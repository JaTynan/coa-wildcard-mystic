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
BARRIER_SHIELD = 9990009
BARRIER_PENALTY = 9990010
BARRIER_MINDSET = 9990011
POWER_SURGE = 9990012
# Spellbook entries for the signature racials (patches/62-racial-spellbook.ps1 teaches them): passive, they do nothing
# themselves; hovering one explains the racial.
BOOK_PLAINSRUNNING = 9990013
BOOK_BLOODRUSH = 9990014
BOOK_AMBUSH = 9990015
BOOK_VOODOO = 9990016
BOOK_RADIANT = 9990017
# Mystic Enchant helpers (sql/enchants/150 carries the server rows; scripts in mystic-enchants-scripts.patch)
TEMPORAL_STORE = 9990018    # Temporal Shift: a cancelled Temporal Blast's cast time, taken off the next one
HOT_HANDS_MARK = 9990019    # Hot Hands: +8% spell crit for the Mage whose Living Bomb is on the target
ABYSSAL_HUNGER = 9990020    # Feeding the Abyss: the hidden physical absorb that stores damage for Life Tap
SURGEONS_OATH = 9990021     # Dark Surgeon: 30% less healing taken
RESONANCE_PENALTY = {9990022: 28, 9990023: 88, 9990024: 76, 9990025: 84}  # Legacy of the Arcanist: Arcane, Fire,
# Frost and Nature Resonance lower the other three elements' damage by 30% (school masks of those three)
HIDDEN = 0x80000080  # can't be cancelled, and not shown on the buff bar
APOSTATE_HOLY_FIRE_HIT = 9990026  # Cauterizing Flames: Flames of the Apostate gives Holy Fire 6% more hit chance
SPELLMOD_RESIST_MISS_CHANCE = 16

ADD_FLAT_MODIFIER, MOD_CRIT_CHANCE_AGAINST_TARGET, SPELLMOD_CASTING_TIME = 107, 330, 10
SCHOOL_ABSORB, PHYSICAL, MOD_HEALING_PCT = 69, 1, 118
MOD_THREAT, PERIODIC_ENERGIZE, EFFECT_IMMUNITY, MANA_SHIELD, MOD_ATTACKER_MELEE_CRIT_CHANCE = 10, 24, 37, 97, 187
DUMMY, MOD_INCREASE_SPEED, MOD_POWER_COST_PCT, MOD_DAMAGE_PERCENT_DONE, MOD_DAMAGE_PERCENT_TAKEN, \
    MOD_HEALTH_REGEN_PERCENT, MOD_HEALING_DONE_PERCENT, HASTE_ALL = 4, 31, 72, 79, 87, 88, 136, 193  # aura types
PASSIVE = 0x80000040  # can't be cancelled, and passive: never shown on the buff bar
# The next ability: any spell hit (melee, ranged, magic or none damage class; harmful or helpful), not auto attacks
NEXT_ABILITY = 0x10 | 0x100 | 0x400 | 0x1000 | 0x4000 | 0x10000
ALL_SCHOOLS = 127
MAGIC_SCHOOLS = 126  # every school but Physical
ONE = struct.unpack('<I', struct.pack('<f', 1.0))[0]  # 1.0 as a float column
HIDE_DURATION = 0x400  # AttributesEx5 (column 9): the client shows no timer
BOOK_PASSIVE = 0x80000050  # a spellbook passive like the stock racials (ability, passive, can't be cancelled)

# Our own rows in the client's SpellIcon.dbc: pictures that are in the game (items use them) but not in its spell-icon
# list. IDs 9990001 and up are free there (the client's highest is 954750). Only the client needs them.
ICON_BANNER_DRAENEI = 9990001
# The Elemental Rend icons (rend_icons.py makes them from the client's Rend icon; racials_off_gcd.py --icons adds them)
ICON_REND_FROST, ICON_REND_FIRE, ICON_REND_NATURE = 9990002, 9990003, 9990004
ICONS = {
    ICON_BANNER_DRAENEI: 'Interface\\Icons\\inv_misc_tournaments_banner_draenei',
    ICON_REND_FROST: 'Interface\\Icons\\wcme_rend_frost',
    ICON_REND_FIRE: 'Interface\\Icons\\wcme_rend_fire',
    ICON_REND_NATURE: 'Interface\\Icons\\wcme_rend_nature',
}
# Client spells that get one of our icons in place of their own: spell -> icon (both the icon and the active icon)
ICON_OVERRIDES = {
    978693: ICON_REND_FROST,   # Elemental Rend (Frost), Spell Shredder
    978694: ICON_REND_FIRE,    # Elemental Rend (Fire)
    978695: ICON_REND_NATURE,  # Elemental Rend (Nature)
}


def with_icon(row):
    """A client Spell.dbc row with its icon replaced if ICON_OVERRIDES lists it."""
    if row[0] not in ICON_OVERRIDES:
        return row
    row = list(row)
    row[133] = row[134] = ICON_OVERRIDES[row[0]]
    return tuple(row)

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
             '(half while the burst is on cooldown). Below 35% health, regenerate 28% of maximum health over '
             '5 sec, once every 2 min.',
             'Health regeneration increased by $s1% out of combat.',
             19697, 0, [(MOD_HEALTH_REGEN_PERCENT, 50, 0)], {4: PASSIVE}),
    VOODOO_BURST: ('Voodoo Regeneration',
                   'Regenerating 28% of maximum health over 5 sec.',
                   'Regenerating 28% of maximum health over 5 sec.',
                   19697, 0, [(DUMMY, 0, 0)]),  # inv_offhand_zulaman_d_01
    VOODOO_COOLDOWN: ('Voodoo Regeneration (cooldown)',
                      'The burst can\'t happen again until this ends, and in-combat regeneration is halved.',
                      'The burst is on cooldown; in-combat regeneration halved.',
                      3234, 0, [(DUMMY, 0, 0)]),  # achievement_dungeon_drak'tharon_heroic
    RADIANT: ('Radiant Presence',
              'In combat, the Draenei gains a stack of Light every 6 sec, up to 5. Each stack gives them and allies '
              'within 30 yards +1% damage and healing and 1% less damage taken. Fades 10 sec after combat. A second '
              'Draenei doesn\'t add more. Their auras and totems reach 50% further.',
              'Damage and healing done increased by $s1% and damage taken reduced by $s1%. Each stack of Light '
              'adds 1%.',
              ICON_BANNER_DRAENEI, 5, [(MOD_DAMAGE_PERCENT_DONE, 1, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 1, 0),
                                       (MOD_DAMAGE_PERCENT_TAKEN, -1, ALL_SCHOOLS)]),  # the server sets the timer
    # Mana-forged Barrier (patches/60-manaforged-barrier.ps1); icons from the stance (_D3energyarmor) and Power Surge
    BARRIER_SHIELD: ('Mana-forged Barrier',
                     'Absorbs up to 90% of damage taken, less as your mana runs low (half as much against magic), '
                     'draining 1 mana per point absorbed. Threat from Magic damage increased by 160%. Immune to '
                     'interrupts.',
                     'Absorbing damage with mana. Threat from Magic damage increased. Immune to interrupts.',
                     27330, 0, [(MANA_SHIELD, -1, ALL_SCHOOLS), (MOD_THREAT, 160, MAGIC_SCHOOLS), (EFFECT_IMMUNITY, 0, 68)],
                     {4: PASSIVE, 101: ONE}),  # infinite amount: the script sets each absorb; 1 mana per point
    BARRIER_PENALTY: ('Mana-forged Barrier',
                      'Damage done reduced by 30% and healing done by 40%. 6% less chance to be critically hit by '
                      'melee attacks.',
                      'Damage done reduced by 30% and healing done by 40%.',
                      27330, 0, [(MOD_DAMAGE_PERCENT_DONE, -30, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, -40, 0),
                                 (MOD_ATTACKER_MELEE_CRIT_CHANCE, -6, 0)], {4: PASSIVE}),
    BARRIER_MINDSET: ('Mana-forged Mindset',
                      'You are no longer in Mana-forged Barrier, but your damage and healing haven\'t returned to '
                      'normal yet.',
                      'Damage done reduced by 20% and healing done by 10%.',
                      27330, 0, [(MOD_HEALING_DONE_PERCENT, -10, 0), (MOD_DAMAGE_PERCENT_DONE, -20, ALL_SCHOOLS)]),
    POWER_SURGE: ('Power Surge',
                  'Restoring 30% of your missing mana over 4 sec.',
                  'Restoring mana.',
                  5356, 0, [(PERIODIC_ENERGIZE, 0, 0)], {98: 1000}),  # every 1 sec; the script sets the amount
    # Spellbook entries ("Racial Passive", RANKS below)
    BOOK_PLAINSRUNNING: ('Plainsrunning',
                         'While you keep moving on foot, your running speed builds over 60 sec up to your level + 40% '
                         '(100% at level 60), on top of other speed effects. When you stop, it drains in 6 sec. Not '
                         'while mounted; paused while carrying a battleground flag.',
                         '', 3542, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_BLOODRUSH: ('Bloodrush',
                     'For each enemy in combat with you, +2% damage and +2% haste, up to 5 enemies. Gone when combat '
                     'ends. Each killing blow also gives +30% movement speed for 6 sec.',
                     '', 6200, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_AMBUSH: ('Ambush',
                  'Entering stealth (Shadowmeld or a class stealth) readies your next ability: it costs 10% less and '
                  'deals or heals 50% more. At most once every 20 sec.',
                  '', 3701, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_VOODOO: ('Voodoo Regeneration',
                  'Health regenerates 50% faster out of combat. In combat, regenerate 0.3% of maximum health per '
                  'second (half while the burst is on cooldown). Below 35% health, regenerate 28% of maximum health '
                  'over 5 sec, once every 2 min.',
                  '', 19697, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_RADIANT: ('Radiant Presence',
                   'In combat, gain a stack of Light every 6 sec, up to 5. Each stack gives you and every ally within '
                   '30 yards (pets and guardians too) +1% damage and healing and 1% less damage taken. The Light '
                   'fades 10 sec after combat. A second Draenei doesn\'t add more. Your auras and totems reach 50% '
                   'further.',
                   '', ICON_BANNER_DRAENEI, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    TEMPORAL_STORE: ('Stored Time',
                     'Time stored from a cancelled Temporal Blast.',
                     'Your next Temporal Blast casts faster by the time you had already spent on the cancelled one.',
                     4828, 0, [(ADD_FLAT_MODIFIER, 0, SPELLMOD_CASTING_TIME)],
                     {122: 0x20000000, 208: 3, 36: 1}),  # Temporal Blast's class mask; one charge; the server sets the amount
    HOT_HANDS_MARK: ('Hot Hands',
                     'Spell critical strike chance against this target increased by 8% for the Mage whose Living Bomb is '
                     'on it.',
                     'Your Living Bomb\'s Mage has 8% more spell critical strike chance against you.',
                     3000, 0, [(MOD_CRIT_CHANCE_AGAINST_TARGET, 8, ALL_SCHOOLS)], {86: 6}),  # on the enemy; lasts as long as Living Bomb
    ABYSSAL_HUNGER: ('Abyssal Hunger',
                     'A chance equal to 10% plus your spell critical strike chance to fully absorb a physical hit and '
                     'store it for your next Life Tap.',
                     '', 4828, 0, [(SCHOOL_ABSORB, -1, PHYSICAL)], {4: PASSIVE}),  # hidden; the script decides each absorb
    SURGEONS_OATH: ('Dark Surgeon\'s Oath',
                    'Healing taken reduced by 30% while you are a Dark Surgeon.',
                    'Healing taken reduced by 30%.',
                    3836, 0, [(MOD_HEALING_PCT, -30, 0)], {4: PASSIVE}),  # hidden like a passive
}
SPELLS[APOSTATE_HOLY_FIRE_HIT] = ('Flames of the Apostate', 'Holy Fire has 6% more chance to hit.', '', 4828, 0,
                                  [(ADD_FLAT_MODIFIER, 6, SPELLMOD_RESIST_MISS_CHANCE)],
                                  {4: HIDDEN, 122: 0x100000, 208: 6})  # Holy Fire's class mask (Priest)
for _spell, _schools in RESONANCE_PENALTY.items():
    SPELLS[_spell] = ('Resonance', 'Damage with the other elements reduced by 30%.', '', 4828, 0,
                      [(MOD_DAMAGE_PERCENT_DONE, -30, _schools)], {4: HIDDEN})

# Spell charge categories the client shows for spells whose charges the server changes:
# category -> (maximum, recovery ms), and spell -> category (SpellChargesCategory.dbc / SpellCharges.dbc).
CHARGE_CATEGORIES = {9001: (3, 8000)}  # Dark Transfusion (spell_wcme_dark_transfusion)
CHARGE_LINKS = {978640: 9001}
RANKS = {spell: 'Racial Passive' for spell in (BOOK_PLAINSRUNNING, BOOK_BLOODRUSH, BOOK_AMBUSH, BOOK_VOODOO, BOOK_RADIANT)}

# spell_script_names rows: id -> script (in the server patch named next to the spell)
SCRIPTS = {
    BARRIER_SHIELD: 'spell_wcme_manaforged_barrier',  # patches/60-manaforged-barrier.ps1
    ABYSSAL_HUNGER: 'spell_wcme_abyssal_hunger',  # mystic-enchants-scripts.patch
}

# spell_proc rows (charges used up by the next ability): id -> (ProcFlags, SpellTypeMask, SpellPhaseMask, Charges)
PROCS = {
    # Used by the next ability that lands, whatever it does: damage and heals, and also spells that only apply an aura
    # (Renew, Corruption: they would otherwise keep the +50% on every cast, and buffs can't be told apart from them).
    AMBUSH: (NEXT_ABILITY, 7, 2, 1),
    ABYSSAL_HUNGER: (0x400 | 0x4000, 0, 1, 0),  # Life Tap casts: spends the stored damage
}

STRINGS = {136: 0, 170: 1, 187: 2}  # enUS name, description, aura text (index into the tuple above)
RANK_COL = 153  # enUS rank text (the line under the name in the spellbook)
FLOAT_COLS = {47, 77, 78, 79, 101, 102, 103, 119, 120, 121, 216, 217, 218, 229, 230, 231}
# spell_dbc columns declared unsigned (AzerothCore's schema); the rest are signed.
UNSIGNED = set(range(1, 13)) | {14} | set(range(16, 41)) - {41} | set(range(42, 47)) | set(range(48, 52)) | {71, 72, 73} | \
    set(range(83, 101)) | set(range(104, 110)) | {116, 117, 118} | set(range(122, 136)) | {152, 169, 186, 203} | \
    set(range(204, 216)) | set(range(219, 224)) | {225, 226, 227, 232, 233}


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
    if col == RANK_COL:
        return RANKS.get(spell, '')
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
    scripts = sorted(SCRIPTS)
    out.append("DELETE FROM `spell_script_names` WHERE `ScriptName` IN (" +
               ", ".join(f"'{SCRIPTS[i]}'" for i in scripts) + ");")
    out.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES " +
               ", ".join(f"({i}, '{SCRIPTS[i]}')" for i in scripts) + ";")
    return "\n".join(out) + "\n"


def icon_dbc(spell_icons):
    """The client's SpellIcon.dbc (a Dbc) with our ICONS rows added, as (rows, string_of) for dbc.write_dbc."""
    rows = [rec for i, rec in sorted(spell_icons.rows.items()) if i not in ICONS] + [(i, 0) for i in sorted(ICONS)]
    return rows, lambda rec, col: ICONS[rec[0]] if rec[0] in ICONS else spell_icons.string(spell_icons.rows[rec[0]][col])


if __name__ == '__main__':
    print(sql(), end='')
