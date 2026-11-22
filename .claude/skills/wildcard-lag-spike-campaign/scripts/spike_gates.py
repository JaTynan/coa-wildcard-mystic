#!/usr/bin/env python3
"""Decision-gate tests for the lag spike campaign. Python 3.8+, standard library only.

Reads Core\\Logs\\Timing.log (five lines per record, written by the world server since commit 9ba9f45):

    2026-11-21 18:02:11 Update time diff: 31ms with 3 players online
    2026-11-21 18:02:11 Last 500 diffs summary:
    2026-11-21 18:02:11 |- Mean: 33ms
    2026-11-21 18:02:11 |- Median: 30ms
    2026-11-21 18:02:11 |- Percentiles (95, 99, max): 61ms, 118ms, 402ms

and, for `perf-at`, a Core\\Logs\\perf\\perf-*.csv written by typeperf (PatchNight.ps1 StartDiagnostics).

A "spike" here is a record whose window max reached --spike-ms (default 500). Each record only describes
the last 500 passes of the game loop (about 500 x Mean ms), so a spike's true time is somewhere in that
window before the record's timestamp, and spikes outside every window are not in the file at all.
"players online" counts real players only: bots have no entry in the session list.

Subcommands
    periodicity  Are spikes periodic? Inter-spike intervals, and a fold test per candidate period.
    sessions     Do spikes cluster after a session starts (bots log in) or after a restart?
    perf-at      What were the Windows counters doing around each spike? (CPU-bound, waiting, disk, VM stall)
    cycle        Is there a repeating beat under a minute in the 5-second counters, and is a record's worst
                 tick larger when the process's CPU dips lower (with a shifted-window control)?
    metric       The proposed exit metric, evening by evening.

Examples
    python spike_gates.py periodicity Timing.log --from "2026-11-22 18:00"
    python spike_gates.py sessions Timing.log
    python spike_gates.py perf-at Timing.log perf-2026-11-22_0405.csv --top 10
    python spike_gates.py cycle perf-2026-11-22_0903.csv --timing Timing.log --from "2026-11-22 15:00"
    python spike_gates.py metric Timing.log --min-players 2

Tested on 2026-11-22 against synthetic files with planted patterns and against one real day of the
server's logs (22 Nov 2026: 457 complete records plus one block cut off at the end of the copy; 5,379
counter rows). With asynchronous logging the lines of a record may arrive in any order; they are grouped
by their shared timestamp. A record missing a line is skipped and counted ("incomplete" in the header).
Thresholds printed as "hint" are proposals, not adopted rules.

Run it from any folder; give the paths of the log copies. It only reads.
Exit codes: 0 ran (for `metric`: the newest judged evening is PASS); 1 `metric` only: the newest judged
evening is FAIL; 2 could not run, or `metric` found no evening with enough records.
"""
import sys

sys.dont_write_bytecode = True

import argparse
import cmath
import csv
import math
import re
from datetime import datetime, timedelta

STAMP = r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"
FIRST = re.compile(STAMP + r" Update time diff: (\d+)ms with (\d+) players online")
MEAN = re.compile(STAMP + r" \|- Mean: (\d+)ms")
MEDIAN = re.compile(STAMP + r" \|- Median: (\d+)ms")
PCT = re.compile(STAMP + r" \|- Percentiles \(95, 99, max\): (\d+)ms, (\d+)ms, (\d+)ms")
SUMMARY = re.compile(STAMP + r" Last \d+ diffs summary:")
TABLE = 500  # AVG_DIFF_COUNT in the core's UpdateTime.h
WORLD = "Process(worldserver)\\% Processor Time"


def when(text):
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            pass
    raise argparse.ArgumentTypeError(f"not a date/time: {text!r} (use YYYY-MM-DD HH:MM)")


def read_text(path):
    raw = open(path, "rb").read()
    for enc in ("utf-8-sig", "utf-16"):
        try:
            if enc == "utf-16" and not raw.startswith((b"\xff\xfe", b"\xfe\xff")):
                continue
            return raw.decode(enc).splitlines()
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace").splitlines()


def read_timing(path, start=None, end=None, min_players=None):
    """Complete records with a timestamp. Returns (records, untimed_first_lines).

    With asynchronous logging the five lines of a record reach the file in any order (on 22 Nov 2026 the
    first two lines were swapped in 100 records, and Median/Percentiles in one). All five carry the same
    timestamp, so lines are grouped by timestamp, not by position. A record is kept once it has its first
    line, Mean, Median and Percentiles; the "Last N diffs summary" line is not needed. Groups missing a
    part (a block cut off at the end of a copied file, or a record split across two seconds) are counted
    in read_timing.incomplete and reported by header().
    """
    groups, order, untimed = {}, [], 0
    for line in read_text(path):
        stamp = line[:19]
        m = FIRST.match(line)
        if m:
            g = groups.get(stamp)
            if g is None or "last" in g:  # a second record on the same second: keep both
                g = {}
                order.append((stamp, g))
                groups[stamp] = g
            g["ts"] = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
            g["last"], g["players"] = int(m.group(2)), int(m.group(3))
            continue
        if "Update time diff:" in line:
            untimed += 1
            continue
        for rx, keys in ((MEAN, ("mean",)), (MEDIAN, ("median",)), (PCT, ("p95", "p99", "max"))):
            m = rx.match(line)
            if not m:
                continue
            g = groups.get(stamp)
            if g is None or keys[0] in g:
                g = {}
                order.append((stamp, g))
                groups[stamp] = g
            for key, val in zip(keys, m.groups()[1:]):
                g[key] = int(val)
            break
        else:
            if SUMMARY.match(line) and stamp not in groups:
                g = {}
                order.append((stamp, g))
                groups[stamp] = g
    need = ("ts", "mean", "median", "max")
    # A record whose lines straddle a second boundary: join two neighbouring incomplete groups that
    # together make exactly one record.
    merged, skip = [], False
    for i, (stamp, g) in enumerate(order):
        if skip:
            skip = False
            continue
        if not all(k in g for k in need) and i + 1 < len(order):
            nstamp, n = order[i + 1]
            try:
                close = abs((datetime.strptime(nstamp, "%Y-%m-%d %H:%M:%S")
                             - datetime.strptime(stamp, "%Y-%m-%d %H:%M:%S")).total_seconds()) <= 1
            except ValueError:
                close = False
            if close and not all(k in n for k in need) and not set(g) & set(n):
                both = dict(g)
                both.update(n)
                if all(k in both for k in need):
                    merged.append(both)
                    skip = True
                    continue
        merged.append(g)
    records = [g for g in merged if all(k in g for k in need)]
    read_timing.incomplete = len(merged) - len(records)
    records.sort(key=lambda r: r["ts"])
    if start:
        records = [r for r in records if r["ts"] >= start]
    if end:
        records = [r for r in records if r["ts"] < end]
    prev = None
    for r in records:  # gap to the previous record, before any player filter
        r["gap"] = (r["ts"] - prev["ts"]).total_seconds() if prev else None
        prev = r
    if min_players is not None:
        records = [r for r in records if r["players"] >= min_players]
    return records, untimed


read_timing.incomplete = 0


def window_s(r):
    """Seconds the record's 500-pass window covered (approximate: 500 x mean)."""
    return TABLE * max(r["mean"], 1) / 1000.0


def coverage(records):
    """Share of wall-clock time the windows covered, over records that follow another within 10 minutes."""
    seen = total = 0.0
    for r in records:
        if r["gap"] and 0 < r["gap"] <= 600:
            seen += min(window_s(r), r["gap"])
            total += r["gap"]
    return seen / total if total else None


def spikes_of(records, spike_ms):
    """Spike records; a spike seen by two overlapping windows (same max, records close together) counts once."""
    out = []
    for r in records:
        if r["max"] < spike_ms:
            continue
        if out and out[-1]["max"] == r["max"] and (r["ts"] - out[-1]["ts"]).total_seconds() <= window_s(r) + 5:
            continue
        out.append(r)
    return out


def header(records, untimed, spike_ms, spikes):
    if not records:
        print("No timestamped records in range. Is this Timing.log (not Server.log), and is the range right?",
              file=sys.stderr)
        sys.exit(2)
    cov = coverage(records)
    gaps = sorted(r["gap"] for r in records if r["gap"] and r["gap"] <= 600)
    typical = gaps[len(gaps) // 2] if gaps else None
    print(f"Records: {len(records)}  from {records[0]['ts']} to {records[-1]['ts']}")
    if untimed:
        print(f"  ({untimed} 'Update time diff' lines had no timestamp and were ignored)")
    if read_timing.incomplete:
        print(f"  ({read_timing.incomplete} incomplete record(s) skipped: a block missing its first line, Mean, Median "
              "or Percentiles, usually the one being written when the file was copied)")
    if typical:
        print(f"Typical spacing between records: {typical:.0f} s")
    if cov is not None:
        print(f"Coverage: the windows saw about {cov * 100:.0f}% of the time "
              f"(a spike in the other {100 - cov * 100:.0f}% is not in the file)")
    print(f"Spikes (window max >= {spike_ms} ms): {len(spikes)}")
    return typical


def resultant(times, period):
    """Length of the mean phase vector, 0..1. Near 1: the times line up at this period."""
    if not times:
        return 0.0
    total = sum(cmath.exp(2j * math.pi * ((t % period) / period)) for t in times)
    return abs(total) / len(times)


def cmd_periodicity(args):
    records, untimed = read_timing(args.timing, args.start, args.end, args.min_players)
    spikes = spikes_of(records, args.spike_ms)
    typical = header(records, untimed, args.spike_ms, spikes)
    if len(spikes) < 2:
        print("Fewer than 2 spikes: nothing to test. Collect more evenings or lower --spike-ms.")
        return
    stamps = [s["ts"].timestamp() for s in spikes]
    control = [r["ts"].timestamp() for r in records]
    gaps = [b - a for a, b in zip(stamps, stamps[1:])]
    print("\nInter-spike intervals, minutes (sorted):")
    print("  " + ", ".join(f"{g / 60:.1f}" for g in sorted(gaps)))
    edges = [2, 5, 10, 15, 20, 30, 60, 120]
    counts = [0] * (len(edges) + 1)
    for g in gaps:
        counts[next((i for i, e in enumerate(edges) if g / 60 < e), len(edges))] += 1
    labels = [f"<{edges[0]}"] + [f"{a}-{b}" for a, b in zip(edges, edges[1:])] + [f">={edges[-1]}"]
    print("  histogram (min): " + "  ".join(f"{l}:{c}" for l, c in zip(labels, counts)))

    periods = args.periods or [120, 300, 600, 900, 1200, 1800, 3600, 7200]
    print("\nFold test. R is 0..1 (1 = every spike at the same phase of the period). 'control' is R for ALL")
    print("records: if it is high too, the server was simply observed at those phases. p is the Rayleigh")
    print("approximation exp(-n*R^2), rough below 10 spikes.")
    print(f"  {'period':>8}  {'R spikes':>8}  {'p':>8}  {'R control':>9}  note")
    for p in periods:
        note = ""
        if typical and p <= typical * 1.5:
            note = "not testable: period is not longer than the record spacing (aliasing)"
        r_s, r_c = resultant(stamps, p), resultant(control, p)
        pval = math.exp(-len(stamps) * r_s * r_s)
        if not note and len(stamps) >= 5 and r_s >= 0.7 and pval <= 0.01 and r_c < 0.3:
            note = "hint: PERIODIC at this period"
        print(f"  {p:>7}s  {r_s:>8.2f}  {pval:>8.3f}  {r_c:>9.2f}  {note}")

    print("A real period also flags every period that divides it (20 min flags 10, 5 and 2 min): take the")
    print("largest flagged period that agrees with the interval list above.")

    print("\nMinute of the hour of each spike record (a clock-aligned job shows as a pile on one minute):")
    by_minute = {}
    for s in spikes:
        by_minute[s["ts"].minute] = by_minute.get(s["ts"].minute, 0) + 1
    print("  " + "  ".join(f":{m:02d}x{c}" for m, c in sorted(by_minute.items())))
    print("\nReminder: each spike happened up to one window (about 500 x Mean ms) BEFORE its record's time,")
    print("and periods at or below the record spacing cannot be seen. See SKILL.md, Gate A.")


def cmd_sessions(args):
    records, untimed = read_timing(args.timing, args.start, args.end)
    spikes = spikes_of(records, args.spike_ms)
    header(records, untimed, args.spike_ms, spikes)
    spike_ids = {id(s) for s in spikes}
    edges = [5, 10, 20, 40, 80]
    labels = [f"0-{edges[0]}"] + [f"{a}-{b}" for a, b in zip(edges, edges[1:])] + [f"{edges[-1]}+"]

    def bucket(minutes):
        return next((i for i, e in enumerate(edges) if minutes < e), len(edges))

    sess = {"rec": [0] * 6, "spk": [0] * 6}
    boot = {"rec": [0] * 6, "spk": [0] * 6}
    by_players = {}
    session_start = restart = empty_since = None
    bots_out = True  # True when the bots are taken to be logged out: after a restart or a long empty spell
    starts = 0
    for r in records:
        if r["gap"] is None or r["gap"] > args.restart_gap:
            restart, session_start, empty_since, bots_out = r["ts"], None, None, True
        if r["players"] == 0:
            if empty_since is None:
                empty_since = r["ts"]
            # Bots log out 300 s after the last real player leaves; a shorter empty spell keeps them in.
            if (r["ts"] - empty_since).total_seconds() >= args.empty_minutes * 60:
                bots_out, session_start = True, None
        else:
            if bots_out:
                session_start, bots_out = r["ts"], False
                starts += 1
            empty_since = None
        is_spike = id(r) in spike_ids
        row = by_players.setdefault(min(r["players"], 5), [0, 0])
        row[0] += 1
        row[1] += is_spike
        if restart:
            b = bucket((r["ts"] - restart).total_seconds() / 60)
            boot["rec"][b] += 1
            boot["spk"][b] += is_spike
        if session_start and r["players"] > 0:
            b = bucket((r["ts"] - session_start).total_seconds() / 60)
            sess["rec"][b] += 1
            sess["spk"][b] += is_spike

    def table(title, data):
        print(f"\n{title}")
        print(f"  {'minutes':>8}  {'records':>7}  {'spikes':>6}  {'spikes per 100 records':>22}")
        for label, n, s in zip(labels, data["rec"], data["spk"]):
            rate = f"{100 * s / n:.1f}" if n else "-"
            print(f"  {label:>8}  {n:>7}  {s:>6}  {rate:>22}")

    print(f"\nSession starts found (first player after >= {args.empty_minutes} min with nobody on, or after a restart): {starts}")
    table("Since the session started (records with players on, inside a detected session):", sess)
    table(f"Since the server (re)started (a gap over {args.restart_gap} s between records counts as a restart):", boot)
    print("\nBy real players online:")
    print(f"  {'players':>8}  {'records':>7}  {'spikes':>6}  {'spikes per 100 records':>22}")
    for p, (n, s) in sorted(by_players.items()):
        print(f"  {str(p) + ('+' if p == 5 else ''):>8}  {n:>7}  {s:>6}  {100 * s / n:>22.1f}")
    print("\nRead it like this: a rate in the first rows several times the later rows = spikes cluster at")
    print("session start (bot logins) or after a restart. Flat rates = not a start-up effect. Rows with")
    print("under ~30 records are too thin to read. Spikes with 0 players on: see SKILL.md (mass bot logout).")


def read_perf(path):
    rows = []
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as handle:
        reader = csv.reader(handle)
        head = next(reader)
        names = [h.split("\\", 3)[-1] if h.startswith("\\\\") else h for h in head]
        for raw in reader:
            if not raw:
                continue
            try:
                ts = datetime.strptime(raw[0], "%m/%d/%Y %H:%M:%S.%f")
            except ValueError:
                continue
            vals = {}
            for name, cell in zip(names[1:], raw[1:]):
                try:
                    vals[name] = float(cell)
                except ValueError:
                    pass  # typeperf writes " " when a counter had no value
            rows.append((ts, vals))
    return names, rows


def cmd_perf_at(args):
    records, untimed = read_timing(args.timing, args.start, args.end, args.min_players)
    spikes = spikes_of(records, args.spike_ms)
    header(records, untimed, args.spike_ms, spikes)
    names, rows = read_perf(args.perf)
    if not rows:
        print("No rows read from the perf CSV.", file=sys.stderr)
        sys.exit(2)
    cores = [n for n in names if re.match(r"Processor\(\d+\)\\% Processor Time", n)]
    steps = sorted((b[0] - a[0]).total_seconds() for a, b in zip(rows, rows[1:]))
    step = steps[len(steps) // 2] if steps else 5.0
    print(f"Perf CSV: {len(rows)} rows from {rows[0][0]} to {rows[-1][0]}, every {step:.0f} s, {len(cores)} cores")
    inside = [s for s in spikes if rows[0][0] <= s["ts"] <= rows[-1][0] + timedelta(seconds=step)]
    print(f"Spikes inside this CSV's time range: {len(inside)} (showing the worst {min(args.top, len(inside))})")
    tally = {}
    for s in sorted(inside, key=lambda r: -r["max"])[: args.top]:
        lo = s["ts"] - timedelta(seconds=window_s(s) + step)
        hi = s["ts"] + timedelta(seconds=2 * step)  # a stalled sampler writes its late row after the stall
        near = sorted(v[WORLD] for ts, v in rows
                      if WORLD in v and abs((ts - s["ts"]).total_seconds()) <= 600 and not lo <= ts <= hi)
        usual = near[len(near) // 2] if near else float("nan")
        print(f"\nSpike record {s['ts']}  max {s['max']} ms  (players {s['players']}, median {s['median']} ms); "
              f"the spike lies between {lo + timedelta(seconds=step):%H:%M:%S} and {s['ts']:%H:%M:%S}. "
              f"World server CPU usually {usual:.0f}% here.")
        print(f"  {'time':>8} {'gap s':>5} {'maxcore%':>8} {'avgcore%':>8} {'world%':>7} {'mysql%':>7} "
              f"{'wr ms':>6} {'rd ms':>6} {'dq':>4} {'pg/s':>6} {'freeMB':>7} {'cpuQ':>4}")
        flags = set()
        prev_ts = None
        for ts, v in rows:
            if ts < lo or ts > hi:
                prev_ts = ts
                continue
            gap = (ts - prev_ts).total_seconds() if prev_ts else float("nan")
            prev_ts = ts
            cv = [v[c] for c in cores if c in v]
            get = lambda key: v.get(key, float("nan"))
            world, mysql = get(WORLD), get("Process(mysqld)\\% Processor Time")
            wr = get("PhysicalDisk(_Total)\\Avg. Disk sec/Write") * 1000
            rd = get("PhysicalDisk(_Total)\\Avg. Disk sec/Read") * 1000
            pages, free = get("Memory\\Pages/sec"), get("Memory\\Available MBytes")
            dq, cpuq = get("PhysicalDisk(_Total)\\Current Disk Queue Length"), get("System\\Processor Queue Length")
            top = max(cv) if cv else float("nan")
            avg = sum(cv) / len(cv) if cv else float("nan")
            print(f"  {ts:%H:%M:%S} {gap:>5.1f} {top:>8.0f} {avg:>8.0f} {world:>7.0f} {mysql:>7.0f} {wr:>6.1f} {rd:>6.1f} "
                  f"{dq:>4.0f} {pages:>6.0f} {free:>7.0f} {cpuq:>4.0f}")
            if gap == gap and gap >= 2 * step:
                flags.add("sampler-gap: typeperf itself paused, so the whole VM stalled (host or Windows level)")
            if wr >= 100 or rd >= 100:
                flags.add("disk: a read or write averaged 100 ms or more")
            if pages >= 1000 and free < 1024:
                flags.add("paging: heavy paging with under 1 GB free")
            if mysql >= 100:
                flags.add("mysql-busy: MySQL used a full core or more")
            if world == world and usual == usual and usual > 0:
                if world <= 0.8 * usual and top == top and top >= 70:
                    flags.add("one-thread: process CPU fell towards one core while one logical CPU was busy: "
                              "a single thread computing and the other threads waiting for it")
                elif world <= 0.8 * usual:
                    flags.add("process-dip: process CPU fell but no single logical CPU stood out: either one "
                              "thread that hopped between CPUs, or a wait (database, lock, disk); 5 s samples cannot tell")
                elif world >= 1.5 * usual:
                    flags.add("world-rise: world server CPU rose to 1.5x its usual level or more (many threads computing)")
        if not flags:
            flags.add("nothing stood out at 5 s resolution")
        for f in sorted(flags):
            print(f"  hint: {f}")
            tally[f.split(":")[0]] = tally.get(f.split(":")[0], 0) + 1
    if tally:
        print("\nHints across the spikes shown: " + ", ".join(f"{k} x{v}" for k, v in sorted(tally.items(), key=lambda kv: -kv[1])))
    print("A 2-5 s spike fills at most one 5 s sample, so its mark is diluted; '% Processor Time' for a")
    print("process is per core (100 = one full core). 'usual' is the median within 10 minutes of the spike.")
    print("No hint is not evidence of absence at this resolution: read the rows.")


def cmd_cycle(args):
    """Is there a repeating beat in the 5-second counters, and does a record's worst tick go with a CPU dip?"""
    names, rows = read_perf(args.perf)
    rows = [(ts, v) for ts, v in rows if WORLD in v and (not args.start or ts >= args.start) and (not args.end or ts < args.end)]
    if len(rows) < 60:
        print("Fewer than 60 counter rows in range (5 minutes): widen --from/--to.", file=sys.stderr)
        sys.exit(2)
    cores = [n for n in names if re.match(r"Processor\(\d+\)\\% Processor Time", n)]
    world = [v[WORLD] for _, v in rows]
    mean = sum(world) / len(world)
    dev = [x - mean for x in world]
    den = sum(d * d for d in dev) or 1.0
    print(f"Counter rows: {len(rows)} from {rows[0][0]:%Y-%m-%d %H:%M:%S} to {rows[-1][0]:%H:%M:%S}; "
          f"world server CPU mean {mean:.0f}% (100 = one core)")
    print("Autocorrelation of world server CPU (1.0 = repeats exactly; near 0 = no beat at that lag):")
    print("  " + "  ".join(f"{lag * 5}s:{sum(dev[i] * dev[i + lag] for i in range(len(dev) - lag)) / den:+.2f}"
                           for lag in range(1, 15)))

    def fold(period, value, bins=8):
        out = [[] for _ in range(bins)]
        for ts, v in rows:
            x = value(v)
            if x is not None:
                out[int((ts.timestamp() % period) / period * bins)].append(x)
        return out

    def explained(groups):
        flat = [x for g in groups for x in g]
        m = sum(flat) / len(flat)
        total = sum((x - m) ** 2 for x in flat) or 1.0
        return sum(len(g) * (sum(g) / len(g) - m) ** 2 for g in groups if g) / total

    print("\nBest period near each candidate (share of the CPU's variation explained by folding at it; a beat")
    print("that is really there explains 0.2 or more, noise explains about 0.01-0.03):")
    best_overall = (0.0, None)
    for centre in args.around:
        best = max((explained(fold(centre + k * 0.005, lambda v: v.get(WORLD))), centre + k * 0.005)
                   for k in range(-int(centre * 10), int(centre * 10) + 1))  # +/- 5% of the candidate
        print(f"  near {centre:>5.1f} s: best {best[1]:.3f} s explains {best[0]:.2f}")
        best_overall = max(best_overall, best)
    for centre in (11.3, 17.3, 23.9):  # periods nothing is known to run at: what the same search finds in noise
        noise = max(explained(fold(centre + k * 0.005, lambda v: v.get(WORLD)))
                    for k in range(-int(centre * 10), int(centre * 10) + 1))
        print(f"  control {centre:>4.1f} s: best explains {noise:.2f}")
    print("  Trust a candidate only if it explains at least twice what the controls do (short ranges overfit).")
    period = best_overall[1]
    print(f"\nProfile over one {period:.3f} s cycle, 8 equal slices (mean per slice):")
    show = [("world server CPU %", lambda v: v.get(WORLD)),
            ("busiest logical CPU %", lambda v: max((v[c] for c in cores if c in v), default=None)),
            ("mysqld CPU %", lambda v: v.get("Process(mysqld)\\% Processor Time"))]
    for label, value in show:
        groups = fold(period, value)
        print(f"  {label:<22} " + " ".join(f"{sum(g) / len(g):>5.0f}" if g else "    -" for g in groups)
              + f"   (explains {explained(groups):.2f})")
    if not args.timing:
        return
    records, _ = read_timing(args.timing, args.start, args.end, args.min_players)

    def link(shift):
        """Correlation between a record's worst tick and the lowest CPU sample in its window moved by shift s."""
        pairs = []
        for r in records:
            lo = r["ts"] - timedelta(seconds=window_s(r) + shift)
            hi = r["ts"] + timedelta(seconds=5 - shift)
            inside = [v[WORLD] for ts, v in rows if lo <= ts <= hi]
            if inside:
                pairs.append((r["max"], min(inside)))
        if len(pairs) < 10:
            return None, len(pairs)
        mx, my = sum(p[0] for p in pairs) / len(pairs), sum(p[1] for p in pairs) / len(pairs)
        sxy = sum((a - mx) * (b - my) for a, b in pairs)
        sxx, syy = sum((a - mx) ** 2 for a, _ in pairs), sum((b - my) ** 2 for _, b in pairs)
        return (sxy / math.sqrt(sxx * syy) if sxx and syy else float("nan")), len(pairs)

    corr, n = link(0)
    if corr is None:
        print("\nFewer than 10 Timing.log records overlap these rows: no link test.")
        return
    print(f"\nLink to Timing.log ({n} records): correlation between a record's worst tick and the lowest")
    print(f"world server CPU sample inside its window: {corr:+.2f}  (clearly negative = long ticks are moments when")
    print("the process as a whole does LESS: one thread works while the map threads wait).")
    controls = [(shift, link(shift)[0]) for shift in (7, 13, 20, 27, 33, 40)]
    print("Control, the same windows moved earlier by 7 / 13 / 20 / 27 / 33 / 40 s (the first two still overlap\n"
          "most of the true window): "
          + "  ".join(f"{c:+.2f}" if c is not None else "-" for _, c in controls))
    print("Trust the link only if it is clearly stronger than every control. It is a correlation, not a cause.")
    print("(Where in the cycle the lowest sample falls is not printed: any window of 20 s or more contains the")
    print("beat's dip whether or not it holds a long tick, so that says nothing extra.)")


def cmd_metric(args):
    records, untimed = read_timing(args.timing, args.start, args.end)
    header(records, untimed, args.max_ms, spikes_of(records, args.max_ms))
    lo, hi = args.evening
    days = {}
    for r in records:
        if lo <= r["ts"].hour < hi and r["players"] >= args.min_players:
            days.setdefault(r["ts"].date(), []).append(r)
    print(f"\nProposed exit metric (not yet adopted by James). Evening = {lo}:00-{hi}:00, records with >= "
          f"{args.min_players} players.")
    print(f"PASS needs all of: at least {args.min_records} records; no window max >= {args.max_ms} ms; "
          f"worst window p99 < {args.p99_ms} ms; >= 95% of windows with p95 <= {args.p95_ms} ms.")
    print(f"  {'evening':>10} {'records':>7} {'max>=lim':>8} {'worst max':>9} {'worst p99':>9} {'p95 ok %':>8}  verdict")
    streak = best = 0
    last_verdict = None
    for day in sorted(days):
        rs = days[day]
        over = sum(r["max"] >= args.max_ms for r in rs)
        worst_max, worst_p99 = max(r["max"] for r in rs), max(r["p99"] for r in rs)
        ok95 = 100.0 * sum(r["p95"] <= args.p95_ms for r in rs) / len(rs)
        if len(rs) < args.min_records:
            verdict = "NO DATA (too few records with players on)"
        elif over == 0 and worst_p99 < args.p99_ms and ok95 >= 95.0:
            verdict = "PASS"
        else:
            verdict = "FAIL"
        streak = streak + 1 if verdict == "PASS" else (streak if verdict.startswith("NO DATA") else 0)
        if not verdict.startswith("NO DATA"):
            last_verdict = verdict
        best = max(best, streak)
        print(f"  {day!s:>10} {len(rs):>7} {over:>8} {worst_max:>9} {worst_p99:>9} {ok95:>8.1f}  {verdict}")
    print(f"\nCurrent run of PASS evenings: {streak} (longest {best}). Evenings with no data do not break or extend a run.")
    print("A PASS only means no spike was SEEN: check the coverage line above. Below about 90% coverage,")
    print("shorten RecordUpdateTimeDiffInterval first (SKILL.md, Phase 1 step 4).")
    if last_verdict is None:
        print(f"No evening with at least {args.min_records} such records: no verdict. (If play was outside "
              f"{lo}:00-{hi}:00, set --evening FROM_HOUR TO_HOUR; if one player, --min-players 1.)")
        sys.exit(2)
    sys.exit(0 if last_verdict == "PASS" else 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    def common(p, players=True):
        p.add_argument("timing", help="Timing.log")
        p.add_argument("--from", dest="start", type=when, metavar="WHEN")
        p.add_argument("--to", dest="end", type=when, metavar="WHEN")
        if players:
            p.add_argument("--min-players", type=int, default=None, help="only records with at least this many real players")

    p = sub.add_parser("periodicity", help="inter-spike intervals and a fold test per candidate period")
    common(p)
    p.add_argument("--spike-ms", type=int, default=500)
    p.add_argument("--periods", type=int, nargs="+", metavar="SECONDS", help="candidate periods to fold at")
    p.set_defaults(func=cmd_periodicity)

    p = sub.add_parser("sessions", help="spikes by time since login, since restart, and by players online")
    common(p, players=False)
    p.add_argument("--spike-ms", type=int, default=500)
    p.add_argument("--empty-minutes", type=float, default=5.0, help="nobody on for this long = bots logged out (default 5)")
    p.add_argument("--restart-gap", type=int, default=180, help="seconds without a record that count as a restart")
    p.set_defaults(func=cmd_sessions)

    p = sub.add_parser("perf-at", help="the Windows counters around each spike, with hints")
    common(p)
    p.add_argument("perf", help="perf-YYYY-MM-DD_HHmm.csv covering the spikes")
    p.add_argument("--spike-ms", type=int, default=500)
    p.add_argument("--top", type=int, default=10)
    p.set_defaults(func=cmd_perf_at)

    p = sub.add_parser("cycle", help="a beat under a minute in the 5 s counters, and its link to long ticks")
    p.add_argument("perf", help="perf-YYYY-MM-DD_HHmm.csv")
    p.add_argument("--timing", help="Timing.log, to test whether a larger worst tick goes with a deeper CPU dip")
    p.add_argument("--from", dest="start", type=when, metavar="WHEN")
    p.add_argument("--to", dest="end", type=when, metavar="WHEN")
    p.add_argument("--min-players", type=int, default=1)
    p.add_argument("--around", type=float, nargs="+", default=[10.0, 20.0, 30.0, 60.0], metavar="SECONDS",
                   help="candidate periods; the best period within 5%% of each is searched (default 10 20 30 60)")
    p.set_defaults(func=cmd_cycle)

    p = sub.add_parser("metric", help="the proposed exit metric, evening by evening (exit 0 PASS, 1 FAIL, 2 no data)")
    common(p, players=False)
    p.add_argument("--min-players", type=int, default=2)
    p.add_argument("--evening", type=int, nargs=2, default=[18, 24], metavar=("FROM_HOUR", "TO_HOUR"),
                   help="hours of the day that count as the evening (default 18 24)")
    p.add_argument("--max-ms", type=int, default=500)
    p.add_argument("--p99-ms", type=int, default=150)
    p.add_argument("--p95-ms", type=int, default=50)
    p.add_argument("--min-records", type=int, default=30)
    p.set_defaults(func=cmd_metric)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
