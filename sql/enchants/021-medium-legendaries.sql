-- Medium legendary fixes from the tooltip review (needs the build with this version of mystic-enchants-scripts.patch):
-- Crimson Defense, Heavyweight, Low Tide and Templar of Flame.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1572131),
('spell_proc', 977700),
('spell_proc', 81404),
('spell_proc', 954424);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (1572131, 977700, 81404, 954424);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1572131, 977700, 81404, 954424) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1572131, 977700, 81404, 954424);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1572131, 0, 0, 0, 0, 0, 65720, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(977700, 0, 0, 0, 0, 0, 20, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(81404, 0, 0, 0, 0, 0, 16384, 2, 2, 2, 0, 0, 0, 100, 0, 0),
(954424, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1572131, 'spell_wcme_crimson_defense'),
(977700, 'spell_wcme_heavyweight'),
(81404, 'spell_wcme_low_tide'),
(954424, 'spell_wcme_templar_of_flame');
