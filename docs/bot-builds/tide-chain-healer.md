# Bot build: Tide Chain Healer, Living Lightning (healer)

Status: draft, 28 Nov 2026. Healer 2 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Matches the bot module's named builds **Tree of Wrath** and **Tide Mender**.

Role: raid healer. A shaman-style chain healer in a druid tree form that can also throw lightning: Riptide on many
people, big chain heals, and lightning bolts that speed up its heals.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "Season 10 Update pt.3 - My Builds - Ascension Wildcard", Heytrix, https://www.youtube.com/watch?v=uX6FQdNew64, chapter "Living Lightning healer" (8:55-11:44) | Season 10 version, short |
| S2 | Video "The Godly Nature Healer - Build Guide - Ascension Season 9", Heytrix, 14 Feb 2024, https://www.youtube.com/watch?v=gsvj9_4K7FA (transcript and card list read 28 Nov) | The full guide, one season old |
| S3 | Video "Did i get the perfect Chain Heal build? pt.2 - Ascension Season 9", Heytrix, 24 Dec 2023, https://www.youtube.com/watch?v=mBiCl_OxYCQ (card list in the description) | Cross-check |
| S4 | Our client spell data: all abilities below exist ("Mending Tides" in the videos is "Mending Tide"); "Transcendent Embrace" was not found under that name | Mechanics |

## 2. How the build works

- **Tree of Wrath**: an improved Tree of Life that can cast Lightning Bolt and Chain Lightning (they cannot miss in the
  form), with bonuses on critical heals.
- **Riptide** is the core heal (S2): the guide's key talents all improve it, and Oracle of the Eclipse keeps it rolling.
- **Lightning Rod** with **Charged Tides**: nature heal crits mark a lightning target; a Lightning Bolt on it cuts the
  cast time of Healing Wave and Chain Heal (S2). So the healer keeps a Lightning Bolt on an enemy.
- **Living Lightning** (S1): a chain heal that also splits into a Chain Lightning. With **Overflowing** at full stacks
  (built by heals such as Healing Touch), the next one jumps further and does not weaken per jump. S1's loop: Healing
  Wave, Healing Touch, Healing Touch, then the empowered Living Lightning.
- **Overflow**: cast-time nature heals also heal one more nearby ally.
- Extras from S2: **Regrowth** with Blooming Growth, **Wild Growth**, **Downpour** for burst group healing.
- Mana (S2): Mage Armor, mana-per-five talents, Water Shield.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Tree of Wrath, Riptide, Chain Heal or Living Lightning, Healing Wave, Lightning Bolt, Life Tap, Mage Armor | S1, S2, S3 |
| Core talents | Low Tide, Mastery of the Tide, Charged Tides, Lightning Rod, Overflow (and Overflowing), Mending Tide | S1, S2, S3 |
| Extras | Healing Touch, Regrowth, Wild Growth, Downpour, Tidal Waves, Ancestral Awakening, Water Shield, Earth Shield, Glyph of Chain Heal | S2, S3 |

Stats: crit (Lightning Rod procs; S2 says about 50% crit caps Regrowth), spirit, healing power, mana per five.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Tree of Wrath | Tree of Wrath | S2 |
| N2 | Mage Armor (or Water Shield) missing | Cast it | S2 |
| H1 | Several group members are hurt **and** Downpour is ready, if rolled | Downpour | S2 |
| H2 | Overflowing at full stacks **and** several hurt | Living Lightning (or Chain Heal) | S1 |
| H3 | A group member at critical health | Healing Wave on them | S1, S2 |
| H4 | A group member in combat lacks my Riptide **and** Riptide is ready | Riptide on them | S2 |
| H5 | Lightning Rod's target is marked **and** an enemy is in range | Lightning Bolt on it | S2 |
| H6 | Several group members are hurt | Chain Heal | S2, S3 |
| H7 | A group member is hurt **and** Healing Touch rolled | Healing Touch (builds Overflowing) | S1 |
| H8 | A group member is hurt | Healing Wave | S1, S2 |
| H9 | Nobody hurt **and** an enemy in range | Lightning Bolt | S2 (keeps Lightning Rod procs coming) |

## 5. Open points

| Point | How to settle it |
|---|---|
| Healing condition "lacks my Riptide" | Same per-member heal-over-time condition as Holy Radiance's Renew |
