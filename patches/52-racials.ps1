# Racial abilities: server side of the race changes.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA change that breaks a patch
# stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Every active racial is off the global cooldown
Write-Host "Patch: Every active racial is off the global cooldown"
& {
$file = 'core/src/server/game/Spells/SpellInfoCorrections.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "void SpellMgr::LoadSpellInfoCorrections()`n{`n    uint32 oldMSTime = getMSTime();`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: LoadSpellInfoCorrections was not found' }
# Most racials are already off it. Will of the Forsaken and Gift of the Naaru could not be used while the global
# cooldown ran, and Cannibalize started one; every copy CoA keeps of each is listed. The client patch
# (client-patch/racials.py) carries the same change, since the client also refuses a spell during the cooldown.
$fix = @'

    // Wildcard: every active racial is off the global cooldown (Will of the Forsaken, Cannibalize, Gift of the Naaru).
    ApplySpellFix({ 7744, 667803, 807744, 807745, 1107744, 20577, 1120577, 28880, 59542, 59543, 59544, 59545, 59547,
                    59548, 814280, 814281, 814282, 1128880, 1159542, 1159543, 1159544, 1159545, 1159547, 1159548 },
        [](SpellInfo* spellInfo)
    {
        spellInfo->StartRecoveryCategory = 0;
        spellInfo->StartRecoveryTime = 0;
    });
'@
Set-Content $file $text.Replace($anchor, $anchor + $fix.Replace("`r`n", "`n")) -NoNewline
}
