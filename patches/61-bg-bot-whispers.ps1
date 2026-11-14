# Bots in a battleground stop whispering "I have a master already". In a battleground (or arena) raid the random
# bots answer to their own leader, so every whisper a player (or an addon such as SquidBots Lite polling its bots)
# sends one of them got that reply, again and again. Now they refuse quietly; what is allowed is unchanged.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if the anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: no 'I have a master already' whispers from battleground bots"
& {
$file = 'core/modules/mod-playerbots/src/Mgr/Security/PlayerbotSecurity.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    PlayerbotAI* fromBotAI = GET_PLAYERBOT_AI(from);`n    if (silent || (fromBotAI && !IsSelfBot(from)))`n        return false;`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'SQUID changed: the silent check in PlayerbotSecurity::CheckLevelFor was not found' }
$add = @'
    // Wildcard: in a battleground the raid's bots answer to their own leader; refuse without a whisper.
    if (reason == PLAYERBOT_DENY_NOT_YOURS && bot->InBattleground())
        return false;

'@
Set-Content $file $text.Replace($anchor, $anchor + $add.Replace("`r`n", "`n")) -NoNewline
}
