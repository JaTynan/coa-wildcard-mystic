# Bot roster plan (long-term)

Status: one of the project's major goals, agreed with James on 27 Nov 2026. It is a large piece of work, not a quick
task, and nothing here is built yet.

Priority (James, 27 Nov): solving the lag comes first. The other uplift work already planned (pipeline, testing and
validation, then the enchant and talent fixes) also comes before this. Starting after the lag fix also means the
two effects can be told apart.

## The goal

James, 27 Nov: fewer bots that players actually meet are worth more than thousands that nobody sees. The bots should
be memorable: the same names, the same builds and the same gear every night, staying close to the players' levels.
There should be enough of them to keep raids, battlegrounds, dungeons and the world events running (world PvP,
gathering rushes, city raids), without those events taking every bot away from normal play.

## The shape

| Part | What it means |
|---|---|
| A fixed roster of about 400 bots | Always the same characters, mostly kept online. Moving a bot to where it is needed is cheaper than logging one in. Any rotation is kept slow: a few logins a minute, spread out. |
| Stable Wildcard core builds | Each bot has a core build for its role (tank, healer, damage) that never changes, plus a few abilities still rolled as players roll them. Its core rotation stays the same. |
| Fixed gear | A bot keeps its gear. It gets new gear only when its level band changes, not on SQUID's random refresh timer. |
| Premade guilds | Bot guilds with fixed members and only randomised names, so players come to know them. |
| Levels follow the players | The roster's levels track the real players' levels. Changing a bot's level re-learns spells and swaps gear, so it is done in batches in the 3:30 to 5:30 am window, never live. |
| World events back on | Invasions, gathering rushes, world PvP and city raids, drawing on the roster near the players. |

## Why it suits the server

The bots' expensive work is not standing around. It is these operations:

- rebuilding a bot's gear and talents, about 70 ms each by SQUID's own notes;
- logging bots in;
- teleporting bots to spots whose map data is not loaded yet, up to 128 ms a lookup by SQUID's own comment.

A fixed roster with set builds and gear removes most of the rebuilds and logins.

## Order of work, once its turn comes

1. Find and fix the lag spikes (experiments E1 to E5 and on; see `server-settings/server-settings.txt`). The likely
   fix is loading the map data for every teleport and quest spot once at start-up, off the world thread.
2. Turn SQUID 3.0's world systems back on, and turn the rebuild limit on (`AiPlayerbot.CoaLive.HeavyRefreshPerTick =
   1`) if the tests support it.
3. Build the roster:
   - the core-build lists per role;
   - the gear sets per level band;
   - the premade guilds;
   - the overnight level-matching job.
4. Tune with numbers: bots online, bots near each player, and how often events run, each checked against Timing.log.

## Open questions

- Whether 400 bots is enough when an 80-bot Alterac Valley, a 40-bot raid and dungeons run at the same time. This
  needs measuring.
- How many random abilities a bot keeps on top of its core build.
