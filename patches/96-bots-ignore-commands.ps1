# Random bots stop answering bot commands whispered by someone who doesn't command them. SquidBots Lite asks every
# "... Bot" in your party "co ?" (for the role icons) and "wcr" / "talents spec list" (for the specs panel); in a
# battleground those are random bots of the raid, not yours. SQUID's live chat took each command for small talk from
# a stranger and whispered a canned line back ("?", "what do you mean", "ok", "sorry, was afk"), and as no real answer
# came the addon asked again every 30 seconds (21 November, Zor in a battleground). Now a whisper that is a bot command
# gets no answer from a random bot that isn't yours. Your own bots and alts answer as before; a whisper in words still
# gets the live chat's reply.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: random bots ignore bot commands from players who don't command them"
$social = 'core/modules/mod-playerbots/src/Ai/Coa/Social'

$header = @'
#pragma once
// Wildcard (patch 96): is a whisper a bot command? Used to keep random bots quiet when someone who doesn't command
// them sends one (an addon's "co ?", "stats", "wcr"...). Words a player might whisper in conversation ("who", "help",
// "go") count only alone; the one-letter commands ("c", "e", "s", "t", "u"...) only alone or with an item link.
#include <set>
#include <string>

namespace WildcardBotCommand
{
inline std::string Trim(std::string const& s)
{
    size_t const b = s.find_first_not_of(" \t\r\n");
    if (b == std::string::npos)
        return "";
    return s.substr(b, s.find_last_not_of(" \t\r\n") - b + 1);
}

inline bool Looks(std::string const& message)
{
    std::string text = Trim(message);
    for (char& c : text)
        if (c >= 'A' && c <= 'Z')
            c = char(c - 'A' + 'a');
    if (text.empty())
        return false;

    size_t const space = text.find(' ');
    std::string const first = text.substr(0, space);
    std::string const rest = space == std::string::npos ? "" : Trim(text.substr(space + 1));

    // An order for one role of the group: "@tank attack", "@heal follow".
    if (first.size() > 1 && first[0] == '@')
        return true;

    // Commands no one says in conversation: the first word is enough ("co ?", "nc -coa auto pull", "wcr spec 2").
    static std::set<std::string> const commands = {
        "co", "nc", "wcr", "talents", "autogear", "stats", "quests", "rti", "rtsc", "summon", "release", "follow",
        "stay", "attack", "flee", "runaway", "grind", "disperse", "mount", "bank", "gb", "gbank", "trainer", "drop",
        "revive", "teleport", "taxi", "repair", "maintenance", "outfit", "glyphs", "formation", "stance", "position",
        "cast", "castnc", "sendmail", "equip", "use", "destroy", "buff", "drink", "calc", "tame", "ginvite", "debug",
        "cdebug", "rebuff", "dc"};
    if (commands.count(first))
        return true;

    // Commands of two words.
    static char const* const phrases[] = {
        "give leader", "focus heal", "reset botai", "reset ai", "save mana", "max dps", "loot all", "add all loot",
        "pvp stats", "rpg status", "rpg do quest", "move from group", "pull rti", "pull back", "tank attack",
        "enter vehicle", "leave vehicle", "wait for attack time", "open items", "unlock items", "unlock traded item",
        "remove glyph", "equip upgrade", "glyph equip", "pet attack", "loot pet", "guild promote", "guild demote",
        "guild remove", "guild leave", "accept *", "cancel "};
    for (char const* phrase : phrases)
    {
        std::string const p = phrase;
        if (text.compare(0, p.size(), p) == 0 && (text.size() == p.size() || p.back() == ' ' || text[p.size()] == ' '))
            return true;
    }

    // One-letter commands (bags, equip, use, sell, buy, trade...): alone, with an item link, or "s gray" / "s *".
    static std::set<std::string> const letters = {"c", "e", "u", "ue", "s", "b", "r", "t", "nt", "q", "qi", "de", "ll",
                                                  "ss"};
    if (letters.count(first))
        return rest.empty() || rest.find("|h") != std::string::npos || rest == "*" || rest == "gray" || rest == "grey";

    // Words a player might also say: a command only when alone.
    static std::set<std::string> const alone = {"who", "help", "go", "talk", "chat", "ready", "home", "pull", "tank",
                                                "pet", "range", "dps", "attackers", "target", "flag", "ra", "cs",
                                                "items", "inv", "inventory", "spells", "emblems", "los", "wipe",
                                                "accept", "leave", "rep", "reputation", "loot", "share", "spell",
                                                "log", "invite", "emote", "alt", "mission", "wildcard"};
    return rest.empty() && alone.count(first) != 0;
}
}  // namespace WildcardBotCommand
'@
Set-Content "$social/WildcardBotCommand.h" $header.Replace("`r`n", "`n") -NoNewline

Edit-Core "$social/CoaLive.cpp" "#include `"CoaLive.h`"`n" "#include `"CoaLive.h`"`n#include `"WildcardBotCommand.h`"`n" 'the CoaLive.h include'

$taken = @'
    if (!TakesWhisper(Enabled(), IsRealPlayer(from), IsRandom(to), master && master->GetGUID() == from->GetGUID()))
        return false;

'@
Edit-Core "$social/CoaLive.cpp" $taken ($taken + @'
    // Wildcard: a bot command from someone who doesn't command this bot (SquidBots Lite asking the party's bots
    // "co ?" in a battleground) gets no answer at all, rather than a canned "?" or "what do you mean".
    if (WildcardBotCommand::Looks(msg))
        return true;

'@) 'the whisper check in CoaLive::OnWhisper'
