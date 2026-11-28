# Bot build: Holy Spell Tank, Crimson Champion (tank)

Status: draft, 28 Nov 2026. Tank 2 of 3 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here is
live. Matches the bot module's named build **Crimson Champion**.

Role: tank, strongest on groups: threat comes from holy spells, mainly two Consecrations at once. Many defensive
cooldowns. Carries Blessing of Sanctuary, Devotion Aura, Vindication (attack power reduction) and Thunder Clap.

**Source warning.** Season 9 guides: S1 on Wildcard (July 2024), S2 on the free-pick realm (September 2024). They agree
on the core.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "WOW Ascension Season 9 Holy Tank Build", LaserPenguinGames, 6 Jul 2024, https://www.youtube.com/watch?v=Kj1niyNlKoo (transcript read 28 Nov) | Primary, one season old |
| S2 | Video "ONE BUTTON GIGA TANK - Crimson Champion - Ascension WoW", Opto, 12 Sep 2024, https://www.youtube.com/watch?v=6TmB5oZOevo (description read 28 Nov): its one-button cast sequence is Consecration (Emanate), Judgement of Wisdom, Thunder Clap, Shield of Righteousness, Hammer of the Righteous, Hammer of Wrath | Cross-check and rotation order |
| S3 | Our client spell data: all abilities below exist except "Hammer Storm" and the "Taunting Consecrate" enchant, not found under those names | Mechanics |

## 2. How the build works

- **Two Consecrations**: the normal one on the ground and **Emanating Light**, a second one that follows the tank. Both
  use Consecration's modifiers, so every Consecration talent doubles up (S1).
- **Crimson Champion** needs Defensive Stance; **Righteous Fury** adds block and reflects holy damage, and grants Hand
  of Reckoning (a taunt) through a talent (S1).
- Holy threat talents and enchants (S1's Holy Guardian adds 30% threat to holy damage).
- **Shield of Righteousness** hits and heals; **Devastate** and Thunder Clap cost rage, not mana.
- Pulling: **Flesh Hook** pulls a caster in; **Smoke Bomb** makes ranged enemies come into melee and reduces damage.
- **Dispersion** is the best defensive and returns mana; plus Divine Protection, Shield Wall, Evasion, Last Stand,
  Ardent Defender (survives a killing blow).

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Consecration, Emanating Light, Hammer of the Righteous, Shield of Righteousness, Crimson Champion, Defensive Stance, Righteous Fury, Judgement of Wisdom, Thunder Clap | S1, S2 |
| Defensives | Dispersion, Divine Protection, Shield Wall, Evasion, Last Stand, Ardent Defender | S1 |
| Utility | Flesh Hook, Smoke Bomb, Shockwave, Rebuke, Holy Light, Purify, Curse of the Elements (also a ranged pull) | S1 |
| Carried buffs | Devotion Aura, Blessing of Kings, Blessing of Sanctuary, Vindication, Imp (Blood Pact), Aspect of the Monkey | S1 |

Stats: spell tank gear (stamina, armour, spell power), hit (S1 was short of it).

## 4. The decision list

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Defensive Stance, Righteous Fury, Devotion Aura or Aspect of the Monkey missing | Cast it | S1 |
| N2 | A group member lacks Blessing of Sanctuary or Kings | Cast it | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| T1 | An enemy in the group is not attacking me | Hand of Reckoning on it | S1, basic tank behaviour |
| T2 | A ranged enemy will not come in | Flesh Hook | S1 |
| T3 | My health is critical **and** a defensive is ready | Dispersion, else Shield Wall, else Divine Protection | S1; order **guess** |
| T4 | Low mana **and** Dispersion is ready | Dispersion | S1 |
| T5 | My Consecration is not down under the enemies | Consecration | S1, S2 |
| T6 | Emanating Light is ready | Emanating Light | S1, S2 |
| T7 | Judgement is ready | Judgement of Wisdom | S2 |
| T8 | Thunder Clap is ready | Thunder Clap | S2 |
| T9 | My health is below half **and** Shield of Righteousness is ready | Shield of Righteousness | S1 ("if you are down some health") |
| T10 | Hammer of the Righteous is ready | Hammer of the Righteous | S2 |
| T11 | Target below 20% **and** Hammer of Wrath is ready | Hammer of Wrath | S2 |
| T12 | Always | Shield of Righteousness or Devastate | S1, S2 |

## 5. Open points

| Point | How to settle it |
|---|---|
| "Hammer Storm" (S1's spinning hammers) | Find its real name in our spell data |
| Consecration placement for a moving pack | The bot module's tank movement; Emanating Light follows the tank anyway |
