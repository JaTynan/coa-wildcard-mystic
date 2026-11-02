"""Minimal MPQ (format version 1) writer: zlib-compressed sectored files, encrypted hash and block tables."""
import struct
import sys
import zlib


def _crypt_table():
    table = [0] * 0x500
    seed = 0x00100001
    for index1 in range(0x100):
        index2 = index1
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp1 = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp2 = seed & 0xFFFF
            table[index2] = temp1 | temp2
            index2 += 0x100
    return table


CRYPT = _crypt_table()


def hash_string(text, hash_type):
    seed1, seed2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in text.upper():
        value = ord(ch)
        seed1 = CRYPT[(hash_type << 8) + value] ^ ((seed1 + seed2) & 0xFFFFFFFF)
        seed2 = (value + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1


def encrypt(data, key):
    seed = 0xEEEEEEEE
    out = bytearray()
    for (value,) in struct.iter_unpack('<I', data):
        seed = (seed + CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        result = value ^ ((key + seed) & 0xFFFFFFFF)
        key = (((~key << 0x15) + 0x11111111) & 0xFFFFFFFF) | (key >> 0x0B)
        seed = (value + seed + (seed << 5) + 3) & 0xFFFFFFFF
        out += struct.pack('<I', result)
    return bytes(out)


SECTOR_SHIFT = 3
SECTOR = 512 << SECTOR_SHIFT
FLAG_EXISTS, FLAG_COMPRESS = 0x80000000, 0x00000200


def pack_file(data):
    sectors = [data[i:i + SECTOR] for i in range(0, len(data), SECTOR)] or [b'']
    blobs = []
    for sector in sectors:
        packed = b'\x02' + zlib.compress(sector, 9)
        blobs.append(packed if len(packed) < len(sector) else sector)
    offsets = [4 * (len(blobs) + 1)]
    for blob in blobs:
        offsets.append(offsets[-1] + len(blob))
    return struct.pack(f'<{len(offsets)}I', *offsets) + b''.join(blobs)


def write_mpq(path, files):
    """files: list of (archive name, bytes)."""
    names = [name for name, _ in files] + ['(listfile)']
    payloads = [data for _, data in files] + ['\r\n'.join(n for n, _ in files).encode() + b'\r\n']
    hash_size = 16
    while hash_size < len(names) * 2:
        hash_size *= 2
    body = bytearray()
    blocks = []
    for data in payloads:
        packed = pack_file(data)
        blocks.append((32 + len(body), len(packed), len(data), FLAG_EXISTS | FLAG_COMPRESS))
        body += packed
    hashes = [(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFF, 0, 0xFFFFFFFF)] * hash_size
    for block_index, name in enumerate(names):
        slot = hash_string(name, 0) % hash_size
        while hashes[slot][4] != 0xFFFFFFFF:
            slot = (slot + 1) % hash_size
        hashes[slot] = (hash_string(name, 1), hash_string(name, 2), 0, 0, block_index)
    hash_raw = b''.join(struct.pack('<IIHHI', *h) for h in hashes)
    block_raw = b''.join(struct.pack('<IIII', *b) for b in blocks)
    hash_pos = 32 + len(body)
    block_pos = hash_pos + len(hash_raw)
    archive_size = block_pos + len(block_raw)
    header = struct.pack('<4sIIHHIIII', b'MPQ\x1a', 32, archive_size, 0, SECTOR_SHIFT,
                         hash_pos, block_pos, hash_size, len(blocks))
    with open(path, 'wb') as out:
        out.write(header)
        out.write(body)
        out.write(encrypt(hash_raw, hash_string('(hash table)', 3)))
        out.write(encrypt(block_raw, hash_string('(block table)', 3)))


if __name__ == '__main__':
    out_path = sys.argv[1]
    pairs = [arg.split('=', 1) for arg in sys.argv[2:]]
    write_mpq(out_path, [(name, open(src, 'rb').read()) for name, src in pairs])
