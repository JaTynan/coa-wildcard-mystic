# Wildcard skill library: start here

Seventeen skills for working on James's Wildcard server (`JaTynan/coa-wildcard-mystic`). Each lives in
`.claude/skills/NAME/SKILL.md`, with longer material in its `references/` folder and tools in `scripts/`.
Written 2026-11-22. This page is an index only: if it disagrees with a skill, the skill wins; fix this page.
It is not a skill itself (no frontmatter, never loaded automatically).

Three things to know before anything else:

1. **A merge to `main` is a deployment.** The server downloads `main` at every restart, and a merged
   `patch-night/` script runs the same night with no night of grace. James merges; nothing else does.
2. **Classify before you change.** Any step that changes what the server does goes through
   `wildcard-change-control` first.
3. **A build takes 2 to 3 hours and that is normal.** Catch the mistake before the build, not in it. A merged
   C++ patch is not built until the workflow is run with `rebuild` ticked, and only the weekly patch night (or a
   by-hand run) installs a build.

## Priority order (James's decision)

1. **Lag spikes.** Root cause UNKNOWN as of 2026-11-22. Start with `wildcard-lag-spike-campaign`.
2. **Pipeline, testing and validation.** The costliest ongoing failure is a build that fails late.
3. **Broken enchants.** Last.

## Status words (the same in every skill)

| Word | Means |
|---|---|
| DOCTRINE | Written in `README.md`, `CHANGES.md` or `docs/` on `main`. Follow it. |
| INTENDED DOCTRINE | Written in `docs/agents/*` or `.claude/agents/*`, which exist only in PR #232 (open and unmerged on 2026-11-22). The risk matrix, the hard stops and the agent roles are all in this group. |
| PRACTICE | What the git history shows people actually did. Useful, not binding. |
| NOT BUILT YET | Described in a document; no code or schedule exists for it. |
| Proposed practice (not yet adopted by James) | A suggestion made by a skill, with its purpose and the incident behind it. It becomes a rule only when James says so. The register of all of them is in `wildcard-change-control/references/proposed-practices.md`. |
| UNVERIFIED | Could not be checked; the text says how to check it. |
| OPEN | A question or a fix whose outcome is not known yet. |

Base of the checkout the skills were written from: `fcfee51` (PR #232's head: `62a26e4`, the #230 merge, plus two
commits adding `.claude/agents/` and `docs/agents/`). `origin/main` was `d3e030f` (#231).

## I want to... -> load this skill

| I want to... | Load | Then, if needed |
|---|---|---|
| Understand the project; I am new | `wildcard-architecture-contract` | the reading order below |
| Know whether a change may go in, its risk class, who approves | `wildcard-change-control` | |
| Handle a player's bug report or a GitHub issue | `wildcard-change-control` (section 4.2) | the skill for the layer the bug is in |
| Find out why something is broken (not lag) | `wildcard-debugging-playbook` | the layer skill it points to |
| Work on "the server is lagging", stutter, rubber-banding | `wildcard-lag-spike-campaign` | `wildcard-diagnostics-and-tooling` for the parsers |
| Measure something or read a server log | `wildcard-diagnostics-and-tooling` | |
| Check whether something was tried before, or why a value is what it is | `wildcard-failure-archaeology` | |
| Fix, test or record a Mystic Enchant, talent or racial; write `sql/enchants` | `ascension-restoration` | `azerothcore-coa-reference` for how spells work |
| Add, change or look up a setting (including bot chat and bot counts) | `wildcard-settings-and-flags` | `wildcard-lag-spike-campaign` first if it is for performance |
| "The bots talk too much" / "bot chat stopped" | `wildcard-settings-and-flags` (the `OllamaChat.*` settings) | `wildcard-debugging-playbook` for the symptom; `wildcard-patch-authoring` for the module fit patch |
| Write or port a C++ patch; the build stopped at "Apply our patch scripts" or "Apply our patches" | `wildcard-patch-authoring` | `azerothcore-coa-reference` |
| Start or watch a build; a build failed at any other step; "is my fix in a build?" | `wildcard-build-and-env` | |
| Know when a merged change goes live; patch night; restart; roll back; find a file on the VM | `wildcard-run-and-operate` | |
| Decide whether something is proven; run the checks before a PR | `wildcard-validation-and-qa` | |
| Write a commit message, PR text, doc or CHANGES.md row; check public-repo rules | `wildcard-docs-and-publishing` | |
| Launcher, download site, sign-up, status pages, addons, client patch, Report Bug relay | `wildcard-client-and-web` | |
| Look up an AzerothCore, CoA or bot term, table, hook or GM command | `azerothcore-coa-reference` | its `references/glossary.md` |
| Prove a cause or justify a number before changing anything | `wildcard-analysis-and-method` | |
| Decide what to build next; see what is NOT BUILT YET | `wildcard-frontier` | |

Requests that look alike:

- "It lags" goes to the lag campaign first; the diagnostics skill holds the measuring tools. "It crashed" or
  "it will not start" goes to the debugging playbook.
- "The build failed": at the step "Apply our patch scripts" or "Apply our patches" a patch no longer fits.
  `wildcard-build-and-env` says what failed and how to re-run; `wildcard-patch-authoring` fixes the script. At
  any other step use `wildcard-build-and-env`.
- "When does my change go live?" has one home: `wildcard-run-and-operate`, "When does my merged change go live?".
- "Is it laggy, pass or fail?" has one home: the proposed exit metric in `wildcard-lag-spike-campaign`
  (Phase 1 step 5). No other skill states lag numbers.
- "Which SQL files does deleting not undo?" has one home: `ascension-restoration`, section 5, item 3.

## The smallest safe path for common changes

| Change | Read | Run |
|---|---|---|
| A value change to a setting already in `server-settings.txt`, **inside the range its comment states** | `wildcard-change-control` section 2 ("Standard changes"); `wildcard-settings-and-flags` section 8 | `repo_lint.py --only settings`; `settings_change_report.py` |
| A setting whose comment states no range (the bot counts, for one) | Not a standard change: score it with `wildcard-change-control`; James merges | the same |
| A new enchant SQL file using an existing recipe | `ascension-restoration` sections 3, 5 and 8; `wildcard-change-control` section 2 | `enchant_sql_lint.py`, `repo_lint.py --only sql` |
| A C++ patch | `wildcard-patch-authoring` (all of it); `wildcard-change-control` section 2 | `preflight.py latest`, `check_patch_files.py`, `repo_lint.py` |
| Anything under `patch-night/`, `.github/`, `vm/`, `signup/`, `.claude/`, `docs/agents/` | `wildcard-change-control` section 2, step 1: these are hard stops and always wait for James | |

Every PR also needs its text written to the house style: `wildcard-docs-and-publishing` sections 3 to 5.
A settings PR does not touch `.claude/skills/`: generated reference files inside a skill are refreshed in a
skill-maintenance PR (hard stop 6).

## Reading order for a newcomer

About an hour. Read the SKILL.md only; open reference files when a task needs them.

1. `wildcard-architecture-contract`: what the system is and what must not break.
2. `wildcard-change-control`: sections 1 to 3 (what is doctrine, how to classify, what is not built).
3. `wildcard-run-and-operate`: patch night in one page, and when a merged change goes live.
4. `wildcard-build-and-env`: what a build is, and why a merged patch is not automatically built.
5. `wildcard-debugging-playbook`: the first five minutes.
6. `azerothcore-coa-reference`: section 1 and the glossary.
7. `wildcard-lag-spike-campaign`: the opening summary (the first-priority problem and what one day of data showed).
8. Then the skill for your task. The three marked ADVANCED (`wildcard-lag-spike-campaign`,
   `wildcard-analysis-and-method`, `wildcard-frontier`) assume the first six.

## Running the scripts

- From the repository root, on Linux or macOS: `python3 -I -B .claude/skills/SKILL/scripts/SCRIPT.py --help`
- On the game VM: `"C:\Games\CoA Server\Runtime\python\python.exe" -I -B PATH-TO-SCRIPT --help`. The skills are on
  the VM only once they are merged to `main` (patch night's download of `main`) or copied there by hand:
  `wildcard-diagnostics-and-tooling` section 1.
- All are Python 3 standard library only and read-only unless their `--help` says otherwise. Every one has
  `--help`, runs from any folder and leaves no `__pycache__`.
- Exit codes: 0 pass, 1 a check failed, 2 the tool could not run.
- `preflight.py` also needs PowerShell 7 (`pwsh`) and network access to GitHub.

## Pre-merge check set

The full table, with one authority per check and the exact command for each, has one home:
**`wildcard-validation-and-qa`, section 11, "The pre-merge check set".** In short:

| PR touches | Script | Authority for | Owning skill |
|---|---|---|---|
| Anything | `.claude/skills/wildcard-validation-and-qa/scripts/repo_lint.py` | general repository hygiene, CHANGES.md and settings coverage, static SQL rules | `wildcard-validation-and-qa` |
| Anything, before the push | `.claude/skills/wildcard-docs-and-publishing/scripts/public_repo_check.py` | public-repository rules | `wildcard-docs-and-publishing` |
| `patches/` | `.claude/skills/wildcard-patch-authoring/scripts/preflight.py` | "the patches apply" | `wildcard-patch-authoring` |
| `patches/*.patch` only | `.claude/skills/wildcard-build-and-env/scripts/check_patch_files.py` | a fast check of the `*.patch` files | `wildcard-build-and-env` |
| `server-settings/`, or a patch that reads a setting | `.claude/skills/wildcard-settings-and-flags/scripts/settings_catalogue.py` with `--lint`, and `.claude/skills/wildcard-settings-and-flags/scripts/settings_change_report.py` | settings | `wildcard-settings-and-flags` |
| `sql/enchants/` | `.claude/skills/ascension-restoration/scripts/enchant_sql_lint.py` | the reset and ownership model of `sql/enchants` | `ascension-restoration` |
| `launcher/`, `signup/`, `addon/`, `client-patch/` | `.claude/skills/wildcard-client-and-web/scripts/check_client_web.py` | launcher, site, addon and generated-SQL drift | `wildcard-client-and-web` |
| How layers connect | `.claude/skills/wildcard-architecture-contract/scripts/check_contract.py` | the architecture invariants (exits non-zero on FAIL) | `wildcard-architecture-contract` |

Not checks: `.claude/skills/wildcard-change-control/scripts/change_facts.py` is a classification helper (it never
passes or fails a change); `.claude/skills/wildcard-build-and-env/scripts/which_build.py` says whether a commit
is in a published build; `.claude/skills/wildcard-lag-spike-campaign/scripts/spike_gates.py` judges an evening's
`Timing.log` against the proposed lag exit metric.

None of these runs automatically as of 2026-11-22. Making any of them a required check means adding a workflow,
which is a hard stop: propose it to James, do not add it.

## The 17 skills, one line each

| Skill | One line |
|---|---|
| `wildcard-change-control` | The gate: hard stops, risk matrix, paths, the three sources of change, who merges, who may roll back, the register of proposed practices. |
| `wildcard-architecture-contract` | START HERE when new. The system on one page, why it is built this way, and the invariants that must hold. |
| `wildcard-debugging-playbook` | Symptom to layer to first check, for everything except lag. |
| `wildcard-failure-archaeology` | The dated record of what was tried, reverted or abandoned, and why. |
| `azerothcore-coa-reference` | How the game server works where this repository touches it; the glossary. |
| `ascension-restoration` | Restoring Mystic Enchants, talents and racials: sources, recipes, SQL rules (and the files the reset cannot undo), tracker, tests. |
| `wildcard-settings-and-flags` | Every setting: the file, the kit, the catalogue of options, how to add one. |
| `wildcard-build-and-env` | The 2 to 3 hour build: steps, failures, triggering, the build-once rule, what is in which build. |
| `wildcard-patch-authoring` | Writing and porting C++ patches, and proving they apply before pushing. |
| `wildcard-run-and-operate` | Patch night, the nightly restart, the go-live table, rollback runbooks, the VM file map. |
| `wildcard-diagnostics-and-tooling` | Measuring: every log and counter file, its format, and parsers for each. Reads only. |
| `wildcard-validation-and-qa` | What counts as proof, what has been tested, how to test each layer, the pre-merge check set. |
| `wildcard-docs-and-publishing` | Docs of record, house style, templates, public-repository rules. |
| `wildcard-client-and-web` | What friends touch: launcher, site, sign-up, status pages, addons, client patch, bug-report relay. |
| `wildcard-lag-spike-campaign` | ADVANCED. The step-by-step hunt for the lag spikes, with gates, experiments and the proposed exit metric. Root cause UNKNOWN. |
| `wildcard-analysis-and-method` | ADVANCED. Working a problem out on paper first; the evidence bar; how an idea becomes a change. |
| `wildcard-frontier` | ADVANCED. Open problems and the first three steps for each, lag first. All proposals. |

## Keeping this page right

```bash
# Every folder is listed here, and nothing listed is missing
ls -d .claude/skills/*/ | xargs -n1 basename | sort > /tmp/have.txt
grep -o '`[a-z]*-[a-z-]*`' .claude/skills/README.md | tr -d '`' | sort -u | grep -E '^(wildcard|ascension|azerothcore)-' > /tmp/listed.txt
diff /tmp/have.txt /tmp/listed.txt && echo "index matches the folders"
# Every script named on this page exists
grep -o '\.claude/skills/[a-z-]*/scripts/[a-z_]*\.py' .claude/skills/README.md | sort -u | xargs ls > /dev/null && echo "all scripts exist"
# The section numbers quoted above still match
grep -n "^### 4.2\|^### Standard changes" .claude/skills/wildcard-change-control/SKILL.md
grep -n "^## 8\. Checklists" .claude/skills/wildcard-settings-and-flags/SKILL.md
grep -n "^## 11\. The pre-merge check set" .claude/skills/wildcard-validation-and-qa/SKILL.md
grep -n "^## 5\. SQL file conventions" .claude/skills/ascension-restoration/SKILL.md
```
