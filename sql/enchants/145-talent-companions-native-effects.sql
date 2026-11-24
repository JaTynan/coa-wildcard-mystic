-- Talent companions, batch 4 (code), part 2: two talents the core can already run, once their rules are written.
-- Data only, except Battle Fatigue's cap, which needs patch 55 (see 1).
-- Their companions fire Ascension effect types this core implements (SpellEffects.cpp): 173 refreshes or extends an
-- aura, 197 changes the cooldown of a class's spells by class flag. What Ascension kept in its own database is the
-- trigger rules, so this file writes them from the tooltips. Needs a server start. Safe to run
-- again (000-reset removes WCME: links, owned spell_proc and spell_dbc rows, action rules and spell_wcme_ bindings).
-- Each read by hand on 24 Nov 2026. Not tested in game: these stay unverified until a player report or an automated
-- test.
--
-- 1. Battle Fatigue (272854). Warrior shouts, banners and Warcry apply Battle Fatigue (272848: +8% physical damage
--   taken from you, 20 sec) to enemies within 10 yards, at most once every 30 sec; physical melee attacks and
--   abilities have a 30% chance to add 1 sec to it.
--   - The shouts: an action rule on the talent lists every shout, banner and Warcry by id (no class flag covers
--     them all) and casts 272848 around you, with the 30 sec limit.
--   - The extension: the companion (272846) is linked to the talent and given its proc rule (physical melee
--     damage, 30%). It fires 272845, effect 173 on 272848. That spell's second value is 0, which tells the core
--     to SET the duration (to 1,001 ms) instead of adding to it: as it is, every proc would cut the debuff to a
--     second. Our copy sets the second value to 10000: add 1 sec per proc, never past 10 sec beyond the debuff's
--     20 sec (+50%).
--   - The cap is James's decision (24 Nov 2026): the tooltip gives none, and without one steady melee keeps the
--     debuff up for good. +50% sits in the middle of comparable extension talents (Glyph of Shred +50%, Endless
--     Agonizer +50%, Glyph of Scourge Strike +60%, Frozen Grave +40%). The cap needs patch 55 (build); before that
--     build the core reads any non-zero second value as plain "add", so the extension works uncapped until then.
--
-- 2. Divine Reset (277920). Direct Holy damage has a 20% chance to reset Divine Storm (277921, effect 197) and, in
--   the same roll, give Divine Storm +50% damage (277919); and a separate 40% chance (the companion, 277916) to take
--   5 sec off Execution Sentence (277922, effect 197). Both talent effects fire on one proc, so the reset and the
--   buff always come together. The buff removes itself 100 ms after it is used (277918 -> 277917); without a rule
--   any melee ability would use it, so its rule names Divine Storm only (its class flag).
--   Each proc rule: Holy school, direct damage (melee, ranged and magic spells, not periodic), on hit.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(272854, 272846, 2, 'WCME: Battle Fatigue applies its melee extension companion'),
(277920, 277916, 2, 'WCME: Divine Reset applies its Execution Sentence companion');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 272854), ('spell_proc', 272846), ('spell_proc', 277920), ('spell_proc', 277916), ('spell_proc', 277919), ('spell_dbc', 272845);
DELETE FROM `spell_proc` WHERE `SpellId` IN (272854, 272846, 277920, 277916, 277919);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(272854, 0, 0, 0, 0, 0, 104720, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(272846, 1, 0, 0, 0, 0, 20, 1, 2, 0, 0, 0, 0, 30, 0, 0),
(277920, 2, 0, 0, 0, 0, 65808, 1, 2, 0, 0, 0, 0, 20, 0, 0),
(277916, 2, 0, 0, 0, 0, 65808, 1, 2, 0, 0, 0, 0, 40, 0, 0),
(277919, 0, 10, 0, 131072, 0, 16, 1, 2, 0, 0, 0, 0, 100, 0, 0);

INSERT INTO `wcme_enchant_action` (`enchant_spell`, `rule`, `spells`, `school_mask`, `target_aura`, `requires_aura`, `chance`, `cooldown_ms`, `action`, `action_spells`, `amount`, `comment`) VALUES
(272854, 0, '469 1160 1161 2048 5242 5246 6190 6192 6673 11549 11550 11551 11554 11555 11556 13730 16244 18328 19134 19778 20511 25202 25203 25289 27578 27579 29544 29584 33789 38945 38946 45517 47436 47437 47439 47440 59613 61044 61578 62102 65930 69565 84277 102929 102930 155799 161203 225289 272851 283412 340006 340076 365104 383150 388554 500259 500261 500995 600469 601160 601161 605246 606673 954509 954514 955062 992971 1100469 1101160 1101161 1102048 1105242 1105246 1106190 1106192 1106673 1111549 1111550 1111551 1111554 1111555 1111556 1113730 1116244 1118328 1119134 1119778 1120511 1123511 1125202 1125203 1125289 1127578 1127579 1129544 1129584 1133789 1138945 1138946 1145517 1147436 1147437 1147439 1147440 1159613 1161044 1161578 1162102 1165930 1169565 1180271 1405742 1405746 1406692 1407173 1571219 1584504 1954514 2304514 2305062 6072022 10013730', 0, '', '', 100, 30000, 'cast_self', '272848', 0, 'Battle Fatigue: a shout, banner or Warcry applies Battle Fatigue to enemies within 10 yards, once every 30 sec');

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(272854, 'spell_wcme_enchant_action');

DELETE FROM `spell_dbc` WHERE `ID` IN (272845);
INSERT INTO `spell_dbc` VALUES
(272845, 0, 0, 0, 2147484032, 0, 4, 1048576, 128, 0, 8388608, 2147483648, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1024, 100, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 6, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 173, 0, 0, 1, 1, 1, 0.0, 0.0, 0.0, 1000, -1, -1, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 272848, 0, 0, 10000, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 'Battle Fatigue duration', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);
