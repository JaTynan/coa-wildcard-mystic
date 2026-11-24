---
name: azerothcore-coa-reference
description: Domain reference for the game server behind this repository - AzerothCore 3.3.5a, the Conquest of Azeroth (CoA) fork and SQUID's Playerbots, on the Wildcard realm. Explains the spell system (Spell.dbc vs spell_dbc, effects, auras, procs, proc flags, spell_proc columns and AttributesMask 2, spell_linked_spell type 2, SpellAffect and class family flags, spell scripts and spell_script_names), every wcme_ table, the CoA enchant tables, the three databases, the config API sConfigMgr GetOption, the script hooks the repository's patches use, the world update loop, map threads and diff, why per-tick code is costly, Hero class 10 versus CoA classes 12-32, bot guards such as IsBot and IsRealPlayer, GM and console commands, the client MPQ and addon side, and a glossary. Load it when a task mentions any of those terms, when asked "what does this table or column do" or "where does this code run", or before reviewing a patch or enchant SQL. It explains; it holds no fix recipes.
---

# AzerothCore and CoA, as they apply to this server

This is the background a capable engineer lacks on day one here: how the game server works **in the places this
repository touches**, with the file that proves each statement. It is a reference, not a procedure. Nothing in it
changes the server.

How to cite in this skill: `core:` is a path in the pinned CoA core, `squid:` a path in the pinned SQUID bots;
anything else is a path in this repository. Facts were checked on **2026-11-22** against release
`server-0.261119.114` (core `c3f2fd4b`, SQUID `4ef5ed9e`, tag v3.0). Upstream line numbers move with every
release: when one matters, re-find it with the grep commands at the end of each file.

`docs/agents/*` and `.claude/agents/*` are cited below (the hard stops, the risk matrix, the patch rules). They
came with PR #232, merged on 22 Nov 2026 (`0802d4f`), and are on `main`: what rests on them is **DOCTRINE**. Status words are
defined in `wildcard-change-control`, section 1.

## When NOT to use this skill

| You want to... | Use instead |
|---|---|
| Write, port or pre-flight a patch (`patches/NN-name.ps1`, anchors, `Edit-Core`) | `wildcard-patch-authoring` |
| Fix a Mystic Enchant, talent or racial (recipes, tracker, test steps, source hierarchy) | `ascension-restoration` |
| Decide whether a change may go in, and by which path | `wildcard-change-control` (always first for anything that changes server behaviour) |
| Look up one of our settings, its default or which build it needs | `wildcard-settings-and-flags` |
| Diagnose a symptom | `wildcard-debugging-playbook` |
| Measure tick times or read logs | `wildcard-diagnostics-and-tooling` |
| Work the lag spikes | `wildcard-lag-spike-campaign` |
| Understand the build, pins and release tags | `wildcard-build-and-env` |
| Run patch night, start or roll back the server | `wildcard-run-and-operate` |
| Ship a client patch, addon or launcher change | `wildcard-client-and-web` |
| See how the repository's layers fit together | `wildcard-architecture-contract` |

## Reference files

| File | Read this when |
|---|---|
| [references/glossary.md](references/glossary.md) | You meet a term you cannot define: aura, proc, ICD, DBC, twin, placeholder, altar, Hero, Manastorm, War Mode... |
| [references/spell-system.md](references/spell-system.md) | Anything touches a spell: data layers, effects, modifiers, SpellAffect, procs and `spell_proc`, linked spells, spell scripts, the core's twin system |
| [references/wcme-tables.md](references/wcme-tables.md) | You see a `wcme_` name, write SQL for `sql/enchants/`, or need to know what `000-reset.sql` deletes |
| [references/hooks-config-and-loop.md](references/hooks-config-and-loop.md) | You need to know where patch code runs, how often, on which thread, or what a config read costs |
| [references/coa-modules-bots-client.md](references/coa-modules-bots-client.md) | You need to place a behaviour: CoA core, a module, SQUID's bots, or the client; class IDs; bot guards and cost settings; MPQ and addons |
| `scripts/repo_facts.py` | You want the current list of `wcme_*` tables, hooks per patch, config files, bot guards or option counts, straight from the repository |

## Open the pinned sources (read-only)

The upstream code is not in this repository. To check a claim, open the exact commits the build uses. Clone
outside the repository, never build or run anything from the clone.

```bash
cd /path/to/coa-wildcard-mystic
# A full patched tree instead: preflight.py latest --keep --workspace DIR (wildcard-patch-authoring)
python3 -I scripts/resolve_release.py latest          # prints tag=, core_sha=, squid_sha=, bots_sha=, ...

mkdir -p ~/upstream && cd ~/upstream
git clone --filter=blob:none --no-checkout https://github.com/Corfirean/azerothcore-wotlk-coa core-ref
git -C core-ref checkout <core_sha>                    # c3f2fd4b2395cd3cc2cc8287117059e054877d7c on 2026-11-22
git clone --filter=blob:none --no-checkout https://github.com/Zyth45/mod-playerbots squid-ref
git -C squid-ref checkout <squid_sha>                  # 4ef5ed9ebe75a330de7df19639a042391e037e15 on 2026-11-22
```

The server PC runs the release the manager installed, which can be older than `latest`. For "what is live" use
the release tag in the world server's first log line (README.md, "Building").

Upstream ships its own engineering notes worth reading before guessing: `core:AGENTS.md`,
`core:.agents/docs/systems/*.md` (spell parity, spell twins, talents, character creation), `core:docs/coa/*.md`
(Manastorm, level scaling, per-class notes).

## 1. The model in twelve lines

1. Two programs: `authserver` (login, port 3724) and `worldserver` (the game, port 8085). Three MySQL databases:
   auth, characters, world.
2. The world server is AzerothCore 3.3.5a, forked as Conquest of Azeroth (CoA) to re-create Ascension's systems
   for Ascension's client. CoA's code is in `core:src/server/coa/`.
3. This repository never edits the running server. C++ patches are applied at build time, settings and SQL at
   every start (CHANGES.md, first table).
4. Almost everything in the game is a **spell**. A lasting spell effect on someone is an **aura**. An aura that
   reacts to events is a **proc**.
5. Spell data is read once at start-up: `Spell.dbc` file, then the `spell_dbc` table on top, then code fixes,
   then side tables (`spell_proc`, `spell_linked_spell`, `spell_script_names`). Changing any of it means a restart
   unless a reload command exists.
6. The **client has its own copy** of the spell data and never sees the server's tables. They can disagree.
7. A **Mystic Enchant** is a spell applied to the player as an aura. Many are **placeholders**: the real
   behaviour lived in Ascension's server, which no longer exists.
8. Every character here is a **Hero, class 10**, in **Wildcard** mode. Class-indexed code often has no entry
   for 10.
9. About 750 **bots** are real player objects. Any code that runs "for each player" runs for them.
10. The world advances in **ticks**. One thread updates one map; the tick waits for the slowest map. Slow code in
    a per-tick or per-hit hook is felt by everyone as lag.
11. Config is one flat namespace of `Name = value` read with `sConfigMgr->GetOption<T>(name, default)`.
12. Our additions are prefixed **wcme** (tables `wcme_*`, scripts `spell_wcme_*`, SQL marker `WCME:`).

## 2. The spell system in brief

Full detail, with column tables and code references: [references/spell-system.md](references/spell-system.md).

**Layers (later wins), all read at start-up:**

| Layer | Where | Changed by |
|---|---|---|
| `Spell.dbc` | File in the server's `DataDir/dbc/` | The manager's release |
| `spell_dbc` | World table; a row replaces the whole spell by ID | `sql/enchants/` |
| Code corrections | `SpellMgr::LoadSpellInfoCorrections` | A patch (`52-racials.ps1`, `89-racial-stoneform.ps1`) |
| Side tables | `spell_proc`, `spell_linked_spell`, `spell_script_names`, `coa_mystic_enchant_*`, `wcme_*` | `sql/enchants/` |

Traps: `spell_dbc` inserts are positional and must have exactly the core's field count (234 at the pin) or the
world server asserts at start-up. Some CoA code reads the DBC **file** raw and ignores `spell_dbc`: the enchant
catalogue (`MysticEnchant.dbc`) and the "which spell does this enchant teach" lookup. That is why
`wcme_enchant_teach` exists.

**Effects and aura types we rely on:**

| Number | Name | Role here |
|---|---|---|
| Effect 3 / aura 4 | Dummy | Does nothing without code. The mark of a placeholder |
| Effect 6 | Apply aura | Every enchant |
| Aura 42 | Proc trigger spell | "When X happens, cast Y" |
| Aura 107 / 108 | Add flat / percent modifier | "Ability X costs less / hits harder". Most rebuilt enchants |
| Aura 322 / 341 | Ascension PvP / PvE damage percent | Honoured only for an allowlist (`65-enchant-tuning-auras.ps1`) |

**Which spells does a modifier change?** Normally: spells of its family whose 96-bit class flags share a bit with
its mask. Bits are shared between abilities, so a mask can hit unrelated spells. Ascension's alternative, which
CoA implements: a modifier with an **empty mask** names its targets by spell ID in `SpellAffect.dbc`
(`core:src/server/game/Spells/SpellInfo.cpp`, `if (!mod->mask)`). 858 rebuilt enchants could use a mask shared
with at most three other spells; **337 could not**, so they have no mask and their targets are rows in
`wcme_spellaffect_dbc`, which `patches/mystic-enchants-spellaffect-sql.patch` makes the core load over
`SpellAffect.dbc` (one changed argument). Start-up only; without the patched build those 337 change nothing.

**Procs.** What the core does at start-up (`SpellMgr::LoadSpellProcs`):

| The spell has | Then |
|---|---|
| A `spell_proc` row | The row rules. `ProcFlags`, `Chance`, `Charges` fall back to the spell's own when 0 |
| Proc flags but **no row** | A default entry is generated: no ability filter unless the effect itself carries a class mask (on Ascension's enchant data it usually does not), **no cooldown**, chance from the spell. On Ascension data this means "fires on every qualifying hit" (`sql/enchants/015-runaway-procs.sql`) |
| **No proc flags** and no row | It never fires (`sql/enchants/016-dead-triggers.sql`) |

`spell_proc` columns we set: `SchoolMask`, `SpellFamilyName` + `SpellFamilyMask0..2` (which abilities),
`ProcFlags` (which event kinds), `SpellTypeMask` (1 damage, 2 heal, 4 neither), `SpellPhaseMask` (1 cast, 2 hit,
4 finish), `HitMask` (2 = crit, 4 = miss...), `AttributesMask`, `Chance` (percent), `Cooldown` (**milliseconds**),
`Charges`.

`AttributesMask` **2** = `PROC_ATTR_TRIGGERED_CAN_PROC`: triggered spells may set the proc off. Without it the
core drops the event when the damaging spell was cast by another spell (Living Bomb's explosion, Fire Nova's
damage, Hellfire's ticks), so an enchant keyed to such an ability stays silent. With it, give the row a cooldown
if the proc itself casts something that could feed it.

**`spell_linked_spell`.** Only type **2** is used here: while aura A is on a unit, aura B is added with it and
removed with it (`Aura::HandleAuraSpecificMods`). It is the "working twin" recipe. Rows must carry a comment
starting `WCME:` or the reset never removes them.

**Spell scripts.** C++ class + registration (`RegisterSpellScript(name)`) + a `spell_script_names` row binding a
spell ID to that name. The table loads at start-up and has no reload command. A row naming a script the installed
build lacks does nothing, which lets SQL merge ahead of its build. A script's proc hook still needs the aura to
proc: flags or a `spell_proc` row.

**CoA's own enchant tables** (world DB, read by `core:src/server/coa/AscensionMysticEnchantProcs.cpp`):
`coa_mystic_enchant_proc` (event-driven rules per enchant and effect; we do not write it) and
`coa_mystic_enchant_aura_link` ("while aura X is on you, you also have Y"; we add 17 enchants' rows in
`sql/enchants/007-enchant-actions.sql`).

## 3. Our tables

Details, columns and the reset rules: [references/wcme-tables.md](references/wcme-tables.md). Current list:
`python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py tables`.

| Table | Database | Created by | Purpose |
|---|---|---|---|
| `wcme_owned` | world | `000-reset.sql` | Ledger of IDs we added to core tables (`spell_dbc`, `spell_proc`, `aura_link`), so the next start can remove them |
| `wcme_backup_spell_proc`, `wcme_backup_spell_linked_spell` | world | `000-reset.sql` | One-off copies of the original tables |
| `wcme_enchant_teach` | world | `000-reset.sql` | An extra spell an enchant teaches (SQL cannot change what the client data says) |
| `wcme_enchant_override` | world | `000-reset.sql` | Force an enchant into (1) or out of (0) scroll rolls |
| `wcme_enchant_action` | world | `000-reset.sql` | The action table read by `spell_wcme_enchant_action` |
| `wcme_proc_target_cooldown` | world | `000-reset.sql` | Per-target proc cooldowns (`63-enchant-target-cooldowns.ps1`) |
| `wcme_spellaffect_dbc` | world | `000-reset.sql` | Named targets for mask-less modifiers |
| `wcme_rune_original_quest`, `wcme_rune_original_loot` | world | `100-rune-rates.sql` | Stock rune amounts, so rates are recomputed, never compounded |
| `wcme_new_spell` | world (TEMPORARY) | `009`, `011`, `012`, `013` | Scratch list so we only claim spells we created |
| `wcme_prestige_legendary` | characters | `49-prestigious-legendary.ps1` at start-up | Legendary choices owed per character |
| `wcme_profession_mastery` | characters | `51-profession-mastery.ps1` at start-up | Mastery points per character and profession |
| `wcme_world_pvp_kills`, `wcme_server_firsts` | characters | `47-leaderboards.ps1` at start-up | Leaderboard counters and records |
| `wcme_applied_sql` | characters | `patch-night/PatchNight.ps1` | Which AI chat SQL files have run (those are run-once) |

`000-reset.sql` runs first at every start: it deletes every row we own from core tables and empties our world
tables, then the numbered files rebuild them in name order. Delete a file and its fix is gone after the next
start (README.md). A row we add that the reset cannot recognise is a bug, except the deliberate rider files and
the core rows we change or replace, which deleting the file does **not** undo: the one list is in
`ascension-restoration` (section 5 item 3, `ascension-restoration/references/reset-limits.md`).

## 4. Server structure

More, including the per-hook table: [references/hooks-config-and-loop.md](references/hooks-config-and-loop.md).

**Databases, and what this project writes:**

| Database | Name here | Written by us |
|---|---|---|
| Auth | `acore_auth` | Realm address in `realmlist` (patch night); accounts (sign-up service). No patch touches it |
| World | `acore_world_wildcard` | `sql/enchants/*.sql` at every start. Patched C++ only reads it |
| Characters | `acore_characters_wildcard` | The four `wcme_*` tables above, written by patched C++; `wcme_applied_sql` |

Rows in the characters and auth databases are player data: deleting or rewriting them is a hard stop
(`docs/agents/context/change-risk.md`, item 7).

**Config.** Read with `sConfigMgr->GetOption<T>("Name", default)`; `T` is `bool`, `uint32`, `int32`, `float` or
`std::string` in our patches. All `.conf` files merge into one namespace, so the file a setting sits in does not
matter to the server. Files this project sets values in (relative to `Core\configs`): `worldserver.conf` (146
settings, including most of our own options), `authserver.conf`, and under `modules\`: `coa.conf`, `wildcard.conf`,
`playerbots.conf`, `mod_coa_playerbots.conf`, `mod_dungeon_clear.conf`, `mod_ollama_chat.conf`, `mod_ahbot.conf`,
`mod-coa-challenges.conf`, `mod-coa-prestige.conf`, `dynamicxp.conf`. A `.conf.dist` is the shipped template;
the server reads only the `.conf`. Never edit a `.conf` on the server: `server-settings/server-settings.txt` is
re-applied at every start.

One `GetOption` call is a string lookup, an environment-variable check and a text-to-value conversion. Fine at
start-up or per event; costly inside a per-tick hook.

**Hooks our patches use** (45 distinct core hooks across 30 patch files on 2026-11-22; list with
`repo_facts.py --core <core clone> hooks`, which also prints two names that are not hooks and says so):

| Frequency | Hooks |
|---|---|
| Every tick, per player and bot | `OnPlayerUpdate` (16 patch files plus the enchant scripts) |
| Every hit, tick or heal, creatures included | `ModifyMeleeDamage`, `ModifySpellDamageTaken`, `ModifyPeriodicDamageAurasTick`, `ModifyHealReceived`, `OnDamage`, `OnBeforeHealAbsorb`, `OnAfterAuraEffectCalculateAmount` |
| Every aura change or spell cast by anything | `OnAuraApply`, `OnAuraRemove`, `OnSpellCast`, `OnSpellPrepare`, `OnSpellCheckCast`, `OnSpellHitResult`, `OnSpellCritChance`, `OnSpellSuccessfulDispel`, `OnSpellModFamilyMask`, `OnUnitSetShapeshiftForm` |
| Every client packet | `CanPacketReceive` |
| Per player action | `OnPlayerSpellCast`, `OnPlayerCreatureKill`, `OnPlayerPVPKill`, `OnPlayerRewardKillRewarder`, `OnPlayerGiveXP`, `OnPlayerGiveReputation`, `OnAfterLootTemplateProcess`, `OnPlayerLootItem`, `OnPlayerStoreNewItem`, `OnPlayerCreateItem`, `OnPlayerGroupRollRewardItem`, `OnPlayerQuestRewardItem`, `OnPlayerBeforeSendLoot`, `OnPlayerUpdateGatheringSkill`, `OnPlayerUpdateCraftingSkill`, `OnPlayerCanAreaExploreAndOutdoor`, `OnPlayerCanUseChat`, `OnPlayerLearnSpell`, `OnPlayerGossipSelect`, `OnPlayerAfterUpdateMaxPower`, `OnUse` |
| Per login or game | `OnPlayerLogin`, `OnPlayerLogout` (bots log in and out too), `OnBattlegroundEndReward`, `OnPlayerCoAPrestigeSaved` |
| Once | `OnStartup` |

A script lists the hooks it wants in its constructor (`PlayerScript("name", {PLAYERHOOK_ON_UPDATE})`). An override
that is not listed is never called; an empty list means all.

## 5. The update loop and why bots multiply cost

```
world thread:  loop { diff = ms since last pass
                      packets of every session
                      MapMgr::Update -> each map on a worker thread (MapUpdate.Threads = 6 here) -> WAIT for all
                      battlegrounds, LFG, database callbacks, console commands, module world scripts }
map thread:    Map::Update -> every Player::Update (OnPlayerUpdate, bot AI), creatures, spells, auras
```

- **tick** = one pass; **diff** = how long the last one took. A long diff is the lag players feel.
- One map, one thread. A continent full of bots is one busy thread no matter how many cores exist
  (`docs/performance.md`).
- The tick waits for the slowest map, so one slow hook stalls every map.
- Hooks on different maps run at the same time on different threads: shared `static` state in a patch needs a lock
  (`47-leaderboards.ps1` uses a `std::mutex`) or must live on the `Player`.
- A synchronous database query (`CharacterDatabase.Query`, `WorldDatabase.Query`) blocks its thread until MySQL
  answers. Our patches query at start-up, login or rare events, and write with the queued `Execute`.
- A SQUID bot is a `Player`. With 750 bots and a median tick of 36 ms (`server-settings.txt:506`), one
  `OnPlayerUpdate` script is called about 21,000 times a second. Sleeping bots still take a basic update.

This is why the risk matrix scores "every tick, every packet, or for all 750 bots" highest for likelihood
(`docs/agents/context/change-risk.md`, L3).

## 6. CoA specifics and the module set

Detail: [references/coa-modules-bots-client.md](references/coa-modules-bots-client.md).

| In the build | What it is | State here |
|---|---|---|
| CoA core (`Corfirean/azerothcore-wotlk-coa`) | AzerothCore + `src/server/coa/` (Mystic Enchants, Wildcard, Hero class, Character Advancement, rulesets, Manastorm, scaling) + 38 bundled modules (prestige, challenges, custom races, Manastorm endless, auction bot...) | Base |
| `mod-coa-playerbots` | The CoA bots ("CoA Companions"), for the 21 CoA classes | Compiled in, off (`CoaBots.Enable = 0`) |
| `mod-coa-content-scaling` + `mod-coa-tbc-content`, `mod-coa-wotlk-content` | Run-time scaling of content to level cap and group size, with Outland and Northrend packs | Compiled in |
| SQUID's `mod-playerbots` | Player-like bots, including Wildcard Heroes | On, 750 random bots |
| `mod-dungeon-clear` | A tank bot leads a dungeon run (`dc` in party chat, `.dc`) | On |
| `mod-ollama-chat` | Bot chat through a local language model; pinned by our workflow, fitted by `10-mod-ollama-chat-fit.ps1` | Our addition |

Mystic Enchant code in the core: `AscensionMysticEnchant.cpp` (state, altar, applying auras),
`AscensionMysticEnchantRules.cpp/.h` (catalogue from `MysticEnchant.dbc`, caps, rolls),
`AscensionMysticEnchantProcs.cpp` (the `coa_mystic_enchant_*` tables), and `...Bonus.cpp`, `...Mechanics.cpp`,
`...Scripts.cpp` (hard-coded per-enchant behaviour: grep these before scripting an enchant, the core may already
do it).

Class IDs: 1 to 9 and 11 are the stock classes; **10 is Hero** (`CLASS_HERO`); 12 to 32 are the CoA classes
(Barbarian 12 ... Runemaster 32); `MAX_CLASSES` is 33. Test for a Wildcard Hero with
`AscensionWildcard::IsWildcardHero(player)` in core code and `IsWildcardHeroBot(bot)` in SQUID code.

What makes the realm Wildcard (`server-settings.txt:13-26`): `CoAChallenges.GameModes.Realm = WildCard`,
`CoA.GameModeMask = 64`, `CoA.ClassModel = "hero"`, `CoA.MapClass10ToWarrior = 0`,
`CoA.RealmType = "live seasonal"`. These are realm identity, not tuning.

## 7. Playerbots

| Kind | What |
|---|---|
| Random bot | Bot-account character that logs itself in and roams. The 750 |
| Altbot | A player's own alt, logged in as a bot and commanded by that player (its **master**) |
| Addclass bot / selfbot | A pooled bot summoned into a party / a real player's character on autopilot |

Guards, by where your code lives:

| In | Use | Evidence |
|---|---|---|
| Core or CoA code | `player->GetSession() && !player->GetSession()->IsBot()` = a real person | `core:src/server/game/Server/WorldSession.h` `IsBot()`; nine patch files use it |
| SQUID module code | `IsRealPlayer(player)`; `GET_PLAYERBOT_AI(player)` (null for a person); `botAI->HasGameClientMaster()` | `squid:src/Bot/PlayerbotAI.cpp`; `patches/20-bots.ps1`, `61`, `90`, `96` |

Cost settings (`server-settings.txt:467-508`): `AiPlayerbot.MinRandomBots` / `MaxRandomBots` = 750;
`AiPlayerbot.BotActiveAlone` = 5 (percent awake away from players; SQUID's default is 60);
`BotActiveAloneForceWhenInZone` = 1 and `ForceWhenInRadius` = 300 (who must stay awake);
`AiPlayerbot.botActiveAloneSmartScale` (not set here, SQUID default on: sheds awake bots as the tick goes from 50
to 200 ms); `MapUpdate.Threads` = 6; `Visibility.Distance.Continents` = 100.

The manager switches both bot systems off on Wildcard whenever its own Start button is used. Start with
`patch-night\Start-Server.cmd` (README.md).

## 8. GM and console commands used on this project

Only commands evidenced in this repository or verified in the pinned core. Giving, removing or changing GM
access, and anything that hands out items or currency on the live realm, are hard stops in
`docs/agents/context/change-risk.md` (items 1 and 2): these are for a GM test character, as
`docs/enchant-restoration.md` describes.

| Command | Where typed | What it does | Evidence |
|---|---|---|---|
| `.aura <spell>` | In game, GM, with a target (target yourself) | Puts the aura on the target: tests an enchant without a scroll. Our patch also teaches the enchant's taught spell then | `docs/enchant-restoration.md`; `core:.../Commands/cs_misc.cpp` |
| `.unaura <spell>` | In game | Removes it | Same |
| `.list auras` | In game | Lists the target's auras; a linked twin shows here | `core:.../cs_list.cpp` |
| `.learn <spell>` | In game | Teaches an ability to trigger an enchant with | `core:.../cs_learn.cpp` |
| `.lookup spell id <spell>` | In game or console | Prints the spell with a clickable link, to read the tooltip | `core:.../cs_lookup.cpp` |
| `.additem <item> [count]` | In game or console | Gives an item, for example an enchant's scroll (IDs in `enchants/tracker.csv`) | `core:.../cs_misc.cpp` |
| `.legendary` | In game, any player | Reopens the owed Legendary Enchant choice | `patches/49-prestigious-legendary.ps1` |
| `.mastery` | In game, any player | Shows Profession Mastery | `patches/51-profession-mastery.ps1` |
| `.racial` | In game, any player | Shows what the signature racial is doing now | `patches/80-racial-status-command.ps1` |
| `.dc` (or `dc` in party chat) | In game | Drives Dungeon Clear | `server-settings.txt:415` |
| `.manastorm enter 1`, `next`, `leave`, `status` | In game | Manastorm controls | `core:docs/coa/manastorm.md` (UNVERIFIED in use here) |
| `server info` | Console / RA | Players online and uptime. Patch night and the status page poll it | `patch-night/PatchNight.ps1:894` |
| `announce <text>` | Console / RA | Server-wide chat line (restart countdown) | `patch-night/PatchNight.ps1:911` |
| `server shutdown 1s 0` | Console / RA | Stops the world server after 1 second with exit code 0 | `patch-night/PatchNight.ps1:158` |
| `character erase <guid>` | Console / RA | Deletes a character. Used once by `Rebuild-WildcardBots.cmd` on non-Hero bot characters. Player data: hard stop | `patch-night/PatchNight.ps1:796` |

In game a command starts with a dot; on the console and through RA it does not. Scripts reach the console through
the manager's bridge: `Ra 'server info'` calls the verb `ra-once` (`patch-night/PatchNight.ps1:122`).
`.aura`, `.unaura`, `.list auras` and `.learn` are marked `Console::No` in the core: they need a character in the
world.

**What needs a restart?**

| You changed | To take effect |
|---|---|
| A config value read with `GetOption` each time, or a reloadable core option | `.reload config` (`server-settings.txt:7`: "or .reload config for most of them") |
| A config value a patch reads once (comment says "read at server start") | Restart |
| `spell_proc` | `.reload spell_proc` exists in the core. UNVERIFIED on this server |
| `spell_linked_spell` | `.reload spell_linked_spell` exists in the core. UNVERIFIED on this server |
| `spell_dbc`, `wcme_spellaffect_dbc`, any DBC-backed data | Restart (loaded with the DBC stores) |
| `spell_script_names` | Restart (no reload command at the pin) |
| `wcme_enchant_teach`, `wcme_enchant_override`, `wcme_enchant_action`, `coa_mystic_enchant_*` | Restart (read in start-up code) |
| `wcme_proc_target_cooldown` | Restart (read once, at the first proc) |
| Anything in `patches/` | A build (automatic that evening, about 3½ hours) and the next 3:30 am install |

In practice the project does not hot-reload: SQL is applied by patch night just before the world server starts,
and `000-reset.sql` must never run against a live world. Treat the reload rows as knowledge for a test realm.

## 9. Client side

| Fact | Why it matters |
|---|---|
| The client reads `DBFilesClient\*.dbc` from MPQ archives in its `Data` folder; the server reads files in `DataDir/dbc/` plus `*_dbc` tables | Two copies of every table. A server-only spell has no name, icon or tooltip for the player |
| Spell list archives: `Data/area-52/patch-D.MPQ` (Area 52 only), `Data/patch-T.MPQ` (everywhere else, us included), `Data/patch-ZZW.MPQ` (ours; sorts after `patch-T` and wins) | 1,206 enchant spells existed only in the Area 52 list until our patch copied them over |
| The client checks cooldowns, the global cooldown, range and cost from **its own** data before sending a cast | A server-only change to those leaves the button greyed out: `52-racials.ps1` has a client twin in `client-patch/racials.py` |
| Copied enchant spells carry no class family or flags in the client copy | With them the character-creation screen crashed (fixed 7 Nov 2026) |
| Our own spells (IDs from 9990001) must exist in both `patch-ZZW.MPQ` and `spell_dbc` | `client-patch/custom_spells.py` writes both; `sql/enchants/150-custom-spells.sql` is generated |
| Addons declare `## Interface: 30300` (client 3.3.5); only that era's Lua API exists | Assume later-version functions are absent |
| The client hides the Mystic Enchant tab for Wildcard characters | The `WildcardEnchants` addon restores it; every player needs it (README.md) |
| `patch-ZZW.MPQ` is the client's own data | Built locally, never published in this public repository |

## 10. Looks like stock AzerothCore knowledge, but is different here

1. **Class 10 exists and is everyone.** `CLASS_HERO = 10`, `MAX_CLASSES = 33`. Per-class tables and `switch`
   statements often skip it. CoA classes are 12 to 32, and their enum names do not match their titles.
2. **Procs use the `spell_proc` table with generated defaults**, not `spell_proc_event`. `Cooldown` is in
   milliseconds. An aura with flags and no row still procs, unfiltered.
3. **Ascension blanked proc rules in the spell data.** Tooltips promise chances and cooldowns the data does not
   contain. "Stock" assumptions about a spell's `ProcChance` are wrong for enchants.
4. **`SpellAffect.dbc` exists** and decides the targets of mask-less modifiers. Stock 3.3.5 has no such file.
5. **The core has a spell-twin system** that copies `spell_proc`, script and link rows from a source spell to its
   copies, and it is active here because the realm type includes `seasonal`. Our docs use "twin" for something
   else.
6. **Spell IDs go far beyond the stock range**: Reborn copies at +1,100,000, crossover enchants at +1,300,000,
   ours from 9,990,001. Never size anything by "about 80,000 spells".
7. **Some data is read from DBC files raw**, bypassing `*_dbc` tables (`MysticEnchant.dbc`,
   `CharacterAdvancement*.dbc`, the "Teaches you" scan of `Spell.dbc`).
8. **CoA is in the core, not a module** (`src/server/coa/`), yet its settings live in `modules\coa.conf` and
   `modules\wildcard.conf`.
9. **`CoA.RealmType` is not cosmetic**: it decides which client rows are visible and whether enchant twins load.
10. **The client is Ascension's**, with extension opcodes and its own rule copies. A stock 3.3.5a client or addon
    guide is only partly right.
11. **Commands are gated by RBAC permission IDs** in the core's command tables (`rbac::RBAC_PERM_COMMAND_*`); our
    three player commands are registered with `SEC_PLAYER`.
12. **Bots are players.** `PlayerScript` hooks, rewards, mail and login queries all apply to them. There are two
    bot systems, and the manager turns both off on Wildcard when its Start button is used.
13. **Database names are per realm**: `acore_world_wildcard`, `acore_characters_wildcard`. Scripts read the names
    from `worldserver.conf`; do not type `acore_world`.
14. **Our SQL is not in AzerothCore's updater** (`data/sql/updates`). It runs from `sql/enchants/` at every start,
    must be safe to run again, and is undone by `000-reset.sql`.
15. **Config files are regenerated.** The manager rebuilds `worldserver.conf` from a template and patch night
    re-applies `server-settings.txt`. A hand edit on the server lasts until the next start.
16. **`MapUpdate.Threads` is 6, not the default 1**, so hooks really do run concurrently.
17. **The rune item is "Rune of Descension"** (375250) in game and `RUNE_OF_ASCENSION` in the core's source.
18. **Hooks must be enabled by name** in the script's constructor list; older AzerothCore tutorials omit this.

## Provenance and maintenance

Checked on 2026-11-22 against this repository at `fcfee51` and the pinned sources of release
`server-0.261119.114`: core `c3f2fd4b2395cd3cc2cc8287117059e054877d7c`, SQUID
`4ef5ed9ebe75a330de7df19639a042391e037e15`, CoA bots `178a7fde`, Content Scaling `3c2febf6`, Dungeon Clear
`6efb59ea`. Upstream was read, never built or run. Nothing here was re-verified on the live server on 2026-11-22;
statements about the server PC come from the scripts and comments in this repository.

Marked UNVERIFIED above: `.reload spell_proc` / `.reload spell_linked_spell` and the `.manastorm` commands in use
on this server (they exist in the pinned sources); the full client MPQ list; whether `CoA.RealmType` should be
`league` (references/coa-modules-bots-client.md).

Re-run after every core update, and before trusting a number in this skill:

```bash
# This repository's facts: tables, hooks, config files, bot guards, option counts
python3 -I .claude/skills/azerothcore-coa-reference/scripts/repo_facts.py --core ~/upstream/core-ref
# Are the pins still the ones this skill was checked against?
python3 -I scripts/resolve_release.py latest | grep -E "^(tag|core_sha|squid_sha)="
```

In the pinned core checkout (`~/upstream/core-ref`):

```bash
grep -n "CLASS_HERO\|define MAX_CLASSES" src/server/shared/SharedDefines.h                       # class 10, 33
grep -n '"spell_dbc"\|SpellAffect.dbc' src/server/game/DataStores/DBCStores.cpp                  # DBC layers
grep -n "Generate default proc entry\|Skip if no proc flags" src/server/game/Spells/SpellMgr.cpp # proc defaults
grep -n "PROC_ATTR_TRIGGERED_CAN_PROC" src/server/game/Spells/SpellMgr.h                         # AttributesMask 2
grep -n "SPELL_LINK_AURA" src/server/game/Spells/SpellMgr.h                                      # link type 2
grep -n "if (!mod->mask)" src/server/game/Spells/SpellInfo.cpp                                   # SpellAffect lookup
grep -n "FROM coa_mystic_enchant" src/server/coa/AscensionMysticEnchantProcs.cpp                 # CoA tables
grep -n "HERO_CLASS\|WILDCARD_MODE" src/server/coa/AscensionMysticEnchantRules.h                 # 10, 0x40
grep -n "bool IsBot()" -A3 src/server/game/Server/WorldSession.h                                 # bot guard
grep -n "sMapMgr->Update\|ProcessCliCommands" src/server/game/World/World.cpp                    # tick order
grep -n '"spell_proc"\|"spell_linked_spell"\|"config"' src/server/scripts/Commands/cs_reload.cpp # reloads
grep -n '{ "aura"\|{ "unaura"\|{ "additem"' src/server/scripts/Commands/cs_misc.cpp              # GM commands
```

In the pinned SQUID checkout (`~/upstream/squid-ref`):

```bash
grep -n "^bool IsRealPlayer" -A5 src/Bot/PlayerbotAI.cpp
grep -n "define GET_PLAYERBOT_AI" src/Script/Playerbots.h
grep -n "^AiPlayerbot.BotActiveAlone \|^AiPlayerbot.botActiveAloneSmartScale" conf/playerbots.conf.dist
```

If a grep returns nothing, the upstream code moved: re-read that area and correct this skill before relying on
it. Counts that will drift (273 settings lines: 270 settings plus the `realm` and two `realmlist` lines, 45 hooks, 16 tables, 214 enchant scripts, 234 `spell_dbc` fields, 750
bots) are dated in the text; `repo_facts.py` regenerates the repository ones.
