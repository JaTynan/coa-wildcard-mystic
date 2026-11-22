# Patch night, phase by phase

Read from `patch-night/PatchNight.ps1` on 2026-11-22 (checkout `fcfee51`, PR #232's head; the script is identical on `origin/main` `d3e030f`; 989 lines). Line numbers refer to that
version. Log lines in code font are copied from the script so you can search for them. Capitalised words such as REV, TAG, PATH and N
stand for values the script fills in. Log contents were not re-verified on the VM on
2026-11-22.

Every line in `patch-night.log` has the form `yyyy-MM-dd HH:mm:ss [LEVEL] message`. LEVEL is INFO, OK, WARN or FAIL
(`Log`, line 61). The window of a by-hand run shows the same lines in colour.

Search a run on the VM (written here, not executed on the VM on 2026-11-22):

```powershell
Select-String -Path 'C:\Games\CoA Server\patch-night\patch-night.log' -Pattern 'Downtime:' | Select-Object -Last 5
```

## Order of events

| # | Phase | Function or lines | Server state |
|---|---|---|---|
| 0 | Download `main`, update itself | `FetchRepo`, lines 742-754 | Up |
| 1 | Start bracket and sanity checks | lines 832-835 | Up |
| 2 | Which core is installed | `OfficialExe`, `Revision`, lines 837-854 | Up |
| 3 | Which build matches | lines 856-880 | Up |
| 4 | Count players, first warning | lines 891-914 | Up |
| 5 | Prepare: download build, write settings | lines 916-932 | Up |
| 6 | Rest of the countdown | lines 934-944 | Up |
| 7 | Stop the world server | `StopWorld` | Down from here |
| 8 | Rotate console logs | `RotateConsoleLogs` | Down |
| 9 | Install the build, settings again | lines 951-971 | Down |
| 10 | Start and check | `StartAndCheck` | Down until the world is up |
| 11 | Downtime line and outcome | lines 973-977 | Up |
| 12 | Fall back to the official server | lines 979-988 | Only if 10 failed |

## 0. Download main and update itself

`FetchRepo` (line 220) runs first in every mode, before the start bracket. So its lines sit just above
`---- patch night started ----` in the log. It downloads
`https://github.com/JaTynan/coa-wildcard-mystic/archive/refs/heads/main.zip` into `patch-night\work` and copies:

| From `main` | To on the VM | Log line |
|---|---|---|
| `server-settings/*` | `C:\Games\CoA Server\server-settings` | `Downloaded the current server-settings from GitHub.` |
| each folder in `addon/` | `F:\CoAClient\Interface\AddOns` | `Updated the NAME addon in PATH.` |
| addons listed in `addon/third-party-addons.txt` | same folder, from each addon's own repository at its pinned commit | `Installed the third-party addon(s) NAMES from SOURCE at COMMIT in PATH.` |
| `sql/enchants/*.sql` | `patch-night\enchants` (emptied first) | `Downloaded N Mystic Enchant fix file(s).` |
| `launcher/` | `patch-night\launcher` | none |
| `ollama-chat/` | `patch-night\ollama-chat` | none |
| `signup/` | `patch-night\signup`, with the `Wildcard Sign-up` task stopped and started around the copy | none |
| `patch-night/*` | `patch-night` | `Updated the patch-night scripts from GitHub (used from the next run).` |

It returns the path of `vm\Install-WildcardServer.ps1` inside the download, which the install step uses later.

**Self-update.** The script hashes itself before and after `FetchRepo`. If the file changed it logs
`Running the newer patch-night script just downloaded...` and starts the new copy with the same switches plus
`-Updated`, which skips the download the second time (lines 743-753, commit `0a04f12`). So the "used from the next run"
wording of the log line above is stale: a new `PatchNight.ps1` is used in the same run, and the other files in the
folder (`launcher_bridge.py`, the `.cmd` files) are already replaced on disk, so anything this run calls later is
the new copy too. **There is no night of grace for a merged `patch-night/` change** (go-live table: SKILL.md).

**"Used only if they read cleanly."** `ParsesCleanly` (line 165) runs PowerShell's parser over a file and reports
whether it found syntax errors. It does not run the file and cannot catch a script that parses but misbehaves.

- A settings `.ps1` that fails is skipped: `NAME from GitHub does not read cleanly; keeping the current copy.` WARN.
- If any patch-night `.ps1` fails, none of the patch-night files are copied:
  `The patch-night script(s) NAMES from GitHub do not read cleanly; keeping the current copies.` WARN.

**Failure.** Anything that throws inside `FetchRepo` logs
`Cannot download from GitHub (REASON); using the local copies.` WARN. The run continues with what is already on the
VM. Copies made before the error stay made. A bad third-party addon line logs
`Skipped a third-party addon line: LINE`, and a failed addon download logs
`Could not install the third-party addon(s) from SOURCE: REASON`. Both are WARN and neither stops the run.

## 1. Start bracket and sanity checks

Logs `---- patch night started ----`. Then checks that `Core\worldserver.exe`, `Runtime\python\python.exe`,
`Scripts\manage.py` and `patch-night\launcher_bridge.py` exist. If one is missing the run ends with
`Missing PATH; nothing was changed.`

`Start-Server.cmd` runs log `---- start server (Start-Server.cmd) ----` instead, and bot rebuilds log
`---- rebuild Wildcard bots (Rebuild-WildcardBots.cmd) ----`. Every mode ends with `---- patch night finished ----`.

## 2. Which core is installed

`OfficialExe` (line 92) decides which program is the manager's. If `Core\worldserver.patched.txt` holds the hash of
the live `worldserver.exe`, the live one is ours and the manager's is `worldserver.official.exe`. Otherwise the live
one is the manager's.

`Revision` (line 83) runs `<exe> --version` and takes the hex after `rev.`.

| Log line | Meaning |
|---|---|
| `The manager's installed core is REV (from FILE).` | Normal. |
| `The auth server reports core REV.` | Normal. Should match the line above. |
| `The auth server did not report its core; trusting the world server.` WARN | Carries on. |
| `The manager installed core A (auth server), but kept our patched world server from core B, so the saved official copy is out of date. Going by the auth server.` WARN | The manager updated and left our program in place. The script uses the auth server's core from here and later passes `-Force` to the installer (commits `f83171d`, `0736bae`). |
| `Cannot read the revision of PATH; nothing was changed.` | Run ends, exit 1. |

## 3. Which build matches

Asks `https://api.github.com/repos/JaTynan/coa-wildcard-mystic/releases?per_page=50` and takes the first release that
is not a draft and whose notes contain `Core:` followed by a 40-character commit that starts with the installed
core revision (lines 859-864). GitHub lists newest first, so a rebuild of the same manager release wins over the
earlier build. The installed tag is read from `Core\worldserver.patched-release.txt`, and only trusted when the live
program is ours.

| Log line | Meaning |
|---|---|
| `Patched build available: TAG.` | A matching release exists. |
| `It is already installed.` | Tag equals the record. No install. |
| `Nightly restart: the new build is left for the weekly patch night.` | `-NoInstall` run and the tag differs. No install. INFO. |
| `No patched build found for this core, but the installed patched server matches it already.` WARN | No matching release was found, or GitHub could not be reached, and the live program is ours. Fine. |
| `No patched build for core REV yet; the official server keeps running (no Mystic Enchants on Wildcard).` WARN | The manager is on a release we have not built. Needs a build. See `wildcard-build-and-env`. |
| `Cannot reach GitHub releases: REASON` WARN | Carries on without a release. |

It also ends the run here with `No settings kit at PATH; nothing was changed.` if
`server-settings\Apply-ServerSettings.ps1` is missing.

## 4. Count players and give the first warning

Only if a `worldserver` process exists. Sends `server info` over RA and reads `Connected players: N`.

| Situation | Log line | Countdown |
|---|---|---|
| Scheduled run (`-Unattended`) | `Players online: N. Counting down 30 minutes while preparing.` | Always the full time, so the restart lands at the same time each night |
| By hand, players on | `Players online: N. Counting down 10 minutes while preparing.` | 10, 5, 1 |
| By hand, nobody on | `No players online.` | None |
| Console silent and the game port closed | `The world is not accepting players (still starting or stuck), so there is nobody to warn.` then `No players online.` | None (commit `e244a47`) |
| Console silent but the game port open | `Players online: unknown. ...` | Full |

Warnings come at the full time, then 15, 10, 5 and 1 minutes, dropping any mark larger than the full time. In game
they read "Nightly restart: the server restarts in N minutes for maintenance and is back within 5 minutes." and, at
one minute, "Nightly restart: the server restarts in 1 minute. Find a safe spot! It is back within 5 minutes."
(`Announce`, line 909). The wording says "Nightly restart" on Tuesday too.

If no world server is running, this phase logs nothing, and the run goes on to start the server.

## 5. Prepare while the server is up (staged, since 22 Nov, commit 759c7b6)

If an install is needed:

- `Downloading NAME.zip (N MB)...` then unpacks to `patch-night\work\package`.
- Ends the run with `Release TAG has no zip; nothing was changed.` or
  `The downloaded package has no installer; nothing was changed.` if the release is malformed.

Always:

- `Applying server-settings (used from the restart)...` then runs
  `server-settings\Apply-ServerSettings.ps1 -Server ... -Unattended`. Its output is logged line by line, indented.
  Look for `set:`, `repaired:`, `checked:` and a last line like
  `Changed N setting(s), N already right, N skipped.` The servers read configs only when they start, so writing them
  now changes nothing until the restart.
- `Applying the settings reported a problem.` WARN if that script exits non-zero. The run continues. The usual cause
  is its realm guard: "These settings are for the wildcard realm, but the manager has the X realm active. Nothing was
  changed."
- `Prepared in N s, with the server up.`

**Call-off.** Any error here, such as a failed download, reaches the script's trap (line 81) and ends the run with
`Stopped with an unexpected error: REASON`. Because players were already warned and the world was not yet stopped,
`Finish` first announces in game `Nightly restart cancelled: the server stays up.` (line 71). The server was never
touched.

## 6. Rest of the countdown

Sleeps to each remaining mark and announces it. A mark that preparing ran past is skipped, except the one-minute
warning, which always comes. If needed the restart time moves so that a full minute follows it. No log lines.

## 7. Stop the world server only

`StopWorld` (line 153) sends `server shutdown 1s 0` over RA and waits up to 2 minutes for the process to go.

| Log line | Meaning |
|---|---|
| `World server stopped (MySQL and the auth server keep running).` | Normal. Downtime is counted from just before this call. |
| `Server is already stopped.` | No world server was running. |
| `The world server did not stop from its console; stopping everything with the manager.` WARN | Falls through to `StopServer`, which runs the launcher's `stop-all` and waits up to 5 minutes. Then `Server stopped.` |
| `stop-all failed: ...` or `The world server did not stop within 5 minutes.` | Thrown as errors. The run ends with `Stopped with an unexpected error: ...`. No call-off announcement, because the stop had begun. The server's state is then unknown. Check by hand. |

Before 22 Nov the whole stack stopped and started each night. Keeping MySQL up keeps its cache warm.

## 8. Rotate console logs

`RotateConsoleLogs` (line 191). The manager appends console output to `Core\Logs\world-console.log` and
`auth-console.log` for ever. They had reached about 3 GB by 22 Nov.

- First run ever: saves the history (`SaveConsoleHistory`, see phase 10), deletes each file and logs
  `Cleared NAME.log (N MB), once; from now on each run's console log is dated and the newest 3 kept.` Then writes
  `patch-night\console-logs-cleared.txt`.
- Every later run: renames each file to `NAME-yyyy-MM-dd_HHmmss.log` and deletes all but the newest 3 of each.
- `Left NAME.log as it is for now (in use): REASON` is normal for `auth-console.log`, since the auth server keeps
  running and holds the file.

## 9. Install the build

Only when a new build was prepared. Logs `Installing TAG...` and runs the installer from the fresh download of `main`
(or the one in the zip if that is missing) with `-Server`, `-Package <work\package>`, `-Unattended`, and `-Force` when
phase 2 found a stale official copy. The installer's own lines are logged indented.

What `vm/Install-WildcardServer.ps1` does:

1. Refuses if a world server is running.
2. If the live program is not ours, saves it as `worldserver.official.exe`.
   `Saved the official world server as worldserver.official.exe`
3. Refuses a build whose core does not start with the official program's revision, unless `-Force`:
   "This build is for core X, but the manager installed core Y."
4. Copies the new program in and runs `--version`. If that fails it copies the official one back:
   `The patched world server would not start here, so the official one was put back.`
5. Writes the new hash to `worldserver.patched.txt`. `Installed the patched world server (core REV).`
6. Sets `CoA.MysticEnchants.AllowWildcard = 1` in `Core\configs\modules\coa.conf`.
7. Copies the addon folders in the package to the client. `All done. Start the server in the manager.`

Back in patch night:

- Installer exit 0: writes the tag to `worldserver.patched-release.txt`, expects the release's core, and applies the
  settings a second time so the settings list has the last word over what the installer set.
- Installer non-zero: `The installer refused or failed; continuing with the server as it was.` WARN. The start
  goes ahead with the program that was there.

## 10. Start and check

`StartAndCheck` (line 694). In order:

1. `Starting the server (this waits until the world is up, up to 25 minutes)...`
2. Launcher `start-mysql`, up to 10 minutes. A problem logs `start-mysql reported a problem: ...` WARN and skips
   step 4, but the start continues.
3. `OnActiveRealm` (line 446): `Databases: world W, characters C.` If Wildcard is the active realm and the config
   points anywhere but `acore_world_wildcard` and `acore_characters_wildcard`, it logs FAIL
   `The Wildcard realm is active, but worldserver.conf points at W and C; not starting the server. Start it from the manager.`
   and the check fails without starting the world. This guard exists because on 19 Nov a start brought Wildcard up
   on the other realm's characters (commit `d5412a9`).
4. Database helpers, all with the world down. Each logs WARN and carries on if it fails:

| Function | What it does | Lines to search for |
|---|---|---|
| `EnsureWildcardBotNames` | Copies SQUID's three name lists from `acore_characters` into `acore_characters_wildcard` when they are missing or empty. Without names no Hero bots are created (commit `91aefe7`). | `Copied TABLE to the Wildcard characters database (N rows).` |
| `ApplyEnchantFixes` | Runs every file in `patch-night\enchants` in name order against the world database named in `worldserver.conf`. | `Applied enchant fix FILE to DB.` or `Enchant fix FILE failed: REASON` WARN |
| `PrepareOllamaChat` | Refreshes the AI chat config template. Creates the config switched off if there is none. Runs each `ollama-chat\sql-characters` file once and records it in `wcme_applied_sql`. | `Created mod_ollama_chat.conf with AI chat switched off.` `Applied AI chat table file FILE to DB.` |
| `SkipUnusedAuctionItems` | Works out from `item_template` which items the auction bot must never list (developer leftovers, Bloodforged and Sanguine gear, level 1-60 resilience gear, Burning Crusade and Wrath items), writes them as ranges into `AuctionHouseBot.DisabledCustomItemIDs` in `mod_ahbot.conf`, and deletes the Auctioneer character's unbid listings of them. | `Auction bot skips N items (...) plus the server-settings list; removed listings (rows): N.` |
| `RepriceAuctionsWhenPricesChange` | When the auction price or level-limit lines in `server-settings.txt` differ from `Core\ahbot-prices.txt`, deletes all the Auctioneer's unbid listings so the bot relists at new prices. Once per change. | `Auction prices changed: removed the Auctioneer's unbid listings (rows: N); the bot relists them at the new prices.` |
| `EnsureCharacterSpellIndexes` | Adds an index named `idx_spell` on `character_spell.spell` and `character_talent.spell` if missing. This fixed the 40-second character list (PR #84, commit `257158e`). Later starts see the index and skip. | `Adding an index on TABLE.spell (one time; a minute or so on a big table)...` `Indexed TABLE.spell.` |
| `AllowCrossFactionFriends` | `INSERT IGNORE` of permission 29 for role 199 in the auth database's `rbac_linked_permissions`. | `Could not allow cross-faction friends: ...` only on failure |

   The two auction helpers delete rows from `auctionhouse` and `item_instance` in the characters database, limited to
   the bot character named Auctioneer and to listings with no bid. That is by design and in `main`. Any change to
   that logic touches character data and is hard stop 7.

5. Creates `C:\Games\CoA Server\BugReports` if missing.
6. Launcher `start-all`, up to 60 minutes for the call. Failure: `start-all reported a problem: ...` WARN, check
   fails.
7. `RestoreRealmAddress` (line 611). The launcher resets the realm list to 127.0.0.1 at every start, so this writes
   the public address back into `acore_auth.realmlist` for the realms that run. The address comes from the
   `realmlist | address = ...` line in `server-settings.txt`, else from the manager's `friends.json`. A
   `realmlist | local = ip/prefix` line sets the home-network address and mask.
   `Realm list points friends at ADDRESS again, from SOURCE (realm IDS).`
   Other outcomes: `No realm address in server-settings or Play with friends; the realm stays on this computer only.`
   `Play with friends is off; the realm stays on this computer only.` `Unexpected realm address '...' (...); not applied.`
   `Could not set the realm address: ...` If this step fails, players elsewhere see the realm but cannot join.
   Changing the address is hard stop 3.
8. The wait, checked every 15 seconds for up to 30 minutes. Passes when `Server.log` is newer than this start and
   contains `World Initialized In`, its first line carries a revision that matches the expected one, and the process
   is still there 60 seconds later. `Server is up on core REV.`

| Failure line (all WARN) | Meaning |
|---|---|
| `The world server is not running.` | No process 2 minutes or more after the start. It crashed or never started. |
| `Cannot read the revision in Server.log: LINE` | Line 1 did not have `rev.` |
| `The server came up on core A, expected B.` | Wrong program is live. The world is left running at this point. |
| `The world server stopped within a minute of starting.` | Crashed just after loading. |
| `The world did not finish loading within 30 minutes.` | Still loading or hung. |

9. After a pass:
   - `ReportConfigWarnings` (line 668) reads the server's own `> Config: Missing property` and
     `> Config: Bad value` lines from `Server.log`, appends them to `server-settings\settings-report.txt` and logs
     `Settings: the server runs N setting(s) on defaults (none set in a config file) and could not use N. Full list in server-settings\settings-report.txt.`
     The level is WARN when any value could not be used.
   - `StartDiagnostics` (line 576) stops the previous typeperf, starts a new one and logs
     `Performance counters: every 5 seconds to PATH.` Files older than 14 days are deleted. It also runs
     `SaveConsoleHistory`, which once only writes `Core\Logs\console-history.txt` and logs
     `Console history: start banners and slow updates from N lines saved to PATH.` Measuring only. Interpretation
     belongs to `wildcard-diagnostics-and-tooling`.
   - `PublishFriendsSite` (line 684) runs `patch-night\launcher\Publish-WildcardSite.ps1` if that and
     `F:\wildcard-site` exist, and logs its output. It runs after the world is up so that hashing the 43 GB client
     does not compete with loading. Failure: `Publishing the friends' download site failed: ...` WARN.

## 11. Downtime and outcome

`Downtime: N s from the stop until the world was up (to within 15 s).` Measured from just before `StopWorld` to
the first poll that saw `World Initialized In`. Written only when the first `StartAndCheck` passes.

Then one of:

- `Patch night OK: installed TAG, settings checked, server up on core REV.`
- `Patch night OK: patched server unchanged, settings checked, server up on core REV.`
- `Patch night OK: official server (no patched build yet), settings checked, server up on core REV.`

"Settings checked" is fixed wording. It appears even when the settings step or an SQL file logged a WARN.

## 12. Fall back to the official server

Runs when `StartAndCheck` failed and the live program is ours (lines 979-988):

1. `Putting the official world server back...` WARN
2. `StopServer`, the full stop through the launcher.
3. Copies `worldserver.official.exe` over `worldserver.exe`. Deletes `worldserver.patched.txt` and
   `worldserver.patched-release.txt`.
4. `StartAndCheck` again, expecting the manager's core.

| Outcome line | Meaning |
|---|---|
| `Patch night FAILED on the patched server; the official server is running instead (no Mystic Enchants). See patch-night.log.` | Players can play, without our patches. Exit 1. |
| `Patch night FAILED: the server is not up. Start it in the manager and check patch-night.log.` | Neither came up, or the live program was already the official one and failed. Exit 1. |

Things that follow from the code and have not been observed in a real run:

- The fall-back runs for any failed check, including the realm guard in step 3 and a timeout, not only for a broken
  build. A realm guard failure therefore also removes the patched program.
- After `The server came up on core A, expected B.` the world is left running. If the fall-back also mismatches,
  the last line says the server is not up while a world server may in fact be running. Check
  `Get-Process worldserver` before believing it.
- After a fall-back, the nightly restart will not reinstall the build. The next weekly patch night or by-hand run
  does, and it will hit the same failure if the cause is still there.

## All outcome lines (`last-run.txt`)

`Finish` (line 68) writes `yyyy-MM-dd HH:mm  OUTCOME` to `last-run.txt`, logs it as OK or FAIL, logs
`---- patch night finished ----` and exits. By-hand runs then wait for Enter.

| Mode | Outcome | Exit |
|---|---|---|
| Any | `Missing PATH; nothing was changed.` | 1 |
| Any | `Stopped with an unexpected error: REASON` | 1 |
| Patch night, nightly | `Cannot read the revision of PATH; nothing was changed.` | 1 |
| Patch night, nightly, start | `No settings kit at PATH; nothing was changed.` | 1 |
| Patch night | `Release TAG has no zip; nothing was changed.` | 1 |
| Patch night | `The downloaded package has no installer; nothing was changed.` | 1 |
| Patch night, nightly | `Patch night OK: WHAT, settings checked, server up on core REV.` | 0 |
| Patch night, nightly | `Patch night FAILED on the patched server; the official server is running instead (no Mystic Enchants). See patch-night.log.` | 1 |
| Patch night, nightly | `Patch night FAILED: the server is not up. Start it in the manager and check patch-night.log.` | 1 |
| Start-Server | `Server started on core REV with your settings.` | 0 |
| Start-Server | `The server is already running. Stop it in the manager first to restart it with bots.` | 1 |
| Start-Server | `Cannot read the revision of PATH.` | 1 |
| Start-Server | `The server did not come up. See patch-night.log, or start it in the manager.` | 1 |
| Rebuild bots | `The manager has the REALM realm active, not Wildcard; nothing was changed.` | 1 |
| Rebuild bots | `The server did not start: REASON` | 1 |
| Rebuild bots | `Cannot list the bots: REASON` | 1 |
| Rebuild bots | `Wildcard bots NOT rebuilt: N non-Hero bot characters are still there. The server is up; see patch-night.log.` (or `not up`) | 1 |
| Rebuild bots | `Wildcard bots rebuilt: all N non-Hero bots removed; SQUID is creating Hero bots (they log in over the next minutes).` | 0 |
| Rebuild bots | `The bots were removed, but the server did not come up. See patch-night.log, or start it with Start-Server.cmd.` | 1 |

## Time limits built into the script

| What | Limit | Where |
|---|---|---|
| Any launcher call | 5 minutes unless stated | `Launcher`, line 117 |
| `start-mysql` | 10 minutes | line 698 |
| `start-all` call | 60 minutes | line 703 |
| World load, inside the bridge | 25 minutes | `launcher_bridge.py` `wait_ready` |
| World up check | 30 minutes, every 15 s | line 707 |
| World stop from console | 2 minutes | `StopWorld` |
| Full stop | 5 minutes | `StopServer` |
| One SQL fix file | 5 minutes | `ApplyEnchantFixes` |
| Adding one index | 15 minutes | `EnsureCharacterSpellIndexes` |
| Installer or settings script | 10 minutes | `RunScript`, line 736 |
| Whole scheduled task | 3 hours | `Register-PatchNight.ps1` |

## History of the design (commits on `main`)

| Date | Commit | Change |
|---|---|---|
| 30 Oct | `bc0110d` | First patch night: weekly, unattended, fall-back to the official server |
| 30 Oct | `465c928` | `Start-Server.cmd`, because the manager turns bots off on Wildcard |
| 30 Oct | `729e002`, `7690c6e` | Realm address put back after each start |
| 30 Oct | `91aefe7`, `0a04f12` | Bot name lists copied. Every run downloads the repository and uses a newer script at once |
| 30 Oct | `42290ca`, `2c07b48`, `5d35b3b` | `Rebuild-WildcardBots.cmd` and its fixes |
| 31 Oct | `fc36cc0` | SQL fixes run before each start |
| 1 Nov | `f83171d`, `0736bae` | Catches a manager update that kept our world server. Goes by the auth server |
| 8 Nov | `5eea001`, `36da31e` | 30-minute countdown. Two schedules: Tuesday patch night and the nightly restart |
| 8 Nov | `e244a47` | No countdown while the world is still loading |
| 8 Nov | `257158e` | Spell indexes (the 40-second character list) |
| 19 Nov | `d5412a9` | Realm database guard after a start on the wrong realm's characters |
| 21 Nov | `9ba9f45` | Performance counters and console history, measuring only |
| 21 Nov | `d509cf9` | Pinned third-party addons |
| 22 Nov | `759c7b6` | Staged run: prepare during the countdown, restart only the world, console log rotation, downtime line, parse check |
| 22 Nov | `f5d6cf5` | No download progress bar. The 38 MB build had taken 2 min 20 s |
| 22 Nov | `ba59783` | Settings check report, config encoding repair, 20 settings backups kept |

Full list: `git log origin/main --format='%h %ad %s%n%b' --date=short -- patch-night vm`
