# Bot build: Retribution, holy-power paladin (melee)

Status: draft, 28 Nov 2026. Proposed new build 9 of 10 (`faction-rosters.md`): Alliance, home race Human (Spellsword
and the sword and mace skill racial). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: melee damage. Carries Sanctified Retribution (3% damage), Heart of the Crusader (3% crit taken), Replenishment
via Judgements of the Wise, and a Blessing.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 retribution paladin rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Holy Templar | Enchant only | Working (audit) | Crusader Strike, Divine Storm and Holy Shock build Holy Power (up to 5); 3 is spent on Templar's Verdict or Word of Glory | Classic retribution, no Holy Power |
| Consecrated Strikes | Enchant only | Working (audit) | Teaches Templar's Slash; Seal of Command deals physical weapon damage; strikes may leave consecrated ground | Less area damage |
| One With The Light | Wildcard talent | Working (audit) | A toggle trading physical damage for extra holy damage on Crusader Strike and Divine Storm | Optional |
| Seal of Command | Stock | Stock (only its scroll version is broken; the trained spell is unaffected) | The classic seal | — |
| Crusader Strike, Divine Storm, The Art of War | Stock | Stock | The classic core | — |

The Wildcard version of this build rests on two **enchants** (Holy Templar, Consecrated Strikes), not talents: it
exists for bots only once class 10 bots can slot Mystic Enchants (`enablers.md`, section 4). Until then the bot plays
classic retribution.

## 3. How the build works

- Seal of Command (Seal of Vengeance on one target is the classic alternative); Judgement on cooldown.
- Crusader Strike and Divine Storm on cooldown; Consecration and Hammer of Wrath (target under 20%) when ready.
- With Holy Templar: at 3 Holy Power, Templar's Verdict (Word of Glory if low on health).
- Exorcism only with The Art of War; Avenging Wrath on cooldown.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Crusader Strike, Divine Storm, Judgement of Wisdom, Consecration, Hammer of Wrath, Exorcism, Avenging Wrath, Seal of Command | S1 |
| With enchants | Templar's Verdict, Word of Glory, Templar's Slash | S2 |
| Talents | The Art of War, Sanctified Retribution, Heart of the Crusader, Judgements of the Wise, One With The Light | S1, S2 |
| Enchants (if bots can slot them) | Holy Templar, Consecrated Strikes | S2 |

Stats: strength, hit, expertise, critical strike.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | No seal on me | Seal of Command | S1 |
| N2 | A group member lacks my blessing | Blessing of Might or Kings (as assigned) | S1 |
| C1 | Avenging Wrath is ready | Avenging Wrath | S1 |
| C2 | Holy Power at 3 or more **and** health below 40% | Word of Glory on myself | S2 |
| C3 | Holy Power at 3 or more | Templar's Verdict | S2 |
| C4 | Judgement is ready | Judgement of Wisdom | S1 |
| C5 | Target under 20% health **and** Hammer of Wrath is ready | Hammer of Wrath | S1 |
| C6 | Crusader Strike is ready | Crusader Strike | S1 |
| C7 | Divine Storm is ready | Divine Storm | S1 |
| C8 | Two or more enemies in front **and** a Templar's Slash charge is ready | Templar's Slash | S2 |
| C9 | The Art of War on me | Exorcism | S1 |
| C10 | Consecration is ready **and** mana above 40% | Consecration | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Holy Power as a condition (C2, C3) | Is it an aura with stacks (`aura stacks::Holy Power,3`) or a power type? `to check` in spell data |
| Enchants for class 10 bots | `enablers.md`, section 4 |
