# Docs of record: every doc and data file

Checked against the repository at `fcfee51` on 2026-11-22. "Readers" says who or what depends on the file, which tells
you how careful an edit must be: a file a script reads can break that script.

Key: **Hand** = written by hand. **Generated** = a script writes it; do not edit by hand. **Mixed** = part of each.

## Front page and change list

| File | Purpose | Readers | Hand or generated | Update when |
|---|---|---|---|---|
| `README.md` | What the project is, the "use at your own risk" line, how to build, install and run patch night, credits, the branch rules | Strangers on GitHub; James; agents | Hand | The install, build or patch night steps change; a new upstream part is added (credits); the branch rules change |
| `CHANGES.md` | Every customisation in one place: one row per code patch with its setting, a settings summary, one sentence per SQL file, and "How changes are made" | James; the patch reviewer agent (it checks that "`CHANGES.md` and the settings list match", `.claude/agents/patch-reviewer.md` step 4); anyone asking "what did we change?" | Hand | Any patch is added, changed or deleted; any SQL file is added; a new group of settings appears |
| `.gitignore` | Keeps the secret files and Python cache folders out | git | Hand | A new file holding secrets or machine-made junk appears on the server PC next to tracked files |

## `docs/`

| File | Purpose | Readers | Hand or generated | Update when |
|---|---|---|---|---|
| `docs/roadmap.md` | Where the server is heading and the ordered to-do list | James; agents planning work | Hand | The plan changes; an item is finished (say so in the item, as item 6 does: "All ten built") |
| `docs/enchant-restoration.md` | Method, recipes, lessons and progress table for Mystic Enchants; in-game test commands; client patch notes | Anyone fixing enchants | Hand | A recipe or lesson is new; counts are re-measured ("Where we stand" table; last row dated 2026-11-01, so it is behind) |
| `docs/performance.md` | Measured server speed and the settings to try next | Anyone working on lag | Hand | Every new measurement. As of 2026-11-22 it holds only the 7 Nov 2026 table and says "Settled on 1,250" bots, while `server-settings.txt` line 507 says 750: the doc is behind the settings |
| `docs/race-kits.md` | The design of the ten race signature passives (settled 13 Nov 2026) | James; whoever changes a racial | Hand | A racial's design changes. Its numbers must match the `CHANGES.md` row and the patch |
| `docs/dk-enchant-proposal.md` | Proposal: twenty new Death Knight enchants. A proposal, not built | James | Hand | The proposal changes or part of it is built |

## `docs/agents/` and `.claude/agents/` (from PR #232; hard stop 6 applies to every edit)

| File | Purpose | Readers | Hand or generated | Update when |
|---|---|---|---|---|
| `docs/agents/README.md` | Which agent does what, on which model; the three rules for spending Fable; where things are | James; every agent session | Hand | A role is added, moves stage or changes model |
| `docs/agents/context/change-risk.md` | The hard stops, the likelihood x impact matrix, the paths, the analyst's return format | The `change-risk-analyst` agent reads it first; everyone classifying a change | Hand | Only with James's OK. The list of standard changes says "Add to this list only with James's OK" |
| `docs/agents/context/patch-night.md` | One page on patch night: files to read, what healthy looks like, what is wrong | The `patch-night-checker` agent | Hand | Patch night's log wording, file locations or schedule change |
| `docs/agents/context/patches.md` | One page on how patches work and what goes wrong most often; the public-repository rules | The `patch-reviewer` agent | Hand | A new kind of failure is learned; a Fable ruling gives a rule others can apply |
| `docs/agents/case-file-template.md` | The form for every question sent to Fable | Whoever prepares a case | Hand | Rarely |
| `docs/agents/cases/YYYY-MM-DD-short-title.md` | Filled-in cases with their rulings. The folder did not exist yet on 2026-11-22 | Later sessions looking for a precedent | Hand, then the ruling is written back | Each Fable case |
| `docs/agents/fable-ledger.md` | One line per Fable call: what for, did it change the outcome. Empty on 2026-11-22 | James, to move the budget after a month | Hand | Every Fable call |
| `.claude/agents/*.md` | The agents themselves: model, tools, instructions | The agent runner | Hand | Only with James's OK |
| `.claude/skills/*/` | Skills: runbooks loaded when their description matches the task | Agent sessions | Hand | A fact in one is found wrong (its own PR) |

## `enchants/`

Deep column-by-column guidance is in sibling skill `ascension-restoration`. This table is only about what is a
record, what is generated, and what reads what.

| File | Purpose | Readers | Hand or generated | Update when |
|---|---|---|---|---|
| `enchants/tracker.csv` | One row per enchant offered on the realm (6,440): audit class, status, the fix, twin, fix file, `tested`, notes. **The record for "is enchant X working?"** | People (GitHub shows it as a searchable table); `scripts/legendary_history.py`; `client-patch/build_client_patch.py` (takes it as an argument) | Hand (first filled from the audit) | An enchant is fixed, re-classified or tested |
| `enchants/test-checklist.csv` | Every fix not yet tested, with the commands and what should happen; `result` column for the tester | The tester in game; `scripts/legendary_history.py` | Hand | A fix is added (new row); a test is done (`result`) |
| `enchants/legendary-notes.csv`, `enchants/epic-notes.csv` | Per enchant: verdict, assumptions, sources, decisions, tooltip review. **The record for "why did we build it this way?"** | `scripts/legendary_history.py` | Hand | A decision or assumption is made for an enchant of that tier |
| `enchants/legendary-notes-header.md`, `enchants/epic-notes-header.md` | The introduction pasted on top of the generated notes: how to read an entry, the sources | `scripts/legendary_history.py` | Hand | The meaning of a status or the list of sources changes |
| `enchants/legendary-notes.md`, `enchants/epic-notes.md` | One section per changed enchant: commits, PRs, builds, live date, logic, assumptions, test results | People | **Generated** by `scripts/legendary_history.py` (add `--quality Epic` for the epic pair) | Regenerate after any input changes |
| `enchants/legendary-history.csv`, `enchants/epic-history.csv` | One row per copy: status, PRs, first and latest build, first live date, tested | People | **Generated**, same script | Regenerate |
| `enchants/legendary-reference.md` | Every legendary on the archived builder matched to our copies and what the server does | People | **Mixed**: rows are hand-kept; the status of each copy is rewritten by the legendary run (`update_reference()`) | A legendary is fixed or tested (the file says "update a row when an enchant is fixed or tested") |
| `enchants/core-*.csv`, `enchants/swap-own-effects.csv`, `enchants/taught-spell-doubles.csv` | Review worklists from audits against the core: one row per finding with a `status` column ("to review", "resolved", "reviewed: ...", "queued ...") | Whoever continues that review | Hand (first filled by an audit) | A row is reviewed: write the outcome in `status` |
| `enchants/enchant_audit.py` | Sorts every enchant into working, broken or missing from the server's DBC files. Writes `summary.txt` and `enchants.csv` into a folder you name, outside the repository | People | Hand (a tool) | The categories change |
| `enchants/export_spell_data.py` | Exports the spell data needed to write fixes from the client's Spell.dbc into one small file. Its output is client data: keep it out of the repository | People | Hand (a tool) | - |

## Files that are docs as well as data or code

| File | The doc part | Readers | Update when |
|---|---|---|---|
| `server-settings/server-settings.txt` | The comment above each setting: what it does, the date (`8 Nov`), the reason with numbers, and whether it needs a build. **The record for "why is this setting at this value?"** | Patch night applies the settings at every start; James edits it on GitHub (README: "edit them here on GitHub and they apply on the night") | A setting is added or its value changes. Format details: sibling `wildcard-settings-and-flags` |
| `sql/enchants/*.sql` | The `--` header at the top: what the file does in plain English, naming spell ids | Patch night runs the SQL; `scripts/legendary_history.py` copies header sentences that name a spell id into the notes | The file is added or its behaviour changes |
| `patches/*.ps1`, `patches/*.patch` | `//` comment blocks naming a spell id, describing the enchant's logic | The build; `scripts/legendary_history.py` copies those blocks into the notes | The logic changes |
| `addon/third-party-addons.txt` | The header explains the format; comments record when each addon was added, by whom, and what was checked | Patch night installs from it (`PatchNight.ps1` lines 248-262) | An addon is added, re-pinned or removed |
| `launcher/README.md`, `signup/README.md`, `ollama-chat/README.md` | How each friends-facing part works and is set up | James; sibling `wildcard-client-and-web` | That part changes |
| `launcher/site/*.html` | The website's words: home, how to play, server, leaderboards, pets, changes | **Players**; published by `launcher/Publish-WildcardSite.ps1` | Anything players are told changes (the 4:00 am restart time appears in `changes.html` and `index.html`) |
| `launcher/launcher-settings.json` | Site address, realm address, first-install archive size (the link itself lives in `launcher-local.json` on the VM since PR #242) | `Publish-WildcardSite.ps1`; through it, every launcher | Those change |
| Pull request title and description | The title is the public changelog line; description lines naming an enchant are quoted into the generated notes | Players (website); `scripts/legendary_history.py`; the reviewer and risk analyst agents | Every PR |
| Commit messages | Why the change was made, with the evidence. **The record for investigations** | Later sessions doing `git log` archaeology | Every commit |
| Release notes and `BUILD-INFO.txt` | Exact commits of every part of a build | People; **patch night reads the `Core:` line** to match a build to the installed core (`PatchNight.ps1` line 861) | Never by hand |

## Files on the server PC that are records but are not in the repository

From the repository's docs, not re-verified on the server PC on 2026-11-22.

| File | What it records | Named in |
|---|---|---|
| `C:\Games\CoA Server\patch-night\patch-night.log`, `last-run.txt` | Every patch night run and its outcome | README; `docs/agents/context/patch-night.md` |
| `C:\Games\CoA Server\server-settings\settings-report.txt` | The settings check | `docs/agents/context/patch-night.md` |
| `C:\Games\CoA Server\ascension-mystic-enchants.json` | The private copy of the archived builder tooltips. **Never copy from it into the repository** | `enchants/legendary-notes-header.md` |
| `signup-settings.json`, `signup.log` (next to the patch-night scripts) | Secrets; every account created and every refusal, never passwords | `signup/README.md` |

## Docs that were behind on 2026-11-22 (examples of drift to look for)

- `docs/performance.md`: last measurement 7 Nov; bot count has changed twice since (see `server-settings.txt` lines
  505-506, which carry newer numbers than the doc).
- `docs/enchant-restoration.md`, "Where we stand": last row 2026-11-01, before the legendary and epic batches of
  15 to 18 Nov.
- `README.md`: describes two patches in detail; `CHANGES.md` lists about 80 rows. README's "What it changes" is the
  original scope, not the current one.
- `CHANGES.md`, "How changes are made": "one PR per patch night" does not match the merge history.

Fixing any of these is ordinary doc work (a PR with `Changelog: skip`), except the last, which is a rule question
for James.
