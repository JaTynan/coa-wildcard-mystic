-- Champion of Justice (986000): teaches Righteous Justice (and Crusader's Promise through the script), Crusader's
-- Justice heals and bonds or strikes, Divine Justice from Divine Storm, Debt of Justice from Crusader's Promise (needs
-- the build with this version of mystic-enchants-scripts.patch).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 986000);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 986000;
DELETE FROM `spell_script_names` WHERE `spell_id` IN (986000, 985957, 985972, 985993) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 986000;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(986000, 0, 0, 0, 0, 0, 16400, 0, 3, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(986000, 'spell_wcme_champion_of_justice'),
(985957, 'spell_wcme_righteous_justice'),
(985972, 'spell_wcme_crusaders_justice'),
(985993, 'spell_wcme_crusaders_promise');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 986000;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(986000, 985957, 'Champion of Justice: teaches Righteous Justice');
