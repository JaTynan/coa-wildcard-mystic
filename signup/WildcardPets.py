"""Tameable pets for the website's Pets page (launcher/site/pets.html, through /api/pets on the sign-up server).

Everything comes from the live server, so the page follows patches and client updates by itself:
  the families, their category and their abilities from the server's DBC files (CreatureFamily, SkillLine,
  SkillLineAbility, Spell, SpellDuration);
  the creatures players can tame (a family and the tameable type flag, as CreatureTemplate::IsTameable has it; the
  exotic flag marks the ones that need Beast Mastery) and one spawn of each from the world database;
  where that spawn is from the server's map files (the area grid in each tile, as GridTerrainData::getArea reads
  it) and AreaTable.dbc, since the world database leaves zoneId empty for nearly every spawn.
For each family it shows one creature: the lowest-level ordinary (not elite) one spawned in the open world, preferring
one with several spawns over a named one-off. Built once, then kept for six hours (a few seconds of work, most of it reading Spell.dbc).
"""
import re
import struct
import threading
import time
from datetime import datetime
from pathlib import Path

import WildcardStatus

CACHE_SECONDS = 6 * 3600
# A family is a tameable kind by the shared skill line its pets also learn; class summons (Imp, Felhunter, the
# Death Knight's ghoul...) have none of these and are left out.
CATEGORIES = {270: "Beast", 36: "Demon", 37: "Undead", 862: "Elemental", 1006: "Dragonkin", 1041: "Mechanical"}
CATEGORY_ORDER = ["Beast", "Undead", "Demon", "Elemental", "Dragonkin", "Mechanical"]
OPEN_WORLD = (0, 1, 530, 571)  # Eastern Kingdoms, Kalimdor, Outland, Northrend
TYPE_FLAG_TAMEABLE, TYPE_FLAG_EXOTIC = 0x1, 0x10000
SPELL_ATTR0_PASSIVE, SPELL_ATTR0_HIDDEN = 0x40, 0x80
GRID = 533.3333333

_lock = threading.Lock()
_cache = {"at": 0.0, "value": None}


def _dbc(path):
    """Rows (tuples of uint32) and a string lookup for a WDBC file."""
    data = path.read_bytes()
    count, fields, size, _ = struct.unpack_from("<4I", data, 4)
    rows = [struct.unpack_from(f"<{fields}I", data, 20 + i * size) for i in range(count)]
    strings = data[20 + count * size:]

    def text(offset):
        if not 0 <= offset < len(strings):
            return ""
        return strings[offset:strings.index(b"\0", offset)].decode("utf-8", "replace")

    return rows, text


def _spells(path, wanted):
    """Name, attributes, description and effect numbers of the wanted spell ids, read straight from Spell.dbc."""
    data = path.read_bytes()
    count, fields, size, _ = struct.unpack_from("<4I", data, 4)
    strings = 20 + count * size
    found = {}
    for i in range(count):
        offset = 20 + i * size
        spell = struct.unpack_from("<I", data, offset)[0]
        if spell not in wanted:
            continue
        row = struct.unpack_from(f"<{fields}I", data, offset)

        def text(at):
            start = strings + at
            return data[start:data.index(b"\0", start)].decode("utf-8", "replace") if at else ""

        signed = [v - (1 << 32) if v >= 1 << 31 else v for v in row[80:83]]
        found[spell] = {"name": text(row[136]), "attributes": row[4], "description": text(row[170]),
                        "duration": row[40], "base": signed, "amplitude": list(row[98:101])}
    return found


def _describe(spell, durations):
    """The tooltip with its numbers filled in, or "" when it uses anything this can't work out."""
    def seconds(ms):
        return f"{ms / 1000:g} sec" if ms < 60000 else f"{ms / 60000:g} min"

    duration = durations.get(spell["duration"], 0)

    def token(match):
        kind, index = match.group(1).lower(), int(match.group(2) or 1) - 1
        if kind == "d":
            return seconds(duration) if duration > 0 else "?"
        if not 0 <= index < 3:
            return "?"
        if kind in ("s", "m"):
            return str(abs(spell["base"][index] + 1))
        if kind == "t":
            return f"{spell['amplitude'][index] / 1000:g}" if spell["amplitude"][index] else "?"
        if kind == "o":
            ticks = duration // spell["amplitude"][index] if spell["amplitude"][index] and duration > 0 else 0
            return str(abs(spell["base"][index] + 1) * ticks) if ticks else "?"
        return "?"

    text = spell["description"]
    if not text or re.search(r"\$(?:[{<\d/]|(?![sSmMdDtToO]))", text):
        return ""  # formulas, other spells' numbers, scaling variables
    text = re.sub(r"\$([sSmMdDtToO])(\d)?", token, text)
    return "" if "?" in text or "$" in text else re.sub(r"\s+", " ", text).strip()


class _Areas:
    """Area of a point, from the area grid in the server's map tiles (one 16x16 grid per 533-yard tile)."""

    def __init__(self, maps, table):
        self.maps, self.table, self.tiles = maps, table, {}

    def area(self, map_id, x, y):
        gx, gy = int(32 - x / GRID), int(32 - y / GRID)
        key = (map_id, gx, gy)
        if key not in self.tiles:
            self.tiles[key] = self._load(map_id, gx, gy)
        tile = self.tiles[key]
        if tile is None:
            return 0
        if isinstance(tile, int):
            return tile
        cx, cy = int(16 * (32 - x / GRID)) & 15, int(16 * (32 - y / GRID)) & 15
        return tile[cx * 16 + cy]

    def _load(self, map_id, gx, gy):
        try:
            data = (self.maps / f"{map_id:03}{gx:02}{gy:02}.map").read_bytes()
            offset = struct.unpack_from("<I", data, 12)[0]
            if not offset:
                return None
            _, flags, grid_area = struct.unpack_from("<IHH", data, offset)
            return grid_area if flags & 1 else struct.unpack_from("<256H", data, offset + 8)
        except (OSError, struct.error):
            return None

    def place(self, map_id, x, y, map_names, instanced):
        """'Area, Zone' in the open world, else the map's name (a dungeon, raid or other instance)."""
        if map_id in instanced:
            return f"{map_names.get(map_id, f'map {map_id}')} (instance)"
        area = self.area(map_id, x, y)
        names = []
        while area and area in self.table and len(names) < 3:
            parent, name = self.table[area]
            if name and name not in names:
                names.append(name)
            area = parent
        if len(names) > 2:
            names = [names[0], names[-1]]
        return ", ".join(names) or map_names.get(map_id, f"map {map_id}")


def _build(server):
    configs = server / "Core" / "configs"
    world = WildcardStatus._read_conf(configs / "worldserver.conf")
    data_dir = Path(world.get("DataDir", "").strip('"') or (server / "Data"))
    if not data_dir.is_absolute():
        data_dir = server / "Core" / data_dir
    if not (data_dir / "dbc").is_dir():
        data_dir = server / "Data"
    dbc = data_dir / "dbc"

    families_rows, family_text = _dbc(dbc / "CreatureFamily.dbc")
    abilities_rows, _ = _dbc(dbc / "SkillLineAbility.dbc")
    duration_rows, _ = _dbc(dbc / "SpellDuration.dbc")
    area_rows, area_text = _dbc(dbc / "AreaTable.dbc")
    map_rows, map_text = _dbc(dbc / "Map.dbc")
    durations = {r[0]: r[1] for r in duration_rows}
    areas = _Areas(data_dir / "maps", {r[0]: (r[2], area_text(r[11])) for r in area_rows})
    map_names = {r[0]: map_text(r[5]) for r in map_rows}
    instanced = {r[0] for r in map_rows if r[2]}

    families = {}
    for row in families_rows:
        category = CATEGORIES.get(row[6])
        if category and row[5]:
            families[row[0]] = {"id": row[0], "name": family_text(row[10]), "category": category, "skill": row[5]}
    by_skill = {}
    for row in abilities_rows:
        by_skill.setdefault(row[1], []).append(row[2])
    wanted = {spell for family in families.values() for spell in by_skill.get(family["skill"], [])}
    spells = _spells(dbc / "Spell.dbc", wanted)

    for family in families.values():
        seen = {}
        for spell_id in by_skill.get(family["skill"], []):
            spell = spells.get(spell_id)
            if not spell or spell["attributes"] & SPELL_ATTR0_HIDDEN or not spell["name"] or \
                    re.search(r"DND|Scaling|Tamed Pet Passive", spell["name"]):
                continue
            # One entry per ability, described by its strongest rank (largest first effect).
            strength = abs(spell["base"][0] + 1)
            if spell["name"] not in seen or strength > seen[spell["name"]][0]:
                seen[spell["name"]] = (strength, {"name": spell["name"],
                                                  "passive": bool(spell["attributes"] & SPELL_ATTR0_PASSIVE),
                                                  "text": _describe(spell, durations)})
        family["abilities"] = [entry for _, entry in seen.values()]

    # The creatures players can tame, and one spawn of each per map.
    database = WildcardStatus._database(world, "WorldDatabaseInfo", "acore_world")
    templates = WildcardStatus._sql(server, (
        f"SELECT entry, family, minlevel, maxlevel, type_flags, `rank`, REPLACE(name, '\\t', ' ') "
        f"FROM `{database}`.creature_template WHERE family <> 0 AND (type_flags & {TYPE_FLAG_TAMEABLE}) <> 0"))
    spawns = WildcardStatus._sql(server, (
        f"SELECT c.id1, c.map, c.position_x, c.position_y, m.n FROM `{database}`.creature c JOIN ("
        f"SELECT MIN(c2.guid) AS g, COUNT(*) AS n FROM `{database}`.creature c2 JOIN `{database}`.creature_template t "
        f"ON t.entry = c2.id1 WHERE t.family <> 0 AND (t.type_flags & {TYPE_FLAG_TAMEABLE}) <> 0 "
        f"GROUP BY c2.id1, c2.map) m ON m.g = c.guid"))
    if templates is None or spawns is None:
        raise RuntimeError("the world database did not answer")

    where = {}
    for entry, map_id, x, y, count in (row[:5] for row in spawns if len(row) >= 5):
        where.setdefault(int(entry), []).append((int(map_id), float(x), float(y), int(count)))
    creatures = {}
    for row in templates:
        if len(row) < 7:
            continue
        entry, family, low, high, flags, rank = (int(v) for v in row[:6])
        if family in families:
            creatures.setdefault(family, []).append({
                "entry": entry, "name": row[6], "low": low, "high": high, "rank": rank,
                "exotic": bool(flags & TYPE_FLAG_EXOTIC), "spawns": where.get(entry, [])})

    for family_id, family in families.items():
        found = creatures.get(family_id, [])
        spawned = [c for c in found if c["spawns"]]
        family["tameable"] = len(found)
        family["exotic"] = bool(found) and all(c["exotic"] for c in found)
        family["example"] = None
        if spawned:
            # An ordinary creature out in the world, one there are several of (not a named one-off), lowest level.
            def score(c):
                open_world = any(s[0] in OPEN_WORLD and s[0] not in instanced for s in c["spawns"])
                return (not open_world, c["rank"] != 0, sum(s[3] for s in c["spawns"]) < 3, c["low"], c["name"])
            pick = min(spawned, key=score)
            spawn = min(pick["spawns"], key=lambda s: (s[0] not in OPEN_WORLD or s[0] in instanced, -s[3]))
            level = str(pick["low"]) if pick["low"] == pick["high"] else f"{pick['low']}-{pick['high']}"
            family["example"] = {"name": pick["name"], "level": level, "elite": pick["rank"] != 0,
                                 "exotic": pick["exotic"],
                                 "where": areas.place(spawn[0], spawn[1], spawn[2], map_names, instanced)}
        del family["skill"]

    order = {name: i for i, name in enumerate(CATEGORY_ORDER)}
    listed = sorted(families.values(), key=lambda f: (order[f["category"]], f["name"].lower(), f["id"]))
    return {"updated": datetime.now().astimezone().isoformat(timespec="seconds"), "categories": CATEGORY_ORDER, "families": listed}


def pets(options):
    with _lock:
        now = time.time()
        if _cache["value"] and now - _cache["at"] < CACHE_SECONDS:
            return _cache["value"]
        value = _build(Path(options.server))
        _cache["at"], _cache["value"] = now, value
        return value
