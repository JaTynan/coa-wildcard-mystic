#!/usr/bin/env python3
"""Exports the spell data needed to write Mystic Enchant fixes, in one small file to send back.

Usage:  python3 export_spell_data.py <dbc folder> [output file]
        e.g. python3 export_spell_data.py ~/coa-test/env/dist/data/dbc

Reads MysticEnchant.dbc and Spell.dbc and writes enchant-data.json.gz (a few MB) holding:
  spells  every field of each enchant spell, plus the spells they teach, fire or mention
  index   id, name, rank and spell family of every named spell (to match names in tooltips)
Nothing is changed.
"""
import gzip
import json
import os
import re
import struct
import sys

F_TRIGGER, F_NAME, F_RANK, F_DESC, F_TOOLTIP, F_FAMILY = 116, 136, 153, 170, 187, 208
M_SPELL = 1
REFERENCE = re.compile(r"(?:\$|@s:)(\d{2,8})")


def read_wdbc(path):
    with open(path, "rb") as handle:
        data = handle.read()
    magic, count, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
    if magic != b"WDBC":
        sys.exit(f"{path} is not a WDBC file")
    base = 20 + count * size

    def string(offset):
        if not 0 < offset < strings:
            return ""
        end = data.index(b"\0", base + offset)
        return data[base + offset:end].decode("utf-8", "replace")

    def record(i):
        return struct.unpack_from(f"<{size // 4}I", data, 20 + i * size)

    return count, record, string


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    dbc = os.path.expanduser(sys.argv[1])
    out = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else "~/enchant-data.json.gz")

    print("Reading Spell.dbc (209 MB, this takes a minute or two)...")
    count, record, string = read_wdbc(os.path.join(dbc, "Spell.dbc"))
    # Only record positions are kept for all 209,000 spells; full rows are unpacked when needed.
    position, index = {}, []
    for i in range(count):
        row = record(i)
        position[row[0]] = i
        name = string(row[F_NAME])
        if name:
            index.append([row[0], name, string(row[F_RANK]), row[F_FAMILY], row[F_FAMILY + 1],
                          row[F_FAMILY + 2], row[F_FAMILY + 3]])

    m_count, m_record, _ = read_wdbc(os.path.join(dbc, "MysticEnchant.dbc"))
    wanted = {m_record(i)[M_SPELL] for i in range(m_count)} - {0}

    def spell(spell_id):
        return record(position[spell_id]) if spell_id in position else None
    # Two rounds: the enchant spells, then what they teach, fire or mention, then the same again.
    for _ in range(2):
        more = set()
        for spell_id in wanted:
            row = spell(spell_id)
            if not row:
                continue
            more.update(t for t in row[F_TRIGGER:F_TRIGGER + 3] if t)
            for field in (F_DESC, F_TOOLTIP):
                more.update(int(m) for m in REFERENCE.findall(string(row[field])))
        wanted |= more

    export = {}
    for spell_id in sorted(wanted):
        row = spell(spell_id)
        if row:
            export[spell_id] = {"fields": list(row), "name": string(row[F_NAME]), "rank": string(row[F_RANK]),
                                "description": string(row[F_DESC]), "tooltip": string(row[F_TOOLTIP])}

    with gzip.open(out, "wt", encoding="utf-8") as handle:
        json.dump({"spells": export, "index": index}, handle, separators=(",", ":"))
    print(f"Wrote {out}: {len(export)} spells in full, {len(index)} names in the index "
          f"({os.path.getsize(out) // 1024} KB). Attach that file in the chat.")


if __name__ == "__main__":
    main()
