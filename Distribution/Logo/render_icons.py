#!/usr/bin/env python3
"""Render Fridge app-icon concepts (1024x1024, full-bleed, opaque).

Usage: python3 Distribution/Logo/render_icons.py
Draws at 4x and downsamples with LANCZOS for anti-aliasing. Requires Pillow.
"""
import math
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4                # supersample factor
N = 1024 * S         # canvas size while drawing


def p(v):
    """Design units (0..1024) -> canvas pixels."""
    return v * S


def canvas(bg):
    img = Image.new("RGB", (N, N), bg)
    return img, ImageDraw.Draw(img)


def stroke_path(d, pts, width, fill):
    """Thick polyline with round caps/joins (pts in design units)."""
    r = p(width) / 2
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.line([p(x0), p(y0), p(x1), p(y1)], fill=fill, width=int(p(width)))
    for x, y in pts:
        d.ellipse([p(x) - r, p(y) - r, p(x) + r, p(y) + r], fill=fill)


def steam(d, x, y_bottom, height, amp, width, fill):
    pts = []
    steps = 60
    for i in range(steps + 1):
        t = i / steps
        pts.append((x + amp * math.sin(t * 2 * math.pi), y_bottom - t * height))
    stroke_path(d, pts, width, fill)


def leaf(img, cx, cy, length, width, angle_deg, fill, vein):
    """Almond-shaped leaf drawn on its own layer then rotated into place."""
    L, W = int(p(length)), int(p(width))
    layer = Image.new("RGBA", (L, L), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    pts = []
    for i in range(101):
        t = i / 100
        x = t * L
        y = L / 2 - math.sin(t * math.pi) ** 0.9 * W / 2
        pts.append((x, y))
    for i in range(100, -1, -1):
        t = i / 100
        x = t * L
        y = L / 2 + math.sin(t * math.pi) ** 0.9 * W / 2
        pts.append((x, y))
    ld.polygon(pts, fill=fill)
    if vein:
        ld.line([L * 0.08, L / 2, L * 0.8, L / 2], fill=vein, width=int(p(width * 0.09)))
    layer = layer.rotate(angle_deg, resample=Image.BICUBIC, expand=True)
    # anchor = leaf base (left-middle before rotation)
    a = math.radians(angle_deg)
    lw, lh = layer.size
    bx = lw / 2 + (-L / 2) * math.cos(a)
    by = lh / 2 - (-L / 2) * math.sin(a)
    img.paste(layer, (int(p(cx) - bx), int(p(cy) - by)), layer)


def save(img, n):
    out = img.resize((1024, 1024), Image.LANCZOS).convert("RGB")
    path = os.path.join(HERE, f"concept-{n}.png")
    out.save(path, optimize=True)
    out.resize((60, 60), Image.LANCZOS).save(os.path.join(HERE, f"concept-{n}@60.png"))
    print("wrote", path)


WHITE = (255, 255, 255)
CREAM = (255, 250, 240)


# 1 — Friendly fridge with a sprouting leaf (fresh green)
def concept1():
    bg = (38, 166, 110)
    img, d = canvas(bg)
    shadow = (27, 136, 89)
    x0, y0, x1, y1 = 322, 272, 702, 872
    d.rounded_rectangle([p(x0 + 22), p(y0 + 22), p(x1 + 22), p(y1 + 22)], radius=p(80), fill=shadow)
    d.rounded_rectangle([p(x0), p(y0), p(x1), p(y1)], radius=p(80), fill=CREAM)
    # freezer / fridge split
    d.rectangle([p(x0), p(462), p(x1), p(482)], fill=bg)
    # handles
    hc = (196, 204, 198)
    d.rounded_rectangle([p(382), p(340), p(410), p(420)], radius=p(14), fill=hc)
    d.rounded_rectangle([p(382), p(530), p(410), p(680)], radius=p(14), fill=hc)
    # sprout: stem + two leaves, rooted on the fridge top
    stem = (22, 112, 72)
    stroke_path(d, [(560, 276), (560, 230), (566, 196)], 18, stem)
    leaf(img, 566, 204, 200, 104, 35, (150, 222, 96), (104, 184, 66))
    leaf(img, 560, 230, 150, 80, 150, (178, 232, 118), (126, 196, 84))
    save(img, 1)


# 2 — Top-down frying pan with a sunny-side egg (warm tomato)
def concept2():
    bg = (242, 96, 64)
    img, d = canvas(bg)
    pan = (44, 48, 58)
    rim = (72, 78, 92)
    ang = math.radians(45)
    cx, cy, R = 440, 440, 290
    hx0, hy0 = cx + (R - 20) * math.cos(ang), cy + (R - 20) * math.sin(ang)
    hx1, hy1 = cx + (R + 210) * math.cos(ang), cy + (R + 210) * math.sin(ang)
    stroke_path(d, [(hx0, hy0), (hx1, hy1)], 84, pan)
    d.ellipse([p(cx - R), p(cy - R), p(cx + R), p(cy + R)], fill=rim)
    d.ellipse([p(cx - R + 32), p(cy - R + 32), p(cx + R - 32), p(cy + R - 32)], fill=pan)
    blobs = [(-40, -20, 145), (60, 30, 125), (-10, 80, 115), (-85, 50, 100), (50, -65, 105)]
    for dx, dy, r in blobs:
        d.ellipse([p(cx + dx - r), p(cy + dy - r), p(cx + dx + r), p(cy + dy + r)], fill=CREAM)
    yr = 76
    d.ellipse([p(cx - yr), p(cy - yr), p(cx + yr), p(cy + yr)], fill=(255, 180, 30))
    d.ellipse([p(cx - 40), p(cy - 44), p(cx - 12), p(cy - 16)], fill=(255, 225, 140))
    for x, y in [(cx + 150, cy - 135), (cx - 160, cy - 105), (cx + 115, cy + 150)]:
        d.ellipse([p(x - 15), p(y - 15), p(x + 15), p(y + 15)], fill=(120, 200, 90))
    save(img, 2)


# 3 — Bowl + chopsticks inside a rounded fridge outline (deep blue)
def concept3():
    bg = (34, 84, 186)
    img, d = canvas(bg)
    line = CREAM
    d.rounded_rectangle([p(252), p(152), p(772), p(872)], radius=p(116), outline=line, width=int(p(46)))
    d.rounded_rectangle([p(310), p(240), p(338), p(380)], radius=p(14), fill=line)
    # chopsticks resting in the bowl, pointing up-right
    chop = (255, 196, 90)
    stroke_path(d, [(560, 590), (700, 330)], 26, chop)
    stroke_path(d, [(600, 596), (738, 360)], 26, chop)
    # rice dome
    top = 610
    d.chord([p(376), p(top - 100), p(648), p(top + 100)], 180, 360, fill=WHITE)
    # bowl body + rim + foot
    d.pieslice([p(352), p(top - 180), p(672), p(top + 180)], 0, 180, fill=line)
    d.rounded_rectangle([p(338), p(top - 16), p(686), p(top + 16)], radius=p(16), fill=line)
    d.rounded_rectangle([p(456), p(top + 160), p(568), p(top + 198)], radius=p(12), fill=line)
    # steam on the left, clear of the chopsticks
    for x in (440, 514):
        steam(d, x, 470, 170, 18, 24, (176, 204, 255))
    save(img, 3)


# 4 — Bold "F" monogram whose top bar becomes a fork (sunny amber)
def concept4():
    bg = (255, 184, 28)
    img, d = canvas(bg)
    ink = (40, 44, 60)
    d.rounded_rectangle([p(330), p(220), p(474), p(830)], radius=p(44), fill=ink)       # stem
    d.rounded_rectangle([p(330), p(220), p(744), p(384)], radius=p(44), fill=ink)       # top bar
    # cut two slots from the right to form three rounded fork tines
    tine_h, slot = (164 - 2 * 26) / 3, 26
    ys = [220 + i * (tine_h + slot) for i in range(3)]
    d.rectangle([p(560), p(220), p(760), p(384)], fill=bg)
    for y in ys:
        d.rounded_rectangle([p(520), p(y), p(744), p(y + tine_h)], radius=p(tine_h / 2), fill=ink)
    d.rectangle([p(474), p(220), p(572), p(384)], fill=ink)                              # solid neck
    d.rounded_rectangle([p(330), p(500), p(640), p(636)], radius=p(44), fill=ink)       # middle bar
    save(img, 4)


if __name__ == "__main__":
    concept1(); concept2(); concept3(); concept4()
