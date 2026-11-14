-- Talent fixes, paired with patches/55-talent-fixes.ps1 (the aura scripts). Safe to run again; 000-reset removes the
-- spell_proc rows listed in wcme_owned first, and this file puts them back.

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
