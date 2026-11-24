---
name: wildcard-docs-and-publishing
description: Writing and publishing rules for the public Wildcard server repository (JaTynan/coa-wildcard-mystic). Covers the docs of record (README, CHANGES.md, docs/, enchants/ trackers and notes, docs/agents/), which change must update which doc, house style for commit messages, PR titles and plain-English docs, how a PR title becomes the website's "What's new" line and the "Changelog:" override, templates (CHANGES row, commit, PR description with risk block, enchant note, incident review, upstream bug report), public-repo rules (no secrets, no client data, no verbatim tooltip text, third-party addons as pinned downloads, licences and credits), and the pre-push check public_repo_check.py. Load it at the moment of writing a commit message, PR title or description, a doc, CHANGES.md row, release note, website text or a bug report to CoA or SQUID; when asked "which doc do I update" or "can this go in a public repo"; and before editing a skill or agent instruction. Not needed to make the change itself.
---

# Wildcard: docs and publishing

Use this skill whenever you are about to **write something a person will read** (a doc, a commit message, a pull
request, a website line, a bug report to another project) or **publish something** (push to this repository).

Three facts shape everything below:

1. **The repository is public.** Anything pushed can be read by anyone, for good. So can pull request text and
   GitHub issues.
2. **Pull request titles are shown to players.** The website's "What's new" box is built from them (section 4).
3. **James is not a professional developer and reads on his phone** (`docs/agents/context/patch-night.md`, "Rules").
   Plain English, short, the result first.

Words used here, defined once:

- **Doc of record**: the one file that is the agreed home for a kind of fact. If two files disagree, the doc of
  record wins and the other gets fixed.
- **Generated file**: a file a script writes. Never edit it by hand; edit its inputs and run the script.
- **Patch night**: the scheduled job on the server PC that updates and restarts the server
  (`patch-night/PatchNight.ps1`). Details: sibling skill `wildcard-run-and-operate`.
- **Build**: compiling the patched world server on GitHub Actions. It takes **about 3½ hours**
  (builds 61 to 74: 3h30 to 3h45; `docs/agents/context/patches.md` says 2 to 3 hours and README "about 1.5-3
  hours", both out of date).
- **Upstream**: the projects this one is built on top of (section 8).
- **Hard stop**: one of eight kinds of change that always wait for James, whatever their risk score
  (`docs/agents/context/change-risk.md`, Step 1). Sibling skill `wildcard-change-control` is the home for them.
- Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

> Status note (updated 24 Nov 2026): `docs/agents/` and `.claude/agents/` came with PR #232, merged on 22 Nov 2026
> (`0802d4f`), so everything cited from them below (hard stops, the risk block, the case-file form, `patches.md`) is
> **DOCTRINE**. Status words used here: DOCTRINE (README, CHANGES.md, docs on `main`) / PRACTICE (what history shows) / NOT BUILT YET / Proposed practice (not yet adopted by
> James) / UNVERIFIED / OPEN.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Decide the risk class or path of a change, or whether you may merge | `wildcard-change-control` |
| Write or port a patch script, or pick its number | `wildcard-patch-authoring` |
| Add a setting or learn the settings file format | `wildcard-settings-and-flags` |
| Fix an enchant, choose a recipe, or learn the tracker columns in depth | `ascension-restoration` |
| Take a measurement or read a log | `wildcard-diagnostics-and-tooling` |
| Decide what counts as tested | `wildcard-validation-and-qa` |
| Change the launcher, website, sign-up service or the bug-report relay | `wildcard-client-and-web` |
| Understand the build or `BUILD-INFO.txt` in depth | `wildcard-build-and-env` |
| Run or repair patch night | `wildcard-run-and-operate` |
| Find out what was tried before and why it failed | `wildcard-failure-archaeology` |

This skill tells you how to **write it down and publish it safely**. It never authorises a change: for anything that
changes how the server behaves, classify with `wildcard-change-control` first. James merges.

## Start here

1. Writing a commit or PR: section 3 (style), section 4 (the title is shown to players), template B or C.
2. "Which doc do I update?": section 1.
3. "Can this go in a public repo?": section 6, then run `scripts/public_repo_check.py` before the push.
4. Editing a skill or an agent file: section 9 first (hard stop 6).

## 1. Which doc do I update? (trigger -> doc)

Do the doc update **in the same pull request as the change** (PRACTICE: most history does this; CHANGES.md asks for
the `CHANGES.md` line but states no "same PR" rule). A change without its doc line is half done.

| You did this | Update this, in the same PR | Source of the rule |
|---|---|---|
| Added or changed a code patch (`patches/NN-name.ps1` or `*.patch`) | A row in `CHANGES.md` "Code patches" (template A) | CHANGES.md "How changes are made": every new code change gets "a line in this file" |
| The patch reads a setting | The setting line in `server-settings/server-settings.txt` with a comment above it: what it does, the date, and "needs the build with ..." if it needs a new build | `docs/agents/context/patches.md`; pattern at `server-settings.txt` lines 34-53 |
| Changed a setting's value | The comment above that line: new value, date, who asked, the measured reason. Add to "Settings (summary)" in `CHANGES.md` only if it is a new group | `server-settings.txt` lines 505-506 show the pattern |
| Added an SQL file in `sql/enchants/` | A plain-English `--` header at the top of the SQL file (the notes generator copies it), and a sentence in `CHANGES.md` "Database" | `scripts/legendary_history.py`, `sql_notes()` |
| Fixed, reviewed or tested a Mystic Enchant | `enchants/tracker.csv` (status, fix, fix file, `tested`), `enchants/<tier>-notes.csv` (assumptions, sources, decisions), then **regenerate** the notes and history (section 2) | `enchants/legendary-notes-header.md` |
| Tested an enchant in game | `result` in `enchants/test-checklist.csv`, then copy to the tracker's `tested` column with the date | `docs/enchant-restoration.md`, "Testing a batch" |
| New enchant recipe or lesson | `docs/enchant-restoration.md` ("Proven recipes", "Lessons") | that file |
| Measured server speed | A row in `docs/performance.md` (template E) | that file |
| The plan changed (new goal, order changed, item finished) | `docs/roadmap.md` | README links it as "Server plan" |
| A design was settled or replaced | Its design doc (`docs/race-kits.md`, `docs/dk-enchant-proposal.md`) with the date and what it replaces | `docs/race-kits.md` opening lines |
| Anything about how the install, build or patch night works for a stranger | `README.md` | README is the front page |
| Launcher, site or sign-up behaviour | `launcher/README.md` or `signup/README.md` | those files |
| Added a third-party addon | One pinned line in `addon/third-party-addons.txt` (section 6) | header of that file |
| Text players read on the website | `launcher/site/*.html` | published by `launcher/Publish-WildcardSite.ps1` |
| A rule agents should follow, or a Fable ruling others can apply | The matching pack in `docs/agents/context/`. **Hard stop 6: waits for James.** | `docs/agents/README.md` rule 2; `change-risk.md` Step 1 |
| A Fable call was made | One line in `docs/agents/fable-ledger.md` | `docs/agents/README.md` rule 3 |
| A question needs Fable | A case file from `docs/agents/case-file-template.md` (template F) | `docs/agents/README.md` rule 1 |
| A skill is wrong or out of date | The skill, as its own PR. **Hard stop 6: waits for James** (section 9) | `change-risk.md` Step 1, item 6 |

The full list of every doc and data file, who reads it and whether a script writes it:
**read `references/docs-of-record.md` when** you are not sure where a fact belongs, or before editing any file under
`enchants/`.

## 2. Generated files: do not edit by hand

| Generated file | Written by | Edit these instead |
|---|---|---|
| `enchants/legendary-notes.md`, `enchants/legendary-history.csv` | `scripts/legendary_history.py` | `enchants/legendary-notes.csv`, `enchants/legendary-notes-header.md`, `enchants/tracker.csv` (`tested`), `enchants/test-checklist.csv` (`result`), SQL file headers, `//` comments in the enchant patch scripts |
| `enchants/epic-notes.md`, `enchants/epic-history.csv` | `scripts/legendary_history.py --quality Epic` | the same, with `epic-notes.csv` and `epic-notes-header.md` |
| Status lines in `enchants/legendary-reference.md` | the legendary run only (`update_reference()`); the rest of that file is hand-kept | the inputs above |
| `sql/enchants/150-custom-spells.sql` | `python3 client-patch/custom_spells.py > sql/enchants/150-custom-spells.sql` (the script's usage line names a `Spell.dbc` argument that the code does not read; **no client file is needed**, and on 2026-11-22 its output was identical to the committed file). Home: `wildcard-client-and-web`. | `client-patch/custom_spells.py` |
| `addon/WildcardEnchants/EnchantData.lua`, `TooltipData.lua` | Their first lines say "Generated". **The generator is not in the repository (UNVERIFIED which script).** Ask James before changing them by hand. | unknown |
| `changelog.json`, `manifest.json`, `launcher.json` on the website | `launcher/Publish-WildcardSite.ps1`, on the server PC. Not in the repository. | PR titles (section 4), `launcher/launcher-settings.json` |
| Release notes and `BUILD-INFO.txt` | the build workflow (`.github/workflows/build-worldserver.yml`, step "Package for the VM") | nothing. **Never edit a release's notes by hand:** patch night finds the build for the installed core by reading the `Core: <repository> <40-character commit>` line in them (`PatchNight.ps1` line 861) |

Regenerate the enchant notes (from the repository root, needs the `gh` command signed in, and a local branch named
`main` because the script reads `git rev-list --first-parent main`):

```
python3 -I scripts/legendary_history.py
python3 -I scripts/legendary_history.py --quality Epic
```

Optional: `--patch-night-log <path to patch-night.log>` fills the "installed on the server" dates (the log is on the
server PC at `C:\Games\CoA Server\patch-night\patch-night.log`); without it that column is left empty.
`--ref <branch>` reads another branch's history. It ends by printing e.g. `305 legendary copies, N with notes`.
Not run on 2026-11-22 (no signed-in `gh` there); the usage is from the script's own docstring and argument list.

**What the generator copies into the notes, so write these with care:** the `--` header of each SQL file, the `//`
comment blocks in the enchant patches that name a spell id, and **lines of pull request descriptions that mention the
enchant by name or id** (`pr_mentions()`). A PR description is therefore not throwaway: it lands in the repository.

## 3. House style (from the repository's own history)

Evidence base: the 487 non-merge commits and 205 merged PRs on `main`, 30 Oct to 22 Nov 2026.

### Prose (docs, comments, PR text, messages to James)

- **Plain English, the "kitchen test":** would it make sense read aloud to a friend who plays but does not program?
- **What the player sees first**, then how it is done. CHANGES.md rows describe behaviour ("Bots without a
  resurrection raise dead group members after a fight"), not code.
- **Short sentences. No jargon without a few words of explanation.** If you must name a table or function, say what
  it does in the same sentence.
- **Measured numbers, with units and the conditions.** "24.6 s became 1.7 s in the test" (commit d802f8c). "Worst
  ticks of 2-5 seconds with 2 players on (median 36 ms)" (commit 6a3e017). Never "faster", "much better", "a lot".
- **Say what is not done.** "The pet-specials-give-energy part needs a hook ... and is not done" (commit aa674b7).
  Guesses are called guesses ("missing chances and sequences are best guesses, marked in each row's comment").
- **Old value next to the new one:** "150 yards (was the default 100)", "750 instead of 1,000".
- **Dates:** in prose and comments, day then short month: `22 Nov` (62 uses in `server-settings.txt`); add the year in
  a heading or where it could be unclear: `7 Nov 2026`. In tables and CSV columns, ISO: `2026-11-16`. The tracker's
  `tested` column starts with the ISO date: `2026-10-31 pass: <what happened>`.
- **Builds take about 3½ hours.** Never call a build slow, stuck or hung because it has run for hours (James's
  own instruction, not written in the repository; README's "about 1.5-3 hours" is out of date).
- **Spelling:** Australian/British, as the docs already use: honour, armour, customisation.
- **Numbers:** thousands with a comma (1,250); `sec`, `min`, `ms`, `yards`, `%` as CHANGES.md does.
- **For James on his phone:** the answer in the first line, at most about 12 short lines, no wide tables, no code
  unless he asked. The patch-night checker's reply shape (`.claude/agents/patch-night-checker.md`) is the model.

### Commit messages

What the history shows (not a rule anyone wrote down; follow it so the log stays readable):

- **Subject = "Area: what changed, in the player's or operator's words".** 305 of 487 subjects have this shape. The
  area is a thing a player or James would name: `Race kits:`, `Bots:`, `Build:`, `Settings:`, `Patch night:`,
  `AI chat:`, `Website:`, `Linux launcher:`, or the ability itself (`Plainsrunning:`, `Arcane Charge:`).
  Not used here: `feat:`, `fix(scope):` and similar prefixes.
- **Subjects may be long** when the detail matters (average 70 characters; 210 run past 72). Old and new values and
  setting names go in the subject: "View distance in the open world: 150 yards (was the default 100)".
- **No full stop at the end.** Sentence case.
- **Body = why, with the evidence, then what was checked.** Symptom with numbers or the exact error text, the cause,
  the change, how it was tested, what is left. Example to imitate: `git show -s 01159e2` (a start-up failure, its
  cause, the fix, "checked against the listed commits: checksums match and both apply cleanly").
- A one-line change that the subject fully explains may have no body (`git show -s 6c4bba6`).
- **End with the attribution lines your session was given** (the history ends each message with a `Co-Authored-By:`
  line and a `Claude-Session:` line).

Template B has the shape. See real ones with:
`git log origin/main --no-merges -8 --format='%h %s%n%b%n----'`.

### Pull request titles

Write the title **for players**: it is the line they read on the website (section 4). Good titles from history:

- "Dungeon finder: Find a Group works again" (#226)
- "Bots: 750 instead of 1,000 for now" (#217)
- "Triple mana regeneration while resting" (#189)

Titles that are fine for James but mean nothing to a player ("Fix the build: patch 90's includes end with a line
break", #210; "Settings: four new core options set on purpose", #230) are the ones that need a `Changelog:` line.

## 4. How a PR title reaches the website

Verified by reading `launcher/Publish-WildcardSite.ps1` (lines 76-109) and `launcher/site/index.html`,
`changes.html`, `site.js` on 2026-11-22. Not run (no PowerShell there, no access to the live site).

1. Patch night calls the publish script after each start, once the site folder exists (`PatchNight.ps1`, function
   `PublishFriendsSite`). So the list refreshes at each patch night (daily, 4:00 am), at `Start-Server.cmd`, or when someone runs
   `Publish-WildcardSite.cmd` by hand. **Not at the moment of merging.**
2. The script asks GitHub for the 100 most recently updated closed pull requests **whose base is `main`**, keeps the
   merged ones from the last 7 days (today counts as day 1; the server PC's local time), and writes `changelog.json`.
3. For each PR the line shown is the **title**, unless the description has a line that **starts with**
   `Changelog:`. Then:
   - `Changelog: <text>` shows `<text>` instead of the title.
   - `Changelog: skip` leaves the PR out of the public list.
   - Only the first such line counts. It must start at the beginning of a line. Upper or lower case both work
     (PowerShell's `-match` ignores case).
4. The home page shows **only the newest day, first five lines**, then "and N more". The Changes page shows all seven
   days. PR numbers are in the file but not shown.
5. If GitHub cannot be reached, the previous `changelog.json` is kept.

What to do with that. **Proposed practice (not yet adopted by James).** Purpose: the website list is read by
players and is built from PR titles. Incident: titles written for developers (for example #210 and #230) mean
nothing to a player. The mechanism above (items 1 to 5) is fact; when to use the `Changelog:` line is this proposal:

- Player-visible change: make the title the changelog line. No `Changelog:` line needed.
- Title must stay technical: add `Changelog: <one plain sentence for players>`.
- Nothing a player would notice (build fixes, docs, agent files, skills, measuring-only changes, refactors): add
  `Changelog: skip`.
- **Anything you would not want read out to the players** (a security fix before it is live, an exploit, a named
  player's problem): `Changelog: skip`, and keep the title bland too, because the title is still public on GitHub.
- A PR merged into another branch (not `main`) never appears. Its content appears under whichever PR later brings it
  to `main`, so that PR's title must cover it.

Known gap (an inference from the code, not something observed live): the Changes page says its list is what "went
live in the last week", but the list is of **merged** PRs. A change under `patches/` is live only once a build that
contains it is installed: the evening build (since PR #241) and then the next 3:30 am patch night, so normally the
morning after the merge, later if the build started late or failed. The gap is now about a day, not up to a week, so
a note such as "(arrives with the weekly update)" is no longer needed.

Whether any PR has used a `Changelog:` line so far is UNVERIFIED (PR descriptions could not be read on 2026-11-22).
Check: `gh api "repos/JaTynan/coa-wildcard-mystic/pulls?state=closed&per_page=100" --jq '.[] | select(.body // "" | test("(?m)^Changelog:")) | "\(.number) \(.title)"'`.

## 5. Templates

**Read `references/templates.md` when** you are about to write any of these. It holds the copy-paste text.

| | Template | Status |
|---|---|---|
| A | `CHANGES.md` row | Current practice |
| B | Commit message | Current practice (derived from history) |
| C | Pull request description, with the change-control risk block, test evidence and a rollback line | **Proposed practice (not yet adopted by James)**. The risk block's format itself is doctrine (`change-risk.md`, "What the analyst returns") |
| D | Enchant notes entry (`<tier>-notes.csv` row + tracker `tested` value) | Current practice |
| E | Performance measurement row (`docs/performance.md`) | Current practice; two added columns are proposed |
| F | Case file | Doctrine: use `docs/agents/case-file-template.md` as it is. The reference only says how to fill it well |
| G | Incident review (PIR), one page | **Proposed practice (not yet adopted by James)** |
| H | Bug report to an upstream project | **Proposed practice (not yet adopted by James)** |

## 6. Public-repository rules

Each rule, where it is written, and why. The first four are doctrine (`docs/agents/README.md` last paragraph;
`docs/agents/context/patches.md`, "Rules for anything in this repository").

| Rule | Why | In practice |
|---|---|---|
| **No secrets** | A pushed secret is public for good, even after deletion (history keeps it). Hard stop 4 covers "secrets, tokens, `signup-settings.json`, or anything that reads or logs them". | Secrets live only on the server PC: `signup-settings.json` (Turnstile keys, invite codes, the GitHub token for bug reports) and `signup-state.json` are in `.gitignore`. An optional `launcher-secret.json` is described in `launcher/README.md`. Placeholders in code look like `PASTE-SECRET-KEY` and `CHANGE-ME`. Never paste config file contents or log lines holding keys into a commit, PR, issue or case file. |
| **No Ascension client data** (MPQ archives, DBC tables, BLP textures, models, maps) | The files belong to the game's makers, not to this project. | The client patch `patch-ZZW.MPQ` is **built locally from your own client files and never published** (`docs/enchant-restoration.md`, "Client patch"; `client-patch/build_client_patch.py` docstring). The scripts that build it are ours and are in the repository; their output is not. |
| **No verbatim client tooltip text** | The text is Ascension's (`enchants/legendary-notes-header.md`, "Sources"). | Describe what a tooltip says **in your own words**. The archived text is kept privately on the server PC, not here. This covers docs, SQL comments, commit messages, PR text, issues and case files. **In new SQL too: description and name text is not copied from the client or the archived page into a `spell_dbc` row; write a paraphrase or leave the description column empty.** Existing files `009` and `011` (about 1,200 rebuilt description sentences) and four rows in `012`/`013` are an OPEN question for James's ruling (`wildcard-architecture-contract` V7): add no more until he rules. Spell ids, names and numbers are used freely throughout the repository; sentences are what must not be copied. |
| **No third-party addon code** | Other people's work, under their own terms; and a pinned download is easier to review and update. | One line per addon in `addon/third-party-addons.txt`: `owner/repository \| commit \| folders`. The commit must be the **full 40 characters** (patch night skips the line otherwise: `PatchNight.ps1` line 260). A branch name is not allowed because it "would take untested changes". Before adding one, check it is for game version 3.3.5 and contains nothing but Lua, XML and art, and say so in a comment with the date, as the file does. Patch night downloads it into the client folder; the code never enters this repository. Only `addon/Wildcard*` folders are ours. |
| **Keep provenance and licence notes with copied files** | So anyone can see what came from where, and under what terms. | `patch-night/launcher_bridge.py` is copied from CF-Server-Manager and says so in its first lines (AGPL-3.0, with the one Wildcard addition marked). `ollama-chat/` holds unchanged copies from mod-ollama-chat (AGPL-3.0, author Dustin Hendrickson, commit `906eb2a`) with its `LICENSE`. New C++ files written by the patches carry AzerothCore's AGPL header. If you copy a file in, add: source repository, path, **commit**, licence, and what you changed. |
| **Keep the credits list current** | Credit is the minimum owed to the projects this stands on. | README "Credits" names Conquest of Azeroth, the CF-Server-Manager builds (Corfirean), SQUID's Playerbots (Zyth45) and AzerothCore. A new upstream part (as mod-ollama-chat and mod-dungeon-clear were) gets a mention where it is described; propose adding it to Credits too. |
| **Player reports are public** | The in-game Report Bug relay files reports as GitHub issues labelled `player report` (`signup/README.md`). | The relay leaves out the account name and the character, but its hidden marker carries the account **number**, and the server-written context carries class, level, map and position (home for relay defects: `wildcard-client-and-web`, `references/bug-report-relay.md`, weak point 1). Do not add any more: no account names, character names, IP addresses or e-mail addresses in replies, PRs and docs. |

### Before every push

```
python3 -I .claude/skills/wildcard-docs-and-publishing/scripts/public_repo_check.py
git diff --stat origin/main...HEAD
git diff origin/main...HEAD | less
```

The script (Python 3, standard library, read-only, tested on this repository on 2026-11-22) looks at tracked files
for: client data files, secret files, secret-looking strings, addon folders that are not ours, addon pins without a
full commit, files `.gitignore` lists but git still tracks, spell text carrying client format codes, share links, and
files over 1 MB. `FAIL` means stop. `WARN` means look. A clean run is not proof: it cannot tell a paraphrase from a
copy. **Read `references/public-repo-checks.md` when** you want the checklist, the same checks as one-line `git`
commands, or the list of what the script found on 2026-11-22.

If a secret was pushed: tell James at once, treat the secret as burnt, and have it replaced (new Turnstile secret, new
invite code, new GitHub token). Removing the line is not enough. Rewriting history is his decision (hard stop 4).

## 7. What may be said in public

**What this project is** (README, first paragraph): a personal build of the world server the CF-Server-Manager
installs, with changes on top, for James and a few friends. "Shared as-is. Not supported, use at your own risk, and
keep backups." Keep that sentence, or its meaning, on anything public that describes the project.

**What it is not:** not an official Conquest of Azeroth, Ascension, SQUID or AzerothCore release; not endorsed by
them; not a supported product; not a place to get the game client (the repository does not hold it).

**Claims need proof first.** Use the weakest word the evidence supports.

| Word | Means | Proof needed |
|---|---|---|
| "should work" | The audit classes it as built from standard effects | `audit` / `status` column in `enchants/tracker.csv` |
| "restored" / "fixed" | A fix is merged and applied on the server | tracker `fix file`; for patch changes also the build number (history CSV, "first build with the change") |
| "tested" | Someone tried it in game and wrote down what happened, with a date | tracker `tested` column or checklist `result`. A recorded result can be a failure: read it |
| "verified" | Tested and passed | tracker status `verified` |

Do not write "N enchants restored" without counting from the tracker on the day, and never let "restored" stand in for
"tested". On 2026-11-22 the tracker held 6,440 rows; 27 had status `verified`; 49 had anything in `tested`; 35 of 561
checklist rows had a result; the legendary history listed 180 copies as "changed, awaiting in-game test" and 5 as
tested. Recount before quoting (section 10).

The same goes for speed: quote a row of `docs/performance.md` or a commit that states its numbers and conditions, with
the date. Do not say "lag fixed". Lag spikes were still an open problem on 2026-11-22
(`server-settings.txt` line 506).

**Anything shared must be reproducible.** Every release zip carries `BUILD-INFO.txt`, repeated as the release notes:
the manager release, the exact commit of each upstream part, the checksums of the official module patches, this
repository's commit and the build time. When you tell someone outside "this fixes X", give the release tag
(`wcme-server-<release>-build<N>`) and the patch file name, so they can see exactly what was built.

**Sensitive points, stated neutrally (this is not legal advice; legal questions go to James):**

- This is a private server for a game mode whose original home, Ascension, is gone; intended behaviour is rebuilt
  from what remains. Say that plainly; do not argue about whether it is allowed.
- Client files are never put in the repository. Note for accuracy: `launcher/launcher-settings.json` holds a public
  share link to the first-install client archive, and `launcher/README.md` says the site is not behind a login. That
  is James's decision to make or revisit; do not add further links to client files, and do not advertise that one.
- The repository has **no licence file of its own** (as of 2026-11-22). Do not tell anyone they may reuse it under
  some licence, and do not add one yourself. Upstream licence files on that date: the CoA core and SQUID's playerbots
  carry GPL v2 text (SQUID also ships an AGPL-3 file); CF-Server-Manager and mod-dungeon-clear carry AGPL-3.0.
- Do not use another project's name to suggest they back this one.

## 8. Upstream projects, and reporting bugs to them

| Project | Repository (as the build uses it) | What it is to us |
|---|---|---|
| AzerothCore | `azerothcore/azerothcore-wotlk` | The open-source server everything descends from |
| Conquest of Azeroth (CoA) core | `Corfirean/azerothcore-wotlk-coa` (README credits `jealous-sound/azerothcore-wotlk-coa`) | The server we patch. Pinned per release |
| CF-Server-Manager and its builds | `Corfirean/coa-server-manager`, `Corfirean/coa-server-build` | Installs and updates the official server; its release list tells our build which commits to use (`scripts/resolve_release.py`) |
| CoA bots, Content Scaling | `Corfirean/mod-coa-playerbots`, `Corfirean/mod-coa-content-scaling` | Modules in the official build |
| SQUID's Playerbots, Dungeon Clear | `Zyth45/mod-playerbots`, `Zyth45/mod-dungeon-clear` | The random bots; we patch them too |
| mod-ollama-chat | `DustinHendrickson/mod-ollama-chat` at `906eb2a` | AI chat for bots; our addition to the build |

We take their code at pinned commits and lay our changes on top at build time. We do not fork them, and nothing of
ours has been sent to them: no upstream report or pull request is recorded anywhere in the repository (searched
2026-11-22).

**The rule that exists** (CHANGES.md, "How changes are made"): "Fixes that are really CoA bugs are worth reporting to
the CoA team; when they fix one, its patch stops fitting, the build says so, and we delete it."

So a report upstream is how a patch of ours gets retired. When to report (**Proposed practice (not yet adopted by
James)**; purpose: reports the upstream team can act on; the written rule above gives no criteria):

- The bug is in **their** code and shows on **their unpatched** server (the official world server, or their code read
  at the pinned commit), not only with our patches on top.
- It is not about Mystic Enchants on Wildcard, or anything else that only exists because of our changes. Those are
  ours.
- You can give exact steps, the release tag and the core commit.

How:

1. Draft it from template H (`references/templates.md`). No client data, no tooltip text, no player names.
2. **James sends it, or says who does, and where.** Which channel each project wants (GitHub issues, a chat server) is
   UNVERIFIED: check the project's README and whether its Issues tab is open before drafting for it. Speaking for the
   project in public is his call. *(Proposed practice (not yet adopted by James); purpose: one voice in public. The
   repository has no rule on who sends.)*
3. Record it: add "(reported upstream: <link>, <date>)" to the patch's `CHANGES.md` row. *(Proposed practice (not yet adopted by James); purpose: the
   row shows which patches are waiting on upstream.)*
4. When a later build stops at "Apply our patches" on that patch because upstream fixed it, delete the patch and its
   `CHANGES.md` row in one PR, and say so in the title. Use sibling `wildcard-patch-authoring` to tell "fixed
   upstream" from "the code only moved".

## 9. Keeping the skills themselves right

- Skills live in `.claude/skills/<skill-name>/SKILL.md`, with long lists in `references/` and scripts in `scripts/`.
  Agents live in `.claude/agents/`; their one-page context packs in `docs/agents/context/`.
- Every skill ends with **"Provenance and maintenance"**: the date its facts were checked and one-line commands to
  check them again. Before relying on a number or a line reference in a skill, run its command.
- **One home per fact.** If a fact belongs to a sibling skill, link to that skill by name; do not copy it.
- **Editing a skill, an agent file or a context pack is a change to the agents' instructions: hard stop 6**
  (DOCTRINE). It is HIGH, never automatic, and waits for James. Open it as its own skill-maintenance PR,
  say which fact was wrong and how you checked the new one, and add `Changelog: skip`.
- **Generated reference files inside a skill follow the same rule.** The settings catalogue
  (`wildcard-settings-and-flags/references/settings-catalogue.md`) is regenerated when that skill is maintained,
  in a skill-maintenance PR (hard stop 6), **not** in every settings PR. A settings PR does not touch
  `.claude/skills/`; it runs `settings_catalogue.py --lint` only. So a one-line value change can still be a
  standard change.
- A skill must never contradict `README.md`, `CHANGES.md` or `docs/agents/context/change-risk.md`. If it does, the
  skill is wrong; fix the skill. If the doc is the one that is out of date, fix the doc first (it is the doc of
  record), then the skill.
- Label anything that is good practice but not written in the repository as
  **"Proposed practice (not yet adopted by James)"** with its purpose. Do not present a proposal as a rule.
- The same public-repository rules apply to skills: no secrets, no client data, no verbatim tooltip text.

A known disagreement, stated, not resolved: CHANGES.md says changes "go in as **one PR per patch night**". History
shows many small PRs merged per day (31 on 8 Nov 2026, 23 on 21 Nov). The README's "Branches" section describes the
practice: "Any other branch is a single change with its own pull request". Which one is the rule is James's call;
sibling `wildcard-change-control` is the home for that question.

## Provenance and maintenance

Facts checked against the repository at `fcfee51` (PR #232's head: `62a26e4`, the #230 merge, plus two commits adding
`.claude/agents/` and `docs/agents/`; `origin/main` is `d3e030f`, #231, not in that checkout) on
2026-11-22. PR descriptions and the live website could not be read that day; items depending on them are marked
UNVERIFIED above. Re-check anything that may have drifted:

```
# Changelog rule (title, Changelog:, skip, 7 days, base main); home page shows 5 lines of the newest day
grep -n -i "changelog" launcher/Publish-WildcardSite.ps1
grep -n "slice(0, 5)" launcher/site/index.html
# Patch night publishes the site
grep -n "Publish-WildcardSite" patch-night/PatchNight.ps1
# What the notes generator reads and writes
sed -n 1,16p scripts/legendary_history.py; grep -nE "write_text|open\(ROOT" scripts/legendary_history.py
# Commit style numbers (all, "Area: ..." shape, over 72 characters)
git log origin/main --no-merges --format=%s | awk '{n++; if(index($0,": ")>0 && index($0,": ")<32) c++; if(length($0)>72) o++} END{print n, c, o}'
# PR titles
git log origin/main --first-parent --merges --format='%ad %s %b' --date=short | head -40
# "One PR per patch night" and the upstream-report rule still in CHANGES.md
grep -n "one PR per patch night" CHANGES.md; grep -n "worth reporting" CHANGES.md
# Hard stop 6 wording and the public-repo rule wording
git show origin/main:docs/agents/context/change-risk.md | grep -n "^6\."
git show origin/main:docs/agents/context/patches.md | grep -n -i "public"
# Is docs/agents/ on main yet (empty = no)
git ls-tree --name-only origin/main docs/agents/
# Ignored secret files; addon pin format and the 40-character check
cat .gitignore
sed -n 1,8p addon/third-party-addons.txt; grep -n "0-9a-f\]{40}" patch-night/PatchNight.ps1
# Bridge and chat-module provenance; credits; no repository licence file (no output = none)
sed -n 1,5p patch-night/launcher_bridge.py; grep -n "AGPL" ollama-chat/README.md README.md
grep -n -A4 "^## Credits" README.md
git ls-files | grep -iE "^(licen[cs]e|copying)"
# custom_spells.py needs no client file and still reproduces file 150 (no output = identical)
python3 -I client-patch/custom_spells.py | diff -q - sql/enchants/150-custom-spells.sql
# Release notes contents
grep -n -A14 '"Manager release' .github/workflows/build-worldserver.yml
# Tracker counts for public claims
python3 -I -B .claude/skills/ascension-restoration/scripts/tracker_summary.py | head -20
# Public-repo findings
python3 -I -B .claude/skills/wildcard-docs-and-publishing/scripts/public_repo_check.py
```

Update this skill when: the changelog code in `Publish-WildcardSite.ps1` changes; a doc of record is added, moved or
retired; James adopts or rejects one of the proposed practices (then relabel it); an upstream report is first sent
(section 8 says none has been); a licence file is added. Each such edit is hard stop 6: its own skill-maintenance PR.
