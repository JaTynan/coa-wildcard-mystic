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

# ---- Nemesis capstone (rank 3, 63123, issue #150)
Write-Host "Patch: Nemesis rank 3 lets Hand of Gul'dan be cast twice in Metamorphosis before its cooldown"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
$included = "#include `"SpellScript.h`"`n"
foreach ($anchor in @($register, $loader, $included)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# The talent's cooldown cuts work from the game data (class masks). Its rank 3 bonus does not: in Metamorphosis,
# Hand of Gul'dan may be cast a second time within 6 seconds before its cooldown counts. Ascension's data holds the
# pieces (a hidden proc aura 863123 and three helpers) but the order "first cast opens the window, second cast
# closes it" was in its server code. This script keeps that order with the game's own window buff (863121, 6 sec,
# the one the tooltip names) as the memory: a cast without the buff gives the buff and clears the spell's
# cooldown; a cast with the buff removes it and the cooldown stands. After the cast, so the cooldown is already
# set when it is cleared. A second, independent limit: the cooldown is cleared at most once per length of the
# spell's own cooldown, so whatever happens to the buff the talent can never give more than two casts in that
# time. One difference from the tooltip, in the player's favour: the second cast may come later than 6 seconds
# (the spell simply stays ready); the buff still shows the 6 seconds.
# Bound to both learnable versions by sql/enchants/140-talent-fixes.sql.
$class = @'
// Wildcard: Nemesis capstone (issue #150).
struct WcmeNemesisCleared : public DataMap::Base
{
    uint64 at = 0;  // game time (ms) the cooldown was last cleared for this character
};

class spell_wcme_nemesis_hand_of_guldan : public SpellScript
{
    PrepareSpellScript(spell_wcme_nemesis_hand_of_guldan);

    void HandleAfterCast()
    {
        Player* caster = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (!caster || !caster->HasAura(63123) || caster->GetShapeshiftForm() != FORM_METAMORPHOSIS)
            return;
        if (caster->HasAura(863121))
        {
            caster->RemoveAurasDueToSpell(863121);  // the second cast: its cooldown stands
            return;
        }
        SpellInfo const* spell = GetSpellInfo();
        uint64 const cooldown = spell->RecoveryTime ? spell->RecoveryTime : spell->CategoryRecoveryTime;
        uint64 const now = GameTime::GetGameTimeMS().count();
        WcmeNemesisCleared* cleared = caster->CustomData.GetDefault<WcmeNemesisCleared>("WcmeNemesisCleared");
        if (cleared->at && now - cleared->at < cooldown)
            return;                                 // already cleared once in this cooldown
        if (caster->AddAura(863121, caster))        // 6 seconds to cast it once more
        {
            cleared->at = now;
            caster->RemoveSpellCooldown(spell->Id, true);
        }
    }

    void Register() override
    {
        AfterCast += SpellCastFn(spell_wcme_nemesis_hand_of_guldan::HandleAfterCast);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_nemesis_hand_of_guldan);`n")
Set-Content $file $text -NoNewline
}
