---
name: wildcard-analysis-and-method
description: First-principles analysis recipes and the research method for the Wildcard server (CoA / AzerothCore 3.3.5a, about 750 bots). Load when a task needs to prove a cause or justify a number before changing anything ("prove it before changing it", "is this number justified") - proc rate and buff uptime arithmetic, an effect applied twice, a number chosen by analogy with a similar ability, tick budget and bot capacity, why averages hide spikes, a query that scans a whole table, a file or counter that grows or overflows, finding which layer owns a bug by swapping one, reading a patch diff for per-tick cost, drop-rate and XP sums. Also for turning a hunch into an accepted change - writing the prediction down before running, the evidence bar, one change at a time, a reviewer told to break the claim, preparing a Fable case file, retiring a failed idea in writing. Each recipe has a worked example from this repository. Not for running measuring tools, the lag campaign or acceptance thresholds.
---

# Wildcard: analysis recipes and research method

**Purpose.** Stop two failures that cost this project the most: a change shipped on a guess that later has to be
undone, and a 3½ hour build spent to learn something a sum on paper would have told you. Part A is eleven
ways to work a problem out first. Part B is the method that turns a hunch into a change James can accept.

Everything dated "as of 2026-11-22" was checked against the repository on that day. Numbers quoted from the live
server come from commit messages, settings comments and docs in the repo, not re-verified on the VM on 2026-11-22.

## When to use this skill

Use it when there is a symptom with more than one possible cause, a number to choose or defend, a patch or case
file whose reasoning must survive review, or a failed idea to close with a record.

## When NOT to use this skill

| You need | Use instead |
|---|---|
| How to read Timing.log, Logs/perf CSVs, mysql-slow.log, the settings report; analysis scripts for them | `wildcard-diagnostics-and-tooling` |
| The step-by-step plan for the live lag spikes | `wildcard-lag-spike-campaign` |
| Pass/fail thresholds, what counts as tested, the test inventory | `wildcard-validation-and-qa` |
| Risk class, hard stops, who merges | `wildcard-change-control` |
| The full list of past investigations and dead ends | `wildcard-failure-archaeology` |
| Symptom to first check, across all layers | `wildcard-debugging-playbook` |
| How procs, auras and `spell_proc` work in the core | `azerothcore-coa-reference` |
| The enchant source hierarchy, recipes and tracker conventions | `ascension-restoration` |
| Writing the patch once the analysis is done | `wildcard-patch-authoring` |

**Change control comes first.** Nothing here authorises a change. Any step that changes server behaviour
(a setting, SQL, a patch, an addon): classify with `wildcard-change-control` first, respect the hard stops, and
James merges. Analysis and read-only measurement need no classification.

## Words used here

| Term | Meaning |
|---|---|
| Tick | One pass of the world server's main loop. Everything in the world (players, bots, creatures) is updated once per tick. Tick time in milliseconds is how "lag" is measured here. |
| Percentile | "95% under 64 ms" means 95 of every 100 ticks took 64 ms or less. The 99th percentile and the worst tick describe the tail: the rare slow ticks. |
| Proc | An effect that fires by chance when something happens (a hit, a cast). |
| Internal cooldown (ICD) | The shortest time allowed between two procs of the same effect. |
| `spell_proc` | The world-database table that tells the core when an aura may proc: which abilities, what chance, what cooldown. |
| Twin | The same enchant made for another realm type, under a different spell id, that works. Linking a broken enchant to its twin is a standard fix here. |
| Hot path | Code that runs very often: every tick, every packet, or for every bot. |
| Mechanism | A specific, checkable chain of cause and effect ("each login deletes by spell id, with no index, so it scans 1.7 million rows"), as opposed to a label ("the database is slow"). |
| Case file | The two-page form in `docs/agents/case-file-template.md` that carries a question to the Fable model. |

Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## The calculator

`scripts/wcalc.py` (Python 3, standard library only; tested on 2026-11-22 against every worked example below).
It reads nothing from the server. Run it from this skill's folder:

```
python3 -I scripts/wcalc.py --help
python3 -I scripts/wcalc.py proc --chance 0.33 --triggers-per-min 60 --icd 4
```

Commands: `proc`, `jump`, `ticks`, `amdahl`, `spike`, `mojibake`, `overflow`, `drops`, `rate`. Each recipe
below names the one it uses; `references/worked-examples.md` has the exact command for every example.

---

# Part A: analysis recipes

Each recipe: when to use it, the steps, the sum, and a worked example from history. The full working for every
example, with the commit trail, is in `references/worked-examples.md`; read it when you apply a recipe for the
first time or need the evidence to cite.

## Recipe 1. Proc rate and uptime

**Use when** an enchant fires on every hit, never fires, or you must pick or check a chance.

**Background you need.** Ascension kept each enchant's proc rules (which ability sets it off, the chance, the
internal cooldown) in its own server database; the spell data that survives has them blanked
(`docs/enchant-restoration.md`, Lessons). So on this core:

| What the aura has | What happens |
|---|---|
| Proc flags, no `spell_proc` row | Fires on every qualifying hit, no ability filter, no cooldown: a **runaway** |
| No proc flags, no `spell_proc` row | Never fires: a **dead trigger**. A twin can look fine and be dead |
| A `spell_proc` row | Fires as the row says (chance, cooldown in ms, family mask) |

**Steps**
1. Write down what the tooltip says in your own words: which abilities, what chance, what cooldown, what the buff
   lasts. Never paste tooltip text into the repo.
2. Read what the data says: the aura's proc flags and whether a `spell_proc` row exists (see
   `azerothcore-coa-reference` for the columns).
3. Estimate triggers per minute for a realistic player (count casts in a rotation; if unknown, say so and give
   a low and a high case).
4. Compute, then compare with the tooltip's intent:
   - procs per minute with no cooldown = triggers per minute x chance
   - with a cooldown: one proc every `cooldown + 1 / (chance x triggers per second)` seconds on average
   - ceiling from the cooldown alone = 60 / cooldown
   - uptime of a buff that each proc refreshes: use `wcalc.py proc --duration`
5. State the expected count for the in-game test before testing ("about 8 procs in a minute of hitting a
   dummy, never two within 4 seconds").

**Worked example (file 015).** Rows such as `(965505, ... Chance 33, Cooldown 4000)` in
`sql/enchants/015-runaway-procs.sql`. Take 60 qualifying hits a minute as an illustrative input (not measured):
before the fix the enchant fired on all 60; with 33% and 4 s it fires about 8.5 times a minute and can never
exceed 15. That is a 7-fold drop from one database row, with no build. Where the tooltip states no cooldown the
file uses 0.1 s (100 ms), which caps nothing in normal play but stops one hit setting off a chain (cde036b).
File 016 is the mirror case: no flags and no row, so zero procs however good the chance looked on paper.

## Recipe 2. Double application

**Use when** an effect is stronger than intended by a clean factor (x2, +16% instead of +8%), or you are adding
something the core, a twin or the client may already do.

**Steps**
1. List every source that can apply the effect: the core's own rule for that spell, the twin linked in
   `spell_linked_spell`, our SQL row, our script, the client's copy of the rule.
2. For each source, find where the number enters the sum and in what unit (a fraction such as 0.8, percentage
   points such as 20, a percent multiplier).
3. Work one case by hand with both the intended and the suspected arithmetic. The buggy version usually gives a
   distinctive figure you can look for in game.
4. Remove the duplicate at the layer you own; leave the core's own row as it ships where it is correct.
5. Record the check ("no doubling" is a result worth writing down: several of the 18 Nov reviews end that way).

**Worked example (patch 71).** Ascension data writes "loses 20% less per jump" as a flat +20 on the jump
multiplier. The core added the 20 straight onto the 0.8 multiplier (figures from the header of
`patches/71-jump-multiplier-points.ps1`):

```
hit            1      2       3        4
unmodified     1    0.8    0.64    0.512     (x0.8 per jump)
bug            1   20.8   432.6  8,998.9     (0.8 + 20 = 20.8 per jump)
fix            1      1       1        1     ((0.8 x 100 + 20) / 100 = 1.0 per jump)
```

So each jump was about 21 times the last instead of losing less. The fix converts to points, applies the
modifier, converts back (`wcalc.py jump`). **Two-source example.** Soul Erosion: our SQL replaced the core's
proc row with one at 100%, so the core's rule fired on every tick and our own 8% rule ran on top (f9806da).
Moon's Wrath: the core already gave +8% crit and our hook added it again, +16% (5bf04bd). The 18 Nov reviews
left standing lists: `enchants/core-proc-row-replacements.csv`, `enchants/swap-own-effects.csv`.

## Recipe 3. A number by analogy

**Use when** no record of a number survives. James's stated rule for intended behaviour: the client tooltip
wins, then designer intent, then copy similar abilities (damage against damage, area against area, heal against
heal), then an educated guess; outliers go to James. The repo names this "the conflict rule"
(`docs/agents/README.md`) without spelling it out as of 2026-11-22; `ascension-restoration` is its home.

**Steps**
1. Confirm the number really is missing: tooltip (paraphrased), client spell data, the core's class version of
   the same ability (`enchants/legendary-notes-header.md`, source 3).
2. Pick the analogue by type, and say why it is the right one in one line.
3. Do the sanity sum: what does this number do per minute or per fight next to the analogue (Recipe 1 or 11)?
4. Record it where the next person will look: the SQL row comment or script comment, and the `assumptions`,
   `sources` and `decisions` columns of `enchants/legendary-notes.csv` or `enchants/epic-notes.csv`. Mark the
   word "assumed" in the commit and in `CHANGES.md` where the number is listed.
5. If James then decides the number, record it as his decision with the date and his reason.

**Worked example.** Blood Drinker (965389): the data has no amount and the text describes a small, attack-power
based heal, so it was set to 3% of maximum health plus 25% of attack power, by analogy with Bloodthirst's own
small percentage heal; the decisions column carries "2026-11-17 James: assumptions and new features are fine;
base missing numbers on similar existing spells" (`enchants/epic-notes.csv`). Consecrated Strikes: 20%
"assumed" (bbb213c), then 35% as James's call the same day (730ecea), his reason kept in
`enchants/legendary-notes.md`; `CHANGES.md` still prints "35% assumed". Contrast: Abiding Fel Energy's
87 + 20% AP + 30% SP came from the archived builder tooltip (b570a98): sourced, not assumed.

## Recipe 4. Tick capacity and throughput

**Use when** choosing a bot count, map threads, wake rules or view distance.

**The sums**
- Saturated loop: ticks per second x average ms is about 1,000. Then ticks/s is only 1000 / average and adds
  nothing. An idle server spins at about 250 ticks/s (`docs/performance.md`).
- Cost per bot: average ms / bots. Compare setups by this, not by raw ms.
- Threads: if N threads took a tick from A ms to B ms, the share that did not speed up is
  `(B/A - 1/N) / (1 - 1/N)`. Above about half, more threads or cores buy little.
- Awake bots: every bot in a player's zone stays awake (`AiPlayerbot.BotActiveAloneForceWhenInZone = 1`), so
  awake bots grow with the number of zones players stand in, up to the total bot count.

**Worked example (the 7 Nov table, `docs/performance.md`).**

| Setup | Ticks/s x avg | Per bot | Reading |
|---|---|---|---|
| 1,000 bots, 1 map thread | 33 x 30 = 990 | 30 microseconds | Saturated: one core busy, seven idle |
| 1,000 bots, 4 map threads | 50 x 20 = 1,000 | 20 | 1.5x faster, not 4x: 56% of the tick did not speed up |
| 1,500 bots, 4 map threads | 26 x 38 = 988 | 25 | 1.5x the bots cost 1.9x the time |
| 1,250 bots, 4 map threads | 30 x 33 = 990 | 26 | |

The 56% is the doc's own conclusion in numbers: "one busy thread per map" limits the server, because most bots
are on the two continents and each map is updated by one thread. The 1,250 decision compared tails, not
averages: the 95% figures were 64 and 66 ms, but the peak was 112 against 301 ms, "a third as large" (112 / 301
= 0.37). Worst case in the doc: 10 zones x 200 bots is about 2,000 awake, more than this CPU carries.
**Limits** (state them when you cite the table): one sample per setup and no record of players online, so it
gives direction only. 1,250 became 1,000 on 9 Nov (ff00757) and 750 on 21 Nov (6a3e017).

## Recipe 5. Tail analysis

**Use when** players report freezes and the average or median tick looks healthy.

**The sum.** Take a 36 ms typical tick and one 3 s tick a minute. That minute holds about 1,584 ticks, so the
long one is 1 in 1,584 (0.06%). The mean moves from 36 to 37.9 ms. The 95th, 99th and even 99.9th percentiles
do not see it. A player feels a 3 second freeze every minute.

**Steps**
1. Never accept an average as evidence about spikes. Ask for the worst tick and the count of ticks over a
   threshold per hour, with timestamps.
2. Compare the percentile ladder. A 99th percentile many times the 95th means two regimes: something different
   happens in the slow ticks, not "everything is a bit slow".
3. Line the slow ticks up against a clock: what else happened at those seconds (saves, logins, log writes, a
   scheduled task, a backup)?
4. Name one mechanism and write its prediction (Part B) before changing anything.

**Worked example (20 and 21 Nov).** With about 880 bots: 95% under 69 ms, 99th percentile 586 ms, worst 2.9 s.
586 / 69 is 8.5: two regimes. Mechanism proposed: log lines written in line with the world update, the console
taking every bot's rolls and challenge packets, `world-console.log` at 2.9 GB. Fix, settings only:
`Log.Async.Enable = 1` and two logger lines (f9dc45a, PR #204). **What the record does not show:** an
after-measurement. The next day James reported worst ticks of 2 to 5 s with 2 players on and a 36 ms median
(6a3e017). Status in the library's agreed words: shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run yet; status OPEN. Removing synchronous console
logging was a sound thing to try; it has not been shown to be the cause of the spikes. The
response was instruments first (9ba9f45, PR #225, "Nothing changes how the server runs"). Treat the case as
open and go to `wildcard-lag-spike-campaign`.

## Recipe 6. Query cost

**Use when** a player-facing wait points at the database (character list, login, auction search, mailbox).

**Steps**
1. Turn on a slow-query log for the investigation, with a threshold below the wait you are chasing: a file in
   `sql/enchants/`, applied at every start and removed by deleting the file (a change: classify it first).
2. Read the logged statement. Ask: which column does its `WHERE` use, and is there an index on it? No index
   means the cost is proportional to the rows in the table, every time it runs.
3. Multiply: rows scanned x how often it runs (remember bots log in too) x who waits behind its locks.
4. Predict: with an index the statement drops out of the slow log entirely and the wait falls to under a second.
5. Fix at the narrowest layer (an index is additive and reversible), confirm, then remove the instrument or
   keep it on purpose with a comment that says "measuring only".

**Worked example (8 Nov).** "Retrieving character list" took about 40 s. At 00:43 a fix shipped on a plausible
theory with no measurement: requests queue behind bot logins on one connection, so add connections (0cce098).
The wait was still there at 08:31, when a temporary slow-query log over 1 s went in (cc145e5, PR #82). It
showed the core's delete-by-spell-id on `character_spell` and `character_talent`: CoA teaches every character a
hidden spell at login that the Wildcard world lacks, so every login, bots included, scanned about 1.7 million
rows and held locks. Fix: `EnsureCharacterSpellIndexes` in `patch-night/PatchNight.ps1` adds `idx_spell` once
(257158e, PR #84). Recorded result: 40 s to under 1 s; temporary log removed the same day (ea01588, PR #86).
`EXPLAIN` would show the same thing (full scan before, index lookup after); history does not record it being
run, so use it as a cross-check, not as cited evidence.

## Recipe 7. Growth arithmetic

**Use when** a file, table or log is far bigger than it should be.

**Steps**
1. Get two sizes and the number of write cycles between them.
2. Decide the shape: **adding** (a fixed amount per cycle) or **multiplying** (part of the content multiplies
   each cycle, so size roughly doubles). Divide growth by cycles: 21.8 MB over 16 writes would be 1.4 MB
   appended per write, which nothing in a settings script does. So it multiplies.
3. Find what is multiplied, solve for the seed, predict what the content must look like, then open the file.

**Worked example (22 Nov).** `playerbots.conf` went from 240 KB to 22 MB after 16 writes (ba59783, PR #229).
Windows PowerShell read the UTF-8 file as Windows-1252 and wrote it back as UTF-8: ASCII is unchanged, each
non-ASCII byte becomes 2 or 3 bytes per write. At x2 per write, 16 writes multiply by 65,536, so about 340
bytes of non-ASCII text at the start (an en dash, a Cyrillic addon prefix) explain all 22 MB: at most 0.15% of
the file. Predictions that held: one SQUID value with that prefix no longer matched, and undoing the same step
restored the file exactly ("back to 243 KB, every restored line identical to the .dist"). Sum:
`wcalc.py mojibake`.

## Recipe 8. Overflow and units

**Use when** something works on small test data and fails at real sizes, or a figure is absurd or negative.

**Steps**
1. Write the largest real value each quantity can take (bytes of the whole client, milliseconds, rows x rows).
2. Write the type that holds it at each step, including the type the language picks for a literal.
3. Compare with 2,147,483,647 (signed 32-bit: just under 2 GB, or about 24.8 days in milliseconds).
4. Check units at every boundary: seconds or milliseconds, percent or fraction, per mille or percent.

**Worked example.** The friends' launcher computed progress with `[Math]::Max(1, $total)`. With an integer
literal PowerShell chose the `int` version, and the 46 GB install total (49.4 billion bytes, 23 times the
limit) overflowed it. The fix casts both sides to `double` (99f4fa7, PR #73). A small test folder could never
have shown it; only the sum finds it in advance. Sum: `wcalc.py overflow --gb 46`.

## Recipe 9. Differential diagnosis by layer swap

**Use when** you cannot tell which layer owns a fault. Change exactly one layer, keep everything else, and see
whether the symptom follows.

| Swap | What it separates | How here |
|---|---|---|
| Official world server against patched | Our patches from CoA's own code | Patch night already falls back to the official server if the patched one fails its start check (bc0110d); a deliberate swap changes what players get, so classify it first |
| One core release against the previous | A CoA update from our changes | `Logs/console-history.txt` was built "to compare update times before and after the 19 Nov core update" (9ba9f45) |
| Our build recipe against the official build | Our workflow from the code | Compare with `Corfirean/coa-server-build` |
| Core's rule against our SQL or script | Which of two sources acts | Recipe 2 |
| Client's copy of a rule against the server's | Display or client-side refusal from server logic | Read the client data; test with the server value changed |
| Setting on against off | One feature from the rest | Any change with a setting in `CHANGES.md` |

**Steps.** List the layers between the player and the fault (client, addon, client patch, settings, SQL, our
patches, module, core, database, VM). Pick the swap that halves the list and costs least: settings and SQL cost
a restart, a patch costs a build. Predict both outcomes before swapping. Swap one thing, and record what did
not change as well as what did.

**Worked examples.** Build 57 stopped at start-up with "Duplicate blank sub-command". Comparing our build
recipe with the official one found it: the official build patches SQUID so its own auction house bot never
registers; ours took SQUID unchanged (01159e2, PR #187). Rune currency: the Wildcard window refused purchases
with plenty of runes owned; the client's own code counts only the 32 currency slots, so the fault was a client
rule and the server fix was to move the runes (b4f61e9, PR #200). A caution: `main` and `for-083` target
different cores; merging one into the other had to be undone (ebc3c3d), and
`docs/agents/context/patches.md` now forbids it.

## Recipes 10 and 11. Reading a diff for hot-path cost; rate and economy sums

Full text, with the worked examples, at the end of `references/worked-examples.md` ("Recipe 10", "Recipe 11").
Recipe 10: for a patch that adds a hook, count how often the hook runs (per tick, per player, per bot) and what
it does before its first early return. Recipe 11: for a drop rate, XP rate or price, write the sum per hour of
play before choosing the value.

---

# Part B: the method

## What is doctrine and what is proposed

**DOCTRINE (written in README, CHANGES.md or docs on `main`, including the rows whose source is `docs/agents/*` or
`.claude/agents/*`, on `main` since PR #232 merged on 22 Nov 2026), as of 2026-11-22, status re-checked 24 Nov:**

| Rule | Where |
|---|---|
| Every change is classified before merge; L4 "proof before going live" and L5 "understanding" are scored 1 to 3 | `docs/agents/context/change-risk.md` |
| Every new code change gets a setting to turn it off where practical, and a line in `CHANGES.md` | `CHANGES.md`, "How changes are made" |
| "One PR per patch night" | `CHANGES.md`. Practice differs: 205 PRs merged in 24 days, 31 on 8 Nov alone. Both are true; this skill does not resolve it |
| The patch reviewer has not seen the author's reasoning and does not take the description's claims as checked; a finding it could not confirm is reported as a question | `.claude/agents/patch-reviewer.md` |
| Fable never gathers its own context; every answer becomes a precedent; every call gets a ledger line | `docs/agents/README.md` |
| A fix passes when it does what its tooltip says; write result and date in the tracker's `tested` column | `docs/enchant-restoration.md` |
| Assumptions, sources and decisions are recorded per enchant; compile checks and scratch-database loads do not replace in-game testing | `enchants/legendary-notes-header.md` |
| A failed anchor costs a whole build, so test the script against the pinned sources before pushing | `docs/agents/context/patches.md` |

**Everything else in Part B is "Proposed practice (not yet adopted by James)".** Each proposal states its
purpose and the incident behind it. `wildcard-change-control` keeps the register of proposals; add these there
rather than treating them as rules.

## B1. The evidence bar

**Proposed practice (not yet adopted by James).** *Purpose:* stop a fix being accepted because it is plausible.
*Incident:* on 8 Nov a database-connections change shipped for the slow character list on a reasonable
theory, and the wait stayed until the slow-query log found the real statement eight hours later; the 20 Nov
logging change (f9dc45a; no after-measurement, status OPEN) was followed by 2 to 5 s spikes on 21 Nov.

A cause is accepted when all four hold:

1. **One mechanism.** A single chain of cause and effect, specific enough to be wrong.
2. **It explains every observation, including the negatives.** List what did not change. For the lag spikes
   the record so far gives: the median stays near 36 ms; they happen with only 2 players on (and, on 22 Nov, with
   one); with nobody on there are none; worst ticks were 1.3 s (3 players, read around the cut from 1,250 to 1,000 on 9 Nov) and 2 to 5 s (2 players, read around the cut from 1,000 to 750 on 21 Nov); the record does not say which side of each cut the reading was taken on, so no conclusion about bot count follows. A mechanism that needs a second story for any of these is not the cause.
3. **It predicted a number before the run** (B2) and the number came in.
4. **It survived an assigned attempt to break it** (B3).

Until then, describe the cause as "candidate" in commits, comments and docs. This maps onto L5 of the risk
matrix: "a guess" scores 3, "plausible from the code" 2, "cause reproduced with evidence" 1.

## B2. Predict the number before you run

**Proposed practice (not yet adopted by James).** *Purpose:* make every experiment able to fail. *Incident:*
the comment added with view distance 150 is the good pattern already in the repo: "watch the tick summary ...
if spikes get worse, try 125" (7001de0). The wake-radius change stated its theory ("each extra player costs a
circle, not a zone") but no expected figure, and no after-measurement was recorded for the 5%-awake change
(240d773) or the logging change (f9dc45a).

Write this in the PR description or case file **before** the change goes live (copy from
`references/templates.md`):

```
Prediction (written <date/time>, before the run)
Mechanism:      <one sentence>
Baseline:       <metric> = <value>, measured <when>, <how long>, <players on>, <bots>
If I am right:  <metric> will be <number or range> within <time window>
If I am wrong:  <metric> will stay about <value>  (this must be a possible outcome)
Will NOT change: <metrics that must stay put if the mechanism is the only cause>
Undo:           <setting back to X at next restart | revert and rebuild>
Result (written after): <value>, <when>; prediction held | failed; next step
```

A prediction that cannot fail is not a hypothesis. "Should help with lag" fails this test; "99th percentile
tick falls from 586 ms to under 150 ms while the 95% figure stays within 10 ms of 69" passes it.

## B3. Assigned adversarial refutation

**DOCTRINE (PR #232, merged 22 Nov 2026) for patches:** a PR that changes `patches/` gets the Fable `patch-reviewer`, which sees only the diff
and the description. **Proposed practice (not yet adopted by James)** for everything else that claims a cause (a
lag diagnosis, a balance finding, a "the core already does this" claim): give the claim to a separate session
that has not seen your reasoning, with the instruction to break it. *Purpose:* the author cannot see their own
blind spot. *Incident:* our SQL had replaced the core's proc rows for Soul Erosion and Shadow Orbs at 100%;
it was found only when someone went back on 18 Nov to check each enchant against the core.

The brief for the refuter is in `references/templates.md`. Use a cheaper model first. Spend Fable only as
`docs/agents/README.md` says: a case file from `docs/agents/case-file-template.md`, one call, the ruling written
back as a precedent, one ledger line. As of 2026-11-22 `docs/agents/cases/` does not exist and the ledger has
no rows: the first case sets the pattern. The Fable "crash and lag investigator" is Stage 2: **NOT BUILT YET**.

## B4. One change at a time, baseline first, reversible first

**Proposed practice (not yet adopted by James).** *Purpose:* be able to say which change did what.
*Incidents:* 61a5be9 changed the MySQL buffer pool, redo log, flush rate and map threads in one commit while
the VM also went from 8 to 10 cores; ff00757 changed view distance and bot count together. Neither effect can
now be separated.

1. Take a baseline with the same instrument, same time of day and player count where possible, long enough to
   contain the thing you are chasing (for a once-a-minute spike, at least an hour).
2. Change one thing.
3. Order of preference, cheapest and most reversible first: read-only measurement; a setting in
   `server-settings.txt` (undo at the next restart: I3 = 1 in the matrix); SQL that `000-reset.sql` or a
   deleted file removes; an addon; a C++ patch (undo is revert and rebuild, about 3½ hours: I3 = 2).
4. If a C++ change is unavoidable, give it a setting (doctrine) so the experiment after the build is a toggle.

## B5 to B7. The idea lifecycle, where good ideas came from, patterns to avoid

All three are **Proposed practice (not yet adopted by James)** and live in full, with their evidence, in
`references/lifecycles-and-sources.md` (sections "B5", "B6", "B7" at the end of that file). In one line each:
B5, an idea moves from experiment setting to adopted change or to a written retirement, never to silence; B6,
the good ideas here came from measuring first and from reading the upstream code; B7, the repeated mistakes are
several changes in one step, no after-measurement, and deciding from an average or a single sample.

## B8. How this plugs into change control and the Fable budget

| Doing this | Moves this score | From to |
|---|---|---|
| Mechanism reproduced with a log line or a test (B1) | L5 Understanding | 3 or 2 to 1 |
| An automatic check or a recorded test proves it (B2 result) | L4 Proof before going live | 3 to 2, or 1 when automatic |
| Experiment as a setting, not C++ (B4) | L1 Kind, I3 Undo | 3 to 1; 2 to 1 |
| Reusing a pattern that went in cleanly (B6) | L6 Precedent | 3 to 1 or 2 |
| Gate in front of the expensive work (Recipe 10) | L3 Where it runs | stays 3 if per tick: say so honestly |

Likelihood totals 6 to 8 are low, 9 to 12 medium, 13 to 18 high. Two points off L4 and L5 is often the
difference between bands, and so between "James merges" and "Fable review, then James merges". Do not score
your own change: the `change-risk-analyst` does, "from evidence in the diff and the code it touches". Your job
is to put the evidence where it can find it: in the PR description.

Note on L4: "an automatic check proves it" needs a check that exists. As of 2026-11-22 the only CI is the build
workflow and no automated tests exist, so most changes cannot honestly score L4 = 1 yet; see
`wildcard-validation-and-qa`.

**Fable budget.** A case file prepared with this method is short because the work is done: the question is one
sentence, every fact has a source, the unknowns say what would close them. That is what "Fable never gathers
its own context" needs. If you cannot fill "What we know" with sourced facts, you are not ready to spend a call.

## Checklist before you claim a cause or propose a number

- [ ] One mechanism, written as a sentence that could be false
- [ ] Every observation listed, including what did not change; none left unexplained
- [ ] The sum done on paper or with `wcalc.py`; inputs that are assumptions marked as such
- [ ] Prediction with a number written before the run, with a possible "I am wrong" outcome
- [ ] Baseline taken with the same instrument
- [ ] One change, the most reversible kind that answers the question
- [ ] Classified with `wildcard-change-control` before anything changes on the server
- [ ] Result written where the next person looks (tracker, settings comment, `docs/performance.md`, PR)
- [ ] If dropped: retirement record written, handed to `wildcard-failure-archaeology`

## References

- `references/worked-examples.md`: read when applying a recipe for the first time, or when you need the full
  working and commit trail for an example.
- `references/lifecycles-and-sources.md`: read when judging whether an idea has been tried before, or when you
  need the evidence behind B5 to B7.
- `references/templates.md`: read when you are about to write a prediction, a refutation brief, a case file or
  a retirement record.

## Provenance and maintenance

Written 2026-11-22 from the repository checkout `fcfee51` (PR #232's head: `62a26e4`, the #230 merge, plus two
commits adding `.claude/agents/` and `docs/agents/`; `origin/main` is `d3e030f`, #231) and its full history. Live
numbers are quoted from the repo; the first day of instrument readings (22 Nov) is in `wildcard-lag-spike-campaign`. Re-verify before relying on anything
that drifts (run from the repository root):

```
cat docs/performance.md                                   # the table and thresholds
grep -nE "RandomBots|BotActiveAlone|MapUpdate.Threads|Visibility.Distance|Log.Async|Logger.coa" server-settings/server-settings.txt
grep -nE "CardDrop|Rate.XP|Rate.Rest|PriceMultiplier|KillXPPercent" server-settings/server-settings.txt
cat docs/agents/context/change-risk.md                    # L1-L6, I1-I4, bands, paths (on `main` since PR #232 merged on 22 Nov:
                                                          # git show origin/main:docs/agents/context/change-risk.md)
cat .claude/agents/patch-reviewer.md docs/agents/README.md
ls docs/agents/cases; tail -3 docs/agents/fable-ledger.md # still no cases, no ledger rows?
cut -d, -f4 enchants/legendary-history.csv | sort | uniq -c | sort -rn | head -4   # untested counts (rough)
git show -s --format='%h %ad %s%n%b' --date=short HASH  # any commit cited here
git log origin/main --merges --ancestry-path HASH..origin/main --format='%h %s' | tail -1   # its PR
git log origin/xp-kill-rate -1 --format='%h %ad %s' --date=short        # unmerged idea branches
git log origin/perf-visibility-react -1 --format='%h %ad %s' --date=short
git log origin/main --first-parent --merges --format=%ad --date=short | sort | uniq -c | sort -rn | head -3
python3 -I .claude/skills/wildcard-analysis-and-method/scripts/wcalc.py jump   # the calculator still runs
```

Maintenance rules: add a worked example only with a commit or file to cite; when an open case here closes (the
lag spikes, the frozen bots near players, kill XP), update its row and say what closed it; when James adopts a
proposed practice, move it to the doctrine table and name the file where he wrote it down.
