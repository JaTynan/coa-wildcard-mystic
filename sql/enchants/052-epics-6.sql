-- Epic enchants, batch 6 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Hooks only (wcme_epic_batch67_spells / wcme_epic_batch67_hooks): Double Agent (81439), Saber Fangs (984696),
-- Eternity (276362), Ursoc's Blessing (81446, 282004), Necromancer's Touch (275963), Arngrim's Greeting (997188), Void
-- Teleportation (954626), Overflowing Cultivation (273422), Consumed By Shadows (997217).
-- Electrical Discharge (277082), Holy Servitude (1584997) and Pious Strikes (1581647) were dropped in review: the core
-- already does them (no rows were ever added for them).
-- Trauma Care (274205) and Physics in Practice (277460) were also dropped in review: the core already does them
-- (aura_wildcard_trauma_care with its own spell_proc row, and a damage hook in AscensionMysticEnchantScripts). This file
-- no longer touches Trauma Care's rows.
-- With rows: Bestial Assault (272317: its own data procs are switched off, the script gives the stacks instead).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 272317);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 272317;
DELETE FROM `spell_script_names` WHERE `spell_id` = 272317 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 272317;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(272317, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0);
