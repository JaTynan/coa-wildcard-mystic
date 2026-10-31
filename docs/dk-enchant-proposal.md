# Death Knight Mystic Enchants: proposal

Twenty new Death Knight enchants for the Wildcard realm: 7 Uncommon, 7 Rare, 6 Epic. Most tie Death Knight
abilities to another class's procs, because a Wildcard character mixes classes.

**What already exists.** The game data already has about 100 Death Knight themed enchants on this realm: the
Death Knight glyphs, and a set like Black Ice Arsenal, Crimson Ward, Rimebound Shadow and Sindragosa's Ire.
About 73 should work (63 standard effects, 7 teach a working spell, 3 scripted). With `Wildcard.AbilityPool =
"classic"`, Death Knight abilities roll, so these become useful. The 20 below fill gaps, mainly cross-class
synergy, which the existing set hardly has.

**How they would be built.** Each one uses the enchant action handler (`wcme_enchant_action`) or an aura link,
and fires spells the client already knows (Killing Machine, Fingers of Frost, The Art of War and so on). So
the effects need no new client spells. The enchants themselves do: see "What it takes" at the end.

Numbers are first guesses for testing, not tuned.

## Uncommon

| Name | Tooltip | Synergy | Built with |
| --- | --- | --- | --- |
| Hoarfrost Rime | Icy Touch has a 15% chance to grant Freezing Fog, making your next Howling Blast free. | Death Knight | Icy Touch hit, 15%: cast Freezing Fog (59052) on self |
| Grave Shackles | Chains of Ice also infects the target with Frost Fever. | Death Knight | Chains of Ice hit: cast Frost Fever (55095) on target |
| Plaguefang | Plague Strike also coats the target in Deadly Poison. | Rogue | Plague Strike hit: cast Deadly Poison IX (57970) on target |
| Rimebite | Frost Strike applies Winter's Chill, raising the critical strike chance of Frost spells against the target. | Mage | Frost Strike hit: cast Winter's Chill (12579) on target |
| Blood Price | Heart Strike and Blood Strike grant Taste for Blood, allowing Overpower. | Warrior | Heart Strike or Blood Strike hit: cast Taste for Blood (60503) on self |
| Crypt Dust | Death and Decay damage has a 10% chance to grant Shadow Trance, making your next Shadow Bolt instant. | Warlock | Death and Decay tick, 10%: cast Shadow Trance (17941) on self |
| Grim Vigil | Death Coil also afflicts enemies with Shadow Word: Pain. | Priest | Death Coil hit: cast Shadow Word: Pain (48125) on target |

## Rare

| Name | Tooltip | Synergy | Built with |
| --- | --- | --- | --- |
| Frozen Covenant | Frost Fever damage has a 5% chance to grant Fingers of Frost. | Mage | Frost Fever tick, 5%: cast Fingers of Frost (44544) on self |
| Obliterating Insight | Obliterate critical strikes grant Fireball!, making your next Fireball or Frostfire Bolt instant and free. | Mage | Obliterate crit: cast Fireball! (57761) on self |
| Scourgeborn Backlash | Scourge Strike has a 15% chance to grant Backlash, making your next Shadow Bolt or Incinerate instant. | Warlock | Scourge Strike hit, 15%: cast Backlash (34936) on self |
| Crusader's Rime | Howling Blast critical strikes grant The Art of War, making your next Flash of Light or Exorcism instant. | Paladin | Howling Blast crit: cast The Art of War (59578) on self |
| Marrowguard | Dodging or parrying while Bone Shield is active reduces the cooldown of Vampiric Blood by 2 sec. | Death Knight (tank) | Dodge or parry taken, needs Bone Shield: cut Vampiric Blood by 2 sec |
| Wintertide Ritual | Casting Icy Veins or Unbreakable Armor grants Killing Machine. | Mage | Icy Veins or Unbreakable Armor cast: cast Killing Machine (51124) on self |
| Chillblood | Frost damage against a target with your Frost Fever reduces the cooldown of Howling Blast by 1 sec. Once per second. | Any Frost class | Frost-school hit, target has Frost Fever, 1 sec cooldown: cut Howling Blast by 1 sec |

## Epic

| Name | Tooltip | Synergy | Built with |
| --- | --- | --- | --- |
| Lich Lord's Bargain | Killing an enemy affected by your Frost Fever or Blood Plague resets the cooldown of Death Coil and Death and Decay. | Death Knight | Kill, target had a disease: reset both cooldowns (needs a "kill" event added to the handler) |
| Frostwyrm's Fury | Critical strikes with Frost spells reduce the remaining cooldown of Icy Veins and Hungering Cold by 1 sec. | Mage | Frost-school crit: cut both by 1 sec |
| Shadowstorm Pact | Shadow critical strikes reduce the cooldown of Summon Gargoyle by 2 sec and Shadowfury by 1 sec. | Warlock | Shadow-school crit: cut both |
| Fallen Crusader's Oath | Your melee abilities have a 15% chance to grant Unholy Strength, increasing Strength by 15% for 15 sec. | Any melee | Melee ability hit, 15%: cast Unholy Strength (53365) on self |
| Glacial Requiem | Casting Hungering Cold resets the cooldown of Frost Nova, Cone of Cold and Deep Freeze. | Mage | Hungering Cold cast: reset three cooldowns |
| Plague Doctor's Ritual | Frost Fever and Blood Plague damage has a 3% chance to grant Clearcasting, making your next spell free. | Any caster | Disease tick, 3%: cast Clearcasting (12536) on self |

## Pure Death Knight drafts

The 20 above are mostly hybrids. Every other class's enchants mostly boost that class's own abilities, so a full
set should be about half pure. A first nine, one per rarity for each specialisation:

| Spec | Rarity | Name | Tooltip |
| --- | --- | --- | --- |
| Blood | Uncommon | Sanguine Strikes | Heart Strike has a 20% chance to reduce the cooldown of Rune Tap by 5 sec. |
| Blood | Rare | Crimson Reprieve | Death Strike critical strikes reset the cooldown of Rune Tap. |
| Blood | Epic | Vampiric Bulwark | Casting Vampiric Blood also grants Bone Shield. |
| Frost | Uncommon | Bitter Frost | Icy Touch has a 10% chance to grant Killing Machine. |
| Frost | Rare | Endless Winter | Obliterate has a 20% chance to grant Freezing Fog, making your next Howling Blast free. |
| Frost | Epic | Frozen Heart | Frost Strike reduces the cooldown of Unbreakable Armor by 2 sec. |
| Unholy | Uncommon | Festering Touch | Plague Strike reduces the cooldown of Death and Decay by 2 sec. |
| Unholy | Rare | Doomcaller | Scourge Strike has a 10% chance to grant Sudden Doom, making your next Death Coil free. |
| Unholy | Epic | Gravelord's Command | Death Coil hits reduce the cooldown of Summon Gargoyle by 5 sec. |

## What it takes

0. **First step: check the CoA client loads an extra patch file** (see the to-do list in
   [enchant-restoration.md](enchant-restoration.md)). A pilot of two Uncommons (Grave Shackles and Blood Price)
   would then prove the whole path for brand-new enchants.
1. **Client data for the enchants themselves.** A new enchant needs a row in the client's MysticEnchant.dbc and
   a spell in its Spell.dbc (name, icon, tooltip). Without them the enchant window has nothing to show. That
   means a small client patch file shipped through coa-sync, plus the same rows on the server. To find out
   first: whether the CoA client loads an extra patch file.
2. **Two small handler additions:** a "kill" event (Lich Lord's Bargain) and "dodge or parry taken" (Marrowguard).
3. **Then data only:** one `wcme_enchant_action` row per effect, as with batch 7.
4. **Testing** as for any batch, with the checklist.

A cheaper first step, with no client work: check the existing Death Knight enchants are working, from the
tracker, once Death Knight abilities roll.
