-- The Wondrous Wisdomball (item 101169, the pet that offers your dungeon quests) is sold again by Tiraxis for
-- 800 Bazaar Tokens, in its old place on the Convenience Items list (James, 20 November). The core's update
-- rev_20261031_96 took it off every vendor for a Khadgar questline that was never written, which left it
-- unobtainable. Safe to run again.
DELETE FROM `npc_vendor` WHERE `entry` = 900008 AND `item` = 101169;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(900008, 12, 101169, 0, 0, 10337);  -- Wondrous Wisdomball, 800 tokens
