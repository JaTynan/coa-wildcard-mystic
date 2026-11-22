# The engine facts the campaign rests on

Read from the pinned sources on 2026-11-22 (never built or run): core `Corfirean/azerothcore-wotlk-coa` at
`c3f2fd4b`, SQUID bots `Zyth45/mod-playerbots` v3.0 at `4ef5ed9e`, `Zyth45/mod-dungeon-clear` at `6efb59ea`,
`DustinHendrickson/mod-ollama-chat` at `906eb2a4` (the pin in `.github/workflows/build-worldserver.yml`).
File paths are relative to each repository. Re-verify after any core update: commands at the end.

## 1. One tick, in order

A **tick** is one call of `World::Update(diff)` from `WorldUpdateLoop()` (`src/server/apps/worldserver/Main.cpp`).
`diff` is the wall-clock time since the previous tick started. Everything below runs on the **world thread**, one
after another, except where marked (`src/server/game/World/World.cpp`, `World::Update`):

1. Record the tick time (`sWorldUpdateTime.UpdateWithDiff`, `RecordUpdateTime`).
2. Timers: 5-second jobs, who-list cache (5 s), daily/weekly resets.
3. `sScriptMgr->OnPlayerbotUpdate` -> SQUID `RandomPlayerbotMgr::UpdateSessions` (bot packet handling).
4. `sAuctionMgr->Update`: once a minute, expire auctions in all three houses, and the Auction House bot's cycle.
5. `sWorldSessionMgr->UpdateSessions`: real players' packets.
6. `sMapMgr->Update`: **each map is handed to a pool of `MapUpdate.Threads` threads, and the world thread waits
   until every map has finished** (`MapUpdater::wait`, `src/server/game/Maps/MapUpdater.cpp`). Players, bots,
   creatures, spells and bot AI (`OnPlayerAfterUpdate` in SQUID's `src/Script/Playerbots.cpp`) run here, as do our
   patches' `OnPlayerUpdate` hooks.
7. Battlegrounds, outdoor PvP, LFG.
8. `ProcessQueryCallbacks`: results of asynchronous database queries are handled here. **Every bot login finishes
   here**: `PlayerbotHolder::AddPlayerBot` queues a query holder (`sWorld->AddQueryHolderCallback`,
   `src/Bot/PlayerbotMgr.cpp`), and its callback builds the whole character on the world thread.
9. `sScriptMgr->OnWorldUpdate`: every module's world script. SQUID's is in `src/Script/Playerbots.cpp`:
   `sRandomPlayerbotMgr.UpdateAI(diff)` ("World thread only"), plus about twenty "CoA World" / "CoA Live" /
   economy managers, the Auction House bot hook, Dungeon Clear's probes, and mod-ollama-chat's dispatcher.

Consequences:

- The tick is as long as **the serial parts plus the slowest single map**. More map threads shorten neither.
- A tick of seconds with one CPU at 100% and the rest idle is one of: a serial part (3, 4, 5, 8, 9) or one map
  that takes that long. The Windows counters cannot tell these apart.
- A synchronous database query (`XDatabase.Query(...)`, as opposed to `Execute` or a callback) blocks its thread
  until MySQL answers. `DatabaseWorkerPool::GetFreeConnection` waits for a free synchronous connection
  (`CharacterDatabase.SynchThreads = 2` here; SQUID's `PlayerbotsDatabase.SynchThreads` default 1). The core's
  warning for such queries exists only in debug builds (`#ifdef ACORE_DEBUG` in `DatabaseWorkerPool.cpp`).

## 2. The instruments, exactly

All of these are stock features switched on by settings or scripts; none is one of our C++ patches. Formats and
parser usage live in wildcard-diagnostics-and-tooling
(`.claude/skills/wildcard-diagnostics-and-tooling/references/formats.md`).

| Instrument | Written by | What one entry is | Limits to remember |
|---|---|---|---|
| `Core\Logs\Timing.log` | world server; settings `RecordUpdateTimeDiffInterval = 60000`, `MinRecordUpdateTimeDiff = 0`, `Appender.Timing = 2,4,1,Timing.log,a`, `Logger.time.update = 4,Console Server Timing` (server-settings.txt, 21 Nov) | Five lines once a minute (`WorldUpdateTime::RecordUpdateTime`, `src/server/game/Time/UpdateTime.cpp`): the tick that crossed the minute mark and the player count, then mean, median, p95, p99 and max of the **last 500 ticks** (`AVG_DIFF_COUNT = 500`) | Covers `500 x mean` ms per record: about 1 s with the world empty (2 ms ticks), 20-28 s with a player on. On 22 Nov that was 13% of the day. "players online" is `GetActiveSessionCount()`: real players only (bots are not in that list). Lines can arrive out of order (async logging). The file is appended across restarts |
| `Core\Logs\perf\perf-YYYY-MM-DD_HHmm.csv` | `typeperf`, started by `StartDiagnostics` in `patch-night/PatchNight.ps1` after each start; counter list in `perf\counters.txt` | One row every 5 s: each logical CPU, processor queue, context switches, free memory, pages/sec, paging file, disk read/write latency, disk queue, disk idle, world server CPU / working set / threads, mysqld CPU / working set | A 2 s event is diluted in a 5 s sample. Process CPU is per core: 100 = one core. One file per start, kept 14 days. Local time, same clock as Timing.log |
| `Core\Logs\mysql-slow.log` | MySQL, `sql/enchants/095-slow-query-log.sql` (`long_query_time = 0.5`) | One block per statement over 0.5 s | Times are **UTC**. A wait for a free connection inside the world server is not a slow query. Many fast queries are invisible |
| `Core\Logs\console-history.txt` | `SaveConsoleHistory` in PatchNight.ps1, **once** | `<line number>: <text>` for every start banner, "World Initialized" and "Update time diff" line of the old console log | No timestamps. Before 21 Nov only ticks over 100 ms were logged, at most one per 5 minutes. See `evidence-2026-11-22.md` section C |
| `.server info` (in game or console), the manager's World speed panel | same `sWorldUpdateTime` | The same last-500-ticks summary, on demand | A snapshot of about 20 s |
| `Core\Logs\Errors.log`, `Server.log`, `Playerbots.log` | world server | - | No timestamps (the core's default appenders have flag 0; verified for Errors.log on 22 Nov) |

SmartScale reads the same table: `PlayerbotAI::AutoScaleActivity` (`src/Bot/PlayerbotAI.cpp`) takes the **largest**
tick of the current and previous 500-tick tables. Under 50 ms: no change. Over 200 ms: the share of far-away bots
kept awake (`BotActiveAlone`, 5%) drops to 0 until the tables roll over. So after every long tick the far world
sleeps for up to about 1,000 ticks. It only ever affects that 5%; bots in a player's zone are not scaled.

## 3. Timers: what runs how often

Use this table when a period shows up. "Thread" is where the work runs. "Setting" says whether it is in
`server-settings/server-settings.txt` today.

| Period | What | Thread | Source | Setting (value) |
|---|---|---|---|---|
| every tick | bot AI, our 17 `OnPlayerUpdate` hooks, Dungeon Clear's two `OnPlayerAfterUpdate` hooks | map | SQUID `Playerbots.cpp`; `patches/`; `DungeonClearModule.cpp` | - |
| 2 s per character | patches 82 and 86 scan bags (bots included); patch 73 rechecks Spellsword | map | `patches/82-*`, `86-*`, `73-*` | none (always on) |
| 3 s | MySQL writes its log to disk | MySQL | `sql/enchants/090-mysql-tuning.sql` | `innodb_flush_log_at_timeout = 3` |
| 4.5-5 s per bot | bot re-decides awake/asleep (`PlayerbotAI::AllowActivity`) | map | `PlayerbotAI.cpp` | - |
| 5 s | who-list cache, expired-ban cleanup | world | `World.cpp` | - |
| **10 s** | random bot manager cycle while fewer than 90% of `MinRandomBots` are online (logging in) | world | `RandomPlayerbotMgr::UpdateAIInternal`: `SetNextCheckDelay(interval * (focus + 25) * 10)`, focus 25 | `AiPlayerbot.RandomBotUpdateInterval` not in the file (default 20) |
| **20 s** | random bot manager cycle at full count: up to 45 bots get their periodic update (revive, re-randomise, teleport), up to 15 log in | world | same, focus 75; `RandomBotsPerInterval` default 60 | not in the file |
| **20 s** | CoA Live channel timers: walks every player, picks bots to talk in General/Trade/LFG/guild, only where real players are | world | SQUID `src/Ai/Coa/Social/CoaLive.cpp`, `CHANNEL_TICK_MS = 20000` (a constant) | `AiPlayerbot.CoaLive.Enable` not in the file (default 1) |
| 0.5-1 s | the same manager cycle during the first `MaxRandomBots x 0.51` s after a server start (383 s at 750) | world | `_isBotInitializing` | - |
| 30 s after first player | bots start logging in (`DisabledWithoutRealPlayerLoginDelay`) | world | `playerbots.conf.dist` | `AiPlayerbot.DisabledWithoutRealPlayer = 1` is set |
| 30 s | Ollama chat maintenance; bug-report relay poll (separate process) | world / other | `mod-ollama-chat_random.cpp`; `signup/WildcardSignup.py` | - |
| 10-35 s | a bot starts an AI chat line (HTTP runs on 4 worker threads, not the world thread) | worker | `mod-ollama-chat_dispatch.cpp` | `OllamaChat.MinRandomInterval = 10`, `Max = 35` |
| **60 s** | auction expiry in 3 houses + Auction House bot: sell cycle (up to `ItemsPerCycle` new listings) and buy cycle with a synchronous `SELECT ... FROM auctionhouse` over every listing | world | `AuctionHouseMgr.cpp` (`_updateIntervalTimer`), `modules/mod-ah-bot-plus/src/AuctionHouseBot.cpp` | `AuctionHouseBot.ItemsPerCycle = 600`, 12,000 listings x 3 houses, `Buyer.Enabled = true` |
| 60 s | Timing.log record; Dungeon Clear ghost probe; status page's `server info` (only while someone views it) | world | - | `RecordUpdateTimeDiffInterval = 60000` |
| 60-300 s per bot | each bot's "update" comes due again (`MinRandomBotReviveTime`-`Max`) | world | `ProcessBot` | not in the file |
| 300 s | "Random Bots Stats" printed (walks all bots) | world | `RandomBotPrintStatsInterval` | not in the file |
| 300 s after last player | **all bots log out in one go** (`LogoutAllBots`; from the code, not observed: the 22 Nov log ends before the player left) | world | `DisabledWithoutRealPlayerLogoutDelay` | - |
| 600 s | Ollama chat saves history, memory, sentiment; simulated dungeon run per faction; weather | world | conf.dist files | `ChangeWeatherInterval` default |
| 600-2,400 s per bot | bot teleports to a new area (750 bots: about 10 per 20 s cycle) | world | `MinRandomBotTeleportInterval` / `Max` | not in the file |
| 900 s per character | autosave (`PlayerSaveInterval`, first one 7.5-22.5 min after login; bots too unless `RandomBotSaveInterval` is raised) | map, then DB threads | `PlayerUpdates.cpp`, `PlayerStorage.cpp` | not in the file |
| 45-240 min | CoA World events: skirmishes (45-90), resource rushes (60-120), invasions (120-240) | world | `playerbots.conf.dist` `AiPlayerbot.CoaWorld.*` | not in the file |
| 04:00 daily | nightly restart (countdown from 03:30) | - | `patch-night/Register-PatchNight.ps1` | - |
| Tuesday 23:00 | weekly patch night (the script's default; what is registered on the VM is UNVERIFIED) | - | same | - |

Settings named in many AzerothCore guides that do **not** exist in this core's
`worldserver.conf.dist`: `GridUnload`, `GridCleanUpDelay`. `MaxCoreStuckTime` exists (default 0 = off) and would
**crash** the server on a long freeze: do not use it as a diagnostic.

## 4. Instruments that exist in the sources but are off

| Instrument | What it gives | Cost / catch | Status here |
|---|---|---|---|
| `AiPlayerbot.PerfMonEnabled = 1` + console/GM command `playerbots pmon` | SQUID's own timer table per named operation, including `RandomPlayerbotMgr::UpdateAIInternal`, `RandomPlayerbotMgr::Login`, `RandomPlayerbotMgr::FullTick` (`src/Bot/Debug/PerfMonitor.cpp`) | Some overhead while on; output goes to the `playerbots` logger; a console command is James's to run | UNVERIFIED on this VM |
| `Metric.Enable = 1` (+ an InfluxDB to receive it) | The core already times every phase of `World::Update` (`METRIC_TIMER("world_update_time", type=...)`) and every map (`map_update_time_diff` by map id) | Needs an InfluxDB reachable from the VM; none is set up | NOT BUILT YET |
| `RecordUpdateTimeDiffInterval` shorter than `500 x mean tick` | Timing.log with no blind time | About four times the log lines at 15000 | Proposed practice (not yet adopted by James), Phase 1 |
| Timestamps on `Server.log` / `Playerbots.log` (appender flag 1) | Bot logins, logouts, "Random Bots Stats" lined up with Timing.log | Setting change to two appenders | Proposed practice (not yet adopted by James), Phase 5 |

## Re-verify (run in the repository; clones under `/tmp` or any scratch folder)

```
python3 -I scripts/resolve_release.py latest                      # the pinned commits
git clone --filter=blob:none https://github.com/Corfirean/azerothcore-wotlk-coa core && git -C core checkout <core_sha>
git clone --filter=blob:none https://github.com/Zyth45/mod-playerbots squid && git -C squid checkout <squid_sha>
grep -n "AVG_DIFF_COUNT" core/src/server/game/Time/UpdateTime.h
grep -n "RecordUpdateTimeDiffInterval\|MinRecordUpdateTimeDiff\|^PlayerSaveInterval\|^MaxCoreStuckTime\|^MapUpdate.Threads\|^Log.Async.Enable\|^Metric.Enable" core/src/server/apps/worldserver/worldserver.conf.dist
grep -n "SetNextCheckDelay" squid/src/Bot/RandomPlayerbotMgr.cpp
grep -n "RandomBotUpdateInterval\|RandomBotsPerInterval\|RandomBotPrintStatsInterval\|MinRandomBotTeleportInterval\|PerfMonEnabled\|CoaLive.Enable =" squid/conf/playerbots.conf.dist
grep -n "CHANNEL_TICK_MS =" squid/src/Ai/Coa/Social/CoaLive.cpp
grep -n "GetMaxUpdateTimeOfCurrentTable" squid/src/Bot/PlayerbotAI.cpp
grep -n "_updateIntervalTimer.SetInterval" core/src/server/game/AuctionHouse/AuctionHouseMgr.cpp
grep -c "void OnPlayerUpdate(Player" patches/*.ps1 patches/*.patch | grep -v ":0"
```
