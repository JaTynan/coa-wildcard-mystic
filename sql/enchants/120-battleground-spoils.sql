-- Battleground Spoils (11 Nov): CoA has the items (one per level bracket, for a win and for a loss) but nothing
-- opens them. Mark them openable and give them the Adventurer's Cache script, as CoA's own update does for the
-- Adventurer's Satchel and rare Cache. Our patch (40-battlegrounds.ps1) then hands them out at the end of each
-- battleground and fills them from the rare Adventurer's Cache. Safe to run again.
UPDATE `item_template` SET `Flags` = `Flags` | 4, `ScriptName` = 'item_ascension_adventurer_cache'
WHERE `entry` IN (1175636, 1175637, 1175638, 1175639, 1175640, 1175641, 1175642,
                  1675636, 1675637, 1675638, 1675639, 1675640, 1675641, 1675642);
