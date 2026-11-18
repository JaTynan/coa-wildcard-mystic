-- Quick legendary fixes, part 1 (database only): copies whose own buff already works and only needed a trigger or a
-- link. Shadow Blades' taught buff (1180000, a dummy) now carries the working Shadow Blades (277847). Fire Watch's
-- legendary copy (978220) carries its working twin (274470). Blazing Flame: Blast Wave and Dragon's Breath grant
-- Blazing Speed.
-- Soul Erosion (1180480) is the core's own (review 2026-11-18): its rule empowers the next Drain Soul on Unstable
-- Affliction or Curse of Agony damage, at the spell's own 8% chance. Our row here replaced the core's proc row with one at
-- 100%, so the core's rule fired on every tick; ours is gone and the core's row is put back as it ships.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1181400);
DELETE FROM `spell_linked_spell` WHERE `spell_trigger` IN (1180000, 978220) AND `comment` LIKE 'WCME:%';
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(1180000, 277847, 2, 'WCME: Shadow Blades (taught by 1180002) carries the working Shadow Blades effect'),
(978220, 274470, 2, 'WCME: Fire Watch (legendary) carries its working twin 274470');
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (1180480, 1181400);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1180480, 1181400) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1180480, 1181400);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1181400, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0);
-- The core's own proc row for Soul Erosion, exactly as it ships (not owned, so the patch-night reset leaves it).
REPLACE INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1180480, 0, 0, 0, 0, 0, 0x55550, 0, 0x3, 0x0, 0x2, 0, 0, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1181400, 'spell_wcme_enchant_action');
INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(1181400, 0, '1831 11113 11114 13018 13019 13020 13021 15091 15744 16046 17145 17277 20229 22424 23039 23113 23331 25049 27133 30092 30600 33061 33933 36278 38064 38536 38712 39001 39038 42944 42945 58970 60290 61362 66044 68312 70407 71151 76473 83999 85393 91924 100200 100349 340079 350102 350146 350151 350171 351072 354131 355681 750613 891834 954324 954650 985899 1002051 1111113 1113018 1113019 1113020 1113021 1115091 1115744 1116046 1117145 1117277 1120229 1122424 1123039 1123113 1123331 1125049 1127133 1130092 1130600 1133061 1133933 1136278 1138064 1138536 1138712 1139001 1139038 1142944 1142945 1158970 1160290 1161362 1187079 1187080 1211113 1584691 2090100 2090101 2090102 2100205 2100206 2100207 2100208 2101040 2101041 2101042 2101043 2101221 2101222 2101223 2101224 2108004 2108005 2108006 2108007 2116711 2116712 2116713 2116714 2125037 2125038 2125039 2125040 2125225 2125226 2125227 2125228 2130088 2132154 2132155 2132156 2132157 2135354 2135355 2135356 2135357 2145185 2145186 2145857 2145858 2145859 2145860 2146692 2152116 2152117 2152118 2152119 2153526 2153527 2153528 2153529 29964 29965 31661 31681 31712 33041 33042 33043 35250 37289 42949 42950 84500 84501 84502 84503 84504 84505 688416 688417 688418 688419 801413 983211 983213 993932 1131661 1133041 1133042 1133043 1135250 1137289 1142949 1142950 1231661 1432161 2135095 2135096 2135097 2135098 9931147', 0, '', '', 100, 0, 'cast_self', '1181401', 0, 'Blazing Flame: Blast Wave or Dragon''s Breath grants Blazing Speed');
-- Part 2 (needs the build with this version of mystic-enchants-scripts.patch): Overheating, Aimed Explosive Shot's
-- blasts, Flame On!, Frozen Chaos, Whispers of the Old Gods' Madness (both copies) and Prophet of Wrath.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 81119),
('spell_proc', 965293),
('spell_proc', 980673),
('spell_proc', 979796);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (81119, 965293, 980673, 979796);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (81119, 81449, 965293, 980673, 272951, 1571328, 979796) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (81119, 965293, 980673, 979796);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(81119, 0, 0, 0, 0, 0, 65552, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(965293, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(980673, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(979796, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(81119, 'spell_wcme_overheating'),
(81449, 'spell_wcme_aimed_explosive_shot'),
(965293, 'spell_wcme_flame_on'),
(980673, 'spell_wcme_frozen_chaos'),
(272951, 'spell_wcme_old_gods_madness'),
(1571328, 'spell_wcme_old_gods_madness'),
(979796, 'spell_wcme_prophet_of_wrath');
-- Part 3: Frost and Demonology Mastery put their pet bonus on your Water Elemental / demon; Hydromancer's Doused makes
-- Lightning Bolt and Chain Lightning Electrocute; Thermal Void now fires from Ice Barrier (its own flags only listed
-- hostile spells), once a second at most.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1134961),
('spell_proc', 1134965),
('spell_proc', 1569697),
('spell_proc', 983739);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (1134961, 1134965, 1569697, 983739);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1134961, 1134965, 1569697) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1134961, 1134965, 1569697, 983739);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1134961, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(1134965, 0, 0, 0, 0, 0, 87312, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(1569697, 0, 0, 0, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(983739, 0, 3, 0, 1, 0, 17408, 0, 2, 0, 0, 0, 0, 100, 1000, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1134961, 'spell_wcme_pet_mastery'),
(1134965, 'spell_wcme_pet_mastery'),
(1569697, 'spell_wcme_doused');
-- Part 4: Elemental Assassin, Stormborn and Compound Power.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 978229),
('spell_proc', 977991),
('spell_proc', 979740);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (978229, 977991, 979740);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (978229, 977991, 979740) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (978229, 977991, 979740);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(978229, 0, 0, 0, 0, 0, 65552, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(977991, 0, 0, 0, 0, 0, 65552, 0, 3, 0, 2, 0, 0, 100, 0, 0),
(979740, 0, 0, 0, 0, 0, 65792, 1, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(978229, 'spell_wcme_elemental_assassin'),
(977991, 'spell_wcme_stormborn'),
(979740, 'spell_wcme_compound_power');
-- Part 5: One With The Light's builder copy (979748) carries its working twin (1575034: Crusader Strike, Divine Storm
-- and Hammer of the Righteous add a Holy strike); its own halved Physical damage stays as data.
DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 979748 AND `comment` LIKE 'WCME:%';
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(979748, 1575034, 2, 'WCME: One With The Light (builder copy) carries its working twin 1575034');
