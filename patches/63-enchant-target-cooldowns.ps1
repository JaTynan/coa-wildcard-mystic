# Per-target proc cooldowns for Mystic Enchants. A spell listed in the world table wcme_proc_target_cooldown
# (spell_id, target_cooldown_ms, shared_cooldown_ms) no longer uses its spell_proc cooldown: it can proc again on a
# target only after target_cooldown_ms, and on anything at all only after shared_cooldown_ms (0.1 sec keeps it to one
# proc per attack, even when the attack hits a whole pack). Rows come from sql/enchants/015-runaway-procs.sql; the
# table is read once, at the first proc after a start. Servers without this patch ignore the table and use spell_proc.
# Run by the build from the workspace root. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

Write-Host "Patch: per-target enchant proc cooldowns (header)"
& {
$file = 'core/src/server/game/Spells/Auras/SpellAuras.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include <map>`n"
$member = "    TimePoint m_procCooldown;`n"
if (([regex]::Matches($text, [regex]::Escape($include))).Count -ne 1) { throw 'Core changed: #include <map> in SpellAuras.h was not found' }
if (([regex]::Matches($text, [regex]::Escape($member))).Count -ne 1) { throw 'Core changed: m_procCooldown in SpellAuras.h was not found' }
$text = $text.Replace($include, $include + "#include <unordered_map>`n")
$text = $text.Replace($member, $member + "    std::unordered_map<ObjectGuid, TimePoint> WcmeTargetReady; // Wildcard: per-target enchant proc cooldowns`n")
Set-Content $file $text -NoNewline
}

Write-Host "Patch: per-target enchant proc cooldowns (checks)"
& {
$file = 'core/src/server/game/Spells/Auras/SpellAuras.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"GridNotifiersImpl.h`"`n"
$check = "    // check proc cooldown`n    if (IsProcOnCooldown(now))`n        return 0;`n"
$prepare = "    // cooldowns should be added to the whole aura (see 51698 area aura)`n    AddProcCooldown(now + procEntry->Cooldown);`n"
foreach ($anchor in @($include, $check, $prepare)) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "Core changed: SpellAuras.cpp no longer has: $anchor" }
}
$loader = @'
#include "DatabaseEnv.h"
#include <mutex>

namespace
{
// Wildcard: enchant procs with a cooldown per target, read once from wcme_proc_target_cooldown at the first proc.
struct WcmeTargetCooldown
{
    Milliseconds Target{0};
    Milliseconds Shared{0};
};

std::unordered_map<uint32, WcmeTargetCooldown> WcmeTargetCooldowns;
std::once_flag WcmeTargetCooldownsLoaded;

WcmeTargetCooldown const* WcmeFindTargetCooldown(uint32 spellId)
{
    std::call_once(WcmeTargetCooldownsLoaded, []
    {
        if (!WorldDatabase.Query("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() "
            "AND TABLE_NAME = 'wcme_proc_target_cooldown'"))
            return;
        if (QueryResult result = WorldDatabase.Query("SELECT spell_id, target_cooldown_ms, shared_cooldown_ms FROM wcme_proc_target_cooldown"))
            do
            {
                Field* fields = result->Fetch();
                WcmeTargetCooldowns[fields[0].Get<uint32>()] = { Milliseconds(fields[1].Get<uint32>()), Milliseconds(fields[2].Get<uint32>()) };
            } while (result->NextRow());
        LOG_INFO("server.loading", "Loaded {} per-target enchant proc cooldowns (wcme_proc_target_cooldown)", WcmeTargetCooldowns.size());
    });
    auto const itr = WcmeTargetCooldowns.find(spellId);
    return itr == WcmeTargetCooldowns.end() ? nullptr : &itr->second;
}
}

'@
$checkAdd = @'
    // Wildcard: a per-target cooldown (wcme_proc_target_cooldown)
    if (WcmeFindTargetCooldown(GetId()))
        if (Unit* target = eventInfo.GetActionTarget())
            if (auto const ready = WcmeTargetReady.find(target->GetGUID()); ready != WcmeTargetReady.end() && ready->second > now)
                return 0;

'@
$prepareNew = @'
    // cooldowns should be added to the whole aura (see 51698 area aura)
    // Wildcard: spells in wcme_proc_target_cooldown use their own short shared cooldown plus one per target
    if (WcmeTargetCooldown const* wcme = WcmeFindTargetCooldown(GetId()))
    {
        AddProcCooldown(now + wcme->Shared);
        if (Unit* target = eventInfo.GetActionTarget())
        {
            if (WcmeTargetReady.size() > 64)
                std::erase_if(WcmeTargetReady, [now](auto const& entry) { return entry.second <= now; });
            WcmeTargetReady[target->GetGUID()] = now + wcme->Target;
        }
    }
    else
        AddProcCooldown(now + procEntry->Cooldown);

'@
$text = $text.Replace($include, $include + $loader.Replace("`r`n", "`n"))
$text = $text.Replace($check, $check + $checkAdd.Replace("`r`n", "`n"))
$text = $text.Replace($prepare, $prepareNew.Replace("`r`n", "`n").TrimEnd("`n") + "`n")
Set-Content $file $text -NoNewline
}
