# Recovery and rollback runbooks

Read from the repository on 2026-11-22 (checkout `fcfee51`, PR #232's head; `patch-night/` and `vm/` are identical
on `origin/main` `d3e030f`). Hard-stop numbers are from `docs/agents/context/change-risk.md`, which is DOCTRINE (PR #232, merged 22 Nov 2026). None of these procedures was executed on the VM that
day. Each one was written from what the scripts do. Where a consequence follows from the code and has not been
seen in a real run, the text says "from the code".

**Every runbook in this file changes the live server. Classify with `wildcard-change-control` first. Patch night
itself, the installer and rollback are hard stop 5, so James decides. Read-only checks are always fine.**

James's stated tolerances: about 30 minutes of downtime and about 15 minutes of data loss are acceptable.

## Which rollback do I need?

| What went wrong | Use |
|---|---|
| A setting change made things worse | Roll back a settings change |
| An SQL fix made things worse | Roll back an SQL fix |
| The newest patched build is bad, the one before was fine | Roll back to the previous patched build |
| Any patched build is bad, or you need to rule our patches out | Restore the official server |
| Data is damaged, or nothing else works | Full VM snapshot rollback |
| A script change in `patch-night/` is bad | Revert the PR on `main`. The next run downloads the fixed scripts, as long as the bad one still gets as far as `FetchRepo`. Remember there is no night of grace: the bad script already ran. If it cannot reach `FetchRepo`: **[James only; hard stop 5.]** copying a good `PatchNight.ps1` into place by hand is a hand edit, which CHANGES.md rules out as a way of working; it is listed only as an emergency stopgap, after the revert PR on `main` is open, and recorded in that PR. |

Prefer the smallest one. A settings or SQL rollback costs one restart. A build rollback costs one restart. A snapshot
rollback loses everything since the snapshot.

## Install a specific build by hand

1. Find the release at `https://github.com/JaTynan/coa-wildcard-mystic/releases`. Tags read
   `wcme-server-<manager release>-build<N>`. The release notes carry `BUILD-INFO.txt`, including the `Core:` commit.
2. Check its core matches what the manager has installed. Line 1 of `Core\Logs\Server.log` shows the running
   revision. A build for another core is refused.
3. Tell players, then stop the server with the manager's Stop All. The installer refuses while a world server runs:
   "The world server is running. Stop the server in the manager first, then run this again."
4. Download the zip on the VM, extract all of it, double-click `Install.cmd`.
5. Read the window. Success ends with `All done. Start the server in the manager.`
6. Start with `C:\Games\CoA Server\patch-night\Start-Server.cmd`. The installer's message says to use the manager,
   but on the Wildcard realm the manager's Start switches the bots off (README, "SQUID's bots on Wildcard").
7. Check `patch-night.log` for `Server started on core REV with your settings.`

What `Install.cmd` does is listed in `patch-night-timeline.md`, phase 9. `Install.cmd -Force` skips the core match
check. Do not use `-Force` unless patch night's own log explained why the saved official copy is stale.

**The build record is not updated by a hand install.** `Core\worldserver.patched-release.txt` is written only by
`PatchNight.ps1`. From the code, the consequences are:

| Record says | Then the next weekly patch night or by-hand run |
|---|---|
| Nothing, or the file is missing | Installs the newest matching release |
| The newest matching tag, while you installed an older build by hand | Logs `It is already installed.` and leaves your build alone |
| An older tag than the newest | Installs the newest |

The status page and the checker read that record, so after a hand install they can name the wrong build.

## Roll back to the previous patched build

**There is no kept copy of the previous patched build on the VM.** The installer keeps only the official program
(`worldserver.official.exe`). `patch-night\work\package` and the zip in `patch-night\work` hold the newest download
only. Earlier builds are on GitHub Releases, as long as nobody deleted them. On 2026-11-22 the tags for the current
manager release were builds 57, 61, 62, 68 and 70 of `wcme-server-0.261119.114`.

1. Pick the last build known to be good. `patch-night.log` shows which tag each past run installed
   (`Installing TAG...`).
2. Follow "Install a specific build by hand" with that release.
3. Decide what stops patch night from reinstalling the bad build. From the code there are three cases:
   - The record still names the bad build and it is the newest release: patch night says `It is already installed.`
     and your rollback holds, until a newer build is published.
   - A newer build gets published: the weekly patch night installs it (whatever branch built it). That is what you want if it has the fix.
   - You want certainty: James can delete the bad release on GitHub or mark it as a draft. Patch night skips drafts
     and takes the next matching release. This is a rollback decision, hard stop 5.
4. Fix forward. Revert or repair the patch on `main` (James merges), then the build is run with **rebuild** ticked:
   by James, or a session he has told to, because the release it publishes is what patch night installs (hard
   stop 5). A build takes 2 to 3 hours. See `wildcard-build-and-env`.

If the bad change has a setting that turns it off, changing that setting is quicker than any of this and needs no
build (`CHANGES.md`: "Turn a change off with its setting where it has one").

## Restore the official server

Use this to take all our C++ patches out of the picture. Mystic Enchants on Wildcard stop working while it is in
place.

1. Tell players, then stop the server with the manager's Stop All.
2. Run `Restore-Official.cmd`. It is not in `patch-night\`. Copies are in the release zip and at
   `C:\Games\CoA Server\patch-night\work\repo\<the one folder inside>\vm\Restore-Official.cmd`.
3. Success reads `The official world server is back. Start the server in the manager.` If it says
   `No official copy saved; the world server was never swapped.`, the live program already is the official one.
4. Start with `Start-Server.cmd`.

What it does: copies `Core\worldserver.official.exe` over `Core\worldserver.exe` and deletes
`Core\worldserver.patched.txt`. Nothing else. Settings and SQL fixes still apply at every start. The official
server ignores settings and tables it does not know.

**It does not last by itself.** From the code: with the marker gone, patch night sees the live program as the
manager's, finds the matching release and installs it again at the next weekly patch night or by-hand run. The
nightly restart leaves it alone. To stay on the official server past the weekly patch night, James has to disable the
`CoA Patch Night` task or remove the release.

Patch night does the same swap itself when a patched server fails its check. See `patch-night-timeline.md`,
phase 12.

## Roll back a settings change

Settings are written into the config files by `server-settings\Apply-ServerSettings.ps1` from
`server-settings.txt`, which every run replaces with the copy on `main`.

**The lasting way.** Revert the change on `main` (a PR, James merges). It applies at the next run. Two traps:

- **Deleting a line does not undo it.** The script only sets what the list names. A setting that was written once
  stays in the config file at its last value after its line is removed. To go back, put the old value in the list.
- The old value is in the backup. Every run that changed something first copies each file it is about to change to
  `Core\configs\settings-backup\<yyyy-MM-dd_HHmmss>\`, keeping the same sub-path (`Core\configs\...` and
  `Settings\...template`). The newest 20 such runs are kept.

Find what a run changed (read-only):

```powershell
$b = 'C:\Games\CoA Server\Core\configs\settings-backup'
Get-ChildItem $b -Directory | Sort-Object Name -Descending | Select-Object -First 5
Select-String -Path 'C:\Games\CoA Server\patch-night\patch-night.log' -Pattern '^\S+ \S+ \[INFO\]\s+set:' | Select-Object -Last 20
```

**The quick way, for an emergency. [James only; hard stop 5.]** This is a hand edit, which CHANGES.md rules out as a
way of working ("Nothing is edited on the running server by hand"). It is listed only as an emergency stopgap: open
the revert PR on `main` first and record the hand edit in that PR. Copy the backed-up files over the live ones with the server stopped, then start.
This holds only until the next run, which applies `main` again. So the revert on `main` still has to follow. Note
that `worldserver.conf` has two copies, the live one and `Settings\worldserver.conf.template`. Restore both, or the
manager rebuilds the live one from the template.

A hand edit of a config file on the VM has the same weakness. It lasts until the next run sets that key again, and
only if the key is in the list.

## Roll back an SQL fix

1. Delete the file from `sql/enchants/` on `main`, or revert the PR that added or changed it. James merges.
2. At the next run `FetchRepo` empties `patch-night\enchants` and refills it from `main`, so the file is gone from the
   VM too.
3. `000-reset.sql` runs first at every start. It removes every row this repository owns, then the remaining files
   put back exactly what the repository holds (README, "Mystic Enchant fixes (SQL)").
4. For an immediate effect, run `Start-Server.cmd` after a stop, or `Run-PatchNight-Now.cmd`.

Limits:

- The reset only removes the kinds of row it knows about: rows marked `WCME:`, rows listed in `wcme_owned`, and the
  `wcme_*` tables. Before relying on it, check that `000-reset.sql` covers the kind of row the file added. The
  conventions belong to `ascension-restoration`.
- The world server caches spell data at start, so the rollback is visible only after a restart.
- A file that changed something outside the world database, or a server variable, is not undone by the reset.
  `095-slow-query-log.sql` is an example. It uses `SET PERSIST`, and its own comment gives the command to stop it.
- A failed file is only a WARN in the log (`Enchant fix FILE failed: ...`). Check for that after the restart.

## Full VM snapshot rollback on Proxmox

**Outside the repository.** James has said that Proxmox snapshots of the VM and Ansible exist, and that no snapshot
rollback has ever been needed. This repository holds no procedure, no snapshot schedule and no retention rule for
them. Nothing here was verified.

What can be said from the repository:

- A snapshot rollback returns the characters and auth databases to the snapshot's time. Everything players did since
  is lost. Compare the snapshot's age with the 15-minute tolerance and let James choose. Hard stops 5 and 7.
- After a rollback the VM boots with nobody signed in, so "After a Windows Update reboot" below applies.
- The first run afterwards downloads `main` again, so scripts, settings, SQL and addons return to the current
  repository state. A bad build would be reinstalled by the next weekly patch night unless the release was dealt with.

Before a risky by-hand operation, the manager's own backup is the tool the repository names
(`Rebuild-WildcardBots.cmd`: "Make a backup in the manager first"; README: "keep a backup").

**Proposed practice (not yet adopted by James; P8 in `wildcard-change-control/references/proposed-practices.md`):**
take a Proxmox snapshot before the restart that brings a HIGH change live (a build that contains a new patch is
the usual case), and write the snapshot name in the PR. Purpose: a known restore point whose age is known. No incident on
record. It is offered because the repository has no data restore procedure at all.

## After a manager Update click

The manager's Update button stays manual (README). Clicking it moves the server to a new CoA release. From the
script there are two ways it can leave the world server:

| Case | What patch night logs | What happens |
|---|---|---|
| The manager replaced our program with its new official one | `The manager's installed core is NEW (from worldserver.exe).` | If a build for NEW exists, patch night installs it. If not: `No patched build for core NEW yet; the official server keeps running (no Mystic Enchants on Wildcard).` |
| The manager kept our program because it saw it was changed | `The manager installed core NEW (auth server), but kept our patched world server from core OLD, ...` | Patch night goes by the auth server, and passes `-Force` to the installer when a build for NEW exists (commits `f83171d`, `0736bae`). |

Steps:

1. Before clicking Update, check whether our patches still fit the new release. That is the costly part and belongs to
   `wildcard-build-and-env` and `wildcard-patch-authoring`. README: if a patch no longer fits, the build stops at
   "Apply our patches" and nothing is published.
2. After the update, a build for the new release is needed. The daily workflow builds each new manager release once
   by itself. It takes 2 to 3 hours once it starts.
3. When the release exists, the weekly patch night installs it; the nightly restart will not. README (DOCTRINE)
   says of the Update button: "click it any time before patch night and the new release is picked up". Read from
   the code, not observed: a nightly run between the Update click and the install can end FAILED (the dangerous
   case below). **Proposed practice (not yet adopted by James):** after the manager's Update, James runs
   `Run-PatchNight-Now.cmd` the same day once the build exists (it restarts the server and installs a build:
   classify with `wildcard-change-control`; hard stop 5). Purpose: avoid a nightly run that ends FAILED. Incident:
   none recorded. The README sentence and this proposal are not reconciled; James decides.
4. Until then, start with `Start-Server.cmd` as usual.

From the code, the second case with no build for NEW yet is the dangerous one. The live program is ours but built for
OLD, while the manager has moved the databases on. Patch night logs
`No patched build found for this core, but the installed patched server matches it already.`, starts the old
program, and the build check then fails with `The server came up on core OLD, expected NEW.` The fall-back copies a
stale official program that is also OLD. Expect a FAILED outcome and act by hand: get the manager to restore its
own world server, or wait for the build. This path has not been observed. Treat it as a warning and not as a
description of a past event.

The 19 Nov update to `server-0.261119.114` also changed how the manager's launcher writes database names, which
started Wildcard on the wrong realm's characters until the bridge was fixed (commit `d5412a9`). After any manager
update, read the `Databases: world ..., characters ...` line of the first start.

## After a Windows Update reboot

The scheduled tasks run only in James's signed-in session, and nothing in this repository starts the game server at
boot. Whether Windows signs in automatically and whether the manager auto-starts are UNVERIFIED. Check on the VM.

1. Sign in on the VM as James and stay signed in. Disconnecting a remote session is fine. Signing out is not.
2. Check what is running (read-only):

```powershell
Get-Process worldserver, authserver, mysqld -ErrorAction SilentlyContinue | Select-Object Name, StartTime
Get-ScheduledTask -TaskName 'CoA Patch Night','CoA Nightly Restart','Wildcard Sign-up' | Select-Object TaskName, State
Get-Content 'C:\Games\CoA Server\patch-night\last-run.txt'
```

3. If no world server is running, start it with `Start-Server.cmd`. It starts the database first.
4. Both tasks are registered with "start when available". Task Scheduler may therefore start a missed run soon after
   sign-in. That is standard Windows behaviour and UNVERIFIED on this VM. If a run starts by itself, let it finish.
   Do not start a second one.
5. The sign-up and status service starts at sign-in through the `Wildcard Sign-up` task.
6. Afterwards check `patch-night.log` as in the main skill. No lines at 3:30 am on a given night means that run was
   missed.

James has said Windows Update runs on Wednesday at 3 am. That is 30 minutes before the nightly task. Whether the
reboot has ever cut a run short is UNVERIFIED. Compare Wednesday entries in `patch-night.log` with other days.

## Rebuild the Wildcard bots

`patch-night\Rebuild-WildcardBots.cmd` runs `PatchNight.ps1 -RebuildWildcardBots`. It was written as a one-off on
30 Oct, when SQUID had created about 2,100 bots in CoA classes on the Wildcard realm (commits `42290ca`, `0a04f12`).

**This deletes characters. It is hard stop 7, and James decides and runs it.** Its own comment says to make a backup
in the manager first.

What it does, in order (`PatchNight.ps1:756-814`):

1. Downloads `main` like every run. Logs `---- rebuild Wildcard bots (Rebuild-WildcardBots.cmd) ----`.
2. Stops if the active realm is not Wildcard: `The manager has the REALM realm active, not Wildcard; nothing was changed.`
3. Reads the bot account prefix from `AiPlayerbot.RandomBotAccountPrefix` in `playerbots.conf`. Default `rndbot`.
4. Stops the whole server through the launcher. **No in-game warning and no countdown.**
5. Sets `AiPlayerbot.Enabled` to 0 in `playerbots.conf`, so no bot is online while it is removed.
6. Starts the server: `Starting the server with the bots switched off...` Waits up to 20 minutes for
   `World Initialized In`, then carries on whether or not it appeared.
7. Lists every character in `acore_characters_wildcard` whose account name starts with the prefix and whose class
   is not 10 (Hero).
8. Sends `character erase <guid>` over the console for each one.
   `Removing N non-Hero bot characters from the Wildcard realm (this takes a while)...` then a progress line every
   50.
9. Counts what is left: `Removed N; non-Hero bot characters left: M.`
10. Stops the server again, applies the settings (which switch the bots back on) and starts with `StartAndCheck`.
    SQUID then creates Hero bots on the emptied accounts.

Dangers:

- Any real player's account whose name begins with the bot prefix would lose its non-Hero characters on Wildcard.
  Check first, read-only (uses the same client as the script):

```powershell
"SELECT a.username, COUNT(*) FROM acore_characters_wildcard.characters c JOIN acore_auth.account a ON a.id = c.account WHERE a.username LIKE 'RNDBOT%' AND c.class <> 10 GROUP BY a.username LIMIT 20;" |
  & 'C:\Games\CoA Server\mysql\bin\mysql.exe' '--defaults-file=C:\Games\CoA Server\mysql\admin-client.ini' --batch
```

  Replace `RNDBOT` with the prefix in upper case if `playerbots.conf` sets another one.
- Two full restarts with no announcement. Players online are dropped.
- If it ends early, for example `Cannot list the bots: ...`, the server is left running with the bots switched off.
  `Start-Server.cmd` after a stop puts the settings back.
- It only reports success when no non-Hero bot is left (commit `5d35b3b`). Otherwise:
  `Wildcard bots NOT rebuilt: M non-Hero bot characters are still there. ...`

There is no undo in the repository. Erased characters come back only from a backup or a snapshot.
