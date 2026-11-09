# Fits the pinned mod-ollama-chat module to the CoA core.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Fit mod-ollama-chat to the CoA core (its WorldSession::IsHeadless is IsBot here)
Write-Host "Patch: Fit mod-ollama-chat to the CoA core (its WorldSession::IsHeadless is IsBot here)"
& {
$file = 'core/modules/mod-ollama-chat/src/mod-ollama-chat_world.cpp'
$text = Get-Content $file -Raw
if ($text -notmatch 'session->IsHeadless\(\)') { throw 'mod-ollama-chat changed: IsHeadless call not found' }
Set-Content $file ($text -replace 'session->IsHeadless\(\)', 'session->IsBot()') -NoNewline
}

# ---- Less bot chat in raids and dungeons (OllamaChat.RaidChatterPct / DungeonChatterPct, 100 = unchanged)
Write-Host "Patch: Less bot chat in raids and dungeons (OllamaChat.RaidChatterPct, OllamaChat.DungeonChatterPct)"
& {
$src = 'core/modules/mod-ollama-chat/src'
# Event lines (kills, loot, deaths), random chatter and replies to other speakers are kept only this share of the time
# inside a raid or dungeon. Answers to a real player speaking straight to a bot are never dropped.
$header = @'
#pragma once
#include "Config.h"
#include "Map.h"
#include "Player.h"
#include "Random.h"

inline bool OllamaQuietHere(Player* bot)
{
    Map* map = bot ? bot->GetMap() : nullptr;
    if (!map)
        return false;
    uint32 pct = 100;
    if (map->IsRaid())
        pct = sConfigMgr->GetOption<uint32>("OllamaChat.RaidChatterPct", 100);
    else if (map->IsDungeon())
        pct = sConfigMgr->GetOption<uint32>("OllamaChat.DungeonChatterPct", 100);
    return pct < 100 && urand(1, 100) > pct;
}
'@
Set-Content "$src/mod-ollama-chat_quiet.h" ($header.Replace("`r`n", "`n") + "`n") -NoNewline
$edits = @(
    @{ File = 'mod-ollama-chat_events.cpp'; Include = '#include "mod-ollama-chat_governor.h"'
       Old = "        if (botChance == 0 || urand(1, 100) > botChance)`n            continue;`n"
       New = "        if (botChance == 0 || urand(1, 100) > botChance)`n            continue;`n        if (OllamaQuietHere(bot))`n            continue;`n" },
    @{ File = 'mod-ollama-chat_random.cpp'; Include = '#include "mod-ollama-chat_governor.h"'
       Old = "        if (g_DisableRepliesInCombat && bot->IsInCombat())`n            continue;`n`n        const uint64_t rawGuid"
       New = "        if (g_DisableRepliesInCombat && bot->IsInCombat())`n            continue;`n`n        if (OllamaQuietHere(bot))`n            continue;`n`n        const uint64_t rawGuid" },
    @{ File = 'mod-ollama-chat_handler.cpp'; Include = '#include "mod-ollama-chat_personality.h"'
       Old = "        const bool directAddress =`n            OllamaIsDirectAddress(bot, player, sourceLocal, trimmedMsg, senderIsBot, scopeKey);`n"
       New = "        const bool directAddress =`n            OllamaIsDirectAddress(bot, player, sourceLocal, trimmedMsg, senderIsBot, scopeKey);`n        if (!directAddress && OllamaQuietHere(bot))`n            continue;`n" }
)
foreach ($edit in $edits) {
    $file = Join-Path $src $edit.File
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    foreach ($anchor in $edit.Include, $edit.Old) {
        if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "mod-ollama-chat changed: anchor not found in $($edit.File)" }
    }
    $text = $text.Replace($edit.Include, $edit.Include + "`n#include `"mod-ollama-chat_quiet.h`"").Replace($edit.Old, $edit.New)
    Set-Content $file $text -NoNewline
}
}
