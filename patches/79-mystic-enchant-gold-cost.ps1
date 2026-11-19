# Cheaper gold prices for applying Mystic Enchants (James, 19 November: about 1-2% of the price; with no source of
# Mystic Runes, gold is the only way to apply an enchant, and it cost tens to hundreds of gold).
# The core's own gold prices for applying an enchant from the collection (to a slot, or as a scroll item) are 30g
# uncommon, 60g rare, 100g epic and 250g legendary and artifact, used whenever the client config doesn't name a price;
# nothing names one, so the client could show other amounts than the server charged. This sends all ten prices in the
# client config, scaled by Wildcard.MysticEnchantGoldCostPct (worldserver.conf, percent of the core's prices, default 1:
# 30s, 60s, 1g, 2g 50s, 2g 50s; at least 1 copper). The client shows the same prices the server charges. Mystic Rune
# prices and the 2g 50s scroll reforge are unchanged. Read each time the config is built (log-in, and every enchant
# action). Run by the build from the workspace root, after the *.patch files. Throws if an anchor is gone. Listed in
# CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host 'Patch: Mystic Enchant gold prices (Wildcard.MysticEnchantGoldCostPct)'
& {
$file = 'core/src/server/coa/AscensionMysticEnchant.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$extract = "            config.Integers.emplace_back(name, 1);`n}`n"
$register = "    RegisterAscensionClientConfig(&AscensionMysticEnchant::AppendExtractCosts);`n"
foreach ($anchor in @($extract, $register)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) {
        throw "Core changed: AscensionMysticEnchant.cpp has no single: $($anchor.Split("`n")[0])"
    }
}
$code = @'

// Wildcard: gold prices for applying enchants from the collection, as a percent of the core's own
// (Wildcard.MysticEnchantGoldCostPct, default 1), named in the client config so the client shows what is charged.
void WcmeAppendGoldCosts(AscensionClientConfig& config)
{
    struct TierPrice { char const* Tier; int32 Copper; };
    static constexpr std::array<TierPrice, 5> CORE_PRICES = { { { "UNCOMMON", 300000 }, { "RARE", 600000 },
        { "EPIC", 1000000 }, { "LEGENDARY", 2500000 }, { "ARTIFACT", 2500000 } } };
    float const pct = std::max(0.0f, sConfigMgr->GetOption<float>("Wildcard.MysticEnchantGoldCostPct", 1.0f, false));
    auto const set = [&config](std::string const& name, int32 value)
    {
        auto const itr = std::find_if(config.Integers.begin(), config.Integers.end(),
            [&name](std::pair<std::string, int32> const& entry) { return entry.first == name; });
        if (itr != config.Integers.end())
            itr->second = value;
        else
            config.Integers.emplace_back(name, value);
    };
    for (TierPrice const& price : CORE_PRICES)
    {
        // At least 1 copper: a price of 0 counts as "not for sale" in the enchant rules.
        int32 const copper = std::max<int32>(1, int32(std::lround(double(price.Copper) * pct / 100.0)));
        set(std::string("CONFIG_MYSTIC_ENCHANT_COLLECTION_REFORGE_") + price.Tier + "_MONEY_COST", copper);
        set(std::string("CONFIG_MYSTIC_ENCHANT_COLLECTION_REFORGE_ITEM_") + price.Tier + "_MONEY_COST", copper);
    }
}
'@
$text = $text.Replace($extract, $extract + $code.Replace("`r`n", "`n"))
$text = $text.Replace($register, $register + "    RegisterAscensionClientConfig(&AscensionMysticEnchant::WcmeAppendGoldCosts);`n")
if (-not $text.Contains("#include <cmath>`n")) { $text = $text.Replace("#include <algorithm>`n", "#include <algorithm>`n#include <array>`n#include <cmath>`n") }
Set-Content $file $text -NoNewline
}
