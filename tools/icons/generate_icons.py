#!/usr/bin/env python3
"""
UI icon atlas generator for "Dig to the Core! Beach Simulator".

    python3 tools/icons/generate_icons.py

Writes
    assets/icons/atlas.png          1024x1024, 8x8 grid of 128x128 cells, transparent
    assets/icons/png/<name>.png     every icon at 128x128 (for review)
    assets/icons/preview_32.png     contact sheet at 32 px (readability check)
    src/shared/Config/IconAtlas.luau  name -> ImageRectOffset map (+ aliases for UI/Icons.luau keys)

Style: chunky cartoon "simulator" icons. Every shape is filled with a soft top->bottom gradient,
a hard darker shade band along its bottom edge and a thin light rim along its top edge, and gets a
thin ink stroke; the whole silhouette then gets a thick ink outline (~8% of the icon) and a soft
drop shadow. Everything is drawn procedurally with Pillow + numpy at 4x and LANCZOS-downsampled.
Palette / fonts come from tools/marketing/art.py (the thumbnail toolkit), which mirrors
src/shared/Config/Theme.luau.

Drawing coordinates: each icon is drawn in a 0..100 design box (y down) that maps onto the
centre of its 128 px cell, leaving room for the outline, the shadow and ~8 px of cell padding.
"""

from __future__ import annotations

import math
import os
import sys
from contextlib import contextmanager
from typing import Callable

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "marketing"))
from art import darken, font, lighten, mix  # noqa: E402  (house drawing helpers)

OUT_DIR = os.path.join(REPO, "assets", "icons")
LUAU_OUT = os.path.join(REPO, "src", "shared", "Config", "IconAtlas.luau")

CELL = 128
GRID = 8
SS = 4  # supersampling
N = CELL * SS
# design box (0..100) -> final px: x 19..109, y 15..105
BOX_X0, BOX_Y0, SPAN = 19.0, 15.0, 90.0
U = SPAN / 100.0 * SS  # supersampled px per design unit
OUTER = 6.5  # silhouette outline, final px (plus the ~3 px shape stroke = ~9.5 px = 7.5%)
STK = 3.2  # per-shape ink stroke, design units (~2.9 px final)
SHADOW_DY = 3.5  # final px

# ---------------------------------------------------------------- palette (Theme.luau)
INK = (27, 27, 36)  # #1b1b24
WHITE = (255, 255, 255)
SAND = (255, 222, 140)
SAND_D = (222, 176, 92)
OCEAN = (40, 190, 245)
OCEAN_D = (20, 110, 200)
SKY = (150, 225, 255)
SUNSET = (255, 140, 60)
CORAL = (255, 95, 125)
PALM = (70, 210, 120)
GOLD = (255, 205, 40)
PURPLE = (170, 100, 255)
RED = (245, 70, 80)
GREEN = (80, 215, 100)
TOKEN = (50, 220, 175)
WOOD = (190, 120, 60)
WOOD_L = (230, 170, 100)
STEEL = (200, 210, 225)
CREAM = (255, 250, 232)
GLASS = (205, 238, 255)
SKIN = (255, 206, 60)  # classic blocky-avatar yellow (same as art.SKIN)


# ---------------------------------------------------------------- mask helpers
def _bin(m: Image.Image) -> Image.Image:
    return m.point(lambda v: 255 if v > 127 else 0)


def dilate(m: Image.Image, r_px: float) -> Image.Image:
    """Round dilation by ~r_px: gaussian blur then a low threshold (2 sigma on straight edges)."""
    if r_px <= 0:
        return m
    b = m.filter(ImageFilter.GaussianBlur(r_px / 2.0))
    return b.point(lambda v: 255 if v > 6 else 0)


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def sub(a, *bs):
    out = a
    for b in bs:
        out = ImageChops.subtract(out, b)
    return out


def inter(a, b):
    return ImageChops.darker(a, b)


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.Y = np.arange(N, dtype=np.float32)[:, None]
        self._sc, self._ox, self._oy, self._rot, self._rc = 1.0, 0.0, 0.0, 0.0, (50.0, 50.0)

    # ------------------------------------------------------------ frames (scale/offset/rotate)
    @contextmanager
    def frame(self, sc=1.0, ox=0.0, oy=0.0, rot=0.0, rc=None):
        """Shapes drawn inside are scaled by sc about the design origin, offset by (ox, oy) and
        then rotated `rot` degrees clockwise about rc (final design coords)."""
        old = (self._sc, self._ox, self._oy, self._rot, self._rc)
        self._sc, self._ox, self._oy = sc, ox, oy
        self._rot, self._rc = rot, rc or (50.0, 50.0)
        try:
            yield self
        finally:
            self._sc, self._ox, self._oy, self._rot, self._rc = old

    def P(self, x, y):
        x = self._ox + x * self._sc
        y = self._oy + y * self._sc
        return ((BOX_X0 * SS) + x * U, (BOX_Y0 * SS) + y * U)

    def L(self, v):  # length in design units -> px
        return v * self._sc * U

    def _new(self):
        m = Image.new("L", (N, N), 0)
        return m, ImageDraw.Draw(m)

    def _done(self, m):
        if self._rot:
            cx, cy = (BOX_X0 * SS) + self._rc[0] * U, (BOX_Y0 * SS) + self._rc[1] * U
            m = m.rotate(-self._rot, resample=Image.BICUBIC, center=(cx, cy))
            m = _bin(m)
        return m

    # ------------------------------------------------------------ shape masks
    def poly(self, pts):
        m, d = self._new()
        d.polygon([self.P(x, y) for x, y in pts], fill=255)
        return self._done(m)

    def ell(self, x0, y0, x1, y1):
        m, d = self._new()
        a, b = self.P(x0, y0), self.P(x1, y1)
        d.ellipse([min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])], fill=255)
        return self._done(m)

    def circ(self, cx, cy, r):
        return self.ell(cx - r, cy - r, cx + r, cy + r)

    def rrect(self, x0, y0, x1, y1, r=0):
        m, d = self._new()
        a, b = self.P(x0, y0), self.P(x1, y1)
        d.rounded_rectangle([a[0], a[1], b[0], b[1]], radius=max(0, self.L(r)), fill=255)
        return self._done(m)

    def rect(self, x0, y0, x1, y1):
        return self.rrect(x0, y0, x1, y1, 0)

    def line(self, pts, w):
        m, d = self._new()
        P = [self.P(x, y) for x, y in pts]
        d.line(P, fill=255, width=max(1, int(round(self.L(w)))), joint="curve")
        r = self.L(w) / 2
        for x, y in P:
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return self._done(m)

    def arc(self, cx, cy, r, a0, a1, w, caps=True):
        """Thick arc centred on radius r; angles in degrees, clockwise from 3 o'clock."""
        m, d = self._new()
        R = r + w / 2
        a, b = self.P(cx - R, cy - R), self.P(cx + R, cy + R)
        d.arc([a[0], a[1], b[0], b[1]], a0, a1, fill=255, width=max(1, int(round(self.L(w)))))
        if caps:
            for t in (a0, a1):
                t = math.radians(t)
                x, y = self.P(cx + r * math.cos(t), cy + r * math.sin(t))
                rr = self.L(w) / 2
                d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
        return self._done(m)

    def pie(self, cx, cy, r, a0, a1):
        m, d = self._new()
        a, b = self.P(cx - r, cy - r), self.P(cx + r, cy + r)
        d.pieslice([a[0], a[1], b[0], b[1]], a0, a1, fill=255)
        return self._done(m)

    def text(self, s, cx, cy, size, kind="title"):
        m, d = self._new()
        d.text(self.P(cx, cy), s, font=font(kind, int(round(self.L(size)))), anchor="mm", fill=255)
        return self._done(m)

    def star(self, cx, cy, R, r, n=5, rot=-90.0):
        pts = []
        for i in range(n * 2):
            rad = R if i % 2 == 0 else r
            t = math.radians(rot + i * 180.0 / n)
            pts.append((cx + rad * math.cos(t), cy + rad * math.sin(t)))
        return self.poly(pts)

    def gear_mask(self, cx, cy, R, r, teeth=8, tw=0.42):
        pts = []
        for i in range(teeth):
            base = i * 2 * math.pi / teeth
            half = math.pi / teeth
            for t, rad in ((base - half * (1 - tw * .2), r), (base - half * tw, R),
                           (base + half * tw, R), (base + half * (1 - tw * .2), r)):
                pts.append((cx + rad * math.cos(t), cy + rad * math.sin(t)))
        return self.poly(pts)

    # ------------------------------------------------------------ painting
    def _comp(self, mask: Image.Image, rgb, alpha=1.0):
        lay = Image.new("RGBA", (N, N), rgb + (255,))
        if alpha < 1:
            mask = mask.point(lambda v: int(v * alpha))
        lay.putalpha(mask)
        self.img.alpha_composite(lay)

    def flat(self, m, col, alpha=1.0):
        self._comp(m, tuple(col[:3]), alpha)

    def ink(self, m):
        self._comp(m, INK)

    def fill(self, m, col, stroke=STK, shade=0.22, rim=0.35, grad=0.12, sk=None, rk=None, ink=INK,
             shade_col=None):
        """Fill a mask with the house cel style: ink stroke, gradient, bottom shade band, top rim."""
        a = np.asarray(m) > 127
        if not a.any():
            return
        if stroke:
            self._comp(dilate(m, self.L(stroke)), ink)
        rows = np.where(a.any(1))[0]
        y0, y1 = int(rows[0]), int(rows[-1])
        h = y1 - y0 + 1
        t = np.clip((self.Y - y0) / max(h, 1), 0, 1)
        top = np.array(lighten(col, grad), np.float32)
        bot = np.array(darken(col, grad * 0.6), np.float32)
        rgb = np.broadcast_to(top + (bot - top) * t[..., None], (N, N, 3)).copy()
        if shade:
            k = int(round((sk * U) if sk is not None else np.clip(0.18 * h, 1.6 * U, 7.5 * U)))
            k = max(1, min(k, N - 1))
            below = np.zeros_like(a)
            below[:-k] = a[k:]
            dx = max(1, k // 3)
            below2 = np.zeros_like(a)
            below2[:-k, :-dx] = a[k:, dx:]
            band = a & ~(below & below2)
            rgb[band] = shade_col or darken(col, shade)
        if rim:
            kr = int(round((rk * U) if rk is not None else np.clip(0.06 * h, 1.0 * U, 2.4 * U)))
            kr = max(1, kr)
            above = np.zeros_like(a)
            above[kr:] = a[:-kr]
            ins = kr * 2
            left = np.zeros_like(a)
            left[:, ins:] = a[:, :-ins]
            right = np.zeros_like(a)
            right[:, :-ins] = a[:, ins:]
            band = a & ~above & left & right
            rgb[band] = lighten(col, rim)
        out = np.dstack([rgb, a.astype(np.float32) * 255]).astype(np.uint8)
        self.img.alpha_composite(Image.fromarray(out, "RGBA"))

    def gloss(self, x0, y0, x1, y1, alpha=0.55):
        self.flat(self.ell(x0, y0, x1, y1), WHITE, alpha)

    def sparkle(self, cx, cy, r, col=WHITE):
        m = self.star(cx, cy, r, r * 0.3, n=4)
        self.fill(m, col, stroke=2.2, shade=0, rim=0, grad=0)

    # ------------------------------------------------------------ final compose
    def finish(self) -> Image.Image:
        a = _bin(self.img.getchannel("A"))
        ol = dilate(a, OUTER * SS)
        ol = ol.filter(ImageFilter.GaussianBlur(SS * 0.5)).point(lambda v: 255 if v > 127 else 0)
        base = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        # drop shadow
        sh = Image.new("L", (N, N), 0)
        sh.paste(ol, (0, int(SHADOW_DY * SS)))
        sh = sh.filter(ImageFilter.GaussianBlur(SS * 1.2)).point(lambda v: int(v * 0.42))
        shl = Image.new("RGBA", (N, N), (12, 8, 30, 255))
        shl.putalpha(sh)
        base.alpha_composite(shl)
        oll = Image.new("RGBA", (N, N), INK + (255,))
        oll.putalpha(ol)
        base.alpha_composite(oll)
        base.alpha_composite(self.img)
        return base.resize((CELL, CELL), Image.LANCZOS)


# ================================================================= reusable parts
def coin_face(ic: Icon, cx, cy, r, col=GOLD, sym="$"):
    ic.fill(ic.circ(cx, cy + r * 0.14, r), darken(col, .28), shade=0, rim=0)
    ic.fill(ic.circ(cx, cy, r), col, shade=0.12, sk=r * 0.12)
    ic.fill(ic.circ(cx, cy, r * 0.70), lighten(col, .18), stroke=1.6, ink=darken(col, .4), shade=0, rim=0,
            grad=0.05)
    if sym:
        ic.fill(ic.text(sym, cx, cy + r * 0.06, r * 1.15), darken(col, .3), stroke=0, shade=0, rim=0, grad=0)
    ic.gloss(cx - r * .6, cy - r * .72, cx - r * .1, cy - r * .42, 0.6)


def disc(ic: Icon, cx, cy, rx, ry, th, col=GOLD):
    side = union(ic.ell(cx - rx, cy - ry + th, cx + rx, cy + ry + th), ic.rect(cx - rx, cy, cx + rx, cy + th))
    ic.fill(side, darken(col, .25), shade=0.15, rim=0)
    ic.fill(ic.ell(cx - rx, cy - ry, cx + rx, cy + ry), col, shade=0, rim=0, grad=0.1)
    ic.fill(ic.ell(cx - rx * .62, cy - ry * .55, cx + rx * .62, cy + ry * .55), lighten(col, .22), stroke=1.4,
            ink=darken(col, .35), shade=0, rim=0, grad=0)


def x2_pill(ic: Icon, cx=72, cy=78, label="2x", col=CORAL):
    ic.fill(ic.rrect(cx - 26, cy - 15, cx + 26, cy + 15, 15), col, shade=0.2)
    ic.fill(ic.text(label, cx, cy + 2.5, 27), WHITE, stroke=2.4, shade=0.10, rim=0, grad=0.04)


def umbrella(ic: Icon, cols=(CORAL, WHITE), pole=WHITE, cx=50, top=8, bot=50, rx=46, base=True):
    """Beach umbrella; canopy apex at (cx, top), scalloped rim at y=bot."""
    ic.fill(ic.rrect(cx - 3.2, bot - 6, cx + 3.2, 96, 2), pole, shade=0.15)
    ry = bot - top
    dome = inter(ic.ell(cx - rx, top, cx + rx, bot + ry), ic.rect(cx - rx - 2, top - 2, cx + rx + 2, bot))
    n = 6
    sw = 2 * rx / n
    sc = union(*[ic.ell(cx - rx + i * sw, bot - sw * .45, cx - rx + (i + 1) * sw, bot + sw * .45)
                 for i in range(n)])
    canopy = union(dome, sc)
    ic.fill(canopy, cols[0], shade=0.2)
    for i in range(1, n, 2):
        xa, xb = cx - rx + i * sw, cx - rx + (i + 1) * sw
        wedge = ic.poly([(cx, top - 4), (cx + (xa - cx) * 1.3, bot + 12), (cx + (xb - cx) * 1.3, bot + 12)])
        ic.fill(inter(canopy, wedge), cols[1], stroke=1.6, shade=0.2)
    ic.fill(ic.circ(cx, top - 1, 4.2), GOLD, stroke=2.4, shade=0, rim=0)


def shovel_parts(ic: Icon):
    """Upright metal shovel in a ~0..116 tall local box, centred on x=50 (use inside a frame)."""
    ic.fill(ic.rrect(33, -8, 67, 6, 7), CORAL, shade=0.2)
    ic.fill(ic.rrect(43.5, 0, 56.5, 64, 4.5), WOOD, shade=0.18)
    blade = ic.poly([(24, 60), (76, 60), (76, 88), (50, 112), (24, 88)])
    ic.fill(blade, STEEL, shade=0.25)
    ic.flat(inter(blade, ic.poly([(29, 65), (48, 65), (48, 103), (29, 86)])), WHITE, 0.55)
    ic.fill(ic.rrect(39, 54, 61, 67, 3), darken(STEEL, .25), shade=0.15, rim=0)


def gear(ic: Icon, cx, cy, R, col=STEEL, teeth=8):
    ic.fill(ic.gear_mask(cx, cy, R, R * 0.76, teeth), col, shade=0.22)
    ic.fill(ic.circ(cx, cy, R * 0.52), lighten(col, .12), stroke=1.8, shade=0, rim=0)
    ic.fill(ic.circ(cx, cy, R * 0.26), darken(col, .45), stroke=2.2, shade=0, rim=0, grad=0)


def arrow_up_mask(ic: Icon, cx, top, bot, w=22, hw=56, hh=36):
    return union(ic.rrect(cx - w / 2, top + hh - 4, cx + w / 2, bot, 3),
                 ic.poly([(cx - hw / 2, top + hh), (cx, top), (cx + hw / 2, top + hh)]))


def egg_spots(ic: Icon, egg, spots, col=(90, 200, 255)):
    for (x, y, r) in spots:
        ic.fill(inter(ic.circ(x, y, r), egg), col, stroke=0, shade=0.2, rim=0, grad=0.05)


# ================================================================= icons
ICONS: list[tuple[str, Callable[["Icon"], None]]] = []


def icon(name):
    def deco(fn):
        ICONS.append((name, fn))
        return fn
    return deco


@icon("coins")
def _coins(ic: Icon):
    for y in (82, 71, 60, 49, 38):
        disc(ic, 32, y, 27, 10, 8)
    coin_face(ic, 64, 60, 31)


@icon("tokens")
def _tokens(ic: Icon):
    cx, cy, R, r = 50, 50, 47, 25
    outer = [(cx + R * math.cos(math.radians(-90 + 60 * i)), cy + R * math.sin(math.radians(-90 + 60 * i)))
             for i in range(6)]
    inner = [(cx + r * math.cos(math.radians(-90 + 60 * i)), cy + r * math.sin(math.radians(-90 + 60 * i)))
             for i in range(6)]
    ic.fill(ic.poly(outer), TOKEN, shade=0, rim=0)
    for i in range(6):
        j = (i + 1) % 6
        mid = math.radians(-90 + 60 * i + 30)
        k = -math.sin(mid)  # +1 faces up, -1 faces down
        col = lighten(TOKEN, .35 * k) if k > 0 else darken(TOKEN, -.3 * k)
        if abs(k) < 0.1:
            col = TOKEN
        col = lighten(col, .12) if math.cos(mid) < -0.1 else col
        ic.fill(ic.poly([outer[i], outer[j], inner[j], inner[i]]), col, stroke=1.4, shade=0, rim=0, grad=0)
    ic.fill(ic.poly(inner), lighten(TOKEN, .3), stroke=1.6, shade=0, rim=0, grad=0.15)
    ic.flat(ic.poly([inner[5], inner[0], (cx + 4, cy - 4), (cx - 14, cy + 2)]), WHITE, 0.55)
    ic.sparkle(80, 16, 10)


def sand_bucket(ic: Icon):
    ic.fill(ic.arc(50, 46, 31, 200, 340, 4.5), darken(CORAL, .35), shade=0, rim=0)
    with ic.frame(rot=28, rc=(66, 30)):
        ic.fill(ic.rrect(62, 2, 70, 40, 3), (255, 210, 50), shade=0.15, rim=0)
        ic.fill(ic.circ(66, 3, 6), (255, 210, 50), shade=0, rim=0)
    mound = union(ic.ell(16, 18, 84, 56), ic.ell(10, 30, 50, 56), ic.ell(50, 28, 90, 56))
    ic.fill(mound, SAND, shade=0.12)
    for (x, y, r) in ((34, 30, 2.6), (56, 26, 2.2), (70, 38, 2.6), (44, 40, 2.2), (24, 42, 2)):
        ic.flat(ic.circ(x, y, r), SAND_D)
    ic.fill(ic.poly([(18, 46), (82, 46), (74, 96), (26, 96)]), CORAL, shade=0.2)
    ic.fill(ic.rrect(13, 41, 87, 53, 6), lighten(CORAL, .15), shade=0.25)
    ic.fill(ic.star(50, 74, 13, 6), GOLD, stroke=2.2, shade=0.15, rim=0)


@icon("sand")
def _sand(ic: Icon):
    sand_bucket(ic)


@icon("backpack")
def _backpack(ic: Icon):
    col = SUNSET
    ic.fill(ic.arc(50, 18, 11, 180, 360, 5), darken(col, .3), shade=0, rim=0)
    ic.fill(ic.rrect(16, 16, 84, 96, 20), col, shade=0.22)
    ic.fill(ic.rrect(16, 16, 84, 48, 18), lighten(col, .08), shade=0.25)
    ic.fill(ic.rrect(25, 58, 75, 90, 9), darken(col, .12), shade=0.2)
    ic.flat(ic.rect(30, 66, 70, 68.5), darken(col, .35))
    ic.fill(ic.rrect(42, 40, 58, 56, 4), GOLD, stroke=2.6, shade=0.2, rim=0)


@icon("shovel")
def _shovel(ic: Icon):
    sc = 0.86
    with ic.frame(sc=sc, ox=50 - 50 * sc, oy=50 - 52 * sc, rot=45):
        shovel_parts(ic)


@icon("spade")
def _spade(ic: Icon):
    sc = 0.9
    with ic.frame(sc=sc, ox=50 - 50 * sc, oy=50 - 50 * sc, rot=-42):
        ic.fill(ic.arc(50, 0, 11, 0, 360, 8, caps=False), (255, 210, 50), shade=0.2)
        ic.fill(ic.rrect(43, 8, 57, 54, 5), (255, 210, 50), shade=0.15)
        scoop = ic.rrect(20, 46, 80, 106, 16)
        ic.fill(scoop, RED, shade=0.22)
        ic.fill(ic.rrect(29, 56, 71, 97, 10), darken(RED, .12), stroke=1.8, shade=0, rim=0)
        ic.gloss(26, 50, 40, 62, 0.6)


@icon("pickaxe")
def _pickaxe(ic: Icon):
    sc = 0.92
    with ic.frame(sc=sc, ox=50 - 50 * sc, oy=50 - 54 * sc, rot=40):
        ic.fill(ic.rrect(43.5, 14, 56.5, 108, 5), WOOD, shade=0.18)
        top, bot = [], []
        for i in range(21):
            x = 4 + i * 4.6
            dy = 0.010 * (x - 50) ** 2
            th = 17 - abs(x - 50) * 0.28
            top.append((x, 6 + dy))
            bot.append((x, 6 + dy + th))
        head = ic.poly(top + bot[::-1])
        ic.fill(head, (150, 160, 180), shade=0.25)
        ic.fill(ic.rrect(40, 6, 60, 28, 4), darken(STEEL, .3), shade=0.2)


@icon("depth")
def _depth(ic: Icon):
    ground = ic.rrect(4, 58, 96, 98, 12)
    ic.fill(ground, (165, 105, 60), shade=0.2)
    ic.fill(inter(ground, ic.rect(0, 50, 100, 72)), SAND, stroke=2.2, shade=0.15)
    ic.flat(ic.rect(4, 82, 96, 84), darken((165, 105, 60), .3))
    ic.fill(ic.ell(28, 62, 72, 78), (70, 40, 35), stroke=2.4, shade=0, rim=0, grad=0)
    ic.fill(union(ic.rrect(39, 2, 61, 44, 3), ic.poly([(22, 38), (78, 38), (50, 72)])), SUNSET, shade=0.2)


@icon("layer")
def _layer(ic: Icon):
    x0, x1, yt, yb, dx, dy = 6, 70, 34, 96, 24, 20
    bands = [(34, SAND), (50, (235, 170, 110)), (64, (160, 100, 60)), (80, PURPLE)]

    def wave(y, xa, xb, slope=0.0, amp=2.2, ph=0.0):
        return [(xa + (xb - xa) * i / 12, y + amp * math.sin(i * 1.3 + ph) - slope * (xa + (xb - xa) * i / 12 - xa))
                for i in range(13)]

    front = ic.rect(x0, yt, x1, yb)
    side = ic.poly([(x1, yt), (x1 + dx, yt - dy), (x1 + dx, yb - dy), (x1, yb)])
    ic.fill(union(front, side), SAND, shade=0, rim=0)
    for i, (y, col) in enumerate(bands):
        ynext = bands[i + 1][0] if i + 1 < len(bands) else yb + 4
        top = wave(y, x0, x1) if i else [(x0, y), (x1, y)]
        bot = wave(ynext, x0, x1) if i + 1 < len(bands) else [(x0, ynext), (x1, ynext)]
        ic.fill(inter(front, ic.poly(top + bot[::-1])), col, stroke=1.4, shade=0.18, rim=0)
        st = [(x1, y), (x1 + dx, y - dy)]
        sb = [(x1, ynext), (x1 + dx, ynext - dy)]
        ic.fill(inter(side, ic.poly(st + sb[::-1])), darken(col, .2), stroke=1.4, shade=0, rim=0)
    ic.fill(ic.poly([(x0, yt), (x1, yt), (x1 + dx, yt - dy), (x0 + dx, yt - dy)]), lighten(SAND, .2), shade=0,
            rim=0)
    for (x, y) in ((22, 58), (48, 72), (30, 88), (56, 90)):
        ic.flat(ic.circ(x, y, 2.4), darken(SAND_D, .3), 0.5)
    ic.fill(ic.poly([(46, 84), (52, 76), (58, 84), (52, 90)]), (120, 230, 255), stroke=1.6, shade=0, rim=0)


@icon("trophy")
def _trophy(ic: Icon):
    ic.fill(ic.arc(22, 30, 13, 90, 270, 6.5), GOLD, shade=0.15)
    ic.fill(ic.arc(78, 30, 13, 270, 450, 6.5), GOLD, shade=0.15)
    cup = inter(ic.ell(16, -26, 84, 64), ic.rect(10, 10, 90, 70))
    ic.fill(cup, GOLD, shade=0.22)
    ic.fill(ic.ell(16, 6, 84, 16), darken(GOLD, .28), stroke=2.2, shade=0, rim=0)
    ic.fill(ic.rrect(43, 60, 57, 76, 2), darken(GOLD, .1), shade=0.2)
    ic.fill(ic.rrect(30, 72, 70, 82, 3), GOLD, shade=0.2)
    ic.fill(ic.rrect(22, 80, 78, 96, 4), (110, 70, 170), shade=0.2)
    ic.fill(ic.star(50, 36, 13, 5.5), lighten(GOLD, .55), stroke=2, shade=0, rim=0)
    ic.gloss(24, 20, 34, 40, 0.5)


@icon("multiplier")
def _multiplier(ic: Icon):
    ic.fill(ic.star(50, 50, 50, 41, n=14, rot=-90), SUNSET, shade=0.2)
    ic.fill(ic.circ(50, 50, 34), lighten(SUNSET, .1), stroke=1.8, shade=0, rim=0, grad=0.1)
    ic.fill(ic.text("x2", 50, 54, 42), WHITE, stroke=3, shade=0.12, rim=0, grad=0.04)


@icon("shop")
def _shop(ic: Icon):
    ic.fill(ic.rect(14, 38, 21, 64), darken(WOOD, .1), shade=0.1)
    ic.fill(ic.rect(79, 38, 86, 64), darken(WOOD, .1), shade=0.1)
    ic.fill(ic.rrect(8, 58, 92, 96, 6), WOOD, shade=0.2)
    ic.fill(ic.rrect(24, 66, 76, 88, 4), lighten(WOOD_L, .2), stroke=2.2, shade=0.15, rim=0)
    coin_face(ic, 50, 76, 8.5, sym="")
    ic.fill(ic.rrect(10, 4, 90, 18, 5), darken(CORAL, .15), shade=0.15)
    n = 6
    sw = 96 / n
    awn = union(ic.poly([(8, 14), (92, 14), (98, 38), (2, 38)]),
                *[ic.circ(2 + sw / 2 + i * sw, 38, sw / 2) for i in range(n)])
    ic.fill(awn, CORAL, shade=0.0, rim=0)
    for i in range(1, n, 2):
        band = ic.poly([(8 + i * 84 / n, 10), (8 + (i + 1) * 84 / n, 10),
                        (2 + (i + 1) * sw, 50), (2 + i * sw, 50)])
        ic.fill(inter(awn, band), WHITE, stroke=1.4, shade=0, rim=0)
    ic.flat(sub(awn, ic.rect(0, 0, 100, 36)), INK, 0.18)


@icon("beach_shop")
def _beach_shop(ic: Icon):
    ic.fill(ic.ell(14, 86, 86, 99), SAND, stroke=2.4, shade=0.15, rim=0)
    umbrella(ic, (CORAL, WHITE), cx=50, top=8, bot=48, rx=47)


@icon("eggs")
def _eggs(ic: Icon):
    egg = ic.ell(20, 4, 80, 98)
    ic.fill(egg, CREAM, shade=0.12, sk=8, shade_col=(225, 215, 200))
    egg_spots(ic, egg, ((40, 32, 9), (64, 22, 6), (66, 56, 11), (36, 70, 8), (58, 84, 7), (28, 50, 4)))
    ic.gloss(30, 14, 42, 34, 0.75)


@icon("crate")
def _crate(ic: Icon):
    W = (215, 150, 85)
    fx0, fx1, fy0, fy1, dx, dy = 6, 70, 34, 96, 24, 20
    ic.fill(ic.poly([(fx1, fy0), (fx1 + dx, fy0 - dy), (fx1 + dx, fy1 - dy), (fx1, fy1)]), darken(W, .22),
            shade=0.1, rim=0)
    ic.fill(ic.poly([(fx0, fy0), (fx1, fy0), (fx1 + dx, fy0 - dy), (fx0 + dx, fy0 - dy)]), lighten(W, .18),
            shade=0, rim=0)
    ic.fill(ic.rect(fx0, fy0, fx1, fy1), W, shade=0.15)
    ic.fill(ic.rect(fx0 + 8, fy0 + 8, fx1 - 8, fy1 - 8), lighten(W, .1), stroke=2, shade=0, rim=0)
    band = ic.rect(fx0, 56, fx1, 74)
    ic.fill(band, (255, 200, 40), stroke=2.2, shade=0, rim=0)
    for i in range(-2, 8):
        x = fx0 + i * 12
        ic.flat(inter(band, ic.poly([(x, 74), (x + 6, 74), (x + 24, 56), (x + 18, 56)])), INK)
    ic.flat(ic.poly([(fx1, 56), (fx1 + dx, 56 - dy), (fx1 + dx, 74 - dy), (fx1, 74)]), (200, 150, 30))
    for (x, y) in ((fx0 + 4, fy0 + 4), (fx1 - 4, fy0 + 4), (fx0 + 4, fy1 - 4), (fx1 - 4, fy1 - 4)):
        ic.fill(ic.circ(x, y, 2.4), STEEL, stroke=1.2, shade=0, rim=0)


@icon("pets")
def _pets(ic: Icon):
    col = (255, 125, 165)
    ic.fill(union(ic.ell(26, 50, 74, 94), ic.ell(18, 60, 52, 92), ic.ell(48, 60, 82, 92)), col, shade=0.2)
    for (x, y, rx, ry, rot) in ((15, 44, 10, 13, -25), (36, 22, 11, 14, -8), (64, 22, 11, 14, 8),
                                (85, 44, 10, 13, 25)):
        with ic.frame(rot=rot, rc=(x, y)):
            ic.fill(ic.ell(x - rx, y - ry, x + rx, y + ry), col, shade=0.22)
    ic.gloss(34, 56, 46, 64, 0.5)


@icon("index")
def _index(ic: Icon):
    ic.fill(ic.rrect(18, 10, 88, 96, 6), darken(OCEAN_D, .25), shade=0.1)
    ic.fill(ic.rrect(20, 12, 84, 90, 3), CREAM, stroke=2, shade=0.1, rim=0)
    for y in (78, 82, 86):
        ic.flat(ic.rect(70, y, 84, y + 0.8), SAND_D)
    ic.fill(ic.rrect(10, 6, 76, 86, 6), OCEAN_D, shade=0.18)
    ic.fill(ic.rrect(10, 6, 22, 86, 4), darken(OCEAN_D, .2), stroke=1.8, shade=0, rim=0)
    ic.fill(ic.star(49, 42, 18, 8), GOLD, stroke=2.4, shade=0.18, rim=0)
    ic.fill(ic.poly([(58, 84), (68, 84), (68, 100), (63, 95), (58, 100)]), RED, stroke=2.2, shade=0, rim=0)


@icon("quests")
def _quests(ic: Icon):
    P = (250, 228, 175)
    ic.fill(ic.rect(20, 14, 80, 86), P, shade=0.1)
    for i, y in enumerate((32, 46, 60)):
        ic.fill(ic.line([(40, y), (70 - i * 6, y)], 4), SAND_D, stroke=0, shade=0, rim=0)
        ic.fill(ic.line([(27, y), (30, y + 3), (35, y - 3)], 3), GREEN if i < 2 else SAND_D, stroke=1.2,
                shade=0, rim=0)
    for y0 in (6, 78):
        ic.fill(ic.rrect(12, y0, 88, y0 + 16, 8), darken(P, .12), shade=0.22)
        ic.fill(ic.ell(80, y0, 92, y0 + 16), darken(P, .3), stroke=2, shade=0, rim=0)
    ic.fill(ic.circ(70, 72, 9), RED, stroke=2.4, shade=0.2, rim=0)


@icon("daily")
def _daily(ic: Icon):
    body = ic.rrect(8, 14, 92, 96, 12)
    ic.fill(body, WHITE, shade=0.14, shade_col=(215, 220, 235))
    ic.fill(inter(body, ic.rect(0, 0, 100, 36)), RED, stroke=2.4, shade=0, rim=0.3)
    for x in (28, 72):
        ic.fill(ic.rrect(x - 4.5, 4, x + 4.5, 26, 4.5), STEEL, stroke=2.4, shade=0.2, rim=0)
    cx, cy = 50, 66
    for i in range(8):
        t = math.radians(i * 45)
        tip = (cx + 25 * math.cos(t), cy + 25 * math.sin(t))
        l = (cx + 15 * math.cos(t - .35), cy + 15 * math.sin(t - .35))
        r = (cx + 15 * math.cos(t + .35), cy + 15 * math.sin(t + .35))
        ic.fill(ic.poly([l, tip, r]), SUNSET, stroke=1.6, shade=0, rim=0)
    ic.fill(ic.circ(cx, cy, 14), GOLD, stroke=2.4, shade=0.18, rim=0)


@icon("gift")
def _gift(ic: Icon):
    B, R = CORAL, GOLD
    fx0, fx1, fy0, fy1, dx, dy = 10, 66, 48, 96, 24, 14
    ic.fill(ic.poly([(fx1, fy0), (fx1 + dx, fy0 - dy), (fx1 + dx, fy1 - dy), (fx1, fy1)]), darken(B, .25),
            shade=0, rim=0)
    ic.fill(ic.rect(fx0, fy0, fx1, fy1), B, shade=0.15)
    ic.fill(ic.rect(32, fy0, 44, fy1), R, stroke=1.8, shade=0.15, rim=0)
    ic.fill(ic.poly([(fx1, 62), (fx1 + dx, 62 - dy), (fx1 + dx, 72 - dy), (fx1, 72)]), darken(R, .2), stroke=1.6,
            shade=0, rim=0)
    # lid
    lx0, lx1, ly0, ly1 = 6, 70, 36, 50
    ic.fill(ic.poly([(lx1, ly0), (lx1 + dx, ly0 - dy), (lx1 + dx, ly1 - dy), (lx1, ly1)]), darken(B, .18),
            shade=0, rim=0)
    ic.fill(ic.poly([(lx0, ly0), (lx1, ly0), (lx1 + dx, ly0 - dy), (lx0 + dx, ly0 - dy)]), lighten(B, .2),
            shade=0, rim=0)
    ic.fill(ic.rect(lx0, ly0, lx1, ly1), B, shade=0.15)
    ic.fill(ic.rect(32, ly0, 44, ly1), R, stroke=1.8, shade=0, rim=0)
    ic.fill(ic.poly([(32, ly0), (44, ly0), (44 + dx, ly0 - dy), (32 + dx, ly0 - dy)]), lighten(R, .2), stroke=1.6,
            shade=0, rim=0)
    # bow
    bx, by = 50, 28
    with ic.frame(rot=-28, rc=(bx, by)):
        ic.fill(ic.ell(bx - 30, by - 13, bx - 2, by + 9), R, shade=0.2)
    with ic.frame(rot=28, rc=(bx, by)):
        ic.fill(ic.ell(bx + 2, by - 13, bx + 30, by + 9), R, shade=0.2)
    ic.fill(ic.circ(bx, by + 1, 7), darken(R, .1), shade=0.2, rim=0)


@icon("rebirth")
def _rebirth(ic: Icon):
    col = TOKEN
    cx, cy, r, w = 50, 50, 33, 15
    for a0 in (200, 20):
        a1 = a0 + 125
        t = math.radians(a1)
        hx, hy = cx + r * math.cos(t), cy + r * math.sin(t)
        tx, ty = -math.sin(t), math.cos(t)
        nx, ny = math.cos(t), math.sin(t)
        head = ic.poly([(hx + nx * 17, hy + ny * 17), (hx + tx * 22, hy + ty * 22), (hx - nx * 17, hy - ny * 17)])
        ic.fill(union(ic.arc(cx, cy, r, a0, a1, w), head), col, shade=0.22)


@icon("store")
def _store(ic: Icon):
    ic.fill(ic.arc(50, 30, 15, 180, 360, 5.5), GOLD, shade=0, rim=0)
    ic.fill(ic.poly([(16, 30), (84, 30), (92, 96), (8, 96)]), PURPLE, shade=0.22)
    ic.fill(ic.poly([(16, 30), (84, 30), (85.5, 41), (14.5, 41)]), darken(PURPLE, .18), stroke=2, shade=0, rim=0)
    ic.fill(ic.star(50, 68, 24, 11), GOLD, stroke=2.8, shade=0.2, rim=0.4)
    ic.sparkle(86, 14, 10, GOLD)


@icon("settings")
def _settings(ic: Icon):
    gear(ic, 50, 50, 48, (185, 195, 215))


@icon("surface")
def _surface(ic: Icon):
    ic.fill(ic.ell(8, 70, 92, 98), SAND, shade=0.15)
    ic.fill(ic.ell(20, 75, 80, 93), (70, 40, 35), stroke=2.2, shade=0, rim=0, grad=0)
    ic.fill(arrow_up_mask(ic, 50, 2, 86, w=22, hw=58, hh=34), GREEN, shade=0.2)
    for (x, y, r) in ((14, 56, 4), (86, 52, 3.5), (22, 40, 3)):
        ic.fill(ic.circ(x, y, r), SAND, stroke=2, shade=0, rim=0)


@icon("sell")
def _sell(ic: Icon):
    S = (225, 180, 110)
    ic.fill(ic.poly([(34, 6), (50, 16), (66, 6), (64, 28), (36, 28)]), S, shade=0.15)
    ic.fill(union(ic.ell(10, 32, 90, 98), ic.poly([(36, 26), (64, 26), (72, 44), (28, 44)])), S, shade=0.2)
    ic.fill(ic.rrect(32, 24, 68, 33, 4), darken(S, .35), stroke=2.2, shade=0, rim=0)
    coin_face(ic, 50, 66, 18)


@icon("auto")
def _auto(ic: Icon):
    gear(ic, 38, 38, 37, OCEAN)
    sc = 0.66
    with ic.frame(sc=sc, ox=62 - 50 * sc, oy=60 - 52 * sc, rot=45, rc=(62, 60)):
        shovel_parts(ic)


@icon("ride")
def _ride(ic: Icon):
    Y = (255, 200, 40)
    ic.fill(ic.line([(46, 58), (70, 16)], 11), Y, shade=0.15)
    ic.fill(ic.line([(70, 16), (88, 50)], 9), darken(Y, .05), shade=0.15)
    ic.fill(ic.poly([(78, 50), (97, 46), (99, 66), (88, 74), (76, 62)]), (150, 160, 180), shade=0.2)
    ic.fill(ic.rrect(2, 74, 70, 98, 12), (75, 75, 92), shade=0.15)
    for x in (13, 36, 59):
        ic.fill(ic.circ(x, 86, 6.5), (170, 175, 190), stroke=2, shade=0, rim=0)
    ic.fill(ic.rrect(4, 50, 64, 78, 5), Y, shade=0.2)
    ic.fill(ic.rrect(8, 22, 42, 56, 5), Y, shade=0.15)
    ic.fill(ic.rrect(13, 27, 37, 46, 3), SKY, stroke=2.2, shade=0, rim=0)
    ic.flat(ic.poly([(16, 29), (24, 29), (17, 44), (14, 44)]), WHITE, 0.7)
    ic.fill(ic.rect(46, 60, 58, 66), INK, stroke=0, shade=0, rim=0)


@icon("place_shade")
def _place_shade(ic: Icon):
    with ic.frame(sc=0.86, ox=0, oy=6):
        ic.fill(ic.ell(14, 86, 86, 99), SAND, stroke=2.4, shade=0.15, rim=0)
        umbrella(ic, (OCEAN, WHITE), cx=50, top=8, bot=48, rx=47)
    ic.fill(ic.circ(78, 78, 18), GREEN, shade=0.2)
    ic.fill(union(ic.rrect(74.5, 67, 81.5, 89, 2), ic.rrect(67, 74.5, 89, 81.5, 2)), WHITE, stroke=2, shade=0.1,
            rim=0)


@icon("heat")
def _heat(ic: Icon):
    ic.fill(ic.rrect(26, 4, 52, 72, 13), (245, 248, 255), shade=0.1, shade_col=(210, 215, 235))
    ic.fill(ic.circ(39, 76, 19), RED, shade=0.2)
    ic.fill(ic.rrect(34, 24, 44, 74, 5), RED, stroke=0, shade=0, rim=0)
    for y in (16, 26, 36, 46):
        ic.flat(ic.rect(28.5, y, 33, y + 1.6), INK)
    ic.gloss(30, 64, 38, 72, 0.6)
    for i, x in enumerate((64, 78, 92)):
        pts = [(x + 4 * math.sin(j * 0.9), 18 + j * 4.5 + i * 2) for j in range(11)]
        ic.fill(ic.line(pts, 5.5), SUNSET, stroke=2.2, shade=0, rim=0)


@icon("sun")
def _sun(ic: Icon):
    cx, cy = 50, 50
    for i in range(10):
        t = math.radians(i * 36 - 90)
        tip = (cx + 49 * math.cos(t), cy + 49 * math.sin(t))
        l = (cx + 30 * math.cos(t - .26), cy + 30 * math.sin(t - .26))
        r = (cx + 30 * math.cos(t + .26), cy + 30 * math.sin(t + .26))
        ic.fill(ic.poly([l, tip, r]), SUNSET, stroke=2.4, shade=0.15, rim=0)
    ic.fill(ic.circ(cx, cy, 31), (255, 215, 50), shade=0.15)
    ic.gloss(30, 30, 46, 42, 0.55)


@icon("shade")
def _shade(ic: Icon):
    ic.fill(ic.ell(2, 68, 98, 99), SAND, shade=0.12)
    ic.fill(ic.ell(40, 74, 94, 94), darken(SAND, .32), stroke=0, shade=0, rim=0, grad=0)
    with ic.frame(sc=0.8, ox=2, oy=4, rot=-14, rc=(40, 40)):
        umbrella(ic, (OCEAN, WHITE), cx=50, top=8, bot=46, rx=47)


@icon("water")
def _water(ic: Icon):
    ic.fill(ic.rrect(40, 14, 60, 28, 3), GLASS, shade=0)
    body = ic.rrect(24, 22, 76, 98, 16)
    ic.fill(body, GLASS, shade=0)
    wave = [(24 + i * 52 / 10, 44 + 2.5 * math.sin(i * 1.1)) for i in range(11)]
    ic.fill(inter(body, ic.poly(wave + [(80, 100), (20, 100)])), OCEAN, stroke=1.6, shade=0.2, rim=0.3)
    ic.fill(inter(body, ic.rect(20, 58, 80, 76)), WHITE, stroke=1.6, shade=0, rim=0, grad=0.05)
    ic.fill(union(ic.circ(50, 69.5, 5), ic.poly([(45.4, 67.5), (50, 59.5), (54.6, 67.5)])), OCEAN_D, stroke=0,
            shade=0, rim=0)
    ic.fill(ic.rrect(36, 2, 64, 16, 4), OCEAN_D, shade=0.2)
    ic.flat(ic.rrect(30, 28, 36, 54, 3), WHITE, 0.75)


@icon("lemonade")
def _lemonade(ic: Icon):
    ic.fill(ic.line([(46, 60), (56, 6), (68, 2)], 6), CORAL, stroke=2.2, shade=0, rim=0)
    glass = ic.poly([(16, 22), (80, 22), (72, 98), (24, 98)])
    ic.fill(glass, GLASS, shade=0, rim=0)
    ic.fill(inter(glass, ic.rect(0, 34, 100, 100)), (255, 225, 70), stroke=1.6, shade=0.15, rim=0.4)
    for (x, y, rot) in ((36, 50, 15), (56, 58, -10)):
        with ic.frame(rot=rot, rc=(x, y)):
            ic.flat(ic.rrect(x - 7, y - 7, x + 7, y + 7, 3), WHITE, 0.6)
    ic.flat(ic.poly([(23, 30), (28, 30), (32, 90), (28, 90)]), WHITE, 0.6)
    ic.fill(ic.circ(80, 22, 16), (255, 215, 40), shade=0, rim=0)
    ic.fill(ic.circ(80, 22, 11.5), (255, 245, 170), stroke=1.6, ink=(230, 190, 40), shade=0, rim=0)
    for i in range(6):
        t = math.radians(i * 60)
        ic.flat(ic.line([(80, 22), (80 + 10 * math.cos(t), 22 + 10 * math.sin(t))], 1.2), (240, 200, 60))


@icon("coconut")
def _coconut(ic: Icon):
    B = (145, 90, 50)
    ic.fill(ic.circ(50, 60, 38), B, shade=0.25)
    for (x, y, a) in ((24, 66, 30), (36, 84, -10), (70, 80, 20), (78, 60, -30), (52, 90, 0)):
        t = math.radians(a)
        ic.flat(ic.line([(x, y), (x + 6 * math.cos(t), y + 6 * math.sin(t))], 1.6), darken(B, .35))
    ic.fill(ic.ell(20, 30, 80, 48), CREAM, stroke=2.6, shade=0, rim=0)
    ic.fill(ic.ell(28, 33.5, 72, 45), (240, 236, 220), stroke=0, shade=0, rim=0, grad=0)
    ic.fill(ic.line([(54, 40), (64, 8), (80, 4)], 6), CORAL, stroke=2.4, shade=0, rim=0)
    with ic.frame(rot=-20, rc=(30, 28)):
        ic.fill(ic.ell(16, 20, 40, 34), PALM, stroke=2.4, shade=0.2, rim=0)
    ic.fill(ic.circ(30, 24, 6), CORAL, stroke=2, shade=0, rim=0)


@icon("popsicle")
def _popsicle(ic: Icon):
    ic.fill(ic.rrect(43, 66, 57, 98, 7), WOOD_L, shade=0.2)
    pop = sub(ic.rrect(22, 4, 78, 76, 24), ic.circ(78, 8, 9), ic.circ(70, 2, 6))
    ic.fill(pop, CORAL, shade=0, rim=0.3)
    wave1 = [(20 + i * 6, 30 + 3 * math.sin(i * 1.2)) for i in range(11)]
    wave2 = [(20 + i * 6, 52 + 3 * math.sin(i * 1.2 + 1)) for i in range(11)]
    ic.fill(inter(pop, ic.poly(wave1 + wave2[::-1])), SUNSET, stroke=1.6, shade=0, rim=0)
    ic.fill(inter(pop, ic.poly(wave2 + [(80, 80), (20, 80)])), (255, 215, 50), stroke=1.6, shade=0.25, rim=0)
    ic.flat(ic.rrect(29, 12, 35, 44, 3), WHITE, 0.6)


@icon("shaved_ice")
def _shaved_ice(ic: Icon):
    dome = union(inter(ic.ell(14, 4, 86, 74), ic.rect(0, 0, 100, 56)),
                 *[ic.circ(18 + i * 12.8, 54, 6.4) for i in range(6)])
    ic.fill(dome, WHITE, shade=0, rim=0)
    cols = [(255, 110, 165), (255, 225, 80), (70, 195, 255)]
    for i, c in enumerate(cols):
        x0 = 8 + i * 28
        band = ic.poly([(x0 + 8, 0), (x0 + 36, 0), (x0 + 28, 64), (x0, 64)])
        ic.fill(inter(dome, band), c, stroke=1.4, shade=0.15, rim=0.4)
    cup = ic.poly([(20, 54), (80, 54), (70, 98), (30, 98)])
    ic.fill(cup, WHITE, shade=0.15, shade_col=(210, 215, 235))
    for i in range(3):
        x = 32 + i * 14
        ic.fill(inter(cup, ic.poly([(x, 50), (x + 7, 50), (x + 5, 100), (x - 2, 100)])), OCEAN, stroke=0,
                shade=0, rim=0)
    ic.fill(ic.line([(60, 26), (74, 4)], 4.5), RED, stroke=2, shade=0, rim=0)


@icon("watermelon_slice")
def _watermelon_slice(ic: Icon):
    with ic.frame(rot=-12, rc=(50, 50)):
        cx, cy = 50, 4
        ic.fill(ic.pie(cx, cy, 90, 55, 125), (60, 175, 80), shade=0, rim=0)
        ic.fill(ic.pie(cx, cy, 83, 55, 125), (225, 250, 210), stroke=0, shade=0, rim=0)
        ic.fill(ic.pie(cx, cy, 78, 57, 123), (255, 80, 100), stroke=1.6, shade=0.15, rim=0.35)
        for (r, a) in ((40, 80), (40, 100), (58, 70), (58, 90), (58, 110), (30, 90)):
            t = math.radians(a)
            x, y = cx + r * math.cos(t), cy + r * math.sin(t)
            with ic.frame(rot=a - 90 - 12, rc=(x, y)):
                ic.flat(ic.ell(x - 2.4, y - 3.8, x + 2.4, y + 3.8), INK)


@icon("giant_watermelon")
def _giant_watermelon(ic: Icon):
    G = (90, 200, 90)
    body = ic.ell(4, 12, 96, 94)
    ic.fill(body, G, shade=0.22)
    for i in range(5):
        x = 16 + i * 17
        pts_l, pts_r = [], []
        for j in range(13):
            y = 10 + j * 7.2
            off = 3.5 * (1 if j % 2 else -1)
            pts_l.append((x + off - 3.5, y))
            pts_r.append((x + off + 3.5, y))
        ic.flat(inter(body, ic.poly(pts_l + pts_r[::-1])), darken(G, .4))
    ic.fill(ic.line([(50, 14), (56, 2)], 5), WOOD, stroke=2.2, shade=0, rim=0)
    ic.gloss(20, 22, 40, 34, 0.5)
    ic.sparkle(88, 12, 9, GOLD)


@icon("boost_sand")
def _boost_sand(ic: Icon):
    with ic.frame(sc=0.8, ox=2, oy=0):
        sand_bucket(ic)
    x2_pill(ic, 70, 80)


@icon("boost_luck")
def _boost_luck(ic: Icon):
    G = (60, 200, 90)
    ic.fill(ic.line([(50, 50), (56, 76), (68, 96)], 6), darken(G, .1), shade=0, rim=0)
    for rot in (0, 90, 180, 270):
        with ic.frame(rot=rot, rc=(50, 48)):
            leaf = union(ic.circ(40, 22, 13), ic.circ(60, 22, 13), ic.poly([(28.5, 28), (71.5, 28), (50, 50)]))
            ic.fill(leaf, G, shade=0.2)
    ic.fill(ic.circ(50, 48, 6), lighten(G, .25), stroke=2, shade=0, rim=0)


@icon("boost_speed")
def _boost_speed(ic: Icon):
    ic.fill(ic.poly([(60, 2), (20, 56), (46, 56), (36, 98), (82, 38), (55, 38), (70, 2)]), (255, 215, 50),
            shade=0.22)
    ic.flat(ic.poly([(60, 8), (28, 52), (36, 52), (62, 12)]), WHITE, 0.55)


@icon("boost_coins")
def _boost_coins(ic: Icon):
    coin_face(ic, 40, 38, 34)
    x2_pill(ic, 70, 80)


@icon("golden_hour")
def _golden_hour(ic: Icon):
    cx, cy = 50, 58
    for i in range(7):
        t = math.radians(180 + 15 + i * 25)
        tip = (cx + 50 * math.cos(t), cy + 50 * math.sin(t))
        l = (cx + 30 * math.cos(t - .16), cy + 30 * math.sin(t - .16))
        r = (cx + 30 * math.cos(t + .16), cy + 30 * math.sin(t + .16))
        ic.fill(ic.poly([l, tip, r]), GOLD, stroke=2.2, shade=0.1, rim=0)
    ic.fill(inter(ic.circ(cx, cy, 33), ic.rect(0, 0, 100, cy)), SUNSET, shade=0, rim=0.35, grad=0.25)
    wave = [(4 + i * 92 / 12, 58 + 2.5 * math.sin(i * 1.4)) for i in range(13)]
    ic.fill(union(ic.poly(wave + [(96, 80), (4, 80)]), ic.rrect(4, 66, 96, 94, 12)), (40, 140, 225), shade=0.2,
            rim=0)
    for (x0, x1, y, c) in ((32, 68, 68, GOLD), (38, 62, 77, GOLD), (44, 56, 86, GOLD), (12, 22, 74, WHITE),
                           (78, 88, 82, WHITE)):
        ic.flat(ic.line([(x0, y), (x1, y)], 3.2), c)


@icon("high_tide")
def _high_tide(ic: Icon):
    W = (40, 165, 240)
    hole = ic.circ(60, 52, 21)
    mouth = union(ic.rect(60, 52, 100, 74), ic.circ(86, 74, 12))
    ic.fill(inter(union(hole, ic.rect(40, 52, 100, 74)), ic.circ(46, 46, 44)), darken(W, .38), shade=0, rim=0, grad=0.25)
    crest = sub(union(ic.circ(46, 46, 44), ic.rrect(2, 72, 98, 98, 12)), hole, mouth)
    ic.fill(crest, W, shade=0.2, rim=0)
    foam = union(*[ic.circ(46 + 39 * math.cos(math.radians(a)), 46 + 39 * math.sin(math.radians(a)), 8)
                   for a in range(-176, 10, 22)])
    ic.fill(inter(foam, ic.circ(46, 46, 47)), WHITE, stroke=2, shade=0.12, rim=0)
    for (x, y) in ((14, 86), (36, 91), (62, 89), (84, 86)):
        ic.flat(ic.line([(x - 5, y), (x + 5, y)], 3), WHITE, 0.8)


@icon("treasure")
def _treasure(ic: Icon):
    Wd = (175, 105, 50)
    ic.fill(ic.poly([(12, 14), (88, 14), (92, 44), (8, 44)]), darken(Wd, .15), shade=0, rim=0)
    ic.fill(ic.poly([(18, 20), (82, 20), (84, 30), (16, 30)]), GOLD, stroke=1.4, shade=0, rim=0)
    for (x, y, r) in ((26, 44, 11), (74, 44, 11), (40, 40, 12), (60, 40, 12), (50, 44, 11)):
        ic.fill(ic.circ(x, y, r), GOLD, stroke=2, shade=0.18, rim=0)
    ic.fill(ic.poly([(50, 16), (62, 30), (50, 44), (38, 30)]), (90, 220, 255), stroke=2.2, shade=0.2, rim=0)
    ic.fill(ic.rrect(6, 44, 94, 96, 6), Wd, shade=0.2)
    ic.fill(ic.rrect(6, 44, 94, 56, 4), darken(Wd, .2), stroke=1.8, shade=0, rim=0)
    for y in (70, 84):
        ic.flat(ic.rect(20, y, 80, y + 1.6), darken(Wd, .3))
    for x in (6, 80):
        ic.fill(ic.rrect(x, 44, x + 14, 96, 3), GOLD, stroke=2, shade=0.2, rim=0)
    ic.fill(ic.rrect(41, 52, 59, 74, 4), GOLD, stroke=2.2, shade=0.2, rim=0)
    ic.flat(ic.circ(50, 61, 3.4), INK)
    ic.flat(ic.rect(48.8, 61, 51.2, 68), INK)


@icon("egg_hatch")
def _egg_hatch(ic: Icon):
    zig = [(10 + i * 8, 56 + (6 if i % 2 else 0)) for i in range(11)]
    egg = ic.ell(16, 18, 84, 98)
    ic.fill(ic.ell(22, 48, 78, 66), (255, 220, 120), stroke=2, shade=0, rim=0)
    bottom = inter(egg, ic.poly(zig + [(100, 100), (0, 100)]))
    ic.fill(bottom, CREAM, shade=0.12, sk=8, shade_col=(225, 215, 200))
    egg_spots(ic, bottom, ((32, 78, 7), (60, 86, 8), (68, 68, 5)), PURPLE)
    with ic.frame(ox=-2, oy=-10, rot=-20, rc=(46, 40)):
        top = inter(ic.ell(16, 18, 84, 98), ic.poly(zig + [(100, 0), (0, 0)]))
        ic.fill(top, CREAM, shade=0.1, shade_col=(225, 215, 200))
        egg_spots(ic, top, ((40, 36, 8), (64, 44, 5)), PURPLE)
    ic.sparkle(10, 50, 8, GOLD)
    ic.sparkle(90, 44, 8, GOLD)


@icon("lock")
def _lock(ic: Icon):
    sh = union(ic.arc(50, 38, 21, 180, 360, 10, caps=False), ic.rect(24, 37, 34, 52), ic.rect(66, 37, 76, 52))
    ic.fill(sh, (170, 180, 200), shade=0.15)
    ic.fill(ic.rrect(12, 44, 88, 96, 12), GOLD, shade=0.22)
    ic.fill(union(ic.circ(50, 64, 7.5), ic.poly([(45, 66), (55, 66), (57, 84), (43, 84)])), (90, 55, 20),
            stroke=0, shade=0, rim=0, grad=0)
    ic.gloss(18, 50, 30, 60, 0.5)


@icon("check")
def _check(ic: Icon):
    ic.fill(ic.line([(12, 54), (38, 80), (88, 20)], 20), GREEN, shade=0.2)


@icon("close")
def _close(ic: Icon):
    ic.fill(union(ic.line([(16, 16), (84, 84)], 21), ic.line([(84, 16), (16, 84)], 21)), RED, shade=0.2)


def _arrow_right_mask(ic: Icon):
    return union(ic.rrect(6, 36, 56, 64, 4), ic.poly([(46, 10), (94, 50), (46, 90)]))


@icon("arrow_right")
def _arrow_right(ic: Icon):
    ic.fill(_arrow_right_mask(ic), WHITE, shade=0.14, shade_col=(200, 205, 225))


@icon("arrow_down")
def _arrow_down(ic: Icon):
    with ic.frame(rot=90, rc=(50, 50)):
        m = _arrow_right_mask(ic)
    ic.fill(m, WHITE, shade=0.14, shade_col=(200, 205, 225))


@icon("star")
def _star(ic: Icon):
    ic.fill(ic.star(50, 54, 52, 24), GOLD, shade=0.22)
    ic.gloss(36, 30, 48, 44, 0.55)


@icon("notify")
def _notify(ic: Icon):
    ic.fill(ic.circ(50, 50, 46), RED, shade=0.2)
    ic.fill(union(ic.rrect(43, 16, 57, 62, 6), ic.circ(50, 76, 8)), WHITE, stroke=2.4, shade=0.1, rim=0)


@icon("music")
def _music(ic: Icon):
    notes = union(
        ic.rrect(30, 20, 38, 78, 2), ic.rrect(80, 10, 88, 68, 2),
        ic.poly([(30, 18), (88, 6), (88, 22), (30, 34)]))
    for (x, y) in ((22, 80), (72, 70)):
        with ic.frame(rot=-22, rc=(x, y)):
            notes = union(notes, ic.ell(x - 15, y - 11, x + 15, y + 11))
    ic.fill(notes, PURPLE, shade=0.2)


@icon("sfx")
def _sfx(ic: Icon):
    ic.fill(ic.poly([(6, 34), (24, 34), (50, 10), (50, 90), (24, 66), (6, 66)]), (95, 120, 255), shade=0.2)
    ic.fill(ic.rrect(6, 34, 24, 66, 3), darken((95, 120, 255), .2), stroke=2, shade=0, rim=0)
    ic.fill(ic.arc(50, 50, 20, -50, 50, 8), OCEAN, shade=0, rim=0)
    ic.fill(ic.arc(50, 50, 38, -50, 50, 8), OCEAN, shade=0, rim=0)


@icon("codes")
def _codes(ic: Icon):
    with ic.frame(rot=-14, rc=(50, 50)):
        t = sub(ic.rrect(4, 24, 96, 76, 7), ic.circ(4, 50, 10), ic.circ(96, 50, 10))
        ic.fill(t, (255, 175, 50), shade=0.2)
        for y in range(28, 74, 9):
            ic.flat(ic.rect(68, y, 70.5, y + 5), darken((255, 175, 50), .35))
        ic.fill(ic.star(38, 51, 16, 7), CORAL, stroke=2.4, shade=0.15, rim=0)
        ic.fill(ic.star(82, 51, 7, 3), WHITE, stroke=1.8, shade=0, rim=0)


@icon("info")
def _info(ic: Icon):
    ic.fill(ic.circ(50, 50, 46), OCEAN, shade=0.2)
    ic.fill(union(ic.circ(50, 25, 8), ic.rrect(43, 38, 57, 80, 5)), WHITE, stroke=2.4, shade=0.1, rim=0)


@icon("power")
def _power(ic: Icon):
    with ic.frame(rot=-25, rc=(50, 50)):
        ic.fill(ic.rrect(10, 45, 90, 55, 4), STEEL, shade=0.2)
        for x0 in (2, 84):
            ic.fill(ic.rrect(x0, 32, x0 + 14, 68, 5), darken(CORAL, .1), shade=0.2)
        for x0 in (14, 70):
            ic.fill(ic.rrect(x0, 20, x0 + 16, 80, 6), CORAL, shade=0.22)


@icon("radius")
def _radius(ic: Icon):
    with ic.frame(rot=-35, rc=(50, 50)):
        body = ic.rrect(-6, 34, 106, 66, 5)
        ic.fill(body, (255, 210, 60), shade=0.22)
        for i, x in enumerate(range(6, 100, 8)):
            h = 14 if i % 2 == 0 else 8
            ic.flat(ic.rect(x - 1, 34, x + 1, 34 + h), darken((255, 210, 60), .45))
        ic.fill(ic.circ(88, 56, 4), (255, 245, 200), stroke=1.8, shade=0, rim=0)


@icon("hand")
def _hand(ic: Icon):
    for (x0, y0, x1, y1) in ((26, 14, 18, 8), (60, 14, 68, 8), (22, 28, 13, 28)):
        ic.fill(ic.line([(x0, y0), (x1, y1)], 4), WHITE, stroke=2, shade=0, rim=0)
    ic.fill(ic.rrect(28, 84, 82, 99, 4), OCEAN, shade=0.2)
    ic.fill(ic.rrect(34, 6, 52, 64, 9), SKIN, shade=0.1)
    ic.fill(ic.rrect(26, 42, 84, 90, 16), SKIN, shade=0.2)
    for x in (52, 62, 72):
        ic.fill(ic.rrect(x - 1, 40, x + 11, 62, 6), SKIN, stroke=2.2, shade=0.12, rim=0)
    with ic.frame(rot=-25, rc=(36, 66)):
        ic.fill(ic.rrect(20, 60, 56, 74, 7), SKIN, stroke=2.4, shade=0.15, rim=0)
    ic.gloss(37, 12, 43, 30, 0.5)


@icon("gem")
def _gem(ic: Icon):
    col = (90, 210, 255)
    top = [(4, 36), (26, 10), (74, 10), (96, 36)]
    gem = ic.poly(top + [(50, 96)])
    ic.fill(gem, col, shade=0, rim=0)
    ic.fill(ic.poly([(4, 36), (96, 36), (50, 96)]), darken(col, .12), stroke=1.4, shade=0, rim=0)
    ic.fill(ic.poly([(30, 36), (70, 36), (50, 96)]), lighten(col, .25), stroke=1.4, shade=0, rim=0)
    ic.fill(ic.poly([(26, 10), (40, 36), (60, 36), (74, 10)]), lighten(col, .45), stroke=1.4, shade=0, rim=0)
    ic.fill(ic.poly([(4, 36), (26, 10), (40, 36)]), lighten(col, .2), stroke=1.4, shade=0, rim=0)
    ic.fill(ic.poly([(96, 36), (74, 10), (60, 36)]), col, stroke=1.4, shade=0, rim=0)
    ic.flat(ic.poly([(34, 14), (44, 14), (38, 30)]), WHITE, 0.8)
    ic.sparkle(86, 82, 9)


@icon("shell")
def _shell(ic: Icon):
    col = (255, 150, 140)
    cx, cy, r = 50, 76, 49
    fan = union(ic.pie(cx, cy, r, 195, 345),
                *[ic.circ(cx + (r - 2) * math.cos(math.radians(a)), cy + (r - 2) * math.sin(math.radians(a)), 8)
                  for a in range(200, 345, 18)])
    ic.fill(ic.poly([(34, 74), (66, 74), (74, 94), (26, 94)]), darken(col, .1), shade=0.2)
    ic.fill(fan, col, shade=0.18)
    for a in range(206, 340, 18):
        t = math.radians(a)
        ic.flat(ic.line([(cx + 12 * math.cos(t), cy + 12 * math.sin(t)),
                         (cx + (r - 8) * math.cos(t), cy + (r - 8) * math.sin(t))], 2.4), darken(col, .3))
    ic.gloss(30, 40, 40, 50, 0.5)


@icon("crab")
def _crab(ic: Icon):
    col = (255, 90, 65)
    for side in (-1, 1):
        for i, y in enumerate((70, 78, 86)):
            x0 = 50 + side * 26
            ic.fill(ic.line([(x0, y - 4), (x0 + side * 14, y + 2), (x0 + side * 18, y + 10)], 4.5),
                    darken(col, .15), stroke=2, shade=0, rim=0)
        ic.fill(ic.line([(50 + side * 26, 60), (50 + side * 38, 40)], 6), darken(col, .1), stroke=2.4, shade=0,
                rim=0)
        cx = 50 + side * 37
        claw = sub(ic.circ(cx, 28, 14), ic.poly([(cx, 28), (cx + side * 2, 8), (cx + side * 18, 14)]))
        ic.fill(claw, col, shade=0.2)
        ic.fill(ic.line([(50 + side * 12, 50), (50 + side * 14, 34)], 4), darken(col, .1), stroke=2, shade=0,
                rim=0)
    ic.fill(ic.ell(18, 44, 82, 88), col, shade=0.22)
    for side in (-1, 1):
        x = 50 + side * 14
        ic.fill(ic.circ(x, 32, 8.5), WHITE, stroke=2.4, shade=0, rim=0)
        ic.flat(ic.circ(x + 1, 33, 4.5), INK)
        ic.flat(ic.circ(x - 0.5, 31, 1.8), WHITE)
    ic.fill(ic.arc(50, 64, 8, 20, 160, 3), INK, stroke=0, shade=0, rim=0)
    ic.gloss(30, 50, 44, 58, 0.45)


@icon("hourglass")
def _hourglass(ic: Icon):
    glass = ic.poly([(24, 12), (76, 12), (76, 18), (55, 50), (76, 82), (76, 88), (24, 88), (24, 82), (45, 50),
                     (24, 18)])
    ic.fill(glass, GLASS, shade=0, rim=0)
    ic.fill(inter(glass, ic.poly([(20, 30), (80, 30), (80, 52), (20, 52)])), SAND, stroke=1.4, shade=0.15, rim=0)
    ic.fill(inter(glass, ic.ell(20, 66, 80, 104)), SAND, stroke=1.4, shade=0.15, rim=0)
    ic.flat(ic.rect(49, 50, 51, 74), SAND_D)
    for x in (18, 76):
        ic.fill(ic.rrect(x, 8, x + 6, 92, 3), WOOD, shade=0.15)
    for y in (2, 86):
        ic.fill(ic.rrect(12, y, 88, y + 12, 5), WOOD, shade=0.2)


# ================================================================= aliases for src/client/UI/Icons.luau
ALIASES = {
    "Coins": "coins", "Tokens": "tokens", "Rebirth": "rebirth", "Sand": "sand", "Backpack": "backpack",
    "Depth": "depth", "Shop": "shop", "Eggs": "eggs", "Pets": "pets", "Index": "index", "Quests": "quests",
    "Daily": "daily", "Store": "store", "Settings": "settings", "Beach": "beach_shop", "Garage": "ride",
    "Dig": "pickaxe", "Ride": "ride", "Crate": "crate", "Surface": "surface", "Sell": "sell", "AutoDig": "auto",
    "Lock": "lock", "Check": "check", "Close": "close", "Star": "star", "Robux": "store", "Power": "power",
    "Speed": "boost_speed", "Radius": "radius", "Multiplier": "multiplier", "Hand": "hand", "Arrow": "arrow_down",
}
# group tables in Icons.luau -> {Default = name, <key> = name overrides}
GROUPS = {
    "Layers": {"Default": "layer", "crystal_caverns": "gem", "shell_bed": "shell", "tidal_clay": "crab",
               "shipwreck": "treasure", "the_core": "sun", "dry_sand": "sand", "wet_sand": "high_tide"},
    "PetShapes": {"Default": "pets", "Crab": "crab", "Star": "star"},
    "VehicleKinds": {"Default": "ride", "MiningDrill": "pickaxe", "Mole": "auto"},
    "BackpackShapes": {"Default": "backpack", "Bucket": "sand", "Box": "crate", "Cart": "shop", "Vehicle": "ride",
                       "Orb": "gem"},
    "TreasureShapes": {"Default": "treasure", "Coin": "coins", "Shell": "shell", "Chest": "treasure",
                       "Gem": "gem", "Egg": "eggs", "Shard": "tokens", "Box": "crate", "Crown": "trophy"},
    "BoostKinds": {"Default": "multiplier", "Sand": "boost_sand", "Luck": "boost_luck", "Coins": "boost_coins",
                   "Speed": "boost_speed"},
    "Events": {"Default": "star", "HighTide": "high_tide", "GoldenHour": "golden_hour"},
}


# ================================================================= build
def render_all():
    assert len(ICONS) <= GRID * GRID, len(ICONS)
    names = [n for n, _ in ICONS]
    assert len(set(names)) == len(names), "duplicate icon names"
    os.makedirs(os.path.join(OUT_DIR, "png"), exist_ok=True)
    atlas = Image.new("RGBA", (CELL * GRID, CELL * GRID), (0, 0, 0, 0))
    offsets = {}
    for i, (name, fn) in enumerate(ICONS):
        ic = Icon()
        fn(ic)
        im = ic.finish()
        a = np.asarray(im.getchannel("A"))
        edge = max(a[:4].max(), a[-4:].max(), a[:, :4].max(), a[:, -4:].max())
        if edge > 8:
            print(f"  warning: {name} reaches the cell padding (alpha {edge})")
        im.save(os.path.join(OUT_DIR, "png", f"{name}.png"))
        x, y = (i % GRID) * CELL, (i // GRID) * CELL
        atlas.paste(im, (x, y))
        offsets[name] = (x, y)
    atlas.save(os.path.join(OUT_DIR, "atlas.png"), optimize=True)
    return atlas, offsets


def contact_sheet(atlas: Image.Image, offsets, size=32):
    """Every icon at `size` px on a dark and a light panel, with names (readability check)."""
    names = list(offsets)
    cols = 8
    cw, chh = 96, size + 22
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cw * cols * 2 + 16, chh * rows + 10), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    f = font("round", 10)
    panels = [((48, 44, 78), (255, 255, 255)), ((255, 236, 196), (45, 40, 70))]
    for p, (bg, fg) in enumerate(panels):
        x0 = p * (cw * cols + 16)
        d.rectangle([x0, 0, x0 + cw * cols, sheet.height], fill=bg)
        for i, n in enumerate(names):
            ox, oy = offsets[n]
            ic = atlas.crop((ox, oy, ox + CELL, oy + CELL)).resize((size, size), Image.LANCZOS)
            cx = x0 + (i % cols) * cw + (cw - size) // 2
            cy = 5 + (i // cols) * chh
            sheet.paste(ic, (cx, cy), ic)
            d.text((x0 + (i % cols) * cw + cw // 2, cy + size + 2), n, font=f, fill=fg, anchor="ma")
    return sheet


def _existing_asset_id() -> str:
    """Keep the owner's pasted id when the atlas is regenerated."""
    try:
        with open(LUAU_OUT) as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("local ASSET_ID = "):
                    return line.split("=", 1)[1].strip().strip('"')
    except FileNotFoundError:
        pass
    return ""


def write_luau(offsets):
    names = list(offsets)
    asset = _existing_asset_id()
    L = [
        "--!strict",
        "--[[",
        "\tIconAtlas — GENERATED by tools/icons/generate_icons.py (re-run it after changing icons; the",
        "\tgenerator keeps the ASSET_ID below). Source art: assets/icons/atlas.png, 1024x1024, an 8x8 grid",
        "\tof 128x128 cells; Icons[name] is the cell's ImageRectOffset in pixels.",
        "",
        "\tUsage on an ImageLabel / ImageButton:",
        "\t\tlocal offset = IconAtlas.Resolve(\"coins\") -- or a UI/Icons.luau key: IconAtlas.Resolve(\"Coins\")",
        "\t\tif IconAtlas.AssetId ~= \"\" and offset then",
        "\t\t\tlabel.Image = IconAtlas.AssetId",
        "\t\t\tlabel.ImageRectOffset = offset",
        "\t\t\tlabel.ImageRectSize = Vector2.new(IconAtlas.CellSize, IconAtlas.CellSize)",
        "\t\telse -- fall back to the emoji text from UI/Icons.luau",
        "\t\tend",
        "\tGrouped Icons.luau tables (Icons.Layers, Icons.PetShapes, ...): Groups[group][key] or",
        "\tGroups[group].Default.",
        "",
        "\tUPLOADING THE ATLAS (owner, once per change of atlas.png):",
        "\t  1. Studio -> View -> Asset Manager -> Bulk Import -> choose assets/icons/atlas.png",
        "\t     (or Creator Hub -> Creations -> Development Items -> Decals/Images -> Upload).",
        "\t  2. Copy the IMAGE asset id, NOT the decal id. In Studio, insert the uploaded decal into the",
        "\t     Workspace and look at its Texture/Image property: \"rbxassetid://<id>\" — that <id> is the",
        "\t     image id. (Asset Manager -> right-click the image -> Copy Asset ID also gives the image id.)",
        "\t     The decal id from the website URL is a different number and will show a blank image.",
        "\t  3. Paste it below:  local ASSET_ID = \"rbxassetid://<id>\"",
        "\tWhile ASSET_ID is \"\" the UI should keep using the emoji icons (UI/Icons.luau).",
        "]]",
        "",
        f"local ASSET_ID = \"{asset}\"",
        "",
        "local Icons: { [string]: Vector2 } = {",
    ]
    for n in names:
        x, y = offsets[n]
        L.append(f"\t{n} = Vector2.new({x}, {y}),")
    L += ["}", "", "-- UI/Icons.luau key -> atlas icon name",
          "local Aliases: { [string]: string } = {"]
    for k, v in ALIASES.items():
        assert v in offsets, v
        L.append(f"\t{k} = \"{v}\",")
    L += ["}", "",
          "-- UI/Icons.luau grouped tables -> atlas icon name (per-key overrides, else Default)",
          "local Groups: { [string]: { [string]: string } } = {"]
    for g, m in GROUPS.items():
        L.append(f"\t{g} = {{")
        for k, v in m.items():
            assert v in offsets, v
            L.append(f"\t\t{k} = \"{v}\",")
        L.append("\t},")
    L += ["}", "",
          "-- Atlas offset for an icon name (\"coins\") or a UI/Icons.luau key (\"Coins\"); nil if unknown.",
          "local function Resolve(key: string): Vector2?",
          "\tlocal direct = Icons[key]",
          "\tif direct then",
          "\t\treturn direct",
          "\tend",
          "\tlocal alias = Aliases[key]",
          "\treturn if alias then Icons[alias] else nil",
          "end",
          "",
          "-- Atlas offset for a grouped Icons.luau entry, e.g. GroupOffset(\"PetShapes\", \"Crab\").",
          "local function GroupOffset(group: string, key: string): Vector2?",
          "\tlocal g = Groups[group]",
          "\tif not g then",
          "\t\treturn nil",
          "\tend",
          "\tlocal name = g[key] or g.Default",
          "\treturn if name then Icons[name] else nil",
          "end",
          "",
          "return {",
          "\tAssetId = ASSET_ID,",
          f"\tCellSize = {CELL},",
          "\tIcons = Icons,",
          "\tAliases = Aliases,",
          "\tGroups = Groups,",
          "\tResolve = Resolve,",
          "\tGroupOffset = GroupOffset,",
          "}", ""]
    with open(LUAU_OUT, "w") as fh:
        fh.write("\n".join(L))


def main():
    atlas, offsets = render_all()
    contact_sheet(atlas, offsets, 32).save(os.path.join(OUT_DIR, "preview_32.png"))
    write_luau(offsets)
    print(f"{len(offsets)} icons -> {os.path.relpath(OUT_DIR, REPO)}/atlas.png, png/, preview_32.png; "
          f"{os.path.relpath(LUAU_OUT, REPO)}")


if __name__ == "__main__":
    main()
