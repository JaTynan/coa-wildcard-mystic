# Bot build: Holy Paladin, tank healer (healer)

Status: draft, 28 Nov 2026. Proposed new build 7 of 10 (`faction-rosters.md`): Alliance, home race Human (The Human
Spirit for mana regeneration). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: single-target healer on the tanks, with Beacon of Light copying heals. Carries Blessing of Kings or Wisdom, Devotion
Aura, and Judgement of Light.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 holy paladin rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Glimmer of Light | Wildcard talent | Working (audit) | Flash of Light builds stacks that Holy Shock spends | Classic Holy Shock |
| Synergetic Light | Wildcard talent | Working (audit) | Holy Light and Flash of Light shorten Holy Shock's cooldown | Fewer Holy Shocks |
| Growing Light | Wildcard talent | Fix live, untested | A heal bonus that builds while healing (shared with Prayer of Preservation) | Optional |
| Adorned by Light | Enchant only | Live | Healed allies are marked; heals on marked allies trigger bonus heals and Holy Shock gets stronger | Optional; needs bot enchants |
| Holy Shock, Beacon of Light, Infusion of Light, Light's Grace, Divine Illumination | Stock | Stock | The classic core | — |

## 3. How the build works

- Beacon of Light on the main tank, Sacred Shield on the off tank.
- Holy Light on the tank most hurt; Flash of Light for small damage and to build Glimmer stacks.
- Holy Shock on cooldown, sooner with Synergetic Light; Infusion of Light makes the next heal faster.
- Judgement of Light kept on the target, Divine Plea and Divine Illumination for mana.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Holy Light, Flash of Light, Holy Shock, Beacon of Light, Sacred Shield, Judgement of Light, Divine Plea, Divine Illumination, Lay on Hands, Cleanse | S1 |
| Talents | Illumination, Light's Grace, Infusion of Light, Beacon of Light, Glimmer of Light, Synergetic Light, Growing Light | S1, S2 |
| Enchants (if bots can slot them) | Adorned by Light | S2 |

Stats: spell power, intellect, haste, critical strike (Illumination).

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | The main tank lacks my Beacon of Light | Beacon of Light on the main tank | S1 |
| N2 | The off tank lacks my Sacred Shield | Sacred Shield on the off tank | S1 |
| N3 | A group member lacks my blessing | Blessing of Kings or Wisdom (as assigned) | S1 |
| H1 | A group member at critical health **and** Lay on Hands is ready | Lay on Hands | S1 |
| H2 | A group member at low health **and** Holy Shock is ready | Holy Shock on them | S1, S2 |
| H3 | Infusion of Light on me **and** a group member hurt | Holy Light on them | S1 |
| H4 | The tank at low or medium health | Holy Light on the tank | S1 |
| H5 | A group member hurt | Flash of Light on them | S1, S2 |
| M1 | Mana below 60% **and** Divine Plea is ready | Divine Plea | S1 |
| M2 | Mana below 50% **and** Divine Illumination is ready | Divine Illumination | S1 |
| M3 | In combat **and** target lacks Judgement of Light | Judgement of Light | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Which tank is the main tank for Beacon | The bot module knows group tanks (`cast heal tank::` exists); main versus off tank is `to check` |
| Enchant-only enabler (Adorned by Light) | `enablers.md`, section 4 |
