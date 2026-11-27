# Bot roster plan (long-term)

Status: one of the project's major goals, agreed with James on 27 Nov 2026. It is a large piece of work, not a quick
task, and nothing here is built yet.

Priority (James, 27 Nov): solving the lag comes first. The other uplift work already planned (pipeline, testing and
validation, then the enchant and talent fixes) also comes before this. Starting after the lag fix also means the
two effects can be told apart.

## 1. Outcomes

The balance James set (27 Nov): the fewest bots that keep the world running, and bots players remember. In his
words, fewer bots that players meet are worth more than thousands nobody sees.

| # | Outcome | How it is measured | First target (a proposal; tune after the first month) |
|---|---|---|---|
| O1 | No freezes while players are on | Timing.log, records with a player online | Freezes of 2 s or more in under 2% of records; median per-minute worst under 300 ms |
| O2 | Queues fill | Time from queueing to start, for a battleground, a dungeon and a raid | Battleground under 5 min; dungeon under 3 min; a raid can be filled on the night |
| O3 | Events have people | Bots taking part in each invasion, rush, world PvP or city raid, near the players | An event near a player draws at least 10 bots without emptying the queues |
| O4 | Bots are memorable | Players meet the same named bots again and talk about them | Each regular player meets at least 5 named bots more than once a week; asked "which bot do you remember?", names come back |
| O5 | Bots feel alive, not scripted | Interactions: groups, duels, world PvP fights, trades, chat with players (SQUID's event log) | Rising week to week, not falling; no complaints about spam |

O4 and O5 are the hard ones to measure. The numbers show whether encounters happen. The weekly question to the
players shows whether they stick.

## 2. Requirements

### The roster: a hybrid of a named cast and random filler

| Part | Size (to measure) | What is fixed | What still varies |
|---|---|---|---|
| Named cast | About 100 to 150 | The rest of this row. Name with a meaning; faction and race; guild; home zone; role and core Wildcard build; gear set per level band; how it fights (rotation, range, aggression); how it behaves in world PvP, battlegrounds and dungeons; chat voice | A few rolled abilities on top of the core build, as players roll them |
| Random filler | About 250 to 300 | Faction mix and level spread | Builds and gear, rebuilt rarely (not on SQUID's 2-hour-to-14-day random timer) |

Rules for the named cast:

- **Names have meaning.** They fit their guild and home (a themed guild of a handful of bots), with the old-WoW and
  in-joke humour James's friends enjoy. No random letter strings.
- **The same bot fights the same way everywhere.** A player who has duelled Bot X knows how it plays in a
  battleground. Its core build and rotation do not change between sessions.
- **They keep their gear.** Gear changes only when the bot moves up a level band, and then to its set for that band.
- **Levels follow the players.** The cast's levels track the active players' levels. Level changes run in batches
  in the 3:30 to 5:30 am window, never during play: they re-learn spells and swap gear, which is the costly work.
- **Their home is predictable.** Each named bot has a home zone and a few haunts, so players run into the same faces.
- **Nothing is generated during play.** Builds, gear, names and guilds are prepared in data files and checked before
  they go live. During play the server only moves bots and runs their AI.

Rules for the filler:

- It keeps the world populated and fills queues: battlegrounds, dungeons, raids.
- It is rebuilt rarely, at most overnight, and is never logged in and out in a burst.

### Performance requirements (from the lag work)

- No bot operation may wait on the disk during play: map data for teleport and quest spots is loaded at start-up.
- Rebuilds are spread out: at most one per world update (`AiPlayerbot.CoaLive.HeavyRefreshPerTick = 1`).
- Bots stay logged in and are moved where they are needed. Any rotation of who is online is slow: a few a minute,
  spread out.
- Every new behaviour gets a before-and-after measurement on Timing.log, and goes back if it fails O1.

## 3. Levers

| Lever | Setting or work | Effect | Cost |
|---|---|---|---|
| Bots online | `MinRandomBots` / `MaxRandomBots` | Coverage of the world and the queues | Load only when the bots are awake near players (they sleep with nobody on) |
| Named versus filler | Roster data (new work) | Memorability against flexibility | Writing and checking the named data |
| Who is awake | `BotActiveAlone` (5% now), `ForceWhenInZone`, `ForceWhenInGuild` | Bots near players act; distant ones idle | Each awake bot costs AI time every tick |
| AI time budget | `CoaWorld.AiBudgetMs` (off now) | Caps bot AI per map tick; never skips bots near players, in combat or grouped | Distant bots act a little less often |
| Placement | Home zones (new); `ConcentrateInPlayerZone`; SQUID density control (needs `EnablePeriodicOnlineOffline`) | Bots where the players are | Teleports. Cheap once map data is warm; costly before the fix |
| Level policy | `SyncLevelWithPlayers` (0 now), `RandomBotFixedLevel`, the overnight job (new) | Bots at the players' level | Rebuilds, done overnight |
| Rebuild policy | `Min/MaxRandomBotRandomizeTime` (2 h to 14 days now), `HeavyRefreshPerTick`, fixed gear sets | Stable bots, less work | Less variety in the filler |
| Queue reserve | Keep N bots out of world events (new) | Battlegrounds and dungeons still fill during events | Fewer bots at events |
| World events | `CoaWorld.Invasions`, `ResourceRush`, `WorldPvp`, `CapitalRaid`, with their sizes and frequency | Moments with players | Bursts of movement and teleports |
| Chat | `CoaLive` (channels), Ollama chat (whispers) | Bots feel alive; named voices | CoA Live timers (cleared of the freezes in E3); Ollama runs off the server |

## 4. Tests

| Test | Proves | How |
|---|---|---|
| Lag gate (every change) | O1 | Timing.log for the evening against the previous one: share of 2 s+ records, median per-minute worst, worst tick (`spike_gates.py`) |
| Peak load night | O1 under the heaviest mix | An evening with an Alterac Valley, a raid and dungeons running at the same time, with one player on |
| Queue timings | O2 | Queue-to-start times from the server logs, per content type |
| Event turnout | O3 | Bots per event from SQUID's event log (`events.jsonl`), against the queue reserve |
| Named bot builds | Each named bot's build is valid and its rotation uses its core abilities | Gameplay test harness scenarios (as in `tests/gameplay`): learn the build, fight a target dummy, check the core abilities were cast |
| Data checks before going live | Names unique and allowed; builds legal for Wildcard; gear valid for level and role | A script run in the pull request, like the enchant SQL lint |
| Encounter log | O4 | Per player and week, from the event log and the online lists: named bots met, met more than once, met in more than one setting (world, battleground, dungeon) |
| Player question | O4 and O5 | Once a week, one question to the players: "which bot do you remember, and why?" |

## 5. Order of work, once its turn comes

1. **Lag fixed.** Map data warm at start-up; the rebuild limit on if the tests back it.
2. **World systems back on**, with the queue reserve, measured on the lag gate.
3. **Filler first.** Rare rebuilds, overnight level matching, slow rotation. Measure O1 and O2.
4. **First named cast**, about 30 bots in 5 themed guilds: one faction mix, their home zones, builds, gear and
   voices. Measure O4 for a few weeks.
5. **Grow the cast** towards 100 to 150. Tune counts, placement and events against O1 to O5.

## 6. Open questions (James)

- The size of the named cast, and of the whole roster, once the peak load night is measured.
- How many random abilities a named bot keeps on top of its core build.
- Who writes the names and personalities: James, Claude, or both (Claude drafts and James picks).
