# Wildcard bots bring their pets back. In SQUID's bots only the Hunter class has a "pet dead: Revive Pet" step; the
# CoA routine Wildcard Heroes use had none, so once a Wildcard bot's pet died it stayed dead (James, 21 November).
# Now, out of combat and alive, a CoA or Wildcard bot whose pet is dead or missing tries its own pet spells: first the
# ones that bring a stored pet back without a cast (Call Pet, Summon Demon), then the Revive family (Revive Pet,
# Demon, Undead, Elemental, Dragonkin, Mechanical, Giant, Aberration, Any Kind). Only spells it knows, and only one the
# server's own cast check accepts, which since patch 83 means one with a stored pet of its kind to bring back.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID's bots changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: Wildcard bots bring their pets back"
$file = 'core/modules/mod-playerbots/src/Ai/Class/Coa/CoaAiObjectContext.cpp'

$include = "#include `"TemporarySummon.h`"`n"
Edit-Core $file $include ("#include `"Pet.h`"`n" + $include) 'the TemporarySummon.h include'

$strategy = "// Out of combat: keep the long buffs up on the bot and its group.`n"
Edit-Core $file $strategy (@'
// Wildcard: a bot whose pet died or went missing brings it back with its own pet spell. Only the Hunter class had
// this step; the CoA routine Wildcard Heroes use had none, so a dead pet stayed dead.
class CoaRevivePetAction : public Action
{
public:
    CoaRevivePetAction(PlayerbotAI* botAI) : Action(botAI, "coa revive pet") {}

    bool isUseful() override
    {
        if (bot->IsInCombat() || bot->IsMounted() || bot->IsInFlight() || !bot->IsAlive())
            return false;
        Pet* pet = bot->GetPet();
        return !pet || !pet->IsAlive();
    }

    bool Execute(Event /*event*/) override
    {
        // A stored pet comes back without a cast first, then the revives. The server's cast check picks: a spell
        // with no stored pet of its kind (patch 83), or a summon while a dead pet is out, is refused.
        static constexpr uint32 Spells[] = {
            883, 1100883, 1350883, 884, 1100884,                       // Call Pet, Summon Demon
            982, 1100982, 1350982, 23499, 574305, 5400236,             // Revive Pet
            887, 1100887, 540237, 889,                                 // Revive Demon, Hellfire Imp, Undead
            91605, 1441605, 91633, 1441633, 91638, 91643, 91648, 99799 // Elemental, Dragonkin, Mechanical, Giant,
        };                                                             // Aberration, Any Kind
        for (uint32 spell : Spells)
            if (bot->HasSpell(spell) && botAI->CanCastSpell(spell, bot))
                return botAI->CastSpell(spell, bot);
        return false;
    }
};

'@ + $strategy) 'the CoaBuffStrategy comment'

$trigger = "        triggers.push_back(new TriggerNode(`"often`", { NextAction(`"coa buff`", ACTION_NORMAL + 5) }));`n"
Edit-Core $file $trigger ($trigger + "        // Wildcard: a dead or missing pet is brought back before the buffs.`n        triggers.push_back(new TriggerNode(`"often`", { NextAction(`"coa revive pet`", ACTION_NORMAL + 6) }));`n") 'the coa buff trigger in CoaBuffStrategy'

$creator = "        creators[`"coa buff`"] = &CoaActionFactoryInternal::coa_buff;`n"
Edit-Core $file $creator ($creator + "        creators[`"coa revive pet`"] = &CoaActionFactoryInternal::coa_revive_pet;`n") 'the coa buff action creator'

$static = "    static Action* coa_buff(PlayerbotAI* botAI) { return new CoaBuffAction(botAI); }`n"
Edit-Core $file $static ($static + "    static Action* coa_revive_pet(PlayerbotAI* botAI) { return new CoaRevivePetAction(botAI); }`n") 'the coa_buff factory function'
