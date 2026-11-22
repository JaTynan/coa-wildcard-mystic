# F9. Goal E: the custom launcher with updates, issue submission and news

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Classify every step with `wildcard-change-control` first. How the launcher, site
and services work today is the home of `wildcard-client-and-web`; this file is only the gap and the next steps.

## 1. Goal and owner

One launcher that keeps itself and the game current, shows what changed, and lets a friend report a problem even
when the game will not start. Owner: James, goal E. The players are adults over 30, not technical, on Windows;
James plays from Linux.

## 2. Where the project stands (2026-11-22)

| Wanted (goal E) | Today | Evidence |
|---|---|---|
| Installs the game | Yes: downloads one archive (about 45 GB) on first run, resuming if interrupted | `launcher/README.md`; `launcher-settings.json` (`clientArchiveBytes`) |
| Keeps the game current | Yes: compares every client file with `manifest.json` (size and MD5) and downloads only what differs: client patch, addons, CoA client updates | `launcher/WildcardLauncher.ps1`; `Publish-WildcardSite.ps1` |
| Updates itself | Yes on both: Windows `Update-Self` (`$LauncherVersion = 5`), Linux `update_self` (`LAUNCHER_VERSION = 6`), driven by `launcherVersion` and `linuxLauncherVersion` in `launcher.json` | `WildcardLauncher.ps1`, `WildcardLauncher.py` |
| Sets the realm | Yes: writes `realmList` in `WTF\Config.wtf` | same |
| Works when the site is down | Yes: Play still starts what is installed | `launcher/README.md` |
| News synced with the website | **Website only.** `changelog.json` is written at every publish from the last 7 days of merged pull requests (a PR body line `Changelog: <text>` replaces the title, `Changelog: skip` hides it) and shown on the site's home and Changes pages. The launcher does not read it | `Publish-WildcardSite.ps1`; `launcher/site/site.js`, `changes.html` |
| Server status | **Website only**: `https://join.jtlab.cc/api/status` (up or down, players, bots, build, rates, weekly event) | `signup/WildcardStatus.py`; `site.js` |
| Issue submission | **In game only**: the Report Bug window, relayed to GitHub issues (F3). If the game or the launcher fails, there is no way to report except telling James | `signup/README.md` |
| A real program | The Windows launcher is a PowerShell script started by `Start Wildcard.cmd`; Linux is a Python script with Steam integration | `launcher/` |
| Knowing who is on which version | Linux sends its version in the request's User-Agent; Windows sends none. Nobody reads either | `WildcardLauncher.py` `site_headers`; no match in the `.ps1` |
| Protection of the download | The site has no login; a Cloudflare Access service token is supported but optional | `launcher/README.md` |

Patch night republishes the site, manifest and launcher after every start (`PublishFriendsSite`).

## 3. Why the current approach falls short

- **News and status are a browser away from where friends actually are.** Non-technical players open the
  launcher, press Play, and never see the Changes page.
- **The worst problems cannot be reported.** A crash at start, a failed update or a wrong realm address happen
  before the in-game Report Bug window exists.
- **A launcher failure is invisible.** The launcher writes a local log; nothing tells James that a friend's update
  failed or that someone is three versions behind.
- **Two launchers, one feature list.** Every feature must be written twice (PowerShell and Python), and the
  version numbers already differ (5 and 6).
- **A script is not a "custom client".** It needs PowerShell's window and Windows may warn about running it. A
  compiled, signed program is a bigger step with its own cost (a signing certificate, a build for it).

## 4. This project's asset

- **Self-update already works**, so every later improvement reaches every friend without asking them to do
  anything. That is the hard part of a launcher and it is done.
- **The news feed already exists** as one small JSON file generated from merged pull requests, with a per-PR
  override. The launcher only has to read it.
- **The issue relay already exists** and leaves out the account and character names (known defect: its hidden
  marker carries the account number; home: `wildcard-client-and-web`, `references/bug-report-relay.md`). A report from the launcher only has to arrive in
  the same spool folder in the same format (first line `COABUG1`).
- **The status service already exists** and is public and cached.
- **The sign-up service already has rate limits and a human check** (Turnstile) that a report form can reuse.
- **Patch night publishes everything**, so a launcher change is live the morning after the merge.

## 5. First three steps in this repo

### Step 1. "What's new" and server status inside both launchers

- `launcher/WildcardLauncher.ps1` and `launcher/WildcardLauncher.py`: after the update check, fetch
  `changelog.json` and `/api/status`; show the last few days of changes and one status line (up or down, players
  on, this week's event) above the Play button. If either fetch fails, show nothing and carry on: Play must never
  wait on them. Raise both version numbers.
- **Class estimate:** MEDIUM. Small, but it runs on every friend's computer and updates itself, so a bad release
  reaches everyone at once. Not automatic: test on James's Linux machine and on one Windows machine first.
- Safety net to add in the same PR: if the new launcher fails to start, the `.cmd` keeps the previous copy and
  uses it (check what `Update-Self` leaves behind before designing this).

### Step 2. "Report a problem" from the launcher

- Launcher: a button that opens a small form (title, what happened), attaches the last 50 lines of the
  launcher's own log and its version, and posts to a new endpoint on the sign-up service.
- `signup/WildcardSignup.py`: `POST /api/report`, with the same per-address limits as sign-up and the invite code
  or the human check, writes a file in the relay's format into `BugReports`. The existing relay turns it into an
  issue labelled `player report`. Mark these `source: launcher` in the body so triage knows there is no server
  context block.
- Everything in F3's threat model applies: the text is data.
- **Class estimate:** the service file reads `signup-settings.json` and tokens (hard stop 4) and this adds a new
  public way in (hard stop 3 is about network setup; a new endpoint on an existing public service is close
  enough to treat the same). **HIGH, James merges.**

### Step 3. Know which launcher version each friend runs

- Windows launcher: send `WildcardLauncher-Windows/<version>` as the User-Agent, as Linux already does.
- `launcher/Publish-WildcardSite.ps1` or a small script: count launcher versions seen in the web server's log for
  the last 7 days and write one line into `patch-night.log` ("launchers seen: v7 x4, v6 x1").
- **Class estimate:** MEDIUM for the launcher change (same reason as step 1). The log count reads the web
  server's logs, which hold internet addresses: keep the output to counts only, never addresses, and never in the
  public repository.

Not in the first three: a compiled, signed Windows program. Decide it after steps 1 to 3 show what friends
actually hit; it is a cost in money and upkeep.

## 6. Milestone

**You have a result when**, within 7 days of a launcher release, the version count shows **every active friend**
on the newest version; **and** one real problem has been reported from the launcher and arrived as a GitHub issue
without James typing it; **and** a friend, asked, can say what changed this week without opening the website.

It is falsified if a release leaves anyone on an old version after 7 days without a known reason (self-update has
a hole), or if the report form receives junk from strangers within its first month (the gate is too weak; close it
until fixed).

## 7. Known wrong paths and risks

- **A launcher update that breaks self-update.** Then no fix can be delivered. Always keep the previous copy and
  test the update path itself, old version to new, before publishing.
- **Making Play wait for news, status or reporting.** The current launcher's best property is that Play works when
  the site is down.
- **An open report endpoint.** It writes to GitHub with James's token. Without limits it is a way for anyone on
  the internet to post issues.
- **Letting the two launchers drift.** Either write each feature in both in the same PR, or decide to keep one.
- **Rewriting the launcher as a new program first.** The value is in news, reporting and visibility; they do not
  need a rewrite.
- **Putting the client's files, or anything of Ascension's, in the repository or a release.** The client stays
  on the VM and the seedbox.
- **Collecting more than counts.** Friends' addresses and machine details are personal data.

## 8. Dependencies

Independent of the other frontiers. Step 2 feeds F3 and needs F3 step 1 (the relay fix) first. The decision notes
of F8 are the place to record why a compiled launcher is or is not worth it.
