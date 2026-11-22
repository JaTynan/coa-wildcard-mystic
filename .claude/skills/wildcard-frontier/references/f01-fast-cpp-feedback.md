# F1. Minutes-not-hours feedback for C++ changes

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Classify every step with `wildcard-change-control` before doing it.

## 1. Goal and owner

A C++ change (a file in `patches/`) should learn that it is broken in minutes, not after a 2 to 3 hour build.
Owner: the pipeline. It is James's costliest ongoing failure.

## 2. Where the project stands (2026-11-22)

- **One workflow**, `.github/workflows/build-worldserver.yml`. It starts on a daily timer (`cron: '17 3 * * *'`,
  03:17 UTC) or by hand. **Nothing runs on a pull request.**
- It builds a manager release **once**; a later change to `patches/` is built only when someone runs it by hand
  with `rebuild` ticked (job `check`, step "Build only releases not built before").
- Order inside job `build` (Windows runner, 340 minute limit): check out the core; apply `patches/*.patch` with
  `git apply --check`; check out the modules; apply the official build's module patches; apply
  `patches/*.ps1` in name order; install Boost and MySQL (cached); configure; `cmake --build build --target
  worldserver -j 4`; run `worldserver.exe --version`; package; publish a release.
- So a failed anchor is found a few minutes into a run, a compile error an hour or more in, a link error near the
  end, and a start-up failure only after patch night installs the build on the VM.
- 56 patch scripts and 5 `.patch` files today (`ls patches`).
- Failures recorded in history, each of which cost at least one build. Six are on record (five at the compile
  step, one at start-up; full list: `wildcard-build-and-env/references/failure-catalogue.md`); four are shown
  here. **None is recorded as a pure anchor failure.**

  | Date | What | Found | Source |
  |---|---|---|---|
  | 12 Nov | `.legendary` command did not compile (command types not qualified) | at compile | commit 0220a49 |
  | 16 Nov | An enchant script used the name `SYNCHRONIZE`, a Windows header macro | at compile, Windows only | commit a4048e7, PR #176 |
  | 19 Nov | With mod-dungeon-clear the compiler command passed Windows' length limit | at compile | commit 2606a77, PR #191 |
  | 19 Nov | Two modules registered the same `.ahbot` sub-commands; the server stopped at start-up ("Duplicate blank sub-command") | after install | comment in the workflow step "Apply the official build's module patches" |

- 40 builds were published between 30 Oct and 21 Nov (`git tag -l 'wcme-server-*'`), the newest numbered
  `build70`. The gap is **not** a failure count: every daily timer run that decides "already built" also uses up a
  number. The true number of failed runs is UNVERIFIED; get it with `gh run list --workflow build-worldserver.yml`.
- The written rule (`docs/agents/context/patches.md`): "a failed anchor costs a whole build, so test the script
  against the pinned sources before pushing." **No tool in the repository does that.** `scripts/` holds only
  `resolve_release.py` and `legendary_history.py`.
- Roadmap item 1 (keep a build tree on the VM and recompile only what changed) is **not started**.
- The build caches Boost and MySQL only. There is no compiler cache.

## 3. Why the current approach falls short

| Kind of failure | Found today | Could be found |
|---|---|---|
| Anchor missing or matched twice | minutes into a build run, but only once a run is started, after the PR is merged | on the PR, in a few minutes, on a free Linux runner |
| Patch order (script B needs text script A changed) | same | same check, because it applies all scripts in order |
| Setting read by a patch but missing from `server-settings.txt`, or no `CHANGES.md` row | by a reviewer, if at all | a static check on the PR, seconds (see `wildcard-validation-and-qa`) |
| Compile error in inserted C++ | 1 to 2 hours into the build | minutes, with an incremental build tree that already holds everything else compiled |
| Windows-only compile error (header macros) | same | only by a Windows compile; a Linux compile would have missed 16 Nov |
| Link error | 2 to 3 hours | minutes, same incremental tree |
| Start-up failure | after install, on the live server, players waiting | before install, with a dry-run start on the VM |
| Wrong behaviour in game | when a player notices | F5 |

A consequence for the risk matrix: likelihood check **L4** ("proof before going live") scores 1 only when "an
automatic check proves it". For C++ the only automatic check is that the program prints its version, so L4 cannot
honestly score 1. Worked through the matrix: a patch scores L1 = 3; with every other likelihood check at its
best (1) and L4 = 3 the total is 10, which is "medium". A patch **without** an off switch scores impact I3 = 2
(revert and rebuild), so its class is MEDIUM at best. A patch **with** an off switch that touches one feature can
score impact 1 and so LOW on paper, but the LOW path it would then take is itself not built (F2), and the nightly
restart does not install builds. Either way, no C++ change can travel an automatic path today.

## 4. This project's asset

- **Pinned inputs.** `python3 -I scripts/resolve_release.py latest` prints the exact commit of the core and every
  module (on 22 Nov: tag `server-0.261119.114`, core `c3f2fd4b...`). Any machine can fetch the same sources.
- **Patches are plain text edits that throw.** Each script reads a file, checks its anchor, replaces, writes. They
  use relative paths with forward slashes (`core/modules/mod-playerbots/src/...`) and PowerShell cmdlets only, so
  they should run under PowerShell 7 on Linux. **UNVERIFIED**: PowerShell was not available where this was written.
  Verify with one run of step 1.
- **The core can start, load everything and exit.** `worldserver --dry-run` runs the full world load, then exits 0,
  or 1 if a database update failed (pinned core, `World.cpp`, search `isDryRun`). The 19 Nov start-up failure
  would have stopped a dry run.
- **The upstream workflow is a known-good recipe** for the same build (`.github/workflows/coa-bots-build.yml` in
  the core repository), and ours already matches its settings.
- **The host upgrade** named in the roadmap (more cores, about 10 GB more memory for the VM) is what item 1 was
  waiting for. Whether it has happened is not recorded in the repo.

## 5. First three steps in this repo

### Step 1. Anchor pre-flight on every pull request that touches `patches/`

- **The tool already exists; do not rebuild it.** `wildcard-patch-authoring` ships a working
  `scripts/preflight.py` (fetches each upstream repository at the commit `resolve_release.py` prints, lays them
  out as the workflow does, runs the same apply steps in the same order, no compile; PASS in about 80 s on
  2026-11-22) and a ready workflow file, `references/preflight-pr-check.workflow.yml` (status: written, never run
  on GitHub).
- The step is to **promote both into the repository proper** (`scripts/preflight.py`,
  `.github/workflows/patch-preflight.yml`) in a pull request of their own.
- What it is worth, said exactly: the record has five compile-step failures and one start-up failure, and none
  recorded as a pure anchor failure. The pre-flight's text checks **do** catch the 21 Nov glued include
  (e0cc2f5) and flag the 16 Nov `SYNCHRONIZE` macro (a4048e7); both were shown on scratch copies with the old
  bug put back (`wildcard-patch-authoring`, `references/reading-preflight-output.md`). It also guards against
  the failure the design expects at every core update (a moved anchor). It does not compile: pair it with step 2.
- Later, change `build-worldserver.yml` to call the same script so the two cannot drift (separate PR).
- **Class estimate:** adding a workflow is hard stop 5 ("the build workflow"; a new read-only workflow lives in the
  same folder and holds the same recipe): **HIGH, James merges.** Changing `build-worldserver.yml` itself is hard stop 5 without question.
- Check it works by opening a test PR that breaks one anchor on purpose; it must fail and name the script.

### Step 2. An incremental build tree on the VM (roadmap item 1), build only

- Create `vm/Build-Local.ps1`. It keeps one build folder on the VM that is never deleted. The trick that makes it
  fast: apply the patches to a **scratch copy** of the pinned sources, then copy into the build folder **only files
  whose content differs**, leaving every other file's modified time alone. The build tool (Ninja) recompiles a file
  only when its time changed, so a one-file patch change recompiles a handful of files, not thousands. Applying
  patches straight onto the build folder would touch files and force a long rebuild.
- Same configure line as the workflow (copy it; do not "improve" it), same Boost 1.87 and MySQL 8.4.9 client.
  Limit the build (`-j 2` or `-j 3`) and refuse to run when players are online unless forced (ask the console
  `server info` the way `PatchNight.ps1` does).
- Output goes to a side folder. **This step never installs anything.** GitHub stays the builder of record.
- Needs on the VM: Visual Studio Build Tools, CMake, Ninja, 20 to 30 GB of disk (roadmap item 1).
- **Class estimate:** MEDIUM (a new script, runs on the live VM, can cost CPU; no saved data touched; undo is
  "do not run it"). If it is later allowed to install its result, that is hard stop 5 (the installer): HIGH.
- Measure before trusting: first full build time, then five one-file changes, save to finished program.

### Step 3. A dry-run start before the server is stopped

- In `patch-night/PatchNight.ps1`, after the new build is downloaded and unpacked and **before** `StopWorld`: run
  the new `worldserver.exe --dry-run` from the unpacked package folder. Exit 0 = go on. Anything else = announce
  "restart cancelled", leave the running server alone, log `[FAIL]`.
- **UNVERIFIED and must be proven first on a copy:** whether a dry run is safe beside a running world server on the
  same database. It loads everything and may apply pending database updates; it must not be pointed at the live
  databases until that is known. First PR: a manual `patch-night/Test-DryRun.ps1` that James runs once against a
  restored copy (or with the server stopped), recording the time it takes and what it writes. Starting the world
  takes many minutes, so it also has to fit inside the countdown.
- **Class estimate:** hard stop 5 (patch night itself). HIGH, James merges.

## 6. Milestone

**You have a result when**, over 14 consecutive days and at least 10 pull requests that touch `patches/`:
every anchor or order failure is reported on the pull request in **under 10 minutes**, and **zero** build runs stop
at an "Apply" step. And for step 2: a one-file C++ change goes from saved file to a finished `worldserver.exe` on
the VM in **under 15 minutes**, five times out of five, with the tick budget (F4) passing during the builds.

It is falsified if a build still stops at an "Apply" step after a green pre-flight (the two recipes drifted), or if
the incremental build regularly rebuilds most of the tree (the copy-only-changed trick is not holding).

## 7. Known wrong paths and risks

- **A Linux compile as the proof.** It is cheap and catches plain mistakes, but it would have missed the 16 Nov
  Windows macro failure. Useful as an extra, never as "it builds".
- **A compiler cache on GitHub first.** The build uses precompiled headers (`USE_COREPCH=1`, `USE_SCRIPTPCH=1`).
  Whether a cache helps with them here is UNVERIFIED; it could cost days for nothing. Measure on the VM tree first.
- **Two recipes.** A pre-flight that applies patches differently from the real build gives false comfort. One
  script, called by both.
- **Building on the VM while friends play.** It takes CPU from the game and corrupts the lag campaign's numbers.
- **Treating the local build as the release.** Different machine, possibly different tool versions. Keep the
  GitHub build from clean sources as the one that is installed, until James decides otherwise.
- **Dry-running against the live database unproven.** See step 3.
- **Calling the 2 to 3 hour build "slow" or "stuck".** It is the normal time.

## 8. Dependencies

Needs nothing. Unlocks F2 (a build that has proven it starts), F3 (L4 can score 1), F5 and F6 (C++ handlers at a
sane cost), F11 (the patch porter's first tool is step 1's script).
