-- Legendary kits, batch 6, the last (needs the build with this version of mystic-enchants-scripts.patch; no client patch
-- change).
-- Tree of Wrath (86438): its own Tree of Wrath form and Living Lightning in place of Tree of Life and Chain Heal (006 no
-- longer teaches twin spell 1568396), Lightning Rod, instant Lightning Bolt on a 6 sec cooldown in the form (986438),
-- cannot miss, Living Lightning cooldown from critical heals, freedom on shapeshift with the Spirit primary stat.
-- Vampire Lord (997126): Unholy Light, Unholy Prayer and Vampire Lord in place of Holy Light, Prayer of Healing and
-- Vampiric Embrace, Beacon of Shadow taught, Vampire Lord healing (Vampiric Bond +125%), Beacon of Shadow healing.
-- Verdant Convergence (902122): Sunburst, no hand-cast Insect Swarm, Solar Eclipse from Earth Shock, Eclipse durations,
-- Earthpulse Agony, Wrath crit in Solar Eclipse, Druidic Overload with Nature's Grace, Dawn.
-- Warden of Demonreach (997113): no Hot Streak, Fuego / Arctis alternating in place of Pyroblast, Gathering Will and
-- Winter's Mantle, their 4-stack empowerment and barrage, Duality of Winter and Summer, Starborn.
-- White Walker (978202): Slice and Ice and Winds of Winter, Intellect into crit rating, Winter's Fury / Ice Spear,
-- Ice Lance on critical strikes, Howl of Winter, Frozen Blade.
-- Zandalari Windreaver (902137): Loa's Assault and Zandalari Glaive, Shards of Gonk, Embrace of Bwonsamdi and Kimbul,
-- Single-Minded Fury off-hand throw, Strength of Arms on Zandalari Glaive.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 86438),
('spell_proc', 997126),
('spell_proc', 902122),
('spell_proc', 997113),
('spell_proc', 978202),
('spell_proc', 902137);
DELETE FROM `wcme_enchant_teach` WHERE `enchant_spell` = 86438;
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (86438, 997126, 902122, 997113, 978202, 902137);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (5570, 5571, 24974, 24975, 24976, 24977, 27013, 48468, 86435, 86438, 92770, 92779, 301097, 902122, 902129, 902137, 902140, 902152, 902153, 978202, 978302, 978846, 978847, 978848, 978849, 978850, 978851, 978852, 978853, 997113, 997126, 1105570, 1124974, 1124975, 1124976, 1124977, 1127013, 1148468, 1205570) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_proc` WHERE `SpellId` IN (86438, 997126, 902122, 997113, 978202, 902137);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(86438, 0, 0, 0, 0, 0, 81920, 0, 2, 0, 2, 0, 0, 100, 0, 0),
(997126, 0, 0, 0, 0, 0, 327680, 0, 2, 0, 0, 0, 0, 100, 0, 0),
(902122, 0, 0, 0, 0, 0, 65536, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(997113, 0, 0, 0, 0, 0, 66560, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(978202, 0, 0, 0, 0, 0, 83216, 0, 3, 0, 2, 0, 0, 100, 0, 0),
(902137, 0, 0, 0, 0, 0, 272, 0, 1, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(86438, 'spell_wcme_tree_of_wrath'),
(86435, 'spell_wcme_tree_of_wrath_form'),
(997126, 'spell_wcme_vampire_lord'),
(92779, 'spell_wcme_beacon_of_shadow'),
(92770, 'spell_wcme_unholy_prayer'),
(902122, 'spell_wcme_verdant_convergence'),
(902129, 'spell_wcme_earthpulse_agony'),
(301097, 'spell_wcme_sunburst'),
(5570, 'spell_wcme_no_insect_swarm'),
(5571, 'spell_wcme_no_insect_swarm'),
(24974, 'spell_wcme_no_insect_swarm'),
(24975, 'spell_wcme_no_insect_swarm'),
(24976, 'spell_wcme_no_insect_swarm'),
(24977, 'spell_wcme_no_insect_swarm'),
(27013, 'spell_wcme_no_insect_swarm'),
(48468, 'spell_wcme_no_insect_swarm'),
(1105570, 'spell_wcme_no_insect_swarm'),
(1124974, 'spell_wcme_no_insect_swarm'),
(1124975, 'spell_wcme_no_insect_swarm'),
(1124976, 'spell_wcme_no_insect_swarm'),
(1124977, 'spell_wcme_no_insect_swarm'),
(1127013, 'spell_wcme_no_insect_swarm'),
(1148468, 'spell_wcme_no_insect_swarm'),
(1205570, 'spell_wcme_no_insect_swarm'),
(997113, 'spell_wcme_warden_of_demonreach'),
(978202, 'spell_wcme_white_walker'),
(978302, 'spell_wcme_white_walker_spell'),
(978846, 'spell_wcme_white_walker_spell'),
(978847, 'spell_wcme_white_walker_spell'),
(978848, 'spell_wcme_white_walker_spell'),
(978849, 'spell_wcme_white_walker_spell'),
(978850, 'spell_wcme_white_walker_spell'),
(978851, 'spell_wcme_white_walker_spell'),
(978852, 'spell_wcme_white_walker_spell'),
(978853, 'spell_wcme_white_walker_spell'),
(902137, 'spell_wcme_zandalari_windreaver'),
(902140, 'spell_wcme_loas_assault_offhand'),
(902152, 'spell_wcme_zandalari_glaive'),
(902153, 'spell_wcme_zandalari_glaive');
