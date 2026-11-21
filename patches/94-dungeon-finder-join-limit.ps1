# Find a Group did nothing (James, 21 November). The client asks to join with every dungeon in the chosen type: a
# Random Classic Dungeon request carries 52 to 126 dungeons, depending on level. The core reads at most 50 and throws
# the whole request away above that ("PacketArrayMaxCapacityException ... CMSG_LFG_JOIN" in Server.log), so the
# player is never queued and sees nothing. The packet's own count is one byte, so 255 is the most the client can send.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: the dungeon finder accepts up to 255 dungeons in one join request"
Edit-Core 'core/src/server/game/Server/Packets/LFGPackets.h' '        Array<uint32, 50> Slots;' `
    '        Array<uint32, 255> Slots;   // Wildcard: Random Classic Dungeon sends up to 126' 'the LFGJoin slot limit'
