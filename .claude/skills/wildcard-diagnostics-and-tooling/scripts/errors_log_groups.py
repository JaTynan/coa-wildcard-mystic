#!/usr/bin/env python3
"""Group the lines of Errors.log (or any plain server log) by their shape and count them.

What the file is
    Core\\Logs\\Errors.log is the world server's error appender. In the core's default config it has
    no timestamps and is started afresh at each server start (Appender.Errors=2,2,0,Errors.log,w in
    worldserver.conf.dist). The copy taken on 22 Nov 2026 fits that: 38,273 lines, no timestamps,
    one start's worth of loading messages (a line the loader prints once per start appears once).
    So the file is "this start only", and most of it is written while the world loads.

What it prints
    One row per line shape: numbers, hex values and quoted names are replaced by placeholders, so
    "creature (Entry: 123 GUID: 456)" and "creature (Entry: 124 GUID: 999)" count as one kind. With
    --baseline OLDER_FILE it marks the kinds that are new since that file: the patch-night notes
    treat "a new kind of line in Errors.log since the last start" as something wrong.

No project threshold exists for error counts (propose one through wildcard-validation-and-qa).

Examples
    python errors_log_groups.py "C:\\Games\\CoA Server\\Core\\Logs\\Errors.log"
    python errors_log_groups.py Errors.log --top 40 --contains spell
    python errors_log_groups.py Errors.log --baseline Errors-yesterday.log

Tested on 2026-11-22 against the real Errors.log copied from the server that day (one day of
data) and against the SYNTHETIC samples in samples\\. Check the output by eye when a log's format changes.
Python 3.8+, standard library only.
"""
import argparse
import re
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import TESTED_REAL, read_lines, safe_stdout, table  # noqa: E402

STAMP = re.compile(r"^\d{4}-\d\d-\d\d[ _T]\d\d:\d\d:\d\d\s+")
LEVEL = re.compile(r"^(FATAL|ERROR|WARN|INFO|DEBUG|TRACE)\s+")


def shape(line):
    text = STAMP.sub("", line)
    text = LEVEL.sub("", text)
    text = re.sub(r"'[^']*'", "'S'", text)
    text = re.sub(r'"[^"]*"', '"S"', text)
    text = re.sub(r"\b0x[0-9A-Fa-f]+\b", "X", text)
    text = re.sub(r"\b[0-9A-Fa-f]{16,}\b", "X", text)
    text = re.sub(r"-?\d+(?:\.\d+)?", "N", text)
    return re.sub(r"\s+", " ", text).strip()


def group(path, contains=None):
    groups = {}
    lines = blank = 0
    for number, raw in enumerate(read_lines(path), 1):
        lines += 1
        if not raw.strip():
            blank += 1
            continue
        if contains and contains.lower() not in raw.lower():
            continue
        key = shape(raw)
        entry = groups.setdefault(key, {"count": 0, "first": number, "last": number, "example": raw})
        entry["count"] += 1
        entry["last"] = number
    return groups, lines, blank


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log", type=Path, help="Errors.log (or Server.log, a console log)")
    parser.add_argument("--top", type=int, default=25, help="how many kinds to show, most frequent first (default 25)")
    parser.add_argument("--contains", metavar="TEXT", help="only lines containing this text (any letter case)")
    parser.add_argument("--baseline", type=Path, metavar="OLDER_FILE",
                        help="an older copy of the log: kinds not in it are marked NEW and listed first")
    parser.add_argument("--width", type=int, default=150, help="cut examples at this many characters")
    return parser


def main(argv=None):
    safe_stdout()
    args = build_parser().parse_args(argv)
    for path in (args.log, args.baseline):
        if path and not path.is_file():
            print(f"No such file: {path}", file=sys.stderr)
            return 2
    groups, lines, blank = group(args.log, args.contains)
    print(f"File: {args.log}")
    print(f"Lines read: {lines}; blank: {blank}; lines counted: {sum(g['count'] for g in groups.values())}; "
          f"kinds of line: {len(groups)}.")
    old = None
    if args.baseline:
        old, old_lines, _ = group(args.baseline, args.contains)
        fresh = [k for k in groups if k not in old]
        print(f"Baseline {args.baseline}: {old_lines} lines, {len(old)} kinds. Kinds here that are not in it: {len(fresh)}.")
    if not groups:
        print("Nothing to group.")
        return 0
    ranked = sorted(groups.items(), key=lambda item: ((old is not None and item[0] in old), -item[1]["count"]))
    shown = ranked[:args.top]
    rows = []
    for number, (key, entry) in enumerate(shown, 1):
        row = [f"#{number}", entry["count"], entry["first"], entry["last"]]
        if old is not None:
            row.append("NEW" if key not in old else str(old[key]["count"]))
        rows.append(row)
    heads = ["", "count", "first line", "last line"] + (["in baseline"] if old is not None else [])
    print()
    print(table(heads, rows))
    print()
    for number, (key, entry) in enumerate(shown, 1):
        print(f"#{number}  {entry['example'][:args.width]}{'...' if len(entry['example']) > args.width else ''}")
    if len(ranked) > len(shown):
        print(f"... and {len(ranked) - len(shown)} more kind(s); raise --top to see them.")
    print()
    print(TESTED_REAL.format(what="Errors.log"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
