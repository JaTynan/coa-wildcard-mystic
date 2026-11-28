# Bot build: Arcane Gunslinger (ranged)

Status: draft, 28 Nov 2026. Ranged slot 1 of 2 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing
here is live. The bot module also has a named build **Arcane Gunslinger**.

Role: ranged damage, single target, from a gun. A hunter and arcane mage hybrid (duality path). Carries Arcane
Empowerment and Trueshot Aura for the raid.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "FINALLY a Build I Like! Arcane Gunslinger Project Ascension Season 10's Darkmoon Wildcard Server", HVLN Plays, Season 10, https://www.youtube.com/watch?v=dH2nhP9LoSw (transcript read 28 Nov) | Primary: a full Season 10 guide |
| S2 | Our client spell data: every ability below exists ("Rune-Edged Bullets" is "Runed Bullets") | Mechanics |

## 2. How the build works

- **Missile Barrage** (talent): arcane damage often makes the next **Arcane Missiles** free and about a second long.
- Spending Missile Barrage gives **Barrage Overload**: the next **Arcane Barrage** fires one extra bolt per stack (up to
  six), and those bolts hit hard.
- **Arcane Gunslinger** (talent): Arcane Barrage hits one more enemy, does 25% more, and can give Missile Barrage back.
- **Lunar Marksmanship** and **Lunar Synergy**: during Lunar Eclipse, Arcane Shot's cooldown is halved; Arcane Missiles
  can start or extend Lunar Eclipse. So Arcane Shot is back by the time the loop comes round.
- **Arcane Shelling**: Arcane Shot stacks a buff raising Arcane Barrage damage (up to three).
- **Runed Bullets**: hunter shots can make **Arcane Blast** instant; cast it just before Arcane Barrage for 15% more
  arcane damage.
- **Shot Weaving**: Arcane Missiles also fires gun shots, which carry **Instant Poison** from the ranged weapon.
- The loop (S1): **Arcane Shot, Arcane Barrage, Arcane Missiles**, repeat; always spend Missile Barrage to keep the
  cycle going.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Arcane Shot, Arcane Barrage, Arcane Missiles, Arcane Blast (or Temporal Blast), Auto Shot, Life Tap, Time Bomb | S1 |
| Core talents | Arcane Gunslinger, Barrage Overload, Missile Barrage, Arcane Shelling, Lunar Marksmanship, Lunar Synergy, Total Lunar Eclipse, Shot Weaving, Runed Bullets | S1 |
| Damage talents | Arcane Arrows, Spellslinger (with arcane clearcasting), Glyph of Arcane Missiles, Demonic Pact and Demonic Tactics (with a demon), Careful Aim, Master Tactician, Arcane Empowerment, Mental Dexterity, Answered Prayers or another 10% talent | S1 |
| Rolled extras | Titan's Grip with Rockbiter Weapon on two two-handers, Fel Armor, Twisted Mind, Trueshot Aura, Rapid Fire, Instant Poison, Arcane Orb, Shamanistic Rage (mana), a Felguard | S1 |

S1 calls Arcane Infusion a trap (redundant). Stats: agility, intellect, spell power, crit, attack power (duality path:
all of them count).

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Fel Armor or Twisted Mind missing, if rolled | Cast it | S1 |
| N2 | My demon is not out | Summon it | S1 |
| C1 | Time Bomb is not on the target **and** it is ready | Time Bomb | S1 |
| C2 | Missile Barrage is on me | Arcane Missiles | S1 ("always consume it") |
| C3 | Runed Bullets' instant Arcane Blast is on me | Arcane Blast | S1 (right before Barrage) |
| C4 | Barrage Overload is on me | Arcane Barrage | S1 |
| C5 | Arcane Shot is ready | Arcane Shot | S1 |
| C6 | Low mana **and** health is fine | Life Tap | S1 |
| C7 | Always | Arcane Barrage | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| A demon pet on a bot (needed for Demonic Pact) | The bot module's pet handling for Heroes |
