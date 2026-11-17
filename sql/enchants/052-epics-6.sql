-- Epic enchants, batch 6 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Hooks only (wcme_epic_batch67_spells / wcme_epic_batch67_hooks): Double Agent (81439), Electrical Discharge (277082),
-- Holy Servitude (1584997), Pious Strikes (1581647), Physics in Practice (277460), Saber Fangs (984696), Eternity
-- (276362), Ursoc's Blessing (81446, 282004), Necromancer's Touch (275963), Arngrim's Greeting (997188), Void
-- Teleportation (954626), Overflowing Cultivation (273422), Consumed By Shadows (997217).
-- With rows: Trauma Care (274205: finisher proc, spell_wcme_finisher_combo, 20% per combo point) and Bestial Assault
-- (272317: its own data procs are switched off, the script gives the stacks instead).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 274205), ('spell_proc', 272317);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (274205, 272317);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (274205, 272317) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (274205, 272317);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(274205, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(272317, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(274205, 'spell_wcme_finisher_combo');
