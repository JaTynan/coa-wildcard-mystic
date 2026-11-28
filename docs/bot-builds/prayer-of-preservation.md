# Bot build: Prayer of Preservation, holy healer (healer)

Status: draft, 28 Nov 2026. Healer 3 of 6 (`raid-coverage.md`). Format and rules as in `plague-caster.md`. Nothing here
is live. Matches the bot module's named build **Sacred Sentinel** (Holy Light, Prayer of Preservation, Preservation, Holy
Shock).

Role: healer for big burst damage, strongest in 10-player raids (S1's raid size). Beacon on the main tank, Holy Light
for big single heals, Prayer of Preservation for big group hits. Instant group dispels with Holy Supernova.

**Source warning.** Season 9 guide (March 2024): the author interviews a player who raided with it.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Video "The Holy Healer - Prayer of Preservation ft. Bas - Build Guide - Ascension Season 9", Heytrix, 16 Mar 2024, https://www.youtube.com/watch?v=GgnKTbCswY0 (transcript read 28 Nov; the guide also links a spreadsheet of abilities and talents) | Primary, one season old |
| S2 | Our client spell data: every ability below exists | Mechanics |

## 2. How the build works

- **Beacon of Light** on the main (or off) tank: much passive healing on the tank. **Growing Light** also heals
  allies near the beacon target.
- Single target: **Holy Light**, with instant **Flash of Light** procs, **Holy Shock** and **Prayer of Mending**;
  **Light's Grace** speeds up Holy Light.
- **Prayer of Preservation** for big incoming group damage; **Preservation** stacks on allies, and **Preserving Light**
  turns consuming them into a short shield plus heals on three nearby allies; **Recovering Prayer** cuts Prayer of
  Preservation's cooldown for each target hit.
- **Circle of Healing**, **Prayer of Mending** and Flash Heal-type casts shorten the cooldown of **Halo** (Circle of Life)
  and **Holy Supernova**.
- **Holy Supernova** with Supernova Salvation dispels the whole group at once (S1's example: curses on Magmadar).
- **Oracle of the Eclipse** turns Holy Shock into an emergency heal on five people.
- **Blessing of the Divines**: heals proc random blessings (haste, mana, party buffs); S1 calls it a must for any healer.
- Mana: S1 never ran low once the build was complete.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core abilities | Holy Light, Flash of Light, Holy Shock, Prayer of Mending, Circle of Healing, Prayer of Preservation, Beacon of Light, Halo (Circle of Life), Holy Supernova, Purify | S1 |
| Core talents | Preservation, Preserving Light, Recovering Prayer, Light's Grace, Growing Light, Blessing of the Divines, Oracle of the Eclipse, holy healing talents (Sheath of Light, Holy Guidance, Empowered Healing) | S1 |
| Utility | Power Infusion, Tremor Totem, Mana Tide Totem, Holy Ground, a blink, Berserking (racial) | S1 |

Stats: healing power (holy scaling), haste, crit, mana regeneration.

## 4. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | The main tank has no Beacon of Light | Beacon of Light on the main tank | S1 |
| H1 | Several group members carry a dispellable curse, poison or magic **and** Holy Supernova is ready | Holy Supernova | S1 |
| H2 | Several group members at low health **and** Prayer of Preservation is ready | Prayer of Preservation | S1 |
| H3 | Several group members at critical health **and** Oracle of the Eclipse's Holy Shock is ready | Holy Shock | S1 (emergency) |
| H4 | Several group members hurt **and** Halo is ready | Halo | S1 |
| H5 | Several group members hurt **and** Circle of Healing is ready | Circle of Healing | S1 |
| H6 | Prayer of Mending is ready **and** someone is taking damage | Prayer of Mending | S1 |
| H7 | A group member at low health **and** a Flash of Light proc is on me | Flash of Light | S1 |
| H8 | Holy Shock is ready **and** someone is hurt | Holy Shock | S1 |
| H9 | A group member is hurt | Holy Light | S1 |
| H10 | One group member has a dispellable effect | Purify on them | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| "Several members have a dispellable effect" | The bot module has a party-dispel condition; a count of members is **to check** |
