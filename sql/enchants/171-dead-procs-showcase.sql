-- Dead procs in the bot showcase builds (docs/bot-builds/showcase-audit.md, section 2): proc talents with no trigger
-- conditions in their spell data (proc flags 0) and no rule in the core or in our files, so they never fired.
-- Ascension kept those conditions in its own database. Each now fires through the enchant action table
-- (spell_wcme_enchant_action, recipe R6, in every build since build6). Data only: no build.
--
-- 1. Demonic Mind, all three versions: the Wildcard talent 283942, 978704, and 1586069 (the spell the enchant 977940
--    teaches). Direct spell damage has a 75% chance (the spell's own proc chance) to put Demonic Wounds on the target
--    (each version's own copy: 283944, 997323, 1586071). The GM test of 3 Nov saw the crit bonus work and this part
--    never fire.
-- 2. Swirling Maelstrom 984616: Lava Lash and Stormstrike hits have a 33% chance (from its sister spell 984610) to
--    give a Swirling Maelstrom stack (984617); one roll per Stormstrike or Lava Lash cast, not per weapon hit. Not done here: the guaranteed stack when 5 Maelstrom Weapon stacks are
--    spent; the action table cannot see stacks being spent.
--
-- Safe to run again: 000-reset empties wcme_enchant_action, removes owned spell_proc rows and spell_wcme_ bindings.
-- Not tested in game: unverified until a player report or an automated test.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 283942),
('spell_proc', 978704),
('spell_proc', 1586069),
('spell_proc', 984616);
DELETE FROM `spell_proc` WHERE `SpellId` IN (283942, 978704, 1586069, 984616);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(283942, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(978704, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(1586069, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(984616, 0, 0, 0, 0, 0, 16, 1, 2, 0, 0, 0, 0, 0, 0, 0);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (283942, 978704, 1586069, 984616);
INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(283942, 0, '', 0, '', '', 75, 0, 'cast_target', '283944', 0, 'Demonic Mind: direct spell damage may put Demonic Wounds on the target'),
(978704, 0, '', 0, '', '', 75, 0, 'cast_target', '997323', 0, 'Demonic Mind: direct spell damage may put Demonic Wounds on the target'),
(1586069, 0, '', 0, '', '', 75, 0, 'cast_target', '1586071', 0, 'Demonic Mind: direct spell damage may put Demonic Wounds on the target'),
(984616, 0, '60103 65974 254121 901603 901608 1160103 1260103 17364 17373 17374 17375 17376 17377 17378 17379 51876 64757 65970 65971 65972 254097 254098 254754 255923 277110 355290 355291 688204 688205 688206 688207 802190 901604 901605 965436 965695 997755 1117364 1217364 1578592 1578593 1578594', 0, '', '', 33, 0, 'cast_self', '984617', 0, 'Swirling Maelstrom: Lava Lash and Stormstrike hits may give a stack');
DELETE FROM `spell_script_names` WHERE `spell_id` IN (283942, 978704, 1586069, 984616) AND `ScriptName` = 'spell_wcme_enchant_action';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(283942, 'spell_wcme_enchant_action'),
(978704, 'spell_wcme_enchant_action'),
(1586069, 'spell_wcme_enchant_action'),
(984616, 'spell_wcme_enchant_action');
