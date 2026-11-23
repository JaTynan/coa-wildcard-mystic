-- Talent fixes. Safe to run again; 000-reset removes this file's rows first (spell_proc rows listed in wcme_owned,
-- spell_linked_spell rows marked WCME:, all of wcme_spellaffect_dbc) and this file puts them back. Fixes that need an
-- aura script are paired with patches/55-talent-fixes.ps1; data-only fixes say so.

-- Backdraft (issue #152): procs from Conflagrate, Shadowburn, Shadowfury and Mind Blast, and from Immolate with the
-- Mystic Enchant Immolating Backdraft. Stock row: family Warlock, Conflagrate only. Now no family filter (the script
-- picks the spells); still only on a spell hit, as before.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', -47258);
DELETE FROM `spell_proc` WHERE `SpellId` = -47258;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`,
    `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`,
    `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(-47258, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0);
DELETE FROM `spell_script_names` WHERE `ScriptName` = 'spell_wcme_backdraft';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (-47258, 'spell_wcme_backdraft');

-- Master Summoner (issue #151): the talent also lengthens Wild Imps (2.5 sec at rank 1, 5 sec at rank 2), but that
-- part lives in a hidden companion spell per rank (818709, 818710) that Ascension's server applied and ours never
-- did. One step, no code: while a rank of the talent is on a character, its companion is too (the same aura link
-- the twin enchants use). 000-reset removes these rows by their WCME: comment and this file puts them back.
-- The companion finds its spells by itself: its duration effect carries Hand of Gul'dan's class flag (family
-- Warlock, third mask word 0x100), which both versions a Hero can learn have (954611, and 2304612, the summoning
-- half of 2304611). The core sets a Wild Imp's lifetime from that spell's duration.
-- Corrected 24 Nov: this file also named those two spells as targets in wcme_spellaffect_dbc (IDs 960000-960003),
-- after a misreading of the companion's mask columns as empty. Named targets are only read for an effect with no
-- mask, so those rows did nothing and are gone.
-- Needs a server start to take effect. The talent's other effects (summon cast time and cost, Infernal and
-- Doomguard duration) are untouched.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(18709, 818709, 2, 'WCME: Master Summoner rank 1 applies its Wild Imp duration companion (#151)'),
(18710, 818710, 2, 'WCME: Master Summoner rank 2 applies its Wild Imp duration companion (#151)');

-- Demonic Recurrence (issue #148; the game data spells it "Demonic Reoccurence"): talent 272730. Only one of its
-- four parts worked, and that part is a drawback, so the talent made Metamorphosis worse and gave nothing back.
--   What it should do: halve Metamorphosis's cooldown; in return the form gives nine tenths less bonus armour and
--   no longer cuts the chance to be critically hit or the length of stuns and snares.
--   How the data does it: the talent itself removes the stun and snare cut (worked: its target, the form's helper
--   54817, is named in SpellAffect.dbc). The rest sits in hidden companion spells Ascension's server applied and
--   ours never did: 272731 (cooldown and armour; its target, Metamorphosis 47241, is named in SpellAffect.dbc) and
--   272733 (critical hits; it names only the CoA-class helper, not 54879, the one a Hero's form uses).
-- Three steps, no code:
--   1. While the talent is on a character, both companions are too (aura links, as for Master Summoner above).
--   2. Companion 272733 names the helper it changes: 54879. ID 960010 is used by neither SpellAffect.dbc nor
--      another file.
--   3. Companion 272731 has a third effect that takes 10 points off the form's damage bonus for every target. The
--      talent's text limits that loss to fights against players, and Ascension gave the points back against
--      monsters with a further companion (272732) whose aura the core only honours for a fixed list of spells that
--      does not include it. So our copy of 272731 (spell_dbc, owned) has that third effect blanked: the damage
--      bonus stays whole against everything. Known gap: it is not reduced against players either.
-- Metamorphosis versions: 47241 is the one in the Hero catalogue. The CoA-class version (1147241) is not touched.
-- Side effect, wanted: the Mystic Enchant of the same name (1570995) is linked to this talent as its twin by
-- 001-twin-links.sql, so it now gets the whole talent, not just the drawback. Its own numbers differ (a
-- flat cooldown cut and half the armour); that enchant is for a later review.
-- Needs a server start to take effect.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_dbc', 272731);
DELETE FROM `spell_dbc` WHERE `ID` = 272731;
INSERT INTO `spell_dbc` VALUES
(272731, 0, 0, 0, 2147484112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 65536, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 0, 0.0, 0.0, 0.0, -91, -51, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 108, 108, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 12, 11, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3639, 0, 0, 'Demonic Reoccurence', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'SLS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(272730, 272731, 2, 'WCME: Demonic Recurrence applies its cooldown and armour companion (#148)'),
(272730, 272733, 2, 'WCME: Demonic Recurrence applies its critical hit companion (#148)');
INSERT INTO `wcme_spellaffect_dbc` (`ID`, `ModifierSpellID`, `AffectedSpellID`) VALUES
(960010, 272733, 54879);
