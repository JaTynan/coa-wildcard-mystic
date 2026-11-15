-- The rest of batch 3 (needs the build with this version of mystic-enchants-scripts.patch and
-- patches/66-enchant-core-hooks.ps1, and the client patch for the two new helper spells in 150).
-- Hot Hands (979765 / 1575104): Pyroblast joins Hot Streak's spell mask (the core's Hot Streak script still ignores
-- Pyroblast unless Hot Hands is on you, so nothing changes for anyone else), Living Fire, Superheated, the Living Bomb
-- crit mark and free Hot Streak Pyroblasts.
-- Predator's Wrath (977802 / its buff 977803): instant Wrath in Cat Form and the buff's Nature damage and energy.
-- Mending Tide: Chain Heal (every rank) keeps Riptide on its first target after a Riptide armed it.
UPDATE `spell_proc` SET `SpellFamilyMask0` = `SpellFamilyMask0` | 0x400000 WHERE `SpellId` = -44445;
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 979765),
('spell_proc', 1575104),
('spell_proc', 977802),
('spell_proc', 977803);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (979765, 1575104, 977802);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (979765, 1575104, 977802, 977803, -1064) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (979765, 1575104, 977802, 977803);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(979765, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(1575104, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(977802, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(977803, 0, 0, 0, 0, 0, 16, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(979765, 'spell_wcme_hot_hands'),
(1575104, 'spell_wcme_hot_hands'),
(977802, 'spell_wcme_predators_wrath'),
(977803, 'spell_wcme_predators_wrath_buff'),
(-1064, 'spell_wcme_chain_heal_keep_riptide');
