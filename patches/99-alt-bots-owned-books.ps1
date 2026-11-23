# An alt bot learns the book companions its account already owns (James, 23 November: once the Book has been bought
# on any character, a player can claim it on every alt from the vanity menu, but had to log in to each alt to do it).
# The core keeps what an account owns in account_vanity_collection (characters database) and hands an owned item to
# any character of the account for free; only the first purchase costs Bazaar Tokens. Bot sessions never load that
# collection (CoA.CollectionsForBots = 0), so an alt played as a bot never got the book and SQUID's automatic books
# (AiPlayerbot.CoaPets.AutoBooks) had nothing to bring out. Now, a minute after an alt bot comes online and every
# 10 minutes after that, while it still lacks one of the books below, one indexed query asks whether its account
# owns that book's vanity item; if so the alt learns the book's companion spell, exactly what claiming it gives.
# Nothing is bought and no currency is touched: an account that does not own a book gets nothing.
# Books (vanity item -> companion spell, from the client's vanity list): Book of Ascension 98457 -> 979602, Bloody
# Book of Ascension 499920 -> 499908, Book of Conquest 134995 / 219315 -> 105307, Book of Artisans 134987 / 750750
# -> 750750. Only alts (bots with a real player as master), never random bots. Off at 0
# (AiPlayerbot.WildcardAltsLearnOwnedBooks), read once at start-up.
# Must run after 98-alt-bots-nearby-class-book.ps1 (it anchors on that patch's lines).
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: alt bots learn the books their account owns (AiPlayerbot.WildcardAltsLearnOwnedBooks)"
$file = 'core/modules/mod-playerbots/src/Ai/Coa/Social/CoaPet.cpp'

Edit-Core $file @'
#include "Trainer.h"

'@ @'
#include "Trainer.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "WorldSession.h"

'@ 'the Trainer.h include that patch 98 adds to CoaPet.cpp'

Edit-Core $file @'
bool NearbyBookEnabled()
{
'@ @'
// Wildcard (patch 99): an alt learns the book companions its account already owns.
struct OwnedBook
{
    uint32 item;   // the vanity item an account owns (account_vanity_collection.item_id)
    uint32 spell;  // the companion spell that claiming the item gives
};
constexpr OwnedBook OWNED_BOOKS[] = {
    {98457, 979602},   // Book of Ascension
    {499920, 499908},  // Bloody Book of Ascension
    {134995, 105307},  // Book of Conquest
    {219315, 105307},  // Book of Conquest
    {134987, 750750},  // Book of Artisans
    {750750, 750750},  // Book of Artisans
};
std::unordered_map<uint64, uint64> nextOwnedBookMs;  // alt -> its next check (map threads, under autoLock)
constexpr uint64 OWNED_BOOK_FIRST_CHECK_MS = 60 * IN_MILLISECONDS;
constexpr uint64 OWNED_BOOK_CHECK_MS = 10 * 60 * IN_MILLISECONDS;

bool OwnedBooksEnabled()
{
    static bool const enabled = sConfigMgr->GetOption<bool>("AiPlayerbot.WildcardAltsLearnOwnedBooks", false);
    return enabled;
}

void LearnOwnedBooks(Player* bot)
{
    uint64 const now = GameTime::GetGameTimeMS().count();
    {
        std::lock_guard<std::mutex> guard(autoLock);
        auto const [slot, first] = nextOwnedBookMs.try_emplace(bot->GetGUID().GetRawValue(), now + OWNED_BOOK_FIRST_CHECK_MS);
        if (first || now < slot->second)
            return;
        slot->second = now + OWNED_BOOK_CHECK_MS;
    }
    WorldSession* session = bot->GetSession();
    if (!session || !session->GetAccountId())
        return;

    // Only the books this alt still lacks and this server has: an alt that has them all asks the database nothing.
    std::string items;
    for (OwnedBook const& book : OWNED_BOOKS)
        if (!bot->HasSpell(book.spell) && sSpellMgr->GetSpellInfo(book.spell))
            items += (items.empty() ? "" : ", ") + std::to_string(book.item);
    if (items.empty())
        return;

    QueryResult owned = CharacterDatabase.Query(
        "SELECT `item_id` FROM `account_vanity_collection` WHERE `account_id` = {} AND `item_id` IN ({})",
        session->GetAccountId(), items);
    if (!owned)
        return;
    do
    {
        uint32 const item = owned->Fetch()[0].Get<uint32>();
        for (OwnedBook const& book : OWNED_BOOKS)
            if (book.item == item && !bot->HasSpell(book.spell))
            {
                bot->learnSpell(book.spell);
                LOG_INFO("playerbots", "Alt bot {} learned book companion {} from its account's vanity item {}",
                         bot->GetName(), book.spell, item);
            }
    } while (owned->NextRow());
}

bool NearbyBookEnabled()
{
'@ 'the NearbyBookEnabled helper that patch 98 adds to CoaPet.cpp'

Edit-Core $file @'
    // Wildcard (patch 98): a class book out nearby, with or without SQUID's own automatic books.
'@ @'
    // Wildcard (patch 99): the books its account owns, with or without SQUID's own automatic books.
    if (OwnedBooksEnabled())
        if (Player* alt = botAI ? botAI->GetBot() : nullptr; alt && alt->IsInWorld() && botAI->IsAltBot())
            LearnOwnedBooks(alt);
    // Wildcard (patch 98): a class book out nearby, with or without SQUID's own automatic books.
'@ 'the patch 98 comment at the start of CoaPet::Tick'
