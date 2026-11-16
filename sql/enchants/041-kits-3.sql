-- Legendary kits, batch 3 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Edge of Fury (986234): 500 maximum rage (wcme_rage_cap), Spiteful Strike and Blind Revenge in place of Heroic Strike
-- and Revenge, Backstab rage and Blind Revenge unlock, Edge of Fury stacks, a faster Killing Spree at 5 stacks.
-- Forbidden Technique (954326): its own shot (954327) in place of Shadow Dance instead of twin 852208's (006 no longer
-- teaches 271981), Forbidden Dance and the teleport back, Dusk Dagger, Dusk Shot, Shadow Powers, Dusk Blade, Forbidden
-- Chants from Meditate.
-- Fury of the Titans (977810): 300 maximum rage, Titanic Strike taught with Titan's Grip, Titanic Fury only at full rage
-- (and the rage loss after it), combo points from Titanic Fury auto attacks and from spending Titanic Power.
-- Grove Ranger (997124): Blooming Shot and Medicinal Sting in place of Arcane Shot and Serpent Sting, Grover's Touch and
-- Grove Shot taught, Grove Ranger's Agility, Grove Ranger stacks, Steady Shot charge refunds, ranged attack power in
-- its heals and Blooming Shot's damage.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 986234),
('spell_proc', 954326),
('spell_proc', 977810),
('spell_proc', 997124);
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 954326;
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (986234, 954326, 977810, 997124);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (986234, 986240, 986236, 51690, 800219, 954326, 954327, 986233, 965426,
  977810, 977813, 977812, 977811, 997124, 985601, 985610, 92726, 92737) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (986234, 954326, 977810, 997124);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(986234, 0, 0, 0, 0, 0, 16, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(954326, 0, 0, 0, 0, 0, 272, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(977810, 0, 0, 0, 0, 0, 65556, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(997124, 0, 0, 0, 0, 0, 16640, 0, 3, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(986234, 'spell_wcme_edge_of_fury'),
(986240, 'spell_wcme_blind_revenge'),
(986236, 'spell_wcme_spiteful_strike'),
(51690, 'spell_wcme_edge_killing_spree'),
(800219, 'spell_wcme_edge_killing_spree'),
(954326, 'spell_wcme_forbidden_technique'),
(954327, 'spell_wcme_forbidden_shot'),
(986233, 'spell_wcme_forbidden_dance'),
(965426, 'spell_wcme_meditate_chants'),
(977810, 'spell_wcme_fury_of_the_titans'),
(977813, 'spell_wcme_titanic_strike'),
(977812, 'spell_wcme_titanic_strike_off'),
(977811, 'spell_wcme_titanic_fury'),
(997124, 'spell_wcme_grove_ranger'),
(985601, 'spell_wcme_grove_heal'),
(985610, 'spell_wcme_grove_heal'),
(92726, 'spell_wcme_blooming_shot'),
(92737, 'spell_wcme_medicinal_sting');
