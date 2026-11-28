# Bot build: Shadow Melee (melee)

Status: draft, 28 Nov 2026. Melee 3 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. The bot module's nearest named builds are **Master of Shadows** and **Fel Infused Blade**.

Role: melee damage, single target (raids). Weak on groups unless Fan of Knives is rolled (S1).

**Source warning.** Season 9 guide (January 2024). Its author calls it an endgame build that needs many legendary
talents: hard for a player to roll, but for a prepared bot the build is simply written down.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "The Shadow Melee - Build Guide - Ascension Season 9", Heytrix, 26 Jan 2024, https://www.youtube.com/watch?v=P0BW9gdgf0A (transcript and description read 28 Nov) | Primary, one season old |
| S2 | Our client spell data: every ability below exists | Mechanics |

## 2. How the build works

- **Corrupted Maelstrom Weapon**: each melee ability adds a stack; at three stacks Chaos Bolt is instant. **Felstorm**
  cuts Chaos Bolt's cooldown so it is ready every time.
- **Pure Chaos Bolt** counts as every school at once: it gains from shadow, fire and crit bonuses alike (even Ignite).
- **Sinister Strike** is the builder. **Double Down** makes it hit with both weapons (twice the Fel Infused Weapon and
  Dark Intent procs) but stops it giving combo points.
- **Master of Shadows**: a stacking buff; at three stacks, Eviscerate or Rupture triggers a large shadow empowerment.
- Combo points therefore come from **Gloomblade** (every few seconds), Honor Among Thieves or Seal Fate.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Sinister Strike, Pure Chaos Bolt, Eviscerate, Gloomblade, Fel Infused Weapon, Twisted Mind or Shadowform | S1 |
| Core talents | Corrupted Maelstrom Weapon, Felstorm, Double Down, Master of Shadows, Dark Intent, Mental Quickness | S1 |
| Rolled extras | Molten Core, Ignite, Shadow and Flame, Aggression, Arcane Power, Fan of Knives (groups); raid duty: Curse of Weakness (`raid-coverage.md`) | S1, assignment |

Gear: agility and intellect hybrid, or plain spell power; daggers for Gloomblade.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Twisted Mind (or Shadowform) not on me | Cast it | S1 |
| N2 | Fel Infused Weapon not on my weapon | Cast it | S1 |
| C1 | Three Corrupted Maelstrom stacks | Pure Chaos Bolt | S1 |
| C2 | Master of Shadows at three stacks **and** combo points | Eviscerate | S1 |
| C3 | Gloomblade is ready | Gloomblade | S1 (combo points) |
| C4 | Three or more enemies **and** Fan of Knives rolled | Fan of Knives | S1 |
| C5 | Always | Sinister Strike | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Combo points without Seal Fate or Honor Among Thieves | Gloomblade alone may be too slow; the roster can give the bot Seal Fate as its rolled talent |
