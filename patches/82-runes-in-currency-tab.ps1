# Runes of Descension (item 375250) are kept in the currency tab's slots, where the client looks for them. The
# Wildcard window (Scrolls of Fortune claims and Repurchase Scrolls) decides in the client whether you can pay, and the
# client counts only the 32 currency-token slots, not bags; the balance it shows counts everywhere. Runes that landed
# in bags (before the rune became a currency, issue #122, and every rune since, because a new rune joins an existing
# stack and a bag stack is found before an empty currency slot) made the window say "not enough" with plenty owned
# (James, 20 November). At login and every 2 sec, any rune stack in the backpack or a bag moves into the currency
# slots, joining the stack there. Needs the rune to be a currency (sql/enchants/160-rune-currency.sql).
# Run by the build from the workspace root, after 40-battlegrounds.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: rune check timer on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint32 WcmeRuneTabTimer = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Runes of Descension move into the currency tab"
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
// Wildcard: Runes of Descension live in the currency tab, where the client's Wildcard window counts them.
class wcme_runes_in_currency_tab : public PlayerScript
{
public:
    wcme_runes_in_currency_tab() : PlayerScript("wcme_runes_in_currency_tab", {PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE}) { }

    void OnPlayerLogin(Player* player) override
    {
        Gather(player);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        player->WcmeRuneTabTimer += diff;
        if (player->WcmeRuneTabTimer < CheckEvery)
            return;
        player->WcmeRuneTabTimer = 0;
        Gather(player);
    }

private:
    static constexpr uint32 Rune = 375250;
    static constexpr uint32 CheckEvery = 2000;

    static void Gather(Player* player)
    {
        if (!player || !player->IsInWorld() || player->IsBeingTeleported())
            return;
        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(Rune);
        if (!proto || !proto->IsCurrencyToken())
            return; // not a currency on this server: the currency slots won't take it

        // The stack already in the currency tab, if any.
        Item* tab = nullptr;
        for (uint8 slot = CURRENCYTOKEN_SLOT_START; slot < CURRENCYTOKEN_SLOT_END && !tab; ++slot)
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot); item && item->GetEntry() == Rune)
                tab = item;

        // Every rune stack in the backpack and the bags.
        std::vector<std::pair<uint8, uint8>> found;
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
            if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot); item && item->GetEntry() == Rune)
                found.emplace_back(INVENTORY_SLOT_BAG_0, slot);
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
            if (Bag* container = player->GetBagByPos(bag))
                for (uint32 slot = 0; slot < container->GetBagSize(); ++slot)
                    if (Item* item = container->GetItemByPos(uint8(slot)); item && item->GetEntry() == Rune)
                        found.emplace_back(bag, uint8(slot));

        for (auto const& [bag, slot] : found)
        {
            Item* item = player->GetItemByPos(bag, slot);
            if (!item || item->GetEntry() != Rune || item->IsInTrade())
                continue;
            if (!tab)
            {
                // No stack in the tab yet: this stack moves into the first free currency slot.
                for (uint8 free = CURRENCYTOKEN_SLOT_START; free < CURRENCYTOKEN_SLOT_END; ++free)
                {
                    if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, free))
                        continue;
                    ItemPosCountVec dest;
                    if (player->CanStoreItem(INVENTORY_SLOT_BAG_0, free, dest, item, false) != EQUIP_ERR_OK)
                        break;
                    player->RemoveItem(bag, slot, true);
                    tab = player->StoreItem(dest, item, true);
                    break;
                }
                if (!tab)
                    return; // the currency slots are full; try again next time
                continue;
            }
            // Join the tab's stack (the destroyed stack and the larger one are saved together).
            uint32 const count = item->GetCount();
            if (uint64(tab->GetCount()) + count > proto->GetMaxStackSize())
                return;
            player->DestroyItem(bag, slot, true);
            tab->SetCount(tab->GetCount() + count);
            tab->SetState(ITEM_CHANGED, player);
        }
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Bag.h`"`n#include `"ObjectMgr.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_runes_in_currency_tab();`n")
Set-Content $file $text -NoNewline
}
