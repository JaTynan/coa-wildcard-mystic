#!/usr/bin/env python3
"""Summarise the Windows counter logs in Core\\Logs\\perf and line them up with Timing.log spikes.

What the files are
    Since 21 Nov 2026 (commit 9ba9f45), patch night's StartDiagnostics starts Windows' own typeperf
    once the world is up: one perf-<yyyy-MM-dd_HHmm>.csv per server start, a row every 5 seconds,
    kept 14 days. Columns (PatchNight.ps1, StartDiagnostics): each core's CPU and the total, the
    processor queue, context switches, free memory, paging, the page file, disk read and write
    latency, disk queue and idle time, and the world server's and MySQL's own CPU, memory and (world
    server) thread count.

    Units, as Windows defines them: "% Processor Time" of a core is 0-100; of a PROCESS it is 100 per
    busy core, so a world server using two full cores shows 200. "Avg. Disk sec/Read|Write" is in
    seconds (shown here in ms). "Working Set" is bytes (shown here in GB).

What it prints
    1. Per file: time span, rows, cells that were blank.
    2. CPU per core: average, 95th percentile, max, share of rows at or above --busy-pct, and how often
       ONE core was that busy while the machine as a whole was under half used (the pattern
       docs/performance.md describes: "one busy thread per map" is the limit, not total CPU).
    3. Processor queue, context switches, memory, paging, disk, worldserver and mysqld.
    4. With --timing Timing.log: which counters moved in the minutes Timing.log shows a spike. For
       every timing record the counters are reduced to one value over that record's window (its last
       N passes); spike windows are then compared with quiet windows. "share above quiet p95" is the
       share of spike windows where the counter was beyond the quiet windows' 95th percentile: about
       5% is chance, near 100% means the counter moved with the spikes. That shows what moved
       TOGETHER with a spike, not what caused it. Use --min-players 1 (or --from/--to) so quiet
       windows come from the same kind of play: with nobody online the bots sleep and every counter
       is lower, which would make everything look as if it "moved".

--busy-pct (default 90) is a display setting, not a pass mark: the project has no adopted threshold
for any of these counters (propose one through wildcard-validation-and-qa).

Examples
    python perf_csv_summary.py "C:\\Games\\CoA Server\\Core\\Logs\\perf"
    python perf_csv_summary.py perf-2026-11-22_0403.csv --from "2026-11-22 19:00" --to "2026-11-22 22:00"
    python perf_csv_summary.py Logs\\perf --timing Logs\\Timing.log --spike-ms 500 --detail 5

Tested on 2026-11-22 against the real Logs\\perf CSV and Timing.log copied from the server that day (one day of
data) and against the SYNTHETIC samples in samples\\. Check the output by eye when a log's format changes.
Python 3.8+, standard library only. Written for Windows and Linux; run so far on Linux (Python 3.13).
"""
import argparse
import bisect
import csv
import re
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import TESTED_REAL, fmt, mean, percentile, read_lines, safe_stdout, table, when_arg  # noqa: E402
from timing_summary import FIELDS, parse_timing, window_seconds  # noqa: E402

CORE = re.compile(r"^Processor\((\d+)\)\\% Processor Time$")
STAMPS = ("%m/%d/%Y %H:%M:%S.%f", "%m/%d/%Y %H:%M:%S", "%d/%m/%Y %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S.%f",
          "%Y-%m-%d %H:%M:%S")

# counter name (without the \\MACHINE prefix) -> (label, scale, unit, digits, which way is "worse")
SHOW = [
    ("Processor(_Total)\\% Processor Time", "CPU, all cores", 1, "%", 1, "high"),
    ("System\\Processor Queue Length", "Processor queue (threads waiting)", 1, "", 1, "high"),
    ("System\\Context Switches/sec", "Context switches /s", 1, "", 0, "high"),
    ("Memory\\Available MBytes", "Free memory", 1, " MB", 0, "low"),
    ("Memory\\Pages/sec", "Paging (pages/s)", 1, "", 1, "high"),
    ("Paging File(_Total)\\% Usage", "Page file used", 1, "%", 1, "high"),
    ("PhysicalDisk(_Total)\\Avg. Disk sec/Read", "Disk read latency", 1000, " ms", 2, "high"),
    ("PhysicalDisk(_Total)\\Avg. Disk sec/Write", "Disk write latency", 1000, " ms", 2, "high"),
    ("PhysicalDisk(_Total)\\Current Disk Queue Length", "Disk queue", 1, "", 1, "high"),
    ("PhysicalDisk(_Total)\\% Idle Time", "Disk idle", 1, "%", 1, "low"),
    ("Process(worldserver)\\% Processor Time", "worldserver CPU (100 = one core)", 1, "%", 0, "high"),
    ("Process(worldserver)\\Working Set", "worldserver memory", 1 / 1024 ** 3, " GB", 2, "high"),
    ("Process(worldserver)\\Thread Count", "worldserver threads", 1, "", 0, "high"),
    ("Process(mysqld)\\% Processor Time", "mysqld CPU (100 = one core)", 1, "%", 0, "high"),
    ("Process(mysqld)\\Working Set", "mysqld memory", 1 / 1024 ** 3, " GB", 2, "high"),
]


def short_name(column):
    """'\\\\MACHINE\\Processor(0)\\% Processor Time' -> 'Processor(0)\\% Processor Time'."""
    match = re.match(r"^\\\\[^\\]+\\(.*)$", column)
    return match.group(1) if match else column.lstrip("\\")


def parse_stamp(text):
    for pattern in STAMPS:
        try:
            return datetime.strptime(text.strip(), pattern)
        except ValueError:
            continue
    return None


def read_perf(path):
    """Returns (names, rows, stats). rows = [(datetime, [float or None, ...])], in file order."""
    stats = {"rows": 0, "bad_rows": 0, "blank_cells": 0, "zone": ""}
    reader = csv.reader(read_lines(path))
    names, rows = [], []
    for cells in reader:
        if not cells:
            continue
        if not names:
            if "PDH-CSV" not in cells[0] and len(cells) < 2:
                stats["bad_rows"] += 1
                continue
            stats["zone"] = cells[0]
            names = [short_name(c) for c in cells[1:]]
            continue
        stamp = parse_stamp(cells[0])
        if stamp is None or len(cells) != len(names) + 1:
            stats["bad_rows"] += 1
            continue
        values = []
        for cell in cells[1:]:
            try:
                values.append(float(cell))
            except ValueError:
                values.append(None)
                stats["blank_cells"] += 1
        rows.append((stamp, values))
        stats["rows"] += 1
    return names, rows, stats


def stat_row(label, values, scale, unit, digits):
    values = [v * scale for v in values if v is not None]
    if not values:
        return [label, "0", "-", "-", "-", "-", "-"]
    return [label, len(values), fmt(min(values), digits, unit), fmt(mean(values), digits, unit),
            fmt(percentile(values, 50), digits, unit), fmt(percentile(values, 95), digits, unit),
            fmt(max(values), digits, unit)]


def summarise(names, rows, busy):
    column = {name: i for i, name in enumerate(names)}
    cores = sorted((int(CORE.match(n).group(1)), i) for n, i in column.items() if CORE.match(n))
    out = []
    if cores:
        table_rows = []
        for number, index in cores:
            values = [r[1][index] for r in rows if r[1][index] is not None]
            share = 100.0 * len([v for v in values if v >= busy]) / len(values) if values else None
            table_rows.append([f"core {number}", fmt(mean(values), 1, "%"), fmt(percentile(values, 95), 1, "%"),
                               fmt(max(values) if values else None, 1, "%"), fmt(share, 1, "%")])
        out.append(f"CPU per core ({len(cores)} cores in the file):")
        out.append(table(["", "average", "p95", "max", f"rows >= {busy:g}%"], table_rows))
        total_index = column.get("Processor(_Total)\\% Processor Time")
        any_busy = one_hot = usable = 0
        for _, values in rows:
            core_values = [values[i] for _, i in cores if values[i] is not None]
            if not core_values:
                continue
            usable += 1
            total = values[total_index] if total_index is not None and values[total_index] is not None \
                else mean(core_values)
            if max(core_values) >= busy:
                any_busy += 1
                if total < 50:
                    one_hot += 1
        if usable:
            out.append(f"Rows where at least one core was >= {busy:g}%: {any_busy} of {usable} "
                       f"({100.0 * any_busy / usable:.1f}%). Of those, the machine as a whole was under 50%: {one_hot} "
                       f"({100.0 * one_hot / usable:.1f}% of all rows) - a single thread at its limit while other "
                       "cores idle.")
        out.append("")
    table_rows = []
    for name, label, scale, unit, digits, _ in SHOW:
        if name in column:
            table_rows.append(stat_row(label, [r[1][column[name]] for r in rows], scale, unit, digits))
    out.append("Counters:")
    out.append(table(["", "rows", "min", "average", "median", "p95", "max"], table_rows))
    world = column.get("Process(worldserver)\\Working Set")
    if world is not None:
        values = [(r[0], r[1][world]) for r in rows if r[1][world] is not None]
        if len(values) > 1:
            hours = (values[-1][0] - values[0][0]).total_seconds() / 3600.0
            grown = (values[-1][1] - values[0][1]) / 1024 ** 3
            if hours > 0:
                out.append(f"worldserver memory went from {values[0][1] / 1024 ** 3:.2f} GB to "
                           f"{values[-1][1] / 1024 ** 3:.2f} GB over {hours:.1f} h ({grown / hours:+.3f} GB/h).")
    known = {s[0] for s in SHOW}
    extra = [n for n in names if n not in known and not CORE.match(n)]
    if extra:
        out.append("Columns in the file this script has no label for (left out above): " + "; ".join(extra))
    return "\n".join(out)


def correlate(names, rows, timing_path, field, threshold, detail, pad, min_players=None):
    records, tstats = parse_timing(timing_path)
    records = [r for r in records if r["ts"] and r[field] is not None]
    if min_players is not None:
        records = [r for r in records if r["players"] is not None and r["players"] >= min_players]
    if not records:
        return f"No timestamped timing records with a '{field}' value in {timing_path}."
    stamps = [r[0] for r in rows]
    first, last = stamps[0], stamps[-1]
    column = {name: i for i, name in enumerate(names)}
    cores = [i for n, i in column.items() if CORE.match(n)]
    series = []          # (label, scale, unit, digits, direction, getter)
    for name, label, scale, unit, digits, direction in SHOW:
        if name in column:
            series.append((label, scale, unit, digits, direction, (lambda values, i=column[name]: values[i])))
    if cores:
        def busiest(values, indexes=tuple(cores)):
            present = [values[i] for i in indexes if values[i] is not None]
            return max(present) if present else None
        series.insert(1, ("CPU, busiest single core", 1, "%", 1, "high", busiest))
    # A long pass shows as the process total FALLING towards one core (one thread works, the rest wait), which
    # a max-reduced row cannot show. So the world server's CPU is also reduced to its lowest value.
    for name, label, scale, unit, digits, direction in SHOW:
        if name in column and "worldserver" in name and "Processor Time" in name:
            series.append(("worldserver CPU", scale, unit, digits, "low",
                           (lambda values, i=column[name]: values[i])))
            break

    def window_values(record):
        span = window_seconds(record) or 60.0
        start = record["ts"] - timedelta(seconds=span + pad)
        end = record["ts"] + timedelta(seconds=pad)
        lo = bisect.bisect_left(stamps, start)
        hi = bisect.bisect_right(stamps, end)
        if hi <= lo:
            return None
        result = []
        for label, scale, unit, digits, direction, getter in series:
            values = [v for v in (getter(rows[i][1]) for i in range(lo, hi)) if v is not None]
            if not values:
                result.append(None)
            else:
                result.append((max(values) if direction == "high" else min(values)) * scale)
        return result

    spike, quiet, skipped = [], [], 0
    for record in records:
        if record["ts"] < first or record["ts"] > last + timedelta(seconds=pad):
            skipped += 1
            continue
        values = window_values(record)
        if values is None:
            skipped += 1
            continue
        (spike if record[field] >= threshold else quiet).append((record, values))
    out = [f"Timing records with a counter window: {len(spike) + len(quiet)} ({len(spike)} spike with {field} >= "
           f"{threshold} ms, {len(quiet)} quiet); outside the counter file's time span: {skipped}.",
           f"Each window is the record's last-N-passes span plus {pad:g} s either side; a counter is reduced to its "
           "worst value in the window (max, or min for free memory and disk idle)."]
    if not spike or not quiet:
        out.append("Need at least one spike window and one quiet window to compare. Try another --spike-ms, or a "
                   "counter file that covers the spikes.")
        return "\n".join(out)
    if len(spike) < 5:
        out.append(f"CAUTION: only {len(spike)} spike window(s). Treat the table as a pointer to look closer, "
                   "not as evidence.")
    ranked = []
    for index, (label, scale, unit, digits, direction, _) in enumerate(series):
        quiet_values = [v[index] for _, v in quiet if v[index] is not None]
        spike_values = [v[index] for _, v in spike if v[index] is not None]
        if not quiet_values or not spike_values:
            continue
        if direction == "high":
            edge = percentile(quiet_values, 95)
            beyond = len([v for v in spike_values if v > edge])
        else:
            edge = percentile(quiet_values, 5)
            beyond = len([v for v in spike_values if v < edge])
        share = 100.0 * beyond / len(spike_values)
        ranked.append((share, [label + (" (lowest in window)" if direction == "low" else ""),
                               fmt(percentile(quiet_values, 50), digits, unit), fmt(edge, digits, unit),
                               fmt(percentile(spike_values, 50), digits, unit),
                               fmt(max(spike_values) if direction == "high" else min(spike_values), digits, unit),
                               f"{share:.0f}%"]))
    ranked.sort(key=lambda item: item[0], reverse=True)
    out.append("")
    out.append("Which counter moved in the spike windows (most-moved first):")
    out.append(table(["counter", "quiet median", "quiet p95 (p5 if lowest)", "spike median", "spike worst",
                      "share above quiet p95"], [row for _, row in ranked]))
    if detail:
        out.append("")
        out.append(f"The {min(detail, len(spike))} worst spike windows, counter by counter:")
        worst = sorted(spike, key=lambda item: item[0][field], reverse=True)[:detail]
        worst.sort(key=lambda item: item[0]["ts"])
        heads = ["counter", "quiet median"] + [f"{r['ts']:%m-%d %H:%M:%S}" for r, _ in worst]
        detail_rows = [[f"Timing.log {field} (ms)", "-"] + [str(r[field]) for r, _ in worst]]
        for index, (label, scale, unit, digits, direction, _) in enumerate(series):
            quiet_values = [v[index] for _, v in quiet if v[index] is not None]
            detail_rows.append([label, fmt(percentile(quiet_values, 50), digits, unit)] +
                               [fmt(values[index], digits, unit) for _, values in worst])
        out.append(table(heads, detail_rows))
    return "\n".join(out)


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="+", type=Path,
                        help="perf-*.csv files, or the Logs\\perf folder (every perf-*.csv in it)")
    parser.add_argument("--from", dest="start", type=when_arg, metavar="WHEN", help="ignore rows before this")
    parser.add_argument("--to", dest="end", type=when_arg, metavar="WHEN", help="ignore rows from this on")
    parser.add_argument("--busy-pct", type=float, default=90.0,
                        help="a core counts as busy at or above this (default 90; a display setting, not a "
                             "project threshold)")
    parser.add_argument("--timing", type=Path, metavar="TIMING_LOG",
                        help="Timing.log: compare the counters in spike minutes with quiet minutes")
    parser.add_argument("--spike-ms", type=int, default=100,
                        help="with --timing: a record is a spike at or above this (default 100, the 'laggy' "
                             "figure in docs/performance.md)")
    parser.add_argument("--spike-field", choices=FIELDS, default="max",
                        help="with --timing: which number of the record decides (default max)")
    parser.add_argument("--pad-seconds", type=float, default=5.0,
                        help="with --timing: widen each window this much each side (default 5, one counter row)")
    parser.add_argument("--min-players", type=int, metavar="N",
                        help="with --timing: only use minutes with at least N players online, so spike minutes "
                             "are compared with quiet minutes of the same kind (bots sleep when nobody is on)")
    parser.add_argument("--detail", type=int, default=0, metavar="N",
                        help="with --timing: also print the counters of the N worst spike windows")
    return parser


def main(argv=None):
    safe_stdout()
    args = build_parser().parse_args(argv)
    files = []
    for path in args.paths:
        if path.is_dir():
            found = sorted(path.glob("perf-*.csv")) or sorted(path.glob("*.csv"))
            if not found:
                print(f"No .csv files in {path}", file=sys.stderr)
            files += found
        elif path.is_file():
            files.append(path)
        else:
            print(f"No such file or folder: {path}", file=sys.stderr)
    if not files:
        return 2
    all_names, all_rows = None, []
    for path in files:
        names, rows, stats = read_perf(path)
        if args.start:
            rows = [r for r in rows if r[0] >= args.start]
        if args.end:
            rows = [r for r in rows if r[0] < args.end]
        print(f"File: {path}")
        print(f"  header: {stats['zone'] or '(none found)'}; counters: {len(names)}; rows read: {stats['rows']}; "
              f"rows skipped (not a timestamp, or wrong number of cells): {stats['bad_rows']}; "
              f"blank cells: {stats['blank_cells']}.")
        if not rows:
            print("  no rows in the chosen time range.\n")
            continue
        seconds = [(b[0] - a[0]).total_seconds() for a, b in zip(rows, rows[1:])]
        print(f"  {rows[0][0]:%Y-%m-%d %H:%M:%S} to {rows[-1][0]:%Y-%m-%d %H:%M:%S}, {len(rows)} rows in range, "
              f"typical gap {percentile(seconds, 50) or 0:.0f} s.")
        if len(files) > 1:
            print(summarise(names, rows, args.busy_pct))
        print()
        if all_names is None:
            all_names = names
        if names == all_names:
            all_rows += rows
        else:
            print(f"  NOTE: {path.name} has different columns from the first file; left out of the combined view.\n")
    if not all_rows:
        print("No counter rows to summarise.")
        return 1
    all_rows.sort(key=lambda r: r[0])
    print("All files together:" if len(files) > 1 else "Summary:")
    print(summarise(all_names, all_rows, args.busy_pct))
    print()
    if args.timing:
        if not args.timing.is_file():
            print(f"No such file: {args.timing}", file=sys.stderr)
            return 2
        print(f"Spikes from {args.timing}:")
        print(correlate(all_names, all_rows, args.timing, args.spike_field, args.spike_ms, args.detail,
                        args.pad_seconds, args.min_players))
        print()
    print(TESTED_REAL.format(what="Logs\\perf CSV and Timing.log"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
