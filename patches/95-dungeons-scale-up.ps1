# Dungeons scale up as well as down, and walking in scales too (James, 21 November: Zor at 47 in Shadowfang Keep met
# level 14 mobs; he wants to run any dungeon at his level, for experience and low-level crafting materials).
# 1. CoA's rule kept a classic dungeon's authored levels from its finder target level up and only shifted creatures
#    down for a character below it. Now a character at or above the target meets every creature at their own level,
#    up to 60 (never lower than the creature already is: a boss authored above the character keeps its level).
#    Below the target, the old rule stands: every creature shifts down by the same amount.
# 2. Finder entries with no real target level (Wailing Caverns, Gnomeregan, Uldaman and the old Scholomance entry say
#    100) counted as level 60, so a level 30 walking in would have met them shifted 30 levels down. They now count
#    from the bottom of their band (15), so the rule above lifts them instead.
# 3. Only a Dungeon Finder group inside its assigned dungeon was scaled; walking in kept the authored levels. Now a
#    character whose Destiny Weaver scaling is on (the default) is scaled when they walk in too, and their loot with
#    them, as in a finder group. A character who turns scaling off at the Destiny Weaver meets authored levels, and a
#    challenge rule still holds a character to them. Heroic and Mythic are unchanged (they never scale).
# Experience follows the level each character sees, so it needs nothing here. Run by the build from the workspace
# root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: dungeons scale up to the character's level, walking in included"

Edit-Core 'core/src/server/game/Miscellaneous/LocalLevelScaling.h' @'
    int const viewerLevel = std::clamp(playerLevel, band.Low, std::max(band.High, referenceLevel));
    int const shift = std::min(0, viewerLevel - int(referenceLevel));
    return static_cast<std::uint8_t>(std::clamp(int(creatureLevel) + shift, 1, 255));
'@ @'
    // Wildcard: at or above the dungeon's level, every creature stands at the character's level (up to 60, never
    // below the creature's own); below it, every creature shifts down by the same amount, as CoA had it.
    std::uint8_t const top = std::max<std::uint8_t>({ band.High, referenceLevel, std::uint8_t(60) });
    int const viewerLevel = std::clamp(playerLevel, band.Low, top);
    if (viewerLevel >= int(referenceLevel))
        return std::max<std::uint8_t>(creatureLevel, static_cast<std::uint8_t>(viewerLevel));
    int const shift = viewerLevel - int(referenceLevel);
    return static_cast<std::uint8_t>(std::clamp(int(creatureLevel) + shift, 1, 255));
'@ 'the dungeon creature level rule'

$weaver = 'core/modules/mod-destiny-weaver/src/destiny_weaver_scaling.cpp'
Edit-Core $weaver @'
                uint8 const reference = dungeon->TargetLevel >= 1 && dungeon->TargetLevel <= 60
                    ? static_cast<uint8>(dungeon->TargetLevel) : 60;
'@ @'
                uint8 const reference = dungeon->TargetLevel >= 1 && dungeon->TargetLevel <= 60
                    ? static_cast<uint8>(dungeon->TargetLevel) : band.Low;   // Wildcard: was 60
'@ 'the dungeon reference level'

Edit-Core $weaver @'
        Group const* group = const_cast<Player*>(player)->GetGroup();
        return group && group->isLFGGroup() &&
               sLFGMgr->inLfgDungeonMap(group->GetGUID(), map->GetId(), map->GetDifficulty());
'@ @'
        Group const* group = const_cast<Player*>(player)->GetGroup();
        if (group && group->isLFGGroup() &&
            sLFGMgr->inLfgDungeonMap(group->GetGUID(), map->GetId(), map->GetDifficulty()))
            return true;
        // Wildcard: walking in scales too, for a character whose Destiny Weaver scaling is on.
        return LocalLevelScaling::ScalingChoiceEnabled(player) &&
               !(LocalLevelScaling::ScalingBlocksFor(player) & LocalLevelScaling::ChallengeBlocksCreatureScaling);
'@ 'the finder-only dungeon scaling check'
