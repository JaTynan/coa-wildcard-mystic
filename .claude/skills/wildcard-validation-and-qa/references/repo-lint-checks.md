# repo_lint.py: every check, what it protects, and what it cannot see

Read this when a finding needs explaining, when you want to add a check, or when someone asks "would the lint have
caught X?".

Run: `python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py [--json] [--only groups] [--strict]
[--allow file.json] [--no-info] [--root DIR]`. Exit 0 = no errors, 1 = errors (or warnings with `--strict`), 2 = the
tool could not run. It reads tracked files (`git ls-files`); outside a git checkout it walks the folder.

Severity: **error** = breaks a rule written in the repository, or will very likely fail at run time. **warning** =
probably wrong or fragile. **info** = cannot be decided without the server, or a fact worth knowing.

## Group `patches`

| Check id | Sev. | Rule | Why (source) |
|---|---|---|---|
| `changes-row` | error | Every `patches/NN-*.ps1` and `*.patch` file name appears in `CHANGES.md` (a backticked wildcard such as `mystic-enchants-*.patch` counts, reported as info `changes-glob`) | CHANGES.md "How changes are made": every new code change gets a line; docs/agents/context/patches.md: "Every patch has a row in CHANGES.md" |
| `changes-stale` | warning | `CHANGES.md` names a patch file that is not in `patches/` | A removed patch whose row stayed tells readers the change is still live |
| `patch-number-dup` | error | Two scripts share a number NN | The workflow applies scripts with `Sort-Object Name`; with a shared number the order hangs on the rest of the name |
| `patch-order` | error | A script number that is not exactly two digits | Sorting is by name, not number: `100-x.ps1` runs before `20-x.ps1`. This is the only way a script can run "out of order" |
| `patch-name` | warning | Name is not `NN-lower-case-words.ps1` | Same sorting concern |
| `patch-stray` | warning | A file in `patches/` that is neither kind | The workflow ignores it |
| `settings-missing` | warning | A literal option name read with `GetOption<T>("Name", ...)` has no line in `server-settings/server-settings.txt` | docs/agents/context/patches.md: any setting a patch reads is listed there. In `*.patch` files only added (`+`) lines are read; in `.ps1` files the whole text is, so an anchor that quotes the core's own `GetOption` shows up here too: put such a name in an allow file |
| `settings-comment-only` | info | The name appears only in a comment of the settings file | The server then runs on the default written in the patch |
| `settings-dynamic` | info | The option name is built at run time | Cannot be checked; check by hand that each possible name is listed |
| `win-macro` | warning | A constant or enumerator in `patches/` is named after a Windows header macro (SYNCHRONIZE, DELETE, ERROR, IN, OUT, ...; the list is `WINDOWS_MACROS` in the script) | 16 Nov: `static constexpr uint32 SYNCHRONIZE` compiled on Linux and failed the Windows build; fixed by a4048e7 (#176). The list is a sample of common macros, not all of them |

## Group `settings`

| Check id | Sev. | Rule |
|---|---|---|
| `settings-format` | error | Every line that is not blank or a `#` comment is `<config file> | <setting> = <value>` (the format stated at the top of the file) |
| `settings-dup` | error / warning | The same file and setting twice: error when the values differ, warning when equal |
| `settings-slash` | warning | A config path written with `/` where the file uses `\` |
| `settings-unrecorded` | info | A value of `?` ("not recorded yet": Apply-Settings skips it) |
| `settings-two-files` | info | The same setting name in two config files |

Not checked: whether the server knows the name, whether the value is in range, whether the comment's stated range
is respected. `settings-report.txt` on the VM answers the first; nothing answers the other two yet.

## Group `sql` (`sql/enchants/*.sql`)

The checker reads `000-reset.sql` itself to learn the rules, so if that file changes the rules follow. As of
2026-11-22 it finds:

| What `000-reset.sql` does on every start | Tables |
|---|---|
| Empties completely | `wcme_enchant_teach`, `wcme_enchant_override`, `wcme_proc_target_cooldown`, `wcme_enchant_action`, `wcme_spellaffect_dbc`, and at the very end `wcme_owned` itself |
| Removes rows listed in `wcme_owned` | `spell_dbc` (`tbl` = `'spell_dbc'`, by `ID`), `spell_proc` (`'spell_proc'`, by `SpellId`), `coa_mystic_enchant_aura_link` (`'aura_link'`, by `enchant_spell`) |
| Removes rows by a marker | `spell_linked_spell` where `comment LIKE 'WCME:%'`; `spell_script_names` where `ScriptName LIKE 'spell\_wcme\_%'` |
| Nothing | every other table |

Because `wcme_owned` is emptied at the end of the reset, each file must register its ids again on every run; the
list the reset uses is the one the *previous* start left behind.

| Check id | Sev. | Rule |
|---|---|---|
| `sql-number-dup` | error | Two files share a three-digit number |
| `sql-reset-first` | error | `000-reset.sql` is not the first file by name |
| `sql-name` | warning | Name is not `NNN-lower-case-words.sql` |
| `sql-rerun` | error | The file would fail or duplicate rows when run a second time: a `CREATE TABLE` without `IF NOT EXISTS`; a plain `INSERT` into an owned table for an id that is neither registered in `wcme_owned` nor deleted earlier in the same file (found by simulating two runs); a plain `INSERT` into any other table with no `DELETE FROM` that table earlier in the file |
| `sql-marker` | error / warning | A row for `spell_linked_spell` without a comment starting `WCME:`, or for `spell_script_names` without a name starting `spell_wcme_`: error unless the file deletes from that table first (then warning: it re-runs, but outlives the file) |
| `sql-owned-dup` | error | A plain `INSERT INTO wcme_owned` repeats a pair an earlier statement registered: duplicate key, and MySQL stops the rest of the file |
| `sql-owned-key` | error | A `tbl` value in `wcme_owned` that the reset has no rule for (a typo such as `'spel_proc'`) |
| `sql-not-owned` | warning / info | Ids put into an owned table but never registered: the rows outlive the file. Info for `REPLACE INTO` (the repository's idiom for restoring the core's own row), warning otherwise |
| `sql-forbidden` | error | `DROP DATABASE` / `DROP SCHEMA`; `DROP TABLE` or `TRUNCATE` of anything not named `wcme_*`; `USE`; `GRANT`, `REVOKE`, `CREATE/ALTER/DROP USER`, `SET PASSWORD` |
| `sql-other-db` | error / warning | A write to a table qualified with a characters or auth database name (hard stop 7); warning when such a name merely appears inside a statement |
| `sql-alter` | warning | `ALTER TABLE` on a stock table |
| `sql-relative-update` | warning | `UPDATE t SET x = x * 2`-style statements on a stock table: they compound at every start |
| `sql-outside-reset` | info | The file changes tables the reset does not restore: deleting the file does not undo it |
| `sql-uncheckable` | info | Rows or registrations built by a `SELECT`, so ownership depends on the database |
| `sql-server-setting` | info | `SET PERSIST` / `SET GLOBAL`: changes MySQL for every database |

What the SQL checks **cannot** see:

- Whether an id already exists as a stock row. A plain `INSERT` for such an id passes here and fails on the server.
- Column counts and types (`INSERT INTO spell_dbc VALUES (...)` with the wrong number of fields).
- Whether a `DELETE` removes a stock row that nothing puts back (the backups `wcme_backup_spell_linked_spell` and
  `wcme_backup_spell_proc` are made once, the first time, and never restored automatically).
- Statements inside stored programs or with `DELIMITER` changes (none exist as of 2026-11-22).
- SQL outside `sql/enchants/`: `ollama-chat/sql-characters/` is a third-party module's schema for the characters
  database, applied by `PrepareOllamaChat` in PatchNight.ps1, and is deliberately not linted.

A failed file does **not** stop patch night: `ApplyEnchantFixes` logs `Enchant fix <file> failed: ...` at WARN and
carries on (patch-night/PatchNight.ps1, function ApplyEnchantFixes), and the `mysql` client stops a file at its
first error, so everything after the failing statement in that file is silently missing for that start. That is
why re-runnability is an **error** here.

The sibling skill ascension-restoration ships `enchant_sql_lint.py`, a deeper replay of the same folder written for
enchant batch work. Run both before an SQL pull request; if they disagree, trust neither and do the
scratch-database double run.

## Group `files`

| Check id | Sev. | Rule | Source |
|---|---|---|---|
| `client-data` | error | No `.mpq .dbc .blp .m2 .wmo .adt .wdt` | docs/agents/context/patches.md: no Ascension client data in this public repository |
| `binary` | error | No `.exe .dll .pdb .zip .7z .tar` | Builds are published as GitHub releases |
| `bytecode` | warning | No `.pyc`, nothing under `__pycache__/` | `.gitignore` already lists it |
| `secret-file` | error | No file named `signup-settings.json`, `signup-state.json`, `.env`, `id_rsa`, `admin-client.ini` | `.gitignore`; hard stop 4 |
| `large-file` | warning | No tracked file over 5 MB | Patch night downloads the repository zip at every run |
| `addon-pin` | error | Each line of `addon/third-party-addons.txt` is `owner/repository | 40-hex commit | folders` | PatchNight.ps1 FetchRepo skips any other line with a WARN, so the addon silently stops updating |

## Group `lineends`

Derived from the files as they are on 2026-11-22 and three "keep CRLF" commits (07dc858, e11ba2a, 1f81e21): every
`.cmd` is CRLF; scripts that run on the VM are CRLF (one exception); `patches/*.ps1` and `*.patch` are LF (the
workflow sets `core.autocrlf false`, so what is committed is what the compiler sees).

| Check id | Sev. | Rule |
|---|---|---|
| `eol-mixed` | error for `.ps1 .cmd .bat .patch`, warning otherwise | CRLF and LF in the same file |
| `eol-cmd` | error | A `.cmd` / `.bat` with LF endings |
| `eol-patch-script` | error | A `patches/*.ps1` with CRLF endings |
| `eol-patch` | error | A `*.patch` that is not LF (it would not apply to LF sources) |
| `eol-odd-one-out` | warning | A VM script whose endings differ from the others in its folder |
| `ps1-encoding` | warning (info under `patches/`) | Non-ASCII characters in a `.ps1` with no UTF-8 byte-order mark: Windows PowerShell 5.1, which the scheduled tasks start (`powershell.exe` in Register-PatchNight.ps1), reads such a file as Windows-1252 |

## Group `parse`

| Check id | Sev. | Rule |
|---|---|---|
| `json-parse` | error | Every `.json` parses |
| `py-parse` | error | Every `.py` parses (`ast.parse`; nothing is executed) |
| `csv-parse` / `csv-width` | error / warning | Every `.csv` reads; every row has the header's column count |
| `ps1-herestring` | error | A PowerShell here-string (`@"` or `@'` at a line end) is closed by `"@` / `'@` at a line start |
| `ps1-parse` | error | **Only when `pwsh` or `powershell` is on the PATH**: every `.ps1` parses with `System.Management.Automation.Language.Parser` (the same call PatchNight.ps1's `ParsesCleanly` uses). Without PowerShell the run says so under SKIPPED. Written but not executed on 2026-11-22 (no PowerShell on the machine it was written on) |
| `yaml-tab` | error | No tab indentation in `.yml` (the standard library has no YAML parser; this is all that is checked) |

## Group `addon`

| Check id | Sev. | Rule |
|---|---|---|
| `toc-name` | error | The `.toc` is named after its folder |
| `toc-interface` | error | `## Interface: 30300` |
| `toc-file` | error | Every file the `.toc` lists exists |
| `toc-unlisted` | warning | Every `.lua` / `.xml` in the folder is listed |
| `toc-version` | warning | A `## Version:` line exists |
| `addon-version` | error / info | A `...VERSION... = "x"` assignment in the addon's Lua equals the `.toc` version; info when the Lua has none (the case for all three addons today) |
| `launcher-version` | error | `launcher/WildcardLauncher.ps1` has `$LauncherVersion = N` and `launcher/WildcardLauncher.py` has `LAUNCHER_VERSION = N` at the start of a line: `Publish-WildcardSite.ps1` reads them with exactly those patterns and throws without them |

Not checked: that the version was *raised* when the addon or launcher changed (needs a comparison with `main`; see
"How to add a check" in SKILL.md), Lua syntax (no Lua interpreter is assumed).

## Group `secrets`

| Check id | Sev. | Rule |
|---|---|---|
| `secret` | error | Patterns for GitHub tokens, private key blocks, AWS keys, Discord webhooks, Slack tokens, JSON web tokens, and `password|secret|api_key|token = "16+ mixed characters"` |
| `share-link` | info | A URL containing `/share/<id>`: public because the repository is |

The value is never printed. This is a tripwire, not a scanner: it knows a handful of shapes. A PASS does not mean
the repository holds no secret.

## Group `enchants`

| Check id | Sev. | Rule |
|---|---|---|
| `tracker-dup` | error | A spell id on two tracker rows |
| `tracker-verified` | warning | Status `verified` with an empty `tested` column |
| `tracker-tested-format` | warning | A `tested` value that does not start with `YYYY-MM-DD` |
| `tracker-fix-file` | warning | A `fix file` that names a file not in `sql/enchants/` or `patches/` |
| `checklist-file` | warning | A checklist row whose `file` number matches no SQL file |

## Exceptions

Put accepted findings in a JSON file and pass it with `--allow`:

```json
{"allow": [
  {"check": "settings-missing", "match": "Rate.XP.Kill", "reason": "the core's own option, quoted in an anchor"},
  {"check": "bytecode", "match": "__pycache__", "reason": "until the housekeeping PR"}
]}
```

A finding is dropped when `check` equals its id and `match` is a substring of its path or message. Keep the file
in the pull request that needs it, with a reason on every line, so the exception is reviewed like code.

## Self-test

`python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint_selftest.py` builds a clean fake repository
and a broken one with 38 planted mistakes in a temporary folder and checks the lint passes the first and reports
every planted mistake in the second. Run on 2026-11-22: `38 of 38 planted mistakes reported ... SELF-TEST PASSED`.
`ps1-parse` is the one check with no fixture (no PowerShell on the machine it was written on).
