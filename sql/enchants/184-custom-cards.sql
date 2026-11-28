-- Mystic Enchant cards we add or switch on for Wildcard (client-patch/custom_cards.py writes this file; the
-- client patch carries the same cards and scrolls). Needs the build with LoadExtraCards in
-- patches/mystic-enchants-wildcard.patch; a server without it ignores wcme_mystic_enchant. Safe to run again:
-- 000-reset empties wcme_mystic_enchant and removes the scroll items listed in wcme_owned first.
INSERT INTO `wcme_mystic_enchant` (`id`, `spell`, `item`, `weight`, `quality`, `required_level`, `realms`, `class_mask`, `comment`) VALUES
(1235411, 1571194, 403833, 100.0, 4, 0, 1, 513, 'Echoing Warcry: sql/enchants/185-custom-card-effects-1.sql'),
(9990001, 275043, 9990001, 100.0, 4, 0, 1, 512, 'Assault and Battery: sql/enchants/185-custom-card-effects-1.sql'),
(9990002, 1576284, 9990002, 100.0, 4, 0, 1, 512, 'Corrupted Maelstrom Weapon: sql/enchants/185-custom-card-effects-1.sql'),
(9990003, 277850, 9990003, 100.0, 4, 0, 1, 512, 'Arcanesworn: patches/55-talent-fixes.ps1, sql/enchants/186-custom-card-effects-2.sql'),
(9990004, 275462, 9990004, 100.0, 4, 0, 1, 512, 'Arcane Divinity: patches/55-talent-fixes.ps1, sql/enchants/186-custom-card-effects-2.sql'),
(9990005, 277880, 9990005, 100.0, 5, 0, 1, 512, 'Arcane Crusade: patches/55-talent-fixes.ps1, sql/enchants/186-custom-card-effects-2.sql');
-- Each new card's scroll: a copy of a Wildcard scroll of the same quality, renamed. INSERT IGNORE leaves an
-- item that already has the number alone (the card then rolls as that item: check the number is free).
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('item_template', 9990001), ('item_dbc', 9990001), ('item_template', 9990002), ('item_dbc', 9990002), ('item_template', 9990003), ('item_dbc', 9990003), ('item_template', 9990004), ('item_dbc', 9990004), ('item_template', 9990005), ('item_dbc', 9990005);
INSERT IGNORE INTO `item_dbc` (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, `Material`, `DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES (9990001, 0, 6, -1, 8, 24653, 0, 0), (9990002, 0, 6, -1, 8, 24653, 0, 0), (9990003, 0, 6, -1, 8, 24653, 0, 0), (9990004, 0, 6, -1, 8, 24653, 0, 0), (9990005, 0, 6, -1, 8, 137561, 0, 0);
DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;
CREATE TEMPORARY TABLE `wcme_card_scroll` AS SELECT * FROM `item_template` WHERE `entry` = 1175751;
UPDATE `wcme_card_scroll` SET `entry` = 9990001, `name` = CONCAT(SUBSTRING_INDEX(`name`, ': ', 1), ': Assault and Battery');
INSERT IGNORE INTO `item_template` SELECT * FROM `wcme_card_scroll`;
DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;
CREATE TEMPORARY TABLE `wcme_card_scroll` AS SELECT * FROM `item_template` WHERE `entry` = 1175751;
UPDATE `wcme_card_scroll` SET `entry` = 9990002, `name` = CONCAT(SUBSTRING_INDEX(`name`, ': ', 1), ': Corrupted Maelstrom Weapon');
INSERT IGNORE INTO `item_template` SELECT * FROM `wcme_card_scroll`;
DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;
CREATE TEMPORARY TABLE `wcme_card_scroll` AS SELECT * FROM `item_template` WHERE `entry` = 1175751;
UPDATE `wcme_card_scroll` SET `entry` = 9990003, `name` = CONCAT(SUBSTRING_INDEX(`name`, ': ', 1), ': Arcanesworn');
INSERT IGNORE INTO `item_template` SELECT * FROM `wcme_card_scroll`;
DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;
CREATE TEMPORARY TABLE `wcme_card_scroll` AS SELECT * FROM `item_template` WHERE `entry` = 1175751;
UPDATE `wcme_card_scroll` SET `entry` = 9990004, `name` = CONCAT(SUBSTRING_INDEX(`name`, ': ', 1), ': Arcane Divinity');
INSERT IGNORE INTO `item_template` SELECT * FROM `wcme_card_scroll`;
DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;
CREATE TEMPORARY TABLE `wcme_card_scroll` AS SELECT * FROM `item_template` WHERE `entry` = 1175930;
UPDATE `wcme_card_scroll` SET `entry` = 9990005, `name` = CONCAT(SUBSTRING_INDEX(`name`, ': ', 1), ': Arcane Crusade');
INSERT IGNORE INTO `item_template` SELECT * FROM `wcme_card_scroll`;
DROP TEMPORARY TABLE IF EXISTS `wcme_card_scroll`;
