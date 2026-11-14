# What we change on top of Conquest of Azeroth

Every customisation on James's Wildcard server, in one place. Nothing is edited on the running server by hand: each
change lives in this repository and is laid back on top of CoA's own files every time, so a CoA update can never
quietly undo it.

| Layer | Where | When it is applied |
|---|---|---|
| Code | `patches/` (`*.patch` files and `NN-name.ps1` scripts) | Each build, on a clean copy of CoA's code for that release. A patch that no longer fits stops the build and names itself. |
| Settings | `server-settings/server-settings.txt` | Every server start (patch night writes them into the config files). |
| Database | `sql/enchants/` | Every server start (safe to run again). |
| Client addon | `addon/WildcardEnchants` | Shipped to players by the launcher. |

## Code patches

Each script groups related changes. Turn a change off with its setting where it has one (no rebuild needed). Remove one
for good by deleting its part from the script.

| Script / patch | Change | Setting |
|---|---|---|
| `mystic-enchants-*.patch` | Mystic Enchants on Wildcard: enchant actions, SpellAffect data, altars on Wildcard | always on |
| `wildcard-ability-pool.patch` | Which classes' abilities Wildcard rolls from | `Wildcard.AbilityPool` |
| `10-mod-ollama-chat-fit.ps1` | Makes the AI chat module compile on the CoA core | always on |
| | Less bot chat in raids and dungeons (direct answers to players kept) | `OllamaChat.RaidChatterPct`, `OllamaChat.DungeonChatterPct` |
| `20-bots.ps1` | Bots level near real players | `AiPlayerbot.WildcardLevelNearPlayersPct` |
| | Bots without a resurrection raise dead group members after a fight | always on |
| | Bots fight by faction (team), not race, so cross-faction battlegrounds work | always on |
| | Bots in War Mode or High Risk attack Mercenaries of their own faction | always on |
| | Some random bots travel in groups (50% solo, 30% pairs, 15% fours, 5% fives) | `AiPlayerbot.WildcardGroupSoloPct` and the shares after it; `AiPlayerbot.RandomBotGroupNearby` |
| | Bot leaders invite only member bots, never real players | always on |
| `30-wildcard-rewards.ps1` | Free class training at the Wildcard trainer | `Wildcard.FreeClassTraining` |
| | Skill card drops weighted by quality | `Wildcard.CardDropQualityWeights`, `Wildcard.CardDropChancePerMille` |
| | Scrolls of Fortune count straight away instead of filling bags | `Wildcard.ScrollsStraightToCurrency` |
| | The free-pack bar updates when a duplicate card is revealed (was only at login) | always on |
| | Every duplicate card fills the free-pack bar, not only rank 1 duplicates | `Wildcard.AllDuplicatesFillPackBar` |
| | A full free-pack bar gives one of each sealed card pack, not one at random | `Wildcard.FreePackBarGivesAllPacks` |
| | A Case of Fortune is used up once opened: one case goes when its loot window closes, and any scroll not taken is mailed (cases used to pile up) | `Wildcard.CasesOfFortuneConsumed` |
| `40-battlegrounds.ps1` (battlegrounds and PvP) | Spirit guides raise every ghost beside them at each wave, and take a stuck "Waiting to Resurrect" off anyone already alive, and never raise (fully heal) someone already alive | always on |
| | Battleground Spoils at the end of each battleground (3 for a win, 1 for a loss), opened like the rare Adventurer's Cache | `Battleground.SpoilsEnabled`, `Battleground.SpoilsForWin`, `Battleground.SpoilsForLoss` |
| | Honourable world PvP kills give XP (killer and group nearby; same victim once per 5 minutes) | `WorldPvP.KillXPPercentOfLevel`, `WorldPvP.KillXPSameVictimSeconds` |
| | Battleground Spoils and quest-reward caches can hold a Case of Fortune and a sealed card pack (quest caches mostly golden packs) | `Battleground.Spoils*Percent`, `Wildcard.QuestCache*Percent` |
| `47-leaderboards.ps1` | Counts world PvP kills and records server firsts (boss kills, Prestige levels) for the website's leaderboards | `Leaderboards.*` |
| | Supplies in Adventurer's Caches, quest caches and Battleground Spoils come as a stack of 20, not 1 to 3 | `AdventurerCache.SupplyStack` |
| | Gear caches (random dungeon cache, Adventurer's Cache, Battleground Spoils) give 2 pieces of gear and twice the supplies | `AdventurerCache.RewardRounds` |
| `45-weekend-bonus.ps1` | Rotating weekly event, all week Friday to Thursday (Shanks-giving, Craftageddon, The Questathlon, Pull-a-palooza): PvP (honour, PvP XP, spoils, Insignia gold), Professions (profession XP, gathering yield, skill-ups) Quests (quest XP, gold, caches, reputation) or Dungeons (kill XP, reputation, random dungeon cache in dungeons and raids), shown on the website | `WeekendBonus.*` |
| | Insignia gold: about 1 silver per level of the dead player (stock: about 1 silver at level 30) | `Battleground.InsigniaGoldPerLevel` |
| `46-play-time-rewards.ps1` | Every hour of play gives a sealed card pack (1 in 4 golden) and sometimes a Case of Fortune | `PlayTimeRewards.*` |
| `48-bonus-stats.ps1` | Looted, quest, crafted and cache gear (not Manastorm caches; rings, necks and trinkets too) can roll 1 or 2 bonuses (1 in 4, then 1 in 4 for a second); each is a prismatic gem socket 1 time in 3, otherwise a stat that suits the item | `BonusStats.*` |
| `49-prestigious-legendary.ps1` | The Prestigious Cache gives its promised choice of one Legendary Enchant (pick a class, then the enchant; `.legendary` reopens it) | `Wildcard.PrestigeLegendaryChoice` |
| `50-manastorm.ps1` | Dead bots are raised at the end of a Manastorm floor | always on |
| | Every resurrection in a run (item, player spell or bot) uses one of the run's 5 shared charges | always on |
| | Opening a Manastorm cache puts its contents straight in the bags (mail if full) and removes that one cache, so stacks never get stuck | `Manastorm.CachesOpenIntoBags` |
| `51-profession-mastery.ps1` | Profession Mastery past skill 300: gathering yields rise to 3x, crafted gear's bonus-roll chances to 2x; `.mastery`, and the WildcardMastery addon shows it in the Skills tab and profession windows | `Mastery.*` |
| `52-racials.ps1` | Every active racial is off the global cooldown (Will of the Forsaken, Cannibalize, Gift of the Naaru); the client patch carries the same change (`client-patch/racials.py`) | always on |
| `53-wildcard-card-messages.ps1` | Setting an ability or talent card before the four starting abilities are rolled (straight after a prestige) explains why on screen and in chat, instead of only the raw SET_SKILL_CARD_UNKNOWN code | always on |
| `54-racial-plainsrunning.ps1` | Tauren Plainsrunning: running on foot builds speed over 60 sec up to level + 40% (100% at 60), on top of other speed effects; drains in 6 sec when you stop; not while mounted, held while carrying a flag | `Racials.Plainsrunning` |
| `56-racial-bloodrush.ps1` | Orc Bloodrush: +2% damage and haste per enemy in combat with you, up to 5; +15% movement speed for 6 sec after a killing blow; buff icons from the client patch | `Racials.Bloodrush` |

## Settings (summary)

Grouped and explained line by line in `server-settings.txt`: Wildcard realm (ability pool, no Pete Arr), experience
(3x, prestige, exploring, quests, gathering, world PvP, rested), progression earned not handed out, professions and drops, faster respawns (90 s
mobs, 2 min nodes), Auction House bot (stock, skipped items, prices), play with friends, SQUID's bots (world PvP,
load, waking, zones), PvP rewards, AI chat, MySQL and world server performance, view distance.

## Database

`sql/enchants/000-014`: Mystic Enchant data fixes (`014`: "your next X" buffs such as Empowered Light are used up
by that next spell). `090-mysql-tuning.sql`: MySQL settings that survive the manager.
`100-rune-rates.sql`: Runes of Descension 250% from quests, 150% from drops.
`110-manastorm-caches-unstack.sql`: Manastorm caches no longer stack, so each one opens and disappears when emptied.
`120-battleground-spoils.sql`: Battleground Spoils can be opened (used by the Battleground Spoils patch).
`150-custom-spells.sql`: our own spells for buff icons (Plainsrunning, Bloodrush), written by `client-patch/custom_spells.py`.
`130-battleground-dampening.sql`: everyone in a battleground does 20% less healing and gets 20% smaller absorb shields
(Ascension's "PvP - Battleground - Dampening", which CoA has but never applied).

## How changes are made

- Changes collect on one branch and go in as **one PR per patch night**, so each night is one merge, and one thing to
  roll back if it goes wrong.
- Every new code change gets a setting to turn it off where that's practical, and a line in this file.
- Fixes that are really CoA bugs are worth reporting to the CoA team; when they fix one, its patch stops fitting, the
  build says so, and we delete it.
