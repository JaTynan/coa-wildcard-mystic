# Bot build: Soul Fire (caster)

Status: draft, 28 Nov 2026. Caster 2 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live.

Role: ranged damage, single target. A fire warlock that spams Soul Fire at close to 100% crit. Spirit stacker, like
the Plague Caster.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "Soul Fire - Destro Lock - Build Showcase - Ascension s10 wildcard", Heytrix, Season 10, https://www.youtube.com/watch?v=PckP_aWOsO4 (transcript read 28 Nov). The author calls it work in progress, not a finished guide. | Primary |
| S2 | Same author, "Season 10 Update pt.3" (https://www.youtube.com/watch?v=uX6FQdNew64, 20:36): the mana problem and its fix after a patch | Supporting |
| S3 | Our client spell data: every ability named below exists | Mechanics |

## 2. How the build works

- **Soul Fire** is the main spell; the build stacks crit until almost every Soul Fire crits.
- **Destructive Bargain** (talent): destruction spells give damage and haste but raise spell costs with each cast. Mana
  is the build's problem (S1, S2).
- **Elemental Focus / Elemental Fury**: crits give clearcasting, cutting spell cost; S1 calls them mandatory for mana.
- **Backdraft**: 30% haste after Shadowburn, Mind Blast or Twilight Shock; S1 says mandatory. When it runs out, cast
  one of those again.
- **Gul'dan's Chosen**: a random proc from Soul Fire; for 10 seconds Backdraft and Molten Core are not used up. A burst
  window.
- **Spirit Tap / Improved Spirit Tap**: crits from Mind Blast or Beam of Hatred give spirit, crit and mana. Fel Armor
  and Molten Armor turn spirit into spell power and crit.
- **Corruption and Living Bomb** are kept up but are a small share of damage; Big Flaming Grimfire extends Living Bomb.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Soul Fire, Mind Blast, Twilight Shock or Shadowburn, Corruption, Fel Armor, Molten Armor, Summon Imp, Life Tap | S1 |
| Core talents | Destructive Bargain, Backdraft, Gul'dan's Chosen, Elemental Focus, Elemental Fury, Spirit Tap and Improved Spirit Tap, Shadow and Flame, Improved Molten Armor | S1 |
| Cooldowns | Metamorphosis or Voidborne, Extraction | S1 |
| Rolled extras | Living Bomb with Big Flaming Grimfire, Beam of Hatred, Decimation (execute), Ignite, Righteous Vengeance, Eradication, Flametongue Weapon | S1 |

Stats: spirit, then hit (S1 uses enchants for it), crit, spell penetration for raids. Race: human for spirit (S1).

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Fel Armor or Molten Armor is not on me | Cast it | S1 |
| N2 | My imp is not out | Summon Imp | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | Low mana **and** health is fine | Life Tap | S1 carded it; threshold **guess** |
| C2 | Gul'dan's Chosen is on me **and** cooldowns are ready | Cooldowns, then Soul Fire | S1 (burst window) |
| C3 | Backdraft is not on me **and** Mind Blast is ready | Mind Blast | S1 |
| C4 | Backdraft is not on me | Twilight Shock or Shadowburn | S1 |
| C5 | My Corruption is not on the target | Corruption | S1 |
| C6 | My Living Bomb is not on the target, if rolled | Living Bomb | S1 |
| C7 | Spirit Tap is not on me **and** Beam of Hatred rolled | Beam of Hatred (full channel) | S1 (also meant to raise the next Soul Fire; S1 could not confirm it works) |
| C8 | Always | Soul Fire | S1 ("just spam Soul Fire") |

The opener falls out of the list: precast Soul Fire (C8), then Mind Blast for Backdraft and Spirit Tap (C3), the DoTs,
then Soul Fire.

## 5. Open points

| Point | How to settle it |
|---|---|
| Is mana sustainable for a bot over a long fight? | A dummy test once bots can run it; S2 says the patch made it workable |
| Beam of Hatred buff to Soul Fire | In game |
