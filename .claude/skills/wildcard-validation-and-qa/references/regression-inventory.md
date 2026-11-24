# Regression inventory: turning each past incident into a check

Read this when you are choosing what check to build next, or when a new incident happens and you want to add it
the same way.

The idea (proposed practice, not yet adopted by James): every incident that reached the build, the server or a
player becomes one row here with the cheapest check that would have caught it, and that check is built if it costs
less than the incident did. A project with no tests gets its first tests from its own history, because those are
the failures known to be possible here. The full stories are in the sibling wildcard-failure-archaeology; this
file only keeps what a check needs.

Cost reminder: a failure found in the build costs about 3½ hours and a day; one found at patch night costs a night without the
change, or without Mystic Enchants if the fallback fires; one found by a player costs trust.

## Top 10 (ranked by cost x how cheaply a check would have caught it)

| # | Incident | Date, evidence | Where it was caught | Check that would have caught it earlier | Status of that check |
|---|---|---|---|---|---|
| 1 | Build 57 stopped at start-up: "Duplicate blank sub-command". SQUID 3.0 and the core's auction bot both registered `.ahbot` commands; the official build patches SQUID and we had taken it unchanged | 19 Nov, 01159e2 | On the VM, after a full build that passed `--version` | A start that reaches world initialisation before the build is installed (`--dry-run` with a database and data files) | NOT BUILT YET: smoke-test-spec.md stage 2A/2B |
| 2 | First build with mod-dungeon-clear died at step 1288 of 3197: compiler command line too long. The official build passes a CMake flag we did not | 19 Nov, 2606a77 | 1-2 hours into the build | Compare our workflow's `cmake` flags and module list with the official `server-binaries.yml` at the release's build commit whenever `resolve_release.py` reports a new module | NOT BUILT YET. Candidate for wildcard-build-and-env |
| 3 | Patch 90's here-string had no final newline, so an added `#include` ran into the next line; MSVC ignored it and a class was undeclared | 21 Nov, e0cc2f5 | Deep in the build | Pre-flight that reproduces the here-string exactly, then a syntax-only compile of the touched file | Caught by the pre-flight's text check (demonstrated on a scratch copy, wildcard-patch-authoring); a real compile is still NOT BUILT YET (stage 1.5) |
| 4 | A constant named `SYNCHRONIZE` compiled on Linux and failed on Windows (a Windows header macro) | 16 Nov, a4048e7 (#176) | The Windows build | Static scan of `patches/` for declarations named after Windows macros | **BUILT**: `repo_lint.py` check `win-macro`. Replayed on the pre-fix file: reported at line 9506 |
| 5 | `.legendary` command: types used without their namespace; build failed | 12 Nov, 0220a49 | The build | Syntax-only compile of the touched file against the patched core | NOT BUILT YET (stage 1.5) |
| 6 | Patch night brought the Wildcard realm up on the other realm's characters database after a manager update changed what `manage.py` writes | 19 Nov, d5412a9 | After the start (how it was noticed is not recorded) | Assert the world and characters database names before starting the world | **BUILT** on the day: `OnActiveRealm` in PatchNight.ps1 refuses to start. Stage 3 check 3.4 re-reads it afterwards |
| 7 | `playerbots.conf` grew from 240 KB to 22 MB over 16 settings writes (UTF-8 read as Windows-1252 and written back), and one bot setting stopped matching | Found 22 Nov, ba59783 | After 16 writes, while reworking the settings script | (a) Apply the settings twice to a copy: the second pass must change nothing. (b) Config size against the previous start | (a) NOT BUILT YET, cheap. (b) NOT BUILT YET: stage 3 check 3.15 |
| 8 | The world server stopped on a channel chat message that a bot built without a channel name | 20 Nov, 3a50d87 (patch 81) | Live, by the crash | None in advance: this is a rare runtime path. What is cheap is noticing fast: crash file newer than the start, process start time changed | NOT BUILT YET: stage 3 checks 3.3 and 3.7. The `patch-night-checker` agent looks for crash files when asked |
| 9 | The download manifest listed IIS's `web.config`, which is never served; every launcher stopped on the 404 | 8 Nov, c3b4125 | By players | After publishing, request every changed file in `manifest.json` and expect 200 | NOT BUILT YET here; see wildcard-client-and-web (`check_client_web.py`) |
| 10 | Client patch: added spells carrying a class family crashed the character-creation screen | 7 Nov, dc2a5da | By a person in the client | Manual checklist item "open character creation" after any client patch change | Written down: how-to-test-each-layer.md section 6. Cannot be automated without driving a client |

## The next ten (same treatment, shorter)

| Incident | Evidence | Cheapest check | Status |
|---|---|---|---|
| "Rebuild bots" removed 0 of 2,100: `mysql` on Windows ended lines with a carriage return, so no line matched | 30 Oct, 0a04f12 | Verify the effect, not the exit code: count what is left afterwards | BUILT into the script (`leftCount`). General rule for every script step |
| Enchants scripted by us that the core already handled: effects happened twice | 17-18 Nov, f70bb96, 7dcb81f, 2c8f3d7 | Before scripting an enchant, search the pinned core for its spell id and name; `enchants/core-overlap-review.csv` records the review | Manual; a script over the core's `spell_script_names` and proc tables is a candidate for ascension-restoration |
| Four "taught" spells were only an effect piece of the real ability | 3 Nov, tracker notes | The in-game teach test (seconds each) | Caught **by the test**: this is the evidence that in-game testing pays |
| Arcane Charge retarget broke the whole helper | 2 Nov, 29eac6a, d2ebbdb | The in-game test | Caught by the test, reverted the same day |
| Character list took 40 s: a full-table delete at every login | 8 Nov, 257158e (#84) | Time the character list in a login probe; slow query log (now on, over 0.5 s) | Slow log BUILT (095); probe NOT BUILT YET (3.17) |
| Console logging on the world thread (the commit's stated cause; changed by settings 20 Nov, effect never measured, status OPEN: the log was 2.99 GB again on 22 Nov before the rotation had run): 2.9 GB log, 99th percentile tick 586 ms | 20 Nov, f9dc45a | Log growth per hour and tick percentiles after each start | Timing.log BUILT (9ba9f45); threshold check NOT BUILT YET (3.14) |
| Pets page blank: a query used `creature.id1`, this core has `id` | 21 Nov, 2563565 | `GET /api/pets` returns a non-empty list after each publish | NOT BUILT YET (3.16 covers `/api/status` only; add pets) |
| Patch 60's anchors would have thrown on the next core release | 15 Nov, c4b6718 | Run the pre-flight against the upstream branch head as well as the pinned release, daily | Candidate for wildcard-patch-authoring; this one was caught by hand **before** the build, which is the model |
| Enchant collection window froze the game on every query | 21 Nov, 4fdb6a0 | Manual checklist: open, page and filter the window | Written down: how-to-test-each-layer.md section 5 |
| Wildcard heroes (class 10) missing from a class table: shield and stance bug | 22 Nov, docs/agents/context/patches.md | In-game test on a Hero as well as a CoA class; grep new code for class tables | Manual: section 3 of how-to-test-each-layer.md |

## How to add a row

1. One line each: what happened, the date, the commit or PR that fixed it.
2. Where was it caught (local check, build, patch night, by a person, by a player)? Each step later is costlier.
3. Name the earliest stage that could have caught it and the check, concretely enough to implement.
4. If the check is static and runs in seconds, add it to `repo_lint.py` with a planted mistake in
   `repo_lint_selftest.py` (SKILL.md, "How to add a check"), then replay it on the pre-fix commit to prove it
   fires: `git show <fix>^:<path>` into a scratch folder and run the lint with `--root`.
5. If it needs the server, add it to the stage 3 table in smoke-test-spec.md with a pass rule and a failure class.
6. If nothing can catch it in advance (row 8), say so and write the detection check instead.
