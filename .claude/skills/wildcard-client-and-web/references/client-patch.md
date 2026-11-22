# The client patch (`patch-ZZW.MPQ`) and its builders

Read from `client-patch/*.py`, `docs/enchant-restoration.md` ("Client patch") and `docs/race-kits.md` on 2026-11-22.
The builders were not run here: they need files from the game client, which are never in this repository. What was
run: `custom_spells.py` (it needs no client file) and its output compared with the committed SQL (identical).

## Words

- **MPQ**: the game's archive format. The client loads every `Data\patch-*.MPQ`; when two archives hold the same
  file, the one whose name sorts later wins.
- **DBC**: a table file inside an MPQ (`DBFilesClient\Spell.dbc` is the client's list of every spell: name, icon,
  tooltip, cooldown...). The server has its own copies and the `spell_dbc` database table.
- **BLP**: the game's image format for icons.

## Why the name `patch-ZZW.MPQ`

The client reads two spell lists: `Data\area-52\patch-D.MPQ` only on Ascension's Area 52 realm type, and
`Data\patch-T.MPQ` everywhere else, including this server. `patch-ZZW` sorts after `patch-T` (and after the
`patch-Z*` names the CoA Custom Races module uses, per `docs/roadmap.md` item 2), so its tables win.

## What may go where

| Thing | In the patch (on the VM and friends' PCs) | In this public repository |
|---|---|---|
| The built `patch-ZZW.MPQ` | yes | NEVER (it is the client's own data plus ours) |
| `Spell.dbc`, `SpellIcon.dbc`, `SpellVisual*.dbc`, `SpellCharges*.dbc` extracted from the client | used as builder input | NEVER |
| Icons made from the client's art (`wcme_rend_*.blp`, `wcme_regen_cooldown.blp`) | yes | NEVER (the scripts that make them are in the repo; their output is not) |
| Our own rows: spell ids 9990001-9990068, icon rows 9990001-9990010, visual kits 9990101-9990103, visual 9990101, charge category 9001 | yes | yes, as Python data in `custom_spells.py`, `racials.py`, `visuals.py` |
| Our own tooltip wording for our own spells and racials | yes | yes (it is ours) |
| Verbatim Ascension tooltip text | (already in the client) | NEVER; paraphrase |

`check_client_web.py` fails if a `.mpq`, `.dbc` or `.blp` file is tracked.

## The builders (usage read from each file; they use `sys.argv`, not argparse)

All of them write their intermediate tables (`Spell.dbc`, `SpellIcon.dbc`, ...) into the CURRENT folder. Run them
from a scratch folder outside the repository so client data cannot be committed by accident.

| Script | Usage | Inputs from the local client | Output |
|---|---|---|---|
| `build_client_patch.py` | `python3 build_client_patch.py <wildcard Spell.dbc> <area-52 Spell.dbc> <tracker.csv> [output.MPQ]` | `DBFilesClient\Spell.dbc` extracted from `Data\patch-T.MPQ` and from `Data\area-52\patch-D.MPQ`; `enchants/tracker.csv` from this repo (its `spell` column) | `patch-ZZW.MPQ` holding `Spell.dbc` only: the Wildcard list, plus every tracker enchant spell it lacks copied from the Area 52 list, plus our own spells, with racial changes and our icons applied. Prints `Added N enchant spells; M spells in all.` |
| `racials_off_gcd.py` | `python3 racials_off_gcd.py <Spell.dbc from the current patch-ZZW.MPQ> <client SpellIcon.dbc> [output.MPQ] [--icons <folder>] [--charges <client SpellCharges.dbc> <client SpellChargesCategory.dbc>] [--visuals <client SpellVisual.dbc> <client SpellVisualKit.dbc>]` | the `Spell.dbc` inside the current `patch-ZZW.MPQ`; the client's `SpellIcon.dbc`; optionally a folder of `.blp` icons, the two charge tables, the two visual tables (the script's own usage text omits `--visuals`; the code at lines 44-48 handles it, and `visuals.py` says the visual tables are in `patch-S.MPQ`) | a rebuilt `patch-ZZW.MPQ` with `Spell.dbc` and `SpellIcon.dbc`, plus the optional tables and `Interface\Icons\<name>.blp` files. Applies, in order: off the global cooldown, cooldowns, castable while moving, changed values, our icons, changed texts, our spells. Prints `N racials off the global cooldown; M spells in all.` |
| `custom_spells.py` | `python3 custom_spells.py > sql/enchants/150-custom-spells.sql` (its usage line names a `<Spell.dbc>` argument, but the code does not read one) | none | prints the SQL for the server's copy of our spells: `spell_dbc` rows, `spell_proc` rows, `spell_script_names` rows, and their `wcme_owned` entries |
| `rend_icons.py` | `python3 rend_icons.py <Ability_Gouge.blp> <output folder>` | that icon from the client's `Data\patch-I.MPQ`; needs the Pillow package (`PIL`), not standard library | `wcme_rend_frost.blp`, `wcme_rend_fire.blp`, `wcme_rend_nature.blp` |
| `regen_icons.py` | `python3 regen_icons.py <Spell_Nature_Regenerate.blp> <output folder>` | that icon from `Data\patch-I.MPQ`; needs Pillow | `wcme_regen_cooldown.blp` |
| `mpqwrite.py` | `python3 mpqwrite.py <out.MPQ> <name in archive>=<file> ...` | any files | a minimal MPQ (version 1, zlib-compressed) with a `(listfile)` |
| `dbc.py`, `racials.py`, `visuals.py` | libraries | - | - |

The repository has no MPQ reader. Extracting `Spell.dbc` and the other tables from the client's archives is done
with a separate MPQ tool; which one was used is not recorded in the repository (UNVERIFIED: ask James).

Which builder to use: `build_client_patch.py` builds from the client's two original lists (use it after a CoA client
update changes `patch-T.MPQ`, or when the tracker gains enchants). `racials_off_gcd.py` rebuilds from the patch you
already have and is the only one that adds icons, charges and visuals. Note that a patch built by
`build_client_patch.py` alone has no `SpellIcon.dbc`, so run `racials_off_gcd.py` on its output to get the icon
rows back.

## The class-family crash (7 Nov, commit `dc2a5da`, PR #52)

The first patch copied the Area 52 enchant spells unchanged. The character-creation screen then crashed: it
gathers spells by class, using each spell's class family and class flags. The client only needs those spells'
names, icons and tooltips (their effects run on the server), so the builder now zeroes columns 208-211 (class
family and the three class-flag words) for every ADDED spell (`build_client_patch.py`, `client_row`).

Rule: a spell added to the client for display only must carry no class family and no class flags. After any
client-patch change, open the character-creation screen before anything else.

## Our own spells (`custom_spells.py`)

68 spells, ids 9990001 to 9990068 (as of 2026-11-22): buff icons for the racials, their spellbook entries, the
Mana-forged Barrier spells and a few hidden Mystic Enchant helpers. One Python dictionary (`SPELLS`) produces both
copies, so they cannot drift:

- the client row, through `custom_spells.row()` in either builder;
- the server row, through `custom_spells.sql()` -> `sql/enchants/150-custom-spells.sql`.

**`sql/enchants/150-custom-spells.sql` is a generated file. Never edit it by hand.** Change `custom_spells.py`,
regenerate, commit both. Drift check (run 2026-11-22: identical):

```
python3 client-patch/custom_spells.py | diff - sql/enchants/150-custom-spells.sql && echo identical
```

`racials.py` holds changes to STOCK spells that the server also makes in C++ at start-up
(`patches/52-racials.ps1` and the racial patches): off the global cooldown (`OFF_GCD`), castable while moving
(`MOVABLE`), cooldowns (`COOLDOWNS`), numbers (`VALUES`) and our own wording (`TEXTS`). The client needs the same
change because the client itself refuses a spell during the global cooldown and draws the tooltip from its own data.

## How the patch reaches friends

1. Build it on a machine that has the client, in a scratch folder.
2. Test it on that client first (below).
3. **[James, or with his say-so.]** Copy it by hand to `F:\CoAClient\Data\patch-ZZW.MPQ` on the VM. No script does
   this. It changes what every friend's client downloads and cannot be recalled once synced: classify with
   wildcard-change-control first.
4. The next publish (after the next server start, or `Publish-WildcardSite.cmd`) hashes it into `manifest.json`.
5. Each friend's launcher downloads it at its next start. A friend who is in game keeps the old one until they
   restart the game.

The server half (`150-custom-spells.sql`, and the enchant spell rows in files 009 and 011) arrives separately
through the normal merge and the next restart. Order matters: a new buff whose spell the client does not have yet
shows no icon or text; a client that has a spell the server lacks shows a spell that does nothing. Ship the server
half and the client half for the same restart.

## Test checklist for a new patch (on your own client, before the VM)

1. The game starts and reaches the login screen.
2. The character-creation screen opens and every race and class can be clicked (the 7 Nov crash).
3. In game: `/run print(GetSpellInfo(911367))` prints a name (an added enchant spell; the 2 Nov test).
4. `/run print(GetSpellInfo(9990001))` prints a name (one of our own spells).
5. A changed racial shows the new tooltip and, where changed, the new cooldown.
6. A buff that uses one of our icons shows the icon, not a question mark.

Changing what is in the patch changes what every player's client does: classify with wildcard-change-control first.
