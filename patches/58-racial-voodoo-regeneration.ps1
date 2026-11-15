# Troll signature racial: Voodoo Regeneration (docs/race-kits.md), replacing the stock Regeneration passive (20555).
# Out of combat, health regenerates 50% faster (our passive 9990005). In combat, regenerate 0.3% of maximum health per
# second, halved while the burst is on cooldown. Below 35% health, regenerate 28% of maximum health over 5 sec
# (buff 9990006), once every 2 min (cooldown marker 9990007). The spells are in sql/enchants/150-custom-spells.sql and
# the client patch (client-patch/custom_spells.py). Run by the build from the workspace root, after
# 40-battlegrounds.ps1 and 54-racial-plainsrunning.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
# The in-combat regen and the burst take percentage healing reductions and increases, like a heal.
# Racials.VoodooRegeneration = 0 turns it off (and gives back the stock passive).
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Voodoo Regeneration state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint32 WcmeVoodooTimer = 0;`n    float WcmeVoodooCarry = 0.0f;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Voodoo Regeneration for Trolls (Racials.VoodooRegeneration)"
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
// Wildcard: Troll Voodoo Regeneration (docs/race-kits.md).
class wcme_voodoo_regeneration : public PlayerScript
{
public:
    wcme_voodoo_regeneration() : PlayerScript("wcme_voodoo_regeneration", {PLAYERHOOK_ON_UPDATE}) { }

    static constexpr uint32 Stock = 20555;
    static constexpr uint32 Passive = 9990005;
    static constexpr uint32 Burst = 9990006;
    static constexpr uint32 Cooldown = 9990007;

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_TROLL)
            return;
        if (!sConfigMgr->GetOption<bool>("Racials.VoodooRegeneration", true))
        {
            for (uint32 spell : {Passive, Burst})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
            if (player->HasSpell(Stock) && !player->HasAura(Stock))
                player->AddAura(Stock, player);
            return;
        }
        if (player->HasAura(Stock))
            player->RemoveAurasDueToSpell(Stock);
        if (!player->HasAura(Passive))
            player->AddAura(Passive, player);
        if (!player->IsAlive())
        {
            player->WcmeVoodooTimer = 0;
            player->WcmeVoodooCarry = 0.0f;
            return;
        }
        if (player->HealthBelowPct(35) && !player->HasAura(Cooldown))
        {
            Lasting(player, Burst, 5000);
            Lasting(player, Cooldown, 120000);
        }
        player->WcmeVoodooTimer = std::min<uint32>(player->WcmeVoodooTimer + diff, 5000);
        for (; player->WcmeVoodooTimer >= 1000; player->WcmeVoodooTimer -= 1000)
        {
            float percent = player->HasAura(Burst) ? 5.6f : 0.0f;  // 28% over the 5 sec
            if (player->IsInCombat())
                percent += player->HasAura(Cooldown) ? 0.15f : 0.3f;
            // Fractions carry over to the next second instead of rounding up to 1, which at low level was many
            // times the intended rate (0.1 health a second at 68 health became 1).
            if (percent <= 0.0f || player->IsFullHealth())
            {
                player->WcmeVoodooCarry = 0.0f;
                continue;
            }
            player->WcmeVoodooCarry += float(player->GetMaxHealth()) * percent / 100.0f * HealingTaken(player);
            int32 const whole = int32(player->WcmeVoodooCarry);
            if (whole > 0)
            {
                player->WcmeVoodooCarry -= float(whole);
                player->ModifyHealth(whole);
            }
        }
    }

private:
    // The percentage changes to healing received (Mortal Strike and the like, and healing-received buffs), as a heal
    // would take them; no flat bonus healing or spell power, so it never scales with gear.
    static float HealingTaken(Player* player)
    {
        float factor = 1.0f;
        if (int32 const reduced = player->GetMaxNegativeAuraModifier(SPELL_AURA_MOD_HEALING_PCT))
            AddPct(factor, reduced);
        int32 const raised = player->GetMaxPositiveAuraModifier(SPELL_AURA_MOD_HEALING_PCT,
            [](AuraEffect const* effect)
            {
                // Nature's Call rank two raises only healing from others (as in Unit::SpellHealingBonusTaken).
                return effect->GetId() != 707807 || effect->GetSpellInfo()->SpellFamilyName != 37;
            });
        if (raised)
            AddPct(factor, raised);
        factor *= player->GetTotalAuraMultiplier(SPELL_AURA_ASCENSION_MOD_HEALING_RECEIVED_PCT);
        return std::max(0.0f, factor);
    }

    static void Lasting(Player* player, uint32 spell, int32 duration)
    {
        if (Aura* aura = player->AddAura(spell, player))
        {
            aura->SetMaxDuration(duration);
            aura->SetDuration(duration);
        }
    }
};

'@
$text = $text.Replace($include, $include + "#include `"SpellAuraEffects.h`"`n#include `"SpellInfo.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_voodoo_regeneration();`n")
Set-Content $file $text -NoNewline
}
