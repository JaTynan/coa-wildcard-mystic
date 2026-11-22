# Chronicle: builds and core updates

Everything that went wrong (or was fought over) in building the patched world server and in following CoA's
releases. Facts come from commit messages, file comments and release tags in this repository, as of 2026-11-22.
Nothing here was re-checked on the VM.

Reading aid:

- **Release `.NN`** is the last part of a CF-Server-Manager release tag (`server-0.261119.114` is "release .114").
- **Build N** is one of this repository's releases, tagged `wcme-server-<release>-buildN`
  (`git tag -l 'wcme-server-*'`).
- A build runs on GitHub Actions for 2 to 3 hours, so every entry below that ends in "the build stopped" cost that
  long before the cause was visible.
- Every entry has the same seven fields. "Tried and rejected" says "none recorded" when history shows only the fix.

## Which release was built when (from the tags)

| Release | Builds tagged | Tag dates | What history says about it |
|---|---|---|---|
| .83 | 1, 8, 11, 15, 20 | 30 Oct to 8 Nov | The server's core until the move to .95. Build 11 "is installed" on 3 Nov (`50f5ba5`). From 5 Nov built from branch `for-083`. |
| .85 | 2, 6 | 31 Oct | Built; no record of an install. |
| .90 | 7 | 1 Nov | `main`'s patches were rebuilt for it (`f83171d`, PR #29). No record of an install. |
| .92 | 9 | 1 Nov | Built; no record of an install. |
| .94 | 16 | 5 Nov | Built; no record of an install. |
| .95 | 21 to 53 (22 builds) | 8 to 18 Nov | The server's core from about 8 to 10 Nov (`2a033cd`, 10 Nov, speaks of "the .95 update") until 19 Nov. |
| .110 | 44 | 15 Nov | Built from the PR #163 merge. No record of an install. |
| .112 | 52, 55 | 17 and 19 Nov | Built; no record of an install. |
| .114 | 57, 61, 62, 68, 70 | 19 to 21 Nov | Build 57 did not start (B-13). "The 19 Nov core update" in `patch-night/PatchNight.ps1:173`. |

"No record of an install" means exactly that: the install log lives on the VM
(`C:\Games\CoA Server\patch-night\patch-night.log`), not in the repository. The enchant history files record
install dates for some builds (see `references/enchants-and-spells.md`, "Install dates on record").

---

## B-01 · 2026-10-31 · Workflow actions on a retiring Node.js version

- **Symptom:** GitHub warned that `actions/checkout@v4` runs on Node.js 20, which it is retiring.
- **Root cause:** old action versions in `.github/workflows/build-worldserver.yml`.
- **Evidence:** `2f786cc`, PR #16.
- **Tried and rejected:** none recorded.
- **Status:** fixed (checkout v7, cache v6, "the versions the CF-Server-Manager's own build uses").
- **Lesson:** when the workflow's plumbing needs a version, copy the one the official build uses.

## B-02 · 2026-11-01 · Patches no longer fit after release .90

- **Symptom:** the patches written for .83/.85 had to be rebuilt for core `8b6bbd8` (release .90).
- **Root cause:** the core changed under them (taught spells became a list in the core, among other things).
- **Evidence:** `f83171d`, PR #29. `mystic-enchants-skip-missing.patch` was folded into
  `mystic-enchants-wildcard.patch` because both touch the same files.
- **Tried and rejected:** none recorded.
- **Status:** fixed for .90. Side effect: `main` now carried .90 patches while the server ran .83, which created
  the `for-083` branch (B-04).
- **Lesson:** two patches that edit the same file belong in one patch.

## B-03 · 2026-11-01 · The release list lagged a release behind

- **Symptom:** the build could not see the newest release.
- **Root cause:** `scripts/resolve_release.py` read only the manager's `server-history.json`, which "can lag a
  release behind" the build repository's own list.
- **Evidence:** `f83171d`, PR #29; `scripts/resolve_release.py` (`HISTORIES`).
- **Tried and rejected:** none recorded.
- **Status:** fixed. It reads `Corfirean/coa-server-build` `changelog/history.json` first, then the manager's.
- **Lesson:** the build repository is the first source for "what is the newest release".

## B-04 · 2026-11-05 · `main` and `for-083` merged into each other, then undone

- **Symptom:** after 5 Nov's merges, branch `for-083` (the build branch for the server's .83 core) had lost its
  .83 patches and the mod-ollama-chat fix in its workflow.
- **Root cause:** `main` was merged into `for-083` (`3a64277`). `main`'s patches are for the .90 core, and the
  merge replaced `for-083`'s versions with them. PR #41 then merged `for-083` into `main` (`2faddef`).
- **Evidence:**
  - `ebc3c3d` "Undo merging main into for-083: main's patches are for the .90 core", which restores the branch
    "exactly as it was at fb60c6c". Verified: `git diff fb60c6c ebc3c3d` is empty.
  - PR #41 changed nothing in `main`'s files. Verified: `git diff dab1e15 2faddef` is empty (it only joined the
    histories).
  - `fb1c58a`, PR #43: README gained the Branches section: "**Never merge it into `main` or `main` into it**;
    close any pull request between the two."
- **Tried and rejected:** keeping one branch for both cores (the merge) was the thing rejected.
- **Status:** fixed by the undo, then retired. After the undo every server change that needed a build was made
  twice, once per branch, as paired pull requests on 8 Nov: #89/#90 (free training), #92/#93 (bots by team),
  #103/#104 (Mercenaries), #106/#107 (scrolls to currency), #108 and then #112 (bots raise the dead). The last
  `for-083` commit is 9 Nov (`869bd0f`); the last .83 build is build 20 (8 Nov). The branch still exists.
- **Lesson:** a branch that builds for a different core is not a feature branch. Never merge it either way. The
  rule is written in README.md and repeated in `docs/agents/context/patches.md`.

## B-05 · 2026-11-05 · mod-ollama-chat did not compile on the CoA core

- **Symptom:** "The 5 Nov build failed" on one call.
- **Root cause:** the module calls `IsHeadless`; on this core the same thing is `IsBot`. "Every other call the
  module makes exists in the .83 core or SQUID."
- **Evidence:** `fb60c6c` (on `for-083`) and `d05134f` (on `main`, PR #42); today `patches/10-mod-ollama-chat-fit.ps1`.
- **Tried and rejected:** none recorded.
- **Status:** fixed.
- **Lesson:** a third-party AzerothCore module needs a fit patch for CoA; compile it against the pinned core
  before a build.

## B-06 · 2026-11-09 · Inline workflow patch steps moved into numbered scripts

- **Symptom:** not a failure. The workflow held ten inline patch steps (the commit removes about 300 lines from the workflow file).
- **Root cause:** every new server change had been added as another inline step.
- **Evidence:** `1e52bc7`, PR #112: "The ten inline patch steps move unchanged into five grouped scripts (bots,
  Wildcard rewards, battlegrounds, Manastorm, AI chat fit), run in name order by one step." `CHANGES.md` was
  created in the same commit to list every customisation.
- **Tried and rejected:** inline steps.
- **Status:** adopted. As of 2026-11-22 `patches/` holds 56 numbered scripts (`10-` to `96-`) and five `*.patch`
  files.
- **Lesson:** one script per change, run in name order, each with a row in `CHANGES.md`.

## B-07 · 2026-11-10 · Release .95 reset the level cap to 80 and blocked prestige

- **Symptom:** nobody could prestige at level 60.
- **Root cause:** "The .95 update put MaxPlayerLevel back to the core default of 80, and prestige follows the
  level cap."
- **Evidence:** `2a033cd`, PR #114; `server-settings/server-settings.txt` (comment above `MaxPlayerLevel = 60`).
- **Tried and rejected:** none recorded.
- **Status:** fixed by setting it in `server-settings.txt`, so it survives updates.
- **Lesson:** a value you rely on must be in `server-settings.txt` even when it equals today's default. A core
  update can change the default.

## B-08 · 2026-11-12 · `.legendary` command did not compile

- **Symptom:** "The build failed in AscensionPrestigiousCache.cpp."
- **Root cause:** `ChatCommandTable` and `Console` live in the namespace `Acore::ChatCommands` and were used
  unqualified.
- **Evidence:** `0220a49` (reached `main` with PR #129).
- **Tried and rejected:** none recorded.
- **Status:** fixed.
- **Lesson:** new C++ in a patch script must be compiled against the pinned core before the build.

## B-09 · 2026-11-15 · A patch prepared for the next core's changed function

- **Symptom:** none yet. Patch 60's anchors "would throw on Tuesday's release".
- **Root cause:** "Upstream cores since mid-November pass the attacker to
  `Unit::CanDefendDuringChannel/Cast`, and their block checks go through them."
- **Evidence:** `c4b6718`, PR #163. Build 44 for release .110 is tagged at this merge.
- **Tried and rejected:** none recorded.
- **Status:** fixed ahead of time: "The patch now finds either signature."
- **Lesson:** an anchor (the exact text a patch script looks for) can be written to accept both the old and the
  new core. Check upstream before its release reaches the manager.

## B-10 · 2026-11-16 · `SYNCHRONIZE` is a Windows header macro

- **Symptom:** the Windows build failed in the enchant scripts.
- **Root cause:** a constant named `SYNCHRONIZE` (Steward of Eternity) clashes with a macro in the Windows
  headers. Local compile checks were not on Windows.
- **Evidence:** `a4048e7`, PR #176; `2ccbf80` (same rename on the next branch).
- **Tried and rejected:** none recorded.
- **Status:** fixed (renamed `SYNCHRONIZE_SPELL`). Since then batches are "compile-checked against the core
  release the build uses (also with the Windows header macros defined)" (`enchants/epic-notes-header.md`, Process).
- **Lesson:** a compile check that is not on Windows must define the Windows macros, or it proves nothing about
  the real build.

## B-11 · 2026-11-17 · Our Iron Guard patch would have doubled the core's

- **Symptom:** none live. Review found patch 69 overlapped the release core.
- **Root cause:** "the release core already applies Iron Guard to melee and ranged blocks, so the old patch would
  have doubled it."
- **Evidence:** `f70bb96`, PR #178; `CHANGES.md` row for `69-iron-guard-block.ps1`.
- **Tried and rejected:** the full patch.
- **Status:** fixed: patch 69 "now only covers blocked spells".
- **Lesson:** before patching the core for an enchant, search the core for that enchant. See E-13 in
  `references/enchants-and-spells.md` for the wider review.

## B-12 · 2026-11-19 · Release .114: patch night started Wildcard on the wrong databases

Filed under patch night: see P-11 in `references/patch-night-and-settings.md`.

## B-13 · 2026-11-19 · Build 57 (release .114) stopped at start-up: "Duplicate blank sub-command"

- **Symptom:** build 57 was published and the world server stopped at start-up with that message (how it was
  installed, and whether patch night fell back to the official server, is not recorded).
- **Root cause:** "SQUID 3.0 has its own auction house bot with `.ahbot update, reload, empty and help`, the same
  commands as the core's mod-ah-bot-plus. The official build patches SQUID (`patches/squid-coa-validation.patch`
  in `Corfirean/coa-server-build`) so its auction house bot never registers; we took SQUID unchanged."
- **Evidence:** `01159e2`, PR #187; `.github/workflows/build-worldserver.yml:154-155` (comment).
- **Tried and rejected:** none recorded.
- **Status:** fixed. The release list "now gives each module patch with its checksum and the build repository
  commit that holds it"; `resolve_release.py` outputs them and the workflow checks each checksum and applies it.
  mod-dungeon-clear joined the build the same way.
- **Lesson:** the official build is more than a list of commits. It also applies its own patches to the modules.
  Build what it builds, patches included.

## B-14 · 2026-11-19 · First build with mod-dungeon-clear stopped at 1288/3197

- **Symptom:** run 44517406631 ended with "ninja: fatal: CreateProcess: The parameter is incorrect (is the
  command line too long?)".
- **Root cause:** "The module's include folders pushed cl.exe's command line past the Windows limit."
- **Evidence:** `2606a77`, PR #191; `.github/workflows/build-worldserver.yml:255-256` (comment).
- **Tried and rejected:** none recorded.
- **Status:** fixed with `-DCMAKE_NINJA_FORCE_RESPONSE_FILE=ON`, which the official build already passed.
- **Lesson:** copy the official build's CMake flags as well as its sources.

## B-15 · 2026-11-19 to 22 · Core behaviour found changed, or different from what we assumed

Each is small. All were found in the three days after release .114 arrived.

| Date | What changed under us | Evidence | Status |
|---|---|---|---|
| 19 Nov | `Scripts\manage.py` writes the default databases into `worldserver.conf` at every start (P-11) | `d5412a9`, PR #186 | fixed |
| 19 Nov | The core's Manastorm XP rate is 30% of full | `02f4be3` | setting written, but not on `main` (see U-03 in `references/unmerged-and-abandoned.md`) |
| 20 Nov | "The core removed [the Wondrous Wisdomball] from every vendor for a questline that doesn't exist" | `486f9c3`, PR #201 | fixed by SQL (`161-wisdomball-tiraxis.sql`) |
| 21 Nov | The pets page asked for `creature.id1`; "this core's world database calls it `id`" | `2563565`, PR #215 | fixed (this one is our assumption, not an update: recorded here because it is a core-version trap) |
| 22 Nov | 49 options "CoA core updates added" were running on defaults unnoticed | `6223bc8`, PR #230 | four set on purpose; the settings check now lists new options (`ba59783`) |

Only the first row names release .114 in its commit message. The others are listed by date, without claiming which
release brought the change.

## B-16 · 2026-11-21 · Patch 90: a missing line break hid an include

- **Symptom:** the build failed with `DcSelfFoundPlanner` undeclared.
- **Root cause:** "the here-string had no final newline, so the last added include ran into the module's next
  line (`#include "TestRun/DcSelfFoundPlanner.h"`), which MSVC then ignored (C4067)."
- **Evidence:** `e0cc2f5`, PR #210.
- **Tried and rejected:** the local check that passed: "My local check had added the newline itself; it now
  reproduces the here-string exactly and compiles clean."
- **Status:** fixed.
- **Lesson:** a local check must run the patch script's real output, byte for byte. A check that "helps" the
  input passes things the build will fail.

---

## Patterns across these entries

| Pattern | Entries | What history shows |
|---|---|---|
| Found only in the 2 to 3 hour build | B-05, B-08, B-10, B-14, B-16 | Three would have been caught by a local compile on any machine; the Windows macro (B-10) and the command-line limit (B-14) need Windows. |
| Found only after the install | B-07, B-13, B-15, P-11 | A core release changed a default, a command, a script or a column. |
| "Do what the official build does" | B-01, B-03, B-13, B-14 | Four separate fixes were "copy Corfirean's build". |
| Our patch duplicates newer core code | B-11, E-13 | The core gained its own handling in early November; ours then ran twice. |

Roadmap item 1 (`docs/roadmap.md`) is the planned answer to the build wait: build on the Windows VM and only
recompile what changed. As of 2026-11-22 nothing in the repository builds on the VM: **NOT BUILT YET**.
