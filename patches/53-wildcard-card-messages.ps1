# Wildcard skill cards: plain-English messages for card refusals the client only shows as a raw code.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA change that breaks a patch
# stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Ability and talent cards before the four starting abilities are learned
Write-Host "Patch: Ability and talent cards explain they need the four starting abilities"
& {
$file = 'core/src/server/coa/AscensionWildcard.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    char const* result = CheckSetRollCard(Loaded, Slots(player), cards, Collection(player), position, request.Card);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: SetRollCard in AscensionWildcard.cpp was not found' }
# CheckSetRollCard answers SET_SKILL_CARD_UNKNOWN while fewer than the four starting abilities are learned (straight
# after a prestige, say), and the client shows only that code. The answer to the client is unchanged; the player
# also gets the reason on screen and in chat.
$add = @'
    std::vector<Slot> const learned = Slots(player);
    if (std::string_view(result) == "SET_SKILL_CARD_UNKNOWN" && std::size_t(std::count_if(learned.begin(), learned.end(),
            [](Slot const& slot) { return slot.EntryId != 0; })) < STARTING_ABILITY_COUNT)
    {
        std::string_view const message = "Please roll your four starting abilities first, then set your ability and talent cards.";
        ChatHandler handler(player->GetSession());
        handler.SendNotification(message);
        handler.SendSysMessage(message);
    }
'@
Set-Content $file $text.Replace($anchor, $anchor + $add.Replace("`r`n", "`n")) -NoNewline
}
