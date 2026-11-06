"""Generate Awaken's designed effect sheets (round 43, docs/features/designed-fx.md).

    python tools/vfx_gen/gen_designed.py [name ...] [--preview=<dir>]

Writes assets/vfx/designed/<name>.png (RGBA: tone, erode order, boil, cover; see vfxlib.py). With --preview it
also writes <dir>/<name>_preview.png: the sheet through the element palette on the floor colour, at erode 0 / 0.4
/ 0.7, so a sheet can be judged without Godot. Every sheet is seeded, so a rerun gives the same bytes.

Each SHEETS entry: (draw function, frame px, columns, frame count, preview palette, erode mode). The frame
count and fps the game plays them at live in scripts/designed_fx.gd (SHEETS); keep the two in step.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, catmull, ellipse_mask, erode_field, fbm, grow, jag_path,  # noqa: E402
                    pack, poly_mask, preview, rng, save, shrink, star, stroke, wobble_ring)

from air_sheets import AIR_SHEETS  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def ease_out(t):
    return 1 - (1 - t) ** 3


def lerp(a, b, t):
    return a + (b - a) * t


def polar(c, r, a):
    return (c + math.cos(a) * r, c + math.sin(a) * r)


# --- 1. hit spark: the every-hit impact star ------------------------------------------------------------------
# Shape language (neutral hit, takes the blow's palette): a hard, lopsided star whose two long spikes run along
# a diagonal (the read of a blow, not a flower), hollowing out from the middle on frame 3 and breaking into loose
# spikes that fly out. Frame 0 is the anticipation: a small pinched glint. Frame 1 the peak, a hot white core.

def hit_spark(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(11)
    k = 9
    base = np.array([1.0, 0.55, 0.7, 0.5, 0.95, 0.55, 0.68, 0.5, 0.62])  # two long tips (0 and 4) on a diagonal
    rot = -0.5
    if i == 0:  # anticipation: a squeezed four point glint, hot only
        tips = [f.u(0.42), f.u(0.12), f.u(0.42), f.u(0.12)]
        f.poly(star(c, c, tips, f.u(0.06), rot=rot + 0.3, bow=0.45), HOT, ink=2.0)
        f.fill(ellipse_mask(c, c, f.u(0.07), f.u(0.07), f.S), HOT)
        return f.finish()
    grow_k = [0, 1.0, 1.08, 1.12, 1.15, 1.17, 1.18, 1.19][i]
    r_out = f.u(0.86) * grow_k
    if i <= 2:
        tips = list(base * r_out)
        outer = star(c, c, tips, r_out * 0.3, rot=rot, bow=0.42)
        m = f.poly(outer, BODY, ink=3.0)
        # light star inside, offset up-left (the lit side), hot core
        inner = star(c - f.u(0.02), c - f.u(0.03), list(base * r_out * 0.62), r_out * 0.2, rot=rot + 0.05, bow=0.45)
        f.poly(inner, LIGHT)
        f.fill(poly_mask([star(c, c, list(base * r_out * 0.33), r_out * 0.12, rot=rot + 0.1, bow=0.4)], f.S), HOT)
        if i == 1:  # the peak frame: a fat hot core disc
            f.fill(ellipse_mask(c, c, f.u(0.2), f.u(0.2), f.S), HOT)
        else:  # frame 2: the core punches out to a ring, ink crack lines across it
            hole = wobble_ring(c, c, f.u(0.13), 5, amp=0.15)
            f.poly(hole, INK)
            f.cut(poly_mask([wobble_ring(c, c, f.u(0.09), 5, amp=0.2)], f.S))
        return f.finish()
    # frames 3..7: the hole eats out from the middle, so the star's own spikes are what is left, then they thin
    t = (i - 3) / (n - 4)
    tips = list(base * r_out * lerp(1.02, 1.1, t))
    outer = star(c, c, tips, r_out * lerp(0.3, 0.22, t), rot=rot, bow=lerp(0.45, 0.6, t))
    m = poly_mask([outer], f.S)
    f.fill(m, BODY if t < 0.5 else LIGHT, ink=lerp(3.0, 2.0, t))
    inner = star(c, c, list(base * r_out * 0.7), r_out * 0.2, rot=rot + 0.05, bow=0.45)
    if t < 0.6:
        f.fill(poly_mask([inner], f.S) * m, LIGHT)
    hole_r = r_out * lerp(0.17, 0.7, t ** 1.2)
    hole = poly_mask([wobble_ring(c, c, hole_r, 5 + i, amp=0.18, lumps=(3, 5, 9))], f.S)
    rim = np.clip(grow(hole, 3.0 * 4) - hole, 0, 1) * m
    f.fill(rim, INK)
    f.cut(hole)
    for s_ in range(3):  # three hot droplets thrown off the long spikes
        a = rot + [0.0, math.pi, 1.4][s_] + 0.25
        rr = r_out * lerp(0.95, 1.2, ease_out(t))
        dr = f.u(lerp(0.055, 0.025, t))
        x, y = polar(c, rr, a)
        f.fill(ellipse_mask(x, y, dr, dr, f.S), HOT, ink=1.5)
    return f.finish()


# --- 2. impact streaks: the directional half of a hit (points along +x, rotated in game) ----------------------
# Thick wedge strokes and inked droplets thrown along the blow; they shoot out then snap thin.

def impact_streaks(i, n, size):
    # Manga speed wedges: long, needle-thin at both ends, fattest a third of the way from the front; they shoot out
    # from the hit (left) along +x, then the backs catch up with the fronts and they snap to slivers.
    f = Frame(size)
    c = f.c
    rows = [(-0.16, 1.0, 0.12), (0.04, 0.8, 0.15), (0.22, 0.92, 0.1), (-0.42, 0.55, 0.08), (0.48, 0.5, 0.07)]  # (angle, length, width)
    t = i / (n - 1)
    front = lerp(0.45, 1.0, ease_out(min(1.0, t * 2.2)))
    back = lerp(-0.35, 0.92, t ** 1.4)
    for k, (dy, ln, w) in enumerate(rows):
        ox, oy = c - f.u(0.75), c  # they radiate from a point behind the hit, in a fan
        r0 = f.u(0.75 + back * ln * 0.95)
        r1 = f.u(0.75 + front * ln * 0.95)
        if r1 - r0 < f.u(0.06):
            continue
        a = dy * 0.75
        p = [(ox + math.cos(a) * lerp(r0, r1, q), oy + math.sin(a) * lerp(r0, r1, q)) for q in np.linspace(0, 1, 12)]
        x0, x1, y, slope = 0, 0, 0, 0
        ww = f.u(w * lerp(1.0, 0.5, t))
        prof = lambda q, ww=ww: ww * (min(1.0, q / 0.68) ** 0.8) * (min(1.0, (1 - q) / 0.32) ** 0.9) + 0.5
        f.poly(stroke(p, prof, cap=False), LIGHT if k in (0, 2) else BODY, ink=2.0)
        if k in (0, 1, 2) and t < 0.75:  # a hot core line down the fat part
            core = [(ox + math.cos(a) * lerp(r0, r1, q), oy + math.sin(a) * lerp(r0, r1, q)) for q in np.linspace(0.35, 0.9, 8)]
            f.poly(stroke(core, lambda q, ww=ww: ww * 0.3 * math.sin(q * math.pi) + 0.3, cap=False), HOT)
    return f.finish()


# --- 3. slash strip: a brush stroke laid along the swing arc (ribbon texture, frames = boiling variants) --------
# Strip frames are wide: x = along the arc (0 tail -> 1 head), y = across (0 inner edge -> 1 outer blade edge).
# A blunt fat head with a hot blade line, tapering to a dry-brush tail split into bristle streaks.

def slash_strip(i, n, size):
    W, H = size * 4, size  # drawn on a square canvas, then squashed: the Frame is square, so draw at 4:1 scale
    f = Frame(size * 2)
    S = f.S
    g = rng(31 + i)
    # the canvas is S x S; we draw into a strip of S x S/4 at the top-middle and crop later
    h = S / 4.0
    y0 = (S - h) / 2
    def P(u, v):
        return (u * S, y0 + (1 - v) * h)
    # main body: outer edge straight along v=0.97, inner edge curving in toward the tail
    top = [P(u, 0.97 - 0.02 * math.sin(u * 7 + i)) for u in np.linspace(0.0, 1.0, 40)]
    def inner_v(u):  # thin at the tail, fullest at 0.8, then sweeping up into the pointed head (a hook)
        if u < 0.8:
            return lerp(0.86, 0.1, (u / 0.8) ** 0.55)
        q = (u - 0.8) / 0.2
        return lerp(0.1, 0.95, q ** 1.6)
    bot = [P(u, inner_v(u)) for u in np.linspace(0.0, 1.0, 60)]
    body = top + bot[::-1]
    m = poly_mask([body], S)
    # dry-brush bristle gaps toward the tail: cut streaks where u is small
    cuts = np.zeros((S, S), np.float32)
    for k in range(9):
        v = 0.25 + 0.68 * k / 8 + g.uniform(-0.03, 0.03)
        u_end = lerp(0.25, 0.7, g.random()) * (1.0 - v * 0.4)
        p = [P(u, v + 0.015 * math.sin(u * 13 + k)) for u in np.linspace(-0.02, u_end, 16)]
        cuts = np.maximum(cuts, poly_mask([stroke(p, lambda q: h * 0.035 * (1 - q) + 1, cap=False)], S))
    m = m * (1 - cuts)
    f.fill(m, BODY, ink=1.6)
    # deep tone along the inner edge (shadow side), light band toward the blade, hot line on the blade
    tone_v = np.zeros((S, S), np.float32)
    yy = np.mgrid[0:S, 0:S][0]
    v_of = 1 - (yy - y0) / h
    # bands follow the stroke's own width (0 inner edge .. 1 blade), with a brushy wobble along it
    uu = np.mgrid[0:S, 0:S][1] / S
    iv = np.vectorize(inner_v)(np.clip(uu, 0, 1))
    rel = (v_of - iv) / np.maximum(0.97 - iv, 0.02)
    wob = 0.035 * np.sin(uu * 11 + i) + 0.015 * np.sin(uu * 29 + 2 * i)
    band_l = (rel > 0.55 + wob).astype(np.float32)
    band_h = ((rel > 0.8 + wob * 0.5) & (rel < 0.92)).astype(np.float32)
    band_d = (rel < 0.22 - wob).astype(np.float32)
    inside = (m > 0.5).astype(np.float32)
    f.tone = np.where(inside * band_d > 0, DEEP, f.tone)
    f.tone = np.where(inside * band_l > 0, LIGHT, f.tone)
    xx = np.mgrid[0:S, 0:S][1] / S
    f.tone = np.where((inside * band_h > 0) & (xx > 0.25), HOT, f.tone)
    # ink speed hatching inside the body near the head (painted detail)
    for k in range(3):
        v = 0.45 + 0.12 * k
        p = [P(u, v + 0.01 * k) for u in np.linspace(0.55 + 0.08 * k + g.uniform(0, 0.05), 0.9, 8)]
        f.fill(poly_mask([stroke(p, lambda q: h * 0.03 * math.sin(q * math.pi) + 0.5, cap=False)], S), DEEP)
    tone, alpha, _ = f.finish()
    s2 = size * 2
    hh = s2 // 4
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None


# --- 4. magma burst: Meteor Fall's landing (billboard, rising from the ground line) ----------------------------
# Thick, blobby, heavy: a squashed hot flash, then a fat lumpy dome of magma thrown up with globs that arc out and
# drip, a dark cracked crust closing over it as it cools, breaking into chunks.

def _tear(x, y, r, falling):
    """A glob with a pointed tail: above it when it is falling, below it when it is rising."""
    k = -1 if falling else 1
    body = [(x + math.sin(a) * r, y + math.cos(a) * r) for a in np.linspace(0.0, math.tau, 40, endpoint=False)]
    tail = [(x - r * 0.6, y - k * r * 0.35), (x, y - k * r * 2.2), (x + r * 0.6, y - k * r * 0.35)]
    return [body, tail]


def magma_burst(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    ground = f.u(1.62)
    if i == 0:  # anticipation: a squashed hot flash hugging the ground
        f.fill(ellipse_mask(c, ground, f.u(0.55), f.u(0.12), S), LIGHT, ink=3.0)
        f.fill(ellipse_mask(c, ground, f.u(0.32), f.u(0.06), S), HOT)
        return f.finish()
    t = (i - 1) / (n - 2)
    cool = max(0.0, (t - 0.3) / 0.7)
    # tongues: a splash crown thrown up and out, longest at the peak, then slumping back into a mound
    reach = lerp(0.75, 1.0, ease_out(min(1, t * 5))) * (1 - 0.75 * max(0, t - 0.2) / 0.8)
    angs = [100, 62, 128, 40, 148, 82, 112]
    lens = [1.25, 1.05, 1.0, 0.75, 0.7, 1.15, 0.9]
    shapes, tips, paths = [], [], []
    for k, (ad, ln) in enumerate(zip(angs, lens)):
        a = math.radians(ad)
        bx = c + f.u((k - 3) * 0.09)
        L = f.u(ln) * reach
        bend = 0.25 * (1 if ad < 90 else -1)  # they curl outward
        path = []
        for q in np.linspace(0, 1, 14):
            aa = a - bend * q * q
            path.append((bx + math.cos(aa) * L * q, ground - math.sin(aa) * L * q))
        w0 = f.u(0.3) * (0.8 + 0.3 * ln)
        shapes.append(stroke(path, lambda q, w0=w0: w0 * (1 - q) ** 1.3 + f.u(0.07) * math.exp(-((q - 0.92) ** 2) * 60), cap=True))
        tips.append((path[-1], a - bend, ln))
        paths.append((path, w0))
    mound_r = f.u(lerp(0.45, 0.62, ease_out(t)))
    mound = [(c + math.cos(a) * mound_r * (1 + 0.1 * math.sin(a * 7)), ground - math.sin(a) * mound_r * lerp(0.7, 0.55, t))
             for a in np.linspace(0, math.pi, 40)]
    m = poly_mask(shapes + [mound], S)
    f.fill(m, BODY, ink=3.5)
    # each tongue's lit inner stripe (painted), and a hot heart in the mound
    lit = poly_mask([stroke([(x - f.u(0.03), y) for x, y in path[1:11]], lambda q, w0=w0: w0 * 0.3 * (1 - q), cap=False)
                     for path, w0 in paths], S) * m
    f.fill(lit, LIGHT)
    if cool < 0.85:
        heart = [(c + math.cos(a) * mound_r * 0.6 * (1 - cool * 0.6), ground - math.sin(a) * mound_r * 0.38 * (1 - cool * 0.5))
                 for a in np.linspace(0, math.pi, 30)]
        f.fill(poly_mask([heart], S), HOT)
    if cool > 0:  # crust plates close in from the tips down, leaving glowing cracks
        yy, xx = np.mgrid[0:S, 0:S]
        cells = rng(43)
        pts = [(c + cells.uniform(-1, 1) * f.u(0.9), ground - cells.uniform(0.0, 1.2) * f.u(1)) for _ in range(30)]
        d = np.full((S, S), 1e9, np.float32)
        d2 = np.full((S, S), 1e9, np.float32)
        for (px, py) in pts:
            dd = np.hypot(xx - px, (yy - py) * 1.2).astype(np.float32)
            d2 = np.where(dd < d, d, np.minimum(d2, dd))
            d = np.minimum(d, dd)
        crack = f.u(lerp(0.06, 0.025, cool))
        plate = ((d2 - d) > crack).astype(np.float32) * shrink(m, f.u(0.03))
        dist_up = (ground - yy) / f.u(1.2)
        plate *= (dist_up > (1.0 - cool * 1.3)).astype(np.float32)
        f.fill(plate, DEEP if cool < 0.6 else INK + 0.1)
    # globs flung off the tongue tips: rising teardrops, then falling ones
    for k, ((tx, ty), a, ln) in enumerate(tips[:5]):
        if t < 0.12:
            continue
        tt = (t - 0.12) / 0.88
        vx, vy = math.cos(a) * f.u(0.9) * ln, -math.sin(a) * f.u(1.3) * ln
        x = tx + vx * tt
        y = ty + vy * tt + f.u(2.4) * tt * tt
        if y > ground or not (f.u(0.12) < x < S - f.u(0.12)) or y < f.u(0.12):
            continue
        r = f.u(lerp(0.1, 0.06, tt))
        falling = (vy + 2 * f.u(2.4) * tt) > 0
        f.fill(poly_mask(_tear(x, y, r, falling), S), LIGHT if cool < 0.6 else BODY, ink=2.5)
        f.fill(ellipse_mask(x - r * 0.3, y - r * 0.2, r * 0.32, r * 0.32, S), HOT)
    return f.finish()


# --- 5. magma shockwave: floor ring (ground plane, seen from above) --------------------------------------------
# A fat lumpy lava wave rolling out, inked front edge, hot crest, thinning into scattered blobs.

def magma_wave(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    t = i / (n - 1)
    R = f.u(lerp(0.3, 0.93, ease_out(t)))
    th = f.u(lerp(0.11, 0.035, t))
    outer = wobble_ring(c, c, R, 61, amp=0.06, lumps=(5, 9, 17))
    inner = wobble_ring(c, c, max(2, R - th * 2.2), 62, amp=0.12, lumps=(4, 7, 13))
    mo = poly_mask([outer], S)
    mi = poly_mask([inner], S)
    band = np.clip(mo - mi, 0, 1)
    f.fill(band, BODY, ink=3.0)
    crest = np.clip(mo - poly_mask([wobble_ring(c, c, R - th * 0.8, 63, amp=0.06, lumps=(5, 9, 17))], S), 0, 1) * band
    f.fill(crest, LIGHT if t > 0.3 else HOT)
    inner_dark = np.clip(poly_mask([wobble_ring(c, c, R - th * 1.6, 64, amp=0.1)], S) - mi, 0, 1) * band
    f.fill(inner_dark, DEEP)
    return f.finish()


# --- 6. magma crust: the floor left behind (cools over a few frames, erodes plate by plate) ---------------------

def magma_crust(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(71)
    t = i / max(1, n - 1)
    pool = wobble_ring(c, c, f.u(0.82), 72, amp=0.14, lumps=(3, 5, 8))
    mp = poly_mask([pool], S)
    f.fill(mp, LIGHT if t < 0.2 else BODY, ink=3.0)
    yy, xx = np.mgrid[0:S, 0:S]
    pts = [(c + g.uniform(-0.85, 0.85) * f.u(1), c + g.uniform(-0.85, 0.85) * f.u(1)) for _ in range(28)]
    d = np.full((S, S), 1e9, np.float32)
    d2 = np.full((S, S), 1e9, np.float32)
    lab = np.zeros((S, S), np.int32)
    for k, (px, py) in enumerate(pts):
        dd = np.hypot(xx - px, yy - py).astype(np.float32)
        nearer = dd < d
        d2 = np.where(nearer, d, np.minimum(d2, dd))
        lab = np.where(nearer, k, lab)
        d = np.minimum(d, dd)
    crack = f.u(lerp(0.04, 0.018, t))
    plate = ((d2 - d) > crack).astype(np.float32) * shrink(mp, crack * 0.8)
    f.fill(plate, [DEEP, DEEP - 0.06, INK + 0.12, INK + 0.06][i])
    # each plate's lit rim on its upper-left side (painted bevel)
    bevel = plate * (1 - shrink(plate, f.u(0.035)))
    up_left = ((xx - c) + (yy - c) < f.u(0.4)).astype(np.float32)
    f.fill(bevel * up_left, DEEP if t > 0.3 else BODY)
    # erode order: per plate, so plates go one by one (cracks last, as glowing lines, then those too)
    order = (lab * 0.61803) % 1.0
    order = order * 0.75 + (d / f.u(0.6)).clip(0, 1) * 0.25
    order = np.where(plate > 0.5, order * 0.8, 0.85 + 0.15 * (d2 - d < crack))
    f.order = order.astype(np.float32)
    return f.finish()


# --- 7. magma wall splat: a fat splash against a wall (billboard), drips running down ---------------------------

def magma_splat(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(81)
    cy = c - f.u(0.15)
    if i == 0:  # anticipation: a flat squashed hot disc (the moment of contact)
        f.fill(ellipse_mask(c, cy, f.u(0.32), f.u(0.42), S), HOT, ink=3)
        return f.finish()
    t = (i - 1) / (n - 2)
    R = f.u(lerp(0.5, 0.56, ease_out(t)))
    core = wobble_ring(c, cy, R, 82, amp=0.16, lumps=(3, 5, 7))
    arms = []
    for k in range(8):  # splash arms: radial strokes ending in round globs
        a = math.tau * k / 8 + 0.2 + g.uniform(-0.2, 0.2)
        L = f.u(lerp(0.65, 0.82, ease_out(t))) * g.uniform(0.75, 1.15)
        p = [polar(0, L * q, a) for q in np.linspace(0.2, 1, 8)]
        p = [(c + x, cy + y) for x, y in p]
        w = f.u(0.12) * g.uniform(0.8, 1.2)
        arms.append(stroke(p, lambda q, w=w: w * (1.2 - 0.85 * q ** 0.6), cap=True))
        x, y = p[-1]
        arms.append(wobble_ring(x, y, w * 0.75, 90 + k, amp=0.1))
    shape = poly_mask([core] + arms, S)
    cool = max(0.0, (t - 0.4) / 0.6)
    f.fill(shape, BODY, ink=3.5)
    f.fill(poly_mask([wobble_ring(c - f.u(0.06), cy - f.u(0.08), R * 0.68, 83, amp=0.2)], S), LIGHT)
    if cool < 0.7:
        f.fill(poly_mask([wobble_ring(c - f.u(0.05), cy - f.u(0.06), R * 0.35 * (1 - cool), 84, amp=0.25)], S), HOT)
    # drips: run down from the lower arms, longer each frame, with a fat round head
    for k, (dx, dl) in enumerate([(-0.42, 0.55), (-0.12, 0.85), (0.2, 0.4), (0.45, 0.7)]):
        x = c + f.u(dx)
        y0 = cy + f.u(0.3 + 0.2 * (1 - abs(dx) / 0.5))
        L = f.u(lerp(0.05, dl, ease_out(t)))
        wd = f.u(0.09) * (1.15 - 0.3 * abs(dx))
        p = [(x, y0 + L * q) for q in np.linspace(0, 1, 10)]
        f.poly(stroke(p, lambda q: wd * (0.55 + 0.45 * q ** 3), cap=True), BODY, ink=2.5)
        f.fill(ellipse_mask(x - wd * 0.15, y0 + L - wd * 0.1, wd * 0.18, wd * 0.18, S), LIGHT)
    if cool > 0:  # crust cracks: straight forked segments spreading from the middle
        for k in range(5):
            a = math.tau * k / 5 + 0.4
            p = jag_path((c, cy), polar(c, R * 0.95 * cool + 2, a), f.u(0.12), 0.5, 300 + k)
            f.poly(stroke(p, lambda q: f.u(0.045) * (1 - q) + 2, cap=False), INK)
            if len(p) > 2:
                j = p[len(p) // 2]
                b2 = j + np.array([math.cos(a + 0.8), math.sin(a + 0.8)]) * (R * 0.3 * cool + 2)
                f.poly(stroke(jag_path(j, b2, f.u(0.08), 0.4, 320 + k), lambda q: f.u(0.03) * (1 - q) + 1.5, cap=False), INK)
    return f.finish()


# --- 8. ice shatter: hard faceted shards (billboard) -----------------------------------------------------------
# Straight edges only. Frame 0: the block cracks (white fracture lines over a hex silhouette). Peak: a hot star
# and big two-tone shards flying out with a specular stripe each; then they spin off and shrink, glints twinkle.

def _shard(cx, cy, L, W, a, seed):
    g = rng(seed)
    d = np.array([math.cos(a), math.sin(a)])
    nrm = np.array([-d[1], d[0]])
    tip = np.array([cx, cy]) + d * L * 0.6
    back = np.array([cx, cy]) - d * L * 0.4
    s1 = np.array([cx, cy]) + nrm * W * 0.5 + d * L * g.uniform(-0.1, 0.15)
    s2 = np.array([cx, cy]) - nrm * W * 0.5 + d * L * g.uniform(-0.2, 0.05)
    mid = np.array([cx, cy]) + d * L * 0.05 + nrm * W * g.uniform(-0.15, 0.15)
    full = [tuple(tip), tuple(s1), tuple(back + nrm * W * 0.12), tuple(back - nrm * W * 0.1), tuple(s2)]
    lit = [tuple(tip), tuple(s1), tuple(mid)]
    shade = [tuple(back - nrm * W * 0.1), tuple(s2), tuple(mid)]
    stripe = [tuple(tip * 0.85 + mid * 0.15 + nrm * W * 0.06), tuple(tip * 0.85 + mid * 0.15 - nrm * W * 0.02), tuple(mid + nrm * W * 0.02), tuple(mid + nrm * W * 0.1)]
    return full, lit, shade, stripe


def ice_shatter(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(91)
    if i == 0:  # the block cracking
        hexa = [polar(c, f.u(0.42), math.tau * k / 6 + 0.26) for k in range(6)]
        f.poly(hexa, LIGHT, ink=3.0)
        f.poly([polar(c, f.u(0.3), math.tau * k / 6 + 0.26) for k in range(6)], BODY)
        for k in range(5):
            a = math.tau * k / 5 + 0.4
            p = [(c, c)]
            for q in (0.15, 0.3, 0.45):
                p.append(polar(c, f.u(q), a + (0.25 if int(q * 20) % 2 else -0.2)))
            f.poly(stroke(np.array(p), lambda q: f.u(0.035) * (1 - q) + 2, cap=False), HOT)
        return f.finish()
    t = (i - 1) / (n - 2)
    if i <= 2:  # the hot burst behind the shards
        tips = [f.u(0.7 if k % 2 == 0 else 0.45) * (1.0 if i == 1 else 0.85) for k in range(8)]
        f.poly(star(c, c, tips, f.u(0.16), rot=0.2, bow=0.0, n_edge=2), LIGHT if i == 1 else BODY, ink=2.5)
        if i == 1:
            f.poly(star(c, c, [x * 0.55 for x in tips], f.u(0.1), rot=0.2, bow=0.0, n_edge=2), HOT)
    for k in range(7):
        a = math.tau * k / 7 + g.uniform(-0.2, 0.2)
        dist = f.u(lerp(0.42, 0.8, ease_out(t))) * g.uniform(0.8, 1.0)
        L = f.u(g.uniform(0.28, 0.42)) * lerp(1.0, 0.45, t)
        W = L * g.uniform(0.4, 0.6)
        spin = a + g.uniform(-0.3, 0.3) + t * g.uniform(-1.5, 1.5)
        x, y = polar(c, dist, a)
        y += f.u(0.25) * t * t  # they fall a little
        full, lit, shade, stripe = _shard(x, y, L, W, spin, 100 + k)
        f.poly(full, BODY, ink=2.2)
        f.poly(lit, LIGHT)
        f.poly(shade, DEEP)
        if t < 0.75:
            f.poly(stripe, HOT)
    # glints: four-point sparkles that pop on alternate frames
    for k in range(4):
        if (i + k) % 2:
            continue
        a = math.tau * k / 4 + 0.8
        x, y = polar(c, f.u(lerp(0.4, 0.85, t)), a)
        r = f.u(lerp(0.16, 0.08, t))
        f.poly(star(x, y, [r, r * 0.4, r, r * 0.4], r * 0.12, rot=0, bow=0.5), HOT, ink=1.5)
    return f.finish()


# --- 9. bolt strip: a lightning bolt along x (ribbon texture; frames = re-jagged boils) --------------------------
# Jagged and branching: a fat zigzag core with forks peeling off, inked; light body, hot core line.

def bolt_strip(i, n, size):
    f = Frame(size * 2)
    S = f.S
    h = S / 4.0
    y0 = (S - h) / 2
    mid = y0 + h / 2
    g = rng(121 + i)
    main = jag_path((0, mid), (S, mid), S / 9, 0.55, 130 + i)
    main[:, 1] = np.clip(main[:, 1], y0 + h * 0.2, y0 + h * 0.8)
    w = h * 0.3
    body = stroke(main, lambda q: w * (0.75 + 0.25 * math.sin(q * 9 + i)), cap=False)
    forks = []
    fork_paths = []
    for k in range(3):
        j = 2 + k * 3 + (i % 2)
        if j >= len(main) - 1:
            continue
        a = main[j]
        side = 1 if k % 2 else -1
        b = a + np.array([S * g.uniform(0.08, 0.15), side * h * 0.38])
        fp = jag_path(a, b, S / 30, 0.5, 140 + i * 5 + k)
        fp[:, 1] = np.clip(fp[:, 1], y0 + 3, y0 + h - 3)
        forks.append(stroke(fp, lambda q: w * 0.45 * (1 - q) + 1.5, cap=False))
        fork_paths.append(fp)
    # fx-air: electric, not pale. A saturated rim (body) round a light band and a fat white-hot core, so the bolt
    # reads as charge against the pale air and the violet tentacle; the forks get a light core.
    m = poly_mask([body] + forks, S)
    f.fill(m, BODY, ink=2.5)
    for fp in fork_paths:
        f.fill(poly_mask([stroke(fp, lambda q: w * 0.2 * (1 - q) + 1.0, cap=False)], S) * m, LIGHT)
    f.fill(poly_mask([stroke(main, lambda q: w * 0.5 * (0.8 + 0.2 * math.sin(q * 9 + i)), cap=False)], S) * m, LIGHT)
    core = stroke(main, lambda q: w * 0.3 * (0.8 + 0.2 * math.sin(q * 9 + i)), cap=False)
    f.fill(poly_mask([core], S), HOT)
    tone, alpha, _ = f.finish()
    s2 = size * 2
    hh = s2 // 4
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None


# --- 10. storm burst: where the bolt hits the ground (billboard) ------------------------------------------------
# A spiky electric star with zigzag arcs crawling out from it; straight angular sparks, no curves.

def storm_burst(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    cy = c + f.u(0.25)
    t = i / (n - 1)
    if i == 0:
        f.fill(ellipse_mask(c, cy, f.u(0.55), f.u(0.14), S), HOT, ink=3)
        return f.finish()
    k = 7
    r = f.u(lerp(0.62, 0.75, ease_out(t)))
    if t < 0.7:
        tips = [r * (1.0 if s % 2 == 0 else 0.62) * (1 - 0.6 * max(0, t - 0.3)) for s in range(k)]
        f.poly(star(c, cy, tips, r * 0.25, rot=-math.pi / 2, bow=0.1, n_edge=2), BODY, ink=2.5)
        f.poly(star(c, cy, [x * 0.68 for x in tips], r * 0.17, rot=-math.pi / 2, bow=0.1, n_edge=2), LIGHT)
        f.poly(star(c, cy, [x * 0.42 for x in tips], r * 0.11, rot=-math.pi / 2, bow=0.1, n_edge=2), HOT)
    for s in range(5):  # arcs crawling outward
        a = -math.pi / 2 + (s - 2) * 0.62 + (0.1 if i % 2 else -0.1)
        r0 = r * lerp(0.3, 0.8, t)
        r1 = r * lerp(0.9, 1.25, t)
        p = jag_path(polar(0, r0, a), polar(0, r1, a), f.u(0.12), 0.6, 150 + s + i * 9)
        p = p + np.array([c, cy])
        am = f.poly(stroke(p, lambda q: f.u(lerp(0.09, 0.04, t)) * (1 - 0.5 * q) + 2, cap=False), BODY, ink=2.0)
        f.fill(poly_mask([stroke(p, lambda q: f.u(lerp(0.04, 0.018, t)) * (1 - 0.5 * q) + 1, cap=False)], S) * am, HOT)
    return f.finish()


# --- 11. dust puff: cartoon cloud (billboard) ------------------------------------------------------------------
# Three to five round lumps, a curl line inside, lit top / shaded bottom; it swells, then holes eat it.

def dust_puff(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    t = i / (n - 1)
    g = rng(161)
    base = c + f.u(0.45)
    lumps = [(-0.42, 0.0, 0.34), (0.0, -0.18, 0.44), (0.42, -0.02, 0.32), (-0.18, -0.42, 0.28), (0.22, -0.4, 0.26)]
    sc = lerp(0.45, 1.0, ease_out(min(1, t * 1.8)))
    rise = f.u(0.25) * t
    masks = []
    for k, (x, y, r) in enumerate(lumps):
        if k >= 3 and t < 0.15:
            continue
        rr = f.u(r) * sc * (1.0 - 0.15 * t)
        masks.append(wobble_ring(c + f.u(x) * sc, base + f.u(y) * sc - rise, rr, 170 + k, amp=0.05))
    m = poly_mask(masks, S)
    f.fill(m, BODY, ink=2.8)
    lit = poly_mask([wobble_ring(c + f.u(x) * sc - f.u(0.06), base + f.u(y) * sc - rise - f.u(0.08), f.u(r) * sc * 0.7, 180 + k, amp=0.05)
                     for k, (x, y, r) in enumerate(lumps)], S) * m
    f.fill(lit, LIGHT)
    shade = m * (1 - shrink(m, 0)) * 0
    yy, xx = np.mgrid[0:S, 0:S]
    bottom = ((yy - (base - rise)) > -f.u(0.02) * sc).astype(np.float32) * m
    f.fill(bottom, DEEP)
    if t < 0.8:  # the curl
        p = [(c + f.u(0.18 * math.cos(a)) * sc * (1 - a / 9), base - rise - f.u(0.18) * sc + f.u(0.18 * math.sin(a)) * sc * (1 - a / 9)) for a in np.linspace(0.5, 5.5, 14)]
        f.poly(stroke(p, lambda q: f.u(0.035) * (1 - q * 0.7) + 1.5, cap=False), INK)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "hit_spark": (hit_spark, 256, 4, 8, "hit", "center", 0.45),
    "impact_streaks": (impact_streaks, 256, 3, 6, "hit", "edge", 0.6),
    "slash_strip": (slash_strip, 256, 1, 4, "wind", "tail", 0.35),
    "magma_burst": (magma_burst, 384, 4, 10, "earth", "edge", 0.55),
    "magma_wave": (magma_wave, 384, 3, 6, "earth", "edge", 0.5),
    "magma_crust": (magma_crust, 384, 2, 4, "earth", "none", 0.15),
    "magma_splat": (magma_splat, 256, 4, 8, "earth", "edge", 0.5),
    "ice_shatter": (ice_shatter, 256, 4, 8, "water", "edge", 0.35),
    "bolt_strip": (bolt_strip, 256, 1, 4, "wind", "none", 0.9),
    "storm_burst": (storm_burst, 256, 3, 6, "wind", "edge", 0.5),
    "dust_puff": (dust_puff, 192, 4, 8, "dust", "edge", 0.6),
}
SHEETS.update(AIR_SHEETS)  # the air family (tools/vfx_gen/air_sheets.py)


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    if frames[0][0].shape[0] != frames[0][0].shape[1]:  # strips: stack rows
        tone = np.concatenate([fr[0] for fr in frames], 0)
        alpha = np.concatenate([fr[1] for fr in frames], 0)
        g = erode_field(alpha, 7, mode, nw) if mode != "none" else fbm(alpha.shape, 9, scales=(6, 3, 1))
        if mode == "tail":
            hh = frames[0][0].shape[0]
            xs = np.tile(np.linspace(0, 1, alpha.shape[1]), (alpha.shape[0], 1))
            g = np.clip(xs * (1 - nw) + fbm(alpha.shape, 9, scales=(22, 9, 3)) * nw, 0, 1)
        boil = fbm(alpha.shape, 99, scales=(6, 2, 1))
        sheet = (np.clip(np.stack([tone, g, boil, alpha], -1), 0, 1) * 255 + 0.5).astype(np.uint8)
    else:
        erode = None
        if mode == "none":
            erode = [fr[2] if fr[2] is not None else fbm(fr[1].shape, 5 + k) for k, fr in enumerate(frames)]
            erode = [np.clip(e * (1 - nw) + fbm(e.shape, 50 + k, scales=(4, 2, 1)) * nw, 0, 1) for k, e in enumerate(erode)]
        sheet = pack(frames, cols, seed=hash(name) % 1000 if False else sum(map(ord, name)), mode=mode, noise_w=nw, erode=erode)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    save(sheet, path)
    if prev_dir:
        os.makedirs(prev_dir, exist_ok=True)
        preview(sheet, pal, (0.0, 0.4, 0.7)).save(os.path.join(prev_dir, name + "_preview.png"))
    print(name, sheet.shape[1], "x", sheet.shape[0], "->", os.path.normpath(path))


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    prev = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--preview=")), None)
    for name in names or SHEETS:
        build(name, prev)


if __name__ == "__main__":
    main()
