# Registers the Mystic Enchant scripts added by mystic-enchants-scripts.patch (src/server/coa/WcmeEnchantScripts.cpp:
# Rush of Blood, Martial Crescendo, Tools of War, Curse of Arugal, Primordial Fury, Ice Lash, Words of Healing and
# Borrowed Time, Ambidextrous, Nature's Fervor) next to the enchant action scripts that mystic-enchants-actions.patch
# registers. The .patch files are applied before these scripts, so both anchors exist.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: register the Mystic Enchant scripts"
& {
$file = 'core/src/server/coa/CoAScriptLoader.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$declare = "void AddSC_WcmeEnchantActions();`n"
$call = "    AddSC_WcmeEnchantActions();`n"
if (([regex]::Matches($text, [regex]::Escape($declare))).Count -ne 1) { throw 'CoAScriptLoader.cpp has no AddSC_WcmeEnchantActions declaration (is mystic-enchants-actions.patch applied?)' }
if (([regex]::Matches($text, [regex]::Escape($call))).Count -ne 1) { throw 'CoAScriptLoader.cpp has no AddSC_WcmeEnchantActions call (is mystic-enchants-actions.patch applied?)' }
$text = $text.Replace($declare, $declare + "void AddSC_WcmeEnchantScripts();`n")
$text = $text.Replace($call, $call + "    AddSC_WcmeEnchantScripts();`n")
Set-Content $file $text -NoNewline
}
