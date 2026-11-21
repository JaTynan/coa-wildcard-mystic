# Tauren signature racial: Plainsrunning (docs/race-kits.md). Running on foot builds speed over 60 sec up to level + 40%
# (100% at level 60); when you stop it holds for 3 sec, then drains over 10 sec (James, 21 November; was 6 sec); it adds on top of other speed effects (Sprint's +70% and a full
# +100% make +170%). Nothing while mounted; held, but not applied, while carrying a battleground flag. Group members
# within 10 yards of a running Tauren get the same bonus while they're on foot (Running with the Herd, 9990058; the
# highest Tauren's if several; not while carrying a flag; James, 20 November). Tauren build faster together: each other
# Tauren running in the group within 10 yards adds the normal rate again, up to 4 (two build in 30 sec, five in 12).
# War Stomp adds 30% more for 5 sec, past the cap, and can be cast on the move at 80% less speed while it casts
# (hidden 9990060), so it doesn't stop the run: a running start or a boost mid run (James, 20 November).
# Juggernaut (James, 21 November: the unstoppable race once moving): tiers by how full the charge is, Tauren only, shown
# as buffs. A third: Momentum (stuns, fears, roots 15% shorter). Two thirds: Unstoppable (25% shorter, 5% less damage
# taken, immune to slows; hidden 9990066 carries the last two). Full: Juggernaut (40% shorter, 10% less damage taken,
# immune to slows and roots; hidden 9990067), and Impact (9990068): the next attack or spell that deals damage deals
# 30% more and knocks the target back (never a boss), and costs 10 sec of building (a sixth of the charge), so the
# Tauren drops back to Unstoppable and runs back up to full for the next (James: momentum spent on the big hit). Each
# new tier reached plays the full-speed shout disc and drum.
# The buff icon is our spell 9990001 (sql/enchants/150-custom-spells.sql and the client patch, client-patch/custom_spells.py).
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose script
# loader this registers in. Each part throws if its anchor is gone. Listed in CHANGES.md. Racials.Plainsrunning = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Plainsrunning state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    float WcmePlainsrunningCharge = 0.0f;`n    float WcmePlainsrunningBonus = 0.0f;`n    uint32 WcmePlainsrunningTimer = 0;`n" +
    "    float WcmeHerdBonus = 0.0f;`n    float WcmeHerdOffer = 0.0f;`n    ObjectGuid WcmeHerdSource;`n    uint32 WcmeHerdTime = 0;`n" +
    "    uint32 WcmeStompBoost = 0;`n    uint32 WcmePlainsrunningStill = 0;`n    uint8 WcmeMomentumTier = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

# ---- Running speed adds the bonus on top (before slows, which reduce the total as usual)
Write-Host "Patch: Plainsrunning adds to running speed"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    // Apply strongest slow aura mod to speed`n    int32 slow = GetMaxNegativeAuraModifier(SPELL_AURA_MOD_DECREASE_SPEED);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the slow step in Unit::UpdateSpeed was not found' }
$add = "    if (mtype == MOVE_RUN && !IsMounted())`n        if (Player const* runner = ToPlayer())`n            speed += std::max(runner->WcmePlainsrunningBonus, runner->WcmeHerdBonus);`n`n"
Set-Content $file $text.Replace($anchor, $add + $anchor) -NoNewline
}

# ---- Build and drain the charge (every 250 ms)
# ---- War Stomp can be cast on the move (every player copy CoA keeps; the client patch makes the same change, and the
#      script slows the Tauren 80% while it casts)
Write-Host "Patch: War Stomp can be cast while moving"
& {
$file = 'core/src/server/game/Spells/SpellInfoCorrections.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "void SpellMgr::LoadSpellInfoCorrections()`n{`n    uint32 oldMSTime = getMSTime();`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: LoadSpellInfoCorrections was not found' }
$fix = @'

    // Wildcard: Tauren Plainsrunning (docs/race-kits.md): War Stomp can be cast while moving. Spell data loads once at
    // server start, so the setting is read then.
    if (sConfigMgr->GetOption<bool>("Racials.Plainsrunning", true))
        ApplySpellFix({ 20549, 46026, 1120549, 1146026 }, [](SpellInfo* spellInfo)
        {
            spellInfo->InterruptFlags &= ~SPELL_INTERRUPT_FLAG_MOVEMENT;
        });
'@
if (-not $text.Contains("#include `"Config.h`"`n")) {
    $first = "#include `"SpellMgr.h`"`n"
    if (-not $text.Contains($first)) { throw 'CoA changed: SpellInfoCorrections.cpp has no #include "SpellMgr.h"' }
    $text = $text.Replace($first, $first + "#include `"Config.h`"`n")
}
Set-Content $file $text.Replace($anchor, $anchor + $fix.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Plainsrunning for Tauren (Racials.Plainsrunning)"
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
// Wildcard: the racials' effects and sounds (docs/race-kits.md, chosen in game by James on 20 November). A spell
// visual kit plays on the unit for everyone nearby, and a sound beside it; 0 skips either.
namespace WcmeFx
{
    inline void Play(Unit* unit, uint32 kit, uint32 sound = 0)
    {
        if (!unit)
            return;
        if (kit)
            unit->SendPlaySpellVisual(kit);
        if (sound)
            unit->PlayDirectSound(sound);
    }
}

// Wildcard: Tauren Plainsrunning (docs/race-kits.md).
class wcme_plainsrunning : public PlayerScript
{
public:
    wcme_plainsrunning() : PlayerScript("wcme_plainsrunning", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SPELL_CAST}) { }

    static constexpr uint32 HerdBuff = 9990058;  // what group members near a running Tauren get
    static constexpr uint32 Stomping = 9990060;  // hidden: 80% slower while War Stomp casts
    static constexpr float StompBoost = 0.30f;   // War Stomp: 30% more, past the cap
    static constexpr uint32 StompTime = 5000;
    static constexpr uint32 FullSpeedFx = 4641; // a yellow shout disc with a drum: full speed, and War Stomp's boost
    static constexpr uint32 DrainDelay = 3000;  // stopped: the charge holds this long (ms)
    static constexpr float DrainTime = 10000.0f; // then full to nothing in this long (ms)
    static constexpr uint32 Momentum = 9990063;         // a third: stuns, fears and roots 15% shorter
    static constexpr uint32 Unstoppable = 9990064;      // two thirds: 25% shorter
    static constexpr uint32 UnstoppableGuard = 9990066; // hidden: 5% less damage taken, immune to slows
    static constexpr uint32 Juggernaut = 9990065;       // full: 40% shorter
    static constexpr uint32 JuggernautGuard = 9990067;  // hidden: 10% less damage taken, immune to slows and roots
    static constexpr uint32 Impact = 9990068;           // full: the next damaging attack or spell, 30% more and a knockback
    static constexpr float ImpactCost = 10.0f / 60.0f;  // Impact spends 10 sec of building (alone): back to Unstoppable

    static bool IsWarStomp(uint32 id) { return id == 20549 || id == 46026 || id == 1120549 || id == 1146026; }

    // War Stomp (every player copy CoA keeps): 30% more for 5 sec, past the cap. Shown at once.
    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (player->getRace() != RACE_TAUREN || !spell || spell->IsTriggered() || !IsWarStomp(spell->GetSpellInfo()->Id) ||
            !sConfigMgr->GetOption<bool>("Racials.Plainsrunning", true))
            return;
        player->WcmeStompBoost = StompTime;
        WcmeFx::Play(player, FullSpeedFx); // the same yellow shout disc and drum as full speed
        player->WcmePlainsrunningTimer = 250; // the next update shows it
    }
    static constexpr float HerdRange = 10.0f;
    static constexpr uint32 HerdHold = 600;      // an offer not refreshed for this long has ended (ms)

    static bool CarryingFlag(Player* player)
    {
        static constexpr std::array<uint32, 3> flags = { 23333, 23335, 34976 }; // Warsong, Silverwing, Netherstorm
        return std::any_of(flags.begin(), flags.end(), [player](uint32 id) { return player->HasAura(id); });
    }

    static uint32 Now() { return uint32(GameTime::GetGameTimeMS().count()); }

    static bool IsRunning(Player* player)
    {
        bool const onFoot = !player->IsMounted() && !player->GetVehicle() && !player->IsInFlight() && !player->IsFlying() &&
            !player->isSwimming();
        return onFoot && !player->IsWalking() && (player->isMoving() || !player->movespline->Finalized());
    }

    // Other Tauren running in the group within 10 yards, on the same map (up to 4): each adds the normal build rate.
    static uint32 HerdRunners(Player* tauren)
    {
        Group* group = tauren->GetGroup();
        if (!group)
            return 0;
        uint32 runners = 0;
        for (GroupReference* ref = group->GetFirstMember(); ref && runners < 4; ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (member && member != tauren && member->getRace() == RACE_TAUREN && member->IsInMap(tauren) &&
                member->IsAlive() && tauren->IsWithinDist(member, HerdRange) && IsRunning(member) && !CarryingFlag(member))
                ++runners;
        }
        return runners;
    }

    // A Tauren's bonus offered to a group member. The member keeps the highest Tauren's; the same Tauren's newer
    // number always replaces its own (so it drains too), and a stale offer gives way to any other.
    static void Offer(Player* member, Player* tauren, float bonus)
    {
        uint32 const now = Now();
        if (member->WcmeHerdSource == tauren->GetGUID() || bonus >= member->WcmeHerdOffer ||
            now - member->WcmeHerdTime > HerdHold)
        {
            member->WcmeHerdOffer = bonus;
            member->WcmeHerdSource = tauren->GetGUID();
            member->WcmeHerdTime = now;
        }
    }

    // Shares the Tauren's bonus with group members within 10 yards, on foot, on the same map (so the same thread).
    static void ShareWithHerd(Player* tauren)
    {
        float const bonus = tauren->WcmePlainsrunningBonus;
        Group* group = tauren->GetGroup();
        if (bonus <= 0.0f || !group)
            return;
        for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (!member || member == tauren || !member->IsInMap(tauren) || !member->IsAlive() || member->IsMounted() ||
                member->GetVehicle() || member->IsInFlight() || !tauren->IsWithinDist(member, HerdRange) ||
                CarryingFlag(member))
                continue;
            Offer(member, tauren, bonus);
        }
    }

    // Every player: applies (or ends) what nearby Tauren offer.
    static void UpdateHerd(Player* player)
    {
        uint32 const now = Now();
        bool const fresh = player->WcmeHerdOffer > 0.0f && now - player->WcmeHerdTime <= HerdHold;
        float const bonus = fresh ? player->WcmeHerdOffer : 0.0f;
        if (!fresh)
        {
            player->WcmeHerdOffer = 0.0f;
            player->WcmeHerdSource.Clear();
        }
        float const shown = player->WcmeHerdBonus;
        if (std::fabs(bonus - shown) < 0.01f && (bonus != 0.0f || shown == 0.0f))
            return;
        player->WcmeHerdBonus = bonus;
        player->UpdateSpeed(MOVE_RUN, true);
        uint8 const percent = uint8(std::min(200.0f, bonus * 100.0f + 0.5f));
        if (!percent)
            player->RemoveAurasDueToSpell(HerdBuff);
        else if (Aura* aura = player->HasAura(HerdBuff) ? player->GetAura(HerdBuff) : player->AddAura(HerdBuff, player))
            aura->SetStackAmount(percent);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        UpdateHerd(player);
        if (player->getRace() != RACE_TAUREN)
            return;
        // Moving while War Stomp casts, 80% slower, instead of the cast stopping the run.
        Spell const* casting = player->GetCurrentSpell(CURRENT_GENERIC_SPELL);
        bool const stomping = casting && IsWarStomp(casting->GetSpellInfo()->Id) &&
            casting->getState() == SPELL_STATE_PREPARING && sConfigMgr->GetOption<bool>("Racials.Plainsrunning", true);
        if (stomping != player->HasAura(Stomping))
        {
            if (stomping)
                player->AddAura(Stomping, player);
            else
                player->RemoveAurasDueToSpell(Stomping);
        }
        if (player->WcmeStompBoost)
        {
            player->WcmeStompBoost = player->WcmeStompBoost > diff ? player->WcmeStompBoost - diff : 0;
            if (!player->WcmeStompBoost)
                player->WcmePlainsrunningTimer = 250; // the boost ends: shown at once
        }
        player->WcmePlainsrunningTimer += diff;
        if (player->WcmePlainsrunningTimer < 250)
            return;
        float const elapsed = float(player->WcmePlainsrunningTimer);
        player->WcmePlainsrunningTimer = 0;

        bool const carrying = CarryingFlag(player);
        bool const enabled = sConfigMgr->GetOption<bool>("Racials.Plainsrunning", true);
        bool const running = IsRunning(player);

        float& charge = player->WcmePlainsrunningCharge;
        float const before = charge;
        if (!enabled || !player->IsAlive())
            charge = 0.0f;
        else if (running && !carrying)
        {
            charge = std::min(1.0f, charge + elapsed * float(1 + HerdRunners(player)) / 60000.0f);
            player->WcmePlainsrunningStill = 0;
        }
        else if (!carrying)
        {
            // Stopped: held for 3 sec, then full to nothing over 10 sec.
            player->WcmePlainsrunningStill += uint32(elapsed);
            if (player->WcmePlainsrunningStill > DrainDelay)
                charge = std::max(0.0f, charge - elapsed / DrainTime);
        }

        float const cap = float(std::min<uint32>(player->GetLevel(), 60) + 40) / 100.0f;
        float const boost = (enabled && player->IsAlive() && player->WcmeStompBoost) ? StompBoost : 0.0f;
        float const bonus = (carrying || player->IsMounted()) ? 0.0f : cap * charge + boost;
        float const shown = player->WcmePlainsrunningBonus;
        // Small changes wait until they add up to 1%, except at empty and at full, which always land exactly (the
        // last step to the cap is under 1%, so without this the bonus stopped just short, 49% at level 10).
        if (std::fabs(bonus - shown) >= 0.01f || (bonus != shown && (bonus == 0.0f || charge >= 1.0f)))
        {
            player->WcmePlainsrunningBonus = bonus;
            player->UpdateSpeed(MOVE_RUN, true);
            // The buff (our spell 9990001, client patch): its stack count is the bonus in percent.
            constexpr uint32 buff = 9990001;
            uint8 const percent = uint8(std::min(200.0f, bonus * 100.0f + 0.5f));
            if (!percent)
                player->RemoveAurasDueToSpell(buff);
            else if (Aura* aura = player->HasAura(buff) ? player->GetAura(buff) : player->AddAura(buff, player))
                aura->SetStackAmount(percent);
        }
        UpdateJuggernaut(player, (enabled && player->IsAlive() && !carrying && !player->IsMounted()) ? charge : 0.0f);
        if (enabled)
            ShareWithHerd(player);
    }

    // Juggernaut: the tier buffs for how full the charge is, kept in place every update (a dispel or a purge doesn't
    // stick), and Impact at full. Each new tier reached plays the shout disc and drum.
    static void UpdateJuggernaut(Player* player, float charge)
    {
        uint8 const tier = charge >= 1.0f ? 3 : charge >= 2.0f / 3.0f ? 2 : charge >= 1.0f / 3.0f ? 1 : 0;
        static constexpr std::array<std::array<uint32, 2>, 4> Wanted = {{ {0, 0}, {Momentum, 0},
            {Unstoppable, UnstoppableGuard}, {Juggernaut, JuggernautGuard} }};
        for (uint32 spell : { Momentum, Unstoppable, UnstoppableGuard, Juggernaut, JuggernautGuard })
        {
            bool const want = spell == Wanted[tier][0] || spell == Wanted[tier][1];
            if (want != player->HasAura(spell))
            {
                if (want)
                    player->AddAura(spell, player);
                else
                    player->RemoveAurasDueToSpell(spell);
            }
        }
        if (tier < 3)
            player->RemoveAurasDueToSpell(Impact);
        else if (!player->HasAura(Impact))
            player->AddAura(Impact, player);
        if (tier > player->WcmeMomentumTier)
            WcmeFx::Play(player, FullSpeedFx); // a new tier: Momentum, Unstoppable or Juggernaut
        player->WcmeMomentumTier = tier;
    }
};

// Wildcard: Juggernaut's Impact (docs/race-kits.md): the hit that uses it (its 30% more damage is the buff's own) knocks
// the target back, unless it's a boss, immune to being moved, or the hit kills it, and spends 10 sec of the run's
// building: the Tauren drops back to Unstoppable and runs back up to full for the next one.
class wcme_juggernaut_impact : public UnitScript
{
public:
    wcme_juggernaut_impact() : UnitScript("wcme_juggernaut_impact", true, {UNITHOOK_ON_DAMAGE}) { }

    void OnDamage(Unit* attacker, Unit* victim, uint32& damage) override
    {
        if (!attacker || !victim || attacker == victim || !damage)
            return;
        Player* tauren = attacker->ToPlayer();
        if (!tauren || !tauren->HasAura(wcme_plainsrunning::Impact))
            return;
        tauren->RemoveAurasDueToSpell(wcme_plainsrunning::Impact);
        tauren->WcmePlainsrunningCharge = std::max(0.0f, tauren->WcmePlainsrunningCharge - wcme_plainsrunning::ImpactCost);
        tauren->WcmePlainsrunningTimer = 250; // the next update shows the lower speed and tier
        Creature* creature = victim->ToCreature();
        bool const boss = creature && (creature->isWorldBoss() || creature->IsDungeonBoss() ||
            creature->GetCreatureTemplate()->rank == CREATURE_ELITE_WORLDBOSS);
        if (!boss && victim->IsAlive() && damage < victim->GetHealth())
        {
            bool const player = victim->GetTypeId() == TYPEID_PLAYER;
            victim->KnockbackFrom(tauren->GetPositionX(), tauren->GetPositionY(), player ? 6.0f : 10.0f, player ? 3.0f : 5.0f);
        }
    }
};

'@
$text = $text.Replace($include, $include + "#include `"GameTime.h`"`n#include `"Group.h`"`n#include `"MoveSpline.h`"`n#include `"Spell.h`"`n#include `"SpellAuras.h`"`n#include `"SpellInfo.h`"`n#include `"UnitScript.h`"`n#include <cmath>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_plainsrunning();`n    new wcme_juggernaut_impact();`n")
Set-Content $file $text -NoNewline
}
