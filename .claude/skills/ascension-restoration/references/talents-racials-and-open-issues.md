# Talents, racials and the open issues

Read this when the broken thing is a talent or a racial rather than a Mystic Enchant, or when you pick up one of
issues #148-#151. Checked on 2026-11-22 against the checkout `fcfee51` (PR #232's head on `62a26e4`; `origin/main`
`d3e030f` differs only under `signup/`).

## Talents: the same method, a different pair of files

| Piece | Where |
|---|---|
| Aura scripts (C++) | `patches/55-talent-fixes.ps1`. One block per talent, registered in the shared script loader in `AscensionAdventurerCache.cpp` (the loader comes from `patches/40-battlegrounds.ps1`, so 40 must run first). |
| Rows that switch them on | `sql/enchants/140-talent-fixes.sql`: `spell_proc` rows registered in `wcme_owned`, and `spell_script_names` bindings. |
| Record | A row in `CHANGES.md` for the patch; "One GitHub issue per talent" (header of patch 55). |

The source hierarchy and the conflict rule are the ones in `SKILL.md` section 1. A talent's tooltip is read the same
way as an enchant's (`.lookup spell id <id>`).

### Worked example that shipped: Backdraft (issue #152, PR #153, merged 14 Nov 2026)

- **Symptom:** the talent's tooltip names four spells that should set it off (three Warlock ones and one Priest
  one) plus a fifth with a particular Mystic Enchant. In play only one did.
- **Cause, from the data:** the stock `spell_proc` row for the talent filters on the Warlock class family and one
  spell's flag. One family filter cannot cover a Priest spell.
- **Fix shape:** the row loses its family filter (`SpellId` `-47258`, negative = every rank; owned so the reset can
  remove it. Deleting file 140 does **not** bring the stock row back: the reset removes ours and nothing
  re-inserts the core's; see `reset-limits.md`), and a small aura script `spell_wcme_backdraft` picks the allowed spells by class family and flags, so
  every rank and every copy of each spell counts. `140` binds the script with `spell_script_names`.
- **Needs a build:** yes (the script is C++). The SQL row alone removes the filter and relies on the script to choose the
  spells (inferred from the two files, not tested), so the two must go live together: see the sequencing warning in `SKILL.md` section 5.
- No in-game result for it is recorded in the repo as of 2026-11-22.

Use it as the template for "tooltip names more triggers than the proc row allows".

## Open issues #148-#151 (opened 14 Nov 2026, still open on 22 Nov): how you would start

No fix exists for any of these. The steps below are a starting plan, not a result. Read each issue first:

```
gh issue view 148 --repo JaTynan/coa-wildcard-mystic     # and 149, 150, 151
```

What the repository itself records about them:

| Issue | What the repo says | Where |
|---|---|---|
| #148 | The Epic copy of Demonic Reoccurence (spell 272730) was found doing nothing in James's talent testing; "that copy's modifiers name no spell". | `enchants/legendary-notes.csv`, row 1570995 |
| #149 | The Epic copy of Demonic Persistence (spell 276506) was reported broken in the same testing. | `enchants/legendary-notes-header.md`, "Open items" |
| #150 | Not in the repository. From the GitHub issue page as read on 22 Nov (not re-checked through the API): Nemesis (63123), no second Hand of Gul'dan cast. | `gh issue view 150` |
| #151 | Not in the repository. From the same read: Master Summoner (18710), Wild Imps do not last longer. | `gh issue view 151` |

All four were opened on 14 Nov by JaTynan with labels talent + warlock and were open on 22 Nov. The issue page
titles #148 "Demonic Recurrence" and #149 "Demonic Persistence", which agrees with the repository's notes above.

### #148, Demonic Reoccurence 272730

1. Tracker row: Epic, audit `standard`, status `working (audit)`, scroll item 200876. Lesson: `standard` means "built
   only from effects the core handles", not "works".
2. Export the spell data (`enchants/export_spell_data.py`) and read 272730's three effects. The note says its
   modifiers name no spell: a spell-modifier aura with an empty class mask changes nothing.
3. Compare with the Legendary copy 1570995, whose modifiers do target the Wildcard Metamorphosis (1147241) and
   were reported working from data in `legendary-notes.csv`.
4. Candidate recipe: R8 "named targets" (rows in `wcme_spellaffect_dbc` naming every learnable Metamorphosis
   version), or a `spell_dbc` copy with the class mask filled in. Which one depends on step 2.
5. Knock-on to check: `sql/enchants/001-twin-links.sql` links the Legendary 1570995 **to** 272730 as its "working
   twin". If 272730 does nothing, that link adds nothing; if 272730 is repaired, the Legendary gets its effect a
   second time. Decide which copy carries the effect before changing either.
6. Record the source (client data), any assumption, and add a checklist row: `.aura 272730`, then what the tooltip
   promises about Metamorphosis.

### #149, Demonic Persistence 276506

1. Tracker row: Epic, audit `standard`, status `working (audit)`, scroll item 201334; `epic-history.csv` shows no
   change by us.
2. A lead already in the repo: `enchants/core-rule-version-gaps.csv` has a row for 276506 (effect 0, rule 0, event
   `cast`): the core's rule lists 23 spells and leaves out two versions a player here can learn (1108092, 1129722),
   status `to review`. If the reported failure is "nothing happens when I cast the ability", check whether the
   character had one of those two versions.
3. The Legendary of the same name (990130) is a different design, scripted in `046-legendary-gaps.sql`. Do not copy
   its behaviour onto the Epic without a source.
4. If the lead holds, the fix pattern is the one used for other version gaps (`core-version-gaps.csv`, status
   `covered`): our rule runs only when the core's own test fails, so nothing doubles. That is C++: hand to
   wildcard-patch-authoring.

### #150 (Nemesis 63123) and #151 (Master Summoner 18710)

Nothing in the repository describes these two. Start the same way: issue text, tracker or talent id, exported
data, core overlap check, then the decision tree. Both are talents by their labels, so the home is patch 55 +
file 140. Possibly related, UNVERIFIED: the Legendary Hand of Gul'dan (1398206) has an open item "check that the
Wild Imps appear" in `enchants/legendary-notes-header.md`.

## Racials: new designs built with the same machinery

The race kits are **not** archaeology. They are James's own design (settled 13 Nov 2026, `docs/race-kits.md`): every
race keeps its stock racials and gains one signature passive. The doc is the specification; its tables are the
"tooltip" that wins.

| Piece | Where |
|---|---|
| Design, numbers, balance notes | `docs/race-kits.md` |
| C++ | one patch per racial: `52-racials.ps1`, `54` Plainsrunning, `56` Bloodrush, `57` Ambush, `58` Voodoo Regeneration, `59` Radiant Presence, `62` spellbook entries, `72` Grave Defiance, `73` Spellsword, `74` Overclock, `75` Arcane Hunger, `76` Prospector's Spirit, `80` the `.racial` status command, `89` Stoneform |
| Our own spells (buffs, spellbook entries) | defined once in `client-patch/custom_spells.py`, ids from 9990001 |
| Server rows | `sql/enchants/150-custom-spells.sql`, **generated** by `custom_spells.py`; never edit by hand |
| Client rows | the client patch built by `client-patch/build_client_patch.py` (not published) |

What carries over from enchant work: one definition feeding both client and server so they cannot disagree; rows
owned through `wcme_owned`; a setting per feature where practical; the same in-game test habit (`.racial` prints the
numbers the buff icons cannot show).

Enchant helper spells live in the same generator (9990018 Stored Time, 9990019 the Hot Hands mark, 9990021,
9990022-9990025, 9990026): a new hidden helper for an enchant is added there, then 150 is regenerated with
`python3 -I client-patch/custom_spells.py > sql/enchants/150-custom-spells.sql`. The script's usage line names a
`<Spell.dbc>` argument, but the code does not read it: no client file is needed (run with no argument on
2026-11-22, its output was identical to the committed file 150). Home: `wildcard-client-and-web`.

For anything beyond this pointer, use wildcard-patch-authoring (the C++) and wildcard-client-and-web (the client patch).
