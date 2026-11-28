# Bot build: Claw-sader, holy cat (melee)

Status: draft, 28 Nov 2026. Melee 2 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. The bot module's nearest named builds are **Druid of the Fang** and **Crusader**.

Role: melee damage, very strong on groups (its Swipe is not target capped, S1), solid single target.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "The Claw-sader Core Build Guide (Project Ascension - Season 10)", Sneptics, 29 Jul 2026, https://www.youtube.com/watch?v=bvSodiSUx5g (transcript read 28 Nov; the author also keeps a public spreadsheet) | Primary: a full Season 10 guide |
| S2 | Our client spell data. Real names: Light Swipe (Cat), Dawnripper, Dawn Rake, Dawnfang Bite, Goldrinn's Fury (S1 says "Gold's Fury"), Serpent Form, Consecrated Weapon, Seal of Command, Sweeping Strikes | Mechanics |

## 2. How the build works

- A cat (agility path) using the **holy "light" versions** of the cat abilities, so paladin holy bonuses apply.
- **Consecrated Weapon** and **Seal of Command** are the engine: auto attacks proc them, and cats attack about once a
  second whatever the weapon. S1: without these two the build does not work. No Judgement, no paladin strikes.
- Combo points from Claw; keep **Dawnripper** (Rip) and **Dawn Rake** up; **Dawnfang Bite** as the spender and for
  groups.
- **Goldrinn's Fury** (a Tiger's Fury variant): every ability lays a stacking shadow damage-over-time. With **Feral
  Instinct**, each enemy hit by Light Swipe cuts its cooldown by a second, so in big packs it is always up.
- **Sweeping Strikes** copies 40% of every Light Swipe hit to up to five more enemies.
- **Serpent Form** is a better Cat Form (adds poison damage). **Avenging Wrath is a trap**: it breaks the form (S1).

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Serpent Form (or Cat Form), Light Swipe, Claw, Dawnripper, Dawn Rake, Dawnfang Bite, Consecrated Weapon, Seal of Command, Goldrinn's Fury | S1 |
| Core talents | Ferocity (cheaper Swipe), Answered Prayers, Vitality, Feral Instinct, Bloody Claws, Righteous Vengeance, Relentless Strikes, attack power and agility talents | S1 |
| Cooldowns and utility | Sweeping Strikes, Adrenaline Rush, Carnage Incarnate (defensive with big area damage), Charge | S1 |
| Carried buffs | Trueshot Aura, Devotion Aura; S1 would swap Blessing of Might for a shout | S1 |
| Rolled extras | Seal of Vengeance (single target), Slice and Dice, Windfury Totem, Berserk, an interrupt; raid duty: Leader of the Pack, Mangle, Sanctified Retribution (`raid-coverage.md`) | S1, assignment |

Stats: agility, then hit to the cap, attack power, crit. No armour penetration: the damage is holy (S1). Two one-hand
weapons preferred (cheaper abilities on the agility path).

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Serpent Form or Cat Form (out of combat) | Shift | S1 |
| N2 | Consecrated Weapon or Seal of Command missing | Cast it | S1 |
| C1 | Not in form | Shift | S1 |
| C2 | Three or more enemies **and** Goldrinn's Fury is ready | Goldrinn's Fury | S1 |
| C3 | Three or more enemies **and** Sweeping Strikes is ready | Sweeping Strikes | S1 |
| C4 | Three or more enemies | Light Swipe (Cat) | S1 |
| C5 | Goldrinn's Fury is ready | Goldrinn's Fury | S1 |
| C6 | Low energy **and** Adrenaline Rush is ready | Adrenaline Rush | S1 |
| C7 | Five combo points **and** my Dawnripper is not on the target | Dawnripper | S1 |
| C8 | Five combo points | Dawnfang Bite | S1 |
| C9 | My Dawn Rake is not on the target | Dawn Rake | S1 |
| C10 | Always | Claw | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Seal swapping (Command for packs, Vengeance for bosses) | Leave the bot on Seal of Command until a "boss fight" condition exists |
