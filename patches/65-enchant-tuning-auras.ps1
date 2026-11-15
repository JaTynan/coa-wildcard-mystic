# Lets the Mystic Enchant spells that use Ascension's PvE / PvP damage auras (341 / 322) count. The core applies those
# auras only for an allowlist of reviewed spells; this adds:
#   PvE (341): Pack Tactics 979038 (Beast and Blade, +15% pet damage) and Demonic Persistence 990138 (empowered demon,
#              +20% damage, misc value 0 meaning every school).
#   PvP (322): Pack Tactics 979038 (10% against players), Demonic Influence 965314 (-33% against players) and Gurubashi
#              Berserker 983151 (-1% per stack against players).
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Mystic Enchant PvE / PvP damage auras"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$edits = @(
    @('id == 271942 || id == 275097;', 'id == 271942 || id == 275097 || id == 979038 || id == 990138;'),
    @('(id == 271942 && effect->GetMiscValue() == 0)', '((id == 271942 || id == 990138) && effect->GetMiscValue() == 0)'),
    @('(IsAscensionPvpTuningAura(effect->GetId()) || effect->GetId() == 275097) &&',
      '(IsAscensionPvpTuningAura(effect->GetId()) || effect->GetId() == 275097 || effect->GetId() == 979038 ||
                effect->GetId() == 965314 || effect->GetId() == 983151) &&')
)
foreach ($edit in $edits) {
    if (([regex]::Matches($text, [regex]::Escape($edit[0]))).Count -ne 1) { throw "Unit.cpp anchor not found exactly once: $($edit[0])" }
    $text = $text.Replace($edit[0], $edit[1])
}
Set-Content $file $text -NoNewline
}
