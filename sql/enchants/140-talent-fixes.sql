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
-- did, and the companions say "longer duration" without saying of what. Two steps, no code:
--   1. While a rank of the talent is on a character, its companion is too (the same aura link the twin enchants
--      use). 000-reset removes these rows by their WCME: comment and this file puts them back.
--   2. Each companion names the spells it lengthens: both Hand of Gul'dan versions a Hero can learn (954611, and
--      2304612, the summoning half of 2304611). The core sets a Wild Imp's lifetime from that spell's duration.
--      000-reset empties wcme_spellaffect_dbc first; IDs 960000+ are used by neither SpellAffect.dbc nor another file.
-- Needs a server start to take effect. The talent's other effects (summon cast time and cost, Infernal and
-- Doomguard duration) are untouched.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(18709, 818709, 2, 'WCME: Master Summoner rank 1 applies its Wild Imp duration companion (#151)'),
(18710, 818710, 2, 'WCME: Master Summoner rank 2 applies its Wild Imp duration companion (#151)');
INSERT INTO `wcme_spellaffect_dbc` (`ID`, `ModifierSpellID`, `AffectedSpellID`) VALUES
(960000, 818709, 954611),
(960001, 818709, 2304612),
(960002, 818710, 954611),
(960003, 818710, 2304612);
