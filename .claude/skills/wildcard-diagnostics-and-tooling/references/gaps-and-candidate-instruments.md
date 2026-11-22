# What cannot be measured today, and candidate instruments

Read this when the existing logs cannot answer your question (which map, which bot, which query burst, which
thread) and you are about to propose a new measurement.

Everything under "Candidate" is a **design proposal (NOT BUILT YET, needs James's OK)**. Each one changes what the server
writes or runs, so each needs `wildcard-change-control` first (classify, respect the hard stops, James merges),
and a prediction written down before it is switched on (`wildcard-analysis-and-method`).

Checked on 2026-11-22 against: this repository; the pinned core `Corfirean/azerothcore-wotlk-coa` at
`c3f2fd4b2395`; SQUID's playerbots `Zyth45/mod-playerbots` at `4ef5ed9e` (v3.0). "In the pinned source" means
the code is there; whether it works on this server is untested unless stated.

## What is recorded, and what is not

| Question | Recorded today? | Detail |
|---|---|---|
| How long does one pass of the game loop take? | **Partly.** | `Timing.log`: once a minute, a summary of the last 500 passes. With a player on that is about 40% of each minute (22 Nov 2026); with the world empty about 4%. No per-pass record. |
| When exactly did a spike happen? | **No.** | Only "somewhere in the 500 passes before this record". Second-level timing does not exist. |
| Which part of the pass was slow (sessions, maps, bots, auctions, database callbacks)? | **No.** | Nothing splits the pass. |
| Which map was slow (Eastern Kingdoms, Kalimdor, a dungeon copy)? | **No.** | `docs/performance.md` names "one busy thread per map" as the limit; that came from CPU patterns, not from a per-map timer. |
| What does one bot cost? Which bot action is expensive? | **No.** | |
| How many bots were awake (not asleep) at a given moment? | **No.** | "players online" in `Timing.log` counts real players only. The status page's "characters in world" (bots included) is live only, not logged. |
| Packets in or out per second? | **No.** | |
| Database: queue depth, queries per second, time waiting for a connection? | **No.** | Only single statements over 0.5 s (`mysql-slow.log`). `performance_schema` is switched off on purpose (`sql/enchants/090-mysql-tuning.sql`). A burst of many fast statements is invisible. |
| Which thread was at 100%? | **No.** | Counters are per logical processor and per process, every 5 s. |
| Machine CPU, memory, paging, disk? | **Yes.** | `Logs\perf\*.csv`, every 5 s, 14 days. |
| Host (Proxmox) pressure: another VM stealing CPU or disk? | **No.** | `docs/performance.md` records one check on 7 Nov ("no CPU, memory or IO pressure"); nothing ongoing. Home: `wildcard-run-and-operate`. |
| What a player felt (client latency, rubber-banding)? | **No.** | Only reports from players. |
| Downtime of a restart? | **Yes**, from 22 Nov. | `Downtime: N s` in `patch-night.log`. |
| Did a setting take effect? | **Yes.** | `settings-report.txt`. |
| Did an enchant do what its tooltip says? | **No**, not automatically. | Manual tests recorded in `enchants/test-checklist.csv` and the tracker. Home: `wildcard-validation-and-qa`. |

## Candidates

Ordered by how directly each answers "what is the main thread doing during a multi-second pass", the open
question after the 22 Nov reference run.

### C1. Record more often, so the windows cover the whole minute
- **What:** lower `RecordUpdateTimeDiffInterval` from 60000 so that 500 passes span the gap. At a 50 ms mean,
  500 passes last 25 s; an interval of 20000 would leave no gap with a player on (and write three times as much).
- **In the pinned source?** Yes: it is the setting already in use (`UpdateTime.cpp`, `LoadFromConfig`).
- **Cost:** file grows about 3x (roughly 1 MB a day at the 22 Nov rate). Five log lines every 20 s is negligible
  next to what the console already writes.
- **Answers:** how many spikes there really are, and when, to within 20 s. Does not say why.
- **Change class:** a value change to a setting already in `server-settings.txt`. Classify with
  `wildcard-change-control` (the "standard change" rule needs a documented range, and this comment states none).

### C2. The core's built-in metrics
- **What:** the core can time each part of `World::Update` and each map's update and send them to an InfluxDB
  database: `Metric.Enable`, `Metric.InfluxDB.Connection`, `Metric.Interval` in `worldserver.conf.dist`. Timers
  in the source include `world_update_time` tagged by part ("Update sessions", "Update maps", "Update
  battlegrounds", "Process query callbacks", ...), `map_update_time_diff` tagged by map id
  (`src/server/game/Maps/MapUpdater.cpp`) and `update_time_diff`.
- **In the pinned source?** Yes, default off (`Metric.Enable = 0`). They are compiled out only when the build
  sets `WITHOUT_METRICS`; our workflow's CMake line does not set it. UNVERIFIED that the installed binary sends
  anything: nobody has switched it on here.
- **Needs:** an InfluxDB server to receive the data (a new service on the VM or the homelab). That is the real
  cost, plus one stopwatch per part per pass while enabled.
- **Answers:** which part of the pass and which map is slow, second by second. This is the closest existing
  thing to "per-map tick time".
- **Does not answer:** per-bot cost. The per-session timers (`world_update_sessions_time`) need a build with
  `WITH_DETAILED_METRICS`, which ours does not set.
- **Change class:** new service plus settings: not LOW. Network setup is a hard stop if it opens a port.

### C3. SQUID's bot performance monitor
- **What:** `AiPlayerbot.PerfMonEnabled` (default 0 in `playerbots.conf.dist`) and the console command
  `playerbots pmon` with `reset`, `tick`, `stack`, `toggle` (`src/Script/PlayerbotCommandScript.cpp`). It prints a
  table of time per bot action, trigger and value to the `playerbots` logger.
- **In the pinned source?** Yes. UNVERIFIED on this server: never run here, output format not captured, overhead
  unknown (it times every bot action while on).
- **Answers:** which kind of bot work the time goes to. This is the closest existing thing to "per-bot cost".
- **Change class:** `toggle` changes live behaviour through a console command. GM and console commands are hard
  stop 1 in `docs/agents/context/change-risk.md`: James runs it or approves it.

### C4. Per-thread CPU at 1 second
- **What:** add `\Thread(worldserver*)\% Processor Time` to `counters.txt` and sample at 1 s for a bounded test
  window. Windows exposes one instance per thread (`worldserver/0`, `worldserver/1`, ...).
- **In the repo?** No. UNVERIFIED: instance naming and whether typeperf keeps up with new threads have not been
  tried here. Thread numbers are not names; you learn "thread 0 was pinned", then must still work out which
  thread that is.
- **Cost:** about 30 more columns and 5x the rows: tens of MB a day. Do it for an hour, not for ever.
- **Answers:** whether a spike is the main thread or a map thread. The 22 Nov run could only say "one logical
  processor".
- **Change class:** an edit to `PatchNight.ps1` = patch night itself = hard stop 5. Alternative that changes
  nothing: James (or a session with VM access, with his say-so) runs a second `typeperf` by hand for the test.

### C5. Count database statements, not just slow ones
- **What:** sample MySQL's own counters (`SHOW GLOBAL STATUS LIKE 'Questions'`, `Threads_running`,
  `Innodb_row_lock_time`) every few seconds into a CSV, with the administrator client patch night already uses.
- **In the repo?** No. NOT BUILT YET. Read-only queries, but a new scheduled job on the server.
- **Answers:** whether spike minutes coincide with a burst of statements or lock waits (the thing
  `mysql-slow.log` cannot see).
- **Related, and not available:** the core can warn about every synchronous query made from the game loop
  (`WarnAboutSyncQueries`, logger `sql.performances`), but only in a Debug build (`#ifdef ACORE_DEBUG` in
  `DatabaseWorkerPool.cpp`). Our builds are `RelWithDebInfo`, so it is inert.

### C6. Log the awake-bot count
- **What:** once a minute, write how many bots are active next to the timing record.
- **In the pinned source?** No ready-made log line was found. Would be a patch (C++). NOT BUILT YET.
- **Answers:** separates "more bots awake" from "same bots, slower pass", the confounder in every comparison so far.
- **Change class:** server C++ running per tick or per minute: `wildcard-patch-authoring`, then change control.

### Not instruments (checked, to save the next reader the trip)
- `.server debug`: build and configuration facts (versions, ports, vmap status). No timing.
- `.server info`: the same five timing numbers as one `Timing.log` record, live. The manager's panel reads this.
- `MaxCoreStuckTime`: a freeze watchdog that stops a stuck server; default 0 (off) in the CoA config. Not a measure.
- `mod-livemon` (in the pinned core's modules): combat statistics per character for balancing (damage, healing,
  crowd control), with a local web feed. It does not time the server. Possibly useful for goal C (re-balancing);
  whether it is enabled here is UNVERIFIED.
- `squidbot\events.jsonl`: world events for a dashboard, not performance.

## Proposed practice (not yet adopted by James)
**One instrument at a time, with an end date.** *Purpose:* an instrument left on is a change to the server that
nobody is watching. *Motivating incident:* console logging grew `world-console.log` to 2.9 GB, and commit f9dc45a
(20 Nov 2026) names it as a cause of slow passes (the 99th percentile pass was 586 ms with every log line written
in line with the world update). That change shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB
on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log
clear/rotation had not run yet; status OPEN. For each new instrument write down: the question, the prediction, the
cost you expect, the date it comes off, and who removes it.
