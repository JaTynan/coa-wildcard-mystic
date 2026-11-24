# Worked classifications of five real merged PRs

Read this before your first classification, or when unsure how a check is scored.

**What these are.** Retrospective teaching examples written on 2026-11-22. None of these PRs was classified when
it was merged: the matrix was written on 22 Nov 2026 (PR #232, merged that evening) and all five were merged by
James before or without it. The scores are this skill's reading of `docs/agents/context/change-risk.md`, not
rulings by James or Fable. Where a score is arguable it says so; "when in doubt, take the higher" was applied.

Reproduce the facts for any of them:

```bash
python3 -I .claude/skills/wildcard-change-control/scripts/change_facts.py facts --merge <merge-commit>
git show <commit>          # the change and its full message
```

| # | PR | Kind | Merge commit | Class |
|---|---|---|---|---|
| 1 | #217 `bots-750` | Settings value change | `0e40f47` | LOW |
| 2 | #33 `fix-steed-charge` | Enchant SQL fix | `9ecead9` | MEDIUM |
| 3 | #200 `rune-currency-tab` | C++ patch on a hot path | `ab03e0a` | HIGH |
| 4 | #186 `patch-night-realm-databases` | Patch night change | `67e2bc8` | HIGH (hard stop 5) |
| 5 | #68 `signup-page` | Accounts and sign-up | `a19bab4` | HIGH (hard stops 1, 3, 4, 5) |

---

## 1. PR #217: 750 bots instead of 1,000 (settings value change)

Commit `6a3e017`, 21 Nov 2026. Two lines in `server-settings/server-settings.txt`:
`AiPlayerbot.MinRandomBots` and `AiPlayerbot.MaxRandomBots` from 1000 to 750, with a comment giving the reason
(worst ticks of 2 to 5 seconds with 2 players on, median 36 ms).

**Is it a standard change?** The rule needs "a value change to a setting already in `server-settings.txt`, within
the range its comment states". The settings exist. The comment states a reason and the previous value, not a
range. Read strictly, it is not pre-approved, so it is scored. (Proposal P9 in SKILL.md exists because of this.)

```
Change: PR #217 (bots-750)
Hard stop: none
Impact: I1 2, I2 2, I3 1, I4 1 -> medium
Likelihood: L1 1, L2 1, L3 1, L4 1, L5 2, L6 1 = 7 -> low
Class: LOW        Confidence: high (see note on I2)
Path: LOW. Intended: automatic, live at the next 3:30 am patch night. Today: James merges (automatic merge NOT BUILT YET).
Evidence:
  I1 2: bots are a system most players use (the matrix names bots in the 2 column).
  I2 2: bot characters are world-side data SQUID's module recreates; no player data. Taken as 2, not 1, because
        what the module does with surplus bots when the cap drops was not read in its code.
  L5 2: fewer bots meaning less load is plausible; the cause of the spikes was not established.
```

Why the other scores are 1: I3, a setting goes back at the next restart. L1, a setting, and 750 sits inside values
already run (1,500, 1,250 and 1,000). L2, five lines in one file. L3, read once at start. L4, the settings report
checks the names at the restart. L6, the bot count had been changed cleanly three times before (#53, #57, 9 Nov).

Lesson: a settings change can still have medium impact. Impact medium with likelihood low is LOW on the matrix.

---

## 2. PR #33: Divine Steed mounts you; Arcane Charge no longer refused at range (enchant SQL fix)

Commit `29eac6a`, 2 Nov 2026, 21:46. `sql/enchants/013-action-fixes.sql` (22 lines changed) and three rows of
`enchants/tracker.csv`. It rebuilds two placeholder spells as `spell_dbc` rows (so the taught spell mounts the
player and raises speed) and changes one field of an earlier rebuilt row for Arcane Charge.

**Is it a standard change?** "An enchant SQL fix re-applying an existing pattern." The file and the
`wcme_owned` pattern existed. But these are hand-built spell rows with new effects, not another row of a proven
kind such as a twin link. Treat it as not standard and score it. What happened next supports that: the Arcane
Charge retarget this PR adjusted was reverted 12 minutes after the merge (#34, `d2ebbdb`: "Retargeting it at the
Charge target broke the whole helper") and redone another way by #35.

```
Change: PR #33 (fix-steed-charge)
Hard stop: none
Impact: I1 1, I2 2, I3 1, I4 2 -> medium
Likelihood: L1 2, L2 2, L3 2, L4 3, L5 1, L6 1 = 11 -> medium
Class: MEDIUM        Confidence: high
Path: MEDIUM. Fix and Opus review; James merges.
Evidence:
  I2 2: world database rows that 000-reset.sql removes and the files re-apply at every start.
  I4 2: a mount-speed ability starts working for holders of two enchants: a small balance shift.
  L1 2: database data.
  L2 2: 22 lines of SQL in one file (over ~20).
  L3 2: the spell data is used each time a player casts.
  L4 3: no automatic check exists for an enchant; it can only be seen working in game.
```

Why the 1s: I1, two enchants. I3, delete the lines and the next start removes the rows. L5, the commit message
records the test that showed the cause ("Tested 2 Nov: Divine Steed's taught spell was a placeholder buff").
L6, earlier files already inserted `spell_dbc` rows the same way.

Lesson: L4 = 3 is what lifts most enchant work to MEDIUM today. A real check (see `wildcard-validation-and-qa`)
would lower it.

---

## 3. PR #200: Runes of Descension move into the currency tab (C++ patch on a hot path)

Commit `b4f61e9`, 20 Nov 2026. New `patches/82-runes-in-currency-tab.ps1` (120 lines), new
`sql/enchants/160-rune-currency.sql` (7 lines), three lines in `CHANGES.md`. The patch adds a timer field to
`Player` and a script with `OnPlayerLogin` and `OnPlayerUpdate` hooks: at login and every 2 seconds it scans the
backpack and bags and moves any rune stack into the currency slots. CHANGES.md lists it as "always on" (no
setting to turn it off).

**Hard stops looked at.** Stop 2 (gives currency): no, it moves runes the player already owns. Stop 7 (rewriting
character data): it changes a character's inventory through the game's own item functions at run time, not by
SQL on the characters database. Read by the letter, no stop applies. It is close enough to both that the
classification says so and confidence is low.

```
Change: PR #200 (rune-currency-tab)
Hard stop: none (close to 2 and 7: see above)
Impact: I1 3, I2 3, I3 2, I4 2 -> high
Likelihood: L1 3, L2 2, L3 3, L4 3, L5 2, L6 2 = 15 -> high
Class: HIGH        Confidence: low (hesitated on whether hard stop 7 applies, and on I3 between 2 and 3)
Path: Low confidence: Fable classifies from a case file. As HIGH: fix, Fable review (patch-reviewer), James merges.
Evidence:
  I1 3: OnPlayerUpdate runs for every player and every bot; a fault there stops or slows the server for everyone.
  I2 3: it moves item stacks in character inventories (character data).
  I3 2: no setting; undo is revert and rebuild (2-3 h). Runes lost or doubled by a bug could not be undone (3).
  I4 2: currency handling; an error would cost or gain players runes.
  L1 3: server C++.
  L2 2: 127 lines in two files.
  L3 3: every tick for every player and bot (a timer increment each tick, the bag scan every 2 s). The diff
        shows no bot guard.
  L4 3: nothing tests it before it is live; compiling only proves it builds.
  L5 2: the cause (the client counts only currency slots) is argued from client behaviour, plausible.
  L6 2: similar server-side item handling had gone in (30-wildcard-rewards), not the same kind.
```

Lesson: for any C++ that runs every tick, I1 is 3 and L3 is 3, which makes the change HIGH almost regardless of
the rest. The `patch-reviewer` checklist item "does it cost anything on a hot path" is aimed at exactly this.
Contrast: PR #189 (`273d36d`, patch 77, 25 lines) reads a setting inside `Player::UpdateManaRegen`, which its own
comment says runs when a character's regeneration is worked out (log-in, stat and aura changes): L3 = 2, not 3.

---

## 4. PR #186: patch night keeps server starts on the active realm's databases (patch night change)

Commit `d5412a9`, 19 Nov 2026. `patch-night/PatchNight.ps1` (+16) and `patch-night/launcher_bridge.py` (+46, -2).
It fixed a live incident: after a manager update, patch night brought the Wildcard realm up on the other realm's
characters. It adds a guard (`OnActiveRealm`) that refuses to start the world on the wrong databases.

**Hard stop 5 applies** (patch night itself). The class is HIGH and it is never automatic, whatever the scores.
The scores are still worth writing: they tell James what to look at.

```
Change: PR #186 (patch-night-realm-databases)
Hard stop: 5 (patch night itself)
Impact: I1 3, I2 3, I3 1, I4 1 -> high
Likelihood: L1 2, L2 2, L3 1, L4 3, L5 1, L6 2 = 11 -> medium
Class: HIGH        Confidence: high
Path: HIGH by hard stop. Review, then James merges. Never automatic, in phase 1 or phase 2.
Evidence:
  I1 3: a wrong guard means the server does not start for anyone at 4 am.
  I2 3: the script decides which characters database the world opens.
  L1 2: scripts.
  L2 2: 62 lines in two files.
  L4 3: patch night can only be proven by a real run on the VM.
  L6 2: patch-night changes had gone in before; wrapping the manager's own start routine was new.
```

Reviewer: this is not security-adjacent, so the HIGH path's Fable review applies in principle; the Fable
`patch-reviewer` agent itself only takes PRs that touch `patches/` and would decline this one, so it needs a case
file or an Opus review. That gap in the documents is recorded, not resolved.

Lesson: the fix for an emergency is still a hard-stop change. Being urgent changes who is asked first, not the class.
Also note there is no delay for `patch-night/` changes: the new `PatchNight.ps1` runs the same night it is merged
(`PatchNight.ps1:742-754`; table in `wildcard-run-and-operate`), which is why hard stop 5 exists.

---

## 5. PR #68: friends' sign-up page (accounts and sign-up)

Commit `a4ccee9`, 7 Nov 2026. New `signup/WildcardSignup.py` (309 lines), `Register-WildcardSignup.ps1` (opens a
firewall rule, registers a scheduled task), `signup/README.md`, ten lines in `PatchNight.ps1` so patch night
keeps the service current and restarts it, and a link on the site. Accounts are created through the server
manager's own one-account command. Secrets (Turnstile keys, invite codes) stay in `signup-settings.json` on the VM.

```
Change: PR #68 (signup-page)
Hard stop: 1 (creates accounts), 3 (firewall rule, Cloudflare tunnel route), 4 (reads signup-settings.json), 5 (edits PatchNight.ps1)
Impact: I1 2, I2 3, I3 3, I4 1 -> high
Likelihood: L1 2, L2 3, L3 2, L4 3, L5 2, L6 3 = 15 -> high
Class: HIGH        Confidence: high
Path: HIGH by hard stop. Security-adjacent, so the review goes to Opus, not Fable. James merges. Never automatic.
Evidence:
  I1 2: a public web page in front of account creation; patch night restarts it.
  I2 3: it creates rows in the auth database.
  I3 3: accounts created by an abuser exist until someone removes them.
  L1 2: a script (Python service, PowerShell set-up).
  L2 3: about 400 lines in eight files.
  L3 2: runs per sign-up request.
  L4 3: only provable live, behind the tunnel.
  L5 2: design reasoned from the manager's command, not from a test.
  L6 3: the first internet-facing service in the repo.
```

Housekeeping the facts script cannot see but a reviewer should: this PR also committed a compiled Python file
(`signup/__pycache__/WildcardSignup.cpython-313.pyc`). `__pycache__/` is in `.gitignore`, yet three `.pyc` files
were still tracked on 2026-11-22 (`git ls-files | grep pyc`).

Lesson: several hard stops can apply at once; name them all. And "HIGH = Fable review" has an exception written in
`docs/agents/README.md`: security-adjacent work goes to Opus.

---

## Scoring habits these examples show

1. Check hard stops first and name every one that applies.
2. Standard changes are narrow. If you have to argue that something is "the same pattern", score it.
3. Impact is the single worst check. One 3 makes impact high.
4. Likelihood is a sum. L1, L3 and L4 do most of the work: C++ on a per-tick path with no test is already 9 of
   the 13 needed for "high".
5. Write an Evidence line for every score above 1. If you cannot, you could not score it from evidence, and
   confidence is low.
6. Totals of 8, 9, 12 or 13 sit on a band edge: confidence is low (this skill's reading of "within one point of
   a band edge"; see proposal P10).
