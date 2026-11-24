---
name: wildcard-lag-spike-campaign
description: Decision-gated campaign for the Wildcard world server's lag spikes, the owner's first priority (long game-loop ticks of 0.3 to 5 seconds; root cause unknown as of 22 Nov 2026). Holds what the first day of instrument data showed (a 20-second beat in the world server's CPU only while a player is online; a separate bot-login ramp), the ranked hypotheses with one experiment and written prediction each, branches ruled out, wrong paths already tried, the proposed exit metric (its single home), the bot ladder, and spike_gates.py, which runs each gate on Timing.log and the Windows counter CSV. Load it FIRST when someone says "the server is lagging", "rubber-banding", "it stutters" or "it froze for a few seconds"; when asked "why does it lag", "can bots go back up" or "what next for performance"; and before changing any bot, map-thread, auction-bot, database or logging setting for performance reasons. It uses the log parsers in wildcard-diagnostics-and-tooling. Not for a crash or a server that will not start.
---

# Lag spike campaign

**State of knowledge, as of 2026-11-22.** The root cause is **UNKNOWN**. The diagnostics merged on 21 Nov
(#225, commit 9ba9f45) have produced **one day** of data (22 Nov, 08:56-16:32, **one** real player from 14:36).
That day shows a clear pattern, summarised below, and a leading hypothesis that has **not** been tested by any
experiment. Treat everything here as a plan to find the cause, not as the cause.

Status words used here: DOCTRINE (written in README, CHANGES.md or docs on `main`), DOCTRINE (PR #232, merged 22 Nov 2026), PRACTICE (what history shows), NOT BUILT YET, Proposed practice (not yet adopted by James), UNVERIFIED,
OPEN. The hard stops, the risk matrix and "standard changes" cited below come from
`docs/agents/context/change-risk.md`, which is **DOCTRINE (PR #232, merged 22 Nov 2026)**: the file
is not on `main` yet (read it with `git show origin/main:docs/agents/context/change-risk.md`).

## When NOT to use this skill

| You want | Use instead |
|---|---|
| How to read a log, what a file contains, the parser scripts | wildcard-diagnostics-and-tooling |
| A crash, a server that will not start, a failed patch night, a build failure | wildcard-debugging-playbook, wildcard-run-and-operate, wildcard-build-and-env |
| Risk class, who merges, hard stops | wildcard-change-control |
| What counts as proof in general, the evidence ladder, the other acceptance checks | wildcard-validation-and-qa (the lag pass/fail numbers themselves live here, Phase 1 step 5) |
| Adding or looking up a setting | wildcard-settings-and-flags |
| Writing or pre-flighting a patch | wildcard-patch-authoring |
| How the world update loop and bots work in general | azerothcore-coa-reference |
| The method behind "predict before running", evidence bars | wildcard-analysis-and-method |
| The story of past incidents | wildcard-failure-archaeology |
| A client that stutters (low frame rate) while the server's ticks are fine, or one slow addon window | wildcard-client-and-web |

## Start here

1. Read "What one day of data shows" below (two minutes). Do not propose a cause from memory.
2. Get the day's logs and run Phase 1 step 3 (four commands).
3. Walk Gates A to D in Phase 2 with the output.
4. The next experiment is in the Phase 3 table (E1 as of 2026-11-22). Write its prediction down first.
5. Any change at all: classify with wildcard-change-control first; James merges.

Words used: a **tick** is one pass of the world server's game loop; players feel long ticks as freezes and
rubber-banding. A **record** is one five-line entry in `Timing.log`; its **window** is the last 500 ticks it
summarises. A **beat** is a repeating pattern in the counters. **Bots** are SQUID's Playerbots (750 configured).
The **login ramp** is the stretch after the first real player arrives while the bots log in (22 Nov: 14:36 to
about 15:00); the **steady state** is what follows. **H1 to H8** are the numbered hypotheses in
`references/hypotheses.md`: Tier 1 fits the whole 20-second pattern, Tier 2 part of it, Tier 3 was checked on
22 Nov and found quiet. **E1 to E3** are the experiments. **SmartScale** is SQUID's own throttle that puts
far-away bots to sleep after a long tick. Any other term:
`.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## What one day of data shows (22 Nov 2026, one player)

Full table, commands and caveats: `references/evidence-2026-11-22.md`. The sibling skill
wildcard-diagnostics-and-tooling holds its own parser outputs for the same day in
`.claude/skills/wildcard-diagnostics-and-tooling/references/reference-run-2026-11-22.md`; both parsers count 457
complete records (the sibling prints 458 blocks, one of them cut off at the end of the copied file).
Computed from the log files that day:

1. **Nobody on: no long ticks.** 340 records with 0 players, none with a tick of 1 s or more (worst 534 ms,
   median tick 2 ms). The bots are **logged out** when nobody is on (`AiPlayerbot.DisabledWithoutRealPlayer = 1`,
   `server-settings.txt:479`), so this is an empty world, not "bots idling".
2. **One player on: long ticks in nearly every window.** 117 records: a tick of 500 ms or more in 111, 1 s or
   more in 77, 2 s or more in 22; worst 5,397 ms at 14:49.
3. **Two phases, analysed separately:**

   | | Login ramp (14:36-15:00, 24 records) | Steady state (15:00-16:32, 93 records) |
   |---|---|---|
   | What is happening | about 750 bots log in (world server memory climbs 4.4 to 6.3 GiB) | bots all in |
   | Records with a tick of 1 s / 2 s or more | 17 / 15 | 60 / 7 |
   | Worst tick | 5,397 ms (every tick over 3 s of the day is here) | 2,896 ms |
   | Median tick | 12 ms rising to 32 ms | 37 ms ("95% under" 95 ms) |
   | MySQL (mysqld CPU, 100 = one core) | **72-111% once every 40 s, 15 times in a row, 14:37:37 to 14:46:59**; at most 33% after | never above 26% |
   | One logical CPU at 85% or more while the process falls to 104-132% | 7 samples, 14:41-14:52 | none seen at 5 s sampling |
   | Database as a cause | **not ruled out** | no slow statement, mysqld quiet: a slow statement is ruled out; a burst of fast queries is not |

4. **A 20.03-second beat** in the world server's CPU, present only while the player was on (measured 15:00 on;
   nothing like it in the idle hours). The size of a record's worst tick **correlates** (-0.69) with how far the
   process's CPU dips inside that record's window; for the same windows moved 20 to 40 s earlier the figure is
   between -0.10 and +0.01. That is a correlation, not proof that the long ticks are the beat.
5. **In the login ramp the largest ticks look like one thread computing**: one logical CPU at 85-100%, the whole
   process down to about one core, MySQL at 6-9% in those seven samples, disk idle. In the steady state the
   5-second counters are too coarse to show this for any single spike.
6. **Quiet all day:** disk writes, memory, paging, whole-VM stalls, slow SQL statements (none after start-up).
7. **Dungeon Clear runs made no difference** (65% of records with a 1 s tick inside a run, 67% outside).

**Timing.log is a partial view** (each record covers only the last 500 ticks: format and caveat in
wildcard-diagnostics-and-tooling). With a player on that was 20-28 s of each minute (41% of the time after 15:00
on 22 Nov, 13% over the day). So every "worst tick" is a **floor**, and counts of "minutes with a spike" are
biased (Phase 1 step 4).

So: on that day something that runs **every 20 seconds while a real player is on** went with dips in the world
server's CPU and with long ticks. Two pieces of SQUID code run on exactly that schedule on the world thread
(`references/hypotheses.md` H1, H2). Which one, or whether it is a third thing, is what the next experiment
decides. The login ramp may have a second cause of its own (the database pulse).

## Phase 0: safety and scope

| Action | Rule |
|---|---|
| Reading logs, running the scripts on copies, reading sources | Free. Do it. |
| Any change to a setting, SQL, patch, addon or script | **Classify with wildcard-change-control first.** James merges. |
| A value change to a setting already in `server-settings.txt`, **inside the range its comment states** | Pre-approved "standard change" (LOW) per `change-risk.md`. |
| Bot count (`AiPlayerbot.MinRandomBots` / `MaxRandomBots`), `RecordUpdateTimeDiffInterval`, and any other setting whose comment states **no range** | **Not** a standard change. The bot-count comment (`server-settings.txt:505-506`) records history, not a range, as of 2026-11-22. Score it with wildcard-change-control; James merges. |
| A setting line that is **not yet** in `server-settings.txt` (most experiments here) | Not pre-approved. Score it. It acts on all 750 bots and can only be seen working live, so do not assume LOW. |
| C++ (a patch) | Scores high on "kind of change" and usually on "every tick"; expect HIGH with a patch-reviewer (Fable) review. A build takes 2-3 hours. |
| Patch night, the installer, `Restore-Official.cmd`, rollback, console/GM commands | **Hard stops** (1 and 5). James does these himself. Never from an agent session on its own. |
| Editing config files on the VM by hand | Never. `CHANGES.md` (DOCTRINE): "Nothing is edited on the running server by hand". Settings go in the repository and apply at the next start (go-live table: wildcard-run-and-operate). |

**Proposed practice (not yet adopted by James): the rules of the campaign.** Purpose: to be able to say which
change did what. Incident that motivates them: 21-22 Nov, when bot count, auction stock, the build, the
diagnostics and four core options all changed within a day and no clean "before" exists
(`references/timeline.md` section 3).

- **One change per night.** The nightly restart applies it; the next evening tests it. If anything else merged
  that day changes load, the night is void: say so in the campaign log.
- **Write the prediction before the run** (template in `references/templates.md`). An experiment without a
  written prediction is a look, not a test.
- **The campaign log** is the PR description of each experiment (template: `references/templates.md` section 1).
  To read earlier entries: `gh pr list -R JaTynan/coa-wildcard-mystic --state all --search "lag campaign"`.
  (Also proposed: one running file `docs/lag-campaign-log.md`, so the record is in the repository. It does not
  exist as of 2026-11-22.)

Two things that are not proposals:

- **Do not copy log files into the repository** (it is public). Quote a few lines at most.
- CHANGES.md says changes go in as one PR per patch night (DOCTRINE); in practice many PRs merge per day
  (PRACTICE). For this campaign that matters: check `git log origin/main --since=yesterday` before trusting any
  evening as "one change".

## Phase 1: establish the baseline

Do this at the start of every session, even if a baseline exists: one more evening may change the ranking.

**22 Nov is not the baseline for what runs next.** That day's only server start was at 08:53-08:56. #229, #230
and #231 merged at 08:59, 09:21 and 15:43 that day, after the start, so none of them was live in the 22 Nov
data (not the staged restart, not the console-log rotation, not the four core options of #230). The first full
evening after the next restart differs from 22 Nov by those merges as well as by any experiment: treat it as a
**new baseline**, and do not compare it one-to-one with 22 Nov.

1. **Get the files** from the game VM, folder `C:\Games\CoA Server\Core\Logs\`: `Timing.log`, the newest
   `perf\perf-*.csv` files (one per server start), `mysql-slow.log`, and once `console-history.txt` (copy it,
   never delete or move it: it cannot be rebuilt). Work on copies outside the repository.
2. **Record the conditions**, or the numbers cannot be compared later:
   - installed build: `Core\worldserver.patched-release.txt`; restarts: `patch-night\patch-night.log`;
   - **when the server last started, against when each PR merged** (a merge after the start is not live):
     `git log origin/main --first-parent --merges --since="3 days ago" --format="%h %ad %s" --date=iso-local`;
   - bot count and SmartScale as the VM has them: `findstr /B "AiPlayerbot.MinRandomBots AiPlayerbot.botActiveAloneSmartScale" "C:\Games\CoA Server\Core\configs\modules\playerbots.conf"`
     (SmartScale is not in `server-settings.txt`, so the VM runs whatever that file holds);
   - who played, how many at once, and where (zone, city, dungeon). Ask James; the logs only give the count
     (Dungeon Clear runs are in `Logs\squidbot\runs.jsonl`). The number of bots awake is logged nowhere.
3. **Summarise** with the sibling skill's parsers (`.claude/skills/wildcard-diagnostics-and-tooling/scripts/`;
   that skill says how to run them on the VM or on staged copies): `timing_summary.py`, `perf_csv_summary.py`,
   `slow_query_summary.py`. Then run this skill's gate script (Python 3.8+, standard library, read-only). Run
   from the repository root and give full paths to the log copies; on the VM use
   `"C:\Games\CoA Server\Runtime\python\python.exe" -I -B` in place of `python3 -I -B`:

   ```
   python3 -I -B .claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py sessions Timing.log --spike-ms 1000
   python3 -I -B .claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py cycle perf-DATE_TIME.csv --timing Timing.log --from "EVENING START"
   python3 -I -B .claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py perf-at Timing.log perf-DATE_TIME.csv --spike-ms 2000 --top 25
   python3 -I -B .claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py metric Timing.log --min-players 1 --evening 18 24
   ```

   Run `cycle` on the steady state only: start it at least 25 minutes after the first login (on 22 Nov:
   `--from "2026-11-22 15:00"`). Expected on an unchanged server (22 Nov values): `sessions` shows 0 spikes per
   100 records with 0 players and about 66 with 1; `cycle` shows a best period of 20.0-20.1 s explaining about
   0.3 with controls under 0.1; `perf-at` shows "one-thread" on the largest login-ramp spikes, "mysql-busy" on
   two of them, and never "disk", "paging" or "sampler-gap". `metric` with the default evening prints **no row
   and exits 2** for 22 Nov (the log ends at 16:32); with `--evening 15 24` it prints FAIL and exits 1.
4. **Know what Timing.log cannot see** (details: `references/engine-and-timers.md` section 2 and evidence B):
   - each record covers only `500 x mean tick`: about 40% of the time with a player on, 13% over the whole day;
   - the records are 60 s apart and the beat is 20 s, so every record lands on the same point of the beat.
     "Share of minutes with a spike" is therefore a property of the sampling. Never report it as a rate.
   - **Proposed practice (not yet adopted by James; score it first, the setting's comment states no range):**
     `RecordUpdateTimeDiffInterval = 17000` instead of 60000. Purpose: full coverage with a player on (a window
     is 20-28 s) and a spacing that is not a multiple of 20 s, so periods can be read from Timing.log itself.
     Cost: about 3.5 times the lines in Timing.log, Server.log and the console. Measuring only; the setting is
     already in `server-settings.txt`.
   - **Alternative, a spike-only log (same two settings, also a Proposed practice):**
     `RecordUpdateTimeDiffInterval = 1000` with `MinRecordUpdateTimeDiff = 500`. The core writes a record only
     when the current tick is longer than the minimum and the interval has passed
     (`WorldUpdateTime::RecordUpdateTime`), so this logs **every tick over 500 ms with its exact time** (at most
     one a second). Catch: no long ticks means no records at all, so medians, p95 and the exit metric cannot be
     computed from those nights. Use it for a few nights to time the spikes exactly, not as the permanent
     setting. These two are the only tick-logging options this core has.
5. **The exit metric. Proposed practice (not yet adopted by James).** This is the library's single home for lag
   pass/fail numbers; wildcard-validation-and-qa and wildcard-frontier point here and state none of their own.
   Purpose: one agreed test of "not laggy" so fixes can be accepted or rejected. Anchored to
   `docs/performance.md` ("95% under" about 50 ms is smooth; 100 ms and up feels laggy). An evening **passes**
   when, over the records between 18:00 and midnight with at least 2 real players on (at least 30 such records,
   coverage 90% or more):
   - no window has a tick of 500 ms or more;
   - the worst window p99 is under 150 ms;
   - at least 95% of windows have p95 at or under 50 ms.

   The campaign **exits** after 7 passing evenings in a row at the target bot count. `spike_gates.py metric`
   prints the verdict per evening and the current run (exit code 0 PASS, 1 FAIL, 2 no evening with enough
   records). On 22 Nov with `--min-players 1 --evening 15 24`: 91 of 93 windows over 500 ms, worst p99 225 ms,
   0% of windows with p95 at or under 50 ms: FAIL. If James plays alone most evenings, use `--min-players 1` and
   say so. A night with nobody on gives **no verdict**: the world is empty then (bots logged out), so it can
   never fail.

## Phase 2: characterise (decision tree)

Run the gates in order. Each gives the command, what 22 Nov showed, and where to go.

**Gate A. Players or no players?** `spike_gates.py sessions`, table "By real players online".
- Spikes only with players on (22 Nov: 0 against 66 per 100 records) -> the cause needs bots online or players: Gate B.
- Spikes with 0 players too -> something that runs regardless: Auction House bot (60 s), start-up work, the
  host. Go to H4 and Tier 3 in `references/hypotheses.md`. One expected exception, **from the code and not yet
  observed** (the 22 Nov log ends with the player still on): a single huge tick about 5 minutes after the last
  player leaves would be all bots logging out at once (`LogoutAllBots`); nobody is on to feel it.

**Gate B. Login ramp or steady?** Same command, table "Since the session started".
- Rate several times higher in the first 10-20 minutes than later -> the bot login storm dominates: H1 login part.
- Flat (22 Nov: about 60-70 per 100 in every row) -> a steady mechanism as well: Gate C. The **size** can still
  be worst in the ramp (22 Nov: every tick over 3 s came within 20 minutes of login, 14:38-14:56).
- Either way, **judge the two phases separately from here on**: run Gates C and D once on the first 25 minutes
  after login and once on the rest. The ramp has its own signature (Gate D).

**Gate C. Periodic?** `spike_gates.py cycle perf.csv --timing Timing.log --from "START"` on at least 30 minutes
of steady state with players on (a 10-minute range overfits: on the 22 Nov login ramp the controls explained
more than half of what the candidates did).
- A candidate explains at least twice what the controls do (22 Nov: 0.34 at 20.03 s against 0.03-0.06) -> a
  timer. Look the period up in `references/engine-and-timers.md` section 3. 20 s -> H1/H2. 60 s that is not
  just 3 x 20 -> H4. 300 s, 600 s, 900 s -> bot statistics, chat saves, autosaves.
- The "Link to Timing.log" lines say whether a larger worst tick goes with a deeper CPU dip (22 Nov: -0.69;
  controls for windows moved 20-40 s earlier +0.01, -0.10, -0.02, -0.04). Trust it only when it is clearly
  stronger than those controls, and call it a correlation. (An earlier version of this gate also counted where
  in the cycle the lowest sample fell. That test was circular, any 20 s window contains the dip, and has been
  removed.)
- Nothing stands out -> aperiodic: Gate D decides between computing and waiting. If the record spacing has been
  shortened (Phase 1 step 4), `spike_gates.py periodicity Timing.log` tests longer periods (minutes to hours)
  and clock-aligned jobs; with 60 s spacing it cannot see anything at or under a minute.

**Gate D. Computing or waiting?** `spike_gates.py perf-at Timing.log perf.csv --spike-ms 2000 --top 25`.
What 22 Nov printed for its 22 spikes of 2 s or more (a spike can carry two hints): **nothing stood out x10,
one-thread x9, process-dip x4, mysql-busy x2**. Split by phase: all nine "one-thread" and both "mysql-busy" are
in the login ramp (before 15:00); the seven spikes after 15:00 gave "nothing" six times and "process-dip" once.
- "one-thread" (in the seven clearest samples one CPU was at 85-100% and the process at 104-132% against a
  usual 220%) -> a single thread is doing the work at that moment. Not disk. Tier 1.
- "mysql-busy", or process CPU down with **no** busy CPU on many spikes -> waiting on the database: the
  synchronous-query row of Tier 3 is open. **On 22 Nov this applies to the login ramp**: the two mysql-busy
  spikes (14:39:02, 3,460 ms; 14:47:03, 3,581 ms) sit inside a 40-second mysqld pulse of about one core
  (14:37-14:47, 15 times). Read `mysql-slow.log` at those seconds (its times are UTC; Sydney is UTC+11 in
  November): on 22 Nov it has no entry there, so no single statement took over 0.5 s, and a burst of many fast
  queries is what remains. After 14:47 mysqld never passed 33%.
- "process-dip" only, or "nothing" -> cannot tell at 5 s resolution (most steady-state spikes on 22 Nov); rely
  on the correlation in Gate C, or go to Phase 5.
- "disk", "paging", "sampler-gap" -> the matching Tier 3 row is open again.

**Gate E. Scales with what?** Needs several evenings: compare `metric` and the `sessions` tables between
evenings with 1, 2, 3+ players and note zones. Not answerable from 22 Nov (one player).

**Gate F. Worse since 19 Nov?** Already answered as far as the data allows (evidence C): logged slow ticks were
larger on the 19 Nov core than on the one before (14% -> 74% at 500 ms or more with a player on), multi-second
ticks existed on every core back to October, and the official 19 Nov build produced a 2.6 s tick once. On this
VM the new core, SQUID 3.0 and Dungeon Clear arrived together, so the file cannot say which. It has no
timestamps and cannot give rates. Do not spend more time on it.

**Check whether the logging change holds** (f9dc45a; a candidate cause, never confirmed). Status, in the
library's agreed words: shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and
the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run
yet; status **OPEN**. Do not redo the change; measure it:
`findstr /B "Log.Async.Enable Logger.coa Logger.module.coa_challenges" "C:\Games\CoA Server\Core\configs\worldserver.conf"`
must show `1`, `4,Server` and `3,Console Server`; and after the next restart
`dir "C:\Games\CoA Server\Core\Logs\world-console*.log"` should show dated files (since #229 each start's
console log is renamed with the date and the newest 3 kept), and `patch-night.log` should hold "Cleared world-console.log (N MB), once" and no line "Left
world-console.log as it is for now (in use)" (written when the old file could not be removed). Growth of more than a few hundred MB
per day means: find which logger is writing (the file's own lines say) before anything else. (Commands written
for the VM, not executed for this skill.)

## Phase 3: hypotheses and experiments

The menu, with mechanism (verified file and function), predictions, experiments, fix options and what must be
shown before a fix is adopted: `references/hypotheses.md`. Order of work as of 2026-11-22 (every row is a
change: classify first, James merges):

| Step | Experiment | One-line prediction to write down | If confirmed | If refuted |
|---|---|---|---|---|
| 1 | **E1**: `AiPlayerbot.RandomBotUpdateInterval = 30` for one evening | steady-state beat moves from 20.03 s to 30.0-30.2 s (about 15 s during the login ramp, while under 90% of the bots are online); long ticks per hour fall by about a third | the bot manager's cycle is the place (H1): step 2 | beat still 20 s **with the live value confirmed as 30**: step 3 |
| 2 | **E2**: interval back to 20, `AiPlayerbot.RandomBotsPerInterval = 20` | beat stays 20 s; median of window maxima falls from about 1,200 ms towards a third | cost is per bot processed: tune batch size (fix a), then E3 to find which work | cost is fixed per cycle: Phase 5 instrumentation, case file |
| 3 | `AiPlayerbot.CoaLive.Enable = 0` for one evening | 20 s beat and long ticks gone | H2: decide with James whether to keep the feature off, report upstream | neither H1 nor H2: Phase 5 |
| 4 | Official-server evening (James only: hard stop 5) | same beat on the manager's own build | upstream: report it; settings-level mitigation | ours: bisect the switches (procedure in hypotheses.md) |
| any time | bots 750 -> 500 (**not** a standard change: the comment states no range; score it) | median and p95 fall about in proportion; beat unchanged | load lever for H5, independent of the long ticks | - |

**Before calling E1 refuted**, confirm the value was live that evening: on the VM
`findstr /B AiPlayerbot.RandomBotUpdateInterval "C:\Games\CoA Server\Core\configs\modules\playerbots.conf"` must
print 30, `settings-report.txt` must not list the name as unknown, and the server must have restarted after the
merge. Run `cycle` with `--from` set at least 25 minutes after the first login, so the 15-second ramp cycle is
not in the range.

All three settings in steps 1-3 are SQUID's, exist in its `playerbots.conf.dist` at the pinned commit, and are not
yet in `server-settings.txt`; adding a line follows the checklist in wildcard-settings-and-flags (the settings
check reports unknown names). Undo is not "delete the line": the config file on the VM keeps the last value
written until something writes the default back, so the undo PR must **set the default explicitly** (20, 60, 1).

## Wrong paths already tried (do not repeat without new evidence)

| Path | What happened | Source |
|---|---|---|
| More vCPUs or map threads | 1 -> 4 threads helped (33 -> 50 ticks/s); beyond that "more vCPUs or map threads add little" because one thread per map is the limit. On 22 Nov total CPU was 28% of 10 logical CPUs during the spikes (`docs/performance.md` says 8 vCPUs; that line is stale) | `docs/performance.md`; evidence D |
| Wake bots by radius only (`BotActiveAloneForceWhenInZone = 0`) | bots near players froze for 20+ minutes; cause never found; reverted the same day. An unexplained dead end, **not** an available lever | e608f61 -> c02ba12 (#88, #95), 8 Nov |
| Raising the bot count to see | 1,500 and 1,250 both went back down. Worst ticks were 1.3 s (3 players, read around the cut from 1,250 to 1,000 on 9 Nov) and 2 to 5 s (2 players, read around the cut from 1,000 to 750 on 21 Nov); the record does not say which side of each cut the reading was taken on, so no conclusion about bot count follows | `references/timeline.md`; wildcard-failure-archaeology |
| Wider view distance | 150 yards backed out before going live while chasing spikes | ff00757, 9 Nov |
| Judging by "feels smoother" | every past change was judged from one glance at a 500-tick snapshot; none has a before/after | timeline |
| Several levers at once | 21-22 Nov changed bot count, auction stock, build, diagnostics and four core options within a day; there is no clean "before" | timeline section 3 |
| Reading ticks/s on an empty server | with nobody on the bots are logged out and the server spins freely (22 Nov: median tick 2 ms, mean about 4 ms, about 240 passes a second); it means nothing about load | `docs/performance.md`; evidence A1 |
| Changing console logging again | already changed by settings on 20 Nov (#204) with no after-measurement; the spikes continued the next day; status OPEN. Measure the log growth first (Phase 2, last check) | f9dc45a, 6a3e017 |
| The 40-second character list | an index problem, fixed 8 Nov (#84). Unrelated to ticks | 257158e |
| MySQL tuning as a spike cure | buffer pool, redo log and flush settings went in on 8 Nov with no measurement; on 22 Nov the disk was idle throughout and MySQL was quiet in the steady state (it was **not** quiet in the login ramp: Gate D) | 61a5be9; evidence A9, A10, A14 |
| "It started with the 19 Nov core update" | spikes over a second are in the logs since October and in commits since 9 Nov | evidence C |

## Phase 4: fix, validate, promote

Steps 1 and 3 are **Proposed practice (not yet adopted by James)**. Purpose: one good evening has been taken
for a result before (every row of the timeline is a single glance); the ladder stops the bot count being raised
on a hunch. Incident: 1,500 and 1,250 bots both had to come back down (7 and 9 Nov).

1. **Before/after protocol** (card in `references/templates.md`): the same number of evenings before and after
   (at least 3 each for a settings fix), same bot count, same build unless the build is the change, at least 30
   records with players on per evening. Accept only if **every** after-evening beats **every** before-evening on
   the number the prediction named. One good evening is not a result.
2. **Promotion.** Settings fix: PR with the campaign log entries in the description -> classify with
   wildcard-change-control -> James merges -> live at the next restart. Patch: wildcard-patch-authoring
   pre-flight, HIGH path, patch-reviewer, 2-3 hour build (a merged patch is built only when someone runs the
   workflow with `rebuild` ticked), installed at the weekly patch night or by James. When each kind of change
   goes live: wildcard-run-and-operate, "When does my merged change go live?".
3. **Bot ladder.** Only after 7 passing evenings at the current count: 750 -> 1,000 -> 1,250, one step at a
   time, **each step classified with wildcard-change-control** (a bot-count change is not a standard change;
   James merges), each needing 7 passing evenings before the next. A step that fails two evenings in a row goes
   back down. 1,250 is where `docs/performance.md` settled on 7 Nov; nothing says the VM can carry more.
4. **Document.** A new dated table in `docs/performance.md` (proposed row shape: wildcard-docs-and-publishing,
   `references/templates.md`, template E; this campaign's extra columns are listed in `references/templates.md`
   here; the file is out of date in four places, listed there); a line in `CHANGES.md` for any new setting or
   patch; the settings comment carries the date and the measured numbers, as the existing ones do. If a C++
   root cause needs judgement, write a case file by hand (skeleton in `references/templates.md`): the "crash
   and lag investigator" agent is Stage 2 and NOT BUILT YET.

## Phase 5: if nothing discriminates, add instruments

Each is a change: classify first. Listed cheapest first. None exists on the VM today.

| Instrument | Tells you | Status |
|---|---|---|
| `RecordUpdateTimeDiffInterval = 17000` (full coverage), or `1000` with `MinRecordUpdateTimeDiff = 500` (every tick over 500 ms, exact time). **Do this first**: it is measuring only | spike times and periods straight from Timing.log | Proposed practice; existing settings whose comment states no range, so scored (Phase 1 step 4) |
| SQUID's performance monitor: `AiPlayerbot.PerfMonEnabled = 1`, then James runs `playerbots pmon` on the console (a console command: hard stop 1) | time per named bot operation, including the manager's cycle and logins | in the pinned sources; UNVERIFIED on this VM |
| Timestamps on `Server.log` and `Playerbots.log` (appender flag 1, as `Appender.Timing` has) | bot logins, logouts and module messages on the same clock as the spikes | Proposed practice; exact lines need checking against the VM's `worldserver.conf` |
| `typeperf` at 1 s instead of 5 s (the `-si` value in `StartDiagnostics`) | separates a busy thread from a wait for 1-2 s ticks, in the steady state too | Proposed practice; touches PatchNight.ps1, hard stop 5: James |
| A patch that logs any tick over N ms with the time spent in each phase of `World::Update` and in each map | which thread, which phase, which map | NOT BUILT YET; per-tick C++: HIGH. The core already has the timing points (`METRIC_TIMER`), sent only to InfluxDB (`Metric.Enable`, no InfluxDB set up) |
| A stack sample of the world server during a long tick (Windows Performance Recorder, or Sysinternals ProcDump with a hang trigger) | the function that is running | UNVERIFIED on this VM: not installed, never tried; needs the build's symbol files to be useful |

## References

- `references/evidence-2026-11-22.md`: read first; every number of the one real day, how to recompute it, what
  it does not show, which branches it closes.
- `references/hypotheses.md`: read when choosing or designing an experiment, or after a result.
- `references/engine-and-timers.md`: read when a period, a thread or an instrument limit is in question.
- `references/timeline.md`: read when someone asks "what did we already try" or wants a before/after.
- `references/templates.md`: read when writing the log entry, the performance.md row or a case file.
- `scripts/spike_gates.py`: the gates (`sessions`, `cycle`, `perf-at`, `periodicity`, `metric`); `--help` for
  options. Authority for the lag exit metric; for the other pre-merge checks see wildcard-validation-and-qa,
  "The pre-merge check set".

## Provenance and maintenance

Written 2026-11-22 from the repository checkout `fcfee51` (PR #232's head: `62a26e4`, the #230 merge, plus two
commits adding `.claude/agents/` and `docs/agents/`; `origin/main` is `d3e030f`, #231), the pinned upstream
sources (read, never built), and one day of the server's logs. Every 22 Nov number was recomputed with the
corrected `spike_gates.py` on 2026-11-22. Volatile facts and how to re-check them (run in the repository root):

```
# Pinned commits (core c3f2fd4b, SQUID v3.0 4ef5ed9e, Dungeon Clear 6efb59ea)
python3 -I scripts/resolve_release.py latest
# Ollama chat pin 906eb2a4
grep -n -A5 "mod-ollama-chat" .github/workflows/build-worldserver.yml
# Timing settings (60000 / 0) and the three logging lines
grep -nE "RecordUpdateTimeDiffInterval|MinRecordUpdateTimeDiff|Appender.Timing|Log.Async.Enable|Logger.coa|Logger.module.coa_challenges" server-settings/server-settings.txt
# Bot count 750 and its comment (still no range?), zone waking on, radius 300, BotActiveAlone = 5, bots logged out when nobody is on
grep -nE -B2 "MinRandomBots" server-settings/server-settings.txt
grep -nE "MaxRandomBots|BotActiveAlone|DisabledWithoutRealPlayer" server-settings/server-settings.txt
# E1-E3 settings still absent from the settings file (no output = absent)
grep -nE "RandomBotUpdateInterval|RandomBotsPerInterval|CoaLive.Enable|SmartScale|PerfMonEnabled" server-settings/server-settings.txt
# Counter list and 5 s sampling
grep -nE "typeperf|'-si'" patch-night/PatchNight.ps1
# Slow-query threshold 0.5 s
cat sql/enchants/095-slow-query-log.sql
# Merge times against the server start (what was live on a given day)
git log origin/main --first-parent --merges --format="%h %ad %s" --date=iso-local -6
# Hard stops and standard changes
git show origin/main:docs/agents/context/change-risk.md | sed -n 7,16p
# Lag investigator still NOT BUILT YET (Status column)
git show origin/main:docs/agents/README.md | grep -n "lag investigator"
# docs/performance.md still out of date (7 Nov 2026 when written)
git log -1 --format=%ad -- docs/performance.md
# The script still parses the logs ("Records: 0" means the line format changed)
python3 -I -B .claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py sessions PATH/TO/Timing.log
```

The 20 s and 10 s cycle, the 500-tick table and every timer in the timer table: commands at the end of
`references/engine-and-timers.md` (re-run after every core or SQUID update: a new release can change any of them).

When an experiment gives a verdict: update the state-of-knowledge paragraph at the top (with the date), move the
hypothesis in `references/hypotheses.md`, and add a dated evidence file next to `evidence-2026-11-22.md` rather
than editing that one.
