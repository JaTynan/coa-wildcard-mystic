-- Fixes from checking our guessed enchants against the archived Ascension builder tooltips (needs the build with this
-- version of mystic-enchants-scripts.patch). Deadly Bite's own version (965292) is Ascension's real design, not a
-- placeholder for its twin 272353: it teaches Savage Blade and stacks its own bleed (spell_wcme_deadly_bite_stacks).
-- 004 no longer blanks it or links it to 272353.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 965292);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` = 965292;
DELETE FROM `spell_script_names` WHERE `spell_id` = 965292 AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` = 965292;
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(965292, 0, 0, 0, 0, 0, 262416, 1, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(965292, 'spell_wcme_deadly_bite_stacks');
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 965292;
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(965292, 983797, 'Deadly Bite: teaches Savage Blade');
