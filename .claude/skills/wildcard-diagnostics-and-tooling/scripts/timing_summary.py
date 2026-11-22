#!/usr/bin/env python3
"""Summarise the world server's update-time log (Core\\Logs\\Timing.log).

What the file is
    Since 21 Nov 2026 (commit 9ba9f45) the world server writes five lines once a minute:

        2026-11-21 18:02:11 Update time diff: 31ms with 3 players online
        2026-11-21 18:02:11 Last 500 diffs summary:
        2026-11-21 18:02:11 |- Mean: 33ms
        2026-11-21 18:02:11 |- Median: 30ms
        2026-11-21 18:02:11 |- Percentiles (95, 99, max): 61ms, 118ms, 402ms

    The five lines are not always in that order (logging runs on its own thread; 101 of the 458
    records in the 22 Nov 2026 file were shuffled) and the script copes with that.
    "players" counts real players only: bots are not in it.
    "diff" is the wall-clock time from the start of one pass of the game loop to the start of the next.
    Each record describes only the LAST 500 passes (about 500 x Mean milliseconds: roughly 17 s at a
    33 ms mean), not the whole minute. A spike that happened outside that window is not in the file.
    This script prints the share of each minute the windows covered ("covered" = N x Mean / gap between
    records; N x Mean is the exact length of the window, since the mean is the sum of the passes over N),
    and warns when most records cover under half their minute. Then every max and p99 is a floor and
    the number of spike minutes is an under-estimate.

    The same five lines, without timestamps, are in Server.log and the console log; console-history.txt
    holds only the first of the five, prefixed "<line number>: ". This script reads all of those too;
    without timestamps the per-hour table, --from/--to and --split are not available.

What it prints
    1. Per-restart table and per-hour table: for the chosen --metric (default: the window's 95th
       percentile, the manager's "95% under" figure), its p50/p95/p99/max across the minute samples.
    2. Spike list: every minute whose --spike-field (default: the window's max) reached --spike-ms.
    3. With --split WHEN: the same statistics before and after that moment.

Thresholds: docs/performance.md says the "95% under" figure matters most: under about 50 ms is smooth,
100 ms and up feels laggy. --spike-ms defaults to 100 for that reason. Nothing else here is a
threshold.

Examples
    python timing_summary.py "C:\\Games\\CoA Server\\Core\\Logs\\Timing.log"
    python timing_summary.py Timing.log --from "2026-11-22 18:00" --to "2026-11-22 23:00"
    python timing_summary.py Timing.log --split "2026-11-22 04:00" --window-hours 12 --min-players 1
    python timing_summary.py Timing.log --metric max --spike-ms 500 --top 30

Tested on 2026-11-22 against the real Timing.log and console-history.txt copied from the server that day (one day of
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
from _common import TESTED_REAL, fmt, mean, percentile, read_lines, safe_stdout, table, when_arg  # noqa: E402

TABLE_SIZE = 500  # AVG_DIFF_COUNT in the core's src/server/game/Time/UpdateTime.h
FIELDS = ("diff", "mean", "median", "p95", "p99", "max")

PREFIX = re.compile(r"^(?:(\d+): )?(?:(\d{4}-\d\d-\d\d)[ _T](\d\d:\d\d:\d\d) )?(.*)$")
RE_DIFF = re.compile(r"Update time diff: (\d+)ms with (\d+) players online")
RE_SIZE = re.compile(r"Last (\d+) diffs summary:")
RE_MEAN = re.compile(r"\|- Mean: (\d+)ms")
RE_MEDIAN = re.compile(r"\|- Median: (\d+)ms")
RE_PCT = re.compile(r"\|- Percentiles \(95, 99, max\): (\d+)ms, (\d+)ms, (\d+)ms")
BANNER = "AzerothCore rev."
RE_REV = re.compile(r"AzerothCore rev\. (\S+)")


def parse_timing(path, gap_seconds=180):
    """Read a Timing.log (or Server.log / console log / console-history.txt).

    Returns (records, stats). Each record is a dict: ts (datetime or None), diff, players, n, mean,
    median, p95, p99, max (None where that line was missing), restart (0-based index of the server
    start it belongs to), rev (core revision from the last start banner seen, None in Timing.log,
    which has no banners), line (1-based line number of its first line).

    The five lines of a record are NOT always in order: logging runs on its own thread
    (Log.Async.Enable = 1) and the real Timing.log of 22 Nov 2026 has blocks with "Last 500 diffs"
    before "Update time diff" and "Median" after "Percentiles". So lines are gathered into a block
    until all five kinds are present, a kind repeats, or the timestamp moves by more than 2 seconds.

    A new restart is assumed when a start banner line is seen, when the "Last N diffs" count drops
    (the table of 500 starts empty at every start), or when two records are more than `gap_seconds`
    apart (the server was down, or frozen)."""
    records = []
    stats = {"lines": 0, "other": 0, "bad_time": 0, "partial": 0, "banners": 0, "reordered": 0}
    current = None
    restart = 0
    pending_banner = False
    last_ts = None
    last_n = None
    revision = None

    def close():
        nonlocal current, restart, pending_banner, last_ts, last_n
        record, current = current, None
        if record is None:
            return
        kinds = record.pop("kinds")
        if kinds != sorted(kinds):
            stats["reordered"] += 1
        fragment = len(kinds) < 3 and 0 not in kinds     # a loose line or two: too little to judge a restart by
        new_start = pending_banner and records
        if records and not new_start and not fragment:
            if record["n"] is not None and last_n is not None and record["n"] < last_n:
                new_start = True
            elif record["ts"] and last_ts and (record["ts"] - last_ts).total_seconds() > gap_seconds:
                new_start = True
        if new_start:
            restart += 1
        pending_banner = False
        record["restart"] = restart
        record["rev"] = revision
        if len(kinds) < 5:
            stats["partial"] += 1
        records.append(record)
        if fragment:
            return
        if record["ts"]:
            last_ts = record["ts"]
        if record["n"] is not None:
            last_n = record["n"]

    for number, raw in enumerate(read_lines(path), 1):
        stats["lines"] += 1
        match = PREFIX.match(raw)
        date, clock, body = match.group(2), match.group(3), match.group(4)
        kind = values = None
        for index, pattern in enumerate((RE_DIFF, RE_SIZE, RE_MEAN, RE_MEDIAN, RE_PCT)):
            found = pattern.search(body)
            if found:
                kind, values = index, [int(g) for g in found.groups()]
                break
        if kind is None:
            if BANNER in body:
                close()
                pending_banner = True
                stats["banners"] += 1
                found = RE_REV.search(body)
                if found:
                    revision = found.group(1)
            elif body.strip():
                stats["other"] += 1
            continue
        ts = None
        if date:
            try:
                ts = datetime.strptime(f"{date} {clock}", "%Y-%m-%d %H:%M:%S")
            except ValueError:
                stats["bad_time"] += 1
        if current is not None and (kind in current["kinds"] or (
                ts and current["ts"] and abs((ts - current["ts"]).total_seconds()) > 2)):
            close()
        if current is None:
            current = {"ts": ts, "diff": None, "players": None, "n": None, "mean": None, "median": None,
                       "p95": None, "p99": None, "max": None, "line": number, "kinds": []}
        current["kinds"].append(kind)
        if kind == 0:
            current["diff"], current["players"] = values
        elif kind == 1:
            current["n"] = values[0]
        elif kind == 2:
            current["mean"] = values[0]
        elif kind == 3:
            current["median"] = values[0]
        else:
            current["p95"], current["p99"], current["max"] = values
        if len(current["kinds"]) == 5:
            close()
    close()
    return records, stats


def sample_interval(records):
    """Seconds between records, from the data (the setting is RecordUpdateTimeDiffInterval)."""
    gaps = []
    for before, after in zip(records, records[1:]):
        if before["ts"] and after["ts"] and before["restart"] == after["restart"]:
            gaps.append((after["ts"] - before["ts"]).total_seconds())
    return percentile(gaps, 50) if gaps else None


def window_seconds(record):
    """How many seconds of play this record's summary lines cover (N passes x mean)."""
    if record["n"] is None or record["mean"] is None:
        return None
    return record["n"] * record["mean"] / 1000.0


def summary_row(label, group, metric, interval):
    values = [r[metric] for r in group if r[metric] is not None]
    means = [r["mean"] for r in group if r["mean"] is not None]
    maxes = [r["max"] for r in group if r["max"] is not None]
    players = [r["players"] for r in group if r["players"] is not None]
    windows = [w for w in (window_seconds(r) for r in group) if w is not None]
    covered = None
    if windows and interval:
        covered = 100.0 * min(1.0, mean(windows) / interval)
    avg_mean = mean(means)
    return [
        label, len(group),
        f"{min(players)}-{max(players)}" if players else "-",
        fmt(avg_mean, 1), fmt(1000.0 / avg_mean if avg_mean else None, 0),
        fmt(percentile(values, 50), 0), fmt(percentile(values, 95), 0), fmt(percentile(values, 99), 0),
        fmt(max(values) if values else None, 0), fmt(max(maxes) if maxes else None, 0),
        fmt(covered, 0, "%"),
    ]


def headers(metric):
    name = {"diff": "last diff", "p95": "window p95", "p99": "window p99", "max": "window max",
            "mean": "window mean", "median": "window median"}[metric]
    return ["", "samples", "players", "avg mean ms", "ticks/s", f"{name}: p50", "p95", "p99", "max",
            "worst tick ms", "covered"]


def describe_restart(index, group):
    first = group[0]["ts"]
    last = group[-1]["ts"]
    if first and last:
        return f"start {index + 1}: {first:%Y-%m-%d %H:%M} to {last:%m-%d %H:%M}"
    return f"start {index + 1}: lines {group[0]['line']}-{group[-1]['line']}"


def episodes(spikes, interval):
    """Group spike minutes that follow each other into episodes."""
    groups = []
    limit = (interval or 60) * 1.6
    for record in spikes:
        if (groups and record["ts"] and groups[-1][-1]["ts"]
                and record["restart"] == groups[-1][-1]["restart"]
                and (record["ts"] - groups[-1][-1]["ts"]).total_seconds() <= limit):
            groups[-1].append(record)
        else:
            groups.append([record])
    return groups


def build_parser():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log", type=Path, help="Timing.log (or Server.log, a console log, console-history.txt)")
    parser.add_argument("--metric", choices=FIELDS, default="p95",
                        help="which number of each minute's record to summarise (default p95, the "
                             "manager's '95%% under' figure; 'diff' is the single pass on the first line)")
    parser.add_argument("--from", dest="start", type=when_arg, metavar="WHEN", help="ignore records before this")
    parser.add_argument("--to", dest="end", type=when_arg, metavar="WHEN", help="ignore records from this on")
    parser.add_argument("--min-players", type=int, help="only minutes with at least this many players online")
    parser.add_argument("--max-players", type=int, help="only minutes with at most this many players online")
    parser.add_argument("--skip-warmup-minutes", type=float, default=0.0, metavar="MIN",
                        help="drop the first MIN minutes after each server start (bots are still logging in)")
    parser.add_argument("--gap-seconds", type=int, default=180,
                        help="a silence longer than this between records counts as a restart (default 180)")
    parser.add_argument("--spike-ms", type=int, default=100,
                        help="list minutes whose --spike-field reached this (default 100: docs/performance.md "
                             "calls 100 ms and up laggy)")
    parser.add_argument("--spike-field", choices=FIELDS, default="max",
                        help="which number decides a spike (default max: the worst pass in the window)")
    parser.add_argument("--top", type=int, default=20, help="how many spike minutes to list, worst first (default 20)")
    parser.add_argument("--no-hours", action="store_true", help="leave the per-hour table out")
    parser.add_argument("--max-starts", type=int, default=25, metavar="N",
                        help="show only the newest N server starts in the per-start table (default 25)")
    parser.add_argument("--ignore-above-ms", type=int, metavar="MS",
                        help="drop records whose 'diff' (first line) is above MS. The real console history holds "
                             "a few values of hours (the first pass after the machine was suspended or the clock "
                             "jumped?); they swamp every average")
    parser.add_argument("--split", type=when_arg, metavar="WHEN",
                        help="compare before and after this moment, e.g. the restart that applied a change")
    parser.add_argument("--window-hours", type=float, metavar="H",
                        help="with --split: only use H hours each side of it")
    return parser


def main(argv=None):
    safe_stdout()
    args = build_parser().parse_args(argv)
    if not args.log.is_file():
        print(f"No such file: {args.log}", file=sys.stderr)
        return 2
    records, stats = parse_timing(args.log, args.gap_seconds)
    print(f"File: {args.log}")
    print(f"Lines read: {stats['lines']}; timing records: {len(records)}; start banners: {stats['banners']}; "
          f"other lines skipped: {stats['other']}; records missing one or more of their five lines: "
          f"{stats['partial']}; records whose lines arrived out of order (read correctly): {stats['reordered']}; "
          f"unreadable timestamps: {stats['bad_time']}.")
    if not records:
        print("No 'Update time diff: Nms with N players online' lines found. Is this the right file?")
        return 1
    timed = all(r["ts"] for r in records)
    if not timed:
        print("NOTE: this file has no timestamps (Server.log, a console log or console-history.txt), so there "
              "is no per-hour table and --from/--to/--split are ignored.")
    if all(r["mean"] is None and r["max"] is None for r in records):
        print("NOTE: only the first line of each record is here (console-history.txt keeps just that line), "
              "so only --metric diff and --spike-field diff mean anything. Switching to them.\n"
              "      Before 21 Nov 2026 the server wrote that line only when a pass took over 100 ms, sampled at "
              "most every 5 minutes, so these are slow passes only: compare counts and sizes of slow passes, "
              "never read the median as a typical pass.")
        args.metric = args.spike_field = "diff"

    # Filters
    kept = records
    if timed and args.start:
        kept = [r for r in kept if r["ts"] >= args.start]
    if timed and args.end:
        kept = [r for r in kept if r["ts"] < args.end]
    huge = [r for r in kept if r["diff"] is not None and r["diff"] >= 60000]
    if huge:
        print(f"NOTE: {len(huge)} record(s) have a 'diff' of a minute or more (largest {max(r['diff'] for r in huge)} ms). "
              "Check them by eye; --ignore-above-ms leaves them out.")
    if args.ignore_above_ms is not None:
        kept = [r for r in kept if r["diff"] is None or r["diff"] <= args.ignore_above_ms]
    if args.min_players is not None:
        kept = [r for r in kept if r["players"] is not None and r["players"] >= args.min_players]
    if args.max_players is not None:
        kept = [r for r in kept if r["players"] is not None and r["players"] <= args.max_players]
    if timed and args.skip_warmup_minutes > 0:
        starts = {}
        for record in records:
            starts.setdefault(record["restart"], record["ts"])
        warm = timedelta(minutes=args.skip_warmup_minutes)
        kept = [r for r in kept if r["ts"] - starts[r["restart"]] >= warm]
    if len(kept) != len(records):
        print(f"Records kept after --from/--to/--min-players/--max-players/--skip-warmup-minutes: {len(kept)}.")
    if not kept:
        print("Nothing left after the filters.")
        return 1
    interval = sample_interval(records) if timed else None
    if interval:
        print(f"Typical gap between records: {interval:.0f} s.")
    print("'covered' = the share of each gap the record's last-N-passes window spans; spikes outside it are not "
          "in this file.\n'ticks/s' = 1000 / avg mean, the way the manager's World speed panel works it out.\n")

    # Per restart
    by_restart = {}
    for record in kept:
        by_restart.setdefault(record["restart"], []).append(record)
    starts = sorted(by_restart.items())
    hidden = max(0, len(starts) - args.max_starts)
    rows = [summary_row(describe_restart(i, g), g, args.metric, interval) for i, g in starts[hidden:]]
    rows.append(summary_row("ALL", kept, args.metric, interval))
    low = [r for r in kept if interval and window_seconds(r) is not None and window_seconds(r) < 0.5 * interval]
    measured = [r for r in kept if window_seconds(r) is not None]
    if interval and measured and len(low) > len(measured) / 2:
        typical = percentile([window_seconds(r) for r in measured], 50)
        print(f"WARNING: low coverage. A record describes only its last N passes (N x mean seconds: typically "
              f"{typical:.0f} s here) but records are {interval:.0f} s apart; {len(low)} of {len(measured)} records "
              "cover under half their gap.\n         Every max and p99 below is a FLOOR (a worse pass may have fallen "
              "outside the window) and counts of spike minutes are under-estimates.\n")
    print(f"Per server start ({args.metric} of each record)"
          + (f"; the {hidden} oldest start(s) are left out, see --max-starts" if hidden else "") + ":")
    print(table(headers(args.metric), rows))
    print()

    # Per core revision (only files with start banners: Server.log, console logs, console-history.txt)
    if any(r["rev"] for r in kept):
        by_rev, order = {}, []
        for record in kept:
            key = record["rev"] or "(before the first banner)"
            if key not in by_rev:
                order.append(key)
            by_rev.setdefault(key, []).append(record)
        rows = []
        for key in order:
            row = summary_row(key, by_rev[key], args.metric, interval)
            row.insert(1, len({r["restart"] for r in by_rev[key]}))
            rows.append(row)
        heads = headers(args.metric)
        heads.insert(1, "starts")
        print(f"Per core revision, in order of first appearance ({args.metric} of each record; a trailing + means "
              "a build with local changes, such as our patched server):")
        print(table(heads, rows))
        print()

    # Per hour
    if timed and not args.no_hours:
        by_hour = {}
        for record in kept:
            by_hour.setdefault(record["ts"].replace(minute=0, second=0), []).append(record)
        rows = [summary_row(f"{hour:%Y-%m-%d %H}:00", g, args.metric, interval) for hour, g in sorted(by_hour.items())]
        print(f"Per hour ({args.metric} of each record):")
        print(table(headers(args.metric), rows))
        print()

    # Spikes
    field = args.spike_field
    spikes = [r for r in kept if r[field] is not None and r[field] >= args.spike_ms]
    with_field = [r for r in kept if r[field] is not None]
    share = 100.0 * len(spikes) / len(with_field) if with_field else 0.0
    print(f"Spikes: {len(spikes)} of {len(with_field)} records ({share:.1f}%) had {field} >= {args.spike_ms} ms.")
    if spikes:
        groups = episodes(spikes, interval)
        if timed:
            longest = max(groups, key=len)
            print(f"They form {len(groups)} episode(s) of back-to-back minutes; the longest is {len(longest)} "
                  f"record(s), starting {longest[0]['ts']:%Y-%m-%d %H:%M}.")
        worst = sorted(spikes, key=lambda r: r[field], reverse=True)[:max(0, args.top)]
        rows = []
        for record in sorted(worst, key=lambda r: (r["ts"] or datetime.min, r["line"])):
            rows.append([f"{record['ts']:%Y-%m-%d %H:%M:%S}" if record["ts"] else f"line {record['line']}",
                         fmt(record["players"]), fmt(record["diff"]), fmt(record["mean"]), fmt(record["median"]),
                         fmt(record["p95"]), fmt(record["p99"]), fmt(record["max"]),
                         fmt(window_seconds(record), 0, " s"),
                         fmt(100.0 * min(1.0, window_seconds(record) / interval), 0, "%")
                         if interval and window_seconds(record) is not None else "-"])
        if rows:
            print(f"Worst {len(rows)} by {field}, in time order:")
            print(table(["when", "players", "diff", "mean", "median", "p95", "p99", "max", "window", "covered"], rows))
    print()

    # Before / after
    if args.split:
        if not timed:
            print("--split needs timestamps; skipped.")
        else:
            before = [r for r in kept if r["ts"] < args.split]
            after = [r for r in kept if r["ts"] >= args.split]
            if args.window_hours:
                span = timedelta(hours=args.window_hours)
                before = [r for r in before if r["ts"] >= args.split - span]
                after = [r for r in after if r["ts"] < args.split + span]
            print(f"Before and after {args.split:%Y-%m-%d %H:%M}"
                  + (f" ({args.window_hours:g} h each side)" if args.window_hours else "") + ":")
            rows = []
            for label, group in (("before", before), ("after", after)):
                if group:
                    row = summary_row(label, group, args.metric, interval)
                    count = len([r for r in group if r[field] is not None and r[field] >= args.spike_ms])
                    row.append(f"{count} ({100.0 * count / len(group):.1f}%)")
                    rows.append(row)
                else:
                    rows.append([label, 0] + ["-"] * 10)
            print(table(headers(args.metric) + [f"records with {field}>={args.spike_ms}"], rows))
            if before and after:
                b_players = mean([r["players"] for r in before if r["players"] is not None]) or 0.0
                a_players = mean([r["players"] for r in after if r["players"] is not None]) or 0.0
                print(f"Average players online: before {b_players:.1f}, after {a_players:.1f}. If these differ, or "
                      "the bot count differs, the two sides are not comparable: narrow with --min-players/"
                      "--max-players and the same hours of the day.")
            print()
    print(TESTED_REAL.format(what="Timing.log and console-history.txt"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
