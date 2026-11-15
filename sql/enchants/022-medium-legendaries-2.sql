-- Medium legendary fixes, part 2 (needs the build with this version of mystic-enchants-scripts.patch): Master of
-- Shadows, Spell Shredder and Beast and Blade.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 980046),
('spell_proc', 978233),
('spell_proc', 978237);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (980046, 978233, 978237);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (980046, 978233, 978237) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (980046, 978233, 978237);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(980046, 0, 0, 0, 0, 0, 16, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(978233, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(978237, 0, 0, 0, 0, 0, 16, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(980046, 'spell_wcme_master_of_shadows'),
(978233, 'spell_wcme_spell_shredder'),
(978237, 'spell_wcme_beast_and_blade');
