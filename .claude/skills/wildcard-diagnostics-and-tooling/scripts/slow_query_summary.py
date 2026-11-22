#!/usr/bin/env python3
"""Group MySQL's slow query log (Core\\Logs\\mysql-slow.log) by the shape of the query.

What the file is
    Since 21 Nov 2026 (commit 9ba9f45, sql/enchants/095-slow-query-log.sql) MySQL writes every query
    that took longer than 0.5 s (long_query_time) to this file. Each entry is MySQL's own layout:

        # Time: 2026-11-21T07:15:02.123456Z
        # User@Host: acore[acore] @ localhost [127.0.0.1]  Id:    11
        # Query_time: 1.842113  Lock_time: 0.000201 Rows_sent: 0  Rows_examined: 1700000
        use acore_characters_wildcard;          (only when the database changed)
        SET timestamp=1795245300;
        DELETE FROM character_spell WHERE spell = 14009999;

    The "# Time:" line is in UTC unless MySQL's log_timestamps was changed (its default is UTC; this
    repository does not set it). Timing.log and the counter CSVs are in the server's local time, so
    use --utc-offset-hours (11 for Sydney daylight time, 10 in winter) to line them up.
    Query_time is how long the statement ran; Lock_time how long it waited for locks; Rows_examined
    how many rows MySQL had to read (a large number for a small result usually means a missing index:
    the 40-second character list of November 2026 was exactly that, fixed by EnsureCharacterSpellIndexes).

What it prints
    One row per query shape ("fingerprint": numbers and quoted text replaced by ?, lists collapsed),
    with how often it appeared, total and worst time, lock time and rows examined; then an example of
    each. --by-hour and --by-minute show WHEN slow queries happened, to compare with the spike list
    from timing_summary.py.

No project threshold exists beyond the 0.5 s that decides what is logged (propose one through
wildcard-validation-and-qa).

Examples
    python slow_query_summary.py "C:\\Games\\CoA Server\\Core\\Logs\\mysql-slow.log"
    python slow_query_summary.py mysql-slow.log --utc-offset-hours 11 --by-hour
    python slow_query_summary.py mysql-slow.log --utc-offset-hours 11 --from "2026-11-22 19:00" --sort max

Tested on 2026-11-22 against the real mysql-slow.log copied from the server that day (one day of
data) and against the SYNTHETIC samples in samples\\. Check the output by eye when a log's format changes.
Python 3.8+, standard library only. Written for Windows and Linux; run so far on Linux (Python 3.13).
"""
import argparse
import re
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import TESTED_REAL, read_lines, safe_stdout, table, when_arg  # noqa: E402

RE_TIME = re.compile(r"^# Time: (\S+)(?: +(\d{1,2}:\d\d:\d\d))?")
RE_USER = re.compile(r"^# User@Host: (\S*?)\[")
RE_STATS = re.compile(r"^# Query_time: (\S+)\s+Lock_time: (\S+)\s+Rows_sent: (\S+)\s+Rows_examined: (\S+)")
RE_SET = re.compile(r"^SET timestamp=(\d+);\s*$", re.I)
RE_USE = re.compile(r"^use\s+`?([^`;\s]+)`?\s*;\s*$", re.I)
HEADER = (re.compile(r"started with:\s*$"), re.compile(r"^TCP Port:"), re.compile(r"^Time\s+Id\s+Command\s+Argument"))


def parse_time(text, clock):
    """'2026-11-21T07:15:02.123456Z' (MySQL 5.7+/8) or '261121' + '7:15:02' (older). None if unreadable."""
    try:
        if clock:
            return datetime.strptime(f"{text} {clock}", "%y%m%d %H:%M:%S")
        cleaned = re.sub(r"(Z|[+-]\d\d:\d\d)$", "", text)
        pattern = "%Y-%m-%dT%H:%M:%S.%f" if "." in cleaned else "%Y-%m-%dT%H:%M:%S"
        return datetime.strptime(cleaned, pattern)
    except ValueError:
        return None


def fingerprint(sql):
    """The query with its values taken out, so the same statement with different numbers groups together."""
    text = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    text = re.sub(r"(--|#)[^\n]*", " ", text)
    text = re.sub(r"'(?:[^'\\]|\\.|'')*'", "?", text)
    text = re.sub(r'"(?:[^"\\]|\\.|"")*"', "?", text)
    text = re.sub(r"\b0x[0-9a-fA-F]+\b", "?", text)
    text = re.sub(r"(?<![\w`.])-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?\b", "?", text)
    text = re.sub(r"\s+", " ", text).strip().rstrip(";").strip()
    text = re.sub(r"\(\s*\?(?:\s*,\s*\?)+\s*\)", "(?+)", text)
    text = re.sub(r"(\(\?\+?\))(?:\s*,\s*\(\?\+?\))+", r"\1+", text)
    return text.lower()


def parse_slow_log(path):
    """Returns (entries, stats). Each entry: time (as logged), user, query_time, lock_time, rows_sent,
    rows_examined, db, epoch, sql."""
    stats = {"lines": 0, "headers": 0, "stray": 0, "bad_entries": 0}
    entries = []
    current = None
    last_time = None
    database = None

    def close():
        nonlocal current
        if current is None:
            return
        sql = "\n".join(current.pop("lines")).strip()
        if current["query_time"] is None or not sql:
            stats["bad_entries"] += 1
        else:
            current["sql"] = sql
            entries.append(current)
        current = None

    def start():
        nonlocal current
        close()
        current = {"time": last_time, "user": None, "query_time": None, "lock_time": 0.0, "rows_sent": 0,
                   "rows_examined": 0, "db": database, "epoch": None, "lines": [], "seen_stats": False}

    for raw in read_lines(path):
        stats["lines"] += 1
        if any(pattern.search(raw) for pattern in HEADER):
            stats["headers"] += 1
            continue
        match = RE_TIME.match(raw)
        if match:
            last_time = parse_time(match.group(1), match.group(2))
            start()
            continue
        match = RE_USER.match(raw)
        if match:
            # Older MySQL leaves "# Time:" out when two entries share a second: a User line then starts one.
            if current is None or current["user"] is not None:
                start()
            current["user"] = match.group(1)
            continue
        match = RE_STATS.match(raw)
        if match:
            if current is None or current["seen_stats"]:
                start()
            current["seen_stats"] = True
            try:
                current["query_time"] = float(match.group(1))
                current["lock_time"] = float(match.group(2))
                current["rows_sent"] = int(match.group(3))
                current["rows_examined"] = int(match.group(4))
            except ValueError:
                current["query_time"] = None
            continue
        if raw.startswith("#"):
            continue                      # other comment lines MySQL may add (e.g. "# Schema:")
        if current is None or not current["seen_stats"]:
            if raw.strip():
                stats["stray"] += 1
            continue
        match = RE_SET.match(raw)
        if match and not current["lines"]:
            current["epoch"] = int(match.group(1))
            continue
        match = RE_USE.match(raw)
        if match and not current["lines"]:
            database = match.group(1)
            current["db"] = database
            continue
        current["lines"].append(raw)
    close()
    return entries, stats


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log", type=Path, help="mysql-slow.log")
    parser.add_argument("--utc-offset-hours", type=float, default=0.0, metavar="H",
                        help="add H hours to the logged times (11 = Sydney daylight time) so they match "
                             "Timing.log; --from/--to are then in that local time (default 0: as logged)")
    parser.add_argument("--from", dest="start", type=when_arg, metavar="WHEN", help="ignore entries before this")
    parser.add_argument("--to", dest="end", type=when_arg, metavar="WHEN", help="ignore entries from this on")
    parser.add_argument("--sort", choices=("total", "count", "max", "rows", "lock"), default="total",
                        help="order of the groups (default total time)")
    parser.add_argument("--top", type=int, default=20, help="how many groups to show (default 20)")
    parser.add_argument("--width", type=int, default=110, help="cut fingerprints and examples at this many characters")
    parser.add_argument("--by-hour", action="store_true", help="also count slow queries per hour")
    parser.add_argument("--by-minute", action="store_true",
                        help="also list every minute that had slow queries (to compare with Timing.log spikes)")
    return parser


def main(argv=None):
    safe_stdout()
    args = build_parser().parse_args(argv)
    if not args.log.is_file():
        print(f"No such file: {args.log}", file=sys.stderr)
        return 2
    entries, stats = parse_slow_log(args.log)
    shift = timedelta(hours=args.utc_offset_hours)
    for entry in entries:
        entry["when"] = entry["time"] + shift if entry["time"] else None
    print(f"File: {args.log}")
    print(f"Lines read: {stats['lines']}; entries: {len(entries)}; MySQL start-up header lines: {stats['headers']}; "
          f"entries skipped (unreadable numbers or no query text): {stats['bad_entries']}; "
          f"lines outside any entry: {stats['stray']}.")
    kept = entries
    if args.start:
        kept = [e for e in kept if e["when"] and e["when"] >= args.start]
    if args.end:
        kept = [e for e in kept if e["when"] and e["when"] < args.end]
    if len(kept) != len(entries):
        print(f"Entries in the chosen time range: {len(kept)}.")
    if not kept:
        if entries:
            print("No slow query was logged in the chosen time range.")
        else:
            print("No slow query entries. (An empty log is good news, if the log is switched on: "
                  "check with  SHOW VARIABLES LIKE 'slow_query_log%';)")
        return 0
    times = [e["when"] for e in kept if e["when"]]
    zone = f"logged time {args.utc_offset_hours:+g} h" if args.utc_offset_hours else "as logged (UTC unless log_timestamps was changed)"
    if times:
        print(f"From {min(times):%Y-%m-%d %H:%M:%S} to {max(times):%Y-%m-%d %H:%M:%S} ({zone}).")
    print(f"Total time in slow queries: {sum(e['query_time'] for e in kept):.1f} s; "
          f"slowest: {max(e['query_time'] for e in kept):.2f} s.\n")

    groups = {}
    for entry in kept:
        key = fingerprint(entry["sql"])
        group = groups.setdefault(key, {"count": 0, "total": 0.0, "max": 0.0, "lock": 0.0, "rows": 0, "rows_max": 0,
                                        "sent": 0, "first": None, "last": None, "example": entry, "dbs": set()})
        group["count"] += 1
        group["total"] += entry["query_time"]
        group["lock"] += entry["lock_time"]
        group["rows"] += entry["rows_examined"]
        group["rows_max"] = max(group["rows_max"], entry["rows_examined"])
        group["sent"] += entry["rows_sent"]
        if entry["query_time"] >= group["max"]:
            group["max"] = entry["query_time"]
            group["example"] = entry
        if entry["db"]:
            group["dbs"].add(entry["db"])
        if entry["when"]:
            group["first"] = min(group["first"] or entry["when"], entry["when"])
            group["last"] = max(group["last"] or entry["when"], entry["when"])
    order = {"total": "total", "count": "count", "max": "max", "rows": "rows", "lock": "lock"}[args.sort]
    ranked = sorted(groups.items(), key=lambda item: item[1][order], reverse=True)
    shown = ranked[:args.top]
    rows = []
    for number, (key, group) in enumerate(shown, 1):
        rows.append([f"#{number}", group["count"], f"{group['total']:.1f}", f"{group['total'] / group['count']:.2f}",
                     f"{group['max']:.2f}", f"{group['lock']:.2f}", f"{group['rows'] // group['count']}",
                     group["rows_max"], f"{group['sent'] // group['count']}",
                     f"{group['first']:%m-%d %H:%M}" if group["first"] else "-",
                     f"{group['last']:%m-%d %H:%M}" if group["last"] else "-"])
    print(f"{len(groups)} query shape(s); showing {len(shown)}, ordered by {args.sort}:")
    print(table(["", "count", "total s", "avg s", "max s", "lock s", "avg rows read", "max rows read",
                 "avg rows sent", "first", "last"], rows))
    print()
    for number, (key, group) in enumerate(shown, 1):
        example = re.sub(r"\s+", " ", group["example"]["sql"])
        dbs = ", ".join(sorted(group["dbs"])) or "not stated"
        print(f"#{number}  database: {dbs}")
        print(f"    shape:   {key[:args.width]}{'...' if len(key) > args.width else ''}")
        print(f"    slowest: {example[:args.width]}{'...' if len(example) > args.width else ''}")
    print()

    if args.by_hour or args.by_minute:
        for wanted, pattern, label in ((args.by_hour, "%Y-%m-%d %H:00", "hour"),
                                       (args.by_minute, "%Y-%m-%d %H:%M", "minute")):
            if not wanted:
                continue
            buckets = {}
            for entry in kept:
                if entry["when"]:
                    bucket = buckets.setdefault(entry["when"].strftime(pattern), [0, 0.0, 0.0])
                    bucket[0] += 1
                    bucket[1] += entry["query_time"]
                    bucket[2] = max(bucket[2], entry["query_time"])
            print(f"Slow queries per {label} ({zone}; the time is when the query FINISHED):")
            print(table([label, "count", "total s", "max s"],
                        [[key, b[0], f"{b[1]:.1f}", f"{b[2]:.2f}"] for key, b in sorted(buckets.items())]))
            print()
    print(TESTED_REAL.format(what="mysql-slow.log"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
