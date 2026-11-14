#!/usr/bin/env python3
"""Rebuilds patch-ZZW.MPQ from the Spell.dbc already inside it, with the racials in racials.py off the global cooldown,
our own spells (custom_spells.py) and our rows added to the client's SpellIcon.dbc (custom_spells.ICONS).

Usage: python3 racials_off_gcd.py <Spell.dbc from the current patch-ZZW.MPQ> <the client's SpellIcon.dbc> [output.MPQ]

The result is the client's own data and is not published: copy it into the client's Data folder
(F:\\CoAClient\\Data on the VM, which friends sync from).
"""
import sys

from dbc import Dbc, write_dbc
from mpqwrite import write_mpq
import custom_spells
from racials import OFF_GCD, off_gcd

spells = Dbc(sys.argv[1])
rows = [off_gcd(spells.rows[spell]) for spell in sorted(spells.rows) if spell not in custom_spells.SPELLS]
rows += [custom_spells.row(spell, spells.fields) for spell in sorted(custom_spells.SPELLS)]  # our buff icons
write_dbc('Spell.dbc', rows, spells.fields, lambda rec, col: custom_spells.string_of(rec[0], col)
          if rec[0] in custom_spells.SPELLS else spells.string(spells.rows[rec[0]][col]))
icon_rows, icon_string = custom_spells.icon_dbc(Dbc(sys.argv[2]))
write_dbc('SpellIcon.dbc', icon_rows, 2, icon_string, string_cols={1})
write_mpq(sys.argv[3] if len(sys.argv) > 3 else 'patch-ZZW.MPQ', [('DBFilesClient\\Spell.dbc', open('Spell.dbc', 'rb').read()),
                                                                  ('DBFilesClient\\SpellIcon.dbc', open('SpellIcon.dbc', 'rb').read())])
print(f'{sum(1 for s in OFF_GCD if s in spells.rows)} racials off the global cooldown; {len(rows)} spells in all.')
