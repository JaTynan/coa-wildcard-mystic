# Components in detail

Everything here was read from the code on 2026-11-22 (`origin/main` at `d3e030f`, #231). Nothing was re-checked on the VM
that day: paths on the VM come from the scripts' defaults.

Contents: 1 launcher (Windows) · 2 launcher (Linux) · 3 download site and publishing · 4 sign-up service ·
5 status API · 6 pets API · 7 status board window · 8 the VM folder map for this surface

---

## 1. Windows launcher (`launcher/WildcardLauncher.ps1`, version 5)

A Windows PowerShell 5.1 script with a small WinForms window (progress bar, Play, Log). Friends start it with
`Start Wildcard.cmd`, which runs it hidden with `-ExecutionPolicy Bypass`.

Files next to the launcher on a friend's PC:

| File | Made by | Purpose |
|---|---|---|
| `WildcardLauncher.ps1`, `Start Wildcard.cmd` | the zip | the launcher |
| `launcher-site.txt` | the zip (publish writes the `site` value into it) | site address; default `https://wildcard.jtlab.cc` if missing |
| `CoAClient\` | first install | the game; `CoAClient\Ascension.exe` is the "installed" test |
| `CoAClient.tar`, `CoAClient.tar.part` | first install | the archive while it downloads; deleted after unpacking |
| `launcher-state.json` | launcher | per-file `size|modified-time` stamp and MD5, so unchanged files are not hashed again |
| `launcher.log` | launcher | every step and error, with timestamps; the Log button opens it in Notepad |
| `launcher-secret.json` | nobody today | optional Cloudflare Access service token (`id`, `secret`); sent as `CF-Access-Client-Id/Secret` headers to the site only, never to the seedbox |

What one start does (`$form.Add_Shown`, lines 397-423):

1. `Get-Json "$site/launcher.json"` (20 s limit).
2. `Update-Self`: if `launcherVersion` in `launcher.json` is greater than `$LauncherVersion`, download
   `$site/WildcardLauncher.ps1` to `WildcardLauncher.ps1.new`, move it over the old one, start it, close.
   Only the `.ps1` is replaced: `Start Wildcard.cmd` and `launcher-site.txt` never self-update.
3. `Install-Client`: skipped when `CoAClient\Ascension.exe` exists. Otherwise needs
   `clientArchiveBytes * 2 + 5 GB` free on the drive (about 91.5 GB with the current 46,456,369,152-byte archive),
   downloads `clientArchiveUrl` to `CoAClient.tar` (resumes a `.part` file with an HTTP Range request; no site headers
   are sent to the seedbox), runs `tar.exe -xf` into the launcher's folder, deletes the archive.
4. `Set-Realm`: rewrites the `SET realmList` line of `CoAClient\WTF\Config.wtf` and writes
   `set realmlist <realm>` into `realmlist.wtf` in every `CoAClient\Data\<locale>` folder (names like `enUS`;
   creates `enUS` if there is none). The game reads the `Data\<locale>` file first.
5. `Sync-Client`: downloads `manifest.json`; for each file, the local copy is current when its size and modified
   time (to the second) equal the manifest's, otherwise its MD5 is computed (4 MB pieces, window stays alive) and
   compared. Stale files are downloaded from `$site/client/<path>` (each path part URL-escaped), their modified time
   set to the manifest's. `web.config` is skipped. One failed file does not stop the rest; failures are listed at
   the end and retried at the next start. Paths in the manifest's `remove` list are deleted.
6. Whatever happened above, the realm is set again (from `launcher.json`, else the built-in `wow.jtlab.cc`) and
   `Check-Server` tries TCP port 3724 (the login server) for 5 seconds and shows online or not answering.
7. Play starts `CoAClient\Ascension.exe` and closes the window. If the site could not be reached but the game is
   installed, Play is still enabled.

Error texts are plain English (`Explain`): no internet, firewall, timeout, wrong PC clock (TLS trust failure), 404
("tell James"), 5xx.

## 2. Linux launcher (`launcher/WildcardLauncher.py`, version 6)

Python 3, standard library only, terminal output. Same steps as Windows. Verified options (`argparse`, lines 707-716,
plus one taken before argparse):

| Option | What it does |
|---|---|
| (none) | update, set the realm, check the server, exit |
| `--play` | the same, then start the game with the saved command (default `wine {exe}` if Wine is installed) |
| `--set-play "COMMAND"` | save the start command in `launcher-linux.json`; `{exe}` becomes the path to `Ascension.exe` |
| `--add-to-steam` | Steam must be closed. Adds a non-Steam shortcut named "Project Descension" to every signed-in Steam user (`userdata/<id>/config/shortcuts.vdf`), maps it to `proton_experimental` in `config/config.vdf`, downloads the artwork from `<site>/steam/`, sets `--play` to start it through Steam, and also runs `--add-shortcut`. First-time backups are kept as `*.wildcard-backup`. Native and Flatpak Steam. |
| `--add-shortcut` | writes `wildcard.desktop` to the app menu and desktop (runs `--play --from-shortcut` in a terminal) |
| `--from-shortcut` | hidden; keeps the terminal open on an error |
| `--steam-update <Steam's %command%>` | hidden; what Steam's launch options call. Updates (skipped if an update finished in the last 120 s, marker file `launcher-last-update`), shows a zenity window if zenity exists, then becomes Steam's own game command. Handled before argparse because Steam's command contains `--`. |

Steam launch options written by `--add-to-steam`: `WINEDLLOVERRIDES="divxtac=d" "<python>" "<launcher>" --steam-update %command%`.
The override switches off the client's `DivxTac.dll`, which hung the loading screen under Proton (commit `f10cf9e`).

Self-update: `update_self` compares `linuxLauncherVersion`, downloads `WildcardLauncher.py`, replaces itself and
re-executes with the same arguments.

Unpacking uses Python's `tarfile` with the `data` filter where the Python version has it (refuses unsafe paths).

## 3. Download site and publishing

### Serving (`launcher/Setup-WildcardSite.ps1`, run once as administrator through `Setup-WildcardSite.cmd`)

| Thing | Value (script defaults) |
|---|---|
| Windows features enabled | `IIS-WebServerRole`, `IIS-WebServer`, `IIS-StaticContent`, `IIS-RequestFiltering`, `IIS-ManagementConsole` |
| IIS website | name `Wildcard`, port `8088`, root `F:\wildcard-site` |
| Virtual directory | `client` -> `F:\CoAClient` |
| IIS settings | every extension served as `application/octet-stream`; double escaping allowed (names with `+` and spaces); `maxAllowedContentLength` 4294967295; directory listing off; under `/client` the segments `WTF`, `Cache`, `Logs`, `Errors`, `Screenshots` are hidden |
| Folder permissions | `IIS_IUSRS` read and execute on both folders |
| Firewall rule | `Wildcard site`: inbound TCP 8088, allowed only from the Servers network's address range (where the Cloudflare tunnel runs; the range is in `launcher/Setup-WildcardSite.ps1`) |
| Public name | `wildcard.jtlab.cc` -> port 8088 on the VM's LAN address, a route in the Cloudflare tunnel (set by hand in Cloudflare; `launcher/README.md` step 3) |

There is no scheduled task for the site: IIS serves it, and patch night republishes it.
IIS keeps its own `web.config` inside `F:\CoAClient` for the `/client` settings; IIS never serves that file, which
is why publish leaves it out of the manifest.

### Publishing (`launcher/Publish-WildcardSite.ps1`)

Parameters: `-Client` (default `F:\CoAClient`), `-Site` (`F:\wildcard-site`), `-Settings`
(`launcher-settings.json` next to the script), `-Repo` (`JaTynan/coa-wildcard-mystic`), `-ChangelogDays` (7).

What it writes into the site folder:

| File | Content |
|---|---|
| `manifest.json` | `{ "generated": ISO time (UTC), "files": [ { "path", "size", "md5", "mtime" } ... ], "remove": [...] }`. `path` is relative to the client folder with backslashes; `md5` lower-case hex; `mtime` Unix seconds (UTC). Written to `manifest.json.new` then moved, so a launcher never reads half a file. |
| `.hash-cache.json` | publish's own cache: a file whose `size|ticks` stamp is unchanged keeps its MD5 without being read again |
| `launcher.json` | `realm`, `clientArchiveBytes` (from `launcher-settings.json`), `clientArchiveUrl` (from `launcher-local.json` on the VM since PR #242), `launcherVersion` (read from the line `$LauncherVersion = N` in the `.ps1`), `linuxLauncherVersion` (from `LAUNCHER_VERSION = N` in the `.py`) |
| `WildcardLauncher.ps1`, `WildcardLauncher.py` | copies, for self-update and the Linux download |
| `WildcardLauncher.zip` | `WildcardLauncher.ps1`, `Start Wildcard.cmd` and a `launcher-site.txt` holding the `site` value: the Windows download button |
| everything in `launcher/site/` | pages, `site.js`, `style.css`, `images/`, `steam/` |
| `changelog.json` | `{ "generated", "days": [ { "date": "yyyy-MM-dd", "label": "Sunday 22 November", "items": [ { "text", "number" } ] } ] }` |

Left out of the manifest: the top-level folders `WTF`, `Cache`, `Logs`, `Errors`, `Screenshots`; any file named
`realmlist.wtf` (the launcher writes its own); any file named `web.config`.

The changelog: one unauthenticated call to GitHub's pull-request list (closed, base `main`, sorted by last update,
first 100 only). A merged PR counts when it merged within the last `ChangelogDays` days (local time on the VM). Its
line is the PR title, unless the PR body has a line starting `Changelog:`: that text replaces the title, and
`Changelog: skip` hides the PR. If GitHub cannot be reached, the old `changelog.json` stays and the output line says
`changelog not refreshed (<error>)`.

Its one output line, which patch night writes to `patch-night.log`:
`Published <N> client files (<X> GB), launcher version <V>, <C> change(s) in the last 7 days, to F:\wildcard-site.`

### `launcher/launcher-settings.json`

| Key | Meaning |
|---|---|
| `site` | the site address written into the zip's `launcher-site.txt` |
| `realm` | the address the launchers write into the game's realm list files (`wow.jtlab.cc`) |
| `clientArchiveUrl` | empty since PR #242 (23 Nov 2026). The seedbox share link for `CoAClient.tar` now lives in `launcher-local.json` in the patch-night folder on the VM (gitignored); the publisher reads it from there, falls back to this key, and stops with "No client archive link" if neither has one, leaving the site's last good `launcher.json` in place |
| `clientArchiveBytes` | the archive's exact size; drives the free-space check and the progress text |
| `remove` | client-relative paths every launcher deletes at its next run (empty today) |

Not gitignored, and public by design: `launcher.json` on the site repeats all but `site` and `remove`, with the
archive link taken from `launcher-local.json`. Never write the link into this file, a PR or an issue.

### The pages (`launcher/site/`)

| Page | `data-page` | Data it loads |
|---|---|---|
| `index.html` | `home` | `/api/status`, `changelog.json`, `manifest.json` |
| `how-to-play.html` | `how-to-play` | static (screenshots in `images/`) |
| `server.html` | `server` | `/api/status`, `manifest.json`, `launcher.json` |
| `leaderboards.html` | `leaderboards` | `/api/status` (`leaderboards`) |
| `pets.html` | `pets` | `https://join.jtlab.cc/api/pets` |
| `changes.html` | `changes` | `changelog.json` |

`site.js` builds the header, menu (`PAGES` list), footer and the live "Online · N playing" pill on every page; it
fetches `https://join.jtlab.cc/api/status` once per page and again every 60 seconds. Pages build their content with
`el(...)` and `textContent`, so text from the server is never inserted as HTML.

## 4. Sign-up service (`signup/WildcardSignup.py`)

One Python process (the manager's own Python, standard library only) listening on `0.0.0.0:8089`.

| Route | What it does |
|---|---|
| `GET /` or `/index.html` | the sign-up page (HTTP 503 "Sign-up is not open yet" until the settings file is complete) |
| `GET /style.css` | the shared stylesheet, read from `patch-night\launcher\site\style.css`; redirects to the site's copy if missing |
| `POST /api/join` | create an account (JSON body up to 4096 bytes: `name`, `password`, `invite`, optional `recruiter`, `token`) |
| `POST /api/recruit` | link or change an existing account's recruiter after proving its password |
| `GET /api/status` | status JSON for the website (section 5); `Access-Control-Allow-Origin: *` |
| `GET /api/pets` | tameable pets JSON (section 6); `Access-Control-Allow-Origin: *` |

Order of checks in `join()` (lines 251-304):

1. Settings usable? (both Turnstile keys present, at least one invite code, none starting with `CHANGE`.)
2. Name `[A-Za-z0-9]{3,16}`, password `[A-Za-z0-9]{6,16}`, password not equal to the name.
3. Limits over the last 24 hours, from `signup-state.json`: failed attempts from this address
   (`failuresPerAddressPerDay`, default 10), accounts from this address (`perAddressPerDay`, 3), accounts in total
   (`perDay`, 20). Over a limit: HTTP 429.
4. Human check: the Turnstile token is verified with Cloudflare (`siteverify`, 10 s). Failing counts as a failed
   attempt.
5. Invite code: compared without regard to case, in constant time, against every code in `inviteCodes`. Wrong
   counts as a failed attempt.
6. Optional recruiter must be a valid, existing, different account.
7. `create_account`: runs `<server>\Runtime\python\python.exe -B <patch-night>\launcher_bridge.py
   <server>\Scripts\manage.py create-account-once` with `{"username", "password"}` on standard input (60 s). This
   is the server manager's own one-account command, the same path as the manager's Create account button. The
   service never writes account rows itself.
8. On success the creation is recorded for the limits and, if asked, the recruiter is linked.

The client's address is the `CF-Connecting-IP` header (set by Cloudflare), else the socket address.

Recruit-a-Friend: `recruit()` checks the password against the account's SRP6 verifier (read with the server's own
`mysql.exe` and `mysql\admin-client.ini`), then runs one `UPDATE ... SET recruiter` on the auth database. Names are
validated against `[A-Za-z0-9]{3,16}` before they are put into SQL.

Files next to the patch-night scripts on the VM:

| File | In Git? | Content |
|---|---|---|
| `signup-settings.json` | no (`.gitignore`) | SECRET: `turnstileSiteKey`, `turnstileSecret`, `inviteCodes`, optional limits, optional `githubToken`, optional `githubRepo` |
| `signup-state.json` | no (`.gitignore`) | the last 24 hours of `created` and `failed` entries (address, time) |
| `signup.log` | never committed (not in `.gitignore`, so do not `git add` it) | every account created, every refusal with its reason and address, recruiter links, bug-report relay results, status or pets failures. Never passwords. |

Settings are re-read on every request (and every 30 s by the relay), so an edit applies without a restart.

Installed by `signup/Register-WildcardSignup.ps1` (as administrator, through the `.cmd`):

- Creates `signup-settings.json` with placeholders if missing and opens it in Notepad.
- Firewall rule `Wildcard sign-up`: inbound TCP 8089 only from the Servers network's address range.
- Scheduled task `Wildcard Sign-up`: at log-on of the registering user, runs
  `<server>\Runtime\python\python.exe -B "<...>\signup\WildcardSignup.py" --server "C:\Games\CoA Server" --port 8089`
  with the patch-night folder as working directory; interactive, not elevated, no time limit, restarts up to 999
  times one minute apart, one instance only.
- Public name `join.jtlab.cc` -> port 8089 on the VM's LAN address, a route in the same Cloudflare tunnel (by hand).

Kept current by patch night: `FetchRepo` stops the task, replaces `patch-night\signup\` with the repository's copy
and starts the task again, on every run (weekly, nightly, `Start-Server.cmd`).

## 5. Status API (`signup/WildcardStatus.py`, `GET /api/status`)

Cached 30 seconds; the console query 60 seconds; leaderboards 5 minutes.

| Field | Source |
|---|---|
| `login`, `world` | a TCP connect to `127.0.0.1` on `authPort` / `worldPort` from `<server>\Settings\repack.json` (defaults 3724 / 8085) |
| `players`, `characters`, `uptime` | the world console's `server info`, through the manager's `ra-once` verb (only when the world port answers). The site shows bots as `characters - players`. |
| `server` | `tag`, `release`, `build` parsed from `<server>\Core\worldserver.patched-release.txt` |
| `restart` | fixed text (4:00 am Sydney, warnings from 3:30) |
| `settings` | rates and features read live from `worldserver.conf`, `modules\mod-coa-prestige.conf`, `modules\playerbots.conf`, `modules\wildcard.conf`, `modules\mod_ollama_chat.conf`, and the rune percentages from `patch-night\enchants\100-rune-rates.sql`. XP is shown relative to CoA's stock 0.9295. |
| `weekend` | the weekly event, computed from the `WeekendBonus.*` settings the same way `patches/45-weekend-bonus.ps1` does |
| `leaderboards` | five top-10 boards (level, Prestige, Manastorm floor, honourable kills, world PvP kills) and up to 40 server firsts, by SQL through the server's own `mysql.exe`. Bot accounts (prefix `AiPlayerbot.RandomBotAccountPrefix`, default `rndbot`) and the names in `Leaderboards.HiddenCharacters` (default `Auctioneer`) are left out. A missing table blanks only its board. |

The status code reads the databases; it never writes to them.

## 6. Pets API (`signup/WildcardPets.py`, `GET /api/pets`)

Built once at service start (a warm-up thread) and cached six hours. Families, kinds and abilities come from the
server's DBC files; one example creature per family and its spawn come from the world database; the zone name comes
from the server's map tiles and `AreaTable.dbc`. Failures are logged in `signup.log` with MySQL's own message
(commit `2563565`).

## 7. Status board window (`signup/WildcardConsole.py`, on `main` since PR #231, 22 Nov)

The `Wildcard Sign-up` task's console window starts minimised and redraws every 30 seconds: world, login and
database ports up or down, players and uptime, patched build tag and running core revision, this machine's
addresses, every realm row (`id, name, address, localAddress, port`, and "marked offline"), the last patch-night
outcome and downtime, the settings check summary, and the newest six lines of `signup.log`. Closing that window
stops the sign-up page, the status API and the bug-report relay (its title says so).

## 8. VM folder map for this surface

`<server>` is `C:\Games\CoA Server`. The patch-night folder is `<server>\patch-night` (inferred from the code:
`WildcardConsole.py` finds `server-settings` beside it, and `PatchNight.ps1` puts `server-settings` in `<server>`).

| Path | What |
|---|---|
| `<server>\patch-night\launcher\` | the repository's `launcher/` folder, replaced on every patch-night run |
| `<server>\patch-night\signup\` | the repository's `signup/` folder, replaced on every run (task restarted) |
| `<server>\patch-night\signup-settings.json`, `signup-state.json`, `signup.log` | sign-up secrets, limits state, log |
| `<server>\patch-night\third-party-addons.json` | which commit of each third-party addon is installed |
| `<server>\patch-night\patch-night.log`, `last-run.txt` | patch night's log and last outcome |
| `<server>\BugReports\` and `\sent\` | bug-report spool and the reports already relayed |
| `F:\CoAClient\` | the master client folder friends update from (`Interface\AddOns`, `Data\patch-ZZW.MPQ`) |
| `F:\wildcard-site\` | the published site (`manifest.json`, `launcher.json`, `changelog.json`, pages, launchers, `.hash-cache.json`) |
