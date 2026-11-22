#!/usr/bin/env python3
"""What does a branch change in server-settings.txt, and is it a candidate "standard change"?

docs/agents/context/change-risk.md pre-approves one kind of settings change as LOW without scoring:
"a value change to a setting already in server-settings.txt, within the range its comment states".
This script sorts each changed line into: value change to an existing setting, new setting, removed setting,
comment-only change; prints the comment a reviewer must read to judge the range; and points out lines that
touch an area change-risk.md lists as a hard stop. It decides nothing: it prepares the facts for the
classification (skill wildcard-change-control). Read-only; uses `git show`, never checks anything out.

  python3 -I settings_change_report.py origin/main my-branch
  python3 -I settings_change_report.py origin/main            (second ref defaults to HEAD)
  python3 -I settings_change_report.py --files old.txt new.txt
  python3 -I settings_change_report.py --exact refA refB      (the two files as they are; default is refB against
                                                               the point where it left refA, as a pull request shows)

Exit code: 0 = every change is a value change to an existing setting and none touches a hard-stop area
(candidate standard change, range still to be checked by a person); 1 = anything else; 2 = could not run.
Runs from any folder (the repository is found from this file; or pass --repo). With settings_catalogue.py --lint
it is the authority for settings checks; the full pre-merge check set is in the skill wildcard-validation-and-qa.
Python 3 standard library only.
"""
import argparse
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True

ENTRY = re.compile(r'^\s*([^|#]+?)\s*\|\s*([^=\s]+)\s*=\s*(.*?)\s*$')
PATH = 'server-settings/server-settings.txt'

# Areas change-risk.md step 1 lists as hard stops, matched against "<file> | <name>". Deliberately broad:
# a false alarm costs a minute of a reviewer's time, a miss does not get a second look.
HARD_STOPS = [
    (3, 'network setup (ports, bind addresses, the realm list)',
     re.compile(r'^(realm|realmlist)\s*\||\|\s*(BindIP|RealmID|WorldServerPort|RealmServerPort|CoA\.AllowRemoteClients'
                r'|\w*DatabaseInfo|Ra\.\w+|SOAP\.\w+|[\w.]+\.Url)$', re.I)),
    (1, 'accounts, security levels, GM or console commands',
     re.compile(r'\|\s*(GM\.\w+|Console\.\w+|Ra\.\w+|SOAP\.\w+|Account\w*\.[\w.]+|\w*Security\w*|AllowTickets|Warden\.[\w.]+)$', re.I)),
    (4, 'secrets, tokens, or what reads them',
     re.compile(r'\|\s*[\w.]*(Token|Secret|Password|ApiKey|CoABugReport\.[\w.]+)$', re.I)),
]
# Hard stop 2 is "anything that gives players gold, items, currency, experience or reputation outside normal
# play". Whether a rate inside its documented range counts is not settled in the document, so these are only
# pointed out as a question for change control.
REWARDS = re.compile(r'\|\s*(Rate\.[\w.]+|[\w.]*(Percent|PerMille|Rate|Rounds|Stack|ForWin|ForLoss|GoldPerLevel|Bonus\w*)'
                     r'|Wildcard\.Free\w+|GroupXP\.\w+|WorldPvP\.\w+|HonorPointsAfterDuel|SkillGain\.\w+|MaxPlayerLevel)$', re.I)


def parse(text):
    """{(file lower, name): (value, comment above, line number)} plus the list of duplicates."""
    found, duplicates = {}, []
    block, last = [], []
    for number, raw in enumerate(text.split('\n'), 1):
        line = raw.rstrip('\r')
        if not line.strip():
            block, last = [], []
            continue
        if re.match(r'^#\s*-{10,}', line):          # a section heading starts a new comment block
            block, last = [], []
            continue
        if line.lstrip().startswith('#'):
            block.append(line.lstrip()[1:].strip())
            continue
        entry = ENTRY.match(line)
        if not entry:
            continue
        if block:
            last, block = block, []
        key = (entry.group(1).lower(), entry.group(2))
        if key in found:
            duplicates.append(key)
        found[key] = (entry.group(3), ' '.join(last), number, entry.group(1))
    return found, duplicates


def show(repo, ref):
    done = subprocess.run(['git', '-C', repo, 'show', '%s:%s' % (ref, PATH)], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)
    if done.returncode != 0:
        sys.stderr.write('Cannot read %s at %s: %s\n' % (PATH, ref, done.stderr.decode(errors='replace').strip()))
        sys.exit(2)
    return done.stdout.decode('utf-8', errors='replace')


def short(value, limit=70):
    return value if len(value) <= limit else value[:limit] + ' ... (%d chars)' % len(value)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('base', help='git ref of the starting point (usually origin/main), or the old file with --files')
    parser.add_argument('head', nargs='?', default='HEAD', help='git ref of the change (default HEAD), or the new file')
    parser.add_argument('--files', action='store_true', help='base and head are two files on disk, not git refs')
    parser.add_argument('--exact', action='store_true',
                        help='compare the two refs as they are, instead of head against its merge base with base')
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..', '..', '..')))
    options = parser.parse_args()

    if options.files:
        try:
            with open(options.base, encoding='utf-8') as handle:
                old_text = handle.read()
            with open(options.head, encoding='utf-8') as handle:
                new_text = handle.read()
        except OSError as problem:
            sys.stderr.write('%s\n' % problem)
            return 2
    else:
        base = options.base
        if not options.exact:
            # Compare against the point where the branch left the base, as a pull request does. Comparing a branch
            # with today's main directly would report everything main gained since as "removed".
            fork = subprocess.run(['git', '-C', options.repo, 'merge-base', options.base, options.head],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if fork.returncode == 0 and fork.stdout.strip():
                base = fork.stdout.decode().strip()
                print('Comparing with the merge base %s of %s and %s.' % (base[:7], options.base, options.head))
        old_text, new_text = show(options.repo, base), show(options.repo, options.head)
    old, _old_duplicates = parse(old_text)
    new, duplicates = parse(new_text)

    changed = [k for k in new if k in old and new[k][0] != old[k][0]]
    added = [k for k in new if k not in old]
    removed = [k for k in old if k not in new]
    recommented = [k for k in new if k in old and new[k][0] == old[k][0] and new[k][1] != old[k][1]]

    print('server-settings.txt: %s -> %s' % (options.base, options.head))
    print('  value changes to existing settings: %d' % len(changed))
    print('  new settings:                       %d' % len(added))
    print('  removed settings:                   %d' % len(removed))
    print('  comment changed, value the same:    %d' % len(recommented))
    print('  settings listed twice in the result: %d' % len(duplicates))
    print('')

    stops, questions = [], []

    def flags(key):
        label = '%s | %s' % (new.get(key, old.get(key))[3], key[1])
        for number, what, pattern in HARD_STOPS:
            if pattern.search(label):
                stops.append((label, number, what))
        if REWARDS.search(label):
            questions.append(label)
        return label

    for key in sorted(changed, key=lambda k: new[k][2]):
        label = flags(key)
        print('CHANGED  %s (line %d)' % (label, new[key][2]))
        print('    was: %s' % short(old[key][0]))
        print('    now: %s' % short(new[key][0]))
        print('    comment to check the range against: %s' % (short(new[key][1], 400) or '(none: no stated range)'))
        if new[key][1] == old[key][1]:
            print('    note: the comment was not updated with the value')
    for key in sorted(added, key=lambda k: new[k][2]):
        label = flags(key)
        print('NEW      %s = %s (line %d)' % (label, short(new[key][0]), new[key][2]))
        print('    comment: %s' % (short(new[key][1], 400) or '(none)'))
    for key in sorted(removed, key=lambda k: old[k][2]):
        label = flags(key)
        print('REMOVED  %s (was %s). The config file on the VM keeps the old line until someone removes it.'
              % (label, short(old[key][0])))
    for key in duplicates:
        print('TWICE    %s | %s (the later line wins)' % key)

    print('')
    if stops:
        print('Possible hard stops (change-risk.md step 1: always HIGH, never automatic, waits for James):')
        for label, number, what in stops:
            print('  %s -> hard stop %d, %s' % (label, number, what))
    if questions:
        print('Touches what players are given (rates, chances, rewards). Hard stop 2 covers gold, items, currency,')
        print('experience or reputation "outside normal play"; whether a documented rate counts is for change control:')
        for label in questions:
            print('  %s' % label)
    if not (changed or added or removed or duplicates):
        print('No setting changed.')
        return 0
    standard = bool(changed) and not (added or removed or duplicates or stops)
    print('')
    if standard:
        print('Verdict: CANDIDATE standard change (value changes only, no hard-stop area matched).')
        print('Still to do by a person or the analyst: confirm each new value is inside the range its comment states.')
        print('A setting whose comment states no range is not covered by the pre-approval.')
        return 0
    print('Verdict: NOT a standard change. Classify with wildcard-change-control (change-risk.md, steps 1-5).')
    return 1


if __name__ == '__main__':
    sys.exit(main())
