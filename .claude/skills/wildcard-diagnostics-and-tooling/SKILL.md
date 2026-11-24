---
name: wildcard-diagnostics-and-tooling
description: How to MEASURE the Wildcard server instead of eyeballing it. Inventory of every diagnostic file on the VM (Timing.log, Logs/perf Windows counter CSVs, mysql-slow.log, console-history.txt, patch-night.log, settings-report.txt, Server.log, Errors.log, console logs, squidbot run logs), exact line formats, what each number means, and how the manager's World speed panel relates to Timing.log. Ships tested Python parsers (timing_summary, perf_csv_summary, slow_query_summary, patch_night_summary, errors_log_groups) and a reference run on the logs of 22 Nov 2026. Load when asked "how laggy is it, in numbers", "compare before and after", "what does this log line mean", "summarise last night's patch-night log", "which queries are slow", to record numbers in docs/performance.md, or to propose a new instrument. This skill reads and measures only. For WHY the server lags or what to try next, load wildcard-lag-spike-campaign first; for a fault that is not slowness, wildcard-debugging-playbook.
---

# Wildcard diagnostics and tooling

Use this skill to turn "it feels laggy" into numbers, and to compare two numbers honestly.

Status words used here: DOCTRINE (written in README, CHANGES.md or docs on `main`, including `docs/agents/` since PR #232 merged on 22 Nov 2026), PRACTICE, NOT BUILT YET, Proposed practice (not yet adopted by James), UNVERIFIED, OPEN.
`docs/agents/*` (hard stops, "healthy or wrong" for patch night) is cited below; it came with PR #232, merged on 22 Nov 2026 (`0802d4f`), and is on `main`: what rests on it is **DOCTRINE**.

Terms used here, defined once:
- **Pass** (the repo also says "tick" or "update"): one trip round the world server's main loop. Its length in
  milliseconds is the **update time** or **diff**.
- **Window**: the last 500 passes, the only history the server keeps of its own speed.
- **p95 / p99**: the value 95% / 99% of passes were faster than. The manager calls p95 "95% under".
- **Spike**: one pass far longer than the rest. Players feel spikes, not averages.
- **VM**: the Windows 11 machine the server runs on. Server folder `C:\Games\CoA Server`.
- Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## 1. Start here (five minutes)

**Where the logs are.** On the game VM, in `Core\Logs` under the server folder: `C:\Games\CoA Server\Core\Logs`
(the folder a chat session linked to the VM connects to). `patch-night.log` and `settings-report.txt` are in
`patch-night\` and `server-settings\` under the same server folder (section 4 lists every file).

**Where the scripts run.** They need Python 3.8 or newer and nothing else. Pick one of two ways:

- **A. On the VM, against the live files** (read-only, safe while the server runs). Python is the manager's own:
  `"C:\Games\CoA Server\Runtime\python\python.exe"`. The skill folder must be on the VM first:
  - once this skill is merged to `main`, patch night's download of `main` holds it, under
    `C:\Games\CoA Server\patch-night\work\repo\` in the one folder that is there (its name is UNVERIFIED on the
    VM: `dir "C:\Games\CoA Server\patch-night\work\repo"`); then `.claude\skills\wildcard-diagnostics-and-tooling\scripts`;
  - until then (the skills are not on `main` as of 2026-11-22), copy this skill's `scripts` folder to any folder
    on the VM outside the server folder, for example `C:\Temp\wildcard-diag\scripts`. Copying a read-only tool
    changes nothing the server uses.
- **B. From a session that has the logs staged** (a copy of `Core\Logs` attached to the session, or copied to
  another machine: section 3). Run from the repository root with `python3 -I -B` and give the path of the copy.

1. Get the shape of the day. On the VM (way A), with `SCRIPTS` standing for the scripts folder:
   ```
   cd /d "SCRIPTS"
   "C:\Games\CoA Server\Runtime\python\python.exe" -I -B timing_summary.py "C:\Games\CoA Server\Core\Logs\Timing.log"
   ```
   On staged copies (way B), with `LOGS` standing for the folder of the copy:
   ```
   python3 -I -B .claude/skills/wildcard-diagnostics-and-tooling/scripts/timing_summary.py LOGS/Timing.log
   ```
2. If there are spikes, ask what moved with them (way A shown; way B is the same two scripts with `LOGS/...`):
   ```
   "C:\Games\CoA Server\Runtime\python\python.exe" -I -B perf_csv_summary.py "C:\Games\CoA Server\Core\Logs\perf" --timing "C:\Games\CoA Server\Core\Logs\Timing.log" --spike-ms 1000 --min-players 1 --detail 3
   "C:\Games\CoA Server\Runtime\python\python.exe" -I -B slow_query_summary.py "C:\Games\CoA Server\Core\Logs\mysql-slow.log" --utc-offset-hours 11 --by-hour
   ```
3. Compare what you see with `references/reference-run-2026-11-22.md` (the same commands on a known day).
4. For what the numbers mean for the lag spikes and what to try next: `wildcard-lag-spike-campaign`.
5. Before you change anything to "fix" what you found, go to section 9 (measuring discipline). Any change to how
   the server behaves: **classify with wildcard-change-control first**; James merges.

These scripts only read. Nothing in this skill changes the server. Way A was written from the scripts and paths
in the repository and has not been executed on the VM as of 2026-11-22; way B is how every script was tested.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Work the lag spikes step by step (hypotheses, gates, what to try next) | `wildcard-lag-spike-campaign` |
| Design an experiment, judge evidence, or decide whether a result is real | `wildcard-analysis-and-method` |
| The lag pass/fail numbers (the proposed exit metric) | `wildcard-lag-spike-campaign`, Phase 1 step 5 (its single home) |
| Decide what else counts as "good enough", or add a check or test | `wildcard-validation-and-qa` |
| Go from a symptom ("server will not start", "patch night failed") to a cause | `wildcard-debugging-playbook` |
| Know what was already tried and what it showed | `wildcard-failure-archaeology` |
| Run, stop, restart or roll back anything; what patch night does step by step | `wildcard-run-and-operate` |
| Change a setting, including the diagnostic ones | `wildcard-settings-and-flags`, after `wildcard-change-control` |
| Understand the world loop, map threads or bots in the core | `azerothcore-coa-reference` |
| Fix or test a Mystic Enchant | `ascension-restoration` |
| Record results in a doc or PR | `wildcard-docs-and-publishing` |

## 2. The scripts

All in `scripts/`. Python 3.8+, standard library only, `pathlib` paths (Windows and Linux). Each has `--help`
with examples, runs from any folder, and leaves no `__pycache__` behind. Each prints how many lines it could not use, so a format change shows up as a count, not a crash.

| Script | Reads | Gives you | Tested on (2026-11-22) |
|---|---|---|---|
| `timing_summary.py` | `Timing.log`; also `Server.log`, console logs, `console-history.txt` | Per-start and per-hour table (p50/p95/p99/max of the chosen per-minute figure), spike list and episodes, before/after a moment (`--split`), per core revision when the file has start banners | Real `Timing.log` and `console-history.txt` + synthetic |
| `perf_csv_summary.py` | `Logs\perf\perf-*.csv` (a file or the folder) | Per-core CPU and how often one core is pinned while the rest idle; queue, paging, disk latency, worldserver vs mysqld CPU and memory. With `--timing`: which counters moved in spike minutes | Real perf CSV + `Timing.log` + synthetic. The spike table shows worldserver CPU twice: highest and **lowest** in each window (a long pass shows as the lowest falling) |
| `slow_query_summary.py` | `mysql-slow.log` | Queries grouped by shape: count, total/avg/max time, lock time, rows read; `--by-hour`, `--by-minute` | Real `mysql-slow.log` + synthetic |
| `patch_night_summary.py` | `patch-night.log` | One row per run: outcome, downtime, build installed, WARN count, flags (fell back, long downtime, cut off) | **Synthetic only**: the real file was not available. Check the first real run by eye |
| `errors_log_groups.py` | `Errors.log` (any plain log) | Lines grouped by kind and counted; `--baseline` marks kinds that are new | Real `Errors.log` + synthetic |
| `selftest.py` | `samples\SYNTHETIC-*` | 45 checks that every script still finds what was planted in the samples | Linux, Python 3.13: all passed. Not yet run on Windows |

`scripts/samples/` holds small files named `SYNTHETIC-...`, written by `make_synthetic_samples.py`. **Every number
in them is invented.** They exist so the scripts can be tested without the server. Never quote one as a measurement.

After editing a script, or once on the VM to prove its Python runs them:
```
"C:\Games\CoA Server\Runtime\python\python.exe" selftest.py
```
Expect `ALL CHECKS PASSED`.

Flags you will use most:

| Want | Flag |
|---|---|
| Only hours when someone was on | `timing_summary.py ... --min-players 1` |
| A time range | `--from "2026-11-22 19:00" --to "2026-11-22 23:00"` (all scripts) |
| Skip the minutes while bots log in after a start | `timing_summary.py ... --skip-warmup-minutes 20` |
| Before and after a restart that applied a change | `timing_summary.py ... --split "2026-11-23 04:00" --window-hours 20 --min-players 1` |
| Only multi-second spikes | `--spike-ms 1000` (default 100, the "laggy" figure in `docs/performance.md`) |
| MySQL times in local time | `slow_query_summary.py ... --utc-offset-hours 11` (10 outside daylight saving) |
| Last two weeks of restarts | `patch_night_summary.py ... --last 14` |

## 3. Where the files are, and getting them

The files live on the VM. Sessions with VM access read them in place.

**Python on the VM.** The repo already depends on the manager's bundled Python at
`C:\Games\CoA Server\Runtime\python\python.exe`: `PatchNight.ps1` runs `launcher_bridge.py` with it (`$python`,
near the top of the script) and the sign-up service is registered with it
(`signup/Register-WildcardSignup.ps1`, which stops with "No manager Python" if it is missing). Use that
interpreter. Its version was not read on 2026-11-22 (UNVERIFIED); the scripts avoid anything newer than 3.8, and
`selftest.py` settles it in ten seconds.

**Copying off the VM** (when you would rather analyse elsewhere): copy, never move, and leave these behind
because of size: `world-console.log` (2.99 GB on 22 Nov), `auth-console.log` (32 MB), `Server.log` (21 MB).
The useful set is small: `Timing.log`, `perf\*.csv`, `mysql-slow.log`, `console-history.txt`, `Errors.log`,
`squidbot\runs.jsonl`, plus `patch-night\patch-night.log`, `patch-night\last-run.txt` and
`server-settings\settings-report.txt`. Files being written can be copied; the last record may be cut off (the
scripts count it and carry on).

**Do not commit real logs to the repository.** It is public; logs carry character names, account-level detail
and the machine name. Short excerpts to show a format are fine.

## 4. Inventory of diagnostic sources

Paths are under `C:\Games\CoA Server`. "Cost" is the cost of leaving it on. Exact line shapes, the code that
writes each, and traps: `references/formats.md` (read this when a parser stops matching or you need to know what
one number means). Sizes are from the copy of 22 Nov 2026.

| Source | Measures | Format | Kept | Written by | Since | Cost |
|---|---|---|---|---|---|---|
| `Core\Logs\Timing.log` | Pass time: one 5-line record a minute summarising the last 500 passes, with real players online | Timestamped text, 5 lines per record, **lines may be out of order** | For ever (appended, nothing rotates it) | The world server (stock feature; 4 settings in `server-settings.txt`) | 9ba9f45, PR #225, 21 Nov 2026 | About 360 KB a day measured (the settings comment says about 100 KB) |
| `Core\Logs\perf\perf-<date>_<HHmm>.csv` | Windows counters every 5 s: per-core CPU, processor queue, context switches, memory, paging, disk latency/queue/idle, worldserver and mysqld CPU and memory | typeperf "PDH-CSV 4.0", quoted cells, blank = `" "` | 14 days; one file per server start | `typeperf.exe`, started by `StartDiagnostics` in `PatchNight.ps1` | 9ba9f45 | About 8.5 MB a day; one small background process |
| `Core\Logs\perf\counters.txt` | The counter list given to typeperf | One counter path per line | Rewritten each start | `StartDiagnostics` | 9ba9f45 | None |
| `Core\Logs\mysql-slow.log` | Every SQL statement slower than 0.5 s: time taken, lock wait, rows read and sent | MySQL slow log; **times in UTC** | For ever | MySQL, via `sql/enchants/095-slow-query-log.sql` | 9ba9f45 | Nothing on a quiet day (33 entries on 22 Nov) |
| `Core\Logs\console-history.txt` | Start banners, "World Initialized" and slow-pass lines pulled from the old console log | `<console line number>: <line>`; no timestamps | Written once, never updated. **Never delete it: it cannot be rebuilt** (copy it aside before working on it) | `SaveConsoleHistory` in `PatchNight.ps1` | 9ba9f45 (function split out in 759c7b6) | None (165 KB) |
| `patch-night\patch-night.log` | Every patch-night, nightly-restart and start-server run: steps, warnings, outcome, downtime | `yyyy-MM-dd HH:mm:ss [LEVEL] message` | For ever | `Log` in `PatchNight.ps1` | From the first patch night; `Downtime:` line from 759c7b6 (22 Nov) | Small |
| `patch-night\last-run.txt` | Outcome of the latest run | One line | Overwritten | `Finish` in `PatchNight.ps1` | as above | None |
| `server-settings\settings-report.txt` | Which settings the server knows, unknown ones, options left on defaults, the server's own "Missing property" / "Bad value" warnings | Text sections | Rewritten each apply, then appended at start | `Apply-ServerSettings.ps1`, then `ReportConfigWarnings` | ba59783 (22 Nov) for the knows/unknown check | None |
| `Core\Logs\Server.log` | Everything the world server logs, this start only; line 1 = core revision; also the timing lines without timestamps | Plain text, no timestamps | Overwritten at each start | The world server | Stock | 21 MB a start |
| `Core\Logs\Errors.log` | Errors, this start only (mostly data checks while the world loads) | Plain text, no timestamps | Overwritten at each start | The world server | Stock | 3.8 MB a start |
| `Core\Logs\world-console.log`, `auth-console.log` | The console windows' full output | Plain text | Appended for ever until `RotateConsoleLogs` (759c7b6): cleared once, then dated per run, newest 3 kept | The manager | Manager | **High if chatty**: 2.9 GB by 20 Nov; commit f9dc45a gives "writing it slowed the world" as its reason. The logging change shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run yet; status OPEN |
| `Core\Logs\Auth.log` | The login server's log, this start | Plain text | Overwritten at each start | The auth server | Stock | Small |
| `Core\Logs\squidbot\runs.jsonl` | One line per Dungeon Clear run: dungeon, start/end, result, bosses, group | JSON lines | Turned over to `.1` | mod-dungeon-clear | Module | Small |
| `Core\Logs\squidbot\events.jsonl` | World events for a dashboard (not performance) | JSON lines | Turned over at 5 MB | SQUID playerbots | Module | Small |
| `Core\Crashes\` | One `.txt` + `.dmp` per crash | Text + dump | For ever | The world server | Stock | Only on a crash |
| `patch-night\signup.log` | Accounts created, refusals, bug-report issue numbers (never passwords) | Text | For ever | `signup/WildcardSignup.py` (`log_file`) | see `signup/README.md` | Small |
| `patch-night\work\callN.in` / `.out` / `.err` | What patch night fed to, and got back from, each helper it ran (MySQL client, manager launcher): N counts up within a run. The place to look when a `[WARN]` line quotes only part of an error | Raw text | Overwritten by the next run's call of the same number | `Invoke-Quiet` in `PatchNight.ps1` | From early patch night | Small |
| `launcher.log` (on each **player's** PC, next to the launcher) | Every step and error of the friends' launcher: not a server file | Text | On the player's machine | `launcher/WildcardLauncher.py` (`LOG_FILE`) and `WildcardLauncher.ps1` | Launcher | None on the server. Home: `wildcard-client-and-web` |
| Manager "World speed" panel | Live pass time (section 5) | On screen | Not stored | The manager, from `server info` | Manager | None |
| Status board / `/api/status` | Live: servers up on their ports, players, characters in world (bots included), uptime, build, last run, last downtime | Console window / JSON | Not stored | `signup/WildcardStatus.py`; board in `signup/WildcardConsole.py` | Board: PR #231, 22 Nov (on `main`) | One `server info` a minute |

Empty on 22 Nov and not traced to a writer: `Core\Logs\coa_bot_fleet_N.log` (21 files), `Core\Logs\supervisor.log`.

Not diagnostics but they shape what you measure: `sql/enchants/090-mysql-tuning.sql` (4 GB buffer pool,
`performance_schema` off) and `EnsureCharacterSpellIndexes` in `PatchNight.ps1` (the index that took the
character list from 40 s to instant). Home for both: `wildcard-run-and-operate`.

## 5. Reading pass times: Timing.log and the World speed panel

A record, as written (`references/formats.md` section 1 has the source for each number):
```
2026-11-22 14:49:03 Update time diff: 59ms with 1 players online      <- the latest single pass; real players only
2026-11-22 14:49:03 Last 500 diffs summary:                           <- everything below covers these 500 passes
2026-11-22 14:49:03 |- Mean: 54ms
2026-11-22 14:49:03 |- Median: 29ms
2026-11-22 14:49:03 |- Percentiles (95, 99, max): 89ms, 169ms, 5397ms
```

**The manager's World speed panel shows the same numbers, live.** In the manager's source
(`Corfirean/coa-server-manager`, `crates/coa-core/src/ra.rs`, checked at `10cfdcf5`, 20 Nov 2026) the panel sends
`server info` to the world console and reads its `Mean`, `Median` and `Percentiles (95, 99, max)` lines, which
the core prints from the same counters as `Timing.log`. So:

| Panel | Timing.log | Note |
|---|---|---|
| "average N ms per tick" | `Mean` | Last 500 passes at the moment you look |
| "95% under N ms" | first number of `Percentiles` | |
| "peak N ms" | third number of `Percentiles` | Worst of the last 500 passes only, so it "forgets" a spike within seconds |
| "N ticks/s" | 1000 / `Mean` | Worked out, not counted. The four rows of `docs/performance.md` fit this (30 ms and 33 ticks/s; 20 ms and 50) |

Which manager version is installed on the VM was not checked on 2026-11-22. The panel is a glance; `Timing.log`
is the record. A number read off the panel is one window at one moment: say so when you quote it.

**Thresholds the repo states. Use these and no others.**

| Statement | Source |
|---|---|
| "95% under" is the figure that matters most: under about **50 ms is smooth**; **100 ms and up feels laggy** | `docs/performance.md`, opening paragraph |
| Ticks per second only means something with bots awake; an idle server spins at about **250** | same (on this server "idle" is an empty world: the bots are logged out when nobody is on) |
| SmartScale puts far bots to sleep first when the tick time rises past **50 ms**, and is fully paused at **200 ms** | `docs/performance.md`, last bullet. In SQUID's source the input is the **worst** pass of the current and previous 500, not the average (`PlayerbotAI::AutoScaleActivity`), settings `AiPlayerbot.botActiveAloneSmartScaleDiffLimitfloor` / `...Ceiling`, not set in `server-settings.txt` so on their defaults |
| A healthy restart: downtime about 2 minutes; over 5 minutes is worth a mention | `docs/agents/context/patch-night.md` |
| Acceptable to James: about 30 minutes downtime, about 15 minutes data loss | Stated by James; home `wildcard-change-control` |

For anything else (how many spike minutes are acceptable, a p99 target, a CPU, memory or disk limit, a
slow-query count): **no adopted threshold.** For lag, the one proposed pass/fail test is the exit metric in
`wildcard-lag-spike-campaign` (Phase 1 step 5; Proposed practice, not yet adopted by James); propose anything
else via `wildcard-validation-and-qa`. The manager's own verdict
(mean up to 50 ms "Smooth", up to 100 "Busy", above "Lagging"; hint "above 20 ticks per second smooth, below 10
it lags") is the manager author's, on the average. It is not this project's bar: on 22 Nov the mean was 47 ms
("Smooth") while two minutes in three had a pass over a second.

**Rules for reading it**

1. Compare like with like. With nobody online the bots are **logged out** (`AiPlayerbot.DisabledWithoutRealPlayer
   = 1`; they log in 30 s after the first player and out 5 minutes after the last), so "idle" here means an
   **empty world**: median pass 2 ms, mean about 4 ms (about 240 passes a second), no spikes (22 Nov). That says
   nothing about play. Filter with `--min-players 1`. The first 20-25 minutes after the first login are the bots
   logging in (the login ramp): summarise them separately (`--skip-warmup-minutes`, or `--from`).
2. A record is the last 500 passes, not the minute (`AVG_DIFF_COUNT = 500` in the core's `UpdateTime.h`; the
   record prints `GetDatasetSize()` passes). The window lasts 500 x the mean pass: about 2 s with the world empty (4 ms), about
   25 s with a player on (50 ms). `timing_summary.py` prints this as "covered" per table row and per spike, and
   warns when most records cover under half their minute: 39% with a player on, 4% with the world empty, on 22 Nov. So each
   record's max and p99 are **floors**, and counts of spike minutes are **under-estimates**.
3. `max` is the worst single pass in the window; `p95` is how the server feels between spikes. Report both. A
   mean hides spikes completely.
4. After a spike SmartScale may put bots to sleep (it keys on the worst recent pass), so the passes right after
   a spike can look better than normal. Do not read that as recovery.
5. `players online` does not count bots, and the number of bots awake is not logged anywhere. It is the main
   uncontrolled variable in every comparison.
6. Measured numbers already in the repo, for context: `docs/performance.md` (7 Nov: 1,000 to 1,500 bots, map
   threads); settings comments (9 Nov: 95% under 74 ms, 99% 147 ms, worst 1.3 s with 3 players; 20 Nov: 95% 69 ms,
   99% 586 ms, worst 2.9 s at about 880 bots); commit 6a3e017 (21 Nov: median 36 ms, worst 2-5 s with 2 players);
   `references/reference-run-2026-11-22.md` (22 Nov: 457 complete records, 458 counting the block cut off at
   16:33:10; 117 with a player; 77 with a pass of 1 s or more; 22 with 2 s or more). The chronicle of what was tried: `wildcard-failure-archaeology`.

`console-history.txt` (older cores) is a list of slow passes only, without timestamps: read
`references/formats.md` section 4 before quoting it.

## 6. Reading the Windows counters

`perf_csv_summary.py <perf folder>` prints per-core CPU, then one row per counter. What each row can tell you:

| Row | Reading |
|---|---|
| CPU per core, "rows >= 90%" | One core pinned while the "all cores" figure stays low = one thread at its limit. `docs/performance.md`: the limit here is "one busy thread per map", not total CPU, so more vCPUs add little |
| Processor queue | Threads waiting for a processor. Staying above zero means the VM is short of CPU as a whole |
| Free memory, Paging, Page file | Falling free memory with sustained paging = memory pressure. `Pages/sec` has isolated bursts even when healthy |
| Disk read/write latency, queue, idle | Shown in ms. Sustained latency or low idle = the disk (a SATA SSD shared with other VMs, per `090-mysql-tuning.sql`) is in the way |
| worldserver / mysqld CPU | 100 = one full logical processor; the world server normally reads well over 100 |
| worldserver memory | Climbs as bots log in. Read the table row, not the "went from ... to ..." line, across a whole start |

No adopted threshold for any counter - propose via wildcard-validation-and-qa.

**What moved with the spikes** (`--timing Timing.log --spike-ms N --min-players 1`): each timing record becomes
one window; each counter is reduced to its worst value in that window (its highest; its lowest for free memory,
disk idle and the second worldserver CPU row); spike windows are compared with quiet ones. "share above quiet p95" near 5% = no relation; near 100% = moved with the spikes.
- Always use `--min-players 1` (or `--from/--to`). Otherwise quiet windows come from empty hours and everything
  "moves".
- It shows what moved **together**, never the cause. Fewer than 5 spike windows: the script warns; treat the
  table as a pointer.
- The counters are 5 s apart and per logical processor: they cannot say which thread, or what it was doing.

22 Nov result, for orientation (details in the reference run; 5% is chance): the busiest single core rose and the
world server's process total fell ("lowest in window") in 48% of spike windows each. mysqld CPU (21%, all of it
in the bot-login minutes) and disk idle (18%) moved less but above chance: **not ruled out**. Paging, queue,
memory and disk write latency did not move. What that means for the spikes: `wildcard-lag-spike-campaign`
(evidence A7, A8, A14).

## 7. Reading the slow query log

`slow_query_summary.py` groups statements by shape (values replaced by `?`). Read the columns like this:

| Pattern | Likely meaning |
|---|---|
| High "rows read", few "rows sent" | A scan: probably a missing index. Precedent: the 40-second character list, fixed by an index on `character_spell.spell` (`EnsureCharacterSpellIndexes`) |
| "rows read" tiny but slow, or high "lock s" | Waiting, not searching: a lock or a flush |
| Rows read = rows sent in the hundreds of thousands, user `acore`, just after a start | The world loading a whole table: normal at start-up |
| User `root` | Patch night's own helper queries, not the game |

- Times are **UTC**; pass `--utc-offset-hours 11` to match the other logs.
- An empty time range is a finding: on 22 Nov there was no slow query at all during the spike period, which
  rules out a single slow statement and nothing more (many fast statements do not appear here, and mysqld was
  busy while the bots logged in).
- Only statements over 0.5 s are logged. No adopted threshold for count or total - propose via
  wildcard-validation-and-qa.

## 8. Reading patch night, settings, errors, and live status

**Patch night** (`patch_night_summary.py`; tested on synthetic data only). Runs are bracketed by
`---- patch night started ----` (or the Start-Server / Rebuild-bots variants) and
`---- patch night finished ----`; the line before the end is the outcome at `[OK]` or `[FAIL]`
(literal strings from `PatchNight.ps1`). Flags the script raises: `FELL BACK TO OFFICIAL`, `LONG DOWNTIME`
(over 300 s, from the "over 5 minutes" line above), `NO FINISHED LINE`, `BAD SETTING VALUE(S)`,
`INSTALL NOT CONFIRMED`. What counts as healthy or wrong: `docs/agents/context/patch-night.md` (DOCTRINE). No log lines at
the scheduled time means the task did not run (it runs only while James is signed in). Operating patch night:
`wildcard-run-and-operate`.

**Settings report** (`server-settings\settings-report.txt`): look for the `Unknown, in neither the .dist nor the
server program` count and `Values it could not use` (should be 0). The context pack's rule is "0 unknown"
(DOCTRINE), but `wildcard-settings-and-flags` predicts from the code that about 28 working settings can
never pass it, and the refinement `5978ee4` is not on `main` (UNVERIFIED on the VM). **Proposed practice (not yet
adopted by James):** compare the unknown list with the previous run's and flag only NEW names. Settings on
defaults are normal; only a change in their number matters (`patch-night.md`). Home: `wildcard-settings-and-flags`.

**Errors.log** (`errors_log_groups.py`): this start only, no timestamps, tens of thousands of standing
data-check lines. Do not read it top to bottom. Keep yesterday's copy and run `--baseline` to see new kinds;
`patch-night.md` treats "a new kind of line since the last start" as something wrong.

**Server.log**: this start only. Line 1 is the banner with the core revision; `World Initialized In` means the
world is up (patch night's own check). It also holds the timing lines, without timestamps:
`timing_summary.py Server.log` works.

**Live status, without touching the console:** the sign-up service answers `GET /api/status` (JSON: `login`,
`world`, `players`, `characters`, `uptime`, `server` build, cached 30 s; `signup/WildcardStatus.py`). On `main`
(PR #231) its console window is a status board refreshed every 30 s. Both get players and uptime by sending the
read-only `server info` through the manager's `ra-once`. Any other console command is a GM command: hard stop 1
in `docs/agents/context/change-risk.md` (DOCTRINE). Home for these services: `wildcard-client-and-web`.

## 9. Measuring discipline

The full method (evidence bar, predicting numbers before running, trying to refute your own result) is in
`wildcard-analysis-and-method`. The lag-spike work itself is run from `wildcard-lag-spike-campaign`. The
minimum for any before/after claim:

1. **Baseline first.** Capture the "before" numbers before the change goes in. `Timing.log` is appended for
   ever, so the baseline usually already exists: find the window, do not rely on memory.
2. **Write the prediction down first**: which number moves, which way, roughly how far.
3. **Same conditions.** Same hours of the day, same number of real players (`--min-players`/`--max-players`),
   same bot count (`AiPlayerbot.MinRandomBots`/`MaxRandomBots`, 750 since 21 Nov), same build, same map threads.
   Skip the warm-up after a start. If a condition differs, say so next to the number.
4. **One change at a time.** Two changes in one restart cannot be told apart. (CHANGES.md says one PR per patch
   night; history shows many merges on some days. Either way, plan the measurement around what actually went
   live together.)
5. **Enough data.** One evening with one player is an observation. Say how many minutes and how many players.
6. **Report p95 and the spikes, with coverage**, never the mean alone.
7. **Record it** in `docs/performance.md` (a doc of record: change it by PR, see `wildcard-docs-and-publishing`).

The table in `docs/performance.md` has these columns. Template row, with where each cell comes from:

```
| Setup | Ticks/s | Average | 95% under | Peak | VM memory |
| --- | --- | --- | --- | --- | --- |
| 750 bots, 6 map threads, 1 player, 22 Nov 14:36-16:32 | 21 | 47 ms | 94 ms | 5,397 ms | ~11.7 GB |
```

| Column | Take it from |
|---|---|
| Setup | Bot count, map threads, players, date and hours, build tag if relevant |
| Ticks/s | `timing_summary.py` column "ticks/s" (1000 / average mean) |
| Average | column "avg mean ms" |
| 95% under | column "window p95: p50" (the typical per-minute p95). The 7 Nov rows were read off the manager panel, one window at one moment; say which you used |
| Peak | column "worst tick ms" |
| VM memory | The 7 Nov rows do not say how it was read. From the counters: 18 GB minus the "Free memory" median (the example uses 6,310 MB free between 15:00 and 16:00) |

The example row is real (22 Nov reference run) but is **not yet in** `docs/performance.md`; adding it is a PR.

**Proposed practice (not yet adopted by James; the home for the proposed row shape is `wildcard-docs-and-publishing`,
`references/templates.md`, template E):** add two columns, "minutes with a pass >= 1 s" and "covered",
to that table. *Purpose:* the existing columns cannot show the failure players report; on 22 Nov "95% under" was
94 ms (borderline) while 66% of minutes had a pass over a second. *Motivating incident:* commit 6a3e017
("worst ticks of 2-5 seconds with 2 players on (median 36 ms)").

## 10. Enchant tooling

These measure the Mystic Enchant data, not server speed. Home for using their output: `ascension-restoration`.

**Both DBC tools need the game client's data files, which are NOT in this repository and must never be added**
(public repo, no client data): a folder holding `Spell.dbc` (about 209 MB) and `MysticEnchant.dbc`, as extracted
for a server (the tools' own example path is `~/coa-test/env/dist/data/dbc`). Where that folder is on the VM was
not checked on 2026-11-22: search the server folder for `Spell.dbc`.

| Tool | Command (arguments are positional; there is no `--help`, running without arguments prints the usage text) | Reads | Writes |
|---|---|---|---|
| `enchants/enchant_audit.py` | `python enchant_audit.py <dbc folder> [output folder]` (output defaults to the current folder) | `Spell.dbc`, `MysticEnchant.dbc`; if a **test server's Docker database container** is running (it tries `ac-database`, `azerothcore-wotlk-ac-database-1`, `coa-test-ac-database-1`) also `spell_dbc` and `spell_script_names` | `summary.txt` (counts per category, per quality, per class) and `enchants.csv` (one row per enchant: spell, name, quality, classes, worldforged, this realm, status, effects, notes, description). Changes nothing |
| `enchants/export_spell_data.py` | `python export_spell_data.py <dbc folder> [output file]` (default `~/enchant-data.json.gz`) | `Spell.dbc`, `MysticEnchant.dbc` | One gzip JSON, a few MB: every field of each enchant spell and of the spells they teach, trigger or mention, plus a name index. Changes nothing |
| `scripts/legendary_history.py` | From the repo root: `python3 -I scripts/legendary_history.py [--quality Epic] [--ref HEAD] [--patch-night-log <path>]` | `enchants/tracker.csv`, `test-checklist.csv`, `<tier>-notes.csv`, git history, GitHub through the `gh` CLI (signed in), optionally `patch-night.log` for the date each build was installed | **Rewrites** `enchants/<tier>-history.csv` and `enchants/<tier>-notes.md` in the working tree |

Cautions:
- On the VM there is no Docker test server, so `enchant_audit.py` prints "database not reachable" and falls back
  to the DBC files alone: enchants defined only in `spell_dbc` then show as `missing`, and none as `scripted`.
  Its categories (`missing`, `unsupported`, `needs-code`, `scripted`, `standard`, plus `teaches-*` and
  `custom-db`) describe what the data can support, not whether an enchant has been seen working.
- `enchants.csv` and the export contain client description text. Keep both out of the repo and out of PRs
  (no verbatim tooltip text in a public repo).
- `legendary_history.py` writes into `enchants/`: run it on a branch, and its output goes through a PR.
- `patch_night_summary.py` and `legendary_history.py --patch-night-log` read the same file; the latter looks only
  for lines matching `installed wcme-server-...-buildN`.

## 11. What cannot be measured yet

Not recorded today: when within a minute a spike happened; which part of the pass was slow; per-map pass time;
per-bot cost; how many bots were awake; packet counts; database queue depth or statements per second; which
thread was busy; host-level pressure over time. `references/gaps-and-candidate-instruments.md` lists each gap
and six candidate instruments checked against the pinned sources (read it when the logs cannot answer your
question and you are about to propose a new measurement). Three of them exist in the code already and are
simply off: a shorter record interval, the core's `Metric.*` timers (per part of the pass and per map; needs an
InfluxDB server), and SQUID's `playerbots pmon` performance monitor. All are design proposals (NOT BUILT YET,
need James's OK), and each changes the server: **classify with wildcard-change-control first** (none is a
standard change: the settings' comments state no range).

## Provenance and maintenance

Written 2026-11-22 from the repository at PR #232's head `fcfee51` (which sits on `62a26e4`, #230; `origin/main`
is `d3e030f`, #231, one merge ahead, adding `signup/WildcardConsole.py`), the pinned core `c3f2fd4b2395`, SQUID playerbots v3.0 (`4ef5ed9e`), the manager
source at `10cfdcf5`, and a read-only copy of the server's `Core\Logs` taken at 16:33 that day.
Not seen that day: `patch-night.log`, `settings-report.txt`, `Core\Crashes`, the live config files, the VM's
Python version, the DBC folder. Statements about those come from the code that writes them.

Re-check when something may have drifted (run from the repo root unless a path says otherwise):

```
# Scripts still work
python3 -I -B .claude/skills/wildcard-diagnostics-and-tooling/scripts/selftest.py
# Timing settings unchanged
grep -nE "RecordUpdateTimeDiffInterval|MinRecordUpdateTimeDiff|Appender.Timing|Logger.time.update" server-settings/server-settings.txt
# Logging settings (async, quiet categories)
grep -nE "Log.Async.Enable|Logger.coa|Logger.module.coa_challenges" server-settings/server-settings.txt
# Bots are logged out when nobody is on (what "nobody online" means)
grep -n "DisabledWithoutRealPlayer" server-settings/server-settings.txt
# Counter list, interval, retention
grep -nE "typeperf|'-si'|AddDays\(-14\)|Processor\(\*\)" patch-night/PatchNight.ps1
# Slow-log threshold and path
cat sql/enchants/095-slow-query-log.sql
# Run marker lines and the downtime line
grep -nE "^Log '----|patch night finished|Downtime:" patch-night/PatchNight.ps1
# Console log rotation, and the once-only console history
grep -n -A 12 "function RotateConsoleLogs" patch-night/PatchNight.ps1
grep -n -A 6 "function SaveConsoleHistory" patch-night/PatchNight.ps1
# Thresholds in the docs
cat docs/performance.md
git show origin/main:docs/agents/context/patch-night.md | grep -nE "Downtime|5 minutes"
# Bot count and map threads
grep -nE "MinRandomBots|MaxRandomBots|MapUpdate.Threads" server-settings/server-settings.txt
# Pinned core revision
python3 -I scripts/resolve_release.py latest
# Enchant tool arguments
sed -n 1,22p enchants/enchant_audit.py; sed -n 1,12p enchants/export_spell_data.py; grep -n "add_argument" scripts/legendary_history.py
```

In a clone of the core (after a core update), the timing line text:
`grep -n 'LOG_INFO("time.update"' src/server/game/Time/UpdateTime.cpp; grep -n "AVG_DIFF_COUNT" src/server/game/Time/UpdateTime.h`.
In a clone of the manager, that the panel still reads `server info`: `grep -nE "ticks_per_sec|strip_prefix" crates/coa-core/src/ra.rs`.
In a clone of SQUID playerbots, the SmartScale defaults: `grep -n "SmartScale" conf/playerbots.conf.dist`.
On the VM: run each script and read its first two lines (lines read, lines skipped).

When a format changes: fix the parser, add the new shape to `samples/make_synthetic_samples.py`, regenerate,
update `selftest.py`, and add a dated reference run beside `references/reference-run-2026-11-22.md` rather than
overwriting it.
