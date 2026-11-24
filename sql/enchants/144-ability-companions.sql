-- Talent companions, batch 4 (code), part 1: passives held by an ability, and one more conditional bonus.
-- Needs the build with patch 55's ability companions (wcme_spell_companion, created in 000-reset.sql); an older build
-- ignores the table. Each pair read by hand on 24 Nov 2026. Not tested in game: James's testing policy, so these
-- stay unverified until a player report or an automated test.
--
-- 1. Ability companions (patch 55): while a player knows the ability, they have the passive.
--   Thrust (every rank, 274269 and 274304-274314): ignores 20% of the target's armour (274337, a modifier on Thrust
--     only: its target is named in SpellAffect.dbc as Thrust's whole rank chain). Thrust is an active ability with no
--     aura, so a link cannot carry it, and this core has no learn-spell table.
--   Two-Handed Weapon Mastery: 25% more rage from damage dealt (829623). The passive needs a two-handed axe, mace,
--     polearm or sword; flag 1 adds "no weapon in the off hand", as the tooltip excludes Titan's Grip. A plain link
--     would lose the passive at the first weapon swap: the core takes item-dependent auras off with the weapon and
--     puts back only learnt spells, not linked ones. The patch puts it back when the gear fits again.
--
-- 2. Careful Aim (3 ranks, a conditional link like 143-talent-companions-conditional.sql): hit chance +1 / 2 / 3% and
--   ranged attack power from 20 / 40 / 60% of Intellect (834482-834484). The tooltip requires Primary Stat: Agility
--   (300036); the Wildcard stat path for it is Path of Agility (84865), so either aura counts. Its hit chance uses
--   aura 333, which this core implements (StatSystem.cpp). Data only: works without the build.
INSERT INTO `wcme_spell_companion` (`ability_spell`, `passive_spell`, `flags`, `comment`) VALUES
(274269, 274337, 0, 'Thrust rank 1: ignores 20% of the target''s armour'),
(274304, 274337, 0, 'Thrust rank 2: ignores 20% of the target''s armour'),
(274305, 274337, 0, 'Thrust rank 3: ignores 20% of the target''s armour'),
(274306, 274337, 0, 'Thrust rank 4: ignores 20% of the target''s armour'),
(274307, 274337, 0, 'Thrust rank 5: ignores 20% of the target''s armour'),
(274308, 274337, 0, 'Thrust rank 6: ignores 20% of the target''s armour'),
(274309, 274337, 0, 'Thrust rank 7: ignores 20% of the target''s armour'),
(274310, 274337, 0, 'Thrust rank 8: ignores 20% of the target''s armour'),
(274311, 274337, 0, 'Thrust rank 9: ignores 20% of the target''s armour'),
(274312, 274337, 0, 'Thrust rank 10: ignores 20% of the target''s armour'),
(274313, 274337, 0, 'Thrust rank 11: ignores 20% of the target''s armour'),
(274314, 274337, 0, 'Thrust rank 12: ignores 20% of the target''s armour'),
(29623, 829623, 1, 'Two-Handed Weapon Mastery: 25% more rage from damage dealt, with a single two-handed weapon');

INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('aura_link', 34482), ('aura_link', 34483), ('aura_link', 34484);
DELETE FROM `coa_mystic_enchant_aura_link` WHERE `enchant_spell` IN (34482, 34483, 34484);
INSERT INTO `coa_mystic_enchant_aura_link` (`enchant_spell`, `aura`, `grant_spell`, `comment`) VALUES
(34482, '84865 300036', 834482, 'WCME: Careful Aim rank 1: hit and ranged attack power from Intellect on the Agility path'),
(34483, '84865 300036', 834483, 'WCME: Careful Aim rank 2: hit and ranged attack power from Intellect on the Agility path'),
(34484, '84865 300036', 834484, 'WCME: Careful Aim rank 3: hit and ranged attack power from Intellect on the Agility path');
