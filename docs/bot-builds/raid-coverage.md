# Raid coverage: buffs, debuffs and the 25-player slots

Status: draft, 28 Nov 2026. The checklist the named raid rosters are built against (`docs/bot-roster-plan.md`). One
roster per faction; both use the same slot plan with different builds and names.

Source: the old Discord build server's buff and debuff lists (2021), passed on by James 28 Nov. All 73 ability names
were checked against our client spell data (28 Nov): every one exists.

## 1. Why this matters for Wildcard bots

On Wildcard any build can carry any buff, so buffs are not tied to classes. Each named bot has 2-3 **rolled extras**
on top of its core build (`plague-caster.md`, section 3). Those extras are where the raid's buffs and debuffs go: the
roster assigns each one to a bot, so nothing is missing and nothing is doubled. The Plague Caster guide gives the same
advice to players: split the buffs across the raid to free ability space.

## 2. Raid buffs (one source each per raid)

| For | Category | Options (any one) |
|---|---|---|
| Everyone | Stats | Mark of the Wild; Blessing of Kings |
| Everyone | Stamina | Power Word: Fortitude |
| Everyone | Health | Commanding Shout or Blood Pact |
| Melee and hunters | Attack power | Battle Shout or Blessing of Might |
| Melee and hunters | Attack power % | Trueshot Aura or Unleashed Rage |
| Melee and hunters | Melee crit | Leader of the Pack or Rampage |
| Melee and hunters | Strength and agility | Strength of Earth Totem |
| Melee and hunters | Melee haste | Windfury Totem |
| Melee and hunters | Damage % | Sanctified Retribution or Ferocious Inspiration (or Arcane Empowerment) |
| Casters | Spell haste | Wrath of Air Totem |
| Casters | Spell power | Totem of Wrath or Flametongue Totem |
| Casters | Mana | Mana Spring Totem or Blessing of Wisdom |
| Casters | Intellect, spirit | Arcane Intellect; Divine Spirit |
| Casters | Spell crit | Moonkin Form or Elemental Oath |
| Casters | Pushback | Concentration Aura |
| Tanks | Armour | Devotion Aura; Stoneskin Totem |
| Tanks | Damage taken | Blessing of Sanctuary |

Totems and auras reach the **whole raid** on our server, within range of the totem or caster: checked 28 Nov in our
spell data (the totem buffs, Devotion Aura, Trueshot Aura and Leader of the Pack all use the raid-wide area aura) and in
the core, which applies that effect to everyone in the raid. So one carrier per totem is enough, as long as the raid
stands near it.

## 3. Debuffs on the boss (one source each)

| For | Category | Options (any one) |
|---|---|---|
| Casters | 5% spell crit taken | Improved Scorch, Improved Shadow Bolt or Winter's Chill |
| Casters | 3% crit taken | Totem of Wrath |
| Casters | Spell damage taken | Curse of the Elements, Earth and Moon or Unleashed Storm |
| Casters | Spell hit | Improved Faerie Fire or Misery |
| Melee | Major armour | Sunder Armor or Expose Armor |
| Melee | Minor armour | Faerie Fire or Curse of Weakness |
| Melee | Bleed damage | Mangle or Trauma |
| Melee | Physical damage taken | Blood Frenzy or Savage Combat |
| Melee | 3% crit taken | Master Poisoner or Heart of the Crusader |
| Hunters | Ranged attack power | Hunter's Mark |
| Tanks | Attack power reduction | Demoralizing Shout, Demoralizing Roar, Demoralizing Screech (vulture pet) or Vindication |
| Tanks | Attack speed slow | Thunder Clap, Infected Wounds or Riposte |

## 4. Personal buffs (each bot keeps its own up)

| Role | Options |
|---|---|
| Casters | Fel Armor, Molten Armor, Inner Fire; weapon: Flametongue, Spellstone, Firestone or Wizard Oil |
| Melee and hunters | Aspect of the Hawk or Beast; Battle or Berserker Stance; Windfury, Rockbiter or poisons |
| Healers | Demon Skin, Mage Armor, Inner Fire; Earthliving Weapon |
| Tanks | Aspect of the Monkey, Demon Skin, Frost Armor, Inner Fire, Defensive Stance or Bear Form, Barkskin; weapon as melee |

## 5. The 25-player slot plan (proposal)

| Role | Slots | Notes |
|---|---|---|
| Tanks | 3 | Two main tanks plus one for adds. At least one carries the tank debuffs (attack power reduction, attack speed slow). |
| Healers | 6 | Holy Radiance is one of them at most (its guide says it falls off past 10 players). |
| Casters | 8 | Carry the caster debuffs and caster buffs. |
| Melee | 6 | Carry the armour, bleed and physical debuffs. |
| Ranged physical | 2 | Hunter's Mark, Trueshot Aura. |

The battleground team (10) and the world PvP crew (5) come from the same rosters later; raid coverage does not apply
to them.

## 6. Covered so far

Drafted builds and what each carries in its core or as a natural rolled extra. "Assign" marks a buff that has no
natural carrier yet and is proposed as that bot's rolled extra.

| Build | Role | Carries |
|---|---|---|
| Plague Caster | Caster | Earth and Moon (spell damage taken), Mark of the Wild |
| Soul Fire | Caster | Blood Pact (imp); Totem of Wrath in its guide's group |
| Immolate and Conflagrate | Caster | Blood Pact (imp); Ignite |
| Pyroblast Fire Mage | Caster | Improved Scorch (5% spell crit taken), Arcane Intellect |
| Elemental Lord | Caster | Winter's Chill; **assign** Totem of Wrath |
| Arcane Paladin | Caster (melee range) | Judgement of Wisdom; **assign** Concentration Aura |
| Cryomancer | Caster | **assign** Divine Spirit |
| Moonkin Fire | Caster | Moonkin Form (spell crit), Wrath of Air Totem, Mana Spring Totem, Blessing of Kings, Improved Scorch; **assign** Improved Faerie Fire (spell hit) |
| Holy Radiance | Healer | Personal only |
| Shadow Bear | Tank | Mangle (bleed debuff); Demoralizing Roar if rolled |

Caster side after the eight casters: every caster debuff and caster buff on the checklist is covered, three of them by
assignment. Still open overall: the melee, hunter and tank buffs and debuffs, which
come with those slots.
