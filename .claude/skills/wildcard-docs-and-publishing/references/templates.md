# Templates

Copy, fill in, delete the hints. Text in `<angle brackets>` is for you to replace.

Rules for every template: plain English; what the player sees first; measured numbers; no secrets, no client data,
**no tooltip text copied word for word** (say what the tooltip says in your own words); no player or account names.

Status labels: **Current practice** = the repository already does this. **Proposed practice (not yet adopted by
James)** = good practice suggested here, with its purpose; not a rule until James says so.

---

## A. `CHANGES.md` row (current practice)

A new patch gets one row in the "Code patches" table. Three columns: script, change, setting.

```
| `<NN-name.ps1>` | <What the player or operator now sees, with the numbers>; <what it was before, if that helps> | `<Setting.Name>` |
```

- Column 3 is the setting that turns it off or tunes it, or `always on`, or `—` when there is nothing to set.
  CHANGES.md: "Every new code change gets a setting to turn it off where that's practical".
- A script that holds several changes gets one row per change; leave column 1 empty on the extra rows (see the
  `20-bots.ps1` rows).
- Say when a change needs something else: "(with `sql/enchants/140-talent-fixes.sql`)", "buff icons from the client
  patch".
- A later change to the same feature edits its row and may carry a date in brackets: "(21 November; replaced ...)".
- Rows are not kept in number order in the file today. Add yours next to its neighbours by topic or at the end of the
  table; do not reorder the table in the same PR.

A new SQL file gets one sentence in the "Database" section:

```
`<NNN-name.sql>`: <what it does for players, in one or two sentences> (<which patch uses it, if any>).
```

Good examples already in the file: the rows for `94-dungeon-finder-join-limit.ps1` (symptom, cause, new limit) and
`77-resting-mana-regen.ps1` (what, when, what is unchanged, the setting and its stock value).

---

## B. Commit message (current practice, derived from the history)

```
<Area>: <what changed, in the player's or operator's words> (<old value or setting name, if short>)

<The symptom, with numbers or the exact error text, and when it was seen.>
<The cause, in one or two sentences.>
<What this commit changes.>
<How it was checked, and the result. What is not done or still a guess.>

<the attribution lines your session was given>
```

- Area: a thing James or a player would name (`Bots`, `Build`, `Settings`, `Patch night`, `Race kits`, `Website`,
  `Linux launcher`, `AI chat`, or the ability's own name). Not `feat:` or `fix:`.
- No full stop on the subject. It may run long if the detail earns it.
- Wrap body lines (the history wraps anywhere from about 72 to 115 characters), or use a short `-` list when one commit does several things
  (`git show -s 9ba9f45`).
- When James reported the problem, say so: "James: worst ticks of 2-5 seconds with 2 players on" (`6a3e017`).
- A measuring-only change says so: "Nothing changes how the server runs." (`9ba9f45`).

Worked examples to read before writing your first one:

```
git show -s d802f8c    # a speed-up: before and after times, and how sameness was proven
git show -s 01159e2    # a start-up failure: the error text, the cause upstream, the fix, the check
git show -s 52a235a    # a two-line fix found by an in-game test
```

---

## C. Pull request description (**proposed practice, not yet adopted by James**)

Purpose: the reviewer and James should be able to decide from the description alone, on a phone. Builds take about 3½
hours, so anything that lets a problem be seen before the build is worth writing down. The risk block's format is
doctrine (`docs/agents/context/change-risk.md`, "What the analyst returns"); pasting it into the PR, and the test and
rollback sections, are the proposal. What existing PR descriptions look like could not be read on 2026-11-22, so
compare with a few recent ones first (`gh api repos/JaTynan/coa-wildcard-mystic/pulls/<n> --jq .body`) and keep
whatever James already expects.

**Title:** the line players will read on the website. See SKILL.md section 4.

```
## What players will notice
<One to three plain sentences. "Nothing" is a fine answer.>

## Why
<The symptom and its evidence: who saw what, when, the numbers, the log line or error text. Then the cause.>

## What changed
- <file or area>: <what, in plain words>
- Docs updated: <CHANGES.md row / server-settings comment / tracker / none needed, and why>

## Enchants touched (only for enchant PRs)
- <Enchant name> (<spell id>): <what it does now, in your own words>. Assumption: <any number or rule you chose
  without a source>. Source: <builder archive / client spell data / similar ability / guess>.

## Test evidence
- Before the build: <what was checked without a build, and the result. E.g. patch script applied against the pinned
  sources; SQL run twice on a scratch database; settings check.>
- After the build / in game: <what was tested, by whom, when; or "not yet tested: needs <what>">
- Not tested: <say what, plainly>

## Risk (from the change-risk analyst)
Change: <PR number>
Hard stop: none | <which>
Impact: I1 n, I2 n, I3 n, I4 n -> <low|medium|high>
Likelihood: L1 n, L2 n, L3 n, L4 n, L5 n, L6 n = total -> <low|medium|high>
Class: LOW | MEDIUM | HIGH        Confidence: high | low (why)
Path: <from the table>
Evidence: one line per score that is not 1

## Rollback
<One line. Pick the true one and fill it in:>
- Setting: set `<Setting.Name>` back to `<old value>`; applies at the next restart.
- SQL: revert this PR; `000-reset.sql` removes the rows it owns at the next start. (The files the reset cannot undo
  and core rows changed in place need a reverse statement: list in `ascension-restoration` section 5 item 3.
  A settings line that was added needs the old value set, not the line removed.)
- Patch: revert this PR; the evening build and the next 3:30 am patch night take it out; until then <turn it off with `<Setting.Name>` / reinstall the
  previous build / Restore-Official.cmd>.
- Cannot be undone: <what is already changed, and what limits the damage>.

Needs: <a new build | the next patch night only | a client patch rebuild | nothing>
Changelog: <a plain line for players | skip>
```

Notes:

- The "Enchants touched" lines are worth the care: the notes generator quotes PR description lines that name an
  enchant by name or id into `enchants/<tier>-notes.md`.
- Get the risk block from the `change-risk-analyst` agent, or fill it in by the matrix yourself and say you did.
  Never write a class to get a PR through: "score the change as written".
- The `Changelog:` line must start at the beginning of its own line. Leave it out when the title already is the
  player line.
- Keep the description free of anything private: it is public the moment the PR is opened.
- James merges. A description never authorises a merge.

---

## D. Enchant notes entry (current practice)

Three places, then regenerate.

**1. `enchants/tracker.csv`**, the enchant's row. Columns: `spell,name,quality,scroll item,audit,family,status,fix,twin,fix file,tested,notes`.
Change only `status`, `fix`, `twin`, `fix file`, `tested`, `notes`.

```
fix:      <how it was fixed, in a few words: "linked to working twin, own duplicate effect removed (spell_dbc)">
fix file: <the SQL file or patch: 004-twin-links-dedup.sql>
tested:   <YYYY-MM-DD> <pass|fail>: <what you did and what happened>
```

`tested` starts with the ISO date, because the generator reads dates from it to decide "changed after its last test,
retest needed". An existing value to copy: `2026-10-31 pass: Ice Block resets Frost Nova`. Write failures too.

**2. `enchants/<tier>-notes.csv`** (`legendary` or `epic`). Columns: `spell,verdict,assumptions,sources,decisions,tooltip_review`.

```
<spell id>,<verdict or empty>,"<Each thing decided without a source: a number, a radius, how two effects interact.>","<Where the design came from: Ascension builder tooltip (area-52 archive, 14 Jun 2026); our client spell data (Spell.dbc); similar ability <name>; player description>","<Decisions James made, with the date>","<Where what the tooltip says and what the server does differ, for later review>"
```

- Assumptions are the point of the file. "Workable best guess" is allowed; an unrecorded guess is not.
- Describe what the tooltip says; do not paste it.
- Sources in the order of trust the project uses: client tooltip, then designer intent, then similar abilities, then an
  educated guess. Sibling `ascension-restoration` owns that rule.

**3. `enchants/test-checklist.csv`** if the fix is not yet tested. Columns: `file,spell,name,scroll item,test type,commands,expected,result`.
Add a row with the GM commands and what should happen; leave `result` empty for the tester.

**4. Regenerate** (SKILL.md section 2) and commit the generated files in the same PR.

---

## E. Performance measurement row (`docs/performance.md`)

The existing table (current practice):

```
| Setup | Ticks/s | Average | 95% under | Peak | VM memory |
| <bots>, <map threads>, <anything else that differs> | <n> | <n> ms | <n> ms | <n> ms | <n> GB |
```

Under a dated heading: `## Measured (<D Mon YYYY>)`. Then one or two sentences: what was decided and why
("Settled on 1,250: the 95% figure is close to 1,500's, but the spikes players feel are a third as large").

**Proposed practice (not yet adopted by James):** add what makes a row comparable later. Motivation: the numbers
behind the last two bot-count changes (1,250 to 1,000 on 9 Nov, then to 750 on 21 Nov) were taken with different
numbers of players on (3, then 2) and are recorded only in comments (`server-settings.txt` lines 505-506), so they are
hard to set beside the 7 Nov table. Either as extra columns or in the sentence under the table:

```
Players on: <n>. Measured for: <minutes>, starting <time>. Build: <wcme-... tag>. Core: <first 8 of the revision>.
Source: <the manager's world-speed panel | Logs/Timing.log | Logs/perf CSV>. Worst single tick: <n> ms.
```

This template is the one home for the proposed row shape. Two sibling skills need extra fields in it, both
Proposed practice (not yet adopted by James): `wildcard-diagnostics-and-tooling` asks for "records with a pass of
1 s or more" and "covered" (the share of each minute the Timing.log records saw); `wildcard-lag-spike-campaign`
asks for records, coverage, median, windows with a tick of 500 ms or more, and the beat period. Add them as
columns of the same table rather than inventing a second shape.

Rules:

- Change one thing between two rows, or say that more than one thing changed.
- A number without its conditions is not a measurement. Leave a cell empty instead of estimating (the 1,250 row's
  memory cell is empty).
- How to take the measurement: sibling `wildcard-diagnostics-and-tooling`.

---

## F. Case file (doctrine: use the repository's own form)

Do not copy the form here. Copy `docs/agents/case-file-template.md` to
`docs/agents/cases/YYYY-MM-DD-short-title.md` and fill it in.

How to fill it well:

- **Question:** one sentence that can be answered with a decision. "Should patch 93 keep its per-map cache?" not
  "Thoughts on patch 93?".
- **What we know:** every fact with where it came from: file and line, log line with its time, PR number,
  measurement. Fable reads only this file and what it links to.
- **What we don't know:** the gaps, and what would close each.
- **Options:** two to four, each with cost and risk. "Do nothing" counts.
- Under two pages. No secrets, no client data, no tooltip text word for word.
- After the ruling: write it back into the case file; if it is a rule others can apply, add it to the matching
  context pack (hard stop 6: that edit waits for James); add a line to `docs/agents/fable-ledger.md`:

```
| <YYYY-MM-DD> | <role> | <case file or PR> | <what it was for> | <yes: what changed | no> |
```

---

## G. Incident review (PIR) (**proposed practice, not yet adopted by James**)

Purpose: when something breaks for players (server down, a failed build installed, lost progress, a bad lag night),
write one page so the cause is fixed for good and the next session does not rediscover it. Today the same facts end
up scattered across commit messages. Example of an incident that had no single record: build57 stopping at start-up
on 19 Nov 2026 ("Duplicate blank sub-command"; `git show -s 01159e2`, fixed by #187).

No blame. One page. Suggested home: `docs/incidents/YYYY-MM-DD-short-title.md` (the folder does not exist; creating
it is part of the proposal).

```
# Incident: <short title> (<D Mon YYYY>)

- **Written by:** <who>, <date>     **Status:** open | closed
- **Impact:** <who was affected, for how long. E.g. "server down 02:10 to 02:55; nobody online">
- **Against the targets:** downtime <n> min (target: about 30); data lost <n> min (target: about 15)

## Symptom
<What players or James saw, in their words. The exact error text or log line.>

## Timeline (Sydney time)
| Time | What happened | Source |
|---|---|---|
| <hh:mm> | <event> | <patch-night.log line / commit / PR / James> |

## Root cause
<The one cause that, removed, would have prevented it. Then any contributing causes.>

## Evidence
- <log line with its time, file and line, commit, PR, measurement>
- <what was ruled out, and how>

## Fix
- Immediate: <what restored service, by whom, when>
- Permanent: <PR number and what it changes; or "none yet">

## What would have caught it earlier
<The check that would have stopped this before players saw it, and where it would run: before the build, in the
build, at start-up, after patch night.>

## Follow-ups
| Action | Owner | Due | Done |
|---|---|---|---|
| <one concrete action> | <who> | <date> | <PR or date> |
```

Rules:

- The timeline uses only facts with a source. Mark anything remembered and not recorded as "(from memory)".
- "Human error" is not a root cause. Ask what let the mistake through.
- Follow-ups that change the server go through `wildcard-change-control` like any other change.
- The lasting record of what was tried and failed lives in sibling `wildcard-failure-archaeology`; link the review
  from there.

---

## H. Bug report to an upstream project (**proposed practice, not yet adopted by James**)

Purpose: CHANGES.md says fixes that are really CoA bugs are worth reporting, and that a fix upstream lets us delete
our patch. No report had been sent by 2026-11-22, so there is no house format yet. **Draft only; James sends it or
says who does.** Check the project's README for where it wants reports.

Before drafting, confirm all three:

- [ ] It happens on their **unpatched** code: seen on the official world server, or read in their source at the pinned
      commit. State which.
- [ ] It is not caused by, or only visible with, our patches, settings or SQL.
- [ ] You have exact steps and the exact versions.

```
Title: <What goes wrong, in their terms> (<area: e.g. LFG, Wildcard rolls, playerbots>)

**Version**
- Server release: <server-0.YYMMDD.NN, from the manager>
- Core commit: <40-character commit of Corfirean/azerothcore-wotlk-coa, from BUILD-INFO.txt>
- Module and commit, if it is a module bug: <e.g. Zyth45/mod-playerbots <tag> <commit>>
- Realm type and settings that matter: <e.g. Wildcard realm; only the settings needed to reproduce>

**What happens**
<Two or three sentences. The exact message or log line.>

**What should happen**
<And why you think so: stock 3.3.5 behaviour, their own docs, or the code's evident intent.>

**Steps to reproduce**
1. <step>
2. <step>
3. <result>

**Where in the code** (if known)
<File and function at that commit, and one or two sentences on the cause. Link to the lines on GitHub.>

**A fix that works for us** (optional)
<Describe the change in words, or attach a small diff against their file. Say it is offered as-is.>

**Context**
A personal server running your release with a few changes on top; this was reproduced without them.
```

Rules:

- Be brief and polite; these are volunteers. One bug per report.
- Their code, their terms: a diff against their file is a change to their code. Do not paste whole patch scripts of
  ours, client data, tooltip text, player names or log lines holding addresses or account names.
- Do not ask them to support Mystic Enchants on Wildcard or anything else we added.
- After sending: note it on the patch's `CHANGES.md` row, "(reported upstream: <link>, <D Mon>)".
- A patch whose `CHANGES.md` row describes a core mistake is a candidate, for example
  `94-dungeon-finder-join-limit.ps1` (the core dropped join requests listing more than 50 dungeons) and
  `71-jump-multiplier-points.ps1`. Candidates only: each still needs the three checks above.
