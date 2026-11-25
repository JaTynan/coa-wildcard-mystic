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

The last four measure the change itself: they read the value before learning the talent and check the difference
after, so they do not depend on the exact base numbers in our data. Each also checks one similar spell that must not
change.

The format is the core's scenario schema 1. Each file says in `contract` what it expects, from the tooltip and our
fix, independent of how the fix is written.

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
