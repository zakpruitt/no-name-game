"""Generate the fx-finish sheets (round 46, docs/features/designed-fx.md "Round 46"): the Awakening as an
authored event (ink lines pulled in, a crown of gold flame tongues, a sunburst on the floor), the combo halos.

    python tools/vfx_gen/gen_finish.py [name ...] [--preview=<dir>]

Same format as gen_designed.py / gen_cohesion.py (tone, erode order, boil, cover; see vfxlib.py), its own module
so lanes add sheets side by side. Registered at runtime by scripts/designed_finish.gd (DESIGNED.extra_sheets).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, SS, Frame, catmull, ellipse_mask, erode_field, fbm, grow,  # noqa: E402
                    pack, poly_mask, preview, rng, save, star, stroke, wobble_ring)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def ease_out(t):
    return 1 - (1 - t) ** 2


def polar(c, r, a):
    return c + math.cos(a) * r, c + math.sin(a) * r


def wedge(a, r0, r1, w0, w1, c, bend=0.0, n=14):
    """A tapered radial stroke from r0 (width w0) to r1 (width w1) at angle a, bowed sideways by `bend` (radians
    across its length)."""
    path = []
    for k in range(n):
        t = k / (n - 1)
        r = lerp(r0, r1, t)
        aa = a + bend * math.sin(t * math.pi)
        path.append(polar(c, r, aa))
    return stroke(path, lambda t: max(0.0, lerp(w0, w1, t)), cap=False)


# --- awaken_gather: the anticipation, ink focus lines pulled in to him ----------------------------------------
# A camera-facing ring of manga focus lines round the hero's chest: fat at the outside, needle-pointed inward,
# gold with an ink rim (black alone vanishes on the indigo floor). Frame by frame their inner points race in
# towards him and the outer ends follow, until the last frame snaps them into a tight hot ring of sparks that
# never reaches his body (a clear hole of HOLE of the half-frame).

HOLE = 0.27


def awaken_gather(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(401)
    k_lines = 18
    angs = [math.tau * k / k_lines + g.uniform(-0.12, 0.12) for k in range(k_lines)]
    lens = [g.uniform(0.75, 1.15) for _ in range(k_lines)]
    widths = [g.uniform(0.75, 1.25) for _ in range(k_lines)]
    t = i / (n - 2) if i < n - 1 else 1.0
    if i < n - 1:
        inner = lerp(0.78, HOLE + 0.02, ease_out(t))
        for k in range(k_lines):
            if k % 3 == 2 and i < 1:  # the first frame only has some of them: they arrive
                continue
            ln = lerp(0.58, 0.3, t) * lens[k]
            r_in = inner + 0.03 * (k % 3)
            r0 = min(0.99, r_in + ln)
            w = f.u(lerp(0.06, 0.075, t)) * widths[k]
            m = poly_mask([wedge(angs[k], f.u(r0), f.u(r_in), w, 0.0, c)], f.S)
            f.fill(m, BODY, ink=2.4)
            core = poly_mask([wedge(angs[k], f.u(r0 - 0.03), f.u(r_in + 0.08), w * 0.36, 0.0, c)], f.S)
            f.fill(core * m, LIGHT)
        # gold motes sucked in along the gaps, stretched into teardrops pointing in
        for k in range(10):
            a = math.tau * (k + 0.5) / 10 + g.uniform(-0.1, 0.1)
            r = lerp(0.9, HOLE + 0.08, ease_out(min(1.0, t * 1.1 + (k % 3) * 0.08)))
            dr = f.u(0.022)
            tail = f.u(lerp(0.03, 0.09, t))
            p0 = polar(c, f.u(r), a)
            p1 = polar(c, f.u(r) + tail, a)
            m = poly_mask([stroke([p1, p0], [0.0, dr * 2], cap=True)], f.S)
            f.fill(m, HOT, ink=1.6)
    else:  # the snap: a ring of short hot strokes just outside him, about to burst
        for k in range(k_lines):
            a = angs[k] + 0.08
            r0 = HOLE + 0.02
            r1 = r0 + 0.1 * lens[k]
            m = poly_mask([wedge(a, f.u(r1), f.u(r0), f.u(0.05) * widths[k], f.u(0.008), c)], f.S)
            f.fill(m, HOT, ink=2.2)
    return f.finish()


# --- awaken_crown: the held peak, a crown of gold flame tongues round him ------------------------------------
# Stands on a ground line (the quad's pivot, anchor) behind the hero, depth tested, so he stays in front of it.
# Tongues rise off a ground ellipse round his feet and sweep outward in S curves to pointed tips, each body gold
# with a light inner tongue and a hot root, inked. The middle stays open (he stands there) save short tongues
# that frame him; the tallest are at the sides. Frame 0 is the squashed burst (anticipation), 1-2 the peak and
# its boil, then the tongues lift off the floor, the tips throw licks, and they break into rising licks and flecks.

GROUND = 0.83  # of the frame: the ground line (anchor y = 0.5 - GROUND)


def _tongue(f, base, up, h, w, lean, ph, t0=0.0, t1=1.0, wig=0.22):
    """Path and widths of one flame tongue from `base`, rising h, leaning `lean` (share of h sideways)."""
    pts = []
    m = 18
    for k in range(m):
        t = lerp(t0, t1, k / (m - 1))
        x = base[0] + lean * h * t ** 1.4 + wig * w * math.sin(t * math.pi * 1.6 + ph) * t
        y = base[1] - up * h * t
        pts.append((x, y))

    def width(u):
        t = lerp(t0, t1, u)
        belly = math.sin(min(1.0, t * 1.25) * math.pi * 0.62 + 0.25)
        return w * max(0.0, belly) * (1 - t) ** 0.55
    return pts, width


def awaken_crown(i, n, size):
    f = Frame(size)
    S = f.S
    c = f.c
    gy = GROUND * S
    g = rng(733)
    # seven fat tongues (x on the ground ellipse in half-frames, height, outward lean, width, phase); the tallest at
    # the sides, short ones behind him, overlapping at the roots so the crown is one inked silhouette
    xs = [-0.52, -0.35, -0.16, 0.02, 0.2, 0.37, 0.54]
    spots = []
    for k, x in enumerate(xs):
        hh = lerp(0.5, 1.0, min(1.0, abs(x) / 0.52) ** 0.8) * g.uniform(0.9, 1.08)
        spots.append((x, hh, x * 0.36 + g.uniform(-0.04, 0.04), g.uniform(0.9, 1.1), g.uniform(0, math.tau)))
    if i == 0:
        hk, lift, life = 0.42, 0.0, 0.0
    elif i <= 2:
        hk, lift, life = [1.08, 1.0][i - 1], 0.0, 0.0
    else:
        u = (i - 2) / (n - 3)
        hk, lift, life = lerp(1.04, 1.16, u), lerp(0.18, 0.78, u ** 0.85), u
    H = f.u(1.28)
    W = f.u(0.3) * (1.35 if i == 0 else 1.0) * (1 - 0.45 * life)

    def tongue(x, hh, ln, wk, ph, hs=1.0, ws=1.0, t0=None, dx=0.0):
        base = (c + f.u(x) + dx, gy - f.u(0.03) * (1 - abs(x)))
        h = H * hh * hk * hs
        w = W * wk * ws
        ph2 = ph + i * 1.1
        pts = []
        m_ = 22
        a0 = lift if t0 is None else t0
        for k in range(m_):
            t = lerp(a0, 1.0, k / (m_ - 1))
            px = base[0] + ln * h * t ** 1.3 + 0.55 * w * math.sin(t * math.pi * 1.7 + ph2) * t
            pts.append((px, base[1] - h * t))

        def wf(u):
            t = lerp(a0, 1.0, u)
            return w * max(0.0, math.sin(min(1.0, t * 1.4) * math.pi * 0.6 + 0.3)) * (1 - t) ** 0.7
        out = [stroke(pts, wf, cap=True)]
        # a side flick off the outer flank: a short tongue curling outward from the middle (a flame, not a blade)
        if hs == 1.0 and ws == 1.0 and abs(x) > 0.15:
            k0 = int(m_ * 0.42)
            if k0 < len(pts) - 2 and lerp(a0, 1.0, k0 / (m_ - 1)) > a0 + 0.02:
                sgn = 1 if x > 0 else -1
                q0 = pts[k0]
                fl = [(q0[0] + sgn * w * 0.75 * (j / 7) ** 0.7, q0[1] - h * 0.34 * (j / 7)) for j in range(8)]
                out.append(stroke(fl, lambda u: w * 0.42 * (1 - u) ** 0.9, cap=False))
        return out, pts

    body, lights, hots, tips = [], [], [], []
    if i < n - 1:
        for sp in spots:
            polys, pts = tongue(*sp)
            body += polys
            tips.append((pts[-1], sp))
            lp, _ = tongue(*sp, hs=0.74, ws=0.5, dx=-f.u(0.015))
            lights += lp
            if lift < 0.3:
                hp, _ = tongue(*sp, hs=0.3, ws=0.55)
                hots += hp
    lip = None
    if i <= 2:
        rx, ry = f.u(0.72 if i else 0.8), f.u(0.08)
        lip = wobble_ring(c, gy - ry * 0.9, rx, 91 + i, amp=0.06, squash=ry / rx)  # (above the ground line: the floor clips below it)
        body.append(lip)
    if body:
        M = poly_mask(body, S)
        f.fill(M, BODY, ink=3.0)
        if lights:
            f.fill(poly_mask(lights, S) * M, LIGHT)
        if hots:
            f.fill(poly_mask(hots, S) * M, HOT)
        if lip is not None:
            f.fill(ellipse_mask(c, gy - f.u(0.075), f.u(0.6), f.u(0.045), S) * M, HOT)
    # licks thrown off the tips as they burn out (teardrops trailing down to where they came from)
    if i >= 3:
        for (tip, sp) in tips[::1 if life < 0.5 else 2]:
            ln, ph = sp[2], sp[4]
            rise = f.u(lerp(0.08, 0.3, life))
            x = tip[0] + ln * f.u(0.12)
            y = tip[1] - rise
            r = f.u(lerp(0.04, 0.022, life))
            drop = stroke([(x - ln * r, y + r * 3.2), (x, y)], [0.0, r * 2.0], cap=True)
            f.fill(poly_mask([drop], S), LIGHT, ink=2.0)
    if i == n - 1:
        for sp in spots[::2]:
            x = c + f.u(sp[0]) + sp[2] * f.u(0.5)
            y = gy - H * sp[1] * 1.3
            r = f.u(0.022)
            f.fill(poly_mask([stroke([(x, y + r * 3), (x, y)], [0.0, r * 2], cap=True)], S), LIGHT, ink=1.8)
    return f.finish()


# --- awaken_floor: the sunburst on the floor (the reach the foes are blown out of) ---------------------------
# Not a hoop: a ring of fat gold rays thrown outward from his feet, each a long wedge pointed at the outside,
# racing out and thinning, then eaten from their outer ends.

def awaken_floor(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(517)
    t = i / (n - 1)
    a0 = g.uniform(0, math.tau)
    # three clusters of rays with gaps between them (never a closed sawblade ring), uneven lengths
    rays = []
    for cl in range(3):
        mid = a0 + math.tau * cl / 3 + g.uniform(-0.2, 0.2)
        for j in range(g.integers(3, 5)):
            rays.append((mid + (j - 1.5) * 0.26 + g.uniform(-0.06, 0.06), g.uniform(0.6, 1.3), g.uniform(-0.08, 0.08)))
    for k, (a, ln, bend) in enumerate(rays):
        w = f.u(g.uniform(0.11, 0.15)) * lerp(1.0, 0.5, t)
        back = lerp(0.22, 0.6, ease_out(t)) + (k % 2) * 0.05
        front = min(0.97, back + lerp(0.24, 0.32, t) * ln + (0.1 if i == 1 else 0.0))
        if i == 0:
            front = back + 0.14 * ln
        m = poly_mask([wedge(a, f.u(back), f.u(front), w, 0.0, c, bend=bend)], f.S)
        f.fill(m, BODY, ink=2.4)
        core = poly_mask([wedge(a, f.u(back + 0.01), f.u(back + (front - back) * 0.6), w * 0.42, 0.0, c, bend=bend)], f.S)
        f.fill(core * m, HOT if t < 0.4 else LIGHT)
    return f.finish()


# --- chain_halo: the combo-climb flourish behind a hit (Fx.chain_spark), three tiers in one sheet -------------------
# Frames 4k..4k+3 are tier k+1. A four-point sparkle (long concave cross, the "it is climbing" glint) with diamond
# glints; tier 2 adds a ring of short strokes thrown out round it; tier 3 adds more strokes and two broken brush arcs.
# Frame 0 pinched, 1 the peak with a hot core, 2 turned and thinner, 3 broken to its tips.

def _sparkle(f, c, r, rot, thin, tone_in=LIGHT):
    tips = [r, r * 0.55, r, r * 0.55]
    m = poly_mask([star(c, c, tips, r * thin, rot=rot, bow=0.42)], f.S)
    f.fill(m, BODY, ink=2.4)
    f.fill(poly_mask([star(c, c, [t * 0.6 for t in tips], r * thin * 0.6, rot=rot, bow=0.42)], f.S) * m, tone_in)
    return m


def chain_halo(i, n, size):
    f = Frame(size)
    c = f.c
    tier, k = divmod(i, 4)
    g = rng(611 + tier * 17)
    rot = 0.25
    r = f.u([0.42, 0.5, 0.58][tier])
    rr = [0.45, 1.0, 0.95, 0.85][k]
    thin = [0.16, 0.22, 0.17, 0.1][k]
    n_str = [0, 7, 11][tier]
    # strokes thrown out round it (behind the sparkle)
    for j in range(n_str):
        a = math.tau * j / n_str + g.uniform(-0.15, 0.15)
        back = f.u(lerp(0.36, 0.62, k / 3)) * (1.0 + tier * 0.12)
        ln = f.u(g.uniform(0.16, 0.28)) * (1 - k * 0.22)
        if k == 0:
            continue
        w = f.u(0.05) * (1 - k * 0.2)
        m = poly_mask([wedge(a, back, back + ln, w, 0.0, c)], f.S)
        f.fill(m, BODY, ink=2.0)
    if tier == 2 and 1 <= k <= 2:  # two broken brush arcs
        for j in range(2):
            a0 = g.uniform(0, math.tau) + j * math.pi
            rad = f.u(0.74 + 0.06 * k)
            pts = [polar(c, rad, a0 + t * 1.3) for t in np.linspace(0, 1, 18)]
            f.fill(poly_mask([stroke(pts, lambda u: f.u(0.05) * math.sin(u * math.pi) ** 0.6, cap=False)], f.S), LIGHT, ink=2.0)
    if k < 3:
        m = _sparkle(f, c, r * rr, rot + k * 0.12, thin)
        if k == 1:
            f.fill(ellipse_mask(c, c, f.u(0.07), f.u(0.07), f.S) * m, HOT)
    else:  # broken: its four tips flung apart
        for j in range(4):
            a = rot + j * math.pi / 2
            ln = r * (1.0 if j % 2 == 0 else 0.6)
            p0 = polar(c, ln * 0.55, a)
            p1 = polar(c, ln * 1.05, a)
            f.fill(poly_mask([stroke([p0, p1], [f.u(0.035), 0.0], cap=True)], f.S), LIGHT, ink=1.8)
    # diamond glints
    for j in range(2 + tier):
        if k == 0:
            break
        a = g.uniform(0, math.tau)
        d = f.u(g.uniform(0.5, 0.8))
        x, y = polar(c, d, a)
        q = f.u(0.05) * (1.2 - k * 0.25)
        f.poly([(x, y - q * 1.6), (x + q, y), (x, y + q * 1.6), (x - q, y)], HOT, ink=1.6)
    return f.finish()


# --- daze_star: a fat cartoon star circling a dazed head (Fx.daze), four boil frames ---------------------------

def daze_star(i, n, size):
    f = Frame(size)
    c = f.c
    rot = -math.pi / 2 + [0.0, 0.12, 0.05, -0.1][i]
    r = f.u(0.82)
    tips = [r * t for t in [1.0, 0.95, 1.0, 0.97, 0.98]]
    pts = star(c, c, tips, r * 0.5, rot=rot, bow=0.12)
    sq = [1.0, 0.92, 1.0, 1.06][i]
    pts = [(c + (x - c) * sq, c + (y - c) / sq) for x, y in pts]
    m = poly_mask([pts], f.S)
    f.fill(m, BODY, ink=3.2)
    hl = star(c - f.u(0.12), c - f.u(0.14), [t * 0.5 for t in tips], r * 0.26, rot=rot, bow=0.15)
    f.fill(poly_mask([hl], f.S) * m, LIGHT)
    f.fill(ellipse_mask(c - f.u(0.25), c - f.u(0.3), f.u(0.1), f.u(0.13), f.S) * m, HOT)
    return f.finish()


# --- combo_burst: a named combo landing (Fx.combo_pop): strokes bursting out all round him -----------------------
# Manga burst lines thrown outward from a clear hole round him (never over him): frame 0 short and fat at the hole's
# edge, then they race out and stretch, then snap thin and break to dashes.

def combo_burst(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(907)
    k_l = 14
    t = i / (n - 1)
    for j in range(k_l):
        a = math.tau * j / k_l + g.uniform(-0.12, 0.12)
        ln = g.uniform(0.65, 1.3)
        back = lerp(0.46, 0.74, ease_out(t)) + g.uniform(0.0, 0.04)
        front = min(0.99, back + lerp(0.42, 0.22, t) * ln)
        w = f.u(lerp(0.085, 0.04, t)) * g.uniform(0.8, 1.2)
        path = [polar(c, f.u(lerp(back, front, u)), a) for u in np.linspace(0, 1, 14)]
        # fat at the inner end (round cap), drawn out to a needle at the outside: thrown out from him
        m = poly_mask([stroke(path, lambda u: w * (1 - u) ** 0.9 + 0.5, cap=True)], f.S)
        f.fill(m, BODY, ink=2.2)
        if t < 0.6:
            core = [polar(c, f.u(lerp(back, front, u)), a) for u in np.linspace(0.04, 0.55, 8)]
            f.fill(poly_mask([stroke(core, [w * 0.4, w * 0.25, 0.0], cap=False)], f.S) * m, HOT if i <= 1 else LIGHT)
    return f.finish()


# --- echo_axe: the spirit echo's ghost axe as a drawn afterimage (spirit_echo.gd, designed) -------------------
# The ancestor's axe head flying the swing's outer arc: a fat crescent blade with a lit edge band and a hot glint,
# a stub of haft, and behind it (the -x side: the game turns the sprite so +x is the way it flies) two echo copies of
# its edge, each a band dimmer and thinner (the classic multiple-image smear). Frame 0 the faint leading outline,
# 1-2 the solid head with the echoes (boil), 3 just the edge echoes thinning. Never a slab: the haft is a stub.

def _axe_head(f, cx, cy, s, rot=0.0):
    """Polygon of a bearded axe head, its eye at (cx - 0.85 s, cy), the edge towards +x, s = half its height:
    a fat convex edge whose horns hook back, concave top and bottom running in to a narrow back at the eye."""
    def q(p0, p1, ctrl, m=10):
        return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * ctrl[0] + t * t * p1[0],
                 (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * ctrl[1] + t * t * p1[1]) for t in np.linspace(0, 1, m)]
    loc = []
    loc += [(-0.55 + math.cos(a) * 1.0, math.sin(a) * 1.0) for a in np.linspace(-0.98, 0.98, 18)]  # the edge
    loc += q((-0.08, 0.86), (-0.2, 1.02), (-0.06, 1.0), 4)  # bottom horn hooks back
    loc += q((-0.2, 1.02), (-0.78, 0.26), (-0.36, 0.42))  # concave beard
    loc += [(-1.0, 0.24), (-1.0, -0.24)]  # the back at the eye
    loc += q((-0.78, -0.26), (-0.2, -1.0), (-0.38, -0.4))  # concave top
    loc += q((-0.2, -1.0), (-0.08, -0.86), (-0.06, -0.98), 4)
    c_, s_ = math.cos(rot), math.sin(rot)
    return [(cx + (x * c_ - y * s_) * s, cy + (x * s_ + y * c_) * s) for x, y in loc]


def _edge_band(f, cx, cy, s, w, a0=-1.1, a1=1.1):
    path = [(cx + (-0.55 + math.cos(a)) * s, cy + math.sin(a) * s) for a in np.linspace(a0, a1, 18)]
    return stroke(path, lambda u: w * math.sin(u * math.pi) ** 0.5, cap=False)


def echo_axe(i, n, size):
    f = Frame(size)
    c = f.c
    s = f.u(0.4)
    cx = c + f.u(0.32)
    # echoes behind (drawn first): edge bands only, a band dimmer each
    if i >= 1:
        for k, (dx, tone, wk) in enumerate([(-0.42, LIGHT, 0.6), (-0.8, BODY, 0.42)]):
            if i == 3 and k == 0:
                dx -= 0.12
            m = poly_mask([_edge_band(f, cx + f.u(dx), c, s * (0.95 - 0.08 * k), f.u(0.1) * wk * (0.7 if i == 3 else 1.0))], f.S)
            f.fill(m, tone, ink=2.0)
    if i in (1, 2):
        # haft stub out of the eye, back towards the hand (-x, a little down)
        haft = stroke([(cx - s * 0.8, c), (cx - s * 1.7, c + s * 0.3)], [f.u(0.07), f.u(0.05)], cap=True)
        f.fill(poly_mask([haft], f.S), DEEP, ink=2.6)
        head = _axe_head(f, cx, c, s * (1.0 if i == 1 else 0.97), rot=0.04 * (i - 1))
        m = poly_mask([head], f.S)
        f.fill(m, BODY, ink=3.0)
        # the lit edge band and a hot glint on it
        f.fill(poly_mask([_edge_band(f, cx, c, s * 0.97, f.u(0.12))], f.S) * m, LIGHT)
        gx, gy = cx + (-0.55 + math.cos(-0.5) * 0.9) * s, c + math.sin(-0.5) * s * 0.9
        f.poly([(gx, gy - f.u(0.07)), (gx + f.u(0.03), gy), (gx, gy + f.u(0.07)), (gx - f.u(0.03), gy)], HOT)
        # the eye: a negative-space hole
        f.cut(ellipse_mask(cx - s * 0.82, c, s * 0.09, s * 0.14, f.S))
    elif i == 0:  # the faint leading outline: just the edge, thin
        m = poly_mask([_edge_band(f, cx, c, s * 0.9, f.u(0.06))], f.S)
        f.fill(m, LIGHT, ink=2.0)
    else:  # 3: the head is gone, a thin edge left where it was
        m = poly_mask([_edge_band(f, cx + f.u(0.05), c, s, f.u(0.05))], f.S)
        f.fill(m, LIGHT, ink=1.6)
    return f.finish()


# --- rock_boulder: Rockslide's boulder (mid_beats.boulder_drop, comic_boulder.gd; redrawn fx-queue-a) ---------------
# Played through the "rock" palette row: the dust row's stone tones with magma only as the hot tone, so the rock is
# stone and only its cracks glow (fx-language: rock is stone, magma is only what glows). Was a flat orange blob under
# three straight bars, landing on an orange spiky star. Now one chunky faceted stone (straight-sided, a flat bottom,
# a lit top facet and a shadow facet: flat cel cuts, no gradient), fat ink.
# Frame 0 (held over the fall): the stone stretched a touch, three tapered speed lines trailing up off it, uneven.
# 1 the landing: squashed, three hot cracks run from one point to its rim (the one hot area), stone lumps of dust
# kicked out low on both sides (round lumps, flat bottoms; no star). 2 settles, the cracks wider. 3 it splits along
# the cracks into three chunks a little apart, hot light in the gaps. 4-6 the chunks tumble out and down, the
# broken faces cooling (hot only on 4), chunky pebbles with them, the dust lumps lifting and thinning. 7 crumbs.

_ROCK = [(-0.95, 0.28), (-0.82, -0.42), (-0.32, -0.9), (0.36, -0.86), (0.9, -0.42), (1.0, 0.22), (0.76, 0.66),
         (0.05, 0.74), (-0.66, 0.68)]
_SPLIT = (2, 5, 8)  # the cracks run from the middle to these corners; the chunks are the three sectors between


def _rock_mid():
    return (0.06, -0.06)


def _rock_pts(idx, cx, cy, r, sx, sy, rot=0.0, about=None):
    """Outline points (unit coords) to frame px, squashed, turned `rot` round `about` (unit coords)."""
    ax, ay = about if about is not None else (0.0, 0.0)
    out = []
    for p in idx:
        x, y = p[0] - ax, p[1] - ay
        x, y = x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)
        out.append((cx + (x + ax) * r * sx, cy + (y + ay) * r * sy))
    return out


def _stone(f, pts, r, ink=3.4, lit=True):
    """A chunk of stone: body, a lit facet cut off its top-left, a shadow facet off its bottom-right, inked."""
    m = poly_mask([pts], f.S)
    f.fill(m, BODY, ink=ink)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
    S = f.S
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    if lit:
        top = ((xx - cx) * 0.55 + (yy - cy) < -r * 0.22).astype(np.float32)
        f.fill(top * m, LIGHT)
    low = ((xx - cx) * 0.8 + (yy - cy) * 0.9 > r * 0.18).astype(np.float32)
    f.fill(low * m, DEEP)
    # two short ink facet lines where the planes meet (chunky stone, not a pebble)
    if lit and r > f.u(0.1):
        for (ax, ay), (bx, by) in (((-0.62, -0.05), (-0.1, -0.2)), ((0.25, 0.2), (0.62, 0.05))):
            f.fill(poly_mask([stroke([(cx + ax * r, cy + ay * r), (cx + bx * r, cy + by * r)], [f.u(0.008), f.u(0.014), 1.0], cap=False)], f.S) * m, INK)
    return m


def _dust_lumps(f, cx, base, r, u, seed, side_k=(1.0, 0.8)):
    """Stone dust kicked out low on both sides of the landing: round lumps on a flat bottom, a lit top on each."""
    g = rng(seed)
    lumps = []
    for side, k in ((-1, side_k[0]), (1, side_k[1])):
        for j in range(3):
            d = r * (0.9 + 0.42 * j) * lerp(0.9, 1.35, u) * k
            rr = r * (0.34 - 0.07 * j) * lerp(1.0, 0.7, u) * g.uniform(0.85, 1.1)
            lumps.append((cx + side * d, base - rr * 0.7 - r * 0.25 * u * (j + 1) * 0.5, rr))
    polys = [wobble_ring(x, y, rr, seed + q, amp=0.08, lumps=(3, 5), n=28) for q, (x, y, rr) in enumerate(lumps)]
    m = poly_mask(polys, f.S)
    flat = (np.mgrid[0:f.S, 0:f.S][0] < base).astype(np.float32)  # the flat bottom
    m = m * flat
    f.fill(m, BODY, ink=2.6)
    lit = poly_mask([wobble_ring(x - rr * 0.15, y - rr * 0.3, rr * 0.62, seed + 40 + q, amp=0.08, lumps=(3, 5), n=24)
                     for q, (x, y, rr) in enumerate(lumps)], f.S)
    f.fill(lit * m, LIGHT)


def rock_boulder(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(1301)
    r = f.u(0.36)
    cy = c + f.u(0.1)
    base = cy + r * 0.74  # the floor line under it when landed
    mid = _rock_mid()
    if i == 0:  # in the air: stretched, three tapered speed lines trailing up, uneven lengths and gaps
        sx, sy = 0.9, 1.1
        for x_off, L, w, st in ((-0.25, 0.26, 0.04, 0.12), (-0.06, 0.44, 0.048, 0.02), (0.12, 0.3, 0.044, 0.2), (0.28, 0.18, 0.036, 0.08)):
            x = c + f.u(x_off)
            y0 = cy - r * 1.02 - f.u(st)
            top = y0 - f.u(L)
            f.poly(stroke([(x, y0), (x, top)], [f.u(w) * 0.7, f.u(w), f.u(w) * 0.7], cap=True), LIGHT, ink=2.6)
        _stone(f, _rock_pts(_ROCK, c, cy - f.u(0.06), r, sx, sy), r)
        return f.finish()
    if i in (1, 2):
        sx, sy = (1.16, 0.86) if i == 1 else (1.06, 0.95)
        rcy = base - r * 0.74 * sy
        _dust_lumps(f, c, base, r, 0.0 if i == 1 else 0.35, 1310)
        pts = _rock_pts(_ROCK, c, rcy, r, sx, sy)
        m = _stone(f, pts, r)
        mx, my = c + mid[0] * r * sx, rcy + mid[1] * r * sy
        w = f.u(0.05 if i == 1 else 0.062)
        for k, q in enumerate(_SPLIT):  # hot cracks from one point to three corners, kinked once
            ex, ey = pts[q]
            kx = mx + (ex - mx) * 0.5 + f.u(0.03) * (1 if k % 2 else -1)
            ky = my + (ey - my) * 0.5 + f.u(0.025)
            path = [(mx, my), (kx, ky), (ex, ey)]
            f.fill(poly_mask([stroke(path, [w, w * 0.75, w * 0.35], cap=False)], f.S) * m, HOT, ink=2.0)
        return f.finish()
    # 3+: the chunks (the sectors between the cracks)
    chunks = []
    for k in range(3):
        a, b = _SPLIT[k], _SPLIT[(k + 1) % 3]
        idx = [a]
        q = a
        while q != b:
            q = (q + 1) % len(_ROCK)
            idx.append(q)
        chunks.append([mid] + [_ROCK[j] for j in idx])
    rcy = base - r * 0.74 * 0.95
    if i == 3:  # split: a little apart, hot light in the gaps
        f.fill(poly_mask([_rock_pts(_ROCK, c, rcy, r * 0.97, 1.04, 0.95)], f.S), HOT, ink=3.4)
        _dust_lumps(f, c, base, r, 0.6, 1310)
        for k, ch in enumerate(chunks):
            ccx = sum(p[0] for p in ch[1:]) / (len(ch) - 1)
            ccy = sum(p[1] for p in ch[1:]) / (len(ch) - 1)
            push = 0.16
            pts = _rock_pts(ch, c + ccx * r * push, rcy + ccy * r * push, r, 1.04, 0.95)
            _stone(f, pts, r * 0.6)
        return f.finish()
    u = (i - 3) / (n - 4)  # 0.25 .. 1
    if i <= 5:
        _dust_lumps(f, c, base, r, min(1.0, 0.6 + u * 0.6), 1310, side_k=(1.0 + u * 0.3, 0.85 + u * 0.2))
        if i == 5:  # the dust thins: holes eaten into it
            for k in range(5):
                x = c + f.u(g.uniform(-0.8, 0.8))
                f.cut(ellipse_mask(x, base - r * 0.25, r * 0.16, r * 0.14, f.S))
    flyd = [(-1.0, 0.55), (0.25, 1.0), (1.0, 0.45)]  # chunk k flies along: out and up, unevenly
    for k, ch in enumerate(chunks):
        if i == n - 1 and k == 1:
            continue
        ccx = sum(p[0] for p in ch[1:]) / (len(ch) - 1)
        ccy = sum(p[1] for p in ch[1:]) / (len(ch) - 1)
        dx, dy = flyd[k]
        out = ease_out(u)
        x = c + ccx * r + dx * r * 1.5 * out
        y = rcy + ccy * r - r * 0.9 * dy * math.sin(u * math.pi) + r * 0.7 * u * u
        scl = lerp(0.95, 0.55, u) * (0.6 if i == n - 1 else 1.0)
        spin = (0.9 if k % 2 else -0.75) * u * 2.2
        loc = [(p[0] - ccx, p[1] - ccy) for p in ch]
        pts = _rock_pts(loc, x, y, r * scl, 1.0, 1.0, rot=spin)
        _stone(f, pts, r * scl * 0.6, ink=3.0)
        if i == 4:  # the broken face still hot: the first edge (the crack side) glows
            f.fill(poly_mask([stroke([pts[0], pts[1]], [f.u(0.03), f.u(0.012)], cap=False)], f.S), HOT, ink=1.6)
    for k in range(5 if i < n - 1 else 3):  # chunky pebbles, not dots
        a = -math.pi * g.uniform(0.1, 0.9)
        d = r * lerp(0.9, 2.2, u) * g.uniform(0.7, 1.1)
        px, py = c + math.cos(a) * d, rcy + math.sin(a) * d * 0.55 + r * u * u * 0.6
        pr = f.u(0.04) * (1 - 0.45 * u) * g.uniform(0.8, 1.2)
        rot = g.uniform(0, math.tau)
        peb = [(px + math.cos(rot + q * 2.1 + 0.3 * (q % 2)) * pr, py + math.sin(rot + q * 2.1 + 0.3 * (q % 2)) * pr * 0.8)
               for q in range(3)] + [(px + math.cos(rot + 5.4) * pr * 0.9, py + math.sin(rot + 5.4) * pr * 0.7)]
        f.poly(peb, BODY if k % 2 else LIGHT, ink=2.0)
    return f.finish()


# --- steam_cloud: Steam Burst's cloud (comic_steam.gd, designed) ------------------------------------------------
# A billowing inked cumulus round a frozen foe going off: frame 0 a hot pop at its foot with small puffs bursting
# out, 1 the peak, a fat cloud of round lobes (only the union inked), lit tops, a cool shadow curl under some lobes,
# three steam jets shooting up; 2-5 it rises and swells, lobes breaking apart and holes eating in. Water row.

def _cloud(f, lobes, curls=2, seed=0):
    polys = [wobble_ring(x, y, r, seed + k, amp=0.06, lumps=(3, 5), n=40) for k, (x, y, r) in enumerate(lobes)]
    M = poly_mask(polys, f.S)
    f.fill(M, BODY, ink=3.0)
    lit = [wobble_ring(x - r * 0.12, y - r * 0.2, r * 0.78, seed + 30 + k, amp=0.06, lumps=(3, 5), n=40) for k, (x, y, r) in enumerate(lobes)]
    f.fill(poly_mask(lit, f.S) * M, LIGHT)
    hot = [ellipse_mask(x - r * 0.25, y - r * 0.35, r * 0.28, r * 0.2, f.S) for (x, y, r) in lobes]
    f.fill(np.clip(sum(hot), 0, 1) * M, HOT)
    for k in range(min(curls, len(lobes))):
        x, y, r = lobes[k]
        pts = [(x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.45 + r * 0.15) for a in np.linspace(0.3, 2.6, 12)]
        f.fill(poly_mask([stroke(pts, lambda u: f.u(0.022) * math.sin(u * math.pi), cap=False)], f.S) * M, DEEP)
    return M


def steam_cloud(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(1409)
    base = [(-0.32, 0.1, 0.2), (0.3, 0.12, 0.21), (-0.05, 0.18, 0.24), (-0.2, -0.12, 0.22), (0.18, -0.1, 0.23),
            (0.0, -0.32, 0.2), (-0.42, -0.08, 0.15), (0.43, -0.05, 0.16)]
    if i == 0:
        st = star(c, c + f.u(0.25), [f.u(v) for v in g.uniform(0.25, 0.4, 8)], f.u(0.12), rot=0.3, bow=0.3)
        m = poly_mask([st], f.S)
        f.fill(m, LIGHT, ink=2.6)
        f.fill(ellipse_mask(c, c + f.u(0.25), f.u(0.09), f.u(0.09), f.S) * m, HOT)
        lobes = [(c + f.u(x) * 0.7, c + f.u(y) * 0.7 + f.u(0.1), f.u(r) * 0.55) for x, y, r in base]
        _cloud(f, lobes, curls=0, seed=5)
        return f.finish()
    u = (i - 1) / (n - 2)
    rise = f.u(lerp(0.0, 0.32, u))
    grow = lerp(1.0, 1.25, u)
    lobes = []
    for k, (x, y, r) in enumerate(base):
        spread = lerp(1.0, 1.35, u)
        rr = f.u(r) * grow * (1 - 0.35 * u * (k % 3 == 0))
        lobes.append((c + f.u(x) * spread, c + f.u(y) * spread - rise, rr))
    if i == 1:  # three steam jets shooting up out of the top
        for k in range(3):
            x = c + f.u((k - 1) * 0.22)
            f.fill(poly_mask([stroke([(x, c - f.u(0.3)), (x + f.u((k - 1) * 0.08), c - f.u(0.9))], [f.u(0.07), 0.0], cap=True)], f.S), LIGHT, ink=2.2)
    _cloud(f, lobes, curls=2 if u < 0.6 else 0, seed=7 + i)
    if u > 0.75:  # holes eat in as it thins (the erosion does the rest)
        for k in range(int(u * 6)):
            x, y, r = lobes[(k * 3) % len(lobes)]
            f.cut(poly_mask([wobble_ring(x + r * 0.2, y + r * 0.1, r * lerp(0.2, 0.6, u), 90 + k, amp=0.15)], f.S))
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "awaken_gather": (awaken_gather, 320, 3, 6, "gold", "edge", 0.5),
    "awaken_crown": (awaken_crown, 384, 4, 8, "gold", "edge", 0.5),
    "awaken_floor": (awaken_floor, 320, 3, 6, "gold", "edge", 0.5),
    "chain_halo": (chain_halo, 192, 4, 12, "void", "center", 0.45),
    "daze_star": (daze_star, 96, 4, 4, "gold", "edge", 0.4),
    "combo_burst": (combo_burst, 256, 3, 6, "void", "edge", 0.45),
    "echo_axe": (echo_axe, 192, 4, 4, "void", "edge", 0.4),
    "rock_boulder": (rock_boulder, 320, 4, 8, "rock", "edge", 0.45),
    "steam_cloud": (steam_cloud, 320, 3, 6, "water", "edge", 0.5),
}


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
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


if __name__ == "__main__":
    main()
