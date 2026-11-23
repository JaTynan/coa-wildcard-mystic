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
Write-Host "Patch: Nemesis rank 3 lets Hand of Gul'dan be cast twice within 6 seconds in Metamorphosis before its cooldown"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
$included = "#include `"SpellScript.h`"`n"
foreach ($anchor in @($register, $loader, $included)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# The talent's cooldown cuts work from the game data (class masks). Its rank 3 bonus does not: the data holds a hidden
# proc aura (863123) and helpers, but the order of events was in Ascension's server code. The rules, from the tooltip
# ("while in Metamorphosis, Hand of Gul'dan can be cast twice within 6 sec before going on cooldown"):
#   1. A Hand of Gul'dan cast in Metamorphosis form with rank 3 opens a window: the game's own buff 863121 (6 sec,
#      the one the tooltip names) goes on, and the spell's cooldown is cleared.
#   2. A second cast of the same spell while the buff is on closes the window; its cooldown stands.
#   3. The window also closes when the buff goes for any other reason (it runs out, death, a purge) or when the
#      character leaves Metamorphosis form; then the spell's normal cooldown starts at once, as if just cast.
#   4. A second cast that was started inside the window still counts if it finishes after (the spell has a 2 sec
#      cast; without this rule it would fail "not ready", or worse count as a new first cast).
# Never more than two casts per window and cooldown: each way out of the window ends with the cooldown running.
# Casts made by a proc (triggered) are ignored. Metamorphosis form counts whichever spell gave it (Metamorphosis,
# Dark Apotheosis and the rest), as the form is what the tooltip names. Bound by sql/enchants/140-talent-fixes.sql:
# the cast script to both learnable Hand of Gul'dan versions, the window script to 863121, the form script to every
# spell that gives Metamorphosis form.
$class = @'
// Wildcard: Nemesis capstone (issue #150).
#include "SpellMgr.h"
#include <algorithm>
#include <array>

constexpr uint32 WCME_NEMESIS_RANK_3 = 63123;
constexpr uint32 WCME_NEMESIS_WINDOW = 863121;
constexpr std::array<uint32, 2> WCME_HAND_OF_GULDAN = { 954611, 2304611 };

struct WcmeNemesisState : public DataMap::Base
{
    uint32 opener = 0;       // the Hand of Gul'dan version whose cooldown the open window cleared (0 = not known)
    bool consuming = false;  // true only while the second cast takes the window buff away
    bool pending = false;    // the window ended while a Hand of Gul'dan cast was still in progress (rule 4)
};

static WcmeNemesisState* WcmeNemesis(Player* player)
{
    return player->CustomData.GetDefault<WcmeNemesisState>("WcmeNemesisState");
}

static bool WcmeIsHandOfGuldan(uint32 spellId)
{
    return std::find(WCME_HAND_OF_GULDAN.begin(), WCME_HAND_OF_GULDAN.end(), spellId) != WCME_HAND_OF_GULDAN.end();
}

// Is the character in the middle of casting the Hand of Gul'dan that opened the window (or any, if not known)?
static bool WcmeCastingHandOfGuldan(Player* player, uint32 opener)
{
    Spell const* spell = player->GetCurrentSpell(CURRENT_GENERIC_SPELL);
    return spell && spell->getState() == SPELL_STATE_PREPARING && WcmeIsHandOfGuldan(spell->GetSpellInfo()->Id) &&
        (!opener || spell->GetSpellInfo()->Id == opener);
}

// Rule 3: the normal cooldown, with every modifier the character has, as after a cast; and the client is told.
static void WcmeStartHandOfGuldanCooldown(Player* player, uint32 opener)
{
    for (uint32 spellId : WCME_HAND_OF_GULDAN)
    {
        if ((opener && spellId != opener) || !player->HasSpell(spellId) || player->HasSpellCooldown(spellId))
            continue;
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
            continue;
        player->AddSpellAndCategoryCooldowns(spellInfo, 0);
        if (uint32 const left = player->GetSpellCooldownDelay(spellId))
        {
            WorldPacket data;
            player->BuildCooldownPacket(data, SPELL_COOLDOWN_FLAG_NONE, spellId, left);
            player->SendDirectMessage(&data);
        }
    }
}

static void WcmeFinishNemesisWindow(Player* player)
{
    WcmeNemesisState* state = WcmeNemesis(player);
    uint32 const opener = state->opener;
    state->opener = 0;
    state->pending = false;
    WcmeStartHandOfGuldanCooldown(player, opener);
}

// Rule 4: while the cast started in the window is still going, wait; if it ends without being cast, rule 3.
static void WcmeWatchPendingCast(Player* player)
{
    player->m_Events.AddEventAtOffset([player]()
    {
        WcmeNemesisState* state = WcmeNemesis(player);
        if (!state->pending)
            return;  // the cast went through and counted as the second cast
        if (player->IsInWorld() && WcmeCastingHandOfGuldan(player, state->opener))
            WcmeWatchPendingCast(player);
        else
            WcmeFinishNemesisWindow(player);
    }, 250ms);
}

class spell_wcme_nemesis_hand_of_guldan : public SpellScript
{
    PrepareSpellScript(spell_wcme_nemesis_hand_of_guldan);

    void HandleAfterCast()
    {
        Player* player = GetCaster() ? GetCaster()->ToPlayer() : nullptr;
        if (!player || GetSpell()->IsTriggered())
            return;
        uint32 const spellId = GetSpellInfo()->Id;
        WcmeNemesisState* state = WcmeNemesis(player);

        if (state->pending)  // rule 4: started in the window, finished after it; its cooldown stands
        {
            state->pending = false;
            state->opener = 0;
            return;
        }
        if (player->HasAura(WCME_NEMESIS_WINDOW))  // rule 2
        {
            if (state->opener && spellId != state->opener)
                return;  // the other version: its own cooldown applies, the window stays
            state->consuming = true;
            player->RemoveAurasDueToSpell(WCME_NEMESIS_WINDOW);
            state->consuming = false;
            state->opener = 0;
            return;
        }
        // Rule 1.
        if (!player->HasAura(WCME_NEMESIS_RANK_3) || player->GetShapeshiftForm() != FORM_METAMORPHOSIS)
            return;
        player->AddAura(WCME_NEMESIS_WINDOW, player);
        if (!player->HasAura(WCME_NEMESIS_WINDOW))
            return;  // the buff did not stay on: no window, the normal cooldown stands
        state->opener = spellId;
        player->RemoveSpellCooldown(spellId, true);
    }

    void Register() override
    {
        AfterCast += SpellCastFn(spell_wcme_nemesis_hand_of_guldan::HandleAfterCast);
    }
};

class spell_wcme_nemesis_window : public AuraScript
{
    PrepareAuraScript(spell_wcme_nemesis_window);

    void AfterRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;
        WcmeNemesisState* state = WcmeNemesis(player);
        if (state->consuming || !player->IsInWorld())
            return;  // the second cast (rule 2), or logging out (the buff is saved and comes back at login)
        if (WcmeCastingHandOfGuldan(player, state->opener))
        {
            state->pending = true;  // rule 4
            WcmeWatchPendingCast(player);
            return;
        }
        WcmeFinishNemesisWindow(player);  // rule 3
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(spell_wcme_nemesis_window::AfterRemove, EFFECT_0,
            SPELL_AURA_ADD_PCT_MODIFIER, AURA_EFFECT_HANDLE_REAL);
    }
};

class spell_wcme_nemesis_form_end : public AuraScript
{
    PrepareAuraScript(spell_wcme_nemesis_form_end);

    void AfterRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        if (!target->IsPlayer() || !target->HasAura(WCME_NEMESIS_WINDOW))
            return;
        // Checked on the next update, so that one Metamorphosis form replacing another does not close the window.
        target->m_Events.AddEventAtOffset([target]()
        {
            if (target->IsInWorld() && target->HasAura(WCME_NEMESIS_WINDOW) &&
                target->GetShapeshiftForm() != FORM_METAMORPHOSIS)
                target->RemoveAurasDueToSpell(WCME_NEMESIS_WINDOW);  // rule 3, through the window script
        }, 1ms);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(spell_wcme_nemesis_form_end::AfterRemove, EFFECT_ALL,
            SPELL_AURA_MOD_SHAPESHIFT, AURA_EFFECT_HANDLE_REAL);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_nemesis_hand_of_guldan);`n    RegisterSpellScript(spell_wcme_nemesis_window);`n    RegisterSpellScript(spell_wcme_nemesis_form_end);`n")
Set-Content $file $text -NoNewline
}
