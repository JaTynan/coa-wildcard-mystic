# Dungeon Clear starts by itself in a dungeon. It only ran when a player typed "dc on" (James, 21 November: on by
# default, all the time, with a reminder of how to turn it off and on). Now, for a real player in a 5-player dungeon
# (not a raid, not a Manastorm or other private instance) whose group has a tank bot:
#   once the tank bot is in the same instance, alive, within 60 yards and nobody of the two is fighting, the player's
#   group gets "dc on" as if the player had typed it;
#   if the run is on, the player gets a chat line saying so and how to turn it off ("dc off"), back on ("dc on"),
#   pause it ("dc pause") or skip a stuck step ("dc skip"), all in party chat.
# Once per instance: after "dc off" it stays off in that instance, also after leaving and coming back; a new instance
# (a new run) starts it again. A run already on (the dungeon finder's own auto clear) only gets the reminder.
# DungeonClear.AutoStart = 0 in mod_dungeon_clear.conf turns this off (default 1).
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Dungeon Clear starts by itself in a dungeon"

$ctor = "public:`n    explicit Player(WorldSession* session);`n"
Edit-Core 'core/src/server/game/Entities/Player/Player.h' $ctor ($ctor + "    uint32 WcmeDcAutoTimer = 0;`n    uint32 WcmeDcAutoInstance = 0;`n") 'the Player constructor in Player.h'

$file = 'core/modules/mod-dungeon-clear/src/DungeonClearModule.cpp'

$include = "#include `"DcModuleEnable.h`"`n"
Edit-Core $file $include ($include + @'
#include "Chat.h"
#include "Config.h"
#include "DcStrategyGate.h"
#include "Ai/Dungeon/DungeonClear/Util/DcLeaderSignal.h"

'@) 'the DcModuleEnable.h include in DungeonClearModule.cpp'

$addSc = "void AddSC_dungeon_clear_module()`n{`n"
Edit-Core $file $addSc (@'
// Wildcard: Dungeon Clear starts by itself once the party's tank bot is in the dungeon with the player, and the player
// is told how to turn it off and on. Once per instance, so "dc off" sticks for that run.
class WcmeDungeonClearAutoStartScript : public PlayerScript
{
public:
    WcmeDungeonClearAutoStartScript()
        : PlayerScript("WcmeDungeonClearAutoStartScript", { PLAYERHOOK_ON_UPDATE }) {}

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        player->WcmeDcAutoTimer += diff;
        if (player->WcmeDcAutoTimer < 2000)
            return;
        player->WcmeDcAutoTimer = 0;

        if (!DcModule::IsEnabled() || !sConfigMgr->GetOption<bool>("DungeonClear.AutoStart", true))
            return;
        if (!player->IsInWorld() || !player->GetSession() || player->GetSession()->IsBot() || !player->IsAlive() ||
            player->IsInCombat() || !player->GetGroup())
            return;
        Map* map = player->GetMap();
        if (!map || !map->IsDungeon() || map->IsRaid() || map->IsScriptedPrivateInstance())
            return;
        uint32 const instance = map->GetInstanceId();
        if (!instance || player->WcmeDcAutoInstance == instance)
            return;

        // The tank bot that would lead the run, here with the player and out of a fight.
        Player* tank = DcLeaderSignal::FindLeaderTank(player);
        PlayerbotAI* tankAI = tank ? GET_PLAYERBOT_AI(tank) : nullptr;
        if (!tankAI || tank->GetMap() != map || !tank->IsAlive() || tank->IsInCombat() ||
            !tank->IsWithinDistInMap(player, 60.0f))
            return;

        player->WcmeDcAutoInstance = instance; // one try per instance, whatever comes of it
        if (!DcRun::Of(tankAI).enabled)
        {
            DcStrategyGate::Reconcile(tank);
            tankAI->DoSpecificAction("dc on", Event("dc", "", player), true);
            LOG_INFO("playerbots.dungeonclear", "Auto start: issued `dc on` to {} for {} (map {}, instance {})",
                     tank->GetName(), player->GetName(), map->GetId(), instance);
        }
        if (DcRun::Of(tankAI).enabled)
            ChatHandler(player->GetSession()).SendSysMessage(
                "|cff00ccffDungeon Clear is on:|r " + tank->GetName() + " leads the run. In party chat: "
                "|cffffff00dc off|r to lead yourself, |cffffff00dc on|r to hand it back, "
                "|cffffff00dc pause|r to hold, |cffffff00dc skip|r if it gets stuck.");
    }
};

'@ + $addSc) 'AddSC_dungeon_clear_module in DungeonClearModule.cpp'

$register = "    new DungeonClearLateJoinerScript();`n"
Edit-Core $file $register ($register + "    new WcmeDungeonClearAutoStartScript();`n") 'the DungeonClearLateJoinerScript registration'
