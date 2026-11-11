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

# ---- Battleground Spoils: 3 for a win, 1 for a loss, opened like an Adventurer's Cache
Write-Host "Patch: Battleground Spoils for battleground wins and losses"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"AscensionSpecialization.h`"`n"
$reward = "bool IsAdventurerReward(uint32 entry)`n{`n    return entry == AdventurerSatchel || entry == AdventurerCache || entry == AdventurerRareCache;`n}`n"
$gear = "bool IsGearCache(uint32 entry)`n{`n    return entry == AdventurerCache || entry == AdventurerRareCache;`n}`n"
$fill = "    loot.FillLoot(item->GetEntry(), LootTemplates_Item, player, true, true);`n"
$register = "    new adventurer_cache_loot();`n}`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $reward, $gear, $fill, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed: AscensionAdventurerCache.cpp no longer has: $($anchor.Split("`n")[0])" }
}
$helpers = @'
// Wildcard: Battleground Spoils (CoA has the items but nothing hands them out or opens them). One kind per level
// bracket, for a win and for a loss; every one opens like the rare Adventurer's Cache: one piece of gear for the
// opener's level and specialization, plus supplies. Battleground.SpoilsEnabled turns it on.
constexpr std::array<uint32, 7> BattlegroundSpoilsWin = { 1175636, 1175637, 1175638, 1175639, 1175640, 1175641, 1175642 };
constexpr std::array<uint32, 7> BattlegroundSpoilsLoss = { 1675636, 1675637, 1675638, 1675639, 1675640, 1675641, 1675642 };

bool BattlegroundSpoilsEnabled()
{
    return sConfigMgr->GetOption<bool>("Battleground.SpoilsEnabled", false);
}

bool IsBattlegroundSpoils(uint32 entry)
{
    return BattlegroundSpoilsEnabled() &&
        (std::find(BattlegroundSpoilsWin.begin(), BattlegroundSpoilsWin.end(), entry) != BattlegroundSpoilsWin.end() ||
         std::find(BattlegroundSpoilsLoss.begin(), BattlegroundSpoilsLoss.end(), entry) != BattlegroundSpoilsLoss.end());
}

// Brackets as the item descriptions give them: 10-19, 20-29, 30-39, 40-49, 50-60, 61-70, 71-80.
uint32 BattlegroundSpoilsFor(uint32 level, bool won)
{
    std::size_t const bracket = level <= 19 ? 0 : level <= 29 ? 1 : level <= 39 ? 2 : level <= 49 ? 3 :
        level <= 60 ? 4 : level <= 70 ? 5 : 6;
    return won ? BattlegroundSpoilsWin[bracket] : BattlegroundSpoilsLoss[bracket];
}

'@
$class = @'
// Wildcard: Battleground Spoils at the end of every battleground (not arenas or wargames), straight into the bags,
// and to the mailbox if they are full. Counts: Battleground.SpoilsForWin, Battleground.SpoilsForLoss.
class battleground_spoils_reward : public AllBattlegroundScript
{
public:
    battleground_spoils_reward() : AllBattlegroundScript("battleground_spoils_reward",
        {ALLBATTLEGROUNDHOOK_ON_BATTLEGROUND_END_REWARD}) { }

    void OnBattlegroundEndReward(Battleground* bg, Player* player, TeamId winner) override
    {
        if (!BattlegroundSpoilsEnabled() || !bg || !player || !player->GetSession() || player->GetSession()->IsBot() ||
            !bg->isBattleground() || bg->IsWargame())
            return;

        bool const won = winner != TEAM_NEUTRAL && player->GetBgTeamId() == winner;
        uint32 const count = sConfigMgr->GetOption<uint32>(won ? "Battleground.SpoilsForWin" : "Battleground.SpoilsForLoss",
            won ? 3 : 1);
        if (!count)
            return;
        uint32 const entry = BattlegroundSpoilsFor(player->GetLevel(), won);
        if (!sObjectMgr->GetItemTemplate(entry))
            return;

        uint32 noSpace = 0;
        ItemPosCountVec dest;
        InventoryResult const result = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, count, &noSpace);
        uint32 const stored = result == EQUIP_ERR_OK ? count : count - std::min(noSpace, count);
        uint32 delivered = 0;
        if (stored && !dest.empty())
            if (Item* item = player->StoreNewItem(dest, entry, true))
            {
                player->SendNewItem(item, stored, true, false);
                delivered = stored;
            }
        if (uint32 const posted = count - delivered)
        {
            player->SendItemRetrievalMail(entry, posted);
            ChatHandler(player->GetSession()).SendSysMessage(
                "Your bags were full, so your Battleground Spoils were sent to your mailbox.");
        }
    }
};

'@
$text = $text.Replace($include, $include + "#include `"AllBattlegroundScript.h`"`n#include `"Battleground.h`"`n#include `"Config.h`"`n")
$text = $text.Replace($reward, $helpers.Replace("`r`n", "`n") + "bool IsAdventurerReward(uint32 entry)`n{`n    return entry == AdventurerSatchel || entry == AdventurerCache || entry == AdventurerRareCache ||`n        IsBattlegroundSpoils(entry);`n}`n")
$text = $text.Replace($gear, "bool IsGearCache(uint32 entry)`n{`n    return entry == AdventurerCache || entry == AdventurerRareCache || IsBattlegroundSpoils(entry);`n}`n")
$text = $text.Replace($fill, "    // Wildcard: Battleground Spoils have no loot table of their own; they draw from the rare Adventurer's Cache.`n    loot.FillLoot(IsBattlegroundSpoils(item->GetEntry()) ? uint32(AdventurerRareCache) : item->GetEntry(),`n        LootTemplates_Item, player, true, true);`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, "    new adventurer_cache_loot();`n    new battleground_spoils_reward();`n}`n")
Set-Content $file $text -NoNewline
}
