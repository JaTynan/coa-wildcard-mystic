---
name: wildcard-settings-and-flags
description: Every configuration axis of the Wildcard server. Covers server-settings/server-settings.txt (line format, which config file each line targets, the realm guard), the settings kit (Apply-ServerSettings.ps1, Apply-Settings.cmd, Save-Current.cmd, Save-From-CoA-Realm.cmd), when settings are applied (every start), settings-report.txt and its Missing property and Bad value warnings, and a generated catalogue of every option the patches add (CoA.MysticEnchants.*, Wildcard.*, Racials.*, WeekendBonus.*, AiPlayerbot.Wildcard*, OllamaChat.*Pct) with code default, live value, patch and first build, plus upstream options set on purpose (bot counts, bot chat, rates) and the performance settings with their history. Load it for "add a setting", "change the XP rate", "turn that feature off", "what does this setting do", "why did the value reset itself", when settings-report lists unknown names, or when a settings PR needs a risk class. For a performance experiment load wildcard-lag-spike-campaign first.
---

# Wildcard settings and flags

Checked on 2026-11-22 at `fcfee51` (PR #232: `62a26e4`, the #230 merge, plus two commits adding `.claude/agents/`
and `docs/agents/`) and at `origin/main` `d3e030f` (#231, which adds only `signup/WildcardConsole.py` and three
lines of `signup/WildcardSignup.py`), and against the upstream sources at the commits the build pins. Nothing was
re-checked on the server VM that day. `docs/agents/*` is cited below; it exists only in PR #232 (open), so what
rests on it is **INTENDED DOCTRINE (PR #232, unmerged on 2026-11-22)**; on `main` read it with
`git show origin/agents-stage-1:docs/agents/context/<file>`. Status words: `wildcard-change-control`, section 1.

## When NOT to use this skill

| You want to | Use instead |
|---|---|
| Decide the risk class, path or who merges; the hard stops in full | wildcard-change-control |
| Write or port the C++ patch that reads a setting; pre-flight a patch | wildcard-patch-authoring |
| Understand what an upstream option does inside AzerothCore, CoA or the bots | azerothcore-coa-reference |
| Run, stop or roll back the server; patch night function by function | wildcard-run-and-operate |
| Measure tick times, read Timing.log or the perf CSVs | wildcard-diagnostics-and-tooling |
| Work the lag spikes as a campaign (which lever to try next and why) | wildcard-lag-spike-campaign |
| Diagnose a symptom that might or might not be a setting | wildcard-debugging-playbook |
| Find the full story of a past incident | wildcard-failure-archaeology |
| Fix or tune a Mystic Enchant (SQL under `sql/enchants/`) | ascension-restoration |
| Launcher, website, sign-up and their settings files | wildcard-client-and-web |
| Decide what counts as tested | wildcard-validation-and-qa |

## Start here

- Change a value: section 8b. Add a setting: 8a. Retire one: 8c. Risk class: 8d (then `wildcard-change-control`).
- What one option is and does: `references/settings-catalogue.md` (section 6 says how to read it).
- A value "did not take" or the report lists unknown names: sections 4, 5 and the traps in section 9.

**Words used here**

| Word | Meaning |
|---|---|
| setting / option | One `Name = value` line the server reads from a config file. |
| config file | A `.conf` text file under `C:\Games\CoA Server\Core\configs` on the VM (`worldserver.conf`, `authserver.conf`, `modules\*.conf`). |
| `.dist` | The template of a config file that ships with the server (`worldserver.conf.dist`): every option that version knows, with its default. |
| the kit | `server-settings/Apply-ServerSettings.ps1` and its three `.cmd` wrappers. |
| the manager | CF-Server-Manager, the desktop program that installs and starts the CoA server. |
| patch night | `patch-night/PatchNight.ps1`: the scheduled script that restarts the server every night and installs builds weekly. |
| the build | Our patched `worldserver.exe`, made by GitHub Actions in 2 to 3 hours. |
| `GetOption` | `sConfigMgr->GetOption<T>("Name", default)`: how C++ code reads a setting. |
| any other term | `.claude/skills/azerothcore-coa-reference/references/glossary.md` |

## 1. The one-page model

```
GitHub main: server-settings/server-settings.txt        (the only place a value is changed)
        |  patch night downloads main.zip at every run (FetchRepo) and overwrites the VM copy
        v
VM: C:\Games\CoA Server\server-settings\server-settings.txt
        |  Apply-ServerSettings.ps1 -Unattended   (during the countdown, server still up)
        v
VM: Core\configs\*.conf  and  Settings\worldserver.conf.template / authserver.conf.template
        |  world server restarts and reads its config files
        v
running server.   Checks written to server-settings\settings-report.txt
```

- **Nothing is edited on the running server by hand** (CHANGES.md, first paragraph). A value changed in a config
  file on the VM is put back at the next start, and a `server-settings.txt` edited on the VM is overwritten by the
  next download from GitHub (`FetchRepo`, patch-night/PatchNight.ps1:220-238).
- **Merging a settings change to `main` deploys it.** It goes live at the next nightly restart, with no build
  (times and the go-live table: `wildcard-run-and-operate`, "When does my merged change go live?").
- **A setting only does something if the installed program reads it.** A line for an option our patch adds is
  ignored without complaint by a build that does not have the patch yet. The catalogue gives each option's first
  build.

## 2. The file format (`server-settings/server-settings.txt`)

As of 2026-11-22: 618 lines, of which 273 are not comments or blank: 270 settings plus 3 special lines (`realm`,
two `realmlist`). Plain ASCII. This is the count rule other skills refer to.

```
# comment
<config file> | <setting> = <value>
```

| Rule | Detail | Source |
|---|---|---|
| One setting per line | Matched by `^\s*([^|#]+?)\s*\|\s*([^=\s]+)\s*=\s*(.*?)\s*$`. Everything after `=` is the value, written to the config file exactly as typed, quotes included. | Apply-ServerSettings.ps1:40 |
| Config file | A path relative to `Core\configs`, with a backslash for module files: `worldserver.conf`, `authserver.conf`, `modules\playerbots.conf`. | file header, line 3-4 |
| Comments | A line starting with `#`. **There are no end-of-line comments**: `x.conf \| A = 1 # note` sets the value to `1 # note`. | the regex above |
| Sections | A comment line of dashes and a title (`# ------- Experience`). Only for people; the kit ignores them. | file |
| `?` value | "Not recorded yet". Apply skips it; Save-Current fills it in. None left as of 2026-11-22. | file header line 5-6; kit line 213 |
| Setting names | Compared without regard to case when the kit looks for the line in a config file. | kit line 63-66 |
| Same setting twice | Both lines are applied in order, so the later one wins. None as of 2026-11-22 (catalogue 4f). | kit line 208-231 |

**The comment above a line is part of the change record.** The house pattern, seen on almost every line: what the
value does in player terms, the date and who asked ("21 Nov, James"), the previous value ("was 1,250"), which build
or patch it needs, and what the off value is ("0 = off", "1 = stock"). The risk rules in section 7 depend on the
comment stating a range, so write one.

### Which config file each line targets (counts as of 2026-11-22)

| Target | Lines | Holds |
|---|---|---|
| `worldserver.conf` | 146 | Core options, and most options our core patches add |
| `modules\mod_ollama_chat.conf` | 37 | AI chat for bots (prompts, pacing, model address) |
| `modules\mod_ahbot.conf` | 27 | Auction House bot stock, prices, item lists |
| `modules\playerbots.conf` | 26 | SQUID's bots: count, waking, world PvP, groups |
| `modules\coa.conf` | 12 | CoA core module: realm type, Mystic Enchant switches, vanity, remote clients |
| `modules\wildcard.conf` | 9 | Wildcard rolls, cards, scrolls |
| `modules\mod_dungeon_clear.conf` | 6 | Dungeon Clear and Smart Rest |
| `modules\mod-coa-challenges.conf`, `modules\dynamicxp.conf` | 2 each | Game mode of the realm; Dynamic XP off |
| `modules\mod_coa_playerbots.conf`, `modules\mod-coa-prestige.conf`, `authserver.conf` | 1 each | CoA's own bots off; prestige XP bonus; bind address |

The server loads `worldserver.conf` and every module config it knows into **one** table of options (upstream
`src/common/Configuration/Config.cpp`, `_configOptions`), so the file a line sits in does not change what the
server reads, as long as that file is one the installed program loads: the list of module config files is compiled
into the program (upstream `modules/CMakeLists.txt`), so the official server never opens `mod_ollama_chat.conf`,
which only our build includes. The file matters for two more reasons: the kit skips a line whose file does not exist on the VM
("no file: ... (skipped ...)"), and for `worldserver.conf` and `authserver.conf` the kit also writes the manager's
master copy `Settings\<file>.template`, because the manager rebuilds the live file from it (kit line 55-61).

### The three special lines (not config options)

| Line | What it does | Read by |
|---|---|---|
| `realm \| active = wildcard` | **Realm guard.** The whole list is for one realm. If the manager's `Settings\realm-profile.json` says another realm is active, the kit changes nothing and exits with an error. No file means realm `coa`. | kit line 192-201 |
| `realmlist \| address = wow.jtlab.cc` | The address other computers use. Written to the `realmlist` table of the auth database after every start, not to a config file. | `RestoreRealmAddress`, PatchNight.ps1:611 |
| `realmlist \| local = <home address>/<mask>` | Home-network address and mask (the LAN address in server-settings), so computers at home connect directly. | same function |

**Realm-specific values**: there is one list and it belongs to the Wildcard realm. The manager keeps each inactive
realm's config files in `Settings\realm-profiles\<realm>.json`; the kit never writes those. A patched server that
runs another realm therefore gets the **defaults in code** for our options, not this file (see the proposed
practice in section 8, step 1).

## 3. The kit

All four files live in `server-settings/` in the repository and `C:\Games\CoA Server\server-settings\` on the VM.
The PowerShell could not be run where this skill was written; the description below is from reading it.

| Run this (on the VM) | It does | Changes |
|---|---|---|
| `Apply-Settings.cmd` | Sets every listed setting (except `?`) in its config file; adds the line at the end of the file if it is missing. | Config files, after a backup |
| `Save-Current.cmd` | (`-Capture`) Fills each `?` with the value the active realm's config file has now. | Only `server-settings.txt` on the VM |
| `Save-From-CoA-Realm.cmd` | (`-Capture -Realm coa`) Fills each `?` from the CoA realm's saved profile `Settings\realm-profiles\coa.json`. | Only `server-settings.txt` on the VM |
| `powershell -File Apply-ServerSettings.ps1 -Server <path> -Unattended` | What patch night calls: same as Apply, no "Press Enter". | as Apply |

Running any of these on the VM changes the server's configuration: classify with **wildcard-change-control** first.
The Save commands write the VM copy of the list, which the next patch night overwrites from GitHub, so their result
must be copied into a pull request to survive.

What Apply does, in order (Apply-ServerSettings.ps1):

1. Realm guard (line 192). Wrong realm: stop, nothing changed.
2. For each line: find the setting in each target file through an index built once per file (line 63-81; added
   22 Nov in `d802f8c` after applying 261 settings took about 3 minutes of patch-night downtime). Every existing
   line for the setting is rewritten; if there is none, the line is appended.
3. Each changed file is first copied to `Core\configs\settings-backup\<yyyy-MM-dd_HHmmss>\`, then written without a
   byte-order mark in the encoding it was read in (line 239-245).
4. Backups of the **newest 20 runs that changed something** are kept; older folders are deleted (line 246-248).
5. The settings check (section 5) is written to `server-settings\settings-report.txt`.
6. Final line: `Changed N setting(s), M already right, K skipped.`

### When settings are applied

| Trigger | Where | Notes |
|---|---|---|
| Nightly restart and weekly patch night | PatchNight.ps1:930 | During the countdown, with the server still up ("The servers read their configs only when they start"). Applied a second time straight after a new build is installed, because the installer sets a value itself (line 966-967). |
| `patch-night\Start-Server.cmd` (`-StartOnly`) | PatchNight.ps1:824 | Downloads `main` first like every run, applies, then starts. Use this instead of the manager's Start button (section 9, trap 3). |
| `patch-night\Rebuild-WildcardBots.cmd` | PatchNight.ps1:806 | One-off tool; applies the settings before its final start. |
| `Apply-Settings.cmd` by hand | kit | Writes the files; the running server does not notice until a restart or `.reload config`. |

Every patch-night run first downloads `main` (`FetchRepo`). A kit script from GitHub that PowerShell cannot parse is
not copied; the VM keeps its current copy and the log says so (PatchNight.ps1:233-236). If GitHub cannot be reached
the local copies are used.

### Two things that are written after the kit, by patch night itself

- `AuctionHouseBot.DisabledCustomItemIDs`: `SkipUnusedAuctionItems` (PatchNight.ps1:490-555) rebuilds this line
  in `mod_ahbot.conf` at every start from the world database (unused, PvP, Burning Crusade and Wrath items) and
  **prepends** the ids from the line in `server-settings.txt`. So the live value is longer than the one in the file,
  by design. Consequence worked out from the code, not seen on the VM: the kit finds a difference on this line at
  every run, so every run "changes 1 setting" and takes one of the 20 backup slots.
- `mod_ollama_chat.conf`: `PrepareOllamaChat` (PatchNight.ps1:368) copies `ollama-chat/mod_ollama_chat.conf.dist`
  into `Core\configs\modules` at every start and, if there is no `mod_ollama_chat.conf` yet, creates one with
  `OllamaChat.Enable = 0`. The settings list then turns it on.

The auction prices have a follow-up too: when any `AuctionHouseBot.Price*` or `EquipItemUseOrEquipLevelRestrict*`
line changes, `RepriceAuctionsWhenPricesChange` removes the Auctioneer's unbid listings once so they are relisted at
the new prices (PatchNight.ps1:557). That deletes rows in the characters database: mention it when classifying an
auction price change.

## 4. Start-only or live?

`.reload config` (a GM console command) makes the world server read the config **files** again (upstream
`World::LoadConfigSettings(true)` calls `sConfigMgr->Reload()`). Whether a new value then takes effect depends on
how the code reads it.

| How the code reads it | Effect of `.reload config` | Examples (verified in the patch named) |
|---|---|---|
| `GetOption` at the moment of use | New value used from the next use | `GroupXP.*` (93), `Wildcard.WorldforgedDropChance` (78), `Wildcard.QuestCache*Percent` (40), `WeekendBonus.*` (45), the `Racials.*` switches during play, `AiPlayerbot.Wildcard*` (20), `Wildcard.RestingManaRate` (77, read in `Player::UpdateManaRegen`) |
| Read in a config-load hook | New value used after the reload | `Wildcard.AbilityPool`, `Wildcard.FreeScrolls` (`OnAfterConfigLoad`, wildcard-ability-pool.patch:113-114) |
| Read once while spell data loads | **Restart needed** | The spell-data part of three racials: War Stomp castable while moving (`Racials.Plainsrunning`, 54:58), Arcane Torrent's 1 min cooldown (`Racials.ArcaneHunger`, 75:40), Cannibalize's channel (`Racials.GraveDefiance`, 72:320) |
| Stated start-only in the file's comment | Restart needed | `DungeonClear.Enable` |
| Thread counts and logging set-up | Assume restart needed (UNVERIFIED in upstream code; check `World.cpp` and `Log.cpp` if it matters) | `MapUpdate.Threads`, `*Database.WorkerThreads`, `Log.Async.Enable` |
| SQUID's own `AiPlayerbot.*` options | UNVERIFIED: SQUID copies them into its own structure; check `PlayerbotAIConfig` in `Zyth45/mod-playerbots` before promising a live change | `AiPlayerbot.MinRandomBots`, `BotActiveAlone` |

One comment in the file disagrees with the code: `Wildcard.RestingManaRate` says "Read at server start", but
77-resting-mana-regen.ps1:20 reads it inside the regeneration update. Trust the code.

The safe default, and the only path the pipeline uses: change the file on GitHub and let the nightly restart apply
it. Applying by hand plus `.reload config` on the live server is James's call (GM and console commands are a hard
stop in docs/agents/context/change-risk.md).

## 5. How unknown and removed options are detected (`settings-report.txt`)

Location on the VM: `C:\Games\CoA Server\server-settings\settings-report.txt`. Rewritten by every Apply run,
then appended to by patch night once the world is up. Introduced 22 Nov in `ba59783`.

| Part of the report | Written by | Meaning |
|---|---|---|
| `Known to the server: N (M of them read by our patched server only, not in the official .dist).` | kit line 289 | A setting is known when the installed `<file>.dist` lists it (commented-out examples count), or when its whole name appears as text inside `Core\worldserver.exe`. |
| `Unknown, in neither the .dist nor the server program (...): N` then the names | kit line 290-291 | Probably renamed or removed by an update, or a typo. The server ignores these lines. |
| `Read by our patched server only:` | kit line 292 | Our own options, found in the program but not in a `.dist`. |
| `No .dist to check against (our own module configs): ...` | kit line 293 | Files with no template on the VM; their settings were not checked at all. |
| `Options the .dist lists that our config files do not set (...)` | kit line 294-304 | New options a core update brought, running on defaults. 49 of these were reviewed on 22 Nov and four set on purpose (commit `6223bc8`, PR #230; last section of the file). |
| `The world server's own warnings at this start`: "Settings it uses but no config file sets" | `ReportConfigWarnings`, PatchNight.ps1:668 | Each `> Config: Missing property <name> in config file ...` line of this start's `Server.log`: the server read an option that no file sets and used the default in code. |
| "Values it could not use" | same | Each `> Config: Bad value defined for name '<name>', going to use '<default>' instead`: the value is the wrong type (text where a number is wanted). **A setting of ours is not working.** Patch night logs this run as WARN. |

Reading it:

- "Missing property" is normal in bulk; only a change in the count matters (docs/agents/context/patch-night.md).
  A patch can silence its own option by passing `false` as third argument of `GetOption` ("Quiet" in the catalogue).
- Any "Bad value" is a fault to fix the same day.
- **The "0 unknown" rule (this section is its home).** docs/agents/context/patch-night.md (INTENDED DOCTRINE) says
  a healthy run shows "0 unknown". **Prediction from the code, UNVERIFIED on the VM:** about 28 working settings
  can never pass the kit's test, because their names are assembled when the server runs
  (`"WeekendBonus." + theme + "." + name`, `prefix + "CasePercent"`), are read by prefix (`Appender.*`,
  `Logger.*`), or are read only by the website's status service (`Leaderboards.HiddenCharacters`). The catalogue
  lists them (section 4g). The refinement that would teach the kit about them (`5978ee4`) is not on `main`.
  **Proposed practice (not yet adopted by James):** a check compares the "Unknown" list with the previous run's
  and alarms on a NEW name, not on a non-zero count. Purpose: a rule that every healthy night fails is no rule.
  Incident: none yet (found by reading the code). Tell James if a real report disagrees with the 4g list.

## 6. The catalogue

Read `references/settings-catalogue.md` when you need a specific option: its type, default in code, live value,
the patch line that reads it, the first build that has it, why an upstream option was set and by which commit, or
the mismatch lists. It is generated; never edit it by hand.

```
# from any folder; python 3, standard library only. What a settings PR runs; writes nothing:
python3 -I .claude/skills/wildcard-settings-and-flags/scripts/settings_catalogue.py --lint
```

`--lint` exits 1 on a hard problem (a line that is neither comment nor setting, a setting listed twice, a
CHANGES.md setting name nothing reads, a `GetOption` whose name it cannot work out). Without `--upstream` three of
its counts are weak (119 / 25 / 8 instead of 0 / 28 / 7 on 2026-11-22); the first count and "Hard problems" were
the same either way. Regenerating the catalogue needs the
four upstream clones at the pinned commits and is skill maintenance, not part of a settings PR: read
`references/regenerating-the-catalogue.md` when you have to do it. A bare run refuses to overwrite the shipped
file, and the script refuses upstream folders that look patched.

What the catalogue holds (numbers as of 2026-11-22):

| Section | Content |
|---|---|
| 1 | The 99 option names our patches read: type, default in code, value in the file, config file, patch and line, first build, status, what it does |
| 2 | Every other line of the file (upstream options set on purpose), grouped by the file's own sections, with the upstream default, the commit and PR that first set it and that set today's value, and the reason from the comment |
| 3 | Performance-relevant settings with full value history; 3b lists option reads inside per-tick hooks |
| 4 | Mismatches (below) |
| 5 | Not on main: commented-out candidates, and settings or option reads that exist only on unmerged branches |

Where the task's usual groups sit in section 2: bots = "SQUID's bots on Wildcard", "SQUID's bots: world PvP",
"SQUID's bots: lower load"; performance, threads and logging = "SQUID's bots: lower load", "Logging (lag, 20 Nov)",
"Performance diagnosis (21 Nov)"; rates, XP and rested = "Experience", "Rested XP", "Professions and drops";
PvP = "PvP rewards"; auction house = "Auction House bot"; dungeon finder = "New core options, set on purpose";
level cap = "Experience" (`MaxPlayerLevel`); chat and Ollama = "AI chat for bots"; realm = "Wildcard realm" and
"Play with friends".

### Production or experimental

| Status | Means | Where to see it |
|---|---|---|
| production | The patch is on `main` and `server-settings.txt` on `main` has a line for the option | catalogue section 1 |
| on code default | The patch is on `main`; the file has no line, so the default in code applies | section 4a |
| needs a newer build | The line is on `main` but no release tag contains the patch yet ("NOT IN A BUILD YET") | section 1, "First build" |
| experimental | Only on an unmerged branch, or commented out in the file | section 5 |

### Mismatches found on 2026-11-22 (catalogue section 4)

| Finding | Detail | What to do |
|---|---|---|
| Read by a patch, no line in the file: 1 | `WeekendBonus.<theme>.XPRate` (45-weekend-bonus.ps1:156): a general XP multiplier per theme that no theme sets. Default 1, quiet. | Harmless. Add a comment line naming it if a theme should ever use it. |
| In the file, read by nothing: 0 | With the upstream templates and sources at the pinned commits, every line has a reader. | Nothing. |
| CHANGES.md setting names nothing reads: 0 | | Nothing. |
| Options CHANGES.md never names: 7 | `CoA.MysticEnchants.AllowWildcard`, `.SkipMissingSpells`, `.SkipDudSpells` (the row says "always on"), `Wildcard.EnchantPrimaryStat`, and three of the four `AiPlayerbot.WildcardGroup*Pct` ("and the shares after it"). | A documentation gap against CHANGES.md's own rule. Fix in a docs PR (see wildcard-docs-and-publishing). |
| Settings the VM check cannot see: 28 (prediction) | Section 5 above. | Verify against a real `settings-report.txt`. |
| File comment against code | `Wildcard.RestingManaRate` "Read at server start" (section 4). | Correct the comment in the next settings PR. |
| File comment against docs | `MapUpdate.Threads` comment: "6 from 8 Nov, with the VM at 10 cores"; docs/performance.md says 8 vCPUs. | Settled: the 22 Nov perf CSV shows 10 logical processors, so the settings comment is right and docs/performance.md (8 vCPUs) is stale. |
| docs/performance.md is stale on one value | It says `AiPlayerbot.BotActiveAlone` is "now 15"; the file has had 5 since `240d773` (7 Nov, PR #59). | Trust the file. |
| Possible upstream drift, candidate only | Upstream's `wildcard.conf.dist` at the pinned core (file last changed 11 Nov) lists `CoA.RealmType = "league"` for a Wildcard realm and says a live or seasonal realm hides Wildcard-only entries in the client. Our file has `"live seasonal"` since 30 Oct (`42290ca`), copied from what the manager set then. | Player-visible; do not change on this evidence. Raise with James; check what the manager writes for a new Wildcard realm today. |

## 7. Performance-relevant settings

Current values and where they came from. Full history per option is in catalogue section 3; the measurements are
in docs/performance.md and the commits named. The lag-spike campaign (skill wildcard-lag-spike-campaign) links here
for values; how to measure belongs to wildcard-diagnostics-and-tooling.

| Setting | Value (2026-11-22) | Upstream default | History and evidence |
|---|---|---|---|
| `MapUpdate.Threads` | 6 | 1 | 4 on 7 Nov (`70f055b`, #49: 1,000 bots went from 33 to 50 ticks/s, docs/performance.md); 6 on 8 Nov (`61a5be9`, #77). Comment: "Back to 1 if anything odd shows up." |
| `AiPlayerbot.MinRandomBots` / `MaxRandomBots` | 750 / 750 | 500 / 500 | 1000 (`7a90659`, 6 Nov, #46) -> 1500 (`2ce36a4`, #53) -> 1250 (`aca9022`, 7 Nov, #57) -> 1000 (`ff00757`, 9 Nov, #113: 99% 147 ms, worst 1.3 s with 3 players) -> 750 (`6a3e017`, 21 Nov, #217: median 36 ms, worst ticks 2-5 s with 2 players) |
| `AiPlayerbot.BotActiveAlone` | 5 | 60 | 15 -> 5 on 7 Nov (`240d773`, #59). Percent of bots awake away from real players. |
| `AiPlayerbot.BotActiveAloneForceWhenInZone` | 1 | 1 | Set to 0 on 8 Nov (`e608f61`, #88), back to 1 the same day (`c02ba12`, #95): with zone waking off, bots near players froze for 20 minutes or more. Cause not understood; the comment says so. |
| `AiPlayerbot.BotActiveAloneForceWhenInRadius` | 300 | 150 | `e608f61`, #88. |
| SmartScale (`AiPlayerbot.botActiveAloneSmartScale`, `...DiffLimitfloor`, `...DiffLimitCeiling`) | **not in the file** | 1, 50, 200 | Never set here, so the VM runs whatever its `playerbots.conf` holds. docs/performance.md describes it as on, starting at 50 ms and fully paused at 200 ms, which matches the upstream defaults. Note the lower-case `b` in the names. |
| `AiPlayerbot.DisabledWithoutRealPlayer`, `RandomBotConcentrateInPlayerZone` | 1, 1 | 0, 0 | Since the first file (`2b882b7`, 30 Oct). Bots log in with the first player and gather in players' zones. |
| `Log.Async.Enable`, `Logger.coa`, `Logger.module.coa_challenges` | 1; `4,Server`; `3,Console Server` | 0; `4,Console Server`; not in a template | 20 Nov (`f9dc45a`, #204): with about 880 bots every roll and challenge packet was written to the console in line with the world update; the console log had reached 2.9 GB; 99th percentile tick 586 ms, worst 2.9 s. Shipped 20 Nov; no after-measurement; `world-console.log` was 2.99 GB on 22 Nov, and that day's server start (08:53) predates the merges of #229 to #231, so the console-log clear/rotation had not run yet; status OPEN. |
| `CharacterDatabase.WorkerThreads` / `SynchThreads`, `LoginDatabase.WorkerThreads` | 4 / 2, 2 | 1 / 1, 1 | 8 Nov (`0cce098`, #75): player requests queued behind bot logins and saves. `WorldDatabase.WorkerThreads` is not set (default 1). |
| `Visibility.Distance.Continents` | 100 | 100 | 150 was merged and backed out the same day, 9 Nov (`7001de0` #111, `ff00757` #113). 75 exists only on the unmerged branch `perf-visibility-react` (`0cd1413`, 8 Nov). |
| `RecordUpdateTimeDiffInterval`, `MinRecordUpdateTimeDiff`, `Appender.Timing`, `Logger.time.update` | 60000; 0; `2,4,1,Timing.log,a`; `4,Console Server Timing` | 300000; 100; none; `4,Console Server` | 21 Nov (`9ba9f45`, #225). Measuring only: one tick-time line a minute to `Logs\Timing.log`. |
| `AuctionHouseBot.ItemsPerCycle`, `*.MinItems` / `MaxItems` | 600; 12000 per house | 100; 1200-1400 | 21 Nov (`7949d1d`, #223). Comment: "If searches start to lag, lower this first." |
| `Respawn.DynamicRateCreature` / `DynamicMinimumCreature` | 0.3 / 90 | 1 / 10 | 7 Nov (#67); minimum 60 -> 90 on 8 Nov (`5247909`, #94). More live creatures near players. |

Two code-side notes for the lag work, both **candidates, cost never measured**:

- Catalogue section 3b lists 7 `GetOption` reads directly inside `OnPlayerUpdate`, which upstream calls for every
  player object on every tick (`PlayerUpdates.cpp:324`), bots included. Most sit behind a race check.
- `46-play-time-rewards.ps1` calls its `Interval()` helper (two `GetOption` reads) at the top of `OnPlayerUpdate`,
  **before** the check that skips bots (lines 43-46 and 66-71), so it runs for every bot on every tick.

## 8. Checklists

Every one of these changes server behaviour: **classify with wildcard-change-control first**, respect the hard
stops, and James merges.

### 8a. Add a new setting (for a new or changed patch)

1. **Default in code.** Write `sConfigMgr->GetOption<T>("Family.Knob", default)` in the patch. Existing patches are
   split: the earlier ones default to off and the file turns them on (`BonusStats.Enabled`, `false`); the racials
   and several later ones default to on (`Racials.*`, `true`; `Wildcard.RestingManaRate`, `3.0f`).
   **Proposed practice (not yet adopted by James):** default to stock behaviour in code and switch the feature on in
   `server-settings.txt`. Purpose: the file is applied only while the Wildcard realm is active (realm guard), so the
   default in code is what any other realm run by the same program gets. Motivating facts: the realm guard
   (kit line 192) and roadmap item on per-realm switches (docs/roadmap.md:44).
2. **Name.** Follow the families in use: `Wildcard.<Thing>` for Wildcard-realm features, `Racials.<Name>`,
   `<Feature>.Enabled` plus `<Feature>.<Knob>` (`Mastery.*`, `BonusStats.*`, `PlayTimeRewards.*`), and the module's
   own prefix when patching a module (`AiPlayerbot.Wildcard<Thing>`, `OllamaChat.<Thing>`, `DungeonClear.<Thing>`).
   Put the unit in the name: `Pct`, `Percent`, `PerMille`, `Seconds`, `Minutes`.
   **Proposed practice (not yet adopted by James):** pass the whole name as one string literal. Purpose: the kit
   recognises our options by finding the name inside `worldserver.exe`; a name glued together at run time can never
   be found, so it shows as "unknown" for ever (the 28 predicted in section 5).
3. **Third argument.** Pass `false` only if a missing line is a normal state; otherwise leave it out so a missing
   line shows up as "Missing property" in the report.
4. **Hot paths.** Do not call `GetOption` in code that runs every tick, every packet or for all 750 bots
   (docs/agents/context/patches.md, fault 3). Read it once in a config-load hook into a variable (the pattern at
   wildcard-ability-pool.patch:113-114), or check the cheap conditions (race, timer, `IsBot()`) first.
5. **Add the line to `server-settings.txt`** in the fitting section, with a comment giving: what it does for
   players, date and who asked, the off or stock value, **the allowed range**, and "needs the build with the patch"
   (docs/agents/context/patches.md: "any setting it reads is listed ... with a comment saying which build it needs").
   Choose the config file of the module the code lives in; for core patches use `worldserver.conf`. Keep the file
   ASCII (section 9, trap 6).
6. **CHANGES.md.** Add or extend the patch's row and put the option name in the "Setting" column, every name, not
   "and the ones after it".
7. **Check before pushing** (seconds, instead of finding out after a 2 to 3 hour build):
   ```
   python3 -I .claude/skills/wildcard-settings-and-flags/scripts/settings_catalogue.py --lint
   ```
   Expect: your option absent from "Read by a patch, no line in server-settings.txt", absent from "Patch options
   CHANGES.md never names", and "Hard problems: 0". Do not regenerate the catalogue in the settings PR (see the
   maintenance rule at the end). For the patch itself use the pre-flight in wildcard-patch-authoring.
8. **After the build is installed** (VM): `settings-report.txt` shows the option under "Read by our patched server
   only", no new name under "Unknown", and no "Bad value".

### 8b. Change a value

1. Read the comment above the line: is the new value inside the range it states?
2. Edit the value **and** the comment (date, who, "was X", why). The history table in the catalogue is built from
   these commits.
3. Report what the branch changes:
   ```
   python3 -I .claude/skills/wildcard-settings-and-flags/scripts/settings_change_report.py origin/main my-branch
   ```
4. Classify (section 8d), open the PR, James merges. It applies at the next nightly restart.
5. Auction prices and level limits: expect the relisting side effect (section 3).

### 8c. Retire a setting

1. Decide what should remain. Removing the line from `server-settings.txt` does **not** remove it from the config
   files on the VM: the kit only sets and appends, so the old value stays in force until the manager regenerates
   the file or someone removes it. To switch a feature off, set the off value and leave the line in for at least
   one restart.
2. If the patch that read it is being deleted, remove the line in the same PR as the patch and the CHANGES.md row.
   A leftover line is harmless to the server but will be listed as "Unknown" by the settings check once the new
   build is installed.
3. Run `--lint`.

### 8d. Risk class of a settings change

From docs/agents/context/change-risk.md, quoted: "Standard changes (pre-approved, always LOW without scoring): a
value change to a setting already in `server-settings.txt`, within the range its comment states".

| The change is | Class |
|---|---|
| A new value for a line already in the file, inside the range the comment states | **Standard change: LOW**, no scoring |
| A new value where the comment states no range, or outside it | Not pre-approved. Score it with wildcard-change-control; James merges. **This includes every bot-count change**: the comment on `AiPlayerbot.MinRandomBots` / `MaxRandomBots` records history and states no range (2026-11-22). |
| A new line, a removed line, a different config file | Classify with wildcard-change-control |
| Anything touching a hard-stop area: `realm`, `realmlist`, `BindIP`, `RealmID`, `CoA.AllowRemoteClients`, ports, database connection lines, GM or console options | **HIGH, never automatic, waits for James** (hard stops 1 and 3) |
| `CoABugReport.*` (feeds the relay that holds a GitHub token), `OllamaChat.Url` (an address on the home network) | Possibly hard stops 4 and 3: the document does not name them. Flag and let change control decide |
| The kit itself (`Apply-ServerSettings.ps1`, the `.cmd` files) | Treat as hard stop 5 ("Patch night itself, the build workflow, the installer, or rollback"): the kit runs inside patch night. This reading is ours; change control has the final word |

Open question, stated not resolved: hard stop 2 covers "anything that gives players gold, items, currency,
experience or reputation outside normal play". The document does not say whether moving a rate such as
`Rate.XP.Global` inside its documented range is a standard change or a hard stop. `settings_change_report.py`
points such lines out; change control or James decides.

Why a value change usually scores low when it is scored: impact check I3 "Undo: change a setting back at the next
restart" = 1, likelihood check L1 "a setting within its documented range" = 1. A setting that can stop the server
from starting or make it lag for everyone (thread counts, bot counts, logging) still scores I1 = 3.

`settings_change_report.py` exits 0 only for "value changes only, no hard-stop area matched", and says the range
check is still to do. It decides nothing.

## 9. Known traps

| # | Trap | Story and evidence | Guard |
|---|---|---|---|
| 1 | A core update resets a value we relied on but never listed | The .95 update put `MaxPlayerLevel` back to 80; prestige follows the level cap, so nobody could prestige at 60 (`2a033cd`, 10 Nov, #114). Earlier, `CoAChallenges.GameModes.Realm` was empty on the Wildcard realm, so SQUID created bots in CoA classes (`42290ca`, 30 Oct). | List every value the realm depends on, even when it equals today's default. After a core update read the "Options the .dist lists that our config files do not set" part of the report. |
| 2 | A merge keeps the wrong side of the settings file | On branch `manastorm-xp-75`, merging `main` in kept main's file and silently dropped the branch's own line. PR #218 merged the branch without the line; the repair commit `d9aa1b0` (21 Nov) was pushed just after the merge and is not on `main`. | After merging `main` into a branch, run `settings_change_report.py origin/main <branch>` and confirm your lines are still listed. |
| 3 | The manager switches the bots off on Wildcard | Its Start button forces `AiPlayerbot.Enabled = 0` on Wildcard (`465c928`; README "SQUID's bots on Wildcard"). The kit's own closing message says "Restart the server in the manager to use them", which on Wildcard does exactly that. | Start with `patch-night\Start-Server.cmd` or let patch night do it. |
| 4 | Config files growing on every write | `Get-Content` read the UTF-8 config files as Windows-1252 and they were written back as UTF-8, so each write multiplied every non-ASCII character. After 16 writes `playerbots.conf` was 22 MB instead of 240 KB and a SQUID value with a Cyrillic prefix no longer matched. Fixed 22 Nov (`ba59783`): files are read as UTF-8 (1252 only if not valid UTF-8), written back in the encoding read, and garbled lines are repaired on reading; the commit reports the live file back at 243 KB. | If a config file is suddenly large, look for a kit older than 22 Nov. The kit prints "repaired: N garbled line(s)" when it fixes one. |
| 5 | Editing on the VM | A value edited in a `.conf` is overwritten at the next start; a `server-settings.txt` edited on the VM is overwritten by the next download. | Change it on GitHub. |
| 6 | Non-ASCII characters in `server-settings.txt` itself | The list is still read with plain `Get-Content` (kit line 41), the reader that caused trap 4. Worked out from the code, not observed: an en dash or accented letter in a value would reach the config file garbled. The file is pure ASCII today. | `grep -nP '[^\x00-\x7F]' server-settings/server-settings.txt` must print nothing. **Proposed practice (not yet adopted by James):** keep the file ASCII-only. |
| 7 | Expecting a line to work without its build | The nightly restart applies settings but installs no build; a line for a new patch does nothing until the weekly patch night (or a manual run) installs the build. | Check "First build" in the catalogue against `Core\worldserver.patched-release.txt` on the VM. |
| 8 | Reading "Missing property" as an error | It only means the default in code was used. | Compare the count with the previous run. "Bad value" is the real error. |
| 9 | Removing a line to undo a change | The old value stays in the config file (section 8c). | Set the stock value instead. |
| 10 | End-of-line comments and stray spaces | Everything after `=` is the value. | Comments go on their own line above. |
| 11 | Start-only settings changed "live" | See section 4. | Assume restart unless the table says otherwise. |
| 12 | Setting names are case-sensitive to the server | The kit matches names ignoring case, the server's table does not (upstream `std::unordered_map`). `AiPlayerbot.botActiveAloneSmartScale` really has a lower-case `b`. | Copy names from the `.dist` or the catalogue, never from memory. |

## 10. Other configuration that is not in server-settings.txt

Launcher settings, the secrets file on the VM, the AI chat template, MySQL settings applied as SQL, the scheduled
task parameters, the installer's own line and the build's pins each live elsewhere. Read
`references/other-configuration.md` when the value you want is not a line of the settings file: it names the file
and the owning skill for each.

## Provenance and maintenance

Written 2026-11-22 from the repository at `fcfee51`, with upstream at the pins `resolve_release.py latest` printed
that day (release `server-0.261119.114`: core `c3f2fd4b23`, SQUID bots `4ef5ed9ebe`, Dungeon Clear `6efb59eae9`,
CoA bots `178a7fde6a`). Scripts were run on Linux with Python 3 on 2026-11-22; the PowerShell kit was read, not run. Nothing was
checked on the VM.

Re-verify with (repository root):

| Fact that drifts | One-liner |
|---|---|
| The catalogue is current | `settings_catalogue.py` with the four `--upstream` clones and `--check` (`references/regenerating-the-catalogue.md`) |
| Mismatch counts, file hygiene | `python3 -I .claude/skills/wildcard-settings-and-flags/scripts/settings_catalogue.py --lint` |
| Every option our patches read | `grep -rnoE 'GetOption<[^>]+>\([^,]+' patches/` (108 reads on 2026-11-22; in `.patch` files only `+` lines are ours) |
| Settings line count (270 + 3) | `grep -vc '^\s*\(#\|$\)' server-settings/server-settings.txt` |
| Lines per config file | `grep -v '^\s*#' server-settings/server-settings.txt \| grep '\|' \| sed 's/ *\|.*//' \| sort \| uniq -c \| sort -rn` |
| The file is still ASCII | `grep -nP '[^\x00-\x7F]' server-settings/server-settings.txt` (no output) |
| Where patch night applies settings | `grep -n 'Apply-ServerSettings\|ReportConfigWarnings\|RestoreRealmAddress' patch-night/PatchNight.ps1` |
| Backup count, report wording | `grep -n 'Skip 20\|report.Add' server-settings/Apply-ServerSettings.ps1` |
| Schedule | `grep -n "Day = \|Time = " patch-night/Register-PatchNight.ps1` |
| The standard-change wording | `grep -n 'Standard changes' -A3 docs/agents/context/change-risk.md` |
| History of one setting | `git log --date=short --format='%h %ad %s' -S'MapUpdate.Threads = ' -- server-settings/server-settings.txt` |
| What a branch changes | `python3 -I .claude/skills/wildcard-settings-and-flags/scripts/settings_change_report.py origin/main <branch>` |
| On the VM: the real report | open `C:\Games\CoA Server\server-settings\settings-report.txt`; compare its "Unknown" list with catalogue section 4g |

Open items a later session should close:

1. Compare a real `settings-report.txt` with the 28 predicted names (section 5); then either correct the "0 unknown"
   health rule in docs/agents/context/patch-night.md or teach the kit about run-time names. Both need James.
2. Confirm on the VM whether every run backs up `mod_ahbot.conf` because of the never-list line (section 3).
3. Verify whether SQUID's `AiPlayerbot.*` options take effect on `.reload config`.
4. The `CoA.RealmType` question in section 6.

Maintenance rule: the catalogue is regenerated **when this skill is maintained**, in a skill-maintenance PR of its
own (editing anything under `.claude/skills/` is hard stop 6: HIGH, James merges), with the four pinned clones.
A settings PR runs `--lint` only and never touches `.claude/skills/`; until the next regeneration read live values
from `server-settings.txt`, not from the catalogue. `settings_catalogue.py --lint` and `settings_change_report.py`
are the authority for settings checks; the full pre-merge check set is in `wildcard-validation-and-qa`. When the
kit changes, re-read sections 2, 3 and 5 against it line by line.
