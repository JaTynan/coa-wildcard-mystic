# Weekend bonus: more XP and reputation on chosen days.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose
# world PvP part this builds on (same file and script loader). Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Weekend bonus (WeekendBonus.Enabled, off when unset)
Write-Host "Patch: Weekend bonus XP and reputation (WeekendBonus.Enabled)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n}`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# On the days listed in WeekendBonus.Days (server time; 0 = Sunday ... 6 = Saturday; default Friday to Sunday),
# every XP gain is multiplied by WeekendBonus.XPRate and every reputation gain by WeekendBonus.ReputationRate.
# It stacks with the realm rates and prestige. Players are told at login while it is on.
$class = @'
bool WeekendBonusActive()
{
    if (!sConfigMgr->GetOption<bool>("WeekendBonus.Enabled", false))
        return false;
    std::tm const now = Acore::Time::TimeBreakdown();
    std::string const days = sConfigMgr->GetOption<std::string>("WeekendBonus.Days", "5,6,0");
    return days.find(char('0' + now.tm_wday)) != std::string::npos;
}

class weekend_bonus : public PlayerScript
{
public:
    weekend_bonus() : PlayerScript("weekend_bonus",
        {PLAYERHOOK_ON_GIVE_EXP, PLAYERHOOK_ON_GIVE_REPUTATION, PLAYERHOOK_ON_LOGIN}) { }

    void OnPlayerGiveXP(Player* /*player*/, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
    {
        if (!amount || !WeekendBonusActive())
            return;
        float const rate = sConfigMgr->GetOption<float>("WeekendBonus.XPRate", 2.0f);
        if (rate > 0.0f)
            amount = uint32(float(amount) * rate);
    }

    void OnPlayerGiveReputation(Player* /*player*/, int32 /*factionID*/, float& amount, ReputationSource /*repSource*/) override
    {
        if (amount <= 0.0f || !WeekendBonusActive())
            return;
        float const rate = sConfigMgr->GetOption<float>("WeekendBonus.ReputationRate", 2.0f);
        if (rate > 0.0f)
            amount *= rate;
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!WeekendBonusActive() || !player->GetSession() || player->GetSession()->IsBot())
            return;
        ChatHandler(player->GetSession()).PSendSysMessage(
            "|cff00ff00Weekend bonus is on:|r {}x XP and {}x reputation.",
            sConfigMgr->GetOption<float>("WeekendBonus.XPRate", 2.0f),
            sConfigMgr->GetOption<float>("WeekendBonus.ReputationRate", 2.0f));
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Timer.h`"`n#include <ctime>`n#include <string>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, "    new world_pvp_kill_xp();`n    new weekend_bonus();`n}`n")
Set-Content $file $text -NoNewline
}
