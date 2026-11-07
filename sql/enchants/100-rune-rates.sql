-- Not an enchant fix: rides along because patch night applies this folder to the world database at every start.
-- More Runes of Descension from quests and ordinary drops (7 Nov: a fully completed zone gave ~700 here, ~2000 on live).
-- Quest rewards: every quest that rewards runes (fixed or choice reward) gives @quest_rune_percent of its amount.
-- Drops: every loot row that drops runes (creatures, objects, containers, shared loot lists) drops them
-- @drop_rune_percent as often: the chance rises first (up to 100%), then the amount; rows in a loot group (where
-- one item is picked from several) only change the amount, so the other items keep their odds.
-- The original numbers are kept in wcme_rune_original_* the first time, so every start recomputes from them and
-- 100 restores them. Rune pouches and bought runes are not affected. Quests weigh more than drops (7 Nov): rewards
-- levelling and prestiging over grinding one spot.
SET @quest_rune_percent := 250;
SET @drop_rune_percent := 150;
SET @rune := 375250;

CREATE TABLE IF NOT EXISTS `wcme_rune_original_quest` (
    `ID` INT UNSIGNED NOT NULL, `Slot` VARCHAR(32) NOT NULL, `Amount` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ID`, `Slot`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `wcme_rune_original_loot` (
    `Source` VARCHAR(40) NOT NULL, `Entry` INT UNSIGNED NOT NULL, `Reference` INT NOT NULL, `GroupId` TINYINT UNSIGNED NOT NULL,
    `Chance` FLOAT NOT NULL, `MinCount` TINYINT UNSIGNED NOT NULL, `MaxCount` TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (`Source`, `Entry`, `Reference`, `GroupId`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Quests
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardAmount1', `RewardAmount1` FROM `quest_template` WHERE `RewardItem1` = @rune AND `RewardAmount1` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardAmount2', `RewardAmount2` FROM `quest_template` WHERE `RewardItem2` = @rune AND `RewardAmount2` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardAmount3', `RewardAmount3` FROM `quest_template` WHERE `RewardItem3` = @rune AND `RewardAmount3` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardAmount4', `RewardAmount4` FROM `quest_template` WHERE `RewardItem4` = @rune AND `RewardAmount4` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardChoiceItemQuantity1', `RewardChoiceItemQuantity1` FROM `quest_template` WHERE `RewardChoiceItemID1` = @rune AND `RewardChoiceItemQuantity1` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardChoiceItemQuantity2', `RewardChoiceItemQuantity2` FROM `quest_template` WHERE `RewardChoiceItemID2` = @rune AND `RewardChoiceItemQuantity2` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardChoiceItemQuantity3', `RewardChoiceItemQuantity3` FROM `quest_template` WHERE `RewardChoiceItemID3` = @rune AND `RewardChoiceItemQuantity3` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardChoiceItemQuantity4', `RewardChoiceItemQuantity4` FROM `quest_template` WHERE `RewardChoiceItemID4` = @rune AND `RewardChoiceItemQuantity4` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardChoiceItemQuantity5', `RewardChoiceItemQuantity5` FROM `quest_template` WHERE `RewardChoiceItemID5` = @rune AND `RewardChoiceItemQuantity5` > 0;
INSERT IGNORE INTO `wcme_rune_original_quest` (`ID`, `Slot`, `Amount`) SELECT `ID`, 'RewardChoiceItemQuantity6', `RewardChoiceItemQuantity6` FROM `quest_template` WHERE `RewardChoiceItemID6` = @rune AND `RewardChoiceItemQuantity6` > 0;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardAmount1' SET q.`RewardAmount1` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardItem1` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardAmount2' SET q.`RewardAmount2` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardItem2` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardAmount3' SET q.`RewardAmount3` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardItem3` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardAmount4' SET q.`RewardAmount4` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardItem4` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardChoiceItemQuantity1' SET q.`RewardChoiceItemQuantity1` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardChoiceItemID1` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardChoiceItemQuantity2' SET q.`RewardChoiceItemQuantity2` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardChoiceItemID2` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardChoiceItemQuantity3' SET q.`RewardChoiceItemQuantity3` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardChoiceItemID3` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardChoiceItemQuantity4' SET q.`RewardChoiceItemQuantity4` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardChoiceItemID4` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardChoiceItemQuantity5' SET q.`RewardChoiceItemQuantity5` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardChoiceItemID5` = @rune;
UPDATE `quest_template` q JOIN `wcme_rune_original_quest` o ON o.`ID` = q.`ID` AND o.`Slot` = 'RewardChoiceItemQuantity6' SET q.`RewardChoiceItemQuantity6` = LEAST(65535, GREATEST(1, ROUND(o.`Amount` * @quest_rune_percent / 100))) WHERE q.`RewardChoiceItemID6` = @rune;

-- Drops
INSERT IGNORE INTO `wcme_rune_original_loot` SELECT 'creature_loot_template', `Entry`, `Reference`, `GroupId`, `Chance`, `MinCount`, `MaxCount` FROM `creature_loot_template` WHERE `Item` = @rune AND `Reference` = 0;
UPDATE `creature_loot_template` l JOIN `wcme_rune_original_loot` o ON o.`Source` = 'creature_loot_template' AND o.`Entry` = l.`Entry` AND o.`Reference` = l.`Reference` AND o.`GroupId` = l.`GroupId`
    SET l.`Chance` = CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN o.`Chance` ELSE LEAST(100, o.`Chance` * @drop_rune_percent / 100) END,
        l.`MinCount` = LEAST(255, GREATEST(1, ROUND(o.`MinCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END)))),
        l.`MaxCount` = LEAST(255, GREATEST(1, ROUND(o.`MaxCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END))))
    WHERE l.`Item` = @rune AND l.`Reference` = 0;
INSERT IGNORE INTO `wcme_rune_original_loot` SELECT 'gameobject_loot_template', `Entry`, `Reference`, `GroupId`, `Chance`, `MinCount`, `MaxCount` FROM `gameobject_loot_template` WHERE `Item` = @rune AND `Reference` = 0;
UPDATE `gameobject_loot_template` l JOIN `wcme_rune_original_loot` o ON o.`Source` = 'gameobject_loot_template' AND o.`Entry` = l.`Entry` AND o.`Reference` = l.`Reference` AND o.`GroupId` = l.`GroupId`
    SET l.`Chance` = CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN o.`Chance` ELSE LEAST(100, o.`Chance` * @drop_rune_percent / 100) END,
        l.`MinCount` = LEAST(255, GREATEST(1, ROUND(o.`MinCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END)))),
        l.`MaxCount` = LEAST(255, GREATEST(1, ROUND(o.`MaxCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END))))
    WHERE l.`Item` = @rune AND l.`Reference` = 0;
INSERT IGNORE INTO `wcme_rune_original_loot` SELECT 'item_loot_template', `Entry`, `Reference`, `GroupId`, `Chance`, `MinCount`, `MaxCount` FROM `item_loot_template` WHERE `Item` = @rune AND `Reference` = 0;
UPDATE `item_loot_template` l JOIN `wcme_rune_original_loot` o ON o.`Source` = 'item_loot_template' AND o.`Entry` = l.`Entry` AND o.`Reference` = l.`Reference` AND o.`GroupId` = l.`GroupId`
    SET l.`Chance` = CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN o.`Chance` ELSE LEAST(100, o.`Chance` * @drop_rune_percent / 100) END,
        l.`MinCount` = LEAST(255, GREATEST(1, ROUND(o.`MinCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END)))),
        l.`MaxCount` = LEAST(255, GREATEST(1, ROUND(o.`MaxCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END))))
    WHERE l.`Item` = @rune AND l.`Reference` = 0;
INSERT IGNORE INTO `wcme_rune_original_loot` SELECT 'reference_loot_template', `Entry`, `Reference`, `GroupId`, `Chance`, `MinCount`, `MaxCount` FROM `reference_loot_template` WHERE `Item` = @rune AND `Reference` = 0;
UPDATE `reference_loot_template` l JOIN `wcme_rune_original_loot` o ON o.`Source` = 'reference_loot_template' AND o.`Entry` = l.`Entry` AND o.`Reference` = l.`Reference` AND o.`GroupId` = l.`GroupId`
    SET l.`Chance` = CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN o.`Chance` ELSE LEAST(100, o.`Chance` * @drop_rune_percent / 100) END,
        l.`MinCount` = LEAST(255, GREATEST(1, ROUND(o.`MinCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END)))),
        l.`MaxCount` = LEAST(255, GREATEST(1, ROUND(o.`MaxCount` * (CASE WHEN o.`GroupId` > 0 OR o.`Chance` <= 0 THEN @drop_rune_percent / 100 ELSE GREATEST(1, o.`Chance` * @drop_rune_percent / 100 / 100) END))))
    WHERE l.`Item` = @rune AND l.`Reference` = 0;
