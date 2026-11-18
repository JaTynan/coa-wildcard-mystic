# Human signature racial: Spellsword (docs/race-kits.md). The experimenter's race: it lifts the weak half of a physical
# and spell hybrid. For each of power (attack power against spell power), critical strike chance (melee and ranged
# against spell) and hit chance (melee and ranged against spell), the weaker side is raised 30% of the way towards the
# stronger side. Each of the three is skipped while you already have a conversion between the two sides for it
# (Sheath of Light, Mental Quickness, Mental Dexterity, Careful Aim and the like), so designed hybrids gain little and
# pure builds nothing they use.
# The raises ride on hidden auras whose amounts this script sets every 2 sec: spell power 9990034, attack power 9990035,
# spell critical strike and hit rating 9990036, melee and ranged critical strike rating 9990037, melee and ranged hit
# rating 9990038 (critical strike and hit are given as rating, worked out from the percent at your level). The buff
# 9990032 shows it working; 9990033 shows instead when your build converts all three already. The spells are in
# sql/enchants/150-custom-spells.sql and the client patch (client-patch/custom_spells.py). Run by the build from the
# workspace root, after 40-battlegrounds.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
# Racials.Spellsword = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Spellsword state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint32 WcmeSpellswordTimer = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Spellsword for Humans (Racials.Spellsword)"
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
// Wildcard: Human Spellsword (docs/race-kits.md).
class wcme_spellsword : public PlayerScript
{
public:
    wcme_spellsword() : PlayerScript("wcme_spellsword", {PLAYERHOOK_ON_UPDATE}) { }

    static constexpr uint32 Shown = 9990032;         // the buff: Spellsword at work
    static constexpr uint32 Idle = 9990033;          // the buff when the build converts all three already
    static constexpr uint32 SpellPower = 9990034;    // spell damage, spell healing
    static constexpr uint32 AttackPower = 9990035;   // melee, ranged attack power
    static constexpr uint32 SpellRatings = 9990036;  // spell critical strike rating, spell hit rating
    static constexpr uint32 MeleeCrit = 9990037;     // melee, ranged critical strike rating
    static constexpr uint32 MeleeHit = 9990038;      // melee, ranged hit rating
    static constexpr float Share = 0.3f;             // 30% of the way towards the stronger side
    static constexpr uint32 Interval = 2000;

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_HUMAN)
            return;
        if (!sConfigMgr->GetOption<bool>("Racials.Spellsword", true))
        {
            for (uint32 spell : {Shown, Idle, SpellPower, AttackPower, SpellRatings, MeleeCrit, MeleeHit})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
            player->WcmeSpellswordTimer = 0;
            return;
        }
        if (!player->IsAlive())
        {
            player->WcmeSpellswordTimer = 0; // death took the auras: start again straight after
            return;
        }
        player->WcmeSpellswordTimer += diff;
        if (player->WcmeSpellswordTimer < Interval && player->HasAura(SpellPower))
            return;
        player->WcmeSpellswordTimer = 0;
        Refresh(player);
    }

private:
    static bool PhysicalStat(int32 stat) { return stat == STAT_STRENGTH || stat == STAT_AGILITY; }
    static bool CasterStat(int32 stat) { return stat == STAT_INTELLECT || stat == STAT_SPIRIT; }

    // A conversion between the two sides for power: spell power from attack power or from Strength or Agility, attack
    // power from Intellect or Spirit, or one of those stats from the other side's.
    static bool PowerConverts(Player* player)
    {
        for (AuraType type : {SPELL_AURA_MOD_SPELL_DAMAGE_OF_ATTACK_POWER, SPELL_AURA_MOD_SPELL_HEALING_OF_ATTACK_POWER})
            for (AuraEffect const* effect : player->GetAuraEffectsByType(type))
                if (effect->GetAmount())
                    return true;
        for (AuraEffect const* effect : player->GetAuraEffectsByType(SPELL_AURA_MOD_SPELL_DAMAGE_OF_STAT_PERCENT))
            if (effect->GetAmount() && PhysicalStat(effect->GetMiscValueB()))
                return true;
        for (AuraEffect const* effect : player->GetAuraEffectsByType(SPELL_AURA_MOD_SPELL_HEALING_OF_STAT_PERCENT))
        {
            // As Unit::SpellBaseHealingBonusDone reads it: the stat is in MiscValue, or MiscValueB when MiscValue is a
            // school mask.
            int32 const misc = effect->GetMiscValue();
            int32 const stat = (misc >= STAT_STRENGTH && misc < MAX_STATS) ? misc : effect->GetMiscValueB();
            if (effect->GetAmount() && PhysicalStat(stat))
                return true;
        }
        for (AuraType type : {SPELL_AURA_MOD_ATTACK_POWER_OF_STAT_PERCENT, SPELL_AURA_MOD_RANGED_ATTACK_POWER_OF_STAT_PERCENT})
            for (AuraEffect const* effect : player->GetAuraEffectsByType(type))
                if (effect->GetAmount() && CasterStat(effect->GetMiscValue()))
                    return true;
        for (AuraEffect const* effect : player->GetAuraEffectsByType(SPELL_AURA_ASCENSION_MOD_STAT_FROM_STAT))
        {
            int32 const to = effect->GetMiscValue(), from = effect->GetMiscValueB();
            if (effect->GetAmount() && ((PhysicalStat(to) && CasterStat(from)) || (CasterStat(to) && PhysicalStat(from))))
                return true;
        }
        return false;
    }

    // A conversion between the two sides for a rating: melee or ranged rating from Intellect or Spirit, or spell rating
    // from Strength or Agility (Mental Dexterity, Zealotry, Molten Armor and the like).
    static bool RatingConverts(Player* player, uint32 physicalMask, uint32 spellMask)
    {
        for (AuraEffect const* effect : player->GetAuraEffectsByType(SPELL_AURA_MOD_RATING_FROM_STAT))
        {
            uint32 const mask = uint32(effect->GetMiscValue());
            int32 const stat = effect->GetMiscValueB();
            if (effect->GetAmount() && (((mask & physicalMask) && CasterStat(stat)) || ((mask & spellMask) && PhysicalStat(stat))))
                return true;
        }
        return false;
    }

    static int32 Raise(float from, float to)
    {
        return to > from ? int32(std::lround(Share * (to - from))) : 0;
    }

    // Percent to rating at the player's level.
    static int32 Rating(Player* player, CombatRating rating, float from, float to)
    {
        float const perPoint = player->GetRatingMultiplier(rating);
        if (to <= from || perPoint <= 0.0f)
            return 0;
        return int32(std::lround(Share * (to - from) / perPoint));
    }

    static void Set(Player* player, uint32 spell, uint8 effIndex, int32 amount)
    {
        if (!amount)
            return; // already zero
        if (Aura* aura = player->GetAura(spell))
            if (AuraEffect* effect = aura->GetEffect(effIndex))
                effect->ChangeAmount(amount);
    }

    static void Refresh(Player* player)
    {
        // Our own raises out first, so the two sides are read as the player's build has them.
        for (uint32 spell : {SpellPower, AttackPower, SpellRatings, MeleeCrit, MeleeHit})
        {
            Aura* aura = player->GetAura(spell);
            if (!aura)
                aura = player->AddAura(spell, player);
            if (!aura)
                return;
            for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
                if (AuraEffect* effect = aura->GetEffect(i); effect && effect->GetAmount())
                    effect->ChangeAmount(0);
        }

        bool const power = !PowerConverts(player);
        bool const crit = !RatingConverts(player, (1 << CR_CRIT_MELEE) | (1 << CR_CRIT_RANGED), 1 << CR_CRIT_SPELL);
        bool const hit = !RatingConverts(player, (1 << CR_HIT_MELEE) | (1 << CR_HIT_RANGED), 1 << CR_HIT_SPELL);

        if (power)
        {
            // Spell power: the best school (damage or healing); attack power: the better of melee and ranged.
            int32 spell = player->SpellBaseHealingBonusDone(SPELL_SCHOOL_MASK_ALL);
            for (uint8 school = SPELL_SCHOOL_HOLY; school < MAX_SPELL_SCHOOL; ++school)
                spell = std::max(spell, player->SpellBaseDamageBonusDone(SpellSchoolMask(1 << school)));
            float const melee = player->GetTotalAttackPowerValue(BASE_ATTACK);
            float const ranged = player->GetTotalAttackPowerValue(RANGED_ATTACK);
            float const physical = std::max(melee, ranged);
            if (physical > float(spell))
            {
                int32 const raise = Raise(float(spell), physical);
                Set(player, SpellPower, EFFECT_0, raise);
                Set(player, SpellPower, EFFECT_1, raise);
            }
            else
            {
                Set(player, AttackPower, EFFECT_0, Raise(melee, float(spell)));
                Set(player, AttackPower, EFFECT_1, Raise(ranged, float(spell)));
            }
        }

        if (crit)
        {
            float spell = 0.0f;
            for (uint8 school = SPELL_SCHOOL_HOLY; school < MAX_SPELL_SCHOOL; ++school)
                spell = std::max(spell, player->GetFloatValue(PLAYER_SPELL_CRIT_PERCENTAGE1 + school));
            float const melee = player->GetFloatValue(PLAYER_CRIT_PERCENTAGE);
            float const ranged = player->GetFloatValue(PLAYER_RANGED_CRIT_PERCENTAGE);
            float const physical = std::max(melee, ranged);
            if (physical > spell)
                Set(player, SpellRatings, EFFECT_0, Rating(player, CR_CRIT_SPELL, spell, physical));
            else
            {
                Set(player, MeleeCrit, EFFECT_0, Rating(player, CR_CRIT_MELEE, melee, spell));
                Set(player, MeleeCrit, EFFECT_1, Rating(player, CR_CRIT_RANGED, ranged, spell));
            }
        }

        if (hit)
        {
            float const spell = player->m_modSpellHitChance;
            float const melee = player->m_modMeleeHitChance;
            float const ranged = player->m_modRangedHitChance;
            float const physical = std::max(melee, ranged);
            if (physical > spell)
                Set(player, SpellRatings, EFFECT_1, Rating(player, CR_HIT_SPELL, spell, physical));
            else
            {
                Set(player, MeleeHit, EFFECT_0, Rating(player, CR_HIT_MELEE, melee, spell));
                Set(player, MeleeHit, EFFECT_1, Rating(player, CR_HIT_RANGED, ranged, spell));
            }
        }

        // The buff: at work, or nothing to add because the build converts all three already.
        uint32 const show = (power || crit || hit) ? Shown : Idle;
        uint32 const hide = show == Shown ? Idle : Shown;
        if (player->HasAura(hide))
            player->RemoveAurasDueToSpell(hide);
        if (!player->HasAura(show))
            player->AddAura(show, player);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"SpellAuraEffects.h`"`n#include `"SpellAuras.h`"`n#include <cmath>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_spellsword();`n")
Set-Content $file $text -NoNewline
}
