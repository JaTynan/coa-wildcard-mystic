# Bot build: Seed of Life, druid heal-over-time healer (healer)

Status: draft, 28 Nov 2026. Healer 6 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Matches the bot module's named build **Naturalist** (Rejuvenation, Regrowth, Lesser Healing Wave, Wild Growth).

Role: raid healer built on heals over time; strong on the tanks (Lifebloom) and the raid (Wild Growth). Carries Tree of
Life, which raises healing received for its group.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Old Discord guide list (2021, passed on by James 28 Nov): "Seed of Life - HoT healer" and "Blooming Growth - Regrowth healer" in the druid section; the posts were not pasted | Intent only |
| S2 | The original 3.3.5 restoration druid rotation (James's rule, 28 Nov) | The rotation |
| S3 | The bot module's pick table, build "Naturalist" | The abilities |
| S4 | Our client spell data: Rejuvenation, Regrowth, Lifebloom, Wild Growth, Swiftmend, Nourish, Tree of Life, Blooming Growth all exist | Mechanics |

## 2. How the build works (classic)

- **Lifebloom** stacked on the tank(s) and kept rolling; **Rejuvenation** on anyone taking damage.
- **Wild Growth** on cooldown when several are hurt.
- **Swiftmend** for an instant big heal (consumes a Rejuvenation or Regrowth).
- **Regrowth** for a direct heal plus a heal over time (with Blooming Growth, S1's second druid build, it gains extra
  healing); **Nourish** heals more on targets with heals over time.
- **Tree of Life** form raises healing received by the group and cheapens heals over time.
- **Lesser Healing Wave** (from the bot picks) as a fast direct heal.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Rejuvenation, Lifebloom, Wild Growth, Regrowth, Swiftmend, Nourish, Tree of Life, Lesser Healing Wave | S2, S3 |
| Talents | Blooming Growth, heal-over-time and spirit talents | S1, S2 |
| Utility | Innervate, Remove Curse, Abolish Poison | S2 |

Stats: spell power, spirit, haste.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Tree of Life | Tree of Life | S2 |
| H1 | A group member at critical health **and** Swiftmend is ready **and** they have my Rejuvenation or Regrowth | Swiftmend | S2 |
| H2 | Several group members hurt **and** Wild Growth is ready | Wild Growth | S2 |
| H3 | The tank has fewer than three Lifeblooms from me, or they are about to run out | Lifebloom on the tank | S2 |
| H4 | A group member at low health | Regrowth on them | S1, S2 |
| H5 | A group member hurt **and** lacks my Rejuvenation | Rejuvenation on them | S2 |
| H6 | A group member hurt **and** has my heals over time | Nourish | S2 |
| H7 | A group member hurt | Lesser Healing Wave | S3 |
| H8 | Low mana **and** Innervate is ready | Innervate on myself | S2 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Lifebloom stack count as a condition | "aura stacks" exists for the bot's own buffs; on a target it is **to check** |
| A Season 9 or 10 source | James's Discord posts for Seed of Life or Blooming Growth would help |
