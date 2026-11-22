# Worked examples: the full working

One section per recipe in `SKILL.md`. Each gives the observation, the sum, what the mechanism predicted, what
was done, and the evidence. Hashes are commits on `origin/main` unless a branch is named. Read a commit with
`git show -s --format='%h %ad %s%n%b' --date=short <hash>`. Numbers from the live server are quoted from the
repo (commit bodies, settings comments, docs), not re-verified on the VM on 2026-11-22. Where an input is
illustrative rather than measured, it says so.

Contents: 1 proc rate, 2 double application, 3 analogy, 4 capacity, 5 tails, 6 query cost, 7 growth,
8 overflow, 9 layer swap, 10 hot path, 11 economy.

---

## 1. Proc rate and uptime: runaway procs and dead triggers

**Observation (deep audit, 15 Nov).** Legendary enchants firing on every hit with no ability filter and no
internal cooldown; others never firing at all.

**Mechanism.** Ascension keeps proc rules in its own server database; the surviving spell data has them
blanked. On this core an aura with proc flags and no `spell_proc` row procs on every qualifying hit, and an
aura with no proc flags and no row never procs (`docs/enchant-restoration.md`, Lessons; 7a1f7a8; 8d8e256).

**The sum.** For a row `(SpellId, ..., Chance, Cooldown ms)`:

```
procs per minute, no cooldown      = triggers per minute x chance
mean gap between procs             = cooldown + 1 / (chance x triggers per second)
ceiling from the cooldown alone    = 60 / cooldown
```

Rows from `sql/enchants/015-runaway-procs.sql`, with 60 qualifying hits a minute as an **illustrative** input:

| Row | Chance | Cooldown | Before (every hit) | After | Ceiling |
|---|---|---|---|---|---|
| 84506 | 100% | 4 s | 60 / min | 12.0 / min | 15 / min |
| 965505 | 33% | 4 s | 60 / min | 8.5 / min | 15 / min |
| 965504 | 33% | 12 s | 60 / min | 4.0 / min | 5 / min |
| 84508 | 33% | 0.1 s | 60 / min | 19.2 / min | 600 / min |

```
python3 -I scripts/wcalc.py proc --chance 0.33 --triggers-per-min 60 --icd 4
```

The last row shows what the 0.1 s floor is for. It does not limit the rate in normal play; it stops one hit
setting off a chain of procs within the same instant ("so one hit cannot set off a chain", cde036b).

**What was done.** `015-runaway-procs.sql` in three parts: rows giving the tooltip's cooldown and chance; rows
with a spell-family filter so only the named ability counts; and named-ability rules through
`spell_wcme_enchant_action` where several families or an extra condition are involved. `016-dead-triggers.sql`
gives each dead enchant a `spell_proc` row and an action rule. A later patch added per-target cooldowns for four
enchants that hit targets (df063a2, `patches/63-enchant-target-cooldowns.ps1`).

**Record-keeping note.** The commit message of 7a1f7a8 says 29 enchants and then lists 7 + 2 + 24 = 33;
`CHANGES.md` and `docs/enchant-restoration.md` say 33. Cite 33 and the file, not the commit's opening figure.

**Uptime reasoning in a decision.** Consecrated Strikes had no surviving chance. It went in at 20% "assumed"
(bbb213c, bf0733e) and James set 35% the same day (730ecea); his reason, kept in `enchants/legendary-notes.md`,
is an uptime argument: near-constant uptime with slow weapons, no extra clutter with fast ones. To check an
argument of that kind you need the buff's duration and the ability rate for a slow and a fast weapon, then
`wcalc.py proc --duration`. Those inputs are not recorded in the repo for this enchant: look them up before
quoting an uptime figure.

**Test prediction to write down.** "With the enchant on, N qualifying hits on a dummy in a minute give about
X procs (range X-2 to X+2), never two within the cooldown; a non-listed ability gives none."

---

## 2. Double application

### 2a. Units: the jump multiplier (patch 71, 508789d, 17 Nov)

**Observation.** Chain Heal and Chain Lightning with any of Tidal Force, Overflowing, Transcendental Embrace,
Booming Thunder or The Water Duke's Stolen Totem: each jump many times stronger than the last.

**Mechanism.** The data writes "loses X% less per jump" as a flat +X on the jump multiplier modifier. The
multiplier itself is a fraction (0.8 in the patch's own example). The core added X straight onto the fraction.
Checked in the pinned core (`SpellInfo.cpp`, `SpellEffectInfo::CalcDamageMultiplier`): the function takes the
multiplier and passes it to the spell-modifier routine unchanged.

**The sum** (X = 20):

```
bug:  0.8 + 20        = 20.8  per jump  -> hits 1, 20.8, 432.6, 8,998.9
fix:  (0.8 x 100 + 20) / 100 = 1.0 per jump -> hits 1, 1, 1, 1
unmodified:             0.8   per jump  -> hits 1, 0.8, 0.64, 0.512
```

`python3 -I scripts/wcalc.py jump --base 0.8 --flat 20 --jumps 3`

**Why the sum is the proof.** A factor of about 21 per jump is not a tuning error; only a unit mismatch
produces it. The same sum gives the test: the second target should take the same as the first with a 20-point
modifier, not 21 times as much. The patch header also records the negative that makes the fix safe: no stock
spell uses a flat modifier here, and percentage modifiers work as before.

### 2b. Two sources: the 18 Nov reviews against the core

After the legendary and epic batches, each enchant we had touched was checked against the core's own rules.

| Enchant | What both sources did | Net effect | Fix | Commit |
|---|---|---|---|---|
| Soul Erosion (1180480) | Our SQL replaced the core's proc row with one at 100%; the core's rule then fired on every tick; our own 8% rule ran too | Far above the spell's 8% | Ours removed, core row restored | f9806da |
| Wraithweaver: Shadow Orbs (1544910) | File 038 replaced the core's 20% row with 100%; our own 20% roll on top | An orb on every tick plus extra | Core row restored, our orb gain removed | 06d67c5 |
| Shadow Visions (1570700) | The core builds Soul Fragments; our script added a second per Mind Flay tick | Twice as fast | Our fragment gain removed | 2d391f3 |
| Moon's Wrath (1180590), Critical Time | The core's bonus table gives the crit; our batch 3 hook gave it again | +16% instead of +8%; +10% instead of +5% | Hook removed | 5bf04bd |
| Compound Power (979740) | Twin's core rule gave 2 combo points on top of ours | 4 a shot | Twin link removed | 99174fa |
| Iron Guard (1181340) | The release core already reduces melee and ranged damage after a block | Would have applied twice to melee | Patch 69 narrowed to spells | `enchants/epic-notes.csv` |

Equally useful are the "no doubling" results in the same commits (Demolisher, Blood and Guts, Overflow,
Blazing Flame, Stormbound Instinct): each says why, usually "the aura does not stack" or "ours covers versions
the core's list misses".

**Standing lists the reviews left behind:** `enchants/core-proc-row-replacements.csv` (11 rows on 2026-11-22; the commit that
added it said six enchants where our SQL replaces the core's proc row), `enchants/swap-own-effects.csv` (19 deliberate swaps whose own proc aura can still
fire beside the twin), `enchants/taught-spell-doubles.csv`, `enchants/core-rule-version-gaps.csv`.

**Earliest form of the rule** (31 Oct, file 004, 360dc22): "When both spells carry the same real effect, remove
ours first, or the player gets the bonus twice" (`docs/enchant-restoration.md`, Lessons).

---

## 3. A number by analogy

| Enchant | Missing | Analogue and reasoning | Where recorded |
|---|---|---|---|
| Blood Drinker (965389) | Heal amount | Text describes a small, attack-power based heal; Bloodthirst's own heal is a small percentage of health; set to 3% of maximum health + 25% of attack power | `enchants/epic-notes.csv` row 965389, assumptions column |
| Consecrated Strikes (965295), Consecrated Weapon | Proc chance | 20% assumed, then 35% by James with an uptime reason | bbb213c, bf0733e, 730ecea; `enchants/legendary-notes.md`; `CHANGES.md` prints "35% assumed" |
| Blessing of the Divines | Amounts for three blessings | "level 60 class numbers" (Circle of Healing, Renew, a party energize) | b570a98 |
| Enchants that copy a class ability | Behaviour and numbers | The CoA core's own class version (Blooming Shot, Eternity, Nature's Power) | `enchants/legendary-notes-header.md`, Sources 3 |
| Deadly Bite (965292) | Chance for Sharpened Blade | 20% "assumed", marked in the commit | 8cdfebf |

**The recording convention that exists.** Three columns in the notes files: `assumptions` (what was decided
without a source), `sources`, `decisions` (James's calls, dated). The generated `enchants/legendary-notes.md`
and `enchants/epic-notes.md` print them per enchant with "What the pull requests said". Best-guess SQL rows are
"marked in each row's comment" (`CHANGES.md`, file 016).

**The correction loop that exists.** Guessed numbers from PRs #164 to #167 were checked against the archived
builder tooltips on 16 Nov (8cdfebf, PR #169): Curse of Arugal's Goldrinn's Guile became +20% from the tooltip
where the client data has 40%. That is the conflict rule in action: tooltip over data.

**Contrast, so you do not over-label.** Abiding Fel Energy's 87 + 20% AP + 30% SP came from the builder tooltip
(b570a98). It is sourced. Only write "assumed" where nothing survives.

---

## 4. Tick capacity: the 7 Nov table and the 1,250 decision

Source: `docs/performance.md` (4ce450e, 35c8e95), settings comments, commits 70f055b, 2ce36a4, aca9022.

| Setup | Ticks/s | Average | 95% under | Peak | Ticks/s x avg | ms per 1,000 bots |
|---|---|---|---|---|---|---|
| 1,000 bots, 1 map thread | 33 | 30 ms | 61 ms | 489 ms | 990 | 30 |
| 1,000 bots, 4 map threads | 50 | 20 ms | 39 ms | 58 ms | 1,000 | 20 |
| 1,500 bots, 4 map threads | 26 | 38 ms | 66 ms | 301 ms | 988 | 25 |
| 1,250 bots, 4 map threads | 30 | 33 ms | 64 ms | 112 ms | 990 | 26 |

**Reading 1: the loop is saturated.** Every product is about 1,000 ms of work per second. The world loop runs
ticks back to back, so "33 ticks/s" and "30 ms average" are the same fact. That is why the doc says ticks per
second "only means something with bots awake".

**Reading 2: one core.** The settings comment for map threads: 1,000 bots "kept one core busy while the other
seven idled (21% CPU, 30 ms a tick)". One core of eight is 12.5%; 21% is a little under two.

**Reading 3: threads helped 1.5x, not 4x.** `wcalc.py amdahl --before 30 --after 20 --threads 4` gives 56% of
the tick that did not speed up, and a floor of about 17 ms with unlimited threads. The doc's explanation fits:
maps update in parallel, but most bots are on Eastern Kingdoms and Kalimdor, and each map has one busy thread.
Prediction that follows: more vCPUs or map threads add little. (The move to 6 threads on a 10-core VM, 61a5be9,
has no measurement recorded.)

**Reading 4: the decision was made on the tail.** 1,250 against 1,500: averages 33 and 38 ms, 95% figures 64
and 66 ms, nearly the same. Peaks 112 and 301 ms. The doc: "the 95% figure is close to 1,500's, but the spikes
players feel are a third as large".

**Reading 5: worst case.** With every bot in a player's zone awake, awake bots are roughly zones with players x
bots per zone, capped by the total. The doc's "10 zones x 200 bots would be about 2,000 awake" is the upper
picture that motivated the wake rules and SmartScale (sleeps far bots past 50 ms, fully paused at 200 ms).

**What the table cannot support.** One sample per setup; no record of players online, where they were, or how
long each sample ran; the 1,250 row has no memory figure. Per-bot cost is not constant (20 to 30 across rows).
Use it for direction, and take a fresh baseline before any new decision. The doc itself is partly stale as of
2026-11-22: its "Levers for later" lists `AiPlayerbot.BotActiveAlone` as "now 15", and
`server-settings/server-settings.txt` has had 5 since 7 Nov (240d773).

**Sequel.** 1,250 to 1,000 on 9 Nov (95% under 74 ms, 99% 147 ms, worst 1.3 s with 3 players, ff00757); 750 on
21 Nov (6a3e017). Bot count has been the lever each time the tail got worse; worst ticks were 1.3 s (3 players, read around the cut from 1,250 to 1,000 on 9 Nov) and 2 to 5 s (2 players, read around the cut from 1,000 to 750 on 21 Nov); the record does not say which side of each cut the reading was taken on, so no conclusion about bot count follows.

---

## 5. Tail analysis: the logging case, and why it is still open

**The numbers (settings comments in `server-settings/server-settings.txt`).**

| Date | Bots | Players | 95% under | 99% | Worst | Median |
|---|---|---|---|---|---|---|
| 9 Nov | 1,250 | 3 | 74 ms | 147 ms | 1.3 s | |
| 20 Nov | about 880 | | 69 ms | 586 ms | 2.9 s | |
| 21 Nov | 1,000 or 750 (not recorded which side of that day's cut) | 2 | | | 2 to 5 s | 36 ms |

**Why averages are useless here.** `wcalc.py spike --median 36 --spike-ms 3000 --per-min 1`: one 3 s tick a
minute among about 1,584 ticks moves the mean by 1.9 ms and is invisible to the 95th, 99th and 99.9th
percentiles. The manager's "95% under" figure, which `docs/performance.md` rightly calls the one that matters
for smoothness, cannot see a freeze that rare. You need the worst tick and a count of ticks over a threshold.

**Two regimes.** On 20 Nov the 99th percentile was 8.5 times the 95th. Compare 9 Nov: 147 / 74 = 2.0. A ratio
that jumps like that says at least 1 tick in 100 is doing something different, not that the server is evenly
overloaded.

**Mechanism proposed (f9dc45a, PR #204).** About 880 bots; every log line written synchronously with the world
update; the console receiving every Wildcard roll ("dozens per bot as it builds") and every challenge packet
sent to a bot; `world-console.log` at 2.9 GB.

**The prediction that should have been written** (it was not; this is the lesson):

```
If right:  99% falls from 586 ms toward about twice the 95% figure (as on 9 Nov); worst tick under 1 s;
           world-console.log grows far more slowly.
If wrong:  99% and worst stay where they are.
Will NOT change: 95% under about 69 ms; median.
```

**Fix.** Settings only: `Log.Async.Enable = 1`, `Logger.coa = 4,Server`,
`Logger.module.coa_challenges = 3,Console Server`.

**Outcome on record.** No after-measurement. On 21 Nov: worst ticks of 2 to 5 s with 2 players on, median
36 ms; bots cut to 750 "while we find the cause" (6a3e017). Then measuring-only instruments: Timing.log once a
minute, Windows counters every 5 s to `Logs/perf`, `Logs/console-history.txt` to compare before and after the
19 Nov core update, a slow-query log over 0.5 s (9ba9f45, PR #225). On 22 Nov code to clear the console log
once and rotate it per start was merged (759c7b6, #229). It had not run by 16:33 that day: the merge (08:59) came
after that day's only server start (08:53), and the file was still 2.99 GB. Whether the log still grows by
gigabytes is **open**: check after the next restart (`wildcard-lag-spike-campaign`, "Check whether the logging
change holds").

**Honest status.** In the library's agreed words: shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run yet; status OPEN. Removing synchronous console logging was sound. It has not been shown to be the cause of the
multi-second ticks: one mechanism did not explain all observations. Open. Continue in
`wildcard-lag-spike-campaign`; read the instruments with `wildcard-diagnostics-and-tooling`.

---

## 6. Query cost: the 40-second character list (8 Nov)

| Time | Step | Commit |
|---|---|---|
| 00:43 | Theory: with 1,250 bots every login, save and logout goes through one character-database connection, so a player's character list waits behind them. More connections set. | 0cce098 |
| 01:11 to 01:15 | General MySQL tuning: 4 GB buffer pool, 1 GB redo log, flush rate, IO capacity | 61a5be9, a55aaea, da2a3fd |
| 08:31 | Symptom still there. Temporary slow-query log over 1 s, as `sql/enchants/091-slow-query-log.sql`; header: "Delete this file once the cause is found" | cc145e5 (PR #82) |
| 13:56 | Cause found and fixed with an index | 257158e (PR #84) |
| 14:22 | Temporary log removed; "40 s to under 1 s" | ea01588 (PR #86) |

**Mechanism** (comment on `EnsureCharacterSpellIndexes`, `patch-night/PatchNight.ps1`): the core "deletes a
spell from every character" (`DELETE FROM character_spell / character_talent WHERE spell = ?`) whenever it is
asked to teach a spell that does not exist. CoA teaches every character its hidden Reset Talents spell
(14009999) at each login. The Wildcard world database lacks that spell. So every login, bots included, scanned
all of about 1.7 million learned-spell rows and held locks for seconds.

**Cost reasoning.** Without an index on `spell`, each delete reads every row: cost = rows x logins. With over a
thousand bots logging in after a start, that is over a thousand full scans of 1.7 million rows, each holding
locks a player's character list must wait for. With an index the delete is a lookup that finds nothing. The
mechanism is also consistent with the negative: the wait was still 40 s after connections were added and MySQL
was tuned, as it would be if the time went on scans and the locks they hold rather than on a shortage of
connections or memory.

**Fix choice.** An index is additive (no data changed), applied once and skipped afterwards, and does not need
a build. The root oddity (CoA teaching a spell the Wildcard world lacks) is upstream's; the index makes it
harmless.

**What history does not show.** `EXPLAIN` output, or the slow-log lines themselves. If you repeat this, keep the
slow-log line and the `EXPLAIN` before and after in the PR. The earlier connections change is still set and its
effect was never measured.

**Instrument lifecycle.** Temporary log: added and removed in six hours. On 21 Nov a slow-query log came back on
purpose as `095-slow-query-log.sql` at 0.5 s, described in `CHANGES.md` as "performance diagnosis, measuring
only".

---

## 7. Growth arithmetic: playerbots.conf, 240 KB to 22 MB (ba59783, 22 Nov)

**Observation.** A config file about 92 times its shipped size after 16 settings writes; one SQUID value (a
Cyrillic addon prefix in `AiPlayerbot.TradeActionExcludedPrefixes`) no longer matching.

**Shape test.** If each write appended something, 21.8 MB over 16 writes is 1.4 MB per write; the settings
script changes a few hundred short lines. So the growth multiplies.

**Mechanism.** Windows PowerShell's `Get-Content` decoded the UTF-8 file as Windows-1252; the script wrote the
text back as UTF-8. A 2-byte UTF-8 character is read as two 1252 characters, each written back as 2 or 3 bytes.
ASCII is untouched. So:

```
size after n writes = ASCII bytes + (non-ASCII bytes at start) x g^n,   g between 2 and 3
```

| g per write | g^16 | Non-ASCII bytes at the start that explain 21.8 MB |
|---|---|---|
| 2 | 65,536 | about 340 |
| 2.25 | 431,440 | about 50 |
| 2.5 | 2,328,306 | about 10 |

`python3 -I scripts/wcalc.py mojibake --start-kb 240 --end-kb 22000 --writes 16`. The simulation
(`--text "a – b {звезда}" --writes 5`) shows g rising from 1.8 to 2.2 as it goes, because the bytes that land
in 0x80 to 0x9F turn into 3-byte characters.

**Conclusion from the sum.** A handful of non-ASCII characters (the script's comment names an en dash in a
comment and a Cyrillic prefix in a value), at most 0.15% of the file, is enough. Nothing else need be wrong.

**Predictions, all checked in the commit.** (1) The garbled text is the same step applied n times, so undoing
that step n times restores it exactly: "back to 243 KB, every restored line identical to the .dist". (2) Values
containing non-ASCII no longer match what SQUID expects: the trade prefix. (3) Files with only ASCII never grew.

**Fix.** Read as UTF-8 (1252 only if the bytes are not valid UTF-8), write in the encoding read, repair garbled
lines on reading (`Repair` in `server-settings/Apply-ServerSettings.ps1`).

**General lesson.** The half-life matters more than the size: at x2 per write, the last write alone added
about half the file. A file that doubles per run is days from filling a disk even when it looks small.

---

## 8. Overflow and units: the launcher at 46 GB (99f4fa7, PR #73, 8 Nov)

**Observation.** Progress maths failing on the real install.

**The sum.** 46 GB = 49,392,123,904 bytes. Signed 32-bit maximum = 2,147,483,647. Ratio 23.

**Mechanism.** `[Math]::Max(1, $script:checkTotal)` and two similar lines in `launcher/WildcardLauncher.ps1`.
With the integer literal `1`, PowerShell bound the call to `Math.Max(int, int)`, and the byte total did not
fit. The fix writes `[Math]::Max([double] 1, [double] $script:checkTotal)` and casts the numerator.

**Why testing missed it.** Any test folder under 2 GB passes. The threshold is a property of the type, so only
the sum finds it in advance: write the largest real value beside the type at every step.

**Units case, same day, same script.** The Unix time conversion: Windows PowerShell read the 'Utc' argument as
milliseconds (4168ff5).

**Where else to apply it here.** Millisecond timers (2^31 ms is 24.8 days); copper totals (2^31 copper is about
214,748 gold); row counts multiplied together; percent stored as a whole number against a fraction (Recipe 2a).

---

## 9. Layer swap

### 9a. Our build against the official build (01159e2, PR #187, 19 Nov)

Build 57 (`server-0.261119.114`) stopped at start-up: "Duplicate blank sub-command". The comparison was between two
build recipes for the same release: the official one (`Corfirean/coa-server-build`) applies
`patches/squid-coa-validation.patch` to SQUID so its own auction house bot never registers; ours took SQUID
unchanged, so two modules registered the same `.ahbot` commands. Fix: the workflow now applies the official
build's module patches, checksum-checked, at the commit the release list names. The same comparison later that day
found the response-file flag when the compiler command line grew too long (2606a77, PR #191).

Cost note: this failure appeared only at start-up, after a full build. The comparison itself (read what the
official workflow does that ours does not) costs minutes and can be done before building. See
`wildcard-build-and-env`.

### 9b. Core against ours

The whole of example 2b is a layer swap done by reading: for each enchant, does the core already have a rule,
and is ours a second one?

### 9c. Client against server

- Runes of Descension (b4f61e9, PR #200): the Wildcard window decides in the client whether you can pay, and
  counts only the 32 currency slots, while its balance line counts bags too. The symptom ("not enough" with
  plenty owned) lived entirely in the client's rule; the server fix moves runes into the currency tab (patch 82)
  and makes the item a currency (`160-rune-currency.sql`).
- Mystic Enchant gold prices (5c2a489, PR #192): the core's prices applied whenever the client config named
  none, so the client could show amounts other than those charged. The patch names all ten prices in the client
  config.
- Curse of Arugal (8cdfebf): tooltip says +20%, client data 40%. Tooltip wins.
- Racials off the global cooldown: "the client patch carries the same change" (`CHANGES.md`, patch 52).

The patch context pack lists this as a standing risk: "the client has its own copy of some rules ... a
server-only change can leave the two disagreeing."

### 9d. One setting

`SkipCinematics = 2` "to test whether the intro cinematic causes the first-login crash of new characters"
(aaf4df4, 30 Oct). The setting is still in place with the comment that the client crashes on a new character's
first login; no test result separating the two outcomes is recorded.

### 9e. A swap that went wrong

`for-083` is the branch for the old `.83` core; `main` targets later cores. Merging `main` into it replaced its
patches with the wrong core's versions and dropped a workflow fix; it was restored exactly (ebc3c3d, on
`origin/for-083`, 5 Nov). Branches for different cores are different layers. Compare them; never merge them.

---

## 10. Hot-path reading

These two readings were done for this skill on 2026-11-22. They are not historical reviews (the Fable ledger
is empty as of that date) and no cost was measured. They show the method.

### 10a. `patches/86-scrolls-of-fortune-redeem-themselves.ps1`

```
Hook:        OnPlayerUpdate(player, diff)        every tick, every player, bots included
Gate:        player timer += diff; if < 2000 return   one add, one compare
Behind gate: 16 backpack slots + each equipped bag's slots; per item one spell lookup and a token check
Database:    none on the scan path
```

| Quantity | Sum | Result |
|---|---|---|
| Gate checks | 750 bots x about 30 ticks/s | about 22,500 a second, each trivial |
| Bag scans | 750 / 2 s | 375 a second, about 12 per tick |
| Slot checks per scan | 16 + bag slots | tens to low hundreds |

Verdict a reviewer could give: cost is small against a 30 ms tick; the gate is before the scan; no query.
Question, not defect: random bots do not need scrolls redeemed, so is a bot guard worth adding? Could not
check without a build: actual time per scan.

### 10b. `patches/30-wildcard-rewards.ps1`, `RollCardDrop`

```
Hook:        per kill that can drop a card
Every call:  reads Wildcard.CardDropChancePerMille from the config (a string-keyed lookup)
Gate:        random(1000) >= chance -> return      97% of calls stop here at 30 per mille
Behind gate: reads and parses the weights string; walks the whole drop list to sort it by quality; two rolls
```

Verdict: the expensive part runs on 3% of kills. The per-call config read is the pattern the context pack
warns about ("a setting read on a hot path without caching"); per kill it is tolerable, and the same code on a
per-tick hook would be a finding. The upside of reading each time is that the comment in the settings file is
true: the value can change without a rebuild.

### 10c. Two measured cases of the same shape, outside the tick

- Settings script (d802f8c, PR #229): each of 261 settings was tested against every line of both copies of
  `worldserver.conf`: settings x lines. About 3 minutes of downtime per patch night. Indexed by name instead:
  24.6 s became 1.7 s in a side-by-side test on 266 settings across 12 files, with identical output.
- Collection addon (4fdb6a0, PR #224): every query looked up all 6,440 enchants' names and sorted them, freezing
  the game client. Names and order are now worked out once.

Both were found by counting: items x items per call, times calls.

---

## 11. Rate and economy sums

All from `server-settings/server-settings.txt` comments and the commits named.

**Fishing at 2 levels an hour (59e6bcf, 12 Nov).** A cast waits 8, 14 or 18 s for a bite (13 s on average) in
a 21 s channel; about 16 s a fish with looting and recasting. 3,600 / 16 = 225 fish an hour (the comment says
"about 220"). `Rate.XP.Profession.Fishing = 0.9`; "each 1.0 of a rate is about 1.1% of a level", so about 1% a
catch; 225 x 1% is a little over 2 levels, "still about 2 with some missed". The yardstick is in the same
comment: gathering should "keep up with Manastorm (2 levels an hour)". An earlier value of 0.82 (0.9% a catch)
was raised to leave room for missed bobbers.

`python3 -I scripts/wcalc.py rate --seconds-per-action 16 --value-per-action 0.99 --unit "% of a level"`

**World PvP kill XP: a missing multiplier found by arithmetic (59e6bcf).** Intended 6% of a level a kill. The
code called `GiveXP` without the hook that applies `Rate.XP.Global` and prestige. 6 / 2.7885 = 2.15: players
would have received 2.15%. The fix calls the hook; the setting is written as the pre-boost figure
(`WorldPvP.KillXPPercentOfLevel = 2.15`), and the comment carries the consequence: about 17 kills a level
(100 / 6 = 16.7).

**Chained rates.** Master rate: 3 x CoA's stock 0.9295 = 2.7885, "which keeps its per-source balance".
Exploring: 13.3333 x 2.7885 = 37.18 = 40 x 0.9295. Prestige: 167% of 3x = 5x. Quest XP: 1.26 x 1.5 = 1.89.

**Auction prices (3f95f33, 8 Nov).** Buyout = sell price x quality multiplier x category-quality multiplier.

| Item | Quality | Category | Product |
|---|---|---|---|
| Rare gear, recipes | 2 | 2 | 4x vendor |
| Epic gear, recipes | 2.5 | 3.2 | 8x |
| Rare bags | 2 | 15 | 30x |
| Epic bags | 2.5 | 60 | 150x |

Stated aim in the comment: rares and epics were going for about vendor price, "which made the Auction House the
easiest way to gear"; the multipliers keep dungeons and raids the better source.

**Card drops (4444b55, 8 Nov).** Before: an even pick over every card, "so epics and legendaries dropped as
often as commons". After: 3% a kill, weights 50, 28, 14, 6, 2.

| Quality | Share | Cards per 1,000 kills | One per |
|---|---|---|---|
| Common | 50% | 15 | 67 kills |
| Uncommon | 28% | 8.4 | 119 |
| Rare | 14% | 4.2 | 238 |
| Epic | 6% | 1.8 | 556 |
| Legendary | 2% | 0.6 | 1,667 |

From the code in `patches/30-wildcard-rewards.ps1`: a quality with no droppable card has its weight left out of
the total, so the other shares rise; a weights list that is not exactly the right length falls back to the old
even pick. Kills per hour is not recorded anywhere in the repo, so cards per hour cannot be stated: time a real
session first.

**Rested XP (b06519c, 12 Nov).** In an inn or city, logged out: a level every 14.4 h, so the 10-level cap fills
in 144 h = 6 days, for someone who plays one day a week. Elsewhere: a level every 28.8 h. The settings went
through three values in ten hours that day (2cd2a78, bf3e353, b06519c); only the last carries its sum.

---

# Recipes moved here from SKILL.md (full text)

## Recipe 10. Reading a diff for hot-path cost

**Use when** reviewing or writing a patch that adds a hook. INTENDED DOCTRINE (PR #232, unmerged): the change-risk matrix scores "every tick,
every packet, or for all 750 bots" as L3 = 3, and the patch context pack lists "a setting read on a hot path
without caching" and "code written for players runs for 750 bots too" among the commonest faults.

**Steps**
1. Find the hook and how often it runs: per tick per player (`OnPlayerUpdate`), per kill, per packet, per login.
2. Multiply by who it runs for. Bots are players: assume all 750 unless a guard excludes them.
3. Find the gate (a timer, a chance roll, an early return) and check the expensive work is behind it.
4. Count the work behind the gate: loop iterations, lookups, database calls. A database call per tick is a
   finding.
5. Write the cost as "N operations per second server-wide"; compare with the tick budget (Recipe 4). A cost you
   could not measure is reported as a question, not a defect (the reviewer agent's own rule).

**Worked reading (done for this skill on 2026-11-22; not a historical review, and no cost was measured).**
Patch 86 hooks `OnPlayerUpdate`: every tick, every player and bot. Its gate is a per-player timer: under
2,000 ms it adds and returns. Every 2 s it scans the 16 backpack slots and each bag, one spell lookup per item,
no database call. For 750 bots that is 375 scans a second, about a dozen per tick at 30 ticks a second.
Finding: cheap, gate in the right place. Question for the author: would a bot guard be free insurance? Patch
30's `RollCardDrop` runs per kill: it reads the chance setting every call, and only the 3% that pass parse the
weights and sort the drop list. The expensive part is behind the gate; the per-call config read is tolerable
per kill and would be a finding per tick. Two measured cases of the same shape outside the tick: the settings
script (261 settings x every config line; 24.6 s became 1.7 s, d802f8c) and the collection addon (all 6,440
enchants per query, 4fdb6a0).

## Recipe 11. Rate and economy sums

**Use when** setting a drop chance, an XP rate, a price or a reward interval.

**Steps**
1. Write the player's loop in seconds per action, from real timings.
2. Value per hour = 3,600 / seconds per action x value per action x success rate (`wcalc.py rate`, `drops`).
3. Compare with other ways to earn the same thing (the settings use Manastorm at 2 levels an hour).
4. For chained multipliers, write the whole chain and check the product against the intended figure.
5. Put the sum in the comment above the setting in `server-settings/server-settings.txt`: the house style, and
   the reason these numbers can be re-derived today.

**Worked examples.** Fishing: about 16 s a fish, so 3,600 / 16 = 225 an hour; at about 1% of a level a catch
that is about 2 levels an hour (59e6bcf). World PvP: the kill XP call skipped the hook that applies the realm's
boosts, found by arithmetic: 6% intended / 2.7885 = 2.15% actually paid (59e6bcf). Auction prices: rare gear
2 x 2 = 4x vendor, epic 2.5 x 3.2 = 8x, bags 30x and 150x (3f95f33). Card drops: 30 per mille is 3% a kill;
weights 50/28/14/6/2 give one legendary card per 1,667 kills (4444b55). Cards per hour needs kills per hour,
which the repo does not record: measure it before quoting one.

