# Chronicle: performance, lag spikes and the bot count

The lag-spike problem is the project's hardest live problem and it is **open**. This file is the full record of
what was changed, in order, with **every measured number that is in the repository**. Read it before proposing
any performance change, so a setting that was already tried is not tried again as if new.

Facts come from commit messages, `docs/performance.md` and comments in `server-settings/server-settings.txt`, as
of 2026-11-22. Nothing here was re-measured on the VM. No number below is mine.

Reading aid:

- **Tick** (or "world update"): one pass of the world server's game loop. Every bot and player is updated in it.
  A long tick is what players feel as a freeze.
- **"95% under N ms"**: 95 of every 100 ticks took less than N ms. `docs/performance.md`: "under about 50 ms is
  smooth; 100 ms and up feels laggy".
- **Ticks per second** "only means something with bots awake (an idle server spins at about 250)"
  (`docs/performance.md`).
- **Awake / asleep bot:** SQUID fully updates only some bots. `AiPlayerbot.BotActiveAlone` is the percentage kept
  awake away from real players.
- **Map threads:** `MapUpdate.Threads`, how many maps (each continent, each dungeon copy) update in parallel.
- Where the numbers were read: "World speed in the manager" (`docs/performance.md`) and "the tick summary in
  `.server info`" (`7001de0`).

---

## The sequence at a glance

| # | Date | Change | Measured before or after (as written in the repo) | Evidence | Still in force on 22 Nov? |
|---|---|---|---|---|---|
| 1 | 6 Nov | Bots 1,000 | none. Comment: "SQUID's notes: 500 fit comfortably in 16 GB, 5,000 ran in about 9 GB" | `7a90659`, PR #46 | no (750) |
| 2 | 7 Nov | `MapUpdate.Threads = 4` | Before: "1,000 bots kept one core busy while the other seven idled (21% CPU, 30 ms a tick)". Table: 1 thread 33 ticks/s, avg 30 ms, 95% under 61 ms, peak 489 ms; 4 threads 50 ticks/s, avg 20 ms, 95% under 39 ms, peak 58 ms; about 10 GB VM memory both | `70f055b`, PR #49; `docs/performance.md` | no (6) |
| 3 | 7 Nov | Bots 1,500 ("try") | Before, in the subject: "1,000 ran at about 45 ticks/s, 20 ms a tick, with map threads" | `2ce36a4`, PR #53 | no |
| 4 | 7 Nov | Bots 1,250 ("settle") | 1,500: "26 ticks/s, 95% under 66 ms, peaks of 300 ms"; table: 26 ticks/s, avg 38 ms, 95% under 66 ms, peak 301 ms, 8.9 GB. 1,250: 30 ticks/s, avg 33 ms, 95% under 64 ms, peak 112 ms | `aca9022`, PR #57; `4ce450e`, `35c8e95`, PR #58 | no |
| 5 | 7 Nov | `BotActiveAlone` 15 to 5 | none | `240d773`, PR #59 | yes (5) |
| 6 | 8 Nov | More database connections (`CharacterDatabase.WorkerThreads = 4`, `SynchThreads = 2`, `LoginDatabase.WorkerThreads = 2`) | none. Symptom: slow "retrieving character list" and slow character creation while bots start | `0cce098`, PR #75 | yes |
| 7 | 8 Nov | MySQL tuning by `SET PERSIST`; `MapUpdate.Threads = 6` | Comment: "6 from 8 Nov, with the VM at 10 cores (was 4 on 8 cores: 30 -> 50 ticks/s at 1,000 bots)"; "The VM has 18 GB; the server used about 9 at 1,500 bots" | `61a5be9`, `a55aaea`, `da2a3fd`, PR #77 | yes |
| 8 | 8 Nov | View distance 100 to 75 yards | none | `0cd1413`, branch `perf-visibility-react` | **never merged** |
| 9 | 8 Nov | Slow-query log, index on `character_spell.spell` and `character_talent.spell`, log removed | Character list "40 s to under 1 s" | `cc145e5` PR #82; `257158e` PR #84; `ea01588` PR #86 | index yes; that log removed |
| 10 | 8 Nov | Wake bots within 300 yards of a player, zone waking off | Before: "with two players questing in different zones ... 95% under 62-72 ms, spikes to 485" | `e608f61`, PR #88 | radius yes; zone waking back on |
| 11 | 8 Nov | Zone waking back on, radius kept | none. Symptom: bots near players "walked a few steps, then stood for 20 minutes or more" | `c02ba12`, PR #95 | yes |
| 12 | 9 Nov | View distance 150 yards | none | `7001de0`, PR #111 | no: backed out the same day |
| 13 | 9 Nov | View distance back to 100; bots 1,250 to 1,000 | "lag spikes with 3 players on (95% under 74 ms, 99% 147 ms, worst 1.3 s)" | `ff00757`, PR #113 | view distance yes; bots no |
| 14 | 20 Nov | Logging off the world update (`Log.Async.Enable = 1`, two loggers off the console) | Before: "about 880 bots in the world (95% under 69 ms, 99% 586 ms, worst 2.9 s)"; `world-console.log` 2.9 GB | `f9dc45a`, PR #204 | yes |
| 15 | 21 Nov | Bots 1,000 to 750 | "2 players on, median 36 ms but worst ticks of 2-5 s" | `6a3e017`, PR #217 | yes (750) |
| 16 | 21 Nov | Measure only: `Timing.log`, Windows counters, console history, slow-query log | none yet | `9ba9f45`, PR #225 | yes |

Bot count in one line: 1,000 (6 Nov), 1,500 (7 Nov), 1,250 (7 Nov), 1,000 (9 Nov), 750 (21 Nov).

**No "after" measurement is recorded for steps 5, 6, 7, 10, 11, 13, 14 or 15.** Steps 2 to 4 are the only ones
with a before and an after.

Worst tick on record, in date order: 489 ms (1 thread, 7 Nov), 58 ms (4 threads, 7 Nov), 301 ms (1,500 bots),
112 ms (1,250 bots), 485 ms (two players in two zones, 8 Nov), 1.3 s (3 players, 9 Nov), 2.9 s (about 880 bots,
20 Nov), 2 to 5 s (2 players, 21 Nov). The "95% under" figure stayed between 39 and 74 ms in every
reading while the worst tick grew. History states no cause for that.

---

## F-01 · 2026-11-07 · One busy core, seven idle

- **Symptom:** 1,000 bots at 30 ms a tick with 21% CPU.
- **Root cause (as stated):** the world updated all maps on one thread.
- **Evidence:** `70f055b`, PR #49; `docs/performance.md` table.
- **Tried and rejected:** nothing; comment says "Back to 1 if anything odd shows up."
- **Status:** fixed for that symptom (peak 489 ms to 58 ms at 1,000 bots).
- **Lesson:** `docs/performance.md`: "Memory is not the limit; one busy thread per map is (most bots are on
  Eastern Kingdoms and Kalimdor), so more vCPUs or map threads add little."

## F-02 · 2026-11-07 · How many bots: 1,500 tried, 1,250 chosen

- **Symptom:** at 1,500 bots peaks of 300 ms.
- **Root cause:** not stated beyond the bot count.
- **Evidence:** `2ce36a4` PR #53; `aca9022` PR #57; `docs/performance.md`: "Settled on 1,250: the 95% figure is
  close to 1,500's, but the spikes players feel are a third as large."
- **Tried and rejected:** 1,500.
- **Status:** superseded (1,000 on 9 Nov, 750 on 21 Nov).
- **Lesson:** judge a bot count by the peak, not the average. `docs/performance.md` also notes "The Proxmox host
  showed no CPU, memory or IO pressure."

## F-03 · 2026-11-07 · Let the far world sleep

- **Symptom:** none measured; a design choice ("zones with players fully active, the rest of the world mostly
  asleep", `docs/performance.md`).
- **Evidence:** `240d773`, PR #59. `docs/performance.md` still lists this under "Levers for later (not changed
  yet)" with "(now 15)": that line of the document is out of date, the setting is 5.
- **Status:** in force.
- **Lesson:** `docs/performance.md`: "Sleeping bots still cost a basic update every tick, so the total bot count
  still matters." Worst case named there: "10 zones x 200 bots would be about 2,000 awake, which this CPU cannot
  carry." It also says SmartScale "puts far bots to sleep first when the tick time rises past 50 ms, and is fully
  paused at 200 ms".

## F-04 · 2026-11-08 · The 40-second character list

- **Symptom:** "Retrieving character list" took about 40 seconds.
- **Root cause:** "every login's full-table spell delete": no index on the `spell` column of `character_spell`
  and `character_talent`.
- **Evidence:** `cc145e5` PR #82 (temporary slow-query log, queries over 1 s, file `091-slow-query-log.sql`);
  `257158e` PR #84 (patch night adds index `idx_spell` to both tables); `ea01588` PR #86 (log removed).
- **Tried and rejected:** more database connections (`0cce098`, PR #75, earlier the same day) was aimed at the
  same symptom; the slow-query log was still needed afterwards, and the index is what the fix commit credits.
- **Status:** fixed: "40 s to under 1 s". The connections setting stayed.
- **Lesson:** this is the only performance problem in the repository with a proven root cause, and it was found
  by logging first. Measure, find the query, then fix.

## F-05 · 2026-11-08 · MySQL tuning

- **Symptom:** none measured. Aim: databases in memory, fewer forced flushes under the stream of bot saves.
- **Root cause of the workaround:** "The manager rewrites `mysql\my.ini` at every start with a 256 MB buffer pool,
  so the values are stored with `SET PERSIST` instead."
- **Evidence:** `sql/enchants/090-mysql-tuning.sql` (`61a5be9`, `a55aaea`, `da2a3fd`, PR #77).

| Setting | Value | Trade-off stated in the file |
|---|---|---|
| `innodb_buffer_pool_size` | 4 GB | none |
| `innodb_redo_log_capacity` | 1 GB | none |
| `innodb_flush_log_at_trx_commit` | 2 | "only a power cut or VM crash (not a server crash) can lose that last" few seconds |
| `innodb_flush_log_at_timeout` | 3 | saves reach disk every few seconds; up to 3 seconds can be lost |
| `innodb_log_buffer_size` | 64 MB | none |
| `performance_schema` | OFF (`PERSIST_ONLY`, from the next MySQL restart) | MySQL's own profiler is unavailable |
| `innodb_io_capacity` / `_max` | 1000 / 2000 | "The VM is on a SATA SSD shared with other VMs, so a moderate value" |

- **Tried and rejected:** editing `my.ini` (the manager overwrites it). Flush "once a second" (`61a5be9`) became
  "every 3 s" one commit later (`a55aaea`).
- **Status:** in force. To undo one: `RESET PERSIST <name>;` then restart MySQL (from the file's header).
- **Lesson:** MySQL settings live in `090-mysql-tuning.sql`, not `my.ini`. `performance_schema` is off, so any
  diagnosis that needs it must turn it back on and restart MySQL.

## F-06 · 2026-11-08 · View distance 75 yards: written, never merged

- **Symptom:** none measured. Reasoning in the commit: "Every visible character's movement goes to every player
  who can see it, so a capital full of bots costs a lot."
- **Evidence:** `0cd1413` on branch `perf-visibility-react` (based on `main` just after PR #76). Not on `main`.
- **Status:** abandoned or parked: **status unknown - ask James**. No measurement at 75 yards exists.
- **Lesson:** 75 yards is an untested idea, not a rejected one.

## F-07 · 2026-11-08 · Wake radius: bots froze, zone waking came back

- **Symptom A (before):** two players in different zones each woke a whole zone of bots: "95% under 62-72 ms,
  spikes to 485".
- **Change:** `BotActiveAloneForceWhenInZone = 0`, `BotActiveAloneForceWhenInRadius = 300` (`e608f61`, PR #88):
  "each extra player costs a circle, not a zone".
- **Symptom B (after, same day):** "with zone waking off, bots near players still froze (walked a few steps, then
  stood for 20 minutes or more) although the radius check reads correctly".
- **Root cause:** **not known.** The comment says zone waking is back on "until that is understood".
- **Evidence:** `c02ba12`, PR #95 (same change also on branch `world-pvp-bots` as `f3f9170`);
  `server-settings/server-settings.txt` lines 467 to 475.
- **Tried and rejected:** radius alone.
- **Status:** worked around. Both are on: whole-zone waking and the 300 yard radius. So the cost that PR #88 set
  out to remove (one player wakes a whole zone) is back.
- **Lesson:** "radius only" has been tried and broke bots near players. Do not turn zone waking off again without
  first explaining the freeze.

## F-08 · 2026-11-09 · View distance 150 yards, backed out before it went live

- **Symptom wanted fixed:** "mobs in big open zones like the Barrens ... popping in out of nowhere".
- **Evidence:** `7001de0`, PR #111 (150, with the note "watch the tick summary in `.server info` after this; if
  spikes get worse, try 125"); `ff00757`, PR #113, the same day: "150 was tried in settings but backed out before
  it went live, while chasing lag spikes with 3 players on; every bot is a player too, so each bot would see
  further".
- **Tried and rejected:** 150 was never live, so it was never measured. 125 was never tried.
- **Status:** 100 yards (the default), set explicitly.
- **Lesson:** "tried" in the settings file does not mean tested on the server. 150 has no measurement either way.

## F-09 · 2026-11-09 · Spikes with 3 players: bots back to 1,000

- **Symptom:** "95% under 74 ms, 99% 147 ms, worst 1.3 s" with 3 players on, at 1,250 bots.
- **Root cause:** not stated.
- **Evidence:** `ff00757`, PR #113.
- **Tried and rejected:** none recorded.
- **Status:** superseded by 750 (F-11). No measurement at 1,000 after this change is recorded until 20 Nov.

## F-10 · 2026-11-20 · Logging ran inside the world update

- **Symptom:** "Lag spikes with about 880 bots in the world (95% under 69 ms, 99% 586 ms, worst 2.9 s)."
- **Root cause (as stated):** "Every log line was written in line with the world update, and the console got
  every Wildcard roll (dozens per bot as it builds) and every challenge packet sent to a bot;
  world-console.log had grown to 2.9 GB."
- **Evidence:** `f9dc45a`, PR #204; `server-settings/server-settings.txt` lines 515 to 522
  (`Log.Async.Enable = 1`, `Logger.coa = 4,Server`, `Logger.module.coa_challenges = 3,Console Server`).
- **Tried and rejected:** none recorded.
- **Status:** OPEN. Shipped 20 Nov; **no after-measurement.** The next day's commit (F-11) reports worst ticks of
  2 to 5 seconds; the repository does not say whether that reading was taken before or after the logging change
  went live. On 22 Nov `world-console.log` was 2.99 GB again (2,992,375,188 bytes, modified that day). The 22 Nov
  server start (08:53) predates the merges of #229 to #231, so the console-log clear and rotation of `759c7b6`
  had not run yet. After the next restart look in `patch-night.log` for "Cleared world-console.log" or "Left
  world-console.log as it is for now (in use)".
- **Lesson:** a cause was named and fixed without an after-measurement, so it is not known whether it was *the*
  cause.

## F-11 · 2026-11-21 · Bots 750 "while the lag spikes are worked through"

- **Symptom:** "2 players on, median 36 ms but worst ticks of 2-5 s."
- **Root cause:** not known. The commit says so: "Fewer bots while we find the cause."
- **Evidence:** `6a3e017`, PR #217.
- **Status:** worked around; explicitly temporary.
- **Lesson:** the pattern (a healthy median with rare multi-second ticks, even with 2 players) is what the
  measurements of F-12 exist to explain.

## F-12 · 2026-11-21 · Measure only

- **Change:** nothing about how the server runs. Four recordings were added (`9ba9f45`, PR #225):

| Recording | Where on the VM | What it holds | Set by |
|---|---|---|---|
| `Timing.log` | `Core\Logs\Timing.log` | the game loop's update time "once a minute, every time" with the time of day; appended across restarts, "about 100 KB a day". Before this "it used to sample every 5 minutes and only above 100 ms" | `server-settings.txt` lines 387 to 395 (`RecordUpdateTimeDiffInterval = 60000`, `MinRecordUpdateTimeDiff = 0`, `Appender.Timing`, `Logger.time.update`) |
| Windows counters | `Core\Logs\perf\perf-<date>_<time>.csv` | every 5 s: per-core CPU, processor queue, memory, paging, disk latency, world server and MySQL CPU and memory; one file per start, kept 14 days | `patch-night/PatchNight.ps1` from line 577 (`typeperf.exe`) |
| Console history | `Core\Logs\console-history.txt` | once: every start banner and slow-update line from `world-console.log`, "to compare update times before and after the 19 Nov core update" | `patch-night/PatchNight.ps1` from line 172 |
| Slow queries | `Core\Logs\mysql-slow.log` | every query over 0.5 s | `sql/enchants/095-slow-query-log.sql` |

- **Status:** recording. A first reading was taken on 22 Nov (one day, one player: `wildcard-lag-spike-campaign/references/evidence-2026-11-22.md`); nothing is written back into the repository's own docs as of 2026-11-22.
  The 22 Nov `Timing.log` was 114 KB for 7.6 hours, so about 360 KB a day, not the comment's "about 100 KB".
- **Lesson:** this is the second slow-query log. The first (F-04, over 1 s, 8 Nov) was deleted once it had found
  its answer; this one is set with `SET PERSIST`, so it stays on until someone runs
  `SET PERSIST slow_query_log = OFF;`.

---

## Things that add load and were never measured

History records these changes with no tick measurement before or after. They are listed so that nobody assumes
they were ruled in or out.

| Date | Change | Evidence | What the commit says about cost |
|---|---|---|---|
| 8 Nov | More bot world PvP (35% High Risk, 55% War Mode, 10% PvE) | `214e02d`, PR #94 | nothing |
| 8 Nov | AI chat livelier "to make up for fewer awake bots" | `a377eb2`, PR #94 | nothing |
| 13 Nov | Random bots travel in groups | `5976987`, PR #132 | "Groups of bots away from real players still sleep like other bots, so this costs no extra CPU" (stated, not measured) |
| 13 Nov | Every random bot flagged for PvP | `78eb686`, PR #133 | nothing |
| 19 Nov | Core update to release .114, with SQUID 3.0 and mod-dungeon-clear | `01159e2`, PR #187 | nothing; `PatchNight.ps1:173` wants update times compared across it |
| 21 Nov | Auction House bot stock tripled to 12,000 per house | `7949d1d`, PR #223 | nothing |

## Client-side freezes that are not server lag

These felt like lag to a player and were not the world update. Check them before blaming the server.

| Date | Symptom | Root cause | Evidence | Status |
|---|---|---|---|---|
| 21 Nov | Opening the enchant collection window froze the game | the addon "looked up all 6,440 enchants' names and info and sorted them" on every query | `4fdb6a0`, PR #224 | fixed (addon) |
| 21 Nov | Damage meter shows nothing | "A known 3.3.5 client bug: with many units around ... the combat log gets stuck" | `447b561`, PR #221 | worked around (addon clears the log) |
| 7 Nov | Launcher window "Not responding" on first check | it read all 43 GB to verify files | `d025dc7`, PR #71 | fixed |

## Contradictions in the record

- **VM size.** `docs/performance.md` says "8 vCPUs of the i9-9900K host, 18 GB". The `MapUpdate.Threads` comment
  in `server-settings.txt` (from `61a5be9`, 8 Nov) says "with the VM at 10 cores (was 4 on 8 cores)". Both are in
  the repository today. Settled on 22 Nov: the perf CSV from the VM shows 10 logical processors, so the settings
  comment is right and `docs/performance.md` is stale.
- **`docs/performance.md` is frozen at 7 Nov.** It says "Settled on 1,250" and lists `BotActiveAlone` as "now 15".
  Neither is true on 22 Nov (750 and 5). Trust `server-settings.txt` for current values.
