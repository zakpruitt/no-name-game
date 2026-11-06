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


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "awaken_gather": (awaken_gather, 320, 3, 6, "gold", "edge", 0.5),
    "awaken_crown": (awaken_crown, 384, 4, 8, "gold", "edge", 0.5),
    "awaken_floor": (awaken_floor, 320, 3, 6, "gold", "edge", 0.5),
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
