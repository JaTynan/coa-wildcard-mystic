# A Wildcard Hero who rolled Auto Shot keeps it (James, 24 November: Zimply, a Hero with the Auto Shot card, had no
# automatic ranged attack; `.learn 75` brought it back until the next log-in).
#
# Cause, shown on the live data: the Auto Shot card (965202) is a hidden placeholder; the core's Wildcard code
# teaches the real Auto Shot (75) from it at every log-in (AscensionWildcard.cpp, ENTRY_SPELLS). The subclass module
# then removes 75 at the same log-in: its ForgetStrayBorrowedCopies (mod-subclass, Subclass.cpp) treats Auto Shot on
# any non-hunter as a stray spell borrowed from a hunter subclass unless the character's own class is listed as
# granting it, and the Wildcard card is not on that list. The character's saved spells showed 75 added by `.learn`
# and deleted again after the next log-in.
# The fix: the subclass module also leaves Auto Shot alone while the character holds the Auto Shot card. Nothing else
# in the module changes. A Hero who lost it gets it back at the next log-in (the core teaches it from the card).
#
# Second part (James, 24 November: close out the card's promise): the card's tooltip says Auto Shot is 33% faster.
# The core's Wildcard grant only teaches Auto Shot, so a Hero shot at the plain weapon speed. Hunters get the 33%
# from a hidden passive, Auto Shot Haste (34082: 33% ranged attack speed). The core's own grant table now teaches it
# with Auto Shot from the card, and removes it with Auto Shot when the card goes (AscensionWildcard.cpp,
# ENTRY_SPELLS). "Scales with Ranged Attack Power" needs nothing: Auto Shot's weapon damage already includes it.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host 'Patch: a Wildcard Hero with the Auto Shot card keeps Auto Shot (mod-subclass)'
& {
$file = 'core/modules/mod-subclass/src/Subclass.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "        !IsBorrowedSpell(player, StockAutoShot) && !OwnClassGrants(player, StockAutoShot))`n        stray.push_back(StockAutoShot);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) {
    throw "Module changed: Subclass.cpp ForgetStrayBorrowedCopies' Auto Shot check was not found exactly once"
}
$replacement = "        !IsBorrowedSpell(player, StockAutoShot) && !OwnClassGrants(player, StockAutoShot) &&`n" +
    "        !player->HasSpell(965202)) // Wildcard (patch 41): the Wildcard Auto Shot card teaches Auto Shot`n" +
    "        stray.push_back(StockAutoShot);`n"
$text = $text.Replace($anchor, $replacement)
Set-Content $file $text -NoNewline
}

Write-Host 'Patch: the Wildcard Auto Shot card also teaches Auto Shot Haste (34082, 33% ranged attack speed)'
& {
$file = 'core/src/server/coa/AscensionWildcard.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    { AUTO_SHOT_ENTRY_SPELL, { AUTO_SHOT_SPELL } },`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) {
    throw "Core changed: AscensionWildcard.cpp's Auto Shot row in ENTRY_SPELLS was not found exactly once"
}
$text = $text.Replace($anchor, "    { AUTO_SHOT_ENTRY_SPELL, { AUTO_SHOT_SPELL, 34082 } }, // Wildcard (patch 41): + Auto Shot Haste`n")
Set-Content $file $text -NoNewline
}
