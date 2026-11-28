# Bot build: Frost Death Knight (melee)

Status: draft, 28 Nov 2026. Melee 6 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live.

Role: melee damage, good single target, decent groups via Howling Blast. Carries Horn of Winter and Improved Icy Talons.

**Source note.** Death knight abilities arrived in Season 10 Wildcard (S2 shows them rolled and used), but no Season 10
or 9 guide for a death knight damage build was found. Following James's rule (28 Nov), the rotation is the original
3.3.5 frost death knight one.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 frost death knight rotation (two-handed Obliterate) | The rotation |
| S2 | Video "I Built My Own Death Knight in WoW! - Project Ascension Season 10", TylorRKO, 9 Aug 2026, https://www.youtube.com/watch?v=f82_QeReBGQ (a levelling vlog; shows Obliterate, Blood Strike, Death Grip, Pestilence, Blood Boil and runes working on a Season 10 Hero, and notes that some rune abilities were awkward to combine) | Confirms the abilities exist on Wildcard |
| S3 | Our client spell data: every ability below exists | Mechanics |

## 2. How the build works (classic)

- Keep both diseases up: **Icy Touch** (Frost Fever) and **Plague Strike** (Blood Plague).
- **Obliterate** spends frost and unholy runes; **Blood Strike** spends blood runes.
- **Frost Strike** spends runic power.
- **Killing Machine** makes the next Frost Strike (or Icy Touch / Howling Blast) crit; **Rime** makes the next
  Howling Blast free.
- **Pestilence** spreads the diseases to nearby enemies; **Howling Blast** for groups.
- **Horn of Winter** gives strength and agility to the raid and runic power to the knight.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Icy Touch, Plague Strike, Obliterate, Blood Strike, Frost Strike, Howling Blast, Pestilence, Horn of Winter, Death Grip, Empower Rune Weapon, Unbreakable Armor | S1, S2 |
| Core talents | Killing Machine, Rime, Improved Icy Talons, frost damage talents, two-hand weapon talents | S1 |
| Presence | Blood Presence for damage, as in 3.3.5 | S1 |

Stats: strength, hit and expertise caps, armour penetration, crit.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Horn of Winter not on me | Horn of Winter | S1 |
| C1 | My Frost Fever is not on the target | Icy Touch | S1 |
| C2 | My Blood Plague is not on the target | Plague Strike | S1 |
| C3 | Three or more enemies **and** both diseases on the target **and** Pestilence usable | Pestilence | S1 |
| C4 | Rime is on me | Howling Blast | S1 |
| C5 | Killing Machine is on me **and** enough runic power | Frost Strike | S1 |
| C6 | Obliterate usable (frost and unholy runes) | Obliterate | S1 |
| C7 | Blood Strike usable (blood runes) | Blood Strike | S1 |
| C8 | Runic power high | Frost Strike | S1 |
| C9 | No runes ready **and** Empower Rune Weapon is ready | Empower Rune Weapon | S1 |
| C10 | Always | Horn of Winter (runic power filler) | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Do runes work on a Wildcard Hero bot? | S2 shows them on a player; the bot module's death knight logic is classic-class only: **check** the Hero path |
| A Season 10 death knight guide | Search again later |
