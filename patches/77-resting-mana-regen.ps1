# Mana regenerates faster while resting (James, 19 November: triple). "Resting" is the game's own split: no spell cast in
# the last 5 seconds, so it covers standing around, drinking and travelling, and not casting in a fight. While casting
# (the 5-second rule) nothing changes, so combat balance stays as it was.
# Wildcard.RestingManaRate (worldserver.conf, default 3; 1 = the stock rate) multiplies the out-of-casting regeneration
# the server keeps for each player. It is the same number the client shows as "Mana Regen: X" (not "while casting"),
# so the character sheet and the mana bar show the tripled rate too. Read when a character's regeneration is worked
# out (log-in, stat and aura changes), so a new value applies after a restart. Run by the build from the workspace root.
# Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host 'Patch: faster mana regeneration while resting (Wildcard.RestingManaRate)'
& {
$file = 'core/src/server/game/Entities/Unit/StatSystem.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    SetStatFloatValue(UNIT_FIELD_POWER_REGEN_FLAT_MODIFIER + AsUnderlyingType(POWER_MANA), power_regen_mp5 + power_regen);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: Player::UpdateManaRegen in StatSystem.cpp was not found' }
if (-not $text.Contains("#include `"Config.h`"`n")) { throw 'Core changed: StatSystem.cpp no longer includes Config.h' }
$new = @'
    // Wildcard: resting (no cast in the last 5 sec) regenerates Wildcard.RestingManaRate times faster (default 3).
    float const restingManaRate = std::max(0.0f, sConfigMgr->GetOption<float>("Wildcard.RestingManaRate", 3.0f, false));
    SetStatFloatValue(UNIT_FIELD_POWER_REGEN_FLAT_MODIFIER + AsUnderlyingType(POWER_MANA), (power_regen_mp5 + power_regen) * restingManaRate);

'@
Set-Content $file $text.Replace($anchor, $new.Replace("`r`n", "`n")) -NoNewline
}
