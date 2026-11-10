# Manastorm: dead bots at the end of a floor.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Manastorm raises every dead member of the run when a floor is cleared, bots included
Write-Host "Patch: Manastorm raises every dead member of the run when a floor is cleared, bots included"
& {
$file = 'core/src/server/coa/AscensionManastorm.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$old = @'
            run.encounter->phase = Phase::Completed;
            if (!player->IsAlive())
            {
                player->ResurrectPlayer(1.0f);
                player->SpawnCorpseBones();
            }
'@
$old = $old.Replace("`r`n", "`n")
if (-not $text.Contains($old)) { throw 'CoA changed: the resurrection in Manastorm Finish() was not found' }
# Finish() only raised the members with their own run (real players); bots in the group stayed dead at the
# end of the floor. Raise everyone dead in the run's private scene.
$new = $old + "`n" + @'
            for (auto const& reference : player->GetMap()->GetPlayers())
                if (Player* member = reference.GetSource(); member && member != player && !member->IsAlive()
                    && player->GetMap()->IsScriptedPrivateMember(member->GetGUID()))
                {
                    member->ResurrectPlayer(1.0f);
                    member->SpawnCorpseBones();
                }
'@
Set-Content $file $text.Replace($old, $new.Replace("`r`n", "`n")) -NoNewline
}
# ---- Every resurrection in a Manastorm run uses one of the run's shared charges (the item already does)
Write-Host "Patch: Every resurrection in a Manastorm run uses one of the run's shared charges"
& {
$file = 'core/src/server/coa/AscensionManastorm.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$methodsAt = "        void UsedResurrection(Player* player)`n"
$check = @'
            if (Player* player = spell->GetCaster()->ToPlayer())
            {
                SpellCastResult const utility = ManastormService::Get().CheckUtility(player, spell->GetSpellInfo()->Id);
                if (utility != SPELL_CAST_OK)
                    result = utility;
            }
'@
$hit = @'
            if (!miss && spell->GetSpellInfo()->Id == 93309)
                if (Player* player = spell->GetCaster()->ToPlayer())
                    ManastormService::Get().UsedResurrection(player);
'@
$check = $check.Replace("`r`n", "`n") + "`n"; $hit = $hit.Replace("`r`n", "`n") + "`n"
foreach ($anchor in $methodsAt, $check, $hit) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: a Manastorm resurrection anchor was not found' }
}
# The run's 5 resurrection charges are shared by the group (one Encounter), but only the run's own item (93309) used
# them: a resurrection spell from a player or a bot was free, so a group of bots made runs easy. Now any resurrection
# cast inside a run's scene needs a charge and uses one; the Manastorm window already shows how many are left.
$methods = @'
        std::shared_ptr<Encounter> SceneEncounter(Player const* player)
        {
            Map* map = player->FindMap();
            if (!map || !map->IsScriptedPrivateInstance()
                || !map->ToInstanceMap()->IsScriptedPrivateMember(player->GetGUID()))
                return nullptr;
            ObjectGuid const owner = map->ToInstanceMap()->GetScriptedPrivateOwner();
            for (auto const& [guid, run] : runs)
                if (run.encounter && run.encounter->instanceId == player->GetInstanceId() && run.encounter->owner == owner
                    && run.GetScene().map == player->GetMapId())
                    return run.encounter;
            return nullptr;
        }

        SpellCastResult CheckSharedResurrection(Player* player)
        {
            if (!enabled.load())
                return SPELL_CAST_OK;
            std::lock_guard<std::recursive_mutex> lock(mutex);
            std::shared_ptr<Encounter> const encounter = SceneEncounter(player);
            return encounter && !encounter->resurrectionCharges ? SPELL_FAILED_NO_CHARGES_REMAIN : SPELL_CAST_OK;
        }

        void UsedSharedResurrection(Player* player)
        {
            std::lock_guard<std::recursive_mutex> lock(mutex);
            if (std::shared_ptr<Encounter> const encounter = SceneEncounter(player); encounter && encounter->resurrectionCharges)
                --encounter->resurrectionCharges;
        }

'@
$checkNew = $check + @'
            if (result == SPELL_CAST_OK && spell->GetSpellInfo()->Id != 93309
                && (spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT)
                    || spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT_NEW)))
                if (Player* player = spell->GetCaster()->ToPlayer())
                    result = ManastormService::Get().CheckSharedResurrection(player);

'@
$hitNew = $hit + @'
            if (!miss && target != spell->GetCaster() && spell->GetSpellInfo()->Id != 93309
                && (spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT)
                    || spell->GetSpellInfo()->HasEffect(SPELL_EFFECT_RESURRECT_NEW)))
                if (Player* player = spell->GetCaster()->ToPlayer())
                    ManastormService::Get().UsedSharedResurrection(player);

'@
$text = $text.Replace($methodsAt, $methods.Replace("`r`n", "`n") + "`n" + $methodsAt)
$text = $text.Replace($check, $checkNew.Replace("`r`n", "`n")).Replace($hit, $hitNew.Replace("`r`n", "`n"))
Set-Content $file $text -NoNewline
}

# ---- Manastorm caches open straight into the bags, one at a time (Manastorm.CachesOpenIntoBags, off when unset)
Write-Host "Patch: Manastorm caches open straight into the bags, one at a time (Manastorm.CachesOpenIntoBags)"
& {
$file = 'core/src/server/coa/AscensionManastorm.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = '#include "AscensionManastorm.h"'
$classAt = "    class item_ascension_manastorm_cache final : public ItemScript`n"
$onUse = @'
        bool OnUse(Player* player, Item* item, SpellCastTargets const&) override
        {
            if (player->IsAlive() && !player->IsInCombat())
                player->SendLoot(item->GetGUID(), LOOT_CORPSE);
            return true;
        }
'@
$register = "    new item_ascension_manastorm_cache();`n"
$onUse = $onUse.Replace("`r`n", "`n")
foreach ($anchor in $include, $classAt, $onUse, $register) {
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw 'CoA changed: a Manastorm cache anchor was not found' }
}
# Right-clicking a cache sends CMSG_OPEN_ITEM (the caches have the "has loot" flag), which opens a loot window. The
# core only removes a container once its loot is empty, and the loot belongs to the whole stack, so a cache whose
# scrolls didn't all fit (one per specialisation) was never removed and blocked the rest of its stack. Now opening a
# cache gives its contents straight to the bags (the mailbox takes what doesn't fit: AscensionCacheRewards::Deliver,
# as other CoA caches do) and removes that one cache. Manastorm's own loot rules still pick the contents. A cache
# left half-looted by the old way hands over what it still had. With Wildcard.ScrollsStraightToCurrency on, the
# scrolls then count straight away.
$helpers = @'
    bool IsManastormCache(uint32 entry)
    {
        return (entry >= 97877 && entry <= 97884) || (entry >= 1278050 && entry <= 1278084)
            || (entry >= 1288050 && entry <= 1288074) || (entry >= 1289056 && entry <= 1289074)
            || entry == 1478051 || entry == 1478052;
    }

    void OpenManastormCacheIntoBags(Player* player, Item* item)
    {
        Loot fresh;
        Loot* loot = &item->loot;
        if (!item->m_lootGenerated || item->loot.isLooted())
        {
            fresh.containerGUID = item->GetGUID();
            fresh.FillLoot(item->GetEntry(), LootTemplates_Item, player, true, true);
            loot = &fresh;
        }
        if (loot->gold)
            player->ModifyMoney(loot->gold);
        std::vector<AscensionCacheRewards::Reward> rewards;
        uint32 const slots = loot->GetMaxSlotInLootFor(player);
        for (uint32 slot = 0; slot < slots; ++slot)
            if (LootItem const* reward = loot->LootItemInSlot(slot, player))
                if (ItemTemplate const* proto = sObjectMgr->GetItemTemplate(reward->itemid))
                    rewards.push_back({ reward->itemid, uint16(proto->ItemLevel), uint8(5), uint8(proto->SubClass),
                        uint32(reward->count ? reward->count : 1), reward->randomPropertyId });
        // The stack keeps no loot of its own afterwards: the next cache in it starts fresh.
        sLootItemStorage->RemoveStoredLoot(item->GetGUID());
        item->m_lootGenerated = false;
        item->loot.clear();
        if (rewards.empty())
        {
            uint32 one = 1;
            player->DestroyItemCount(item, one, true);
        }
        else
            AscensionCacheRewards::Deliver(player, rewards, item);
    }

    class ManastormCacheOpen final : public ServerScript
    {
    public:
        ManastormCacheOpen() : ServerScript("AscensionManastormCacheOpen", {SERVERHOOK_CAN_PACKET_RECEIVE}) { }

        bool CanPacketReceive(WorldSession* session, WorldPacket const& packet) override
        {
            if (packet.GetOpcode() != CMSG_OPEN_ITEM || packet.size() < 2
                || !sConfigMgr->GetOption<bool>("Manastorm.CachesOpenIntoBags", false))
                return true;
            Player* player = session ? session->GetPlayer() : nullptr;
            if (!player || player->m_mover != player || !player->IsAlive() || player->IsInCombat())
                return true;
            Item* item = player->GetItemByPos(packet.read<uint8>(0), packet.read<uint8>(1));
            if (!item || !IsManastormCache(item->GetEntry()))
                return true;
            ObjectGuid const cache = item->GetGUID();
            OpenManastormCacheIntoBags(player, item);
            player->SendLootRelease(cache);
            return false;
        }
    };

'@
$onUseNew = @'
        bool OnUse(Player* player, Item* item, SpellCastTargets const&) override
        {
            if (!player->IsAlive() || player->IsInCombat())
                return true;
            if (sConfigMgr->GetOption<bool>("Manastorm.CachesOpenIntoBags", false))
                OpenManastormCacheIntoBags(player, item);
            else
                player->SendLoot(item->GetGUID(), LOOT_CORPSE);
            return true;
        }
'@
$text = $text.Replace($include, $include + "`n#include `"AscensionCacheRewards.h`"`n#include `"LootItemStorage.h`"")
$text = $text.Replace($classAt, $helpers.Replace("`r`n", "`n") + $classAt)
$text = $text.Replace($onUse, $onUseNew.Replace("`r`n", "`n"))
$text = $text.Replace($register, $register + "    new ManastormCacheOpen();`n")
Set-Content $file $text -NoNewline
}
