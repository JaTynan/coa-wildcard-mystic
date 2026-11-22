# An alt bot learns from a class book that is out nearby, whoever summoned it (James, issue #233 part B, 22 November:
# while levelling in Manastorm, a dungeon or the open world a player brings out the book, and the bots should use it
# as the players do). SQUID already lets an alt bring out its OWN book after a level up (AiPlayerbot.CoaPets.AutoBooks,
# off by default); this adds the other case and does not need the bot to own a book. Every 30 seconds, in a calm
# moment (alive, out of combat, not in flight, not in a battleground or arena), a Wildcard Hero alt looks for one of
# the class books SQUID knows (its own companion list, category "class") within 30 yards. If that book can teach it
# something it can afford, it learns from it through SQUID's own train code; otherwise it says and does nothing.
# Only alts (bots with a real player as master), never random bots, and only classless Heroes. Needs patch 97's
# setting on, or the book offers a Hero bot nothing. Off at 0 (AiPlayerbot.WildcardAltsUseNearbyClassBook), read once
# at start-up, so the 750 random bots pay one cheap check per update and nothing else.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: alt bots learn from a class book nearby (AiPlayerbot.WildcardAltsUseNearbyClassBook)"
$file = 'core/modules/mod-playerbots/src/Ai/Coa/Social/CoaPet.cpp'

Edit-Core $file @'
#include "GameTime.h"

'@ @'
#include "GameTime.h"
#include "AscensionWildcard.h"
#include "Config.h"
#include "Trainer.h"

'@ 'the GameTime.h include in CoaPet.cpp'

Edit-Core $file @'
void Ask(Player* bot, Category category)
{
    std::lock_guard<std::mutex> guard(autoLock);
    bookUses.try_emplace(bot->GetGUID().GetRawValue(), BookUse{category, 0});
}
'@ @'
void Ask(Player* bot, Category category)
{
    std::lock_guard<std::mutex> guard(autoLock);
    bookUses.try_emplace(bot->GetGUID().GetRawValue(), BookUse{category, 0});
}

// Wildcard (patch 98): an alt learns from a class book that is out nearby, whoever summoned it.
std::unordered_map<uint64, uint64> nextNearbyBookMs;  // alt -> its next look around (map threads, under autoLock)
constexpr uint64 NEARBY_BOOK_CHECK_MS = 30 * IN_MILLISECONDS;
constexpr float NEARBY_BOOK_YARDS = 30.0f;

bool NearbyBookEnabled()
{
    static bool const enabled = sConfigMgr->GetOption<bool>("AiPlayerbot.WildcardAltsUseNearbyClassBook", false);
    return enabled;
}

void LearnFromNearbyBook(PlayerbotAI* botAI, Player* bot)
{
    if (!AscensionWildcard::IsClasslessHero(bot))
        return;
    uint64 const now = GameTime::GetGameTimeMS().count();
    {
        std::lock_guard<std::mutex> guard(autoLock);
        uint64& next = nextNearbyBookMs[bot->GetGUID().GetRawValue()];
        if (now < next)
            return;
        next = now + NEARBY_BOOK_CHECK_MS;
    }
    if (!bot->IsAlive() || bot->IsInCombat() || bot->IsInFlight() || bot->InBattleground() || bot->InArena())
        return;

    for (ObjectGuid const& guid : botAI->GetAiObjectContext()->GetValue<GuidVector>("nearest npcs")->Get())
    {
        Creature* book = botAI->GetCreature(guid);
        Companion const* companion = book ? ByEntry(book->GetEntry()) : nullptr;
        if (!companion || companion->category != CAT_CLASS || !book->IsAlive() ||
            bot->GetDistance(book) > NEARBY_BOOK_YARDS)
            continue;

        // Only when the book has something for this bot that it can pay for: no chatter otherwise.
        Trainer::Trainer const* trainer = Trainer::GetTrainerFor(book, bot);
        if (!trainer)
            return;
        bool teachable = false;
        for (Trainer::Spell const& spell : trainer->GetSpells())
            if (spell.MoneyCost <= bot->GetMoney() && trainer->CanTeachSpell(bot, &spell))
            {
                teachable = true;
                break;
            }
        if (!teachable)
            return;

        TrainerAction action(botAI);
        action.LearnFrom(book);
        return;
    }
}
'@ 'the Ask helper in CoaPet.cpp'

Edit-Core $file @'
void Tick(PlayerbotAI* botAI)
{
    if (!sPlayerbotAIConfig.coaPetsAutoBooks)
        return;
'@ @'
void Tick(PlayerbotAI* botAI)
{
    // Wildcard (patch 98): a class book out nearby, with or without SQUID's own automatic books.
    if (NearbyBookEnabled())
        if (Player* alt = botAI ? botAI->GetBot() : nullptr; alt && alt->IsInWorld() && botAI->IsAltBot())
            LearnFromNearbyBook(botAI, alt);
    if (!sPlayerbotAIConfig.coaPetsAutoBooks)
        return;
'@ 'the start of CoaPet::Tick'
