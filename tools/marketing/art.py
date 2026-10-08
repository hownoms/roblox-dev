"""
Shared drawing toolkit for "Dig to the Core! Beach Simulator" marketing art.

Everything is drawn with Pillow (+ numpy for gradients) on a supersampled canvas and
downscaled at the end, which gives clean anti-aliased edges. Coordinates passed to the
Canvas helpers are always in *final* output pixels; the canvas scales them internally.

Style rules (match the game's Config.Theme): saturated colours, thick dark outlines
(STROKE), cel-style highlights, chunky rounded title text.
"""

from __future__ import annotations

import math
import os
import random
from typing import Callable, Iterable, Sequence

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "marketing")
FONT_DIR = os.path.join(HERE, "fonts")

SS = 2  # supersampling factor

# ---------------------------------------------------------------- palette (Config.Theme)
STROKE = (35, 30, 60)
WHITE = (255, 255, 255)
SAND = (255, 222, 140)
SAND_DARK = (222, 176, 92)
OCEAN = (40, 190, 245)
OCEAN_DARK = (20, 110, 200)
SKY = (150, 225, 255)
SUNSET = (255, 140, 60)
CORAL = (255, 95, 125)
PALM = (70, 210, 120)
GOLD = (255, 205, 40)
PURPLE = (170, 100, 255)

# Config.Layers — (name, colour, depthStart, depthEnd)
LAYERS = [
    ("Dry Sand", (255, 224, 150), 0, 20),
    ("Wet Sand", (214, 172, 112), 20, 45),
    ("Shell Bed", (255, 214, 214), 45, 75),
    ("Tidal Clay", (150, 108, 82), 75, 110),
    ("Pirate Cove", (122, 86, 56), 110, 150),
    ("Sunken Shipwreck", (128, 88, 54), 150, 200),
    ("Fossil Bed", (228, 212, 176), 200, 260),
    ("Bedrock", (108, 110, 122), 260, 330),
    ("Crystal Caverns", (176, 112, 255), 330, 410),
    ("Frozen Abyss", (160, 226, 255), 410, 495),
    ("Ancient Ruins", (206, 176, 110), 495, 585),
    ("Magma Chamber", (255, 92, 32), 585, 680),
    ("Obsidian Depths", (52, 40, 72), 680, 780),
    ("Alien Hive", (96, 232, 124), 780, 885),
    ("The Core", (255, 200, 60), 885, 1000),
]

RARITY = {
    "Common": (200, 200, 210),
    "Uncommon": (90, 220, 110),
    "Rare": (60, 160, 255),
    "Epic": (180, 90, 255),
    "Legendary": (255, 190, 30),
    "Mythic": (255, 70, 120),
}


# ---------------------------------------------------------------- colour helpers
def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def lighten(c, t=0.3):
    return mix(c, WHITE, t)


def darken(c, t=0.3):
    return mix(c, (0, 0, 0), t)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


# ---------------------------------------------------------------- fonts
_FONT_FILES = {
    "title": ["LuckiestGuy-Regular.ttf", "LilitaOne-Regular.ttf", "FredokaOne-Regular.ttf"],
    "round": ["FredokaOne-Regular.ttf", "LilitaOne-Regular.ttf"],
    "block": ["LilitaOne-Regular.ttf", "FredokaOne-Regular.ttf"],
}
_FALLBACK = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    for name in _FONT_FILES.get(kind, []):
        p = os.path.join(FONT_DIR, name)
        if os.path.exists(p) and os.path.getsize(p) > 10_000:
            return ImageFont.truetype(p, size)
    return ImageFont.truetype(_FALLBACK, size)


# ---------------------------------------------------------------- gradients
def vgradient(w, h, stops: Sequence[tuple[float, tuple]]) -> Image.Image:
    """Vertical gradient with colour stops [(t, rgb), ...], t in 0..1."""
    ts = np.array([s[0] for s in stops])
    cols = np.array([s[1] for s in stops], dtype=float)
    y = np.linspace(0, 1, h)
    out = np.zeros((h, 3))
    for ch in range(3):
        out[:, ch] = np.interp(y, ts, cols[:, ch])
    arr = np.repeat(out[:, None, :], w, axis=1).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def rgradient(w, h, cx, cy, r, inner, outer, power=1.0) -> Image.Image:
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(r, 1)
    t = np.clip(d, 0, 1) ** power
    a = np.array(inner, float)
    b = np.array(outer, float)
    arr = a[None, None, :] + (b - a)[None, None, :] * t[..., None]
    mode = "RGBA" if len(inner) == 4 else "RGB"
    return Image.fromarray(arr.astype(np.uint8), mode).convert("RGBA")


def radial_alpha(w, h, cx, cy, r, color, max_alpha=255, power=1.6) -> Image.Image:
    """Soft round glow: colour with alpha falling off from centre."""
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(r, 1)
    a = np.clip(1 - d, 0, 1) ** power * max_alpha
    arr = np.zeros((h, w, 4), np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = color[0], color[1], color[2]
    arr[..., 3] = a.astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


# ---------------------------------------------------------------- canvas
class Canvas:
    """RGBA canvas whose draw helpers take final-pixel coordinates (scaled by `s`)."""

    def __init__(self, w, h, s=SS, bg=None):
        self.w, self.h, self.s = w, h, s
        self.img = Image.new("RGBA", (int(w * s), int(h * s)), bg or (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    # coordinate helpers
    def P(self, pts):
        return [(x * self.s, y * self.s) for x, y in pts]

    def B(self, box):
        x0, y0, x1, y1 = box
        return [min(x0, x1) * self.s, min(y0, y1) * self.s, max(x0, x1) * self.s, max(y0, y1) * self.s]

    def W(self, w):
        return max(1, int(round(w * self.s)))

    def refresh(self):
        self.d = ImageDraw.Draw(self.img)

    def blend(self, bbox, fn):
        """Run fn(draw, ox, oy) on a temp layer covering bbox (canvas px) and alpha-composite it,
        so translucent fills blend instead of overwriting alpha."""
        x0, y0, x1, y1 = [int(v) for v in bbox]
        x0, y0 = max(0, x0 - 4), max(0, y0 - 4)
        x1, y1 = min(self.img.width, x1 + 4), min(self.img.height, y1 + 4)
        if x1 <= x0 or y1 <= y0:
            return
        tmp = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        fn(ImageDraw.Draw(tmp), x0, y0)
        self.img.alpha_composite(tmp, (x0, y0))
        self.refresh()

    # primitives (outline drawn as a bigger shape behind so it sits *outside* the fill)
    def poly(self, pts, fill, outline=STROKE, width=0):
        pts = list(pts)
        if width and outline:
            self.d.polygon(self.P(pts), fill=rgba(outline) if len(outline) == 3 else outline)
            self.d.line(self.P(pts + [pts[0]]), fill=rgba(outline) if len(outline) == 3 else outline,
                        width=self.W(width * 2), joint="curve")
            for x, y in self.P(pts):
                r = width * self.s
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(outline) if len(outline) == 3 else outline)
        if fill is not None:
            if len(fill) == 4 and 0 < fill[3] < 255:
                P = self.P(pts)
                xs, ys = [q[0] for q in P], [q[1] for q in P]
                self.blend((min(xs), min(ys), max(xs), max(ys)),
                           lambda d, ox, oy: d.polygon([(x - ox, y - oy) for x, y in P], fill=fill))
            else:
                self.d.polygon(self.P(pts), fill=fill if len(fill) == 4 else rgba(fill))

    def ellipse(self, box, fill, outline=STROKE, width=0):
        x0, y0, x1, y1 = box
        if width and outline:
            self.d.ellipse(self.B((x0 - width, y0 - width, x1 + width, y1 + width)),
                           fill=outline if len(outline) == 4 else rgba(outline))
        if fill is not None:
            if len(fill) == 4 and 0 < fill[3] < 255:
                b = self.B(box)
                self.blend(b, lambda d, ox, oy: d.ellipse([b[0] - ox, b[1] - oy, b[2] - ox, b[3] - oy], fill=fill))
            else:
                self.d.ellipse(self.B(box), fill=fill if len(fill) == 4 else rgba(fill))

    def circle(self, cx, cy, r, fill, outline=STROKE, width=0):
        self.ellipse((cx - r, cy - r, cx + r, cy + r), fill, outline, width)

    def rrect(self, box, r, fill, outline=STROKE, width=0):
        x0, y0, x1, y1 = box
        if width and outline:
            self.d.rounded_rectangle(self.B((x0 - width, y0 - width, x1 + width, y1 + width)),
                                     radius=(r + width) * self.s, fill=rgba(outline))
        if fill is not None:
            self.d.rounded_rectangle(self.B(box), radius=r * self.s, fill=fill if len(fill) == 4 else rgba(fill))

    def line(self, pts, color, width, outline=None, owidth=0):
        pts = list(pts)
        if outline:
            self.d.line(self.P(pts), fill=rgba(outline), width=self.W(width + owidth * 2), joint="curve")
            for x, y in self.P([pts[0], pts[-1]]):
                r = (width / 2 + owidth) * self.s
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=rgba(outline))
        self.d.line(self.P(pts), fill=color if len(color) == 4 else rgba(color), width=self.W(width), joint="curve")
        for x, y in self.P([pts[0], pts[-1]]):
            r = width / 2 * self.s
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=color if len(color) == 4 else rgba(color))

    # compositing
    def layer(self):
        return Canvas(self.w, self.h, self.s)

    def over(self, other: "Canvas | Image.Image", alpha=1.0):
        im = other.img if isinstance(other, Canvas) else other
        if alpha < 1:
            im = im.copy()
            im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
        self.img.alpha_composite(im)
        self.refresh()

    def glow(self, cx, cy, r, color, alpha=220, power=1.6):
        """Additive-looking soft glow (screen blend)."""
        g = radial_alpha(self.img.width, self.img.height, cx * self.s, cy * self.s, r * self.s, color, alpha, power)
        self.img.alpha_composite(g)
        self.refresh()

    def paste(self, sprite: Image.Image, cx, cy, rot=0.0, scale=1.0, flip=False):
        """Paste a sprite (already at canvas resolution) centred at (cx, cy)."""
        sp = sprite
        if flip:
            sp = sp.transpose(Image.FLIP_LEFT_RIGHT)
        if scale != 1.0:
            sp = sp.resize((max(1, int(sp.width * scale)), max(1, int(sp.height * scale))), Image.LANCZOS)
        if rot:
            sp = sp.rotate(rot, resample=Image.BICUBIC, expand=True)
        x = int(cx * self.s - sp.width / 2)
        y = int(cy * self.s - sp.height / 2)
        self.img.alpha_composite(sp, (x, y)) if x >= 0 and y >= 0 and x + sp.width <= self.img.width and y + sp.height <= self.img.height else _safe_composite(self.img, sp, x, y)
        self.refresh()

    def final(self, size=None):
        out = self.img.resize((size or (self.w, self.h)), Image.LANCZOS)
        return out


def _safe_composite(base: Image.Image, sp: Image.Image, x: int, y: int):
    tmp = Image.new("RGBA", base.size, (0, 0, 0, 0))
    tmp.paste(sp, (x, y), sp)
    base.alpha_composite(tmp)


# ---------------------------------------------------------------- sprites
def sprite(draw_fn: Callable[[Canvas], None], size: float, design=200, outline=10, outline_color=STROKE,
           shadow=True) -> Image.Image:
    """Draw `draw_fn` in a design x design local space, render it at `size` final px
    (times SS) and wrap the whole silhouette in a thick dark outline + soft drop shadow."""
    scale = size / design * SS
    pad = int(outline * scale * 1.6 + 20)
    c = Canvas(design, design, scale)
    draw_fn(c)
    im = c.img
    big = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    big.alpha_composite(im, (pad, pad))
    if outline:
        a = big.getchannel("A")
        r = outline * scale
        blurred = a.filter(ImageFilter.GaussianBlur(r * 0.5))
        mask = blurred.point(lambda v: 255 if v > 6 else int(v * 42))
        # second pass to round off corners
        mask = mask.filter(ImageFilter.GaussianBlur(max(1, r * 0.12))).point(lambda v: 255 if v > 110 else int(v * 2.3))
        ol = Image.new("RGBA", big.size, rgba(outline_color))
        ol.putalpha(mask)
        layers = Image.new("RGBA", big.size, (0, 0, 0, 0))
        if shadow:
            sh = Image.new("RGBA", big.size, (0, 0, 0, 0))
            shm = mask.filter(ImageFilter.GaussianBlur(r * 0.6)).point(lambda v: int(v * 0.35))
            sh2 = Image.new("RGBA", big.size, (10, 5, 30, 255))
            sh2.putalpha(shm)
            sh.alpha_composite(sh2, (0, 0))
            off = int(r * 0.9)
            layers.alpha_composite(sh, (0, 0) if off <= 0 else (0, 0))
            layers = ImageChops.offset(layers, off // 2, off)
        layers.alpha_composite(ol)
        layers.alpha_composite(big)
        big = layers
    return big


def shine(c: Canvas, box, alpha=110):
    """White glossy highlight ellipse."""
    c.ellipse(box, (255, 255, 255, alpha))


# ---- pets -------------------------------------------------------------------------------
def eyes(c: Canvas, x1, y1, x2, y2, r=13, look=(2, 2)):
    for x, y in ((x1, y1), (x2, y2)):
        c.ellipse((x - r, y - r * 1.25, x + r, y + r * 1.25), STROKE)
        c.circle(x - r * 0.35 + look[0] * 0.3, y - r * 0.5, r * 0.42, WHITE)
        c.circle(x + r * 0.35, y + r * 0.45, r * 0.18, WHITE)


def blush(c: Canvas, x, y, r=9):
    c.ellipse((x - r * 1.3, y - r * 0.7, x + r * 1.3, y + r * 0.7), (255, 120, 150, 150))


def smile(c: Canvas, x, y, w=16):
    c.d.arc(c.B((x - w, y - w * 0.8, x + w, y + w * 0.8)), 20, 160, fill=rgba(STROKE), width=c.W(5))


def pet_crab(c: Canvas, body=(255, 95, 70), accent=(255, 220, 180), glow=False):
    # legs
    for i, dx in enumerate((-58, -42, 42, 58)):
        side = -1 if dx < 0 else 1
        c.line([(100 + dx, 130), (100 + dx + side * 22, 160), (100 + dx + side * 16, 182)], darken(body, .15), 9,
               STROKE, 4)
    # claws
    for side in (-1, 1):
        cx = 100 + side * 78
        c.line([(100 + side * 40, 115), (cx, 85)], darken(body, .1), 12, STROKE, 4)
        c.circle(cx, 70, 26, body, STROKE, 5)
        c.poly([(cx, 70), (cx + side * 30, 50), (cx + side * 30, 75)], (0, 0, 0, 0), None, 0)
        c.d.polygon(c.P([(cx, 68), (cx + side * 32, 46), (cx + side * 34, 72)]), fill=(0, 0, 0, 0))
        c.circle(cx - side * 8, 62, 7, lighten(body, .5))
    # stalks
    for side in (-1, 1):
        c.line([(100 + side * 20, 100), (100 + side * 24, 62)], darken(body, .1), 8, STROKE, 4)
    # body
    c.ellipse((32, 88, 168, 168), body, STROKE, 5)
    c.ellipse((40, 96, 160, 128), lighten(body, .25))
    shine(c, (55, 98, 95, 112), 120)
    for side in (-1, 1):
        x = 100 + side * 24
        c.circle(x, 56, 17, WHITE, STROKE, 4)
        c.circle(x + 2, 58, 9, STROKE)
        c.circle(x - 1, 54, 4, WHITE)
    smile(c, 100, 136, 16)
    blush(c, 62, 136)
    blush(c, 138, 136)


def pet_turtle(c: Canvas, body=(110, 200, 90), shell=(40, 170, 140), accent=(220, 190, 120)):
    # legs
    for x in (55, 140):
        c.ellipse((x - 16, 140, x + 16, 178), body, STROKE, 5)
    # head
    c.circle(160, 100, 34, body, STROKE, 5)
    shine(c, (140, 74, 166, 90), 120)
    eyes(c, 152, 96, 178, 96, 9)
    smile(c, 166, 116, 9)
    # shell
    c.d.chord(c.B((14, 46, 152, 196)), 180, 360, fill=rgba(STROKE))
    c.d.chord(c.B((22, 54, 144, 188)), 180, 360, fill=rgba(shell))
    c.rrect((10, 116, 156, 140), 12, accent, STROKE, 5)
    for (x, y) in ((83, 88), (50, 104), (116, 104)):
        c.poly([(x - 16, y), (x - 8, y - 14), (x + 8, y - 14), (x + 16, y), (x + 8, y + 14), (x - 8, y + 14)],
               lighten(shell, .25), darken(shell, .35), 3)
    shine(c, (40, 64, 80, 80), 110)


def pet_dragon(c: Canvas, body=(255, 150, 30), belly=(255, 230, 120), wing=(255, 80, 40), horn=(255, 250, 220)):
    # tail
    c.line([(60, 150), (25, 168), (12, 140)], body, 22, STROKE, 5)
    c.poly([(12, 120), (0, 145), (24, 142)], wing, STROKE, 4)
    # wings
    c.poly([(72, 100), (6, 22), (26, 70), (0, 84), (30, 104), (8, 124), (60, 122)], wing, STROKE, 5)
    c.poly([(128, 100), (194, 22), (174, 70), (200, 84), (170, 104), (192, 124), (140, 122)], wing, STROKE, 5)
    c.line([(72, 100), (16, 36)], darken(wing, .25), 4)
    c.line([(128, 100), (184, 36)], darken(wing, .25), 4)
    # body
    c.ellipse((50, 90, 150, 185), body, STROKE, 5)
    c.ellipse((72, 112, 128, 180), belly)
    # feet
    for x in (70, 130):
        c.ellipse((x - 16, 168, x + 16, 192), body, STROKE, 5)
    # head
    c.poly([(70, 30), (62, 0), (86, 24)], horn, STROKE, 4)
    c.poly([(130, 30), (138, 0), (114, 24)], horn, STROKE, 4)
    c.ellipse((50, 18, 150, 110), body, STROKE, 5)
    c.ellipse((75, 70, 125, 104), belly)
    shine(c, (64, 26, 104, 46), 130)
    eyes(c, 80, 56, 120, 56, 12)
    c.circle(92, 84, 3, STROKE)
    c.circle(108, 84, 3, STROKE)
    blush(c, 66, 78)
    blush(c, 134, 78)


def pet_octopus(c: Canvas, body=(240, 90, 170), accent=(255, 200, 230)):
    for i in range(6):
        x = 38 + i * 25
        c.line([(x, 120), (x + (8 if i % 2 else -8), 160), (x + (-4 if i % 2 else 4), 188)], body, 20, STROKE, 5)
    c.ellipse((28, 20, 172, 150), body, STROKE, 5)
    for (x, y, r) in ((60, 50, 8), (140, 46, 6), (130, 70, 5)):
        c.circle(x, y, r, accent)
    shine(c, (52, 30, 100, 54), 130)
    eyes(c, 76, 92, 124, 92, 14)
    smile(c, 100, 122, 12)
    blush(c, 52, 112)
    blush(c, 148, 112)


def pet_seal(c: Canvas, body=(170, 200, 230), belly=(240, 248, 255)):
    c.poly([(30, 170), (8, 150), (8, 192)], body, STROKE, 5)
    c.ellipse((20, 60, 180, 190), body, STROKE, 5)
    c.ellipse((60, 110, 150, 186), belly)
    c.poly([(150, 150), (192, 172), (150, 182)], darken(body, .1), STROKE, 5)
    shine(c, (40, 70, 90, 96), 130)
    eyes(c, 80, 104, 128, 104, 12)
    c.ellipse((94, 118, 114, 130), STROKE)
    for side in (-1, 1):
        for dy in (-4, 6):
            c.line([(104 + side * 18, 128 + dy), (104 + side * 42, 124 + dy * 2)], STROKE, 3)
    blush(c, 64, 128)
    blush(c, 146, 128)


def pet_alien(c: Canvas, body=(110, 240, 140), accent=(200, 255, 120)):
    c.line([(100, 40), (88, 10)], body, 7, STROKE, 4)
    c.circle(86, 8, 10, accent, STROKE, 4)
    c.poly([(30, 190), (36, 90), (64, 46), (100, 36), (136, 46), (164, 90), (170, 190), (148, 172), (124, 190),
            (100, 172), (76, 190), (52, 172)], body, STROKE, 5)
    shine(c, (54, 56, 96, 80), 130)
    c.ellipse((62, 70, 138, 140), WHITE, STROKE, 5)
    c.circle(104, 108, 22, STROKE)
    c.circle(96, 98, 8, WHITE)
    smile(c, 100, 154, 12)


def pet_phoenix(c: Canvas, body=(255, 90, 40), accent=(255, 210, 60)):
    for i, (dx, h) in enumerate(((-18, 40), (0, 54), (18, 40))):
        c.poly([(100 + dx - 12, 50), (100 + dx, 50 - h), (100 + dx + 12, 50)], accent if i == 1 else body, STROKE, 4)
    c.poly([(40, 150), (0, 120), (20, 170), (60, 180)], accent, STROKE, 5)
    c.poly([(160, 150), (200, 120), (180, 170), (140, 180)], accent, STROKE, 5)
    c.ellipse((40, 40, 160, 180), body, STROKE, 5)
    c.ellipse((66, 100, 134, 176), accent)
    shine(c, (58, 50, 100, 74), 130)
    eyes(c, 80, 90, 120, 90, 11)
    c.poly([(92, 104), (108, 104), (100, 118)], (255, 200, 40), STROKE, 3)
    c.poly([(70, 176), (64, 196), (80, 186)], accent, STROKE, 3)
    c.poly([(130, 176), (136, 196), (120, 186)], accent, STROKE, 3)


def pet_starfish(c: Canvas, body=(255, 90, 200), accent=(90, 220, 255)):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 92 if i % 2 == 0 else 42
        pts.append((100 + r * math.cos(a), 108 + r * math.sin(a)))
    c.poly(pts, body, STROKE, 5)
    inner = [(100 + (p[0] - 100) * 0.6, 108 + (p[1] - 108) * 0.6) for p in pts]
    c.poly(inner, accent, None)
    shine(c, (78, 40, 104, 70), 140)
    eyes(c, 84, 104, 116, 104, 10)
    smile(c, 100, 124, 9)


# ---- treasures -------------------------------------------------------------------------
def tr_chest(c: Canvas, open_=True, wood=(170, 105, 50), metal=(255, 205, 40)):
    if open_:
        # lid tilted back
        c.poly([(20, 60), (180, 60), (170, 10), (30, 10)], darken(wood, .1), STROKE, 6)
        c.poly([(30, 22), (170, 22), (172, 34), (28, 34)], metal, None)
        # gold pile
        for (x, y, r) in ((60, 74, 26), (100, 62, 32), (140, 74, 26), (82, 80, 24), (120, 80, 24)):
            c.circle(x, y, r, GOLD, STROKE, 4)
            c.circle(x - r * .3, y - r * .3, r * .3, (255, 245, 170))
        # gem on top
        c.poly([(100, 30), (118, 48), (100, 70), (82, 48)], (90, 220, 255), STROKE, 4)
    c.rrect((18, 80, 182, 186), 10, wood, STROKE, 6)
    for x in (18, 166):
        c.rrect((x, 80, x + 16, 186), 3, metal, STROKE, 3)
    c.rrect((18, 80, 182, 100), 4, darken(wood, .2), STROKE, 3)
    for y in (120, 150):
        c.line([(30, y), (170, y)], darken(wood, .25), 3)
    c.rrect((86, 96, 114, 132), 6, metal, STROKE, 4)
    c.circle(100, 112, 5, STROKE)


def tr_diamond(c: Canvas, col=(90, 220, 255)):
    top = [(40, 70), (70, 30), (130, 30), (160, 70)]
    c.poly(top + [(100, 180)], col, STROKE, 6)
    c.poly([(40, 70), (160, 70), (100, 180)], darken(col, .15), None)
    c.poly([(70, 30), (85, 70), (100, 30)], lighten(col, .5), None)
    c.poly([(100, 30), (115, 70), (130, 30)], lighten(col, .3), None)
    c.poly([(85, 70), (100, 180), (70, 70)], lighten(col, .35), None)
    c.line([(40, 70), (160, 70)], STROKE, 4)


def tr_rainbow_diamond(c: Canvas):
    cols = [(255, 80, 120), (255, 170, 40), (255, 240, 80), (90, 230, 120), (70, 170, 255), (180, 100, 255)]
    c.poly([(30, 70), (65, 25), (135, 25), (170, 70), (100, 185)], cols[4], STROKE, 6)
    xs = [30, 53, 77, 100, 123, 147, 170]
    for i in range(6):
        c.poly([(xs[i], 70), (xs[i + 1], 70), (100, 185)], cols[i], None)
    c.poly([(30, 70), (65, 25), (135, 25), (170, 70)], (230, 250, 255), None)
    c.poly([(65, 25), (82, 70), (100, 25), (118, 70), (135, 25)], (200, 235, 255), None)
    c.line([(30, 70), (170, 70)], STROKE, 4)
    shine(c, (60, 34, 90, 52), 200)


def tr_crown(c: Canvas, col=GOLD):
    c.poly([(20, 160), (20, 60), (60, 105), (100, 40), (140, 105), (180, 60), (180, 160)], col, STROKE, 6)
    c.rrect((20, 140, 180, 170), 6, darken(col, .15), STROKE, 4)
    for (x, y, gc) in ((100, 110, (255, 70, 110)), (55, 128, (90, 200, 255)), (145, 128, (90, 230, 120))):
        c.circle(x, y, 13, gc, STROKE, 3)
    for (x, y) in ((20, 58), (100, 36), (180, 58)):
        c.circle(x, y, 11, (255, 245, 180), STROKE, 4)
    shine(c, (36, 70, 60, 120), 100)


def tr_skull(c: Canvas, col=(245, 235, 210)):
    # dino skull: long snout to the right
    c.poly([(20, 90), (40, 40), (100, 30), (160, 60), (190, 100), (180, 130), (120, 130), (110, 160), (60, 160),
            (30, 140)], col, STROKE, 6)
    c.ellipse((52, 60, 92, 100), STROKE)
    c.circle(66, 74, 6, (255, 120, 60))
    for x in range(118, 182, 14):
        c.poly([(x, 128), (x + 10, 128), (x + 5, 145)], WHITE, STROKE, 3)
    c.ellipse((150, 76, 166, 90), STROKE)
    shine(c, (50, 40, 110, 56), 120)


def tr_bone(c: Canvas, col=(245, 235, 210)):
    c.line([(45, 155), (155, 45)], col, 34, STROKE, 6)
    for (x, y) in ((40, 140), (60, 160), (140, 40), (160, 60)):
        c.circle(x, y, 22, col, STROKE, 6)
    c.line([(45, 155), (155, 45)], col, 34)
    for (x, y) in ((40, 140), (60, 160), (140, 40), (160, 60)):
        c.circle(x, y, 22, col)
    c.line([(70, 118), (118, 70)], WHITE, 8)


def tr_crystal(c: Canvas, col=(176, 112, 255)):
    shards = [((100, 10), 34, 170), ((55, 50), 26, 170), ((150, 55), 26, 170), ((28, 95), 18, 175),
              ((175, 100), 18, 175)]
    for (tx, ty), hw, by in sorted(shards, key=lambda s: -abs(s[0][0] - 100)):
        k = 0 if tx == 100 else (1 if abs(tx - 100) < 60 else 2)
        cc = lighten(col, 0.08 * k)
        c.poly([(tx, ty), (tx + hw, ty + 40), (tx + hw * .8, by), (tx - hw * .8, by), (tx - hw, ty + 40)], cc,
               STROKE, 5)
        c.poly([(tx, ty), (tx + hw * .3, ty + 40), (tx + hw * .2, by), (tx - hw * .3, by), (tx - hw, ty + 40)],
               lighten(cc, .35), None)
    c.ellipse((10, 160, 190, 196), (110, 100, 130), STROKE, 5)


def tr_coin(c: Canvas, col=GOLD):
    c.circle(100, 100, 85, darken(col, .15), STROKE, 6)
    c.circle(100, 94, 80, col)
    c.circle(100, 94, 58, lighten(col, .2), darken(col, .2), 5)
    f = font("title", 90)
    c.d.text((100 * c.s, 100 * c.s), "$", font=font("title", int(90 * c.s)), anchor="mm", fill=rgba(darken(col, .3)))
    shine(c, (50, 30, 90, 56), 140)


def tr_beachball(c: Canvas):
    cols = [(255, 70, 90), WHITE, (60, 160, 255), WHITE, (255, 205, 40), WHITE]
    c.circle(100, 100, 88, WHITE, STROKE, 6)
    box = c.B((12, 12, 188, 188))
    for i, col in enumerate(cols):
        c.d.pieslice(box, i * 60 - 90, (i + 1) * 60 - 90, fill=rgba(col))
    c.circle(100, 100, 14, (255, 205, 40), STROKE, 3)
    shine(c, (40, 36, 92, 70), 150)


def tr_egg(c: Canvas, col=(255, 255, 240), spots=(90, 200, 255)):
    c.ellipse((30, 10, 170, 190), col, STROKE, 6)
    for (x, y, r) in ((70, 70, 16), (125, 50, 12), (130, 120, 20), (80, 140, 14), (100, 100, 8)):
        c.circle(x, y, r, spots)
    shine(c, (55, 30, 90, 80), 150)


def tr_anchor(c: Canvas, col=(150, 160, 175)):
    c.circle(100, 30, 18, None, STROKE, 0)
    c.d.ellipse(c.B((80, 10, 120, 50)), outline=rgba(STROKE), width=c.W(18))
    c.d.ellipse(c.B((80, 10, 120, 50)), outline=rgba(col), width=c.W(9))
    c.line([(100, 50), (100, 170)], col, 18, STROKE, 5)
    c.line([(60, 75), (140, 75)], col, 16, STROKE, 5)
    c.d.arc(c.B((30, 90, 170, 190)), 20, 160, fill=rgba(STROKE), width=c.W(26))
    c.d.arc(c.B((30, 90, 170, 190)), 20, 160, fill=rgba(col), width=c.W(16))
    c.poly([(26, 120), (48, 140), (20, 150)], col, STROKE, 4)
    c.poly([(174, 120), (152, 140), (180, 150)], col, STROKE, 4)


def tr_flame(c: Canvas, outer=(255, 90, 30), inner=(255, 220, 60)):
    pts = [(100, 5), (130, 50), (165, 40), (175, 110), (160, 170), (100, 195), (40, 170), (25, 110), (45, 60),
           (70, 80)]
    c.poly(pts, outer, STROKE, 6)
    c.poly([(100, 70), (130, 120), (125, 170), (100, 185), (75, 170), (70, 120)], inner, None)
    c.ellipse((88, 140, 112, 180), WHITE)


def tr_ufo(c: Canvas):
    c.ellipse((60, 30, 140, 110), (180, 255, 230, 230), STROKE, 6)
    pet_eye = (100, 72)
    c.circle(100, 76, 18, (110, 240, 140), STROKE, 3)
    c.circle(100, 74, 6, STROKE)
    c.ellipse((10, 80, 190, 140), (170, 180, 200), STROKE, 6)
    c.ellipse((30, 84, 170, 110), (220, 230, 240))
    for x in (40, 70, 100, 130, 160):
        c.circle(x, 122, 7, (255, 230, 80), STROKE, 3)


def tr_shovel(c: Canvas, blade=(200, 210, 225), handle=(170, 105, 50), grip=(255, 95, 70)):
    """Upright shovel in 200 box: grip at top, blade at bottom."""
    c.rrect((70, 6, 130, 30), 10, grip, STROKE, 6)
    c.rrect((92, 20, 108, 120), 6, handle, STROKE, 6)
    c.poly([(60, 112), (140, 112), (140, 150), (100, 196), (60, 150)], blade, STROKE, 6)
    c.poly([(68, 118), (100, 118), (100, 188), (68, 150)], lighten(blade, .45), None)
    c.rrect((86, 104, 114, 122), 4, darken(blade, .2), STROKE, 4)


def tr_snowflake(c: Canvas, col=(220, 245, 255)):
    for i in range(3):
        a = i * math.pi / 3
        dx, dy = math.cos(a) * 80, math.sin(a) * 80
        c.line([(100 - dx, 100 - dy), (100 + dx, 100 + dy)], col, 16, STROKE, 5)
    for i in range(6):
        a = i * math.pi / 3
        x, y = 100 + math.cos(a) * 55, 100 + math.sin(a) * 55
        for s in (-1, 1):
            b = a + s * 0.7
            c.line([(x, y), (x + math.cos(b) * 22, y + math.sin(b) * 22)], col, 10, STROKE, 4)
    for i in range(3):
        a = i * math.pi / 3
        dx, dy = math.cos(a) * 80, math.sin(a) * 80
        c.line([(100 - dx, 100 - dy), (100 + dx, 100 + dy)], col, 16)
    c.circle(100, 100, 18, WHITE, STROKE, 4)


def tr_rebirth(c: Canvas, col=(120, 255, 200)):
    """Two chasing circular arrows (the rebirth symbol)."""
    cx, cy, r = 100, 100, 66
    box = c.B((cx - r, cy - r, cx + r, cy + r))
    for a0 in (200, 20):
        a1 = a0 + 120
        c.d.arc(box, a0, a1, fill=rgba(col), width=c.W(30))
        t = math.radians(a1)
        hx, hy = cx + r * math.cos(t), cy + r * math.sin(t)
        tx, ty = -math.sin(t), math.cos(t)
        nx, ny = math.cos(t), math.sin(t)
        c.poly([(hx + nx * 32, hy + ny * 32), (hx + tx * 44, hy + ty * 44), (hx - nx * 32, hy - ny * 32)], col,
               None)
    c.d.arc(c.B((cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6)), 210, 300, fill=rgba(lighten(col, .55)),
            width=c.W(6))
    c.d.arc(c.B((cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6)), 30, 120, fill=rgba(lighten(col, .55)),
            width=c.W(6))


def tr_core(c: Canvas):
    c.circle(100, 100, 80, (255, 150, 30), STROKE, 6)
    c.circle(100, 100, 62, (255, 200, 60))
    c.circle(100, 100, 40, (255, 240, 150))
    c.circle(100, 100, 20, WHITE)
    shine(c, (46, 40, 86, 66), 120)


# ---- the character ---------------------------------------------------------------------
SKIN = (255, 206, 60)  # classic yellow


def box3d(c: Canvas, x, y, w, h, col, d=10, width=5):
    """Front face at (x, y, w, h) with a darker right side and lighter top (pseudo-3D)."""
    side = [(x + w, y), (x + w + d, y - d), (x + w + d, y + h - d), (x + w, y + h)]
    top = [(x, y), (x + d, y - d), (x + w + d, y - d), (x + w, y)]
    outline = [(x, y), (x + d, y - d), (x + w + d, y - d), (x + w + d, y + h - d), (x + w, y + h), (x, y + h)]
    c.poly(outline, col, STROKE, width)
    c.poly(side, darken(col, .28), None)
    c.poly(top, lighten(col, .3), None)
    c.d.line(c.P([(x + w, y), (x + w, y + h)]), fill=rgba(darken(col, .45)), width=c.W(2))


def _limb(c: Canvas, p0, p1, w, col):
    """Blocky limb: a rotated rectangle from p0 to p1 with dark outline."""
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0) or 1
    nx, ny = -(y1 - y0) / L * w / 2, (x1 - x0) / L * w / 2
    c.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], col, STROKE, 5)
    c.poly([(x0 + nx * .2, y0 + ny * .2), (x1 + nx * .2, y1 + ny * .2), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)],
           darken(col, .15), None)


def character(c: Canvas, shirt=(255, 95, 70), pants=(40, 120, 220), hat=(40, 190, 245), pose="dig",
              blade=(205, 215, 230), handle=(170, 105, 50), grip=(255, 95, 70)):
    """Blocky cartoon avatar in a 200x200 design box. pose: "dig" (holding a shovel on the right),
    "cheer" (both arms up) or "stand"."""
    if pose == "dig":
        # shovel behind the front arm: grip top-right, blade planted bottom-right
        c.line([(186, 52), (158, 160)], STROKE, 16)
        c.line([(186, 52), (158, 160)], handle, 8)
        c.line([(176, 40), (198, 50)], STROKE, 18)
        c.line([(176, 40), (198, 50)], grip, 10)
        c.poly([(140, 150), (178, 160), (176, 186), (152, 199), (134, 182)], blade, STROKE, 5)
        c.poly([(142, 156), (160, 160), (152, 194), (138, 180)], lighten(blade, .5), None)
        _limb(c, (76, 100), (58, 140), 18, SKIN)           # back arm hangs
    # legs
    box3d(c, 72, 142, 27, 50, darken(pants, .1), 8)
    box3d(c, 101, 142, 27, 50, pants, 8)
    if pose == "cheer":
        _limb(c, (74, 100), (40, 52), 20, SKIN)
    # torso
    box3d(c, 66, 92, 64, 54, shirt, 10)
    c.poly([(84, 92), (112, 92), (98, 108)], lighten(shirt, .6), None)
    c.rrect((70, 126, 126, 134), 2, darken(shirt, .25), None)
    # head (classic big block head)
    box3d(c, 64, 30, 66, 60, SKIN, 10)
    c.ellipse((80, 50, 92, 66), STROKE)
    c.ellipse((102, 50, 114, 66), STROKE)
    c.circle(84, 55, 3, WHITE)
    c.circle(106, 55, 3, WHITE)
    c.d.chord(c.B((82, 62, 112, 84)), 0, 180, fill=rgba(STROKE))
    c.d.chord(c.B((88, 72, 106, 83)), 0, 180, fill=rgba((255, 110, 120)))
    c.ellipse((68, 66, 80, 73), (255, 120, 90, 140))
    c.ellipse((114, 66, 126, 73), (255, 120, 90, 140))
    # bucket hat
    c.poly([(60, 34), (138, 34), (132, 20), (126, 8), (72, 8), (66, 20)], hat, STROKE, 5)
    c.rrect((68, 18, 132, 26), 3, WHITE, None)
    c.poly([(54, 34), (146, 34), (152, 42), (48, 42)], darken(hat, .2), STROKE, 4)
    if pose == "dig":
        _limb(c, (128, 100), (168, 92), 18, SKIN)          # front arm to the handle
        c.circle(172, 92, 10, SKIN, STROKE, 4)
        _limb(c, (122, 116), (158, 132), 16, SKIN)
        c.circle(162, 134, 9, SKIN, STROKE, 4)
    elif pose == "cheer":
        _limb(c, (126, 100), (160, 50), 20, SKIN)
        c.circle(162, 44, 12, SKIN, STROKE, 4)
        c.circle(38, 46, 12, SKIN, STROKE, 4)
    else:
        _limb(c, (128, 100), (138, 140), 18, SKIN)
        _limb(c, (70, 100), (58, 140), 18, SKIN)


def big_shovel(c: Canvas, blade=(205, 215, 230), handle=(170, 105, 50), grip=(255, 95, 70), glow=False):
    """Diagonal shovel in a 200 box, blade bottom-left, grip top-right."""
    c.line([(150, 30), (62, 130)], STROKE, 24)
    c.line([(150, 30), (62, 130)], handle, 13)
    c.line([(140, 44), (90, 100)], lighten(handle, .3), 4)
    # T grip
    c.line([(134, 14), (174, 48)], STROKE, 26)
    c.line([(134, 14), (174, 48)], grip, 15)
    # blade
    blade_pts = [(70, 112), (90, 132), (66, 182), (30, 194), (14, 182), (8, 150), (36, 118)]
    c.poly(blade_pts, blade, STROKE, 6)
    c.poly([(36, 124), (60, 120), (34, 178), (18, 170), (14, 152)], lighten(blade, .5), None)
    c.poly([(62, 106), (80, 124), (70, 136), (52, 118)], darken(blade, .25), STROKE, 4)


# ---------------------------------------------------------------- title text
def title_text(text: str, size: int, fill_top=(255, 245, 110), fill_bot=(255, 150, 20), stroke=STROKE,
               stroke_w=None, shadow=True, kind="title", outer=None, spacing=0, rot=0.0,
               shadow_off=None) -> Image.Image:
    """Chunky cartoon title rendered at SS resolution, returned as RGBA sprite."""
    s = SS
    f = font(kind, int(size * s))
    sw = int((stroke_w if stroke_w is not None else size * 0.11) * s)
    ow = int((outer or 0) * s)
    lines = text.split("\n")
    tmp = ImageDraw.Draw(Image.new("L", (10, 10)))
    bbs = [tmp.textbbox((0, 0), ln, font=f, stroke_width=sw) for ln in lines]
    lh = int(size * s * 1.06)
    tw = max(b[2] - b[0] for b in bbs)
    pad = sw + ow + int(size * s * 0.25)
    W = tw + pad * 2
    H = lh * len(lines) + pad * 2 + int(size * s * 0.15)

    def mask(extra_stroke):
        m = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(m)
        for i, ln in enumerate(lines):
            d.text((W / 2, pad + lh * i + lh / 2), ln, font=f, anchor="mm", fill=255,
                   stroke_width=extra_stroke, stroke_fill=255)
        return m

    m_fill = mask(0)
    m_stroke = mask(sw)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if shadow:
        so = shadow_off if shadow_off is not None else int(size * s * 0.08)
        m_sh = mask(sw + ow)
        shl = Image.new("RGBA", (W, H), (20, 10, 40, 150))
        shl.putalpha(m_sh.point(lambda v: int(v * 0.6)))
        shl = ImageChops.offset(shl, int(so * 0.4), so)
        out.alpha_composite(shl.filter(ImageFilter.GaussianBlur(size * s * 0.02)))
    if ow:
        m_out = mask(sw + ow)
        ol = Image.new("RGBA", (W, H), rgba(outer_color := WHITE))
        ol.putalpha(m_out)
        out.alpha_composite(ol)
    # stroke with a 3D "extrusion" (stacked offset copies)
    depth = int(size * s * 0.06)
    for k in range(depth, -1, -max(1, s)):
        st = Image.new("RGBA", (W, H), rgba(stroke))
        st.putalpha(m_stroke)
        out.alpha_composite(ImageChops.offset(st, 0, k))
    # gradient fill per line (covers the full line box so nothing is left unfilled)
    grad = Image.new("RGBA", (W, H), rgba(fill_bot))
    grad.paste(vgradient(W, pad + 1, [(0, fill_top), (1, fill_top)]), (0, 0))
    for i in range(len(lines)):
        y0 = pad + lh * i
        g = vgradient(W, lh, [(0, fill_top), (0.3, fill_top), (0.65, mix(fill_top, fill_bot, .5)), (0.9, fill_bot),
                              (1, fill_bot)])
        grad.paste(g, (0, y0))
    grad.putalpha(m_fill)
    out.alpha_composite(grad)
    # glossy top highlight inside letters
    hl = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(hl)
    for i in range(len(lines)):
        y0 = pad + lh * i
        hd.rectangle([0, y0, W, y0 + int(lh * 0.42)], fill=90)
    hl = ImageChops.multiply(hl, m_fill.filter(ImageFilter.MinFilter(max(3, (int(size * s * 0.06) // 2) * 2 + 1))))
    wl = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    wl.putalpha(hl)
    out.alpha_composite(wl)
    out = out.crop(out.getbbox())
    if rot:
        out = out.rotate(rot, resample=Image.BICUBIC, expand=True)
    return out


def pill_label(text, size, bg=(255, 70, 110), fg=WHITE, kind="title", stroke_w=None, rot=0.0) -> Image.Image:
    """Rounded badge/sticker with text (e.g. "NEW!", "UPDATE 1", "MYTHIC")."""
    s = SS
    f = font(kind, int(size * s))
    d = ImageDraw.Draw(Image.new("L", (10, 10)))
    bb = d.textbbox((0, 0), text, font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    padx, pady = int(size * s * 0.55), int(size * s * 0.35)
    ow = int(size * s * 0.1)
    W, H = tw + padx * 2 + ow * 2, th + pady * 2 + ow * 2 + int(size * s * 0.12)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(im)
    r = (H - ow * 2) // 2
    dd.rounded_rectangle([0, int(size * s * 0.1), W - 1, H - 1], radius=r + ow, fill=rgba(STROKE))
    dd.rounded_rectangle([0, 0, W - 1, H - 1 - int(size * s * 0.1)], radius=r + ow, fill=rgba(STROKE))
    dd.rounded_rectangle([ow, ow, W - 1 - ow, H - 1 - ow - int(size * s * 0.1)], radius=r, fill=rgba(bg))
    dd.rounded_rectangle([ow + r // 2, ow + int(pady * 0.25), W - 1 - ow - r // 2, ow + (H - ow * 2) // 2 - 8],
                         radius=r // 2, fill=rgba(lighten(bg, .25)))
    sw = int((stroke_w if stroke_w is not None else size * 0.08) * s)
    dd.text((W / 2, (H - int(size * s * 0.1)) / 2), text, font=f, anchor="mm", fill=rgba(fg),
            stroke_width=sw, stroke_fill=rgba(STROKE))
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    return im


# ---------------------------------------------------------------- scenery
def cloud(c: Canvas, x, y, w, alpha=255):
    h = w * 0.45
    blobs = [(x + w * .2, y + h * .6, h * .45), (x + w * .42, y + h * .38, h * .6), (x + w * .68, y + h * .48, h * .5),
             (x + w * .85, y + h * .68, h * .33), (x + w * .5, y + h * .75, h * .4)]
    for bx, by, r in blobs:
        c.circle(bx, by, r + 5, (120, 190, 235, alpha))
    for bx, by, r in blobs:
        c.circle(bx, by, r, (255, 255, 255, alpha))
    c.ellipse((x + w * .08, y + h * .78, x + w * .95, y + h * 1.02), (215, 235, 250, alpha))


def sunburst(c: Canvas, cx, cy, n, r, col, alpha=60, offset=0.0):
    for i in range(n):
        a0 = offset + i * 2 * math.pi / n
        a1 = a0 + math.pi / n
        c.poly([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)),
                (cx + r * math.cos(a1), cy + r * math.sin(a1))], (*col, alpha), None)


def sun(c: Canvas, cx, cy, r):
    c.glow(cx, cy, r * 3.2, (255, 250, 200), 200, 1.4)
    sunburst(c, cx, cy, 14, r * 2.6, (255, 255, 220), 55)
    c.circle(cx, cy, r, (255, 230, 90), (255, 170, 40), 6)
    c.circle(cx - r * .25, cy - r * .25, r * .45, (255, 250, 200))


def _bez(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


def leaf(c: Canvas, base, ctrl, tip, width, col):
    up, dn = [], []
    n = 14
    for i in range(n + 1):
        t = i / n
        x, y = _bez(base, ctrl, tip, t)
        x2, y2 = _bez(base, ctrl, tip, min(1, t + 0.01))
        dx, dy = x2 - x, y2 - y
        L = math.hypot(dx, dy) or 1
        w = width * math.sin(math.pi * min(1, t * 1.15)) * (1 - t * 0.35)
        # serrated lower edge
        w2 = w * (0.75 if i % 2 else 1.0)
        up.append((x - dy / L * w, y + dx / L * w))
        dn.append((x + dy / L * w2, y - dx / L * w2))
    c.poly(up + dn[::-1], col, STROKE, 5)
    mid = [_bez(base, ctrl, tip, i / n) for i in range(n + 1)]
    c.line(mid[:-2], darken(col, .22), 3)
    c.poly(up[:n // 2] + mid[:n // 2][::-1], lighten(col, .18), None)


def palm(c: Canvas, x, y, h, lean=1, rng=None):
    """Palm tree with base at (x, y); lean +1 bends right, -1 left."""
    pts = []
    for i in range(10):
        t = i / 9
        pts.append((x + lean * (math.sin(t * 1.5) * h * 0.25), y - t * h))
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        wdt = h * (0.09 - 0.035 * i / 9)
        c.line([(x0, y0), (x1, y1)], (180, 120, 62) if i % 2 else (160, 104, 52), wdt, STROKE, 5)
    tx, ty = pts[-1]
    greens = [(60, 185, 90), (85, 215, 110), (45, 160, 80)]
    L = h * 0.62
    specs = [(-1.0, -0.15, 0), (1.0, -0.15, 1), (-0.75, 0.45, 2), (0.8, 0.45, 2), (-0.25, -0.55, 1),
             (0.35, -0.5, 0), (-1.05, 0.15, 1), (1.05, 0.2, 0)]
    for k, (dx, dy, ci) in enumerate(specs):
        tip = (tx + dx * L, ty + dy * L + L * 0.55)
        ctrl = (tx + dx * L * 0.55, ty + dy * L - L * 0.25)
        leaf(c, (tx, ty), ctrl, tip, h * 0.075, greens[ci])
    for dx in (-1, 1, 0):
        c.circle(tx + dx * h * 0.045, ty + h * 0.05 + (h * 0.03 if dx == 0 else 0), h * 0.048, (140, 90, 50),
                 STROKE, 4)


def sand_spray(c: Canvas, x0, y0, rng: random.Random, n=40, dirx=1, height=220, reach=320, col=SAND,
               size=(5, 15)):
    """Fountain of sand chunks thrown out of a hole along parabolic arcs."""
    for i in range(n):
        t = rng.uniform(0.08, 1.0)
        v = rng.uniform(0.75, 1.15)
        x = x0 + dirx * reach * t * v
        y = y0 - height * v * (4 * t * (1 - t)) - rng.uniform(-15, 15)
        x += rng.uniform(-18, 18)
        r = (size[1] - (size[1] - size[0]) * t) * rng.uniform(.8, 1.1)
        k = rng.uniform(0, 6.28)
        pts = [(x + r * math.cos(a + k) * rng.uniform(.75, 1.1), y + r * math.sin(a + k) * rng.uniform(.75, 1.1))
               for a in np.linspace(0, 2 * math.pi, 7, endpoint=False)]
        c.poly(pts, mix(col, SAND_DARK, rng.uniform(0, .45)), STROKE, max(2, r * 0.25))
    for i in range(n):
        t = rng.uniform(0.05, 1.0)
        x = x0 + dirx * reach * t * rng.uniform(.6, 1.2)
        y = y0 - height * (4 * t * (1 - t)) * rng.uniform(.6, 1.2)
        r = rng.uniform(2, 4)
        c.circle(x, y, r, lighten(col, .3))


def sand_particles(c: Canvas, cx, cy, n, spread, rng: random.Random, col=SAND, up=True, size=(6, 16)):
    for _ in range(n):
        a = rng.uniform(-math.pi * 0.95, -math.pi * 0.05) if up else rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(0.15, 1.0) * spread
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist * 0.8
        r = rng.uniform(*size)
        pts = [(x + r * math.cos(t) * rng.uniform(.7, 1.1), y + r * math.sin(t) * rng.uniform(.7, 1.1))
               for t in np.linspace(0, 2 * math.pi, 6, endpoint=False) + rng.uniform(0, 1)]
        cc = mix(col, SAND_DARK, rng.uniform(0, .5))
        c.poly(pts, cc, STROKE, max(2, r * 0.22))


def sparkle(c: Canvas, x, y, r, col=WHITE, alpha=255):
    pts = []
    for i in range(8):
        a = i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.25
        pts.append((x + rr * math.cos(a - math.pi / 2), y + rr * math.sin(a - math.pi / 2)))
    c.poly(pts, (*col, alpha), None)


def wavy(x0, x1, y, amp, freq, phase, step=8):
    return [(x, y + amp * math.sin(x * freq + phase) + amp * 0.4 * math.sin(x * freq * 2.7 + phase * 1.7))
            for x in np.arange(x0, x1 + step, step)]


def strata(c: Canvas, x0, x1, y_top, y_bot, layers=LAYERS, rng=None, speckle=True, line_w=4, min_h=None,
           weights=None):
    """Draw stacked layer bands between y_top and y_bot. Returns list of (y_start, y_end) per layer."""
    rng = rng or random.Random(3)
    n = len(layers)
    ws = weights or [1.0] * n
    total = sum(ws)
    ys = [y_top]
    for wv in ws:
        ys.append(ys[-1] + (y_bot - y_top) * wv / total)
    bounds = []
    for i, (name, col, *_rest) in enumerate(layers):
        top = wavy(x0 - 20, x1 + 20, ys[i], 0 if i == 0 else 7, 0.012 + 0.002 * (i % 3), i * 1.7)
        poly = top + [(x1 + 20, y_bot + 400), (x0 - 20, y_bot + 400)]
        c.poly(poly, col, None)
        # shading: lighter band near top
        hl = wavy(x0 - 20, x1 + 20, ys[i] + (ys[i + 1] - ys[i]) * 0.3, 0 if i == 0 else 7,
                  0.012 + 0.002 * (i % 3), i * 1.7)
        c.d.polygon(c.P(top + hl[::-1]), fill=(*lighten(col, .18), 255))
        if speckle:
            hh = ys[i + 1] - ys[i]
            for _ in range(int((x1 - x0) * hh / 900)):
                x = rng.uniform(x0, x1)
                y = rng.uniform(ys[i] + 8, ys[i + 1] - 4)
                r = rng.uniform(2, 6)
                cc = darken(col, .18) if rng.random() < .7 else lighten(col, .3)
                c.ellipse((x - r * 1.4, y - r, x + r * 1.4, y + r), cc)
        if i > 0:
            c.line(top, STROKE, line_w)
        bounds.append((ys[i], ys[i + 1]))
    return bounds


def save(img: Image.Image, rel: str):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.convert("RGB").save(p, optimize=True) if not rel.endswith("badge") else img.save(p)
    print("wrote", os.path.relpath(p, REPO), img.size)
    return p


def save_rgba(img: Image.Image, rel: str):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, optimize=True)
    print("wrote", os.path.relpath(p, REPO), img.size)
    return p


def decorate_layers(c: Canvas, bounds, x0, x1, rng: random.Random, layers=LAYERS):
    """Signature details per layer so each band reads as a place, not just a colour."""
    for i, (a, b) in enumerate(bounds):
        name = layers[i][0]
        col = layers[i][1]
        hgt = b - a
        n = int((x1 - x0) / 160)
        for _ in range(n):
            x = rng.uniform(x0, x1)
            y = rng.uniform(a + hgt * 0.3, b - hgt * 0.2)
            if name == "Shell Bed":
                r = rng.uniform(6, 10)
                c.d.pieslice(c.B((x - r, y - r, x + r, y + r)), 180, 360, fill=rgba(WHITE))
                c.d.arc(c.B((x - r, y - r, x + r, y + r)), 180, 360, fill=rgba(darken(col, .3)), width=c.W(2))
            elif name in ("Magma Chamber",):
                L = rng.uniform(30, 70)
                pts = [(x, y), (x + L * .4, y + rng.uniform(-8, 8)), (x + L, y + rng.uniform(-10, 10))]
                c.line(pts, (255, 220, 60), 5)
            elif name == "Alien Hive":
                r = rng.uniform(8, 13)
                hexp = [(x + r * math.cos(k * math.pi / 3), y + r * math.sin(k * math.pi / 3)) for k in range(6)]
                c.poly(hexp, lighten(col, .35), darken(col, .3), 2)
            elif name == "Frozen Abyss":
                c.line([(x, y), (x + 14, y - 10)], WHITE, 4)
            elif name == "Crystal Caverns":
                sparkle(c, x, y, rng.uniform(6, 11), (240, 220, 255))
            elif name == "Ancient Ruins":
                c.rrect((x, y - 7, x + 34, y + 7), 2, darken(col, .12), darken(col, .35), 2)
            elif name == "Obsidian Depths":
                c.poly([(x, y - 9), (x + 7, y), (x, y + 9), (x - 7, y)], (110, 80, 160), None)
            elif name == "Bedrock":
                c.ellipse((x - 12, y - 7, x + 12, y + 7), darken(col, .25), None)


def _egg_zig(y):
    pts = [(0, y)]
    for i in range(0, 8):
        pts.append((30 + i * 20, y + (-16 if i % 2 else 10)))
    pts.append((200, y))
    return pts


def _egg_full(c: Canvas, col, spots):
    c.ellipse((30, 10, 170, 190), col)
    c.ellipse((40, 110, 160, 188), darken(col, .12))
    for (x, y, r) in ((70, 60, 14), (128, 48, 11), (130, 140, 18), (72, 150, 15), (104, 96, 9)):
        c.circle(x, y, r, spots)
    c.ellipse((52, 28, 84, 64), (255, 255, 255, 160))


def tr_egg_bottom(c: Canvas, col=(255, 215, 60), spots=(255, 150, 40)):
    _egg_full(c, col, spots)
    c.d.polygon(c.P(_egg_zig(96) + [(200, 0), (0, 0)]), fill=(0, 0, 0, 0))


def tr_egg_top(c: Canvas, col=(255, 215, 60), spots=(255, 150, 40)):
    _egg_full(c, col, spots)
    c.d.polygon(c.P(_egg_zig(96) + [(200, 200), (0, 200)]), fill=(0, 0, 0, 0))


def tr_arrow_down(c: Canvas, col=(255, 90, 60)):
    c.poly([(65, 10), (135, 10), (135, 100), (185, 100), (100, 192), (15, 100), (65, 100)], col, STROKE, 7)
    c.poly([(75, 18), (100, 18), (100, 108), (40, 108)], lighten(col, .3), None)


# ---------------------------------------------------------------- store & wave-2 badge emblems
def tr_sand_pile(c: Canvas, col=SAND):
    c.poly([(10, 175), (40, 110), (75, 70), (100, 55), (125, 70), (160, 110), (190, 175)], col, STROKE, 6)
    c.poly([(40, 175), (70, 120), (100, 95), (130, 120), (160, 175)], lighten(col, .25))
    for (x, y, r) in ((60, 150, 5), (100, 130, 6), (140, 155, 5), (85, 165, 4), (120, 100, 4)):
        c.circle(x, y, r, darken(col, .2))
    c.rrect((10, 168, 190, 188), 10, darken(col, .1), STROKE, 6)


def tr_bolt(c: Canvas, col=(255, 230, 60)):
    pts = [(120, 5), (40, 110), (95, 110), (70, 195), (165, 75), (108, 75), (140, 5)]
    c.poly(pts, col, STROKE, 7)
    c.poly([(118, 20), (62, 100), (85, 100)], lighten(col, .5))


def tr_backpack(c: Canvas, body=(255, 120, 60), pocket=(255, 190, 70)):
    c.d.arc(c.B((60, 5, 140, 75)), 180, 360, fill=rgba(STROKE), width=c.W(24))
    c.d.arc(c.B((60, 5, 140, 75)), 180, 360, fill=rgba(darken(body, .25)), width=c.W(12))
    c.rrect((30, 40, 170, 190), 40, body, STROKE, 7)
    c.rrect((50, 110, 150, 175), 18, pocket, STROKE, 5)
    c.line([(60, 128), (140, 128)], STROKE, 5)
    c.rrect((90, 120, 110, 140), 5, GOLD, STROKE, 3)
    shine(c, (48, 52, 95, 85), 140)


def tr_book(c: Canvas, cover=(70, 150, 255), pages=(255, 248, 225)):
    c.rrect((25, 30, 180, 185), 16, darken(cover, .3), STROKE, 7)
    c.rrect((35, 40, 178, 172), 10, pages, STROKE, 4)
    c.rrect((20, 20, 165, 172), 16, cover, STROKE, 7)
    c.rrect((32, 20, 48, 172), 4, darken(cover, .2))
    c.circle(105, 92, 38, GOLD, STROKE, 5)
    c.poly([(105, 66), (114, 85), (134, 88), (119, 101), (123, 121), (105, 111), (87, 121), (91, 101),
            (76, 88), (96, 85)], WHITE)
    shine(c, (60, 30, 140, 50), 120)


def tr_column(c: Canvas, stone=(225, 205, 160)):
    c.rrect((30, 20, 170, 50), 8, stone, STROKE, 6)
    c.rrect((45, 50, 155, 165), 4, lighten(stone, .1), STROKE, 6)
    for x in (68, 92, 116, 140):
        c.line([(x - 6, 58), (x - 6, 158)], darken(stone, .18), 7)
    c.poly([(120, 50), (135, 95), (125, 120), (140, 165), (155, 165), (155, 50)], darken(stone, .12))
    c.rrect((20, 165, 180, 192), 8, darken(stone, .1), STROKE, 6)
    c.line([(50, 50), (75, 90), (65, 120)], STROKE, 4)


def tr_calendar(c: Canvas, head=(255, 90, 80), num="7"):
    c.rrect((20, 30, 180, 190), 22, WHITE, STROKE, 7)
    c.rrect((20, 30, 180, 80), 22, head, None)
    c.rrect((20, 58, 180, 80), 0, head, None)
    for x in (60, 140):
        c.rrect((x - 9, 10, x + 9, 52), 9, (200, 205, 220), STROKE, 5)
    c.d.text((100 * c.s, 138 * c.s), num, font=font("title", int(95 * c.s)), anchor="mm", fill=rgba(head),
             stroke_width=int(6 * c.s), stroke_fill=rgba(STROKE))


def tr_hourglass(c: Canvas, glass=(200, 240, 255), wood=(170, 105, 50)):
    c.poly([(45, 30), (155, 30), (110, 100), (155, 170), (45, 170), (90, 100)], glass, STROKE, 6)
    c.poly([(70, 140), (130, 140), (150, 168), (50, 168)], SAND)
    c.poly([(62, 45), (138, 45), (104, 88), (96, 88)], SAND)
    c.line([(100, 88), (100, 140)], SAND, 5)
    c.rrect((25, 12, 175, 34), 8, wood, STROKE, 6)
    c.rrect((25, 166, 175, 188), 8, wood, STROKE, 6)


def tr_gear(c: Canvas, col=(150, 165, 190)):
    teeth = []
    for i in range(16):
        a = i * math.pi / 8
        r = 92 if i % 2 == 0 else 72
        for da in (-0.17, 0.17):
            teeth.append((100 + r * math.cos(a + da), 100 + r * math.sin(a + da)))
    c.poly(teeth, col, STROKE, 6)
    c.circle(100, 100, 30, darken(col, .3), STROKE, 6)


def tr_fast_forward(c: Canvas, col=(120, 255, 200)):
    c.poly([(15, 30), (100, 100), (15, 170)], col, STROKE, 7)
    c.poly([(95, 30), (185, 100), (95, 170)], col, STROKE, 7)
    c.poly([(30, 55), (70, 88), (30, 90)], lighten(col, .5))
