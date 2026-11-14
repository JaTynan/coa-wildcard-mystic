# Talent fixes: talents whose Ascension tooltip does more than the AzerothCore data or scripts. Each talent is an
# aura script registered in the shared script loader (from 40-battlegrounds.ps1) and switched on by a row in
# sql/enchants/140-talent-fixes.sql. Run by the build from the workspace root. Throws if an anchor is gone.
# Listed in CHANGES.md. One GitHub issue per talent.
$ErrorActionPreference = 'Stop'

# ---- Backdraft (47258-47260, issue #152) and the Mystic Enchant Immolating Backdraft (271548)
Write-Host "Patch: Backdraft procs from Conflagrate, Shadowburn, Shadowfury and Mind Blast (and Immolate with Immolating Backdraft)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# AzerothCore's Backdraft procs only from Conflagrate (spell_proc family mask). Ascension's tooltip: "When you cast
# Conflagrate, Mind Blast, Shadowfury or Shadowburn"; Mind Blast is a Priest spell, so one family mask cannot cover
# it. The SQL row drops the family filter and this check picks the spells by family flags (every rank and copy).
$class = @'
// Wildcard: Backdraft triggers (issue #152).
class spell_wcme_backdraft : public AuraScript
{
    PrepareAuraScript(spell_wcme_backdraft);

    bool CheckProc(ProcEventInfo& eventInfo)
    {
        SpellInfo const* spell = eventInfo.GetSpellInfo();
        if (!spell)
            return false;
        flag96 const& flags = spell->SpellFamilyFlags;
        if (spell->SpellFamilyName == SPELLFAMILY_WARLOCK)
        {
            if ((flags[0] & 0x80) || (flags[1] & (0x800000 | 0x1000))) // Shadowburn; Conflagrate, Shadowfury
                return true;
            return (flags[0] & 0x4) && GetTarget()->HasAura(271548);   // Immolate, with Immolating Backdraft
        }
        return spell->SpellFamilyName == SPELLFAMILY_PRIEST && (flags[0] & 0x2000); // Mind Blast
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_wcme_backdraft::CheckProc);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"SpellInfo.h`"`n#include `"SpellScript.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_backdraft);`n")
Set-Content $file $text -NoNewline
}
