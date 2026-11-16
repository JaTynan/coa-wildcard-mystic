-- Arcane Echo for Mind Mending Armor (1106118), and Arcane Reverberation's Resonating Power (1112044), which the core's
-- replacement gives for Arcane Power (needs the build with this version of mystic-enchants-scripts.patch).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1106118);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 1100170;
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1106118, 1112044) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 1106118;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1106118, 0, 0, 0, 0, 0, 278528, 2, 2, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1106118, 'spell_wcme_mind_mending_armor'),
(1112044, 'spell_wcme_resonating_power');
