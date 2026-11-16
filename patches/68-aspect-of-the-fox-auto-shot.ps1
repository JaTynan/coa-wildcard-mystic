# Aspect of the Fox (Mystic Enchant 1143164, its taught aspect 1143166): Auto Shot keeps firing while you move, as its
# tooltip says. The aspect's own aura (313) already covers Steady Shot through its family mask; Auto Shot (75) has no
# family flags, so the core never matched it. This adds Auto Shot for anyone with the aspect up.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Aspect of the Fox Auto Shot while moving"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    if (!info)`n        return false;`n    // All movement gates must agree on the active Manastorm mixture.`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Unit.cpp CanCastSpellWhileMoving anchor not found exactly once' }
$text = $text.Replace($anchor, "    if (!info)`n        return false;`n    if (info->Id == 75 && HasAura(1143166))`n        return true;`n    // All movement gates must agree on the active Manastorm mixture.`n")
Set-Content $file $text -NoNewline
}
