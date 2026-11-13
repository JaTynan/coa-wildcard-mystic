# Race kits: signature passives

James's design, settled 13 November 2026. Every race keeps its stock Wrath racials as they are, and gains one
**signature passive**: one noticeable effect that defines how the race plays. Optional and per realm
([roadmap.md](roadmap.md), item 6).

This replaces the first design (1 November), which reworked every race's actives and added trade-skill passives.
That one is dropped: on this server, Mystic Enchants already give effects like +100% critical damage or triple
ability damage for little investment, so signature passives of this size sit fine alongside them, and a full
rework isn't needed. On a plain Wrath server these numbers would be too high.

Each race owns a niche, so no two signatures overlap: Tauren movement, Trolls healing in combat, Gnomes and Blood
Elves resources, Orcs kills and haste, Undead death, Humans hybrid builds, Dwarves standing firm, Night Elves
stealth, Draenei leading a group.

Build notes: *hook* = a small piece of C++. Tooltips come from the addon.

## Signature passives

| Race | Signature passive | What it does | Notes |
| --- | --- | --- | --- |
| Human | Spellsword | The best race for physical and spell hybrids. **Stat bridge:** whichever of attack power and spell power is lower gains 30% of the higher; a conversion you already have (Sheath of Light, Mental Quickness) doesn't stack, you get the bigger. **Spells into attacks:** +10% melee and ranged attack speed for 3 sec per second of cast or channel time (instants give nothing), up to 12 sec. **Attacks into spells:** each melee or ranged ability (not auto-attacks) adds 3 sec of +10% cast speed, up to 9 sec. | hooks. Designed hybrids already convert, so the bridge lifts the weird Wildcard ones |
| Dwarf | Sure-Footed | Knockbacks and pulls move you half as far, fall damage is halved, and dazes last half as long. | hook |
| Night Elf | Ambush | Entering stealth (Shadowmeld or a class stealth) readies your next ability: 10% cheaper and 50% more damage or healing. At most once every 20 sec. | hook |
| Gnome | Expansive Mind | +5% maximum mana, rage or energy (reworks the stock passive, which gives intellect). Escape Artist also gives +30% movement speed for 3 sec. | aura rework; Escape Artist gains a speed effect |
| Draenei | Radiant Presence | Your auras and totems reach 50% further. Allies within 30 yards take 1% less damage per enemy within 30 yards, up to 5%. Doesn't stack with a second Draenei. | hook |
| Orc | Warsong | Each killing blow gives 15% movement speed and 5% haste for 6 sec. | hook |
| Undead | Unliving | When you die, rise as a ghoul for 10 sec and keep fighting; a killing blow in that time brings you back at 20% health. Once every 15 min (about once per battleground). | hook; the ghoul form reuses Raise Ally's |
| Tauren | Plainsrunning | While you keep moving on foot, speed builds to a cap over 60 sec of running. The cap is your level + 40% (41% at level 1, 100% at level 60). When you stop it drains, full to nothing in 6 sec. Adds on top of other speed effects (at full, Sprint's +70% and Plainsrunning's +100% make +170%). Not while mounted; paused while carrying a battleground flag. | hook |
| Troll | Voodoo Regeneration | Below 35% health, regenerate 3% of maximum health per second for 8 sec. Once every 2 min. The stock Regeneration passive stays (10% of normal health regeneration continues in combat), but pauses while Voodoo Regeneration is on cooldown: the burst uses up the troll's regeneration, and a long fight at high health still keeps a trickle. | hook |
| Blood Elf | Arcane Hunger | Each ability you use adds a charge, up to 3; they fade after 10 sec without using one. Per charge, abilities cost 3% more and deal or heal 2% more. | hook |

## Already done

- Every active racial is off the global cooldown (Will of the Forsaken, Cannibalize and Gift of the Naaru were not):
  `patches/52-racials.ps1` and the client patch.

## Balance notes

- First paper review (13 November): the signatures are big on purpose and fit the server's power level. The ones to
  watch once players try them: Plainsrunning (the strongest; first lever would be half the cap in combat), Ambush
  (PvP burst from Vanish or Shadowmeld), Spellsword's 30% and 10%, and Voodoo Regeneration with Troll Berserking.
- Change numbers after player feedback, not before.
