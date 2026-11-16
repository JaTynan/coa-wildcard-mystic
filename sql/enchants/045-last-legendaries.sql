-- The last legendaries (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Explosive Charge (1568152): 25% of Explosive Shot's damage to other enemies within 5 yards (its aura 354 had no
-- handler for this enchant; done in the damage hook wcme_last_legendary_hooks, so it needs no rows here).
-- Social Distancing (81102): 20% disease resistance while no other player is within 6 yards (its proc had nothing to
-- trigger).
-- Harbinger of Pestilence (990020): Wrath / Haunt stacks, Nightfall from Wrath, Harbinger's Bile on Haunt, Haunt
-- cooldown per stack, disease damage per stack against creatures (its proc had no proc flags).
-- Flame Ascendance (1398169): Flame Shock in the form finishes Lava Burst and Lava Beam; Lava Burst's critical chance
-- over 100% adds to its critical damage.
-- Checked and left as they are (already work from their data or the core): Discipline Mastery (1134969), Fury Mastery
-- (1134994), Hand of Gul'dan (1398206), Guardians of the Grove (1567585) and Predator's Wrath: Wrathful Strikes
-- (1572260); see enchants/legendary-notes.md.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 81102),
('spell_proc', 990020),
('spell_proc', 1398169);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81102, 990020, 1398169);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81102, 990020, 1398169) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (81102, 990020, 1398169);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(990020, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(1398169, 0, 0, 0, 0, 0, 65536, 0, 1, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(81102, 'spell_wcme_social_distancing'),
(990020, 'spell_wcme_harbinger_of_pestilence'),
(1398169, 'spell_wcme_flame_ascendance');
