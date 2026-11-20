# Dwarf Stoneform is stronger (James, 21 November). Its buff (65116, and the classless copy 1165116 Wildcard Dwarves
# have, which gave only +10% armour) lasts 10 sec (was 8) and gives +20% armour, 20% less chance to be critically hit
# (unchanged) and resistance to every magic school worth about 8% less spell damage: 0.54 per level (32 at level 60).
# Under CoA's Classic+ combat rules (every fight with both sides at level 60 or below) a resistance R resists R x 0.15 /
# the attacker's level, so 0.54 per level is 8% against an enemy of the Dwarf's own level, a little less against
# higher ones. Stoneform's cooldown is 2 min on both copies (the classless 1120594 had 1.5 min); its cleanse (poisons,
# diseases and bleeds removed at once) is unchanged. The client patch shows it all (client-patch/racials.py). Spell
# data loads once, at server start. Run by the build from the workspace root. Throws if the anchor is gone. Listed in
# CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Stoneform gives +20% armour and magic resistance for 10 sec, 2 min cooldown"
& {
$file = 'core/src/server/game/Spells/SpellInfoCorrections.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "void SpellMgr::LoadSpellInfoCorrections()`n{`n    uint32 oldMSTime = getMSTime();`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: LoadSpellInfoCorrections was not found' }
$fix = @'

    // Wildcard: Dwarf Stoneform, both copies. The buff lasts 10 sec and gives +20% armour, 20% less chance to be
    // critically hit (as it was) and 0.54 resistance per level to every magic school (about 8% resisted against an
    // enemy of the same level under the Classic+ rules); the cleanse has a 2 min cooldown.
    ApplySpellFix({ 65116, 1165116 }, [](SpellInfo* spellInfo)
    {
        spellInfo->DurationEntry = sSpellDurationStore.LookupEntry(1); // 10 sec
        spellInfo->Effects[EFFECT_0].BasePoints = 19; // +20% armour (the die adds 1)
        SpellEffectInfo& resistance = spellInfo->Effects[EFFECT_2];
        resistance.Effect = SPELL_EFFECT_APPLY_AURA;
        resistance.ApplyAuraName = SPELL_AURA_MOD_RESISTANCE;
        resistance.BasePoints = -1; // with the die, 0 plus the level part
        resistance.DieSides = 1;
        resistance.RealPointsPerLevel = 0.54f;
        resistance.MiscValue = SPELL_SCHOOL_MASK_MAGIC;
        resistance.TargetA = SpellImplicitTargetInfo(TARGET_UNIT_CASTER);
    });
    ApplySpellFix({ 20594, 1120594 }, [](SpellInfo* spellInfo)
    {
        spellInfo->RecoveryTime = 120000; // 2 min
    });
'@
Set-Content $file $text.Replace($anchor, $anchor + $fix.Replace("`r`n", "`n")) -NoNewline
}
