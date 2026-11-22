# F11. Sustainability: upstream, a dead game's data, and surviving core updates

Everything under "First three steps", "Milestone" and "Wrong paths" is a **Proposed practice (not yet adopted by James)**.
Facts were checked on 2026-11-22. Classify every step with `wildcard-change-control` first.

## 1. Goal and owner

The server, and the record of how Ascension's systems worked, should outlive any one upstream repository, web
page or machine; and a CoA core update should be absorbed with little or no hand work. Owner: James (the "digital
archaeology" purpose) and the pipeline (the patch porter).

## 2. Where the project stands (2026-11-22)

What the project depends on that it does not control:

| Dependency | Used for | If it disappears |
|---|---|---|
| `Corfirean/azerothcore-wotlk-coa` (core), `mod-coa-playerbots`, `mod-coa-content-scaling`, `coa-server-build` | Every build, fetched by commit from GitHub at build time | No new builds. The installed program keeps running |
| `Zyth45/mod-playerbots` (SQUID), `Zyth45/mod-dungeon-clear` | The 750 bots, Dungeon Clear | Same |
| `DustinHendrickson/mod-ollama-chat` (pinned to one commit in the workflow) | Bot chat | Same |
| The CF-Server-Manager and its releases | Installs and updates the official server, MySQL, client; `scripts/resolve_release.py` reads its release to find the commits | No release to resolve; patch night's "which release is installed" still works locally |
| Boost 1.87 and MySQL 8.4.9 downloads | The build | The build's cache covers it until the cache key changes |
| The CoA client (about 45 GB) | Everything players see | One copy in `F:\CoAClient` on the VM, one archive on the seedbox (`launcher/README.md`) |
| The archived Ascension builder page (Wayback Machine capture of 14 June 2026) | The enchant tooltips: the main source for intended behaviour | A private copy is on the VM: `C:\Games\CoA Server\ascension-mystic-enchants.json` (`enchants/epic-notes-header.md`). It is Ascension's text, so it is deliberately not in this repository |
| The client's spell data | Effects, numbers, the enchants' own text | Inside the client |
| Players' memories, videos, the old wiki and forum | Behaviour the data does not show | Ascension's site and forums are already gone |

How a core update is handled today: the daily build fetches the manager's newest release; any patch whose anchor
no longer fits stops the build and names itself; someone re-fits it by hand and builds again. Nine manager
releases were built between 30 Oct and 19 Nov (tags `.83` to `.114`). A side branch (`for-083`) had to carry a
second set of patches for the server's then-current core for a while (`README.md`, "Branches"). The **patch
porter** (re-anchor patches after a core update; Sonnet first, Fable where core logic changed) is a Stage 2 row
in `docs/agents/README.md`: **NOT BUILT YET**.

What is archived on purpose: this repository (public), release zips of each build on GitHub, the per-enchant
notes with sources and assumptions (`enchants/*-notes.csv`, generated `*-notes.md`), VM snapshots on Proxmox.

## 3. Why the current approach falls short

- **Every build depends on six other people's GitHub repositories being there that day.** A deleted, renamed or
  made-private repository stops all new builds, and commits fetched by hash cannot be recovered from anywhere else.
- **The single most valuable research source is one JSON file on one VM**, plus a third-party web archive. The VM
  snapshots protect it only while the Proxmox host does.
- **The record of "why" is spread** over pull request descriptions on GitHub, commit messages, CSV notes and chat.
  Pull request text lives only on GitHub; the notes files quote some of it.
- **Core updates arrive every two or three days** and each can cost a hand re-fit plus a 2 to 3 hour build. The
  update of 10 Nov also silently reset a setting (`MaxPlayerLevel`, commit 2a033cd), and updates have added 49
  options that ran on defaults until someone looked (commit 6223bc8).
- **Nothing has ever been restored from the archive.** An archive that has not been restored from is a hope.
- **It is someone else's game.** The client and the tooltips cannot be published, so the public repository can
  never be the whole archive. What may be kept where is a rule from `wildcard-docs-and-publishing`, and it limits
  every option here.

## 4. This project's asset

- **Everything of James's is already in one repository**, re-applied from scratch each time. Given the upstream
  sources and the client, the server can be rebuilt from it.
- **Every build records its exact inputs**: `BUILD-INFO.txt` inside each release zip lists the commit of the core
  and every module, and `scripts/resolve_release.py` reproduces the lookup.
- **Each published build is itself an archive** of a working program for one core (40 of them by 21 Nov).
- **Patches name what they depend on.** An anchor is a statement "this exact upstream text must exist". That makes
  a core update's damage listable in minutes with F1's pre-flight, before any build.
- **The notes files already separate source, assumption and decision** for each legendary and epic enchant: the
  archaeology is written down in a form that survives without Ascension's text.
- **Proxmox snapshots and Ansible exist** (James's statement; not in this repository).

## 5. First three steps in this repo

### Step 1. An archive manifest, and a second copy of what is irreplaceable

- Create `docs/archive.md`: a table of every irreplaceable input, where its copies are, the date each copy was
  last checked, and what may and may not be public. At least: the builder JSON, the client archive, the upstream
  source at each commit the live server has run, the databases, the VM snapshot schedule, `signup-settings.json`
  (location only, never its content).
- For the upstream sources: keep a **mirror clone** of each of the six repositories on storage James controls
  (private, off GitHub or in private forks), refreshed after each build. This is the one item where a third
  party can remove something that cannot be re-made.
- For the builder JSON and the Wayback capture: a second copy off the VM.
- **Class estimate:** the document is LOW. The copies are actions on James's own storage, not repository
  changes; they need James, not a merge. Do not put any of the copied material in this public repository.

### Step 2. The core-update report (the porter's eyes, before the porter)

- Using the existing pre-flight (`wildcard-patch-authoring/scripts/preflight.py`): a workflow or a scheduled local run that, when the manager publishes
  a new release, applies the patches to the **new** commits and writes a report: which scripts fit, which fail and
  on what anchor, with the upstream diff of the file around each failed anchor. Also list config options the new
  release adds or changes (compare the `.conf.dist` files of the two commits).
- The report is the input a porter needs; James can also read it over coffee. No patch is changed by this step.
- **Class estimate:** read-only. As a workflow, hard stop 5 by caution: James merges.

### Step 3. The patch porter, proposing only

- Add `.claude/agents/patch-porter.md` (Sonnet) and a context pack: given one failed script and the report, it
  proposes a re-fitted anchor as a pull request, and must show the pre-flight passing and, where the inserted code
  is unchanged, say so. Where the upstream logic around the anchor changed (not just moved), it stops and writes a
  case file for Fable, as the roles table says.
- Every porter PR changes `patches/`, so it gets the `patch-reviewer` and James merges.
- **Class estimate:** the agent's instructions are hard stop 6 (HIGH, James merges). Each PR it opens is C++:
  MEDIUM at best today (F1 part 3).

## 6. Milestone

**You have a result when** a restore drill succeeds: on a machine that is not the VM, using **only** the archive
(mirrored sources, this repository, the client archive, a database dump), a server is built and started to "World
Initialized" on the current core, and the drill's time and missing pieces are written into `docs/archive.md`.
Target: within 60 days, and repeated once a year.

For core updates: **you have a result when**, for three manager releases in a row, the core-update report exists
within 1 hour of the release being detected, and at least two of the three need no hand-written anchor (either
everything fits, or the porter's proposal passes pre-flight and review unchanged).

It is falsified if the drill needs anything from GitHub's upstream repositories or from the live VM (the archive
is incomplete: add the missing piece and repeat).

## 7. Known wrong paths and risks

- **Publishing the archive to make it safe.** The client, its data files and Ascension's tooltip text must not go
  into this repository or its releases.
- **Vendoring upstream source into this repository.** It would make the repository huge, blur whose code is
  whose, and upstream licences differ (`launcher_bridge.py` is AGPL-3.0, noted in `README.md`). Mirror privately.
- **Freezing on one core for good.** Tempting after a painful update, but CoA's fixes stop arriving, and
  `CHANGES.md` relies on upstream fixing bugs so patches can be deleted.
- **Auto-merging porter output.** A re-fitted anchor that applies cleanly can still attach the code to the wrong
  place. Pre-flight proves it applies, not that it is right.
- **Treating the Wayback Machine as permanent.** Captures can be removed on request.
- **Trusting snapshots as the archive.** They live on the same host and hold everything or nothing.
- **Reporting CoA bugs upstream and forgetting them.** `CHANGES.md` says fixes that are really CoA bugs are worth
  reporting; when CoA fixes one, its patch stops fitting and should be deleted, not re-fitted. The porter must
  check for that case first.
- **An archive nobody has restored from.**

## 8. Dependencies

Steps 2 and 3 need F1 step 1. F10 step 3 says which scripts the porter should expect to fail most. Step 1 needs
nothing and is cheap: do it early. The publishing limits come from `wildcard-docs-and-publishing`.
