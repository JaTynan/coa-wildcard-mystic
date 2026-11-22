#!/usr/bin/env python3
"""Summarises the Mystic Enchant tracker: where the restoration stands, and what is waiting for an in-game test.

Usage:  python3 -I tracker_summary.py [repository root]     (default: the repository this script sits in)
        python3 -I tracker_summary.py --untested-list        also prints every fix with nothing in `tested`
Reads enchants/tracker.csv, enchants/test-checklist.csv and the enchants/*-history.csv / review files. Changes nothing.
Python 3 standard library only. Exit code 0; 2 when the folder is not the repository root.
For "tested" counts by fix use wildcard-validation-and-qa/scripts/tested_inventory.py: this script is for status,
quality, family and review-queue counts.
"""
import argparse
import csv
import datetime
import re
import sys
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True


def rows(path):
    with open(path, newline='', encoding='utf-8') as handle:
        return list(csv.DictReader(handle))


def table(title, counter, order=None):
    print(f'\n{title}')
    keys = order or [k for k, _ in counter.most_common()]
    for key in keys:
        if counter.get(key):
            print(f'  {counter[key]:6}  {key or "(none)"}')


def verdict(text):
    text = (text or '').strip().lower()
    if not text:
        return 'no result yet'
    if 'fail' in text:
        return 'fail recorded'
    if 'pass' in text:
        return 'pass recorded'
    return 'other note (read it)'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('root', nargs='?', default=str(Path(__file__).resolve().parents[4]),
                        help='repository root (default: the repository this script sits in)')
    parser.add_argument('--untested-list', action='store_true', help='also print every fix with nothing in `tested`')
    opts = parser.parse_args()
    root = Path(opts.root)
    enchants = root / 'enchants'
    if not (enchants / 'tracker.csv').is_file():
        print(f'Not the repository root (no enchants/tracker.csv): {root}', file=sys.stderr)
        sys.exit(2)
    tracker = rows(enchants / 'tracker.csv')
    print(f'Mystic Enchant tracker summary, run {datetime.date.today().isoformat()} on enchants/tracker.csv')
    print(f'{len(tracker)} enchants (one row per enchant spell)')

    status_order = ['working (audit)', 'verified', 'live', 'live (after restart)', 'partly working', 'broken', 'missing']
    status = Counter(r['status'] for r in tracker)
    table('By status', status, status_order + sorted(set(status) - set(status_order)))
    table('By quality', Counter(r['quality'] for r in tracker))
    table('By audit verdict (enchant_audit.py)', Counter(r['audit'] for r in tracker))
    table('Broken family (only set for enchants the audit found broken)', Counter(r['family'] for r in tracker if r['family']))

    print('\nStatus by quality')
    qualities = ['Uncommon', 'Rare', 'Epic', 'Legendary', 'Artifact']
    print('  ' + 'status'.ljust(22) + ''.join(q.rjust(11) for q in qualities))
    cross = Counter((r['status'], r['quality']) for r in tracker)
    for s in status_order:
        print('  ' + s.ljust(22) + ''.join(str(cross[(s, q)]).rjust(11) for q in qualities))

    fixed = [r for r in tracker if r['fix file'].strip()]
    table(f'By fix file ({len(fixed)} rows name one; a tracker row names only the file that first fixed it)',
          Counter(re.sub(r'\s*\(.*\)$', '', r['fix file']) for r in fixed),
          sorted({re.sub(r'\s*\(.*\)$', '', r['fix file']) for r in fixed}))

    untested = [r for r in fixed if not r['tested'].strip()]
    tested = [r for r in tracker if r['tested'].strip()]
    print(f'\nTesting (tracker `tested` column): {len(tested)} rows have an entry, '
          f'{len(untested)} of the {len(fixed)} rows with a fix file have none')
    table('  Untested fixes by fix file', Counter(re.sub(r'\s*\(.*\)$', '', r['fix file']) for r in untested),
          sorted({re.sub(r'\s*\(.*\)$', '', r['fix file']) for r in untested}))
    table('  Status of the rows that do have a test entry', Counter(r['status'] for r in tested))
    dates = sorted({m for r in tested for m in re.findall(r'20\d\d-\d\d-\d\d', r['tested'])})
    if dates:
        print(f'  Test dates in the tracker run from {dates[0]} to {dates[-1]}')

    checklist = enchants / 'test-checklist.csv'
    if checklist.exists():
        check = rows(checklist)
        print(f'\nTest checklist: {len(check)} rows')
        table('  By result', Counter(verdict(r.get('result')) for r in check))
        table('  Rows with no result, by test type', Counter(r['test type'] for r in check if not (r.get('result') or '').strip()))

    for tier in ('legendary', 'epic'):
        path = enchants / f'{tier}-history.csv'
        if path.exists():
            history = rows(path)
            norm = Counter(re.sub(r'\s*\(.*$', '', r['status']) for r in history)
            table(f'{tier}-history.csv: {len(history)} copies, by status (text in brackets dropped)', norm)

    print('\nReview files (rows by the first words of `status`)')
    for name in ('core-overlap-review', 'core-proc-row-replacements', 'core-refresh-aura-review', 'core-rule-gaps',
                 'core-rule-version-gaps', 'core-version-gaps', 'swap-own-effects', 'taught-spell-doubles'):
        path = enchants / f'{name}.csv'
        if path.exists():
            data = rows(path)
            counts = Counter(re.split(r'[:;(]', r.get('status') or '')[0].strip() or '(none)' for r in data)
            print(f'  {name}.csv: {len(data)} rows: ' + ', '.join(f'{v} {k}' for k, v in counts.most_common()))

    if opts.untested_list:
        print('\nFixes with nothing in `tested` (spell, quality, name, fix file, scroll item)')
        for r in sorted(untested, key=lambda r: (r['fix file'], r['name'])):
            print(f"  {r['spell']:>8}  {r['quality']:9}  {r['name']}  [{r['fix file']}]  scroll {r['scroll item']}")


if __name__ == '__main__':
    main()
