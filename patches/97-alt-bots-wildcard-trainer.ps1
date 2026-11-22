# A Wildcard Hero bot is served the same trainer list as a Wildcard Hero player (James, issue #233, 22 November: his
# alt bots would not learn class abilities because they thought training cost money, though it is free on this
# server). A player's trainer window comes from the core's per-character lookup (Trainer::GetTrainerFor): for a
# classless Hero that is the Wildcard rank list, priced by the Wildcard price function, which returns 0 with
# Wildcard.FreeClassTraining. SQUID's train command asked for that list only for Warcraft Reborn bots; a Hero bot got
# the trainer's stock list and stock prices instead. Now a classless Hero bot is given the per-character list too.
# Other bots are unchanged. Off at 0 (AiPlayerbot.WildcardHeroesUseWildcardTrainer), read each time a bot is asked
# to train, not per tick.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Wildcard Hero bots use the Wildcard trainer list (AiPlayerbot.WildcardHeroesUseWildcardTrainer)"
$file = 'core/modules/mod-playerbots/src/Ai/Base/Actions/TrainerAction.cpp'

Edit-Core $file @'
#include "CoaAltAddon.h"

'@ @'
#include "CoaAltAddon.h"
#include "AscensionWildcard.h"
#include "Config.h"

'@ 'the CoaAltAddon.h include in TrainerAction.cpp'

Edit-Core $file @'
    return IsRebornBot(bot) ? Trainer::GetTrainerFor(npc, bot) : sObjectMgr->GetTrainer(npc->GetEntry());
'@ @'
    // Wildcard (patch 97): a classless Hero gets the per-character list too, as a Hero player does.
    bool const hero = AscensionWildcard::IsClasslessHero(bot) &&
        sConfigMgr->GetOption<bool>("AiPlayerbot.WildcardHeroesUseWildcardTrainer", false);
    return (hero || IsRebornBot(bot)) ? Trainer::GetTrainerFor(npc, bot) : sObjectMgr->GetTrainer(npc->GetEntry());
'@ 'the trainer lookup (TrainerOf) in TrainerAction.cpp'
