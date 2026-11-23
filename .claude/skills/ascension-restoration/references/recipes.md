# Proven recipes, step by step

Read this when the decision tree in `SKILL.md` has named a recipe and you are about to write the SQL.
Every recipe below has a real file in `sql/enchants/` to copy the shape from. Facts were checked against the
checkout of 2026-11-22 (`fcfee51`, PR #232's head on `62a26e4`; `origin/main` `d3e030f` differs only under
`signup/`) and the upstream core at `c3f2fd4` (19 Nov 2026).

Before any of them:

1. **Check the core does not already do it.** Search the enchant's spell id in `enchants/core-overlap-review.csv`,
   then in the core's own enchant tables (`data/sql/updates/pending_db_world`, tables `coa_mystic_enchant_proc`,
   `coa_mystic_enchant_bonus`, `coa_mystic_enchant_aura_link`) and its C++ (`src/server/coa`, `src/server/scripts/Spells`).
   Twenty-odd fixes were removed on 17-18 Nov 2026 because the core already did the job and ours doubled it
   (`enchants/epic-notes-header.md` "Overlaps with the core's own enchant code").
2. **Classify with wildcard-change-control first.** Re-applying one of these SQL patterns is a listed standard
   change (LOW) in `docs/agents/context/change-risk.md`; anything that needs C++ is not.
3. Use the next free file number in the enchant range (055 on 2026-11-22) and start the file with a plain-English
   comment header: what, which enchants (name and spell id), what it needs (build, client patch), and any assumption.

Shared vocabulary:

- **Our spell / enchant spell**: the spell id in column `spell` of `enchants/tracker.csv`. The enchant is a passive
  aura of that spell on the player.
- **`spell_dbc`**: world-database table with the same 234 columns as the client's `Spell.dbc`, in the same order. A row
  there replaces (or adds) the server's copy of that spell. The client never sees it.
- **`spell_proc`**: one row per aura saying when it may "proc" (fire): which events, which spells, chance, cooldown.
- **`wcme_owned (tbl, id)`**: our list of rows we put into core tables, so `000-reset.sql` can take them out again.
  `tbl` is `spell_dbc`, `spell_proc` or `aura_link`.

`spell_proc` columns you will set (constants from the core's `src/server/game/Spells/SpellMgr.h`):

| Column | Meaning | Values seen in our files |
|---|---|---|
| `SpellId` | The aura that procs. A negative id means "this spell and all its ranks" (140 uses `-47258`). | |
| `SchoolMask` | Only spells of these schools set it off. 0 = any. | 1 Physical, 64 Arcane (002) |
| `SpellFamilyName`, `SpellFamilyMask0-2` | Only spells of this class family with these flags. 0 = no filter. | 005, 015 part 2 |
| `ProcFlags` | Which events count. Bit list in `SpellMgr.h` (`PROC_FLAG_*`). | `0x10000` = 65536 harmful magic spell done; `0x10` melee ability done; `0x40000` periodic done; `0x4000` helpful magic spell done |
| `SpellTypeMask` | 1 damage, 2 heal, 4 neither; 0 = all. | |
| `SpellPhaseMask` | 1 on cast, 2 on hit, 4 on finish. | |
| `HitMask` | 0 = normal and critical; 2 = critical only; 4 miss; 0x10 dodge; 0x20 parry; 0x40 block. | |
| `AttributesMask` | 2 = triggered spells may set it off; 8 = a charge is only used when the buff really changed the spell. | 005, 014 |
| `Chance` | Percent. 0 = use the spell's own chance. | |
| `Cooldown` | Internal cooldown in milliseconds. | 015 part 1 |
| `Charges` | How many procs before the aura goes. | 014 |

---

## R1. Working twin (link)

**Use when** the broken enchant has a twin (the same enchant made for another realm type) that works, and the two
do not both carry the same real effect. **Build needed:** no. **Example:** `sql/enchants/001-twin-links.sql`
(same tooltip), `003-twin-links-close.sql` (twin's tooltip differs).

1. Find the twin: same name in the exported spell data's `index` (see `SKILL.md`, section 1). Confirm the twin's audit
   class is `standard` or `scripted`, or that the core has a rule for it.
2. Check the twin can fire: if it is a proc aura, it needs proc flags in its data or a `spell_proc` row. Neither = it
   never fires (go to R3).
3. Compare effects. If our spell and the twin both carry the same real bonus, go to R2.
4. Add the row:
   ```sql
   INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
   (<our spell>, <twin spell>, 2, 'WCME: <Name> uses twin <twin spell> (<why it works>)');
   ```
   `type` 2 means "while the first aura is on the player, the second is too, and it leaves with it"
   (`SPELL_LINK_AURA`). The comment **must** start with `WCME:`; that is how the reset finds the row.
5. If the twin's text differs from ours, add `[<our spell>] = <twin spell>,` to
   `addon/WildcardEnchants/TooltipData.lua` so players see the twin's text. That file holds ids only, never text.
6. Tracker: `fix` = "linked to working twin", `twin` = the id, `fix file`, `status` = `live (after restart)`.

**Pitfalls**
- *Twin that never fires.* Batch 2 dropped 22 links for this reason (`3a141df`).
- *The twin brings the core's rules with it.* If we later script the enchant ourselves, the link must go or both
  run: Compound Power, Frozen Chaos and Elemental Assassin were doubled this way (`99174fa`).
- *The core teaches the enchant's own taught spell whatever we link.* Four enchants give both the twin's effect and
  their own spell (`enchants/core-overlap-review.csv`, status `queued`).
- *The twin itself may be broken in play.* The legendary Demonic Reoccurence 1570995 links twin 272730, whose audit
  class is `standard`, and issue #148 reports that twin doing nothing. "standard" is a data check, not a test.

## R2. Twin with our duplicate effect removed

**Use when** R1 applies but our spell also carries the same real effect, so a plain link would give it twice.
**Build needed:** no. **Example:** `sql/enchants/004-twin-links-dedup.sql`.

1. Register the spell: `INSERT INTO wcme_owned (tbl, id) VALUES ('spell_dbc', <our spell>);`
2. `DELETE FROM spell_dbc WHERE ID IN (<our spell>);` then `INSERT INTO spell_dbc VALUES (...)` with a full 234-column
   copy of our spell in which the duplicated effect is turned into a placeholder. Take the 234 values from the
   exported spell data (`fields`). Keep the name. **Do not copy description or aura-description text into the
   SQL**: leave those columns empty, as the rows of file 004 do (the client shows its own text, and client tooltip
   text must not be committed to this public repository).
3. Link the twin as in R1.

**Pitfalls**
- A wrong column count fails the whole file (MySQL stops at the first error; see `SKILL.md` section 5).
- If the enchant later gets its own design, remove the blanking as well as the link (Deadly Bite 965292:
  `019-tooltip-review.sql`; Dragon Warrior 954252: `038`).

## R3. Twin given proc settings

**Use when** the twin is a proc aura with no proc settings, so it never fired. **Build needed:** no.
**Example:** `sql/enchants/005-twin-procs.sql`.

1. Read from the tooltip which ability sets it off, the chance and the cooldown.
2. `INSERT INTO wcme_owned VALUES ('spell_proc', <twin>);` then `DELETE FROM spell_proc WHERE SpellId IN (<twin>);`
   then `INSERT INTO spell_proc (...) VALUES (...)` using the column table above.
3. Link our spell to the twin as in R1, and say in the link comment what fires it.

**Pitfalls**
- *Triggered spells.* A bomb's explosion, a nova's damage or a channel's ticks are spells cast by another spell. They
  only set off a proc when `AttributesMask` has 2 (`4795ac5`).
- *Never replace a proc row the core ships for an enchant it runs.* The core's rule takes its chance from that row
  (usually 0 = the spell's own chance); ours at 100 made the core's rule fire every time (Soul Erosion, Wraithweaver).
  `enchants/core-proc-row-replacements.csv` lists the eleven cases. Where a file has to restore a core row it uses
  `REPLACE INTO spell_proc` with the row exactly as the core ships it and does **not** register it in `wcme_owned`.

## R4. School pair

**Use when** the enchant is one of the "damage of school A raises school B, and B raises A" family.
**Build needed:** no. **Example:** `sql/enchants/002-school-pairs.sql` (all 21 known ones are done).

1. Own and rewrite our spell in `spell_dbc` so its placeholder becomes a proc aura for one half.
2. The other half is an existing proc spell made for it (ids 2861xx); link it with `spell_linked_spell` type 2.
3. Two `spell_proc` rows (both owned): ours with `SchoolMask` = school A, the linked one with school B, both on
   damaging hits (`ProcFlags` 69904, `SpellTypeMask` 1, `SpellPhaseMask` 2 in the file).

## R5. Teach a working spell (twin's spell, or a namesake)

**Use when** the enchant teaches or transforms into an ability that is broken, and a working spell exists: the one
its twin teaches (file 006) or a working spell of the same name (file 008).
**Build needed:** yes, the build with `patches/mystic-enchants-wildcard.patch` (reads `wcme_enchant_teach` at
start-up). Every build since build6 has it (installed 2026-11-02 per `enchants/legendary-history.csv`).
**Examples:** `sql/enchants/006-teach-twins.sql`, `008-teach-namesakes.sql`, `053-epics-7.sql`.

1. Why SQL alone cannot do it: the spell an enchant teaches is read from the description text in the **client's**
   `Spell.dbc`, not from `spell_dbc`.
2. Add the row:
   ```sql
   INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
   (<our spell>, <working spell>, '<Name> teaches <Spell>, as twin <id> does');
   ```
   The primary key is `enchant_spell`: one extra taught spell per enchant. `000-reset.sql` empties this table, so
   there is nothing to register in `wcme_owned`. If an earlier file already has a row for the enchant, edit that
   file or `DELETE FROM wcme_enchant_teach WHERE enchant_spell = <id>;` first (as `019` does).
3. A transform adds the new ability next to the old one; it does not replace it.

**Pitfalls**
- *Namesake that is only a piece of the ability.* 24 namesakes were taken out again because the picked spell was a
  hidden effect or a free part (`767ca36`, `57c8c67`). Check the picked spell has a cost, a cooldown or a tooltip of
  its own.
- *Taught-spell doubles.* The core also teaches the spell the enchant's own text names, so players can end up
  knowing both. `enchants/taught-spell-doubles.csv` lists 54 rows, all `queued`. Decision (James, 2026-11-18,
  "option 1"): keep our teach only until the enchant's own spell works, then remove ours.

## R6. Action table

**Use when** the enchant is "when you do X, cast Y / cut or reset the cooldown of Z", possibly with a chance, a
cooldown, a school, an aura on the target or an aura on the player as conditions.
**Build needed:** yes, the build with `patches/mystic-enchants-actions.patch` (script `spell_wcme_enchant_action`);
in every build since build6.
**Examples:** `sql/enchants/007-enchant-actions.sql` part 1, `015-runaway-procs.sql` part 3, `016-dead-triggers.sql`.

Three rows per enchant:

1. The rule, in `wcme_enchant_action` (columns documented at the top of the patch):

   | Column | Meaning |
   |---|---|
   | `enchant_spell`, `rule` | Key. Number rules 0, 1, 2... per enchant. |
   | `spells` | Trigger spell ids, space separated. Empty = any spell. `0` = an auto attack. |
   | `school_mask` | School of the trigger spell. 0 = any. |
   | `target_aura` | Aura ids; the target must have at least one of them from this player. Empty = no condition. |
   | `requires_aura` | Aura ids; the player must have at least one. Empty = no condition. |
   | `chance`, `cooldown_ms` | Percent; cooldown per enchant and rule. |
   | `action` | `cast_self`, `cast_target`, `reduce_cooldown` (amount in ms), `reduce_cooldown_pct` (percent of what is left), `reset_cooldown`. |
   | `action_spells` | The spells to cast (every id, in order) or whose cooldown changes. |
   | `amount` | See `action`. For casts: when not 0, an energize helper restores this percent of attack power. |
   | `comment` | Plain English. Where a number is not from a source, say so in the row, as `016-dead-triggers.sql` does ("chance assumed"). |

2. A `spell_proc` row on the enchant spell (owned) that lets the right events reach the script.
3. The binding: `INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (<our spell>, 'spell_wcme_enchant_action');`
   `000-reset.sql` removes every `spell_wcme_%` binding, so there is nothing to register.

**Pitfalls**
- *List every version of the trigger ability.* On this realm a character can learn the stock or the CoA version of
  most abilities (Shadow Bolt 686 or 1100686). A list with only one never fires for the other. Real rows list dozens
  of ids.
- *A timing mistake looks like "does nothing".* Arcane Charge fired as Charge started, so its damage missed. "Fire
  it when Charge Root lands" was tried on a wrong premise (the root lands as Charge starts); what passed the test
  was making the damage hit the Charge target itself (`013-action-fixes.sql`, `79b50b4`; five pull requests on
  2 Nov, story in `wildcard-failure-archaeology`, E-07).
- *Rows are read at start-up only.* A changed row needs a restart.
- *If the logic needs memory* (stacks, sequences, "the last spell cast"), the table cannot express it: go to
  `SKILL.md` section 6.

## R7. Aura link

**Use when** the enchant is "while X is on you, you also have Y". **Build needed:** no (the table is the core's own).
**Example:** `sql/enchants/007-enchant-actions.sql` part 2.

```sql
INSERT INTO `wcme_owned` (`tbl`, `id`) VALUES ('aura_link', <our spell>);
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (<our spell>);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(<our spell>, '<aura ids, space separated>', <granted spell>, 'WCME: <Name>: <what it does>');
```

**Pitfall:** watch the **proc buff** only, never the talent that procs it. A talent is a passive aura the player
always has, so the grant becomes permanent (Decimation by Pyro; three more lost their talent ids on 18 Nov).

## R8. Rebuilt missing spell, and placeholder to modifier

**Use when** the enchant's spell does not exist on the server (audit class `missing`), or exists with only a
placeholder where its tooltip describes a plain modifier ("changes cost / cooldown / cast time / damage / crit of
spell X by N"). **Examples:** `sql/enchants/009-missing-modifiers.sql` (858 tracker rows),
`011-missing-named-targets.sql` (337), `012-placeholder-modifiers.sql` (1).

1. Build one passive spell with one modifier aura on the named spell or school, amount from the archived description.
   **Description text is not copied into new SQL.** Where the row has a description column, leave it empty or
   write a paraphrase in your own words. Existing files `009` and `011` (about 1,200 rebuilt description
   sentences: 857 and 334 long strings counted on 2026-11-22) and four rows in `012`/`013` already carry such
   text; whether that breaks the "no verbatim tooltip text" rule is an OPEN question for James's ruling
   (`wildcard-architecture-contract`, V7). Do not add more until he rules.
2. Use the guarded pattern so an id the core adds later is never overwritten:
   ```sql
   CREATE TEMPORARY TABLE `wcme_new_spell` (`id` INT NOT NULL PRIMARY KEY);
   INSERT INTO `wcme_new_spell` VALUES (<id>), ...;
   DELETE FROM `wcme_new_spell` WHERE `id` IN (SELECT `ID` FROM `spell_dbc`);
   INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', `id` FROM `wcme_new_spell`;
   DROP TEMPORARY TABLE `wcme_new_spell`;
   INSERT IGNORE INTO `spell_dbc` VALUES (...234 columns...), ...;
   ```
3. Picking the target:
   - If the target spell's class flag is shared by at most three other spells, put that flag on the modifier
     (009). **Build needed:** no.
   - Otherwise leave the class mask empty and name every target in
     `wcme_spellaffect_dbc (ID, ModifierSpellID, AffectedSpellID)` (ids in 900000-999999 that neither
     another file nor SpellAffect.dbc uses; a row replaces the file's row with the same ID. 950018-975169 was
     free of file rows on 23 Nov 2026, and `scripts/enchant_sql_lint.py` fails on a clash). **Build needed:** yes,
     `patches/mystic-enchants-spellaffect-sql.patch` loads the table into the server's SpellAffect data.
4. The client must have the spell too, or the enchant window has nothing to show: that is the client patch
   (`client-patch/build_client_patch.py`, built from James's own client files, never published). Route client patch
   work to wildcard-client-and-web.

**Pitfalls**
- *Reused enchant ids.* Two enchant ids turned out to be used by unrelated spells in our data and were skipped
  (`docs/enchant-restoration.md`, "Placeholder to modifier"). Always check a spell with that id does not exist.
- *Class family in the client copy crashed character creation* (fixed 7 Nov, `dc2a5da`): added spells carry no class
  family or flags in the client.
- These 1,195 are the largest untested group: the tracker has test entries for 4 of them (2026-11-22).

## R9. Proc rules only (runaway procs, "your next X" buffs)

**Use when** the enchant already triggers the right spell but fires on every hit, or a "your next X" buff is never
used up. Ascension kept each enchant's proc rules in its own server database; the spell data has them blanked.
**Build needed:** no. **Examples:** `sql/enchants/015-runaway-procs.sql` parts 1 and 2, `014-consume-buffs.sql`.

1. `wcme_owned ('spell_proc', id)`, `DELETE`, then `INSERT INTO spell_proc` with the tooltip's chance and cooldown.
   Where the tooltip states no cooldown, 015 uses 100 ms so one hit cannot set off a chain.
2. "Your next X" buff: give it `Charges` 1 and `AttributesMask` 8, so only the spell it changes uses the charge.
3. Procs that hit many targets: add a row to `wcme_proc_target_cooldown (spell_id, target_cooldown_ms,
   shared_cooldown_ms, comment)` for a cooldown per target (needs `patches/63-enchant-target-cooldowns.ps1`).

## R10. Force an enchant into or out of the scroll rolls

`wcme_enchant_override (enchant_spell, roll, comment)`: `roll` 1 = always offered, 0 = never. Read at start-up by
`patches/mystic-enchants-wildcard.patch`. Use 0 for an enchant found broken, 1 for one that works only through
hard-coded C++ (the dud filter `CoA.MysticEnchants.SkipDudSpells` cannot see those). No file inserts a row as of
2026-11-22; `000-reset.sql` creates and empties the table.
