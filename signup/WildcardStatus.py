"""Live status and realm settings for the Wildcard homepage (https://wildcard.jtlab.cc), served by the sign-up
service as GET /api/status.

Everything is read from the server itself, so the page never goes stale: whether the login and world servers answer
on their ports, players and uptime from the world console (through the manager's ra-once), the installed patched
build, and the rates and features from the live config files. Results are cached briefly so a busy page costs the
server nothing.
"""

import json
import re
import socket
import subprocess
import threading
import time
from datetime import date, datetime, timedelta
from pathlib import Path

CACHE_SECONDS = 30
CONSOLE_SECONDS = 60
STOCK_XP = 0.9295  # CoA's stock master XP rate, which counts as "1x" for players

_lock = threading.Lock()
_cache = {"at": 0.0, "value": None}
_console = {"at": 0.0, "value": {}}


def _read_conf(path):
    values = {}
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return values
    for line in text.splitlines():
        match = re.match(r"\s*([A-Za-z0-9_.]+)\s*=\s*(.*?)\s*$", line)
        if match and not line.lstrip().startswith("#"):
            values[match.group(1)] = match.group(2).strip('"')
    return values


def _number(values, key, default=None):
    try:
        return float(values[key])
    except (KeyError, ValueError):
        return default


def _times(value):
    if value is None:
        return None
    rounded = round(value, 2)
    text = f"{rounded:.2f}".rstrip("0").rstrip(".")
    return text + "×"


def _answers(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2):
            return True
    except OSError:
        return False


def _console_info(options):
    """Players and uptime from the world console's 'server info', cached a minute."""
    now = time.time()
    if now - _console["at"] < CONSOLE_SECONDS:
        return _console["value"]
    command = [options.python, "-B", str(options.bridge), str(options.manage), "ra-once"]
    info = {}
    try:
        result = subprocess.run(command, input="server info\n", capture_output=True, text=True, timeout=20,
                                cwd=str(options.server), creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        text = result.stdout or ""
        players = re.search(r"Connected players:\s*(\d+)", text)
        characters = re.search(r"Characters in world:\s*(\d+)", text)
        uptime = re.search(r"Server uptime:\s*([^\r\n]+)", text)
        if players:
            info["players"] = int(players.group(1))
        if characters:
            info["characters"] = int(characters.group(1))
        if uptime:
            info["uptime"] = uptime.group(1).strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    _console["at"], _console["value"] = now, info
    return info


def _rune_rates(patch_night):
    try:
        text = (patch_night / "enchants" / "100-rune-rates.sql").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None, None
    quest = re.search(r"@quest_rune_percent\s*:=\s*(\d+)", text)
    drop = re.search(r"@drop_rune_percent\s*:=\s*(\d+)", text)
    return (int(quest.group(1)) if quest else None), (int(drop.group(1)) if drop else None)


def _build(core):
    try:
        tag = (core / "worldserver.patched-release.txt").read_text(encoding="utf-8").strip()
    except OSError:
        return {"tag": None, "release": None, "build": None}
    release = re.search(r"\.(\d+)-build(\d+)$", tag)
    return {"tag": tag, "release": ("." + release.group(1)) if release else None,
            "build": int(release.group(2)) if release else None}


WEEKEND_TITLES = {"PvP": "Shanks-giving", "Professions": "Craftageddon", "Quests": "The Questathlon",
                  "Dungeons": "Pull-a-palooza"}  # used when WeekendBonus.<theme>.Title is not set
WEEKEND_RATES = [  # the order players read them in
    ("XPRate", "all XP"), ("HonorRate", "honour"), ("PvPXPRate", "XP from world PvP kills"),
    ("BattlegroundSpoilsRate", "Battleground Spoils"), ("InsigniaGoldRate", "gold from Insignias"), ("ProfessionXPRate", "profession XP"),
    ("GatherYieldRate", "herbs, ore, skins and fish from each node or catch"),
    ("ProfessionSkillRate", "profession skill-ups"), ("QuestXPRate", "quest XP"), ("QuestMoneyRate", "quest gold"),
    ("QuestCacheRate", "Adventurer's caches from quests"), ("ReputationRate", "reputation"),
    ("DungeonXPRate", "XP from kills in dungeons and raids"),
    ("DungeonReputationRate", "reputation in dungeons and raids"),
    ("DungeonCacheRate", "random dungeon caches"),
]


def _weekend(world, today=None):
    """The rotating weekend bonus, worked out exactly as the server does (patches/45-weekend-bonus.ps1): weeks run
    Friday to Thursday from WeekendBonus.RotationStart, each taking the next theme in WeekendBonus.Rotation."""
    if world.get("WeekendBonus.Enabled") != "1":
        return None
    rotation = [t.strip() for t in world.get("WeekendBonus.Rotation", "PvP,Professions,Quests,Dungeons").split(",") if t.strip()]
    forced = world.get("WeekendBonus.Theme", "").strip()
    if not rotation and not forced:
        return None
    try:
        start = date.fromisoformat(world.get("WeekendBonus.RotationStart", "2026-11-13"))
    except ValueError:
        start = date(2026, 11, 13)
    days = {int(c) for c in world.get("WeekendBonus.Days", "5,6,0") if c.isdigit()}
    today = today or date.today()

    def theme(friday):
        return forced or rotation[((friday - start).days // 7) % len(rotation)]

    def describe(friday):
        name = theme(friday)
        boosts = []
        for key, label in WEEKEND_RATES:
            rate = _number(world, f"WeekendBonus.{name}.{key}")
            if rate and rate != 1:
                boosts.append(f"{_times(rate)} {label}")
        title = world.get(f"WeekendBonus.{name}.Title", "").strip() or WEEKEND_TITLES.get(name, name)
        # Server time (the VM's clock, as the core uses): a week starts at midnight on its Friday. Times go out as
        # epoch milliseconds so the site's live timeline counts down in each visitor's own time zone.
        begins = datetime(friday.year, friday.month, friday.day).astimezone()
        last = friday + timedelta(days=7 if len(days) == 7 else 3)
        ends = datetime(last.year, last.month, last.day).astimezone()
        return {"theme": name, "title": title, "boosts": boosts, "allWeek": len(days) == 7,
                "friday": friday.strftime("%a %d %b").replace(" 0", " "),
                "startsAt": int(begins.timestamp() * 1000), "endsAt": int(ends.timestamp() * 1000)}

    friday = today - timedelta(days=(today.weekday() - 4) % 7)  # the Friday that started this week
    active = (today.isoweekday() % 7) in days
    if not forced and friday < start:  # the rotation has not started yet
        friday, active = start, False
    elif not active:
        friday += timedelta(days=7)
    # The timeline shows a full turn of the rotation: this week and the ones after it.
    ahead = 1 if forced else max(len(rotation), 2)
    weeks = [describe(friday + timedelta(days=7 * n)) for n in range(ahead)]
    return {"active": active, "current": weeks[0], "next": describe(friday + timedelta(days=7)), "weeks": weeks}


def _settings(configs, patch_night):
    world = _read_conf(configs / "worldserver.conf")
    modules = configs / "modules"
    prestige = _read_conf(modules / "mod-coa-prestige.conf")
    bots = _read_conf(modules / "playerbots.conf")
    wildcard = _read_conf(modules / "wildcard.conf")
    chat = _read_conf(modules / "mod_ollama_chat.conf")

    xp_global = _number(world, "Rate.XP.Global")
    xp = xp_global / STOCK_XP if xp_global else None
    explore = _number(world, "Rate.XP.Explore")
    prestige_bonus = _number(prestige, "CoAPrestige.ExperienceBonusPercent")
    quest_runes, drop_runes = _rune_rates(patch_night)
    creature_respawn = _number(world, "Respawn.DynamicMinimumCreature")
    node_respawn = _number(world, "Respawn.DynamicMinimumGameObject")
    rest_cap = _number(world, "Rate.Rest.MaxBonus")
    max_bots = _number(bots, "AiPlayerbot.MaxRandomBots")
    professions = _number(world, "MaxPrimaryTradeSkill")

    def item(label, value, note=""):
        return {"label": label, "value": value, "note": note}

    groups = [
        {"title": "Experience", "items": [
            item("Experience", _times(xp), "from kills, quests and everything else"),
            item("Exploring", _times(explore * xp_global / STOCK_XP) if explore and xp_global else None,
                 "for discovering new places"),
            item("Prestige bonus", f"+{prestige_bonus - 100:g}%" if prestige_bonus else None,
                 f"on top, while a prestige cycle is active ({_times(xp * prestige_bonus / 100)} total)"
                 if prestige_bonus and xp else ""),
            item("Rested", f"up to {rest_cap:g} levels" if rest_cap else None, "builds up fast in inns and cities"),
            item("Reputation", _times(_number(world, "Rate.Reputation.Gain")), "every faction"),
            item("Honor", _times(_number(world, "Rate.Honor"))),
        ]},
        {"title": "Loot", "items": [
            item("Gold", _times(_number(world, "Rate.Drop.Money"))),
            item("Rare items", _times(_number(world, "Rate.Drop.Item.Rare"))),
            item("Epic and legendary items", _times(_number(world, "Rate.Drop.Item.Epic"))),
            item("Runes of Descension", f"{quest_runes}% from quests, {drop_runes}% from drops"
                 if quest_runes and drop_runes else None, "questing pays best, to suit prestiging"),
            item("Mystic scrolls", "1 in 25 kills", "from level 11+ mobs; every dungeon boss drops at least one"),
        ]},
        {"title": "World", "items": [
            item("Realm", "Wildcard", "random abilities from the classic classes ("
                 + (wildcard.get("Wildcard.AbilityPool") or "classic") + " pool), with Mystic Enchants"),
            item("Free rerolls", "Yes" if wildcard.get("Wildcard.FreeScrolls") == "1" else None,
                 "unlimited Scrolls of Fortune from Pete Arr, beside Silas Darkmoon (Stormwind, Orgrimmar)"),
            item("Professions", f"{professions:g}" if professions else None, "primary professions per character"),
            item("Mob respawn", f"about {creature_respawn / 60:g} minute" + ("s" if creature_respawn != 60 else "")
                 if creature_respawn else None, "out in the world; dungeons and rares keep their own timers"),
            item("Herbs, ore and chests", f"about {node_respawn / 60:g} minutes" if node_respawn else None),
            item("Bots", f"{max_bots:,.0f}" if max_bots else None,
                 "players run by the server, levelling near you" + (", chatting with AI" if chat.get("OllamaChat.Enable") == "1" else "")),
            item("Auction house", "Stocked", "by the Auctioneer, as well as other players"),
        ]},
    ]
    for group in groups:
        group["items"] = [entry for entry in group["items"] if entry["value"]]
    return groups


LEADERBOARD_SECONDS = 300
LEVEL_ACHIEVEMENTS = {6: 10, 7: 20, 8: 30, 9: 40, 10: 50, 11: 60, 12: 70, 13: 80}
_boards = {"at": 0.0, "value": None}


def _database(world, key, default):
    parts = world.get(key, "").split(";")
    name = parts[4] if len(parts) >= 5 else default
    return name if re.fullmatch(r"[A-Za-z0-9_]+", name) else default


def _sql(server, query):
    """Rows (lists of strings) from the server's own MySQL client and admin login, or None if it fails."""
    client = server / "mysql" / "bin" / "mysql.exe"
    ini = server / "mysql" / "admin-client.ini"
    try:
        result = subprocess.run([str(client), f"--defaults-file={ini}", "--batch", "--skip-column-names", "-e", query],
                                capture_output=True, text=True, timeout=20,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode:
        return None
    return [line.split("\t") for line in result.stdout.splitlines() if line.strip()]


def _leaderboards(server, configs):
    """Top-10 boards and the server-firsts log, real players only (random bot accounts left out). Each board is its
    own query, so a table that does not exist yet (before the build with patches/47-leaderboards.ps1) only blanks
    that board. Cached for five minutes."""
    now = time.time()
    if _boards["value"] is not None and now - _boards["at"] < LEADERBOARD_SECONDS:
        return _boards["value"]
    world = _read_conf(configs / "worldserver.conf")
    chars = _database(world, "CharacterDatabaseInfo", "acore_characters")
    auth = _database(world, "LoginDatabaseInfo", "acore_auth")
    prefix = _read_conf(configs / "modules" / "playerbots.conf").get("AiPlayerbot.RandomBotAccountPrefix", "rndbot")
    prefix = re.sub(r"[^A-Za-z0-9_]", "", prefix).upper() or "RNDBOT"
    real = f"c.account NOT IN (SELECT id FROM `{auth}`.account WHERE username LIKE '{prefix}%')"
    # Characters kept off the boards and the firsts by name (Leaderboards.HiddenCharacters, comma separated): the
    # Auctioneer is the auction house bot's character, not a player, and test characters go here too.
    hidden = [n for n in (re.sub(r"[^A-Za-z]", "", n) for n in
              world.get("Leaderboards.HiddenCharacters", "Auctioneer").split(",")) if n]
    if hidden:
        real += " AND c.name NOT IN (" + ", ".join(f"'{n}'" for n in hidden) + ")"
    live = f"c.deleteDate IS NULL AND {real}"

    def board(title, unit, query):
        rows = _sql(server, query) or []
        return {"title": title, "unit": unit,
                "rows": [{"name": r[0], "value": int(float(r[1]))} for r in rows if len(r) >= 2]}

    boards = [
        board("Highest level", "level", f"SELECT c.name, c.level FROM `{chars}`.characters c WHERE {live} "
              "ORDER BY c.level DESC, c.xp DESC LIMIT 10"),
        board("Most Prestige", "prestige", f"SELECT c.name, CAST(SUBSTRING_INDEX(TRIM(s.data), ' ', 1) AS UNSIGNED) p "
              f"FROM `{chars}`.character_settings s JOIN `{chars}`.characters c ON c.guid = s.guid "
              f"WHERE s.source = 'core.coa_prestige' AND {live} HAVING p > 0 ORDER BY p DESC LIMIT 10"),
        board("Deepest Manastorm floor", "floor", f"SELECT c.name, MAX(m.best_completed_depth) d "
              f"FROM `{chars}`.character_manastorm_progress m JOIN `{chars}`.characters c ON c.guid = m.guid "
              f"WHERE {live} GROUP BY c.guid, c.name HAVING d > 0 ORDER BY d DESC LIMIT 10"),
        board("Most honourable kills", "kills", f"SELECT c.name, c.totalKills FROM `{chars}`.characters c "
              f"WHERE {live} AND c.totalKills > 0 ORDER BY c.totalKills DESC LIMIT 10"),
        board("Most world PvP kills", "kills", f"SELECT c.name, k.kills FROM `{chars}`.wcme_world_pvp_kills k "
              f"JOIN `{chars}`.characters c ON c.guid = k.guid WHERE {live} AND k.kills > 0 "
              "ORDER BY k.kills DESC LIMIT 10"),
    ]

    firsts = []
    ids = ", ".join(str(i) for i in LEVEL_ACHIEVEMENTS)
    seen = set()
    for row in _sql(server, f"SELECT a.achievement, c.name, a.date FROM `{chars}`.character_achievement a "
                            f"JOIN `{chars}`.characters c ON c.guid = a.guid WHERE a.achievement IN ({ids}) AND {live} "
                            "ORDER BY a.date, a.guid") or []:
        if len(row) >= 3 and row[0] not in seen:
            seen.add(row[0])
            level = LEVEL_ACHIEVEMENTS.get(int(row[0]))
            firsts.append({"at": int(row[2]), "text": f"{row[1]} was the first to reach level {level}."})
    for row in _sql(server, f"SELECT text, at FROM `{chars}`.wcme_server_firsts") or []:
        if len(row) >= 2 and not any(re.search(rf"\b{n}\b", row[0], re.I) for n in hidden):
            firsts.append({"at": int(row[1]), "text": row[0]})
    firsts.sort(key=lambda f: f["at"], reverse=True)
    for first in firsts:
        first["date"] = time.strftime("%d %b %Y", time.localtime(first["at"])).lstrip("0")

    value = {"boards": boards, "firsts": firsts[:40]}
    _boards["at"], _boards["value"] = now, value
    return value


def status(options):
    with _lock:
        now = time.time()
        if _cache["value"] and now - _cache["at"] < CACHE_SECONDS:
            return _cache["value"]
        server = Path(options.server)
        core = server / "Core"
        configs = core / "configs"
        try:
            ports = json.loads((server / "Settings" / "repack.json").read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            ports = {}
        login = _answers(int(ports.get("authPort", 3724)))
        world = _answers(int(ports.get("worldPort", 8085)))
        console = _console_info(options) if world else {}
        value = {
            "updated": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "login": login,
            "world": world,
            "players": console.get("players"),
            "characters": console.get("characters"),
            "uptime": console.get("uptime"),
            "server": _build(core),
            "restart": "Every night at 4:00 am (Sydney time), back within 10 minutes. Warnings start at 3:30.",
            "leaderboards": _leaderboards(server, configs),
            "settings": _settings(configs, Path(options.bridge).parent),
            "weekend": _weekend(_read_conf(configs / "worldserver.conf")),
        }
        _cache["at"], _cache["value"] = now, value
        return value
