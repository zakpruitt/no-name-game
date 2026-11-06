"""Generate the fx-cohesion sheets (round 44, docs/features/designed-fx.md): the tentacle's skin and smear,
the inked ground stamps that replace the flat floor hoops, and the per-element hit pop.

    python tools/vfx_gen/gen_cohesion.py [name ...] [--preview=<dir>]

Same format and conventions as gen_designed.py (tone, erode order, boil, cover; see vfxlib.py). Kept in its own
module so the storm lane and this one can add sheets side by side.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, catmull, ellipse_mask, erode_field, fbm, pack,  # noqa: E402
                    poly_mask, preview, rng, save, star, stroke, wobble_ring)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


# --- tentacle skin: a tiling strip laid along the tentacle (void_tendril.gd) -----------------------------------
# x runs along the tentacle (the tile repeats; the game advances it by arc length over the local width, so the
# pattern keeps its proportions and gets denser towards the thin tip), y across it (0 the back, 1 the belly).
# Back: a deep shadow band with wrinkle ticks. Belly: a light stripe with a row of suckers. One hot highlight
# dash along the back. The silhouette ink is the shader's (a fixed width in metres), so the strip is all body.
# Rows are boil variants (the tentacle re-draws on twos).

def tentacle_skin(i, n, size):
    f = Frame(size * 2)
    S = f.S
    g = rng(71 + i * 13)
    h = S / 4.0
    y0 = (S - h) / 2

    def P(u, v):
        return (u * S, y0 + v * h)

    def tiled(fn):  # draw a feature at u, u-1 and u+1 so the strip wraps
        for off in (-1.0, 0.0, 1.0):
            fn(off)

    # the whole strip in body
    f.fill(poly_mask([[P(0, 0), P(1, 0), P(1, 1), P(0, 1)]], S), BODY)
    # back shadow: a wavy band (periods divide the tile, so it wraps)
    us = np.linspace(0, 1, 160)
    edge = [0.3 + 0.05 * math.sin(u * math.tau * 2 + i * 0.7) + 0.025 * math.sin(u * math.tau * 5 + i) for u in us]
    f.fill(poly_mask([[P(0, -0.1)] + [P(u, e) for u, e in zip(us, edge)] + [P(1, -0.1)]], S), DEEP)
    # belly stripe: light, wavy on its inner edge
    bel = [0.64 + 0.035 * math.sin(u * math.tau * 3 + 1.3 + i * 0.5) for u in us]
    f.fill(poly_mask([[P(0, 1.1)] + [P(u, e) for u, e in zip(us, bel)] + [P(1, 1.1)]], S), LIGHT)
    # wrinkle ticks: tapered curved ink strokes from the back edge into the shadow band
    k_ticks = 6
    for k in range(k_ticks):
        u0 = (k + 0.5) / k_ticks + g.uniform(-0.02, 0.02)
        ln = g.uniform(0.26, 0.42)
        bend = g.uniform(0.02, 0.04)

        def tick(off, u0=u0, ln=ln, bend=bend):
            path = [P(u0 + off + bend * math.sin(q * math.pi * 0.8) - q * 0.025, -0.02 + q * ln) for q in np.linspace(0, 1, 10)]
            f.fill(poly_mask([stroke(path, lambda q: h * 0.05 * (1 - q) ** 0.8 + 0.6, cap=False)], S), INK)
        tiled(tick)
    # suckers: a row along the belly, alternating big / small, each a light disc in an ink rim with a deep pit
    k_suck = 4
    for k in range(k_suck):
        u0 = (k + 0.25) / k_suck + g.uniform(-0.015, 0.015)
        r = h * (0.11 if k % 2 == 0 else 0.085) * g.uniform(0.92, 1.06)
        v0 = 0.82 + (0.03 if k % 2 else -0.01)

        def suck(off, u0=u0, r=r, v0=v0):
            cx, cy = P(u0 + off, v0)
            rim = ellipse_mask(cx, cy, r * 1.25, r * 1.05, S)
            f.fill(rim, INK)
            f.fill(ellipse_mask(cx, cy, r * 1.0, r * 0.82, S), HOT)
            f.fill(ellipse_mask(cx + r * 0.1, cy + r * 0.12, r * 0.45, r * 0.38, S), DEEP)
        tiled(suck)
    # highlight dashes along the back, just inside the shadow band
    for k in range(2):
        u0 = 0.18 + 0.5 * k + g.uniform(-0.03, 0.03)
        ln = g.uniform(0.18, 0.26)

        def dash(off, u0=u0, ln=ln):
            path = [P(u0 + off + q * ln, 0.42 + 0.025 * math.sin(q * math.pi)) for q in np.linspace(0, 1, 10)]
            f.fill(poly_mask([stroke(path, lambda q: h * 0.075 * math.sin(q * math.pi) ** 0.7 + 0.5, cap=False)], S), HOT)
        tiled(dash)
    tone, alpha, _ = f.finish()
    s2 = size * 2
    hh = s2 // 4
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None


# --- tentacle smear: the drawn blur between where the tentacle was and where it is (a fast lash) -------------
# x along the tentacle (0 root .. 1 tip), y from the old pose (0) to the new one (1). Solid light at the front
# edge, breaking into dry-brush streaks towards the back, the streaks longer towards the tip (it moves faster).

def tentacle_smear(i, n, size):
    f = Frame(size * 2)
    S = f.S
    g = rng(91 + i * 5)
    h = S / 4.0
    y0 = (S - h) / 2

    def P(u, v):
        return (u * S, y0 + v * h)

    xx = np.mgrid[0:S, 0:S][1] / S
    us = np.linspace(0, 1, 160)
    # the body of the smear: solid from the front edge back to a wavy line, deeper towards the tip (it moves faster)
    back = [lerp(0.8, 0.62, u ** 0.7) + 0.04 * math.sin(u * 13 + i * 1.7) + 0.03 * math.sin(u * 31 + i) for u in us]
    m = poly_mask([[P(0, 1.05)] + [P(u, e) for u, e in zip(us, back)] + [P(1, 1.05)]], S)
    # echo strokes behind it (the classic multiple-image smear): tapered bands parallel to the tentacle, thinner,
    # shorter and further apart the further back they are, starting towards the tip (the root barely moves)
    for k, (v, w, u0) in enumerate(((0.5, 0.11, 0.18), (0.3, 0.075, 0.36), (0.14, 0.045, 0.55))):
        u0 += g.uniform(-0.04, 0.04)
        path = [P(u, v + 0.03 * math.sin(u * 9 + k + i)) for u in np.linspace(u0, 1.0, 40)]
        m = np.maximum(m, poly_mask([stroke(path, lambda q, w=w: h * w * math.sin(min(1.0, q * 1.4) * math.pi * 0.5) + 0.5, cap=False)], S))
    # the root end fades out (it barely moves)
    m = m * np.clip((xx - 0.05) / 0.15, 0, 1)
    m = (m > 0.5).astype(np.float32)
    f.fill(m, LIGHT, ink=1.2)
    # a body-tone core along the front, a hot line on the leading edge
    core = [lerp(0.9, 0.7, u) + 0.03 * math.sin(u * 23 + i) for u in us]
    f.fill(poly_mask([[P(0, 1.05)] + [P(u, e) for u, e in zip(us, core)] + [P(1, 1.05)]], S) * m, BODY)
    tone, alpha, _ = f.finish()
    s2 = size * 2
    hh = s2 // 4
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None



# --- ground stamps: inked brush rings on the floor (replace the flat Fx.ring / thin_hoop / breaker cue hoops) ---
# Strips laid round an annulus (designed_ink.gd builds it; the strip tiles round the circle, so a big ring and a
# small one keep the same brush). x along the circle, y across the band (0 inner, 1 outer).

# Strips are drawn at ~280 px a metre (a 0.3 m band is 85 px) but seen at ~48 px a metre: an ink line that reads
# as ~2 px on screen is ~10 px here.
INK_PX = 13.0


def _strip_canvas(size, aspect):
    f = Frame(size * 2)
    S = f.S
    h = S / aspect
    y0 = (S - h) / 2
    return f, S, h, y0


def _crop_strip(f, size, aspect):
    tone, alpha, order = f.finish()
    s2 = size * 2
    hh = int(s2 / aspect)
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None


# Shock line: the floor shock of a landing or a burst. Not a hoop: a broken brush stroke with gaps, fat in the
# middle of each piece and dragged thin at its ends, a hot streak along the fattest parts, a few splatter dots
# flung off the outside. Rows are boil variants (re-drawn on twos while it races out).
def stamp_shock(i, n, size):
    aspect = 6.0
    f, S, h, y0 = _strip_canvas(size, aspect)
    g = rng(131 + i * 17)

    def P(u, v):
        return (u * S, y0 + v * h)

    # round 45: one arc a tile over less than half of it (a ring is 3-5 tiles, so ~45% of the circle is drawn), a
    # fat belly near its front and hair-thin ends; the ink is its own tapered stroke (a uniform grow made the thin
    # ends into ink blobs), so the line thins to nothing instead of ending in a dot
    from vfxlib import SS
    u0 = g.uniform(0.04, 0.14)
    ln = g.uniform(0.4, 0.5)
    thick = g.uniform(0.72, 0.86)
    lean = g.uniform(0.2, 0.28)
    bow = g.uniform(-0.06, 0.06)

    def yv(q):
        return 0.52 + bow * math.sin(q * math.pi) + 0.04 * math.sin(q * 6 + i)
    path = [P(u0 + q * ln, yv(q)) for q in np.linspace(0, 1, 40)]

    def shape(q):
        if q < lean:  # the front swells fast, the tail drags out concave to a hair
            return max(0.0, q / lean) ** 0.55
        return max(0.0, (1 - q) / (1 - lean)) ** 1.6

    def wfn(q):
        return h * thick * shape(q) + 0.3

    def inkw(q):
        return wfn(q) + INK_PX * SS * 2.0 * min(1.0, shape(q) * 3.0)
    f.fill(poly_mask([stroke(path, inkw, cap=False)], S), INK)
    m = poly_mask([stroke(path, wfn, cap=False)], S)
    split = [P(u0 + q * ln * 0.5, yv(q) + 0.02) for q in np.linspace(0, 1, 12)]  # a dry-brush split in the tail
    m = m * (1 - poly_mask([stroke(split, lambda q: h * 0.06 * (1 - q) + 0.3, cap=False)], S))
    f.fill(m, LIGHT)
    core = [P(u0 + q * ln, yv(q) - 0.05) for q in np.linspace(0.3, 0.7, 16)]
    f.fill(poly_mask([stroke(core, lambda q: h * thick * 0.3 * math.sin(q * math.pi) + 0.3, cap=False)], S), HOT)
    for k in range(g.integers(1, 3)):  # a flick or two of splatter off the outer edge, near the belly
        uu = u0 + ln * g.uniform(0.2, 0.6)
        r = h * g.uniform(0.06, 0.1)
        cx, cy = P(uu, g.uniform(0.02, 0.08))
        f.fill(ellipse_mask(cx, cy, r * 1.3, r, S), LIGHT, ink=INK_PX * 0.6)
    return _crop_strip(f, size, aspect)


# Breaker cue: a hand-drawn target ring (rows 0-1: brush dashes, each a tapered capsule with a slight hook,
# gaps between) and the closing ring (rows 2-3: one solid fat brush line, a dry-brush notch now and then).
# Both are tinted by the breaker's colour in the shader (the cue's colours carry meaning: paper, gold in the
# window, grey when locked, the ending's colour).
def stamp_cue(i, n, size):
    aspect = 6.0
    f, S, h, y0 = _strip_canvas(size, aspect)
    g = rng(151 + i * 7)

    def P(u, v):
        return (u * S, y0 + v * h)

    if i < 2:  # target: 3 dashes a tile
        k_n = 3
        for k in range(k_n):
            u0 = k / k_n + 0.03 + g.uniform(-0.01, 0.01)
            ln = 1.0 / k_n - 0.09 + g.uniform(-0.02, 0.02)
            path = [P(u0 + q * ln, 0.5 + 0.07 * math.sin(q * math.pi + i) - 0.06 * q * q) for q in np.linspace(0, 1, 20)]
            m = poly_mask([stroke(path, lambda q: h * 0.36 * (min(1.0, q / 0.25) ** 0.5) * (1 - 0.45 * q) + 0.5, cap=True)], S)
            f.fill(m, LIGHT, ink=INK_PX)
            hl = [P(u0 + q * ln, 0.5 + 0.07 * math.sin(q * math.pi + i) - 0.06 * q * q - 0.07) for q in np.linspace(0.12, 0.55, 10)]
            f.fill(poly_mask([stroke(hl, lambda q: h * 0.1 * math.sin(q * math.pi) + 0.3, cap=False)], S), HOT)
    else:  # closing: a solid brush line, thickness breathing, two dry notches
        path = [P(u, 0.5 + 0.04 * math.sin(u * math.tau * 2 + i)) for u in np.linspace(-0.02, 1.02, 60)]
        m = poly_mask([stroke(path, lambda q: h * (0.55 + 0.08 * math.sin(q * math.tau * 3 + i)) + 0.5, cap=False)], S)
        f.fill(m, BODY, ink=INK_PX)
        hl = [P(u, 0.42 + 0.04 * math.sin(u * math.tau * 2 + i)) for u in np.linspace(-0.02, 1.02, 60)]
        f.fill(poly_mask([stroke(hl, lambda q: h * 0.1 + 0.3, cap=False)], S) * (m > 0.5), LIGHT)
    return _crop_strip(f, size, aspect)


# --- per-element hit pops: one designed pop a hit, in the element's own shape language -----------------------
# Replaces the hit star + a cluster of element chips on every element hit (Fx.hit_spark + Fx.element_hit) with one
# drawing. Frame 0 anticipation (a pinched glint), 1 the peak (held), 2-5 the element's own dissolve.

def _glint(f, c, r, rot=0.3):
    f.poly(star(c, c, [r, r * 0.28, r, r * 0.28], r * 0.12, rot=rot, bow=0.45), HOT, ink=2.0)


# Storm: a jagged star with straight zigzag sides and uneven spikes, forked sparks flying off two tips.
def pop_storm(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(201)
    if i == 0:
        _glint(f, c, f.u(0.4))
        return f.finish()
    grow = [0, 1.0, 1.08, 1.13, 1.16, 1.18][i]
    k = 7
    tips = [f.u(r * 0.8) * grow for r in (0.82, 0.5, 0.66, 0.45, 0.9, 0.52, 0.6)]
    rot = -0.4
    if i <= 2:
        pts = star(c, c, tips, f.u(0.22) * grow, rot=rot, bow=0.0, n_edge=2)
        f.poly(pts, BODY, ink=3.0)
        f.poly(star(c - f.u(0.04), c - f.u(0.04), [t * 0.55 for t in tips], f.u(0.12), rot=rot, bow=0.0, n_edge=2), LIGHT)
        if i == 1:
            f.fill(ellipse_mask(c, c, f.u(0.13), f.u(0.13), f.S), HOT)
    else:
        # broken: the spikes fly out as separate zigzag shards, the middle gone
        for s in range(k):
            a = rot + math.tau * s / k
            r0 = f.u(0.25 + 0.12 * (i - 2))
            r1 = tips[s] * (1.0 - 0.12 * (i - 3))
            wv = f.u(0.07) * (1.0 - 0.15 * (i - 3))
            p0 = np.array([math.cos(a), math.sin(a)])
            nrm = np.array([-p0[1], p0[0]])
            mid = (r0 + r1) * 0.5
            poly = [c + p0 * r0 + nrm * wv, c + p0 * mid + nrm * wv * 0.2, c + p0 * r1, c + p0 * mid - nrm * wv * 0.6, c + p0 * r0 - nrm * wv]
            f.poly([tuple(q) for q in poly], BODY if i < 5 else LIGHT, ink=2.0)
    # forked sparks off the two long tips
    if 1 <= i <= 4:
        for s in (0, 4):
            a = rot + math.tau * s / k
            p0 = np.array([math.cos(a), math.sin(a)])
            nrm = np.array([-p0[1], p0[0]])
            base = c + p0 * tips[s] * (0.95 + 0.1 * i)
            path = [base, base + p0 * f.u(0.1) + nrm * f.u(0.05), base + p0 * f.u(0.17) - nrm * f.u(0.03)]
            f.fill(poly_mask([stroke(path, [f.u(0.035), f.u(0.025), 1.0], cap=False)], f.S), HOT, ink=1.2)
    return f.finish()


# Magma: a fat blobby splash with round-tipped tongues, two teardrop globs flung off, holes opening in it.
def pop_magma(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(211)
    if i == 0:
        _glint(f, c, f.u(0.36))
        return f.finish()
    grow = [0, 1.0, 1.1, 1.16, 1.2, 1.22][i]
    body = wobble_ring(c, c, f.u(0.38) * grow, 5, amp=0.12, lumps=(3, 5))
    m = poly_mask([body], f.S)
    for s in range(6):
        a = 0.3 + math.tau * s / 6 + g.uniform(-0.2, 0.2)
        ln = f.u(g.uniform(0.25, 0.42)) * grow
        p0 = np.array([math.cos(a), math.sin(a)])
        path = [c + p0 * f.u(0.2), c + p0 * (f.u(0.3) + ln * 0.6), c + p0 * (f.u(0.3) + ln)]
        m = np.maximum(m, poly_mask([stroke(path, [f.u(0.2), f.u(0.12), f.u(0.15)], cap=True)], f.S))
    if i >= 3:
        hole = wobble_ring(c + f.u(0.05), c - f.u(0.03), f.u(0.1 + 0.11 * (i - 3)), 9 + i, amp=0.2)
        m = m * (1 - poly_mask([hole], f.S))
    f.fill(m, BODY, ink=3.0)
    inner = wobble_ring(c - f.u(0.04), c - f.u(0.05), f.u(0.24) * grow, 7, amp=0.15)
    f.fill(poly_mask([inner], f.S) * m, LIGHT)
    if i <= 2:
        f.fill(ellipse_mask(c - f.u(0.05), c - f.u(0.06), f.u(0.11), f.u(0.09), f.S) * m, HOT)
    # globs: teardrops flying out and falling
    for s, a in enumerate((-1.1, 2.2)):
        d = f.u(0.55 + 0.12 * i)
        x = c + math.cos(a) * d
        y = c + math.sin(a) * d + f.u(0.03 * i * i * 0.4)
        r = f.u(0.075) * (1.0 - 0.1 * i)
        tail = [(x - math.cos(a) * r * 2.6, y - math.sin(a) * r * 2.6)]
        circ = [(x + math.cos(t) * r, y + math.sin(t) * r) for t in np.linspace(a - 1.9, a + 1.9, 12)]
        f.poly(tail + circ, LIGHT, ink=2.0)
    return f.finish()


# Ice: straight-edged faceted shards bursting out (lit facet, shadow facet), a four-point glint at the middle.
def pop_ice(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(221)
    if i == 0:
        _glint(f, c, f.u(0.42), rot=0.0)
        return f.finish()
    out = [0, 0.0, 0.12, 0.26, 0.38, 0.48][i]
    for s in range(6):
        a = 0.2 + math.tau * s / 6 + g.uniform(-0.15, 0.15)
        L = f.u(g.uniform(0.38, 0.6)) * (1.0 - 0.12 * max(0, i - 2))
        W = f.u(g.uniform(0.11, 0.16))
        p0 = np.array([math.cos(a), math.sin(a)])
        nrm = np.array([-p0[1], p0[0]])
        b = c + p0 * f.u(0.08 + out)
        tip = b + p0 * L
        left = b + p0 * L * 0.35 + nrm * W
        right = b + p0 * L * 0.3 - nrm * W * 0.8
        f.poly([tuple(b), tuple(left), tuple(tip), tuple(right)], BODY, ink=2.4)
        f.poly([tuple(b), tuple(left), tuple(tip)], LIGHT)
        if i <= 3:
            st = [b + p0 * L * 0.45 + nrm * W * 0.35, b + p0 * L * 0.8 + nrm * W * 0.12]
            f.fill(poly_mask([stroke(st, [f.u(0.025), f.u(0.012)], cap=False)], f.S), HOT)
    if i <= 2:
        _glint(f, c, f.u(0.3 if i == 1 else 0.2), rot=0.0)
    return f.finish()


# Dark: an ink splat: tapered curling strokes out of a blot with a negative-space hole, splatter dots.
def pop_dark(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(231)
    if i == 0:
        _glint(f, c, f.u(0.36), rot=0.6)
        return f.finish()
    grow = [0, 1.0, 1.1, 1.15, 1.18, 1.2][i]
    m = poly_mask([wobble_ring(c, c, f.u(0.26) * grow, 3, amp=0.18, lumps=(2, 3, 5))], f.S)
    for s in range(5):
        a = -0.5 + math.tau * s / 5 + g.uniform(-0.3, 0.3)
        ln = f.u(g.uniform(0.42, 0.62)) * grow
        curl = g.choice([-1, 1]) * g.uniform(0.6, 1.1)
        path = []
        for q in np.linspace(0, 1, 16):
            aa = a + curl * q * q
            path.append((c + math.cos(aa) * (f.u(0.15) + ln * q), c + math.sin(aa) * (f.u(0.15) + ln * q)))
        m = np.maximum(m, poly_mask([stroke(path, lambda q: f.u(0.15) * (1 - q) ** 1.3 + 2, cap=False)], f.S))
    hole_r = f.u(0.08 + 0.07 * max(0, i - 1))
    m = m * (1 - ellipse_mask(c + f.u(0.03), c - f.u(0.02), hole_r, hole_r * 0.85, f.S))
    f.fill(m, BODY, ink=3.0)
    # the lit edge: a body-tone crescent on the upper-left of the blot, a hot nick
    f.fill(poly_mask([wobble_ring(c - f.u(0.07), c - f.u(0.08), f.u(0.16) * grow, 4, amp=0.2)], f.S) * m, LIGHT)
    if i <= 2:
        f.fill(ellipse_mask(c - f.u(0.12), c - f.u(0.12), f.u(0.05), f.u(0.035), f.S) * m, HOT)
    for s in range(6):
        a = g.uniform(0, math.tau)
        d = f.u(g.uniform(0.55, 0.8)) * (1 + 0.08 * i)
        r = f.u(g.uniform(0.02, 0.045))
        f.fill(ellipse_mask(c + math.cos(a) * d, c + math.sin(a) * d, r, r, f.S), LIGHT, ink=2.0)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "tentacle_skin": (tentacle_skin, 256, 1, 3, "void", "none", 0.9),
    "tentacle_smear": (tentacle_smear, 256, 1, 2, "void", "tail", 0.35),
    "stamp_shock": (stamp_shock, 256, 1, 4, "hit", "edge", 0.6),
    "stamp_cue": (stamp_cue, 256, 1, 4, "gold", "edge", 0.5),
    "pop_storm": (pop_storm, 256, 3, 6, "wind", "center", 0.45),
    "pop_magma": (pop_magma, 256, 3, 6, "earth", "edge", 0.5),
    "pop_ice": (pop_ice, 256, 3, 6, "water", "edge", 0.35),
    "pop_dark": (pop_dark, 256, 3, 6, "void", "edge", 0.5),
}


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    if frames[0][0].shape[0] != frames[0][0].shape[1]:  # strips: stack rows
        tone = np.concatenate([fr[0] for fr in frames], 0)
        alpha = np.concatenate([fr[1] for fr in frames], 0)
        g = erode_field(alpha, 7, mode, nw) if mode not in ("none", "tail") else fbm(alpha.shape, 9, scales=(6, 3, 1))
        if mode == "tail":
            xs = np.tile(np.linspace(0, 1, alpha.shape[1]), (alpha.shape[0], 1))
            g = np.clip(xs * (1 - nw) + fbm(alpha.shape, 9, scales=(22, 9, 3)) * nw, 0, 1)
        boil = fbm(alpha.shape, 99, scales=(6, 2, 1))
        sheet = (np.clip(np.stack([tone, g, boil, alpha], -1), 0, 1) * 255 + 0.5).astype(np.uint8)
    else:
        erode = None
        if mode == "none":
            erode = [fr[2] if fr[2] is not None else fbm(fr[1].shape, 5 + k) for k, fr in enumerate(frames)]
            erode = [np.clip(e * (1 - nw) + fbm(e.shape, 50 + k, scales=(4, 2, 1)) * nw, 0, 1) for k, e in enumerate(erode)]
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
