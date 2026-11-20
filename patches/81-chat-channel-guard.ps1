# A channel chat message built without a channel name no longer stops the world server. ChatHandler::BuildChatPacket
# asserted on it; SQUID's bots can build one when they answer, in the chat type they heard, a command that came from a
# channel (20 November: the server stopped on this assertion while James was in game). The message now goes out with
# an empty channel name (the client shows it without one) and the server logs which sender did it.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: channel chat without a channel name doesn't stop the server"
& {
$file = 'core/src/server/game/Chat/Chat.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "            if (chatType == CHAT_MSG_CHANNEL)`n            {`n                ASSERT(channelName.length() > 0);`n                data << channelName;`n            }`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the channel name assertion in ChatHandler::BuildChatPacket was not found exactly once' }
$fix = @'
            if (chatType == CHAT_MSG_CHANNEL)
            {
                // Wildcard: a channel message without a channel name went out instead of stopping the server.
                if (channelName.empty())
                    LOG_ERROR("misc", "BuildChatPacket: channel message without a channel name from {} ({}), sent anyway",
                        senderName, senderGUID.ToString());
                data << channelName;
            }

'@
Set-Content $file $text.Replace($anchor, $fix.Replace("`r`n", "`n")) -NoNewline
}
