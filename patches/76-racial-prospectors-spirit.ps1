# Dwarf signature racial: Prospector's Spirit (docs/race-kits.md). Natural explorers: each kind of find gives its own
# buff, stacking up to 3 times and lasting 8 hours (gathering more adds a stack and refreshes it; kept through death):
#   Mining a vein (9990049): +2% Stamina per stack.
#   Herbalism (9990050): +2% Intellect and Spirit per stack.
#   Skinning (9990051): +2% Strength and Agility per stack.
#   Treasure (9990052): +2% damage and healing per stack. Opening a chest that Find Treasure shows (a lock of the
#     Treasure type: Battered Chest, Large Iron Bound Chest, strongboxes...), or discovering a new area.
#   Fishing a catch (9990053): +3% running speed (on foot) and swim speed per stack; at 3 stacks, water breathing too
#     (hidden 9990054).
# Discovering a new area also gives 50% more exploration experience. A gathering counts once per node or creature, as
# its skill-up does; a chest or catch once per opening. The spells are in sql/enchants/150-custom-spells.sql and the
# client patch (client-patch/custom_spells.py). Run by the build from the workspace root, after 40-battlegrounds.ps1.
# Throws if an anchor is gone. Listed in CHANGES.md. Racials.ProspectorsSpirit = 0 turns it off.
$ErrorActionPreference = 'Stop'

# ---- Per-player state, on the player (map updates run on several threads, so no shared table)
Write-Host "Patch: Prospector's Spirit state on Player"
& {
$file = 'core/src/server/game/Entities/Player/Player.h'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$anchor = "public:`n    explicit Player(WorldSession* session);`n"
if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'Core changed: the Player constructor in Player.h was not found' }
$add = "    ObjectGuid WcmeProspectLastLoot;`n"
Set-Content $file $text.Replace($anchor, $anchor + $add) -NoNewline
}

Write-Host "Patch: Prospector's Spirit for Dwarves (Racials.ProspectorsSpirit)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
$class = @'
// Wildcard: Dwarf Prospector's Spirit (docs/race-kits.md).
class wcme_prospectors_spirit : public PlayerScript
{
public:
    wcme_prospectors_spirit() : PlayerScript("wcme_prospectors_spirit", {PLAYERHOOK_ON_UPDATE,
        PLAYERHOOK_ON_UPDATE_GATHERING_SKILL, PLAYERHOOK_ON_BEFORE_SEND_LOOT, PLAYERHOOK_CAN_AREA_EXPLORE_AND_OUTDOOR,
        PLAYERHOOK_ON_GIVE_EXP}) { }

    static constexpr uint32 Mining = 9990049;
    static constexpr uint32 Herbalism = 9990050;
    static constexpr uint32 Skinning = 9990051;
    static constexpr uint32 Treasure = 9990052;
    static constexpr uint32 Fishing = 9990053;
    static constexpr uint32 WaterBreathing = 9990054;  // with Fishing at 3 stacks
    static constexpr uint8 MaxStacks = 3;
    static constexpr int32 Lasts = 8 * HOUR * IN_MILLISECONDS;

    static bool Applies(Player* player)
    {
        return player->getRace() == RACE_DWARF && sConfigMgr->GetOption<bool>("Racials.ProspectorsSpirit", true);
    }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (player->getRace() != RACE_DWARF)
            return;
        if (!Applies(player))
        {
            for (uint32 spell : {Mining, Herbalism, Skinning, Treasure, Fishing, WaterBreathing})
                if (player->HasAura(spell))
                    player->RemoveAurasDueToSpell(spell);
            return;
        }
        // Water breathing goes with 3 stacks of the fishing buff (and ends with it).
        Aura const* fishing = player->GetAura(Fishing);
        bool const breathe = fishing && fishing->GetStackAmount() >= MaxStacks;
        if (!breathe && player->HasAura(WaterBreathing))
            player->RemoveAurasDueToSpell(WaterBreathing);
        else if (breathe && player->IsAlive() && !player->HasAura(WaterBreathing))
            Lasting(player, WaterBreathing, fishing->GetDuration());
    }

    void OnPlayerUpdateGatheringSkill(Player* player, uint32 skill, uint32 /*current*/, uint32 /*gray*/,
                                      uint32 /*green*/, uint32 /*yellow*/, uint32& /*gain*/) override
    {
        if (!Applies(player))
            return;
        switch (skill)
        {
            case SKILL_MINING: Gain(player, Mining); break;
            case SKILL_HERBALISM: Gain(player, Herbalism); break;
            case SKILL_SKINNING: Gain(player, Skinning); break;
            default: break;
        }
    }

    void OnPlayerBeforeSendLoot(Player* player, ObjectGuid lootGuid, Loot* loot) override
    {
        if (!loot || !Applies(player) || lootGuid == player->WcmeProspectLastLoot)
            return; // the same chest or catch opened again counts once
        if (loot->loot_type == LOOT_FISHING)
        {
            player->WcmeProspectLastLoot = lootGuid;
            Gain(player, Fishing);
            return;
        }
        if (!lootGuid.IsGameObject())
            return;
        GameObject* chest = ObjectAccessor::GetGameObject(*player, lootGuid);
        if (!chest || chest->GetGoType() != GAMEOBJECT_TYPE_CHEST || !IsTreasureLock(chest->GetGOInfo()->GetLockId()))
            return;
        player->WcmeProspectLastLoot = lootGuid;
        Gain(player, Treasure);
    }

    // Called just before the core marks the current area explored: if it isn't yet, this is a discovery.
    bool OnPlayerCanAreaExploreAndOutdoor(Player* player) override
    {
        if (!Applies(player))
            return true;
        AreaTableEntry const* area = sAreaTableStore.LookupEntry(player->GetAreaId());
        if (!area)
            return true;
        uint32 const offset = area->exploreFlag / 32;
        if (offset >= PLAYER_EXPLORED_ZONES_SIZE)
            return true;
        uint32 const bit = uint32(1) << (area->exploreFlag % 32);
        if (!(player->GetUInt32Value(PLAYER_EXPLORED_ZONES_1 + offset) & bit))
            Gain(player, Treasure);
        return true;
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 xpSource) override
    {
        if (xpSource == XPSOURCE_EXPLORE && Applies(player))
            amount += amount / 2;  // 50% more exploration experience
    }

private:
    // A lock Find Treasure tracks: one of its cases is the Treasure lock type.
    static bool IsTreasureLock(uint32 lockId)
    {
        LockEntry const* lock = sLockStore.LookupEntry(lockId);
        if (!lock)
            return false;
        for (uint8 i = 0; i < MAX_LOCK_CASE; ++i)
            if (lock->Type[i] == LOCK_KEY_SKILL && lock->Index[i] == LOCKTYPE_TREASURE)
                return true;
        return false;
    }

    static void Lasting(Player* player, uint32 spell, int32 duration)
    {
        if (Aura* aura = player->AddAura(spell, player))
        {
            aura->SetMaxDuration(Lasts);
            aura->SetDuration(duration);
        }
    }

    // One more stack (up to 3), and a fresh 8 hours.
    static void Gain(Player* player, uint32 spell)
    {
        if (!player->IsAlive())
            return;
        Aura* aura = player->GetAura(spell);
        if (!aura)
            aura = player->AddAura(spell, player);
        else if (aura->GetStackAmount() < MaxStacks)
            aura->SetStackAmount(aura->GetStackAmount() + 1);
        if (!aura)
            return;
        aura->SetMaxDuration(Lasts);
        aura->SetDuration(Lasts);
        if (spell == Fishing && aura->GetStackAmount() >= MaxStacks)
            Lasting(player, WaterBreathing, Lasts);
    }
};

'@
$text = $text.Replace($include, $include + "#include `"GameObject.h`"`n#include `"LootMgr.h`"`n#include `"ObjectAccessor.h`"`n#include `"SpellAuras.h`"`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_prospectors_spirit();`n")
Set-Content $file $text -NoNewline
}
