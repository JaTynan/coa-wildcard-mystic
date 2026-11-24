# Talents, racials and the open issues

Read this when the broken thing is a talent or a racial rather than a Mystic Enchant, or when you pick up one of
issues #148-#151 (fixed 23-24 Nov). Checked on 2026-11-22, updated 2026-11-24, against the checkout `fcfee51` (PR #232's head on `62a26e4`; `origin/main`
`d3e030f` differs only under `signup/`).

## Talents: the same method, a different pair of files

| Piece | Where |
|---|---|
| Aura scripts (C++) | `patches/55-talent-fixes.ps1`. One block per talent, registered in the shared script loader in `AscensionAdventurerCache.cpp` (the loader comes from `patches/40-battlegrounds.ps1`, so 40 must run first). |
| Rows that switch them on | `sql/enchants/140-talent-fixes.sql`: `spell_proc` rows registered in `wcme_owned`, and `spell_script_names` bindings. |
| Record | A row in `CHANGES.md` for the patch; "One GitHub issue per talent" (header of patch 55). |

The source hierarchy and the conflict rule are the ones in `SKILL.md` section 1. A talent's tooltip is read the same
way as an enchant's (`.lookup spell id <id>`).

### Worked example that shipped: Backdraft (issue #152, PR #153, merged 14 Nov 2026)

- **Symptom:** the talent's tooltip names four spells that should set it off (three Warlock ones and one Priest
  one) plus a fifth with a particular Mystic Enchant. In play only one did.
- **Cause, from the data:** the stock `spell_proc` row for the talent filters on the Warlock class family and one
  spell's flag. One family filter cannot cover a Priest spell.
- **Fix shape:** the row loses its family filter (`SpellId` `-47258`, negative = every rank; owned so the reset can
  remove it. Deleting file 140 does **not** bring the stock row back: the reset removes ours and nothing
  re-inserts the core's; see `reset-limits.md`), and a small aura script `spell_wcme_backdraft` picks the allowed spells by class family and flags, so
  every rank and every copy of each spell counts. `140` binds the script with `spell_script_names`.
- **Needs a build:** yes (the script is C++). The SQL row alone removes the filter and relies on the script to choose the
  spells (inferred from the two files, not tested), so the two must go live together: see the sequencing warning in `SKILL.md` section 5.
- No in-game result for it is recorded in the repo as of 2026-11-22.

Use it as the template for "tooltip names more triggers than the proc row allows".

## Issues #148-#151: fixed 23-24 Nov 2026, not yet verified

All four warlock talent issues have merged fixes in `patches/55-talent-fixes.ps1` and
`sql/enchants/140-talent-fixes.sql`. James does not test by hand: a fix stays **unverified** until a player
report or an automated test says otherwise (see "Testing policy" in `wildcard-validation-and-qa`). The C++ parts
need the build after 24 Nov; the SQL parts went live at the next start.

| Issue | Talent | What was wrong | Fix | PR |
|---|---|---|---|---|
| #151 | Master Summoner 18710 | The Wild Imp bonus (2.5 s / 5 s) sits in hidden companion spells 818709, 818710 that nothing applied, and which have a mask but were never linked | Aura links talent rank -> companion. No named targets were needed: the companion's mask already selects Hand of Gul'dan (an early read said otherwise; it was the mask misread, see the spell-system reference) | #243 |
| #148 | Demonic Recurrence 272730 | Cooldown cut, armour loss and crit drawback sit in companions 272731, 272733; 272733 named only the CoA-class helper | Aura links 272730 -> 272731, 272733; named target 272733 -> 54879 (the Hero Metamorphosis helper); owned `spell_dbc` copy of 272731 with effect 3 blanked (its counterpart uses aura 341, honoured only for an allowlist). The twin-linked enchant 1570995 gains the same | #252 |
| #150 | Nemesis 63123 | No second Hand of Gul'dan cast | Script state machine: the first cast in the window does not start the cooldown, the second does; the window ending, logout or leaving the form restarts the opener's cooldown; a 250 ms watch for a cast still in flight. Scripts `spell_wcme_nemesis_hand_of_guldan`, `spell_wcme_nemesis_window`, `spell_wcme_nemesis_form_end` | #253 |
| #149 | Demonic Persistence 276506 | The stand-in effects did nothing | Script on 276508 (`spell_wcme_demonic_persistence_talent`): prevents the stand-in, the lowest-health imp (ties: shortest timer) sacrifices itself (276511, owner as original caster), then 276513 and 276509, and the other imps are empowered with 276512. New imps get Deterioration 990142 (a fixed 4% of health a second, new spell id) and 276512 when due (`wcme_demonic_persistence_new_imps`). Owned `spell_dbc` rows 276509, 276512 (aura 79, all schools) and 990142 | #254 |

### Talent recipes learnt from these

| Recipe | When | How | Example |
|---|---|---|---|
| T1 Hidden companion link | A talent's tooltip promises more than its own effects do, and a hidden spell with the same name or the next id carries the rest | `spell_linked_spell` type 2 from each talent rank to its companion, comment `WCME:`. If the companion's mask is empty or names the wrong spell, add `wcme_spellaffect_dbc` rows (check the ID with `enchant_sql_lint.py`) | #151, #148 |
| T2 Script on the stand-in spell | The talent fires a placeholder spell whose effects mean nothing to our core | A `spell_wcme_*` SpellScript or AuraScript on the placeholder; prevent its default effects, then cast the real spells with the owner as original caster | #149 (276508) |
| T3 Aura 341 / 322 allowlist | An effect uses Ascension's PvE or PvP damage aura | The core honours these only for spells listed in patch 65 (`65-enchant-tuning-auras.ps1`). Adding a spell is C++; otherwise blank the effect or swap it for a stock aura | #148 (272731 effect 3 blanked); patch 65 lists 990138, 979038 |
| T4 `spell_dbc` aura swap | The effect is right in spirit but uses an aura the core ignores | Owned `spell_dbc` copy (`wcme_owned`, DELETE, INSERT the full 234-column row) with the aura changed, for example to 79 (damage done %, misc 127 = all schools) | #149 (276509, 276512) |
| T5 State across casts | A talent changes cooldown rules for a window | A per-player state struct in the script file; cover every way the window ends (expiry, logout, form change, a cast still in flight); start cooldowns with `AddSpellAndCategoryCooldowns` and send the packet | #150 |

### The scan for more of the same (24 Nov 2026)

`scripts/talent_companion_scan.py` finds every Wildcard-rollable talent and ability whose tooltip quotes a
hidden spell that nothing applies (read-only; the docstring has the command). Results:
`enchants/talent-companions.csv`. Run on 24 Nov against the client data and the core at `c3f2fd4`: 4,507 rank
spells in the roll pool, 189 unapplied companions, of which **54 entries `strong`** (passive, permanent, and
named like the talent, at id + 800000, tagged SLS, or in a known block such as the 902300 stun-reduction or
957339 "Generic Capstone Threat" spells), 19 `probable`, 8 `stock-data`, 23 `false-alarm`. Run against the
repository before #243, it lists Master Summoner and Demonic Recurrence as `strong`, so it would have found
both. Checked by hand: Tactical Mastery, Careful Aim and Iron Will (the talent holds a placeholder or half the
effect, the companion the rest). A row is a lead: read both spells before fixing (recipe T1), watch the
`duplicate` column, and do not link a companion whose aura the core ignores (T3) or that duplicates the
talent's own effect.

### Batches, by type (James, 24 Nov: work through them by type, so a problem met once is solved the same way)

| Batch | Type | Status |
|---|---|---|
| 1 | Plain bonuses: an aura link per rank (`sql/enchants/141-talent-companions.sql`) | 25 talents; waiting for James to merge; unverified |
| 2 | Event-driven companions: link plus proc rules, or action-table rules (`sql/enchants/142-talent-companions-procs.sql`) | 8 talents; waiting for James to merge; unverified |
| 3 | Conditional: core aura links, recipe R7 (`sql/enchants/143-talent-companions-conditional.sql`) | Divinity (on Path of Strength), Glyph of Trueshot Aura (while Trueshot Aura is on); waiting for James to merge; unverified. Swashbuckler: Flurry of Blows was already an aura link in 007. |
| 4 | Needs code. Part 1 (`patches/55-talent-fixes.ps1` ability companions, `sql/enchants/144-ability-companions.sql`): Thrust, Two-Handed Weapon Mastery, and Careful Aim (data after all: a conditional link). Part 2 (`sql/enchants/145-talent-companions-native-effects.sql`, and patch 55's cap for effect 173): Battle Fatigue (extensions capped at +50%) and Divine Reset, whose companions use effect types this core runs. Still to do: aura 354 rules (Harbinger of Plague, Reave), class-script overrides and Ascension-only effect types, bespoke scripts | Bloodletting, Harbinger of Plague, Reave; from batch 2: Beacon of Virtue, Flare Strike, Holy Concentration, Pack Leader, Tidecaller's Boon; from batch 3: Corrupted Bear Form (its Shadow-damage proc has no trigger rules, so today the talent does nothing; the 20% penalty alone would make it worse); from batch 5: Thrust (an active ability whose armour-ignore passive needs "while you know X, you have Y", which this core cannot express in data: it has no learn-spell table) |
| 5 | Active abilities with a passive companion (no aura to link from) | Done 24 Nov, no SQL. Weighted and Jagged Reinforcement already work: their shield enchants (280422, 280420) carry the companion as an equip spell (SpellItemEnchantment type 3), applied while the shield is worn. Thrust moves to batch 4 (row above). |
| - | Left out by James (24 Nov 2026) | Icy Reach: a Death Knight talent whose tooltip quotes the Mage range companions (829023, 829014). Linking them would add range to Mage spells only, and stack with Arctic Reach at a different rank. James: "Leave it out." Do not link it in a later batch. |
| - | Outlier | One With The Light: its companion fires 275371, which is not in the game data; linking it as it is would log an error every second |
| - | No change needed | Nature's Splendor: the talent's own effects already give longer durations (4.5 / 9 / 3 sec) than the companion its tooltip quotes (3 / 6 / 2); linking would stack them |

The results file is now the to-do list: `talent_companion_scan.py` counts our aura links, action-table casts and
links as applied and skips greyed-out tooltip text, so after batches 1-3 it lists only what is left (19 strong
entries, all named above, 16 probable, 7 stock data).

Lessons from batch 1, for every later batch:
- A tooltip that says "does not stack" over a companion with the adding duration aura (232): own a copy with
  aura 234, which the core resolves as the strongest single cut.
- A capstone shown greyed out below the final rank links from the final rank only.
- A talent that only teaches spells has no aura of its own: link from the taught passive.
- A linked companion with a weapon requirement is removed with the weapon and not put back until login: drop the
  requirement (if the tooltip allows) or wait for batch 4's code.
- Look for sibling companions the tooltip does not quote (fear cuts next to stun cuts, 902313-902321).
- Run the file on a real MariaDB twice before the PR: the lint missed an unescaped apostrophe (`enchant_sql_lint.py`
  now catches it).

Lessons from batch 2:
- A `spell_proc` row with Chance 0 falls back to the spell's own chance. With an action-table rule carrying the
  chance, set the row to 100, or the two roll twice.
- (Corrected in batch 4.) This lesson first said effect types 165, 173 and 197 do not exist in this core. They do:
  see the batch 4 lessons. What stands: the action table (`reduce_cooldown`, bound to the companion) is the tool
  when the trigger must be exact spells or the companion's own effect is a placeholder. On a match the script stops
  the companion's own effect (PreventDefaultAction), and without one nothing fires. Never set a disable mask on
  every effect: then the aura cannot proc at all, script included.
- A trigger that must be exact spells (Meteor's two versions, Align, a Druid spell on a Mage talent) goes in the
  action table, which lists ids; a family mask cannot isolate them.
- A spell that summons (Meteor 760040) deals its damage through another spell: proc on cast, not on hit.
- A modifier type (107/108 misc) of 32 or more is outside the core's range and is ignored without an error
  (Talonshrike's 38): own a copy with the type the tooltip means. Batch 1's companions have none.
- Check the talent and companion ids against our earlier SQL first: these Hero talents double as Mystic Enchants,
  and some halves were already fixed (Talonshrike's cooldown cut in 007, Endless Agony's proc in 015).

Lessons from batch 3:
- The core's aura link (`coa_mystic_enchant_aura_link`) works for any aura, not only enchants: "source" is the
  talent, "aura" the condition (a form, a stat path, a buff), "grant" the companion. Its key is (source, grant).
- Before adding a penalty, check that the talent's payoff works: a talent that does nothing today must not get
  its drawback alone (Corrupted Bear Form).
- A tooltip can quote a spell with smaller numbers than the talent already gives (Nature's Splendor): compare
  values, not just effect types, before linking.
- Some aura types read a second value when the first is not valid (aura 175 falls back to MiscValueB): read the
  core's handler before "fixing" an odd number.

Lessons from batch 5:
- A spell that enchants an item (effects 53, 54) can carry its companion on the enchantment itself
  (SpellItemEnchantment: type 1 combat proc, 3 equip spell, 7 use spell). The scan now reads that file; give it
  the full server DBC folder (the VM's `C:\Games\CoA Server\Data\dbc`), or these show as missing.
- This core has no `spell_learn_spell` table (newer AzerothCore removed it), so "learning ability X also teaches
  passive Y" cannot be done in data. A generic code hook (an ability-to-passive table read at login and on learn
  and unlearn) is the batch 4 proposal; Thrust is its first user.

Lessons from batch 4:
- Read `SpellAuraDefines.h` before calling an aura "Ascension-only": this core implements many of Ascension's
  types (317-365). Aura 333 (hit chance, all kinds) works natively, so Careful Aim needed only a link. Others are
  honoured only for listed spell ids, each with its own condition: 341 (Unit.cpp allowlist, patch 65) and 354
  (`AuraEffect::CheckEffectProc` and `HandleAscensionPercentEventProc`). A companion on one of those needs its id
  and its condition added in code.
- Read `SpellEffects.cpp` too: this core runs several of Ascension's effect types (165, 168, 173, 176, 177, 183, 192,
  195, 197, 198). A companion using one needs only its trigger rules, so Battle Fatigue and Divine Reset were data.
- Effect 173 (refresh an aura) reads its second value: 0 sets the aura's duration to the amount, anything else adds
  the amount. Ascension's spell data leaves it 0 even where the tooltip says "extends", which would cut the aura to
  about a second on every proc. Check it, and own a copy with the second value set when the tooltip extends.
- A tooltip that extends with no limit still wants a cap: James's rule (24 Nov) is +50% of the base duration unless
  the cooldown says otherwise (comparable talents: Glyph of Shred +50%, Endless Agonizer +50%, Glyph of Scourge
  Strike +60%, Frozen Grave +40%). Patch 55 makes effect 173's second value a cap when it is 2 or more (ms beyond
  the base duration). Check the uptime against the cooldown: Battle Fatigue's +50% (30 sec) equals its 30 sec
  limit, so a warrior who keeps hitting and reshouts on time can keep it up throughout.
- Passives held by an ability: patch 55's `wcme_spell_companion` (ability, passive, flags). Use it for an active
  ability's passive and for any passive with a weapon requirement (a linked aura is lost at the first weapon swap).
- A fast compile check exists without a build: after pre-flight with `--keep --workspace /tmp/pf`, run
  `g++ -std=gnu++20 -fsyntax-only -w` on the changed file with the include folders of `src/` and `deps/` (not
  jemalloc, whose headers shadow the system's; `-Ideps/g3dlite/include` only at its root, since G3D has its own
  `Log.h`). It found nothing to fix in part 1, and catches a misspelt method, so it is a real check.
- The core strips weapon-dependent auras on more than unequip: a disarm and a weapon at 0 durability do it too,
  and putting them back (`Player::ApplyItemDependentAuras`) only covers the player's own spell and talent maps.
  The equip hook alone missed both (patch-reviewer, #262); patch 55 now hooks that function. A talent from a
  classic talent tree is in the talent map, not the spell map: check `HasTalent` as well as `HasSpell`.

Before scripting, check the core does not already do it (`enchants/core-overlap-review.csv`) and read every
version of the ability a Hero can learn (Hand of Gul'dan has 954611 and 2304611 -> 2304612; both summon guardians
through summon properties row 61).

## Racials: new designs built with the same machinery

The race kits are **not** archaeology. They are James's own design (settled 13 Nov 2026, `docs/race-kits.md`): every
race keeps its stock racials and gains one signature passive. The doc is the specification; its tables are the
"tooltip" that wins.

| Piece | Where |
|---|---|
| Design, numbers, balance notes | `docs/race-kits.md` |
| C++ | one patch per racial: `52-racials.ps1`, `54` Plainsrunning, `56` Bloodrush, `57` Ambush, `58` Voodoo Regeneration, `59` Radiant Presence, `62` spellbook entries, `72` Grave Defiance, `73` Spellsword, `74` Overclock, `75` Arcane Hunger, `76` Prospector's Spirit, `80` the `.racial` status command, `89` Stoneform |
| Our own spells (buffs, spellbook entries) | defined once in `client-patch/custom_spells.py`, ids from 9990001 |
| Server rows | `sql/enchants/150-custom-spells.sql`, **generated** by `custom_spells.py`; never edit by hand |
| Client rows | the client patch built by `client-patch/build_client_patch.py` (not published) |

What carries over from enchant work: one definition feeding both client and server so they cannot disagree; rows
owned through `wcme_owned`; a setting per feature where practical; the same in-game test habit (`.racial` prints the
numbers the buff icons cannot show).

Enchant helper spells live in the same generator (9990018 Stored Time, 9990019 the Hot Hands mark, 9990021,
9990022-9990025, 9990026): a new hidden helper for an enchant is added there, then 150 is regenerated with
`python3 -I client-patch/custom_spells.py > sql/enchants/150-custom-spells.sql`. The script's usage line names a
`<Spell.dbc>` argument, but the code does not read it: no client file is needed (run with no argument on
2026-11-22, its output was identical to the committed file 150). Home: `wildcard-client-and-web`.

For anything beyond this pointer, use wildcard-patch-authoring (the C++) and wildcard-client-and-web (the client patch).
