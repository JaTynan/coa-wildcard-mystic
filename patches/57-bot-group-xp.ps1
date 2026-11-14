# Bots in a player's group no longer take a share of the player's kill XP (14 Nov). Normally kill XP is split by level
# across everyone alive and nearby, times a small group bonus (1.4x for five), so a player with four bots got about
# 28% of what the same kill gives solo, which made bot dungeons several times slower than levelling alone. Now the
# split counts only the real players: alone with bots you get the full solo amount; two real players and three bots
# share it as a pair. Bots' own XP is unchanged. Battlegrounds and raids are left alone. Another script that has
# already set the rate to 0 (a challenge denying the reward) still wins: we scale the rate, never raise it from 0.
# Run by the build from the workspace root, after 40-battlegrounds.ps1, whose script loader this registers in.
# Throws if an anchor is gone. Listed in CHANGES.md. Wildcard.BotsTakeNoGroupXP = 0 turns it off.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: bots take no share of a player's group kill XP (Wildcard.BotsTakeNoGroupXP)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
$includes = "#include `"Formulas.h`"`n#include `"Group.h`"`n#include `"KillRewarder.h`"`n"
$class = @'
// Wildcard: bots in a player's group take no share of that player's kill XP.
class wcme_bot_group_xp : public PlayerScript
{
public:
    wcme_bot_group_xp() : PlayerScript("wcme_bot_group_xp", {PLAYERHOOK_ON_REWARD_KILL_REWARDER}) { }

    void OnPlayerRewardKillRewarder(Player* player, KillRewarder* rewarder, bool /*isDungeon*/, float& rate) override
    {
        if (rate <= 0.0f || !player || !rewarder || !player->GetSession() || player->GetSession()->IsBot())
            return;
        Group* group = player->GetGroup();
        Unit* victim = rewarder->GetVictim();
        Player* killer = rewarder->GetKiller();
        if (!group || !victim || victim->IsPlayer() || group->isBGGroup() || group->isRaidGroup() || player->InBattleground())
            return;
        if (!sConfigMgr->GetOption<bool>("Wildcard.BotsTakeNoGroupXP", true))
            return;

        // The same members the core counts: alive and within reward distance (or the killer).
        uint32 allCount = 0, allLevels = 0, realCount = 0, realLevels = 0;
        for (GroupReference* itr = group->GetFirstMember(); itr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (!member || !member->IsAlive() || (member != killer && !member->IsAtGroupRewardDistance(victim)))
                continue;
            uint8 level = member->GetLevel();
            sScriptMgr->OnPlayerBeforeGetLevelForXPGain(member, level);
            ++allCount;
            allLevels += level;
            if (member->GetSession() && !member->GetSession()->IsBot())
            {
                ++realCount;
                realLevels += level;
            }
        }
        if (realCount == allCount || !realCount || !realLevels || !allLevels)
            return;

        // rate = groupBonus(count) * level / sumOfLevels; swap the whole group for just the real players.
        float const before = Acore::XP::xp_in_group_rate(allCount, false) / float(allLevels);
        float const after = Acore::XP::xp_in_group_rate(realCount, false) / float(realLevels);
        rate *= after / before;
    }
};

'@
$text = $text.Replace($include, $include + $includes)
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_bot_group_xp();`n")
Set-Content $file $text -NoNewline
}
