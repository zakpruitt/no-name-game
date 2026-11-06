"""Lightning payoff sheets (fx-air round 2, docs/features/designed-fx.md "Sky strike").

    strike_scorch  floor, 6 frames: the scorched star a sky strike leaves. Frame 0 white-hot (a jagged star with a hot
                   core and rays), then it cools through the element's light and body tones to its deep tone with
                   hot cracks still glowing, and breaks up wedge by wedge. Jagged, never round.
    arc_crawl      sprite, 6 frames: small arcs crawling over a struck foe: three or four short zigzags on a loose
                   ring that move round it frame to frame, a saturated rim round a hot core, inked.
Both are played through the storm (lightning) palette row.
"""
import math

import numpy as np

from vfxlib import BODY, DEEP, HOT, INK, LIGHT, Frame, jag_path, poly_mask, rng, star, stroke


def lerp(a, b, t):
    return a + (b - a) * t


def strike_scorch(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(501)
    k = 9
    base = [1.0, 0.55, 0.85, 0.5, 0.95, 0.6, 0.8, 0.52, 0.9]
    t = i / (n - 1)
    R = f.u(0.62 if i == 0 else 0.7)
    tips = [R * b * (1.0 + 0.04 * ((s * 7 + i) % 3)) for s, b in enumerate(base)]
    outer = star(c, c, tips, R * 0.36, rot=0.3, bow=0.0, n_edge=2)
    tone = [HOT, LIGHT, BODY, DEEP, DEEP, DEEP][i]
    m = f.poly(outer, tone, ink=2.5)
    if i == 0:  # white-hot: a light ring round a fat hot core
        f.fill(poly_mask([star(c, c, [x * 0.6 for x in tips], R * 0.24, rot=0.3, bow=0.0, n_edge=2)], S), HOT)
    elif i <= 2:
        f.fill(poly_mask([star(c, c, [x * 0.55 for x in tips], R * 0.2, rot=0.3, bow=0.0, n_edge=2)], S) * m, [HOT, LIGHT][i - 1])
    # cracks: jagged hot lines from the middle out along each long spike, thinning as it cools
    for s in range(k):
        if base[s] < 0.8 and i > 0:
            continue
        a = 0.3 + math.tau * s / k
        L = tips[s] * lerp(1.15, 0.9, t)
        p = jag_path((c, c), (c + math.cos(a) * L, c + math.sin(a) * L), f.u(0.12), 0.5, 510 + s)
        w = f.u(lerp(0.05, 0.022, t))
        f.poly(stroke(p, lambda q: w * (1 - 0.7 * q) + 1, cap=False), HOT if i <= 3 else BODY, ink=1.5 if i == 0 else 0)
    if i >= 4:  # breaking up: cut gaps between wedges
        for s in range(5):
            a = g.uniform(0, math.tau)
            p = [(c + math.cos(a) * R * 0.15, c + math.sin(a) * R * 0.15), (c + math.cos(a) * R * 1.2, c + math.sin(a) * R * 1.2)]
            f.cut(poly_mask([stroke(p, [f.u(0.03 * (i - 3))] * 2, cap=False)], S))
    return f.finish()


def arc_crawl(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    if i == 0:  # anticipation: three pin-prick glints on the ring
        for s in range(3):
            a = 0.4 + math.tau * s / 3
            x, y = c + math.cos(a) * f.u(0.5), c + math.sin(a) * f.u(0.62)
            f.poly(star(x, y, [f.u(0.1), f.u(0.04)] * 2, f.u(0.02), rot=a, bow=0.4), HOT, ink=1.5)
        return f.finish()
    t = i / (n - 1)
    count = 4 if i < n - 1 else 2
    for s in range(count):
        a0 = 0.4 + math.tau * s / count + i * 0.55  # crawl round the body frame to frame
        span = lerp(0.9, 0.55, t)
        r0 = f.u(lerp(0.52, 0.6, (s + i) % 2))
        a1 = a0 + span
        A = (c + math.cos(a0) * r0, c + math.sin(a0) * r0 * 1.15)
        B = (c + math.cos(a1) * r0, c + math.sin(a1) * r0 * 1.15)
        p = jag_path(A, B, f.u(0.09), 0.9, 600 + s * 13 + i * 7)
        w = f.u(lerp(0.12, 0.075, t))
        m = f.poly(stroke(p, lambda q: w * (0.5 + 0.5 * math.sin(q * math.pi)) + 1.5, cap=False), BODY, ink=2.0)
        f.fill(poly_mask([stroke(p, lambda q: w * 0.4 * math.sin(q * math.pi) + 0.5, cap=False)], S) * m, HOT)
        if s == 0 and i <= 2:  # one hot spark where an arc leaves the body
            x, y = A
            f.poly(star(x, y, [f.u(0.12), f.u(0.05), f.u(0.1), f.u(0.05)], f.u(0.02), rot=a0, bow=0.3), HOT, ink=1.5)
    return f.finish()


STORM_SHEETS = {
    "strike_scorch": (strike_scorch, 256, 3, 6, "boltA", "edge", 0.5),
    "arc_crawl": (arc_crawl, 192, 3, 6, "boltA", "edge", 0.5),
}
