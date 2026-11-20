# Orc signature racial: Bloodrush (docs/race-kits.md). Relentless but reckless. For each enemy in combat with you, +2%
# damage, up to 5 enemies, gone out of combat. Each killing blow adds a stack of Rush, up to 5, lasting 15 sec in or out
# of combat (each kill starts the 15 sec again): per stack +10% movement speed on foot (on top of Sprint and the like)
# and +2% haste, and 2% more damage taken. The buffs are our spells 9990002 (stacks = enemies), 9990003 (Rush, stacks =
# kills) and hidden 9990056 (Rush's damage taken, kept at Rush's stacks). Blood Fury also adds a stack of Rush and starts
# its 15 sec again (James, 20 November): sql/enchants/150-custom-spells.sql and the client patch
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
    wcme_bloodrush() : PlayerScript("wcme_bloodrush", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_PVP_KILL,
        PLAYERHOOK_ON_SPELL_CAST}) { }

    static constexpr uint32 Stacks = 9990002;
    static constexpr uint32 Rush = 9990003;      // per stack: +10% speed on foot, +2% haste
    static constexpr uint32 Reckless = 9990056;  // per stack: 2% more damage taken (hidden, follows Rush)
    static constexpr uint8 MaxRush = 5;
    static constexpr int32 RushTime = 15000;

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
                // Not friendly, rather than hostile: a neutral (yellow) mob you are fighting is still an enemy.
                if (Unit* other = ref->GetOther(player); other && other->IsAlive() && !player->IsFriendlyTo(other))
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
        if (!Applies(player))
            for (uint32 spell : {Rush, Reckless})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
        FollowRush(player);
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

    // Blood Fury (every player copy CoA keeps) adds a stack of Rush, as a kill does.
    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (!spell || spell->IsTriggered())
            return;
        switch (spell->GetSpellInfo()->Id)
        {
            case 20572: case 33697: case 33702: case 760344: case 814283: case 814284: case 814285: case 1120572:
            case 1133697: case 1133702:
                Kill(player);
                break;
            default:
                break;
        }
    }

    void OnPlayerCreatureKill(Player* killer, Creature* /*killed*/) override { Kill(killer); }
    void OnPlayerPVPKill(Player* killer, Player* killed) override
    {
        if (killer != killed)
            Kill(killer);
    }

private:
    // One more stack of Rush (up to 5), and a fresh 15 sec.
    static void Kill(Player* killer)
    {
        if (!killer || !Applies(killer) || !killer->IsAlive())
            return;
        Aura* aura = killer->GetAura(Rush);
        bool const first = !aura;
        uint8 const had = aura ? aura->GetStackAmount() : 0;
        if (!aura)
            aura = killer->AddAura(Rush, killer);
        else if (aura->GetStackAmount() < MaxRush)
            aura->SetStackAmount(aura->GetStackAmount() + 1);
        if (!aura)
            return;
        if (first)
            WcmeFx::Play(killer, 4010); // Death Wish's red flash; the Rush buff then wears its looping red hands
        else if (had < MaxRush && aura->GetStackAmount() >= MaxRush)
            WcmeFx::Play(killer, 9990102, 306097); // full Rush: Bloodlust's head burst (silent copy), the modern war shout
        aura->SetMaxDuration(RushTime);
        aura->SetDuration(RushTime);
        FollowRush(killer);
    }

    // The damage taken rides on its own hidden aura (a harmful effect would make Rush show as a debuff), kept at Rush's
    // stacks and gone with it; put back if something removed it.
    static void FollowRush(Player* player)
    {
        Aura const* rush = player->GetAura(Rush);
        uint8 const stacks = (rush && player->IsAlive()) ? rush->GetStackAmount() : 0;
        Aura* reckless = player->GetAura(Reckless);
        if (!stacks)
        {
            if (reckless)
                player->RemoveAura(reckless);
            return;
        }
        if (!reckless)
            reckless = player->AddAura(Reckless, player);
        if (reckless && reckless->GetStackAmount() != stacks)
            reckless->SetStackAmount(stacks);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Spell.h`"`n#include `"SpellInfo.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_bloodrush();`n")
Set-Content $file $text -NoNewline
}
