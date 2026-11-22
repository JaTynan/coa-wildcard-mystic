# Failure history of the friends-facing surface

Every row is from a commit message or diff in this repository (read 2026-11-22). "Lesson" is the reusable part.
To read any of them in full: `git show <hash>`.

## Launcher (Windows), versions 1 to 5

| Date | Version | Symptom | Cause | Fix | Commit / PR |
|---|---|---|---|---|---|
| 7 Nov | 1 | (first release) | - | launcher, publish script, IIS setup, patch-night hook | `bc98dc1`, PR #54 |
| 7 Nov | 2 | A friend outside the home network got "Unable to connect" | The published client carried the VM's own `Data\<locale>\realmlist.wtf`, pointing at the home address, and the game reads that file before `WTF\Config.wtf` | Launcher writes `realmlist.wtf` in every `Data\<locale>` folder; publish stops listing any `realmlist.wtf` | `eb1f8de`, PR #65 |
| 7 Nov | 3 | Window frozen ("Not responding") on the first check after install: it read all 43 GB | Every file was hashed in one go on the window's thread | A file whose size and modified time match the manifest counts as current (publish adds `mtime`; downloads keep it); hashing in 4 MB pieces with progress. Also added: `launcher.log`, the Log button, plain-English errors, the game-server check | `d025dc7`, PR #71 |
| 8 Nov | 3 | Modified times never matched, so files were re-hashed or re-downloaded | Windows PowerShell read the `'Utc'` argument of `[datetime]::new(1970,1,1,0,0,0,'Utc')` as milliseconds | Use `[DateTimeOffset]` with `SpecifyKind(..., 'Utc')` and `ToUnixTimeSeconds()` in both publish and launcher | `4168ff5`, PR #72 ("date fix") |
| 8 Nov | 4 | Progress failed on the 46 GB total | `[Math]::Max(1, <big number>)` picked the 32-bit integer overload and overflowed | Force doubles: `[Math]::Max([double] 0, ...)` | `99f4fa7`, PR #73 |
| 8 Nov | 5 | Every launcher got HTTP 404 on one file and stopped | IIS keeps its own `web.config` in the client folder and never serves it, yet it was in the manifest | Publish skips `web.config`; the launcher skips it too and carries on past any single failed file | `c3b4125`, `12f7f93`, PR #74 |
| 8 Nov | 5 | Game kept an old address when the site or an update failed | The realm was only set on the success path | The realm is always set at the end, from `launcher.json` or the built-in default | `9cb5609` |

Process slip on 8 Nov: the `web.config` fix was pushed to the `launcher-date-fix` branch after PR #72 had already
merged, so it "missed #72" and had to go in again as PR #74 (the commit title of `12f7f93` says so; the stray commit
`233669f` is still the tip of `origin/launcher-date-fix`). Lesson: once a PR is merged, later pushes to its branch
go nowhere; open a new PR.

## Publish script and site

| Date | Symptom | Cause | Fix | Commit / PR |
|---|---|---|---|---|
| 8 Nov | Recent changes was empty or wrong | Windows PowerShell hands back a top-level JSON array as ONE object; wrapping it in `@()` nested it, so the loop saw one item. The real error was also swallowed. | Assign the result directly; report the real error text in the publish output | `f9c3d54`, PR #81 |
| 8 Nov | `how-to-play.html` showed as fully rewritten | Line endings flipped between CRLF and LF | A commit to restore CRLF (`e11ba2a`). The file is LF again as of 2026-11-22 (it flipped back in `101f66a`), and there is no `.gitattributes`, so this can recur. | `e11ba2a` |
| 13 Nov | The auction-house character and deleted test characters appeared on the leaderboards | No filter | `Leaderboards.HiddenCharacters` setting and `deleteDate IS NULL` | `b516c2b` |
| 21 Nov | Pets page blank: "the world database did not answer" | The query used `creature.id1` (newer AzerothCore); this core's column is `id` | Column fixed; queries now raise MySQL's own message into `signup.log`; 60 s timeout | `2563565`, PR #215 |
| 21 Nov | Players missed most of the home page | One endless page | Short home page plus Server, Leaderboards and Changes pages; shared `site.js` | `4394492`, PR #212 |

Lessons: (1) the VM runs Windows PowerShell 5.1, whose JSON and date handling differ from PowerShell 7; (2) this
core's world database does not match upstream AzerothCore column names, so check a query on the VM's database before
merging; (3) an error message that hides the real error costs a second round.

## Linux launcher, Steam and Proton

| Date | Version | What | Commit / PR |
|---|---|---|---|
| 8 Nov | 1 | First release: install, update, realm, server check, `--play` through Wine or Bottles, self-update; `launcher.json` gains `linuxLauncherVersion` | `0867997`, PR #91 |
| 8 Nov | 2 | `--add-to-steam`: writes the binary `shortcuts.vdf` (existing shortcuts kept) and the Proton mapping in `config.vdf`, with one-time backups; refuses while Steam runs (Steam overwrites its settings when it exits) | `f429df6`, PR #97 |
| 8 Nov | 3 | `--add-shortcut`: one-click app menu and desktop entry; terminal stays open on errors | `e9f88fc`, PR #100 |
| 8 Nov | 4 | Steam entry renamed "Project Descension" (replaces an older "Wildcard" entry instead of duplicating it); artwork; **loading-screen fix**: the client's `DivxTac.dll` hung the loading screen under Proton (endless load, then the 30 s packet watchdog disconnect), switched off with `WINEDLLOVERRIDES="divxtac=d"` | `f10cf9e`, PR #101 |
| 12 Nov | 5 | Steam's Play button updates the game first (`--steam-update` in the launch options) | `fe32099`, PR #131 |
| 15 Nov | 6 | **Play from Steam did nothing**: Steam's `%command%` contains `--`, which argparse treats as the end of options, so `--steam-update` died with "unrecognized arguments" before updating or starting. Fix: take `--steam-update` from the command line before argparse. | `2bbf3d5`, PR #161 |

Lesson: anything that wraps another program's command line must be tested with that program's real command line.

## Sign-up page and its window

| Date | What | Commit / PR |
|---|---|---|
| 7 Nov | First release: invite code, Cloudflare human check, daily limits, accounts through the manager | `a4ccee9`, PR #68 |
| 8 Nov | `/api/status` added to the same service for the home page | `760b9a2`, PR #79 |
| 9 Nov | Recruit-a-Friend; existing accounts prove their password against the SRP6 verifier | `26af572` |
| 14 Nov | Bug-report relay thread added to the same service | `eb2b3a2`, PR #147 |
| 22 Nov | **The sign-up window**: the task's console window used to stay blank, and clicking into a console starts a text selection that pauses whatever writes to it. It now starts minimised, shows a status board every 30 s, and click-to-select is switched off for it. | `5dfb9a7`, PR #231 |

Lesson: this one process now carries four jobs (sign-up, status API, pets API, bug-report relay) plus the board.
If its window is closed or the task is stopped, all four stop together.

## Addons

| Date | Version | Symptom | Cause and fix | Commit / PR |
|---|---|---|---|---|
| 30 Oct | 1.7 | Every active enchant was drawn one slot along (often on a locked slot) | The client numbers slots 1-17, the server 0-16; the addon now answers client slot i with server slot i - 1 | `f46610e`, PR #12 |
| 31 Oct | 1.8 | Restored-by-twin enchants showed the old, misleading text | `TooltipData.lua` + `TooltipFix.lua` show the twin's description | `b1f1d81`, PR #20 |
| 31 Oct | 1.9 | Wrong line was taken as the description | Read the first line under the name, not the last | `c4eaf1a`, PR #22 |
| 7 Nov | 1.10 | "Requires Level 60" was rewritten on item tooltips (every level-60 epic for one enchant) | Enchants whose text starts with a "Requires <spell>" line gave that line as their "description". Requirement lines and lines under 30 characters are now never used or changed. | `6a7f08b`, PR #60 |
| 21 Nov | 1.11 | The collection window froze the game for a moment on open, page turn and filter change | Every query looked up and sorted all 6,440 enchants. Names and order are now built once, known/unknown is only checked when that filter is on, and a query repeated within 2 seconds reuses its answer. | `4fdb6a0`, PR #224 |
| 21 Nov | CombatLogFix 1.0 | Damage meters showed nothing | A 3.3.5 client bug: with many units around the combat log stops passing events until cleared. New addon clears it on a zone-type change and when the player's own power-costing spell succeeds with no combat-log event within a second (at most once per 5 s). | `447b561`, PR #221 |

## Client patch

| Date | Symptom | Cause and fix | Commit / PR |
|---|---|---|---|
| 2 Nov | 1,206 enchants had no spell in the client's Wildcard list | Built `patch-ZZW.MPQ` from the client's own two spell lists. Tested 2 Nov on James's Linux desktop: `GetSpellInfo(911367)` returned the right name and icon. | `34083eb`, PR #36 |
| 7 Nov | **The character-creation screen crashed** | The added spells still carried a class family and class flags, and that screen gathers spells by class. The builder now zeroes columns 208-211 for the added spells. Fixed and tested 7 Nov. | `dc2a5da`, PR #52 |
| 13 Nov | Some racials could not be used during the global cooldown even after the server change | The client itself refuses a spell during the global cooldown, so the client copy must change too (`racials.py`) | `5053590`, PR #138 |

Lesson: client data and server data are two copies of the same spell. Change one without the other and the
player sees a wrong tooltip, a refused cast, or a crash.
