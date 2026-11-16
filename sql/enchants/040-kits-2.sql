-- Legendary kits, batch 2 (needs the build with this version of mystic-enchants-scripts.patch; no client patch change).
-- Darkmaster (983180): Harvested Essence from Shadow Bolt and Haunt, Afflicted and Ruptured Soul from an empowered
-- Drain Soul, Drain Life crits and heals your charmed minion, Necromancer's Touch from its abilities (983181 keeps only
-- the creature or the player value), Drain Soul at 3 times below 25% health.
-- Defias Gunslinger (997047): Grape Shot and Pistol Shot in place of Multi-Shot and Sinister Strike (single one-handed
-- weapon needed: 300191 and 997048), Gunslinger's Strike, Pirate's Flurry, Defias Tactics.
-- Disciple of Arugal (982980): Shadow Missiles in place of Arcane Missiles, Tainted, Arugal's Fury, Lessons in Shadow,
-- Missile Barrage from Shadow Bolt, and Curse of Agony haste (its ranks below).
-- Disciple of the Tides (978234): its own design instead of twin 274918 (004 no longer overrides or links it): Blessed
-- Waves in place of Chain Heal, Tidal Swell charges, Tidal Shield (978690) in place of Lesser Healing Wave while they
-- last (978698), its absorb shield, and Blessed Waves cooldown from single-target critical heals.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 983180),
('spell_proc', 997047),
('spell_proc', 982980),
('spell_proc', 978234);
DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 978234 AND `spell_effect` = 274918;
DELETE FROM `spell_dbc` WHERE `ID` = 978234;
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (983180, 997047, 982980, 978234);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (983180, 983181, 997047, 997048, 300191, 982980, 978234, 978698, 978690,
  980, 981, 1014, 6217, 11711, 11712, 11713, 27218, 47863, 47864, 69404, 71112, 365400, 1100980, 1101014, 1106217, 1111711,
  1111712, 1111713, 1127218, 1147863, 1147864, 1169404, 1171112, 1401480) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (983180, 997047, 982980, 978234);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(983180, 0, 0, 0, 0, 0, 327680, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(997047, 0, 0, 0, 0, 0, 272, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(982980, 0, 0, 0, 0, 0, 327680, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(978234, 0, 0, 0, 0, 0, 16384, 0, 2, 0, 2, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(983180, 'spell_wcme_darkmaster'),
(983181, 'spell_wcme_necromancers_touch'),
(997047, 'spell_wcme_defias_gunslinger'),
(997048, 'spell_wcme_gunslinger_shot'),
(300191, 'spell_wcme_gunslinger_shot'),
(982980, 'spell_wcme_disciple_of_arugal'),
(980, 'spell_wcme_arugal_curse_haste'),
(981, 'spell_wcme_arugal_curse_haste'),
(1014, 'spell_wcme_arugal_curse_haste'),
(6217, 'spell_wcme_arugal_curse_haste'),
(11711, 'spell_wcme_arugal_curse_haste'),
(11712, 'spell_wcme_arugal_curse_haste'),
(11713, 'spell_wcme_arugal_curse_haste'),
(27218, 'spell_wcme_arugal_curse_haste'),
(47863, 'spell_wcme_arugal_curse_haste'),
(47864, 'spell_wcme_arugal_curse_haste'),
(69404, 'spell_wcme_arugal_curse_haste'),
(71112, 'spell_wcme_arugal_curse_haste'),
(365400, 'spell_wcme_arugal_curse_haste'),
(1100980, 'spell_wcme_arugal_curse_haste'),
(1101014, 'spell_wcme_arugal_curse_haste'),
(1106217, 'spell_wcme_arugal_curse_haste'),
(1111711, 'spell_wcme_arugal_curse_haste'),
(1111712, 'spell_wcme_arugal_curse_haste'),
(1111713, 'spell_wcme_arugal_curse_haste'),
(1127218, 'spell_wcme_arugal_curse_haste'),
(1147863, 'spell_wcme_arugal_curse_haste'),
(1147864, 'spell_wcme_arugal_curse_haste'),
(1169404, 'spell_wcme_arugal_curse_haste'),
(1171112, 'spell_wcme_arugal_curse_haste'),
(1401480, 'spell_wcme_arugal_curse_haste'),
(978234, 'spell_wcme_tidal_disciple'),
(978698, 'spell_wcme_tidal_swell'),
(978690, 'spell_wcme_tidal_shield');
