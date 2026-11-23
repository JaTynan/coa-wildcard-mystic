#!/usr/bin/env python3
"""Static pre-flight for sql/enchants: catches the mistakes that make a file fail when patch night runs it.

Usage (from anywhere):  python3 -I enchant_sql_lint.py [path/to/sql/enchants] [--spellaffect-dbc path/to/SpellAffect.dbc]
Reads only. Python 3 standard library only. Exit code 1 when it finds an ERROR, 2 for a bad folder, 0 otherwise.
This script is the authority for reset and ownership modelling of sql/enchants; the full pre-merge check set is
listed in the skill wildcard-validation-and-qa. The files the reset cannot undo are listed in
references/reset-limits.md of this skill.

It does NOT replace the scratch-database run (it knows nothing about rows the core itself ships). It replays the
files in name order against an empty model of the keys this repository adds, twice, and reports:

  ERROR  duplicate key   a plain INSERT adds a key an earlier statement already added and nothing deleted in between.
                         MySQL stops that file at the error; patch night only logs a WARN and carries on.
  ERROR  not re-runnable a plain INSERT into spell_dbc / spell_proc whose key is neither listed in wcme_owned
                         (so 000-reset removes it before the next run) nor deleted earlier in the same file.
  ERROR  no WCME marker  a spell_linked_spell row whose comment does not start with 'WCME:' (000-reset would never
                         remove it, so the second run would add it again).
  ERROR  stock row id    a wcme_spellaffect_dbc row whose ID the server's SpellAffect.dbc already uses. A table row
                         REPLACES the file row with the same ID, so the stock modifier silently loses its target
                         (file 011 did this to ten rows until 23 Nov 2026). Without --spellaffect-dbc the check uses
                         the list below (the file's IDs from 900000 to 999999 on 23 Nov 2026) and refuses any ID
                         outside that range, where the file is dense. With it, the real file is read and the list
                         below is checked for staleness. The file is client data: never copy it into the repository.
  WARN   not in 000      a spell_script_names row whose ScriptName does not start with spell_wcme_ and is not
                         deleted in its own file (000-reset only clears spell_wcme_* names).
  NOTE                   statements it could not model (UPDATE, DELETE with a JOIN or sub-query) - read those by hand.
"""
import argparse
import re
import struct
import sys
from pathlib import Path

sys.dont_write_bytecode = True

# table -> number of leading (or named) columns that make its primary / unique key
KEYS = {
    'spell_dbc': ('ID',), 'spell_proc': ('SpellId',), 'wcme_owned': ('tbl', 'id'),
    'wcme_enchant_teach': ('enchant_spell',), 'wcme_enchant_override': ('enchant_spell',),
    'wcme_enchant_action': ('enchant_spell', 'rule'), 'wcme_spellaffect_dbc': ('ID',),
    'wcme_proc_target_cooldown': ('spell_id',), 'spell_script_names': ('spell_id', 'ScriptName'),
    'spell_linked_spell': ('spell_trigger', 'spell_effect', 'type'),
}
OWNED_TABLES = ('spell_dbc', 'spell_proc')

# IDs that SpellAffect.dbc itself uses inside the range our rows live in, as inclusive (first, last) pairs.
# Read from the server's file on 23 Nov 2026 (36,849 rows; 201 of them in this range). Re-check after a client
# data update with --spellaffect-dbc: the run prints a replacement list when this one is out of date.
OUR_ID_RANGE = (900000, 999999)
STOCK_SPELLAFFECT_IDS = (
    (901388, 901397), (912000, 912002), (918322, 918325), (918328, 918328), (918350, 918354), (918358, 918360),
    (918375, 918378), (918380, 918381), (918384, 918384), (918389, 918392), (918398, 918415), (918421, 918421),
    (918427, 918428), (918430, 918438), (918440, 918448), (918450, 918457), (918460, 918473), (918475, 918475),
    (918477, 918488), (918491, 918495), (918497, 918498), (918519, 918522), (918525, 918530), (918532, 918539),
    (918548, 918567), (918569, 918597), (918605, 918608), (929179, 929181), (938442, 938443), (975170, 975172),
    (975176, 975176), (999997, 999999),
)


def dbc_ids(path):
    """Returns the set of row IDs (first field) of a WDBC file."""
    data = Path(path).read_bytes()
    if data[:4] != b'WDBC' or len(data) < 20:
        sys.exit(f'Not a DBC file: {path}')
    rows, _fields, row_size, _strings = struct.unpack('<4I', data[4:20])
    if row_size < 4 or len(data) < 20 + rows * row_size:
        sys.exit(f'Damaged DBC file: {path}')
    return {struct.unpack_from('<I', data, 20 + i * row_size)[0] for i in range(rows)}


def as_ranges(ids):
    out = []
    for value in sorted(ids):
        if out and value == out[-1][1] + 1:
            out[-1][1] = value
        else:
            out.append([value, value])
    return tuple((a, b) for a, b in out)


def statements(text):
    """Splits SQL into statements at ';' outside quotes, dropping -- comments."""
    out, buf, quote, i, n = [], [], None, 0, len(text)
    while i < n:
        ch = text[i]
        if quote:
            buf.append(ch)
            if ch == '\\' and i + 1 < n:
                buf.append(text[i + 1]); i += 1
            elif ch == quote:
                if i + 1 < n and text[i + 1] == quote:
                    buf.append(quote); i += 1
                else:
                    quote = None
        elif ch == "'":
            quote = ch; buf.append(ch)
        elif ch == '-' and text.startswith('--', i):
            while i < n and text[i] != '\n':
                i += 1
            continue
        elif ch == ';':
            out.append(''.join(buf).strip()); buf = []
        else:
            buf.append(ch)
        i += 1
    tail = ''.join(buf).strip()
    if tail:
        out.append(tail)
    return [s for s in out if s]


def tuples(values):
    """Yields each (...) row of a VALUES list as a list of raw field strings."""
    depth, quote, field, row, i, n = 0, None, [], None, 0, len(values)
    while i < n:
        ch = values[i]
        if quote:
            field.append(ch)
            if ch == '\\' and i + 1 < n:
                field.append(values[i + 1]); i += 1
            elif ch == quote:
                if i + 1 < n and values[i + 1] == quote:
                    field.append(quote); i += 1
                else:
                    quote = None
        elif ch == "'":
            quote = ch; field.append(ch)
        elif ch == '(':
            depth += 1
            if depth == 1:
                row, field = [], []
            else:
                field.append(ch)
        elif ch == ')':
            depth -= 1
            if depth == 0:
                row.append(''.join(field).strip()); yield row; row = None
            else:
                field.append(ch)
        elif ch == ',' and depth == 1:
            row.append(''.join(field).strip()); field = []
        elif depth >= 1:
            field.append(ch)
        i += 1


def clean(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
        return value[1:-1].replace("''", "'")
    return value


INSERT = re.compile(r"^(INSERT IGNORE|INSERT|REPLACE)\s+INTO\s+`?(\w+)`?\s*(\(([^)]*)\))?\s*(VALUES|SELECT)\b(.*)$", re.S | re.I)
DELETE_IN = re.compile(r"^DELETE\s+FROM\s+`?(\w+)`?\s+WHERE\s+`?(\w+)`?\s*(?:IN\s*\(([^()]*)\)|=\s*('(?:[^']|'')*'|-?\d+))\s*"
                       r"(?:AND\s+`?(\w+)`?\s+LIKE\s+'([^']*)')?$", re.S | re.I)
DELETE_ALL = re.compile(r"^DELETE\s+FROM\s+`?(\w+)`?$", re.I)
DELETE_LIKE = re.compile(r"^DELETE\s+FROM\s+`?(\w+)`?\s+WHERE\s+`?(\w+)`?\s+LIKE\s+'([^']*)'$", re.I)


def like(pattern, text):
    regex = ''
    i = 0
    while i < len(pattern):
        ch = pattern[i]
        if ch == '\\' and i + 1 < len(pattern):
            regex += re.escape(pattern[i + 1]); i += 2; continue
        regex += '.*' if ch == '%' else '.' if ch == '_' else re.escape(ch)
        i += 1
    return re.fullmatch(regex, text, re.S) is not None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('folder', nargs='?', default=str(Path(__file__).resolve().parents[4] / 'sql' / 'enchants'),
                        help='the sql/enchants folder (default: the one in the repository this script sits in)')
    parser.add_argument('--spellaffect-dbc', metavar='FILE',
                        help="the server's SpellAffect.dbc (on the VM: C:\\Games\\CoA Server\\Data\\dbc). Checks "
                             'wcme_spellaffect_dbc IDs against the real file instead of the built-in list')
    args = parser.parse_args()
    folder = Path(args.folder)
    if not folder.is_dir():
        print(f'Not a folder: {folder}', file=sys.stderr)
        sys.exit(2)
    files = sorted(folder.glob('*.sql'))
    if not files:
        sys.exit(f'No .sql files in {folder}')
    parsed = [(f.name, statements(f.read_text(encoding='utf-8'))) for f in files]
    problems, notes = [], []

    stock_ids = dbc_ids(args.spellaffect_dbc) if args.spellaffect_dbc else None
    if stock_ids is not None:
        real = as_ranges(i for i in stock_ids if OUR_ID_RANGE[0] <= i <= OUR_ID_RANGE[1])
        if real != STOCK_SPELLAFFECT_IDS:
            problems.append(('WARN', 'enchant_sql_lint.py', 'STOCK_SPELLAFFECT_IDS is out of date for this '
                             f'SpellAffect.dbc; replace it with: {real}'))

    def stock_id_problem(value):
        if not value.isdigit():
            return f'wcme_spellaffect_dbc ID {value!r} is not a plain number'
        number = int(value)
        if stock_ids is not None:
            return f'stock row id: SpellAffect.dbc already has a row {number}; ours would replace it' \
                if number in stock_ids else None
        if not OUR_ID_RANGE[0] <= number <= OUR_ID_RANGE[1]:
            return (f'stock row id: wcme_spellaffect_dbc ID {number} is outside {OUR_ID_RANGE[0]}-{OUR_ID_RANGE[1]}, '
                    f'where it cannot be checked without --spellaffect-dbc')
        if any(first <= number <= last for first, last in STOCK_SPELLAFFECT_IDS):
            return f'stock row id: SpellAffect.dbc already has a row {number}; ours would replace it'
        return None

    # Every key any file registers in wcme_owned: 000-reset removes those rows before the next run.
    owned = set()
    for name, stmts in parsed:
        for stmt in stmts:
            m = INSERT.match(stmt)
            if m and m.group(2) == 'wcme_owned' and m.group(5).upper() == 'VALUES':
                for row in tuples(m.group(6)):
                    owned.add((clean(row[0]), clean(row[1])))

    state = {table: set() for table in KEYS}
    for run in (1, 2):
        if run == 2:   # what 000-reset leaves behind from run 1
            state['spell_linked_spell'] = {k for k in state['spell_linked_spell'] if not k[3].startswith('WCME:')}
            for table in OWNED_TABLES:
                state[table] = {k for k in state[table] if (table, k[0]) not in owned}
            for table in ('wcme_enchant_teach', 'wcme_enchant_override', 'wcme_proc_target_cooldown',
                          'wcme_enchant_action', 'wcme_spellaffect_dbc', 'wcme_owned'):
                state[table] = set()
            state['spell_script_names'] = {k for k in state['spell_script_names'] if not k[1].startswith('spell_wcme_')}
        for name, stmts in parsed:
            if name.startswith('000'):
                continue   # modelled above
            deleted_here = {table: set() for table in KEYS}
            for stmt in stmts:
                flat = ' '.join(stmt.split())
                m = INSERT.match(stmt)
                if m and m.group(2) in KEYS:
                    kind, table, columns, mode = m.group(1).upper(), m.group(2), m.group(4), m.group(5).upper()
                    if mode != 'VALUES':
                        if run == 1 and table != 'wcme_owned':
                            notes.append(f'{name}: {flat[:90]}... (INSERT ... SELECT not modelled)')
                        continue
                    names = [c.strip(' `') for c in columns.split(',')] if columns else None
                    for row in tuples(m.group(6)):
                        if names:
                            key = tuple(clean(row[names.index(c)]) if c in names else '' for c in KEYS[table])
                        else:
                            key = tuple(clean(v) for v in row[:len(KEYS[table])])
                        full = key
                        if table == 'spell_linked_spell':
                            comment = clean(row[names.index('comment')]) if names and 'comment' in names else clean(row[-1])
                            full = key + (comment,)
                            if run == 1 and not comment.startswith('WCME:'):
                                problems.append(('ERROR', name, f'no WCME marker: spell_linked_spell {key}'))
                        if run == 1 and table == 'wcme_spellaffect_dbc':
                            clash = stock_id_problem(key[0])
                            if clash:
                                problems.append(('ERROR', name, clash))
                        present = any(k[:len(key)] == key for k in state[table])
                        if kind == 'INSERT' and present:
                            problems.append(('ERROR', name, f'duplicate key on run {run}: {table} {key}'))
                        if run == 1 and kind == 'INSERT' and table in OWNED_TABLES and (table, key[0]) not in owned \
                                and key not in deleted_here[table]:
                            problems.append(('ERROR', name, f'not re-runnable: {table} {key[0]} is not in wcme_owned '
                                                            f'and not deleted first'))
                        if run == 1 and table == 'spell_script_names' and not key[1].startswith('spell_wcme_') \
                                and key not in deleted_here[table] and kind == 'INSERT':
                            problems.append(('WARN', name, f'spell_script_names {key}: 000-reset will not clear it'))
                        if kind == 'REPLACE':
                            state[table] = {k for k in state[table] if k[:len(key)] != key}
                        if not (kind == 'INSERT IGNORE' and present):
                            state[table].add(full)
                    continue
                m = DELETE_IN.match(flat)
                if m and m.group(1) in KEYS:
                    table, column = m.group(1), m.group(2)
                    if m.group(3) and re.match(r"\s*SELECT\s+`?id`?\s+FROM\s+`?wcme_owned`?\s+WHERE\s+`?tbl`?\s*=\s*'(\w+)'\s*$",
                                               m.group(3), re.I):
                        # "every row of this table registered in wcme_owned so far" (file 002)
                        which = re.search(r"'(\w+)'", m.group(3)).group(1)
                        values = [k[1] for k in state['wcme_owned'] if k[0] == which]
                    elif m.group(3) and 'SELECT' in m.group(3).upper():
                        if run == 1:
                            notes.append(f'{name}: {flat[:110]} (sub-query not modelled)')
                        continue
                    else:
                        values = [clean(v) for v in (m.group(3).split(',') if m.group(3) else [m.group(4)])]
                    pos = KEYS[table].index(column) if column in KEYS[table] else None
                    if pos is None:
                        if run == 1:
                            notes.append(f'{name}: {flat[:90]} (not on a key column; not modelled)')
                        continue
                    extra = (KEYS[table].index(m.group(5)), m.group(6)) if m.group(5) in KEYS[table] else None
                    gone = {k for k in state[table] if k[pos] in values and (not extra or like(extra[1], k[extra[0]]))}
                    state[table] -= gone
                    if len(KEYS[table]) == 1:
                        deleted_here[table] |= {(v,) for v in values}
                    else:
                        deleted_here[table] |= {k[:len(KEYS[table])] for k in gone}
                    continue
                m = DELETE_LIKE.match(flat)
                if m and m.group(1) in KEYS and m.group(2) in KEYS[m.group(1)]:
                    table, pos = m.group(1), KEYS[m.group(1)].index(m.group(2))
                    state[table] = {k for k in state[table] if not like(m.group(3), k[pos])}
                    continue
                m = DELETE_ALL.match(flat)
                if m and m.group(1) in KEYS:
                    state[m.group(1)] = set()
                    continue
                target = re.match(r'(?:UPDATE|DELETE(?:\s+`?\w+`?)?\s+FROM)\s+`?(\w+)`?', flat, re.I)
                if run == 1 and target and target.group(1) in KEYS:
                    notes.append(f'{name}: {flat[:110]}{"..." if len(flat) > 110 else ""}')

    errors = [p for p in problems if p[0] == 'ERROR']
    seen = set()
    for level, name, text in problems:
        if (level, name, text) not in seen:
            seen.add((level, name, text))
            print(f'{level}  {name}: {text}')
    if notes:
        print(f'\n{len(notes)} statement(s) not modelled - read by hand:')
        for note in notes:
            print(f'NOTE   {note}')
    print(f'\n{len(files)} files, {sum(len(s) for _, s in parsed)} statements, {len(owned)} wcme_owned keys: '
          f'{len(errors)} error(s), {len(seen) - len(set(errors))} warning(s).')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
