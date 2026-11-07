"""Generate the fx-polygons sheets (round 48, docs/features/designed-fx.md "fx-polygons"): the last runtime polygon
effects as authored sheets: the breaker dive's comet trail (brush and ink), the chip spray every Fx.burst throws,
the state tells on foes (buried crust ring, pinned frost, molten licks), the dark tear.

    python tools/vfx_gen/gen_polygons.py [name ...] [--preview=<dir>]

Same format as gen_designed.py / gen_cohesion.py (tone, erode order, boil, cover; see vfxlib.py), its own module
so lanes add sheets side by side. Registered at runtime by scripts/designed_polish.gd (DESIGNED.extra_sheets).
No ice crystals or spike clusters anywhere (Zak): ice is rime, straight cracks and glints.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, catmull, ellipse_mask, erode_field, fbm, grow,  # noqa: E402
                    jag_path, pack, poly_mask, preview, rng, save, shrink, stroke, wobble_ring)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def polar(cx, cy, r, a):
    return cx + math.cos(a) * r, cy + math.sin(a) * r


# --- strips (ribbons): drawn on a square canvas in a band S x S/4, cropped ---------------------------------------
# u runs 0 (tail) .. 1 (head) along x, v 0 .. 1 across (top = 1). The ribbon's UV.x is the same, so the head sits at
# the hero end of the mesh.

def _strip_canvas(size):
    f = Frame(size * 2)
    S = f.S
    h = S / 4.0
    y0 = (S - h) / 2

    def P(u, v):
        return (u * S, y0 + (1 - v) * h)
    return f, S, h, y0, P


def _crop(f, size):
    tone, alpha, _ = f.finish()
    s2 = size * 2
    hh = s2 // 4
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None


# dive_trail: the breaker dive's comet (every element but storm and dark; storm plays the lime bolt, dark dive_ink).
# A brush comet: a fat round head at the hero end, the body tapering to a dry-brush point at the tail with bristle
# splits, two loose speed strokes trailing it, a hot core line from the head down the middle, a light band on top
# and a deep shadow edge underneath. Four boils (the splits and the strokes move).

HEAD_U = 0.84
HEAD_R = 0.42  # of the strip's height


def dive_trail(i, n, size):
    f, S, h, y0, P = _strip_canvas(size)
    g = rng(611 + i)

    def half(u):  # the body's half width in v, 0 at the tail to HEAD_R at the head
        k = np.clip(u / HEAD_U, 0, 1)
        return HEAD_R * k ** 0.85 * (1 + 0.04 * math.sin(u * 17 + i * 1.7))
    us = np.linspace(0.02, HEAD_U, 50)
    mid = 0.5 + 0.03 * np.sin(us * 6 + i)
    top = [P(u, m + half(u)) for u, m in zip(us, mid)]
    bot = [P(u, m - half(u) * 0.9) for u, m in zip(us, mid)]
    head = []
    for k in range(24):
        a = -math.pi * 0.5 + math.pi * k / 23
        head.append((HEAD_U * S + math.cos(a) * HEAD_R * h * 1.05, y0 + (1 - mid[-1]) * h - math.sin(a) * HEAD_R * h))
    body = top + head + bot[::-1]
    m = poly_mask([body], S)
    # bristle splits in the tail half
    cuts = np.zeros((S, S), np.float32)
    for k in range(5):
        v = 0.5 + g.uniform(-0.22, 0.22)
        u1 = g.uniform(0.25, 0.55)
        p = [P(u, v + 0.02 * math.sin(u * 11 + k + i)) for u in np.linspace(-0.02, u1, 14)]
        cuts = np.maximum(cuts, poly_mask([stroke(p, lambda q: h * 0.05 * (1 - q) + 1, cap=False)], S))
    m = m * (1 - cuts)
    f.fill(m, BODY, ink=4.0)
    inside = m > 0.5
    yy, xx = np.mgrid[0:S, 0:S]
    uu = xx / S
    vv = 1 - (yy - y0) / h
    hw = np.vectorize(half)(np.clip(uu, 0, 1))
    rel = (vv - 0.5) / np.maximum(hw, 0.02)  # -1 bottom .. 1 top of the body
    f.tone = np.where(inside & (rel < -0.45 + 0.08 * np.sin(uu * 9 + i)), DEEP, f.tone)
    f.tone = np.where(inside & (rel > 0.25 + 0.06 * np.sin(uu * 13 + i)), LIGHT, f.tone)
    # the hot core: a tapered line from the head down the middle
    core = [P(u, 0.5 + 0.03 * math.sin(u * 6 + i) + 0.04) for u in np.linspace(0.38, HEAD_U + 0.02, 20)]
    cm = poly_mask([stroke(core, lambda q: h * (0.02 + 0.2 * q ** 1.3), cap=True)], S)
    f.fill(cm * m, HOT)
    # loose speed strokes trailing it, above and below
    for k, side in enumerate((1, -1)):
        v = 0.5 + side * (0.36 + g.uniform(0, 0.06))
        u0 = g.uniform(0.05, 0.18)
        u1 = u0 + g.uniform(0.22, 0.32)
        p = [P(u, v - side * 0.08 * (u - u0) / (u1 - u0)) for u in np.linspace(u0, u1, 10)]
        sm = poly_mask([stroke(p, lambda q: h * 0.075 * math.sin(q * math.pi) + 0.5, cap=False)], S)
        f.fill(sm, LIGHT if k == 0 else BODY, ink=3.0)
    return _crop(f, size)


# dive_ink: the dark dive. Ink, not light: one fat tapered ink stroke with a violet body, two thinner strokes that
# peel off it and curl at their ends, splatter drops left behind the tail, a negative-space hole near the head and a
# hot lip on the head. Four boils.

def dive_ink(i, n, size):
    f, S, h, y0, P = _strip_canvas(size)
    g = rng(811 + i)

    def main_w(u):
        return h * 0.78 * min(1.0, (u / 0.8)) ** 0.9

    us = np.linspace(0.04, 0.82, 30)
    path = [P(u, 0.5 + 0.06 * math.sin(u * 5 + i * 0.9)) for u in us]
    mm = poly_mask([stroke(path, lambda q: main_w(lerp(0.04, 0.82, q)), cap=True)], S)
    f.fill(mm, BODY, ink=4.0)
    # two thinner strokes peeling off and curling at their tails
    for k, side in enumerate((1, -1)):
        u0 = 0.72 - 0.06 * k
        pts = []
        for j in range(16):
            t = j / 15
            u = lerp(u0, 0.12 + 0.08 * k + g.uniform(-0.02, 0.02), t)
            v = 0.5 + side * (0.08 + 0.3 * t ** 1.4)
            if t > 0.75:  # the curl
                c = (t - 0.75) / 0.25
                v += side * 0.12 * math.sin(c * math.pi)
                u += 0.05 * c
            pts.append(P(u, v))
        sm = poly_mask([stroke(pts, lambda q: h * 0.2 * (1 - q) ** 0.8 + 1, cap=True)], S)
        f.fill(sm, DEEP if k else BODY, ink=3.5)
    # light along the top of the main stroke, the hot lip at the head
    yy, xx = np.mgrid[0:S, 0:S]
    vv = 1 - (yy - y0) / h
    uu = xx / S
    centre = 0.5 + 0.06 * np.sin(uu * 5 + i * 0.9)
    inside = mm > 0.5
    f.tone = np.where(inside & (vv > centre + 0.12) & (uu > 0.3), LIGHT, f.tone)
    lip = poly_mask([stroke([P(u, 0.5 + 0.06 * math.sin(u * 5 + i * 0.9) + 0.18) for u in np.linspace(0.56, 0.82, 10)],
                            lambda q: h * 0.09 * math.sin(q * math.pi) + 0.5, cap=False)], S)
    f.fill(lip * mm, HOT)
    # a negative-space hole in the body near the head
    hx, hy = P(0.7 + 0.02 * math.sin(i), 0.46)
    f.cut(ellipse_mask(hx, hy, h * 0.07, h * 0.06, S))
    # splatter left behind the tail
    for k in range(6):
        u = g.uniform(0.0, 0.22)
        v = 0.5 + g.uniform(-0.35, 0.35)
        r = h * g.uniform(0.035, 0.07) * (0.6 + u * 2)
        x, y = P(u, v)
        f.fill(ellipse_mask(x, y, r, r, S), DEEP, ink=2.5)
    return _crop(f, size)


# --- chip_spray: what an Fx.burst throws (sprite) -----------------------------------------------------------------
# A handful of inked teardrop chips and two dots flung up and out in a fan from the middle (screen up), then
# arcing over and falling, shrinking; one hot chip, the rest body with a light cap. The shader spins the quad to the
# burst's direction. Frame 0 is a tight cluster with a pinched flash (anticipation).

def chip_spray(i, n, size):
    f = Frame(size)
    S = f.S
    c = f.c
    g = rng(5)  # the same chips every frame: they fly
    chips = []
    for k in range(8):
        a = -math.pi * 0.5 + g.uniform(-1.15, 1.15)  # up, fanned
        spd = g.uniform(0.55, 0.95)
        r = g.uniform(0.045, 0.075)
        chips.append((a, spd, r, k))
    t = i / (n - 1)
    if i == 0:  # the pinched flash
        pts = []
        for k in range(8):
            a = math.tau * k / 8 + 0.2
            rr = 0.16 if k % 2 == 0 else 0.06
            pts.append(polar(c, c, f.u(rr), a))
        f.poly([pts], HOT, ink=3.0)
    for a, spd, r, k in chips:
        if i == 0:
            d = 0.12 * spd
            vy = 0.0
        else:
            d = 0.1 + 0.75 * spd * (1 - (1 - t) ** 1.6)
            vy = 0.55 * t * t  # falls (screen down)
        x = c + math.cos(a) * f.u(d)
        y = c + math.sin(a) * f.u(d) + f.u(vy)
        # direction of travel: out along a, bending down as it falls
        dx = math.cos(a)
        dy = math.sin(a) + 1.6 * t
        L = math.hypot(dx, dy)
        dx, dy = dx / L, dy / L
        rr = f.u(r * (1.0 - 0.45 * t))
        if k >= 6:  # two round dots
            f.fill(ellipse_mask(x, y, rr * 0.7, rr * 0.7, S), BODY, ink=3.0)
            continue
        tail = rr * (2.2 + 1.5 * (1 - t))  # a teardrop: the point trails behind the motion
        path = [(x - dx * tail, y - dy * tail), (x - dx * tail * 0.4, y - dy * tail * 0.4), (x, y)]
        m = poly_mask([stroke(catmull(path, 6), lambda q: rr * 2 * (q ** 0.7), cap=True)], S)
        f.fill(m, HOT if k == 0 else BODY, ink=3.0)
        cap = poly_mask([stroke([(x - dx * rr * 0.3 - dy * rr * 0.3, y - dy * rr * 0.3 + dx * rr * 0.3), (x + dx * rr * 0.3, y + dy * rr * 0.3)],
                                [rr * 0.7, rr * 0.5], cap=True)], S)
        f.fill(cap * m, HOT if k == 0 else LIGHT)
    return f.finish()


# --- tell_buried: the buried state on the floor round its feet (ground, loops) -----------------------------------
# A broken ring of heaved crust: four fat arcs of dark crust (fat in the middle, dragged thin at the ends, never a
# closed hoop), hot seams along their inner edges, short cracks running out of the gaps, rubble lumps on the ring.
# The four frames are boils of the same drawing (the seams glow and the lumps shift a hair).

def tell_buried(i, n, size):
    f = Frame(size)
    S = f.S
    c = f.c
    g = rng(77)
    gi = rng(200 + i)
    R = 0.56
    arcs = []
    a = g.uniform(0, math.tau)
    for k in range(4):
        span = g.uniform(1.15, 1.35)
        arcs.append((a, span))
        a += span + g.uniform(0.18, 0.3)
    for a0, span in arcs:  # the cracks out of the gaps first (under the crust)
        ag = a0 + span + 0.18
        p0 = polar(c, c, f.u(R - 0.05), ag)
        p1 = polar(c, c, f.u(R + 0.3 + g.uniform(0, 0.1)), ag + g.uniform(-0.15, 0.15))
        jp = jag_path(p0, p1, f.u(0.08), 0.6, 300 + int(ag * 10))
        f.fill(poly_mask([stroke(jp, lambda q: f.u(0.035) * (1 - q) + 2, cap=False)], S), DEEP, ink=3.0)
    for a0, span in arcs:
        pts = []
        m = 22
        for j in range(m):
            t = j / (m - 1)
            aa = a0 + span * t
            pts.append(polar(c, c, f.u(R + 0.012 * math.sin(t * 9 + i * 0.7)), aa))
        width = lambda q: f.u(0.13) * min(1.0, math.sin(q * math.pi) * 2.2) ** 0.8 + 2  # noqa: E731
        cm = poly_mask([stroke(pts, width, cap=False)], S)
        f.fill(cm, DEEP, ink=4.0)
        # top light along the outer edge, hot seam along the inner edge (it glows from below)
        inner = [polar(c, c, f.u(R - 0.035), a0 + span * (0.12 + 0.76 * t)) for t in np.linspace(0, 1, 14)]
        seam = poly_mask([stroke(inner, lambda q: f.u(0.022 + 0.01 * (i % 2)) * math.sin(q * math.pi) + 1, cap=False)], S)
        f.fill(seam * cm, BODY if i % 2 == 0 else LIGHT)
        for j in range(1, 4):  # broken into slabs: ink notches across the arc
            aa = a0 + span * (j / 4 + gi.uniform(-0.03, 0.03) * 0 + g.uniform(-0.04, 0.04))
            p0 = polar(c, c, f.u(R - 0.09), aa)
            p1 = polar(c, c, f.u(R + 0.09), aa + 0.05)
            f.fill(poly_mask([stroke([p0, p1], [f.u(0.022), f.u(0.014)], cap=False)], S) * cm, INK)
        outer = [polar(c, c, f.u(R + 0.04), a0 + span * (0.2 + 0.6 * t)) for t in np.linspace(0, 1, 10)]
        f.fill(poly_mask([stroke(outer, lambda q: f.u(0.025) * math.sin(q * math.pi), cap=False)], S) * cm, LIGHT)
    for k in range(5):  # rubble lumps on the ring
        aa = g.uniform(0, math.tau)
        rr = R + g.uniform(-0.05, 0.08)
        x, y = polar(c, c, f.u(rr), aa)
        lump = wobble_ring(x + gi.uniform(-1, 1) * 2, y + gi.uniform(-1, 1) * 2, f.u(g.uniform(0.045, 0.07)), 50 + k, amp=0.2)
        f.poly([lump], DEEP, ink=3.5)
    return f.finish()


# --- tell_pinned: the skewered state, frost holding its feet (ground, loops) -------------------------------------
# No stake, no crystals: a pale rime round its feet with a toothless scalloped edge, five straight inked cracks
# running out of it and two four-point glints that move from frame to frame.

def tell_pinned(i, n, size):
    f = Frame(size)
    S = f.S
    c = f.c
    g = rng(91)
    rime = wobble_ring(c, c, f.u(0.46), 91, amp=0.08, lumps=(6, 11), squash=0.95)
    f.poly([rime], LIGHT, ink=4.0)
    f.fill(poly_mask([wobble_ring(c, c, f.u(0.3), 93, amp=0.1, lumps=(5, 9))], S), BODY)
    f.fill(poly_mask([wobble_ring(c, c, f.u(0.16), 94, amp=0.1, lumps=(4, 7))], S), DEEP)
    for k in range(5):
        a = math.tau * k / 5 + g.uniform(-0.25, 0.25)
        p0 = polar(c, c, f.u(0.12), a)
        p1 = polar(c, c, f.u(0.62 + g.uniform(0, 0.15)), a + g.uniform(-0.12, 0.12))
        mid = polar(c, c, f.u(0.38), a + g.uniform(-0.1, 0.1))
        f.fill(poly_mask([stroke([p0, mid, p1], [f.u(0.03), f.u(0.024), 1.5], cap=False)], S), INK)
    for k in range(2):  # glints, moving round
        a = 0.6 + k * 2.6 + i * 0.7
        x, y = polar(c, c, f.u(0.3 + 0.08 * ((i + k) % 2)), a)
        r = f.u(0.07 if (i + k) % 2 == 0 else 0.045)
        pts = []
        for j in range(8):
            aa = math.tau * j / 8 + math.pi * 0.25
            pts.append(polar(x, y, r if j % 2 == 0 else r * 0.22, aa))
        f.poly([pts], HOT, ink=2.5)
    return f.finish()


# --- tell_molten: the molten state, licks of flame at its feet (sprite_depth on a ground line, loops) -------------
# Five short magma tongues standing on a ground ellipse round its feet, the tallest at the sides (the foe stands in
# the middle), leaning out and licking side to side frame to frame, round-tipped, hot roots, inked.

GROUND = 0.78


def tell_molten(i, n, size):
    f = Frame(size)
    S = f.S
    gy = GROUND * S
    g = rng(61)
    spec = [(-0.62, 0.42, -0.35), (-0.32, 0.3, -0.12), (0.0, 0.18, 0.0), (0.33, 0.32, 0.15), (0.6, 0.46, 0.38)]
    for k, (x, hh, lean) in enumerate(spec):
        lick = 0.3 * (1 if (i + k) % 2 == 0 else -1)
        hh = hh * (1.0 + 0.12 * ((i + k) % 3 - 1))
        bx = f.c + f.u(x)
        by = gy - f.u(0.04) * (1 - abs(x))
        pts = []
        for j in range(14):
            t = j / 13
            px = bx + f.u(hh) * (lean * t ** 1.3 + lick * math.sin(t * math.pi) * t)
            py = by - f.u(hh) * 1.5 * t
            pts.append((px, py))
        w0 = f.u(0.24 + 0.06 * (abs(x) > 0.5))

        def wid(q, w0=w0):
            return w0 * max(0.0, math.sin(min(1.0, q * 1.3) * math.pi * 0.6 + 0.3)) * (1 - q) ** 0.5 + 1
        m = poly_mask([stroke(pts, wid, cap=True)], S)
        f.fill(m, BODY, ink=4.0)
        core = poly_mask([stroke(pts[:9], lambda q, w0=w0: w0 * 0.45 * (1 - q) + 1, cap=True)], S)
        f.fill(core * m, LIGHT)
        root = ellipse_mask(bx, by - f.u(0.03), w0 * 0.35, w0 * 0.22, S)
        f.fill(root * m, HOT)
    # a hot puddle line along the ground ellipse joining their roots
    gl = [(f.c + f.u(x), gy - f.u(0.035) * (1 - abs(x)) + f.u(0.02) * math.sin(x * 9 + i)) for x in np.linspace(-0.66, 0.66, 20)]
    f.fill(poly_mask([stroke(gl, lambda q: f.u(0.05) * math.sin(q * math.pi) + 2, cap=True)], S), BODY, ink=3.0)
    _ = g
    return f.finish()


# --- ink_tear: a dark rip across a foe (Tow Line's yank out of the air, Shatter's cut; sprite) ---------------------
# Frame 0 a pinched hot flash and a thin cut; then one fat tapered ink stroke tearing across, a violet body and a hot
# seam, ragged on its trailing edge, drops flicking off; it peels open (a negative-space split down its middle) and
# breaks into drops.

def ink_tear(i, n, size):
    f = Frame(size)
    S = f.S
    c = f.c
    g = rng(41)
    a = -0.5
    d = (math.cos(a), math.sin(a))
    nrm = (-d[1], d[0])
    grow_k = [0.45, 1.0, 1.0, 0.95, 0.85, 0.7][i]

    def P(t, off=0.0):
        return (c + d[0] * f.u(t) + nrm[0] * f.u(off), c + d[1] * f.u(t) + nrm[1] * f.u(off))
    L = 0.82 * grow_k
    path = [P(t, 0.06 * math.sin(t * 4.5 + 0.4)) for t in np.linspace(-L, L, 24)]
    wmax = f.u(0.17 if i else 0.06)
    m = poly_mask([stroke(path, lambda q: wmax * math.sin(q * math.pi) ** 0.7 + 1, cap=False)], S)
    f.fill(m, BODY, ink=4.0)
    seam = poly_mask([stroke(path[4:20], lambda q: wmax * 0.28 * math.sin(q * math.pi) + 1, cap=False)], S)
    f.fill(seam * m, HOT if i <= 2 else LIGHT)
    if i == 0:
        pts = []
        for k in range(8):
            aa = math.tau * k / 8 + 0.3
            pts.append(polar(c, c, f.u(0.3 if k % 2 == 0 else 0.08), aa))
        f.poly([pts], HOT, ink=3.0)
    if i >= 3:  # it peels open
        split = poly_mask([stroke(path[6:18], lambda q: wmax * 0.22 * (i - 2) * math.sin(q * math.pi), cap=False)], S)
        f.cut(split)
    for k in range(6):  # drops flicked off its trailing (lower) side
        t = g.uniform(-0.6, 0.6)
        off = -g.uniform(0.18, 0.3) - 0.12 * max(0, i - 1)
        x, y = P(t, off)
        y += f.u(0.03 * max(0, i - 1) ** 1.5)
        r = f.u(g.uniform(0.03, 0.055) * (1.0 if i else 0.0) * (1 - 0.1 * i))
        if r > 1:
            f.fill(ellipse_mask(x, y, r, r, S), DEEP, ink=2.5)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "dive_trail": (dive_trail, 256, 1, 4, "water", "tail", 0.35),
    "dive_ink": (dive_ink, 256, 1, 4, "void", "tail", 0.35),
    "chip_spray": (chip_spray, 256, 3, 6, "earth", "edge", 0.45),
    "tell_buried": (tell_buried, 320, 2, 4, "dust", "edge", 0.5),
    "tell_pinned": (tell_pinned, 320, 2, 4, "water", "edge", 0.5),
    "tell_molten": (tell_molten, 256, 2, 4, "earth", "edge", 0.5),
    "ink_tear": (ink_tear, 256, 3, 6, "void", "edge", 0.5),
}


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    if frames[0][0].shape[0] != frames[0][0].shape[1]:  # strips: stack rows
        tone = np.concatenate([fr[0] for fr in frames], 0)
        alpha = np.concatenate([fr[1] for fr in frames], 0)
        if mode == "tail":
            xs = np.tile(np.linspace(0, 1, alpha.shape[1]), (alpha.shape[0], 1))
            g = np.clip(xs * (1 - nw) + fbm(alpha.shape, 9, scales=(22, 9, 3)) * nw, 0, 1)
        elif mode == "none":
            g = fbm(alpha.shape, 9, scales=(6, 3, 1))
        else:
            g = erode_field(alpha, 7, mode, nw)
        boil = fbm(alpha.shape, 99, scales=(6, 2, 1))
        sheet = (np.clip(np.stack([tone, g, boil, alpha], -1), 0, 1) * 255 + 0.5).astype(np.uint8)
    else:
        sheet = pack(frames, cols, seed=sum(map(ord, name)), mode=mode, noise_w=nw)
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



# --- drag_line: the axe's drag on the floor (a strip repeated along the line by metres) ----------------------------
# A scraped gouge that tiles along u: two ragged inked banks round a body, a hot core line broken into dashes, chips
# kicked out of the bank. Every curve is periodic in u so the tiles meet. Four boils.

def drag_line(i, n, size):
    f, S, h, y0, P = _strip_canvas(size)
    g = rng(141 + i)
    us = np.linspace(-0.02, 1.02, 80)
    tw = math.tau

    def top_v(u):
        return 0.78 + 0.06 * math.sin(tw * 2 * u + i) + 0.03 * math.sin(tw * 5 * u + 2 * i)

    def bot_v(u):
        return 0.24 + 0.05 * math.sin(tw * 3 * u + 1.3 * i) + 0.03 * math.sin(tw * 7 * u + i)
    body = [P(u, top_v(u)) for u in us] + [P(u, bot_v(u)) for u in us[::-1]]
    f.fill(poly_mask([body], S), BODY, ink=4.0)
    deep = [P(u, bot_v(u) + 0.12) for u in us] + [P(u, bot_v(u)) for u in us[::-1]]
    f.fill(poly_mask([deep], S) * poly_mask([body], S), DEEP)
    lit = [P(u, top_v(u)) for u in us] + [P(u, top_v(u) - 0.1) for u in us[::-1]]
    f.fill(poly_mask([lit], S) * poly_mask([body], S), LIGHT)
    for k in range(3):  # the hot core in dashes
        u0 = (k / 3 + 0.05 * i) % 1.0
        for off in (0.0, -1.0, 1.0):
            pts = [P(u + off, 0.52 + 0.03 * math.sin(tw * 2 * (u + off) + i)) for u in np.linspace(u0, u0 + 0.22, 10)]
            f.fill(poly_mask([stroke(pts, lambda q: h * 0.12 * math.sin(q * math.pi) + 1, cap=False)], S), HOT)
    for k in range(3):  # chips kicked out over the banks
        u = (k / 3 + 0.17 + 0.1 * i) % 1.0
        side = 1 if k % 2 == 0 else -1
        v = (top_v(u) + 0.08) if side > 0 else (bot_v(u) - 0.08)
        x, y = P(u, v)
        r = h * g.uniform(0.05, 0.08)
        f.fill(ellipse_mask(x, y, r * 1.3, r, S), DEEP, ink=3.0)
    return _crop(f, size)


SHEETS["drag_line"] = (drag_line, 256, 1, 4, "earth", "none", 0.9)


if __name__ == "__main__":
    main()
