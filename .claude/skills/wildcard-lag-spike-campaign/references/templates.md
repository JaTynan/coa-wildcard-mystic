# Templates for the campaign

## 1. Campaign log

Keep it in the PR description of each experiment and, once the campaign has a result, in a case file
(`docs/agents/cases/`, section 3). One entry per experiment or per analysis of a new evening. The **prediction is
written before the run** and never edited afterwards; the method behind that rule is in
wildcard-analysis-and-method.

```
### <date> - <short name>
Hypothesis:   H? (from references/hypotheses.md) in one sentence.
Change:       exactly what differs from the night before (settings lines, build tag). "None (analysis only)" is valid.
              Everything else that changed that night anyway: <build, other merged PRs, restart time>.
Conditions:   evening window, players on (how many, where: zone / dungeon / city), bots configured.
Prediction (written <date/time>, before the run):
              If H? is true:  <instrument> will show <number or range>.
              If H? is false: <instrument> will show <number or range>.
Observation:  the command lines run and the numbers they printed (coverage included).
Verdict:      confirmed / refuted / inconclusive (why: too few records, conditions differed, ...).
Next:         the one next step this verdict selects.
```

Worked entry from the data that exists:

```
### 2026-11-22 - first day of diagnostics (analysis only)
Hypothesis:   none yet; characterise.
Change:       none. Core c3f2fd4b2395+, 750 bots, settings as on main before the 08:53 start (at most #228;
              #229, #230 and #231 merged at 08:59, 09:21 and 15:43 and were not live).
Conditions:   08:56-16:32, 0 players until 14:36, then 1 player; in Dungeon Clear runs 14:37-14:59 (Ragefire
              Chasm) and 15:22-16:10 (Wailing Caverns) per squidbot\runs.jsonl, elsewhere not recorded.
Prediction:   none written beforehand (first look). So nothing here counts as a confirmed prediction.
Observation:  spike_gates.py sessions: 0 of 340 empty-world records with a tick >= 1,000 ms; 77 of 117 with a
              player (login ramp 14:36-15:00: 17 of 24; steady state: 60 of 93).
              spike_gates.py cycle (15:00 on): best period 20.030 s explains 0.34; controls 0.03-0.06;
              link: correlation -0.69 (windows moved 20-40 s earlier: +0.01 to -0.10).
              perf-at (22 spikes >= 2 s): nothing x10, one-thread x9, process-dip x4, mysql-busy x2; the
              one-thread and mysql-busy hints are all before 15:00. mysqld at 72-111% of a core every 40 s,
              14:37-14:47.
Verdict:      pattern found (a 20 s beat with players on; one busy thread and a database pulse in the login
              ramp); cause not identified. Root cause UNKNOWN.
Next:         E1 (RandomBotUpdateInterval = 30), prediction to be written before the evening. The next
              evening is a new baseline: #229-#231 go live at the next restart.
```

## 2. A row for docs/performance.md

`docs/performance.md` has one table ("Measured (7 Nov 2026)": Setup, Ticks/s, Average, 95% under, Peak, VM
memory). It is out of date in four places as of 2026-11-22: it says 8 vCPUs (the VM has 10 logical processors),
"settled on 1,250" bots (750 since 21 Nov), `BotActiveAlone` "now 15" (5 since 7 Nov), and 4 map threads (6
since 8 Nov). Updating it is a docs change: propose it in the same PR as the first campaign result. The home
for the proposed row shape is wildcard-docs-and-publishing (`references/templates.md`, template E). The columns
this campaign needs in such a row (Proposed practice, not yet adopted by James) are the ones the old rows lacked:

```
## Measured (<date>, from Timing.log and the counter log)

| Setup | Players | Records | Coverage | Median | 95% under | Windows with a tick >= 500 ms | Worst tick | Beat | Memory |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 750 bots, 6 map threads, core c3f2fd4b2395+, before any change | 1 | 93 (15:00-16:32) | 41% | 37 ms | 95 ms | 91 of 93 | 2,896 ms | 20.03 s | 6.5 GiB |
```

"Median" and "95% under" are the medians across records of each record's own figure. State the evening window
and the player count; a row without them cannot be compared with another.

## 3. Case file for Fable (when a C++ root cause needs judgement)

The "crash and lag investigator" in `docs/agents/README.md` (PR #232, merged 22 Nov 2026) is Stage 2 and
**NOT BUILT YET**. Until it exists, write
the case by hand from `docs/agents/case-file-template.md` into `docs/agents/cases/YYYY-MM-DD-lag-spikes.md`, and
add a line to `docs/agents/fable-ledger.md` when it is used. Fable reads only that file, so it must carry the
evidence. Under two pages. No log files, no secrets. Skeleton for this campaign:

```
# Case: 20-second long ticks on the world server
- Kind: lag
- Prepared by: <who>, <date>
- Budget: one Fable call

## Question
<One decision. Example: "E1 moved the beat to 30 s and E2 cut the tick size to a third. Do we ship smaller
batches by settings, or patch SQUID to spread ProcessBot over ticks?">

## What we know
- <each fact with its source: Timing.log window and command, perf CSV command, commit, file:function at pin>
- The campaign log entries, verbatim, predictions included.

## What we don't know
- Which thread (world or one map). What inside the cycle is slow. Behaviour with 2+ players.

## Options considered
1. Settings only: ... cost, risk, how it is undone.
2. Patch: ... (per-tick code for all bots: HIGH; 3½ h build; patch-reviewer).
3. Report upstream and wait.
4. Do nothing; stay at 750 bots.

## Constraints
docs/agents/context/change-risk.md (hard stops; James merges MEDIUM and HIGH). Acceptable: ~30 min downtime,
~15 min data loss. Players are few and non-technical: bots must not "feel dead".
```

## 4. Before/after protocol card (copy into the experiment's PR)

```
Before: evenings <dates>, same weekday mix if possible, >= 30 records each with players on, coverage >= 90%.
After:  the same number of evenings, same bot count, same build unless the build IS the change.
Compare: per evening, spike_gates.py metric (same thresholds) and spike_gates.py cycle (period, explained).
Accept only if: every after-evening is better than every before-evening on the predicted number
               (not on average), and nothing else changed between them. Otherwise: inconclusive, extend.
```
