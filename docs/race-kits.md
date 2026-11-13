# Race kits: signature passives

James's design, settled 13 November 2026. Every race keeps its stock Wrath racials as they are, and gains one
**signature passive**: one noticeable effect that defines how the race plays. Optional and per realm
([roadmap.md](roadmap.md), item 6).

This replaces the first design (1 November), which reworked every race's actives and added trade-skill passives.
That one is dropped: on this server, Mystic Enchants already give effects like +100% critical damage or triple
ability damage for little investment, so signature passives of this size sit fine alongside them, and a full
rework isn't needed. On a plain Wrath server these numbers would be too high.

Each race owns a niche, so no two signatures overlap: Tauren movement, Trolls enduring on health and Gnomes on resources, Blood Elves trading
resources for damage, Orcs greedy rushes (solo), Undead death, Humans hybrid builds, Dwarves exploring and gathering, Night Elves
stealth, Draenei patient group fights.

Build notes: *hook* = a small piece of C++. Tooltips come from the addon.

## Signature passives

| Race | Signature passive | What it does | Notes |
| --- | --- | --- | --- |
| Human | Spellsword | The best race for physical and spell hybrids. **Stat bridge:** whichever of attack power and spell power is lower gains 30% of the higher; a conversion you already have (Sheath of Light, Mental Quickness) doesn't stack, you get the bigger. **Spells into attacks:** +10% melee and ranged attack speed for 3 sec per second of cast or channel time (instants give nothing), up to 12 sec. **Attacks into spells:** each melee or ranged ability (not auto-attacks) adds 3 sec of +10% cast speed, up to 9 sec. | hooks. Designed hybrids already convert, so the bridge lifts the weird Wildcard ones |
| Dwarf | Prospector's Spirit | Each kind of gathering gives its own buff, stacking up to 3 times and lasting 2 hours (refreshed by gathering more). **Mining** a vein: +2% Stamina per stack. **Herbalism**: +2% Intellect and Spirit. **Skinning**: +2% Strength and Agility. **Treasure** (opening a chest; Find Treasure shows them): +2% damage and healing. **Fishing** a catch: +3% movement and swim speed, and at 3 stacks water breathing. Natural explorers: mixing gathering, chests and fishing between dungeons gives everything; repeating one only gives its 3 stacks. | hooks (gathering, loot and fishing) |
| Night Elf | Ambush | Entering stealth (Shadowmeld or a class stealth) readies your next ability: 10% cheaper and 50% more damage or healing. At most once every 20 sec. | hook |
| Gnome | Overclock | The endurance king for resources: gnomes learn their enemy and plan their next move. +5% maximum mana, energy, rage and runic power. Every 15 sec in combat, another step: abilities cost 1% less (whatever resource they use) and runes recharge 1% faster, and you're instantly topped up by that step's number in every resource (1% at the first step, 2% at the second, up to 10% at the tenth). After 10 steps (2 min 30 sec) it stops: the 10% discount stays for the rest of the fight, 55% topped up in all. Resets when combat ends. About 12% of a mana pool in a 1 min fight, 110% in 5 min, 185% in 10 min. Escape Artist also gives +30% movement speed for 3 sec. | hook (reworks the stock Expansive Mind, which gives intellect); Escape Artist gains a speed effect |
| Draenei | Radiant Presence | Patient, steady, best in a group. In combat, gain a stack of Light every 6 sec, up to 5 (30 sec to fill). Each stack gives you and every ally within 30 yards (pets and guardians included) +1% damage and healing and 1% less damage taken (up to 5%). Stacks fade 10 sec after combat. Your auras and totems reach 50% further. Doesn't stack with a second Draenei. | hook |
| Orc | Bloodrush | Greedy, fast, best alone. For each enemy in combat with you, +2% damage and +2% haste, up to 5 enemies (+10%). Each killing blow also gives +15% movement speed for 6 sec. All gone out of combat. | hook |
| Undead | Grave Defiance | Below 35% health you deal and heal more, rising evenly to +30% at 1% health (about +13% at 20%, +22% at 10%). It lasts up to 15 sec at a time; when it ends (time up, or healed above 35%) it can't start again for 45 sec, so bouncing across the line (Drain Life, Life Tap) gains nothing: at most 15 sec in every minute. When you die, you rise as a ghoul for 10 sec and keep fighting, dealing and healing 30% less (the low-health bonus doesn't apply to the ghoul); a killing blow by the ghoul brings you back at 20% health. Once every 5 min. Living dangerously: the opposite of Trolls, who want to heal back up. | hooks; the ghoul form reuses Raise Ally's |
| Tauren | Plainsrunning | While you keep moving on foot, speed builds to a cap over 60 sec of running. The cap is your level + 40% (41% at level 1, 100% at level 60). When you stop it drains, full to nothing in 6 sec. Adds on top of other speed effects (at full, Sprint's +70% and Plainsrunning's +100% make +170%). Not while mounted; paused while carrying a battleground flag. | hook |
| Troll | Voodoo Regeneration | The endurance king for health. Out of combat, health regenerates 50% faster. In combat, regenerate 0.3% of maximum health per second (a full bar about every 5.5 min), halved while the burst below is on cooldown. Below 35% health, regenerate 3% of maximum health per second for 8 sec, once every 2 min. Replaces the stock Regeneration passive. | hook |
| Blood Elf | Arcane Hunger | Each ability or spell you use adds a stack, up to 10. Per stack, abilities deal or heal 1% more and cost 2% more (at 10: +10% damage and healing, +20% cost). Stop using abilities for 5 sec (when mana would start regenerating) and the stacks fall off. **Arcane Torrent** eats every stack: besides its silence, it restores 2% of your maximum mana, rage or energy per stack eaten (20% at 10), and its cooldown drops to 1 min. Keep hitting harder at a growing cost, or cash the stacks in for resources. | hook; Arcane Torrent reworked (cooldown and the refund) |

## Already done

- Every active racial is off the global cooldown (Will of the Forsaken, Cannibalize and Gift of the Naaru were not):
  `patches/52-racials.ps1` and the client patch.

## Balance notes

- First paper review (13 November): the signatures are big on purpose and fit the server's power level. The ones to
  watch once players try them: Plainsrunning (the strongest; first lever would be half the cap in combat), Ambush
  (PvP burst from Vanish or Shadowmeld), Spellsword's 30% and 10%, and Voodoo Regeneration with Troll Berserking.
- Undead (13 November): the ghoul deals and heals 30% less, so dying on purpose into a group isn't worth it, and its
  cooldown came down from 15 to 5 min. Compared with class abilities: weaker than Shaman Reincarnation (30 min, no
  kill needed) and Priest Spirit of Redemption (every death, full healing), so 5 min is fair. In raids it's a
  self-revive every 5 min, but only by killing something, so mostly on adds. Watch Undead Warlocks and Death
  Knights, who can lower their own health (Life Tap, Death Pact) to sit in Grave Defiance on purpose (now capped at 15 sec in every minute).
- Change numbers after player feedback, not before.
