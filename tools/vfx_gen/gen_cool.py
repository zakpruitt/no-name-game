"""Generate the round 51 cool pass sheets (combo-cool lane, docs/features/combo-breakers.md "Round 51 cool pass"):
the rebuilt endings' designed looks, played by scripts/cool_fx.gd (DESIGNED.extra_sheets).

    python tools/vfx_gen/gen_cool.py [name ...] [--preview=<dir>]

Same format as gen_leash.py (tone, erode order, boil, cover; see vfxlib.py). No polygons at runtime, no crystals: ice
is chunky rounded blocks and powder, the dark is tentacles with suckers and ink, magma is round tongues and globs.

    void_spit     sprite_depth, stood on the floor: Collapse's hole spitting a foe out. 0 the mouth puckers open (an
                  inked lip, suckers round it); 1 a fat tentacle bursts up out of it, two more curling off its sides;
                  2 tallest, the side ones curled over; 3 they fling apart, ink thrown off the tips; 4-5 drawing back
                  down into the mouth, drops falling; 6 the puddle closing.
    avalanche_spill ground, flows to +u from the left edge (the tower's foot): Avalanche's spill. 0 a burst of powder
                  at the foot; 1-3 the slide runs out (a fan of snow, blocks tumbling in it, a powder wave at its
                  front); 4 it stops, blocks settled in a drift; 5 the drift thinning.
    abyss_column  sprite_depth, stood on the floor: Abyss's throw out of the deep. 0 the floor tears open, a black
                  slit; 1 a column of tentacles shoots up, braided round each other; 2 tallest, the tips splaying into
                  grabbing hands; 3 the hands closing on the top; 4 the column whipping down; 5 an ink splash at the
                  foot; 6 the puddle.
    erupt_chain   ground: Eruption's fuse, a lava crack that tiles along u (ribbon, 4 boils): a split in the floor
                  with crusted lips, a hot core, sparks.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, ellipse_mask, fbm, pack,  # noqa: E402
                    poly_mask, preview, rng, save, shrink, stroke, wobble_ring)
from gen_elements import tear, tongue  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def _curl_path(x0, y0, a0, length, curl, n=22, twist=0.0):
    """A tentacle's spine from (x0, y0) leaving at angle a0 (screen radians, -pi/2 is up), bending by `curl` radians
    over its length, the bend gathering toward the tip (a curl, not an arc)."""
    pts = [(x0, y0)]
    x, y = x0, y0
    step = length / n
    for k in range(1, n + 1):
        q = k / n
        a = a0 + curl * q ** 2.2 + twist * math.sin(q * math.pi * 2.0)
        s = step * (1.0 - 0.35 * q)  # the tip curls tighter
        x += math.cos(a) * s
        y += math.sin(a) * s
        pts.append((x, y))
    return pts


def _tentacle(f, path, w0, lit_side=1.0, suckers=True, tone=BODY, ink=4.5):
    """Paint one tentacle along `path`: fat root, thin curled tip, a lit band down one side, sucker dots down the other."""
    S = f.S
    body = stroke(path, lambda q: w0 * (1 - q) ** 0.85 + w0 * 0.08, cap=True)
    m = poly_mask([body], S)
    f.fill(m, tone, ink=ink)
    # the lit band: the spine shifted to one side, thinner
    lit = []
    for k in range(len(path) - 1):
        (x0, y0), (x1, y1) = path[k], path[k + 1]
        dx, dy = x1 - x0, y1 - y0
        ln = max(math.hypot(dx, dy), 1e-3)
        q = k / (len(path) - 1)
        off = w0 * (1 - q) ** 0.85 * 0.22 * lit_side
        lit.append((x0 - dy / ln * off, y0 + dx / ln * off))
    if len(lit) > 3:
        lm = poly_mask([stroke(lit[:-2], lambda q: w0 * 0.26 * (1 - q) + 1.0, cap=True)], S) * m
        f.fill(lm, LIGHT)
    if suckers:
        for k in range(2, len(path) - 4, 3):
            (x0, y0), (x1, y1) = path[k], path[k + 1]
            dx, dy = x1 - x0, y1 - y0
            ln = max(math.hypot(dx, dy), 1e-3)
            q = k / (len(path) - 1)
            r = w0 * (1 - q) * 0.16 + 1.0
            off = w0 * (1 - q) ** 0.85 * 0.3 * -lit_side
            sx, sy = x0 - dy / ln * off, y0 + dx / ln * off
            f.fill(ellipse_mask(sx, sy, r, r * 0.8, S) * m, LIGHT, ink=1.5)
            f.fill(ellipse_mask(sx, sy, r * 0.45, r * 0.35, S) * m, DEEP)
    return m


# --- void_spit ------------------------------------------------------------------------------------------------------

def void_spit(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(5101)
    ground = f.u(1.62)
    mouth_r = f.u([0.36, 0.5, 0.52, 0.5, 0.46, 0.4, 0.3][i])
    # the mouth: an inked lip round a black hole in the floor
    lip = wobble_ring(c, ground, mouth_r, 5103 + i, amp=0.1, lumps=(4, 6), n=64, squash=0.28)
    f.fill(poly_mask([lip], S), BODY, ink=4.0)
    f.fill(ellipse_mask(c, ground + f.u(0.005), mouth_r * 0.72, mouth_r * 0.17, S), INK + 0.06)
    for k in range(7):  # suckers round the lip
        a = math.tau * (k + 0.3 * i) / 7
        x, y = c + math.cos(a) * mouth_r * 0.86, ground + math.sin(a) * mouth_r * 0.24
        f.fill(ellipse_mask(x, y, f.u(0.028), f.u(0.018), S), LIGHT, ink=1.5)
    if i == 0:
        f.fill(ellipse_mask(c, ground - f.u(0.02), mouth_r * 0.4, mouth_r * 0.08, S), HOT)
        return f.finish()
    if i == 6:
        for k in range(3):  # last drops falling into the mouth
            x = c + f.u(g.uniform(-0.25, 0.25))
            f.poly(tear(x, ground - f.u(0.25 + 0.15 * k), f.u(0.035), math.pi * 0.5), BODY, ink=2.5)
        return f.finish()
    tall = [0, 1.15, 1.42, 1.3, 0.85, 0.45][i]
    curl = [0, 0.5, 1.4, 2.2, 2.6, 2.8][i]
    spread = [0, 0.15, 0.3, 0.55, 0.4, 0.2][i]
    w0 = f.u([0, 0.2, 0.22, 0.2, 0.17, 0.14][i])
    tips = []
    for k, side in enumerate((-1.0, 1.0)):  # the side ones, curling outward
        path = _curl_path(c + side * f.u(0.14), ground - f.u(0.02), -math.pi * 0.5 + side * (0.35 + spread),
                          f.u(tall * 0.78), side * curl * 0.9)
        _tentacle(f, path, w0 * 0.8, lit_side=-side)
        tips.append(path[-1])
    # the middle one, fattest and tallest, bending a little
    path = _curl_path(c, ground - f.u(0.02), -math.pi * 0.5, f.u(tall), 0.35 * curl * (1 if i % 2 else -1), twist=0.06)
    _tentacle(f, path, w0, lit_side=1.0)
    tips.append(path[-1])
    if i >= 3:  # ink thrown off the tips, then falling
        k = i - 3
        for s, (x0, y0) in enumerate(tips):
            ang = math.atan2(y0 - ground, x0 - c)
            for j in range(2):
                x = x0 + math.cos(ang + 0.4 * j) * f.u(0.12) * (k + 1)
                y = y0 + math.sin(ang + 0.4 * j) * f.u(0.12) * (k + 1) + f.u(0.1) * k * k
                if f.u(0.05) < x < S - f.u(0.05) and f.u(0.05) < y < ground - f.u(0.04):
                    f.poly(tear(x, y, f.u(0.045 - 0.006 * k), ang if k < 1 else math.pi * 0.5), BODY, ink=3.0)
    if i == 1:  # the burst: a ring of ink spat round the root
        for a in np.linspace(-2.9, -0.25, 6):
            x, y = c + math.cos(a) * f.u(0.48), ground + math.sin(a) * f.u(0.3)
            f.poly(tear(x, y, f.u(0.05), a), BODY, ink=3.0)
    return f.finish()


# --- avalanche_spill ------------------------------------------------------------------------------------------------

def _block(cx, cy, w, h, rot, r=0.28, n=6):
    """A chunky ice block seen from above: a rounded rectangle, turned by `rot`."""
    pts = []
    rr = min(w, h) * r
    for corner, (sx, sy) in enumerate(((1, 1), (-1, 1), (-1, -1), (1, -1))):
        ox, oy = sx * (w / 2 - rr), sy * (h / 2 - rr)
        a0 = [0.0, 0.5, 1.0, 1.5][corner] * math.pi
        for k in range(n + 1):
            a = a0 + (math.pi / 2) * k / n
            pts.append((ox + math.cos(a) * rr, oy + math.sin(a) * rr))
    cr, sr = math.cos(rot), math.sin(rot)
    return [(cx + x * cr - y * sr, cy + x * sr + y * cr) for x, y in pts]


def avalanche_spill(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(5201)
    front = [0.22, 0.5, 0.78, 0.96, 0.98, 0.98][i]  # of the frame's width, where the slide's front has got to
    x0 = f.u(0.08)
    xf = lerp(x0, S - f.u(0.04), front)
    thin = [0.0, 0.0, 0.0, 0.0, 0.25, 0.55][i]

    def half(x):  # the fan: narrow at the foot, wide at the front
        q = (x - x0) / max(xf - x0, 1.0)
        return f.u(0.22 + 0.42 * q ** 0.7) * (1.0 - 0.25 * thin)
    xs = np.linspace(x0, xf, 40)
    top = [(x, c - half(x) + f.u(0.03) * math.sin(k * 1.3 + i)) for k, x in enumerate(xs)]
    bot = [(x, c + half(x) + f.u(0.03) * math.sin(k * 1.7 + 2 * i)) for k, x in enumerate(xs)]
    nose = [(xf + f.u(0.06) * math.cos(a), c + half(xf) * math.sin(a)) for a in np.linspace(-math.pi / 2, math.pi / 2, 16)]
    body = top + nose + bot[::-1]
    m = poly_mask([body], S)
    f.fill(m, BODY, ink=4.0)
    # the snow's lit top and its trodden middle
    f.fill(shrink(m, f.u(0.06)) * (1.0 - thin * 0.6), LIGHT)
    lane = [(x, c - half(x) * 0.25) for x in xs] + [(x, c + half(x) * 0.25) for x in xs[::-1]]
    f.fill(poly_mask([lane], S) * m, BODY)
    # the blocks tumbling in it (the cubes broken into chunky slabs), more at the front
    count = [3, 5, 7, 8, 8, 8][i]
    for k in range(count):
        q = (k + 0.5) / count
        bx = lerp(x0 + f.u(0.1), xf - f.u(0.12), q ** 0.8)
        by = c + g.uniform(-0.55, 0.55) * half(bx)
        w = f.u(g.uniform(0.11, 0.17)) * (1.0 - 0.2 * thin)
        rot = g.uniform(-1.0, 1.0) + (0.6 * i if i < 4 else 2.4)
        blk = _block(bx, by, w * 1.25, w, rot)
        f.poly(blk, LIGHT, ink=3.5)
        f.poly(_block(bx - w * 0.06, by - w * 0.08, w * 0.8, w * 0.5, rot, r=0.4), HOT)
    # the powder wave at the front, rolling (puffs), and powder burst at the foot on the first frames
    if i <= 4:
        for k in range(5):
            a = -1.2 + 2.4 * k / 4
            px = xf + f.u(0.02) * math.cos(a) - f.u(0.04)
            py = c + half(xf) * 0.95 * math.sin(a)
            r = f.u([0.09, 0.12, 0.14, 0.13, 0.08][i]) * (1.1 if k == 2 else 0.9)
            f.poly(wobble_ring(px, py, r, 5210 + k + 7 * i, amp=0.18, lumps=(3, 4), n=30), LIGHT, ink=3.0)
            f.fill(ellipse_mask(px - r * 0.25, py - r * 0.3, r * 0.45, r * 0.35, S), HOT)
    if i <= 1:
        for k in range(4):
            a = math.tau * k / 4 + 0.4
            px, py = x0 + f.u(0.12) + math.cos(a) * f.u(0.12), c + math.sin(a) * f.u(0.16)
            f.poly(wobble_ring(px, py, f.u(0.1), 5230 + k, amp=0.2, lumps=(3, 4), n=30), LIGHT, ink=3.0)
    return f.finish()


# --- abyss_column ---------------------------------------------------------------------------------------------------

def abyss_column(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(5301)
    ground = f.u(1.72)
    slit_r = f.u([0.42, 0.55, 0.58, 0.58, 0.55, 0.5, 0.36][i])
    slit = wobble_ring(c, ground, slit_r, 5303 + i, amp=0.12, lumps=(3, 5), n=64, squash=0.22)
    f.fill(poly_mask([slit], S), DEEP, ink=4.0)
    f.fill(ellipse_mask(c, ground, slit_r * 0.75, slit_r * 0.15, S), INK + 0.04)
    if i == 0:
        for a in (-2.6, -2.0, -1.1, -0.5):  # the floor's lips torn up
            x, y = c + math.cos(a) * slit_r, ground + math.sin(a) * slit_r * 0.3
            f.poly(tear(x, y - f.u(0.03), f.u(0.05), a), BODY, ink=3.0)
        return f.finish()
    if i == 6:
        return f.finish()
    tall = [0, 1.1, 1.3, 1.28, 0.85, 0.35][i]
    w0 = f.u([0, 0.17, 0.18, 0.17, 0.16, 0.12][i])
    # three tentacles braided up the column: each a sine about the axis, out of phase
    for k in range(3):
        ph = math.tau * k / 3 + 0.5 * i
        pts = []
        for j in range(26):
            q = j / 25
            y = ground - f.u(0.02) - f.u(tall) * q
            sway = f.u(0.16) * (1 - 0.5 * q) * math.sin(ph + q * 5.0)
            if i == 4:  # whipping down: the top bends over
                sway += f.u(0.55) * q ** 2.2 * (1 if k % 2 else -1)
            pts.append((c + sway, y))
        if i in (2, 3):  # the tips splay into a grabbing hand round the top
            top = pts[-1]
            splay = [-1.2, 0.0, 1.2][k] * (0.9 if i == 2 else 0.4)
            hand = _curl_path(top[0], top[1], -math.pi * 0.5 + splay, f.u(0.32), -splay * 1.8, n=10)
            pts = pts + hand[1:]
        _tentacle(f, pts, w0, lit_side=1.0 if k % 2 else -1.0, tone=BODY if k != 1 else DEEP)
    if i == 5:  # the splash at the foot
        for a in np.linspace(-2.9, -0.25, 7):
            x, y = c + math.cos(a) * f.u(0.55), ground + math.sin(a) * f.u(0.35)
            f.poly(tear(x, y, f.u(0.055), a), BODY, ink=3.0)
    if i == 1:
        for a in np.linspace(-2.8, -0.35, 5):  # the burst of ink round the root
            x, y = c + math.cos(a) * f.u(0.5), ground + math.sin(a) * f.u(0.32)
            f.poly(tear(x, y, f.u(0.05), a), BODY, ink=3.0)
    _ = g
    return f.finish()


# --- erupt_chain (a strip) --------------------------------------------------------------------------------------------

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


def erupt_chain(i, n, size):
    f, S, h, y0, P = _strip_canvas(size)
    tw = math.tau
    us = np.linspace(-0.02, 1.02, 90)

    def w(u):
        return 0.26 + 0.07 * math.sin(tw * 3 * u + 0.8 * i) + 0.04 * math.sin(tw * 7 * u + i)
    outer = [P(u, 0.5 + w(u)) for u in us] + [P(u, 0.5 - w(u) * 0.9) for u in us[::-1]]
    om = poly_mask([outer], S)
    f.fill(om, DEEP, ink=4.5)
    crack = [P(u, 0.5 + w(u) * 0.45 + 0.04 * math.sin(tw * 5 * u + i)) for u in us] + \
        [P(u, 0.5 - w(u) * 0.4 + 0.04 * math.sin(tw * 4 * u + 2 * i)) for u in us[::-1]]
    cm = poly_mask([crack], S) * om
    f.fill(cm, LIGHT, ink=2.5)
    core = [P(u, 0.5 + w(u) * 0.15) for u in us] + [P(u, 0.5 - w(u) * 0.12) for u in us[::-1]]
    f.fill(poly_mask([core], S) * cm, HOT)
    for k in range(3):  # sparks flicked off the lips
        u = (k / 3 + 0.17 * i) % 1.0
        side = 1 if (k + i) % 2 == 0 else -1
        x, y = P(u, 0.5 + side * (w(u) + 0.08))
        f.poly(tear(x, y, h * 0.05, -math.pi * 0.5 * side), LIGHT, ink=2.5)
    return _crop(f, size)


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "void_spit": (void_spit, 384, 4, 7, "void", "edge", 0.5),
    "avalanche_spill": (avalanche_spill, 384, 3, 6, "water", "edge", 0.55),
    "abyss_column": (abyss_column, 384, 4, 7, "void", "edge", 0.5),
    # "erupt_chain": (erupt_chain, 256, 1, 4, "earth", "none", 0.9),  # (round 52 plays it: gen_cool2.py imports it)
}


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    if frames[0][0].shape[0] != frames[0][0].shape[1]:  # strips: rows stacked; the age erodes it (fbm order)
        tone = np.concatenate([fr[0] for fr in frames], 0)
        alpha = np.concatenate([fr[1] for fr in frames], 0)
        gg = fbm(alpha.shape, 9, scales=(6, 3, 1))
        boil = fbm(alpha.shape, 99, scales=(6, 2, 1))
        sheet = (np.clip(np.stack([tone, gg, boil, alpha], -1), 0, 1) * 255 + 0.5).astype(np.uint8)
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


if __name__ == "__main__":
    main()
