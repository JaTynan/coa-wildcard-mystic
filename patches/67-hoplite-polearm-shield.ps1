# Hoplite (Mystic Enchant 978217): lets a polearm be wielded with a shield while the enchant is on, as its tooltip says.
# The core only allows that pairing for the Guardian class; this adds the enchant next to it. The enchant's script
# (mystic-enchants-scripts.patch) puts the shield back in your bags when the enchant comes off.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Hoplite polearm and shield"
& {
$file = 'core/src/server/game/Entities/Player/Player.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    if (getClass() != CLASS_GUARDIAN || off->InventoryType != INVTYPE_SHIELD)`n        return false;`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Player.cpp CanUseTwoHandWithShield anchor not found exactly once' }
$text = $text.Replace($anchor, "    if (off->InventoryType == INVTYPE_SHIELD && main->SubClass == ITEM_SUBCLASS_WEAPON_POLEARM && HasAura(978217))`n        return true;`n" + $anchor)
Set-Content $file $text -NoNewline
}
