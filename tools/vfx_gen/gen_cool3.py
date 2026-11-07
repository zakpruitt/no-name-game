"""Generate the round 54 cool pass sheets (combo-cool3 lane, docs/features/combo-breakers.md "Round 54 cool pass 3"):
the counter's sharper parry (the glint and the attacker's weapon knocked flying), played by scripts/counter_fx.gd,
and the rebuilt mids' marks, played by scripts/mid_beats.gd (DESIGNED.extra_sheets).

    python tools/vfx_gen/gen_cool3.py [name ...] [--preview=<dir>]

Same format as gen_counter.py (tone, erode order, boil, cover; see vfxlib.py). No crystals: the glint is a hard
four-point flick of light, the only straight-sided shape (a weapon stopped dead), and gone in two frames.

    parry_glint   sprite: the clash's first frames, sharper than parry_flash: 0 a thin hot cross flick, 1 a long
                  lopsided four-point glint with an inked ring, 2-3 the glint's arms snapping off as hot needles.
    parry_blade   sprite: the attacker's weapon knocked out of its hand, spinning off (a chunky cleaver, cream steel,
                  dark grip, a hot edge), four quarter turns of the spin, each with its own smear arc behind it.
    reap_hook     sprite: Reap's barb biting the picked foe: 0 the hooked point arriving with a speed smear, 1 sunk,
                  an ink splash round it, 2-3 the barb drawn tight, drops flung off, 4 thinning.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, ellipse_mask, pack,  # noqa: E402
                    poly_mask, preview, rng, save, star, stroke, wobble_ring)
from gen_counter import blade, curl_path, polar, tentacle  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


# --- parry_glint ----------------------------------------------------------------------------------------------------

def _glint_star(f, c, tips, rot):
    return star(c, c, tips, f.u(0.07), rot=rot, bow=-0.25, n_edge=4)


def parry_glint(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(6101 + i)
    rot = -0.32
    if i == 0:  # the flick: a thin hot cross
        for a, ln in ((rot, 0.7), (rot + math.pi * 0.5, 0.45)):
            p0, p1 = polar(c, c, f.u(ln), a), polar(c, c, f.u(ln), a + math.pi)
            f.poly(stroke([p0, (c, c), p1], [0.0, f.u(0.05), 0.0], cap=False), HOT, ink=2.0)
        return f.finish()
    if i == 1:  # the glint: a long lopsided four-point star, inked, a white core, an ink ring round it
        f.poly(wobble_ring(c, c, f.u(0.5), 6111, amp=0.05, lumps=(5, 9), n=80), INK)
        f.cut(poly_mask([wobble_ring(c, c, f.u(0.44), 6112, amp=0.05, lumps=(5, 9), n=80)], f.S))
        tips = [f.u(0.98), f.u(0.42), f.u(0.8), f.u(0.38)]
        m = f.poly(_glint_star(f, c, tips, rot), LIGHT, ink=4.0)
        f.fill(poly_mask([_glint_star(f, c, [t * 0.55 for t in tips], rot)], f.S) * m, HOT)
        return f.finish()
    # 2-3: the arms snap off as needles flying out, the middle gone
    k = (i - 2) / max(1, n - 3)
    for j, ln in enumerate((0.98, 0.42, 0.8, 0.38, 0.6, 0.55)):
        a = rot + math.pi * 0.5 * j + (0.0 if j < 4 else 0.78)
        r_in = f.u(lerp(0.35, 0.7, k)) * (ln if j < 4 else 0.7)
        r_out = f.u(lerp(1.0, 0.98, k)) * ln
        if r_out - r_in < f.u(0.04):
            continue
        f.poly(stroke([polar(c, c, r_in, a), polar(c, c, r_out, a)], [f.u(0.06 - 0.03 * k), 0.0], cap=False),
               HOT if j < 4 else LIGHT, ink=2.0)
    for _ in range(4):
        a = g.uniform(0, math.tau)
        x, y = polar(c, c, f.u(g.uniform(0.4, 0.85)), a)
        f.fill(ellipse_mask(x, y, f.u(0.025), f.u(0.025), f.S), LIGHT, ink=1.5)
    return f.finish()


# --- parry_blade ----------------------------------------------------------------------------------------------------

def parry_blade(i, n, size):
    f = Frame(size)
    c = f.c
    a = -0.6 + i * math.pi * 0.5  # a quarter turn a frame
    d = np.array([math.cos(a), math.sin(a)])
    nrm = np.array([-d[1], d[0]])
    L = f.u(0.62)
    tip = (c + d[0] * L, c + d[1] * L)
    back = (c - d[0] * L * 0.2, c - d[1] * L * 0.2)
    # the smear: the arc the tip swept since the last frame, a fat stroke thinning back
    sweep = [polar(c, c, L * 0.92, a - math.pi * 0.5 * q) for q in np.linspace(0.0, 0.85, 14)]
    f.poly(stroke(sweep, lambda q: f.u(0.11) * (1 - q) + 0.5, cap=True), BODY, ink=2.0)
    for k in (0.55, 0.75):
        arc = [polar(c, c, L * k, a - math.pi * 0.5 * q) for q in np.linspace(0.1, 0.6, 10)]
        f.poly(stroke(arc, lambda q: f.u(0.025) * (1 - q) + 0.3, cap=True), LIGHT)
    # the cleaver: a broad blade, a dark guard, grip and pommel
    blade(f, tip, back, f.u(0.3), tone=LIGHT)
    grip_end = (c - d[0] * L * 0.62, c - d[1] * L * 0.62)
    f.poly(stroke([back, grip_end], [f.u(0.09), f.u(0.08)], cap=True), DEEP, ink=3.0)
    f.fill(ellipse_mask(grip_end[0], grip_end[1], f.u(0.075), f.u(0.075), f.S), BODY, ink=3.0)
    gx, gy = back
    guard = [(gx + nrm[0] * f.u(0.2), gy + nrm[1] * f.u(0.2)), (gx - nrm[0] * f.u(0.2), gy - nrm[1] * f.u(0.2))]
    f.poly(stroke(guard, [f.u(0.06), f.u(0.06)], cap=True), DEEP, ink=2.5)
    gl = (c + d[0] * L * 0.55 + nrm[0] * f.u(0.06), c + d[1] * L * 0.55 + nrm[1] * f.u(0.06))
    f.fill(ellipse_mask(gl[0], gl[1], f.u(0.05), f.u(0.05), f.S), HOT)
    return f.finish()


# --- reap_hook ------------------------------------------------------------------------------------------------------

def reap_hook(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(6301 + i)
    sink = [0.0, 0.12, 0.16, 0.18, 0.18][i]
    tip = (c + f.u(0.05 - sink), c + f.u(0.06))
    if i == 0:  # arriving: a speed smear behind
        for k, y in enumerate((-0.12, 0.0, 0.12)):
            f.poly(stroke([(c - f.u(0.95), c + f.u(y)), (c - f.u(0.2), c + f.u(y * 0.4))], [0.0, f.u(0.04 - 0.01 * k)],
                          cap=False), LIGHT if k == 1 else BODY)
    if 1 <= i <= 3:  # the splash where it bites
        r = f.u([0, 0.42, 0.5, 0.46][i])
        f.fill(poly_mask([wobble_ring(c, c + f.u(0.04), r, 6320 + i, amp=0.3, lumps=(4, 7), n=70)], f.S), DEEP, ink=3.5)
        f.cut(poly_mask([wobble_ring(c, c + f.u(0.04), r * 0.55, 6330 + i, amp=0.25, lumps=(3, 5), n=50)], f.S))
    # the hook: the line thick at the left, curling down and back up into a barbed point
    w0 = f.u([0.15, 0.14, 0.13, 0.11, 0.08][i])
    path = curl_path(tip[0] + f.u(0.18), tip[1] - f.u(0.02), f.u(0.22), f.u(0.02), math.pi * 1.05, -1.25 * math.pi, n=26)
    line = [(c - f.u(0.98), c - f.u(0.2 - 0.05 * i)), path[0]]
    f.poly(stroke(line, [f.u(0.06), w0], cap=True), DEEP, ink=3.0)
    tentacle(f, path, w0, tone=DEEP, ink=3.0, suckers=False, seed=6340)
    bx, by = path[-1]
    f.poly([(bx, by), (bx + f.u(0.16), by - f.u(0.04)), (bx + f.u(0.04), by + f.u(0.1))], HOT, ink=2.5)
    if i >= 2:  # drops flung off
        for _ in range(6):
            a = g.uniform(-math.pi, 0.2)
            x, y = polar(c, c, f.u(g.uniform(0.5, 0.9)), a)
            r = f.u(g.uniform(0.02, 0.04))
            f.fill(ellipse_mask(x, y, r, r, f.S), BODY, ink=1.5)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "parry_glint": (parry_glint, 384, 2, 4, "void", "center", 0.4),
    "parry_blade": (parry_blade, 192, 4, 4, "dust", "edge", 0.4),
    "reap_hook": (reap_hook, 256, 3, 5, "void", "edge", 0.45),
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
