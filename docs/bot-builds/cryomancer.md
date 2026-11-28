# Bot build: Cryomancer, frost mage (caster)

Status: draft, 28 Nov 2026. Caster 7 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Matches the bot module's named build **Cryomancer** (Frostbolt, Frost Bomb, Ice Lance, Water Elemental, Deep
Freeze).

Role: ranged damage, with control (freezes) and good area damage.

**Source note.** No good Season 9 or 10 frost guide was found. Following James's rule (28 Nov), the core is the original
3.3.5 frost mage rotation, which the bot module's Cryomancer picks already match. A Season 9 play session (S3) adds the
custom frost spells as optional extras.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 frost mage rotation | The rotation |
| S2 | The bot module's pick table, build "Cryomancer" (`CoaWildcardPicks.cpp`) | The core abilities |
| S3 | Video "This Pure FROST Caster Build is So FUN in Project Ascension WoW", Venario, 18 Jan 2025, https://www.youtube.com/watch?v=znCv2RzKKgk (a play session, Season 9, possibly free-pick) | Optional extras only |
| S4 | Our client spell data: Fingers of Frost, Brain Freeze (makes the next Fireball or Frostfire Bolt instant and free), Ice Lance (triple damage on frozen targets), Deep Freeze, Frost Bomb, Water Elemental, Icy Veins all exist | Mechanics |

## 2. How the build works

- **Frostbolt** is the filler. Its direct frost damage can trigger:
  - **Fingers of Frost**: the target counts as frozen for the next spells, so **Ice Lance** does triple damage and
    **Deep Freeze** can be used.
  - **Brain Freeze**: the next **Fireball** or **Frostfire Bolt** is instant and free.
- **Water Elemental** and **Icy Veins** are the pet and the cooldown.
- **Frost Bomb** (from the bot picks) is a delayed burst on the target.
- Optional, from S3: **Glacial Burst** (needs Frostflame Shock on the target to crit), **Frozen Orb** and **Frostfall**
  for groups, **Cone of Cold** right after Deep Freeze.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Frostbolt, Ice Lance, Deep Freeze, Frost Bomb, Water Elemental, Icy Veins, Fireball or Frostfire Bolt | S1, S2 |
| Core talents | Fingers of Frost, Brain Freeze, frost damage and crit talents | S1 |
| Rolled extras | Frozen Orb, Frostfall, Cone of Cold, Glacial Burst with Frostflame Shock, Winter's Chill, Divine Spirit (raid duty, `raid-coverage.md`) | S3, assignment |

Stats: hit to the cap (S3 was missing it), spell power, crit. Mana: S3 ran dry in long fights, so a mana source among
the rolled extras helps (Evocation, Spirit Tap or similar).

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Water Elemental not out | Summon Water Elemental | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | Icy Veins is ready | Icy Veins | S1 |
| C2 | Fingers of Frost is on me **and** Deep Freeze is ready | Deep Freeze | S1 |
| C3 | Brain Freeze is on me | Frostfire Bolt (or Fireball) | S1 |
| C4 | Fingers of Frost is on me | Ice Lance | S1 |
| C5 | My Frost Bomb is not on the target **and** it is ready | Frost Bomb | S2; placement in the order **guess** |
| C6 | Three or more enemies **and** Frozen Orb is ready, if rolled | Frozen Orb | S3 |
| C7 | Three or more enemies close **and** Cone of Cold is ready, if rolled | Cone of Cold | S3 |
| C8 | Moving | Ice Lance | S1 |
| C9 | Always | Frostbolt | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Does Fingers of Frost show as a buff the bot can see? | Our spell data: its proc aura (74396 is named in the talent) |
