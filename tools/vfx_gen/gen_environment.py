"""Generate the environment's sheets (round 50, docs/features/environment.md): the structure indicator that marks the
wall or pillar an environmental ending will use, and the beats the structures play when a thrown foe hits them.

    python tools/vfx_gen/gen_environment.py [name ...] [--preview=<dir>] [--out=<dir>]

Same format as gen_spectacle.py / gen_counter.py (tone, erode order, boil, cover; see vfxlib.py). Registered at
runtime by scripts/env_target.gd (DESIGNED.extra_sheets), played in the ending's element row (or "dust": stone).

Shape language: the indicator is the one hard, graphic thing in the room, an inker's target bracket. Four fat corner
brackets (each an L with a lit stripe, inked), four chevrons marching in on the middle and a hot pip, no words.
"Too far" is the same bracket broken into dashes, thin, with no chevrons. The pillar gets a floor ring of inward
chevrons round its foot; the aim line is a row of floor chevrons from the pile to it. The beats are drawn stone and
marks: chunky inked rocks with a lit facet, and wall marks per element that stay for the room's life.

    env_bracket   sprite, 8 frames: 0 the pop-in (wide, hot), 1-3 the loop (chevrons marching in), 4 the lock (snapped
                  tight round a hot star: the press took it), 5 the lock breaking up, 6 too far (dashed, thin),
                  7 in reach but not the pick (brackets only).
    env_ring      ground, 4 frames: 0-2 the pillar's floor ring loop (inward chevrons stepping in), 3 too far (dashes).
    env_chevron   ground, 4 frames: one floor chevron pointing +u, in four brightnesses (the aim line marches them).
    env_chunk     sprite, 4 frames: four stone chunks (one a piece; `first` picks it), a lit facet and a crack each.
    env_mark      ground, 6 frames (one a piece): 0 a crack (hit), 1 a scorch (magma), 2 a frost glaze (ice: no
                  crystals, cracked glaze and drips), 3 an ink splat (dark), 4 a forked bolt burn (storm), 5 a pillar's
                  tall crack.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, ellipse_mask, jag_path, pack,  # noqa: E402
                    poly_mask, preview, rng, save, star, stroke, wobble_ring)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


def polar(cx, cy, r, a):
    return cx + math.cos(a) * r, cy + math.sin(a) * r


def rot(x, y, cx, cy, a):
    dx, dy = x - cx, y - cy
    return cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)


# --- the bracket --------------------------------------------------------------------------------------------------

def corner(f, cx, cy, R, arm, w, tone, a, ink=3.5, dashes=0, lit=True):
    """One corner bracket: an L with its corner at angle `a` (a diagonal), arms running back along the square's
    sides. `dashes` > 0 cuts each arm into that many pieces (too far)."""
    kx, ky = polar(cx, cy, R * math.sqrt(2.0), a)
    # the two arms run from the corner toward the neighbouring corners
    ends = []
    for s in (-1, 1):
        b = a + s * math.pi / 4.0 + math.pi
        # along the side: from the corner, direction to the square's side midpoint
        dx, dy = math.cos(a + s * math.pi / 4 + math.pi), math.sin(a + s * math.pi / 4 + math.pi)
        ends.append((kx + dx * arm, ky + dy * arm))
    path = [ends[0], (kx, ky), ends[1]]
    if dashes == 0:
        m = poly_mask([stroke(path, [w * 0.7, w, w * 0.7], cap=True)], f.S)
        f.fill(m, tone, ink=ink)
        if lit:
            inner = [(lerp(p[0], cx, 0.07), lerp(p[1], cy, 0.07)) for p in path]
            lm = poly_mask([stroke(inner, [w * 0.18, w * 0.3, w * 0.18], cap=False)], f.S) * m
            f.fill(lm, LIGHT if tone < LIGHT else HOT)
        return m
    for end in ends:
        for k in range(dashes):
            t0, t1 = k / dashes + 0.08, (k + 1) / dashes - 0.08
            p0 = (lerp(kx, end[0], t0), lerp(ky, end[1], t0))
            p1 = (lerp(kx, end[0], t1), lerp(ky, end[1], t1))
            f.poly(stroke([p0, p1], [w, w], cap=True), tone, ink=ink)
    return None


def chevron(f, cx, cy, r, a, size, w, tone, ink=2.8):
    """A chevron at radius r on angle a, its point toward the middle."""
    tip = polar(cx, cy, r, a)
    back_l = polar(cx, cy, r + size, a - size / max(r, 1.0) * 0.9)
    back_r = polar(cx, cy, r + size, a + size / max(r, 1.0) * 0.9)
    return f.poly(stroke([back_l, tip, back_r], [w * 0.6, w, w * 0.6], cap=True), tone, ink=ink)


def pip(f, cx, cy, r, tone=HOT):
    pts = [polar(cx, cy, r * (1.0 if k % 2 == 0 else 0.42), math.pi / 4 * k - math.pi / 2) for k in range(8)]
    return f.poly(pts, tone, ink=2.5)


def env_bracket(i, n, size):
    f = Frame(size)
    c = f.c
    corners = [math.pi / 4 + math.pi / 2 * k for k in range(4)]  # (the square's corners on the diagonals)
    jit = rng(5100)
    tilt = [jit.uniform(-0.05, 0.05) for _ in range(4)]
    if i in (0, 1, 2, 3):
        R = f.u([0.66, 0.56, 0.55, 0.55][i])
        arm = f.u([0.3, 0.27, 0.27, 0.27][i])
        w = f.u(0.1)
        tone = HOT if i == 0 else BODY
        for k, a in enumerate(corners):
            corner(f, c, c, R, arm, w, tone, a + tilt[k])
        if i == 0:
            pip(f, c, c, f.u(0.12), HOT)
            return f.finish()
        rc = f.u([0, 0.5, 0.41, 0.32][i])
        for k in range(4):
            chevron(f, c, c, rc, math.pi / 2 * k, f.u(0.16), f.u(0.075), LIGHT if i != 3 else HOT)
        pip(f, c, c, f.u(0.085 if i != 3 else 0.11), HOT)
        return f.finish()
    if i == 4:  # the lock: snapped tight round a hot star
        R = f.u(0.42)
        tips = [0.62, 0.36, 0.55, 0.34, 0.66, 0.38, 0.52, 0.35]
        m = f.poly(star(c, c, [f.u(t) for t in tips], f.u(0.2), rot=0.2, bow=0.15, n_edge=3), LIGHT, ink=3.5)
        f.fill(poly_mask([star(c, c, [f.u(t * 0.5) for t in tips], f.u(0.1), rot=0.25, bow=0.2)], f.S) * m, HOT)
        for k, a in enumerate(corners):
            corner(f, c, c, R, f.u(0.24), f.u(0.13), BODY, a)
        return f.finish()
    if i == 5:  # the lock breaking up: the brackets thrown back out, thin; the star hollowed
        R = f.u(0.6)
        for k, a in enumerate(corners):
            corner(f, c, c, R, f.u(0.2), f.u(0.07), BODY, a + tilt[k] * 2, ink=2.5, lit=False)
        f.poly(wobble_ring(c, c, f.u(0.34), 5111, amp=0.12), LIGHT, ink=2.0)
        f.cut(poly_mask([wobble_ring(c, c, f.u(0.27), 5112, amp=0.16)], f.S))
        return f.finish()
    if i == 6:  # too far: dashed, thin, no chevrons
        R = f.u(0.55)
        for k, a in enumerate(corners):
            corner(f, c, c, R, f.u(0.3), f.u(0.055), BODY, a + tilt[k], ink=2.0, dashes=2)
        f.fill(ellipse_mask(c, c, f.u(0.045), f.u(0.045), f.S), BODY, ink=1.6)
        return f.finish()
    # 7: in reach, not the pick: the brackets alone
    R = f.u(0.55)
    for k, a in enumerate(corners):
        corner(f, c, c, R, f.u(0.27), f.u(0.075), BODY, a + tilt[k], ink=2.6, lit=False)
    return f.finish()


# --- the pillar's floor ring --------------------------------------------------------------------------------------

def env_ring(i, n, size):
    f = Frame(size)
    c = f.c
    if i == 3:  # too far: a dashed ring
        for k in range(12):
            a0 = math.tau * k / 12
            path = [polar(c, c, f.u(0.7), a0 + t) for t in np.linspace(0.05, 0.38, 6)]
            f.poly(stroke(path, [f.u(0.04)] * 2, cap=True), BODY, ink=1.8)
        return f.finish()
    spin = 0.12 * i
    for k in range(6):  # the broken inked ring
        a0 = spin + math.tau * k / 6
        path = [polar(c, c, f.u(0.62), a0 + t) for t in np.linspace(0.08, math.tau / 6 - 0.08, 10)]
        m = poly_mask([stroke(path, [f.u(0.03), f.u(0.065), f.u(0.03)], cap=True)], f.S)
        f.fill(m, BODY, ink=2.5)
    rc = f.u([0.86, 0.8, 0.74][i])
    for k in range(6):
        a = spin + math.tau * (k + 0.5) / 6
        chevron(f, c, c, rc, a, f.u(0.12), f.u(0.06), LIGHT if i < 2 else HOT, ink=2.4)
    return f.finish()


# --- the aim line's chevron ---------------------------------------------------------------------------------------

def env_chevron(i, n, size):
    f = Frame(size)
    c = f.c
    tone = [BODY, LIGHT, HOT, DEEP][i]
    w = f.u(0.2)
    pts = [(c - f.u(0.38), c - f.u(0.55)), (c + f.u(0.32), c), (c - f.u(0.38), c + f.u(0.55))]
    f.poly(stroke(pts, [w * 0.6, w, w * 0.6], cap=True), tone, ink=3.0)
    return f.finish()


# --- stone chunks -------------------------------------------------------------------------------------------------

def env_chunk(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(5300 + i)
    k = [6, 5, 7, 5][i]
    pts = []
    for j in range(k):
        a = math.tau * j / k + g.uniform(-0.25, 0.25)
        r = f.u(g.uniform(0.55, 0.85))
        pts.append(polar(c, c, r, a))
    m = f.poly(pts, BODY, ink=4.0)
    # the lit facet (upper left) and the shadow side
    lit = [(lerp(p[0], c - f.u(0.25), 0.55), lerp(p[1], c - f.u(0.25), 0.55)) for p in pts[: max(3, k // 2 + 1)]]
    f.fill(poly_mask([lit], f.S) * m, LIGHT)
    sh = [(lerp(p[0], c + f.u(0.3), 0.5), lerp(p[1], c + f.u(0.3), 0.5)) for p in pts[k // 2:] + pts[:1]]
    f.fill(poly_mask([sh], f.S) * m, DEEP)
    # a crack across it
    a = g.uniform(0, math.pi)
    p0, p1 = polar(c, c, f.u(0.6), a), polar(c, c, f.u(0.15), a + 2.4)
    f.fill(poly_mask([stroke([p0, (c, c), p1], [f.u(0.05), f.u(0.03), 0.0], cap=False)], f.S) * m, INK)
    return f.finish()


# --- wall and pillar marks ----------------------------------------------------------------------------------------

def _cracks(f, cx, cy, n_cracks, length, w, seed, tone=INK, spread=math.tau, a0=0.0):
    g = rng(seed)
    for j in range(n_cracks):
        a = a0 + spread * (j + g.uniform(0.2, 0.8)) / n_cracks
        L = length * g.uniform(0.6, 1.0)
        end = polar(cx, cy, L, a)
        path = jag_path((cx, cy), end, L / 4, 0.5, seed + j)
        f.poly(stroke(path, [w, w * 0.6, 0.0], cap=False), tone)
        if g.random() < 0.6:  # a branch
            mid = path[len(path) // 2]
            b = a + g.choice([-0.7, 0.7])
            bend = polar(mid[0], mid[1], L * 0.4, b)
            f.poly(stroke(jag_path(mid, bend, L / 6, 0.4, seed + 50 + j), [w * 0.5, 0.0], cap=False), tone)


def env_mark(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(5400 + i)
    if i == 0:  # a crack: a pocked dent and cracks running off it
        f.poly(wobble_ring(c, c, f.u(0.2), 5401, amp=0.25), DEEP, ink=3.0)
        f.fill(ellipse_mask(c - f.u(0.05), c - f.u(0.05), f.u(0.08), f.u(0.06), f.S), BODY)
        _cracks(f, c, c, 7, f.u(0.85), f.u(0.06), 5402)
        return f.finish()
    if i == 1:  # a scorch: a dark blotch, ragged, with a few cooling hot veins
        m = f.poly(wobble_ring(c, c, f.u(0.62), 5411, amp=0.3, lumps=(3, 5, 11)), INK)
        f.fill(poly_mask([wobble_ring(c, c, f.u(0.44), 5412, amp=0.3)], f.S) * m, DEEP)
        _cracks(f, c, c, 5, f.u(0.48), f.u(0.045), 5413, tone=HOT)
        for _ in range(9):  # spatter round the rim
            a = g.uniform(0, math.tau)
            x, y = polar(c, c, f.u(g.uniform(0.66, 0.92)), a)
            r = f.u(g.uniform(0.025, 0.06))
            f.fill(ellipse_mask(x, y, r, r, f.S), INK)
        return f.finish()
    if i == 2:  # a frost glaze: a cracked sheet with drips, no crystals
        m = f.poly(wobble_ring(c, c - f.u(0.1), f.u(0.55), 5421, amp=0.22, squash=0.75), BODY, ink=3.0)
        f.fill(poly_mask([wobble_ring(c - f.u(0.1), c - f.u(0.2), f.u(0.3), 5422, amp=0.2, squash=0.6)], f.S) * m, LIGHT)
        _cracks(f, c, c - f.u(0.05), 6, f.u(0.5), f.u(0.03), 5423, tone=DEEP)
        for k in range(5):  # drips down off its bottom edge
            x = c + f.u(-0.4 + 0.2 * k + g.uniform(-0.04, 0.04))
            y0 = c + f.u(0.25)
            L = f.u(g.uniform(0.2, 0.5))
            f.poly(stroke([(x, y0), (x, y0 + L)], [f.u(0.07), f.u(0.05), f.u(0.06)], cap=True), BODY, ink=2.0)
        return f.finish()
    if i == 3:  # an ink splat: a fat blot, thrown droplets and runs
        f.poly(wobble_ring(c, c, f.u(0.42), 5431, amp=0.38, lumps=(4, 7, 13)), DEEP, ink=3.0)
        f.fill(poly_mask([wobble_ring(c - f.u(0.08), c - f.u(0.1), f.u(0.16), 5432, amp=0.3)], f.S), BODY)
        for _ in range(8):
            a = g.uniform(0, math.tau)
            rr = f.u(g.uniform(0.55, 0.9))
            x, y = polar(c, c, rr, a)
            r = f.u(g.uniform(0.03, 0.07))
            f.fill(ellipse_mask(x, y, r, r, f.S), DEEP, ink=1.8)
        for k in range(3):  # runs
            x = c + f.u(-0.2 + 0.2 * k)
            f.poly(stroke([(x, c + f.u(0.3)), (x + f.u(0.02), c + f.u(0.7 + 0.1 * k))], [f.u(0.06), f.u(0.03)], cap=True), DEEP, ink=1.8)
        return f.finish()
    if i == 4:  # a forked bolt burn: scorched forks off a hot point
        for j in range(5):
            a = -math.pi / 2 + (j - 2) * 0.62 + g.uniform(-0.15, 0.15)
            end = polar(c, c, f.u(g.uniform(0.6, 0.92)), a + math.pi)
            path = jag_path((c, c), end, f.u(0.16), 0.7, 5440 + j)
            f.poly(stroke(path, [f.u(0.09), f.u(0.05), 0.0], cap=False), DEEP, ink=2.5)
            f.poly(stroke(path, [f.u(0.03), f.u(0.015), 0.0], cap=False), LIGHT)
        pip(f, c, c, f.u(0.12), HOT)
        return f.finish()
    # 5: a pillar's tall crack (drawn up the frame: the decal stands on the pillar's face)
    path = jag_path((c + f.u(0.05), c + f.u(0.92)), (c - f.u(0.05), c - f.u(0.9)), f.u(0.22), 0.55, 5450)
    f.poly(stroke(path, [f.u(0.03), f.u(0.08), f.u(0.06), 0.0], cap=False), INK)
    for j in range(4):
        mid = path[2 + j * max(1, (len(path) - 4) // 4)]
        side = 1 if j % 2 else -1
        end = (mid[0] + side * f.u(0.32), mid[1] - f.u(0.1))
        f.poly(stroke(jag_path(mid, end, f.u(0.1), 0.4, 5460 + j), [f.u(0.04), 0.0], cap=False), INK)
    f.poly(wobble_ring(c, c + f.u(0.1), f.u(0.14), 5470, amp=0.3), DEEP, ink=2.0)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "env_bracket": (env_bracket, 256, 4, 8, "earth", "center", 0.4),
    "env_ring": (env_ring, 256, 2, 4, "wind", "edge", 0.45),
    "env_chevron": (env_chevron, 96, 4, 4, "earth", "edge", 0.4),
    "env_chunk": (env_chunk, 128, 4, 4, "dust", "edge", 0.5),
    "env_mark": (env_mark, 256, 3, 6, "earth", "edge", 0.55),
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
        preview(sheet, pal, (0.0, 0.5)).save(os.path.join(prev_dir, name + "_preview.png"))
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
