# Group kill XP in dungeons, raids, battlegrounds and Manastorm: not split, scaled with the group. Enemies there are tougher for a
# group (Manastorm: x1.6 to x3.4 health for 2 to 5 players; dungeons x2.5, raids x2.2 whatever the size), but kill XP
# was split between the members as anywhere else, so a group of 5 earned well under half the solo rate (James, 21
# November: a group Manastorm takes about 4 times as long as solo, so break even needs about 4 times the XP each).
# Now each group member in reward range gets the kill's full XP (what the core works out for the group, before auras
# and realm rates) times a factor for how many alive members are in range:
#   GroupXP.Manastorm (Manastorm and other scripted private instances): 1.8, 2.6, 3.3, 4.0 for 2, 3, 4, 5+;
#   GroupXP.Dungeon (dungeons and raids), a little lower so both are worth doing: 1.4, 1.8, 2.2, 2.5;
#   GroupXP.Battleground (battleground kills, where they give XP): as dungeons.
# The last factor holds for bigger groups and nothing is split, so 20 players in a Manastorm each get the kill's XP
# times 4 (James: rather 20 players having fun going slow with OK XP than encouraging solo play). Arenas give no XP.
# Bots count as members, as they do for the health scaling. The core's grey-member halving, XP auras, the realm XP
# rate, prestige, Manastorm.ExperienceRate and the weekly event still apply on top. Solo and open-world groups are
# unchanged. An empty setting turns its part off (the core's split).
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: group XP in dungeons, raids and Manastorm"
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'

$class = @'
// Wildcard: group kill XP in dungeons, raids, battlegrounds and Manastorm, not split and scaled with the group
// (patch 93). The last factor holds for bigger groups.
class wcme_group_xp : public PlayerScript
{
public:
    wcme_group_xp() : PlayerScript("wcme_group_xp", { PLAYERHOOK_ON_REWARD_KILL_REWARDER }) { }

    void OnPlayerRewardKillRewarder(Player* player, KillRewarder* rewarder, bool /*isDungeon*/, float& rate) override
    {
        Player* killer = rewarder ? rewarder->GetKiller() : nullptr;
        Unit* victim = rewarder ? rewarder->GetVictim() : nullptr;
        Group* group = killer ? killer->GetGroup() : nullptr;
        Map* map = victim ? victim->FindMap() : nullptr;
        if (!player || !group || !victim || !map || map->IsBattleArena())
            return;
        char const* key = nullptr;
        if (map->IsBattleground())
            key = "GroupXP.Battleground";
        else if (victim->IsPlayer())
            return; // world PvP has its own XP (patch 40)
        else if (map->IsScriptedPrivateInstance())
            key = "GroupXP.Manastorm";
        else if (map->IsDungeon())
            key = "GroupXP.Dungeon";
        if (!key)
            return;

        // Alive members in reward range, as the core counts them for its split.
        uint32 count = 0;
        for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
            if (Player* member = ref->GetSource())
                if (member->IsAlive() && (member == killer || member->IsAtGroupRewardDistance(victim)))
                    ++count;
        if (count < 2)
            return;

        std::vector<float> factors;
        std::istringstream text(sConfigMgr->GetOption<std::string>(key, ""));
        for (float factor; text >> factor;)
            factors.push_back(std::max(0.0f, factor));
        if (factors.empty())
            return; // the core's split
        rate = factors[std::min<std::size_t>(count - 2, factors.size() - 1)];
    }
};

'@
Edit-Core $file "void AddSC_AscensionAdventurerCache()`n{`n" ($class + "void AddSC_AscensionAdventurerCache()`n{`n") 'AddSC_AscensionAdventurerCache'

$register = "    new world_pvp_kill_xp();`n"
Edit-Core $file $register ($register + "    new wcme_group_xp();`n") 'the world_pvp_kill_xp registration'

$include = "#include `"ScriptMgr.h`"`n"
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
foreach ($header in @('KillRewarder.h', 'Group.h', 'Config.h')) {
    if ($text -notmatch [regex]::Escape("#include `"$header`"")) { $text = $text.Replace($include, $include + "#include `"$header`"`n") }
}
if ($text -notmatch '#include <sstream>') { $text = $text.Replace($include, $include + "#include <sstream>`n") }
Set-Content $file $text -NoNewline
