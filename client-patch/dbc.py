import struct


class Dbc:
    def __init__(self, path):
        data = open(path, 'rb').read()
        _, self.count, self.fields, self.size, strsize = struct.unpack_from('<4s4I', data, 0)
        self.base = 20 + self.count * self.size
        self.strings = data[self.base:self.base + strsize]
        self.data = data
        self.rows = {}
        for i in range(self.count):
            rec = struct.unpack_from(f'<{self.fields}I', data, 20 + i * self.size)
            self.rows[rec[0]] = rec

    def string(self, offset):
        if not 0 < offset < len(self.strings):
            return ''
        return self.strings[offset:self.strings.index(b'\0', offset)].decode('utf-8', 'replace')


STRING_COLS = set(range(136, 204)) - {152, 169, 186, 203}


def write_dbc(path, rows, fields, string_of):
    """rows: list of tuples of uint32; string_of(row, col) -> str for string columns."""
    table = bytearray(b'\0')
    index = {'': 0}
    out = []
    for rec in rows:
        rec = list(rec)
        for c in STRING_COLS:
            s = string_of(rec, c)
            if s not in index:
                index[s] = len(table)
                table += s.encode('utf-8') + b'\0'
            rec[c] = index[s]
        out.append(struct.pack(f'<{fields}I', *rec))
    header = struct.pack('<4s4I', b'WDBC', len(out), fields, fields * 4, len(table))
    with open(path, 'wb') as fh:
        fh.write(header)
        for r in out:
            fh.write(r)
        fh.write(table)
