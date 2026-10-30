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

Nothing else changes: the build uses the exact commits of the manager's release and the same
build settings.

## Building (GitHub Actions)

1. Actions tab → **Build patched worldserver** → **Run workflow**.
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

## Credits

Conquest of Azeroth (jealous-sound/azerothcore-wotlk-coa), the CF-Server-Manager builds
(Corfirean), SQUID's Playerbots (Zyth45), AzerothCore. This repository only adds the patch,
the addon and the scripts.
