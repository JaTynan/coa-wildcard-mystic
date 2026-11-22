# CoA specifics, the module set, playerbots, and the client

Read this when you need to know which piece of software a behaviour belongs to (the CoA core, a CoA module,
SQUID's bots, the client) before you decide where a fix can go, or when a bot does something a player-only
feature did not expect.

`core:` = the pinned CoA core at `c3f2fd4b`; `squid:` = the pinned SQUID bots at `4ef5ed9e`
(release `server-0.261119.114`). Checked 2026-11-22.

## 1. What is in one build

The build (`.github/workflows/build-worldserver.yml`) assembles one `worldserver.exe` from these sources, at the
exact commits the manager's release names (`scripts/resolve_release.py`), then lays our patches on top.

| Part | Repository | What it is | State on this realm |
|---|---|---|---|
| Core | `Corfirean/azerothcore-wotlk-coa` | AzerothCore 3.3.5a with the CoA server component in `src/server/coa/` and 38 bundled modules in `modules/` | The base. Our patch scripts name files under `src/server/game` 53 times and under `src/server/coa` 45 times |
| CoA bots ("CoA Companions") | `Corfirean/mod-coa-playerbots` | A bot system written for the 21 CoA classes | Compiled in, **off**: `CoaBots.Enable = 0` (`server-settings.txt:413`) |
| Content Scaling | `Corfirean/mod-coa-content-scaling` | Scales creatures, items, spells and quests at run time to the realm's level cap and the group's size, without rewriting database rows. Diagnostic command `.coascale` | Compiled in |
| Content packs | `mod-coa-tbc-content`, `mod-coa-wotlk-content` (folders inside the scaling repository) | Outland and Northrend content for the scaling engine | Compiled in |
| SQUID's bots | `Zyth45/mod-playerbots` (tag v3.0 at the pin) | A fork of mod-playerbots: bots that are full player characters, with CoA class, Wildcard Hero and raid support | **On**: `AiPlayerbot.Enabled = 1`, 750 random bots |
| Dungeon Clear | `Zyth45/mod-dungeon-clear` | A tank bot leads its party through a dungeon, boss to boss. Needs SQUID's bots. Part of the official build since `server-0.261119.114` | On: `DungeonClear.Enable = 1` |
| AI chat | `DustinHendrickson/mod-ollama-chat` at `906eb2a4` (pinned in the workflow, not by the release) | Bots talk through a local language model | Our addition; made to compile by `patches/10-mod-ollama-chat-fit.ps1` |

Two things about the assembly order matter to anyone writing a patch:

- The official build's own module patches (`squid-coa-validation.patch`, `dungeon-clear-coa-validation.patch`,
  from `Corfirean/coa-server-build`) are applied to SQUID and Dungeon Clear **before** our scripts, checksum
  verified. Without the SQUID one, SQUID and the core's `mod-ah-bot-plus` both register `.ahbot` sub-commands and
  the world server stops at start-up with "Duplicate blank sub-command" (19 Nov 2026, workflow comment).
- The CoA bots and Content Scaling are copied into `core/modules/` **after** our `patches/*.ps1` run. As of
  2026-11-22 no patch of ours edits either (regenerate the list of edited trees with the grep in section 6).

## 2. What CoA adds to AzerothCore that matters here

All paths are under `core:src/server/coa/` unless marked. The folder holds 754 files; these are the ones this
project keeps coming back to.

| System | Files | What to know |
|---|---|---|
| Mystic Enchants: state and UI protocol | `AscensionMysticEnchant.cpp` (1,363 lines) | Loads the catalogue, keeps each character's slots, applies each slotted enchant as an aura (`SyncAuras`), teaches and removes taught spells, checks the altar (within 10 yards of one of 24 game object entries), answers the client's enchant window. Our `mystic-enchants-wildcard.patch` edits this file. |
| Mystic Enchants: rules | `AscensionMysticEnchantRules.cpp/.h` | Pure rule code: reads `MysticEnchant.dbc`, quality caps, class and realm gates, reforge pools and the weighted `Roll`. `HERO_CLASS = 10`, `WILDCARD_MODE = 0x40`, `SLOT_COUNT = 17`. Stock rule: several checks refuse Wildcard characters outright (`character.Wildcard()`), which is what our patch lifts behind `CoA.MysticEnchants.AllowWildcard`. |
| Mystic Enchants: data-driven procs | `AscensionMysticEnchantProcs.cpp` | Reads `coa_mystic_enchant_proc`, `coa_mystic_enchant_aura_link`, `coa_mystic_enchant_minion_aura`. |
| Mystic Enchants: hard-coded behaviour | `AscensionMysticEnchantBonus.cpp`, `...Mechanics.cpp`, `...Scripts.cpp` | Per-enchant C++ (`spell_ascension_mystic_*` scripts and global hooks). An enchant that works **only** through these looks like a dud to our filter; `wcme_enchant_override` keeps such enchants in the rolls. Before writing a script for an enchant, grep here: the core may already handle it, and a second handler doubles the effect. |
| Wildcard | `AscensionWildcard.cpp` (3,809 lines), `AscensionWildcard.h`, `AscensionWildcardSkillcards.cpp`, `AscensionWildcardStarterData.h`, about 20 `AscensionWildcard<Ability>.cpp` | Starting abilities, level rolls, rerolls, skill cards, Scrolls of Fortune. `IsWildcardHero(player)` is the test for "a class-10 character in Wildcard mode". `wildcard-ability-pool.patch` edits the roll pool. |
| Hero class behaviour | `AscensionHeroClass.h`, `AscensionHero<Class>.cpp` | How a classless Hero answers "are you a warrior / hunter / ...?" questions the stock code asks (reactive abilities, pets, relics, shields). |
| Character Advancement | `AscensionFreepick.cpp`, `AscensionFreepickRules.cpp` | The ability and talent catalogue (client DBCs `CharacterAdvancement*.dbc`), realm types, class models. `ReadRealm()` parses `CoA.RealmType` and `CoA.ClassModel`. |
| Rulesets | `AscensionHighRisk.cpp`, `AscensionHighRiskPolicy.h`, `AscensionMercenary.cpp` | PvE / War Mode / High Risk auras, Mercenary. |
| Manastorm | `AscensionManastorm.cpp` and headers; modules `mod-manastorm-endless`, `mod-treasure-keeper` | Floors, caches, the Treasure Keeper. Design notes: `core:docs/coa/manastorm.md`. |
| Scaling inside the core | `CoACreatureScaling.cpp`, `AscensionItemScaling.cpp`, `AscensionQuestScaling.cpp` | Separate from the external Content Scaling module. Two systems scale things: check which one before changing a number. |
| Prestige | module `mod-coa-prestige` | Fires the CoA hook `OnPlayerCoAPrestigeSaved` that `47-leaderboards.ps1` listens to. |
| Game modes | module `mod-coa-challenges` | `CoAChallenges.GameModes.Realm = WildCard` makes Wildcard realm-wide. Without it Wildcard is only a per-character challenge and SQUID creates bots in CoA classes (`server-settings.txt:13-17`). |
| Custom races | module `mod-coa-custom-races` | Extra races; when enabled the server prefers DBC files from `DataDir/dbc_races/` (`core:src/server/game/DataStores/DBCStores.cpp:290-300`). |
| Protocol extensions | `AscensionCompat.cpp` | The client is Ascension's, not stock 3.3.5a: it speaks extra opcodes (numbers 1311 to 2515 by default, `CoA.FirstExtensionOpcode` / `LastExtensionOpcode`) and is told the realm type and class model at the character list. `CoA.AllowRemoteClients = 1` applies this to non-local connections (`server-settings.txt:407`). |

### Class IDs

| ID | Class |
|---|---|
| 1 to 9, 11 | Stock: Warrior, Paladin, Hunter, Rogue, Priest, Death Knight, Shaman, Mage, Warlock, Druid |
| **10** | **Hero** (`CLASS_HERO`). Every character and every SQUID bot on this realm |
| 12 to 32 | CoA classes: Barbarian 12, Witch Doctor 13, Felsworn 14, Witch Hunter 15, Stormbringer 16, Knight of Xoroth 17, Guardian 18, Templar 19, Bloodmage 20, Ranger 21, Chronomancer 22, Necromancer 23, Pyromancer 24, Cultist 25, Starcaller 26, Sun Cleric 27, Tinker 28, Venomancer 29, Reaper 30, Primalist 31, Runemaster 32 |

`MAX_CLASSES` is 33 (`core:src/server/shared/SharedDefines.h:184`). The enum names do not always match the titles
(`CLASS_DEMON_HUNTER` is the Felsworn, `CLASS_MONK` the Templar, `CLASS_SON_OF_ARUGAL` the Bloodmage,
`CLASS_PROPHET` the Venomancer): search by number.

Why class 10 is a trap: code and data written per class (a table of spec names, a lookup of which class can use a
shield, a bot strategy picked by class) usually has rows for 1 to 9, 11 and 12 to 32, and nothing for 10. The
core answers such questions for Heroes by asking which abilities the character actually owns
(`AscensionHeroClass::Answer`). `docs/agents/context/patches.md` item 5 records a shield and stance bug of
22 Nov 2026 from exactly this. Helpers:

| Question | Call | Where |
|---|---|---|
| Is this a class-10 character in Wildcard mode? | `AscensionWildcard::IsWildcardHero(player)` | Core code; used in `mystic-enchants-wildcard.patch` |
| Is this bot a Wildcard Hero? | `IsWildcardHeroBot(bot)` | SQUID code (`squid:src/Ai/Class/Coa/CoaWildcard.cpp:735`); used in `patches/20-bots.ps1` |
| Is this one of the 21 CoA classes? | `IsAscensionClass(classId)` | `core:src/server/shared/SharedDefines.h:189` |

### The realm's identity settings (do not change casually)

From `server-settings.txt:13-26`; these are what the manager sets when it creates a Wildcard realm.

| Setting | Value | Effect |
|---|---|---|
| `CoAChallenges.GameModes.Realm` | `WildCard` | Wildcard for the whole realm |
| `CoA.GameModeMask` | `64` | The Wildcard bit (2 Ironman, 8 Draft, 32 Resolute, 64 Wildcard, 128 Felforged, 256 Nightmare...) |
| `CoA.ClassModel` | `"hero"` | The classless character creator |
| `CoA.MapClass10ToWarrior` | `0` | Create real Heroes (1 would create a warrior shell instead) |
| `CoA.RealmType` | `"live seasonal"` | Which client rows are visible; also switches the core's enchant twins on (references/spell-system.md section 7) |
| `PlayerStart.CustomSpells`, `AlwaysMaxSkillForLevel` | `1` | Starting abilities; weapon skills maxed |

Open observation (2026-11-22, not a recommendation): the upstream template `core:src/server/coa/conf/wildcard.conf.dist`
lists `CoA.RealmType = "league"` for a Wildcard realm and explains that Wildcard-only Character Advancement
entries are flagged league, so "on a live or seasonal realm the client hides entries the server still rolls".
This server runs `"live seasonal"`, the value recorded from the manager on 30 Oct 2026 (commit `42290ca`). Whether
that difference explains any missing ability in the client is UNVERIFIED. It is a realm-identity setting: do not
test it on the live realm; classify with `wildcard-change-control` first.

## 3. Playerbots

### 3.1 Two bot systems

| | SQUID's bots (`mod-playerbots`) | CoA bots (`mod-coa-playerbots`) |
|---|---|---|
| Config | `modules\playerbots.conf`, options `AiPlayerbot.*` | `modules\mod_coa_playerbots.conf`, options `CoaBots.*` |
| State here | On, 750 random bots, all Wildcard Heroes | Off |
| Who switches them | `server-settings.txt:412-413` | Same |
| Our patches | `20-bots`, `61`, `87`, `92`, `96` edit `core/modules/mod-playerbots`; `90` edits Dungeon Clear; settings `AiPlayerbot.Wildcard*` | None |

The manager turns **both** systems off on a Wildcard realm every time its own Start button is used. The server
must be started with `patch-night\Start-Server.cmd` (or by patch night) to keep SQUID's bots on (README.md,
"SQUID's bots on Wildcard"). A world that comes up with no bots usually means someone pressed Start in the
manager.

### 3.2 Kinds of bot (SQUID)

| Kind | What it is | Master |
|---|---|---|
| Random bot | A character on a bot account, logged in by the server, living its own life | None, until a player invites and commands it |
| Altbot | A character on a player's own account, logged in as a bot | That player |
| Addclass bot | A levelled, geared bot from a reserved pool, summoned into a party | The summoner |
| Selfbot | A real player's own character with bot AI switched on | Itself |

Every bot is a `Player` object with a `WorldSession` created with the bot flag and no network socket
(`squid:src/Bot/PlayerbotMgr.cpp:274`). So the core treats it as a logged-in player: it earns rewards, triggers
hooks, and receives whispers and mail. `/who` hides bots here only because `Who.ShowBots = 0` is set (`server-settings.txt:618`).

### 3.3 Guards: telling a bot from a person

Use the guard that exists where your code lives. Core code cannot include SQUID's headers.

| Where the code is | Guard | Meaning | Used in |
|---|---|---|---|
| Core or CoA code (`src/server/...`) | `player->GetSession() && !player->GetSession()->IsBot()` | A real, connected person. `IsBot()` is `core:src/server/game/Server/WorldSession.h:1301` | `40`, `45`, `46`, `47`, `48`, `49`, `51`, `90` |
| SQUID module code | `IsRealPlayer(player)` | True when no bot AI is attached at all. Null-safe (`squid:src/Bot/PlayerbotAI.cpp:5292`) | `20-bots`, `96` |
| SQUID module code | `GET_PLAYERBOT_AI(player)` | The bot's AI object, or null for a person (`squid:src/Script/Playerbots.h:31`) | `20-bots`, `61`, `90` |
| SQUID module code | `botAI->HasGameClientMaster()` | The bot's master is a person at a keyboard (a real player or a selfbot) | `20-bots` |
| SQUID module code | `sRandomPlayerbotMgr.IsRandomBot(player)` | A random bot specifically (not an altbot or selfbot) | SQUID's own code |
| SQUID module code | `botAI->IsAltBot()`, `IsSelfBot(player)` | The other kinds | SQUID's own code |

Always test `GetSession()` for null before `IsBot()`: every use in `patches/` does. Regenerate the usage list with
`repo_facts.py bots`.

Questions to ask of any player-facing patch (from `docs/agents/context/patches.md` item 4):

1. Does it give a reward (gold, item, currency, XP, a leaderboard entry)? Then bots must be excluded, or 750 bots
   farm it. Rewards outside normal play are also a hard stop in the risk matrix.
2. Does it whisper, mail or pop a window? A bot has no client to show it, and nobody empties a bot's mailbox.
3. Does it run per tick? Then it runs 750 times more than you pictured
   (references/hooks-config-and-loop.md section 4).
4. Does it assume a class? Every bot here is class 10.
5. Does it assume a master? A random bot's `GetMaster()` can be null; a bot in a battleground must not answer
   "I have a master already" to a stranger (`61-bg-bot-whispers.ps1`).

### 3.4 The settings that drive cost

Values as of 2026-11-22; the story behind each is in the comment above it in `server-settings.txt`.

| Setting | Here | SQUID default at the pin | What it does to load |
|---|---|---|---|
| `AiPlayerbot.MinRandomBots` / `MaxRandomBots` | 750 / 750 | 500 / 500 | The total. Sleeping bots still cost a basic update each tick |
| `AiPlayerbot.BotActiveAlone` | 5 | 60 | Rough percent of bots awake when no player is near. The biggest single lever |
| `AiPlayerbot.BotActiveAloneForceWhenInZone` | 1 | 1 | Every bot in a real player's zone stays awake. Costly with players spread over zones; turning it off froze nearby bots on 8 Nov 2026, so it is back on until understood |
| `AiPlayerbot.BotActiveAloneForceWhenInRadius` | 300 | 150 | Bots within this many yards of a player stay awake |
| `AiPlayerbot.botActiveAloneSmartScale` (+ `...DiffLimitfloor`, `...DiffLimitCeiling`) | not set here: default 1, 50, 200 | 1, 50, 200 | Automatic throttle: fewer awake bots as tick time rises from 50 ms, none but forced ones at 200 ms. Note the lower-case `b` in the option name |
| `AiPlayerbot.RandomBotConcentrateInPlayerZone` | 1 | 0 | Bots move to where players level: livelier zones, and more awake bots around each player |
| `AiPlayerbot.DisabledWithoutRealPlayer` | 1 | 0 | Bots log in with the first player and out 5 minutes after the last. Every first login of the day starts a wave of bot logins |
| `AiPlayerbot.RandomBotGroupNearby` + `AiPlayerbot.WildcardGroup*Pct` | on; 50 / 30 / 15 / 5 | off | Bot groups. The setting's comment says grouped bots away from players still sleep |
| `MapUpdate.Threads` | 6 | core default 1 | Maps updated in parallel |
| `Visibility.Distance.Continents` | 100 | | Every bot sees this far too |
| `CharacterDatabase.WorkerThreads` / `SynchThreads`, `LoginDatabase.WorkerThreads` | 4 / 2 / 2 | | Lets players' queries through alongside bot logins and saves |
| `Log.Async.Enable` | 1 | | Log writing off the world thread |

Measured numbers that exist in the repository (do not invent others): `docs/performance.md` (7 Nov 2026 table,
1,000 to 1,500 bots, 1 and 4 map threads) and the comments at `server-settings.txt:467-520`. How to measure, and
the spike investigation itself, belong to `wildcard-diagnostics-and-tooling` and `wildcard-lag-spike-campaign`.

## 4. The client side

### 4.1 Two copies of the truth

The player's client and the server each hold their own copy of the game's tables and never compare them.

| Data | The client reads | The server reads |
|---|---|---|
| Spells | `DBFilesClient\Spell.dbc` inside its MPQ archives | `DataDir/dbc/Spell.dbc`, then the `spell_dbc` table over it |
| Enchant catalogue | `MysticEnchant.dbc` in its MPQs | The file `DataDir/dbc/MysticEnchant.dbc`, read raw; no table override |
| Tooltips, names, icons | Its own `Spell.dbc` text and `SpellIcon.dbc` | Not used for behaviour (one exception: the "Teaches you" scan, references/spell-system.md section 1) |
| What a spell does | Nothing: it only predicts and displays | Everything |
| Cooldowns, global cooldown, range, cost, "can I cast this now" | **Its own copy, checked before it even sends the cast** | Checked again on arrival |

So the two can disagree, in both directions:

| Symptom | Cause | Fix lives in |
|---|---|---|
| The enchant works but shows no name, icon or tooltip (or `GetSpellInfo(id)` returns nil in an addon) | The spell exists only in `spell_dbc` | Client patch (`client-patch/build_client_patch.py`) |
| The tooltip promises something else than what happens | We restored the enchant through a twin whose text differs, or the tooltip was always ahead of the code | `addon/WildcardEnchants/TooltipData.lua` shows the twin's text; otherwise a server fix |
| The button is greyed out or "not ready" though the server would allow it | The client's own cooldown, global cooldown or requirement data | Client patch. This is why `patches/52-racials.ps1` has a client twin in `client-patch/racials.py` |
| A price, a limit or a tab shown by the client differs from what the server does | The client has its own copy of some rules and config values | Server sends the value where the protocol allows (`79-mystic-enchant-gold-cost.ps1` names prices in the client config), else an addon |
| The Mystic Enchant tab is missing for Wildcard characters | The client hides it and blocks its own checks for Wildcard | The `WildcardEnchants` addon (README.md) |

Rule of thumb: **a number the player can see before pressing the button is the client's; what happens after is
the server's.** A change that must alter both needs both a patch and a client change, or they will disagree.
Which may ship how is the business of `wildcard-client-and-web`.

### 4.2 MPQ load order

When the same file (say `DBFilesClient\Spell.dbc`) is in several of the client's archives, one archive wins. As
the repository records it (`docs/enchant-restoration.md`, "Client patch"), a later name beats an earlier one:

- `Data/area-52/patch-D.MPQ`: the spell list used only on Ascension's Area 52 realm.
- `Data/patch-T.MPQ`: the spell list used everywhere else, including this server.
- `Data/patch-ZZW.MPQ`: ours. It sorts after `patch-T`, so its files replace `patch-T`'s.

`patch-ZZW.MPQ` as built on 2026-11-22 carries: `Spell.dbc` (the Wildcard list, plus the enchant spells missing
from it copied from the Area 52 list, plus racial changes, plus our own spells with IDs from 9990001), rows added
to `SpellIcon.dbc`, `SpellVisual.dbc` and `SpellVisualKit.dbc` for race-kit effects, and a few recoloured icon
files (`client-patch/*.py`).

Hard-won details:

- The copied enchant spells carry **no class family and no class flags** in the client copy (fields 208 to 211
  zeroed). With them the character-creation screen crashed, because it gathers spells by class (fixed and tested
  7 Nov 2026). The server copy keeps or omits its masks independently.
- The archive is built from the player's own client data and is **never published** in this public repository.
  Only the builder is.
- A custom spell must exist on both sides with the same ID: `client-patch/custom_spells.py` writes the client row
  and prints the SQL for `sql/enchants/150-custom-spells.sql`. Change one without the other and the buff has no
  icon, or the icon has no buff.
- UNVERIFIED in this repository: the complete list of archives in the client and their exact order beyond the
  three above. To check, list `F:\CoAClient\Data\*.MPQ` on the server PC and sort by name.

### 4.3 Addons and API level

- The client is Ascension's build of 3.3.5. Addons declare `## Interface: 30300`
  (all three of ours do: `addon/*/*.toc`).
- Only the 3.3.5 Lua API exists, plus whatever Ascension's client added. Anything from later WoW versions
  (`C_Timer` and the other `C_*` namespaces, for example) should be assumed absent. Check that a function
  exists in the 3.3.5 API, or test it in this client, before using it.
- `GetSpellInfo(id)` returns nil for a spell the client does not have: the test for "did the client patch land"
  used on 2 Nov 2026 was `GetSpellInfo(911367)`.
- Third-party addons are never stored in the repository; `addon/third-party-addons.txt` pins each to a commit and
  patch night downloads it.

## 5. Where a fix can live: quick placement table

| The wrong behaviour is... | It belongs to | Our lever |
|---|---|---|
| What a spell or enchant does | Server spell data or C++ | `sql/enchants/` or a patch (`ascension-restoration`, `wildcard-patch-authoring`) |
| A number in a tooltip, an icon, a greyed-out button | Client | Client patch or addon (`wildcard-client-and-web`) |
| A rate, a limit, a switch | Config | `server-settings.txt` (`wildcard-settings-and-flags`) |
| What a bot does | SQUID's module | A patch on `core/modules/mod-playerbots`, or `playerbots.conf` |
| Creature or item strength | The core's scaling or the Content Scaling module | Check which first; settings before code |
| A bug in CoA itself that is not Wildcard-specific | Upstream | Report it (`wildcard-docs-and-publishing`); patch locally only if it cannot wait |

Every one of these changes server behaviour: classify with `wildcard-change-control` first. James merges.

## 6. Re-verification

```bash
# Pinned commits of every part
python3 -I scripts/resolve_release.py latest
# The module set and order of assembly
grep -n "repository:\|content-packs\|ref: 906eb2a" .github/workflows/build-worldserver.yml
# Which source trees our patch scripts edit
grep -ho "core/[A-Za-z0-9_/.-]*" patches/*.ps1 | awk -F/ '{print ($2=="modules") ? $1"/"$2"/"$3 : $1"/"$2"/"$3"/"$4}' | sort | uniq -c | sort -rn
# Bot switches and cost settings
grep -n "AiPlayerbot.Enabled\|CoaBots.Enable\|BotActiveAlone\|RandomBots\|MapUpdate.Threads" server-settings/server-settings.txt
python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py bots

# In the pinned core
grep -n "CLASS_HERO\|CLASS_BARBARIAN\|CLASS_SPIRIT_MAGE\|define MAX_CLASSES" src/server/shared/SharedDefines.h
grep -n "HERO_CLASS\|WILDCARD_MODE\|SLOT_COUNT" src/server/coa/AscensionMysticEnchantRules.h
grep -n "^bool IsWildcardHero" -A6 src/server/coa/AscensionWildcard.cpp
grep -n "CoA.RealmType" -B3 -A3 src/server/coa/conf/wildcard.conf.dist src/server/coa/AscensionFreepick.cpp
ls modules | wc -l; ls src/server/coa | wc -l
# In the pinned SQUID bots
grep -n "^bool IsRealPlayer\|^bool IsSelfBot\|bool PlayerbotAI::IsAltBot\|bool PlayerbotAI::HasGameClientMaster" src/Bot/PlayerbotAI.cpp
grep -n "^AiPlayerbot.BotActiveAlone\|^AiPlayerbot.botActiveAloneSmartScale\|^AiPlayerbot.M..RandomBots" conf/playerbots.conf.dist
```
