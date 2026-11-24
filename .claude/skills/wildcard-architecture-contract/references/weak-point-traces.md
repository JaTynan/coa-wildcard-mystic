# Weak-point traces: what the code does in each failure

Read this when you need to reason about what patch night, the build or the installer will do in a situation that has
gone wrong, or before proposing a change to any of them. Every trace is a reading of the scripts at `origin/main` `d3e030f` (the same files as in the PR #232 checkout `fcfee51`)
(22 Nov 2026). **None was reproduced on the VM**; treat each as a prediction to confirm, with the confirming
observation named.

Any change to these scripts is a hard stop: classify with `wildcard-change-control` first; James merges.

## T1. How patch night decides what is installed (background for T2 to T5)

Three files in `C:\Games\CoA Server\Core` carry the state:

| File | Written by | Meaning |
|---|---|---|
| `worldserver.official.exe` | The installer, whenever the live program is not one of ours (`Install-WildcardServer.ps1:64-71`) | The manager's own world server, as last seen. |
| `worldserver.patched.txt` | The installer (`:86`) | The hash of the patched program it installed. |
| `worldserver.patched-release.txt` | Patch night after a successful install (`PatchNight.ps1:964`) | The build tag, for example `wcme-server-0.261119.114-build70`. |

`OfficialExe` (`PatchNight.ps1:92-97`) says "the live program is ours" when the hash in `worldserver.patched.txt`
equals the hash of `worldserver.exe` and the saved official copy exists. Everything below follows from that test.

## T2. A build that starts but is broken in play (W1)

- The build passes if it compiles, links and `worldserver.exe --version` exits 0 (workflow lines 276-283).
- The installer passes if `--version` works on the VM (`Install-WildcardServer.ps1:81-85`).
- `StartAndCheck` passes when `Server.log` contains "World Initialized In", line 1 shows the expected core revision,
  and the process still exists 60 seconds later (`PatchNight.ps1:706-727`).

So a patch that crashes on the first player login, breaks a spell, or misbehaves only with bots awake passes every
gate and the run ends `[OK] Patch night OK`. Confirm by: nothing; this is the absence of a check. The crash folder
(`Core\Crashes\`) and `Errors.log` are where it would show afterwards (`docs/agents/context/patch-night.md`).

## T3. A broken SQL file on `main` (W4)

`ApplyEnchantFixes` (`PatchNight.ps1:350-366`) runs each file as one `mysql --batch` call. `mysql` stops at the first
error in a file, so the rest of **that file** is skipped; the loop then logs
`[WARN] Enchant fix <file> failed: <message>` and goes on to the next file. The server starts regardless.

Because `000-reset.sql` already removed every owned row, the failed file's fixes are simply absent until the file is
repaired and the server restarts. The run's last line still says OK.

Confirm by: `Select-String -Path patch-night.log -Pattern 'Enchant fix .* failed'` on the VM.

Proposed practice (not yet adopted by James): have the patch-night checker treat any "Enchant fix ... failed" line as
PROBLEM. Purpose: a silent partial apply is otherwise invisible. Motivating incident: none recorded in the repo; this
is from the code.

## T4. A fall-back to the official server, and the days after (W7)

1. The patched server fails `StartAndCheck`. Lines 979-986: stop everything, copy `worldserver.official.exe` over
   `worldserver.exe`, delete `worldserver.patched.txt` and `worldserver.patched-release.txt`, start again, finish with
   "Patch night FAILED on the patched server; the official server is running instead (no Mystic Enchants)".
2. Next 3:30 am run (daily since 23 Nov 2026): the live program is no longer ours, so the installed tag reads as
   empty (line 869). The release still exists, so `installNeeded` is true, the **same** release is installed again,
   and step 1 repeats unless a newer build was published in between. Nothing records that a build was bad. With the
   daily task this is one failed start (up to 30 minutes of checking) and one fall-back **every night**.
3. Before 23 Nov the nightly run had `-NoInstall` (line 875): it kept the official server and ended "Patch night OK:
   official server (no patched build yet)" (line 975), which was misleading, and only Tuesday's run retried the bad
   build. A run given `-NoInstall` by hand still behaves that way.

While the official server runs: Wildcard characters have no Mystic Enchants, and every setting and `wcme_*` table
our patches read is ignored. Rows our SQL binds to `spell_wcme_*` script names point at scripts the official program
does not have. What the official server logs about those is UNVERIFIED (check `Errors.log` after such a start).

`Start-Server.cmd` (`-StartOnly`, lines 816-830) has no fall-back: if the server does not come up it says so and
stops.

## T5. The manager's Update button, then the next patch night (W5)

The script's own comment (lines 842-843): a manager update keeps a world server it sees was changed (ours), so the
saved official copy goes stale. The auth server is always the manager's own, so its revision is trusted.

Suppose the manager moved from core A to core B and kept our patched program (built for A):

1. `OfficialExe` returns the saved copy (core A). The auth server reports B. They differ, so `$installed = B` and
   `$staleOfficial = $true` (849-854).
2. Next run. If a build for B exists, it is installed (with `-Force`, because the saved copy is stale, line 958) and
   the run normally ends OK: this is the common case since patch night installs every night (23 Nov 2026). The rest
   of this trace is the case where **no build for B exists yet**. `$expected` is B (lines 951, 969-971).
3. `StartAndCheck B`: the live program is still the A build. `Server.log` line 1 shows A. "The server came up on
   core A, expected B" and the function returns false (716-718). It does not stop the server it just started.
4. Fall-back (980-986): stops, copies the saved official program (core A, stale) over the live one, starts, and
   checks for B again. It fails the same way. Last line: "Patch night FAILED: the server is not up", although a
   world server from core A may in fact be running against databases the manager updated for B.

Whether a core-A program starts at all against core-B databases is UNVERIFIED and depends on what the update changed.

What would avoid it, from the code (a prediction to confirm, not observed). **Proposed practice (not yet adopted by
James):** press Update in the manager only after the build workflow has published a release for the new manager
release. The workflow builds a release with no build yet by itself (step `decide`, "has no build yet"), in the
evening run after the release appears, and a build takes about 3½ hours. Purpose: avoid nights that end FAILED.
Incident: none recorded. With that order, README's wording (the Update button "stays manual: click it any time
before patch night and the new release is picked up") holds (SKILL.md, V12).

History: the stale-copy detection was added in f83171d (PR #29, 1 Nov), "catch a manager update that kept the patched
world server". README still says the official server "comes back on its own" after a manager update; the script is
the newer statement.

## T6. Which release gets installed (W6)

Lines 859-864: the script asks GitHub for the 50 newest releases and takes the **first** one that is not a draft and
whose notes contain `Core: <repository> <40-hex commit>` starting with the installed revision. GitHub lists releases
newest first, so that is the newest build for this core.

Nothing looks at which branch or commit of this repository the release was built from, although the notes carry it
("This repository: ..."). The workflow accepts a manual run from any branch and always publishes. Consequences:

- A test build started from a feature branch becomes the build the next 3:30 am patch night installs.
- To keep a build from being installed, its release has to be deleted or marked as a draft; a newer good build also
  wins. **James only** (hard stop 5: this decides what patch night installs, and it is an action on GitHub outside
  any PR). A session does not do this without his say-so.
- Among the 40 release tags fetched on 22 Nov, one was built from a commit not on `main`:
  `wcme-server-0.261028.83-build20`, from `for-083`, which was that branch's purpose.

Proposed practice (not yet adopted by James): only start the build workflow from `main`. Purpose: keep "what is on
`main`" and "what patch night installs" the same thing. Motivating incident: none yet; the `for-083` period showed the
mechanism works for any branch.

## T7. `main` as the deploy branch (W3)

- `FetchRepo` downloads `https://github.com/<repo>/archive/refs/heads/main.zip` on every run, including
  `Start-Server.cmd` runs (line 743 runs it for every mode).
- New `patch-night/*.ps1` files replace the current ones if **all** of them parse (325-336). The running script then
  compares its own hash and, if it changed, starts the new copy with the same switches and exits (742-754).
- New `server-settings/*.ps1` files are taken one by one if each parses (230-238).
- `signup/` is copied and its scheduled task restarted (315-324); Python files are not parse-checked.
- `launcher/` is copied and published to the site after the start; friends' launchers replace themselves when
  `launcherVersion` is higher than their own (`WildcardLauncher.ps1:267`).

A script that parses but is wrong runs unattended at 3:30 am with James's rights on the VM. If GitHub cannot be
reached, the local copies are used and the run goes on (line 339, WARN).

## T8. What the settings kit will and will not do

- It only sets what the list names. A key the list does not name keeps whatever the file has, including a hand edit
  (`Apply-ServerSettings.ps1:208-231`).
- A key missing from the file is appended; a key present more than once has every copy set (221-227).
- `worldserver.conf` and `authserver.conf` are written twice: the manager's template in `Settings\` and the live copy
  (55-61).
- If the manager has another realm active, nothing is applied and the script exits 1 (192-201). Patch night logs
  "Applying the settings reported a problem" as WARN and still starts the server.
- It reports settings the installed server does not know (compared with the `.dist` files and with the names found
  inside `worldserver.exe`) to `server-settings\settings-report.txt` (250-306). Patch night appends the server's own
  "Missing property" and "Bad value" warnings (`PatchNight.ps1:668-682`).
- `realmlist | ...` and `realm | ...` lines are not config settings; patch night writes the realm address into the
  auth database after each start (`RestoreRealmAddress`, 611-666).

## T9. What the reset does and does not own

From `sql/enchants/000-reset.sql` and the static check:

| Kind of row | Marker | Removed by the reset |
|---|---|---|
| `spell_linked_spell` | `comment LIKE 'WCME:%'` | Yes |
| `spell_dbc`, `spell_proc` | id listed in `wcme_owned` | Yes, if listed (seven `spell_proc` ids are not: V4) |
| `coa_mystic_enchant_aura_link` | id listed in `wcme_owned` as `aura_link` | Yes |
| `spell_script_names` | `ScriptName LIKE 'spell\_wcme\_%'` | Yes |
| `wcme_enchant_teach`, `wcme_enchant_override`, `wcme_proc_target_cooldown`, `wcme_enchant_action`, `wcme_spellaffect_dbc` | Whole table is ours | Emptied |
| `wcme_owned` itself | | Emptied last, then refilled by the files that follow |
| One-off backups `wcme_backup_spell_linked_spell`, `wcme_backup_spell_proc` | Created the first time only | Never restored automatically |
| Anything else (loot, items, vendors, `spell_area`, currency rows, MySQL variables, core rows changed in place) | None | **No** (V3) |

The reset runs against the **world** database of the active realm only (`ApplyEnchantFixes` reads `WorldDatabaseInfo`).
Tables the patched server creates in the characters database (`wcme_world_pvp_kills`, `wcme_server_firsts`,
`wcme_prestige_legendary`, `wcme_profession_mastery`) hold player progress and are never touched by it.
