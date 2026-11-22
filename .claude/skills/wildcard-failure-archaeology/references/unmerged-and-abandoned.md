# Chronicle: unmerged branches, lost commits and things reversed later

Three ledgers:

1. every remote branch that is truly not merged into `origin/main`, what it holds and its apparent status;
2. commits pushed to a branch after its pull request had already merged (eight cases; four never reached `main`);
3. changes that a later commit reversed, replaced or tuned back.

All of it is as of 2026-11-22 (`origin/main` at `d3e030f`). Pull request states on GitHub (open or closed) were
**not** read for this file: only git history was. Where a status depends on GitHub or on James's intent it says
"status unknown - ask James".

## How this was worked out (repeat these to re-verify)

```bash
# 1. Branches not merged into main
git branch -r --no-merged origin/main

# 2. For one branch: its own commits, and whether main already holds the same change
#    "+" = not on main, "-" = an identical change is on main under another commit
git cherry -v origin/main origin/<branch>

# 3. Is the *content* on main even though the commit is not? Search main for a setting or a phrase
git grep -n '<setting name or phrase>' origin/main -- .
git log origin/main --oneline -S'<exact text>' -- <file>

# 4. All three at once, plus the "pushed after the merge" flag
python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py branches
```

`git cherry` compares changes, not names, so a change that was redone slightly differently on `main` shows as
"+". Step 3 is what tells "superseded" from "lost".

---

## 1. Unmerged and abandoned branches

25 remote branches are not merged into `origin/main` (26 with `pr-232`, which is the same commit as
`agents-stage-1`).

### The `for-083` family (old core, never to be merged)

| Branch | Tip | Own commits not on `main` | Status |
|---|---|---|---|
| `for-083` | `869bd0f`, 9 Nov | `ebc3c3d` (the undo), `8fd3d00`, `a7c6fb5`, `f3f7bb0`, `9e3170e` | **Abandoned on purpose.** The build branch for release .83. README.md: "It goes away once the server moves to a newer release." The server has since moved on (.95, then .114), and the last .83 build is build 20 (8 Nov). Never merge it either way. Deleting it: ask James. |
| `free-training-083` | `e6cf1d8`, 8 Nov | subset of the above | Merged into `for-083` as PR #89. Leftover. |
| `bots-team-opposing-083` | `f3f7bb0`, 8 Nov | subset | Merged into `for-083` as PR #92. Leftover. |
| `bots-attack-mercenaries-for-083` | `5853c99`, 8 Nov | subset | Merged into `for-083` as PR #103. Leftover. |
| `scrolls-to-currency-for-083` | `9e3170e`, 8 Nov | subset | Merged into `for-083` as PR #106. Leftover. |
| `bots-resurrect-for-083` | `1c13230`, 8 Nov | subset | Merged into `for-083` as PR #108. Leftover. |

Every `for-083` change has a twin on `main`, made for the newer core:

| `for-083` commit | What | Twin on `main` |
|---|---|---|
| `8fd3d00` | bot levels near real players | `65d7a66`, PR #47 |
| `a7c6fb5` | free class training | `bcdf147`, PR #90 |
| `e6cf1d8` | spirit guides raise every ghost | `0bc4d94`, PR #90 (identical change) |
| `938ea7e` | bots tell friend from foe by team | `7532277`, PR #93 (identical change) |
| `f3f7bb0` | card drops weighted by quality | `4444b55`, PR #93 |
| `5853c99` | bots attack same-faction Mercenaries | `f4c833a`, PR #104 (identical change) |
| `9e3170e` | scrolls straight to the scroll count | `0b11527`, PR #107 |
| `1c13230` | bots raise the dead | `544e07f`, PR #112 (identical change) |

So nothing of value is stranded on the `for-083` family.

### Branches that hold something `main` does not

| ID | Branch | Tip | What it holds | Is the content on `main`? | Status |
|---|---|---|---|---|---|
| U-01 | `xp-kill-rate` | `225f5f7`, 14 Nov | `Rate.XP.Kill = 0.9273` (kill XP 15% lower: "Levelling 20-40 took about three hours on a first prestige with a weak build") | No. `main`'s settings have no `Rate.XP.Kill` line | Never merged. **Status unknown - ask James.** Later XP work went the other way for groups (PR #219). |
| U-02 | `bot-group-xp` | `da53c03`, 14 Nov | `patches/57-bot-group-xp.ps1`, setting `Wildcard.BotsTakeNoGroupXP`: bots in a player's group take no share of kill XP ("A player with four bots got about 28% of solo kill XP") | No. Neither the patch nor the setting is on `main` | Never merged. The same complaint (groups earn far less XP) was answered a week later by a different design: `patches/93-group-xp.ps1`, PR #219 (`c48fbf9`), which covers Manastorm, dungeons, raids and battlegrounds, not the open world. **Apparently superseded in part; status unknown - ask James.** If revived, the number 57 is now taken by `57-racial-ambush.ps1`. |
| U-03 | `manastorm-xp-75` | `d9aa1b0`, 21 Nov | `Manastorm.ExperienceRate = 0.75` in `server-settings.txt` | **No.** PR #218 merged this branch, but the setting is not in `main`'s `server-settings.txt` | **Lost in a merge, still wanted by the look of it.** See section 2. Ask James, then re-apply through a new pull request. |
| U-04 | `tauren-juggernaut` | `916d715`, 21 Nov | Running with the Herd: reach 30 yards (`b856fb4`), then 18 (`18239b7`), hold 3 sec out of range (`916d715`) | No. `main` (`CHANGES.md`, `docs/race-kits.md`) still says 10 yards | Pushed after PR #213 merged. **Lost; apparently still wanted** (each commit quotes James's reason). Ask James. |
| U-05 | `faster-settings` | `a3eb865`, 22 Nov | `5978ee4`: the settings check recognises setting names built at run time and settings only the website reads. `a3eb865`: sign-up page window (title, start-up report, one line per request, a port clash is reported) | `5978ee4`: no. `a3eb865`: partly; `main` has the later status board from PR #231 (`5dfb9a7`), a different commit | Pushed after PR #229 merged. **Status unknown - ask James.** Going by `5978ee4`'s title, `main`'s settings check does not yet recognise names built at run time. |
| U-06 | `site-redesign` | `428a390`, 21 Nov | Home page "Top players" shows Most prestige, not Highest level | No | Pushed after PR #212 merged. **Lost; apparently still wanted.** Ask James. |
| U-07 | `perf-visibility-react` | `0cd1413`, 8 Nov | `Visibility.Distance.Continents = 75` | No. `main` sets 100 | Never merged, never measured. **Status unknown - ask James.** See F-06 in `references/performance-and-bots.md`. |
| U-08 | `export-v2` | `a6b487b`, 31 Oct | `enchants/export_spell_data.py` also exports namesakes of exported spells | No. `main`'s script has no namesake code | Never merged. The namesake recipe (file 008) was written anyway. **Status unknown - ask James.** |
| U-09 | `docs/patch-night-build51` | `4893a38`, 18 Nov | Regenerated legendary history recording build 51's install | The data is on `main`: `legendary-history.csv` there has 10 rows with build 51 live on 2026-11-18, from later regenerations | **Superseded** by later regenerations on `main` (for example `b83bdf9`). |
| U-10 | `agents-stage-1` (= `pr-232`) | `fcfee51`, 22 Nov | `.claude/agents/` (three agents) and `docs/agents/` (context packs, case file template, ledger, risk matrix) | No | **In flight:** pull request #232, not merged as of 2026-11-22. Note that `docs/agents/*`, quoted in several places in this chronicle, exists only on this branch until it merges. |

### Branches whose content is already on `main`

| Branch | Tip | Why it shows as unmerged | Status |
|---|---|---|---|
| `progression` | `84ed1a2`, 30 Oct | One commit (double reputation) landed two seconds after PR #13 merged | **Superseded:** `Rate.Reputation.Gain = 2` reached `main` in `1f12f22` (PR #14) |
| `launcher-date-fix` | `233669f`, 8 Nov | web.config fix pushed after PR #72 merged | **Superseded:** identical change on `main` as `c3b4125` (PR #74) |
| `world-pvp-bots` | `f3f9170`, 8 Nov | zone waking back on, pushed after PR #94 merged | **Superseded:** identical change on `main` as `c02ba12` (PR #95) |
| `case-of-fortune` | `b87f512`, 10 Nov | first Case of Fortune fix | **Superseded:** identical change on `main` as `6c4bba6` (PR #115); the fix itself was replaced in PR #120 (G-02) |
| `race-kits-human-torrent` | `24cf303`, 13 Nov | Dwarf exploration commit pushed after PR #141 merged | **Superseded:** identical change on `main` as `3c56f12` (PR #142) |
| `racial-grave-defiance`, `racial-spellsword`, `racial-overclock`, `racial-arcane-hunger` | 19 Nov | Stacked pull requests #181 to #184 were merged into each other, not into `main`; the tips are those merge commits | **Superseded:** no file differs from what reached `main` through PR #180 and PR #185 (`race-kits-to-main`). `git cherry` lists nothing. |

Safe to delete, as far as git can tell: every branch in this last table and the five `*-083` leftovers. Deleting
a branch is James's call.

---

## 2. Commits pushed after the merge

The pattern: a pull request is merged, then one more commit is pushed to the same branch. GitHub does not add it
to `main`. It reaches `main` only if someone opens a second pull request.

| # | Date | Branch (merged as) | Late commit | Reached `main`? | How |
|---|---|---|---|---|---|
| 1 | 30 Oct | `progression` (PR #13) | `84ed1a2` double reputation | yes | redone inside PR #14 |
| 2 | 8 Nov | `launcher-date-fix` (PR #72) | `233669f` web.config | yes | redone as PR #74; `12f7f93` says it "missed #72" |
| 3 | 8 Nov | `world-pvp-bots` (PR #94) | `f3f9170` zone waking back on | yes | redone as PR #95 |
| 4 | 13 Nov | `race-kits-human-torrent` (PR #141) | `24cf303` Dwarf exploration | yes | redone as PR #142 |
| 5 | 21 Nov | `manastorm-xp-75` (PR #218) | `d9aa1b0` "Manastorm XP at 75% again" | **no** | see below |
| 6 | 21 Nov | `tauren-juggernaut` (PR #213) | `b856fb4`, `18239b7`, `916d715` | **no** | U-04 |
| 7 | 21 Nov | `site-redesign` (PR #212) | `428a390` | **no** | U-06 |
| 8 | 22 Nov | `faster-settings` (PR #229) | `5978ee4`, `a3eb865` | **no** | U-05 |

The four most recent are the four that are missing.

### Case 5 in full: a merged pull request that changed nothing

- **Symptom:** PR #218 "Manastorm XP: 75% of full instead of 30%" is merged, yet `main`'s `server-settings.txt`
  has no `Manastorm.ExperienceRate` line. As far as the repository shows, the realm is still on the core's 30%.
- **Root cause:** the branch's first commit (`02f4be3`) added the setting. The branch then merged `main` into
  itself (`cbd1a9b`) and "the merge with main kept main's settings file", dropping the three lines. PR #218 was
  merged in that state (`5b21c4d`). The repair, `d9aa1b0` "Manastorm XP at 75% again", was pushed afterwards.
- **Evidence:** `git show origin/main:server-settings/server-settings.txt | grep -c ExperienceRate` prints 0;
  `git show cbd1a9b:server-settings/server-settings.txt | grep -c ExperienceRate` prints 0;
  `git merge-base --is-ancestor d9aa1b0 origin/main` fails.
- **Status:** **open.** Not on `main` as of 2026-11-22.
- **Lesson:** two failures stacked: a merge that silently dropped the branch's only change, and the fix pushed
  after the pull request was closed.

**Proposed practice (not yet adopted by James):** after any merge, run
`python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py branches` and look for lines
starting with `!`. Purpose: catch a commit that was pushed after its pull request merged before it is forgotten.
Motivating incidents: the eight rows above, four of them still missing. How to act on a hit belongs to
`wildcard-change-control` (a new pull request; James merges).

---

## 3. Reversed, replaced or tuned back by a later commit

### Reverted or undone outright

| Date | What was undone | By | Why (as written) | Chronicle entry |
|---|---|---|---|---|
| 31 Oct | 22 of batch 1's twin links | `3a141df`, PR #19 | they "never fired" | E-02 |
| 1 Nov | Patch night stopping when the manager kept our world server | `0736bae`, PR #30 | go by the auth server instead | P-07 |
| 2 Nov | Arcane Charge retarget (`52a235a`, `29eac6a`) | `d2ebbdb`, PR #34 | "broke the whole helper" | E-07 |
| 2 and 3 Nov | 24 namesake teaches | `767ca36` PR #32, `57c8c67` PR #39 | they taught "an effect piece, not the ability" | E-06 |
| 2 Nov | The roll hold on rebuilt enchants (file 010) | `34083eb`, PR #36 | the client patch now carries the spells | E-09 |
| 5 Nov | Merge of `main` into `for-083` | `ebc3c3d` | "main's patches are for the .90 core" | B-04 |
| 8 Nov | Temporary slow-query log (`091-slow-query-log.sql`) | `ea01588`, PR #86 | it had found the cause | F-04 |
| 8 Nov | Zone waking off | `c02ba12`, PR #95 | "bots near players froze" | F-07 |
| 8 Nov | Pete Arr's free Scrolls of Fortune (`Wildcard.FreeScrolls = 1`, 31 Oct) | `549192a`, PR #105 | "Remove Pete Arr" (no reason given) | none |
| 9 Nov | View distance 150 | `ff00757`, PR #113 | "backed out before it went live, while chasing lag spikes" | F-08 |
| 12 Nov | First Case of Fortune fix | `6ccb7b4`, PR #120 | "it never ran" | G-02 |
| 16 Nov | Deadly Bite blanked and linked to a twin (file 004) | `8cdfebf`, PR #169 | it is "Ascension's real version, not a placeholder" | E-12 |
| 17 Nov | Flowing's proc script and `spell_proc` row | `7910784`, PR #178 | the core's rule already builds the stacks | E-15 |
| 17 to 18 Nov | Our scripts, links and proc rows for the enchants listed in E-13 | review commits in PR #178 | the core already does them | E-13 |
| 18 Nov | Hand edit of `150-custom-spells.sql` | `f5073f2`, PR #180 | the generator had to retire the rows too | E-17 |
| 20 Nov | Wisdomball removed from vendors (by the core) | `486f9c3`, PR #201 | "a questline that doesn't exist" | B-15 |

### Tuned back or replaced (design decisions, not bugs)

Listed so that an older value is not "restored" by mistake. The right-hand value is current unless noted.

| Date | Setting or design | Went from | To | Evidence |
|---|---|---|---|---|
| 6 to 7 Nov | Bot count | 1,000, 1,500, 1,250 | 1,000 (9 Nov), 750 (21 Nov) | `references/performance-and-bots.md` |
| 7 Nov | AI chat model | `qwen3.6:27b` (`6422345`), "8B model" (`4e1f3f0`) | `gemma3:12b` (`35b1bea`, PR #64) | commits named |
| 7 Nov | SQUID's canned quest lines | off (`08f8f2f`, PR #48) | back on "with fewer quest lines" (`4e1f3f0`, PR #50) | commits named |
| 7 Nov | SQUID's emote chain reactions | on | off (`8c73e88`, PR #55); bot gestures cut after "six emotes in three seconds" (`dc2a5da`) | commits named |
| 7 Nov | Runes of Descension rate | "every zone a quiet 300%-runes test zone" (`f42a9ba`) | separate quest and drop scaling, then 250% quests / 150% drops (`bc24d6a`, `971068d`, PR #69) | commits named |
| 7 to 8 Nov | Open-world respawn floor | 60 s (`e659ebc`, PR #67) | 90 s: "slower characters were overwhelmed clearing hard spots" (`5247909`, PR #94) | commits named |
| 8 Nov | Auction price multipliers | rare 6x, epic 10x, bags 40x / 200x (`b9b0aee`) | rare 4x, epic 8x, bags 30x / 150x, "James's numbers" (`3f95f33`, PR #102) | commits named |
| 8 Nov | MySQL log flush | once a second (`61a5be9`) | every 3 s (`a55aaea`) | F-05 |
| 12 Nov | Offline rested XP | 20x (`2cd2a78`) | a level per 16 h in an inn (`bf3e353`), then 14.4 h (`b06519c`, PR #123) | commits named |
| 12 Nov | Weekend bonus | double XP and reputation (`a018067`) | "XP off" (`1a3cc14`, PR #121); all theme rates 2 to 3 (`018b2d7`, PR #209) | commits named |
| 12 Nov | Auction bot scrolls and gems | classic scrolls 3x, gems to item level 65 (`c8bbc89`) | only low-end scrolls and raw gems (`b73802e`, PR #126) | commits named |
| 13 Nov | Insignia gold | about 10 silver a body (`0ab2d27`) | 1 silver per level of the dead player (`14dc402`, PR #136) | commits named |
| 13 Nov | Race kits | two actives and two passives per race | "stock racials plus one signature passive each; first design dropped" (`a242a1f`, PR #139) | `docs/race-kits.md` |
| 16 Nov | Curse of Arugal's Darkness | 8% per stack (`730ecea`) | 4% per stack, 20% at 5 (`75129f8`, PR #169) | commits named |
| 16 Nov | Mana Fiend Intellect | +30% (`672e3c1`) | +25% "as the community wiki lists it" (`2029a99`) | commits named |
| 20 to 21 Nov | Undead ghoul gate | 10 min debuff "Grave Hunger" (`89d4e7a`) | 20 Grave Feast charges (`d15f197`) | commits named |
| 21 Nov | Stoneform | flat 8% less spell damage (`40ec678`) | magic resistance (`710ca91`) | commits named |

---

## 4. Pull request numbers that never merged into `main`

From the merge commits on `main`, these numbers between 1 and 232 have no merge: 78, 89, 92, 103, 106, 108, 109,
137, 148, 149, 150, 151, 152, 154, 155, 179, 181, 182, 183, 184, 193, 194, 195, 196, 197, 198, 232.

| Numbers | What git shows |
|---|---|
| 89, 92, 103, 106, 108 | merged into `for-083`, not `main` |
| 181, 182, 183, 184 | stacked race-kit pull requests merged into each other; content reached `main` through #180 and #185 |
| 109 | `1e52bc7` (PR #112) says it "Includes the resurrection and Manastorm changes from #109" |
| 193 | `d407b9f` (PR #199) says it "Carries #193 (Overclock) too" |
| 148 to 151, 152 | GitHub issues, not pull requests: `enchants/legendary-notes-header.md` cites "issue #148" and "issue #149"; `CHANGES.md` (row for patch 55) and the header of `patches/55-talent-fixes.ps1` name issue #152 |
| 232 | the agents pull request, not merged as of 2026-11-22 |
| 78, 137, 154, 155, 179, 194 to 198 | **nothing in git names them.** They may be closed pull requests or issues. To find out: `gh pr view <number>` or `gh issue view <number>`. Do not guess which unmerged branch belongs to which number. |
