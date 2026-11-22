#!/usr/bin/env python3
"""Read-only helpers for extending the failure chronicle. Python 3 standard library and git only.

Runs from any folder: the repository is found from this file's own location (or pass --repo DIR first):

  python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py fixes --since 2026-11-22
      Commits on every branch whose subject or body reads like a fix, revert, retry, test result or
      measurement, newest first, with the pull request that merged each (or NOT ON MAIN).

  python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py branches
      Every remote branch not merged into origin/main, and for each of its own commits whether main
      already holds the same change (git cherry). Flags a branch whose pull request was merged and which
      then received more commits: those commits never reached main.

  python3 -I .claude/skills/wildcard-failure-archaeology/scripts/chronicle_scan.py pr <commit> [<commit> ...]
      Which merged pull request first brought each commit to main.

Nothing here writes, fetches or checks out anything. Run `git fetch --all --tags` yourself first if you
want the newest history.
"""
import argparse
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'))

MAIN = 'origin/main'
WORDS = re.compile(
    r'\b(fix(es|ed)?|revert(s|ed)?|undo|undone|back to|back on|again|instead of|no longer|never fired|'
    r'failed|fails|crash(ed|es)?|froze|freez\w*|stopp?ed|wrong|missed|temporary|remove the|drop(ped)?|'
    r'tested|passes|measure\w*|ticks?/s|ms\b|was \d)', re.I)


def git(*args):
    out = subprocess.run(('git', '-C', REPO) + args, capture_output=True, text=True)
    if out.returncode not in (0, 1):
        sys.exit(f'git {" ".join(args)} failed: {out.stderr.strip()}')
    return out.stdout


def merges():
    """[(merge hash, number, branch)] for pull requests merged on main, oldest first."""
    found = []
    for line in git('log', MAIN, '--first-parent', '--merges', '--reverse', '--format=%H %s').splitlines():
        sha, subject = line.split(' ', 1)
        match = re.match(r'Merge pull request #(\d+) from [^/]+/(.+)', subject)
        if match:
            found.append((sha, int(match.group(1)), match.group(2)))
    return found


def pr_map():
    """commit hash -> '#N branch' for the first pull request that brought it to main."""
    owner = {}
    for sha, number, branch in merges():
        for commit in git('rev-list', '--no-merges', f'{sha}^2', '--not', f'{sha}^1').split():
            owner.setdefault(commit, f'#{number} {branch}')
    return owner


def on_main(commit):
    return subprocess.run(('git', 'merge-base', '--is-ancestor', commit, MAIN)).returncode == 0


def cmd_fixes(args):
    owner = pr_map()
    log = git('log', '--all', '--no-merges', '--date=short', f'--since={args.since}',
              '--format=%x1e%H%x1f%ad%x1f%s%x1f%b')
    shown = 0
    for record in log.split('\x1e')[1:]:
        sha, date, subject, body = record.split('\x1f', 3)
        body = '\n'.join(l for l in body.splitlines()
                         if l.strip() and not l.startswith(('Co-Authored-By', 'Claude-Session')))
        if not (WORDS.search(subject) or WORDS.search(body)):
            continue
        where = owner.get(sha) or ('on main, direct commit' if on_main(sha) else 'NOT ON MAIN')
        print(f'{sha[:7]} {date} [{where}] {subject}')
        if args.bodies and body:
            print('    ' + body.replace('\n', '\n    '))
        shown += 1
    print(f'-- {shown} commits since {args.since} read like a fix, retry, test or measurement', file=sys.stderr)


def cmd_branches(_args):
    merged = merges()
    for ref in git('branch', '-r', '--no-merged', MAIN, '--format=%(refname:short)').split():
        if ref.endswith('/HEAD'):
            continue
        name = ref.split('/', 1)[1]
        tip = git('log', '-1', '--date=short', '--format=%h %ad', ref).strip()
        print(f'\n{name}  (tip {tip})')
        # A merged pull request from this branch whose merged head is an ancestor of the tip, with
        # commits added afterwards, means those later commits were pushed after the merge.
        for sha, number, branch in merged:
            if branch == name:
                extra = git('rev-list', '--no-merges', '--count', f'{sha}^2..{ref}').strip()
                if extra != '0':
                    print(f'  ! pull request #{number} merged this branch; it has commits from after '
                          f'that merge: any marked "+" below never reached main')
        lines = git('cherry', '-v', MAIN, ref).splitlines()
        if not lines:
            print('  (no commits of its own: only merge commits differ from main)')
        for line in lines:
            mark, sha, subject = line.split(' ', 2)
            state = '= same change is on main' if mark == '-' else '+ NOT on main'
            print(f'  {sha[:7]} {state}: {subject}')


def cmd_pr(args):
    owner = pr_map()
    for commit in args.commits:
        full = git('rev-parse', commit).strip()
        where = owner.get(full) or ('on main, direct commit' if on_main(full) else 'NOT ON MAIN')
        print(f'{full[:7]} {where}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--repo', default=REPO, help='repository root (default: found from this file)')
    sub = parser.add_subparsers(dest='command', required=True)
    fixes = sub.add_parser('fixes')
    fixes.add_argument('--since', default='2026-11-22', help='date, YYYY-MM-DD (default 2026-11-22)')
    fixes.add_argument('--bodies', action='store_true', help='print each commit body too')
    fixes.set_defaults(run=cmd_fixes)
    sub.add_parser('branches').set_defaults(run=cmd_branches)
    one = sub.add_parser('pr')
    one.add_argument('commits', nargs='+')
    one.set_defaults(run=cmd_pr)
    args = parser.parse_args()
    globals()['REPO'] = args.repo
    args.run(args)


if __name__ == '__main__':
    main()
