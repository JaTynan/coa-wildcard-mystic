"""Tooltips and icons for the website's Mystic Enchants, Pets, Racials, Wildcard and Build planner pages.

Run by Publish-WildcardSite.ps1 on the VM after it copies the site, with the game server's own Python:

  python build_spell_data.py --server "C:\\Games\\CoA Server" --client F:\\CoAClient --site F:\\wildcard-site

Writes, into the site folder:
  racial-tooltips.json
                every race's racials a Wildcard character has, marked new or changed (racials.json lists our
                signature passives, their buffs and what we changed, in our own words)
  enchant-tooltips.json, enchant-tooltips-rare.json, enchant-tooltips-uncommon.json, pet-tooltips.json
                every enchant on the Mystic Enchants page (by spell id; Legendary and Epic in the first file) and every
                tameable pet family's ability (by name): name, icon, requirements, the tooltip with its numbers filled
                in, any tooltips it embeds, for an enchant how many copies one character may slot, and for a
                worldforged enchant where it comes from
  wildcard-tooltips.json
                the Wildcard ability and talent pool, the essence each level gives and the starting choices, as the
                world server reads them (wildcard_planner.py), each entry with its tooltip (a talent: one per rank)
  icons\\*.png   the icons those use, read from the game client's archives and turned into PNG

Everything is read on the VM from the server's DBC files and the client's archives; none of it is in the repository.
Spell texts and icons come from the client's own Spell.dbc (our client patch's copy), so they read as in game; the
server's copy is the fallback.
Icons are only read again when an archive changed or an icon is new, so a normal night takes a few seconds.
Prints one line for patch-night.log. Exit code 0 even when some icons or numbers could not be read; 1 only when
nothing could be written (the site then keeps its last good files).
"""
import argparse
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wildcard_mpq  # noqa: E402
import wildcard_planner as planner  # noqa: E402
import wildcard_tooltips as tips  # noqa: E402

# Pet families, as the sign-up service's /api/pets lists them (signup/WildcardPets.py): a family is tameable by the
# shared skill line its pets learn, and an ability is described by its strongest rank (largest first effect).
CATEGORIES = {270, 36, 37, 862, 1006, 1041}
SPELL_ATTR0_PASSIVE, SPELL_ATTR0_HIDDEN = 0x40, 0x80
# How many enchants of each quality a Wildcard character (the Hero class) may slot: QualityCap in the core, with
# CoA.ClientIntegerConfigs empty (its default, and not set in server-settings.txt), so the core's defaults apply.
# Rare and Uncommon have no cap of their own (the core's default is every slot), but at most 3 rare worldforged
# enchants (RARE_WORLDFORGED_LIMIT), and 17 enchant slots in all (SLOT_COUNT).
CAPS = {"Legendary": 1, "Epic": 3, "RareWorldforged": 3, "Slots": 17}
# Rare worldforged enchants drop by the enemy's type (patches/78-worldforged-enchants.ps1): name prefix -> enemies.
WORLDFORGED_FAMILIES = {
    "Fighter's ": "humanoids that are not casters", "Wizard's ": "humanoid casters (mages and paladins)",
    "Primal ": "beasts", "Demonic ": "demons", "Draconic ": "dragonkin", "Gigantic ": "giants",
    "Necrotic ": "undead", "Element-bound ": "elementals",
}
ENCHANT_FILES = {"Legendary": "enchant-tooltips.json", "Epic": "enchant-tooltips.json",
                 "Rare": "enchant-tooltips-rare.json", "Uncommon": "enchant-tooltips-uncommon.json"}
HERO_CLASS_BIT = 1 << (10 - 1)  # the Wildcard (Hero) class in SkillLineAbility's class mask
FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"


def dbc_folder(server):
    """The server's DBC folder: DataDir from worldserver.conf, as the world server reads it."""
    conf = server / "Core" / "configs" / "worldserver.conf"
    data = None
    if conf.is_file():
        for line in conf.read_text("utf-8", "replace").splitlines():
            match = re.match(r'\s*DataDir\s*=\s*"?([^"]*)"?\s*$', line)
            if match and match.group(1).strip():
                data = Path(match.group(1).strip())
                if not data.is_absolute():
                    data = server / "Core" / data
    for candidate in (data, server / "Data"):
        if candidate and (candidate / "dbc" / "Spell.dbc").is_file():
            return candidate / "dbc"
    raise SystemExit(f"No Spell.dbc under {server}")


def pet_abilities(spells, dbc):
    families = tips.DBC(dbc / "CreatureFamily.dbc")
    abilities = tips.DBC(dbc / "SkillLineAbility.dbc")
    skills = {row[5] for row in families.rows() if row[6] in CATEGORIES and row[5]}
    best = {}
    for row in abilities.rows():
        if row[1] not in skills:
            continue
        spell = spells.get(row[2])
        if not spell or spell.row[tips.C_ATTR] & SPELL_ATTR0_HIDDEN or not spell.name or \
                re.search(r"DND|Scaling|Tamed Pet Passive", spell.name):
            continue
        strength = abs(spell.col(tips.C_BASE) + 1)
        if spell.name not in best or strength > best[spell.name][0]:
            best[spell.name] = (strength, spell)
    return {name: spell for name, (_, spell) in best.items()}


def racials(spells, renderer, dbc, listing):
    """Every race's racials as a Wildcard character has them, with our signature passive first."""
    by_skill = {}
    for row in tips.DBC(dbc / "SkillLineAbility.dbc").rows():
        if row[4] == 0 or row[4] & HERO_CLASS_BIT:
            by_skill.setdefault(row[1], []).append(row[2])
    races = []
    for race in listing["races"]:
        changed = {int(k): v for k, v in race.get("changed", {}).items()}
        notes = {int(k): v for k, v in race.get("note", {}).items()}
        entries = []
        book = spells.get(race["signature"])
        if book:
            tip = renderer.tooltip(book)
            buffs = [renderer.tooltip(spells.get(b), 1) for b in race.get("buffs", []) if spells.get(b)]
            tip["subs"] = [b for b in buffs if b["lines"]]
            tip.update(kind="new", passive=True)
            entries.append(tip)
        seen = set()
        for spell_id in by_skill.get(race["skill"], []):
            spell = spells.get(spell_id)
            if not spell or spell.row[tips.C_ATTR] & SPELL_ATTR0_HIDDEN or spell_id in race.get("replaced", []) \
                    or not spell.name or spell.name in seen:
                continue
            seen.add(spell.name)
            tip = renderer.tooltip(spell)
            tip.pop("subs", None)
            tip["passive"] = bool(spell.row[tips.C_ATTR] & SPELL_ATTR0_PASSIVE)
            if spell_id in changed:
                tip.update(kind="changed", change=changed[spell_id])
            if spell_id in notes:
                tip["note"] = notes[spell_id]
            entries.append(tip)
        order = {"new": 0, "changed": 1}
        entries.sort(key=lambda t: (order.get(t.get("kind"), 2), t["passive"], t["name"]))
        races.append({"race": race["race"], "faction": race["faction"], "icon_path": race["icon"],
                      "icon": race["icon"].rsplit("\\", 1)[-1].lower(), "racials": entries})
    return races


def worldforged(dbc):
    """Spell ids of the worldforged enchants (MysticEnchant.dbc field 7, as AscensionMysticEnchantRules.cpp reads it)."""
    table = tips.DBC(dbc / "MysticEnchant.dbc")
    return {row[1] for row in table.rows() if row[7]}


def enchant_sources(drop_chance):
    """Where worldforged enchants come from, in our own words, by key (a tooltip's "source")."""
    sources = {"hidden": "Worldforged: Ascension hid this one in the world. It does not drop on Wildcard yet."}
    for prefix, enemies in WORLDFORGED_FAMILIES.items():
        sources[prefix.strip()] = (
            f"Worldforged: drops from {enemies} above level 10 that give experience ({drop_chance}% a kill), and only "
            f"for an ability you know. Up to {CAPS['RareWorldforged']} rare worldforged enchants at a time.")
    return sources


def enchant_source(spell, quality, is_worldforged):
    """The key of where a worldforged enchant comes from; "" for an ordinary one (Mystic Scrolls)."""
    if not is_worldforged:
        return ""
    for prefix in WORLDFORGED_FAMILIES:
        if quality == "Rare" and spell.name.startswith(prefix):
            return prefix.strip()
    return "hidden"


def wildcard_pool(dbc, server, spells, renderer):
    """wildcard-tooltips.json's content, without icons cleared yet."""
    ability_pool = planner.server_setting(server, "Wildcard.AbilityPool", "all")
    entries = planner.pool(dbc, ability_pool)
    starters, card_quality = planner.cards(dbc, entries)
    out = []
    for entry in entries:
        ranks = [spells.get(spell_id) for spell_id in entry["spells"]]
        top = next((s for s in reversed(ranks) if s), None)
        # Never rolled: glyphs, and abilities that cost no essence (the death knight runes).
        if not top or top.name.startswith("Glyph of ") or (not entry["talent"] and not entry["cost"]):
            continue
        tip = renderer.tooltip(top)
        if entry["talent"] and len(ranks) > 1:
            tip["ranks"] = [renderer.tooltip(s)["lines"] if s else [] for s in ranks]
        item = {"id": entry["id"], "name": entry["name"] or top.name, "talent": entry["talent"],
                "class": entry["class"], "tab": entry["tab"], "level": entry["level"], "cost": entry["cost"],
                "tip": tip}
        if entry["kind"] == "TalentAbility":
            item["fromTalent"] = True
        if entry["group"] == planner.TAME_GROUP:
            item["tame"] = True
        if entry["id"] in starters:
            item["starter"] = True
        if entry["id"] in card_quality:
            item["card"] = card_quality[entry["id"]]
        out.append(item)
    drop = planner.server_setting(server, "Wildcard.CardDropChancePerMille", "30")
    weights = planner.server_setting(server, "Wildcard.CardDropQualityWeights", "")
    return {"pool": ability_pool, "budget": planner.budget(dbc), "talentStart": planner.TALENT_POOL_START_LEVEL,
            "startingAbilities": 4, "cardSlotLevels": [0, 25, 40], "cardDropPerMille": int(drop or 0),
            "cardWeights": dict(zip(planner.QUALITIES, [int(w) for w in weights.split(",")])) if
            len(weights.split(",")) == 5 else {}, "entries": out}


def icon_paths(tip, found):
    if tip.get("icon_path"):
        found.add(tip["icon_path"])
    for sub in tip.get("subs", []):
        icon_paths(sub, found)


def finish(tip):
    """Drop the archive path the page does not need."""
    tip.pop("icon_path", None)
    for sub in tip.get("subs", []):
        finish(sub)
    return tip


def extract_icons(client, wanted, folder):
    """Write folder/<name>.png for each wanted icon path. Returns (written, missing names, note)."""
    folder.mkdir(parents=True, exist_ok=True)
    archives = wildcard_mpq.client_archives(client)
    fingerprint = [[p.name, p.stat().st_size, int(p.stat().st_mtime)] for p in archives]
    source_file = folder / ".source.json"
    try:
        previous = json.loads(source_file.read_text("utf-8"))
    except (OSError, ValueError):
        previous = {}
    changed = previous.get("archives") != fingerprint
    names = {path: path.replace("/", "\\").rsplit("\\", 1)[-1].lower() for path in wanted}
    hashes = {path: wildcard_mpq.name_hashes(path + ".blp") for path in wanted}
    known_missing = set() if changed else set(previous.get("missing", []))
    todo = {path for path, name in names.items()
            if changed or (not (folder / f"{name}.png").is_file() and name not in known_missing)}
    written, unreadable = 0, 0
    opened = []
    try:
        for archive_path in archives:
            if not todo:
                break
            try:
                archive = wildcard_mpq.Archive(archive_path)
            except (OSError, ValueError):
                continue
            opened.append(archive)
            for path in sorted(todo):
                try:
                    data = archive.read(path + ".blp", hashes[path])
                except (wildcard_mpq.UnreadableFile, OSError, ValueError, EOFError):
                    unreadable += 1
                    continue
                except Exception:  # a damaged file must not stop the rest (zlib.error, bz2 OSError ...)
                    unreadable += 1
                    continue
                if data is None:
                    continue
                try:
                    width, height, rgba = wildcard_mpq.blp_to_rgba(data)
                    target = folder / f"{names[path]}.png"
                    target.with_suffix(".tmp").write_bytes(wildcard_mpq.png(width, height, rgba))
                    os.replace(target.with_suffix(".tmp"), target)
                    written += 1
                    todo.discard(path)
                except Exception:
                    unreadable += 1
    finally:
        for archive in opened:
            archive.close()
    missing = sorted(names[p] for p in todo) + sorted(known_missing & set(names.values()))
    source_file.write_text(json.dumps({"archives": fingerprint, "missing": missing}), "utf-8")
    present = {n for n in names.values() if (folder / f"{n}.png").is_file()}
    return written, present, unreadable


def write_json(target, data):
    temporary = target.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, separators=(",", ":"), ensure_ascii=False), "utf-8")
    os.replace(temporary, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--server", default=r"C:\Games\CoA Server")
    parser.add_argument("--client", default=r"F:\CoAClient")
    parser.add_argument("--site", default=r"F:\wildcard-site")
    parser.add_argument("--enchants", help="enchant-status.json (default: the one in the site folder)")
    args = parser.parse_args()
    started = time.time()
    server, site = Path(args.server), Path(args.site)
    dbc = dbc_folder(server)
    spell_data, spell_source = wildcard_mpq.read_client_file(args.client, "DBFilesClient\\Spell.dbc")
    icon_data, _ = wildcard_mpq.read_client_file(args.client, "DBFilesClient\\SpellIcon.dbc") if spell_data else (None, "")
    spells = tips.Spells(dbc, spell_data, icon_data)
    renderer = tips.Renderer(spells)

    listed = json.loads(Path(args.enchants or site / "enchant-status.json").read_text("utf-8-sig"))["enchants"]
    forged = worldforged(dbc)
    drop_chance = planner.server_setting(server, "Wildcard.WorldforgedDropChance", "1")
    enchants, quality_of = {}, {}
    for entry in listed:
        spell = spells.get(int(entry["spell"]))
        if spell and str(spell.id) not in enchants and entry["quality"] in ENCHANT_FILES:
            tip = renderer.tooltip(spell)
            tip["limit"] = max(1, spell.row[tips.C_STACK])
            source = enchant_source(spell, entry["quality"], int(entry["spell"]) in forged)
            if source:
                tip["source"] = source
            enchants[str(spell.id)] = tip
            quality_of[str(spell.id)] = entry["quality"]
    wildcard = wildcard_pool(dbc, server, spells, renderer)
    pool_tips = [entry["tip"] for entry in wildcard["entries"]]
    pets = {name: renderer.tooltip(spell) for name, spell in sorted(pet_abilities(spells, dbc).items())}
    listing = json.loads((Path(__file__).resolve().parent / "racials.json").read_text("utf-8"))
    races = racials(spells, renderer, dbc, listing)
    for tip in pets.values():
        tip.pop("subs", None)  # pet abilities have no embedded Ascension tooltips worth showing

    # Icons: attach each tooltip's archive path, then read what is needed.
    def attach(tip, spell_id):
        spell = spells.get(spell_id)
        tip["icon_path"] = spell.icon_path if spell else ""
        for sub in tip.get("subs", []):
            attach(sub, sub["id"])
    for key, tip in enchants.items():
        attach(tip, int(key))
    for tip in pets.values():
        attach(tip, tip["id"])
    racial_tips = [t for race in races for t in race["racials"]]
    for tip in racial_tips + pool_tips:
        attach(tip, tip["id"])
    wanted = {FALLBACK_ICON} | {race["icon_path"] for race in races}
    every_tip = list(enchants.values()) + list(pets.values()) + racial_tips + pool_tips
    for tip in every_tip:
        icon_paths(tip, wanted)
    written, present, unreadable = extract_icons(Path(args.client), wanted, site / "icons")

    def clear(tip):
        if tip.get("icon") not in present:
            tip["icon"] = ""
        for sub in tip.get("subs", []):
            clear(sub)
    for tip in every_tip:
        clear(finish(tip))
    for race in races:
        race.pop("icon_path")
        if race["icon"] not in present:
            race["icon"] = ""

    common = {"updated": datetime.now().astimezone().isoformat(timespec="seconds"), "level": tips.LEVEL,
              "fallbackIcon": FALLBACK_ICON.rsplit("\\", 1)[-1].lower()}
    for name in sorted(set(ENCHANT_FILES.values())):
        part = {key: tip for key, tip in enchants.items() if ENCHANT_FILES[quality_of[key]] == name}
        write_json(site / name, dict(common, caps=CAPS, sources=enchant_sources(drop_chance), tooltips=part))
    write_json(site / "pet-tooltips.json", dict(common, tooltips=pets))
    write_json(site / "racial-tooltips.json", dict(common, races=races))
    write_json(site / "wildcard-tooltips.json", dict(common, **wildcard))
    no_icon = sum(1 for t in every_tip if not t["icon"])
    print(f"Spell tooltips: {len(enchants)} enchants, {len(pets)} pet abilities, {len(racial_tips)} racials, "
          f"{len(pool_tips)} Wildcard abilities and talents, "
          f"from {spell_source or 'the server'}'s Spell.dbc, {renderer.unknown} number(s) not "
          f"worked out, {len(present)} icons ({written} read now, {no_icon} tooltip(s) without one"
          f"{f', {unreadable} unreadable' if unreadable else ''}), {time.time() - started:.0f} s.")


if __name__ == "__main__":
    main()
