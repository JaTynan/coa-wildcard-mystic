# Bot build: Plague Caster (Spirit Stacker)

Status: draft, 28 Nov 2026. The first written build for the tailored bot roster (`docs/bot-roster-plan.md`). Nothing
here is live. The rotation lines use two conditions that do not exist yet (`all::` and `not::`, section 5); they
need one C++ change first.

Role: ranged damage (caster). Raid and dungeon first; it is a ramping damage-over-time build, weak in short fights.

## 1. Sources

| # | Source | What it gave | Weight |
|---|---|---|---|
| S1 | Video "Plague Caster - Spirit Stacker - Build Guide - Ascension s10 wildcard", Heytrix, 13 Aug 2026, https://www.youtube.com/watch?v=orV5JLdugbQ (transcript read 28 Nov; chapter "Rotation & Opener", 3:20-10:20) | The Season 10 Wildcard version: abilities, talents, opener, which procs to wait for, stats, gear, race | Primary: same realm type and season as ours |
| S2 | Old Discord build guide "Harbinger of Pestilence" (nature and shadow caster hybrid), passed on by James 28 Nov | An older version of the same idea: opener, priority list, rules of thumb, stat order | Cross-check: an earlier season, several abilities differ |
| S3 | Our client spell data (`Spell.dbc`, read 28 Nov) | Exact behaviour, stack limits and durations of each ability | Settles what an ability does; never how to order two choices |
| S4 | The bot module's own pick table (`CoaWildcardPicks.cpp`, build "Plague Caster") | The abilities a bot already drafts toward | Matches S1's list one for one |

Rule used (the project's conflict rule): the game data (S3) decides what an ability does; S1 decides how the build is
played on our season; S2 confirms or flags. Where none of them decides, the choice is marked **guess**.

## 2. How the build works

All of this is checked against S3 unless marked.

- **Wrath** (druid) is the filler. Each cast grants a stack of **Harbinger of Plague**: diseases and Haunt deal more
  damage, up to 5 stacks, 8 seconds each.
- **Haunt** (warlock) raises the damage of shadow damage-over-time on the target for 12 seconds. While Haunt is on the
  target, **Wrath of the Plague** makes every Wrath also lay a short shadow disease (2.5 seconds, ticks every half
  second). With Harbinger up, Haunt also splashes nearby enemies.
- **Plague Swarm** is this season's Insect Swarm: a disease that counts as shadow damage under Shadowform.
- **Devour Mind** is this season's Devouring Plague, but channelled like Mind Flay: it lays a big disease, heals the
  caster, and keeps extending while the channel continues.
- **Natural Selection** (talent): each Wrath extends the Insect Swarm on the target, up to 15 times before it goes on
  cooldown. S1 says this works on Plague Swarm, so Plague Swarm rarely needs recasting (S3 names Insect Swarm only:
  **check in game**).
- **Icy Touch** with **Ebon Plaguebringer**: Ebon Plague raises disease and magic damage taken; Frost Fever also
  turns on Tundra Stalker. S1's opener lost a lot of damage by forgetting it. (S3 words the talent as morphing Crypt
  Fever: **check in game** that Icy Touch alone applies Ebon Plague.)
- **Shadowform** makes the plague damage count as shadow and lets Devour Mind crit and benefit from haste (S1).
- **Procs to line up** before the big diseases (S1): 5 Harbinger stacks, **Nature's Grace** (a Wrath crit gives 20%
  haste for 4 seconds) and **Spirit Tap** (a crit from Haunt or Mind Flay, via Improved Spirit Tap).
- **Spirit stacking** (S1): Fel Armor and Molten Armor turn spirit into spell power and crit, so spirit is the main stat
  after hit.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Wrath, Haunt, Plague Swarm, Devour Mind, Shadowform, Icy Touch | S1, S4 |
| Core talents | Harbinger of Plague, Wrath of the Plague, Ebon Plaguebringer, Natural Selection, Improved Blood Presence (threat), Spirit Tap and Improved Spirit Tap | S1, S4 |
| Cooldowns | Voice of Bwonsamdi, Avenging Wrath, Icy Veins, on-use trinket | S1 (any haste or damage cooldown that rolls, such as Power Infusion or Arcane Power, does the same job) |
| Rolled extras (vary per bot) | Fel Armor or Molten Armor, Mind Flay, a group buff, Cleansing Totem, Earth and Moon, Tundra Stalker | S1 |

Stats: hit to the cap first (S2 gives 17%; S1 says hit is the hardest stat on this build), then spirit, then spell
power and crit, haste last. Both sources agree.

Race (S1, a min-max choice only): human on Alliance for the spirit bonus; S1 suggests a haste racial on Horde.

## 4. The decision list

Read top to bottom: the bot does the first line whose condition is true. A lower line is the "else".

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Shadowform is not on me | Shadowform | S1 |
| N2 | My armour (Fel or Molten) is not on me, if rolled | Cast it | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| C1 | My Frost Fever is not on the target | Icy Touch | S1 |
| C2 | Haunt is ready | Haunt | S1, S2 (use it on cooldown) |
| C3 | 5 Harbinger stacks **and** Spirit Tap on me **and** the cooldowns are ready | Cooldowns, then carry on | S1 (Nature's Grace left out of the condition: it lasts 4 seconds and would delay too often; **guess**) |
| C4 | 5 Harbinger stacks **and** my Plague Swarm is not on the target | Plague Swarm | S1, S2 (apply only at 5 stacks) |
| C5 | 5 Harbinger stacks **and** my Devour Mind is not on the target | Channel Devour Mind to the end | S1, S2 (channelling to the end: **guess**) |
| C6 | No Spirit Tap on me **and** no Harbinger stacks at all (the fight has just started) **and** Mind Flay rolled | Mind Flay | S2's opener (two casts); S1 for low-gear bots. Limited to the start so it does not replace Wrath: **guess** |
| C7 | Always | Wrath | S1, S2 (filler that builds stacks, feeds Wrath of the Plague and extends Plague Swarm) |

Deliberate choices:

- **No early refresh.** S2 says not to reapply diseases before they run out; S1 instead re-applies when the most
  procs are up. The list follows S2: it is simpler, and Natural Selection keeps Plague Swarm going anyway.
- **The opener falls out of the list.** In the first seconds there are no stacks, so C1 and C2 fire, then Wrath (C7)
  builds stacks; at 5 stacks C3 to C5 fire. This matches both sources' opener without a separate "opener" state.
- **Single target only.** Neither source describes area play beyond Haunt's splash.

### The same list as rotation lines (proposed syntax)

`all::` (every condition true) and `not::` do not exist yet; the rest are the bot module's existing conditions and
actions. Spell names are checked against S3.

```
nc:  not::has aura::Shadowform>cast::Shadowform!90
co:  debuff missing::Frost Fever>cast::Icy Touch!90
co:  can cast::Haunt>cast::Haunt!85
co:  all::aura stacks::Harbinger of Plague,5&&has aura::Spirit Tap&&can cast::Voice of Bwonsamdi>cast::Voice of Bwonsamdi!84,cast::Avenging Wrath!83,cast::Icy Veins!82
co:  all::aura stacks::Harbinger of Plague,5&&debuff missing::Plague Swarm>cast::Plague Swarm!80
co:  all::aura stacks::Harbinger of Plague,5&&debuff missing::Devour Mind>cast::Devour Mind!75
co:  all::not::has aura::Spirit Tap&&not::has aura::Harbinger of Plague>cast::Mind Flay!40
co:  can cast::Wrath>cast::Wrath!20
```

## 5. What the bots need before this can run

1. The `all::` and `not::` conditions (C++, one build, reusable by every build).
2. A hook so a named Hero always loads its own lines, including after a rebuild (C++, same build).
3. The lines loaded into memory at start-up, never read from the database mid-fight.
4. A check that the general routine does not fight the written lines (it keeps interrupts and defensives).

## 6. Open points

| Point | How to settle it |
|---|---|
| Does Natural Selection extend Plague Swarm? | In game: cast Plague Swarm, then Wrath, watch the duration |
| Does Icy Touch alone apply Ebon Plague with this build? | In game: target debuffs after Icy Touch |
| Channel Devour Mind to the end, or clip it? | James, or the old Discord guides |
| Movement: S2 used Earth Shock to keep a debuff up while moving | Not in the Season 10 build; leave out unless a source says otherwise |
| James's cross-check against the old Discord Wildcard guides | Record any change here with the date |
