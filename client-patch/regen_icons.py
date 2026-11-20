#!/usr/bin/env python3
"""Makes the Voodoo Regeneration cooldown icon: the client's Regeneration icon (Spell_Nature_Regenerate) with its green
turned red, so the cooldown reads as the same racial, spent. Only the green is moved; the blue hand stays blue.

Usage: python3 regen_icons.py <Spell_Nature_Regenerate.blp> <output folder>

Spell_Nature_Regenerate.blp is in the client's Data\\patch-I.MPQ (Interface\\icons\\spell_nature_regenerate.blp). Made
from the client's own art, so not published: racials_off_gcd.py --icons <output folder> puts it in patch-ZZW.MPQ.
"""
import colorsys
import os
import sys

from PIL import Image

from rend_icons import write_blp

NAME = 'wcme_regen_cooldown'
GREEN_FROM, GREEN_TO, GREEN_CENTRE = 70, 175, 132  # the icon's greens, in degrees; 132 is their middle


def greens_to_red(image):
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in px[x, y]))
            degrees = h * 360
            if s > 0.2 and GREEN_FROM <= degrees <= GREEN_TO:
                h = ((degrees - GREEN_CENTRE) % 360) / 360  # the middle green lands on red
            px[x, y] = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))
    return out


if __name__ == '__main__':
    source = Image.open(sys.argv[1]).convert('RGB')
    os.makedirs(sys.argv[2], exist_ok=True)
    write_blp(os.path.join(sys.argv[2], NAME + '.blp'), greens_to_red(source))
    print(NAME)
