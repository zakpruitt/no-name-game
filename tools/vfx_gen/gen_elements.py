"""Generate the fx-elements sheets (round 46, docs/features/designed-fx.md): the ice and magma base moves that were
still runtime polygon assemblies (Molten Palm's fist and fissure, the lava spurts and geysers, Meteor Fall's fireball,
the ice spikes, the frost spear's floor, the Deep Freeze burst, the lava pool under Undertow).

    python tools/vfx_gen/gen_elements.py [name ...] [--preview=<dir>]

Same format and conventions as gen_designed.py (tone, erode order, boil, cover; see vfxlib.py). The runtime is
scripts/designed_elements.gd, which registers these through DESIGNED.extra_sheets.

Shape language (designed-fx.md): magma = thick blobby tongues with round tips, teardrop globs, drips with fat heads,
dark crust plates with hot cracks, never straight edges or thin lines; ice = hexagonal blocks, faceted shards with a
lit facet, a shadow facet and one specular stripe, four-point glints, straight cracks, never curves or drips.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, catmull, ellipse_mask, erode_field, fbm, pack,  # noqa: E402
                    poly_mask, preview, rng, save, star, stroke, wobble_ring, shrink, grow, SS)

OUT = os.environ.get("VFX_OUT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def ease_out(t):
    return 1 - (1 - t) ** 3


def polar(cx, cy, r, a):
    return (cx + math.cos(a) * r, cy + math.sin(a) * r)


def voronoi(S, pts, sy=1.0):
    """Nearest and second-nearest distance and the nearest label for each pixel (crust plates, ice plates)."""
    yy, xx = np.mgrid[0:S, 0:S]
    d = np.full((S, S), 1e9, np.float32)
    d2 = np.full((S, S), 1e9, np.float32)
    lab = np.zeros((S, S), np.int32)
    for k, (px, py) in enumerate(pts):
        dd = np.hypot(xx - px, (yy - py) * sy).astype(np.float32)
        nearer = dd < d
        d2 = np.where(nearer, d, np.minimum(d2, dd))
        lab = np.where(nearer, k, lab)
        d = np.minimum(d, dd)
    return d, d2, lab


def tear(x, y, r, a):
    """A teardrop glob moving along angle `a`: round head at (x, y), pointed tail behind it."""
    body = [(x + math.cos(t) * r, y + math.sin(t) * r) for t in np.linspace(a - 2.45, a + 2.45, 24)]
    tail = (x - math.cos(a) * r * 2.6, y - math.sin(a) * r * 2.6)
    return body + [tail]


def facet_order(f, seed, cells=26, by_y=0.0):
    """Ice erodes in straight-edged pieces: one random order per Voronoi cell (cells are convex polygons), optionally
    biased so the top goes first (by_y > 0)."""
    g = rng(seed)
    S = f.S
    pts = [(g.uniform(0, S), g.uniform(0, S)) for _ in range(cells)]
    d, d2, lab = voronoi(S, pts)
    vals = g.random(cells).astype(np.float32)
    o = vals[lab]
    if by_y:
        yy = np.mgrid[0:S, 0:S][0] / S
        o = o * (1 - by_y) + yy * by_y
    f.order = o.astype(np.float32)


def tongue(path, w0, tip_r):
    """A blobby tongue along `path`: fat at the root, narrowing, ending in a round tip blob (magma never ends thin)."""
    return stroke(path, lambda q: w0 * (1 - q) ** 1.1 + tip_r * 2.0 * math.exp(-((q - 0.94) ** 2) * 80) + tip_r * 0.9 * q, cap=True)


def glint(f, x, y, r, tone=HOT, ink=1.5, rot=0.0):
    """A four-point sparkle (ice)."""
    f.poly(star(x, y, [r, r * 0.38, r, r * 0.38], r * 0.11, rot=rot, bow=0.5), tone, ink=ink)


# --- 1. Molten Palm's fist (billboard, drawn flying to +x; the runtime turns it to the flight on screen) ------------
# A fist of molten rock: a round block wider than it is long, four knuckles making its front edge, a thumb tucked
# along the top, dark crust plates over it with hot cracks between, the knuckles' tops lit. Behind it, blobby flame
# tongues stream back with round tips and teardrop globs. Frame 0 bunched and white-hot (wind-up), 1-2 the flight
# (stretched, boiling), 3-4 the hit (squashed, a splash crown thrown forward off the knuckles), 5-7 it cools dark and
# breaks into chunks and globs.

def _fist_shape(f, cx, cy, la, lb):
    knuck = []
    for k in range(4):
        q = (k - 1.5) / 1.5
        knuck.append((cx + la * (0.9 - 0.16 * q * q), cy + lb * q * 0.72, lb * 0.33))
    body = wobble_ring(cx, cy, 1.0, 5, amp=0.0, n=64)
    body = [(cx + (x - cx) * la, cy + (y - cy) * lb) for x, y in body]
    thumb = (cx + la * 0.1, cy - lb * 0.9, la * 0.6, lb * 0.3)
    return body, knuck, thumb


def magma_fist(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(301 + (i % 2) * 7)
    cx, cy = c + f.u(0.08), c + f.u(0.04)
    along, across, k = [(0.72, 1.12, 0.62), (1.18, 0.86, 1.0), (1.14, 0.9, 1.0), (0.78, 1.2, 1.02), (0.8, 1.18, 1.0),
                        (0.86, 1.1, 0.96), (0.9, 1.05, 0.9), (0.92, 1.0, 0.82)][i]
    la, lb = f.u(0.36) * along * k, f.u(0.42) * across * k
    if i >= 3:
        cx -= f.u(0.12)
    cool = [0.0, 0.0, 0.0, 0.0, 0.15, 0.5, 0.8, 1.0][i]
    # the trail (behind it): blobby tongues streaming back, round tips, globs flung off
    if 1 <= i <= 2:
        for s, (dy, ln, w) in enumerate([(-0.24, 0.6, 0.2), (0.02, 0.78, 0.26), (0.27, 0.52, 0.18)]):
            pts = []
            for q in np.linspace(0, 1, 12):
                x = cx - la * 0.4 - f.u(ln) * q
                y = cy + f.u(dy) * (1 + 0.4 * q) + f.u(0.07) * math.sin(q * 5.5 + s * 2.1 + i * 1.7) * q
                pts.append((x, y))
            f.poly(tongue(pts, f.u(w), f.u(0.05)), BODY, ink=4.5)
            lit = [(x + f.u(0.02), y - f.u(0.025)) for x, y in pts[:8]]
            f.fill(poly_mask([stroke(lit, lambda q, w=w: f.u(w) * 0.32 * (1 - q), cap=False)], S), LIGHT)
        for s, (dx, dy, r) in enumerate([(-0.72, -0.5, 0.06), (-0.85, 0.42, 0.05), (-0.55, 0.55, 0.045)]):
            x, y = cx + f.u(dx) + f.u(0.05) * i, cy + f.u(dy)
            f.poly(tear(x, y, f.u(r), math.pi + 0.25 * (1 if dy < 0 else -1)), LIGHT, ink=2.0)
    if i == 0:  # wind-up: three short hot ticks behind it
        for dy in (-0.3, 0.0, 0.3):
            p = [(cx - la - f.u(0.12), cy + f.u(dy)), (cx - la - f.u(0.42), cy + f.u(dy * 1.2))]
            f.poly(stroke(p, [f.u(0.07), f.u(0.01)], cap=True), LIGHT, ink=2.0)
    # the splash crown thrown forward off the knuckles on the hit
    if i >= 3:
        spread = [0, 0, 0, 1.0, 1.2, 1.28, 1.32, 1.36][i]
        for s, (a, ln) in enumerate([(-1.05, 0.36), (-0.5, 0.44), (0.05, 0.4), (0.55, 0.44), (1.1, 0.34)]):
            a += g.uniform(-0.08, 0.08)
            x0, y0 = cx + la * 0.85, cy + lb * math.sin(a) * 0.8
            L = f.u(ln) * spread
            if i <= 4:
                path = [(x0 + math.cos(a) * L * q, y0 + math.sin(a) * L * q + f.u(0.05) * q * q) for q in np.linspace(0, 1, 10)]
                f.poly(tongue(path, f.u(0.17), f.u(0.055)), BODY if i == 3 else LIGHT, ink=4.5)
            else:  # the tongues have broken into falling globs
                x, y = x0 + math.cos(a) * L, y0 + math.sin(a) * L + f.u(0.12) * (i - 4) ** 1.5
                f.poly(tear(x, y, f.u(0.075 - 0.012 * (i - 5)), math.pi * 0.5), BODY if cool < 0.7 else DEEP, ink=2.5)
        if i == 3:
            f.poly(star(cx + la * 1.05, cy, [f.u(0.42), f.u(0.3), f.u(0.5), f.u(0.28), f.u(0.38), f.u(0.32)], f.u(0.16),
                        rot=0.3, bow=0.3), LIGHT, ink=3.0)
            f.poly(star(cx + la * 1.05, cy, [f.u(0.24), f.u(0.17), f.u(0.28), f.u(0.16), f.u(0.22), f.u(0.18)], f.u(0.09),
                        rot=0.3, bow=0.3), HOT)
    # the fist
    body, knuck, thumb = _fist_shape(f, cx, cy, la, lb)
    m = poly_mask([body], S)
    for x, y, r in knuck:
        m = np.maximum(m, ellipse_mask(x, y, r, r, S))
    tx, ty, trx, try_ = thumb
    m = np.maximum(m, ellipse_mask(tx, ty, trx, try_, S))
    if i >= 6:  # breaking up: chunks pull apart
        d, d2, lab = voronoi(S, [(cx + g.uniform(-1, 1) * la, cy + g.uniform(-1, 1) * lb) for _ in range(7)])
        m = m * ((d2 - d) > f.u(0.035 * (i - 5))).astype(np.float32)
    f.fill(m, LIGHT if i == 0 else BODY, ink=5.0)
    # crust plates over it, hot cracks between (plates cover more as it cools)
    d, d2, lab = voronoi(S, [(cx + g.uniform(-1.1, 1.1) * la, cy + g.uniform(-1.1, 1.1) * lb) for _ in range(9)])
    crack = f.u(lerp(0.045, 0.02, cool)) * (1.4 if i == 0 else 1.0)
    plate = ((d2 - d) > crack).astype(np.float32) * shrink(m, f.u(0.02))
    yy, xx = np.mgrid[0:S, 0:S]
    if cool < 0.5:
        plate *= ((xx - cx) < la * (0.35 + cool)).astype(np.float32)
    if i == 0:
        f.fill(plate, BODY)
    else:
        f.fill(plate, DEEP if cool < 0.6 else INK + 0.12)
        # the plates' lit bevel on their upper-left
        yy, xx = np.mgrid[0:S, 0:S]
        bevel = plate * (1 - shrink(plate, f.u(0.03)))
        f.fill(bevel * (((xx - cx) * 0.4 + (yy - cy)) < 0).astype(np.float32), BODY if cool < 0.6 else DEEP)
    # the cracks glow hot near the knuckles (the front), light behind
    if cool < 0.7:
        yy, xx = np.mgrid[0:S, 0:S]
        front = ((xx - cx) > -la * 0.1).astype(np.float32)
        f.fill(m * (1 - plate) * shrink(m, f.u(0.02)) * front, HOT if i <= 4 else LIGHT)
        if i <= 4:
            f.fill(m * (1 - plate) * shrink(m, f.u(0.02)) * (1 - front), LIGHT)
    # knuckle tops lit, finger grooves inked
    if i < 6:
        for x, y, r in knuck:
            f.fill(ellipse_mask(x + r * 0.15, y - r * 0.25, r * 0.45, r * 0.3, S) * m, LIGHT if cool < 0.5 else BODY)
        for k in range(3):
            x = (knuck[k][0] + knuck[k + 1][0]) * 0.5
            y = (knuck[k][1] + knuck[k + 1][1]) * 0.5
            f.poly(stroke([(x + f.u(0.03), y), (x - la * 0.55, y)], [f.u(0.03), f.u(0.008)], cap=False), INK)
    if i == 0:
        f.fill(ellipse_mask(cx, cy, la * 0.5, lb * 0.45, S) * m, HOT)
    return f.finish()


# --- 2. Magma spurt (billboard standing on the floor, depth tested): one of Molten Palm's fissure eruptions and
# every earth `elements.spikes` (geysers' feet, the lava bolt's trail). Frame 0 a hot bulge splitting the floor;
# the peak a fat tongue of lava thrown up with two side tongues and round tips, globs off the top; it topples, slumps
# into a crusted mound and the crust breaks up.

def magma_spurt(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(331)
    ground = f.u(1.62)
    if i == 0:
        f.fill(ellipse_mask(c, ground, f.u(0.4), f.u(0.12), S), LIGHT, ink=5.0)
        f.fill(ellipse_mask(c, ground - f.u(0.02), f.u(0.2), f.u(0.05), S), HOT)
        return f.finish()
    h = [0, 1.0, 0.86, 0.6, 0.36, 0.24, 0.17][i]
    lean = [0, 0.0, 0.04, 0.07, 0.09, 0.1, 0.1][i]
    cool = [0, 0, 0, 0.2, 0.55, 0.85, 1.0][i]
    shapes, paths = [], []
    for s, (dx, hh, w, bend) in enumerate([(0.0, 1.0, 0.4, 0.0), (-0.2, 0.58, 0.26, -0.45), (0.21, 0.66, 0.24, 0.4)]):
        L = f.u(1.0) * h * hh
        if L < f.u(0.05):
            continue
        path = []
        for q in np.linspace(0, 1, 12):
            x = c + f.u(dx) + f.u(bend * 0.45) * q * q + f.u(lean) * q * q * (1 if s != 1 else 0.5)
            path.append((x, ground - L * q))
        tip = f.u(0.1) * (1.0 if s == 0 else 0.8) * (1.0 if h > 0.5 else 1.25)
        shapes.append(tongue(path, f.u(w), tip))
        paths.append((path, w))
    mound = [(c + math.cos(a) * f.u(0.36) * (1 + 0.08 * math.sin(a * 6)), ground - math.sin(a) * f.u(lerp(0.16, 0.24, cool)))
             for a in np.linspace(0, math.pi, 30)]
    m = poly_mask(shapes + [mound], S)
    f.fill(m, BODY, ink=6.0)
    if cool < 0.9:
        lit = poly_mask([stroke([(x - f.u(0.04), y) for x, y in p[1:10]], lambda q, w=w: f.u(w) * 0.3 * (1 - q), cap=False)
                         for p, w in paths], S) * m
        f.fill(lit, LIGHT)
    if cool < 0.6:
        f.fill(ellipse_mask(c, ground - f.u(0.06), f.u(0.2 * (1 - cool)), f.u(0.09), S) * m, HOT)
    if cool > 0:  # crust plates close over it from the top down
        d, d2, lab = voronoi(S, [(c + g.uniform(-0.6, 0.6) * f.u(1), ground - g.uniform(0, 1.2) * f.u(1)) for _ in range(14)], 1.0)
        yy, xx = np.mgrid[0:S, 0:S]
        plate = ((d2 - d) > f.u(lerp(0.05, 0.022, cool))).astype(np.float32) * shrink(m, f.u(0.025))
        plate *= ((ground - yy) / (f.u(1.15) * max(h, 0.3)) > (1.0 - cool * 1.4)).astype(np.float32)
        f.fill(plate, DEEP if cool < 0.7 else INK + 0.12)
    # globs off the top: rising, then falling teardrops
    if 1 <= i <= 4:
        for s, (a, sp) in enumerate([(-1.2, 0.5), (-1.95, 0.42), (-0.7, 0.3)]):
            tt = i / 4.0
            top = paths[0][0][-1] if paths else (c, ground - f.u(0.4))
            x = top[0] + math.cos(a) * f.u(sp) * tt * 1.6
            y = top[1] + math.sin(a) * f.u(sp) * tt * 1.6 + f.u(0.9) * tt * tt
            if y > ground - f.u(0.05) or y < f.u(0.08):
                continue
            mv = math.atan2(math.sin(a) * f.u(sp) + 2 * f.u(0.9) * tt, math.cos(a) * f.u(sp))
            f.poly(tear(x, y, f.u(0.075), mv), LIGHT if cool < 0.5 else BODY, ink=4.5)
    return f.finish()


# --- 3. Magma crack (floor, seen from above): the fissure Molten Palm tears along its line, one tile a step. A lumpy
# molten seam along x with crust plates breaking off its banks, hot down the middle; it cools to dark plates with
# glowing joins and breaks up plate by plate.

def magma_crack(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(351)
    t = i / max(1, n - 1)
    w = [0.12, 0.22, 0.2, 0.17][i]
    top = [(c + f.u(x), c - f.u(w) * (0.6 + 0.4 * math.cos(x * 1.6)) * (1 + 0.25 * math.sin(x * 9 + 1)))
           for x in np.linspace(-0.95, 0.95, 28)]
    bot = [(c + f.u(x), c + f.u(w) * (0.6 + 0.4 * math.cos(x * 1.6)) * (1 + 0.25 * math.sin(x * 7 + 2)))
           for x in np.linspace(0.95, -0.95, 28)]
    seam = poly_mask([top + bot], S)
    # crust plates along the banks
    bank_pts = [(c + f.u(x), c + f.u(side * g.uniform(0.18, 0.34))) for x in np.linspace(-0.85, 0.85, 7) for side in (-1, 1)]
    plates = []
    for k, (px, py) in enumerate(bank_pts):
        r = f.u(g.uniform(0.09, 0.14))
        plates.append(wobble_ring(px, py, r, 360 + k, amp=0.18, lumps=(3, 5), n=24))
    pm = poly_mask(plates, S) if i > 0 else np.zeros((S, S), np.float32)
    f.fill(np.maximum(seam, pm * 0.0), BODY, ink=3.0)
    if i > 0:
        f.fill(pm, DEEP if t < 0.6 else INK + 0.12, ink=2.5)
    core = poly_mask([[(x, (y - c) * 0.45 + c) for x, y in top + bot]], S)
    f.fill(core, HOT if t < 0.4 else (LIGHT if t < 0.8 else BODY))
    if t >= 0.6:  # the seam crusts over too, leaving glowing joins
        d, d2, lab = voronoi(S, [(c + g.uniform(-0.9, 0.9) * f.u(1), c + g.uniform(-0.2, 0.2) * f.u(1)) for _ in range(9)])
        plate = ((d2 - d) > f.u(0.03)).astype(np.float32) * shrink(seam, f.u(0.02))
        f.fill(plate, DEEP)
    order = None
    return f.finish()


# --- 4. Ice spike (billboard standing on the floor, depth tested): every water `elements.spikes` (Harpoon's line,
# the nova ring, Deep Freeze, the crystals). A cluster of three faceted shards (lit facet, body facet, shadow facet,
# one specular stripe each) on a broken hexagonal plate. Frame 0 straight cracks and a glint on the floor; the peak
# overshoots; then they crack across and fall apart into chips.

def _crystal(f, bx, by, h, w, lean, cracked=0.0, seed=0):
    """A faceted shard standing on (bx, by): five corners, three facets, a specular stripe."""
    tip = (bx + lean * h, by - h)
    bl, br = (bx - w, by), (bx + w, by)
    sl, sr = (bx - w * 0.92 + lean * h * 0.3, by - h * 0.42), (bx + w * 0.85 + lean * h * 0.36, by - h * 0.5)
    ml = (bx - w * 0.25 + lean * h * 0.08, by + w * 0.08)  # the ridge's feet (the front facet between them)
    mr = (bx + w * 0.3 + lean * h * 0.08, by + w * 0.06)
    f.poly([bl, sl, tip, sr, br], BODY, ink=5.5)
    f.poly([bl, sl, tip, ml], LIGHT)
    f.poly([mr, tip, sr, br], DEEP)
    # specular stripe in the lit facet, parallel to its long edge
    p0 = (lerp(sl[0], ml[0], 0.35), lerp(sl[1], ml[1], 0.35))
    f.poly([p0, (p0[0] + w * 0.12, p0[1]), (lerp(p0[0], tip[0], 0.8) + w * 0.06, lerp(p0[1], tip[1], 0.8)),
            (lerp(p0[0], tip[0], 0.8), lerp(p0[1], tip[1], 0.8))], HOT)
    if cracked > 0:  # a straight crack across it, ink
        g = rng(seed)
        y = by - h * g.uniform(0.35, 0.6)
        f.poly(stroke([(bx - w * 1.1, y + w * 0.3), (bx + lean * h * 0.4, y - w * 0.1), (bx + w * 1.1, y - w * 0.35)],
                      [f.u(0.02) * cracked] * 3, cap=False), INK)


def ice_spike(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(371)
    ground = f.u(1.6)
    if i == 0:  # the floor cracks and glints (straight lines only)
        hexa = [polar(c, ground, f.u(0.3), math.tau * k / 6 + 0.26) for k in range(6)]
        hexa = [(x, ground + (y - ground) * 0.4) for x, y in hexa]
        f.poly(hexa, BODY, ink=2.5)
        for k in range(5):
            a = math.tau * k / 5 + 0.3
            p = [(c, ground), polar(c, ground, f.u(0.22), a), polar(c, ground, f.u(0.42), a + 0.18)]
            p = [(x, ground + (y - ground) * 0.4) for x, y in p]
            f.poly(stroke(p, [f.u(0.035), f.u(0.025), f.u(0.008)], cap=False), LIGHT)
        glint(f, c, ground - f.u(0.1), f.u(0.26), ink=3.5)
        facet_order(f, 372)
        return f.finish()
    h = [0, 1.22, 1.0, 1.0, 0.92, 0.5][i]
    # the broken hex plate it stands on
    plate = [polar(c, ground, f.u(0.42), math.tau * k / 6 + 0.26) for k in range(6)]
    plate = [(x, ground + (y - ground) * 0.38) for x, y in plate]
    if i <= 4:
        f.poly(plate, LIGHT, ink=5.0)
        f.poly([(x * 0.6 + c * 0.4, y * 0.6 + ground * 0.4) for x, y in plate], BODY)
    shards = [(-0.24, 0.6, 0.16, -0.3), (0.02, 0.92, 0.21, 0.04), (0.26, 0.68, 0.17, 0.3)]
    if i <= 4:
        for k, (dx, hh, w, lean) in enumerate(shards):
            _crystal(f, c + f.u(dx), ground + f.u(0.02), f.u(1.1) * hh * h, f.u(w) * (1.1 if i == 1 else 1.0), lean,
                     cracked=1.0 if i == 4 else 0.0, seed=380 + k)
        if i in (1, 3):
            glint(f, c + f.u(0.06), ground - f.u(1.1) * h * 0.92, f.u(0.24 if i == 1 else 0.16), ink=3.5)
    else:  # broken: faceted chips tumbling down and out
        for k in range(6):
            a = -math.pi * 0.5 + (k - 2.5) * 0.45
            x, y = polar(c, ground - f.u(0.5), f.u(0.45 + 0.1 * (k % 2)), a)
            y += f.u(0.3)
            L, W = f.u(g.uniform(0.15, 0.24)), f.u(g.uniform(0.08, 0.12))
            r = a + g.uniform(-1, 1)
            d = np.array([math.cos(r), math.sin(r)])
            nrm = np.array([-d[1], d[0]])
            p = np.array([x, y])
            full = [tuple(p + d * L), tuple(p + nrm * W), tuple(p - d * L * 0.6), tuple(p - nrm * W * 0.8)]
            f.poly(full, BODY, ink=4.5)
            f.poly([full[0], full[1], tuple(p)], LIGHT)
            f.poly([full[2], full[3], tuple(p)], DEEP)
    facet_order(f, 373 + i, by_y=0.35)
    return f.finish()


# --- 5. Frost floor (floor, seen from above): what the frost spear spreads (frost_spear.gd). Straight cracks out
# from the spear, kinked and forked, a few hexagonal ice plates between them, a jagged toothed edge of ice facets, bare
# floor between (a flat disc washed out everything on it). Frame 0 the cracks running out; 1-3 the full frost with its
# glints moving (it boils on fours, slowly).

def ice_frost(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(391)
    reach = 0.55 if i == 0 else 1.0
    # the toothed edge: a ring of ice triangles pointing in, alternating lit and body
    if i > 0:
        teeth = 30
        for k in range(teeth):
            a0, a1 = math.tau * k / teeth, math.tau * (k + 1) / teeth
            am = (a0 + a1) * 0.5 + g.uniform(-0.05, 0.05)
            if k % 4 == 1 or k % 7 == 3:
                continue  # a gap: the edge is broken, not a closed hoop
            dep = g.uniform(0.03, 0.09)
            o0, o1 = polar(c, c, f.u(0.96), a0), polar(c, c, f.u(0.96), a1)
            tip = polar(c, c, f.u(0.96 - dep), am)
            f.poly([o0, o1, tip], LIGHT if k % 2 == 0 else BODY, ink=1.6)
            f.poly([o0, ((o0[0] + o1[0]) / 2, (o0[1] + o1[1]) / 2), tip], DEEP if k % 3 == 0 else LIGHT)
    # hexagonal plates between the cracks
    if i > 0:
        for k in range(6):
            a = math.tau * (k + 0.5) / 6 + g.uniform(-0.25, 0.25)
            x, y = polar(c, c, f.u(g.uniform(0.38, 0.72)), a)
            r = f.u(g.uniform(0.06, 0.1))
            rot = g.uniform(0, 1)
            hexa = [polar(x, y, r, math.tau * q / 6 + rot) for q in range(6)]
            f.poly(hexa, BODY, ink=2.0)
            f.poly([hexa[0], hexa[1], hexa[2], (x, y)], LIGHT)
            f.poly([hexa[3], hexa[4], (x, y)], DEEP)
    # straight cracks: three kinked spans, forked once, wide at the spear, to a point; light with a hot core
    g2 = rng(397)
    for k in range(11):
        a = math.tau * (k + g2.uniform(-0.3, 0.3)) / 11
        rr = f.u(g2.uniform(0.7, 0.98) * reach)
        pts = [(c, c)]
        b = a
        for q in (0.33, 0.66, 1.0):
            b = a + g2.uniform(-0.2, 0.2)
            pts.append(polar(c, c, rr * q, b))
        w = f.u(0.045)
        f.poly(stroke(pts, [w, w * 0.6, w * 0.3, 1.0], cap=False), LIGHT, ink=3.0)
        f.poly(stroke(pts[:3], [w * 0.4, w * 0.2, 1.0], cap=False), HOT)
        if k % 2 == 0:  # a fork off the middle span
            j = pts[2]
            fk = [j, polar(j[0], j[1], rr * 0.28, b + (0.6 if k % 4 else -0.6))]
            f.poly(stroke(fk, [w * 0.35, 1.0], cap=False), LIGHT, ink=1.6)
    # glints that move from frame to frame
    if i > 0:
        g3 = rng(400 + i)
        for k in range(3):
            x, y = polar(c, c, f.u(g3.uniform(0.3, 0.85)), g3.uniform(0, math.tau))
            glint(f, x, y, f.u(0.06))
    facet_order(f, 401, cells=40)
    return f.finish()



# --- 6. Meteor Fall's fireball in flight (billboard, depth tested, stood behind him; drawn flying to +x) ------------
# What he comes down inside: a round molten ball (crust plates with hot cracks, a white-hot bow on its front edge) with
# fat blobby flame tongues streaming back with round tips and teardrop globs shed behind. Frame 0 ignites (a smaller
# white-hot ball, short tongues); 1-4 boil on twos (the tongues whip, globs peel off).

def magma_meteor(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(411 + i * 5)
    cx, cy = c + f.u(0.36), c
    R = f.u(0.3 if i == 0 else 0.36)
    tl = 0.45 if i == 0 else 1.0
    ph = i * 1.9
    # the tongues behind it (drawn first)
    shapes, lits = [], []
    for s, (dy, ln, w) in enumerate([(-0.24, 1.05, 0.26), (0.0, 1.4, 0.34), (0.25, 0.95, 0.24), (-0.1, 0.7, 0.2), (0.14, 0.78, 0.2)]):
        pts = []
        L = f.u(ln) * 0.68 * tl * (0.9 + 0.2 * math.sin(ph + s * 1.3))
        for q in np.linspace(0, 1, 16):
            x = cx - R * 0.3 - L * q
            y = cy + f.u(dy) * (1 + 0.6 * q) + f.u(0.09) * math.sin(q * 6.0 + ph + s * 2.2) * q
            pts.append((x, y))
        shapes.append(tongue(pts, f.u(w), f.u(0.06)))
        lits.append((pts, w))
    m = poly_mask(shapes, S)
    f.fill(m, BODY, ink=5.0)
    lit = poly_mask([stroke([(x, y - f.u(0.03)) for x, y in p[1:11]], lambda q, w=w: f.u(w) * 0.32 * (1 - q), cap=False)
                     for p, w in lits], S) * m
    f.fill(lit, LIGHT)
    # globs shed behind
    if i > 0:
        for s in range(3):
            x = cx - f.u(0.8 + 0.2 * s + 0.08 * ((i + s) % 3))
            y = cy + f.u(g.uniform(-0.45, 0.45))
            if x < f.u(0.1):
                continue
            f.poly(tear(x, y, f.u(0.07 - 0.012 * s), math.pi), LIGHT, ink=4.0)
    # the ball
    ball = wobble_ring(cx, cy, R, 420 + i, amp=0.05, lumps=(5, 7), n=64)
    mb = poly_mask([ball], S)
    f.fill(mb, LIGHT if i == 0 else BODY, ink=5.5)
    d, d2, lab = voronoi(S, [(cx + g.uniform(-1, 1) * R, cy + g.uniform(-1, 1) * R) for _ in range(8)])
    yy, xx = np.mgrid[0:S, 0:S]
    back = ((xx - cx) < R * 0.25).astype(np.float32)
    plate = ((d2 - d) > f.u(0.04)).astype(np.float32) * shrink(mb, f.u(0.03)) * back
    f.fill(plate, DEEP if i > 0 else BODY)
    bevel = plate * (1 - shrink(plate, f.u(0.03)))
    f.fill(bevel * ((yy - cy) < 0).astype(np.float32), BODY if i > 0 else LIGHT)
    # the hot cracks between the plates, and a white-hot bow on the front edge
    f.fill(mb * (1 - plate) * shrink(mb, f.u(0.03)) * back, LIGHT)
    bow = mb * (1 - poly_mask([wobble_ring(cx - R * 0.28, cy, R * 0.95, 430, amp=0.04)], S))
    f.fill(bow, HOT)
    f.fill(ellipse_mask(cx + R * 0.35, cy - R * 0.35, R * 0.18, R * 0.12, S) * mb, HOT)
    return f.finish()


# --- 7. Lava geyser (billboard standing on the floor, depth tested): elements.geyser / rim_geyser ----------------------
# Frame 0 the floor bulges and splits hot; 1 a thick lumpy column punches up (overshoot) with a crown of round-tipped
# tongues; 2 full; 3 the crown breaks into globs; 4 the column's top falls away in blobs; 5 a short spout with drips;
# 6 a slumped mound crusting; 7 cooled crust lumps.

def magma_geyser(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(451)
    ground = f.u(1.66)
    if i == 0:
        f.fill(ellipse_mask(c, ground, f.u(0.34), f.u(0.1), S), LIGHT, ink=4.0)
        f.fill(ellipse_mask(c, ground - f.u(0.02), f.u(0.18), f.u(0.05), S), HOT)
        for a in (-2.6, -1.9, -1.25, -0.55):
            x, y = polar(c, ground, f.u(0.32), a)
            f.poly(tear(x, y - f.u(0.05), f.u(0.05), a), LIGHT, ink=3.0)
        return f.finish()
    top = [0, 1.32, 1.22, 1.16, 0.9, 0.56, 0.32, 0.22][i]  # column height in frame units
    gap = [0, 0, 0, 0, 0.35, 0.3, 0, 0][i]  # the top falls away from the column
    cool = [0, 0, 0, 0.1, 0.25, 0.45, 0.75, 1.0][i]
    w0 = f.u([0, 0.34, 0.38, 0.36, 0.3, 0.26, 0.34, 0.32][i])
    col = []
    for q in np.linspace(0, 1, 18):
        y = ground - f.u(top - gap) * q
        x = c + f.u(0.05) * math.sin(q * 6 + i)
        col.append((x, y))
    shapes = [stroke(col, lambda q: w0 * (1.25 - 0.4 * q) * (1 + 0.12 * math.sin(q * 11 + i * 2)), cap=True)]
    # the foot: a lumpy puddle round the column (a whole round shape: a dome cut on the ground line drew a straight edge)
    foot = [(c + math.cos(a) * f.u(0.5) * (1 + 0.1 * math.sin(a * 5 + i)),
             ground - f.u(0.04 + 0.06 * cool) + math.sin(a) * f.u(0.13 + 0.06 * cool) * (1 + 0.15 * math.sin(a * 3 + i)))
            for a in np.linspace(0, math.tau, 40, endpoint=False)]
    shapes.append(foot)
    crown_y = ground - f.u(top)
    tips = []
    if i in (1, 2):  # the crown: a fat head with tongues splashing over and falling, round tips
        shapes.append(wobble_ring(c, crown_y + f.u(0.12), w0 * 0.75, 452 + i, amp=0.1, lumps=(3, 5)))
        for s, (a, ln) in enumerate([(-2.85, 0.62), (-2.3, 0.5), (-0.85, 0.52), (-0.3, 0.64)]):
            L = f.u(ln) * (1.0 if i == 1 else 1.12)
            sag = f.u(0.42 if i == 1 else 0.6)  # the splash spills over and falls
            path = [(c + math.cos(a) * L * q, crown_y + f.u(0.12) + math.sin(a) * L * q + sag * q * q) for q in np.linspace(0, 1, 14)]
            shapes.append(tongue(path, f.u(0.17), f.u(0.07)))
            tips.append(path[-1])
            if i == 2:  # a glob dropping off each tip
                x, y = path[-1]
                shapes.append(tear(x, y + f.u(0.17), f.u(0.05), math.pi * 0.5))
    m = poly_mask(shapes, S)
    f.fill(m, BODY, ink=5.5)
    if cool < 0.8:
        lit = poly_mask([stroke([(x - w0 * 0.3, y) for x, y in col[1:16]], lambda q: w0 * 0.55 * (1 - q * 0.5), cap=True)], S) * m
        f.fill(lit, LIGHT)
        f.fill(poly_mask([stroke([(x - w0 * 0.28, y) for x, y in col[1:13]], lambda q: w0 * 0.24 * (1 - q * 0.7), cap=True)], S) * m, HOT)
        for x, y in tips:  # the splash's tips light up as they fall
            f.fill(ellipse_mask(x - f.u(0.015), y - f.u(0.02), f.u(0.04), f.u(0.03), S) * m, LIGHT)
    if cool > 0:  # crust closing from the foot up
        d, d2, lab = voronoi(S, [(c + g.uniform(-0.5, 0.5) * f.u(1), ground - g.uniform(0, 1.5) * f.u(1)) for _ in range(16)])
        yy, xx = np.mgrid[0:S, 0:S]
        plate = ((d2 - d) > f.u(lerp(0.05, 0.022, cool))).astype(np.float32) * shrink(m, f.u(0.03))
        plate *= ((ground - yy) < f.u(1.6) * cool).astype(np.float32)
        f.fill(plate, DEEP if cool < 0.7 else INK + 0.12)
    # globs: thrown from the crown, then the falling top
    if i >= 3:
        k = i - 3
        for s, (dx, sp) in enumerate([(-0.4, 0.9), (0.35, 0.8), (-0.12, 1.0), (0.2, 1.1), (-0.3, 1.2)]):
            x = c + f.u(dx) * (1 + 0.5 * k)
            y = crown_y + f.u(0.25) * k * k * 0.5 + f.u(0.1) * s * 0.4 - f.u(0.15)
            if y > ground - f.u(0.1) or y < f.u(0.06):
                continue
            f.poly(tear(x, y, f.u(0.07 - 0.008 * k), math.pi * 0.5), LIGHT if cool < 0.5 else BODY, ink=4.0)
    return f.finish()


# --- 8. Lava pool (floor): what Undertow pulls them down into (elements.Well, comic: was a scorch decal) --------------
# Frame 0 a hot crack splitting open; 1 the pool opens (white-hot middle); 2-3 it boils (crust rafts drift, bubbles pop
# as lit domes); 4-5 crust closes over it leaving glowing joins.

def magma_pool(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(471)
    if i == 0:
        p = jag_free(c, g)
        f.poly(stroke(p, lambda q: f.u(0.09) * math.sin(math.pi * q) + 2, cap=False), LIGHT, ink=3.0)
        f.poly(stroke(p, lambda q: f.u(0.035) * math.sin(math.pi * q) + 1, cap=False), HOT)
        return f.finish()
    R = f.u([0, 0.62, 0.7, 0.72, 0.72, 0.7][i])
    pool = wobble_ring(c, c, R, 472, amp=0.06, lumps=(2, 3, 5), n=96)  # round, fat lobes (finer lumps read as a blast)
    mp = poly_mask([pool], S)
    f.fill(mp, BODY, ink=7.0)
    f.fill(poly_mask([wobble_ring(c, c, R * 0.6, 473 + i, amp=0.1, lumps=(2, 3), n=72)], S), LIGHT)
    f.fill(poly_mask([wobble_ring(c + f.u(0.04), c - f.u(0.03), R * 0.26, 476 + i, amp=0.15, n=48)], S), HOT)
    cool = [0, 0, 0, 0.1, 0.5, 0.85][i]
    # crust rafts drifting (more as it cools)
    g2 = rng(480)
    for k in range(5 + int(cool * 8)):
        a = g2.uniform(0, math.tau) + i * 0.12
        rr = R * g2.uniform(0.35, 0.85)
        x, y = polar(c, c, rr, a)
        r = f.u(g2.uniform(0.06, 0.11)) * (1 + cool)
        f.fill(poly_mask([wobble_ring(x, y, r, 490 + k, amp=0.25, lumps=(3, 4))], S) * mp, DEEP, ink=2.5)
    if 2 <= i <= 3:  # bubbles: lit domes popping
        for k, (a, rr) in enumerate([(0.6, 0.3), (2.4, 0.45), (4.2, 0.2)]):
            x, y = polar(c, c, R * rr, a + i)
            r = f.u(0.05 + 0.02 * ((i + k) % 2))
            f.fill(ellipse_mask(x, y, r, r * 0.8, S), BODY, ink=2.5)  # a dome of lava, lit on top (no dark middle: those read as eyes)
            f.fill(ellipse_mask(x - r * 0.25, y - r * 0.3, r * 0.35, r * 0.22, S), HOT)
    if cool > 0.3:
        d, d2, lab = voronoi(S, [(c + g.uniform(-0.8, 0.8) * f.u(1), c + g.uniform(-0.8, 0.8) * f.u(1)) for _ in range(18)])
        plate = ((d2 - d) > f.u(lerp(0.04, 0.02, cool))).astype(np.float32) * shrink(mp, f.u(0.02))
        f.fill(plate, DEEP if cool < 0.7 else INK + 0.12)
    # the dark crust lip round it
    rim = mp * (1 - shrink(mp, f.u(0.05)))
    f.fill(rim, DEEP)
    return f.finish()


def jag_free(c, g):
    """A lumpy split line across the middle (the pool's first crack), as a smooth-ish path (magma: never straight)."""
    pts = [(c + (q - 0.5) * c * 1.2, c + math.sin(q * 5.0) * c * 0.08) for q in np.linspace(0, 1, 9)]
    return catmull(pts, 6)

SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "magma_fist": (magma_fist, 256, 4, 8, "earth", "edge", 0.5),
    "magma_spurt": (magma_spurt, 256, 4, 7, "earth", "edge", 0.5),
    "magma_crack": (magma_crack, 256, 2, 4, "earth", "edge", 0.5),
    "ice_spike": (ice_spike, 256, 3, 6, "water", "edge", 0.35),
    "ice_frost": (ice_frost, 512, 2, 4, "water", "edge", 0.4),
    "magma_meteor": (magma_meteor, 384, 3, 5, "earth", "edge", 0.5),
    "magma_geyser": (magma_geyser, 384, 4, 8, "earth", "edge", 0.5),
    "magma_pool": (magma_pool, 384, 3, 6, "earth", "edge", 0.5),
}


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    erode = None
    if any(fr[2] is not None for fr in frames):  # authored orders (ice: straight-edged pieces) with a little noise
        erode = []
        for k, fr in enumerate(frames):
            if fr[2] is None:
                erode.append(erode_field(fr[1], 7 + k, mode, nw))
            else:
                erode.append(np.clip(fr[2] * 0.85 + fbm(fr[1].shape, 50 + k, scales=(3, 2, 1)) * 0.15, 0, 1) * 0.94 + 0.03)
    sheet = pack(frames, cols, seed=sum(map(ord, name)), mode=mode, noise_w=nw, erode=erode)
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
