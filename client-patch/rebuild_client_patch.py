#!/usr/bin/env python3
"""Rebuilds patch-ZZW.MPQ on the VM, from the client's own files, so nobody has to run racials_off_gcd.py by hand.

Patch night runs this (RebuildClientPatch in patch-night/PatchNight.ps1) with the server's Python whenever a file in
client-patch/ has changed since the last build, then swaps the result in (keeping the old copy). It runs
racials_off_gcd.py with every option the current client patch uses:

  Spell.dbc                      from the current patch-ZZW.MPQ (it carries the enchant spells build_client_patch.py
                                 added; racials_off_gcd.py rebuilds the rest of it from that, the same every time)
  --icons                        the icons already in the current patch-ZZW.MPQ (ours: rend_icons.py, regen_icons.py)
  SpellIcon.dbc, --charges,      the client's own copies: the newest copy in any archive other than patch-ZZW.MPQ
  --visuals, --cards
  (MysticEnchant.dbc, Item.dbc, SpellCharges.dbc, SpellChargesCategory.dbc, SpellVisual.dbc, SpellVisualKit.dbc)

Then it checks the result reads back: every file the old patch had is still there, Spell.dbc has at least as many
spells, and every card in custom_cards.py is in MysticEnchant.dbc. Exit code 0 and one line on success; anything
else leaves the output unwritten (patch night keeps the old patch).

  python rebuild_client_patch.py --client F:\\CoAClient --out <new patch-ZZW.MPQ> [--work <scratch folder>]

The client's data never goes into the repository: the scratch folder is emptied afterwards.
"""
import argparse
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
# The MPQ reader the website's tooltip builder uses (launcher/tooltips, from PR #307): launcher\tooltips in the
# repo and beside client-patch in patch-night on the VM, since patch night copies both folders there.
sys.path.insert(0, str(HERE.parent / 'launcher' / 'tooltips'))
sys.path.insert(0, str(HERE))
import wildcard_mpq  # noqa: E402
import custom_cards  # noqa: E402

PATCH = 'patch-ZZW.MPQ'
CLIENT_TABLES = ['SpellIcon', 'SpellCharges', 'SpellChargesCategory', 'SpellVisual', 'SpellVisualKit', 'MysticEnchant',
                 'Item']


def client_copy(archives, name):
    """The client's own copy of DBFilesClient\\<name>, from the first archive (other than our patch) that has it."""
    for path in archives:
        if path.name.lower() == PATCH.lower():
            continue
        try:
            archive = wildcard_mpq.Archive(path)
        except (OSError, ValueError):
            continue
        try:
            data = archive.read(f'DBFilesClient\\{name}')
        finally:
            archive.close()
        if data is not None:
            return data
    raise SystemExit(f'No archive other than {PATCH} has DBFilesClient\\{name}.dbc')


def listing(archive):
    data = archive.read('(listfile)')
    return [line.strip() for line in data.decode('latin-1').splitlines() if line.strip()] if data else []


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--client', default=r'F:\CoAClient')
    parser.add_argument('--out', required=True)
    parser.add_argument('--work')
    args = parser.parse_args()
    data_dir = Path(args.client) / 'Data'
    current_path = data_dir / PATCH
    if not current_path.is_file():
        raise SystemExit(f'{current_path} is missing: build the first client patch by hand (client-patch/*.py)')
    work = Path(args.work or tempfile.mkdtemp(prefix='wildcard-client-patch-'))
    if work.exists():
        shutil.rmtree(work)
    (work / 'icons').mkdir(parents=True)
    try:
        current = wildcard_mpq.Archive(current_path)
        old_files = listing(current)
        spell = current.read('DBFilesClient\\Spell.dbc')
        if spell is None:
            raise SystemExit(f'{PATCH} has no Spell.dbc')
        (work / 'base-Spell.dbc').write_bytes(spell)
        old_spells = struct.unpack_from('<I', spell, 4)[0]
        for name in old_files:
            if name.lower().startswith('interface\\icons\\') and name.lower().endswith('.blp'):
                (work / 'icons' / name.rsplit('\\', 1)[-1]).write_bytes(current.read(name))
        current.close()

        archives = wildcard_mpq.client_archives(args.client)
        for table in CLIENT_TABLES:
            (work / f'base-{table}.dbc').write_bytes(client_copy(archives, table + '.dbc'))

        new_path = work / PATCH
        command = [sys.executable, str(HERE / 'racials_off_gcd.py'), str(work / 'base-Spell.dbc'),
                   str(work / 'base-SpellIcon.dbc'), str(new_path),
                   '--icons', str(work / 'icons'),
                   '--charges', str(work / 'base-SpellCharges.dbc'), str(work / 'base-SpellChargesCategory.dbc'),
                   '--visuals', str(work / 'base-SpellVisual.dbc'), str(work / 'base-SpellVisualKit.dbc'),
                   '--cards', str(work / 'base-MysticEnchant.dbc'), str(work / 'base-Item.dbc')]
        # The builder imports its neighbours (dbc, mpqwrite, custom_spells ...) from its own folder; the scratch folder
        # it runs in holds only the DBC files this script wrote.
        run = subprocess.run(command, cwd=work, capture_output=True, text=True, timeout=30 * 60)
        if run.returncode != 0:
            raise SystemExit('racials_off_gcd.py failed: ' + (run.stderr or run.stdout).strip().splitlines()[-1])

        # Check the result before it goes anywhere.
        built = wildcard_mpq.Archive(new_path)
        new_files = {name.lower() for name in listing(built)}
        lost = [name for name in old_files if name.lower() not in new_files and name.lower() != '(listfile)']
        if lost:
            raise SystemExit('The new client patch lost: ' + ', '.join(lost))
        new_spells = struct.unpack_from('<I', built.read('DBFilesClient\\Spell.dbc'), 4)[0]
        if new_spells < old_spells:
            raise SystemExit(f'The new Spell.dbc has {new_spells} spells, the old one {old_spells}')
        cards = built.read('DBFilesClient\\MysticEnchant.dbc')
        count, fields, size = struct.unpack_from('<3I', cards, 4)
        spells = {struct.unpack_from('<I', cards, 20 + i * size + 4)[0] for i in range(count)}
        missing = [card[5] for card in custom_cards.CARDS if card[1] not in spells]
        if missing:
            raise SystemExit('The new MysticEnchant.dbc lacks: ' + ', '.join(missing))
        built.close()
        shutil.copyfile(new_path, args.out)
        print(f'Client patch rebuilt: {new_spells} spells, {len(custom_cards.CARDS)} custom cards, '
              f'{len(new_files)} files, {os.path.getsize(args.out) / 1048576:.1f} MB.')
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
