# Gameplay scenarios (automated in-game tests)

These files are tests for our own fixes, written for the gameplay test runner that is already built into the CoA
core (`src/server/coa/CoAGameplayTest.cpp`, off by default). The runner starts a real worldserver with no network
clients, creates throwaway characters, plays out each scenario's steps (learn a spell, equip an item, cast at a
target dummy, wait) and checks its assertions (an aura is on, a cooldown is this long, a spell hit this target).
It is the only way our fixes can become "verified" without someone testing them by hand.

Status, 25 Nov 2026: **written and checked for structure only; not run yet.** Nothing here runs a server, and no
script, patch night step or workflow calls these files. Where and when they run is still to be decided (below).

## What is here

| Scenario | Checks | From |
|---|---|---|
| `wcme-rapid-killing-cooldown` | Rapid Killing rank 1 makes Rapid Fire's cooldown 210 sec | sql 148, PR #271 (live) |
| `wcme-temple-guardian-inner-fire` | Temple Guardian's block bonus comes and goes with Inner Fire | sql 148, PR #271 (live) |
| `wcme-twisted-mind-penalty` | Twisted Mind's healing penalty comes and goes with the form | sql 148, PR #271 (live) |
| `wcme-single-minded-fury-follow-up` | two one-handers keep the companion on; Mortal Strike is followed by its off-hand twin | PR #275 |
| `wcme-spider-bomb-factory` | the factory is built, a bomb leaves it and its explosion hits the target | PR #276 |

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

## Open decision (James)

Where and when to run. Options, cheapest first:

1. **On demand on the VM**, by one command, while nobody is playing. No change to patch night.
2. **Inside patch night**, after the new build is installed and before the server starts again. Fully automatic,
   but it adds to the nightly downtime and changes patch night (hard stop 5).
3. **Elsewhere** (GitHub Actions, another machine): needs the client data there, which must not go into this
   public repository.
