-- Medium legendaries, batch 4 (needs the build with this version of mystic-enchants-scripts.patch, and the client
-- patch for Abyssal Hunger 9990020, Dark Surgeon's Oath 9990021 and Dark Transfusion's charge category 9001).
-- Gift of Light (1277670): stacks on each Light's Grace renewal that let Divine Favor skip its cooldown.
-- Stormbound Instinct (1181360): Shocks give Maelstrom Weapon and Stormbound Reflexes and splash 30% of their damage;
-- Primal Strike, Lightning Bolt and Chain Lightning make the next Shock free of cooldown.
-- Feeding the Abyss (1154364) was dropped in review 2026-11-18: the core already does the whole enchant (its own absorb,
-- store and Life Tap eruption), so ours ran a second absorb roll and a second payoff.
-- Nether Portal (1180440): its portal buff (1180443) summons a demon per Shadow Bolt, Soul Fire or Incinerate, and one
-- more for Soul Fire during Decimation.
-- Dark Surgeon (978209): its own design instead of twin 1573136 (003 no longer links them): Hippocratic Oath, 30% less
-- healing taken (150), Dark Surgeon stacks from Mutilate, Lesser Circle of Healing and Trauma Care from finishing moves
-- (Greater Heal spends Trauma Care). Dark Transfusion (978640): 3 charges every 8 sec, energy and a combo point; its
-- heal (978641) reaches up to 6 allies.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_proc', 1277670),
('spell_proc', 1181360),
('spell_proc', 1180443),
('spell_proc', 978209);
DELETE FROM `wcme_enchant_action` WHERE `enchant_spell` IN (1277670, 1181360, 1154364, 978209);
DELETE FROM `spell_script_names` WHERE `spell_id` IN (1277670, 1181360, 1154364, 1154363, 1180443, 978209, 978640, 978641) AND `ScriptName` LIKE 'spell\_wcme\_%';
DELETE FROM `spell_script_names` WHERE `spell_id` = 1180443 AND `ScriptName` = 'aura_wildcard_nether_portal';
DELETE FROM `spell_proc` WHERE `SpellId` IN (1277670, 1181360, 1180443, 978209);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1277670, 0, 0, 0, 0, 0, 17408, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(1181360, 0, 0, 0, 0, 0, 65592, 0, 3, 0, 0, 0, 0, 100, 0, 0),
(1180443, 0, 0, 0, 0, 0, 65536, 0, 1, 0, 0, 0, 0, 100, 0, 0),
(978209, 0, 0, 0, 0, 0, 16400, 0, 7, 0, 0, 0, 0, 100, 0, 0);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(1277670, 'spell_wcme_gift_of_light'),
(1181360, 'spell_wcme_stormbound_instinct'),
(1180443, 'spell_wcme_nether_portal'),
(978209, 'spell_wcme_dark_surgeon'),
(978640, 'spell_wcme_dark_transfusion'),
(978641, 'spell_wcme_dark_transfusion_heal');
