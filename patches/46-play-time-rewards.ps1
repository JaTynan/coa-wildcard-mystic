# Play-time rewards: every hour of play earns a sealed card pack, sometimes a Case of Fortune.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose
# world PvP part this builds on (same file and script loader). Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Play-time rewards (PlayTimeRewards.Enabled, off when unset)
Write-Host "Patch: Play-time rewards (PlayTimeRewards.Enabled)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# Each time a character's total played time passes another PlayTimeRewards.IntervalMinutes (default 60), it gets
# a sealed card pack (PackPercent; GoldenPackPercent of them golden; talent or ability at random) and, at
# CasePercent, a Case of Fortune. Counting uses the character's own played time, so part of an hour carries over
# between sessions. Nothing is given while the player is flagged AFK at that moment. Bots get nothing.
$class = @'
class play_time_rewards : public PlayerScript
{
public:
    play_time_rewards() : PlayerScript("play_time_rewards",
        {PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_UPDATE}) { }

    void OnPlayerLogin(Player* player) override
    {
        if (uint32 const interval = Interval())
        {
            std::lock_guard<std::mutex> lock(_lock);
            _reached[player->GetGUID()] = player->GetTotalPlayedTime() / interval;
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        std::lock_guard<std::mutex> lock(_lock);
        _reached.erase(player->GetGUID());
    }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        uint32 const interval = Interval();
        if (!interval || !player->GetSession() || player->GetSession()->IsBot())
            return;
        uint32 const now = player->GetTotalPlayedTime() / interval;
        {
            std::lock_guard<std::mutex> lock(_lock);
            auto reached = _reached.find(player->GetGUID());
            if (reached == _reached.end())
            {
                _reached[player->GetGUID()] = now;
                return;
            }
            if (now <= reached->second)
                return;
            reached->second = now;
        }
        if (!player->isAFK())
            Reward(player);
    }

private:
    static uint32 Interval()
    {
        if (!sConfigMgr->GetOption<bool>("PlayTimeRewards.Enabled", false))
            return 0;
        return std::max<uint32>(1, sConfigMgr->GetOption<uint32>("PlayTimeRewards.IntervalMinutes", 60)) * MINUTE;
    }

    static void Give(Player* player, uint32 entry)
    {
        ItemPosCountVec dest;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, 1) == EQUIP_ERR_OK)
            if (Item* item = player->StoreNewItem(dest, entry, true))
            {
                player->SendNewItem(item, 1, true, false);
                return;
            }
        player->SendItemRetrievalMail(entry, 1);
    }

    static void Reward(Player* player)
    {
        bool given = false;
        if (urand(1, 100) <= sConfigMgr->GetOption<uint32>("PlayTimeRewards.PackPercent", 100))
        {
            bool const golden = urand(1, 100) <= sConfigMgr->GetOption<uint32>("PlayTimeRewards.GoldenPackPercent", 25);
            bool const talent = urand(0, 1);
            Give(player, golden ? (talent ? 97870u : 778998u) : (talent ? 97886u : 97885u));
            given = true;
        }
        if (urand(1, 100) <= sConfigMgr->GetOption<uint32>("PlayTimeRewards.CasePercent", 25))
        {
            Give(player, urand(0, 1) ? 1278049u : 1278048u);
            given = true;
        }
        if (given)
            ChatHandler(player->GetSession()).SendSysMessage(
                "|cff00ff00Thanks for playing!|r Your time online earned you a reward (mailed if your bags were full).");
    }

    std::mutex _lock;
    std::map<ObjectGuid, uint32> _reached;
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new play_time_rewards();`n")
Set-Content $file $text -NoNewline
}
