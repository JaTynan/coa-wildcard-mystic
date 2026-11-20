# Summon Demon brings back a demon and Call Pet brings back a hunter pet. Both spells (Summon Demon 884 / 1100884,
# Call Pet 883 / 1100883 / 1350883) name no creature: they load a stored pet, and the core took whichever was current.
# A character who levelled with a hunter pet and then took demons on the next prestige got the boar from Summon
# Demon, and could only fix it by abandoning the boar (James, 20 November). Now each spell takes, among the stored
# pets that aren't stabled, the current one if it's of its kind, or else the most recently saved one of its kind
# (a demon: a summoned pet whose creature is a Demon; a hunter pet: a tamed one). With none of its kind the cast fails
# with "you have no pet". A demon brought back by Summon Demon keeps its name. Other summons are unchanged.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Summon Demon brings back a demon, Call Pet a hunter pet"

$getInfo = "    static std::pair<PetStable::PetInfo const*, PetSaveMode> GetLoadPetInfo(PetStable const& stable, uint32 petEntry, uint32 petnumber, bool current);`n"
Edit-Core 'core/src/server/game/Entities/Pet/Pet.h' $getInfo ($getInfo + @'
    // Wildcard: for Summon Demon and Call Pet, the creature of the stored pet of their kind to bring back (0: none of
    // that kind); nothing for any other spell, or when the pet out already is of that kind.
    static Optional<uint32> WcmeStoredPetFor(Player const* owner, uint32 spellId);

'@) 'Pet::GetLoadPetInfo in Pet.h'

$loadFromDb = "bool Pet::LoadPetFromDB(Player* owner, uint32 petEntry, uint32 petnumber, bool current, uint32 healthPct /*= 0*/, bool fullMana /*= false*/)`n"
Edit-Core 'core/src/server/game/Entities/Pet/Pet.cpp' $loadFromDb (@'
Optional<uint32> Pet::WcmeStoredPetFor(Player const* owner, uint32 spellId)
{
    bool demon = false;
    switch (spellId)
    {
        case 884: case 1100884: // Summon Demon
            demon = true;
            break;
        case 883: case 1100883: case 1350883: // Call Pet
            break;
        default:
            return {};
    }
    auto const ofKind = [demon](uint32 creatureId, PetType type)
    {
        if (!demon)
            return type == HUNTER_PET;
        CreatureTemplate const* creature = sObjectMgr->GetCreatureTemplate(creatureId);
        return type == SUMMON_PET && creature && creature->type == CREATURE_TYPE_DEMON;
    };
    if (Pet* out = owner->GetPet(); out && ofKind(out->GetEntry(), out->getPetType()))
        return {};
    PetStable const* stable = owner->GetPetStable();
    if (!stable)
        return 0u;
    if (stable->CurrentPet && ofKind(stable->CurrentPet->CreatureId, stable->CurrentPet->Type))
        return stable->CurrentPet->CreatureId;
    PetStable::PetInfo const* latest = nullptr;
    for (PetStable::PetInfo const& pet : stable->UnslottedPets)
        if (ofKind(pet.CreatureId, pet.Type) && (!latest || pet.LastSaveTime > latest->LastSaveTime))
            latest = &pet;
    return latest ? latest->CreatureId : 0u;
}

'@ + $loadFromDb) 'Pet::LoadPetFromDB in Pet.cpp'

$check = "                        std::pair<PetStable::PetInfo const*, PetSaveMode> info = Pet::GetLoadPetInfo(*playerCaster->GetPetStable(), m_spellInfo->Effects[i].MiscValue, 0, false);`n"
Edit-Core 'core/src/server/game/Spells/Spell.cpp' $check @'
                        // Wildcard: Summon Demon and Call Pet bring back a pet of their own kind (patch 83).
                        uint32 storedEntry = m_spellInfo->Effects[i].MiscValue;
                        if (!storedEntry)
                            if (Optional<uint32> const stored = Pet::WcmeStoredPetFor(playerCaster, m_spellInfo->Id))
                            {
                                if (!*stored)
                                    return SPELL_FAILED_NO_PET;
                                storedEntry = *stored;
                            }
                        std::pair<PetStable::PetInfo const*, PetSaveMode> info = Pet::GetLoadPetInfo(*playerCaster->GetPetStable(), storedEntry, 0, false);

'@ 'the stored pet check in Spell::CheckCast'

$effect = "    Pet* OldSummon = owner->GetPet();`n"
Edit-Core 'core/src/server/game/Spells/SpellEffects.cpp' $effect (@'
    // Wildcard: Summon Demon and Call Pet bring back a pet of their own kind (patch 83).
    bool storedPick = false;
    if (!petentry)
        if (Optional<uint32> const stored = Pet::WcmeStoredPetFor(owner, m_spellInfo->Id))
        {
            if (!*stored)
                return;
            petentry = *stored;
            storedPick = true;
        }

'@ + $effect) 'the old summon in Spell::EffectSummonPet'

$rename = "    std::string new_name = sObjectMgr->GeneratePetName(petentry);`n    if (!new_name.empty())`n        pet->SetName(new_name);`n"
Edit-Core 'core/src/server/game/Spells/SpellEffects.cpp' $rename @'
    std::string new_name = storedPick ? std::string() : sObjectMgr->GeneratePetName(petentry); // a pet brought back keeps its name
    if (!new_name.empty())
        pet->SetName(new_name);

'@ 'the summoned pet rename in Spell::EffectSummonPet'
