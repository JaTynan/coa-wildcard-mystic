# Profession Mastery: past skill 300, gathering and crafting keep earning Mastery levels that raise yields and rolls.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1 and
# 48-bonus-stats.ps1, whose code this builds on (same file and script loader). Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Profession Mastery (Mastery.Enabled)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
$chance = @'
        if (urand(1, 100) > sConfigMgr->GetOption<uint32>("BonusStats.ChancePercent", 25))
            return;
        uint32 const bonuses = urand(1, 100) <= sConfigMgr->GetOption<uint32>("BonusStats.SecondStatPercent", 25) ? 2 : 1;
'@
$chance = $chance.Replace("`r`n", "`n")
foreach ($anchor in @($include, $register, $loader, $chance)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed (or 40/48 did not run): AscensionAdventurerCache.cpp has no single: $($anchor.Trim().Split("`n")[0])" }
}
# Once a profession's skill reaches Mastery.StartSkill (300), every gather or craft with it earns a Mastery point, even
# grey ones. Points fill Mastery levels up to Mastery.MaxLevel (50); level L+1 costs FirstLevelPoints (10) x (1 +
# L x Growth (0.1)) points, about 1,700 in all. Saved per character in wcme_profession_mastery.
#   Gathering (Mining, Herbalism, Skinning, Fishing; Jewelcrafting for prospecting, Inscription for milling): the
#     materials from each node, skin, catch, prospect or mill rise in step to Mastery.GatherYieldMax (3x) at max level.
#   Crafting (Blacksmithing, Leatherworking, Tailoring, Engineering): the bonus-roll chances on crafted gear (both the
#     first and the second bonus) rise in step to Mastery.CraftRollMax (2x) at max level, from the crafter's best of
#     those four professions.
# Level-ups are announced to the player; .mastery lists every Mastery. Bots never earn it.
$class = @'
namespace WcmeMastery
{
    std::mutex Lock;
    std::unordered_map<uint32, std::map<uint32, uint32>> Points; // character guid -> skill -> points

    bool Enabled() { return sConfigMgr->GetOption<bool>("Mastery.Enabled", false); }
    uint32 MaxLevel() { return std::min<uint32>(sConfigMgr->GetOption<uint32>("Mastery.MaxLevel", 50), 1000); }

    bool Gathering(uint32 skill)
    {
        return skill == SKILL_MINING || skill == SKILL_HERBALISM || skill == SKILL_SKINNING || skill == SKILL_FISHING ||
            skill == SKILL_JEWELCRAFTING || skill == SKILL_INSCRIPTION;
    }

    bool Crafting(uint32 skill)
    {
        return skill == SKILL_BLACKSMITHING || skill == SKILL_LEATHERWORKING || skill == SKILL_TAILORING ||
            skill == SKILL_ENGINEERING;
    }

    uint32 LevelFor(uint32 points)
    {
        float const first = std::max(1.0f, sConfigMgr->GetOption<float>("Mastery.FirstLevelPoints", 10.0f));
        float const growth = std::max(0.0f, sConfigMgr->GetOption<float>("Mastery.Growth", 0.1f));
        uint32 const max = MaxLevel();
        float needed = 0.0f;
        uint32 level = 0;
        while (level < max)
        {
            needed += first * (1.0f + float(level) * growth);
            if (float(points) < needed)
                break;
            ++level;
        }
        return level;
    }

    uint32 PointsToNext(uint32 points)
    {
        float const first = std::max(1.0f, sConfigMgr->GetOption<float>("Mastery.FirstLevelPoints", 10.0f));
        float const growth = std::max(0.0f, sConfigMgr->GetOption<float>("Mastery.Growth", 0.1f));
        uint32 const level = LevelFor(points);
        if (level >= MaxLevel())
            return 0;
        float needed = 0.0f;
        for (uint32 l = 0; l <= level; ++l)
            needed += first * (1.0f + float(l) * growth);
        return uint32(std::ceil(needed - float(points)));
    }

    uint32 Level(Player* player, uint32 skill)
    {
        std::lock_guard<std::mutex> guard(Lock);
        auto const found = Points.find(player->GetGUID().GetCounter());
        if (found == Points.end())
            return 0;
        auto const entry = found->second.find(skill);
        return entry == found->second.end() ? 0 : LevelFor(entry->second);
    }

    // 1 at no Mastery, rising in step to `top` at the max level.
    float Scale(uint32 level, float top)
    {
        uint32 const max = std::max<uint32>(1, MaxLevel());
        return 1.0f + (std::max(1.0f, top) - 1.0f) * float(std::min(level, max)) / float(max);
    }

    float GatherYield(Player* player, uint32 skill)
    {
        return Enabled() ? Scale(Level(player, skill), sConfigMgr->GetOption<float>("Mastery.GatherYieldMax", 3.0f)) : 1.0f;
    }

    float CraftBoost(Player* player)
    {
        if (!Enabled() || !player)
            return 1.0f;
        uint32 best = 0;
        for (uint32 skill : {SKILL_BLACKSMITHING, SKILL_LEATHERWORKING, SKILL_TAILORING, SKILL_ENGINEERING})
            best = std::max(best, Level(player, skill));
        return Scale(best, sConfigMgr->GetOption<float>("Mastery.CraftRollMax", 2.0f));
    }

    std::string SkillName(uint32 skill)
    {
        SkillLineEntry const* entry = sSkillLineStore.LookupEntry(skill);
        return entry && entry->name[0] && *entry->name[0] ? entry->name[0] : "Profession " + std::to_string(skill);
    }

    std::string Describe(uint32 skill, uint32 level)
    {
        if (Crafting(skill))
            return Acore::StringFormat("bonus-roll chance x{:.2f} on crafted gear",
                Scale(level, sConfigMgr->GetOption<float>("Mastery.CraftRollMax", 2.0f)));
        return Acore::StringFormat("x{:.2f} materials", Scale(level, sConfigMgr->GetOption<float>("Mastery.GatherYieldMax", 3.0f)));
    }

    void Earn(Player* player, uint32 skill)
    {
        if (!Enabled() || !player || !player->GetSession() || player->GetSession()->IsBot() ||
            player->GetSkillValue(skill) < sConfigMgr->GetOption<uint32>("Mastery.StartSkill", 300))
            return;
        uint32 const guid = player->GetGUID().GetCounter();
        uint32 before = 0, after = 0;
        {
            std::lock_guard<std::mutex> guard(Lock);
            uint32& points = Points[guid][skill];
            before = points;
            if (LevelFor(points) < MaxLevel())
                ++points;
            after = points;
        }
        if (after == before)
            return;
        CharacterDatabase.Execute("REPLACE INTO wcme_profession_mastery (guid, skill, points) VALUES ({}, {}, {})",
            guid, skill, after);
        uint32 const level = LevelFor(after);
        if (level > LevelFor(before))
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat(
                "|cffffd000{} Mastery {}!|r Now {}.", SkillName(skill), level, Describe(skill, level)));
    }

    // The profession a gathering loot belongs to, from where it came and what it holds (0 = none).
    uint32 GatherSkill(Loot const& loot, LootStore const& store)
    {
        if (&store == &LootTemplates_Skinning)
            return SKILL_SKINNING;
        if (&store == &LootTemplates_Fishing)
            return SKILL_FISHING;
        if (&store == &LootTemplates_Prospecting)
            return SKILL_JEWELCRAFTING;
        if (&store == &LootTemplates_Milling)
            return SKILL_INSCRIPTION;
        if (&store != &LootTemplates_Gameobject)
            return 0;
        for (LootItem const& entry : loot.items)
            if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry.itemid))
            {
                if (proto->Class == ITEM_CLASS_TRADE_GOODS && proto->SubClass == ITEM_SUBCLASS_HERB)
                    return SKILL_HERBALISM;
                if ((proto->Class == ITEM_CLASS_TRADE_GOODS && proto->SubClass == ITEM_SUBCLASS_METAL_STONE) ||
                    proto->Class == ITEM_CLASS_GEM)
                    return SKILL_MINING;
            }
        return 0;
    }

    bool CountsFor(uint32 skill, ItemTemplate const* proto)
    {
        if (skill == SKILL_HERBALISM)
            return proto->Class == ITEM_CLASS_TRADE_GOODS && proto->SubClass == ITEM_SUBCLASS_HERB;
        if (skill == SKILL_MINING)
            return (proto->Class == ITEM_CLASS_TRADE_GOODS && proto->SubClass == ITEM_SUBCLASS_METAL_STONE) ||
                proto->Class == ITEM_CLASS_GEM;
        return true;
    }
}

class wcme_mastery_gathering : public MiscScript
{
public:
    wcme_mastery_gathering() : MiscScript("wcme_mastery_gathering", {MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS}) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*tab*/, LootStore const& store, Player* owner,
        bool /*personal*/, bool /*noEmptyError*/, uint16 /*lootMode*/) override
    {
        if (!loot || !owner || !WcmeMastery::Enabled())
            return;
        uint32 const skill = WcmeMastery::GatherSkill(*loot, store);
        if (!skill)
            return;
        float const yield = WcmeMastery::GatherYield(owner, skill);
        if (yield > 1.0f)
            for (LootItem& entry : loot->items)
            {
                ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry.itemid);
                if (!proto || entry.needs_quest || !WcmeMastery::CountsFor(skill, proto))
                    continue;
                float const scaled = float(entry.count) * yield;
                uint32 whole = uint32(scaled);
                if (frand(0.0f, 1.0f) < scaled - float(whole))
                    ++whole;
                entry.count = uint8(std::min<uint32>({whole, proto->GetMaxStackSize(), 255u}));
            }
        WcmeMastery::Earn(owner, skill);
    }
};

class wcme_mastery_player : public PlayerScript
{
public:
    wcme_mastery_player() : PlayerScript("wcme_mastery_player",
        {PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_UPDATE_CRAFTING_SKILL}) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!WcmeMastery::Enabled())
            return;
        std::map<uint32, uint32> loaded;
        if (QueryResult result = CharacterDatabase.Query("SELECT skill, points FROM wcme_profession_mastery WHERE guid = {}",
            player->GetGUID().GetCounter()))
            do
            {
                Field* fields = result->Fetch();
                loaded[fields[0].Get<uint32>()] = fields[1].Get<uint32>();
            } while (result->NextRow());
        std::lock_guard<std::mutex> guard(WcmeMastery::Lock);
        WcmeMastery::Points[player->GetGUID().GetCounter()] = std::move(loaded);
    }

    void OnPlayerLogout(Player* player) override
    {
        std::lock_guard<std::mutex> guard(WcmeMastery::Lock);
        WcmeMastery::Points.erase(player->GetGUID().GetCounter());
    }

    void OnPlayerUpdateCraftingSkill(Player* player, SkillLineAbilityEntry const* skill, uint32 /*current*/,
        uint32& /*gain*/) override
    {
        if (skill && (WcmeMastery::Crafting(skill->SkillLine) || skill->SkillLine == SKILL_JEWELCRAFTING ||
            skill->SkillLine == SKILL_INSCRIPTION))
            WcmeMastery::Earn(player, skill->SkillLine);
    }
};

class wcme_mastery_world : public WorldScript
{
public:
    wcme_mastery_world() : WorldScript("wcme_mastery_world", {WORLDHOOK_ON_STARTUP}) { }

    void OnStartup() override
    {
        CharacterDatabase.DirectExecute("CREATE TABLE IF NOT EXISTS wcme_profession_mastery (guid INT UNSIGNED NOT NULL, "
            "skill SMALLINT UNSIGNED NOT NULL, points INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (guid, skill)) "
            "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }
};

class wcme_mastery_command : public CommandScript
{
public:
    wcme_mastery_command() : CommandScript("wcme_mastery_command") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        static Acore::ChatCommands::ChatCommandTable commands =
            { { "mastery", HandleMastery, SEC_PLAYER, Acore::ChatCommands::Console::No } };
        return commands;
    }

    static bool HandleMastery(ChatHandler* handler)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;
        std::map<uint32, uint32> mine;
        {
            std::lock_guard<std::mutex> guard(WcmeMastery::Lock);
            auto const found = WcmeMastery::Points.find(player->GetGUID().GetCounter());
            if (found != WcmeMastery::Points.end())
                mine = found->second;
        }
        uint32 const start = sConfigMgr->GetOption<uint32>("Mastery.StartSkill", 300);
        handler->SendSysMessage(Acore::StringFormat("|cffffd000Profession Mastery|r (earned past skill {}):", start));
        bool any = false;
        for (uint32 skill : {SKILL_MINING, SKILL_HERBALISM, SKILL_SKINNING, SKILL_FISHING, SKILL_JEWELCRAFTING,
            SKILL_INSCRIPTION, SKILL_BLACKSMITHING, SKILL_LEATHERWORKING, SKILL_TAILORING, SKILL_ENGINEERING})
        {
            if (!player->HasSkill(skill))
                continue;
            any = true;
            uint32 const points = mine.count(skill) ? mine[skill] : 0;
            uint32 const level = WcmeMastery::LevelFor(points);
            uint32 const next = WcmeMastery::PointsToNext(points);
            handler->SendSysMessage(Acore::StringFormat("  {}: Mastery {} of {} ({}), {}", WcmeMastery::SkillName(skill),
                level, WcmeMastery::MaxLevel(), WcmeMastery::Describe(skill, level),
                next ? Acore::StringFormat("{} more to the next level", next) : std::string("maxed")));
        }
        if (!any)
            handler->SendSysMessage("  You have no profession that earns Mastery.");
        return true;
    }
};

'@
$text = $text.Replace($include, $include + "#include `"ChatCommand.h`"`n#include `"CommandScript.h`"`n#include `"DBCStores.h`"`n#include `"MiscScript.h`"`n#include `"WorldScript.h`"`n#include <cmath>`n#include <string>`n#include <unordered_map>`n`nnamespace WcmeMastery { float CraftBoost(Player* player); } // defined below`n")
$text = $text.Replace($chance, @'
        // Crafted gear: Profession Mastery (patches/51-profession-mastery.ps1) raises both chances.
        float const boost = source == 1 ? WcmeMastery::CraftBoost(player) : 1.0f;
        if (frand(0.0f, 100.0f) >= float(sConfigMgr->GetOption<uint32>("BonusStats.ChancePercent", 25)) * boost)
            return;
        uint32 const bonuses = frand(0.0f, 100.0f) < float(sConfigMgr->GetOption<uint32>("BonusStats.SecondStatPercent", 25)) * boost ? 2 : 1;
'@.Replace("`r`n", "`n"))
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_mastery_gathering();`n    new wcme_mastery_player();`n    new wcme_mastery_world();`n    new wcme_mastery_command();`n")
Set-Content $file $text -NoNewline
}
