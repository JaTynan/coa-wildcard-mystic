#!/usr/bin/env python3
"""Mystic Enchant audit: which enchants can work on this server, and why the others cannot.

Usage:  python3 enchant_audit.py <dbc folder> [output folder]
        e.g. python3 enchant_audit.py ~/coa-test/env/dist/data/dbc ~/enchant-audit

Reads MysticEnchant.dbc (the enchant list) and Spell.dbc (the spell definitions the server
uses). If the test server's database container is running, it also reads the custom spells
(spell_dbc) and the spells that have custom code (spell_script_names). Nothing is changed.

Writes summary.txt (counts per category) and enchants.csv (one row per enchant).

Categories:
  missing      the enchant's spell exists nowhere the server looks
  unsupported  uses a spell effect or aura type this core does not have (an Ascension extension)
  needs-code   relies on a dummy/script effect, or a proc with no spell to trigger, and has no
               custom code on the server: it is applied but does nothing (or only part of it works)
  scripted     same as needs-code, but the server has custom code for it: probably works
  standard     built only from standard effects the core handles: should work
"""
import csv
import os
import struct
import subprocess
import sys
from collections import Counter

# WotLK 3.3.5a Spell.dbc fields (0-based)
F_ID, F_PROC_FLAGS, F_PROC_CHANCE = 0, 34, 35
F_EFFECT, F_AURA, F_TRIGGER = 71, 95, 116          # three of each
F_NAME, F_DESC = 136, 170                           # enUS strings
# MysticEnchant.dbc fields (0-based)
M_SPELL, M_QUALITY, M_WORLDFORGED, M_CLASS_LO, M_CLASS_HI = 1, 3, 7, 13, 14
M_REALM_LIVE, M_REALM_SEASONAL = 8, 9   # a "live seasonal" realm offers enchants marked for either

APPLY_AURA_EFFECTS = {6, 27, 35, 65, 119, 128, 129, 143}   # apply aura / persistent / area auras
DUMMY_EFFECTS = {3, 77}                                    # SPELL_EFFECT_DUMMY, SPELL_EFFECT_SCRIPT_EFFECT
DUMMY_AURAS = {4, 226}                                     # SPELL_AURA_DUMMY, SPELL_AURA_PERIODIC_DUMMY
TRIGGER_AURAS = {23, 42, 109, 231}                         # periodic trigger / proc trigger / add target trigger
TOTAL_EFFECTS, TOTAL_AURAS = 165, 317                      # AzerothCore 3.3.5 limits

CLASS_NAMES = {1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue", 5: "Priest", 6: "DeathKnight",
               7: "Shaman", 8: "Mage", 9: "Warlock", 10: "Hero", 11: "Druid"}


def read_wdbc(path):
    with open(path, "rb") as handle:
        data = handle.read()
    magic, count, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
    if magic != b"WDBC":
        sys.exit(f"{path} is not a WDBC file")
    base = 20 + count * size

    def string(offset):
        if not 0 <= offset < strings:
            return ""
        end = data.index(b"\0", base + offset)
        return data[base + offset:end].decode("utf-8", "replace")

    def record(index):
        start = 20 + index * size
        return struct.unpack_from(f"<{size // 4}I", data, start)

    return count, fields, size, record, string


def db_set(query):
    """Runs a query in the test server's database container; None when it is not reachable."""
    for container in ("ac-database", "azerothcore-wotlk-ac-database-1", "coa-test-ac-database-1"):
        try:
            out = subprocess.run(["docker", "exec", container, "mysql", "-uroot", "-ppassword", "-N", "-B",
                                  "acore_world", "-e", query], capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            return None
        if out.returncode == 0:
            return {int(line.split()[0]) for line in out.stdout.split("\n") if line.strip().lstrip("-").isdigit()}
    return None


def taught_spell(desc):
    """The spell an enchant teaches, read the way the server reads it: "Teaches you ... @s:NNN"."""
    at = 0 if desc.startswith("Teaches you") else desc.find("\nTeaches you")
    if at < 0:
        return 0
    token = desc.find("@s:", at)
    if token < 0:
        return 0
    digits = ""
    for ch in desc[token + 3:]:
        if not ch.isdigit():
            break
        digits += ch
    return int(digits) if digits else 0


def judge(spell_id, spells, custom, scripted):
    spell = spells.get(spell_id)
    effects, notes = [], []
    if not spell:
        if spell_id in custom:
            return "custom-db", effects, ["defined only in spell_dbc; not audited further"]
        return "missing", effects, notes
    unsupported = needs = False
    for i in range(3):
        effect, aura, trigger = spell[F_EFFECT + i], spell[F_AURA + i], spell[F_TRIGGER + i]
        if not effect:
            continue
        label = f"E{effect}"
        if effect >= TOTAL_EFFECTS:
            unsupported = True
            notes.append(f"effect {effect} unknown to the core")
        if effect in APPLY_AURA_EFFECTS:
            label += f"/A{aura}"
            if aura >= TOTAL_AURAS:
                unsupported = True
                notes.append(f"aura {aura} unknown to the core")
            elif aura in DUMMY_AURAS:
                needs = True
                notes.append("dummy aura")
            elif aura in TRIGGER_AURAS:
                if not trigger:
                    needs = True
                    notes.append("triggers nothing by itself")
                elif trigger not in spells and trigger not in custom:
                    needs = True
                    notes.append(f"triggered spell {trigger} missing")
        if effect in DUMMY_EFFECTS:
            needs = True
            notes.append("dummy/script effect")
        if trigger:
            label += f">{trigger}"
        effects.append(label)
    if not effects:
        needs = True
        notes.append("no effects at all")
    if unsupported:
        return "unsupported", effects, notes
    if needs:
        return ("scripted" if spell_id in scripted else "needs-code"), effects, notes
    return "standard", effects, notes


def classes(mask):
    if not mask:
        return "all"
    names = [CLASS_NAMES.get(bit + 1, f"class{bit + 1}") for bit in range(64) if mask >> bit & 1]
    return " ".join(names)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    dbc = os.path.expanduser(sys.argv[1])
    out_dir = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else ".")
    os.makedirs(out_dir, exist_ok=True)

    print("Reading Spell.dbc (209 MB, this takes a minute)...")
    s_count, s_fields, s_size, s_record, s_string = read_wdbc(os.path.join(dbc, "Spell.dbc"))
    if s_fields < 187:
        sys.exit(f"Spell.dbc has {s_fields} fields per record; this script expects the 3.3.5 layout (234).")
    # Keep only the fields the audit uses (a full record is 234 numbers; Spell.dbc holds a lot of them).
    keep = [F_NAME, F_DESC] + [F_EFFECT + i for i in range(3)] + [F_AURA + i for i in range(3)] + \
        [F_TRIGGER + i for i in range(3)]
    spells = {}
    for index in range(s_count):
        row = s_record(index)
        spells[row[F_ID]] = {field: row[field] for field in keep}

    custom = db_set("SELECT ID FROM spell_dbc")
    scripted = db_set("SELECT spell_id FROM spell_script_names") or set()
    if scripted:
        # negative ids in spell_script_names cover every rank of a spell; keep the absolute values
        scripted = {abs(spell) for spell in scripted}
    db_note = ("database read: %d custom spells, %d scripted spells" % (len(custom), len(scripted))
               if custom is not None else "database not reachable (start the test server for a fuller audit)")
    custom = custom or set()

    m_count, m_fields, _, m_record, m_string = read_wdbc(os.path.join(dbc, "MysticEnchant.dbc"))
    rows, tally, off_realm = [], Counter(), Counter()
    by_quality = Counter()
    for index in range(m_count):
        row = m_record(index)
        spell_id = row[M_SPELL]
        if not spell_id:
            continue
        quality = m_string(row[M_QUALITY]).replace("RE_QUALITY_", "").title()
        mask = row[M_CLASS_LO] | (row[M_CLASS_HI] << 32)
        spell = spells.get(spell_id)
        name = s_string(spell[F_NAME]) if spell else ""
        desc = s_string(spell[F_DESC]) if spell else ""

        status, effects, notes = judge(spell_id, spells, custom, scripted)
        teach = taught_spell(desc)
        if teach and status in ("needs-code", "standard"):
            # The server teaches this spell while the enchant is active (AscensionMysticEnchantRules TaughtSpells).
            t_status, _, _ = judge(teach, spells, custom, scripted)
            status = {"standard": "teaches-ok", "scripted": "teaches-ok", "missing": "teaches-missing",
                      "custom-db": "teaches-ok"}.get(t_status, "teaches-needs-code")
            notes = [f"teaches spell {teach} ({t_status})"]
        on_realm = bool(row[M_REALM_LIVE] or row[M_REALM_SEASONAL])
        if on_realm:
            tally[status] += 1
            by_quality[(quality, status)] += 1
        else:
            off_realm[status] += 1
        rows.append([spell_id, name, quality, classes(mask), "yes" if row[M_WORLDFORGED] else "",
                     "yes" if on_realm else "",
                     status, " ".join(effects), "; ".join(dict.fromkeys(notes)), desc.replace("\n", " ")])

    with open(os.path.join(out_dir, "enchants.csv"), "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["spell", "name", "quality", "classes", "worldforged", "this realm", "status", "effects", "notes",
                         "description"])
        writer.writerows(sorted(rows, key=lambda r: (r[5] != 'yes', r[6], r[2], r[1])))

    qualities = sorted({q for q, _ in by_quality})
    statuses = ["standard", "teaches-ok", "scripted", "needs-code", "teaches-needs-code", "unsupported",
                "teaches-missing", "custom-db", "missing"]
    on = sum(tally.values())
    lines = [f"Mystic Enchant audit: {len(rows)} enchants, {on} offered on a live seasonal realm "
             f"(the rest belong to other realm types and are never offered here)",
             f"Spell.dbc: {s_count} spells, {s_fields} fields per record; MysticEnchant.dbc: {m_fields} fields",
             db_note, ""]
    lines += ["On this realm:"] + [f"  {status:19} {tally[status]:6}" for status in statuses if tally[status]]
    lines += ["Other realm types (ignored):"] + [f"  {status:19} {off_realm[status]:6}" for status in statuses
                                                 if off_realm[status]]
    lines += ["", "By quality:", "  " + "quality".ljust(10) + "".join(s.replace("teaches-", "t-")[:12].rjust(13) for s in statuses)]
    for quality in qualities:
        lines.append("  " + quality.ljust(10) + "".join(str(by_quality[(quality, s)]).rjust(13) for s in statuses))
    lines += ["", "Class coverage on this realm (enchants usable by each class, 'all' counted for every class):"]
    for class_id, class_name in CLASS_NAMES.items():
        usable = sum(1 for r in rows if r[5] == "yes" and (r[3] == "all" or class_name in r[3].split()))
        lines.append(f"  {class_name:12} {usable}")
    other = sum(1 for r in rows if r[5] == "yes" and "class" in r[3])
    lines.append(f"  {'other ids':12} {other}  (class bits beyond the original classes)")
    text = "\n".join(lines) + "\n"
    with open(os.path.join(out_dir, "summary.txt"), "w", encoding="utf-8") as handle:
        handle.write(text)
    print(text)
    print(f"Wrote {os.path.join(out_dir, 'summary.txt')} and enchants.csv")


if __name__ == "__main__":
    main()
