# Gnome signature racial: Overclock (docs/race-kits.md), replacing the stock Expansive Mind passive (20591, 5% more
# Intellect). The endurance king for resources: +5% maximum mana, rage, energy and runic power (buff 9990040, and
# hidden 9990041 for runic power). Every 15 sec in combat, another step, up to 10 (buff 9990042, whose stack count is
# the steps; hidden 9990043 carries the frost runes): abilities cost 1% less per step, whatever resource they use, and
# runes recharge 1% faster per step, and each step tops you up by its number in percent of every resource you have
# (1% at the first step up to 10% at the tenth, 55% in all). After 10 steps (2 min 30 sec) it stops and the 10% stays
# for the rest of the fight. Resets when combat ends. Escape Artist also gives +60% movement speed for 3 sec (9990044).
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
    static constexpr uint32 StepTime = 15000;

    static bool Enabled() { return sConfigMgr->GetOption<bool>("Racials.Overclock", true); }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_GNOME)
            return;
        if (!Enabled())
        {
            for (uint32 spell : {Pools, PoolsRunic, Steps, StepsFrost})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
            player->WcmeOverclockSteps = 0;
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
        {
            Reset(player);
            return;
        }
        for (uint32 spell : {Pools, PoolsRunic})
            if (!player->HasAura(spell))
                player->AddAura(spell, player);

        if (!player->IsInCombat())
        {
            Reset(player);
            return;
        }
        if (player->WcmeOverclockSteps >= MaxSteps)
            return; // learned all it can: the 10% stays for the rest of the fight
        player->WcmeOverclockTimer += diff;
        if (player->WcmeOverclockTimer < StepTime)
            return;
        player->WcmeOverclockTimer -= StepTime;
        uint8 const step = ++player->WcmeOverclockSteps;
        for (uint32 spell : {Steps, StepsFrost})
        {
            Aura* aura = player->GetAura(spell);
            if (!aura)
                aura = player->AddAura(spell, player);
            if (aura && aura->GetStackAmount() != step)
                aura->SetStackAmount(step);
        }
        // Topped up by the step's number in percent of every resource the player has.
        for (Powers power : {POWER_MANA, POWER_RAGE, POWER_ENERGY, POWER_RUNIC_POWER})
            if (uint32 const max = player->GetMaxPower(power))
                if (uint32 const amount = CalculatePct(max, step))
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
    }

private:
    static constexpr std::array<uint32, 2> StockSpells = {20591, 1120591}; // Expansive Mind (stock, and CoA's copy)

    // Combat over (or death): the steps start again from nothing.
    static void Reset(Player* player)
    {
        player->WcmeOverclockSteps = 0;
        player->WcmeOverclockTimer = 0;
        for (uint32 spell : {Steps, StepsFrost})
            if (player->HasAura(spell))
                player->RemoveAurasDueToSpell(spell);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Spell.h`"`n#include `"SpellAuras.h`"`n#include `"SpellInfo.h`"`n#include <array>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_overclock();`n")
Set-Content $file $text -NoNewline
}
