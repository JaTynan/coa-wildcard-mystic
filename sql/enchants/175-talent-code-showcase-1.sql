-- Showcase talents, batch 1 (docs/bot-builds/showcase-audit.md): the data half of the fixes in patches/55-talent-
-- fixes.ps1 ("Showcase talents, batch 1"), plus Arcane Gunslinger, which needs no code. The script bindings below
-- do nothing until a build with that part of patch 55 is installed (the server logs one error per missing script
-- and carries on); nothing here changes play before then except Arcane Gunslinger. Safe to run again: 000-reset
-- removes spell_wcme_ bindings, WCME: links and owned aura links. Not tested in game: unverified until a player
-- report or an automated test.
--
-- 1. Raging Onslaught 275920 and 2. Master of Kunai: only the script bindings here. Their proc rows wait for the
--    build: without the script, Raging Onslaught's proc would cast Rage! again, which resets its charges and costs the
--    player one, and Master of Kunai's Kunai stacks would never be used up. They come in a later file, once a build
--    with this part of patch 55 is installed. The Adrenaline Rush cooldown cut is all in the script (no data).
-- 3. Toss and Throw: all in the script (no data). Its buff's own proc keeps no trigger on purpose (see the script).
-- 4. Arcane Gunslinger 274586: while its buff 274590 is up, the core grants 300028 (Arcane Barrage hits one more
--    enemy; aura link, recipe R7). Gaining Missile Barrage (any of its six 15-sec buffs) ends the buff, as the
--    tooltip says (cast links with a negative id remove an aura).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('aura_link', 274586);
DELETE FROM `spell_script_names` WHERE `ScriptName` IN ('spell_wcme_raging_onslaught', 'spell_wcme_kunai_consume');
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(275920, 'spell_wcme_raging_onslaught'),
(26679, 'spell_wcme_kunai_consume'),
(26803, 'spell_wcme_kunai_consume'),
(26804, 'spell_wcme_kunai_consume'),
(26805, 'spell_wcme_kunai_consume'),
(48673, 'spell_wcme_kunai_consume'),
(48674, 'spell_wcme_kunai_consume'),
(1126679, 'spell_wcme_kunai_consume'),
(1148673, 'spell_wcme_kunai_consume'),
(1148674, 'spell_wcme_kunai_consume');
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (274586);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(274586, '274590', 300028, 'WCME: Arcane Gunslinger: Arcane Barrage hits one more enemy while the buff is up');
DELETE FROM `spell_linked_spell` WHERE `spell_effect` = -274590 AND `comment` LIKE 'WCME:%';
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(44401, -274590, 0, 'WCME: Arcane Gunslinger: gaining Missile Barrage ends the buff'),
(274595, -274590, 0, 'WCME: Arcane Gunslinger: gaining Missile Barrage ends the buff'),
(983720, -274590, 0, 'WCME: Arcane Gunslinger: gaining Missile Barrage ends the buff'),
(1144401, -274590, 0, 'WCME: Arcane Gunslinger: gaining Missile Barrage ends the buff'),
(1244401, -274590, 0, 'WCME: Arcane Gunslinger: gaining Missile Barrage ends the buff'),
(1573780, -274590, 0, 'WCME: Arcane Gunslinger: gaining Missile Barrage ends the buff');
