-- Not an enchant fix: rides along because patch night applies this folder to the world database at every start.
-- Runes of Descension at about live-server rates (7 Nov: a fully completed zone gave ~700 here, ~2000 on live).
-- The core's test-zone bonus multiplies runes from loot and quest rewards in a listed zone; every zone with
-- creatures, objects or quests is listed at 300% runes with normal experience and Bazaar Tokens, never expiring.
-- Zones added by hand with .testzone are kept. Change @rune_percent to retune (100 = normal).
-- The every-15-minutes "[Test Zones]" world announcement is off (CoA.TestZoneBonus.AnnounceIntervalMinutes = 0).
SET @rune_percent := 300;

CREATE TABLE IF NOT EXISTS `coa_test_zone_bonus` (
    `zone_id` INT UNSIGNED NOT NULL,
    `experience_percent` INT UNSIGNED NOT NULL DEFAULT 200,
    `rune_percent` INT UNSIGNED NOT NULL DEFAULT 200,
    `bazaar_token_percent` INT UNSIGNED NOT NULL DEFAULT 200,
    `expires_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ours are the never-expiring rows with normal experience and tokens; refresh them.
DELETE FROM `coa_test_zone_bonus` WHERE `expires_at` = 0 AND `experience_percent` = 100 AND `bazaar_token_percent` = 100;

INSERT IGNORE INTO `coa_test_zone_bonus` (`zone_id`, `experience_percent`, `rune_percent`, `bazaar_token_percent`, `expires_at`)
SELECT `zone`, 100, @rune_percent, 100, 0 FROM (
    SELECT `zoneId` AS `zone` FROM `creature` WHERE `zoneId` > 0
    UNION SELECT `zoneId` FROM `gameobject` WHERE `zoneId` > 0
    UNION SELECT `QuestSortID` FROM `quest_template` WHERE `QuestSortID` > 0
) AS `zones`;
