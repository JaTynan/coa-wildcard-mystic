# Weekend bonus: a rotating weekend theme (PvP, Professions, Quests, Dungeons) that boosts that kind of play.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose
# Battleground Spoils and world PvP parts this builds on (same file and script loader). Throws if an anchor is gone.
# Listed in CHANGES.md. The website (signup/WildcardStatus.py) works out the theme the same way.
$ErrorActionPreference = 'Stop'

function Edit-Anchored([string]$file, [string]$old, [string]$new, [string]$what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    $old = $old.Replace("`r`n", "`n")
    if (([regex]::Matches($text, [regex]::Escape($old))).Count -ne 1) { throw "Core changed: $what was not found in $file" }
    Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Rotating weekend bonus (WeekendBonus.Enabled)"

# The shared helper. Weeks run Friday to Thursday from WeekendBonus.RotationStart (a Friday, server time); each week
# takes the next theme in WeekendBonus.Rotation, or WeekendBonus.Theme when set. On the days in WeekendBonus.Days
# (0 = Sunday ... 6 = Saturday; default Friday to Sunday) WeekendBonusRate("X") is WeekendBonus.<theme>.X, else 1.
$header = @'
#ifndef WCME_WEEKEND_BONUS_H
#define WCME_WEEKEND_BONUS_H

#include "Config.h"
#include "Define.h"
#include "Timer.h"
#include <cstdio>
#include <ctime>
#include <sstream>
#include <string>
#include <vector>

// Wildcard rotating weekend bonus (patches/45-weekend-bonus.ps1).
inline int64 WeekendBonusDayNumber(int year, int month, int day)
{
    // Days since 1970-01-01 for a calendar date (H. Hinnant's days_from_civil).
    year -= month <= 2;
    int64 const era = (year >= 0 ? year : year - 399) / 400;
    int64 const yoe = year - era * 400;
    int64 const doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
    int64 const doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

inline std::string WeekendBonusTheme()
{
    std::string const forced = sConfigMgr->GetOption<std::string>("WeekendBonus.Theme", "", false);
    if (!forced.empty())
        return forced;
    std::vector<std::string> themes;
    std::stringstream list(sConfigMgr->GetOption<std::string>("WeekendBonus.Rotation", "PvP,Professions,Quests,Dungeons", false));
    for (std::string theme; std::getline(list, theme, ',');)
        if (!theme.empty())
            themes.push_back(theme);
    if (themes.empty())
        return "";
    int year = 2026, month = 11, day = 13;
    std::sscanf(sConfigMgr->GetOption<std::string>("WeekendBonus.RotationStart", "2026-11-13", false).c_str(),
        "%d-%d-%d", &year, &month, &day);
    std::tm const now = Acore::Time::TimeBreakdown();
    int64 const days = WeekendBonusDayNumber(now.tm_year + 1900, now.tm_mon + 1, now.tm_mday) -
        WeekendBonusDayNumber(year, month, day);
    if (days < 0)
        return ""; // the rotation has not started yet
    int64 const week = days / 7;
    int64 const count = int64(themes.size());
    return themes[std::size_t(((week % count) + count) % count)];
}

inline bool WeekendBonusToday()
{
    if (!sConfigMgr->GetOption<bool>("WeekendBonus.Enabled", false))
        return false;
    std::tm const now = Acore::Time::TimeBreakdown();
    return sConfigMgr->GetOption<std::string>("WeekendBonus.Days", "5,6,0", false).find(char('0' + now.tm_wday)) !=
        std::string::npos;
}

inline float WeekendBonusRate(std::string const& name)
{
    if (!WeekendBonusToday())
        return 1.0f;
    std::string const theme = WeekendBonusTheme();
    if (theme.empty())
        return 1.0f;
    float const rate = sConfigMgr->GetOption<float>("WeekendBonus." + theme + "." + name, 1.0f, false);
    return rate > 0.0f ? rate : 1.0f;
}

#endif
'@
Set-Content 'core/src/server/game/Miscellaneous/WeekendBonus.h' $header.Replace("`r`n", "`n") -NoNewline

# Honour (kills and battleground bonuses all pass Rate.Honor here).
Edit-Anchored 'core/src/server/game/Entities/Player/Player.cpp' "#include `"Formulas.h`"`n" "#include `"Formulas.h`"`n#include `"WeekendBonus.h`"`n" 'the Formulas.h include'
Edit-Anchored 'core/src/server/game/Entities/Player/Player.cpp' @'
    honor_f *= sWorld->getRate(RATE_HONOR);
'@ @'
    honor_f *= sWorld->getRate(RATE_HONOR);
    honor_f *= WeekendBonusRate("HonorRate");
'@ 'the honour rate in RewardHonor'

# Quest gold.
Edit-Anchored 'core/src/server/game/Entities/Player/PlayerQuest.cpp' "#include `"WorldSession.h`"`n" "#include `"WorldSession.h`"`n#include `"WeekendBonus.h`"`n" 'the WorldSession.h include'
Edit-Anchored 'core/src/server/game/Entities/Player/PlayerQuest.cpp' @'
    if (moneyRew)
    {
        ModifyMoney(moneyRew);
'@ @'
    if (moneyRew > 0)
        moneyRew = int32(float(moneyRew) * WeekendBonusRate("QuestMoneyRate"));

    if (moneyRew)
    {
        ModifyMoney(moneyRew);
'@ 'the quest money reward'

# Everything else lives beside world PvP XP and Battleground Spoils.
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
$spoils = @'
        uint32 const count = sConfigMgr->GetOption<uint32>(won ? "Battleground.SpoilsForWin" : "Battleground.SpoilsForLoss",
            won ? 3 : 1);
'@
$spoils = $spoils.Replace("`r`n", "`n")
foreach ($anchor in @($include, $register, $loader, $spoils)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no single: $($anchor.Trim().Split("`n")[0])" }
}
$class = @'
class weekend_bonus : public PlayerScript
{
public:
    weekend_bonus() : PlayerScript("weekend_bonus", {PLAYERHOOK_ON_GIVE_EXP, PLAYERHOOK_ON_GIVE_REPUTATION,
        PLAYERHOOK_ON_UPDATE_GATHERING_SKILL, PLAYERHOOK_ON_UPDATE_CRAFTING_SKILL, PLAYERHOOK_ON_QUEST_REWARD_ITEM,
        PLAYERHOOK_ON_LOGIN}) { }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 xpSource) override
    {
        if (!amount || !WeekendBonusToday())
            return;
        float rate = WeekendBonusRate("XPRate");
        if (xpSource == XPSOURCE_QUEST || xpSource == XPSOURCE_QUEST_DF)
            rate *= WeekendBonusRate("QuestXPRate");
        else if (xpSource == XPSOURCE_BATTLEGROUND)
            rate *= WeekendBonusRate("PvPXPRate");
        else if (xpSource == XPSOURCE_PROFESSION || xpSource == XPSOURCE_PROFESSION_SKILL)
            rate *= WeekendBonusRate("ProfessionXPRate");
        else if (xpSource == XPSOURCE_KILL && InDungeon(player))
            rate *= WeekendBonusRate("DungeonXPRate");
        amount = uint32(float(amount) * rate);
    }

    void OnPlayerGiveReputation(Player* player, int32 /*factionID*/, float& amount, ReputationSource /*repSource*/) override
    {
        if (amount <= 0.0f || !WeekendBonusToday())
            return;
        amount *= WeekendBonusRate("ReputationRate");
        if (InDungeon(player))
            amount *= WeekendBonusRate("DungeonReputationRate");
    }

    void OnPlayerUpdateGatheringSkill(Player* /*player*/, uint32 /*skill*/, uint32 /*current*/, uint32 /*gray*/,
        uint32 /*green*/, uint32 /*yellow*/, uint32& gain) override
    {
        gain = ScaleByChance(gain, WeekendBonusRate("ProfessionSkillRate"));
    }

    void OnPlayerUpdateCraftingSkill(Player* /*player*/, SkillLineAbilityEntry const* /*skill*/, uint32 /*current*/,
        uint32& gain) override
    {
        gain = ScaleByChance(gain, WeekendBonusRate("ProfessionSkillRate"));
    }

    // Quest weekends: an Adventurer's Satchel or Cache handed out as a quest reward (the random dungeon cache too)
    // comes with extra copies, QuestCacheRate times as many in all. Dungeon weekends: DungeonCacheRate instead for one
    // handed out inside a dungeon or raid (the random dungeon cache).
    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 count) override
    {
        if (!item || !count || !IsAdventurerReward(item->GetEntry()) || IsBattlegroundSpoils(item->GetEntry()))
            return;
        uint32 const total = ScaleByChance(count, WeekendBonusRate(InDungeon(player) ? "DungeonCacheRate" : "QuestCacheRate"));
        if (total <= count)
            return;
        uint32 const entry = item->GetEntry();
        for (uint32 extra = count; extra < total; ++extra)
        {
            ItemPosCountVec dest;
            if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entry, 1) == EQUIP_ERR_OK)
                if (Item* given = player->StoreNewItem(dest, entry, true))
                {
                    player->SendNewItem(given, 1, true, false);
                    continue;
                }
            player->SendItemRetrievalMail(entry, 1);
        }
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!WeekendBonusToday() || !player->GetSession() || player->GetSession()->IsBot())
            return;
        std::string const theme = WeekendBonusTheme();
        if (theme.empty())
            return;
        std::string const title = sConfigMgr->GetOption<std::string>("WeekendBonus." + theme + ".Title", theme, false);
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cff00ff00It's " + title + "!|r See wildcard.jtlab.cc for this event's bonuses.");
    }

    static bool InDungeon(Player* player)
    {
        return player && player->FindMap() && player->FindMap()->IsDungeon();
    }

    static uint32 ScaleByChance(uint32 value, float rate)
    {
        if (!value || rate == 1.0f)
            return value;
        float const scaled = float(value) * rate;
        uint32 whole = uint32(scaled);
        if (frand(0.0f, 1.0f) < scaled - float(whole))
            ++whole;
        return whole;
    }
};

// Profession weekends: herb, ore and other trade goods from gathering nodes, everything skinned and everything
// fished come in GatherYieldRate times the usual amount (never past a full stack).
class weekend_bonus_gathering : public MiscScript
{
public:
    weekend_bonus_gathering() : MiscScript("weekend_bonus_gathering", {MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS}) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*tab*/, LootStore const& store, Player* owner,
        bool /*personal*/, bool /*noEmptyError*/, uint16 /*lootMode*/) override
    {
        if (!loot || !owner || (&store != &LootTemplates_Gameobject && &store != &LootTemplates_Skinning &&
            &store != &LootTemplates_Fishing))
            return;
        float const rate = WeekendBonusRate("GatherYieldRate");
        if (rate == 1.0f)
            return;
        for (LootItem& entry : loot->items)
        {
            ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry.itemid);
            if (!proto || entry.needs_quest)
                continue;
            if (&store == &LootTemplates_Gameobject && proto->Class != ITEM_CLASS_TRADE_GOODS &&
                proto->Class != ITEM_CLASS_GEM)
                continue;
            uint32 const scaled = weekend_bonus::ScaleByChance(entry.count, rate);
            entry.count = uint8(std::min<uint32>({scaled, proto->GetMaxStackSize(), 255u}));
        }
    }
};

'@
# PvP weekends: BattlegroundSpoilsRate times the Battleground Spoils (defined here, before the spoils class uses it).
$helpers = "#include `"Map.h`"`n#include `"MiscScript.h`"`n#include `"WeekendBonus.h`"`n#include <string>`n`nstatic uint32 weekend_bonus_spoils(uint32 count)`n{`n    return uint32(float(count) * WeekendBonusRate(`"BattlegroundSpoilsRate`") + 0.5f);`n}`n`n"
$text = $text.Replace($include, $include + $helpers)
$text = $text.Replace($spoils, @'
        uint32 const count = weekend_bonus_spoils(sConfigMgr->GetOption<uint32>(won ? "Battleground.SpoilsForWin" : "Battleground.SpoilsForLoss",
            won ? 3 : 1));
'@.Replace("`r`n", "`n"))
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new weekend_bonus();`n    new weekend_bonus_gathering();`n")
Set-Content $file $text -NoNewline
}
