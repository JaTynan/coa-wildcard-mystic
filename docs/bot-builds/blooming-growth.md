# Bot build: Blooming Growth, Regrowth druid healer (healer)

Status: draft, 28 Nov 2026. Proposed new build 4 of 10 (`faction-rosters.md`): Horde, home race Tauren (Plainsrunning
and Endurance help a healer who moves a lot). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: raid healer built on critical Regrowths that spread heals over time to nearby allies. A Horde counterpart to
Seed of Life (`seed-of-life.md`), which the Alliance keeps.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Old Discord guide list (2021, passed on by James 28 Nov): "Blooming Growth - Regrowth healer" in the druid section; the post was not pasted | Intent only |
| S2 | The original 3.3.5 restoration druid rotation (James's rule, 28 Nov) | The rotation |
| S3 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Blooming Growth | Wildcard talent | Working (audit) | A critical Regrowth copies its heal over time onto three more nearby allies, a little weaker | No build: plain Regrowth |
| Seed of Life | Wildcard talent | Working (audit) | Regrowth and Rejuvenation plant a seed on the ally (the Alliance build's namesake) | Less healing |
| Nature's Grace | Stock talent | Stock | Crits give a short haste burst | Slower casts |
| Restoration Mastery (druid version) | Enchant only | Working (audit) | Stronger heals over time, cheaper Regrowth, Healing Touch and Nourish | Optional; needs bot enchants |

Critical strike is the build's fuel: every Regrowth crit spreads healing.

## 3. How the build works

- Regrowth is the main heal: cast it on hurt allies in groups so its crits spread.
- Rejuvenation and Lifebloom on the tank; Wild Growth and Swiftmend on cooldown as in Seed of Life.
- Tree of Life form for the group.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Regrowth, Rejuvenation, Lifebloom, Wild Growth, Swiftmend, Nourish, Tree of Life | S2 |
| Talents | Blooming Growth, Seed of Life, Nature's Grace, Natural Perfection, Living Seed | S1, S2, S3 |
| Enchants (if bots can slot them) | Restoration Mastery | S3 |

Stats: spell power, critical strike (more than usual), haste, spirit.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Tree of Life | Tree of Life | S2 |
| H1 | A group member at critical health **and** Swiftmend is ready **and** they have my Rejuvenation or Regrowth | Swiftmend | S2 |
| H2 | Several group members hurt **and** Wild Growth is ready | Wild Growth | S2 |
| H3 | Several group members hurt, close together | Regrowth on the most hurt of them | S1, S3 |
| H4 | The tank lacks my Lifebloom or it is about to run out | Lifebloom on the tank | S2 |
| H5 | A group member at low health **and** lacks my Regrowth | Regrowth on them | S1 |
| H6 | A group member hurt **and** lacks my Rejuvenation | Rejuvenation on them | S2 |
| H7 | A group member hurt **and** has my heals over time | Nourish | S2 |
| H8 | Low mana **and** Innervate is ready | Innervate on myself | S2 |

## 6. Open points

| Point | How to settle it |
|---|---|
| "Close together" for H3 | Needs a "hurt allies near this ally" count; `to check` (the party-member triggers count hurt members, not distance) |
| A Season 9 or 10 source | James's Discord post for Blooming Growth |
