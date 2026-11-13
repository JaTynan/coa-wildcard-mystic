-- Battleground healing reduction (13 Nov): Ascension puts "PvP - Battleground - Dampening" (spell 74411) on everyone
-- in a battleground: healing done -20% and absorb shields -20%. CoA's data has the spell but nothing applies it,
-- so bots healed themselves to near full in one cast. These rows put it on every player and bot while they are in
-- a battleground zone, and the server takes it off when they leave. Arenas are not included.
-- Zones: Alterac Valley 2597, Warsong Gulch 3277, Arathi Basin 3358, Eye of the Storm 3820,
-- Strand of the Ancients 4384, Isle of Conquest 4710. Safe to run again.
DELETE FROM `spell_area` WHERE `spell` = 74411 AND `area` IN (2597, 3277, 3358, 3820, 4384, 4710);
INSERT INTO `spell_area` (`spell`, `area`, `quest_start`, `quest_end`, `aura_spell`, `racemask`, `gender`, `autocast`,
                          `quest_start_status`, `quest_end_status`) VALUES
(74411, 2597, 0, 0, 0, 0, 2, 1, 64, 11),
(74411, 3277, 0, 0, 0, 0, 2, 1, 64, 11),
(74411, 3358, 0, 0, 0, 0, 2, 1, 64, 11),
(74411, 3820, 0, 0, 0, 0, 2, 1, 64, 11),
(74411, 4384, 0, 0, 0, 0, 2, 1, 64, 11),
(74411, 4710, 0, 0, 0, 0, 2, 1, 64, 11);
