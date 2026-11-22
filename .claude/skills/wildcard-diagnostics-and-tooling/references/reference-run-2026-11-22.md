# Reference run: the real logs of 22 November 2026

Read this when you need a known example of what each script finds on the real server's files, or one day to
compare a later day against.

**Aggregates only; no raw log dumps.** This file holds summary tables, conclusions and a few format lines per
tool. The log files themselves are not in this repository and must not be added (public repository).

**What this is.** On 2026-11-22 at 16:33 Sydney time a read-only copy of the game VM's `Core\Logs` folder was
taken (`Timing.log`, `perf\perf-2026-11-22_0903.csv`, `perf\counters.txt`, `mysql-slow.log`,
`console-history.txt`, `Errors.log`, `squidbot\runs.jsonl`). Every script in `../scripts/` was run against the
copy with Python 3.13 on Linux. `LOGS` below stands for the folder the copy was in. Re-run on 2026-11-22 after
`perf_csv_summary.py` gained its "worldserver CPU (lowest in window)" row.

**What it is not.** One server start (08:53-08:56), one day, one real player (online from 14:36), 750 bots
configured, core `c3f2fd4b2395` patched. That start predates the merges of #229, #230 and #231, so none of them
was live. These are observations. None is a root cause, and none is a threshold. With nobody online the bots are
**logged out** (`AiPlayerbot.DisabledWithoutRealPlayer = 1`), so every "nobody online" figure below describes an
**empty world**, not idle bots. Hypotheses about the lag spikes are tested in `wildcard-lag-spike-campaign`
(root cause UNKNOWN on 2026-11-22). `patch-night.log` was not in the copy, so `patch_night_summary.py` has no
reference run yet.

## 1. Timing.log

```
python3 -I -B timing_summary.py LOGS/Timing.log --spike-ms 1000 --top 10 --split "2026-11-22 14:36"
```

First lines of the output (format sample):

```
Lines read: 2286; timing records: 458; start banners: 0; other lines skipped: 0; records missing one or more of their five lines: 1; records whose lines arrived out of order (read correctly): 101; ...
Typical gap between records: 60 s.
WARNING: low coverage. A record describes only its last N passes (N x mean seconds: typically 2 s here) but records are 60 s apart; 456 of 457 records cover under half their gap.
Spikes: 77 of 457 records (16.8%) had max >= 1000 ms.
```

**Counting rule.** 458 blocks, one of them cut off at the end of the file (16:33:10: the copy was taken while
the server was writing). So: **457 complete records; 117 with a player online; 77 with a pass of 1 s or more;
22 with 2 s or more; none with nobody online (worst 534 ms); worst 5,397 ms at 14:49.** The campaign's
`spike_gates.py` gives the same figures.

Per hour (from the script's table):

| Hour | Records | Players | Mean pass | Passes/s | Window p95, median | Worst pass | Covered |
|---|---|---|---|---|---|---|---|
| 09:00-13:59 (each hour) | 60 | 0 | 4.0-4.3 ms | 233-248 | 12 ms | 45-93 ms | 3-4% |
| 14:00 | 60 | 0, then 1 from 14:36 | 18.9 ms | 53 | 15 ms | 5,397 ms | 16% |
| 15:00 | 60 | 1 | 50.0 ms | 20 | 94 ms | 2,896 ms | 42% |
| 16:00 (to 16:32) | 34 | 1 | 47.9 ms | 21 | 96 ms | 1,824 ms | 40% |

What to take from it:

- **Nobody online (08:56 to 14:35, 340 records): an empty world.** Mean pass about 4 ms (median 2 ms), about
  240 passes a second. Window p95 12-15 ms. One record in 340 has a pass over 100 ms (534 ms at 14:00:02).
- **One player online (14:36 to 16:32, 117 records):** mean pass 47 ms (21 passes a second); the window p95 has
  a median of 94 ms; 77 records (66%) contain a pass of 1,000 ms or more, 22 one of 2,000 ms or more. The ten
  largest are all between 14:38 and 14:56, while the bots were logging in.
- **"covered" is 39% with a player on.** Each record sees only its last 500 passes, about 25 s of each minute.
  Spikes in the other 60% are not in the file, so the true count is at least what is shown, and "66% of
  minutes" is a property of the sampling, not a rate.
- **The before/after table is NOT a valid comparison of a change**: "before" is an empty world, "after" has a
  player and 750 bots. The script says so in its last line.
- 101 records had their five lines out of order; the parser read them.

## 2. Windows counters

```
python3 -I -B perf_csv_summary.py LOGS/perf
python3 -I -B perf_csv_summary.py LOGS/perf --timing LOGS/Timing.log --spike-ms 1000 --min-players 1 --detail 3
```

Whole day, 5,379 rows, 10 logical processors (`docs/performance.md` says 8 vCPUs; that line is stale):

| Counter | Median | p95 | Max |
|---|---|---|---|
| CPU, all cores | 20.5% | 29.9% | 52.0% |
| Processor queue | 0 | 0 | 4 |
| Free memory | 8,556 MB | - | lowest 5,128 MB |
| Disk write latency | 0.14 ms | 0.19 ms | 0.61 ms |
| Disk read latency | 0.00 ms | 0.75 ms | 124 ms (11:26, nobody on; 7.9 ms at most with the player on) |
| worldserver CPU (100 = one core) | 155% | 234% | 260% (lowest 104%) |
| worldserver memory | 4.27 GB | 6.55 GB | 6.61 GB |
| mysqld CPU (100 = one core) | 1% | 7% | 111% |

- The world server uses about 1.5 cores with the world empty (median 149% between 12:00 and 13:00) and about 2.3
  with one player on (median 225% between 15:00 and 16:00).
- World server memory follows the bots: 4.2 GB with the world empty, 6.5 GB with the bots in. The script's
  "memory went from ... to ..." line compares the first and last row only; read the table row.

**Which counter moved in the spike windows** (77 spike windows against 40 quiet ones, all with the player on;
"share" = spike windows beyond the quiet windows' 95th percentile, or below the 5th for "lowest" rows; about 5%
is chance):

| Counter | Quiet median | Spike median | Spike worst | Share |
|---|---|---|---|---|
| CPU, busiest single core | 46.6% | 57.7% | 100.0% | 48% |
| worldserver CPU (lowest in window) | 211% | 194% | 104% | 48% |
| mysqld CPU | 7% | 11% | 111% | 21% |
| Disk idle (lowest in window) | 95.8% | 95.7% | 87.2% | 18% |
| Context switches /s | 11,633 | 11,762 | 25,131 | 13% |
| CPU, all cores | 30.1% | 30.0% | 52.0% | 12% |
| worldserver CPU (highest in window) | 237% | 236% | 256% | 6% |
| Disk read latency, paging, free memory, disk write latency, disk queue | - | - | - | 3-5% |
| Processor queue, page file, worldserver memory | - | - | - | 0% |

- **Two counters moved most, together: the busiest single logical processor went up and the world server's
  process total went down** (48% each). That is the picture of one thread working while the others wait. It
  does not show which thread or what work: a row every 5 s is too coarse.
- **mysqld CPU (21%) and disk idle (18%) moved less, but about four times chance: not ruled out.** The mysqld
  movement is in the bot-login minutes: mysqld reached 72-111% of a core every 40 s from 14:37 to 14:47 and
  never passed 33% afterwards (`wildcard-lag-spike-campaign`, evidence A14).
- Paging, processor queue, memory and disk write latency did not move.
- Without `--min-players 1` almost every counter "moves" (the same run printed 88% for the busiest core, 56%
  for MySQL's CPU), because quiet windows then come mostly from the empty-world hours. That is the trap the
  option exists for.

## 3. Slow queries

```
python3 -I -B slow_query_summary.py LOGS/mysql-slow.log --utc-offset-hours 11 --by-hour --top 6
```

| Hour (Sydney) | Statements over 0.5 s | Total | Slowest |
|---|---|---|---|
| 08:00 | 14 | 24.2 s | 4.73 s |
| 09:00 | 15 | 11.9 s | 1.06 s |
| 10:00 | 4 | 3.5 s | 0.88 s |
| 11:00-16:33 | 0 | - | - |

- 33 statements all day, 39.6 s in total, the slowest 4.7 s. All between 08:53 and 10:32 local. By kind: whole
  tables read while the world loads (the two largest, 573,271 rows each, and one scan of 4.7 million rows),
  patch night's own helper queries, and bursts of respawn and item saves in the first 90 minutes.
- **None from 10:33 on**, so none during 14:36-16:32. A single slow statement is therefore not what those
  spikes were. Many fast statements one after another would not appear in this log, and during the login ramp
  mysqld was busy (section 2): that is not ruled out.
- One shape is worth a look in its own right: a one-row delete from the creature respawn table taking
  0.5-0.9 s, seven times. A one-row delete that slow is waiting on something (a lock or a flush), not searching.
  No conclusion drawn here.

## 4. Console history

```
python3 -I -B timing_summary.py LOGS/console-history.txt --ignore-above-ms 60000 --max-starts 0 --spike-ms 1000 --top 0
```

2,522 lines: 2,143 slow-pass lines, 239 start banners; 8 lines carry absurd values and were left out.

| Core revision (`+` = patched build) | Starts | Lines | Median | p95 | Largest |
|---|---|---|---|---|---|
| `9c31f851ee9c` | 1 | 5 | 107 ms | 430 ms | 504 ms |
| `90ec1e0a2e58` | 6 | 69 | 172 ms | 1,012 ms | 4,587 ms |
| `a76415e00eba` | 4 | 5 | 135 ms | 162 ms | 163 ms |
| `a76415e00eba+` | 35 | 580 | 246 ms | 971 ms | 29,789 ms |
| `85ecc2122efd+` | 19 | 1,202 | 289 ms | 682 ms | 2,970 ms |
| `c3f2fd4b2395` | 2 | 9 | 123 ms | 2,173 ms | 2,655 ms |
| `c3f2fd4b2395+` | 5 | 265 | 758 ms | 2,131 ms | 4,486 ms |

- Read `formats.md` section 4 before quoting this table. These are slow passes only (over 100 ms, sampled every
  5 minutes), without timestamps, across changing bot counts and settings. ("Starts" here counts starts that
  logged at least one slow pass.)
- What it supports: passes of 1-4 s were already being caught on the October revisions, so multi-second passes
  are older than the 19 Nov core update.
- What it does not support: any claim that one revision is faster or slower than another.
- **This file cannot be rebuilt. Never delete it** (`formats.md` section 4).

## 5. Errors.log

```
python3 -I -B errors_log_groups.py LOGS/Errors.log --top 10
```

38,273 lines, 223 kinds, one server start, no timestamps. The ten commonest kinds (9,580 down to 1,065 lines
each) are all data checks made while the world loads: unsupported-race rows in the character-creation tables,
achievement criteria without data, spawn masks, item class and material checks, missing creature models, and
the enchant proc script bound to spells whose data does not match what it expects (home for that one:
`ascension-restoration`). They are the standing background of this server: use `--baseline OLDER_COPY` to see
what is new rather than reading the list.

## 6. Dungeon runs against spike minutes (one-off check, no script shipped)

`squidbot\runs.jsonl` shows the player in two Dungeon Clear runs that afternoon (14:37-14:59 and 15:22-16:10).
Player-online records with a pass of 1,000 ms or more, by the record's timestamp: 45 of 69 during a run (65%),
32 of 48 outside one (67%). On this one afternoon, being in a dungeon run made no difference.

## Figures to reuse (22 Nov 2026, one player, 750 bots configured)

| Measure | Nobody online (empty world, bots logged out) | One player online |
|---|---|---|
| Complete records | 340 | 117 |
| Mean pass | 4.2 ms | 47 ms |
| Passes per second (1000 / mean) | 237 | 21 |
| Window p95, median across records | 12 ms | 94 ms |
| Records with a pass >= 1,000 ms | 0 | 77 (66%) |
| Records with a pass >= 2,000 ms | 0 | 22 (19%) |
| Worst pass | 534 ms | 5,397 ms |
| Share of each minute the records cover | 4% | 39% |
