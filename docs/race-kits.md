# Race kits: the new baseline

James's design, theme locked in (1 November 2026), before a balancing pass. Each race has two actives and two
passives, its own feel, and one passive with a trade skill rolled in (a trade benefit, a combat benefit, or both).
How you play changes a little with your racial, and it will not be the best for every class. Optional and per
realm ([roadmap.md](roadmap.md), item 6).

Build notes: *existing* = a spell the client already has; *reworked* = an existing spell with new server numbers,
tooltip text from the addon; *hook* = a small piece of C++; *new* = a new active (reused spell for now, or the
client patch from roadmap item 2). Trade skill bonuses (+5, +10) use an existing aura type.

Trade skills by race: Human all (+5), Dwarf Mining, Night Elf Tailoring, Gnome Engineering, Draenei Jewelcrafting,
Orc Blacksmithing, Undead Alchemy, Tauren Herbalism, Troll Skinning, Blood Elf Enchanting. Unclaimed:
Leatherworking, Inscription.

## Alliance

**Human**: good at everything, the safe pick, never the obvious one

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Will to Survive | Break free and become immune to stuns and incapacitates for 2 sec, taking 10% less damage. Used while stunned or incapacitated, it lasts 4 sec. | existing (Every Man for Himself), reworked. Each race owns its own kind of crowd control: Humans stuns and incapacitates, Undead charm, fear and sleep, Gnomes roots and snares |
| Active | Regroup | Gain Battle Ready. At or below 50% health, Will to Survive's remaining cooldown is also reduced by 30 sec. 1.5 min cooldown. | new |
| Passive | Battle Ready | After 5 sec out of combat, your next ability costs 10% less and has +10% crit chance. | hook. Capped at 10% so it never becomes best in slot (Subtlety rogue openers would be) |
| Passive | Jack of All Trades | +5 to all trade skills; 20% discount on learning recipes. | discount needs a hook |

**Dwarf**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Stoneform | +10% armor; removes and grants immunity to bleed, poison and disease for 8 sec. | existing, reworked |
| Active | Grudge | Mark an enemy for 15 sec: they deal 10% more damage to you, and you deal 10% more damage to them. | new |
| Passive | Treasure Hunter | Find treasure on the minimap. | existing (Find Treasure) |
| Passive | Deep Miner | +10 Mining. Indoors or underground, Treasure Hunter also shows ore veins, and those veins yield an extra ore or gem. | hooks for the tracking and the extra yield |

**Night Elf**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Shadowmeld | As is. 2 min cooldown. | existing |
| Active | Meditate | Put an out-of-combat ally into a trance (sleep) that restores 30% health and mana over 3 sec. 5 min cooldown. | new. The long cooldown keeps the Shadowmeld-then-Meditate trick occasional |
| Passive | Wisp Spirit | +75% speed while dead; revive with more health. | existing + hook for the revive health |
| Passive | Moonweaver | +10 Tailoring; extra cloth from humanoids; shorter Mooncloth cooldown. | hooks for the cloth and the cooldown |

**Gnome**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Escape Artist | Remove and become immune to snares, roots and slows; +30% movement speed for 3 sec. | existing, reworked |
| Active | Eureka | +10% haste and abilities cost 10% less for 5 sec. | new |
| Passive | Expansive Mind | +5% maximum Mana, Rage or Energy. | existing, reworked (Wrath's gives intellect) |
| Passive | Tinker | +10 Engineering; engineering items a little more reliable, or shorter engineering cooldowns (undecided). | shorter cooldowns is the simpler hook |

**Draenei**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Gift of the Naaru | As is, but cannot be interrupted. | existing, reworked |
| Active | Naaru's Ward | Target takes 10% less magic damage and receives 10% more healing for 8 sec. | new |
| Passive | Gemcutter's Eye | +10 Jewelcrafting; chance of an extra gem from Jewelcrafting. | hook for the extra gem |
| Passive | Heroic Presence | +1% hit for your party. | existing |

## Horde

**Orc**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Blood Fury | +5% attack power and spell power per nearby ally (players, NPCs, pets; up to 4), counted once when cast, for 15 sec; 10% less healing taken. 2 min cooldown. | existing, reworked + hook to count allies |
| Active | Command | Nearby allies (very short range; players, NPCs and pets) gain 5% attack power, spell power and movement speed for 8 sec. | new; pairs with Blood Fury: stand together |
| Passive | Forge Hardened | +10 Blacksmithing; 5% chance to avoid a killing blow in combat (90 sec cooldown). | hook |
| Passive | Warsong | Each killing blow gives 15% movement speed and 5% haste for 6 sec. | hook. Signature, locked 13 Nov |

**Undead**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Will of the Forsaken | Removes all charm, fear and sleep effects. | existing |
| Active | Cannibalize | 7% health and mana every 2 sec for 10 sec, from a humanoid or undead corpse within 5 yards; movement, actions or damage cancel it. | existing |
| Passive | Forsaken Apothecary | +10 Alchemy; potions and elixirs you make have a chance to make an extra, and those you drink last longer. | hooks for the extra craft and the duration |
| Passive | Unliving | When you die, rise as a ghoul for 10 sec and keep fighting; a killing blow in that time brings you back at 20% health. Once every 15 min (about once per battleground). | hook; the ghoul form reuses Raise Ally's. Signature, locked 13 Nov |

**Tauren**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | War Stomp | Stuns up to 5 nearby enemies for 2 sec. 1.5 min cooldown. | existing |
| Active | Bull Rush | Gain 10% health as temporary health for 5 sec, and 10 extra stacks of Plainsrunning. | new |
| Passive | Plainsrunning | +1% movement speed per second while you keep moving, up to 60%. When you stop it drains 10% per second (full to nothing in 6 sec). | hook. Signature, locked 13 Nov |
| Passive | Tauren Health | +5% health; +10 Herbalism; chance for additional herbs. | existing (Endurance) + hook for the herbs |

**Troll**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Berserking | 10% haste, plus up to 10% more based on missing health, for 15 sec. 2 min cooldown. | existing, reworked |
| Active | Rapid Regeneration | Regenerate 50% of maximum health over 6 sec, but 50% slower movement and haste, and you cannot dodge, parry or block meanwhile. | new |
| Passive | Voodoo Regeneration | Below 35% health, regenerate 3% of maximum health per second for 8 sec. Once every 2 min. | hook. Signature, locked 13 Nov |
| Passive | Trophy Hunter | +10 Skinning; 5% more damage to enemies below 20% health, plus 1% per body skinned, stacking up to 10. | hook; stack duration to settle (Headhunter had 1 min per stack) |

**Blood Elf**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Arcane Torrent | Spends all Mana Tap charges: a 1 sec area silence, and 5% mana, rage or energy per charge. 2 min cooldown. | existing, reworked (the Burning Crusade Torrent already spent Mana Tap charges) |
| Active | Mana Tap | Gain a Mana Tap charge, up to 3. | existing; needs a limit on gaining charges (a cooldown, or a target with mana) |
| Passive | Arcane Affinity | +10 Enchanting; chance of extra materials when disenchanting. | hook for the extra materials |
| Passive | Arcane Hunger | Abilities cost 3% more per Mana Tap charge; damage and healing dealt +2% per charge. | hook |

## Signature passives (13 November)

Each race gets one passive as noticeable as Plainsrunning, and each owns its niche: Tauren movement, Trolls healing
in combat, Gnomes and Blood Elves resources, Orcs kills and haste, Undead death. Locked: Tauren Plainsrunning (drains
over 6 sec), Troll Voodoo Regeneration, Orc Warsong, Undead Unliving (15 min), Gnome as above (Expansive Mind's 5%
resources, Escape Artist's speed boost), Blood Elf Arcane Hunger. Still open: Human, Dwarf, Night Elf, Draenei.

## For the balancing pass

- Draenei Heroic Presence and Orc Spell Scarred are the two passives you would rarely notice.
- Humans are likely the strongest in PvP defence; timing levers (Will to Survive's cooldown, Regroup's 30 sec) first.
- Plainsrunning's cap and drop rules matter most in battlegrounds.
- Mana Tap's charge limit, Trophy Hunter's stack duration and Tinker's choice are still open.
