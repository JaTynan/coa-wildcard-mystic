# Chronicle: Mystic Enchants and spell fixes

What went wrong while restoring Mystic Enchants, what was tried and taken back, and what a test actually showed.
Facts come from commit messages, `docs/enchant-restoration.md`, the `enchants/` trackers and SQL file comments,
as of 2026-11-22. Nothing was re-tested in game for this file. Enchant behaviour is described in our own words;
Ascension's tooltip text is not kept in this repository.

Reading aid:

- **Enchant spell:** each Mystic Enchant is a spell (an id like `282881`) that sits on the character as an aura.
- **Placeholder:** an enchant spell whose effects are dummies. On Ascension the behaviour lived in server code we
  do not have.
- **Twin:** the same enchant made for another realm type, with a different spell id. Some twins work where ours
  is a placeholder.
- **Twin link:** a `spell_linked_spell` row that puts the twin's aura on you while ours is on.
- **Proc:** an effect that fires when something happens (a hit, a cast). `spell_proc` is the table that says
  when, how often and with what cooldown.
- **Triggered spell:** a spell cast by another spell (an explosion, a damage tick), not by the player.
- **The core:** CoA's server code. It has its own Mystic Enchant rules (`coa_mystic_enchant_*` tables and C++).
- **Helper spell:** a second spell an enchant casts to do its damage or buff.
- **File NNN:** `sql/enchants/NNN-*.sql`.

## Install dates on record

`enchants/legendary-history.csv` and `enchants/epic-history.csv` carry a "first live on server" date, which
`scripts/legendary_history.py` reads from the VM's `patch-night.log` ("installed wcme-server-...-buildN"). The
distinct pairs in those two files:

| First build containing the change | First live on the server |
|---|---|
| build 6 | 2026-11-02 |
| build 16 | 2026-11-10 |
| build 29 | 2026-11-12 |
| builds 45, 46, 47 | 2026-11-16 |
| build 50 | 2026-11-17 |
| build 51 | 2026-11-18 |

The date is when a build *containing* the change was first installed, which can be a later build than the one
named. Changes merged after build 51 have no live date in these files as of 2026-11-22.

## The state of testing (read this before trusting "fixed")

| Fact | Number | Source |
|---|---|---|
| Enchants offered on the realm | 6,440 | `enchants/tracker.csv` (row count) |
| Tracker rows with anything in `tested` | 49 | `enchants/tracker.csv` |
| Newest in-game test date anywhere in the trackers | 2026-11-03 | tracker, checklist and both history files |
| Checklist entries with a result | 35 of 561 | `enchants/test-checklist.csv` |
| Legendary copies "changed, awaiting in-game test" | 180 of 305 (177 plain, 2 waiting on core patch 71, 1 "through its shot"); 29 more carry the stale "changed on an unmerged branch" label; 5 "tested" | `enchants/legendary-history.csv`; rule: `ascension-restoration/references/state-2026-11-22.md` |
| Epic-file copies "changed, awaiting in-game test" | 280 of 1,710; 28 "tested" | `enchants/epic-history.csv` |

So almost everything below from 15 Nov onward is **changed, compile-checked and SQL-loaded, but not tested in
game**. The notes headers say the same: "None of that replaces in-game testing."

---

## E-01 · 2026-10-31 · Rolls gave enchants that do nothing: the missing and dud filters

- **Symptom:** a scroll roll could give an enchant that applies and does nothing.
- **Root cause:** of 6,440 enchants, 1,206 had a spell that "exists neither in Spell.dbc nor in spell_dbc", and
  about 790 more had a spell that "is only placeholder effects with nothing giving it behaviour".
- **Evidence:** `cf8c837` (PR #15) and `d746df2` (PR #17). Settings `CoA.MysticEnchants.SkipMissingSpells` and
  `CoA.MysticEnchants.SkipDudSpells`. Both are checked "at every startup against the loaded spells, never a fixed
  list".
- **Tried and rejected:** a fixed list of bad enchants (rejected in the design: an enchant should roll again by
  itself once it is given behaviour).
- **Status:** fixed, with a **known limit**: "about 70 enchants handled only by hard-coded C++ checks are left
  out as well" (they look identical to duds). `docs/enchant-restoration.md` (Lessons) gives the number as 36 and
  the remedy: table `wcme_enchant_override` (`enchant_spell, roll`) forces one into (1) or out of (0) the rolls,
  "once spot-checked". The two numbers (70 and 36) are both in the repository; neither is reconciled.
- **Lesson:** the filter decides from data. An enchant that works only through C++ needs an override row, and an
  enchant found broken can be forced out the same way.

## E-02 · 2026-10-31 · Twin links that never fired

- **Symptom:** enchants "restored" through a twin still did nothing.
- **Root cause:** "A twin can look working and never fire: a proc aura with no proc flags and no `spell_proc` row
  does nothing." (`docs/enchant-restoration.md`, Lessons)
- **Evidence:** `3a141df`, PR #19: batch 2 dropped 22 of batch 1's 51 twin links ("drop 22 twin links that never
  fired"). `c4507e9`, PR #24: batch 5 gave "9 enchants whose twin never fired" proc settings read from the tooltip.
- **Tried and rejected:** linking any twin that has a proc aura.
- **Status:** fixed: "The twin search now skips these."
- **Lesson:** a link showing up in `.list auras` is not a pass. The enchant has to *do* the thing.

## E-03 · 2026-10-31 · Batch 5 fix: triggered spells do not set off procs

- **Symptom:** three of batch 5's new procs (Living Bomb, Fire Nova, Hellfire) did not fire.
- **Root cause:** "Living Bomb's explosion, Fire Nova's damage and Hellfire's ticks are triggered spells, which
  only set off a proc when spell_proc allows it (AttributesMask 2). Hellfire's damage counts as periodic."
- **Evidence:** `4795ac5`, PR #25, merged the same day as batch 5 (PR #24).
- **Tried and rejected:** none recorded.
- **Status:** fixed.
- **Lesson:** when the trigger is an explosion, a tick or any spell another spell casts, the `spell_proc` row
  needs `AttributesMask` 2.

## E-04 · 2026-10-31 · Twin plus ours gave the bonus twice

- **Symptom:** a linked twin and our own spell both carried the same real effect.
- **Evidence:** `360dc22`, PR #23: "38 twin links with our duplicate effect removed" (ours becomes a placeholder
  in `spell_dbc` first, file 004).
- **Status:** fixed for those 38. The same class of bug came back on a larger scale in E-13.
- **Lesson:** "When both spells carry the same real effect, remove ours first, or the player gets the bonus twice."

## E-05 · 2026-10-30 to 2026-11-07 · Addon tooltip and slot bugs

| Date | Symptom | Root cause | Evidence | Status |
|---|---|---|---|---|
| 30 Oct | Every active enchant drawn one slot along, often on a locked slot | "The client numbers Mystic Enchant slots 1-17 and the server 0-16" | `f46610e`, PR #12 (addon 1.7) | fixed |
| 31 Oct | Wrong text taken as the enchant's description | "Enchant tooltips show the granted buff below the description: the description is the first line under the name" | `c4eaf1a`, PR #22 (addon 1.9) | fixed |
| 7 Nov | "Requires Level 60" on items replaced by enchant text (Sacred Unity on every level-60 epic) | an enchant whose description starts with a "Requires ..." line gave that line as its old text, so the twin swap matched item tooltips | `6a7f08b`, PR #60 | fixed: requirement lines and short lines are skipped |

- **Lesson:** client and server count slots differently, and tooltip text matching must never touch requirement
  lines.

## E-06 · 2026-11-02 to 03 · "Working namesake" picked a piece of the ability

- **Symptom:** tests on 2 Nov: Divine Steed "taught its hidden speed buff". On 3 Nov: Ring of Frost, Shadow
  Missiles, Soul Reaper and Seal of Command "taught a piece of the ability (nothing, an animation, a buff, 1 Holy
  damage)".
- **Root cause:** recipe 008 teaches a same-named spell in place of a broken one, and several same-named spells
  are effect pieces: "no cost, cooldown or tooltip of its own".
- **Evidence:** `767ca36`, PR #32 (20 taken out after the Divine Steed test); `57c8c67`, PR #39 (4 more);
  `29eac6a`, PR #33 (Divine Steed's own taught spell rebuilt, tested "pass after 013: mount, speed and buff").
- **Tried and rejected:** picking a namesake by name alone.
- **Status:** fixed for the 24 removed; those enchants went back to "broken" until their own spell is fixed.
- **Lesson:** a namesake is only a candidate if it has a cost, a cooldown or a tooltip of its own.

## E-07 · 2026-11-02 · The Arcane Charge saga (enchant 282881, helper 282883)

Five pull requests in one day. Intended behaviour: Charge also deals Arcane damage to enemies near the impact
and gives a mana buff.

| Step | What was done | What the test showed | Evidence |
|---|---|---|---|
| 0 | File 007 action row: the helper is cast as Charge starts | "mana parts work; damage hit enemies around the caster at charge start", so it hit nothing: the caster is still far away | tracker note, 2 Nov |
| 1 retarget | Helper's damage moved to an area around the Charge target | "retargeting Arcane Charge's damage at the Charge target made the whole helper fail (self-only range)": the mana parts stopped too | `52a235a`, PR #32; result reported in `29eac6a` |
| 2 | Retarget kept, helper's range raised so the cast is "no longer refused at range" | no result recorded for this step | `29eac6a`, PR #33 |
| 3 revert | Retarget reverted; test results recorded | back to step 0: "partly: mana parts work; damage only hits enemies near you as Charge starts. Retargeting it at the Charge target broke the whole helper, reverted" | `d2ebbdb`, PR #34 |
| 4 | Fire the helper "when Charge Root lands ... which is when you arrive" | wrong premise: "Charge Root lands as Charge starts, not on arrival, so the damage around you still missed a lone target" | `93bfa49`, PR #34; correction in `79b50b4` |
| 5 | Helper's damage hits "the Charge target itself, at any range"; mana part unchanged | **pass**: "Charge hits the target with Arcane Charge and grants the mana buff; only the target is hit, not other enemies near it" | `79b50b4`, PR #35; `78f0b00`, PR #37 |

- **Root cause:** the helper's area and range are measured from the caster at the moment of casting, and every
  available trigger (Charge starting, Charge Root landing) happens before the caster arrives.
- **Tried and rejected:** area around the target (broke the whole helper); firing on Charge Root (same timing as
  the cast).
- **Status:** worked around, tracker status `verified` (2026-11-02). **Known difference from the tooltip:** only
  the Charge target is hit, not nearby enemies. Final SQL: `sql/enchants/013-action-fixes.sql`.
- **Lesson:** an effect that should happen "on arrival" cannot be had from a cast-time trigger with a self-centred
  area. Changing a helper's targeting can make the whole helper fail, including parts that worked. Test after
  every single change, and record the result even when it is a failure: the tracker note is the only reason this
  story can be told.

## E-08 · 2026-11-02 · Fiery Charge never triggers (open)

- **Symptom:** "fail: aura stays on but Charge never triggers it, although the rule loads; sister enchants
  92249/92250/92252/92438 suspect".
- **Root cause:** not known.
- **Evidence:** `d2ebbdb`; `enchants/tracker.csv` row 92247 (status `broken`). The four sisters (Frosty Charge
  92249, Shadow Charge 92250, Arcane Charge 92252, Fel Charge 92438) are still marked `live` with nothing in
  `tested`.
- **Status:** **open** since 2 Nov.
- **Lesson:** four enchants are marked live on the strength of a rule whose sister failed.

## E-09 · 2026-11-01 to 02 · 1,195 rebuilt enchants held out of rolls until the client had them

- **Symptom:** the server could rebuild a missing enchant spell, but the client had no such spell.
- **Evidence:** `68d8d0f`, `2284b9e`, PR #31 (846 + 336 rebuilt, "held out of rolls until the client has them" by
  file 010); `34083eb`, PR #36 (client patch adds the 1,206 spells; "the roll hold (010) goes").
  `docs/enchant-restoration.md`: of the placeholder-to-modifier recipe, "2 enchant IDs turned out to be reused by
  unrelated spells in our data (skipped)".
- **Status:** fixed. The client patch then crashed character creation: see C-01 in
  `references/client-launcher-site.md`.
- **Lesson:** a new or rebuilt spell needs both halves: `spell_dbc` on the server and the client patch. Hold it
  out of the rolls until both are live.

## E-10 · 2026-11-15 · Runaway Legendary procs

- **Symptom:** "29 Legendary enchants fired on every hit."
- **Root cause:** "Ascension keeps their proc rules (which ability sets them off, the chance, the internal
  cooldown) in its own database, and the spell data has them blanked." A proc aura with proc flags but no
  `spell_proc` row "fires on every qualifying hit, with no ability filter and no cooldown".
- **Evidence:** `7a1f7a8`, PR #164, file `015-runaway-procs.sql`: 7 given the cooldown their tooltip states, 2 a
  spell-family filter, 24 a named-ability rule. (The subject says 29; the body's parts add to 33;
  `docs/enchant-restoration.md` says "file 015 fixes 33 Legendaries".) Same PR: `cde036b` gives four chance-on-hit
  enchants a 0.1 sec internal cooldown "so one hit cannot set off a chain"; `df063a2` adds per-target cooldowns
  (patch 63, table `wcme_proc_target_cooldown`).
- **Tried and rejected:** none recorded.
- **Status:** changed, awaiting in-game test.
- **Lesson:** proc flags without a `spell_proc` row means "always". Every proc enchant needs a row.

## E-11 · 2026-11-15 · Dead Legendary triggers

- **Symptom:** 22 Legendary enchants never fired.
- **Root cause:** the mirror image of E-10: "Their trigger aura had no proc flags and no spell_proc row, so it
  never fired."
- **Evidence:** `8d8e256`, PR #165, file `016-dead-triggers.sql`; `bbb213c` (best-guess rules "each marked in its
  row comment"); `f47b397` (a 0 in a rule's spell list matches an auto attack). The first commit says 22;
  `CHANGES.md` says the file now covers 33 (31 through the action table, 2 through aura links).
- **Status:** changed, awaiting in-game test.
- **Lesson:** no proc flags means "never". Check both directions on any proc enchant.

## E-12 · 2026-11-15 to 16 · Guessed numbers, then the tooltip review

- **Symptom:** rules written before the archived builder tooltips were to hand used guesses.
- **Evidence:**
  - `bbb213c`, `bf0733e`: values "assumed" (Consecrated Strikes 20%, Rush of Blood 50%, and others).
  - `730ecea`, PR #166: "Apply James's calls on the guessed enchant values" (Consecrated Strikes and Weapon 35%,
    and others).
  - `8cdfebf`, PR #169: "Checked every enchant from #164 to #167 that had a guessed number or mechanic against
    the archived Ascension builder tooltips." Curse of Arugal: the tooltip gives +20% where "the client data has
    40%". Deadly Bite 965292 turned out to be "Ascension's real version, not a placeholder", so file 004 "no
    longer blanks it or links it".
  - `b570a98`, PR #167: second batch matched to the full tooltips James sent.
  - `99f22a4`, PR #168: Mana-forged Barrier's threat bonus applied to every school; the tooltip limits it to
    magic damage.
- **Tried and rejected:** the guesses listed above.
- **Status:** corrected where the review found a difference.
- **Lesson:** the client's spell data and the tooltip can disagree (40% against 20%). The tooltip wins. A guess
  must be marked as a guess where it is written, so a review can find it.

## E-13 · 2026-11-17 to 18 · The core already did it: the overlap review

The largest "undo" in the project. Between 15 and 17 Nov the Legendary and Epic enchants were scripted in batches
(PRs #164 to #177 and the first commits of #178). A review then found that the CoA core handles many of them itself, so effects happened
twice. The commit messages date some of the core's own handling to early November ("the core has done it since
3 November", "since 2 November", "the core's 4 November fix").

- **Root causes found (each is a distinct way to double an effect):**

| Way | Example and what happened | Evidence |
|---|---|---|
| We scripted what a core rule already does | Explosive Charge splash, Elemental Torrent stack, Trauma Care, Physics in Practice, Pious Strikes, Holy Servitude, Electrical Discharge, Growing Light, Shadow Funnel's Void Nova, Moon's Wrath, Critical Time, Pyroclasmic Shadows, Feeding the Abyss ("a second absorb roll and a second payoff") | `d8f9215`, `7dcb81f`, `f70bb96`, `209d729`, `93996b4`, `5bf04bd`, `02714a7` |
| Our `spell_proc` row replaced the core's | Soul Erosion and Wraithweaver: Shadow Orbs: our row at 100% made the core's rule fire on every tick instead of 8% / 20%, with our own roll on top | `f9806da`, `06d67c5`; `enchants/core-proc-row-replacements.csv` |
| Our row silenced the core's script | Relentless Reflexes ("ours (cast phase) replaced the core's (finish phase), so the core's script never fired"); Trauma Care | `c494f83`, `7dcb81f` |
| A twin link brought the twin's core rules as well as our script | Compound Power (4 combo points a shot), Frozen Chaos, Elemental Assassin | `99174fa` |
| A twin link to a *different* enchant of the same name | Precision Impact linked 290200, "a different enchant of the same name" | `aa927a6` |
| Core teaches the enchant's own spell and we teach the twin's | Cremation: "players see both"; 55 enchants listed | `02714a7`; `enchants/taught-spell-doubles.csv` |
| Aura link watched the talent, not the proc buff | Decimation by Pyro: "the bonus was permanent"; same mistake in Mind Core, Pyroclasmic Shadows, Fingers of Death | `b8dfdbb` |
| Aura link watched too much | Omen of Doom: "watched every class's Clearcasting and took the buff away as soon as Clearcasting was used" | `d6da5ba` |
| Our helper repeated a core change | Fire Walk With Me: "Scorch lost 20 yards" | `d6da5ba` |
| The enchant's own buff added to the core's bonus | Lone Wolf: "no pet meant +21%" | `92b8e46` |
| Both counted the same event | Rush of Blood (energy twice), Shadow Visions (twice as fast), Savage Momentum (4 sec instead of 2), the three Abjurer's Wards (20 sec instead of 10) | `2c8f3d7`, `2d391f3`, `209d729`, `cca2a2c` |

- **Reviewed and found fine (no change):** Glyph of Mana Tide, Glyph of Circle of Healing, Glyph of Trueshot
  Aura, Stormbound Instinct, Blazing Flame, Disciple of the Tides, Demolisher, Blood and Guts, Dragon Warrior,
  Corrupted Bear Form, Overflow (`258fd4a`, `4fa4cf3`, `f9806da`, `06d67c5`, `aa927a6`, `99174fa`, `1789a56`,
  `0c119f4`, `2d391f3`). Nine tracker entries "only matched coincidental numbers in the core" (fireworks files,
  GatherMate ids) and were closed (`271f5d8`).
- **Gaps found in the core itself** (the core handles the enchant, but not completely on this realm):

| List | Rows | What it holds | Status in the file's header |
|---|---|---|---|
| `enchants/core-overlap-review.csv` | 64 | every enchant we touch that the core also handles, with the review result | reviewed |
| `enchants/core-proc-row-replacements.csv` | 11 | places our SQL replaces the core's proc row (commit `f9806da` says "six enchants") | see file |
| `enchants/core-rule-gaps.csv` | 9 | a trigger effect with no core rule, "so that effect never fires" | "most still need a look" |
| `enchants/core-refresh-aura-review.csv` | 100 | "refresh aura" effects that set a time where the name says extend (commit `209d729` says 72, 13 reached by enchants) | "they still need a look" |
| `enchants/core-version-gaps.csv` | 10 | core rules blind to other versions of a spell on the "hero" class model | covered case by case |
| `enchants/core-rule-version-gaps.csv` | 263 | core rules whose spell list misses a version a player here can learn | "they still need a look" |
| `enchants/taught-spell-doubles.csv` | 54 | core teaches one spell, we teach another (notes header says 55) | queued; James chose option 1 on 2026-11-18: own spell only once it works |
| `enchants/swap-own-effects.csv` | 19 | tooltip swaps whose own data can still fire | "each needs a look" |

  Row counts are as of 2026-11-22 (`wc -l` minus the header). Where a commit message gives a different number
  the difference is shown, not resolved.

- **Evidence for the whole review:** PR #178 (`epics-1`), 26 commits titled "Review ..." from `3c1c790` (17 Nov) to
  `cca2a2c` (18 Nov); `enchants/epic-notes-header.md`, section "Overlaps with the core's own enchant code".
- **Tried and rejected:** scripting from the tooltip without first searching the core.
- **Status:** fixed in the repository for everything the review reached. `d8f9215` notes "live doubling stays
  until a build with this PR is installed". Everything is awaiting in-game test. Four enchants (Cauterize 850093,
  Frost Shot 851989, Hammerstorm 852412, plus Shadow Siphon which was resolved in `d6da5ba`) were flagged as
  needing a decision; the first three are "queued: their own spells need code first".
- **Lessons (all from `enchants/epic-notes-header.md`):**
  1. "Before scripting any enchant, check ... the core's tables in `data/sql/updates/pending_db_world` and its
     C++ in `src/server` (search for the enchant's spell id)."
  2. "Our SQL must not replace the core's own `spell_proc` row for an enchant the core runs."
  3. Aura links "must watch the proc buff only, never the talent that procs it".
  4. Where we write our own script for an enchant, its twin link "has to go, or both run".
  5. Where we cover a gap in a core rule, "ours runs only when the core's own test fails".
  6. On this realm both the stock and the CoA version of most abilities are learnable (Shadow Bolt 686 or
     1100686). A rule that lists one version misses the other.

## E-14 · 2026-11-17 · Heal hook passes its two units in a different order

- **Symptom:** Growing Light, Holy Ground and the Align heal bonus read healer and target the wrong way round.
- **Root cause:** "The core passes the heal hook's units as (healer, target) for direct heals and (target,
  healer) for heal-over-time ticks."
- **Evidence:** `09c12c0`, PR #178; `enchants/epic-notes-header.md` ("Known core quirk").
- **Status:** fixed with `WcmeHealParties`.
- **Lesson:** "Any new heal rule should call `WcmeHealParties` first."

## E-15 · 2026-11-17 · The Flowing fix, corrected the same day

- **Symptom:** Flowing (273418) "had no proc flags", so a proc script and `spell_proc` row were added
  (`508789d`).
- **Correction:** "the core's own Mystic Enchant rule already builds the stacks, so the separate proc script and
  spell_proc row are dropped; the scripts only turn the third stack into Overflowing" (`7910784`).
- **Status:** fixed. A small E-13 inside one day.
- **Lesson:** "no proc flags" in the spell data does not prove nothing fires it. The core's rule tables can.

## E-16 · 2026-11-17 · Chain jump modifiers multiplied instead of adding points

- **Symptom:** Tidal Force, Overflowing, Transcendental Embrace, Booming Thunder and the Water Duke's totem "made
  each jump many times stronger than the last".
- **Root cause:** a core bug: 'flat "loses X% less per jump" modifiers are percentage points. The core added X
  straight onto the multiplier.'
- **Evidence:** `508789d`, PR #178; `patches/71-jump-multiplier-points.ps1`; `CHANGES.md` row.
- **Status:** fixed by a core patch; awaiting in-game test (2 legendary copies are marked "awaiting in-game test
  (core patch 71)").
- **Lesson:** some enchant bugs are core bugs. Reporting them upstream to CoA is covered by
  `wildcard-docs-and-publishing`.

## E-17 · 2026-11-11 to 18 · Other root causes worth recognising

| Date | Enchant | What was wrong | Evidence |
|---|---|---|---|
| 11 Nov | Empowered Light | its buff "had no charge, so every Holy Fire for 8 seconds was faster" | `e73b77b`, PR #117 |
| 16 Nov | Thermal Void | "its flags only listed hostile spells, so it never fired" from Ice Barrier | `292e4be`, PR #171 |
| 16 Nov | Astral Storm | "its data proc fired on every damaging spell and could phase any target" | `cd1c3e0`, PR #175 |
| 16 Nov | Ability-swap kits | "the core only swaps an enchant's ability when the new name contains the old one (or the description says 'transform')" | `107f408`, PR #175 |
| 16 Nov | Pack Tactics and three others | "The core applies auras 341 (PvE damage done) and 322 (PvP damage done) only for an allowlist of reviewed spells" | `21826cd`, PR #173; patch 65 |
| 16 Nov | Overflow, Dragon Warrior, Demolisher, Dark Surgeon, Disciple of the Tides, Tree of Wrath, Forbidden Technique | each had been given a twin's behaviour and was rebuilt to "its own design instead of twin" | `978cedc`, `a224506`, `63a06c9`, `bd04201`, `647e1f3`, `7cbb369`, `33ea415` (all PR #175) |
| 17 Nov | Double Agent | "never fired: the core removes the target's stealth before the damage is worked out" | `3c1c790`, PR #178 |
| 17 Nov | Holy Servitude, Saber Fangs, Elemental Lord | helpers cast with an amount from a finished hit got "the caster's spell power again" | `3c1c790` |
| 17 Nov | Bestial Assault | "counted Auto Shot, so stacks would have built by themselves" | `0b4e6a2` |
| 17 Nov | Necromancer's Touch | Dominate Undead and Enslave Demon "tame the creature in our data, so those pets never counted" | `9298c60` |
| 17 Nov | Consumed By Shadows | Master of Subtlety's buff has to be found "by name (the core uses talent twins of 31665)" | `5db193a` |
| 18 Nov | Generator out of step | "the Feeding the Abyss rows removed by hand today are now retired in the generator" (`custom_spells.py` against `150-custom-spells.sql`) | `f5073f2`, PR #180 |

- **Lesson from the last row:** `150-custom-spells.sql` is generated. A hand edit to it is lost at the next
  regeneration unless the generator changes too.

## E-18 · 2026-11-19 · Worldforged enchants never dropped, and did nothing when owned

- **Symptom:** James reported on 19 Nov that worldforged Mystic Enchants never drop.
- **Root cause (three parts):** each rare worldforged enchant "relies on a server-side helper spell ... Nothing on
  this core applies the helpers"; "The Power spells carry no amounts (every value is 0 in Spell.dbc)"; and the
  Unidentified Mystic Scroll "leaves worldforged enchants out of its roll, and no loot table has their scrolls".
- **Evidence:** `90ee10d`, PR #190; `patches/78-worldforged-enchants.ps1`; setting
  `Wildcard.WorldforgedDropChance`. Checked by "a simulation over the server's Spell.dbc, MysticEnchant.dbc and
  SpellAffect.dbc" that "registers 990 enchants (Primal Tide has no helper)".
- **Status:** changed, awaiting in-game test.
- **Lesson:** "does not drop" hid "does not work". Check both.

## E-19 · 2026-11-19 · Mystic Enchant gold prices: client and server could disagree

- **Symptom:** prices (30g to 250g, "more as the client showed it") made the system unusable with no source of
  Mystic Runes.
- **Root cause:** "The core's money prices ... are used whenever the client config names none, and nothing named
  one, so the client could show other amounts than were charged."
- **Evidence:** `5c2a489`, PR #192; `patches/79-mystic-enchant-gold-cost.ps1`; `Wildcard.MysticEnchantGoldCostPct`
  (default 1).
- **Status:** changed; no test recorded.
- **Lesson:** "at least 1 copper (0 means 'not for sale' to the rules)". A price of 0 is not "free".

## E-20 · 2026-11-23 · Ten named-target rows replaced stock SpellAffect rows

- **Symptom:** none seen in game. Found by comparing all 8,909 of our `wcme_spellaffect_dbc` IDs with the 36,849 rows
  of `SpellAffect.dbc`.
- **Root cause:** file `011` used IDs 901388-901397, which the stock file uses for the "Threat Reduction" spells.
  A table row replaces the file row with the same ID. `000-reset.sql` had claimed IDs from 900000 never collide.
- **Evidence:** PR #244 (moved to 951000-951009); PR #245 (`enchant_sql_lint.py` fails on a clash, with a built-in
  list of the 32 ranges the file uses between 900000 and 999999).
- **Status:** fixed; lint check in place.
- **Lesson:** a "safe range" is a claim to check against the data, not a comment to trust.

## E-21 · 2026-11-23 · Spell mask read word by word instead of effect by effect

- **Symptom:** while fixing #151 and #150, Master Summoner's companion looked maskless and Nemesis's cooldown cuts
  looked broken, and named-target rows 960000-960003 were added for Master Summoner.
- **Root cause:** a scratch reader took the class mask from fields `122+e`, `125+e`, `128+e`. The layout is three
  words per effect, effect by effect: `122+3*e` to `124+3*e`.
- **Evidence:** `sql/enchants/140-talent-fixes.sql` header ("Corrected 24 Nov"); PR #252 removed rows
  960000-960003; #148 was re-checked with the right reader.
- **Status:** corrected. The layout is written down in `azerothcore-coa-reference/references/spell-system.md`.
- **Lesson:** check a new data reader against one spell whose answer you already know.

---

## Race kit fixes (not enchants, same spell machinery)

| Date | Racial | What was wrong | Evidence |
|---|---|---|---|
| 13 Nov | All ten | The first design (two actives and two passives per race) was dropped for "stock racials plus one signature passive each" | `a242a1f`, PR #139 |
| 15 Nov | Voodoo Regeneration | "Each second's heal was at least 1 health, so at low level the in-combat regen ran many times its intended rate" | `688b1fc`, PR #162 |
| 15 Nov | Plainsrunning | stopped at 49% of a 50% cap: "only refreshed on changes of 1% or more, and the last step to the cap is smaller" | `193a319`, PR #162 |
| 15 Nov | Bloodrush | neutral (yellow) mobs in combat with you gave no stack | `165b090`, PR #162 |
| 15 Nov | Ambush | spells that only apply an aura did not use the charge, "so they could keep the +50% cast after cast" | `01501ee`, PR #162 |
| 20 Nov | Satiated | could be cleared by Divine Shield or Ice Block "to restack early" | `caff18a`, PR #199 |
| 21 Nov | Stoneform | flat 8% spell damage cut (`40ec678`) replaced the same day by magic resistance (`710ca91`) | PR #207 |
| 20 to 21 Nov | Undead Grave Defiance | cooldown debuff "Grave Hunger" (`89d4e7a`) retired a day later for 20 Grave Feast charges (`d15f197`) | PRs #199, #207 |
| 21 Nov | Running with the Herd | range and hold time retuned three times after PR #213 merged; **those three commits are not on `main`** | U-04 in `references/unmerged-and-abandoned.md` |

Tuning reversals like the last three are design changes by James, not failures; they are listed so nobody
"restores" the older value by mistake.
