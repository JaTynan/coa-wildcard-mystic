-- Overflow (977710): its own design instead of twin 1571951 (003 no longer links them): Healing Touch overflow heal,
-- Living Seed and Flowing; Overflowing Chain Heal; Living Seed mana; Chain Heal cuts Tranquility's cooldown (needs the
-- build with this version of mystic-enchants-scripts.patch).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 977710);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 977710;
DELETE FROM `spell_script_names` WHERE `spell_id` = 977710 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 977710;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(977710, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(977710, 'spell_wcme_overflow');
