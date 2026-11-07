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
- **Serving** (`Setup-WildcardSite.ps1`, once, as administrator) turns on Windows' web server (IIS) on port 8088:
  the site folder at `/`, `F:\CoAClient` at `/client/`, personal folders blocked, no directory listings, and a
  firewall rule that only lets the Servers network (where the tunnel runs) in.

## Setting it up

1. Upload `CoAClient.tar` to the seedbox and make a share link that never expires. Put it in
   `launcher-settings.json` as `clientArchiveUrl`.
2. On the VM, double-click `Setup-WildcardSite.cmd` in `patch-night\launcher`, then `Publish-WildcardSite.cmd`.
3. In Cloudflare (Zero Trust, Networks, Tunnels), add a public hostname to the existing tunnel:
   `wildcard.jtlab.cc` to `http://10.59.20.53:8088`.
4. Send friends `https://wildcard.jtlab.cc`.

The site is not behind a login, so anyone who knows the address could download the client. The launcher supports a
Cloudflare Access service token (a `launcher-secret.json` next to it with `id` and `secret`) if that ever matters.

When a CoA client update changes most of the client, make a new archive and share link, so new friends do not
download the old client and then most of it again.
