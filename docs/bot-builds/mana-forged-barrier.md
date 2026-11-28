# Bot build: Mana-forged Barrier, Mystic Knight (tank)

Status: draft, 28 Nov 2026. A Wildcard showcase tank (James, 28 Nov: an arcane barrier tank "to help show off the
Wildcard server possibilities"). Format and rules as in `plague-caster.md`. Nothing here is live. Matches the bot
module's named build **Mystic Knight**.

Role: tank. A spellsword in plate whose mana is its health bar: an arcane barrier soaks physical hits by draining mana,
and its weapon refills that mana on every melee ability.

**Source note: built from game data, not a guide.** No guide video was found (only long levelling streams). The build
comes from the Season 10 client's own Hero Archetype "Mystic Knight" and our client spell data. The order of the
decision list is not settled by either, so most lines are marked **guess**.

## 1. Sources

| # | Source | Weight |
|---|---|---|
| S1 | Season 10 Hero Archetype "Mystic Knight", as recorded in the bot module's pick table (`CoaWildcardPicks.cpp`): Mana-forged Barrier, Eldritch Wrath, Deconstruct, Eldritch Weapon | Which abilities make the build |
| S2 | Our client spell data, read 28 Nov | What each ability does |
| S3 | The "Templar of Flame" archetype also uses Mana-forged Barrier, with Invocation (a damage-reduction channel that fires high-threat mana bolts) | A second, fire-flavoured variant |

## 2. How the build works (from S2)

- **Mana-forged Barrier** (tank stance): physical damage is absorbed by the shield and drains mana instead of health;
  threat is greatly increased; it teaches **Channeled Mana**, the single-target taunt.
- **Eldritch Weapon**: more threat, and every melee ability sends out a wave of high-threat arcane damage that
  **restores missing mana**. This is what keeps the barrier fed.
- **Eldritch Wrath**: an arcane burst around the knight that also lowers enemies' attack power (the raid's attack power
  reduction; it uses Holy Wrath modifiers).
- **Deconstruct** (replaces Devastate through Deconstruction): applies Sunder Armor (the raid's major armour debuff) with
  arcane weapon damage, and grants a Deconstruction buff for one second per Sunder stack on the target.
- **Eldritch Knight**: melee damage with Eldritch Weapon active, or casting Eldritch Wrath, grants a further buff.

## 3. The build itself

| Part | Abilities and talents | Source |
|---|---|---|
| Core | Mana-forged Barrier, Eldritch Weapon, Eldritch Wrath, Deconstruct (Devastate with Deconstruction), Channeled Mana | S1, S2 |
| Talents | Eldritch Knight, Deconstruction | S2 |
| Variant | Invocation (Templar of Flame archetype) as a defensive channel | S3 |
| Rolled extras | Shield Wall or another physical cooldown; a magic-damage defensive (the barrier only stops physical damage) | **guess** |

Stats: intellect and mana (the barrier's real health), stamina, armour, spell power and attack power (Eldritch Wrath
scales with both). A one-hand weapon and shield, or two-hander (Deconstruct does less with a two-hander).

## 4. The decision list (from S2; order is a **guess**)

### Out of combat

| # | When | Do | Source |
|---|---|---|---|
| N1 | Mana-forged Barrier stance not active | Mana-forged Barrier | S1 |
| N2 | Eldritch Weapon not on my weapon | Eldritch Weapon | S1 |

### In combat

| # | When | Do | Source |
|---|---|---|---|
| T1 | An enemy in the group is not attacking me | Channeled Mana on it | S2 |
| T2 | Barrier not up | Mana-forged Barrier | S1 |
| T3 | Low mana **and** a melee ability is ready | That ability first (Eldritch Weapon refills mana) | S2 |
| T4 | Eldritch Wrath is ready | Eldritch Wrath | S1 (also the attack power reduction) |
| T5 | Fewer than five Sunder stacks on the target | Deconstruct | S1 |
| T6 | Health critical **and** Invocation is ready, if rolled | Invocation | S3 |
| T7 | Always | Deconstruct | S1 |

## 5. Open points

| Point | How to settle it |
|---|---|
| Mana as health: a bot must not spend mana it needs for the barrier | Check that the bot's spell costs leave enough mana; a "keep mana above X" condition may be needed |
| Magic-heavy bosses | The barrier stops only physical damage; pair it with a strong healer or keep it for physical fights |
