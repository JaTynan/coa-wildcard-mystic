# Mystic Enchant restoration

The plan, the method and the progress log for restoring broken Mystic Enchants on the Wildcard realm.
The per-enchant tracker is [`enchants/tracker.csv`](../enchants/tracker.csv); GitHub shows it as a searchable table.

## Where we stand

| Date | Restored (live) | Tested | Broken left | Missing |
| --- | --- | --- | --- | --- |
| 2026-10-31 | 164 | 3 (plus the tooltip fix) | 739 | 1,206 |

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

## Proven recipes

| Recipe | Used for | How |
| --- | --- | --- |
| Working twin | 143 enchants (files 001, 003, 004, 005) | Many broken enchants have a twin: the same enchant made for another realm type, which works. `spell_linked_spell` type 2 puts the twin's aura on while ours is on. Where the twin's text differs, the addon (1.9) shows the twin's tooltip. When both spells carry the same real effect, ours becomes a placeholder in `spell_dbc` first (file 004), so the bonus is not doubled. A twin with a proc aura but no proc settings gets a `spell_proc` row read from its tooltip (file 005). |
| School pair | 21 enchants (file 002) | "Damaging school A raises school B, and B raises A". The enchant's placeholder becomes a proc aura (`spell_dbc`) for one half; the existing 2861xx proc spell covers the other half (linked); `spell_proc` rows say when each fires. |

## Lessons

- A twin can look working and never fire: a proc aura with no proc flags and no `spell_proc` row does nothing.
  The twin search now skips these.
- When both spells carry the same real effect, remove ours first, or the player gets the bonus twice.
- Enchant tooltips show the granted buff below the description: the description is the first line under the name.
- The "modifier" family (about 300) is mostly event logic ("when X, reduce Y's cooldown"), not simple
  percentage changes. There is no cheap scripted fix for it.
- Taught spells are read from the client's Spell.dbc, not from `spell_dbc`, so SQL cannot add a "teaches".

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
| Twin that teaches a spell | about 95 | A small server change: a table of extra "teaches" for an enchant (one build) |
| Placeholder families | about 650 | Per family, read the tooltips and write proc rules or C++ |
| Missing spells | 1,206 | Research first: no spell and no scroll item in our data |

## Tools

- [`enchants/enchant_audit.py`](../enchants/enchant_audit.py): sorts every enchant into working, broken or missing.
- [`enchants/export_spell_data.py`](../enchants/export_spell_data.py): exports the spell data needed to write
  fixes from the client's Spell.dbc into one small file.

Use at your own risk; shared as is, without support.
