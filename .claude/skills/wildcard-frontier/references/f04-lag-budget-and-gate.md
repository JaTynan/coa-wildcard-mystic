# F4. Lag: a performance budget and a regression gate

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by
James)**.
Facts were checked on 2026-11-22 from the repository and, where marked "(22 Nov logs)", from a read-only copy of
the VM's logs of that day (one day, one player).
Classify every step with `wildcard-change-control` first.

**The live hunt for the current spikes is `wildcard-lag-spike-campaign`.** This file is about what comes after:
a written number for "not laggy", checked automatically after every patch night, so lag stays fixed and a change
that brings it back is caught the next morning.

## 1. Goal and owner

Turn "the server feels laggy" into a budget in milliseconds that every night either passes or fails, and know how
many bots and players the machine can carry. Owner: James, priority 1.

## 2. Where the project stands

| Fact | Date | Source |
|---|---|---|
| The measure is the world update time ("tick"). "95% under about 50 ms is smooth; 100 ms and up feels laggy" | 7 Nov | `docs/performance.md` |
| Measured: 1,000 bots on 4 map threads: 95% under 39 ms, peak 58 ms; 1,250 bots: 64 ms, peak 112; 1,500: 66 ms, peak 301 | 7 Nov | `docs/performance.md` table |
| Finding: memory is not the limit; one busy thread per map is (most bots are on two continents) | 7 Nov | `docs/performance.md` |
| Console logging on the game loop: 99th percentile tick 586 ms, worst 2.9 s, console log 2.9 GB. Logging changed by settings: shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run yet; status OPEN | 20 Nov | commit f9dc45a, PR #204 |
| James still sees worst ticks of 2 to 5 seconds with 2 players on (median 36 ms); bots cut from 1,000 to 750 while the cause is found | 21 Nov | commit 6a3e017, PR #217 |
| Measuring added: `Logs\Timing.log` once a minute, Windows counters every 5 s in `Logs\perf`, MySQL queries over 0.5 s in `Logs\mysql-slow.log`, old console lines in `Logs\console-history.txt` | 21 Nov | commit 9ba9f45, PR #225 |
| The character list took 40 s; an index made it under 1 s | 8 Nov | PR #84; `EnsureCharacterSpellIndexes` in `PatchNight.ps1` |
| A branch that lowers view distance from 100 to 75 yards is unmerged | 8 Nov | `origin/perf-visibility-react`, commit 0cd1413 |
| SmartScale puts far bots to sleep above 50 ms and is fully paused at 200 ms | 7 Nov | `docs/performance.md` "Levers for later" |

What `Timing.log` holds (from the pinned core, `src/server/game/Time/UpdateTime.cpp`): once per
`RecordUpdateTimeDiffInterval` (set to 60000 ms) a block of lines: "Update time diff: Nms with N players online",
"Last 500 diffs summary:", "Mean", "Median", "Percentiles (95, 99, max): a, b, c".

## 3. Why the current approach falls short

- **There is no pass/fail.** The numbers are read by a person when lag is felt. Nothing compares last night with
  the night before. A change that adds 20 ms to every tick would go unnoticed until someone complained.
- **The record has a blind spot.** Each minute's block summarises only the newest **500** passes of the game loop
  (`AVG_DIFF_COUNT = 500`). With a player on (22 Nov logs: about 21 passes a second) that is the last 20 to 28
  seconds of the minute, about 40%; with the world empty about 2 seconds. A 2-second spike in the rest of the
  minute is in no block. The `Logs\perf` counters (every 5 s) and the console's own
  slow-update lines cover part of the gap, but there is no complete record of every slow tick.
- **Load is not controlled.** A quiet night with 2 players and a Saturday with 6 in three zones are different
  tests. The worst case named in `docs/performance.md` (players spread over many zones, each full of awake bots)
  has never been measured.
- **No capacity model.** The bot count was tried at 1,000, 1,500 and 1,250 on 7 Nov, was 1,000 by 21 Nov and is
  750 since, each move made by feel or after an incident. Nobody can say
  "this machine carries N awake bots at 50 ms".
- **"Players online" counts real players only** (22 Nov logs: 0 or 1 all day with 750 bots configured). The
  number of bots awake is logged nowhere.
- **An empty server proves nothing.** `AiPlayerbot.DisabledWithoutRealPlayer = 1` (`server-settings.txt:479`, set
  since 30 Oct) logs every bot out when no real player is on. On 22 Nov the 340 records with nobody on had a
  median tick of 2 ms and a worst of 534 ms. Any verdict taken over such records passes whatever was merged.

## 4. This project's asset

- **750 bots are a free load generator, but only while a real player is online** (`DisabledWithoutRealPlayer = 1`:
  bots log in 30 s after the first player and out 5 minutes after the last). The settings that wake or sleep them
  (`AiPlayerbot.MinRandomBots`, `BotActiveAlone`, SmartScale) are one-line changes applied at a restart, each
  reversible the next night.
- **`Timing.log` is appended across restarts** (about 360 KB a day measured on 22 Nov; the settings comment says 100 KB), so before/after comparisons need no setup.
- **Every change is dated in git**, so a step in the numbers can be matched to the merges of that day.
- **A restart every night at the same time** gives a natural experiment boundary: one night, one configuration.
- **A tested gate exists**: `spike_gates.py metric` in `wildcard-lag-spike-campaign` (run on the real 22 Nov
  `Timing.log`: 457 complete records). It filters by players online (`--min-players`), by evening hours, needs a
  minimum number of records, and prints the coverage. This skill's own prototype was a duplicate without those
  filters and was removed on 2026-11-22.

## 5. First three steps in this repo

### Step 1. Adopt (or amend) one budget, in writing

- The numbers are **not** set here. The library's single home for lag pass/fail numbers is the proposed exit
  metric in `wildcard-lag-spike-campaign` (Phase 1 step 5), judged by
  `.claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py metric`. Step 1 is: James adopts that metric
  or amends it, and the adopted text goes into `docs/performance.md` as a section "Budget", with the evenings it
  was taken from. Do not invent a target the server has never met.
- **Judge only records with at least one real player online** (`--min-players 1` or more), require a minimum
  number of such records per evening (the tool's default is 30), and say in the section that **a night with nobody
  on gives no verdict**.
- State the blind spot in the same section (the tool prints the coverage).
- **Class estimate:** LOW (a documentation section; nothing on the server changes).

### Step 2. A verdict line for every evening that had players

- In `patch-night/PatchNight.ps1`, just before the server is stopped, run the tool over the previous evening and
  log one line: `Tick budget, last evening: PASS|FAIL|NO DATA (...)`. Add it to `last-run.txt`. A check straight
  after the 4:00 am start is no use for this: the world is empty then (bots logged out) and would always pass.
- Needs Python on the VM; the server's own `Runtime\python\python.exe` is already used by patch night.
- Add the line to `docs/agents/context/patch-night.md` so the checker agent reports a FAIL.
- **Class:** hard stop 5 (patch night). HIGH, James merges. Report only: a FAIL changes nothing by itself.

### Step 3. A capacity curve, measured on purpose

- Only after the spike campaign is closed (otherwise the two confound each other). On four nights, set
  `AiPlayerbot.MinRandomBots` / `MaxRandomBots` to 500, 750, 1,000, 1,250 (one value per night, nothing else
  merged that night), and record each evening's budget line. Only evenings with a real player on count (with
  nobody on there are no bots to measure); the awake-bot count is logged nowhere today, so record the configured
  count and who played.
- Write the table and a fitted "ms per 100 awake bots" into `docs/performance.md`, with the date and the build.
- One extra night for the named worst case: James and two friends logged in on three continents.
- **Class estimate:** not a standard change. The bot-count comment states no range (2026-11-22), so each night is
  scored with `wildcard-change-control` (it runs for everyone: impact check I1 can be 3); James merges. Tell the
  players. The campaign's bot ladder (its Phase 4) is the adopted route for raising bots once it exists.

## 6. Milestone

**You have a result when** 14 evenings **with players on** each have an automatic PASS or FAIL line against the
written budget in `patch-night.log` (evenings with nobody on print NO DATA and do not count), at least 12 of the
14 are PASS, and **one planted regression** (a night with a setting
deliberately made worse, for example bots back to 1,250) is reported FAIL the next morning without anyone looking.

It is falsified if the planted regression passes (the budget is too loose or the blind spot hides it), or if
healthy nights fail more than 2 in 14 (the budget is tighter than the machine can meet: fix the cause or the
number, and write down which).

## 7. Known wrong paths and risks

- **Averages.** The mean hides spikes; the complaint is about spikes. Budget the percentiles and the worst pass.
- **Ticks per second, or any verdict, on an empty server.** It spins at about 250 with nobody on
  (`docs/performance.md`); the bots are logged out then.
- **Declaring the spikes fixed because the gate passes.** With the blind spot, PASS means "no sampled minute broke
  the budget". The blind spot shrinks with a settings value (`RecordUpdateTimeDiffInterval` shorter than 500 x the
  mean tick: `wildcard-diagnostics-and-tooling` candidate C1 and the campaign's Phase 1 step 4; score it, the
  comment states no range). A complete per-tick log would be C++ on the hottest path (likelihood check L3 = 3):
  not without James.
- **Comparing nights with different players.** Record how many real players were on; compare like with like.
- **Two changes in one night.** Then a FAIL cannot be assigned. This is where many merges a day hurts most.
- **Tuning bots down until it passes.** Lively zones are the point of the bots. Record the bot count beside every
  verdict so a PASS bought by fewer bots is visible.
- **Load testing while friends play**, unannounced.
- **More vCPUs as the fix.** The 7 Nov finding is one busy thread per map; more cores added little.

## 8. Dependencies

Step 1 is the campaign's own Phase 1 step 5 seen from the other side: it needs James's decision, nothing else. Step 3 must wait for it. F2's health check
and F10's "no worse" proofs use this budget. F1 step 2 (building on the VM) must be watched with it.
