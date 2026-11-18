# Blood Elf signature racial: Arcane Hunger (docs/race-kits.md). Each ability or spell you use adds a stack, up to 10
# (buff 9990046, with hidden 9990048 for the damage taken): per stack, abilities deal and heal 1.5% more, cost 2% more,
# and you take 0.5% less damage (at 10: +15% damage and healing, 5% less damage taken, +20% cost; James, 18 November).
# Aura amounts are whole percents, so the halves round up as stacks build: damage and healing +2, 3, 5, 6, 8, 9, 11,
# 12, 14, 15%; damage taken -1, 1, 2, 2, 3, 3, 4, 4, 5, 5%. Stop using abilities for 5 sec and the stacks fall off
# (casting or channelling keeps them). Arcane Torrent
# eats every stack: besides its own effects (the silence and CoA's restore), it restores 2% of every resource you have
# (mana, rage, energy, runic power) per stack eaten (20% at 10), and its cooldown drops from 2 min to 1 min.
# A stack is added just after the ability, so it counts from the next one. Not counted: triggered spells, passives,
# items (potions, trinkets), auto attack and auto-repeat shots, and Arcane Torrent itself.
# The buff is in sql/enchants/150-custom-spells.sql and the client patch (client-patch/custom_spells.py; the client
# shows the 1 min cooldown too, client-patch/racials.py). Run by the build from the workspace root, after
# 40-battlegrounds.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
# Racials.ArcaneHunger = 0 turns it off (the cooldown follows the setting at server start).
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Arcane Hunger state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint8 WcmeHungerPending = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

# ---- Arcane Torrent's cooldown: 1 min (every player copy CoA keeps)
Write-Host "Patch: Arcane Hunger shortens Arcane Torrent's cooldown"
& {
$file = 'core/src/server/game/Spells/SpellInfoCorrections.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "void SpellMgr::LoadSpellInfoCorrections()`n{`n    uint32 oldMSTime = getMSTime();`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: LoadSpellInfoCorrections was not found' }
$fix = @'

    // Wildcard: Blood Elf Arcane Hunger (docs/race-kits.md): Arcane Torrent's cooldown is 1 min. Spell data loads once
    // at server start, so the setting is read then.
    if (sConfigMgr->GetOption<bool>("Racials.ArcaneHunger", true))
        ApplySpellFix({ 28730, 50613, 814286, 814287, 814288, 814289, 814290, 814291, 814292, 1125046, 1125047, 1128730,
                        1150613 }, [](SpellInfo* spellInfo)
        {
            spellInfo->RecoveryTime = 60000;
        });
'@
if (-not $text.Contains("#include `"Config.h`"`n")) {
    $first = "#include `"SpellMgr.h`"`n"
    if (-not $text.Contains($first)) { throw 'CoA changed: SpellInfoCorrections.cpp has no #include "SpellMgr.h"' }
    $text = $text.Replace($first, $first + "#include `"Config.h`"`n")
}
Set-Content $file $text.Replace($anchor, $anchor + $fix.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Arcane Hunger for Blood Elves (Racials.ArcaneHunger)"
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
// Wildcard: Blood Elf Arcane Hunger (docs/race-kits.md).
class wcme_arcane_hunger : public PlayerScript
{
public:
    wcme_arcane_hunger() : PlayerScript("wcme_arcane_hunger", {PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SPELL_CAST}) { }

    static constexpr uint32 Hunger = 9990046;  // per stack: +1.5% damage and healing done, +2% ability costs
    static constexpr uint32 Ward = 9990048;    // per stack: 0.5% less damage taken
    static constexpr uint8 MaxStacks = 10;
    static constexpr int32 FadeTime = 5000;

    static bool Enabled() { return sConfigMgr->GetOption<bool>("Racials.ArcaneHunger", true); }

    static bool IsArcaneTorrent(uint32 id)
    {
        switch (id)
        {
            case 28730: case 50613: case 814286: case 814287: case 814288: case 814289: case 814290: case 814291:
            case 814292: case 1125046: case 1125047: case 1128730: case 1150613:
                return true;
            default:
                return false;
        }
    }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (player->getRace() != RACE_BLOODELF)
            return;
        if (!Enabled() || !player->IsAlive())
        {
            player->WcmeHungerPending = 0;
            for (uint32 spell : {Hunger, Ward})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
            return;
        }
        Aura* aura = player->GetAura(Hunger);
        if (!aura && !player->WcmeHungerPending && player->HasAura(Ward))
            player->RemoveAurasDueToSpell(Ward); // the stacks fell off
        if (player->WcmeHungerPending)
        {
            uint8 const have = aura ? aura->GetStackAmount() : 0;
            uint8 const stacks = uint8(std::min<uint32>(have + player->WcmeHungerPending, MaxStacks));
            player->WcmeHungerPending = 0;
            if (!aura)
                aura = player->AddAura(Hunger, player);
            if (!aura)
                return;
            if (aura->GetStackAmount() != stacks)
                aura->SetStackAmount(stacks);
            aura->SetMaxDuration(FadeTime);
            aura->SetDuration(FadeTime);
            SetAmounts(player, aura, stacks);
            return;
        }
        // Still casting or channelling counts as using an ability: the stacks don't fall off mid-spell.
        if (aura && aura->GetDuration() < FadeTime - 500 && player->IsNonMeleeSpellCast(false, false, true))
            aura->SetDuration(FadeTime);
    }

    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        if (player->getRace() != RACE_BLOODELF || !spell || !Enabled())
            return;
        SpellInfo const* info = spell->GetSpellInfo();
        if (spell->IsTriggered() || info->IsPassive() || spell->m_CastItem || info->IsAutoRepeatRangedSpell() ||
            info->HasEffect(SPELL_EFFECT_ATTACK))
            return;
        if (!IsArcaneTorrent(info->Id))
        {
            ++player->WcmeHungerPending; // added just after this ability, so it counts from the next one
            return;
        }
        // Arcane Torrent eats every stack: 2% of every resource the player has per stack.
        uint32 eaten = player->WcmeHungerPending;
        player->WcmeHungerPending = 0;
        if (Aura* aura = player->GetAura(Hunger))
        {
            eaten += aura->GetStackAmount();
            player->RemoveAura(aura);
        }
        if (player->HasAura(Ward))
            player->RemoveAurasDueToSpell(Ward);
        eaten = std::min<uint32>(eaten, MaxStacks);
        if (!eaten)
            return;
        for (Powers power : {POWER_MANA, POWER_RAGE, POWER_ENERGY, POWER_RUNIC_POWER})
            if (uint32 const max = player->GetMaxPower(power))
                if (uint32 const amount = CalculatePct(max, 2 * eaten))
                    player->EnergizeBySpell(player, Hunger, amount, power);
    }

private:
    // The half percents, rounded up: damage and healing 1.5% a stack, damage taken 0.5% a stack (whole percents only).
    static void SetAmounts(Player* player, Aura* hunger, uint8 stacks)
    {
        int32 const done = (3 * stacks + 1) / 2;
        for (uint8 i : {EFFECT_0, EFFECT_1})
            if (AuraEffect* effect = hunger->GetEffect(i); effect && effect->GetAmount() != done)
                effect->ChangeAmount(done);
        Aura* ward = player->GetAura(Ward);
        if (!ward)
            ward = player->AddAura(Ward, player);
        if (ward)
            if (AuraEffect* effect = ward->GetEffect(EFFECT_0))
                if (int32 const taken = -int32((stacks + 1) / 2); effect->GetAmount() != taken)
                    effect->ChangeAmount(taken);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Spell.h`"`n#include `"SpellAuraEffects.h`"`n#include `"SpellAuras.h`"`n#include `"SpellInfo.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_arcane_hunger();`n")
Set-Content $file $text -NoNewline
}
