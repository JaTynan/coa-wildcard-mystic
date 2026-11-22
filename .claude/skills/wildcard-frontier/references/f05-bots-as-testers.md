# F5. Bots and the console as testers

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22 against the repository and the pinned upstream sources (core `c3f2fd4b`, SQUID
bots `4ef5ed9e`). **Nothing here was tried on the live server.** Where feasibility is unknown it says so.
Classify every step with `wildcard-change-control` first.

## 1. Goal and owner

Check that an enchant or talent does what it should without James doing every check by hand in game.
Owner: the pipeline; it serves goal B, whose real limit is testing (F6).

## 2. Where the project stands (2026-11-22)

- **Testing is by hand.** A GM character targets itself and types `.aura <enchant spell>`, `.list auras`,
  `.learn`, `.lookup spell id`, then plays and watches (`docs/enchant-restoration.md`, "Testing in game").
- `enchants/test-checklist.csv` has 561 rows with the commands and the expected result; 35 have a result.
  The two quickest kinds are `twin` (139 rows, 137 waiting) and `teach` (148 rows, 120 waiting): each is "put the
  enchant on, then look for one aura or one spell".
- The patched server makes `.aura` on an enchant also teach its spell, as the altar does (comment in
  `patches/mystic-enchants-wildcard.patch`), so `.aura` is a fair stand-in for the scroll for these kinds.
- There are **no** automated functional tests of any kind.

What the upstream sources allow (read, not run):

| Question | Answer | Source |
|---|---|---|
| Can the server console (used by patch night through `ra-once`) run `.aura`, `.unaura`, `.cast`, `.damage`, `.list auras`? | **No.** All are marked `Console::No`: they need a logged-in GM with a target | core `src/server/scripts/Commands/cs_misc.cpp`, `cs_cast.cpp`, `cs_list.cpp` |
| What useful commands can the console run? | `player learn <name> <spell>` and `player unlearn` (the player must be online), `additem`, `revive`, `saveall`, `pinfo`, `kick`, `combatstop`, `reload ...`, `server info` | core `cs_player.cpp`, `cs_misc.cpp`, `cs_reload.cpp` |
| After `saveall`, does the database show a passive aura (which is what an enchant is)? | **No.** Passive auras are not saved (`Aura::CanBeSaved` returns false for them) | core `src/server/game/Spells/Auras/SpellAuras.cpp` |
| Can a bot be told to cast a spell? | Yes, by chat: SQUID's bots handle `cast <spell>` ("cast custom spell"), `attack`, `stats` and more from their master | SQUID `src/Ai/Base/Strategy/ChatCommandHandlerStrategy.cpp`, `ChatTriggerContext.h` |
| Will any bot obey? | Not once patch 96 is installed: random bots that are not yours will ignore whispered bot commands, while your own bots and alts still answer. **Patch 96 is merged (21 Nov, 13a03d3, #228) but in no build as of 2026-11-22**, so until a build with it is installed random bots still answer | `CHANGES.md` row for `96-bots-ignore-commands.ps1` |
| Is there a client that can log in without a person? | Not in this repository, and none was found upstream. **Feasibility unknown** | search of both source trees |
| Does the core have unit tests? | Yes: target `unit_tests` (googletest), off by default (`BUILD_TESTING`), about 120 files under `src/test`, including data-driven spell proc tests | core `src/test/CMakeLists.txt`, `src/test/server/game/Spells/` |
| Does the server say anything checkable at start? | Yes: counts of action rows, enchants left out of rolls, extra taught spells, worldforged enchants | F2 part 4 |

## 3. Why the current approach falls short

- **The observation channel is missing.** The console can change a logged-in character (teach a spell) but cannot
  *read* what auras it has, and the database does not store passive auras. So "apply, then assert" cannot be done
  from outside the game with what exists.
- **Bots can act but cannot report.** A bot can be told to cast; nothing records "the proc fired 3 times in 20
  casts" anywhere a script can read. The combat log exists only inside a game client.
- **So every check needs a person in a client**, and there are 526 checklist rows waiting plus about 1,500 fixed
  enchants with no test note (F6).

## 4. This project's asset

- **A checklist that is already machine-readable**: file, spell, test type, commands, expected aura or spell.
- **`.aura` teaches as the altar does**, so the `twin` and `teach` kinds reduce to "is aura X on me" and "do I
  know spell Y", both of which a client addon can ask (`UnitAura`, the spellbook).
- **The project already ships addons** and a launcher that installs them, and James has a GM account.
- **35 checklist rows already have a hand result** (28 of them `teach`, 2 `twin`): a ready answer key to check
  any automatic method against.
- **750 bots fight all day** with random builds. If the server ever logs errors per spell, they are free coverage
  for "does it crash", though not for "is it right".

## 5. First three steps in this repo

### Step 1. Check what the server says at start against what the repo expects

- Create `scripts/check_start_counts.py` (to be written; does not exist as of 2026-11-22) (Python, read-only): from `sql/enchants/*.sql` work out the numbers the
  start-up lines should show (for example the count of `wcme_enchant_action` rows), read a `Server.log`, and print
  expected against actual. This catches "the SQL did not apply" and "a fix silently fell out" with no game client.
- It proves data arrived, not behaviour. Say so in its output.
- **Class estimate:** LOW (a read-only script). Wiring it into patch night is F2 step 1 and hard stop 5.

### Step 2. A self-test addon for the two quick kinds, on James's client only

- Create `tools/selftest-addon/WildcardSelfTest/` (**not** under `addon/`: everything in `addon/` is copied to
  every player by patch night, see `FetchRepo`). A slash command reads a list generated from the checklist; for
  each row it sends the GM command `.aura <spell>` as chat, waits, looks for the expected twin aura (`UnitAura`
  gives the spell id on this client version; **UNVERIFIED**, check on one row) or the expected taught spell, sends
  `.unaura`, and stores pass or fail with the date in its saved variables file.
- Create `scripts/import_selftest.py` (to be written; does not exist as of 2026-11-22): turns that saved file into `result` entries in the checklist and `tested`
  notes in the tracker, each marked `auto` with the build tag, so hand tests and automatic ones stay distinct.
- First run: the checklist rows that already have a hand result (28 `teach`, 2 `twin`). The method is usable only
  if it agrees with them.
- **Class estimate:** it issues GM commands, so treat it as hard stop 1: **HIGH, James merges**, and it must never
  ship to players. No server change.
- Limits to state: an addon on this client cannot cast spells by itself (casting needs a key press), so this
  covers "the aura or spell is there", not "the proc fires".

### Step 3. Two one-day spikes to settle the unknowns (each ends with a written yes or no)

- **Spike A, unit test:** can one of our C++ handlers be tested in the core's `unit_tests` target? Candidate:
  the chain jump multiplier of `patches/71-jump-multiplier-points.ps1` (pure arithmetic). Needs F1 step 2 (a local
  build tree) to be affordable. Outcome: a test that fails without the patch and passes with it, or a note saying
  why not (for example the code needs a live database).
- **Spike B, bot as actor:** with James's own bot in his party at a training dummy, the enchant on the bot,
  `cast <spell>` whispered 20 times, and the self-test addon counting the bot's proc from the combat log events
  James's client sees. Outcome: does the count match the tooltip's chance within reason, yes or no.
- **Class estimate:** A is a build experiment, nothing merged: no class until it produces a patch. B uses existing
  commands in game: no change to classify.
- A third option, a new console command that prints a player's auras, would close the observation gap for good.
  It is a GM/console command: **hard stop 1**. Do not start it; put it to James as a decision.

## 6. Milestone

**You have a result when** 20 `twin` or `teach` enchants are checked by the addon in **under 10 minutes** of
James's time, and its verdicts agree with existing hand results on **at least 19 of 20**; and then the 257 waiting
rows of those two kinds are cleared within **7 days**.

It is falsified if agreement is below 19 of 20 (the addon cannot see what a person sees; find out which part), or
if the client refuses GM commands sent by an addon.

## 7. Known wrong paths and risks

- **"A bot will test it."** A bot can act; nothing can read the result. Settle spike B before building on it.
- **Driving `.aura` from the console.** Not allowed by the core, as the table shows.
- **Reading `character_aura` after a save.** Passive auras are not there.
- **Counting "the row exists" as "tested".** Step 1 proves data, step 2 proves presence, only a fight proves
  behaviour. Record which level each note is.
- **Shipping the self-test addon to everyone** by putting it in `addon/`.
- **Marking automatic results as hand tests.** Keep the `auto` mark; James's rule is that each fix records how it
  was tested.
- **Statistics on procs from 20 casts.** A 10% proc shows 0 to 5 times in 20. Use enough casts or call it a smoke
  check.
- **A headless client.** Unknown feasibility, likely large, and automating logins touches hard stop 1.

## 8. Dependencies

Step 1 feeds F2's health check. Spike A needs F1 step 2. F6's throughput depends on step 2. A decision by James is
needed before any new command.
