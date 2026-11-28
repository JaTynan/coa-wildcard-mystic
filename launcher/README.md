# Friends' launcher and download site

Friends get the game, and keep it current, with one launcher. Nothing here contains Ascension's files or any
password; the client itself stays on the VM and the seedbox.

| What | Where it comes from |
| --- | --- |
| First install (the whole client, about 45 GB) | One archive (`CoAClient.tar`) on the seedbox, through a never-expiring share link |
| Every update after that (client patch, addon, files changed by a CoA client update) | The VM's `F:\CoAClient`, served at `https://wildcard.jtlab.cc/client/` through the Cloudflare tunnel |
| The launcher, the download page | This folder; patch night publishes them to the same site |

## How it works

- **The launcher** (`WildcardLauncher.ps1`, started by `Start Wildcard.cmd`) is a small window with a progress bar and
  a Play button. It reads `launcher.json`, updates itself if there is a newer launcher, downloads and unpacks the
  archive on first run (resuming if interrupted), compares the client with `manifest.json` and downloads only the
  files that differ, and sets `realmList` in `WTF\Config.wtf` to the server. If the site is unreachable, Play still
  works with what is installed.
- **Publishing** (`Publish-WildcardSite.ps1`) writes the site on the VM: `launcher.json`, `manifest.json` (every
  client file with size and MD5; `WTF`, `Cache`, `Logs`, `Errors` and `Screenshots` are left out), the launcher and
  `index.html`. Patch night runs it after every start, once the site folder exists. Hashes are cached, so only
  changed files are read again.
- **Tooltips and icons** (`tooltips/build_spell_data.py`, run by the publisher with the server's own Python) write
  `enchant-tooltips.json` (Legendary and Epic), `enchant-tooltips-rare.json`, `enchant-tooltips-uncommon.json`,
  `pet-tooltips.json`, `racial-tooltips.json`, `wildcard-tooltips.json` and `icons\*.png` into the site for the
  Mystic Enchants, Tameable pets, Racials, Abilities and talents, and Build planner pages: what each enchant, pet
  ability, racial, Wildcard ability and talent does, worked out from the client's own spell data (our client patch's
  copy) as the game shows it, and its icon read from the client's archives. `tooltips/wildcard_planner.py` reads the
  Wildcard pool, the essence each level gives and the starting choices from the server's DBC files exactly as the
  world server does, so the planner's limits are the game's. The planner's example builds (`site/builds.json`) are
  the builds our bots aim for, copied by hand from SQUID's source with `scripts/bot_builds.py` when the pinned
  release changes. `tooltips/racials.json` lists each race's signature passive, the buffs it shows and what we changed in
  stock racials, in our own words: update it with `docs/race-kits.md`. Nothing from the client is in this repository; it is all made on
  the VM. Icons are only read again when a client archive changes. If it fails, the publisher's second log line
  says why and the site keeps its last files.
- **Serving** (`Setup-WildcardSite.ps1`, once, as administrator) turns on Windows' web server (IIS) on port 8088:
  the site folder at `/`, `F:\CoAClient` at `/client/`, personal folders blocked, no directory listings, and a
  firewall rule that only lets the Servers network (where the tunnel runs) in.

## Setting it up

1. Upload `CoAClient.tar` to the seedbox and make a share link that never expires. Put it in a file named
   `launcher-local.json` in the `patch-night` folder on the VM (beside `signup-settings.json`), as
   `{"clientArchiveUrl": "the link"}`. That file is never in GitHub; `launcher-settings.json` here leaves the link
   empty. The published `launcher.json` still carries the link, so anyone who can open the site can read it.
2. On the VM, double-click `Setup-WildcardSite.cmd` in `patch-night\launcher`, then `Publish-WildcardSite.cmd`.
3. In Cloudflare (Zero Trust, Networks, Tunnels), add a public hostname to the existing tunnel:
   `wildcard.jtlab.cc` to `http://10.59.20.53:8088`.
4. Send friends `https://wildcard.jtlab.cc`.

The site is not behind a login, so anyone who knows the address could download the client. The launcher supports a
Cloudflare Access service token (a `launcher-secret.json` next to it with `id` and `secret`) if that ever matters.

When a CoA client update changes most of the client, make a new archive and share link, so new friends do not
download the old client and then most of it again.
