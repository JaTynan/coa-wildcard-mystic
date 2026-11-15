-- Next batch of coded Mystic Enchants (needs the build with this version of mystic-enchants-scripts.patch): the random
-- class spell enchants (Crazy Cultist, Deranged Druid, Eccentric Elementalist, Wacky Wizardry, Zany Zealot), Blessing of
-- the Divines, and the stack builders (Felborne, Abiding Fel Energy, Fel Strike, Overloaded Froststorm, Astral Tempest,
-- Blademaster, both Shadow Visions, Unrelenting Wrath). Fel Meteor and Unrelenting Wrath are taught while their enchant
-- is active and need their stacks or charge to cast.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 84529),
('spell_proc', 1568195),
('spell_proc', 84531),
('spell_proc', 1568216),
('spell_proc', 84533),
('spell_proc', 1568237),
('spell_proc', 965442),
('spell_proc', 1571306),
('spell_proc', 84527),
('spell_proc', 1568174),
('spell_proc', 965476),
('spell_proc', 101086),
('spell_proc', 84805),
('spell_proc', 84806),
('spell_proc', 81122),
('spell_proc', 81479),
('spell_proc', 965862),
('spell_proc', 965299),
('spell_proc', 1570700),
('spell_proc', 965288);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (84529, 1568195, 84531, 1568216, 84533, 1568237, 965442, 1571306, 84527, 1568174, 965476, 101086, 84805, 84806, 81122, 81479, 965862, 965299, 1570700, 965288);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (84529, 1568195, 84531, 1568216, 84533, 1568237, 965442, 1571306, 84527, 1568174, 965476, 101086, 84805, 84806, 81122, 81479, 965862, 965299, 1570700, 965288, 101087, 965289) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (84529, 1568195, 84531, 1568216, 84533, 1568237, 965442, 1571306, 84527, 1568174, 965476, 101086, 84805, 84806, 81122, 81479, 965862, 965299, 1570700, 965288);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(84529, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(1568195, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(84531, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(1568216, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(84533, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(1568237, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(965442, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(1571306, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(84527, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(1568174, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0),
(965476, 0, 0, 0, 0, 0, 16384, 2, 2, 0, 0, 0, 0, 0, 0, 0),
(101086, 0, 0, 0, 0, 0, 87312, 3, 2, 0, 0, 0, 0, 0, 0, 0),
(84805, 0, 0, 0, 0, 0, 87312, 3, 2, 0, 0, 0, 0, 0, 0, 0),
(84806, 0, 0, 0, 0, 0, 87312, 3, 2, 0, 0, 0, 0, 0, 0, 0),
(81122, 0, 0, 0, 0, 0, 69904, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(81479, 0, 0, 0, 0, 0, 69904, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(965862, 0, 0, 0, 0, 0, 56, 0, 2, 0, 0, 0, 0, 0, 0, 0),
(965299, 0, 0, 0, 0, 0, 327680, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(1570700, 0, 0, 0, 0, 0, 327680, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(965288, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 0, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(84529, 'spell_wcme_random_class_spell'),
(1568195, 'spell_wcme_random_class_spell'),
(84531, 'spell_wcme_random_class_spell'),
(1568216, 'spell_wcme_random_class_spell'),
(84533, 'spell_wcme_random_class_spell'),
(1568237, 'spell_wcme_random_class_spell'),
(965442, 'spell_wcme_random_class_spell'),
(1571306, 'spell_wcme_random_class_spell'),
(84527, 'spell_wcme_random_class_spell'),
(1568174, 'spell_wcme_random_class_spell'),
(965476, 'spell_wcme_blessing_of_the_divines_random'),
(101086, 'spell_wcme_fel_energy'),
(84805, 'spell_wcme_fel_energy'),
(84806, 'spell_wcme_fel_energy'),
(81122, 'spell_wcme_overloaded'),
(81479, 'spell_wcme_overloaded'),
(965862, 'spell_wcme_blademaster'),
(965299, 'spell_wcme_shadow_visions'),
(1570700, 'spell_wcme_shadow_visions'),
(965288, 'spell_wcme_unrelenting_wrath'),
(101087, 'spell_wcme_reactive_spell'),
(965289, 'spell_wcme_reactive_spell');
INSERT INTO `wcme_enchant_teach` (`enchant_spell`, `taught_spell`, `comment`) VALUES
(101086, 101087, 'Felborne: teaches Fel Meteor, castable at 5 stacks of Meteoric Impact'),
(965288, 965289, 'Unrelenting Wrath: teaches Unrelenting Wrath, castable with a charge');
