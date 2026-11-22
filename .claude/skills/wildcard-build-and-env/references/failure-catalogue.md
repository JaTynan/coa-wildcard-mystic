# Build failure catalogue and tag history

Read this when a build has failed, when you are about to start one and want to know what has
gone wrong before, or when someone asks why a release has so many builds.

Source: commit messages and tags in this repository, as of 2026-11-22. The Actions run list
could not be read while writing this, so log text is quoted only where a commit message quotes
it. Everything else is paraphrased from the commit.

## How to read a failed run

1. Find the red step: `gh run view <run id> --repo JaTynan/coa-wildcard-mystic`.
2. Get its log: `gh run view <run id> --repo JaTynan/coa-wildcard-mystic --log-failed`.
3. Search the log for the texts in the next table. The last 30 lines are usually enough,
   except for compile errors, where you search for `error C`, `error LNK` or `ninja: fatal`.
4. Match it to a past failure below. If it is new, add a row when it is fixed.

## Error text by step

These strings are in the workflow or the patch scripts today, so they are what the log prints.

| Step | Text to search for | Means | Who fixes |
|---|---|---|---|
| Look up the release's exact commits | `is not in the manager's list. Recent ones:` | Typed release tag is wrong or too old for the lists | Retype the tag |
| same | `lists no core commit` (or bots, scaling, squid) | Upstream list entry is incomplete | Wait or ask upstream |
| same | `The build recipe needs checking` | A part now comes from a different repository | James. The workflow must follow upstream (hard stop 5) |
| same | `has no checksum`, `lists module patches but no build repository commit` | Upstream list entry is inconsistent | Same |
| Build only releases not built before | `is already built; nothing to do.` | Not an error. Tick `rebuild` | Whoever started it |
| Apply our patches | `no longer fits release` | A `patches/*.patch` file does not apply to this core | `wildcard-patch-authoring` |
| Apply the official build's module patches | `checksum ... differs from the release's` | The patch file in `coa-server-build` is not the one the release lists | Do not bypass. Report upstream, tell James |
| same | `does not apply to` | Upstream's own patch does not fit upstream's own module commit | Same |
| Apply our patch scripts | `changed:` after a line `== NN-name.ps1` | An anchor was not found exactly once. The line above names the script, the message names the part and file | `wildcard-patch-authoring` |
| same | `A racial patch did not run before this one` | Script order problem | `wildcard-patch-authoring` |
| same | `failed.` with a script name | The script ended with an error that was not a throw | Read the lines above it |
| Install Boost 1.87 and the MySQL 8.4 client | `Boost download attempt`, `got an HTML page instead of the installer`, `MySQL download looks wrong.` | A download site failed. Three attempts are made for Boost | Run again later |
| same | `No OpenSSL development install found on the runner.` | GitHub's Windows image changed | James (workflow change) |
| Configure | `CMake configure failed.` | A dependency was not found, or a module's CMake file is broken | Read CMake's own error above |
| Build worldserver | `error C` followed by four digits | Compiler error in the named file | Fix the patch that inserted the code |
| same | `error LNK` | Linker error: something declared but never defined, or defined twice | Same |
| same | `ninja: fatal:` | The build tool itself failed | See failure 5 |
| Check it starts and reports its revision | `worldserver --version exited with` | The program does not load | Read the output above |
| Publish as a release | `Publishing the release failed.` | GitHub refused the release (permissions, tag exists) | James |

## Every recorded build failure

Phase is where in the run it appeared, from step order. "After the build" means the build
passed and the failure appeared on the VM.

| # | Date | Phase | Symptom | Cause | Fix | Would have been caught by |
|---|---|---|---|---|---|---|
| 1 | 5 Nov | Build worldserver | The build failed on one call in mod-ollama-chat, `IsHeadless` | The module was written for stock AzerothCore. On the CoA core that function is called `IsBot` | A build step replacing the call (`d05134f`, PR #42; `fb60c6c` on `for-083`). Now part of `patches/10-mod-ollama-chat-fit.ps1` | A syntax-only compile of the new module against the pinned core |
| 2 | 12 Nov | Build worldserver | Failed in `AscensionPrestigiousCache.cpp`: `ChatCommandTable` and `Console` not known | The types live in the namespace `Acore::ChatCommands` (`ChatCommand.h`) and the inserted code used them bare | Qualified names and the include added in `patches/49-prestigious-legendary.ps1` (`0220a49`) | A syntax-only compile with any compiler |
| 3 | 16 Nov | Build worldserver | The Windows build failed on a constant named `SYNCHRONIZE` | `SYNCHRONIZE` is a macro in the Windows headers, so the Microsoft compiler replaced the name. Linux compilers do not have it | Renamed to `SYNCHRONIZE_SPELL` in `patches/mystic-enchants-scripts.patch` (`a4048e7`, PR #176; `2ccbf80`, PR #177) | Only a Windows compile. A Linux syntax check passes this |
| 4 | 19 Nov | After the build | Build 57, the first for `.114`, built and published, then stopped while starting: "Duplicate blank sub-command" | SQUID 3.0 brought its own auction house bot with the same `.ahbot` commands as the core's `mod-ah-bot-plus`. The official build patches SQUID so that bot never registers. Ours took SQUID unchanged | The resolver now outputs the official module patches and the workflow verifies and applies them. Dungeon Clear added at the same time (`01159e2`, PR #187) | Starting the world once before publishing. Nothing in CI does that. Reading the resolver output for new parts in a new release |
| 5 | 19 Nov | Build worldserver, at step 1,288 of 3,197 | "ninja: fatal: CreateProcess: The parameter is incorrect (is the command line too long?)" | The first build with Dungeon Clear. Its include folders pushed the compiler's command line past the Windows limit | `-DCMAKE_NINJA_FORCE_RESPONSE_FILE=ON`, as the official build does (`2606a77`, PR #191) | Comparing our CMake flags with the official build's when a module is added |
| 6 | 21 Nov | Build worldserver | An include line was ignored (warning C4067), then `DcSelfFoundPlanner` was undeclared | The text `patches/90-dungeon-clear-auto-start.ps1` inserted had no final line break, so the last added `#include` ran into the module's next line | One line break added (`e0cc2f5`, PR #210) | A local check that inserts the script's exact text. The local check that was run had added the line break itself and passed |

One fix arrived before its failure. On 15 Nov `c4b6718` (PR #163) changed
`patches/60-manaforged-barrier.ps1` to accept both the current and the next core's version of
`Unit::CanDefendDuringChannel/Cast`, because "patch 60's anchors would throw on Tuesday's
release". That is the model for the loop after a release: read the next core, fix first.

One port is recorded as a planned event, not a failure: `f83171d` (PR #29, 1 Nov) rebuilt the
patch files on the `.90` core and folded the skip-missing patch into
`mystic-enchants-wildcard.patch`.

### What the six have in common

- Five of six appeared in or after the compile step. None was a failed anchor. The recorded
  history therefore argues for a compile check before pushing even more than for an anchor
  check. (Anchor failures may have happened without a commit message saying so. The run list
  would show them.)
- Two came from adding a third-party module (1 and 5) and one from an upstream recipe change
  (4). A new module or a new upstream release is the moment to compare with the official
  build, `server-binaries.yml` in `Corfirean/coa-server-build` by the wording of `2606a77`.
- Two came from the difference between the check that was run and the real build (3 and 6).

### Other workflow changes that were not failures

| Date | Commit | Change |
|---|---|---|
| 30 Oct | `446ae0a` | Workflow added. Build 1 |
| 30 Oct | `bc0110d` | Daily schedule, the `check` job and "build each release once" |
| 31 Oct | `2f786cc` (PR #16) | `actions/checkout@v7`, `actions/cache@v6`, because v4 ran on a Node.js version GitHub was retiring |
| 1 Nov | `f83171d` (PR #29) | Resolver reads the build repository's list first |
| 5 Nov | `07eba5f` (PR #40) | mod-ollama-chat added to the build, pinned |
| 9 Nov | `1e52bc7` | Ten inline patch steps moved into `patches/*.ps1`, run by one step |

## Tag history

Regenerate from the repository root with
`python3 -I .claude/skills/wildcard-build-and-env/scripts/which_build.py`. The date is the date of the repository commit that was built.

| Manager release | Builds | Run numbers | Commit dates |
|---|---|---|---|
| `server-0.261028.83` | 5 | 1, 8, 11, 15, 20 | 30 Oct to 8 Nov |
| `server-0.261029.85` | 2 | 2, 6 | 31 Oct |
| `server-0.261030.90` | 1 | 7 | 1 Nov |
| `server-0.261101.92` | 1 | 9 | 1 Nov |
| `server-0.261104.94` | 1 | 16 | 5 Nov |
| `server-0.261108.95` | 22 | 21, 22, 24, 25, 27, 29, 30, 33, 34, 35, 36, 38, 39, 41, 42, 43, 45, 46, 47, 50, 51, 53 | 8 Nov to 18 Nov |
| `server-0.261115.110` | 1 | 44 | 15 Nov |
| `server-0.261116.112` | 2 | 52, 55 | 17 and 19 Nov |
| `server-0.261119.114` | 5 | 57, 61, 62, 68, 70 | 19 to 21 Nov |

40 builds were published from 70 workflow runs. The 30 run numbers with no release are 3, 4,
5, 10, 12, 13, 14, 17, 18, 19, 23, 26, 28, 31, 32, 37, 40, 48, 49, 54, 56, 58, 59, 60, 63,
64, 65, 66, 67 and 69. Tags cannot say which of those failed. A run number is also used by
every daily run that found the release already built, and the schedule ran on about 23 days in
this period. UNVERIFIED split. To settle it:
`gh run list --repo JaTynan/coa-wildcard-mystic --workflow build-worldserver.yml --limit 100`.

### What the pattern shows

**`.83`, five builds over nine days.** The server's release at the time. Rebuilt by hand as
changes landed: build 11 added the SpellAffect SQL patch (`411b435`), build 15 the
mod-ollama-chat fix (`fb60c6c`), build 20 came from the `for-083` branch (`4252e55`) and is the
only tag not on `main`.

**`.85`, `.90`, `.92`, `.94`, `.110`, one or two each.** Built by the schedule as each became
the newest release. The server did not stay on them, so nobody asked for rebuilds.

**`.95`, 22 builds in ten days.** None of the 22 is a port to a new core. They are feature
work. In those ten days `main` took the patch script restructure,
the racial passives, the legendary and epic Mystic Enchant batches (84 commits touched `patches/*.patch` between 15 and 18 Nov) and several server features. Each merge that changed
C++ needed a manual run with `rebuild` ticked, one to three a day, because the schedule will
not rebuild an existing release. Builds 45 to 51 and 53 were for `.95` although `.110` had been
built, so the server stayed on `.95` while newer releases existed, and main's patches fitted
both. Two of the six recorded failures (2 and 3) fall in this stretch.

**`.112`, two builds.** Build 52 is its first build (17 Nov), build 55 a rebuild from a later
commit (19 Nov).

**`.114`, five builds in three days.** Two different things overlap here. First the port:
build 57 published and would not start (failure 4), and the next attempt stopped on the
command line limit (failure 5). Build 61 is the commit that fixed that (`2606a77`). Then
feature work carried on at the same pace as on `.95`: build 62 is a gold cost change merged
late on 19 Nov, a new patch script merged on 21 Nov broke the build (failure 6, patch 90),
and builds 68 and 70 followed its fix. Ten of the fifteen run numbers from 56 to 70 produced
no release. Some of those are daily runs that found nothing to do. The rest are failures.

The cost this points at: one failure is reported per run, and a run that gets as far as
compiling takes hours. The two port fixes were small (apply a module patch, add one CMake
flag) and the feature fix was one line break. Each still cost at least one full attempt.
