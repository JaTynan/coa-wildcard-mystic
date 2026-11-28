# Bot build: Winds of Winter (melee)

Status: draft, 28 Nov 2026. Melee 1 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live.

Role: melee damage, best on groups of enemies: its source says most players used it for Mythic+ in Season 10.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "Season 10 Update pt.3 - My Builds - Ascension Wildcard", Heytrix, Season 10, https://www.youtube.com/watch?v=uX6FQdNew64, chapter "Winds of Winter" (6:12-8:55; transcript read 28 Nov). A short segment, not a full guide. | Primary, thin |
| S2 | Our client spell data: Winds of Winter, Titanic Mutilate, Lava Lash, Lava Sweep, Killing Machine, Flametongue and Frostbrand Weapon all exist | Mechanics |

## 2. How the build works

- **Winds of Winter** is a combo-point finisher that works like Cone of Cold: a frost cone in front of the caster.
- **Titanic Mutilate** builds the combo points (two casts in S1's loop).
- **Killing Machine**: melee hits make the next frost spell crit, so Winds of Winter lands as a big crit.
- **Lava Lash** raises the damage of the cone; **Lava Sweep** is cast between rounds.
- **Flametongue Weapon, not Frostbrand**: Frostbrand's frost hits would use up Killing Machine (S1).

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Winds of Winter, Titanic Mutilate, Lava Lash, Lava Sweep, Flametongue Weapon | S1 |
| Core talents | Killing Machine | S1 |
| Rolled extras | Exposed Weakness, Concussion, Earth and Moon (S1 was rolling for these); Master Poisoner (raid duty, `raid-coverage.md`) | S1, assignment |

Stats: S1 runs a spirit-stacking version but recommends plain spell power and intellect for most players.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Flametongue Weapon not on my weapon (out of combat) | Flametongue Weapon | S1 |
| C1 | Cooldowns ready **and** enemies in front of me | Cooldowns | S1 |
| C2 | Lava Lash's buff is not on me **and** Lava Lash is ready | Lava Lash | S1 |
| C3 | Five combo points **and** Killing Machine is on me | Winds of Winter | S1 |
| C4 | Five combo points | Winds of Winter | S1 |
| C5 | Lava Sweep is ready | Lava Sweep | S1 ("in between") |
| C6 | Always | Titanic Mutilate | S1 |

The bot must face the group for the cone. The bot module's melee positioning ("behind" for melee damage) would put it
behind one target: **check** that cone builds face the pack.

## 5. Open points

| Point | How to settle it |
|---|---|
| A fuller source | A full Season 10 Winds of Winter guide if one turns up |
| Facing for cone finishers | The bot module's positioning code |
