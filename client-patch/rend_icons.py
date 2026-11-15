#!/usr/bin/env python3
"""Makes the Elemental Rend icons (Spell Shredder): the client's Rend icon (Ability_Gouge) with its red blood hue-shifted
to each element's colour. Grey (the blade and the border) is left alone.

Usage: python3 rend_icons.py <Ability_Gouge.blp> <output folder>

Ability_Gouge.blp is in the client's Data\\patch-I.MPQ (Interface\\Icons\\Ability_Gouge.blp). The icons are made from
the client's own art, so they are not published: racials_off_gcd.py --icons <output folder> puts them in patch-ZZW.MPQ.
"""
import colorsys
import os
import struct
import sys

from PIL import Image

# file name -> (hue shift in degrees from red, brightness factor)
ICONS = {
    'wcme_rend_frost': (205, 1.15),
    'wcme_rend_fire': (28, 1.15),
    'wcme_rend_nature': (105, 1.1),
}


def shifted(image, degrees, bright):
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in px[x, y]))
            if s > 0.25:  # only coloured pixels
                h, v = (h + degrees / 360) % 1, min(1.0, v * bright)
            px[x, y] = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))
    return out


def write_blp(path, image):
    """A paletted BLP2 with mipmaps down to 1x1, like the client's own icons."""
    base = image.quantize(256)
    palette = base.getpalette()[:768] + [0] * (768 - len(base.getpalette()[:768]))
    levels, size = [], image.width
    while size >= 1:
        level = base if size == image.width else image.resize((size, size), Image.LANCZOS).quantize(palette=base)
        levels.append(level.tobytes())
        size //= 2
    offsets, sizes, at = [], [], 148 + 1024
    for data in levels:
        offsets.append(at)
        sizes.append(len(data))
        at += len(data)
    header = b'BLP2' + struct.pack('<I4B2I', 1, 1, 0, 0, 1, image.width, image.height)
    header += struct.pack('<16I', *(offsets + [0] * (16 - len(offsets))))
    header += struct.pack('<16I', *(sizes + [0] * (16 - len(sizes))))
    bgra = b''.join(bytes((palette[i * 3 + 2], palette[i * 3 + 1], palette[i * 3], 255)) for i in range(256))
    with open(path, 'wb') as out:
        out.write(header + bgra + b''.join(levels))


if __name__ == '__main__':
    source = Image.open(sys.argv[1]).convert('RGB')
    os.makedirs(sys.argv[2], exist_ok=True)
    for name, (degrees, bright) in ICONS.items():
        write_blp(os.path.join(sys.argv[2], name + '.blp'), shifted(source, degrees, bright))
        print(name)
