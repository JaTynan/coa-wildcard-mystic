# The spells that bring back a stored pet bring back one of their own kind. Summon Demon, Call Pet and the Revive
# family (Revive Pet, Demon, Undead, Elemental, Dragonkin, Mechanical, Giant) name no creature: they load a stored pet,
# and the core took whichever was current. After a prestige from hunter pets to demons, Summon Demon brought back the
# boar; abandoning the boar, then moving to undead pets, Revive Undead brought back the imp (James, 20 November).
# Now each takes, among the stored pets that aren't stabled, the current one if it's of its kind, or else the most
# recently saved one of its kind:
#   hunter pet (a tamed one): Call Pet 883 / 1100883 / 1350883, Revive Pet 982 / 1100982 / 1350982 / 23499 / 574305 / 5400236
#   demon: Summon Demon 884 / 1100884, Revive Demon 887 / 1100887, Revive Hellfire Imp 540237
#   undead: Revive Undead 889; elemental: Revive Elemental 91605 / 1441605; dragonkin: Revive Dragonkin 91633 / 1441633;
#   mechanical: Revive Mechanical 91638; giant: Revive Giant 91643
# (for the creature kinds, a pet that isn't a tamed one, whose creature is of that type). With none of its kind the cast
# fails with "you have no pet". A dead pet of another kind that is out goes back to the stored list first. A pet
# brought back keeps its name. Revive Aberration (no such creature type in this game version), Revive Pet - Any Kind
# and every other summon are unchanged.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: pet-returning spells bring back a pet of their own kind"

$getInfo = "    static std::pair<PetStable::PetInfo const*, PetSaveMode> GetLoadPetInfo(PetStable const& stable, uint32 petEntry, uint32 petnumber, bool current);`n"
Edit-Core 'core/src/server/game/Entities/Pet/Pet.h' $getInfo ($getInfo + @'
    // Wildcard: for the spells that bring back a stored pet (Summon Demon, Call Pet, the Revive family), the creature of
    // the stored pet of their kind to bring back (0: none of that kind); nothing for any other spell, or when the pet
    // out already is of that kind.
    static Optional<uint32> WcmeStoredPetFor(Player const* owner, uint32 spellId);
    // Wildcard: loads that stored pet (health in percent, 0 for as saved); false if it couldn't be loaded.
    static bool WcmeBringBack(Player* owner, uint32 creatureId, uint32 healthPct);

'@) 'Pet::GetLoadPetInfo in Pet.h'

$loadFromDb = "bool Pet::LoadPetFromDB(Player* owner, uint32 petEntry, uint32 petnumber, bool current, uint32 healthPct /*= 0*/, bool fullMana /*= false*/)`n"
Edit-Core 'core/src/server/game/Entities/Pet/Pet.cpp' $loadFromDb (@'
Optional<uint32> Pet::WcmeStoredPetFor(Player const* owner, uint32 spellId)
{
    constexpr uint32 HunterPet = 0; // otherwise a creature type
    uint32 kind = 0;
    switch (spellId)
    {
        case 883: case 1100883: case 1350883: // Call Pet
        case 982: case 1100982: case 1350982: case 23499: case 574305: case 5400236: // Revive Pet
            kind = HunterPet;
            break;
        case 884: case 1100884: // Summon Demon
        case 887: case 1100887: case 540237: // Revive Demon, Revive Hellfire Imp
            kind = CREATURE_TYPE_DEMON;
            break;
        case 889: kind = CREATURE_TYPE_UNDEAD; break; // Revive Undead
        case 91605: case 1441605: kind = CREATURE_TYPE_ELEMENTAL; break; // Revive Elemental
        case 91633: case 1441633: kind = CREATURE_TYPE_DRAGONKIN; break; // Revive Dragonkin
        case 91638: kind = CREATURE_TYPE_MECHANICAL; break; // Revive Mechanical
        case 91643: kind = CREATURE_TYPE_GIANT; break; // Revive Giant
        default:
            return {};
    }
    auto const ofKind = [kind](uint32 creatureId, PetType type)
    {
        if (kind == HunterPet)
            return type == HUNTER_PET;
        CreatureTemplate const* creature = sObjectMgr->GetCreatureTemplate(creatureId);
        return type != HUNTER_PET && creature && creature->type == kind;
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

bool Pet::WcmeBringBack(Player* owner, uint32 creatureId, uint32 healthPct)
{
    Pet* pet = new Pet(owner, SUMMON_PET); // the saved type replaces this as it loads
    if (pet->LoadPetFromDB(owner, creatureId, 0, false, healthPct))
        return true;
    delete pet;
    return false;
}

'@ + $loadFromDb) 'Pet::LoadPetFromDB in Pet.cpp'

# Cast checks: Summon Demon and Call Pet.
$check = "                        std::pair<PetStable::PetInfo const*, PetSaveMode> info = Pet::GetLoadPetInfo(*playerCaster->GetPetStable(), m_spellInfo->Effects[i].MiscValue, 0, false);`n"
Edit-Core 'core/src/server/game/Spells/Spell.cpp' $check @'
                        // Wildcard: a pet-returning spell brings back a pet of its own kind (patch 83).
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

# Cast checks: the Revive family.
$reviveCheck = "                        PetStable& petStable = playerCaster->GetOrInitPetStable();`n"
Edit-Core 'core/src/server/game/Spells/Spell.cpp' $reviveCheck ($reviveCheck + @'
                        // Wildcard: a pet-returning spell brings back a pet of its own kind (patch 83).
                        if (Optional<uint32> const stored = Pet::WcmeStoredPetFor(playerCaster, m_spellInfo->Id); stored && !*stored)
                            return SPELL_FAILED_NO_PET;

'@) 'the revive pet check in Spell::CheckCast'

# Summon Demon and Call Pet.
$effect = "    Pet* OldSummon = owner->GetPet();`n"
Edit-Core 'core/src/server/game/Spells/SpellEffects.cpp' $effect (@'
    // Wildcard: a pet-returning spell brings back a pet of its own kind (patch 83).
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

$summon = "    float x, y, z;`n    owner->GetClosePoint(x, y, z, owner->GetObjectSize());`n    Pet* pet = owner->SummonPet(petentry, x, y, z, owner->GetOrientation(), SUMMON_PET);`n"
Edit-Core 'core/src/server/game/Spells/SpellEffects.cpp' $summon (@'
    if (storedPick) // only ever load the stored pet: never make a new one in its place
    {
        Pet::WcmeBringBack(owner, petentry, 0);
        return;
    }

'@ + $summon) 'the pet summon in Spell::EffectSummonPet'

# The Revive family.
$revive = "    Pet* pet = player->GetPet();`n    if (!pet)`n    {`n        // Position passed to SummonPet is irrelevant"
Edit-Core 'core/src/server/game/Spells/SpellEffects.cpp' $revive (@'
    // Wildcard: a pet-returning spell brings back a pet of its own kind (patch 83).
    if (Optional<uint32> const stored = Pet::WcmeStoredPetFor(player, m_spellInfo->Id))
    {
        if (!*stored)
            return;
        if (Pet* out = player->GetPet())
        {
            if (out->IsAlive())
                return;
            player->RemovePet(out, PET_SAVE_NOT_IN_SLOT, false); // a dead pet of another kind goes back to the list
        }
        Pet::WcmeBringBack(player, *stored, uint32(damage));
        return;
    }

'@ + $revive) 'the pet revive in Spell::EffectResurrectPet'
