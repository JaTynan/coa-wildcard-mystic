# for-083, and building for a core older than main's

Read this when the server is on an older manager release than `main`'s patches were written for, when someone
proposes a second build branch, or when you need the `for-083` story. Facts as of 2026-11-22. The incident
itself is also told in `wildcard-failure-archaeology` (`wildcard-failure-archaeology/references/build-and-core-updates.md`).

## for-083 and main

What it was. In early November the server ran manager release `.83` while `main`'s patches had
been rebased onto `.90` (commit `f83171d`, 1 Nov). Two of main's patch files do not fit the
`.83` core. `for-083` was a second branch holding `.83` versions of the patches, and its builds
were started by hand from that branch with release `server-0.261028.83`. Build 20, the last
`.83` build, was made from it (its tag is on `for-083` and not on `main`).

The rule. README.md: "Never merge it into `main` or `main` into it; close any pull request
between the two." The reason is recorded. On 5 Nov `main` was merged into `for-083`
(`3a64277`) and a pull request merged that back (#41). The merge replaced the `.83` patches
with `.90` ones and dropped a build fix from its workflow. `ebc3c3d` restored the branch by
hand. Every change wanted on both cores was then made twice, as a pair of pull requests, for
example #106 `scrolls-to-currency-for-083` and #107 `scrolls-to-currency-main`.

Status on 2026-11-22. The branch still exists with its last commit on 9 Nov (`869bd0f`), and
five side branches from that period remain. README.md still calls it "the build branch for the
server's current core (release .83)" and says "It goes away once the server moves to a newer
release". The repository's own evidence says the server has moved: builds 21 to 53 were for
`.95`, commit `4893a38` (on the unmerged branch `docs/patch-night-build51`) records build 51
installed on 18 Nov, and
`docs/agents/context/patch-night.md` gives `wcme-server-0.261119.114-build70` as its example
of an installed tag. So the README line looks out of date. Deleting the branch and correcting
the README are James's decisions. Raise them through `wildcard-docs-and-publishing`. Do not
do either yourself.

If the server lags behind main's core again:

1. Find out whether a second branch is needed at all:
   `python3 -I .claude/skills/wildcard-build-and-env/scripts/check_patch_files.py --release <the server's release>`
   and run the patch script pre-flight from `wildcard-patch-authoring` against the same release.
2. If everything fits, there is no branch. Run the workflow from `main` with that release
   typed in and `rebuild` ticked. This is what happened for `.95`: builds 45 to 51 and 53 were
   made for `.95` although a `.110` build (44) already existed.
3. Only if it does not fit, James may decide on a build branch. Cut it from the tagged commit
   of the last good build for that core, name it `for-<release number>`, build from it by
   hand, never merge it either way, make each shared change as two pull requests, and delete
   it when the server catches up.
4. Cheaper than a branch, when the difference is small, is a patch script that accepts either
   version of the upstream code. `c4b6718` did this for Mana-forged Barrier ahead of a core
   change.
