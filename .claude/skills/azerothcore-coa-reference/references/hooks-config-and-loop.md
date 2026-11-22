# Server structure: processes, config, script hooks and the update loop

Read this when you need to know where a piece of patch code runs, how often, on which thread, and what a setting
read costs there. It is the background for the checklist items "a setting read on a hot path" and "code written
for players runs for 750 bots too" in `docs/agents/context/patches.md`.

`core:` = the pinned CoA core at `c3f2fd4b`; `squid:` = the pinned SQUID bots at `4ef5ed9e`. Checked 2026-11-22.

## 1. Processes

| Process | Port | Job | Config file |
|---|---|---|---|
| MySQL | (the manager's own instance under `C:\Games\CoA Server\mysql`) | Holds the auth, world and characters databases | `mysql\my.ini`, rewritten by the manager at every start (`sql/enchants/090-mysql-tuning.sql` header) |
| `authserver.exe` | 3724 | Login and realm list | `authserver.conf` |
| `worldserver.exe` | 8085 | The game world. Everything in `patches/` is compiled into it | `worldserver.conf` plus every file in `configs\modules\` |

Ports are from `core:AGENTS.md` ("entry points (ports 3724 and 8085)") and `server-settings.txt:401`.

Since 22 Nov 2026 a staged patch night restarts only the world server; MySQL and the auth server keep running
(`patch-night/PatchNight.ps1:154`).

## 2. The config system

### 2.1 Files this project writes (from `server-settings/server-settings.txt`: 273 lines on 2026-11-22, which is 270 settings plus the `realm` and two `realmlist` lines; count rule in `wildcard-settings-and-flags`)

Paths are relative to `C:\Games\CoA Server\Core\configs`.

| File | Settings we set | What lives there |
|---|---|---|
| `worldserver.conf` | 146 | Stock AzerothCore options, and **most of our own options** (`Racials.*`, `Battleground.*`, `WeekendBonus.*`, `BonusStats.*`, `Mastery.*`, `Leaderboards.*`, `Manastorm.*`, ...) |
| `authserver.conf` | 1 | `BindIP` |
| `modules\coa.conf` | 12 | CoA's own switches (`CoA.*`), including our `CoA.MysticEnchants.*` |
| `modules\wildcard.conf` | 9 | Wildcard rolls (`Wildcard.*`), CoA's and ours |
| `modules\playerbots.conf` | 26 | SQUID's bots (`AiPlayerbot.*`), including our `AiPlayerbot.Wildcard*` |
| `modules\mod_coa_playerbots.conf` | 1 | The CoA bots' master switch `CoaBots.Enable` |
| `modules\mod_dungeon_clear.conf` | 6 | Dungeon Clear |
| `modules\mod_ollama_chat.conf` | 37 | Bot AI chat |
| `modules\mod_ahbot.conf` | 27 | Auction house bot |
| `modules\mod-coa-challenges.conf` | 2 | Game modes; `CoAChallenges.GameModes.Realm = WildCard` is what makes the realm Wildcard |
| `modules\mod-coa-prestige.conf` | 1 | Prestige |
| `modules\dynamicxp.conf` | 2 | Experience rates |

Three pseudo-files in the list are not config files: `realm | active` (a guard: nothing is applied while the
manager has another realm active), and `realmlist | address` / `realmlist | local` (written to the auth database
by patch night, `Apply-ServerSettings.ps1:211`).

Note the hyphen/underscore mix in the names (`mod-coa-challenges.conf` but `mod_coa_playerbots.conf`): copy names
from the table, do not guess. Regenerate the table with `repo_facts.py confs`.

The upstream templates for the CoA files are in the core, not in a module folder:
`core:src/server/coa/conf/coa.conf.dist`, `wildcard.conf.dist`, `coa_bugreport.conf.dist`. (CoA's settings once
lived in `mod_ascension_compat.conf`; if that old file is still in `modules\`, start-up logs that it "is no longer
read: move its settings into coa.conf as CoA.* keys".)

### 2.2 `.conf` and `.conf.dist`

- A `.conf.dist` is the shipped template: every option, its default, and a comment. The server never reads it.
- The `.conf` beside it is what the server reads. An option missing from the `.conf` takes the default written
  **in the C++ call**, not the one in the `.dist` (the config reader may log the missing name the first time).
- All module `.conf` files are merged into one flat namespace with `worldserver.conf`
  (`ConfigMgr::LoadModulesConfigs`, `core:src/common/Configuration/Config.cpp:771`). **The file a setting is in
  does not matter to the server**; the name does. That is why our own options can sit in `worldserver.conf`. It
  matters to humans and to `Apply-ServerSettings.ps1`, which checks each setting against the `.dist` of the file
  it is listed under.
- Our own options exist in no upstream `.dist`. The settings check (22 Nov 2026,
  `Apply-ServerSettings.ps1:250` on) reports names the installed `.dist` does not know. For our patch options that
  is expected only when the patch adds them to a `.dist` (as `mystic-enchants-wildcard.patch` does for
  `coa.conf.dist`). The details are in the sibling skill `wildcard-settings-and-flags`.
- The manager rebuilds `Core\configs\worldserver.conf` from `Settings\worldserver.conf.template`, so settings for
  that file are written to both (`Apply-ServerSettings.ps1:10`). Never hand-edit a config on the server: the next
  start overwrites it from `server-settings.txt`.

### 2.3 The API: `sConfigMgr->GetOption<T>(name, default)`

```cpp
bool on = sConfigMgr->GetOption<bool>("Racials.Plainsrunning", true);
uint32 n = sConfigMgr->GetOption<uint32>("Battleground.SpoilsForWin", 3);
std::string pool = sConfigMgr->GetOption<std::string>("Wildcard.AbilityPool", "all");
```

Types used in our patches (regenerate with `repo_facts.py options`): `bool`, `uint32`, `float`, `std::string`,
one `int32`. 72 distinct option names as of 2026-11-22.

What one call costs (`ConfigMgr::GetValueDefault`, `core:src/common/Configuration/Config.cpp:554`): a lookup by
string in a map, building the matching environment-variable name (`AC_...`) and checking the environment for an
override, then converting the stored **text** to the type. It is cheap once, and not free. Called from a hook that
runs every tick for every player and bot, it is thousands of string operations per second. The environment check
also means a setting can be overridden by an `AC_<NAME>` environment variable on the server PC without any file
changing.

When a new value is seen:

| How the code reads it | New value seen after |
|---|---|
| `GetOption` called each time the feature runs | `.reload config` (or a restart) |
| Read once into a `static`, or in `OnStartup`, or at script construction | A restart only |
| A stock option cached by the core (`sWorld->getIntConfig(...)`) | `.reload config` for most: reloadable is the default, and 8 of the 549 entries in `core:src/server/game/World/WorldConfig.cpp` are marked `Reloadable::No` (`MaxPlayerLevel`, `WorldServerPort`, `Expansion`...). Some reloadable ones are still only used once: `MapUpdate.Threads` sizes the thread pool at start (`core:src/server/game/Maps/MapMgr.cpp:70`). Treat thread, port and database settings as restart-only |
| A module's own cached config (SQUID's `sPlayerbotAIConfig`) | Whatever that module supports. Treat as restart unless its `.dist` says otherwise |

`server-settings.txt` says of its own contents: "Changes take effect when the server next starts (or `.reload
config` for most of them)" (line 7), and individual comments say "Read at server start only" where that is so
(for example `DungeonClear.Enable`, line 417). Trust the comment on the setting; when there is none, read the
patch.

`.reload config` reloads the files and calls `sWorld->LoadConfigSettings(true)`
(`core:src/server/scripts/Commands/cs_reload.cpp:351`). It does not re-run `OnStartup` hooks.

## 3. Script hooks

A hook is a virtual function on a script base class. A patch adds a class that overrides the hooks it wants and
registers one object of it. The core then calls every registered script at that point.

### 3.1 Registration, and the "enabled hooks" list

```cpp
class wcme_plainsrunning : public PlayerScript {
public:
    wcme_plainsrunning() : PlayerScript("wcme_plainsrunning", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SPELL_CAST}) { }
    void OnPlayerUpdate(Player* player, uint32 diff) override { ... }
```

The second constructor argument lists which hooks this script wants. **A hook you override but do not list is
never called.** An empty list means "all hooks" (`core:src/server/game/Scripting/ScriptDefines/PlayerScript.cpp:1273`).
`UnitScript` takes an extra `bool addToScripts` before the list. Forgetting to add the enum when adding an
override compiles cleanly and does nothing at run time: check this first when a new hook "does not fire".

The script object must also be created by a function the script loader calls. Our patches add that call to an
existing loader (for CoA code, `core:src/server/coa/CoAScriptLoader.cpp`, as `mystic-enchants-actions.patch`
does).

### 3.2 The hooks our patches use (2026-11-22)

Regenerate, and check each name against the pinned core, with:

```bash
python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py --core /path/to/core hooks
```

"How often" is the thing to look at before adding code to one.

| Hook | Base class (header in `core:src/server/game/Scripting/ScriptDefines/`) | When it runs | How often | Patches using it |
|---|---|---|---|---|
| `OnPlayerUpdate` | `PlayerScript` | Inside `Player::Update` (`core:src/server/game/Entities/Player/PlayerUpdates.cpp:324`) | **Every map update, for every player and every bot** | 46, 54, 56, 57, 58, 59, 60, 72, 73, 74, 75, 76, 78, 82, 86, 90, enchant scripts |
| `ModifyMeleeDamage`, `ModifySpellDamageTaken`, `ModifyPeriodicDamageAurasTick`, `ModifyHealReceived` | `UnitScript` | Each time damage or healing is calculated | **Every hit, tick and heal in the world, creatures included** | 60, 78, enchant scripts |
| `OnDamage`, `OnBeforeHealAbsorb`, `OnAfterAuraEffectCalculateAmount` | `UnitScript` | Damage dealt, heal absorbs, aura amounts | Every hit / heal / aura amount | 54, 72, enchant scripts |
| `OnAuraApply`, `OnAuraRemove` | `UnitScript` | Any aura goes on or off any unit | Very often | 58, enchant scripts, `mystic-enchants-wildcard.patch` |
| `OnSpellCast`, `OnSpellPrepare`, `OnSpellCheckCast`, `OnSpellHitResult`, `OnSpellCritChance`, `OnSpellSuccessfulDispel` | `AllSpellScript` | Stages of **every** spell cast by anything | Very often | enchant scripts |
| `OnSpellModFamilyMask` | `GlobalScript` | Each "does this modifier affect this spell" test (`core:src/server/game/Spells/SpellInfo.cpp:1662`) | Very often | enchant scripts |
| `CanPacketReceive` | `ServerScript` | Each packet from a client, before it is handled | **Every packet** | 50 |
| `OnPlayerSpellCast` | `PlayerScript` | A player (or bot) casts | Per cast | 54, 56, 59, 74, 75 |
| `OnUnitSetShapeshiftForm`, `OnPlayerAfterUpdateMaxPower` | `UnitScript`, `PlayerScript` | Form change; max power recalculated | Per event | enchant scripts |
| `OnPlayerCreatureKill`, `OnPlayerPVPKill`, `OnPlayerRewardKillRewarder` | `PlayerScript` | Kills and their rewards | Per kill | 40, 47, 56, 72, 78, 93 |
| `OnPlayerGiveXP`, `OnPlayerGiveReputation` | `PlayerScript` | XP or reputation about to be given | Per gain | 45, 76 |
| `OnAfterLootTemplateProcess` | `MiscScript` | Loot generated from a template | Per loot roll | 45, 51, 78 |
| `OnPlayerLootItem`, `OnPlayerStoreNewItem`, `OnPlayerCreateItem`, `OnPlayerGroupRollRewardItem`, `OnPlayerQuestRewardItem`, `OnPlayerBeforeSendLoot` | `PlayerScript` | An item reaches a player, by each route | Per item | 30, 45, 48, 76 |
| `OnPlayerUpdateGatheringSkill`, `OnPlayerUpdateCraftingSkill` | `PlayerScript` | Profession skill-up checks | Per gather / craft | 45, 51, 76 |
| `OnPlayerCanAreaExploreAndOutdoor` | `PlayerScript` | Area exploration check | Per area update | 76 |
| `OnPlayerCanUseChat` | `PlayerScript` | A player sends chat | Per message | 51, `mystic-enchants-wildcard.patch` |
| `OnPlayerLearnSpell` | `PlayerScript` | A spell is learned | Per learn | `mystic-enchants-wildcard.patch` |
| `OnPlayerGossipSelect` | `PlayerScript` | A gossip menu choice | Per click | 49 |
| `OnPlayerLogin`, `OnPlayerLogout` | `PlayerScript` | Enter / leave world. **Bots log in and out too** | Per login | 45, 46, 49, 51, 62, 82, 86, `mystic-enchants-wildcard.patch` |
| `OnBattlegroundEndReward` | `AllBattlegroundScript` | End of a battleground, per player | Per game | 40 |
| `OnPlayerCoAPrestigeSaved` | `PlayerScript` (a CoA addition) | A prestige is recorded | Rare | 47 |
| `OnUse` | `ItemScript` | An item with that script name is used | Per use | 50 |
| `OnStartup` | `WorldScript` | Once, after the world has loaded | Once | 47, 49, 51, `mystic-enchants-actions.patch`, `wildcard-ability-pool.patch` |

Two names the script reports as "not a core hook" are not hooks: `CanSurge` is a helper inside
`60-manaforged-barrier.ps1`, and `OnTreasureKeeperKilled` is a method of the Manastorm module's
`ManastormRewards` class that `84-treasure-keeper-instant-reward.ps1` uses as its anchor.

Not everything is a hook. Many patches edit core functions in place with `Edit-Core` (for example
`63-enchant-target-cooldowns.ps1` edits `SpellAuras.cpp`, `52-racials.ps1` edits `SpellInfoCorrections.cpp`).
For those, "how often" is whatever calls the edited function.

## 4. The world update loop

```
WorldUpdateLoop()                      core:src/server/apps/worldserver/Main.cpp:587   (one thread: "the world thread")
  loop:
    diff = ms since last pass          (sleeps if diff < MinWorldUpdateTime, default 1 ms)
    World::Update(diff)                core:src/server/game/World/World.cpp:1131
      UpdateSessions(diff)             every session's queued packets (world thread)
      MapMgr::Update(diff)             core:src/server/game/Maps/MapMgr.cpp:441
        for each map: schedule on the MapUpdater thread pool   (MapUpdate.Threads workers)
        wait until EVERY map has finished                      <- the tick cannot be shorter than the slowest map
      battlegrounds, outdoor PvP, LFG  (world thread)
      ProcessQueryCallbacks()          results of async database queries (world thread)
      ProcessCliCommands()             console / RA commands (world thread)
      sScriptMgr->OnWorldUpdate(diff)  module world scripts, e.g. SQUID's bot manager (world thread)
```

Terms: one pass is a **tick**. **diff** is the time the previous pass took, in milliseconds; it is what the
manager's "World speed" panel and `Logger.time.update` report (`server-settings.txt:395`).

Facts that follow from the shape:

1. **One map is updated by one thread at a time.** Eastern Kingdoms is one map, Kalimdor is one map; each dungeon
   copy is its own. With 6 map threads (`MapUpdate.Threads = 6`, `server-settings.txt:495`; the core default is 1)
   maps run side by side, but a crowded continent is still one thread. `docs/performance.md`: "Memory is not the
   limit; one busy thread per map is (most bots are on Eastern Kingdoms and Kalimdor)".
2. **The tick waits for the slowest map.** A stall in one map (a slow script, a synchronous database query, a
   path-finding storm) is a stall for everyone, on every map.
3. **Anything on the world thread delays every map's next update.** Packets, console commands and query callbacks
   are handled there.
4. **`Player::Update` runs on a map thread.** So `OnPlayerUpdate`, the `Modify*Damage` hooks and spell scripts for
   two players on different maps run **at the same time on different threads**. Shared state in a patch (a
   `static` map, a counter) needs a lock or must be per-player. `47-leaderboards.ps1` guards its table of firsts
   with a `std::mutex` for this reason; several patches keep their state as members added to `Player` instead
   (`player->WcmeRuneTabTimer` in `82-runes-in-currency-tab.ps1`).
5. **A synchronous database query inside a tick blocks that thread until MySQL answers.** `CharacterDatabase.Query`
   and `WorldDatabase.Query` are synchronous; `.Execute` is queued and returns at once. The core turns on a
   warning for sync queries once the loop starts (`WarnAboutSyncQueries(true)`, `Main.cpp:598`). Our patches query
   at start-up (`OnStartup`), at login, or on rare events, and write with `Execute`. Keep it that way.
6. **Logging can run in line with the tick.** `Log.Async.Enable = 1` (`server-settings.txt:520`) was set on
   20 Nov 2026 (`f9dc45a`) to move it to its own thread, after a 2.9 GB console log and a 99th-percentile tick of
   586 ms were measured (the comment block above that setting). The change shipped with no after-measurement;
   `world-console.log` was 2.99 GB on 22 Nov, and that day's server start (08:53) predates the merges of #229 to
   #231, so the console-log clear and rotation had not run yet. Status OPEN (`wildcard-failure-archaeology`, F-10).

### 4.1 Why per-tick and per-packet code is "hot", in numbers

A hook that runs per player per tick runs `players x ticks per second` times.

| Situation (from the repository) | Rough call rate for one `OnPlayerUpdate` script |
|---|---|
| 750 bots, median tick 36 ms (`server-settings.txt:506`) | 750 x about 28 ticks/s = about 21,000 calls per second |
| 16 patch scripts plus the enchant scripts override it | Multiply by the number of scripts that are enabled |

That is why a 2-microsecond body is fine and a body that reads three settings, walks the aura list and builds a
string is not. It is also why the risk matrix scores "every tick, every packet, or for all 750 bots" as the
highest likelihood class (L3 = 3, `docs/agents/context/change-risk.md`).

The standard ways to stay cheap, all used somewhere in `patches/`:

| Technique | Example |
|---|---|
| Leave at once for the players it does not concern | `if (player->getRace() != RACE_TAUREN) return;` (`54-racial-plainsrunning.ps1`) |
| Accumulate `diff` and act every N ms | `player->WcmeRuneTabTimer += diff; if (... < 2000) return;` (`82-runes-in-currency-tab.ps1:45`) |
| Skip bots when the feature is for people | `if (!player->GetSession() || player->GetSession()->IsBot()) return;` (`46-play-time-rewards.ps1:46`) |
| List only the hooks you need in the constructor | Section 3.1 |
| Read data once at start-up into memory | `mystic-enchants-actions.patch` loads `wcme_enchant_action` in `OnStartup` |

Observation, not a verdict (2026-11-22): several per-tick hooks still call `GetOption` on every pass (for example
`54-racial-plainsrunning.ps1:229`), and the racial hooks run for bots because a bot has a race like anyone else.
Whether either costs enough to matter is a measurement question: take it to `wildcard-lag-spike-campaign` and
`wildcard-diagnostics-and-tooling`, do not "optimise" from this note.

### 4.2 How 750 bots multiply cost

- A SQUID bot is a real `Player` with a `WorldSession` that has no network socket. Every `PlayerScript`,
  `UnitScript` and spell hook fires for it exactly as for a person.
- Each bot's AI runs inside its own map's update, in `OnPlayerAfterUpdate` (`squid:src/Script/Playerbots.cpp:249`),
  so the bots of one continent share that continent's single thread. The bot manager itself runs on the world
  thread (`sRandomPlayerbotMgr.UpdateAI`, line 546, commented "World thread only").
- "Asleep" is not "free": `docs/performance.md` notes that sleeping bots still cost a basic update every tick, so
  the total count matters as well as the active share.
- Every bot login, save and logout is a set of characters-database queries. With 1,250 bots these queued in front
  of real players' character lists until the worker thread counts were raised
  (`CharacterDatabase.WorkerThreads = 4`, `server-settings.txt:499-504`).
- Visibility multiplies too: each bot "sees" every unit in view distance, so raising
  `Visibility.Distance.Continents` raises the work for all 750 (`server-settings.txt:496-498`).

## 5. Re-verification

```bash
# From the pinned core
grep -n "^void WorldUpdateLoop" -A40 src/server/apps/worldserver/Main.cpp | grep -n "sWorld->Update\|MinWorldUpdateTime\|WarnAboutSyncQueries"
grep -n "sMapMgr->Update\|UpdateSessions(diff)\|ProcessCliCommands\|ProcessQueryCallbacks\|OnWorldUpdate" src/server/game/World/World.cpp
grep -n "schedule_update\|m_updater.wait" src/server/game/Maps/MapMgr.cpp
grep -n "OnPlayerUpdate\|OnPlayerAfterUpdate" src/server/game/Entities/Player/PlayerUpdates.cpp
grep -n "If empty - enable all available hooks" -r src/server/game/Scripting/ScriptDefines | head -3
grep -c "Reloadable::No" src/server/game/World/WorldConfig.cpp
# From the pinned SQUID bots
grep -n "OnPlayerAfterUpdate\|World thread only" src/Script/Playerbots.cpp
# From this repository
python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py confs options
git grep -c "void OnPlayerUpdate(" -- patches
git grep -n "MapUpdate.Threads\|Log.Async.Enable\|MinRandomBots" -- server-settings/server-settings.txt
```
