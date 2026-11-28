-- Showcase talents, batch 2 (docs/bot-builds/showcase-audit.md): binds patch 55's Blades of Blood script to every
-- Whirlwind a player can use (stock main hand 1680 and off hand 44949, CoA 1101680 and 1101681), not to Bladestorm's
-- Whirlwind ticks (50622 and its copies 1150622, 1250622). The script raises the target limit while the Blades of Blood
-- buff is up and, from the main-hand spells only, puts your Rend on each enemy hit. Swirling Maelstrom needs no data.
-- Needs the build with patch 55's "Showcase talents, batch 2"; before that the server logs a missing script for
-- these rows and carries on, so nothing changes in play. Safe to run again: 000-reset removes spell_wcme_ bindings.
-- Not tested in game: unverified until a player report or an automated test.
DELETE FROM `spell_script_names` WHERE `ScriptName` = 'spell_wcme_blades_of_blood_whirlwind';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1680, 'spell_wcme_blades_of_blood_whirlwind'),
(44949, 'spell_wcme_blades_of_blood_whirlwind'),
(1101680, 'spell_wcme_blades_of_blood_whirlwind'),
(1101681, 'spell_wcme_blades_of_blood_whirlwind');
