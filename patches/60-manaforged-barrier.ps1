# Mana-forged Barrier, the full Ascension tank stance (701463). The core puts you in its form (form 20) and teaches
# Channeled Mana, but nothing else: it has no code for that form, and the Wildcard client's copy of the spell has its
# effects blanked. While in the stance (our spells, sql/enchants/150-custom-spells.sql and client-patch/custom_spells.py):
# - 9990009 (hidden): a mana shield that absorbs up to 90% of damage, scaled by how full your mana is (half as much
#   against magic), draining 1 mana per point absorbed; +160% threat; immune to interrupts.
# - 9990010 (hidden): 30% less damage done, 40% less healing done, 6% less chance to be critically hit in melee.
# - Damage taken from players (and their pets) doubled.
# - Dodge, parry and block while casting or channeling.
# - Power Surge (9990012): while casting a damaging spell or channeling, a melee hit against you has a 50% chance to
#   restore 30% of your missing mana over 4 sec; at most once every 2 sec.
# - Leaving the stance leaves Mana-forged Mindset (9990011) for 10 sec: 20% less damage, 10% less healing.
# Run by the build from the workspace root, after 40-battlegrounds.ps1. Throws if an anchor is gone. Listed in
# CHANGES.md. Wildcard.ManaforgedBarrier = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Mana-forged Barrier state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    bool WcmeBarrier = false;`n    uint64 WcmeSurgeReady = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

# ---- Dodge, parry and block while casting (tank stance)
Write-Host "Patch: Mana-forged Barrier defends while casting"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$channel = "bool Unit::CanDefendDuringChannel() const`n{`n"
$cast = "bool Unit::CanDefendDuringCast() const`n{`n"
$block = "victim->IsNonMeleeSpellCast(false, false, true)"
foreach ($anchor in @($channel, $cast)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: Unit.cpp has no: $($anchor.Split("`n")[0])" }
}
if (([regex]::Matches($text, [regex]::Escape($block))).Count -ne 3) { throw 'Core changed: the three block-while-casting checks in Unit.cpp were not found' }
$guard = "    if (HasAura(9990009)) // Wildcard: Mana-forged Barrier`n        return true;`n"
$text = $text.Replace($channel, $channel + $guard).Replace($cast, $cast + $guard)
$text = $text.Replace($block, "(" + $block + " && !victim->HasAura(9990009))")
Set-Content $file $text -NoNewline
}

# ---- The stance, its shield, Power Surge and the player-damage penalty
Write-Host "Patch: Mana-forged Barrier (Wildcard.ManaforgedBarrier)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
$class = @'
// Wildcard: Mana-forged Barrier, the full tank stance (patches/60-manaforged-barrier.ps1).
namespace WcmeManaforged
{
    constexpr uint32 Stance = 701463;
    constexpr uint32 Shield = 9990009;
    constexpr uint32 Penalty = 9990010;
    constexpr uint32 Mindset = 9990011;
    constexpr uint32 Surge = 9990012;

    inline bool Enabled() { return sConfigMgr->GetOption<bool>("Wildcard.ManaforgedBarrier", true); }

    inline void Lasting(Unit* unit, uint32 spell, int32 duration, int32 tick = 0)
    {
        unit->RemoveAurasDueToSpell(spell);
        if (Aura* aura = unit->AddAura(spell, unit))
        {
            aura->SetMaxDuration(duration);
            aura->SetDuration(duration);
            if (tick)
                if (AuraEffect* effect = aura->GetEffect(EFFECT_0))
                    effect->ChangeAmount(tick);
        }
    }

    inline bool CastingForSurge(Unit const* unit)
    {
        if (Spell const* channel = unit->GetCurrentSpell(CURRENT_CHANNELED_SPELL))
            if (channel->getState() != SPELL_STATE_FINISHED)
                return true;
        if (Spell const* cast = unit->GetCurrentSpell(CURRENT_GENERIC_SPELL))
            return cast->getState() == SPELL_STATE_PREPARING && !cast->GetSpellInfo()->IsPositive();
        return false;
    }
}

class spell_wcme_manaforged_barrier : public AuraScript
{
    PrepareAuraScript(spell_wcme_manaforged_barrier);

    void Absorb(AuraEffect* /*effect*/, DamageInfo& damage, uint32& absorb)
    {
        Unit* target = GetTarget();
        uint32 const maxMana = target->GetMaxPower(POWER_MANA);
        if (!maxMana)
        {
            absorb = 0;
            return;
        }
        float share = 0.9f * float(target->GetPower(POWER_MANA)) / float(maxMana);
        if (!(damage.GetSchoolMask() & SPELL_SCHOOL_MASK_NORMAL))
            share *= 0.5f;
        absorb = uint32(float(damage.GetDamage()) * share);
    }

    void Register() override
    {
        OnEffectManaShield += AuraEffectManaShieldFn(spell_wcme_manaforged_barrier::Absorb, EFFECT_0);
    }
};

class wcme_manaforged_barrier : public PlayerScript
{
public:
    wcme_manaforged_barrier() : PlayerScript("wcme_manaforged_barrier", {PLAYERHOOK_ON_UPDATE}) { }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        bool const inStance = player->IsAlive() && player->HasAura(WcmeManaforged::Stance) && WcmeManaforged::Enabled();
        if (inStance)
        {
            for (uint32 spell : {WcmeManaforged::Shield, WcmeManaforged::Penalty})
                if (!player->HasAura(spell))
                    player->AddAura(spell, player);
            if (player->HasAura(WcmeManaforged::Mindset))
                player->RemoveAurasDueToSpell(WcmeManaforged::Mindset);
            player->WcmeBarrier = true;
            return;
        }
        if (!player->WcmeBarrier)
            return;
        player->WcmeBarrier = false;
        player->RemoveAurasDueToSpell(WcmeManaforged::Shield);
        player->RemoveAurasDueToSpell(WcmeManaforged::Penalty);
        player->RemoveAurasDueToSpell(WcmeManaforged::Surge);
        if (player->IsAlive() && WcmeManaforged::Enabled())
            WcmeManaforged::Lasting(player, WcmeManaforged::Mindset, 10000);
    }
};

class wcme_manaforged_barrier_damage : public UnitScript
{
public:
    wcme_manaforged_barrier_damage() : UnitScript("wcme_manaforged_barrier_damage", true,
        {UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK}) { }

    void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage) override
    {
        Player* tank = Tank(target);
        if (!tank)
            return;
        if (FromPlayer(attacker, tank))
            damage *= 2;
        if (damage && attacker && attacker != tank && CanSurge(tank))
        {
            tank->WcmeSurgeReady = GameTime::GetGameTimeMS().count() + 2000;
            uint32 const missing = tank->GetMaxPower(POWER_MANA) - tank->GetPower(POWER_MANA);
            if (int32 const tick = int32(missing * 0.3f / 4.0f))
                WcmeManaforged::Lasting(tank, WcmeManaforged::Surge, 4000, tick);
        }
    }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* /*spellInfo*/) override
    {
        if (Player* tank = Tank(target); damage > 0 && tank && FromPlayer(attacker, tank))
            damage *= 2;
    }

    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* /*spellInfo*/) override
    {
        if (Player* tank = Tank(target); tank && FromPlayer(attacker, tank))
            damage *= 2;
    }

private:
    static Player* Tank(Unit* target)
    {
        Player* player = target ? target->ToPlayer() : nullptr;
        return player && player->WcmeBarrier ? player : nullptr;
    }

    static bool FromPlayer(Unit* attacker, Player* tank)
    {
        Player* player = attacker ? attacker->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
        return player && player != tank;
    }

    static bool CanSurge(Player* tank)
    {
        return uint64(GameTime::GetGameTimeMS().count()) >= tank->WcmeSurgeReady && WcmeManaforged::CastingForSurge(tank) &&
            roll_chance_i(50);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"GameTime.h`"`n#include `"Random.h`"`n#include `"Spell.h`"`n#include `"SpellAuraEffects.h`"`n#include `"SpellAuras.h`"`n#include `"SpellInfo.h`"`n#include `"SpellScript.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_manaforged_barrier();`n    new wcme_manaforged_barrier_damage();`n    RegisterSpellScript(spell_wcme_manaforged_barrier);`n")
Set-Content $file $text -NoNewline
}
