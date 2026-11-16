-- Legendary kits, batch 1 (needs the build with this version of mystic-enchants-scripts.patch): Apostle of Eredath
-- (902185, teaches Beam of Hatred), Astral Bomber (978235), Cauterizing Flames (86460) and Dark Ranger (997115, with
-- Shadow Artillery's Shadow Shells check on 998204). Their ability swaps are done by the scripts (the core only swaps
-- abilities whose names match).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 902185),
('spell_proc', 978235),
('spell_proc', 86460),
('spell_proc', 997115);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (902185, 978235, 86460, 997115);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (902185, 978235, 86460, 997115, 998204) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (902185, 978235, 86460, 997115);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(902185, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 2, 0, 0, 100, 0, 0),
(978235, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(86460, 0, 0, 0, 0, 0, 81920, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(997115, 0, 0, 0, 0, 0, 65792, 0, 3, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(902185, 'spell_wcme_apostle_of_eredath'),
(978235, 'spell_wcme_astral_bomber'),
(86460, 'spell_wcme_cauterizing_flames'),
(997115, 'spell_wcme_dark_ranger'),
(998204, 'spell_wcme_shadow_artillery');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 902185;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(902185, 902186, 'Apostle of Eredath: teaches Beam of Hatred');
