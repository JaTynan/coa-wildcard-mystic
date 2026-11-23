# Every `wcme_*` database table, and the rules for rows we add to core tables

Read this when you meet a `wcme_` name in SQL or C++ and need to know what it is, which database it lives in,
who creates it, who reads it and when a change to it takes effect. Regenerate the list at any time with:

```bash
python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py tables
```

Checked on 2026-11-22: 16 tables (15 permanent, 1 temporary). Most `wcme_...` names you will see in the repository
are **not** tables: they are C++ script names (`spell_wcme_curse_of_arugal`, `wcme_plainsrunning`) registered by
the patches. The script above lists only names that appear in a `CREATE TABLE`.

## The three databases and the realm's copies

| Database | Name on this server | What our project does to it |
|---|---|---|
| Auth | `acore_auth` (shared by all realms) | Patch night writes the realm's address into `realmlist` after each start (`patch-night/PatchNight.ps1:660`). The sign-up service creates accounts. Nothing in `patches/` touches it. |
| World | `acore_world_wildcard` for the Wildcard realm (`acore_world` is the manager's default realm) | `sql/enchants/*.sql` runs against it at every start. The patched C++ only **reads** it. |
| Characters | `acore_characters_wildcard` (`acore_characters` for the default realm) | Three patches create and write their own tables here. Patch night keeps `wcme_applied_sql` here. |

The scripts never hard-code the realm's database: they read the name out of `worldserver.conf`
(`WorldDatabaseInfo`, `CharacterDatabaseInfo`; function `DatabaseName`, `patch-night/PatchNight.ps1:436`), and
refuse to carry on when the manager's active realm is Wildcard but the config points elsewhere (line 454).

## World database: created by `sql/enchants/000-reset.sql`

`000-reset.sql` runs first at every server start. It creates these tables if they are missing, then empties the
ones the repository owns outright, so the files after it rebuild exactly what the repository holds.

| Table | Columns | Purpose | Read by | Takes effect |
|---|---|---|---|---|
| `wcme_backup_spell_linked_spell` | Same as `spell_linked_spell` | One-off copy of the original table, made the first time the reset ran (`CREATE TABLE IF NOT EXISTS ... AS SELECT`). Never refreshed. A safety net, not a live table. | Nobody | n/a |
| `wcme_backup_spell_proc` | Same as `spell_proc` | Same, for `spell_proc`. | Nobody | n/a |
| `wcme_owned` | `tbl` VARCHAR(32), `id` INT; key (`tbl`, `id`) | The ownership ledger for rows we add to **core** tables that have no comment column to mark. `tbl` is one of `spell_dbc`, `spell_proc`, `aura_link`. Each SQL file inserts the IDs it is about to write; the next start's reset deletes those rows from the core table, then empties the ledger. | `000-reset.sql` only | Every start |
| `wcme_enchant_teach` | `enchant_spell`, `taught_spell`, `comment`; key `enchant_spell` | An extra spell an enchant teaches while it is active, on top of what the client data says. One taught spell per enchant. | `LoadExtraTeaches` in `patches/mystic-enchants-wildcard.patch` | Start-up; needs the patched build |
| `wcme_enchant_override` | `enchant_spell`, `roll` (0 or 1), `comment`; key `enchant_spell` | Forces an enchant into (1) or out of (0) scroll rolls, bypassing the missing/dud checks. For enchants that work through C++ the dud filter cannot see, and for ones found broken in testing. | `LoadRollOverrides`, same patch | Start-up; needs the patched build |
| `wcme_proc_target_cooldown` | `spell_id`, `target_cooldown_ms`, `shared_cooldown_ms` (default 100), `comment` | Spells whose procs use a cooldown per target plus a short shared one, instead of their `spell_proc` cooldown. | `patches/63-enchant-target-cooldowns.ps1` | Read once, at the first proc after a start |
| `wcme_enchant_action` | `enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`; key (`enchant_spell`, `rule`) | The action table: what an enchant does when its aura procs. `action` is one of `reduce_cooldown`, `reduce_cooldown_pct`, `reset_cooldown`, `cast_target`, `cast_self`. ID lists are space-separated text. | `spell_wcme_enchant_action` (`patches/mystic-enchants-actions.patch`) | Start-up; needs the patched build |
| `wcme_spellaffect_dbc` | `ID`, `ModifierSpellID`, `AffectedSpellID`; key `ID` | Extra SpellAffect rows: which spells a mask-less modifier changes. IDs from 900000 up, never one SpellAffect.dbc already uses (`enchant_sql_lint.py` checks). See references/spell-system.md section 3. | The core's DBC loader, once `patches/mystic-enchants-spellaffect-sql.patch` names the table | Start-up only; needs the patched build |

What the reset removes at each start (`sql/enchants/000-reset.sql`, 37 lines):

| Core table | Which rows go | How they are recognised |
|---|---|---|
| `spell_linked_spell` | Ours | `comment LIKE 'WCME:%'` |
| `spell_dbc` | Ours | ID listed in `wcme_owned` with `tbl = 'spell_dbc'` |
| `spell_proc` | Ours | `SpellId` listed in `wcme_owned` with `tbl = 'spell_proc'` |
| `spell_script_names` | Ours | `ScriptName LIKE 'spell\_wcme\_%'` |
| `coa_mystic_enchant_aura_link` | Ours | `enchant_spell` listed in `wcme_owned` with `tbl = 'aura_link'` |
| `wcme_enchant_teach`, `wcme_enchant_override`, `wcme_proc_target_cooldown`, `wcme_enchant_action`, `wcme_spellaffect_dbc`, `wcme_owned` | All rows | Whole table emptied |

Consequences you must respect when writing or reviewing SQL:

- **A row we add to a core table must be recognisable by one of the rules above**, or it is never removed and the
  database drifts from the repository. `spell_linked_spell`: start the comment with `WCME:`. `spell_dbc`,
  `spell_proc`, `coa_mystic_enchant_aura_link`: insert the ID into `wcme_owned` in the same file.
- **`wcme_owned` is keyed by ID, not by row.** If we "own" a `spell_proc` row for a spell the core also has a row
  for, the reset deletes the core's row along with ours and nothing puts the core's back. The file must then write
  the row it wants (several files use `REPLACE INTO spell_proc` for exactly this), or leave the core's row alone
  and not claim it. `sql/enchants/005-twin-procs.sql` records two reviews (18 Nov 2026) where a row of ours was
  withdrawn so the core's own row applies again.
- **The reset empties the tables for a moment at each start.** The world server is not running then (the SQL runs
  just before it starts), so nothing reads the half-built state. Never run the folder against a live world.
- **Files run in name order**, and a later file may delete or replace an earlier file's row on purpose
  (`017-enchant-scripts.sql` removes action-table rules that `015` and `016` created, because a dedicated script
  replaces them).
- **A failed file is logged and the start carries on** (`Enchant fix <file> failed: ...` in `patch-night.log`,
  `patch-night/PatchNight.ps1:364`). One bad statement can leave the rest of that file unapplied while the server
  comes up looking healthy.

## World database: created by other files in `sql/enchants/`

| Table | Created in | Purpose |
|---|---|---|
| `wcme_rune_original_quest` | `100-rune-rates.sql:14` | The original rune reward of every quest that pays Runes of Descension (item 375250), saved the first time. Each start recomputes the live `quest_template` amounts from these and the percentage at the top of the file (250 as of 2026-11-22), so changing the percentage never compounds, and 100 restores stock. |
| `wcme_rune_original_loot` | `100-rune-rates.sql:17` | The same idea for every loot row that drops runes (chance and counts). Drop percentage 150 as of 2026-11-22. |
| `wcme_new_spell` (TEMPORARY) | `009`, `011`, `012`, `013` | A scratch list inside one file: the spell IDs the file wants to create. IDs that already exist in `spell_dbc` are removed from it, and only the remainder is recorded in `wcme_owned`, so we never claim (and later delete) a spell we did not create. Dropped at the end of the file. |

These two rune tables are not touched by the reset: they are the memory of the stock values.

## Characters database: created by the patched world server at start-up

Each is created by a `WorldScript::OnStartup` hook with `CharacterDatabase.DirectExecute("CREATE TABLE IF NOT
EXISTS ...")`, so the table appears the first time a build containing the patch starts. They hold player progress:
**deleting or rewriting rows here is a hard stop** in `docs/agents/context/change-risk.md` (item 7). Classify with
`wildcard-change-control` first.

| Table | Columns | Patch | Purpose |
|---|---|---|---|
| `wcme_prestige_legendary` | `guid`, `owed` | `patches/49-prestigious-legendary.ps1:254` | How many Legendary Enchant choices a character is still owed from Prestigious Caches. Written when the number changes, read in `OnPlayerLogin`. |
| `wcme_profession_mastery` | `guid`, `skill`, `points`; key (`guid`, `skill`) | `patches/51-profession-mastery.ps1:331` | Profession Mastery points per character and profession. |
| `wcme_world_pvp_kills` | `guid`, `kills` | `patches/47-leaderboards.ps1:63` | World PvP kill counter for the website leaderboard. |
| `wcme_server_firsts` | `kind`, `detail`, `guid`, `name`, `text`, `at`; key (`kind`, `detail`) | `patches/47-leaderboards.ps1:65` | Server-first records (boss kills, Prestige levels). `INSERT IGNORE` makes the first writer win. Loaded into memory at start-up. |

The leaderboard tables are only created when `Leaderboards.*` is enabled (`WcmeLeaderboards::Enabled()` guards the
`OnStartup` body).

## Characters database: created by patch night

| Table | Created in | Purpose |
|---|---|---|
| `wcme_applied_sql` | `patch-night/PatchNight.ps1:395` | `file`, `applied`. Records which of the AI chat module's own SQL files (`ollama-chat/sql-characters/`) have been run, because those files are not safe to run twice. This is the opposite convention to `sql/enchants/`, where every file runs at every start. |

## Which convention applies to a new SQL file?

| If the SQL is... | Then... |
|---|---|
| Safe to run again at every start (idempotent) and belongs to the world database | It goes in `sql/enchants/` and must clean up through the reset rules above. This is the only path that exists today. |
| Not safe to run twice | There is no general run-once mechanism for the world database as of 2026-11-22. `wcme_applied_sql` covers only the AI chat files. Do not invent one inside a fix: raise it through `wildcard-change-control`. |
| For the characters or auth database | No SQL folder is applied to them. Tables there are created by C++ at start-up (above). |

## Related core tables we add rows to (not ours, but touched)

| Core table | Files | Marker |
|---|---|---|
| `spell_dbc` | `002`, `004`, `005`, `009`, `011`, `012`, `013`, `150` | `wcme_owned` |
| `spell_proc` | `002`, `005`, `007`, `014` to `053` (most batches), `140`, `150` | `wcme_owned`. An all-ranks row uses the negative ID in both places (`140-talent-fixes.sql`: `('spell_proc', -47258)`). |
| `spell_linked_spell` | `001` to `005`, `020` | `WCME:` comment |
| `spell_script_names` | `007`, `015` to `054` (most batches), `140`, `150` | `spell_wcme_` name prefix |
| `coa_mystic_enchant_aura_link` | `007` part 2 | `wcme_owned` key `aura_link` |
| `quest_template`, loot tables | `100-rune-rates.sql` | Recomputed from `wcme_rune_original_*` |
| Other world tables | `110`, `120`, `130`, `140`, `160`, `161` (caches, battleground spoils, dampening, talent fixes, rune currency, an NPC) | Each file is written to be safe to run again; read its header. Safe to run again is not the same as undone by the reset: deleting one of these files leaves its change in place (list: `ascension-restoration/references/reset-limits.md`) |
| MySQL server settings | `090-mysql-tuning.sql`, `095-slow-query-log.sql` | `SET PERSIST` statements (buffer pool, redo log, slow-query log) that ride along because patch night runs this folder as the database administrator at every start. Not game data, and not world-database rows. |

To see exactly what a file does, read its header comment: every file in `sql/enchants/` starts with one, and they
are precise.

## Re-verification

```bash
# Every table and where it is created
python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py tables
# What the reset removes
grep -n "^DELETE" sql/enchants/000-reset.sql
# Which wcme_owned keys are in use
grep -ho "('[a-z_]*', [0-9]*)" sql/enchants/*.sql | cut -d"'" -f2 | sort | uniq -c
# Characters-database tables created by C++
git grep -n "DirectExecute(\"CREATE TABLE" -- patches
# How the SQL folder is applied
grep -n "function ApplyEnchantFixes" -A18 patch-night/PatchNight.ps1
```
