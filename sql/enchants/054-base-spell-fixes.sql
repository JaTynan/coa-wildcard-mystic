-- Base spells two reviewed enchants depend on (needs the build with this version of mystic-enchants-scripts.patch and
-- core patch 71-jump-multiplier-points.ps1; no client patch change).
-- Void Shift (954522, Priest; 2304522, the Artifact copy): no script existed, so it did nothing. spell_wcme_void_shift
-- swaps health percentages (floor 25%, 10% for 2304522) and enforces Void Instability (956037) for 954522.
-- Void Shift (Artifact enchant 1398201) now actually teaches its Void Shift (2304522).
-- Flowing (273418): the core's own Mystic Enchant rule already builds Flowing stacks from Healing Touch; the enchant
-- scripts now turn the third stack into Overflowing (273420), which the next Chain Heal uses up. No rows for it here:
-- the core's spell_proc and script rows for 273418 stay as they are.
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 1398201;
DELETE FROM `spell_script_names` WHERE `spell_id` IN (954522, 2304522) AND `ScriptName` LIKE 'spell\_wcme\_%';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(954522, 'spell_wcme_void_shift'),
(2304522, 'spell_wcme_void_shift');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 1398201;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(1398201, 2304522, 'Void Shift (Artifact enchant) teaches Void Shift');
