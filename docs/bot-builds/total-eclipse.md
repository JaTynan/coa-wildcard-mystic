# Bot build: Total Eclipse, balance druid (caster)

Status: draft, 28 Nov 2026. Caster 8 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Replaces the earlier "Moonkin Fire" draft, whose source was too weak. The bot module's nearest named build is
**Druid of the Eclipse**.

Role: ranged damage plus raid support: Moonkin Form (spell crit aura), Improved Faerie Fire (spell hit and crit on the
target), Earth and Moon (spell damage taken).

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Old Discord guide "Total Eclipse - Balance Druid" (2021), passed on by James 28 Nov: rotate Wrath and Starfire by the active Eclipse, as in the original 3.3.5 game | Primary for intent |
| S2 | The original 3.3.5 balance druid rotation (James, 28 Nov: where guides say nothing more, follow the classic rotation) | The rotation |
| S3 | Our client spell data: Eclipse works as in 3.3.5 (arcane damage can raise Wrath's damage; nature damage can raise Starfire's crit), with Starsurge added to both; all abilities below exist | Mechanics |

## 2. How the build works

- **Eclipse**: Starfire (arcane) can trigger **Solar Eclipse**, which raises Wrath's damage. Wrath (nature) can trigger
  **Lunar Eclipse**, which raises Starfire's crit chance. Each lasts 15 seconds.
- So: cast **Wrath** until Lunar Eclipse comes up, then **Starfire** while it lasts; cast **Starfire** until Solar
  Eclipse comes up, then **Wrath** while it lasts. In practice the bot keeps casting the spell that matches the last
  Eclipse it had.
- Keep **Insect Swarm** and **Moonfire** on the target, and **Faerie Fire** (with Improved Faerie Fire) for the raid.
- **Starfall** and **Force of Nature** are the cooldowns; Starfall is also the area spell.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Wrath, Starfire, Moonfire, Insect Swarm, Faerie Fire, Moonkin Form, Starfall | S1, S2 |
| Core talents | Eclipse, Improved Faerie Fire, Earth and Moon, Moonkin Form's talent, spell crit talents | S2 |
| Cooldowns | Force of Nature, Innervate (own mana) | S2 |
| Rolled extras (raid duty) | Wrath of Air Totem, Mana Spring Totem, Blessing of Kings: carried here so the raid has them (`raid-coverage.md`) | Assignment |

Stats: hit to the cap, spell power, crit (Eclipse procs from crits), haste.

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Moonkin Form | Moonkin Form | S2 |
| N2 | A group member lacks Blessing of Kings, if rolled | Blessing of Kings | Assignment |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | Not in Moonkin Form | Moonkin Form | S2 |
| C2 | My totems are not down near the group, if rolled | Wrath of Air Totem, Mana Spring Totem | Assignment |
| C3 | Faerie Fire is not on the target | Faerie Fire | S2 |
| C4 | Three or more enemies **and** Starfall is ready | Starfall | S2 |
| C5 | Force of Nature is ready | Force of Nature | S2 |
| C6 | Low mana **and** Innervate is ready | Innervate on myself | S2 |
| C7 | Lunar Eclipse is on me | Starfire | S1, S2 |
| C8 | Solar Eclipse is on me | Wrath | S1, S2 |
| C9 | My Insect Swarm is not on the target | Insect Swarm | S2 |
| C10 | My Moonfire is not on the target | Moonfire | S2 |
| C11 | My last Eclipse was Solar (or none yet) | Wrath | S2 (build toward Lunar) |
| C12 | Always | Starfire | S2 (build toward Solar) |

C11 needs a condition the bot module does not have: "which Eclipse did I have last". A simpler stand-in, a **guess**:
Wrath when Solar's cooldown is running, otherwise Starfire.

## 5. Open points

| Point | How to settle it |
|---|---|
| "Last Eclipse" memory for C11 | A small C++ condition with the `all::`/`any::`/`not::` change, or the stand-in |
| Starsurge (added to both Eclipses in our data) | If rolled, cast it whenever ready during either Eclipse: **guess** |
