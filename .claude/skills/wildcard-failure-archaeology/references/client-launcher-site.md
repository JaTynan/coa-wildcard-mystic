# Chronicle: client patch, launchers, website and sign-up services

Failures on the friends-facing side: the client patch (`client-patch/`, which builds `patch-ZZW.MPQ`), the
Windows launcher (`launcher/WildcardLauncher.ps1`), the Linux launcher (`launcher/WildcardLauncher.py`), the
download site and its publish script, and the sign-up and status services (`signup/`). Facts come from commit
messages and file comments, as of 2026-11-22. Nothing here was re-checked on a client or on the VM.

Reading aid:

- **Client patch:** an extra archive the game client loads after its own. `patch-ZZW.MPQ` "sorts after `patch-T`
  and wins" (`docs/enchant-restoration.md`). It is built from the client's own files and never published in this
  repository.
- **Manifest:** the list of files and sizes the launcher compares against to decide what to download.
- **Launcher N:** the launcher's own version number (`$LauncherVersion`); a higher number makes installed
  launchers update themselves.

---

## C-01 · 2026-11-02 to 07 · The client patch crashed the character-creation screen

- **Symptom:** with `patch-ZZW.MPQ` installed, the character-creation screen crashed.
- **Root cause:** the 1,206 enchant spells copied from the Area 52 spell list kept their class family and class
  flags; "the character-creation screen crashed with them (it gathers spells by class)".
- **Evidence:** `34083eb`, PR #36 (2 Nov, patch first built; "Tested on [James's Linux desktop]: `GetSpellInfo(911367)` returns
  Critical Mass"); `dc2a5da`, PR #52 (7 Nov, fix); `client-patch/build_client_patch.py` (docstring);
  `docs/enchant-restoration.md` ("fixed and tested 7 Nov").
- **Tried and rejected:** copying the spell rows unchanged.
- **Status:** fixed. Each added spell is copied "without its class family and class flags".
- **Lesson:** the first test (a spell lookup in game) passed and the patch still crashed a different screen. A
  client patch needs the whole path tested: log in, character list, **character creation**, enter world.

## C-02 · 2026-10-30 · Client crash on a new character's first login (cause never confirmed)

- **Symptom:** "the client crashes on the first login of a new character".
- **Root cause:** not established. The commit says `SkipCinematics = 2` was set "to test whether the intro
  cinematic causes the first-login crash of new characters".
- **Evidence:** `aaf4df4`, PR #13; `server-settings/server-settings.txt` (comment above `SkipCinematics = 2`).
- **Tried and rejected:** none recorded.
- **Status:** worked around: the setting is still 2. The result of the test is not written anywhere, and this
  predates the client patch, so it is a different crash from C-01.
- **Lesson:** an experiment setting with no recorded result stays forever. See "Open questions" in SKILL.md.

## C-03 · 2026-11-07 to 08 · The Windows launcher fix series (launcher 1 to 5)

The launcher shipped on 7 Nov (`bc98dc1`, PR #54). Seven fixes followed in two days.

| # | Date | Symptom | Root cause | Evidence | Launcher |
|---|---|---|---|---|---|
| 1 | 7 Nov | A friend outside the home network got "Unable to connect" | "the downloaded realmlist.wtf pointed at the home address"; the game reads `Data\<locale>\realmlist.wtf` over `Config.wtf`, and the host's own copy was being published | `eb1f8de`, PR #65 | 2 |
| 2 | 7 Nov | Window frozen ("Not responding") on the first check after an install | it "read all 43 GB" to verify files | `d025dc7`, PR #71 | 3 |
| 3 | 8 Nov | Wrong file dates in the manifest and on download | "Windows PowerShell read 'Utc' as milliseconds" in `[datetime]::new(1970, 1, 1, 0, 0, 0, 'Utc')` | `4168ff5`, PR #72 | (same) |
| 4 | 8 Nov | Progress maths failed on a full install | "46 GB total overflowed Math.Max's int overload" | `99f4fa7`, PR #73 | 4 |
| 5 | 8 Nov | Every launcher got a 404 on one file and stopped | IIS's own `web.config` was listed in the manifest; "IIS never serves it" | `c3b4125`, PR #74 | 5 |
| 6 | 8 Nov | The web.config fix was not on `main` | it was pushed to branch `launcher-date-fix` (`233669f`) after PR #72 had merged, so it "missed #72" and was redone as PR #74 | `12f7f93` | 5 |
| 7 | 8 Nov | Game kept an old server address when the site or an update failed | realm was only written on the success path | `9cb5609`, PR #74 | 5 |

- **Fixes in force:** files count as current "when size and modified time match the manifest"; the publish script
  skips `realmlist.wtf` and `web.config`; the launcher "keeps going past a failed file" and reports it at the end;
  the launcher always writes the realm address.
- **Tried and rejected:** verifying every file by reading it (row 2); publishing the client folder as it stands
  (rows 1 and 5).
- **Status:** fixed.
- **Lessons:** the publish script must skip files that belong to the host (its realm address, the web server's
  config). One bad file must not stop a 46 GB install. Row 6 is one of eight recorded cases of a commit pushed
  to a branch after its pull request had merged, and the only one whose commit message says so (see "Commits
  pushed after the merge" in `references/unmerged-and-abandoned.md`).

## C-04 · 2026-11-08 to 15 · Linux launcher and Steam

| Date | Symptom | Root cause | Evidence | Status |
|---|---|---|---|---|
| 8 Nov | Endless loading screen under Proton, then a disconnect | the client's `DivxTac.dll` "hangs the loading screen under Proton (endless load, then the 30 s packet watchdog disconnect)" | `f10cf9e`, PR #101 (Linux launcher 4) | worked around: the Steam launch options switch the DLL off |
| 12 Nov | Steam's Play button started the game without updating | the Steam shortcut ran the game directly | `fe32099`, PR #131 (launcher 5, `--steam-update`) | fixed |
| 15 Nov | Play from Steam did nothing | "Steam's %command% contains "--", which argparse treats as the end of options, so --steam-update exited with 'unrecognized arguments'" | `2bbf3d5`, PR #161 (launcher 6) | fixed: the flag is taken from the command line before argparse |

- **Lesson:** the fix of 12 Nov introduced the bug of 15 Nov. Anything placed before Steam's `%command%` has to
  cope with the `--` Steam inserts.

## C-05 · 2026-11-08 to 21 · Website and services

| Date | Symptom | Root cause | Evidence | Status |
|---|---|---|---|---|
| 8 Nov | "Recent changes" on the home page was wrong | "Windows PowerShell's top-level JSON array" was nested; the real error was not logged | `f9c3d54`, PR #81 | fixed |
| 8 and 12 Nov | Site page and status service line endings | the files must "keep CRLF line endings" | `e11ba2a` (PR #105), `07dc858` (PR #121) | fixed twice; the reason is not written in either commit |
| 13 Nov | Auctioneer and deleted test characters on the leaderboards | no filter | `b516c2b`, PR #135 | fixed |
| 21 Nov | Tameable pets page blank: "the world database did not answer" | the query asked for `creature.id1` ("newer AzerothCore; the base SQL files have it"), "while this core's world database calls it `id`" | `2563565`, PR #215 | fixed; failures now log MySQL's own message with a 60 sec timeout |
| 22 Nov | A port clash for the sign-up page was silent | "on Windows 'reuse address' is off so a clash is no longer silent" | `a3eb865` (branch `faster-settings`, **not on `main`**); the status board of `5dfb9a7` (PR #231) is on `main` | see U-05 in `references/unmerged-and-abandoned.md` |

- **Lesson (pets page):** an error message that says only "did not answer" hides the cause. Log the database's
  own error text.

## C-06 · 2026-11-20 to 21 · Client behaviour that needed a server or addon answer

| Date | Symptom | Root cause | Evidence | Status |
|---|---|---|---|---|
| 20 Nov | The Wildcard window refused Scroll of Fortune claims "with plenty owned" | the client "counts only the currency-token slots (checked in the client's own code: it sums item 375250 over the 32 currency slots), while its balance line counts bags too" | `b4f61e9`, PR #200; patch 82; `160-rune-currency.sql` | fixed: runes are moved into the currency tab |
| 21 Nov | Enchant collection window froze the game | every query "looked up all 6,440 enchants' names and info and sorted them" | `4fdb6a0`, PR #224 | fixed in the addon |
| 21 Nov | Damage meters show nothing | "A known 3.3.5 client bug: with many units around (hundreds of bots here) the combat log gets stuck" | `447b561`, PR #221 | worked around by a new addon |
| 21 Nov | Third-party addons (two were left out) | DBM-WotLK "is for the Wrath Classic client"; the Skada repository "is the Retail and Classic Skada" | `d509cf9`, `1bedcb1`, PR #220 | left out on purpose |

- **Lesson:** `docs/agents/context/patches.md` item 8: "the client has its own copy of some rules ...; a
  server-only change can leave the two disagreeing." The rune case is the clearest example on record.
