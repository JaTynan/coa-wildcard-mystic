# Night Elf signature racial: Ambush (docs/race-kits.md). Entering stealth (Shadowmeld, Stealth, Prowl) readies your
# next ability: 10% cheaper and 50% more damage or healing. At most once every 20 sec. The buff is our spell 9990004
# (sql/enchants/150-custom-spells.sql and the client patch, client-patch/custom_spells.py); its one charge is used up
# by the next ability that hits (spell_proc row in the same SQL file). Run by the build from the workspace root, after
# 40-battlegrounds.ps1 and 54-racial-plainsrunning.ps1. Throws if an anchor is gone. Listed in CHANGES.md.
# Racials.Ambush = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Ambush state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    bool WcmeAmbushStealthed = false;`n    uint32 WcmeAmbushCooldown = 0;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Ambush for Night Elves (Racials.Ambush)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
$class = @'
// Wildcard: Night Elf Ambush (docs/race-kits.md).
class wcme_ambush : public PlayerScript
{
public:
    wcme_ambush() : PlayerScript("wcme_ambush", {PLAYERHOOK_ON_UPDATE}) { }

    static constexpr uint32 Ready = 9990004;
    static constexpr uint32 CooldownMs = 20000;

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (player->getRace() != RACE_NIGHTELF)
            return;
        player->WcmeAmbushCooldown = player->WcmeAmbushCooldown > diff ? player->WcmeAmbushCooldown - diff : 0;
        if (!sConfigMgr->GetOption<bool>("Racials.Ambush", true))
        {
            if (player->HasAura(Ready))
                player->RemoveAurasDueToSpell(Ready);
            player->WcmeAmbushStealthed = false;
            return;
        }
        bool const stealthed = player->IsAlive() && player->HasAuraType(SPELL_AURA_MOD_STEALTH);
        if (stealthed && !player->WcmeAmbushStealthed && !player->WcmeAmbushCooldown && !player->HasAura(Ready))
            if (player->AddAura(Ready, player))
                player->WcmeAmbushCooldown = CooldownMs;
        player->WcmeAmbushStealthed = stealthed;
    }
};

'@
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_ambush();`n")
Set-Content $file $text -NoNewline
}
