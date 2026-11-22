#!/usr/bin/env python3
"""repo_lint.py - static checks for the coa-wildcard-mystic repository that run in seconds.

Usage (from anywhere; python 3.8+, standard library only, reads files, changes nothing):

    python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py            # text report
    python3 -I .../repo_lint.py --json                                                  # machine readable
    python3 -I .../repo_lint.py --root /path/to/coa-wildcard-mystic --only sql,patches   # some groups only
    python3 -I .../repo_lint.py --strict                                                # warnings fail too
    python3 -I .../repo_lint.py --allow my-allow.json                                   # extra exceptions

Exit code: 0 = no errors, 1 = at least one error (or a warning with --strict), 2 = the tool itself could not run.

Severities:
    error    breaks a written rule of the repository or will very likely fail at run time
    warning  probably wrong or fragile; a person should look
    info     cannot be decided statically, or a fact worth knowing; never fails the run

Groups: patches, settings, sql, files, lineends, parse, addon, secrets, enchants.
Every finding carries a stable check id (for example sql-rerun) so exceptions can be listed in an allow file:
    {"allow": [{"check": "settings-missing", "match": "Some.Option"}]}
A finding is dropped when its check id equals "check" and "match" is a substring of its path or message.

What this tool can NOT see: anything that needs the database (whether an id already exists in the stock
tables), the C++ compiler, the game client or the running server. A clean run is rung 1 of the evidence ladder
in SKILL.md, nothing more.
"""
import argparse
import ast
import csv
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder

GROUPS = ("patches", "settings", "sql", "files", "lineends", "parse", "addon", "secrets", "enchants")

# Options a patch may read without a line in server-settings.txt. Keep this list short and explained.
BUILTIN_ALLOW = [
    # (check id, substring, reason)
]

# Tables 000-reset.sql empties completely on every run: anything may be inserted into them freely.
# (Read from 000-reset.sql at run time; this is only the fallback if that parse finds nothing.)
RESET_FALLBACK_EMPTIED = {"wcme_enchant_teach", "wcme_enchant_override", "wcme_proc_target_cooldown",
                          "wcme_enchant_action", "wcme_spellaffect_dbc", "wcme_owned"}

BINARY_CLIENT_EXT = {".mpq", ".dbc", ".blp", ".m2", ".wmo", ".adt", ".wdt"}
BINARY_BUILD_EXT = {".exe", ".dll", ".pdb", ".zip", ".7z", ".tar"}
BYTECODE_EXT = {".pyc", ".pyo"}
SECRET_FILE_NAMES = {"signup-settings.json", "signup-state.json", ".env", "id_rsa", "admin-client.ini"}

SECRET_PATTERNS = [
    ("github token", re.compile(r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{40,}\b")),
    ("private key block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("aws access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("discord webhook", re.compile(r"discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_\-]{20,}")),
    ("slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9\-]{10,}")),
    ("json web token", re.compile(r"\beyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}")),
    ("assigned secret", re.compile(
        r"""(?ix)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*['"]([A-Za-z0-9+/_\-]{16,})['"]""")),
]
SHARE_LINK = re.compile(r"https?://[^\s\"'<>)]+/(?:api/)?share/[A-Za-z0-9_\-]{8,}[^\s\"'<>)]*")


class Report:
    def __init__(self):
        self.findings = []
        self.stats = {}
        self.skipped = []

    def add(self, severity, check, path, message, line=None):
        self.findings.append({"severity": severity, "check": check, "path": path, "line": line, "message": message})

    def error(self, check, path, message, line=None):
        self.add("error", check, path, message, line)

    def warning(self, check, path, message, line=None):
        self.add("warning", check, path, message, line)

    def info(self, check, path, message, line=None):
        self.add("info", check, path, message, line)


def read_bytes(path):
    with open(path, "rb") as handle:
        return handle.read()


def read_text(path):
    data = read_bytes(path)
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252", errors="replace")


def tracked_files(root):
    """Files git tracks (so build output and scratch files are ignored); falls back to walking the tree."""
    try:
        out = subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True, timeout=60)
        if out.returncode == 0 and out.stdout:
            return sorted(p for p in out.stdout.decode("utf-8", "replace").split("\0") if p), True
    except (OSError, subprocess.TimeoutExpired):
        pass
    found = []
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules")]
        for name in files:
            found.append(os.path.relpath(os.path.join(base, name), root).replace(os.sep, "/"))
    return sorted(found), False


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


# --------------------------------------------------------------------------------------------- patches
PATCH_SCRIPT = re.compile(r"^(\d\d)-([a-z0-9]+(?:-[a-z0-9]+)*)\.ps1$")
GETOPTION = re.compile(r"GetOption\s*<[^>]+>\s*\(\s*([^,)]{1,200})", re.S)
LITERAL = re.compile(r'^`?"([^"`\\]+)`?"$')
TERNARY = re.compile(r'^[^"`+]*\?\s*`?"([^"`\\]+)`?"\s*:\s*`?"([^"`\\]+)`?"$')


def options_read(path, text):
    """(name, line) for each literal option name read with GetOption; (None, line, expr) for computed names.
    In *.patch files only added lines count (context lines are the core's own code)."""
    if path.endswith(".patch"):
        kept = []
        for row in text.split("\n"):
            kept.append(row[1:] if row.startswith("+") and not row.startswith("+++") else "")
        text = "\n".join(kept)
    results = []
    for match in GETOPTION.finditer(text):
        expr = " ".join(match.group(1).split())
        literal = LITERAL.match(expr)
        line = line_of(text, match.start())
        ternary = TERNARY.match(expr)
        if literal:
            results.append((literal.group(1), line, expr))
        elif ternary:
            results.append((ternary.group(1), line, expr))
            results.append((ternary.group(2), line, expr))
        else:
            results.append((None, line, expr))
    return results


def parse_settings(text):
    """server-settings.txt: '<config file> | <setting> = <value>' lines; returns (entries, bad lines, comment text)."""
    entries, bad, comments = [], [], []
    for number, row in enumerate(text.split("\n"), 1):
        stripped = row.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            comments.append(stripped)
            continue
        match = re.match(r"^([^|]+?)\s*\|\s*([^=\s]+)\s*=\s?(.*)$", stripped)
        if not match:
            bad.append((number, stripped))
            continue
        entries.append({"file": match.group(1).strip(), "name": match.group(2), "value": match.group(3).strip(),
                        "line": number})
    return entries, bad, "\n".join(comments)


def check_patches(root, files, report):
    patch_files = [f for f in files if f.startswith("patches/") and f.count("/") == 1]
    scripts = [f for f in patch_files if f.endswith(".ps1")]
    diffs = [f for f in patch_files if f.endswith(".patch")]
    others = [f for f in patch_files if not f.endswith((".ps1", ".patch"))]
    report.stats["patch_scripts"] = len(scripts)
    report.stats["patch_diffs"] = len(diffs)
    for path in others:
        report.warning("patch-stray", path, "file in patches/ that is neither NN-name.ps1 nor *.patch; the build ignores it")

    numbers = {}
    for path in scripts:
        name = path.split("/", 1)[1]
        match = PATCH_SCRIPT.match(name)
        if not match:
            digits = re.match(r"^\d*", name).group()
            if digits and len(digits) != 2:
                report.error("patch-order", path, "script number has %d digit(s); the build sorts by name, not by number, so "
                             "this runs out of numeric order (for example 100-x sorts before 20-x)" % len(digits))
            else:
                report.warning("patch-name", path, "script name is not NN-lower-case-words.ps1; the build applies scripts "
                               "in name order, so an odd name lands in an unexpected place")
            continue
        numbers.setdefault(match.group(1), []).append(path)
    for number, paths in sorted(numbers.items()):
        if len(paths) > 1:
            report.error("patch-number-dup", paths[1], "patch number %s is used by %d scripts (%s); their order then "
                         "depends on the rest of the name" % (number, len(paths), ", ".join(p.split("/")[1] for p in paths)))
    if numbers:
        used = sorted(int(n) for n in numbers)
        report.stats["patch_number_range"] = "%02d-%02d" % (used[0], used[-1])
        report.stats["patch_next_free_number"] = next((n for n in range(used[-1] + 1, 100)), None)

    changes_path = os.path.join(root, "CHANGES.md")
    if not os.path.exists(changes_path):
        report.error("changes-missing", "CHANGES.md", "CHANGES.md not found")
        return
    changes = read_text(changes_path)
    ticked = set(re.findall(r"`([^`\n]+)`", changes))
    globs = [t for t in ticked if "*" in t and "/" not in t and " " not in t]
    for path in scripts + diffs:
        name = path.split("/", 1)[1]
        if name in changes:
            continue
        if any(fnmatch.fnmatchcase(name, g) for g in globs):
            report.info("changes-glob", path, "covered in CHANGES.md only by a wildcard row (%s)"
                        % ", ".join(g for g in globs if fnmatch.fnmatchcase(name, g)))
            continue
        report.error("changes-row", path, "no mention in CHANGES.md (the rule there: every new code change gets a line)")
    known = {p.split("/", 1)[1] for p in scripts + diffs}
    for token in sorted(ticked):
        for piece in re.split(r"\s*\+\s*|\s*,\s*", token):
            if re.match(r"^(\d\d-[A-Za-z0-9-]+\.ps1|[A-Za-z0-9-]+\.patch)$", piece) and piece not in known:
                report.warning("changes-stale", "CHANGES.md", "names %s, which is not in patches/" % piece,
                               line_of(changes, changes.find(piece)))

    check_windows_macros(root, scripts + diffs, report)

    # Options read by patches against server-settings.txt
    settings_path = os.path.join(root, "server-settings", "server-settings.txt")
    if not os.path.exists(settings_path):
        report.error("settings-file", "server-settings/server-settings.txt", "not found")
        return
    settings_text = read_text(settings_path)
    entries, _, _ = parse_settings(settings_text)
    set_names = {e["name"] for e in entries}
    seen, dynamic, read_count = {}, [], 0
    for path in scripts + diffs:
        text = read_text(os.path.join(root, path))
        for name, line, expr in options_read(path, text):
            if name is None:
                dynamic.append((path, line, expr))
            else:
                read_count += 1
                seen.setdefault(name, (path, line))
    report.stats["options_read_by_patches"] = len(seen)
    for name, (path, line) in sorted(seen.items()):
        if name in set_names:
            continue
        if name in settings_text:
            report.info("settings-comment-only", path, "option %s is read here and only mentioned in a comment of "
                        "server-settings.txt (not set), so the server runs it on the patch's default" % name, line)
        elif name in changes:
            report.warning("settings-missing", path, "option %s is read here and named in CHANGES.md, but has no line in "
                           "server-settings/server-settings.txt (the server uses the default written in the patch)" % name, line)
        else:
            report.warning("settings-missing", path, "option %s is read here but appears in neither "
                           "server-settings.txt nor CHANGES.md" % name, line)
    for path, line, expr in dynamic:
        report.info("settings-dynamic", path, "option name built at run time (%s...): cannot be checked statically"
                    % expr[:60], line)


# Names the Windows SDK headers define as macros. A constant or enumerator of ours with one of these names compiles
# on Linux and fails on the Windows build (16 Nov: SYNCHRONIZE in the enchant scripts, fixed by a4048e7).
WINDOWS_MACROS = ("SYNCHRONIZE DELETE ERROR IN OUT OPTIONAL CONST VOID TRUE FALSE NO_ERROR IGNORE STRICT CALLBACK PASCAL "
                  "ABSOLUTE RELATIVE INFINITE NEAR FAR MAX_PATH INTERFACE TRANSPARENT OPAQUE DIFFERENCE READ_CONTROL "
                  "GENERIC_READ GENERIC_WRITE GENERIC_EXECUTE GENERIC_ALL WAIT_TIMEOUT WAIT_FAILED STATUS_PENDING "
                  "ERROR_SUCCESS SEVERITY_ERROR DOMAIN UNDERFLOW OVERFLOW ALTERNATE WINDING RGB BI_RGB PM_REMOVE "
                  "MB_OK WRITE_OWNER WRITE_DAC STANDARD_RIGHTS_ALL THREAD_PRIORITY_NORMAL NORMAL_PRIORITY_CLASS "
                  "HIGH_PRIORITY_CLASS IDLE_PRIORITY_CLASS PROCESS_ALL_ACCESS FILE_SHARE_READ SM_CXSCREEN "
                  "ERROR_INVALID_PARAMETER ERROR_ACCESS_DENIED S_OK S_FALSE E_FAIL NOERROR").split()
WIN_DECL = re.compile(
    r"(?:\b(?:constexpr|const|static|enum(?:\s+class)?|#\s*define)\b[^;\n(){}]*?|^[ \t+]*)\b(%s)\b[ \t]*(?:=[^=]|,[ \t]*$|$)"
    % "|".join(WINDOWS_MACROS), re.M)


def check_windows_macros(root, paths, report):
    for path in paths:
        text = read_text(os.path.join(root, path))
        for match in WIN_DECL.finditer(text):
            row = text[text.rfind("\n", 0, match.start()) + 1:text.find("\n", match.end() - 1) if "\n" in text[match.end() - 1:] else len(text)]
            if path.endswith(".patch") and not row.startswith("+"):
                continue
            if re.match(r"^[ \t+]*(//|\*|#\s*(?!define))", row):
                continue
            report.warning("win-macro", path, "declares %s, which the Windows headers define as a macro: this compiles on "
                           "Linux and fails on the Windows build; rename it (for example %s_SPELL)"
                           % (match.group(1), match.group(1)), line_of(text, match.start(1)))


# --------------------------------------------------------------------------------------------- settings
def check_settings(root, files, report):
    path = "server-settings/server-settings.txt"
    full = os.path.join(root, path)
    if not os.path.exists(full):
        return
    entries, bad, _ = parse_settings(read_text(full))
    report.stats["settings_lines"] = len(entries)
    for number, row in bad:
        report.error("settings-format", path, "line is not '<config file> | <setting> = <value>': %s" % row[:80], number)
    seen = {}
    for entry in entries:
        key = (entry["file"].lower(), entry["name"].lower())
        if key in seen:
            first = seen[key]
            if first["value"] == entry["value"]:
                report.warning("settings-dup", path, "%s | %s is set twice with the same value (first at line %d)"
                               % (entry["file"], entry["name"], first["line"]), entry["line"])
            else:
                report.error("settings-dup", path, "%s | %s is set twice with different values (%s at line %d, %s here); "
                             "which one wins depends on the apply script" % (entry["file"], entry["name"], first["value"],
                                                                            first["line"], entry["value"]), entry["line"])
        else:
            seen[key] = entry
        if entry["value"] == "?":
            report.info("settings-unrecorded", path, "%s has the value ? (not recorded yet; Apply-Settings skips it)"
                        % entry["name"], entry["line"])
        if "/" in entry["file"]:
            report.warning("settings-slash", path, "config path %s uses / where every other line uses \\" % entry["file"],
                           entry["line"])
    names = {}
    for entry in entries:
        names.setdefault(entry["name"].lower(), set()).add(entry["file"].lower())
    for name, where in sorted(names.items()):
        if len(where) > 1:
            report.info("settings-two-files", path, "%s is set in more than one config file (%s); fine if both read it"
                        % (name, ", ".join(sorted(where))))


# --------------------------------------------------------------------------------------------- sql
SQL_TOKEN = re.compile(r"""
    (?P<sq>'(?:[^'\\]|\\.|'')*')      |
    (?P<dq>"(?:[^"\\]|\\.|"")*")      |
    (?P<bq>`[^`]*`)                   |
    (?P<lc>(?:--[ \t]|\#)[^\n]*|--$)  |
    (?P<bc>/\*.*?\*/)                 |
    (?P<semi>;)
""", re.S | re.X | re.M)


def split_sql(text):
    """Statements as (start offset, raw text, masked text). In the masked text string contents are replaced by
    spaces (quotes kept) and comments removed, so keywords and brackets can be searched safely."""
    statements, raw_start, pos, masked = [], 0, 0, []
    for match in SQL_TOKEN.finditer(text):
        masked.append(text[pos:match.start()])
        kind = match.lastgroup
        token = match.group()
        if kind in ("sq", "dq"):
            masked.append(token[0] + " " * (len(token) - 2) + token[-1])
        elif kind == "bq":
            masked.append(token)
        elif kind in ("lc", "bc"):
            masked.append(" " * len(token))
        else:
            statements.append((raw_start, text[raw_start:match.start()], "".join(masked)))
            raw_start, masked = match.end(), []
        pos = match.end()
    masked.append(text[pos:])
    if "".join(masked).strip():
        statements.append((raw_start, text[raw_start:], "".join(masked)))
    return [(start, raw, mask) for start, raw, mask in statements if mask.strip()]


NAME = r"(?:`[^`]+`|[A-Za-z_][A-Za-z0-9_$]*)"
TABLE = r"(?:(?P<db>%s)\s*\.\s*)?(?P<table>%s)" % (NAME, NAME)
HEAD = [
    ("insert", re.compile(r"^\s*INSERT\s+(?P<ignore>IGNORE\s+)?(?:INTO\s+)?" + TABLE, re.I)),
    ("replace", re.compile(r"^\s*REPLACE\s+(?:INTO\s+)?" + TABLE, re.I)),
    ("update", re.compile(r"^\s*UPDATE\s+(?:IGNORE\s+)?" + TABLE, re.I)),
    ("delete", re.compile(r"^\s*DELETE\s+(?:%s\s+)?FROM\s+%s" % (NAME, TABLE), re.I)),
    ("create_temp", re.compile(r"^\s*CREATE\s+TEMPORARY\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?" + TABLE, re.I)),
    ("create", re.compile(r"^\s*CREATE\s+TABLE\s+(?P<ifne>IF\s+NOT\s+EXISTS\s+)?" + TABLE, re.I)),
    ("drop_temp", re.compile(r"^\s*DROP\s+TEMPORARY\s+TABLE\s+(?:IF\s+EXISTS\s+)?" + TABLE, re.I)),
    ("drop_table", re.compile(r"^\s*DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?" + TABLE, re.I)),
    ("drop_db", re.compile(r"^\s*DROP\s+(?:DATABASE|SCHEMA)\b", re.I)),
    ("truncate", re.compile(r"^\s*TRUNCATE\s+(?:TABLE\s+)?" + TABLE, re.I)),
    ("alter", re.compile(r"^\s*ALTER\s+TABLE\s+" + TABLE, re.I)),
    ("use", re.compile(r"^\s*USE\s+", re.I)),
    ("grant", re.compile(r"^\s*(?:GRANT|REVOKE|CREATE\s+USER|ALTER\s+USER|DROP\s+USER|SET\s+PASSWORD)\b", re.I)),
    ("set_persist", re.compile(r"^\s*SET\s+(?:PERSIST|PERSIST_ONLY|GLOBAL)\b", re.I)),
    ("set", re.compile(r"^\s*SET\b", re.I)),
]


def unquote(name):
    return name.strip("`") if name else name


def classify(mask):
    for kind, pattern in HEAD:
        match = pattern.match(mask)
        if match:
            groups = match.groupdict()
            return kind, unquote(groups.get("table")), unquote(groups.get("db")), match
    return "other", None, None, None


def top_level_tuples(mask, start):
    """Spans (open, close) of each bracketed tuple after VALUES, at depth 0."""
    spans, depth, begin = [], 0, None
    for index in range(start, len(mask)):
        char = mask[index]
        if char == "(":
            if depth == 0:
                begin = index
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0 and begin is not None:
                spans.append((begin, index))
                begin = None
    return spans


def split_fields(mask, raw, span):
    fields, depth, begin = [], 0, span[0] + 1
    for index in range(span[0] + 1, span[1]):
        char = mask[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            fields.append(raw[begin:index].strip())
            begin = index + 1
    fields.append(raw[begin:span[1]].strip())
    return fields


def insert_rows(raw, mask, head_end):
    """For INSERT/REPLACE ... VALUES: (column names or None, list of rows as field lists). None if it is not a
    plain VALUES list (INSERT ... SELECT and the like)."""
    rest = mask[head_end:]
    columns = None
    match = re.match(r"\s*\(([^()]*)\)\s*", rest)
    offset = head_end
    if match:
        columns = [unquote(c.strip()) for c in match.group(1).split(",")]
        offset += match.end()
    values = re.match(r"\s*VALUES?\b", mask[offset:], re.I)
    if not values:
        return columns, None
    offset += values.end()
    return columns, [split_fields(mask, raw, span) for span in top_level_tuples(mask, offset)]


def as_int(field):
    return int(field) if re.match(r"^-?\d+$", field or "") else None


def static_id_list(mask, raw, column_names):
    """ids from 'WHERE `col` IN (1, 2, 3)' or 'WHERE `col` = 5' for one of the given columns; None if not that shape."""
    for column in column_names:
        col = r"`?%s`?" % re.escape(column)
        match = re.search(r"WHERE\s+(?:%s\s*\.\s*)?%s\s+IN\s*\(([\d\s,\-]+)\)" % (NAME, col), mask, re.I)
        if match:
            return {int(v) for v in re.findall(r"-?\d+", match.group(1))}
        match = re.search(r"WHERE\s+(?:%s\s*\.\s*)?%s\s*=\s*(-?\d+)" % (NAME, col), mask, re.I)
        if match:
            return {int(match.group(1))}
    return None


def parse_reset(statements, report, path):
    """What 000-reset.sql really removes: tables emptied outright, tables cleaned through wcme_owned (with the
    owner key and the id column), and tables cleaned by a LIKE marker."""
    emptied, owned, marked = set(), {}, {}
    for _, raw, mask in statements:
        kind, table, _, _ = classify(mask)
        if kind != "delete":
            continue
        if not re.search(r"\bWHERE\b|\bJOIN\b", mask, re.I):
            emptied.add(table)
            continue
        join = re.search(r"JOIN\s+`?wcme_owned`?\s+`?(\w+)`?\s+ON\s+(.*)$", mask, re.I | re.S)
        if join:
            key = re.search(r"`?tbl`?\s*=\s*'([^']*)'", raw)
            column = re.search(r"=\s*`?\w+`?\s*\.\s*`?(\w+)`?\s*$", mask.strip())
            if key and column:
                owned[table] = (key.group(1), column.group(1))
            continue
        like = re.search(r"WHERE\s+`?(\w+)`?\s+LIKE\s+'((?:[^'\\]|\\.)*)'", raw, re.I)
        if like:
            marked[table] = (like.group(1), like.group(2))
    if not (emptied or owned or marked):
        report.warning("sql-reset-parse", path, "could not read any rule from 000-reset.sql; using the built-in list")
        emptied = set(RESET_FALLBACK_EMPTIED)
    return emptied, owned, marked


def like_to_prefix(pattern):
    """'WCME:%' -> 'WCME:' ; 'spell\\_wcme\\_%' -> 'spell_wcme_' ; None when the pattern is not a plain prefix."""
    if not pattern.endswith("%"):
        return None
    body = pattern[:-1].replace("\\_", "_").replace("\\%", "\x00")
    return None if "%" in body else body.replace("\x00", "%")


def check_sql(root, files, report):
    folder = "sql/enchants/"
    sql_files = sorted(f for f in files if f.startswith(folder) and f.endswith(".sql"))
    report.stats["sql_files"] = len(sql_files)
    if not sql_files:
        return
    prefixes = {}
    for path in sql_files:
        name = path[len(folder):]
        match = re.match(r"^(\d{3})-[a-z0-9]+(?:-[a-z0-9]+)*\.sql$", name)
        if not match:
            report.warning("sql-name", path, "name is not NNN-lower-case-words.sql; files run in name order")
            continue
        prefixes.setdefault(match.group(1), []).append(path)
    for prefix, paths in sorted(prefixes.items()):
        if len(paths) > 1:
            report.error("sql-number-dup", paths[1], "number %s is used by %s" % (prefix, ", ".join(paths)))
    if not sql_files[0].endswith("/000-reset.sql"):
        report.error("sql-reset-first", sql_files[0], "000-reset.sql must sort first; the first file is %s" % sql_files[0])

    parsed = {path: split_sql(read_text(os.path.join(root, path))) for path in sql_files}
    reset_path = folder + "000-reset.sql"
    emptied, owned_rule, marked = parse_reset(parsed.get(reset_path, []), report, reset_path)
    report.stats["reset_rules"] = {
        "emptied_every_run": sorted(emptied),
        "removed_if_listed_in_wcme_owned": {t: {"tbl": k, "id_column": c} for t, (k, c) in sorted(owned_rule.items())},
        "removed_by_marker": {t: {"column": c, "like": p} for t, (c, p) in sorted(marked.items())},
    }
    key_of = {table: key for table, (key, _) in owned_rule.items()}
    id_column = {table: column for table, (_, column) in owned_rule.items()}

    # Pass 1: what every file registers in wcme_owned (static ids and "dynamic" registrations per file).
    registered = {}          # key -> {id: first file}
    dynamic_reg = {}         # file -> set of keys registered through a SELECT
    for path in sql_files:
        if path == reset_path:
            continue
        for start, raw, mask in parsed[path]:
            kind, table, db, head = classify(mask)
            if kind not in ("insert", "replace") or table != "wcme_owned":
                continue
            columns, rows = insert_rows(raw, mask, head.end())
            line = None
            if rows is None:
                keys = set(re.findall(r"'([A-Za-z_]+)'", raw))
                dynamic_reg.setdefault(path, set()).update(keys or {"?"})
                continue
            plain = kind == "insert" and not head.group("ignore")
            for row in rows:
                if len(row) < 2:
                    continue
                key, ident = row[0].strip("'\""), as_int(row[1])
                if ident is None:
                    dynamic_reg.setdefault(path, set()).add(key)
                    continue
                first = registered.setdefault(key, {}).get(ident)
                if first is None:
                    registered[key][ident] = path
                elif plain:
                    line = line_of(read_text(os.path.join(root, path)), start + (len(mask) - len(mask.lstrip())))
                    report.error("sql-owned-dup", path, "plain INSERT INTO wcme_owned repeats ('%s', %d), already registered "
                                 "by %s: a duplicate-key error stops the rest of this file. Use INSERT IGNORE"
                                 % (key, ident, first.split("/")[-1]), line)
            unknown = {row[0].strip("'\"") for row in rows if row} - set(key_of.values())
            for key in sorted(unknown):
                report.error("sql-owned-key", path, "registers tbl '%s' in wcme_owned, but 000-reset.sql removes rows only for %s"
                             % (key, ", ".join("'%s'" % k for k in sorted(set(key_of.values())))))
    report.stats["wcme_owned_static_ids"] = {key: len(ids) for key, ids in sorted(registered.items())}

    # Pass 2: simulate two runs. present[table] = ids we inserted and have not deleted.
    present = {table: set() for table in owned_rule}
    uncheckable = {}
    not_owned = {}
    for run in (1, 2):
        if run == 2:
            for table in present:
                present[table] -= set(registered.get(key_of[table], {}))
        for path in sql_files:
            if path == reset_path:
                continue
            text = None
            deleted_tables = set()
            temp_tables = set()
            for start, raw, mask in parsed[path]:
                kind, table, db, head = classify(mask)

                def where():
                    nonlocal text
                    if text is None:
                        text = read_text(os.path.join(root, path))
                    return line_of(text, start + (len(mask) - len(mask.lstrip())))

                if run == 1:
                    lowered_db = (db or "").lower()
                    if kind == "drop_db":
                        report.error("sql-forbidden", path, "DROP DATABASE / DROP SCHEMA is never allowed here", where())
                    elif kind == "grant":
                        report.error("sql-forbidden", path, "account or privilege statement (hard stop 1: accounts and "
                                     "security): %s" % " ".join(mask.split())[:60], where())
                    elif kind == "use":
                        report.error("sql-forbidden", path, "USE switches database; patch night picks the world database "
                                     "of the active realm itself (--database)", where())
                    elif kind == "drop_table" and not (table or "").startswith("wcme_"):
                        report.error("sql-forbidden", path, "DROP TABLE %s: only our own wcme_ tables may be dropped" % table,
                                     where())
                    elif kind == "truncate" and not (table or "").startswith("wcme_"):
                        report.error("sql-forbidden", path, "TRUNCATE %s: only our own wcme_ tables may be emptied" % table,
                                     where())
                    elif kind == "alter" and not (table or "").startswith("wcme_"):
                        report.warning("sql-alter", path, "ALTER TABLE %s changes a stock table's shape; a core update that "
                                       "ships its own change to it can then fail" % table, where())
                    elif kind == "create" and not head.group("ifne"):
                        report.error("sql-rerun", path, "CREATE TABLE %s without IF NOT EXISTS fails on the second run" % table,
                                     where())
                    elif kind == "set_persist":
                        report.info("sql-server-setting", path, "changes a MySQL server setting for every database: %s"
                                    % " ".join(raw[len(mask) - len(mask.lstrip()):].split())[:70], where())
                    if kind in ("insert", "replace", "update", "delete", "alter", "truncate", "drop_table", "create") and (
                            "character" in lowered_db or "auth" in lowered_db):
                        report.error("sql-other-db", path, "writes to %s.%s: files here may only touch the world database "
                                     "(hard stop 7: character, account and guild data)" % (db, table), where())
                    if kind in ("insert", "replace", "update", "delete") and re.search(
                            r"\b(?:acore_)?(?:characters|auth)\w*\s*\.\s*`?\w+", mask, re.I) and not (
                            "character" in lowered_db or "auth" in lowered_db):
                        report.warning("sql-other-db", path, "mentions a characters/auth database table inside a statement "
                                       "(read or write?): %s" % " ".join(mask.split())[:70], where())

                if kind == "create_temp":
                    temp_tables.add(table)
                    continue
                if kind == "delete":
                    deleted_tables.add(table)
                    if table in present:
                        ids = static_id_list(mask, raw, [id_column[table]])
                        if ids is None:
                            if not re.search(r"\bWHERE\b", mask, re.I):
                                present[table].clear()
                        else:
                            present[table] -= ids
                    continue
                if kind == "update" and run == 1:
                    if table and not table.startswith("wcme_") and table not in temp_tables:
                        relative = re.search(r"SET\b.*?(`?\w+`?\s*\.\s*)?`?(\w+)`?\s*=\s*(?:\w+\s*\(\s*)*(`?\w+`?\s*\.\s*)?`?\2`?\s*[*/+\-]",
                                             mask, re.I | re.S)
                        if relative:
                            report.warning("sql-relative-update", path, "UPDATE %s sets %s from its own value: it compounds on "
                                           "every start unless the original is kept elsewhere" % (table, relative.group(2)),
                                           where())
                        # An UPDATE whose ids are all rows that an earlier (or this) file registers in wcme_owned
                        # is undone by the reset: the reset deletes the row and the owning file re-creates it
                        # (013 updating spell_proc 282881, which 007 owns). Only the rest are "outside the reset".
                        ids = static_id_list(mask, raw, [id_column[table]]) if table in owned_rule else None
                        owners = registered.get(key_of.get(table), {})
                        if ids and all(owners.get(i) is not None and owners[i] <= path for i in ids):
                            report.stats.setdefault("updates_of_owned_rows", []).append("%s: %s" % (path, table))
                        else:
                            not_owned.setdefault((path, table), "UPDATE")
                    continue
                if kind not in ("insert", "replace"):
                    continue
                if table in temp_tables or table == "wcme_owned":
                    continue
                ignore = kind == "replace" or bool(head.groupdict().get("ignore"))
                dup_update = bool(re.search(r"ON\s+DUPLICATE\s+KEY\s+UPDATE", mask, re.I))
                columns, rows = insert_rows(raw, mask, head.end())

                if table in emptied:
                    continue

                if table in marked:
                    column, pattern = marked[table]
                    prefix = like_to_prefix(pattern)
                    if run == 1:
                        if rows is None or prefix is None:
                            if prefix and ("'" + prefix) not in raw:
                                report.error("sql-marker", path, "INSERT INTO %s ... SELECT without the %s marker '%s': "
                                             "000-reset.sql will never remove these rows" % (table, column, prefix), where())
                            else:
                                uncheckable.setdefault(path, set()).add("%s (rows built by a SELECT)" % table)
                        else:
                            index = columns.index(column) if columns and column in columns else None
                            bad = 0
                            for row in rows:
                                cells = [row[index]] if index is not None and index < len(row) else row
                                if not any(cell.startswith("'" + prefix) for cell in cells):
                                    bad += 1
                            if bad and table not in deleted_tables:
                                report.error("sql-marker", path, "%d row(s) inserted into %s without %s starting '%s': "
                                             "000-reset.sql will not remove them, so they pile up or collide on the next start"
                                             % (bad, table, column, prefix), where())
                            elif bad:
                                report.warning("sql-marker", path, "%d row(s) inserted into %s without the '%s' marker; the file "
                                               "deletes its own rows first, so it re-runs, but removing the file leaves them"
                                               % (bad, table, prefix), where())
                    continue

                if table in owned_rule:
                    key = key_of[table]
                    if rows is None:
                        if run == 1:
                            uncheckable.setdefault(path, set()).add("%s (rows built by a SELECT)" % table)
                        continue
                    index = 0
                    if columns and id_column[table] in columns:
                        index = columns.index(id_column[table])
                    ids = [as_int(row[index]) if index < len(row) else None for row in rows]
                    if any(i is None for i in ids):
                        if run == 1:
                            uncheckable.setdefault(path, set()).add("%s (computed ids)" % table)
                        ids = [i for i in ids if i is not None]
                    dynamic = key in dynamic_reg.get(path, set())
                    if run == 1:
                        missing = [i for i in ids if i not in registered.get(key, {})]
                        if missing and dynamic:
                            uncheckable.setdefault(path, set()).add(
                                "%s (%d ids owned only if a SELECT registers them at run time)" % (table, len(missing)))
                        elif missing:
                            sample = ", ".join(str(i) for i in missing[:5]) + (" ..." if len(missing) > 5 else "")
                            if kind == "replace":
                                report.info("sql-not-owned", path, "REPLACE INTO %s for %d id(s) not registered in wcme_owned "
                                            "(%s): right when it restores the core's own row (000-reset.sql must leave "
                                            "that alone), wrong for a row of ours, which then outlives its file"
                                            % (table, len(missing), sample), where())
                            elif ignore or dup_update:
                                report.warning("sql-not-owned", path, "%d id(s) put into %s but never registered in wcme_owned "
                                               "as '%s' (%s): 000-reset.sql does not remove them, so an edit to the row or "
                                               "deleting the file has no effect on a database that already has it"
                                               % (len(missing), table, key, sample), where())
                            else:
                                report.warning("sql-not-owned", path, "%d id(s) inserted into %s but never registered in "
                                               "wcme_owned as '%s' (%s): the rows outlive the file" % (len(missing), table, key, sample),
                                               where())
                    if not ignore and not dup_update:
                        clash = [i for i in ids if i in present[table]]
                        if clash and not dynamic:
                            sample = ", ".join(str(i) for i in clash[:5]) + (" ..." if len(clash) > 5 else "")
                            report.error("sql-rerun", path, "run %d: plain INSERT INTO %s for %d id(s) that are still there (%s): "
                                         "not removed by 000-reset.sql and not deleted earlier in this file, so a duplicate-key "
                                         "error stops the rest of the file" % (run, table, len(clash), sample), where())
                    present[table].update(ids)
                    continue

                # Any other table: not covered by 000-reset.sql at all.
                if run == 1 and table:
                    own = table.startswith("wcme_")
                    if not own:
                        not_owned.setdefault((path, table), "INSERT")
                    if not ignore and not dup_update and table not in deleted_tables:
                        report.error("sql-rerun", path, "plain INSERT INTO %s with no DELETE FROM %s earlier in the file and no "
                                     "000-reset.sql rule for that table: the second run inserts the rows again or fails"
                                     % (table, table), where())
    for path, items in sorted(uncheckable.items()):
        report.info("sql-uncheckable", path, "cannot be checked without the database: " + "; ".join(sorted(items)))
    by_file = {}
    for (path, table), verb in sorted(not_owned.items()):
        by_file.setdefault(path, []).append("%s %s" % (verb, table))
    for path, items in sorted(by_file.items()):
        report.info("sql-outside-reset", path, "changes stock tables that 000-reset.sql does not restore, so deleting this "
                    "file does not undo it: " + ", ".join(items))


# --------------------------------------------------------------------------------------------- files
def check_files(root, files, report):
    for path in files:
        ext = os.path.splitext(path)[1].lower()
        base = path.rsplit("/", 1)[-1]
        if ext in BINARY_CLIENT_EXT:
            report.error("client-data", path, "game client data (%s) must never be committed to this public repository" % ext)
        elif ext in BINARY_BUILD_EXT:
            report.error("binary", path, "build output or archive (%s) committed; builds are published as releases" % ext)
        elif ext in BYTECODE_EXT or "/__pycache__/" in "/" + path:
            report.warning("bytecode", path, "compiled Python is committed (.gitignore lists __pycache__/, but a file tracked "
                           "before that stays tracked until 'git rm --cached')")
        if base.lower() in SECRET_FILE_NAMES:
            report.error("secret-file", path, "this file name is reserved for secrets or local state and must stay untracked")
        try:
            size = os.path.getsize(os.path.join(root, path))
        except OSError:
            continue
        if size > 5 * 1024 * 1024:
            report.warning("large-file", path, "%.1f MB; large files slow every patch-night download of the repository zip"
                           % (size / 1048576.0))
    third = "addon/third-party-addons.txt"
    if third in files:
        for number, row in enumerate(read_text(os.path.join(root, third)).split("\n"), 1):
            if re.match(r"^\s*(#|$)", row):
                continue
            parts = [p.strip() for p in row.split("|")]
            if len(parts) < 3 or not re.match(r"^[0-9a-f]{40}$", parts[1]):
                report.error("addon-pin", third, "line is not 'owner/repository | 40-character commit | folders'; patch night "
                             "skips it with a warning: %s" % row.strip()[:70], number)
            elif not re.match(r"^[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+$", parts[0]):
                report.error("addon-pin", third, "first field is not owner/repository: %s" % parts[0], number)


# --------------------------------------------------------------------------------------------- line endings
def ending_kind(data):
    crlf = data.count(b"\r\n")
    lf = data.count(b"\n") - crlf
    lone_cr = data.count(b"\r") - crlf
    if lone_cr:
        return "mixed"
    if crlf and lf:
        return "mixed"
    return "crlf" if crlf else ("lf" if lf else "none")


def check_lineends(root, files, report):
    counts = {}
    for path in files:
        ext = os.path.splitext(path)[1].lower()
        if ext not in (".ps1", ".cmd", ".bat", ".py", ".sql", ".lua", ".toc", ".md", ".txt", ".yml", ".json", ".patch",
                       ".html", ".css", ".js", ".csv"):
            continue
        data = read_bytes(os.path.join(root, path))
        kind = ending_kind(data)
        top = path.split("/", 1)[0]
        counts.setdefault((top if ext == ".ps1" else "*", ext), {}).setdefault(kind, []).append(path)
        if kind == "mixed" and ext in (".ps1", ".cmd", ".bat", ".patch"):
            report.error("eol-mixed", path, "mixed line endings in a script or patch (PowerShell here-strings then carry "
                         "stray carriage returns into patched C++, and a .patch stops applying)")
        elif kind == "mixed":
            report.warning("eol-mixed", path, "mixed line endings in one file (harmless to run, but the next editor that "
                           "normalises it turns a one-line change into a whole-file diff)")
        if ext in (".cmd", ".bat") and kind == "lf":
            report.error("eol-cmd", path, "a .cmd file with LF-only endings; every other .cmd here is CRLF and cmd.exe can "
                         "misread labels and long lines in LF files")
        if ext == ".ps1" and path.startswith("patches/") and kind == "crlf":
            report.error("eol-patch-script", path, "patch scripts are LF in this repository; their here-strings are pasted into "
                         "C++ sources, and the workflow sets core.autocrlf false so CRLF would reach the compiler")
        if ext == ".patch" and kind != "lf":
            report.error("eol-patch", path, "a .patch file with CRLF endings will not apply to LF sources (git apply --check)")
        if ext == ".ps1" and data[:3] != b"\xef\xbb\xbf":
            try:
                data.decode("ascii")
            except UnicodeDecodeError:
                if not path.startswith("patches/"):
                    report.warning("ps1-encoding", path, "non-ASCII characters and no UTF-8 byte-order mark: Windows PowerShell "
                                   "5.1 (which the scheduled tasks use) reads the file as Windows-1252")
                else:
                    report.info("ps1-encoding", path, "non-ASCII characters and no byte-order mark; fine under pwsh on the "
                                "build runner (reads UTF-8), wrong under Windows PowerShell 5.1")
    summary = {}
    for (top, ext), kinds in sorted(counts.items()):
        label = ext if top == "*" else "%s/*%s" % (top, ext)
        summary[label] = {kind: len(paths) for kind, paths in sorted(kinds.items())}
        if ext == ".ps1" and top != "patches" and len(kinds) > 1:
            minority = min(kinds.items(), key=lambda item: len(item[1]))
            for path in minority[1]:
                report.warning("eol-odd-one-out", path, "%s line endings; the other scripts in %s/ use %s"
                               % (minority[0].upper(), top, "/".join(k.upper() for k in kinds if k != minority[0])))
    for ext in (".ps1",):
        vm_kinds = {}
        for (top, e), kinds in counts.items():
            if e == ext and top != "patches":
                for kind, paths in kinds.items():
                    vm_kinds.setdefault(kind, []).extend(paths)
        if len(vm_kinds) > 1:
            minority = min(vm_kinds.items(), key=lambda item: len(item[1]))
            already = {f["path"] for f in report.findings if f["check"] == "eol-odd-one-out"}
            for path in minority[1]:
                if path not in already:
                    report.warning("eol-odd-one-out", path, "%s line endings; the other %d scripts that run on the VM are %s"
                                   % (minority[0].upper(), sum(len(p) for k, p in vm_kinds.items() if k != minority[0]),
                                      "/".join(k.upper() for k in vm_kinds if k != minority[0])))
    report.stats["line_endings"] = summary


# --------------------------------------------------------------------------------------------- parse
def check_parse(root, files, report):
    for path in files:
        ext = os.path.splitext(path)[1].lower()
        full = os.path.join(root, path)
        if ext == ".json":
            try:
                json.loads(read_text(full))
            except ValueError as problem:
                report.error("json-parse", path, "does not parse as JSON: %s" % problem)
        elif ext == ".py":
            try:
                ast.parse(read_text(full), filename=path)
            except SyntaxError as problem:
                report.error("py-parse", path, "Python syntax error: %s" % problem.msg, problem.lineno)
        elif ext == ".csv":
            try:
                with open(full, newline="", encoding="utf-8-sig") as handle:
                    rows = list(csv.reader(handle))
            except (csv.Error, UnicodeDecodeError) as problem:
                report.error("csv-parse", path, "does not read as CSV: %s" % problem)
                continue
            if rows:
                width = len(rows[0])
                odd = [n for n, row in enumerate(rows[1:], 2) if row and len(row) != width]
                if odd:
                    report.warning("csv-width", path, "%d row(s) do not have the header's %d columns (first at line %d); tools "
                                   "that read by column name see an empty or missing value" % (len(odd), width, odd[0]), odd[0])
        elif ext == ".ps1":
            text = read_text(full)
            opened = None
            for number, row in enumerate(text.split("\n"), 1):
                row = row.rstrip("\r")
                if opened is None:
                    match = re.search(r"@(['\"])\s*$", row)
                    if match:
                        opened = (match.group(1), number)
                elif row.startswith(opened[0] + "@"):
                    opened = None
            if opened:
                report.error("ps1-herestring", path, "here-string opened with @%s is never closed (the closing %s@ must start "
                             "a line)" % (opened[0], opened[0]), opened[1])
        elif ext in (".yml", ".yaml"):
            for number, row in enumerate(read_text(full).split("\n"), 1):
                if "\t" in row[:len(row) - len(row.lstrip())]:
                    report.error("yaml-tab", path, "tab used for indentation; YAML does not allow it", number)
                    break
    scripts = [f for f in files if f.lower().endswith(".ps1")]
    shell = shutil.which("pwsh") or shutil.which("powershell")
    if not shell:
        report.skipped.append("ps1-parse: PowerShell is not installed here, so %d .ps1 files were only checked for unclosed "
                              "here-strings, not parsed" % len(scripts))
        return
    command = ("$bad = 0; foreach ($f in [Console]::In.ReadToEnd().Split(\"`n\")) { $f = $f.Trim(); if (-not $f) { continue }; "
               "$t = $null; $e = $null; [void] [System.Management.Automation.Language.Parser]::ParseFile($f, [ref] $t, [ref] $e); "
               "foreach ($x in $e) { \"$f|$($x.Extent.StartLineNumber)|$($x.Message)\" } }")
    try:
        out = subprocess.run([shell, "-NoProfile", "-NonInteractive", "-Command", command],
                             input="\n".join(os.path.join(root, s) for s in scripts), capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.TimeoutExpired) as problem:
        report.skipped.append("ps1-parse: could not run %s (%s)" % (shell, problem))
        return
    for row in out.stdout.split("\n"):
        parts = row.strip().split("|", 2)
        if len(parts) == 3:
            rel = os.path.relpath(parts[0], root).replace(os.sep, "/")
            report.error("ps1-parse", rel, "PowerShell parse error: %s" % parts[2], as_int(parts[1]))
    report.stats["ps1_parsed_with"] = shell


# --------------------------------------------------------------------------------------------- addon
def check_addon(root, files, report):
    tocs = [f for f in files if f.startswith("addon/") and f.lower().endswith(".toc")]
    versions = {}
    for toc in tocs:
        folder = toc.rsplit("/", 1)[0]
        name = folder.rsplit("/", 1)[-1]
        text = read_text(os.path.join(root, toc))
        if toc.rsplit("/", 1)[-1] != name + ".toc":
            report.error("toc-name", toc, "the .toc must be named after its folder (%s.toc) or the client does not load the addon"
                         % name)
        meta = dict(re.findall(r"^##\s*([A-Za-z-]+)\s*:\s*(.*?)\s*$", text, re.M))
        if meta.get("Interface") != "30300":
            report.error("toc-interface", toc, "## Interface is %r; the 3.3.5a client wants 30300 (otherwise 'out of date')"
                         % meta.get("Interface"))
        version = meta.get("Version")
        if not version:
            report.warning("toc-version", toc, "no ## Version line")
        versions[name] = version
        listed = [row.strip().replace("\\", "/") for row in text.split("\n")
                  if row.strip() and not row.strip().startswith("#")]
        present = {f[len(folder) + 1:] for f in files if f.startswith(folder + "/")}
        for entry in listed:
            if entry not in present:
                report.error("toc-file", toc, "lists %s, which is not in the addon folder: the addon loads with an error" % entry)
        for entry in sorted(present):
            if entry.lower().endswith((".lua", ".xml")) and entry not in listed:
                report.warning("toc-unlisted", folder + "/" + entry, "not listed in %s.toc, so the client never loads it" % name)
        found_any = False
        for entry in sorted(present):
            if not entry.lower().endswith(".lua"):
                continue
            lua = read_text(os.path.join(root, folder, entry))
            for match in re.finditer(r"""(?im)^\s*(?:local\s+)?[A-Za-z_.]*VERSION[A-Za-z_]*\s*=\s*["']?([0-9][0-9.]*)["']?""", lua):
                found_any = True
                if version and match.group(1) != version:
                    report.error("addon-version", folder + "/" + entry, "version %s in the Lua differs from ## Version: %s in the "
                                 ".toc" % (match.group(1), version), line_of(lua, match.start()))
        if not found_any and version:
            report.info("addon-version", toc, "version %s lives only in the .toc (no version string in the Lua to compare)"
                        % version)
    report.stats["addon_versions"] = versions
    ps1, py = "launcher/WildcardLauncher.ps1", "launcher/WildcardLauncher.py"
    launcher = {}
    if ps1 in files:
        match = re.search(r"(?m)^\$LauncherVersion = (\d+)", read_text(os.path.join(root, ps1)))
        if match:
            launcher["windows"] = int(match.group(1))
        else:
            report.error("launcher-version", ps1, "no '$LauncherVersion = N' line at the start of a line; "
                         "Publish-WildcardSite.ps1 reads the version with exactly that pattern")
    if py in files:
        match = re.search(r"(?m)^LAUNCHER_VERSION = (\d+)", read_text(os.path.join(root, py)))
        if match:
            launcher["linux"] = int(match.group(1))
        else:
            report.error("launcher-version", py, "no 'LAUNCHER_VERSION = N' line at the start of a line; "
                         "Publish-WildcardSite.ps1 reads the version with exactly that pattern")
    report.stats["launcher_versions"] = launcher


# --------------------------------------------------------------------------------------------- secrets
def check_secrets(root, files, report):
    for path in files:
        ext = os.path.splitext(path)[1].lower()
        if ext in (".png", ".jpg", ".jpeg", ".gif", ".ico", ".pyc", ".zip", ".mpq", ".dbc", ".blp", ".exe", ".dll"):
            continue
        full = os.path.join(root, path)
        try:
            if os.path.getsize(full) > 3 * 1024 * 1024:
                continue
        except OSError:
            continue
        text = read_text(full)
        for label, pattern in SECRET_PATTERNS:
            for match in pattern.finditer(text):
                if label == "assigned secret":
                    value = match.group(2)
                    if len(set(value)) < 6 or not (re.search(r"\d", value) and re.search(r"[A-Za-z]", value)):
                        continue
                report.error("secret", path, "looks like a %s (value not shown); if real, revoke it: removing the line does "
                             "not remove it from history" % label, line_of(text, match.start()))
        for match in SHARE_LINK.finditer(text):
            report.info("share-link", path, "public share link %s...: anyone who reads this public repository can use it"
                        % match.group()[:48], line_of(text, match.start()))


# --------------------------------------------------------------------------------------------- enchants
def check_enchants(root, files, report):
    tracker = "enchants/tracker.csv"
    sql_names = {f.rsplit("/", 1)[-1] for f in files if f.startswith("sql/enchants/")}
    sql_prefixes = {n[:3] for n in sql_names}
    patch_names = {f.rsplit("/", 1)[-1] for f in files if f.startswith("patches/")}
    if tracker in files:
        with open(os.path.join(root, tracker), newline="", encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle))
        report.stats["tracker_rows"] = len(rows)
        spells, missing_files, bad_dates, tested = {}, {}, [], 0
        for number, row in enumerate(rows, 2):
            spell = (row.get("spell") or "").strip()
            if spell in spells:
                report.error("tracker-dup", tracker, "spell %s is on two rows (lines %d and %d)" % (spell, spells[spell], number),
                             number)
            spells[spell] = number
            for name in re.findall(r"[0-9A-Za-z][0-9A-Za-z-]*\.(?:sql|patch|ps1)", row.get("fix file") or ""):
                if name not in sql_names and name not in patch_names:
                    missing_files.setdefault(name, []).append(number)
            value = (row.get("tested") or "").strip()
            if value:
                tested += 1
                if not re.match(r"^20\d\d-\d\d-\d\d\b", value):
                    bad_dates.append(number)
            if (row.get("status") or "") == "verified" and not value:
                report.warning("tracker-verified", tracker, "spell %s has status verified but an empty tested column" % spell,
                               number)
        report.stats["tracker_tested_rows"] = tested
        for name, lines in sorted(missing_files.items()):
            report.warning("tracker-fix-file", tracker, "%d row(s) name fix file %s, which is not in sql/enchants/ or patches/ "
                           "(renamed or removed since?)" % (len(lines), name), lines[0])
        if bad_dates:
            report.warning("tracker-tested-format", tracker, "%d tested value(s) do not start with a YYYY-MM-DD date (first at "
                           "line %d)" % (len(bad_dates), bad_dates[0]), bad_dates[0])
    checklist = "enchants/test-checklist.csv"
    if checklist in files:
        with open(os.path.join(root, checklist), newline="", encoding="utf-8-sig") as handle:
            rows = list(csv.DictReader(handle))
        report.stats["checklist_rows"] = len(rows)
        gone = {}
        for number, row in enumerate(rows, 2):
            prefix = (row.get("file") or "").strip()
            if re.match(r"^\d{3}$", prefix) and prefix not in sql_prefixes:
                gone.setdefault(prefix, []).append(number)
        for prefix, lines in sorted(gone.items()):
            report.warning("checklist-file", checklist, "%d row(s) point at SQL file %s-*, which is not in sql/enchants/"
                           % (len(lines), prefix), lines[0])


CHECKS = {"patches": check_patches, "settings": check_settings, "sql": check_sql, "files": check_files,
          "lineends": check_lineends, "parse": check_parse, "addon": check_addon, "secrets": check_secrets,
          "enchants": check_enchants}


def find_root(start):
    here = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(here, "patches")) and os.path.isfile(os.path.join(here, "CHANGES.md")):
            return here
        parent = os.path.dirname(here)
        if parent == here:
            return None
        here = parent


def main():
    parser = argparse.ArgumentParser(description="Static checks for the coa-wildcard-mystic repository.")
    parser.add_argument("--root", help="repository root (default: found from this script's place or the current folder)")
    parser.add_argument("--json", action="store_true", help="print one JSON document instead of text")
    parser.add_argument("--only", help="comma separated groups: " + ", ".join(GROUPS))
    parser.add_argument("--strict", action="store_true", help="exit 1 on warnings as well as errors")
    parser.add_argument("--allow", help="JSON file of exceptions: {\"allow\": [{\"check\": id, \"match\": substring}]}")
    parser.add_argument("--no-info", action="store_true", help="leave info findings out of the text report")
    args = parser.parse_args()

    root = args.root or find_root(os.path.dirname(os.path.abspath(__file__))) or find_root(os.getcwd())
    if not root or not os.path.isdir(os.path.join(root, "patches")):
        print("repo_lint: cannot find the repository root (a folder with patches/ and CHANGES.md); use --root", file=sys.stderr)
        return 2
    root = os.path.abspath(root)
    groups = [g.strip() for g in (args.only.split(",") if args.only else GROUPS) if g.strip()]
    unknown = [g for g in groups if g not in CHECKS]
    if unknown:
        print("repo_lint: unknown group(s): %s. Known: %s" % (", ".join(unknown), ", ".join(GROUPS)), file=sys.stderr)
        return 2
    allow = [{"check": c, "match": m, "reason": r} for c, m, r in BUILTIN_ALLOW]
    if args.allow:
        try:
            with open(args.allow, encoding="utf-8") as handle:
                allow += json.load(handle).get("allow", [])
        except (OSError, ValueError, AttributeError) as problem:
            print("repo_lint: cannot read the allow file: %s" % problem, file=sys.stderr)
            return 2

    files, from_git = tracked_files(root)
    report = Report()
    report.stats["files_checked"] = len(files)
    report.stats["file_list_from"] = "git ls-files" if from_git else "directory walk (not a git checkout)"
    for group in groups:
        try:
            CHECKS[group](root, files, report)
        except Exception as problem:  # a broken check must not hide the others
            report.error("lint-crash", group, "the %s checks stopped with %s: %s" % (group, type(problem).__name__, problem))

    kept, allowed = [], 0
    for finding in report.findings:
        hay = "%s %s" % (finding["path"], finding["message"])
        if any(rule.get("check") == finding["check"] and rule.get("match", "") in hay for rule in allow):
            allowed += 1
            continue
        kept.append(finding)
    order = {"error": 0, "warning": 1, "info": 2}
    kept.sort(key=lambda f: (order[f["severity"]], f["check"], f["path"], f["line"] or 0))
    counts = {level: sum(1 for f in kept if f["severity"] == level) for level in order}
    failed = bool(counts["error"] or (args.strict and counts["warning"]))

    if args.json:
        print(json.dumps({"root": root, "groups": groups, "counts": counts, "allowed": allowed, "ok": not failed,
                          "skipped": report.skipped, "stats": report.stats, "findings": kept}, indent=1))
    else:
        print("repo_lint: %s (%d files, %s)" % (root, len(files), report.stats["file_list_from"]))
        for level in ("error", "warning", "info"):
            rows = [f for f in kept if f["severity"] == level]
            if not rows or (level == "info" and args.no_info):
                continue
            print("\n%s (%d)" % (level.upper() + "S" if level != "info" else "INFO", len(rows)))
            for finding in rows:
                place = finding["path"] + (":%d" % finding["line"] if finding["line"] else "")
                print("  [%s] %s: %s" % (finding["check"], place, finding["message"]))
        if report.skipped:
            print("\nSKIPPED")
            for row in report.skipped:
                print("  " + row)
        print("\nResult: %d error(s), %d warning(s), %d info, %d allowed by exception. %s"
              % (counts["error"], counts["warning"], counts["info"], allowed, "FAIL" if failed else "PASS"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
