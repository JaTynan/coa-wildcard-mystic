#!/usr/bin/env python3
"""Builds patch-ZZW.MPQ: the client's Wildcard spell list plus the Mystic Enchant spells it lacks.

Usage: python3 build_client_patch.py <wildcard Spell.dbc> <area-52 Spell.dbc> <tracker.csv> [output.MPQ]

The Wildcard list comes from Data/patch-T.MPQ, the Area 52 list from Data/area-52/patch-D.MPQ (both inside the
client; extract DBFilesClient\\Spell.dbc from each). Every enchant in the tracker that the Wildcard list lacks
is copied from the Area 52 list. The result is the client's own data and is not published: copy it into the
client's Data folder by hand.
"""
import csv
import sys

from dbc import Dbc, write_dbc
from mpqwrite import write_mpq

wildcard, area52 = Dbc(sys.argv[1]), Dbc(sys.argv[2])
enchants = {int(row['spell']) for row in csv.DictReader(open(sys.argv[3]))}
added = sorted(spell for spell in enchants if spell not in wildcard.rows and spell in area52.rows)
source = {spell: wildcard for spell in wildcard.rows}
source.update({spell: area52 for spell in added})
rows = [source[spell].rows[spell] for spell in sorted(source)]
write_dbc('Spell.dbc', rows, wildcard.fields, lambda rec, col: source[rec[0]].string(source[rec[0]].rows[rec[0]][col]))
write_mpq(sys.argv[4] if len(sys.argv) > 4 else 'patch-ZZW.MPQ', [('DBFilesClient\\Spell.dbc', open('Spell.dbc', 'rb').read())])
print(f'Added {len(added)} enchant spells; {len(rows)} spells in all.')
