---
name: wildcard-build-and-env
description: How the patched Wildcard world server is built on GitHub Actions, and how to stop a 3½ hour build failing late. Covers build-worldserver.yml step by step (what fails where, with the error text), scripts/resolve_release.py and the pinned commits, release tags wcme-server-X-buildN, the automatic rebuild rule (a build whenever patches/ changed) and the rebuild tick box, starting and watching a build, the catalogue of past build failures, quick pre-push checks (check_patch_files.py, which_build.py), proposed workflow improvements, the for-083 branch story, and what to do after a new CoA or manager release. Load it when "the build failed" at any step ("Apply our patches", "Configure", "Build worldserver", "Publish as a release"), before starting a build, when asked "is my fix in a build yet" or "why did the nightly build do nothing", when a new manager release appears, or before touching .github, scripts/resolve_release.py or vm/. If the failed step is "Apply our patch scripts" (a moved anchor), fix it with wildcard-patch-authoring.
---

# Wildcard build and environment

Builds are the most expensive routine event in this project. One takes about 3½ hours on GitHub
(builds 61 to 74: 3h30 to 3h45, one outlier at 6h11; README.md's "about 1.5-3 hours" is out of
date; the job is allowed 340 minutes), and most failures show
up only after a long wait. That is normal for this build. Do not call a build of that length
slow or stuck. The useful work is catching the failure before the build starts, which is what
most of this skill is about.

All facts below are as of 2026-11-22, `origin/main` at `d3e030f`, unless a line says otherwise.
`docs/agents/*` and `.claude/agents/*` (hard stops, the risk matrix)
came with PR #232, merged on 22 Nov 2026 (`0802d4f`), and are on `main`: what rests on them is **DOCTRINE**. Status words are defined in `wildcard-change-control`, section 1.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Write, port or pre-flight a patch script or patch file; a build that stopped at "Apply our patch scripts" (tie-break: this skill says what failed and how to rerun; that one fixes the script) | `wildcard-patch-authoring` |
| Decide whether a change may go ahead, or who merges | `wildcard-change-control` |
| Understand patch night, rollback, the VM's files; the table of when each kind of merged change goes live | `wildcard-run-and-operate` |
| Diagnose a server that built fine but misbehaves, lags or crashes | `wildcard-debugging-playbook`, `wildcard-diagnostics-and-tooling` |
| Change a setting or add one | `wildcard-settings-and-flags` (no build needed for a value change) |
| Fix an enchant with SQL | `ascension-restoration` (no build needed) |
| Learn what the C++ being compiled does | `azerothcore-coa-reference` |
| Decide what counts as tested | `wildcard-validation-and-qa` |
| Read the full story of a past incident | `wildcard-failure-archaeology` |

## Start here

- A build failed: find the step in "The step sequence", then `references/failure-catalogue.md`.
- About to push under `patches/` or start a build: "Shift-left: catch it before the 3 hours".
- "Is my fix in a build?": `python3 -I .claude/skills/wildcard-build-and-env/scripts/which_build.py <commit>`.
- A new manager release appeared: "After a new manager or CoA release".

## Rules before you touch anything

1. The build workflow, the installer in `vm/` and rollback are hard stop 5 in
   `docs/agents/context/change-risk.md`. Any change to them is HIGH and waits for James.
   Classify with `wildcard-change-control` first. This skill gives you proposals to put in
   front of him, not permission.
2. Starting a build is a deployment step, not a test. A finished build is published as a
   release, and the next 3:30 am patch night installs the newest release that matches the server's
   core (`patch-night/PatchNight.ps1:859-863`). It does not check which branch the build came
   from. **Proposed practice (not yet adopted by James):** build only from `main`, after
   James has merged, and only on his say-so (he starts the run, or tells a session to).
   Purpose: an unreviewed branch build would otherwise be installed at the next patch
   night. No incident of this kind is recorded. It follows from reading the code. This rule
   is the home for "who starts a rebuild"; deleting or drafting a release is the same kind
   of act (it decides what patch night installs) and is James's too.
3. James merges pull requests. Nothing here merges, cancels or installs for him.
4. `for-083` and `main` are never merged into each other (README.md "Branches").

## Words used here

| Word | Meaning |
|---|---|
| Manager | CF-Server-Manager, the Windows program that installs and updates the Conquest of Azeroth (CoA) server. |
| Manager release | One version of the official server, tagged like `server-0.261119.114`. People say ".114". |
| Core | The server's C++ source, `Corfirean/azerothcore-wotlk-coa`. Each manager release pins one core commit. |
| Pinned | Fixed to one exact commit id, so two builds of the same release use identical upstream code. |
| Patch file | `patches/*.patch`, a diff applied with `git apply`. Five exist. |
| Patch script | `patches/NN-name.ps1`, a PowerShell script that edits source by finding an exact piece of text (the anchor). 56 exist. |
| Anchor | The text a patch script searches for. It must be found exactly once or the script stops the build. |
| Runner | The temporary GitHub machine a job runs on. It starts empty every time. |
| Run number | GitHub's counter for this workflow. Every run gets one, including runs that build nothing. |
| CMake, Ninja, MSVC | The tool that writes the build files, the tool that runs the compile steps, and Microsoft's C++ compiler. |
| Sparse checkout | A git checkout that downloads only some folders. |
| Any other term | `.claude/skills/azerothcore-coa-reference/references/glossary.md` |

## What a build is

Inputs:

| Input | Where it comes from |
|---|---|
| Manager release tag | `latest`, or the tag typed into the Run workflow form |
| Pinned commits of the upstream repositories | `scripts/resolve_release.py` reads them from two public lists (see below) |
| Our patch files and patch scripts | `patches/` at the commit of this repository being built |
| mod-ollama-chat (bot AI chat) | Pinned in the workflow itself: `906eb2a45f5b3b815a281977005371193517eb32` (workflow line 175, repeated on line 303) |
| Installer and addon | `vm/*` and `addon/WildcardEnchants` |

Outputs, only when every step passes:

- A GitHub release tagged `wcme-<manager tag>-build<run number>`, for example
  `wcme-server-0.261119.114-build70`. The tag points at the commit of this repository that was
  built (`--target github.sha`, workflow line 320).
- One zip, `coa-wildcard-<manager tag>.zip`, containing `server/worldserver.exe`, any DLLs
  beside it, `server/core-revision.txt` (the 40 character core commit, no line break),
  `addon/WildcardEnchants/`, `Install.cmd`, `Restore-Official.cmd`,
  `Install-WildcardServer.ps1` and `BUILD-INFO.txt`.
- `BUILD-INFO.txt` lists the manager release, every pinned commit, the module patch checksums,
  our `*.patch` file names, this repository's commit and the UTC build time. The same text is
  the release's description. Patch night reads the `Core:` line from that description to match
  a build to the installed server, so do not edit release notes by hand.

Only the world server is built (`--target worldserver`). The auth server stays the manager's own.

### resolve_release.py

```bash
python3 -I scripts/resolve_release.py latest
python3 -I scripts/resolve_release.py server-0.261119.114
```

It reads `changelog/history.json` from `Corfirean/coa-server-build` first and the manager's
`src/data/server-history.json` second (the manager's copy can lag a release behind,
`scripts/resolve_release.py:17-19`). `latest` is the last entry when sorted by date, then tag.
It prints `key=value` lines and, inside a workflow, writes them to `$GITHUB_OUTPUT`.

Output on 2026-11-22: tag `server-0.261119.114`, `core_sha=c3f2fd4b2395...`,
`bots_sha=178a7fde...`, `scaling_sha=3c2febf6...`, `squid_sha=4ef5ed9e...` (`squid_tag=v3.0`),
`dungeon_sha=6efb59ea...`, `build_sha=355362dd...`, plus a patch path and SHA-256 for SQUID and
for Dungeon Clear.

| Key | Repository | Always present |
|---|---|---|
| `core_sha` | `Corfirean/azerothcore-wotlk-coa` | yes |
| `bots_sha` | `Corfirean/mod-coa-playerbots` (CoA's own bots) | yes |
| `scaling_sha` | `Corfirean/mod-coa-content-scaling` | yes |
| `squid_sha`, `squid_tag` | `Zyth45/mod-playerbots` (SQUID's Playerbots, the ~750 random bots) | yes |
| `dungeon_sha` | `Zyth45/mod-dungeon-clear` | only if the release lists it |
| `squid_patch`, `dungeon_patch` and their `_sha256` | files in `Corfirean/coa-server-build` | only if listed |
| `build_sha` | `Corfirean/coa-server-build` | only if a module patch is listed |

The script exits with a message when a release is unknown ("is not in the manager's list.
Recent ones: ..."), when a part is missing ("lists no core commit"), or when a part moved to a
different repository ("The build recipe needs checking"). The last one means upstream changed
how it builds, and the workflow needs a human look.

The lists are live upstream data. Commit `01159e2` says module patches are listed "since
server-0.261119.114", yet on 2026-11-22 the lookup for `server-0.261108.95` also returns
module patches. So a rebuild of an old release may not use the same recipe as its first build.
Run the script for the release you are about to build and read the output.

## Triggers, and when a fix goes live

| Trigger | What it does |
|---|---|
| Schedule, `17 3 * * *` | 03:17 UTC every day by the cron line, but GitHub starts scheduled runs late: observed starts were 8:37 to 10:50 pm Sydney time (runs up to 75). Uses the workflow and patches on `main`, release `latest`, rebuild off. |
| Run workflow (`workflow_dispatch`) | Inputs `release` (default `latest`) and `rebuild` (tick box, default off). Can run from any branch. |

Concurrency group `build-worldserver` with `cancel-in-progress: false`. A second run waits for
the first instead of cancelling it. GitHub's own documented behaviour (not something in this
repository) is that only one run can wait in a group, so starting a third replaces the waiting
one.

The `check` job (ubuntu, 10 minute limit) runs first and decides (step `decide`; rule since PR #241, 23 Nov
2026, James):

- If `rebuild` is ticked, build.
- Otherwise find the newest release whose tag starts with `wcme-<manager tag>-`. None: build ("has no build
  yet").
- Otherwise compare the commit that release was built from (`target_commitish`) with `HEAD`, for
  `patches/`, `.github/workflows/build-worldserver.yml` and `scripts/resolve_release.py` only. Any change: build,
  printing "Changed since `<tag>`:" and a diff summary. No change: print "is already built and the patches have not
  changed since; nothing to do." and skip the build job. The run still ends green in about a minute and uses up a
  run number.
- If GitHub cannot be asked, the step fails red. If the built commit cannot be fetched, it builds "to be safe".

Consequences:

1. **A merged patch is built the same evening** with nobody ticking anything, provided it was on `main` when the
   scheduled run checked out. Scheduled runs start about 8:37 to 10:50 pm Sydney, so a patch merged later than
   that waits for the next evening. SQL, settings, addons, docs and skills never cause a build.
2. **Runs queue.** A scheduled run that waits behind a by-hand run usually finds nothing changed and skips (run 75
   waited behind build 74 on 24 Nov, then skipped). Starting a run by hand in the afternoon therefore replaces
   that evening's scheduled build rather than adding to it.
3. **The schedule only ever builds `latest`.** If the server is on an older release, its builds must be started by
   hand with that release typed in.
4. **A failed build publishes nothing, so the next evening builds again** (the newest release still predates the
   change) until one passes. A broken patch fails nightly until it is fixed on `main`.
5. **Building does not install.** The daily 3:30 am patch night installs the newest matching release (until 23 Nov
   only the weekly Tuesday run did; the nightly run had `-NoInstall`). `Run-PatchNight-Now.cmd` installs too
   (James's call).

So for a C++ change the path to live is: merged to `main`, the evening build (about 3½ hours), then the next 3:30 am
patch night. A build that finishes after 3:30 am Sydney waits a night. Settings and SQL changes need no build. The
rebuild rule above is this skill's own fact; the one table of when every kind of merged change goes live is in
`wildcard-run-and-operate`, "When does my merged change go live?".

Check whether a commit is in a published build:

```bash
python3 -I .claude/skills/wildcard-build-and-env/scripts/which_build.py <commit>
```

Exit code 1 and "is in no published build yet" means the evening build has not run or has not finished. Example:
patch 96 (`13a03d3`) was merged on 21 Nov, under the old rule, and stayed unbuilt until build 74 (24 Nov).

## The step sequence

Phase tells you how deep into the run a failure in that step appears. It is derived from the
order of steps. The repository records no per-step timings, so there are no minute counts here.
"Early" means before any compiling. Full error texts and fixes are in
[references/failure-catalogue.md](references/failure-catalogue.md).

`check` job (ubuntu):

| Step | Does | Fails with |
|---|---|---|
| Look up the release's exact commits | Runs `resolve_release.py` | "is not in the manager's list", "lists no ... commit", "The build recipe needs checking", "No release list could be read." |
| Build a release with no build yet, or whose patches changed since its newest build | The decision above | Fails red only if GitHub cannot be asked. Otherwise prints "has no build yet", "Changed since ..." or "already built and the patches have not changed since; nothing to do." |

`build` job (windows-latest, 340 minute limit):

| # | Step name in the log | Does | Phase | Typical failure text |
|---|---|---|---|---|
| 1 | Keep line endings as they are | `git config --global core.autocrlf false` | early | none seen |
| 2 | This repository | Checks this repository out into `_mine` | early | none seen |
| 3 | Core at the release commit | Core at `core_sha`, depth 1, into `core` | early | checkout error if the commit is gone |
| 4 | **Apply our patches** | Each `patches/*.patch` in name order: `git apply --check`, then apply | early | "`<name>` no longer fits release `<tag>`. The patch needs refreshing for this core." |
| 5 | CoA bots module, Content Scaling module, SQUID's Playerbots, Dungeon Clear module | Four checkouts at pinned commits | early | checkout error |
| 6 | The official build's module patches | Sparse checkout of `patches` from `coa-server-build` | early | checkout error |
| 7 | Apply the official build's module patches | Verifies each patch's SHA-256, then applies it to its module | early | "checksum ... differs from the release's ...", "does not apply to ...", "is listed but ... was not checked out." |
| 8 | AI chat for bots | mod-ollama-chat at the pinned commit | early | checkout error |
| 9 | **Apply our patch scripts** | Runs every `patches/*.ps1` in name order from the workspace root. Prints `== NN-name.ps1` before each | early | "Core changed: ... was not found exactly once in ...", "CoA changed: ...", "SQUID changed: ...", "SQUID's bots changed: ...", "mod-ollama-chat changed: ...", "A racial patch did not run before this one" (full list of anchor texts: `wildcard-patch-authoring`), then "`<script>` failed." |
| 10 | Place the modules where the core expects them | Copies the CoA bots and Content Scaling modules into `core/modules` | early | "copying ... failed (N)" |
| 11 | Cache Boost and MySQL | Restores two folders | early | a miss is not a failure |
| 12 | Install Boost 1.87 and the MySQL 8.4 client | Downloads on a cache miss, finds OpenSSL on the runner | early | "Boost download attempt N failed", "got an HTML page instead of the installer", "MySQL download looks wrong.", "No OpenSSL development install found on the runner." |
| 13 | MSVC environment | Sets up the Microsoft C++ compiler for x64 | early | action error |
| 14 | Configure | CMake generates the Ninja build files | early | "CMake configure failed." |
| 15 | **Build worldserver** | `cmake --build build --target worldserver -j 4`. Nearly all of the 3½ hours | middle to late | "Build failed." Above it: `error C....` from the compiler, `LNK....` from the linker, or `ninja: fatal:` |
| 16 | Check it starts and reports its revision | `worldserver.exe --version` | late | "worldserver --version exited with N" |
| 17 | Package for the VM | Builds the zip and `BUILD-INFO.txt` | late | copy errors |
| 18 | Publish as a release | `gh release create` | late | "Publishing the release failed." |

Three things that table implies:

- Steps 4, 7 and 9 stop at the first problem. One run reports one broken patch. If three
  anchors moved, that is three runs unless you check them all beforehand.
- The compiler also stops at the first failing file (Ninja's default). One run, one compile
  error.
- Step 16 is the only test of the finished program, and it only proves the program loads.
  Build 57 passed it and then stopped while starting the world on the VM. Start-up failures
  appear after the build, at install time.

## Trigger and watch a build

From the website: Actions tab, **Build patched worldserver**, **Run workflow**, pick the
branch (`main`), type the release or leave `latest`, tick **Build even if this release was
built before** when the release already has a build.

With the `gh` command line tool. These are GitHub's standard commands, written but not
executed on 2026-11-22.

**Gate, before the first command.** A finished build is a release the next 3:30 am patch night will
install, whatever branch it ran on. Start one only from `main`, after James has merged, and on
his say-so (Proposed practice, not yet adopted by James; purpose and source in rule 2 above).
Changing the workflow itself is hard stop 5.

```bash
R=JaTynan/coa-wildcard-mystic
# 1. Shift-left checks first (next section). Then:
gh workflow run build-worldserver.yml --repo $R --ref main -f release=latest -f rebuild=true
gh run list --repo $R --workflow build-worldserver.yml --limit 10
gh run watch <run id> --repo $R            # optional, blocks until it ends
gh run view <run id> --repo $R             # jobs and steps with pass or fail
gh run view <run id> --repo $R --log-failed  # only the failed step's log
gh release list --repo $R --limit 5        # the new wcme-... tag appears here
```

Some agent sessions cannot use GitHub's GraphQL interface (`.claude/agents/patch-reviewer.md`
says "GraphQL is blocked here; use REST through `gh api`"). If a `gh` subcommand fails for
that reason, use the REST calls directly:

```bash
gh api repos/$R/actions/workflows/build-worldserver.yml/dispatches -f ref=main -f 'inputs[release]=latest' -f 'inputs[rebuild]=true'
gh api "repos/$R/actions/workflows/build-worldserver.yml/runs?per_page=10" --jq '.workflow_runs[] | [.run_number,.event,.status,.conclusion,.head_sha[0:7],.run_started_at,.updated_at,.id] | @tsv'
gh api repos/$R/actions/runs/<run id>/jobs --jq '.jobs[] | .name, (.steps[] | "  \(.number) \(.conclusion) \(.name)")'
gh api repos/$R/actions/jobs/<job id>/logs        # plain text log of one job
```

Reading a result:

| What you see | Meaning |
|---|---|
| Green run, about a minute, `build` skipped | Nothing in `patches/`, the workflow or the resolver changed since the newest build, and `rebuild` not ticked. Nothing happened. |
| Run "pending" or "queued" for a long time | Another build holds the concurrency group. It will start afterwards. |
| Red at a step in bold above | Go to the failure catalogue. |
| Green, a new `wcme-...-buildN` release | Built. Installed at the next 3:30 am patch night. |

After a build, confirm what it contains:

```bash
git fetch --tags
python3 -I .claude/skills/wildcard-build-and-env/scripts/which_build.py <commit of your fix>
```

## The cost model

- Every run starts on an empty machine and compiles everything. The workflow caches only the
  Boost and MySQL folders (key `winbuild-deps:boost-1.87.0:mysql-8.4.9`). There is no compiler
  cache and no kept build folder, so a one line change costs the same as the first build ever.
- Everything before step 15 is cheap. Step 15 is the whole cost.
- `docs/agents/context/patches.md` says "a failed anchor costs a whole build". By step order,
  the anchor steps (4 and 9) run before compiling, so that run itself ends early. What you
  lose is the build you were waiting for: nothing is published, nobody is told, and each
  retry is another full dispatch that then spends the full 3½ hours if it gets further.
- A mistake inside inserted C++ is the expensive kind. The anchor matches, the patch applies,
  and the error appears during step 15.
- A start-up failure costs the most: a full build, an install, and a server that fell back to
  the official program without Mystic Enchants.
- Undoing a bad C++ change is "revert and rebuild" in the risk matrix (the matrix says 2-3 h; about 3½ h now) (impact check
  I3, score 2).

## Shift-left: catch it before the 3 hours

Run these in order before pushing a change under `patches/`, before starting a build, and when
a new manager release appears. Each takes minutes or less. `check_patch_files.py` is the fast
check of the `*.patch` files only; the authority for "the patches apply" is `preflight.py` in
`wildcard-patch-authoring`; the full pre-merge check set is in `wildcard-validation-and-qa`.

| # | Check | Catches | Command | Status |
|---|---|---|---|---|
| 1 | Release lookup | Unknown release, a moved or missing repository, new module patches | `python3 -I scripts/resolve_release.py latest` | Works. Run on Linux, 2026-11-22. |
| 2 | Patch files fit the pinned core | Step 4 failures | `python3 -I .claude/skills/wildcard-build-and-env/scripts/check_patch_files.py` | Shipped and tested 2026-11-22. |
| 3 | Official module patches: checksum and fit | Step 7 failures | same script with `--modules` | Shipped and tested 2026-11-22. |
| 4 | Patch scripts against the pinned sources | Step 9 failures: moved anchors, script order, a missing line break | Owned by `wildcard-patch-authoring` (its pre-flight). Needs PowerShell 7 (`pwsh`). | See that skill. |
| 5 | Syntax-only compile of the files a patch touches | Typos, undeclared names, wrong namespaces | No script in this repository. | Candidate, NOT BUILT YET. |
| 6 | Is the fix actually in the build | A rebuild that was never started | `which_build.py <commit>` | Shipped and tested 2026-11-22. |

### check_patch_files.py

It repeats steps 4 and 7 of the build without Windows. It fetches each pinned commit without
file contents, applies the patches to a temporary index, and lets git download only the files
the patches touch. First run: about 12 seconds and under 3 MB on a Linux machine. Later runs: under a second.
It changes nothing in the repository.

```bash
S=.claude/skills/wildcard-build-and-env/scripts
python3 -I $S/check_patch_files.py                        # newest release
python3 -I $S/check_patch_files.py --modules              # plus the official module patches
python3 -I $S/check_patch_files.py --release server-0.261108.95
python3 -I $S/check_patch_files.py --patches /some/other/patches
```

Exit code 0 means every patch fits, 1 means at least one does not (each is named, with git's
own "patch failed: file:line"), 2 means the check could not run. It keeps going after a
failure so you see every patch that needs work, which the build never shows you in one run.

What it proved on 2026-11-22: main's five patch files fit `.114`, `.95` and `.90`, and two of
them do not fit `.83` (which is why `for-083` existed). The index method gives byte-identical
files to a normal `git apply` in a working folder, compared on all 11 touched files.

What a pass does not prove: anything about the 56 patch scripts, compiling, linking or start-up.

### Syntax-only compile (candidate)

Several commit messages record an ad hoc check of this kind done in a work session, for example
"Compiles with -Wall -Wextra against core c3f2fd4b2395 with our patches" (`5c2a489`) and
"Syntax-checked against the core" (`273d36d`). No script for it is in the repository, so
treat it as a technique someone has to set up again each time.

Two recorded lessons limit how far to trust it:

- It ran with a Linux compiler. The real build uses Microsoft's. `SYNCHRONIZE` is a macro in
  Windows headers only, so a constant with that name passed locally and broke the Windows
  build (`a4048e7`). Avoid ALL_CAPS names that Windows might define.
- The check must use the exact text the script inserts. In `e0cc2f5` the local check added a
  line break the script did not, passed, and the real build failed.

## Proposals for the workflow

All of these change hard stop 5 files. They are proposals for James, each **"Proposed practice
(not yet adopted by James)"**. Detail, expected saving and risk for each are in
[references/proposals.md](references/proposals.md). Read it before suggesting any of them.

| Proposal | Saves | Main risk |
|---|---|---|
| A fast "patches apply" job on ubuntu for every pull request | Every step 4, 7 and 9 failure, found in minutes before merge | Needs `pwsh` on ubuntu and a job that publishes nothing |
| Compiler cache (ccache or sccache) | Unknown until measured. Most files do not change between rebuilds of one release | Cache size limits, wrong results with precompiled headers if set up carelessly |
| Incremental builds on the VM (roadmap item 1) | "A one-file change rebuilds in minutes" by the roadmap's estimate | Uses the live server's CPU and disk. NOT BUILT YET |
| Upload the patched source tree as an artifact | Lets anyone inspect or compile exactly what CI compiled | Storage, and it is CoA's source |
| Draft releases for test builds | Test builds from a branch that patch night will not install | Needs an input and a publish step change |
| Keep going after the first compile error (`ninja -k 0`) | Several errors from one run | Longer failing runs |

## Recreate the environment

### (a) The GitHub side

Nothing to install. The workflow file is the whole build machine. What it needs:

- The workflow asks for `contents: write` so its own token can create the release.
- Every upstream repository it checks out is public, so it uses no secrets.
- To start a run you need write access to `JaTynan/coa-wildcard-mystic`. Agents normally do
  not have it; either way the run is James's to start or approve (rule 2).
- A fork can run the same workflow and will publish releases in the fork.

### (b) A local Windows build (roadmap item 1)

Status: **NOT BUILT YET.** `docs/roadmap.md` item 1 (added 1 Nov, commit `331bfee`) plans a
kept build folder on the Windows VM so only changed files recompile. On 2026-11-22 the
repository holds no script, document or commit that implements it. The only sources are the
roadmap paragraph and the workflow.

A recipe derived from the workflow, with the exact toolchain and the CMake flags word for word,
is in [references/local-windows-build.md](references/local-windows-build.md). It is labelled
"derived from the workflow; written but not executed on 2026-11-22". Read it when James asks to
start roadmap item 1. Building on the live VM changes how the server gets its program, so
classify with `wildcard-change-control` first.

### (c) Installing a built zip on the VM

The short version, from `vm/Install-WildcardServer.ps1`. `wildcard-run-and-operate` owns the
full procedure and rollback.

1. Stop the server in the manager. The installer refuses while `worldserver` is running.
2. Extract the whole zip, double-click `Install.cmd`.
3. Start the server in the manager.

What the installer does, in order:

- Saves the live program as `Core\worldserver.official.exe`, unless the live one is already
  one of ours (it compares a hash stored in `Core\worldserver.patched.txt`).
- Reads the official program's revision with `--version` and compares it with
  `server\core-revision.txt`. On a mismatch it refuses: "This build is for core X, but the
  manager installed core Y. The manager has probably updated. Run the GitHub build again for
  the new release." `-Force` skips this. Patch night passes `-Force` only when it has worked
  out that the saved official copy is stale.
- Copies the new program in and runs `--version`. If that fails it puts the official one back:
  "The patched world server would not start here, so the official one was put back."
- Sets `CoA.MysticEnchants.AllowWildcard = 1` in `Core\configs\modules\coa.conf`.
- Copies the addon folders from the zip into `F:\CoAClient\Interface\AddOns`.

`Restore-Official.cmd` copies `worldserver.official.exe` back and removes the marker. Defaults
are `C:\Games\CoA Server` and `F:\CoAClient` (`-Server`, `-Client`).

A hand install does not write `Core\worldserver.patched-release.txt` (only patch night does,
`PatchNight.ps1:964`). Reading the code, the next patch night will therefore install the same
build again. That is harmless but explains a surprise "Installing ..." line in the log.

## for-083 and main

`for-083` was a second branch holding `.83` versions of the patches while `main` had moved to the `.90` core. It
and `main` are **never merged into each other** (README.md; the 5 Nov accident is commits `3a64277` and
`ebc3c3d`). The branch still exists (last commit 9 Nov) although the server has moved on; deleting it and fixing
the README are James's decisions. The full story, and the four-step procedure for "the server lags behind main's
core again" (usually: no branch, just a `rebuild` run from `main` with that release typed in), are in
[references/for-083-and-old-cores.md](references/for-083-and-old-cores.md). Read it before proposing a build
branch.

## After a new manager or CoA release

1. Detect. The schedule picks it up the next day. To know sooner, run
   `python3 -I scripts/resolve_release.py latest` and compare the tag with the newest
   `wcme-` release.
2. Check before the build does. Run `check_patch_files.py --modules` and the patch script
   pre-flight against the new release. Read the resolver output for new keys or a "build
   recipe needs checking" message. Both upstream recipe changes so far arrived this way
   (the SQUID patch and Dungeon Clear in `.114`).
3. If nothing was checked, the build will tell you, one failure per run: step 4 ("no longer
   fits release"), step 7, step 9 ("... changed: ...") and then step 15.
4. Port. `wildcard-patch-authoring` owns how to refresh a patch file and re-anchor a script.
   The first port, `.83` to `.90`, is commit `f83171d` (PR #29).
5. Classify the port with `wildcard-change-control`. James merges.
6. Build from `main`. With the fix merged, the evening schedule builds a release that has no build
   yet, and rebuilds one whose patches changed. Ticking `rebuild` is rarely needed now.
7. The server changes release only when James clicks **Update** in the manager. If he updates
   before a build for the new core exists, patch night logs "No patched build for core ...
   yet; the official server keeps running (no Mystic Enchants on Wildcard)"
   (`PatchNight.ps1:879`). **Proposed practice (not yet adopted by James):** do not click
   Update until `gh release list` shows a `wcme-` build for the new release. Purpose: avoid a
   night on the official server. Motivating case: the `.114` release, whose first build
   (build 57) did not start and whose next attempt stopped partway through compiling.

## Provenance and maintenance

Written 2026-11-22 from the repository at `origin/main` `d3e030f` (and PR #232's head `fcfee51`
for `docs/agents/*`), all branches and tags, and live
runs of `resolve_release.py`. Not verified: anything from the Actions run list (durations,
which runs failed, log text beyond what commit messages quote), the `gh` commands, the local
Windows recipe, and behaviour on the VM.

Re-check anything that may have drifted:

```bash
# Workflow changed? (triggers, steps, flags, pinned mod-ollama-chat)
git log --format='%h %ad %s' --date=short -- .github scripts/resolve_release.py vm
grep -n "cron\|timeout-minutes\|ref: 906eb2a\|key: winbuild\|-j 4" .github/workflows/build-worldserver.yml
# Current pinned commits
python3 -I scripts/resolve_release.py latest
# Counts quoted here: 5 patch files, 56 patch scripts, 40 builds from 70 runs
ls patches/*.patch | wc -l; ls patches/*.ps1 | wc -l
python3 -I .claude/skills/wildcard-build-and-env/scripts/which_build.py | tail -15
# Do the patch files still fit?
python3 -I .claude/skills/wildcard-build-and-env/scripts/check_patch_files.py --modules
# Anything on main that changes the program but is in no build?
git diff --stat "$(git tag -l 'wcme-*' | awk -F-build '{print $2" "$0}' | sort -n | tail -1 | cut -d' ' -f2)" origin/main -- patches
# Has roadmap item 1 been started? (expect only the workflow and the roadmap until it is)
git grep -il 'ninja\|cmake' -- . ':!patches/*.patch'
# for-083 still there?
git branch -r | grep -i '083'
# Real run history, needs GitHub access
gh run list --repo JaTynan/coa-wildcard-mystic --workflow build-worldserver.yml --limit 100
```

When a build fails in a new way, add a row to `references/failure-catalogue.md` with the error
text, the cause, the fixing commit and the check that would have caught it.
