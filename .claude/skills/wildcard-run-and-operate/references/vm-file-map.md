# VM file map

**From the repo; not re-verified on the VM on 2026-11-22.** Every path below was read from a script or document in
this repository (checkout `fcfee51`, PR #232's head; the files described are identical on `origin/main` `d3e030f`). Paths use the script defaults: server `C:\Games\CoA Server`, client
`F:\CoAClient`.

## Top-level folders under C:\Games\CoA Server

These folder names were verified to exist on the VM on 2026-11-22, names only:

`.state`, `BugReport`, `BugReports`, `client-backups`, `Core`, `Data`, `Extras`, `icon-extract`, `Licenses`, `mysql`,
`patch-night`, `Runtime`, `Scripts`, `server-settings`, `Settings`.

| Folder | What this repository says about it |
|---|---|
| `Core` | Server programs, configs, logs, crash files. Detail below. |
| `Settings` | The manager's own state: active realm, ports, master copies of the two main configs. Detail below. |
| `mysql` | The database server, its client and data. Detail below. |
| `Runtime` | The manager's Python. `Runtime\python\python.exe` runs the launcher and the sign-up service. |
| `Scripts` | The manager's launcher, `Scripts\manage.py`. Not in this repository. |
| `patch-night` | Our scripts, their logs and working files. Detail below. |
| `server-settings` | Our settings kit and its report. Detail below. |
| `BugReports` | Spool folder for the in-game Report Bug window (`CoABugReport.SpoolDirectory` in `server-settings.txt`). `StartAndCheck` creates it. The sign-up service turns each file into a GitHub issue and moves it to `BugReports\sent` (`signup/README.md`). |
| `BugReport` | The manager's own bug report relay. Named in the manager's source, not used by our scripts. |
| `.state` | The manager's process records. Named in the manager's source, not used by our scripts. |
| `Data`, `Extras`, `Licenses` | Part of the manager's release. Not touched by our scripts. |
| `client-backups`, `icon-extract` | Nothing in this repository reads or writes them. Purpose UNVERIFIED. Ask James or inspect on the VM before touching. |

Beside the server folder, the manager keeps `C:\Games\CoA Server.manager\friends.json` (the "Play with friends"
address). `RestoreRealmAddress` reads it when `server-settings.txt` has no `realmlist | address` line.

## Core

| Path | What it is | Written by |
|---|---|---|
| `Core\worldserver.exe` | The live world server. Patched or official. | Manager, installer, patch night fall-back |
| `Core\worldserver.official.exe` | The manager's own world server, kept when ours is installed | `Install-WildcardServer.ps1` |
| `Core\worldserver.patched.txt` | The SHA-256 of the patched program that was installed. If it equals the hash of the live program, the live program is ours. | Installer writes. Restore and fall-back delete. |
| `Core\worldserver.patched-release.txt` | The installed build tag, for example `wcme-server-0.261119.114-build70` | `PatchNight.ps1` after a successful install. Fall-back deletes. A by-hand `Install.cmd` or `Restore-Official.cmd` does not touch it. |
| `Core\authserver.exe` | The manager's auth server. Its revision shows which release the manager really has installed. | Manager |
| `Core\ahbot-prices.txt` | The auction price lines last acted on | `RepriceAuctionsWhenPricesChange` |
| `Core\configs\worldserver.conf` | Live main config. The manager rebuilds it from `Settings\worldserver.conf.template`. | Manager, `Apply-ServerSettings.ps1`, `launcher_bridge.py` (database names) |
| `Core\configs\*.dist`, `Core\configs\modules\*.dist` | The list of settings the installed server knows | Manager release |
| `Core\configs\modules\coa.conf` | Holds `CoA.MysticEnchants.AllowWildcard` | Installer sets it to 1. Settings kit. |
| `Core\configs\modules\playerbots.conf` | SQUID's bots. `AiPlayerbot.Enabled`, `AiPlayerbot.RandomBotAccountPrefix`. | Settings kit. Rebuild bots flips Enabled to 0 for a while. |
| `Core\configs\modules\mod_ahbot.conf` | Auction bot. `AuctionHouseBot.DisabledCustomItemIDs` is rewritten each start. | `SkipUnusedAuctionItems`, settings kit |
| `Core\configs\modules\mod_ollama_chat.conf` and `.conf.dist` | AI chat for bots. Created switched off if missing. | `PrepareOllamaChat` |
| `Core\configs\settings-backup\<yyyy-MM-dd_HHmmss>\` | Copies of every config file a settings run changed, taken before the change. Newest 20 runs kept. | `Apply-ServerSettings.ps1` |
| `Core\Logs\Server.log` | This start only. Line 1 has the core revision. `World Initialized In` means the world is up. | World server |
| `Core\Logs\Errors.log` | Errors since the realm began. Read the lines after the last start. | World server |
| `Core\Logs\world-console.log`, `auth-console.log` | Console output of the current start | Manager launcher |
| `Core\Logs\world-console-<yyyy-MM-dd_HHmmss>.log`, `auth-console-<...>.log` | Earlier starts, newest 3 kept | `RotateConsoleLogs` |
| `Core\Logs\console-history.txt` | One-time extract of start banners and slow-update lines from the old 3 GB console log | `SaveConsoleHistory` |
| `Core\Logs\perf\perf-<yyyy-MM-dd_HHmm>.csv` | Windows counters every 5 seconds, one file per start, kept 14 days | `StartDiagnostics` (typeperf) |
| `Core\Logs\perf\counters.txt` | The counter list given to typeperf | `StartDiagnostics` |
| `Core\Logs\Timing.log` | World update time once a minute (`Appender.Timing` in `server-settings.txt`) | World server |
| `Core\Logs\mysql-slow.log` | Queries over 0.5 s (`sql/enchants/095-slow-query-log.sql`) | MySQL |
| `Core\Crashes\` | One `.txt` and `.dmp` per crash, named with the core revision and date | World server |

How to read the logs and counters is in `wildcard-diagnostics-and-tooling`.

## Settings (the manager's)

| Path | What it is | Read by |
|---|---|---|
| `Settings\realm-profile.json` | `active` realm (`coa`, `wildcard`, `reborn`), `simultaneous`, `with_reborn` | Settings kit realm guard, `OnActiveRealm`, `EnsureWildcardBotNames`, `RestoreRealmAddress`, bridge |
| `Settings\repack.json` | `worldPort` (8085 if unreadable) | `WorldAcceptsPlayers` |
| `Settings\worldserver.conf.template`, `authserver.conf.template` | Master copies. The manager rebuilds the live configs from them, so the settings kit writes both. | `Apply-ServerSettings.ps1` |
| `Settings\realm-profiles\<realm>.json` | Saved configs of each inactive realm | `Save-From-CoA-Realm.cmd` |

## mysql

| Path | What it is |
|---|---|
| `mysql\bin\mysql.exe` | The client every script uses |
| `mysql\admin-client.ini` | Connection details for that client. Holds credentials. Never print or copy it. |
| `mysql\data\<database>\` | One folder per database. The bridge checks `acore_world_wildcard` and `acore_characters_wildcard` exist here. |

Databases named in the scripts: `acore_auth`, `acore_world`, `acore_characters`, `acore_world_wildcard`,
`acore_characters_wildcard`. Tables our scripts create: `wcme_applied_sql` in the characters database
(`PrepareOllamaChat`), and the `wcme_*` tables in the world database (`sql/enchants/000-reset.sql`).

## patch-night

| Path | What it is | Written by |
|---|---|---|
| `PatchNight.ps1`, `Register-PatchNight.ps1`, `launcher_bridge.py`, `*.cmd` | The scripts. Replaced from `main` on every run if they parse. | `FetchRepo` |
| `patch-night.log` | Every run of every mode, appended. Lines read `yyyy-MM-dd HH:mm:ss [INFO|OK|WARN|FAIL] message`. | `Log` |
| `last-run.txt` | One line, date and outcome of the latest run of any mode. Overwritten. | `Finish` |
| `console-logs-cleared.txt` | Marker that the one-time console log clear has happened | `RotateConsoleLogs` |
| `third-party-addons.json` | Which commit of each third-party addon is installed | `FetchRepo` |
| `enchants\*.sql` | The SQL fixes as of the last download. Folder is emptied and refilled each run. | `FetchRepo` |
| `launcher\` | Copy of the repository's `launcher/`, including `Publish-WildcardSite.ps1` | `FetchRepo` |
| `ollama-chat\` | Copy of `ollama-chat/` | `FetchRepo` |
| `signup\` | Copy of `signup/`. Replaced each run, with the `Wildcard Sign-up` task stopped and started around it. | `FetchRepo` |
| `signup-settings.json` | Secrets for the sign-up service. Lives on the VM only. Hard stop 4. | `Register-WildcardSignup.ps1` creates, James edits |
| `signup.log` | Accounts created, refusals, issue numbers. No passwords. | Sign-up service |
| `work\repo.zip`, `work\repo\<one folder>\` | The last download of `main`. `vm\Install-WildcardServer.ps1` and `vm\Restore-Official.cmd` are in here. | `FetchRepo` |
| `work\coa-wildcard-<manager release>.zip` | The last build downloaded. A rebuild of the same manager release has the same file name and overwrites it. | Patch night |
| `work\package\` | That build unpacked: `server\worldserver.exe`, `server\core-revision.txt`, `addon\WildcardEnchants`, `Install.cmd`, `Restore-Official.cmd`, `Install-WildcardServer.ps1`, `BUILD-INFO.txt` | Patch night |
| `work\call<N>.in`, `.out`, `.err` | Input and output of each launcher, mysql or script call in a run | `Invoke-Quiet` |

## server-settings

| Path | What it is | Written by |
|---|---|---|
| `server-settings.txt` | The settings list. Replaced from `main` each run. | `FetchRepo` |
| `Apply-ServerSettings.ps1`, `Apply-Settings.cmd`, `Save-Current.cmd`, `Save-From-CoA-Realm.cmd` | The settings kit | `FetchRepo` (a `.ps1` that does not parse is not copied) |
| `settings-report.txt` | Settings check: known, unknown, options on defaults. Rewritten by each settings run. Patch night then appends the server's own start-up warnings. | `Apply-ServerSettings.ps1`, `ReportConfigWarnings` |

Do not run `Save-Current.cmd` or `Save-From-CoA-Realm.cmd` casually. They rewrite `server-settings.txt` on the VM, and
the next run replaces that file from `main` anyway. The format and the kit belong to `wildcard-settings-and-flags`.

## F: drive

| Path | What it is | Written by |
|---|---|---|
| `F:\CoAClient` | The VM's copy of the game client. The launcher gives players what is in here. | Manager, patch night |
| `F:\CoAClient\Interface\AddOns\<addon>` | Our addons (every folder under `addon/`) and the pinned third-party addons | `FetchRepo` every run. The installer copies `WildcardEnchants` from a build zip. |
| `F:\wildcard-site` | The friends' download site: page, launcher, `launcher.json`, `manifest.json`, `changelog.json`. Exists only after `Setup-WildcardSite.ps1` has run once. | `launcher\Publish-WildcardSite.ps1`, run by `PublishFriendsSite` after the world is up |

Site, launcher and client detail belongs to `wildcard-client-and-web`.

## Re-verify

```bash
grep -n "Join-Path\|F:\\\\\|\.manager" patch-night/PatchNight.ps1 | head -80
grep -n "settings-backup\|settings-report\|realm-profile" server-settings/Apply-ServerSettings.ps1
```

On the VM (read-only): `Get-ChildItem 'C:\Games\CoA Server' -Force | Select-Object Name, LastWriteTime`
