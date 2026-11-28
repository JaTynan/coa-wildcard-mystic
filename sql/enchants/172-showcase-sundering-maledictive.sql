-- Two talents in the bot showcase builds that never worked (docs/bot-builds/showcase-audit.md, section 2): their
-- trigger was kept in Ascension's own server data, which we do not have. Both now use patterns already in this
-- folder. Data only: no build. Not tested in game: unverified until a player report or an automated test.
--
-- 1. Cataclysmic Sundering 277180 (shaman talent, Earthen Guardian build). Each of its three effects fires a
--    position trigger (277182, 277183, 277184: the core's delayed-trigger effect) that, 0.2, 0.4 and 0.6 seconds
--    later, places Burning Ground 277181 at 2, 6 and 10 yards in front of the shaman: fire damage every second to
--    enemies in it, and more Flame Shock damage taken. Now one action-table rule (recipe R6, as file 016): casting
--    Sundering casts all three, once per cast (cast phase only, so a Sundering that hits several enemies or misses
--    them all still leaves exactly three patches). The Sundering list is the one the core uses for the enchant
--    version of the same talent, 1578857 (coa_mystic_enchant_proc), which has the same design.
-- 2. Maledictive Assault 271400 (warlock talent, Shadow Bear build). Its bonus sits in the hidden companion 271399:
--    Shadow Bolt hits two more targets near the first (+3 jump targets); stock Shadow Bolt's own chain damage factor
--    (0.6) reduces those hits, as the tooltip says. Now an aura link (recipe R7, as file 143): while the talent is on
--    the character AND a Nightfall (Shadow Trance) or Backlash buff is up, the core grants 271399; when the buff goes,
--    so does 271399. Only the proc buffs are watched, never the talent. The talent's own proc effect (Corruption on
--    Incinerate-type spells) is not in its tooltip and has no trigger; it is left alone. Not changed here: stock
--    Shadow Bolt can already be cast in Bear Form at any time (its spell data allows bear forms), not only during
--    the two buffs; the CoA copy of Shadow Bolt (1100686 and up) cannot be cast in Bear Form at all.
--
-- Safe to run again: 000-reset empties wcme_enchant_action, removes owned spell_proc rows, spell_wcme_ bindings and
-- aura links listed in wcme_owned.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 277180),
('aura_link', 271400);
DELETE FROM `spell_proc` WHERE `SpellId` IN (277180);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(277180, 0, 0, 0, 0, 0, 65552, 7, 1, 0, 0, 0, 0, 0, 0, 0);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (277180);
INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(277180, 0, '271588 760121 760396 760397 760398 760399 992739 2110121 2760121', 0, '', '', 100, 0, 'cast_self', '277182 277183 277184', 0, 'Cataclysmic Sundering: Sundering leaves three burning patches in a line in front of you');
DELETE FROM `spell_script_names` WHERE `spell_id` IN (277180) AND `ScriptName` = 'spell_wcme_enchant_action';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(277180, 'spell_wcme_enchant_action');
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (271400);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(271400, '17941 1117941 34936 234936 1134936 1234936 1590279 1590281', 271399, 'WCME: Maledictive Assault: Shadow Bolt hits two more targets while Nightfall or Backlash is up');
