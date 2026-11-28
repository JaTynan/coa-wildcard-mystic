# Bot build: Elemental Lord (caster)

Status: draft, 28 Nov 2026. Caster 5 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. The bot module's nearest named build is **Stormcaller**.

Role: ranged damage with burst: a very large Earth Shock for adds that must die at once (S1's main selling point).
Reactive and random by design.

**Source warning.** Season 9 guide (February 2024). In Season 10 the same author still praises Booming Thunder
("Season 10 Update pt.3", changelog section), one of this build's pieces.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "The Elemental Lord - Build Guide - Ascension Season 9", Heytrix, 20 Feb 2024, https://www.youtube.com/watch?v=iVDcVcSxuWs (transcript read 28 Nov) | Primary, one season old |
| S2 | Cross-check available, not yet read: "Blasting Ascension with Elemental Lord & Booming Thunder", Nordic Boomerchef Gaming, Season 9, https://www.youtube.com/watch?v=kyWo15mCBP4 | - |
| S3 | Our client spell data. All abilities below exist except "Power of the Elemental" (S1's 5% crit and hit pet talent), not found under that name | Mechanics |

## 2. How the build works

- **Elemental Blast** (fire, frost and nature at once) is cast constantly. **Elemental Domination** removes its cooldown:
  without it the build does not work (S1).
- **Elemental Lord**: each Elemental Blast empowers one of the three shocks at random.
  - Empowered **Frost Shock**: next Lava Burst +50%, and mana for the caster and pet.
  - Empowered **Flame Shock**: resets Lava Burst, and crit for the pet.
  - Empowered **Earth Shock**: a big hit.
- **Booming Thunder**: stacks from Elemental Blast (four per cast, S1) and Reverberation; spent by a huge Earth Shock.
- **Reverberation**: damaging with one shock buffs the next different shock or Elemental Blast, and cuts cooldowns.
- Because Elemental Blast is also fire and frost, **Ignite** and **Winter's Chill** work with it (S1).
- A **Fire Elemental** pet runs throughout; Frost Shock keeps its mana up.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Elemental Blast, Earth Shock, Lava Burst, Flame Shock, Frost Shock, Fire Elemental | S1 |
| Core talents | Elemental Domination, Elemental Lord, Booming Thunder (or Primordial Aftershocks), Ignite, Reverberation | S1 |
| Rolled extras | Legacy of the Arcanist, Tethered Power, Spellslinger, Elemental Focus, Lunar Guidance, Winter's Chill, Arcane Power or Elemental Mastery or Power Infusion | S1 |

Stats: intellect, crit (reaching the crit cap makes a big jump, S1), spell power.

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | My Fire Elemental is not out | Summon it | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | Earth Shock is empowered **or** Booming Thunder is at full stacks | Earth Shock | S1 |
| C2 | Frost Shock is empowered | Frost Shock | S1 (sets up a +50% Lava Burst) |
| C3 | Flame Shock is empowered | Flame Shock | S1 (resets Lava Burst) |
| C4 | Lava Burst is ready **and** Frost Shock's buff is on me | Lava Burst | S1 |
| C5 | Lava Burst is ready | Lava Burst | S1 |
| C6 | Always | Elemental Blast | S1 |

Full Booming Thunder stacks (C1) are worth saving for an add that must die, but bots cannot tell which add matters;
spending at full stacks is the **guess**.

## 5. Open points

| Point | How to settle it |
|---|---|
| The names of the "empowered" buffs, for the conditions | Our spell data: find the three Elemental Lord buff auras |
| Full Booming Thunder stack count | Our spell data |
| Cross-check | Read S2 |
