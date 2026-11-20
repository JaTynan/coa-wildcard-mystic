# Undead signature racial: Grave Defiance (docs/race-kits.md).
# Below 35% health you deal and heal more, rising evenly to +30% at 1% health (about +13% at 20%, +22% at 10%): buff
# 9990027, whose stack count is the bonus in percent. It lasts up to 15 sec at a time; when it ends (time up, healed
# above 35%, or rising as a ghoul) it can't start again for 45 sec (marker 9990028).
# When a hit would kill you, you rise as a ghoul for 10 sec instead (9990029: Raise Ally's ghoul model, 30% less damage
# and healing done). The ghoul can't die and can't be healed: it stays at 1 health. A killing blow by the ghoul on an
# enemy worth experience or honor brings you back at 20% health; otherwise you die when it ends, credited to whoever
# dealt the killing hit. Rising takes 20 charges of Grave Feast (9990061, a buff whose stack count is the charges, up to
# 20, kept through death and logout), all used up when you rise; each tick of a Cannibalize channel adds one (every
# 2 sec, 5 for a full channel, fewer if interrupted), so about four full channels between rises (James, 21 November;
# it replaces the 10-minute Grave Hunger debuff 9990030 and Cannibalize taking 2 min off it, 20 November).
# Not from falling, lava, drowning or fatigue (self damage), not from your duel opponent (the duel ends at 1 health as
# usual), and not in a vehicle. A battleground flag carrier drops the flag on rising. The spells are in sql/enchants/150-custom-spells.sql and the client patch
# (client-patch/custom_spells.py). Run by the build from the workspace root, after 40-battlegrounds.ps1. Throws if an
# anchor is gone. Listed in CHANGES.md. Racials.GraveDefiance = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Grave Defiance state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    bool WcmeGraveActive = false;`n    bool WcmeGhoulActive = false;`n    bool WcmeGhoulRevived = false;`n    ObjectGuid WcmeGhoulKiller;`n    uint32 WcmeCannibalizeTicks = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Grave Defiance for Undead (Racials.GraveDefiance)"
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
// Wildcard: Undead Grave Defiance (docs/race-kits.md).
namespace WcmeGraveDefiance
{
    constexpr uint32 Defiance = 9990027;          // the low-health bonus; stacks = percent
    constexpr uint32 DefianceCooldown = 9990028;  // 45 sec after the bonus ends
    constexpr uint32 Ghoul = 9990029;             // risen: Raise Ally's ghoul, 30% less damage and healing done
    constexpr uint32 RetiredCooldown = 9990030;   // the old 10 min Grave Hunger debuff: taken off where still worn
    constexpr uint32 Feast = 9990061;             // Grave Feast: stacks = charges to rise
    constexpr uint32 FeastNeeded = 20;            // rising takes (and uses) this many; also the most you can hold
    constexpr uint32 CannibalizeHeal = 20578;     // the healing aura every Cannibalize channels: a charge per tick

    inline uint32 Charges(Player* player)
    {
        Aura const* feast = player->GetAura(Feast);
        return feast ? feast->GetStackAmount() : 0;
    }

    // Charges for the Cannibalize ticks since the last look (the aura counts them).
    inline void CountCannibalize(Player* player)
    {
        Aura* heal = player->GetAura(CannibalizeHeal, player->GetGUID());
        AuraEffect const* effect = heal ? heal->GetEffect(EFFECT_0) : nullptr;
        uint32 const ticks = effect ? effect->GetTickNumber() : 0;
        if (ticks > player->WcmeCannibalizeTicks && player->IsAlive())
        {
            uint32 const gained = ticks - player->WcmeCannibalizeTicks;
            uint32 const charges = std::min(FeastNeeded, Charges(player) + gained);
            Aura* feast = player->GetAura(Feast);
            if (!feast)
                feast = player->AddAura(Feast, player);
            if (feast && feast->GetStackAmount() != charges)
                feast->SetStackAmount(uint8(charges));
        }
        player->WcmeCannibalizeTicks = ticks;
    }

    inline bool Enabled()
    {
        return sConfigMgr->GetOption<bool>("Racials.GraveDefiance", true);
    }

    inline void Lasting(Player* player, uint32 spell, int32 duration)
    {
        if (Aura* aura = player->AddAura(spell, player))
        {
            aura->SetMaxDuration(duration);
            aura->SetDuration(duration);
        }
    }

    // Ends the low-health bonus and starts its 45 sec cooldown.
    inline void EndDefiance(Player* player)
    {
        player->RemoveAurasDueToSpell(Defiance);
        player->WcmeGraveActive = false;
        if (player->IsAlive())
            Lasting(player, DefianceCooldown, 45000);
    }

    // +1% at 35% health rising evenly to +30% at 1% (about +13% at 20%, +22% at 10%).
    inline uint8 Bonus(Player* player)
    {
        int32 const bonus = int32(std::lround(30.0f * (35.0f - player->GetHealthPct()) / 34.0f));
        return uint8(std::clamp(bonus, 1, 30));
    }
}

class wcme_grave_defiance : public PlayerScript
{
public:
    wcme_grave_defiance() : PlayerScript("wcme_grave_defiance", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_PVP_KILL}) { }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        using namespace WcmeGraveDefiance;
        if (player->getRace() != RACE_UNDEAD_PLAYER)
            return;
        if (player->HasAura(RetiredCooldown))
            player->RemoveAurasDueToSpell(RetiredCooldown);
        CountCannibalize(player);

        // The ghoul first, even with the setting turned off meanwhile: a ghoul that has risen still ends one way or
        // the other. The aura is the state, so a ghoul that logged out and back in carries on.
        bool const ghoul = player->HasAura(Ghoul);
        if (ghoul)
        {
            player->WcmeGhoulActive = true;
            if (player->GetHealth() > 1)
                player->SetHealth(1); // natural regeneration and leech effects don't heal the ghoul either
        }
        else if (player->WcmeGhoulActive)
        {
            // Time ran out (or something removed it) without a killing blow: the death the ghoul held off.
            player->WcmeGhoulActive = false;
            bool const revived = player->WcmeGhoulRevived;
            ObjectGuid const killerGuid = player->WcmeGhoulKiller;
            player->WcmeGhoulRevived = false;
            player->WcmeGhoulKiller.Clear();
            if (!revived && player->IsAlive())
            {
                Unit* killer = killerGuid ? ObjectAccessor::GetUnit(*player, killerGuid) : nullptr;
                Unit::Kill(killer, player);
                return;
            }
        }

        if (!Enabled())
        {
            if (player->HasAura(Defiance))
                player->RemoveAurasDueToSpell(Defiance);
            player->WcmeGraveActive = false;
            return;
        }

        Aura* defiance = player->GetAura(Defiance);
        if (player->WcmeGraveActive && !defiance)
        {
            // Its 15 sec ran out (or death removed it).
            player->WcmeGraveActive = false;
            if (player->IsAlive())
                Lasting(player, DefianceCooldown, 45000);
            return;
        }
        if (defiance && (ghoul || !player->IsAlive() || !player->HealthBelowPct(35)))
        {
            EndDefiance(player);
            return;
        }
        if (!defiance)
        {
            if (ghoul || !player->IsAlive() || !player->HealthBelowPct(35) || player->HasAura(DefianceCooldown))
                return;
            Lasting(player, Defiance, 15000);
            defiance = player->GetAura(Defiance);
            if (!defiance)
                return;
            player->WcmeGraveActive = true;
            WcmeFx::Play(player, 165101); // necromantic empowerment
        }
        uint8 const bonus = Bonus(player);
        if (defiance->GetStackAmount() != bonus)
            defiance->SetStackAmount(bonus);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override { Revive(killer, killed); }
    void OnPlayerPVPKill(Player* killer, Player* killed) override
    {
        if (killer != killed)
            Revive(killer, killed);
    }

private:
    // A killing blow by the ghoul on an enemy worth experience or honor (not critters, totems, pets or gray enemies)
    // brings the player back at 20% health.
    static void Revive(Player* killer, Unit* killed)
    {
        using namespace WcmeGraveDefiance;
        if (!killer || !killed || !killer->HasAura(Ghoul) || !killer->isHonorOrXPTarget(killed))
            return;
        killer->WcmeGhoulRevived = true;
        killer->RemoveAurasDueToSpell(Ghoul);
        WcmeFx::Play(killer, 10297); // back to life: Unholy Presence
        killer->SetHealth(std::max<uint32>(1, killer->CountPctFromMaxHealth(20)));
    }
};

// Wildcard: Grave Defiance's rise. Runs before a hit lowers health, after absorbs (Cheat Death, Ardent Defender and
// the like save first), so the killer gets no credit and nothing is lost until the ghoul really dies.
class wcme_grave_defiance_rise : public UnitScript
{
public:
    // DealDamage is called on every unit script; the heal hook keeps the ghoul at 1 health.
    wcme_grave_defiance_rise() : UnitScript("wcme_grave_defiance_rise", true, {UNITHOOK_ON_BEFORE_HEAL_ABSORB}) { }

    uint32 DealDamage(Unit* attacker, Unit* victim, uint32 damage, DamageEffectType damagetype,
                      std::optional<uint32>* /*scriptHealthLeechDamage*/) override
    {
        using namespace WcmeGraveDefiance;
        if (!damage || !victim || damagetype == SELF_DAMAGE)
            return damage;
        Player* player = victim->ToPlayer();
        if (!player || player->getRace() != RACE_UNDEAD_PLAYER)
            return damage;
        uint32 const health = player->GetHealth();
        if (!health || damage < health)
            return damage;

        // Already risen: the ghoul can't die until its time is up. The last hit that would have killed it gets the
        // credit if it does.
        if (player->HasAura(Ghoul))
        {
            if (attacker && attacker != player)
                player->WcmeGhoulKiller = attacker->GetGUID();
            return health - 1;
        }

        if (!Enabled() || !player->IsAlive() || Charges(player) < FeastNeeded || player->GetVehicle() ||
            player->HasSpiritOfRedemptionAura() || player->GetCommandStatus(CHEAT_GOD) ||
            player->HasPlayerFlag(PLAYER_FLAGS_IS_OUT_OF_BOUNDS))
            return damage;
        // The duel ends at 1 health as usual when the opponent (or their pet) lands the hit.
        if (player->duel && attacker && (player->duel->Opponent == attacker ||
            player->duel->Opponent->GetGUID() == attacker->GetCharmerOrOwnerGUID()))
            return damage;

        player->WcmeGhoulKiller = (attacker && attacker != player) ? attacker->GetGUID() : ObjectGuid::Empty;
        player->WcmeGhoulRevived = false;
        player->WcmeGhoulActive = true;
        if (player->HasAura(Defiance))
            EndDefiance(player); // the low-health bonus doesn't apply to the ghoul
        // A battleground flag carrier drops the flag, as at death: an unkillable carrier would be a sure capture.
        if (Battleground* bg = player->GetBattleground())
            bg->EventPlayerDroppedFlag(player);
        Lasting(player, Ghoul, 10000);
        player->RemoveAurasDueToSpell(Feast); // rising uses every charge
        WcmeFx::Play(player, 258020); // the rise: a necromancy summon; the ghoul buff wears Dark Banish
        return health - 1;
    }

    void OnBeforeHealAbsorb(HealInfo& heal) override
    {
        Player* target = heal.GetTarget() ? heal.GetTarget()->ToPlayer() : nullptr;
        if (target && target->getRace() == RACE_UNDEAD_PLAYER && target->HasAura(WcmeGraveDefiance::Ghoul))
            heal.SetHeal(0);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"ObjectAccessor.h`"`n#include `"Spell.h`"`n#include `"SpellAuras.h`"`n#include `"SpellInfo.h`"`n#include `"UnitScript.h`"`n#include <cmath>`n#include <optional>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_grave_defiance();`n    new wcme_grave_defiance_rise();`n")
Set-Content $file $text -NoNewline
}
