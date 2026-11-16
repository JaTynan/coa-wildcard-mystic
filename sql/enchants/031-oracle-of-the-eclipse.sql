-- Oracle of the Eclipse (979240): Holy Light and Healing Wave Eclipses with their talent effects, mana and Blessing of
-- the Moon; teaches Oracle's Blessing (983668), which spends Blessing of the Moon (needs the build with this version of
-- mystic-enchants-scripts.patch).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 979240);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 979240;
DELETE FROM `spell_script_names` WHERE `spell_id` IN (979240, 983668) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 979240;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(979240, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(979240, 'spell_wcme_oracle_of_the_eclipse'),
(983668, 'spell_wcme_oracles_blessing');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 979240;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(979240, 983668, 'Oracle of the Eclipse: teaches Oracle''s Blessing');
