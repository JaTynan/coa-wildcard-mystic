# Mystic Enchant restoration

The plan, the method and the progress log for restoring broken Mystic Enchants on the Wildcard realm.
The per-enchant tracker is [`enchants/tracker.csv`](../enchants/tracker.csv); GitHub shows it as a searchable table.

## Where we stand

| Date | Restored (live) | Tested | Broken left | Missing |
| --- | --- | --- | --- | --- |
| 2026-10-31 | 164, +16 at the next restart, +211 with the next build | 4 (plus the tooltip fix) | 399 (+113 partly working) | 1,206 |

Out of 6,440 enchants offered on the realm, the audit found 4,331 that should work, 903 that need code
(882 placeholders plus 21 unsupported effects) and 1,206 whose spell is missing from the game data.

## How a fix reaches the server

1. Fixes are SQL files in [`sql/enchants/`](../sql/enchants), run in name order. No rebuild is needed.
2. `Start-Server.cmd` and patch night download them from GitHub and apply them to the active realm's world
   database just before the world server starts (`Applied enchant fix ...` lines in `patch-night.log`).
3. `000-reset.sql` first removes every row the repo added (spell_linked_spell rows marked `WCME:`, and
   spell_dbc / spell_proc rows listed in `wcme_owned`). So the database always matches the repo: delete a
   file and its fix is gone at the next start. One-off backups of the original tables are kept as `wcme_backup_*`.
4. Tooltip fixes ship in the WildcardEnchants addon, which patch night copies to the client folder for coa-sync.

Workflow per batch: pick a batch from the tracker, write the SQL, run it twice on a scratch database, open a
pull request, merge, stop the server, run `Start-Server.cmd`, test in game, update the tracker.

## Testing a batch

[`enchants/test-checklist.csv`](../enchants/test-checklist.csv) lists every fix not yet tested, with the commands
and what should happen. Fill in the `result` column (pass, fail and what happened), then copy results to the
tracker. Quick types first: `twin` and `teach` take seconds each (`.aura`, then `.list auras` or the spellbook).

## Proven recipes

| Recipe | Used for | How |
| --- | --- | --- |
| Twin that teaches | 95 enchants (file 006, needs the build) | Our enchant teaches the spell its twin teaches, through `wcme_enchant_teach`. |
| Working namesake | 74 enchants (file 008, needs the build) | An enchant that teaches a broken spell, or transforms an ability, teaches a working spell of the same name instead (a transform adds the ability rather than replacing). |
| Action table | 42 enchants (file 007 part 1, needs the build) | `spell_wcme_enchant_action` (patch `mystic-enchants-actions`): on a proc the enchant casts a helper spell, or cuts or resets a cooldown, with spell, target-aura and player-aura conditions, read from `wcme_enchant_action`. |
| Aura link | 17 enchants (file 007 part 2, works now) | "While X is on you, you also have Y" through the core's `coa_mystic_enchant_aura_link`. |
| Working twin | 143 enchants (files 001, 003, 004, 005) | Many broken enchants have a twin: the same enchant made for another realm type, which works. `spell_linked_spell` type 2 puts the twin's aura on while ours is on. Where the twin's text differs, the addon (1.9) shows the twin's tooltip. When both spells carry the same real effect, ours becomes a placeholder in `spell_dbc` first (file 004), so the bonus is not doubled. A twin with a proc aura but no proc settings gets a `spell_proc` row read from its tooltip (file 005). |
| School pair | 21 enchants (file 002) | "Damaging school A raises school B, and B raises A". The enchant's placeholder becomes a proc aura (`spell_dbc`) for one half; the existing 2861xx proc spell covers the other half (linked); `spell_proc` rows say when each fires. |

## Lessons

- 113 "broken" enchants also carry a real effect (for example the threat reducers), so they already do part of
  their job and stay in the rolls. The tracker marks them `partly working`.

- A twin can look working and never fire: a proc aura with no proc flags and no `spell_proc` row does nothing.
  The twin search now skips these.
- When both spells carry the same real effect, remove ours first, or the player gets the bonus twice.
- Enchant tooltips show the granted buff below the description: the description is the first line under the name.
- The "modifier" family (about 300) is mostly event logic ("when X, reduce Y's cooldown"), not simple
  percentage changes. There is no cheap scripted fix for it.
- Taught spells are read from the client's Spell.dbc, not from `spell_dbc`, so SQL alone cannot add a "teaches".
  The patched server reads extra ones from `wcme_enchant_teach` (file 006: 95 enchants whose twin teaches a spell).
- Triggered spells (Living Bomb's explosion, Fire Nova's damage, Hellfire's ticks) only set off a proc when the
  `spell_proc` row allows it (`AttributesMask` 2).
- `wcme_enchant_override` (enchant_spell, roll) forces an enchant into (1) or out of (0) the scroll rolls. Use it for
  the 36 enchants handled by C++ that the dud filter cannot see, once spot-checked, and for any found broken.

## Testing in game (GM character, target yourself)

| Command | Use |
| --- | --- |
| `.aura <enchant spell>` | Puts the enchant on you without a scroll |
| `.list auras` | Lists your auras: a linked twin shows up here |
| `.unaura <spell>` | Removes it again |
| `.learn <spell>` | Gives an ability to trigger the enchant |
| `.lookup spell id <spell>` | Prints a clickable spell link, to check the tooltip |
| `.additem <scroll item>` | The full path: the scroll item ids are in the tracker |

A fix passes when it does what its tooltip says. Write the result and date in the tracker's `tested` column.

## Next candidates

| Group | Count | What it needs |
| --- | --- | --- |
| Twin that never fires | 7 left | Need a condition on the target (proc table `target_aura`), a stance change (C++), or the twin does something else entirely |
| Placeholder families | about 650 | Per family, read the tooltips and write proc rules or C++ |
| Missing spells | 1,206 | Research first: no spell and no scroll item in our data |

## Tools

- [`enchants/enchant_audit.py`](../enchants/enchant_audit.py): sorts every enchant into working, broken or missing.
- [`enchants/export_spell_data.py`](../enchants/export_spell_data.py): exports the spell data needed to write
  fixes from the client's Spell.dbc into one small file.

Use at your own risk; shared as is, without support.

## To do (in order)

1. **Fast build loop on trundle.** Keep a build of the core on trundle (Ubuntu, native, no VM) and only
   recompile what changed, so a C++ change to the test server takes minutes instead of a 3-hour GitHub build.
   GitHub then builds Windows once per batch for the live server. Worth checking at the same time: a compiler
   cache in the GitHub workflow, to shorten the Windows build too.
2. **Client patch check** (first step of the [Death Knight proposal](dk-enchant-proposal.md)): does the CoA
   client load an extra patch file? Another CoA community server ships its own patch files for custom races,
   so it seems possible; their notes warn that the launcher may skip patch files with names it does not know.
   Check which patch names the client folder already has, then whether one of ours loads.
3. **Map the Legendary enchants to Death Knight builds.** On Ascension each build centres on one Legendary.
   Candidates to check first: White Walker (two-handed Frost and blade), Vampire Lord (Shadow damage over time
   into healing), Unbounded Deathbringer (not yet checked). White Walker and Vampire Lord are on the broken list.
4. **A full Death Knight set.** Death Knight has no enchants tagged for it (Warrior has 121 on this realm).
   Aim for about 120, Warrior's rarity split, half pure Death Knight and half hybrid. Start from the nine pure
   ones drafted in the proposal, plus two themes:
    - **Plaguebearer:** Death Knight diseases with Warlock damage over time (Corruption, Curse of Agony) and
      Shadow damage generally.
    - **Necromancer:** undead pets (Ghoul, Gargoyle, Army of the Dead) with Warlock demons.
5. **Damage-type transforms** (for example Frost Strike dealing Shadow damage). These need C++: one general
   hook ("this ability deals this school while the enchant is active") so each enchant is a table row. The
   broken pet "Companion" enchants (Fire, Frost, Arcane, Nature, Shadow pet attacks) would use it too.
6. **Race kits: a full racial rework, based on WoW Forever's (optional).** Replace each race's racials with a
   kit that changes how you play, not stat reskins. Aimed at Wildcard, where a random start leaves little sense
   of identity: race becomes the fixed part of a character. A config switch, set per realm through the
   settings kit, so other realms keep the stock racials. Design first, one kit per playable race (WoW Forever's
   kits as the starting point, including the ones for races it does not have), then one build. Pieces:
    - Passive bonuses (for example Tauren Endurance: health plus a second stat) from a `race -> spell` table,
      with the stock racials removed while the switch is on. Reuse client-known spells where possible, so the
      spellbook shows a proper tooltip.
    - Gathering bonuses (for example Tauren Cultivation: bonus herbs): one C++ hook on gathering loot, driven by
      a `race, skill, chance` table.
    - Movement that builds while you keep moving (Tauren Plainsrunning): one C++ hook adding a stacking speed
      aura while moving out of combat.
    - Active abilities that change (WoW Forever reworks some, such as Gnome Eureka!): reuse or adapt
      client-known spells; brand-new ones need the client patch from item 2.
