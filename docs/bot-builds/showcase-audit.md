# Showcase audit: does every part of every build work?

Status: draft, 28 Nov 2026. James's rule (28 Nov): these builds are showcases that players will copy, so every
ability, talent and enchant in them has to work. This page checks every part of all 37 builds against our server's
data and code, and lists what has to be fixed or tested first. Nothing here is a test result.

## 1. How each part was checked

Every name in each build's "The build itself" table was looked up in our server's spell data, as the spell a player
learns from the talent list (or, with no talent entry, the Mystic Enchant of that name). Each spell was then checked
against: the enchant tracker, the core's scripts and SQL at the revision our live build uses (CoA .114, 19 Nov), and
our own `sql/` and `patches/` on `main`.

| Grade | Meaning |
|---|---|
| stock | A classic 3.3.5 spell the core already runs |
| data only | Built only from effects the core handles by itself; should work |
| scripted | Needs server code, and the core or our patches have code or rules for it |
| fix live, untested | Was broken; a fix is merged and live, never tested in game |
| **never fires** | A proc talent with no trigger conditions anywhere (section 2) |
| **needs code** | Relies on a placeholder effect (or a spell it fires does), and no code for it was found |
| **broken** | Broken in the tracker, no fix written |
| unresolved | The name in the build doc does not match a learnable talent or ability; the doc needs the right name |

## 2. Proc talents that can never fire

Seven parts used by these builds are talents of the "when you do X, gain Y" kind whose spell data gives **no trigger
conditions** (proc flags 0), with no `spell_proc` row, enchant rule or script anywhere: not in the core's own
enchant rules (`coa_mystic_enchant_proc`, in the core's pending world SQL), not in ours. Ascension kept those
conditions in its own database. The core makes a proc rule from the spell data only when the proc flags are set
(`SpellMgr.cpp`, "Skip if no proc flags in DBC"), so these talents sit on the character and do nothing.

Evidence: GM tests on 2 and 3 Nov hit exactly this case. Demonic Mind (one of the seven) "the proc on enemies did not
fire", and Devour Mind's Devourer buff did not appear; both are proc auras with proc flags 0. The Legendary deep
audit of 15 Nov (`sql/enchants/016-dead-triggers.sql`) fixed 30 enchants for the same reason.

The October enchant audit (`enchants/enchant_audit.py`) did not look at proc flags. Of the enchants the tracker
lists as "working (audit)", **194 have this fault** with no rule anywhere (188 Epic, 4 Rare, 1 Uncommon, 1
Legendary). (201 before 28 Nov evening: the first check also counted add-target-trigger auras, which the core runs
without proc flags.)

Correction (28 Nov): the first version of this page said 43 build parts and 679 enchants. That count missed the
core's pending world SQL, where the core gives several hundred enchants their trigger rules. The numbers above
include it.

The fix is known: a `spell_proc` row with the conditions from the tooltip (recipe R9), or an action-table rule
where the trigger must be exact spells (R6, in every build since build6). Both are SQL, live at the next restart.

## 2b. Core rules that miss the other version of an ability

On this realm most abilities exist twice (the stock one and the CoA copy, for example Shadow Bolt 686 and 1100686),
and a character can learn either. Twenty build parts get their trigger rule from the core, but the core's rule lists
only one version of the trigger ability, so the talent does nothing for a player who learnt the other one
(`enchants/core-rule-version-gaps.csv`): Heavyweight, Demolisher, Arcane Gunslinger, Shot Weaving, Master of Shadows,
Harbinger of Plague, Gul'dan's Chosen, Toss and Throw, Master of Kunai, Glimmer of Light, Arcane Motes, Good Fortune,
Sword and Thunder, Shield Finesse, Synergetic Light, Blades of Blood, Shadow Infusion, Hunting Frenzy, Enduring
Aegis. The fix is SQL: an extra rule row in the core's table listing the missing versions.

## 3. Every build

Counts are distinct parts per build. "Core parts to fix" counts only parts in the build's core rows, not its rolled
extras.

| Build | Parts | Stock or data only | Scripted | Fix untested | Never fires | Needs code | Broken | Unresolved | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| Arcane Gunslinger (ranged) | 32 | 22 | 4 | 0 | 0 | 3 | 0 | 3 | 3 core part(s) to fix |
| Arcane Mage | 23 | 20 | 2 | 1 | 0 | 0 | 0 | 0 | Ready to test |
| Arcane Paladin | 23 | 13 | 3 | 0 | 0 | 0 | 1 | 6 | 1 core part(s) to fix |
| Beast Master | 16 | 14 | 0 | 1 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Blooming Growth | 13 | 11 | 1 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Claw-sader | 26 | 25 | 0 | 0 | 0 | 0 | 0 | 1 | Ready to test |
| Cryomancer | 16 | 13 | 0 | 0 | 0 | 1 | 0 | 2 | 1 core part(s) to fix |
| Cryotherapist | 7 | 6 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Dark Ranger | 19 | 16 | 0 | 0 | 0 | 2 | 0 | 1 | 2 core part(s) to fix |
| Discipline | 21 | 20 | 1 | 0 | 0 | 0 | 0 | 0 | Ready to test |
| Earthen Guardian | 17 | 13 | 1 | 0 | 1 | 0 | 0 | 2 | 1 core part(s) to fix |
| Elemental Lord (caster) | 20 | 17 | 0 | 1 | 0 | 1 | 0 | 1 | Ready to test |
| Enhancement | 19 | 16 | 1 | 0 | 1 | 1 | 0 | 0 | 2 core part(s) to fix |
| Frost Death Knight (melee) | 15 | 14 | 0 | 0 | 0 | 0 | 0 | 1 | Ready to test |
| Holy Paladin | 17 | 15 | 1 | 1 | 0 | 0 | 0 | 0 | Ready to test |
| Holy Radiance (healer) | 17 | 16 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Holy Spell Tank | 28 | 26 | 0 | 0 | 0 | 1 | 0 | 1 | 1 core part(s) to fix |
| Immolate and Conflagrate (caster) | 24 | 23 | 0 | 0 | 0 | 1 | 0 | 0 | Ready to test |
| Lightning Warrior | 18 | 16 | 0 | 0 | 0 | 1 | 0 | 1 | Ready to test |
| Mana-forged Barrier | 9 | 7 | 0 | 1 | 0 | 0 | 0 | 1 | Ready to test |
| Metamorphosis Tank | 16 | 11 | 2 | 0 | 0 | 0 | 0 | 3 | Ready to test |
| Ninja | 33 | 29 | 0 | 1 | 0 | 2 | 1 | 0 | 2 core part(s) to fix |
| Plague Caster (Spirit Stacker) | 20 | 19 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Prayer of Preservation | 22 | 15 | 1 | 2 | 2 | 0 | 0 | 2 | 2 core part(s) to fix |
| Protection Warrior | 20 | 20 | 0 | 0 | 0 | 0 | 0 | 0 | Ready to test |
| Pyroblast Fire Mage (caster) | 16 | 13 | 0 | 1 | 1 | 0 | 0 | 1 | 1 core part(s) to fix |
| Restoration Shaman | 21 | 21 | 0 | 0 | 0 | 0 | 0 | 0 | Ready to test |
| Retribution | 18 | 17 | 1 | 0 | 0 | 0 | 0 | 0 | Ready to test |
| Seed of Life | 12 | 11 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Shadow Bear (tank) | 22 | 16 | 0 | 0 | 1 | 0 | 0 | 5 | 1 core part(s) to fix |
| Shadow Melee (melee) | 19 | 17 | 0 | 0 | 0 | 1 | 0 | 1 | 1 core part(s) to fix |
| Soul Fire (caster) | 25 | 24 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Tide Chain Healer | 23 | 20 | 2 | 1 | 0 | 0 | 0 | 0 | Ready to test |
| Titan's Grip Crush (melee) | 29 | 23 | 0 | 0 | 1 | 2 | 0 | 3 | 3 core part(s) to fix |
| Total Eclipse | 15 | 14 | 0 | 0 | 0 | 0 | 0 | 1 | Ready to test |
| Vampire Lord | 14 | 11 | 2 | 1 | 0 | 0 | 0 | 0 | Ready to test |
| Winds of Winter (melee) | 10 | 8 | 1 | 0 | 0 | 0 | 0 | 1 | Ready to test |

"Ready to test" means no known gap in its core parts, not that it works: every Wildcard part still needs a GM test.

## 4. The parts to fix or test

| Part | Spell | Grade | Core or extra | Used by |
|---|---|---|---|---|
| Divine Concord | 277860 | broken | core | Arcane Paladin |
| Adrenaline Junkie | 285279 | broken | extra | Ninja |
| Blessing of the Divines | 273020 | never fires | core | Prayer of Preservation |
| Cataclysmic Sundering | 277180 | never fires | core | Earthen Guardian |
| Demonic Mind | 283942, 978704, 1586069 | never fires | core | Pyroblast Fire Mage (caster) |
| Maledictive Assault | 271400 | never fires | core | Shadow Bear (tank) |
| Preservation | 276273 | never fires | core | Prayer of Preservation |
| Raging Onslaught | 275920 | never fires | core | Titan's Grip Crush (melee) |
| Swirling Maelstrom | 984616 | never fires | core | Enhancement |
| Arcane Gunslinger | 274586 | needs code | core | Arcane Gunslinger (ranged) |
| Blades of Blood | 285895 | needs code | core | Titan's Grip Crush (melee) |
| Blooming Growth | 272214 | needs code | core | Blooming Growth, Seed of Life |
| Emanating Light | 1584044 | needs code | core | Holy Spell Tank |
| Frost Bomb | 271936, 954263, 1569556 | needs code | core | Cryomancer |
| Good Fortune | 284012 | needs code | core | Holy Radiance (healer) |
| Gul'dan's Chosen | 277150 | needs code | core | Soul Fire (caster) |
| Heavyweight | 273378 | needs code | core | Titan's Grip Crush (melee) |
| Hunting Frenzy | 1180820 | needs code | core | Beast Master |
| Icy Penance | 92754, 271341, 1568670 | needs code | core | Cryotherapist |
| Master of Kunai | 277475 | needs code | core | Ninja |
| Master of Shadows | 275491 | needs code | core | Shadow Melee (melee) |
| Plague Swarm | 276431, 1577100 | needs code | core | Plague Caster (Spirit Stacker) |
| Shadow Shot | 276811 | needs code | core | Dark Ranger |
| Shot Weaving | 274591 | needs code | core | Arcane Gunslinger (ranged) |
| Stormborn | 274078 | needs code | core | Enhancement |
| Time Bomb | 284591, 982484 | needs code | core | Arcane Gunslinger (ranged) |
| Toss and Throw | 277455 | needs code | core | Ninja |
| Wave of Despair | 283182, 901054, 1583807 | needs code | core | Dark Ranger |
| Elemental Immolate | 274734 | needs code | extra | Immolate and Conflagrate (caster) |
| Legacy of the Arcanist | 271284 | needs code | extra | Elemental Lord (caster), Lightning Warrior |
| Bestial Assault | 272317 | fix live, untested | core | Beast Master |
| Eldritch Knight | 81116 | fix live, untested | core | Mana-forged Barrier |
| Elemental Lord | 276578 | fix live, untested | core | Elemental Lord (caster) |
| Flash of Adrenaline | 282309 | fix live, untested | core | Ninja |
| Growing Light | 270661 | fix live, untested | core | Holy Paladin, Prayer of Preservation |
| Holy Ground | 281788 | fix live, untested | core | Prayer of Preservation |
| Hot Hands | 275397 | fix live, untested | core | Pyroblast Fire Mage (caster) |
| Mastery of the Tide | 274948 | fix live, untested | core | Tide Chain Healer |
| Spellstorm | 271709 | fix live, untested | core | Arcane Mage |
| Vampirism | 277003 | fix live, untested | core | Vampire Lord |

## 5. Names in the build docs to correct

Totem and shorthand names were corrected on 28 Nov. What is left falls in two groups. "Name not found": a
combination written in one cell ("X with Y") or a description rather than a name; the doc needs the exact talent.
"Not on our talent list": the spell exists but no talent entry teaches it. Some are granted by another part (a form
such as Dark Apotheosis, or Earthen Guardian's Stone Shield) and are fine; others look like Season 9 talents that
are not in our Season 10 data (most of Arcane Paladin's, two of Prayer of Preservation's). Those builds need a
replacement chosen from what our talent list offers, or they cannot be copied as written.

| Name in the doc | Problem | Used by |
|---|---|---|
| Arcane Crusade | not on our talent list | Arcane Paladin |
| Arcane Divinity | not on our talent list | Arcane Paladin |
| Arcanesworn | not on our talent list | Arcane Paladin |
| Assault and Battery | not on our talent list | Lightning Warrior |
| Blade of the Magisters | not on our talent list | Arcane Paladin |
| Blood Presence for damage | name not found | Frost Death Knight (melee) |
| Challenging Howl | not on our talent list | Metamorphosis Tank |
| Combustion with Playing with Fire | name not found | Pyroblast Fire Mage (caster) |
| Corrupted Maelstrom Weapon | not on our talent list | Shadow Melee (melee) |
| Demonic Pact and Demonic Tactics | name not found | Arcane Gunslinger (ranged) |
| Dual-wield talents | name not found | Metamorphosis Tank |
| Echoing Warcry | not on our talent list | Titan's Grip Crush (melee) |
| Etheric Vengeance | not on our talent list | Arcane Paladin |
| Exposed Weakness | not on our talent list | Winds of Winter (melee) |
| Felhunter and Master Demonologist | name not found | Shadow Bear (tank) |
| Glacial Burst with Frostflame Shock | name not found | Cryomancer |
| Holy Fire with Divine Prophet | name not found | Arcane Paladin |
| Hoplite Training | not on our talent list | Shadow Bear (tank) |
| Imp | name not found | Holy Spell Tank |
| Invocation  as a defensive channel | name not found | Mana-forged Barrier |
| Iron Fur | name not found | Shadow Bear (tank) |
| Light Swipe | name not found | Claw-sader |
| Moonkin Form's talent | name not found | Total Eclipse |
| Necromancer's Touch with Enslave Demon | name not found | Dark Ranger |
| Prepared to Crush! | not on our talent list | Titan's Grip Crush (melee) |
| Preserving Light | not on our talent list | Prayer of Preservation |
| Primal Strike | not on our talent list | Earthen Guardian |
| Recovering Prayer | not on our talent list | Prayer of Preservation |
| Runed Bullets | not on our talent list | Arcane Gunslinger (ranged) |
| Shadow Cleave | not on our talent list | Metamorphosis Tank |
| Soul Link with a Voidwalker | name not found | Shadow Bear (tank) |
| Spellslinger | not on our talent list | Arcane Gunslinger (ranged), Elemental Lord (caster) |
| Stance Dance | name not found | Titan's Grip Crush (melee) |
| Stone Shield | not on our talent list | Earthen Guardian |
| Swipe | not on our talent list | Shadow Bear (tank) |
| Water Elemental | not on our talent list | Cryomancer |

## 6. Proposed order of work

Each step is its own pull request, classified under change control; James merges.

| Step | What | Kind | Build needed |
|---|---|---|---|
| 1 | Correct the names in section 5, so the audit covers every real part | Docs | No |
| 2a | Add the missing ability versions to the core's rules for the twenty parts in section 2b | SQL | No |
| 2 | Give the seven build parts that **never fire** their trigger conditions from the tooltip | SQL (R9, R6) | No |
| 3 | GM tests of everything "fix live, untested", plus each step 2 batch | James's GM character | No |
| 4 | Write code for the **needs code** and **broken** parts (Divine Concord, Adrenaline Junkie, Blooming Growth, Seed of Life, Atonement, Shadow Shot and the rest) | C++ patches | Yes, 2 to 3 hours |
| 5 | GM test of each build's full rotation, build by build | James's GM character | No |
| Later | The other 190-odd enchants with the same never-fires fault | SQL | No |

## 7. Limits of this check

- A part graded "stock", "data only" or "scripted" can still misbehave (wrong numbers, wrong targets); only a test
  shows that.
- The check reads one level of fired spells, not deeper chains.
- Talent-list versions are checked; where a build names the enchant version instead, the enchant was checked.
- Script lookup is by spell id in the core and our files; a script that finds a spell another way would be missed,
  making a part look worse than it is, never better.

## 8. Progress on the parts that never fire (28 Nov)

| Part | Result | Where |
|---|---|---|
| Demonic Mind | Fixed: Demonic Wounds on direct spell damage, 75% | PR #291 |
| Swirling Maelstrom | Partly fixed: stack from Lava Lash and Stormstrike (33%); the stack for spending 5 Maelstrom Weapon stacks needs code | PR #291 |
| Cataclysmic Sundering | Fixed: three burning patches per Sundering | PR #292 |
| Maledictive Assault | Fixed: Shadow Bolt hits two more targets while Nightfall or Backlash is up | PR #292 |
| Blessing of the Divines | Fixed: random blessing from costed Holy and Nature heals; two blessings heal less than the tooltip | PR #293 (after #290) |
| Raging Onslaught | Needs code. Its +40% Raging Blow damage already works. The refund cannot be done in data: casting Rage! again resets its charges to 0 and loses one. A script must add one charge to Rage! on a Raging Blow hit (20%); the hit comes before the core spends the charge, so that is a true refund | Not started |
| Preservation | Needs code: Prayer of Preservation must give Preservation only to injured allies; the buff's +20% chance to be crit-healed is a placeholder; the next direct heal on that ally consumes it, heals 3 nearby allies, shields the ally and cuts Prayer of Preservation's cooldown by 3 s | Not started |

## 9. Progress on the needs-code parts, group A (28 Nov)

| Part | Result | Where |
|---|---|---|
| Arcane Gunslinger | False alarm for its Missile Barrage chance (add-target-trigger auras need no proc flags). Still missing: the extra Arcane Barrage target (300028 is applied by nothing) and the early removal | Code |
| Good Fortune | Fixed: the Holy crit buff now comes | PR #295 |
| Shot Weaving | Fixed: a ranged shot with each Arcane Missile | PR #295 |
| Blades of Blood | Needs code: Whirlwind's +5 targets uses spell modifier 34, which our core lacks; the Rend part is a placeholder | Code |
| Master of Kunai | Needs code: the Kunai stacks are never used up in data; the cooldown cut reaches only the stock Adrenaline Rush | Code |
| Toss and Throw | Needs code: in data the combo-point proc would use up the buff's charges; "more damage against monsters" uses spell modifier 38, which does not exist | Code |

## 10. Trace of the 14 suspected-code talents (28 Nov)

Each was traced through its spell data, the core's rule table and the core's code. Only five needed code.

| Talent | Build | What was wrong | Fix | Where |
|---|---|---|---|---|
| Wave of Despair | Dark Ranger | Nothing: the cone damage and the delayed removal are effects the core handles | None | - |
| Emanating Light | Holy Spell Tank | Nothing: a self buff pulsing Consecration damage | None | - |
| Icy Penance | Cryotherapist | Nothing: a Penance-style channel; the core already gives all 8 ranks their scaling | None | - |
| Plague Swarm | Plague Caster | No spell or attack power scaling | Data, all 8 ranks | PR #299 |
| Master of Shadows | Shadow Melee | At 3 stacks the rule cast an internal helper, not the buff; the stack buff gave the buff at any count; the crit part never came | Data | PR #299 |
| Stormborn | Enhancement | Only the stock Elemental Mastery and Shamanistic Rage counted; no scaling | Data | PR #299 |
| Frost Bomb | Cryomancer | Never exploded | Data: the core's Living Bomb script on all 8 ranks | PR #299 |
| Hunting Frenzy | Beast Master | The 2 free pet abilities were never used up (15 sec of free crits); +10% pet damage never reaches the pet | Data for the charges; the pet damage needs a pet aura (to do) | PR #299 |
| Heavyweight | Titan's Grip Crush | The stack buff is empty; Ready to Strike is never given; Thunder Clap's aftershock is not wired | Data, waiting for James on the auto-attack reset line | - |
| Blooming Growth | Blooming Growth, Seed of Life | Fired on every helpful spell with a 6-per-tick placeholder | Code | PR #300 |
| Gul'dan's Chosen | Soul Fire | The buff came but did nothing | Code | PR #300 |
| Shadow Shot | Dark Ranger | Damage works (Steady Shot's code); the Corruption part did nothing | Code | PR #300 |
| Time Bomb | Arcane Gunslinger | Nothing stored or exploded | Code | PR #300 |
| Preservation | Prayer of Preservation | Four placeholder parts | Code (to do) | - |
