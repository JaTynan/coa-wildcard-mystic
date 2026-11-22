#!/usr/bin/env python3
"""tested_inventory.py - what this repository RECORDS as tested, counted from its own files.

Usage (python 3.8+, standard library only, reads files and git history, changes nothing):

    python3 -I .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py            # text
    python3 -I .../tested_inventory.py --json
    python3 -I .../tested_inventory.py --list-tested      # every tracker row with a recorded result
    python3 -I .../tested_inventory.py --ref origin/main  # which history the patch search reads (default HEAD)

Four parts:
  1. enchants/tracker.csv         rows by status, and how many carry a result in the `tested` column
  2. enchants/test-checklist.csv  rows by test type, and how many have a `result`
  3. enchants/*-history.csv       the generated per-quality status of each legendary / epic copy
  4. patches/*                    for each patch file, whether any commit message that touched it records a test
                                  (in game, on live data, a compile or syntax check, a data check)

Part 4 is a keyword search of commit messages. It finds what was WRITTEN DOWN, not what was done: a test nobody
recorded is invisible here, and pull request descriptions (not stored in git) are not searched.
"""
import argparse
import collections
import csv
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder

EVIDENCE = [
    # (class, meaning, pattern)
    ("in-game", "someone exercised it on the running server",
     re.compile(r"tested in game|in-game test(?!ing)|auditioned in game|tested \d{1,2} (?:nov|oct|dec)|"
                r"tested on the live|test results|pass(?:es)? in game", re.I)),
    ("compile", "compiled or syntax-checked against the core, never run",
     re.compile(r"compiles (?:clean|with)|syntax-checked|compile-checked|compiles clean", re.I)),
    ("data-check", "compared with game data or the core's code, never run",
     re.compile(r"checked against|checked: |verified against", re.I)),
]
RESULT_WORDS = [
    ("pass", re.compile(r"\bpass\b", re.I)),
    ("fail", re.compile(r"\bfail|\bbroken\b|taken out|does nothing|never trigger|did not fire|no change visible", re.I)),
]


def find_root(start):
    here = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(here, "patches")) and os.path.isfile(os.path.join(here, "CHANGES.md")):
            return here
        parent = os.path.dirname(here)
        if parent == here:
            return None
        here = parent


def rows_of(path):
    with open(path, newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def verdict(text):
    """pass / fail / partial / other for a free-text result, by its first word and a few keywords."""
    body = re.sub(r"^20\d\d-\d\d-\d\d\s*", "", text or "").strip()
    if not body:
        return "date only"
    low = body.lower()
    if low.startswith("pass"):
        return "pass"
    if low.startswith("fail"):
        return "fail"
    if low.startswith("partly") or ";" in body or " no " in " " + low + " " or "not " in low:
        return "partial or with a caveat"
    return "other (read it)"


def tracker(root):
    path = os.path.join(root, "enchants", "tracker.csv")
    if not os.path.exists(path):
        return None
    rows = rows_of(path)
    by_status = collections.OrderedDict()
    tested_rows = []
    for row in rows:
        status = row.get("status") or "(blank)"
        entry = by_status.setdefault(status, {"rows": 0, "tested": 0})
        entry["rows"] += 1
        if (row.get("tested") or "").strip():
            entry["tested"] += 1
            tested_rows.append(row)
    dates = collections.Counter((row["tested"].strip()[:10] if re.match(r"20\d\d-\d\d-\d\d", row["tested"].strip())
                                 else "(no date)") for row in tested_rows)
    # Where the tested cell is only a date, the words are in the notes column.
    verdicts = collections.Counter(
        verdict(row["tested"]) if verdict(row["tested"]) != "date only" else "date only; notes say: " + verdict(row.get("notes"))
        for row in tested_rows)
    return {
        "rows": len(rows),
        "by_status": collections.OrderedDict(sorted(by_status.items(), key=lambda item: -item[1]["rows"])),
        "tested_rows": len(tested_rows),
        "untested_rows": len(rows) - len(tested_rows),
        "tested_by_date": dict(sorted(dates.items())),
        "tested_by_verdict": dict(verdicts.most_common()),
        "changed_by_us": sum(v["rows"] for k, v in by_status.items() if k in ("live", "live (after restart)", "verified")),
        "list": [{"spell": r.get("spell"), "name": r.get("name"), "status": r.get("status"), "tested": r.get("tested"),
                  "notes": (r.get("notes") or "")[:160]} for r in tested_rows],
    }


def checklist(root):
    path = os.path.join(root, "enchants", "test-checklist.csv")
    if not os.path.exists(path):
        return None
    rows = rows_of(path)
    by_type = collections.OrderedDict()
    for row in rows:
        entry = by_type.setdefault(row.get("test type") or "(blank)", {"rows": 0, "with_result": 0})
        entry["rows"] += 1
        if (row.get("result") or "").strip():
            entry["with_result"] += 1
    filled = [row for row in rows if (row.get("result") or "").strip()]
    return {
        "rows": len(rows),
        "with_result": len(filled),
        "without_result": len(rows) - len(filled),
        "short_rows_missing_the_result_column": sum(1 for row in rows if row.get("result") is None),
        "by_test_type": collections.OrderedDict(sorted(by_type.items(), key=lambda item: -item[1]["rows"])),
        "results_by_verdict": dict(collections.Counter(verdict(row["result"]) for row in filled).most_common()),
        "sql_files_covered": sorted({row.get("file") or "" for row in rows}),
    }


def histories(root):
    out = collections.OrderedDict()
    folder = os.path.join(root, "enchants")
    if not os.path.isdir(folder):
        return out
    for name in sorted(os.listdir(folder)):
        if not name.endswith("-history.csv"):
            continue
        rows = rows_of(os.path.join(folder, name))
        out[name] = {
            "rows": len(rows),
            "by_status": dict(collections.Counter(row.get("status") or "(blank)" for row in rows).most_common()),
            "with_test_result": sum(1 for row in rows if (row.get("tested") or "").strip()),
        }
    return out


def patches(root, ref):
    folder = os.path.join(root, "patches")
    out = collections.OrderedDict()
    for name in sorted(os.listdir(folder)):
        if not name.endswith((".ps1", ".patch")):
            continue
        try:
            log = subprocess.run(["git", "-C", root, "log", ref, "--format=%x01%h%x02%ad%x02%B", "--date=short", "--",
                                  "patches/" + name], capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            return None
        if log.returncode != 0:
            return None
        commits = [c for c in log.stdout.split("\x01") if c.strip()]
        found = []
        for commit in commits:
            parts = commit.split("\x02", 2)
            if len(parts) < 3:
                continue
            short, date, body = parts
            for row in body.split("\n"):
                for label, _, pattern in EVIDENCE:
                    if pattern.search(row):
                        found.append({"class": label, "commit": short, "date": date, "line": " ".join(row.split())[:200]})
        classes = sorted({item["class"] for item in found})
        out[name] = {"commits": len(commits), "evidence_classes": classes, "evidence": found}
    return out


def main():
    parser = argparse.ArgumentParser(description="Count what the repository records as tested.")
    parser.add_argument("--root")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--list-tested", action="store_true", help="also print every tracker row with a result")
    parser.add_argument("--ref", default="HEAD", help="git ref whose history is searched for patch tests (default HEAD)")
    args = parser.parse_args()
    root = args.root or find_root(os.path.dirname(os.path.abspath(__file__))) or find_root(os.getcwd())
    if not root:
        print("tested_inventory: cannot find the repository root; use --root", file=sys.stderr)
        return 2
    data = {"root": root, "ref": args.ref, "tracker": tracker(root), "checklist": checklist(root),
            "histories": histories(root), "patches": patches(root, args.ref)}
    if args.json:
        print(json.dumps(data, indent=1))
        return 0

    t = data["tracker"]
    if t:
        print("1. enchants/tracker.csv: %d enchants" % t["rows"])
        print("   %-24s %6s %8s %9s" % ("status", "rows", "tested", "untested"))
        for status, entry in t["by_status"].items():
            print("   %-24s %6d %8d %9d" % (status, entry["rows"], entry["tested"], entry["rows"] - entry["tested"]))
        print("   %-24s %6d %8d %9d" % ("TOTAL", t["rows"], t["tested_rows"], t["untested_rows"]))
        print("   Rows we changed (live, live (after restart), verified): %d; with a recorded result: %d"
              % (t["changed_by_us"], sum(e["tested"] for s, e in t["by_status"].items()
                                         if s in ("live", "live (after restart)", "verified"))))
        print("   Results by date: " + ", ".join("%s: %d" % item for item in t["tested_by_date"].items()))
        print("   Results by kind: " + ", ".join("%s: %d" % item for item in t["tested_by_verdict"].items()))
        if args.list_tested:
            for row in t["list"]:
                print("     %-8s %-28s %-22s %s | %s" % (row["spell"], row["name"][:28], row["status"], row["tested"][:60],
                                                       row["notes"][:90]))
    c = data["checklist"]
    if c:
        print("\n2. enchants/test-checklist.csv: %d test rows, %d with a result, %d without (%d of those rows are short: "
              "no result column at all)" % (c["rows"], c["with_result"], c["without_result"],
                                            c["short_rows_missing_the_result_column"]))
        print("   %-28s %5s %12s" % ("test type", "rows", "with result"))
        for kind, entry in c["by_test_type"].items():
            print("   %-28s %5d %12d" % (kind, entry["rows"], entry["with_result"]))
        print("   Results by kind: " + ", ".join("%s: %d" % item for item in c["results_by_verdict"].items()))
        print("   SQL file numbers covered: " + " ".join(c["sql_files_covered"]))
    if data["histories"]:
        print("\n3. Generated history files")
        for name, entry in data["histories"].items():
            print("   %s: %d rows, %d with a test result" % (name, entry["rows"], entry["with_test_result"]))
            for status, count in entry["by_status"].items():
                print("      %5d  %s" % (count, status))
    p = data["patches"]
    print("\n4. patches/: tests recorded in commit messages (ref %s)" % args.ref)
    if p is None:
        print("   git history not readable here; skipped")
    else:
        groups = collections.OrderedDict((("in-game", []), ("compile", []), ("data-check", []), ("none", [])))
        for name, entry in p.items():
            classes = entry["evidence_classes"]
            best = next((c for c in ("in-game", "compile", "data-check") if c in classes), "none")
            groups[best].append(name)
        for label, meaning, _ in EVIDENCE:
            print("   %s (%s): %d" % (label, meaning, len(groups[label])))
            for name in groups[label]:
                first = next(e for e in p[name]["evidence"] if e["class"] == label)
                print("      %-46s %s %s  \"%s\"" % (name, first["commit"], first["date"], first["line"][:90]))
        print("   none recorded: %d of %d" % (len(groups["none"]), len(p)))
        for name in groups["none"]:
            print("      %s" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
