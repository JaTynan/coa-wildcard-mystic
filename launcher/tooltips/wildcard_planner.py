"""The Wildcard ability and talent pool, the essence budget and the starting choices, read the way the world server
reads them (AscensionWildcard.cpp, LoadTables and LoadSkillCards), for the website's Wildcard and Build planner pages.

What the server does, and so what this reproduces:
  - The pool is every CharacterAdvancement.dbc row of type Ability, TalentAbility or Talent whose Wildcard mode byte
    (field 121, bits 8-15) is 1, that is not draft-only (flag 0x1000000 in field 120) and that has at least one rank
    spell (fields 5-9). Wildcard.AbilityPool "classic" also leaves out the Conquest of Azeroth classes' entries; on
    this data every Wildcard entry belongs to an original class, General or the Hero, so nothing is dropped.
  - An ability costs its Wildcard ability essence (field 22, almost always 2); a talent costs 1 talent essence,
    whatever its rank. Abilities that cost nothing (the death knight runes) and glyphs are never rolled.
  - An entry can be rolled once the character has earned the essence it needs by its Wildcard level (field 28);
    talents not before level 10.
  - The essence budget per level is CharacterAdvancementEssence.dbc's Hero rows marked Wildcard (not draft).
  - The four starting abilities are picked with starter cards, which every Wildcard character has: two normal and two
    golden, each a different ability. The starter cards are SkillCard.dbc's Hero Wildcard rows marked starter.
  - Only one way to tame a pet (the five entries in group 2).
  - Skill cards: every normal ability and talent card can drop from any enemy worth experience
    (Wildcard.CardDropChancePerMille, weighted by quality); golden cards come from packs and the Darkmoon tickets.
    No card is tied to a place or an enemy.

Standard library only: it runs on the game server's own Python.
"""
import re
import struct
from pathlib import Path

TYPES = ("Ability", "TalentAbility", "Talent")
DRAFT_ONLY = 0x1000000
TAME_GROUP = 2
TALENT_POOL_START_LEVEL = 10
HERO_CLASS = 10
CUSTOM_CLASSES = range(12, 33)  # the Conquest of Azeroth classes (IsAscensionCustomClassId)
# CharacterAdvancement.dbc fields (the server's ADVANCEMENT_* plus the display ones)
F_ID, F_TYPE, F_SPELLS, F_AE, F_LEVEL, F_GROUP, F_CLASS_TYPE, F_TAB, F_NAME, F_ICON, F_FLAGS, F_MODES = \
    0, 1, 5, 22, 28, 29, 32, 33, 47, 64, 120, 121
QUALITIES = ("Common", "Uncommon", "Rare", "Epic", "Legendary")


class Table:
    """A DBC file. Unlike wildcard_tooltips.DBC, a string at offset 0 is read too: in CharacterAdvancement.dbc offset 0
    is "Ability"."""

    def __init__(self, path):
        self.data = Path(path).read_bytes()
        if self.data[:4] != b"WDBC":
            raise ValueError(f"{path} is not a DBC file")
        self.count, self.fields, self.size, _ = struct.unpack_from("<4I", self.data, 4)
        self.strings = 20 + self.count * self.size

    def rows(self):
        for i in range(self.count):
            yield struct.unpack_from(f"<{self.fields}I", self.data, 20 + i * self.size)

    def text(self, offset):
        start = self.strings + offset
        return self.data[start:self.data.index(b"\0", start)].decode("utf-8", "replace")


def budget(dbc):
    """[[level, ability essence, talent essence], ...] for the Wildcard Hero, by level."""
    rows = [r for r in Table(dbc / "CharacterAdvancementEssence.dbc").rows()
            if r[2] == HERO_CLASS and r[4] and not r[3] and not r[5] and not r[6]]
    return sorted([r[1], r[7], r[8]] for r in rows)


def pool(dbc, ability_pool="classic"):
    """The Wildcard entries, in the order the server loads them."""
    advancement = Table(dbc / "CharacterAdvancement.dbc")
    class_types = Table(dbc / "CharacterAdvancementClassTypes.dbc")
    tabs = Table(dbc / "CharacterAdvancementTabTypes.dbc")
    class_of = {r[0]: r[2] for r in class_types.rows()}
    class_name = {r[0]: class_types.text(r[1]) for r in class_types.rows()}
    tab_name = {r[0]: tabs.text(r[2]) for r in tabs.rows()}
    spell_class = {}
    rows = list(advancement.rows())
    for row in rows:
        owner = class_of.get(row[F_CLASS_TYPE])
        if owner is not None:
            for spell_id in row[F_SPELLS:F_SPELLS + 5]:
                if spell_id:
                    spell_class[spell_id] = owner

    def in_pool(spell_id):
        owner = spell_class.get(spell_id)
        if ability_pool == "all" or not owner or owner == HERO_CLASS:
            return True
        return (owner in CUSTOM_CLASSES) == (ability_pool == "coa")

    entries = []
    for row in rows:
        kind = advancement.text(row[F_TYPE])
        if kind not in TYPES or ((row[F_MODES] >> 8) & 0xFF) != 1 or row[F_FLAGS] & DRAFT_ONLY or \
                row[F_ID] > 0xFFFFFF:
            continue
        spells = [s for s in row[F_SPELLS:F_SPELLS + 5] if s]
        if not spells or not in_pool(spells[0]):
            continue
        entries.append({
            "id": row[F_ID], "talent": kind == "Talent", "kind": kind, "spells": spells,
            "level": row[F_LEVEL], "cost": 1 if kind == "Talent" else row[F_AE], "group": row[F_GROUP],
            "class": class_name.get(row[F_CLASS_TYPE], ""), "tab": re.sub(r" \(\d+\)$", "", tab_name.get(row[F_TAB], "")),
            "name": advancement.text(row[F_NAME]),
        })
    return entries


def cards(dbc, entries):
    """(starter entry ids, {entry id: card quality}) from SkillCard.dbc, matched to entries as the server does."""
    table = Table(dbc / "SkillCard.dbc")
    ability_by_spell, talent_by_spell = {}, {}
    for entry in entries:
        if entry["talent"]:
            for spell_id in entry["spells"]:
                talent_by_spell.setdefault(spell_id, entry)
            continue
        known = ability_by_spell.get(entry["spells"][0])
        if known is None or (known["level"] > 1 and entry["level"] <= 1):
            ability_by_spell[entry["spells"][0]] = entry
    starters, quality = set(), {}
    for row in table.rows():
        kind, klass, grade = table.text(row[5]), table.text(row[7]), table.text(row[8])
        if not row[9] or klass != "CLASS_HERO" or not kind.startswith("SKILL_CARD_") or kind == "SKILL_CARD_MAX":
            continue
        talent = kind.startswith("SKILL_CARD_TALENT")
        entry = (talent_by_spell if talent else ability_by_spell).get(row[4])
        if not entry:
            continue
        name = grade.replace("SKILL_CARD_", "").title()
        if row[11]:
            if row[2] == 1 and kind in ("SKILL_CARD_DEFAULT_NORMAL", "SKILL_CARD_DEFAULT_GOLDEN"):
                starters.add(entry["id"])
        elif kind in ("SKILL_CARD_DEFAULT_NORMAL", "SKILL_CARD_TALENT_NORMAL") and name in QUALITIES:
            quality[entry["id"]] = name
    return starters, quality


def server_setting(server, name, default):
    """A setting's value from the server's config files (the last line that sets it), else the default."""
    value = default
    for path in sorted((server / "Core" / "configs").rglob("*.conf")) if (server / "Core" / "configs").is_dir() else []:
        try:
            lines = path.read_text("utf-8", "replace").splitlines()
        except OSError:
            continue
        for line in lines:
            key, sep, rest = line.partition("=")
            if sep and key.strip() == name:
                value = rest.split("#", 1)[0].strip().strip('"')
    return value
