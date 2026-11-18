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
