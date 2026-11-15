# Two small core hooks for Mystic Enchants (the scripts are in mystic-enchants-scripts.patch):
#   Hot Hands (979765 / 1575104): lets Pyroblast count toward Hot Streak, as the core already allows for the other
#     Hot Hands spell (275397). sql/enchants/026 adds Pyroblast to Hot Streak's spell_proc mask.
#   Temporal Shift (977972): a Temporal Blast cancelled part-way stores the time already spent (Stored Time, 9990018,
#     client-patch/custom_spells.py), which the next Temporal Blast's cast time loses.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Anchored($file, $edits) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    foreach ($edit in $edits) {
        if (([regex]::Matches($text, [regex]::Escape($edit[0]))).Count -ne 1) { throw "$file anchor not found exactly once: $($edit[0])" }
        $text = $text.Replace($edit[0], $edit[1])
    }
    Set-Content $file $text -NoNewline
}

Write-Host "Patch: Mystic Enchant core hooks (Hot Hands, Temporal Shift)"
Edit-Anchored 'core/src/server/scripts/Spells/spell_mage.cpp' @(
    ,@('GetTarget()->HasAura(SPELL_MAGE_HOT_HANDS);',
       'GetTarget()->HasAura(SPELL_MAGE_HOT_HANDS) || GetTarget()->HasAura(979765) || GetTarget()->HasAura(1575104);')
)
Edit-Anchored 'core/src/server/game/Spells/Spell.cpp' @(
    ,@("        case SPELL_STATE_PREPARING:`n            CancelGlobalCooldown();`n            SendCastResult(SPELL_FAILED_INTERRUPTED);`n",
       "        case SPELL_STATE_PREPARING:`n            CancelGlobalCooldown();`n            SendCastResult(SPELL_FAILED_INTERRUPTED);`n" +
       "            if (m_timer > 0 && m_casttime > m_timer && m_caster->HasAura(977972) && m_spellInfo->SpellName[0] &&`n" +
       "                std::string_view(m_spellInfo->SpellName[0]) == `"Temporal Blast`")`n" +
       "                m_caster->CastCustomSpell(9990018, SPELLVALUE_BASE_POINT0, -(m_casttime - m_timer), m_caster, true);`n")
)
