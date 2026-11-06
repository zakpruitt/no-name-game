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


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "tentacle_skin": (tentacle_skin, 256, 1, 3, "void", "none", 0.9),
    "tentacle_smear": (tentacle_smear, 256, 1, 2, "void", "tail", 0.35),
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
