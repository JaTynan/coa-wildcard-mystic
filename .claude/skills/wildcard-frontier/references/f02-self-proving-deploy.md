# F2. A self-proving overnight deploy

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Every step here touches patch night or rollback, which is **hard stop 5**: HIGH,
James merges, never automatic. Classify with `wildcard-change-control` first anyway.

## 1. Goal and owner

After each overnight restart the server should prove by itself that it is healthy, and put itself back on the last
good state when it is not. Owner: the pipeline. It is what makes the LOW path in `change-risk.md` real.

## 2. Where the project stands (2026-11-22)

What `patch-night/PatchNight.ps1` does today:

| Part | What it does | Where |
|---|---|---|
| Fetch | Downloads the **current head of `main`** as a zip at run time: settings, SQL fixes, addons, launcher, sign-up service, and the patch-night scripts themselves | `function FetchRepo` |
| Guard on its own scripts | New `.ps1` files replace the current ones only if every one parses; a settings script that does not parse is skipped | `ParsesCleanly`, inside `FetchRepo` |
| Countdown | Warns players at 30, 15, 10, 5 and 1 minutes while it prepares; if preparing fails the restart is called off and the server stays up | section "4. Staged (22 Nov)"; `Finish` |
| SQL fixes | Runs every file in name order. **A file that fails is logged as `[WARN]` and the run continues** | `function ApplyEnchantFixes` |
| Start check | Waits up to 30 minutes for "World Initialized In" in this start's `Server.log`; checks the core revision on line 1 is the expected one; waits 60 s; checks the process is still alive | `function StartAndCheck` |
| Fallback | If that check fails and the live program is ours: copy `worldserver.official.exe` back, start again. The result is the **official** server: no patches at all | section "5. The patched server did not come up" |
| Record | `patch-night.log`, `last-run.txt`, "Downtime: N s", `Core\worldserver.patched-release.txt` | `Finish`, end of script |
| Schedules | One task since 23 Nov 2026: "CoA Patch Night", daily, countdown from 3:30 am, restart 4:00 am, installs new builds (PR #240; the old "CoA Nightly Restart" `-NoInstall` task is removed by the register script). It runs only while James is signed in on the VM | `Register-PatchNight.ps1` |

What `docs/agents/context/change-risk.md` says the LOW path is: "fix, Opus analyst agrees, build and smoke test,
merge, installed at the next nightly restart, checked at 4:37 am, rolled back if the check fails. One automatic
change per night."

## 3. Why the current approach falls short

| The LOW path assumes | What exists | Gap |
|---|---|---|
| A smoke test | "World came up on the right core and lived 60 seconds" | Says nothing about whether SQL applied, enchants loaded, players can log in, or the tick time is sane |
| A check at 4:37 am | Nothing is scheduled at 4:37. The `patch-night-checker` agent is read-only and run by hand (on `main` since PR #232 merged on 22 Nov 2026) | **NOT BUILT YET** |
| Roll back if the check fails | Only the program is swapped, and only to the official one | No "previous patched build". No rollback of settings, SQL, addons or site: the run always takes the head of `main`, so there is no notion of "what we ran last night" |
| Installed at the next nightly restart | True for settings, SQL, addons, and (since 23 Nov 2026) for C++ once the evening build has finished | A build that finishes after 3:30 am waits a night; a failed build waits for a fix |
| One automatic change per night | No counter, no automatic merge | **NOT BUILT YET** |

Two concrete failure stories the current check cannot see:
1. A merged SQL file has an error. It is logged `[WARN]`, the world starts, the run ends `[OK]`. The enchants
   that file fixed are now broken (because `000-reset.sql` removed last night's rows first), and nothing says so.
2. A merged setting makes the world start but behave badly (for example a bot setting that doubles the load). The
   run ends `[OK]`. The fallback to the official program would not help anyway, because the settings stay.

Also: because the fallback keeps the same settings and SQL, a failure caused by them will fail the official server
too, and the run ends with "the server is not up".

## 4. This project's asset

- **The repo is the whole state** (outside the databases and the program file). So "roll back" can mean "run patch
  night against an older commit". GitHub serves any commit as a zip (`archive/<sha>.zip`); `FetchRepo` already uses
  that form for third-party addons.
- **`000-reset.sql`** makes SQL fixes reversible for rows the reset owns: yesterday's files give yesterday's rows.
  Not for the files the reset cannot undo (list: `ascension-restoration` section 5 item 3), not for MySQL
  `SET PERSIST`, and not for a setting whose line was added since (removing a line leaves the value in the
  config: set the old value instead).
- **Settings backups** are already kept: `Core\configs\settings-backup\<date-time>\`
  (`server-settings/Apply-ServerSettings.ps1`).
- **Free health numbers in `Server.log`** at every start: "Loaded N Mystic Enchant action rows for M enchants",
  "Mystic enchants left out of rolls: N whose spell does not exist, M whose spell does nothing",
  "Mystic enchants given an extra taught spell: N", "Worldforged enchants working: ...". A change in these that
  nobody intended is a regression signal.
- **`Timing.log`** gives tick numbers within minutes of the start (F4).
- **Downtime is already measured**, so "back within 30 minutes" can be checked.
- **VM snapshots** exist as the last resort. Never needed so far. They also roll back the character database, so
  they are not the tool for a bad setting.

## 5. First three steps in this repo

### Step 1. A health check after the start, report only

- Create `patch-night/Check-Health.ps1` (read-only). Called at the end of `StartAndCheck`, and able to run by hand.
  It checks and logs one line each:
  1. every SQL file logged "Applied" in this run (no "failed");
  2. the start-up count lines above are present and inside the bands in a new file
     `patch-night/expected-health.json` kept in this repo (for example "action rows at least 40", "left out of
     rolls: missing at most 20"). A PR that changes enchant data changes the band in the same PR;
  3. no new kind of line in `Errors.log` since this start, and no new file in `Core\Crashes`;
  4. the console answers `server info`, and the world port answers (`WorldAcceptsPlayers` already exists);
  5. the settings report has no "Bad value" and no unknown name that was not in the previous run's list. (The
     context pack's rule is "0 unknown", DOCTRINE; `wildcard-settings-and-flags` predicts about 28 working
     settings can never pass it and the refinement `5978ee4` is not on `main`. UNVERIFIED on the VM.)
- It ends with one line: `[OK] Health: 5 of 5` or `[WARN] Health: FAILED <which>`. **It changes nothing and rolls
  nothing back.** `last-run.txt` gains the health result.
- Add the health lines to `docs/agents/context/patch-night.md` ("What a healthy run looks like") so the checker
  agent reads them.
- **Class:** hard stop 5. HIGH, James merges. Risk is small (read-only), but a check that throws could end the run
  early, so wrap it so that its own failure is only a `[WARN]`.

### Step 2. A last-good pin and a one-command manual rollback

- When a run ends OK **and** the health check passed, write the commit of `main` it used to
  `patch-night/last-good.txt`, and keep the previous patched program as `Core\worldserver.previous.exe` when a new
  build is installed.
- To know the commit, `FetchRepo` must ask GitHub for the head commit of `main` first and then download that
  commit's zip, instead of the branch zip.
- Add a `-Ref <commit>` parameter to `PatchNight.ps1`. With it, `FetchRepo` downloads that commit. Add
  `Rollback-LastGood.cmd`: runs patch night now with `-Ref` set from `last-good.txt` and no build install.
- This gives James an undo for owned SQL rows and for settings that existed at the last-good commit, in one
  double-click. Not undone: the program, character data, the SQL files the reset cannot undo, `SET PERSIST`
  values, config lines added since, and client files friends have already synced.
- **Class:** hard stop 5. HIGH, James merges.

### Step 3. Automatic rollback, proven by drills

- If the health check fails after a patch night: run once more with `-Ref <last good>`; if the failure was
  after a build install, put `worldserver.previous.exe` back first (not the official one). Never more than one
  automatic attempt a night. Always end by saying plainly in `last-run.txt` what was rolled back and from what.
- A scheduled "4:37" task is then just `Check-Health.ps1` run again 30 to 40 minutes after the restart, with the
  tick budget (F4) added. Register it in `Register-PatchNight.ps1`.
- Before it is switched on, run three drills on a quiet night, each from a PR that is reverted straight after:
  (a) an SQL file with a syntax error; (b) a setting with a bad value; (c) a build that fails its start
  (only once F1 step 3 exists, or by pointing at a deliberately wrong build).
- **Class:** hard stop 5. HIGH, James merges. Needs 14 nights of step 1 reports with no false alarm first.

## 6. Milestone

**You have a result when** three drills out of three (a deliberately broken SQL file, a bad setting value, a build
that will not start) each end with the server back on the last good state **within 30 minutes** of the scheduled
restart, with **no human action**, and the 14 nights before the drills show **zero** false health failures.

It is falsified by one drill that needs James, one that takes longer than 30 minutes, or one false alarm that
would have rolled back a good night.

## 7. Known wrong paths and risks

- **"World Initialized" as proof.** It proves the program loaded. Both failure stories above pass it.
- **The official server as the only fallback.** It removes every patch, including the one that lets Wildcard use
  Mystic Enchants. It is a last resort, not a rollback.
- **Snapshot rollback for a bad change.** It also rolls back characters. James accepts about 15 minutes of data
  loss; a snapshot from the evening loses hours of play.
- **Rollback loops.** One automatic attempt, then stop and say so.
- **A health check that needs GM commands or a logged-in character.** That is hard stop 1 territory and fragile.
  Logs, ports and the console's `server info` are enough for step 1.
- **Bands that are too tight.** A band of exactly N fails every time someone adds an enchant. Bands, updated in
  the PR that changes the data.
- **An LLM agent with write access as the 4:37 check.** The check must be a plain script. The agent only reads and
  reports.
- **Forgetting the tasks need James signed in.** No session, no run, no check. The health check must also notice
  "no run happened" (the checker pack already lists this).
- **Many merges a day.** With 20 merges between two nights, "last good" versus "tonight" is a 20-change difference.
  Rollback still works, but finding the culprit does not get easier. This is where the written rule ("one PR per
  patch night") and practice differ; James has not resolved it.

## 8. Dependencies

Step 1 uses F4's budget once it exists (it can start without). Step 3's build drill needs F1 step 3. F3's
automatic path needs this frontier's step 3. F10 needs steps 1 and 2.
