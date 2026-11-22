# What is recorded as tested, 2026-11-22

Read this when someone asks "has X been tested?" or "how much of this is proven?". Every number here comes from
`scripts/tested_inventory.py` run against commit `fcfee51` on 2026-11-22; re-run it rather than trusting this page
once the tracker has moved.

```
python3 -I .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py
python3 -I .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py --list-tested   # the 49 rows
```

The short version: **the only systematic test record in this repository is for Mystic Enchants, it covers 49 of
6,440 tracker rows, and all of it dates from three sessions (31 Oct, 2 Nov, 3 Nov 2026). Nothing has been recorded
since, although 166 pull requests merged between 4 and 22 Nov (`git log origin/main --merges --first-parent --since=2026-11-04 --oneline | wc -l`).** Most C++ patches have no recorded test of any kind.

## 1. `enchants/tracker.csv` (6,440 enchants)

| status | rows | with a result in `tested` | without |
|---|---|---|---|
| working (audit) | 4,331 | 0 | 4,331 |
| live (after restart) | 875 | 2 | 873 |
| live | 653 | 6 | 647 |
| broken | 424 | 7 | 417 |
| partly working | 119 | 7 | 112 |
| verified | 27 | 27 | 0 |
| missing | 11 | 0 | 11 |
| **total** | **6,440** | **49** | **6,391** |

How to read it:

- `working (audit)` means `enchants/enchant_audit.py` judged the spell data to be made of effects the core handles.
  It is a static verdict (rung 1 of the evidence ladder). **None of the 4,331 has an in-game result.**
- `live` and `live (after restart)` mean a fix is merged and applied. 1,528 rows; 8 have a result. Of those 8, two
  record problems (Counterpoise: no crit or haste seen), two could not be cast in the test (Rain of Arrows), three
  are clean passes and one was unreadable in game (Hasty Mana Tide Totem).
- `verified` is the only status that means "a person saw it work". 27 rows, 0.4% of the list, 1.7% of the 1,555
  rows we changed (`live` + `live (after restart)` + `verified`).
- The 14 results on `broken` and `partly working` rows are **failed or partial tests**: recorded results are not
  all passes. Four taught spells were taken out of file 008 on 3 Nov because the test showed they were only an
  effect piece (Ring of Frost, Seal of Command, Shadow Missiles, Soul Reaper).
- Results by date: 2026-10-31: 4, 2026-11-02: 10, 2026-11-03: 35.
- Format in practice: the four 31 Oct rows hold `YYYY-MM-DD pass: what was seen` in `tested`; the 45 later rows hold
  only the date in `tested` and the words in `notes`.

## 2. `enchants/test-checklist.csv` (561 test rows)

Columns: `file` (the SQL file number, or `audit`), `spell`, `name`, `scroll item`, `test type`, `commands` (the GM
commands to type), `expected`, `result`. It lists fixes waiting for a test with ready-made commands.

- 35 rows have a result, 526 do not. (47 of the 526 are short rows with no `result` column at all.)
- Results: 19 pass, 2 fail, 14 other (partial or notes).
- Two definitions are in use for "rows we fixed": 1,555 by status (`live`, `live (after restart)`, `verified`; this
  script) and 1,565 by a non-empty fix column (`ascension-restoration`'s `tracker_summary.py`). 35 / 45 of those
  have a test entry; 49 tracker rows have a test entry in all. Say which definition a quoted figure uses.

| test type | rows | with a result |
|---|---|---|
| teach (the enchant teaches a spell) | 148 | 28 |
| twin (linked to a working copy) | 139 | 2 |
| hook (C++ script) | 74 | 0 |
| action (action-table row) | 45 | 5 |
| kit | 23 | 0 |
| proc | 22 | 0 |
| core (needs a core patch) | 22 | 0 |
| school pair | 20 | 0 |
| aura link | 13 | 0 |
| new spell, new spell (named targets) | 12 + 11 | 0 |
| periodic | 12 | 0 |
| probably already works | 10 | 0 |
| everything else (core+hook, script, modifier, swap, link, core+action, core+proc) | 10 | 0 |

**Every row that depends on C++ (hook, core, kit, script and the mixed core+ types: 126 rows) is untested.** All 35
results are for data-only fixes.

SQL file numbers the checklist covers: 001-009, 011, 012, 015, 017, 018, 020, 027, 037, 038, 040-054, plus `audit`.
Files 013, 014, 016, 019, 021-026, 028-036 and 039 have no checklist rows (their enchants may still appear under
another file's number; check by spell id).

## 3. Generated history files (`scripts/legendary_history.py`)

| file | rows | `changed, awaiting in-game test` | `tested (see test notes)` | `changed after its last test, retest needed` | other |
|---|---|---|---|---|---|
| `enchants/legendary-history.csv` | 305 | 177 (+3 worded variants) | 5 | 1 (Astral Storm, last test 2026-11-03) | 81 unchanged working, 29 changed on an unmerged branch, 9 "works / handled, checked" verdicts from reading data or code |
| `enchants/epic-history.csv` | 1,710 | 280 | 28 | 1 (last test 2026-11-02) | 1,141 unchanged working, 163 changed on an unmerged branch, 80 unchanged broken, 17 unchanged partly working |

`enchants/legendary-notes-header.md` says it plainly: "Almost every changed legendary is still awaiting an in-game
test", and both headers say the compile check and the scratch-database load "do not replace in-game testing".

Statuses such as `works from its data (checked 2026-11-16)` and `handled by the core (checked 2026-11-18)` are
**desk checks** (reading spell data or core code), rung 1. Do not count them as tested.

## 4. C++ patches: tests recorded in commit messages

Method: for each file in `patches/`, every commit message that touched it was searched for test wording. This finds
what was written down, not what was done. Pull request descriptions are not in git and were **not** searched; the
enchant notes files quote some of them.

| Evidence recorded | Count (of 61 files) | Which |
|---|---|---|
| In game | 9 | The racial patches 54, 56, 57, 58, 59, 72, 74, 75, 76, all from one line in commit 22fae33 (20 Nov): James "auditioned in game" each racial's effect and sound. That is a look-and-listen check of the moments, not a check of the numbers in CHANGES.md. |
| Compiled or syntax-checked only | 4 | 77 (273d36d, syntax-checked), 78 (90ee10d, compiles with -Wall -Wextra against core c3f2fd4b2395), 79 (5c2a489, same), 90 (e0cc2f5, after its first build failed) |
| Checked against game data only | 1 | `mystic-enchants-scripts.patch` (1789a56, against CharacterAdvancement.dbc). Individual enchants in it have tracker results; the patch as a whole has none. |
| **Nothing recorded** | **47** | 10, 20, 30, 40, 45, 46, 47, 48, 49, 50, 51, 52, 53, 55, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 73, 80-89, 91-96, and the patches `mystic-enchants-actions`, `-spellaffect-sql`, `-wildcard`, `wildcard-ability-pool` |

Honest reading: these patches are live and players use them, so many have been *seen* working. But "seen working
by players" is rung 8 without a record, which cannot be told apart from "nobody has hit the bug yet". Three
patches in the "nothing recorded" list each fixed a failure that players found first: 81 (the world server stopped
on a channel message, 20 Nov), 94 (Find a Group refused Random Classic Dungeon) and 82 (the Wildcard window said
"not enough Marks" with runes in bags).

`CHANGES.md` has no "tested" wording for any patch.

## 5. Other recorded tests (all one-off, none repeatable by script)

| What | Evidence | Source |
|---|---|---|
| Client patch loads its spells | On 2 Nov, on James's Linux desktop, `GetSpellInfo(911367)` returned Critical Mass with its icon | commit 34083eb, docs/enchant-restoration.md |
| Client patch no longer crashes character creation | "fixed and tested 7 Nov" | docs/enchant-restoration.md, commit dc2a5da |
| Named-target modifier route (`wcme_spellaffect_dbc`) | Quick Conjure Water: cast time 2.97 s to 2.524 s, exactly 15% (3 Nov) | tracker row 91395 |
| Rebuilt modifier spells | Critical Mass: Fire crit 3.03% to 5.03%; Hasty Tranquility: cooldown 8 min to 7 min 20 s (2 Nov) | tracker rows 911367, 87754 |
| Settings apply rewrite | Old and new code run side by side on 266 settings across 12 files: identical output; 24.6 s became 1.7 s | commit d802f8c (22 Nov) |
| Config encoding repair | On the live `playerbots.conf`: 22 MB back to 243 KB, every restored line identical to the `.dist` | commit ba59783 (22 Nov) |
| Official module patches | Checksums match and both apply to the listed commits | commit 01159e2 (19 Nov) |

## 6. Measured performance baselines on record

From `docs/performance.md`, measured 7 Nov 2026 in the manager's world-speed panel (`docs/performance.md` says 8 vCPU, 18 GB; 10 logical processors were seen in the
22 Nov counter file, so that line is stale):

| Setup | Ticks/s | Average | 95% under | Peak |
|---|---|---|---|---|
| 1,000 bots, 1 map thread | 33 | 30 ms | 61 ms | 489 ms |
| 1,000 bots, 4 map threads | 50 | 20 ms | 39 ms | 58 ms |
| 1,500 bots, 4 map threads | 26 | 38 ms | 66 ms | 301 ms |
| 1,250 bots, 4 map threads | 30 | 33 ms | 64 ms | 112 ms |

The same file gives the only stated comfort bands: 95% under about 50 ms is smooth; 100 ms and up feels laggy.

Later measurements, in commit messages only:

| Date | Measurement | Source |
|---|---|---|
| 8 Nov | Character list 40 s, under 1 s after indexing `character_spell` / `character_talent` | commits 257158e, ea01588 (#84) |
| 20 Nov | About 880 bots: 99th percentile tick 586 ms, worst 2.9 s, console log 2.9 GB, read before the logging change (which shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run yet; status OPEN) | commit f9dc45a |
| 21 Nov | Worst ticks 2 to 5 s with 2 players on, median 36 ms, read around the cut from 1,000 to 750 bots (the record does not say which side of the cut, so no conclusion about bot count follows) | commit 6a3e017 |
| 22 Nov | First day of instrument readings, one player, 750 bots: 457 complete Timing.log records; 117 with a player on; 77 with a pass of 1 s or more; 22 with 2 s or more; none with nobody on (worst 534 ms); worst 5,397 ms at 14:49. Root cause UNKNOWN | wildcard-lag-spike-campaign `references/evidence-2026-11-22.md`; wildcard-diagnostics-and-tooling `references/reference-run-2026-11-22.md` (in the skills, not yet in docs/performance.md) |
| 22 Nov | Applying settings took about 3 minutes of downtime before the rewrite; healthy downtime is now "about 2 minutes" | commit d802f8c, docs/agents/context/patch-night.md |

**The only summary of the configuration live on 2026-11-22** (750 bots, core c3f2fd4b) **is one day with one
player**: the 22 Nov row above. A multi-evening baseline does not exist, and nothing from that day is in
`docs/performance.md` yet. The lag pass/fail numbers are not set here: their single home is the proposed exit
metric in wildcard-lag-spike-campaign (Phase 1 step 5).
