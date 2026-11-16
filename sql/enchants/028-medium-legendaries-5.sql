-- Medium legendaries, batch 5 (needs the build with this version of mystic-enchants-scripts.patch).
-- Assuaging Shadows (965334): Shadow Nova and Shadow Marks from Shadow Dance, marks spent by Ambush or Ravage,
-- longer Shadowstep, and Shadow's Embrace finishing-move effects.
-- Corrupted Bear Form (99634): Corrupted Bear in Bear and Dire Bear Form (its form script is bound to the forms),
-- Corrupted Paw on auto attacks, Corruption from Maul and Mangle, Corrupted Hunger from Swipe, instant Shadow Bolts.
-- Prayer of Preservation (986033): Preservation, Shield of Preservation and the extra heal; the prayer's last tick
-- heals 70% more (888571).
-- Righteous Flames (81298): Inner Fire charges boost and feed Fire hits, Righteous Flames stacks, Radiant damage.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 965334),
('spell_proc', 99634),
('spell_proc', 986033),
('spell_proc', 81298);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (965334, 99634, 986033, 81298);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (965334, 99634, 5487, 9634, 1105487, 1109634, 986033, 888571, 81298) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (965334, 99634, 986033, 81298);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(965334, 0, 0, 0, 0, 0, 5136, 0, 7, 0, 0, 0, 0, 100, 0, 0),
(99634, 0, 0, 0, 0, 0, 65556, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(986033, 0, 0, 0, 0, 0, 16384, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(81298, 0, 0, 0, 0, 0, 82944, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(965334, 'spell_wcme_assuaging_shadows'),
(99634, 'spell_wcme_corrupted_bear_form'),
(5487, 'spell_wcme_corrupted_bear_shape'),
(9634, 'spell_wcme_corrupted_bear_shape'),
(1105487, 'spell_wcme_corrupted_bear_shape'),
(1109634, 'spell_wcme_corrupted_bear_shape'),
(986033, 'spell_wcme_prayer_of_preservation'),
(888571, 'spell_wcme_prayer_of_preservation_hot'),
(81298, 'spell_wcme_righteous_flames');
