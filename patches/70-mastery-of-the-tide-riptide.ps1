# Mastery of the Tide (Mystic Enchants 1574368 and 274948): Chain Heal no longer uses up your Riptide on its first
# target; the 25% Riptide bonus still applies. Done in the core's Chain Heal script, which removes Riptide itself.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Mastery of the Tide keeps Riptide"
& {
$file = 'core/src/server/scripts/Spells/spell_shaman.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "                // Consume it`n                GetHitUnit()->RemoveAura(aurEff->GetBase());`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'spell_shaman.cpp Chain Heal Riptide anchor not found exactly once' }
$text = $text.Replace($anchor, "                // Consume it`n                if (!GetCaster()->HasAura(1574368) && !GetCaster()->HasAura(274948))`n                    GetHitUnit()->RemoveAura(aurEff->GetBase());`n")
Set-Content $file $text -NoNewline
}
