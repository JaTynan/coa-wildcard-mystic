# Mystic Enchant costs in steps (James, 24 November): learning enchants should be cheap to start, so anyone can try
# it from level 1 with a few Marks of Ascension, and then stay reasonable instead of rising forever.
#
# Learning an enchant into the collection costs 1 Mystic Extract. Extracts come from two places, and both got dearer
# with every use, without end:
#   1. Altar levels. Each reforge adds altar progress (60 uncommon, 80 rare, 100 epic, 200 legendary); each altar
#      level gives 1 extract. The core's points per level grow with the level (the first reforge completes level 0,
#      then about 360 points at level 1, 660 at level 20, 1,860 at level 100), so every extract needs more reforges
#      than the last.
#   2. Buying one with Marks of Ascension (item 375250), only while holding none: 1,000 marks at altar level 0,
#      +200 per level, up to 5,000.
# This makes both a step table, each read from worldserver.conf (see server-settings.txt):
#   Wildcard.MysticAltarLevelSteps = "0:60 1:120 5:240 10:400 20:640"   points per altar level, from that level up
#   Wildcard.MysticExtractMarkSteps = "0:100 5:250 10:500 20:1000"  marks for one extract, from that level up
# Each pair is "from altar level : amount"; the last pair holds for every level above it. An empty or unreadable
# value keeps the core's own curve. Read once, at the first use after start-up.
# Characters keep their saved altar points. Their level is worked out again from the new steps at their next
# reforge, so anyone the new steps put higher gains those levels and their extracts, at most 5 per reforge (the
# core drops extracts that do not fit in the bags, after saving the level; the points stay, so nothing is lost).
# Run by the build from the workspace root, after the *.patch files. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host 'Patch: Mystic Enchant costs in steps (Wildcard.MysticAltarLevelSteps, Wildcard.MysticExtractMarkSteps)'
& {
$file = 'core/src/server/coa/AscensionMysticEnchantRules.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"Log.h`"`n"
$purchase = @'
std::uint32_t ExtractPurchaseCost(std::uint32_t altarLevel)
{
    return std::min<std::uint32_t>(altarLevel * 200 + 1000, 5000);
}
'@
$progress = @'
std::uint64_t LevelProgress(std::uint32_t level)
{
    if (level == 0)
        return 1;
'@
$gain = @'
    std::uint32_t const before = progress.Level;
    while (LevelProgress(progress.Level) <= progress.Points)
        ++progress.Level;
'@
$purchase = $purchase.Replace("`r`n", "`n")
$progress = $progress.Replace("`r`n", "`n")
$gain = $gain.Replace("`r`n", "`n")
foreach ($anchor in @($include, $purchase, $progress, $gain)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) {
        throw "Core changed: AscensionMysticEnchantRules.cpp has no single: $($anchor.Split("`n")[0])"
    }
}
$helpers = @'

namespace
{
// Wildcard (patch 42): a step table "from:amount from:amount ...", sorted by level. Empty when unset or unreadable.
std::vector<std::pair<std::uint32_t, std::uint32_t>> WcmeSteps(char const* option)
{
    std::vector<std::pair<std::uint32_t, std::uint32_t>> steps;
    std::string const value = sConfigMgr->GetOption<std::string>(option, "", false);
    std::size_t start = 0;
    while (start < value.size())
    {
        std::size_t const end = std::min(value.find(' ', start), value.size());
        std::string const token = value.substr(start, end - start);
        start = end + 1;
        if (token.empty())
            continue;
        std::size_t const colon = token.find(':');
        char* fromEnd = nullptr;
        char* amountEnd = nullptr;
        unsigned long const from = colon == std::string::npos ? 0 : std::strtoul(token.c_str(), &fromEnd, 10);
        unsigned long const amount = colon == std::string::npos ? 0 :
            std::strtoul(token.c_str() + colon + 1, &amountEnd, 10);
        // Both numbers must fill their side of the colon exactly ("x:50" or "0:120,5:240" are refused).
        bool const exact = colon != std::string::npos && colon > 0 && fromEnd == token.c_str() + colon &&
            amountEnd == token.c_str() + token.size() && amountEnd != token.c_str() + colon + 1;
        if (!exact || !amount || amount > 1000000 || from > 100000)
        {
            LOG_ERROR("server.loading", "{}: cannot read '{}', using the core's own curve", option, value);
            return {};
        }
        steps.emplace_back(std::uint32_t(from), std::uint32_t(amount));
    }
    std::sort(steps.begin(), steps.end());
    return steps;
}

// The amount for an altar level: the step with the highest "from" not above the level (the first step below it).
std::uint32_t WcmeStepAt(std::vector<std::pair<std::uint32_t, std::uint32_t>> const& steps, std::uint32_t level)
{
    std::uint32_t amount = steps.front().second;
    for (auto const& [from, value] : steps)
        if (from <= level)
            amount = value;
    return amount;
}
}

'@
$newPurchase = @'
std::uint32_t ExtractPurchaseCost(std::uint32_t altarLevel)
{
    // Wildcard (patch 42): marks for one extract, in steps (Wildcard.MysticExtractMarkSteps).
    static std::vector<std::pair<std::uint32_t, std::uint32_t>> const steps = WcmeSteps("Wildcard.MysticExtractMarkSteps");
    if (!steps.empty())
        return WcmeStepAt(steps, altarLevel);
    return std::min<std::uint32_t>(altarLevel * 200 + 1000, 5000);
}
'@
$newProgress = @'
std::uint64_t LevelProgress(std::uint32_t level)
{
    // Wildcard (patch 42): the total points that complete this altar level, adding a step amount per level
    // (Wildcard.MysticAltarLevelSteps). The core compares it with the character's saved total.
    static std::vector<std::pair<std::uint32_t, std::uint32_t>> const steps = WcmeSteps("Wildcard.MysticAltarLevelSteps");
    if (!steps.empty())
    {
        std::uint64_t total = 0;
        for (std::uint32_t each = 0; each <= level; ++each)
            total += WcmeStepAt(steps, each);
        return total;
    }
    if (level == 0)
        return 1;
'@
$text = $text.Replace($include, $include + "#include `"Config.h`"`n#include <utility>`n#include <vector>`n")
$text = $text.Replace($purchase, $helpers.Replace("`r`n", "`n").TrimStart("`n") + $newPurchase.Replace("`r`n", "`n"))
$text = $text.Replace($progress, $newProgress.Replace("`r`n", "`n"))
# At most 5 altar levels per reforge: the core saves the level before handing out its extracts, and anything that
# does not fit in the bags is lost. Points are kept, so a character the new steps put far ahead catches up over a
# few reforges instead of losing extracts at once.
$newGain = @'
    std::uint32_t const before = progress.Level;
    while (LevelProgress(progress.Level) <= progress.Points && progress.Level - before < 5) // Wildcard (patch 42)
        ++progress.Level;
'@
$text = $text.Replace($gain, $newGain.Replace("`r`n", "`n"))
Set-Content $file $text -NoNewline
}
