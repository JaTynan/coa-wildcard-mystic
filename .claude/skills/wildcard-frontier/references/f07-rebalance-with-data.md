# F7. Goal C: re-balancing Wildcard and Mystic Enchants with data

Everything under "First three steps", "Milestone", "Wrong paths" and the cost template is a **Proposed practice (not yet adopted by James)**. Facts were checked on 2026-11-22. Table definitions come from the pinned core's SQL files;
**whether each table holds useful rows on the live server was not checked**. Classify every step with
`wildcard-change-control` first.

## 1. Goal and owner

Tune abilities and enchants from what players actually pick, use and achieve, and review the roughly 2,000
Wildcard abilities at a cost James can afford. Owner: James, goal C.

## 2. Where the project stands (2026-11-22)

- **Stage 3 is NOT BUILT YET**: the weekly data pack, the monthly Fable balance review, the ability pass and the
  ability arbiter are rows in `docs/agents/README.md` and nothing else.
- Balance changes so far were made by judgement, one at a time, with the reasoning in the PR (examples: the
  group XP factors in patch 93, battleground dampening in `130-battleground-dampening.sql`, the race kits' numbers
  in `docs/race-kits.md`).
- `docs/race-kits.md` records the scale of the problem: on this server enchants already give effects like +100%
  critical damage for little investment.
- The budget rule for the expensive model: a starting split of 30% of Fable usage for balance; every ruling
  becomes a precedent so the same question is never paid for twice (`docs/agents/README.md`).
- James's own figure for the ability review: about 2,000 abilities, and about 10,000 agent calls if done one at a
  time, which he cannot afford. The 2,000 is his estimate; **UNVERIFIED** here (count the pool for
  `Wildcard.AbilityPool = "classic"` from the client data to confirm).

What data exists, and what does not:

| Question | Where it could come from today | State |
|---|---|---|
| Which enchants do real players have in their slots? | `coa_mystic_enchant_slot (guid, preset, slot, spell)` and `coa_mystic_enchant_known (guid, spell)` in the characters database | Table defined by the core (`rev_20261005_01_coa_mystic_enchants.sql`); contents not checked |
| Which abilities and talents did a Hero end up with? | `character_spell`, `character_talent` | Stock tables; about 1.7 million rows including bots (comment in `PatchNight.ps1`, `EnsureCharacterSpellIndexes`) |
| Levelling speed | `characters.level`, `totaltime`, `leveltime`; needs a weekly snapshot to turn totals into rates | Columns exist; no snapshot |
| Prestige, Manastorm depth, PvP kills, server firsts | `character_settings` (source `core.coa_prestige`), `character_manastorm_progress`, `wcme_world_pvp_kills`, `wcme_server_firsts` | Already queried for the website (`signup/WildcardStatus.py`, `_leaderboards`) |
| Gold and auction prices | `characters.money`, `auctionhouse` | Stock tables. The auction house bot fills most listings, so prices mostly show its settings |
| Dungeon and boss kills | `log_encounter` | Stock table; whether it is being written is not checked |
| Battlegrounds | `pvpstats_battlegrounds`, `pvpstats_players` | Stock tables; not checked |
| How often an ability or enchant is **used** | Nowhere | **Missing** |
| Damage and healing per ability or per build | Nowhere on the server. A client's combat log has it for that client only | **Missing** |
| Deaths, time to kill, where players give up | Nowhere | **Missing** |

Real players can be told from bots the way the leaderboards do it: the account name does not start with the bot
prefix (`AiPlayerbot.RandomBotAccountPrefix`), and names in `Leaderboards.HiddenCharacters` are left out.

## 3. Why the current approach falls short

- **No numbers at all reach a reviewer.** A monthly review with nothing to review is opinion.
- **Pick data is reachable, use data is not.** What a player owns says little: Wildcard abilities are rolled, not
  chosen. Use and outcome are what balance needs, and the server records neither.
- **The player base is a few friends.** Any rate has a tiny sample. One player's holiday moves every number.
- **Bots are 750 of the population** and pick by their own rules. Mixed in, they drown the signal; on their own,
  they say what bots do, not what is strong.
- **One ability at a time does not fit the budget**, and without written precedents two reviews of similar
  abilities will disagree.
- **Many enchants do not work yet** (F6), so their pick and use rates describe bugs, not balance.

## 4. This project's asset

- **The data is already in MySQL on the VM**, and patch night already runs read-only queries with the admin
  client (`function Sql` in `PatchNight.ps1`; `_sql` in `WildcardStatus.py`).
- **A filter for real players already exists** and is in use on the public leaderboards.
- **Every balance number is a setting or a table row** applied at the next restart and dated in git, so a
  before/after comparison has a clean boundary.
- **The conflict rule and the case-file format** (`docs/agents/case-file-template.md`, with a "Rule for next
  time" line) are the skeleton of a rulebook of precedents.
- **Spell data groups abilities by type** (damage, area damage, heal, and so on), which is exactly what batching
  needs: similar abilities are judged against each other.
- **The combat log addon** (`addon/WildcardCombatLogFix`) keeps damage meters working on this crowded realm, so a
  willing friend's meter is a usable (if small) source of use and damage numbers.

## 5. First three steps in this repo

### Step 1. The weekly numbers file (shared with F8)

- Create `scripts/weekly_numbers.py` (to be written; does not exist as of 2026-11-22) (Python, standard library, **read-only SQL** through the server's own
  `mysql.exe` and admin login, the way `WildcardStatus.py` does). Once a week it writes one JSON file on the VM
  with, for real players only: count of characters by level band; hours played this week per character (difference
  in `totaltime` from last week's file); levels gained; enchants in slots (count per enchant spell); prestige and
  Manastorm depth; dungeon boss kills if `log_encounter` has rows.
- **The file stays on the VM.** This repository is public: per-player data, even with names removed, is not
  committed. Only the script is.
- First PR: the script and a `--dry` mode printing the queries. Second PR: a scheduled task.
- **Class estimate:** not LOW by default. The script uses the admin database login (a secrets file) and reads
  account data to tell players from bots: hard stop 4, and possibly 1, may apply. Let the analyst decide; expect
  HIGH, James merges. (Still add a row limit and a timeout so it cannot load the database.) A new scheduled task
  on the VM is James's call. The data file stays on the VM.

### Step 2. The rulebook and a 50-ability pilot

- Create `docs/agents/context/ability-rules.md`: the conflict rule, the comparison classes (damage against damage,
  area against area, heal against heal), and an empty "precedents" list.
- Pick 50 abilities of **one** type. Run the ability pass on them in batches (see the cost template in the appendix), by hand
  trigger. Record: calls made, how many abilities were flagged as outliers, how many rulings became rules.
- Output is a list for James, not changes. Nothing is applied.
- **Class estimate:** files under `docs/agents/` are hard stop 6: HIGH, James merges. No server change.

### Step 3. The first monthly review, from four weekly files

- After four weekly files exist: a case file (the template) holding the four weeks' numbers and the open
  questions, one Fable call, a ranked list of at most five proposed changes each with its evidence and the number
  it expects to move. A ledger line in `docs/agents/fable-ledger.md`.
- **Class estimate:** the case file is documentation under `docs/agents/` (hard stop 6). Each proposed change is
  classified on its own; any that shifts power between players scores impact check I4 at 2 or 3.

## 6. Milestone

**You have a result when** four weekly files in a row exist with the same fields (28 days), **and** one balance
change proposed from them is merged, **and** the number it named moved in the direction it predicted in the two
files after it went live.

For the ability review: **you have a result when** the 50-ability pilot is done for **at most 12 agent calls** and
its outlier rate is known, so the cost of the remaining abilities can be stated before it is spent.

It is falsified if the weekly numbers swing more from week to week than any change could move them (the sample is
too small to steer by: fall back to case-by-case judgement and say so), or if the pilot needs more than 25 calls
for 50 abilities (batching is not working; fix the batch design before going on).

## 7. Known wrong paths and risks

- **Tuning from one week.** With a few players, wait for four.
- **Letting bots into the averages**, or tuning for bots.
- **Reading auction prices as demand.** The bot sets them.
- **A C++ hook that counts every cast.** It runs for every cast by 750 bots (likelihood check L3 = 3) while lag is
  the top problem. Not before F4 passes and James agrees.
- **Publishing player data** in a public repository or on the site beyond the leaderboards James already chose.
- **Balancing enchants that are still broken** (F6).
- **Many small "fair" nerfs.** Friends notice lost power more than gained balance; each one needs I4 scored.
- **A review with no prediction.** A change that does not say which number should move cannot be judged later.
- **Spending the Fable budget on gathering.** The rule is that Fable never gathers its own context.

## 8. Dependencies

Shares step 1 with F8. Needs F6 far enough along that enchant data means something, and F4 passing so lag is not
shaping play. Feeds F8 (did the change keep people playing?) and uses F2 for safe deployment of each change.

## Appendix: cost template for the ability review (fill in; no prices are given on purpose)

| Symbol | Meaning | Fill in from |
|---|---|---|
| N | Abilities to review | Count from the client data (James's estimate: about 2,000) |
| B | Abilities per batch call | Pilot. Start at 10 of the same type |
| f | Share flagged for the arbiter | Pilot |
| r | Share of flags that an existing precedent already answers | Grows as the rulebook fills; 0 at the start |
| P_pass, P_arb | Price of one pass call and one arbiter call | Current price list, at the size of the batch |
| k | Calls per ability when done one at a time | James's figure implies about 5 |

- One at a time: `N x k` calls. With N = 2,000 and k = 5 that is 10,000.
- Batched: pass calls = `N / B`; arbiter calls = `N x f x (1 - r)`.
- Example with made-up shares, to show the shape only: N = 2,000, B = 10, f = 10%, r = 50% gives 200 pass calls
  and 100 arbiter calls: 300 calls against 10,000.
- Cost = `(N / B) x P_pass + N x f x (1 - r) x P_arb`. The rulebook is sent with every pass call, so keep it
  short (it is paid for every time) and stable (so it can be cached where the tooling allows).
- Order the types so the most uniform come first: precedents made early are reused most.
- Stop rule: if `f` rises above twice the pilot's rate for a type, stop and fix the rules for that type first.
