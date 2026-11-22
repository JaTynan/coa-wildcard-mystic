#!/usr/bin/env python3
"""Builds the settings catalogue for the Wildcard server repository.

Reads (never writes outside --out):
  server-settings/server-settings.txt   the settings list patch night applies at every start
  patches/*.ps1, patches/*.patch        every sConfigMgr->GetOption<T>("Name", default) our patches add
  CHANGES.md                            the "Setting" column of the code patch table
  ollama-chat/mod_ollama_chat.conf.dist the only upstream config template kept in this repository
  git history                           who set each value and when; which build first carried each option
  --upstream DIR (optional, repeatable) checkouts of the upstream sources at the pinned commits; their
                                        *.conf.dist files and C++ are used to tell known options from typos

Writes one Markdown file (default: ../references/settings-catalogue.md next to this script).

  python3 -I settings_catalogue.py --lint              only the mismatch lists, to the screen; exit 1 on a hard one
  python3 -I settings_catalogue.py --upstream ~/upstream/core --upstream ~/upstream/mod-playerbots \
        --upstream ~/upstream/mod-dungeon-clear --upstream ~/upstream/mod-coa-playerbots
                                                       regenerate the catalogue (the four pinned, unpatched clones)
  python3 -I settings_catalogue.py <same --upstream flags> --check
                                                       exit 1 if the catalogue on disk is out of date
  python3 -I settings_catalogue.py --stdout            print a weak catalogue (no upstream) without writing a file

Safety rules (added after the shipped catalogue was overwritten by a bare run on 2026-11-22):
  * Without --upstream it REFUSES to write the shipped reference file. Use --stdout, or --out FILE for a scratch
    copy. A weak run can never replace an upstream-checked catalogue.
  * It prints every upstream checkout it found, and REFUSES to write when one looks patched (local changes in its
    work tree, or our own Wcme*.cpp files inside it): patched sources make our own options look like upstream ones
    and hide the mismatches this tool exists to find. Never point --upstream at a kept pre-flight workspace.
    --lint and --check only warn. Name each clone; a parent folder is searched one level down and may hold more
    than you meant.
  * Private details are masked in the output: home-network addresses, the host name written next to one, and the
    value of Leaderboards.HiddenCharacters.

When to regenerate: when this skill is maintained (a skill-maintenance pull request). A settings pull request
runs --lint only and does not touch the catalogue.

This script (--lint) and settings_change_report.py are the authority for settings checks; the full pre-merge
check set is listed in the skill wildcard-validation-and-qa.

Exit codes: 0 ok; 1 a hard problem (--lint) or out of date (--check); 2 refused to write.
Python 3 standard library only. Git must be on the PATH (history columns are left empty without it).
"""
import argparse
import os
import re
import subprocess
import sys
from collections import OrderedDict, defaultdict

sys.dont_write_bytecode = True

PRIVATE_IP = re.compile(r'\b(?:10\.\d{1,3}|192\.168|172\.(?:1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}(?:/\d{1,2})?(?::\d+)?')
MASKED_VALUES = {'Leaderboards.HiddenCharacters': '"<character names>"'}


def scrub(text):
    """Mask private details before anything is printed or written (the repository is public)."""
    text = PRIVATE_IP.sub('<LAN address>', text)
    # a host name written just before its address: "on NAME (<LAN address>"
    return re.sub(r'\bon [A-Za-z][\w-]* \(<LAN address>', 'on <host> (<LAN address>', text)


def upstream_checkouts(directories):
    """[(path, problem or '')] for every git checkout that is, or sits directly under, an --upstream folder."""
    found = []
    for top in directories:
        paths = [top] if os.path.exists(os.path.join(top, '.git')) else \
            [os.path.join(top, name) for name in sorted(os.listdir(top))]
        for path in paths:
            if not os.path.exists(os.path.join(path, '.git')):
                continue
            problems = []
            dirty = run_git(path, ['status', '--porcelain', '--untracked-files=no'])
            if dirty and dirty.strip():
                problems.append('local changes in its work tree')
            for folder, _dirs, files in os.walk(path):
                if '.git' in folder.split(os.sep):
                    continue
                if any(name.startswith('Wcme') and name.endswith('.cpp') for name in files):
                    problems.append('contains our own Wcme*.cpp files')
                    break
            found.append((path, '; '.join(problems)))
    return found

ENTRY = re.compile(r'^\s*([^|#]+?)\s*\|\s*([^=\s]+)\s*=\s*(.*?)\s*$')          # same as Apply-ServerSettings.ps1
COMMENTED_ENTRY = re.compile(r'^\s*#\s*([\w\\.\-]+\.conf)\s*\|\s*([^=\s]+)\s*=\s*(.*?)\s*$')
SECTION = re.compile(r'^#\s*-{10,}\s*(.+?)\s*$')
DIST_KEY = re.compile(r'^\s*#?\s*([A-Za-z][\w.\-]*)\s*=\s*(.*?)\s*$')           # same as the kit's .dist check
PSEUDO_FILES = ('realm', 'realmlist')
# "    void OnPlayerUpdate(Player* player, uint32 diff) override": a C++ function header inside a patch
FUNCTION_HEADER = re.compile(r'^\s*(?:static |inline |virtual |constexpr )*([\w:<>\*&]+)[\w:<>\*& ]*?\s+\*?&?(\w+)\s*\([^;]*$')
PER_TICK_FUNCTIONS = ('OnPlayerUpdate', 'OnUpdate', 'Update', 'OnWorldUpdate', 'OnMapUpdate', 'UpdateAI')

# Settings the lag work keeps coming back to. Listed whether or not server-settings.txt sets them.
PERFORMANCE_KEYS = [
    'MapUpdate.Threads',
    'AiPlayerbot.MinRandomBots', 'AiPlayerbot.MaxRandomBots',
    'AiPlayerbot.BotActiveAlone', 'AiPlayerbot.BotActiveAloneForceWhenInZone',
    'AiPlayerbot.BotActiveAloneForceWhenInRadius', 'AiPlayerbot.BotActiveAloneForceWhenInMap',
    'AiPlayerbot.BotActiveAloneForceWhenInGuild',
    'AiPlayerbot.botActiveAloneSmartScale', 'AiPlayerbot.botActiveAloneSmartScaleDiffLimitfloor',
    'AiPlayerbot.botActiveAloneSmartScaleDiffLimitCeiling',
    'AiPlayerbot.RandomBotConcentrateInPlayerZone', 'AiPlayerbot.DisabledWithoutRealPlayer',
    'AiPlayerbot.RandomBotGroupNearby',
    'Log.Async.Enable', 'Logger.coa', 'Logger.module.coa_challenges',
    'CharacterDatabase.WorkerThreads', 'CharacterDatabase.SynchThreads',
    'LoginDatabase.WorkerThreads', 'WorldDatabase.WorkerThreads',
    'Visibility.Distance.Continents',
    'RecordUpdateTimeDiffInterval', 'MinRecordUpdateTimeDiff', 'Appender.Timing', 'Logger.time.update',
    'Respawn.DynamicRateCreature', 'Respawn.DynamicMinimumCreature',
    'AuctionHouseBot.ItemsPerCycle', 'AuctionHouseBot.Alliance.MaxItems',
    'OllamaChat.Enable',
]


def run_git(repo, args):
    try:
        done = subprocess.run(['git', '-C', repo] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        return None
    if done.returncode != 0:
        return None
    return done.stdout.decode('utf-8', errors='replace')


def cell(text, limit=0):
    """One Markdown table cell: no pipes, no line breaks, optionally shortened."""
    text = ' '.join(str(text).split())
    if limit and len(text) > limit:
        text = text[:limit].rstrip() + ' ... (%d chars)' % len(text)
    return text.replace('|', '\\|')


def code(text, limit=0):
    text = cell(text, limit)
    if text == '':
        return '(empty)'
    return '`' + text.replace('`', "'") + '`'


def first_sentences(text, limit=220):
    text = ' '.join(text.split())
    if len(text) <= limit:
        return text
    cut = text[:limit]
    stop = max(cut.rfind('. '), cut.rfind(': '), cut.rfind('; '))
    if stop > limit // 2:
        return cut[:stop + 1].rstrip()
    return cut.rstrip() + ' ...'


# --------------------------------------------------------------------------- server-settings.txt
def parse_settings(path):
    """Entries in file order, each with its section and the comment block above it."""
    entries, commented, problems = [], [], []
    section = '(top of file)'
    block, last_block = [], []
    with open(path, encoding='utf-8') as handle:
        lines = handle.read().split('\n')
    for number, raw in enumerate(lines, 1):
        line = raw.rstrip('\r')
        head = SECTION.match(line)
        if head:
            section = head.group(1)
            block, last_block = [], []
            continue
        if not line.strip():
            block, last_block = [], []
            continue
        if line.lstrip().startswith('#'):
            off = COMMENTED_ENTRY.match(line)
            if off:
                commented.append({'file': off.group(1), 'key': off.group(2), 'value': off.group(3),
                                  'line': number, 'section': section, 'comment': ' '.join(block)})
                continue
            block.append(line.lstrip()[1:].strip())
            continue
        found = ENTRY.match(line)
        if not found:
            problems.append('line %d is neither a comment nor "<file> | <name> = <value>": %s' % (number, line[:80]))
            continue
        if block:
            last_block = block
            block = []
        entries.append({'file': found.group(1), 'key': found.group(2),
                        'value': MASKED_VALUES.get(found.group(2), found.group(3)),
                        'line': number, 'section': section, 'comment': ' '.join(last_block)})
    return entries, commented, problems


# --------------------------------------------------------------------------- patches
def split_args(text):
    """Top-level arguments of a call, given the text after its opening bracket. Returns (args, complete)."""
    args, depth, current, quote = [], 0, '', False
    i = 0
    while i < len(text):
        ch = text[i]
        if quote:
            current += ch
            if ch == '\\' and i + 1 < len(text):
                current += text[i + 1]
                i += 1
            elif ch == '"':
                quote = False
        elif ch == '"':
            quote = True
            current += ch
        elif ch in '([{':
            depth += 1
            current += ch
        elif ch in ')]}':
            if depth == 0:
                args.append(current.strip())
                return args, True
            depth -= 1
            current += ch
        elif ch == ',' and depth == 0:
            args.append(current.strip())
            current = ''
        else:
            current += ch
        i += 1
    args.append(current.strip())
    return args, False


def scan_patches(patch_dir):
    """Every GetOption read our patches add: name -> list of reads. Also the names that could not be resolved."""
    reads = defaultdict(list)
    unresolved = []
    weekend_rates = defaultdict(list)       # rate name -> [(file, line)]
    literal_index = {}                      # file -> text, for the dynamic-name resolvers
    call = re.compile(r'GetOption<\s*([^>]+?)\s*>\s*\(')
    for name in sorted(os.listdir(patch_dir)):
        if not (name.endswith('.ps1') or name.endswith('.patch')):
            continue
        path = os.path.join(patch_dir, name)
        with open(path, encoding='utf-8', errors='replace') as handle:
            lines = handle.read().split('\n')
        is_diff = name.endswith('.patch')
        clean = []
        for line in lines:
            line = line.rstrip('\r')
            if is_diff:
                # only lines the patch ADDS are ours; context and removed lines are upstream's
                line = line[1:] if (line.startswith('+') and not line.startswith('+++')) else ''
            # PowerShell double-quoted strings escape quotes and newlines with a backtick
            clean.append(line.replace('`"', '"').replace('`n', ' '))
        literal_index[name] = '\n'.join(clean)
        function = ''
        for number, line in enumerate(clean, 1):
            header = FUNCTION_HEADER.match(line)
            if header and header.group(1) not in ('if', 'for', 'while', 'switch', 'return', 'else'):
                function = header.group(2)
            if not line.lstrip().startswith('# '):
                for rate in re.finditer(r'WeekendBonusRate\(', line):
                    inner, _complete = split_args(line[rate.end():])
                    for literal in re.findall(r'"([A-Za-z]+)"', inner[0] if inner else ''):
                        weekend_rates[literal].append((name, number))
            for found in call.finditer(line):
                rest = line[found.end():]
                args, complete = split_args(rest)
                extra = number
                while not complete and extra < len(clean) and extra < number + 3:
                    rest += ' ' + clean[extra].strip()
                    extra += 1
                    args, complete = split_args(rest)
                if len(args) < 2:
                    unresolved.append((name, number, 'could not read the call: ' + line.strip()[:120]))
                    continue
                kind = found.group(1).replace('std::', '')
                quiet = len(args) > 2 and args[2] == 'false'
                names = resolve_names(args[0], name, literal_index[name])
                # "whole": the complete name is one string literal in the code (so it is text inside the built
                # program). False only for names glued together from pieces when the server runs.
                whole = not re.search(r'"\s*\+|\+\s*"', args[0])
                defaults = [args[1]]
                ternary = re.match(r'^(.+?)\?\s*(.+?)\s*:\s*(.+)$', args[1])
                if ternary and len(names) == 2:
                    defaults = [ternary.group(2).strip(), ternary.group(3).strip()]
                if names is None:
                    unresolved.append((name, number, 'name built at run time: ' + args[0]))
                    continue
                for index, option in enumerate(names):
                    reads[option].append({'file': name, 'line': number, 'type': kind, 'function': function,
                                          'default': defaults[index] if index < len(defaults) else defaults[0],
                                          'quiet': quiet, 'whole': whole})
    # WeekendBonus.<theme>.<rate>: the rate names come from the WeekendBonusRate("X") calls
    for rate, places in weekend_rates.items():
        for patch, number in places:
            reads['WeekendBonus.<theme>.' + rate].append({'file': patch, 'line': number, 'type': 'float', 'function': '',
                                                          'default': '1.0f', 'quiet': True, 'whole': False})
    return reads, unresolved


def resolve_names(expression, patch, text):
    """The option name(s) a first argument stands for, or None when it cannot be worked out."""
    expression = expression.strip()
    literal = re.match(r'^"([^"]+)"$', expression)
    if literal:
        return [literal.group(1)]
    ternary = re.match(r'^.+?\?\s*"([^"]+)"\s*:\s*"([^"]+)"$', expression)
    if ternary:
        return [ternary.group(1), ternary.group(2)]
    themed = re.match(r'^"WeekendBonus\."\s*\+\s*theme\s*\+\s*"\.(\w*)"(\s*\+\s*name)?$', expression)
    if themed:
        # ".Title" names itself; "." + name is a rate, and the rate names are added from WeekendBonusRate("X")
        return ['WeekendBonus.<theme>.' + themed.group(1)] if themed.group(1) else []
    joined = re.match(r'^(\w+)\s*\+\s*"([^"]+)"$', expression)
    if joined:
        # a prefix chosen between string literals on the line that declares the variable
        declared = re.search(r'\b%s\s*=\s*([^;]+);' % re.escape(joined.group(1)), text)
        prefixes = re.findall(r'"([A-Za-z][\w.]*)"', declared.group(1)) if declared else []
        return [prefix + joined.group(2) for prefix in prefixes] or None
    plain = re.match(r'^(\w+)$', expression)
    if plain:
        # a variable assigned from string literals elsewhere in the same patch
        found = re.findall(r'\b%s\s*=\s*"([A-Za-z][\w.]*\.[\w.]+)"' % re.escape(plain.group(1)), text)
        return sorted(set(found)) or None
    member = re.match(r'^\w+\.(\w+)$', expression)
    if member:
        # a table of { ..., "Option.Name" } rows; take every dotted literal in the patch
        found = re.findall(r'\{[^{}\n]*"([A-Z][A-Za-z]*\.[A-Za-z.]+)"\s*\}', text)
        return sorted(set(found)) or None
    return None


# --------------------------------------------------------------------------- CHANGES.md
def parse_changes(path):
    """Rows of the code patch table: (script, change, setting cell, line number)."""
    rows = []
    script = ''
    in_table = False
    with open(path, encoding='utf-8') as handle:
        for number, line in enumerate(handle, 1):
            if line.startswith('| Script / patch'):
                in_table = True
                continue
            if in_table and not line.startswith('|'):
                in_table = False
            if not in_table or line.startswith('|---'):
                continue
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if len(cells) < 3:
                continue
            if cells[0]:
                script = cells[0]
            rows.append({'script': script, 'change': ' | '.join(cells[1:-1]), 'setting': cells[-1], 'line': number})
    return rows


def setting_tokens(text):
    """Option names in a Setting cell: backticked words with a dot that are not file names."""
    tokens = []
    for token in re.findall(r'`([^`]+)`', text):
        if '.' in token and '/' not in token and not token.startswith('.') \
                and not re.search(r'\.(sql|ps1|py|patch|md|txt|cmd)$', token):
            tokens.append(token)
    return tokens


def token_matches(token, names):
    pattern = re.escape(token).replace(r'\*', r'[\w.<>]*').replace('<theme>', r'[\w<>]+')
    pattern = pattern.replace(re.escape('<theme>'), r'[\w<>]+')
    whole = re.compile('^' + pattern + '$')
    return [name for name in names if whole.match(name)]


# --------------------------------------------------------------------------- upstream (.dist and sources)
def load_dists(directories):
    """conf file name (lower case, no folder) -> {option: default as written}, from every *.conf.dist found."""
    dists = {}
    for top in directories:
        for folder, _dirs, files in os.walk(top):
            if os.sep + '.git' in folder:
                continue
            for name in files:
                if not name.endswith('.conf.dist'):
                    continue
                keys = dists.setdefault(name[:-5].lower(), OrderedDict())
                with open(os.path.join(folder, name), encoding='utf-8', errors='replace') as handle:
                    for line in handle:
                        found = DIST_KEY.match(line)
                        if not found:
                            continue
                        live = not line.lstrip().startswith('#')
                        # an active line beats a commented-out example of the same option
                        if found.group(1) not in keys or live:
                            keys[found.group(1)] = found.group(2)
    return dists


def names_in_sources(directories, names):
    """Which of these option names appear as text in upstream C++ (the kit does the same against worldserver.exe)."""
    wanted = {name: name.encode('utf-8') for name in names}
    seen = set()
    if not wanted:
        return seen
    for top in directories:
        for folder, _dirs, files in os.walk(top):
            if os.sep + '.git' in folder:
                continue
            for name in files:
                if not name.endswith(('.cpp', '.h', '.hpp')):
                    continue
                try:
                    with open(os.path.join(folder, name), 'rb') as handle:
                        data = handle.read()
                except OSError:
                    continue
                for option, needle in wanted.items():
                    if option not in seen and needle in data:
                        seen.add(option)
                if len(seen) == len(wanted):
                    return seen
    return seen


def prefix_families(directories):
    """Option prefixes the server reads as a family (GetKeysByString("Logger.")): any name under one is read."""
    found = set()
    pattern = re.compile(rb'GetKeysByString\(\s*"([A-Za-z.]+\.)"')
    for top in directories:
        for folder, _dirs, files in os.walk(top):
            if os.sep + '.git' in folder:
                continue
            for name in files:
                if name.endswith('.cpp'):
                    try:
                        with open(os.path.join(folder, name), 'rb') as handle:
                            found.update(m.decode() for m in pattern.findall(handle.read()))
                    except OSError:
                        pass
    return found


def repo_script_readers(repo, names):
    """Settings our own scripts read from the config files (the website's status service, patch night)."""
    readers = defaultdict(list)
    for folder in ('signup', 'patch-night', 'vm', 'launcher'):
        top = os.path.join(repo, folder)
        if not os.path.isdir(top):
            continue
        for name in sorted(os.listdir(top)):
            if not name.endswith(('.py', '.ps1')):
                continue
            with open(os.path.join(top, name), encoding='utf-8', errors='replace') as handle:
                text = handle.read()
            for option in names:
                if re.search(r'["\']%s["\']' % re.escape(option), text):
                    readers[option].append('%s/%s' % (folder, name))
    return readers


def checkout_ids(directories):
    """'name@shortsha' for every git checkout directly under the upstream folders (provenance only)."""
    ids = []
    for top in directories:
        paths = [top] if os.path.isdir(os.path.join(top, '.git')) else \
            [os.path.join(top, name) for name in sorted(os.listdir(top))]
        for path in paths:
            if os.path.isdir(os.path.join(path, '.git')):
                sha = run_git(path, ['rev-parse', '--short=10', 'HEAD'])
                url = run_git(path, ['config', '--get', 'remote.origin.url']) or ''
                label = url.strip().replace('https://github.com/', '').replace('.git', '') or os.path.basename(path)
                ids.append('%s@%s' % (label, (sha or '?').strip()))
    return sorted(set(ids))


# --------------------------------------------------------------------------- git history
def settings_history(repo, relative, first_parent):
    """key -> [(short hash, date, subject, old value or None, new value or None)] oldest first."""
    args = ['log', '--reverse', '--date=short', '--format=@@C %h %ad %s', '-p', '-U0']
    args += ['--first-parent', '-m'] if first_parent else ['--no-merges']
    text = run_git(repo, args + ['HEAD', '--', relative])
    history = defaultdict(list)
    if text is None:
        return history
    commit = None
    plus, minus = {}, {}

    def flush():
        for key in list(plus) + [k for k in minus if k not in plus]:
            old, new = minus.get(key), plus.get(key)
            if old != new:
                history[key].append(commit + (old, new))

    for line in text.split('\n'):
        if line.startswith('@@C '):
            if commit:
                flush()
            parts = line[4:].split(' ', 2)
            commit = (parts[0], parts[1], parts[2] if len(parts) > 2 else '')
            plus, minus = {}, {}
        elif line.startswith('+') and not line.startswith('+++'):
            found = ENTRY.match(line[1:])
            if found and not line[1:].lstrip().startswith('#'):
                plus[found.group(2)] = found.group(3)
        elif line.startswith('-') and not line.startswith('---'):
            found = ENTRY.match(line[1:])
            if found and not line[1:].lstrip().startswith('#'):
                minus[found.group(2)] = found.group(3)
    if commit:
        flush()
    return history


def pull_request_of(merges, key, value, date):
    """The merged PR that brought this value of this setting to main (best effort: same value, same day or later)."""
    for _short, when, subject, _old, new in merges.get(key, []):
        if new == value and when >= date:
            number = re.search(r'#(\d+)', subject)
            return ('#' + number.group(1)) if number else 'no PR'
    return ''


def option_first_commits(repo, names):
    """option name -> (short hash, date) of the first commit on main's first-parent line that adds it to patches/."""
    text = run_git(repo, ['log', '--reverse', '--first-parent', '-m', '--date=short', '--format=@@C %h %ad %s',
                          '-p', '-U0', 'HEAD', '--', 'patches'])
    first = {}
    if text is None:
        return first
    # WeekendBonus.<theme>.X is looked for as the literal "X" next to WeekendBonusRate
    needles = {}
    for name in names:
        if name.startswith('WeekendBonus.<theme>.'):
            tail = name.rsplit('.', 1)[1]
            needles[name] = '".Title"' if tail == 'Title' else '"%s"' % tail
        else:
            needles[name] = '"%s"' % name
    commit = None
    for line in text.split('\n'):
        if line.startswith('@@C '):
            parts = line[4:].split(' ', 2)
            commit = (parts[0], parts[1])
            continue
        if not line.startswith('+') or line.startswith('+++'):
            continue
        if '"' not in line:
            continue
        flat = line.replace('`"', '"')
        for name, needle in needles.items():
            if name not in first and needle in flat:
                first[name] = commit
        # the two halves of a name built from a prefix ("Battleground.Spoils" + "CasePercent")
        for name in names:
            if name not in first and '.' in name:
                for cut in ('CasePercent', 'GoldenPackPercent', 'PackPercent'):
                    if name.endswith(cut) and ('"%s"' % name[:-len(cut)]) in flat:
                        first[name] = commit
    return first


def build_tags(repo):
    """[(build number, tag)] sorted by build number, from the wcme-server-*-buildN release tags."""
    text = run_git(repo, ['tag', '--list', 'wcme-server-*'])
    tags = []
    for tag in (text or '').split():
        number = re.search(r'-build(\d+)$', tag)
        if number:
            tags.append((int(number.group(1)), tag))
    return sorted(tags)


def first_build_with(repo, commit, tags, cache):
    if commit not in cache:
        cache[commit] = ''
        for _number, tag in tags:
            done = subprocess.run(['git', '-C', repo, 'merge-base', '--is-ancestor', commit, tag],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if done.returncode == 0:
                cache[commit] = tag
                break
    return cache[commit]


def unmerged_branches(repo, main_lines, main_options):
    """Settings lines and option reads that exist only on branches not merged into HEAD."""
    refs = run_git(repo, ['for-each-ref', '--format=%(refname:short)', 'refs/remotes/origin'])
    found = []
    for ref in sorted((refs or '').split()):
        if ref.endswith('/HEAD') or ref == 'origin':
            continue
        merged = subprocess.run(['git', '-C', repo, 'merge-base', '--is-ancestor', ref, 'HEAD'],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if merged.returncode == 0:
            continue
        base = run_git(repo, ['merge-base', 'HEAD', ref])
        if not base:
            continue
        diff = run_git(repo, ['diff', '-U0', base.strip(), ref, '--', 'server-settings/server-settings.txt', 'patches'])
        if not diff:
            continue
        lines, options = [], set()
        for line in diff.split('\n'):
            if not line.startswith('+') or line.startswith('+++'):
                continue
            body = line[1:]
            entry = ENTRY.match(body)
            if entry and not body.lstrip().startswith('#') and '.conf' in entry.group(1):
                if main_lines.get(entry.group(2)) != entry.group(3) and (entry.group(2), entry.group(3)) not in lines:
                    lines.append((entry.group(2), entry.group(3)))
            for option in re.findall(r'GetOption<[^>]+>\(\s*`?"([^"`]+)`?"', body):
                if option not in main_options:
                    options.add(option)
        when = run_git(repo, ['log', '-1', '--date=short', '--format=%ad', ref]) or ''
        if lines or options:
            found.append({'branch': ref.replace('origin/', '', 1), 'date': when.strip(), 'lines': lines,
                          'options': sorted(options)})
    return found


# --------------------------------------------------------------------------- the catalogue
def build(repo, upstream, with_branches=True):
    settings_path = os.path.join(repo, 'server-settings', 'server-settings.txt')
    entries, commented, problems = parse_settings(settings_path)
    reads, unresolved = scan_patches(os.path.join(repo, 'patches'))
    changes = parse_changes(os.path.join(repo, 'CHANGES.md'))

    by_key = defaultdict(list)
    for entry in entries:
        by_key[entry['key']].append(entry)
    real = [e for e in entries if e['file'].lower() not in PSEUDO_FILES]

    # Names known from config templates: the one in this repository, plus any upstream checkouts given.
    dists = load_dists([os.path.join(repo, 'ollama-chat')] + list(upstream))
    have_upstream = bool(upstream)

    def dist_for(conf_file):
        return dists.get(conf_file.replace('/', '\\').split('\\')[-1].lower())

    our_names = sorted(reads)
    themes = []
    for entry in by_key.get('WeekendBonus.Rotation', []):
        themes = [t for t in entry['value'].strip('"').split(',') if t]

    def expand(name):
        """WeekendBonus.<theme>.X -> the real lines in the file, one per theme that sets it."""
        if '<theme>' not in name:
            return [name]
        return [name.replace('<theme>', theme) for theme in themes if name.replace('<theme>', theme) in by_key]

    read_by_patch = set()
    for name in our_names:
        read_by_patch.update(expand(name))
        read_by_patch.add(name)

    # History
    commits = settings_history(repo, 'server-settings/server-settings.txt', first_parent=False)
    merges = settings_history(repo, 'server-settings/server-settings.txt', first_parent=True)
    first_commit = option_first_commits(repo, our_names)
    tags = build_tags(repo)
    tag_cache = {}
    head = (run_git(repo, ['log', '-1', '--date=short', '--format=%h %ad', 'HEAD']) or 'unknown').strip()
    newest_tag = tags[-1][1] if tags else ''

    def set_by(key, value):
        """'abc1234 2026-11-09 (#123)' for the commit that gave this setting its current value, and its first one."""
        events = commits.get(key, [])
        if not events:
            return '', ''
        added = events[0]
        current = None
        for event in events:
            if event[4] == value:
                current = event
        if current is None:
            current = events[-1]

        def show(event):
            pr = pull_request_of(merges, key, event[4], event[1])
            return '%s %s%s' % (event[0], event[1], (' (%s)' % pr) if pr else '')
        return show(added), show(current)

    out = []
    w = out.append
    w('# Settings catalogue (generated)')
    w('')
    w('Generated by `scripts/settings_catalogue.py` from the repository at commit `%s`. Do not edit by hand:' % head)
    w('change the sources and run the script again. Volatile by nature: every merged settings PR changes it.')
    w('')
    w('- Settings lines in `server-settings/server-settings.txt`: **%d** (plus %d `realm` / `realmlist` lines the kit '
      'handles specially, and %d commented-out candidates).' % (len(real), len(entries) - len(real), len(commented)))
    w('- Options our patches read (`GetOption` in `patches/`): **%d** names.' % len(our_names))
    w('- Newest release tag in this clone: `%s`.' % (newest_tag or 'none found'))
    if have_upstream:
        w('- Upstream checkouts were given: %d config templates (`*.conf.dist`) read, and upstream C++ searched for '
          'names no template lists. Checkouts: %s.' % (len(dists), ', '.join('`%s`' % i for i in checkout_ids(upstream))
                                                       or 'not git checkouts'))
    else:
        w('- **No upstream checkout was given** (`--upstream`): only `ollama-chat/mod_ollama_chat.conf.dist` could be '
          'checked. Table 2\'s "Known upstream" column is therefore mostly "not checked".')
    w('')
    w('Contents: [1. Options our patches add](#1-options-our-patches-add) | '
      '[2. Upstream options we set on purpose](#2-upstream-options-we-set-on-purpose) | '
      '[3. Performance-relevant settings](#3-performance-relevant-settings) | '
      '[4. Mismatches](#4-mismatches) | [5. Not on main](#5-not-on-main-experimental)')
    w('')

    # ---- Table 1
    w('## 1. Options our patches add')
    w('')
    w('One row per option name read by `sConfigMgr->GetOption<T>("Name", default)` in a line our patches add.')
    w('"Default in code" is what the server uses when no config file sets the option. "Quiet" means the read passes')
    w('`false` as third argument, so a missing line gives no "Missing property" warning at start-up. "First build" is')
    w('the oldest release tag that contains the commit which first added the name to `patches/`; an older build')
    w('ignores the line. "Also upstream" marks names an upstream template or source already has (our patch only reads')
    w('them). Status: **production** = set in server-settings.txt on main; **on code default** = patch is on main but')
    w('the file has no line for it.')
    w('')
    w('| Option | Type | Default in code | Value in server-settings.txt | Config file | Read in (patch:line) | '
      'First build | Status | What it does |')
    w('|---|---|---|---|---|---|---|---|---|')
    upstream_known = set()
    if have_upstream:
        every_dist = set()
        for keys in dists.values():
            every_dist.update(keys)
        plain = [n for n in our_names if '<' not in n]
        upstream_known = (set(plain) & every_dist) | names_in_sources(upstream, [n for n in plain if n not in every_dist])
    absent = []
    for name in our_names:
        sites = reads[name]
        kinds = sorted({s['type'] for s in sites})
        defaults = []
        for site in sites:
            if site['default'] not in defaults:
                defaults.append(site['default'])
        lines = [e for real_name in expand(name) for e in by_key.get(real_name, [])]
        if lines:
            if '<theme>' in name:
                value = ', '.join('%s=%s' % (e['key'].split('.')[1], e['value']) for e in lines)
            else:
                value = lines[-1]['value']
            conf = lines[-1]['file']
            status = 'production'
        else:
            value, conf, status = None, '', 'on code default'
            absent.append(name)
        where = ', '.join('%s:%d' % place for place in sorted({(s['file'], s['line']) for s in sites})[:4])
        if len({(s['file'], s['line']) for s in sites}) > 4:
            where += ', ...'
        commit = first_commit.get(name)
        if commit:
            tag = first_build_with(repo, commit[0], tags, tag_cache)
            build_note = ('%s (%s)' % (tag.replace('wcme-server-', ''), commit[0])) if tag else \
                'NOT IN A BUILD YET (%s, %s)' % commit
        else:
            build_note = 'unknown'
        what = ''
        for row in changes:
            for token in setting_tokens(row['setting']):
                if token_matches(token, [name] + expand(name)):
                    what = row['change']
                    break
            if what:
                break
        if not what and lines:
            what = lines[0]['comment']
        notes = []
        if all(s['quiet'] for s in sites):
            notes.append('Quiet.')
        if name in upstream_known:
            notes.append('Also upstream.')
        if len(defaults) > 1:
            notes.append('Defaults differ between reads.')
        w('| %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (
            code(name), cell(', '.join(kinds)), code(' / '.join(defaults), 60),
            code(value, 60) if value is not None else '(no line)', code(conf) if conf else '',
            cell(where), cell(build_note), status,
            cell(' '.join(notes + [first_sentences(what, 200)]))))
    w('')
    if unresolved:
        w('**Reads the script could not resolve to a name** (look at them by hand and teach `resolve_names`):')
        w('')
        for patch, number, why in unresolved:
            w('- `%s:%d` %s' % (patch, number, cell(why)))
        w('')

    # ---- Table 2
    w('## 2. Upstream options we set on purpose')
    w('')
    w('Every other line of `server-settings.txt`, grouped by the file\'s own section headings, in file order. "Reason"')
    w('is the start of the comment above the line in the file (read the file for the whole of it). "First set" and')
    w('"Current value since" are the commits that added the line and gave it today\'s value, with the merged PR.')
    if have_upstream:
        w('"Upstream default" is the value in the upstream config template at the pinned commit; "not in template"')
        w('means no template lists the name, so see section 4. Where two upstream templates share a file name')
        w('(`mod_ahbot.conf.dist` ships with the core and with SQUID\'s bots) the value shown is from whichever was')
        w('read last; check the installed `.dist` on the VM before relying on an auction-bot default.')
    w('')
    section = None
    for entry in real:
        if entry['key'] in read_by_patch:
            continue
        if entry['section'] != section:
            section = entry['section']
            w('')
            w('### %s' % section)
            w('')
            w('| Config file | Option | Value | %sFirst set | Current value since | Reason (from the file) |'
              % ('Upstream default | ' if have_upstream else 'Known upstream | '))
            w('|---|---|---|---|---|---|')
        dist = dist_for(entry['file'])
        if dist is not None and entry['key'] in dist:
            known = code(dist[entry['key']], 30) if have_upstream else 'yes (.dist in repo)'
        elif have_upstream:
            known = 'not in template'
        else:
            known = 'not checked'
        added, current = set_by(entry['key'], entry['value'])
        w('| %s | %s | %s | %s | %s | %s | %s |' % (
            code(entry['file']), code(entry['key']), code(entry['value'], 48), known,
            cell(added), cell(current if current != added else ('unchanged' if added else '')),
            cell(first_sentences(entry['comment'], 200))))
    w('')

    # ---- Table 3
    w('## 3. Performance-relevant settings')
    w('')
    w('Current value and every recorded change, oldest first (commit, date, merged PR where found, old -> new).')
    w('"(no line)" means the file does not set it, so the server uses the installed config file\'s value or its')
    w('built-in default.')
    w('')
    w('| Option | Value in server-settings.txt | %sHistory in this repository |'
      % ('Upstream template default | ' if have_upstream else ''))
    w('|---|---|%s---|' % ('---|' if have_upstream else ''))
    for key in PERFORMANCE_KEYS:
        lines = by_key.get(key, [])
        value = code(lines[-1]['value'], 48) if lines else '(no line)'
        events = []
        for short, when, _subject, old, new in commits.get(key, []):
            pr = pull_request_of(merges, key, new, when) if new is not None else ''
            change = ('added as %s' % new) if old is None else ('removed (was %s)' % old) if new is None \
                else '%s -> %s' % (old, new)
            events.append('%s %s%s: %s' % (short, when, (' ' + pr) if pr else '', change))
        default = ''
        if have_upstream:
            hit = ''
            for keys in dists.values():
                if key in keys:
                    hit = keys[key]
                    break
            default = '%s | ' % (code(hit, 30) if hit != '' else 'not in a template')
        w('| %s | %s | %s%s |' % (code(key), value, default, cell('; '.join(events) or 'never set here', 600)))
    w('')

    ticking = sorted({(site['file'], site['line'], name, site['function'])
                      for name in our_names for site in reads[name] if site['function'] in PER_TICK_FUNCTIONS})
    w('### 3b. Our option reads that sit directly inside a per-tick hook (%d) - candidates, cost not measured' % len(ticking))
    w('')
    w('`OnPlayerUpdate` runs for every player object on every world tick, and each bot is a player object. A')
    w('`GetOption` there is a text look-up and a conversion per call. The repository names "a setting read on a hot')
    w('path without caching" as a common patch fault (docs/agents/context/patches.md). Found by the enclosing')
    w('function name only: a read reached through a helper (`Enabled()`, `Applies()`) is not listed, and a read')
    w('behind a cheap race or timer check runs far less often than the hook does. Nobody has measured what these')
    w('cost; treat the list as where to look, not as a finding.')
    w('')
    for patch, number, name, function in ticking:
        w('- `%s:%d` %s in `%s`' % (patch, number, code(name), function))
    if not ticking:
        w('- none')
    w('')

    # ---- Mismatches
    w('## 4. Mismatches')
    w('')
    hard = list(problems)
    w('### 4a. Read by a patch, no line in server-settings.txt (%d)' % len(absent))
    w('')
    w('The server uses the default in code. Not wrong by itself, but CHANGES.md says every setting a patch reads is')
    w('listed in the file, and a non-quiet read logs "Missing property" at each start.')
    w('')
    for name in absent:
        sites = reads[name]
        w('- %s: default %s, %s (%s:%d)' % (code(name), code(sites[0]['default'], 60),
                                           'quiet' if all(s['quiet'] for s in sites) else 'warns at start',
                                           sites[0]['file'], sites[0]['line']))
    if not absent:
        w('- none')
    w('')

    unknown = []
    candidates = []
    for entry in real:
        if entry['key'] in read_by_patch:
            continue
        dist = dist_for(entry['file'])
        if dist is not None and entry['key'] in dist:
            continue
        candidates.append(entry)
    in_source = names_in_sources(upstream, sorted({e['key'] for e in candidates})) if have_upstream else set()
    any_dist = set()
    for keys in dists.values():
        any_dist.update(keys)
    families = prefix_families(upstream) if have_upstream else set()
    script_readers = repo_script_readers(repo, sorted({e['key'] for e in candidates}))
    elsewhere, by_family, by_script = [], [], []
    for entry in candidates:
        if entry['key'] in in_source:
            continue
        if entry['key'] in script_readers:
            by_script.append(entry)
            continue
        family = [f for f in families if entry['key'].startswith(f)]
        if family:
            by_family.append((entry, family[0]))
            continue
        if have_upstream and entry['key'] in any_dist:
            elsewhere.append(entry)
            continue
        unknown.append(entry)
    w('### 4b. In server-settings.txt, but no patch and no known config template reads it (%d)' % len(unknown))
    w('')
    if have_upstream:
        w('Checked against our patches, every upstream `*.conf.dist` given, and the text of the upstream C++ given.')
        w('A name here is a typo, was renamed or removed upstream, or lives in a source that was not given (a sparse')
        w('checkout hides files). The authority is the VM\'s `server-settings\\settings-report.txt`, which checks the')
        w('installed `.dist` files and `worldserver.exe` itself.')
    else:
        w('**Weak check: no upstream checkout was given**, so this lists every line our patches do not read and')
        w('`mod_ollama_chat.conf.dist` does not list. Most are ordinary upstream options. Run again with `--upstream`,')
        w('or read `server-settings\\settings-report.txt` on the VM, before calling any of them unknown.')
    w('')
    for entry in unknown:
        w('- %s | %s (line %d)' % (code(entry['file']), code(entry['key']), entry['line']))
    if not unknown:
        w('- none')
    w('')
    if elsewhere:
        w('### 4c. Set in a different config file than the template that lists it (%d)' % len(elsewhere))
        w('')
        w('The server loads every config file into one table, so these still work; noted in case the kit\'s `.dist`')
        w('check reports them.')
        w('')
        for entry in elsewhere:
            w('- %s | %s (line %d)' % (code(entry['file']), code(entry['key']), entry['line']))
        w('')

    # The kit on the VM calls a setting known when its .dist lists it or the whole name is text inside
    # worldserver.exe. Names our patches glue together at run time, names read by prefix and names only a script
    # reads are in neither, so the kit will list them as unknown although they work.
    glued = []
    for name in our_names:
        if any(site['whole'] for site in reads[name]) or name in upstream_known:
            continue
        for real_name in expand(name):
            for entry in by_key.get(real_name, []):
                dist = dist_for(entry['file'])
                if not (dist is not None and entry['key'] in dist):
                    glued.append((entry, 'name built at run time in %s' % reads[name][0]['file']))
    if have_upstream:      # without the templates, ordinary upstream options would be mistaken for these
        glued += [(entry, 'read by prefix %s*' % family) for entry, family in by_family]
        glued += [(entry, 'read by %s, not by the server' % ', '.join(script_readers[entry['key']]))
                  for entry in by_script]
    glued.sort(key=lambda pair: pair[0]['line'])
    w('### 4g. Working settings the VM\'s settings check cannot see (%d) - PREDICTION' % len(glued))
    w('')
    w('`Apply-ServerSettings.ps1` calls a setting known when the installed `.dist` lists it or the whole name appears')
    w('as text inside `worldserver.exe`. The names below are in neither place, for the reason given, so expect them')
    w('under "Unknown" in `server-settings\\settings-report.txt` on every run. Worked out from the code; NOT verified')
    w('against a real report. Treat this list as the expected baseline: an unknown name that is not on it is the')
    w('real finding.%s' % ('' if have_upstream else ' (Without `--upstream` only the run-time names can be listed.)'))
    w('')
    for entry, why in glued:
        w('- %s | %s (line %d): %s' % (code(entry['file']), code(entry['key']), entry['line'], why))
    if not glued:
        w('- none')
    w('')

    all_names = set(our_names) | {e['key'] for e in real} | {c['key'] for c in commented}
    orphans = []
    for row in changes:
        for token in setting_tokens(row['setting']):
            if not token_matches(token, all_names):
                orphans.append((row, token))
    w('### 4d. CHANGES.md "Setting" column names that match nothing (%d)' % len(orphans))
    w('')
    w('A name in the table that no patch reads and server-settings.txt does not have.')
    w('')
    for row, token in orphans:
        w('- CHANGES.md:%d %s names %s' % (row['line'], cell(row['script'], 60), code(token)))
    if not orphans:
        w('- none')
    w('')

    named = set()
    for row in changes:
        for token in setting_tokens(row['setting']):
            named.update(token_matches(token, our_names))
            for name in our_names:
                if token_matches(token, expand(name)):
                    named.add(name)
    undocumented = [n for n in our_names if n not in named and n not in upstream_known]
    w('### 4e. Options our patches read that the CHANGES.md "Setting" column never names (%d)' % len(undocumented))
    w('')
    w('CHANGES.md asks for a line per change and its setting. A row that says "always on" or names only the first')
    w('of a family leaves the option findable only here and in server-settings.txt.')
    w('')
    for name in undocumented:
        w('- %s (%s)' % (code(name), reads[name][0]['file']))
    if not undocumented:
        w('- none')
    w('')

    duplicates = [(key, lines) for key, lines in by_key.items()
                  if len({(e['file'].lower()) for e in lines}) < len(lines)]
    unrecorded = [e for e in real if e['value'] == '?']
    w('### 4f. File hygiene')
    w('')
    w('- Lines that are neither a comment nor a setting: %d%s' % (
        len(problems), ''.join('\n  - ' + cell(p) for p in problems)))
    w('- Settings listed twice for the same config file (the later line wins): %d%s' % (
        len(duplicates), ''.join('\n  - %s on lines %s' % (code(k), ', '.join(str(e['line']) for e in v))
                                 for k, v in duplicates)))
    w('- Values still `?` (not recorded; the kit skips them): %d%s' % (
        len(unrecorded), ''.join('\n  - %s (line %d)' % (code(e['key']), e['line']) for e in unrecorded)))
    w('- Patch reads with a name the script could not resolve: %d' % len(unresolved))
    w('')
    hard += ['duplicate setting %s' % k for k, _v in duplicates]
    hard += ['CHANGES.md names %s, which nothing reads' % t for _r, t in orphans]
    hard += ['unresolved read %s:%d' % (p, n) for p, n, _why in unresolved]

    # ---- Not on main
    w('## 5. Not on main (experimental)')
    w('')
    w('### 5a. Commented-out lines in server-settings.txt (%d)' % len(commented))
    w('')
    for item in commented:
        w('- line %d: %s | %s = %s. %s' % (item['line'], code(item['file']), code(item['key']), code(item['value'], 40),
                                          cell(first_sentences(item['comment'], 160))))
    if not commented:
        w('- none')
    w('')
    w('### 5b. Settings lines and option reads that exist only on unmerged branches')
    w('')
    if with_branches:
        branches = unmerged_branches(repo, {e['key']: e['value'] for e in real}, set(our_names))
        w('What each branch adds or changes against the point where it left main (`git diff <merge-base> <branch>`),')
        w('in `server-settings.txt` and `patches/`, leaving out anything main has since gained with the same value.')
        w('None of this is live. Branches of the old-core `for-083` family carry their own copy of the file; read')
        w('them as history, not as proposals. A branch with nothing left to show is not listed.')
        w('')
        w('| Branch | Last commit | Settings lines added or changed | New option reads in patches |')
        w('|---|---|---|---|')
        for branch in branches:
            lines = '; '.join('%s = %s' % (k, cell(v, 30)) for k, v in branch['lines'][:12])
            if len(branch['lines']) > 12:
                lines += '; ... (%d in all)' % len(branch['lines'])
            options = ', '.join(branch['options'][:12])
            if len(branch['options']) > 12:
                options += ', ... (%d in all)' % len(branch['options'])
            w('| `%s` | %s | %s | %s |' % (branch['branch'], branch['date'], cell(lines) or '-', cell(options) or '-'))
        if not branches:
            w('| (none found; are the `origin/*` branches fetched?) | | | |')
    else:
        w('Skipped (`--no-branches`).')
    w('')
    return '\n'.join(out) + '\n', hard, {'absent': absent, 'unknown': unknown, 'orphans': orphans, 'glued': glued,
                                         'undocumented': undocumented, 'unresolved': unresolved}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--repo', default=os.path.normpath(os.path.join(here, '..', '..', '..', '..')),
                        help='repository root (default: four folders above this script)')
    parser.add_argument('--upstream', action='append', default=[],
                        help='folder holding upstream checkouts (searched for *.conf.dist and C++); repeatable')
    default_out = os.path.normpath(os.path.join(here, '..', 'references', 'settings-catalogue.md'))
    parser.add_argument('--out', default=default_out, help='file to write (default: the shipped reference file)')
    parser.add_argument('--stdout', action='store_true', help='print the catalogue instead of writing a file')
    parser.add_argument('--check', action='store_true', help='do not write; exit 1 if --out is out of date')
    parser.add_argument('--lint', action='store_true', help='print the mismatch counts; exit 1 on a hard problem')
    parser.add_argument('--no-branches', action='store_true', help='skip the unmerged-branch scan (faster)')
    options = parser.parse_args()

    repo = os.path.abspath(options.repo)
    if not os.path.isfile(os.path.join(repo, 'server-settings', 'server-settings.txt')):
        sys.exit('No server-settings/server-settings.txt under %s; pass --repo.' % repo)
    for folder in options.upstream:
        if not os.path.isdir(folder):
            sys.exit('--upstream %s is not a folder.' % folder)
    upstream = [os.path.abspath(u) for u in options.upstream]
    checkouts = upstream_checkouts(upstream)
    patched = [(path, why) for path, why in checkouts if why]
    if upstream:
        print('Upstream checkouts read (%d):' % len(checkouts), file=sys.stderr)
        for path, why in checkouts:
            sha = (run_git(path, ['rev-parse', '--short=10', 'HEAD']) or '?').strip()
            print('  %s @ %s%s' % (path, sha, '   LOOKS PATCHED: ' + why if why else ''), file=sys.stderr)
        if not checkouts:
            print('  none: no git checkout in or directly under the folders given.', file=sys.stderr)
        print('Compare the commits with `python3 -I scripts/resolve_release.py latest` (core_sha, squid_sha, '
              'dungeon_sha, bots_sha).', file=sys.stderr)
    if patched:
        print('WARNING: %d upstream checkout(s) look patched. Patched sources hide real mismatches; use unpatched '
              'clones at the pinned commits.' % len(patched), file=sys.stderr)
    text, hard, found = build(repo, upstream, with_branches=not (options.no_branches or options.lint))
    text = scrub(text)

    if options.lint:
        print('Read by a patch, no line in server-settings.txt: %d' % len(found['absent']))
        for name in found['absent']:
            print('  ' + name)
        print('In server-settings.txt, read by no patch and in no known template: %d%s' % (
            len(found['unknown']), '' if options.upstream else '  (weak: no --upstream given)'))
        if options.upstream:
            for entry in found['unknown']:
                print('  %s | %s' % (entry['file'], entry['key']))
        print('Working settings the VM check will list as unknown (prediction): %d' % len(found['glued']))
        print('Patch options CHANGES.md never names: %d' % len(found['undocumented']))
        for name in found['undocumented']:
            print('  ' + name)
        print('Hard problems: %d' % len(hard))
        for item in hard:
            print('  ' + item)
        return 1 if hard else 0

    out = os.path.abspath(options.out)
    if options.stdout:
        sys.stdout.write(text)
        return 0
    if options.check:
        try:
            with open(out, encoding='utf-8') as handle:
                current = handle.read()
        except OSError:
            current = ''
        if current == text:
            print('Up to date: %s' % out)
            return 0
        print('OUT OF DATE: %s differs from what the script produces now. Run it without --check.' % out)
        return 1
    if not upstream and out == os.path.abspath(default_out):
        print('REFUSED: no --upstream given, so this would replace the shipped catalogue with a weak one.\n'
              'Give the four pinned, unpatched clones (--upstream DIR, four times), or use --stdout, or --out FILE '
              'for a scratch copy. Nothing was written.', file=sys.stderr)
        return 2
    if patched:
        print('REFUSED: an upstream checkout looks patched (see above). Nothing was written.', file=sys.stderr)
        return 2
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(text)
    print('Wrote %s (%d lines). Hard problems: %d.' % (out, text.count('\n'), len(hard)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
