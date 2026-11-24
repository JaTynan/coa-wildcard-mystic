---
name: wildcard-failure-archaeology
description: The dated chronicle of every investigation, dead end, revert, retry and rejected fix in the coa-wildcard-mystic repository (30 Oct to 24 Nov 2026), each with symptom, root cause, evidence (commit, PR, file), what was tried and rejected, status and lesson. Load it before repeating a fix or experiment that feels familiar, or changing a value that looks odd, to check whether it was already tried (bot count 1000/1500/1250/1000/750, view distance 75/150, zone waking, logging, twin links, Arcane Charge, dud filter, runaway procs, core overlap review). Load it when asked "why is X set this way", "was this tried before", "why was this reverted", "what happened with for-083", "which branches are unmerged or abandoned", "what is still an open question", or when adding a new entry after an incident. Covers builds and core updates (.83 to .114), patch night and settings kit, performance and bots, enchants and spells, client patch, launcher and site, unmerged branches and lost commits. Not for quick symptom lookup.
---

# Wildcard failure archaeology

The chronicle of what has already been fought over on James's Wildcard server project, so that nobody re-fights
a settled battle or mistakes an abandoned experiment for a new idea.

It covers the whole history of the repository: 30 October to 22 November 2026, every branch. Each entry was read
out of a commit message, a file comment, a tracker or a document in this repository, and cites it. **Nothing in
it was re-checked on the server VM, and nothing was re-tested in game.** Where history does not state a cause,
the entry says "not known" and stops. It does not guess.

## When to use this skill

- Before you propose a fix, a setting change or an experiment: check whether it was tried, and what happened.
- When a value looks odd ("why 750 bots?", "why is view distance set to its own default?"): find the story.
- When you find a branch, a setting or a file that looks abandoned: check its status before touching it.
- After an incident is closed: add an entry (see "How to add an entry").

## When NOT to use this skill

| You want | Use instead |
|---|---|
| "I have this symptom right now, what do I check?" | `wildcard-debugging-playbook` (symptom to triage table). This chronicle is organised by story and date, not by symptom. |
| To decide whether a change may be made, and by which path | `wildcard-change-control`. Nothing here authorises a change. Any step that changes server behaviour: classify with `wildcard-change-control` first; James merges. |
| The step-by-step plan for the lag spikes | `wildcard-lag-spike-campaign`. This skill only records what was already tried and measured. |
| How the layers fit together, and why | `wildcard-architecture-contract` |
| How AzerothCore, CoA spells, procs and bots work | `azerothcore-coa-reference` |
| What counts as tested, and how to test | `wildcard-validation-and-qa` |
| How the launcher, site and services work today | `wildcard-client-and-web` |

## How to use it (two minutes)

1. Find the theme in the table below and open that one reference file. Do not read all seven.
2. Search the file for your keyword (a setting name, an enchant name, a branch, a build number).
3. Read the entry's **Status** first, then **Tried and rejected**, then **Lesson**.
4. Open the evidence yourself before relying on it:
   ```bash
   git show <hash>                          # the commit, message and change
   git show origin/<branch>:<path>          # a file on another branch (never check out)
   python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py pr <hash>   # which PR merged it
   ```
5. If the entry is `open` or says "status unknown - ask James", say so in your answer. Do not present your own
   theory as the recorded cause.

| Theme | File | Read this when |
|---|---|---|
| Builds and core updates | `references/build-and-core-updates.md` | a build failed, a core release changed something, or you need the `for-083` story |
| Patch night, settings kit, bot rebuild | `references/patch-night-and-settings.md` | touching `PatchNight.ps1` or `Apply-ServerSettings.ps1`, or a start went wrong |
| Performance and bots | `references/performance-and-bots.md` | anything about lag, bot count, view distance, MySQL, map threads, logging |
| Enchants and spells | `references/enchants-and-spells.md` | writing or reviewing an enchant fix; an enchant fires twice, never, or always |
| Client patch, launchers, site | `references/client-launcher-site.md` | a client crash, a launcher or site failure |
| Other game code and bots | `references/game-code-and-bots.md` | items, battlegrounds, whispers, pets, the one recorded server stop |
| Unmerged, lost, reversed | `references/unmerged-and-abandoned.md` | a branch, a merged PR whose change is missing, or a value that was tuned back |

## Words used in every file

| Word | Meaning |
|---|---|
| The manager | CF-Server-Manager, the program that installs and normally starts the CoA server |
| The core | CoA's server code (a fork of AzerothCore 3.3.5a) |
| Release `.NN` | last part of a manager release tag: `server-0.261119.114` is "release .114" |
| Build N | one of this repository's releases, tag `wcme-server-<release>-buildN`. A build takes about 3½ hours on GitHub Actions |
| Patch night | `patch-night/PatchNight.ps1` on the VM: one daily run from 3:30 am that applies settings and SQL and installs any new build (since 23 Nov; before that a weekly install plus a nightly restart; schedule: `wildcard-run-and-operate`) |
| Settings kit | `server-settings/server-settings.txt` and `Apply-ServerSettings.ps1`, which writes it into the config files at every start |
| SQUID | SQUID's Playerbots, the random bots |
| Tick | one pass of the world server's game loop. A long tick is a freeze |
| Any other term | `.claude/skills/azerothcore-coa-reference/references/glossary.md`. Status words (DOCTRINE, PRACTICE, OPEN ...): `wildcard-change-control`, section 1 |
| Twin | the same enchant under another spell id, made for another realm type |
| Proc | an effect fired by an event; `spell_proc` is the table that says when |
| Anchor | the exact text a patch script searches for in the core's source. It must be found exactly once or the build stops |
| PR #N | pull request N on GitHub. James merges all of them |

Status words: **fixed** (a commit says so; "tested" only where a test is recorded), **worked around** (the
symptom is avoided, the cause is not removed or not known), **open**, **abandoned**, **superseded** (a later
change replaced it), **changed, awaiting in-game test** (merged, compile-checked, nobody has recorded a test).

---

## Index of entries

### Builds and core updates (`references/build-and-core-updates.md`)

| ID | Date | One line | Status |
|---|---|---|---|
| B-01 | 31 Oct | Workflow actions on a retiring Node.js | fixed |
| B-02 | 1 Nov | Patches rebuilt for release .90 | fixed |
| B-03 | 1 Nov | Release list lagged a release behind | fixed |
| B-04 | 5 Nov | `main` and `for-083` merged into each other; undone in `ebc3c3d` | fixed, branch retired |
| B-05 | 5 Nov | mod-ollama-chat did not compile (`IsHeadless` is `IsBot`) | fixed |
| B-06 | 9 Nov | Inline workflow steps became numbered scripts in `patches/` | adopted |
| B-07 | 10 Nov | Release .95 reset the level cap to 80, blocking prestige | fixed |
| B-08 | 12 Nov | `.legendary` command did not compile | fixed |
| B-09 | 15 Nov | Patch 60 made to fit the next core's changed function | fixed ahead of time |
| B-10 | 16 Nov | `SYNCHRONIZE` clashes with a Windows macro | fixed |
| B-11 | 17 Nov | Iron Guard patch would have doubled the core | fixed |
| B-12 | 19 Nov | Release .114: Wildcard started on the wrong databases (pointer to P-11) | fixed |
| B-13 | 19 Nov | Build 57 stopped at start-up: "Duplicate blank sub-command" | fixed |
| B-14 | 19 Nov | Build stopped at 1288/3197: command line too long | fixed |
| B-15 | 19 to 22 Nov | Five things the core changed, or did differently from what we assumed | four fixed, one lost (U-03) |
| B-16 | 21 Nov | Patch 90: a missing line break hid an include | fixed |
| B-17 | 23 Nov | Merged patches waited for a by-hand rebuild | adopted: automatic rebuild |

### Patch night and settings (`references/patch-night-and-settings.md`)

| ID | Date | One line | Status |
|---|---|---|---|
| P-01 | 30 Oct | Settings kit: v1, v2 (template too), fix (fixed-size array) | fixed |
| P-02 | 30 Oct | Manager's Start button turns the bots off on Wildcard | worked around |
| P-03 | 30 Oct | Realm list reset to 127.0.0.1 at every start | fixed |
| P-04 | 30 Oct | No Hero bots: the name list table was empty | fixed |
| P-05 | 30 Oct | Bots created in CoA classes: realm game mode was empty | fixed |
| P-06 | 30 Oct | Rebuild-WildcardBots: fix, honest, by guid | fixed |
| P-07 | 1 Nov | Manager update kept our patched world server | fixed (go by the auth server) |
| P-08 | 7 Nov | MySQL error 1046 | fixed |
| P-09 | 8 Nov | Countdown while the world was still loading | fixed |
| P-10 | 8 Nov | Weekly patch night plus nightly 4 am restart | superseded by P-17 |
| P-11 | 19 Nov | Wildcard started on the other realm's characters | fixed, with a guard that refuses to start |
| P-12 | 21 Nov | Patch night overwrote a settings line | fixed |
| P-13 | 22 Nov | 3 minutes of downtime applying settings | fixed |
| P-14 | 22 Nov | Config files grew to 22 MB (encoding) | fixed |
| P-15 | 22 Nov | Settings the server does not know; 49 new options on defaults | check live, refinement lost (U-05) |
| P-16 | 22 Nov | Staged patch night | adopted, no run recorded yet |
| P-17 | 23 Nov | Patch night every night, installing builds | adopted |

### Performance and bots (`references/performance-and-bots.md`)

| ID | Date | One line | Status |
|---|---|---|---|
| F-01 | 7 Nov | One busy core: map threads 1 to 4 | fixed for that symptom |
| F-02 | 7 Nov | 1,500 bots tried, 1,250 chosen | superseded |
| F-03 | 7 Nov | Only 5% of far bots awake | in force |
| F-04 | 8 Nov | 40-second character list: missing index | fixed, the only proven root cause |
| F-05 | 8 Nov | MySQL tuning by `SET PERSIST` | in force, effect not measured |
| F-06 | 8 Nov | View distance 75 yards | never merged, never measured |
| F-07 | 8 Nov | Wake radius alone froze bots; zone waking back on | worked around, cause not known |
| F-08 | 9 Nov | View distance 150 yards | backed out before it went live |
| F-09 | 9 Nov | Spikes with 3 players: bots 1,250 to 1,000 | superseded |
| F-10 | 20 Nov | Logging inside the world update | changed, no after-measurement, OPEN |
| F-11 | 21 Nov | Bots 750 while the spikes are worked through | worked around |
| F-12 | 21 Nov | Measure only: Timing.log, counters, slow queries | recording; first reading 22 Nov, nothing written back |

### Enchants and spells (`references/enchants-and-spells.md`)

| ID | Date | One line | Status |
|---|---|---|---|
| E-01 | 31 Oct | Missing and dud filters; C++-only enchants also left out ("about 70" by README, 36 by docs/enchant-restoration.md) | fixed, known limit |
| E-02 | 31 Oct | Twin links that never fired (22 dropped) | fixed |
| E-03 | 31 Oct | Batch 5 fix: triggered spells need `AttributesMask` 2 | fixed |
| E-04 | 31 Oct | Twin plus ours doubled the bonus (38) | fixed |
| E-05 | 30 Oct to 7 Nov | Addon: slot off by one, wrong description line, "Requires Level" rewritten | fixed |
| E-06 | 2 to 3 Nov | Namesake teaches taught a piece of the ability (24 removed) | fixed by removal |
| E-07 | 2 Nov | Arcane Charge: retarget, revert, two more tries, pass | worked around; target only |
| E-08 | 2 Nov | Fiery Charge never triggers; four sisters suspect | **open** |
| E-09 | 1 to 2 Nov | Rebuilt enchants held out of rolls until the client patch | fixed |
| E-10 | 15 Nov | Runaway Legendary procs | awaiting in-game test |
| E-11 | 15 Nov | Dead Legendary triggers | awaiting in-game test |
| E-12 | 15 to 16 Nov | Guessed numbers corrected by the tooltip review | corrected |
| E-13 | 17 to 18 Nov | The core already did it: effects doubled, then removed | fixed in repo, lists still open |
| E-14 | 17 Nov | Heal hook unit order | fixed |
| E-15 | 17 Nov | Flowing fix corrected the same day | fixed |
| E-16 | 17 Nov | Chain jump modifiers: a core bug | patched, awaiting test |
| E-17 | 11 to 18 Nov | Twelve other root causes in one table | see table |
| E-18 | 19 Nov | Worldforged enchants neither dropped nor worked | awaiting in-game test |
| E-19 | 19 Nov | Enchant gold prices: client and server could disagree | changed |
| E-20 | 23 Nov | Ten named-target IDs replaced stock SpellAffect rows | fixed, lint check added |
| E-21 | 23 Nov | Spell mask read word by word: two wrong conclusions | corrected |

### Client, launcher, site (`references/client-launcher-site.md`)

| ID | Date | One line | Status |
|---|---|---|---|
| C-01 | 2 to 7 Nov | Client patch crashed character creation (class family kept) | fixed |
| C-02 | 30 Oct | Client crash on a new character's first login | worked around, cause never confirmed |
| C-03 | 7 to 8 Nov | Windows launcher: realmlist, 43 GB check, date, maths, web.config | fixed (launcher 5) |
| C-04 | 8 to 15 Nov | Linux launcher: `DivxTac.dll` under Proton, Steam's `--` | fixed or worked around |
| C-05 | 8 to 21 Nov | Site: changelog JSON, CRLF, pets page column name | fixed |
| C-06 | 20 to 21 Nov | Runes counted only in the currency tab; addon freeze; combat log | fixed or worked around |

### Other game code and bots (`references/game-code-and-bots.md`)

| ID | Date | One line | Status |
|---|---|---|---|
| G-01 | 20 Nov | World server stopped on a channel message with no channel name | fixed |
| G-02 | 10 to 21 Nov | "The handler never ran": Case of Fortune, Manastorm caches, Wisdomball | fixed |
| G-03 | 8 to 14 Nov | Battleground resurrection, three fixes | fixed |
| G-04 | 14 to 21 Nov | Battleground bots whispering back, two fixes | fixed |
| G-05 | 21 Nov | Dungeon Finder dropped requests with more than 50 dungeons | fixed; Ragefire Chasm question open |
| G-06 | 20 Nov | Pet spells brought back the wrong pet, two fixes | fixed |
| G-07 | various | Smaller ones, and "the shield and stance bug of 22 Nov" | last one unknown |
| G-08 | 23 Nov | Wildcard alts taught a slice of every class | merged, unverified |
| G-09 | 24 Nov | Alt-bot log lines reached no file (root logs errors only) | changed |

### Unmerged, lost, reversed (`references/unmerged-and-abandoned.md`)

| ID | Branch | One line | Status |
|---|---|---|---|
| (family) | `for-083` and five `*-083` | old-core build branches; every change has a twin on `main` | abandoned on purpose |
| U-01 | `xp-kill-rate` | kill XP 15% lower | never merged, ask James |
| U-02 | `bot-group-xp` | bots take no share of group kill XP | never merged, partly superseded by PR #219 |
| U-03 | `manastorm-xp-75` | PR #218 merged, but the setting is not on `main` | **lost** |
| U-04 | `tauren-juggernaut` | Running with the Herd 18 yards, 3 sec hold | **lost** after PR #213 |
| U-05 | `faster-settings` | settings-check refinement; sign-up window | **lost** after PR #229 |
| U-06 | `site-redesign` | Top players shows Most prestige | **lost** after PR #212 |
| U-07 | `perf-visibility-react` | view distance 75 | never merged, never measured |
| U-08 | `export-v2` | spell export includes namesakes | never merged, ask James |
| U-09 | `docs/patch-night-build51` | build 51 install record | superseded |
| U-10 | `agents-stage-1` / `pr-232` | agents and `docs/agents/` | PR #232, merged 22 Nov 2026 (`0802d4f`) |

---

## Settled battles: do not re-fight these

Each line is a thing that looks like a good idea and has a recorded outcome. Read the entry before going there
again. "Settled" means history has an answer, not that the answer can never change: bring new evidence.

| Idea | Outcome on record | Entry |
|---|---|---|
| Merge `main` and `for-083` (or any branch built for another core) | Wiped the old-core patches; undone. README forbids it | B-04 |
| Turn zone waking off and rely on the 300 yard radius | Bots near players stood still for 20 minutes or more | F-07 |
| Raise the bot count above 1,250 | 1,500 gave 300 ms peaks on this host | F-02 |
| Edit `mysql\my.ini` | The manager rewrites it at every start; use `SET PERSIST` in `090-mysql-tuning.sql` | F-05 |
| Write a setting only to the live `worldserver.conf` | The manager regenerates it from a template | P-01 |
| Start the server with the manager's Start button | Bots go off on Wildcard | P-02 |
| Erase or select bots by character name | Two-word names and carriage returns; use the character number | P-06 |
| Trust the world server's revision for "which release is installed" | A manager update can keep our patched one; trust the auth server | P-07 |
| Link any twin that has a proc aura | Some twins never fire | E-02 |
| Teach a same-named spell in place of a broken one, by name alone | 24 turned out to be effect pieces | E-06 |
| Move Arcane Charge's damage to an area around the Charge target | Broke the whole helper, mana part included | E-07 |
| Add a `spell_proc` row at 100% for an enchant the core runs | Makes the core's rule fire every time | E-13 |
| Script an enchant from its tooltip without searching the core first | Effects doubled for dozens of enchants; two days of review | E-13 |
| Watch a talent in an aura link | The bonus becomes permanent | E-13 |
| Copy Area 52 spell rows into the client patch unchanged | Character creation crashed | C-01 |
| Publish the client folder as it stands | Shipped the host's `realmlist.wtf` and IIS's `web.config` | C-03 |
| Hook an item's `OnUse` without checking how it opens | Loot-container items never call it | G-02 |
| Take the build's sources from the release list and stop there | The official build also patches modules and passes its own CMake flags | B-13, B-14 |
| Check a patch script locally with a "tidied" copy of its output | The real output failed the build | B-16 |
| Read config files with `Get-Content` and no encoding (PowerShell 5.1) | A 240 KB file became 22 MB | P-14 |
| Push one more commit to a branch after its PR merged | Four changes are missing from `main` today | U-03 to U-06 |

Not settled, though they may look it:

| Idea | Why it is still open |
|---|---|
| View distance 75 yards | written on a branch, never merged, never measured (F-06) |
| View distance 150 or 125 yards | 150 was backed out before it went live; 125 never tried (F-08) |
| "The logging change fixed the spikes" | no after-measurement; 2 to 5 second ticks were reported the next day (F-10, F-11) |
| "750 bots is the right number" | the commit calls it temporary: "while we find the cause" (F-11) |
| Kill XP 15% lower; bots take no group XP | both written, neither merged, no reason recorded (U-01, U-02) |

---

## Open questions history leaves unanswered

Each is something a reader will want to know and the repository does not say. Answering one is a contribution:
write the answer into the place named, then update this list.

### Lag spikes (the top priority)

1. **What causes the multi-second ticks?** Not known. Every commit that touches them says so or names a cause
   without an after-measurement (F-09 to F-11).
2. **What did `Timing.log`, the `Logs\perf` CSVs, `mysql-slow.log` and `console-history.txt` show?** Recording
   began on 21 Nov (F-12). No reading is in the repository proper as of 2026-11-22. A first reading from the VM
   (22 Nov, one day, one player) is in `wildcard-lag-spike-campaign` (`wildcard-lag-spike-campaign/references/evidence-2026-11-22.md`) and
   `wildcard-diagnostics-and-tooling` (`wildcard-diagnostics-and-tooling/references/reference-run-2026-11-22.md`); it is an observation, not a cause.
3. **Did update times change with the 19 Nov core update (release .114, SQUID 3.0, mod-dungeon-clear)?**
   `PatchNight.ps1:173` extracts the console history "to compare update times before and after". No comparison is
   written down.
4. **Did moving logging off the world update help?** OPEN. `f9dc45a` shipped 20 Nov; no after-measurement.
   `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229 to
   #231, so the console-log clear and rotation had not run yet (F-10).
5. **Why did bots near players freeze with zone waking off?** `c02ba12`: zone waking is back "until that is
   understood". It has not been explained since.
6. **Why does the worst tick grow while the 95% figure stays between 39 and 74 ms?** Worst tick on record: 58 ms at
   1,000 bots (7 Nov), 2 to 5 s at 750 bots (21 Nov). No cause is stated.
7. **How many vCPUs does the VM have?** Settled: the 22 Nov perf CSV shows 10 logical processors, so the
   `MapUpdate.Threads` comment (10 from 8 Nov) is right and `docs/performance.md` (8 vCPUs) is stale.
8. **Was any change of 8 to 21 Nov that adds bot activity measured?** No (table "Things that add load and were
   never measured" in the performance file).

### Enchants

9. **Do the fixes work in game?** The newest recorded in-game test is 3 Nov 2026. 180 legendary copies (177 plus
   3 worded variants) and 280 epic-file copies are "changed, awaiting in-game test" (rule and full counts:
   `ascension-restoration/references/state-2026-11-22.md`).
10. **Why does Fiery Charge never trigger, and do its four sisters work?** Open since 2 Nov (E-08).
11. **How many enchants does the dud filter wrongly leave out: about 70 or 36?** Both numbers are in the
    repository (E-01). No list of them, and no record of which have been given an override row.
12. **The review lists:** `core-rule-gaps.csv` (9 rows, 7 to review), `core-refresh-aura-review.csv` (100 rows,
    21 to review; commit `209d729` says 13 reached by enchants), `core-rule-version-gaps.csv` (263 rows, 261 to
    review), `taught-spell-doubles.csv`, `swap-own-effects.csv` (19) all say "still need a look" (E-13).
13. **Cauterize, Frost Shot, Hammerstorm:** give both a twin's effect and their own spell; "queued: their own
    spells need code first".
14. **Open items in `enchants/legendary-notes-header.md`:** Astral Storm needs a retest; Hand of Gul'dan's Wild
    Imps are untested; Aspect of the Fox may be blocked by the client itself; epic copies in issues #148 and #149
    are not covered.

### Builds, patch night, client

15. **Were the builds for releases .85, .90, .92, .94, .110 and .112 ever installed?** Tags exist; no install is
    recorded in the repository. The answer is in `patch-night.log` on the VM.
16. **Did `SkipCinematics = 2` stop the first-login client crash?** Set on 30 Oct "to test whether"; no result
    (C-02).
17. **Was Ragefire Chasm's refusal of a group of alts-as-bots the 50-dungeon limit, or something else?** (G-05)
18. **What was "the shield and stance bug of 22 Nov"?** Named in `docs/agents/context/patches.md`; no commit or
    issue describes it (G-07).
19. **Has the staged patch night (22 Nov) run, and what was its downtime?** (P-16)
20. **Why must the site page and status service keep CRLF line endings?** Fixed twice, reason never written
    (C-05).

### Branches and process

21. **Should the four lost changes go to `main`?** Manastorm XP 75%, Running with the Herd, Most prestige,
    settings-check refinement (U-03 to U-06).
22. **Are `xp-kill-rate`, `bot-group-xp`, `perf-visibility-react` and `export-v2` dropped or parked?**
23. **What are pull request numbers 78, 137, 152, 154, 155, 179 and 194 to 198?** Nothing in git names them.
24. **`CHANGES.md` says changes go in as "one PR per patch night".** Practice is different: 31 pull requests
    merged on 8 Nov, 25 on 7 Nov, 23 on 21 Nov (`git log origin/main --first-parent --merges`). Both facts
    stand; which one James wants is his call. See `wildcard-change-control`.

---

## Patterns that repeat across themes

These are observations from the entries, not rules. Rules written in the repository are cited as such.

| Pattern | Seen in | What the record suggests |
|---|---|---|
| Changed without an after-measurement | F-03, F-05, F-07, F-09, F-10, F-11 | Only F-01, F-02 and F-04 have before and after numbers, and F-04 is the only proven cause |
| An experiment setting with no recorded result stays | C-02 (`SkipCinematics`), F-07 (zone waking "until understood") | The setting outlives the question |
| "Tried" in a commit title, never live | F-06, F-08 | Check whether it reached `main` *and* the server before calling it tested |
| The first fix watched the wrong path | G-02, E-07, E-15 | Find how the thing actually fires before hooking it |
| Fixing one reply exposed the next | G-03, G-04, C-04 | Bots and addons reach paths players do not |
| Our change duplicated the core | E-04, E-13, E-15, B-11 | Written rule: search the core first (`enchants/epic-notes-header.md`) |
| A core release changed a default or a script | B-07, B-13, B-15, P-11 | Written rule: a failed anchor stops the build on purpose (`docs/agents/context/patches.md`); defaults and scripts have no such alarm |
| Windows PowerShell 5.1 surprises | P-01, P-14, C-03, C-05 | Seven are listed at the end of the patch night file |
| Numbers that disagree inside the repository | E-01 (70 / 36), E-10 (29 / 33), E-11 (22 / 33), E-13 list sizes, VM cores (8 / 10) | Quote both; do not pick one |

**Proposed practice (not yet adopted by James):** record an after-measurement in the same place as the change
(the settings comment or the commit message) whenever a change is made for performance. Purpose: so the next
person can tell a cause from a guess. Motivating incidents: F-10 and F-11, where a cause was named on 20 Nov and
2 to 5 second ticks were reported on 21 Nov with no way to tell whether the first change had helped.

**Proposed practice (not yet adopted by James):** when a setting is added as an experiment, write the question
and the date beside it, and come back to write the answer. Purpose: so experiments end. Motivating incidents:
C-02 and F-07.

A third proposal (check for commits pushed after a merge) is in `references/unmerged-and-abandoned.md`,
section 2, with its motivating incidents.

---

## How to add an entry

Add an entry when an investigation closes, a fix is reverted, a test result is recorded, or an experiment ends
(either way). Editing these files is a documentation change: it still goes through a pull request (classify
with `wildcard-change-control` first; James merges).

1. Gather the evidence.
   ```bash
   git fetch --all --tags      # only if you are allowed to change the local clone; otherwise skip
   python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py fixes --since 2026-11-22 --bodies
   python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py branches
   git log --all --no-merges --format='%h %ad %s' --date=short --since=2026-11-22
   git log origin/main --first-parent --merges --format='%h %ad %s' --date=short --since=2026-11-22
   ```
2. Read the full commit body (`git show -s --format=%B <hash>`). Commit bodies in this repository are long and
   precise; the subject alone is not enough.
3. Pick the theme file and the next free ID in it (`B-17`, `P-17`, `F-13`, `E-20`, `C-07`, `G-08`, `U-11`).
4. Use this template. Every field is required; write "none recorded" or "not known" where history is silent.
   ```markdown
   ## X-NN · YYYY-MM-DD · Short title

   - **Symptom:** what someone saw, in their words where possible.
   - **Root cause:** as stated in the commit or file. If not stated: "not known".
   - **Evidence:** commit hash, PR number, file and line. Quote the key sentence.
   - **Tried and rejected:** each attempt and why it was dropped, or "none recorded".
   - **Status:** fixed / worked around / open / abandoned / superseded / changed, awaiting in-game test.
   - **Lesson:** one line.
   ```
5. Add the entry's row to the index in this file. If it settles or opens a question, update those two sections.
6. Rules for what may be written:
   - Only what the repository states. Quote, and cite. No causes of your own.
   - Measured numbers exactly as written, with their date and the player and bot counts given with them.
   - No verbatim client tooltip text (paraphrase), no secrets, no Ascension client data: the repository is public.
   - If two sources disagree, record both.

## Provenance and maintenance

Written 2026-11-22 from the repository alone, at `origin/main` = `d3e030f` (710 commits, 205 merged pull
requests), with all remote branches and `wcme-server-*` tags. The reading covered: every commit subject on every
branch (515 non-merge commits) and the bodies of all of them; `README.md`, `CHANGES.md`, `docs/*.md`,
`docs/agents/**` (then on PR #232's branch; merged on 22 Nov 2026, so DOCTRINE), `enchants/*.csv` headers and both notes headers, comments
in `server-settings/server-settings.txt`, `patch-night/PatchNight.ps1`,
`server-settings/Apply-ServerSettings.ps1`, the build workflow and `sql/enchants/09x-*.sql`.

Not used, and therefore not verified here: the server VM (logs, live config, installed build), GitHub pull
request and issue pages (descriptions, open or closed state), any in-game test.

`scripts/chronicle_scan.py` was run against this repository on 2026-11-22 (`pr`, `fixes`, `branches`). It only
reads git history.

Re-verify the things that drift:

```bash
# Is main still where this was written? New commits since then are not in the chronicle.
git rev-parse --short origin/main                       # d3e030f on 2026-11-22
git log --oneline d3e030f..origin/main | wc -l

# Unmerged branches, and commits pushed after a merge (section 2 of the unmerged file)
python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py branches

# The four lost changes: each prints 0 or nothing while still missing from main
git show origin/main:server-settings/server-settings.txt | grep -c 'Manastorm.ExperienceRate'
git grep -n 'ShareRange' origin/main -- patches
git grep -n 'prestige/i' origin/main -- launcher
git merge-base --is-ancestor 5978ee4 origin/main && echo "settings-check refinement is on main"

# Current values of the settings whose history is in the performance file
grep -n -E 'RandomBots|MapUpdate.Threads|Visibility.Distance|BotActiveAlone|Log.Async' server-settings/server-settings.txt

# Has anyone recorded a result from the 21 Nov measurements?
git log --all --oneline --since=2026-11-22 -i --grep='Timing.log\|perf\|slow quer\|spike\|tick'

# Newest in-game test date in the trackers (was 2026-11-03)
grep -o '2026-1[0-2]-[0-9][0-9]' enchants/tracker.csv | sort | tail -1

# Release tags (which release was built when)
git tag -l 'wcme-server-*' --format='%(refname:short) %(creatordate:short)' | sort -t- -k4 -V

# PR #232 (docs/agents) merged on 22 Nov 2026; non-zero confirms
git ls-tree --name-only origin/main docs/ | grep -c agents
```
