# Bot build: Protection Warrior, shield tank (tank)

Status: draft, 28 Nov 2026. Proposed new build 6 of 10 (`faction-rosters.md`): Alliance, home race Dwarf (Stoneform,
plus Prospector's Spirit). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: main tank. Carries Commanding Shout or Battle Shout, Demoralizing Shout, Thunder Clap (attack speed debuff) and
Sunder Armor.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 protection warrior rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Shield Finesse | Wildcard talent | Working (audit) | Shield Wall resets Shield Block; Shield Block resets Shield Slam | More downtime between blocks |
| Sword and Thunder | Wildcard talent | Working (audit) | Devastate and Revenge may reset Thunder Clap and grant a buff | Fewer Thunder Claps |
| Enduring Aegis | Enchant only | Working (audit) | During Shield Block, Shield Slam hits more targets and extends Shield Block; more block value | Optional; needs bot enchants |
| Shield Slam, Revenge, Devastate, Sword and Board, Vigilance | Stock | Stock | The classic core | — |

The classic build works without the Wildcard parts; they add block uptime and area threat.

## 3. How the build works

- Defensive Stance; Shield Block on cooldown.
- Shield Slam (instantly when Sword and Board procs), then Revenge, then Devastate as filler.
- Thunder Clap and Demoralizing Shout kept up on the target; Shockwave and Thunder Clap on groups.
- Heroic Strike (Cleave on groups) when rage is high.
- Shield Wall and Last Stand at critical health.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Shield Slam, Revenge, Devastate, Shield Block, Thunder Clap, Demoralizing Shout, Shockwave, Concussion Blow, Heroic Strike, Cleave, Taunt | S1 |
| Defensives | Shield Wall, Last Stand, Spell Reflection | S1 |
| Talents | Sword and Board, Vigilance, Critical Block, Shield Finesse, Sword and Thunder | S1, S2 |
| Enchants (if bots can slot them) | Enduring Aegis | S2 |

Stats: stamina, defense to the cap, then block value, expertise, hit.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Not in Defensive Stance | Defensive Stance | S1 |
| N2 | No shout from me on the group | Commanding Shout (Battle Shout if a paladin gives Might) | S1 |
| T1 | Health critical **and** Shield Wall is ready | Shield Wall | S1 |
| T2 | Health critical **and** Last Stand is ready | Last Stand | S1 |
| T3 | Lost aggro on a group member's target | Taunt | S1 |
| T4 | Shield Block is ready | Shield Block | S1 |
| T5 | Sword and Board on me, or Shield Slam is ready | Shield Slam | S1 |
| T6 | Revenge is usable | Revenge | S1 |
| T7 | Target lacks Thunder Clap's debuff **or** three or more enemies near me | Thunder Clap | S1, S2 |
| T8 | Target lacks Demoralizing Shout | Demoralizing Shout | S1 |
| T9 | Three or more enemies in front **and** Shockwave is ready | Shockwave | S1 |
| T10 | Rage above 60 | Heroic Strike (Cleave if two or more enemies) | S1 |
| T11 | Otherwise | Devastate | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Heroic Strike is an on-next-swing ability | The bot module's warrior strategy already handles it for class 1; check for class 10 |
| Enchant-only enabler (Enduring Aegis) | `enablers.md`, section 4 |
