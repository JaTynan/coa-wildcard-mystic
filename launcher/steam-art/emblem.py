"""The Project Descension: Wildcard emblem (original artwork), drawn with Pillow. Used by make_steam_art.py."""
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

GOLD = [(255, 244, 196), (240, 200, 110), (196, 140, 52), (120, 74, 22), (214, 160, 70), (255, 230, 160)]


def vgrad(w, h, stops):
    col = Image.new("RGB", (1, h))
    n = len(stops) - 1
    for y in range(h):
        t = y / max(1, h - 1) * n
        i = min(int(t), n - 1)
        f = t - i
        col.putpixel((0, y), tuple(int(a + (b - a) * f) for a, b in zip(stops[i], stops[i + 1])))
    return col.resize((w, h))


def metal(mask, stops=GOLD, bevel=10, light=1.0):
    """Gold fill shaped by mask, with a bevelled edge lit from the top left."""
    w, h = mask.size
    base = vgrad(w, h, stops).convert("RGBA")
    height = mask.filter(ImageFilter.GaussianBlur(bevel))
    hi = ImageChops.subtract(height, ImageChops.offset(height, int(bevel * 0.5), int(bevel * 0.5)))
    lo = ImageChops.subtract(ImageChops.offset(height, int(bevel * 0.5), int(bevel * 0.5)), height)
    white = Image.new("RGBA", (w, h), (255, 250, 225, 0))
    white.putalpha(hi.point(lambda v: min(255, int(v * 4 * light))))
    dark = Image.new("RGBA", (w, h), (50, 25, 5, 0))
    dark.putalpha(lo.point(lambda v: min(255, int(v * 4 * light))))
    base.alpha_composite(white)
    base.alpha_composite(dark)
    base.putalpha(mask)
    return base


def shape(size, draw_fn):
    m = Image.new("L", size, 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def plate_points(cx, cy, w, h, point):
    """Long plate with chamfered corners and pointed ends."""
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
    c = h * 0.22
    return [(x0 + c, y0), (cx - w * 0.08, y0), (cx, y0 - h * 0.1), (cx + w * 0.08, y0), (x1 - c, y0),
            (x1, cy - h * 0.18), (x1 + point, cy), (x1, cy + h * 0.18), (x1 - c, y1), (cx + w * 0.1, y1),
            (cx, y1 + h * 0.08), (cx - w * 0.1, y1), (x0 + c, y1), (x0, cy + h * 0.18), (x0 - point, cy),
            (x0, cy - h * 0.18)]


def inset(points, cx, cy, fx, fy):
    return [(cx + (x - cx) * fx, cy + (y - cy) * fy) for x, y in points]


def gem(size, colour):
    """A faceted gem: four-point star cut, lit from the top left."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    outer = [(c, 0), (s, c), (c, s), (0, c)]
    d.polygon(outer, fill=tuple(int(v * 0.45) for v in colour) + (255,))
    facets = [((c, 0), (c, c), (0, c), 1.35), ((c, 0), (s, c), (c, c), 1.0), ((0, c), (c, c), (c, s), 0.7),
              ((c, c), (s, c), (c, s), 0.5)]
    for a, b, e, k in facets:
        d.polygon([a, b, e], fill=tuple(min(255, int(v * k)) for v in colour) + (255,))
    d.polygon([(c, s * 0.2), (s * 0.8, c), (c, s * 0.8), (s * 0.2, c)], fill=tuple(min(255, int(v * 1.1)) for v in colour) + (255,))
    d.ellipse((s * 0.3, s * 0.28, s * 0.42, s * 0.4), fill=(255, 255, 255, 220))
    sparkle = img.copy().filter(ImageFilter.GaussianBlur(s * 0.12))
    out = Image.new("RGBA", (s * 2, s * 2), (0, 0, 0, 0))
    glowc = Image.new("RGBA", (s * 2, s * 2), colour + (0,))
    m = Image.new("L", (s * 2, s * 2), 0)
    ImageDraw.Draw(m).polygon([(s, s * 0.3), (s * 1.7, s), (s, s * 1.7), (s * 0.3, s)], fill=150)
    glowc.putalpha(m.filter(ImageFilter.GaussianBlur(s * 0.3)))
    out.alpha_composite(glowc)
    out.alpha_composite(sparkle, (s // 2, s // 2))
    out.alpha_composite(img, (s // 2, s // 2))
    return out


def gold_text(text, font, stroke, stops=GOLD[:4], bevel=None):
    l, t, r, b = font.getbbox(text, stroke_width=stroke)
    pad = stroke * 4 + 20
    w, h = r - l + pad * 2, b - t + pad * 2
    pos = (pad - l, pad - t)
    fill_mask = shape((w, h), lambda d: d.text(pos, text, font=font, fill=255))
    edge_mask = shape((w, h), lambda d: d.text(pos, text, font=font, fill=255, stroke_width=stroke, stroke_fill=255))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.putalpha(edge_mask.filter(ImageFilter.GaussianBlur(stroke * 1.5)).point(lambda v: int(v * 0.8)))
    img.alpha_composite(shadow, (0, 0))
    edge = Image.new("RGBA", (w, h), (36, 16, 4, 255))
    edge.putalpha(edge_mask)
    img.alpha_composite(edge)
    img.alpha_composite(metal(fill_mask, [(255, 248, 210), (246, 206, 112), (190, 128, 40), (240, 186, 90)],
                              bevel or max(2, stroke // 2)))
    return img


def emblem(width, fonts):
    """Returns the emblem as RGBA, about width wide (transparent background)."""
    W = width
    H = int(W * 0.62)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx, cy = W / 2, H * 0.47
    K = 0.74  # plate size within the canvas, leaving room for the wings
    pw, ph = W * 0.76 * K, H * 0.42 * K
    point = W * 0.07 * K
    rng = random.Random(7)

    # drooping wings behind the plate: feathers fan out and DOWN from each end (Descension, not Ascension)
    wings = Image.new("L", (W, H), 0)
    wing_shade = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(wings)
    ds = ImageDraw.Draw(wing_shade)
    # angle below horizontal, length, width: short at the top, longest hanging lowest, like a folded-down wing
    feathers = [(4, 0.15, 0.030), (15, 0.19, 0.032), (26, 0.23, 0.034), (37, 0.27, 0.036), (48, 0.30, 0.037),
                (58, 0.32, 0.037), (67, 0.33, 0.036), (75, 0.32, 0.034)]
    for side in (-1, 1):
        root_x, root_y = cx + side * pw * 0.42, cy - ph * 0.30
        for i, (ang, length, thick) in enumerate(reversed(feathers)):
            a = math.radians(ang)
            dx, dy = side * math.cos(a), math.sin(a)  # positive dy points down the image
            length, thick = length * K, thick * K
            tip = (root_x + dx * W * length, root_y + dy * W * length * 0.95)
            nx, ny = -dy * W * thick, dx * W * thick
            mid = (root_x + dx * W * length * 0.55, root_y + dy * W * length * 0.55 * 0.95)
            outline = [(root_x - nx * 0.5, root_y - ny * 0.5), (mid[0] - nx, mid[1] - ny), tip,
                       (mid[0] + nx, mid[1] + ny), (root_x + nx * 0.5, root_y + ny * 0.5)]
            d.polygon(outline, fill=255)
            # dark gap between feathers so each reads separately
            ds.line([(root_x, root_y), tip], fill=255, width=max(2, W // 500))
            ds.polygon([(mid[0] + nx * 0.85, mid[1] + ny * 0.85), tip, (mid[0] + nx, mid[1] + ny)], fill=200)
    wing_metal = metal(wings, [(250, 230, 170), (214, 162, 72), (140, 88, 26), (90, 52, 14)], bevel=W // 260)
    grooves = Image.new("RGBA", (W, H), (60, 30, 6, 0))
    grooves.putalpha(ImageChops.multiply(wing_shade, wings).filter(ImageFilter.GaussianBlur(1)).point(lambda v: int(v * 0.7)))
    wing_metal.alpha_composite(grooves)
    img.alpha_composite(wing_metal)
    # a single blade pointing down beneath the ribbon
    tipd = Image.new("L", (W, H), 0)
    ImageDraw.Draw(tipd).polygon([(cx - W * 0.03 * K, cy + ph * 0.5), (cx, cy + ph * 0.5 + H * 0.26 * K),
                                  (cx + W * 0.03 * K, cy + ph * 0.5)], fill=255)
    img.alpha_composite(metal(tipd, [(250, 226, 160), (200, 146, 60), (110, 66, 20)], bevel=W // 300))

    # outer plate
    pts = plate_points(cx, cy, pw, ph, point)
    outer = shape((W, H), lambda dd: dd.polygon(pts, fill=255))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.putalpha(outer.filter(ImageFilter.GaussianBlur(W // 60)).point(lambda v: int(v * 0.7)))
    img.alpha_composite(shadow, (0, W // 120))
    img.alpha_composite(metal(outer, bevel=W // 110))

    # inner rim and ember panel
    rim = inset(pts, cx, cy, 0.955, 0.86)
    panel = inset(pts, cx, cy, 0.93, 0.78)
    rim_mask = shape((W, H), lambda dd: dd.polygon(rim, fill=255))
    img.alpha_composite(metal(rim_mask, [(120, 70, 20), (230, 180, 90), (90, 50, 14)], bevel=W // 300))
    rv = int(W / 60 * K)
    rivet = metal(shape((rv, rv), lambda dd: dd.ellipse((1, 1, rv - 2, rv - 2), fill=255)),
                  bevel=max(1, W // 600))
    ring = inset(pts, cx, cy, 0.985, 0.93)
    for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
        steps = int(math.hypot(x1 - x0, y1 - y0) // (W * 0.06 * K))
        for k in range(1, steps):
            x, y = x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps
            img.alpha_composite(rivet, (int(x - rivet.width / 2), int(y - rivet.height / 2)))
    panel_mask = shape((W, H), lambda dd: dd.polygon(panel, fill=255))
    ember = vgrad(W, H, [(48, 8, 10), (128, 26, 12), (190, 60, 18), (96, 18, 10)]).convert("RGBA")
    heat = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(heat)
    for _ in range(int(W * 0.6)):
        x, y = rng.uniform(cx - pw / 2, cx + pw / 2), rng.uniform(cy - ph / 2, cy + ph / 2)
        r = rng.uniform(W * 0.004, W * 0.03)
        hd.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=(255, rng.randint(90, 160), 40, rng.randint(10, 40)))
    ember.alpha_composite(heat.filter(ImageFilter.GaussianBlur(W // 120)))
    inner_shadow = ImageChops.invert(panel_mask).filter(ImageFilter.GaussianBlur(W // 70))
    dark = Image.new("RGBA", (W, H), (20, 4, 4, 0))
    dark.putalpha(inner_shadow.point(lambda v: min(255, int(v * 1.6))))
    ember.alpha_composite(dark)
    ember.putalpha(panel_mask)
    img.alpha_composite(ember)

    # gems: crest and the two points
    g = gem(int(W * 0.075 * K), (150, 90, 230))
    img.alpha_composite(g, (int(cx - g.width / 2), int(cy - ph * 0.55 - g.height / 2)))
    sg = gem(int(W * 0.042 * K), (150, 90, 230))
    for side in (-1, 1):
        x = cx + side * (pw / 2 + point * 0.45)
        img.alpha_composite(sg, (int(x - sg.width / 2), int(cy - sg.height / 2)))

    # text
    title_font = fonts["title"]
    big = int(H * 0.2 * K)
    while True:
        line = gold_text("DESCENSION", ImageFont.truetype(title_font, big), max(3, big // 14))
        if line.width <= pw * 0.98:
            break
        big = int(big * 0.95)
    small = gold_text("PROJECT", ImageFont.truetype(title_font, int(big * 0.5)), max(2, big // 20))
    img.alpha_composite(small, (int(cx - small.width / 2), int(cy - ph * 0.40 - small.height * 0.12)))
    img.alpha_composite(line, (int(cx - line.width / 2), int(cy - line.height * 0.36)))

    # ribbon
    rw, rh = pw * 0.56, H * 0.12 * K
    ry = cy + ph * 0.5 + rh * 0.15
    tail = rw * 0.14
    ribbon_pts = [(cx - rw / 2, ry - rh / 2), (cx + rw / 2, ry - rh / 2), (cx + rw / 2 + tail, ry - rh * 0.1),
                  (cx + rw / 2 + tail * 0.6, ry + rh * 0.12), (cx + rw / 2 + tail * 1.1, ry + rh * 0.62),
                  (cx + rw / 2, ry + rh / 2), (cx - rw / 2, ry + rh / 2), (cx - rw / 2 - tail * 1.1, ry + rh * 0.62),
                  (cx - rw / 2 - tail * 0.6, ry + rh * 0.12), (cx - rw / 2 - tail, ry - rh * 0.1)]
    rmask = shape((W, H), lambda dd: dd.polygon(ribbon_pts, fill=255))
    rshadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rshadow.putalpha(rmask.filter(ImageFilter.GaussianBlur(W // 90)).point(lambda v: int(v * 0.7)))
    img.alpha_composite(rshadow, (0, W // 150))
    edge_mask = rmask
    img.alpha_composite(metal(edge_mask, [(240, 200, 120), (150, 96, 30)], bevel=W // 300))
    inner = shape((W, H), lambda dd: dd.polygon(inset(ribbon_pts, cx, ry, 0.97, 0.78), fill=255))
    cloth = metal(inner, [(96, 52, 150), (58, 26, 102), (34, 14, 64)], bevel=W // 200, light=0.6)
    img.alpha_composite(cloth)
    sub_font = ImageFont.truetype(fonts["sub"], int(rh * 0.5))
    try:
        sub_font.set_variation_by_axes([700])
    except Exception:
        pass
    word = "WILDCARD"
    spaced = " ".join(word)
    l, t, r, b = sub_font.getbbox(spaced)
    td = ImageDraw.Draw(img)
    td.text((cx - (r - l) / 2 - l + 2, ry - (b - t) / 2 - t + 2), spaced, font=sub_font, fill=(20, 8, 30, 200))
    td.text((cx - (r - l) / 2 - l, ry - (b - t) / 2 - t), spaced, font=sub_font, fill=(250, 232, 190, 255))

    bbox = img.getbbox()
    return img.crop(bbox)
