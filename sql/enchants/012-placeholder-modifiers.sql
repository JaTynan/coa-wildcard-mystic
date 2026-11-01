-- Batch 12: broken enchants whose tooltip is a plain modifier ("Reduces the cooldown of X by N sec") but whose
-- spell holds only a placeholder in that place. The spell is copied into spell_dbc with the modifier put where the
-- placeholder was; its other effects, name and tooltip stay as they are, so the game client shows the right text.
-- Where the target shares its spell flag with many others, the spell names its targets in wcme_spellaffect_dbc
-- instead (those need the build with patch mystic-enchants-spellaffect-sql).
-- A row is only added (and owned) where spell_dbc has no row for that spell already.
CREATE TEMPORARY TABLE `wcme_new_spell` (`id` INT NOT NULL PRIMARY KEY);
INSERT INTO `wcme_new_spell` VALUES (118607);
DELETE FROM `wcme_new_spell` WHERE `id` IN (SELECT `ID` FROM `spell_dbc`);
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', `id` FROM `wcme_new_spell`;
DROP TEMPORARY TABLE `wcme_new_spell`;
INSERT IGNORE INTO `spell_dbc` VALUES
(118607, 0, 0, 0, 2147484112, 0, 0, 67108864, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 101, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0, 1, 0.0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 1, 1, 1, 0.0, 0.0, 0.0, 19, 24, 24, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 107, 108, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2639, 0, 0, 'Glyph of Obliterate', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712188, 'Increases the damage of your Obliterate ability by $m3%.', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712188, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);
INSERT INTO `wcme_spellaffect_dbc` (`ID`, `ModifierSpellID`, `AffectedSpellID`) VALUES
(950000, 118607, 49020),
(950001, 118607, 49153),
(950002, 118607, 49154),
(950003, 118607, 49155),
(950004, 118607, 49156),
(950005, 118607, 51423),
(950006, 118607, 51424),
(950007, 118607, 51425),
(950008, 118607, 254645),
(950009, 118607, 354171),
(950010, 118607, 1149020),
(950011, 118607, 1151423),
(950012, 118607, 1151424),
(950013, 118607, 1151425),
(950014, 118607, 1166198),
(950015, 118607, 1166972),
(950016, 118607, 1166973),
(950017, 118607, 1166974);
