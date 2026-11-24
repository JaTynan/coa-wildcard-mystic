---
name: ascension-restoration
description: Digital-archaeology method and runbook for restoring Ascension's Mystic Enchants, talents and racials on the Wildcard realm. Covers the source hierarchy and conflict rule (client tooltip first), the restoration state with dated counts, the decision tree from a broken enchant to a proven recipe (twin link, school pair, teach table, action table, aura link, rebuilt spell, proc rules), sql/enchants conventions (numbering, WCME marker, wcme_owned, 000-reset, safe to run twice), the tracker and notes files, the per-batch checklist and in-game test commands. Load it when a player or James says "this enchant does nothing", "it procs on every hit", "this talent or racial is broken", "the tooltip says X but it does Y"; when asked to fix, audit, research, test or document an enchant, talent or racial; when writing or reviewing a file in sql/enchants; or when updating enchants/tracker.csv. If it is not yet clear the fault is in the enchant data, start with wildcard-debugging-playbook.
---

# Ascension restoration: Mystic Enchants, talents and racials

**Priority first.** James's order of work is (1) lag spikes, (2) pipeline, testing and validation, (3) broken
enchants **last**. Do enchant work when it is asked for, or when nothing in (1) or (2) is waiting. A complete,
working Mystic Enchant system is still one of the project's end goals.

**What this is.** Ascension, the game these systems come from, is gone: no site, no forums, no server code. Its
Mystic Enchants (passive effects a character collects and slots) exist on our server only as client data, and
most of the clever ones were driven by Ascension's own server code, which nobody has. So each broken enchant is
reconstructed from evidence. This skill is the method, the proven recipes, and the record-keeping.

**Two rules that override everything below.**

1. Any step that changes what the server does: **classify with wildcard-change-control first.** James merges.
2. This repository is public. **Never paste tooltip or description text from the client or the archived builder
   into it**: not in SQL comments, docs, tracker cells, commit messages or pull requests. Paraphrase in your own
   words ("Execute grants a haste buff"), and refer to spells by name and id.

## When NOT to use this skill

| You are doing | Use instead |
|---|---|
| Deciding the risk class, whether James must review, or how to branch and merge | wildcard-change-control |
| Writing or porting the C++ (`patches/*.ps1`, `*.patch`), anchors, pre-flight against the pinned core | wildcard-patch-authoring |
| Needing to understand `spell_proc`, auras, class family flags, spell scripts or core hooks in depth | azerothcore-coa-reference |
| Deciding what counts as proof, or designing a test or check | wildcard-validation-and-qa |
| Patch night, `Start-Server.cmd`, restarts, rollback on the VM | wildcard-run-and-operate |
| Reading `patch-night.log`, `Server.log`, `Errors.log` or measuring anything | wildcard-diagnostics-and-tooling |
| A fix that "does nothing" after a restart and you do not know which layer failed | wildcard-debugging-playbook |
| Building or shipping the client patch, the addon to players, the launcher | wildcard-client-and-web |
| A setting such as `CoA.MysticEnchants.*` or `Wildcard.*`: defaults, which build, how to add one | wildcard-settings-and-flags |
| Public-repo rules, house style, `CHANGES.md` wording | wildcard-docs-and-publishing |
| Re-balancing enchants as a system, or brand-new enchants as a feature | wildcard-frontier |
| Lag, bots, performance | wildcard-lag-spike-campaign |

## Start here

1. Find the enchant in `enchants/tracker.csv` (by name or spell id).
2. Check `enchants/core-overlap-review.csv`: if the core already does it, add nothing.
3. Section 3 picks the recipe; `references/recipes.md` has the exact steps.
4. Section 8 is the per-batch checklist; section 4 the in-game test.
5. Classify with `wildcard-change-control` before the pull request. James merges.

Status words used below (DOCTRINE, PRACTICE, NOT BUILT YET, Proposed practice, UNVERIFIED,
OPEN) are defined in `wildcard-change-control`, section 1. The risk matrix and hard stops come from
`docs/agents/*`: **DOCTRINE (PR #232, merged 22 Nov 2026)**.

## Words used here

| Word | Meaning |
|---|---|
| Enchant spell | The spell id that *is* the enchant: a passive aura on the player. Column `spell` in the tracker. |
| Placeholder | A spell effect that does nothing by itself (a "dummy"). Ascension's code gave it meaning; ours has none. |
| Twin | The same enchant made for another realm type, under another spell id, that often works. |
| Proc | An aura "firing" on an event (a hit, a cast, a crit). `spell_proc` is the table of when each may fire. |
| `Spell.dbc` / `spell_dbc` | The client's spell list / the server table that overrides or adds to the server's copy of it. |
| Core | The CoA fork of AzerothCore that the server is built from. It has its own partial enchant code. |
| Build | Compiling the server with our `patches/`. Takes 2-3 hours. SQL needs no build; C++ does. |
| WCME | "Wildcard Mystic Enchants": the prefix that marks rows and tables this repository owns. |
| GM | Game master: an account level that may type dot-commands such as `.aura` in game. |
| DBC | The client's data-table file format (`Spell.dbc` and friends); the server reads its own copies. |

Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## 1. The sourcing method

### Source hierarchy (strongest first)

| # | Source | Where it lives | How to consult it |
|---|---|---|---|
| 1 | **Client tooltip**: what our own game client shows for the spell | The client's `Spell.dbc` | In game as a GM: `.lookup spell id <id>` prints a clickable link; hover it. The description is the first line under the name; a granted buff is shown below it. |
| 2 | **Spell data**: effects, numbers, triggered spells, proc flags | `Spell.dbc` and `MysticEnchant.dbc` in the server's DBC folder | `python3 enchants/export_spell_data.py <dbc folder> [output]` writes `enchant-data.json.gz`: every field of each enchant spell and of the spells it teaches, fires or mentions, plus a name index for finding twins and namesakes. |
| 3 | **Archived builder**: Ascension's own enchant list for its Area 52 realm, captured 14 June 2026 | Wayback Machine: `https://web.archive.org/web/20260614222446/https://ascension.gg/en/v2/builder/area-52/mystic-enchant`. A private copy is on the game server at `C:\Games\CoA Server\ascension-mystic-enchants.json`. | Read it; never copy its text here. It shows designer intent, and it is the only text for the 1,206 enchants whose spell our client list lacked. |
| 4 | **The core's own version** of the same ability | Upstream source: `src/server/coa`, `src/server/scripts/Spells`, and `data/sql/updates/pending_db_world` | Search for the spell id. Several enchants copy a class ability the core already scripts; take numbers and behaviour from it. |
| 5 | **Player descriptions** passed on by James | Not written down anywhere a reader can open | Ask James; record what he says in the enchant's notes row (`decisions` or `sources`) or tracker `notes` cell, with the date. Used for Mana Fiend, Steward of Eternity, Grove Ranger. |
| 6 | **Public pages**: the Project Ascension wiki (Enchant Collection page), forum threads, social media, YouTube | The open web | Weakest. Good for a number nobody else gives. Ascension's own database site blocks automated reading. |

Watch out: with the WildcardEnchants addon on, about 200 enchants show their **twin's** text
(`addon/WildcardEnchants/TooltipData.lua`, a list of id pairs). If the id you are reading is in that file, you are
reading the twin's tooltip, not the enchant's own.

### Conflict rule (James's decision)

1. **The client tooltip wins.**
2. Then **designer intent** (the archived builder, the core's own version of the ability).
3. Then **copy a similar ability**: damage from damage, area effect from area effect, heal from heal.
4. Then an **educated guess**, written down as a guess.
5. **Outliers go to James.**

Supporting decisions: a workable best guess beats leaving an enchant missing; prefer a permanent code fix over a
database stopgap; base a missing number on a similar existing spell; where tooltip and mechanics differ, flag it
for review.

### What counts as an outlier (stop and ask James)

**Proposed reading of James's conflict rule (not yet adopted by James).** Purpose: make "outliers go to James" a
list a session can check. Derived from the cases that were put to him (the `decisions` column of the notes files, commit `730ecea`):

- Two sources disagree and the higher one looks wrong (Mana Fiend: client tooltip against two player accounts and the wiki).
- The tooltip gives no chance, cooldown or amount, and no similar spell exists to copy.
- The fix would leave the tooltip saying something different from what the server does.
- The same enchant can be built two ways with different results for players (the "taught spell doubles" choice).
- The result is far stronger or weaker than other enchants of its quality.
- It gives players items, currency or power outside normal play. That is also a hard stop in change control.

### How to record a source and an assumption

James's requirement: every fix is documented with the pull request and build it shipped in, whether it was tested
(with dates), its assumptions and its sources.

| What | Where it goes |
|---|---|
| The logic in plain English, paraphrased | The comment header of the SQL file, and the comment above the script if there is one. The history generator copies these. |
| A guessed number | In the row's own `comment` ("chance assumed"), and under Assumptions. |
| Assumptions, sources, decisions, tooltip differences (Legendary and Epic) | `enchants/legendary-notes.csv` or `enchants/epic-notes.csv`: `spell, verdict, assumptions, sources, decisions, tooltip_review`. |
| The same for Uncommon and Rare | Tracker `fix` and `notes`, plus the pull request description (no notes file exists for those tiers). |
| A decision by James | `decisions`, dated: `2026-11-17 James: fix every known gap.` |
| Tooltip and server differ on purpose | `tooltip_review`; it is listed at the top of the generated notes for every later review. |

Write sources the way the files already do, for example: `Ascension builder tooltip (area-52 archive, 14 Jun 2026);
our client spell data (Spell.dbc)`, or `our client spell data (Spell.dbc); the core`.

## 2. Current state

| As of | Source | What it says |
|---|---|---|
| Audit, Oct 2026 | `docs/enchant-restoration.md` | 6,440 enchants offered on the realm: 4,331 should work, 903 need code (882 placeholders, 21 unsupported effects), 1,206 had no spell in the game data. |
| 2026-10-31 | same doc, progress table | 164 restored live; 4 tested; 399 broken left (+113 partly working); 1,206 missing. |
| 2026-11-01 | same doc, progress table (its last row) | 1,195 missing enchants rebuilt; 4 tested; 398 broken left (+112 partly working); 11 missing. |
| 2026-11-15 to 18 | commits and `enchants/*-history.csv` | Legendary and Epic batches (pull requests #164-#178), then a review against the core that removed doubled fixes. |
| **2026-11-22** | `enchants/tracker.csv`, counted by `scripts/tracker_summary.py` | 4,331 working (audit) / 27 verified / 653 live / 875 live (after restart) / 119 partly working / **424 broken** / 11 missing. 49 rows have a test entry (dates 31 Oct to 3 Nov). |
| **2026-11-22** | `enchants/test-checklist.csv` | 561 rows: 19 pass, 2 fail, 14 other (partial or notes), **526 with no result**. So "tested" means two different things: 49 tracker rows with a non-empty `tested` column; 35 of 561 checklist rows with a result. |
| **2026-11-22** | `enchants/legendary-history.csv` (305 copies) | 209 changed and awaiting an in-game test: 180 labelled so (177 plain + 3 worded variants) plus 29 labelled "unmerged", which is stale; 81 never changed, 5 tested, 1 needs a retest, 9 checked and left. |
| **2026-11-22** | `enchants/epic-history.csv` (1,710 copies) | 443 changed and awaiting a test (280 labelled so, plus 163 labelled "unmerged", stale), 1,141 never changed and "working (audit)", 80 still broken and untouched, 17 partly working and untouched, 28 tested, 1 needs a retest. |

Mismatches found on 2026-11-22 (state them; do not paper over them):

- The doc's last progress row (1 Nov) says 398 broken and 112 partly working; the tracker says 424 and 119. The doc
  row was never updated. Part of the gap is the 24 namesake teaches taken back out on 2-3 Nov (`767ca36`, `57c8c67`).
- The tracker itself lags: the 15-18 Nov batches mostly did not update its `status` and `fix file`. 33 Legendary
  rows still read `broken` there although the history file shows 31 of them changed since.
- The doc's recipe table still mentions file `010` (deleted 2 Nov, `34083eb`) and counts from 31 Oct.
- The honest headline: **most fixes are merged and untested.** "Restored" in this project means "a fix is live",
  not "confirmed in game".

Full numbers: [references/state-2026-11-22.md](references/state-2026-11-22.md) (read it when you need a count the
table above does not give).

## 3. Decision tree: given a broken enchant, which recipe?

Work top to bottom; stop at the first "yes".

0. **Does the core already do it?** Search the spell id in `enchants/core-overlap-review.csv`, then in the core's
   enchant tables and C++. Yes: do not add anything. If it still misbehaves, look in the `core-*-gaps.csv` files
   (a version of the ability the core's rule does not list is the usual cause).
1. **Is the spell missing on the server** (tracker `audit` = `missing`)? Recipe **R8** (rebuilt spell).
2. **Is there a twin that works?** (same name in the exported index, audit `standard` or `scripted`, and it can fire)
   - Twin carries an effect ours also has: **R2** (blank ours, then link).
   - Twin is a proc aura with no proc settings: **R3** (give it a `spell_proc` row, then link).
   - Twin teaches a working spell: **R5** (teach table).
   - Otherwise: **R1** (link). If the twin's text differs, add the id pair to the addon's `TooltipData.lua`.
3. **Does it teach or transform into a broken ability, and a working spell of the same name exists?** **R5**.
4. **Is the tooltip a plain modifier** (cost, cooldown, cast time, damage, crit of a named spell or school)? **R8**
   placeholder-to-modifier variant.
5. **Is it "school A raises school B and back"?** **R4** (all 21 known ones are done).
6. **Is it "while X is on you, you also have Y"?** **R7** (aura link).
7. **Does it already trigger the right spell, but on every hit, or a "next X" buff never gets used up?** **R9**.
8. **Is it "when you do X: cast Y, or cut or reset a cooldown", with at most a chance, a cooldown, a school and an
   aura condition?** **R6** (action table).
9. **Does it need memory** (stacks, sequences, "the last spell"), a new trigger the action table lacks (aura
   ending, stance change, kill, dodge), or a change inside the core's own formulas? SQL is not enough: section 6.
10. **Nothing fits, or the tooltip is only variables:** research first (section 1), record what you found in the
    tracker `notes`, and take it to James.

| Recipe | Tables you write | Needs a build? | Real example |
|---|---|---|---|
| R1 Working twin | `spell_linked_spell` (type 2, comment `WCME:...`) | No | `001-twin-links.sql`, `003-twin-links-close.sql` |
| R2 Twin, our duplicate removed | `wcme_owned`, `spell_dbc`, `spell_linked_spell` | No | `004-twin-links-dedup.sql` |
| R3 Twin given proc settings | `wcme_owned`, `spell_proc`, `spell_linked_spell` | No | `005-twin-procs.sql` |
| R4 School pair | `wcme_owned`, `spell_dbc`, `spell_proc`, `spell_linked_spell` | No | `002-school-pairs.sql` |
| R5 Teach a working spell | `wcme_enchant_teach` | Yes (in every build since build6) | `006-teach-twins.sql`, `008-teach-namesakes.sql` |
| R6 Action table | `wcme_enchant_action`, `spell_proc`, `spell_script_names` | Yes (since build6) | `007-enchant-actions.sql` part 1, `016-dead-triggers.sql` |
| R7 Aura link | `wcme_owned` (`aura_link`), `coa_mystic_enchant_aura_link` | No | `007-enchant-actions.sql` part 2 |
| R8 Rebuilt spell / placeholder to modifier | `wcme_owned`, `spell_dbc`, sometimes `wcme_spellaffect_dbc` | Flag-picked target: no. Named targets: yes. Client patch for the client to show it. | `009`, `011`, `012` |
| R9 Proc rules only | `wcme_owned`, `spell_proc`, sometimes `wcme_proc_target_cooldown` | No (per-target cooldown: yes, patch 63) | `014-consume-buffs.sql`, `015-runaway-procs.sql` |
| R10 Force in or out of the rolls | `wcme_enchant_override` | Yes (since build6) | none yet |

Step-by-step for each, with exact columns and pitfalls: [references/recipes.md](references/recipes.md) (read it
before writing the SQL).

### The pitfalls that have actually bitten

| Pitfall | What happens | Guard |
|---|---|---|
| Double bonus | Our spell and the twin (or the core) both give the effect. | R2; and check the core first. About 20 fixes were removed for this on 17-18 Nov. |
| Twin that never fires | A proc aura with no proc flags and no `spell_proc` row does nothing. | Check before linking; R3. |
| Blanked proc rules | Ascension kept chance, cooldown and trigger ability in its own database. An aura with proc flags and no row fires on every hit (file 015: 29 Legendaries by the commit's first line, 33 by its own breakdown of 7 + 2 + 24; `7a1f7a8`); one with no flags never fires (file 016). | Always write the `spell_proc` row from the tooltip. |
| Taught spells come from the client | The spell an enchant teaches is read from the client's `Spell.dbc` text. `spell_dbc` cannot change it. | `wcme_enchant_teach` (R5). |
| Triggered spells | Explosions, nova damage and channel ticks only set off a proc with `AttributesMask` 2. | Set it (R3). |
| Reused enchant ids | Two enchant ids are used by unrelated spells in our data. | Check the id is free; use the guarded insert (R8). |
| Replacing a core proc row | The core's rule reads its chance from that row; ours at 100% made it fire every time. | Never own a row the core ships for its own rule; `enchants/core-proc-row-replacements.csv`. |
| One version of the ability | Characters here can learn the stock or the CoA version of most abilities. | List every version in `spells`. |
| Watching the talent, not the buff | An aura link on a talent is permanent. | Watch the proc buff only (R7). |
| Heal hook order | The core passes healer and target in a different order for direct heals and for ticks. | Call `WcmeHealParties` first in any new heal rule (`enchants/epic-notes-header.md`). |

## 4. In-game test protocol

GM character, target yourself (`docs/enchant-restoration.md`):

| Command | Use |
|---|---|
| `.aura <enchant spell>` | Puts the enchant on you without a scroll. It also teaches the enchant's spell. |
| `.list auras` | Lists your auras; a linked twin shows up here. |
| `.unaura <spell>` | Removes it. |
| `.learn <spell>` | Gives you an ability to set the enchant off. |
| `.lookup spell id <spell>` | Clickable link, to read the tooltip. |
| `.additem <scroll item>` | The full path through the altar; scroll ids are in the tracker. |

**These are for James's GM test character.** A session does not send GM or console commands on the live realm
(including `additem` through the console) without his say-so: hard stops 1 (GM or console commands) and 2 (gives
items outside normal play), DOCTRINE.

| Test type (checklist column) | Do this | Pass means |
|---|---|---|
| `twin` | `.aura <ours>`; `.list auras` | The twin's id is listed, and the twin's tooltip effect happens. |
| `teach` | `.aura <ours>`; open the spellbook. Once per family use the scroll and altar instead. | The taught spell is there **and works when cast** (several "taught" spells were icon-only). |
| `school pair` | `.aura`; deal damage with each school | Each school gives the other's buff, and it stacks. |
| `action`, `proc` | `.aura`; use the named ability | The named effect happens at about the stated chance and no faster than the stated cooldown. |
| `aura link`, `link` | `.aura`; gain the watched buff | The granted buff is on only while the watched buff is. |
| `new spell`, `new spell (named targets)`, `modifier` | In the client first: `/run print(GetSpellInfo(<id>))` (nil = the client lacks the spell); `.aura`; use the named spell and one other spell of the same class | The named spell changes by the stated amount; the other does not. |
| `hook`, `kit`, `script`, `core...` | Follow the row's `commands` | What the row's `expected` says. |

A fix **passes when it does what its tooltip says** (the doc's definition). Record the result in the checklist's
`result`, then in the tracker's `tested` column as `YYYY-MM-DD pass: <what you saw>`. A failure is recorded the
same way and the status goes back to `broken` or `partly working`.

*Proposed practice (not yet adopted by James):* for every proc-type fix also run one negative check (an ability
the tooltip does not name must not set it off) and one check with the other learnable version of the ability.
Purpose: catch the two failures found only in review. Incidents: runaway procs (`7a1f7a8`), version gaps
(`enchants/core-rule-version-gaps.csv`, 261 rows to review).

What counts as evidence beyond this, and the tested inventory as a whole: **wildcard-validation-and-qa**.

## 5. SQL file conventions (`sql/enchants/`)

Numbering, as the 64 files stand on 2026-11-22 (no written rule; this is the observed pattern):

| Range | What it is for |
|---|---|
| `000-reset.sql` | Runs first. Creates our tables, removes every row we own. |
| `001`-`013` | First wave, one file per recipe batch (010 was retired on 2 Nov). |
| `014`-`019` | Proc repairs (used-up buffs, runaway procs, dead triggers), bindings for scripted enchants, tooltip review. |
| `020`-`046` | Legendary batches. |
| `047`-`053` | Epic batches. |
| `054` | Base spells that reviewed enchants depend on. **Next free enchant number: 055.** |
| `090`, `095` | Not enchants: MySQL settings (`SET PERSIST`). They change the whole database server; the reset does not undo them. |
| `100`-`130`, `160`, `161` | Not enchants: world data riders (rune rates, caches, battleground rows, a currency row, a vendor). Their headers say what they are. The reset does not undo them (item 3 below). |
| `140` | Talent fixes (pairs with `patches/55-talent-fixes.ps1`). |
| `150` | **Generated** by `client-patch/custom_spells.py`. Never edit by hand; change the generator and regenerate. |

The contract:

1. **Marker and ownership.** A row we add to `spell_linked_spell` has a `comment` starting `WCME:`. A row we add to
   `spell_dbc`, `spell_proc` or `coa_mystic_enchant_aura_link` is registered in
   `wcme_owned (tbl, id)` with `tbl` = `spell_dbc`, `spell_proc` or `aura_link`. Our own tables are named `wcme_*`.
2. **`000-reset.sql` every start.** It deletes `WCME:` links, every owned row, every `spell_wcme_%` script binding,
   empties `wcme_enchant_teach`, `wcme_enchant_override`, `wcme_proc_target_cooldown`, `wcme_enchant_action`,
   `wcme_spellaffect_dbc`, and finally empties `wcme_owned`. The files after it put back exactly what the
   repository holds. So: delete a file and its fix is gone at the next start.
3. **Limits of that promise: the files the reset cannot undo.** This list is the one home for the whole skill
   library (verified by reading all 64 files on 2026-11-22; detail per file in
   [references/reset-limits.md](references/reset-limits.md), read it before deleting or reverting any of these):
   - **(a) Outside the reset's tables (8 files):** `090`, `095` (MySQL `SET PERSIST`, server-wide), `100`, `110`,
     `120`, `130`, `160`, `161`. Deleting the file leaves its change in place.
   - **(b) A core row changed in place (1 file):** `026` (ORs a bit into the core's `spell_proc` row -44445).
   - **(c) Core rows removed, or replaced by a row we own, so deleting the file does not bring the stock row
     back:** `027` (deletes the core's script binding `aura_wildcard_nether_portal`; also owns 1181360), `140`
     (owns the stock Backdraft row -47258), and the replaced core `spell_proc` rows in `005` (55441), `018`
     (1570700), `020` (1181400).
   - **Not on the list:** `013` (its `UPDATE spell_proc` hits row 282881, which `007` inserts and owns).
   To undo one of these, write the reverse statement in a new file. One-off copies of the original tables are
   kept as `wcme_backup_spell_linked_spell` and `wcme_backup_spell_proc`. Prefer inserts you own; where a core row
   must change, say so in the file header.
4. **Idempotent.** Every file must give the same database when run twice. Patterns that achieve it: register in
   `wcme_owned` then `DELETE ... WHERE id IN (...)` then `INSERT`; `INSERT IGNORE`; `REPLACE INTO` for a core row
   restored as shipped; "Safe to run again" stated in the header of non-enchant files.
5. **A later file wins.** When a later file takes over an enchant, it deletes the earlier file's rows for it
   (`DELETE FROM wcme_enchant_action WHERE enchant_spell = ...`) or, better, the earlier file is edited.

How the files reach the database (`patch-night/PatchNight.ps1`, functions `FetchRepo` and `ApplyEnchantFixes`):

- Every run (weekly patch night, the nightly restart, `Start-Server.cmd`) downloads the **`main` branch** as a zip
  and copies `sql/enchants/*.sql` to `patch-night\enchants`. An unmerged branch is never applied.
- After MySQL is up and before the world server starts, each file is piped, in name order, to `mysql.exe` against
  the world database named in `worldserver.conf` (`WorldDatabaseInfo`), using `mysql\admin-client.ini`.
- Log lines in `patch-night\patch-night.log`: `Applied enchant fix <file> to <db>.` or
  `Enchant fix <file> failed: <error>` at level WARN.
- **A failed file does not stop the start.** MySQL stops that file at its first error (the rest of the file is not
  run), patch night logs the WARN and goes on to the next file, and the server comes up with half a fix. Read the
  log after every restart that carries new SQL.
- Tooltip id pairs ship in the WildcardEnchants addon, which the same run copies into the VM's client folder.

**Sequencing warning.** SQL goes live at the next restart; C++ goes live only when a new build is installed (the
weekly patch night or a run by hand). Times and the full table: `wildcard-run-and-operate`, "When does my merged
change go live?". A file that binds a `spell_wcme_*` script, or removes an old rule in favour of one, takes effect before the
build that contains the script: "unknown script names are only logged" (`017` header), so the enchant does nothing
in between. Say in the file header which build it needs, and tell James in the pull request.

Pre-flight before opening a pull request:

```
python3 -I .claude/skills/ascension-restoration/scripts/enchant_sql_lint.py
```

`enchant_sql_lint.py` is the **authority for reset and ownership modelling of `sql/enchants`**; the full
pre-merge check set, and which script wins for which check, is in `wildcard-validation-and-qa`. It replays all
files twice against a model of the keys we add and reports duplicate keys, inserts the reset would not clear, links without the `WCME:` marker, and statements it cannot model. Tested 2026-11-22: 64 files, 0 errors;
a deliberately broken file was caught on all four counts. It knows nothing about rows the core ships, so it does
**not** replace the scratch-database run.

Scratch-database run ("run it twice on a scratch database", `docs/enchant-restoration.md`). The repo does not
write down how; this is a *proposed procedure (not yet adopted by James; written but not executed on 2026-11-22)*:

1. Use a test server's database if there is one (the audit script expects Docker containers named `ac-database`
   and similar). On the VM, ask James first: it is the live MySQL server.
2. Create a database `wcme_scratch`. For each of `spell_dbc`, `spell_proc`, `spell_linked_spell`,
   `spell_script_names`, `coa_mystic_enchant_aura_link` and every existing `wcme_%` table:
   `CREATE TABLE wcme_scratch.t LIKE <world>.t; INSERT INTO wcme_scratch.t SELECT * FROM <world>.t;`
3. Run `000` to `054` plus your new file, in name order, with `--database=wcme_scratch`. **Leave out 090 and 095**
   (they set server-wide MySQL options) and the 100+ riders (they need tables you did not copy).
4. Record `CHECKSUM TABLE` for the copied tables. Run the same files again. Every file must exit 0 and every
   checksum must match the first run.
5. Drop `wcme_scratch`.

## 6. When SQL is not enough

Hand the C++ to **wildcard-patch-authoring**; classify with wildcard-change-control first (server C++ scores
higher on likelihood, and a mistake costs a 2-3 hour build). What already exists to build on:

| Route | File | What it gives you |
|---|---|---|
| Action handler | `patches/mystic-enchants-actions.patch` (`WcmeEnchantActions.cpp`, script `spell_wcme_enchant_action`) | The data-driven rules of R6. A new **trigger or action kind** (kill, dodge or parry taken, aura removed, stance changed) is added here once and then used by rows. |
| Enchant scripts | `patches/mystic-enchants-scripts.patch` (`WcmeEnchantScripts.cpp`, about 14,500 lines) registered by `patches/64-enchant-scripts-loader.ps1` | One script or hook per enchant that needs memory or checks. Each is bound in `spell_script_names` by an SQL file (`017` onwards) and usually needs a `spell_proc` row. Many are "hooks only" with no rows. |
| Realm plumbing | `patches/mystic-enchants-wildcard.patch` | Enchants on Wildcard at all (`CoA.MysticEnchants.AllowWildcard`), the missing and dud filters for scroll rolls (`SkipMissingSpells`, `SkipDudSpells`), `wcme_enchant_teach`, `wcme_enchant_override`. |
| Named modifier targets | `patches/mystic-enchants-spellaffect-sql.patch` | Loads `wcme_spellaffect_dbc` into the server's SpellAffect data (R8). |
| Per-target proc cooldowns | `patches/63-enchant-target-cooldowns.ps1` | `wcme_proc_target_cooldown`. |
| Core hooks for single enchants | `65` (PvE / PvP damage auras), `66` (Hot Hands, Temporal Shift), `67` (Hoplite), `68` (Aspect of the Fox), `69` (Iron Guard), `70` (Mastery of the Tide), `71` (jump multiplier in percentage points) | The pattern for "the core's own formula has to change": the smallest possible edit at one anchor, keyed on the enchant's aura id. |
| Whole families | `patches/78-worldforged-enchants.ps1` (the 990 rare worldforged enchants and their drops, `Wildcard.WorldforgedDropChance`), `patches/79-mystic-enchant-gold-cost.ps1` (`Wildcard.MysticEnchantGoldCostPct`) | Examples of a family solved in one place instead of 990 rows. |

Before proposing new C++, check the doc's "Next candidates": most remaining groups are unlocked by **one generic
handler each**, not by one script per enchant.

## 7. Tracker discipline

- `enchants/tracker.csv` is the per-enchant record: one row per enchant spell, 12 columns
  (`spell, name, quality, scroll item, audit, family, status, fix, twin, fix file, tested, notes`).
- `enchants/test-checklist.csv` lists what to type and what should happen for each fix.
- `enchants/legendary-notes.md`, `epic-notes.md`, `legendary-history.csv`, `epic-history.csv` are **generated** by
  `scripts/legendary_history.py` from the tracker, the checklist, `<tier>-notes.csv`, the SQL headers, the script
  comments, the commit history, the pull requests and the release tags. Edit the inputs, never the outputs.
  It needs the GitHub CLI signed in and a local branch named `main`.
- Eight `core-*.csv` and related review files each answer one question about overlap with the core.

Columns, every allowed value, how to regenerate, and what each review file answers:
[references/tracker-and-review-files.md](references/tracker-and-review-files.md) (read it before you edit any of them).

## 8. A new batch, end to end

- [ ] **Pick.** `python3 -I .claude/skills/ascension-restoration/scripts/tracker_summary.py`; choose one group
      from section 10 or one recipe's worth of rows. Small batches: one recipe, one file.
- [ ] **Research.** For each enchant: client tooltip, exported data, builder, core. Run the decision tree.
      Write down source and assumptions as you go. Outliers to James before you write anything.
- [ ] **Check the core** (`enchants/core-overlap-review.csv`, then the core's tables and C++).
- [ ] **Classify with wildcard-change-control.** State the class and why in the pull request.
- [ ] **Write** `sql/enchants/055-<name>.sql` (next free number) with a plain-English header; no tooltip text,
      in comments **or in data columns** (leave description columns empty or use your own words: recipes R2, R8).
- [ ] **Lint**, then **run twice on a scratch database** (section 5).
- [ ] **Records in the same branch:** tracker rows (`fix`, `twin`, `fix file`, `status`), a checklist row per
      enchant, notes rows for Legendary and Epic, the `Database` section of `CHANGES.md`, `TooltipData.lua` if a
      twin's text differs. Regenerate notes and history if you can run the generator.
- [ ] **Pull request.** The repository's written rule is one pull request per patch night (`CHANGES.md`); in
      practice each enchant batch has been its own pull request, several a day. Follow what James asks for this
      batch. List per enchant: what it does now, source, assumptions, what it needs (build, client patch).
- [ ] **James merges.** SQL applies at the next start; anything needing C++ waits for the build to be installed.
- [ ] **After the restart:** in `patch-night.log`, find `Applied enchant fix 055-...` and no `failed` line.
- [ ] **Test in game** (section 4). Record result and date in the checklist and the tracker; set `verified` only
      on a pass.
- [ ] **Follow up** failures as their own change; do not leave a row saying `live` when the test failed.

## 9. Talents and racials

Talents are restored the same way, in `patches/55-talent-fixes.ps1` plus `sql/enchants/140-talent-fixes.sql`
(one shipped so far: Backdraft, issue #152). Racials are James's own designs (`docs/race-kits.md`), built with
the same machinery: one patch per racial and our own spells generated into `150-custom-spells.sql`.
Issues #148-#151 are open with no fix (as read from the GitHub issue page on 22 Nov, not re-checked through the
API; all opened 14 Nov by JaTynan, labels talent + warlock): #148 Demonic Recurrence (272730) does nothing; #149
Demonic Persistence (276506) does nothing; #150 Nemesis (63123): no second Hand of Gul'dan cast; #151 Master
Summoner (18710): Wild Imps do not last longer.

The Backdraft worked example, a "how you would start" plan for each open issue, and the racial file map:
[references/talents-racials-and-open-issues.md](references/talents-racials-and-open-issues.md) (read it when the
broken thing is a talent or racial, or you pick up one of those issues).

## 10. Remaining work

From `docs/enchant-restoration.md`, "Next candidates". **This table was written on 2026-11-01** and has not been
updated since; the Legendary and Epic batches of 15-18 Nov fixed some of what it counts, so treat the counts as
upper bounds and recount from the tracker before planning. Counts are for the whole realm list, with the
Area 52 part in brackets.

| Group | Count | What it needs |
|---|---|---|
| Extra damage under a condition (target has your aura, health above or below a mark, stealth, a form) | 32 (18) | One generic C++ handler: a table of enchant, spells or school, condition, percent, applied in the damage hooks |
| Melee auto attacks deal extra damage as a school | 6 (6) | The same handler with an auto-attack rule |
| Cooldown cut or reset on an event the action table cannot see (aura ending, stance change) | about 20 (12) | New triggers for the action handler |
| Teaches or transforms into an ability we do not have | 43 (32) | Client patch (new spells) or a namesake, case by case |
| Procs with a chance | 62 (24) | Action table rows, read by hand from each tooltip |
| Everything else | about 360 (94) | One-off C++; many have tooltips made only of variables and need research first |
| Missing, not simple | 11 (11) | Read by hand |

Also open on 2026-11-22, and not in that table:

- **Testing.** 526 of 561 checklist rows have no result. This is the cheapest progress available and needs no build.
- **Review queues:** 261 core rules missing a learnable version, 54 taught-spell doubles (decision made, work
  queued), 21 "refresh aura" spells, 19 tooltip swaps whose own effect may also fire, 7 core rule gaps.
- **Tracker catch-up** for files 015-054, and a regeneration of the history files from `main`.
- **New Death Knight enchants** are a proposal only (`docs/dk-enchant-proposal.md`): twenty hybrid and nine pure
  drafts with first-guess numbers. They are new designs, not restoration, and need new client data.

## Provenance and maintenance

Written 2026-11-22 from the checkout at `fcfee51` (PR #232's head: `62a26e4`, the #230 merge, plus two commits
adding `.claude/agents/` and `docs/agents/`; `origin/main` `d3e030f`, #231, differs only under `signup/`) and
the upstream core at `c3f2fd4` (19 Nov 2026). Not re-verified on the VM that day: log line texts and paths come
from `patch-night/PatchNight.ps1` and the docs. Issue titles for #148 to #151 come from one read of the GitHub
issue page on 22 Nov (no API access); the repository itself names only #148 and #149. The scratch-database procedure and `scripts/legendary_history.py` were not executed.

Re-verify what may drift (run from the repository root):

| Fact | Command |
|---|---|
| Tracker and checklist counts, review queues | `python3 -I .claude/skills/ascension-restoration/scripts/tracker_summary.py` |
| SQL folder still re-runnable | `python3 -I .claude/skills/ascension-restoration/scripts/enchant_sql_lint.py` |
| File list and next free number | `ls sql/enchants` |
| What the reset removes | `cat sql/enchants/000-reset.sql` |
| Files the reset cannot undo (section 5, item 3) | `grep -l "SET PERSIST\|item_template\|spell_area\|npc_vendor\|currencytypes_dbc\|loot_template\|quest_template" sql/enchants/*.sql`; `grep -n "44445\|nether_portal\|47258" sql/enchants/*.sql`; `cat enchants/core-proc-row-replacements.csv` |
| How patch night applies the files; failure handling | `grep -n -A16 '^function ApplyEnchantFixes' patch-night/PatchNight.ps1` |
| Branch that is downloaded | `grep -n 'archive/refs/heads' patch-night/PatchNight.ps1` |
| Patch night day and times | `grep -n 'Day =\|Time =' patch-night/Register-PatchNight.ps1` |
| Action table columns and actions | `sed -n 31,46p patches/mystic-enchants-actions.patch` |
| Tables the wildcard patch reads | `grep -n 'wcme_\|CoA.MysticEnchants' patches/mystic-enchants-wildcard.patch` |
| History generator options | `python3 -I scripts/legendary_history.py --help` |
| "Next candidates" table still dated 1 Nov | `git log --format='%h %ad %s' --date=short -- docs/enchant-restoration.md \| head -3` |
| Stale "unmerged" labels | `grep -c 'unmerged branch' enchants/legendary-history.csv enchants/epic-history.csv` |
| Open talent issues | `gh issue list --repo JaTynan/coa-wildcard-mystic --state open` |
| Table keys in the core | `grep -n 'KEY' data/sql/base/db_world/spell_proc.sql` in a clone of `Corfirean/azerothcore-wotlk-coa` |
| Risk class of an enchant SQL fix | `grep -n 'Standard changes' -A3 docs/agents/context/change-risk.md` |

When you change this skill: replace `references/state-2026-11-22.md` with a new dated snapshot rather than editing
numbers in place, and update the "Current state" table from it.
