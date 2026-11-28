# Bot build: Metamorphosis Tank, Demoniac (tank)

Status: draft, 28 Nov 2026. A Wildcard showcase tank (James, 28 Nov: "to help show off the Wildcard server
possibilities"). Format and rules as in `plague-caster.md`. Nothing here is live. Matches the bot module's named build
**Demoniac**.

Role: tank. A warlock who turns into a demon to tank: dual-wields (no shield), cannot be interrupted, shares damage
with a demon pet through Soul Link, and burns everything nearby with Immolation Aura.

**Source note: built from game data, not a guide.** No guide video was found (only long levelling streams). The build
comes from the Season 10 client's own Hero Archetype "Demoniac" (its character-creation preset) and our client spell
data, which describe every piece below. The order of the decision list is not settled by either, so most lines are
marked **guess**. This is the design James asked for, not a copy of a player's build.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Season 10 Hero Archetype "Demoniac", as recorded in the bot module's pick table (`CoaWildcardPicks.cpp`, which cites the client's CharacterCreationArchetypes data): Dark Apotheosis, Incinerate, and the Enslave Demon and Soul Link pair | Which abilities make the build |
| S2 | Our client spell data, read 28 Nov | What each ability does |

## 2. How the build works (from S2)

- **Dark Apotheosis**: an improved tanking Metamorphosis. More maximum health, much more armour from cloth, greatly
  increased threat; it cannot be interrupted and ignores pushback; it cannot use a shield and gives extra bonuses while
  **dual-wielding**. It teaches **Challenging Howl** (taunts every enemy nearby) and **Demon Claws** (strike twice).
- **Immolation Aura**: fire damage to every enemy nearby; the demon version also lowers their attack power (the raid's
  attack power reduction). Dark Apotheosis shortens its cooldown and, while it is up, adds immunity to silence and a
  bigger Soul Link share.
- **Soul Link** passes part of the damage taken to the demon pet (Voidwalker, Felguard or an enslaved demon).
  **Demon Spikes** adds armour from intellect and stamina, makes Soul Link stronger and halves what the demon takes.
- **Shadow Cleave** (demon) and **Incinerate** for threat on several targets and one target.
- **Demonic Leap** to reach adds; **Nemesis** shortens Metamorphosis-family cooldowns.
- **Demonic Aegis** raises Demon Skin and Fel Armor and the cloth armour bonus in Dark Apotheosis.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Dark Apotheosis, Immolation Aura, Demon Claws, Challenging Howl, Shadow Cleave, Incinerate, Soul Link, Summon Voidwalker or Felguard (or Enslave Demon) | S1, S2 |
| Defensive | Demon Spikes, Demonic Aegis, Fel Armor or Demon Skin | S2 |
| Mobility | Demonic Leap, Nemesis | S2 |
| Rolled extras | Dual-wield talents, crit and threat talents | **guess** |

Stats: stamina, intellect (Demon Spikes), armour on cloth (Dark Apotheosis multiplies cloth armour), spell power for the
fire and shadow damage. Two one-hand weapons.

## 4. The decision list (from S2; order is a **guess**)

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | My demon is not out | Summon Voidwalker or Felguard | S1 |
| N2 | Soul Link is not active | Soul Link | S1 |
| N3 | Fel Armor (or Demon Skin) missing | Cast it | S2 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| T1 | Not in Dark Apotheosis | Dark Apotheosis | S1 |
| T2 | Three or more enemies not attacking me **and** Challenging Howl is ready | Challenging Howl | S2 |
| T3 | Target far away | Demonic Leap | S2 |
| T4 | Immolation Aura is not on me **and** it is ready | Immolation Aura | S2 (also the attack power reduction) |
| T5 | Demon Spikes is not on me **and** it is ready | Demon Spikes | S2 |
| T6 | Two or more enemies near me **and** Shadow Cleave is ready | Shadow Cleave | S2 |
| T7 | Demon Claws is ready | Demon Claws | S2 |
| T8 | Always | Incinerate | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Single-target taunt | Dark Apotheosis teaches only the group taunt; check whether a tank stance grants one (Channeled Mana is taught by tank stances) |
| Can a bot keep its demon alive and Soul Linked? | The bot module's pet handling for Heroes |
| A real player's version | Ask James's friends, or a later Season 10 guide |
