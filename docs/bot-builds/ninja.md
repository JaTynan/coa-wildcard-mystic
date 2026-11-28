# Bot build: Ninja, thrown weapons (ranged)

Status: draft, 28 Nov 2026. Ranged slot 2 of 2 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing
here is live.

Role: ranged physical damage with thrown weapons: high burst on one target or a group, fully mobile (no cast times).
S1 calls it close to a three-button build. Carries Hunter's Mark for the raid.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "0.5 SEC GCDs!?!? This build PUMPS in Project Ascension Season 10's Darkmoon Wildcard Server", HVLN Plays, Season 10, https://www.youtube.com/watch?v=g-IFcu6AoIY (transcript read 28 Nov) | Primary: a full Season 10 guide |
| S2 | Our client spell data: every ability below exists except "Physics and Practice" (S1's Sprint talent), not found under that name | Mechanics |

## 2. How the build works

- **Shuriken Toss** is the builder and the biggest share of damage; **Deadly Throw** is the five-point finisher (and it
  interrupts, with Throwing Specialization); **Glaive Toss** is the big hit.
- **Master of Kunai** (on Adrenaline Rush): during Adrenaline Rush, Shuriken Toss and Glaive Toss hit two more enemies,
  and each Shuriken Toss shortens Adrenaline Rush's cooldown.
- **Toss and Throw**: after a Deadly Throw, the next three Shuriken Tosses (or Glaive Tosses) give an extra combo point,
  cost less and hit harder. So the loop is **three Shuriken Toss, then Deadly Throw**.
- **Critical Serration** and **Clean Pass**: crits lay Piercing Shots; Glaive Toss consumes it for double damage.
- **Unseen Assassin**: after stealth or Shadow Dance, a half-second global cooldown and 40% more damage. The burst window
  is Vanish or stealth, then Adrenaline Rush and Shadow Dance together.
- Energy is the limit: Relentless Strikes, Vitality, Overkill and Throwing Specialization keep it flowing; Piercing
  Cleaver fills when energy is out. S1 lists Sealed Fate, Vigor, Omen of Clarity and Combat Potency as traps.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Shuriken Toss, Deadly Throw, Glaive Toss, Adrenaline Rush, Shadow Dance, Vanish, Sprint, Battle Stance | S1 |
| Core talents | Master of Kunai, Toss and Throw, Critical Serration, Clean Pass, Unseen Assassin, Flash of Adrenaline, Relentless Strikes, Vitality, Throwing Specialization, Mortal Shots, Lethality, Mace Specialization, Shredding Blows, Aggression | S1 |
| Rolled extras | Adrenaline Junkie, Overkill, Slaughter from the Shadows, Roll the Bones, Righteous Vengeance, Death Wish, Death Mark, Instant Poison (ranged weapon), Rockbiter Weapon, Aspect of the Hawk, Piercing Cleaver, a tamed wolf; raid duty: Hunter's Mark (`raid-coverage.md`) | S1, assignment |

Stats: hit to the cap, agility, attack power, crit, armour penetration. A thrown weapon in the ranged slot; a one-hand
mace for Mace Specialization. No auto attacks.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Battle Stance not active | Battle Stance | S1 (armour penetration) |
| C1 | Hunter's Mark not on the target | Hunter's Mark | Assignment |
| C2 | Adrenaline Rush is ready **and** (stealthed **or** Vanish is ready) | Vanish if not stealthed, then Adrenaline Rush | S1 (burst window) |
| C3 | Adrenaline Rush is on me **and** Shadow Dance is ready | Shadow Dance | S1 |
| C4 | Five combo points | Deadly Throw | S1 |
| C5 | Piercing Shots is on the target **and** Glaive Toss is ready | Glaive Toss | S1 |
| C6 | Enough energy | Shuriken Toss | S1 |
| C7 | Low energy **and** Roll the Bones is ready | Roll the Bones | S1 |
| C8 | Always | Piercing Cleaver | S1 (energy-free filler) |

Vanish mid-fight drops threat and stealths; for a bot it is fine in groups with a tank, but it must not be used as an
escape that leaves the fight: **check** the bot module's Vanish handling.

## 5. Open points

| Point | How to settle it |
|---|---|
| Sprint as a damage buff (S1's Sprint talent) | Find its real name in our spell data |
