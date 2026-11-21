# Bots hand their dungeon quests in at a Wondrous Wisdomball. The Wisdomball (creature 79025, the pet that offers your
# dungeon quests) offers and ends them by its own script, not through the quest giver tables, so a bot's "talk to quest
# giver" found nothing on it: bots took the quests you shared and did them, but never handed them in (James, 21
# November). Now, when a bot talks to a Wisdomball (yours, when you open it or hand a quest in; the ball lets anyone in
# range use it), it hands in every dungeon quest it has complete that the ball would take
# (AscensionWisdomball::TurnInQuests), choosing its reward as at any quest giver. Other quest givers are unchanged.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: bots hand quests in at the Wondrous Wisdomball"
$file = 'core/modules/mod-playerbots/src/Ai/Base/Actions/QuestAction.cpp'

$include = "#include `"QuestAction.h`"`n"
Edit-Core $file $include ($include + "#include `"AscensionWisdomball.h`"`n") 'the QuestAction.h include'

$menu = "    bot->SetTarget(guid);`n    if (!CoaQuestMenuFits(bot, guid))`n"
Edit-Core $file $menu (@'
    bot->SetTarget(guid);
    // Wildcard: the Wondrous Wisdomball ends dungeon quests by its own script, not the quest giver tables (patch 92).
    if (Creature* ball = questGiver->ToCreature(); ball && AscensionWisdomball::IsWisdomball(ball))
    {
        bool handedIn = false;
        for (uint32 questId : AscensionWisdomball::TurnInQuests(bot))
            if (Quest const* quest = sObjectMgr->GetQuestTemplate(questId))
                handedIn |= ProcessQuest(quest, questGiver);
        return handedIn;
    }
    if (!CoaQuestMenuFits(bot, guid))

'@) 'the quest menu check in QuestAction::ProcessQuests'
