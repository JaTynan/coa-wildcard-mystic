-- Talent companions, batch 5 (probable list), part 2: three talents and abilities whose companion needs more than a
-- link. Explosive Charge and Authority need the build with patch 55 (its "part 6" section): without it the bindings
-- name scripts that do not exist yet (the server logs an error for each and carries on). Challenging Echo is data
-- only. Safe to run again (000-reset removes WCME: links, owned spell_dbc and spell_proc rows, ability companions,
-- all of wcme_spellaffect_dbc and spell_wcme_ bindings). Each read by hand on 25 Nov 2026. Not tested in game:
-- unverified until a player report or an automated test.
--
-- 1. Debilitating Roar (283530) and Challenging Echo (283527). The talent gives Challenging Roar and Challenging
--   Shout 1 sec more duration and 12 sec less cooldown, and grants Challenging Echo: the taunted enemies also deal 15%
--   less damage. Nothing granted Echo (now linked to the talent). Both spells are druid-family modifiers, which this
--   core only lets touch druid spells, so the warrior's Challenging Shout was never affected. Our copies of both drop
--   the class flags and name their targets instead (wcme_spellaffect_dbc, 960020-960027): Challenging Roar and
--   Challenging Shout, the stock and CoA versions. The CoA Challenging Shout (1101161) has no damage effect, so Echo
--   changes only its duration and cooldown through the talent. The talent is also an Epic enchant; it gains the same.
-- 2. Explosive Shot (all six stock ranks) holds Explosive Charge (906142): each hit of the shot's damage, the first
--   blast and every tick, also deals 40% of that damage to the other enemies within 5 yards (906143), split between
--   them. Choice made: the companion's own tooltip says "split"; the shot's tooltip reads as each enemy taking 40%.
--   Split is the smaller of the two and the companion carries the effect. Proc rule: Explosive Shot's damage spell
--   (hunter class flag 0x200 in the third mask), ranged spell damage, on hit, triggered spells allowed (the ticks are
--   triggered).
-- 3. Authority (299120): Execution Sentence's ticks stack Authority on the target (the talent's trigger had no proc
--   rule: now periodic damage done by Execution Sentence, paladin flag 0x2000000 in the third mask). Shield of
--   Righteousness consumes the stacks and gives the paladin 3% less damage taken per stack for 8 sec (patch 55
--   script, bound to every Shield of Righteousness version that deals damage). The companion (299123, now linked)
--   gives Shield of Righteousness a 20% chance to reset Execution Sentence (299124).
--
-- Checked and left alone:
-- - Thunder Hide (277080): its upgrade, Protected by Thunder (277112, and the CoA copy 1578661), is only quoted as
--   "if you have it" in the buff text; no talent, ability or Character Advancement entry grants it in our data.
--   Linking it to the ability would hand everyone a bonus nothing in the game offers.
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(283530, 283527, 2, 'WCME: Debilitating Roar grants Challenging Echo'),
(299120, 299123, 2, 'WCME: Authority applies its Execution Sentence reset companion');

INSERT INTO `wcme_spell_companion` (`ability_spell`, `passive_spell`, `flags`, `comment`) VALUES
(53301, 906142, 0, 'Explosive Shot rank 1: Explosive Charge splash'),
(53319, 906142, 0, 'Explosive Shot rank 2: Explosive Charge splash'),
(53320, 906142, 0, 'Explosive Shot rank 3: Explosive Charge splash'),
(60051, 906142, 0, 'Explosive Shot rank 4: Explosive Charge splash'),
(60052, 906142, 0, 'Explosive Shot rank 5: Explosive Charge splash'),
(60053, 906142, 0, 'Explosive Shot rank 6: Explosive Charge splash');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_dbc', 283527), ('spell_dbc', 283530);
DELETE FROM `spell_dbc` WHERE `ID` IN (283527, 283530);
INSERT INTO `spell_dbc` VALUES
(283527, 0, 0, 0, 2147484112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 0, 0, 1, 1, 1, 0.0, 0.0, 0.0, -16, -1, -1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 107, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 957, 0, 0, 'Challenging Echo', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 1', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1.0, 0.0, 0.0, 0, 0),
(283530, 0, 0, 0, 2147484112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, 999, -12001, -1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 107, 107, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 1, 11, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 957, 0, 0, 'Debilitating Roar', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1.0, 1.0, 0.0, 0, 0);

INSERT INTO `wcme_spellaffect_dbc` (`ID`, `ModifierSpellID`, `AffectedSpellID`) VALUES
(960020, 283527, 5209),
(960021, 283527, 1105209),
(960022, 283527, 1161),
(960023, 283527, 1101161),
(960024, 283530, 5209),
(960025, 283530, 1105209),
(960026, 283530, 1161),
(960027, 283530, 1101161);

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 906142), ('spell_proc', 299120), ('spell_proc', 299123);
DELETE FROM `spell_proc` WHERE `SpellId` IN (906142, 299120, 299123);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(906142, 0, 9, 0, 0, 512, 256, 1, 2, 0, 2, 0, 0, 100, 0, 0),
(299120, 0, 10, 0, 0, 33554432, 262144, 1, 2, 0, 0, 0, 0, 100, 0, 0),
(299123, 0, 10, 0, 1048576, 0, 87312, 0, 1, 0, 0, 0, 0, 20, 0, 0);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(906142, 'spell_wcme_explosive_charge'),
(906143, 'spell_wcme_explosive_charge_splash'),
(53600, 'spell_wcme_authority_consume'),
(61411, 'spell_wcme_authority_consume'),
(1153600, 'spell_wcme_authority_consume'),
(1161411, 'spell_wcme_authority_consume');
