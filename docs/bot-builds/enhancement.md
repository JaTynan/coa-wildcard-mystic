# Bot build: Enhancement, storm and lava melee shaman (melee)

Status: draft, 28 Nov 2026. Proposed new build 3 of 10 (`faction-rosters.md`): Horde, home race Orc. Format and rules
as in `plague-caster.md`. Nothing here is live.

Role: melee damage with strong bursts. Carries Windfury Totem and Strength of Earth Totem (raid-wide here,
`raid-coverage.md`), and Bloodlust.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 enhancement shaman rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status (`enchants/tracker.csv`, merged fixes on `main`) | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Stormborn | Wildcard talent | Working (audit) | During Shamanistic Rage or Elemental Mastery, Stormstrike also hits everything in front with nature damage | Classic single-target only |
| Pack Alpha | Wildcard talent | Live | Feral Spirit gives a buff that Stormstrike and Lava Lash extend, and they shorten Feral Spirit's cooldown | Feral Spirit far less often |
| Swirling Maelstrom | Enchant only | Working (audit) | Lava Lash, Stormstrike and spending 5 Maelstrom stacks build an extra buff | Optional; needs bot enchants |
| Maelstrom Weapon, Stormstrike, Lava Lash, Feral Spirit | Stock | Stock | The classic core | — |

## 3. How the build works (classic, plus enablers)

- Windfury Weapon on the main hand, Flametongue on the off hand; Lightning Shield kept up.
- Spend 5 Maelstrom Weapon stacks on an instant Lightning Bolt (Chain Lightning on groups).
- Stormstrike, Earth Shock (Flame Shock if missing), Lava Lash on cooldown.
- Feral Spirit and Shamanistic Rage on cooldown; Shamanistic Rage also makes Stormstrike cleave with Stormborn.
- Fire Nova and Magma Totem for groups.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Stormstrike, Lava Lash, Earth Shock, Flame Shock, Lightning Bolt, Chain Lightning, Feral Spirit, Shamanistic Rage, Fire Nova, Lightning Shield | S1 |
| Totems | Windfury, Strength of Earth, Magma or Searing, Mana Spring | S1 |
| Talents | Maelstrom Weapon, Stormstrike, Lava Lash, Feral Spirit, Stormborn, Pack Alpha | S1, S2 |
| Enchants (if bots can slot them) | Swirling Maelstrom | S2 |

Stats: attack power, hit, expertise, haste.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Main-hand weapon not enchanted | Windfury Weapon | S1 |
| N2 | Off-hand weapon not enchanted | Flametongue Weapon | S1 |
| N3 | Lightning Shield missing | Lightning Shield | S1 |
| C1 | Feral Spirit is ready | Feral Spirit | S1 |
| C2 | Shamanistic Rage is ready **and** (mana below 60% **or** three or more enemies in front) | Shamanistic Rage | S1, S2 |
| C3 | Maelstrom Weapon at 5 stacks **and** three or more enemies near the target | Chain Lightning | S1 |
| C4 | Maelstrom Weapon at 5 stacks | Lightning Bolt | S1 |
| C5 | Stormstrike is ready | Stormstrike | S1 |
| C6 | Target lacks my Flame Shock | Flame Shock | S1 |
| C7 | Earth Shock is ready | Earth Shock | S1 |
| C8 | Lava Lash is ready | Lava Lash | S1 |
| C9 | Three or more enemies near me **and** a fire totem is down | Fire Nova | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Weapon-enchant conditions (N1, N2) | The bot module already enchants shaman weapons for class 7; check it works for class 10 |
| Enchant-only enabler (Swirling Maelstrom) | `enablers.md`, section 4 |
