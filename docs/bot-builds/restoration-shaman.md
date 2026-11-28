# Bot build: Restoration Shaman, Riptide and Chain Heal (healer)

Status: draft, 28 Nov 2026. Proposed new build 8 of 10 (`faction-rosters.md`): Alliance, home race Draenei (Radiant
Presence: auras and totems reach 50% further; Gift of the Naaru). Format and rules as in `plague-caster.md`. Nothing
here is live.

Role: group healer with Chain Heal, Earth Shield on the tank, and totems (Mana Spring, Stoneskin, Wrath of Air; all
raid-wide here, `raid-coverage.md`). Carries Mana Tide Totem and Heroism. The Alliance counterpart to the Horde's Tide
Chain Healer (`tide-chain-healer.md`), on the classic base rather than Living Lightning.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | The original 3.3.5 restoration shaman rotation (James's rule, 28 Nov) | The rotation |
| S2 | Our client spell data and enchant status | Enablers, status |

## 2. Build enablers

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Mending Tide | Wildcard talent | Working (audit) | Riptide marks one ally; healing that ally spreads a follow-up chain effect | Classic Riptide |
| Low Tide | Wildcard talent | Working (audit) | More critical heals on the Riptide target | Optional |
| Transcendental Embrace | Wildcard talent | Working (audit) | Critical Healing Wave and Lesser Healing Wave give a buff | Optional |
| Restoration Mastery (shaman version) | Enchant only | Working (audit) | Chain Heal, Healing Wave and Lesser Healing Wave heal more | Optional; needs bot enchants |
| Riptide, Earth Shield, Tidal Waves, Chain Heal, Mana Tide Totem | Stock | Stock | The classic core | — |

## 3. How the build works

- Earth Shield on the main tank, Water Shield on myself, Earthliving Weapon on the weapon.
- Riptide on cooldown on a hurt ally (the tank by default), then Chain Heal starting on that ally to use Riptide's
  bonus and Tidal Waves.
- Healing Wave (after Tidal Waves) on a tank in trouble; Lesser Healing Wave for quick top-ups.
- Totems: Mana Spring, Stoneskin or Strength of Earth, Wrath of Air, Flametongue; Mana Tide when low on mana.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Riptide, Chain Heal, Healing Wave, Lesser Healing Wave, Earth Shield, Water Shield, Earthliving Weapon, Cleanse Spirit, Nature's Swiftness | S1 |
| Totems | Mana Spring, Stoneskin, Wrath of Air, Flametongue, Mana Tide | S1 |
| Talents | Tidal Waves, Ancestral Awakening, Improved Earth Shield, Mending Tide, Low Tide, Transcendental Embrace | S1, S2 |
| Enchants (if bots can slot them) | Restoration Mastery | S2 |

Stats: spell power, haste, mana per 5 seconds, critical strike.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | The main tank lacks my Earth Shield | Earth Shield on the main tank | S1 |
| N2 | Water Shield missing | Water Shield | S1 |
| N3 | Weapon not enchanted | Earthliving Weapon | S1 |
| N4 | A totem missing in combat | Place it (Mana Spring, Stoneskin, Wrath of Air, Flametongue) | S1 |
| H1 | A group member at critical health **and** Nature's Swiftness is ready | Nature's Swiftness, then Healing Wave on them | S1 |
| H2 | A group member hurt **and** Riptide is ready | Riptide on them (the tank first) | S1, S2 |
| H3 | Several group members hurt | Chain Heal on the one with my Riptide, else the most hurt | S1 |
| H4 | The tank at low health **and** Tidal Waves on me | Healing Wave on the tank | S1 |
| H5 | A group member hurt | Lesser Healing Wave on them | S1 |
| M1 | Mana below 40% **and** Mana Tide Totem is ready | Mana Tide Totem | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Chain Heal on "the ally with my Riptide" (H3) | Needs a "target has my aura" choice of heal target; `to check` |
| Totem placement for class 10 | The bot module's shaman totem strategy is for class 7; check for Heroes |
