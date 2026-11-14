#!/usr/bin/env python3
"""Our own spells (buff icons for server-side features): the same row goes into the client's Spell.dbc (patch-ZZW.MPQ,
via build_client_patch.py and racials_off_gcd.py) and the server's spell_dbc table (sql/enchants/150-custom-spells.sql).

Usage: python3 custom_spells.py <Spell.dbc>   prints the SQL for sql/enchants/150-custom-spells.sql.
IDs 9990001 and up are free in the client's spell list.
"""
import struct
import sys

PLAINSRUNNING = 9990001
BLOODRUSH = 9990002
BLOODRUSH_SPEED = 9990003

DUMMY, MOD_INCREASE_SPEED, MOD_DAMAGE_PERCENT_DONE, HASTE_ALL = 4, 31, 79, 193  # aura types
ALL_SCHOOLS = 127

# id -> name, description, aura text, icon id (SpellIcon.dbc), max stack, effects [(aura, amount per stack, misc)].
# Every one lasts until the server removes it (it sets a timer where one is needed).
SPELLS = {
    PLAINSRUNNING: ('Plainsrunning',
                    'While you keep moving on foot, your running speed builds over 60 sec up to your level + 40% '
                    '(100% at level 60), on top of other speed effects. When you stop it drains in 6 sec. Not while '
                    'mounted; held while carrying a flag.',
                    'Running faster. The number is your bonus running speed in percent.',
                    3542, 100, [(DUMMY, 0, 0)]),  # Interface\Icons\Achievement_Zone_ArathiHighlands_01
    BLOODRUSH: ('Bloodrush',
                'For each enemy in combat with you, +2% damage and +2% haste, up to 5 enemies. Each killing blow '
                'gives +15% movement speed for 6 sec. Gone out of combat.',
                'Damage and haste increased by $s1%. One stack per enemy in combat with you.',
                86, 5, [(MOD_DAMAGE_PERCENT_DONE, 2, ALL_SCHOOLS), (HASTE_ALL, 2, 0)]),  # Ability_Racial_BloodRage
    BLOODRUSH_SPEED: ('Bloodrush',
                      'Movement speed increased by 15% after a killing blow.',
                      'Movement speed increased by $s1%.',
                      516, 0, [(MOD_INCREASE_SPEED, 15, 0)]),  # Ability_Rogue_Sprint
}

STRINGS = {136: 0, 170: 1, 187: 2}  # enUS name, description, aura text (index into the tuple above)
FLOAT_COLS = {47, 77, 78, 79, 101, 102, 103, 119, 120, 121, 216, 217, 218, 229, 230, 231}
# spell_dbc columns declared unsigned (AzerothCore's schema); the rest are signed.
UNSIGNED = set(range(1, 13)) | {14} | set(range(16, 41)) - {41} | set(range(42, 47)) | set(range(48, 52)) | {71, 72, 73} | \
    set(range(83, 101)) | set(range(104, 110)) | {116, 117, 118} | set(range(122, 136)) | {152, 169, 186, 203} | \
    set(range(204, 216)) | set(range(219, 224)) | {225, 226, 227, 232, 233}
ONE = struct.unpack('<I', struct.pack('<f', 1.0))[0]


def row(spell, fields=234, string_flags=0xFE0000FE):
    *_, icon, stack, effects = SPELLS[spell]
    r = [0] * fields
    r[0] = spell
    r[4] = 0x80000000          # can't be cancelled by right-click
    r[28] = 1                  # instant
    r[40] = 21                 # lasts until the server removes it
    r[46] = 1                  # self
    r[49] = stack              # stacks (each stack multiplies the amounts)
    r[68] = 0xFFFFFFFF         # no item requirement
    for i, (aura, amount, misc) in enumerate(effects):
        r[71 + i] = 6          # apply aura
        r[74 + i] = 1          # die sides: amount = base points + 1
        r[80 + i] = (amount - 1) & 0xFFFFFFFF
        r[86 + i] = 1          # on self
        r[95 + i] = aura
        r[110 + i] = misc
        r[216 + i] = ONE
    r[133] = icon
    r[213], r[225] = 1, 1
    for flags in (152, 169, 186, 203):
        r[flags] = string_flags
    return tuple(r)


def string_of(spell, col):
    texts = SPELLS[spell]
    return texts[STRINGS[col]] if col in STRINGS else ''


def sql(fields=234):
    def value(col, v, spell):
        if 136 <= col <= 203 and col not in (152, 169, 186, 203):
            return "'" + string_of(spell, col).replace("\\", "\\\\").replace("'", "''") + "'"
        if col in FLOAT_COLS:
            return repr(struct.unpack('<f', struct.pack('<I', v))[0])
        return str(v) if col in UNSIGNED else str(struct.unpack('<i', struct.pack('<I', v))[0])
    out = ["-- Our own spells: buff icons for server-side features (client-patch/custom_spells.py writes this file; the",
           "-- client patch carries the same rows). Safe to run again; 000-reset removes rows listed in wcme_owned first."]
    ids = sorted(SPELLS)
    out.append("INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES " + ", ".join(f"('spell_dbc', {i})" for i in ids) + ";")
    out.append("DELETE FROM `spell_dbc` WHERE `ID` IN (" + ", ".join(map(str, ids)) + ");")
    out.append("INSERT INTO `spell_dbc` VALUES")
    out.append(",\n".join("(" + ", ".join(value(c, v, i) for c, v in enumerate(row(i, fields))) + ")" for i in ids) + ";")
    return "\n".join(out) + "\n"


if __name__ == '__main__':
    print(sql(), end='')
