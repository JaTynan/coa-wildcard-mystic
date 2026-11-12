# Bonus stats: gear (rings, necks and trinkets too) from loot, quests and crafting can roll extra stats and a gem socket.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose
# world PvP part this builds on (same file and script loader). Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Bonus stat rolls on gear (BonusStats.Enabled)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# When a weapon or armour piece is looted (also won on a group roll), given by a quest, or crafted, it has
# BonusStats.ChancePercent (25) to roll a bonus; a roll gives one and, at BonusStats.SecondStatPercent (25),
# a second. Each bonus is a gem socket at BonusStats.SocketSharePercent (33): an extra prismatic socket, as the
# Eternal Belt Buckle gives, if the item has fewer than three (one at most); otherwise a stat. Rings, necklaces,
# trinkets and relics count as armour. Stats suit the item: caster gear rolls caster stats, physical gear physical stats, tank gear tank stats.
# Each is a single-stat enchantment that already exists in the game data (so the client shows it, in green), put
# in a free random-property enchantment slot, so it is saved with the item and works like any item stat. The
# size follows the item level (BonusStats.PointsPerItemLevel, 0.25: a level-63 blue rolls about 16 crit rating,
# 32 attack power or 18 spell power), give or take 20%. Loot and quest gear needs BonusStats.MinQuality (3,
# blue); crafted gear BonusStats.CraftedMinQuality (2, green). Bots never roll.
$class = @'
namespace WcmeBonusStats
{
    // stat -> (amount -> enchantment id), built once from SpellItemEnchantment.dbc.
    std::map<uint32, std::map<uint32, uint32>> const& Enchants()
    {
        static std::map<uint32, std::map<uint32, uint32>> const table = []
        {
            std::map<uint32, std::map<uint32, uint32>> built;
            for (uint32 id = 1; id < sSpellItemEnchantmentStore.GetNumRows(); ++id)
            {
                SpellItemEnchantmentEntry const* entry = sSpellItemEnchantmentStore.LookupEntry(id);
                if (!entry || entry->type[0] != ITEM_ENCHANTMENT_TYPE_STAT || entry->type[1] || entry->type[2] ||
                    !entry->amount[0] || entry->charges || entry->GemID || entry->EnchantmentCondition ||
                    entry->requiredSkill || entry->requiredLevel)
                    continue;
                built[entry->spellid[0]].emplace(entry->amount[0], id);
            }
            return built;
        }();
        return table;
    }

    // How many points one "unit" of the budget buys of each stat (ratings 1, attack power 2, and so on).
    float Weight(uint32 stat)
    {
        switch (stat)
        {
            case ITEM_MOD_ATTACK_POWER: return 2.0f;
            case ITEM_MOD_SPELL_POWER: return 1.17f;
            case ITEM_MOD_MANA_REGENERATION: return 0.4f;
            case ITEM_MOD_AGILITY: case ITEM_MOD_STRENGTH: case ITEM_MOD_INTELLECT: case ITEM_MOD_SPIRIT:
            case ITEM_MOD_STAMINA: return 0.67f;
            default: return 1.0f;
        }
    }

    std::vector<uint32> Pool(ItemTemplate const* proto)
    {
        bool caster = false, physical = false, tank = false;
        for (uint8 i = 0; i < proto->StatsCount && i < MAX_ITEM_PROTO_STATS; ++i)
            switch (proto->ItemStat[i].ItemStatType)
            {
                case ITEM_MOD_INTELLECT: case ITEM_MOD_SPIRIT: case ITEM_MOD_SPELL_POWER: case ITEM_MOD_MANA_REGENERATION:
                case ITEM_MOD_SPELL_PENETRATION: caster = true; break;
                case ITEM_MOD_AGILITY: case ITEM_MOD_STRENGTH: case ITEM_MOD_ATTACK_POWER: case ITEM_MOD_RANGED_ATTACK_POWER:
                case ITEM_MOD_EXPERTISE_RATING: case ITEM_MOD_ARMOR_PENETRATION_RATING: physical = true; break;
                case ITEM_MOD_DEFENSE_SKILL_RATING: case ITEM_MOD_DODGE_RATING: case ITEM_MOD_PARRY_RATING:
                case ITEM_MOD_BLOCK_RATING: case ITEM_MOD_BLOCK_VALUE: tank = true; break;
                default: break;
            }
        std::vector<uint32> pool;
        if (caster)
            pool.insert(pool.end(), {ITEM_MOD_SPELL_POWER, ITEM_MOD_CRIT_RATING, ITEM_MOD_HASTE_RATING, ITEM_MOD_HIT_RATING,
                ITEM_MOD_MANA_REGENERATION, ITEM_MOD_INTELLECT, ITEM_MOD_SPIRIT});
        if (physical)
            pool.insert(pool.end(), {ITEM_MOD_ATTACK_POWER, ITEM_MOD_CRIT_RATING, ITEM_MOD_HASTE_RATING, ITEM_MOD_HIT_RATING,
                ITEM_MOD_EXPERTISE_RATING, ITEM_MOD_ARMOR_PENETRATION_RATING, ITEM_MOD_AGILITY, ITEM_MOD_STRENGTH});
        if (tank)
            pool.insert(pool.end(), {ITEM_MOD_DEFENSE_SKILL_RATING, ITEM_MOD_DODGE_RATING, ITEM_MOD_PARRY_RATING,
                ITEM_MOD_BLOCK_RATING, ITEM_MOD_STAMINA});
        if (pool.empty())
            pool = {ITEM_MOD_CRIT_RATING, ITEM_MOD_HASTE_RATING, ITEM_MOD_HIT_RATING, ITEM_MOD_ATTACK_POWER,
                ITEM_MOD_SPELL_POWER, ITEM_MOD_STAMINA};
        std::sort(pool.begin(), pool.end());
        pool.erase(std::unique(pool.begin(), pool.end()), pool.end());
        return pool;
    }

    // The enchantment for `stat` closest to `target` points, if one is within half of it.
    uint32 Closest(uint32 stat, float target)
    {
        auto const found = Enchants().find(stat);
        if (found == Enchants().end() || found->second.empty())
            return 0;
        uint32 best = 0;
        float distance = target * 0.5f;
        for (auto const& [amount, id] : found->second)
            if (std::fabs(float(amount) - target) <= distance)
            {
                distance = std::fabs(float(amount) - target);
                best = id;
            }
        return best;
    }

    // An enchantment that opens a prismatic gem socket (as the Eternal Belt Buckle does), from the game data.
    uint32 SocketEnchant()
    {
        static uint32 const id = []
        {
            for (uint32 row = 1; row < sSpellItemEnchantmentStore.GetNumRows(); ++row)
                if (SpellItemEnchantmentEntry const* entry = sSpellItemEnchantmentStore.LookupEntry(row))
                    if (entry->type[0] == ITEM_ENCHANTMENT_TYPE_PRISMATIC_SOCKET && !entry->requiredLevel &&
                        !entry->requiredSkill && !entry->EnchantmentCondition)
                        return row;
            return 0u;
        }();
        return id;
    }

    // source: 0 looted or a quest reward, 1 crafted, 2 from a cache.
    void Roll(Player* player, Item* item, uint8 source)
    {
        if (!sConfigMgr->GetOption<bool>("BonusStats.Enabled", false) || !player || !item || !player->GetSession() ||
            player->GetSession()->IsBot())
            return;
        ItemTemplate const* proto = item->GetTemplate();
        if (!proto || (proto->Class != ITEM_CLASS_WEAPON && proto->Class != ITEM_CLASS_ARMOR) ||
            proto->InventoryType == INVTYPE_NON_EQUIP || proto->InventoryType == INVTYPE_BODY ||
            proto->InventoryType == INVTYPE_TABARD || proto->GetMaxStackSize() > 1)
            return;
        uint32 const minQuality = source == 1 ? sConfigMgr->GetOption<uint32>("BonusStats.CraftedMinQuality", 2) :
            source == 2 ? sConfigMgr->GetOption<uint32>("BonusStats.CacheMinQuality", 2) :
            sConfigMgr->GetOption<uint32>("BonusStats.MinQuality", 3);
        if (proto->Quality < minQuality)
            return;

        // BonusStats.ChancePercent (25) gives one bonus and SecondStatPercent (25) of those a second. Each bonus is a
        // gem socket at BonusStats.SocketSharePercent (33), otherwise a stat. Only one socket can be added (an extra
        // prismatic socket, if the item has fewer than three), so a second socket roll becomes a stat.
        if (urand(1, 100) > sConfigMgr->GetOption<uint32>("BonusStats.ChancePercent", 25))
            return;
        uint32 const bonuses = urand(1, 100) <= sConfigMgr->GetOption<uint32>("BonusStats.SecondStatPercent", 25) ? 2 : 1;
        uint32 const socketShare = sConfigMgr->GetOption<uint32>("BonusStats.SocketSharePercent", 33);

        uint8 sockets = 0;
        for (uint8 i = 0; i < MAX_ITEM_PROTO_SOCKETS; ++i)
            if (proto->Socket[i].Color)
                ++sockets;
        bool canSocket = sockets < MAX_ITEM_PROTO_SOCKETS && !item->GetEnchantmentId(PRISMATIC_ENCHANTMENT_SLOT) &&
            SocketEnchant();
        bool socketed = false;
        uint32 count = 0;
        for (uint32 i = 0; i < bonuses; ++i)
        {
            if (canSocket && urand(1, 100) <= socketShare)
            {
                item->SetEnchantment(PRISMATIC_ENCHANTMENT_SLOT, SocketEnchant(), 0, 0);
                socketed = true;
                canSocket = false;
            }
            else
                ++count;
        }

        std::string rolled;
        std::vector<EnchantmentSlot> slots;
        for (uint32 slot = PROP_ENCHANTMENT_SLOT_0; slot < MAX_ENCHANTMENT_SLOT; ++slot)
            if (!item->GetEnchantmentId(EnchantmentSlot(slot)))
                slots.push_back(EnchantmentSlot(slot));

        uint32 const level = std::max<uint32>(proto->ItemLevel, NativeItemScaling::InstanceLevel(item) + 5u);
        float const budget = float(level) * sConfigMgr->GetOption<float>("BonusStats.PointsPerItemLevel", 0.25f);
        std::vector<uint32> pool = Pool(proto);
        Acore::Containers::RandomShuffle(pool);

        for (uint32 stat : pool)
        {
            if (!count || slots.empty())
                break;
            uint32 const enchant = Closest(stat, budget * Weight(stat) * frand(0.8f, 1.2f));
            SpellItemEnchantmentEntry const* entry = enchant ? sSpellItemEnchantmentStore.LookupEntry(enchant) : nullptr;
            if (!entry)
                continue;
            item->SetEnchantment(slots.front(), enchant, 0, 0);
            slots.erase(slots.begin());
            --count;
            rolled += (rolled.empty() ? "" : " and ") + std::string(entry->description[0] ? entry->description[0] : "");
        }
        if (socketed)
            rolled += (rolled.empty() ? "" : " and ") + std::string("a gem socket");
        if (rolled.empty())
            return;
        item->SetState(ITEM_CHANGED, player);
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cff1eff00Bonus stats!|r Your " + proto->Name1 + " rolled " + rolled + ".");
    }
}

class wcme_bonus_stats : public PlayerScript
{
public:
    wcme_bonus_stats() : PlayerScript("wcme_bonus_stats", {PLAYERHOOK_ON_LOOT_ITEM, PLAYERHOOK_ON_GROUP_ROLL_REWARD_ITEM,
        PLAYERHOOK_ON_QUEST_REWARD_ITEM, PLAYERHOOK_ON_CREATE_ITEM}) { }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootguid*/) override
    {
        WcmeBonusStats::Roll(player, item, 0);
    }

    void OnPlayerGroupRollRewardItem(Player* player, Item* item, uint32 /*count*/, RollVote /*voteType*/, Roll* /*roll*/) override
    {
        WcmeBonusStats::Roll(player, item, 0);
    }

    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        WcmeBonusStats::Roll(player, item, 0);
    }

    void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
    {
        WcmeBonusStats::Roll(player, item, 1);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"AscensionNativeItemScaling.h`"`n#include `"Containers.h`"`n#include `"DBCStores.h`"`n#include <cmath>`n#include <string>`n#include <vector>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_bonus_stats();`n")
Set-Content $file $text -NoNewline
}

# Gear from caches (Adventurer's caches, Battleground Spoils, Manastorm caches: everything AscensionCacheRewards::Deliver
# puts in the bags) rolls too, from BonusStats.CacheMinQuality (2, green), so players meet the rolls while levelling.
# Gear that goes to the mailbox because the bags are full does not roll.
& {
$file = 'core/src/server/coa/AscensionCacheRewards.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"Player.h`"`n"
$old = @'
    for (std::unique_ptr<Item>& item : mailItems)
        player->SendItemRetrievalMail(item.release());
'@
$old = $old.Replace("`r`n", "`n")
if (([regex]::Matches($text, [regex]::Escape($include))).Count -ne 1) { throw 'Core changed: AscensionCacheRewards.cpp has no single Player.h include' }
if (([regex]::Matches($text, [regex]::Escape($old))).Count -ne 1) { throw 'Core changed: the mail step in AscensionCacheRewards::Deliver was not found' }
$text = $text.Replace($include, $include + "`nnamespace WcmeBonusStats { void Roll(Player* player, Item* item, uint8 source); } // patches/48-bonus-stats.ps1`n")
$new = @'
    for (auto const& given : stored)
        WcmeBonusStats::Roll(player, given.first, 2);

'@
Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n") + $old) -NoNewline
}
