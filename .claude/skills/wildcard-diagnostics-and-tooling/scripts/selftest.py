#!/usr/bin/env python3
"""Runs every diagnostics script against the SYNTHETIC samples and checks it finds what was planted.

    python selftest.py

Prints one line per check and ends with "ALL CHECKS PASSED" (exit code 0) or the list of failures
(exit code 1). Use it after editing a script, and on the server once to confirm its Python runs them
(C:\\Games\\CoA Server\\Runtime\\python\\python.exe selftest.py). It reads only the files in samples\\
and writes only to a temporary folder it removes. Passing here says the parsers handle the formats
as this skill understands them; it says nothing about the real server.

Last run: 2026-11-22, Python 3.13 on Linux, all checks passed. Not yet run on Windows.
The same day the scripts were also run against the real Timing.log, console-history.txt, perf CSV,
mysql-slow.log and Errors.log from the server (see ../references/reference-run-2026-11-22.md); those files
are not in the repository, so this self-test cannot repeat that.
"""
import contextlib
import io
import shutil
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import errors_log_groups  # noqa: E402
import patch_night_summary  # noqa: E402
import perf_csv_summary  # noqa: E402
import slow_query_summary  # noqa: E402
import timing_summary  # noqa: E402

SAMPLES = HERE / "samples"
failures = []


def run(module, *arguments):
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer), contextlib.redirect_stderr(buffer):
        try:
            code = module.main([str(a) for a in arguments])
        except SystemExit as stop:          # argparse --help
            code = stop.code
    return code, buffer.getvalue()


def check(name, condition, detail=""):
    print(("ok    " if condition else "FAIL  ") + name)
    if not condition:
        failures.append(name + (": " + detail if detail else ""))


def main():
    timing = SAMPLES / "SYNTHETIC-Timing.log"
    perf = SAMPLES / "SYNTHETIC-perf-2026-11-21_0508.csv"
    slow = SAMPLES / "SYNTHETIC-mysql-slow.log"
    night = SAMPLES / "SYNTHETIC-patch-night.log"
    errors = SAMPLES / "SYNTHETIC-Errors.log"
    for path in (timing, perf, slow, night, errors):
        if not path.is_file():
            print(f"Missing sample {path}; run samples/make_synthetic_samples.py first.")
            return 1

    for module in (timing_summary, perf_csv_summary, slow_query_summary, patch_night_summary, errors_log_groups):
        code, text = run(module, "--help")
        check(f"{module.__name__} --help", code == 0 and "Examples" in text)
        code, text = run(module, HERE / "no-such-file.log")
        check(f"{module.__name__} missing file gives exit code 2", code == 2)

    # timing_summary: parser
    records, stats = timing_summary.parse_timing(timing)
    check("timing: 117 records (115 whole, 2 cut-off), 1 noise line skipped, 10 shuffled blocks read",
          len(records) == 117 and stats["other"] == 1 and stats["partial"] == 2 and stats["reordered"] == 10,
          str((len(records), stats)))
    whole = [r for r in records if None not in (r["diff"], r["n"], r["mean"], r["median"], r["max"])]
    check("timing: every whole record has all nine numbers, shuffled or not", len(whole) == 115)
    check("timing: two server starts found from the 'Last N diffs' count dropping",
          {r["restart"] for r in records} == {0, 1})
    worst = max((r for r in records if r["max"] is not None), key=lambda r: r["max"])
    check("timing: worst planted pass is 2900 ms at 02:18", worst["max"] == 2900 and worst["ts"].strftime("%H:%M") == "02:18")
    code, text = run(timing_summary, timing, "--split", "2026-11-21 04:00", "--spike-ms", "500")
    check("timing: report runs, lists 5 spikes >= 500 ms and a before/after table",
          code == 0 and "Spikes: 5 of 115" in text and "Before and after 2026-11-21 04:00" in text, text[-600:])
    code, text = run(timing_summary, timing, "--from", "2026-11-21 02:00", "--to", "2026-11-21 04:00", "--max-players", "0")
    check("timing: --from/--to/--max-players keep the nobody-online half hour only (30 records)",
          code == 0 and "kept after" in text and ": 30." in text, text[:900])
    code, text = run(timing_summary, SAMPLES / "SYNTHETIC-console-history.txt")
    check("timing: console-history.txt (first lines only, no timestamps) is read with banners as restarts",
          code == 0 and "start banners: 2" in text and "Switching to them" in text and "Per core revision" in text)
    code, text = run(timing_summary, SAMPLES / "SYNTHETIC-Server-timing-lines.log")
    check("timing: Server.log-style lines without timestamps are read", code == 0 and "timing records: 115" in text)

    # perf_csv_summary
    names, rows, pstats = perf_csv_summary.read_perf(perf)
    check("perf: 25 counters (10 cores), 336 rows, 1 bad row skipped, 18 blank cells in the first row",
          len(names) == 25 and pstats["rows"] == 336 and pstats["bad_rows"] == 1 and pstats["blank_cells"] == 18, str(pstats))
    code, text = run(perf_csv_summary, SAMPLES, "--timing", timing, "--detail", "2")
    lines = text.splitlines()
    core2 = [line for line in lines if line.startswith("core 2")]
    check("perf: the pinned core (core 2) is the only one with busy rows",
          code == 0 and core2 and core2[0].split()[-1] == "14.3%" and "a single thread at its limit" in text)
    moved = [line for line in lines if line.startswith("Disk write latency") and line.rstrip().endswith("100%")]
    still = [line for line in lines if line.startswith("worldserver threads") and line.rstrip().endswith("0%")]
    check("perf: disk write latency moved in the spike windows, thread count did not", bool(moved) and bool(still), text[-1500:])
    check("perf: 2 spike windows matched inside the counter file", "(2 spike with max >= 100 ms" in text)

    # slow_query_summary
    entries, sstats = slow_query_summary.parse_slow_log(slow)
    check("slow: 20 entries, 1 unreadable entry skipped, 1 stray line, 3 header lines",
          len(entries) == 20 and sstats["bad_entries"] == 1 and sstats["stray"] == 1 and sstats["headers"] == 3, str(sstats))
    shapes = {slow_query_summary.fingerprint(e["sql"]) for e in entries}
    check("slow: 3 query shapes; the repeated DELETE is one of them",
          len(shapes) == 3 and "delete from character_spell where spell = ?" in shapes, str(shapes))
    check("slow: IN lists of different lengths collapse", "select guid, name from characters where guid in (?+) and name <> ?" in shapes)
    code, text = run(slow_query_summary, slow, "--utc-offset-hours", "11", "--by-hour", "--by-minute")
    check("slow: report runs and shifts UTC to local time", code == 0 and "2026-11-21 04:00" in text and "per minute" in text)

    # patch_night_summary
    runs, nstats = patch_night_summary.parse_patch_night(night)
    check("patch night: 5 runs, 1 continuation line", len(runs) == 5 and nstats["continuation"] == 1, str(nstats))
    check("patch night: outcomes FAIL, OK, OK, OK, cut off",
          [r["level"] if r["finished"] else "cut" for r in runs] == ["FAIL", "OK", "OK", "OK", "cut"])
    check("patch night: downtimes 118 s and 402 s read", [r["downtime"] for r in runs] == [None, 118, None, 402, None])
    check("patch night: fallback to the official server flagged on the first run only", [r["fallback"] for r in runs] == [True, False, False, False, False])
    code, text = run(patch_night_summary, night, "--last", "2")
    check("patch night: report runs; long downtime and missing finished line are flagged",
          code == 0 and "LONG DOWNTIME" in text and "NO FINISHED LINE" in text)

    # errors_log_groups
    groups, count, blank = errors_log_groups.group(errors)
    check("errors: 52 lines into 4 kinds, the commonest seen 40 times",
          count == 52 and blank == 1 and len(groups) == 4 and max(g["count"] for g in groups.values()) == 40)

    # Encodings Windows tools produce
    scratch = Path(tempfile.mkdtemp(prefix="wildcard-diag-selftest-"))
    try:
        text = night.read_text(encoding="utf-8")
        (scratch / "utf16.log").write_text(text, encoding="utf-16")
        (scratch / "bom.log").write_text(text, encoding="utf-8-sig")
        (scratch / "ansi.log").write_bytes(text.replace("SYNTHETIC timeout", "SYNTHETIC caf\u00e9").encode("cp1252"))
        for name in ("utf16.log", "bom.log", "ansi.log"):
            found, _ = patch_night_summary.parse_patch_night(scratch / name)
            check(f"encoding: {name} gives the same 5 runs", len(found) == 5)
        (scratch / "empty.log").write_text("", encoding="utf-8")
        for module in (timing_summary, slow_query_summary, patch_night_summary, errors_log_groups, perf_csv_summary):
            code, text = run(module, scratch / "empty.log")
            check(f"{module.__name__} on an empty file ends without a traceback", code in (0, 1), text[-300:])
        (scratch / "junk.log").write_bytes(bytes(range(256)) * 20)
        for module in (timing_summary, slow_query_summary, patch_night_summary, errors_log_groups, perf_csv_summary):
            code, text = run(module, scratch / "junk.log")
            check(f"{module.__name__} on binary junk ends without a traceback", code in (0, 1), text[-300:])
    finally:
        shutil.rmtree(scratch, ignore_errors=True)

    print()
    if failures:
        print(f"{len(failures)} CHECK(S) FAILED:")
        for failure in failures:
            print("  " + failure)
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
