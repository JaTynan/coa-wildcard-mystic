# Leaderboards and server firsts for the website: the server counts world PvP kills and records server firsts.
# Run by the build (step "Apply our patch scripts") from the workspace root, after 40-battlegrounds.ps1, whose
# world PvP part this builds on (same file and script loader). Throws if an anchor is gone. Listed in CHANGES.md.
# The website side is signup/WildcardStatus.py (leaderboards, firsts).
$ErrorActionPreference = 'Stop'

Write-Host "Patch: World PvP kill counts and server firsts for the website (Leaderboards.Enabled)"
& {
$file = 'core/src/server/coa/AscensionAdventurerCache.cpp'
$text = (Get-Content $file -Raw) -replace "`r`n", "`n"
$include = "#include `"PlayerScript.h`"`n"
$register = "    new world_pvp_kill_xp();`n"
$loader = "void AddSC_AscensionAdventurerCache()`n{`n"
foreach ($anchor in @($include, $register, $loader)) {
    if (-not $text.Contains($anchor)) { throw "Core changed (or 40-battlegrounds.ps1 did not run): AscensionAdventurerCache.cpp has no: $($anchor.Split("`n")[0])" }
}
# Two tables in the characters database, made at startup if missing:
#   wcme_world_pvp_kills: per character, kills of other players in the open world (not battlegrounds, arenas or
#     instances; not grey victims; the same victim counts once per Leaderboards.SameVictimSeconds, 300).
#   wcme_server_firsts: one row per first: the first group to defeat each dungeon or raid boss ("boss", entry), and
#     the first character to reach each Prestige level ("prestige", level). Each is announced to the server.
# Bots never count. Level firsts are read by the website from the level achievements, so they need nothing here.
$class = @'
namespace WcmeLeaderboards
{
    std::mutex Lock;
    std::set<std::pair<std::string, uint32>> Firsts;
    std::map<std::pair<ObjectGuid, ObjectGuid>, time_t> LastKill;

    bool Enabled() { return sConfigMgr->GetOption<bool>("Leaderboards.Enabled", false); }

    bool Real(Player* player) { return player && player->GetSession() && !player->GetSession()->IsBot(); }

    // Records a first unless one is already held for (kind, detail); announces it when it is new.
    void RecordFirst(std::string const& kind, uint32 detail, Player* player, std::string const& text)
    {
        {
            std::lock_guard<std::mutex> guard(Lock);
            if (!Firsts.insert({kind, detail}).second)
                return;
        }
        std::string name = player->GetName();
        std::string line = text;
        std::string kindText = kind;
        CharacterDatabase.EscapeString(name);
        CharacterDatabase.EscapeString(line);
        CharacterDatabase.EscapeString(kindText);
        CharacterDatabase.Execute("INSERT IGNORE INTO wcme_server_firsts (kind, detail, guid, name, text, at) "
            "VALUES ('{}', {}, {}, '{}', '{}', UNIX_TIMESTAMP())", kindText, detail, player->GetGUID().GetCounter(), name, line);
        ChatHandler(nullptr).SendWorldText("|cffffd000Server first!|r {}", text);
    }
}

class wcme_leaderboards_world : public WorldScript
{
public:
    wcme_leaderboards_world() : WorldScript("wcme_leaderboards_world") { }

    void OnStartup() override
    {
        if (!WcmeLeaderboards::Enabled())
            return;
        CharacterDatabase.DirectExecute("CREATE TABLE IF NOT EXISTS wcme_world_pvp_kills (guid INT UNSIGNED NOT NULL, "
            "kills INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (guid)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        CharacterDatabase.DirectExecute("CREATE TABLE IF NOT EXISTS wcme_server_firsts (kind VARCHAR(32) NOT NULL, "
            "detail INT UNSIGNED NOT NULL, guid INT UNSIGNED NOT NULL, name VARCHAR(64) NOT NULL, text VARCHAR(255) NOT NULL, "
            "at INT UNSIGNED NOT NULL, PRIMARY KEY (kind, detail)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
        if (QueryResult result = CharacterDatabase.Query("SELECT kind, detail FROM wcme_server_firsts"))
        {
            std::lock_guard<std::mutex> guard(WcmeLeaderboards::Lock);
            do
            {
                Field* fields = result->Fetch();
                WcmeLeaderboards::Firsts.insert({fields[0].Get<std::string>(), fields[1].Get<uint32>()});
            } while (result->NextRow());
        }
    }
};

class wcme_leaderboards_player : public PlayerScript
{
public:
    wcme_leaderboards_player() : PlayerScript("wcme_leaderboards_player",
        {PLAYERHOOK_ON_PVP_KILL, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_COA_PRESTIGE_SAVED}) { }

    void OnPlayerPVPKill(Player* killer, Player* killed) override
    {
        if (!WcmeLeaderboards::Enabled() || !WcmeLeaderboards::Real(killer) || !killed || killer == killed)
            return;
        Map* map = killer->FindMap();
        if (!map || map->Instanceable() || killer->InBattleground() || killer->InArena())
            return;
        if (killed->GetLevel() <= Acore::XP::GetGrayLevel(killer->GetLevel()))
            return;
        time_t const now = GameTime::GetGameTime().count();
        time_t const wait = sConfigMgr->GetOption<uint32>("Leaderboards.SameVictimSeconds", 300);
        {
            std::lock_guard<std::mutex> guard(WcmeLeaderboards::Lock);
            auto& last = WcmeLeaderboards::LastKill[{killer->GetGUID(), killed->GetGUID()}];
            if (last && now - last < wait)
                return;
            last = now;
            if (WcmeLeaderboards::LastKill.size() > 20000)
                WcmeLeaderboards::LastKill.clear();
        }
        CharacterDatabase.Execute("INSERT INTO wcme_world_pvp_kills (guid, kills) VALUES ({}, 1) "
            "ON DUPLICATE KEY UPDATE kills = kills + 1", killer->GetGUID().GetCounter());
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override
    {
        if (!WcmeLeaderboards::Enabled() || !WcmeLeaderboards::Real(killer) || !killed || !killed->IsDungeonBoss())
            return;
        Map* map = killed->FindMap();
        if (!map || !map->IsDungeon())
            return;
        std::string names = killer->GetName();
        if (Group* group = killer->GetGroup())
        {
            names.clear();
            for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
                if (Player* member = ref->GetSource())
                    if (WcmeLeaderboards::Real(member) && member->FindMap() == map)
                        names += (names.empty() ? "" : ", ") + member->GetName();
            if (names.empty())
                names = killer->GetName();
        }
        WcmeLeaderboards::RecordFirst("boss", killed->GetEntry(), killer,
            Acore::StringFormat("{} defeated {} ({}).", names, killed->GetName(), map->GetMapName()));
    }

    void OnPlayerCoAPrestigeSaved(Player* player) override
    {
        if (!WcmeLeaderboards::Enabled() || !WcmeLeaderboards::Real(player))
            return;
        PlayerSettingVector const* state = player->FindPlayerSettings("core.coa_prestige");
        uint32 const level = state && !state->empty() ? (*state)[0].value : 0;
        if (level)
            WcmeLeaderboards::RecordFirst("prestige", level, player,
                Acore::StringFormat("{} reached Prestige {}.", player->GetName(), level));
    }
};

'@
$text = $text.Replace($include, $include + "#include `"DatabaseEnv.h`"`n#include `"Map.h`"`n#include `"PlayerSettings.h`"`n#include `"WorldScript.h`"`n#include <set>`n#include <string>`n")
$text = $text.Replace($loader, $class.Replace("`r`n", "`n") + $loader)
$text = $text.Replace($register, $register + "    new wcme_leaderboards_world();`n    new wcme_leaderboards_player();`n")
Set-Content $file $text -NoNewline
}
