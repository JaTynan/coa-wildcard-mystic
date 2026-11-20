# .racial: any player can type it to see what their signature racial is doing right now, in numbers the buff icons
# can't show (docs/race-kits.md): Spellsword's spell power, attack power, critical strike and hit added; Ambush's
# recharge; Overclock's step and the time to the next; Plainsrunning's speed and the herd's; and so on for every race.
# It reads the state the racial patches keep (54 to 59, 72 to 76), so it runs after them. Run by the build from the
# workspace root, after 40-battlegrounds.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: .racial status command"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
foreach ($needed in @('WcmePlainsrunningBonus', 'WcmeMomentumTier', 'WcmeOverclockSteps', 'WcmeRadiantStacks', 'WcmeAmbushCooldown')) {
    if (-not $text.Contains($needed)) { throw "A racial patch did not run before this one: no $needed in AscensionAdventurerCache.cpp" }
}
$class = @'
// Wildcard: .racial, what your signature racial is doing right now (docs/race-kits.md).
class wcme_racial_command : public CommandScript
{
public:
    wcme_racial_command() : CommandScript("wcme_racial_command") { }

    Acore::ChatCommands::ChatCommandTable GetCommands() const override
    {
        using namespace Acore::ChatCommands;
        static ChatCommandTable commands =
        {
            { "racial", HandleRacial, SEC_PLAYER, Console::No },
        };
        return commands;
    }

private:
    static uint32 Stacks(Player* player, uint32 spell)
    {
        Aura const* aura = player->GetAura(spell);
        return aura ? aura->GetStackAmount() : 0;
    }

    // Time left on an aura, rounded up to whole seconds (0 without it).
    static uint32 Seconds(Player* player, uint32 spell)
    {
        Aura const* aura = player->GetAura(spell);
        return (aura && aura->GetDuration() > 0) ? uint32(aura->GetDuration() + 999) / 1000 : 0;
    }

    static int32 Amount(Player* player, uint32 spell, uint8 effect)
    {
        if (Aura* aura = player->GetAura(spell))
            if (AuraEffect const* eff = aura->GetEffect(effect))
                return eff->GetAmount();
        return 0;
    }

    static std::string Time(uint32 seconds)
    {
        if (seconds >= 3600)
            return std::to_string(seconds / 3600) + " h " + std::to_string(seconds % 3600 / 60) + " min";
        if (seconds >= 60)
            return std::to_string(seconds / 60) + " min " + std::to_string(seconds % 60) + " sec";
        return std::to_string(seconds) + " sec";
    }

    static std::string Percent(float value)
    {
        char buffer[16];
        std::snprintf(buffer, sizeof(buffer), "%.1f%%", value);
        return buffer;
    }

    static void Say(ChatHandler* handler, std::string const& line) { handler->SendSysMessage(line); }

    static bool HandleRacial(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!player)
            return false;
        switch (player->getRace())
        {
            case RACE_TAUREN:
            {
                Say(handler, "Plainsrunning: +" + std::to_string(uint32(player->WcmePlainsrunningBonus * 100.0f + 0.5f)) +
                    "% running speed, " + std::to_string(uint32(player->WcmePlainsrunningCharge * 100.0f + 0.5f)) +
                    "% of the way to your cap.");
                if (player->WcmeStompBoost)
                    Say(handler, "War Stomp boost: +30% for " + Time((player->WcmeStompBoost + 999) / 1000) + " more, included above.");
                {
                    static char const* const tiers[] = {
                        "none yet (Momentum at a third of the way)",
                        "Momentum: stuns, fears and roots 15% shorter (Unstoppable at two thirds)",
                        "Unstoppable: stuns, fears and roots 25% shorter, 5% less damage taken, immune to slows (Juggernaut at full)",
                        "Juggernaut: stuns, fears and roots 40% shorter, 10% less damage taken, immune to slows and roots" };
                    Say(handler, std::string("Juggernaut tier: ") + tiers[std::min<uint8>(player->WcmeMomentumTier, 3)] + ".");
                    if (player->WcmeMomentumTier >= 3)
                        Say(handler, player->HasAura(9990068) ? std::string("Impact: ready (next damaging hit +30% and a knockback).")
                            : "Impact: ready again in " + Time((player->WcmeImpactWait + 999) / 1000) + ".");
                    if (player->WcmePlainsrunningStill && player->WcmePlainsrunningCharge > 0.0f)
                        Say(handler, player->WcmePlainsrunningStill <= 3000 ? std::string("Stopped: draining starts in ") +
                            Time((3000 - player->WcmePlainsrunningStill + 999) / 1000) + "." : std::string("Stopped: draining."));
                }
                break;
            }
            case RACE_ORC:
            {
                Say(handler, "Bloodrush: " + std::to_string(Stacks(player, 9990002)) + " enemies in combat with you (+" +
                    std::to_string(2 * Stacks(player, 9990002)) + "% damage).");
                if (uint32 const rush = Stacks(player, 9990003))
                    Say(handler, "Rush: " + std::to_string(rush) + " stacks (+" + std::to_string(10 * rush) + "% speed, +" +
                        std::to_string(2 * rush) + "% haste, " + std::to_string(2 * rush) + "% more damage taken), " +
                        Time(Seconds(player, 9990003)) + " left unless you kill again.");
                else
                    Say(handler, "Rush: none. A killing blow or Blood Fury adds a stack.");
                break;
            }
            case RACE_NIGHTELF:
            {
                if (player->HasAura(9990004))
                    Say(handler, "Ambush: ready. Your next ability costs 10% less and deals or heals 50% more.");
                else
                    Say(handler, "Ambush: not ready. Enter stealth to ready it.");
                if (player->WcmeAmbushCooldown)
                    Say(handler, "Entering stealth again readies it in " + Time((player->WcmeAmbushCooldown + 999) / 1000) +
                        ".");
                break;
            }
            case RACE_TROLL:
            {
                if (uint32 const cooldown = Seconds(player, 9990007))
                    Say(handler, "Voodoo Regeneration: the burst heal is ready again in " + Time(cooldown) +
                        "; until then your regeneration in combat is halved.");
                else
                    Say(handler, "Voodoo Regeneration: the burst heal is ready (below 35% health).");
                if (Amount(player, 26297, EFFECT_0) || Amount(player, 1126297, EFFECT_0))
                    Say(handler, "Berserking: +" + std::to_string(std::max(Amount(player, 26297, EFFECT_0), Amount(player, 1126297, EFFECT_0))) +
                        "% haste, " + Time(std::max(Seconds(player, 26297), Seconds(player, 1126297))) + " left.");
                else
                    Say(handler, "Berserking would give +" + std::to_string(std::clamp(int32(std::lround(10.0f +
                        (100.0f - player->GetHealthPct()) / 3.0f)), 10, 30)) + "% haste right now (10% at full health, up to 30% at 40% or lower).");
                break;
            }
            case RACE_DRAENEI:
            {
                uint32 const light = player->WcmeRadiantStacks;
                std::string line = "Radiant Presence: " + std::to_string(light) + " of 5 Light (+" + std::to_string(light) +
                    "% damage and healing, " + std::to_string(light) + "% less damage taken, for you and allies within 30 yards).";
                if (light < 5 && player->IsInCombat())
                    line += " Next in " + Time((6000 - std::min<uint32>(player->WcmeRadiantStackTimer, 6000) + 999) / 1000) + ".";
                Say(handler, line);
                break;
            }
            case RACE_UNDEAD_PLAYER:
            {
                if (uint32 const bonus = Stacks(player, 9990027))
                    Say(handler, "Grave Defiance: +" + std::to_string(bonus) + "% damage and healing, " +
                        Time(Seconds(player, 9990027)) + " left.");
                else if (uint32 const wait = Seconds(player, 9990028))
                    Say(handler, "Grave Defiance: can start again in " + Time(wait) + ".");
                else
                    Say(handler, "Grave Defiance: ready (below 35% health).");
                if (uint32 const charges = Stacks(player, 9990061); charges >= 20)
                    Say(handler, "Rising as a ghoul: ready (Grave Feast 20 of 20).");
                else
                    Say(handler, "Rising as a ghoul: Grave Feast " + std::to_string(charges) + " of 20 (each Cannibalize tick adds one).");
                break;
            }
            case RACE_HUMAN:
            {
                int32 const spellPower = Amount(player, 9990034, EFFECT_0);
                int32 const attackPower = std::max(Amount(player, 9990035, EFFECT_0), Amount(player, 9990035, EFFECT_1));
                float const spellCrit = float(Amount(player, 9990036, EFFECT_0)) * player->GetRatingMultiplier(CR_CRIT_SPELL);
                float const spellHit = float(Amount(player, 9990036, EFFECT_1)) * player->GetRatingMultiplier(CR_HIT_SPELL);
                float const meleeCrit = float(Amount(player, 9990037, EFFECT_0)) * player->GetRatingMultiplier(CR_CRIT_MELEE);
                float const meleeHit = float(Amount(player, 9990038, EFFECT_0)) * player->GetRatingMultiplier(CR_HIT_MELEE);
                if (!spellPower && !attackPower && spellCrit <= 0.0f && spellHit <= 0.0f && meleeCrit <= 0.0f && meleeHit <= 0.0f)
                {
                    Say(handler, "Spellsword: adding nothing right now (your two sides are even, or your build converts already).");
                    break;
                }
                Say(handler, "Spellsword is adding:");
                if (spellPower)
                    Say(handler, "  +" + std::to_string(spellPower) + " spell power");
                if (attackPower)
                    Say(handler, "  +" + std::to_string(attackPower) + " attack power");
                if (spellCrit > 0.0f)
                    Say(handler, "  +" + Percent(spellCrit) + " spell critical strike chance");
                if (meleeCrit > 0.0f)
                    Say(handler, "  +" + Percent(meleeCrit) + " melee and ranged critical strike chance");
                if (spellHit > 0.0f)
                    Say(handler, "  +" + Percent(spellHit) + " spell hit chance");
                if (meleeHit > 0.0f)
                    Say(handler, "  +" + Percent(meleeHit) + " melee and ranged hit chance");
                break;
            }
            case RACE_GNOME:
            {
                uint32 const steps = player->WcmeOverclockSteps;
                std::string line = "Overclock: step " + std::to_string(steps) + " of 10 (abilities cost " + std::to_string(steps) +
                    "% less).";
                if (!player->IsInCombat())
                    line += " Held until your next fight.";
                else if (steps < 10)
                    line += " Next step in " + Time((5000 - std::min<uint32>(player->WcmeOverclockTimer, 5000) + 999) / 1000) + ".";
                else
                    line += " Cools down in " + Time((10000 - std::min<uint32>(player->WcmeOverclockTimer, 10000) + 999) / 1000) + ".";
                Say(handler, line);
                break;
            }
            case RACE_BLOODELF:
            {
                uint32 const hunger = Stacks(player, 9990046);
                Say(handler, "Arcane Hunger: " + std::to_string(hunger) + " of 10 stacks (+" + std::to_string((3 * hunger + 1) / 2) +
                    "% damage and healing, +" + std::to_string(2 * hunger) + "% ability costs). Arcane Torrent would restore " +
                    std::to_string(2 * hunger) + "% of every resource.");
                if (uint32 const sated = Seconds(player, 9990057))
                    Say(handler, "Satiated: no new stacks for " + Time(sated) + ".");
                break;
            }
            case RACE_DWARF:
            {
                struct Find { uint32 spell; char const* name; char const* gives; };
                static Find const finds[] =
                {
                    { 9990049, "Mining", "% Stamina" },
                    { 9990050, "Herbalism", "% Intellect and Spirit" },
                    { 9990051, "Skinning", "% Strength and Agility" },
                    { 9990052, "Treasure", "% damage and healing" },
                    { 9990053, "Fishing", "% movement and swim speed" },
                };
                Say(handler, "Prospector's Spirit:");
                for (Find const& find : finds)
                {
                    uint32 const stacks = Stacks(player, find.spell);
                    uint32 const each = find.spell == 9990053 ? 3 : 2;
                    if (stacks)
                        Say(handler, std::string("  ") + find.name + ": " + std::to_string(stacks) + " of 3 (+" +
                            std::to_string(each * stacks) + find.gives + "), " + Time(Seconds(player, find.spell)) + " left.");
                    else
                        Say(handler, std::string("  ") + find.name + ": none.");
                }
                break;
            }
            default:
                Say(handler, "Your race has no signature racial.");
                break;
        }
        // Running with the Herd works for every race.
        if (player->WcmeHerdBonus > 0.0f)
            Say(handler, "Running with the Herd: +" + std::to_string(uint32(player->WcmeHerdBonus * 100.0f + 0.5f)) +
                "% running speed from a Tauren nearby.");
        return true;
    }
};

'@
$text = $text.Replace($include, $include + "#include `"Chat.h`"`n#include `"ChatCommand.h`"`n#include `"CommandScript.h`"`n#include `"SpellAuraEffects.h`"`n#include `"SpellAuras.h`"`n#include <algorithm>`n#include <cmath>`n#include <cstdio>`n#include <string>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_racial_command();`n")
Set-Content $file $text -NoNewline
}
