"""Generate the breaker-spectacle sheets (docs/features/designed-fx.md "Breaker spectacle"): every breaker ending's
landing as one comic-book beat (a halftone burst in the element's shape language, radial speed lines, a floor-wide
spread, a drawn wall star), its after-beat (smoke curling off the struck), and the window's screen-space art (the
hang's focus lines, the ending's callout banner).

    python tools/vfx_gen/gen_spectacle.py [name ...] [--preview=<dir>]

Same format as gen_designed.py / gen_finish.py (tone, erode order, boil, cover; see vfxlib.py). Registered at
runtime by scripts/designed_breaker.gd (DESIGNED.extra_sheets); the two canvas sheets (hang_focus, callout_panel)
are drawn by its screen layer through shaders/designed_canvas.gdshader.

Shape language (designed-fx.md): storm / spirit / gold bursts are straight-sided spiky stars, magma is round-tipped
tongues and teardrops, ice is a cold scalloped puff with straight cracks (no crystals, no shards: Zak), dark is an
ink splat with tendril arms and splatter. Every burst carries halftone dots in its outer band (the comic print).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, SS, Frame, ellipse_mask, grow, jag_path,  # noqa: E402
                    pack, poly_mask, preview, rng, save, star, stroke, wobble_ring,
                    cluster_angles)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def ease_out(t):
    return 1 - (1 - t) ** 2


def polar(c, r, a):
    return c + math.cos(a) * r, c + math.sin(a) * r


def halftone(f, mask, r0, r1, pitch, dot0, dot1, tone, rot=0.35):
    """Print dots of `tone` inside `mask`, on a grid turned `rot`, growing from dot0 (at radius r0) to dot1 (r1):
    the comic print's halftone, densest at the burst's rim."""
    S, c = f.S, f.c
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    x, y = xx - c, yy - c
    u = x * math.cos(rot) + y * math.sin(rot)
    v = -x * math.sin(rot) + y * math.cos(rot)
    gu = (u / pitch) - np.round(u / pitch)
    gv = (v / pitch) - np.round(v / pitch)
    d = np.hypot(gu, gv) * pitch  # distance to the nearest grid point, px
    r = np.hypot(x, y)
    k = np.clip((r - r0) / max(1.0, r1 - r0), 0.0, 1.0)
    rad = dot0 + (dot1 - dot0) * k
    dots = np.clip(rad - d + 0.5, 0.0, 1.0) * (r >= r0) * mask
    f.fill(dots.astype(np.float32), tone)


# --- slam bursts: the landing's comic POW, one shape language per element --------------------------------------
# Frame 0 the anticipation (a pinched hot glint), 1 the peak (the whole balloon, a fat hot core), 2 the core punches
# out to an inked ring and the halftone prints in, 3-5 the hole eats it from the middle so the spikes / tongues /
# arms are left, thinning, with droplets thrown. The game stands it behind the pile, depth tested (the foes in
# front), and plays it after the impact frame.

def _burst_outline(f, style, R, i, seed):
    c = f.c
    g = rng(seed)
    if style == "star":  # straight-sided spikes, lopsided: two long ones on a diagonal
        base = [1.0, 0.62, 0.8, 0.55, 0.9, 0.6, 0.97, 0.58, 0.78, 0.52, 0.88, 0.6]
        return [star(c, c, [R * b for b in base], R * 0.42, rot=-0.45, bow=0.12, n_edge=3)], base
    if style == "magma":  # round-tipped tongues: a star with soft valleys and a fat blob on each tip
        base = [1.0, 0.72, 0.9, 0.68, 0.95, 0.75, 0.86, 0.7, 0.92]
        polys = [star(c, c, [R * b * 0.92 for b in base], R * 0.55, rot=0.2, bow=0.45, n_edge=6)]
        for k, b in enumerate(base):
            a = 0.2 + math.tau * k / len(base)
            x, y = polar(c, R * b * 0.86, a)
            polys.append(wobble_ring(x, y, R * 0.13 * (0.8 + 0.4 * b), seed + k, amp=0.1, n=32))
        return polys, base
    if style == "frost":  # a cold scalloped puff, no points at all (the cracks carry the ice)
        return [wobble_ring(c, c, R * 0.8, seed, amp=0.1, lumps=(9, 13, 4), n=160)], [1.0] * 9
    # ink: a lumpy splat with tendril arms ending in blobs
    base = [g.uniform(0.7, 1.0) for _ in range(8)]
    polys = [wobble_ring(c, c, R * 0.5, seed, amp=0.18, lumps=(3, 5, 7))]
    for k, b in enumerate(base):
        a = math.tau * k / len(base) + g.uniform(-0.2, 0.2)
        path = [polar(c, R * lerp(0.3, b * 0.92, u), a + 0.25 * math.sin(u * 2.4) * (1 if k % 2 else -1)) for u in np.linspace(0, 1, 16)]
        polys.append(stroke(path, lambda u: R * lerp(0.26, 0.07, u ** 0.8), cap=True))
        x, y = polar(c, R * b * 0.95, a + 0.25 * math.sin(2.4) * (1 if k % 2 else -1))
        polys.append(wobble_ring(x, y, R * 0.09, seed + 30 + k, amp=0.15, n=28))
    return polys, base


def slam(i, n, size, style, seed):
    f = Frame(size)
    c = f.c
    g = rng(seed + i)
    if i == 0:  # anticipation: a pinched four point glint, hot
        tips = [f.u(0.5), f.u(0.14), f.u(0.5), f.u(0.14)]
        f.poly(star(c, c, tips, f.u(0.07), rot=0.25, bow=0.4), HOT, ink=3.0)
        f.fill(ellipse_mask(c, c, f.u(0.09), f.u(0.09), f.S), HOT)
        return f.finish()
    grow_k = [0, 1.0, 1.06, 1.1, 1.13, 1.15][i]
    R = f.u(0.86) * grow_k
    polys, base = _burst_outline(f, style, R, i, seed)
    m = poly_mask(polys, f.S)
    f.fill(m, BODY if style != "ink" else DEEP, ink=4.5 if i <= 2 else 3.5)
    # the lit inner shape, offset up-left
    inner, _ = _burst_outline(f, style, R * 0.62, i, seed + 7)
    im = poly_mask(inner, f.S)
    im = np.roll(np.roll(im, -int(f.u(0.03)), 0), -int(f.u(0.02)), 1) * m
    f.fill(im, LIGHT if style != "ink" else BODY)
    # halftone dots in the outer band (bigger towards the rim): the print
    if i >= 2 or style in ("star", "frost"):
        halftone(f, m * (1.0 - im), R * 0.45, R * 1.0, f.u(0.075), f.u(0.008), f.u(0.03),
                 LIGHT if style != "ink" else BODY)
    if style == "frost":  # straight cracks across the puff, forking, white-hot at the peak
        for k in range(7):
            a = 0.4 + math.tau * k / 7 + g.uniform(-0.1, 0.1)
            L = R * g.uniform(0.85, 1.05)
            w = f.u(lerp(0.035, 0.018, (i - 1) / 4))
            f.poly(stroke([polar(c, R * 0.12, a), polar(c, L, a)], [w, w * 0.7, 0.0], cap=False), HOT if i <= 2 else LIGHT, ink=1.5)
            fa = a + (0.35 if k % 2 else -0.35)
            f.poly(stroke([polar(c, L * 0.55, a), polar(c, L * 0.55 + R * 0.28, fa)], [w * 0.7, 0.0], cap=False), LIGHT, ink=1.2)
    if i == 1:  # the peak: a fat hot core
        core, _ = _burst_outline(f, style, R * 0.34, i, seed + 11)
        f.fill(poly_mask(core, f.S), HOT)
        return f.finish()
    if i == 2:  # the core punches out to an inked ring
        f.poly(wobble_ring(c, c, f.u(0.2), seed + 3, amp=0.15), INK)
        f.cut(poly_mask([wobble_ring(c, c, f.u(0.15), seed + 4, amp=0.2)], f.S))
        return f.finish()
    t = (i - 3) / max(1, n - 4)
    hole_r = R * lerp(0.32, 0.66, t ** 1.1)
    hole = poly_mask([wobble_ring(c, c, hole_r, seed + 9 + i, amp=0.2, lumps=(3, 5, 9))], f.S)
    rim = np.clip(grow(hole, 3.5 * SS) - hole, 0, 1) * m
    f.fill(rim, INK)
    f.cut(hole)
    # droplets thrown off the tips: teardrops for magma, specks for ink, small sparks otherwise
    for k in range(6):
        a = g.uniform(0, math.tau)
        rr = R * lerp(1.0, 1.25, ease_out(t)) * g.uniform(0.9, 1.05)
        dr = f.u(lerp(0.05, 0.028, t)) * (1.4 if style in ("magma", "ink") else 1.0)
        x, y = polar(c, rr, a)
        f.fill(ellipse_mask(x, y, dr, dr, f.S), HOT if style != "ink" else BODY, ink=2.0)
        if style == "magma":
            tail = [polar(c, rr - dr * 0.2, a), polar(c, rr - dr * 3.0, a)]
            f.poly(stroke(tail, [dr * 1.6, 0.0], cap=False), HOT, ink=1.6)
    return f.finish()


def slam_star(i, n, size):
    return slam(i, n, size, "star", 3101)


def slam_magma(i, n, size):
    return slam(i, n, size, "magma", 3201)


def slam_frost(i, n, size):
    return slam(i, n, size, "frost", 3301)


def slam_ink(i, n, size):
    return slam(i, n, size, "ink", 3401)


# --- slam_rays: radial speed lines thrown out from the landing ------------------------------------------------
# Long straight wedges, fat at the inner end round a clear hole, needle-thin outward (thin short lines read as
# commas at game distance; long straight ones read). Frame 0 they start short at the hole, 1 the peak at full
# reach with a hot inner third, then the inner ends race out and the lines thin away.

def slam_rays(i, n, size):
    """fx-language rule 7: three uneven fans of speed lines with clear gaps (vfxlib.cluster_angles), never the even
    ring of 26 carrots it was (a sawblade on Grounded, an urchin on Abyss). Each fan's middle line is the longest and
    fattest; the ends of a fan are short. Frame 0 they start short at the hole, 1 the peak at full reach with a hot inner
    third, 2 still hot, then the inner ends race out and the lines thin away tail last."""
    f = Frame(size)
    c = f.c
    g = rng(3502)
    t = i / (n - 1)
    for j, (a, wt) in enumerate(cluster_angles(13, 3507, clusters=3, spread=0.5)):
        ln = lerp(0.62, 1.0, wt) * g.uniform(0.94, 1.04)
        back = lerp(0.3, 0.8, ease_out(t) ** 1.2) if i > 0 else 0.27
        front = min(0.995, (0.55 if i == 0 else lerp(0.97, 1.0, t)) * ln + (0.0 if i == 0 else 0.02))
        if front - back < 0.05:
            continue
        w = f.u(lerp(0.085, 0.026, t)) * lerp(0.6, 1.15, wt)
        path = [polar(c, f.u(lerp(back, front, u)), a) for u in np.linspace(0, 1, 12)]
        m = poly_mask([stroke(path, lambda u: w * (1 - u) ** 0.8 + 0.5, cap=True)], f.S)
        f.fill(m, LIGHT, ink=2.6)
        if i <= 2:
            core = [polar(c, f.u(lerp(back, front, u)), a) for u in np.linspace(0.03, 0.42, 6)]
            f.fill(poly_mask([stroke(core, [w * 0.5, w * 0.22, 0.0], cap=False)], f.S) * m, HOT)
    return f.finish()


# --- war_cry: the roar as a breaker's window opens (breaker_quake.war_cry) ----------------------------------------
# fx-language: the hang's roar round him, drawn. Three uneven fans (cluster_angles) of slightly bowed strokes, fat and
# round at the inner end round a clear middle (he stands in it: never over him), needle-thin outward; each fan has a
# short echo stroke beside its longest. Frame 0 the anticipation: short fat stubs pulled in at the hole's edge; 1 the
# peak, thrown out with a hot inner third; 2-3 they stretch and thin; 4-5 they snap off from the inside and break.

def war_cry(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(3601)
    t = i / (n - 1)
    hole = 0.4
    for j, (a, wt) in enumerate(cluster_angles(10, 3607, clusters=3, spread=0.45)):
        ln = lerp(0.5, 1.0, wt) * g.uniform(0.92, 1.05)
        bow = (0.025 if j % 2 else -0.02) * g.uniform(0.6, 1.2)
        if i == 0:
            back, front = hole * 0.92, hole + 0.12 * ln
        else:
            back = hole + lerp(0.0, 0.36, ease_out(t) ** 1.4) + g.uniform(0.0, 0.03)
            front = min(0.985, hole + lerp(0.48, 0.58, ease_out(t)) * ln)
        if front - back < 0.04:
            continue
        w = f.u(lerp(0.1, 0.04, t) if i > 0 else 0.1) * lerp(0.6, 1.15, wt)
        path = [polar(c, f.u(lerp(back, front, u)), a + bow * math.sin(u * math.pi)) for u in np.linspace(0, 1, 14)]
        m = poly_mask([stroke(path, lambda u: w * (1 - u) ** 0.85 + 0.5, cap=True)], f.S)
        f.fill(m, BODY, ink=2.6)
        if i <= 2:
            core = [polar(c, f.u(lerp(back, front, u)), a + bow * math.sin(u * math.pi)) for u in np.linspace(0.04, 0.45, 8)]
            f.fill(poly_mask([stroke(core, [w * 0.45, w * 0.22, 0.0], cap=False)], f.S) * m, HOT if i <= 1 else LIGHT)
        elif i <= 3:
            lit = [polar(c, f.u(lerp(back, front, u)), a + bow * math.sin(u * math.pi)) for u in np.linspace(0.04, 0.5, 8)]
            f.fill(poly_mask([stroke(lit, [w * 0.35, w * 0.15, 0.0], cap=False)], f.S) * m, LIGHT)
    return f.finish()


# --- floor spreads: the landing reaches the whole floor round it -----------------------------------------------
# cracks (magma, ice): a splash star in the middle and long straight branching cracks out to the square's edge,
# white-hot first, then cooling to body and deep, breaking into gaps. arcs (storm): zigzag lightning racing over
# the floor with forks. splat (dark): an ink pool splash with arms, blobs and splatter.

def _spread(i, n, size, style, seed):
    f = Frame(size)
    c = f.c
    g = rng(seed)
    t = i / (n - 1)
    reach = lerp(0.55, 0.98, ease_out(min(1.0, i / 1.5)))
    tone = [HOT, HOT, LIGHT, BODY, DEEP, DEEP][min(i, 5)]
    if style == "splat":
        R = f.u(lerp(0.32, 0.48, ease_out(min(1.0, i / 2))))
        polys = [wobble_ring(c, c, R, seed, amp=0.2, lumps=(3, 5, 8))]
        for k in range(9):
            a = math.tau * k / 9 + g.uniform(-0.2, 0.2)
            L = f.u(reach * g.uniform(0.7, 1.0))
            path = [polar(c, lerp(R * 0.5, L, u), a + 0.2 * math.sin(u * 3) * (1 if k % 2 else -1)) for u in np.linspace(0, 1, 14)]
            polys.append(stroke(path, lambda u: f.u(lerp(0.12, 0.035, u)), cap=True))
            x, y = path[-1]
            polys.append(wobble_ring(x, y, f.u(0.045), seed + k, amp=0.2, n=24))
        m = poly_mask(polys, f.S)
        f.fill(m, DEEP, ink=3.5)
        f.fill(poly_mask([wobble_ring(c - f.u(0.04), c - f.u(0.05), R * 0.55, seed + 2, amp=0.2)], f.S) * m, BODY)
        for k in range(16):  # splatter
            a = g.uniform(0, math.tau)
            rr = f.u(reach * g.uniform(0.55, 1.0))
            dr = f.u(g.uniform(0.012, 0.03))
            x, y = polar(c, rr, a)
            f.fill(ellipse_mask(x, y, dr, dr, f.S), DEEP, ink=1.5)
        if i >= 3:
            f.cut(poly_mask([wobble_ring(c, c, R * lerp(0.2, 0.8, (i - 3) / 2), seed + 5, amp=0.25)], f.S))
        return f.finish()
    # the middle: a lopsided straight star splash (a scorch / frost mark) and the cracks / arcs out from it
    R = f.u(0.26 if i else 0.2)
    tips = [R * b for b in (1.0, 0.6, 0.85, 0.55, 0.95, 0.6, 0.8, 0.5, 0.9)]
    f.poly(star(c, c, tips, R * 0.4, rot=0.3, bow=0.0, n_edge=2), DEEP if i >= 2 else BODY, ink=3.0)
    if i <= 2:
        f.fill(poly_mask([star(c, c, [x * 0.55 for x in tips], R * 0.2, rot=0.3, bow=0.0, n_edge=2)], f.S), HOT if i < 2 else LIGHT)
    k_c = 11
    for k in range(k_c):
        a = 0.3 + math.tau * k / k_c + g.uniform(-0.12, 0.12)
        L = f.u(reach * g.uniform(0.65, 1.0))
        w = f.u(lerp(0.045, 0.022, t)) * g.uniform(0.8, 1.2)
        if style == "arcs":
            p = jag_path(polar(c, R * 0.6, a), polar(c, L, a), f.u(0.08), 0.55, seed + k)
        else:
            p = np.array([polar(c, R * 0.6, a), polar(c, lerp(R, L, 0.5), a + g.uniform(-0.05, 0.05)), polar(c, L, a + g.uniform(-0.08, 0.08))])
        f.poly(stroke(p, lambda q: w * (1 - 0.75 * q) + 1, cap=False), tone, ink=2.0)
        if style == "arcs" and i <= 2:  # the hot core down the arc
            f.poly(stroke(p, lambda q: w * 0.35 * (1 - q), cap=False), HOT)
        # forks: one or two off the middle, straight for cracks, zigzag for arcs
        for fk in range(1 + (k % 2)):
            q = g.uniform(0.35, 0.7)
            j = min(len(p) - 1, int(q * (len(p) - 1)))
            x0, y0 = p[j]
            fa = a + (0.5 if fk else -0.5) * g.uniform(0.6, 1.0)
            fl = L * g.uniform(0.2, 0.35)
            if style == "arcs":
                fp = jag_path((x0, y0), (x0 + math.cos(fa) * fl, y0 + math.sin(fa) * fl), f.u(0.05), 0.5, seed + 50 + k * 3 + fk)
            else:
                fp = np.array([(x0, y0), (x0 + math.cos(fa) * fl, y0 + math.sin(fa) * fl)])
            f.poly(stroke(fp, lambda q: w * 0.6 * (1 - q) + 0.5, cap=False), tone, ink=1.6)
    if i >= 3:  # breaking up: gaps cut across the cracks
        for s in range(6 + 3 * (i - 3)):
            a = g.uniform(0, math.tau)
            r0 = f.u(g.uniform(0.2, 0.9))
            x, y = polar(c, r0, a)
            f.cut(ellipse_mask(x, y, f.u(0.03 * (i - 2)), f.u(0.03 * (i - 2)), f.S))
    return f.finish()


def floor_cracks(i, n, size):
    return _spread(i, n, size, "cracks", 3601)


def floor_arcs(i, n, size):
    return _spread(i, n, size, "arcs", 3701)


def floor_splat(i, n, size):
    return _spread(i, n, size, "splat", 3801)


# --- wall_star: a foe slammed into a wall or pillar -------------------------------------------------------------
# A big lopsided impact star flat on the wall with straight cracks running out of it and chunks knocked off.

def wall_star(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(3901)
    if i == 0:
        f.poly(star(c, c, [f.u(0.45), f.u(0.12)] * 2, f.u(0.06), rot=0.6, bow=0.4), HOT, ink=3.0)
        return f.finish()
    t = (i - 1) / (n - 2)
    R = f.u(lerp(0.72, 0.8, t))
    base = [1.0, 0.5, 0.8, 0.45, 0.92, 0.55, 0.75, 0.48, 0.86, 0.5]
    m = f.poly(star(c, c, [R * b for b in base], R * 0.36, rot=-0.3, bow=0.15, n_edge=3), BODY, ink=4.0)
    f.fill(poly_mask([star(c - f.u(0.02), c - f.u(0.03), [R * b * 0.6 for b in base], R * 0.22, rot=-0.25, bow=0.2)], f.S) * m, LIGHT)
    if i == 1:
        f.fill(ellipse_mask(c, c, f.u(0.2), f.u(0.2), f.S), HOT)
    else:
        halftone(f, m, R * 0.4, R, f.u(0.08), f.u(0.01), f.u(0.03), LIGHT, rot=0.7)
    for k in range(8):  # the wall cracks, straight, running past the star
        a = -0.3 + math.tau * k / 8 + g.uniform(-0.15, 0.15)
        L = f.u(g.uniform(0.82, 0.98))
        w = f.u(lerp(0.035, 0.02, t))
        mid = polar(c, L * 0.6, a + g.uniform(-0.12, 0.12))
        f.poly(stroke([polar(c, R * 0.3, a), mid, polar(c, L, a)], [w, w * 0.6, 0.0], cap=False), INK)
    if i >= 3:
        f.cut(poly_mask([wobble_ring(c, c, R * lerp(0.2, 0.55, (i - 3) / max(1, n - 4)), 3907 + i, amp=0.2)], f.S))
    for k in range(4):  # chunks knocked off
        a = g.uniform(0, math.tau)
        rr = R * lerp(0.9, 1.15, t)
        x, y = polar(c, rr, a)
        s_ = f.u(0.05)
        f.poly([(x - s_, y - s_ * 0.6), (x + s_ * 0.8, y - s_), (x + s_, y + s_ * 0.7), (x - s_ * 0.6, y + s_)], DEEP, ink=2.0)
    return f.finish()


# --- smoke_curl: the after-beat on the struck (smoking / steaming / dark wisps) --------------------------------
# One column of scalloped smoke lumps rising off a foe with a curl hook at the top; it lifts, leans, the curl rolls
# over and holes eat it. Drawn standing on its ground line (anchored low), depth tested behind the foe.

def smoke_curl(i, n, size):
    f = Frame(size)
    c = f.c
    t = i / (n - 1)
    lift = f.u(lerp(0.0, 0.5, t))
    lumps = []
    for k in range(4):
        y = c + f.u(0.55) - f.u(0.3) * k - lift
        x = c + f.u(0.08) * math.sin(k * 1.3 + t * 3.0) + f.u(0.06) * k * t
        r = f.u(lerp(0.17, 0.11, k / 3) * lerp(0.8, 1.15, t))
        lumps.append(wobble_ring(x, y, r, 4001 + k, amp=0.14, lumps=(4, 6), n=40))
    m = poly_mask(lumps, f.S)
    f.fill(m, BODY, ink=3.0)
    for k, lp in enumerate(lumps):  # the lit top of each lump
        lm = poly_mask([lp], f.S)
        lm = np.roll(lm, -int(f.u(0.05)), 0) * lm
        f.fill(lm * m, LIGHT)
    # the curl hook off the top lump
    x0, y0 = c + f.u(0.08 + 0.18 * t), c + f.u(0.55) - f.u(0.9) - lift
    hook = [polar(0, 1, 0)]
    path = [(x0 + f.u(0.12) * math.cos(a), y0 + f.u(0.12) * math.sin(a)) for a in np.linspace(math.pi * 0.9, math.pi * 2.6, 14)]
    f.poly(stroke(path, lambda q: f.u(0.05) * (1 - q) + 1, cap=False), BODY, ink=2.2)
    if i >= n // 2:
        g = rng(4100 + i)
        for k in range(3 + i):
            x, y = c + f.u(g.uniform(-0.3, 0.3)), c + f.u(g.uniform(-0.6, 0.6)) - lift
            f.cut(ellipse_mask(x, y, f.u(0.06 * t), f.u(0.06 * t), f.S))
    del hook
    return f.finish()


# --- hang_focus (screen): the hang's manga focus lines ---------------------------------------------------------
# Long straight lines from past the screen's edge pointing in at the hero, stopping round a wide clear middle (the
# game stretches the square over the screen, so the middle is a wide oval). Each frame a new set (boil on twos).

def hang_focus(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(4201 + i * 13)
    k_l = 46
    for j in range(k_l):
        a = math.tau * j / k_l + g.uniform(-0.05, 0.05)
        r_in = g.uniform(0.66, 0.9)
        r_out = 1.5
        w = f.u(g.uniform(0.018, 0.04))
        path = [polar(c, f.u(lerp(r_out, r_in, u)), a) for u in np.linspace(0, 1, 10)]
        m = poly_mask([stroke(path, lambda u: w * (1 - u) ** 0.9 + 0.5, cap=False)], f.S)
        f.fill(m, LIGHT, ink=1.6)
    return f.finish()


# --- callout_panel (screen): the ending's name and total on one banner -----------------------------------------
# A slanted brush banner across the middle third of the square (the game draws only that band): a fat stroke with
# a lit top stripe, a halftone field at its right end, dry-brush slits at both ends, inked. Frame 0 the stroke
# slashing in from the left with a pointed head, 1 the whole banner, 2-3 boil variants of it.

def callout_panel(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(4301 + (i if i >= 2 else 0))
    x0, x1 = f.u(0.06), f.u(1.94)
    if i == 0:
        x1 = f.u(1.2)
    top, bot = f.u(0.68), f.u(1.32)
    skew = f.u(0.1)
    xs = np.linspace(x0, x1, 40)
    up = [(x, top - skew * (x / S) + f.u(0.012) * math.sin(x * 0.02 + i)) for x in xs]
    dn = [(x, bot - skew * (x / S) + f.u(0.012) * math.sin(x * 0.017 + 2 + i)) for x in xs[::-1]]
    head = [(x1 + f.u(0.06), (top + bot) * 0.5 - skew * (x1 / S))] if i == 0 else []
    tail = [(x0 - f.u(0.04), (top + bot) * 0.5 - skew * (x0 / S) + f.u(0.04))]
    m = f.poly(up + head + dn + tail, BODY, ink=5.0)
    stripe_up = [(x, y + f.u(0.035)) for x, y in up]
    stripe_dn = [(x, y + f.u(0.16)) for x, y in up[::-1]]
    f.fill(poly_mask([stripe_up + stripe_dn], S) * m, LIGHT)
    # halftone at the right end, densest at the edge
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    k = np.clip((xx - f.u(1.1)) / f.u(0.8), 0, 1)
    pitch = f.u(0.05)
    d = np.hypot((xx / pitch) - np.round(xx / pitch), (yy / pitch) - np.round(yy / pitch)) * pitch
    dots = np.clip(k * f.u(0.02) - d + 0.5, 0, 1) * m * (xx > f.u(1.1))
    f.fill(dots.astype(np.float32), DEEP)
    # dry-brush slits at both ends
    for end, sgn in ((x0, 1), (x1, -1)):
        for s_ in range(4):
            y = lerp(top, bot, 0.15 + 0.22 * s_) - skew * (end / S)
            ln = f.u(g.uniform(0.08, 0.2))
            f.cut(poly_mask([stroke([(end - sgn * f.u(0.02), y), (end + sgn * ln, y)], [f.u(0.018), 0.0], cap=False)], S))
    # a hot glint streak along the top stripe
    gx = f.u(0.3 + 0.1 * (i % 2))
    f.fill(poly_mask([stroke([(gx, top + f.u(0.07) - skew * (gx / S)), (gx + f.u(0.5), top + f.u(0.07) - skew * ((gx + f.u(0.5)) / S))], [0.0, f.u(0.03), 0.0], cap=False)], S) * m, HOT)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "slam_star": (slam_star, 384, 3, 6, "boltA", "center", 0.45),
    "slam_magma": (slam_magma, 384, 3, 6, "earth", "center", 0.45),
    "slam_frost": (slam_frost, 384, 3, 6, "water", "center", 0.45),
    "slam_ink": (slam_ink, 384, 3, 6, "void", "center", 0.45),
    "slam_rays": (slam_rays, 512, 3, 6, "gold", "edge", 0.4),
    "floor_cracks": (floor_cracks, 512, 3, 6, "earth", "edge", 0.5),
    "floor_arcs": (floor_arcs, 512, 3, 6, "boltA", "edge", 0.5),
    "floor_splat": (floor_splat, 512, 3, 6, "void", "edge", 0.5),
    "war_cry": (war_cry, 384, 3, 6, "void", "edge", 0.4),
    "wall_star": (wall_star, 320, 3, 6, "hit", "center", 0.45),
    "smoke_curl": (smoke_curl, 192, 4, 8, "dust", "edge", 0.5),
    "hang_focus": (hang_focus, 512, 2, 4, "gold", "edge", 0.3),
    "callout_panel": (callout_panel, 512, 2, 4, "earth", "edge", 0.4),
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
    global OUT
    out = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--out=")), None)
    if out:
        OUT = out
    for name in names or SHEETS:
        build(name, prev)


if __name__ == "__main__":
    main()
