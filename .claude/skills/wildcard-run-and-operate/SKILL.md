---
name: wildcard-run-and-operate
description: How the Wildcard server on the Windows VM is run day to day. Covers the weekly patch night and the nightly restart (patch-night/PatchNight.ps1 function by function, with the log lines to search for), the two scheduled tasks and the by-hand run, Start-Server.cmd, the installer and Restore-Official.cmd, the VM file map, the go-live table (when a merged setting, SQL file, addon, script or C++ patch reaches players), rollback runbooks (build, settings, SQL, official server, VM snapshot), Rebuild-WildcardBots.cmd, the RA console bridge, and what a healthy run looks like. Load it when asked "did the server update last night", "why did it not restart", "when will my merged change be live", "how do I start, stop, restart, install or roll back the server", "what do I do after a manager Update click or a Windows reboot", "where is that file or log on the VM", or before touching anything under C:\Games\CoA Server. Who may roll back is decided in wildcard-change-control; this skill holds the procedure.
---

# Wildcard: run and operate

Everything here was read from this repository on 2026-11-22: the checkout `fcfee51` (PR #232's head, which sits on
`62a26e4`, the #230 merge) and `origin/main` at `d3e030f` (#231); `patch-night/`, `vm/` and `server-settings/` are
identical in the two. Nothing was re-verified on the VM that day. Where a claim depends on the VM's real state,
the text says so and gives the command to check.

`docs/agents/*` and `.claude/agents/*` are cited below (hard-stop numbers, "healthy or wrong", the
patch-night-checker). They arrive with PR #232, open and not on `main` on 2026-11-22, so they are
**INTENDED DOCTRINE (PR #232, unmerged on 2026-11-22)**. Check: `git ls-tree --name-only origin/main docs/agents/`
(empty = still unmerged); read them with `git show origin/agents-stage-1:docs/agents/context/change-risk.md`.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Decide whether a change may go ahead, or who merges | `wildcard-change-control` |
| Work out why something is broken from a symptom | `wildcard-debugging-playbook` |
| "It restarted fine but it lags", rubber-banding, long ticks | `wildcard-lag-spike-campaign` |
| Read Timing.log, perf CSVs, the slow query log, or measure something | `wildcard-diagnostics-and-tooling` |
| Understand or change a setting, or the settings file format | `wildcard-settings-and-flags` |
| Trigger, watch or fix the 2 to 3 hour GitHub build | `wildcard-build-and-env` |
| Write or port a C++ patch | `wildcard-patch-authoring` |
| Write an enchant SQL fix, or learn what `000-reset.sql` owns | `ascension-restoration` |
| Launcher, site, sign-up service, bug report relay, client patch | `wildcard-client-and-web` |
| Decide what counts as tested, or design the missing smoke test | `wildcard-validation-and-qa` |
| The history of past incidents | `wildcard-failure-archaeology` |
| GM commands, databases, bot systems in depth | `azerothcore-coa-reference` |

## Start here

| The request | Go to |
|---|---|
| "Did it update last night?" | "Check last night's result (read-only)", then "Healthy or wrong" |
| "When is my merged change live?" | "When does my merged change go live?" (the library's single home for that table) |
| "Roll it back" / "the server is down" | `references/runbooks.md`, table "Which rollback do I need?" (James decides: hard stop 5) |
| "Where is that file on the VM?" | `references/vm-file-map.md` |
| A restore point before a risky change | The manager's own backup is the only tool the repository names; a Proxmox snapshot is James only and has no procedure in the repository: `references/runbooks.md`, "Full VM snapshot rollback on Proxmox" |


## Ground rules before you touch the live server

1. **Classify with `wildcard-change-control` first.** Patch night itself, the installer and rollback are hard stop 5
   in `docs/agents/context/change-risk.md`: always HIGH, never automatic, James decides. Deleting character data is
   hard stop 7.
2. **Read-only checks are always fine.** Reading logs, `last-run.txt`, config files, task definitions and
   `server info` over the console changes nothing.
3. Nothing is edited on the running server by hand (`CHANGES.md`, first paragraph). A hand edit to a config file or
   a database row that this repository owns is overwritten at the next start.
4. Never print `mysql\admin-client.ini`, `patch-night\signup-settings.json` or passwords from config files.

## Words used here

| Word | Meaning |
|---|---|
| VM | The Windows 11 machine that runs the server. Server folder `C:\Games\CoA Server`, client folder `F:\CoAClient` (the script defaults, `PatchNight.ps1:22-24`). |
| Manager | CF-Server-Manager, the desktop app that installed the server and can start, stop and update it. |
| Official server | The `worldserver.exe` the manager installed. The installer keeps a copy as `Core\worldserver.official.exe`. |
| Patched build | Our `worldserver.exe` with `patches/` applied, published by the GitHub build as a release named `wcme-<manager release>-build<N>`. |
| World server, auth server | `worldserver.exe` runs the game world. `authserver.exe` handles logins. MySQL holds the data. |
| RA | Remote Administration, the world server's console. Scripts send it one command at a time through `launcher_bridge.py`. |
| Core revision | The git commit the server was built from. `worldserver.exe --version` and line 1 of `Core\Logs\Server.log` both print it as `rev. <hex>`. |

Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## The three ways PatchNight.ps1 runs a restart

One script does everything. The switches decide how much.

| Run | How it starts | Switches | Countdown | Installs a new build |
|---|---|---|---|---|
| Weekly patch night | Task `CoA Patch Night` | `-Unattended -WarnMinutes 30` | Always 30 minutes | Yes |
| Nightly restart | Task `CoA Nightly Restart` | `-Unattended -WarnMinutes 30 -NoInstall` | Always 30 minutes | No |
| By hand | `patch-night\Run-PatchNight-Now.cmd` | none, so `-WarnMinutes 10` | 10 minutes, skipped if nobody is online | Yes |

`-NoInstall` is the only difference between the nightly restart and patch night. Both download `main`, apply
settings, SQL fixes, addons and the site, and restart the world server. The nightly leaves a newer build alone and
logs `Nightly restart: the new build is left for the weekly patch night.`

Two more modes skip the release lookup: `Start-Server.cmd` (`-StartOnly`) and `Rebuild-WildcardBots.cmd`
(`-RebuildWildcardBots`). Both are covered below.

### What Register-PatchNight.ps1 registers

Read from `patch-night/Register-PatchNight.ps1` on 2026-11-22:

| Task name | Trigger | Players see | World stops at about |
|---|---|---|---|
| `CoA Patch Night` | Weekly, Tuesday, 11:00 pm | Warnings at 30, 15, 10, 5 and 1 minutes | Tuesday 11:30 pm |
| `CoA Nightly Restart` | Daily, 3:30 am | The same warnings | 4:00 am |

Times are the VM's local clock. Both tasks run `powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden
-File "<folder>\PatchNight.ps1" -Unattended -WarnMinutes 30`, and the nightly adds ` -NoInstall`. Task settings:
start when available after a missed time, 3 hour limit, a second copy of the same task is not started while one
runs.

**They run only while James is signed in on the VM.** The principal is the user who ran the register script, logon
type Interactive, not elevated (`Register-PatchNight.ps1:18`). Signed out means no run and no log lines.

**Known discrepancy, not resolved here.** README and the context pack say Tuesday 11 pm and 3:30/4:00, which matches
the script. James has also described the patch night job as Wednesday 4:00 am, with Windows Update on Wednesday at
3 am. The script takes `-Day`, `-Time`, `-NightlyTime` and `-WarnMinutes`, and someone can edit a task in Task
Scheduler, so the tasks on the VM may differ from the repository. Check before you rely on a time (read-only,
written from the script, not executed on the VM on 2026-11-22):

```powershell
Get-ScheduledTask -TaskName 'CoA Patch Night','CoA Nightly Restart' | ForEach-Object {
  $_.TaskName; $_.State
  $_.Triggers | Format-List DaysOfWeek, StartBoundary, Enabled
  $_.Actions.Arguments
  $_ | Get-ScheduledTaskInfo | Format-List LastRunTime, LastTaskResult, NextRunTime
}
```

```cmd
schtasks /query /tn "CoA Patch Night" /v /fo list
schtasks /query /tn "CoA Nightly Restart" /v /fo list
```

Note that the Tuesday patch night and the 3:30 am nightly both run, about four hours apart. A third task,
`Wildcard Sign-up`, starts the sign-up and status service at sign-in. It belongs to `wildcard-client-and-web`.

## Patch night in one page

Full detail, with every log line quoted, is in `references/patch-night-timeline.md`. Read that when you need to
explain a specific log line or failure. The short version:

1. **Self-update** (`FetchRepo`). Downloads `main` as a zip. Copies settings, our addons, pinned third-party addons,
   SQL fixes, the launcher and site, the AI chat files, the sign-up service and the patch-night scripts. If
   `PatchNight.ps1` itself changed, the new copy runs straight away. Scripts that do not parse are not used.
2. **Which core is installed** (`OfficialExe`, `Revision`). Compares the world server's revision with the auth
   server's to catch a manager update.
3. **Which build matches** (GitHub Releases API). Picks the first release whose notes name the installed core.
4. **Countdown starts**, and during it the script downloads and unpacks the build and writes the settings. The server
   stays up for all of that. If preparing fails, players are told the restart is off and the server stays up.
5. **Stop the world server only** (`StopWorld`). MySQL and the auth server keep running.
6. **Rotate console logs** (`RotateConsoleLogs`).
7. **Install** the build if it is new (`vm/Install-WildcardServer.ps1`), then apply settings again.
8. **Start and check** (`StartAndCheck`). Runs the database helpers, starts everything, sets the realm address, waits
   for the world, checks the build, then starts the performance counters and republishes the site.
9. **Downtime line and outcome**. Or, if the patched server did not come up, **fall back to the official server**.

### What "up on the right build" means, exactly

`StartAndCheck` (`PatchNight.ps1:694-734`) returns true only when all of these hold:

- `Core\Logs\Server.log` was written after this start began and contains `World Initialized In`.
- Line 1 of that log has `rev. <hex>`, and that revision and the expected one match as prefixes of each other.
- 60 seconds later a `worldserver` process still exists.

It waits up to 30 minutes, checking every 15 seconds. It gives up early if no `worldserver` process exists 2 minutes
after the start.

It does **not** check that anyone can log in, that the auth server answers, that the SQL fixes applied, that
`Errors.log` is quiet, that a crash happens after the first minute, or that any patch works. This is the only
automatic check after a restart. A broader smoke test is NOT BUILT YET. The design gap is owned by
`wildcard-validation-and-qa`. For lag after a healthy restart use `wildcard-lag-spike-campaign`.

### Failure handling at a glance

| When | What you see | What the script does |
|---|---|---|
| GitHub unreachable | `Cannot download from GitHub (...); using the local copies.` | Carries on with the copies already on the VM. |
| A downloaded script does not parse | `... do not read cleanly; keeping the current copies.` | Keeps the old scripts. |
| Preparing fails during the countdown | `Stopped with an unexpected error: ...` | Announces `Nightly restart cancelled: the server stays up.` in game and exits. The server was never stopped. |
| Installer refuses | `The installer refused or failed; continuing with the server as it was.` | Starts the server it had before. |
| One SQL file fails | `Enchant fix <file> failed: ...` | Carries on with the next file and still starts. The outcome can still say OK. |
| Patched server does not pass the check | `Putting the official world server back...` | Stops everything, copies `worldserver.official.exe` over the live one, starts and checks again. |
| Official server fails too | `Patch night FAILED: the server is not up. Start it in the manager and check patch-night.log.` | Stops. A person has to act. |

After a fall-back the nightly restart does not put the patched build back, because it never installs. The weekly
patch night or `Run-PatchNight-Now.cmd` does.

## When does my merged change go live?

This table is the library's single home for the question; other skills keep a two-line summary and point here.

**A merge to `main` is a deployment.** "Next run" means the next time `PatchNight.ps1` runs in any mode: nightly
restart, patch night, by hand, or `Start-Server.cmd`. Every run downloads `main` first. A start from the manager's
own Start button applies none of this.

| Layer | Repository path | Goes live | Notes |
|---|---|---|---|
| Settings | `server-settings/server-settings.txt` | Next run, at the restart. Normally 4:00 am. | Removing a line does not undo it. See the settings rollback runbook. |
| SQL fixes | `sql/enchants/*.sql` | Next run, just before the world starts | All files run again every start, in name order, after `000-reset.sql`. |
| Our addons | `addon/<folder>` | Copied to `F:\CoAClient\Interface\AddOns` at the start of the next run | Players get them when their launcher next syncs. See `wildcard-client-and-web`. |
| Third-party addons | `addon/third-party-addons.txt` | Next run, only when a pinned commit changed or a folder is missing | |
| Site and launcher | `launcher/` | Next run, published after the world is up | Only if `F:\wildcard-site` exists. |
| Sign-up and status service | `signup/` | Start of the next run. The task is stopped, the files replaced, the task started | Does not wait for the restart. |
| Patch-night scripts | `patch-night/`, `server-settings/*.ps1` | **The same run that downloads them. There is no night of grace.** | The run copies the new scripts over the live ones and, when `PatchNight.ps1` itself changed, re-runs itself as the new copy at once (`PatchNight.ps1:742-754`, since `0a04f12`). The only guard is a parse check: if any downloaded `.ps1` does not parse, all the old copies are kept (`:326-335`). The script's own log line says "used from the next run"; that wording is stale, the code does not wait. So a merged `patch-night/` change (hard stop 5) runs unattended at the next 3:30 am. |
| Installer | `vm/Install-WildcardServer.ps1` | Next install | Patch night uses the copy from `main`, not the one in the zip. |
| C++ patches | `patches/` | Needs a build, then an install by the weekly patch night or a by-hand run. Never by the nightly restart (`-NoInstall`) | See below. |
| Client files | our addons, `patch-ZZW.MPQ`, anything in `F:\CoAClient` | After the run that follows the file landing in `F:\CoAClient`: the site's `manifest.json` is republished, and each friend's launcher fetches the differences the next time it is opened | Addons are copied by `FetchRepo`. The client patch is built and copied into `F:\CoAClient\Data` by hand (James; see `wildcard-client-and-web`). |
| The launcher itself | `launcher/WildcardLauncher.ps1`, `.py` | As client files, and only if its version number was raised (`$LauncherVersion`, `LAUNCHER_VERSION`): a launcher updates itself only to a higher number | Details: `wildcard-client-and-web`. |

**C++ patches need two things.**

1. **A build (the build-once rule).** The daily workflow (03:17 UTC) builds each manager release only once. Its
   check job skips the build when any release named `wcme-<tag>-` exists
   (`.github/workflows/build-worldserver.yml:51-64`). So a patch merged after that release was built is **not**
   built by the daily run. The workflow has to be run by hand with **rebuild** ticked, which takes 2 to 3 hours.
   A finished run publishes a release, and a release is something patch night will install, so starting one is a
   deployment step: James starts it, or a session he has told to (hard stop 5; see `wildcard-build-and-env`,
   which owns the build). Example on 2026-11-22: patch 96 (`13a03d3`, PR #228) is on `main` and in **no build**;
   the newest build, build70, was cut before it.
2. **An install.** Only the weekly patch night or `Run-PatchNight-Now.cmd` installs a build. The nightly restart
   runs with `-NoInstall` and never does: it logs `Nightly restart: the new build is left for the weekly patch
   night.` Patch night installs when the chosen release's tag differs from `Core\worldserver.patched-release.txt`.

**Which release patch night chooses** (`PatchNight.ps1:857-866`): it walks the repository's releases newest
first, skips drafts, and takes the first whose notes carry a `Core:` line with the commit of the core that is
installed. Nothing else is checked. **The branch the build ran on does not matter**: a build started from a
feature branch is as eligible as one from `main`. That is why starting a `rebuild` run, and deleting a release
or marking it as a draft (which changes what is chosen), are hard stop 5 decisions for James.

Build details belong to `wildcard-build-and-env`.

A setting for a patch that is not in the installed build is ignored by the server. It shows up as unknown in
`server-settings\settings-report.txt`.

## Runbooks

Short ones are here. Recovery and rollback runbooks are in `references/runbooks.md`. Read that before any rollback,
after a manager Update click, after a reboot, or before `Rebuild-WildcardBots.cmd`.

PowerShell below was written from the scripts and not executed on the VM on 2026-11-22.

### Check last night's result (read-only)

```powershell
$pn  = 'C:\Games\CoA Server\patch-night'
Get-Content "$pn\last-run.txt"
$log = "$pn\patch-night.log"
$start = (Select-String -Path $log -Pattern '---- patch night started ----' | Select-Object -Last 1).LineNumber
Get-Content $log | Select-Object -Skip ([math]::Max(0, $start - 40))
Select-String -Path $log -Pattern '\[WARN\]|\[FAIL\]|Downtime:|failed' | Select-Object -Last 30
Get-Content 'C:\Games\CoA Server\Core\worldserver.patched-release.txt'
Get-Content 'C:\Games\CoA Server\Core\Logs\Server.log' -TotalCount 1
```

The 40 extra lines matter. The download step logs before the `---- patch night started ----` line.
Then judge the run with "Healthy or wrong" below. The `patch-night-checker` agent does this same check.

### Run patch night now

Classify with `wildcard-change-control` first. Patch night itself is hard stop 5: **James runs it, or says go.** It
restarts the live server and installs any newer matching build. Read-only checks are always fine.

1. Confirm no scheduled run is close. The script has no lock of its own, so a by-hand run can overlap a task.
2. Double-click `C:\Games\CoA Server\patch-night\Run-PatchNight-Now.cmd` on the VM. The window stays open.
3. If players are online it warns at 10, 5 and 1 minutes. If the console reports 0 players it logs
   `No players online.` and restarts at once. Whether bots count as connected players is UNVERIFIED. Read the
   `Players online:` line of a past run to see.
4. Wait for the outcome line. Press Enter to close. Then run the check above.

### Start the server by hand

Classify with `wildcard-change-control` first. Patch night itself is hard stop 5: **James decides.** This start also
deploys whatever is on `main` (settings, SQL, scripts). Read-only checks are always fine.

Use `C:\Games\CoA Server\patch-night\Start-Server.cmd`. Do not use the manager's Start button on the Wildcard realm.
The manager switches both bot systems off on Wildcard whenever its own Start is used (README, "SQUID's bots on
Wildcard"; commit `465c928`). `Start-Server.cmd` applies the settings, which turn SQUID's bots back on, then starts
through the same launcher the manager uses and runs the same `StartAndCheck`.

- It refuses if a world server is already running: `The server is already running. Stop it in the manager first to restart it with bots.`
- It also downloads `main` first, so merged settings and SQL go live with this start.
- Success reads `Server started on core <rev> with your settings.`

### Stop the server

Classify with `wildcard-change-control` first. Patch night itself is hard stop 5: **James decides.** Read-only checks
are always fine.

Use the manager's Stop All. That is what the repository's own instructions say ("Stop the server in the manager",
README and `vm/Install-WildcardServer.ps1`). There is no stop script in the repository. Two things to know:

- Nothing warns players unless you announce it yourself.
- A stopped server does not stay stopped. If the world is not running when a task fires, the script skips the
  countdown and starts it. To keep it down across the nightly and weekly task times, James has to disable the tasks.

## Talking to the server console (RA)

`PatchNight.ps1` never opens a network connection to the console itself. It runs the manager's own launcher:

```
Runtime\python\python.exe -B patch-night\launcher_bridge.py Scripts\manage.py <verb>
```

with the working folder `C:\Games\CoA Server` and any input on standard input (`Launcher`, `PatchNight.ps1:117`).
`launcher_bridge.py` is copied from CF-Server-Manager (AGPL-3.0) with one Wildcard addition: after the launcher
prepares the configs, it points `worldserver.conf` back at `acore_world_wildcard` and `acore_characters_wildcard`
when Wildcard is the active realm (commit `d5412a9`, after the 19 Nov start on the wrong realm's characters).

| Verb the scripts use | Used by | Effect |
|---|---|---|
| `ra-once` | `Ra` | Sends the one console command read from standard input and prints the reply. |
| `start-mysql` | `StartAndCheck` | Starts the database only. |
| `start-all` | `StartAndCheck`, rebuild | Starts database, auth and world. The bridge allows the world 25 minutes to load. |
| `stop-all` | `StopServer` | Stops everything. If the console is unreachable, the bridge ends the world process only after checking it is this server's own. |

Console commands the script sends:

| Command | Where | Read-only |
|---|---|---|
| `server info` | Before the countdown, to read `Connected players: N` | Yes |
| `announce Nightly restart: ...` | Countdown and call-off | No, players see it |
| `server shutdown 1s 0` | `StopWorld` | No |
| `character erase <guid>` | Rebuild bots only | No, deletes a character |

Safe read-only check by hand (written from the `Ra` function, not executed on the VM on 2026-11-22):

```powershell
Set-Location 'C:\Games\CoA Server'
'server info' | & '.\Runtime\python\python.exe' -B '.\patch-night\launcher_bridge.py' '.\Scripts\manage.py' ra-once
```

`server info` is the only console command this repository proves safe. Other console and GM commands are hard stop 1
territory. See `azerothcore-coa-reference` for the command set.

Read-only SQL uses the same client the script uses (`Sql`, `PatchNight.ps1:344`). Only run `SELECT`:

```powershell
'SELECT id, name, address FROM acore_auth.realmlist;' |
  & 'C:\Games\CoA Server\mysql\bin\mysql.exe' '--defaults-file=C:\Games\CoA Server\mysql\admin-client.ini' --batch
```

## Healthy or wrong

From `docs/agents/context/patch-night.md` (INTENDED DOCTRINE: PR #232, unmerged), with additions from the script marked "added".

**Healthy**

- Ends with `[OK] Patch night OK: ...` and `server up on core <revision>`.
- A `Downtime: N s` line of about 2 minutes since the staged change of 22 Nov. Over 5 minutes is worth a mention.
- Settings: no `Bad value`, and "0 unknown" by the context pack's rule. That rule is INTENDED DOCTRINE and may be
  unreachable: `wildcard-settings-and-flags` predicts from the code that about 28 working settings are always
  listed as unknown, and the refinement `5978ee4` is not on `main` (UNVERIFIED on the VM). **Proposed practice (not
  yet adopted by James):** compare the unknown list with the previous run's and flag only NEW names. Settings on
  defaults are normal. Only a change in their number matters.
- Normal lines that look alarming: `Nightly restart: the new build is left for the weekly patch night.` is INFO.
  `No patched build found for this core, but the installed patched server matches it already.` is a WARN and fine.
- Added: `Databases: world acore_world_wildcard, characters acore_characters_wildcard.` on the Wildcard realm.

**Wrong**

- `[FAIL]`, `Patch night FAILED`, `official server is running instead`, `did not come up`, `installer refused`.
- No run at the scheduled time. No log lines at 3:30 am means the task did not run.
- The newest release on GitHub differs from the installed build tag for more than a week. A weekly run was missed.
- A crash file newer than the last report, or a new kind of line in `Errors.log` since the last start.
- New unknown settings (see the note under Healthy), or any `Bad value`.
- Added: any `Enchant fix ... failed`, `Applying the settings reported a problem.`, or
  `... not starting the server. Start it from the manager.` Those can sit under an OK outcome or explain a FAILED one.

### The patch-night-checker report

`.claude/agents/patch-night-checker.md` (Haiku, read-only) replies in this shape, at most 12 lines:

```
**Patch night <date and time>: OK | PROBLEM | DID NOT RUN**
- Build: <installed tag>, core <revision>. <New build installed, or unchanged.>
- Downtime: <N s> (last run <M s>).
- Settings: <changed / unknown / bad values / on defaults, with the change since last run>.
- New since last run: <warnings, errors or crashes that were not there before, or "nothing">.
- Needs James: <one line, or "nothing">.
```

It compares with the previous run in the same log. It does not diagnose. When something needs judgement it says what
it saw and that a case file (`docs/agents/case-file-template.md`) is the next step.

## Known operational risks and gaps (as of 2026-11-22)

| Risk or gap | Detail |
|---|---|
| Tasks need a signed-in session | Interactive logon. After a reboot or sign-out, nothing runs and the log has no lines. |
| Nothing in the repository starts the game server at boot | Only `Wildcard Sign-up` has an at-sign-in trigger. Whether the manager auto-starts is UNVERIFIED. |
| Single VM | No second server, no staging copy. Every restart and every install happens on the live realm. |
| The only post-restart check is `StartAndCheck` | Log line, revision, process alive after 60 s. Nothing else. See above. |
| "Checked at 4:37 am, rolled back if the check fails" | This phrase is in `docs/agents/context/change-risk.md:54` only. No script, task or workflow in any branch does a 4:37 check or an automatic rollback of a merged change. NOT BUILT YET. The only automatic rollback is the fall-back to the official server. |
| "Build and smoke test" on the LOW path | The build's only runtime check is `worldserver.exe --version`. No smoke test exists. NOT BUILT YET. |
| A failed SQL file does not fail the run | Logged as WARN. The outcome can still read OK. |
| No kept copy of the previous patched build | Only the official server is kept on disk. Older builds are on GitHub Releases. |
| No lock between a by-hand run and a task | Two copies could overlap. |
| A stopped server is started by the next task | No "stay down" switch. |
| OK is said by every mode | `last-run.txt` holds the last outcome of any mode, including `Start-Server.cmd`. The nightly and the weekly run write the same `Patch night OK` wording. Tell them apart by the time. |
| VM snapshots | James has said Proxmox snapshots and Ansible exist and that no snapshot rollback has been needed. No procedure is in this repository. |

**Proposed practice (not yet adopted by James; register: `wildcard-change-control/references/proposed-practices.md`):** after every run, search the run's log for `failed` and `[WARN]`
as well as reading the outcome line. Purpose: an OK outcome does not cover SQL or settings problems. Motivating
case: `ApplyEnchantFixes` logs a failed file and carries on (`PatchNight.ps1:364`).

**Proposed practice (not yet adopted by James):** do not start `Run-PatchNight-Now.cmd` within an hour before a
scheduled task time. Purpose: the script has no lock. No incident on record. This comes from reading the code.

## References in this skill

- `references/patch-night-timeline.md`. Read this when you need the exact function, log line and failure behaviour
  of a phase, or the full list of outcome lines.
- `references/runbooks.md`. Read this before any install, rollback, restore, bot rebuild, or recovery after a manager
  update or a reboot.
- `references/vm-file-map.md`. Read this when you need to know where a file lives on the VM and which script writes it.

## Provenance and maintenance

Written 2026-11-22 from the checkout `fcfee51` (PR #232's head on `62a26e4`, #230) and `origin/main` at `d3e030f`
(#231). `PatchNight.ps1` was last changed by `759c7b6`, `f5d6cf5` and `ba59783`
on 2026-11-22. Line numbers refer to that version. Re-verify anything that may have drifted:

```bash
# Has the operating code changed since this was written?
git log d3e030f..origin/main --oneline -- patch-night vm server-settings/Apply-ServerSettings.ps1 docs/agents/context/patch-night.md .claude/agents/patch-night-checker.md
# Are the agent docs on main yet? (empty = still PR #232 only)
git ls-tree --name-only origin/main docs/agents/
# The self-restart and the release choice (go-live table)
sed -n 742,754p patch-night/PatchNight.ps1; sed -n 857,866p patch-night/PatchNight.ps1
# Task names, days, times, switches as registered by the script
grep -n "Register-Run\|\$Day\|\$Time\|\$NightlyTime\|WarnMinutes\|LogonType\|ScheduledTaskSettingsSet" patch-night/Register-PatchNight.ps1
# Every log line and outcome the script can write
grep -n "Log '\|Log \"\|Finish '\|Finish \"" patch-night/PatchNight.ps1
# What StartAndCheck checks
sed -n '/^function StartAndCheck/,/^}/p' patch-night/PatchNight.ps1
# What a run downloads from main
sed -n '/^function FetchRepo/,/^}/p' patch-night/PatchNight.ps1
# Build-once rule and the rebuild input
grep -n "rebuild\|already built" .github/workflows/build-worldserver.yml
# Is a 4:37 check or a smoke test built yet?
git grep -n "4:37\|smoke" -- . ':!.claude/skills'
# Launcher verbs and the realm guard in the bridge
grep -n "stop-all\|REALM_DATABASES\|def prepare" patch-night/launcher_bridge.py
```

On the VM, the scheduled-task query near the top of this file is the check for what is really registered.
