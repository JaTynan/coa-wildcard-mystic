-- Two showcase talents fixed with data (no build). Sources: our spell data (Spell.dbc) and the core's aura-link code.
--
-- Divine Concord 277860 (talent and Epic enchant; Arcane Paladin build). The Art of War should also make Arcane Blast
-- instant and 40% stronger. Ascension built this as a second Art of War buff for Arcane Blast (984293: no cast time,
-- +40% damage, one charge, used up by Arcane Blast), whose use casts a cleanup (984295) that removes the paladin's Art
-- of War; but nothing gave 984293. Now the core's aura link gives it while you have Divine Concord and any version of
-- the paladin's Art of War buff, and removes it when that buff goes (used by Flash of Light or Exorcism, or run out).
-- The cleanup removes only one version of the paladin's buff (853489), so links remove the others when it is cast:
-- whichever spell uses the shared Art of War, both buffs go. (The extra Arcane Blast stack or Harnessed Energy charge
-- needs code: patch 55, showcase batch 6.)
--
-- Master of Kunai 277475 (Ninja build). Its buff (277476) gives Shuriken Toss 2 more targets, and its tooltip says Glaive
-- Toss too, but its modifier is a rogue-family one and Glaive Toss is a hunter-family spell. Ascension's own companion,
-- 277480 (hunter family, Glaive Toss's class flag, triple the jump targets: 1 becomes 3), was applied by nothing. It now
-- comes and goes with the buff. (Its Kunai and Toss and Throw parts on Glaive Toss need code: patch 55, batch 6.)
--
-- Safe to run again: 000-reset removes the owned aura link and every WCME: link. Not tested in game: unverified until a
-- player report or an automated test.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('aura_link', 277860);
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (277860);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(277860, '53489 59578 853489 1153489 1159578 1253489 1259578', 984293, 'WCME: Divine Concord: The Art of War also makes Arcane Blast instant and stronger');

DELETE FROM `spell_linked_spell` WHERE `comment` LIKE 'WCME: Divine Concord%' OR `comment` LIKE 'WCME: Master of Kunai%';
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(984295, -53489, 0, 'WCME: Divine Concord: Arcane Blast used the shared Art of War'),
(984295, -59578, 0, 'WCME: Divine Concord: Arcane Blast used the shared Art of War'),
(984295, -1153489, 0, 'WCME: Divine Concord: Arcane Blast used the shared Art of War'),
(984295, -1159578, 0, 'WCME: Divine Concord: Arcane Blast used the shared Art of War'),
(984295, -1253489, 0, 'WCME: Divine Concord: Arcane Blast used the shared Art of War'),
(984295, -1259578, 0, 'WCME: Divine Concord: Arcane Blast used the shared Art of War'),
(277476, 277480, 2, 'WCME: Master of Kunai: Glaive Toss also hits 2 more targets');
