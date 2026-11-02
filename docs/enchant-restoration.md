# Mystic Enchant restoration

The plan, the method and the progress log for restoring broken Mystic Enchants on the Wildcard realm.
The per-enchant tracker is [`enchants/tracker.csv`](../enchants/tracker.csv); GitHub shows it as a searchable table.

## Where we stand

| Date | Restored (live) | Tested | Broken left | Missing |
| --- | --- | --- | --- | --- |
| 2026-10-31 | 164, +16 at the next restart, +211 with the next build | 4 (plus the tooltip fix) | 399 (+113 partly working) | 1,206 |
| 2026-11-01 | same +1 with the next build, plus 1,195 rebuilt missing enchants (337 of them need the next build), held out of rolls until the client has their spells | 4 (plus the tooltip fix) | 398 (+112 partly working) | 11 |

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
| Rebuilt missing spell | 1,195 enchants (files 009 and 011, held out of rolls by 010) | The enchant's spell was missing, so a new passive spell is built in `spell_dbc` from the archived Ascension description (Area-52 builder page): one aura that changes the named spell or school by the stated amount (cost, cooldown, cast time, damage, crit, hit, dispel resistance, scaling). 858 pick out their target by a spell flag that at most three other spells share (009, works now). 337 targets share their flag widely, so those spells carry no flag and name their targets in `wcme_spellaffect_dbc` (011), which patch `mystic-enchants-spellaffect-sql` loads into the server's SpellAffect data (needs the build). The client gets these spells from `patch-ZZW.MPQ` (below), so they are in the rolls. |
| Placeholder to modifier | 1 enchant (file 012, needs the build) | A broken enchant whose tooltip is a plain modifier gets its spell copied into `spell_dbc` with the modifier where the placeholder was; name and tooltip stay, so the client shows the right text. Few fit: most such tooltips are already working, and 2 enchant IDs turned out to be reused by unrelated spells in our data (skipped). |
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

What is left on the Area-52 list (3,822 enchants) after the files above, and the one piece of code that would unlock each group.
Counts are for the whole realm list, with the Area-52 part in brackets.

| Group | Count | What it needs |
| --- | --- | --- |
| Extra damage under a condition: against targets with one of your auras, above or below a health mark, while stealthed or in a form | 32 (18) | One generic C++ handler: a table of (enchant, spells or school, condition, percent) applied in the damage hooks (`ModifySpellDamageTaken`, `ModifyPeriodicDamageAurasTick`, `ModifyMeleeDamage`) |
| Melee auto attacks deal extra damage as a school (the forged weapons) | 6 (6) | The same handler, with an "auto attack, add N% as school X" rule |
| Cooldown cut or reset on an event the action table cannot see (an aura ending, a stance change) | about 20 (12) | New triggers for `spell_wcme_enchant_action` (aura removed, stance changed) |
| Teaches or transforms into an ability we do not have | 43 (32) | Client patch (new spells) or a namesake, case by case |
| Procs with a chance | 62 (24) | Action table rows, read by hand from each tooltip |
| Everything else | about 360 (94) | One-off C++, enchant by enchant; many of the non-Area-52 ones have tooltips made only of variables, so they need research first |
| Missing, not simple | 11 (11) | Read by hand |

Ten enchants marked partly working already carry the effect their tooltip names (the threat ones and Improved Mend Pet); they are on the checklist to confirm.

## Client patch

The game client reads two spell lists: `Data/area-52/patch-D.MPQ` only on Ascension's Area 52 realm, and
`Data/patch-T.MPQ` everywhere else, including this server. The 1,206 enchants whose spell was missing are only in
the Area 52 list. [`client-patch/build_client_patch.py`](../client-patch/build_client_patch.py) copies them into the
Wildcard list and packs it as `patch-ZZW.MPQ`, which sorts after `patch-T` and wins. Tested 2 Nov on trundle:
`GetSpellInfo(911367)` returns Critical Mass with its icon.

The archive is the client's own data, so it is never published here: build it from your own client files and copy
it into the client's `Data` folder (`F:\CoAClient\Data` on the VM, which friends sync from). The server side of the
same spells is files 009 and 011.

The Area 52 versions of most broken enchants are the same placeholders as ours (the behaviour lived in Ascension's
server code), so this does not restore the complex ones; about 15 do have a real effect there and are next.

## Tools

- [`enchants/enchant_audit.py`](../enchants/enchant_audit.py): sorts every enchant into working, broken or missing.
- [`enchants/export_spell_data.py`](../enchants/export_spell_data.py): exports the spell data needed to write
  fixes from the client's Spell.dbc into one small file.

Use at your own risk; shared as is, without support.

## To do

The server-wide plan and to-do list moved to [roadmap.md](roadmap.md).
