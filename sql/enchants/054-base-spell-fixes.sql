-- Base spells two reviewed enchants depend on (needs the build with this version of mystic-enchants-scripts.patch and
-- core patch 71-jump-multiplier-points.ps1; no client patch change).
-- Void Shift (954522, Priest; 2304522, the Artifact copy): no script existed, so it did nothing. spell_wcme_void_shift
-- swaps health percentages (floor 25%, 10% for 2304522) and enforces Void Instability (956037) for 954522.
-- Void Shift (Artifact enchant 1398201) now actually teaches its Void Shift (2304522).
-- Flowing (273418): its data has no proc flags; Healing Touch casts now build Flowing and the third stack gives
-- Overflowing (273420), which the next Chain Heal uses up.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 273418);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (273418, 1398201);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (954522, 2304522, 273418) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 273418;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(273418, 0, 0, 0, 0, 0, 16384, 0, 1, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(954522, 'spell_wcme_void_shift'),
(2304522, 'spell_wcme_void_shift'),
(273418, 'spell_wcme_flowing');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 1398201;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(1398201, 2304522, 'Void Shift (Artifact enchant) teaches Void Shift');
