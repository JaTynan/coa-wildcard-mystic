# Bot build: Vampire Lord, shadow healer (healer)

Status: draft, 28 Nov 2026. Healer 4 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Matches the bot module's named build **Vampire Lord** (Beacon of Shadow, Shadow Waste Bolt, Vampire Lord,
Shadow Mend, Mind Flay, Shadow Word: Pain).

Role: raid healer that heals by doing shadow damage: steady healing spread over the whole raid, plus a beacon. A
Wildcard showcase: a healer that never casts a heal in its main loop.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "Season 10 Update pt.3 - My Builds - Ascension Wildcard", Heytrix, https://www.youtube.com/watch?v=uX6FQdNew64, chapter "Shadow Healer" (13:37-16:00): Vampiric Embrace with Vampirism heals allies much more; Beacon of Shadow on an ally; apply every shadow damage-over-time and deal damage; cooldowns on pull. The author copied it from a raid log of a heroic Molten Core clear and had not mastered the rotation | Season 10, thin |
| S2 | The original 3.3.5 shadow priest rotation (James's rule, 28 Nov) | The damage rotation |
| S3 | The Season 10 Hero Archetype "Vampire Lord", as recorded in the bot module's pick table | The abilities |
| S4 | Our client spell data: Vampire Lord heals the priest and nearby allies for part of single-target shadow damage (damage over time heals for much less); Beacon of Shadow makes Shadow Bolt heal the beacon target; all abilities below exist | Mechanics |

## 2. How the build works

- **Vampire Lord** and **Vampiric Embrace** turn shadow damage into healing for the group. Single-target hits heal far
  more than damage over time does (S4), so direct shadow spells matter.
- **Beacon of Shadow** on an ally (usually the tank): Shadow Bolt also heals that ally.
- **Shadow Mend** is the direct heal for emergencies.
- The damage loop follows the classic shadow priest: keep Vampiric Touch, Shadow Word: Pain and Devouring Plague up,
  Mind Blast on cooldown, Mind Flay as filler; here Shadow Bolt and Shadow Waste Bolt also feed the beacon.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Vampire Lord, Vampiric Embrace, Beacon of Shadow, Shadow Bolt, Shadow Waste Bolt, Mind Blast, Mind Flay, Shadow Word: Pain, Shadow Mend, Shadowform | S1, S3, S4 |
| Core talents | Vampirism, shadow damage talents | S1 |
| Extras | Vampiric Touch, Devouring Plague, Shadowfiend (mana) | S2 |

Stats: spell power, hit (the healing depends on landing damage), crit, haste.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Shadowform not on me | Shadowform | S2 |
| N2 | The tank has no Beacon of Shadow | Beacon of Shadow on the tank | S1, S4 |
| H1 | A group member at critical health | Shadow Mend on them | S3, S4 |
| H2 | Vampiric Embrace not on the target | Vampiric Embrace | S1 |
| H3 | Cooldowns ready | Cooldowns (and Shadowfiend when low on mana) | S1, S2 |
| H4 | My Vampiric Touch is not on the target, if rolled | Vampiric Touch | S2 |
| H5 | My Shadow Word: Pain is not on the target | Shadow Word: Pain | S2, S3 |
| H6 | Mind Blast is ready | Mind Blast | S2 |
| H7 | Beacon of Shadow is up | Shadow Bolt (or Shadow Waste Bolt) | S4 (heals the beacon) |
| H8 | Always | Mind Flay | S2, S3 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Is the healing enough for a raid? | S1 saw about 3,000 healing per second in a raid log; enough as one of six healers, not alone |
