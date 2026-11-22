# The record files: tracker, checklist, notes, history, review lists

Read this when you are about to update a record after a fix or a test, or need to know which file answers a
question. All paths are under `enchants/` unless stated. Values and counts were derived from the files on
2026-11-22 (checkout `fcfee51`, PR #232's head; `enchants/` is the same on `origin/main` `d3e030f`); re-run `scripts/tracker_summary.py` for current numbers.

## Which file answers which question

| Question | File | Kept by |
|---|---|---|
| Does this enchant work, and what fixed it? | `tracker.csv` (6,440 rows, one per enchant spell) | hand |
| What do I type to test it, and what should happen? | `test-checklist.csv` (561 rows) | hand |
| Why is a Legendary / Epic the way it is: commits, PR, build, live date, assumptions, sources | `legendary-notes.md`, `epic-notes.md` | generated |
| The same as a table | `legendary-history.csv` (305 copies), `epic-history.csv` (1,710 copies) | generated |
| The assumptions, sources and decisions that feed those | `legendary-notes.csv` (63 rows), `epic-notes.csv` (150 rows) | hand |
| The method text at the top of the notes | `legendary-notes-header.md`, `epic-notes-header.md` | hand |
| Every Legendary on the archived builder against our copies | `legendary-reference.md` (170 on the site, 199 copies here) | status column refreshed by the generator |
| Does the core already handle this enchant? | `core-overlap-review.csv` | hand |
| The plan, recipes and lessons | `../docs/enchant-restoration.md` | hand |

## tracker.csv

| Column | Allowed values (all that occur on 2026-11-22) |
|---|---|
| `spell` | The enchant's spell id. Key. |
| `name` | Enchant name. Several spells can share a name (copies for other realm types, lower-quality copies). |
| `quality` | `Uncommon`, `Rare`, `Epic`, `Legendary`, `Artifact` |
| `scroll item` | Item id of its scroll, for `.additem`. Never empty. |
| `audit` | Output class of `enchant_audit.py`: `standard`, `scripted`, `teaches-ok` (should work); `needs-code`, `teaches-needs-code`, `unsupported` (broken); `missing` (spell not on the server) |
| `family` | Empty for working enchants. For broken ones: `modifier on a placeholder`, `teaches a broken spell`, `proc on a placeholder`, `other placeholder`, `transform`, `leftover`, `unsupported effect` |
| `status` | `working (audit)`: the audit found nothing missing; **not** tested. `live (after restart)`: fix merged, applies at the next start. `live`: fix is on the server. `verified`: tested in game and passed. `partly working`: carries a real effect besides its placeholder, so it stays in the rolls. `broken`. `missing`. |
| `fix` | One line in plain English: what was done (for example "linked to working twin", "action: ...", "aura link: ..."). |
| `twin` | Spell id of the twin used, if any. |
| `fix file` | The `sql/enchants` file, optionally with `(part 1)` / `(part 2)`. |
| `tested` | Starts with the date, `YYYY-MM-DD`, then the result: `2026-10-31 pass: <what was seen>`. A bare date means the detail is in `notes`. |
| `notes` | Free text: failures, caveats, what to retest. |

Rules of use (from `docs/enchant-restoration.md` and practice):

- Update the row in the same pull request as the fix. Never mark `verified` without an in-game result and its date.
- A failed test is recorded too: set `status` back to `broken` or `partly working`, keep the date, say what happened.
- **The tracker lags the later work.** Its `status` and `fix file` columns were kept up for files 001-013; the
  Legendary and Epic batches of 15-18 Nov (files 015-054) mostly did not update them. On 2026-11-22, 33 Legendary
  rows still say `broken` in the tracker although `legendary-history.csv` shows 31 of them changed since. For
  Legendary and Epic enchants read the history files first. Bringing the tracker level is open work.

## test-checklist.csv

Columns: `file` (the SQL file number, or `audit`), `spell`, `name`, `scroll item`, `test type`, `commands`,
`expected`, `result`.

`test type` values in use: `twin`, `teach`, `hook`, `action`, `kit`, `proc`, `core`, `school pair`, `aura link`,
`new spell`, `new spell (named targets)`, `periodic`, `probably already works`, `core+hook`, `core+action`,
`core+proc`, `script`, `modifier`, `swap`, `link`.

`result` is free text: start with `pass` or `fail`, say what was seen, add the date. Then copy the result to the
tracker's `tested` column. No script generates this file (checked 2026-11-22): add a row by hand for every new fix.

## Notes and history (generated)

`scripts/legendary_history.py` builds the notes and history for one quality tier.

```
python3 -I scripts/legendary_history.py                      # Legendary
python3 -I scripts/legendary_history.py --quality Epic       # Epic, plus lower-quality copies of the same names
python3 -I scripts/legendary_history.py --patch-night-log "C:\Games\CoA Server\patch-night\patch-night.log"
python3 -I scripts/legendary_history.py --ref HEAD           # which history to read (default HEAD)
```

Options verified with `--help` on 2026-11-22: `--patch-night-log`, `--ref`, `--quality {Legendary,Epic}`.

What it needs (read from the script):

- The GitHub CLI signed in (`gh api` lists merged pull requests and releases). It could not be run in a session
  without GitHub API access; treat a regeneration there as NOT DONE.
- A local branch named `main` (it calls `git rev-list --first-parent main`).
- Release tags fetched (it finds the first `wcme-...-buildN` release containing each commit).
- Without `--patch-night-log` the "Installed on the server" column stays empty.

What it reads: `tracker.csv`, `test-checklist.csv` (`result`), `<tier>-notes.csv`, `<tier>-notes-header.md`,
`patches/mystic-enchants-scripts.patch` (the comments above each script), the SQL file headers, and every commit
whose added lines under `sql/enchants` or `patches` mention the spell id.

What it writes: `<tier>-history.csv`, `<tier>-notes.md`, and for Legendary the status column of
`legendary-reference.md`. **Never edit those three by hand.** To change what they say, edit `<tier>-notes.csv`
(`spell, verdict, assumptions, sources, decisions, tooltip_review`), the checklist or the tracker, and run it again.

How the status is chosen: `verdict` from the notes file if set; else `tested (see test notes)` or `changed after its
last test (date), retest needed`; else `changed, awaiting in-game test`; else `unchanged: <tracker status>`.

**Known wrinkle (2026-11-22):** 29 Legendary and 163 Epic copies show `changed on an unmerged branch` in the
committed files. Every commit they name is on `main` (checked with `git merge-base --is-ancestor`). The files were
generated on the feature branch before its pull request merged, so the script could not find the pull request yet.
Read that status as "changed, awaiting in-game test".
*Proposed practice (not yet adopted by James):* regenerate once more from `main` after the merge and include the
result in the next pull request. Purpose: the committed status matches reality. Incident: the stale statuses above.

Because the history is built from commit text, **a fix is only traceable if the SQL or patch line it adds contains
the enchant's spell id**, and the reasoning is only there if the file header or script comment says it in plain
English. Write both.

## Review lists (each answers one question)

| File | Question it answers | Rows on 2026-11-22 |
|---|---|---|
| `core-overlap-review.csv` | Which enchants that we touch does the core also handle, and did both run? Columns `core_tables`, `core_cpp`, `status`, `outcome`. **Check here before scripting anything.** | 64: 60 resolved, 4 queued |
| `core-proc-row-replacements.csv` | Where did our SQL replace a `spell_proc` row the core ships for its own rule? | 11: 7 fixed, 4 reviewed as harmless |
| `core-rule-gaps.csv` | Which core-handled enchants have one trigger effect with no core rule, so that effect never fires? | 9: 7 to review |
| `core-version-gaps.csv` | Which core enchant code looks a spell up through its "twin" lookup, which on a `CoA.ClassModel = "hero"` realm only knows the stock spell? | 10: 5 covered, 5 to review |
| `core-rule-version-gaps.csv` | Which core enchant rules list spells but leave out a version a player here can learn? | 263: 261 to review |
| `core-refresh-aura-review.csv` | Which spells' "refresh aura" effect sets the time left instead of adding to it? | 100: 78 not reached by an enchant, 21 to review, 1 fixed |
| `swap-own-effects.csv` | Where the addon shows a twin's tooltip, which enchants' own data can still fire as well? | 19: all to review |
| `taught-spell-doubles.csv` | Where do the core's teach and our teach table both teach a spell? | 54: all queued (option 1) |

These "to review" rows are real remaining work that the "Next candidates" table in the doc does not count.

## Audit and export tools

| Tool | Command | Output |
|---|---|---|
| `enchant_audit.py` | `python3 enchant_audit.py <dbc folder> [output folder]` | `summary.txt` and `enchants.csv`; classes as in the `audit` column. Reads `MysticEnchant.dbc` and `Spell.dbc`; if a test server's database container is running (it tries the Docker names `ac-database`, `azerothcore-wotlk-ac-database-1`, `coa-test-ac-database-1`) it also reads `spell_dbc` and `spell_script_names`. Changes nothing. |
| `export_spell_data.py` | `python3 export_spell_data.py <dbc folder> [output file]` | `enchant-data.json.gz` (default `~/enchant-data.json.gz`): every field of each enchant spell and of the spells they teach, fire or mention, plus an index of every named spell (id, name, rank, class family and flags). |

Both read the **server's** DBC folder (the example in each docstring is `~/coa-test/env/dist/data/dbc`, a Linux test
server). Their outputs contain client text: keep them out of the repository.
