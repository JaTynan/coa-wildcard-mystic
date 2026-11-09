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
