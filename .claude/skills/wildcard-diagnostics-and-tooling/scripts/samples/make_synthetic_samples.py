#!/usr/bin/env python3
"""Writes the SYNTHETIC-* sample files in this folder. Every number in them is made up.

They exist only so the analysis scripts can be tested without the server: the line shapes match what
the writers produce (see ../../references/formats.md for where each shape comes from), the values do
not come from the Wildcard server. Never quote a number from these files as a measurement.

The generator is seeded, so running it again writes the same files:
    python make_synthetic_samples.py

Planted on purpose, so the tests can check the scripts find them:
  - Timing: two server starts (01:50 and 05:03), nobody online from 02:30, slow passes at 02:17-02:19,
    05:20, 05:30 and 05:44; a few blocks with their five lines shuffled (the real file has those).
  - Counters (10 cores, as on the server): disk write latency and mysqld CPU jump in the same minutes as
    the 05:20 and 05:30 spikes; core 2 is pinned near 100% from 05:10 to 05:14 while the others idle;
    the first row has blanks for the rate counters (the real file does).
  - Slow queries: one statement repeated with different numbers (must group into one fingerprint).
  - Patch night: a run that fell back to the official server, an OK run, a Start-Server run, an OK run
    with a long downtime, and a run cut off without its finished line.
  - Each file has a few lines that do not fit the format (must be skipped and counted, not crash).
"""
import argparse
import random
import sys

sys.dont_write_bytecode = True
from datetime import datetime, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
random.seed(20261122)


def timing():
    lines = []
    lines_plain = []          # the same records the way Server.log has them: no timestamps
    history = []              # console-history.txt shape: "<line number>: <console line>"
    console_line = 0

    def record(ts, diff, players, n, mean, median, p95, p99, worst):
        nonlocal console_line
        stamp = ts.strftime("%Y-%m-%d %H:%M:%S")
        body = [f"Update time diff: {diff}ms with {players} players online",
                f"Last {n} diffs summary:",
                f"|- Mean: {mean}ms",
                f"|- Median: {median}ms",
                f"|- Percentiles (95, 99, max): {p95}ms, {p99}ms, {worst}ms"]
        stamped = [f"{stamp} {text}" for text in body]
        if len(lines) % 35 == 0:                 # some blocks arrive shuffled, as in the real file
            stamped[0], stamped[1] = stamped[1], stamped[0]
            stamped[3], stamped[4] = stamped[4], stamped[3]
        lines.extend(stamped)
        lines_plain.extend(body)
        console_line += random.randint(40, 400)
        history.append(f"{console_line}: {body[0]}")

    def run(start, minutes, players_at, spikes, first_n):
        for minute in range(minutes):
            ts = start + timedelta(minutes=minute, seconds=random.randint(0, 2))
            players = players_at(ts)
            n = min(500, first_n + minute * 400)
            base = 5 if players == 0 else 18 + 2 * players
            mean = max(1, int(random.gauss(base, base * 0.08)))
            median = max(1, mean - random.randint(0, 3))
            p95 = int(mean * random.uniform(1.6, 2.0))
            p99 = int(p95 * random.uniform(1.2, 1.6))
            worst = int(p99 * random.uniform(1.1, 1.5))
            key = ts.strftime("%H:%M")
            if key in spikes:
                worst = spikes[key]
                p99 = max(p99, int(worst * 0.4))
            diff = max(1, int(random.gauss(mean, mean * 0.2)))
            record(ts, diff, players, n, mean, median, p95, p99, worst)

    def players_first(ts):
        return 3 if (ts.hour, ts.minute) < (2, 30) else 0          # nobody on from 02:30

    def players_second(ts):
        return 2

    banner = "AzerothCore rev. 000000000000+ 2026-01-01 00:00:00 +0000 (SYNTHETIC branch) (Win64, RelWithDebInfo, Static)"
    console_line += 1
    history.append(f"{console_line}: {banner}")
    lines_plain.append(banner)
    run(datetime(2026, 11, 21, 1, 50, 5), 70, players_first,
        {"02:17": 2450, "02:18": 2900, "02:19": 1310}, first_n=500)
    lines.append("this line does not belong in a timing log (SYNTHETIC noise)")
    lines.append("2026-11-21 03:59:59 |- Mean: 12ms")       # a summary line cut loose from its record
    console_line += 1
    history.append(f"{console_line}: {banner}")
    console_line += 5000
    history.append(f"{console_line}: World Initialized In 3 Minutes 12 Seconds")
    lines_plain.append(banner)
    run(datetime(2026, 11, 21, 5, 3, 40), 45, players_second, {"05:20": 950, "05:30": 1875, "05:44": 240}, first_n=1)
    lines.append("2026-11-21 05:48:41 Last 500 diffs summary:")   # the file was copied mid-write: a cut-off block

    (HERE / "SYNTHETIC-Timing.log").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\r\n")
    (HERE / "SYNTHETIC-Server-timing-lines.log").write_text("\n".join(lines_plain) + "\n", encoding="utf-8",
                                                           newline="\r\n")
    (HERE / "SYNTHETIC-console-history.txt").write_text("\n".join(history) + "\n", encoding="utf-8", newline="\r\n")


def counters():
    host = "\\\\SYNTHETIC-HOST"
    names = [f"\\Processor({i})\\% Processor Time" for i in range(10)] + [
        "\\Processor(_Total)\\% Processor Time", "\\System\\Processor Queue Length",
        "\\System\\Context Switches/sec", "\\Memory\\Available MBytes", "\\Memory\\Pages/sec",
        "\\Paging File(_Total)\\% Usage", "\\PhysicalDisk(_Total)\\Avg. Disk sec/Read",
        "\\PhysicalDisk(_Total)\\Avg. Disk sec/Write", "\\PhysicalDisk(_Total)\\Current Disk Queue Length",
        "\\PhysicalDisk(_Total)\\% Idle Time", "\\Process(worldserver)\\% Processor Time",
        "\\Process(worldserver)\\Working Set", "\\Process(worldserver)\\Thread Count",
        "\\Process(mysqld)\\% Processor Time", "\\Process(mysqld)\\Working Set"]
    header = ['"(PDH-CSV 4.0) (AUS Eastern Daylight Time)(-660)"'] + [f'"{host}{name}"' for name in names]
    rows = [",".join(header)]
    start = datetime(2026, 11, 21, 5, 8, 2, 123000)
    working_set = 6.0e9
    for step in range(int(28 * 60 / 5)):                # 05:08 to 05:36, every 5 s
        ts = start + timedelta(seconds=5 * step)
        spike = (datetime(2026, 11, 21, 5, 29, 40) <= ts <= datetime(2026, 11, 21, 5, 30, 45)
                 or datetime(2026, 11, 21, 5, 20, 20) <= ts <= datetime(2026, 11, 21, 5, 20, 45))
        pinned = datetime(2026, 11, 21, 5, 10) <= ts < datetime(2026, 11, 21, 5, 14)
        cores = [max(0.0, min(100.0, random.gauss(22, 6))) for _ in range(10)]
        if pinned:
            cores[2] = random.uniform(96, 100)
        if spike:
            cores = [min(100.0, c + 10) for c in cores]
        total = sum(cores) / 10
        working_set += random.uniform(0, 4.0e5)
        values = cores + [
            total,
            float(random.choice([0, 0, 0, 1, 1, 2]) + (6 if spike else 0)),
            random.gauss(42000, 3000),
            random.gauss(7200, 40),
            abs(random.gauss(3, 3)) + (40 if spike else 0),
            random.gauss(9.5, 0.1),
            abs(random.gauss(0.0006, 0.0003)),
            abs(random.gauss(0.0012, 0.0004)) + (random.uniform(0.25, 0.9) if spike else 0),
            float(random.choice([0, 0, 0, 1]) + (9 if spike else 0)),
            max(0.0, random.gauss(97, 1.5) - (80 if spike else 0)),
            sum(cores) * 0.7,
            working_set,
            28.0,
            abs(random.gauss(18, 5)) + (160 if spike else 0),
            4.6e9 + random.uniform(0, 1e6)]
        cells = [f'"{ts:%m/%d/%Y %H:%M:%S}.{ts.microsecond // 1000:03d}"'] + [f'"{value:.6f}"' for value in values]
        if step == 0:                                    # the real file's first row: rate counters are blank
            for index in list(range(1, 12)) + [13, 15, 17, 18, 20, 21, 24]:
                cells[index] = '" "'
        rows.append(",".join(cells))
    rows.insert(100, '"not a timestamp","1","2"')         # noise: wrong shape
    (HERE / "SYNTHETIC-perf-2026-11-21_0508.csv").write_text("\n".join(rows) + "\n", encoding="ascii",
                                                              newline="\r\n")


def slow_queries():
    out = ["C:\\SYNTHETIC\\mysql\\bin\\mysqld.exe, Version: 8.4.0 (MySQL Community Server - GPL). started with:",
           "TCP Port: 3306, Named Pipe: MySQL",
           "Time                 Id Command    Argument"]

    def entry(ts, seconds, lock, sent, examined, sql, database=None, thread=11):
        out.append(f"# Time: {ts:%Y-%m-%dT%H:%M:%S}.{random.randint(0, 999999):06d}Z")
        out.append(f"# User@Host: acore[acore] @ localhost [127.0.0.1]  Id: {thread:5d}")
        out.append(f"# Query_time: {seconds:.6f}  Lock_time: {lock:.6f} Rows_sent: {sent}  Rows_examined: {examined}")
        if database:
            out.append(f"use {database};")
        out.append(f"SET timestamp={int((ts - datetime(1970, 1, 1)).total_seconds())};")
        out.extend(sql.split("\n"))

    base = datetime(2026, 11, 20, 17, 0, 0)               # UTC, as MySQL writes it by default
    for i in range(14):
        entry(base + timedelta(minutes=7 * i, seconds=random.randint(0, 50)), random.uniform(0.6, 3.4), 0.0002, 0,
              random.randint(1650000, 1720000),
              f"DELETE FROM character_spell WHERE spell = {random.choice([14009999, 14009998])};",
              "synthetic_characters" if i == 0 else None)
    for i in range(5):
        guids = ", ".join(str(random.randint(1000, 9000)) for _ in range(random.randint(3, 40)))
        entry(base + timedelta(minutes=30 + 11 * i), random.uniform(0.5, 0.9), 0.00001, random.randint(3, 40), 52000,
              f"SELECT guid, name FROM characters\n  WHERE guid IN ({guids}) /* synthetic */ AND name <> 'Synth''etic';")
    entry(datetime(2026, 11, 20, 18, 30, 12), 12.75, 4.5, 0, 9000000,
          "UPDATE synthetic_table SET value = 0x1F, note = \"x\" WHERE id = -42 AND ratio > 1.5e3;", thread=14)
    out.insert(40, "?? a line that is not part of an entry (SYNTHETIC noise)")
    out.append("# Time: 2026-11-20T19:00:00.000000Z")
    out.append("# User@Host: acore[acore] @ localhost [127.0.0.1]  Id:    11")
    out.append("# Query_time: not-a-number  Lock_time: 0 Rows_sent: 0  Rows_examined: 0")
    out.append("SELECT 1;")
    (HERE / "SYNTHETIC-mysql-slow.log").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\r\n")


def patch_night():
    out = []

    def log(ts, message, level="INFO"):
        out.append(f"{ts:%Y-%m-%d %H:%M:%S} [{level}] {message}")

    # 1. a weekly patch night that installed a build, failed to come up, and fell back
    t = datetime(2026, 11, 17, 23, 0, 3)
    log(t, "---- patch night started ----")
    log(t, "Patched build available: wcme-server-0.000000.000-build2.")
    log(t + timedelta(seconds=3), "Players online: 2. Counting down 10 minutes while preparing.")
    log(t + timedelta(seconds=4), "Downloading wcme-server-0.000000.000-build2.zip (38 MB)...")
    log(t + timedelta(seconds=50), "Prepared in 46 s, with the server up.")
    log(t + timedelta(minutes=10, seconds=8), "Installing wcme-server-0.000000.000-build2...")
    log(t + timedelta(minutes=10, seconds=30), "Starting the server (this waits until the world is up, up to 25 minutes)...")
    log(t + timedelta(minutes=12, seconds=45), "The world server is not running.", "WARN")
    log(t + timedelta(minutes=12, seconds=45), "Putting the official world server back...", "WARN")
    log(t + timedelta(minutes=12, seconds=50), "Starting the server (this waits until the world is up, up to 25 minutes)...")
    log(t + timedelta(minutes=16, seconds=20), "Server is up on core 000000000000.")
    out.append("  a continuation line without a timestamp (SYNTHETIC; a multi-line message)")
    log(t + timedelta(minutes=16, seconds=21), "Patch night FAILED on the patched server; the official server is running instead "
        "(no Mystic Enchants). See patch-night.log.", "FAIL")
    log(t + timedelta(minutes=16, seconds=21), "---- patch night finished ----")

    # 2. a nightly restart that went well
    t = datetime(2026, 11, 20, 3, 30, 2)
    log(t, "---- patch night started ----")
    log(t, "The manager's installed core is 000000000000 (from worldserver.official.exe).")
    log(t, "The auth server reports core 000000000000.")
    log(t, "Patched build available: wcme-server-0.000000.000-build1.")
    log(t, "It is already installed.")
    log(t + timedelta(seconds=4), "Players online: 0. Counting down 30 minutes while preparing.")
    log(t + timedelta(seconds=5), "Applying server-settings (used from the restart)...")
    log(t + timedelta(seconds=21), "Prepared in 16 s, with the server up.")
    log(t + timedelta(minutes=30, seconds=9), "Starting the server (this waits until the world is up, up to 25 minutes)...")
    log(t + timedelta(minutes=30, seconds=20), "Applied enchant fix 000-reset.sql to synthetic_world.")
    log(t + timedelta(minutes=33, seconds=2), "Server is up on core 000000000000.")
    log(t + timedelta(minutes=33, seconds=2), "Settings: the server runs 41 setting(s) on defaults (none set in a config file) "
        "and could not use 0. Full list in server-settings\\settings-report.txt.")
    log(t + timedelta(minutes=33, seconds=3), "Performance counters: every 5 seconds to C:\\SYNTHETIC\\Core\\Logs\\perf\\perf-2026-11-20_0403.csv.")
    log(t + timedelta(minutes=33, seconds=5), "Downtime: 118 s from the stop until the world was up (to within 15 s).")
    log(t + timedelta(minutes=33, seconds=5), "Patch night OK: patched server unchanged, settings checked, server up on core 000000000000.", "OK")
    log(t + timedelta(minutes=33, seconds=5), "---- patch night finished ----")

    # 3. Start-Server.cmd
    t = datetime(2026, 11, 20, 19, 15, 0)
    log(t, "---- start server (Start-Server.cmd) ----")
    log(t, "Applying server-settings...")
    log(t + timedelta(minutes=4), "Server is up on core 000000000000.")
    log(t + timedelta(minutes=4), "Server started on core 000000000000 with your settings.", "OK")
    log(t + timedelta(minutes=4), "---- patch night finished ----")

    # 4. a long downtime, then a run that was cut off
    t = datetime(2026, 11, 21, 3, 30, 1)
    log(t, "---- patch night started ----")
    log(t + timedelta(seconds=3), "No players online.")
    log(t + timedelta(minutes=37), "Server is up on core 000000000000.")
    log(t + timedelta(minutes=37), "Downtime: 402 s from the stop until the world was up (to within 15 s).")
    log(t + timedelta(minutes=37), "Patch night OK: installed wcme-server-0.000000.000-build3, settings checked, server up on core 000000000000.", "OK")
    log(t + timedelta(minutes=37), "---- patch night finished ----")
    t = datetime(2026, 11, 22, 3, 30, 1)
    log(t, "---- patch night started ----")
    log(t + timedelta(seconds=2), "Cannot reach GitHub releases: SYNTHETIC timeout", "WARN")
    (HERE / "SYNTHETIC-patch-night.log").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\r\n")


def errors():
    out = []
    for i in range(40):
        out.append(f"SYNTHETIC: creature (Entry: {random.randint(1, 40000)} GUID: {random.randint(1, 900000)}) "
                   f"has no path {random.randint(1, 99)}")
    for i in range(7):
        out.append(f"SYNTHETIC: spell {random.randint(1, 80000)} listed for player 'Bot{random.randint(1, 500)}' does not exist")
    out.append("")
    out.append("SYNTHETIC: a line seen once")
    for i in range(3):
        out.append(f"2026-11-21 0{i}:15:00 ERROR SYNTHETIC: with a timestamp, value 0x{random.randint(1, 65535):04X}")
    random.shuffle(out)
    (HERE / "SYNTHETIC-Errors.log").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\r\n")


if __name__ == "__main__":
    argparse.ArgumentParser(
        description=__doc__ + "\nTakes no options. Writes the SYNTHETIC-* files next to itself (overwriting them) "
        "and lists them. Run from any folder.\nExit codes: 0 written; 2 bad arguments.",
        formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    timing()
    counters()
    slow_queries()
    patch_night()
    errors()
    for path in sorted(HERE.glob("SYNTHETIC-*")):
        print(f"{path.name}  {path.stat().st_size} bytes")
