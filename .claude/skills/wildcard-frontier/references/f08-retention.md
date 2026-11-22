# F8. Goal D: retention features chosen by evidence

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Classify every step with `wildcard-change-control` first.

## 1. Goal and owner

Build the next player-experience feature because there is a reason to think it will keep friends playing, and be
able to tell afterwards whether it did. Owner: James, goal D.

## 2. Where the project stands (2026-11-22)

Built and live (each has a row in `CHANGES.md` or a block in `server-settings.txt`):

| Feature | What it gives | Where |
|---|---|---|
| Rotating weekly event | One theme a week at triple rates (PvP, professions, quests, dungeons), Friday to Thursday, shown on the website | `patches/45-weekend-bonus.ps1`, `91-weekly-event-mystic-scrolls.ps1`; settings `WeekendBonus.*` |
| Play-time rewards | A sealed card pack for every hour played, sometimes a Case of Fortune | `patches/46-play-time-rewards.ps1`; `PlayTimeRewards.*` |
| Leaderboards and server firsts | Website boards: level, Prestige, Manastorm depth, kills, world PvP kills, firsts | `patches/47-leaderboards.ps1`; `signup/WildcardStatus.py` |
| Rested XP for weekend players | Up to 10 levels of rested XP, filling in 6 days in an inn | `server-settings.txt`, "Rested XP (weekend players)" |
| Race kits | One signature passive for each of the ten races | patches 54 to 59, 72 to 76; `docs/race-kits.md` |
| Profession Mastery | Past skill 300: gathering up to 3x, crafted bonus rolls up to 2x | `patches/51-profession-mastery.ps1` |
| Group XP not split; dungeons that scale up | Playing together is not a loss | `patches/93-group-xp.ps1`, `95-dungeons-scale-up.ps1` |
| Bonus stats on gear, battleground spoils, legendary choice at Prestige | Loot that stays interesting | patches 48, 40, 49 |
| Bots to play with, Dungeon Clear auto start | A full world with a few people in it | patches 20, 90; SQUID's bots |

Planned (`docs/roadmap.md`): level cap 70 (item 7), profession bonuses (8), new races (9, planning only),
pick-one-of-three (10, "nice to have"), the Death Knight set (2 to 4).

What does not exist: any measure of whether friends keep playing. No weekly count of who logged in, no hours, no
before-and-after for any feature above. The website shows who is online now and the boards; neither is kept over
time.

## 3. Why the current approach falls short

- **Features are chosen by taste and by what was fun to build.** That has worked so far, but the roadmap's next
  items are large (level cap 70 touches rolls, prestige, items, vendors and scaling), and nothing says which one
  the friends would feel.
- **No feature has ever been judged afterwards.** The weekly events, play-time rewards and rested XP all aim at
  "come back next week"; nobody knows if they do that.
- **The sample is a handful of adults with jobs.** Percentages and significance tests mean nothing here. A measure
  has to be readable as plain counts, and the honest method is closer to a case study than to statistics.
- **The cheapest evidence is not collected:** nobody has asked the friends.

## 4. This project's asset

- **The characters database already holds what a small server needs.** Stock columns in `characters`
  (pinned core, `data/sql/base/db_characters/characters.sql`): `level`, `totaltime` (seconds played),
  `leveltime`, `logout_time`, `online`, `creation_date`. The core also has `account_coa_daily_login`
  (`last_claim_at`, `claim_number`).
- **Real players are already separable from bots** (F7 part 2).
- **Everything has a switch and a date.** A weekly event theme, a reward rate or a racial can be turned on or off
  for a known week, which is the only experiment a server this small can run.
- **The friends are reachable.** James knows every player. Asking five people three questions is real evidence.
- **The website already has a status service** that could show a "this week" line if James wants it public.

## 5. First three steps in this repo

### Step 1. Three plain numbers, once a week (the same script as F7 step 1)

`scripts/weekly_numbers.py` (to be written; does not exist as of 2026-11-22) writes, for real players only, into a file that stays on the VM:

| Number | How | Why this one |
|---|---|---|
| **Active players this week** | Accounts with at least one character whose `totaltime` grew since last week's file | The headline. A count, not a rate |
| **Hours played per active player** | Sum of `totaltime` growth per account; give the list, lowest to highest, without names | Shows whether it is one keen player or everyone |
| **Came back** | Of the accounts active last week, how many are active this week, written "4 of 5" | Retention in the only form the sample allows |

Also store: new accounts this week, characters created, highest level and Prestige reached, and the week's event
theme (so weeks can be compared by theme). No percentages. No averages across fewer than five people.

- The first file only starts the clock: every number needs last week's file.
- **Class estimate:** not LOW by default (admin database login, account data: hard stop 4 and possibly 1; expect
  HIGH, James merges); see F7 step 1 for the scheduled task and the privacy rule.

### Step 2. A decision note before each large feature

- Add `docs/decisions/` with a one-page template: the feature; which of the three numbers it should move and
  roughly how ("two more friends reach 60 and keep playing past it"); what would count as "did not help"; when to
  look (four weeks after it goes live); what it costs to build and to undo.
- Fill it in first for whichever roadmap item James wants next. Fill the "what happened" section four weeks after.
- **Class estimate:** LOW (documentation).

### Step 3. Ask the friends, three questions, twice a year

- A short form linked from the website (or simply a message from James): what they did most last month, what made
  them stop a session, the one thing they would add. Keep answers off the public repository; record only the
  summary in the decision notes.
- If it becomes a page on the sign-up service, that file reads secrets: hard stop 4, HIGH, James merges. A plain
  message needs no change at all, and is the recommended first version.

## 6. Milestone

**You have a result when** eight weekly lines of the same three numbers exist (56 days), **and** one roadmap item
was chosen with a written decision note that named the number it should move, **and** four weeks after it went
live the note's "what happened" section is filled in with those numbers, whichever way they went.

It is falsified, usefully, if the eight lines show the numbers do not move with anything the project ships (for
example, activity follows school holidays and nothing else). Then the honest conclusion is that features are for
fun rather than retention, and step 3's answers become the main guide.

## 7. Known wrong paths and risks

- **Dashboards.** Three numbers in a text file are enough for five players.
- **Treating one friend's busy month as a feature's failure.** Look at who, not only how many; James knows why.
- **Rewards for time online** raising hours without anyone enjoying it more. Play-time rewards already exist;
  hours alone cannot say whether they work. That is what "came back" and the three questions are for.
- **Publishing who played how much.** The leaderboards are public by James's choice; a play-time list is not.
- **Building several features in the same four weeks** and then trying to tell them apart.
- **Using bots' numbers.** Bots are always active.
- **Changing the level cap as an experiment.** It cannot be cleanly undone once characters pass 60 (impact check
  I3 = 3). Decide it from the note and the friends' answers, not from a trial.
- **Anything that gives gold, items, currency, XP or reputation outside normal play** is hard stop 2. Most
  retention rewards are exactly that: they always wait for James.

## 8. Dependencies

Shares its script with F7. Needs F4 passing (lag drives people away more than any feature brings them back, and
would swamp every number). Level cap 70 and new races should also wait for F2, because they are hard to undo.
