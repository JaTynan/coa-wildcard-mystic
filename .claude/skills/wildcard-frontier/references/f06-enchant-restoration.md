# F6. Goal B: complete the Mystic Enchant restoration

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Classify every step with `wildcard-change-control` first.

This file says what is worth doing next and why. How to fix one enchant, the recipes, and the conflict rule
(client tooltip, then designer intent, then similar abilities, then an educated guess; outliers to James) belong to
`ascension-restoration` and `docs/enchant-restoration.md`.

## 1. Goal and owner

Every Mystic Enchant offered on the realm either works as its tooltip says, or is knowingly held out of the rolls
with a written reason. Owner: James, goal B. It is his third priority, after lag and the pipeline.

## 2. Where the project stands (2026-11-22)

From `python3 -I -B .claude/skills/ascension-restoration/scripts/tracker_summary.py` (status and fix counts) and
`python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py` (tested counts). "Tested"
here means a tracker row with a non-empty `tested` column (49 rows); the checklist's "35 of 561 with a result" is a
different count:

| Measure | Number |
|---|---|
| Enchants on the realm | 6,440 |
| "working (audit)": the audit says the spell data should work; nobody has checked them in game | 4,331 (0 with a test note) |
| "live" or "live (after restart)": a fix is applied | 653 + 875 = 1,528 (8 with a test note) |
| "verified" | 27 |
| "broken" | 424 (276 need code, 148 teach a broken spell) |
| "partly working" | 119 |
| "missing" | 11 |
| Rows with a fix recorded (non-empty fix column) | 1,565, of which **45 have a test entry (2.9%)**; 49 tracker rows have one in all. By status instead (`live`, `live (after restart)`, `verified`) it is 1,555 and 35 |
| Dates of every test note in the tracker | 31 Oct (4), 2 Nov (10), 3 Nov (35). **None since 3 November** |
| Checklist rows waiting for a result | 526 of 561 |
| Legendaries (305): changed and waiting for an in-game test | 180, plus 1 that needs a retest; tested 5 (counting rule and the 29 rows with a stale "unmerged" label: `ascension-restoration/references/state-2026-11-22.md`) |
| Epic copies (1,710 rows): changed and waiting | 280, plus 1 that needs a retest; tested 28 (163 more carry the stale "unmerged" label) |

Other facts:
- What is left, by the one piece of code that would unlock each group (`docs/enchant-restoration.md`, "Next
  candidates"; counts for the whole realm, the Area-52 part in brackets):

  | Group | Count | Needs |
  |---|---|---|
  | Extra damage under a condition (target has your aura, health above or below a mark, stealth, a form) | 32 (18) | One generic C++ handler: a table of (enchant, spells or school, condition, percent) used in the damage hooks |
  | Auto attacks deal extra damage as a school (the forged weapons) | 6 (6) | The same handler with one more rule |
  | Cooldown cut or reset on an event the action table cannot see | about 20 (12) | New triggers for `spell_wcme_enchant_action`: aura removed, stance changed |
  | Teaches or transforms into an ability we do not have | 43 (32) | A client patch or a namesake, case by case |
  | Procs with a chance | 62 (24) | Action table rows read by hand from each tooltip. No new code |
  | Everything else | about 360 (94) | One-off C++; many have tooltips made only of variables and need research first |
  | Missing, not simple | 11 (11) | Read by hand |

- The Death Knight proposal needs two more triggers ("kill" and "dodge or parry taken") for the same action table
  (`docs/dk-enchant-proposal.md`, "What it takes").
- **The dud filter has a known hole.** Enchants whose spell "does nothing" are kept out of scroll rolls
  (`CoA.MysticEnchants.SkipDudSpells`). `README.md` says about 70 enchants that work only through hard-coded C++
  checks look identical and are left out too; `docs/enchant-restoration.md` ("Lessons") speaks of "the 36 enchants
  handled by C++ that the dud filter cannot see". The two numbers disagree and neither has a list in the repo.
  `wcme_enchant_override (enchant_spell, roll)` exists to force one in or out.
- The generated history files mark 163 epic rows and 29 legendary rows as "changed on an unmerged branch". Those
  files are generated (`scripts/legendary_history.py`); regenerate before trusting the count.

## 3. Why the current approach falls short

- **Writing fixes is no longer the limit; testing is.** About 1,500 fixed enchants have never been tried in game,
  and no test note is newer than 3 November, while hundreds of fixes merged after that date (the legendary and epic
  batches of 15 to 18 November). Each untested fix is a guess presented to players as a working enchant.
- **The 4,331 "working" enchants are an audit verdict**, not an observation. The worldforged family (patch 78)
  showed the core can be wrong about its own enchants (it gave a bonus to every hit that belonged to one ability).
- **One-off C++ does not scale.** About 360 enchants each need their own code, and each batch costs a build and a
  review.
- **The dud filter cannot tell "works through C++" from "does nothing"**, so some working enchants never roll and
  nobody has the list.
- **Sources are thin.** Ascension is gone. Intended behaviour comes from the client tooltip, the archived builder
  page, the client's spell data and players' memories. A fix can match its tooltip and still be wrong.

## 4. This project's asset

- **The tracker**: one row per enchant with status, fix file, twin and a `tested` column; plus the generated
  history files that tie each legendary and epic to its commits, PR, first build and first night live.
- **Table-driven handlers already work**: the action table (`wcme_enchant_action`), aura links, the teach table,
  the SpellAffect table. A new enchant in an existing pattern is a row of SQL, applied at the next 4:00 am restart,
  removed by deleting the row. The matrix lists "an enchant SQL fix re-applying an existing pattern" as a standard
  change (always LOW).
- **Start-up self-checks**: the filters are computed at every start from the live data, not kept as lists, so a
  repaired enchant returns to the rolls by itself.
- **A written conflict rule and James's standing decisions**: a workable best guess beats a missing enchant;
  prefer permanent code fixes to database stopgaps; base missing numbers on similar spells; flag tooltip and
  mechanics differences for review; record sources and assumptions per fix.
- **Player reports** (F3) are test results that cost nothing.

## 5. First three steps in this repo

### Step 1. Burn down the quick tests before writing more fixes

- No code. Work the checklist's `twin` (137 waiting) and `teach` (120 waiting) rows, which take seconds each by
  hand today and far less with F5's self-test addon. Fill `result`, copy to the tracker's `tested` column with the
  date and build, regenerate the history files with `scripts/legendary_history.py`.
- Add a "tested" line to `docs/enchant-restoration.md`'s "Where we stand" table for the date.
- **Class estimate:** LOW (data files and documentation; nothing on the server changes). A failed test becomes a
  fix, which is classified on its own.

### Step 2. Name the C++-only enchants and decide each one

- Produce `enchants/core-handled.csv`: every enchant the dud filter drops although the core handles it in C++,
  with where the core handles it. Start from the two existing claims (about 70, and 36) and settle the number.
  `enchants/enchant_audit.py` and the existing `enchants/core-*.csv` review files are the starting material.
- For each one spot-checked in game, add a `wcme_enchant_override` row (roll = 1) in a new
  `sql/enchants/` file, with the test date in the row's comment.
- **Class estimate:** the list is documentation (LOW). The SQL re-applies an existing pattern: a standard change
  if James agrees it fits that line; otherwise score it (it changes what scrolls can roll: impact check I4 = 2).

### Step 3. The generic conditional-damage handler (unlocks 38 enchants as table rows)

- One patch script (`patches/NN-enchant-damage-rules.ps1`) adding a table `wcme_enchant_damage_rule`
  (enchant, spell list or school, condition, percent) read once at start, applied in the three damage hooks named
  in "Next candidates"; plus one SQL file of rows. Ship it with 3 to 5 rows first, not all 38.
- It runs on every hit by every player and all 750 bots, so it must cost nothing when the attacker has no such
  enchant (check a per-player flag first, never query the database in the hook).
- Needs: a setting to turn it off (`CHANGES.md` rule), a `CHANGES.md` row, the `patch-reviewer` (it changes
  `patches/`), a build, and the tick budget (F4) watched on the night it goes live.
- **Class estimate:** C++ (L1 = 3), every hit for all bots (L3 = 3), only seen working live (L4 = 3): likelihood
  high. Expect **HIGH: Fable review, James merges.** Much cheaper to get right after F1 step 2.
- The same pattern then applies to the action-table triggers (aura removed, stance changed, kill, dodge or parry),
  about 20 enchants plus the Death Knight drafts.

## 6. Milestone

**You have a result when**, within 30 days, the number of fixed-but-untested rows (1,520 on 22 Nov: 1,565 with a
fix minus 45 with a note) is **under 760**, with every new note carrying a date, a build tag and whether it was a
hand or automatic test, and **zero** enchants moved to "verified" without one.

For step 3: **you have a result when** at least 30 of the 38 enchants in the two damage groups are "live" with a
passing test note within 14 days of the handler's build, and the tick budget passes on each of those nights.

It is falsified if the untested count is not falling by at least 150 a week after step 1 starts (testing is still
the limit: put effort into F5, not into more fixes), or if more than 1 in 5 tested fixes fail (the fixing method,
not the testing, needs attention; stop and review the failures first).

## 7. Known wrong paths and risks

- **More fix batches before testing the last ones.** It widens the gap this frontier is about.
- **One-off C++ for an enchant that fits a table.** Check the seven groups first.
- **Trusting the audit's "working".** Sample it: 50 random "working (audit)" rows tested would say how far to
  trust the other 4,281.
- **A database stopgap where code is the real fix** (James prefers the permanent fix), and the reverse: C++ for
  what one SQL row does.
- **Doubling an effect** by linking a twin without removing our own copy (a recorded lesson).
- **Forcing an untested C++-only enchant into the rolls** to raise the count.
- **Copying tooltip text into the repo.** Paraphrase; the builder capture stays on the VM.
- **Balance creep.** Restoring an enchant "as its tooltip says" can be far too strong on this realm. Restore
  first, flag it, and leave the tuning to F7.
- **The "modifier" family (about 300)** is mostly event logic, not simple percentages; there is no cheap scripted
  fix for it (a recorded lesson).

## 8. Dependencies

Throughput depends on F5 step 2. C++ handlers depend on F1 for cost and on F4 for safety. F3 feeds test results.
F7 depends on this: tuning enchants that do not work is wasted effort. The Death Knight set (roadmap items 2 to 4)
depends on the client patch pilot, not on this file.
