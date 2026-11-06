"""Air sheets for Awaken's designed effects (fx-air lane, docs/features/designed-fx.md "Air").

Shape language: fat calligraphic wind ribbons that taper at both ends and finish in a curled hook (ukiyo-e /
Wind Waker wind), spiral curls, puffy scalloped cloud wisps, bent speed lines, and things carried in the wind
(leaves, paper scraps, pebbles). Rounded and flowing, never jagged (jagged is lightning's). Drawn in tone like
every designed sheet; the game plays them through the `air` palette row (pale white-mint, one soft shadow tone,
slate ink), so they read as moving air against the dark floor and never as the lightning's electric colour.

Sheets (imported into gen_designed.SHEETS):
    air_ribbon  strip, 4 rows: three boils of one fat wind ribbon with a curl at its head, and a fourth row where
                it has broken into separate curls (the dissolve). Played on the twister's helix bands.
    air_swirl   floor, 8 frames: the twister's foot. Frame 0 pulls in (thin streaks converging), the peak is three
                fat spiral arms with hooked ends and grit, they turn on twos, then break into loose curls.
    air_wisp    sprite, 8 frames: a scalloped cloud puff trailing a curled tail, flung off the twister's top.
    air_gust    sprite, 8 frames, drawn blowing to +x: a puff bursting at the back and two curled ribbons streaming
                ahead with bent speed lines (air slash, Gale Lift, throws, wind dashes). Erodes tail first.
    air_debris  sprite, 8 single frames: leaves, a paper scrap, pebbles, a twig: the things the wind carries
                (played one frame each, through the warm dust palette).
"""
import math

import numpy as np

from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, catmull, ellipse_mask, poly_mask, rng, stroke, wobble_ring)


def lerp(a, b, t):
    return a + (b - a) * t


def ease_out(t):
    return 1 - (1 - t) ** 3


# --- shared shapes --------------------------------------------------------------------------------------------

def curl(x, y, a0, r0, turns=0.85, shrink=0.65, n=24, cw=1.0):
    """A spiral from (x, y) heading along a0, turning `turns` of a circle while its radius shrinks: the hook a
    wind ribbon ends in. cw +1 turns one way, -1 the other."""
    pts = []
    # centre of the first arc: to the side of the heading
    side = a0 + cw * math.pi / 2
    cx, cy = x + math.cos(side) * r0, y + math.sin(side) * r0
    start = math.atan2(y - cy, x - cx)
    for k in range(n + 1):
        t = k / n
        r = r0 * (1 - shrink * t)
        a = start + cw * turns * math.tau * t
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def path_normals(p):
    p = np.asarray(p, np.float64)
    d = np.gradient(p, axis=0)
    d /= np.maximum(1e-6, np.linalg.norm(d, axis=1))[:, None]
    return np.stack([-d[:, 1], d[:, 0]], 1)


def ribbon(f, path, wfun, top=1.0, ink=2.2, light=True, deep=True, hair=0, seed=0, tone=BODY):
    """A fat calligraphic wind ribbon along `path` (px), width wfun(q) for q 0..1. Body tone, a light band along
    one edge (`top` +1 / -1 picks the side), the one shadow tone along the other, inked; `hair` thin flow lines
    inside it. Returns its mask."""
    p = np.asarray(path, np.float64)
    m_ = len(p)
    w = np.array([wfun(i / max(1, m_ - 1)) for i in range(m_)])
    mask = poly_mask([stroke(p, list(w), cap=False)], f.S)
    f.fill(mask, tone, ink=ink)
    nrm = path_normals(p)
    if light:
        lp = p + nrm * (w[:, None] * 0.26 * top)
        f.fill(poly_mask([stroke(lp, list(w * 0.42), cap=False)], f.S) * mask, LIGHT)
    if deep:
        dp = p - nrm * (w[:, None] * 0.34 * top)
        f.fill(poly_mask([stroke(dp, list(w * 0.3), cap=False)], f.S) * mask, DEEP)
    g = rng(seed)
    for k in range(hair):  # flow lines: thin, tapered both ends, along part of the ribbon
        q0 = g.uniform(0.12, 0.4)
        q1 = min(0.95, q0 + g.uniform(0.25, 0.45))
        i0, i1 = int(q0 * (m_ - 1)), int(q1 * (m_ - 1))
        if i1 - i0 < 3:
            continue
        off = g.uniform(-0.18, 0.12)
        hp = p[i0:i1] + nrm[i0:i1] * (w[i0:i1, None] * off)
        hw = max(2.0, f.S * 0.004)
        f.fill(poly_mask([stroke(hp, lambda q: hw * math.sin(q * math.pi) + 0.3, cap=False)], f.S) * mask, DEEP)
    return mask


def taper(peak=0.45, end=0.0, start=0.0, curl_from=None):
    """Width profile 0..1: rises from `start` to 1 at `peak`, falls to `end`; past `curl_from` it narrows fast."""
    def w(q):
        if q < peak:
            v = lerp(start, 1.0, math.sin(q / peak * math.pi / 2) ** 0.8)
        else:
            v = lerp(1.0, end, ((q - peak) / (1 - peak)) ** 1.3)
        return max(0.0, v)
    return w


def puff(f, cx, cy, r, seed, lumps=5, squash=0.8, ink=2.4, rot=0.0, lit=True):
    """A scalloped cloud: a ring of round lumps round a middle one, inked only round the union, lit top-left,
    a shadow crescent at the bottom."""
    g = rng(seed)
    circles = [(cx, cy, r * 0.62)]
    for k in range(lumps):
        a = rot + math.tau * k / lumps + g.uniform(-0.25, 0.25)
        rr = r * g.uniform(0.38, 0.52)
        circles.append((cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55 * squash, rr))
    m = np.zeros((f.S, f.S), np.float32)
    for x, y, rr in circles:
        m = np.maximum(m, ellipse_mask(x, y, rr, rr, f.S))
    f.fill(m, BODY, ink=ink)
    if lit:
        sh = np.zeros_like(m)
        for x, y, rr in circles:
            sh = np.maximum(sh, ellipse_mask(x + rr * 0.1, y + rr * 0.32, rr * 0.86, rr * 0.86, f.S))
        f.fill(np.clip(m - sh, 0, 1) * m, LIGHT)
        dk = np.zeros_like(m)
        for x, y, rr in circles:
            dk = np.maximum(dk, ellipse_mask(x - rr * 0.05, y - rr * 0.3, rr * 0.92, rr * 0.92, f.S))
        f.fill(np.clip(m - dk, 0, 1) * m, DEEP)
    return m


def strip_frame(size):
    """A 4:1 strip drawn on a square canvas (as slash_strip): returns the frame, S, strip height and its top."""
    f = Frame(size * 2)
    S = f.S
    h = S / 4.0
    return f, S, h, (S - h) / 2


def crop_strip(f, size):
    tone, alpha, _ = f.finish()
    s2 = size * 2
    hh = s2 // 4
    y = (s2 - hh) // 2
    return tone[y:y + hh, :], alpha[y:y + hh, :], None


# --- air_ribbon -----------------------------------------------------------------------------------------------
# One wind ribbon across the strip: born thin at the tail (u 0), fattest a little past the middle, curling into a
# hook at the head (u ~0.88). The lit band runs along its top edge (the band's top on the twister), the shadow
# along its bottom. Rows 0-2 boil (the wave and the curl shift a little); row 3 has broken into three curls.

def air_ribbon(i, n, size):
    f, S, h, y0 = strip_frame(size)

    def P(u, v):
        return (u * S, y0 + (1 - v) * h)

    if i < 3:
        ph = i * 0.9
        body = [P(u, 0.5 + 0.13 * math.sin(u * 5.5 + ph) * (1 - u * 0.6) - 0.08 * u) for u in np.linspace(0.0, 0.8, 40)]
        hx, hy = body[-1]
        hx0, hy0 = body[-2]
        a0 = math.atan2(hy - hy0, hx - hx0)
        hook = curl(hx, hy, a0, h * (0.2 + 0.015 * i), turns=0.95, shrink=0.6, n=22, cw=-1.0)
        path = body + hook[1:]
        wmax = h * 0.42
        ribbon(f, catmull(path, 2), lambda q: wmax * taper(0.42, 0.0, 0.05)(q) + 2.5, top=1.0, hair=2, seed=40 + i)
        # a second, thinner ribbon peeling off the back, with its own little curl: wind is never one stroke
        side = [P(u, 0.24 + 0.08 * math.sin(u * 6 + ph + 1)) for u in np.linspace(0.18, 0.55, 18)]
        sx, sy = side[-1]
        sx0, sy0 = side[-2]
        h2 = curl(sx, sy, math.atan2(sy - sy0, sx - sx0), h * 0.1, turns=0.8, shrink=0.55, n=14, cw=1.0)
        ribbon(f, catmull(side + h2[1:], 2), lambda q: h * 0.16 * taper(0.35, 0.0)(q) + 2, top=1.0, deep=False, seed=50 + i)
        return crop_strip(f, size)
    # row 3: broken up, three separate curls drifting apart along the strip
    for k, (u0, u1, v, r) in enumerate([(0.05, 0.28, 0.42, 0.14), (0.36, 0.6, 0.58, 0.17), (0.66, 0.84, 0.46, 0.2)]):
        seg = [P(u, v + 0.06 * math.sin(u * 9 + k)) for u in np.linspace(u0, u1, 12)]
        ex, ey = seg[-1]
        ex0, ey0 = seg[-2]
        hook = curl(ex, ey, math.atan2(ey - ey0, ex - ex0), h * r, turns=0.9, shrink=0.6, n=16, cw=-1.0)
        ribbon(f, catmull(seg + hook[1:], 2), lambda q: h * 0.26 * taper(0.3, 0.0)(q) + 2, top=1.0, seed=60 + k)
    return crop_strip(f, size)


# --- air_swirl ------------------------------------------------------------------------------------------------
# The twister's foot on the floor, seen from above. Frame 0 is the pull: six thin streaks far out, curving in.
# Frame 1 the peak: three fat spiral arms, each tapering to a hooked curl at its outer end, a calm eye, grit
# (dust flecks and pebbles) caught in the arms. Frames 2-5 turn on twos and widen; 6-7 the arms break into curls.

def _spiral(c, r0, r1, a0, sweep, n=40):
    pts = []
    for k in range(n):
        t = k / (n - 1)
        r = lerp(r0, r1, t ** 0.9)
        a = a0 + sweep * t
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    return pts


def air_swirl(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(201)
    if i == 0:  # the pull-in: streaks curving towards the middle
        for k in range(6):
            a = k * math.tau / 6 + 0.3
            p = _spiral(c, f.u(0.95), f.u(0.5), a, -0.9, 20)[::-1]
            p = p[::-1]
            ribbon(f, p, lambda q: f.u(0.07) * math.sin(q * math.pi) ** 0.7 + 1.5, light=False, deep=False, ink=1.6)
        return f.finish()
    t = (i - 1) / (n - 2)
    turn = -0.55 * (i - 1)  # turns on twos
    breaking = i >= n - 2
    grow = lerp(0.82, 1.0, ease_out(min(1.0, t * 2.0)))
    arms = 3
    for k in range(arms):
        a = turn + k * math.tau / arms
        if not breaking:
            p = _spiral(c, f.u(0.16), f.u(0.78 * grow), a, 2.2, 36)
            ex, ey = p[-1]
            ex0, ey0 = p[-2]
            hook = curl(ex, ey, math.atan2(ey - ey0, ex - ex0), f.u(0.1), turns=0.85, shrink=0.6, n=16, cw=-1.0)
            w = f.u(lerp(0.17, 0.13, t))
            ribbon(f, catmull(p + hook[1:], 2), lambda q: w * taper(0.35, 0.0, 0.1)(q) + 2, top=1.0, hair=1, seed=210 + k + i)
        else:  # broken: two short curls per arm, further out
            for j in range(2):
                p = _spiral(c, f.u(0.35 + 0.3 * j), f.u(0.55 + 0.32 * j), a + j * 0.9, 0.9, 14)
                ex, ey = p[-1]
                ex0, ey0 = p[-2]
                hook = curl(ex, ey, math.atan2(ey - ey0, ex - ex0), f.u(0.07), turns=0.85, shrink=0.6, n=12, cw=-1.0)
                ribbon(f, catmull(p + hook[1:], 2), lambda q: f.u(0.09) * taper(0.3, 0.0)(q) + 2, top=1.0, deep=False, seed=230 + k + j)
    # grit caught in the arms: dust flecks (body chips) and pebbles (deep), turning with them
    if not breaking:
        for k in range(9):
            a = turn * 1.3 + k * 2.4 + g.uniform(-0.2, 0.2)
            r = f.u(g.uniform(0.3, 0.85) * grow)
            x, y = c + math.cos(a) * r, c + math.sin(a) * r
            if k % 3 == 0:
                f.poly(wobble_ring(x, y, f.u(0.035), 240 + k, amp=0.2, n=24), DEEP, ink=1.6)
            else:
                L = f.u(0.05)
                d = a + math.pi / 2
                chip = [(x + math.cos(d) * L, y + math.sin(d) * L), (x + math.cos(d + 2.4) * L * 0.5, y + math.sin(d + 2.4) * L * 0.5),
                        (x - math.cos(d) * L * 0.8, y - math.sin(d) * L * 0.8), (x + math.cos(d - 2.2) * L * 0.45, y + math.sin(d - 2.2) * L * 0.45)]
                f.poly(chip, LIGHT, ink=1.4)
    return f.finish()


# --- air_wisp -------------------------------------------------------------------------------------------------
# A scalloped cloud puff with a curled tail trailing behind it (to the left: the game turns it to its flight).

def air_wisp(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    t = i / (n - 1)
    if i == 0:
        puff(f, c + f.u(0.15), c, f.u(0.2), 251, lumps=4)
        return f.finish()
    sc = lerp(0.85, 1.05, ease_out(min(1.0, t * 2)))
    px, py = c + f.u(0.22), c - f.u(0.04) * t
    # the tail: a ribbon from behind the puff, curling under at its end
    tail_len = lerp(0.45, 0.75, t)
    tail = [(px - f.u(0.1) - f.u(tail_len) * q, py + f.u(0.08) * math.sin(q * 3.2 + 0.4)) for q in np.linspace(0, 1, 16)]
    ex, ey = tail[-1]
    ex0, ey0 = tail[-2]
    hook = curl(ex, ey, math.atan2(ey - ey0, ex - ex0), f.u(0.09), turns=0.9, shrink=0.6, n=14, cw=1.0)
    path = catmull(tail + hook[1:], 2)
    if t < 0.75:
        ribbon(f, path, lambda q: f.u(0.15) * (1 - q) ** 0.8 * (1 - 0.3 * t) + 2, top=-1.0, seed=252)
        puff(f, px, py, f.u(0.3) * sc, 253, lumps=5, rot=i * 0.15)
    else:  # breaking: the puff splits into two small ones, the tail a loose curl
        ribbon(f, path, lambda q: f.u(0.08) * math.sin(q * math.pi) + 2, top=-1.0, deep=False, seed=254)
        puff(f, px - f.u(0.05), py - f.u(0.08), f.u(0.17), 255, lumps=4)
        puff(f, px + f.u(0.22), py + f.u(0.1), f.u(0.12), 256, lumps=3)
    return f.finish()


# --- air_gust -------------------------------------------------------------------------------------------------
# A directional gust drawn blowing to +x: a puff bursting at the back, two curled ribbons streaming ahead (one
# hooks up, one down), bent speed lines between them. Frame 0 the squeeze, 1 the burst, then the ribbons run out
# and their curls tighten; erosion takes the back first.

def air_gust(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    t = i / (n - 1)
    if i == 0:  # squeeze: a tight puff with two short lines
        puff(f, c - f.u(0.45), c, f.u(0.22), 301, lumps=4, squash=0.7)
        for s in (-1, 1):
            p = [(c - f.u(0.2) + f.u(0.4) * q, c + s * f.u(0.12) * (1 - q * 0.5)) for q in np.linspace(0, 1, 8)]
            ribbon(f, p, lambda q: f.u(0.05) * math.sin(q * math.pi) + 1.5, light=False, deep=False, ink=1.4)
        return f.finish()
    reach = lerp(0.55, 0.95, ease_out(min(1.0, t * 1.6)))
    # speed lines (bent, thin, behind the ribbons)
    for k, (dy, L0) in enumerate([(-0.3, 0.1), (0.04, 0.0), (0.3, 0.15)]):
        bend = 0.08 * (1 if dy < 0 else -1)
        p = [(c - f.u(0.25) + f.u(L0 + (reach + 0.1 - L0) * q), c + f.u(dy + bend * q * q)) for q in np.linspace(0, 1, 10)]
        ribbon(f, p, lambda q: f.u(0.035) * math.sin(q * math.pi) + 1.2, light=False, deep=False, ink=1.2, tone=LIGHT)
    # the two ribbons
    for s, seed in ((-1, 310), (1, 320)):
        wave = 0.07 * s
        L = reach + 0.35
        body = [(c - f.u(0.45) + f.u(L) * q, c + s * f.u(0.16 + 0.06 * q) + f.u(wave * math.sin(q * 4 + i * 0.5))) for q in np.linspace(0, 1, 20)]
        ex, ey = body[-1]
        ex0, ey0 = body[-2]
        hook = curl(ex, ey, math.atan2(ey - ey0, ex - ex0), f.u(lerp(0.13, 0.09, t)), turns=lerp(0.75, 1.0, t), shrink=0.6, n=16, cw=float(s))
        w = f.u(lerp(0.16, 0.11, t))
        ribbon(f, catmull(body + hook[1:], 2), lambda q: w * taper(0.3, 0.0, 0.15)(q) + 2, top=float(-s), hair=1, seed=seed + i)
    # the burst puff at the back (over the ribbons' roots)
    if t < 0.8:
        puff(f, c - f.u(0.5 + 0.05 * t), c, f.u(lerp(0.3, 0.2, t)), 330 + (i % 2), lumps=5, squash=0.85, rot=i * 0.3)
    return f.finish()


# --- air_debris -----------------------------------------------------------------------------------------------
# What the wind carries, one piece a frame: two leaves, a curled leaf, a paper scrap, a folded scrap, two
# pebbles, a twig. Drawn big in the frame (the game sizes the quad ~0.25 m).

def _leaf(f, c, rot, curlk, seed):
    L, W = f.u(0.72), f.u(0.32)
    pts = []
    for k in range(25):
        q = k / 24
        x = lerp(-L, L, q)
        y = W * math.sin(q * math.pi) ** 0.9 + curlk * f.u(0.3) * (q - 0.5) ** 2
        pts.append((x, y))
    for k in range(24, -1, -1):
        q = k / 24
        x = lerp(-L, L, q)
        y = -W * 0.7 * math.sin(q * math.pi) ** 0.9 + curlk * f.u(0.3) * (q - 0.5) ** 2
        pts.append((x, y))
    cs, sn = math.cos(rot), math.sin(rot)
    poly = [(c + x * cs - y * sn, c + x * sn + y * cs) for x, y in pts]
    m = f.poly(poly, BODY, ink=3.0)
    half = [(c + x * cs - y * sn, c + x * sn + y * cs) for x, y in pts[25:]]
    f.fill(poly_mask([half + [(c - L * cs, c - L * sn)]], f.S) * m, DEEP)
    rib = [(c + x * cs - (curlk * f.u(0.3) * (k / 12 - 0.5) ** 2) * sn, c + x * sn + (curlk * f.u(0.3) * (k / 12 - 0.5) ** 2) * cs)
           for k, x in enumerate(np.linspace(-L * 1.25, L * 0.8, 13))]
    f.poly(stroke(rib, lambda q: f.u(0.05) * (1 - q * 0.7) + 2, cap=False), INK)


def air_debris(i, n, size):
    f = Frame(size)
    c = f.c
    if i in (0, 1, 2):
        _leaf(f, c, [-0.5, 0.9, 2.4][i], [0.0, 0.6, -1.2][i], 400 + i)
    elif i in (3, 4):  # paper scrap: a torn quad, one corner folded over in the light tone
        g = rng(410 + i)
        rot = 0.4 + i
        q = [(-0.6, -0.42), (0.55, -0.5), (0.62, 0.4), (-0.5, 0.48)]
        q = [(x + g.uniform(-0.06, 0.06), y + g.uniform(-0.06, 0.06)) for x, y in q]
        cs, sn = math.cos(rot), math.sin(rot)
        P = [(c + f.u(x) * cs - f.u(y) * sn, c + f.u(x) * sn + f.u(y) * cs) for x, y in q]
        m = f.poly(P, LIGHT, ink=3.0)
        fold = [P[2], (P[2][0] * 0.55 + P[1][0] * 0.45, P[2][1] * 0.55 + P[1][1] * 0.45), (P[2][0] * 0.55 + P[3][0] * 0.45, P[2][1] * 0.55 + P[3][1] * 0.45)]
        f.poly(fold, DEEP, ink=2.0)
        if i == 4:
            f.fill(poly_mask([stroke([P[0], P[2]], [f.u(0.04)] * 2, cap=False)], f.S) * m, BODY)
    elif i in (5, 6):  # pebbles
        r = f.u(0.48 if i == 5 else 0.38)
        m = f.poly(wobble_ring(c, c, r, 420 + i, amp=0.18, lumps=(2, 3, 5), squash=0.8, rot=i), DEEP, ink=3.2)
        f.fill(poly_mask([wobble_ring(c - r * 0.2, c - r * 0.25, r * 0.5, 430 + i, amp=0.2, squash=0.7)], f.S) * m, BODY)
        f.fill(ellipse_mask(c - r * 0.35, c - r * 0.4, r * 0.15, r * 0.1, f.S) * m, LIGHT)
    else:  # a twig with a stub
        p = [(c - f.u(0.75), c + f.u(0.3)), (c - f.u(0.1), c + f.u(0.05)), (c + f.u(0.75), c - f.u(0.25))]
        f.poly(stroke(catmull(p, 6), lambda q: f.u(0.13) * (1 - q * 0.5) + 2, cap=True), DEEP, ink=3.0)
        f.poly(stroke([(c - f.u(0.1), c + f.u(0.05)), (c + f.u(0.1), c + f.u(0.5))], [f.u(0.08), f.u(0.05)], cap=True), DEEP, ink=3.0)
    return f.finish()


AIR_SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "air_ribbon": (air_ribbon, 256, 1, 4, "air", "tail", 0.3),
    "air_swirl": (air_swirl, 384, 4, 8, "air", "edge", 0.5),
    "air_wisp": (air_wisp, 192, 4, 8, "air", "edge", 0.55),
    "air_gust": (air_gust, 256, 4, 8, "air", "tail", 0.35),
    "air_debris": (air_debris, 96, 4, 8, "dust", "edge", 0.6),
}
