# Worldforged Mystic Enchants: make the 990 rare ones work, and let them drop (James, 19 November).
# The rare worldforged enchants come in eight families named after an enemy type ("Wizard's Sinister Strike", "Primal
# Mongoose Bite"...), 124 abilities each. On this core they did nothing: on Ascension a server-side helper per enchant
# ("<enchant> SLS") watched for the ability and gave the family's Power buff, and nothing here applies the helpers; the
# Power spells also carry no amounts (Ascension worked them out from the tooltips). Nothing handed them out either: the
# Unidentified Mystic Scroll leaves worldforged enchants out on purpose, and no loot table has them.
#
# What this adds (all in AscensionMysticEnchant.cpp, next to the core's own scroll drops):
#   - Triggers as the tooltips say: damage with the ability (direct, periodic or either, per ability); Gigantic above 75%
#     target health; Necrotic killing an enemy with the ability, or any enemy. Chance from the enchant's own helper
#     (enchant spell + 1). One 20 sec cooldown shared by every rare worldforged enchant (the client's own marker, 780999).
#   - The Power buffs with the tooltip amounts ($PL = character level), times the family's active enchants ("each
#     additional enchant increases the power of the buff by 100%"): Fighter's 10 rage and energy, attack power 1 x level;
#     Wizard's 4% base mana, spell power 0.4 x level; Primal a heal of 1.7 x level, primary stat 0.3 x level; Demonic 2%
#     damage; Draconic 3% crit; Gigantic 3% crit (8 sec); Necrotic 2% damage (8 sec); Element-bound 2% haste and 3%
#     cheaper spells (8 sec).
#   - Gigantic and Necrotic "deal 2% more damage" above 75% / below 35% health applied to the named ability only (the core
#     read it as a bonus to every hit, so that effect becomes a placeholder at startup).
#   - Drops: Wildcard.WorldforgedDropChance percent (worldserver.conf, default 1) from enemies above level 10 worth
#     experience. The enemy's type picks the family (beasts Primal, dragonkin Draconic, demons Demonic, elementals
#     Element-bound, giants Gigantic, undead Necrotic, humanoids Wizard's if a caster class (mage or paladin) and
#     Fighter's otherwise); the enchant is one for an ability the looter knows, by the enchant list's weights. 0 = off.
# Not covered: the 217 epic and legendary worldforged enchants (designs of their own) still never drop.
# Run by the build from the workspace root, after the *.patch files. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host 'Patch: worldforged enchant state on Player'
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    uint8 WcmeWorldforgedPending = 0;`n    ObjectGuid WcmeWorldforgedKillVictim;`n    uint32 WcmeWorldforgedKillAbility = 0;`n    uint32 WcmeWorldforgedKillTime = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host 'Patch: worldforged enchants work and drop (Wildcard.WorldforgedDropChance)'
& {
$file = 'core/src/server/coa/AscensionMysticEnchant.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$world = "class AscensionMysticEnchantWorld final : public WorldScript`n"
$startup = "            SkipMissingSpells();`n"
$register = "    new AscensionMysticEnchant::AscensionMysticEnchantScrollDrops();`n"
$std = "#include <unordered_set>`n"
$auras = "#include `"SpellAuras.h`"`n"
foreach ($anchor in @($world, $startup, $register, $std, $auras)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) {
        throw "Core changed (or mystic-enchants-wildcard.patch did not apply): AscensionMysticEnchant.cpp has no single: $($anchor.Split("`n")[0])"
    }
}
$code = @'
// Wildcard: worldforged Mystic Enchants (patches/78-worldforged-enchants.ps1). The 990 rare worldforged enchants come in
// eight families named after an enemy type ("Wizard's Sinister Strike", "Primal Mongoose Bite"...). Each one, while
// active, gives its family's Power buff now and then when its named ability does what the tooltip says. On Ascension
// that was the job of a server-side helper per enchant (named "<enchant> SLS"), which nothing on this core applies, and
// the Power spells carry no amounts (Ascension worked them out in code), so this does both. It also lets them drop:
// nothing on this core hands them out (the Unidentified Mystic Scroll leaves worldforged enchants out).
//
// Triggers, as the tooltips say (one list per ability, the same in every family):
//   most abilities: "Dealing damage with X" (direct or periodic);
//   "Dealing direct damage with X" (DIRECT_ABILITIES) and "Dealing periodic damage with X" (PERIODIC_ABILITIES);
//   Gigantic: X deals 2% more to targets above 75% health and triggers there;
//   Necrotic: X deals 2% more to targets below 35% health; "Killing an enemy with X" triggers, or for the abilities in
//   KILL_ANY_ABILITIES, killing any enemy (one worth experience or honor).
// The chance is the helper's own (enchant spell + 1). Every rare worldforged enchant shares one 20 sec cooldown (the
// client's "Worldforged Rare iCD", 780999). "Each additional enchant increases the power of the buff by 100%": the buff
// is multiplied by the number of active enchants of its family (stacks included). $PL in the tooltips is taken as the
// character's level.
namespace WcmeWorldforged
{
enum Family : uint8
{
    FIGHTER, WIZARD, PRIMAL, DEMONIC, DRACONIC, GIGANTIC, NECROTIC, ELEMENT_BOUND, FAMILY_COUNT
};

enum class Trigger : uint8
{
    Damage, Direct, Periodic, AboveHealth, KillWith, KillAny
};

constexpr std::array<std::string_view, FAMILY_COUNT> PREFIXES = {
    "Fighter's ", "Wizard's ", "Primal ", "Demonic ", "Draconic ", "Gigantic ", "Necrotic ", "Element-bound " };
constexpr uint32 SHARED_COOLDOWN = 780999;  // Worldforged Rare iCD: 20 sec, applied by every Power spell's third effect
constexpr uint32 KILL_WINDOW_MS = 1000;

// The enchant tooltips' own wording, one list per ability (checked against all 990 enchants: no ability differs between
// families).
constexpr std::array<std::string_view, 7> DIRECT_ABILITIES = {
    "Conflagrate", "Crimson Tempest", "Fireball", "Flamestrike", "Holy Fire", "Pyroblast", "Shadowflame" };
constexpr std::array<std::string_view, 19> PERIODIC_ABILITIES = {
    "Consecration", "Corruption", "Curse of Agony", "Devouring Plague", "Entangling Roots", "Flame Shock", "Garrote",
    "Immolate", "Insect Swarm", "Lacerate", "Living Bomb", "Moonfire", "Rend", "Rip", "Rupture", "Serpent Sting",
    "Shadow Word: Pain", "Unstable Affliction", "Vampiric Touch" };
constexpr std::array<std::string_view, 54> KILL_ANY_ABILITIES = {
    "Ambush", "Backstab", "Bloodthirst", "Claw", "Conflagrate", "Consecration", "Corruption", "Counterattack",
    "Devastate", "Dispatch", "Envenom", "Eviscerate", "Execute", "Exorcism", "Fireball", "Flamestrike", "Frostbolt",
    "Garrote", "Gloomblade", "Hamstring", "Haunt", "Hellfire", "Hemorrhage", "Immolate", "Incinerate", "Judgement",
    "Lacerate", "Mangle", "Maul", "Moonfire", "Multi-Shot", "Mutilate", "Overpower", "Pyroblast", "Rake", "Rend",
    "Revenge", "Rip", "Riposte", "Rupture", "Scorch", "Shadowburn", "Shadowflame", "Shadowfury", "Shiv", "Shred",
    "Siegebreaker", "Slam", "Smite", "Starfire", "Starsurge", "Stormstrike", "Whirlwind", "Wrath" };

template <std::size_t N>
bool Listed(std::array<std::string_view, N> const& list, std::string_view name)
{
    return std::find(list.begin(), list.end(), name) != list.end();
}

struct Entry
{
    uint32 EnchantSpell = 0;
    Family Group = FIGHTER;
    Trigger How = Trigger::Damage;
    uint32 Chance = 0;
    uint8 BonusEffect = MAX_SPELL_EFFECTS;  // Gigantic and Necrotic: the "deals 2% more" effect (aura state + amount)
    std::size_t Ability = 0;
};

struct Ability
{
    std::string Name;
    std::vector<uint32> Learned;                          // the spells of that name a character can know
    std::array<int32, FAMILY_COUNT> Entries;              // index into Entries, -1 for none
};

std::vector<Entry> Entries;
std::vector<Ability> Abilities;
std::unordered_map<uint32, std::size_t> AbilityBySpell;  // the ability's spells and the spells they trigger
std::array<std::vector<std::size_t>, FAMILY_COUNT> ByFamily;
bool Active = false;

Family FamilyOf(std::string_view name, std::string_view& ability)
{
    for (uint8 family = 0; family < FAMILY_COUNT; ++family)
        if (name.size() > PREFIXES[family].size() && name.substr(0, PREFIXES[family].size()) == PREFIXES[family])
        {
            ability = name.substr(PREFIXES[family].size());
            return Family(family);
        }
    return FAMILY_COUNT;
}

void MapTriggered(uint32 spellId, std::size_t ability, uint32 depth)
{
    SpellInfo const* spell = sSpellMgr->GetSpellInfo(spellId);
    if (!spell || depth > 2)
        return;
    for (SpellEffectInfo const& effect : spell->GetEffects())
    {
        bool const triggers = effect.Effect == SPELL_EFFECT_TRIGGER_SPELL || effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE ||
            effect.Effect == SPELL_EFFECT_TRIGGER_SPELL_WITH_VALUE ||
            effect.Effect == SPELL_EFFECT_TRIGGER_MISSILE_SPELL_WITH_VALUE ||
            effect.ApplyAuraName == SPELL_AURA_PERIODIC_TRIGGER_SPELL ||
            effect.ApplyAuraName == SPELL_AURA_PERIODIC_TRIGGER_SPELL_WITH_VALUE;
        if (!triggers || !effect.TriggerSpell || effect.TriggerSpell == spellId)
            continue;
        if (AbilityBySpell.emplace(effect.TriggerSpell, ability).second)
            MapTriggered(effect.TriggerSpell, ability, depth + 1);
    }
}

void Load()
{
    Entries.clear();
    Abilities.clear();
    AbilityBySpell.clear();
    for (auto& list : ByFamily)
        list.clear();
    Active = false;

    std::unordered_map<std::string, std::size_t> abilityByName;
    uint32 noHelper = 0, placeholders = 0;
    for (Enchant const& enchant : AscensionMysticEnchant::Loaded.Rows)
    {
        if (!enchant.Worldforged || !enchant.Spell)
            continue;
        SpellInfo const* info = sSpellMgr->GetSpellInfo(enchant.Spell);
        if (!info || !info->SpellName[0])
            continue;
        std::string_view const name = info->SpellName[0];
        std::string_view abilityName;
        Family const family = FamilyOf(name, abilityName);
        if (family == FAMILY_COUNT)
            continue;  // the epic and legendary worldforged enchants: designs of their own, not this system
        SpellInfo const* helper = sSpellMgr->GetSpellInfo(enchant.Spell + 1);
        if (!helper || !helper->SpellName[0] || std::string(helper->SpellName[0]) != std::string(name) + " SLS")
        {
            ++noHelper;  // Primal Tide has none
            continue;
        }

        Entry entry;
        entry.EnchantSpell = enchant.Spell;
        entry.Group = family;
        entry.Chance = helper->ProcChance;
        if (family == GIGANTIC)
            entry.How = Trigger::AboveHealth;
        else if (family == NECROTIC)
            entry.How = Listed(KILL_ANY_ABILITIES, abilityName) ? Trigger::KillAny : Trigger::KillWith;
        else if (Listed(DIRECT_ABILITIES, abilityName))
            entry.How = Trigger::Direct;
        else if (Listed(PERIODIC_ABILITIES, abilityName))
            entry.How = Trigger::Periodic;

        // "Deals 2% more damage against targets above 75% / below 35% health": the core reads this effect as a bonus to
        // every damage source (its spell family and empty mask match everything), so it becomes a placeholder here and
        // the script applies it to the named ability only, with the same aura state and amount.
        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            if (info->Effects[i].ApplyAuraName == SPELL_AURA_MOD_DAMAGE_DONE_VERSUS_AURASTATE ||
                (info->Effects[i].ApplyAuraName == SPELL_AURA_DUMMY && info->Effects[i].MiscValue &&
                    (family == GIGANTIC || family == NECROTIC)))
            {
                if (info->Effects[i].ApplyAuraName != SPELL_AURA_DUMMY)
                {
                    const_cast<SpellInfo*>(info)->Effects[i].ApplyAuraName = SPELL_AURA_DUMMY;
                    ++placeholders;
                }
                entry.BonusEffect = i;
            }

        std::string const key(abilityName);
        auto [itr, added] = abilityByName.emplace(key, Abilities.size());
        if (added)
        {
            Ability ability;
            ability.Name = key;
            ability.Entries.fill(-1);
            Abilities.push_back(std::move(ability));
        }
        entry.Ability = itr->second;
        Abilities[entry.Ability].Entries[family] = int32(Entries.size());
        ByFamily[family].push_back(Entries.size());
        Entries.push_back(entry);
    }

    // The abilities' own spells (every spell of that name: stock ranks, CoA copies and NPC versions; only the enchant
    // owner's own hits count), then the spells they trigger (Arcane Missiles' bolts, Hellfire's burns...).
    // Judgement deals its damage through "Judgement of Righteousness", "of Command" and the like.
    auto const judgement = abilityByName.find("Judgement");
    for (uint32 id = 0; id < sSpellMgr->GetSpellInfoStoreSize(); ++id)
    {
        SpellInfo const* spell = sSpellMgr->GetSpellInfo(id);
        if (!spell || !spell->SpellName[0])
            continue;
        std::string_view const name = spell->SpellName[0];
        if (auto const itr = abilityByName.find(std::string(name)); itr != abilityByName.end())
        {
            AbilityBySpell[id] = itr->second;
            if (!spell->IsPassive())
                Abilities[itr->second].Learned.push_back(id);
        }
        else if (judgement != abilityByName.end() && name.substr(0, 13) == "Judgement of ")
            AbilityBySpell.emplace(id, judgement->second);
    }
    for (auto const& [name, index] : abilityByName)
        for (uint32 spell : std::vector<uint32>(Abilities[index].Learned))
            MapTriggered(spell, index, 0);

    Active = !Entries.empty();
    LOG_INFO("coa", "Worldforged enchants working: {} in {} families, {} abilities ({} spells), {} without a helper, {} "
        "health bonuses moved to their ability", Entries.size(), std::count_if(ByFamily.begin(), ByFamily.end(),
        [](auto const& list) { return !list.empty(); }), Abilities.size(), AbilityBySpell.size(), noHelper, placeholders);
}

// Every active enchant of the family counts, stacks included ("each additional enchant increases the power by 100%").
uint32 FamilyCount(Player const* player, Family family)
{
    uint32 count = 0;
    for (std::size_t index : ByFamily[family])
        if (Aura const* aura = player->GetAura(Entries[index].EnchantSpell))
            count += std::max<uint32>(1, aura->GetStackAmount());
    return count;
}

// Primal Power's "Primary Stat": the Wildcard stat path (Strength, Agility, Intellect, Healing = Spirit, Duality = the
// higher of Strength and Agility), else the highest of Strength, Agility, Intellect and Spirit.
uint32 PrimalStatSpell(Player const* player)
{
    constexpr uint32 INTELLECT = 781602, SPIRIT = 781603, STRENGTH = 781604, AGILITY = 781605;
    if (player->HasSpell(84864))
        return STRENGTH;
    if (player->HasSpell(84865))
        return AGILITY;
    if (player->HasSpell(84866))
        return INTELLECT;
    if (player->HasSpell(84867))
        return SPIRIT;
    if (player->HasSpell(129243))
        return player->GetStat(STAT_AGILITY) > player->GetStat(STAT_STRENGTH) ? AGILITY : STRENGTH;
    Stats best = STAT_STRENGTH;
    for (Stats stat : { STAT_AGILITY, STAT_INTELLECT, STAT_SPIRIT })
        if (player->GetStat(stat) > player->GetStat(best))
            best = stat;
    switch (best)
    {
        case STAT_AGILITY: return AGILITY;
        case STAT_INTELLECT: return INTELLECT;
        case STAT_SPIRIT: return SPIRIT;
        default: return STRENGTH;
    }
}

void CastWith(Player* player, uint32 spell, int32 bp0, std::optional<int32> bp1 = std::nullopt)
{
    if (!sSpellMgr->GetSpellInfo(spell))
        return;
    int32 const second = bp1.value_or(0);
    player->CastCustomSpell(player, spell, &bp0, bp1 ? &second : nullptr, nullptr, true);
}

// The family's Power buff, as its tooltip says, times the number of its active enchants.
void Grant(Player* player, Family family)
{
    uint32 const count = FamilyCount(player, family);
    if (!count || !player->IsAlive())
        return;
    int32 const n = int32(count);
    int32 const level = int32(player->GetLevel());
    auto scaled = [n, level](float perLevel) { return int32(std::lround(perLevel * float(level) * float(n))); };
    switch (family)
    {
        case FIGHTER:  // 10 rage and energy, attack power (melee and ranged) by 1 x level
            CastWith(player, 781000, scaled(1.0f), scaled(1.0f));
            CastWith(player, 781001, 10 * n);   // energy
            CastWith(player, 781002, 100 * n);  // rage, in tenths
            break;
        case WIZARD:  // 4% of base mana, spell power by 0.4 x level
            CastWith(player, 781300, scaled(0.4f));
            CastWith(player, 781301, 4 * n);
            break;
        case PRIMAL:  // a heal of 1.7 x level, primary stat by 0.3 x level
            CastWith(player, 781600, 0);
            CastWith(player, 781601, scaled(1.7f));
            CastWith(player, PrimalStatSpell(player), scaled(0.3f));
            break;
        case DEMONIC:  // 2% damage done
            CastWith(player, 781900, 2 * n);
            break;
        case DRACONIC:  // 3% critical strike chance (spells, and weapons)
            CastWith(player, 782200, 3 * n);
            CastWith(player, 782201, 3 * n);
            break;
        case GIGANTIC:  // 3% critical strike chance, 8 sec
            CastWith(player, 782500, 3 * n);
            CastWith(player, 782501, 3 * n);
            break;
        case NECROTIC:  // 2% damage done, 8 sec
            CastWith(player, 782800, 2 * n);
            break;
        case ELEMENT_BOUND:  // 2% haste and 3% cheaper spells, 8 sec
            CastWith(player, 783100, 2 * n);
            CastWith(player, 783101, -3 * n);
            break;
        default:
            return;
    }
    if (!player->HasAura(SHARED_COOLDOWN))
        player->AddAura(SHARED_COOLDOWN, player);
}

// A proc is queued and given on the player's next update, outside the damage calculation that caused it.
void Roll(Player* player, Entry const& entry)
{
    if (player->WcmeWorldforgedPending || player->HasAura(SHARED_COOLDOWN) || !roll_chance_i(int32(entry.Chance)))
        return;
    player->WcmeWorldforgedPending = uint8(entry.Group) + 1;
}

// A hit by an ability with worldforged enchants: the health bonuses, and the triggers.
void Hit(Unit* attacker, Unit* target, uint32& damage, SpellInfo const* spell, bool periodic)
{
    if (!Active || !damage || !spell || !attacker || !target || !target->IsAlive())
        return;
    Player* player = attacker->ToPlayer();
    if (!player)
        return;
    auto const itr = AbilityBySpell.find(spell->Id);
    if (itr == AbilityBySpell.end() || !player->IsValidAttackTarget(target))
        return;  // heal ticks come through the periodic hook too; they never target an enemy
    Ability const& ability = Abilities[itr->second];
    bool const lethal = damage >= target->GetHealth();
    for (int32 index : ability.Entries)
    {
        if (index < 0)
            continue;
        Entry const& entry = Entries[index];
        Aura const* aura = player->GetAura(entry.EnchantSpell);
        if (!aura)
            continue;
        bool inState = false;
        if (entry.BonusEffect < MAX_SPELL_EFFECTS)
            if (AuraEffect const* bonus = aura->GetEffect(entry.BonusEffect))
                if (target->HasAuraState(AuraStateType(bonus->GetMiscValue())))
                {
                    inState = true;
                    damage = uint32(std::max<int64>(0, int64(damage) * (100 + bonus->GetAmount()) / 100));
                }
        switch (entry.How)
        {
            case Trigger::Damage: Roll(player, entry); break;
            case Trigger::Direct: if (!periodic) Roll(player, entry); break;
            case Trigger::Periodic: if (periodic) Roll(player, entry); break;
            case Trigger::AboveHealth: if (inState) Roll(player, entry); break;
            case Trigger::KillWith:
                if (lethal)
                {
                    player->WcmeWorldforgedKillVictim = target->GetGUID();
                    player->WcmeWorldforgedKillAbility = uint32(itr->second) + 1;
                    player->WcmeWorldforgedKillTime = getMSTime();
                }
                break;
            default: break;
        }
    }
}

// A killing blow on an enemy worth experience or honor: Necrotic's triggers.
void Kill(Player* player, Unit* victim)
{
    if (!Active || !player || !victim)
        return;
    bool const byAbility = player->WcmeWorldforgedKillAbility && player->WcmeWorldforgedKillVictim == victim->GetGUID() &&
        GetMSTimeDiffToNow(player->WcmeWorldforgedKillTime) <= KILL_WINDOW_MS;
    std::size_t const ability = byAbility ? player->WcmeWorldforgedKillAbility - 1 : 0;
    player->WcmeWorldforgedKillAbility = 0;
    player->WcmeWorldforgedKillVictim.Clear();
    if (!player->isHonorOrXPTarget(victim))
        return;
    for (std::size_t index : ByFamily[NECROTIC])
    {
        Entry const& entry = Entries[index];
        if (entry.How == Trigger::KillWith && (!byAbility || entry.Ability != ability))
            continue;
        if (!player->HasAura(entry.EnchantSpell))
            continue;
        Roll(player, entry);
        if (player->WcmeWorldforgedPending)
            return;
    }
}

// Which family an enemy drops: its creature type, and for humanoids, casters (mage and paladin classes, the ones with
// mana) drop Wizard's and the others Fighter's. Mechanicals, critters and the rest drop none.
Family DropFamily(Creature const* creature)
{
    switch (creature->GetCreatureType())
    {
        case CREATURE_TYPE_BEAST: return PRIMAL;
        case CREATURE_TYPE_DRAGONKIN: return DRACONIC;
        case CREATURE_TYPE_DEMON: return DEMONIC;
        case CREATURE_TYPE_ELEMENTAL: return ELEMENT_BOUND;
        case CREATURE_TYPE_GIANT: return GIGANTIC;
        case CREATURE_TYPE_UNDEAD: return NECROTIC;
        case CREATURE_TYPE_HUMANOID:
        {
            uint32 const unitClass = creature->GetCreatureTemplate()->unit_class;
            return (unitClass == CLASS_MAGE || unitClass == CLASS_PALADIN) ? WIZARD : FIGHTER;
        }
        default: return FAMILY_COUNT;
    }
}

bool Knows(Player const* player, Ability const& ability)
{
    return std::any_of(ability.Learned.begin(), ability.Learned.end(),
        [player](uint32 spell) { return player->HasSpell(spell); });
}

// One of the family's enchants for an ability the player knows, by the enchant list's own weights, or nothing.
Enchant const* RollDrop(Player const* player, Family family)
{
    std::array<bool, REALM_COUNT> const gates = AscensionFreepick::RealmGates();
    std::vector<Enchant const*> pool;
    double total = 0.0;
    for (std::size_t index : ByFamily[family])
    {
        Entry const& entry = Entries[index];
        Enchant const* enchant = AscensionMysticEnchant::Loaded.FindSpell(entry.EnchantSpell);
        if (!enchant || !enchant->Item || enchant->Weight <= 0.0f || !ClassAllowed(*enchant, player->getClass()) ||
            !RealmAllows(*enchant, gates) || enchant->RequiredLevel > player->GetLevel() ||
            !sObjectMgr->GetItemTemplate(enchant->Item) || !Knows(player, Abilities[entry.Ability]))
            continue;
        pool.push_back(enchant);
        total += enchant->Weight;
    }
    if (pool.empty() || total <= 0.0)
        return nullptr;
    double target = rand_norm() * total;
    for (Enchant const* enchant : pool)
    {
        target -= enchant->Weight;
        if (target < 0.0)
            return enchant;
    }
    return pool.back();
}
}

class WcmeWorldforgedHits final : public UnitScript
{
public:
    WcmeWorldforgedHits() : UnitScript("WcmeWorldforgedHits", true,
        { UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK }) { }

    void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (damage <= 0)
            return;
        uint32 amount = uint32(damage);
        WcmeWorldforged::Hit(attacker, target, amount, spellInfo, false);
        damage = int32(std::min<uint32>(amount, uint32(std::numeric_limits<int32>::max())));
    }

    void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage, SpellInfo const* spellInfo) override
    {
        WcmeWorldforged::Hit(attacker, target, damage, spellInfo, true);
    }
};

class WcmeWorldforgedPlayer final : public PlayerScript
{
public:
    WcmeWorldforgedPlayer() : PlayerScript("WcmeWorldforgedPlayer",
        { PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_PVP_KILL }) { }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (!player->WcmeWorldforgedPending)
            return;
        auto const family = WcmeWorldforged::Family(player->WcmeWorldforgedPending - 1);
        player->WcmeWorldforgedPending = 0;
        if (family < WcmeWorldforged::FAMILY_COUNT)
            WcmeWorldforged::Grant(player, family);
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override { WcmeWorldforged::Kill(killer, killed); }

    void OnPlayerPVPKill(Player* killer, Player* killed) override
    {
        if (killer != killed)
            WcmeWorldforged::Kill(killer, killed);
    }
};

// Worldforged enchant drops: Wildcard.WorldforgedDropChance percent (default 1) from enemies above level 10 that are
// worth experience, of the enemy's family, for an ability the looter knows.
class WcmeWorldforgedDrops final : public MiscScript
{
public:
    WcmeWorldforgedDrops() : MiscScript("WcmeWorldforgedDrops", { MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS }) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const*, LootStore const& store, Player* owner, bool personal,
        bool, uint16 lootMode) override
    {
        if (!WcmeWorldforged::Active || !loot || !owner || personal || &store != &LootTemplates_Creature ||
            !(lootMode & LOOT_MODE_DEFAULT) || !AscensionFreepick::RealmOffersMysticAltars() || !owner->GetMap() ||
            loot->items.size() >= MAX_NR_LOOT_ITEMS)
            return;
        float const chance = sConfigMgr->GetOption<float>("Wildcard.WorldforgedDropChance", 1.0f, false);
        if (chance <= 0.0f)
            return;
        Creature* creature = owner->GetMap()->GetCreature(loot->sourceWorldObjectGUID);
        if (!creature || creature->IsPet() || creature->GetCharmerOrOwnerGUID() || creature->GetLevel() <= 10 ||
            !owner->isHonorOrXPTarget(creature))
            return;
        WcmeWorldforged::Family const family = WcmeWorldforged::DropFamily(creature);
        if (family == WcmeWorldforged::FAMILY_COUNT || !roll_chance_f(chance))
            return;
        if (Enchant const* enchant = WcmeWorldforged::RollDrop(owner, family))
            loot->AddItem(LootStoreItem(enchant->Item, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, 1, 1));
    }
};

'@
$text = $text.Replace($world, $code.Replace("`r`n", "`n") + $world)
$text = $text.Replace($startup, $startup + "            WcmeWorldforged::Load();`n")
$text = $text.Replace($register, $register + "    new AscensionMysticEnchant::WcmeWorldforgedHits();`n    new AscensionMysticEnchant::WcmeWorldforgedPlayer();`n    new AscensionMysticEnchant::WcmeWorldforgedDrops();`n")
$text = $text.Replace($std, $std + "#include <array>`n#include <cmath>`n#include <limits>`n#include <optional>`n#include <string>`n#include <string_view>`n")
$text = $text.Replace($auras, "#include `"SpellAuraEffects.h`"`n" + $auras)
Set-Content $file $text -NoNewline
}
