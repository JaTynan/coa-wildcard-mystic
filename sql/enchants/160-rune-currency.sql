-- Runes of Descension (item 375250) are a currency, so new runes go to the currency tab's slots (where the client's
-- Wildcard window counts them) and patches/82-runes-in-currency-tab.ps1 can move old ones there. The core's update
-- rev_20260916_06 (issue #122) adds the same currency row; this makes sure of it on our databases. The server drops
-- the item's currency bit when the row is missing. Safe to run again.
DELETE FROM `currencytypes_dbc` WHERE `ID` = 364 OR `ItemID` = 375250;
INSERT INTO `currencytypes_dbc` (`ID`, `ItemID`, `CategoryID`, `BitIndex`) VALUES (364, 375250, 41, 35);
UPDATE `item_template` SET `BagFamily` = `BagFamily` | 8192 WHERE `entry` = 375250;
