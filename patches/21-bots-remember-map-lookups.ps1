# Bots remember map lookups across restarts (lag work, 28 Nov 2026; DRAFT for James and review). SQUID 3.0 looks up
# the zone, area, water and ground of every spot it considers for a teleport, and the zone and area of every spot
# its levelling filter and area guard check while bots pick quest and travel places. The first lookup of a spot can
# load map data from disk (SQUID's own comment: up to 128 ms a call), all on the threads that run the world. SQUID
# keeps the answers, but only in memory, so every restart (nightly now) starts cold and the evening pays again.
# Now the answers are also kept in two tables of the playerbots database (wcme_teleport_spot, wcme_area_spot),
# created here if missing, read once at start-up and added to as new spots come up. A spot's zone, area, water and
# ground never change, so a remembered answer stays right. If the tables cannot be created or read, the bots work as
# before (memory only) and the start-up log says so.
# Builds on nothing else; runs after 20-bots.ps1. Run by the build (step "Apply our patch scripts") after the modules
# are checked out. Throws if an anchor is gone. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

function Edit-Core($file, $anchor, $replacement, $what) {
    $text = (Get-Content $file -Raw) -replace "`r`n", "`n"
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -ne 1) { throw "SQUID changed: $what was not found exactly once in $file" }
    Set-Content $file $text.Replace($anchor, $replacement.Replace("`r`n", "`n")) -NoNewline
}

Write-Host "Patch: bots remember map lookups across restarts"
$mgr = 'core/modules/mod-playerbots/src/Bot/RandomPlayerbotMgr.cpp'
$leveling = 'core/modules/mod-playerbots/src/Ai/Coa/World/CoaWorldLeveling.cpp'

# ---- RandomPlayerbotMgr.cpp: the teleport spots ----
Edit-Core $mgr @'
std::mutex teleportSpotsLock;
std::unordered_map<std::string, TeleportSpot> teleportSpots;  // map, x, y, z, phase, collision height -> spot
'@ @'
std::mutex teleportSpotsLock;
std::unordered_map<std::string, TeleportSpot> teleportSpots;  // map, x, y, z, phase, collision height -> spot

// Wildcard (patch 21): the spots of earlier runs, read once at start-up (before any bot moves) and only read after,
// so no lock. Keyed by map, x, y, z: the phase of a random bot is the normal one, and the collision height only
// changes the water test by a little.
std::atomic<bool> wcmeSpotsSaved{false};
std::unordered_map<std::string, TeleportSpot> wcmeSavedSpots;

std::string WcmeSpotKey(Map* map, float x, float y, float z)
{
    return std::to_string(map->GetId()) + ":" + std::to_string(x) + ":" + std::to_string(y) + ":" + std::to_string(z);
}
'@ 'the teleport spot cache'

Edit-Core $mgr @'
        auto it = teleportSpots.find(key);
        if (it != teleportSpots.end())
            return it->second;
    }
    TeleportSpot spot;
    spot.zoneId = map->GetZoneId(phase, x, y, z);
    spot.areaId = map->GetAreaId(phase, x, y, z);
    spot.inWater = map->IsInWater(phase, x, y, z, height);
    spot.ground = map->GetHeight(phase, x, y, z + 0.5f);
    std::lock_guard<std::mutex> guard(teleportSpotsLock);
'@ @'
        auto it = teleportSpots.find(key);
        if (it != teleportSpots.end())
            return it->second;
    }
    // Wildcard (patch 21): known from an earlier run, so no map data is loaded for it.
    bool const saved = wcmeSpotsSaved.load(std::memory_order_acquire);
    std::string const savedKey = WcmeSpotKey(map, x, y, z);
    if (saved)
    {
        auto it = wcmeSavedSpots.find(savedKey);
        if (it != wcmeSavedSpots.end())
        {
            std::lock_guard<std::mutex> guard(teleportSpotsLock);
            teleportSpots.emplace(key, it->second);
            return it->second;
        }
    }
    TeleportSpot spot;
    spot.zoneId = map->GetZoneId(phase, x, y, z);
    spot.areaId = map->GetAreaId(phase, x, y, z);
    spot.inWater = map->IsInWater(phase, x, y, z, height);
    spot.ground = map->GetHeight(phase, x, y, z + 0.5f);
    if (saved)
        PlayerbotsDatabase.Execute("INSERT IGNORE INTO wcme_teleport_spot (spot, zone, area, water, ground) VALUES "
                                   "('{}', {}, {}, {}, {})", savedKey, spot.zoneId, spot.areaId, spot.inWater ? 1 : 0,
                                   spot.ground);
    std::lock_guard<std::mutex> guard(teleportSpotsLock);
'@ 'the teleport spot lookup'

Edit-Core $mgr @'
void RandomPlayerbotMgr::RandomTeleport(Player* bot, std::vector<WorldLocation>& locs, bool hearth)
{
'@ @'
// Wildcard (patch 21): read the teleport spots of earlier runs. Called once at start-up (CoaWorldLeveling's
// OnStartup), on the world thread, before any bot moves.
void WcmeLoadTeleportSpots()
{
    PlayerbotsDatabase.DirectExecute("CREATE TABLE IF NOT EXISTS wcme_teleport_spot (spot VARCHAR(96) NOT NULL, "
                                     "zone INT UNSIGNED NOT NULL, area INT UNSIGNED NOT NULL, water TINYINT UNSIGNED "
                                     "NOT NULL, ground FLOAT NOT NULL, PRIMARY KEY (spot)) ENGINE=InnoDB");
    if (!PlayerbotsDatabase.Query("SELECT COUNT(*) FROM wcme_teleport_spot"))
    {
        LOG_ERROR("server.loading", "Wildcard: table wcme_teleport_spot is missing; teleport spots are kept in memory only");
        return;
    }
    if (QueryResult result = PlayerbotsDatabase.Query("SELECT spot, zone, area, water, ground FROM wcme_teleport_spot"))
    {
        do
        {
            Field* fields = result->Fetch();
            TeleportSpot spot;
            spot.zoneId = fields[1].Get<uint32>();
            spot.areaId = fields[2].Get<uint32>();
            spot.inWater = fields[3].Get<uint8>() != 0;
            spot.ground = fields[4].Get<float>();
            wcmeSavedSpots[fields[0].Get<std::string>()] = spot;
        } while (result->NextRow());
    }
    wcmeSpotsSaved.store(true, std::memory_order_release);
    LOG_INFO("server.loading", ">> Wildcard: {} teleport spots remembered from earlier runs", wcmeSavedSpots.size());
}

void RandomPlayerbotMgr::RandomTeleport(Player* bot, std::vector<WorldLocation>& locs, bool hearth)
{
'@ 'RandomTeleport(locs)'

# ---- CoaWorldLeveling.cpp: the zones and areas of the levelling filter and the area guard ----
Edit-Core $leveling @'
#include <atomic>
#include <shared_mutex>
#include <unordered_map>
'@ @'
#include <atomic>
#include <shared_mutex>
#include <unordered_map>

#include "DatabaseEnv.h"  // Wildcard (patch 21)

void WcmeLoadTeleportSpots();  // Wildcard (patch 21), RandomPlayerbotMgr.cpp
'@ 'the includes'

Edit-Core $leveling @'
    std::shared_mutex g_zoneLock;
    std::unordered_map<uint64, uint32> g_zoneOf;
'@ @'
    std::shared_mutex g_zoneLock;
    std::unordered_map<uint64, uint32> g_zoneOf;
    std::atomic<bool> g_wcmeSaved{false};  // Wildcard (patch 21): new answers also go to wcme_area_spot
'@ 'the zone cache'

Edit-Core $leveling @'
        uint32 const zone = sMapMgr->GetZoneId(PHASEMASK_NORMAL, loc);
        std::unique_lock<std::shared_mutex> lock(g_zoneLock);
        g_zoneOf[key] = zone;
        return zone;
'@ @'
        uint32 const zone = sMapMgr->GetZoneId(PHASEMASK_NORMAL, loc);
        if (g_wcmeSaved.load(std::memory_order_acquire))
            PlayerbotsDatabase.Execute("INSERT INTO wcme_area_spot (spot, zone) VALUES ({}, {}) ON DUPLICATE KEY "
                                       "UPDATE zone = VALUES(zone)", key, zone);
        std::unique_lock<std::shared_mutex> lock(g_zoneLock);
        g_zoneOf[key] = zone;
        return zone;
'@ 'ZoneOf'

Edit-Core $leveling @'
        uint32 const area = sMapMgr->GetAreaId(PHASEMASK_NORMAL, mapId, x, y, z);
        std::unique_lock<std::shared_mutex> lock(g_zoneLock);
        g_areaOf[key] = area;
        return area;
    }
'@ @'
        uint32 const area = sMapMgr->GetAreaId(PHASEMASK_NORMAL, mapId, x, y, z);
        if (g_wcmeSaved.load(std::memory_order_acquire))
            PlayerbotsDatabase.Execute("INSERT INTO wcme_area_spot (spot, area) VALUES ({}, {}) ON DUPLICATE KEY "
                                       "UPDATE area = VALUES(area)", key, area);
        std::unique_lock<std::shared_mutex> lock(g_zoneLock);
        g_areaOf[key] = area;
        return area;
    }

    // Wildcard (patch 21): the zones and areas of earlier runs, straight into the caches above. Once at start-up,
    // on the world thread, before any bot moves.
    void WcmeLoadAreaSpots()
    {
        PlayerbotsDatabase.DirectExecute("CREATE TABLE IF NOT EXISTS wcme_area_spot (spot BIGINT UNSIGNED NOT NULL, "
                                         "zone INT UNSIGNED NULL, area INT UNSIGNED NULL, PRIMARY KEY (spot)) "
                                         "ENGINE=InnoDB");
        if (!PlayerbotsDatabase.Query("SELECT COUNT(*) FROM wcme_area_spot"))
        {
            LOG_ERROR("server.loading", "Wildcard: table wcme_area_spot is missing; zones and areas are kept in memory only");
            return;
        }
        uint32 zones = 0;
        uint32 areas = 0;
        if (QueryResult result = PlayerbotsDatabase.Query("SELECT spot, zone, area FROM wcme_area_spot"))
        {
            std::unique_lock<std::shared_mutex> lock(g_zoneLock);
            do
            {
                Field* fields = result->Fetch();
                uint64 const key = fields[0].Get<uint64>();
                if (!fields[1].IsNull())
                {
                    g_zoneOf[key] = fields[1].Get<uint32>();
                    ++zones;
                }
                if (!fields[2].IsNull())
                {
                    g_areaOf[key] = fields[2].Get<uint32>();
                    ++areas;
                }
            } while (result->NextRow());
        }
        g_wcmeSaved.store(true, std::memory_order_release);
        LOG_INFO("server.loading", ">> Wildcard: {} zones and {} areas of spots remembered from earlier runs", zones, areas);
    }
'@ 'AreaOf'

Edit-Core $leveling @'
    void OnStartup() override { LoadSettings(); }
'@ @'
    void OnStartup() override
    {
        LoadSettings();
        WcmeLoadAreaSpots();      // Wildcard (patch 21)
        WcmeLoadTeleportSpots();  // Wildcard (patch 21)
    }
'@ 'OnStartup'
