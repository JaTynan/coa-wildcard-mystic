---
name: wildcard-architecture-contract
description: START HERE when new to James's Wildcard WoW server project (coa-wildcard-mystic). The whole system on one page (GitHub repo, Actions build, releases, the Windows VM, CF-Server-Manager, world and auth servers, MySQL, patch night, settings kit, SQL fixes, addons, client patch, launcher, site, sign-up and status services, Ollama bot chat), the load-bearing design decisions and why they were made, the numbered invariants that must keep holding with a check for each (check_contract.py), known violations and weak points with severity, and a decision table for which layer a change belongs in. Load it when asked "I am new, where do I start", "how does this all fit together", "which layer does this belong in", "why is it built this way", "is it safe to change how patch night, the build, the SQL reset or the settings kit works", or before designing or reviewing a change that crosses layers. Not a how-to for any single layer; for the date a merged change goes live, load wildcard-run-and-operate.
---

# Wildcard architecture contract

What the system is, why it is shaped this way, and what must stay true. Read it before you change anything that
touches more than one layer. Facts are from the checkout at `fcfee51` (PR #232's head: `62a26e4`, the #230 merge,
plus two commits adding `.claude/agents/` and `docs/agents/`) and `origin/main` `d3e030f` (#231, which differs only
under `signup/`), on 22 Nov 2026, unless a line says otherwise. Nothing here was re-checked on the live VM on 2026-11-22; every claim about the VM comes from the scripts
that run there.

**Before changing server behaviour: classify with `wildcard-change-control` first. James merges.** Changes to patch
night, the build workflow, the installer or rollback are a hard stop (always HIGH, never automatic;
`docs/agents/context/change-risk.md`, hard stop 5). `docs/agents/*` and `.claude/agents/*` exist only in PR #232:
what rests on them is **INTENDED DOCTRINE (PR #232, unmerged on 2026-11-22)**; on `main` read them with
`git show origin/agents-stage-1:<path>`. Status words are defined in `wildcard-change-control`, section 1.

## When NOT to use this skill

| You need | Use instead |
|---|---|
| To decide whether a change may go ahead, its risk class, who merges | `wildcard-change-control` |
| A symptom looked up, or a failing build, start or patch night diagnosed | `wildcard-debugging-playbook` |
| The story of a past investigation, revert or dead end | `wildcard-failure-archaeology` |
| How AzerothCore or CoA works inside (spells, procs, hooks, the databases, bots) | `azerothcore-coa-reference` |
| To restore an enchant or write an enchant SQL file | `ascension-restoration` |
| A setting's name, default, file or the checklist for adding one | `wildcard-settings-and-flags` |
| The build step by step, how to trigger or watch it, build failures | `wildcard-build-and-env` |
| To write or port a patch script, or pre-flight anchors without a build | `wildcard-patch-authoring` |
| To run, restart, roll back or inspect the server; the VM file map | `wildcard-run-and-operate` |
| To measure something (logs, counters, timing) | `wildcard-diagnostics-and-tooling` |
| What counts as tested; how to add a check or a smoke test | `wildcard-validation-and-qa` |
| Doc templates, house style, what may be published | `wildcard-docs-and-publishing` |
| Launcher, site, sign-up, client patch and addon how-to | `wildcard-client-and-web` |
| The lag spike investigation | `wildcard-lag-spike-campaign` |
| Analysis method or open research problems | `wildcard-analysis-and-method`, `wildcard-frontier` |

## Start here

1. New to the project: read section 2 (the system on one page), then section 3 (how a change reaches a player).
2. Deciding where a change belongs: section 8, first row that fits.
3. About to change patch night, the build, the SQL reset or the settings kit: sections 4 to 7, then run
   `python3 -I .claude/skills/wildcard-architecture-contract/scripts/check_contract.py` (exit 0 = no new FAIL).
4. Then classify with `wildcard-change-control`. James merges.

## 1. Words used here

| Word | Meaning |
|---|---|
| CoA | Conquest of Azeroth, a fork of AzerothCore (an open-source World of Warcraft 3.3.5a server). Not ours. |
| The manager | CF-Server-Manager, a Windows app by Corfirean that installs and updates a CoA server, its MySQL and its configs. Not ours. |
| Manager release | One version of the server the manager installs, named like `server-0.261119.114`. It fixes the exact commit of every part. |
| Core | The server's C++ source at one commit. "Core c3f2fd4b" means that commit of `Corfirean/azerothcore-wotlk-coa`. |
| Official server | The `worldserver.exe` the manager installed. Kept on the VM as `Core\worldserver.official.exe`. |
| Patched server | Our build of the same core with `patches/` applied. It replaces `Core\worldserver.exe`. |
| Realm | One game world with its own databases. This server runs the Wildcard realm (realm id 2). |
| Patch night | `patch-night/PatchNight.ps1`: the one script that updates, configures, starts and checks the server on the VM. |
| Anchor | The exact piece of upstream source text a patch script looks for before it edits. |
| WCME | Our ownership prefix ("Wildcard Mystic Enchants") on database rows, tables and script names. |

Any other term: `.claude/skills/azerothcore-coa-reference/references/glossary.md`.

## 2. The system on one page

```
 UPSTREAM (not ours, pinned per manager release)        GITHUB: JaTynan/coa-wildcard-mystic (PUBLIC)
 Corfirean: core, CoA bots, content scaling,            main branch = what the VM runs tonight
            coa-server-build (module patches)                |                     |
 Zyth45:    mod-playerbots (SQUID), mod-dungeon-clear        | patches/            | everything else
 DustinHendrickson: mod-ollama-chat (pinned by us)           v                     |
        \____________________________________    Actions: "Build patched worldserver"
                                             \-> (windows-latest, 2-3 h, cron 03:17 UTC or by hand)
                                                  resolve_release.py -> *.patch -> modules -> *.ps1
                                                  -> cmake/ninja -> worldserver.exe --version
                                                         |                         |
                                              Release wcme-<release>-build<N>      | main.zip
                                              (zip: worldserver.exe, Install.cmd)  | (downloaded whole)
                                                         |                         |
 ==================== WINDOWS 11 VM  C:\Games\CoA Server   F:\CoAClient ============================
  Scheduled tasks (run as James, only while he is signed in):
    "CoA Nightly Restart"  daily 3:30 am, restart 4:00 am   PatchNight.ps1 -Unattended -NoInstall
    "CoA Patch Night"      Tuesday 11:00 pm                 PatchNight.ps1 -Unattended   (installs builds)
    (times are Register-PatchNight.ps1's defaults; what the VM has registered is UNVERIFIED)
  PatchNight.ps1
    FetchRepo        main.zip -> settings kit, addons, pinned third-party addons, SQL, launcher+site,
                     ollama-chat files, sign-up service, and the patch-night scripts themselves
    Install-WildcardServer.ps1   (weekly only) swaps Core\worldserver.exe, keeps worldserver.official.exe
    Apply-ServerSettings.ps1     server-settings.txt -> Core\configs\*.conf (+ Settings\*.template)
    launcher_bridge.py           -> the manager's Scripts\manage.py: start-mysql, start-all, stop-all, ra-once
    mysql.exe                    sql/enchants/*.sql -> world DB (every start); AI chat tables -> characters DB (once)
    Publish-WildcardSite.ps1     -> F:\wildcard-site: manifest.json, launcher.json, changelog.json, pages
  MySQL:  acore_auth (accounts, realm list) | acore_world_wildcard | acore_characters_wildcard
  authserver.exe (always the manager's own)     worldserver.exe (ours) --HTTP--> Ollama on another machine
  IIS :8088  site at /, F:\CoAClient at /client/          WildcardSignup.py :8089 (task "Wildcard Sign-up"):
                                                           join page, /api/status, /api/pets, bug report relay
 =====================================|=============================================================
                   Cloudflare tunnel: wildcard.jtlab.cc (site), join.jtlab.cc (sign-up)
                                      v
  FRIENDS' PCs:  WildcardLauncher.ps1 (Windows) / .py (Linux) -> syncs client folder from manifest.json,
                 sets the realm address -> game client -> login server -> Wildcard realm (+ ~750 bots)
```

Component list with the file that defines each one:

| Component | Where it is defined | Ours? |
|---|---|---|
| Build | `.github/workflows/build-worldserver.yml`, `scripts/resolve_release.py` | Ours |
| Code patches | `patches/*.patch` (5), `patches/NN-name.ps1` (56) | Ours |
| Installer and restore | `vm/Install-WildcardServer.ps1`, `vm/Install.cmd`, `vm/Restore-Official.cmd` | Ours |
| Patch night and nightly restart | `patch-night/PatchNight.ps1`, `Register-PatchNight.ps1`, `Start-Server.cmd`, `Run-PatchNight-Now.cmd`, `Rebuild-WildcardBots.cmd` | Ours |
| Bridge to the manager | `patch-night/launcher_bridge.py` | The manager's file (AGPL-3.0) plus one marked Wildcard addition |
| Settings kit | `server-settings/server-settings.txt` (273 lines: 270 settings plus the `realm` and two `realmlist` lines), `Apply-ServerSettings.ps1` | Ours |
| SQL fixes | `sql/enchants/*.sql` (64 files, `000-reset.sql` first) | Ours |
| Addons | `addon/Wildcard*` (3 of ours), `addon/third-party-addons.txt` (11 pinned, code not kept here) | Mixed |
| Client patch | `client-patch/*.py` builds `patch-ZZW.MPQ` from the client's own files; the result is never committed | Builder ours, data not |
| Launcher, site, manifest | `launcher/` | Ours |
| Sign-up, status, pets, bug report relay | `signup/` | Ours |
| AI chat for bots | `ollama-chat/` (config template and tables of the pinned commit), `patches/10-mod-ollama-chat-fit.ps1` | Module not ours |
| The three databases | Auth is shared (`acore_auth`); world and characters are per realm (`acore_world_wildcard`, `acore_characters_wildcard`; the CoA realm's are `acore_world`, `acore_characters`) | The manager creates them |

Realm ids in the realm list are coa 1, wildcard 2, reborn 3 (`PatchNight.ps1:647`).

## 3. From a merged pull request to a player's screen

There are four speeds. Know which one your change is on before you promise anyone a date. The one table of what
goes live when, with times, sources and the log line that proves it: `wildcard-run-and-operate`, "When does my
merged change go live?". In two lines: settings, SQL, addons, site, sign-up and patch-night scripts arrive at the
next restart (a merged `PatchNight.ps1` runs that same night); C++ arrives only after a build that contains it
(the daily build makes each manager release once, so a run with **rebuild** ticked is needed) and then the weekly
patch night. Two rows that table may not carry, kept here because they are architecture:

| Layer | Goes live when | Check it arrived |
|---|---|---|
| **Client files** (addons, `patch-ZZW.MPQ`, anything in `F:\CoAClient`) | After the server start that follows the file landing in `F:\CoAClient`: patch night republishes `manifest.json`; each friend's launcher fetches the differences the next time they open it. Addons are copied by `FetchRepo`; the client patch is built and copied into `F:\CoAClient\Data` **by hand** (`docs/enchant-restoration.md`, "Client patch"). | `F:\wildcard-site\manifest.json`; the friend's `launcher.log`. |
| **Launcher itself** (`launcher/WildcardLauncher.ps1`, `.py`) | As client files, but only if its version number was raised (`$LauncherVersion`, `LAUNCHER_VERSION`); the launcher updates itself only to a higher number. | `launcher.json` on the site. |

Two consequences people get wrong:

1. **A fix that needs both a patch and SQL goes live in two steps.** The SQL arrives the next morning; the C++ arrives
   only after a build and the weekly patch night (or a manual run). Write the SQL so the *old* build ignores it. The repo does this
   already: tables "read by the patched world server ... Servers without the patch ignore it" (`000-reset.sql`).
2. **`CHANGES.md` describes `main`, not the running server.** A row there can be merged but unbuilt (see Known
   violations, V1).

What one patch night run does, in order (`PatchNight.ps1`, main path from line 832):

1. `FetchRepo`. If that brought a newer `PatchNight.ps1`, the script restarts itself as the new copy (lines 742-754).
2. Reads the installed core from the official server's `--version`, cross-checked against `authserver.exe` (838-854).
3. Picks the newest GitHub release whose notes name that core (856-867).
4. Announces the restart in game, then prepares **while the server is still up**: downloads and unpacks the build,
   writes the settings (888-932).
5. Stops only the world server (`StopWorld`, line 153); MySQL and the auth server keep running.
6. Only when run without `-NoInstall` (Tuesday, or by hand) and a new build exists: runs the installer, then the
   settings again so the list has the last word (951-968).
7. `StartAndCheck` (694-734): `start-mysql`; refuses to go on if the config points at the wrong realm's databases;
   runs every SQL file; `start-all`; restores the realm address; waits for "World Initialized In" in `Server.log`
   from the expected core; checks the process is still alive 60 s later; then publishes the site.
8. If that fails and the patched server was live: copies the official server back and starts that (979-988).

For the function-by-function runbook use `wildcard-run-and-operate`.

## 4. Load-bearing decisions and why

Each of these holds something up. Do not undo one without reading its reason.

| # | Decision | Why | Evidence |
|---|---|---|---|
| D1 | **Layers, re-applied every time.** Nothing is edited by hand on the running server; each change lives in the repo and is laid back on top of CoA's files at every build or start. | The manager rewrites configs and a CoA update replaces code and data. A hand edit would vanish without anyone noticing. Re-applying makes the repo the single description of the server. | `CHANGES.md` lines 3-12 |
| D2 | **Build from the manager release's exact commits, with the same build settings.** | The patched program must be the manager's program plus our patches and nothing else, or the databases the manager set up will not match it. `resolve_release.py` stops if a part comes from an unexpected repository or a module patch has no checksum. | `scripts/resolve_release.py:55-87`; workflow lines 83-169, 251-266; README "Nothing else changes" |
| D3 | **Patches are anchored edit scripts that fail loudly**, not a fork of CoA. | A fork needs merging at every CoA update. A script that cannot find its anchor stops the build and names itself, which is how an upstream change announces itself. | `docs/agents/context/patches.md`; header of every `patches/NN-*.ps1`; workflow step "Apply our patches" throws "no longer fits release" |
| D4 | **SQL is re-applied at every start, after `000-reset.sql` removes what we own.** | The database always equals the repo: delete a file and its fix is gone after the next start. No migration history to keep. | README "Mystic Enchant fixes (SQL)"; `sql/enchants/000-reset.sql`; `PatchNight.ps1:350-366` |
| D5 | **Ownership markers**: `WCME:` comments on `spell_linked_spell` rows, the `wcme_owned` table for `spell_dbc`, `spell_proc` and aura-link rows, the `spell_wcme_` prefix on script names, `wcme_*` tables emptied and refilled. | The reset can only remove what it can recognise. Without a marker it would have to guess which rows are CoA's. | `000-reset.sql` |
| D6 | **Settings come from one list, written at every start.** | The manager rebuilds `worldserver.conf` from its template, so settings are written to both. One list means one place to read what the server is set to. The list is tied to one realm and refuses to apply to another. | `Apply-ServerSettings.ps1:10-12, 55-61, 192-201` |
| D7 | **The installer refuses a build made for a different core** (unless `-Force`). | A world server from another core does not match the databases. | `vm/Install-WildcardServer.ps1:73-79` |
| D8 | **Keep the official server and fall back to it** if the patched one does not come up. | Players get a working server without Mystic Enchants instead of no server. | `Install-WildcardServer.ps1:64-71`; `PatchNight.ps1:979-988` |
| D9 | **Staged patch night: prepare during the countdown, restart only the world server.** | Downloading, unpacking and writing settings no longer count as downtime; MySQL keeps its cache warm. If preparing fails the restart is called off and the server stays up. | commit 759c7b6 (22 Nov); `PatchNight.ps1:153-163, 888-932`, `Finish` lines 68-79 |
| D10 | **Missing and dud enchants are filtered at start-up from the server's own data, not from a list.** | A list goes stale. Computed at start, an enchant comes back by itself the restart after its spell is added or given behaviour. | README; PR #15 (cf8c837), PR #17 (d746df2); now inside `patches/mystic-enchants-wildcard.patch` |
| D11 | **Client data is never committed.** The client patch is built from the builder's own client files; third-party addons are pinned downloads, not copies. | The repository is public and the game data is not ours to publish. | `client-patch/build_client_patch.py` docstring; `addon/third-party-addons.txt` header; `docs/agents/README.md` last paragraph |
| D12 | **`mod-ollama-chat` is pinned to one commit** (`906eb2a`), while everything else follows the manager release. | It is not part of the manager's release, so nothing else fixes its version. A patch script anchors on its text and its table files are not safe to run twice, so it must not move by itself. | workflow lines 171-176; `ollama-chat/README.md`; `PatchNight.ps1:368-406` |
| D13 | **SQUID's bots are on for Wildcard, which the manager does not support.** The manager's own Start button switches both bot systems off on Wildcard; `Start-Server.cmd` and patch night start the server through the bridge without that step. | The world is meant to feel populated (about 750 bots). | README "SQUID's bots on Wildcard"; `server-settings.txt:409-412` |
| D14 | **Start and stop go through the manager's own launcher script** (`launcher_bridge.py` running `Scripts\manage.py`), not our own process handling. | The server is started exactly as the manager would start it, so the manager keeps working beside us. | `PatchNight.ps1:117-120`; `launcher_bridge.py` header |
| D15 | **A start never opens the wrong realm's databases.** | From release 0.261119.114 the manager's script writes the default databases into the config whatever realm is active. Opening the CoA realm's characters as Wildcard would be data damage. | PR #186 (d5412a9); `launcher_bridge.py:37-63`; `PatchNight.ps1:446-459` |
| D16 | **Patch night updates itself from `main`, but only with scripts that parse.** | James edits on GitHub and it applies that night; a typo merged during the day must not take the server down. | `PatchNight.ps1:165-169, 325-336` |
| D17 | **A Windows VM under the manager, not a native Linux server.** Reasoning inferred from the repo; James has not written the reason down. | The project is defined as "the world server the CF-Server-Manager installs, plus one change". The manager does installs, updates, databases, realms and backups; we replace one program file. The roadmap keeps a native Linux build only as a fallback for a test server. | README first paragraph; `docs/roadmap.md` item 1 |
| D18 | **Secrets live only on the VM** (`signup-settings.json`, optional `launcher-secret.json`). | Public repository. | `signup/README.md`; `.gitignore` |

## 5. Invariants

Each is a statement you can test. "Static check" means
`python3 -I .claude/skills/wildcard-architecture-contract/scripts/check_contract.py` from any folder (reads only;
tested 2026-11-22). Its output tags each line with the invariant number.

| # | Invariant | How to check | 2026-11-22 |
|---|---|---|---|
| I1 | `main`'s patches fit the newest manager release. | `python3 -I scripts/resolve_release.py latest` for the pinned commits, then for the `.patch` files `git apply --check` in name order on a clean core at `core_sha`. For the `.ps1` anchors use the pre-flight in `wildcard-patch-authoring`. Final proof is a green build. | `.patch` files: hold (applied in order to core c3f2fd4b). `.ps1`: 55 of 56 proven by build 70; `96-` never built (V1). |
| I2 | Patch scripts run exactly once, on a clean tree, in name order, and each stops the build when an anchor is missing. | Static check. The order is `Sort-Object Name` in the workflow (lines 96 and 182). `.patch` files run first and can only touch the core, because the modules are checked out after them. | Holds. 6 scripts never check "exactly once" (W9). |
| I3 | Every file in `patches/` has a row in `CHANGES.md`, and the docs name no patch that is gone. | Static check. | `CHANGES.md` holds. README violated (V2). |
| I4 | Every setting a patch reads is in `server-settings.txt`. | Static check (71 names read literally; 8 names built at run time are listed for a check by eye). | Holds. |
| I5 | `server-settings.txt` has one line per setting per file and names its realm. | Static check. | Holds (273 lines: 270 settings plus `realm` and two `realmlist`; no repeats). |
| I6 | SQL files run in name order with `000-reset.sql` first, and every file can run at every start. | Static check for order. Re-runnability needs MySQL: run the folder twice against a copy of the world database and compare. | Order holds. Re-run: UNVERIFIED here (no database). |
| I7 | Every row our SQL adds or changes is put back by `000-reset.sql` when its file is deleted. | Static check. | Violated in known ways (V3-V5). |
| I8 | The repository contains no client data. | Static check (no game binaries, no archive link). Text needs a human: see V7. | Binaries hold. V6, V7, V8 open. |
| I9 | The repository contains no secrets. | Static check (token shapes only; it cannot recognise every secret). | Holds. |
| I10 | Third-party code is pinned to a full commit. | Static check. | Holds for `mod-ollama-chat` and the 11 addons. Actions are pinned by tag only (W12). |
| I11 | Our own spells exist identically on both sides: client (`client-patch/custom_spells.py`) and server (`150-custom-spells.sql`). | Static check compares the id sets. Field equality: `python3 -I client-patch/custom_spells.py \| diff -q - sql/enchants/150-custom-spells.sql` (the usage line names a `<Spell.dbc>` argument the code does not read; no client file is needed). | Ids hold (68 each). Fields hold (output identical to file 150 on 2026-11-22). |
| I12 | Every release patch night can install was built from `main`; `for-083` and `main` are never merged into each other. | Static check. | Holds today. One old release was built from `for-083` (W6). |
| I13 | The patched server is only ever installed over the core it was built for, and the official copy is kept. | On the VM: `Core\worldserver.official.exe` exists; `worldserver.official.exe --version` shows the same revision as `Server.log` line 1. | From the code. Not re-checked on the VM. |
| I14 | Every patch commit on `main` is in a published build. | Static check (compares `main` with the newest `wcme-server-*` tag). | Violated (V1). |
| I15 | A start opens the active realm's databases only. | `patch-night.log` line "Databases: world acore_world_wildcard, characters acore_characters_wildcard." after each start. | From the code. Not re-checked on the VM. |
| I16 | Whatever is on `main` at 3:30 am is safe to run on the VM unattended. | No automatic check exists beyond "the PowerShell parses" (D16). This is the invariant change control exists to protect. | Cannot be proven; see W1, W4. |

## 6. Known violations as of 2026-11-22

Found by running the static check on the checkout of 2026-11-22 (it prints these as KNOWN, and exits 1 only for a
FAIL that is not on its known list). None of these is an emergency. Fixing any of them changes the
repository or the server, so classify with `wildcard-change-control` first.

| # | What | Detail | Suggested handling |
|---|---|---|---|
| V1 | One patch is merged but in no build. | `patches/96-bots-ignore-commands.ps1` (commit 13a03d3, PR #228, 21 Nov) came after build 70 (tag at 3aa3d99). Its `CHANGES.md` row and its setting `OllamaChat.BlacklistCommands` are already on `main`; the running server ignores the setting. The daily build will not pick it up, because release .114 is already built. | A workflow run with rebuild ticked (`wildcard-build-and-env`). A finished build is a release the weekly patch night will install, so James starts it or says go (hard stop 5 territory). This state is normal between a merge and a build; it is a violation only if nobody knows. |
| V2 | README names a patch file that no longer exists. | `patches/mystic-enchants-skip-missing.patch` was folded into `mystic-enchants-wildcard.patch` in f83171d (PR #29). | Doc fix (`wildcard-docs-and-publishing`). |
| V3 | Some SQL files change things `000-reset.sql` cannot put back. | The one list, verified file by file, lives in `ascension-restoration` (SKILL.md section 5 item 3, and `ascension-restoration/references/reset-limits.md`). Three groups: (a) outside the reset's tables, 8 files: `090`, `095` (`SET PERSIST`, server-wide), `100`, `110`, `120`, `130`, `160`, `161`; (b) a core row changed in place: `026`; (c) core rows removed, or replaced by a row we own, so deleting the file does not bring the stock row back: `027`, `140`, and rows in `005`, `018`, `020`. `013` is not one. `check_contract.py` prints (a) and (b) as a KNOWN line and what it can see of (c) as an INFO line. | The rider files say they "ride along" on purpose. Treat the rule as "enchant rows are resettable; rider files and replaced core rows are one-way" until James decides otherwise. To undo one, write the reverse statement in a new file. |
| V4 | Seven `spell_proc` rows are written without an entry in `wcme_owned`. | Files `005` (282040, 285100), `007` (276302, 979137), `017` (1587050), `020` (1180480), `038` (1544910). `enchants/core-proc-row-replacements.csv` records several as "core row restored", so these writes put CoA's own row back on purpose. | Leave as is; know that deleting the file does not remove the row. |
| V5 | Two files delete script bindings by spell id with no name filter. | `015` (24 spell ids) and `016` (31) run `DELETE FROM spell_script_names WHERE spell_id IN (...)`. If CoA binds a script of its own to one of those spells, it is removed at every start and nothing restores it (the one-off backups cover `spell_linked_spell` and `spell_proc` only). Whether any of the 55 has a core binding today is UNVERIFIED (needs the live world database: `SELECT * FROM spell_script_names WHERE spell_id IN (...) AND ScriptName NOT LIKE 'spell\_wcme\_%'` on a database where the two files have not run, or the core's SQL at the pinned commit). | Candidate fix: add `AND ScriptName LIKE 'spell\_wcme\_%'`, as files `040`-`048` already do. |
| V6 | A never-expiring share link to the whole client archive is committed. | A share link in `launcher/launcher-settings.json`. The repo holds no client data, but it publishes where to download all of it. `launcher/README.md` says the site is not behind a login either. | James's call. The launcher already supports a Cloudflare Access token (`launcher-secret.json`). |
| V7 | Rebuilt spell rows carry description text. | `009` and `011` hold about 1,200 `spell_dbc` rows built "from the archived Ascension description" (`docs/enchant-restoration.md`), with long text in roughly 860 and 337 string fields (four more rows in `012`/`013`). The written rule is "no verbatim client tooltip text" (`docs/agents/context/patches.md`). Whether rebuilt rows from the archived builder page count is not written down anywhere. | OPEN: ask James to rule; record the ruling in `wildcard-docs-and-publishing`. Do not add more until then: new SQL leaves description columns empty or paraphrases (`ascension-restoration`, recipes R2 and R8). |
| V8 | Three compiled Python files are tracked. | `launcher/__pycache__/*.pyc`, `signup/__pycache__/*.pyc`, although `.gitignore` lists `__pycache__/`. Harmless, but `FetchRepo` copies them to the VM. | Remove from the index in a housekeeping PR. |
| V9 | Doc and practice disagree on batching. | `CHANGES.md` ("How changes are made") says changes go in as one PR per patch night. History: 205 merged PRs on 22 days, up to 31 in one day (8 Nov). | Not resolved here. `wildcard-change-control` owns it. |
| V10 | README's Branches section is stale. | It calls `for-083` "the build branch for the server's current core (release .83)". Builds 57 to 70 were made from `main` for release .114, and `for-083` last moved on 9 Nov. | Doc fix; the "never merge" rule still stands. |
| V11 | README and the script disagree about manager updates. | README: "After a manager update the official server comes back on its own." `PatchNight.ps1:842-854`: a manager update keeps a world server it sees was changed. The script is newer (PR #29). | Trust the script; fix the README. See W5 for what follows from it. |
| V12 | README and the code trace disagree on when to click Update. | README: the Update button "stays manual: click it any time before patch night and the new release is picked up". The trace in W5 predicts a nightly restart between the click and the weekly patch night ends FAILED. Not observed. | Ask James; see W5 for the proposed practice. |

## 7. Known weak points

Severity: **High** = can take the server down or expose something, with no automatic guard. **Medium** = costs
hours or misleads. **Low** = untidy. Severity is about outage and exposure, **not priority**: James's order of work
is lag first, then pipeline, testing and validation, then enchants. The code traces behind W3 to W7 are in
[references/weak-point-traces.md](references/weak-point-traces.md); read that when you need to reason about what
patch night does in a failure.

| # | Weak point | Severity | Detail |
|---|---|---|---|
| W1 | No automated tests. | High | The only CI is the build. Its only runtime check is `worldserver.exe --version` (workflow line 281). Patch night's check is "the world finished loading on the right core and was still running 60 s later". Nothing checks that any feature works. The "smoke test", the "4:37 am check" and the rollback after a failed check named in `change-risk.md` are **NOT BUILT YET** (the start-up fall-back to the official server does exist: D8). |
| W2 | The build is the only gate and takes 2-3 hours. | High | A failed anchor, compile error or link error is found deep into a run. Roadmap item 1 (a build loop on the VM) is planned, not built. Anything that catches a failure before the build is worth more than almost any other tooling. |
| W3 | Merging to `main` is deploying, to the VM and to friends' PCs. | High | Every run downloads `main` and executes the newest `PatchNight.ps1` the same night; the guard is only that it parses. The launcher on each friend's PC replaces itself with whatever the site publishes. There is no staging branch and no signature. |
| W4 | SQL failures do not stop the start. | Medium | A file that errors is logged as `[WARN] Enchant fix NNN failed` and the server starts anyway. Because `000-reset.sql` ran first, a failed file means its fixes are missing until it is repaired. The run still ends "Patch night OK". |
| W5 | After the manager's Update button, the nightly restart can report failure. | Medium | Traced from the code, not observed: the manager keeps our old-core world server; the nightly run expects the new core, sees the old one, "falls back" to a saved official copy that is also from the old core, and ends FAILED. A prediction from the code, not observed. **Proposed practice (not yet adopted by James):** after the manager's Update, James runs `Run-PatchNight-Now.cmd` the same day (it restarts the server and installs a build: classify with `wildcard-change-control`; hard stop 5, James decides). Purpose: avoid a nightly run that ends FAILED. Incident: none recorded. README says the opposite in plain words: the Update button "stays manual: click it any time before patch night and the new release is picked up". The two are not reconciled (V12). |
| W6 | Patch night installs the newest release for the core, whichever branch built it. | Medium | Selection is by the core commit in the release notes only. A workflow run started by hand on a feature branch publishes an installable release. It has happened by design once (build 20, from `for-083`). |
| W7 | After a fall-back to the official server, nothing remembers the bad build. | Medium | Nightly runs keep the official server (no Mystic Enchants) until Tuesday; Tuesday's run installs the same build again. `Start-Server.cmd` has no fall-back at all. |
| W8 | One VM; the tasks run only while James is signed in. | Medium | Both tasks use an interactive logon (`Register-PatchNight.ps1:17-18`). A reboot or sign-out stops patch night, the nightly restart and the sign-up service. No log lines at 3:30 am means the task did not run. |
| W9 | Anchors are coupled to upstream text, with uneven strictness. | Medium | Every CoA or SQUID update can break any of 56 scripts. 6 scripts (`46`, `47`, `55`, `56`, `62`, `80`) never check "exactly once": they check "present" and then replace every occurrence. Others mix both kinds of check. Several scripts also depend on an earlier script's inserted text (their errors say "or 40-battlegrounds.ps1 did not run"). |
| W10 | One busy thread per continent. | Medium | Each map is updated by one thread; most bots are on Eastern Kingdoms and Kalimdor, so more vCPUs or map threads add little (`docs/performance.md`, measured 7 Nov; its "8 vCPUs" is stale: 10 logical processors were seen on 22 Nov). This is the structural limit behind the lag work; see `wildcard-lag-spike-campaign`. |
| W11 | Rules exist twice, on the client and on the server. | Medium | The client hides Mystic Enchants from Wildcard characters and keeps its own copy of spell data, so one change can need a patch, SQL, an addon change and a client patch together (`52-racials.ps1` and `client-patch/racials.py`; `150-custom-spells.sql` and `custom_spells.py`; enchant gold costs named in the client config). Only the custom spell ids are checked for agreement (I11). |
| W12 | Dependence on third-party repositories staying available. | Medium | Every build checks out Corfirean and Zyth45 repositories at pinned commits and downloads Boost and MySQL. If a repository is deleted or made private, no build is possible; the last published zip keeps working. No mirror exists. Actions are pinned by tag, not commit. |
| W13 | Enchants that work only through hard-coded C++ look like duds: "about 70" by README.md, 36 by `docs/enchant-restoration.md`; no list of them exists (`wildcard-failure-archaeology`, E-01). | Low | The dud filter cannot see C++-only behaviour, so they are left out of scroll rolls (README, "Known limit"). Owned enchants are untouched. |
| W14 | Public repository, private operation. | Medium | Besides V6: internal addresses, host names and the tunnel layout are in tracked files (`server-settings.txt`, `launcher/README.md`, `signup/README.md`). No token-shaped secret was found. The release zips publish a compiled CoA server. |
| W15 | The client patch and the first-install archive are made by hand. | Low | No script builds `patch-ZZW.MPQ` on the VM or refreshes the 45 GB archive; a stale archive makes new friends download most of the client twice (`launcher/README.md`). |
| W16 | Four tables of player state are created by the patched server itself. | Low | Patches `47`, `49` and `51` run `CREATE TABLE IF NOT EXISTS wcme_...` in the **characters** database at start. They are outside `sql/enchants/` and outside the reset, correctly (they hold player progress), but nothing lists them in one place. |

## 8. Boundaries: which layer does my change belong in?

Pick the first row that fits. Lower rows cost more: a setting is live tomorrow and undone tomorrow; a patch needs a
2-3 hour build and the weekly patch night. **Whatever the row: classify with `wildcard-change-control` first; James
merges.** "Next restart" below means the nightly restart (times: `wildcard-run-and-operate`).

| I want to... | It is a... | Lives in | Live when | How-to |
|---|---|---|---|---|
| Change a number or switch the server already reads (rates, bot counts, a feature flag) | Setting | `server-settings/server-settings.txt` | Next restart | `wildcard-settings-and-flags` |
| Fix an enchant, proc, linked spell or teach rule using data the server already understands | SQL | `sql/enchants/NNN-*.sql`, with ownership markers | Next restart | `ascension-restoration` |
| Change world data that is not an enchant (a vendor, a loot rate, an item flag) | SQL "ride-along" | `sql/enchants/1NN-*.sql`; say in the header that the reset does not undo it (V3) | Next restart | `ascension-restoration` for file conventions; `azerothcore-coa-reference` for the tables |
| Make the server do something no data can express (a new rule, hook, command, bot behaviour) | Patch | `patches/NN-name.ps1`, plus a `CHANGES.md` row, plus a setting to turn it off where practical | Build, then the weekly patch night | `wildcard-patch-authoring`, then `wildcard-build-and-env` |
| Change what the client *shows* or *allows* using its Lua interface (a tab, a tooltip, a window) | Addon | `addon/Wildcard*/` | Next restart, then each friend's next launcher run | `wildcard-client-and-web` |
| Add someone else's addon for everyone | Pinned line | `addon/third-party-addons.txt` (full commit hash; never copy the code) | As above | `wildcard-client-and-web` |
| Make the client know a spell, icon, name or cooldown it lacks | Client patch | `client-patch/*.py`; output built and copied by hand, never committed | When someone rebuilds and copies it, then the next start and launcher run | `wildcard-client-and-web` |
| Add a spell of our own that both sides must know | Client patch **and** SQL | `client-patch/custom_spells.py` generates `sql/enchants/150-custom-spells.sql` | Both of the above | `wildcard-client-and-web`, `ascension-restoration` |
| Change how the server is updated, started, checked or rolled back | Script (hard stop) | `patch-night/`, `vm/`, `.github/workflows/` | Next run (it updates itself) | `wildcard-run-and-operate`; `wildcard-change-control` first |
| Change the website, the launcher, sign-up or the status page | Script / page | `launcher/`, `signup/` (`signup/` is hard stop 4, it reads the secrets file, and often 1: HIGH) | Next restart (launcher: raise its version) | `wildcard-client-and-web`; `wildcard-change-control` first |
| Change something on the VM that is not in any of the above (a firewall rule, a scheduled task, IIS) | One-time setup script | `launcher/Setup-WildcardSite.ps1`, `signup/Register-WildcardSignup.ps1`, `patch-night/Register-PatchNight.ps1` | When James runs it | `wildcard-run-and-operate` |

Rules of thumb that follow from the contract:

- **Never fix it on the VM by hand.** A hand edit to a config is overwritten at the next start if the list sets it,
  and silently kept if it does not; either way the repo no longer describes the server (D1).
- **Prefer the cheapest layer that is a real fix.** James prefers permanent code fixes over database stopgaps for
  enchants, so "cheapest" does not mean "SQL at any price"; it means do not write C++ for what a setting already does.
- **Proposed practice (not yet adopted by James):** a change that spans layers ships in dependency order: SQL and
  settings that the old build ignores first, the patch second, the client side last; state the order in the PR.
  Purpose: no half-live fix. Motivating case: SQL that binds a `spell_wcme_*` script goes live a restart before the
  build that contains the script, and the enchant does nothing in between (`017` header; `ascension-restoration`).
- **New code gets a setting to turn it off where practical, and a `CHANGES.md` row** (`CHANGES.md`, "How changes are
  made"). The setting goes in `server-settings.txt` with a comment naming the build it needs (I4).
- `check_contract.py` is the authority for the architecture invariants only; the full pre-merge check set, and
  which script is the authority for which check, is in `wildcard-validation-and-qa`.
- **Proposed practice (not yet adopted by James):** run the static check before opening any PR that touches
  `patches/`, `sql/` or `server-settings/`. Purpose: catch contract breaks in seconds instead of at 4 am. Motivating
  incidents: V2 and V8 sat unnoticed; a settings file once grew from 240 KB to 22 MB over 16 writes before a check
  existed (`Apply-ServerSettings.ps1:82-86`).

## 9. Provenance and maintenance

Written 2026-11-22 from the checkout at `fcfee51` (PR #232's head on `62a26e4`; `origin/main` is `d3e030f`). Sources read in full: the build workflow, `scripts/resolve_release.py`,
`patch-night/PatchNight.ps1` (988 lines), `Register-PatchNight.ps1`, `launcher_bridge.py`,
`server-settings/Apply-ServerSettings.ps1`, `vm/Install-WildcardServer.ps1`, `launcher/Publish-WildcardSite.ps1`,
`Setup-WildcardSite.ps1`, `signup/Register-WildcardSignup.ps1`, the READMEs, `CHANGES.md`, `docs/roadmap.md`,
`docs/performance.md`, `docs/agents/`. The launcher and sign-up programs were read at their headers only. Line numbers
drift; search for the quoted function name if a number is off.

Re-verify with (repo root, read-only):

```bash
# Every static invariant and the violations list
python3 -I .claude/skills/wildcard-architecture-contract/scripts/check_contract.py     # exit 0 = no FAIL beyond the KNOWN list
# Newest manager release and its pinned commits (needs the network)
python3 -I scripts/resolve_release.py latest
# Schedules
grep -n "cron:" .github/workflows/build-worldserver.yml
grep -n "Day = \|Time = \|WarnMinutes = " patch-night/Register-PatchNight.ps1
# The build still skips releases already built; the nightly restart still never installs
grep -n "already built" .github/workflows/build-worldserver.yml
grep -n "NoInstall" patch-night/PatchNight.ps1 patch-night/Register-PatchNight.ps1
# What FetchRepo copies; the start-up check; the fall-back
grep -n "^function FetchRepo" -A 122 patch-night/PatchNight.ps1
grep -n "^function StartAndCheck" -A 40 patch-night/PatchNight.ps1
grep -n "back to the official one" -A 9 patch-night/PatchNight.ps1
# The mod-ollama-chat pin
grep -rn "906eb2a" .github ollama-chat/README.md
# Counts: patch scripts, SQL files, settings lines
ls patches/*.ps1 | wc -l; ls sql/enchants/*.sql | wc -l
grep -c "^[^#|]*|[^=]*=" server-settings/server-settings.txt
# Patch commits no build contains (V1)
newest=$(git tag -l 'wcme-server-*' | awk -F-build '{print $2, $0}' | sort -n | tail -1 | cut -d' ' -f2)
git log --oneline "$newest"..origin/main -- patches/
# Merges per day (V9)
git log origin/main --first-parent --merges --format=%ad --date=short | sort | uniq -c | sort -rn | head -3
```

When a violation is fixed, delete its row here and re-run the static check. When a new invariant is agreed, add the
row, add a check to `scripts/check_contract.py`, and run it before claiming a status.
