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


def off_gcd(row):
    """The row with no global cooldown: neither blocked by it (category 133) nor starting one."""
    if row[0] not in OFF_GCD:
        return row
    row = list(row)
    row[START_RECOVERY_CATEGORY] = row[START_RECOVERY_TIME] = 0
    return tuple(row)
