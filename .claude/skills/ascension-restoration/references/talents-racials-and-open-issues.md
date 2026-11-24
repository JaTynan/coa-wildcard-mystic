# Talents, racials and the open issues

Read this when the broken thing is a talent or a racial rather than a Mystic Enchant, or when you pick up one of
issues #148-#151 (fixed 23-24 Nov). Checked on 2026-11-22, updated 2026-11-24, against the checkout `fcfee51` (PR #232's head on `62a26e4`; `origin/main`
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

## Issues #148-#151: fixed 23-24 Nov 2026, not yet verified

All four warlock talent issues have merged fixes in `patches/55-talent-fixes.ps1` and
`sql/enchants/140-talent-fixes.sql`. James does not test by hand: a fix stays **unverified** until a player
report or an automated test says otherwise (see "Testing policy" in `wildcard-validation-and-qa`). The C++ parts
need the build after 24 Nov; the SQL parts went live at the next start.

| Issue | Talent | What was wrong | Fix | PR |
|---|---|---|---|---|
| #151 | Master Summoner 18710 | The Wild Imp bonus (2.5 s / 5 s) sits in hidden companion spells 818709, 818710 that nothing applied, and which have a mask but were never linked | Aura links talent rank -> companion. No named targets were needed: the companion's mask already selects Hand of Gul'dan (an early read said otherwise; it was the mask misread, see the spell-system reference) | #243 |
| #148 | Demonic Recurrence 272730 | Cooldown cut, armour loss and crit drawback sit in companions 272731, 272733; 272733 named only the CoA-class helper | Aura links 272730 -> 272731, 272733; named target 272733 -> 54879 (the Hero Metamorphosis helper); owned `spell_dbc` copy of 272731 with effect 3 blanked (its counterpart uses aura 341, honoured only for an allowlist). The twin-linked enchant 1570995 gains the same | #252 |
| #150 | Nemesis 63123 | No second Hand of Gul'dan cast | Script state machine: the first cast in the window does not start the cooldown, the second does; the window ending, logout or leaving the form restarts the opener's cooldown; a 250 ms watch for a cast still in flight. Scripts `spell_wcme_nemesis_hand_of_guldan`, `spell_wcme_nemesis_window`, `spell_wcme_nemesis_form_end` | #253 |
| #149 | Demonic Persistence 276506 | The stand-in effects did nothing | Script on 276508 (`spell_wcme_demonic_persistence_talent`): prevents the stand-in, the lowest-health imp (ties: shortest timer) sacrifices itself (276511, owner as original caster), then 276513 and 276509, and the other imps are empowered with 276512. New imps get Deterioration 990142 (a fixed 4% of health a second, new spell id) and 276512 when due (`wcme_demonic_persistence_new_imps`). Owned `spell_dbc` rows 276509, 276512 (aura 79, all schools) and 990142 | #254 |

### Talent recipes learnt from these

| Recipe | When | How | Example |
|---|---|---|---|
| T1 Hidden companion link | A talent's tooltip promises more than its own effects do, and a hidden spell with the same name or the next id carries the rest | `spell_linked_spell` type 2 from each talent rank to its companion, comment `WCME:`. If the companion's mask is empty or names the wrong spell, add `wcme_spellaffect_dbc` rows (check the ID with `enchant_sql_lint.py`) | #151, #148 |
| T2 Script on the stand-in spell | The talent fires a placeholder spell whose effects mean nothing to our core | A `spell_wcme_*` SpellScript or AuraScript on the placeholder; prevent its default effects, then cast the real spells with the owner as original caster | #149 (276508) |
| T3 Aura 341 / 322 allowlist | An effect uses Ascension's PvE or PvP damage aura | The core honours these only for spells listed in patch 65 (`65-enchant-tuning-auras.ps1`). Adding a spell is C++; otherwise blank the effect or swap it for a stock aura | #148 (272731 effect 3 blanked); patch 65 lists 990138, 979038 |
| T4 `spell_dbc` aura swap | The effect is right in spirit but uses an aura the core ignores | Owned `spell_dbc` copy (`wcme_owned`, DELETE, INSERT the full 234-column row) with the aura changed, for example to 79 (damage done %, misc 127 = all schools) | #149 (276509, 276512) |
| T5 State across casts | A talent changes cooldown rules for a window | A per-player state struct in the script file; cover every way the window ends (expiry, logout, form change, a cast still in flight); start cooldowns with `AddSpellAndCategoryCooldowns` and send the packet | #150 |

### The scan for more of the same (24 Nov 2026)

`scripts/talent_companion_scan.py` finds every Wildcard-rollable talent and ability whose tooltip quotes a
hidden spell that nothing applies (read-only; the docstring has the command). Results:
`enchants/talent-companions.csv`. Run on 24 Nov against the client data and the core at `c3f2fd4`: 4,507 rank
spells in the roll pool, 189 unapplied companions, of which **54 entries `strong`** (passive, permanent, and
named like the talent, at id + 800000, tagged SLS, or in a known block such as the 902300 stun-reduction or
957339 "Generic Capstone Threat" spells), 19 `probable`, 8 `stock-data`, 23 `false-alarm`. Run against the
repository before #243, it lists Master Summoner and Demonic Recurrence as `strong`, so it would have found
both. Checked by hand: Tactical Mastery, Careful Aim and Iron Will (the talent holds a placeholder or half the
effect, the companion the rest). A row is a lead: read both spells before fixing (recipe T1), watch the
`duplicate` column, and do not link a companion whose aura the core ignores (T3) or that duplicates the
talent's own effect.

### Batches, by type (James, 24 Nov: work through them by type, so a problem met once is solved the same way)

| Batch | Type | Status |
|---|---|---|
| 1 | Plain bonuses: an aura link per rank (`sql/enchants/141-talent-companions.sql`) | 25 talents; waiting for James to merge; unverified |
| 2 | Event-driven companions (aura 42): link plus proc rules from the tooltip | next |
| 3 | Conditional: only in a form, on a stat path, while Swashbuckling, while a spell is learned (aura-link recipe R7) | Corrupted Bear Form, Divinity, Swashbuckler: Flurry of Blows, Glyph of Trueshot Aura |
| 4 | Needs code: weapon-dependent linked auras, unimplemented class-script overrides, Ascension aura types | Two-Handed Weapon Mastery, Bloodletting, Careful Aim, Harbinger of Plague, Reave |
| 5 | Active abilities with a passive companion (no aura to link from) | Thrust, Weighted Reinforcement |
| - | Left out by James (24 Nov 2026) | Icy Reach: a Death Knight talent whose tooltip quotes the Mage range companions (829023, 829014). Linking them would add range to Mage spells only, and stack with Arctic Reach at a different rank. James: "Leave it out." Do not link it in a later batch. |

Lessons from batch 1, for every later batch:
- A tooltip that says "does not stack" over a companion with the adding duration aura (232): own a copy with
  aura 234, which the core resolves as the strongest single cut.
- A capstone shown greyed out below the final rank links from the final rank only.
- A talent that only teaches spells has no aura of its own: link from the taught passive.
- A linked companion with a weapon requirement is removed with the weapon and not put back until login: drop the
  requirement (if the tooltip allows) or wait for batch 4's code.
- Look for sibling companions the tooltip does not quote (fear cuts next to stun cuts, 902313-902321).
- Run the file on a real MariaDB twice before the PR: the lint missed an unescaped apostrophe (`enchant_sql_lint.py`
  now catches it).

Before scripting, check the core does not already do it (`enchants/core-overlap-review.csv`) and read every
version of the ability a Hero can learn (Hand of Gul'dan has 954611 and 2304611 -> 2304612; both summon guardians
through summon properties row 61).

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
