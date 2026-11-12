# Weekend bonus: more reputation, honour, profession skill-ups, quest money and (optionally) XP on chosen days.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose
# world PvP part this builds on (same file and script loader). Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Anchored([string]$file, [string]$old, [string]$new, [string]$what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    $old = $old.Replace("`r`n", "`n")
    if (([regex]::Matches($text, [regex]::Escape($old))).Count -ne 1) { throw "Core changed: $what was not found in $file" }
    Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n")) -NoNewline
}

# ---- Weekend bonus (WeekendBonus.Enabled, off when unset)
Write-Host "Patch: Weekend bonus (WeekendBonus.Enabled)"

# One shared helper: on the days in WeekendBonus.Days (server time; 0 = Sunday ... 6 = Saturday; default Friday
# to Sunday) it returns the named WeekendBonus.*Rate, otherwise 1. Every rate defaults to 1 (no change).
$header = @'
#ifndef WCME_WEEKEND_BONUS_H
#define WCME_WEEKEND_BONUS_H

#include "Config.h"
#include "Timer.h"
#include <ctime>
#include <string>

// Wildcard weekend bonus (patches/45-weekend-bonus.ps1): the multiplier one WeekendBonus.*Rate setting gives now.
inline bool WeekendBonusToday()
{
    if (!sConfigMgr->GetOption<bool>("WeekendBonus.Enabled", false))
        return false;
    std::tm const now = Acore::Time::TimeBreakdown();
    return sConfigMgr->GetOption<std::string>("WeekendBonus.Days", "5,6,0").find(char('0' + now.tm_wday)) !=
        std::string::npos;
}

inline float WeekendBonusRate(std::string const& setting)
{
    if (!WeekendBonusToday())
        return 1.0f;
    float const rate = sConfigMgr->GetOption<float>(setting, 1.0f);
    return rate > 0.0f ? rate : 1.0f;
}

#endif
'@
Set-Content 'core/src/server/game/Miscellaneous/WeekendBonus.h' $header.Replace("`r`n", "`n") -NoNewline

# Honour: every honour reward (kills and battleground bonuses) passes Rate.Honor here.
Edit-Anchored 'core/src/server/game/Entities/Player/Player.cpp' "#include `"Formulas.h`"`n" "#include `"Formulas.h`"`n#include `"WeekendBonus.h`"`n" 'the Formulas.h include'
Edit-Anchored 'core/src/server/game/Entities/Player/Player.cpp' @'
    honor_f *= sWorld->getRate(RATE_HONOR);
'@ @'
    honor_f *= sWorld->getRate(RATE_HONOR);
    honor_f *= WeekendBonusRate("WeekendBonus.HonorRate");
'@ 'the honour rate in RewardHonor'

# Quest money.
Edit-Anchored 'core/src/server/game/Entities/Player/PlayerQuest.cpp' "#include `"WorldSession.h`"`n" "#include `"WorldSession.h`"`n#include `"WeekendBonus.h`"`n" 'the WorldSession.h include'
Edit-Anchored 'core/src/server/game/Entities/Player/PlayerQuest.cpp' @'
    if (moneyRew)
    {
        ModifyMoney(moneyRew);
'@ @'
    if (moneyRew > 0)
        moneyRew = int32(float(moneyRew) * WeekendBonusRate("WeekendBonus.QuestMoneyRate"));

    if (moneyRew)
    {
        ModifyMoney(moneyRew);
'@ 'the quest money reward'

# XP, reputation and profession skill-ups, plus the login notice, as a PlayerScript beside world PvP XP.
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
$class = @'
class weekend_bonus : public PlayerScript
{
public:
    weekend_bonus() : PlayerScript("weekend_bonus", {PLAYERHOOK_ON_GIVE_EXP, PLAYERHOOK_ON_GIVE_REPUTATION,
        PLAYERHOOK_ON_UPDATE_GATHERING_SKILL, PLAYERHOOK_ON_UPDATE_CRAFTING_SKILL, PLAYERHOOK_ON_LOGIN}) { }

    void OnPlayerGiveXP(Player* /*player*/, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
    {
        if (amount)
            amount = uint32(float(amount) * WeekendBonusRate("WeekendBonus.XPRate"));
    }

    void OnPlayerGiveReputation(Player* /*player*/, int32 /*factionID*/, float& amount, ReputationSource /*repSource*/) override
    {
        if (amount > 0.0f)
            amount *= WeekendBonusRate("WeekendBonus.ReputationRate");
    }

    void OnPlayerUpdateGatheringSkill(Player* /*player*/, uint32 /*skill*/, uint32 /*current*/, uint32 /*gray*/,
        uint32 /*green*/, uint32 /*yellow*/, uint32& gain) override
    {
        gain = Scale(gain);
    }

    void OnPlayerUpdateCraftingSkill(Player* /*player*/, SkillLineAbilityEntry const* /*skill*/, uint32 /*current*/,
        uint32& gain) override
    {
        gain = Scale(gain);
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!WeekendBonusToday() || !player->GetSession() || player->GetSession()->IsBot())
            return;
        std::string boosts;
        auto add = [&boosts](char const* setting, char const* name)
        {
            float const rate = WeekendBonusRate(setting);
            if (rate != 1.0f)
                boosts += Acore::StringFormat("{}{}x {}", boosts.empty() ? "" : ", ", rate, name);
        };
        add("WeekendBonus.XPRate", "XP");
        add("WeekendBonus.ReputationRate", "reputation");
        add("WeekendBonus.HonorRate", "honour");
        add("WeekendBonus.ProfessionSkillRate", "profession skill-ups");
        add("WeekendBonus.QuestMoneyRate", "quest gold");
        if (!boosts.empty())
            ChatHandler(player->GetSession()).SendSysMessage("|cff00ff00Weekend bonus is on:|r " + boosts + ".");
    }

private:
    static uint32 Scale(uint32 gain)
    {
        if (!gain)
            return gain;
        float const scaled = float(gain) * WeekendBonusRate("WeekendBonus.ProfessionSkillRate");
        uint32 whole = uint32(scaled);
        if (frand(0.0f, 1.0f) < scaled - float(whole))
            ++whole;
        return whole;
    }
};

'@
$text = $text.Replace($include, $include + "#include `"WeekendBonus.h`"`n#include <string>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new weekend_bonus();`n")
Set-Content $file $text -NoNewline
}
