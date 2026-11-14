# Tauren signature racial: Plainsrunning (docs/race-kits.md). Running on foot builds speed over 60 sec up to level + 40%
# (100% at level 60); it drains in 6 sec when you stop; it adds on top of other speed effects (Sprint's +70% and a full
# +100% make +170%). Nothing while mounted; held, but not applied, while carrying a battleground flag. The buff icon is our
# spell 9990001 (sql/enchants/150-custom-spells.sql and the client patch, client-patch/custom_spells.py).
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
$add = "    float WcmePlainsrunningCharge = 0.0f;`n    float WcmePlainsrunningBonus = 0.0f;`n    uint32 WcmePlainsrunningTimer = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

# ---- Running speed adds the bonus on top (before slows, which reduce the total as usual)
Write-Host "Patch: Plainsrunning adds to running speed"
& {
$file = 'core/src/server/game/Entities/Unit/Unit.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "    // Apply strongest slow aura mod to speed`n    int32 slow = GetMaxNegativeAuraModifier(SPELL_AURA_MOD_DECREASE_SPEED);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the slow step in Unit::UpdateSpeed was not found' }
$add = "    if (mtype == MOVE_RUN && !IsMounted())`n        if (Player const* runner = ToPlayer())`n            speed += runner->WcmePlainsrunningBonus;`n`n"
Set-Content $file $text.Replace($anchor, $add + $anchor) -NoNewline
}

# ---- Build and drain the charge (every 250 ms)
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
// Wildcard: Tauren Plainsrunning (docs/race-kits.md).
class wcme_plainsrunning : public PlayerScript
{
public:
    wcme_plainsrunning() : PlayerScript("wcme_plainsrunning", {PLAYERHOOK_ON_UPDATE}) { }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_TAUREN)
            return;
        player->WcmePlainsrunningTimer += diff;
        if (player->WcmePlainsrunningTimer < 250)
            return;
        float const elapsed = float(player->WcmePlainsrunningTimer);
        player->WcmePlainsrunningTimer = 0;

        static constexpr std::array<uint32, 3> flags = { 23333, 23335, 34976 }; // Warsong, Silverwing, Netherstorm
        bool const carrying = std::any_of(flags.begin(), flags.end(), [player](uint32 id) { return player->HasAura(id); });
        bool const enabled = sConfigMgr->GetOption<bool>("Racials.Plainsrunning", true);
        bool const onFoot = !player->IsMounted() && !player->GetVehicle() && !player->IsInFlight() && !player->IsFlying() &&
            !player->isSwimming();
        bool const running = onFoot && !player->IsWalking() && (player->isMoving() || !player->movespline->Finalized());

        float& charge = player->WcmePlainsrunningCharge;
        if (!enabled || !player->IsAlive())
            charge = 0.0f;
        else if (running && !carrying)
            charge = std::min(1.0f, charge + elapsed / 60000.0f);
        else if (!carrying)
            charge = std::max(0.0f, charge - elapsed / 6000.0f);

        float const cap = float(std::min<uint32>(player->GetLevel(), 60) + 40) / 100.0f;
        float const bonus = (carrying || player->IsMounted()) ? 0.0f : cap * charge;
        float const shown = player->WcmePlainsrunningBonus;
        if (std::fabs(bonus - shown) >= 0.01f || (bonus == 0.0f && shown != 0.0f))
        {
            player->WcmePlainsrunningBonus = bonus;
            player->UpdateSpeed(MOVE_RUN, true);
            // The buff (our spell 9990001, client patch): its stack count is the bonus in percent.
            constexpr uint32 buff = 9990001;
            uint8 const percent = uint8(std::min(100.0f, bonus * 100.0f + 0.5f));
            if (!percent)
                player->RemoveAurasDueToSpell(buff);
            else if (Aura* aura = player->HasAura(buff) ? player->GetAura(buff) : player->AddAura(buff, player))
                aura->SetStackAmount(percent);
        }
    }
};

'@
$text = $text.Replace($include, $include + "#include `"MoveSpline.h`"`n#include `"SpellAuras.h`"`n#include <cmath>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_plainsrunning();`n")
Set-Content $file $text -NoNewline
}
