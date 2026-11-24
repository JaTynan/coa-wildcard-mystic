---
name: wildcard-frontier
description: ADVANCED. Open problems where James's Wildcard server project (coa-wildcard-mystic) can advance - eleven frontiers covering the lag budget, minutes-not-hours C++ feedback, a self-proving overnight deploy with rollback, the player-issue-to-automatic-fix pipeline (goal A), bots as testers, completing Mystic Enchant restoration (B), data-driven re-balancing (C), retention features (D), the custom launcher (E), no-behaviour-change technical reviews, and sustainability. For each - what exists today with evidence, what blocks it, the project's asset, the first three small PRs in this repo with a risk-class estimate, and a falsifiable milestone. Load when asked "what should we build next" or "what is not built yet", how to plan or sequence the roadmap, how to make the LOW automatic path real, how to speed up or pre-check builds, how to design the issue pipeline, telemetry, balance review, retention measures or launcher work. Everything forward-looking here is a proposal until James OKs it.
---

# Wildcard frontier: where the project can advance, and the first steps

**Status of this document.** Every forward-looking item below is a **Proposed practice (not yet adopted by James)**;
the designs are **design proposals (NOT BUILT YET, need James's OK)**. The facts under "Where the project stands"
were checked against the repository on 2026-11-22 and carry their source. Nothing here is a rule. The rules are in
`README.md` and `CHANGES.md` (DOCTRINE) and in `docs/agents/context/change-risk.md`, which is **DOCTRINE (PR #232, merged 22 Nov 2026)**: the matrix, the hard stops and the agent roles cited below are not on `main`
yet. Status words: DOCTRINE / PRACTICE / NOT BUILT YET / Proposed practice (not yet adopted
by James) / UNVERIFIED / OPEN.

**No step in this skill may be executed without change control.** Before any step that changes what the server,
patch night, the build, the site or the agents do: **classify with `wildcard-change-control` first**, respect the hard
stops, and remember that James merges. The "class estimate" given for each step is this skill's reading of the
matrix, to help planning. The `change-risk-analyst` (or James) decides.

## When NOT to use this skill

| You want to ... | Use instead |
|---|---|
| Classify a change, check a hard stop, or learn how PRs and merges work | `wildcard-change-control` |
| Hunt the lag spikes that are happening now | `wildcard-lag-spike-campaign` |
| Diagnose a failed build, a failed start or a failed patch night | `wildcard-debugging-playbook` |
| Find out whether something was already tried and why it was dropped | `wildcard-failure-archaeology` |
| Know what counts as evidence, or how to test a layer today | `wildcard-validation-and-qa` |
| Analyse a log or a measurement, or run an experiment properly | `wildcard-analysis-and-method` |
| Read logs and counters on the VM (`Timing.log`, `Logs\perf`) | `wildcard-diagnostics-and-tooling` |
| Work on the launcher, site, sign-up or relay as they are today | `wildcard-client-and-web` |
| Write or publish documentation, or check the public-repo rules | `wildcard-docs-and-publishing` |
| Fix one enchant or write one patch | `ascension-restoration` (one enchant) or `wildcard-patch-authoring` (one patch); this skill only says what is worth doing next |
| The lag pass/fail numbers | `wildcard-lag-spike-campaign`, Phase 1 step 5 (their single home) |
| Start, watch or fix a build | `wildcard-build-and-env` |
| Add or change a setting | `wildcard-settings-and-flags` |

Do not use this skill as authority that something exists. If a frontier file says NOT BUILT YET, check again before
relying on that too: the repo moves at up to 30 merged PRs a day.

## Words used here

| Word | Meaning |
|---|---|
| Frontier | An open problem: the project wants something it cannot do yet. |
| Tick | One pass of the world server's game loop. Its length in milliseconds is the lag measure ("update time diff"). |
| Patch | A C++ change, applied to CoA's source at build time by a file in `patches/`. Needs a 2 to 3 hour build. |
| Anchor | The exact piece of upstream source a patch script looks for. Found zero or two times = the build stops. |
| Patch night | `patch-night/PatchNight.ps1`: the weekly run installs new builds, the nightly restart does not. Schedule and go-live table: `wildcard-run-and-operate`. |
| Smoke test | A quick automatic check that the thing starts and its main parts respond. Not a full test. |
| LOW / MEDIUM / HIGH | The risk class from `docs/agents/context/change-risk.md` (likelihood x impact). |
| Hard stop | One of eight kinds of change that is always HIGH and always waits for James (same file, Step 1). |
| Goals A to E | James's "beyond where we are" list: A automatic fixes for LOW player issues; B complete enchant restoration; C re-balancing; D retention features; E custom launcher. |
| Stage 1 / 2 / 3 | The agent roll-out stages in `docs/agents/README.md`. |
| NOT BUILT YET | Described in a document, no code or schedule exists for it. |
| Any other term | `.claude/skills/azerothcore-coa-reference/references/glossary.md` |

## James's priority order (his decision)

1. Lag spikes. 2. Pipeline, testing and validation. 3. Broken enchants. Everything else after.
The frontiers and the order of the first ten PRs below follow it: the lag campaign's measuring and its first
experiment come first. The costliest ongoing failure is the build: 2 to 3 hours on GitHub, with problems
often found late (failed anchor, compile error, link error, start-up failure after install). That is the normal
build time, not a fault; the frontier is finding failures *before* spending it.

## What is built and what is not (as of 2026-11-22)

Read this table before believing any document that describes the pipeline. `change-risk.md` describes a target, and
its own table header says "Phase 1 (now)", but several parts of the LOW path do not exist.

| Thing a document mentions | Reality | Evidence |
|---|---|---|
| Risk matrix, `change-risk-analyst`, `patch-reviewer`, `patch-night-checker` | Written, and on `main` since PR #232 merged on 22 Nov 2026 | `git cat-file -e origin/main:docs/agents/README.md` fails; commits 6504f6f, fcfee51 |
| Fable ledger | Empty: zero calls recorded | `docs/agents/fable-ledger.md` has a header row only |
| Issue pipeline (triage, fix, classify) | **NOT BUILT YET** (Stage 2) | `docs/agents/README.md` roles table |
| In-game Report Bug to GitHub issue relay | Built and merged | `signup/WildcardSignup.py` `report_issue`, `bug_report_relay`; settings `CoABugReport.*` |
| "Build and smoke test" | The build exists. The only runtime check is `worldserver.exe --version` | `.github/workflows/build-worldserver.yml`, step "Check it starts and reports its revision" |
| Any check on a pull request | **None.** The one workflow runs on a daily timer or by hand | same file, `on:` has `schedule` and `workflow_dispatch` only |
| "Installed at the next nightly restart" | True for settings, SQL, addons, site. **False for C++**: the nightly task passes `-NoInstall` | `patch-night/Register-PatchNight.ps1` line `' -NoInstall'`; `PatchNight.ps1` "left for the weekly patch night" |
| "Checked at 4:37 am" | **NOT BUILT YET.** Exactly two scheduled tasks are registered, neither is a 4:37 check | `Register-PatchNight.ps1` |
| "Rolled back if the check fails" | Partly. If the patched server does not come up, the **official** server is put back (all patches lost). No rollback of settings, SQL or addons, and no "previous good build" | `PatchNight.ps1` section "5. The patched server did not come up" |
| "One automatic change per night" | **NOT BUILT YET.** Nothing merges automatically and nothing counts | no code |
| Automated tests | **None** in this repository | no test files; the workflow above |
| Log and crash triage, crash and lag investigator, patch porter | **NOT BUILT YET** (Stage 2) | `docs/agents/README.md` |
| Weekly data pack, balance review, ability pass, ability arbiter | **NOT BUILT YET** (Stage 3) | same |
| Build on the VM (roadmap item 1) | **Not started** in this repository | `docs/roadmap.md` item 1; no commit mentions it |

A doc-versus-practice difference to keep in view, not to resolve silently: `CHANGES.md` ("How changes are made")
says changes go in as **one PR per patch night**; history shows many merged PRs a day (31 on 8 Nov, 23 on 21 Nov,
205 merged between 30 Oct and 22 Nov). Several proposals below (last-good pin, one automatic change per night) only
work if "what changed since last night" is a short, known list.

## The project's assets (what makes these frontiers reachable)

| Asset | Why it matters | Source |
|---|---|---|
| Everything is re-applied from the repo at every start | Removing a change = deleting or reverting a file, for rows the reset owns; `000-reset.sql` clears those first. Exceptions (files the reset cannot undo, `SET PERSIST`, removed settings lines): `ascension-restoration` section 5 item 3 and `wildcard-settings-and-flags` | `CHANGES.md` intro; `docs/enchant-restoration.md` "How a fix reaches the server" |
| Per-change setting switches | A C++ change with a switch can be turned off at the next restart without a build (impact check I3 = 1) | `CHANGES.md` "Every new code change gets a setting to turn it off where that's practical" |
| Pinned, reproducible build inputs | `python3 -I scripts/resolve_release.py latest` prints every upstream commit; the same inputs can be fetched anywhere | `scripts/resolve_release.py`; workflow job `check` |
| Patches fail loudly | A patch whose anchor is missing throws and names itself; nothing wrong gets built | `docs/agents/context/patches.md` |
| The server reports its own enchant counts at start | `Server.log` lines "Loaded N Mystic Enchant action rows for M enchants", "Mystic enchants left out of rolls: N whose spell does not exist, M whose spell does nothing", "Worldforged enchants working: ..." are free health numbers | `patches/mystic-enchants-actions.patch`, `mystic-enchants-wildcard.patch`, `78-worldforged-enchants.ps1` |
| The core has a `--dry-run` start | `worldserver --dry-run` loads the whole world, then exits 0 (or 1 if a database update failed) | pinned core `src/server/apps/worldserver/Main.cpp` and `src/server/game/World/World.cpp` (search `isDryRun`) |
| The core ships a unit-test target | `unit_tests` (googletest), off by default (`BUILD_TESTING`), about 120 files under `src/test` including spell proc tests | pinned core `src/test/CMakeLists.txt`, `conf/dist/config.cmake` |
| `Timing.log` | Tick statistics once a minute, kept across restarts since 21 Nov | `server-settings/server-settings.txt` "Performance diagnosis"; commit 9ba9f45 |
| `Logs\perf` CSVs, `mysql-slow.log`, `console-history.txt` | Windows counters every 5 s, queries over 0.5 s, old tick lines | commit 9ba9f45; `sql/enchants/095-slow-query-log.sql` |
| 750 bots | A free load generator **only while a real player is online** (`AiPlayerbot.DisabledWithoutRealPlayer = 1`: bots log in 30 s after the first player and out 5 minutes after the last; with nobody on the world is empty). As testers they are unproven (see F5) | `AiPlayerbot.MinRandomBots = 750`; `server-settings.txt:479` |
| The 6,440-row tracker | Every enchant has a status, a fix file and a `tested` column | `enchants/tracker.csv` |
| The risk matrix | A written, scoreable definition of LOW | `docs/agents/context/change-risk.md` |
| VM snapshots on Proxmox | A whole-machine fallback. Never needed so far. Loses data since the snapshot (James accepts about 15 minutes) | James's statement; not in the repo |
| Downtime is measured | "Downtime: N s" in `patch-night.log`; about 2 minutes is healthy | `docs/agents/context/patch-night.md` |

## The frontiers

Each has its own file with the same eight parts: goal and owner, where it stands, why it falls short, the asset,
first three steps, a falsifiable milestone, wrong paths, dependencies.

| # | Frontier | Whose goal | One-line state today | "You have a result when ..." (short form) | Read this when |
|---|---|---|---|---|---|
| F4 | [A lag budget and regression gate](references/f04-lag-budget-and-gate.md) | James, priority 1 | Measuring exists since 21 Nov; no pass/fail number, no check after a patch night | 14 evenings with players on each get an automatic PASS/FAIL against a written budget | planning anything after the live spike hunt, or defining "is it laggy" as a number |
| F1 | [Minutes-not-hours feedback for C++](references/f01-fast-cpp-feedback.md) | Pipeline (James's biggest pain) | Nothing runs on a PR; anchors, compile and start-up are all found inside or after a 2 to 3 h build | 10 patch PRs in a row get an anchor verdict in under 10 minutes; a one-file change builds on the VM in under 15 | a build failed late, or someone asks how to test a patch before pushing |
| F2 | [A self-proving overnight deploy](references/f02-self-proving-deploy.md) | Pipeline | Start check is "world came up on the right core and lived 60 s"; fallback is the official server only | 3 of 3 drills with a deliberately broken change end on the last good state inside 30 minutes, no human | anyone says "LOW is automatic", "4:37 check" or "rollback" |
| F3 | [Player issue to overnight fix](references/f03-issue-pipeline.md) | James, goal A | Relay built; triage, fix and automatic path NOT BUILT YET | 20 issues triaged with zero false LOW, and the first LOW fix goes live with no human touch | designing triage, the threat model, or the metrics for phase 2 |
| F5 | [Bots and the console as testers](references/f05-bots-as-testers.md) | Pipeline, serves B | No automated functional test; console cannot run `.aura`, `.cast` or `.list auras` | 20 enchants of one type checked by script in under 10 minutes, agreeing with hand tests on at least 19 | someone proposes "let a bot test it" |
| F6 | [Complete the enchant restoration](references/f06-enchant-restoration.md) | James, goal B (priority 3) | 1,565 enchants carry a fix; 45 of those have a test note (2.9%) | untested fixed rows fall from 1,520 to under 760 in 30 days, with zero rows changed without a note | choosing the next enchant batch or handler |
| F7 | [Re-balancing with data](references/f07-rebalance-with-data.md) | James, goal C | No telemetry pack; pick data is in the database, use data is nowhere | 4 weekly packs in a row, and one balance change whose effect shows in the next pack | telemetry, the monthly balance review, the ~2,000-ability review budget |
| F8 | [Retention features chosen by evidence](references/f08-retention.md) | James, goal D | Many features shipped; no measure of whether friends come back | 8 weekly lines of the same three numbers, and one roadmap choice justified by them | deciding what to build next from the roadmap |
| F9 | [The custom launcher](references/f09-launcher.md) | James, goal E | Self-update and file sync built; news only on the website; issues only in game | every friend on the newest launcher within 7 days, and one issue filed from the launcher | launcher, website news, out-of-game issue reports |
| F10 | [Technical reviews with no behaviour change](references/f10-technical-reviews.md) | Pipeline (change source 3) | One success by hand (the 40 s character list index); no method for proving "nothing changed" | 3 changes merged, each with a before/after equivalence proof a reviewer can re-run | DB optimisation, patch tidy-up, anchor robustness, dead settings |
| F11 | [Sustainability](references/f11-sustainability.md) | James (the archaeology purpose), pipeline | Sources of truth are a private JSON on the VM, a Wayback capture and upstream repos | a restore drill rebuilds a working server from archived inputs alone | upstream risk, archiving, surviving a CoA core update |

For the **live** lag-spike hunt use `wildcard-lag-spike-campaign`. F4 is what comes after it: keeping lag fixed.
The lag pass/fail numbers have one home, the campaign's proposed exit metric; F4 states none of its own.

## Sequencing: what unlocks what (one page)

```
Lag campaign: measure-only step, then E1 (wildcard-lag-spike-campaign) ── first, before everything below

F4 step 1 (adopt the campaign's exit metric) ┐
                                             ├─> F2 step 1 (health check, report only)
F1 step 1 (anchor pre-flight on PRs) ───────┘          │
        │                                              v
        v                                   F2 step 2 (last-good pin) ─> F2 step 3 (automatic rollback, drilled)
F1 step 2 (incremental build on the VM)                │
        │                                              v
        v                                   F3 phase 1 (triage only, James merges everything)
F1 step 3 (dry-run start before install)               │   needs: 20 issues, zero false LOW
        │                                              v
        └──────────────> L4 can score 1 ─────> F3 LOW path live (one automatic change per night)

F5 (scripted enchant checks) ──> F6 testing throughput ──> F7 (balance needs working enchants to be worth tuning)
F7 step 1 (weekly numbers from the database) ──> F8 (retention measures come from the same weekly file)
F9 (launcher) is independent; its issue form feeds F3.
F10 needs F2 (rollback) and F4 (budget) to prove "no worse". F11 archive steps are independent and cheap.
```

Reading it:
1. **Nothing automatic is safe before F2.** A LOW change that deploys itself needs a check that can fail and a state
   to fall back to. Today neither exists for settings, SQL or addons.
2. **Nothing C++ is cheap before F1.** Every C++ mistake costs a build. F1 step 1 is the cheapest high-value step
   in this whole document.
3. **The lag number is needed by three others** (F2's health check, F10's "no worse" proof, F1's "do not build while
   players are on"), so get the campaign's proposed exit metric adopted or amended early (F4 step 1), even though
   the live spike hunt is still running.
4. **F6 is limited by testing, not by writing fixes.** F5 is the lever. Until it works, the limit is James's hours
   in game.
5. **F7 and F8 share one small data script.** Build it once.

### Suggested order of the first ten PRs (Proposed practice, not yet adopted by James)

Lag first, then pipeline, testing and validation, enchants last, as James ordered. Every row is classified with
`wildcard-change-control` first; James merges.

| Order | Step | Why now |
|---|---|---|
| 1 | Lag campaign, measure only: shorten `RecordUpdateTimeDiffInterval` (campaign Phase 1 step 4; an existing setting whose comment states no range, so scored) and record a new baseline evening | 22 Nov is not the baseline for what runs next (#229 to #231 were not live that day); full coverage of the minute is needed to judge any experiment |
| 2 | Lag campaign experiment **E1**: `AiPlayerbot.RandomBotUpdateInterval = 30` for one evening, prediction written first | The one experiment that separates the two leading hypotheses; root cause is UNKNOWN until it runs |
| 3 | F4 step 1: James adopts or amends the campaign's proposed exit metric; "Budget" section in `docs/performance.md` | One written test of "not laggy" that F2 and F10 can reuse |
| 4 | F1 step 1: promote the existing `preflight.py` and its workflow file from `wildcard-patch-authoring` into the repository (adding a workflow is hard stop 5: HIGH, James merges) | Cheap to catch before a 2 to 3 hour build. No anchor failure is on record; the recorded losses are five compile-step failures and one start-up failure, of which the pre-flight's text checks catch the 21 Nov glued include and flag the 16 Nov macro. Touches nothing on the server, so it does not disturb the campaign's one-change-a-night rule |
| 5 | F2 step 1: health check after start, report only | First real "proof after go-live"; no behaviour change |
| 6 | F3 step 1: fix the relay's context split and the account number in the hidden marker; triage summary template | Small; closes real gaps before any agent reads issues (defects: `wildcard-client-and-web`) |
| 7 | F2 step 2: last-good pin and manual `-Ref` rollback | Gives James a one-command undo for a bad night |
| 8 | F1 step 2: incremental build tree on the VM (build only, no install) | Needs the host upgrade named in the roadmap; not while the lag campaign is measuring unless limited to idle hours |
| 9 | F7/F8 step 1: weekly numbers script (read-only SQL; expect HIGH, it uses the admin login) and F11 step 1: archive manifest | Start the clock on measures that need weeks of history; cheap insurance |
| 10 | F5 step 1: start-up count check and one scripted test type (enchants, priority 3) | Unblocks F6 throughput. F2 step 3 (automatic rollback, with three drills) follows only after 14 quiet nights of row 5's reports |

## What NOT to start yet (Proposed practice, not yet adopted by James)

| Do not start | Until | Why |
|---|---|---|
| Any automatic merge or automatic deploy (F3's LOW path, phase 2 of the paths table) | F2 step 3 has passed its drills and 20 triaged issues show zero false LOW | An automatic change with no failing check and no fallback is only luck |
| Automatic rollback (F2 step 3) | The health check has reported for 14 nights with no false alarm | A rollback triggered by a wrong check causes the outage it was meant to prevent |
| The full ~2,000-ability review (F7) | A 50-ability pilot has measured calls per ability and the outlier rate | James cannot afford about 10,000 agent calls; the cost template needs real numbers first |
| A balance change justified by numbers | 4 weekly packs exist and the lag budget is passing | A handful of players makes one week noise; lag changes how people play |
| The 120-enchant Death Knight set (roadmap item 4) | The two-enchant pilot in `docs/dk-enchant-proposal.md` ("What it takes", step 0) has worked end to end | New enchants need client data; the path is unproven |
| Level cap 70, new races, pick-one-of-three (roadmap 7, 9, 10) | F8's measures exist | Otherwise the choice is taste, and nobody can tell afterwards whether it helped |
| A compiler cache on the GitHub build | A measurement shows it helps with this build's precompiled headers | The build uses `USE_COREPCH=1` and `USE_SCRIPTPCH=1`; caches and precompiled headers often do not mix (UNVERIFIED here) |
| Per-cast usage telemetry in C++ | The lag budget passes and James OKs it | It runs for every cast by 750 bots (likelihood check L3 = 3) |
| A new GM or console test command (F5 option C) | James decides | Hard stop 1: GM and console commands always wait for James |
| Running builds on the game VM while friends play | The lag campaign is closed, or builds are limited to idle hours and a few cores | A build competes for the same CPU and would confuse the lag measurements |
| A patch porter agent (F11) | F1 step 1 exists | The porter's first tool is the same pre-flight |
| Changing patch night to fetch a pinned commit by default | F2 step 2 is reviewed by James | Hard stop 5: patch night and rollback |

## Scripts

This skill ships no scripts of its own (two prototypes were removed on 2026-11-22 as duplicates). Use:

| For | Script | Owner |
|---|---|---|
| F4: PASS/FAIL of an evening's `Timing.log` against the proposed exit metric | `.claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py metric` | `wildcard-lag-spike-campaign` |
| F6: tracker status and fix counts | `.claude/skills/ascension-restoration/scripts/tracker_summary.py` | `ascension-restoration` |
| F6: what is recorded as tested | `.claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py` | `wildcard-validation-and-qa` |
| F1: do the patches apply | `.claude/skills/wildcard-patch-authoring/scripts/preflight.py` | `wildcard-patch-authoring` |

Scripts named in the frontier files as `scripts/<name>.py` with "to be written" do not exist yet.

## Provenance and maintenance

Written 2026-11-22 from the repository at PR #232's head (`fcfee51`: `62a26e4`, the #230 merge, plus two commits
adding `.claude/agents/` and `docs/agents/`; `origin/main` is `d3e030f`, #231, and is not in that checkout), the
pinned upstream sources for release `server-0.261119.114` (core `c3f2fd4b`, SQUID bots `4ef5ed9e`), and git history
from 30 Oct to 22 Nov 2026. Nothing here was re-verified on the live server; facts marked "22 Nov logs" come from a read-only copy of that day's logs. The GitHub
API was not reachable either: the open issues (#148 to #151, four warlock talent reports opened 14 Nov) are as read from the issue page on
22 Nov and were not re-checked through the API, and no workflow run results were read (only the release tags).

Re-verify before relying on a fact (run from the repository root):

```bash
# Are the agents and the matrix on main yet?
git cat-file -e origin/main:docs/agents/context/change-risk.md && echo on-main || echo not-on-main
# Does anything run on pull requests? (no output = no)
grep -n 'pull_request' .github/workflows/*.yml
# What does the build check at run time?
grep -n -A6 'Check it starts' .github/workflows/build-worldserver.yml
# Which scheduled tasks exist, and does the nightly one install builds?
grep -n -e 'Register-Run' -e 'NoInstall' patch-night/Register-PatchNight.ps1
# What does the start check prove?
grep -n -A40 '^function StartAndCheck' patch-night/PatchNight.ps1
# What is the fallback?
grep -n -A9 'did not come up: back to the official' patch-night/PatchNight.ps1
# Has the Fable ledger any rows? (no output = none)
git show origin/main:docs/agents/fable-ledger.md | tail -n +8
# Enchant test coverage
python3 -I -B .claude/skills/ascension-restoration/scripts/tracker_summary.py
python3 -I -B .claude/skills/wildcard-validation-and-qa/scripts/tested_inventory.py
# Are bots still logged out when nobody is on? (why an empty server proves nothing)
grep -n 'DisabledWithoutRealPlayer' server-settings/server-settings.txt
# Pinned upstream commits
python3 -I scripts/resolve_release.py latest
# Merged PRs per day
git log origin/main --first-parent --merges --format=%ad --date=short | sort | uniq -c
# Published builds
git tag -l 'wcme-server-*' | wc -l
# Is roadmap item 1 (build on the VM) started? (no output = no)
git log --all --oneline -i --grep='local build' --grep='incremental' --grep='build on the VM'
# Bot count
grep -n 'RandomBots =' server-settings/server-settings.txt
# Open player issues (needs GitHub access)
gh api 'repos/JaTynan/coa-wildcard-mystic/issues?state=open&labels=player%20report'
```

When a step from a frontier file is adopted and merged, move it from "first three steps" to "where the project
stands" with its PR number and date, and write the next step. When a milestone is met or shown false, say so in the
file with the number that decided it. Retire a frontier in writing rather than deleting it.
