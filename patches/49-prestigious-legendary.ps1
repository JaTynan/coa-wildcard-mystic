# Prestigious Cache: the "One Legendary Enchant for the class of your choice" the tooltip promises.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the .patch files (our Mystic
# Enchant patch touches other parts of AscensionMysticEnchant.cpp). Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Anchored([string]$file, [string]$old, [string]$new, [string]$what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    $old = $old.Replace("`r`n", "`n")
    if (([regex]::Matches($text, [regex]::Escape($old))).Count -ne 1) { throw "Core changed: $what was not found in $file" }
    Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Prestigious Cache gives a choice of one Legendary Enchant (Wildcard.PrestigeLegendaryChoice)"

# 1. The Mystic Enchant catalogue lists, for one class, every Legendary enchant this realm offers that has a scroll.
Edit-Anchored 'core/src/server/coa/AscensionMysticEnchant.h' @'
std::optional<Collection> Summarize(Player const* player);
}
'@ @'
std::optional<Collection> Summarize(Player const* player);

// Wildcard (patches/49-prestigious-legendary.ps1): (scroll item, enchant spell) of every Legendary enchant this realm
// offers for classId, in catalogue order. Empty until the catalogue is loaded.
std::vector<std::pair<uint32, uint32>> LegendaryChoices(uint32 classId);
}
'@ 'the Summarize declaration'
Edit-Anchored 'core/src/server/coa/AscensionMysticEnchant.cpp' @'
    return collection;
}
}

void AddAscensionMysticEnchantScripts()
'@ @'
    return collection;
}

std::vector<std::pair<uint32, uint32>> LegendaryChoices(uint32 classId)
{
    std::vector<std::pair<uint32, uint32>> choices;
    if (!Ready)
        return choices;
    std::array<bool, REALM_COUNT> const gates = AscensionFreepick::RealmGates();
    for (Enchant const& enchant : Loaded.Rows)
        if (enchant.Item && enchant.Spell && !enchant.Worldforged && ClassAllowed(enchant, classId) &&
            QualityOf(enchant, classId) == QUALITY_LEGENDARY && RealmAllows(enchant, gates) &&
            sObjectMgr->GetItemTemplate(enchant.Item))
            choices.emplace_back(enchant.Item, enchant.Spell);
    return choices;
}
}

void AddAscensionMysticEnchantScripts()
'@ 'the end of the AscensionMysticEnchant namespace'

# 2. Opening a Prestigious Cache owes the player one choice (kept in wcme_prestige_legendary until made). A menu opens
#    right away: pick a class, then one of its Legendary enchants; its scroll goes to the bags (or the mailbox).
#    Closed the menu? ".legendary" opens it again, and players are reminded at login while a choice is owed.
$file = 'core/src/server/coa/AscensionPrestigiousCache.cpp'
Edit-Anchored $file "#include `"AscensionCacheRewards.h`"`n" "#include `"AscensionCacheRewards.h`"`n#include `"AscensionMysticEnchant.h`"`n#include `"ChatCommand.h`"`n#include `"CommandScript.h`"`n#include `"DBCStores.h`"`n#include `"ScriptedGossip.h`"`n#include `"SpellInfo.h`"`n#include `"SpellMgr.h`"`n#include `"WorldScript.h`"`n#include <string>`n" 'the AscensionCacheRewards.h include'
Edit-Anchored $file @'
bool OpenPrestigiousCache(Player* player, Item* item)
{
'@ @'
namespace WcmePrestigeLegendary
{
    constexpr uint32 Menu = 9100249;
    constexpr uint32 PageSize = 20;
    constexpr uint32 ClassSender = 1;      // action: class id, or NextBase + page
    constexpr uint32 EnchantSender = 1000; // sender: EnchantSender + class id; action: choice index, NextBase + page, Back
    constexpr uint32 NextBase = 100000;
    constexpr uint32 Back = 200000;

    std::mutex Lock;
    std::unordered_map<uint32, uint32> Owed; // character guid -> choices owed

    bool Enabled() { return sConfigMgr->GetOption<bool>("Wildcard.PrestigeLegendaryChoice", false); }

    uint32 OwedTo(Player* player)
    {
        std::lock_guard<std::mutex> guard(Lock);
        auto const found = Owed.find(player->GetGUID().GetCounter());
        return found == Owed.end() ? 0 : found->second;
    }

    void SetOwed(Player* player, uint32 count)
    {
        uint32 const guid = player->GetGUID().GetCounter();
        {
            std::lock_guard<std::mutex> guard(Lock);
            if (count)
                Owed[guid] = count;
            else
                Owed.erase(guid);
        }
        if (count)
            CharacterDatabase.Execute("REPLACE INTO wcme_prestige_legendary (guid, owed) VALUES ({}, {})", guid, count);
        else
            CharacterDatabase.Execute("DELETE FROM wcme_prestige_legendary WHERE guid = {}", guid);
    }

    std::string ClassName(uint32 classId)
    {
        ChrClassesEntry const* entry = sChrClassesStore.LookupEntry(classId);
        return entry && entry->name[0] && *entry->name[0] ? entry->name[0] : "Class " + std::to_string(classId);
    }

    std::vector<uint32> Classes()
    {
        std::vector<uint32> classes;
        for (uint32 classId = 1; classId < 64; ++classId)
            if (sChrClassesStore.LookupEntry(classId) && !AscensionMysticEnchant::LegendaryChoices(classId).empty())
                classes.push_back(classId);
        return classes;
    }

    void Open(Player* player, uint32 page = 0)
    {
        ClearGossipMenuFor(player);
        std::vector<uint32> const classes = Classes();
        for (uint32 i = page * PageSize; i < classes.size() && i < (page + 1) * PageSize; ++i)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, ClassName(classes[i]), ClassSender, classes[i]);
        if ((page + 1) * PageSize < classes.size())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "More classes...", ClassSender, NextBase + page + 1);
        if (classes.empty())
            ChatHandler(player->GetSession()).SendSysMessage("No Legendary Enchants are available to choose from yet.");
        player->PlayerTalkClass->GetGossipMenu().SetMenuId(Menu);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
    }

    void OpenClass(Player* player, uint32 classId, uint32 page)
    {
        ClearGossipMenuFor(player);
        std::vector<std::pair<uint32, uint32>> const choices = AscensionMysticEnchant::LegendaryChoices(classId);
        uint32 const sender = EnchantSender + classId;
        for (uint32 i = page * PageSize; i < choices.size() && i < (page + 1) * PageSize; ++i)
        {
            SpellInfo const* spell = sSpellMgr->GetSpellInfo(choices[i].second);
            std::string const name = spell && spell->SpellName[0] ? spell->SpellName[0] : "Enchant " + std::to_string(choices[i].second);
            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, name, sender, i,
                "Take " + name + " (" + ClassName(classId) + ")? This choice is final.", 0, false);
        }
        if ((page + 1) * PageSize < choices.size())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "More enchants...", sender, NextBase + page + 1);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back to classes", sender, Back);
        player->PlayerTalkClass->GetGossipMenu().SetMenuId(Menu);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, player->GetGUID());
    }

    void Choose(Player* player, uint32 classId, uint32 index)
    {
        std::vector<std::pair<uint32, uint32>> const choices = AscensionMysticEnchant::LegendaryChoices(classId);
        uint32 const owed = OwedTo(player);
        if (index >= choices.size() || !owed)
            return;
        uint32 const scroll = choices[index].first;
        SetOwed(player, owed - 1);
        ItemPosCountVec dest;
        Item* given = nullptr;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, scroll, 1) == EQUIP_ERR_OK)
            given = player->StoreNewItem(dest, scroll, true);
        if (given)
            player->SendNewItem(given, 1, true, false);
        else
            player->SendItemRetrievalMail(scroll, 1);
        ChatHandler(player->GetSession()).SendSysMessage(given ?
            "|cffff8000Your Legendary Enchant scroll is in your bags.|r" :
            "|cffff8000Your bags were full, so your Legendary Enchant scroll was sent to your mailbox.|r");
        if (owed > 1)
            Open(player);
    }

    void Grant(Player* player)
    {
        if (!Enabled() || !player || !player->GetSession() || player->GetSession()->IsBot())
            return;
        SetOwed(player, OwedTo(player) + 1);
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cffff8000Choose your Legendary Enchant.|r Closed the window? Type .legendary to open it again.");
        Open(player);
    }
}

class wcme_prestige_legendary_player : public PlayerScript
{
public:
    wcme_prestige_legendary_player() : PlayerScript("wcme_prestige_legendary_player",
        {PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_GOSSIP_SELECT}) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!WcmePrestigeLegendary::Enabled())
            return;
        if (QueryResult result = CharacterDatabase.Query("SELECT owed FROM wcme_prestige_legendary WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            uint32 const owed = result->Fetch()[0].Get<uint32>();
            {
                std::lock_guard<std::mutex> guard(WcmePrestigeLegendary::Lock);
                WcmePrestigeLegendary::Owed[player->GetGUID().GetCounter()] = owed;
            }
            if (owed)
                ChatHandler(player->GetSession()).SendSysMessage(
                    "|cffff8000You have a Legendary Enchant to choose from your Prestigious Cache.|r Type .legendary to choose it.");
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        std::lock_guard<std::mutex> guard(WcmePrestigeLegendary::Lock);
        WcmePrestigeLegendary::Owed.erase(player->GetGUID().GetCounter());
    }

    void OnPlayerGossipSelect(Player* player, uint32 menu, uint32 sender, uint32 action) override
    {
        if (menu != WcmePrestigeLegendary::Menu)
            return;
        using namespace WcmePrestigeLegendary;
        if (!OwedTo(player))
        {
            CloseGossipMenuFor(player);
            return;
        }
        if (sender == ClassSender)
        {
            if (action >= NextBase)
                Open(player, action - NextBase);
            else
                OpenClass(player, action, 0);
            return;
        }
        if (sender > EnchantSender)
        {
            uint32 const classId = sender - EnchantSender;
            if (action == Back)
                Open(player);
            else if (action >= NextBase)
                OpenClass(player, classId, action - NextBase);
            else
            {
                CloseGossipMenuFor(player);
                Choose(player, classId, action);
            }
        }
    }
};

class wcme_prestige_legendary_world : public WorldScript
{
public:
    wcme_prestige_legendary_world() : WorldScript("wcme_prestige_legendary_world", {WORLDHOOK_ON_STARTUP}) { }

    void OnStartup() override
    {
        CharacterDatabase.DirectExecute("CREATE TABLE IF NOT EXISTS wcme_prestige_legendary (guid INT UNSIGNED NOT NULL, "
            "owed INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (guid)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }
};

class wcme_prestige_legendary_command : public CommandScript
{
public:
    wcme_prestige_legendary_command() : CommandScript("wcme_prestige_legendary_command") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        static Acore::ChatCommands::ChatCommandTable commands =
            { { "legendary", HandleLegendary, SEC_PLAYER, Acore::ChatCommands::Console::No } };
        return commands;
    }

    static bool HandleLegendary(ChatHandler* handler)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;
        if (!WcmePrestigeLegendary::Enabled() || !WcmePrestigeLegendary::OwedTo(player))
        {
            handler->SendSysMessage("You have no Legendary Enchant to choose. Each Prestigious Cache gives one.");
            return true;
        }
        WcmePrestigeLegendary::Open(player);
        return true;
    }
};

bool OpenPrestigiousCache(Player* player, Item* item)
{
'@ 'the start of OpenPrestigiousCache'
Edit-Anchored $file @'
    AscensionCacheRewards::Deliver(player, payout, item);

    return true;
}
'@ @'
    if (AscensionCacheRewards::Deliver(player, payout, item))
        WcmePrestigeLegendary::Grant(player);

    return true;
}
'@ 'the delivery at the end of OpenPrestigiousCache'
Edit-Anchored $file @'
    new ascension_prestigious_cache_pools();
}
'@ @'
    new ascension_prestigious_cache_pools();
    new wcme_prestige_legendary_player();
    new wcme_prestige_legendary_world();
    new wcme_prestige_legendary_command();
}
'@ 'the AddSC_AscensionPrestigiousCache registrations'
