"""Spell texts the client patch changes so a tooltip says what the server does, spell -> {column: text}
(170 the description, 187 the buff's text). Read by racials.text() through racials.TEXTS. Our own wording only.

Blessing of the Divines (talent 273020, sql/enchants/173-blessing-of-the-divines-talent.sql) casts one of five
blessings. Three of their tooltips promised more than the server gives. James, 28 Nov 2026: fix the tooltips to
match the spell data. The numbers below are the core's own sums (SpellEffectInfo::CalcValue: base points, plus the
per-level points times levels above the higher of base level and spell level, plus a roll of 1 to the die sides;
Unit::SpellHealingBonusDone: plus the effect's bonus multiplier times bonus healing).
"""

# Blessing of Creation 273023: 10 base points, 1.2 mana per level above level 1, plus a roll of 1.
CREATION_TEXT = 'Grants ${(($PL-1)*1.2)+$m1} mana, $s2 energy, and $/10;s3 rage to you and your party.'

# Blessing of Mending 273025: 11 to 15, plus 2.5 per level above level 1, plus 20.1% of bonus healing (the spell's
# bonus multiplier 0.201).
MENDING_TEXT = 'Heals party members within 30 yards of you for ${(($PL-1)*2.5+$m1)+($BH*0.201)}.'

# Blessing of the Divines 273026: 11 every 3 sec, plus 18.8% of bonus healing (bonus multiplier 0.188). Its base level
# is 80, so the per-level points never add anything.
DIVINES_TEXT = 'Heals party members within 30 yards of you for ${$m1+($BH*0.188)} every 3 sec for $d.'
DIVINES_BUFF = 'Healing ${$m1+($BH*0.188)} every 3 sec.'

# Frost Bomb 271936 and ranks 2-8 271966-271972 (sql/enchants/178-showcase-trace-data.sql). Each rank's tooltip took
# its damage from the small wave spell its explosion casts on the bomb's target, not from the explosion itself.
# James, 28 Nov 2026: fix the tooltip. When the bomb ends or is dispelled, its rank's explosion hits enemies within 10
# yards (base points plus 9.66 per level above the explosion's spell level, plus 42.85% of spell power and 27.8% of
# attack power from sql 178) and slows them 60% for 6 sec; the wave hits the bomb's target for its own flat amount and
# the same slow. (bomb, explosion, wave, the explosion's spell level)
FROST_BOMB_RANKS = [(271936, 271949, 271950, 10), (271966, 271959, 271952, 20), (271967, 271960, 271953, 30),
                    (271968, 271961, 271954, 40), (271969, 271962, 271955, 50), (271970, 271963, 271956, 60),
                    (271971, 271964, 271957, 70), (271972, 271965, 271958, 80)]


def frost_bomb_text(explosion, wave, level):
    scaling = f'(($PL-{level})*9.66)+($SP*0.4285)+($AP*0.278)'
    return (f'Places a Frost Bomb on the target for $d. When it ends or is dispelled it explodes, dealing '
            f'${{${explosion}m1+{scaling}}} to ${{${explosion}M1+{scaling}}} Frost damage to enemies within 10 yards '
            f'and slowing them by 60% for 6 sec. The bomb\'s target also takes ${wave}s1 Frost damage and the same slow.')


# Preservation 276259 (talent 276273, patch 55 batch 4 and sql/enchants/180-talent-code-showcase-4.sql). Its extra
# heal 276258 keeps its spell data (James, 28 Nov 2026: go with the spell data and update the tooltip): 12 to 35, plus
# 3.094 per level (its base and spell level are 0), plus 20.1% of bonus healing. The buff also gives the priest's
# heals 20% more crit chance on that ally, which its tooltip did not say.
PRESERVATION_HEAL = '${$276258m1+($PL*3.094)+($BH*0.201)} to ${$276258M1+($PL*3.094)+($BH*0.201)}'
PRESERVATION_TEXT = ('Heals from the priest who gave it are 20% more likely to be critical on this ally. That priest\'s '
                     'next direct heal on this ally uses it up, healing 3 other allies nearby for ' + PRESERVATION_HEAL +
                     ' each, giving this ally Shield of Preservation and taking 3 sec off Prayer of Preservation\'s '
                     'cooldown. Lasts $d.')
PRESERVATION_BUFF = ('Heals from the priest who gave it are 20% more likely to be critical. That priest\'s next direct heal '
                     'on you heals 3 other allies nearby, shields you and shortens Prayer of Preservation\'s cooldown.')

TEXTS = {
    273023: {170: CREATION_TEXT},
    273025: {170: MENDING_TEXT},
    273026: {170: DIVINES_TEXT, 187: DIVINES_BUFF},
    276259: {170: PRESERVATION_TEXT, 187: PRESERVATION_BUFF},
}
TEXTS.update({bomb: {170: frost_bomb_text(explosion, wave, level)} for bomb, explosion, wave, level in FROST_BOMB_RANKS})
