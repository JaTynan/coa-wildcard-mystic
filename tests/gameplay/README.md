# Gameplay scenarios (automated in-game tests)

These files are tests for our own fixes, written for the gameplay test runner that is already built into the CoA
core (`src/server/coa/CoAGameplayTest.cpp`, off by default). The runner starts a real worldserver with no network
clients, creates throwaway characters, plays out each scenario's steps (learn a spell, equip an item, cast at a
target dummy, wait) and checks its assertions (an aura is on, a cooldown is this long, a spell hit this target).
It is the only way our fixes can become "verified" without someone testing them by hand.

Status, 25 Nov 2026: **written and checked for structure only; not run yet.** PR #278 (open) runs them every night
on the scheduled patch night, in a throwaway test world server, before the live world starts (James chose this on
25 Nov: no players are expected from 3:30 to 5:30 am). Until #278 and this folder are both on `main`, nothing runs.

## What is here

| Scenario | Checks | From |
|---|---|---|
| `wcme-rapid-killing-cooldown` | Rapid Killing rank 1 makes Rapid Fire's cooldown 210 sec | sql 148, PR #271 (live) |
| `wcme-temple-guardian-inner-fire` | Temple Guardian's block bonus comes and goes with Inner Fire | sql 148, PR #271 (live) |
| `wcme-twisted-mind-penalty` | Twisted Mind's healing penalty comes and goes with the form | sql 148, PR #271 (live) |
| `wcme-single-minded-fury-follow-up` | two one-handers keep the companion on; Mortal Strike is followed by its off-hand twin | PR #275 |
| `wcme-spider-bomb-factory` | the factory is built, a bomb leaves it and its explosion hits the target | PR #276 |
| `wcme-empowering-frostbolt-cast-time` | rank 3 makes Frostbolt 300 ms faster; Fireball unchanged | sql 151, PR #273 (live) |
| `wcme-rising-flames-fire-nova` | rank 2 adds 20% to Fire Nova damage; Lightning Bolt unchanged | sql 151, PR #273 (live) |
| `wcme-sinister-calling-gloomblade` | rank 3 makes the Gloomblade buff 3 sec longer; Slice and Dice unchanged | sql 151, PR #273 (live) |
| `wcme-improved-blood-presence-damage` | rank 5 adds 8 to Blood Presence's damage bonus; Frost Presence unchanged | sql 151, PR #273 (live) |
| `wcme-fiery-payback-low-health` | the below-35% half starts off at full health, switches on below 35% (Pyroblast 3.5 sec faster, 5 sec longer cooldown) and off again | sql 152, PR #274 |
| `wcme-fanaticism-execution-sentence` | Crusader Strike and Judgement of Light +20% against a target with your Execution Sentence; Exorcism and no debuff unchanged | sql 152, PR #274 |
| `wcme-authority-shield-of-righteousness` | Shield of Righteousness turns 3 Authority stacks on the target into 3 stacks of damage reduction | sql 149, PR #272 |
| `wcme-improved-blood-presence-heal-scope` | the capstone heal share is 5 in Blood Presence and held at 2 in Frost Presence | sql 152, PR #274 |
| `wcme-improved-kick-energy` | a Kick that interrupts a hostile mage's Frostbolt gives 40 energy | sql 152, PR #274 |
| `wcme-corrupted-bear-paw` | over 20 sec of bear melee, Corrupted Paw deals 20-30% of the melee damage | sql 147, PR #270 |
| `wcme-fierce-block-multiplier` | 800 Fierce Blows without and 800 with Righteous Fury: blocked about 1.6 times as often (bounds 1.35-1.9) | sql 153, PRs #275 and #279 |

The four `sql 151` rows measure the change itself: they read the value before learning the talent and check the difference
after, so they do not depend on the exact base numbers in our data. Each also checks one similar spell that must not
change.

The format is the core's scenario schema 1. Each file says in `contract` what it expects, from the tooltip and our
fix, independent of how the fix is written.

The seven fight tests (25 Nov 2026) set up a real situation: a hostile creature or player, a debuff placed by the
right caster, health dropped below a threshold. Each starts with `SETUP:` checks (the companion is linked, the cast
went through, enough strikes landed), so a broken fixture fails as a setup problem, not as a false verdict on the
fix. Only Fierce Block is statistical; its scenario file is written by `tools/fierce_block_scenario.py`. Not covered
yet: Explosive Charge's splash (needs a hunter with a ranged weapon and ammunition), Fiery Payback's disarm chance,
Beacon of Virtue, Holy Concentration, Pack Leader, Flare Strike and Bloodletting.

## Check the files without a server

The core's runner can validate a scenario's structure. From a core checkout at the pinned commit:

```sh
python3 apps/coa-gameplay-test/run.py validate /path/to/coa-wildcard-mystic/tests/gameplay/scenarios/<file>.json
```

All five passed this on 25 Nov 2026 (core c3f2fd4). Validation does not prove a scenario will pass, or that it
tests the right thing: only a run does.

## What a run needs

From the core's own guide (`apps/coa-gameplay-test/README.md`, `docs/coa/verification.md`):

- a worldserver built with our patches (every release build is one), its config, and the client data folder;
- a MySQL 8 server with `mysql` and `mysqldump`; the runner copies the world database for each run, so the copy
  must be the Wildcard world database with our SQL applied (patch night already applies it);
- Python 3.11 or later, and the runner scripts from a core checkout at the release's pinned commit;
- memory: the core measured up to about 5 GB per test worldserver.

The VM has the first two. The world copy and the test server's memory are why a run should not overlap with play.

## Where and when they run

Decided by James on 25 Nov 2026: inside the scheduled patch night, after the new build and tonight's SQL are in
place and before the live world starts (PR #278, `patch-night/Run-GameplayTests.ps1`). The results go to
`patch-night.log` and `gameplay-tests\latest.txt` on the VM. A by-hand run of the same script works too, while the
live world is stopped.
