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
# Undead Grave Defiance (patches/72-racial-grave-defiance.ps1)
GRAVE_DEFIANCE = 9990027           # below 35% health: stacks = bonus damage and healing in percent
GRAVE_DEFIANCE_COOLDOWN = 9990028  # 45 sec after the bonus ends
GRAVE_GHOUL = 9990029              # risen as a ghoul for 10 sec
GRAVE_GHOUL_COOLDOWN = 9990030     # debuff: 10 min from rising, 2 min less per Cannibalize
BOOK_GRAVE_DEFIANCE = 9990031      # its spellbook entry
TRANSFORM = 56                     # aura: look like the creature in misc
RISEN_ALLY = 30230                 # Raise Ally's ghoul (creature), so the same four ghoul models
NO_IMMUNITIES = 0x20000000         # Attributes: shows over a shapeshift form's model too; immunities (Divine Shield, Ice
                                   # Block) don't strip it
DEBUFF = 0x04000000                # Attributes: shown and treated as a debuff (the stock Sated and Forbearance)
KEPT_THROUGH_DEATH = 0x00100000    # AttributesEx3 (column 7): death doesn't remove it
# Human Spellsword (patches/73-racial-spellsword.ps1): the server sets every amount
SPELLSWORD = 9990032               # the buff: at work
SPELLSWORD_IDLE = 9990033          # the buff when the build converts power, critical strike and hit already
SPELLSWORD_SPELL_POWER = 9990034   # hidden: spell damage, spell healing
SPELLSWORD_ATTACK_POWER = 9990035  # hidden: melee, ranged attack power
SPELLSWORD_SPELL_RATINGS = 9990036  # hidden: spell critical strike rating, spell hit rating
SPELLSWORD_MELEE_CRIT = 9990037    # hidden: melee, ranged critical strike rating
SPELLSWORD_MELEE_HIT = 9990038     # hidden: melee, ranged hit rating
BOOK_SPELLSWORD = 9990039          # its spellbook entry
MOD_DAMAGE_DONE, MOD_ATTACK_POWER, MOD_RANGED_ATTACK_POWER, MOD_HEALING_DONE, MOD_RATING = 13, 99, 124, 135, 189
CR_HIT_MELEE, CR_HIT_RANGED, CR_HIT_SPELL, CR_CRIT_MELEE, CR_CRIT_RANGED, CR_CRIT_SPELL = 5, 6, 7, 8, 9, 10
# Gnome Overclock (patches/74-racial-overclock.ps1)
OVERCLOCK = 9990040                # +5% maximum mana, rage and energy
OVERCLOCK_RUNIC = 9990041          # hidden: +5% maximum runic power
OVERCLOCK_STEPS = 9990042          # stacks = steps: costs 1% less, blood and unholy runes 1% faster per step
OVERCLOCK_STEPS_FROST = 9990043    # hidden, same stacks: frost runes 1% faster per step
OVERCLOCK_ESCAPE = 9990044         # Escape Artist: +60% movement speed for 3 sec
BOOK_OVERCLOCK = 9990045           # its spellbook entry
MOD_POWER_REGEN_PERCENT, MOD_INCREASE_ENERGY_PERCENT = 110, 132
POWER_MANA, POWER_RAGE, POWER_ENERGY, POWER_RUNE, POWER_RUNIC_POWER = 0, 1, 3, 5, 6
RUNE_BLOOD, RUNE_UNHOLY, RUNE_FROST = 0, 1, 2
# Blood Elf Arcane Hunger (patches/75-racial-arcane-hunger.ps1)
ARCANE_HUNGER = 9990046            # stacks: +1.5% damage and healing done (the server sets it), +2% ability costs each
BOOK_ARCANE_HUNGER = 9990047       # its spellbook entry
ARCANE_HUNGER_WARD = 9990048       # hidden: 0.5% less damage taken per stack (the server sets it)
# Dwarf Prospector's Spirit (patches/76-racial-prospectors-spirit.ps1): 3 stacks, 2 hours, kept through death
PROSPECT_MINING = 9990049          # +2% Stamina per stack
PROSPECT_HERBALISM = 9990050       # +2% Intellect and Spirit per stack
PROSPECT_SKINNING = 9990051        # +2% Strength and Agility per stack
PROSPECT_TREASURE = 9990052        # +2% damage and healing per stack
PROSPECT_FISHING = 9990053         # +3% running and swim speed per stack
PROSPECT_WATER_BREATHING = 9990054  # hidden: with 3 stacks of the fishing buff
BOOK_PROSPECTOR = 9990055          # its spellbook entry
# Orc Bloodrush's Rush (patches/56-racial-bloodrush.ps1): BLOODRUSH_SPEED's stacks
BLOODRUSH_RECKLESS = 9990056       # hidden: 2% more damage taken per stack of Rush (kept at Rush's stacks)
# Blood Elf Arcane Hunger (patches/75-racial-arcane-hunger.ps1): after Arcane Torrent
# Tauren Plainsrunning (patches/54-racial-plainsrunning.ps1): what group members near a running Tauren get
PLAINSRUNNING_HERD = 9990058       # stacks: the bonus running speed in percent (the server sets it)
# Night Elf Ambush (patches/57-racial-ambush.ps1): its 20 sec, shown
AMBUSH_RECHARGING = 9990059        # debuff while Ambush can't be readied again (the server sets the duration)
# Tauren War Stomp (patches/54-racial-plainsrunning.ps1): moving while it casts
PLAINSRUNNING_STOMPING = 9990060   # hidden: 80% slower while War Stomp casts
ARCANE_SATIATED = 9990057          # debuff: Arcane Hunger can't build for 15 sec (the server sets the duration)
MOD_INCREASE_SWIM_SPEED, WATER_BREATHING, MOD_SPEED_ALWAYS, MOD_TOTAL_STAT_PERCENTAGE = 58, 82, 129, 137
STAT_STRENGTH, STAT_AGILITY, STAT_STAMINA, STAT_INTELLECT, STAT_SPIRIT = 0, 1, 2, 3, 4

ADD_FLAT_MODIFIER, MOD_CRIT_CHANCE_AGAINST_TARGET, SPELLMOD_CASTING_TIME = 107, 330, 10
SCHOOL_ABSORB, PHYSICAL, MOD_HEALING_PCT = 69, 1, 118
MOD_DECREASE_SPEED = 33
# Spell visuals (column 131) for the racials' buffs (James chose them in game, 20 November). Existing client visuals,
# except VISUAL_AMBUSH_READY, which client-patch/visuals.py adds.
VISUAL_DEATH_WISH = 4599      # Rush: Death Wish's looping red hands (its flash, kit 4010, the server plays)
VISUAL_DARK_BANISH = 9652     # Risen Ghoul: Teleport Other's visual, whose looping part is Dark Banish (kit 7427)
VISUAL_ROCKET_BOOTS = 1223    # Escape Artist's speed: Gnomish Rocket Boots' fire hands and trail (kit 1164)
VISUAL_AMBUSH_READY = 9990101 # Ambush ready: the starlight hands without their beam sound (visuals.py)
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
ICON_SPELLSWORD, ICON_SPELLSWORD_IDLE = 9990005, 9990006  # Human Spellsword (James's picks, 14 November)
ICON_OVERCLOCK, ICON_OVERCLOCK_STEPS, ICON_ROCKET_BOOTS = 9990007, 9990008, 9990009  # Gnome Overclock (James's picks)
ICONS = {
    ICON_BANNER_DRAENEI: 'Interface\\Icons\\inv_misc_tournaments_banner_draenei',
    ICON_REND_FROST: 'Interface\\Icons\\wcme_rend_frost',
    ICON_REND_FIRE: 'Interface\\Icons\\wcme_rend_fire',
    ICON_REND_NATURE: 'Interface\\Icons\\wcme_rend_nature',
    ICON_SPELLSWORD: 'Interface\\Icons\\inv_sword_144',
    ICON_SPELLSWORD_IDLE: 'Interface\\Icons\\inv_axe_39',
    ICON_OVERCLOCK: 'Interface\\Icons\\inv_misc_enggizmos_23',
    ICON_OVERCLOCK_STEPS: 'Interface\\Icons\\achievement_bg_tophealer_wsg',
    ICON_ROCKET_BOOTS: 'Interface\\Icons\\inv_gizmo_rocketboot_destroyed_02',
}
# Client spells that get one of our icons in place of their own: spell -> icon (both the icon and the active icon)
ICON_OVERRIDES = {
    978693: ICON_REND_FROST,   # Elemental Rend (Frost), Spell Shredder
    978694: ICON_REND_FIRE,    # Elemental Rend (Fire)
    978695: ICON_REND_NATURE,  # Elemental Rend (Nature)
    20589: ICON_ROCKET_BOOTS,     # Escape Artist (Gnome racial; Overclock adds its speed)
    1120589: ICON_ROCKET_BOOTS,   # CoA's copies of Escape Artist
    830589: ICON_ROCKET_BOOTS,
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
                    'mounted; held while carrying a flag. Group members within 10 yards run with you at the same '
                    'bonus, and each other Tauren running with you builds yours faster (up to 4). War Stomp adds 30% '
                    'more for 5 sec, past your cap, and can be cast on the move.',
                    'Running faster. The number is your bonus running speed in percent.',
                    3542, 200, [(DUMMY, 0, 0)]),
    PLAINSRUNNING_STOMPING: ('War Stomp', 'Moving 80% slower while War Stomp casts.', '', 129, 0,
                             [(MOD_DECREASE_SPEED, -80, 0)], {4: HIDDEN}),  # Interface\Icons\Achievement_Zone_ArathiHighlands_01
    PLAINSRUNNING_HERD: ('Running with the Herd',
                         'Running with a Tauren: within 10 yards of a group member\'s Plainsrunning, you run faster by '
                         'as much as they do. On foot only.',
                         'Running with the herd. The number is your bonus running speed in percent.',
                         3542, 200, [(DUMMY, 0, 0)]),
    BLOODRUSH: ('Bloodrush',
                'For each enemy in combat with you, +2% damage, up to 5 enemies. The stacks go out of combat.',
                'Damage increased by $s1%. One stack per enemy in combat with you.',
                6200, 5, [(MOD_DAMAGE_PERCENT_DONE, 2, ALL_SCHOOLS)]),  # achievement_bg_interruptx_flagcapture_attempts_1game
    BLOODRUSH_SPEED: ('Rush',
                      'Each killing blow (and Blood Fury) adds a stack, up to 5, for 15 sec: 10% more movement speed on foot and 2% more '
                      'haste per stack, and 2% more damage taken. Each kill starts the 15 sec again.',
                      'Movement speed increased by $s1% and haste by $s2%. Damage taken increased by 2% per stack. '
                      'Another killing blow adds a stack and starts the 15 sec again.',
                      516, 5, [(MOD_SPEED_ALWAYS, 10, 0), (HASTE_ALL, 2, 0)], {131: VISUAL_DEATH_WISH}),  # Ability_Rogue_Sprint
    BLOODRUSH_RECKLESS: ('Rush', 'Damage taken increased by 2% per stack of Rush.', '', 516, 5,
                         [(MOD_DAMAGE_PERCENT_TAKEN, 2, ALL_SCHOOLS)], {4: HIDDEN}),
    AMBUSH: ('Ambush',
             'Entering stealth readies your next ability: it costs 10% less and deals or heals 50% more. At most once '
             'every 20 sec.',
             'Your next ability costs 10% less and deals or heals 50% more.',
             3701, 0, [(MOD_DAMAGE_PERCENT_DONE, 50, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 50, 0),
                       (MOD_POWER_COST_PCT, -10, ALL_SCHOOLS)],
             {34: NEXT_ABILITY, 35: 100, 36: 1, 131: VISUAL_AMBUSH_READY}),  # achievement_profession_fishing_findfish; one charge
    AMBUSH_RECHARGING: ('Ambush Recharging',
                        'Ambush was readied recently: entering stealth won\'t ready it again until this runs out.',
                        'Entering stealth won\'t ready Ambush again until this runs out.',
                        3701, 0, [(DUMMY, 0, 0)], {4: 0x80000000 | DEBUFF | NO_IMMUNITIES, 7: KEPT_THROUGH_DEATH}),
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
                         'while mounted; paused while carrying a battleground flag. Group members within 10 yards '
                         'run with you at the same bonus. Tauren build faster together: each other Tauren running in '
                         'your group within 10 yards adds the normal rate again, up to 4 (two reach full speed in 30 '
                         'sec, five in 12). War Stomp adds 30% more for 5 sec, past your cap: a running start or a '
                         'boost mid run. It can be cast on the move, at 80% less speed while it casts.',
                         '', 3542, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_BLOODRUSH: ('Bloodrush',
                     'Relentless but reckless. For each enemy in combat with you, +2% damage, up to 5 enemies, gone '
                     'when combat ends. Each killing blow adds a stack of Rush, up to 5, for 15 sec (each kill starts '
                     'the 15 sec again): per stack, 10% more movement speed on foot and 2% more haste, but you take 2% '
                     'more damage. Blood Fury adds a stack too.',
                     '', 6200, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_AMBUSH: ('Ambush',
                  'Entering stealth (Shadowmeld or a class stealth) readies your next ability: it costs 10% less and '
                  'deals or heals 50% more. At most once every 20 sec (Ambush Recharging shows the wait).',
                  '', 3701, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_VOODOO: ('Voodoo Regeneration',
                  'Health regenerates 50% faster out of combat. In combat, regenerate 0.3% of maximum health per '
                  'second (half while the burst is on cooldown). Below 35% health, regenerate 28% of maximum health '
                  'over 5 sec, once every 2 min. Berserking gives more haste the lower your health: 10% at full, '
                  'up to 30% at 40% health or lower.',
                  '', 19697, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_RADIANT: ('Radiant Presence',
                   'In combat, gain a stack of Light every 6 sec, up to 5. Each stack gives you and every ally within '
                   '30 yards (pets and guardians too) +1% damage and healing and 1% less damage taken. The Light '
                   'fades 10 sec after combat. A second Draenei doesn\'t add more. Gift of the Naaru fills your Light '
                   'to 5 at once. Your auras and totems reach 50% further.',
                   '', ICON_BANNER_DRAENEI, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    BOOK_GRAVE_DEFIANCE: ('Grave Defiance',
                          'Below 35% health, you deal and heal more, rising evenly to 30% more at 1% health (about 13% '
                          'at 20%, 22% at 10%). It lasts up to 15 sec, then can\'t start again for 45 sec. When a hit '
                          'would kill you, you rise as a ghoul for 10 sec instead, dealing and healing 30% less; the '
                          'ghoul can\'t die or be healed. A killing blow on an enemy worth experience or honor brings '
                          'you back at 20% health; otherwise you die when it ends. Rising works once every 10 min, '
                          'and each Cannibalize takes 2 min off the wait. Not from falling, lava or drowning, or '
                          'against your duel opponent.',
                          '', 4153, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    # Grave Defiance's buffs (the server sets every timer)
    GRAVE_DEFIANCE: ('Grave Defiance',
                     'Below 35% health, damage and healing done increased by up to 30% as your health falls. Lasts up '
                     'to 15 sec, then can\'t start again for 45 sec.',
                     'Damage and healing done increased. The number is the bonus in percent.',
                     4153, 30, [(MOD_DAMAGE_PERCENT_DONE, 1, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 1, 0)]),  # achievement_boss_devourerofsouls
    GRAVE_DEFIANCE_COOLDOWN: ('Grave Defiance (cooldown)',
                              'Grave Defiance has ended and can\'t start again until this runs out.',
                              'Grave Defiance can\'t start again until this runs out.',
                              13716, 0, [(DUMMY, 0, 0)], {7: KEPT_THROUGH_DEATH}),  # inv_helmet_168
    GRAVE_GHOUL: ('Risen Ghoul',
                  'Risen as a ghoul: damage and healing done reduced by 30%, and you can\'t die or be healed. A killing '
                  'blow on an enemy worth experience or honor brings you back at 20% health; otherwise you die when '
                  'this ends.',
                  'Risen as a ghoul. Land a killing blow to come back at 20% health, or die when this ends. Damage '
                  'and healing done reduced by 30%.',
                  3254, 0, [(MOD_DAMAGE_PERCENT_DONE, -30, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, -30, 0)],
                  {4: 0x80000000 | NO_IMMUNITIES, 131: VISUAL_DARK_BANISH}),  # achievement_dungeon_coablackdragonflight
    GRAVE_GHOUL_COOLDOWN: ('Grave Hunger',
                           'You can\'t rise as a ghoul again until this runs out (10 min). Each Cannibalize takes 2 min '
                           'off.',
                           'You can\'t rise as a ghoul again until this runs out. Cannibalize takes 2 min off.',
                           3254, 0, [(DUMMY, 0, 0)], {4: 0x80000000 | DEBUFF | NO_IMMUNITIES, 7: KEPT_THROUGH_DEATH}),
    BOOK_SPELLSWORD: ('Spellsword',
                      'The experimenter\'s race. For power (attack power against spell power), critical strike chance '
                      '(melee and ranged against spell) and hit chance (melee and ranged against spell), your weaker side '
                      'is raised 30% of the way towards your stronger side: with 2,000 attack power and 500 spell power, '
                      'you gain 450 spell power. Each of the three is skipped while your build already converts between '
                      'the two sides for it (Sheath of Light, Mental Quickness, Mental Dexterity and the like).',
                      '', ICON_SPELLSWORD, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    SPELLSWORD: ('Spellsword',
                 'Your weaker side is raised 30% of the way towards your stronger side, for power, critical strike '
                 'chance and hit chance. Skipped for any of the three your build already converts.',
                 'Your weaker side is raised 30% of the way towards your stronger side: power, critical strike and '
                 'hit. Your character sheet shows the result.',
                 ICON_SPELLSWORD, 0, [(DUMMY, 0, 0)]),
    SPELLSWORD_IDLE: ('Spellsword',
                      'Your build already converts between physical and spell power, critical strike and hit, so '
                      'Spellsword has nothing to add.',
                      'Your build already converts between physical and spell power, critical strike and hit, so '
                      'Spellsword has nothing to add.',
                      ICON_SPELLSWORD_IDLE, 0, [(DUMMY, 0, 0)]),
    SPELLSWORD_SPELL_POWER: ('Spellsword', 'Spell power raised.', '', ICON_SPELLSWORD, 0,
                             [(MOD_DAMAGE_DONE, 0, MAGIC_SCHOOLS), (MOD_HEALING_DONE, 0, ALL_SCHOOLS)], {4: HIDDEN}),
    SPELLSWORD_ATTACK_POWER: ('Spellsword', 'Attack power raised.', '', ICON_SPELLSWORD, 0,
                              [(MOD_ATTACK_POWER, 0, 0), (MOD_RANGED_ATTACK_POWER, 0, 0)], {4: HIDDEN}),
    SPELLSWORD_SPELL_RATINGS: ('Spellsword', 'Spell critical strike and hit rating raised.', '', ICON_SPELLSWORD, 0,
                               [(MOD_RATING, 0, 1 << CR_CRIT_SPELL), (MOD_RATING, 0, 1 << CR_HIT_SPELL)], {4: HIDDEN}),
    SPELLSWORD_MELEE_CRIT: ('Spellsword', 'Melee and ranged critical strike rating raised.', '', ICON_SPELLSWORD, 0,
                            [(MOD_RATING, 0, 1 << CR_CRIT_MELEE), (MOD_RATING, 0, 1 << CR_CRIT_RANGED)], {4: HIDDEN}),
    SPELLSWORD_MELEE_HIT: ('Spellsword', 'Melee and ranged hit rating raised.', '', ICON_SPELLSWORD, 0,
                           [(MOD_RATING, 0, 1 << CR_HIT_MELEE), (MOD_RATING, 0, 1 << CR_HIT_RANGED)], {4: HIDDEN}),
    BOOK_OVERCLOCK: ('Overclock',
                     'Gnomes learn their enemy and plan their next move. Maximum mana, rage, energy and runic power '
                     'increased by 5%. In combat Overclock boosts and cools down like an engine: every 5 sec another '
                     'step, up to 10, and after 10 sec at 10 steps it cools down and climbs again (one cycle a minute). '
                     'Each step makes abilities cost 1% less (whatever resource they use) and runes recharge 1% faster, '
                     'and tops up 1% of every resource you have. Out of combat the steps hold where they are, ready for '
                     'the next fight. Escape Artist also gives 60% more movement speed for 3 sec. Replaces Expansive '
                     'Mind.',
                     '', ICON_OVERCLOCK, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    OVERCLOCK: ('Overclock',
                'Maximum mana, rage, energy and runic power increased by 5%.',
                'Maximum mana, rage, energy and runic power increased by 5%.',
                ICON_OVERCLOCK, 0, [(MOD_INCREASE_ENERGY_PERCENT, 5, POWER_MANA),
                                    (MOD_INCREASE_ENERGY_PERCENT, 5, POWER_RAGE),
                                    (MOD_INCREASE_ENERGY_PERCENT, 5, POWER_ENERGY)], {4: HIDDEN, 7: KEPT_THROUGH_DEATH}),
    OVERCLOCK_RUNIC: ('Overclock', 'Maximum runic power increased by 5%.', '', ICON_OVERCLOCK, 0,
                      [(MOD_INCREASE_ENERGY_PERCENT, 5, POWER_RUNIC_POWER)], {4: HIDDEN, 7: KEPT_THROUGH_DEATH}),
    OVERCLOCK_STEPS: ('Overclock',
                      'Every 5 sec in combat, another step, up to 10; after 10 sec at 10 it cools down and climbs '
                      'again. Each step makes abilities cost 1% less and runes recharge 1% faster, and tops up 1% of '
                      'every resource. Out of combat the steps hold.',
                      'Abilities cost 1% less and runes recharge 1% faster for each step. The number is the steps.',
                      ICON_OVERCLOCK_STEPS, 10, [(MOD_POWER_COST_PCT, -1, ALL_SCHOOLS),
                                                 (MOD_POWER_REGEN_PERCENT, 1, POWER_RUNE),
                                                 (MOD_POWER_REGEN_PERCENT, 1, POWER_RUNE)],
                      {114: RUNE_BLOOD, 115: RUNE_UNHOLY}),  # MiscValueB of effects 2 and 3: the rune
    OVERCLOCK_STEPS_FROST: ('Overclock', 'Frost runes recharge 1% faster for each step.', '', ICON_OVERCLOCK_STEPS, 10,
                            [(MOD_POWER_REGEN_PERCENT, 1, POWER_RUNE)], {4: HIDDEN, 113: RUNE_FROST}),
    OVERCLOCK_ESCAPE: ('Escape Artist',
                       'Movement speed increased by 60% for 3 sec after Escape Artist.',
                       'Movement speed increased by $s1%.',
                       ICON_ROCKET_BOOTS, 0, [(MOD_INCREASE_SPEED, 60, 0)], {131: VISUAL_ROCKET_BOOTS}),
    BOOK_ARCANE_HUNGER: ('Arcane Hunger',
                         'Each ability or spell you use adds a stack of Arcane Hunger, up to 10. Per stack, abilities '
                         'deal and heal 1.5% more and cost 2% more, and you take 0.5% less damage (at 10: 15% more '
                         'damage and healing, 5% less damage taken, 20% more cost). Go 5 sec without using an ability '
                         'and the stacks fall off. Arcane Torrent eats every stack: '
                         'besides its usual effects, it restores 2% of every resource you have (mana, rage, energy, '
                         'runic power) per stack eaten, 20% at 10, and leaves you Satiated: no new stacks for 15 sec. '
                         'Arcane Torrent\'s cooldown is 1 min.',
                         '', 3384, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    ARCANE_HUNGER: ('Arcane Hunger',
                    'Each ability or spell adds a stack: abilities deal and heal 1.5% more and cost 2% more per stack, '
                    'and you take 0.5% less damage. Fades after 5 sec without using an ability. Arcane Torrent eats the '
                    'stacks for 2% of every resource each.',
                    'For each stack: damage and healing done increased by 1.5%, damage taken reduced by 0.5%, ability '
                    'costs increased by 2%. Fades after 5 sec without using an ability.',
                    3384, 10, [(MOD_DAMAGE_PERCENT_DONE, 0, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 0, 0),
                               (MOD_POWER_COST_PCT, 2, ALL_SCHOOLS)]),  # achievement_bg_wineos
    ARCANE_SATIATED: ('Satiated',
                      'After Arcane Torrent, your hunger for magic is sated: Arcane Hunger can\'t build for 15 sec.',
                      'Your hunger for magic is sated. Arcane Hunger can\'t build.',
                      87, 0, [(DUMMY, 0, 0)], {4: 0x80000000 | DEBUFF | NO_IMMUNITIES}),  # Arcane Torrent's icon
    ARCANE_HUNGER_WARD: ('Arcane Hunger', 'Damage taken reduced by 0.5% for each stack of Arcane Hunger.', '', 3384, 0,
                         [(MOD_DAMAGE_PERCENT_TAKEN, 0, ALL_SCHOOLS)], {4: HIDDEN}),
    BOOK_PROSPECTOR: ('Prospector\'s Spirit',
                      'Natural explorers: each kind of find gives its own buff, stacking up to 3 times and lasting 8 '
                      'hours (finding more adds a stack and starts the 8 hours again). Mining a vein: 2% more Stamina '
                      'per stack. Herbalism: 2% more Intellect and Spirit. Skinning: 2% more Strength and Agility. '
                      'Treasure, from opening a chest that Find Treasure shows or discovering a new area: 2% more damage '
                      'and healing. Fishing a catch: 3% more running and swim speed, and at 3 stacks you can breathe '
                      'underwater. Discovering a new area also gives 50% more experience.',
                      '', 12202, 0, [(DUMMY, 0, 0)], {4: BOOK_PASSIVE}),
    PROSPECT_MINING: ('Prospector\'s Spirit: Mining',
                      'Stamina increased by 2% per stack, up to 3. Mining another vein adds a stack and starts the 8 '
                      'hours again.',
                      'Stamina increased by $s1% per stack.',
                      12199, 3, [(MOD_TOTAL_STAT_PERCENTAGE, 2, STAT_STAMINA)], {7: KEPT_THROUGH_DEATH}),  # inv_elemental_eternal_earth
    PROSPECT_HERBALISM: ('Prospector\'s Spirit: Herbalism',
                         'Intellect and Spirit increased by 2% per stack, up to 3. Gathering another herb adds a stack and '
                         'starts the 8 hours again.',
                         'Intellect and Spirit increased by $s1% per stack.',
                         12201, 3, [(MOD_TOTAL_STAT_PERCENTAGE, 2, STAT_INTELLECT),
                                    (MOD_TOTAL_STAT_PERCENTAGE, 2, STAT_SPIRIT)], {7: KEPT_THROUGH_DEATH}),  # inv_elemental_eternal_life
    PROSPECT_SKINNING: ('Prospector\'s Spirit: Skinning',
                        'Strength and Agility increased by 2% per stack, up to 3. Skinning another creature adds a stack '
                        'and starts the 8 hours again.',
                        'Strength and Agility increased by $s1% per stack.',
                        12200, 3, [(MOD_TOTAL_STAT_PERCENTAGE, 2, STAT_STRENGTH),
                                   (MOD_TOTAL_STAT_PERCENTAGE, 2, STAT_AGILITY)], {7: KEPT_THROUGH_DEATH}),  # inv_elemental_eternal_fire
    PROSPECT_TREASURE: ('Prospector\'s Spirit: Treasure',
                        'Damage and healing done increased by 2% per stack, up to 3. Opening another chest that Find '
                        'Treasure shows, or discovering a new area, adds a stack and starts the 8 hours again.',
                        'Damage and healing done increased by $s1% per stack.',
                        12202, 3, [(MOD_DAMAGE_PERCENT_DONE, 2, ALL_SCHOOLS), (MOD_HEALING_DONE_PERCENT, 2, 0)],
                        {7: KEPT_THROUGH_DEATH}),  # inv_elemental_eternal_shadow
    PROSPECT_FISHING: ('Prospector\'s Spirit: Fishing',
                       'Running speed on foot and swim speed increased by 3% per stack, up to 3; at 3 stacks you can '
                       'also breathe underwater. Another catch adds a stack and starts the 8 hours again.',
                       'Running and swim speed increased by $s1% per stack. At 3 stacks you can breathe underwater.',
                       12203, 3, [(MOD_SPEED_ALWAYS, 3, 0), (MOD_INCREASE_SWIM_SPEED, 3, 0)],
                       {7: KEPT_THROUGH_DEATH}),  # inv_elemental_eternal_water
    PROSPECT_WATER_BREATHING: ('Prospector\'s Spirit: Fishing', 'You can breathe underwater.', '', 12203, 0,
                               [(WATER_BREATHING, 0, 0)], {4: HIDDEN, 7: KEPT_THROUGH_DEATH}),
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
RANKS = {spell: 'Racial Passive' for spell in (BOOK_PLAINSRUNNING, BOOK_BLOODRUSH, BOOK_AMBUSH, BOOK_VOODOO, BOOK_RADIANT,
                                               BOOK_GRAVE_DEFIANCE, BOOK_SPELLSWORD, BOOK_OVERCLOCK,
                                               BOOK_ARCANE_HUNGER, BOOK_PROSPECTOR)}

# Rows we used to add and still delete, so servers that ran an older file lose them
RETIRED_PROCS = [ABYSSAL_HUNGER]
RETIRED_SCRIPTS = ['spell_wcme_abyssal_hunger']
# Comment lines at the end of the SQL file
NOTES = ["-- Abyssal Hunger (9990020) keeps its spell row (the client patch has it) but nothing applies it since review 2026-11-18:",
         "-- Feeding the Abyss is the core's own."]

# spell_script_names rows: id -> script (in the server patch named next to the spell)
SCRIPTS = {
    BARRIER_SHIELD: 'spell_wcme_manaforged_barrier',  # patches/60-manaforged-barrier.ps1
}

# spell_proc rows (charges used up by the next ability): id -> (ProcFlags, SpellTypeMask, SpellPhaseMask, Charges)
PROCS = {
    # Used by the next ability that lands, whatever it does: damage and heals, and also spells that only apply an aura
    # (Renew, Corruption: they would otherwise keep the +50% on every cast, and buffs can't be told apart from them).
    AMBUSH: (NEXT_ABILITY, 7, 2, 1),
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
    out.append("DELETE FROM `spell_proc` WHERE `SpellId` IN (" + ", ".join(map(str, sorted(procs + RETIRED_PROCS))) + ");")
    out.append("INSERT INTO `spell_proc` (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, "
               "`SpellFamilyMask2`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, "
               "`DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`) VALUES")
    out.append(",\n".join(f"({i}, 0, 0, 0, 0, 0, {f}, {s}, {ph}, 0, 0, 0, 0, 100, 0, {c})"
                          for i, (f, s, ph, c) in ((i, PROCS[i]) for i in procs)) + ";")
    scripts = sorted(SCRIPTS)
    out.append("DELETE FROM `spell_script_names` WHERE `ScriptName` IN (" +
               ", ".join(f"'{name}'" for name in [SCRIPTS[i] for i in scripts] + RETIRED_SCRIPTS) + ");")
    out.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES " +
               ", ".join(f"({i}, '{SCRIPTS[i]}')" for i in scripts) + ";")
    out += NOTES
    return "\n".join(out) + "\n"


def icon_dbc(spell_icons):
    """The client's SpellIcon.dbc (a Dbc) with our ICONS rows added, as (rows, string_of) for dbc.write_dbc."""
    rows = [rec for i, rec in sorted(spell_icons.rows.items()) if i not in ICONS] + [(i, 0) for i in sorted(ICONS)]
    return rows, lambda rec, col: ICONS[rec[0]] if rec[0] in ICONS else spell_icons.string(spell_icons.rows[rec[0]][col])


if __name__ == '__main__':
    print(sql(), end='')
