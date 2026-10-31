# Wildcard Mystic Enchants for CF-Server-Manager servers

A personal build: the world server the CF-Server-Manager installs (Conquest of Azeroth, with
SQUID's Playerbots and the CoA bots), plus one change: **Mystic Enchants work on Wildcard
realms**. Shared as-is. **Not supported, use at your own risk**, and keep backups.

## What it changes

- New option `CoA.MysticEnchants.AllowWildcard` (in `coa.conf`, default `0`). At `1`, Wildcard
  characters can use Mystic Enchants: altars, scrolls, the collection, applying and saving
  enchants. The usual rarity limits still apply (epic 3, legendary 1). The essence investment
  rules are skipped for Wildcard, since Wildcard builds come from rolls, not talent trees.
- The **WildcardEnchants** client addon (`addon/`), needed because the game client hides the
  Mystic Enchant tab and blocks its own checks for Wildcard characters. Every player needs it.

A second patch adds `Wildcard.AbilityPool` (in `wildcard.conf`): `all` (default, as the client data
defines Wildcard), `classic` (the original classes' abilities) or `coa` (the Conquest of Azeroth classes'),
for starting abilities, level rolls and rerolls alike, bots included.

Nothing else changes: the build uses the exact commits of the manager's release and the same
build settings.

## Building (GitHub Actions)

1. It runs by itself daily. To run it by hand: Actions tab → **Build patched worldserver** → **Run workflow**.
2. Enter the manager's server release, for example `server-0.261028.83` (or leave `latest`).
   The world server's log shows the core revision in its first line if you're unsure.
3. About 1.5–3 hours later the build appears under **Releases** as a zip.

If the patch no longer fits a new release, the build stops at **Apply our patches** and nothing
is published.

## Installing on the server PC

1. Stop the server in the manager.
2. Download the release zip, extract it, double-click **Install.cmd**.
3. Start the server in the manager.

The installer keeps the manager's program as `Core\worldserver.official.exe`, refuses to install
a build made for a different core than the one installed, sets the config option and copies the
addon into the client folder (`F:\CoAClient` by default). **Restore-Official.cmd** puts the
manager's own world server back.

After a manager update the official server comes back on its own. Build again for the new
release and reinstall.

## Patch night (automatic weekly update)

The build runs by itself every day on GitHub and builds each new manager release once. On the
server PC, `patch-night\Register-PatchNight.cmd` creates a scheduled task (Tuesday 11 pm by
default) that:

1. reads which release the manager has installed;
2. downloads the patched build of that release, if there is one, and the current
   `server-settings` from this repository (edit them here on GitHub and they apply on the night);
3. warns players in game 10 minutes ahead, stops the server, installs the build if it is new,
   applies the settings, starts the server and checks it came up on the right build;
4. if the patched server does not come up, puts the official one back and starts that.

Results go to `patch-night\patch-night.log` and `patch-night\last-run.txt`. The manager's own
**Update** button stays manual: click it any time before patch night and the new release is
picked up. `Run-PatchNight-Now.cmd` runs it straight away, with the window open.

**SQUID's bots on Wildcard:** the manager switches both bot systems off on Wildcard whenever its
own Start button is used. `server-settings` turns SQUID's bots on, and `patch-night\Start-Server.cmd`
applies the settings and starts the server without that step (patch night does the same). This is
not something the manager supports; keep a backup.

`patch-night\launcher_bridge.py` comes from CF-Server-Manager (AGPL-3.0); patch night starts and
stops the server through it, the same way the manager does.

## Credits

Conquest of Azeroth (jealous-sound/azerothcore-wotlk-coa), the CF-Server-Manager builds
(Corfirean), SQUID's Playerbots (Zyth45), AzerothCore. This repository only adds the patch,
the addon and the scripts.
