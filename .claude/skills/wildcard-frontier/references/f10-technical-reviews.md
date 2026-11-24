# F10. Agent-proposed technical reviews with no player-visible change

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Classify every step with `wildcard-change-control` first.

## 1. Goal and owner

Let periodic or on-request reviews propose database and code-health improvements that players never notice,
each with proof that behaviour did not change. Owner: the pipeline. It is the third source of change (after James
asking and player issues).

## 2. Where the project stands (2026-11-22)

- **No review process exists.** No agent, schedule or template for it. Nothing in `docs/agents/README.md` names it.
- **It has been done by hand at least three times (two with a recorded good outcome, one with the outcome not
  measured):**

  | Date | Change | Proof used | Source |
  |---|---|---|---|
  | 8 Nov | Index on `character_spell.spell` and `character_talent.spell`: the character list went from about 40 s to under 1 s | The cause was read from the core's code (a delete across about 1.7 million rows at every login); the effect was felt | PR #84; `EnsureCharacterSpellIndexes` in `PatchNight.ps1` |
  | 20 Nov | Logging changed by settings (asynchronous, quieter loggers). **Outcome not measured**: shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and the 22 Nov server start (08:53) predates the merges of #229-#231, so the console-log clear/rotation had not run yet; status OPEN | 99th percentile tick 586 ms and a 2.9 GB console log before | commit f9dc45a, PR #204 |
  | 22 Nov | Review of the 49 options CoA updates had added and left on defaults; 4 were set, the rest left | Reviewed with James | commit 6223bc8, PR #230 |

- **Raw material for a review is being collected since 21 Nov:** `Logs\mysql-slow.log` (queries over 0.5 s),
  `Timing.log`, `Logs\perf` (commit 9ba9f45). `settings-report.txt` lists unknown settings and options left on
  defaults at every run.
- The repository has 56 patch scripts, 5 `.patch` files, 64 SQL files and about 275 setting lines, grown over
  three weeks at up to 30 merged PRs a day.

## 3. Why the current approach falls short

**"No behaviour change" is a claim nobody can check today.** That is the open problem. Specifically:

- There are no tests, so "it still works" means "nobody has complained yet".
- A change in C++ or patch structure needs a 3½ hour build to learn anything (F1), so tidying patches costs
  as much as adding features.
- A database index is safe to read with but changes write cost and lock behaviour; with 750 bots writing all the
  time, "faster query" does not automatically mean "faster server".
- The matrix has no row for "should change nothing". Scored honestly, a refactor of patch scripts is C++ (L1 = 3)
  that "can only be seen working live" (L4 = 3): the same class as a new feature, for no visible gain.
- With no measure, a review cannot rank its own findings: which slow query matters, which patch is fragile.

## 4. This project's asset

- **Patches are text edits on pinned sources.** Two ways of writing the same patches can be applied to the same
  upstream commit and the **resulting source trees compared byte for byte**. If they are identical, the compiled
  server is the same program: a real proof of "no behaviour change" that needs no build and no game. This works
  for consolidating, reordering or re-anchoring patches.
- **SQL fixes are rebuilt from nothing at every start** (`000-reset.sql`). Two versions of the SQL folder can be
  applied to two copies of a scratch database and the resulting tables compared row for row.
- **Settings are a flat list.** The effective config files produced by two versions of `server-settings.txt` can
  be compared directly; the settings report already prints unknown and defaulted options.
- **The slow query log gives a ranked list for free**, with time taken and rows read.
- **Nine manager releases were built in three weeks** (.83, .85, .90, .92, .94, .95, .110, .112, .114 in the
  release tags), so there is real history for asking "which anchors broke when the core moved".
- **F4's budget** (once it exists) turns "no worse" into a PASS or FAIL.

## 5. First three steps in this repo

### Step 1. The equivalence check for patches (the proof tool)

- Create `scripts/patched_tree_hash.ps1` (to be written; shares its fetch-and-apply code with `wildcard-patch-authoring/scripts/preflight.py`, the existing pre-flight): apply
  the repository's patches to the pinned sources and print one hash per changed file and one overall hash.
- Rule it enables: **a PR that claims "no behaviour change" to `patches/` must show the same overall hash before
  and after.** The reviewer re-runs the script on both commits. Same hash = same source = same program.
- First use: none needed. Run it on `main` twice to show it is stable (same hash both times).
- **Class estimate:** LOW for the script (read-only, runs nowhere near the server). Making it a required check on
  pull requests is a workflow change: hard stop 5 by caution, James merges.

### Step 2. A slow-query review, as a case file, changing nothing

- After at least 7 days of `mysql-slow.log`: a script or a cheap agent groups the log by query shape and lists the
  top ten by total time, with rows examined and how often. Write it as `docs/agents/cases/<date>-slow-queries.md`
  from the case-file template. For each candidate index: the query, the table's size, who writes to the table
  (bots? the auction bot? every tick?), and the proof plan below.
- Proof plan for an index (state it in the case, run it only after James agrees): (a) the query's plan before and
  after on a copy of the table; (b) the query returns the same rows; (c) the tick budget passes the night after;
  (d) the query no longer appears in the next 7 days of the slow log. Undo: drop the index.
- The index itself follows the existing pattern (`EnsureCharacterSpellIndexes`: check, add once, log).
- **Class estimate:** the case file is documentation under `docs/agents/` (hard stop 6). An index on the
  characters database changes no rows, but it is patch night code (hard stop 5) and touches the characters
  database's structure: **HIGH, James merges**, one index per night.

### Step 3. An anchor robustness score, from history

- Create `scripts/anchor_history.py` (to be written; does not exist as of 2026-11-22) (Python, read-only): from git history, list every patch script changed in a
  commit whose message names a core or module update, and count per script how often it had to be re-fitted across
  the nine releases. Output a table: script, times re-fitted, last time.
- Use: the scripts re-fitted most often are the candidates for shorter, more structural anchors
  (`docs/agents/context/patches.md`, "What goes wrong most often", item 1). Each such rewrite is then proven with
  step 1's hash.
- Honest limit: commit messages are the only source, so the count is a floor. Say so in the output.
- **Class estimate:** LOW (read-only script and a table in a document).

Further candidates, not in the first three: settings that no longer exist in the configs (from
`settings-report.txt`'s "unknown"), settings identical to the current default, SQL files whose every row is
overwritten by a later file, patches whose target the core has since fixed (the build would already say so).

## 6. Milestone

**You have a result when**, within 45 days, three technical changes have been merged, each with an equivalence or
before/after proof that a reviewer re-ran and got the same answer: at least one patch tidy-up with **identical
tree hashes**, and at least one index whose query **left the slow log** for 7 days while the tick budget passed.

It is falsified if a change that passed its proof still altered behaviour (the proof method has a hole; find it
before using the method again), or if the hash is not stable between two runs on the same commit.

## 7. Known wrong paths and risks

- **"It's only a refactor."** Without the hash it is an unreviewed C++ change.
- **Indexes by intuition.** The one success came from reading why the query ran, not from adding indexes to slow
  tables. An index on a table bots write every tick can make things worse.
- **Consolidating patches for neatness.** One change per script with its own switch is what makes rollback and
  blame easy. Merge scripts only when the hash proves it changes nothing and the result is easier to port.
- **Looser anchors as "robust".** A looser anchor matches twice after an update. Robust means short, unique and
  structural.
- **Removing a "dead" setting** that the manager or an update would otherwise reset. The settings list exists
  because values went missing (`GameModes.Realm`, `MaxPlayerLevel` after the .95 update). Check the file's
  comment before calling a line dead.
- **Agents proposing a stream of small changes.** Each one costs James's review. Batch the findings into one case
  file; let him pick.
- **Calling a visible speed-up "no behaviour change".** Players notice speed. Say what they will notice.
- **Touching character or account rows.** Hard stop 7, whatever the motive.

## 8. Dependencies

Step 1 shares code with F1 step 1. Proofs for anything that runs on the server need F4's budget and F2's health
check and last-good pin. Step 3 feeds F11 (the patch porter starts with the most fragile scripts).
