# Proposed practices (not yet adopted by James)

Read this when James asks for process suggestions, when you are about to suggest a new rule, or when one of the
incidents below repeats.

**Status of everything in this file: Proposed practice (not yet adopted by James).** None of it is a rule of the project. James has said there are no
firm unwritten rules and that he is open to best-practice suggestions that come with a purpose. Each entry gives
the purpose, the incident in this repository's history that motivates it, the cost, and what adopting it would
change. Adopting any of them is James's decision; several touch hard stops 5 or 6 and so wait for him anyway.
Hashes can be read with `git show <hash>`. Facts are as of 2026-11-22.

---

## P1. Pre-flight gate before any PR touching `patches/` is merged

- **Proposal.** The PR description must include the output of applying every script in `patches/`, in name
  order, to the pinned sources of the current release, using the script files exactly as committed. No merge
  without it. Procedure and tooling: `wildcard-patch-authoring`.
- **Purpose.** A build takes 2 to 3 hours and fails late. An anchor or insert error can be found in minutes.
- **Incident.** `e0cc2f5` (21 Nov): patch 90 failed the build because its inserted text had no final newline. A
  local check had been run, but the check added the newline itself, so it tested something other than the
  committed script. Also `0220a49` (12 Nov) and `a4048e7` (16 Nov), compile errors found by the build.
- **Already in the documents.** `docs/agents/context/patches.md` says "test the script against the pinned sources
  before pushing". The proposal adds: make it a merge condition and show the output.
- **Cost.** Minutes per PR, plus a clone of the pinned sources. Applying scripts needs PowerShell.
- **Limit.** It catches anchors and broken inserts. It does not catch compile, link or start-up errors.

## P2. PR description template with the risk block

- **Proposal.** Add `.github/pull_request_template.md` (text below).
- **Purpose.** James reads the same items in the same order every time, and his requirement that MEDIUM and HIGH
  reviews show the reasoning for the category is met by filling in the form.
- **Incident.** None went wrong for lack of it. 205 PRs were merged with no classification because the matrix did
  not exist until 22 Nov.
- **Cost.** One file. It lives under `.github/`, next to the build workflow; treat adding it as James's call.

Template text: one copy only, in `wildcard-docs-and-publishing/references/templates.md`, template C (it carries
the analyst block from SKILL.md section 2, test evidence with a "not tested" line, a rollback line and a "needs"
line saying whether a build is required).

## P3. One behaviour change per PR, and a limit per night

- **Proposal.** Keep one change per PR (README already says so). Add a limit on what goes live per restart: at
  most one player-visible change classed MEDIUM or above per night; LOW changes and documents are not limited.
  Extra PRs wait, approved, and James merges them on following days.
- **Purpose.** When something is wrong in the morning there are few suspects. It also gives James a concrete
  option for settling the CHANGES.md sentence "one PR per patch night", which practice does not follow.
- **Incident.** 31 PRs merged on 8 Nov, 25 on 7 Nov, 23 on 21 Nov. On 21 Nov the lag spikes were under
  investigation (`6a3e017`, `9ba9f45`) while 23 other changes merged, which makes any before-and-after timing
  comparison hard to attribute.
- **Cost.** Slower delivery on productive days; someone has to keep the queue.
- **Not decided here.** Whether CHANGES.md or the README is right. That is James's call.

## P4. A lifecycle for experiment settings

- **Proposal.** When a setting is changed to test an idea, its comment in `server-settings.txt` carries: the
  date, who asked, the hypothesis, the number expected to move and by how much, and a review date. At review it
  becomes one of: adopted (comment rewritten as the reason), reverted, or retired with the result written in
  the comment or in `docs/performance.md`.
- **Purpose.** Experiments otherwise become permanent by neglect, and the result is lost.
- **Incident.** The bot count went 1,500 (#53), 1,250 (#57), 1,000 (9 Nov), 750 (#217, "while the spikes are
  worked through"), each with a reason but no stated exit. The MySQL slow-query log was added as "Temporary"
  (`cc145e5`, 8 Nov), removed six hours later once #84 fixed the cause (`ea01588`), and added again at a lower
  threshold on 21 Nov (`9ba9f45`). The first round is the lifecycle working; the proposal makes it routine.
- **Cost.** A few comment lines per experiment and a reminder. Method: `wildcard-analysis-and-method`.

## P5. A rollback note in every MEDIUM-or-above PR

- **Proposal.** Two lines: how to undo it, and how long until the undo is live (next restart, or rebuild plus
  patch night).
- **Purpose.** I3 (undo) is already scored; writing the answer down costs nothing extra and helps whoever is
  looking at a broken server.
- **Incident.** `d5412a9` (19 Nov): the Wildcard realm came up on the other realm's characters after patch night.
- **Cost.** Two lines per PR. Included in the P2 template (template C in `wildcard-docs-and-publishing`).

## P6. Branch hygiene

- **Proposal.** Turn on GitHub's "Automatically delete head branches", and delete the branches already merged.
- **Purpose.** Fewer stale branches to base work on or merge by mistake.
- **Incident.** 229 remote branches on 2026-11-22; 202 of them fully merged into `main`. The one branch accident
  on record (`3a64277`, 5 Nov) was a merge between two long-lived branches.
- **Cost.** One repository setting; a one-off deletion James approves. Deleting a merged branch loses nothing:
  the commits stay in `main`. Do not delete unmerged branches under this proposal.

## P7. Retire `for-083`

- **Proposal.** Once James confirms no server runs release .83, delete `for-083` and its five feature branches
  (`bots-attack-mercenaries-for-083`, `bots-resurrect-for-083`, `bots-team-opposing-083`, `free-training-083`,
  `scrolls-to-currency-for-083`) and shorten the README "Branches" section.
- **Purpose.** Remove the one branch that must never be merged.
- **Incident.** `ebc3c3d` (5 Nov). The README says the branch "goes away once the server moves to a newer
  release"; release tags since then are for .95, .112 and .114 (`git tag --sort=-creatordate | head`), and the
  last commit on `for-083` is dated 9 Nov.
- **Cost.** A README edit and six deletions. Consider tagging the branch tip first so it can be found again.

## P8. Snapshot before a HIGH change goes live

- **Proposal.** Take a Proxmox snapshot of the game VM before the restart that brings a HIGH change live, and
  keep it until the change has run for a day.
- **Purpose.** Some HIGH changes score I3 = 3 (cannot be undone). A snapshot makes them undoable, inside James's
  stated tolerance of about 15 minutes of data loss only if it is taken just before the restart.
- **Incident.** `d5412a9` (19 Nov). No snapshot rollback has ever been needed, so this is insurance.
- **Cost.** Disk space and a manual or scripted step on Proxmox; James's hands (hard stop 5). Procedure:
  `wildcard-run-and-operate`.

## P9. State ranges in setting comments

- **Proposal.** For each setting that is meant to be tuned, add an allowed range to its comment, for example
  "(tune 500 to 1,000)".
- **Purpose.** The standard-change rule pre-approves "a value change ... within the range its comment states".
  Without stated ranges almost no settings change qualifies, and every one must be scored.
- **Incident.** Scoring #217 (see `worked-examples.md`): the comment gives the reason and the old value, no range.
- **Cost.** One pass over about 270 setting lines (count: `wildcard-settings-and-flags`); James decides each range.

## P10. Clarify two sentences in the matrix

- **Proposal.** In `docs/agents/context/change-risk.md`: (a) say whether "a total within one point of a band
  edge" means totals 8, 9, 12 and 13, or 7 to 10 and 11 to 14; (b) say who reviews a HIGH change that does not
  touch `patches/` and is not security-adjacent, since the Fable `patch-reviewer` declines those.
- **Purpose.** Two analysts should reach the same answer.
- **Incident.** Found while scoring #217 and #186 for the worked examples.
- **Cost.** Two sentences. Editing the matrix is hard stop 6: it waits for James.

## P11. Nobody acts on the game VM, starts a rebuild or removes a release without James's say-so

- **Proposal.** No session starts, stops, installs, restores or hand-edits anything on the game VM, starts a
  workflow run with `rebuild` ticked, or deletes or drafts a release, unless James has said to. Read-only checks
  are not limited.
- **Purpose.** A merge is a deployment and there is no staging server. A finished build is a release the weekly
  patch night will install whatever branch built it.
- **What the documents say today.** Only the three agents in `.claude/agents/` are limited in writing (the analyst and the
  reviewer never merge, deploy or comment; `patch-night-checker` is read only). CHANGES.md says nothing is edited
  on the running server by hand. Nothing covers every session, and sessions do have VM access.
- **Incident.** `d5412a9` (19 Nov): patch night brought the Wildcard realm up on the other realm's characters.
  No incident of a session acting on the VM is recorded.
- **Cost.** Urgent fixes wait for James.

---

## Index of every proposal in the library (so James can accept or reject in one place)

**Indexed on 2026-11-22** by searching all 17 skills for "Proposed practice" and "not yet adopted"
(`grep -rnE "Proposed practice|not yet adopted" .claude/skills`). The detail, purpose and incident stay in the
home skill; this table only points. A proposal added or reworded in another skill after that date is not here
until the index is rebuilt: re-run the grep and compare. Ids are for this index only (skill letters + number).
"Same as" marks one proposal worded in more than one skill.

| Id | Proposal, in one line | Home skill (file) |
|---|---|---|
| P1-P11 | The eleven entries above (pre-flight gate, PR template, one change per night, experiment lifecycle, rollback note, branch hygiene, retire `for-083`, snapshot before HIGH, ranges in setting comments, clarify the matrix, James-only VM actions) | `wildcard-change-control` (this file) |
| CC-1 | Layer-by-layer reading of what earns L4 = 1 today | `wildcard-validation-and-qa` (SKILL.md, the L4 section); pointed to from change-control section 3 |
| AR-1 | The list of what counts as an outlier to take to James | `ascension-restoration` (SKILL.md section 1) |
| AR-2 | For every proc-type fix: one negative check and one check with the other learnable version of the ability | `ascension-restoration` (section 4) |
| AR-3 | Scratch-database "run it twice" procedure for enchant SQL | `ascension-restoration` (section 5) |
| AR-4 | Regenerate notes and history from `main` once more after the merge | `ascension-restoration` (`ascension-restoration/references/tracker-and-review-files.md`) |
| AC-1 | A change that spans layers ships in dependency order (SQL and settings, then patch, then client) | `wildcard-architecture-contract` (section 8) |
| AC-2 | Run `check_contract.py` before any PR touching `patches/`, `sql/` or `server-settings/` | `wildcard-architecture-contract` (section 8) |
| AC-3 | After the manager's Update, James runs `Run-PatchNight-Now.cmd` the same day (README says otherwise; not reconciled) | `wildcard-architecture-contract` (W5, V12, `references/weak-point-traces.md`); same as RO-3 |
| AC-4 | The patch-night checker treats any "Enchant fix ... failed" line as PROBLEM | `wildcard-architecture-contract` (`wildcard-architecture-contract/references/weak-point-traces.md`) |
| AC-5 | Only start the build workflow from `main` | `wildcard-architecture-contract` (`wildcard-architecture-contract/references/weak-point-traces.md`); same as BE-1 |
| BE-1 | Build only from `main`, after James has merged, and on his say-so (who starts a rebuild) | `wildcard-build-and-env` (rule 2) |
| BE-2 | Do not click the manager's Update until a `wcme-` build for the new release exists | `wildcard-build-and-env` ("After a new manager or CoA release") |
| BE-3 to BE-11 | Nine workflow changes: a fast "patches apply" job on every PR; syntax-only compile; keep going after the first compile error; compiler cache; incremental builds on the VM; upload the patched tree; draft releases for test builds; say so when a build fails; start the world once before publishing | `wildcard-build-and-env` (`wildcard-build-and-env/references/proposals.md`, items 1 to 9) |
| DP-1 | After "Patch night OK", still search the run for "failed:" and `[WARN]` | `wildcard-debugging-playbook` (Proposed practices); same as RO-1 |
| DP-2 | After merging `main` into a branch, diff the settings file and CHANGES.md and confirm your lines are there | `wildcard-debugging-playbook`; same as FA-3 |
| DP-3 | When a debugging session ends, add a row to the symptom table with the commit | `wildcard-debugging-playbook` |
| DP-4 | Before any `Restore-Official.cmd`, compare the saved official copy's revision with the auth server's | `wildcard-debugging-playbook` |
| FA-1 | Record an after-measurement next to every change made for performance | `wildcard-failure-archaeology` (SKILL.md) |
| FA-2 | An experiment setting carries its question and date, and later its answer | `wildcard-failure-archaeology`; same idea as P4 |
| FA-3 | After any merge, check for commits pushed to the branch after its PR merged | `wildcard-failure-archaeology` (`wildcard-failure-archaeology/references/unmerged-and-abandoned.md`) |
| PA-1 | New patch scripts use `Edit-Core` as scripts 83-96 do, never a `.Contains` check | `wildcard-patch-authoring` (section 3) |
| PA-2 | Make the pre-flight a required check on pull requests; until then paste its summary into every patch PR | `wildcard-patch-authoring` (section 13, `references/preflight-pr-check.workflow.yml`); same as P1 and BE-3 |
| SF-1 | Judge the settings report by "no NEW unknown name against the previous run", not "0 unknown" | `wildcard-settings-and-flags` (section 5); repeated in debugging, run-and-operate, diagnostics, validation |
| SF-2 | New options default to stock behaviour in code and are switched on in the settings file | `wildcard-settings-and-flags` (section 8a) |
| SF-3 | Pass every option name to `GetOption` as one whole string literal | `wildcard-settings-and-flags` (section 8a) |
| SF-4 | Keep `server-settings.txt` ASCII (a guard for trap 6) | `wildcard-settings-and-flags` (section 9) |
| SF-5 | Regenerate the settings catalogue only in a skill-maintenance PR; settings PRs run `--lint` | `wildcard-settings-and-flags` (maintenance rule) |
| RO-1 | After every run, search the run's log for `failed` and `[WARN]` | `wildcard-run-and-operate` (SKILL.md); same as DP-1 |
| RO-2 | Do not start `Run-PatchNight-Now.cmd` within an hour before a scheduled task time | `wildcard-run-and-operate` (SKILL.md) |
| RO-3 | After the manager's Update, James runs `Run-PatchNight-Now.cmd` the same day | `wildcard-run-and-operate` (`wildcard-run-and-operate/references/runbooks.md`); same as AC-3 |
| RO-4 | Snapshot the VM before a risky install | `wildcard-run-and-operate` (`wildcard-run-and-operate/references/runbooks.md`); same as P8 |
| VQ-1 | The evidence ladder and its four rules | `wildcard-validation-and-qa` (section 1) |
| VQ-2 | Acceptance thresholds per layer (the lag numbers are not here: see LC-2) | `wildcard-validation-and-qa` (section 3) |
| VQ-3 | A fixed format for a `tested` cell, and for recording results outside enchants | `wildcard-validation-and-qa` (section 7) |
| VQ-4 | Every incident becomes a row naming the cheapest check that would have caught it | `wildcard-validation-and-qa` (section 9, `references/regression-inventory.md`) |
| VQ-5 | After each SQL run, count rows in the tables the file touches; what a thorough enchant test covers | `wildcard-validation-and-qa` (`wildcard-validation-and-qa/references/how-to-test-each-layer.md`) |
| VQ-6 | The smoke-test design (NOT BUILT YET) and its thresholds | `wildcard-validation-and-qa` (`wildcard-validation-and-qa/references/smoke-test-spec.md`) |
| DT-1 | One instrument at a time, with an end date | `wildcard-diagnostics-and-tooling` (`wildcard-diagnostics-and-tooling/references/gaps-and-candidate-instruments.md`) |
| DT-2 | Candidate instruments C1 to C6 (record more often, core metrics, bot performance monitor, per-thread CPU, statement counts, awake-bot count) | `wildcard-diagnostics-and-tooling` (same file) |
| DT-3 | Extra fields for a `docs/performance.md` row | `wildcard-docs-and-publishing` (`wildcard-docs-and-publishing/references/templates.md`, template E); asked for by diagnostics and the campaign |
| DO-1 | When to add `Changelog: skip` or a player-facing `Changelog:` line | `wildcard-docs-and-publishing` (SKILL.md, section 4) |
| DO-2 | Templates C (PR description), G (incident review), H (upstream bug report) | `wildcard-docs-and-publishing` (`wildcard-docs-and-publishing/references/templates.md`); C is the same as P2 |
| DO-3 | When to report a bug upstream, who posts it, and recording the link in the CHANGES.md row | `wildcard-docs-and-publishing` (SKILL.md, upstream section) |
| CW-1 | Run `check_client_web.py` before every PR touching `launcher/`, `signup/`, `addon/` or `client-patch/` | `wildcard-client-and-web` (section 10) |
| CW-2 | Parse-check `launcher/*.ps1` in `FetchRepo` and keep the old copy on failure | `wildcard-client-and-web` (section 10) |
| CW-3 | Test a launcher change against a real client folder before merging | `wildcard-client-and-web` (section 10) |
| CW-4 | Change `TooltipData.lua` in the same PR as a twin link, and record how its data files are generated | `wildcard-client-and-web` (section 10) |
| CW-5 | Build client patches in a scratch folder outside the repository | `wildcard-client-and-web` (section 10) |
| CW-6 | Write PR titles (or a `Changelog:` line) for players | `wildcard-client-and-web` (section 10); same as DO-1 |
| CW-7 | Add a `.gitattributes` to fix line endings per file type | `wildcard-client-and-web` (section 10) |
| LC-1 | The rules of the campaign (one change per night, prediction written first, before/after protocol) | `wildcard-lag-spike-campaign` (SKILL.md) |
| LC-2 | The exit metric: the library's single home for lag pass/fail numbers | `wildcard-lag-spike-campaign` (SKILL.md, Phase 1 step 5) |
| LC-3 | Measure-only settings: `RecordUpdateTimeDiffInterval` shortened, or a spike-only log; timestamps on `Server.log` and `Playerbots.log`; `typeperf` at 1 s | `wildcard-lag-spike-campaign` (SKILL.md, `references/engine-and-timers.md`); overlaps DT-2 |
| LC-4 | The ladder for raising bots again (each step scored, not a standard change) | `wildcard-lag-spike-campaign` (SKILL.md) |
| AM-1 | Part B, the research method: evidence bar, predict numbers before running, adversarial refutation, one change at a time (B1 to B4) | `wildcard-analysis-and-method` (SKILL.md) |
| AM-2 | B5 to B7: idea lifecycle and retirement records, sources of ideas, patterns to avoid; note templates | `wildcard-analysis-and-method` (`wildcard-analysis-and-method/references/lifecycles-and-sources.md`, `references/templates.md`) |
| FR-1 | The suggested order of the first ten PRs, and what not to start yet | `wildcard-frontier` (SKILL.md) |
| FR-2 | F1 to F11: every "first three steps", milestone and wrong-paths block (C++ feedback, self-proving deploy, issue pipeline, lag budget, bots as testers, enchant restoration, re-balancing, retention, launcher, technical reviews, sustainability) | `wildcard-frontier` (`references/f01-...` to `f11-...`); F3's appendix is a design proposal, NOT BUILT YET |

Overlaps to settle together when James rules: P1 = PA-2 = BE-3; P2 = DO-2 (C); P4 = FA-2; P8 = RO-4; P11 = BE-1
= AC-5; DP-1 = RO-1; DP-2 = FA-3; AC-3 = RO-3; DO-1 = CW-6; LC-3 overlaps DT-2.

---

## How a proposal becomes a rule

1. James says yes, in chat or by merging a PR that writes it into `README.md`, `CHANGES.md` or `docs/agents/`.
2. The PR that writes it is classified like any other (most of these touch hard stop 5 or 6).
3. Move the entry out of this file and out of SKILL.md section 9, into SKILL.md section 5 or 6, citing the commit.
   For a proposal whose home is another skill, change its label there and drop its row from the index.
4. If James says no, keep the entry with "Declined by James on <date>: <reason>" so it is not proposed again.
