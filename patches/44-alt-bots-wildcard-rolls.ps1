# A Wildcard Hero alt played as a bot takes the rolls its levels have earned (James, 23 November: alts got stuck at
# level 10 and at every level after it, because a new ability, a new talent and the stat path each wait for the
# player to accept them in the Wildcard window, so he had to log in to each of five characters every few levels).
# SQUID drafts a build only for random bots; for a player's alt it stops at "keeps the rolls its owner made" and
# does nothing. With AiPlayerbot.WildcardAltsRollOnLevelUp = 1 an alt now does the part that only adds:
#   - every ability and talent roll its level has earned and not yet taken, through the core's own roll (the same
#     call a random bot uses), so the skill cards its owner set still steer the rolls;
#   - starting abilities only if it has none at all (the core's rule);
#   - the higher ranks of the abilities it has, up to its level;
#   - a stat path only if it has none: the one its role and abilities suit (the role the owner set with the
#     "wildcard role" whisper, else the one its build already plays). Out of combat, as the core demands; a path due
#     in combat is taken when the fight is over, by SQUID's own step for that.
# It never rerolls, unlearns or spends a Scroll of Fortune, and never changes a stat path the owner chose: what the
# owner picked stays. Runs where SQUID already drafts for random bots: at a level up, when the bot's AI is built
# (coming online) and on a maintenance command. Random bots are untouched. 0 (the code default) = SQUID's own
# behaviour. Read once at start-up.
# Run by the build (step "Apply our patch scripts") after the modules are checked out. Throws if an anchor is gone.
# Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Wildcard Hero alt bots take the rolls they have earned (AiPlayerbot.WildcardAltsRollOnLevelUp)"
Edit-Core 'core/modules/mod-playerbots/src/Ai/Class/Coa/CoaWildcard.cpp' @'
bool DraftWildcardBuild(Player* bot)
{
    if (!IsWildcardHeroBot(bot) || !sRandomPlayerbotMgr.IsRandomBot(bot))
        return false;
'@ @'
// Wildcard (patch 44): a player's alt takes what its levels have earned and nothing its owner chose is changed.
static bool RollForWildcardAlt(Player* bot)
{
    static bool const enabled = sConfigMgr->GetOption<bool>("AiPlayerbot.WildcardAltsRollOnLevelUp", false);
    if (!enabled)
        return false;

    CoaRole const role = GetWildcardRole(bot);
    CoaStyle const style = GetWildcardStyle(bot);
    auto const filled = [bot]
    {
        std::vector<AscensionWildcard::Slot> const slots = AscensionWildcard::Slots(bot);
        return std::count_if(slots.begin(), slots.end(),
                             [](AscensionWildcard::Slot const& slot) { return slot.EntryId != 0; });
    };
    auto const before = filled();

    // The core's own draft: starting abilities only when it has none, then each roll that is due.
    AscensionWildcard::DraftBuild(bot);
    TrainRanks(bot);

    bool pathDue = false;
    if (!AscensionWildcard::PrimaryStat(bot))
    {
        // The server refuses a path change in combat: PlayerbotAI calls this again when the fight is over.
        pathDue = bot->IsInCombat();
        if (!pathDue)
        {
            std::vector<AscensionCoATalentState::KnownEntry> upload = AscensionWildcard::KnownEntries(bot);
            upload.push_back({ PathFor(TargetRoleOf(bot), ShapeOf(bot)), 1 });
            AscensionWildcard::ApplyBuildUpload(bot, upload);
        }
    }
    {
        std::lock_guard<std::mutex> lock(BuildStateLock);
        if (pathDue)
            PathsDue.insert(bot->GetGUID().GetCounter());
        else
            PathsDue.erase(bot->GetGUID().GetCounter());
    }

    auto const after = filled();
    if (after != before)
        LOG_INFO("wcme.alts", "Wildcard alt {} (level {}) took {} roll(s) it had earned",
                 bot->GetName(), bot->GetLevel(), after - before);
    ForgetWildcardKit(bot);
    return role != GetWildcardRole(bot) || style != GetWildcardStyle(bot);
}

bool DraftWildcardBuild(Player* bot)
{
    if (!IsWildcardHeroBot(bot))
        return false;
    if (!sRandomPlayerbotMgr.IsRandomBot(bot))
        return RollForWildcardAlt(bot);
'@ 'the start of DraftWildcardBuild in CoaWildcard.cpp'
