"""Builds the legendary enchant history: for every legendary copy in enchants/tracker.csv, which commits, pull
requests and server builds changed it, when that build went live, what testing recorded, and the logic, assumptions
and sources behind it.

Writes enchants/legendary-history.csv (one row per copy) and enchants/legendary-notes.md (one section per enchant
we changed). Hand-kept inputs: enchants/legendary-notes.csv (assumptions, sources, decisions, checked verdicts),
enchants/test-checklist.csv and the tracker's tested column.

Run from the repository root with the GitHub CLI signed in:
    python3 -I scripts/legendary_history.py [--patch-night-log path/to/patch-night.log]
The patch night log (C:\\Games\\CoA Server\\patch-night\\patch-night.log on the server) adds the date each build was
installed; without it that column is left empty.
"""
import argparse
import csv
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO = 'JaTynan/coa-wildcard-mystic'
TRACKED = ['sql/enchants', 'patches']
ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    return subprocess.run(args, cwd=ROOT, check=True, capture_output=True, text=True).stdout


def gh_pages(path):
    items = []
    page = 1
    while True:
        chunk = json.loads(run('gh', 'api', f'{path}{"&" if "?" in path else "?"}per_page=100&page={page}'))
        items += chunk
        if len(chunk) < 100:
            return items
        page += 1


def first_parent_owner():
    """Maps every commit on main to the first-parent commit (usually a pull request merge) that brought it in."""
    owner = {}
    for merge in run('git', 'rev-list', '--first-parent', 'main').split():
        owner[merge] = merge
        parents = run('git', 'rev-list', '--parents', '-n', '1', merge).split()[1:]
        if len(parents) > 1:
            for commit in run('git', 'rev-list', f'{parents[0]}..{merge}').split():
                owner.setdefault(commit, merge)
    return owner


def commits_by_id(ids, ref):
    """For each id: the commits on `ref` whose added lines in the tracked paths mention it, oldest first."""
    found = defaultdict(list)
    log = run('git', 'log', '--reverse', '-p', '--unified=0', '--format=@@COMMIT %H %cI', ref, '--', *TRACKED)
    commit = None
    for line in log.splitlines():
        if line.startswith('@@COMMIT '):
            _, sha, date = line.split()
            commit = (sha, date[:10])
            continue
        if not line.startswith('+') or line.startswith('+++') or commit is None:
            continue
        for number in set(re.findall(r'(?<![\d.])(\d{4,8})(?![\d.])', line)):
            if number in ids and (not found[number] or found[number][-1] != commit):
                found[number].append(commit)
    return found


def builds(releases):
    """Published wcme builds, oldest first: (number, tag, date, commit)."""
    out = []
    for release in releases:
        match = re.match(r'wcme-(.+)-build(\d+)$', release['tag_name'])
        if match:
            out.append((int(match.group(2)), release['tag_name'], release['created_at'][:10], release['target_commitish']))
    return sorted(out, key=lambda b: (b[2], b[0]))


def first_build(commit, build_list, cache):
    if commit in cache:
        return cache[commit]
    cache[commit] = None
    for number, tag, date, target in build_list:
        if subprocess.run(['git', 'merge-base', '--is-ancestor', commit, target], cwd=ROOT,
                          capture_output=True).returncode == 0:
            cache[commit] = (number, tag, date)
            break
    return cache[commit]


def first_install(commit, build_list, installed, cache):
    """Date patch night first installed a build that contains the commit."""
    key = ('live', commit)
    if key in cache:
        return cache[key]
    cache[key] = ''
    for date, tag in sorted((d, t) for t, d in installed.items()):
        target = next((b[3] for b in build_list if b[1] == tag), None)
        if target and subprocess.run(['git', 'merge-base', '--is-ancestor', commit, target], cwd=ROOT,
                                     capture_output=True).returncode == 0:
            cache[key] = date
            break
    return cache[key]


def installs(log_path):
    """Build tag -> first date patch night installed it."""
    if not log_path or not Path(log_path).exists():
        return {}
    seen = {}
    for line in Path(log_path).read_text(encoding='utf-8', errors='ignore').splitlines():
        match = re.match(r'(\d{4}-\d\d-\d\d) [\d:]+ .*installed (wcme-server-[\w.]+-build\d+)', line)
        if match and match.group(2) not in seen:
            seen[match.group(2)] = match.group(1)
    return seen


def script_notes(text, enchant_id):
    """The comment blocks in the enchant scripts that describe this id."""
    blocks = []
    lines = [l[1:] if l.startswith('+') else l for l in text.splitlines()]
    pattern = re.compile(rf'(?<!\d){enchant_id}(?!\d)')
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith('//') and pattern.search(lines[i]):
            start = i
            while start > 0 and lines[start - 1].lstrip().startswith('//'):
                start -= 1
            end = i
            while end + 1 < len(lines) and lines[end + 1].lstrip().startswith('//'):
                end += 1
            block = ' '.join(l.strip().lstrip('/').strip() for l in lines[start:end + 1])
            if block not in blocks:
                blocks.append(block)
            i = end + 1
            continue
        i += 1
    return blocks


def sql_notes(enchant_id):
    """Header comment lines of the enchant SQL files that name this id, with the file name."""
    notes = []
    pattern = re.compile(rf'(?<!\d){enchant_id}(?!\d)')
    for path in sorted((ROOT / 'sql/enchants').glob('*.sql')):
        header = []
        for line in path.read_text(encoding='utf-8', errors='ignore').splitlines():
            if not line.startswith('--'):
                break
            header.append(line[2:].strip())
        joined = ' '.join(header)
        for sentence in re.split(r'(?<=[.;])\s+(?=[A-Z])', joined):
            if pattern.search(sentence):
                notes.append(f'{path.name}: {sentence}')
    return notes


def pr_mentions(bodies, name, enchant_id):
    """Lines of pull request descriptions that mention the enchant by name or id."""
    out = []
    pattern = re.compile(rf'(?<!\d){enchant_id}(?!\d)|\b{re.escape(name)}\b')
    for number in sorted(bodies):
        for line in (bodies[number] or '').splitlines():
            line = line.strip().lstrip('-*| ').strip()
            if line and pattern.search(line) and len(line) > 20:
                out.append((number, line))
    return out


MONTHS = {m: i for i, m in enumerate(['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
                                      'Dec'], 1)}


def test_dates(results, year='2026'):
    """Dates found in test notes, as YYYY-MM-DD (ISO dates, or '3 Nov' style in the given year)."""
    dates = []
    for text in results:
        dates += re.findall(r'\d{4}-\d\d-\d\d', text)
        for day, month in re.findall(r'\b(\d{1,2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b', text):
            dates.append(f'{year}-{MONTHS[month]:02d}-{int(day):02d}')
    return sorted(dates)


def update_reference(rows):
    """Rewrites the status of each copy in enchants/legendary-reference.md from the history rows."""
    path = ROOT / 'enchants/legendary-reference.md'
    status = {r['spell']: r['status'] + (f' ({r["pull requests"]})' if r['pull requests'] else '') for r in rows}
    out = []
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith('| ') and not line.startswith('| Site ID') and not line.startswith('| Our ID'):
            cells = line.split(' | ')
            last = cells[-1].rstrip(' |')
            if re.match(r'\d+: ', last):
                copies = []
                for copy in last.split('<br>'):
                    sid = copy.split(':', 1)[0]
                    copies.append(f'{sid}: {status[sid]}' if sid in status else copy)
                cells[-1] = '<br>'.join(copies) + ' |'
            elif cells[0].lstrip('| ').isdigit() and cells[0].lstrip('| ') in status:
                cells[-1] = status[cells[0].lstrip('| ')] + ' |'
            line = ' | '.join(cells)
        if line.startswith('Copy totals'):
            counts = {}
            for r in rows:
                key = r['status'].split(' (')[0]
                counts[key] = counts.get(key, 0) + 1
            line = f'Copy totals (all {len(rows)}): ' + ', '.join(f'{k}: {v}' for k, v in
                                                              sorted(counts.items(), key=lambda kv: -kv[1])) + '.'
        out.append(line)
    path.write_text('\n'.join(out) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--patch-night-log')
    parser.add_argument('--ref', default='HEAD', help='history to read (default: the checked-out branch)')
    args = parser.parse_args()

    tracker = [r for r in csv.DictReader(open(ROOT / 'enchants/tracker.csv', encoding='utf-8'))
               if r['quality'] == 'Legendary']
    ids = {r['spell'] for r in tracker}
    tests = defaultdict(list)
    for row in csv.DictReader(open(ROOT / 'enchants/test-checklist.csv', encoding='utf-8')):
        if row['result'].strip():
            tests[row['spell']].append(row['result'].strip())
    for row in tracker:
        if row['tested'].strip():
            tests[row['spell']].append(row['tested'].strip())
    notes = {}
    notes_path = ROOT / 'enchants/legendary-notes.csv'
    if notes_path.exists():
        for row in csv.DictReader(open(notes_path, encoding='utf-8')):
            notes[row['spell']] = row

    prs = {}
    bodies = {}
    for pr in gh_pages(f'repos/{REPO}/pulls?state=closed'):
        if pr.get('merged_at'):
            prs[pr['merge_commit_sha']] = (pr['number'], pr['title'], pr['merged_at'][:10])
            bodies[pr['number']] = pr.get('body') or ''
    build_list = builds(gh_pages(f'repos/{REPO}/releases'))
    installed = installs(args.patch_night_log)
    owner = first_parent_owner()
    history = commits_by_id(ids, args.ref)
    scripts = (ROOT / 'patches/mystic-enchants-scripts.patch').read_text(encoding='utf-8', errors='ignore')
    build_cache = {}

    rows = []
    sections = []
    for row in sorted(tracker, key=lambda r: (r['name'], r['spell'])):
        sid = row['spell']
        changes = []
        for sha, date in history.get(sid, []):
            merge = owner.get(sha)
            pr = prs.get(merge) if merge else None
            build = first_build(merge or sha, build_list, build_cache)
            changes.append({
                'commit': sha[:7], 'date': date,
                'pr': pr[0] if pr else None, 'pr_title': pr[1] if pr else '',
                'build': build[0] if build else None, 'build_tag': build[1] if build else '',
                'build_date': build[2] if build else '',
                'live': first_install(merge or sha, build_list, installed, build_cache) if build else '',
            })
        note = notes.get(sid, {})
        pr_list = sorted({c['pr'] for c in changes if c['pr']})
        build_nums = sorted({c['build'] for c in changes if c['build']})
        pending = [c for c in changes if not c['pr']]
        live = sorted({c['live'] for c in changes if c['live']})
        if note.get('verdict'):
            status = note['verdict']
        elif tests.get(sid):
            tested_on = test_dates(tests[sid])
            if changes and tested_on and changes[-1]['date'] > tested_on[-1]:
                status = f'changed after its last test ({tested_on[-1]}), retest needed'
            else:
                status = 'tested (see test notes)'
        elif changes:
            status = 'changed, awaiting in-game test' if not pending else 'changed on an unmerged branch'
        else:
            status = 'unchanged: ' + (row['status'] or 'unknown')
        rows.append({
            'spell': sid, 'name': row['name'], 'status': status,
            'audit': row['audit'], 'tracker status': row['status'],
            'pull requests': ' '.join(f'#{n}' for n in pr_list),
            'first build with the change': f'build{build_nums[0]}' if build_nums else '',
            'latest build with a change': f'build{build_nums[-1]}' if build_nums else '',
            'first live on server': live[0] if live else '',
            'last change': changes[-1]['date'] if changes else '',
            'unmerged commits': ' '.join(c['commit'] for c in pending),
            'tested': ' | '.join(tests.get(sid, [])),
            'assumptions': note.get('assumptions', ''),
            'sources': note.get('sources', ''),
            'decisions': note.get('decisions', ''),
        })
        if not changes and not note:
            continue
        lines = [f'### {row["name"]} ({sid})', '', f'**Status:** {status}']
        if changes:
            lines += ['', '| Date | Commit | Pull request | First build with it | Installed on the server |',
                      '|---|---|---|---|---|']
            for c in changes:
                pr_text = f'#{c["pr"]} {c["pr_title"]}' if c['pr'] else 'not merged yet'
                build_text = f'build{c["build"]} ({c["build_date"]})' if c['build'] else 'none yet'
                lines.append(f'| {c["date"]} | {c["commit"]} | {pr_text} | {build_text} | {c["live"] or "-"} |')
        what = script_notes(scripts, sid) + sql_notes(sid)
        if what:
            lines += ['', '**What the server does (from the code and SQL comments):**', '']
            lines += [f'- {w}' for w in what]
        said = [(n, l) for n, l in pr_mentions(bodies, row['name'], sid) if n in pr_list]
        if said:
            lines += ['', '**What the pull requests said:**', '']
            lines += [f'- #{n}: {l}' for n, l in said[:12]]
        for label, key in (('Assumptions', 'assumptions'), ('Sources', 'sources'), ('Decisions', 'decisions')):
            if note.get(key):
                lines += ['', f'**{label}:** {note[key]}']
        lines += ['', f'**Testing:** {" | ".join(tests[sid]) if tests.get(sid) else "nothing recorded yet"}', '']
        sections.append('\n'.join(lines))

    update_reference(rows)
    with open(ROOT / 'enchants/legendary-history.csv', 'w', newline='', encoding='utf-8') as out:
        writer = csv.DictWriter(out, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    header = (ROOT / 'enchants/legendary-notes-header.md').read_text(encoding='utf-8')
    (ROOT / 'enchants/legendary-notes.md').write_text(header.rstrip() + '\n\n' + '\n'.join(sections), encoding='utf-8')
    print(f'{len(rows)} legendary copies, {len(sections)} with notes')


if __name__ == '__main__':
    sys.exit(main())
