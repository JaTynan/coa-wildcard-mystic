-- Fel Corruption (984165): Corrupted Core and Molten Core for Chaos Bolt and Felblade, cooldown cuts, Fel Infused
-- Flames and Rising Chaos (needs the build with this version of mystic-enchants-scripts.patch).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 984165);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 984165;
DELETE FROM `spell_script_names` WHERE `spell_id` = 984165 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 984165;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(984165, 0, 0, 0, 0, 0, 327696, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(984165, 'spell_wcme_fel_corruption');
