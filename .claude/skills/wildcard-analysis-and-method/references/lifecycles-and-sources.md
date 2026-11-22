# Idea lifecycles, where ideas came from, and patterns to avoid

Evidence for sections B5, B6 and B7 of the method; their full text is at the end of this file (moved from
`SKILL.md`). Hashes are on `origin/main` unless a branch is named. As of
2026-11-22. The complete chronicle of investigations lives in `wildcard-failure-archaeology`; this file keeps
only the cases that teach the method.

## 1. Lifecycles

### 1.1 Bots wake radius: tried, broke something, half kept (8 Nov)

| Time | Event | Evidence |
|---|---|---|
| 15:10 | Idea, with its reasoning in the settings comment: with two players questing in different zones, each zone woke all its bots (95% under 62 to 72 ms, spikes to 485); wake only bots within 300 yards, so "each extra player costs a circle, not a zone". Two settings: `AiPlayerbot.BotActiveAloneForceWhenInZone = 0`, `AiPlayerbot.BotActiveAloneForceWhenInRadius = 300` | e608f61, PR #88 |
| 17:08 | Result: bots near players froze ("walked a few steps, then stood for 20 minutes or more") "although the radius check reads correctly". Zone waking back on "until that is understood". Radius kept | c02ba12, PR #95 |

What this did well: a settings-only experiment, undone in two hours by one line; the comment keeps the baseline
numbers, the symptom, and the negative (the check reads correctly, so the obvious explanation is ruled out).
What is missing: a predicted figure, a measurement with the radius on, and any follow-up. Why bots froze is
**open** as of 2026-11-22. Before anyone proposes "wake by radius" again, they must explain the freeze first.

### 1.2 Arcane Charge: a fast, recorded test loop (2 Nov, 21:07 to 22:33)

| Step | What was tried | Test result recorded | Commit |
|---|---|---|---|
| 1 | Damage lands around the Charge target instead of the caster (the helper is cast as Charge starts, so nothing was near the caster) | | 52a235a (PR #32) |
| 2 | Range opened so the cast is not refused while far away | | 29eac6a (PR #33) |
| 3 | **Reverted:** "Retargeting it at the Charge target broke the whole helper"; test checklist and tracker updated with 2 Nov results for this and the other action enchants | "partly: mana parts work; damage only hits enemies near you as Charge starts" | d2ebbdb (PR #34) |
| 4 | Fire when Charge Root lands, "which is when you arrive" | | 93bfa49 |
| 5 | Charge Root lands as Charge starts, not on arrival, so that missed too; damage now hits the Charge target itself | | 79b50b4 (PR #35) |
| 6 | Tracker set to `verified`: target hit and mana buff work; "only the target is hit, not other enemies near it (tooltip says nearby enemies on impact)" | pass with a noted shortfall | 78f0b00 (PR #37) |

Why it is the model: SQL-only changes applied at a restart, so each attempt cost minutes, not a build; every
attempt, including the failed ones and a wrong theory about timing (step 4), is in the file's comments; the
final record states what still differs from the tooltip. The same commit (d2ebbdb) recorded failures for other
enchants honestly (All that is Right, Fiery Charge).

### 1.3 View distance: 150 merged then backed out; 75 never merged

- 150 yards: reason (mobs popping in on open zones), risk (every bot sees further) and a watch instruction with
  a fallback ("if spikes get worse, try 125") all in the comment (7001de0, PR #111, 9 Nov 08:51). Backed out the
  same evening "before it went live, while chasing lag spikes with 3 players on" (ff00757, in PR #113), in a
  commit that also cut bots from 1,250 to 1,000. It was never measured live.
- 75 yards: branch `origin/perf-visibility-react`, one commit (0cd1413, 8 Nov): "less movement traffic in
  bot-crowded cities". Never merged. No record of why. Status: retired without a record.

Current value: `Visibility.Distance.Continents = 100`, with the 150 story in its comment.

### 1.4 The slow-query log: an instrument with an exit

Temporary file `091-slow-query-log.sql` (over 1 s), its own header saying to delete it once the cause is found
(cc145e5, PR #82); cause fixed (257158e, PR #84); file deleted the same day (ea01588, PR #86). Thirteen days
later a slow-query log returned deliberately as `095-slow-query-log.sql` at 0.5 s (9ba9f45, PR #225), named in
`CHANGES.md` as measuring only. Full working: `worked-examples.md` section 6.

### 1.5 Kill XP 15% lower: unmerged, status unknown

Branch `origin/xp-kill-rate`, commit 225f5f7 (14 Nov): `Rate.XP.Kill` 1.0909 to 0.9273 (1.0909 x 0.85), with the
reason in the settings comment: levelling 20 to 40 took about three hours on a first prestige with a weak
build. Not in `main`; `server-settings/server-settings.txt` on `main` has no `Rate.XP.Kill` line. Whether it was
rejected, superseded or forgotten is not recorded in the repository. Later XP changes went another way (group
XP not split, c48fbf9; Manastorm XP at 75%, 02f4be3). Check the pull request list and ask James before
re-proposing.

### 1.6 Bot count: the lever pulled five times

| Date | Bots | Stated reason | Commit |
|---|---|---|---|
| 6 Nov | 1,000 | More bots; watch world speed | 7a90659 |
| 7 Nov | 1,500 | "try": 1,000 ran at about 45 ticks/s, 20 ms | 2ce36a4 |
| 7 Nov | 1,250 | 1,500 ran at 26 ticks/s, 95% under 66 ms, peaks of 300 ms | aca9022 |
| 9 Nov | 1,000 | Spikes with 3 players: 95% under 74 ms, 99% 147 ms, worst 1.3 s | ff00757 |
| 21 Nov | 750 | Worst ticks 2 to 5 s with 2 players, median 36 ms; "while we find the cause" | 6a3e017 |

Each step has its measurement in the commit or comment, which is good. The pattern across steps is the lesson:
Worst ticks were 1.3 s (3 players, read around the cut from 1,250 to 1,000 on 9 Nov) and 2 to 5 s (2 players, read around the cut from 1,000 to 750 on 21 Nov); the record does not say which side of each cut the reading was taken on, so no conclusion about bot count follows. No measurement taken at 750 is recorded in the repo as of 2026-11-22.

### 1.7 Assumed numbers corrected from a source

Guesses marked "assumed" or "best guess" in PRs #165 and #166 (15 Nov) were checked against the archived
builder tooltips the next day (8cdfebf, PR #169; b570a98). This is the lifecycle working end to end for
numbers: guess labelled, source found, guess replaced, both recorded.

## 2. Where good ideas came from

| Source | Case | What made it work | Evidence |
|---|---|---|---|
| Measure first | Bot-count table | Four comparable rows decided 1,250 on the peak, not the average | `docs/performance.md` |
| Measure first | Slow-query log | Found a statement nobody had guessed | cc145e5, 257158e |
| A precedent in the core | Hot Hands | The core already let another Hot Hands spell (275397) feed Hot Streak; the patch adds two spell ids to the same check: one line | `patches/66-enchant-core-hooks.ps1`, 1d8de01 |
| A precedent in the core | Hoplite, Aspect of the Fox, Iron Guard | "the core only allowed that for the Guardian class"; "the core only let Steady Shot through"; "melee and ranged blocks are already done by the core itself" | `CHANGES.md` rows for patches 67, 68, 69 |
| Reuse working data | Twins, namesakes, school pairs | 143 enchants by twin link, 74 by namesake, with no new logic | `docs/enchant-restoration.md`, Proven recipes |
| Ascension's unused data | Battleground Dampening (spell 74411) | The spell exists in CoA's data; six `spell_area` rows apply it; no code | `sql/enchants/130-battleground-dampening.sql`, b63e976 (PR #144) |
| The official build | Response files; SQUID module patches | The official recipe had already met and solved both problems | 2606a77 (PR #191), 01159e2 (PR #187) |
| Player and GM reports | Worldforged enchants never drop; Scrolls need hundreds of clicks; Cannibalize felt slow; "weekly events felt lackluster" | A concrete complaint with an example | 90ee10d, 7232b63, bc91666, 018b2d7 |
| Archived tooltips | 16 Nov review | James supplied the full builder tooltips; guessed values replaced | b570a98, 8cdfebf |
| The client's own code | Rune currency slots | The refusal was computed in the client; reading it located the rule | b4f61e9 |
| Simulation before the build | Worldforged enchants | "a simulation over the server's Spell.dbc, MysticEnchant.dbc and SpellAffect.dbc registers 990 enchants"; compiled with warnings on against the pinned core | 90ee10d (PR #190) |
| Side-by-side test | Settings script speed-up | Old and new run on 266 settings across 12 files: identical output, then timed | d802f8c |
| Review of our own work | 18 Nov core reviews | Systematic check found doublings no player had reported | f9806da, 06d67c5, 2d391f3, 5bf04bd, 99174fa |

Search order when you are stuck, cheapest first:

1. Is there a measurement, or can a read-only one be taken?
2. Does the core already do this for a sibling spell, class or case? Grep the pinned core for the neighbour.
3. Is there a twin, namesake or class version with working data?
4. Does Ascension's data already hold the piece (a spell, a row) that nothing applies?
5. What does the official build or module do here that ours does not?
6. Can the outcome be simulated from the data files before a build?
7. Who has seen it in game, and what exactly did they see?

## 3. Patterns to avoid, with the evidence

Stated neutrally: each was a reasonable move at the time, and each has a cost visible in the history.

| # | Pattern | Evidence | Cost seen | Counter (Part B) |
|---|---|---|---|---|
| 1 | A plausible fix before any instrument | 0cce098 (connections for the character list), eight hours before the slow log | Symptom stayed; the change is still set, effect unknown | B1, B2 |
| 2 | Several changes in one step | 61a5be9 (buffer pool, redo log, flush, map threads; VM cores changed too); ff00757 (view distance and bot count) | Effects cannot be separated | B4 |
| 3 | No after-measurement | 240d773 (5% awake), f9dc45a (logging), 61a5be9 (6 threads) | Unknown whether they worked; logging case reopened next day | B2 |
| 4 | Decisions on averages or one sample | 7 Nov table rows are single samples without player counts | Bot count revised twice more (1,000, then 750) | Recipes 4, 5 |
| 5 | Treating the symptom lever as the cause | Bot count cut 1,250 to 1,000 to 750; worst-tick readings of 1.3 s and 2 to 5 s were taken around the cuts, on which side is not recorded | Fewer bots; spikes not explained; no conclusion about bot count follows | B1 |
| 6 | Replacing a core row without reading the core's rule | Soul Erosion, Shadow Orbs at 100% | Live legendaries far over their intended rate until 18 Nov | Recipe 2 |
| 7 | A number changed repeatedly without the sum for each step | Rested XP: three values in ten hours on 12 Nov | Only the last can be re-derived | Recipe 11 |
| 8 | Shipping ahead of testing | 177 of 305 legendary copies and 280 of 1,710 epic copies "changed, awaiting in-game test"; `enchants/test-checklist.csv` has 561 rows | Unknown defect rate in live enchants | `wildcard-validation-and-qa` |
| 9 | An idea dropped with no record | View distance 75; kill XP 15% | Will be re-proposed and re-argued | B5 retirement record |
| 10 | Merging branches built for different cores | `main` into `for-083`, undone (ebc3c3d) | Branch patches replaced; a restore commit | Recipe 9 |
| 11 | A doc left behind by the settings | `docs/performance.md` says `BotActiveAlone` is "now 15"; settings have 5 since 7 Nov | A reader plans from a stale lever list | Result recorded where the next person looks |
| 12 | A commit message that disagrees with itself | 7a1f7a8 says 29 enchants, lists 33 | Wrong figure quoted later | Cite the file |

Patterns worth keeping, from the same history:

- The reasoning and the numbers in the comment above the setting (every example in Recipe 11).
- "Measuring only. Nothing changes how the server runs" as a separate change from any fix (9ba9f45).
- Temporary instruments that say in their own header when to delete them (cc145e5).
- Guesses labelled "assumed" in the commit, the row comment and the notes file.
- Recording "no doubling" and "fail" results, not only fixes and passes (99174fa, d2ebbdb).
- A compile check against the pinned core and a data simulation before spending a build (90ee10d, 5c2a489).

---

# Part B sections moved here from SKILL.md (full text)

## B5. The idea lifecycle

```
idea -> written down (issue, or case file for a judgement call)
     -> experiment behind a setting or in a removable SQL file      [classify first]
     -> prediction recorded (B2) -> run -> result recorded
     -> ADOPTED: default on, CHANGES.md line, settings comment with the reasoning
     or RETIRED: written record of what was tried, why dropped, the evidence
```

Where results are recorded today (doctrine): the tracker's `tested` column and `enchants/test-checklist.csv`
for enchants; a row in `docs/performance.md` for capacity; the dated comment above the setting; the generated
history files (`enchants/legendary-history.csv`, `enchants/epic-history.csv`); `CHANGES.md`.
**Proposed practice (not yet adopted by James):** every retired idea gets a retirement record (template in
`references/templates.md`) and an entry in `wildcard-failure-archaeology`. *Incident:* the 75-yard view
distance branch has no record of why it was never merged.

Real lifecycles, with commits, are in `references/lifecycles-and-sources.md`. Check it before proposing any of
these again: waking bots by radius instead of by zone (tried 8 Nov, bots froze, cause open); view distance 150
(backed out before going live) and 75 (never merged, no record); kill XP 15% lower (branch `xp-kill-rate`,
status unknown as of 2026-11-22). Two to copy: the Arcane Charge loop of 2 Nov (four attempts in 90 minutes,
one reverted, every result in the tracker) and the temporary slow-query log (added, used, removed in a day).

## B6. Where good ideas have come from here

Search order when stuck, cheapest first, each with a case from history
(table with evidence in `references/lifecycles-and-sources.md`):

1. **Measure.** The bot-count table; the slow-query log (cc145e5).
2. **Read the core for a precedent.** Hot Hands: "the core already did this for another Hot Hands spell"
   (`patches/66-enchant-core-hooks.ps1`).
3. **Reuse working data.** Twins and namesakes: 143 and 74 enchants (`docs/enchant-restoration.md`).
4. **Look for Ascension data nothing applies.** Battleground Dampening, which "CoA has but never applied"
   (b63e976).
5. **Read what the official build does.** Response files "as the official build" (2606a77).
6. **Simulate from the data files before a build.** Worldforged enchants (90ee10d).
7. **Ask who saw it in game, and exactly what.** Arcane Charge tests (d2ebbdb); the archived tooltips (b570a98).

## B7. Patterns to avoid, as seen here

Neutral statements; evidence, costs and counters are tabled in `references/lifecycles-and-sources.md`.

1. A plausible fix before any instrument (0cce098, eight hours before the slow-query log).
2. Several changes in one step (61a5be9, ff00757), or a fix with no after-measurement (240d773, f9dc45a).
3. Decisions from averages or single samples (the 7 Nov table; bot count then went 1,250, 1,000, 750).
4. Replacing a core row without reading the core's rule (Soul Erosion and Shadow Orbs at 100%).
5. Shipping ahead of testing: as of 2026-11-22, 177 of 305 legendary copies and 280 of 1,710 epic copies read
   "changed, awaiting in-game test" (`enchants/legendary-history.csv`, `enchants/epic-history.csv`).
6. An idea dropped, or a number changed several times in a day, with no record of why (view distance 75;
   rested XP on 12 Nov).

Worth keeping: the sum in the comment above the setting; "measuring only" as its own change (9ba9f45); guesses
labelled "assumed" and later corrected from a source (#165 and #166, then #169); "no doubling" and "fail"
written down as results (99174fa, d2ebbdb).

