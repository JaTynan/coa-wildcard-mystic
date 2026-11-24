---
name: wildcard-patch-authoring
description: Writing, changing, porting and pre-flighting the server C++ patches of coa-wildcard-mystic - the patches/NN-name.ps1 scripts and *.patch files the 2-3 hour build applies to the CoA core and the bot modules. Load it before creating or editing anything under patches/, before pushing a branch that touches patches/, when the build stops at the step "Apply our patch scripts" or "Apply our patches", when a build log says "Core changed", "CoA changed", "SQUID changed", "was not found exactly once" or "no longer fits release", when a new CoA core release needs the patches re-anchored, or when mystic-enchants-scripts.patch must be regenerated. Covers the Edit-Core contract, choosing anchors, script order and numbering, where new code goes, the bots / Wildcard Hero class 10 / null / database / Windows-compile checklists, the CHANGES.md row, setting line and SQL companion, and scripts/preflight.py, which proves in about a minute, with no build, that every patch applies to the pinned sources.
---

# Wildcard patch authoring

A **patch** here is C++ that we add to somebody else's source code at build time. Nothing under `patches/` is
compiled as it stands: the build checks out CoA's code for one release, lays our edits on top, and compiles the
result. One build takes 2 to 3 hours on GitHub, and an edit that no longer fits is found partway into it. This
skill is how to write those edits so they fit, and how to prove that they fit in about a minute before you push.

All facts below were checked on 2026-11-22 against `origin/main` (`d3e030f`) and manager release
server-0.261119.114 (core c3f2fd4b2395, SQUID v3.0 4ef5ed9ebe75). File:line references to upstream code are for
those commits. `docs/agents/*` and `.claude/agents/*`
came with PR #232, merged on 22 Nov 2026 (`0802d4f`), and are on `main`: what rests on them is **DOCTRINE**.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Decide whether a change is a patch, a setting or SQL; understand the layers | wildcard-architecture-contract |
| Score the risk, find the path, know who may merge | wildcard-change-control |
| Add or change a setting, or find a setting's default | wildcard-settings-and-flags |
| Fix an enchant, talent or racial with data (SQL), or learn the restoration method | ascension-restoration |
| Understand AzerothCore/CoA internals (hooks, spell scripts, procs, the three databases) | azerothcore-coa-reference |
| Trigger or watch a build, or diagnose a build that failed after the patch steps (configure, compile, link, package). Tie-break for the two patch steps: that skill says what failed and how to rerun; this one fixes the patch | wildcard-build-and-env |
| Find out whether this patch or fix was tried before, and how it went | wildcard-failure-archaeology |
| Diagnose a symptom on the running server | wildcard-debugging-playbook |
| Test a built patch, or decide what counts as evidence | wildcard-validation-and-qa |
| Install a build, patch night, rollback | wildcard-run-and-operate |
| Change the client patch, addons, launcher or site | wildcard-client-and-web |
| Write the CHANGES.md row or PR text in house style | wildcard-docs-and-publishing |

## Start here

1. New patch: sections 2 to 8, then run the pre-flight (section 9) before you push.
2. Build stopped at "Apply our patch scripts" or "Apply our patches": section 9, then
   `references/reading-preflight-output.md`; after a core update, section 10.
3. Classify with wildcard-change-control before the pull request. James merges.

Any term not explained here: `.claude/skills/azerothcore-coa-reference/references/glossary.md`. Status words
(DOCTRINE, PRACTICE, NOT BUILT YET ...): wildcard-change-control, section 1.

## 1. The model in one screen

The build is `.github/workflows/build-worldserver.yml`, job `build`. The part that matters to a patch author:

The full step table has one home: **wildcard-build-and-env**, "The step sequence" (its numbers are used here).
Two of its steps apply our work:

- **Step 4, "Apply our patches"** (workflow lines 91-105): every `patches/*.patch`, in name order, with
  `git apply --check --whitespace=nowarn` then `git apply`, **inside `core/`**. The modules are checked out
  after it (steps 5 to 8).
- **Step 9, "Apply our patch scripts"** (lines 178-186): every `patches/*.ps1`, `Sort-Object Name`, run with
  PowerShell 7 (`pwsh`) **from the workspace root**; the first one that throws stops the build.

Consequences you must hold in your head:

- A `*.patch` file can only touch the core, and its paths start at the core's root (`a/src/server/...`). The
  modules do not exist yet when it is applied.
- A `*.ps1` script runs from the workspace root, so its paths start with `core/`: `core/src/server/...`,
  `core/modules/mod-playerbots/src/...`, `core/modules/mod-dungeon-clear/src/...`,
  `core/modules/mod-ollama-chat/src/...`. Modules that ship inside the core repository are patched the same way
  (`core/modules/mod-destiny-weaver/...` in script 95, `core/modules/mod-manastorm-endless/...` in 84).
- A script may build on text a `*.patch` added (64, 49 and 78 do). Never the other way round.
- Scripts are applied exactly once to freshly checked out sources. Many would insert their code a second time
  without any error if run twice (section 6).
- The CoA bots module and Content Scaling arrive after the scripts, and no script patches them.

## 2. Before you write a patch

1. **Does it need C++ at all?** A setting is applied at every server start and SQL at every start too; a patch
   needs a 2-3 hour build and scores highest for risk. Use the layer table in sibling skill
   **wildcard-architecture-contract** to choose; settings are in **wildcard-settings-and-flags**, enchant and
   spell data in **ascension-restoration**, C++ background (hooks, spell scripts, config API) in
   **azerothcore-coa-reference**.
2. **Classify with wildcard-change-control first.** A patch scores **L1 = 3** ("Server C++ (a patch)",
   `docs/agents/context/change-risk.md`, step 3). Check the hard stops there before anything else: a patch that
   gives gold, items, currency or XP outside normal play (hard stop 2), touches accounts, GM or console commands
   (1), or network setup (3) is HIGH and waits for James whatever it scores.
3. **Know who reviews and merges.** `docs/agents/README.md` sends any pull request that changes `patches/` to the
   `patch-reviewer` agent (Fable; `.claude/agents/patch-reviewer.md`; give it only the PR number). **James
   merges.** Do not merge your own patch PR.
4. **Branch.** One branch per change with its own pull request (README.md, "Branches"). `for-083` and `main` are
   never merged into each other. CHANGES.md also says changes go in as "one PR per patch night"; history shows
   many merged PRs on a single day. Both statements are true of the repository; wildcard-change-control is the
   home of that question.

## 3. Anatomy of a patch script

`patches/94-dungeon-finder-join-limit.ps1`, whole but for its shortened header comment, with what each part is for:

```powershell
# Find a Group did nothing (James, 21 November). The client asks to join with every dungeon in the chosen type: a
# ... (header: the symptom, who reported it and when, the cause, what the patch changes, any setting) ...
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'                    # every error ends the script, so the build stops

function Edit-Core($file, $anchor, $replacement, $what) {      # the helper, defined again in each script
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"     # whole file as one string, line endings to LF
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: the dungeon finder accepts up to 255 dungeons in one join request"   # shows in the build log
Edit-Core 'core/src/server/game/Server/Packets/LFGPackets.h' '        Array<uint32, 50> Slots;' `
    '        Array<uint32, 255> Slots;   // Wildcard: Random Classic Dungeon sends up to 126' 'the LFGJoin slot limit'
```

The larger scripts repeat that with three kinds of edit (read `patches/90-dungeon-clear-auto-start.ps1` or
`93-group-xp.ps1` as the model):

| Edit | Anchor | Replacement |
|---|---|---|
| Add an include | an existing `#include "X.h"` line with its line break | the anchor + your includes, **each ending in a line break** |
| Add a class or helper functions | the first line of an existing function, e.g. ``"void AddSC_dungeon_clear_module()`n{`n"`` | your code + the anchor (your code lands in front of it) |
| Register the class | an existing registration line, e.g. ``"    new DungeonClearLateJoinerScript();`n"`` | the anchor + your `new ...();` line |

PowerShell you need and no more:

- `` `n `` inside double quotes is a line break; inside single quotes nothing is special.
- `@'` ... `'@` is a **here-string**: literal text over several lines. The closing `'@` must start its line. The
  text does **not** end with a line break: if the last line must be a complete line, leave an empty line before
  `'@` (the 21 November build failure, section 8).
- An argument that is an expression needs brackets: `Edit-Core $file $a ($a + @' ... '@) 'what'`.
- `.Replace(old, new)` replaces **every** occurrence. That is why the check is "exactly once".

### The Edit-Core contract

`Edit-Core $file $anchor $replacement $what` (scripts 83-88 and 90-96, word for word the same but for the first
words of the error):

- `$file`: path from the workspace root. It must exist (a missing folder gives a PowerShell path error, not an
  anchor error).
- `$anchor`: literal text, matched case-sensitively, that must occur **exactly once** in the file after its line
  endings are turned into LF. Zero or two matches throws.
- `$replacement`: the text that takes the anchor's place. To insert, include the anchor in it.
- `$what`: plain words naming the place ("the mailbox listing in WorldSession::HandleGetMailList"). It is all a
  reader of a failed build log gets: `Core changed: <what> was not found exactly once in <file>`. Use
  `SQUID changed:` when the file is in mod-playerbots (script 96 does). All anchor error texts in use:
  `Core changed:`, `CoA changed:`, `SQUID changed:`, `SQUID's bots changed:` (script 87), `mod-ollama-chat
  changed:`, and `Battleground Spoils part missing or core changed` (script 40).
- The file is written back whole, LF only, no byte added at the end.
- The anchor itself is **not** LF-normalised. The repository stores scripts with LF, so a multi-line here-string
  anchor matches. Save a script with Windows line endings and that anchor never matches: tested on 2026-11-22, a
  CRLF copy of script 95 failed with a misleading "Core changed". Keep scripts LF.

Older scripts do the same job differently; do not copy their weaker forms into new work:

| Scripts | Form | Note |
|---|---|---|
| 10-82 (most) | `& { ... }` blocks with inline `Get-Content` / check / `Set-Content`; errors `Core changed:`, `CoA changed:`, `SQUID changed:`, `mod-ollama-chat changed:` | 44 checks are `.Contains(...)`: "at least once", so a second match would be replaced too |
| 45, 49 | `Edit-Anchored $file $old $new $what` | as Edit-Core, and it also LF-normalises the anchor |
| 66 | `Edit-Anchored $file @( ,@(old, new) )` | a list of pairs for one file |

**Proposed practice (not yet adopted by James):** new scripts define and use `Edit-Core` exactly as 83-96 do,
never a `.Contains` check. Purpose: one error format and a real uniqueness check. Motivation: `.Replace` changes
every match, and an anchor that has become two places after a core update would be edited twice without a word.

The full per-script table (style, files, dependencies, companions) is `references/patch-catalogue.md`: read it
before you add to an existing script or anchor in a file another script already edits.

## 4. Choosing anchors

The anchor is the only thing tying your code to code that changes every week. Between the two newest cores
1,403 files differ and every one of our anchors still fits; against the three-week-old .83 core 29 of 56 scripts
fail. A good anchor fails when, and only when, the code it depends on has really changed.

Rules:

1. **Short**: one to three lines. Every extra character is another thing upstream can change.
2. **Unique**: exactly one match in the file. Check before you write the script:
   `grep -c -F 'your anchor line' <kept workspace>/core/path/to/File.cpp`.
3. **Structural**: a function's opening line, a registration line, a declaration, an include. Not a comment, not
   wrapped argument lists, not a list of values.
4. **Close to the thing you depend on.** If your code needs variable `m` to be in scope, the anchor should be the
   line that proves it is.
5. **Say what it is** in `$what`, in words a non-programmer can read in a build log.

| Verdict | Real anchor | Why |
|---|---|---|
| Good | `'        Array<uint32, 50> Slots;'` (94) | one line, and it is the very thing being changed: if upstream fixes the limit itself, the patch stops fitting and can be deleted, as CHANGES.md intends |
| Good | ``"void AddSC_AscensionAdventurerCache()`n{`n"`` (22 scripts) | a function opening; survives its own edits, so many scripts share it |
| Good | ``"    new DungeonClearLateJoinerScript();`n"`` (90) | a registration line with its indentation |
| Fragile, and it broke | ``"bool Unit::CanDefendDuringChannel() const`n{`n"`` (60) | upstream added a parameter to the signature. Commit c4b6718 made the script accept either form ahead of the release |
| Fragile, and it breaks | `'id == 271942 \|\| id == 275097;'` (65) | a list of spell ids that upstream extends; it does not fit the .83 core |
| Fragile, and it broke | "exactly 3 occurrences of `victim->IsNonMeleeSpellCast(false, false, true)`" (60, before c4b6718) | counting repeats of a common expression |
| Fragile | the comment `//called when player lists his received mails` inside an anchor (85) | comments get reworded or removed |
| Fragile | whole wrapped statements and lambdas (20: three lines of `HasReadyAbility(...)`) | re-wrapping the same code breaks it |
| Different failure | a new file written into `core/modules/mod-playerbots/src/Ai/Coa/Social/` (96) | the folder does not exist in SQUID v2.9.4: a path error, not an anchor error |

What upstream changes most, from this repository's own failures: function signatures gaining parameters
(c4b6718), lists of ids and allowlists (65), whole files and folders appearing or moving between SQUID versions
(96), and method names (`IsHeadless` became `IsBot`, script 10).

## 5. Order, numbers and names

- Name: `NN-lower-case-words.ps1`, two digits. Order is `Sort-Object Name`.
- As practised: 10 mod-ollama-chat, 20 bots, 30 Wildcard rewards, 40 battlegrounds, then 45 to 96 in the order the
  scripts were written. No number is used twice on `main`. CHANGES.md lists them in no particular order.
- **Take the next free number at the top and never renumber** (PRACTICE: no script on `main` has ever been
  renamed; no document states it). As of 2026-11-22 that is **97**; only 97, 98
  and 99 are left. A three-digit name does not sort after 99: PowerShell puts `100-new.ps1` straight after
  `10-...ps1` and before `20-bots.ps1` (tested with pwsh 7.4.6). **Open: what follows 99 is a decision for
  James. Raise it; do not invent a scheme.** The gaps (11-19, 21-29, 31-39, 41-44) are free, but a script placed
  there runs before 45-96 and cannot build on them.
- Check other branches before you take a number. `origin/bot-group-xp` holds `57-bot-group-xp.ps1`, and `main`'s
  57 is `57-racial-ambush.ps1`:
  `for b in $(git branch -r | grep -v HEAD); do git ls-tree --name-only $b patches/; done | sort -u`
- **Dependencies are by position, and the scripts say so.** 21 scripts need `40-battlegrounds.ps1` (it adds the
  includes and the registration line they anchor on in `AscensionAdventurerCache.cpp`); 51 needs 48; 57 and 58
  need 54; 91 needs 45's `WeekendBonus.h`; 87 relies on 83's behaviour; 64 needs two `*.patch` files. When your
  script builds on another, write it in the header comment and in the error text, as they do:
  `"Core changed (or 40-battlegrounds.ps1 did not run): ..."`.
- **Adding to an existing script** is normal for a closely related change (20, 30 and 40 each hold several
  parts). A new, separate feature gets a new script.
- **Removing a change**: delete its part from the script (CHANGES.md, "Code patches"), then run the pre-flight:
  a later script may anchor on what you removed.

## 6. Where new code goes

| You are adding | Put it | Real example |
|---|---|---|
| A script class (PlayerScript, AuraScript ...) for core behaviour | in front of `void AddSC_AscensionAdventurerCache()` in `core/src/server/coa/AscensionAdventurerCache.cpp`, registered after `    new world_pvp_kill_xp();` | 93, 55 |
| Per-player state (a timer, a counter) | public members after `explicit Player(WorldSession* session);` in `Player.h`, named `Wcme...`, with an initial value | 90: `uint32 WcmeDcAutoTimer = 0;` |
| A helper used by one `.cpp` | `static` functions in front of the first function that uses them | 85: `WcmeSpentSystemMail` |
| A header of your own | a new file written whole, next to the files that include it, in a folder already compiled | 45 `WeekendBonus.h`, 96 `WildcardBotCommand.h`, 10 `mod-ollama-chat_quiet.h` |
| A Mystic Enchant's own C++ | `src/server/coa/WcmeEnchantScripts.cpp`, which exists only as `patches/mystic-enchants-scripts.patch` | section 11 |

Write a new header like this (script 96): `Set-Content "$dir/Name.h" $header.Replace("`r`n", "`n") -NoNewline`.
No script adds a `.cpp` file. Names: `Wcme...` or `wcme_...` for our classes, members and functions, a
`// Wildcard:` comment on inserted lines, and `(patch NN)` where another script will want to find you.

**Settings.** Read with `sConfigMgr->GetOption<T>("Group.Name", default)`. Give every new behaviour a setting
where practical (CHANGES.md, "How changes are made"), with a default that keeps the stock behaviour unless James
asked otherwise. Each call builds a name, looks the option up and parses text (core
`src/common/Configuration/Config.cpp:554`), so on a path that runs every tick or every packet, gate it behind a
timer first (script 90 reads its setting once every 2 seconds per player) or read it once. Names, defaults, which
config file, and the checklist for adding one: **wildcard-settings-and-flags**.

## 7. The three things that ship with a patch

A patch PR that lacks any of these is not finished:

1. **A row in `CHANGES.md`**, table "Code patches": `` | `NN-name.ps1` | what players notice, in plain words | `Setting.Name` or `always on` or `—` | ``.
2. **A line in `server-settings/server-settings.txt`** for each setting, with the comment block the file uses:
   date, who asked, the patch file, what the values mean, and when the server reads it. Real example:
   ```
   # Starts by itself (21 Nov, James; patches/90-dungeon-clear-auto-start.ps1): once the party's tank bot is in a
   # dungeon with you, the run starts and a chat line says how to turn it off (dc off) and on (dc on). 0 = only by hand.
   modules\mod_dungeon_clear.conf | DungeonClear.AutoStart = 1
   ```
3. **The SQL companion, if the C++ does nothing without data.** A spell or aura script runs only when a row binds
   it. `55-talent-fixes.ps1` (the class `spell_wcme_backdraft`) is paired with `sql/enchants/140-talent-fixes.sql`;
   the racial scripts with `150-custom-spells.sql`, which is written by `client-patch/custom_spells.py`; 82 with
   `160-rune-currency.sql`; the enchant scripts with `017-enchant-scripts.sql` onward. Name the companion in the
   script's header comment. SQL is applied at every server start, the C++ only once a build with it is installed:
   say in the SQL file and the PR which build the rows need (the enchant notes do: "needs the build with this
   version of mystic-enchants-scripts.patch"). File conventions and the reset file: **ascension-restoration**.

House style for the row and the commit message: **wildcard-docs-and-publishing**. Public repository: no secrets,
no client data, no client tooltip text copied word for word.

## 8. Mandatory checklists

Go through every list for every patch. Put the answers in the PR description; the reviewer checks the same
things in the same order (`.claude/agents/patch-reviewer.md`, step 4).

**A. Bots.** About 750 random bots are players as far as the core is concerned: every player hook you write runs
for them.

- [ ] Rewards, mail, whispers, chat lines, leaderboards, database rows: skipped for bots? The guard the patches
      use in core code is `!player->GetSession() || player->GetSession()->IsBot()` (core
      `WorldSession.h:1301`; scripts 40, 45, 46, 47, 48, 49, 51, 90).
- [ ] In mod-playerbots code: `GET_PLAYERBOT_AI(player)` (null for a real player), `IsRealPlayer(player)`
      (`PlayerbotAI.h:84`), `botAI->HasGameClientMaster()` (a bot a real player controls),
      `IsWildcardHeroBot(bot)` (`Ai/Class/Coa/CoaWildcard.h:34`), `IsSelfBot(player)`.
- [ ] Decided on purpose for each of: a real player, a player's own bots and alts, random bots? (Script 93 counts
      bots as group members on purpose and says so.)
- [ ] Runs 750 times? Anything in `OnPlayerUpdate` runs every tick for every bot. Count a timer first, return
      early, then do the work (90, 54, 73, 74).

**B. Wildcard Heroes are class 10.** `CLASS_HERO = 10`; the CoA classes are 12 to 32 (core
`src/server/shared/SharedDefines.h:158-180`).

- [ ] No table, switch or range over classes that has no row for 10. `IsAscensionClass(classId)` is true only for
      12-32, and `GetLegacyClassForCustomClass(CLASS_HERO)` answers `CLASS_DRUID`, so a formula that falls back
      on it treats a Hero as a Druid (`SharedDefines.h:189-206`).
- [ ] No `getClass() == CLASS_X` test that a Hero with that ability should pass. Real example: the core lets
      only `CLASS_GUARDIAN` hold a two-hander with a shield (the anchor of script 67), so a Hero needs the
      enchant's own check.
- [ ] Use `AscensionWildcard::IsWildcardHero(player)` (`AscensionWildcard.h:531`) when you mean "a Wildcard
      character".
- The context pack names "the shield and stance bug of 22 Nov" as the case behind this rule
  (`docs/agents/context/patches.md:25`). No commit, fix or description of it is in the repository as of
  2026-11-22. UNVERIFIED beyond that one line; ask James, or search later:
  `git log --all -i --grep='shield\|stance' --since=2026-11-22`.

**C. Null and lifetime.**

- [ ] Checked before use: `GetSession()`, `GetMap()` / `FindMap()`, `GetGroup()`, `GetPet()`, a spell's caster
      and target, `sObjectMgr->Get...Template(...)`. Script 93's first lines are the model.
- [ ] No pointer kept across a tick, a teleport or a logout. Keep the `ObjectGuid` and look it up again (script 30
      re-finds the item by GUID inside its delayed event).
- [ ] No `ASSERT` on something a bot or a client can cause (script 81 exists because one stopped the server).

**D. Database.**

- [ ] No query per tick, per hit or per packet. Load at login or start-up, keep in memory, write on change (47,
      49, 51).
- [ ] Synchronous `Query` only at start-up or login; writes with `Execute` (queued).
- [ ] Our own tables are named `wcme_...`; a table the core, the auction bot or the manager also writes is not
      ours to change. Deleting or rewriting character or account rows is hard stop 7.

**E. Client and server.** The client has its own copy of spell data, tooltips, cooldown rules and enchant lists.

- [ ] Does the client refuse or show something different? Script 52 (racials off the global cooldown) needed the
      same change in `client-patch/racials.py`. Hand-off: **wildcard-client-and-web**.
- [ ] New spell ids for icons or buffs come from `client-patch/custom_spells.py`, which also writes
      `sql/enchants/150-custom-spells.sql`.

**F. It must compile with MSVC on Windows**, and you cannot compile it here.

- [ ] No identifier that `<windows.h>` defines as a macro: `SYNCHRONIZE`, `DELETE`, `ERROR`, `IGNORE`,
      `OPTIONAL`, `IN`, `OUT`, `min`, `max` ... A constant named `SYNCHRONIZE` failed the build of 16 November
      (commit a4048e7; renamed `SYNCHRONIZE_SPELL`).
- [ ] Every inserted block ends where you think it ends. An include list without a final line break joined the
      next `#include` onto the same line; MSVC ignored it (warning C4067) and the build of 21 November failed
      on an undeclared name (commit e0cc2f5).
- [ ] Names fully qualified and headers included. `ChatCommandTable` lives in `Acore::ChatCommands` (build
      failure of 12 November, commit 0220a49). Add the `#include` for every type you use; a precompiled header may
      hide a missing one in one file and not in another.
- [ ] Nothing that lengthens the compiler's command line: do not add include folders or modules. The compiler's
      include list already passed Windows' limit once ("CreateProcess: The parameter is incorrect", 19 November;
      the workflow now forces response files, lines 255-259). Build settings: **wildcard-build-and-env**.
- [ ] Scripts saved with LF line endings, UTF-8.

## 9. Pre-flight: prove it applies before you push

`scripts/preflight.py` lays the sources out exactly as build steps 2 to 9 do (section 1), at the release's pinned
commits, and applies every `*.patch` and every script in the build's order. It compiles nothing and runs no
upstream code. It never writes to the repository: it works on a copy of `patches/` in a scratch folder.

`preflight.py` is the **authority for "the patches apply"** (the fast `*.patch`-only check is `check_patch_files.py`
in wildcard-build-and-env; the full pre-merge check set is in wildcard-validation-and-qa).

**Verified baseline, 2026-11-22:** all 5 `*.patch` and all 56 scripts apply to server-0.261119.114; the text
check finds nothing; 47 to 93 seconds on a 2-CPU Linux machine.

```bash
cd <repo>
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py            # newest release
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py server-0.261119.114
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest --keep --workspace /tmp/wc
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest --stop-after 55
python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest --fail-fast
```

| Option | Use |
|---|---|
| `--keep` (with `--workspace DIR`, outside the repository, empty) | keep the patched sources to read: your inserted code in place, and the upstream code you need for the next anchor |
| `--stop-after NN` | run scripts up to and including NN. There is no "only NN": a script cannot run without the ones before it |
| `--fail-fast` | stop at the first failing script, as the build does. Default: carry on and list every failure |
| `--no-scripts` | stop after the `*.patch` files (section 11) |
| `--patches DIR` | test a scratch copy of `patches/` instead of the repository's |
| `--json FILE` | results as JSON (outside the repository) |
| `--no-cache` / `--cache DIR` | fetched commits are kept in `~/.cache/wildcard-preflight` (about 500 MB after four releases) |

Needs `python3`, `git` and **PowerShell 7** (`pwsh`), the shell the build uses. Windows PowerShell 5.1 is refused.
Without `pwsh` on a Linux machine, no root needed (this is how it was run on 2026-11-22):

```bash
mkdir -p ~/tools/pwsh && cd ~/tools
curl -sSL -o pwsh.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/powershell-7.4.6-linux-x64.tar.gz
tar -xzf pwsh.tar.gz -C pwsh && chmod +x pwsh/pwsh
export PREFLIGHT_PWSH=~/tools/pwsh/pwsh
```

On the Windows VM: UNVERIFIED as of 2026-11-22 (the script was written to be portable but has only been run on
Linux). Check `pwsh -v`, `python --version` and `git --version` there first.

**Reading the result.** Exit code 0 = PASS, 1 = something would fail the build, 2 = the pre-flight could not run
(that is "not tested", never a pass). Per script you get `OK name (N file(s))` or `FAIL name at file:line` and
the script's own error text, the same text the build log would show. Then the text check, then
`git diff --stat` per source tree, then a summary. Annotated real outputs, including how to tell a root failure
from a knock-on: `references/reading-preflight-output.md`. Read it the first time you see FAIL.

The **text check** is a few pattern checks on the C++ files that were touched, not a compiler. It reports:
text glued to an `#include` line and unbalanced brackets (ERROR, fails the run), mixed line endings and
Windows macro names used as identifiers (WARNING). It catches the 16 and 21 November build failures when they
are put back in a scratch copy. A `*.patch` whose `@@` count is stale is a FAIL (section 11).

**What PASS means:** every edit lands. **What it does not mean:** that the code compiles, links, starts or
behaves. Say exactly that in the PR: "Pre-flight PASS against server-0.261119.114 (5/5 patches, 57/57 scripts);
not compiled."

A real compile check without the full build is a **candidate, not built**: `g++ -fsyntax-only` on one patched
file stopped here at the first missing dependency (`boost/container/flat_map.hpp`), and it would need Boost,
MySQL and OpenSSL headers plus a CMake configure, and would still not be MSVC. Two commit messages claim a local
syntax check (273d36d, e0cc2f5) without recording how it was done.

The loop while writing:

1. `preflight.py latest --keep --workspace /tmp/wc` once. Read the upstream code under `/tmp/wc/core`.
2. Pick the anchor; `grep -c -F '<anchor line>' /tmp/wc/core/<file>` must print 1. That workspace holds the
   sources after every existing script has run, which is what a new highest-numbered script will see.
3. Write the script. Run `preflight.py latest --stop-after NN` (your number) until it is OK, then a full run.
4. Read your code in place in a kept workspace, in its surroundings: indentation, scope, the line before and
   after. Then the checklists of section 8.

## 10. Porting after a core update

A new manager release changes the commits `scripts/resolve_release.py latest` returns, and the daily build
(03:17 UTC) builds it with whatever is on `main`. The job called "patch porter" in `docs/agents/README.md` is
Stage 2 and **NOT BUILT YET**: today this is done by hand, like this.

1. `preflight.py latest` (or the new tag by name). PASS: nothing to port.
2. FAIL: sort the failures (`references/reading-preflight-output.md`, part 4): `*.patch` files first, then the
   lowest-numbered script whose message does not name an earlier script. Fix one, run again; knock-on failures
   disappear by themselves.
3. For each root failure, look at what upstream did to that place. The cache holds both cores:
   ```bash
   C=~/.cache/wildcard-preflight/Corfirean__azerothcore-wotlk-coa.git
   git -C $C diff <old core sha> <new core sha> -- src/server/game/Entities/Unit/Unit.cpp
   git -C $C grep -n 'CanDefendDuringChannel' <new core sha> -- src/server
   ```
   (old sha: `python3 -I scripts/resolve_release.py server-0.261119.114` prints `core_sha=` for any release;
   our builds are tagged `wcme-<release>-buildNN`, see `git tag -l 'wcme-server-*'`).
4. Decide which case it is:
   - **The text moved or was re-worded, the logic is the same**: re-anchor. If the patch must fit both the old
     and the new core for a while, accept either form, as commit c4b6718 did for script 60.
   - **Upstream fixed the same thing**: delete our part and its CHANGES.md row (CHANGES.md, "How changes are
     made": "its patch stops fitting, the build says so, and we delete it").
   - **The logic itself changed** (a function was split, a rule now works differently, our inserted code would
     compile but mean something else): stop. Do not force the anchor. Write it up as a case file
     (`docs/agents/case-file-template.md`) for a Fable ruling, as `docs/agents/README.md` assigns
     ("Fable takes the ones where core logic changed"), and tell James.
5. A re-anchored patch is a patch change: classify with wildcard-change-control, pre-flight PASS in the PR,
   reviewer, James merges. Why `main` and `for-083` carry different patches: **wildcard-build-and-env**.

## 11. The `*.patch` files

Five ordinary `git diff` files against the core; no two touch the same file. `mystic-enchants-scripts.patch` is a
single new file, `src/server/coa/WcmeEnchantScripts.cpp`, kept only as this patch. **Regenerate, never hand-edit:**
a stale `@@` line count makes `git apply` silently drop the file's last line (the pre-flight fails such a patch).
The regenerate commands and the reason: [references/patch-files.md](references/patch-files.md); read it before
changing any `*.patch` file.

## 12. After the pre-flight passes

1. Open the pull request: what and why in plain words, the checklist answers, the pre-flight line, the
   risk class from **wildcard-change-control**. The patch reviewer reads it; James merges.
2. The build runs daily, or by hand with "rebuild" ticked (how to trigger and watch it, and the catalogue of
   build failures by step: **wildcard-build-and-env**). A build is 2 to 3 hours by design.
3. A built patch is still untested. What counts as tested, how to test in game, and how to record it:
   **wildcard-validation-and-qa**. Installing and rolling back: **wildcard-run-and-operate**.

## 13. Proposal: make the pre-flight a required check on pull requests

**Proposed practice (not yet adopted by James).** Purpose: no pull request that touches `patches/` can be merged
while a patch does not apply. Motivation, stated exactly: the context pack's rule "test the script against the
pinned sources before pushing" (`docs/agents/context/patches.md`). The record holds five compile-step build
failures and one start-up failure, **none recorded as a pure anchor failure**. What the pre-flight is shown to
catch, on scratch copies with the old bugs put back: its text check flags the 21 Nov glued `#include` (`e0cc2f5`)
as an ERROR and the 16 Nov `SYNCHRONIZE` macro name (`a4048e7`) as a WARNING
(`references/reading-preflight-output.md`, part 5). It compiles nothing, so other compile, link and start-up
errors still need the build.

The ready-to-use workflow is `references/preflight-pr-check.workflow.yml` (`ubuntu-latest`, read-only token,
about two minutes). It is **not** under `.github/` and must not be put there by an agent: adding a workflow is
hard stop 5, so it waits for James, who would also have to mark the check as required in branch protection.
Status: written, never run on GitHub. Until then, also proposed and not adopted: paste the pre-flight's summary
lines into every patch PR.

## Provenance and maintenance

Written 2026-11-22 from: `.github/workflows/build-worldserver.yml`, all 56 `patches/*.ps1` and 5 `*.patch`,
`CHANGES.md`, `README.md`, `docs/agents/*`, commit history, and the upstream sources at the commits of
server-0.261119.114. The pre-flight was run on 2026-11-22 against releases .114, .112, .95 and .83 and against six
deliberately broken scratch copies of `patches/`.

Re-verify what drifts (run from the repository root):

| Fact | Command |
|---|---|
| The baseline still passes | `python3 -I .claude/skills/wildcard-patch-authoring/scripts/preflight.py latest` |
| The workflow steps the pre-flight mirrors | the pre-flight prints a WARNING when the step names of job `build` differ from its list; then re-read `build-worldserver.yml` against `MIRRORED_STEPS` in `preflight.py` |
| Step line numbers in section 1 | `grep -n "name: \(Apply our\|Core at\|Place the\)" .github/workflows/build-worldserver.yml` |
| Script count and next free number | `ls patches/*.ps1 \| wc -l; ls patches \| grep -o '^[0-9]*' \| sort -n \| tail -1` |
| Numbers used on other branches | `for b in $(git branch -r \| grep -v HEAD); do git ls-tree --name-only $b patches/; done \| sort -u` |
| Which scripts define which helper | `grep -n "^function " patches/*.ps1` |
| Error texts | `grep -ho "throw [\"'][A-Za-z' -]* changed" patches/*.ps1 \| sort \| uniq -c` (six texts with the Battleground Spoils one: `grep -n "part missing or core changed" patches/*.ps1`) |
| `.Contains` checks left | `grep -c "Contains(" patches/*.ps1 \| awk -F: '{s+=$2} END {print s}'` |
| Scripts stored with LF | `git ls-files --eol patches \| awk '{print $1,$2}' \| sort \| uniq -c` |
| docs/agents on main yet | `git log origin/main --oneline -- docs/agents \| head -1` |
| Class ids, bot guards (upstream) | keep a workspace (`--keep`) and `grep -n "CLASS_HERO\|IsAscensionClass" core/src/server/shared/SharedDefines.h; grep -n "bool IsBot" core/src/server/game/Server/WorldSession.h; grep -n "IsRealPlayer\|HasGameClientMaster" core/modules/mod-playerbots/src/Bot/PlayerbotAI.h` |
| PowerShell release used above | any 7.x works; v7.4.6 was the one used on 2026-11-22 |
| The shield and stance bug of 22 Nov | `git log --all -i --grep='shield\|stance' --since=2026-11-22` |
