# Bot build: Pyroblast Fire Mage (caster)

Status: draft, 28 Nov 2026. Caster 4 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live.

Role: ranged damage. Lower single-target damage than the warlocks, but it can cast everything while moving. Its guide
recommends it for movement-heavy fights.

**Source warning.** Season 9 Wildcard guide (February 2024). No Season 10 version was found.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "The Pyroblast Fire Mage - Build Guide - Ascension Wildcard Season 9", Heytrix, 29 Feb 2024, https://www.youtube.com/watch?v=Y1teRiXjimM (transcript and description read 28 Nov) | Primary, one season old |
| S2 | Our client spell data: every ability below exists | Mechanics |

## 2. How the build works

- **Hot Streak**: two fire crits in a row make the next Pyroblast instant. **Hot Hands** (legendary): a Pyroblast crit
  can trigger Hot Streak itself, so near 100% crit gives an endless chain of instant Pyroblasts.
- **Scorched Earth**: Scorch can be cast while moving. Scorch is the way to start the chain (two Scorch crits).
- **Ignite** and **Empowered Fire**: S1 always takes both; they scale Pyroblast and help mana.
- Everything else is crit: Molten Armor, Demonic Mind (a crit stance), Firestone, crit talents, Totem of Wrath.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Pyroblast, Scorched Earth (Scorch), Molten Armor, Demonic Mind, Create Firestone, Arcane Intellect | S1 |
| Core talents | Hot Streak, Hot Hands, Ignite, Empowered Fire, two crit talents | S1 |
| Rolled extras | Improved Scorch, Critical Mass, Master Conjuror, Combustion with Playing with Fire, Destructive Reach, Elemental Focus (mana), a blink | S1 |

S1's Metamorphosis package (permanent Metamorphosis) is "for fun"; S1 recommends crit instead. Bots take crit.

Stats: crit to the cap (S1: about 103% on Pyroblast), then intellect.

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Molten Armor is not on me | Molten Armor | S1 |
| N2 | Demonic Mind is not on me | Demonic Mind | S1 |
| N3 | No Firestone on my weapon | Create and use a Firestone | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | Hot Streak is on me | Pyroblast (instant; also stops a Scorch mid-cast) | S1 (his macro does exactly this) |
| C2 | Combustion is ready, if rolled | Combustion | S1; timing **guess** |
| C3 | Moving, or no Hot Streak | Scorch | S1 (fishes for the two crits) |

With crit capped, C1 fires almost every global cooldown and Scorch is only the starter. Below the cap, the bot simply
falls back to Scorch more often.

## 5. Open points

| Point | How to settle it |
|---|---|
| Does Hot Hands still let a Pyroblast crit restart Hot Streak? | In game |
| Bots and "stop casting" | The bot module must interrupt a Scorch cast when Hot Streak appears; **check** |
