# Orc signature racial: Bloodrush (docs/race-kits.md). For each enemy in combat with you, +2% damage and +2% haste, up to
# 5 enemies; each killing blow gives +15% movement speed for 6 sec; gone out of combat. The buffs are our spells 9990002
# (stacks = enemies) and 9990003 (speed): sql/enchants/150-custom-spells.sql and the client patch
# (client-patch/custom_spells.py). Run by the build from the workspace root, after 40-battlegrounds.ps1, whose script
# loader this registers in. Throws if an anchor is gone. Listed in CHANGES.md. Racials.Bloodrush = 0 turns it off.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Bloodrush for Orcs (Racials.Bloodrush)"
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
// Wildcard: Orc Bloodrush (docs/race-kits.md).
class wcme_bloodrush : public PlayerScript
{
public:
    wcme_bloodrush() : PlayerScript("wcme_bloodrush", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_PVP_KILL}) { }

    static constexpr uint32 Stacks = 9990002;
    static constexpr uint32 Speed = 9990003;

    static bool Applies(Player* player)
    {
        return player->getRace() == RACE_ORC && sConfigMgr->GetOption<bool>("Racials.Bloodrush", true);
    }

    static uint8 Enemies(Player* player)
    {
        uint32 enemies = 0;
        auto count = [&](auto const& refs)
        {
            for (auto const& [guid, ref] : refs)
                if (Unit* other = ref->GetOther(player); other && other->IsAlive() && player->IsHostileTo(other))
                    ++enemies;
        };
        count(player->GetCombatManager().GetPvECombatRefs());
        count(player->GetCombatManager().GetPvPCombatRefs());
        return uint8(std::min<uint32>(enemies, 5));
    }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (player->getRace() != RACE_ORC)
            return;
        uint8 const enemies = (Applies(player) && player->IsAlive() && player->IsInCombat()) ? Enemies(player) : 0;
        Aura* aura = player->GetAura(Stacks);
        if (!enemies)
        {
            if (aura)
                player->RemoveAura(aura);
            return;
        }
        if (!aura)
            aura = player->AddAura(Stacks, player);
        if (aura && aura->GetStackAmount() != enemies)
            aura->SetStackAmount(enemies);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* /*killed*/) override { Rush(killer); }
    void OnPlayerPVPKill(Player* killer, Player* killed) override
    {
        if (killer != killed)
            Rush(killer);
    }

private:
    static void Rush(Player* killer)
    {
        if (!killer || !Applies(killer) || !killer->IsAlive())
            return;
        if (Aura* aura = killer->AddAura(Speed, killer))
        {
            aura->SetMaxDuration(6000);
            aura->SetDuration(6000);
        }
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_bloodrush();`n")
Set-Content $file $text -NoNewline
}
