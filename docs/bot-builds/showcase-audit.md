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

## 2. The main finding: proc talents that can never fire

43 parts used by these builds are talents of the "when you do X, gain Y" kind whose spell data gives **no trigger
conditions** (proc flags 0), with no `spell_proc` row, action-table rule or script anywhere. Ascension kept those
conditions in its own database, which we do not have. The core makes a proc rule from the spell data only when the
proc flags are set (`SpellMgr.cpp`, "Skip if no proc flags in DBC"), so these talents sit on the character and do
nothing.

Evidence that this is real, not theory: two GM tests on 2 and 3 Nov hit exactly this case. Demonic Mind ("the proc on
enemies did not fire") and Devour Mind ("The Devourer buff does not") both fail on a proc aura with proc flags 0.
The Legendary deep audit of 15 Nov (`sql/enchants/016-dead-triggers.sql`) fixed 30 enchants for the same reason.

The October enchant audit (`enchants/enchant_audit.py`) never looked at proc flags, so it marked these "standard"
(working). Beyond the builds, **679 enchants the tracker lists as "working (audit)" have the same fault** (587 Epic,
53 Uncommon, 23 Rare, 16 Legendary). This is the biggest gap between "working" in the tracker and working in game.

The fix is known and needs no build: a `spell_proc` row with the conditions from the tooltip (recipe R9), or an
action-table rule where the trigger must be exact spells (R6, in every build since build6). Both are SQL, live at
the next restart.

## 3. Every build

Counts are distinct parts per build. "Core parts to fix" counts only parts in the build's core rows, not its rolled
extras.

| Build | Parts | Stock or data only | Scripted | Fix untested | Never fires | Needs code | Broken | Unresolved | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| Arcane Gunslinger (ranged) | 32 | 21 | 2 | 0 | 5 | 1 | 0 | 3 | 6 core part(s) to fix |
| Arcane Mage | 23 | 19 | 1 | 1 | 1 | 0 | 0 | 1 | 1 core part(s) to fix |
| Arcane Paladin | 23 | 13 | 1 | 0 | 1 | 1 | 1 | 6 | 3 core part(s) to fix |
| Beast Master | 16 | 13 | 0 | 1 | 2 | 0 | 0 | 0 | 2 core part(s) to fix |
| Blooming Growth | 13 | 11 | 0 | 0 | 0 | 2 | 0 | 0 | 2 core part(s) to fix |
| Claw-sader | 26 | 25 | 0 | 0 | 0 | 0 | 0 | 1 | Ready to test |
| Cryomancer | 16 | 13 | 0 | 0 | 0 | 1 | 0 | 2 | 1 core part(s) to fix |
| Cryotherapist | 7 | 6 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Dark Ranger | 19 | 14 | 0 | 0 | 1 | 3 | 0 | 1 | 3 core part(s) to fix |
| Discipline | 21 | 19 | 0 | 0 | 1 | 1 | 0 | 0 | 2 core part(s) to fix |
| Earthen Guardian | 17 | 12 | 1 | 0 | 2 | 0 | 0 | 2 | 2 core part(s) to fix |
| Elemental Lord (caster) | 20 | 16 | 0 | 1 | 1 | 0 | 0 | 2 | Ready to test |
| Enhancement | 19 | 11 | 1 | 0 | 2 | 0 | 0 | 5 | 2 core part(s) to fix |
| Frost Death Knight (melee) | 15 | 14 | 0 | 0 | 0 | 0 | 0 | 1 | Ready to test |
| Holy Paladin | 17 | 13 | 1 | 1 | 2 | 0 | 0 | 0 | 2 core part(s) to fix |
| Holy Radiance (healer) | 17 | 14 | 0 | 0 | 3 | 0 | 0 | 0 | 2 core part(s) to fix |
| Holy Spell Tank | 28 | 26 | 0 | 0 | 0 | 1 | 0 | 1 | 1 core part(s) to fix |
| Immolate and Conflagrate (caster) | 24 | 22 | 0 | 0 | 1 | 1 | 0 | 0 | 1 core part(s) to fix |
| Lightning Warrior | 18 | 16 | 0 | 0 | 1 | 0 | 0 | 1 | Ready to test |
| Mana-forged Barrier | 9 | 7 | 0 | 1 | 0 | 0 | 0 | 1 | Ready to test |
| Metamorphosis Tank | 16 | 11 | 2 | 0 | 0 | 0 | 0 | 3 | Ready to test |
| Ninja | 33 | 27 | 0 | 1 | 4 | 0 | 1 | 0 | 4 core part(s) to fix |
| Plague Caster (Spirit Stacker) | 20 | 18 | 0 | 0 | 1 | 1 | 0 | 0 | 2 core part(s) to fix |
| Prayer of Preservation | 22 | 15 | 1 | 2 | 2 | 0 | 0 | 2 | 2 core part(s) to fix |
| Protection Warrior | 20 | 17 | 0 | 0 | 3 | 0 | 0 | 0 | 3 core part(s) to fix |
| Pyroblast Fire Mage (caster) | 16 | 13 | 0 | 1 | 1 | 0 | 0 | 1 | 1 core part(s) to fix |
| Restoration Shaman | 21 | 17 | 0 | 0 | 0 | 0 | 0 | 4 | Ready to test |
| Retribution | 18 | 17 | 1 | 0 | 0 | 0 | 0 | 0 | Ready to test |
| Seed of Life | 12 | 11 | 0 | 0 | 0 | 1 | 0 | 0 | 1 core part(s) to fix |
| Shadow Bear (tank) | 22 | 16 | 0 | 0 | 1 | 0 | 0 | 5 | 1 core part(s) to fix |
| Shadow Melee (melee) | 19 | 15 | 0 | 0 | 3 | 0 | 0 | 1 | 3 core part(s) to fix |
| Soul Fire (caster) | 25 | 24 | 0 | 0 | 1 | 0 | 0 | 0 | 1 core part(s) to fix |
| Tide Chain Healer | 23 | 20 | 2 | 1 | 0 | 0 | 0 | 0 | Ready to test |
| Titan's Grip Crush (melee) | 29 | 21 | 0 | 0 | 5 | 0 | 0 | 3 | 5 core part(s) to fix |
| Total Eclipse | 15 | 14 | 0 | 0 | 0 | 0 | 0 | 1 | Ready to test |
| Vampire Lord | 14 | 11 | 2 | 1 | 0 | 0 | 0 | 0 | Ready to test |
| Winds of Winter (melee) | 10 | 8 | 1 | 0 | 0 | 0 | 0 | 1 | Ready to test |

"Ready to test" means no known gap in its core parts, not that it works: every Wildcard part still needs a GM test.

## 4. The parts to fix or test

| Part | Spell | Grade | Core or extra | Used by |
|---|---|---|---|---|
| Divine Concord | 277860 | broken | core | Arcane Paladin |
| Adrenaline Junkie | 285279 | broken | extra | Ninja |
| Arcane Arrows | 284901 | never fires | core | Arcane Gunslinger (ranged) |
| Arcane Gunslinger | 274586 | never fires | core | Arcane Gunslinger (ranged) |
| Arcane Motes | 281905 | never fires | core | Arcane Mage |
| Arcane Shelling | 274593 | never fires | core | Arcane Gunslinger (ranged) |
| Blades of Blood | 285895 | never fires | core | Titan's Grip Crush (melee) |
| Blessing of the Divines | 273020 | never fires | core | Prayer of Preservation |
| Cataclysmic Sundering | 277180 | never fires | core | Earthen Guardian |
| Clean Pass | 277485 | never fires | core | Ninja |
| Critical Serration | 277609 | never fires | core | Ninja |
| Demonic Mind | 283942, 978704, 1586069 | never fires | core | Pyroblast Fire Mage (caster) |
| Double Down | 275235 | never fires | core | Shadow Melee (melee) |
| Elemental Destruction | 274730 | never fires | core | Immolate and Conflagrate (caster) |
| Enduring Aegis | 1584825 | never fires | core | Protection Warrior |
| Faithful Light | 270662 | never fires | core | Holy Radiance (healer) |
| Felstorm | 276053 | never fires | core | Shadow Melee (melee) |
| Fetch Me Their Bones! | 284454 | never fires | core | Beast Master |
| Glimmer of Light | 277692 | never fires | core | Holy Paladin |
| Good Fortune | 284012 | never fires | core | Holy Radiance (healer) |
| Gul'dan's Chosen | 277150 | never fires | core | Soul Fire (caster) |
| Heavyweight | 273378 | never fires | core | Titan's Grip Crush (melee) |
| Holy Spirit | 273920 | never fires | core | Discipline |
| Hunting Frenzy | 1180820 | never fires | core | Beast Master |
| In for the Kill | 283597 | never fires | core | Titan's Grip Crush (melee) |
| Lunar Synergy | 282083 | never fires | core | Arcane Gunslinger (ranged) |
| Maledictive Assault | 271400 | never fires | core | Shadow Bear (tank) |
| Master of Kunai | 277475 | never fires | core | Ninja |
| Master of Shadows | 275491 | never fires | core | Shadow Melee (melee) |
| Preservation | 276273 | never fires | core | Prayer of Preservation |
| Prophet of Wrath | 275427 | never fires | core | Arcane Paladin |
| Raging Onslaught | 275920 | never fires | core | Titan's Grip Crush (melee) |
| Shield Finesse | 285548 | never fires | core | Protection Warrior |
| Shot Weaving | 274591 | never fires | core | Arcane Gunslinger (ranged) |
| Stormborn | 274078 | never fires | core | Enhancement |
| Swirling Maelstrom | 984616 | never fires | core | Enhancement |
| Sword and Thunder | 284435 | never fires | core | Protection Warrior |
| Synergetic Light | 285818 | never fires | core | Holy Paladin |
| Titan's Fury | 273662 | never fires | core | Titan's Grip Crush (melee) |
| Toss and Throw | 277455 | never fires | core | Ninja |
| Wrath of the Plague | 284744 | never fires | core | Plague Caster (Spirit Stacker) |
| Zephyr | 284414 | never fires | core | Earthen Guardian |
| Legacy of the Arcanist | 271284 | never fires | extra | Elemental Lord (caster), Lightning Warrior |
| Light of Life | 271489 | never fires | extra | Holy Radiance (healer) |
| Shadow Infusion | 285942 | never fires | extra | Dark Ranger |
| Atonement | 270631 | needs code | core | Discipline |
| Blooming Growth | 272214 | needs code | core | Blooming Growth, Seed of Life |
| Dark Arrows | 276808 | needs code | core | Dark Ranger |
| Emanating Light | 1584044 | needs code | core | Holy Spell Tank |
| Frost Bomb | 271936, 954263, 1569556 | needs code | core | Cryomancer |
| Icy Penance | 92754, 271341, 1568670 | needs code | core | Cryotherapist |
| Plague Swarm | 276431, 1577100 | needs code | core | Plague Caster (Spirit Stacker) |
| Seal of Arcane Wrath | 277854, 984284 | needs code | core | Arcane Paladin |
| Seed of Life | 273346 | needs code | core | Blooming Growth |
| Shadow Shot | 276811 | needs code | core | Dark Ranger |
| Time Bomb | 284591, 982484 | needs code | core | Arcane Gunslinger (ranged) |
| Wave of Despair | 283182, 901054, 1583807 | needs code | core | Dark Ranger |
| Elemental Immolate | 274734 | needs code | extra | Immolate and Conflagrate (caster) |
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

These names do not match a learnable talent or ability. Some are a combination written in one cell ("X with Y"), some
are the name of an effect rather than the talent that gives it. Each build doc needs the exact talent name.

| Name in the doc | Problem | Used by |
|---|---|---|
| Arcane Crusade | not learnable | Arcane Paladin |
| Arcane Divinity | not learnable | Arcane Paladin |
| Arcanesworn | not learnable | Arcane Paladin |
| Assault and Battery | not learnable | Lightning Warrior |
| Blade of the Magisters | not learnable | Arcane Paladin |
| Blood Presence for damage | name not found | Frost Death Knight (melee) |
| Challenging Howl | not learnable | Metamorphosis Tank |
| Combustion with Playing with Fire | name not found | Pyroblast Fire Mage (caster) |
| Corrupted Maelstrom Weapon | not learnable | Shadow Melee (melee) |
| Demonic Pact and Demonic Tactics | name not found | Arcane Gunslinger (ranged) |
| Dual-wield talents | name not found | Metamorphosis Tank |
| Echoing Warcry | not learnable | Titan's Grip Crush (melee) |
| Etheric Vengeance | not learnable | Arcane Paladin |
| Exposed Weakness | not learnable | Winds of Winter (melee) |
| Felhunter and Master Demonologist | name not found | Shadow Bear (tank) |
| Fire Elemental | name not found | Elemental Lord (caster) |
| Flametongue | name not found | Restoration Shaman |
| Glacial Burst with Frostflame Shock | name not found | Cryomancer |
| Holy Fire with Divine Prophet | name not found | Arcane Paladin |
| Hoplite Training | not learnable | Shadow Bear (tank) |
| Imp | name not found | Holy Spell Tank |
| Invocation  as a defensive channel | name not found | Mana-forged Barrier |
| Iron Fur | name not found | Shadow Bear (tank) |
| Light Swipe | name not found | Claw-sader |
| Magma | not learnable | Enhancement |
| Mana Gem | name not found | Arcane Mage |
| Mana Spring | not learnable | Enhancement, Restoration Shaman |
| Mana Tide | not learnable | Restoration Shaman |
| Moonkin Form's talent | name not found | Total Eclipse |
| Necromancer's Touch with Enslave Demon | name not found | Dark Ranger |
| Prepared to Crush! | not learnable | Titan's Grip Crush (melee) |
| Preserving Light | not learnable | Prayer of Preservation |
| Primal Strike | not learnable | Earthen Guardian |
| Recovering Prayer | not learnable | Prayer of Preservation |
| Runed Bullets | not learnable | Arcane Gunslinger (ranged) |
| Searing | name not found | Enhancement |
| Shadow Cleave | not learnable | Metamorphosis Tank |
| Soul Link with a Voidwalker | name not found | Shadow Bear (tank) |
| Spellslinger | not learnable | Arcane Gunslinger (ranged), Elemental Lord (caster) |
| Stance Dance | name not found | Titan's Grip Crush (melee) |
| Stone Shield | not learnable | Earthen Guardian |
| Strength of Earth | not learnable | Enhancement |
| Swipe | not learnable | Shadow Bear (tank) |
| Water Elemental | not learnable | Cryomancer |
| Windfury | not learnable | Enhancement |
| Wrath of Air | name not found | Restoration Shaman |

## 6. Proposed order of work

Each step is its own pull request, classified under change control; James merges.

| Step | What | Kind | Build needed |
|---|---|---|---|
| 1 | Correct the names in section 5, so the audit covers every real part | Docs | No |
| 2 | Give the build parts that **never fire** their trigger conditions from the tooltip, in batches of about ten | SQL (R9, R6) | No |
| 3 | GM tests of everything "fix live, untested", plus each step 2 batch | James's GM character | No |
| 4 | Write code for the **needs code** and **broken** parts (Divine Concord, Adrenaline Junkie, Blooming Growth, Seed of Life, Atonement, Shadow Shot and the rest) | C++ patches | Yes, 2 to 3 hours |
| 5 | GM test of each build's full rotation, build by build | James's GM character | No |
| Later | The other 600-odd enchants with the same never-fires fault | SQL | No |

## 7. Limits of this check

- A part graded "stock", "data only" or "scripted" can still misbehave (wrong numbers, wrong targets); only a test
  shows that.
- The check reads one level of fired spells, not deeper chains.
- Talent-list versions are checked; where a build names the enchant version instead, the enchant was checked.
- Script lookup is by spell id in the core and our files; a script that finds a spell another way would be missed,
  making a part look worse than it is, never better.
