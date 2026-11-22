#!/usr/bin/env python3
"""Summarise patch-night.log run by run: outcome, downtime, warnings.

What the file is
    patch-night\\PatchNight.ps1 appends every line it prints to patch-night\\patch-night.log as

        2026-11-22 04:02:41 [INFO] Server is up on core c3f2fd4b2395.

    with a level of INFO, OK, WARN or FAIL (function Log). A run opens with one of

        ---- patch night started ----                               (weekly, nightly, or Run-PatchNight-Now.cmd)
        ---- start server (Start-Server.cmd) ----
        ---- rebuild Wildcard bots (Rebuild-WildcardBots.cmd) ----

    and every run that ends through the script's own Finish closes with
        ---- patch night finished ----
    preceded by the outcome line at level OK (exit code 0) or FAIL. A run with no finished line was
    cut off (the window was closed, the VM went down) or is still going. Lines written before the
    opening line (the script fetching a newer copy of itself) are counted with the run that follows.

What it prints
    One row per run: when, kind, how long the script ran, OK/FAIL, the downtime the script measured
    ("Downtime: N s from the stop until the world was up"), build installed, core, number of WARN
    lines, and flags. Then, per run with anything to look at, its WARN and FAIL lines.

Thresholds (docs/agents/context/patch-night.md): a healthy run ends with "[OK] Patch night OK", and a
downtime of about 2 minutes; "over 5 minutes is worth a mention" - so downtimes over 300 s are flagged
LONG. Two WARN lines that file calls normal are counted but marked "(normal)".

Examples
    python patch_night_summary.py "C:\\Games\\CoA Server\\patch-night\\patch-night.log"
    python patch_night_summary.py patch-night.log --last 14
    python patch_night_summary.py patch-night.log --from 2026-11-15 --warnings all

Tested on synthetic data matching the writer's format on 2026-11-22: the real patch-night.log was not
available. The first run on the real file should be checked by eye.
Python 3.8+, standard library only. Written for Windows and Linux; run so far on Linux (Python 3.13).
"""
import argparse
import re
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import TESTED_SYNTHETIC, mean, percentile, read_lines, safe_stdout, table, when_arg  # noqa: E402

LINE = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d) \[(INFO|OK|WARN|FAIL)\] (.*)$")
OPENERS = {
    "---- patch night started ----": "patch night",
    "---- start server (Start-Server.cmd) ----": "start server",
    "---- rebuild Wildcard bots (Rebuild-WildcardBots.cmd) ----": "rebuild bots",
}
CLOSER = "---- patch night finished ----"
LONG_DOWNTIME = 300   # "Over 5 minutes is worth a mention": docs/agents/context/patch-night.md
NORMAL_WARNINGS = ("No patched build found for this core, but the installed patched server matches it",)

RE_DOWNTIME = re.compile(r"^Downtime: (\d+) s ")
RE_UP = re.compile(r"^Server is up on core (\S+?)\.?$")
RE_INSTALLING = re.compile(r"^Installing (\S+?)\.\.\.$")
RE_INSTALLED = re.compile(r"installed (wcme-server-[\w.]+-build\d+)")
RE_PREPARED = re.compile(r"^Prepared in (\d+) s")
RE_PLAYERS = re.compile(r"^Players online: (\w+)\.")
RE_SETTINGS = re.compile(r"^Settings: the server runs (\d+) setting\(s\) on defaults .* could not use (\d+)")


def new_run(kind, ts):
    return {"kind": kind, "start": ts, "end": None, "finished": False, "level": None, "outcome": None,
            "downtime": None, "core": None, "installing": None, "installed": None, "prepared": None,
            "players": None, "defaults": None, "bad_settings": None, "warn": [], "fail": [], "lines": 0,
            "fallback": False, "nightly_skip": False, "self_update": False}


def parse_patch_night(path):
    """Returns (runs, stats)."""
    stats = {"lines": 0, "continuation": 0, "before_first_run": 0}
    runs = []
    current = None
    preamble = []          # parsed lines seen while no run is open
    last = None            # (ts, level, message) of the previous parsed line

    def absorb(run, ts, level, message):
        run["lines"] += 1
        run["end"] = ts
        if level == "WARN":
            run["warn"].append((ts, message))
        elif level == "FAIL":
            run["fail"].append((ts, message))
        if level in ("OK", "FAIL"):
            run["level"], run["outcome"] = level, message
        for pattern, key, cast in ((RE_DOWNTIME, "downtime", int), (RE_UP, "core", str),
                                   (RE_INSTALLING, "installing", str), (RE_PREPARED, "prepared", int),
                                   (RE_PLAYERS, "players", str)):
            found = pattern.search(message)
            if found:
                run[key] = cast(found.group(1))
        found = RE_INSTALLED.search(message)
        if found and level == "OK":
            run["installed"] = found.group(1)
        found = RE_SETTINGS.search(message)
        if found:
            run["defaults"], run["bad_settings"] = int(found.group(1)), int(found.group(2))
        if "Putting the official world server back" in message or "official server is running instead" in message:
            run["fallback"] = True
        if "the new build is left for the weekly patch night" in message:
            run["nightly_skip"] = True
        if "Running the newer patch-night script just downloaded" in message:
            run["self_update"] = True

    for raw in read_lines(path):
        stats["lines"] += 1
        match = LINE.match(raw)
        if not match:
            if raw.strip():
                stats["continuation"] += 1
                # A message that ran over several lines: keep it with a WARN/FAIL it continues.
                if current is not None and last and last[1] in ("WARN", "FAIL"):
                    bucket = current["warn"] if last[1] == "WARN" else current["fail"]
                    if bucket:
                        bucket[-1] = (bucket[-1][0], bucket[-1][1] + " | " + raw.strip())
            continue
        try:
            ts = datetime.strptime(match.group(1), "%Y-%m-%d %H:%M:%S")
        except ValueError:
            stats["continuation"] += 1
            continue
        level, message = match.group(2), match.group(3)
        last = (ts, level, message)
        if message in OPENERS:
            if current is not None:
                runs.append(current)            # the previous run never reached its finished line
            current = new_run(OPENERS[message], ts)
            for item in preamble:
                absorb(current, *item)
            current["end"] = ts
            preamble = []
            continue
        if message == CLOSER:
            if current is not None:
                current["finished"] = True
                current["end"] = ts
                runs.append(current)
                current = None
            else:
                stats["before_first_run"] += 1
            continue
        if current is None:
            preamble.append((ts, level, message))
        else:
            absorb(current, ts, level, message)
    if current is not None:
        runs.append(current)
    stats["before_first_run"] += len(preamble)
    return runs, stats


def flags(run):
    out = []
    if not run["finished"]:
        out.append("NO FINISHED LINE")
    if run["fallback"]:
        out.append("FELL BACK TO OFFICIAL")
    if run["downtime"] is not None and run["downtime"] > LONG_DOWNTIME:
        out.append("LONG DOWNTIME")
    if run["bad_settings"]:
        out.append(f"{run['bad_settings']} BAD SETTING VALUE(S)")
    if run["installing"] and not run["installed"]:
        out.append("INSTALL NOT CONFIRMED")
    if run["nightly_skip"]:
        out.append("new build left for weekly")
    if run["self_update"]:
        out.append("script updated itself")
    return ", ".join(out)


def is_normal(message):
    return any(text in message for text in NORMAL_WARNINGS)


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log", type=Path, help="patch-night.log")
    parser.add_argument("--from", dest="start", type=when_arg, metavar="WHEN", help="only runs that started at or after this")
    parser.add_argument("--to", dest="end", type=when_arg, metavar="WHEN", help="only runs that started before this")
    parser.add_argument("--last", type=int, metavar="N", help="only the newest N runs")
    parser.add_argument("--warnings", choices=("problems", "all", "none"), default="problems",
                        help="which runs get their WARN/FAIL lines printed: those with anything to look at "
                             "(default), all, or none")
    parser.add_argument("--width", type=int, default=160, help="cut printed log lines at this many characters")
    return parser


def main(argv=None):
    safe_stdout()
    args = build_parser().parse_args(argv)
    if not args.log.is_file():
        print(f"No such file: {args.log}", file=sys.stderr)
        return 2
    runs, stats = parse_patch_night(args.log)
    print(f"File: {args.log}")
    print(f"Lines read: {stats['lines']}; runs found: {len(runs)}; lines without the 'date [LEVEL]' shape "
          f"(continuations of a longer message, or unreadable): {stats['continuation']}; "
          f"lines outside any run: {stats['before_first_run']}.")
    if args.start:
        runs = [r for r in runs if r["start"] >= args.start]
    if args.end:
        runs = [r for r in runs if r["start"] < args.end]
    if args.last:
        runs = runs[-args.last:]
    if not runs:
        print("No runs in range.")
        return 1
    rows = []
    for run in runs:
        duration = (run["end"] - run["start"]).total_seconds() if run["end"] else None
        if run["finished"]:
            result = run["level"] or "?"
        else:
            result = "cut off"
        real_warnings = [m for _, m in run["warn"] if not is_normal(m)]
        rows.append([f"{run['start']:%Y-%m-%d %a %H:%M}", run["kind"],
                     f"{duration / 60:.0f} min" if duration is not None else "-", result,
                     f"{run['downtime']} s" if run["downtime"] is not None else "-",
                     run["installed"] or (f"({run['installing']}?)" if run["installing"] else "-"),
                     (run["core"] or "-")[:12], len(real_warnings),
                     run["players"] if run["players"] is not None else "-", flags(run)])
    print()
    print(table(["started", "kind", "script ran", "result", "downtime", "build installed", "core", "WARN",
                 "players", "flags"], rows, right={2, 4, 7, 8}))
    print()

    finished = [r for r in runs if r["finished"]]
    ok = [r for r in finished if r["level"] == "OK"]
    failed = [r for r in finished if r["level"] == "FAIL"]
    downtimes = [r["downtime"] for r in runs if r["downtime"] is not None]
    print(f"Runs: {len(runs)}; OK: {len(ok)}; FAIL: {len(failed)}; cut off or still running: {len(runs) - len(finished)}; "
          f"fell back to the official server: {len([r for r in runs if r['fallback']])}.")
    if downtimes:
        print(f"Downtime over {len(downtimes)} run(s) that reported it: median {percentile(downtimes, 50):.0f} s, "
              f"average {mean(downtimes):.0f} s, worst {max(downtimes)} s; over {LONG_DOWNTIME} s: "
              f"{len([d for d in downtimes if d > LONG_DOWNTIME])}.")
    else:
        print("No run reported a 'Downtime:' line (it was added to the script on 22 Nov 2026; older runs and "
              "Start-Server runs do not have it).")
    print()

    if args.warnings != "none":
        for run in runs:
            interesting = (run["fail"] or not run["finished"] or run["fallback"]
                           or any(not is_normal(m) for _, m in run["warn"]))
            if args.warnings == "problems" and not interesting:
                continue
            if not (run["warn"] or run["fail"] or run["outcome"] or not run["finished"]):
                continue
            print(f"{run['start']:%Y-%m-%d %H:%M} {run['kind']}:")
            for ts, message in sorted([(t, "WARN  " + m + ("  (normal)" if is_normal(m) else "")) for t, m in run["warn"]]
                                      + [(t, "FAIL  " + m) for t, m in run["fail"]], key=lambda item: item[0]):
                print(f"  {ts:%H:%M:%S} {message[:args.width]}")
            if run["outcome"] and run["level"] == "OK":
                print(f"  outcome: {run['outcome'][:args.width]}")
            if not run["finished"]:
                print(f"  no finished line; the last line was at {run['end']:%Y-%m-%d %H:%M:%S}.")
        print()
    print(TESTED_SYNTHETIC.format(what="patch-night.log"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
