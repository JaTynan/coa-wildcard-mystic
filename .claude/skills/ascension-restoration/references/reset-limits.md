# SQL files that `000-reset.sql` cannot undo

Read this before deleting, reverting or reordering any file named here, and before writing a new file that touches
a table or row the core ships. This is the one home for the list; other skills point here.

Verified on 2026-11-22 by reading all 64 files in `sql/enchants/` against `000-reset.sql`, the pinned core's
`data/sql/base/db_world/spell_proc.sql` (core `c3f2fd4`) and `enchants/core-proc-row-replacements.csv`.
Nothing here was checked against the live database.

## What the reset can undo

`000-reset.sql` removes: `spell_linked_spell` rows whose comment starts `WCME:`; rows of `spell_dbc`, `spell_proc`
and `coa_mystic_enchant_aura_link` listed in `wcme_owned`; `spell_script_names` rows named `spell_wcme_%`; and the
whole content of our `wcme_*` tables. Anything else stays as the last run left it.

## (a) Outside the reset's tables: 8 files

Deleting the file leaves its change in the database (or in the MySQL server).

| File | What it changes | Notes |
|---|---|---|
| `090-mysql-tuning.sql` | MySQL server variables, `SET PERSIST` (7 InnoDB settings) | Server-wide, kept in MySQL's own data folder; survives restarts and file deletion. Undo: a statement in a new file that sets the old value (MySQL's `RESET PERSIST <name>` drops a persisted setting from the next MySQL restart). |
| `095-slow-query-log.sql` | `SET PERSIST` slow-query log on, threshold, file | Same. Stays on until a statement turns it off. |
| `100-rune-rates.sql` | `quest_template` and four `*_loot_template` tables, in place | Keeps its own originals in `wcme_rune_original_quest` / `wcme_rune_original_loot` and recomputes from them, so it is safe to run again; deleting it leaves the last amounts. |
| `110-manastorm-caches-unstack.sql` | `item_template`, in place | |
| `120-battleground-spoils.sql` | `item_template`, in place | |
| `130-battleground-dampening.sql` | `spell_area` rows (deletes its own, then inserts) | The file cleans up after itself; the reset does not. |
| `160-rune-currency.sql` | `currencytypes_dbc` row (delete then insert) and `item_template` in place | |
| `161-wisdomball-tiraxis.sql` | `npc_vendor` row (delete then insert) | |

## (b) A core row changed in place: 1 file

| File | Statement | Why the reset misses it |
|---|---|---|
| `026-medium-legendaries-3-extras.sql` | `UPDATE spell_proc SET SpellFamilyMask0 = SpellFamilyMask0 \| 0x400000 WHERE SpellId = -44445` | Row -44445 is the core's own (it is in the core's base `spell_proc.sql`) and is not in `wcme_owned`. The bit stays set after the file is deleted. |

## (c) Core rows removed, or replaced by a row we own

Here the reset *does* act, and that is the problem: after the file is deleted the reset removes **our** row and
nothing re-inserts the core's, so the spell ends up with no row at all.

| File | Row | What happens |
|---|---|---|
| `027-medium-legendaries-4.sql` | `spell_script_names`: binding `aura_wildcard_nether_portal` on spell 1180443 | The file deletes the core's own binding (the class exists in the core, `src/server/coa/AscensionWildcardNetherPortal.cpp`). Nothing restores it. |
| `027-medium-legendaries-4.sql` | `spell_proc` 1181360 (Stormbound Instinct) | Core row replaced by ours and registered in `wcme_owned`. |
| `140-talent-fixes.sql` | `spell_proc` -47258 (Backdraft, every rank) | The **stock** row (in the core's base `spell_proc.sql`) is registered as owned, deleted and replaced by ours. Deleting 140 leaves no Backdraft row. |
| `005-twin-procs.sql` | `spell_proc` 55441 (Glyph of Mana Tide) | Core row replaced by ours and owned. |
| `018-enchant-scripts-2.sql` | `spell_proc` 1570700 (Shadow Visions) | Same. |
| `020-quick-legendaries.sql` | `spell_proc` 1181400 (Blazing Flame) | Same. |

That 55441, 1181360, 1181400 and 1570700 had a core row is recorded in `enchants/core-proc-row-replacements.csv`
(columns `core_flags`, `core_chance`; status "reviewed", still ours). They are not in the core's base SQL file at
the pinned commit, so their original values exist only in that CSV and in `wcme_backup_spell_proc`, the one-off
copy of `spell_proc` the reset made the first time it ran. To put a stock row back, write a `REPLACE INTO` with
the original values in a new file, without a `wcme_owned` entry (as files 005, 007, 017, 020 and 038 already do
for seven rows the 18 Nov review handed back to the core).

Related, and deliberate: those seven restored core rows (005: 282040, 285100; 007: 276302, 979137; 017: 1587050;
020: 1180480; 038: 1544910) are written without a `wcme_owned` entry, so deleting the file does not remove them.
Files `015` and `016` delete script bindings by spell id with no name filter; whether any of those 55 spells has
a core binding is UNVERIFIED (see `wildcard-architecture-contract`, V5).

## Not on the list

- `013-action-fixes.sql`: its `UPDATE spell_proc ... WHERE SpellId = 282881` edits a row that
  `007-enchant-actions.sql` inserts and registers in `wcme_owned`. The reset deletes it and 007 re-creates it at
  every start, so deleting 013 does undo the change. A static check that flags 013 here is a false positive.
- `009`, `011`, `012`, `013` use a temporary table `wcme_new_spell`; it does not outlive the connection.

## Re-verify

```bash
grep -l "SET PERSIST\|item_template\|spell_area\|npc_vendor\|currencytypes_dbc\|loot_template\|quest_template" sql/enchants/*.sql
grep -n "44445\|nether_portal\|47258" sql/enchants/*.sql
grep -n "('spell_proc', 55441)\|('spell_proc', 1570700)\|('spell_proc', 1181400)\|('spell_proc', 1181360)\|('spell_proc', 282881)" sql/enchants/*.sql
cat enchants/core-proc-row-replacements.csv
python3 -I .claude/skills/ascension-restoration/scripts/enchant_sql_lint.py     # its NOTE lines list the statements to read by hand
```
