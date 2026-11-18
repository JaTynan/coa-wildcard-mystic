#!/usr/bin/env python3
"""Rebuilds patch-ZZW.MPQ from the Spell.dbc already inside it, with the racials in racials.py off the global cooldown
(and its race-kit cooldowns),
our own spells (custom_spells.py) and our rows added to the client's SpellIcon.dbc (custom_spells.ICONS).

Usage: python3 racials_off_gcd.py <Spell.dbc from the current patch-ZZW.MPQ> <the client's SpellIcon.dbc> [output.MPQ]
       [--icons <folder>] [--charges <the client's SpellCharges.dbc> <the client's SpellChargesCategory.dbc>]

--icons adds every .blp in the folder as Interface\\Icons\\<name>.blp (rend_icons.py makes the Elemental Rend ones).
--charges adds custom_spells.CHARGE_CATEGORIES and CHARGE_LINKS to the client's spell charge tables (Dark Transfusion).

The result is the client's own data and is not published: copy it into the client's Data folder
(F:\\CoAClient\\Data on the VM, which friends sync from).
"""
import os
import sys

from dbc import Dbc, write_dbc
from mpqwrite import write_mpq
import custom_spells
from racials import OFF_GCD, cooldowns, off_gcd

args = sys.argv[1:]
icon_files = []
if '--icons' in args:
    folder = args.pop(args.index('--icons') + 1)
    args.remove('--icons')
    icon_files = [('Interface\\Icons\\' + name, open(os.path.join(folder, name), 'rb').read())
                  for name in sorted(os.listdir(folder)) if name.lower().endswith('.blp')]
charge_files = []
if '--charges' in args:
    at = args.index('--charges')
    links, categories = Dbc(args[at + 1]), Dbc(args[at + 2])
    del args[at:at + 3]
    link_rows = [rec for spell, rec in sorted(links.rows.items()) if spell not in custom_spells.CHARGE_LINKS]
    link_rows += [(spell, category) for spell, category in sorted(custom_spells.CHARGE_LINKS.items())]
    category_rows = [rec for cat, rec in sorted(categories.rows.items()) if cat not in custom_spells.CHARGE_CATEGORIES]
    category_rows += [(cat, *values) for cat, values in sorted(custom_spells.CHARGE_CATEGORIES.items())]
    write_dbc('SpellCharges.dbc', link_rows, 2, None, string_cols=set())
    write_dbc('SpellChargesCategory.dbc', category_rows, 3, None, string_cols=set())
    charge_files = [('DBFilesClient\\SpellCharges.dbc', open('SpellCharges.dbc', 'rb').read()),
                    ('DBFilesClient\\SpellChargesCategory.dbc', open('SpellChargesCategory.dbc', 'rb').read())]
spells = Dbc(args[0])
rows = [custom_spells.with_icon(cooldowns(off_gcd(spells.rows[spell]))) for spell in sorted(spells.rows) if spell not in custom_spells.SPELLS]
rows += [custom_spells.row(spell, spells.fields) for spell in sorted(custom_spells.SPELLS)]  # our buff icons
write_dbc('Spell.dbc', rows, spells.fields, lambda rec, col: custom_spells.string_of(rec[0], col)
          if rec[0] in custom_spells.SPELLS else spells.string(spells.rows[rec[0]][col]))
icon_rows, icon_string = custom_spells.icon_dbc(Dbc(args[1]))
write_dbc('SpellIcon.dbc', icon_rows, 2, icon_string, string_cols={1})
write_mpq(args[2] if len(args) > 2 else 'patch-ZZW.MPQ', [('DBFilesClient\\Spell.dbc', open('Spell.dbc', 'rb').read()),
                                                       ('DBFilesClient\\SpellIcon.dbc', open('SpellIcon.dbc', 'rb').read())]
          + charge_files + icon_files)
print(f'{sum(1 for s in OFF_GCD if s in spells.rows)} racials off the global cooldown; {len(rows)} spells in all.')
