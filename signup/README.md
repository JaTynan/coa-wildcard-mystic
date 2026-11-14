# Friends' sign-up page

`https://join.jtlab.cc`: a friend picks an account name and password, enters an invite code, and ticks Cloudflare's
human check (Turnstile). The account is created through the server manager's own one-account command.

- **Limits** (last 24 hours, changeable in the settings file): 3 accounts per internet address, 20 in total, and 10
  failed attempts (wrong invite code or failed human check) per address before it is turned away for the day.
- **Names and passwords** are letters and digits only (the game's limit): names 3-16, passwords 6-16 characters.
- **Secrets** live on the VM in `signup-settings.json` next to the patch-night scripts, never in GitHub:
  the Turnstile site key and secret key, and the invite code(s). Edits apply straight away.
- `signup.log` (same folder) records every account created and every refusal, never passwords.
- The same service answers `GET /api/status` for the homepage (wildcard.jtlab.cc): login and world server up or
  down, players, bots, uptime and the installed build, plus the rates and features read from the live config files.
  Public, read-only, cached 30 seconds (players: 60).

## Setting it up

1. Cloudflare, Turnstile: add a widget for `join.jtlab.cc` (mode Managed). Keep the site key and secret key.
2. Cloudflare, Zero Trust, Networks, Tunnels, your tunnel, Published application routes: add
   `join.jtlab.cc` to `http://10.59.20.53:8089`.
3. On the VM, double-click `Register-WildcardSignup.cmd` in `patch-night\signup`. It starts the page (and at every
   sign-in), opens the firewall to the Servers network only, and opens `signup-settings.json`: paste the two keys,
   replace `CHANGE-ME` with your invite code, save.

Patch night keeps the page's code current and restarts it. To change the invite code, edit `inviteCodes` in the
settings file; old codes stop working as soon as you save.

## In-game bug reports

The game's **Report Bug** window sends reports to the world server (`CoABugReport.Enable` in server-settings), which
saves each one the player ticked **Public** in `C:\Games\CoA Server\BugReports`. This service turns every file into an
issue on `JaTynan/coa-wildcard-mystic`, labelled `player report`, and moves the file into `BugReports\sent`. The
issue shows the player's title and text plus the server context (class, level, map, position, build), never the
account or character. `signup.log` records each issue number.

To switch it on, add a GitHub token to `signup-settings.json`:

1. GitHub, Settings, Developer settings, Fine-grained tokens, Generate new token. Repository access: only
   `JaTynan/coa-wildcard-mystic`. Permissions: Issues, Read and write. Pick a long expiry.
2. Add `"githubToken": "github_pat_..."` to `signup-settings.json` and save. It is picked up within 30 seconds.

Without a token, reports wait in the folder and go out once it is added. A player can send one report every 2 minutes.

