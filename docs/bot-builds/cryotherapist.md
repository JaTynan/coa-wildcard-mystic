# Bot build: Cryotherapist, frost healer (healer)

Status: draft, 28 Nov 2026. Healer 5 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Matches the bot module's named build **Cryotherapist**.

Role: healer that turns frost damage into healing for allies. A Wildcard showcase: a frost mage that heals.

**Source note: built from game data.** No guide exists. A Season 10 creator streamed an attempt to make it work ("there
is no guide for this one"); those streams are hours long and were not read. The build comes from the Season 10 Hero
Archetype and our client spell data; the order is mostly **guess**.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The Season 10 Hero Archetype "Cryotherapist", as recorded in the bot module's pick table: Frostbolt, Greater Heal, Icy Penance, Prayer of Healing, Cryotherapist, Ice Lance, Frostfire Bolt | The abilities |
| S2 | Our client spell data: Cryotherapist uses "Frozen Light" to turn frost damage into healing for allies; Icy Penance fires frozen light at an enemy every second (holyfrost damage); all abilities exist | Mechanics |
| S3 | Hello Heroes Guild, "The Impossible Healer - Cryomancer Build Goes Live", Season 10 stream, 9 Aug 2026, https://www.youtube.com/watch?v=lRY1ndaHeY0 (description only) | Shows players attempted it in Season 10 |

## 2. How the build works (from S2)

- **Cryotherapist**: frost damage dealt becomes healing for allies.
- **Icy Penance**: a channelled volley at an enemy, damage every second, so steady healing.
- **Frostbolt**, **Ice Lance** and **Frostfire Bolt** are the damage, and through Cryotherapist the healing.
- **Greater Heal** and **Prayer of Healing** are the direct heals for a single target and a group.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Cryotherapist, Icy Penance, Frostbolt, Ice Lance, Frostfire Bolt, Greater Heal, Prayer of Healing | S1 |
| Rolled extras | Fingers of Frost and Brain Freeze (from the frost mage, to make Ice Lance and Frostfire Bolt stronger), mana talents | **guess** |

## 4. The decision list (order is a **guess**)

| # | When | Do | Source |
|---|---|---|---|
| H1 | Several group members at low health | Prayer of Healing | S1 |
| H2 | A group member at critical health | Greater Heal on them | S1 |
| H3 | Icy Penance is ready **and** an enemy in range | Icy Penance | S1, S2 |
| H4 | Brain Freeze is on me, if rolled | Frostfire Bolt | S1 |
| H5 | Fingers of Frost is on me, if rolled | Ice Lance | S1 |
| H6 | Always (with an enemy in range) | Frostbolt | S1, S2 |

## 5. Open points

| Point | How to settle it |
|---|---|
| How the healing is aimed (lowest ally, group, tank?) | Our spell data: the Frozen Light auras the Cryotherapist talent names |
| Is it strong enough for raids? | Test once bots can run it; treat it as a dungeon healer until then |
