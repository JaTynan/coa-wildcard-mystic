# Reading the pre-flight's output

Read this when a pre-flight run says FAIL, or when you need to know exactly what a PASS does and does not prove.
Every excerpt below is real output from 2026-11-22 (Linux, git 2.43, PowerShell 7.4.6, release
server-0.261119.114 unless stated).

## 1. A pass (the verified baseline)

```
Pre-flight for <repo>/patches
Release server-0.261119.114: core c3f2fd4b2395, SQUID 4ef5ed9ebe75 (v3.0), Dungeon Clear 6efb59eae96b, mod-ollama-chat 906eb2a45f5b (pinned in the workflow)
PowerShell 7.4.6 (...); 5 *.patch, 56 *.ps1
== Core at the release commit (21 s)
== Apply our patches (inside core/, before any module is checked out)
  OK    mystic-enchants-actions.patch
  ...
== Apply the official build's module patches (checksums as the release lists them)
  OK    patches/squid-coa-validation.patch -> core/modules/mod-playerbots
  OK    patches/dungeon-clear-coa-validation.patch -> core/modules/mod-dungeon-clear
== Apply our patch scripts (patches/*.ps1, in name order, from the workspace root)
  OK    10-mod-ollama-chat-fit.ps1  (5 file(s), 0.9 s)
  ...
  OK    96-bots-ignore-commands.ps1  (2 file(s), 0.2 s)
== C++ text check of the 56 touched source files (a heuristic, NOT a compiler ...)
  nothing found
== What changed (git diff --stat; our scripts and patches only)
-- core
  ...
  40 files changed, 5187 insertions(+), 51 deletions(-)
  new file: src/server/coa/WcmeEnchantActions.cpp
  new file: src/server/coa/WcmeEnchantScripts.cpp
  new file: src/server/game/Miscellaneous/WeekendBonus.h
-- core/modules/mod-playerbots
  8 files changed, 123 insertions(+), 6 deletions(-)
  new file: src/Ai/Coa/Social/WildcardBotCommand.h
-- core/modules/mod-dungeon-clear
  1 file changed, 54 insertions(+)
-- core/modules/mod-ollama-chat
  4 files changed, 3102 insertions(+), 3092 deletions(-)
  new file: src/mod-ollama-chat_quiet.h
== Summary
  release        server-0.261119.114 (core c3f2fd4b2395)
  *.patch        5 of 5 applied
  *.ps1          56 of 56 run applied; 18 s
  applied once   each script ran exactly once, in the build's order, on freshly checked out sources
  text check     0 error(s), 0 warning(s) in 56 files
  wall time      47 s
  RESULT         PASS: every patch and script applies to this release. NOT proven: that it compiles, links, starts or behaves.
```

How to read it:

- **Header line 2** is what `scripts/resolve_release.py` returned. If the tag is not the one you expect, a new
  manager release has come out: you are testing against the newer core, which is what the next build will use.
- **"(N file(s))"** after each script is how many files that one script changed. After your edit, the number for
  your script should be what you intended. `WARNING: changed no file` after an `OK` means every anchor check passed
  and nothing was written: look for a `-replace` or `.Replace` whose result is thrown away.
- **"What changed"** is your diff. For a new script, compare with the baseline numbers above: only the files you
  meant to touch should have moved. The huge numbers under mod-ollama-chat are normal: that module's files are
  stored with Windows line endings (CRLF) and script 10 rewrites three of them with LF, so every line counts as
  changed.
- **Exit code**: 0 pass, 1 a patch, script or the text check failed, 2 the pre-flight itself could not run (no
  pwsh, no network, bad option). Treat 2 as "not tested", never as a pass.

Measured wall time here, 2 CPUs: 61 to 93 s with nothing cached (`--no-cache` or first run), 47 to 62 s afterwards.

## 2. One broken anchor

A scratch copy of `patches/` with one word changed in the anchor of `71-jump-multiplier-points.ps1`
(`DamageMultiplier` to `DamageMultiplierX`, as if the core had renamed it), run with `--patches <copy>`:

```
  OK    70-mastery-of-the-tide-riptide.ps1  (1 file(s), 0.2 s)
  FAIL  71-jump-multiplier-points.ps1  at 71-jump-multiplier-points.ps1:14
        SpellInfo.cpp CalcDamageMultiplier anchor not found exactly once
  OK    72-racial-grave-defiance.ps1  (3 file(s), 0.2 s)
  ...
  *.ps1          55 of 56 run applied; FAILED: 71-jump-multiplier-points.ps1; 39 s
  RESULT         FAIL: a build of this would fail (or build something wrong). Fix and run again.
```

- `at 71-...ps1:14` is the script line that threw. The message is the script's own `throw` text: the same text the
  build log would show after "== 71-jump-multiplier-points.ps1".
- The build stops at the first failure. The pre-flight carries on by default so one run lists everything; use
  `--fail-fast` to see exactly what the build would see.

## 3. A missing earlier script (knock-on failures)

A scratch copy without `40-battlegrounds.ps1`:

```
  FAIL  45-weekend-bonus.ps1  at 45-weekend-bonus.ps1:142
        Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no single: #include "PlayerScript.h"
        (it had already changed: core/src/server/game/Miscellaneous/WeekendBonus.h (new file); core/src/server/game/Entities/Player/PlayerQuest.cpp (+4 -0); core/src/server/game/Entities/Player/Player.cpp (+5 -0))
  FAIL  46-play-time-rewards.ps1  at 46-play-time-rewards.ps1:15
        Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: #include "PlayerScript.h"
        (an earlier script failed too: this may be a knock-on, fix the first failure first)
  ...
  *.ps1          34 of 55 run applied; FAILED: 45-weekend-bonus.ps1, 46-..., (21 scripts)
```

- **Fix the first failure and run again.** 21 scripts fail here for one cause.
- **"it had already changed"**: scripts are not all-or-nothing. A script with several parts writes each part as it
  goes, so a failure in part 3 leaves parts 1 and 2 applied. In the build this does not matter (the build stops).
  It matters if you are tempted to "re-run just that script" in a kept workspace: never do that; start a new run.

## 4. A core the patches were not written for (what a core update looks like)

`main`'s patches of 2026-11-22 against older releases:

| Release | Core | Result |
|---|---|---|
| server-0.261119.114 | c3f2fd4b23 | PASS |
| server-0.261116.112 | 30003e18ab | PASS (1,403 files differ between these two cores, and every anchor still fits) |
| server-0.261108.95 | 85ecc2122e (SQUID v2.9.4) | FAIL: only `96-bots-ignore-commands.ps1` |
| server-0.261028.83 | a76415e00e (SQUID v2.7) | FAIL: 2 of 5 `*.patch`, 29 of 56 scripts |

The .95 failure is a different kind of message:

```
  FAIL  96-bots-ignore-commands.ps1  at 96-bots-ignore-commands.ps1:96
        Could not find a part of the path '.../core/modules/mod-playerbots/src/Ai/Coa/Social/WildcardBotCommand.h'.
```

That is not an anchor: the folder the script writes its new header into does not exist in SQUID v2.9.4. A
PowerShell error that is not one of the scripts' own "... changed: ..." texts usually means a file or folder
moved.

The .83 run, read as a porting job (root causes only):

```
  FAIL  mystic-enchants-actions.patch
        mystic-enchants-actions.patch no longer fits release server-0.261028.83. The patch needs refreshing for this core.
            error: patch failed: src/server/coa/CoAScriptLoader.cpp:131
  FAIL  mystic-enchants-wildcard.patch
            error: patch failed: src/server/coa/AscensionMysticEnchant.cpp:335
  (the build stops here; the scripts are still tried below so one run shows everything)
  ...
  FAIL  40-battlegrounds.ps1  at 40-battlegrounds.ps1:87
        Core changed: AscensionAdventurerCache.cpp no longer has: bool IsGearCache(uint32 entry)
        (it had already changed: core/src/server/game/Battlegrounds/Battleground.cpp (+38 -3))
  FAIL  64-enchant-scripts-loader.ps1  at 64-enchant-scripts-loader.ps1:14
        CoAScriptLoader.cpp has no AddSC_WcmeEnchantActions declaration (is mystic-enchants-actions.patch applied?)
  FAIL  65-enchant-tuning-auras.ps1  at 65-enchant-tuning-auras.ps1:22
        Unit.cpp anchor not found exactly once: id == 271942 || id == 275097;
  FAIL  78-worldforged-enchants.ps1  at 78-worldforged-enchants.ps1:49
        Core changed (or mystic-enchants-wildcard.patch did not apply): AscensionMysticEnchant.cpp has no single: SkipMissingSpells();
```

Sort the list before you touch anything:

1. `*.patch` failures first (they are applied first; 64 and 78 fail only because of them).
2. Then the lowest-numbered script whose message is not "(or NN did not run)". Here: 40, then 65.
3. Everything that names an earlier script or patch in its message is a knock-on until proven otherwise.

(The server's .83 core has its own branch, `for-083`, whose patches differ from `main`'s on purpose: README.md,
"Branches". This table is a demonstration of reading failures, not a plan to port `main` to .83.)

## 5. Problems the scripts themselves never report

These pass every anchor check and were each a real or demonstrated way to lose a build:

```
== C++ text check ...
  ERROR    core/modules/mod-dungeon-clear/src/DungeonClearModule.cpp:87: text after an #include on the same line: '#include "TestRun/DcSelfFoundPlanner.h"' (inserted text without a final line break runs into the next line; MSVC then ignores it: C4067, 21 November, commit e0cc2f5)
  WARNING  core/src/server/coa/WcmeEnchantScripts.cpp: 'SYNCHRONIZE' looks declared as a name, and <windows.h> defines it as a macro: rename it (line: static constexpr uint32 SYNCHRONIZE = 986165;)
  ERROR    core/src/server/game/Handlers/MailHandler.cpp: the patches changed the file's balance of unmatched '{' / '}' (was +0, now +1 more opened than closed)
```

- The first two lines come from putting two historical bugs back in a scratch copy: script 90 as it was before
  commit e0cc2f5 (build failed 21 November) and the name `SYNCHRONIZE` from before commit a4048e7 (build failed 16
  November). Both builds would have been saved.
- The third is a deliberately dropped `}` in script 85.

```
  FAIL  mystic-enchants-scripts.patch
        mystic-enchants-scripts.patch: 1 line(s) from line 14559 follow a hunk that is already full: its @@ count is stale, and git apply would drop them without an error
```

- A line added by hand to the 671 KB patch without raising the `+1,14552` in its `@@` header. `git apply --check`
  and `git apply` both exit 0 and silently leave the last line (`}`) out of the file. Demonstrated on 2026-11-22;
  not known to have happened in a build.

```
  FAIL  94-dungeon-finder-join-limit.ps1: PowerShell syntax error at line 17: Missing closing ')' after expression in 'if' statement.
  WARNING  52-zz-copy.ps1 and 52-racials.ps1 share the number 52; their order then depends on the rest of the name
```

- Every script is parsed before any script runs, so a typo in script 96 is reported in seconds, not after the
  other 55 have run.

## 6. What a PASS does not prove

| Not proven | Who proves it |
|---|---|
| The C++ compiles with MSVC (types, missing includes, names in the wrong namespace) | The build (about 3½ h). The text check is a few regular expressions, not a compiler |
| It links | The build |
| The server starts with it | The build's only runtime check is `worldserver.exe --version`; start-up is seen at install time (sibling skill wildcard-validation-and-qa) |
| It does what the description says, for players, bots and Wildcard Heroes | Review (the checklists in SKILL.md, the patch reviewer) and testing in game |
| Settings and SQL companions exist and match | The checks in sibling skill wildcard-validation-and-qa |
| It still applies to the NEXT core | Run the pre-flight again when the release changes |
