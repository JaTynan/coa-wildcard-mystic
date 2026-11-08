#!/usr/bin/env python3
"""Draws the Steam library artwork, built around the Project Descension: Wildcard emblem (emblem.py), for the Linux launcher's --add-to-steam (original art: no game assets).

  python3 make_steam_art.py FONT_DIR OUT_DIR

FONT_DIR holds Cinzel[wght].ttf and CinzelDecorative-Bold.ttf (Google Fonts, OFL, github.com/google/fonts/ofl).
Writes portrait.png (600x900), header.png (920x430), hero.png (1920x620), logo.png (transparent) and icon.png
(256x256) into OUT_DIR, which is launcher/site/steam so the site publishes them.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from emblem import emblem, gem  # noqa: E402

FONTS, OUT = Path(sys.argv[1]), Path(sys.argv[2])
TITLE_FONT = FONTS / "CinzelDecorative-Bold.ttf"
SUB_FONT = FONTS / "Cinzel[wght].ttf"
GOLD_TOP, GOLD_BOTTOM = (250, 232, 170), (178, 118, 40)
INK = (12, 14, 28)


def gradient(w, h, top, bottom):
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        img.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img.resize((w, h))


def glow(size, center, radius, colour, strength):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=colour + (strength,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.6))


def card(w, h, scale):
    """One face-down Wildcard card: dark face, double gold border, a four-point star."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(w * 0.08)
    d.rounded_rectangle((0, 0, w - 1, h - 1), r, fill=(20, 22, 40, 255), outline=GOLD_BOTTOM + (255,),
                        width=max(2, int(4 * scale)))
    inset = int(w * 0.07)
    d.rounded_rectangle((inset, inset, w - 1 - inset, h - 1 - inset), int(r * 0.6), outline=(120, 86, 40, 255),
                        width=max(1, int(2 * scale)))
    cx, cy, s = w / 2, h / 2, w * 0.26
    star = []
    for i in range(8):
        angle = math.pi / 4 * i - math.pi / 2
        length = s if i % 2 == 0 else s * 0.28
        star.append((cx + math.cos(angle) * length, cy + math.sin(angle) * length))
    d.polygon(star, fill=GOLD_TOP + (235,))
    d.ellipse((cx - s * 0.12, cy - s * 0.12, cx + s * 0.12, cy + s * 0.12), fill=(20, 22, 40, 255))
    return img


def fan(canvas, center, card_w, count, spread, lift, scale):
    cw, ch = card_w, int(card_w * 1.45)
    cx, cy = center
    for i in range(count):
        t = (i - (count - 1) / 2) / max(1, (count - 1) / 2)
        angle = -t * spread
        face = card(cw, ch, scale).rotate(angle, expand=True, resample=Image.BICUBIC)
        shadow = Image.new("RGBA", face.size, (0, 0, 0, 0))
        shadow.putalpha(face.getchannel("A").point(lambda a: int(a * 0.55)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(10 * scale))
        x = int(cx + t * card_w * 0.55 - face.width / 2)
        y = int(cy - face.height / 2 + abs(t) * lift)
        canvas.alpha_composite(shadow, (x + int(8 * scale), y + int(12 * scale)))
        canvas.alpha_composite(face, (x, y))


def embers(canvas, count, seed, region=None):
    rng = random.Random(seed)
    w, h = canvas.size
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = region or (0, 0, w, h)
    for _ in range(count):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.choice([1, 1, 1.5, 2, 2.5, 3.5]) * max(1, w / 1200)
        a = rng.randint(90, 230)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, rng.randint(140, 200), 80, a))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.6)))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(4)))


def background(w, h, seed, ember_density=9000):
    base = gradient(w, h, (10, 13, 30), (34, 16, 34)).convert("RGBA")
    base.alpha_composite(glow((w, h), (w * 0.5, h * 1.05), max(w, h) * 0.45, (210, 96, 40), 150))
    base.alpha_composite(glow((w, h), (w * 0.15, h * 0.1), max(w, h) * 0.3, (60, 70, 160), 90))
    base.alpha_composite(glow((w, h), (w * 0.9, h * 0.2), max(w, h) * 0.25, (110, 50, 140), 80))
    embers(base, int(w * h / ember_density), seed)
    # vignette
    vig = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vig).ellipse((-w * 0.25, -h * 0.25, w * 1.25, h * 1.25), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(min(w, h) * 0.18))
    dark = Image.new("RGBA", (w, h), (4, 4, 10, 255))
    dark.putalpha(vig.point(lambda v: 255 - v))
    base.alpha_composite(dark)
    return base


def gold_text(text, font, stroke):
    left, top, right, bottom = font.getbbox(text, stroke_width=stroke)
    pad = stroke * 6 + 10
    w, h = right - left + pad * 2, bottom - top + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - left, pad - top), text, font=font, fill=255)
    outline = Image.new("L", (w, h), 0)
    ImageDraw.Draw(outline).text((pad - left, pad - top), text, font=font, fill=255, stroke_width=stroke,
                                 stroke_fill=255)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    halo = Image.new("RGBA", (w, h), (255, 150, 60, 0))
    halo.putalpha(outline.filter(ImageFilter.GaussianBlur(stroke * 3)).point(lambda a: int(a * 0.55)))
    img.alpha_composite(halo)
    edge = Image.new("RGBA", (w, h), (30, 16, 6, 255))
    edge.putalpha(outline)
    img.alpha_composite(edge)
    fill = gradient(w, h, GOLD_TOP, GOLD_BOTTOM).convert("RGBA")
    fill.putalpha(mask)
    img.alpha_composite(fill)
    return img


def title_block(width, scale, subtitle=True):
    """'PROJECT' over 'DESCENSION', with a small subtitle, fitted to width."""
    big = int(150 * scale)
    while True:
        line2 = gold_text("DESCENSION", ImageFont.truetype(str(TITLE_FONT), big), max(2, big // 24))
        if line2.width <= width:
            break
        big = int(big * 0.94)
    line1 = gold_text("PROJECT", ImageFont.truetype(str(TITLE_FONT), int(big * 0.62)), max(2, big // 32))
    parts = [line1, line2]
    if subtitle:
        sub_font = ImageFont.truetype(str(SUB_FONT), max(12, int(big * 0.2)))
        try:
            sub_font.set_variation_by_axes([600])
        except Exception:
            pass
        text = "CONQUEST OF AZEROTH  •  WILDCARD"
        l, t, r, b = sub_font.getbbox(text)
        sub = Image.new("RGBA", (r - l + 20, b - t + 20), (0, 0, 0, 0))
        ImageDraw.Draw(sub).text((10 - l, 10 - t), text, font=sub_font, fill=(236, 220, 186, 255))
        parts.append(sub)
    gap = int(big * -0.08)
    h = sum(p.height for p in parts) + gap * (len(parts) - 1)
    w = max(p.width for p in parts)
    block = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = 0
    for p in parts:
        block.alpha_composite(p, ((w - p.width) // 2, y))
        y += p.height + gap
    return block


def save(img, name, size):
    img.resize(size, Image.LANCZOS).save(OUT / name, optimize=True)
    print(name, size)


def logo(width):
    return emblem(width, {"title": str(TITLE_FONT), "sub": str(SUB_FONT)})


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    s = 2  # draw at 2x, then scale down

    w, h = 600 * s, 900 * s
    img = background(w, h, 1)
    fan(img, (w * 0.5, h * 0.3), int(w * 0.28), 5, 24, h * 0.04, s)
    e = logo(int(w * 1.0))
    e = e.resize((int(w * 0.96), int(e.height * w * 0.96 / e.width)), Image.LANCZOS)
    img.alpha_composite(e, ((w - e.width) // 2, int(h * 0.56)))
    save(img, "portrait.png", (600, 900))

    w, h = 920 * s, 430 * s
    img = background(w, h, 2)
    fan(img, (w * 0.14, h * 0.55), int(h * 0.36), 3, 18, h * 0.04, s)
    e = logo(int(w * 0.8))
    e = e.resize((int(e.width * h * 0.8 / e.height), int(h * 0.8)), Image.LANCZOS)
    img.alpha_composite(e, (int(w * 0.585 - e.width / 2), (h - e.height) // 2))
    save(img, "header.png", (920, 430))

    w, h = 1920 * s, 620 * s  # hero: no text, Steam puts the logo over it
    img = background(w, h, 3, 22000)
    fan(img, (w * 0.8, h * 0.55), int(h * 0.4), 5, 26, h * 0.05, s)
    save(img, "hero.png", (1920, 620))

    e = logo(1600)
    save(e, "logo.png", (800, int(e.height * 800 / e.width)))

    n = 512
    icon = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    face = card(int(n * 0.68), int(n * 0.96), 2.5)
    fd = ImageDraw.Draw(face)
    fd.rectangle((face.width * 0.2, face.height * 0.3, face.width * 0.8, face.height * 0.7), fill=(20, 22, 40, 255))
    g = gem(int(face.width * 0.62), (160, 96, 240))
    face.alpha_composite(g, ((face.width - g.width) // 2, (face.height - g.height) // 2))
    icon.alpha_composite(face, ((n - face.width) // 2, (n - face.height) // 2))
    save(icon, "icon.png", (256, 256))


main()
