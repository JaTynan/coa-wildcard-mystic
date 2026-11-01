# Race kits: the new baseline

James's design (1 November 2026), locked in as the starting point. Each race has two actives and two passives, and its own feel: how you play
changes a little based on your racial, and it will not be the best for every class. Balance comes later; the
first goal is that every race feels different. Optional and per realm ([roadmap.md](roadmap.md), item 6).

Notes flag what to watch in testing and how each would be built: *existing* = a spell the client already has;
*reworked* = an existing spell with new server numbers, tooltip text from the addon; *hook* = a small piece
of C++; *new* = a new active (reused spell for now, or the client patch from roadmap item 2).

## Alliance

**Human**: good at everything, the safe pick, never the obvious one

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Will to Survive | Break free of stuns and incapacitates and become immune to them for 3 sec. Used while stunned or incapacitated, you also take 20% less critical damage for 10 sec. | existing (Every Man for Himself), reworked. Covers stuns and incapacitates; Undead cover charm, fear and sleep, Gnomes roots and snares, so each race owns its own kind of crowd control. Can be used ahead of a stun (proactive) or to break one (reactive, with the crit reduction) |
| Active | Alert | +5% stealth detection and +5% critical strike chance with spells, melee and ranged attacks for 8 sec. | new; watch it doesn't become a damage button pressed on cooldown |
| Passive | Versatile | Crowd control on you has 10% less effect, and +1% to all stats. | reworked; a small, always-useful passive that suits the safe pick |
| Passive | Jack of All Trades | +5 to all trade skills; 20% discount on learning recipes. | skill bonus existing aura type; discount needs a hook |

**Dwarf**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Stoneform | +10% armor; removes and grants immunity to bleed, poison and disease for 8 sec. | existing, reworked |
| Active | Grudge | Mark an enemy for 15 sec: they deal 10% more damage to you, and you deal 10% more damage to them. | new; a debuff with "damage from caster" exists, the other half may need a hook. A duel-style choice: who is worth the grudge |
| Passive | Treasure Hunter | Find treasure on the minimap. | existing (Find Treasure) |
| Passive | Dungeon Crawler | +10% movement speed and +2% hit chance while indoors. | hook (indoors check); strong in dungeons, watch it |

**Night Elf**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Shadowmeld | As is. | existing |
| Active | Meditate | Put an out-of-combat ally into a trance (sleep) that restores 30% health and mana over 3 sec. | new; open question: with Shadowmeld dropping combat, self-use mid-dungeon could become a loop. Options: a long cooldown, allies only, or a shared cooldown with Shadowmeld |
| Passive | Wisp Spirit | +75% speed while dead; revive with more health. | existing + hook for the revive health |
| Passive | Quickness | As is (Wrath: +2% dodge). | existing |

**Gnome**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Escape Artist | Remove and become immune to snares, roots and slows; +30% movement speed for 3 sec. | existing, reworked |
| Active | Eureka | +10% haste and abilities cost 10% less for 5 sec. | new |
| Passive | Expansive Mind | +5% maximum Mana, Rage or Energy. | existing |
| Passive | Tinker | +10 Engineering, and either more reliable engineering items or shorter engineering cooldowns (undecided). | skill existing; shorter cooldowns is the simpler hook, reliability touches many items |

**Draenei**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Gift of the Naaru | As is, but cannot be interrupted. | existing, reworked |
| Active | Naaru's Ward | Target takes 10% less magic damage and receives 10% more healing for 8 sec. | new |
| Passive | Gemcutter's Eye | +10 Jewelcrafting; chance of an extra gem from Jewelcrafting. | skill existing; extra gem needs a hook |
| Passive | Heroic Presence | +1% hit for your party. | existing |

## Horde

**Orc**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Blood Fury | +5% attack power and spell power per nearby ally (players, NPCs, pets; up to 4), counted once when cast, for 15 sec; 10% less healing taken. 2 min cooldown. | existing, reworked + hook to count allies; leans into groups and pets |
| Active | Command | Nearby allies (very short range; players, NPCs and pets) gain 5% attack power, spell power and movement speed for 8 sec. | new; could make orcs group up to keep it running. Pairs with Blood Fury: stand together |
| Passive | Hardiness | 5% chance to avoid a killing blow in combat. | hook; can make memorable moments, watch it in PvP |
| Passive | Spell Scarred | 5% less damage taken from curses and banes. | hook or reworked; deliberately small next to Hardiness |

**Undead**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Will of the Forsaken | Removes all charm, fear and sleep effects. | existing |
| Active | Cannibalize | 7% health and mana every 2 sec for 10 sec, from a humanoid or undead corpse within 5 yards; movement, actions or damage cancel it. | existing |
| Passive | Unbreathing | Unlimited breath underwater. | reworked (Underwater Breathing) |
| Passive | Dead Man's Hunger | Eating a corpse grants 2% leech for 5 min. | hook (or the enchant action handler) |

**Tauren**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | War Stomp | Stuns up to 5 nearby enemies for 2 sec. 1.5 min cooldown. | existing |
| Active | Bull Rush | Gain 10% health as temporary health for 5 sec, and 10 extra stacks of Plainsrunning. | new; starts or keeps the momentum |
| Passive | Plainsrunning | +1% movement speed per second while you keep moving, up to 60%. | hook; 60 sec to cap. Decide what makes it drop (stopping, damage, mounting) |
| Passive | Herbalist | +10 Herbalism; chance for additional herbs. | skill existing; extra herbs need a hook |

**Troll**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Berserking | 10% haste, plus up to 10% more based on missing health, for 15 sec. 2 min cooldown. | existing, reworked |
| Active | Rapid Regeneration | Regenerate 50% of maximum health over 6 sec, but 50% slower movement and haste, and you cannot dodge, parry or block meanwhile. | new |
| Passive | Regeneration | +20% health regeneration, and 20% of it continues in combat. | existing, reworked |
| Passive | Headhunter | 5% more damage to enemies below 20% health, plus 1% per enemy you landed the killing blow on, stacking up to 10; each stack lasts 1 min. | hook (or the enchant action handler with a kill event); an execute theme for trolls; stacks can drop between dungeon pulls, which rewards aggressive play |

**Blood Elf**

| | Racial | What it does | Notes |
| --- | --- | --- | --- |
| Active | Mana Tap | Gain a Mana Tap charge, up to 3. | existing; needs a limit on how charges are gained (a cooldown, or a target with mana as originally), or it is three presses |
| Active | Arcane Torrent | Spends all Mana Tap charges: a 1 sec area silence, and 5% mana, rage or energy per charge. 2 min cooldown. | existing, reworked (the Burning Crusade Torrent already spent Mana Tap charges) |
| Passive | Arcane Affinity | +10 Enchanting; chance of extra materials when disenchanting. | skill existing; extra materials need a hook |
| Passive | Arcane Hunger | Abilities cost 3% more per Mana Tap charge; damage and healing dealt +2% per charge. | hook; a nice loop with the two actives: hold charges for power, or spend them on Torrent |
