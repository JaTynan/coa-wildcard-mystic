# Bot build: Discipline, shield and atonement priest (healer)

Status: draft, 28 Nov 2026. Proposed new build 5 of 10 (`faction-rosters.md`): Horde, home race Troll (Berserking
rework gives haste for Penance and Smite). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: healer who prevents damage (Power Word: Shield, Divine Aegis) and heals through damage (Atonement). Carries
Power Word: Fortitude, Divine Spirit and Shadow Protection, and Pain Suppression for the tank.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 discipline priest rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Atonement | Wildcard talent | Working (audit) | Smite and Holy Fire damage heal a nearby ally | Classic discipline, no damage-to-heal |
| Dominant Word: Shield | Wildcard talent | Working (audit) | A much bigger shield on allies under 75% health; Smite, Holy Fire and Penance damage build stacks | Smaller shields |
| Holy Spirit | Wildcard talent | Working (audit) | Penance, healing or damaging, gives a buff | Optional |
| Penance, Divine Aegis, Borrowed Time, Grace, Rapture | Stock | Stock | The classic core | — |

## 3. How the build works

- Power Word: Shield on whoever is about to take damage (tank first, then anyone hurt), respecting Weakened Soul.
- Penance on cooldown on the most hurt ally; Flash Heal after a shield (Borrowed Time haste).
- Prayer of Mending on cooldown.
- With Atonement: when nobody needs healing, Smite and Holy Fire the target to heal allies anyway.
- Pain Suppression on the tank at critical health.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Power Word: Shield, Penance, Flash Heal, Prayer of Mending, Greater Heal, Renew, Smite, Holy Fire, Pain Suppression, Power Infusion | S1 |
| Buffs | Power Word: Fortitude, Divine Spirit, Shadow Protection, Inner Fire | S1 |
| Talents | Divine Aegis, Borrowed Time, Grace, Rapture, Atonement, Dominant Word: Shield, Holy Spirit | S1, S2 |

Stats: spell power, haste, critical strike (Divine Aegis), spirit.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | A raid buff missing on a group member | Fortitude, Divine Spirit or Shadow Protection | S1 |
| N2 | Inner Fire missing | Inner Fire | S1 |
| H1 | The tank at critical health **and** Pain Suppression is ready | Pain Suppression on the tank | S1 |
| H2 | The tank lacks Power Word: Shield **and** lacks Weakened Soul | Power Word: Shield on the tank | S1 |
| H3 | A group member at low health **and** Penance is ready | Penance on them | S1 |
| H4 | A group member hurt **and** lacks Power Word: Shield and Weakened Soul | Power Word: Shield on them | S1, S2 |
| H5 | Prayer of Mending is ready **and** the group is in combat | Prayer of Mending on the tank | S1 |
| H6 | A group member at low health | Flash Heal on them | S1 |
| H7 | A group member hurt | Renew on them if they lack it | S1 |
| C1 | Nobody below 80% health **and** mana above 50% **and** Holy Fire is ready | Holy Fire on the target | S2 |
| C2 | Nobody below 80% health **and** mana above 50% | Smite on the target | S2 |

## 6. Open points

| Point | How to settle it |
|---|---|
| "Lacks Weakened Soul" on a group member | `no aura::` checks the bot itself; a per-member aura check is a bot need (`plague-caster.md`, section 5) |
| How far a healer bot should Smite (C1, C2) | James's call; start with the 80% and 50% thresholds above |
