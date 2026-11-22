---
name: wildcard-validation-and-qa
description: Evidence, testing and validation for the Wildcard (CoA / AzerothCore 3.3.5a) server repository coa-wildcard-mystic. Load this when a task needs to decide whether a change is proven enough to merge or go live; when scoring L4 "proof before going live" in the risk matrix; when asked "has this been tested?" or "what is verified?"; to run the pre-merge check set before a pull request (all nine check scripts and which is the authority for what); when testing a setting, an SQL file, a C++ patch, an addon, the client patch, the launcher or the sign-up service; when recording an in-game test result in the tracker; when designing the smoke test, the 4:37 am check or automatic rollback (NOT BUILT YET, design proposal inside); or when turning a past incident into a regression check. Covers the evidence ladder, proposed acceptance thresholds, the tested inventory, per-layer test steps and how to add a check.
---

# Wildcard validation and QA

This skill answers one question: **what proof do we have, and what proof do we need, before a change goes live?**

The honest starting point, as of 2026-11-22:

- **There are no automated tests.** The only CI is `.github/workflows/build-worldserver.yml`, and its only runtime
  check is `worldserver.exe --version` (step "Check it starts and reports its revision").
- The only systematic test record is for Mystic Enchants: 49 of 6,440 tracker rows have a result, all from three
  sessions (31 Oct, 2 Nov, 3 Nov). 47 of the 61 files in `patches/` have no recorded test of any kind.
- The "smoke test", the "4:37 am check" and "rolled back if the check fails" named in the LOW path of
  `docs/agents/context/change-risk.md` are **NOT BUILT YET**. Patch night has `StartAndCheck` and a fall-back to the
  official world server, and nothing after that.
- A static checker now exists and is tested: `scripts/repo_lint.py` (this skill). On the current repository it
  reports 0 errors and 6 warnings.

Why this matters here more than usual: a build takes 2-3 hours on GitHub Actions and often fails deep inside (a
failed anchor, a compile error, a start-up failure after install). Every failure caught before the build saves
those hours. Pipeline, testing and validation is the owner's second priority, after the lag spikes.

Words used below, once:

- **DOCTRINE**: a rule written in README.md, CHANGES.md or docs/ on `main`. Follow it.
- **INTENDED DOCTRINE (PR #232, unmerged on 2026-11-22)**: anything in `docs/agents/*` or `.claude/agents/*`
  (the risk matrix, hard stops, L4, the LOW path, `patch-night.md`). Those files are not on `main` yet; every
  citation of them below carries this status.
- **PRACTICE**: what the history shows people actually did. Useful, not binding.
- **Proposed practice (not yet adopted by James)**: this skill's suggestion, always labelled so. Other status
  words: NOT BUILT YET, UNVERIFIED, OPEN. James has said there are no
  firm unwritten rules and he is open to best-practice suggestions; a proposal becomes a rule only when he says so.
- **GM**: a game-master account, which can type dot commands such as `.aura` in game.
- **Rung**: a level on the evidence ladder below.
- **Scratch database**: a throwaway copy of the world database that nobody plays on.
- Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Classify a change (LOW / MEDIUM / HIGH), know the hard stops, or know who merges | wildcard-change-control. This skill only supplies the evidence for its L4 score |
| Find out why something is broken right now | wildcard-debugging-playbook |
| Read or measure logs: `Timing.log`, perf CSVs, `Errors.log`, `patch-night.log`, slow queries | wildcard-diagnostics-and-tooling (its scripts do the measuring; this skill says what result is acceptable) |
| Check that a patch script applies to the pinned sources before a build | wildcard-patch-authoring (the pre-flight) |
| Understand a build failure, trigger or watch a build | wildcard-build-and-env |
| Write enchant SQL, use the tracker's other columns, find the intended behaviour of an enchant | ascension-restoration |
| Run patch night, restart, restore the official server, roll back by hand | wildcard-run-and-operate |
| Read the full story of a past incident | wildcard-failure-archaeology (this skill keeps only the check each incident suggests) |
| Work on the lag spikes | wildcard-lag-spike-campaign |
| Know the launcher, site and sign-up internals | wildcard-client-and-web |

## Quick start: before you open a pull request

```
# 1. Static checks (about 1 second, read-only)
python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py --no-info

# 2. Compare with the dated baseline: six warnings were already there on 2026-11-22
#    (references/lint-baseline-2026-11-22.md). Anything else is from your change.

# 3. The other check scripts that match what you touched: section 11, "The pre-merge check set".

# 4. Then the layer-specific steps in references/how-to-test-each-layer.md, and say in the pull request which
#    rung of the ladder you reached, with what evidence (template at the end of this file).
```

Exit code 0 = no errors, 1 = at least one error, 2 = the tool could not run. `--json` gives the same result for
machines; `--strict` makes warnings fail; `--only sql,patches` runs some groups.

## 1. The evidence ladder

**Proposed practice (not yet adopted by James):** the ladder and its four rules. Purpose: make "tested" mean
something another person can check. Incident: build 57 passed `worldserver.exe --version` (rung 4) and stopped at
start-up (19 Nov, 01159e2).

Evidence is anything another person can check. "I am confident" is not evidence; a command and its output, a log
line, a dated in-game result are. Each rung proves more than the one before, and costs more.

| Rung | Name | What it proves | What it does NOT prove | How you get it here today |
|---|---|---|---|---|
| 1 | Static check | The files are well-formed and follow the repository's written rules | That anything works | `repo_lint.py`; `enchant_audit.py` verdicts; reading code or spell data ("works from its data") |
| 2 | Applies cleanly | The patch finds its anchors in the pinned sources; the SQL loads without error, **twice** | That it compiles; that the rows do the right thing | Patch pre-flight (wildcard-patch-authoring); scratch-database double run |
| 3 | Builds | It compiles and links on Windows with every other patch | That it starts | The GitHub build (2-3 h). A local Linux compile is a partial rung 3: three Windows-only failures are on record |
| 4 | Starts and reports its revision | The program loads and prints its version | That the world loads. Build 57 passed this and stopped at start-up | Workflow step `worldserver.exe --version`; the installer repeats it on the VM |
| 5 | World initialises, no new errors | The server loads all data and scripts on the real database, on the expected revision, and stays up a minute | That your feature works | `StartAndCheck` in PatchNight.ps1 (world initialised, revision, alive after 60 s). **"No new Errors.log lines" and "0 unknown settings" (see the note on that rule in section 3) are checked by nobody automatically**: read them yourself |
| 6 | In-game functional test by a GM | A person saw the change do what it should, once | Edge cases; bots; load; that it still works after the next change | GM commands; `enchants/test-checklist.csv`; record it (section 7) |
| 7 | Measured before and after | A number moved by the expected amount, with the method written down | That it holds on other days and loads | wildcard-diagnostics-and-tooling scripts; an in-game number (cast time 2.97 s to 2.524 s) |
| 8 | Soak with players | It survived real use for a stated period with nothing new in the crash folder or the error log | Nothing more to prove; but "nobody complained" without the log check is not this rung | Days live **plus** a recorded check of `Core\Crashes` and `Errors.log` |

Rules for using the ladder:

1. Claim the highest rung you have evidence for, and name it. "Compiles on Linux against c3f2fd4b" is an honest
   rung 3-partial. "Tested" with no detail is not a rung.
2. A higher rung does not replace a lower one that looks at something different. A GM test (6) of a C++ patch says
   nothing about tick time (7).
3. A desk check is rung 1 however careful. The history files' "works from its data (checked 2026-11-16)" is rung 1.
4. Evidence expires. `scripts/legendary_history.py` already marks an enchant "changed after its last test
   (date), retest needed" when a later commit touches it. Treat every layer the same way; a core update expires
   rung 2 and above for every patch.

## 2. What practice has been (so you can tell it from the proposals)

| Layer | What history shows people did | Source |
|---|---|---|
| Enchant SQL | "write the SQL, run it twice on a scratch database, open a pull request, merge, stop the server, run Start-Server.cmd, test in game, update the tracker" | docs/enchant-restoration.md (doctrine for enchant batches) |
| Enchant C++ batches | "compile-checked against the core release the build uses (also with the Windows header macros defined) and its SQL loaded twice into a scratch database. None of that replaces in-game testing" | enchants/epic-notes-header.md |
| Other C++ patches | Sometimes "compiles with -Wall -Wextra against core c3f2fd4b2395" or "syntax-checked" in the commit message (4 patches); usually nothing recorded | commits 5c2a489, 90ee10d, 273d36d |
| In-game tests | Three sessions, results committed as their own pull requests (`results-arcane-charge` #37, `results-3nov` #39); a failed test led to a same-day revert (d2ebbdb) | git history |
| Racials | James "auditioned in game" each racial's effect and sound on 20 Nov | commit 22fae33 |
| Settings script rewrites | Old and new run side by side on copies of the config files, outputs compared | commit d802f8c |
| Client patch | Tried on one private client first: `GetSpellInfo(911367)` | commit 34083eb |
| Going live | Merge to `main`; SQL, settings and addons arrive at the 4:00 am restart, builds at the weekly patch night; players are the soak | PatchNight.ps1, Register-PatchNight.ps1 |
| Merge cadence | CHANGES.md says "one PR per patch night". History shows up to 31 merged pull requests in a day (8 Nov) and 205 in 24 days. Both are facts; this skill does not resolve the difference (wildcard-change-control owns it) | CHANGES.md; `git log origin/main --merges --first-parent` |

## 3. Proposed acceptance thresholds (not yet adopted by James)

Everything in this section is a proposal. Purpose: make "is this proven enough?" a lookup instead of a judgement,
so that an automatic LOW path can exist at all. The risk classes are the ones in
`docs/agents/context/change-risk.md`; classify with wildcard-change-control first, then read the row for your layer.

Each cell is the **minimum rung with recorded evidence before the change goes live**, then what must follow.

| Layer | LOW | MEDIUM | HIGH |
|---|---|---|---|
| Settings (`server-settings.txt`) | Rung 1 (lint clean, value inside the comment's range). After the restart: rung 5 (no new unknown name, 0 bad value) | Rung 1 before; rung 5 and a rung 6 look at the effect within a day | As MEDIUM, plus rung 7 if it is on the performance list, and the old value written in the pull request for a one-line undo |
| SQL (`sql/enchants`) | Rung 2 (lint clean and the double run), for a fix that re-applies an existing recipe. After the restart: no `Enchant fix ... failed` line | Rung 2 before; rung 6 on at least one row per recipe within a day, recorded | Rung 2 before; rung 6 on every changed row before it is called done; files that change stock tables (lint `sql-outside-reset`) carry their reverse statement in the pull request |
| C++ patch (`patches/`) | Rare (section 4): only a patch with a tested off-switch setting and every impact score at 1. Then the MEDIUM evidence, with the switch tried both ways | Rung 2 (pre-flight) and partial rung 3 (compile check) before the build; rung 4 from the build; rung 5 at install; rung 6 within a day, with the setting off as well as on | As MEDIUM, plus rung 6 before players are told about it, a bot and a class-10 Hero tried, rung 7 if it runs per tick, per packet or for bots, and rung 8 = 7 days with the crash folder and error log checked |
| Addon (`addon/Wildcard*`) | Text only: rung 1 | Logic: rung 1, then rung 6 on one private client before the merge | As MEDIUM plus a look at the heaviest screen (rung 7 by eye: no freeze) |
| Client patch (`client-patch/`) | Not available: a bad client file reaches every player and has no automatic undo | Rung 6 on one private client, including the character-creation screen, before it is copied to the client folder | As MEDIUM on Windows and Linux clients |
| Patch night script, installer, workflow | Not available: hard stop 5, always HIGH | Not available | Parse check (`ps1-parse` on a machine with PowerShell), side-by-side run against copies where the change can be isolated, James present for the first live run |
| Launcher and site (`launcher/`) | Page text: rung 1 | Launcher logic: rung 1, version raised, rung 6 on one real client | As MEDIUM plus the manifest check after publishing |
| Sign-up and status (`signup/`) | Status and pets pages only: rung 1, then `/api/status` and `/api/pets` answer after the restart | As LOW plus a browser look | Anything touching account creation, invites or the settings file is hard stop 1 or 4: HIGH whatever the evidence, James tests the form himself |

Numbers proposed alongside the table (each **not yet adopted**; the motivating fact is in brackets):

| Threshold | Proposed value | Based on |
|---|---|---|
| Unknown settings after a start | **No NEW unknown names compared with the previous run's list** (Proposed practice). The doc's rule is "0 unknown": docs/agents/context/patch-night.md lists "Unknown settings, or any Bad value" under "What is wrong" (INTENDED DOCTRINE) | Prediction from the code (wildcard-settings-and-flags): about 28 working settings can never pass "0 unknown" (names built at run time, read by prefix, or read only by the website), and the refinement `5978ee4` is not on `main`. UNVERIFIED on the VM: compare with a real `settings-report.txt` before adopting either rule |
| Bad values after a start | 0 | Same |
| Failed enchant SQL files | 0 | Today a failure is a WARN and the run still ends OK (PatchNight.ps1 ApplyEnchantFixes) |
| Downtime | Healthy about 2 minutes; over 5 minutes is reported (doctrine: patch-night.md). Proposed hard limit 30 minutes | James's stated tolerance: about 30 minutes of downtime, about 15 minutes of data loss |
| New kinds of line in `Errors.log` | 0 without an explanation | patch-night.md: "a new kind of line in Errors.log since the last start" is wrong |
| New crash files | 0 | patch-night.md |
| Tick time after a change | No number here: the single home for lag pass/fail numbers is the proposed exit metric in wildcard-lag-spike-campaign (Phase 1 step 5; tool `spike_gates.py metric`) | One day of readings exists (22 Nov, one player: wildcard-lag-spike-campaign `references/evidence-2026-11-22.md`); a multi-evening baseline does not |
| Soak before "done" for HIGH | 7 days | One full weekly patch-night cycle |
| Enchant fix "verified" | One dated GM result that says what was seen, on the build that is live | docs/enchant-restoration.md: "A fix passes when it does what its tooltip says. Write the result and date in the tracker's tested column" (doctrine) |

## 4. How this ties to L4 in the risk matrix

`docs/agents/context/change-risk.md` scores likelihood on six checks. L4 is "Proof before going live":

| L4 score | The matrix says (doctrine) |
|---|---|
| 1 | An automatic check proves it (settings check, test, build plus smoke test) |
| 2 | Partly tested |
| 3 | Can only be seen working live |

Proposed reading of those three lines against what exists on 2026-11-22 (not yet adopted by James; purpose: stop
L4 being scored 1 on the strength of checks that are not built):

| Situation | Honest L4 | Why |
|---|---|---|
| A value change to an existing setting, inside its comment's range | 1 | The settings check exists: `settings-report.txt` shows unknown names and bad values at the next start. It is one of the matrix's pre-approved standard changes anyway |
| An enchant SQL fix that re-applies an existing recipe, lint clean, double run done | 1 for "it loads and re-runs" (also a standard change); the behaviour is still unproven until a GM result exists | The double run is a real check; it is manual, not automatic. Say so in the evidence line |
| Addon text | 1 | Nothing to prove beyond the lint |
| Addon logic, tried on a private client | 2 | Tested by hand once |
| A C++ patch, pre-flighted and compile-checked, behaviour never run | 3 | The build proves it compiles; **no smoke test exists**, and the repository shows no test server on the VM, so its behaviour "can only be seen working live" |
| A C++ patch, also exercised on the Docker test server the audit tool refers to (if it still exists: UNVERIFIED) | 2 | Partly tested |
| A C++ patch after the smoke test of references/smoke-test-spec.md is built | 2, or 1 only for failure modes the smoke test actually exercises (start-up, crashes at start) | A smoke test proves the server starts, not that a feature works |
| Anything in patch night, the workflow, the installer | Not scored: hard stop 5 makes it HIGH | |

Consequence, by the matrix's own arithmetic (read it before promising anyone an automatic path for code):

- Server C++ is L1 = 3 (doctrine). With L4 = 3 as well, the likelihood total is at least 10 once the other four
  checks score their minimum of 1 each. Low likelihood needs 6-8, so **a C++ patch is never low likelihood today**;
  three more points anywhere (size, hot path, understanding, precedent) make it high (13+).
- Impact check I3 (undo) is 2 for "revert and rebuild (2-3 h)". A patch with no setting to turn it off therefore
  has medium impact at least, and medium x medium is MEDIUM: James merges.
- So a C++ patch can come out LOW only when it has an off switch that works (I3 = 1), every other impact score is
  1, and the likelihood total stays at 12 or under. That is the practical value of the CHANGES.md rule "every new
  code change gets a setting to turn it off where that's practical" (doctrine): it is what makes a cheap undo, and
  the switch itself must be tested both ways to count.
- Building stages 1 and 3 of the smoke-test proposal is what would let L4 drop to 2 for code.

The analyst's "Evidence: one line per score that is not 1" should quote the rung and the evidence; use the
template in section 7.

## 5. What is recorded as tested (the verified inventory)

Full tables, dated 2026-11-22: `references/tested-inventory-2026-11-22.md`. Regenerate with:

```
python3 -I .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py
```

| Area | Recorded as tested | Not tested |
|---|---|---|
| Mystic Enchants, `enchants/tracker.csv` | 49 rows with a non-empty `tested` column (the meaning of "tested" for the tracker): 27 `verified`, 14 failed or partial (still `broken` / `partly working`), 8 on `live` rows of which 3 are clean passes | 6,391 rows. All 4,331 `working (audit)` rows rest on a static audit; 1,520 of the 1,528 `live` rows have no result |
| `enchants/test-checklist.csv` | 35 of 561 checklist rows have a result (19 pass, 2 fail, 14 other: partial or notes). This is a different count from the tracker's 49 | 526 rows, including every one of the 126 that depend on C++ |
| Legendary and epic history | 5 + 28 "tested (see test notes)" | 180 legendary and 280 epic copies "changed, awaiting in-game test"; 2 need a retest |
| C++ patches (61 files) | 9 racial patches "auditioned in game" (effects and sounds, one commit); 4 compile-checked; 1 data-checked | 47 with nothing recorded |
| Client patch | Two one-off checks on a private client (2 Nov, 7 Nov) | Everything since |
| Settings script | Two side-by-side comparisons on 22 Nov | No repeatable test |
| Performance | One table from 7 Nov (docs/performance.md), four figures in commit messages, and one day of readings with one player (22 Nov; in wildcard-diagnostics-and-tooling's reference run and the lag campaign's evidence file, not yet in docs/performance.md) | A multi-evening baseline for the live configuration (750 bots, core c3f2fd4b) |
| Launcher, site, sign-up | Nothing recorded | Everything |

Read "recorded" literally. Much of this code is live and used daily, so much of it has been seen working; but an
unrecorded observation cannot be told apart from "nobody has hit the bug yet", and three live patches (81, 82, 94)
exist because players found the failure first.

## 6. How to test each layer today

Step-by-step tables with the rung each step earns: **`references/how-to-test-each-layer.md`** (read it when you have
a change in hand). The shape of it:

| Layer | Fastest useful check | The check people skip and regret |
|---|---|---|
| Settings | Lint, then `settings-report.txt`: no NEW unknown names (the doc says 0; see section 3) and "Values it could not use (0)" after the start | Looking at the effect in game: "0 unknown" proves the name, not the behaviour |
| SQL | Lint, then run **all** files in order **twice** on a scratch database | Reading `patch-night.log` for `Enchant fix ... failed`: it is only a WARN and the run still says OK |
| C++ patch | Lint, pre-flight, compile check, then the build | Trying it with a bot, a class-10 Hero, and the setting off |
| Enchants in game | James's GM character only (GM commands and giving items are hard stops 1 and 2: no session sends them on the live realm without his say-so): `.aura <spell>`, `.list auras`, `.learn`, `.lookup spell id`, `.additem <scroll>` (docs/enchant-restoration.md) | Measuring the number before and after; relogging |
| Addon | Lint (`toc-*`), load on a private client | The heaviest screen (the collection window once froze the game) |
| Client patch | Build from your own client files, start a private client | Opening character creation (it crashed on 7 Nov) |
| Launcher and site | Lint (`launcher-version`), then fetch `manifest.json` and a sample of its files | Checking every changed file answers 200 (the `web.config` 404 of 8 Nov) |
| Sign-up | `GET /api/status` and `/api/pets` after the restart | Nothing automatic may create accounts: hard stop 1 |

The scratch database: the repository evidences a Docker test server (`enchants/enchant_audit.py` looks for
containers `ac-database`, `azerothcore-wotlk-ac-database-1`, `coa-test-ac-database-1`). Where it runs and whether it
still exists is UNVERIFIED. Making a scratch database on the VM's own MySQL is **not** evidenced anywhere and
competes with the live server: ask James first. Details and the exact loop are in the reference.

## 7. How to record a test result

### Enchants (doctrine: "Write the result and date in the tracker's tested column")

Two places, both read by `scripts/legendary_history.py`:

1. `enchants/test-checklist.csv`, column `result`: free text, for the row whose commands you ran.
2. `enchants/tracker.csv`, column `tested`, and set `status` to `verified` only on a clean pass. A failed or
   partial test keeps or gets `broken` / `partly working` and still gets its result written down.

Formats in practice: the first four results (31 Oct) are `2026-10-31 pass: Ice Block resets Frost Nova` in
`tested`; the 45 later ones hold only the date (`2026-11-03`) in `tested` with the words in `notes`. Both work,
because the generator finds a date in either `YYYY-MM-DD` or `3 Nov` form and compares it with the enchant's last
change to decide "retest needed". **A result with no date cannot be compared and is as good as lost.**

Proposed format (not yet adopted by James; purpose: one cell that stands alone and survives the notes column being
reused): `YYYY-MM-DD pass|partly|fail: what was seen (build tag)`, for example
`2026-11-24 pass: Starfire grants the buff, stacks to 4, gone after relog (wcme-server-0.261119.114-build70)`.
The build tag is in `C:\Games\CoA Server\Core\worldserver.patched-release.txt`. The lint warns on a `tested` value
that does not start with a date (`tracker-tested-format`) and on `verified` with an empty `tested`.

Then: regenerate the history files if a legendary or epic changed
(`python3 -I scripts/legendary_history.py [--quality Epic]`, needs the GitHub CLI signed in), and send the results
as their own pull request, as #37 and #39 did. Results are documentation: a standard LOW change.

### Everything else (proposed, not yet adopted by James)

Nothing else has a tracker. Until one exists, put this block in the pull request description (the notes files
already quote pull request descriptions as the record of assumptions):

```
Evidence
- Rung reached before merge: <1-8 and its name>
- How: <command or steps> -> <result, with numbers>
- On: <core revision or build tag>, <date>
- Not tested: <bots / class 10 / setting off / load / Windows build / ...>
- After it is live I will check: <log line or in-game step>, by <date>
```

And when the after-live check is done, add a dated comment to the pull request with the result. "Not tested" is
the most valuable line: it tells the reviewer what L4 really is.

## 8. The smoke-test gap and the proposal

**NOT BUILT YET. Needs James's OK: patch night, the workflow, the installer and rollback are hard stop 5.**

Read `references/smoke-test-spec.md` before touching this area. Summary:

| Stage | When | What | Catches | State |
|---|---|---|---|---|
| 1 | Pull request, minutes, ubuntu | `repo_lint.py`, patch pre-flight, enchant SQL replay, later a syntax-only compile | Failed anchors, missing CHANGES rows, Windows-macro names, non-re-runnable SQL | The lint exists and is tested; the workflow that runs it does not |
| 2 | Build, after `--version` | Start the built server far enough to reach "World Initialized" (`worldserver --dry-run`, which exists in the core) | Start-up stops such as build 57's | Blocked on GitHub runners by the DBC data files (client data, cannot be public); options and unknowns are in the spec. Whether upstream publishes a database dump: unknown; the base SQL is in the core repository |
| 3 | After the restart on the VM, at +2 and +35 minutes | 17 read-only checks: world initialised, revision equals the tag, right databases, ports, console round trip, no crash file, no new unknown / 0 bad settings, SQL applied, no new `Errors.log` kinds, bot count, tick time against a baseline, config file sizes, status page; a real login probe is OPEN | The 19 Nov wrong-database start, the 22 MB config, crashes after start | Nothing exists beyond `StartAndCheck` |
| Rollback | When a HARD check fails | Undo exactly what the night changed; today only "back to the official program" exists, one step deep, and it does not help when a setting or SQL file is the cause | | NOT BUILT YET |

## 9. Regression inventory: incidents as checks

Proposed practice (not yet adopted by James): every incident becomes a row naming the cheapest check that would
have caught it. Top ten with status in `references/regression-inventory.md`. Two are already built: the Windows
macro name (`repo_lint.py` check `win-macro`, replayed against the pre-fix file) and the wrong-database start
(`OnActiveRealm` in PatchNight.ps1). The two most valuable unbuilt ones: a start that reaches world initialisation
before install (build 57), and a syntax-only compile of touched files at pull request time (three build failures).

## 10. How to add a test or a check

Decide where it belongs by what it needs:

| The check needs | Put it in | Runs |
|---|---|---|
| Only files in the repository | `scripts/repo_lint.py` | Seconds, every pull request |
| The pinned upstream sources | The pre-flight in wildcard-patch-authoring | Minutes |
| A database | The scratch-database run (manual today) | Minutes |
| The running server | The stage 3 table in references/smoke-test-spec.md (NOT BUILT YET) | After each restart |
| A person in the game | `enchants/test-checklist.csv` (enchants) or the layer checklist in references/how-to-test-each-layer.md | By hand |

Adding a static check to `repo_lint.py`:

1. Pick the group function (`check_patches`, `check_settings`, `check_sql`, `check_files`, `check_lineends`,
   `check_parse`, `check_addon`, `check_secrets`, `check_enchants`) or add one and register it in `CHECKS` and
   `GROUPS`.
2. Report with `report.error(check_id, path, message, line)`, `.warning(...)` or `.info(...)`. The id is
   lower-case-with-hyphens and never reused. Error only for a written rule or a near-certain run-time failure;
   when unsure, warning. The message says what is wrong **and what happens because of it**, in plain English.
3. Plant the mistake in `bad()` in `scripts/repo_lint_selftest.py`, add the id to `EXPECT_BAD`, and make sure the
   clean fixture in `base()` does not trip it.
4. Run both:
   ```
   python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint_selftest.py   # SELF-TEST PASSED
   python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py --no-info  # the real repository
   ```
5. If the real repository now shows new findings, do not silence them: list them in a new dated baseline file
   beside the old one and tell James. If the check came from an incident, replay it on the pre-fix file
   (`git show <fix>^:<path>` into a scratch folder, then `--root`) to prove it would have fired.
6. Document the id in `references/repo-lint-checks.md`.

Checks deliberately left out, and why: "the version was raised when the addon changed" and "CHANGES.md changed
when `patches/` changed" need a comparison with `main`, which a file-only lint cannot do; they belong in the
stage 1 workflow as `git diff --name-only origin/main...` rules. Lua syntax needs a Lua interpreter. YAML needs a
parser the standard library lacks.

Making the lint run on every pull request means adding a workflow, which is hard stop 5: propose it, do not add it.

## 11. The pre-merge check set

This is the library's one list of the check scripts and which is the **authority** for what. Where two scripts
look at the same thing, the one named as authority decides. Run the rows that match what the pull request
touches, from the repository root. Every command below was run on 2026-11-22 and exited 0 on the repository as
it stood. Exit codes for all of them: 0 pass, 1 a check failed, 2 the tool could not run. None runs automatically
(making one a required check means adding a workflow: hard stop 5, propose it to James).

| # | Script (owning skill) | Authority for | Not its job | Command |
|---|---|---|---|---|
| 1 | `repo_lint.py` (this skill) | General repository hygiene; CHANGES.md and settings coverage of patches; static SQL rules (idempotence markers, statements outside the reset) | The reset/ownership model of `sql/enchants` (row 2 wins); whether patches apply (row 3) | `python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py --no-info` |
| 2 | `enchant_sql_lint.py` (ascension-restoration) | `sql/enchants`: what `000-reset.sql` removes and what each file owns (run twice against a model of the keys) | Does not replace the run-twice test on a scratch database | `python3 -I -B .claude/skills/ascension-restoration/scripts/enchant_sql_lint.py` |
| 3 | `preflight.py` (wildcard-patch-authoring) | "The patches apply": every `*.patch` and `NN-*.ps1` against the pinned sources, in the build's order | Compiling, linking, starting | `python3 -I -B .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest` (needs PowerShell 7 and network; about 80 s) |
| 4 | `check_patch_files.py` (wildcard-build-and-env) | Fast check of the `*.patch` files and the official module patches only | The `.ps1` scripts (row 3) | `python3 -I -B .claude/skills/wildcard-build-and-env/scripts/check_patch_files.py --modules` |
| 5 | `settings_catalogue.py --lint` (wildcard-settings-and-flags) | Settings: every option a patch reads is listed, with its default | Whether a value change is a standard change (row 6) | `python3 -I -B .claude/skills/wildcard-settings-and-flags/scripts/settings_catalogue.py --lint` |
| 6 | `settings_change_report.py` (wildcard-settings-and-flags) | Settings: what a branch changes in `server-settings.txt` and whether it is a candidate standard change | The risk class (wildcard-change-control decides) | `python3 -I -B .claude/skills/wildcard-settings-and-flags/scripts/settings_change_report.py origin/main origin/BRANCH` |
| 7 | `public_repo_check.py` (wildcard-docs-and-publishing) | Public-repository rules: secrets, client data files, third-party addon code, large files | Tooltip sentences without format codes (it cannot see them) | `python3 -I -B .claude/skills/wildcard-docs-and-publishing/scripts/public_repo_check.py` |
| 8 | `check_client_web.py` (wildcard-client-and-web) | Launcher, site, sign-up, addon and generated-SQL drift (for example `150-custom-spells.sql` against its generator) | Anything on the VM or a player's PC | `python3 -I -B .claude/skills/wildcard-client-and-web/scripts/check_client_web.py` |
| 9 | `check_contract.py` (wildcard-architecture-contract) | The numbered architecture invariants. Exits non-zero when it prints FAIL; lines marked KNOWN are the listed known violations | Layer-level detail (rows 1 to 8) | `python3 -I -B .claude/skills/wildcard-architecture-contract/scripts/check_contract.py` |
| - | `change_facts.py` (wildcard-change-control) | Nothing: it is a **classification helper, not a check**. It lists files by layer and hard-stop hints and never passes or fails a change | | `python3 -I -B .claude/skills/wildcard-change-control/scripts/change_facts.py facts origin/main origin/BRANCH` |

Related, not checks of a pull request: `which_build.py COMMIT` (wildcard-build-and-env: is a commit in a published
build) and `spike_gates.py metric` (wildcard-lag-spike-campaign: the proposed lag exit metric, the only home for
lag pass/fail numbers).

Known gaps between these scripts and the truth: the list of SQL files the reset cannot undo has one home,
`ascension-restoration` section 5 item 3. `repo_lint.py` prints part of it (`sql-outside-reset`: 026, 100, 110,
120, 130, 160, 161; `sql-server-setting`: 090, 095) and cannot see the rest (core rows removed or replaced and
owned: 027, 140, and the replaced core `spell_proc` rows in 005, 018, 020, 027). Until 2026-11-22 it also
flagged 013, a false positive (013 updates `spell_proc` 282881, a row 007 registers in `wcme_owned`); that is
fixed and recorded in `stats.updates_of_owned_rows` of the `--json` output.

## 12. Scripts in this skill

| Script | What it does | Tested on 2026-11-22 |
|---|---|---|
| `scripts/repo_lint.py` | Static checks in nine groups; `--json`, `--only`, `--strict`, `--allow`, `--no-info`, `--root`. Exit 0 / 1 / 2 | Run against the repository at fcfee51: 0 errors, 6 warnings, 44 info, 1.2 s. The PowerShell parse step was skipped (no PowerShell there) and is untested |
| `scripts/repo_lint_selftest.py` | Builds a clean and a broken fake repository and checks the lint's verdict on each | 38 of 38 planted mistakes reported; SELF-TEST PASSED |
| `scripts/tested_inventory.py` | Counts the tracker by status and tested / untested, the checklist by test type, the history files by status, and searches commit messages for recorded patch tests; `--json`, `--list-tested`, `--ref` | Run against fcfee51; output is the source of section 5 |

All three are Python 3 standard library only, read-only, have `--help`, leave no `__pycache__`, and are safe to run anywhere, including on the VM
(`C:\Games\CoA Server\Runtime\python\python.exe`).

## 13. Reference files

| File | Read it when |
|---|---|
| `references/how-to-test-each-layer.md` | You have a change and need the exact steps and pass rules for its layer |
| `references/tested-inventory-2026-11-22.md` | Someone asks what is proven; you need the counts, the recorded one-off tests or the performance baselines |
| `references/lint-baseline-2026-11-22.md` | The lint reports something and you need to know whether it was already there; includes the full first output |
| `references/repo-lint-checks.md` | You need to know what a check id means, what the lint cannot see, or how exceptions work |
| `references/smoke-test-spec.md` | You are asked about the smoke test, the 4:37 am check or automatic rollback (NOT BUILT YET; hard stop 5) |
| `references/regression-inventory.md` | You are choosing the next check to build, or adding one after an incident |

## Provenance and maintenance

Written 2026-11-22 against the checkout `fcfee51` (PR #232's head: `62a26e4`, the #230 merge, plus two commits adding
`.claude/agents/` and `docs/agents/`; `origin/main` is `d3e030f`, #231, which is not in that checkout). VM access was
not available: every statement about what a log on the VM contains comes from the scripts, docs and commit
messages in the repository, not from the VM. Upstream facts (the `--dry-run` option, where the command table
loads, the base SQL) were read from `Corfirean/azerothcore-wotlk-coa` at c3f2fd4b and
`Corfirean/coa-server-build` at e2d7efe.

Re-verify what drifts:

```
# The lint result and baseline; the lint still catches its planted mistakes; tested / untested counts
python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py --no-info
python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/repo_lint_selftest.py
python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py
# The only runtime check in CI is still --version
grep -n -A8 "Check it starts" .github/workflows/build-worldserver.yml
# No other workflow or test has appeared (expect one workflow and no test files)
ls .github/workflows; git ls-files | grep -iE "(^|/)tests?/|_test\.|/test_"
# What StartAndCheck checks, and the fall-back
grep -n -A44 "^function StartAndCheck" patch-night/PatchNight.ps1; tail -n 12 patch-night/PatchNight.ps1
# A failed SQL file is still only a WARN
grep -n "Enchant fix" patch-night/PatchNight.ps1
# The LOW path still names the smoke test, 4:37 and rollback; L4 wording (PR #232 only until it merges)
git show origin/agents-stage-1:docs/agents/context/change-risk.md | grep -nE "smoke|4:37|L4"
# Nothing implements the 4:37 check (expect no output)
grep -rn "4:37" --exclude-dir=.claude --include="*.ps1" --include="*.py" --include="*.yml" --include="*.cmd" .
# What 000-reset.sql removes (see stats.reset_rules), and UPDATEs of owned rows
python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py --only sql --json
# Bots are logged out with nobody on (why a 4:35 am check sees an empty world)
grep -n "DisabledWithoutRealPlayer" server-settings/server-settings.txt
# The enchant test doctrine and GM commands
grep -n -A14 "Testing in game" docs/enchant-restoration.md
# Performance bands and the 7 Nov table
sed -n 1,20p docs/performance.md
# The scratch-database evidence
grep -n -A8 "def db_set" enchants/enchant_audit.py
# Schedules as the script registers them (what the VM has registered is UNVERIFIED: wildcard-run-and-operate)
sed -n 1,16p patch-night/Register-PatchNight.ps1
# Merge cadence
git log origin/main --merges --first-parent --format=%ad --date=short | sort | uniq -c | sort -rn | head -3
```

In a clone of the core, that upstream still has `--dry-run`: `grep -n "dry-run" src/server/apps/worldserver/Main.cpp`.

When the lint gains or loses findings on `main`, add a new `references/lint-baseline-YYYY-MM-DD.md`; keep the old
one. When a stage of the smoke test is built, change its "NOT BUILT YET" label here and in the spec in the same pull
request, and revisit the L4 table in section 4. When James adopts or rejects a proposal, move it to doctrine (with
where it is now written) or delete it; the register of proposals is kept by wildcard-change-control.
