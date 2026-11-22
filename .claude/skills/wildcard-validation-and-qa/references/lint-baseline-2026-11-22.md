# repo_lint baseline, 2026-11-22

Read this when you want to know what the static checker found the first time it was run, so you can tell an old
finding from one your change introduced. Findings are information for James. Nothing here was fixed: the checker
only reads.

- Checked: the repository at commit `fcfee51` (the head of PR #232, which is `62a26e4`, the #230 merge, plus two commits that add
  `.claude/agents/` and `docs/agents/`), 253 tracked files.
- Command: `python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py`
- Run on Linux with Python 3 and no PowerShell, so the 64 `.ps1` files were checked for unclosed here-strings only,
  not parsed. On a machine with `pwsh` or `powershell` the checker parses them too; that part of the result is
  **unknown** as of this date.
- Time: about 1.2 seconds.
- Result: **0 errors, 6 warnings, 44 info. PASS** (exit code 0; with `--strict` exit code 1 because of the warnings).

## The six warnings

| # | Check | Where | What it means | Suggested handling (James decides) |
|---|---|---|---|---|
| 1-3 | `bytecode` | `launcher/__pycache__/WildcardLauncher.cpython-313.pyc`, `signup/__pycache__/WildcardSignup.cpython-313.pyc`, `signup/__pycache__/WildcardStatus.cpython-313.pyc` | Compiled Python is tracked. `.gitignore` lists `__pycache__/`, but a file tracked before that line was added stays tracked. Patch night copies the whole `launcher/` and `signup/` folders to the VM, so these travel too. Harmless, but stale bytecode next to changed source is confusing. | `git rm --cached` the three files in a housekeeping PR. `signup/` is on the sign-up path: classify with wildcard-change-control first. |
| 4 | `csv-width` | `enchants/test-checklist.csv` from line 417 | 47 rows have 7 fields where the header has 8: the `result` column is missing entirely (no trailing comma). `scripts/legendary_history.py` copes (`row.get('result') or ''`), and so does GitHub's table view, but a tool that writes results back by position would shift columns. The 47 lie between line 417 and the last line (562), among rows added after the first batches (SQL files 003 to 053). | Add the trailing comma when those rows next get a result. |
| 5 | `eol-mixed` | `sql/enchants/100-rune-rates.sql` | 67 lines end CRLF and one (line 9) ends LF. MySQL does not care. The next editor that normalises the file produces a whole-file diff. | Normalise when the file is next edited for a real reason. |
| 6 | `eol-odd-one-out` | `launcher/Publish-WildcardSite.ps1` | LF endings; the other two `.ps1` files in `launcher/` and every other script that runs on the VM (`patch-night/`, `server-settings/`, `signup/`, `vm/`) are CRLF. PowerShell runs both. The history has three "keep CRLF line endings" commits (07dc858, e11ba2a, 1f81e21), so the intent is consistency. | Leave, or normalise in its next edit. It is published by patch night (hard stop 5 area), so not worth a PR of its own. |

## What passed (worth knowing, because these are the checks that protect a build)

- All 56 `patches/NN-*.ps1` scripts and all 5 `*.patch` files are named in `CHANGES.md`. Three of the `.patch` files
  (`mystic-enchants-actions`, `-spellaffect-sql`, `-wildcard`) are covered only by the wildcard row
  `mystic-enchants-*.patch` (info `changes-glob`).
- No duplicate patch numbers. Numbers in use run 10 to 96; the next free number is 97.
- All 73 option names that patches read with a literal `GetOption<...>("Name", ...)` have a line in
  `server-settings/server-settings.txt` (273 setting lines, no malformed line, no duplicate).
- 7 option reads build the name at run time (info `settings-dynamic`): `prefix + "CasePercent"` and two more in
  `40-battlegrounds.ps1`; `"WeekendBonus." + theme + ...` twice in `45-weekend-bonus.ps1`; `entry.setting` in
  `62-racial-spellbook.ps1`; `key` in `93-group-xp.ps1`. The checker cannot confirm those are listed.
- No constant or enumerator in `patches/` is named after a Windows header macro (the 16 Nov SYNCHRONIZE build failure;
  replaying the checker on the pre-fix file `a4048e7^:patches/mystic-enchants-scripts.patch` reports it at line 9506).
- `sql/enchants/`: 64 files, numbers unique, `000-reset.sql` sorts first, no `DROP DATABASE`, no `DROP TABLE` or
  `TRUNCATE` of a stock table, no `USE`, no account statements, no write to a characters or auth database, no
  `CREATE TABLE` without `IF NOT EXISTS`, every statically readable row is either removed by `000-reset.sql` or
  deleted earlier in its own file (two simulated runs, no duplicate key).
- No game client data (`.mpq .dbc .blp`), no executables or archives, no reserved secret file names, no secret
  patterns.
- All `.cmd` files are CRLF, all `patches/*.ps1` and `*.patch` files are LF, no script has mixed endings.
- `launcher/launcher-settings.json` parses; all 20 Python files parse; all 14 CSV files read.
- The three addon `.toc` files say `## Interface: 30300`, list every Lua file in their folder and no missing one.
  Versions: WildcardEnchants 1.11, WildcardMastery 1.0, WildcardCombatLogFix 1.0. No Lua file carries a version
  string, so there is nothing to compare the `.toc` version with (info `addon-version`).
- Launcher versions are readable by the pattern `Publish-WildcardSite.ps1` uses: Windows 5, Linux 6.
- `addon/third-party-addons.txt`: every line is `owner/repository | 40-character commit | folders`.
- `enchants/tracker.csv`: 6,440 rows, no duplicate spell, every `verified` row has a `tested` value, all 49 `tested`
  values start with a `YYYY-MM-DD` date, every named fix file exists.

## Info findings that deserve a human look

| Check | Where | Why it matters |
|---|---|---|
| `share-link` | `launcher/launcher-settings.json:4` (`clientArchiveUrl`) | The launcher needs this link to the full client archive (about 46 GB by `clientArchiveBytes`), and the repository is public, so the link is public too. The repository's own rule is that client data is never published in it; a link is not the data, but it leads to it. This is a decision for James, not a defect the checker can judge. |
| `sql-not-owned` (7) | `005-twin-procs.sql:36,39`, `007-enchant-actions.sql:175,180`, `017-enchant-scripts.sql:104`, `020-quick-legendaries.sql:20`, `038-core-handlers-and-visuals.sql:21` | `REPLACE INTO spell_proc` for an id not registered in `wcme_owned`. Each one carries a comment saying it restores the core's own proc row "as it ships (not owned, so the reset leaves it)". That is the right idiom. The risk it leaves: when a core update changes that row, our copy silently overrides the new one at every start. Re-check these seven ids (282040, 285100, 276302, 979137, 1587050, 1180480, 1544910) against the new core's `spell_proc` after each core update. |
| `sql-outside-reset` (7) | `026` (UPDATE of the stock `spell_proc` row -44445); `100` (quest and loot tables); `110`, `120` (item_template); `130` (spell_area); `160` (currencytypes_dbc, item_template); `161` (npc_vendor) | These change stock tables that `000-reset.sql` does not restore. "Delete the file and its fix is gone at the next start" (docs/enchant-restoration.md) is **not true for these files**: undoing them needs a new statement that puts the old value back (`100-rune-rates.sql` keeps the originals in `wcme_rune_original_*` for exactly that reason; the others do not). With `sql-server-setting` (090, 095) that makes nine files the lint can see. The full list, including the kinds the lint cannot see (core rows removed or replaced and owned: 027, 140, and rows in 005, 018, 020, 027), has one home: `ascension-restoration` section 5, item 3. Until 2026-11-22 the lint also listed 013 here: a false positive, fixed (013 updates `spell_proc` 282881, which 007 registers in `wcme_owned`, so the reset does undo it). |
| `sql-uncheckable` (4) | `009`, `011`, `012`, `013` | 858 + 337 + 1 + 3 `spell_dbc` ids are registered in `wcme_owned` by a `SELECT` that runs on the server ("only where no spell with that ID exists already"). Whether each id ends up owned depends on the database, so only a scratch-database double run can prove these files re-run cleanly. |
| `sql-server-setting` (11) | `090-mysql-tuning.sql`, `095-slow-query-log.sql` | `SET PERSIST ...` changes MySQL itself, for every database on the VM, and survives restarts. Not a defect; listed so nobody mistakes these two for enchant fixes. |
| `settings-two-files` (1) | `BindIP` | Set in both `authserver.conf` and `worldserver.conf`. Both programs read it; fine. |

## Things the checker cannot see (do not read a PASS as more than this)

1. Whether an anchor in a patch script still matches the pinned sources: use the patch pre-flight in
   wildcard-patch-authoring.
2. Whether the C++ compiles, on Linux or on Windows.
3. Whether an id our SQL inserts already exists as a stock row (a plain `INSERT` then fails on the server only).
4. Whether a setting name is one the server reads: only `settings-report.txt` on the VM answers that.
5. Whether PowerShell scripts parse, on this machine (no PowerShell here).
6. Anything about behaviour in game.

## Full output, verbatim

```
repo_lint: REPOSITORY-ROOT (253 files, git ls-files)

WARNINGS (6)
  [bytecode] launcher/__pycache__/WildcardLauncher.cpython-313.pyc: compiled Python is committed (.gitignore lists __pycache__/, but a file tracked before that stays tracked until 'git rm --cached')
  [bytecode] signup/__pycache__/WildcardSignup.cpython-313.pyc: compiled Python is committed (.gitignore lists __pycache__/, but a file tracked before that stays tracked until 'git rm --cached')
  [bytecode] signup/__pycache__/WildcardStatus.cpython-313.pyc: compiled Python is committed (.gitignore lists __pycache__/, but a file tracked before that stays tracked until 'git rm --cached')
  [csv-width] enchants/test-checklist.csv:417: 47 row(s) do not have the header's 8 columns (first at line 417); tools that read by column name see an empty or missing value
  [eol-mixed] sql/enchants/100-rune-rates.sql: mixed line endings in one file (harmless to run, but the next editor that normalises it turns a one-line change into a whole-file diff)
  [eol-odd-one-out] launcher/Publish-WildcardSite.ps1: LF line endings; the other scripts in launcher/ use CRLF

INFO (44)
  [addon-version] addon/WildcardCombatLogFix/WildcardCombatLogFix.toc: version 1.0 lives only in the .toc (no version string in the Lua to compare)
  [addon-version] addon/WildcardEnchants/WildcardEnchants.toc: version 1.11 lives only in the .toc (no version string in the Lua to compare)
  [addon-version] addon/WildcardMastery/WildcardMastery.toc: version 1.0 lives only in the .toc (no version string in the Lua to compare)
  [changes-glob] patches/mystic-enchants-actions.patch: covered in CHANGES.md only by a wildcard row (mystic-enchants-*.patch, *.patch)
  [changes-glob] patches/mystic-enchants-spellaffect-sql.patch: covered in CHANGES.md only by a wildcard row (mystic-enchants-*.patch, *.patch)
  [changes-glob] patches/mystic-enchants-wildcard.patch: covered in CHANGES.md only by a wildcard row (mystic-enchants-*.patch, *.patch)
  [settings-dynamic] patches/40-battlegrounds.ps1:261: option name built at run time (prefix + "CasePercent"...): cannot be checked statically
  [settings-dynamic] patches/40-battlegrounds.ps1:262: option name built at run time (prefix + "PackPercent"...): cannot be checked statically
  [settings-dynamic] patches/40-battlegrounds.ps1:263: option name built at run time (prefix + "GoldenPackPercent"...): cannot be checked statically
  [settings-dynamic] patches/45-weekend-bonus.ps1:85: option name built at run time ("WeekendBonus." + theme + "." + name...): cannot be checked statically
  [settings-dynamic] patches/45-weekend-bonus.ps1:220: option name built at run time ("WeekendBonus." + theme + ".Title"...): cannot be checked statically
  [settings-dynamic] patches/62-racial-spellbook.ps1:45: option name built at run time (entry.setting...): cannot be checked statically
  [settings-dynamic] patches/93-group-xp.ps1:65: option name built at run time (key...): cannot be checked statically
  [settings-two-files] server-settings/server-settings.txt: bindip is set in more than one config file (authserver.conf, worldserver.conf); fine if both read it
  [share-link] launcher/launcher-settings.json:4: public share link https://<host>/api/share/<id>...: anyone who reads this public repository can use it
  [sql-not-owned] sql/enchants/005-twin-procs.sql:36: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (282040): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-not-owned] sql/enchants/005-twin-procs.sql:39: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (285100): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-not-owned] sql/enchants/007-enchant-actions.sql:175: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (276302): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-not-owned] sql/enchants/007-enchant-actions.sql:180: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (979137): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-not-owned] sql/enchants/017-enchant-scripts.sql:104: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (1587050): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-not-owned] sql/enchants/020-quick-legendaries.sql:20: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (1180480): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-not-owned] sql/enchants/038-core-handlers-and-visuals.sql:21: REPLACE INTO spell_proc for 1 id(s) not registered in wcme_owned (1544910): right when it restores the core's own row (000-reset.sql must leave that alone), wrong for a row of ours, which then outlives its file
  [sql-outside-reset] sql/enchants/026-medium-legendaries-3-extras.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: UPDATE spell_proc
  [sql-outside-reset] sql/enchants/100-rune-rates.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: UPDATE creature_loot_template, UPDATE gameobject_loot_template, UPDATE item_loot_template, UPDATE quest_template, UPDATE reference_loot_template
  [sql-outside-reset] sql/enchants/110-manastorm-caches-unstack.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: UPDATE item_template
  [sql-outside-reset] sql/enchants/120-battleground-spoils.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: UPDATE item_template
  [sql-outside-reset] sql/enchants/130-battleground-dampening.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: INSERT spell_area
  [sql-outside-reset] sql/enchants/160-rune-currency.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: INSERT currencytypes_dbc, UPDATE item_template
  [sql-outside-reset] sql/enchants/161-wisdomball-tiraxis.sql: changes stock tables that 000-reset.sql does not restore, so deleting this file does not undo it: INSERT npc_vendor
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:16: changes a MySQL server setting for every database: SET PERSIST innodb_buffer_pool_size = 4294967296
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:17: changes a MySQL server setting for every database: SET PERSIST innodb_redo_log_capacity = 1073741824
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:18: changes a MySQL server setting for every database: SET PERSIST innodb_flush_log_at_trx_commit = 2
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:19: changes a MySQL server setting for every database: SET PERSIST innodb_flush_log_at_timeout = 3
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:20: changes a MySQL server setting for every database: SET PERSIST innodb_log_buffer_size = 67108864
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:21: changes a MySQL server setting for every database: SET PERSIST_ONLY performance_schema = OFF
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:22: changes a MySQL server setting for every database: SET PERSIST innodb_io_capacity_max = 2000
  [sql-server-setting] sql/enchants/090-mysql-tuning.sql:23: changes a MySQL server setting for every database: SET PERSIST innodb_io_capacity = 1000
  [sql-server-setting] sql/enchants/095-slow-query-log.sql:5: changes a MySQL server setting for every database: SET PERSIST slow_query_log_file = 'C:/Games/CoA Server/Core/Logs/mysql
  [sql-server-setting] sql/enchants/095-slow-query-log.sql:6: changes a MySQL server setting for every database: SET PERSIST long_query_time = 0.5
  [sql-server-setting] sql/enchants/095-slow-query-log.sql:7: changes a MySQL server setting for every database: SET PERSIST slow_query_log = ON
  [sql-uncheckable] sql/enchants/009-missing-modifiers.sql: cannot be checked without the database: spell_dbc (858 ids owned only if a SELECT registers them at run time)
  [sql-uncheckable] sql/enchants/011-missing-named-targets.sql: cannot be checked without the database: spell_dbc (337 ids owned only if a SELECT registers them at run time)
  [sql-uncheckable] sql/enchants/012-placeholder-modifiers.sql: cannot be checked without the database: spell_dbc (1 ids owned only if a SELECT registers them at run time)
  [sql-uncheckable] sql/enchants/013-action-fixes.sql: cannot be checked without the database: spell_dbc (1 ids owned only if a SELECT registers them at run time); spell_dbc (2 ids owned only if a SELECT registers them at run time)

SKIPPED
  ps1-parse: PowerShell is not installed here, so 64 .ps1 files were only checked for unclosed here-strings, not parsed

Result: 0 error(s), 6 warning(s), 44 info, 0 allowed by exception. PASS
```
