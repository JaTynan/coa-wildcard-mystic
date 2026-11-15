-- Mystic Enchants with their own code (needs the build with mystic-enchants-scripts.patch and 64-enchant-scripts-loader.ps1).
-- Each enchant spell is bound to its script in src/server/coa/WcmeEnchantScripts.cpp, which replaces the rough
-- action-table rule an earlier file may give it (015, 016): the rows here remove that rule. On a server without the
-- build these enchants do nothing until it is installed (unknown script names are only logged).
-- Rush of Blood 1587050, Martial Crescendo 84752, Tools of War 84750, Curse of Arugal 982806, Primordial Fury 977717, Ice Lash 977764, Words of Healing 81470, Ambidextrous 977771, Nature's Fervor 965283, Controlled Burn 81407, Eldritch Knight 81116, Disciple of the Tides 274921, Twilight Paragon 977824, Consecrated Strikes 965295, Consecrated Weapon 977848.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1587050),
('spell_proc', 84752),
('spell_proc', 84750),
('spell_proc', 982806),
('spell_proc', 977717),
('spell_proc', 977764),
('spell_proc', 81470),
('spell_proc', 977771),
('spell_proc', 965283),
('spell_proc', 81407),
('spell_proc', 81116),
('spell_proc', 274921),
('spell_proc', 977824),
('spell_proc', 965295),
('spell_proc', 977848);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (1587050, 84752, 84750, 982806, 977717, 977764, 81470, 977771, 965283, 81407, 81116, 274921, 977824, 965295, 977848);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1587050, 84752, 84750, 982806, 977717, 977764, 81470, 977771, 965283, 81407, 81116, 274921, 977824, 965295, 977848, 59887, 59888, 59889, 59890, 59891, 276407, 1159887, 1159888, 1159889, 1159890, 1159891, 1259887, 1259888, 1259889, 1259890, 1259891, 1576968) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1587050, 84752, 84750, 982806, 977717, 977764, 81470, 977771, 965283, 81407, 81116, 274921, 977824, 965295, 977848);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1587050, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(84752, 0, 0, 0, 0, 0, 332048, 1, 2, 0, 2, 0, 0, 0, 0, 0),
(84750, 0, 0, 0, 0, 0, 332048, 1, 2, 0, 2, 0, 0, 0, 0, 0),
(982806, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 0, 0, 0),
(977717, 0, 0, 0, 0, 0, 69904, 1, 2, 2, 0, 0, 0, 0, 0, 0),
(977764, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 0, 0, 0),
(81470, 0, 0, 0, 0, 0, 17408, 2, 2, 0, 0, 0, 0, 0, 0, 0),
(977771, 0, 0, 0, 0, 0, 20, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(965283, 0, 0, 0, 0, 0, 65552, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(81407, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 0, 0, 0),
(81116, 0, 0, 0, 0, 0, 69904, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(274921, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(977824, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 2, 0, 0, 0, 0, 0),
(965295, 0, 0, 0, 0, 0, 16, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(977848, 0, 0, 0, 0, 0, 16, 1, 2, 0, 0, 0, 0, 0, 0, 0);
-- Borrowed Time (the buff) is kept, not used up, while Words of Healing is active.
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1587050, 'spell_wcme_rush_of_blood'),
(84752, 'spell_wcme_unique_physical_stacks'),
(84750, 'spell_wcme_unique_physical_stacks'),
(982806, 'spell_wcme_curse_of_arugal'),
(977717, 'spell_wcme_primordial_fury'),
(977764, 'spell_wcme_ice_lash'),
(81470, 'spell_wcme_words_of_healing'),
(977771, 'spell_wcme_ambidextrous'),
(965283, 'spell_wcme_natures_fervor'),
(81407, 'spell_wcme_controlled_burn'),
(81116, 'spell_wcme_eldritch_knight'),
(274921, 'spell_wcme_disciple_of_the_tides'),
(977824, 'spell_wcme_twilight_paragon'),
(965295, 'spell_wcme_consecrated_strikes'),
(977848, 'spell_wcme_consecrated_weapon'),
(59887, 'spell_wcme_borrowed_time_kept'),
(59888, 'spell_wcme_borrowed_time_kept'),
(59889, 'spell_wcme_borrowed_time_kept'),
(59890, 'spell_wcme_borrowed_time_kept'),
(59891, 'spell_wcme_borrowed_time_kept'),
(276407, 'spell_wcme_borrowed_time_kept'),
(1159887, 'spell_wcme_borrowed_time_kept'),
(1159888, 'spell_wcme_borrowed_time_kept'),
(1159889, 'spell_wcme_borrowed_time_kept'),
(1159890, 'spell_wcme_borrowed_time_kept'),
(1159891, 'spell_wcme_borrowed_time_kept'),
(1259887, 'spell_wcme_borrowed_time_kept'),
(1259888, 'spell_wcme_borrowed_time_kept'),
(1259889, 'spell_wcme_borrowed_time_kept'),
(1259890, 'spell_wcme_borrowed_time_kept'),
(1259891, 'spell_wcme_borrowed_time_kept'),
(1576968, 'spell_wcme_borrowed_time_kept');
