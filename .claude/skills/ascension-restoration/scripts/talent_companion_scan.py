#!/usr/bin/env python3
"""Find Wildcard talents and abilities whose real effect sits in a hidden companion spell that nothing applies.

The pattern (issues #151 and #148, Nov 2026): Ascension moved part or all of a talent into a hidden spell
(often the talent's id + 800000, a 9xxxxx block, or a spell tagged "SLS") and applied it with its own server
code, which nobody has. The talent's own effects are then placeholders. The tooltip still quotes the companion
("$818710s1"), which is how this scan finds it.

For every rank spell a Wildcard Hero can roll (CharacterAdvancement.dbc, the same filter as the core's Wildcard
loader) the scan collects each spell the tooltip quotes, then checks whether anything applies it:
  - the talent's own effects (trigger fields), followed through spell_linked_spell, up to 3 steps;
  - spell_linked_spell in the core's base SQL, the core's modules and this repository's sql/;
  - aura links (coa_mystic_enchant_aura_link) and action-table casts (wcme_enchant_action) in this repository;
  - learnable (another roll), spell_learn_spell, spell_script_names;
  - the id written in C++ (core src, modules, this repository's patches/);
  - optional: the live world tables (InnoDB files) with --live, as a loose "mentioned" check.
What is left is classified:
  strong       passive aura, permanent, and same name, id + 800000, "SLS" tag or a known companion block
  probable     passive aura, permanent, none of those signs
  stock-data   companion id under 100000 (Blizzard data; stock scripts often handle these: check by hand)
  false-alarm  totems, items, rune enchants, glyph references
and flagged "duplicate" when the companion repeats an aura, value type and target mask the talent already has
(linking would double it).

A row is a lead, not a verdict. Read the talent and companion (spell data, tooltip) before fixing; never copy
tooltip text into this repository.

Usage (read-only):
  python3 -I talent_companion_scan.py --dbc "<server>/Data/dbc" --core ~/upstream/core-ref --repo . \
      [--live "<server>/mysql/data/acore_world_wildcard"] [--out talent-companions.csv]
"""
import argparse
import collections
import csv
import os
import re
import struct
import sys


def load_dbc(path):
    data = open(path, "rb").read()
    _, count, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
    base = 20 + count * size

    def text(offset):
        if not 0 <= offset < strings:   # CharacterAdvancement.dbc keeps a real string at offset 0
            return ""
        end = data.index(b"\0", base + offset)
        return data[base + offset:end].decode("utf-8", "replace")

    rows = [struct.unpack_from("<%dI" % fields, data, 20 + i * size) for i in range(count)]
    return rows, text


def sql_values(text, table):
    """Rows of every INSERT INTO table ... VALUES, respecting quotes and parentheses in strings."""
    text = re.sub(r"--[^\n]*", "", text)
    out = []
    for match in re.finditer(r"INSERT\s+(?:IGNORE\s+)?INTO\s+`?%s`?\s*(\([^)]*\))?\s*VALUES" % table, text, re.I):
        i, quoted, row, cur = match.end(), False, None, ""
        while i < len(text):
            ch = text[i]
            if quoted:
                if ch == "\\":
                    cur += text[i:i + 2]
                    i += 2
                    continue
                if ch == "'":
                    if text[i + 1:i + 2] == "'":
                        cur += "'"
                        i += 2
                        continue
                    quoted = False
                else:
                    cur += ch
            elif ch == "'":
                quoted = True
            elif ch == ";":
                break
            elif ch == "(" and row is None:
                row, cur = [], ""
            elif ch == "," and row is not None:
                row.append(cur.strip())
                cur = ""
            elif ch == ")" and row is not None:
                row.append(cur.strip())
                out.append(row)
                row, cur = None, ""
            elif row is not None:
                cur += ch
            i += 1
    return out


def files(top, suffixes, skip=lambda name: False):
    for root, _, names in os.walk(top):
        for name in names:
            if name.endswith(suffixes) and not skip(name):
                yield os.path.join(root, name)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dbc", required=True, help="folder with Spell.dbc, CharacterAdvancement.dbc, SpellDuration.dbc")
    ap.add_argument("--core", required=True, help="unpatched core checkout at the pinned commit")
    ap.add_argument("--repo", default=".", help="this repository")
    ap.add_argument("--live", help="optional: the live world database folder (acore_world_wildcard, *.ibd)")
    ap.add_argument("--out", help="CSV to write (default: print a summary only)")
    args = ap.parse_args()

    spells, text = load_dbc(os.path.join(args.dbc, "Spell.dbc"))
    sp = {r[0]: r for r in spells}
    name = lambda i: text(sp[i][136]) if i in sp else ""
    rank = lambda i: text(sp[i][153]) if i in sp else ""
    durations = {}
    for r in load_dbc(os.path.join(args.dbc, "SpellDuration.dbc"))[0]:
        d = r[1] - (1 << 32) if r[1] >= 1 << 31 else r[1]
        durations[r[0]] = d

    # The Wildcard roll pool, as the core's AscensionWildcard LoadTables() filters it.
    adv, adv_text = load_dbc(os.path.join(args.dbc, "CharacterAdvancement.dbc"))
    pool, learnable = {}, set()
    for r in adv:
        kind = adv_text(r[1])
        for v in r[5:14]:
            if v:
                learnable.add(v)
        if kind not in ("Talent", "Ability", "TalentAbility"):
            continue
        if ((r[121] >> 8) & 0xFF) != 1 or (r[120] & 0x1000000) or r[0] > 0xFFFFF:
            continue
        for v in r[5:10]:
            if v:
                pool[v] = (r[0], kind)

    linked, scripted, learned, granted = collections.defaultdict(set), set(), set(), set()
    sql = [os.path.join(args.core, "data/sql/base/db_world", f) for f in
           ("spell_linked_spell.sql", "spell_script_names.sql", "spell_learn_spell.sql")]
    sql += list(files(os.path.join(args.repo, "sql"), (".sql",)))
    sql += list(files(os.path.join(args.core, "modules"), (".sql",), lambda n: "_dbc" in n))
    for path in sql:
        if not os.path.exists(path):
            continue
        body = open(path, encoding="utf-8", errors="replace").read()
        for row in sql_values(body, "spell_linked_spell"):
            try:
                linked[abs(int(row[0]))].add(abs(int(row[1])))
            except (ValueError, IndexError):
                pass
        for row in sql_values(body, "spell_script_names"):
            try:
                scripted.add(abs(int(row[0])))
            except (ValueError, IndexError):
                pass
        for row in sql_values(body, "spell_learn_spell"):
            try:
                learned.add(int(row[1]))
            except (ValueError, IndexError):
                pass
        for row in sql_values(body, "coa_mystic_enchant_aura_link"):   # (enchant, auras, grant, comment)
            try:
                granted.add(int(row[2]))
            except (ValueError, IndexError):
                pass
        for row in sql_values(body, "wcme_enchant_action"):   # cast actions name the spells they cast
            if len(row) > 9 and row[8] in ("cast_self", "cast_target"):
                granted.update(int(x) for x in row[9].split() if x.isdigit())
    in_code = set()
    for top in (os.path.join(args.core, "src"), os.path.join(args.core, "modules"), os.path.join(args.repo, "patches")):
        for path in files(top, (".cpp", ".h", ".ps1", ".patch")):
            in_code.update(int(x) for x in re.findall(r"\b(\d{4,7})\b", open(path, errors="replace").read()))
    live = set()
    if args.live:
        for table in ("coa_mystic_enchant_proc", "coa_mystic_enchant_aura_link", "spell_linked_spell", "spell_proc"):
            path = os.path.join(args.live, table + ".ibd")
            if os.path.exists(path):
                raw = open(path, "rb").read()
                for o in range(len(raw) - 4):
                    v = struct.unpack_from(">I", raw, o)[0]
                    for w in (v, v ^ 0x80000000):
                        if 1000 <= w <= 9999999:
                            live.add(w)

    def reach(spell, depth=0, seen=None):
        seen = set() if seen is None else seen
        if spell not in sp or spell in seen or depth > 3:
            return seen
        seen.add(spell)
        for e in range(3):
            if sp[spell][116 + e]:
                reach(sp[spell][116 + e], depth + 1, seen)
        for c in linked.get(spell, ()):
            reach(c, depth + 1, seen)
        return seen

    def effects(spell):
        r = sp[spell]
        return [(r[95 + e], r[110 + e], (r[122 + 3 * e], r[123 + 3 * e], r[124 + 3 * e])) for e in range(3) if r[71 + e]]

    def summary(spell):
        r = sp[spell]
        return " ".join("e%d:effect%d/aura%d/misc%d/mask%x,%x,%x" % (e, r[71 + e], r[95 + e], r[110 + e],
                        r[122 + 3 * e], r[123 + 3 * e], r[124 + 3 * e]) for e in range(3) if r[71 + e])

    quote = re.compile(r"\$(?:[/*][\d.]+;)?(\d{3,})[a-zA-Z]")
    false_alarm = re.compile(r"Totem|^Create |^Rune of|Dancing Rune Weapon", re.I)
    blocks = re.compile(r"Stun Reduction|Fear Dur|Spell Reach|Generic Capstone", re.I)
    rows = []
    for t in sorted(pool):
        if t not in sp:
            continue
        reached = reach(t)
        # Text greyed out in the tooltip (|cFFAAAAAA ... |r) describes a rank not yet reached, such as a capstone
        # below the final rank; its quotes do not belong to this rank.
        tip = re.sub(r"\|cFFAAAAAA.*?\|r", " ", text(sp[t][170]) + " " + text(sp[t][187]), flags=re.I | re.S)
        for c in sorted({int(m.group(1)) for m in quote.finditer(tip)} - {t}):
            if c not in sp or c in reached or c in learnable or c in learned or c in scripted or c in in_code \
                    or c in granted:
                continue
            r = sp[c]
            kinds = [r[71 + e] for e in range(3) if r[71 + e]]
            passive = bool(r[4] & 0x40) and bool(kinds) and all(k in (6, 35, 65, 143) for k in kinds) \
                and (r[40] == 0 or durations.get(r[40], -1) == -1)
            tag = name(c) + " " + rank(c)
            if false_alarm.search(name(t)) or (name(c).startswith("Glyph of") and not name(t).startswith("Glyph")):
                cls = "false-alarm"
            elif not passive:
                continue
            elif c < 100000:
                cls = "stock-data"
            elif re.search(r"\bsls\b", tag, re.I) or c == t + 800000 or name(c).lower() == name(t).lower() \
                    or blocks.search(tag):
                cls = "strong"
            else:
                cls = "probable"
            mine = {(a, m, k) for a, m, k in effects(t) if a not in (0, 4, 42)}
            dup = any((a, m, k) in mine for a, m, k in effects(c))
            rows.append({"entry": pool[t][0], "type": pool[t][1], "talent_spell": t, "talent_name": name(t),
                         "talent_rank": rank(t), "companion_spell": c, "companion_name": name(c),
                         "companion_rank": rank(c), "class": cls, "duplicate": "yes" if dup else "",
                         "live_table_mention": "yes" if c in live else "", "companion_effects": summary(c),
                         "talent_effects": summary(t)})

    counts = collections.Counter(r["class"] for r in rows)
    entries = collections.defaultdict(set)
    for r in rows:
        entries[r["class"]].add(r["entry"])
    print("%d rank spells in the Wildcard pool; %d unapplied tooltip companions." % (len(pool), len(rows)))
    for cls in ("strong", "probable", "stock-data", "false-alarm"):
        print("  %-12s %4d rows, %3d entries" % (cls, counts[cls], len(entries[cls])))
    if args.out:
        with open(args.out, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]) if rows else ["entry"])
            writer.writeheader()
            writer.writerows(rows)
        print("Wrote", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
