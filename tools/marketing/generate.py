"""
Generate all marketing art for "Dig to the Core! Beach Simulator".

    python3 tools/marketing/generate.py            # everything
    python3 tools/marketing/generate.py icon thumbs # subsets: icon thumbs social badges

Outputs go to marketing/ (see marketing/README.md). Deterministic: same seed -> same art.
"""

from __future__ import annotations

import math
import random
import sys

from art import *  # noqa: F401,F403
from art import (LAYERS, Canvas, character, darken, lighten, mix, pill_label, save, save_rgba, sprite,
                 strata, title_text, vgradient, wavy)
import art as A


# ============================================================ shared scene pieces
def sky(c: Canvas, y_h, top=(40, 140, 235), bot=(170, 232, 255)):
    g = vgradient(c.img.width, int(y_h * c.s), [(0, top), (0.7, mix(top, bot, .7)), (1, bot)])
    c.img.alpha_composite(g, (0, 0))
    c.refresh()


def hole_edges(cx, y0, y1, w0, w1, rng, step=10):
    ph1, ph2 = rng.uniform(0, 6), rng.uniform(0, 6)
    left, right = [], []
    y = y0
    while y <= y1 + 0.1:
        t = (y - y0) / max(1, (y1 - y0))
        hw = w0 + (w1 - w0) * t
        wob = 9 * math.sin(y * 0.022 + ph1) + 4 * math.sin(y * 0.061 + ph2)
        left.append((cx - hw + wob, y))
        right.append((cx + hw + wob + 5 * math.sin(y * 0.05 + ph2), y))
        y += step
    return left, right


def cut_hole(c: Canvas, cx, y0, y1, w0, w1, bounds, rng, layers=LAYERS):
    """Dig a tunnel through the strata: darker band colours inside + thick outline + inner shadow."""
    left, right = hole_edges(cx, y0, y1, w0, w1, rng)
    bottom = [(cx + w1 * 0.8, y1 + w1 * 0.35), (cx + w1 * 0.4, y1 + w1 * 0.6), (cx, y1 + w1 * 0.68),
              (cx - w1 * 0.4, y1 + w1 * 0.6), (cx - w1 * 0.8, y1 + w1 * 0.35)]
    poly = left + bottom + right[::-1]
    inner = c.layer()
    for i, (a, b) in enumerate(bounds):
        col = darken(layers[i][1], .45)
        inner.poly(wavy(-20, c.w + 20, a, 0 if i == 0 else 7, 0.012 + 0.002 * (i % 3), i * 1.7)
                   + [(c.w + 20, c.h + 50), (-20, c.h + 50)], col, None)
    mask = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(mask).polygon(c.P(poly), fill=255)
    # inner shadow: dark near the walls, darker on the left
    inv = ImageChops.invert(mask)
    inv = ImageChops.offset(inv, int(18 * c.s), 0).filter(ImageFilter.GaussianBlur(22 * c.s))
    sh = Image.new("RGBA", c.img.size, (15, 8, 35, 255))
    sh.putalpha(inv.point(lambda v: min(255, int(v * 1.25))))
    inner.img.alpha_composite(sh)
    inner.img.putalpha(ImageChops.multiply(inner.img.getchannel("A"), mask))
    c.poly(poly, None, STROKE, 7)
    c.d.polygon(c.P(poly), fill=(0, 0, 0, 255))
    c.over(inner)
    return poly


def beach_surface(c: Canvas, y, rng, x0=0, x1=None):
    x1 = x1 if x1 is not None else c.w
    top = wavy(x0 - 20, x1 + 20, y, 6, 0.01, 0.3)
    c.poly(top + [(x1 + 20, y + 60), (x0 - 20, y + 60)], A.SAND, A.STROKE, 5)
    for _ in range(int((x1 - x0) / 25)):
        x = rng.uniform(x0, x1)
        yy = y + rng.uniform(4, 22)
        c.ellipse((x - 5, yy - 2, x + 5, yy + 2), A.SAND_DARK)


def ocean(c: Canvas, y_top, y_bot):
    g = vgradient(c.img.width, int((y_bot - y_top) * c.s), [(0, (30, 150, 230)), (1, (70, 215, 250))])
    c.img.alpha_composite(g, (0, int(y_top * c.s)))
    c.refresh()
    for i, yy in enumerate(range(int(y_top) + 14, int(y_bot), 22)):
        for x in range(-40 + (i % 2) * 70, c.w, 140):
            c.d.arc(c.B((x, yy - 6, x + 50, yy + 10)), 200, 340, fill=(255, 255, 255, 170), width=c.W(4))
    c.line([(0, y_top), (c.w, y_top)], (20, 110, 200), 4)


def hole_mouth(c: Canvas, cx, y, rx, ry):
    """Perspective opening of the hole at the surface with a sand rim."""
    c.ellipse((cx - rx - 26, y - ry - 14, cx + rx + 26, y + ry + 12), A.SAND_DARK, STROKE, 6)
    c.ellipse((cx - rx - 20, y - ry - 12, cx + rx + 20, y + ry - 2), A.SAND)
    c.ellipse((cx - rx, y - ry, cx + rx, y + ry), (60, 40, 30), STROKE, 5)
    c.ellipse((cx - rx * .9, y - ry * .55, cx + rx * .9, y + ry), (25, 15, 20))


def core_glow(c: Canvas, cx, cy, r):
    c.glow(cx, cy, r * 2.6, (255, 170, 40), 230, 1.3)
    c.glow(cx, cy, r * 1.5, (255, 230, 120), 255, 1.2)
    A.sunburst(c, cx, cy, 18, r * 2.4, (255, 240, 170), 60, 0.1)
    c.circle(cx, cy, r, (255, 160, 30), A.STROKE, 8)
    c.circle(cx, cy, r * 0.84, (255, 200, 60))
    c.circle(cx, cy, r * 0.62, (255, 235, 140))
    c.circle(cx, cy, r * 0.38, (255, 252, 225))
    c.ellipse((cx - r * .6, cy - r * .75, cx - r * .1, cy - r * .45), (255, 255, 255, 140))


def put(c: Canvas, fn, x, y, size, rot=0.0, glow=None, flip=False, outline=10):
    if glow:
        c.glow(x, y, size * 0.95, glow, 170, 1.5)
    c.paste(sprite(fn, size, outline=outline), x, y, rot=rot, flip=flip)


TITLE_SAFE = 0.06  # titles keep this fraction of the short side clear of every edge


def title_safe_centre(t, cx, cy, w, h, s):
    """Shift (cx, cy) so the title's visible pixels stay TITLE_SAFE inside a w x h canvas."""
    box = t.getchannel("A").getbbox()
    if not box:
        return cx, cy
    margin = TITLE_SAFE * min(w, h)
    left = cx - t.width / (2 * s) + box[0] / s
    right = cx - t.width / (2 * s) + box[2] / s
    top = cy - t.height / (2 * s) + box[1] / s
    bottom = cy - t.height / (2 * s) + box[3] / s
    if top < margin:
        cy += margin - top
    elif bottom > h - margin:
        cy -= bottom - (h - margin)
    if left < margin:
        cx += margin - left
    elif right > w - margin:
        cx -= right - (w - margin)
    return cx, cy


def put_title(c: Canvas, text, cx, cy, size, rot=-4, **kw):
    t = title_text(text, size, rot=rot, **kw)
    cx, cy = title_safe_centre(t, cx, cy, c.w, c.h, c.s)
    c.paste(t, cx, cy)
    return t


def vignette(c: Canvas, strength=90):
    w, h = c.img.size
    v = A.rgradient(w, h, w / 2, h / 2, math.hypot(w, h) / 2, (0, 0, 0, 0), (15, 5, 40, strength), 2.2)
    c.img.alpha_composite(v)
    c.refresh()


# ============================================================ thumbnail 1 — hero cross-section
def thumb_hero(seed=1) -> Image.Image:
    rng = random.Random(seed)
    W, H = 1920, 1080
    c = Canvas(W, H)
    SURF = 430
    sky(c, SURF)
    A.sun(c, 1720, 110, 66)
    for x, y, w in ((40, 70, 280), (330, 230, 200), (1340, 250, 240), (1560, 300, 180)):
        A.cloud(c, x, y, w)
    ocean(c, 335, SURF)
    A.palm(c, 110, SURF + 6, 330, 1)
    A.palm(c, 1815, SURF + 6, 310, -1)
    bounds = strata(c, 0, W, SURF, 1080, LAYERS[:14], rng, weights=[0.85] * 4 + [1.0] * 10)
    A.decorate_layers(c, bounds, 0, W, rng, LAYERS[:14])
    beach_surface(c, SURF - 12, rng)
    CX = 960
    CORE_Y, CORE_R = 1085, 215
    cut_hole(c, CX, SURF - 10, CORE_Y - CORE_R + 30, 135, 90, bounds, rng)
    hole_mouth(c, CX + 4, SURF - 12, 150, 30)
    c.glow(CX, CORE_Y - CORE_R - 40, 320, (255, 200, 80), 220, 1.4)
    core_glow(c, CX, CORE_Y, CORE_R)
    items = [
        (1, A.pet_starfish, 640, 0.0, 66, None),
        (3, A.tr_anchor, 1300, 20, 82, None),
        (4, A.tr_chest, 560, -8, 124, (255, 220, 80)),
        (5, A.tr_coin, 1420, 15, 70, (255, 220, 80)),
        (6, A.tr_skull, 1250, 8, 130, None),
        (6, A.tr_bone, 330, -10, 86, None),
        (8, A.tr_crystal, 620, -5, 116, (200, 140, 255)),
        (8, A.tr_crystal, 1600, 6, 100, (200, 140, 255)),
        (9, A.tr_diamond, 1360, -12, 80, (160, 240, 255)),
        (10, A.tr_crown, 430, 10, 96, (255, 220, 80)),
        (11, A.tr_egg, 1300, -10, 76, (255, 140, 40)),
        (12, A.tr_rainbow_diamond, 600, 8, 78, (255, 120, 255)),
        (12, A.tr_ufo, 1790, -8, 104, (120, 255, 150)),
        (12, A.pet_alien, 250, 6, 84, (120, 255, 150)),
    ]
    for idx, fn, x, rot, size, glow in items:
        a, b = bounds[idx]
        put(c, fn, x, (a + b) / 2 + 4, size, rot, glow)
    for _ in range(22):
        A.sparkle(c, CX + rng.choice([-1, 1]) * rng.uniform(250, 480), rng.uniform(860, 1070), rng.uniform(8, 20),
                  (255, 250, 210))
    # hero on the lip of the hole, sand flying out to the right
    A.sand_spray(c, CX + 40, SURF - 10, rng, n=34, dirx=1, height=230, reach=330)
    put(c, lambda cc: character(cc, pose="dig"), CX - 215, SURF - 118, 260)
    put(c, A.pet_crab, CX + 330, SURF - 38, 110)
    put(c, A.pet_turtle, CX - 470, SURF - 34, 100, flip=True)
    put_title(c, "DIG TO THE CORE!", W / 2, 132, 172, rot=-3)
    c.paste(pill_label("1,000 m DEEP!", 46, bg=(255, 80, 60), rot=6), 1500, 1000)
    vignette(c, 70)
    return c.final()


# ============================================================ thumbnail 2 — pets
def burst_bg(c: Canvas, cx, cy, inner, outer, ray=(255, 255, 255), n=20, ray_alpha=40):
    bg = A.rgradient(c.img.width, c.img.height, cx * c.s, cy * c.s, 1100 * c.s, rgba(inner), rgba(outer), 0.9)
    c.img.alpha_composite(bg)
    c.refresh()
    A.sunburst(c, cx, cy, n, 1600, ray, ray_alpha, 0.05)


def confetti(c: Canvas, rng, n, box, cols=None):
    cols = cols or [(255, 90, 120), (255, 210, 60), (90, 220, 255), (120, 240, 140), (200, 120, 255)]
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        w, h = rng.uniform(8, 16), rng.uniform(16, 28)
        a = rng.uniform(0, math.pi)
        ca, sa = math.cos(a), math.sin(a)
        pts = [(x + dx * ca - dy * sa, y + dx * sa + dy * ca) for dx, dy in
               ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
        c.poly(pts, rng.choice(cols), STROKE, 2)


def sand_island(c: Canvas, cx, y, rx, ry):
    c.ellipse((cx - rx, y - ry + 26, cx + rx, y + ry + 40), A.SAND_DARK, STROKE, 7)
    c.ellipse((cx - rx, y - ry, cx + rx, y + ry), A.SAND, STROKE, 7)
    c.ellipse((cx - rx * .8, y - ry * .8, cx + rx * .3, y - ry * .1), lighten(A.SAND, .35))


def thumb_pets(seed=2) -> Image.Image:
    rng = random.Random(seed)
    W, H = 1920, 1080
    c = Canvas(W, H)
    burst_bg(c, 960, 640, (255, 140, 230), (90, 40, 190), n=22, ray_alpha=38)
    sand_island(c, 960, 960, 900, 110)
    # the hatch: the Magma Egg (Config/Eggs: dark shell, orange spots) cracking open, the Core
    # Dragon (Mythic, magma_egg) bursting out
    MAGMA_SHELL, MAGMA_SPOTS = (60, 30, 30), (255, 100, 30)
    c.glow(960, 610, 470, (255, 190, 110), 255, 1.3)
    A.sunburst(c, 960, 610, 16, 520, (255, 230, 180), 80, 0.3)
    confetti(c, rng, 46, (0, 260, W, 780))
    c.ellipse((760, 640, 1160, 740), (255, 120, 40), STROKE, 7)       # glowing inside of the shell
    c.ellipse((780, 655, 1140, 735), (200, 60, 20))
    put(c, A.pet_dragon, 960, 530, 380)
    egg = lambda cc: A.tr_egg_bottom(cc, MAGMA_SHELL, MAGMA_SPOTS)
    put(c, egg, 960, 760, 440, glow=(255, 120, 40))
    put(c, lambda cc: A.tr_egg_top(cc, MAGMA_SHELL, MAGMA_SPOTS), 1250, 330, 230, rot=-35)
    for _ in range(26):
        A.sparkle(c, 960 + rng.uniform(-330, 330), 600 + rng.uniform(-260, 220), rng.uniform(10, 26), (255, 255, 230))
    # pet parade on the island
    parade = [
        (A.pet_crab, 300, 900, 200, (255, 210, 40), (255, 255, 200)),     # Golden Crab
        (A.pet_octopus, 560, 830, 200, None, None),
        (A.pet_seal, 1370, 840, 210, None, None),
        (A.pet_phoenix, 1630, 880, 220, None, None),
        (A.pet_turtle, 1700, 560, 180, None, None),
        (A.pet_alien, 220, 560, 170, None, None),
        (A.pet_starfish, 470, 520, 140, None, None),
        (A.pet_crab, 1470, 520, 140, None, None),
    ]
    for fn, x, y, size, b1, b2 in parade:
        f = fn if b1 is None else (lambda cc, fn=fn, b1=b1, b2=b2: fn(cc, b1, b2))
        put(c, f, x, y, size, rot=rng.uniform(-8, 8))
    c.paste(pill_label("MYTHIC!", 52, bg=(255, 70, 120), rot=-6), 960, 935)
    put_title(c, "HATCH RARE PETS!", W / 2, 140, 180, rot=-3, fill_top=(255, 255, 255), fill_bot=(130, 230, 255))
    vignette(c, 80)
    return c.final()


# ============================================================ thumbnail 3 — treasure
def cave_bg(c: Canvas, rng, top=(120, 80, 50), bot=(55, 35, 30)):
    g = vgradient(c.img.width, c.img.height, [(0, top), (1, bot)])
    c.img.alpha_composite(g)
    c.refresh()
    cols = [LAYERS[4][1], LAYERS[5][1], LAYERS[3][1], LAYERS[5][1], LAYERS[4][1], LAYERS[7][1]]
    y = 120
    for i, col in enumerate(cols):
        pts = wavy(-20, c.w + 20, y, 14, 0.008, i * 2.1)
        c.poly(pts + [(c.w + 20, c.h + 40), (-20, c.h + 40)], darken(col, .25 + i * 0.05), None)
        c.line(pts, darken(col, .55), 4)
        for _ in range(40):
            x = rng.uniform(0, c.w)
            yy = y + rng.uniform(20, 160)
            r = rng.uniform(3, 8)
            c.ellipse((x - r * 1.4, yy - r, x + r * 1.4, yy + r), darken(col, .4 + i * 0.05))
        y += 170


def thumb_treasure(seed=3) -> Image.Image:
    rng = random.Random(seed)
    W, H = 1920, 1080
    c = Canvas(W, H)
    cave_bg(c, rng)
    # light shaft from the hole above
    c.poly([(860, 0), (1060, 0), (1260, 1080), (660, 1080)], (255, 240, 170, 50), None)
    c.glow(1000, 640, 620, (255, 200, 60), 255, 1.2)
    A.sunburst(c, 1000, 640, 18, 900, (255, 240, 160), 70, 0.0)
    # floor
    c.ellipse((300, 900, 1700, 1180), darken(LAYERS[4][1], .1), STROKE, 7)
    # the chest + coin fountain
    for k in range(26):
        t = k / 26
        ang = math.radians(-160 + 140 * t + rng.uniform(-6, 6))
        dist = rng.uniform(230, 470)
        x, y = 1000 + math.cos(ang) * dist, 560 + math.sin(ang) * dist * 0.75
        fn = rng.choice([A.tr_coin] * 4 + [A.tr_diamond, lambda cc: A.tr_diamond(cc, (255, 80, 120)),
                                          lambda cc: A.tr_diamond(cc, (90, 230, 120))])
        put(c, fn, x, y, rng.uniform(48, 86), rot=rng.uniform(-40, 40), outline=9)
    put(c, A.tr_chest, 1000, 720, 460)
    for _ in range(30):
        A.sparkle(c, 1000 + rng.uniform(-520, 520), 640 + rng.uniform(-360, 260), rng.uniform(10, 28),
                  (255, 255, 220))
    # rare finds around the edges
    finds = [(A.tr_rainbow_diamond, 1590, 470, 200, -10, (255, 140, 255), "LEGENDARY", (255, 170, 30)),
             (A.tr_beachball, 1640, 800, 190, 12, (255, 240, 160), "MYTHIC", (255, 70, 120)),
             (A.tr_skull, 230, 930, 190, 8, None, None, None),
             (A.tr_crown, 1640, 230, 150, 14, (255, 220, 80), None, None)]
    for fn, x, y, size, rot, glow, label, lc in finds:
        put(c, fn, x, y, size, rot=rot, glow=glow)
        if label:
            c.paste(pill_label(label, 30, bg=lc, rot=rot * 0.4), x, y + size * 0.62)
    put(c, lambda cc: character(cc, pose="cheer", shirt=(60, 200, 120)), 470, 640, 400)
    put(c, lambda cc: A.pet_crab(cc, (200, 50, 40)), 680, 900, 150)
    put_title(c, "FIND LEGENDARY\nTREASURE!", W / 2, 165, 150, rot=-3)
    vignette(c, 100)
    return c.final()


# ============================================================ thumbnail 4 — rebirth & go deeper
MARBLE = (246, 242, 255)
SHRINE_PURPLE = (170, 100, 255)


def rebirth_shrine(c: Canvas, cx, base_y, scale, rng):
    """World/Hub.buildRebirth seen from the front: three stepped marble tiers (the middle one
    lilac), a purple glow disc on the top step, a marble pedestal with the purple REBIRTH sign,
    the golden digger statue holding its shovel up, and two purple orbs."""
    u = scale  # px per stud
    lilac = mix(SHRINE_PURPLE, WHITE, 0.55)
    gold = (255, 205, 40)
    c.glow(cx, base_y - 12 * u, 13 * u, (190, 130, 255), 200, 1.4)
    for w, h, y, col in ((14, 1, 0, MARBLE), (11, 1, 1, lilac), (8, 1, 2, MARBLE)):
        box3d(c, cx - w * u / 2, base_y - (y + h) * u, w * u, h * u, col, d=int(u * 0.9), width=6)
    # neon glow disc lying on the top step (horizontal, seen at a low angle)
    c.glow(cx, base_y - 3.05 * u, 6 * u, (200, 140, 255), 230, 1.4)
    c.ellipse((cx - 4.5 * u, base_y - 3.05 * u - 0.9 * u, cx + 4.5 * u, base_y - 3.05 * u + 0.9 * u),
              (210, 160, 255), STROKE, 5)
    # pedestal + sign
    box3d(c, cx - 2 * u, base_y - 8 * u, 4 * u, 5 * u, MARBLE, d=int(u * 0.8), width=6)
    c.paste(pill_label("REBIRTH", int(1.35 * u), bg=SHRINE_PURPLE), cx, base_y - 1.7 * u)
    # golden statue: legs, torso, arms, head, shovel raised high
    def g(x0, y0, w, h):
        c.rrect((cx + (x0 - w / 2) * u, base_y - (y0 + h / 2) * u, cx + (x0 + w / 2) * u, base_y - (y0 - h / 2) * u),
                int(0.25 * u), gold, STROKE, 6)
    g(0, 9.2, 2.4, 2.4)
    g(0, 11.9, 3, 3)
    g(-1.95, 11.8, 0.9, 2.8)
    g(1.95, 14.6, 0.9, 3.4)
    g(1.95, 18.5, 0.4, 6)
    g(1.95, 22.4, 1.8, 2.4)
    c.circle(cx, base_y - 14.7 * u, 1.3 * u, gold, STROKE, 6)
    shine(c, (cx - 1.5 * u, base_y - 13.4 * u, cx - 0.2 * u, base_y - 10.6 * u), 90)
    for x in (-5, 5):
        c.glow(cx + x * u, base_y - 9 * u, 1.6 * u, (190, 120, 255), 230, 1.3)
        c.circle(cx + x * u, base_y - 9 * u, 0.7 * u, (150, 90, 230), STROKE, 5)


def portal(c: Canvas, cx, cy, r, rng, cols=((120, 255, 200), (60, 160, 255), (190, 110, 255))):
    c.glow(cx, cy, r * 1.7, (120, 255, 220), 230, 1.3)
    c.circle(cx, cy, r, (40, 30, 90), STROKE, 10)
    for k in range(5):
        rr = r * (1 - k * 0.17)
        col = cols[k % len(cols)]
        for j in range(3):
            a0 = j * 120 + k * 37
            c.d.arc(c.B((cx - rr, cy - rr, cx + rr, cy + rr)), a0, a0 + 80, fill=rgba(col), width=c.W(18 - k * 2))
    c.glow(cx, cy, r * 0.6, (220, 255, 250), 255, 1.2)


def ring_arrows(c: Canvas, cx, cy, r, col=(120, 255, 200)):
    """Two chunky circular arrows chasing each other around (cx, cy)."""
    box = c.B((cx - r, cy - r, cx + r, cy + r))
    for a0 in (200, 20):
        a1 = a0 + 125
        c.d.arc(box, a0, a1, fill=rgba(STROKE), width=c.W(52))
        c.d.arc(box, a0, a1, fill=rgba(col), width=c.W(34))
        c.d.arc(c.B((cx - r + 8, cy - r + 8, cx + r - 8, cy + r - 8)), a0 + 6, a1 - 6, fill=rgba(lighten(col, .5)),
                width=c.W(8))
        t = math.radians(a1)
        hx, hy = cx + r * math.cos(t), cy + r * math.sin(t)
        tx, ty = -math.sin(t), math.cos(t)          # direction of travel (clockwise)
        nx, ny = math.cos(t), math.sin(t)
        tip = (hx + tx * 70, hy + ty * 70)
        c.poly([(hx + nx * 50, hy + ny * 50), tip, (hx - nx * 50, hy - ny * 50)], col, STROKE, 7)


def thumb_rebirth(seed=4, badge="NEW GAME!") -> Image.Image:
    rng = random.Random(seed)
    W, H = 1920, 1080
    c = Canvas(W, H)
    deep = LAYERS[8:14]
    bounds = strata(c, 0, W, -20, 1080, deep, rng, weights=[1.0] * len(deep))
    A.decorate_layers(c, bounds, 0, W, rng, deep)
    c.poly([(0, 0), (W, 0), (W, H), (0, H)], (20, 10, 50, 90), None)
    # a tunnel plunging down the right side towards the Core
    cut_hole(c, 1530, -40, 860, 120, 100, bounds, rng, deep)
    c.glow(1530, 1080, 360, (255, 190, 60), 255, 1.3)
    core_glow(c, 1530, 1140, 170)
    put(c, A.tr_arrow_down, 1530, 560, 230)
    # the Rebirth Shrine as built in the hub, the hero celebrating beside it
    ring_arrows(c, 580, 720, 300)
    rebirth_shrine(c, 580, 1010, 25, rng)
    put(c, lambda cc: character(cc, pose="cheer", shirt=(170, 100, 255)), 950, 770, 290)
    put(c, A.pet_phoenix, 1000, 500, 140, rot=8)
    put(c, A.pet_dragon, 230, 900, 180, rot=-8)
    for txt, x, y, sz, col in (("x1.5", 1190, 470, 60, (90, 220, 110)), ("x2", 1200, 620, 74, (60, 170, 255)),
                               ("x2.5", 1180, 790, 90, (255, 90, 160))):
        c.paste(pill_label(txt, sz, bg=col, rot=rng.uniform(-8, 8)), x, y)
    for _ in range(30):
        A.sparkle(c, 700 + rng.uniform(-420, 420), 600 + rng.uniform(-380, 380), rng.uniform(8, 22), (220, 255, 250))
    put_title(c, "REBIRTH &\nGO DEEPER!", 720, 160, 140, rot=-4,
              fill_top=(190, 255, 240), fill_bot=(60, 200, 255))
    if badge:
        c.paste(pill_label(badge, 54, bg=(255, 70, 90), rot=10), 1620, 110)
    vignette(c, 90)
    return c.final()


# ============================================================ icon 512
def icon(seed=5, text="DIG!") -> Image.Image:
    rng = random.Random(seed)
    S = 512
    c = Canvas(S, S, s=2)
    SURF = 250
    sky(c, SURF, top=(30, 130, 235), bot=(160, 230, 255))
    A.sun(c, 455, 55, 30)
    lay = [LAYERS[0], LAYERS[4], LAYERS[6], LAYERS[8], LAYERS[11], LAYERS[13]]
    bounds = strata(c, 0, S, SURF, S, lay, rng, line_w=4)
    beach_surface(c, SURF - 8, rng)
    CX = 330
    cut_hole(c, CX, SURF - 6, 470, 74, 60, bounds, rng, lay)
    hole_mouth(c, CX + 2, SURF - 8, 86, 18)
    c.glow(CX, 480, 220, (255, 190, 60), 255, 1.2)
    core_glow(c, CX, 570, 120)
    put(c, A.tr_chest, 120, (bounds[1][0] + bounds[1][1]) / 2, 74, -8, (255, 220, 80), outline=9)
    put(c, A.tr_crystal, 100, (bounds[3][0] + bounds[3][1]) / 2, 70, 6, (200, 140, 255), outline=9)
    A.sand_spray(c, CX + 30, SURF - 14, rng, n=16, dirx=1, height=130, reach=150, size=(5, 11))
    put(c, lambda cc: character(cc, pose="dig"), CX - 175, SURF - 98, 230, outline=11)
    put_title(c, text, 330, 92, 132, rot=-7)
    vignette(c, 50)
    return c.final()


# ============================================================ social
def discord_banner() -> Image.Image:
    """960x540 Discord server banner: the hero scene plus a community call-out."""
    c = Canvas(960, 540, s=2)
    c.img = thumb_hero(seed=11).convert("RGBA")  # 1920x1080 == 960x540 at s=2
    c.refresh()
    c.paste(pill_label("CODES & UPDATES!", 30, bg=(90, 110, 255), rot=-5), 175, 495)
    return c.final()


def x_header(seed=12) -> Image.Image:
    rng = random.Random(seed)
    W, H = 1500, 500
    c = Canvas(W, H)
    SURF = 210
    sky(c, SURF)
    A.sun(c, 1420, 70, 44)
    for x, y, w in ((40, 30, 200), (1150, 110, 170)):
        A.cloud(c, x, y, w)
    ocean(c, 160, SURF)
    bounds = strata(c, 0, W, SURF, H, LAYERS[:14], rng, weights=[1] * 14, line_w=3)
    A.decorate_layers(c, bounds, 0, W, rng, LAYERS[:14])
    beach_surface(c, SURF - 8, rng)
    CX = 1100
    cut_hole(c, CX, SURF - 6, 470, 80, 60, bounds, rng)
    hole_mouth(c, CX + 2, SURF - 8, 90, 20)
    c.glow(CX, 500, 220, (255, 190, 60), 255, 1.3)
    core_glow(c, CX, 600, 130)
    for idx, fn, x, size, glow in ((4, A.tr_chest, 820, 70, (255, 220, 80)), (6, A.tr_skull, 1330, 70, None),
                                   (8, A.tr_crystal, 600, 64, (200, 140, 255)),
                                   (11, A.tr_egg, 1360, 50, (255, 140, 40))):
        a, b = bounds[idx]
        put(c, fn, x, (a + b) / 2, size, 0, glow, outline=8)
    A.sand_spray(c, CX + 20, SURF - 10, rng, n=20, dirx=1, height=120, reach=200, size=(4, 10))
    put(c, lambda cc: character(cc, pose="dig"), CX - 130, SURF - 75, 170)
    put(c, A.pet_crab, CX + 230, SURF - 25, 70)
    put_title(c, "DIG TO THE CORE!", 500, 105, 96, rot=-3)
    vignette(c, 50)
    return c.final()


# ============================================================ badges
BADGES = [
    # file, emblem, ring colour, bg colour, ribbon text
    ("01_welcome", A.tr_shovel, (255, 205, 40), (90, 200, 255), "WELCOME!"),
    ("02_first_pet", A.tr_egg, (90, 220, 110), (255, 170, 220), "FIRST PET"),
    ("03_pirate_cove", A.tr_chest, (255, 205, 40), LAYERS[4][1], "110 m"),
    ("04_fossil_bed", A.tr_skull, (230, 230, 240), LAYERS[6][1], "200 m"),
    ("05_crystal_caverns", A.tr_crystal, (200, 150, 255), LAYERS[8][1], "330 m"),
    ("06_frozen_abyss", A.tr_snowflake, (160, 230, 255), (60, 140, 220), "410 m"),
    ("07_magma_chamber", A.tr_flame, (255, 150, 40), (150, 30, 20), "585 m"),
    ("08_alien_hive", A.pet_alien, (120, 255, 150), (40, 90, 60), "780 m"),
    ("09_the_core", A.tr_core, (255, 220, 80), (255, 120, 30), "THE CORE!"),
    ("10_first_rebirth", A.tr_rebirth, (120, 255, 200), (90, 50, 180), "REBIRTH"),
]


def badge(emblem, ring, bg, ribbon) -> Image.Image:
    S = 512
    c = Canvas(S, S, s=2)
    c.circle(256, 256, 244, STROKE)
    c.circle(256, 256, 232, ring)
    c.circle(256, 256, 232 * 0.86 + 6, darken(ring, .3))
    inner = A.rgradient(S * 2, S * 2, 256 * 2, 200 * 2, 240 * 2, rgba(lighten(bg, .35)), rgba(darken(bg, .25)), 1)
    m = Image.new("L", (S * 2, S * 2), 0)
    ImageDraw.Draw(m).ellipse([(256 - 196) * 2, (256 - 196) * 2, (256 + 196) * 2, (256 + 196) * 2], fill=255)
    inner.putalpha(m)
    c.over(inner)
    A.sunburst(c, 256, 230, 12, 196, (255, 255, 255), 30)
    c.ellipse((110, 60, 300, 130), (255, 255, 255, 70))
    c.glow(256, 230, 180, (255, 255, 230), 150, 1.4)
    c.paste(sprite(emblem, 250, outline=11), 256, 222)
    lab = pill_label(ribbon, 54, bg=darken(ring, .05) if sum(ring) < 600 else (255, 90, 80))
    if lab.width > 420 * 2:
        lab = lab.resize((420 * 2, int(lab.height * 420 * 2 / lab.width)), Image.LANCZOS)
    c.paste(lab, 256, 402)
    mask = Image.new("L", c.img.size, 0)
    ImageDraw.Draw(mask).ellipse([4, 4, c.img.width - 4, c.img.height - 4], fill=255)
    c.img.putalpha(ImageChops.multiply(c.img.getchannel("A"), mask))
    return c.final()


# ============================================================ main
def main(argv):
    which = set(argv) or {"icon", "thumbs", "social", "badges"}
    if "thumbs" in which or "t1" in which:
        save(thumb_hero(), "thumbnails/thumb_1.png")
    if "thumbs" in which or "t2" in which:
        save(thumb_pets(), "thumbnails/thumb_2.png")
    if "thumbs" in which or "t3" in which:
        save(thumb_treasure(), "thumbnails/thumb_3.png")
    if "thumbs" in which or "t4" in which:
        save(thumb_rebirth(), "thumbnails/thumb_4.png")
        save(thumb_rebirth(badge="UPDATE 1"), "thumbnails/thumb_4_update1.png")
    if "icon" in which:
        save(icon(), "icon.png")
    if "social" in which:
        save(discord_banner(), "social/discord_banner.png")
        save(x_header(), "social/x_header.png")
    if "badges" in which:
        for name, emblem, ring, bg, ribbon in BADGES:
            save_rgba(badge(emblem, ring, bg, ribbon), f"badges/{name}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
