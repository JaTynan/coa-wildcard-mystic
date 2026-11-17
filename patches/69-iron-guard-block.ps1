# Iron Guard (Mystic Enchant 1181340): a successful block also takes 15% (the enchant's own value) off the damage that
# gets through, for melee and ranged attacks and for blocked spells. Done where the core works out the blocked amount,
# because no script hook sees a block before the damage is dealt.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Iron Guard block reduction"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"

$melee = "            // double blocked amount if block is critical`n            if (damageInfo->target->isBlockCritical())`n                damageInfo->blocked_amount += damageInfo->blocked_amount;`n"
if (([regex]::Matches($text, [regex]::Escape($melee))).Count -ne 1) { throw 'Unit.cpp melee block anchor not found exactly once' }
$meleeAdd = $melee + "            if (AuraEffect const* ironGuard = damageInfo->target->GetAuraEffect(1181340, EFFECT_0))`n            {`n                uint32 total = 0;`n                for (uint8 i = 0; i < MAX_ITEM_PROTO_DAMAGES; ++i)`n                    total += damageInfo->damages[i].damage;`n                if (total > damageInfo->blocked_amount)`n                    damageInfo->blocked_amount += (total - damageInfo->blocked_amount) * uint32(std::max(0, ironGuard->GetAmount())) / 100;`n            }`n"
$text = $text.Replace($melee, $meleeAdd)

$spell = "                    if (damage < int32(damageInfo->blocked))`n                        damageInfo->blocked = uint32(damage);`n"
if (([regex]::Matches($text, [regex]::Escape($spell))).Count -ne 1) { throw 'Unit.cpp spell block anchor not found exactly once' }
$spellAdd = "                    if (AuraEffect const* ironGuard = victim->GetAuraEffect(1181340, EFFECT_0); ironGuard && damage > int32(damageInfo->blocked))`n                        damageInfo->blocked += uint32(damage - int32(damageInfo->blocked)) * uint32(std::max(0, ironGuard->GetAmount())) / 100;`n" + $spell
$text = $text.Replace($spell, $spellAdd)
Set-Content $file $text -NoNewline
}
