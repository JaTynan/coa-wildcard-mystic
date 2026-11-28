"""Read files out of the game client's MPQ archives, and turn BLP textures into PNG. Standard library only.

Enough of the MPQ format for the client's own archives: header versions 1 to 3 (the extended block table above 4 GB
is read), encrypted hash and block tables, sector tables, encrypted files (with the key adjusted by offset), and
sectors compressed with zlib or bzip2. Files stored with the old "implode" method or LZMA are reported, not read.
"""
import struct
import zlib
from pathlib import Path

try:
    import bz2  # some embedded Pythons leave it out; only bzip2-packed files need it
except ImportError:
    bz2 = None


def _crypt_table():
    table = [0] * 0x500
    seed = 0x00100001
    for i in range(0x100):
        index = i
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            high = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[index] = high | (seed & 0xFFFF)
            index += 0x100
    return table


CRYPT = _crypt_table()
MASK = 0xFFFFFFFF
FLAG_IMPLODE, FLAG_COMPRESS, FLAG_ENCRYPTED, FLAG_FIX_KEY = 0x100, 0x200, 0x10000, 0x20000
FLAG_SINGLE_UNIT, FLAG_DELETE, FLAG_SECTOR_CRC, FLAG_EXISTS = 0x1000000, 0x2000000, 0x4000000, 0x80000000


def hash_string(name, kind):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in name.upper().replace("/", "\\").encode("latin-1", "replace"):
        seed1 = CRYPT[(kind << 8) + ch] ^ ((seed1 + seed2) & MASK)
        seed2 = (ch + seed1 + seed2 + (seed2 << 5) + 3) & MASK
    return seed1


def name_hashes(name):
    """The three hashes a file name is looked up by; work them out once when looking in many archives."""
    return hash_string(name, 0), hash_string(name, 1), hash_string(name, 2)


def decrypt(data, key):
    """Decrypt whole 32-bit words; a tail shorter than a word is left as it is."""
    count = len(data) // 4
    words = struct.unpack_from(f"<{count}I", data)
    out = [0] * count
    seed = 0xEEEEEEEE
    table = CRYPT
    for i in range(count):
        seed = (seed + table[0x400 + (key & 0xFF)]) & MASK
        value = words[i] ^ ((key + seed) & MASK)
        out[i] = value
        key = ((((~key) << 0x15) + 0x11111111) & MASK) | (key >> 0x0B)
        seed = (value + seed + (seed << 5) + 3) & MASK
    return struct.pack(f"<{count}I", *out) + bytes(data[count * 4:])


class UnreadableFile(Exception):
    pass


class Archive:
    def __init__(self, path):
        self.path = Path(path)
        self._file = open(self.path, "rb")
        start = 0
        while True:
            self._file.seek(start)
            head = self._file.read(32)
            if len(head) < 32:
                raise ValueError(f"{self.path.name}: not an MPQ archive")
            if head[:4] == b"MPQ\x1b":  # user data in front of the archive
                start += struct.unpack_from("<I", head, 8)[0]
                continue
            if head[:4] == b"MPQ\x1a":
                break
            start += 0x200
            if start > 1 << 20:
                raise ValueError(f"{self.path.name}: no MPQ header found")
        self.base = start
        self._file.seek(start)
        header = self._file.read(68)
        (_, header_size, _, version, shift, hash_pos, block_pos, hash_count,
         block_count) = struct.unpack_from("<4sIIHHIIII", header)
        hi_block = hash_hi = block_hi = 0
        if version >= 1 and header_size >= 44:
            hi_block, hash_hi, block_hi = struct.unpack_from("<QHH", header, 32)
        self.sector = 512 << shift
        hash_at = self.base + (hash_hi << 32 | hash_pos)
        block_at = self.base + (block_hi << 32 | block_pos)
        self._file.seek(hash_at)
        self._hashes = decrypt(self._file.read(hash_count * 16), hash_string("(hash table)", 3))
        self._file.seek(block_at)
        self._blocks = decrypt(self._file.read(block_count * 16), hash_string("(block table)", 3))
        self.hash_count, self.block_count = hash_count, block_count
        self._highs = None
        if hi_block:
            self._file.seek(self.base + hi_block)
            self._highs = self._file.read(block_count * 2)

    def block(self, number):
        offset, packed, size, flags = struct.unpack_from("<IIII", self._blocks, number * 16)
        if self._highs:
            offset |= struct.unpack_from("<H", self._highs, number * 2)[0] << 32
        return offset, packed, size, flags

    def close(self):
        self._file.close()

    def _find(self, name, hashes=None):
        count = self.hash_count
        if not count:
            return None
        first, a, b = hashes or name_hashes(name)
        start = index = first & (count - 1)
        found = None
        while True:
            name1, name2, locale, _, block = struct.unpack_from("<IIHHI", self._hashes, index * 16)
            if block == 0xFFFFFFFF:
                return found
            if name1 == a and name2 == b and block < self.block_count:
                if locale == 0:  # the neutral copy; a localised one only if there is no neutral one
                    return block
                found = block if found is None else found
            index = (index + 1) & (count - 1)
            if index == start:
                return found

    def has(self, name):
        block = self._find(name)
        if block is None:
            return False
        flags = self.block(block)[3]
        return bool(flags & FLAG_EXISTS) and not flags & FLAG_DELETE

    def read(self, name, hashes=None):
        """The file's bytes, None if this archive does not hold it, or UnreadableFile."""
        number = self._find(name, hashes)
        if number is None:
            return None
        offset, packed, size, flags = self.block(number)
        if not flags & FLAG_EXISTS or flags & FLAG_DELETE:
            return None
        if flags & FLAG_IMPLODE:
            raise UnreadableFile(f"{name} in {self.path.name} uses the implode method")
        self._file.seek(self.base + offset)
        raw = self._file.read(packed)
        key = 0
        if flags & FLAG_ENCRYPTED:
            key = hash_string(name.replace("/", "\\").rsplit("\\", 1)[-1], 3)
            if flags & FLAG_FIX_KEY:
                key = ((key + offset) ^ size) & MASK
        if flags & FLAG_SINGLE_UNIT:
            if flags & FLAG_ENCRYPTED:
                raw = decrypt(raw, key)
            return self._unpack(raw, size, flags, name) if packed < size else raw[:size]
        sectors = (size + self.sector - 1) // self.sector
        if not flags & FLAG_COMPRESS:
            if flags & FLAG_ENCRYPTED:
                raw = b"".join(decrypt(raw[i:i + self.sector], (key + n) & MASK)
                               for n, i in enumerate(range(0, len(raw), self.sector)))
            return raw[:size]
        entries = sectors + 1 + (1 if flags & FLAG_SECTOR_CRC else 0)
        table = raw[:entries * 4]
        if flags & FLAG_ENCRYPTED:
            table = decrypt(table, (key - 1) & MASK)
        bounds = struct.unpack(f"<{entries}I", table)
        out = []
        for n in range(sectors):
            chunk = raw[bounds[n]:bounds[n + 1]]
            if flags & FLAG_ENCRYPTED:
                chunk = decrypt(chunk, (key + n) & MASK)
            want = min(self.sector, size - n * self.sector)
            out.append(self._unpack(chunk, want, flags, name) if len(chunk) < want else chunk[:want])
        return b"".join(out)

    def _unpack(self, chunk, want, flags, name):
        method, body = chunk[0], chunk[1:]
        if method == 0x02:
            return zlib.decompress(body)
        if method == 0x10 and bz2:
            return bz2.decompress(body)
        raise UnreadableFile(f"{name} in {self.path.name}: compression 0x{method:02x} is not supported")


def client_archives(client):
    """The client's archives, the one whose copy of a file wins first (the client loads patches over the base)."""
    data = Path(client) / "Data"
    if not data.is_dir():
        return []
    found = []
    locale = [p for p in data.glob("*/*.MPQ") if p.parent.name.lower() == "enus"]
    found += sorted((p for p in locale if p.name.lower().startswith("patch-")), key=lambda p: p.stem.upper(),
                    reverse=True)
    patches = [p for p in data.glob("*.MPQ") if p.name.lower().startswith("patch-")]
    found += sorted(patches, key=lambda p: p.stem.upper(), reverse=True)
    found += [p for p in data.glob("patch.MPQ")]
    found += sorted((p for p in locale if not p.name.lower().startswith("patch-")), key=lambda p: p.name.upper())
    for name in ("lichking.MPQ", "expansion.MPQ", "common-2.MPQ", "common.MPQ"):
        found += [p for p in data.glob(name)]
    found += sorted(p for p in data.glob("*/*.MPQ") if p.parent.name.lower() not in ("enus",))
    seen, ordered = set(), []
    for p in found:
        if p.resolve() not in seen:
            seen.add(p.resolve())
            ordered.append(p)
    return ordered


# ---- BLP to PNG ---------------------------------------------------------------------------------------------------

def _rgb565(v):
    r, g, b = (v >> 11) & 31, (v >> 5) & 63, v & 31
    return (r << 3 | r >> 2, g << 2 | g >> 4, b << 3 | b >> 2)


def _dxt(data, width, height, kind):
    """kind 0 = DXT1, 1 = DXT3, 7 = DXT5. Returns RGBA bytes."""
    out = bytearray(width * height * 4)
    at = 0
    for by in range(0, height, 4):
        for bx in range(0, width, 4):
            alpha = None
            if kind == 1:
                bits = int.from_bytes(data[at:at + 8], "little")
                alpha = [((bits >> (4 * i)) & 15) * 17 for i in range(16)]
                at += 8
            elif kind == 7:
                a0, a1 = data[at], data[at + 1]
                bits = int.from_bytes(data[at + 2:at + 8], "little")
                if a0 > a1:
                    levels = [a0, a1] + [((7 - i) * a0 + i * a1) // 7 for i in range(1, 7)]
                else:
                    levels = [a0, a1] + [((5 - i) * a0 + i * a1) // 5 for i in range(1, 5)] + [0, 255]
                alpha = [levels[(bits >> (3 * i)) & 7] for i in range(16)]
                at += 8
            c0, c1, bits = struct.unpack_from("<HHI", data, at)
            at += 8
            p0, p1 = _rgb565(c0), _rgb565(c1)
            if c0 > c1 or kind != 0:
                colours = [p0 + (255,), p1 + (255,),
                           tuple((2 * a + b) // 3 for a, b in zip(p0, p1)) + (255,),
                           tuple((a + 2 * b) // 3 for a, b in zip(p0, p1)) + (255,)]
            else:
                colours = [p0 + (255,), p1 + (255,), tuple((a + b) // 2 for a, b in zip(p0, p1)) + (255,),
                           (0, 0, 0, 0)]
            for i in range(16):
                x, y = bx + (i & 3), by + (i >> 2)
                if x < width and y < height:
                    r, g, b, a = colours[(bits >> (2 * i)) & 3]
                    if alpha is not None:
                        a = alpha[i]
                    o = (y * width + x) * 4
                    out[o:o + 4] = bytes((r, g, b, a))
    return bytes(out)


def blp_to_rgba(data):
    """(width, height, RGBA bytes) for the largest picture in a BLP2 file."""
    if data[:4] != b"BLP2":
        raise UnreadableFile("not a BLP2 texture")
    _, compression, alpha_depth, alpha_kind, _, width, height = struct.unpack_from("<IBBBBII", data, 4)
    offsets = struct.unpack_from("<16I", data, 20)
    sizes = struct.unpack_from("<16I", data, 84)
    picture = data[offsets[0]:offsets[0] + sizes[0]]
    if compression == 2:
        return width, height, _dxt(picture, width, height, alpha_kind if alpha_depth else 0)
    if compression == 3:  # raw BGRA
        out = bytearray(width * height * 4)
        for i in range(width * height):
            b, g, r, a = picture[i * 4:i * 4 + 4]
            out[i * 4:i * 4 + 4] = bytes((r, g, b, a))
        return width, height, bytes(out)
    if compression == 1 and len(data) < 148 + 1024:
        raise UnreadableFile("BLP palette missing")
    if compression == 1:  # 256-colour palette, then alpha of 0, 1, 4 or 8 bits
        palette = struct.unpack_from("<256I", data, 148)
        count = width * height
        out = bytearray(count * 4)
        for i in range(count):
            c = palette[picture[i]]
            if alpha_depth == 8:
                a = picture[count + i]
            elif alpha_depth == 4:
                a = ((picture[count + i // 2] >> (4 * (i & 1))) & 15) * 17
            elif alpha_depth == 1:
                a = 255 if picture[count + i // 8] >> (i & 7) & 1 else 0
            else:
                a = 255
            out[i * 4:i * 4 + 4] = bytes(((c >> 16) & 255, (c >> 8) & 255, c & 255, a))
        return width, height, bytes(out)
    raise UnreadableFile(f"BLP compression {compression} is not supported")


def png(width, height, rgba):
    rows = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & MASK)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))
