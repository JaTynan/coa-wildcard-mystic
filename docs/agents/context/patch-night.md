# Context pack: patch night

Read this instead of exploring. Paths are on the server VM unless they start with a repository folder.

## What patch night is
`patch-night/PatchNight.ps1` keeps the server on our patched world server and James's settings.
- **Patch night, every night:** scheduled task "CoA Patch Night", countdown from 3:30 am, restart at 4:00 am Sydney
  time. Applies settings, database fixes, addons and the site, and installs a new patched build when there is one
  for the installed core (daily since 23 Nov 2026; before that builds were installed on Tuesdays only, and a second
  task, "CoA Nightly Restart", did the rest). If "CoA Nightly Restart" still exists, the tasks were not re-registered.
- **By hand:** `Run-PatchNight-Now.cmd`. The same run.
The task runs as James, only while he is signed in on the VM. No log lines at 3:30 am means the task did not run.

## Files to read (all under `C:\Games\CoA Server`)
| File | What it tells you |
|---|---|
| `patch-night\last-run.txt` | One line: the date and the outcome of the last run. |
| `patch-night\patch-night.log` | Everything. Runs are bracketed by "---- patch night started ----" and "---- patch night finished ----". |
| `server-settings\settings-report.txt` | Settings check: unknown settings, options left on defaults, the server's own config warnings. |
| `Core\Logs\Server.log` | This start only. Line 1 has the core revision; "World Initialized In" means the world is up. |
| `Core\Logs\Errors.log` | Errors since the realm began; look at lines after the last start. |
| `Core\Crashes\` | One `.txt` and `.dmp` per crash, named with the core revision and the date. |
| `Core\worldserver.patched-release.txt` | The installed build tag, e.g. `wcme-server-0.261119.114-build70`. |

## What a healthy run looks like
- Ends with `[OK] Patch night OK: ...` and "server up on core <revision>".
- A "Downtime: N s" line of about 2 minutes (after the staged patch night change). Over 5 minutes is worth a mention.
- Settings: "0 unknown" and no "Bad value". Settings on defaults are normal; only a change in their number matters.
- Lines that are normal: "No patched build found for this core, but the installed patched server matches it" is
  fine. "Nightly restart: the new build is left for the weekly patch night" should no longer appear: it means the old
  nightly task is still registered.

## What is wrong
- `[FAIL]`, "Patch night FAILED", "official server is running instead", "did not come up", "installer refused".
- No run at the scheduled time.
- The newest release on GitHub for the installed core differs from the installed build tag after a night's run.
- A crash file newer than the last report, or a new kind of line in Errors.log since the last start.
- Unknown settings, or any "Bad value".

## Rules
- Read only. Never start, stop or change anything on the server, never run patch night, never merge or cancel.
- Plain English, short. James reads the result on his phone.
