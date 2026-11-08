"""Sheets for the fx-queue-b lane (docs/features/fx-language.md queue items 7-9).

    hail_whirl  sprite, 8 frames (4x2): Hailstorm's lift riding a frozen foe (comic_hail.ride, designed), in the air
                language: three fat wind ribbons wrapping the cube as a helix, widening upward, the far half of each
                a band darker (behind the cube), the near half lit; each ends in a curled hook; three hail pellets
                carried round in it (round lumps, never crystals). Frame 0 the anticipation (pinched low, pellets
                dragged in along the floor), 1 the peak, 2-5 turning on twos, 6-7 broken into curls flung outward.
                Played through the `air` palette row.

    python tools/vfx_gen/gen_queue.py [names] [--preview=<dir>] [--out=<dir>]
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, LIGHT, Frame, catmull, ellipse_mask, pack, poly_mask, preview, rng, save,  # noqa: E402
                    stroke, wobble_ring)
from air_sheets import curl, ease_out, lerp, path_normals  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def _piece(f, pts, widths, tone, lit, ink=2.6):
    """One run of a wind ribbon (px points, px widths): body or deep, a light band on its top edge when `lit`."""
    if len(pts) < 2:
        return
    p = np.asarray(pts, np.float64)
    w = np.asarray(widths, np.float64)
    m = poly_mask([stroke(p, list(w), cap=False)], f.S)
    f.fill(m, tone, ink=ink)
    if lit:
        nrm = path_normals(p)
        lp = p - nrm * (w[:, None] * 0.24)
        f.fill(poly_mask([stroke(lp, list(w * 0.4), cap=False)], f.S) * m, LIGHT)
    return m


def _band(f, cx, cy, rx, ry, a0, sweep, rise, wmax, hook_r, n=40):
    """A helix band round (cx, cy): its points, widths and which are near (front) / far (back). Tapers both ends,
    fattest past the middle, ending in a curl."""
    pts, ws, near = [], [], []
    for k in range(n):
        q = k / (n - 1)
        a = a0 + sweep * q
        pts.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry - rise * q))
        ws.append(wmax * (math.sin(min(q / 0.6, 1.0) * math.pi / 2) ** 0.8 if q < 0.6 else 1.0 - 0.75 * ((q - 0.6) / 0.4) ** 1.2) + 1.5)
        near.append(math.sin(a) > -0.05)
    ex, ey = pts[-1]
    ex0, ey0 = pts[-2]
    hook = curl(ex, ey, math.atan2(ey - ey0, ex - ex0), hook_r, turns=0.8, shrink=0.6, n=12, cw=1.0 if sweep > 0 else -1.0)
    w_end = ws[-1]
    for k, h in enumerate(hook[1:]):
        pts.append(h)
        ws.append(w_end * (1 - (k + 1) / len(hook)) + 1.0)
        near.append(near[-1])
    return pts, ws, near


def _runs(pts, ws, near, want):
    runs, cur = [], ([], [])
    for p, w, n_ in zip(pts, ws, near):
        if n_ == want:
            cur[0].append(p)
            cur[1].append(w)
        elif cur[0]:
            runs.append(cur)
            cur = ([], [])
    if cur[0]:
        runs.append(cur)
    return runs


def _pellet(f, x, y, r, seed):
    """A hail pellet: a round inked lump, lit top-left, a shadow at the bottom (never a crystal)."""
    m = f.poly(wobble_ring(x, y, r, seed, amp=0.12, lumps=(2, 3, 4), n=32, squash=0.85), BODY, ink=2.4)
    f.fill(poly_mask([wobble_ring(x - r * 0.18, y - r * 0.22, r * 0.55, seed + 1, amp=0.15, n=24)], f.S) * m, LIGHT)
    f.fill(np.clip(m - ellipse_mask(x - r * 0.1, y - r * 0.25, r * 0.95, r * 0.95, f.S), 0, 1) * m, DEEP)


def hail_whirl(i, n, size):
    f = Frame(size)
    c = f.c
    g = rng(5101)
    t = i / (n - 1)
    cy = c + f.u(0.1)
    bands = [(0.5, 0.42, 0.0), (0.1, 0.6, 1.9), (-0.32, 0.78, 3.9)]  # (height, radius, phase), bottom first
    if i == 0:  # anticipation: pinched low and small, pellets dragged in along the floor
        for k, (h, r, ph) in enumerate(bands[:2]):
            pts, ws, near = _band(f, c, cy + f.u(0.45 + 0.08 * k), f.u(r * 0.5), f.u(r * 0.5 * 0.42), ph, 1.2 * math.pi,
                                  f.u(0.06), f.u(0.07), f.u(0.05))
            for p, w in _runs(pts, ws, near, False):
                _piece(f, p, w, DEEP, False, ink=2.2)
            for p, w in _runs(pts, ws, near, True):
                _piece(f, p, w, BODY, True, ink=2.2)
        for k in range(3):
            a = 0.6 + k * 2.1
            _pellet(f, c + math.cos(a) * f.u(0.62), cy + f.u(0.62) + math.sin(a) * f.u(0.14), f.u(0.06), 5110 + k)
        return f.finish()
    breaking = i >= n - 2
    turn = 0.62 * (i - 1)
    grow = lerp(1.08, 1.0, min(1.0, (i - 1) / 2.0))  # the peak's overshoot, settled by frame 3
    fronts = []
    for k, (h, r, ph) in enumerate(bands):
        rx = f.u(r) * grow
        ry = rx * 0.42
        y = cy + f.u(h)
        w = f.u(lerp(0.13, 0.17, k / 2)) * lerp(1.0, 0.75, t)
        if not breaking:
            pts, ws, near = _band(f, c, y, rx, ry, ph + turn * (1 + 0.15 * k), 1.35 * math.pi, f.u(0.12), w, f.u(0.07))
            for p, ww in _runs(pts, ws, near, False):
                _piece(f, p, ww, DEEP, False)
            fronts.append((pts, ws, near, k))
        else:  # broken into two short curls a band, flung further out
            for j in range(2):
                a0 = ph + turn + j * math.pi + 0.4
                out = lerp(1.0, 1.12, (i - (n - 2)))
                pts, ws, near = _band(f, c, y - f.u(0.06 * (i - n + 3)), rx * out, ry * out, a0, 0.55 * math.pi, f.u(0.04), w * 0.7,
                                      f.u(0.05), n=16)
                _piece(f, pts, ws, BODY, True, ink=2.2)
    # hail carried round in it: three pellets rising with the turn (in front of the far halves, behind the near)
    for k in range(3):
        a = 0.9 + turn * 1.4 + k * 2.2
        h = lerp(0.55, -0.35, (k / 2) * 0.6 + t * 0.4)
        rr = lerp(0.45, 0.75, (k / 2))
        out = 1.0 if not breaking else lerp(1.12, 1.25, i - (n - 2))
        x = c + math.cos(a) * f.u(rr) * out
        yy = cy + f.u(h) + math.sin(a) * f.u(rr * 0.42) * out
        _pellet(f, x, yy, f.u(0.09 * (1.0 if not breaking else 0.8)), 5120 + k + 3 * i)
    for pts, ws, near, k in fronts:
        for p, ww in _runs(pts, ws, near, True):
            m = _piece(f, p, ww, BODY, True)
            if i <= 2 and k == 2 and m is not None and len(p) > 6:  # the one hot area: the top band's lead edge
                q0 = len(p) // 3
                hp = np.asarray(p[q0:q0 + max(3, len(p) // 3)], np.float64)
                f.fill(poly_mask([stroke(hp, lambda q: f.u(0.03) * math.sin(q * math.pi) + 0.5, cap=False)], f.S) * m, HOT)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "hail_whirl": (hail_whirl, 256, 4, 8, "air", "edge", 0.45),
}


def build(name, out_dir, prev_dir=None):
    fn, size, cols, count, pal, mode, nw = SHEETS[name]
    frames = [fn(i, count, size) for i in range(count)]
    sheet = pack(frames, cols, seed=sum(map(ord, name)), mode=mode, noise_w=nw)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".png")
    save(sheet, path)
    if prev_dir:
        os.makedirs(prev_dir, exist_ok=True)
        preview(sheet, pal, (0.0, 0.4, 0.7)).save(os.path.join(prev_dir, name + "_preview.png"))
    print(name, sheet.shape[1], "x", sheet.shape[0], "->", os.path.normpath(path))


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    prev = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--preview=")), None)
    out = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--out=")), OUT)
    for name in names or SHEETS:
        build(name, out, prev)


if __name__ == "__main__":
    main()
