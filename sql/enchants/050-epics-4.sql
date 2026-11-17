-- Epic enchants, batch 4 (needs the build with this version of mystic-enchants-scripts.patch and
-- patches/70-mastery-of-the-tide-riptide.ps1; no client patch change).
-- Hooks only (wcme_epic_batch4_spells / wcme_epic_batch4_hooks): Faerie Swarm (81402, 281916), Tempered by Chaos
-- (299180), Shooting Stars (281485), Fire Walk With Me (952120, 283296), Blood-Soaked Mutilation (1590974), Elemental
-- Burst (278033), Lightning Mastery (81140), Overload Mastery (281411), Chilling Blows (81213), Mending Hands (81297,
-- 281724), Pyroclasmic Ignition (271125).
-- Savage Momentum (1556008) and Growing Light (270661) were dropped in review 2026-11-18: the core already does them.
-- Savage Momentum keeps one fix: its Stampede extension (1556022) adds 2 sec instead of setting the time left to 2 sec.
-- Core patch 70: Mastery of the Tide (1574368, 274948).
-- With rows: Holy Ground (81315, 281788: allies in your Consecration) and Fire Walk With Me (1584166: Scorch helper).
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81315, 281788, 1584166);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81315, 281788, 1584166, 1556022) AND `ScriptName` LIKE 'spell\_wcme\_%';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1556022, 'spell_wcme_stampede_extension'),
(81315, 'spell_wcme_area_keeper'),
(281788, 'spell_wcme_area_keeper'),
(1584166, 'spell_wcme_area_keeper');
