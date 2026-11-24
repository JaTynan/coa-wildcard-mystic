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
        // A known opener always gets its cooldown back; without one (after a relog), only the versions it knows.
        if ((opener && spellId != opener) || (!opener && !player->HasSpell(spellId)) || player->HasSpellCooldown(spellId))
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

# ---- Demonic Persistence (276506, issue #149; the Epic Mystic Enchant of the same spell too)
Write-Host "Patch: Demonic Persistence sacrifices the lowest-health Wild Imp on Incinerate and Mind Blast"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# CoA's own rule (coa_mystic_enchant_proc, unchanged) fires 276508 when Incinerate or Mind Blast is cast. 276508 is a
# "script spell": in the game data its effects only stand in for Ascension's server code (a hidden marker aura, the
# demon buff 276509, and the explosion 276511 centred on the caster). So it gave the demon a buff with no sacrifice,
# exploded around the warlock, and killed no imp. This script replaces those stand-ins with the tooltip's rules:
#   1. No living Wild Imp from Hand of Gul'dan (creatures 855350 and 855352) of the caster's: nothing happens.
#   2. Otherwise the one with the least health is sacrificed (equal health: the one closest to expiring). It casts the
#      explosion 276511 at itself (Fire, 8 yd, the warlock's spell power and kill credit) and dies.
#   3. The warlock gains a stack of 276513 (up to 4, 20 sec): Hand of Gul'dan's imps last 1 sec longer per stack
#      (game data, the same way Master Summoner lengthens them). The demon gains a stack of 276509 (+20% damage).
#   4. Every Wild Imp from Hand of Gul'dan the warlock has, and every one summoned while the stacks last, gets 276512
#      at the same number of stacks for the time the stacks have left (+20% damage per stack).
#   5. "Deteriorate over time": every Wild Imp from Hand of Gul'dan summoned by a warlock with the talent carries
#      990142, Ascension's own deterioration for this talent's Legendary version, at a fixed 4% of its health a second.
#      The longest an imp can live is 21 sec (12 base, +5 Master Summoner, +4 at 4 stacks), so at most 84% is lost: it
#      never dies of this alone, and the oldest imp is reliably the weakest (rule 2). Our copy ignores immunities,
#      cannot crit and deals fixed damage, so the rate is steady.
# 276509, 276512 and 990142 are given working data in sql/enchants/140-talent-fixes.sql. Bound to 276508 there too.
$class = @'
// Wildcard: Demonic Persistence (issue #149).
#include "AllCreatureScript.h"
#include "TemporarySummon.h"
#include <limits>
#include <vector>

constexpr uint32 WCME_DP_EXPLOSION = 276511;
constexpr uint32 WCME_DP_DEMON_DAMAGE = 276509;
constexpr uint32 WCME_DP_IMP_DAMAGE = 276512;
constexpr uint32 WCME_DP_STACKS = 276513;
constexpr uint32 WCME_DP_TALENT = 276506;
constexpr uint32 WCME_DP_DETERIORATION = 990142;

static bool WcmeIsHandOfGuldanImp(Unit const* unit)
{
    return unit && unit->IsInWorld() && unit->IsAlive() && unit->GetTypeId() == TYPEID_UNIT &&
        (unit->GetEntry() == 855350 || unit->GetEntry() == 855352);
}

static uint32 WcmeTimeLeft(Unit* unit)
{
    TempSummon* summon = unit->ToTempSummon();
    return summon ? summon->GetTimer() : std::numeric_limits<uint32>::max();
}

// Rule 4: the imp's damage stacks follow its owner's stacks of Demonic Persistence, and end with them.
static void WcmeEmpowerImp(Unit* owner, Unit* imp)
{
    Aura const* stacks = owner->GetAura(WCME_DP_STACKS);
    if (!stacks || stacks->GetDuration() <= 0)
        return;
    Aura* aura = imp->GetAura(WCME_DP_IMP_DAMAGE);
    if (!aura)
        aura = imp->AddAura(WCME_DP_IMP_DAMAGE, imp);
    if (!aura)
        return;
    aura->SetStackAmount(stacks->GetStackAmount());
    aura->SetMaxDuration(stacks->GetDuration());
    aura->SetDuration(stacks->GetDuration());
}

class spell_wcme_demonic_persistence_talent : public SpellScript
{
    PrepareSpellScript(spell_wcme_demonic_persistence_talent);

    void PreventTrigger(SpellEffIndex effIndex)
    {
        PreventHitDefaultEffect(effIndex);  // the stand-in demon buff and the explosion around the caster
    }

    void PreventMarker(SpellEffIndex /*effIndex*/)
    {
        PreventHitAura();  // the stand-in hidden marker aura
    }

    void HandleCast()
    {
        Unit* owner = GetCaster();
        if (!owner)
            return;
        std::vector<Unit*> const minions(owner->m_Controlled.begin(), owner->m_Controlled.end());
        Unit* imp = nullptr;
        for (Unit* minion : minions)
            if (WcmeIsHandOfGuldanImp(minion) && (!imp || minion->GetHealth() < imp->GetHealth() ||
                (minion->GetHealth() == imp->GetHealth() && WcmeTimeLeft(minion) < WcmeTimeLeft(imp))))
                imp = minion;
        if (!imp)
            return;  // rule 1
        imp->CastSpell(imp, WCME_DP_EXPLOSION, true, nullptr, nullptr, owner->GetGUID());  // rule 2
        imp->KillSelf(false);
        owner->CastSpell(owner, WCME_DP_STACKS, true);  // rule 3
        owner->CastSpell(owner, WCME_DP_DEMON_DAMAGE, true);
        for (Unit* minion : minions)  // rule 4
            if (WcmeIsHandOfGuldanImp(minion))
                WcmeEmpowerImp(owner, minion);
    }

    void Register() override
    {
        OnEffectLaunch += SpellEffectFn(spell_wcme_demonic_persistence_talent::PreventTrigger, EFFECT_ALL,
            SPELL_EFFECT_TRIGGER_SPELL);
        OnEffectLaunchTarget += SpellEffectFn(spell_wcme_demonic_persistence_talent::PreventTrigger, EFFECT_ALL,
            SPELL_EFFECT_TRIGGER_SPELL);
        OnEffectHit += SpellEffectFn(spell_wcme_demonic_persistence_talent::PreventTrigger, EFFECT_ALL,
            SPELL_EFFECT_TRIGGER_SPELL);
        OnEffectHitTarget += SpellEffectFn(spell_wcme_demonic_persistence_talent::PreventTrigger, EFFECT_ALL,
            SPELL_EFFECT_TRIGGER_SPELL);
        OnEffectHitTarget += SpellEffectFn(spell_wcme_demonic_persistence_talent::PreventMarker, EFFECT_0,
            SPELL_EFFECT_APPLY_AURA);
        OnCast += SpellCastFn(spell_wcme_demonic_persistence_talent::HandleCast);
    }
};

// Rules 4 and 5 for each new Wild Imp from Hand of Gul'dan.
class wcme_demonic_persistence_new_imps : public AllCreatureScript
{
public:
    wcme_demonic_persistence_new_imps() : AllCreatureScript("wcme_demonic_persistence_new_imps") { }

    void OnCreatureAddWorld(Creature* creature) override
    {
        if (!creature->IsSummon() || (creature->GetEntry() != 855350 && creature->GetEntry() != 855352))
            return;
        Unit* owner = creature->GetOwner();
        if (!owner)
            return;
        if (owner->HasAura(WCME_DP_TALENT))  // rule 5
            creature->AddAura(WCME_DP_DETERIORATION, creature);
        if (owner->HasAura(WCME_DP_STACKS))  // rule 4
            WcmeEmpowerImp(owner, creature);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_demonic_persistence_talent);`n    new wcme_demonic_persistence_new_imps();`n")
Set-Content $file $text -NoNewline
}

# ---- Ability companions (talent companions batch 4: Thrust, Two-Handed Weapon Mastery)
Write-Host "Patch: passives held by an ability (wcme_spell_companion): while a player knows the ability, they have the passive"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# Some abilities keep part of their effect in a hidden passive that Ascension's server gave to whoever knew the
# ability (Thrust's armour-ignore, 274337). A plain link needs an aura to hang off, and an active ability has none;
# this core has no spell_learn_spell table either. So: a table, wcme_spell_companion (ability_spell, passive_spell,
# flags), read at start-up. While a player knows ability_spell they have the aura passive_spell, and lose it when
# they no longer do. flags 1: only while no weapon is in the off hand (Two-Handed Weapon Mastery: a single two-handed
# weapon, not with Titan's Grip). A passive with an item requirement is held only while the gear fits it; a linked
# aura could not do this, because the core takes it off with the weapon and never puts it back.
# Checked at login, when a listed ability is learnt or forgotten, and when gear changes for a player who knows a
# gear-dependent ability; each check runs 200 ms later, so the change has settled. The aura is not saved: login
# puts it back. Empty table (the default): nothing happens. Rows in sql/enchants/144-ability-companions.sql.
$class = @'
// Wildcard: passives held by an ability (wcme_spell_companion).
#include "DatabaseEnv.h"
#include "ObjectAccessor.h"
#include "WorldScript.h"
#include <unordered_map>
#include <unordered_set>

struct WcmeSpellCompanion
{
    uint32 Ability;
    uint32 Passive;
    uint32 Flags;
};

constexpr uint32 WCME_COMPANION_NO_OFFHAND_WEAPON = 1;

std::vector<WcmeSpellCompanion> WcmeSpellCompanions;
std::unordered_set<uint32> WcmeSpellCompanionAbilities;
std::vector<uint32> WcmeGearDependentAbilities;

void WcmeSyncSpellCompanions(Player* player)
{
    if (!player || !player->IsInWorld() || WcmeSpellCompanions.empty())
        return;
    // One passive may be held by several abilities: hold it if any of them allows it.
    std::unordered_map<uint32, bool> wanted;
    for (WcmeSpellCompanion const& row : WcmeSpellCompanions)
    {
        bool hold = player->HasSpell(row.Ability);
        if (hold && (row.Flags & WCME_COMPANION_NO_OFFHAND_WEAPON) && player->GetWeaponForAttack(OFF_ATTACK, true))
            hold = false;
        if (hold)
            if (SpellInfo const* info = sSpellMgr->GetSpellInfo(row.Passive))
                if (info->EquippedItemClass != -1 && !player->HasItemFitToSpellRequirements(info))
                    hold = false;
        wanted[row.Passive] = wanted[row.Passive] || hold;
    }
    for (auto const& [passive, hold] : wanted)
    {
        if (hold && !player->HasAura(passive))
            player->CastSpell(player, passive, true);
        else if (!hold && player->HasAura(passive))
            player->RemoveAurasDueToSpell(passive);
    }
}

void WcmeQueueSpellCompanionSync(Player* player)
{
    ObjectGuid const guid = player->GetGUID();
    player->m_Events.AddEventAtOffset([guid]()
    {
        if (Player* target = ObjectAccessor::FindPlayer(guid))
            WcmeSyncSpellCompanions(target);
    }, 200ms);
}

class wcme_spell_companions_world : public WorldScript
{
public:
    wcme_spell_companions_world() : WorldScript("wcme_spell_companions_world", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        WcmeSpellCompanions.clear();
        WcmeSpellCompanionAbilities.clear();
        WcmeGearDependentAbilities.clear();
        if (!WorldDatabase.Query("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() "
            "AND TABLE_NAME = 'wcme_spell_companion'"))
            return;
        if (QueryResult result = WorldDatabase.Query("SELECT ability_spell, passive_spell, flags FROM wcme_spell_companion"))
            do
            {
                Field* fields = result->Fetch();
                WcmeSpellCompanion row{ fields[0].Get<uint32>(), fields[1].Get<uint32>(), fields[2].Get<uint32>() };
                SpellInfo const* passive = sSpellMgr->GetSpellInfo(row.Passive);
                if (!passive || !sSpellMgr->GetSpellInfo(row.Ability))
                {
                    LOG_ERROR("sql.sql", "wcme_spell_companion: ability {} or passive {} does not exist", row.Ability, row.Passive);
                    continue;
                }
                WcmeSpellCompanions.push_back(row);
                WcmeSpellCompanionAbilities.insert(row.Ability);
                if ((row.Flags & WCME_COMPANION_NO_OFFHAND_WEAPON) || passive->EquippedItemClass != -1)
                    WcmeGearDependentAbilities.push_back(row.Ability);
            } while (result->NextRow());
        LOG_INFO("server.loading", ">> Loaded {} ability companions (wcme_spell_companion)", WcmeSpellCompanions.size());
    }
};

class wcme_spell_companions_player : public PlayerScript
{
public:
    wcme_spell_companions_player() : PlayerScript("wcme_spell_companions_player", { PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_FORGOT_SPELL, PLAYERHOOK_ON_EQUIP, PLAYERHOOK_ON_UNEQUIP_ITEM }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (!WcmeSpellCompanions.empty())
            WcmeQueueSpellCompanionSync(player);
    }

    void OnPlayerLearnSpell(Player* player, uint32 spellId) override
    {
        if (WcmeSpellCompanionAbilities.count(spellId))
            WcmeQueueSpellCompanionSync(player);
    }

    void OnPlayerForgotSpell(Player* player, uint32 spellId) override
    {
        if (WcmeSpellCompanionAbilities.count(spellId))
            WcmeQueueSpellCompanionSync(player);
    }

    void OnPlayerEquip(Player* player, Item* /*item*/, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        GearChanged(player);
    }

    void OnPlayerUnequip(Player* player, Item* /*item*/) override
    {
        GearChanged(player);
    }

private:
    // Gear changes often (bots dress themselves): only check players who know a gear-dependent ability.
    static void GearChanged(Player* player)
    {
        for (uint32 ability : WcmeGearDependentAbilities)
            if (player->HasSpell(ability))
            {
                WcmeQueueSpellCompanionSync(player);
                return;
            }
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_spell_companions_world();`n    new wcme_spell_companions_player();`n")
Set-Content $file $text -NoNewline
}
