"""Racial abilities taken off the global cooldown. The server makes the same change (patches/52-racials.ps1); the
client needs it too, because the client itself refuses a spell while the global cooldown runs.

Most racials are already off it. These were not: Will of the Forsaken and Gift of the Naaru could not be used while
the global cooldown ran, and Cannibalize started one. Every copy of each (CoA keeps several) is listed.
"""

OFF_GCD = [
    7744, 667803, 807744, 807745, 1107744,  # Will of the Forsaken
    20577, 1120577,  # Cannibalize
    28880, 59542, 59543, 59544, 59545, 59547, 59548, 814280, 814281, 814282,  # Gift of the Naaru
    1128880, 1159542, 1159543, 1159544, 1159545, 1159547, 1159548,
]

START_RECOVERY_CATEGORY, START_RECOVERY_TIME = 205, 206
RECOVERY_TIME = 29
INTERRUPT_FLAGS = 31
INTERRUPT_ON_MOVEMENT = 0x01

# Racials that can be cast while moving (the server makes the same change at start-up, while the racial's setting is
# on). Tauren Plainsrunning (patches/54-racial-plainsrunning.ps1): War Stomp, every player copy CoA keeps.
MOVABLE = {20549, 46026, 1120549, 1146026}

# Stock spell texts the race kits change, spell -> {column: text} (170 the description, 187 the buff's text). Troll
# Berserking scales with missing health (patches/58-racial-voodoo-regeneration.ps1), every player copy CoA keeps.
BERSERKING_TEXT = ('Increases your attack and casting speed by 10% to 30% for $d, more the lower your health: 10% at full '
                   'health, 1% more for every 3% missing, up to 30% at 40% health or lower. Does not stack with other '
                   'similar cast speed increasing effects.')
TEXTS = {26297: {170: BERSERKING_TEXT}, 1126297: {170: BERSERKING_TEXT}}

# Dwarf Stoneform (patches/89-racial-stoneform.ps1): its buff lasts 10 sec and gives +20% armour, 20% less chance to be
# critically hit and resistance to every magic school worth about 8% less spell damage; 2 min cooldown. Both copies say
# so (CoA's own text left out the critical strike part).
STONEFORM_TEXT = ('Instantly removes all poison, disease and bleed effects. In addition, for 10 sec your armor is '
                  'increased by 20%, your chance to be critically hit is reduced by 20% and your resistance to all '
                  'magic schools is increased, for about 8% less spell damage taken.')
STONEFORM_BUFF = ('Armor increased by 20%. Chance to be critically hit reduced by 20%. Resistance to all magic schools '
                  'increased.')
TEXTS.update({spell: {170: STONEFORM_TEXT} for spell in (20594, 1120594)})
TEXTS.update({spell: {170: STONEFORM_TEXT, 187: STONEFORM_BUFF} for spell in (65116, 1165116)})

# Stock spell values the race kits change, spell -> {column: value}. Stoneform: the buff lasts 10 sec (duration 1),
# the classless buff's armour is +20% (base points 19, as the stock copy already has), and the classless cleanse has
# the stock copy's 2 min cooldown.
EFFECT_BASE_POINTS, DURATION = 80, 40
VALUES = {1165116: {EFFECT_BASE_POINTS: 19, DURATION: 1}, 65116: {DURATION: 1}, 1120594: {RECOVERY_TIME: 120000}}

# Troll: the stock Regeneration passive (20555 and CoA's copy 1120555) is hidden, since Voodoo Regeneration replaces it
# (patches/58-racial-voodoo-regeneration.ps1 already takes its effect away): "do not display" keeps it out of the
# spellbook, so only Voodoo Regeneration shows there, with the same icon.
ATTRIBUTES, DO_NOT_DISPLAY = 4, 0x80
VALUES.update({spell: {ATTRIBUTES: 0x50 | DO_NOT_DISPLAY} for spell in (20555, 1120555)})

# Undead Cannibalize (patches/72-racial-grave-defiance.ps1): a 2.5 sec channel (duration 66) healing 2% every half
# second (amplitude 500, base points 1), then Gorged; each tick is a Grave Feast charge.
AMPLITUDE = 98
VALUES[20578] = {DURATION: 66, AMPLITUDE: 500, EFFECT_BASE_POINTS: 1}
CANNIBALIZE_TEXT = ('Feed on a nearby Humanoid or Undead corpse for 2.5 sec, regenerating 2% of total health, mana, '
                    'rage, energy and runic power every 0.5 sec. Feeding to the end leaves you Gorged: 3% of total health every second for 10 sec, which '
                    'moving and fighting don\'t interrupt. Any movement, action or damage taken stops the feeding. '
                    'Each tick of feeding adds a charge of Grave Feast.')
TEXTS.update({spell: {170: CANNIBALIZE_TEXT} for spell in (20577, 1120577)})
TEXTS[20578] = {187: 'Restoring $s1% of total health and resources every $t1 sec.'}

# Racial cooldowns changed by the race kits (the server makes the same change at start-up, while the racial's setting
# is on): spell -> cooldown in ms. Blood Elf Arcane Hunger (patches/75-racial-arcane-hunger.ps1): Arcane Torrent 1 min
# instead of 2, every player copy CoA keeps.
COOLDOWNS = {spell: 60000 for spell in (28730, 50613, 814286, 814287, 814288, 814289, 814290, 814291, 814292, 1125046,
                                        1125047, 1128730, 1150613)}


def off_gcd(row):
    """The row with no global cooldown: neither blocked by it (category 133) nor starting one."""
    if row[0] not in OFF_GCD:
        return row
    row = list(row)
    row[START_RECOVERY_CATEGORY] = row[START_RECOVERY_TIME] = 0
    return tuple(row)


def cooldowns(row):
    """The row with its cooldown from COOLDOWNS, if listed."""
    if row[0] not in COOLDOWNS:
        return row
    row = list(row)
    row[RECOVERY_TIME] = COOLDOWNS[row[0]]
    return tuple(row)


def movable(row):
    """The row without the movement interrupt, if listed in MOVABLE: the client lets it be cast on the move."""
    if row[0] not in MOVABLE:
        return row
    row = list(row)
    row[INTERRUPT_FLAGS] &= ~INTERRUPT_ON_MOVEMENT
    return tuple(row)


def text(spell, col, default):
    """A stock spell's text: ours from TEXTS if listed, else the client's own."""
    return TEXTS.get(spell, {}).get(col, default)


def values(row):
    """The row with its numbers from VALUES, if listed."""
    if row[0] not in VALUES:
        return row
    row = list(row)
    for col, value in VALUES[row[0]].items():
        row[col] = value
    return tuple(row)
