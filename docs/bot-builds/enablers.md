# Bot builds: the talents and enchants each build depends on

Status: draft, 28 Nov 2026. Covers all 37 drafted builds (27 in `raid-coverage.md`, 10 new in `faction-rosters.md`).

Many Wildcard builds only exist because of one or two talents or Mystic Enchants: without Blooming Growth there is no
Blooming Growth healer, without Divine Concord no Arcane Paladin. This page lists those **enablers** for every build
and says whether each one works on our server today, so we know which builds a bot can actually play.

## 1. How the status was worked out

For each enabler name, our client spell data gives the spell a character learns from the talent list
(`CharacterAdvancement.dbc`); where there is no talent entry, the Mystic Enchant of that name. That spell id was
then looked up in `enchants/tracker.csv`, and in the SQL and patches on `main` (the tracker lags behind merged
fixes, as `ascension-restoration` notes).

| Status | Meaning |
|---|---|
| working (audit) | The October audit says the spell data alone should make it work. **Not tested in game.** |
| live | A fix is live (tracker). Not tested unless marked verified. |
| fix live, untested | The tracker still says broken, but a fix for that exact spell id is merged on `main` (enchant batches 4 to 7, 16-18 Nov). |
| **broken** | Broken, and no fix exists on `main`. |
| not tracked | A Wildcard talent that is not offered as a Mystic Enchant, so the audit never looked at it. Whether it works depends on the core's own scripts. Unknown until tested. |
| not tracked, scroll broken | As above, and the enchant scroll of the same name is broken because the scroll fails to **teach** the ability. That is a fault in the scroll, not proof the ability is broken; bots learn it from the talent list, not a scroll. |
| (enchant) | No talent entry: the effect exists only as a Mystic Enchant. A bot needs that enchant slotted (section 4). |
| no talent entry found | The name exists in spell data only as helper spells; the talent may be listed under another name. To check. |

Classic (stock) talents and abilities are left out of the table: they come with the core and work.

## 2. Every build

| Build | Wildcard enablers and status | Verdict |
|---|---|---|
| Plague Caster | Harbinger of Plague: working (audit); Wrath of the Plague: working (audit); Natural Selection: not tracked; Devour Mind: not tracked; Plague Swarm: not tracked, scroll broken | Test in game |
| Soul Fire | Destructive Bargain: not tracked; Gul'dan's Chosen: working (audit); Big Flaming Grimfire: working (audit) | Test in game |
| Immolate and Conflagrate | Infinite Burn: working (audit); Controlled Burn: working (audit); Elemental Destruction: working (audit); Midnight Flames: working (audit) | Nothing known broken |
| Pyroblast Fire Mage | Hot Hands: fix live, untested; Scorched Earth: not tracked | Fix live, untested |
| Elemental Lord | Elemental Lord: fix live, untested; Elemental Domination: working (audit); Booming Thunder: working (audit); Elemental Blast: not tracked | Fix live, untested |
| Arcane Paladin | Arcanesworn (no talent entry found); Arcane Divinity (no talent entry found); Divine Concord: **broken**; Arcane Crusade (no talent entry found); Seal of Arcane Wrath: not tracked, scroll broken | **Blocked** |
| Cryomancer | Frost Bomb: not tracked | Test in game |
| Total Eclipse | classic abilities only | Nothing known broken |
| Winds of Winter | Winds of Winter: not tracked, scroll broken; Titanic Mutilate: not tracked | Test in game |
| Claw-sader | Light Swipe (Cat): not tracked; Dawnripper: not tracked; Consecrated Weapon: not tracked; Goldrinn's Fury: not tracked; Serpent Form: not tracked, scroll broken | Test in game |
| Shadow Melee | Corrupted Maelstrom Weapon (no talent entry found); Felstorm: working (audit); Double Down: working (audit); Master of Shadows: working (audit); Dark Intent: not tracked; Pure Chaos Bolt: not tracked | Test in game |
| Titan's Grip Crush | Heavyweight: working (audit); Prepared to Crush! (no talent entry found); Titan's Fury: working (audit); Gurubashi Berserker (enchant): working (audit) | Test in game |
| Lightning Warrior | Lightning Blade: not tracked; Thunder Slam: not tracked; Assault and Battery (no talent entry found); Crackling Thunder: working (audit) | Test in game |
| Frost Death Knight | classic abilities only | Nothing known broken |
| Arcane Gunslinger | Arcane Gunslinger: working (audit); Barrage Overload: working (audit); Lunar Marksmanship: live; Lunar Synergy: working (audit); Arcane Shelling: working (audit); Shot Weaving: working (audit) | Nothing known broken |
| Ninja | Master of Kunai: working (audit); Toss and Throw: working (audit); Critical Serration: working (audit); Clean Pass: not tracked; Unseen Assassin: not tracked; Shuriken Toss: not tracked; Glaive Toss: not tracked | Test in game |
| Holy Radiance | Holy Radiance: working (audit); Good Fortune: working (audit); Faithful Light: working (audit) | Nothing known broken |
| Tide Chain Healer | Tree of Wrath: not tracked; Living Lightning: not tracked; Lightning Rod: working (audit); Charged Tides: not tracked; Mending Tide: working (audit); Low Tide: working (audit); Overflow: live | Test in game |
| Prayer of Preservation | Prayer of Preservation: not tracked; Preservation: **broken**; Preserving Light (no talent entry found); Recovering Prayer (no talent entry found); Growing Light: fix live, untested; Blessing of the Divines: not tracked; Oracle of the Eclipse: not tracked; Holy Supernova: not tracked | **Blocked** |
| Vampire Lord | Vampire Lord: working (audit); Beacon of Shadow: not tracked, scroll broken; Vampirism: fix live, untested | Fix live, untested |
| Cryotherapist | Cryotherapist: working (audit); Icy Penance: not tracked | Test in game |
| Seed of Life | classic abilities only | Nothing known broken |
| Shadow Bear | Maledictive Assault: working (audit); Nightmare Mauling: working (audit); Savage Defense: not tracked; Corrupted Bear Form: working (audit) | Test in game |
| Holy Spell Tank | Emanating Light: not tracked, scroll broken; Crimson Champion: not tracked | Test in game |
| Earthen Guardian | Earthen Guardian: not tracked; Stone Shield (no talent entry found); Totemic Bond: not tracked; Cataclysmic Sundering: not tracked; Primal Strike (no talent entry found) | Test in game |
| Metamorphosis Tank | Dark Apotheosis: not tracked; Immolation Aura: not tracked; Demon Spikes: not tracked | Test in game |
| Mana-forged Barrier | Mana-forged Barrier: not tracked; Eldritch Weapon: not tracked; Eldritch Wrath: not tracked; Deconstruction: not tracked | Test in game |
| Dark Ranger | Shadow Shot: not tracked, scroll broken; Blood Arrow: not tracked; Shadow Artillery: not tracked; Wave of Despair: not tracked; Dark Arrows: not tracked; Growing Corruption: working (audit); Necromancer's Touch: fix live, untested | Fix live, untested |
| Beast Master | Unrelenting Wrath: not tracked; Fetch Me Their Bones!: working (audit); Hunting Frenzy (enchant): working (audit); Bestial Assault: fix live, untested; Frenzy Shot: not tracked | Fix live, untested |
| Enhancement | Stormborn: working (audit); Pack Alpha: live; Swirling Maelstrom (enchant): working (audit) | Nothing known broken |
| Blooming Growth | Blooming Growth: working (audit); Seed of Life: working (audit); Restoration Mastery (enchant): working (audit) | Nothing known broken |
| Discipline | Atonement: working (audit); Dominant Word: Shield: working (audit); Holy Spirit: working (audit) | Nothing known broken |
| Protection Warrior | Enduring Aegis (enchant): working (audit); Shield Finesse: working (audit); Sword and Thunder: working (audit) | Nothing known broken |
| Holy Paladin | Glimmer of Light: working (audit); Synergetic Light: working (audit); Adorned by Light (enchant): live; Growing Light: fix live, untested | Fix live, untested |
| Restoration Shaman | Low Tide: working (audit); Mending Tide: working (audit); Transcendental Embrace: working (audit); Restoration Mastery (enchant): working (audit) | Nothing known broken |
| Retribution | Consecrated Strikes (enchant): working (audit); One With The Light: working (audit); Holy Templar (enchant): working (audit) | Needs bot enchants |
| Arcane Mage | Evoker: live; Power Overwhelming: not tracked; Arcane Motes: working (audit); Spellstorm: fix live, untested | Fix live, untested |

"Nothing known broken" is not the same as tested: almost every Wildcard enabler is either "working (audit)" or
"not tracked". Only the bots' first runs, or GM tests, will prove them.

## 3. The two blocked builds

| Build | Blocking talent | Spell | Where it is in the rosters | Stand-in until fixed |
|---|---|---|---|---|
| Arcane Paladin | Divine Concord | 277860 (Epic enchant, needs code, no fix) | Horde caster | Arcane Mage (Blood Elf), shared with the Alliance |
| Prayer of Preservation | Preservation | 276273 (Epic enchant, needs code, no fix) | Healer on both sides (Alliance home, Horde shared) | Horde: Restoration Shaman (Tauren), shared. Alliance: Blooming Growth (Night Elf), shared |

Both are Epic enchants with the talent and the enchant on the same spell id, so fixing the enchant fixes the talent.
Under James's priorities enchant work comes after the lag and pipeline work.

Eight builds lean on a fix that is merged but untested: Pyroblast (Hot Hands), Elemental Lord (Elemental Lord),
Vampire Lord (Vampirism), Holy Paladin and Prayer of Preservation (Growing Light), Dark Ranger (Necromancer's Touch,
optional), Beast Master (Bestial Assault, optional), Arcane Mage (Spellstorm, optional). A GM test of those spells
would clear them.

## 4. Bot need: Mystic Enchants for Wildcard Hero bots

Eight enablers exist only as Mystic Enchants: Hunting Frenzy (Beast Master), Swirling Maelstrom (Enhancement),
Restoration Mastery (Blooming Growth, Restoration Shaman), Enduring Aegis (Protection Warrior), Adorned by Light (Holy
Paladin), Gurubashi Berserker (Titan's Grip Crush), and Holy Templar plus Consecrated Strikes (Retribution).

Today the bot module slots Mystic Enchants only for Warcraft Reborn class bots (classes 12 and up): `CoaReborn.cpp`
reads `playerbots_coa_wcr_enchants` and calls the core's `AscensionMysticEnchant::ApplyGuide`. Wildcard Hero bots
(class 10) get none. All builds but Retribution still work without their enchant (it is a bonus). Retribution's
Holy Power version needs Holy Templar; until bots get enchants it plays classic retribution.

Proposed bot change (after the lag work, with the other rotation C++): a per-build enchant list for class 10 bots,
applied through the same `ApplyGuide` call. Whether `ApplyGuide` works on the Wildcard realm as it does on Reborn is
to check.

## 5. Open points

| Point | How to settle it |
|---|---|
| Fix Divine Concord and Preservation, or use the stand-ins | James |
| GM tests of the "not tracked" abilities the new builds rest on (Shadow Shot, Unrelenting Wrath, Frenzy Shot) | James, on his GM character |
| The "no talent entry found" names | Search the talent list by spell id from the build sources |
