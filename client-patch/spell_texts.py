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

TEXTS = {
    273023: {170: CREATION_TEXT},
    273025: {170: MENDING_TEXT},
    273026: {170: DIVINES_TEXT, 187: DIVINES_BUFF},
}
