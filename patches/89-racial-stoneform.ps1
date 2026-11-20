# Dwarf Stoneform is stronger (James, 21 November). Its 8-second buff (65116, and the classless copy 1165116 Wildcard
# Dwarves have, which gave only +10% armour) now gives +20% armour, 20% less chance to be critically hit (unchanged)
# and 8% less damage from spells (every magic school). The cleanse part (20594 / 1120594: poisons, diseases and bleeds
# removed at once) is unchanged. James asked for a resistance increase worth about 8% less spell damage: a percentage
# of resistance does nothing for the many characters with none, so it is a straight 8%. The client patch shows the new
# numbers and says what it does (client-patch/racials.py). Spell data loads once, at server start.
# Run by the build from the workspace root. Throws if the anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Stoneform gives +20% armour and 8% less spell damage"
& {
$file = 'core/src/server/game/Spells/SpellInfoCorrections.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "void SpellMgr::LoadSpellInfoCorrections()`n{`n    uint32 oldMSTime = getMSTime();`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: LoadSpellInfoCorrections was not found' }
$fix = @'

    // Wildcard: Dwarf Stoneform's buff, both copies: +20% armour, 20% less chance to be critically hit (as it was) and
    // 8% less damage from every magic school.
    ApplySpellFix({ 65116, 1165116 }, [](SpellInfo* spellInfo)
    {
        spellInfo->Effects[EFFECT_0].BasePoints = 19; // +20% armour (the die adds 1)
        SpellEffectInfo& spell = spellInfo->Effects[EFFECT_2];
        spell.Effect = SPELL_EFFECT_APPLY_AURA;
        spell.ApplyAuraName = SPELL_AURA_MOD_DAMAGE_PERCENT_TAKEN;
        spell.BasePoints = -9; // -8%
        spell.DieSides = 1;
        spell.MiscValue = SPELL_SCHOOL_MASK_MAGIC;
        spell.TargetA = SpellImplicitTargetInfo(TARGET_UNIT_CASTER);
    });
'@
Set-Content $file $text.Replace($anchor, $anchor + $fix.Replace("`r`n", "`n")) -NoNewline
}
