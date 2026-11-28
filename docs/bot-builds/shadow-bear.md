# Bot build: Shadow Bear (tank)

Status: draft, 28 Nov 2026. Third written build for the tailored bot roster (`docs/bot-roster-plan.md`). Nothing here
is live. Format and rules as in `plague-caster.md`. The bot module's nearest named build is **Beast of Nightmare**
(Corrupted Bear Form, Corruption, Shadow Bolt, Mangle, Bear Form).

Role: tank, dungeons and raids. Strong on groups of enemies; weak to magic damage (S1).

**Source warning.** No Season 10 Wildcard tank guide was found on YouTube on 28 Nov: searches turned up only long
live streams. The guide used is from **Season 9** Wildcard (February 2024). Every ability below exists in our client
data (S3), but numbers and some interactions may have changed since.

## 1. Sources

| # | Source | What it gave | Weight |
|---|---|---|---|
| S1 | Video "Bear the Dark Force: Shadow Bear Tank Build Guide - Project Ascension Season 9", Nordic Boomerchef Gaming, 29 Feb 2024, https://www.youtube.com/watch?v=Jc2yNGX5TGY (transcript read 28 Nov) | Abilities, talents, the core loop, what to roll for, stats | Primary, but one season old |
| S2 | Old Discord guide "Bear Tank" (2021), passed on by James 28 Nov | A plain physical bear: starting abilities, what to card, the area version | Cross-check: three seasons older, no rotation given |
| S3 | Our client spell data (`Spell.dbc`, read 28 Nov) | Exact behaviour; all the abilities named below exist | Settles what an ability does |

### What S2 confirms and adds

- **Agrees with S1:** Bear Form and Swipe as the core; Savage Defense carded; a Voidwalker (S2 also lists Soul Link)
  for damage reduction; Challenging Roar; Carnage Incarnate as the version for groups of enemies and dungeons.
- **Differs:** S2's bear has no Shadow Bolt at all. It is a physical bear that adds Evasion, Charge and Poisons, and
  suggests threat talents if needed. Barkskin is its alternative defensive.
- **Used here:** Evasion and Barkskin join the defensive cooldowns (T5b). The physical version is a good **second bear
  build** for the roster, so not every bear tank plays the same way.

## 2. How the build works

Checked against S3 unless marked.

- **Bear Form** with **Corrupted Bear Form**: less physical damage taken, shadow damage added to melee, and Maul and
  Mangle apply **Corruption**.
- **Nightmare Mauling**: Maul and Mangle apply Corruption; **Swipe** drains life from enemies carrying it. S1: Swipe also
  spreads the Corruption to nearby enemies.
- **Backlash**: when hit by a physical attack, a chance that the next Shadow Bolt is fast. **Nightfall**: Corruption
  ticks can make the next Shadow Bolt instant.
- **Maledictive Assault**: while Backlash or Nightfall is up, Shadow Bolt can be cast **without leaving Bear Form**, and
  it hits two extra targets.
- **Soul Leech**: Shadow Bolt damage heals the bear. S1: so spell power matters for survival, not only damage.
- **Savage Defense**: absorbs the next physical hits based on maximum health and attack power. S1: a melee crit in bear
  form always triggers it, so crit, health and agility all feed survival.
- **The loop** (S1): Swipe, Swipe, and an instant Shadow Bolt whenever Backlash or Nightfall lights up. S1 also uses
  Shadow Bolt to pull casters and line-of-sight to gather ranged enemies.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Bear Form, Swipe, Shadow Bolt, Feral Charge (bear) | S1 (level 1 picks) |
| Core talents | Maledictive Assault, Backlash, Soul Leech, Savage Defense | S1 ("the go-to four") |
| Corruption route | Corrupted Bear Form or Nightmare Mauling, Nightfall, Mangle or Maul | S1, S3 |
| Defensive cooldowns | Carnage Incarnate, Survival Instincts | S1 (carded) |
| Rolled extras | Hoplite Training (shield on a bear for armour), Mental Quickness, Enrage, Challenging Roar, an interrupt (S1: always have one), Soul Link with a Voidwalker or Felhunter and Master Demonologist (flat damage reduction), Iron Fur | S1 |

Stats: hit to the cap first (S1: a missed taunt or Shadow Bolt loses the pull), then agility, stamina and spell power.
Attack power feeds Savage Defense.

## 4. The decision list

Top to bottom; the first line that is true wins. Interrupts stay with the general routine.

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Bear Form | Bear Form | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| T1 | Not in Bear Form | Bear Form | S1 |
| T2 | An enemy in the group is not attacking me | Growl on it | Basic tank behaviour (not in S1) |
| T3 | My target is out of melee range | Feral Charge | S1 ("almost mandatory") |
| T4 | My health is critical **and** Survival Instincts is ready | Survival Instincts | S1 carded it; threshold **guess** |
| T5 | My health is low **and** Carnage Incarnate is ready | Carnage Incarnate | S1, S2; threshold **guess** |
| T5b | My health is low **and** Carnage Incarnate is on cooldown | Evasion or Barkskin, if rolled | S2 lists them; using them as the fallback: **guess** |
| T6 | Backlash **or** Nightfall's Shadow Trance is on me | Shadow Bolt | S1, S3 (the core of the build) |
| T7 | My Corruption is not on the target | Mangle (or Maul) | S1, S3 |
| T8 | Two or more enemies near me | Swipe | S1 |
| T9 | Mangle is ready | Mangle | **guess** (single-target order not given) |
| T10 | Always | Swipe | S1 ("Swipe, Swipe") |

The Shadow Bolt line needs an **or**: `any::` (one of these is true), the partner of `all::`. The same C++ change
adds it.

## 5. Open points

| Point | How to settle it |
|---|---|
| Season 9 to 10 changes | A Season 10 source, or James's knowledge of what changed |
| Rage use: Maul as a rage dump? | James (neither source says) |
| Does Shadow Bolt from Bear Form still hit three targets? | In game |
| Physical bear (S2) as its own build | Write it once the roster's tank slots are set |
