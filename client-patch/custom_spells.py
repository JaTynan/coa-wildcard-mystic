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
AMBUSH = 9990004
VOODOO = 9990005
VOODOO_BURST = 9990006
VOODOO_COOLDOWN = 9990007
RADIANT = 9990008

DUMMY, MOD_INCREASE_SPEED, MOD_POWER_COST_PCT, MOD_DAMAGE_PERCENT_DONE, MOD_DAMAGE_PERCENT_TAKEN, \
    MOD_HEALTH_REGEN_PERCENT, MOD_HEALING_DONE_PERCENT, HASTE_ALL = 4, 31, 72, 79, 87, 88, 136, 193  # aura types
PASSIVE = 0x80000040  # can't be cancelled, and passive: never shown on the buff bar
# The next ability: any spell hit (melee, ranged, magic or none damage class; harmful or helpful), not auto attacks
NEXT_ABILITY = 0x10 | 0x100 | 0x400 | 0x1000 | 0x4000 | 0x10000
ALL_SCHOOLS = 127
HIDE_DURATION = 0x400  # AttributesEx5 (column 9): the client shows no timer

# Our own rows in the client's SpellIcon.dbc: pictures that are in the game (items use them) but not in its spell-icon
# list. IDs 9990001 and up are free there (the client's highest is 954750). Only the client needs them.
ICON_BANNER_DRAENEI = 9990001
ICONS = {
    ICON_BANNER_DRAENEI: 'Interface\\Icons\\inv_misc_tournaments_banner_draenei',
}

# id -> name, description, aura text, icon id (SpellIcon.dbc), max stack, effects [(aura, amount per stack, misc)],
# and optionally {column: value} for anything else. Every one lasts until the server removes it (it sets a timer where
# one is needed).
SPELLS = {
    PLAINSRUNNING: ('Plainsrunning',
                    'While you keep moving on foot, your running speed builds over 60 sec up to your level + 40% '
                    '(100% at level 60), on top of other speed effects. When you stop it drains in 6 sec. Not while '
                    'mounted; held while carrying a flag.',
                    'Running faster. The number is your bonus running speed in percent.',
                    3542, 100, [(DUMMY, 0, 0)]),  # Interface\Icons\Achievement_Zone_ArathiHighlands_01
    BLOODRUSH: ('Bloodrush',
                'For each enemy in combat with you, +2% damage and +2% haste, up to 5 enemies. Each killing blow '
                'gives +30% movement speed for 6 sec. The stacks go out of combat.',
                'Damage and haste increased by $s1%. One stack per enemy in combat with you.',
                6200, 5, [(MOD_DAMAGE_PERCENT_DONE, 2, ALL_SCHOOLS), (HASTE_ALL, 2, 0)]),  # achievement_bg_interruptx_flagcapture_attempts_1game
    BLOODRUSH_SPEED: ('Bloodrush',
                      'Movement speed increased by 30% for 6 sec after a killing blow.',
                      'Movement speed increased by $s1%.',
                      516, 0, [(MOD_INCREASE_SPEED, 30, 0)]),  # Ability_Rogue_Sprint
    AMBUSH: ('Ambush',
             'Entering stealth readies your next ability: it costs 10% less and deals or heals 50% more. At most once '
             'every 20 sec.',
             'Your next ability costs 10% less and deals or heals 50% more.',
             3701, 0, [(MOD_DAMAGE_PERCENT_DONE, 50, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 50, 0),
                       (MOD_POWER_COST_PCT, -10, ALL_SCHOOLS)],
             {34: NEXT_ABILITY, 35: 100, 36: 1}),  # achievement_profession_fishing_findfish; one charge
    VOODOO: ('Voodoo Regeneration',
             'Health regenerates 50% faster out of combat. In combat, regenerate 0.3% of maximum health per second '
             '(half while the burst is on cooldown). Below 35% health, regenerate 3% of maximum health per second '
             'for 8 sec, once every 2 min.',
             'Health regeneration increased by $s1% out of combat.',
             19697, 0, [(MOD_HEALTH_REGEN_PERCENT, 50, 0)], {4: PASSIVE}),
    VOODOO_BURST: ('Voodoo Regeneration',
                   'Regenerating 3% of maximum health per second for 8 sec.',
                   'Regenerating 3% of maximum health per second.',
                   19697, 0, [(DUMMY, 0, 0)]),  # inv_offhand_zulaman_d_01
    VOODOO_COOLDOWN: ('Voodoo Regeneration (cooldown)',
                      'The burst can\'t happen again until this ends, and in-combat regeneration is halved.',
                      'The burst is on cooldown; in-combat regeneration halved.',
                      3234, 0, [(DUMMY, 0, 0)]),  # achievement_dungeon_drak'tharon_heroic
    RADIANT: ('Radiant Presence',
              'In combat, the Draenei gains a stack of Light every 6 sec, up to 5. Each stack gives them and allies '
              'within 30 yards +1% damage and healing and 1% less damage taken. Fades 10 sec after combat. A second '
              'Draenei doesn\'t add more. Their auras and totems reach 50% further.',
              'Damage and healing done increased by $s1% and damage taken reduced by $s1% per stack of Light.',
              ICON_BANNER_DRAENEI, 5, [(MOD_DAMAGE_PERCENT_DONE, 1, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 1, 0),
                                       (MOD_DAMAGE_PERCENT_TAKEN, -1, ALL_SCHOOLS)],
              {9: HIDE_DURATION}),  # renewed every second while a Draenei is near
}

# spell_proc rows (charges used up by the next ability): id -> (ProcFlags, SpellTypeMask, SpellPhaseMask, Charges)
PROCS = {
    AMBUSH: (NEXT_ABILITY, 3, 2, 1),  # used by the next ability that deals damage or heals (not buffs); on hit
}

STRINGS = {136: 0, 170: 1, 187: 2}  # enUS name, description, aura text (index into the tuple above)
FLOAT_COLS = {47, 77, 78, 79, 101, 102, 103, 119, 120, 121, 216, 217, 218, 229, 230, 231}
# spell_dbc columns declared unsigned (AzerothCore's schema); the rest are signed.
UNSIGNED = set(range(1, 13)) | {14} | set(range(16, 41)) - {41} | set(range(42, 47)) | set(range(48, 52)) | {71, 72, 73} | \
    set(range(83, 101)) | set(range(104, 110)) | {116, 117, 118} | set(range(122, 136)) | {152, 169, 186, 203} | \
    set(range(204, 216)) | set(range(219, 224)) | {225, 226, 227, 232, 233}
ONE = struct.unpack('<I', struct.pack('<f', 1.0))[0]


def row(spell, fields=234, string_flags=0xFE0000FE):
    _, _, _, icon, stack, effects, *extra = SPELLS[spell]
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
    for col, v in (extra[0] if extra else {}).items():
        r[col] = v & 0xFFFFFFFF
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
    procs = sorted(PROCS)
    out.append("INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES " + ", ".join(f"('spell_proc', {i})" for i in procs) + ";")
    out.append("DELETE FROM `spell_proc` WHERE `SpellId` IN (" + ", ".join(map(str, procs)) + ");")
    out.append("INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, "
               "`SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, "
               "`DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES")
    out.append(",\n".join(f"({i}, 0, 0, 0, 0, 0, {f}, {s}, {ph}, 0, 0, 0, 0, 100, 0, {c})"
                          for i, (f, s, ph, c) in ((i, PROCS[i]) for i in procs)) + ";")
    return "\n".join(out) + "\n"


def icon_dbc(spell_icons):
    """The client's SpellIcon.dbc (a Dbc) with our ICONS rows added, as (rows, string_of) for dbc.write_dbc."""
    rows = [rec for i, rec in sorted(spell_icons.rows.items()) if i not in ICONS] + [(i, 0) for i in sorted(ICONS)]
    return rows, lambda rec, col: ICONS[rec[0]] if rec[0] in ICONS else spell_icons.string(spell_icons.rows[rec[0]][col])


if __name__ == '__main__':
    print(sql(), end='')
