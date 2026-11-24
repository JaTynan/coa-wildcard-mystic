# How to test each layer today, step by step

Read this when you have a change in hand and need to know exactly what to run to earn each rung of the evidence
ladder (the ladder itself is in SKILL.md). "Today" means with what exists on 2026-11-22: no test suite, no smoke
test, one live server.

Before any step that changes what the live server does (applying settings, running SQL against the realm's
database, installing a build, restarting): **classify with wildcard-change-control first**. Testing does not exempt
a change from its class, and James merges.

Paths starting `C:\` or `F:\` are on the server VM. Statements about what the VM's logs contain come from the
scripts and docs in this repository, not re-verified on the VM on 2026-11-22.

## 0. Every change, first (seconds)

```
python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py --no-info
```

Compare the result with `references/lint-baseline-2026-11-22.md`: six warnings were already there. Anything else is
yours. Exit code 1 means an error: fix it before going further.

## 1. Settings (`server-settings/server-settings.txt`)

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Run the lint (step 0) | No `settings-format` or `settings-dup` finding | 1 |
| 2 | Read the comment above the line you changed | Your value is inside the range the comment states. (A "standard change" in docs/agents/context/change-risk.md is exactly this: a value change to a setting already in the file, within the range its comment states) | 1 |
| 3 | After the merge, at the next start (the 3:30 am patch night, or `server-settings\Apply-Settings.cmd` by hand with James's OK), open `C:\Games\CoA Server\server-settings\settings-report.txt` | The line `Unknown, in neither the .dist nor the server program (...): N.` lists no name that was not there at the previous run (Proposed practice, not yet adopted by James). The context pack's rule is 0 (DOCTRINE: PR #232), but wildcard-settings-and-flags predicts about 28 working settings can never pass it and the refinement `5978ee4` is not on `main`; UNVERIFIED on the VM. And, under "The world server's own warnings at this start", `Values it could not use (0):` | 5 |
| 4 | In `C:\Games\CoA Server\patch-night\patch-night.log`, the last run | A line `Settings: the server runs N setting(s) on defaults ... and could not use 0`. N on defaults is normal; only a change in N matters (docs/agents/context/patch-night.md) | 5 |
| 5 | Look at the effect in game, or with `server info` / the status page for server-wide ones | The behaviour the comment promises | 6 |
| 6 | For anything on the performance list: measure before and after (wildcard-diagnostics-and-tooling) | Numbers, with the same bot count and time window | 7 |

Notes:

- "0 unknown" proves the server *recognises the name*. It does not prove the value did what you wanted.
- A setting that needs a newer build than the one installed is "unknown" until that build is in. The comments say
  "needs the build with ..." for those; check `Core\worldserver.patched-release.txt` for the installed tag.
- The settings file says changes take effect at the next start "(or .reload config for most of them)". Which ones
  do not reload is not listed anywhere: UNVERIFIED per setting; a restart is the only sure way.
- Nothing is applied while the manager has a different realm active (first lines of the settings file).

## 2. SQL (`sql/enchants/*.sql`)

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Lint (step 0), then the deeper `enchant_sql_lint.py` in the sibling skill ascension-restoration | No `sql-*` error | 1 |
| 2 | **Scratch-database double run** (below) | Both runs end with exit code 0 and print no `ERROR` line | 2 |
| 3 | After the merge and the next start, in `patch-night.log` | One `Applied enchant fix <file> to <database>.` line per file and **no** `Enchant fix <file> failed:` line. A failure is only logged at WARN and the run still ends `[OK]`, so you must look | 5 |
| 4 | In game with a GM character (section 4) | It does what the tooltip says | 6 |

### The scratch-database double run

This is the repository's stated practice: "write the SQL, run it twice on a scratch database"
(docs/enchant-restoration.md), and "its SQL loaded twice into a scratch database" for every enchant batch
(enchants/epic-notes-header.md). The second run is the point: every file runs again at **every** server start, so
a file that only works once breaks the second night.

What the repository shows about where that scratch database is: `enchants/enchant_audit.py` (function `db_set`)
reaches "the test server's database container" with `docker exec <container> mysql ... acore_world`, trying the
container names `ac-database`, `azerothcore-wotlk-ac-database-1` and `coa-test-ac-database-1`, and its usage line
names a folder `~/coa-test/env/dist/data/dbc`. So a Docker test server with a world database exists (or existed) on
a Linux machine. **Which machine, and whether it is still there, is UNVERIFIED** (the roadmap mentions "a native
build on [James's Linux desktop] for the test server"). Check with `docker ps` on that machine.

With such a container, in name order, twice:

```
# from the repository root on the machine that has the container; credentials as in enchants/enchant_audit.py
for run in 1 2; do
  for f in sql/enchants/*.sql; do
    docker exec -i <container> mysql -uroot -p<password> acore_world < "$f" \
      || { echo "RUN $run FAILED in $f"; break 2; }
  done
done
```

- Run **all** files in order, not just yours: `000-reset.sql` must run first, and later files may depend on
  earlier ones.
- The `mysql` client stops a file at the first error and returns non-zero. That is the signal.
- Proposed practice (not yet adopted by James): after each run, count rows in the tables your file touches and
  check run 2 equals run 1 (`SELECT COUNT(*) FROM spell_proc`, and so on). Purpose: catches a file that re-runs
  without error but adds rows each time. Motivating case: the lint's `sql-rerun` rule cannot see rows built by a
  `SELECT`.
- A scratch database made from the stock AzerothCore world data is not the same as the CoA realm's world database:
  it has no `coa_mystic_enchant_aura_link` unless the CoA core's SQL was loaded. A file that fails only for that
  reason tells you about the scratch database, not the file.

**On the VM's own MySQL: UNVERIFIED, and ask James first.** The repository evidences how patch night reaches MySQL
(`C:\Games\CoA Server\mysql\bin\mysql.exe --defaults-file="C:\Games\CoA Server\mysql\admin-client.ini"`, function
`Sql` in PatchNight.ps1) and that the Wildcard realm's world database is `acore_world_wildcard`. It does **not**
evidence anyone creating a scratch database there, whether `mysqldump.exe` is in that folder, or how long a copy
takes. A copy of the world tables is a heavy read on the same MySQL the live server uses, and lag spikes are the
project's top problem, so do not do it while players are on. If James agrees, the minimum to copy is the tables
`000-reset.sql` touches plus the ones your file touches, into a database with a name no realm uses, and drop it
afterwards. Never point a test at `acore_world_wildcard`, `acore_characters_wildcard` or `acore_auth`.

## 3. C++ patch (`patches/NN-*.ps1`, `*.patch`)

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Lint (step 0) | `changes-row`, `patch-number-dup`, `settings-missing`, `win-macro`, `ps1-herestring`, `eol-patch-script` all clean | 1 |
| 2 | Patch pre-flight from the sibling wildcard-patch-authoring (`scripts/preflight.py`): applies every patch and script to the pinned sources in a scratch workspace, as the workflow does. It needs `pwsh` | Every script reports OK. This is the step that saves a 2-3 hour build from dying at "Apply our patch scripts" | 2 |
| 3 | Compile check of the files you touched, against the pinned core with all patches applied. Practice recorded in history: "compiles with -Wall -Wextra against core c3f2fd4b2395 with our patches" (5c2a489), "compile-checked ... also with the Windows header macros defined" (enchants/epic-notes-header.md). The exact command is not in the repository: see wildcard-patch-authoring / wildcard-build-and-env | No error. A Linux compile does **not** prove the Windows build: SYNCHRONIZE (a4048e7), a missing final newline (e0cc2f5) and an unqualified namespace (0220a49) each cost a build | 3 (partial) |
| 4 | The GitHub build (about 3½ hours, automatic the evening after the merge; wildcard-build-and-env) | The workflow's steps "Apply our patches", "Apply our patch scripts", "Build worldserver" and "Check it starts and reports its revision" (`worldserver.exe --version`) pass and a release `wcme-<tag>-build<N>` appears | 3 and 4 |
| 5 | Install: the next 3:30 am patch night, or `Run-PatchNight-Now.cmd` (hard stop 5: James) | `patch-night.log` ends `[OK] Patch night OK: installed wcme-...` and has `Server is up on core <revision>` | 5 |
| 6 | Read `Core\Logs\Errors.log` for kinds of line that were not there before the start, and `Core\Crashes\` for a file newer than the start (`errors_log_groups.py --baseline` in wildcard-diagnostics-and-tooling). Nothing does this automatically | No new kind, no new crash file | 5 |
| 7 | In game with a GM character: exercise the change, with its setting on **and off** if it has one | What the CHANGES.md row says, both ways | 6 |
| 8 | If the code runs per tick, per packet or for bots (L3 = 3 in the risk matrix): tick times before and after | wildcard-diagnostics-and-tooling | 7 |

Checks worth doing by hand at step 7 because history shows they bite (docs/agents/context/patches.md): a bot in
the same situation (code written for players runs for about 750 bots); a Wildcard Hero (class 10, which class
tables often have no row for: "the shield and stance bug of 22 Nov"); a character in a group; after a relog.

## 4. Mystic Enchants, talents and racials in game (GM character, target yourself)

From docs/enchant-restoration.md, "Testing in game". **These are for James's GM test character. A session does not
send GM or console commands (including `additem` through the console) on the live realm without his say-so: hard
stops 1 and 2.**

| Command | Use |
|---|---|
| `.aura <enchant spell>` | Puts the enchant on you without a scroll. With the patched server it also teaches the enchant's spell (commit 6922a11), so "teach" enchants can be tested in seconds |
| `.list auras` | Lists your auras: a linked twin shows up here |
| `.unaura <spell>` | Removes it again |
| `.learn <spell>` | Gives you an ability to trigger the enchant with |
| `.lookup spell id <spell>` | Prints a clickable spell link, to check the tooltip |
| `.additem <scroll item>` | The full path through a scroll: item ids are in the tracker's `scroll item` column |
| `.racial` | Any player: what your signature racial is doing right now, in numbers (patch 80) |

`enchants/test-checklist.csv` already holds the commands and the expected result for 561 fixes: filter it by `file`
(your SQL file number) or by `spell`. Do the quick types first: "`twin` and `teach` take seconds each".

**Pass rule (doctrine):** "A fix passes when it does what its tooltip says."

What a thorough enchant test covers (proposed practice, not yet adopted by James; each line is a failure that a
recorded test actually found):

1. The effect appears (the buff, the taught spell, the proc). Burst of Thorns showed "buff icon and tooltip only".
2. The numbers move by the stated amount. Measure a before and after: Quick Conjure Water, 2.97 s to 2.524 s.
3. It fires only from the abilities the tooltip names, and no more often than stated. File 015 exists because 33
   Legendaries fired on every hit.
4. It is not doubled. Reviews on 17-18 Nov removed several scripts because the core already did the same thing.
5. It survives a relog ("twin present after relog", 31 Oct).
6. The full path once per batch: apply from a scroll or the altar, not only `.aura`.
7. Any client crash or oddity during the test is written down even if unexplained (All that is Right, 2 Nov).

## 5. Addon (`addon/Wildcard*`)

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Lint | `toc-*` clean; the `## Version` raised if players should be able to tell the copies apart (the lint cannot check "raised") | 1 |
| 2 | Copy the addon folder into a client's `Interface\AddOns` and log in (a private client, not the VM's `F:\CoAClient`, which the launcher syncs to every player) | The addon is listed and ticked at the character screen's AddOns button, not "out of date" | 4-equivalent |
| 3 | In game: open the window or tooltip the change touches; `/reload` once | No Lua error box. Turning error display on with `/console scriptErrors 1` is standard for this client version but UNVERIFIED on the CoA client | 6 |
| 4 | For anything that loops over the 6,440 enchants: open, page and filter the collection window | No freeze. Commit 4fdb6a0 fixed a window that froze the game on every query | 7 |

How it ships: patch night copies every folder under `addon/` to `F:\CoAClient\Interface\AddOns` (FetchRepo), and
the launcher takes it to players. So a merge to `main` reaches every player after the next patch night with
no build. That makes "addon text" a standard LOW change and "addon logic" L1 = 2.

## 6. Client patch (`client-patch/`, builds `patch-ZZW.MPQ`)

The archive is the client's own data and is never committed (the lint's `client-data` check enforces that).

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Lint; `py-parse` covers the builder scripts | Clean | 1 |
| 2 | Build it from your own client files with `client-patch/build_client_patch.py` | The script finishes and writes the archive | 2 |
| 3 | Put it in a private client's `Data` folder and start the client | The client reaches the login screen | 4-equivalent |
| 4 | Open **character creation** | No crash. On 7 Nov added spells that carried a class family crashed exactly this screen (dc2a5da) | 5-equivalent |
| 5 | In game: `/run print(GetSpellInfo(<an id the patch adds>))` | The spell's name. The recorded test: `GetSpellInfo(911367)` returns Critical Mass with its icon (2 Nov) | 6 |
| 6 | Check one tooltip and one buff icon the change touches, and one stock spell nearby | They read as intended; the stock one is unchanged | 6 |

Only then is it copied to `F:\CoAClient\Data`. **[James, or with his say-so.]** This changes what every friend's
client downloads and cannot be recalled once synced: classify with wildcard-change-control first. From there every
player's launcher downloads it. There is no automatic
rollback for a client file once players have synced it, other than publishing a corrected one (or listing it under
`remove` in `launcher/launcher-settings.json`).

## 7. Launcher and download site (`launcher/`)

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Lint | `launcher-version`, `json-parse`, `py-parse`, `eol-cmd` clean. Raise `$LauncherVersion` (Windows) or `LAUNCHER_VERSION` (Linux) when the launcher itself changed: clients update only when the published number is higher than their own | 1 |
| 2 | After patch night has run `Publish-WildcardSite.ps1`: its one-line summary is in `patch-night.log` | `Published N client files (X GB), launcher version V, ... to F:\wildcard-site.` and no `Publishing the friends' download site failed` | 5 |
| 3 | **Manifest check.** Fetch `<site>/manifest.json` and `<site>/launcher.json` | `manifest.json` parses and has `generated`, a non-empty `files` list whose entries have `path`, `size`, `md5`, `mtime`, and `remove`; `launcher.json` has `realm`, `clientArchiveUrl`, `clientArchiveBytes`, `launcherVersion`, `linuxLauncherVersion` (field names from Publish-WildcardSite.ps1) | 5 |
| 4 | Request a sample of the listed files under `<site>/client/` (at least every file added or changed) | Every one answers 200. On 8 Nov the manifest listed IIS's `web.config`, which the web server never serves, and every launcher stopped on the 404 (c3b4125) | 5 |
| 5 | Run the launcher on one real client, Windows and Linux if both changed | It updates itself, syncs, and the game starts | 6 |

The sibling wildcard-client-and-web owns this surface and ships `check_client_web.py`; use it for steps 3-4 if it
covers them.

## 8. Sign-up and status services (`signup/`)

Creating accounts is hard stop 1 and the settings file with secrets is hard stop 4: changes to those parts are HIGH
and wait for James whatever the tests say. Do not create test accounts on the live realm on your own.

| Step | Do | Pass when | Rung |
|---|---|---|---|
| 1 | Lint | `py-parse`, `secret`, `secret-file` clean | 1 |
| 2 | After patch night restarted the "Wildcard Sign-up" task: `GET /api/status` on the sign-up service | JSON with `login: true`, `world: true`, `players`, `characters`, `uptime` and a `server` build that equals `Core\worldserver.patched-release.txt` (keys from signup/WildcardStatus.py) | 5 |
| 3 | `GET /api/pets` | A non-empty list. On 21 Nov the Pets page was blank because one query used a column name from a newer core (2563565) | 5 |
| 4 | Open the page in a browser; for the form itself, James tests with a real invite code | It behaves | 6 |

## 9. Patch night script, installer, build workflow

All three are **hard stop 5**: always HIGH, never automatic. What testing exists:

- A broken `.ps1` cannot reach the VM's copy: FetchRepo keeps the current scripts when a downloaded one "does not
  read cleanly" (`ParsesCleanly`, a PowerShell parse). That protects against syntax errors only.
- The installer refuses a build made for a different core than the manager installed, and puts the official
  program back if the new one will not print its version (vm/Install-WildcardServer.ps1).
- Recorded practice for a risky rewrite: run old and new side by side on copies and compare the output byte for
  byte (commit d802f8c: 266 settings across 12 config files, identical results). Do that for any change to
  `Apply-ServerSettings.ps1`: it takes `-Server <folder>`, so it can be pointed at a copy. Exactly which files a
  copy needs is UNVERIFIED; read the script's first 60 lines.
- The lint parses these scripts only where PowerShell is installed. On the VM, run it there
  (`python repo_lint.py --only parse`): the VM has Python at `C:\Games\CoA Server\Runtime\python\python.exe`
  (PatchNight.ps1) and PowerShell.
- There is no rehearsal for the workflow file: a manual run with `rebuild` ticked publishes a release that the
  next 3:30 am patch night will install, whatever branch it ran on. Start one only from `main`, on James's say-so (hard
  stop 5; wildcard-build-and-env). A draft-release input is proposed in wildcard-build-and-env and NOT BUILT YET.
