-- Fixes found while testing (2 Nov).
-- Divine Steed (991022, 852442): the spell they teach (991021, 291021) was a placeholder; it now mounts you
-- and raises your speed, with the effects of its own buff spell (991020, 291020).
-- Each row is owned only if spell_dbc has no row for that spell already.
CREATE TEMPORARY TABLE `wcme_new_spell` (`id` INT NOT NULL PRIMARY KEY);
INSERT INTO `wcme_new_spell` VALUES (991021), (291021);
DELETE FROM `wcme_new_spell` WHERE `id` IN (SELECT `ID` FROM `spell_dbc`);
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', `id` FROM `wcme_new_spell`;
DROP TEMPORARY TABLE `wcme_new_spell`;
INSERT IGNORE INTO `spell_dbc` VALUES
(991021, 0, 0, 0, 1376256, 0, 0, 0, 0, 0, 131072, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 45000, 0, 0, 12288, 0, 0, 101, 0, 0, 40, 40, 27, 0, 0, 0, 0, 0, 1, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 0, 1, 1, 0.0, 0.0, 0.0, 0, 69, -1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 78, 32, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 16510, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3339, 0, 5623, 0, 0, 'Divine Steed', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Leap atop your Charger for $d, increasing movement speed by $991020s2%. Usable while indoors and in combat.', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 10, 0, 268435456, 0, 0, 0, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0),
(291021, 0, 0, 0, 1376256, 0, 0, 0, 0, 0, 131072, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 45000, 0, 0, 12288, 0, 0, 101, 0, 0, 20, 20, 27, 0, 0, 0, 0, 0, 1, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 6, 6, 0, 0, 1, 1, 0.0, 0.0, 0.0, 0, 69, -1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 78, 32, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 16510, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3339, 0, 5623, 0, 0, 'Divine Steed', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Leap atop your Charger for $d, increasing movement speed by $291020s2%. Usable while indoors and in combat.

@ext:Divine Steed is removed upon shapeshifting.:ext@', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 10, 0, 268435456, 0, 0, 0, 1, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0);
-- Arcane Charge (282881): fired as Charge starts, so its damage (around you) missed the target. It now fires when
-- Charge Root lands on the target, which is when you arrive, so the damage hits enemies around you there.
UPDATE `wcme_enchant_action` SET `spells` = '7922 1107922 1357922',
    `comment` = 'Arcane Charge: Charge Root landing casts Arcane Charge (damage and mana around you)' WHERE `enchant_spell` = 282881;
UPDATE `spell_proc` SET `SpellTypeMask` = 7, `SpellPhaseMask` = 2, `AttributesMask` = 2 WHERE `SpellId` = 282881;
-- Arcane Charge, second part: Charge Root lands as Charge starts, not on arrival, so the damage around you still
-- missed a lone target. The damage part of 282883 now hits the Charge target itself, at any range; the mana part
-- around you is unchanged.
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) SELECT 'spell_dbc', 282883 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `spell_dbc` WHERE `ID` = 282883);
INSERT IGNORE INTO `spell_dbc` VALUES
(282883, 0, 0, 0, 65536, 136, 0, 65536, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 8, 0, 0, 0, 101, 0, 80, 1, 0, 0, 0, 0, 0, 0, 0, 13, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, 2, 64, 0, 1, 0, 0, 2.0, 0.0, 0.0, 4, 0, 0, 0, 0, 0, 6, 22, 0, 0, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 282884, 0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5964, 0, 63728, 0, 0, 'Arcane Charge', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 'Arcane Charge impact deals $s1 damage.', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 16712190, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1, 0, 0, 1.0, 1.0, 1.0, 0, 0, 0, 0, 0, 0, 64, 0, 0, 0, 0.166, 0.0, 0.0, 0, 0);
