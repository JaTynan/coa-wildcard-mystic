# Wildcard progression: class training, skill card drops, Scrolls of Fortune.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Free class training on Wildcard (Wildcard.FreeClassTraining, off at 0)
Write-Host "Patch: Free class training on Wildcard (Wildcard.FreeClassTraining, off at 0)"
& {
$file = 'core/src/server/coa/AscensionWildcard.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$head = "uint32 TrainerPrice(uint32 spellId, uint32 level)`n{`n"
if (-not $text.Contains($head)) { throw 'CoA changed: TrainerPrice in AscensionWildcard.cpp was not found' }
$free = $head + "    if (sConfigMgr->GetOption<bool>(`"Wildcard.FreeClassTraining`", false))`n        return 0;`n"
Set-Content $file $text.Replace($head, $free) -NoNewline
}

# ---- Wildcard skill card drops weighted by quality (Wildcard.CardDropQualityWeights, off when empty)
Write-Host "Patch: Wildcard skill card drops weighted by quality (Wildcard.CardDropQualityWeights, off when empty)"
& {
$file = 'core/src/server/coa/AscensionWildcard.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$old = @'
std::optional<std::uint32_t> RollCardDrop(Tables const& tables, RandomBelow const& random)
{
    if (tables.DropItems.empty() || random(1000) >= CARD_DROP_CHANCE_PER_MILLE)
        return std::nullopt;
    return tables.DropItems[random(std::uint32_t(tables.DropItems.size()))];
}
'@
$new = @'
std::optional<std::uint32_t> RollCardDrop(Tables const& tables, RandomBelow const& random)
{
    std::uint32_t const chance = sConfigMgr->GetOption<std::uint32_t>("Wildcard.CardDropChancePerMille", CARD_DROP_CHANCE_PER_MILLE);
    if (tables.DropItems.empty() || random(1000) >= chance)
        return std::nullopt;
    std::string const weightText = sConfigMgr->GetOption<std::string>("Wildcard.CardDropQualityWeights", "");
    std::array<std::uint32_t, SKILL_CARD_QUALITY_COUNT> weights{};
    std::size_t parsed = 0;
    for (std::string_view part : Acore::Tokenize(weightText, ',', false))
    {
        if (parsed >= weights.size())
            break;
        weights[parsed++] = Acore::StringTo<std::uint32_t>(part).value_or(0);
    }
    if (parsed != weights.size())
        return tables.DropItems[random(std::uint32_t(tables.DropItems.size()))];
    std::array<std::vector<std::uint32_t>, SKILL_CARD_QUALITY_COUNT> byQuality;
    for (std::uint32_t item : tables.DropItems)
        if (auto const card = tables.CardItems.find(item); card != tables.CardItems.end())
            if (auto const info = tables.Cards.find(card->second); info != tables.Cards.end())
                byQuality[info->second.Quality].push_back(item);
    std::uint32_t total = 0;
    for (std::size_t quality = 0; quality < byQuality.size(); ++quality)
        if (!byQuality[quality].empty())
            total += weights[quality];
    if (!total)
        return tables.DropItems[random(std::uint32_t(tables.DropItems.size()))];
    std::uint32_t pick = random(total);
    for (std::size_t quality = 0; quality < byQuality.size(); ++quality)
    {
        if (byQuality[quality].empty())
            continue;
        if (pick < weights[quality])
            return byQuality[quality][random(std::uint32_t(byQuality[quality].size()))];
        pick -= weights[quality];
    }
    return tables.DropItems[random(std::uint32_t(tables.DropItems.size()))];
}
'@
$old = $old.Replace("`r`n", "`n")
if (-not $text.Contains($old)) { throw 'CoA changed: RollCardDrop in AscensionWildcard.cpp was not found' }
if (-not $text.Contains('#include "StringConvert.h"')) { $text = $text.Replace('#include "StringFormat.h"', "#include `"StringConvert.h`"`n#include `"StringFormat.h`"") }
Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n")) -NoNewline
}

# ---- Scrolls of Fortune go straight to the scroll count (Wildcard.ScrollsStraightToCurrency, off when unset)
Write-Host "Patch: Scrolls of Fortune go straight to the scroll count (Wildcard.ScrollsStraightToCurrency, off when unset)"
& {
$file = 'core/src/server/coa/AscensionWildcard.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$before = 'class AscensionWildcardSpecializationCache final : public ItemScript'
$register = '    new AscensionWildcard::AscensionWildcardItems();'
foreach ($anchor in $before, $register, 'std::optional<ScrollToken> RedeemToken(SpellInfo const* spellInfo)') {
    if (-not $text.Contains($anchor)) { throw "CoA changed: '$anchor' was not found in AscensionWildcard.cpp" }
}
# Caches and claims hand out Scroll of Fortune items that each have to be right-clicked to count (the redeem
# spell). Do that for the player: any scroll item that lands in their bags is turned into its count a moment
# later (next update, so the code that stored it is finished with the item).
$class = @'
class AscensionWildcardScrollsToCurrency final : public PlayerScript
{
public:
    AscensionWildcardScrollsToCurrency() : PlayerScript("AscensionWildcardScrollsToCurrency",
        { PLAYERHOOK_ON_STORE_NEW_ITEM }) { }

    void OnPlayerStoreNewItem(Player* player, Item* item, uint32) override
    {
        if (!player || !item || !RedeemToken(sSpellMgr->GetSpellInfo(uint32(item->GetTemplate()->Spells[0].SpellId))))
            return;
        if (!sConfigMgr->GetOption<bool>("Wildcard.ScrollsStraightToCurrency", false))
            return;
        ObjectGuid const itemGuid = item->GetGUID();
        player->m_Events.AddEventAtOffset([player, itemGuid]()
        {
            Item* held = player->GetItemByGuid(itemGuid);
            if (!held)
                return;
            SpellInfo const* redeem = sSpellMgr->GetSpellInfo(uint32(held->GetTemplate()->Spells[0].SpellId));
            std::optional<ScrollToken> const token = RedeemToken(redeem);
            if (!token)
                return;
            uint32 count = held->GetCount();
            uint32 const redeemed = count;
            player->DestroyItemCount(held, count, true);
            SetScrolls(player, *token, ScrollCounts(player, token->Spec)[token->Kind] + RedeemAmount(redeem) * redeemed);
        }, Milliseconds(1));
    }
};

'@
$text = $text.Replace($before, $class.Replace("`r`n", "`n") + $before)
$text = $text.Replace($register, $register + "`n    new AscensionWildcard::AscensionWildcardScrollsToCurrency();")
Set-Content $file $text -NoNewline
}
