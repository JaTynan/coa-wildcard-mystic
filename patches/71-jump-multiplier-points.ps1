# Flat "jump multiplier" spell modifiers in percentage points. Ascension data writes "Chain Heal loses 20% less healing
# per jump" as a flat +20 on SPELLMOD_DAMAGE_MULTIPLIER; the core added the 20 straight onto the 0.8 multiplier, so each
# jump healed or hit about 21 times the last. Affected: Tidal Force (55198), Overflowing (273420), Transcendental
# Embrace (1583832), Booming Thunder (965305) and The Water Duke's Stolen Totem (102279-102282); no stock spell uses a
# flat modifier here. Percentage modifiers work as before.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: flat jump multiplier modifiers count as percentage points"
& {
$file = 'core/src/server/game/Spells/SpellInfo.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    float multiplier = DamageMultiplier;`n    if (Player* modOwner = (caster ? caster->GetSpellModOwner() : nullptr))`n        modOwner->ApplySpellMod(_spellInfo->Id, SPELLMOD_DAMAGE_MULTIPLIER, multiplier, spell);`n    return multiplier;`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'SpellInfo.cpp CalcDamageMultiplier anchor not found exactly once' }
$text = $text.Replace($anchor, "    float multiplier = DamageMultiplier;`n    if (Player* modOwner = (caster ? caster->GetSpellModOwner() : nullptr))`n    {`n        // CoA: flat modifiers are percentage points (0.8 + 20 = 1.0), as the Ascension data means them.`n        float points = multiplier * 100.0f;`n        modOwner->ApplySpellMod(_spellInfo->Id, SPELLMOD_DAMAGE_MULTIPLIER, points, spell);`n        multiplier = points / 100.0f;`n    }`n    return multiplier;`n")
Set-Content $file $text -NoNewline
}
