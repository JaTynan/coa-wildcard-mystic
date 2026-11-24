# Lag: the evidence timeline (7 to 22 Nov 2026)

Everything the repository records about world-server speed, in date order, with the source of each number.
All times are Sydney. "Tick" = one pass of the world server's game loop; the manager's "World speed" panel and
`.server info` report its length in milliseconds.

**Status of this file:** built from git on 2026-11-22. Sections 1-3 hold what the repository records: numbers
James or a session wrote into commit messages and settings comments at the time, with the conditions around each
(who was on, where, how long after a restart) mostly not recorded. The first day of instrument data (22 Nov) is
analysed separately in `evidence-2026-11-22.md`; where it corrects this file, the correction is marked
"(22 Nov logs)".

## 1. Measurements, in order

| Date | Bots | Core / SQUID | Map threads | Players | 95% under | 99% | Worst | Other | Source |
|---|---|---|---|---|---|---|---|---|---|
| 7 Nov | 1,000 | .95 era / 2.9.4 | 1 | not recorded | 61 ms | - | 489 ms | 33 ticks/s, avg 30 ms, ~10 GB; "one core busy while the other seven idled (21% CPU)" | `docs/performance.md`; settings comment at `MapUpdate.Threads` |
| 7 Nov | 1,000 | same | 4 | not recorded | 39 ms | - | 58 ms | 50 ticks/s, avg 20 ms | `docs/performance.md` |
| 7 Nov | 1,500 | same | 4 | not recorded | 66 ms | - | 301 ms | 26 ticks/s, avg 38 ms, 8.9 GB | `docs/performance.md`, commit aca9022 |
| 7 Nov | 1,250 | same | 4 | not recorded | 64 ms | - | 112 ms | 30 ticks/s, avg 33 ms | `docs/performance.md` |
| 8 Nov | 1,250 | same | 4 then 6 | 2, in different zones | 62-72 ms | - | 485 ms | each zone woke all its bots | commit e608f61 (settings comment) |
| 9 Nov | 1,250 | same | 6 | 3 | 74 ms | 147 ms | **1.3 s** | led to 1,000 bots | commit ff00757 (settings comment) |
| 20 Nov | ~880 in world (setting 1,000) | .114 / 3.0 | 6 | not recorded | 69 ms | 586 ms | **2.9 s** | world-console.log 2.9 GB | commit f9dc45a |
| 21 Nov (which side of that day's cut to 750 is not recorded) | 1,000 or 750 (not recorded) | .114 / 3.0 | 6 | 2 | - | - | **2-5 s** | median 36 ms | commit 6a3e017 (James) |

Read the table honestly:

- **Spikes over a second existed before the 19 Nov core update** (9 Nov, 1.3 s, older core and SQUID 2.9.4). The
  19 Nov update can have made them worse; it did not create them.
- Worst ticks were 1.3 s (3 players, read around the cut from 1,250 to 1,000 on 9 Nov) and 2 to 5 s (2 players,
  read around the cut from 1,000 to 750 on 21 Nov); the record does not say which side of each cut the reading
  was taken on, so no conclusion about bot count follows from these readings.
- The median stayed healthy throughout (36 ms on 21 Nov). The problem is rare long ticks, not general slowness.
- Three rows are single observations taken from the manager or `.server info`, which show only the last 500 ticks
  (see `engine-and-timers.md`). None of them is a rate ("spikes per hour").

## 2. Every performance change, in order

| Date (merge) | PR / commit | Change | Stated reason or result |
|---|---|---|---|
| 7 Nov | #49 70f055b | `MapUpdate.Threads = 4` (was 1) | 1,000 bots kept one core busy; 33 -> 50 ticks/s |
| 7 Nov | #53 2ce36a4 | Bots 1,000 -> 1,500 | trial |
| 7 Nov | #57 aca9022 | Bots 1,500 -> 1,250 | 1,500: 26 ticks/s, 95% 66 ms, peaks 300 ms |
| 7 Nov | #58 4ce450e, 35c8e95 | `docs/performance.md` written | not updated since: it still says "settled on 1,250" and `BotActiveAlone` "now 15" |
| 7 Nov | #59 240d773 | `AiPlayerbot.BotActiveAlone = 5` (was 15) | far world sleeps |
| 7 Nov | #67 | Respawns: `Respawn.DynamicRateCreature = 0.3`, minimum 60 s then 90 s (8 Nov), objects 120 s | gameplay, but more live mobs for bots to fight |
| 8 Nov | #75 0cce098 | `CharacterDatabase.WorkerThreads = 4`, `.SynchThreads = 2`, `LoginDatabase.WorkerThreads = 2` | players queued behind bot logins and saves |
| 8 Nov | #77 61a5be9, a55aaea | `sql/enchants/090-mysql-tuning.sql`: buffer pool 4 GB, redo log 1 GB, `innodb_flush_log_at_trx_commit = 2`, flush every 3 s, log buffer 64 MB, performance_schema off; `MapUpdate.Threads = 6` "with the VM at 10 cores" | no measurement recorded |
| 8 Nov | #82, #84, #86 | Temporary slow-query log (over 1 s) -> found the cause of the 40-second character list -> index on `character_spell.spell` and `character_talent.spell` (PatchNight.ps1 `EnsureCharacterSpellIndexes`) -> log removed | 40 s -> under 1 s. **Closed.** |
| 8 Nov | #88 e608f61 | Wake radius: `BotActiveAloneForceWhenInZone = 0`, `...ForceWhenInRadius = 300` | 2 players in 2 zones: 95% 62-72 ms, spikes to 485 |
| 8 Nov | #95 c02ba12 | Zone waking back **on** (radius 300 kept) | with the radius alone, bots near players froze for 20+ minutes; cause not found |
| 8 Nov | a377eb2 | AI chat livelier (10-35 s, 5 per player) | to offset fewer awake bots |
| 9 Nov | #111 7001de0, ff00757 | View distance 150 tried in settings, back to 100 before going live; bots 1,250 -> 1,000 | 3 players: 95% 74 ms, 99% 147 ms, worst 1.3 s |
| 11 Nov | (settings) | Auction House bot stock 4,000 per house | - |
| 13 Nov | #133 78eb686 | Every bot flagged for PvP; bots travel in groups (50/30/15/5) | "costs no extra CPU" was the expectation, not measured |
| 20 Nov | #204 f9dc45a | `Log.Async.Enable = 1`; `Logger.coa = 4,Server`; `Logger.module.coa_challenges = 3,Console Server` | the commit's reason: console logging ran inside the tick; 99% 586 ms, worst 2.9 s. Changed by settings; **effect never measured; status OPEN** (the spikes continued, next row; `world-console.log` was 2.99 GB on 22 Nov) |
| 21 Nov | #217 6a3e017 | Bots 1,000 -> 750 | 2 players, median 36 ms, worst 2-5 s |
| 21 Nov | #223 7949d1d | Auction House bot stock 4,000 -> 12,000 per house, `ItemsPerCycle = 600` | "if searches start to lag, lower this first" |
| 21 Nov | #225 9ba9f45 | **Diagnostics, measuring only**: Timing.log every 60 s, Windows counters every 5 s, console-history.txt, MySQL slow log over 0.5 s (`095-slow-query-log.sql`) | "Nothing changes how the server runs." |
| 22 Nov (merged 08:59, after that day's 08:53 start: **first live at the next restart**) | #229 | Staged patch night: only the world server restarts; console logs dated per run, newest 3 kept | downtime; the one-off `console-history.txt` extraction now runs from `RotateConsoleLogs` before the old log is cleared |
| 22 Nov (merged 09:21: **first live at the next restart**) | #230 6223bc8 | `MoveMaps.Bots.MaxSlope = 50`, `Respawn.QuestTarget.General = 180`, `Who.ShowBots = 0`, `DungeonFinder.MaxExpansion = 0` | gameplay; the first changes the bots' pathfinding filter, the second adds respawns |

Never merged: branch `perf-visibility-react` (0cd1413, 8 Nov) would set `Visibility.Distance.Continents = 75`
("less movement traffic in bot-crowded cities"). Untested; a candidate lever, not a finding.

## 3. What changed in the window the spikes got worse (15 to 22 Nov)

The commit that added the diagnostics says they exist "to compare update times before and after the 19 Nov core
update". These are all the things that changed around then. They overlap, which is why "it was the core update"
cannot be read off the calendar.

### Upstream (from `python3 -I scripts/resolve_release.py <tag>`)

| Release | Core commit | SQUID bots | Our first build tag (commit date) |
|---|---|---|---|
| server-0.261108.95 | 85ecc212 | **v2.9.4** (75d1784f) | builds 21-53, 8-18 Nov |
| server-0.261115.110 | 9740ced5 | **v3.0** (4ef5ed9e) | build44, 15 Nov |
| server-0.261116.112 | 30003e18 | v3.0 | build52 17 Nov, build55 19 Nov |
| server-0.261119.114 | c3f2fd4b | v3.0 | build57 19 Nov (did not start), build61/62 19 Nov, build68 21 Nov, build70 21 Nov |

- By release list, SQUID went **2.9.4 -> 3.0** with release .110. **On this VM .110 and .112 never ran** (22 Nov
  logs: `console-history.txt` holds start banners for five core revisions only, the last two being `85ecc2122efd`
  (.95) and `c3f2fd4b2395` (.114)). So here the new core, SQUID 3.0 and Dungeon Clear all arrived in one step, and
  the calendar cannot separate them. SQUID 3.0 brings a "living world" layer (`AiPlayerbot.CoaWorld.*`: invasions,
  resource rushes, simulated dungeon runs, world PvP skirmishes, capital raids, guild life) and a social layer
  (`AiPlayerbot.CoaLive.*`), most of it on by default in its `playerbots.conf.dist`.
- .114 added **Dungeon Clear** (`mod-dungeon-clear`, 6efb59ea) to the build; we turned it on the same evening
  (`DungeonClear.Enable = 1`, ce4780b, 19 Nov 10:57 pm).
- **Which build was live on which evening is not in the repository.** It is in
  `C:\Games\CoA Server\patch-night\patch-night.log` ("Server is up on core ...", "Patched build available: ...").
  Until 23 Nov builds were installed only by the weekly run (Tuesday 11 pm by the script's default; 17 Nov was a
  Tuesday) or by `Run-PatchNight-Now.cmd`; since 23 Nov every 3:30 am run installs (PR #240).
- **VM size:** `docs/performance.md` says 8 vCPUs; the settings comment of 8 Nov says "the VM at 10 cores"; the
  22 Nov counter file has columns `Processor(0)` to `Processor(9)`: **10 logical processors**.

### Our own patches added 17-21 Nov (file add dates from git)

| Added | Patch | Runs when |
|---|---|---|
| 17 Nov | 68 aspect-of-the-fox, 69 iron-guard, 70 mastery-of-the-tide, 71 jump-multiplier | on specific spell events |
| 18 Nov | 72 grave-defiance, 73 spellsword, 74 overclock, 75 arcane-hunger, 76 prospectors-spirit | **every player update** (`OnPlayerUpdate`), race check first |
| 19 Nov | 77 resting-mana-regen | every mana regen update |
| 19 Nov | 78 worldforged-enchants | `OnPlayerUpdate` (cheap flag check) and every kill |
| 19 Nov | 79 mystic-enchant-gold-cost | on enchant purchase |
| 20 Nov | 80 racial-status-command, 81 chat-channel-guard, 83 stored-pet, 84 treasure-keeper, 85 empty-system-mail | on command / event |
| 20 Nov | **82 runes-in-currency-tab**, **86 scrolls-of-fortune-redeem** | **every player, every 2 s** (bag scan), bots included |
| 21 Nov | 87 bots-revive-pets, 92 bots-hand-in-at-wisdomball, 96 bots-ignore-commands | bot AI (96: merged 21 Nov 23:23 as #228, in **no build** as of 22 Nov, so not running) |
| 21 Nov | 88 lfg-refusal-log, 94 lfg-join-limit, 95 dungeons-scale-up, 89 stoneform, 91 weekly-mystic-scrolls, 93 group-xp | on event |
| 21 Nov | 90 dungeon-clear-auto-start | `OnPlayerUpdate`, real players only (bots return early) |

Seventeen of our patches hook `OnPlayerUpdate` in total (list them: `grep -l "void OnPlayerUpdate(Player" patches/*`).
The hook runs for bots too, on the map threads. Most return after one race comparison.

### Settings changed 19-22 Nov that touch load

`DungeonClear.Enable = 1` (19 Nov), `DungeonClear.SmartRest*` and `DungeonClear.AutoStart = 1` (21 Nov),
`Wildcard.RestingManaRate = 3`, `Wildcard.WorldforgedDropChance = 1` (19 Nov), the three logging lines (20 Nov),
bots 750 (21 Nov), Auction House stock 12,000 x 3 houses (21 Nov), the four diagnostics lines (21 Nov), the four
core options of 22 Nov.

### What this means for any before/after comparison

Between James's 2-5 s observation (21 Nov afternoon) and the first night of diagnostics data, at least five things
changed: bot count, auction stock, the installed build (68 -> 70, if it was installed), the diagnostics settings
themselves, and (merged 22 Nov, live from the next restart) the staged restart and four core options. **There is
no clean "before" in Timing.log.**

**What was live in the 22 Nov data:** that day's only start was at 08:53-08:56 (first slow-log entry 08:53:58,
first Timing record 08:56:00). #229, #230 and #231 merged at 08:59, 09:21 and 15:43, after it. So the 22 Nov
readings were taken with settings as on `main` before the 08:53 start (at most #228): no staged restart, no
console-log rotation, none of #230's four core options. The first evening after the next restart is a **new
baseline**; it differs from 22 Nov by #229-#231 as well as by any experiment. Record the conditions with the
data (Phase 1).
