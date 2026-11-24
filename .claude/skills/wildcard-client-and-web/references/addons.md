# Addons: what each does, how they talk to the server, how to test

Read from `addon/` and `patch-night/PatchNight.ps1` on 2026-11-22. An addon is a folder of Lua scripts the game
client loads from `Interface\AddOns\<Name>\`; its `<Name>.toc` file lists the scripts and holds the version.

## Our three addons

| Addon | Version (`.toc`) | Files | What it does | Server half |
|---|---|---|---|---|
| `WildcardEnchants` | 1.11 | `EnchantData.lua`, `TooltipData.lua`, `TooltipFix.lua`, `WildcardEnchants.lua` | Makes Mystic Enchants usable by Wildcard characters in the client (below) | `patches/mystic-enchants-wildcard.patch`, setting `CoA.MysticEnchants.AllowWildcard = 1` |
| `WildcardMastery` | 1.0 | `WildcardMastery.lua` | Shows Profession Mastery (earned past skill 300) in the Skills tab and profession windows; `/mastery` | `patches/51-profession-mastery.ps1` |
| `WildcardCombatLogFix` | 1.0 | `WildcardCombatLogFix.lua` (+ saved variable `WildcardCombatLogFixDB`) | Clears the 3.3.5 client's combat log when it gets stuck (hundreds of bots around), so damage meters keep working; `/clf`, `/clf report`, `/clf clear` | none |

**Where the version is declared:** only in the `## Version:` line of each `.toc`. None of the Lua files holds a
version constant, so there is nothing to disagree with (checked by `scripts/check_client_web.py`). Note that
`README.md` still says "addon (1.8)" and `docs/enchant-restoration.md` "(1.9)" in passing: those are the versions
that introduced a feature, not the current one.

## Why every player needs WildcardEnchants

The Ascension client was built to switch Mystic Enchants OFF for Wildcard characters. Four separate client
behaviours block them, and the addon undoes each one for Wildcard characters only (`Applies()`):

| Client behaviour | What the addon does | Function |
|---|---|---|
| The Collections window hides its Mystic Enchant tab and redirects requests elsewhere | Re-opens the tab and shows it again after the window's own OnShow | `Patch` |
| The client's own rule checks (`C_MysticEnchant.Can...`) answer "disabled in Wildcard" or "essence investment required" | Reports those two objections as passed; every other objection stands. The server re-checks every request with the real rules. | `PatchChecks` |
| The enchant list (`C_MysticEnchant.QueryEnchants`) returns nothing | Builds the list from `EnchantData.lua` with the tab's own filters | `PatchQuery`, `QueryEnchants` |
| The client keeps no record of active slots (`GetAppliedEnchant` answers 0) | Uses the slot list the patched server whispers to the addon | `PatchApplied` |

Without the addon a Wildcard player cannot open the enchant tab, cannot apply a scroll through the UI and sees no
active enchants, even though the server would allow it. That is why patch night and the installer put it in the
master client folder and the launcher gives it to everyone. It changes nothing for non-Wildcard characters.

## The two data files

| File | Header says | Content | Generator |
|---|---|---|---|
| `EnchantData.lua` | "Generated from MysticEnchant.dbc: the enchants a live/seasonal (Wildcard) realm offers" | `WildcardEnchantsData`: 6,440 entries of `{spell id, quality 0-6, worldforged 0/1, class mask}` | NOT in this repository (no script writes it; it arrived in the first upload, commit `5f83af5`). `README.md` says it "lists every enchant for browsing and does not need updating". UNVERIFIED how to regenerate it after a client update that adds enchants: ask James. |
| `TooltipData.lua` | "Generated: enchant spell -> working twin whose tooltip it should show (see sql/enchants)" | `WildcardEnchantsTooltipTwin`: about 200 pairs | NOT in this repository either. It has been edited in the same commits as the twin-link SQL (`sql/enchants/001`, `003`...) and the legendary reviews. When a twin link is added or removed in SQL, this file must change with it. |

`TooltipFix.lua` reads each pair's two descriptions from the client at run time and swaps the old text for the
twin's in spell and item tooltips. It holds no tooltip text itself, so no client text is published.

## How the addons talk to the server

The 3.3.5 client has no direct addon-to-server channel, so both sides use an "addon whisper to yourself":

| Prefix | Addon sends | Server sends | Used by |
|---|---|---|---|
| `WCME` | `REQ` (on entering the world, because the addon misses the login send) | `S:<slot 0 spell>,<slot 1 spell>,...` on login and on every change | WildcardEnchants |
| `WCMM` | `REQ` after loading | `M:<skill>,<level>,<max>,<into level>,<level needs>,<bonus x100>,<G or C>;...` | WildcardMastery |

Slot numbering trap: the client numbers enchant slots 1-17, the server 0-16. Client slot i is server slot i - 1
(the 30 Oct "one slot along" bug, commit `f46610e`).

## 3.3.5 client constraints (each one visible in this code)

- `## Interface: 30300` in every `.toc`. An addon marked for another version needs "Load out of date AddOns"
  ticked (the third-party list notes this for SuperDuperMacro).
- The client's Lua is 5.1: no `goto`, no integer division operator, no bitwise operators; bit tests are done with
  arithmetic (`HasClass` uses `math.floor(mask / 2 ^ (classID - 1)) % 2`).
- Timers are done with a frame's `OnUpdate` script (`WildcardCombatLogFix.lua` line 75); nothing here uses a timer
  API.
- Ascension-only APIs (`C_MysticEnchant`, `C_GameMode`, `Collections`, the `MYSTIC_ENCHANT_*` events) may be
  absent: the code tests for them and registers those events inside `pcall`.
- Do not give a frame a global name another addon uses. The combat-log addon was written fresh because the
  well-known one names its frame `DEFAULT_CHAT_FRAME`, replacing the chat window (commit `447b561`).
- Work done on every window open is felt: the collection-window freeze (below).
- An addon only reloads when the game restarts or the player types `/reload`.

## The collection-window freeze (21 Nov, 1.11, commit `4fdb6a0`, PR #224)

Symptom: opening the Mystic Enchant collection, turning a page or changing a filter froze the game for a moment.
Cause: every query asked the client for the name and info of all 6,440 enchants and sorted them. Fix, in
`WildcardEnchants.lua`:

1. `Index()` builds the name list and the sort order once per session.
2. Known/unknown is asked of the client only when exactly one of those two filters is on; otherwise only the
   enchants on the page shown are looked up.
3. The same query repeated within 2 seconds returns the last answer (the window asks several times while opening).
4. `Forget()` drops that cached answer on any `MYSTIC_ENCHANT_*` event or new slot list, so a learned or applied
   enchant shows at once.

If the freeze comes back, look for a new per-enchant call inside the loop over `Index()`.

## Third-party addons (`addon/third-party-addons.txt`)

Eleven GitHub repositories as of 2026-11-22 (DragonUI, Details, ActionBarSaver, AtlasLoot, Clique, Decursive,
MikScrollingBattleText, MoveAnything, Omen, OmniBar, SuperDuperMacro). One line each:
`owner/repository | 40-character commit | Folder, Folder` (`Name=.` copies the repository's root as `Name`).

- Their code is never kept in this repository; patch night downloads each at its pinned commit from GitHub.
- A branch name instead of a commit is rejected (the line is skipped with a WARN in `patch-night.log`).
- A folder is installed only if it contains `<Folder>.toc`.
- One is downloaded again only when its pin changes or a folder is missing from the client; the installed pins are
  remembered in `patch-night\third-party-addons.json` on the VM.
- Before changing a pin: read what changed between the two commits in that repository. The file's header records
  the check done when each was added (game version 3.3.5, nothing but Lua, XML and art). This is other people's
  code that will run on every friend's PC.

## How an addon change reaches players

1. Edit under `addon/<Name>/`, bump `## Version:` in the `.toc`, merge to `main` (James merges).
2. The next patch-night run of any kind (the daily 3:30 am patch night, `Start-Server.cmd`, `Run-PatchNight-Now.cmd`)
   downloads `main` and copies every folder under `addon/` into `F:\CoAClient\Interface\AddOns`
   (`FetchRepo`; log line `Updated the <Name> addon in ...`). The installer does the same on a build install.
3. After the server is back up, the site is republished and the changed files get new hashes in `manifest.json`.
4. A friend's launcher downloads them at its next start; the game must be restarted (or `/reload`) to load them.

So an addon change merged today is on friends' PCs after the next 4:00 am restart plus one launcher start. Nothing
removes an addon folder from friends' PCs when it is deleted from the repository: list its files in `remove` in
`launcher/launcher-settings.json` (a PR: classify with wildcard-change-control first; James merges). Deleting it
from the VM's client folder is a hand step on the VM: **[James, or with his say-so.]**

Older documents and the 30 Oct commit `f46610e` say "coa-sync" carries the client folder to players. No code for
coa-sync is in this repository; since 7 Nov the carrier is the launcher and its manifest.

## Testing an addon change

There is no automated addon test. What can be done, cheapest first:

1. `python3 .claude/skills/wildcard-client-and-web/scripts/check_client_web.py` (the `.toc` lists files that exist,
   Interface 30300, pins well-formed).
2. On your own client: copy the folder into `Interface\AddOns`, start the game (or `/reload`), and turn on Lua
   errors with `/console scriptErrors 1` (a stock 3.3.5 client setting; general client knowledge, not from this
   repository) so a mistake shows as a pop-up instead of silently doing nothing.
3. WildcardEnchants, on a Wildcard character: the Collections window shows the Mystic Enchant tab; the list fills;
   paging and filters do not freeze; an applied enchant shows in the slot it was applied to; a twin-restored
   enchant's tooltip shows the twin's text; an item's "Requires Level" line is unchanged (the 7 Nov bug).
4. On a non-Wildcard character: nothing changes.
5. WildcardMastery: `/mastery` prints; the Skills tab shows the Mastery level for a profession past 300.
6. WildcardCombatLogFix: `/clf` prints a count; `/clf report` announces each clear.

Record what was tested and when in the PR. Risk class: `docs/agents/context/change-risk.md` treats "addon text"
as a standard LOW change and "an addon's logic" as likelihood score 2 on its "kind of change" check; classify with
wildcard-change-control.
