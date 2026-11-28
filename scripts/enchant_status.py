"""Writes launcher/site/enchant-status.json, the data behind the website's Mystic Enchants and Build planner pages
(enchants.html, planner.html): every enchant a Wildcard character can roll, with a status players can plan builds by.
Legendary and Epic are read from enchants/legendary-history.csv and enchants/epic-history.csv, so they are as current
as those files; Rare and Uncommon (which have no history file) from enchants/tracker.csv. scripts/legendary_history.py
runs this after writing the history files. Run by hand from the repository root: python3 -I scripts/enchant_status.py

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
TRACKER = ROOT / 'enchants' / 'tracker.csv'
TRACKER_TIERS = ('Rare', 'Uncommon')
OUT = ROOT / 'launcher' / 'site' / 'enchant-status.json'
# tracker.csv status -> (status, note) for the tiers without a history file
TRACKER_STATUS = {
    'verified': ('confirmed', 'Passed an in-game test'),
    'live': ('restored', 'Fixed; live on the server'),
    'live (after restart)': ('restored', 'Fixed; live on the server'),
    'working (audit)': ('feedback', 'Works as it came, by our audit'),
    'partly working': ('broken', 'Partly works; not fixed yet'),
    'broken': ('broken', 'Not fixed yet'),
    'missing': ('broken', 'Not in the game data yet'),
}
ORDER = ['broken', 'feedback', 'restored', 'confirmed']


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


def rows():
    """(quality, spell, name, status, note, differs) for every enchant, history files first, then the tracker."""
    for quality, path in TIERS:
        for row in csv.DictReader(open(path, encoding='utf-8')):
            status, note = status_of(row)
            yield quality, row['spell'], row['name'], status, note, row['tooltip differs (review)'].strip()
    for row in csv.DictReader(open(TRACKER, encoding='utf-8')):
        if row['quality'] in TRACKER_TIERS:
            status, note = TRACKER_STATUS.get(row['status'].strip(), ('feedback', ''))
            yield row['quality'], row['spell'], row['name'], status, note, ''


def build():
    enchants = []
    by_key = {}
    for quality, spell, name, status, note, differs in rows():
        # One line per enchant name and quality: copies made for other realm types share the name.
        key = (name, quality)
        if key in by_key:
            # Keep the least certain status of the copies, so a broken copy is not hidden by a working one.
            item = by_key[key]
            if ORDER.index(status) < ORDER.index(item['status']):
                item['status'], item['note'] = status, note
            continue
        by_key[key] = {'name': name, 'quality': quality, 'spell': int(spell), 'status': status, 'note': note,
                       'differs': differs}
        enchants.append(by_key[key])
    rank = {'Legendary': 0, 'Epic': 1, 'Rare': 2, 'Uncommon': 3}
    enchants.sort(key=lambda e: (rank[e['quality']], e['name'].lower()))
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
