# Dungeon and raid bosses drop more Unidentified Mystic Scrolls during a weekly event that sets
# WeekendBonus.<theme>.MysticScrollRate (Pull-a-palooza: 3; James, 21 November: enchants were slow to find, and the
# dungeon week should help). A boss always drops one scroll per 10 levels (at least one); inside a dungeon or raid
# that count is multiplied by the rate, a fraction rounding up by chance like the other event rates (2.5 = 2 or 3).
# World bosses outside instances, other enemies' 4% chance, Worldforged drops and Manastorm (no creature loot) are
# unchanged. Run by the build from the workspace root, after 45-weekend-bonus.ps1 (WeekendBonus.h). Throws if an
# anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: weekly event Mystic Scroll rate for dungeon and raid bosses"
if (-not (Test-Path 'core/src/server/game/Miscellaneous/WeekendBonus.h')) { throw '45-weekend-bonus.ps1 did not run: no WeekendBonus.h' }

$file = 'core/src/server/coa/AscensionMysticEnchant.cpp'
$include = "#include `"LootMgr.h`"`n"
Edit-Core $file $include ($include + "#include `"WeekendBonus.h`"`n") 'the LootMgr.h include'

$boss = "        if (creature->IsDungeonBoss() || creatureTemplate->rank == CREATURE_ELITE_WORLDBOSS)`n            count = std::max<uint32>(1, level / 10);`n"
Edit-Core $file $boss (@'
        if (creature->IsDungeonBoss() || creatureTemplate->rank == CREATURE_ELITE_WORLDBOSS)
        {
            count = std::max<uint32>(1, level / 10);
            // Wildcard: the weekly event's Mystic Scroll rate, for bosses inside a dungeon or raid (patch 91).
            if (creature->GetMap() && creature->GetMap()->IsDungeon())
            {
                float const scaled = float(count) * WeekendBonusRate("MysticScrollRate");
                count = uint32(scaled);
                if (roll_chance_f((scaled - float(count)) * 100.0f))
                    ++count;
                count = std::max<uint32>(1, count);
            }
        }
'@) 'the boss scroll count in AscensionMysticEnchantScrollDrops'
