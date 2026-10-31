# Race kits: the new baseline

Each race gets four racials in the style of WoW Forever's rework: one active ability, one survival or utility
ability, one passive that changes how you play or adds a profession or world bonus, and one plain stat passive.
For the eight races WoW Forever has, its kit is the baseline, with its announced tuning of 26 and 27 October 2026
(for its 4 November launch; it may still change). Draenei and Blood Elf are not in WoW Forever, so their kits
are our own design in the same spirit. WoW Forever's Skyborne race and its priest racials are left out.

Optional and per realm (see [roadmap.md](roadmap.md), item 6): with the switch on, these replace the stock
racials; with it off, nothing changes.

**How each would be built:** *existing* = the spell is already in the client (shows properly in the
spellbook); *reworked* = an existing spell given new numbers on the server, with the WildcardEnchants addon
showing the new tooltip text; *hook* = needs a small piece of C++; *new* = a new active ability, needing the
client patch file (roadmap item 2) or a reused spell.

## Alliance

**Human**

| Racial | What it does | Built as |
| --- | --- | --- |
| Will to Survive | Removes all stun effects. | existing (Every Man for Himself) |
| Perception | Detect stealthed enemies for 20 sec. | existing (the classic Human racial) |
| Ruthless | +1% critical strike chance with all attacks and spells. | reworked passive |
| The Human Spirit | +10% Spirit. | reworked (The Human Spirit) |

**Dwarf**

| Racial | What it does | Built as |
| --- | --- | --- |
| Stoneform | Immune to bleed, poison and disease effects, and reduced physical damage taken, for 8 sec. | existing |
| Find Treasure | Track treasure chests; chests you open have a chance at better loot. | existing tracking + hook for the loot bonus |
| Artisan's Precision | +1% hit chance with attacks and spells. | reworked passive |
| Big Game Hunter | +5% damage to beasts. | reworked (Beast Slaying style) |

**Night Elf**

| Racial | What it does | Built as |
| --- | --- | --- |
| Elune's Light | +10% critical strike chance for 15 sec. | new |
| Shadowmeld | Stealth while standing still. | existing |
| Quickness | +1% dodge and +2% movement speed; stealthed Rogues and Druids are harder to detect. | existing (Quickness), reworked |
| Wisp Spirit | +75% movement speed while dead. | existing |

**Gnome**

| Racial | What it does | Built as |
| --- | --- | --- |
| Escape Artist | Escape roots and snares, briefly immune to them. | existing |
| Eureka! | For 8 sec, abilities cost 10% less and deal (or heal) 10% more. 2 min cooldown. | new |
| Engineering Specialization | Engineering devices work more reliably (fewer misfires and failures). | hook |
| Expansive Mind | +5% maximum Mana, Rage or Energy. | existing (Expansive Mind) |

**Draenei** (our design)

| Racial | What it does | Built as |
| --- | --- | --- |
| Gift of the Naaru | Heals the target for 20% of their maximum health over 15 sec. | existing |
| Naaru's Ward | For 8 sec, magic damage taken is reduced by 10%. 2 min cooldown. | new |
| Gemcutter's Eye | Jewelcrafting prospects and crafted gems have a chance to yield an extra gem. | hook |
| Heroic Presence | +1% hit chance for you and your party (unchanged). | existing |

## Horde

**Orc**

| Racial | What it does | Built as |
| --- | --- | --- |
| Blood Fury | +10% attack power and spell power for 15 sec. 2 min cooldown. | existing, reworked |
| Shatter Curse | Removes curses, then reduces magic damage taken by 5% for 8 sec. 3 min cooldown. | new |
| Command | Hunter and Warlock pets deal 5% more damage. | existing (Command) |
| Hardiness | Stun duration reduced by 20%. | existing (Hardiness), reworked |

**Undead**

| Racial | What it does | Built as |
| --- | --- | --- |
| Will of the Forsaken | Removes charm, fear and sleep. | existing |
| Cannibalize | Eat a humanoid or undead corpse to restore 7% health and mana every 2 sec for 10 sec. | existing, reworked |
| Touch of the Grave | Attacks and spells have a chance (20% melee, 30% casters) to drain up to 5% of the target's maximum health. Once every 15 sec. | hook (proc) |
| Underwater Breathing | Breathe underwater 300% longer. | existing |

**Tauren**

| Racial | What it does | Built as |
| --- | --- | --- |
| War Stomp | Stuns up to 5 enemies within 8 yards for 2 sec. 1.5 min cooldown. | existing |
| Cultivation | Extra herbs grow for you to gather, no Herbalism needed; synergy with Alchemy. Our version: a chance at a duplicate herb when gathering, plus extra herbs without the skill. | hook |
| Plainsrunning | Every 5 sec of running adds 2% movement speed, up to 60% (about 2.5 min to cap). Stopping or taking damage weakens it. Not while mounted. | hook |
| Endurance | +5% health. | existing (Endurance), reworked |

**Troll**

| Racial | What it does | Built as |
| --- | --- | --- |
| Berserking | +10% casting and attack speed for 10 sec. | existing, reworked |
| Rapid Regeneration | Regenerate 50% of maximum health over a short time. | new |
| Beast Slaying | +5% damage to beasts. | existing |
| Regeneration | +20% health regeneration, and 20% of it continues in combat. | existing (Regeneration), reworked |

**Blood Elf** (our design)

| Racial | What it does | Built as |
| --- | --- | --- |
| Arcane Torrent | Silences nearby enemies for 2 sec and restores mana, energy or runic power. | existing |
| Mana Tap | Drain an enemy's mana into a charge you can spend on Arcane Torrent for more power. | existing (the classic Blood Elf racial) |
| Arcane Affinity | Enchanting disenchants have a chance to yield extra materials; +10 Enchanting skill. | hook + existing |
| Magic Resistance | Reduces the chance to be hit by spells by 2% (unchanged). | existing |

## What it needs

- A `race -> spell` table applied at login, and removal of the stock racials while the switch is on.
- Hooks: Plainsrunning, Cultivation and the other gathering or crafting bonuses (Find Treasure, Gemcutter's Eye,
  Arcane Affinity, Engineering Specialization), and Touch of the Grave (can use the enchant action handler).
- New actives (Elune's Light, Eureka!, Naaru's Ward, Shatter Curse, Rapid Regeneration): a reused spell for now,
  a proper one once the client patch works.
- Tooltip text for reworked spells through the WildcardEnchants addon.
- Custom races from other mods are not covered; they would need kits of their own.

Sources: [Method](https://www.method.gg/wow-forever/all-new-racial-abilities-in-world-of-warcraft-forever),
[wow.gg (19 Oct)](https://wow.gg/guides/forever-racials),
[Kami Labs on the 26 Oct tuning](https://kami-labs.fr/en/wow-forever/patch-notes-26-octobre-capacites-raciales/),
[Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/racial-abilities/).
