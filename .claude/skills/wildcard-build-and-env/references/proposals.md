# Proposed workflow improvements

Read this before suggesting any change to how builds are made.

Every item here is a **"Proposed practice (not yet adopted by James)"**. None is built. Each
one changes `.github/workflows/`, `vm/` or patch night, which are hard stop 5 in
`docs/agents/context/change-risk.md`. So each is HIGH, needs a pull request James reviews and
merges himself, and should be classified with `wildcard-change-control` first.

No saving below is measured. The repository has no per-step timings. Where a number would be
needed, the entry says how to get it. Measure first: the run list gives total durations, and a
run's job page gives the time of each step.

```bash
gh api "repos/JaTynan/coa-wildcard-mystic/actions/workflows/build-worldserver.yml/runs?per_page=100" \
  --jq '.workflow_runs[] | [.run_number,.conclusion,.run_started_at,.updated_at] | @tsv'
gh api repos/JaTynan/coa-wildcard-mystic/actions/runs/<run id>/jobs \
  --jq '.jobs[].steps[] | [.name,.conclusion,.started_at,.completed_at] | @tsv'
```

Ordered by value for effort, as judged from the failure history.

## 1. A fast "patches apply" job on every pull request

What. A second workflow, on `pull_request` for paths `patches/**`, `scripts/**` and the build
workflow. On `ubuntu-latest` it repeats build steps 1 to 10: resolve the release, check out the
pinned sources, apply the patch files, the official module patches and every patch script.
Then it stops. No compiler, no release. GitHub's ubuntu image is documented to include
PowerShell 7, which the scripts need. UNVERIFIED here: no `pwsh` was available to run the
scripts on Linux while writing this, and a script that depends on Windows path or line ending
behaviour would need fixing.

Purpose. Find every failure of steps 4, 7 and 9 in minutes, before the merge, and show all of
them at once if the job is written to keep going.

Motivating incident. `docs/agents/context/patches.md` already says "test the script against
the pinned sources before pushing". Nothing enforces it. Failure 6 in the catalogue (a missing
line break) shows a hand-run local check that differed from the real script.

Expected saving. One avoided build attempt for each broken anchor or patch file. The recorded
failures were mostly compile errors, so this alone would have caught none of the six. Its
value is highest on the day a new core arrives.

Risk. Low for the server, because it publishes nothing and is a separate file. It still counts
as a build workflow change. A new required check can block merges if upstream is unreachable,
so do not make it required at first.

First step in this repository. `scripts/check_patch_files.py` in this skill already does the
patch file half and runs on ubuntu. Put it in a workflow and add the script loop from the
build workflow's "Apply our patch scripts" step.

## 2. A syntax-only compile on the patched files

What. After proposal 1's job has a fully patched tree, compile only the source files our
patches touch or add, without linking, and without building the rest. On Windows this is the
real compiler with `/Zs`. On Linux it is `g++ -fsyntax-only` or `clang++ -fsyntax-only`.

Purpose. Catch compile errors in inserted code in minutes.

Motivating incidents. Failures 1, 2 and 6 would have been caught by any compiler. Failure 3
(`SYNCHRONIZE`) only by the Windows one. Commit messages show this check already being done by
hand in work sessions ("Compiles with -Wall -Wextra against core c3f2fd4b2395").

Expected saving. Up to three of the six recorded failures on Linux, four on Windows.

Risk and unknowns. The files need the core's include paths, generated headers (the revision
header, for one) and the same defines, which means running CMake configure first and reading
the compile commands it writes. Precompiled headers are on in the real build
(`USE_COREPCH=1`, `USE_SCRIPTPCH=1`), so a file can compile in the real build only because
the precompiled header included something for it, or the reverse. Not designed or tried here.
Candidate.

## 3. Keep going after the first compile error

What. `cmake --build build --target worldserver -j 4 -- -k 0` so Ninja reports every failing
file in one run.

Purpose. One run, all the compile errors.

Expected saving. One attempt for each extra error that would otherwise appear in a later run.

Risk. A failing run takes as long as a passing one. One line in the workflow. Low.

## 4. A compiler cache

What. `sccache` or `ccache` in front of the Microsoft compiler, with its folder saved by
`actions/cache`, keyed on the core commit.

Purpose. Rebuilds of the same release recompile only what changed. On `.95` there were 22
builds of one core, and each compiled everything.

Expected saving. Unknown. Potentially most of the compile step for a rebuild where few files
changed. A patch that edits a widely included header still recompiles most of the tree.

Risk. Medium. Compiler caches and Microsoft precompiled headers and debug information
(`RelWithDebInfo`) need specific settings to work together, and the wrong ones give either no
cache hits or a broken program. GitHub limits cache storage per repository. This needs a trial
on a fork with the output compared against an uncached build before it goes near `main`.
UNVERIFIED: none of this has been tried in this repository.

## 5. Incremental builds on the VM (roadmap item 1)

What. `docs/roadmap.md` item 1: keep a build folder on the Windows VM, recompile only what
changed, patch night builds locally, GitHub stays as the backup builder.

Purpose. The roadmap's words: "a one-file change rebuilds in minutes and the result is the
live server's own format, so there is no GitHub wait and no separate test build".

Expected saving. The roadmap's own estimate, minutes for a one-file change. Not measured.

Risks the roadmap names. About 20 to 30 GB of disk, and builds "limited to a few cores or run
at quiet times so players do not feel them". The server's lag spikes are the project's first
priority, so a compile on the same machine during play is a real conflict.

Risks from reading the build. The patch scripts are written to run once on a clean tree
(`docs/agents/context/patches.md`: "They are never applied twice"). An incremental loop needs
a way to return the tree to clean and re-apply, without touching every file's timestamp, or
everything recompiles anyway. The VM's Visual Studio and CMake versions will not match
GitHub's image exactly, so the two builders can disagree. Changing patch night to build
locally is a change to patch night and rollback.

Status. NOT BUILT YET. The recipe to start from is `local-windows-build.md`.

## 6. Upload the patched tree as an artifact

What. After "Apply our patch scripts", zip the files our patches changed or added (or a diff
against the pinned commits) and upload it with the run.

Purpose. When a compile fails you can read the exact file the compiler saw without redoing
the patching. It also gives proposals 2 and 5 a tree to work from.

Expected saving. Diagnosis time per failure, not build time.

Risk. Low. Upload a diff and not whole upstream files, since this repository is public and
the source is CoA's.

## 7. Draft releases for test builds

What. A third input, for example `draft`, that publishes with `gh release create --draft`.
Patch night already skips drafts (`patch-night/PatchNight.ps1:861`).

Purpose. Build a branch to see whether it compiles without that build being installed at
the weekly patch night. Status: NOT BUILT YET.

Motivating fact. Today any published build for the installed core is a candidate for patch
night, whatever branch it came from.

Risk. Low in code. The `check` job's "already built" test would need to ignore drafts, or a
draft would stop the schedule building the real one. That detail is the reason this needs
care.

## 8. Say so when a build fails

What. On failure, open or update a GitHub issue naming the step and the last lines of the log.

Purpose. A failed scheduled build is silent today. The next thing anyone notices is a patch
night line saying no patched build exists.

Risk. Low. Needs `issues: write` for the workflow's token, which is a permission change.

## 9. Start the world once before publishing

What. Run the built world server against a throwaway database on the runner until it prints
"World Initialized In", then stop it.

Purpose. Failure 4 (build 57) passed every check and stopped at start-up.

Why it is last. It is the hardest. It needs MySQL with the three databases loaded, the
server's data files (maps and DBC files extracted from the game client, which must never be
put in this public repository) and several minutes of start-up. `wildcard-validation-and-qa`
owns the smoke test question. Treat this entry as a pointer to that skill.
