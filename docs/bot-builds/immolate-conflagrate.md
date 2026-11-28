# Bot build: Immolate and Conflagrate (caster)

Status: draft, 28 Nov 2026. Caster 3 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live.

Role: ranged damage, single target. A fire warlock that keeps one Immolate burning all fight and spends it with
Conflagrate without using it up.

**Source warning.** Season 9 guide (January 2024). No Season 10 version was found; the same author tried a variant in
Season 10 and dropped it (Heytrix, "Season 10 Update pt.3", 19:29).

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "Immolate & Conflagrate Build Guide - Ascension Season 9", Heytrix, 16 Jan 2024, https://www.youtube.com/watch?v=h8UDop_NuAA (transcript read 28 Nov) | Primary, one season old |
| S2 | Our client spell data. All abilities below exist except "Hasty Conflagrate" (S1's name for the cooldown-reduction enchant), which was not found under that name | Mechanics |

## 2. How the build works

- **Immolate** once, at the start. **Controlled Burn**: Chaos Bolt refreshes it, so it never needs recasting.
- **Conflagrate** on cooldown (10 seconds). **Infinite Burn**: it no longer consumes Immolate (our data has the same
  effect as the Glyph of Conflagrate).
- **Elemental Destruction** and **Midnight Flames** (legendaries) multiply Immolate's damage: the first needs Flame Shock
  on the target, the second is fed by Fireball and Fire Blast between Conflagrates.
- **Snapshot**: S1 casts the single Immolate with every percentage buff up (cooldown, Pyroclasm from Scorch, an
  arcane-raises-fire talent from Arcane Missiles, a one-hand weapon then a staff swap). **Left out for bots**: too fiddly
  and the gain is a few percent each. The bot casts Immolate under its main cooldown only.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Immolate, Conflagrate, Chaos Bolt, Fireball, Fire Blast, Scorch, Flame Shock, Summon Imp, Life Tap | S1 |
| Core talents | Infinite Burn, Controlled Burn, Improved Immolate, Molten Core, Ignite, Fire and Brimstone, Fire Power, Ruin | S1 |
| Legendaries | Elemental Destruction, Midnight Flames | S1 |
| Cooldown | Arcane Power or Soul Harvest (or Metamorphosis) | S1 |
| Rolled extras | Elemental Immolate (combo-point version, can run alongside), Pyroclasm, Booming Echoes | S1 |

Stats: spell power, crit, haste (more haste fits more fillers between Conflagrates).

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | My imp is not out | Summon Imp | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | My Immolate is not on the target **and** my cooldown is ready | Cooldown, then Immolate | S1 (simplified snapshot) |
| C2 | My Immolate is not on the target | Immolate | S1 |
| C3 | Chaos Bolt is ready | Chaos Bolt | S1 (keeps Immolate alive) |
| C4 | Conflagrate is ready | Conflagrate | S1 |
| C5 | My Flame Shock is not on the target, if Elemental Destruction rolled | Flame Shock | S1 |
| C6 | Low mana **and** health is fine | Life Tap | S1 carded it; threshold **guess** |
| C7 | Fire Blast is ready | Fire Blast | S1 (Midnight Flames filler) |
| C8 | Always | Fireball | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Does Chaos Bolt still refresh Immolate on our realm? | In game |
| Two fire warlocks (this and Soul Fire) in one raid | Fine for damage; give them different rolled extras so they cover different raid buffs |
