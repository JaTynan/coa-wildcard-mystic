-- Epic enchants, batch 2 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Finishing-move procs (spell_wcme_finisher_combo, 20% per combo point): Cobra Combo (979106, 284148), Double Team
-- (275094), Deadly Combo (977856, 283833), Enraging Finale (283405), Titanic Finale (954436), Adrenaline Junkie
-- (1589466), Swashbuckler: Bloodsail (983110, 285111; 983113 gives its rage on main-hand hits).
-- Weapon Command (954057, 283338: single two-handed weapon), the Companions (81418-81422: hunter pet auto attack school)
-- and, as a hook only, I Have The High Ground (81090) and Titanic Finale's Enrage speed.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 979106), ('spell_proc', 284148), ('spell_proc', 275094), ('spell_proc', 977856), ('spell_proc', 283833),
('spell_proc', 283405), ('spell_proc', 954436), ('spell_proc', 1589466), ('spell_proc', 983110), ('spell_proc', 285111),
('spell_proc', 983113);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (979106, 284148, 275094, 977856, 283833, 283405, 954436, 1589466,
  983110, 285111, 954057, 283338, 81418, 81419, 81420, 81421, 81422);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (979106, 284148, 275094, 977856, 283833, 283405, 954436, 1589466, 983110,
  285111, 983113, 954057, 283338, 81418, 81419, 81420, 81421, 81422) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (979106, 284148, 275094, 977856, 283833, 283405, 954436, 1589466, 983110, 285111,
  983113);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(979106, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(284148, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(275094, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(977856, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(283833, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(283405, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(954436, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(1589466, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(983110, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(285111, 0, 0, 0, 0, 0, 87312, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(983113, 0, 0, 0, 0, 0, 4, 0, 2, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(979106, 'spell_wcme_finisher_combo'), (284148, 'spell_wcme_finisher_combo'), (275094, 'spell_wcme_finisher_combo'),
(977856, 'spell_wcme_finisher_combo'), (283833, 'spell_wcme_finisher_combo'), (283405, 'spell_wcme_finisher_combo'),
(954436, 'spell_wcme_finisher_combo'), (1589466, 'spell_wcme_finisher_combo'), (983110, 'spell_wcme_finisher_combo'),
(285111, 'spell_wcme_finisher_combo'), (983113, 'spell_wcme_bloodsail_rage'),
(954057, 'spell_wcme_weapon_command'), (283338, 'spell_wcme_weapon_command'),
(81418, 'spell_wcme_companion'), (81419, 'spell_wcme_companion'), (81420, 'spell_wcme_companion'),
(81421, 'spell_wcme_companion'), (81422, 'spell_wcme_companion');
