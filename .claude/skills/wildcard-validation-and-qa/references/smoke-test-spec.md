# Smoke test: the gap, and a design proposal

**Status: Design proposal (NOT BUILT YET, needs James's OK).** Patch night, the build workflow, the installer and
rollback are hard stop 5 in docs/agents/context/change-risk.md: nothing in this file may be implemented, merged or
scheduled without James's explicit OK, and every stage below is a separate HIGH change through
wildcard-change-control.

Read this when you are asked to design or build the "smoke test", the "4:37 am check" or "automatic rollback" that
the LOW path in change-risk.md names, or when you need to say honestly what proof a build has before it goes live.

A smoke test is a short automatic check that the thing starts and its most basic functions answer. It does not
prove features work; it proves the server is not obviously broken.

## 1. What exists today (verified in the repository, 2026-11-22)

| Where | Check | What happens on failure | Source |
|---|---|---|---|
| Build workflow | Each `*.patch`: `git apply --check` | Build stops, names the patch | build-worldserver.yml, step "Apply our patches" |
| Build workflow | Each `NN-*.ps1`: its anchors are found exactly once (`Edit-Core`) | Build stops, names the script | step "Apply our patch scripts" |
| Build workflow | Official module patches: SHA-256 equals the release's, `git apply --check` | Build stops | step "Apply the official build's module patches" |
| Build workflow | Compile and link | Build stops | step "Build worldserver" |
| Build workflow | **`worldserver.exe --version` exits 0** | Build stops; nothing is published | step "Check it starts and reports its revision". This is the **only runtime check** in CI, and it proves only that the program loads its DLLs and prints a string |
| Patch night | Downloaded `.ps1` scripts parse | The current copies are kept, WARN | PatchNight.ps1 FetchRepo / ParsesCleanly |
| Installer | Build's core revision equals the manager's installed core; new program prints its version | Refuses, or puts the official program back | vm/Install-WildcardServer.ps1 |
| Patch night | Active realm is Wildcard but the config points at other databases | FAIL, the world is not started | OnActiveRealm |
| Patch night | `StartAndCheck`: this start's `Server.log` contains "World Initialized In" within 30 minutes; the revision on its first line matches the expected core; the process is still alive 60 seconds later | Returns false | StartAndCheck |
| Patch night | If StartAndCheck fails and the live program is ours: copy `worldserver.official.exe` back and StartAndCheck again | `Patch night FAILED on the patched server; the official server is running instead (no Mystic Enchants)` | PatchNight.ps1, section 5 |
| Patch night | Counts the server's own "Missing property" and "Bad value" config warnings | Logged (WARN if any bad value); does **not** fail the run | ReportConfigWarnings |
| Patch night | Each `sql/enchants` file's exit code | `Enchant fix <file> failed` at WARN; does **not** fail the run | ApplyEnchantFixes |
| After the fact | The `patch-night-checker` agent reads the log and reports (read only) | A message to James | .claude/agents/patch-night-checker.md |

What does **not** exist, although change-risk.md's LOW path names it:

| Named in the LOW path | Status |
|---|---|
| "build and smoke test" | The build exists. **No smoke test exists** beyond `--version`. |
| "checked at 4:37 am" | **NOT BUILT YET.** Nothing in the repository runs at 4:37 or checks anything after StartAndCheck returns (`grep -rn "4:37" .` finds only change-risk.md). |
| "rolled back if the check fails" | **NOT BUILT YET** for settings, SQL, addons or the site. The only automatic rollback is the program swap above, and it is one step deep: back to the *official* program, not to the previous patched build. |

Three limits of today's fallback worth stating plainly:

1. It replaces the program only. If the server fails to start because of a setting or an SQL file, the official
   program is started against the same settings and the same SQL, and will most likely fail the same way.
2. It triggers only on "did not come up". A server that starts and then crashes after two minutes, lags, or
   refuses logins passes.
3. Falling back costs the Mystic Enchants on Wildcard until someone intervenes, so it is a safety net, not a
   rollback to last-known-good.

## 2. Which past failures each stage would have caught

| Failure (date, commit) | Got past | First stage that would catch it |
|---|---|---|
| Missing final newline in an added include; MSVC error deep in the build (21 Nov, e0cc2f5) | Local check | Stage 1: caught by the pre-flight's text check (demonstrated on a scratch copy with the old bug put back: wildcard-patch-authoring, `references/reading-preflight-output.md`); a real compile is still NOT BUILT YET |
| `SYNCHRONIZE` clashes with a Windows macro (16 Nov, a4048e7) | Linux compile | Stage 1 (lint `win-macro`; the pre-flight's text check flags it too) |
| Build 57 stopped at start-up: "Duplicate blank sub-command" (19 Nov, 01159e2) | The whole build and `--version` | Stage 2 (a start that reaches world initialisation) |
| Wildcard came up on the other realm's characters (19 Nov, d5412a9) | StartAndCheck | Stage 3 (database identity check; now also guarded by OnActiveRealm) |
| World server stopped on a channel message from a bot (20 Nov, 3a50d87) | Everything | Stage 3 soak only (crash file check), and then only after the fact |
| `playerbots.conf` grew from 240 KB to 22 MB over 16 writes (found 22 Nov, ba59783) | Everything, for weeks | Stage 3 (config size check) |

## 3. Stage 1: at pull request time (minutes, ubuntu runner)

Purpose: fail before a 2-3 hour build is spent.

| # | Check | Tool | Pass | Fail action |
|---|---|---|---|---|
| 1.1 | Static lint | `scripts/repo_lint.py --json` (this skill; exists and is tested) | Exit 0 | PR check red |
| 1.2 | Lint self-test, only when the lint changed | `scripts/repo_lint_selftest.py` | `SELF-TEST PASSED` | PR check red |
| 1.3 | Patch pre-flight against the pinned sources | `preflight.py` in wildcard-patch-authoring (needs `pwsh`, which GitHub's ubuntu runners include; confirm on the runner) | Every patch and script OK | PR check red, naming the script |
| 1.4 | Enchant SQL replay | `enchant_sql_lint.py` in ascension-restoration | Exit 0 | PR check red |
| 1.5 | Only when `patches/` changed: syntax-compile the touched C++ files (`-fsyntax-only`) against the patched tree | NOT BUILT YET; method per wildcard-patch-authoring | No error | PR check red. Catches the 0220a49 kind (undeclared name), not Windows-only failures |

Trigger: `pull_request` on paths `patches/**`, `sql/**`, `server-settings/**`, `addon/**`, `launcher/**`,
`signup/**`, `patch-night/**`, `vm/**`, `CHANGES.md`. A new workflow file, separate from `build-worldserver.yml`, so
the build workflow itself is untouched. It is still a workflow in a repository where the workflow is a hard stop:
James's OK first.

Acceptance for building stage 1: on the current `main` it passes; on a branch that reintroduces each of the three
historical mistakes (drop a CHANGES.md row, break an anchor, rename a constant to `SYNCHRONIZE`) it fails with a
message that names the file. Budget: under 10 minutes; if the pre-flight clone makes it slower, cache the sources
by commit.

## 4. Stage 2: at build time (after `--version`, before publishing)

Goal: start the freshly built world server far enough to reach "World Initialized", so that a start-up stop like
build 57's is found by the build, not by patch night.

What the upstream sources establish (core `Corfirean/azerothcore-wotlk-coa` at c3f2fd4b, read on 2026-11-22):

- `worldserver` has a `--dry-run` option (`src/server/apps/worldserver/Main.cpp`: `("dry-run,d", "Dry run")`). In a
  dry run the world loads fully, logs `WORLD: World Initialized In ...`, then logs `AzerothCore Dry Run Completed,
  Terminating.` and exits 0, or exits 1 with `Dry Run Completed With N Failed Database Update(s)`
  (`src/server/game/World/World.cpp`).
- A dry run skips only the map and vmap file check. It still calls `LoadDBCStores` (same file), so it **needs the
  server's DBC data files**, which are extracted game client data.
- The chat command table, where build 57 died (`ASSERT(!_invoker, "Duplicate blank sub-command.")` in
  `ChatCommand.cpp`), is loaded inside world initialisation (`Acore::ChatCommands::LoadCommandMap()` in World.cpp),
  after the databases and the DBC files. So a start **without** a database cannot catch that class of failure.
- Before the world initialises, the program writes to the auth database (`UPDATE realmlist SET flag = ...` in
  Main.cpp). A dry run must therefore never be pointed at the live auth database.
- A base world database is in the core repository as SQL (`data/sql/base/db_world`, 309 files, about 300 MB, plus
  `data/sql/updates`), and the core's `worldserver.conf.dist` ships `Updates.EnableDatabases = 7` and
  `Updates.AutoSetup = 1`, which is AzerothCore's mechanism for filling empty databases at first start. Whether a
  ready-made database **dump** is published anywhere: **unknown**. None was found in `Corfirean/coa-server-build`.
- The official build repository does run start-up checks: its `scripts/smoke-test-linux.sh` starts `worldserver`
  with **no database** for 30 seconds and checks only that module configuration files are found, and its
  `docs/server-release.md` says packaging "applies SQL in an isolated database, checks startup" on the
  maintainer's own persistent build machine. How that isolated database and its data files are provisioned is not
  in the public files read: **unknown**.

So a full dry run on a GitHub-hosted runner is **blocked by the DBC files**: they are client data, this repository
is public and must never hold them, and no public source for them was found. Options, in order of preference:

| Option | What | Catches | Blocker |
|---|---|---|---|
| 2A (recommended) | **Dry run on the VM before the swap.** During patch night's countdown, with the live server still up: unpack the new build to a staging folder and run `worldserver.exe --dry-run` there with a config that points at throwaway copies of the three databases and at the VM's existing data folder | Everything up to "World Initialized": duplicate commands, missing tables, script registration errors, bad DB updates | Needs throwaway databases on the VM (copying the world database is heavy, see how-to-test-each-layer.md section 2), memory for a second world load while the live one runs (the VM has 18 GB, and docs/performance.md recorded about 10 GB in use with 1,000 bots: **may not fit**), and it lengthens patch night. Feasibility: OPEN, measure first |
| 2B | **Dry run on the build runner with private data.** Keep the DBC files as a private artifact (not in the repository), restore them in the workflow, start MySQL on the runner, let `Updates.AutoSetup` build the databases from the core's base SQL, run `--dry-run` | The same, and before the release is published | Storing client data where a public repository's workflow can read it needs James's decision; `AutoSetup` on a 300 MB base adds an unknown time to a build already near its limits; the CoA modules' own SQL must load too. Feasibility: OPEN |
| 2C (cheap, partial) | **No-database start**, as upstream's `smoke-test-linux.sh` does: run the built program with the packaged `.conf.dist` files for 30 seconds and check it reaches "Loading Modules Configuration" and reports no missing config file | A packaging mistake, a missing DLL, a crash in static initialisation or script registration (`sScriptMgr->Initialize()` runs before the database starts) | Would **not** have caught build 57. Costs about a minute. Worth having only as a floor |
| 2D | The planned local build loop on the VM (docs/roadmap.md item 1) makes 2A natural: the build tree and the data are on the same machine | As 2A | Roadmap item, not started as far as the repository shows |

Pass/fail for 2A or 2B:

| Check | Pass | Fail |
|---|---|---|
| Exit code of the dry run | 0 | Anything else: do not install; keep the running build |
| Log contains | `World Initialized In` and `Dry Run Completed, Terminating.` | Missing either |
| Log does not contain | `Dry Run Completed With` (failed database updates), `ASSERT`, `Duplicate blank sub-command` | Any present |
| Revision on the first log line | Equals the build's `core-revision.txt` | Differs |
| Time | Under 25 minutes (StartAndCheck allows 30 for a real start) | Over: treat as failed, do not install |
| Databases used | Names that are not `acore_auth`, `acore_world*`, `acore_characters*` of any realm | Refuse to run at all |

## 5. Stage 3: after the restart on the VM (the "4:37 am check")

Runs after `StartAndCheck` returns true, as a separate read-only script (proposed name
`patch-night/Check-AfterRestart.ps1`), twice: at +2 minutes (quick) and at +35 minutes (settled; with a 4:00 am
restart and about 2 minutes of downtime that is about 4:37, which is where the time in change-risk.md fits). It
writes one line per check to `patch-night.log` and one verdict line to a new `last-check.txt`.

"Baseline" below means the same check's value at the previous good start, kept in a small JSON file next to the
script. Thresholds marked * are **proposed acceptance thresholds (not yet adopted by James)**.

| # | Check | How (all read-only) | Pass | Class on failure |
|---|---|---|---|---|
| 3.1 | World initialised | `Server.log` newer than the start contains `World Initialized In` | Present | HARD |
| 3.2 | Revision equals the tag | First line of `Server.log` `rev. <hash>` against the release body's `Core:` hash and `Core\worldserver.patched-release.txt` | Equal (prefix match, as StartAndCheck does) | HARD |
| 3.3 | Process alive | `Get-Process worldserver`, at +2 and +35 minutes; start time unchanged between them | Same process both times | HARD |
| 3.4 | Right databases | The run's log line `Databases: world <w>, characters <c>.` | `acore_world_wildcard`, `acore_characters_wildcard` while the Wildcard realm is active | HARD |
| 3.5 | Ports answer | TCP connect to the auth and world ports from `Settings\repack.json` (defaults 3724 and 8085; `WorldAcceptsPlayers` already does this for the world port) | Both within 2 s | HARD |
| 3.6 | Console round trip | `server info` through the bridge (`ra-once`), as PatchNight's `Ra` and the status service do | Reply within 20 s containing `Connected players:` | HARD |
| 3.7 | No crash | Files in `Core\Crashes` newer than the start | None | HARD |
| 3.8 | Settings: unknown | `settings-report.txt` line `Unknown, in neither the .dist nor the server program (...): N.` | No name that was not in the previous run's list * (Proposed practice). The context pack's rule is N = 0 (DOCTRINE), but wildcard-settings-and-flags predicts about 28 working settings can never pass it and the refinement `5978ee4` is not on `main`; UNVERIFIED on the VM | SOFT (HARD if a new name appeared and the night's change touched settings) |
| 3.9 | Settings: bad value | `Values it could not use (N):` in the same report | N = 0 * | SOFT, as 3.8 |
| 3.10 | Settings on defaults | `Settings it uses but no config file sets ... (N):` | N equals baseline (the doc: "only a change in their number matters") | INFO |
| 3.11 | Enchant SQL applied | Count of `Applied enchant fix` lines in this run equals the number of `.sql` files downloaded; zero `Enchant fix ... failed` | Both | SOFT (HARD if the night's change was SQL) |
| 3.12 | Errors.log: no new kinds | `errors_log_groups.py --baseline <copy saved before the restart>` (wildcard-diagnostics-and-tooling). Needs patch night to save a copy of `Errors.log` before stopping the world, which it does not do today (the file is rewritten at each start: wildcard-diagnostics-and-tooling) | 0 new kinds of line * | SOFT |
| 3.13 | Bot count | `Characters in world:` from `server info` (bots included, per wildcard-diagnostics-and-tooling) against `AiPlayerbot.MinRandomBots` (750 on 2026-11-22). **Only meaningful with a real player on**: `AiPlayerbot.DisabledWithoutRealPlayer = 1` logs every bot out when nobody is on, and they log in 30 s after the first player | At 4:35 am with nobody on the expected value is **about 0**. Proposed instead: read 10 minutes after the first login of the day, expect at least 80% of the setting * | INFO |
| 3.14 | Tick time | `timing_summary.py` over the `Timing.log` records from +15 to +35 minutes | With nobody on this is the **empty-world floor** (22 Nov: median pass 2 ms, no spikes), not a bots floor; it catches start-up faults only (flag a median well above that floor). No pass/fail number of its own: the tick check that matters needs a real or scripted player session and is the campaign's evening metric (wildcard-lag-spike-campaign, Phase 1 step 5, `spike_gates.py metric`) | INFO |
| 3.15 | Config file sizes | Size of each file under `Core\configs` that settings touch, against baseline | Within 10% * | SOFT. A doubling is HARD: `playerbots.conf` went from 240 KB to 22 MB before anyone noticed |
| 3.16 | Status page | `GET /api/status` on the sign-up service | `login` and `world` true, `server` tag equals 3.2 | SOFT |
| 3.17 | Login probe | A real login (auth handshake, realm list, character list) by a script | **OPEN.** It needs a client implementation of the login protocol and a dedicated account, which is hard stop 1 territory. Until then 3.5 + 3.6 + 3.16 stand in for it. The character list is worth timing when this exists: it once took 40 s (#84) |

About the tick and bot checks (3.13, 3.14): with `AiPlayerbot.DisabledWithoutRealPlayer = 1` (set since 30 Oct,
`server-settings.txt:479`) a check at 4:15-4:35 am sees an **empty world**: no bots are logged in and the tick is
a few milliseconds whatever was merged. So a tick or bot check at that hour can never catch a lag regression. Two
honest options: run those two checks with a real or scripted player session (a scripted login is hard stop 1
territory, see 3.17; OPEN), or state that they measure only the empty-world floor, as the table now does. The
lag pass/fail numbers live in one place, the campaign's proposed exit metric (wildcard-lag-spike-campaign,
Phase 1 step 5); this spec states none of its own. One day of readings exists (22 Nov, one player); a
multi-evening baseline does not.

### Verdict and rollback (proposed, NOT BUILT YET)

| Verdict | When | Action |
|---|---|---|
| PASS | Every HARD check passes, no SOFT check fails | Write `last-check.txt`; update the baseline file |
| HOLD | Every HARD check passes, at least one SOFT check fails | Leave the server up. Notify James. Do **not** update the baseline. No further automatic change may go in until a person clears it |
| ROLL BACK | Any HARD check fails at +2 or +35 minutes | See below |

Rollback must undo exactly what the night changed, so it depends on the kind of change. This is why the LOW path's
"one automatic change per night" matters: with one change there is one thing to undo.

| What changed tonight | Undo | Exists today? |
|---|---|---|
| A new build was installed | Put back the **previous patched** program (keep it as `worldserver.previous.exe` at install time) and its release tag; only if there is none, the official program | Only the official-program fallback exists |
| Settings | Restore the newest folder under `Core\configs\settings-backup\` (Apply-ServerSettings keeps the newest 20) and restart the world | Backups exist; restore is manual |
| SQL in `sql/enchants` | Revert the merge on GitHub, then restart: the next start downloads `main` again and `000-reset.sql` removes the rows. **Not** enough for files that change stock tables (lint info `sql-outside-reset`): those need a reverse statement | Manual |
| Addon, launcher, site | Revert the merge; the next run republishes. Players who already synced keep the bad file until then | Manual |
| Anything touching character or account data | Cannot be rolled back by any of the above. Such changes are hard stop 7 and never automatic | n/a |

Limits to respect (James's stated tolerances): about 30 minutes of downtime, about 15 minutes of data loss. A
rollback is itself a restart of about 2 minutes; two failed attempts in a row must stop and page a person rather
than loop. Proxmox VM snapshots exist and have never been needed; a snapshot rollback loses character progress
since the snapshot and is James's decision alone.

### Acceptance for building stage 3

1. Run on seven consecutive ordinary nights in report-only mode: zero HARD failures, and every SOFT failure
   explained.
2. Fault injection on a quiet night, each with James present: (a) a setting line with a misspelled name: 3.8
   reports 1; (b) an SQL file with a deliberate duplicate insert: 3.11 fails; (c) the world process killed at +5
   minutes: 3.3 fails at +35.
3. Only after 1 and 2: let HARD failures trigger the rollback, first for the "new build" row alone.

## 6. Order to build in

1. Stage 1 (pure CI, touches nothing live, pays back on the first failed anchor).
2. Stage 3 in report-only mode (read-only on the VM; gives the baseline the thresholds need).
3. Stage 2C (one minute in the build, a floor).
4. Stage 2A or 2B after measuring whether a second world load fits on the VM.
5. Rollback automation last, one row of the table at a time.

Until at least stages 1 and 3 exist, no change can honestly score L4 = 1 on the strength of a "smoke test": see
the L4 section of SKILL.md.
