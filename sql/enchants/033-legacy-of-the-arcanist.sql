-- Legacy of the Arcanist (984117): elemental Meteors from Fire, Nature, Frost and Arcane hits, Elemental Motes,
-- Potential and Elemental Resonance (needs the build with this version of mystic-enchants-scripts.patch, and the client
-- patch for the Resonance penalties 9990022 to 9990025 in 150).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 984117);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 984117;
DELETE FROM `spell_script_names` WHERE `spell_id` = 984117 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 984117;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(984117, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(984117, 'spell_wcme_legacy_of_the_arcanist');
