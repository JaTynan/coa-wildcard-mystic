# The spell system, as this project uses it

Read this when you have to understand or review anything that touches a spell: an enchant fix in `sql/enchants/`,
a `spell_wcme_*` script, a proc that fires too often or never, or a modifier that changes the wrong ability.
It explains the machinery. The recipes for fixing a given enchant are in the sibling skill
`ascension-restoration`.

`core:` = a path in the pinned CoA core at commit `c3f2fd4b` (release `server-0.261119.114`, checked 2026-11-22).
Line numbers drift with every release: re-find them with the grep commands at the end.

## 1. Where a spell's data comes from: five layers

A spell on this server is assembled once, at world server start-up, in this order. A later layer wins.

| # | Layer | Lives in | Who can change it | Takes effect |
|---|---|---|---|---|
| 1 | `Spell.dbc` file | Server folder `DataDir/dbc/Spell.dbc` (the server's copy of the client's table) | Nobody here: it comes with the manager's release | Start-up |
| 2 | `spell_dbc` table | World database | Our SQL (`sql/enchants/*.sql`) and the core's own updates | Start-up only |
| 3 | `SpellInfo` build | Memory: one `SpellInfo` object per spell | Automatic (`SpellMgr::LoadSpellInfoStore`, `core:src/server/game/Spells/SpellMgr.cpp:3462`) | Start-up |
| 4 | Corrections in code | `SpellMgr::LoadSpellInfoCorrections` (`core:src/server/game/Spells/SpellInfoCorrections.cpp:75`) | A patch (`patches/52-racials.ps1`, `89-racial-stoneform.ps1` add `ApplySpellFix` blocks) | Needs a build |
| 5 | Side tables | `spell_proc`, `spell_linked_spell`, `spell_script_names`, `spell_bonus_data`, the CoA and `wcme_*` tables | Our SQL | Start-up (some can be reloaded, see SKILL.md section 8) |

How layer 2 works: the core loads each DBC with `LOAD_DBC(store, "File.dbc", "table_name")`
(`core:src/server/game/DataStores/DBCStores.cpp:297`). For spells the line is
`LOAD_DBC(sSpellStore, "Spell.dbc", "spell_dbc")` (line 390). The file is read first; then every row of the table
is laid over it by ID: an existing ID is replaced whole, a new ID is added
(`core:src/server/shared/DataStores/DBCDatabaseLoader.cpp:39`).

Three consequences that have each bitten this project:

1. **A `spell_dbc` row replaces the whole spell, not one field.** To change one number you copy the full row.
   That is why our rows are long positional `INSERT INTO spell_dbc VALUES (...)` lists.
2. **The column count must match the core's format exactly.** The loader asserts
   (`"SQL format string does not match database for table"`, `DBCDatabaseLoader.cpp:128`): a mismatch stops the
   world server at start-up. If a core update adds a column to `spell_dbc`, every positional insert of ours
   breaks at once. At the pinned commit the format (`SpellEntryfmt`) has 234 fields and our rows have 234 values.
   Check the count after each core update (command in section 9).
3. **The client never sees `spell_dbc`.** The client reads its own `Spell.dbc` from its MPQ files. A spell that
   exists only in `spell_dbc` works on the server but has no name, icon or tooltip for the player until the
   client patch adds it (`client-patch/build_client_patch.py`). See SKILL.md section 9.

And one exception that surprises everyone: **some CoA code reads the DBC files raw, skipping `spell_dbc`.**
`GetClientDBCPath("Spell.dbc")` (`core:src/server/game/DataStores/DBCStores.cpp:739`) opens the file in
`DataDir/dbc/` directly. The Mystic Enchant catalogue (`MysticEnchant.dbc`) and the "which spell does this enchant
teach" lookup are read this way: the teach lookup scans each spell's description text in the file for a
"Teaches you" line carrying an `@s:<id>` token (`core:src/server/coa/AscensionMysticEnchantRules.cpp:261-290`).
So SQL cannot make an enchant teach a spell. That is the whole reason `wcme_enchant_teach` exists
(`docs/enchant-restoration.md`, Lessons).

## 2. Effects and aura types we rely on

A spell has up to 3 effects (`MAX_SPELL_EFFECTS = 3`). Each effect has an effect type; when the type is
"apply aura" it also has an aura type. Numbers below are from the pinned core
(`core:src/server/shared/SharedDefines.h:879-953`, `core:src/server/game/Spells/Auras/SpellAuraDefines.h`).

| Kind | Number | Name | What it does | Where we use it |
|---|---|---|---|---|
| Effect | 3 | `SPELL_EFFECT_DUMMY` | Nothing unless a script handles it | The mark of a placeholder enchant |
| Effect | 6 | `SPELL_EFFECT_APPLY_AURA` | Puts an aura on the target | Every rebuilt enchant |
| Effect | 30 | `SPELL_EFFECT_ENERGIZE` | Gives mana, rage, energy | Action-table helpers such as Molten Mana |
| Effect | 36 | `SPELL_EFFECT_LEARN_SPELL` | Teaches a spell | Rare here: enchants teach through the catalogue instead |
| Effect | 64 | `SPELL_EFFECT_TRIGGER_SPELL` | Casts another spell | Inside helper spells |
| Effect | 77 | `SPELL_EFFECT_SCRIPT_EFFECT` | Like dummy: needs a script | Counted as placeholder by the dud filter |
| Aura | 4 | `SPELL_AURA_DUMMY` | Nothing unless code looks for it | Placeholders; also markers our scripts check with `HasAura` |
| Aura | 23 | `SPELL_AURA_PERIODIC_TRIGGER_SPELL` | Casts a spell every N ms | Counted as placeholder when its trigger spell is 0 or missing |
| Aura | 42 | `SPELL_AURA_PROC_TRIGGER_SPELL` | On a proc, casts the effect's trigger spell | School pairs (`sql/enchants/002`), most proc enchants |
| Aura | 107 | `SPELL_AURA_ADD_FLAT_MODIFIER` | Adds a flat amount to one property of matching spells | Rebuilt enchants ("costs 20 less", "1 sec shorter cooldown") |
| Aura | 108 | `SPELL_AURA_ADD_PCT_MODIFIER` | Changes one property of matching spells by a percent | Rebuilt enchants ("deals 10% more") |
| Aura | 226 | `SPELL_AURA_PERIODIC_DUMMY` | A timer with no effect of its own | Placeholders |
| Aura | 322 | `SPELL_AURA_ASCENSION_MOD_PVP_DAMAGE_DONE_PCT` | Ascension's PvP-only damage percent | `patches/65-enchant-tuning-auras.ps1` |
| Aura | 341 | `SPELL_AURA_ASCENSION_MOD_PVE_DAMAGE_DONE_PCT` | Ascension's PvE-only damage percent | Same patch: the core only honours these two for an allowlist of spells |

For a modifier aura (107/108) the effect's "misc value" picks the property, the `SpellModOp` list
(`core:src/server/game/Spells/SpellDefines.h:74`): 0 damage, 1 duration, 7 crit chance, 10 cast time, 11 cooldown,
14 cost, 16 resist-miss (hit), 28 dispel resistance, and so on, plus Ascension's own 31 (maximum aura stacks).

The dud filter's definition of "placeholder" is exactly this list: an effect is ignored when it is effect 3 or 77,
aura 4 or 226, or a trigger aura (42, 23, 109, 227) whose trigger spell is 0 or does not exist. A spell with only
such effects is a placeholder (`SpellIsPlaceholder`, `patches/mystic-enchants-wildcard.patch:128-150`).

## 3. Class family flags, SpellAffect, and why `wcme_spellaffect_dbc` exists

**The stock mechanism.** A modifier aura does not name the spells it changes. It carries a family number and a
96-bit mask (`EffectSpellClassMask`); it applies to every spell of that family whose own `SpellFamilyFlags` share
at least one bit with the mask (`SpellInfo::IsAffected`, `core:src/server/game/Spells/SpellInfo.cpp:1459`). The
bits were handed out by Blizzard per class, and one bit is often shared by several abilities.

**The problem.** To rebuild a missing enchant such as "ability X costs less" we need a mask that selects X and
nothing else. For 858 enchants the target's bit is shared with at most three other spells, close enough, so the
rebuilt spell simply carries that mask (`sql/enchants/009-missing-modifiers.sql`). For the other 337 the target
shares its bit widely: a mask would also change unrelated abilities (`docs/enchant-restoration.md`, recipe
"Rebuilt missing spell").

**Ascension's answer, which CoA implements.** A modifier with an **empty** mask is looked up in `SpellAffect.dbc`,
a three-column table: `ID`, `ModifierSpellID`, `AffectedSpellID` (format `"nii"`,
`core:src/server/shared/DataStores/DBCfmt.h:108`). The check is in `SpellInfo::IsAffectedBySpellMod`:

```cpp
if (!mod->mask) {                       // core:src/server/game/Spells/SpellInfo.cpp:1646
    auto const named = targets.find(mod->spellId);   // rows for this modifier
    ...  target < 0 ? -target == firstRank : target == Id
```

A positive `AffectedSpellID` means that exact spell. A negative one means every rank of the chain that starts with
that spell.

**Our part.** At the pinned commit the core loads `SpellAffect.dbc` from the file only (its `LOAD_DBC` line passes
`nullptr` as the table name). `patches/mystic-enchants-spellaffect-sql.patch` changes that one argument to
`"wcme_spellaffect_dbc"`, so rows in that world table are laid over the file like any `*_dbc` table.
`sql/enchants/011-missing-named-targets.sql` then builds the 337 spells with an empty mask and names each one's
targets in `wcme_spellaffect_dbc`. Our IDs start at 900000 so they never replace a row of the real file
(`sql/enchants/000-reset.sql:32-33`).

Rules that follow:

- These rows are read at start-up only, as part of DBC loading. No reload command reaches them. Restart.
- On a world server **without** the patch the table is ignored and those 337 enchants change nothing
  (`sql/enchants/011` header).
- The lookup is built once from the store (`SpellAffectTargets()` is a function-local static), so a row can
  never be added while the server runs.
- The core warns and carries on if `SpellAffect.dbc` itself is missing from `DataDir/dbc/`
  (`"named spell modifiers will not apply"`, `DBCStores.cpp:397`). With the file missing the table is not loaded
  either, because the `LOAD_DBC` call sits inside that `if`.
- A modifier that carries a mask never reaches the SpellAffect lookup. Do not give a named-target spell a mask
  "to be safe": it switches the named rows off.

## 4. Procs

A proc is an aura reacting to an event. Three things decide whether it fires:

1. **Does the aura listen to this kind of event?** Its proc flags.
2. **Does the event pass the filters?** School, spell family and mask, damage or heal, cast or hit phase, hit
   result, triggered or not.
3. **Chance, cooldown, charges.**

On stock data, all of that is in `Spell.dbc` plus a few `spell_proc` rows. Ascension keeps its proc rules in its
own server database and ships the spell data with them blanked (`docs/enchant-restoration.md`, Lessons). So for
enchants the rules have to be put back by us, from the tooltip.

### 4.1 What the core does at start-up (`SpellMgr::LoadSpellProcs`, `core:src/server/game/Spells/SpellMgr.cpp:2369`)

| The spell has... | Result | Seen here as |
|---|---|---|
| A `spell_proc` row | That row is used. Three of its columns fall back to the spell's own data when 0: `ProcFlags`, `Charges`, and `Chance` (only when `ProcsPerMinute` is also 0). | Normal case for every enchant we fixed |
| Proc flags in its data, a proc-type aura, **no row** | The core **generates a default entry** (the loop from line 2546; the default entry itself from line 2610): no school filter, no family filter unless the effect itself carries a mask, phase "hit", chance from the spell's `ProcChance`, **cooldown 0**. | "Runaway procs": fires on every qualifying hit with no ability filter and no cooldown. `sql/enchants/015-runaway-procs.sql` fixed 33 Legendaries. |
| **No proc flags** and no row | Skipped (`if (!procFlags) continue;`). The aura never fires. | "Dead triggers": `sql/enchants/016-dead-triggers.sql`. Also why a twin can look fine and do nothing. |
| A row but still no flags anywhere | Start-up logs `` `spell_proc` table entry for SpellId N doesn't have `ProcFlags` value defined, proc will not be triggered ``. | Look for it in `Errors.log` after adding rows |
| A row for a spell ID that does not exist | Logged (`Spell N listed in `spell_proc` does not exist`) and skipped. | Happens when a file runs before the spell it needs |

A negative `SpellId` in `spell_proc` means "this spell and all its later ranks"; it must be the first rank.

Because of the core's own twin system (section 7), a stock spell's row is also copied to its core twins that have
no row of their own (`CopyToSpellTwins`, line 2526).

### 4.2 The `spell_proc` columns, as we set them

Column order used by every file in `sql/enchants/`:
`SpellId, SchoolMask, SpellFamilyName, SpellFamilyMask0, SpellFamilyMask1, SpellFamilyMask2, ProcFlags,
SpellTypeMask, SpellPhaseMask, HitMask, AttributesMask, DisableEffectsMask, ProcsPerMinute, Chance, Cooldown,
Charges`.

| Column | Meaning | Values we use |
|---|---|---|
| `SchoolMask` | Only events of these damage schools. 0 = any. Bits: 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane. | School pairs |
| `SpellFamilyName` + `SpellFamilyMask0..2` | Only events caused by spells of this family whose flags share a bit with the mask. 0 = any. | The "only the named ability sets it off" rows of file 015 part 2 |
| `ProcFlags` | Which event kinds. 0 = take the spell's own. | See the bit table below |
| `SpellTypeMask` | 1 damage, 2 heal, 4 neither; 7 = all. 0 = no filter. | 1 for "when you deal damage" |
| `SpellPhaseMask` | 1 cast, 2 hit, 4 finish. Required for spell-type flags. | 2 almost always; 1 or 4 for "when you cast" |
| `HitMask` | Result filter: 1 normal, 2 crit, 4 miss, 16 dodge, 32 parry, 64 block, 1024 absorb... 0 = the default (normal + crit, plus absorb for "done" events). | 2 for "on a critical strike" |
| `AttributesMask` | Behaviour bits, table below. | 2 where triggered spells must count |
| `DisableEffectsMask` | Bit per effect (1, 2, 4) that must NOT react to the proc. | Rare |
| `ProcsPerMinute` | Weapon-speed-based chance. Overrides `Chance` when not 0. | Rare |
| `Chance` | Percent. 0 = take the spell's `ProcChance`. | From the tooltip |
| `Cooldown` | Internal cooldown in **milliseconds**. | 3000 = 3 sec; 100 where the tooltip names none, so one swing cannot chain |
| `Charges` | How many procs before the aura is used up. 0 = take the spell's. | Rare |

`ProcFlags` bits (`core:src/server/game/Spells/SpellMgr.h:109`). "Done" = you did it, "taken" = it was done to you.

| Bit | Value | Event |
|---|---|---|
| 1 | 0x2 | You killed a target (usually one worth XP or honor) |
| 2 / 3 | 0x4 / 0x8 | Melee auto attack done / taken |
| 4 / 5 | 0x10 / 0x20 | Melee-class ability done / taken |
| 6 / 7 | 0x40 / 0x80 | Ranged auto attack done / taken |
| 8 / 9 | 0x100 / 0x200 | Ranged-class ability done / taken |
| 10 / 11 | 0x400 / 0x800 | Helpful spell with no damage class done / taken |
| 12 / 13 | 0x1000 / 0x2000 | Harmful spell with no damage class done / taken |
| 14 / 15 | 0x4000 / 0x8000 | Helpful magic spell done / taken |
| 16 / 17 | 0x10000 / 0x20000 | Harmful magic spell done / taken |
| 18 / 19 | 0x40000 / 0x80000 | Periodic tick done / taken |
| 20 | 0x100000 | Any damage taken |
| 22 / 23 | 0x400000 / 0x800000 | Main-hand / off-hand attack done |
| 24 | 0x1000000 | You died |

Worked example, a row from `sql/enchants/015-runaway-procs.sql`:
`(965501, 0, 0, 0, 0, 0, 65808, 1, 2, 0, 0, 0, 0, 100, 3000, 0)`. 65808 = 0x10000 + 0x100 + 0x10: harmful magic
spell, ranged ability or melee ability done. Type 1: only when it deals damage. Phase 2: on hit. Chance 100.
Cooldown 3000 ms. No family filter, so any ability counts.

`AttributesMask` bits (`ProcAttributes`, `core:src/server/game/Spells/SpellMgr.h:277`):

| Value | Name | Meaning |
|---|---|---|
| 1 | `PROC_ATTR_REQ_EXP_OR_HONOR` | The target must be worth XP or honor |
| **2** | `PROC_ATTR_TRIGGERED_CAN_PROC` | **Triggered spells may set this proc off** |
| 4 | `PROC_ATTR_REQ_MANA_COST` | The triggering spell must have a mana cost |
| 8 | `PROC_ATTR_REQ_SPELLMOD` | Charges drop only when this aura's modifier actually applied to the spell |
| 16 | `PROC_ATTR_USE_STACKS_FOR_CHARGES` | A proc removes a stack, not a charge |
| 128 | `PROC_ATTR_REDUCE_PROC_60` | Lower chance when the actor is above level 60 |
| 256 | `PROC_ATTR_CANT_PROC_FROM_ITEM_CAST` | Spells cast by items do not count |

### 4.3 Why `AttributesMask = 2` matters so much here

Many Ascension tooltips say "when ability X deals damage", where the damage is not dealt by X itself but by a spell
X triggers: Living Bomb's explosion, Fire Nova's damage, Hellfire's ticks (`docs/enchant-restoration.md`,
Lessons). The core drops such events before any other check:

```cpp
// core:src/server/game/Spells/Auras/SpellAuras.cpp:2236
if (!GetSpellInfo()->HasAttribute(SPELL_ATTR3_CAN_PROC_FROM_PROCS) &&
    !(procEntry->AttributesMask & PROC_ATTR_TRIGGERED_CAN_PROC) && ... auto attacks and kills are exempt ...)
    if (spell->IsTriggered() && !spell->GetSpellInfo()->HasAttribute(SPELL_ATTR3_NOT_A_PROC))
        return 0;
```

So: if the tooltip's trigger is the visible part of an ability whose damage comes from a hidden triggered spell,
the row needs `AttributesMask` 2, and the family mask (if any) must match the **triggered** spell, not the button.
The opposite mistake is as bad: mask 2 on a proc that itself casts a damaging spell can let the proc feed itself.
Give such a row a cooldown.

### 4.4 Per-target cooldowns (ours)

`spell_proc.Cooldown` is one timer per aura. `patches/63-enchant-target-cooldowns.ps1` adds a second kind for
spells listed in `wcme_proc_target_cooldown`: a cooldown per target plus a short shared one (default 100 ms),
replacing the `spell_proc` cooldown for those spells. The table is read once, at the first proc after a start.

## 5. `spell_linked_spell`

"When spell A does something, also do B." Columns: `spell_trigger`, `spell_effect`, `type`, `comment`. The types
(`SpellLinkedType`, `core:src/server/game/Spells/SpellMgr.h:100`):

| `type` | `spell_trigger` > 0 | Meaning |
|---|---|---|
| 0 | cast of A | Cast B (negative B: remove B's auras). With a **negative** trigger: when A's aura is removed, cast B. |
| 1 | A hits a target | Cast B on that target |
| **2** | A's aura is on a unit | **B's aura is added with it, and removed with it.** Negative B: the unit is immune to B while A is on. |

Type 2 is the only one this repository writes. It is the "working twin" recipe: while our broken enchant's aura is
on the player, the twin's aura rides along and leaves with it (`sql/enchants/001-twin-links.sql`):

```sql
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(282035, 1581729, 2, 'WCME: Chaos Manifesting uses twin 1581729 (scripted)'),
```

How the core handles type 2 (`Aura::HandleAuraSpecificMods`, `core:src/server/game/Spells/Auras/SpellAuras.cpp:1263-1316`):

- On apply: `caster->AddAura(B, target)`. The linked aura is added directly, not cast, so B's cast-time checks
  and costs do not run.
- On remove: `target->RemoveAura(B, casterGuid, ...)`.
- On re-apply with a different stack count: B's stack count is set to match A's.

Things to remember:

- **Mark every row `WCME:`** at the start of `comment`. `000-reset.sql` deletes rows `WHERE comment LIKE 'WCME:%'`
  at every start; a row without the marker is never cleaned up and survives its file being deleted.
- **Double bonus.** If our spell and its twin both carry the same real effect, the player gets it twice. File
  `004-twin-links-dedup.sql` first turns ours into a placeholder in `spell_dbc`.
- A twin with a proc aura but no proc flags and no `spell_proc` row does nothing when linked (section 4.1). File
  `005-twin-procs.sql` gives such twins a row.
- The link shows in game: `.list auras` on a character with the enchant lists the twin too
  (`docs/enchant-restoration.md`, "Testing in game").
- A link also counts as "behaviour" for the dud filter (`SpellHasBehaviour` checks the trigger as a cast link, a
  remove link and a type-2 link).

## 6. Spell scripts and `spell_script_names`

A spell script is C++ compiled into the world server. Two kinds, often paired:

- `SpellScript`: hooks on one cast (check cast, on hit, after cast).
- `AuraScript`: hooks on one aura (on apply, on remove, on proc, periodic tick, calculate amount).

Three pieces make a script run for a spell:

| Piece | Where | Example here |
|---|---|---|
| The class | C++ in the build | `class spell_wcme_enchant_action : public AuraScript` (`patches/mystic-enchants-actions.patch:181`) |
| Registration under a name | An `AddSC_...()` function called from the script loader | `RegisterSpellScript(spell_wcme_enchant_action);` in `AddSC_WcmeEnchantActions()`, which the patch adds to `core:src/server/coa/CoAScriptLoader.cpp` |
| The binding of spell ID to name | A row in world table `spell_script_names (spell_id, ScriptName)` | `(1181190, 'spell_wcme_enchant_action')` in `sql/enchants/007-enchant-actions.sql` |

Facts worth knowing:

- The table is loaded once at start-up (`ObjectMgr::LoadSpellScriptNames`,
  `core:src/server/game/Globals/ObjectMgr.cpp:6549`) and there is no reload command for it at the pinned commit.
- A negative `spell_id` binds the script to every rank; it must be the first rank.
- A row whose spell does not exist is logged and skipped.
- A row naming a script the installed build does not contain does nothing: our SQL headers rely on this
  ("unknown script names are only logged", `sql/enchants/017-enchant-scripts.sql`). This is what lets SQL be
  merged before the build that carries its script is installed. The enchant is simply dead until then.
- One spell can have several scripts. A core twin (section 7) inherits its stock spell's scripts only when it has
  none of its own.
- `000-reset.sql` deletes every binding whose name starts with `spell_wcme_` at each start, so the files after it
  put back exactly the set in the repository.
- A script with a proc hook still needs the aura to proc at all: it needs proc flags or a `spell_proc` row
  (section 4.1). The action-table header says so: "the enchant spell is bound to the script, and its `spell_proc`
  row says which events can set it off".

Our scripts are in two generated source files: `WcmeEnchantActions.cpp` (the generic action table, from
`mystic-enchants-actions.patch`) and `WcmeEnchantScripts.cpp` (214 `RegisterSpellScript` lines as of 2026-11-22,
from `mystic-enchants-scripts.patch`, wired in by `patches/64-enchant-scripts-loader.ps1`). Not every enchant
script is bound to a spell: the same patch also registers global `PlayerScript`, `UnitScript` and `AllSpellScript`
classes (names like `wcme_epic_batch3_hooks`) that watch every cast or hit and act when the player has the
enchant's aura.

## 7. The core's own "spell twin" system (do not confuse with our twins)

The pinned core maps copies of spells back to a source spell (`core:.agents/docs/systems/warcraft-reborn-spell-twins.md`):

- A Warcraft Reborn spell is its stock spell's ID plus 1,100,000.
- A crossover Mystic Enchant is the stock ID plus 1,300,000. Enchant twins are loaded **only on a seasonal
  realm**. This realm's type is `"live seasonal"` (`server-settings.txt:22`), so they are loaded here.
- At load, a source spell's rows are copied to each twin that has none of its own: `spell_script_names`,
  `spell_proc`, `spell_bonus_data`, `spell_linked_spell` and others.
- Core code compares against stock IDs through `SpellMgr::GetSpellTwinSource(id)`, and `Unit::HasAuraOrTwin`
  style helpers accept a stock ID and match any relative.

Why this matters for our SQL:

- A `spell_proc` or `spell_script_names` row we add for a stock-ID spell can silently appear on its core twins.
- A row we add for a twin **stops** the copy for that twin: it now has "its own".
- When a stock-looking fix does nothing for a 1,3xx,xxx enchant, check whether it is a core "namesake" (same name,
  different layout): those get nothing copied.

In this repository's docs, "twin" means something else: the same enchant under another spell ID made for another
realm type (glossary). Say which one you mean.

## 8. The CoA enchant tables and where our tables sit beside them

| Table (world DB) | Owner | Read by | What a row says |
|---|---|---|---|
| `coa_mystic_enchant_proc` | CoA core | `core:src/server/coa/AscensionMysticEnchantProcs.cpp:665` | For one enchant spell and effect index: on an event (`cast`, `hit`, `damage`, `direct_damage`, `periodic_damage`, `heal`, `direct_heal`, `periodic_heal`, `critical_damage`, `critical_heal`, `critical`, `kill`, `parry`, `dodged`, `auto_attack`, `damaged`), filtered by school, spell list, chance, cooldown, required auras, target auras and conditions, then consume auras, trigger spells or scale an amount. Columns: `enchant_spell, effect, event, school_mask, spells, chance, cooldown_ms, requires_aura, target_aura, conditions, consume_aura, trigger_spells, amount_pct, chance_per_combo`. |
| `coa_mystic_enchant_aura_link` | CoA core | Same file, line 727 | "While aura X is on you, you also have spell Y": `enchant_spell, aura, grant_spell` (`aura` is a space-separated ID list). |
| `coa_mystic_enchant_minion_aura` | CoA core | Same file, line 748 | An aura given to a summoned creature of a given entry. Not written by this repository. |
| `wcme_enchant_action` | This repo | `spell_wcme_enchant_action` | Our own, simpler rule table. See references/wcme-tables.md. |

As of 2026-11-22 our SQL writes `coa_mystic_enchant_aura_link` (17 enchants, `sql/enchants/007-enchant-actions.sql`
part 2, rows tracked in `wcme_owned` under the key `aura_link`) and does **not** write `coa_mystic_enchant_proc`:
that table stays the core's. An unknown event name or condition in it is logged
(`coa_mystic_enchant_proc: spell N effect M has an unknown event or effect`) and the row is skipped.

Both CoA tables count as "behaviour" for the dud filter, which is how an enchant fixed through them re-enters
scroll rolls after the next restart with nothing else to update (README.md).

## 9. Re-verification commands

Run from the pinned core checkout (SKILL.md, "Open the pinned sources").

```bash
# The five layers, in load order
grep -n "LoadDBCStores\|LoadSpellInfoStore\|LoadSpellInfoCorrections\|LoadSpellProcs\|LoadSpellLinked\|LoadSpellScriptNames" src/server/game/World/World.cpp
# spell_dbc and SpellAffect loading (is the table name still nullptr upstream?)
grep -n '"spell_dbc"\|SpellAffect.dbc' src/server/game/DataStores/DBCStores.cpp
# Column count the core expects for spell_dbc (the format string's length; 234 on 2026-11-22), to compare with a row of ours
python3 -I -c "import re;s=open('src/server/shared/DataStores/DBCfmt.h').read();m=re.search(r'SpellEntryfmt\[\]\s*=\s*((?:\s*\"[^\"]*\")+)',s);print(len(''.join(re.findall(r'\"([^\"]*)\"',m.group(1)))))"
# Default proc generation and the triggered-spell gate
grep -n "Generate default proc entry\|Skip if no proc flags" src/server/game/Spells/SpellMgr.cpp
grep -n "PROC_ATTR_TRIGGERED_CAN_PROC" src/server/game/Spells/Auras/SpellAuras.cpp src/server/game/Spells/SpellMgr.h
# Linked-spell types and the empty-mask SpellAffect lookup
grep -n "SPELL_LINK_AURA" src/server/game/Spells/SpellMgr.h src/server/game/Spells/Auras/SpellAuras.cpp
grep -n "if (!mod->mask)" src/server/game/Spells/SpellInfo.cpp
# CoA enchant tables and their columns
grep -n "FROM coa_mystic_enchant" -B3 src/server/coa/AscensionMysticEnchantProcs.cpp
```

From this repository:

```bash
git grep -n "LOAD_DBC" -- patches/mystic-enchants-spellaffect-sql.patch
git grep -c "RegisterSpellScript" -- patches/mystic-enchants-scripts.patch
git grep -n "AttributesMask" -- sql/enchants | head
```
