# Bot build: Arcane Paladin, "Battlemage" (caster, melee range)

Status: draft, 28 Nov 2026. Caster 6 of 8 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live.

Role: damage from melee range. A paladin that weaves arcane mage spells into its strikes: good single target and
strong area damage (S1). It stands with the melee but scales with spell power and spell crit, so it fills a caster slot.

**Source warning.** Season 9 Wildcard guide (October 2024, level 70). No Season 10 version was found.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "The Arcane Paladin - Wildcard Elune lvl70 - Wow Ascension s9", Heytrix, 12 Oct 2024, https://www.youtube.com/watch?v=UItmRj2amDk (transcript and description read 28 Nov) | Primary, one season old |
| S2 | Our client spell data: every ability below exists ("Art of War" is "The Art of War") | Mechanics |

## 2. How the build works

- **Crusader Strike** and **Divine Storm** on cooldown; they proc the arcane seal (**Seal of Arcane Wrath**).
- **The Art of War** (must be 3/3): melee hits make the next **Arcane Blast** instant (**Divine Concord** swaps it in for
  Exorcism), which also feeds the Sanctity of Battle and Arcane Crusade talents.
- **Missile Barrage** procs are **not** spent on Arcane Missiles: **Arcanesworn** lets Crusader Strike consume them for a
  damage proc that also shortens Avenging Wrath's cooldown.
- **Avenging Wrath** makes the seal and **Arcane Barrage** much stronger and raises Missile Barrage chance. Guardian of
  Ancient Kings fills the gaps. **Arcane Power does not stack with Avenging Wrath**: S1 uses it only in between.
- **Arcane Divinity**: arcane spells also count as holy, and only the larger modifier applies, so S1 stacks holy damage.
- **Divine Illumination** is kept up by arcane spells and strikes extending it.
- **Blade of the Magisters**: paladin abilities stack a buff that raises mage spells; it does not refresh, so build a
  few stacks and then spend them on Arcane Blast and Arcane Barrage.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Crusader Strike, Divine Storm, Judgement of Wisdom, Seal of Arcane Wrath, Avenging Wrath, Divine Illumination, Arcane Blast, Arcane Barrage, Arcane Explosion (area) | S1 |
| Core talents | The Art of War, Arcanesworn, Arcane Divinity, Divine Concord, Arcane Crusade, Prophet of Wrath, One with the Light (leveling) | S1 |
| Strong extras | Barrage Overload, Blade of the Magisters, Fury of the Light, Etheric Vengeance, Guardian of Ancient Kings, Righteous Vengeance, Holy Fire with Divine Prophet | S1 |

Mana: Spellblade or Judgement of Wisdom (S1). Stats: spell crit (S1 at 80-90%), holy damage, spell power.

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Seal of Arcane Wrath is not on me | Cast it | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | Avenging Wrath is ready | Avenging Wrath | S1 |
| C2 | Avenging Wrath is on cooldown **and** not on me **and** Arcane Power is ready | Arcane Power | S1 (never together) |
| C3 | Missile Barrage is on me **and** Crusader Strike is ready | Crusader Strike | S1 (consume the proc with a strike) |
| C4 | The Art of War is on me | Arcane Blast (instant) | S1 |
| C5 | Divine Illumination is ready | Divine Illumination | S1 |
| C6 | Crusader Strike is ready | Crusader Strike | S1 |
| C7 | Three or more enemies near me **and** Divine Storm is ready | Divine Storm | S1 |
| C8 | Judgement is ready | Judgement of Wisdom | S1 |
| C9 | Three or more enemies near me | Arcane Explosion | S1 |
| C10 | Always | Arcane Barrage | S1 |

Blade of the Magisters stack-and-spend is left to the order above (strikes first, then spells): **guess**.

## 5. Open points

| Point | How to settle it |
|---|---|
| Needs level 70 abilities: at lower levels the bot plays a plain paladin | Fine for the level-banded roster; note it in the bot's level bands |
| Does Arcanesworn consume Missile Barrage on our core? | In game |
