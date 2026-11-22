# The hypothesis menu

Ranked on 2026-11-22 by how well each fits the one day of data in `evidence-2026-11-22.md` (A1-A14 there) plus the
history in `timeline.md`. **None is proven.** A rank is a prior for choosing the next experiment, nothing more.
Re-rank whenever a new evening of data or an experiment result comes in, and write the reason in the campaign log.

Every experiment below changes server behaviour. **Classify each with wildcard-change-control first.** Most touch
a setting that is *not yet* in `server-settings/server-settings.txt`, so they are not the pre-approved "standard
change"; expect the score to come out above LOW because they act on all 750 bots and can only be seen working live.
A bot-count change is not a standard change either: the setting's comment states no range (2026-11-22), so it is
scored. James merges. One experiment per night (settings apply at the nightly restart). The matrix and "standard
change" are INTENDED DOCTRINE (PR #232, unmerged on 2026-11-22).

**Ranking as of 2026-11-22 (a prior, from one day of data): H1 first, H2 second, H3 third.** H2 is ranked
below H1 because of the instance-map evidence in its "Against" paragraph. This is evidence, not proof: the root
cause stays UNKNOWN until an experiment moves the beat.

How to read a row: **Mechanism** is what the sources say (file and function verified at the pinned commits, see
`engine-and-timers.md`). **Predicts** is what you should see if it is the cause. **Experiment** is the cheapest
reversible test and the numbers that would confirm or refute it. **Before a fix is adopted** is what must be shown.

## Tier 1: fit the 20-second, one-thread, players-only pattern

### H1. The random bot manager's cycle (SQUID), on the world thread

- **Mechanism.** `RandomPlayerbotMgr::UpdateAIInternal` (`src/Bot/RandomPlayerbotMgr.cpp`) runs from SQUID's world
  script every `RandomBotUpdateInterval x (focus + 25) x 10` ms: 20 s when 90% or more of the bots are online,
  10 s below that. Each run walks the bot list and calls `ProcessBot` for up to 45 online bots (their periodic
  "update": revive the dead, re-randomise gear, teleport to a new area, log out and schedule a return) and logs in
  up to 15 more (45 while under 90%). With `AiPlayerbot.DisabledWithoutRealPlayer = 1` (set in server-settings.txt)
  there are no bots online, so nothing to do, until 30 s after the first real player arrives; logins then complete
  in batches on the world thread (`World::ProcessQueryCallbacks`).
- **Fits.** A1 (nothing with 0 players), A6 (20.03 s beat only with a player on: 20 s plus a tick), A7, A8 (one
  thread, seen in the login ramp), A5 (largest during the login ramp). The login part also fits A14: the bots'
  logins are database work, and mysqld ran at about one core every 40 s for the ten minutes of the ramp. That
  supports "logins are costly", for the first minutes only; it does not show the steady-state ticks are logins. Spikes predate 19 Nov and SQUID 3.0; the random bot manager is a
  long-standing part of mod-playerbots, but its code at the 2.9.4 commit was not read for this file.
- **Does not explain by itself.** Why the logged slow ticks were larger after 19 Nov (evidence C; confounded, not
  a rate) unless SQUID 3.0 made
  the per-bot update dearer (it added CoA World/Live hooks inside it, for example `CoaWorldIsBotHeld`,
  `CoaLive::OfflineSeconds`); why the window p95 is 95 ms.
- **Predicts.** `spike_gates.py cycle`: best period 20.0-20.1 s at full count; near 10 s in the first minutes
  after login (not shown on 22 Nov: 10 minutes of data is too little, controls explained as much).
- **Experiment E1 (discriminates H1 from H2 and H4).** Add `modules\playerbots.conf | AiPlayerbot.RandomBotUpdateInterval = 30`
  for one evening. Written prediction: **once 90% of the bots are online** (from about 15-25 minutes after the
  first login; run `cycle --from` then) the beat moves to 30.0-30.2 s (autocorrelation peaks at 30/60/90 s and
  none at 20/40) and long ticks per hour fall by about a third; their size does not fall. **While fewer than 90%
  of `MinRandomBots` are online the cycle is 15 s, not 30** (`interval x (focus + 25) x 10` ms with focus 25:
  `RandomPlayerbotMgr.cpp:415-427`), so a `cycle` run that includes the login ramp will show a 15 s component;
  that is expected and refutes nothing.
  **Before calling it refuted, confirm the live value**: on the VM
  `findstr /B AiPlayerbot.RandomBotUpdateInterval "C:\Games\CoA Server\Core\configs\modules\playerbots.conf"`
  prints 30, `settings-report.txt` does not list the name as unknown, and the server restarted after the merge.
  A beat still at 20.0 s **with the value confirmed** refutes H1: go to H2. Side effects to tell James and to
  record: bots log in and refresh 1.5 times more slowly; the same setting also scales each bot's first-update,
  randomise and teleport delays at login (`RandomPlayerbotMgr.cpp:1861, 1938-1952`), a second small difference
  from the baseline. (Why it discriminates: `randomBotUpdateInterval` is read only inside
  `RandomPlayerbotMgr.cpp`, and H2's `CHANNEL_TICK_MS` is a constant.)
- **Experiment E2 (size).** With the interval back at 20, add `AiPlayerbot.RandomBotsPerInterval = 20` (default
  60). Prediction: beat stays at 20 s, the median of the window maxima (1,196 ms on 22 Nov) falls to roughly a
  third if the cost is per bot processed. No fall = the cost is a fixed part of the cycle (the walk over all
  bots), not the per-bot work.
- **Experiment E3 (which per-bot work).** Only if E2 confirms: lengthen teleports
  (`AiPlayerbot.MinRandomBotTeleportInterval` / `Max`, defaults 600 / 2400) for an evening; a teleport loads
  map grids and navigation tiles on the calling thread. Or ask James to switch on SQUID's own timer
  (`AiPlayerbot.PerfMonEnabled = 1`, console `playerbots pmon`; UNVERIFIED on this VM), which names the slow
  operation directly.
- **Fix options, cheapest first.** (a) smaller batches more often (`RandomBotsPerInterval` down, interval down in
  proportion: same throughput, shorter stalls); (b) fewer teleports; (c) report upstream to SQUID with the data;
  (d) a patch that spreads the batch over several ticks (C++, per-tick code for all bots: HIGH, patch-reviewer).
- **Before a fix is adopted.** E1 moved the beat (proof of location); the fix's evenings meet the exit metric at
  750 bots; bots still log in, refresh and travel (James plays an evening and looks; note what "bots feel dead"
  would look like, as the 8 Nov wake-radius freeze did).

### H2. CoA Live's channel timers (SQUID 3.0), on the world thread

- **Mechanism.** `ChannelTimers` in `src/Ai/Coa/Social/CoaLive.cpp` runs every `CHANNEL_TICK_MS = 20000` (a
  constant, not a setting). It walks every online player, groups bots by zone and guild, and lets bots speak in
  General, Trade, LookingForGroup and guild chat **where real players are**. Trade lines price items
  (`PriceOf`: market price, else the lowest buyout on the auction house, 12,000 listings a house since 21 Nov).
- **Fits.** A1, A6, A7, A8; new with SQUID 3.0, so it would also explain evidence C.
- **Against.** The walk is light on paper; seconds would need an expensive inner step. Spikes over a second
  existed on SQUID 2.9.4, which has no CoA Live. **And on 22 Nov the player was inside a dungeon instance for 69
  of the 117 records.** The per-zone branch (General, Trade with `PriceOf`, LFG) runs only for zones that hold a
  real player and a "free random bot", and `FreeRandomBot` rejects any bot on an instance map
  (`CoaLive.cpp:1134-1141`, `p->GetMap()->Instanceable()`). So that branch, the only place `PriceOf` runs, had
  nothing to do in those minutes, yet long ticks were just as common inside the runs as outside (65% against
  67%, A12). What is left of H2 for those minutes is the walk over all players itself and the guild and
  night-bank lines. This weakens H2; it is one day with one player and does not rule it out.
- **Experiment.** Only after E1 says "not H1" (the beat stayed at 20 s): add
  `modules\playerbots.conf | AiPlayerbot.CoaLive.Enable = 0` for an evening. Prediction: the 20 s beat and the
  long ticks disappear. Side effect: SQUID's living chat goes quiet (the Ollama chat is separate and stays).
- **Before a fix is adopted.** Same as H1; and decide with James whether the feature is wanted at all.

### H3. One map thread stuck every 20 s (not the world thread)

- **Mechanism.** The world thread waits for every map (`MapUpdater::wait`). If one continent's update takes
  seconds, the counters look exactly like H1/H2: one CPU busy, the rest waiting. A 20 s rhythm would have to
  come from something scheduled by H1/H2 and executed later on the map thread (a teleported bot arriving, a
  re-randomised bot re-equipping).
- **Why it matters.** It changes the fix, not the experiments: E1 still moves the beat. To tell the thread, you
  need instrumentation (Phase 5: per-map timing, or a stack sample).

## Tier 2: fit part of the pattern

### H4. Auction House bot minute cycle

- **Mechanism.** `AuctionHouseMgr::Update` every 60 s on the world thread: expiry scan of all listings, then
  `AuctionHouseBot::Update` (`modules/mod-ah-bot-plus`): up to `ItemsPerCycle = 600` new listings and a buy cycle
  that runs a synchronous `SELECT id FROM auctionhouse WHERE itemowner NOT IN (...)` over every listing.
  Stock: 4,000 a house from 11 Nov, 12,000 from 21 Nov.
- **Fits.** One thread. **Against.** It runs with nobody on too, and A1 shows no long ticks then (one 534 ms tick
  at 14:00 in five hours). Its period is 60 s; the beat is 20 s.
- **Experiment.** None needed now. Re-open if `cycle` shows a 60 s component that is **not** just the third
  harmonic of 20 s (it explains 0.19 at 60.12 s on 22 Nov, which is 3 x 20.04).

### H5. Too many bots awake around the player (the old finding)

- **Mechanism.** `BotActiveAloneForceWhenInZone = 1` keeps every bot in a player's zone fully awake, and
  `RandomBotConcentrateInPlayerZone = 1` sends bots there. One continent's map thread carries them
  (`docs/performance.md`: "one busy thread per map").
- **Fits.** A3: median 37 ms and window p95 95 ms with one player. **Does not fit** the 0.3-5 s ticks: this load
  is steady, not a 20 s pulse.
- **Experiment.** After the long ticks are dealt with, or in parallel on different evenings: bots 750 -> 500 (an
  existing setting, but its comment states no range, so it is scored with wildcard-change-control, not
  pre-approved; James merges). Prediction: median and p95 fall roughly in proportion; the 20 s
  beat stays. **Not available as a lever:** `BotActiveAloneForceWhenInZone = 0`. It was tried on 8 Nov (e608f61),
  bots near players froze for 20+ minutes, the cause was never found, and it was put back (c02ba12, #95). Do not
  retry it without first explaining the freeze.
- SmartScale (`AiPlayerbot.botActiveAloneSmartScale`, floor 50 ms, ceiling 200 ms) is **not** in
  server-settings.txt; the VM runs whatever its `playerbots.conf` holds (upstream default: on). It reacts to the
  largest recent tick, so with a long tick every 20 s the far-away 5% are asleep nearly all the time.

### H6. Our own per-tick code

- **Mechanism.** 17 patches hook `OnPlayerUpdate`, which runs for every bot on every map update. Verified
  examples: `patches/46-play-time-rewards.ps1` reads its settings (`Interval()`, two `sConfigMgr->GetOption`
  calls) **before** its bot check; `82-runes-in-currency-tab.ps1` and `86-scrolls-of-fortune-redeem-themselves.ps1`
  scan every character's bags every 2 s with no bot check; several racials call `GetOption` per update for their
  race. In this core `GetOption` builds an environment-variable name and calls the C runtime's environment lookup
  on every call when no such variable exists (`ConfigMgr::GetValueDefault`, `GetEnvFromCache` in
  `src/common/Configuration/Config.cpp`).
- **Fits.** A steady cost that grows with awake bots (so it helps explain A3). **Does not fit** a 20 s pulse of
  seconds. Cost unmeasured.
- **Evidence it is not required for long ticks.** The official .114 build (no patches of ours) logged 2,655 ms
  and 1,451 ms with a player on (evidence C; two lines, one session).
- **Experiment.** The clean one is the official-server evening (H8). Turning the settings off does **not** remove
  the hooks: a racial switched off still runs its race check and its `GetOption` read. So "bisecting by settings"
  only tests the work behind the switch, not the hook. Procedure in the section "Bisecting our own switches".
- **Fix options.** Bot check first in each hook; read settings once at start-up or on reload instead of per
  update (see wildcard-patch-authoring for the patch checklist). C++ in per-tick code: classify, expect HIGH.

### H7. Dungeon Clear (on since 19 Nov)

- **Mechanism.** Two `OnPlayerAfterUpdate` hooks per character per update, a 60 s ghost probe, two
  `OnAllCreatureUpdate` filters that return at once outside two dungeons (`src/DungeonClearModule.cpp`).
- **Fits.** Arrived in the 19 Nov step. **Against.** Nothing in it runs at 20 s; on 22 Nov the long ticks were as
  common outside Dungeon Clear runs as inside (67% against 65% of records, evidence A12).
- **Experiment.** `DungeonClear.Enable = 0` for an evening (existing setting; read at start-up only). Prediction
  if guilty: beat gone. Low value before E1.

### H8. "It is upstream (CoA core or SQUID), not us"

- **Status.** Partly supported already: evidence C (official build, 2.6 s tick). H1 and H2 are both upstream code.
- **Experiment (James only: it touches the installer and rollback, a hard stop).** `vm\Restore-Official.cmd`
  with the server stopped, play one evening with the same settings, then `Run-PatchNight-Now.cmd` to go back.
  Read from `PatchNight.ps1`, not tried: the 4 am nightly restart leaves the official server in place (it runs
  with `-NoInstall`), the weekly patch-night run (Tuesday 11 pm by the script's default; what the VM has
  registered is UNVERIFIED) reinstalls ours. On the official server: settings that need our build
  are ignored (server-settings.txt says so for the Mystic Enchant lines), Mystic Enchants on Wildcard, the racial
  kits and the Ollama chat (our build adds that module) are gone for the evening, and our `sql/enchants` rows
  that name our scripts may produce start-up errors (UNVERIFIED). Prediction if upstream: same 20 s beat, same
  size. If the long ticks vanish: it is ours, go to H6 and the bisection.
- **Cheaper first:** E1 costs one settings line and tells more.

## Tier 3: checked against 22 Nov and found quiet (re-open only on new evidence)

| Hypothesis | Mechanism | Why it is parked | Re-open when |
|---|---|---|---|
| Disk latency | MySQL flush every 3 s, log writes, antivirus, a Proxmox backup | writes under 1 ms all day | `perf-at` hint "disk" |
| Paging | world server grows until Windows pages | 5.1 GB free at worst | hint "paging"; working set climbing day over day |
| Whole-VM stall | host steals the VM's CPUs | counter rows never over 6.2 s apart | hint "sampler-gap" |
| Slow SQL statement | one query over 0.5 s on a game thread | none after 10:32 (both phases) | entries at spike times |
| Waiting on MySQL or a lock | many synchronous queries (SQUID has dozens; e.g. `PetIsDeadValue::Calculate` queries `character_pet` from the map thread) | **parked for the steady state only** (mysqld never above 26% after 15:00). **Open for the login ramp**: mysqld at 72-111% of a core every 40 s, 14:37-14:47, and two `mysql-busy` spikes (A14) | any `mysql-busy` hint; spikes with process CPU down and **no** busy CPU |
| Player/bot autosaves | 900 s each, staggered | not periodic at 20 s; writes are asynchronous | a 15-minute component |
| Ollama chat | HTTP on 4 worker threads; saves every 10 min | not on the game threads | a 10-minute component |
| Console logging (changed 20 Nov, f9dc45a) | synchronous console writes | not parked as solved: shipped 20 Nov, no after-measurement, `world-console.log` 2.99 GB on 22 Nov before the rotation of #229 had run; status OPEN. It is in this table only because a write stall is not a busy CPU | the check in SKILL.md fails |
| Memory growth with uptime | - | the working set follows the bots (4.2 GiB with the world empty, 6.5 GiB with 750 bots in); no growth trend visible within one 7.5 h start | spike size rising hour by hour within one start |
| 40-second character list | full-table delete per login | fixed 8 Nov by the index (#84) | the index is missing (`SHOW INDEX FROM character_spell`) |

Not yet looked at, because the data had none: two or more players, players in different zones, dungeons,
battlegrounds, cities, the CoA World events (45-240 min apart; a 7.5 h day with one player cannot show them).

## Bisecting our own switches

`CHANGES.md` says: "Turn a change off with its setting where it has one (no rebuild needed)". That makes a
bisection possible without a build, with three limits: a switch removes the feature's work but not its hook
(H6); "always on" patches have no switch; and each step costs a night.

Only do this if the official-server evening (H8) says the long ticks are ours.

1. List the switches: the "Setting" column of the patch table in `CHANGES.md`. On 22 Nov: the ten `Racials.*`
   lines, `Wildcard.ManaforgedBarrier`, `Wildcard.RestingManaRate` (1 = stock), `Wildcard.WorldforgedDropChance`
   (0 = no drops), `PlayTimeRewards.Enabled`, `BonusStats.Enabled`, `Mastery.Enabled`, `Leaderboards.Enabled`,
   `WeekendBonus.Enabled`, `Battleground.SpoilsEnabled`, `DungeonClear.AutoStart`, `GroupXP.*` (empty = stock),
   `CoA.MysticEnchants.*`.
2. Night 1: turn off the half added most recently (17-21 Nov: `Racials.GraveDefiance`, `.Spellsword`,
   `.Overclock`, `.ArcaneHunger`, `.ProspectorsSpirit`, `Wildcard.RestingManaRate = 1`,
   `Wildcard.WorldforgedDropChance = 0`, `DungeonClear.AutoStart = 0`). Tell the players: their racials change
   for the evening. Written prediction: if one of these is the cause, the beat or the long ticks go.
3. If they go: next night restore half of that half. If they stay: restore all, turn off the other half.
4. About five nights to isolate one switch out of ~20. If every switch is off and the long ticks remain, the cause
   is in an always-on patch or a hook itself: only a build without that patch can test it (wildcard-build-and-env;
   2-3 hours a build).

Each night's change is several settings at once **on purpose**; record it as one experiment with its prediction,
and never mix it with any other change that night.
