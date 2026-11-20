# A Manastorm Treasure Keeper pays out when it dies, not when the run ends. It drops nothing from its body by design:
# its two bonus caches (and, for Wildcard characters, its Ascension Case) were added to the run and arrived in the
# completion mail, lost if the run didn't finish, which felt like the Keeper gave nothing (James, 20 November). Now
# every run member in the storm gets them straight into their bags the moment it dies (by mail if the bags are full),
# with a chat line, and the completion mail no longer adds them. Each member's cache is chosen as the completion
# would have (their level, or the depth in endgame); the bonus never counted toward the weekly cache limit, and still
# doesn't. Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Manastorm Treasure Keeper rewards on the kill"
$src = 'core/modules/mod-manastorm-endless/src'

$declare = "    void OnTreasureKeeperKilled(`n        ManastormRun& run) const;`n"
Edit-Core "$src/ManastormRewards.h" $declare ($declare + @'

    // Wildcard: the Treasure Keeper's bonus caches and case go to each run member in the storm when it dies.
    void WcmeTreasureKeeperReward(Creature* keeper, ManastormRun& run) const;
'@) 'ManastormRewards::OnTreasureKeeperKilled in ManastormRewards.h'

$define = "void ManastormRewards::OnTreasureKeeperKilled(`n    ManastormRun& run) const`n{`n"
Edit-Core "$src/ManastormRewards.cpp" $define (@'
void ManastormRewards::WcmeTreasureKeeperReward(Creature* keeper, ManastormRun& run) const
{
    if (!_loaded || !_treasureKeeper.Enabled)
        return;

    run.ClearTreasureKeeperGuid();
    if (!keeper || !keeper->FindMap())
        return;

    for (ObjectGuid::LowType member : run.GetMembers())
    {
        Player* player = ObjectAccessor::FindConnectedPlayer(ObjectGuid::Create<HighGuid::Player>(member));
        if (!player || !player->IsInWorld() || player->GetMap() != keeper->GetMap())
            continue; // only the members in this storm

        std::vector<std::pair<uint32, uint32>> rewards;
        uint32 cache = 0;
        if (_treasureKeeper.BonusCacheCount && ResolveCacheItemEntry(run.IsEndgame(), run.GetDepth(),
                player->GetLevel(), cache, member, uint8(run.GetMode()), run.GetDepth()) && cache)
            rewards.emplace_back(cache, _treasureKeeper.BonusCacheCount);
        if (_treasureKeeper.CaseCount && (_treasureKeeper.AbilityCaseItem || _treasureKeeper.TalentCaseItem) &&
            (GetActiveGameModeMask(member) & GAME_MODE_WILDCARD))
        {
            bool const ability = !_treasureKeeper.TalentCaseItem ||
                (_treasureKeeper.AbilityCaseItem && urand(0, 1) == 0);
            rewards.emplace_back(ability ? _treasureKeeper.AbilityCaseItem : _treasureKeeper.TalentCaseItem,
                _treasureKeeper.CaseCount);
        }

        // Into the bags one by one (caches don't stack); what doesn't fit comes by mail.
        std::vector<Item*> overflow;
        uint32 given = 0;
        for (auto const& [entry, count] : rewards)
            for (uint32 i = 0; i < count; ++i)
            {
                ItemPosCountVec dest;
                if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, 1) == EQUIP_ERR_OK)
                {
                    if (Item* item = player->StoreNewItem(dest, entry, true))
                    {
                        player->SendNewItem(item, 1, true, false);
                        ++given;
                    }
                }
                else if (Item* item = Item::CreateItem(entry, 1, player))
                    overflow.push_back(item);
            }
        if (!overflow.empty())
        {
            CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
            MailDraft draft("Treasure Keeper", "Your bags were full, so the Treasure Keeper's reward came by mail.");
            for (Item* item : overflow)
            {
                item->SaveToDB(trans);
                draft.AddItem(item);
            }
            draft.SendMailTo(trans, MailReceiver(player), MailSender(MAIL_CREATURE, keeper->GetEntry()),
                MAIL_CHECK_MASK_COPIED);
            CharacterDatabase.CommitTransaction(trans);
        }
        if (!rewards.empty())
            ChatHandler(player->GetSession()).SendSysMessage(overflow.empty()
                ? "Treasure Keeper defeated: its treasure is in your bags."
                : "Treasure Keeper defeated: your bags were full, so its treasure is in your mail.");
        LOG_INFO(LOG_FILTER, "Manastorm run {}: Treasure Keeper rewarded character {} ({} to bags, {} by mail).",
            run.GetRunId(), member, given, overflow.size());
    }
}

'@ + $define) 'ManastormRewards::OnTreasureKeeperKilled in ManastormRewards.cpp'

$include = "#include `"ManastormRewards.h`"`n"
Edit-Core "$src/ManastormRewards.cpp" $include ($include + "#include `"Chat.h`"`n") 'the ManastormRewards.h include in ManastormRewards.cpp'

$call = "        ManastormRewards::Instance()`n            .OnTreasureKeeperKilled(`n                *run);`n"
Edit-Core "$src/ManastormMgr.cpp" $call @'
        ManastormRewards::Instance()
            .WcmeTreasureKeeperReward(
                creature,
                *run);

'@ 'the Treasure Keeper kill in ManastormMgr.cpp'
