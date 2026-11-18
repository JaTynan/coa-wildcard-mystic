# Spellbook entries for the signature racials (docs/race-kits.md): each race with one learns a "Racial Passive" spell
# that explains it when hovered, next to the stock racials. They do nothing themselves; the racial is still the hook in
# its own patch. Spells 9990013-9990017, 9990031, 9990039, 9990045, 9990047 and 9990055 (sql/enchants/150-custom-spells.sql and the client patch,
# client-patch/custom_spells.py). Checked at every login: learned while the racial's setting is on, and unlearned when
# it is turned off. Run by the build from the workspace root, after 40-battlegrounds.ps1 and the racial patches.
# Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: Spellbook entries for the signature racials"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
$class = @'
// Wildcard: a spellbook entry for each signature racial (docs/race-kits.md), kept in step with its setting at login.
class wcme_racial_spellbook : public PlayerScript
{
public:
    wcme_racial_spellbook() : PlayerScript("wcme_racial_spellbook", {PLAYERHOOK_ON_LOGIN}) { }

    void OnPlayerLogin(Player* player) override
    {
        struct Entry { uint8 race; uint32 spell; char const* setting; };
        static Entry const entries[] =
        {
            { RACE_TAUREN, 9990013, "Racials.Plainsrunning" },
            { RACE_ORC, 9990014, "Racials.Bloodrush" },
            { RACE_NIGHTELF, 9990015, "Racials.Ambush" },
            { RACE_TROLL, 9990016, "Racials.VoodooRegeneration" },
            { RACE_DRAENEI, 9990017, "Racials.RadiantPresence" },
            { RACE_UNDEAD_PLAYER, 9990031, "Racials.GraveDefiance" },
            { RACE_HUMAN, 9990039, "Racials.Spellsword" },
            { RACE_GNOME, 9990045, "Racials.Overclock" },
            { RACE_BLOODELF, 9990047, "Racials.ArcaneHunger" },
            { RACE_DWARF, 9990055, "Racials.ProspectorsSpirit" },
        };
        for (Entry const& entry : entries)
        {
            if (player->getRace() != entry.race)
                continue;
            bool const on = sConfigMgr->GetOption<bool>(entry.setting, true);
            if (on && !player->HasSpell(entry.spell))
                player->learnSpell(entry.spell);
            else if (!on && player->HasSpell(entry.spell))
                player->removeSpell(entry.spell, SPEC_MASK_ALL, false);
        }
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_racial_spellbook();`n")
Set-Content $file $text -NoNewline
}
