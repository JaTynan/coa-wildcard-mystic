#!/usr/bin/env python3
"""Static check of the architecture contract (the numbered invariants in SKILL.md).

Usage:  python3 -I .claude/skills/wildcard-architecture-contract/scripts/check_contract.py [repo root] [--strict]

Runs from any folder: the repository root defaults to the repository this script sits in.
Reads the repository only (files and `git` history); changes nothing and needs no network, no server and no
database. Python 3 standard library only. Each line is PASS, KNOWN, FAIL or INFO with the invariant number it
belongs to. FAIL means the invariant does not hold as written today; it does not by itself mean the server is
broken. KNOWN is a FAIL whose exact text is in the KNOWN_FAILS list below: the violations already understood and
listed under "Known violations" in SKILL.md as of 2026-11-22. A known line whose text changes (one more file, one
more commit) becomes a FAIL again on purpose.

Exit codes: 0 = no FAIL (KNOWN lines allowed); 1 = at least one FAIL, or with --strict at least one FAIL or KNOWN;
2 = the folder given is not the repository root.

This script is the authority for the architecture invariants only. The full pre-merge check set, and which script
is the authority for which check, is listed in the skill wildcard-validation-and-qa.

What it cannot check (needs the pinned sources, a build, the VM or MySQL): I1 (the patches fit the newest core), that
the SQL really runs twice without error, and anything about the live server (I13, I15, I16).
"""
import argparse
import collections
import os
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True

_parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
_parser.add_argument('root', nargs='?',
                     default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'),
                     help='repository root (default: the repository this script sits in)')
_parser.add_argument('--strict', action='store_true', help='exit 1 on KNOWN lines too')
_opts = _parser.parse_args()
REPO = os.path.abspath(_opts.root)
STRICT = _opts.strict
if not os.path.isfile(os.path.join(REPO, 'CHANGES.md')):
    print(f'Not the repository root (no CHANGES.md): {REPO}\nPass the root as the first argument.', file=sys.stderr)
    sys.exit(2)
fails = 0
known = 0
# Exact FAIL lines already understood (SKILL.md, "Known violations"; re-checked 2026-11-24: V1, V6 and V8 cleared). Compared as
# "[invariant] text". Remove a line here when its violation is fixed; never add one without a V-row in SKILL.md.
KNOWN_FAILS = {
    "[I3] README.md names missing patch files: ['mystic-enchants-skip-missing.patch']",
    '[I7] spell_proc rows written but not listed in wcme_owned, so 000-reset never removes them: 005: [282040, 285100]; 007: [276302, 979137]; 017: [1587050]; 020: [1180480]; 038: [1544910]',
    "[I7] deletes every script binding of the listed spells, the core's own included, and nothing restores those: 015 (24 spell ids), 016 (31 spell ids)",
    '[I7] changes that deleting the file does NOT undo (outside 000-reset): 026: spell_proc row -44445 (a core row, changed in place); 090: MySQL server variables (SET PERSIST); 095: MySQL server variables (SET PERSIST); 100: creature_loot_template, gameobject_loot_template, item_loot_template, quest_template, reference_loot_template; 110: item_template; 120: item_template; 130: spell_area; 160: currencytypes_dbc, item_template; 161: npc_vendor',
}


def rd(path):
    with open(os.path.join(REPO, path), encoding='utf-8', errors='replace') as handle:
        return handle.read()


def ls(path, suffix=''):
    return sorted(f for f in os.listdir(os.path.join(REPO, path)) if f.endswith(suffix))


def git(*a):
    try:
        return subprocess.run(['git', '-C', REPO] + list(a), capture_output=True, text=True, timeout=60).stdout
    except (OSError, subprocess.SubprocessError):
        return ''


def say(level, inv, text):
    global fails, known
    if level == 'FAIL':
        if f'[{inv}] {text}' in KNOWN_FAILS:
            level, known = 'KNOWN', known + 1
        else:
            fails += 1
    print(f'{level:5} [{inv}] {text}')


def check(ok, inv, good, bad):
    say('PASS' if ok else 'FAIL', inv, good if ok else bad)


def statements(text):
    """Split SQL into statements, ignoring ; and -- inside quoted strings."""
    out, cur, quoted, i = [], [], False, 0
    while i < len(text):
        c = text[i]
        if quoted:
            if c == '\\':
                cur.append(text[i:i + 2]); i += 2; continue
            if c == "'":
                if text[i + 1:i + 2] == "'":
                    cur.append("''"); i += 2; continue
                quoted = False
        elif c == "'":
            quoted = True
        elif text.startswith('--', i):
            j = text.find('\n', i)
            i = len(text) if j < 0 else j
            continue
        elif c == ';':
            out.append(''.join(cur).strip()); cur = []; i += 1; continue
        cur.append(c); i += 1
    if ''.join(cur).strip():
        out.append(''.join(cur).strip())
    return [s for s in out if s]


# ---------------------------------------------------------------- I2, I3: patches and CHANGES.md / README.md
changes = rd('CHANGES.md')
patches = ls('patches')
scripts = [p for p in patches if p.endswith('.ps1')]
missing = [p for p in patches if p not in changes and
           not (p.startswith('mystic-enchants-') and p.endswith('.patch') and 'mystic-enchants-*.patch' in changes)]
check(not missing, 'I3', f'all {len(patches)} files in patches/ have a CHANGES.md row',
      f'no CHANGES.md row for: {", ".join(missing)}')
named = set(re.findall(r'`((?:\d\d-[a-z0-9-]+\.ps1)|(?:[a-z-]+\.patch))`', changes))
ghost = sorted(named - set(patches))
check(not ghost, 'I3', 'CHANGES.md names no patch file that is gone', f'CHANGES.md names missing files: {ghost}')
readme_named = set(re.findall(r'patches/([\w.-]+\.(?:patch|ps1))', rd('README.md')))
ghost = sorted(readme_named - set(patches))
check(not ghost, 'I3', 'README.md names no patch file that is gone', f'README.md names missing patch files: {ghost}')

numbers = collections.Counter(re.match(r'\d+', p).group(0) for p in scripts if re.match(r'\d+-', p))
unnumbered = [p for p in scripts if not re.match(r'\d\d-', p)]
dupes = [n for n, c in numbers.items() if c > 1]
check(not dupes and not unnumbered, 'I2', f'{len(scripts)} patch scripts, each with its own two-digit number',
      f'duplicate numbers {dupes}, unnumbered {unnumbered}')
weak, nostop = [], []
for p in scripts:
    text = rd('patches/' + p)
    if "$ErrorActionPreference = 'Stop'" not in text or 'throw' not in text:
        nostop.append(p)
    if not re.search(r'\.Count\s*-ne\s*1', text):
        weak.append(p)
check(not nostop, 'I2', 'every patch script stops on error and throws when an anchor is missing',
      f'no Stop preference or no throw in: {nostop}')
say('INFO', 'I2', f'{len(weak)} script(s) only check an anchor is present, never that it is there exactly once: '
    + (', '.join(w.split("-")[0] for w in weak) or 'none'))

# ---------------------------------------------------------------- I4: settings a patch reads are in the list
settings_text = rd('server-settings/server-settings.txt')
keys, seen = set(), collections.Counter()
for line in settings_text.splitlines():
    m = re.match(r'^\s*([^|#]+?)\s*\|\s*([^=\s]+)\s*=\s*(.*?)\s*$', line)
    if m:
        keys.add(m.group(2)); seen[(m.group(1).lower(), m.group(2).lower())] += 1
read, composed = collections.defaultdict(set), collections.defaultdict(set)
for p in patches:
    text = rd('patches/' + p)
    if p.endswith('.patch'):
        text = '\n'.join(l[1:] for l in text.splitlines() if l.startswith('+') and not l.startswith('+++'))
    text = text.replace('`"', '"')
    for m in re.finditer(r'GetOption<[^>]+>\(\s*("([^"]+)"|[^,]+),', text):
        (read[m.group(2)] if m.group(2) else composed[m.group(1).strip()]).add(p)
unlisted = {k: sorted(v) for k, v in read.items() if k not in keys}
check(not unlisted, 'I4', f'all {len(read)} settings the patches read by name are in server-settings.txt',
      f'read by a patch but not in server-settings.txt: {unlisted}')
say('INFO', 'I4', f'{len(composed)} setting name(s) are built at run time and must be checked by eye: '
    + '; '.join(f'{k} ({", ".join(sorted(v))})' for k, v in sorted(composed.items())))
dup = [k for k, c in seen.items() if c > 1]
check(not dup, 'I5', f'{sum(seen.values())} settings lines, none listed twice for the same file',
      f'listed twice: {dup}')
check(bool(re.search(r'(?m)^\s*realm\s*\|\s*active\s*=\s*wildcard\s*$', settings_text)), 'I5',
      'the settings list names its realm (realm | active = wildcard)', 'no "realm | active = wildcard" line')

# ---------------------------------------------------------------- I6, I7: SQL
sqldir = 'sql/enchants'
sqlfiles = ls(sqldir, '.sql')
prefixes = collections.Counter(f.split('-')[0] for f in sqlfiles)
check(sqlfiles and sqlfiles[0] == '000-reset.sql' and not [p for p, c in prefixes.items() if c > 1], 'I6',
      f'{len(sqlfiles)} SQL files, 000-reset.sql sorts first, no number used twice',
      f'first file {sqlfiles[:1]}, repeated numbers {[p for p, c in prefixes.items() if c > 1]}')
stm = [(f, s) for f in sqlfiles for s in statements(rd(f'{sqldir}/{f}'))]
owned = collections.defaultdict(set)
dynamic = set()
for f, s in stm:
    if re.match(r'(?is)INSERT (IGNORE )?INTO `wcme_owned`', s):
        for table, ident in re.findall(r"\('(\w+)',\s*(-?\d+)\)", s):
            owned[table].add(int(ident))
        if 'SELECT' in s.upper():
            dynamic.add(f)


def row_ids(s):
    return [int(x) for x in re.findall(r'(?m)^\s*\(\s*(-?\d+)\s*,', s[s.upper().find('VALUES') + 6:])]


for table, key in (('spell_proc', 'spell_proc'), ('spell_dbc', 'spell_dbc'), ('coa_mystic_enchant_aura_link', 'aura_link')):
    loose = collections.defaultdict(list)
    for f, s in stm:
        if re.match(r'(?is)(INSERT INTO|REPLACE INTO|INSERT IGNORE INTO) `?%s`?' % table, s):
            if table == 'spell_dbc' and f in dynamic:
                continue   # these files register each id themselves, only where the id was free
            loose[f] += [i for i in row_ids(s) if i not in owned[key]]
    loose = {f: v for f, v in loose.items() if v}
    check(not loose, 'I7', f'every {table} row written is listed in wcme_owned ({len(owned[key])} ids)',
          f'{table} rows written but not listed in wcme_owned, so 000-reset never removes them: '
          + '; '.join(f'{f[:3]}: {v}' for f, v in sorted(loose.items())))
bad = []
for f, s in stm:
    if re.match(r'(?is)INSERT INTO `?spell_linked_spell', s):
        rows = len(re.findall(r'(?m)^\s*\(', s[s.upper().find('VALUES'):]))
        if rows != s.count("'WCME:"):
            bad.append(f)
check(not bad, 'I7', 'every spell_linked_spell row carries a WCME: comment', f'rows without WCME: in {bad}')
bad = []
for f, s in stm:
    if re.match(r'(?is)INSERT INTO `?spell_script_names', s):
        bad += [f'{f}: {n}' for n in set(re.findall(r"'([A-Za-z_0-9]+)'", s)) if not n.startswith('spell_wcme_')]
check(not bad, 'I7', 'every script name bound by SQL starts with spell_wcme_', f'other script names: {bad}')
bad = [f'{f[:3]} ({len(re.findall(chr(92) + "d+", s))} spell ids)' for f, s in stm
       if re.match(r'(?is)DELETE FROM `?spell_script_names', s) and 'ScriptName' not in s]
check(not bad, 'I7', 'no file deletes script bindings by spell id alone',
      'deletes every script binding of the listed spells, the core\'s own included, and nothing restores those: '
      + ', '.join(bad))
ours = re.compile(r'^(wcme_|spell_dbc$|spell_proc$|spell_linked_spell$|spell_script_names$|coa_mystic_enchant_aura_link$)')
outside = collections.defaultdict(set)
for f, s in stm:
    if f == '000-reset.sql':
        continue
    m = re.match(r'(?is)(UPDATE|INSERT INTO|INSERT IGNORE INTO|REPLACE INTO|DELETE FROM|ALTER TABLE) `?(\w+)`?', s)
    if m and not ours.match(m.group(2)):
        outside[f].add(m.group(2))
    if re.match(r'(?is)SET PERSIST', s):
        outside[f].add('MySQL server variables (SET PERSIST)')
    m = re.match(r'(?is)UPDATE `?(spell_proc|spell_dbc)`?.*?WHERE\s+`?(?:SpellId|ID)`?\s*=\s*(-?\d+)', s)
    if m and int(m.group(2)) not in owned[m.group(1)]:
        outside[f].add(f'{m.group(1)} row {m.group(2)} (a core row, changed in place)')
# Core rows removed, or replaced by a row we own: deleting the file makes the reset delete OUR row and nothing puts
# the core's back. Seen from the repository alone only in part: the review file of replaced core proc rows, owned
# all-rank (negative) spell_proc ids, and deletes of a script binding that is not one of ours.
replaced = collections.defaultdict(set)
try:
    import csv as _csv, io as _io
    for row in _csv.DictReader(_io.StringIO(rd('enchants/core-proc-row-replacements.csv'))):
        if 'restored' not in row.get('status', '') and row.get('spell', '').lstrip('-').isdigit():
            ident = int(row['spell'])
            for f, s in stm:
                if re.search(r"\('spell_proc',\s*%d\)" % ident, s):
                    replaced[f].add(f'core spell_proc row {ident} replaced and owned')
except OSError:
    pass
for f, s in stm:
    for ident in re.findall(r"\('spell_proc',\s*(-\d+)\)", s):
        replaced[f].add(f'all-rank spell_proc row {ident} owned (a stock row if the core ships it)')
    m = re.match(r"(?is)DELETE FROM `?spell_script_names`?.*?`?ScriptName`?\s*=\s*'([A-Za-z_0-9]+)'", s)
    if m and not m.group(1).startswith('spell_wcme_'):
        replaced[f].add(f'deletes the script binding {m.group(1)} (not one of ours)')
if replaced:
    say('INFO', 'I7', 'core rows removed or replaced-and-owned, which deleting the file does not bring back '
        '(full list and reasoning: ascension-restoration/references/reset-limits.md): '
        + '; '.join(f'{f[:3]}: {", ".join(sorted(v))}' for f, v in sorted(replaced.items())))
check(not outside, 'I7', 'no SQL file changes anything 000-reset cannot put back',
      'changes that deleting the file does NOT undo (outside 000-reset): '
      + '; '.join(f'{f[:3]}: {", ".join(sorted(v))}' for f, v in sorted(outside.items())))

# ---------------------------------------------------------------- I8, I9: public repository
tracked = [f for f in git('ls-files').split('\n') if f]
if tracked:
    game = [f for f in tracked if re.search(r'\.(mpq|dbc|blp|m2|wmo|adt|wdt|exe|dll)$', f, re.I)]
    check(not game, 'I8', f'no client or game binaries among {len(tracked)} tracked files', f'tracked game files: {game}')
    pyc = [f for f in tracked if f.endswith('.pyc')]
    check(not pyc, 'I8', 'no compiled Python tracked', f'compiled Python is tracked although .gitignore lists __pycache__/: {pyc}')
    secret = re.compile(r'github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|BEGIN (?:RSA|OPENSSH) PRIVATE KEY')
    hits, links = [], []
    for f in tracked:
        path = os.path.join(REPO, f)
        if not os.path.isfile(path) or os.path.getsize(path) > 2_000_000:
            continue
        try:
            text = rd(f)
        except OSError:
            continue
        if secret.search(text):
            hits.append(f)
        # A placeholder such as /share/<id> in a document is not a link.
        if re.search(r'https?://[^\s"\'<]*/share/[^\s"\'<]+', text):
            links.append(f)
    check(not hits, 'I9', 'no token-shaped secret in tracked files', f'token-shaped text in: {hits}')
    check(not links, 'I8', 'no share link to the client archive in tracked files',
          f'a share link (the whole client archive) is published in: {links}')
    prose = {}
    for f in sqlfiles:
        text = rd(f'{sqldir}/{f}')
        if 'spell_dbc' in text and f != '150-custom-spells.sql':
            count = sum(1 for s in re.findall(r"'((?:[^'\\]|\\.|'')*)'", re.sub(r'--[^\n]*', '', text))
                        if len(s) >= 40 and ' ' in s)
            if count:
                prose[f[:3]] = count
    say('INFO', 'I8', 'spell_dbc rows carrying long text (names, descriptions; decide whether this counts as '
        f'tooltip text): {prose}')
else:
    say('INFO', 'I8', 'not a git checkout: tracked-file checks skipped')

# ---------------------------------------------------------------- I10: pins
workflow = rd('.github/workflows/build-worldserver.yml')
pins = set(re.findall(r'\b[0-9a-f]{40}\b', workflow))
chat_readme = rd('ollama-chat/README.md')
check(len(pins) == 1 and next(iter(pins))[:7] in chat_readme, 'I10',
      f'mod-ollama-chat is pinned to one commit ({next(iter(pins), "?")[:7]}) in the workflow and ollama-chat/README.md',
      f'mod-ollama-chat pins disagree: workflow {sorted(pins)}, ollama-chat/README.md')
bad = [l for l in rd('addon/third-party-addons.txt').splitlines()
       if l.strip() and not l.startswith('#') and not re.match(r'^[\w.-]+/[\w.-]+ \| [0-9a-f]{40} \| \S', l)]
check(not bad, 'I10', 'every third-party addon is pinned to a full commit', f'not pinned: {bad}')
floating = sorted(set(re.findall(r'uses:\s*(\S+@v\d+)', workflow)))
say('INFO', 'I10', f'GitHub Actions used by tag, not commit: {", ".join(floating)}')

# ---------------------------------------------------------------- I11: client and server copies of our own spells
py_ids = set(int(x) for x in re.findall(r'\b(99900\d\d)\b', rd('client-patch/custom_spells.py')))
sql_ids = set(int(x) for x in re.findall(r"\('spell_dbc', (99900\d\d)\)", rd(f'{sqldir}/150-custom-spells.sql')))
check(py_ids == sql_ids, 'I11', f'{len(py_ids)} custom spell ids, the same in client-patch/custom_spells.py and 150-custom-spells.sql',
      f'only in the client script: {sorted(py_ids - sql_ids)}; only in the SQL: {sorted(sql_ids - py_ids)}')

# ---------------------------------------------------------------- I12, I14: history
tags = [t for t in git('tag', '-l', 'wcme-server-*').split('\n') if t]
main = 'origin/main' if git('rev-parse', '--verify', '-q', 'origin/main').strip() else 'HEAD'
if tags:
    newest = max(tags, key=lambda t: int(re.search(r'build(\d+)$', t).group(1)) if re.search(r'build(\d+)$', t) else 0)
    behind = [l for l in git('log', '--no-merges', '--format=%h %ad %s', '--date=short', f'{newest}..{main}', '--', 'patches/').split('\n') if l]
    # Since PR #241 the daily workflow builds a merged patch the same evening, so an unbuilt patch commit is normal
    # for about a day. It is a FAIL only when the oldest one is more than 36 hours old (a missed or failed build).
    stamps = [int(x) for x in git('log', '--no-merges', '--format=%ct', f'{newest}..{main}', '--', 'patches/').split() if x.isdigit()]
    stale = bool(stamps) and (time.time() - min(stamps)) > 36 * 3600
    level = 'FAIL' if stale else 'INFO'
    note = '' if not behind else (' (older than 36 h: the automatic build missed them)' if stale else ' (normal: the next automatic evening build picks them up)')
    say(level, 'I14', f'newest build tag {newest}; patch commits on {main} that no build contains: {len(behind)}{note}'
        + ''.join(f'\n          {l}' for l in behind))
    off = [t for t in tags if subprocess.run(['git', '-C', REPO, 'merge-base', '--is-ancestor',
                                              git('rev-list', '-1', t).strip(), main]).returncode]
    say('INFO', 'I12', f'{len(tags)} release tags; built from a commit that is not on {main}: {off or "none"}')
else:
    say('INFO', 'I14', 'no wcme-server-* tags in this checkout: build history checks skipped')
if git('rev-parse', '--verify', '-q', 'origin/for-083').strip():
    merged = subprocess.run(['git', '-C', REPO, 'merge-base', '--is-ancestor', 'origin/for-083', main]).returncode == 0
    check(not merged, 'I12', 'for-083 has not been merged into main', 'for-083 is an ancestor of main')

packaged = re.findall(r'Copy-Item -Recurse _mine/addon/(\S+)', workflow)
addons = sorted(d for d in os.listdir(os.path.join(REPO, 'addon')) if os.path.isdir(os.path.join(REPO, 'addon', d)))
say('INFO', 'note', f'addons in the repo: {addons}; in the build zip: {packaged} (patch night copies all of them from main anyway)')

print(f'\n{fails} FAIL line(s), {known} KNOWN line(s). FAIL = an invariant does not hold as written and is not on '
      f'the known list; KNOWN = see SKILL.md, "Known violations".')
sys.exit(1 if fails or (known and STRICT) else 0)
