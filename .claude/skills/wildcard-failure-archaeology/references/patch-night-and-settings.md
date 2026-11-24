# Chronicle: patch night, the settings kit and the bot rebuild

Failures and retries in the scripts that run on the VM: `patch-night/PatchNight.ps1` (patch night, the nightly
restart, `Start-Server.cmd`, `Rebuild-WildcardBots.cmd`) and `server-settings/Apply-ServerSettings.ps1` (the
"settings kit", which writes `server-settings.txt` into the server's config files). Facts come from commit
messages and file comments, as of 2026-11-22. Nothing here was re-checked on the VM.

Reading aid:

- **The manager** is CF-Server-Manager, the program that installs and normally starts the CoA server.
- **SQUID** is SQUID's Playerbots (`mod-playerbots`), the random-bot system.
- **RA** is the world server's remote console.
- Windows PowerShell 5.1 is what the VM's scripts run on. Several entries are PowerShell 5.1 traps.

---

## P-01 · 2026-10-30 · Settings kit, three versions in one day

| Step | What happened | Evidence |
|---|---|---|
| v1 | "My Server Settings", uploaded by hand | `2b882b7` (direct commit) |
| v2 | Settings written to `Core/configs/worldserver.conf` were lost: "The manager rebuilds [it] from `Settings/worldserver.conf.template`, so worldserver settings now go to both." Unknown values are read from the manager's saved realm profile (`Settings/realm-profiles/coa.json`). | `e3fc84b`, PR #1 |
| fix | Adding a setting a file did not already have failed: "The config file lines were kept in a fixed-size array (a PowerShell if-expression unrolls an ArrayList)". Errors also vanished with the window; they now stay on screen. | `b8a71b5`, PR #2 |

- **Tried and rejected:** writing only the live config file (v1).
- **Status:** fixed.
- **Lesson:** the manager regenerates config files from templates. A setting has to be written to the template
  as well as the live file, every start.

## P-02 · 2026-10-30 · The manager's Start button switches the bots off on Wildcard

- **Symptom:** no SQUID bots on the Wildcard realm.
- **Root cause:** "The manager forces `AiPlayerbot.Enabled = 0` on Wildcard whenever it starts the server."
- **Evidence:** `465c928`, PR #4; README.md ("SQUID's bots on Wildcard").
- **Tried and rejected:** none recorded.
- **Status:** worked around. `Start-Server.cmd` (`PatchNight.ps1 -StartOnly`) applies the settings and starts the
  server through the launcher bridge instead of the manager's button. README: "This is not something the manager
  supports; keep a backup."
- **Lesson:** start the server with `Start-Server.cmd` or patch night, never the manager's Start button, or the
  bots go off.

## P-03 · 2026-10-30 · Other computers could not join after a start outside the manager

- **Symptom:** friends could not connect.
- **Root cause:** "The launcher resets the realm list to 127.0.0.1 at every start; the manager writes the Play
  with friends address back afterwards." Our start did not.
- **Evidence:** `729e002`, PR #5; `7690c6e`, PR #6 (the optional `realmlist | address = ...` line).
- **Tried and rejected:** none recorded.
- **Status:** fixed. Patch night writes the address back after each start.
- **Lesson:** anything the manager does after a start, our start has to do too.

## P-04 · 2026-10-30 · No Hero bots were created ("No more unused names left")

- **Symptom:** SQUID created no bots on Wildcard.
- **Root cause:** "SQUID names new bots from `playerbots_names` in the realm's characters database, and the
  Wildcard one is empty."
- **Evidence:** `91aefe7`, PR #7.
- **Tried and rejected:** none recorded.
- **Status:** fixed. Before the world starts, the three name lists are copied from the CoA characters database
  when the Wildcard ones are missing or empty. The same commit made each run download the repository and use the
  newest scripts, "so the folders no longer need replacing by hand".
- **Lesson:** a new realm database starts empty of the helper tables modules expect.

## P-05 · 2026-10-30 · Bots were created in CoA classes, not as Wildcard Heroes

- **Symptom:** SQUID's bots on Wildcard had CoA classes.
- **Root cause:** "`CoAChallenges.GameModes.Realm` was empty on the Wildcard realm, so Wildcard was only a
  per-character challenge."
- **Evidence:** `42290ca`, PR #8.
- **Tried and rejected:** none recorded.
- **Status:** fixed. `server-settings.txt` holds every setting the manager makes for a Wildcard realm and only
  applies them while Wildcard is the active realm (`realm | active = wildcard`). The wrong bots were then removed
  with the rebuild (P-06).
- **Lesson:** the realm guard line exists so Wildcard settings never land on the other realm.

## P-06 · 2026-10-30 · Rebuild-WildcardBots, four attempts

`Rebuild-WildcardBots.cmd` starts the server with bots off, erases the non-Hero characters of SQUID's bot
accounts in the Wildcard characters database, then starts normally so SQUID makes Hero bots.

| Attempt | Result | Root cause | Evidence |
|---|---|---|---|
| 1 | Written | | `42290ca`, PR #8 |
| 2 "fix" | First run removed "0 of 2100" | "mysql on Windows can end its lines with an extra carriage return, so no line passed the plain-name check" | `0a04f12`, PR #9 |
| 3 "honest" | It had reported success with bots left | The success message did not check the result | `5d35b3b`, PR #10 |
| 4 "by guid" | Names still failed | "SQUID gives its bots two-word names ("<Name> Bot"), which no plain-name check accepts and which a command argument would split" | `2c07b48`, PR #11 |

- **Tried and rejected:** erasing by character name (attempts 1 to 3).
- **Status:** fixed: "`character erase` also takes the character's number, so the rebuild lists and erases by guid."
  PR #9 also made every mode run the newest `PatchNight.ps1` straight away.
- **Lessons:** trim what `mysql` prints on Windows. Identify characters by number, never by name. A script may
  say "done" only after checking that nothing is left.

## P-07 · 2026-11-01 · A manager update kept our patched world server

- **Symptom:** after the manager updated, the installed core and the saved "official" copy disagreed.
- **Root cause:** "A manager update keeps a world server it sees was changed (ours), so the saved official copy
  goes stale."
- **Evidence:** `f83171d`, PR #29 (first answer); `0736bae`, PR #30 (second answer).
- **Tried and rejected:** PR #29 made patch night stop and tell James to restore the manager's world server in
  the manager's settings. A day later PR #30 replaced that.
- **Status:** fixed. "The auth server is always the manager's own, so its revision shows which release is really
  installed." Patch night goes by the auth server's revision, logs a warning, and passes `-Force` to the
  installer because the stale official copy would make its core check refuse a build that does match.
- **Lesson:** trust `authserver.exe` for "which release is installed", not the world server.

## P-08 · 2026-11-07 · MySQL error 1046 removing auction listings

- **Symptom:** patch night's removal of "UNUSED" developer items from the auction house failed.
- **Root cause:** "MySQL refuses a multi-table DELETE with aliases unless a database is selected."
- **Evidence:** `b872579`, PR #62 (one hour after the feature, `205bec3`, PR #61).
- **Tried and rejected:** none recorded.
- **Status:** fixed with `USE` before the `DELETE`.
- **Lesson:** select the database first in any SQL patch night sends, even when every table is fully named.

## P-09 · 2026-11-08 · Countdown to nobody

- **Symptom:** patch night counted down while the world was still loading.
- **Root cause:** the console is silent while the world loads, and the script read that as "players may be on".
- **Evidence:** `e244a47`, PR #83.
- **Tried and rejected:** none recorded.
- **Status:** fixed. No countdown when the game port does not answer yet.
- **Lesson:** "no answer from the console" and "nobody online" need separate checks.

## P-10 · 2026-11-08 · Two schedules instead of one

- **Symptom:** not a failure. A weekly patch night meant merged fixes waited up to a week.
- **Evidence:** `5eea001`, `36da31e`, `6c313ab`, PR #76; `patch-night/Register-PatchNight.ps1:1-14`.
- **Status:** superseded on 23 Nov by P-17. Until then `Register-PatchNight.ps1` registered "CoA Patch Night"
  (weekly, default Tuesday 11:00 pm, installs new builds) and "CoA Nightly Restart" (daily from 3:30 am, 30 minute
  countdown, restart 4:00 am, `-NoInstall`).
- **Lesson:** SQL and settings changes go live at the next 4 am restart. Anything in `patches/` waits for a build
  and the next patch night that installs it.

## P-11 · 2026-11-19 · Patch night started Wildcard on the other realm's characters

- **Symptom:** "on 19 November it brought the Wildcard realm up on the other realm's characters."
- **Root cause:** "From server 0.261119.114, `Scripts\manage.py` writes the default `acore_world` and
  `acore_characters` into worldserver.conf on every start, whatever realm is active. The manager app puts the
  realm's databases back itself; patch night starts through manage.py."
- **Evidence:** `d5412a9`, PR #186.
- **Tried and rejected:** none recorded.
- **Status:** fixed. `launcher_bridge.py` wraps `prepare()` and puts the Wildcard databases back;
  `PatchNight.ps1` "logs the databases at every start and refuses to start the world if the Wildcard realm is
  active but the config points anywhere else".
- **Lesson:** this is the most serious patch night incident on record. A manager release can change what its
  start script writes. The guard that refuses to start is the protection; do not remove it.

## P-12 · 2026-11-21 · Patch night overwrote a settings line

- **Symptom:** the auction bot's never-list line in `server-settings.txt` (cut gems, high scrolls) had no effect.
- **Root cause:** it "was being overwritten by patch night's list" of items to skip.
- **Evidence:** `ee4ab40`, PR #222.
- **Tried and rejected:** none recorded.
- **Status:** fixed: "the two are now merged."
- **Lesson:** when patch night computes a setting itself, it must merge with the line in `server-settings.txt`,
  not replace it.

## P-13 · 2026-11-22 · Three minutes of downtime spent applying settings

- **Symptom:** "Patch night spent about 3 minutes of server downtime applying server-settings.txt."
- **Root cause:** "each of the 261 settings was tested against every line of both copies of worldserver.conf."
- **Evidence:** `d802f8c`, PR #229. Test in the commit: 266 settings across 12 files, identical output, 24.6 s
  became 1.7 s.
- **Tried and rejected:** none recorded.
- **Status:** fixed (each file read once and indexed by setting name).
- **Lesson:** the commit's side-by-side test (same files, same counts) is the model for changing this script.

## P-14 · 2026-11-22 · Config files grew from 240 KB to 22 MB (encoding)

- **Symptom:** `playerbots.conf` "had grown from 240 KB to 22 MB after 16 writes", and one setting no longer
  matched (the Questie prefix in `AiPlayerbot.TradeActionExcludedPrefixes`).
- **Root cause:** "Get-Content read the UTF-8 configs as Windows-1252 and they were written back as UTF-8,
  multiplying every non-ASCII character on each write."
- **Evidence:** `ba59783`, PR #229; `server-settings/Apply-ServerSettings.ps1:82` (comment).
- **Tried and rejected:** none recorded.
- **Status:** fixed. Configs are read as UTF-8 (1252 only if invalid) and written in the encoding read; garbled
  lines are restored. Tested "on the live playerbots.conf: back to 243 KB, every restored line identical to the
  .dist".
- **Lesson:** in Windows PowerShell 5.1, `Get-Content` without an encoding is not UTF-8. The damage built up one
  write at a time and was only found at 16 writes; the commit does not say when it began.

## P-15 · 2026-11-22 · Settings the server does not know

- **Symptom:** none visible. A renamed or removed setting is "ignored by the server", and 49 new options from
  core updates ran on defaults.
- **Root cause:** nothing compared `server-settings.txt` with what the installed server reads.
- **Evidence:** `ba59783`, PR #229 (the check, written to `server-settings\settings-report.txt`); `6223bc8`,
  PR #230 (four of the 49 set on purpose, "reviewed with James on 22 Nov").
- **Tried and rejected:** a follow-up that recognises setting names built at run time and settings only the
  website reads (`5978ee4`) was pushed after PR #229 merged and is **not on `main`** (U-05 in
  `references/unmerged-and-abandoned.md`).
- **Status:** check is live; the refinement is not.
- **Lesson:** read `settings-report.txt` after a core update.

## P-16 · 2026-11-22 · Staged patch night, and three smaller fixes

- **Symptom:** downtime longer than needed, and a console log of gigabytes.
- **Evidence:** `759c7b6`, `f5d6cf5`, PR #229.
  - Downloading, unpacking and writing settings now happen during the countdown with the server up. "If
    preparing fails the restart is called off in game and the server stays up."
  - "Only the world server restarts: MySQL (warm cache) and the auth server keep running."
  - "No download progress bar (Windows PowerShell 5.1 downloads crawl with it)."
  - `world-console.log` (3 GB) and `auth-console.log` cleared once (history saved first), then dated per run with
    the newest 3 kept.
  - "New patch-night or settings scripts from GitHub are used only if they read cleanly."
- **Status:** adopted on 22 Nov. No run of the staged version is recorded in the repository yet.
- **Lesson:** `docs/agents/context/patch-night.md` gives the expected result: a "Downtime: N s" line of about
  2 minutes; over 5 is worth a mention.

## P-17 · 2026-11-23 · Patch night every night, installing builds

- **Symptom:** not a failure. With builds installed only on Tuesdays, a merged and built C++ fix waited up to a week,
  and SQL that needed new code ran days ahead of it.
- **Evidence:** `aef54f0`, PR #240 (James, 23 Nov); `patch-night/Register-PatchNight.ps1` header.
- **Status:** adopted. One task, "CoA Patch Night", daily at 3:30 am, restart at 4:00 am, installs any new build.
  Running the register script removes "CoA Nightly Restart". `PatchNight.ps1` was not changed: `-NoInstall` and its
  log line still exist, and the header comment and in-game text still say "nightly restart". Build 74 was installed
  on 24 Nov at 04:04, the first install under the new task.
- **Side effect, from the code:** after a fall-back to the official server the same bad build is now retried every
  night, not every Tuesday (`wildcard-architecture-contract`, W7).
- **Lesson:** with PR #241 (B-17) a merged patch normally reaches players the next morning, with its SQL.

---

## Line endings and PowerShell 5.1: the small recurring ones

| Date | Trap | Evidence |
|---|---|---|
| 30 Oct | Patch night script had mixed line endings | `1f81e21`, PR #5 |
| 8 Nov | Unix time: "Windows PowerShell read 'Utc' as milliseconds" (launcher and publish) | `4168ff5`, PR #72 |
| 8 Nov | "Windows PowerShell's top-level JSON array" got nested in the changelog | `f9c3d54`, PR #81 |
| 8 Nov | `Math.Max` picked its int overload: "46 GB total overflowed" | `99f4fa7`, PR #73 |
| 8 and 12 Nov | Site page and status service must keep CRLF line endings | `e11ba2a`, `07dc858` |
| 22 Nov | `Get-Content` default encoding (P-14) | `ba59783`, PR #229 |
| 22 Nov | Progress bar slows downloads | `f5d6cf5`, PR #229 |

All seven are behaviours of Windows PowerShell 5.1 or of Windows line endings, and each was found in use.
