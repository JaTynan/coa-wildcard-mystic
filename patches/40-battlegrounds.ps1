# Battlegrounds: spirit guides.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Battleground spirit guides raise every ghost beside them at each wave
Write-Host "Patch: Battleground spirit guides raise every ghost beside them at each wave"
& {
$file = 'core/src/server/game/Battlegrounds/Battleground.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$wave = "    if (m_LastResurrectTime >= RESURRECTION_INTERVAL)`n    {`n"
$loop = "                for (ObjectGuid const& guid : itr->second)`n"
if (-not $text.Contains($wave)) { throw 'Core changed: the resurrection wave in Battleground::_ProcessResurrect was not found' }
if (-not $text.Contains($loop)) { throw 'Core changed: the revive queue loop in Battleground::_ProcessResurrect was not found' }
$sweep = @'
        // Wildcard: a ghost standing at its own team's spirit guide is raised at the wave even if it dropped out of
        // the queue (players reported needing a second wave, or talking to the guide, in Warsong Gulch).
        for (auto const& [ghostGuid, ghostEntry] : GetPlayers())
        {
            Player* ghost = ObjectAccessor::FindPlayer(ghostGuid);
            if (!ghost || ghost->IsAlive() || !ghost->HasPlayerFlag(PLAYER_FLAGS_GHOST) || !ghost->IsInWorld())
                continue;
            bool queued = false;
            for (auto const& [queuedGuide, queuedGhosts] : m_ReviveQueue)
                if (std::find(queuedGhosts.begin(), queuedGhosts.end(), ghostGuid) != queuedGhosts.end())
                    queued = true;
            if (queued)
                continue;
            uint32 const ownGuide = ghost->GetBgTeamId() == TEAM_ALLIANCE ? BG_CREATURE_ENTRY_A_SPIRITGUIDE : BG_CREATURE_ENTRY_H_SPIRITGUIDE;
            for (ObjectGuid const& creatureGuid : BgCreatures)
            {
                Creature* guide = ghost->GetMap()->GetCreature(creatureGuid);
                if (guide && guide->IsSpiritGuide() && guide->GetEntry() == ownGuide && ghost->IsWithinDistInMap(guide, 30.0f))
                {
                    m_ReviveQueue[guide->GetGUID()].push_back(ghostGuid);
                    break;
                }
            }
        }
'@
$text = $text.Replace($wave, $wave + $sweep.Replace("`r`n", "`n").TrimEnd() + "`n")
# Walk a copy: removing a ghost from the queue mid-wave must not skip the next one.
$text = $text.Replace($loop, "                GuidVector const waveGhosts = itr->second;`n                for (ObjectGuid const& guid : waveGhosts)`n")
Set-Content $file $text -NoNewline
}
