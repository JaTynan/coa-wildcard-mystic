---
name: wildcard-debugging-playbook
description: Triage and symptom lookup for the Wildcard private WoW server (CoA AzerothCore fork). Load it first whenever something is broken or behaving oddly and the layer at fault is not yet known - a failed GitHub build (anchor "Core changed", "SQUID changed", compile or CreateProcess errors), the world server not starting or crashing ("Duplicate blank sub-command"), patch night failing or falling back to the official server, a setting that does not take effect, SQL or database errors (MySQL 1046, slow character list), a Mystic Enchant that never fires, fires on every hit or applies twice, addon or tooltip faults, client crashes, bots frozen or spamming whispers, launcher or download site errors, sign-up or website pages blank. Gives a first-five-minutes triage with the file to read per layer, a 90-row symptom, cause, check and fix table citing commits and PRs, experiments that split competing explanations, and traps that cost real time. Not for lag or tick-time problems.
---

# Wildcard debugging playbook

Use this when something is wrong and you do not know why yet. It tells you **which layer is broken, how to prove
it, and what was done the last time it happened**. Every row comes from this repository's own history: commit
messages, script comments and docs. Facts are as of 2026-11-22 (`origin/main` at `d3e030f`, #231).
`docs/agents/*` and `.claude/agents/*` are cited below; they
came with PR #232, merged on 22 Nov 2026 (`0802d4f`), and are on `main`: what rests on them is **DOCTRINE**. Status words (DOCTRINE, PRACTICE, NOT BUILT YET, OPEN ...)
are defined in `wildcard-change-control`, section 1.

Three ground rules:

1. **Look before you touch.** Every check in the triage and in the lookup table is read-only. Reading logs, config
   files and git history needs no approval.
2. **Anything that changes the live server, a setting, SQL, a patch or a script: classify with
   wildcard-change-control first.** Patch night, the build workflow, the installer and rollback are hard stops in
   `docs/agents/context/change-risk.md` (always James). James merges.
3. **A build takes about 3½ hours. That is normal.** Do not describe a running build as slow or stuck, and do not
   "try a rebuild" as a diagnostic step when a cheaper check exists.

VM paths below are the ones the repo's scripts and docs use (`patch-night/PatchNight.ps1`,
`docs/agents/context/patch-night.md`). **They are from the repo and were not re-verified on the VM on 2026-11-22.**
The PowerShell lines in this file were written but not executed on 2026-11-22.

## When NOT to use this skill

| You have | Use instead |
|---|---|
| Lag, slow world updates, long ticks, "the server stutters" | wildcard-lag-spike-campaign |
| A need to measure something (timing log, counters, slow queries, reading logs in depth) | wildcard-diagnostics-and-tooling |
| A wish for the full story of an investigation, dead end or revert | wildcard-failure-archaeology (this skill keeps the short lookup; that one keeps the stories) |
| A cause already known, and you need to write the fix | wildcard-patch-authoring (C++ patches), ascension-restoration (enchant SQL), wildcard-settings-and-flags (settings), wildcard-build-and-env (the build), wildcard-client-and-web (launcher, site, sign-up) |
| A question of what risk class a fix is, or who may run it | wildcard-change-control |
| A question of how patch night works step by step, or how to roll back | wildcard-run-and-operate |
| A need to prove a fix works | wildcard-validation-and-qa |

## Words used here

- **Manager**: CF-Server-Manager, the program that installs and updates the official CoA server on the VM.
- **Official server**: the world server program the manager installs. **Patched server**: ours, built by GitHub
  Actions from the same source plus `patches/`.
- **Core**: the server's C++ source (CoA's fork of AzerothCore). A **core revision** is its commit, printed on line 1
  of `Server.log`.
- **Anchor**: the exact piece of upstream source text a patch script searches for before editing. If it is not found
  exactly once the build stops on purpose.
- **Patch night**: `patch-night/PatchNight.ps1` on the VM. One scheduled run, daily at 3:30 am (restart
  4:00 am), which also installs a new build. Schedule: `wildcard-run-and-operate`.
- **SQUID's bots**: the mod-playerbots module that runs the roughly 750 random bots.
- **Wildcard Hero**: the realm's classless character, class id 10.
- **Proc**: an effect that fires when something else happens (a hit, a cast).
- Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## First five minutes

### Step 1: write down four facts (2 minutes, all read-only)

Run on the VM in PowerShell:

```powershell
$s = 'C:\Games\CoA Server'
Get-Content "$s\patch-night\last-run.txt"                       # outcome of the last patch night or restart
Get-Content "$s\Core\worldserver.patched-release.txt"           # installed build tag, e.g. wcme-server-0.261119.114-build70
Get-Content "$s\Core\Logs\Server.log" -TotalCount 1             # core revision of the program running now
Select-String -Path "$s\patch-night\patch-night.log" -Pattern '\[(WARN|FAIL)\]' | Select-Object -Last 30
```

And in the repo:

```bash
git log origin/main --first-parent --merges --since='3 days ago' --format='%h %ad %s' --date=format:'%m-%d %H:%M'
git tag -l 'wcme-server-*' | tail -5        # newest builds (run after a fetch; a fetch is James's or the main session's call)
```

Now you know: did the last restart succeed, which build is installed, which core is running, and what changed
recently. Note on "what changed": `CHANGES.md` says changes go in as one PR per patch night; in practice up to 31 PRs
were merged in a day (8 Nov) and 23 on 21 Nov. So "last night's change" is usually a list, not one thing. Read the list.

### Step 2: find the layer

Work down this table and stop at the first row whose sign matches.

| Layer | The sign | Look here first (exact file or command) | Rows |
|---|---|---|---|
| **Build** | No new release on GitHub; the Actions run is red | The failed step's log in the Actions run "Build patched worldserver" (`.github/workflows/build-worldserver.yml`). The step name tells you the family: "Apply our patches" = a `.patch` file no longer fits; "Apply our patch scripts" = an anchor moved; "Build worldserver" = compile or link error. | B1-B10 |
| **Install** | `patch-night.log` has "installer refused or failed", or the installed tag is older than the newest release for more than a week | `patch-night\patch-night.log`; `Core\worldserver.patched-release.txt` | P2, P3, P10 |
| **Start-up** | "did not come up", "official server is running instead", or the world never prints "World Initialized In" | `Core\Logs\Server.log` (this start only), `Core\Logs\Errors.log` (lines after the last start), newest file in `Core\Crashes\` | S1-S10 |
| **Patch night** | `[FAIL]`, "Patch night FAILED", or no log lines at the scheduled time | `patch-night\last-run.txt`, then `patch-night\patch-night.log` between "---- patch night started ----" and "---- patch night finished ----" | P1-P12 |
| **Settings** | A value in `server-settings.txt` is not what the server does | `server-settings\settings-report.txt` (unknown settings, "Bad value", settings left on defaults); the "Settings:" line in `patch-night.log` | C1-C8 |
| **SQL / database** | "Enchant fix ... failed", a MySQL error number, a page or login that waits on the database | `patch-night.log` lines "Applied enchant fix NNN to DATABASE" or "... failed: ..."; `patch-night\signup.log` for the website's queries | Q1-Q4, P5, P9 |
| **C++ behaviour** | The server runs; one game rule is wrong for everyone, with addons off | Is the patch in the installed build? `CHANGES.md` row for the patch, its setting in `server-settings.txt`, then experiment 3 below | X1-X8 |
| **Mystic Enchant** | One enchant does nothing, fires constantly, or doubles | In game on a GM test character: `.aura SPELL`, `.list auras` (`docs/enchant-restoration.md`); `enchants/tracker.csv`; `enchants/core-overlap-review.csv` | E1-E11 |
| **Addon** | Wrong only in the interface (tooltip text, a window, a meter); goes away with the addon off | The addon's folder under `addon/`; the player's `Interface\AddOns` | A1-A5 |
| **Client patch / client** | The game client itself crashes or shows no name or icon for a spell | Whether `patch-ZZW.MPQ` is in the client's `Data` folder; `client-patch/build_client_patch.py` | K1-K3 |
| **Bots** | Only bots misbehave (frozen, wrong class, whisper spam, missing) | `modules\playerbots.conf` values against `server-settings.txt`; `patches/20-bots.ps1`, `61-`, `87-`, `96-` | R1-R6, S6, S7 |
| **Launcher + site** | A friend cannot install, update or connect | The player's `launcher.log` (next to the launcher; the Log button opens it); on the VM the site folder `F:\wildcard-site` | L1-L8 |
| **Sign-up / web services** | The sign-up page, status, pets or leaderboards are blank or refuse | `patch-night\signup.log`; scheduled task "Wildcard Sign-up" | U1-U2 |
| **Process** | The repo, a merge or a PR is the problem | `git log --merges`, `git diff -w` | G1-G3 |

If the sign is **slowness**, stop here and load wildcard-lag-spike-campaign.

### Step 3: look the symptom up

Open **`references/symptom-table.md`** (read this when you have a symptom and a layer: it holds all 90 rows with
cause, discriminating check, fix route and the commit or PR). Then read the cited commit in full; the messages are
long and precise:

```bash
git log -1 --format=%B <hash>
git log --all --no-merges -i --grep='<two or three words of the symptom>' --format='%h %ad %s' --date=short
```

### Exact messages, and where they are in the table

| Message you see | Row |
|---|---|
| "Core changed: ...", "CoA changed: ...", "SQUID changed: ...", "SQUID's bots changed: ...", "mod-ollama-chat changed: ...", "Battleground Spoils part missing or core changed" (full list: `wildcard-patch-authoring`) | B1 |
| "... no longer fits release ... The patch needs refreshing for this core." | B2 |
| "ninja: fatal: CreateProcess: The parameter is incorrect (is the command line too long?)" | B3 |
| Compile error near `SYNCHRONIZE` or another all-capitals name | B4 |
| `ChatCommandTable` or `Console` not declared | B5 |
| Warning C4067, then a class "undeclared" | B6 |
| "... is already built; nothing to do." | B9 |
| "Duplicate blank sub-command" | S1 |
| "The Wildcard realm is active, but worldserver.conf points at ..." | S3 |
| "The server came up on core X, expected Y." | S4 |
| "The world server stopped within a minute of starting." | S5 |
| "No more unused names left" | S6 |
| "The manager installed core X (auth server), but kept our patched world server from core Y" | P2 |
| "This build is for core A, but the manager installed core B" | P3 |
| "Patch night FAILED on the patched server; the official server is running instead" | P4 |
| MySQL error 1046 | P5 |
| "... from GitHub does not read cleanly; keeping the current copy" | P8 |
| "Enchant fix ... failed: ..." | P9 |
| "Nightly restart: the new build is left for the weekly patch night." (old task still registered) | P10 |
| "repaired: N garbled line(s) in ..." | C1 |
| "the world database did not answer" (website) | Q2 |
| Bot whisper "I have a master already" | R2 |
| Launcher: one file 404 (`web.config`) | L1 |
| Client: "Unable to connect" from outside the home network | L3 |

Normal lines that are **not** faults (`docs/agents/context/patch-night.md`): "No patched build found for this core, but the installed patched server matches it";
settings "on defaults" (only a change in their number matters).

## Discriminating experiments

Each one splits two explanations with a single check. Read-only checks come first. Where an experiment changes the
live server it says so: **classify with wildcard-change-control first**, and James decides.

### 1. Is it our patch, or CoA's own core?

- Read-only first: does any file under `patches/` touch the code involved?
  `grep -rln '<function or file name>' patches/` and the matching row in `CHANGES.md`. If nothing of ours touches it,
  it is CoA's (or SQUID's) and belongs in a report to them (wildcard-docs-and-publishing).
- Read-only second: most of our changes have a switch. Find the setting in `server-settings/server-settings.txt`
  and see whether the symptom is described in its comment.
- Live experiment (changes the server; rollback is a hard stop, James only): turn the patch's setting off for one
  restart, or put the official program back with `Restore-Official.cmd` (it refuses while the world server runs).
  **Before Restore-Official**, compare the saved copy's core with the auth server's: after a manager update the saved
  `worldserver.official.exe` can be from an older core (row P2), and an old program on new databases is a new fault.
  Remember what the official server lacks: no Mystic Enchants on Wildcard, and every setting our patches read is ignored.

### 2. Is it a setting, or the build?

Three facts decide it, all read-only:

1. `server-settings\settings-report.txt`: is the setting "unknown" or a "Bad value"? Then the server never used it.
2. The comment above the setting in `server-settings.txt`: which build does it need?
3. `Core\worldserver.patched-release.txt`: is that build installed?

Known name, good value, build installed, and still wrong: it is the code (or the value was reset; row C2).
Setting absent from `origin/main`: it was never merged (row C3).

### 3. Is the fix actually live?

Do not confuse "merged" with "live". When each layer goes live has one home: `wildcard-run-and-operate`, "When
does my merged change go live?". In short: settings, SQL, addons and scripts at the next restart; C++ only after a
build that contains it is installed; the client patch only when rebuilt and copied by hand. How to **prove** it:

| Kind of change | Proof that it is live |
|---|---|
| Settings, `sql/enchants/*.sql`, addons, patch-night scripts, site | `patch-night.log` after the merge time: "Downloaded the current server-settings", "Applied enchant fix NNN" |
| C++ (`patches/`) | The release notes of the installed tag contain "This repository: OWNER/REPO SHA". Then: `git merge-base --is-ancestor <fix-commit> <SHA> && echo in-build` (or `which_build.py` in `wildcard-build-and-env`) |
| Client patch (`patch-ZZW.MPQ`) | File date in the client's `Data` folder |

Since PR #241 the evening build picks up a merged C++ patch by itself (row B9), and the next 3:30 am patch night
installs it. A patch merged after the evening run started, or a failed build, means a day's wait. A by-hand rebuild
is James's call (`wildcard-build-and-env`, rule 2).

### 4. Is it the server, or the client (addon, client patch)?

- The server's truth for an aura is `.list auras` on the character. The tooltip is the client's opinion, possibly
  rewritten by the WildcardEnchants addon (rows A1, A2).
- Disable the suspect addon on **your own** client and reload. Fault gone: addon. Fault stays: server or client data.
- For a client crash, take `patch-ZZW.MPQ` out of the `Data` folder of a **test** client, not of `F:\CoAClient` on
  the VM: friends' launchers sync from that folder.
- Some rules are decided inside the client and the server cannot overrule them (row X2: the rune count).

### 5. Is it data (SQL), or code?

- Did the file run? Search the last start in `patch-night.log` for "Applied enchant fix NNN" or "failed:".
- Is the row there? A read-only `SELECT` with the same client and credentials file patch night uses
  (`PatchNight.ps1`, function `Sql`). **SELECT only**: it is an admin login.

```powershell
'SELECT * FROM acore_world_wildcard.spell_proc WHERE SpellId = 12345;' |
  & 'C:\Games\CoA Server\mysql\bin\mysql.exe' '--defaults-file=C:\Games\CoA Server\mysql\admin-client.ini' --batch
```

- Row present and behaviour still wrong: the code path does not read it (rows E6, E8) or a patched build is needed.

### 6. Bots only, or players too?

Reproduce with a real player character. Code written for players also runs for about 750 bots, and bots do things
players never do (answer commands in channels, revive themselves at a spirit guide): rows S2, X4, R2, R3.

### 7. Did a core update cause it, or did we?

Line 1 of `Server.log` gives the running core. Compare the date the symptom began with the manager release dates
(the release number in a tag such as `wcme-server-0.261119.114-build70` appears to carry the date, 26-11-19) and with
`git log origin/main --first-parent --merges --since=<date>`. A manager update can also silently reset settings
(row C2), change how the server is started (row S3) or add a module that clashes (row S1).

### 8. Will this patch script still fit, before spending a build on it?

Do not find out in the build. Apply the script to the pinned sources locally first: wildcard-patch-authoring holds
the pre-flight. Row B6 shows why the pre-flight must run the script's own text unchanged.

## Traps that cost real time

Short versions. The full stories are in wildcard-failure-archaeology.

**1. "It compiled for me" (21 Nov, e0cc2f5, #210).** A patch script inserted two `#include` lines from a text block
with no final line break. The last one ran into the file's next line, the compiler ignored that line with only a
warning, and a class was "undeclared" hours into the build. The local check had passed because it added the line
break itself. *Lesson: a local check must run the real script on the real source, not a tidied copy.*

**2. The build that passed and could not start (19 Nov, 01159e2, #187).** Build57 compiled, passed its only check
(`worldserver.exe --version`) and stopped while loading with "Duplicate blank sub-command": a new SQUID version and a
core module both registered the same commands. The official build quietly patches SQUID; ours had not. *Lesson: a green
build proves the program runs, not that the world loads. When a new upstream release arrives, read what the official
build repository changed, not only the core.*

**3. The config file that grew to 22 MB (found 22 Nov, ba59783, #229).** Each settings run read UTF-8 files as
Windows-1252 and wrote them back as UTF-8. Every non-English character multiplied. Nothing failed for 16 runs; then
one bot setting with a Cyrillic prefix stopped matching and `playerbots.conf` was 22 MB. *Lesson: a file that only
ever grows is a symptom. In Windows PowerShell 5.1, say the encoding on every read and write.*

**4. The 40-second character list (8 Nov, #82, #84, #86).** Guessing would have blamed the bots or the disk. A
temporary slow-query log (queries over 1 s) showed one delete scanning about 1.7 million rows at every login. One index
fixed it: 40 s to under 1 s. The log was then removed. *Lesson: add a temporary measurement, find the fact, remove the
measurement.*

**5. The update that kept our program (1 Nov, f83171d, 0736bae).** The manager updated to a new core but left the
world server alone because it saw it had been changed. Patch night read the old revision from it and thought nothing
had happened. *Lesson: the auth server is always the manager's own; its revision is the truth about what is installed.*

**6. The wrong realm's characters (19 Nov, d5412a9, #186).** A manager release changed its start script to write the
default databases every time. The manager app corrects that itself; patch night starts the server another way and
brought Wildcard up on the other realm's characters. *Lesson: anything that starts the server outside the manager
must check which databases the config points at. Patch night now logs them and refuses a mismatch.*

**7. Merged, but not there (21 Nov, d9aa1b0).** A branch set a new value in `server-settings.txt`, then merged `main`
to catch up. The merge kept `main`'s copy of the file and the new line vanished without a conflict. *Lesson: after
merging `main` into a branch, re-read the diff of the files you changed.* The same family: a C++ fix that is merged
but not in the installed build (experiment 3).

**8. Twice the bonus (17-18 Nov, #178).** Several restored enchants worked in testing and were later found to give
their bonus twice: the core already implemented them (a bonus table, a proc rule, or hard-coded) and our script added
the same thing. A review of every enchant we touch against the core found 56 overlaps on 18 Nov (`d8f9215`;
`enchants/core-overlap-review.csv` has 64 rows on 22 Nov, 4 still queued). *Lesson: before writing behaviour for an enchant, search the core for its spell id.*

**9. The optimisation that froze the bots (8 Nov, e608f61 then c02ba12).** Waking only bots within 300 yards of a
player, instead of the whole zone, was meant to save work. Bots near players then walked a few steps and stood still
for 20 minutes or more, "although the radius check reads correctly". Zone waking went back on the same day and the
cause is still not known. *Lesson: this is an OPEN question, not a free performance lever. Do not repeat it without a
new idea; see wildcard-lag-spike-campaign.*

**10. The rule that lives in the client (20 Nov, b4f61e9, #200).** The Wildcard window refused purchases with plenty of
runes owned. The server was right; the client counts only the currency tab, not bags. *Lesson: when the server's
numbers look right and the interface still refuses, the client has its own copy of the rule.*

## Proposed practices (not yet adopted by James)

These are suggestions, not existing rules. Each names its purpose and the incident behind it. They are indexed
with every other skill's proposals in `wildcard-change-control/references/proposed-practices.md`.

| Proposed practice (not yet adopted by James) | Purpose | Motivating incident |
|---|---|---|
| When a run ends "Patch night OK", still search it for "failed:" and `[WARN]` (the same proposal is worded in `wildcard-run-and-operate`; one entry in the register) | A failed enchant SQL file is only a warning and the run still reports OK | `PatchNight.ps1` `ApplyEnchantFixes` (row P9) |
| After merging `main` into a branch, run `git diff origin/main -- server-settings/server-settings.txt CHANGES.md` and confirm your lines are present | Catch a silently dropped line | d9aa1b0 (row C3) |
| When a debugging session ends, add a row to `references/symptom-table.md` with the commit | Keep the lookup current | 90 rows exist only because commit messages were precise |
| Before any `Restore-Official.cmd`, compare the saved official copy's revision with the auth server's | Avoid running an old program on new databases | f83171d (row P2) |

## Provenance and maintenance

Sources: `git log --all --no-merges` (commit subjects and bodies, 30 Oct to 22 Nov 2026), comments in
`patch-night/PatchNight.ps1`, `server-settings/Apply-ServerSettings.ps1`, `vm/Install-WildcardServer.ps1`,
`.github/workflows/build-worldserver.yml`, the `patches/*.ps1` headers, `docs/agents/context/*.md`,
`docs/enchant-restoration.md`, `README.md`, `CHANGES.md`, `signup/README.md`. Nothing here was observed on the VM:
log lines quoted are the ones the scripts print.

Not verified, and how to verify: what `Core\Crashes\` files contain for row S2 (open the newest file); whether
`SkipCinematics = 2` cured the first-login crash (row S10: ask James or test); the exact PowerShell lines in this file
(run them on the VM; all are read-only).

Re-verify what may drift:

```bash
# New failures since this table was written (add rows for them)
git log --all --no-merges --since=2026-11-22 -i --grep='fix\|fail\|crash\|revert\|undo\|stop' --format='%h %ad %s' --date=short
# Anchor failure messages still read "Core changed / CoA changed / SQUID changed / SQUID's bots changed / ..."
grep -ho "throw ['\"][A-Za-z' -]* changed" patches/*.ps1 | sort | uniq -c
# Messages quoted from patch night still exist
grep -n "does not read cleanly\|came up on core\|stopped within a minute\|kept our patched world server\|Enchant fix" patch-night/PatchNight.ps1
# The build's only run-time check, the response-file flag and the automatic rebuild rule
grep -n "worldserver.exe\" --version\|CMAKE_NINJA_FORCE_RESPONSE_FILE\|INPUTS=" .github/workflows/build-worldserver.yml
# Patch night time as registered by default
grep -n "Time = \|WarnMinutes = \|Nightly Restart" patch-night/Register-PatchNight.ps1
# Bot wake settings (trap 9) and the level cap (row C2)
grep -n "BotActiveAloneForceWhen\|MaxPlayerLevel" server-settings/server-settings.txt
# Row C3: is the repair commit pushed after PR #218 on main yet? (rc 1 = still missing)
git merge-base --is-ancestor d9aa1b0 origin/main; echo $?
# Which files use Windows line endings (row G3)
for f in $(git ls-files '*.ps1' '*.cmd' '*.py' '*.sql'); do grep -q $'\r$' "$f" && echo "CRLF $f"; done
# Row count of the table
grep -c '^| [A-Z][0-9]' .claude/skills/wildcard-debugging-playbook/references/symptom-table.md
```

To add a row: reproduce or read the fix commit, write symptom, cause, the one check that tells, the fix route and
the hash; put it in the layer's section with the next free ID; never reuse an ID.
