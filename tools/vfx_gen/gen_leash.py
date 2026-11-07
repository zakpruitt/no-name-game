"""Generate Lava Leash's sheets (dark-magma lane, docs/features/designed-fx.md "Lava Leash"): the lava seam a dragged foe
leaves on the floor, and the seam's eruption under the pile at his feet.

    python tools/vfx_gen/gen_leash.py [name ...] [--preview=<dir>]

Same format as gen_elements.py / gen_polygons.py (tone, erode order, boil, cover; see vfxlib.py), its own module so
lanes add sheets side by side. Registered at runtime by scripts/lava_leash.gd (DESIGNED.extra_sheets).
Magma's shape language: round-tipped tongues, teardrop globs, crust plates with hot joins; never a point or a crystal.

    lava_seam    ribbon (4 boils): a molten gouge that tiles along u. Crusted inked banks, a body of lava with a lit
                 band, a fat wavering white-hot core, crust rafts drifting on it, a bubble popping. Drawn with the drag
                 line's shader (each vertex's age cools it down the ramp and erodes it from its old end).
    leash_burst  sprite_depth, stood behind the pile: frame 0 a hot slit opening in the floor; 1 the seam bursts, a fan
                 of fat tongues thrown up and out; 2 taller, splitting, a glob on every tip; 3 the tongues let go: globs
                 thrown, the column thinning; 4-5 the globs falling, the puddle crusting; 6 a crusted mound, hot joins.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, ellipse_mask, erode_field, fbm, pack,  # noqa: E402
                    poly_mask, preview, rng, save, shrink, stroke, wobble_ring)
from gen_elements import tear, tongue, voronoi  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


# --- strips: drawn on a square canvas in a band S x S/4, cropped (gen_polygons' layout) -----------------------------

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


def lava_seam(i, n, size):
    f, S, h, y0, P = _strip_canvas(size)
    g = rng(707 + i)
    tw = math.tau
    us = np.linspace(-0.02, 1.02, 90)

    def top_v(u):  # the banks: ragged, periodic in u so the tiles meet
        return 0.86 + 0.05 * math.sin(tw * 2 * u + 0.7 * i) + 0.03 * math.sin(tw * 7 * u + i)

    def bot_v(u):
        return 0.14 + 0.05 * math.sin(tw * 3 * u + 1.1 * i) + 0.03 * math.sin(tw * 6 * u + 2 * i)

    def mid_v(u):
        return 0.5 + 0.05 * math.sin(tw * 2 * u + 0.9 * i)
    outer = [P(u, top_v(u)) for u in us] + [P(u, bot_v(u)) for u in us[::-1]]
    om = poly_mask([outer], S)
    f.fill(om, DEEP, ink=4.5)  # the crusted banks
    # the crust's cracks on the banks: short dark joins across them
    for k in range(6):
        u = (k / 6 + 0.07 * i) % 1.0
        for off in (0.0, 1.0, -1.0):
            for side in (1, -1):
                v0 = top_v(u) if side > 0 else bot_v(u)
                pts = [P(u + off + 0.01 * q, lerp(v0, mid_v(u) + side * 0.16, q)) for q in np.linspace(0, 1, 5)]
                f.fill(poly_mask([stroke(pts, lambda q: h * 0.035 * (1 - q) + 1, cap=False)], S) * om, INK)

    # the lava: a body between the banks, the lit band and the white-hot core along the middle
    def half(u, k):
        return k * (0.2 + 0.04 * math.sin(tw * 3 * u + i * 1.3) + 0.025 * math.sin(tw * 8 * u + i))
    lava = [P(u, mid_v(u) + half(u, 1.0)) for u in us] + [P(u, mid_v(u) - half(u, 1.0)) for u in us[::-1]]
    lm = poly_mask([lava], S) * om
    f.fill(lm, BODY, ink=3.0)
    lit = [P(u, mid_v(u) + half(u, 0.62)) for u in us] + [P(u, mid_v(u) - half(u, 0.5)) for u in us[::-1]]
    f.fill(poly_mask([lit], S) * lm, LIGHT)
    core = [P(u, mid_v(u) + 0.02 + half(u, 0.24)) for u in us] + [P(u, mid_v(u) + 0.02 - half(u, 0.2)) for u in us[::-1]]
    f.fill(poly_mask([core], S) * lm, HOT)
    # crust rafts drifting on it (they slide along u from boil to boil)
    for k in range(3):
        u = (k / 3 + 0.11 * i + 0.05) % 1.0
        for off in (0.0, 1.0, -1.0):
            x, y = P(u + off, mid_v(u) + (0.07 if k % 2 else -0.08))
            raft = wobble_ring(x, y, h * 0.075, 720 + k, amp=0.2, lumps=(2, 3), n=30, squash=0.6)
            f.fill(poly_mask([raft], S) * lm, DEEP, ink=2.0)
    # a bubble on the core, popping across the boils: a lit dome, then a ring, then gone
    u = (0.35 + 0.29 * i) % 1.0
    x, y = P(u, mid_v(u))
    r = h * [0.07, 0.1, 0.12, 0.0][i]
    if r > 0:
        f.fill(ellipse_mask(x, y, r, r * 0.8, S) * lm, LIGHT if i < 2 else HOT, ink=2.0)
    # glowing drips flicked over the banks
    for k in range(2):
        u = (k / 2 + 0.23 + 0.13 * i) % 1.0
        side = 1 if (k + i) % 2 == 0 else -1
        v = (top_v(u) + 0.05) if side > 0 else (bot_v(u) - 0.05)
        x, y = P(u, v)
        f.poly(tear(x, y, h * g.uniform(0.04, 0.055), -math.pi * 0.5 * side), LIGHT, ink=2.5)
    return _crop(f, size)


def leash_burst(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(808)
    ground = f.u(1.6)
    if i == 0:  # a hot slit splitting open across the floor
        slit = wobble_ring(c, ground, f.u(0.62), 801, amp=0.12, lumps=(3, 5), n=60, squash=0.16)
        f.fill(poly_mask([slit], S), LIGHT, ink=4.0)
        f.fill(ellipse_mask(c, ground - f.u(0.01), f.u(0.34), f.u(0.04), S), HOT)
        for a in (-2.7, -2.2, -0.95, -0.45):  # sparks of lava at the lips
            x, y = c + math.cos(a) * f.u(0.5), ground + math.sin(a) * f.u(0.16)
            f.poly(tear(x, y - f.u(0.04), f.u(0.045), a), LIGHT, ink=3.0)
        return f.finish()
    cool = [0, 0, 0, 0.1, 0.3, 0.55, 1.0][i]
    reach = [0, 1.0, 1.28, 1.2, 0.85, 0.5, 0.25][i]  # the tongues' length, frame units
    spread = [0, 1.0, 1.08, 1.15, 1.2, 1.2, 1.0][i]
    w0 = f.u([0, 0.26, 0.28, 0.22, 0.18, 0.16, 0.0][i])
    shapes = []
    tips = []
    # the fan: five tongues out of the seam, the middle tallest, the outer ones thrown wide and sagging
    for k, (a, ln) in enumerate([(-2.55, 0.62), (-2.05, 0.86), (-1.57, 1.0), (-1.1, 0.84), (-0.6, 0.6)]):
        if w0 <= 0:
            break
        a = -math.pi * 0.5 + (a + math.pi * 0.5) * spread
        L = f.u(ln) * reach
        sag = f.u(0.35) * max(0.0, (i - 1) * 0.35) * abs(math.cos(a)) * 1.6
        gap = f.u(0.2) * max(0, i - 2) * 0.6  # the tongues come off the seam as they let go
        path = [(c + math.cos(a) * (gap + L * q), min(ground - f.u(0.06), ground + math.sin(a) * (gap + L * q) + sag * q * q))
                for q in np.linspace(0, 1, 16)]  # (a sagging tongue lands on the floor, never through it)
        shapes.append(tongue(path, w0 * (1.15 if k == 2 else 0.95), f.u(0.075)))
        tips.append(path[-1])
    # the foot: the seam's lumpy puddle
    foot = wobble_ring(c, ground - f.u(0.03 + 0.04 * cool), f.u(0.62 + 0.08 * cool), 803 + i, amp=0.1, lumps=(3, 5), n=60,
                       squash=0.24 + 0.1 * cool)
    shapes.append(foot)
    if i == 6:  # the mound: a crusted heap where the seam went up
        shapes.append(wobble_ring(c, ground - f.u(0.14), f.u(0.36), 806, amp=0.12, lumps=(3, 4), n=48, squash=0.55))
    m = poly_mask(shapes, S)
    f.fill(m, BODY, ink=5.5)
    if cool < 0.8:  # the lit sides and hot cores of the tongues, offset up-left
        for k, (x, y) in enumerate(tips):
            f.fill(ellipse_mask(x - f.u(0.02), y - f.u(0.025), f.u(0.05), f.u(0.04), S) * m, LIGHT)
        inner = shrink(m, f.u(0.06))
        f.fill(np.roll(inner, -int(f.u(0.025)), 1) * m * (1 - cool), LIGHT)
        core = shrink(m, f.u(0.13))
        f.fill(np.roll(core, -int(f.u(0.03)), 1) * m * (1 - cool), HOT)
    if cool > 0:  # crust plates closing over it from the foot up, hot joins between
        d, d2, _ = voronoi(S, [(c + g.uniform(-0.7, 0.7) * f.u(1), ground - g.uniform(0, 1.3) * f.u(1)) for _ in range(18)])
        yy, _xx = np.mgrid[0:S, 0:S]
        plate = ((d2 - d) > f.u(lerp(0.05, 0.02, cool))).astype(np.float32) * shrink(m, f.u(0.025))
        plate *= ((ground - yy) < f.u(1.5) * cool).astype(np.float32)
        f.fill(plate, DEEP if cool < 0.7 else INK + 0.12)
    # globs thrown off the tongues, then falling
    if i >= 2:
        k = i - 2
        for s, (x0, y0) in enumerate(tips):
            ang = math.atan2(y0 - ground, x0 - c)
            x = x0 + math.cos(ang) * f.u(0.16) * k
            y = y0 + math.sin(ang) * f.u(0.16) * k + f.u(0.11) * k * k
            if y > ground - f.u(0.06) or y < f.u(0.05) or x < f.u(0.05) or x > S - f.u(0.05):
                continue
            f.poly(tear(x, y, f.u(0.075 - 0.009 * k), ang if k < 2 else math.pi * 0.5), LIGHT if cool < 0.5 else BODY, ink=4.0)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "lava_seam": (lava_seam, 256, 1, 4, "earth", "none", 0.9),
    "leash_burst": (leash_burst, 384, 4, 7, "earth", "edge", 0.5),
}


def build(name, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    if frames[0][0].shape[0] != frames[0][0].shape[1]:  # strips: rows stacked; the age erodes it (fbm order)
        tone = np.concatenate([fr[0] for fr in frames], 0)
        alpha = np.concatenate([fr[1] for fr in frames], 0)
        g = fbm(alpha.shape, 9, scales=(6, 3, 1))
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


if __name__ == "__main__":
    main()
