# Bots (SQUID mod-playerbots): who they fight, where they level, raising the dead.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Bot levels near real players (AiPlayerbot.WildcardLevelNearPlayersPct, off at 0)
Write-Host "Patch: Bot levels near real players (AiPlayerbot.WildcardLevelNearPlayersPct, off at 0)"
& {
$file = 'core/modules/mod-playerbots/src/Bot/RandomPlayerbotMgr.cpp'
$text = Get-Content $file -Raw
$roll = "        uint32 roll = urand(1, 100);`n        if (roll <= 100 * sPlayerbotAIConfig.randomBotMaxLevelChance)"
$text = $text -replace "`r`n", "`n"
if (-not $text.Contains($roll)) { throw 'SQUID changed: the level roll in RandomizeFirst was not found' }
if (-not $text.Contains('#include "Player.h"')) { throw 'SQUID changed: #include "Player.h" not found' }
$near = @'
        uint32 roll = urand(1, 100);
        uint32 wildcardNearLevel = 0;
        uint32 wildcardNearPct = sConfigMgr->GetOption<uint32>("AiPlayerbot.WildcardLevelNearPlayersPct", 0);
        if (wildcardNearPct && urand(1, 100) <= wildcardNearPct)
        {
            std::vector<uint32> realLevels;
            for (Player* real : players)
                if (real && real->IsInWorld() && real->GetSession() && !real->GetSession()->IsBot())
                    realLevels.push_back(real->GetLevel());
            if (!realLevels.empty())
            {
                uint32 centre = realLevels[urand(0, realLevels.size() - 1)];
                uint32 low = std::max(minLevel, centre > 5 ? centre - 5 : 1u);
                uint32 high = std::min(maxLevel, centre + 5);
                if (low <= high)
                    wildcardNearLevel = urand(low, high);
            }
        }
        if (wildcardNearLevel)
        {
            level = wildcardNearLevel;
        }
        else if (roll <= 100 * sPlayerbotAIConfig.randomBotMaxLevelChance)
'@
$text = $text.Replace($roll, $near.TrimEnd())
$text = $text.Replace('#include "Player.h"', "#include `"Player.h`"`n#include `"Config.h`"")
Set-Content $file $text -NoNewline
}

# ---- Wildcard bots without a resurrection still raise dead group members out of combat
Write-Host "Patch: Wildcard bots without a resurrection still raise dead group members out of combat"
& {
$file = 'core/modules/mod-playerbots/src/Ai/Class/Coa/CoaAiObjectContext.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$trigger = @'
        return bot->IsAlive() && !bot->IsInCombat() && ClassHas(bot, KIND_RESURRECT) && DeadGroupMember(bot) &&
               !GroupFighting(bot) &&
               HasReadyAbility(botAI, bot, [](uint16 kind) { return (kind & KIND_RESURRECT) != 0; });
'@
$cast = @'
        SpellInfo const* cast = CastFirst(botAI, bot,
            KnownAbilities(bot, [](uint16 kind) { return (kind & KIND_RESURRECT) != 0; }), dead);
        if (cast)
            botAI->SayToParty("Resurrecting " + dead->GetName() + ".");
'@
$trigger = $trigger.Replace("`r`n", "`n"); $cast = $cast.Replace("`r`n", "`n")
foreach ($anchor in $trigger, $cast) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'SQUID changed: the CoA resurrect trigger or action was not found' }
}
# A Wildcard bot only knows a resurrection if it rolled one, so most groups watched their dead. One that has
# none uses the priest's Resurrection for its level (no mana cost, normal cast time), only out of combat.
$triggerNew = @'
        return bot->IsAlive() && !bot->IsInCombat() && DeadGroupMember(bot) && !GroupFighting(bot) &&
               ((ClassHas(bot, KIND_RESURRECT) &&
                 HasReadyAbility(botAI, bot, [](uint16 kind) { return (kind & KIND_RESURRECT) != 0; })) ||
                IsWildcardHeroBot(bot));
'@
$castNew = @'
        SpellInfo const* cast = CastFirst(botAI, bot,
            KnownAbilities(bot, [](uint16 kind) { return (kind & KIND_RESURRECT) != 0; }), dead);
        if (!cast && IsWildcardHeroBot(bot))
        {
            static constexpr std::array<std::pair<uint8, uint32>, 7> ResurrectionRanks = { {
                { 78, 48171 }, { 68, 25435 }, { 58, 20770 }, { 46, 10881 }, { 34, 10880 }, { 22, 2010 }, { 1, 2006 } } };
            uint32 spellId = 2006;
            for (auto const& [level, id] : ResurrectionRanks)
                if (bot->GetLevel() >= level)
                {
                    spellId = id;
                    break;
                }
            if (bot->CastSpell(dead, spellId, TriggerCastFlags(TRIGGERED_IGNORE_POWER_AND_REAGENT_COST)) == SPELL_CAST_OK)
                cast = sSpellMgr->GetSpellInfo(spellId);
        }
        if (cast)
            botAI->SayToParty("Resurrecting " + dead->GetName() + ".");
'@
$text = $text.Replace($trigger, $triggerNew.Replace("`r`n", "`n")).Replace($cast, $castNew.Replace("`r`n", "`n"))
Set-Content $file $text -NoNewline
}

# ---- Bots tell friend from foe by team, not race (cross-faction battlegrounds)
Write-Host "Patch: Bots tell friend from foe by team, not race (cross-faction battlegrounds)"
& {
$file = 'core/modules/mod-playerbots/src/Bot/PlayerbotAI.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$race = 'bool PlayerbotAI::IsOpposing(Player* player) { return IsOpposing(player->getRace(), bot->getRace()); }'
if (-not $text.Contains($race)) { throw 'SQUID changed: PlayerbotAI::IsOpposing(Player*) was not found' }
# With CFBG.KeepRace a player on the other side keeps their race; their team (setTeamId by CFBG) is what counts.
$team = 'bool PlayerbotAI::IsOpposing(Player* player) { return player->GetTeamId() != bot->GetTeamId(); }'
Set-Content $file $text.Replace($race, $team) -NoNewline
}

# ---- Bots attack Mercenaries of their own faction too (when the bot is in a PvP ruleset)
Write-Host "Patch: Bots attack Mercenaries of their own faction too (when the bot is in a PvP ruleset)"
& {
$file = 'core/modules/mod-playerbots/src/Ai/Base/Value/EnemyPlayerValue.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$old = 'if (enemy && botAI->IsOpposing(enemy) && enemy->IsPvP() &&'
if (-not $text.Contains($old)) { throw 'SQUID changed: the enemy player check in NearestEnemyPlayersValue was not found' }
if (-not $text.Contains('static bool CoaPvpRuleset(Unit const* unit)')) { throw 'SQUID changed: CoaPvpRuleset was not found' }
# CoA's Mercenary (aura 9930874, core AscensionMercenary.cpp) is free-for-all against anyone in War Mode or
# High Risk, own faction included; the core already lets those characters attack them.
$new = 'if (enemy && (botAI->IsOpposing(enemy) || (enemy->HasAura(9930874) && CoaPvpRuleset(bot))) && enemy->IsPvP() &&'
Set-Content $file $text.Replace($old, $new) -NoNewline
}

# ---- Some random bots travel in groups (AiPlayerbot.WildcardGroupSoloPct and the shares after it, SQUID's split when unset)
Write-Host "Patch: Some random bots travel in groups (AiPlayerbot.WildcardGroupSoloPct)"
& {
$file = 'core/modules/mod-playerbots/src/Bot/PlayerbotAI.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = '#include "PlayerbotAI.h"'
$old = @'
GrouperType PlayerbotAI::GetGrouperType()
{
    uint32 grouperNumber = GetFixedBotNumber(100);

'@
$old = $old.Replace("`r`n", "`n")
foreach ($anchor in "$include`n", $old) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'SQUID changed: GetGrouperType was not found' }
}
# Each bot has a fixed number 0-99 that picks its part: solo, a member who joins groups, or a leader who invites
# nearby members up to a group size. SQUID's split is 20% solo, 60% members, 20% leaders. Our shares are of bots, so
# "30% in pairs" is 15% leaders of two and 15% members; whatever is not solo or a leader is a member.
$new = $old + @'
    if (int32 const wildcardSolo = sConfigMgr->GetOption<int32>("AiPlayerbot.WildcardGroupSoloPct", -1); wildcardSolo >= 0)
    {
        float const n = float(grouperNumber);
        if (n < float(wildcardSolo))
            return HasGameClientMaster() ? GrouperType::MEMBER : GrouperType::SOLO;
        float edge = float(wildcardSolo) + sConfigMgr->GetOption<float>("AiPlayerbot.WildcardGroupPairPct", 0.0f) / 2.0f;
        if (n < edge)
            return GrouperType::LEADER_2;
        edge += sConfigMgr->GetOption<float>("AiPlayerbot.WildcardGroupFourPct", 0.0f) / 4.0f;
        if (n < edge)
            return GrouperType::LEADER_4;
        edge += sConfigMgr->GetOption<float>("AiPlayerbot.WildcardGroupFivePct", 0.0f) / 5.0f;
        if (n < edge)
            return GrouperType::LEADER_5;
        return GrouperType::MEMBER;
    }

'@
$text = $text.Replace("$include`n", "$include`n#include `"Config.h`"`n").Replace($old, $new.Replace("`r`n", "`n"))
Set-Content $file $text -NoNewline
}

# ---- A bot leader invites only member bots, never a real player, a solo bot or another leader
Write-Host "Patch: A bot leader invites only member bots, never a real player, a solo bot or another leader"
& {
$file = 'core/modules/mod-playerbots/src/Ai/Base/Actions/InviteToGroupAction.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$old = @'
        if (player->GetGroup())
            continue;

        if (!PlayerbotAIConfig::instance().randomBotInvitePlayer && IsSelfBot(player))
            continue;

        Group* group = bot->GetGroup();
'@
$old = $old.Replace("`r`n", "`n")
if (([regex]::Matches($text, [regex]::Escape($old))).Count -ne 1) { throw 'SQUID changed: the target checks in InviteNearbyToGroupAction were not found' }
# "invite nearby" (AiPlayerbot.RandomBotGroupNearby, marked unfinished by SQUID) checked the inviter's part instead of
# the target's, so it invited solo bots and other leaders, and it invited real players nearby whatever
# RandomBotInvitePlayer said. Now the target must be a member bot that no real player controls.
$new = $old.Replace("        Group* group = bot->GetGroup();", @'
        if (PlayerbotAI* targetAI = GET_PLAYERBOT_AI(player))
        {
            if (targetAI->HasGameClientMaster() || IsRealPlayer(targetAI->GetMaster()) ||
                targetAI->GetGrouperType() != GrouperType::MEMBER)
                continue;
        }
        else if (!PlayerbotAIConfig::instance().randomBotInvitePlayer)
            continue;

        Group* group = bot->GetGroup();
'@.Replace("`r`n", "`n"))
Set-Content $file $text.Replace($old, $new) -NoNewline
}
