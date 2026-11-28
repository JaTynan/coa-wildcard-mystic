# Bot build: Dark Ranger, shadow hunter (ranged)

Status: draft, 28 Nov 2026. Proposed new build 1 of 10 (`faction-rosters.md`): Horde, home race Undead. Format and
rules as in `plague-caster.md`. Nothing here is live.

Role: ranged damage. A hunter that shoots shadow: auto shots, shadow shots and warlock damage over time, with strong
area damage (Death and Decay, Wave of Despair, Shadow Artillery).

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Season 10 build guide video by MASTERO (YouTube `VFq_2SRSvvU`), transcript read 28 Nov | The build and the play |
| S2 | Our client spell data: every ability and talent below exists; enchant status from `enchants/tracker.csv` and merged fixes on `main` | Mechanics, status |

## 2. Build enablers

The talents that make this build exist. Status words are explained in `enablers.md`.

| Enabler | Kind | Our status | What it does (paraphrased) | Without it |
|---|---|---|---|---|
| Shadow Shot | Wildcard ability | Not tracked (the scroll that teaches it is broken; the ability itself is untested) | Ranged weapon hit as shadow; extra damage to slowed targets; applies Corruption if known | No filler; the build does not work |
| Dark Arrows | Wildcard talent | Not tracked | Shadow Bolt and Seed of Corruption damage turn the next auto shots into shadow arrows, each cutting Black Arrow's cooldown | Much less damage; Black Arrow less often |
| Blood Arrow | Wildcard ability | Not tracked | Shadow hit plus a drain over time that heals the hunter | Lose sustain and a damage over time |
| Shadow Artillery | Wildcard ability | Not tracked | Area shadow strike plus a damage-over-time zone; two charges | Weaker area damage |
| Wave of Despair | Wildcard ability | Not tracked | A Seed of Corruption variant that hits several enemies; feeds Dark Arrows | Weaker area damage and fewer Dark Arrows |
| Growing Corruption | Wildcard talent | Working (audit) | Seed targets are easier to crit; the Seed explosion spreads Corruption | Optional |
| Necromancer's Touch | Wildcard talent | Fix live, untested | Pet bonus (S1 suggests it with Enslave Demon) | Optional |

## 3. How the build works (S1)

- Starter: Auto Shot, Blood Presence, Corruption, Life Tap.
- Shadow Shot is the filler and keeps Corruption up. Black Arrow raises all damage to the target and is used on
  cooldown; Dark Arrows makes it come back sooner.
- Blood Arrow keeps a drain running for damage and healing.
- Area: Death and Decay, Wave of Despair, Shadow Artillery, in that order for a pull.
- Mana: Life Tap; S1 also mentions Evocation and Dispersion as options.
- S1 favours critical strike, and names Impending Doom, Shadow Infusion and Grasp of Darkness as strong extras.

## 4. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Auto Shot, Shadow Shot, Black Arrow, Blood Arrow, Corruption, Wave of Despair, Shadow Artillery, Death and Decay, Life Tap, Blood Presence | S1 |
| Talents | Dark Arrows, Growing Corruption, Improved Blood Presence, Unending Fury, Enhanced Weapon Mastery | S1 |
| Look-fors | Shadow Infusion, Impending Doom, Grasp of Darkness, Necromancer's Touch with Enslave Demon | S1 |

Stats: ranged attack power and spell power (both scale), critical strike.

## 5. The decision list

| # | When | Do | Source |
|---|---|---|---|
| N1 | Blood Presence missing | Blood Presence | S1 |
| C1 | Three or more enemies near the target **and** Death and Decay is ready | Death and Decay on them | S1 |
| C2 | Three or more enemies near the target | Wave of Despair | S1 |
| C3 | Three or more enemies near the target **and** a Shadow Artillery charge is ready | Shadow Artillery | S1 |
| C4 | Black Arrow is ready | Black Arrow | S1 |
| C5 | Target lacks my Blood Arrow | Blood Arrow | S1 |
| C6 | Target lacks my Corruption **and** Shadow Shot is not ready | Corruption | S1 |
| C7 | No Dark Arrows on me | Wave of Despair (one target is fine) to start Dark Arrows | guess from S1's talent text |
| C8 | Otherwise | Shadow Shot | S1 |
| C9 | Mana below 30% **and** health above 50% | Life Tap | S1 |

## 6. Open points

| Point | How to settle it |
|---|---|
| Shadow Shot works when learnt as a talent, though its scroll is broken | In-game test on a GM character (James) |
| Whether bots should use Wave of Despair on one target to start Dark Arrows (C7) | James's call, or a damage test |
| Pet choice (S1 mentions Enslave Demon with Necromancer's Touch) | Leave out at first; bots manage pets poorly |
