-- Batch 5: broken enchants whose working twin never fired (a proc aura with no proc settings). spell_proc
-- rows now say when each twin fires, read from the tooltip; the enchant is linked to its twin as before.
INSERT INTO `wcme_owned` (`tbl`, `id`) VALUES
('spell_dbc', 81100),
('spell_dbc', 983065),
('spell_proc', 1584647),
('spell_proc', 1579665),
('spell_proc', 55441),
('spell_proc', 282040),
('spell_proc', 1576793),
('spell_proc', 911162),
('spell_proc', 285100);
DELETE FROM `spell_dbc` WHERE `ID` IN (81100, 983065);
INSERT INTO `spell_dbc` VALUES
(81100, 0, 0, 0, 2147484112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 0, 0.0, 0.0, 0.0, 0, 9, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 262144, 0, 0, 0, 0, 0, 0, 24752, 24991, 0, 'By Fire Be Purged', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 4', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 11, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(983065, 0, 0, 0, 2147484112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, -1, -1, -1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 4, 4, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24684, 6429, 0, 'Hellish Pursuit', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Rank 4', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);
DELETE FROM `spell_proc` WHERE `SpellId` IN (1584647, 1579665, 55441, 282040, 1576793, 911162, 285100);
INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES
(1584647, 0, 9, 262144, 0, 0, 4352, 0, 2, 0, 0, 0, 0, 0, 0, 0),
(1579665, 0, 11, 0, 2147745792, 0, 65536, 1, 2, 0, 0, 0, 0, 0, 20000, 0),
(55441, 0, 11, 536870912, 0, 0, 21504, 0, 7, 0, 0, 0, 0, 0, 0, 0),
(282040, 0, 0, 0, 0, 0, 340, 0, 2, 52, 0, 0, 0, 0, 0, 0),
(1576793, 0, 4, 0, 512, 0, 16, 1, 2, 0, 0, 0, 0, 0, 0, 0),
(911162, 0, 3, 0, 65536, 0, 65536, 1, 2, 0, 0, 0, 0, 0, 8000, 0),
(285100, 0, 5, 64, 0, 0, 65536, 1, 2, 0, 0, 0, 0, 0, 0, 0);
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES
(283449, 1584647, 2, 'WCME: Scattered Burst uses twin 1584647, made to fire when Scatter Shot hits'),
(81100, 1579665, 2, 'WCME: By Fire Be Purged uses twin 1579665, made to fire when Fire Nova deals damage, once every 20 sec'),
(118126, 55441, 2, 'WCME: Glyph of Mana Tide uses twin 55441, made to fire when Mana Tide Totem is cast'),
(81477, 282040, 2, 'WCME: Blind Rage uses twin 282040, made to fire when an attack misses, is dodged or parried'),
(954641, 1584647, 2, 'WCME: Scattered Burst uses twin 1584647, made to fire when Scatter Shot hits'),
(281347, 1579665, 2, 'WCME: By Fire Be Purged uses twin 1579665, made to fire when Fire Nova deals damage, once every 20 sec'),
(983065, 285100, 2, 'WCME: Hellish Pursuit uses twin 285100, made to fire when Hellfire deals damage'),
(276308, 1576793, 2, 'WCME: Violent Combo uses twin 1576793, made to fire when Shield Slam hits'),
(283200, 911162, 2, 'WCME: Scorched Ground uses twin 911162, made to fire when Living Bomb explodes, once every 8 sec');
