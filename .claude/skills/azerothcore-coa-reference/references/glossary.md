# Glossary: every term a newcomer meets on this project

Plain-English definitions, each tied to where the term shows up in this repository or in the pinned sources.
`core:` means a path in the pinned CoA core (`Corfirean/azerothcore-wotlk-coa`), `squid:` a path in the pinned
SQUID bots (`Zyth45/mod-playerbots`). Pinned commits and how to open them are in SKILL.md, "Open the pinned
sources". Checked on 2026-11-22 against release `server-0.261119.114`.

## The game engine (AzerothCore)

| Term | What it means | Where you meet it here |
|---|---|---|
| AzerothCore (AC) | Open-source server for World of Warcraft 3.3.5a, written in C++, storing its data in MySQL. | The base under everything. `core:AGENTS.md` line 3. |
| core | The server's own C++ source, as opposed to modules. Here "the core" is the CoA fork of AzerothCore. | `patches/` edits it at build time. |
| module | An add-on source folder under `core:modules/`, compiled into the same `worldserver.exe`. Each may ship its own `.conf.dist`. | SQUID's bots, Dungeon Clear and AI chat are modules. |
| authserver | The small login program (port 3724). Checks the password, hands out the realm list. | `server-settings.txt` sets one option in `authserver.conf`. |
| worldserver | The big program that runs the game world (port 8085). Everything in `patches/` ends up inside it. | The build produces a patched `worldserver.exe`. |
| realm | One game world a player picks at login: a row in the auth database's `realmlist` table plus its own world and characters databases. | This server's realm is "Wildcard", `RealmID = 2` (`server-settings.txt:24`). |
| auth / characters / world database | The three MySQL databases. Auth: accounts and realm list. Characters: everything players own. World: game content and rules (spells, loot, quests). | See SKILL.md section 4. |
| DBC | "Database client" file: a binary table shipped inside the game client (`Spell.dbc`, `MysticEnchant.dbc`). The server keeps its own copy of the files it needs in `DataDir/dbc/`. | `core:src/server/game/DataStores/DBCStores.cpp:289`. |
| `*_dbc` table | A world-database table whose rows replace or add to the matching DBC file when the server starts. `spell_dbc` is the one for `Spell.dbc`. | All our rebuilt spells are `spell_dbc` rows (`sql/enchants/009`, `011`, `150`). |
| MPQ | The client's archive format. DBC files, icons and interface files live inside `*.MPQ` files in the client's `Data` folder. | `client-patch/build_client_patch.py` writes `patch-ZZW.MPQ`. |
| spell | Any ability, buff, passive, talent effect, item effect or enchant. Identified by a number (spell ID). | Every Mystic Enchant is a spell. |
| SpellInfo | The server's in-memory record of one spell, built at start-up from `Spell.dbc` plus `spell_dbc`, then adjusted by code. Read-only while the server runs. | `core:src/server/game/Spells/SpellInfo.h`; `sSpellMgr->GetSpellInfo(id)`. |
| effect | One of up to three things a spell does (`MAX_SPELL_EFFECTS` is 3). Each has a type number: deal damage, apply an aura, trigger another spell, dummy... | `core:src/server/shared/DataStores/DBCStructure.h:1673`. |
| aura | A lasting effect sitting on a unit: a buff, a debuff, a passive. Created by an "apply aura" effect (type 6). Each aura effect has an aura type number that says what it does. | A slotted Mystic Enchant is an aura on the player, which is why `.aura <spell>` tests one. |
| dummy | An effect or aura type that does nothing by itself (effect 3, aura 4). It is a hook for code: a spell script gives it meaning. A dummy with no script is dead. | See "placeholder" below. |
| spell family (SpellFamilyName) | A number grouping spells by class: 3 Mage, 4 Warrior, 5 Warlock, 6 Priest, 7 Druid, 8 Rogue, 9 Hunter, 10 Paladin, 11 Shaman, 15 Death Knight. CoA class spells use other numbers. | `core:src/server/shared/SharedDefines.h:3925`. |
| class mask / family flags (SpellFamilyFlags) | 96 bits (three 32-bit numbers) on each spell. A modifier or proc names the spells it applies to by family + a mask of these bits. Several spells can share a bit. | The reason for `wcme_spellaffect_dbc`; see references/spell-system.md. |
| spell mod (modifier) | An aura (type 107 flat, 108 percent) that changes one property of other spells: cost, cooldown, cast time, damage... | Most rebuilt enchants are one of these. |
| SpellAffect | Ascension's extra DBC that lists, by spell ID, which spells a modifier changes when its class mask is empty. | `core:src/server/shared/DataStores/DBCStructure.h:1809`. |
| proc | "Programmed random occurrence": an aura that reacts to an event (you hit, you are hit, you cast, you kill). | `spell_proc` rows in `sql/enchants/`. |
| proc flags | A bit mask saying which kinds of event an aura listens to (melee swing, spell hit, periodic tick, kill...). | `core:src/server/game/Spells/SpellMgr.h:109`. |
| ICD (internal cooldown) | The minimum time between two procs of the same aura. The `Cooldown` column of `spell_proc`, in milliseconds. | `sql/enchants/015-runaway-procs.sql` adds them. |
| GCD (global cooldown) | The short shared lockout (usually 1.5 s) after most abilities. Per spell: `StartRecoveryTime` and `StartRecoveryCategory`. The client enforces it too. | `patches/52-racials.ps1` takes racials off it; `client-patch/racials.py` does the same client-side. |
| triggered spell | A spell cast by another spell or by code rather than by a button press (a proc's damage, a DoT tick's side effect). By default a triggered spell does not set off procs. | `AttributesMask` 2 in `spell_proc` allows it. |
| spell script | A C++ class (`SpellScript` for the cast, `AuraScript` for the aura) attached to a spell ID through the `spell_script_names` table. | `spell_wcme_*` scripts in `patches/mystic-enchants-scripts.patch`. |
| hook | A named point where the core calls every registered script: `OnPlayerLogin`, `OnPlayerUpdate`... | List per patch in references/hooks-config-and-loop.md. |
| unit / creature / player | `Unit` is anything that can fight. `Creature` (NPCs, pets) and `Player` are its two kinds. A bot is a `Player`. | Hooks receive these as pointers. |
| GUID | The unique number of an object. For a character, its row number in the characters database (`guid`). | Our characters-database tables key on `guid`. |
| map | A continent, a dungeon, a battleground or an arena: map 0 Eastern Kingdoms, 1 Kalimdor... | Each map is updated by one thread at a time. |
| instance | One private copy of a dungeon, raid or battleground map. Ten parties in the same dungeon are ten instances, each its own map object. | "each dungeon copy" in `server-settings.txt:493`. |
| tick / world update | One pass of the server's main loop: read packets, update every map, run timers. | `core:src/server/apps/worldserver/Main.cpp:587`. |
| diff | Milliseconds since the previous tick, passed to every update function. A big diff means a slow tick: that is the lag players feel. | `OnPlayerUpdate(Player*, uint32 diff)`. |
| opcode / packet | One message between client and server; the opcode is its type number. | `patches/50-manastorm.ps1` and `81-chat-channel-guard.ps1` work at this level. |
| console | The world server's own command line. Commands there need no leading dot. | `server info`, `server shutdown 1s 0`. |
| RA (remote administration) | Sending a console command to the running world server from outside. Here the scripts do it through the manager's bridge verb `ra-once`. | `patch-night/PatchNight.ps1:122`. |
| GM command | A dot command typed in game chat by an account with the right permission: `.aura 12345`. | SKILL.md section 8. |
| RBAC | Role-based access control: each command needs a numbered permission. The pinned core's command tables use it. | `core:src/server/game/Accounts/RBAC.h`. |
| `.conf` / `.conf.dist` | A text settings file and its shipped template that documents every option and default. | `server-settings/Apply-ServerSettings.ps1` checks ours against the `.dist`. |
| prepared statement / sync query | A pre-compiled database query; a "sync" query makes the calling thread wait for MySQL. A sync query during a tick stalls the world. | Our patches only use sync queries at start-up or on rare events. |

## Conquest of Azeroth and Ascension

| Term | What it means | Where you meet it here |
|---|---|---|
| Ascension | The original commercial server whose client and game design this is built on. Its site and forums are gone, so intended behaviour has to be reconstructed. | `docs/enchant-restoration.md`. |
| Conquest of Azeroth (CoA) | The AzerothCore fork that re-implements Ascension's systems for Ascension's client. Its code is in `core:src/server/coa/` (754 files at the pinned commit). | `Corfirean/azerothcore-wotlk-coa`. |
| CF-Server-Manager ("the manager") | The Windows program that installs and runs CoA releases on the server PC. It owns the official `worldserver.exe` and rebuilds `worldserver.conf` from a template. | README.md; `Apply-ServerSettings.ps1:10`. |
| release / pinned commits | One manager release, such as `server-0.261119.114`, names one exact commit of each part. Our build uses the same commits plus our patches. | `scripts/resolve_release.py`. |
| CoA classes | The 21 custom classes with class IDs 12 to 32 (Barbarian 12 ... Runemaster 32). | `core:src/server/shared/SharedDefines.h:160-180`. |
| Hero | Class ID 10, `CLASS_HERO`: Ascension's classless character that can hold abilities from any class. | `core:src/server/shared/SharedDefines.h:158`. |
| Wildcard | A game mode (bit 64) where a Hero does not choose abilities: they are rolled at random as it levels. On this server the whole realm is Wildcard. | `core:src/server/coa/AscensionWildcard.h:23`; `server-settings.txt:13-26`. |
| Wildcard Hero | A class-10 character in Wildcard mode. The core's test is `AscensionWildcard::IsWildcardHero(player)`. | `core:src/server/coa/AscensionWildcard.cpp:3430`. |
| skill card, card pack | Wildcard collectibles: a card sets one ability or talent on the build; sealed packs hold cards. | `patches/30-wildcard-rewards.ps1`, `53-wildcard-card-messages.ps1`. |
| Scroll of Fortune | The Wildcard item (ability and talent kinds) that is spent on rolls; it also counts as a currency. | `core:src/server/coa/AscensionWildcard.h:44-48`; `Wildcard.ScrollsStraightToCurrency`. |
| Character Advancement | Ascension's replacement for talent trees and trainers: a client DBC list of every ability and talent a character can take, with realm-type flags. | `core:src/server/coa/AscensionFreepickRules.cpp:185`. |
| essence (AE / TE) | Ability Essence and Talent Essence: the points a non-Wildcard Hero spends in Character Advancement. Enchants can require an investment. | Skipped for Wildcard by `mystic-enchants-wildcard.patch` (README.md). |
| prestige | At the level cap a character can reset to level 1 for rewards and faster experience (Chromie's Prestige Mode, `mod-coa-prestige`). | `patches/47-leaderboards.ps1`, `49-prestigious-legendary.ps1`. |
| Mystic Enchant | A passive bonus slotted onto a character (17 slots), separate from gear. Each is a spell applied as an aura; many also teach or change an ability. Listed in the client's `MysticEnchant.dbc`. | The heart of this repository. `core:src/server/coa/AscensionMysticEnchant*.cpp`. |
| quality | Uncommon, Rare, Epic, Legendary, Artifact. Limits apply per quality: 3 epic, 1 legendary (README.md). | `enchants/tracker.csv` column `quality`. |
| Mystic Scroll | The item that carries one enchant; every enchant has its own scroll item ID. An unidentified scroll (item 97866) is revealed into a random enchant. | `tracker.csv` column `scroll item`; `core:src/server/coa/AscensionMysticEnchantRules.h:26`. |
| roll (of a scroll) | The weighted random pick of which enchant a scroll becomes. An enchant with weight 0 never rolls. | `SkipMissingSpells` / `SkipDudSpells` set weights to 0. |
| altar (Mystic Altar) | The game object a player must stand within 10 yards of to apply or reforge enchants. | `core:src/server/coa/AscensionMysticEnchant.cpp:87-90`. |
| collection | The list of enchants a character has learned and can re-apply for gold or runes. | `patches/79-mystic-enchant-gold-cost.ps1`. |
| Rune of Descension | Item 375250, the currency for enchant work. (The core's constant for the same item is named `RUNE_OF_ASCENSION`.) | `sql/enchants/100-rune-rates.sql`, `160-rune-currency.sql`. |
| worldforged enchant | A rare enchant family (990 of them, eight families) that drops in the world for an ability the looter knows. | `patches/78-worldforged-enchants.ps1`. |
| Manastorm | An endless, floor-by-floor dungeon mode built from rooms of existing dungeons (`mod-manastorm-endless`). | `patches/50-manastorm.ps1`, `84-treasure-keeper-instant-reward.ps1`. |
| ruleset: PvE / War Mode / High Risk | The three PvP rule auras a character carries. PvE: never attackable in the world. War Mode: open-world PvP. High Risk: open-world PvP from level 15 where dying can also cost gold and one or two pieces of gear. | `core:src/server/coa/AscensionHighRiskPolicy.h`; `server-settings.txt:438-446`. |
| Mercenary | An aura (spell 9930874, level 20+) that puts a player on a neutral faction so both sides can attack them. | `core:src/server/coa/AscensionMercenary.cpp:21-27`; `patches/20-bots.ps1`. |
| content scaling | Run-time scaling of creatures, items and quests so old content fits the realm's level cap and group size. | `mod-coa-content-scaling`; `patches/95-dungeons-scale-up.ps1`. |
| Warcraft Reborn (wcr) | CoA's class model for the stock classes, with its own copies of stock spells at ID + 1,100,000. | Not used on this realm, but its twin machinery is in the core. |
| realm type | What the client is told the realm is: `live`, `seasonal`, `league`, `ptr`, `development`. It decides which client rows are visible. | `CoA.RealmType = "live seasonal"` (`server-settings.txt:22`). |
| Area 52 | One of Ascension's realms. The client carries a separate spell list for it (`Data/area-52/patch-D.MPQ`), and 1,206 enchant spells exist only there. The archived builder page used for tooltips is Area 52's. | `docs/enchant-restoration.md:100-106`. |
| class model | Which character creator the realm offers: `coa`, `wcr`, `hero`. This realm is `hero`. | `server-settings.txt:19`. |

## This repository's own vocabulary

| Term | What it means | Where |
|---|---|---|
| WCME | "Wildcard Mystic Enchants". The prefix for everything this repository adds: tables `wcme_*`, scripts `spell_wcme_*`, the SQL comment marker `WCME:`. | `sql/enchants/000-reset.sql`. |
| placeholder | An enchant spell whose effects are only dummies (or a trigger with nothing to trigger). On Ascension the real behaviour lived in server code we do not have. | `SpellIsPlaceholder` in `patches/mystic-enchants-wildcard.patch`. |
| dud | A placeholder with nothing on the server giving it behaviour (no script, no link, no rule row). Kept out of scroll rolls. | `CoA.MysticEnchants.SkipDudSpells`. |
| missing | An enchant listed in `MysticEnchant.dbc` whose spell does not exist in the server's spell data at all. | `tracker.csv` `audit = missing` (1,206). |
| twin (ours) | The same enchant made for another realm type, under a different spell ID, that does work. We link ours to it. | `sql/enchants/001-twin-links.sql`; `tracker.csv` column `twin`. |
| twin (the core's) | A different thing: a Warcraft Reborn or crossover copy of a stock spell that the core maps back to its stock source and copies data rows to. | `core:.agents/docs/systems/warcraft-reborn-spell-twins.md`. |
| namesake (ours) | A working spell with the same name as a broken one; the enchant is made to teach it instead. | `sql/enchants/008-teach-namesakes.sql`. |
| namesake (the core's) | A Reborn spell that shares a stock spell's name but not its layout; gets no copied rows. | Same core doc. |
| rebuilt spell | A spell we created from scratch in `spell_dbc` for a missing enchant, from its archived description. | `sql/enchants/009`, `011`. |
| action table | `wcme_enchant_action`: data rows that tell the generic script `spell_wcme_enchant_action` what an enchant does when it procs. | `patches/mystic-enchants-actions.patch`. |
| school pair | The recipe for "damage of school A raises school B and the reverse". | `sql/enchants/002-school-pairs.sql`. |
| tracker | `enchants/tracker.csv`: one row per enchant (6,440) with audit result, status, fix file and test date. | `enchants/`. |
| patch (ours) | A file in `patches/` that edits the pinned sources at build time. Not to be confused with a client patch (an MPQ). | `docs/agents/context/patches.md`. |
| anchor / `Edit-Core` | The exact text a patch script looks for in the source, which must be found exactly once, and the helper that replaces it. | `docs/agents/context/patches.md:8`. |
| patch night / nightly restart | The two scheduled tasks on the server PC: weekly (Tuesday 11:00 pm) installs a new build; nightly (starts 3:30 am, restart 4:00 am) applies merged settings, SQL and addons. Times are the script's defaults; what is registered on the VM is UNVERIFIED (`wildcard-run-and-operate`). | `patch-night/Register-PatchNight.ps1:3-5`. |
| server-settings | `server-settings/server-settings.txt`, the one list of every config value this server changes. | Lines are `<config file> | <setting> = <value>`. |

## Bots

| Term | What it means | Where |
|---|---|---|
| SQUID / SQUID's bots | Zyth45's fork of `mod-playerbots` (tag v3.0 at the pin): bots that are full `Player` objects driven by AI. | `squid:`; config `modules\playerbots.conf`. |
| CoA bots / CoA Companions | A second, separate bot system (`Corfirean/mod-coa-playerbots`) built for the 21 CoA classes. Compiled in, switched off here. | `CoaBots.Enable = 0` (`server-settings.txt:413`). |
| random bot | A bot on one of the bot accounts that logs in by itself and roams the world. About 750 here. | `AiPlayerbot.MinRandomBots`. |
| altbot | A character on a player's own account, logged in as a bot and commanded by that player. | `squid:conf/playerbots.conf.dist:8`. |
| addclass bot | A bot from a reserved account pool, summoned to fill a party. | `squid:conf/playerbots.conf.dist:7`. |
| selfbot | A real player's own character with bot AI switched on. | `squid:src/Bot/PlayerbotAI.cpp:5300`. |
| master | The player a bot follows and takes commands from. Random bots have none until a player takes them. | `PlayerbotAI::GetMaster()`. |
| active / asleep | An active bot runs its full AI. A bot far from players mostly sleeps, but still costs a basic update each tick. | `AiPlayerbot.BotActiveAlone`. |
| SmartScale | SQUID's automatic throttle: as tick time climbs from 50 ms to 200 ms it puts more far-away bots to sleep. | `squid:conf/playerbots.conf.dist:1469-1489`. |
| Dungeon Clear | Module where a tank bot leads a party through a dungeon (`dc` in party chat, or `.dc`). | `server-settings.txt:414-430`. |
| AI chat | `mod-ollama-chat`: bots answer in chat through a local language model. | `ollama-chat/`, `patches/10-mod-ollama-chat-fit.ps1`. |

## Client side

| Term | What it means | Where |
|---|---|---|
| addon | Lua and XML files in the client's `Interface\AddOns` folder. | `addon/WildcardEnchants`, `WildcardMastery`, `WildcardCombatLogFix`. |
| Interface 30300 | The addon API version of client 3.3.5. Every `.toc` here declares it. Newer WoW API functions do not exist. | `addon/*/*.toc`. |
| `patch-T.MPQ` | The client archive holding the spell list every non-Area-52 realm uses, this one included. | `docs/enchant-restoration.md:102`. |
| `patch-ZZW.MPQ` | Our client patch. It sorts after `patch-T`, so its `Spell.dbc` wins. Built locally from the player's own client; never published. | `client-patch/build_client_patch.py`. |
| launcher | The friends' program that updates their client files (client patch, addons) from the server PC and starts the game. | `launcher/README.md`. |
