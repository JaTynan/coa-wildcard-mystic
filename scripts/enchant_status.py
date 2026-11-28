"""Writes launcher/site/enchant-status.json, the data behind the website's Mystic Enchants page (enchants.html): every
Legendary and Epic enchant with a status players can plan builds by. Read from enchants/legendary-history.csv and
enchants/epic-history.csv, so it is as current as those files; scripts/legendary_history.py runs this after writing
them. Run by hand from the repository root: python3 -I scripts/enchant_status.py

Statuses (James, 28 Nov 2026: restored, confirmed working, or waiting on feedback; plus one for known faults):
- confirmed: passed an in-game test and not changed since.
- restored: we changed it and the change is live on the server; not yet confirmed in game.
- feedback: should work, nobody has confirmed it since: it worked as it came (by our audit or a later check), or it
  passed a test before a later change.
- broken: known not to work or only partly, or its fix is written but waits for a server update.
The note column is our own wording only (dates, and where the server differs from the tooltip).
"""
import csv
import json
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIERS = [('Legendary', ROOT / 'enchants' / 'legendary-history.csv'), ('Epic', ROOT / 'enchants' / 'epic-history.csv')]
OUT = ROOT / 'launcher' / 'site' / 'enchant-status.json'


def nice(day):
    """2026-11-20 -> 20 Nov."""
    try:
        d = date.fromisoformat(day.strip()[:10])
    except ValueError:
        return ''
    return f'{d.day} {d.strftime("%b")}'


def status_of(row):
    """(status, note) for one history row."""
    text = row['status'].strip()
    live = row['first live on server'].strip()
    changed = row['last change'].strip()
    if text.startswith('tested'):
        return 'confirmed', 'Passed an in-game test'
    if text.startswith('changed after its last test'):
        when = text.split('(', 1)[1].split(')', 1)[0] if '(' in text else ''
        return 'feedback', f'Passed a test{" on " + nice(when) if when else ""}; changed since ({nice(changed)})'
    if text.startswith('changed'):
        if not live:
            return 'broken', 'Fix written; waits for a server update'
        return 'restored', f'Fixed; live since {nice(live)}'
    if text.startswith(('works', 'handled')):
        return 'feedback', 'Works as it came (checked against the server code)'
    if text.startswith('unchanged: working'):
        return 'feedback', 'Works as it came, by our audit'
    if text.startswith('unchanged: partly'):
        return 'broken', 'Partly works; not fixed yet'
    if text.startswith('unchanged'):
        return 'broken', 'Not fixed yet'
    return 'feedback', ''


def build():
    enchants = []
    seen = set()
    for quality, path in TIERS:
        for row in csv.DictReader(open(path, encoding='utf-8')):
            # One line per enchant name and quality: copies made for other realm types share the name.
            key = (row['name'], quality)
            status, note = status_of(row)
            differs = row['tooltip differs (review)'].strip()
            if key in seen:
                # Keep the least certain status of the copies, so a broken copy is not hidden by a working one.
                order = ['broken', 'feedback', 'restored', 'confirmed']
                for item in enchants:
                    if (item['name'], item['quality']) == key and order.index(status) < order.index(item['status']):
                        item['status'], item['note'] = status, note
                continue
            seen.add(key)
            enchants.append({'name': row['name'], 'quality': quality, 'spell': int(row['spell']), 'status': status,
                             'note': note, 'differs': differs})
    enchants.sort(key=lambda e: (e['quality'] != 'Legendary', e['name'].lower()))
    lines = ',\n'.join(json.dumps(e, ensure_ascii=False, separators=(',', ':')) for e in enchants)
    OUT.write_text(f'{{"updated":"{date.today().isoformat()}","enchants":[\n{lines}\n]}}\n', encoding='utf-8')
    return enchants


if __name__ == '__main__':
    result = build()
    counts = {}
    for e in result:
        counts[(e['quality'], e['status'])] = counts.get((e['quality'], e['status']), 0) + 1
    print(f'{len(result)} enchants written to {OUT.relative_to(ROOT)}:',
          ', '.join(f'{q} {s} {n}' for (q, s), n in sorted(counts.items())))
