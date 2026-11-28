# Bot build: Beast Master, pet hunter (ranged)

Status: draft, 28 Nov 2026. Proposed new build 2 of 10 (`faction-rosters.md`): Horde, home race Orc (Command and
Bloodrush both feed the pet's and the hunter's damage). Format and rules as in `plague-caster.md`. Nothing here is live.

Role: ranged damage through a strong pet. Simple to play, which suits a bot.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 beast mastery hunter rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status (`enchants/tracker.csv`, merged fixes on `main`) | Enablers, status |

No Season 9 or 10 guide found yet.

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Unrelenting Wrath | Wildcard ability | Not tracked | Sends the pet into a rage for more damage and less threat, and resets Frenzy Shot; two charges | Classic Bestial Wrath only |
| Frenzy Shot | Wildcard ability | Not tracked | A shot that makes the pet's auto attacks strike extra nearby enemies | Less damage, no pet cleave |
| Bestial Assault | Wildcard talent | Fix live, untested | Direct hunter shots build a buff that gives Unrelenting Wrath charges back | Fewer Unrelenting Wraths |
| Fetch Me Their Bones! | Wildcard talent | Working (audit) | Hunter shots shorten Kill Command; Kill Command makes the pet charge and hit an area | Classic Kill Command |
| Hunting Frenzy | Enchant only | Working (audit) | Pet specials hit harder under Hunter's Mark; Kill Command boosts the pet's next crits | Optional; needs bot enchants |
| Beast Mastery | Stock talent | Stock | Exotic pets and more pet talent points | Classic |

The classic build (Bestial Wrath, The Beast Within, Kill Command) works without any of these; the Wildcard ones add
area damage and more uptime.

## 3. How the build works (classic, plus enablers)

- Hunter's Mark on the target; Serpent Sting kept up.
- Kill Command on cooldown; Bestial Wrath (with The Beast Within) on cooldown, or Unrelenting Wrath with its charges.
- Frenzy Shot whenever ready; then Arcane Shot and Steady Shot as filler.
- Multi-Shot and Volley for groups.
- Aspect of the Dragonhawk, swap to Aspect of the Viper when low on mana.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Hunter's Mark, Serpent Sting, Kill Command, Bestial Wrath, Unrelenting Wrath, Frenzy Shot, Arcane Shot, Steady Shot, Multi-Shot, Volley | S1, S2 |
| Talents | Beast Mastery, The Beast Within, Ferocious Inspiration, Fetch Me Their Bones!, Bestial Assault | S1, S2 |
| Enchants (if bots can slot them) | Hunting Frenzy | S2 |

Stats: agility, attack power, hit to cap. Pet: a ferocity pet (classic choice: wolf for Furious Howl).

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | No aspect, mana above 30% | Aspect of the Dragonhawk | S1 |
| N2 | Mana below 10% | Aspect of the Viper | S1 |
| C1 | Target lacks Hunter's Mark | Hunter's Mark | S1 |
| C2 | Unrelenting Wrath has a charge **and** the pet is attacking | Unrelenting Wrath | S2 |
| C3 | Bestial Wrath is ready **and** the pet is attacking | Bestial Wrath | S1 |
| C4 | Kill Command is ready | Kill Command | S1 |
| C5 | Frenzy Shot is ready | Frenzy Shot | S2 |
| C6 | Three or more enemies near the target | Multi-Shot | S1 |
| C7 | Target lacks my Serpent Sting | Serpent Sting | S1 |
| C8 | Arcane Shot is ready | Arcane Shot | S1 |
| C9 | Otherwise | Steady Shot | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| The pet must be alive and attacking for C2-C4 | Needs a "pet attacking" condition; `to check` in the bot module |
| Enchant-only enablers (Hunting Frenzy) | Bots of class 10 get no Mystic Enchants today (`enablers.md`, section 4) |
