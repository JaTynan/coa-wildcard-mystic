# Diagnostic file formats: exact shapes and where each comes from

Read this when a parser stops matching, when you write a new parser, or when you need to know what one number in
a log really means. Every shape below was checked two ways on 2026-11-22: against the code that writes it, and
against a copy of the real file taken from the server that afternoon (except where marked).

Sources used: this repository; the pinned CoA core `Corfirean/azerothcore-wotlk-coa` at `c3f2fd4b2395` (release
`server-0.261119.114`); SQUID's playerbots `Zyth45/mod-playerbots` at `4ef5ed9e` (tag v3.0); the manager
`Corfirean/coa-server-manager` at `10cfdcf5` (20 Nov 2026). Paths such as `src/server/...` are in the core.

All server paths are under `C:\Games\CoA Server`.

## 1. `Core\Logs\Timing.log`

**Writer:** the world server itself. Nothing in `patches/` touches it: it is a stock AzerothCore feature switched
on by four settings (`server-settings/server-settings.txt`, section "Performance diagnosis (21 Nov)"):

```
worldserver.conf | RecordUpdateTimeDiffInterval = 60000     # one record a minute (core default 300000 = 5 min)
worldserver.conf | MinRecordUpdateTimeDiff = 0              # record every time (core default 100: only above 100 ms)
worldserver.conf | Appender.Timing = 2,4,1,Timing.log,a     # type 2 file, level 4 Info, flag 1 timestamp prefix, a = append
worldserver.conf | Logger.time.update = 4,Console Server Timing
```

The appender fields are `Type,LogLevel,Flags,File,Mode` (`worldserver.conf.dist`, "Appender config values").

**Code:** `WorldUpdateTime::RecordUpdateTime` in `src/server/game/Time/UpdateTime.cpp`, called once per pass from
`World::Update` (`src/server/game/World/World.cpp`). It writes five log calls in a row.

**Shape (real file, 22 Nov 2026):**

```
2026-11-22 08:57:00 Update time diff: 48ms with 0 players online
2026-11-22 08:57:00 Last 500 diffs summary:
2026-11-22 08:57:00 |- Mean: 7ms
2026-11-22 08:57:00 |- Median: 2ms
2026-11-22 08:57:00 |- Percentiles (95, 99, max): 15ms, 31ms, 290ms
```

CRLF line ends, plain ASCII. The timestamp is the server's local time (`%Y-%m-%d %X`, `LogMessage::getTimeStr`).

| Number | What it is (from the code) |
|---|---|
| `Update time diff: Nms` | The most recent pass only: `GetLastUpdateTime()`. One sample, not an average. |
| `with N players online` | `sWorldSessionMgr->GetActiveSessionCount()`: sessions not waiting in the login queue. On the real file it read 0 or 1 all day with about 750 bots in the world, so **bots are not counted**. |
| `Last N diffs` | How many passes the summary covers: `GetDatasetSize()`. The table holds 500 (`AVG_DIFF_COUNT` in `UpdateTime.h`); N is smaller only just after a start (the first record of a start reads `Last 1`). |
| `Mean` | Average of those N passes (integer division). |
| `Median` | 50th percentile of those N passes. |
| `Percentiles (95, 99, max)` | 95th, 99th and 100th percentile of those N passes, linear interpolation. |

What a "diff" is: `WorldUpdateLoop` in `src/server/apps/worldserver/Main.cpp` measures the wall-clock time from
the start of one pass to the start of the next and hands it to `World::Update`. So it includes everything the
main thread did in that pass (sessions, maps, bots, database callbacks) plus any sleep. With nothing to do the
loop sleeps to `MinWorldUpdateTime` (default 1 ms), which is why an idle server "spins" at a few ms per pass.

**Three traps, all seen on the real file:**

1. **The five lines can arrive out of order.** Logging runs on its own thread since `Log.Async.Enable = 1`
   (commit f9dc45a). In the 22 Nov file 101 of 458 records had lines shuffled, for example `Last 500 diffs`
   before `Update time diff`, or `Median` after `Percentiles`. Group lines by timestamp and kind, never by position.
2. **A record covers the last 500 passes, not the last minute.** 500 passes x the mean is the time covered:
   about 2 s on an empty server (4 ms mean; the bots are logged out when nobody is on), about 25 s with a player
   on (50 ms mean). The rest of the minute is not
   in the file. `timing_summary.py` prints this as "covered".
3. **The first record after a start comes straight away** (the "last record" clock starts at zero and the game
   clock counts from process start, so more than a minute has always passed by the first pass). It says `Last 1`.

**Growth:** appended for ever, nothing rotates it. The settings comment estimates "about 100 KB a day"; the real
file grew 114 KB in 7 h 37 min, which is about 360 KB a day (1,440 records of roughly 250 bytes).

The same five lines also go to the console and `Server.log` (the logger names three appenders), there **without**
timestamps, because those appenders have flag 0.

## 2. `Core\Logs\perf\perf-<yyyy-MM-dd_HHmm>.csv` and `counters.txt`

**Writer:** Windows' own `typeperf.exe`, started by `StartDiagnostics` in `patch-night/PatchNight.ps1` once
`StartAndCheck` has seen the world come up. Arguments: `-cf counters.txt -si 5 -f CSV -o <file> -y`.
One file per server start, named with the start time; files older than 14 days (by last write) are deleted the
next time `StartDiagnostics` runs. The previous start's `typeperf` is stopped first.

`counters.txt` (rewritten at each start) lists what is asked for:

```
\Processor(*)\% Processor Time            \PhysicalDisk(_Total)\Avg. Disk sec/Read
\System\Processor Queue Length            \PhysicalDisk(_Total)\Avg. Disk sec/Write
\System\Context Switches/sec              \PhysicalDisk(_Total)\Current Disk Queue Length
\Memory\Available MBytes                  \PhysicalDisk(_Total)\% Idle Time
\Memory\Pages/sec                         \Process(worldserver)\% Processor Time | Working Set | Thread Count
\Paging File(_Total)\% Usage              \Process(mysqld)\% Processor Time | Working Set
```

**Shape (real file, 22 Nov 2026):** typeperf's "PDH-CSV 4.0" layout, every cell quoted, plain ASCII.

```
"(PDH-CSV 4.0) (AUS Eastern Daylight Time)(-660)","\\<MACHINE>\Processor(0)\% Processor Time", ... 25 counters
"11/22/2026 09:03:19.561"," "," ", ... ,"0"," ","5128"," ","2.4549560546875", ...
"11/22/2026 09:03:24.586","39.231951702677079652","31.752807296852726182", ...
```

- `<MACHINE>` stands for the VM's Windows computer name (left out here on purpose).
- Column 1 is local time as `MM/dd/yyyy HH:mm:ss.fff`. The header names the time zone and its offset in minutes.
- `\Processor(*)` expands to one column per logical processor plus `_Total`. The real file has `Processor(0)` to
  `Processor(9)`: **10 logical processors** (`docs/performance.md` says 8 vCPUs; the settings file notes "the VM
  at 10 cores" from 8 Nov).
- A cell that could not be sampled is `" "` (a quoted space). The **first row** has blanks for every rate counter
  (18 of 25 cells), because a rate needs two samples.
- Rows are about 5 s apart (the real file: 5,379 rows in 7 h 30 min).

**Units (Windows' definitions):**

| Counter | Unit and reading |
|---|---|
| `Processor(n)\% Processor Time` | 0-100 for that logical processor. |
| `Process(x)\% Processor Time` | 100 = one full logical processor. A world server using two and a half cores reads 250. Not capped at 100. |
| `System\Processor Queue Length` | Threads ready to run but waiting for a processor, all processors together. |
| `Memory\Available MBytes` | Free memory in MB. |
| `Memory\Pages/sec` | Pages read from or written to disk to resolve hard page faults. Spiky by nature. |
| `PhysicalDisk\Avg. Disk sec/Read`, `sec/Write` | **Seconds** per operation (0.00014 = 0.14 ms). |
| `PhysicalDisk\% Idle Time` | 100 = disk doing nothing. Can read slightly over 100. |
| `Process(x)\Working Set` | **Bytes** of physical memory the process holds. The script shows it divided by 1024^3. |

**Limits:** a row every 5 s cannot show which thread was busy during a 3-second stall, only that some logical
processor was. `\Process(worldserver)` is the first process of that name only; a second world server (another
realm started alongside) would be `worldserver#1` and is not recorded. Two starts within the same minute would
write the same file name (`-y` overwrites). About 8.5 MB a day at the real file's rate.

## 3. `Core\Logs\mysql-slow.log`

**Writer:** MySQL, switched on by `sql/enchants/095-slow-query-log.sql` (run as database administrator at every
start by `ApplyEnchantFixes`): `slow_query_log = ON`, `long_query_time = 0.5`, file
`C:/Games/CoA Server/Core/Logs/mysql-slow.log`, all with `SET PERSIST` so they survive the manager rewriting
`my.ini`. To stop it: `SET PERSIST slow_query_log = OFF;` (a behaviour change: classify first).

**Shape (real file, 22 Nov 2026; MySQL 8.4.9, port 3307):**

```
C:\Games\CoA Server\mysql\bin\mysqld.exe, Version: 8.4.9 (MySQL Community Server - GPL). started with:
TCP Port: 3307, Named Pipe: MySQL
Time                 Id Command    Argument
# Time: 2026-11-21T21:54:13.910561Z
# User@Host: acore[acore] @ localhost [127.0.0.1]  Id:   132
# Query_time: 0.729223  Lock_time: 0.000007 Rows_sent: 22151  Rows_examined: 22151
use acore_world_wildcard;
SET timestamp=1795298053;
SELECT * FROM `spell_dbc` ORDER BY `ID` DESC;
```

- The three header lines repeat each time MySQL starts.
- `# Time:` is **UTC** (the trailing `Z`). Sydney daylight time is UTC+11, so 21:54 UTC on the 21st is 08:54 on
  the 22nd. Every other log here is local time. `slow_query_summary.py --utc-offset-hours 11` converts.
- `use <database>;` appears only when the connection's database changed since its last entry.
- `User` tells you who ran it: `acore` is the world server; `root` is patch night's own helper queries (they use
  the administrator client file).
- Query text can run to thousands of characters on one line (the longest real line: 4,031).
- No rotation. Lines are written only for queries over 0.5 s, so a quiet day adds nothing.

## 4. `Core\Logs\console-history.txt`

**Writer:** `SaveConsoleHistory` in `patch-night/PatchNight.ps1`, **once**: only if the file does not exist yet.
It reads the manager's `world-console.log` (every console line since the realm began, gigabytes) and keeps the
lines that contain `AzerothCore rev.`, `Update time diff` or `World Initialized`, each prefixed with its line
number in the console log and `: `. Purpose (the function's comment): compare update times before and after the
19 Nov core update.

**Shape (real file, 22 Nov 2026: 2,522 lines):**

```
3: AzerothCore rev. 9c31f851ee9c 2026-10-21 22:48:45 +0500 (HEAD branch) (Win64, RelWithDebInfo, Static) (worldserver-daemon)
28085: WORLD: World Initialized In 3 Minutes 40 Seconds
28087: AzerothCore rev. 9c31f851ee9c 2026-10-21 22:48:45 +0500 (HEAD branch) (Win64, RelWithDebInfo, Static) (worldserver-daemon) ready...
191110: Update time diff: 504ms with 0 players online
```

**How to read it, and how not to:**

- **No timestamps.** Order and core revision are all you have. The banner appears twice per start (at launch and
  with `ready...`). A `+` after the revision marks a build with local changes: our patched server.
- Only the **first** of the five timing lines matched the filter, so there are no means or percentiles: just the
  single-pass "diff".
- Until 21 Nov the server wrote that line only when the pass took **over 100 ms**, and checked at most every
  5 minutes (the core defaults). So the history is a list of slow passes caught by a 5-minute sampler. Its median
  is not a typical pass. Compare how many slow passes a revision has and how large they are, nothing finer.
- Eight real lines carry absurd values (the largest 83,052,825 ms, about 23 hours). Cause not established
  (UNVERIFIED: the first pass after the VM was paused, or a clock change, would do it). Use
  `timing_summary.py --ignore-above-ms 60000` and say that you did.
- Revisions in the real file, in order: `9c31f851ee9c`, `90ec1e0a2e58`, `a76415e00eba` (official, then `+`),
  `85ecc2122efd+`, `c3f2fd4b2395` (official, then `+`).

**Never delete `console-history.txt`.** It is written once from the old console log, which `RotateConsoleLogs`
then removes; from then on `world-console.log` holds one run, so the file cannot be rebuilt. It is the only
before/after record across core updates (five revisions back to October). Before any work on it, copy it aside
and work on the copy; do not delete, move or edit the original. If a newer extract is wanted, that means writing
a separate file from the dated `world-console-*.log` files: a change to patch night (hard stop 5, James).

## 5. `patch-night\patch-night.log` and `last-run.txt`

**Writer:** function `Log` in `patch-night/PatchNight.ps1`:
`'{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $level, $message`, appended with `Add-Content`.
Levels: `INFO`, `OK`, `WARN`, `FAIL`. **Not re-verified against the real file on 2026-11-22: it was not in the
copied folder.**

```
2026-11-22 04:02:41 [INFO] Server is up on core c3f2fd4b2395.          (shape from the code; values illustrative)
```

Literal marker lines in the script:

| Line | Written when |
|---|---|
| `---- patch night started ----` | Weekly patch night, nightly restart, or `Run-PatchNight-Now.cmd`. |
| `---- start server (Start-Server.cmd) ----` | `-StartOnly`. |
| `---- rebuild Wildcard bots (Rebuild-WildcardBots.cmd) ----` | `-RebuildWildcardBots`. |
| `---- patch night finished ----` | Every exit through `Finish`, all three kinds. The line before it is the outcome, at level `OK` (exit code 0) or `FAIL`. |

Lines worth parsing (text from the script):

| Line starts with | Meaning |
|---|---|
| `Downtime: N s from the stop until the world was up (to within 15 s).` | Measured downtime. Only on a successful ordinary run. Added 22 Nov 2026 (commit 759c7b6). |
| `Prepared in N s, with the server up.` | Download, unpack and settings, done during the countdown. |
| `Players online: N. Counting down M minutes while preparing.` / `No players online.` | From `server info` before the restart. |
| `Server is up on core <rev>.` | `StartAndCheck` succeeded. |
| `Settings: the server runs N setting(s) on defaults ... and could not use M` | `ReportConfigWarnings`; level `WARN` when M > 0. |
| `Performance counters: every 5 seconds to <path>.` | `StartDiagnostics` started typeperf. |
| `Installing <tag>...` then outcome `Patch night OK: installed <tag>, ...` | A new build went in. |
| `Putting the official world server back...` | The patched server did not come up: fallback. |
| `Applied enchant fix <file> to <db>.` / `Enchant fix <file> failed: ...` | One per SQL file. |

Before its opening line a run may log a few lines while it downloads the repository, and
`Running the newer patch-night script just downloaded...` when it restarts itself. A helper script's output is
logged indented by two spaces. A message can span several lines; the later lines have no timestamp.

`last-run.txt` is one line, overwritten each run: `yyyy-MM-dd HH:mm  <outcome>`.

## 6. `server-settings\settings-report.txt`

**Writers:** `server-settings/Apply-ServerSettings.ps1` rewrites the file on every apply (which settings the
server knows, which are unknown, which options the `.dist` files list that ours do not set), then
`ReportConfigWarnings` in `PatchNight.ps1` appends the server's own start-up warnings. Lines to look for (text
from the scripts):

```
Known to the server: N (M of them read by our patched server only, not in the official .dist).
Unknown, in neither the .dist nor the server program (renamed or removed by an update? the server ignores these): N.
The world server's own warnings at this start (yyyy-MM-dd HH:mm):
Settings it uses but no config file sets, so it runs on its default (N):
Values it could not use (N):
```

Not re-verified against the real file on 2026-11-22 (not in the copied folder). Home for interpreting it:
`wildcard-settings-and-flags`.

## 7. `Core\Logs\Server.log`, `Errors.log`, console logs, `Auth.log`

From the core's default config at the pinned revision (`worldserver.conf.dist`, `authserver.conf.dist`); the live
config was not read on 2026-11-22, but the real files fit these defaults:

| File | Default appender | So it is |
|---|---|---|
| `Server.log` | `Appender.Server=2,5,0,Server.log,w` | This start only (overwritten at start), no timestamps, level Debug and up. Line 1 is the banner with the core revision; `World Initialized In` marks the world being up (`StartAndCheck` relies on both). 21 MB on 22 Nov. |
| `Errors.log` | `Appender.Errors=2,2,0,Errors.log,w` | This start only, no timestamps, errors only. Real copy: 38,273 lines, 3.8 MB, 223 kinds of line, nearly all written while the world loads. |
| `Auth.log` | `Appender.Auth=2,5,0,Auth.log,w` | The login server's log, this start only. |
| `world-console.log`, `auth-console.log` | written by the manager, not the server | Everything the console printed, appended for ever: 2.99 GB and 32 MB on 22 Nov. `RotateConsoleLogs` (commit 759c7b6, 22 Nov) clears them once, then renames each run's file with the date and keeps the newest 3. On the afternoon of 22 Nov the 2.99 GB file was still there. Not established why: check `patch-night.log` for a `Cleared world-console.log` line and whether `patch-night\console-logs-cleared.txt` exists. |

`docs/agents/context/patch-night.md` describes `Errors.log` as "errors since the realm began". The real file
holds one start. Treat it as this start only.

## 8. Other files seen in `Core\Logs` on 22 Nov 2026

| File | What it is | Writer |
|---|---|---|
| `squidbot\runs.jsonl` | One JSON object per Dungeon Clear run: `runId` (local time in the id), `dungeon`, `dungeonName`, `difficulty`, `instance`, `startedAtMs`, `endedAtMs` (epoch ms), `durationS`, `result` (`clear` / `aborted` seen), `bossesKilled`, `bossesTotal`, `bossTimeline`, `wipes`, `comp`, `players`. 15 lines on 22 Nov. Useful as a timeline of what a player was doing. | mod-dungeon-clear (`DcRealRunLog.cpp`); turned over to `runs.jsonl.1`. |
| `squidbot\events.jsonl` | World events for a dashboard (invasions, gold rushes, server firsts), 1 MB. Not copied, not parsed here. | SQUID playerbots (`CoaWorldEvents.cpp`), folder set by `AiPlayerbot.CoaDataDir` (default `<LogsDir>/squidbot`), turned over at 5 MB. |
| `coa_bot_fleet_N.log` (21 files) | Empty on 22 Nov. | Not traced (UNVERIFIED). |
| `supervisor.log` | Empty on 22 Nov. | The manager knows the path (`services.rs`); what writes to it was not traced. |

## 9. `Core\Crashes\`

`docs/agents/context/patch-night.md`: one `.txt` and one `.dmp` per crash, named with the core revision and the
date. The folder name `Crashes` is in the core (`src/common/Debugging/WheatyExceptionReport.cpp`). Not seen on
2026-11-22 (outside the copied folder). Home for reading a crash: `wildcard-debugging-playbook`.
