#!/usr/bin/env python3
"""Pre-push check for the public repository: looks for things that must never be published.

Usage (from any folder; read-only, runs only `git ls-files`; the repository is found from this file's own
location unless a root is given):
    python3 -I .claude/skills/wildcard-docs-and-publishing/scripts/public_repo_check.py [repository root]

It reads the files git tracks (what a push would publish), not untracked files. Stage new files first
(`git add -N <file>`) or they are not looked at.

Levels:
  FAIL  a rule in README.md / docs/agents/context/patches.md looks broken. Fix before pushing.
  WARN  worth a human look. Not proof of a problem.
  ok    nothing found.
Exit codes: 0 no FAIL; 1 at least one FAIL; 2 the tool could not run (not a git repository). Authority for the
public-repository rules; the full pre-merge check set is listed in wildcard-validation-and-qa.
 A clean run is not proof: it cannot recognise paraphrased-versus-copied
text or an unusual secret format. Read the diff as well.
"""
import sys

sys.dont_write_bytecode = True

import argparse
import os
import re
import subprocess

# Game client data: archives, tables, textures, models, maps. The client patch is built locally and never committed.
CLIENT_EXT = {'.mpq', '.dbc', '.db2', '.blp', '.m2', '.wmo', '.adt', '.wdt', '.wdl', '.skin', '.anim'}
# Build outputs, dumps and archives that have no place in the source tree.
BINARY_EXT = {'.exe', '.dll', '.pdb', '.dmp', '.zip', '.7z', '.tar', '.gz', '.pyc', '.pyo'}
# Files that hold secrets on the VM (signup/README.md, launcher/README.md).
SECRET_FILES = {'signup-settings.json', 'signup-state.json', 'launcher-secret.json', '.env'}
SECRET_PATTERNS = [
    ('GitHub token', re.compile(r'\b(github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,})')),
    ('private key', re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY')),
    ('Cloudflare Turnstile key', re.compile(r'\b0x4AAAAAA[A-Za-z0-9_-]{10,}')),
    ('AWS key', re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ('Slack token', re.compile(r'\bxox[bap]-[A-Za-z0-9-]{10,}')),
    ('quoted secret value', re.compile(
        r'''(?i)(password|passwd|secret|token|invite ?codes?|api[_-]?key)["']?\s*[:=]\s*\[?\s*["']'''
        r'''(?!PASTE-|CHANGE-ME|github_pat_\.\.\.)[^"'<>${}%\s]{8,}["']''')),
]
# Spell text as the client stores it carries format tokens ($s1, $d, $12345s2). Our own spells do too, and they
# are written by client-patch/custom_spells.py, so those two places are expected.
TOOLTIP_TOKEN = re.compile(r"'[^'\n]{25,}\$(\d{3,7})?[sdtmoax][1-3]?\b")
OWN_SPELL_TEXT = ('sql/enchants/150-custom-spells.sql', 'client-patch/')
SHARE_LINK = re.compile(r'https?://[^\s"\']*(/share/|[?&](token|key|sig)=)[^\s"\']*')
PIN_LINE = re.compile(r'^[\w.-]+/[\w.-]+ \| [0-9a-f]{40} \| \S')
BIG = 1_000_000


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('root', nargs='?', default=None,
                        help='repository root (default: the repository this script sits in)')
    args = parser.parse_args()
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.abspath(args.root) if args.root else os.path.abspath(os.path.join(here, '..', '..', '..', '..'))
    try:
        listing = subprocess.run(['git', '-C', root, 'ls-files', '-z'], check=True, capture_output=True).stdout
        ignored = subprocess.run(['git', '-C', root, 'ls-files', '-z', '-ci', '--exclude-standard'], check=True,
                                 capture_output=True).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'Not a git repository, or git failed: {error}', file=sys.stderr)
        sys.exit(2)
    files = [f for f in listing.decode('utf-8', 'replace').split('\0') if f]
    ignored = [f for f in ignored.decode('utf-8', 'replace').split('\0') if f]
    results = []

    def report(level, title, items, hint=''):
        results.append((level if items else 'ok', title, items, hint))

    ext = lambda f: os.path.splitext(f)[1].lower()
    report('FAIL', 'Game client data files', [f for f in files if ext(f) in CLIENT_EXT],
           'Client data is never published; build the client patch locally (docs/enchant-restoration.md).')
    report('FAIL', 'Secret-holding files', [f for f in files if os.path.basename(f) in SECRET_FILES],
           'These live only on the VM (.gitignore, signup/README.md).')
    report('WARN', 'Build outputs, archives or compiled files', [f for f in files if ext(f) in BINARY_EXT],
           'Usually committed by accident. Ask James before removing: the removal is a commit like any other.')
    report('WARN', 'Tracked although .gitignore lists them', ignored,
           '.gitignore only stops new files; these were added before the rule or with a forced add.')

    addon_dirs = sorted({f.split('/')[1] for f in files if f.startswith('addon/') and f.count('/') >= 2})
    report('FAIL', 'Addon folders that are not ours (addon/Wildcard*)',
           [d for d in addon_dirs if not d.startswith('Wildcard')],
           'Third-party addons go in addon/third-party-addons.txt as a pinned commit, never as code.')

    pins = os.path.join(root, 'addon', 'third-party-addons.txt')
    bad_pins = []
    if os.path.exists(pins):
        for number, line in enumerate(open(pins, encoding='utf-8', errors='replace'), 1):
            line = line.strip()
            if line and not line.startswith('#') and not PIN_LINE.match(line):
                bad_pins.append(f'addon/third-party-addons.txt:{number}: {line[:80]}')
    report('FAIL', 'Third-party addon lines without a full 40-character commit', bad_pins,
           'Format: owner/repository | commit | folders. A branch name would take untested changes.')

    secrets, tokens, links, big = [], [], [], []
    for name in files:
        path = os.path.join(root, name)
        try:
            size = os.path.getsize(path)
            data = open(path, 'rb').read()
        except OSError:
            continue
        if size > BIG:
            big.append(f'{name} ({size / 1e6:.1f} MB)')
        if b'\0' in data[:8000]:
            continue  # binary: covered by the extension checks
        if name.endswith('public_repo_check.py'):
            continue  # this file's own patterns
        for number, line in enumerate(data.decode('utf-8', 'replace').splitlines(), 1):
            for label, pattern in SECRET_PATTERNS:
                if pattern.search(line):
                    secrets.append(f'{name}:{number}: {label}')  # the value itself is never printed
            if TOOLTIP_TOKEN.search(line) and not name.startswith(OWN_SPELL_TEXT):
                tokens.append(f'{name}:{number}')
            if SHARE_LINK.search(line):
                links.append(f'{name}:{number}')
    report('FAIL', 'Possible secrets', secrets, 'Values are not printed here. Open the line; if real, rotate it too.')
    report('WARN', 'Spell text with client format tokens outside our own spells', tokens,
           'May be text carried over from client spell data. The rule is to describe in our own words.')
    report('WARN', 'Share links or URLs carrying a token', links,
           'A link anyone can use is public once pushed. Check that is intended.')
    report('WARN', 'Files over 1 MB', big, 'Large files are often data that should stay on the VM.')

    failed = False
    for level, title, items, hint in results:
        print(f'[{level:4}] {title}' + (f': {len(items)}' if items else ''))
        for item in items[:25]:
            print(f'         {item}')
        if len(items) > 25:
            print(f'         ... and {len(items) - 25} more')
        if items and hint:
            print(f'         -> {hint}')
        failed = failed or level == 'FAIL'
    print('\nResult:', 'FAIL: fix before pushing.' if failed else 'no FAIL. Read any WARN lines, then read the diff.')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
