# Scrolls of Fortune redeem themselves. A Scroll of Fortune item (I to XII, Abilities or Talents, or the plain ones)
# only adds to its specialization's scroll count, the one Character Advancement spends, when you use it; with
# hundreds arriving (in bags, and by the Postmaster when the bags were full) that meant clicking each stack by hand
# (James, 20 November). At login and every 2 sec, every Scroll of Fortune stack in the backpack and bags is redeemed
# exactly as using it would (the item's own "Redeem TOKEN_TYPE_SCROLL_OF_FORTUNE_..." spell decides the specialization,
# kind and amount), with one chat line. Stacks in a trade window are left alone. Patch 85 deletes the empty letters.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Scrolls of Fortune redeem themselves"

$ctor = "public:`n    explicit Player(WorldSession* session);`n"
Edit-Core 'core/src/server/game/Entities/Player/Player.h' $ctor ($ctor + "    uint32 WcmeScrollRedeemTimer = 0;`n") 'the Player constructor in Player.h'

$file = 'core/src/server/coa/AscensionWildcard.cpp'
$items = "class AscensionWildcardItems final : public AllItemScript`n"
Edit-Core $file $items (@'
// Wildcard: Scrolls of Fortune in the bags are redeemed as if used, so nobody clicks hundreds of stacks.
class WcmeScrollRedeemer final : public PlayerScript
{
public:
    WcmeScrollRedeemer() : PlayerScript("WcmeScrollRedeemer", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Redeem(player);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        player->WcmeScrollRedeemTimer += diff;
        if (player->WcmeScrollRedeemTimer < 2000)
            return;
        player->WcmeScrollRedeemTimer = 0;
        Redeem(player);
    }

private:
    static void Redeem(Player* player)
    {
        if (!player || !player->IsInWorld())
            return;
        std::vector<std::pair<uint8, uint8>> found;
        auto check = [&found](Item* item, uint8 bag, uint8 slot)
        {
            if (item && !item->IsInTrade() &&
                RedeemToken(sSpellMgr->GetSpellInfo(uint32(item->GetTemplate()->Spells[0].SpellId))))
                found.emplace_back(bag, slot);
        };
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
            check(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), INVENTORY_SLOT_BAG_0, slot);
        for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
            if (Bag* container = player->GetBagByPos(bag))
                for (uint32 slot = 0; slot < container->GetBagSize(); ++slot)
                    check(container->GetItemByPos(uint8(slot)), bag, uint8(slot));
        if (found.empty())
            return;

        uint32 total = 0;
        for (auto const& [bag, slot] : found)
        {
            Item* item = player->GetItemByPos(bag, slot);
            if (!item)
                continue;
            SpellInfo const* redeem = sSpellMgr->GetSpellInfo(uint32(item->GetTemplate()->Spells[0].SpellId));
            std::optional<ScrollToken> const token = RedeemToken(redeem);
            if (!token)
                continue;
            uint32 const count = item->GetCount();
            uint32 const amount = RedeemAmount(redeem) * count;
            player->DestroyItem(bag, slot, true);
            SetScrolls(player, *token, ScrollCounts(player, token->Spec)[token->Kind] + amount);
            total += count;
        }
        if (total)
            ChatHandler(player->GetSession()).PSendSysMessage("Scrolls of Fortune redeemed: {}.", total);
    }
};

'@ + $items) 'AscensionWildcardItems in AscensionWildcard.cpp'

$register = "    new AscensionWildcard::AscensionWildcardItems();`n"
Edit-Core $file $register ($register + "    new AscensionWildcard::WcmeScrollRedeemer();`n") 'the AscensionWildcardItems registration'
