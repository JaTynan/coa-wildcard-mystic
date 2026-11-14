# Draenei signature racial: Radiant Presence (docs/race-kits.md). In combat, gain a stack of Light every 6 sec, up to 5.
# Each stack gives you and every ally within 30 yards (group or raid members, their pets and guardians) +1% damage and
# healing and 1% less damage taken. Stacks fade 10 sec after combat. A second Draenei doesn't add more: everyone keeps
# the highest count near them. Your auras and totems reach 50% further. The buff is our spell 9990008
# (sql/enchants/150-custom-spells.sql and the client patch, client-patch/custom_spells.py, which also adds its icon).
# Run by the build from the workspace root, after 40-battlegrounds.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
# Racials.RadiantPresence = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Radiant Presence state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint8 WcmeRadiantStacks = 0;`n    uint32 WcmeRadiantStackTimer = 0;`n    uint32 WcmeRadiantFade = 0;`n    uint32 WcmeRadiantPulse = 0;`n    bool WcmeRadiantReach = false;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

# ---- Auras and totems reach 50% further (area auras of any family, and anything a totem casts)
Write-Host "Patch: Radiant Presence widens auras and totems"
& {
$file = 'core/src/server/game/Spells/SpellInfo.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "        if (Player* modOwner = caster->GetSpellModOwner())`n            modOwner->ApplySpellMod(_spellInfo->Id, SPELLMOD_RADIUS, radius, spell);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the radius spell mod in SpellEffectInfo::CalcRadius was not found' }
$new = @'
        if (Player* modOwner = caster->GetSpellModOwner())
        {
            modOwner->ApplySpellMod(_spellInfo->Id, SPELLMOD_RADIUS, radius, spell);
            if (modOwner->WcmeRadiantReach && (IsAreaAuraEffect() || caster->IsTotem()))
                radius *= 1.5f; // Wildcard: Draenei Radiant Presence
        }

'@
Set-Content $file $text.Replace($anchor, $new.Replace("`r`n", "`n")) -NoNewline
}

# ---- Build the stacks and share them (every 1 sec)
Write-Host "Patch: Radiant Presence for Draenei (Racials.RadiantPresence)"
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
// Wildcard: Draenei Radiant Presence (docs/race-kits.md).
class wcme_radiant_presence : public PlayerScript
{
public:
    wcme_radiant_presence() : PlayerScript("wcme_radiant_presence", {PLAYERHOOK_ON_UPDATE}) { }

    static constexpr uint32 Light = 9990008;
    static constexpr uint8 MaxStacks = 5;
    static constexpr float Range = 30.0f;

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_DRAENEI)
            return;
        player->WcmeRadiantReach = sConfigMgr->GetOption<bool>("Racials.RadiantPresence", true);
        if (!player->WcmeRadiantReach || !player->IsAlive())
        {
            // Nothing more is shared; the buffs this player gave run out within 3 sec.
            player->WcmeRadiantStacks = 0;
            player->WcmeRadiantStackTimer = player->WcmeRadiantFade = player->WcmeRadiantPulse = 0;
            return;
        }
        if (player->IsInCombat())
        {
            player->WcmeRadiantFade = 0;
            if (player->WcmeRadiantStacks < MaxStacks)
            {
                player->WcmeRadiantStackTimer += diff;
                if (player->WcmeRadiantStackTimer >= 6000)
                {
                    player->WcmeRadiantStackTimer -= 6000;
                    ++player->WcmeRadiantStacks;
                    player->WcmeRadiantPulse = 1000; // share the new stack straight away
                }
            }
            else
                player->WcmeRadiantStackTimer = 0;
        }
        else
        {
            player->WcmeRadiantStackTimer = 0;
            if (player->WcmeRadiantStacks)
            {
                player->WcmeRadiantFade += diff;
                if (player->WcmeRadiantFade >= 10000)
                {
                    player->WcmeRadiantStacks = 0;
                    player->WcmeRadiantFade = 0;
                }
            }
        }
        if (!player->WcmeRadiantStacks)
        {
            player->WcmeRadiantPulse = 0;
            return;
        }
        player->WcmeRadiantPulse += diff;
        if (player->WcmeRadiantPulse < 1000)
            return;
        player->WcmeRadiantPulse = 0;

        std::list<Unit*> allies;
        Acore::AnyGroupedUnitInObjectRangeCheck check(player, player, Range, true);
        Acore::UnitListSearcher<Acore::AnyGroupedUnitInObjectRangeCheck> searcher(player, allies, check);
        Cell::VisitObjects(player, searcher, Range);
        allies.remove(player);
        allies.push_back(player);
        for (Unit* ally : allies)
            Shine(ally, player->WcmeRadiantStacks);
    }

private:
    // One Light buff per unit, cast on itself, so two Draenei never add up: the higher count stays. It lasts 3 sec
    // (the timer is hidden) and every Draenei in range renews it each second, so it goes soon after they leave.
    static void Shine(Unit* ally, uint8 stacks)
    {
        Aura* aura = ally->GetAura(Light);
        if (aura && aura->GetStackAmount() > stacks)
            return;
        if (!aura)
            aura = ally->AddAura(Light, ally);
        if (!aura)
            return;
        if (aura->GetStackAmount() != stacks)
            aura->SetStackAmount(stacks);
        aura->SetMaxDuration(3000);
        aura->SetDuration(3000);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"CellImpl.h`"`n#include `"GridNotifiers.h`"`n#include `"GridNotifiersImpl.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_radiant_presence();`n")
Set-Content $file $text -NoNewline
}
