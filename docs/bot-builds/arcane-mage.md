# Bot build: Arcane Mage, Arcane Blast and Missile Barrage (caster)

Status: draft, 28 Nov 2026. Proposed new build 10 of 10 (`faction-rosters.md`): Alliance, home race Gnome (Overclock,
Expansive Mind). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: caster damage with big bursts. Carries Arcane Intellect, Arcane Empowerment (3% damage) and Focus Magic.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 arcane mage rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Power Overwhelming | Wildcard talent | Not tracked | Direct spell damage shortens Arcane Power and Presence of Mind | Burst only every 2 minutes |
| Arcane Motes | Wildcard talent | Working (audit) | Arcane Missiles and Arcane Barrage create motes | Optional |
| Spellstorm | Wildcard talent | Fix live, untested | Using Missile Barrage gives an Arcane Evoked buff (and Brain Freeze a Fire one) | Evoker does nothing |
| Evoker | Wildcard talent | Live | Spending Spellstorm's buffs may repeat recent Arcane Missiles casts | Optional; needs Spellstorm |
| Arcane Blast, Arcane Missiles, Missile Barrage, Arcane Barrage, Arcane Power | Stock | Stock | The classic core | — |

## 3. How the build works

- Arcane Blast stacks up to 4 (each makes the next cost more and hit harder).
- Arcane Missiles only when Missile Barrage procs; at 4 stacks, Missiles (with Barrage) or Arcane Barrage to reset.
- Arcane Power, Presence of Mind and Icy Veins at the start of a burst; Power Overwhelming brings them back sooner.
- Evocation and Mana Gem for mana.
- Arcane Explosion and Blizzard on groups.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Arcane Blast, Arcane Missiles, Arcane Barrage, Arcane Power, Presence of Mind, Icy Veins, Mirror Image, Evocation, Conjure Mana Gem, Arcane Explosion, Blizzard | S1 |
| Buffs | Arcane Intellect, Molten Armor or Mage Armor, Focus Magic | S1 |
| Talents | Missile Barrage, Arcane Empowerment, Torment the Weak, Spell Power, Power Overwhelming, Arcane Motes, Spellstorm, Evoker | S1, S2 |

Stats: spell power, hit to the cap, haste, intellect.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Arcane Intellect missing on a group member | Arcane Intellect | S1 |
| N2 | No armour | Molten Armor | S1 |
| C1 | Arcane Power is ready | Arcane Power | S1, S2 |
| C2 | Presence of Mind is ready | Presence of Mind, then Arcane Blast | S1 |
| C3 | Three or more enemies near me | Arcane Explosion | S1 |
| C4 | Missile Barrage on me **and** Arcane Blast at 4 stacks | Arcane Missiles | S1 |
| C5 | Arcane Blast at 4 stacks **and** mana below 50% | Arcane Barrage | S1 |
| C6 | Otherwise | Arcane Blast | S1 |
| M1 | Mana below 30% **and** a Mana Gem is available | Mana Gem | S1 |
| M2 | Mana below 20% **and** Evocation is ready | Evocation | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Arcane Blast stacks (C4, C5) | The debuff is on the mage, so `aura stacks::Arcane Blast,4` fits |
| Spellstorm and Evoker together | Both depend on a fix that is live but untested; leave them out until a test passes |
