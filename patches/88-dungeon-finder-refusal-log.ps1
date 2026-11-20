# The dungeon finder says why it refused a join, in Server.log. It never logged a refusal above Debug, and the client
# only shows padlocks for the player's own character, so a group refused because of one member gave no clue which
# member or why (James, 21 November: Ragefire Chasm with his alts as bots refused, alone it works). Each refused join
# now logs one line: the player, the group size, the result code and the dungeons asked for, then, for every member
# the server holds locked out, their name and lock code per dungeon (the codes are lfg::LfgLockStatusType in LFG.h:
# 1 expansion, 2 too low level, 3 too high level, 4 gear score too low, 5 too high gear score, 6 raid locked, 1001
# attunement too low level, 1002 attunement too high, 1022 quest not done, 1025 missing item, 1031 not in season,
# 1034 missing achievement). Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: dungeon finder refusals are logged with the reason"
$file = 'core/src/server/game/DungeonFinding/LFGMgr.cpp'

$include = "#include `"LFGMgr.h`"`n"
Edit-Core $file $include ($include + "#include `"ObjectAccessor.h`"`n") 'the LFGMgr.h include'

$debug = "            LOG_DEBUG(`"lfg`", `"LFGMgr::Join: [{}] joining with {} members. result: {}`", guid.ToString(), grp ? grp->GetMembersCount() : 1, joinData.result);`n"
Edit-Core $file $debug ($debug + @'
            // Wildcard: say why, member by member (the client only shows the player's own padlocks).
            {
                std::string asked;
                for (uint32 dungeonId : dungeons)
                    asked += Acore::StringFormat(" {}", dungeonId);
                std::string locks;
                for (auto const& [memberGuid, memberLocks] : joinData.lockmap)
                {
                    Player* member = ObjectAccessor::FindConnectedPlayer(memberGuid);
                    locks += Acore::StringFormat(" | {}:", member ? member->GetName() : memberGuid.ToString());
                    for (auto const& [dungeonId, status] : memberLocks)
                        locks += Acore::StringFormat(" {}={}", dungeonId & 0x00FFFFFF, status);
                }
                LOG_INFO("coa", "Dungeon finder refused {} (group of {}): result {}, dungeons{}{}", player->GetName(),
                    grp ? grp->GetMembersCount() : 1, uint32(joinData.result), asked.empty() ? " none" : asked,
                    locks.empty() ? " | no member locks" : locks);
            }
'@) 'the refused-join debug line in LFGMgr::JoinLfg'
