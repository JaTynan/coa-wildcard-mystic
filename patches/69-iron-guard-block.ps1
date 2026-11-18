# Iron Guard (Mystic Enchant 1181340): a successful block of a spell also takes 15% (the enchant's own value) off the
# damage that gets through. Melee and ranged blocks are already handled by the release core itself (Unit.cpp,
# "Ascension Iron Guard"), so this patch only covers blocked spells; an earlier version also did melee, which would have
# applied it twice. Done where the core works out the blocked amount, because no script hook sees a block before the
# damage is dealt.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Iron Guard block reduction"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"

$spell = "                    if (damage < int32(damageInfo->blocked))`n                        damageInfo->blocked = uint32(damage);`n"
if (([regex]::Matches($text, [regex]::Escape($spell))).Count -ne 1) { throw 'Unit.cpp spell block anchor not found exactly once' }
$spellAdd = "                    if (AuraEffect const* ironGuard = victim->GetAuraEffect(1181340, EFFECT_0); ironGuard && damage > int32(damageInfo->blocked))`n                        damageInfo->blocked += uint32(damage - int32(damageInfo->blocked)) * uint32(std::max(0, ironGuard->GetAmount())) / 100;`n" + $spell
$text = $text.Replace($spell, $spellAdd)
Set-Content $file $text -NoNewline
}
