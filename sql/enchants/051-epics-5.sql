-- Epic enchants, batch 5 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Hooks only (wcme_epic_batch5_spells / wcme_epic_batch5_hooks): Final Shield (81255, 281638), Blessed by the Elune
-- (272253), War Mage (281939), Elemental Lord (276578), Spellstorm (271709), Suffocating Roots (84378), Deter and Punish
-- (977988, 283979), Predatory Nature (979050), Soul Siphoner (81398), Blood Shield (288804), Tidecaller's Boon (271813),
-- Twilight (84471).
-- With rows: Sniper (81166) and Ready, Set, Go! (81128) (standing still), Lone Wolf (1180030: no pet, enemies around you).
-- The same build also fixes the order of the two units in the core's heal hook for direct heals (Growing Light 270661,
-- Holy Ground 81315 / 281788 and the Align heal bonus 986160 read them the wrong way round before).
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81166, 81128, 1180030);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81166, 81128, 1180030) AND `ScriptName` LIKE 'spell\_wcme\_%';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(81166, 'spell_wcme_stand_still'),
(81128, 'spell_wcme_stand_still'),
(1180030, 'spell_wcme_lone_wolf');
