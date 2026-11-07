"""Generate the dash counter's sheets (docs/features/counter.md): Backlash's parry flash (the tentacle catching the
weapon, in the signature's violet) and its whip-crack slam arc.

    python tools/vfx_gen/gen_counter.py [name ...] [--preview=<dir>] [--out=<dir>]

Same format as gen_designed.py / gen_spectacle.py (tone, erode order, boil, cover; see vfxlib.py). Registered at
runtime by scripts/counter_fx.gd (DESIGNED.extra_sheets), played in the `void` palette row.

Shape language (designed-fx.md, dark): ink tendrils and smears, tapered curling strokes, splatter dots, negative
space; the clash itself is the one hard shape, a lopsided straight-sided star (a weapon stopped dead).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, SS, Frame, ellipse_mask, grow, pack,  # noqa: E402
                    poly_mask, preview, rng, save, star, stroke, wobble_ring)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def ease_out(t):
    return 1 - (1 - t) ** 2


def polar(cx, cy, r, a):
    return cx + math.cos(a) * r, cy + math.sin(a) * r


def curl_path(cx, cy, r0, r1, a0, turn, n=40):
    """A spiral from radius r0 at angle a0 in to r1 after `turn` radians: the tentacle wrapping round."""
    return [polar(cx, cy, lerp(r0, r1, k ** 0.9), a0 + turn * k) for k in np.linspace(0, 1, n)]


def tentacle(f, path, w0, tone=DEEP, ink=3.5, suckers=True, seed=1):
    """A fat tapered tentacle along `path` (thick at its root, a hooked point), lit stripe, sucker dots."""
    m = poly_mask([stroke(path, lambda u: w0 * (1 - u) ** 0.7 + 1.0, cap=True)], f.S)
    f.fill(m, tone, ink=ink)
    # the lit stripe along its top edge
    lit = [(x - w0 * 0.12, y - w0 * 0.16) for x, y in path[: int(len(path) * 0.8)]]
    lm = poly_mask([stroke(lit, lambda u: w0 * 0.28 * (1 - u) + 0.5, cap=False)], f.S) * m
    f.fill(lm, BODY)
    if suckers:
        g = rng(seed)
        for k in range(3, int(len(path) * 0.75), 4):
            x, y = path[k]
            u = k / len(path)
            r = w0 * 0.14 * (1 - u) + 1.0
            f.fill(ellipse_mask(x + g.uniform(-1, 1), y + w0 * 0.12 * (1 - u), r, r * 0.8, f.S) * m, LIGHT)
    return m


def blade(f, tip, back, width, tone=LIGHT):
    """The weapon caught: a straight wedge, blunt at the back, pointed at the tip, one hot edge."""
    tx, ty = tip
    bx, by = back
    d = np.array([tx - bx, ty - by], float)
    L = np.linalg.norm(d)
    d /= max(L, 1e-6)
    n = np.array([-d[1], d[0]])
    pts = [(bx + n[0] * width * 0.5, by + n[1] * width * 0.5),
           (tx - d[0] * width * 0.6 + n[0] * width * 0.45, ty - d[1] * width * 0.6 + n[1] * width * 0.45),
           (tx, ty),
           (tx - d[0] * width * 0.6 - n[0] * width * 0.45, ty - d[1] * width * 0.6 - n[1] * width * 0.45),
           (bx - n[0] * width * 0.5, by - n[1] * width * 0.5)]
    m = f.poly(pts, tone, ink=3.0)
    edge = [(bx + n[0] * width * 0.3, by + n[1] * width * 0.3), (tx, ty)]
    f.fill(poly_mask([stroke(edge, [width * 0.22, width * 0.08], cap=False)], f.S) * m, HOT)
    return m


# --- parry_flash: the tentacle catches the weapon ---------------------------------------------------------------
# Frame 0 the anticipation: two crossed hot needles where they meet. 1 the peak: a lopsided clash star (body, lit
# inside, a hot core) with the blade coming in from the upper left and the tentacle curled round it, hooked. 2 the
# core punches out to an inked ring and halftone-free shards fly; the curl cinches tighter and the blade is pulled
# off its line. 3-5 the star hollows from the middle (the sheet erodes from the centre), its spikes thrown out as
# straight shards, the curl thinning to a hook and splatter.

def parry_flash(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(4101 + i)
    if i == 0:
        for a in (-0.7, 0.75):
            p0, p1 = polar(c, c, f.u(0.62), a), polar(c, c, f.u(0.62), a + math.pi)
            f.poly(stroke([p0, (c, c), p1], [0.0, f.u(0.07), 0.0], cap=False), HOT, ink=2.5)
        f.fill(ellipse_mask(c, c, f.u(0.08), f.u(0.08), f.S), HOT)
        return f.finish()
    t = (i - 1) / (n - 2)
    R = f.u(lerp(0.8, 0.95, ease_out(t)))
    tips = [1.0, 0.5, 0.78, 0.46, 0.92, 0.52, 0.7, 0.44, 0.97, 0.5, 0.74, 0.48]
    if i <= 2:
        m = f.poly(star(c, c, [R * b for b in tips], R * 0.36, rot=-0.62, bow=0.1, n_edge=3), BODY, ink=4.5)
        inner = star(c - f.u(0.03), c - f.u(0.03), [R * b * 0.62 for b in tips], R * 0.22, rot=-0.58, bow=0.15)
        f.fill(poly_mask([inner], f.S) * m, LIGHT)
    if i == 1:
        f.fill(poly_mask([star(c, c, [R * b * 0.34 for b in tips], R * 0.13, rot=-0.6, bow=0.2)], f.S), HOT)
    if i == 2:
        f.poly(wobble_ring(c, c, f.u(0.24), 4111, amp=0.14), INK)
        f.cut(poly_mask([wobble_ring(c, c, f.u(0.18), 4112, amp=0.18)], f.S))
    if i >= 3:  # the spikes fly off as straight shards, the middle gone
        k = (i - 3) / max(1, n - 4)
        for j, b in enumerate(tips):
            a = -0.62 + math.tau * j / len(tips)
            r_out = R * b * lerp(1.0, 1.18, ease_out(k))
            r_in = R * lerp(0.5, 0.82, k) * b
            if r_out - r_in < f.u(0.05):
                continue
            w = f.u(lerp(0.09, 0.04, k)) * (1.3 if b > 0.85 else 1.0)
            path = [polar(c, c, r_in, a), polar(c, c, r_out, a)]
            f.poly(stroke(path, [w, 0.0], cap=False), LIGHT if b > 0.85 else BODY, ink=2.4)
    # the blade, coming in from the upper left (pulled off its line as the curl cinches)
    if i <= 3:
        pull = [0.0, 0.0, 0.14, 0.3][i]
        tip = (c + f.u(0.1 + pull * 0.5), c + f.u(0.06 + pull))
        back = (c - f.u(0.9) + f.u(pull * 0.4), c - f.u(0.66) + f.u(pull * 0.9))
        blade(f, tip, back, f.u(0.17 if i < 3 else 0.13))
    # the tentacle, curled round the blade where they meet
    cin = [0, 0.0, 0.25, 0.45, 0.6, 0.72][i]
    r0 = f.u(lerp(0.78, 0.6, cin))
    r1 = f.u(lerp(0.13, 0.08, cin))
    turn = lerp(1.55, 1.9, cin) * math.pi
    path = curl_path(c + f.u(0.04), c + f.u(0.02), r0, r1, 1.05, turn)
    w0 = f.u(lerp(0.3, 0.17, max(0.0, (i - 2) / 3)))
    tentacle(f, path, w0, seed=4120 + i)
    if i >= 2:  # ink splatter thrown off the snap
        for _ in range(7 if i < 4 else 5):
            a = g.uniform(0, math.tau)
            rr = f.u(g.uniform(0.6, 0.98))
            x, y = polar(c, c, rr, a)
            r = f.u(g.uniform(0.02, 0.045)) * (1.0 - 0.3 * (i - 2) / 3)
            f.fill(ellipse_mask(x, y, r, r, f.S), DEEP, ink=1.6)
    return f.finish()


# --- snap_arc: Backlash's whip-crack slam -------------------------------------------------------------------------
# A fat crescent smear from high on the left down to the floor on the right (the tentacle bringing the foe down),
# hatched with speed lines, ending in a hot crack where it hits. Frame 0 the top of the arc only, 1 the whole arc
# and the crack's flash, 2-5 the smear's back end eats away towards the hit, the crack spreading and cooling.

def snap_arc(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(4201)
    ox, oy = c - f.u(0.15), c + f.u(0.05)  # the arc's middle
    R = f.u(0.72)
    a_from, a_to = math.pi * 1.08, math.pi * 1.92  # upper left round over the top to the right
    head = [0.35, 1.0, 1.0, 1.0, 1.0, 1.0][i]
    tail = [0.0, 0.0, 0.25, 0.5, 0.7, 0.85][i]
    if head - tail > 0.05:
        ks = np.linspace(tail, head, 36)
        path = [polar(ox, oy, R * lerp(1.0, 0.96, k), lerp(a_from, a_to, k)) for k in ks]
        wmax = f.u(0.3) * (1.0 - 0.35 * tail)
        m = poly_mask([stroke(path, lambda u: wmax * math.sin(math.pi * min(1.0, 0.08 + u * 0.92)) ** 0.7 + 1.0, cap=False)], f.S)
        f.fill(m, DEEP, ink=4.0)
        lit = [polar(ox, oy, R * 1.04, lerp(a_from, a_to, k)) for k in ks]
        f.fill(poly_mask([stroke(lit, lambda u: wmax * 0.32 * math.sin(math.pi * u) + 0.5, cap=False)], f.S) * m, BODY)
        for k in np.linspace(tail + 0.05, head - 0.05, 7):  # speed hatching across the smear, cut as gaps
            a = lerp(a_from, a_to, k)
            p0, p1 = polar(ox, oy, R - wmax * 0.45, a), polar(ox, oy, R + wmax * 0.45, a)
            f.cut(poly_mask([stroke([p0, p1], [f.u(0.018), f.u(0.018)], cap=False)], f.S) * m)
    if i >= 1:  # the crack where it lands
        hx, hy = polar(ox, oy, R * 0.96, a_to)
        k = (i - 1) / (n - 2)
        rr = f.u(lerp(0.28, 0.4, ease_out(k)))
        tips = [1.0, 0.55, 0.85, 0.5, 0.95, 0.6, 0.8, 0.5]
        if i <= 3:
            m2 = f.poly(star(hx, hy, [rr * b for b in tips], rr * 0.4, rot=0.3, bow=0.1, n_edge=3), LIGHT if i > 1 else HOT, ink=3.5)
            f.fill(ellipse_mask(hx, hy, rr * 0.3, rr * 0.3, f.S) * m2, HOT)
        for j in range(5):  # the cracks running off it, straight
            a = -0.2 + j * 0.65 + g.uniform(-0.1, 0.1)
            L = f.u(lerp(0.3, 0.5, k)) * g.uniform(0.8, 1.1)
            w = f.u(lerp(0.04, 0.02, k))
            f.poly(stroke([polar(hx, hy, rr * 0.3, a), polar(hx, hy, L, a)], [w, 0.0], cap=False), INK)
        if i >= 4:
            f.cut(ellipse_mask(hx, hy, rr * lerp(0.2, 0.6, (i - 4) / max(1, n - 5)), rr * 0.5, f.S))
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "parry_flash": (parry_flash, 384, 3, 6, "void", "center", 0.45),
    "snap_arc": (snap_arc, 320, 3, 6, "void", "edge", 0.45),
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
