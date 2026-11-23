# A Wildcard Hero alt played as a bot stops being taught every class's abilities, and the ones it was already
# taught are removed once (James, 23 November, issue #248: a level 38 alt with 14 rolled abilities also knew about
# 110 abilities of every classic class and two CoA classes).
#
# Cause, as far as the saved data shows: the bot factory's "available spells" step (PlayerbotFactory::
# InitAvailableSpells, reached by an alt through the maintenance command) teaches from every class trainer that is
# valid for the character, and the core counts every class trainer as valid for a Wildcard Hero, so that it can train
# its ranks anywhere. The alt examined held 13 to 22 spells from each class trainer's stock list.
#
# 1. AiPlayerbot.WildcardAltsSkipClassTrainers = 1: for a Wildcard Hero alt that step skips class trainers
#    (profession trainers are untouched). Its ranks come from the Wildcard trainer list (patch 97) and patch 44.
# 2. AiPlayerbot.WildcardAltsRemoveUnrolledClassSpells = N (0 = off): once per alt, when its AI is built (it comes
#    online), remove a spell only when ALL of these hold (the rule James approved, tried first on the saved spells
#    of the alt above: 154 spells removed, every rolled ability, proficiency and profession kept):
#      a. it is a class ability: every skill line it belongs to is a class skill line, and it teaches no weapon,
#         armour, dual wield, parry, block, defense, language or profession skill;
#      b. it, or the first rank of its chain, is on the stock list of a class trainer;
#      c. no Wildcard slot of the character, in any of its specializations, holds that ability (its rank spells,
#         their chain and their rank ladder), and the core did not grant it together with an ability the character
#         keeps (the copy of the core's ENTRY_SPELLS table below: a taunt with Defensive Stance, and so on);
#      d. it is not a stat path spell.
#    Every removal is logged ("playerbots.coa"). The alt is marked with N in its player settings
#    (wcme.wildcard.alt_clean) so it runs once; raise N to run it again for everyone. An alt with no rolled build at
#    all, or one where the rule would remove more than 600 spells, is left alone and logged.
# Alts only: random bots are not touched by either part.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Wildcard Hero alts are not taught every class's abilities (AiPlayerbot.WildcardAltsSkipClassTrainers, AiPlayerbot.WildcardAltsRemoveUnrolledClassSpells)"

# 1. The cause.
Edit-Core 'core/modules/mod-playerbots/src/Bot/Factory/PlayerbotFactory.cpp' @'
    std::vector<uint32> const trainerIds = trainerIdCache[bot->getClass()];
    cacheLock.unlock();
'@ @'
    std::vector<uint32> trainerIds = trainerIdCache[bot->getClass()];
    cacheLock.unlock();

    // Wildcard (patch 43): every class trainer is valid for a Wildcard Hero (the core lets it train its ranks at any
    // of them), so this walk taught a player's alt a slice of every class. An alt keeps to what it rolled.
    static bool const altsSkipClassTrainers =
        sConfigMgr->GetOption<bool>("AiPlayerbot.WildcardAltsSkipClassTrainers", false);
    if (altsSkipClassTrainers && IsWildcardHeroBot(bot) && !sRandomPlayerbotMgr.IsRandomBot(bot))
        std::erase_if(trainerIds, [](uint32 creatureId)
        {
            Trainer::Trainer const* trainer = sObjectMgr->GetTrainer(creatureId);
            return trainer && trainer->GetTrainerType() == Trainer::Type::Class;
        });
'@ 'the copy of the trainer cache in PlayerbotFactory::InitAvailableSpells'

# 2. The one-off removal.
$file = 'core/modules/mod-playerbots/src/Ai/Class/Coa/CoaWildcard.h'
Edit-Core $file @'
void ForgetWildcardKit(Player const* bot);
'@ @'
void ForgetWildcardKit(Player const* bot);
// Wildcard (patch 43): once per alt, removes the class abilities it was taught and never rolled.
void CleanWildcardAltSpells(Player* bot);
'@ 'the ForgetWildcardKit declaration in CoaWildcard.h'

Edit-Core 'core/modules/mod-playerbots/src/Bot/Factory/AiFactory.cpp' @'
        // A Wildcard Hero rolls what it has earned and takes the stat path its build suits.
'@ @'
        // Wildcard (patch 43): first, once, an alt loses the class abilities it was taught and never rolled.
        CleanWildcardAltSpells(player);
        // A Wildcard Hero rolls what it has earned and takes the stat path its build suits.
'@ 'the Wildcard draft comment in AiFactory.cpp'

$file = 'core/modules/mod-playerbots/src/Ai/Class/Coa/CoaWildcard.cpp'
Edit-Core $file @'
#include "CoaWildcardPicks.h"
'@ @'
#include "CoaWildcardPicks.h"
#include "DBCStores.h"
#include "ObjectMgr.h"
#include "Trainer.h"
'@ 'the CoaWildcardPicks.h include in CoaWildcard.cpp'

Edit-Core $file @'
bool TakeDueWildcardPath(Player const* bot)
{
'@ @'
// Wildcard (patch 43): the one-off removal of class abilities an alt was taught and never rolled.
namespace
{
// Spells the core grants together with an ability and takes away with it. A copy of ENTRY_SPELLS in the core's
// AscensionWildcard.cpp (private to that file): when a core update changes that table, change this one.
struct GrantedWith
{
    uint32 entrySpell;
    std::array<uint32, 6> spells;
};
constexpr std::array<GrantedWith, 31> GRANTED_WITH = { {
    { 84864, { 986202, 986203 } },
    { 84865, { 986200, 986201 } },
    { 84866, { 92839, 92840 } },
    { 84867, { 92842, 92843 } },
    { 129243, { 129245, 129246 } },
    { 965202, { 75 } },
    { 965200, { 1515, 883, 2641, 6991, 982, 1462 } },
    { 891, { 885, 889, 893, 109980 } },
    { 890, { 884, 887, 892, 109981 } },
    { 91634, { 91631, 91633, 91652, 109982 } },
    { 91606, { 91602, 91605, 91651, 109983 } },
    { 5487, { 779, 277420 } },
    { 768, { 1082 } },
    { 49377, { 16979, 49376 } },
    { 33917, { 33876, 33878 } },
    { 850073, { 939300 } },
    { 939300, { 939320, 939340 } },
    { 939301, { 939321, 939341 } },
    { 939302, { 939322, 939342 } },
    { 939303, { 939323, 939343 } },
    { 939304, { 939324, 939344 } },
    { 939305, { 939325, 939345 } },
    { 939306, { 939326, 939346 } },
    { 939307, { 939327, 939347 } },
    { 939308, { 939328, 939348 } },
    { 939309, { 939329, 939349 } },
    { 48263, { 56222 } },
    { 25780, { 277422 } },
    { 71, { 277421 } },
    { 701463, { 277423 } },
    { 275585, { 217364, 275588 } } } };

// Every spell on the stock list of a class trainer, with the first rank of its chain and what it teaches.
std::unordered_set<uint32> const& ClassTrainerSpells()
{
    static std::unordered_set<uint32> spells;
    static std::once_flag once;
    std::call_once(once, []
    {
        CreatureTemplateContainer const* templates = sObjectMgr->GetCreatureTemplates();
        for (CreatureTemplateContainer::const_iterator i = templates->begin(); i != templates->end(); ++i)
        {
            Trainer::Trainer const* trainer = sObjectMgr->GetTrainer(i->first);
            if (!trainer || trainer->GetTrainerType() != Trainer::Type::Class)
                continue;
            for (Trainer::Spell const& spell : trainer->GetSpells())
            {
                spells.insert(spell.SpellId);
                spells.insert(sSpellMgr->GetFirstSpellInChain(spell.SpellId));
                if (SpellInfo const* info = sSpellMgr->GetSpellInfo(spell.SpellId))
                    for (uint8 effect = 0; effect < MAX_SPELL_EFFECTS; ++effect)
                        if (info->Effects[effect].Effect == SPELL_EFFECT_LEARN_SPELL && info->Effects[effect].TriggerSpell)
                            spells.insert(info->Effects[effect].TriggerSpell);
            }
        }
    });
    return spells;
}

// Rule a: a class ability. Every skill line it belongs to is a class line, and it teaches no proficiency or skill.
bool IsClassAbility(uint32 spellId)
{
    SpellInfo const* info = sSpellMgr->GetSpellInfo(spellId);
    if (!info)
        return false;
    for (uint8 effect = 0; effect < MAX_SPELL_EFFECTS; ++effect)
        switch (info->Effects[effect].Effect)
        {
            case SPELL_EFFECT_WEAPON:
            case SPELL_EFFECT_PROFICIENCY:
            case SPELL_EFFECT_DUAL_WIELD:
            case SPELL_EFFECT_PARRY:
            case SPELL_EFFECT_BLOCK:
            case SPELL_EFFECT_DEFENSE:
            case SPELL_EFFECT_SKILL:
            case SPELL_EFFECT_SKILL_STEP:
            case SPELL_EFFECT_LANGUAGE:
            case SPELL_EFFECT_TRADE_SKILL:
                return false;
            default:
                break;
        }

    bool classLine = false;
    SkillLineAbilityMapBounds const bounds = sSpellMgr->GetSkillLineAbilityMapBounds(spellId);
    for (auto line = bounds.first; line != bounds.second; ++line)
    {
        SkillLineEntry const* skill = sSkillLineStore.LookupEntry(line->second->SkillLine);
        if (!skill)
            continue;
        if (skill->categoryId != SKILL_CATEGORY_CLASS)
            return false;
        classLine = true;
    }
    return classLine;
}
}  // namespace

void CleanWildcardAltSpells(Player* bot)
{
    static uint32 const wanted =
        sConfigMgr->GetOption<uint32>("AiPlayerbot.WildcardAltsRemoveUnrolledClassSpells", 0);
    if (!wanted || !bot || !IsWildcardHeroBot(bot) || sRandomPlayerbotMgr.IsRandomBot(bot))
        return;
    static std::string const MARK = "wcme.wildcard.alt_clean";
    if (bot->GetPlayerSetting(MARK, 0).value >= wanted)
        return;

    // Rules c and d: what the character rolled, in every specialization, and the stat paths.
    std::unordered_set<uint32> kept;
    std::unordered_set<uint32> keptRoots;
    auto const keep = [&kept, &keptRoots](uint32 spellId)
    {
        if (!spellId)
            return;
        kept.insert(spellId);
        keptRoots.insert(sSpellMgr->GetFirstSpellInChain(spellId));
    };
    bool rolled = false;
    auto const& ladders = AscensionWildcard::LoadedTables().RankLadders;
    for (uint32 spec = 0; spec < AscensionWildcard::SPECIALIZATION_COUNT; ++spec)
        for (AscensionWildcard::Slot const& slot : AscensionWildcard::Slots(bot, spec))
        {
            std::vector<uint32> const* ranks = slot.EntryId ? RankSpellsOf(slot.EntryId) : nullptr;
            if (!ranks || ranks->empty())
                continue;
            rolled = true;
            for (uint32 rankSpellId : *ranks)
                keep(rankSpellId);
            if (auto const ladder = ladders.find(ranks->front()); ladder != ladders.end())
                for (uint32 rankSpellId : ladder->second)
                    keep(rankSpellId);
        }
    for (AscensionWildcard::PrimaryStatPath const& path : AscensionWildcard::PRIMARY_STAT_PATHS)
        keep(path.SpellId);
    if (!rolled)
    {
        LOG_INFO("playerbots.coa", "Wildcard alt {}: no rolled build to compare with, its spells are left alone",
                 bot->GetName());
        return;
    }

    std::unordered_set<uint32> const& taught = ClassTrainerSpells();
    std::vector<uint32> extra;
    for (auto const& [spellId, spell] : bot->GetSpellMap())
    {
        if (!spell || spell->State == PLAYERSPELL_REMOVED)
            continue;
        uint32 const root = sSpellMgr->GetFirstSpellInChain(spellId);
        if (!taught.contains(spellId) && !taught.contains(root))  // rule b
            continue;
        if (kept.contains(spellId) || keptRoots.contains(root))   // rules c and d
            continue;
        if (!IsClassAbility(spellId))                              // rule a
            continue;
        extra.push_back(spellId);
    }

    // Rule c, second half: what the core granted with an ability the character keeps.
    std::unordered_set<uint32> const leaving(extra.begin(), extra.end());
    for (GrantedWith const& granted : GRANTED_WITH)
        if (bot->HasSpell(granted.entrySpell) && !leaving.contains(granted.entrySpell))
            for (uint32 spellId : granted.spells)
                if (spellId)
                    std::erase(extra, spellId);

    if (extra.size() > 600)
    {
        LOG_WARN("playerbots.coa", "Wildcard alt {}: the rule would remove {} spells, which is not believable; "
                 "nothing was removed", bot->GetName(), extra.size());
        return;
    }

    uint32 removed = 0;
    for (uint32 spellId : extra)
    {
        if (!bot->HasSpell(spellId))
            continue;  // a higher rank or a granted spell that left with an earlier one
        SpellInfo const* info = sSpellMgr->GetSpellInfo(spellId);
        LOG_INFO("playerbots.coa", "Wildcard alt {}: removed unrolled class spell {} ({})", bot->GetName(), spellId,
                 info && info->SpellName[0] ? info->SpellName[0] : "?");
        bot->removeSpell(spellId, SPEC_MASK_ALL, false);
        ++removed;
    }
    bot->UpdatePlayerSetting(MARK, 0, wanted);
    LOG_INFO("playerbots.coa", "Wildcard alt {} (level {}): {} unrolled class spell(s) removed, {} rolled or granted "
             "spell(s) protected", bot->GetName(), bot->GetLevel(), removed, kept.size());
    if (removed)
        ForgetWildcardKit(bot);
}

bool TakeDueWildcardPath(Player const* bot)
{
'@ 'the start of TakeDueWildcardPath in CoaWildcard.cpp'
