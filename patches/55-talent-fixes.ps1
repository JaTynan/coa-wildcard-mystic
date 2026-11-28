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

extern void (*WcmeItemAurasApplied)(Player*); // defined in Player.cpp (this patch)

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
        // A talent learnt through a classic talent tree sits in the talent map, not the spell map.
        bool hold = player->HasSpell(row.Ability) || player->HasTalent(row.Ability, player->GetActiveSpec());
        // Any off-hand weapon counts, broken or disarmed too: it is still in the hand.
        if (hold && (row.Flags & WCME_COMPANION_NO_OFFHAND_WEAPON) && player->GetWeaponForAttack(OFF_ATTACK, false))
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

// Gear-dependent passives: the core strips them on unequip, disarm and when the weapon breaks, and on the way back
// only re-adds passives in the player's own spell and talent maps. Ours are in neither, so Player.cpp calls this
// whenever it re-applies item-dependent auras (equip, disarm ending, repair, leaving a form).
bool WcmeKnowsGearDependentAbility(Player* player)
{
    for (uint32 ability : WcmeGearDependentAbilities)
        if (player->HasSpell(ability) || player->HasTalent(ability, player->GetActiveSpec()))
            return true;
    return false;
}

void WcmeOnItemDependentAurasApplied(Player* player)
{
    if (player && WcmeKnowsGearDependentAbility(player))
        WcmeQueueSpellCompanionSync(player);
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
        WcmeItemAurasApplied = &WcmeOnItemDependentAurasApplied;
        LOG_INFO("server.loading", ">> Loaded {} ability companions (wcme_spell_companion)", WcmeSpellCompanions.size());
    }
};

class wcme_spell_companions_player : public PlayerScript
{
public:
    wcme_spell_companions_player() : PlayerScript("wcme_spell_companions_player", { PLAYERHOOK_ON_LOGIN,
        PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_FORGOT_SPELL, PLAYERHOOK_ON_PLAYER_LEARN_TALENTS,
        PLAYERHOOK_ON_TALENTS_RESET, PLAYERHOOK_ON_UNEQUIP_ITEM }) { }

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

    void OnPlayerLearnTalents(Player* player, uint32 /*talentId*/, uint32 /*talentRank*/, uint32 spellId) override
    {
        if (WcmeSpellCompanionAbilities.count(spellId))
            WcmeQueueSpellCompanionSync(player);
    }

    void OnPlayerTalentsReset(Player* player, bool /*noCost*/) override
    {
        if (!WcmeSpellCompanions.empty())
            WcmeQueueSpellCompanionSync(player);
    }

    // Equipping is covered by the Player.cpp call above. Unequipping is not (the core only strips there), and a
    // free off-hand can be what makes a passive due, so moving an item to a bag checks again. Selling or
    // destroying an equipped item fires no hook: the passive then waits for the next gear change or login.
    void OnPlayerUnequip(Player* player, Item* /*item*/) override
    {
        if (WcmeKnowsGearDependentAbility(player))
            WcmeQueueSpellCompanionSync(player);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_spell_companions_world();`n    new wcme_spell_companions_player();`n")
Set-Content $file $text -NoNewline
}
& {
# The core's own re-apply of item-dependent auras tells the ability-companion code (above) to check again. A plain
# function pointer, set by that code at start-up, keeps the game library from depending on the coa one.
$file = 'core/src/server/game/Entities/Player/Player.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$head = "void Player::ApplyItemDependentAuras(Item* item, bool apply)`n{`n    if (apply)`n    {`n"
$tail = "                AddAura(spellId, this);`n        }`n    }`n    else`n        RemoveItemDependentAurasAndCasts(item);`n}`n"
foreach ($anchor in @($head, $tail)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: Player::ApplyItemDependentAuras was not found exactly once in $file" }
}
$text = $text.Replace($head, "void (*WcmeItemAurasApplied)(Player*) = nullptr; // set by the ability-companion code (patch 55)`n`n" + $head)
$text = $text.Replace($tail, "                AddAura(spellId, this);`n        }`n`n        if (WcmeItemAurasApplied)`n            WcmeItemAurasApplied(this);`n    }`n    else`n        RemoveItemDependentAurasAndCasts(item);`n}`n")
Set-Content $file $text -NoNewline
}

# ---- Capped aura extensions (talent companions batch 4: Battle Fatigue)
Write-Host "Patch: effect 173 (refresh aura) can cap the total extension of one application"
& {
# Ascension's effect 173 sets an aura's duration (second value 0) or adds to it (any other value). Its data uses
# only 0 and 1, so a second value of 2 or more now means: add, but at most that many ms in total per application of
# the aura, the way Glyph of Shred caps its Rip extensions. Each extension also raises the aura's max duration by
# the same amount, and a fresh application resets the max (Aura::RefreshTimers), so "max minus base" is what has
# been added since the aura was applied. With a cap, only the caster's own copy of the aura is extended: two
# players with the talent on one target each extend their own debuff. Battle Fatigue uses it (sql/enchants/145).
$file = 'core/src/server/game/Spells/SpellEffects.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    int32 duration = effect.MiscValueB ? aura->GetDuration() + damage : damage;`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: EffectAscensionRefreshAura's duration line was not found exactly once in $file" }
$cap = @'
    if (effect.MiscValueB > 1 && damage > 0)
    {
        aura = target->GetAura(effect.MiscValue, m_caster->GetGUID());
        if (!aura)
            return;
        int32 const base = aura->CalcMaxDuration();
        if (base <= 0)
            return;
        int32 const add = std::min<int32>(damage, base + effect.MiscValueB - aura->GetMaxDuration());
        if (add <= 0)
            return;
        aura->SetMaxDuration(aura->GetMaxDuration() + add);
        aura->SetDuration(aura->GetDuration() + add);
        return;
    }

'@
$text = $text.Replace($anchor, $cap.Replace("`r`n", "`n") + "`n" + $anchor)
Set-Content $file $text -NoNewline
}

# ---- Percent-of-damage companions (aura 354) the core does not list (talent companions batch 4: Harbinger of
#      Plague, Reave)
Write-Host "Patch: Harbinger of Plague and Reave deal their share of damage (aura 354 scripts)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# Ascension's aura 354 deals a percentage of the triggering damage as another spell. The core runs it only for its
# own list of spells (AuraEffect::CheckEffectProc and HandleAscensionPercentEventProc); for any other spell it asks
# the aura's scripts whether to proc and then does nothing. These scripts answer and do the casting, so the core's
# code is not touched. Each needs its spell_proc row and binding (sql/enchants/146).
$class = @'
static int32 WcmePercentOfDamage(uint32 damage, int32 pct)
{
    return pct <= 0 ? 0 : int32(std::min<uint64>(std::numeric_limits<int32>::max(), uint64(damage) * uint32(pct) / 100));
}

// Wildcard: Harbinger of Plague (talent 276427, companion 276433). While a Harbinger of Plague buff from Wrath is on
// you (276430 or 276432), Haunt also hits up to 10 enemies near its target for 30% of its damage (276435).
class spell_wcme_harbinger_of_plague : public AuraScript
{
    PrepareAuraScript(spell_wcme_harbinger_of_plague);

    bool CheckProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        Unit* owner = GetTarget();
        Unit* target = eventInfo.GetActionTarget();
        DamageInfo* damage = eventInfo.GetDamageInfo();
        return owner && eventInfo.GetActor() == owner && target && target != owner && damage && damage->GetDamage() &&
            aurEff->GetAmount() > 0 && (owner->HasAura(276430) || owner->HasAura(276432));
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        int32 const amount = WcmePercentOfDamage(eventInfo.GetDamageInfo()->GetDamage(), aurEff->GetAmount());
        if (amount)
            GetTarget()->CastCustomSpell(eventInfo.GetActionTarget(), 276435, &amount, nullptr, nullptr, true, nullptr, aurEff);
    }

    void Register() override
    {
        DoCheckEffectProc += AuraCheckEffectProcFn(spell_wcme_harbinger_of_plague::CheckProc, EFFECT_0, SPELL_AURA_ASCENSION_PROC_PERCENT_EVENT);
        OnEffectProc += AuraEffectProcFn(spell_wcme_harbinger_of_plague::HandleProc, EFFECT_0, SPELL_AURA_ASCENSION_PROC_PERCENT_EVENT);
    }
};

// Harbinger's Bile (276435) hits enemies around Haunt's target; from Harbinger of Plague it spares that target,
// which Haunt itself already hit ("nearby targets"). Any other use of the spell is left alone.
class spell_wcme_harbinger_bile : public SpellScript
{
    PrepareSpellScript(spell_wcme_harbinger_bile);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        SpellInfo const* from = GetTriggeringSpell();
        if (from && from->Id == 276433)
            if (Unit* primary = GetSpell()->GetOriginalTarget()) // the explicit unit is dropped for a destination spell
                targets.remove(primary);
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_wcme_harbinger_bile::FilterTargets, EFFECT_0, TARGET_UNIT_DEST_AREA_ENEMY);
    }
};

// Wildcard: Reave (280990-280997, the Hero version; its passive 280998 is held by wcme_spell_companion). Each hit adds
// Shadow damage as a share of Reave's damage, per condition met: behind the enemy (effect 0, 100%, 280999), the
// enemy below 35% health before the hit (effect 1, 125%, 281000), the enemy bleeding (effect 2, 100%, 281001). The
// conditions are the ones the core uses for the Bloodmage class's own Reave (AscensionBloodmageSecondary.cpp).
class spell_wcme_reave_passive : public AuraScript
{
    PrepareAuraScript(spell_wcme_reave_passive);

    bool CheckProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        Unit* owner = GetTarget();
        Unit* target = eventInfo.GetActionTarget();
        DamageInfo* damage = eventInfo.GetDamageInfo();
        SpellInfo const* spell = eventInfo.GetSpellInfo();
        if (!owner || eventInfo.GetActor() != owner || !target || target == owner || !damage || !damage->GetDamage() ||
            !spell || spell->Id < 280990 || spell->Id > 280997 || aurEff->GetAmount() <= 0)
            return false;
        switch (aurEff->GetEffIndex())
        {
            case EFFECT_0:
                return !target->HasInArc(float(M_PI), owner);
            case EFFECT_1:
                return (uint64(target->GetHealth()) + damage->GetDamage()) * 100 < uint64(target->GetMaxHealth()) * 35;
            default:
                return target->HasAuraState(AURA_STATE_BLEEDING);
        }
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        uint32 const trigger = GetSpellInfo()->Effects[aurEff->GetEffIndex()].TriggerSpell;
        int32 const amount = WcmePercentOfDamage(eventInfo.GetDamageInfo()->GetDamage(), aurEff->GetAmount());
        if (amount && sSpellMgr->GetSpellInfo(trigger))
            GetTarget()->CastCustomSpell(eventInfo.GetActionTarget(), trigger, &amount, nullptr, nullptr, true, nullptr, aurEff);
    }

    void Register() override
    {
        DoCheckEffectProc += AuraCheckEffectProcFn(spell_wcme_reave_passive::CheckProc, EFFECT_ALL, SPELL_AURA_ASCENSION_PROC_PERCENT_EVENT);
        OnEffectProc += AuraEffectProcFn(spell_wcme_reave_passive::HandleProc, EFFECT_ALL, SPELL_AURA_ASCENSION_PROC_PERCENT_EVENT);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_harbinger_of_plague);`n    RegisterSpellScript(spell_wcme_harbinger_bile);`n    RegisterSpellScript(spell_wcme_reave_passive);`n")
Set-Content $file $text -NoNewline
}

# ---- Talent companion scripts (talent companions batch 4, part 4: Beacon of Virtue, Holy Concentration, Pack
#      Leader, Flare Strike, Bloodletting, Corrupted Bear Form)
Write-Host "Patch: talent companion scripts (Beacon of Virtue, Holy Concentration, Pack Leader, Flare Strike, Bloodletting, Corrupted Bear Form)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# Six talents whose hidden companion or scaling lived in Ascension's own server code. The rows that hold each companion
# and give the scripts their proc rules are in sql/enchants/147-talent-companion-scripts.sql.
$class = @'
// Wildcard (patch 55, talent companions part 4): does the target carry an aura of this class family and flag
// (SpellFamilyFlags[0]) from this caster? Rend 4/0x20, Rupture 8/0x100000, Hunter's Mark 9/0x400.
static bool WcmeHasOwnFamilyAura(Unit const* target, ObjectGuid caster, uint32 family, uint32 flags0)
{
    for (auto const& [id, application] : target->GetAppliedAuras())
    {
        Aura const* aura = application->GetBase();
        SpellInfo const* info = aura->GetSpellInfo();
        if (info->SpellFamilyName == family && (info->SpellFamilyFlags[0] & flags0) && aura->GetCasterGUID() == caster)
            return true;
    }
    return false;
}

// Ascension's class-script auras (aura 112) carry a script id in MiscValue; ours read them by that id. A class mask on
// the aura effect limits it to those spells, as the core's own spell modifiers do.
static int32 WcmeClassScriptPct(Unit const* unit, int32 script, SpellInfo const* spell)
{
    int32 pct = 0;
    for (AuraEffect const* effect : unit->GetAuraEffectsByType(SPELL_AURA_OVERRIDE_CLASS_SCRIPTS))
        if (effect->GetMiscValue() == script &&
            (!effect->GetSpellInfo()->Effects[effect->GetEffIndex()].SpellClassMask || effect->IsAffectedOnSpell(spell)))
            pct += effect->GetAmount();
    return pct;
}

// The player and their party or raid members within range (the player alone when not grouped).
static std::vector<Unit*> WcmeGroupWithin(Player* player, float range)
{
    std::vector<Unit*> units{ player };
    if (Group* group = player->GetGroup())
        for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
            if (Player* member = ref->GetSource())
                if (member != player && member->IsInWorld() && member->IsAlive() && member->IsInMap(player) &&
                    member->IsWithinDistInMap(player, range))
                    units.push_back(member);
    return units;
}

// Beacon of Virtue (277680): beacons the target and up to 4 injured allies of its party near it (the most injured
// first) with 277682 for 10 sec. The heal itself is the companion's (277684, held by wcme_spell_companion). The caster
// keeps the list of what it beaconed last, so the heals reach every beacon, in a group or not, pets included.
struct WcmeBeaconTargets final : DataMap::Base
{
    std::vector<ObjectGuid> Targets;
};
constexpr char WcmeBeaconTargetsKey[] = "wcme_beacon_of_virtue_targets";

class spell_wcme_beacon_of_virtue : public SpellScript
{
    PrepareSpellScript(spell_wcme_beacon_of_virtue);

    void ClearTargets()
    {
        GetCaster()->CustomData.GetDefault<WcmeBeaconTargets>(WcmeBeaconTargetsKey)->Targets.clear();
    }

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        Unit* primary = GetExplTargetUnit();
        targets.remove_if([primary](WorldObject* object)
        {
            Unit* unit = object->ToUnit();
            return !unit || unit == primary || !unit->IsAlive() || unit->IsFullHealth();
        });
        targets.sort([](WorldObject* left, WorldObject* right)
        {
            return left->ToUnit()->GetHealthPct() < right->ToUnit()->GetHealthPct();
        });
        uint32 const others = GetSpellInfo()->MaxAffectedTargets > 1 ? GetSpellInfo()->MaxAffectedTargets - 1 : 4;
        if (targets.size() > others)
            targets.resize(others);
    }

    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        if (Unit* target = GetHitUnit())
        {
            GetCaster()->CastSpell(target, 277682, true);
            GetCaster()->CustomData.GetDefault<WcmeBeaconTargets>(WcmeBeaconTargetsKey)->Targets.push_back(target->GetGUID());
        }
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_wcme_beacon_of_virtue::FilterTargets, EFFECT_0, TARGET_UNIT_LASTTARGET_AREA_PARTY);
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_wcme_beacon_of_virtue::FilterTargets, EFFECT_1, TARGET_UNIT_LASTTARGET_AREA_PARTY);
        BeforeCast += SpellCastFn(spell_wcme_beacon_of_virtue::ClearTargets);
        OnEffectHitTarget += SpellEffectFn(spell_wcme_beacon_of_virtue::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// Beacon of Virtue's companion (277684): each hit of your Holy heals with a cast time also heals everyone carrying
// your beacon (277682) within 60 yards, other than the heal's own target, for 25% of it (277681, a plain heal).
class spell_wcme_beacon_of_virtue_heals : public AuraScript
{
    PrepareAuraScript(spell_wcme_beacon_of_virtue_heals);

    bool CheckProc(ProcEventInfo& eventInfo)
    {
        HealInfo* heal = eventInfo.GetHealInfo();
        SpellInfo const* spell = eventInfo.GetSpellInfo();
        return GetTarget()->IsPlayer() && eventInfo.GetActor() == GetTarget() && heal && heal->GetHeal() && spell &&
            spell->Id != 277681 && (spell->GetSchoolMask() & SPELL_SCHOOL_MASK_HOLY) && spell->CastTimeEntry &&
            spell->CastTimeEntry->CastTime > 0;
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        Player* player = GetTarget()->ToPlayer();
        int32 const amount = int32(uint64(eventInfo.GetHealInfo()->GetHeal()) * uint32(std::max(0, aurEff->GetAmount())) / 100);
        if (!amount)
            return;
        Unit* healed = eventInfo.GetActionTarget();
        WcmeBeaconTargets const* beacons = player->CustomData.Get<WcmeBeaconTargets>(WcmeBeaconTargetsKey);
        if (!beacons)
            return;
        std::vector<ObjectGuid> const targets = beacons->Targets;
        for (ObjectGuid const& guid : targets)
            if (Unit* unit = ObjectAccessor::GetUnit(*player, guid))
                if (unit != healed && unit->IsAlive() && unit->IsWithinDistInMap(player, 60.0f) &&
                    unit->HasAura(277682, player->GetGUID()))
                    player->CastCustomSpell(unit, 277681, &amount, nullptr, nullptr, true, nullptr, aurEff);
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_wcme_beacon_of_virtue_heals::CheckProc);
        OnEffectProc += AuraEffectProcFn(spell_wcme_beacon_of_virtue_heals::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
    }
};

// Holy Concentration's companions (966083-966085, ranks 1-3, linked to the talent ranks): Flash Heal, Greater Heal,
// Binding Heal and Circle of Healing (their proc rules) have the rank's chance to extend your Renew on you and your
// party or raid within 40 yards by 3 sec. Capped at +50% of Renew's duration per application (James, 24 November:
// the tooltip's cap value is missing from the client data); each extension raises the aura's maximum by the same
// amount, and a fresh Renew resets it, so "maximum minus base" is what has been added since it was applied.
class spell_wcme_holy_concentration_renew : public AuraScript
{
    PrepareAuraScript(spell_wcme_holy_concentration_renew);

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& /*eventInfo*/)
    {
        PreventDefaultAction();
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;
        int32 const step = std::max(0, aurEff->GetAmount()) * IN_MILLISECONDS;
        for (Unit* unit : WcmeGroupWithin(player, 40.0f))
            for (auto const& [id, application] : unit->GetAppliedAuras())
            {
                Aura* aura = application->GetBase();
                SpellInfo const* info = aura->GetSpellInfo();
                if (info->SpellFamilyName != SPELLFAMILY_PRIEST || !(info->SpellFamilyFlags[0] & 0x40) ||
                    !info->HasAura(SPELL_AURA_PERIODIC_HEAL) || aura->GetCasterGUID() != player->GetGUID())
                    continue;
                int32 const base = aura->CalcMaxDuration();
                if (base <= 0)
                    continue;
                int32 const add = std::min(step, base + base / 2 - aura->GetMaxDuration());
                if (add <= 0)
                    continue;
                aura->SetMaxDuration(aura->GetMaxDuration() + add);
                aura->SetDuration(aura->GetDuration() + add);
            }
    }

    void Register() override
    {
        OnEffectProc += AuraEffectProcFn(spell_wcme_holy_concentration_renew::HandleProc, EFFECT_0, SPELL_AURA_DUMMY);
    }
};

// Damage and healing changes that hang on the target's state:
// - Bloodletting (283986, Rupture +25% on targets with your Rend; its companion 283987, Rend +30% on targets with your
//   Rupture) and the Mystic Enchant Garrote (982178, Garrote +5% on targets with your Rend): class scripts 982178 and
//   982132, limited by the aura's class mask.
// - Flare Strike (283151-283155): its rain of arrows (417802, 417816-417819) deals 100% more to the target of your Hunter's Mark (companion
//   283150, class script 417800, held by wcme_spell_companion). The rain is cast by the flare on its owner's behalf.
// - Pack Leader (277566; companion 277750): Spirit Wolves' Spirit Hunt heals (58879) heal for 30% (Pack Leader adds
//   wolves). The heal is a direct heal, so the hook's first unit is the healing wolf.
class wcme_talent_companion_hooks : public UnitScript
{
public:
    wcme_talent_companion_hooks() : UnitScript("wcme_talent_companion_hooks", true,
        { UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        if (!target || !attacker || !spellInfo || !damage || spellInfo->HasAura(SPELL_AURA_PERIODIC_HEAL))
            return;
        // The attacker's class scripts first: an empty list for nearly everyone, so the target is rarely scanned.
        int32 const rend = WcmeClassScriptPct(attacker, 982178, spellInfo);
        int32 const rupture = WcmeClassScriptPct(attacker, 982132, spellInfo);
        if (!rend && !rupture)
            return;
        int32 pct = 0;
        if (rend && WcmeHasOwnFamilyAura(target, attacker->GetGUID(), SPELLFAMILY_WARRIOR, 0x20))
            pct += rend;
        if (rupture && WcmeHasOwnFamilyAura(target, attacker->GetGUID(), SPELLFAMILY_ROGUE, 0x100000))
            pct += rupture;
        if (pct > 0)
            damage = uint32(std::min<uint64>(std::numeric_limits<uint32>::max(), uint64(damage) * (100 + pct) / 100));
    }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        // The rain of each Flare Strike rank (the core's AscensionSummonedEffects payloads), not Volley and its kin,
        // which share the class flag.
        if (!target || !attacker || !spellInfo || damage <= 0 ||
            (spellInfo->Id != 417802 && (spellInfo->Id < 417816 || spellInfo->Id > 417819)))
            return;
        Unit* owner = attacker->GetCharmerOrOwnerOrSelf();
        if (!owner || !WcmeHasOwnFamilyAura(target, owner->GetGUID(), SPELLFAMILY_HUNTER, 0x400))
            return;
        if (int32 const pct = WcmeClassScriptPct(owner, 417800, spellInfo); pct > 0)
            damage = int32(std::min<int64>(std::numeric_limits<int32>::max(), int64(damage) * (100 + pct) / 100));
    }

    void ModifyHealReceived(Unit* first, Unit* second, uint32& heal, SpellInfo const* spellInfo) override
    {
        if (!spellInfo || spellInfo->Id != 58879 || !heal || !first)
            return;
        Unit* owner = first->GetOwner();
        if (!owner && second)
            owner = second->GetOwner();
        if (!owner)
            return;
        if (AuraEffect const* pack = owner->GetAuraEffect(277750, EFFECT_0))
            heal = uint32(uint64(heal) * uint32(std::clamp(pack->GetAmount(), 0, 100)) / 100);
    }
};
// Corrupted Bear Form (271403, the core's own script syncs its -20% Physical penalty, 271408): each melee hit in Bear
// Form also deals Shadow damage (Corrupted Paw, 271411), which the data leaves at a flat 2. Ours scales it to 25% of
// the hit as dealt, after armour and the penalty, so the total matches a plain bear (0.8 x 1.25 = 1.0). The penalty
// needs the core's form script on the CoA forms too (bound in 147). Ascension's
// own elemental weapon attacks keep Physical in their school so armour still counts; taking the share from the hit
// after armour does the same for a pure Shadow spell. James asked for scaling on 25 Nov 2026 (patch 55).
class spell_wcme_corrupted_bear_paw : public AuraScript
{
    PrepareAuraScript(spell_wcme_corrupted_bear_paw);

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        Unit* owner = GetTarget();
        Unit* target = eventInfo.GetActionTarget();
        DamageInfo* damage = eventInfo.GetDamageInfo();
        if (!owner || !target || target == owner || !damage)
            return;
        // Never from the Paw itself, so it cannot feed on its own damage.
        if (SpellInfo const* spell = eventInfo.GetSpellInfo(); spell && spell->Id == 271411)
            return;
        int32 const amount = WcmePercentOfDamage(damage->GetDamage(), 25);
        if (amount)
            owner->CastCustomSpell(target, 271411, &amount, nullptr, nullptr, true, nullptr, aurEff);
    }

    void Register() override
    {
        OnEffectProc += AuraEffectProcFn(spell_wcme_corrupted_bear_paw::HandleProc, EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

// Corrupted Paw (271411) has no spell power coefficient in the data, so the core would add its default for an instant
// spell (about 43% of spell power) and the caster's damage-done bonuses on top of the share above. The Paw keeps only
// the value it was cast with; crits and the target's damage-taken modifiers still apply afterwards.
class spell_wcme_corrupted_paw : public SpellScript
{
    PrepareSpellScript(spell_wcme_corrupted_paw);

    int32 _base = -1;

    void RememberBase(SpellEffIndex /*effIndex*/)
    {
        _base = GetEffectValue();
    }

    void KeepBase()
    {
        if (_base >= 0)
            SetHitDamage(_base);
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_wcme_corrupted_paw::RememberBase, EFFECT_0, SPELL_EFFECT_SCHOOL_DAMAGE);
        OnHit += SpellHitFn(spell_wcme_corrupted_paw::KeepBase);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_beacon_of_virtue);`n    RegisterSpellScript(spell_wcme_beacon_of_virtue_heals);`n    RegisterSpellScript(spell_wcme_holy_concentration_renew);`n    RegisterSpellScript(spell_wcme_corrupted_bear_paw);`n    RegisterSpellScript(spell_wcme_corrupted_paw);`n    new wcme_talent_companion_hooks();`n")
Set-Content $file $text -NoNewline
}

# ---- Talent companion scripts, part 6 (scan "probable" list: Explosive Shot's Explosive Charge, Authority)
Write-Host "Patch: talent companion scripts part 6 (Explosive Charge, Authority)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# The rows that hold each companion and give the scripts their proc rules are in
# sql/enchants/149-talent-companion-scripts-2.sql.
$class = @'
// Explosive Charge (906142, held while you know Explosive Shot): each hit of Explosive Shot's damage (53352, the
// first blast and every tick) also deals the companion's share (40%) to the other enemies within 5 yards (906143).
// Only 53352 itself: its class flag is shared with other area shots, whose every hit would splash again.
// Ascension ran this percent-of-damage aura (354) in its own code; this core runs it only for its own list.
class spell_wcme_explosive_charge : public AuraScript
{
    PrepareAuraScript(spell_wcme_explosive_charge);

    bool CheckProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        Unit* owner = GetTarget();
        Unit* target = eventInfo.GetActionTarget();
        DamageInfo* damage = eventInfo.GetDamageInfo();
        return owner && eventInfo.GetActor() == owner && target && target != owner && damage && damage->GetDamage() &&
            aurEff->GetAmount() > 0 && eventInfo.GetSpellInfo() && eventInfo.GetSpellInfo()->Id == 53352;
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        int32 const amount = WcmePercentOfDamage(eventInfo.GetDamageInfo()->GetDamage(), aurEff->GetAmount());
        if (amount)
            GetTarget()->CastCustomSpell(eventInfo.GetActionTarget(), 906143, &amount, nullptr, nullptr, true, nullptr, aurEff);
    }

    void Register() override
    {
        DoCheckEffectProc += AuraCheckEffectProcFn(spell_wcme_explosive_charge::CheckProc, EFFECT_0, SPELL_AURA_ASCENSION_PROC_PERCENT_EVENT);
        OnEffectProc += AuraEffectProcFn(spell_wcme_explosive_charge::HandleProc, EFFECT_0, SPELL_AURA_ASCENSION_PROC_PERCENT_EVENT);
    }
};

// The splash (906143) spares the shot's own target and splits the share between the enemies it does hit, as the
// companion's tooltip says. Any other use of the spell is left whole.
class spell_wcme_explosive_charge_splash : public SpellScript
{
    PrepareSpellScript(spell_wcme_explosive_charge_splash);

    uint32 _targets = 0;

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        SpellInfo const* from = GetTriggeringSpell();
        if (!from || from->Id != 906142)
            return;
        if (Unit* primary = GetSpell()->GetOriginalTarget()) // the explicit unit is dropped for a destination spell
            targets.remove(primary);
        _targets = uint32(targets.size());
    }

    void Split()
    {
        if (_targets > 1)
            SetHitDamage(GetHitDamage() / int32(_targets));
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_wcme_explosive_charge_splash::FilterTargets, EFFECT_0, TARGET_UNIT_DEST_AREA_ENEMY);
        OnHit += SpellHitFn(spell_wcme_explosive_charge_splash::Split);
    }
};

// Authority (299120): Execution Sentence's ticks stack Authority (299121) on the target (the talent's own trigger,
// given its proc rule in 149). Shield of Righteousness then consumes the stacks: after its hit, the paladin's own
// stacks on that target are removed and the paladin takes 3% less damage per stack consumed (299122, 8 sec; a new
// consume replaces the old buff, it does not add to it). The
// stacks' damage bonus to Shield of Righteousness itself is the debuff's own data and applies before they go.
class spell_wcme_authority_consume : public SpellScript
{
    PrepareSpellScript(spell_wcme_authority_consume);

    void Consume()
    {
        Unit* caster = GetCaster();
        Unit* target = GetHitUnit();
        if (!caster || !target || !caster->HasAura(299120))
            return;
        Aura* authority = target->GetAura(299121, caster->GetGUID());
        if (!authority)
            return;
        uint8 const stacks = authority->GetStackAmount();
        authority->Remove();
        if (!stacks)
            return;
        // 299122 is "per stack" in its data (3% each, up to 4): a fresh buff with one stack per Authority consumed.
        caster->RemoveAurasDueToSpell(299122);
        if (Aura* reduction = caster->AddAura(299122, caster))
            reduction->SetStackAmount(stacks);
    }

    void Register() override
    {
        AfterHit += SpellHitFn(spell_wcme_authority_consume::Consume);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_explosive_charge);`n    RegisterSpellScript(spell_wcme_explosive_charge_splash);`n    RegisterSpellScript(spell_wcme_authority_consume);`n")
Set-Content $file $text -NoNewline
}

# ---- Talent companion scripts, part 7 (scan "stock-data" list: Improved Kick, Fanaticism, Fiery Payback, Improved Blood Presence)
Write-Host "Patch: talent companion scripts part 7 (Improved Kick, Fanaticism, Fiery Payback, Improved Blood Presence)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# The rows that hold each companion and bind the aura script are in sql/enchants/152-talent-companion-scripts-3.sql.
$class = @'
// Improved Kick: a Kick that interrupts a cast gives the rogue energy, the amount held by the rank's companion
// (13869: 20, 13870: 40) and given by 813868. The core has no proc result for "interrupted", so this uses its
// successful-interrupt hook. Kick is Rogue class flag 0x10; the other spells with that flag cannot interrupt.
class wcme_improved_kick_energy : public AllSpellScript
{
public:
    wcme_improved_kick_energy() : AllSpellScript("wcme_improved_kick_energy", { ALLSPELLHOOK_ON_SUCCESSFUL_INTERRUPT }) { }

    void OnSpellSuccessfulInterrupt(Spell* spell, Unit* /*target*/) override
    {
        if (!spell)
            return;
        SpellInfo const* info = spell->GetSpellInfo();
        if (info->SpellFamilyName != SPELLFAMILY_ROGUE || !(info->SpellFamilyFlags[0] & 0x10))
            return;
        Unit* caster = spell->GetCaster();
        if (!caster)
            return;
        for (uint32 companion : { 13870u, 13869u })
            if (AuraEffect const* energy = caster->GetAuraEffect(companion, EFFECT_0))
            {
                int32 amount = energy->GetAmount();
                if (amount > 0)
                    caster->CastCustomSpell(caster, 813868, &amount, nullptr, nullptr, true, nullptr, energy);
                return;
            }
    }
};

// Fanaticism: Crusader Strike, Seals and Judgements deal more damage to a target carrying the paladin's own
// Execution Sentence (Paladin flag 0x2000000 in the third mask). The amount is the rank's companion (31891, 31894,
// 31895), whose data is a modifier with no target. The spell groups by class flag: Judgements (0x800000 / 0x8 in
// the third mask, as the talent's own crit bonus picks them), Seal of Command (0x2000000), the Seal of
// Righteousness family (0x20000000 in the second), Vengeance and Corruption (0x800, their damage over time too),
// Blood and the Martyr (0x400), Crusader Strike and its elemental versions (0x8000), the Judgements of Command
// and Blood (0x8 / 0x200 in the second, 0x10 in the third).
static bool WcmeIsFanaticismSpell(SpellInfo const* spell)
{
    if (!spell || spell->SpellFamilyName != SPELLFAMILY_PALADIN)
        return false;
    flag96 const& flags = spell->SpellFamilyFlags;
    return (flags[0] & (0x800000 | 0x2000000)) || (flags[1] & (0x20000000 | 0x800 | 0x400 | 0x8000 | 0x8 | 0x200)) ||
        (flags[2] & (0x8 | 0x10));
}

static bool WcmeHasOwnExecutionSentence(Unit const* target, ObjectGuid caster)
{
    for (auto const& [id, application] : target->GetAppliedAuras())
    {
        Aura const* aura = application->GetBase();
        SpellInfo const* info = aura->GetSpellInfo();
        if (info->SpellFamilyName == SPELLFAMILY_PALADIN && (info->SpellFamilyFlags[2] & 0x2000000) &&
            aura->GetCasterGUID() == caster)
            return true;
    }
    return false;
}

static int32 WcmeFanaticismPct(Unit const* attacker, Unit const* target, SpellInfo const* spell)
{
    if (!attacker || !target || attacker == target || !WcmeIsFanaticismSpell(spell))
        return 0;
    int32 pct = 0;
    for (uint32 companion : { 31895u, 31894u, 31891u })
        if (AuraEffect const* effect = attacker->GetAuraEffect(companion, EFFECT_0))
        {
            pct = effect->GetAmount();
            break;
        }
    if (pct <= 0 || !WcmeHasOwnExecutionSentence(target, attacker->GetGUID()))
        return 0;
    return pct;
}

class wcme_fanaticism_hooks : public UnitScript
{
public:
    wcme_fanaticism_hooks() : UnitScript("wcme_fanaticism_hooks", true,
        { UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK }) { }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (damage <= 0)
            return;
        if (int32 const pct = WcmeFanaticismPct(attacker, target, spellInfo))
            damage = int32(std::min<int64>(std::numeric_limits<int32>::max(), int64(damage) * (100 + pct) / 100));
    }

    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        if (!damage)
            return;
        if (int32 const pct = WcmeFanaticismPct(attacker, target, spellInfo))
            damage = uint32(std::min<uint64>(std::numeric_limits<uint32>::max(), uint64(damage) * (100 + pct) / 100));
    }
};

// Fiery Payback (44440, 44441): passives that only count below 35% health (their data asks for that health state).
// The core switches such an aura's effects on and off as the state comes and goes, but only a learned spell starts
// switched off. Held through a link instead, the aura starts switched off here when the state is missing, the way
// the core does it for a learned spell.
class spell_wcme_health_state_passive : public AuraScript
{
    PrepareAuraScript(spell_wcme_health_state_passive);

    void HandleApply(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        Unit* target = GetTarget();
        AuraStateType const state = AuraStateType(GetSpellInfo()->CasterAuraState);
        if (!target || state == AURA_STATE_NONE || target->HasAuraState(state))
            return;
        // At login the health states are not set yet; the core sets them afterwards and switches such auras off itself.
        if (Player* player = target->ToPlayer(); player && player->isBeingLoaded())
            return;
        if (AuraApplication* application = GetAura()->GetApplicationOfTarget(target->GetGUID()))
            GetAura()->HandleAllEffects(application, AURA_EFFECT_HANDLE_REAL, false);
    }

    void Register() override
    {
        AfterEffectApply += AuraEffectApplyFn(spell_wcme_health_state_passive::HandleApply, EFFECT_2, SPELL_AURA_ADD_FLAT_MODIFIER, AURA_EFFECT_HANDLE_REAL);
    }
};

// Improved Blood Presence, rank 5 capstone (51376, +3 to the heal share of 63611): the tooltip gives it to Blood
// Presence's heal only. The stock script also casts 63611 in Frost and Unholy Presence with the talent (2%), and the
// modifier would reach that too (James, 25 Nov 2026: hold it at 2%). Outside Blood Presence, its share is taken
// back out. The stock script casts 63611 after the new presence is on, and the core recalculates it when the
// capstone comes or goes, so the check always sees the current presence. Only the stock Blood Presence (48266)
// counts: it is the one in the presence group with Frost and Unholy, and the one the stock script casts 63611 for.
class spell_wcme_blood_presence_capstone_scope : public AuraScript
{
    PrepareAuraScript(spell_wcme_blood_presence_capstone_scope);

    void CalculateAmount(AuraEffect const* /*aurEff*/, int32& amount, bool& /*canBeRecalculated*/)
    {
        Unit* owner = GetUnitOwner();
        if (!owner)
            return;
        AuraEffect const* capstone = owner->GetAuraEffect(51376, EFFECT_0);
        if (!capstone || owner->HasAura(48266))
            return;
        amount = std::max(0, amount - capstone->GetAmount());
    }

    void Register() override
    {
        DoEffectCalcAmount += AuraEffectCalcAmountFn(spell_wcme_blood_presence_capstone_scope::CalculateAmount, EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_improved_kick_energy();`n    new wcme_fanaticism_hooks();`n    RegisterSpellScript(spell_wcme_health_state_passive);`n    RegisterSpellScript(spell_wcme_blood_presence_capstone_scope);`n")
Set-Content $file $text -NoNewline
}

# ---- Talent companion scripts, part 8 (Single-Minded Fury)
Write-Host "Patch: talent companion scripts part 8 (Single-Minded Fury)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# The bindings and the proc rule are in sql/enchants/153-single-minded-fury.sql.
$class = @'
#include "Item.h"
#include <cctype>

// Single-Minded Fury (988256, the Ascension talent; the core scripts only its own copy, 1988256): while a one-handed
// weapon that is not a dagger is in each hand, Mortal Strike, Overpower and Slam deal 5% less damage (988258's
// amount) and are followed by an off-hand attack. Ascension made an off-hand twin for each of them and for each
// elemental version, named "<ability> (Off-hand)"; the follow-up casts the twin of the ability that hit.
static std::unordered_map<std::string, uint32> const& WcmeOffHandTwins()
{
    static std::unordered_map<std::string, uint32> const twins = []
    {
        std::unordered_map<std::string, uint32> map;
        std::unordered_set<uint32> alreadyTriggered;
        std::string const suffix = " (off-hand)";
        for (uint32 id = 0; id < sSpellMgr->GetSpellInfoStoreSize(); ++id)
        {
            SpellInfo const* info = sSpellMgr->GetSpellInfo(id);
            if (!info || info->SpellFamilyName != SPELLFAMILY_WARRIOR || !info->SpellName[0])
                continue;
            for (SpellEffectInfo const& effect : info->Effects)
                if (effect.Effect == SPELL_EFFECT_TRIGGER_SPELL && effect.TriggerSpell)
                    alreadyTriggered.insert(effect.TriggerSpell);
            std::string name = info->SpellName[0];
            if (name.size() <= suffix.size())
                continue;
            std::string tail = name.substr(name.size() - suffix.size());
            std::transform(tail.begin(), tail.end(), tail.begin(), [](unsigned char c) { return std::tolower(c); });
            if (tail != suffix)
                continue;
            map.try_emplace(name.substr(0, name.size() - suffix.size()), id); // lowest id wins: the Ascension twin
        }
        // Abilities that strike with both weapons by themselves (Hateful Strike, Loa's Assault, Overwhelm) trigger
        // their twin through their own data; they are not Single-Minded Fury abilities and get no second twin.
        std::erase_if(map, [&](auto const& entry) { return alreadyTriggered.contains(entry.second); });
        return map;
    }();
    return twins;
}

static uint32 WcmeSingleMindedFuryTwin(SpellInfo const* spell)
{
    if (!spell || spell->SpellFamilyName != SPELLFAMILY_WARRIOR || !(spell->SpellFamilyFlags[0] & 0x2200004) ||
        !spell->SpellName[0])
        return 0;
    auto const twin = WcmeOffHandTwins().find(spell->SpellName[0]);
    return twin != WcmeOffHandTwins().end() ? twin->second : 0;
}

static bool WcmeSingleMindedFuryWeapons(Player const* player)
{
    for (WeaponAttackType attack : { BASE_ATTACK, OFF_ATTACK })
    {
        Item const* weapon = player->GetWeaponForAttack(attack, true);
        if (!weapon)
            return false;
        ItemTemplate const* proto = weapon->GetTemplate();
        if (proto->InventoryType == INVTYPE_2HWEAPON || proto->SubClass == ITEM_SUBCLASS_WEAPON_DAGGER)
            return false;
    }
    return true;
}

class spell_wcme_single_minded_fury : public AuraScript
{
    PrepareAuraScript(spell_wcme_single_minded_fury);

    bool Validate(SpellInfo const* /*spellInfo*/) override
    {
        WcmeOffHandTwins(); // built once at startup, not at the first hit
        return ValidateSpellInfo({ 988258 });
    }

    void HandlePeriodic(AuraEffect const* aurEff)
    {
        Player* player = GetTarget()->ToPlayer();
        if (!player)
            return;
        bool const qualifies = WcmeSingleMindedFuryWeapons(player);
        bool const active = player->HasAura(988258);
        if (qualifies && !active)
            player->CastSpell(player, 988258, true, nullptr, aurEff);
        else if (!qualifies && active)
            player->RemoveAurasDueToSpell(988258);
    }

    void HandleRemove(AuraEffect const* /*aurEff*/, AuraEffectHandleModes /*mode*/)
    {
        GetTarget()->RemoveAurasDueToSpell(988258);
    }

    void Register() override
    {
        OnEffectPeriodic += AuraEffectPeriodicFn(spell_wcme_single_minded_fury::HandlePeriodic, EFFECT_0, SPELL_AURA_PERIODIC_DUMMY);
        AfterEffectRemove += AuraEffectRemoveFn(spell_wcme_single_minded_fury::HandleRemove, EFFECT_0, SPELL_AURA_PERIODIC_DUMMY, AURA_EFFECT_HANDLE_REAL);
    }
};

// 988258 is on while the weapons qualify; its proc rule (153) brings every warrior hit with the talent's class
// flags here, and only an ability with an off-hand twin is followed up. The twins carry no twin of their own.
class spell_wcme_single_minded_fury_follow_up : public AuraScript
{
    PrepareAuraScript(spell_wcme_single_minded_fury_follow_up);

    bool CheckProc(ProcEventInfo& eventInfo)
    {
        Unit* owner = GetTarget();
        Unit* target = eventInfo.GetActionTarget();
        DamageInfo* damage = eventInfo.GetDamageInfo();
        Player* player = owner ? owner->ToPlayer() : nullptr;
        return player && eventInfo.GetActor() == owner && target && target != owner && damage && damage->GetDamage() &&
            WcmeSingleMindedFuryTwin(eventInfo.GetSpellInfo()) && WcmeSingleMindedFuryWeapons(player);
    }

    void HandleProc(AuraEffect const* aurEff, ProcEventInfo& eventInfo)
    {
        PreventDefaultAction();
        if (uint32 const twin = WcmeSingleMindedFuryTwin(eventInfo.GetSpellInfo()))
            GetTarget()->CastSpell(eventInfo.GetActionTarget(), twin, true, nullptr, aurEff);
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_wcme_single_minded_fury_follow_up::CheckProc);
        OnEffectProc += AuraEffectProcFn(spell_wcme_single_minded_fury_follow_up::HandleProc, EFFECT_0, SPELL_AURA_ANY);
    }
};

class wcme_single_minded_fury_hooks : public UnitScript
{
public:
    wcme_single_minded_fury_hooks() : UnitScript("wcme_single_minded_fury_hooks", true, { UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN }) { }

    void ModifySpellDamageTaken(Unit* /*target*/, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (damage <= 0 || !attacker || !spellInfo || spellInfo->SpellFamilyName != SPELLFAMILY_WARRIOR)
            return;
        AuraEffect const* penalty = attacker->GetAuraEffect(988258, EFFECT_0);
        if (!penalty || !WcmeSingleMindedFuryTwin(spellInfo))
            return;
        int32 const pct = std::clamp(penalty->GetAmount(), -100, 0);
        damage = int32(int64(damage) * (100 + pct) / 100);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_single_minded_fury);`n    RegisterSpellScript(spell_wcme_single_minded_fury_follow_up);`n    new wcme_single_minded_fury_hooks();`n")
Set-Content $file $text -NoNewline
}

# ---- Talent companion scripts, part 9 (Righteous Fury's Fierce Block)
Write-Host "Patch: Righteous Fury raises the chance to block Fierce Blow (Unit.cpp hook and its rule)"
& {
# The core has no script hook for a spell's block chance, so Unit::isSpellBlocked asks a function pointer, set by
# the rule below at start-up; a plain pointer keeps the game library from depending on the coa one. Null: no change.
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$head = "bool Unit::isSpellBlocked(Unit* victim, SpellInfo const* spellProto, WeaponAttackType attackType)`n{`n"
$skill = "        else`n            blockChance += (weaponSkill - victimMaxSkill) * 0.04f;`n"
foreach ($anchor in @($head, $skill)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: Unit::isSpellBlocked was not found as expected in $file" }
}
$text = $text.Replace($head, "float (*WcmeSpellBlockChanceBonus)(Unit const*, SpellInfo const*) = nullptr; // set by patch 55 (Fierce Block)`n`n" + $head)
$text = $text.Replace($skill, $skill + "`n        if (WcmeSpellBlockChanceBonus)`n            blockChance += WcmeSpellBlockChanceBonus(victim, spellProto);`n")
Set-Content $file $text -NoNewline
}
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or an earlier patch did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# The link that gives Righteous Fury its companion is in sql/enchants/153-single-minded-fury.sql.
$class = @'
// Righteous Fury: "your chance to block Fierce Blows increased by 60%" (60 points, added to the block chance). The
// amount is its companion's (986051, in hundredths of a percent: 6000), linked to Righteous Fury. Fierce Blow is the
// CoA strike creatures use on their target (975011), plus the boss strikes whose text says they count as a Fierce
// Blow (Sartura's cuts, the Fierce Draconic Strikes and the rest, listed from our spell data on 25 Nov 2026). Only
// with something to block with: a player needs the block skill and an unbroken shield.
extern float (*WcmeSpellBlockChanceBonus)(Unit const*, SpellInfo const*); // defined in Unit.cpp (this patch)

static bool WcmeIsFierceBlow(uint32 spellId)
{
    static std::unordered_set<uint32> const fierceBlows = { 975011,
        2108314, 2111425, 2116056, 2116116, 2116118, 2116120, 2116122, 2116124, 2118250, 2118251, 2119102, 2119402,
        2119502, 2119602, 2119702, 2123500, 2123902, 2124092, 2124093, 2125490, 2125491, 2125492, 2130936, 2131355,
        2132021, 2141704, 2145508, 2145807, 2147154, 2148902, 2149952, 2152161, 2152162, 2152165, 2154026, 2154402,
        2157500, 2157902, 2158092, 2158093, 2159002, 2165014, 2180275 };
    return fierceBlows.contains(spellId);
}

static bool WcmeCanBlockWithShield(Unit const* victim)
{
    Player const* player = victim->ToPlayer();
    if (!player)
        return victim->GetUnitBlockChance() > 0.0f;
    if (!player->CanBlock())
        return false;
    Item const* shield = player->GetUseableItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);
    return shield && !shield->IsBroken() && shield->GetTemplate()->Block;
}

static float WcmeFierceBlockBonus(Unit const* victim, SpellInfo const* spell)
{
    if (!victim || !spell || !WcmeIsFierceBlow(spell->Id))
        return 0.0f;
    AuraEffect const* fierceBlock = victim->GetAuraEffect(986051, EFFECT_0);
    if (!fierceBlock || fierceBlock->GetAmount() <= 0 || !WcmeCanBlockWithShield(victim))
        return 0.0f;
    return fierceBlock->GetAmount() / 100.0f;
}

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    WcmeSpellBlockChanceBonus = &WcmeFierceBlockBonus;`n")
Set-Content $file $text -NoNewline
}

# ---- Showcase talents, batch 1 (docs/bot-builds/showcase-audit.md): Raging Onslaught, Master of Kunai, Toss and Throw.
# Their data needs code: see sql/enchants/175-talent-code-showcase-1.sql, which binds these scripts and gives the
# rest of the fixes. James, 28 Nov 2026: restore the showcase builds' talents.
Write-Host "Patch: Raging Onslaught refunds a Raging Blow charge; Master of Kunai and Toss and Throw do their whole tooltip"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no single: $($anchor.Split("`n")[0])" }
}
$class = @'
// Wildcard: Raging Onslaught (275920). A Raging Blow cast has the talent's own 20% chance to refund its charge. The
// core spends one Rage! charge (954881) after the cast (spell_hero_warrior_spend_rage_charge, AfterCast); this proc
// runs on the cast phase, before that, so the charge added here is the one the cast then spends. Casting Rage! again
// would reset its charges instead, so the charge is added directly. Bound in sql 175.
class spell_wcme_raging_onslaught : public AuraScript
{
    PrepareAuraScript(spell_wcme_raging_onslaught);

    bool CheckProc(ProcEventInfo& eventInfo)
    {
        SpellInfo const* spell = eventInfo.GetSpellInfo();
        return spell && spell->Id == 954836 && GetTarget()->HasAura(954881);
    }

    void HandleProc(AuraEffect const* /*aurEff*/, ProcEventInfo& /*eventInfo*/)
    {
        PreventDefaultAction();
        if (Aura* charges = GetTarget()->GetAura(954881))
            charges->SetCharges(charges->GetCharges() + 1);
    }

    void Register() override
    {
        DoCheckProc += AuraCheckProcFn(spell_wcme_raging_onslaught::CheckProc);
        OnEffectProc += AuraEffectProcFn(spell_wcme_raging_onslaught::HandleProc, EFFECT_0, SPELL_AURA_PROC_TRIGGER_SPELL);
    }
};

// Wildcard: Master of Kunai's Kunai (277477) raises the damage of your next Deadly Throw by its stacks; that Deadly
// Throw uses them up. Ascension's server removed the stacks; here, after a Deadly Throw hits, the thrower's Kunai on
// that target goes. Bound in sql 175 to every rogue Deadly Throw (stock and CoA ranks). The stacks themselves are
// data (sql 176 gives the Master of Kunai buff its trigger, once this build is installed).
class spell_wcme_kunai_consume : public SpellScript
{
    PrepareSpellScript(spell_wcme_kunai_consume);

    void HandleAfterHit()
    {
        Unit* caster = GetCaster();
        Unit* target = GetHitUnit();
        if (caster && target)
            target->RemoveAurasDueToSpell(277477, caster->GetGUID());
    }

    void Register() override
    {
        AfterHit += SpellHitFn(spell_wcme_kunai_consume::HandleAfterHit);
    }
};

// Wildcard: two Shuriken Toss talents, checked when a player casts Shuriken Toss (before its spell modifiers and their
// charges are used up, so the third cast of Toss and Throw still counts).
// Shuriken Toss here means the ids carrying the class flag Toss and Throw's cost reduction uses (so each counted
// cast also uses one of its three charges); 1569626, which has no class flags and is not on the talent list, is
// left out.
// - Master of Kunai (talent 277475): Shuriken Toss cuts Adrenaline Rush's cooldown by 4 sec (its helper 277479),
//   for the stock spell (13750) and the CoA copy (1113750) alike.
// - Toss and Throw (buff 277456): each of its three Shuriken Tosses gives one more combo point (34071) to the target.
//   The buff's own proc is left without a trigger on purpose: as a proc it would also use up one of the three charges
//   the cost reduction uses, and the buff would end after two throws.
class wcme_shuriken_toss_talents : public PlayerScript
{
public:
    wcme_shuriken_toss_talents() : PlayerScript("wcme_shuriken_toss_talents", { PLAYERHOOK_ON_SPELL_CAST }) { }

    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (!player || !spell || !spell->GetSpellInfo())
            return;
        static std::unordered_set<uint32> const shurikenToss = { 954835, 955223, 955224, 955225, 955226, 955227, 955228,
            2304835 };
        if (!shurikenToss.contains(spell->GetSpellInfo()->Id))
            return;
        if (player->HasAura(277475))
            for (uint32 adrenalineRush : { 13750u, 1113750u })
                if (player->HasSpellCooldown(adrenalineRush))
                    player->ModifySpellCooldown(adrenalineRush, -4000);
        if (player->HasAura(277456))
            if (Unit* target = spell->m_targets.GetUnitTarget())
                player->CastSpell(target, 34071, true);
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    RegisterSpellScript(spell_wcme_raging_onslaught);`n    RegisterSpellScript(spell_wcme_kunai_consume);`n    new wcme_shuriken_toss_talents();`n")
Set-Content $file $text -NoNewline
}
