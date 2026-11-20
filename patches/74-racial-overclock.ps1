# Gnome signature racial: Overclock (docs/race-kits.md), replacing the stock Expansive Mind passive (20591, 5% more
# Intellect). The endurance king for resources: +5% maximum mana, rage, energy and runic power (hidden buffs 9990040
# and 9990041, so nothing shows on the buff bar for it). A turbo cycle, like a CPU boosting and cooling down: every
# 5 sec in combat another step, up to 10 (buff 9990042, whose stack count is the steps; hidden 9990043 carries the frost
# runes): abilities cost 1% less per step, whatever resource they use, runes recharge 1% faster per step, and each
# step tops up 1% of every resource you have. After 10 sec at 10 steps it cools down to nothing and climbs again, so a
# minute of combat is one cycle (10% topped up). The cycle only runs in combat: out of combat it holds where it is,
# through death too, so the next pull starts where the last fight left off. Logging out starts it from nothing.
# Escape Artist also gives +60% movement speed for 3 sec (9990044).
# The spells are in sql/enchants/150-custom-spells.sql and the client patch (client-patch/custom_spells.py, which also
# gives Escape Artist its rocket boot icon). Run by the build from the workspace root, after 40-battlegrounds.ps1.
# Throws if an anchor is gone. Listed in CHANGES.md. Racials.Overclock = 0 turns it off (and gives back Expansive Mind).
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Overclock state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint32 WcmeOverclockTimer = 0;`n    uint8 WcmeOverclockSteps = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Overclock for Gnomes (Racials.Overclock)"
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
// Wildcard: Gnome Overclock (docs/race-kits.md).
class wcme_overclock : public PlayerScript
{
public:
    wcme_overclock() : PlayerScript("wcme_overclock", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SPELL_CAST}) { }

    static constexpr uint32 Pools = 9990040;       // +5% maximum mana, rage and energy
    static constexpr uint32 PoolsRunic = 9990041;  // +5% maximum runic power
    static constexpr uint32 Steps = 9990042;       // per stack: costs 1% less, blood and unholy runes 1% faster
    static constexpr uint32 StepsFrost = 9990043;  // per stack: frost runes 1% faster
    static constexpr uint32 Speed = 9990044;       // Escape Artist: +60% movement speed for 3 sec
    static constexpr uint8 MaxSteps = 10;
    static constexpr uint32 StepTime = 5000;   // a step every 5 sec in combat
    static constexpr uint32 PeakTime = 10000;  // then 10 sec at 10 steps before it cools down and climbs again

    static bool Enabled() { return sConfigMgr->GetOption<bool>("Racials.Overclock", true); }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_GNOME)
            return;
        if (!Enabled())
        {
            for (uint32 spell : {Pools, PoolsRunic})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
            SetSteps(player, 0);
            player->WcmeOverclockTimer = 0;
            for (uint32 stock : StockSpells)
                if (player->HasSpell(stock) && !player->HasAura(stock))
                    player->AddAura(stock, player);
            return;
        }
        for (uint32 stock : StockSpells)
            if (player->HasAura(stock))
                player->RemoveAurasDueToSpell(stock);
        if (!player->IsAlive())
            return; // held through death: put back on when alive again
        for (uint32 spell : {Pools, PoolsRunic})
            if (!player->HasAura(spell))
                player->AddAura(spell, player);
        SetSteps(player, player->WcmeOverclockSteps); // puts the buff back if something removed it

        if (!player->IsInCombat())
            return; // out of combat the cycle holds where it is

        player->WcmeOverclockTimer += diff;
        if (player->WcmeOverclockSteps >= MaxSteps)
        {
            if (player->WcmeOverclockTimer < PeakTime)
                return;
            player->WcmeOverclockTimer = 0; // cooled down: climb again from nothing
            SetSteps(player, 0);
            WcmeFx::Play(player, 0, 126580); // a small electrical zap
            return;
        }
        if (player->WcmeOverclockTimer < StepTime)
            return;
        player->WcmeOverclockTimer -= StepTime;
        SetSteps(player, player->WcmeOverclockSteps + 1);
        if (player->WcmeOverclockSteps >= MaxSteps)
            WcmeFx::Play(player, 2432); // step 10: a spark nova
        // Each step tops up 1% of every resource the player has.
        for (Powers power : {POWER_MANA, POWER_RAGE, POWER_ENERGY, POWER_RUNIC_POWER})
            if (uint32 const max = player->GetMaxPower(power))
                if (uint32 const amount = CalculatePct(max, 1))
                    player->EnergizeBySpell(player, Steps, amount, power);
    }

    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (player->getRace() != RACE_GNOME || !spell || spell->IsTriggered() || !Enabled())
            return;
        uint32 const id = spell->GetSpellInfo()->Id;
        if (id != 20589 && id != 1120589 && id != 830589) // Escape Artist (stock, and CoA's copies)
            return;
        if (Aura* aura = player->AddAura(Speed, player))
        {
            aura->SetMaxDuration(3000);
            aura->SetDuration(3000);
        }
        WcmeFx::Play(player, 1168); // the rocket boots' ignition; the speed buff wears their fire hands and trail
    }

private:
    static constexpr std::array<uint32, 2> StockSpells = {20591, 1120591}; // Expansive Mind (stock, and CoA's copy)

    // The steps, and the buffs that show and carry them (none at 0).
    static void SetSteps(Player* player, uint8 steps)
    {
        player->WcmeOverclockSteps = steps;
        for (uint32 spell : {Steps, StepsFrost})
        {
            if (!steps)
            {
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
                continue;
            }
            Aura* aura = player->GetAura(spell);
            if (!aura)
                aura = player->AddAura(spell, player);
            if (aura && aura->GetStackAmount() != steps)
                aura->SetStackAmount(steps);
        }
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Spell.h`"`n#include `"SpellAuras.h`"`n#include `"SpellInfo.h`"`n#include <array>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_overclock();`n")
Set-Content $file $text -NoNewline
}
