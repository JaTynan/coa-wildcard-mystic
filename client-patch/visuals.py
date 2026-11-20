"""Effect-table additions for the racials' effects (James chose each in game, 20 November; docs/race-kits.md lists them).

Three effects he picked carry a built-in sound he swapped for another, and the client plays a kit's sound with its
look, so each gets a silent copy here (the server plays the chosen sound beside it). The Ambush hands also need a
visual whose looping part is that silent copy, for the Ambush buff to wear. Everything else the racials show is an
existing kit or visual, played by the server or named in custom_spells.py.

The base tables come from the client: patch-S.MPQ holds SpellVisual.dbc and SpellVisualKit.dbc (checked 20 November:
byte for byte the same as the server's copies). Client data, so they stay out of the repo; pass their paths.
"""
import struct

KIT_SOUND = 15        # SpellVisualKit: SoundID
VISUAL_STATE_KIT = 4  # SpellVisual: StateKit
VISUAL_MISSILE_ATTACHMENT = 16

# New kit -> (kit it copies, what for). The copy keeps the look and drops the sound.
SILENT_KITS = {
    9990101: (10583, "Troll Voodoo burst: Earthliving's lifebloom, the server adds Nature Resistance's sound (3331)"),
    9990102: (6799, "Orc full Rush: Bloodlust's head burst, the server adds the modern war shout (306097)"),
    9990103: (833217, "Night Elf Ambush ready: Starsurge's starlight hands, the server adds the wisp's \"yes\" (6346)"),
}
# New visual -> {column: value}, the rest zero.
NEW_VISUALS = {
    # The Ambush buff's look: the silent starlight hands while it lasts (missile attachment -1, as visuals without a
    # missile have, Gnomish Rocket Boots' 1223 among them).
    9990101: {VISUAL_STATE_KIT: 9990103, VISUAL_MISSILE_ATTACHMENT: 0xFFFFFFFF},
}


def _read(path):
    data = open(path, 'rb').read()
    magic, count, fields, size, strings = struct.unpack_from('<4s4I', data, 0)
    assert magic == b'WDBC' and size == fields * 4
    rows = {}
    for i in range(count):
        rec = list(struct.unpack_from(f'<{fields}I', data, 20 + i * size))
        rows[rec[0]] = rec
    return fields, rows, data[20 + count * size:]


def _write(path, fields, rows, strings):
    with open(path, 'wb') as fh:
        fh.write(struct.pack('<4s4I', b'WDBC', len(rows), fields, fields * 4, len(strings)))
        for key in sorted(rows):
            fh.write(struct.pack(f'<{fields}I', *rows[key]))
        fh.write(strings)


def build(visual_path, kit_path, visual_out='SpellVisual.dbc', kit_out='SpellVisualKit.dbc'):
    """Writes the two tables with our rows added; returns the (name in the MPQ, bytes) pairs."""
    fields, kits, strings = _read(kit_path)
    for new, (source, _) in SILENT_KITS.items():
        assert new not in kits, f'kit {new} is taken'
        rec = list(kits[source])
        rec[0], rec[KIT_SOUND] = new, 0
        kits[new] = rec
    _write(kit_out, fields, kits, strings)
    vfields, visuals, vstrings = _read(visual_path)
    for new, cols in NEW_VISUALS.items():
        assert new not in visuals, f'visual {new} is taken'
        rec = [0] * vfields
        rec[0] = new
        for col, value in cols.items():
            rec[col] = value
        visuals[new] = rec
    _write(visual_out, vfields, visuals, vstrings)
    return [('DBFilesClient\\SpellVisual.dbc', open(visual_out, 'rb').read()),
            ('DBFilesClient\\SpellVisualKit.dbc', open(kit_out, 'rb').read())]
