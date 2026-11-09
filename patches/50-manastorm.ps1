# Manastorm: dead bots at the end of a floor.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Manastorm raises every dead member of the run when a floor is cleared, bots included
Write-Host "Patch: Manastorm raises every dead member of the run when a floor is cleared, bots included"
& {
$file = 'core/src/server/coa/AscensionManastorm.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$old = @'
            run.encounter->phase = Phase::Completed;
            if (!player->IsAlive())
            {
                player->ResurrectPlayer(1.0f);
                player->SpawnCorpseBones();
            }
'@
$old = $old.Replace("`r`n", "`n")
if (-not $text.Contains($old)) { throw 'CoA changed: the resurrection in Manastorm Finish() was not found' }
# Finish() only raised the members with their own run (real players); bots in the group stayed dead at the
# end of the floor. Raise everyone dead in the run's private scene.
$new = $old + "`n" + @'
            for (auto const& reference : player->GetMap()->GetPlayers())
                if (Player* member = reference.GetSource(); member && member != player && !member->IsAlive()
                    && player->GetMap()->IsScriptedPrivateMember(member->GetGUID()))
                {
                    member->ResurrectPlayer(1.0f);
                    member->SpawnCorpseBones();
                }
'@
Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n")) -NoNewline
}
# ---- Every resurrection in a Manastorm run uses one of the run's shared charges (the item already does)
Write-Host "Patch: Every resurrection in a Manastorm run uses one of the run's shared charges"
& {
$file = 'core/src/server/coa/AscensionManastorm.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$methodsAt = "        void UsedResurrection(Player* player)`n"
$check = @'
            if (Player* player = spell->GetCaster()->ToPlayer())
            {
                SpellCastResult const utility = ManastormService::Get().CheckUtility(player, spell->GetSpellInfo()->Id);
                if (utility != SPELL_CAST_OK)
                    result = utility;
            }
'@
$hit = @'
            if (!miss && spell->GetSpellInfo()->Id == 93309)
                if (Player* player = spell->GetCaster()->ToPlayer())
                    ManastormService::Get().UsedResurrection(player);
'@
$check = $check.Replace("`r`n", "`n") + "`n"; $hit = $hit.Replace("`r`n", "`n") + "`n"
foreach ($anchor in $methodsAt, $check, $hit) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: a Manastorm resurrection anchor was not found' }
}
# The run's 5 resurrection charges are shared by the group (one Encounter), but only the run's own item (93309) used
# them: a resurrection spell from a player or a bot was free, so a group of bots made runs easy. Now any resurrection
# cast inside a run's scene needs a charge and uses one; the Manastorm window already shows how many are left.
$methods = @'
        std::shared_ptr<Encounter> SceneEncounter(Player const* player)
        {
            Map* map = player->FindMap();
            if (!map || !map->IsScriptedPrivateInstance()
                || !map->ToInstanceMap()->IsScriptedPrivateMember(player->GetGUID()))
                return nullptr;
            ObjectGuid const owner = map->ToInstanceMap()->GetScriptedPrivateOwner();
            for (auto const& [guid, run] : runs)
                if (run.encounter && run.encounter->instanceId == player->GetInstanceId() && run.encounter->owner == owner
                    && run.GetScene().map == player->GetMapId())
                    return run.encounter;
            return nullptr;
        }

        SpellCastResult CheckSharedResurrection(Player* player)
        {
            if (!enabled.load())
                return SPELL_CAST_OK;
            std::lock_guard<std::recursive_mutex> lock(mutex);
            std::shared_ptr<Encounter> const encounter = SceneEncounter(player);
            return encounter && !encounter->resurrectionCharges ? SPELL_FAILED_NO_CHARGES_REMAIN : SPELL_CAST_OK;
        }

        void UsedSharedResurrection(Player* player)
        {
            std::lock_guard<std::recursive_mutex> lock(mutex);
            if (std::shared_ptr<Encounter> const encounter = SceneEncounter(player); encounter && encounter->resurrectionCharges)
                --encounter->resurrectionCharges;
        }

'@
$checkNew = $check + @'
            if (result == SPELL_CAST_OK && spell->GetSpellInfo()->Id != 93309
                && (spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT)
                    || spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT_NEW)))
                if (Player* player = spell->GetCaster()->ToPlayer())
                    result = ManastormService::Get().CheckSharedResurrection(player);

'@
$hitNew = $hit + @'
            if (!miss && target != spell->GetCaster() && spell->GetSpellInfo()->Id != 93309
                && (spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT)
                    || spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT_NEW)))
                if (Player* player = spell->GetCaster()->ToPlayer())
                    ManastormService::Get().UsedSharedResurrection(player);

'@
$text = $text.Replace($methodsAt, $methods.Replace("`r`n", "`n") + "`n" + $methodsAt)
$text = $text.Replace($check, $checkNew.Replace("`r`n", "`n")).Replace($hit, $hitNew.Replace("`r`n", "`n"))
Set-Content $file $text -NoNewline
}
