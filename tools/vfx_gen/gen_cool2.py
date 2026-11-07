"""Generate the round 52 cool pass sheets (combo-cool2 lane, docs/features/combo-breakers.md "Round 52 cool pass"):
the rebuilt Eruption and Flash Freeze and Collapse's louder spit, played by scripts/eruption_hurl.gd,
scripts/frost_shell.gd and scripts/collapse_spit.gd (DESIGNED.extra_sheets).

    python tools/vfx_gen/gen_cool2.py [name ...] [--preview=<dir>]

Same format as gen_cool.py (tone, erode order, boil, cover; see vfxlib.py). No polygons at runtime, no crystals: ice
is rounded frost lumps, rime and powder, steam is lumpy puffs, magma is round tongues and globs, the dark is ink.

    erupt_chain   ground strip (gen_cool.py's drawing, now played): Eruption's fuse, the lava crack that races along
                  the floor from where he landed to each burning foe (ribbon, 4 boils).
    erupt_drip    sprite_depth, stood on the floor against the wall: a burning foe splatted on the wall and sliding
                  down it. 0 the splat high up (a fat blob, globs flung out); 1-3 the lava runs down the wall in three
                  streams, the middle one the foe's (fattest); 4 it pools at the foot, licks rising; 5 the streams
                  crusting dark; 6 cooled scabs.
    steam_shell   sprite_depth, stood on the floor at a foe: Flash Freeze's steam rolling over it and setting. 0 puffs
                  at its feet; 1 billowing up round it; 2 tallest, curling over its head; 3 drawn in tight, a rime of
                  rounded frost lumps where it touches; 4 the steam thinning off the shell; 5 a low cold mist.
    spit_burst    sprite: Collapse's spit, round 52: a fat ink crown thrown up out of the hole as each foe comes
                  back out (a ring of teardrop globs flung out, a splash column, drops falling). 6 frames.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import (BODY, DEEP, HOT, INK, LIGHT, Frame, ellipse_mask, fbm, pack,  # noqa: E402
                    poly_mask, preview, rng, save, shrink, stroke, wobble_ring)
from gen_elements import tear, tongue  # noqa: E402
from gen_cool import erupt_chain  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def lerp(a, b, t):
    return a + (b - a) * t


# --- erupt_drip -----------------------------------------------------------------------------------------------------

def _stream(f, x, top, bottom, w, wobble, seed, tone=BODY, ink=4.0):
    """A lava stream running down the wall from (x, top) to `bottom`, lumpy, fattening into a drop at its foot."""
    g = rng(seed)
    n = 26
    path = []
    for k in range(n + 1):
        q = k / n
        y = lerp(top, bottom, q)
        path.append((x + f.u(wobble) * math.sin(q * 7.0 + seed) * (0.4 + q), y))
    body = stroke(path, lambda q: w * (0.75 + 0.25 * math.sin(q * 9 + seed)) * (1.0 - 0.3 * q) + w * 0.5 * math.exp(-((q - 1.0) ** 2) * 60),
                  cap=True)
    m = poly_mask([body], f.S)
    f.fill(m, tone, ink=ink)
    core = stroke(path[:-2], lambda q: w * 0.32 * (1.0 - 0.4 * q), cap=True)
    f.fill(poly_mask([core], f.S) * m, HOT)
    _ = g
    return path[-1]


def erupt_drip(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(5401)
    ground = f.u(1.86)
    splat_y = f.u(0.42)
    cool = [0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.9][i]
    body_t = lerp(BODY, DEEP, cool)
    # the streams: run down the wall from the splat (the middle one is where the foe slides)
    run = [0.0, 0.35, 0.7, 1.0, 1.0, 1.0, 1.0][i]
    if i >= 1:
        for k, (dx, w, seed) in enumerate(((-0.26, 0.1, 3), (0.0, 0.19, 7), (0.25, 0.09, 11))):
            r = run * (1.0 if k == 1 else 0.85)
            bottom = lerp(splat_y + f.u(0.1), ground - f.u(0.03), r)
            _stream(f, c + f.u(dx), splat_y + f.u(0.05), bottom, f.u(w) * (1.0 - 0.35 * cool), 0.04 + 0.02 * k, 5410 + seed,
                    tone=body_t)
    # the pool at the foot, with licks rising off it
    if i >= 3:
        pr = f.u([0, 0, 0, 0.3, 0.46, 0.44, 0.36][i])
        pool = wobble_ring(c, ground, pr, 5430 + i, amp=0.14, lumps=(3, 5), n=60, squash=0.28)
        f.fill(poly_mask([pool], S), body_t, ink=4.0)
        if cool < 0.5:
            f.fill(ellipse_mask(c, ground, pr * 0.6, pr * 0.12, S), HOT)
            for k in range(3):
                x = c + f.u((-0.2, 0.05, 0.24)[k])
                tall = f.u([0, 0, 0, 0.2, 0.3, 0.12, 0][i] * (1.0 if k == 1 else 0.7))
                if tall > 0:
                    path = [(x, ground - f.u(0.02)), (x + f.u(0.03), ground - tall * 0.5), (x - f.u(0.02), ground - tall)]
                    f.poly(tongue(path, f.u(0.06), f.u(0.025)), LIGHT, ink=3.0)
    # the splat: a fat blob with lumps flung out round it (biggest on 0, shrinking as it runs off)
    sr = f.u([0.3, 0.27, 0.24, 0.2, 0.17, 0.15, 0.12][i])
    splat = wobble_ring(c, splat_y, sr, 5450 + min(i, 2), amp=0.22, lumps=(4, 7), n=80, squash=0.85)
    f.fill(poly_mask([splat], S), body_t, ink=4.5)
    if cool < 0.5:
        f.fill(ellipse_mask(c - sr * 0.1, splat_y - sr * 0.12, sr * 0.5, sr * 0.36, S), LIGHT)
        f.fill(ellipse_mask(c - sr * 0.18, splat_y - sr * 0.2, sr * 0.22, sr * 0.15, S), HOT)
    else:  # crusted: dark plates with a few hot cracks
        for k in range(3):
            a = g.uniform(0, math.tau)
            x, y = c + math.cos(a) * sr * 0.4, splat_y + math.sin(a) * sr * 0.4
            f.fill(ellipse_mask(x, y, sr * 0.12, sr * 0.04, S), LIGHT if cool < 0.8 else DEEP)
    if i <= 2:  # globs flung off the splat
        for k in range(7):
            a = -math.pi * 0.5 + (k - 3) * 0.55 + g.uniform(-0.1, 0.1)
            d = sr * (1.3 + 0.5 * i) + f.u(0.06) * k % 2
            x, y = c + math.cos(a) * d * 1.2, splat_y + math.sin(a) * d * 0.9
            f.poly(tear(x, y, f.u(0.04 - 0.008 * i), a), LIGHT if k % 2 else BODY, ink=3.0)
    return f.finish()


# --- steam_shell ----------------------------------------------------------------------------------------------------

def _puff(f, x, y, r, seed, tone=LIGHT, ink=3.5, hot=True):
    f.poly(wobble_ring(x, y, r, seed, amp=0.12, lumps=(3, 4), n=44), tone, ink=ink)
    if hot:
        f.fill(ellipse_mask(x - r * 0.25, y - r * 0.3, r * 0.42, r * 0.3, f.S), HOT)


def steam_shell(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(5501)
    ground = f.u(1.82)
    # the column of puffs round the foe: heights and widths per frame
    tall = [0.35, 0.95, 1.35, 1.15, 0.9, 0.35][i]
    wide = [0.55, 0.72, 0.7, 0.5, 0.56, 0.75][i]
    count = [4, 7, 9, 8, 6, 5][i]
    for k in range(count):
        q = k / max(count - 1, 1)
        side = -1 if k % 2 else 1
        y = ground - f.u(0.12) - f.u(tall) * q
        sway = (0.38 + 0.18 * math.sin(q * 5.0 + i)) * wide * side
        if i == 2 and q > 0.75:  # curling over the top
            sway *= -0.6
        if i >= 3:  # drawn in tight round the shell
            sway *= 0.75 if i == 3 else 1.0
        x = c + f.u(sway)
        r = f.u((0.2 + 0.08 * (1 - q)) * (1.0 if i < 4 else 0.85) * (0.75 if i == 5 else 1.0))
        tone = LIGHT if i < 4 else BODY
        _puff(f, x, y, r, 5510 + k + 13 * i, tone=tone, ink=3.5 if i < 5 else 2.5, hot=i < 4)
    # the rime: rounded frost lumps where the steam has set on the shell, at its sides and foot (3-4)
    if i in (3, 4):
        for k in range(8):
            q = k / 7
            side = -1 if k % 2 else 1
            y = ground - f.u(0.1) - f.u(0.9) * q
            x = c + side * f.u(0.36 - 0.1 * q)
            r = f.u(0.07 + 0.03 * ((k * 7) % 3) / 2)
            f.poly(wobble_ring(x, y, r, 5560 + k, amp=0.07, lumps=(2, 3), n=28), HOT, ink=3.0)
    # the cold mist along the floor (from 3)
    if i >= 3:
        mr = f.u([0, 0, 0, 0.6, 0.72, 0.8][i])
        mist = wobble_ring(c, ground - f.u(0.04), mr, 5580 + i, amp=0.12, lumps=(4, 7), n=60, squash=0.22)
        f.fill(poly_mask([mist], S), BODY if i < 5 else DEEP, ink=3.0)
        f.fill(ellipse_mask(c, ground - f.u(0.06), mr * 0.6, mr * 0.08, S), LIGHT)
    _ = g
    return f.finish()


# --- spit_burst -----------------------------------------------------------------------------------------------------

def spit_burst(i, n, size):
    f = Frame(size)
    S, c = f.S, f.c
    g = rng(5601)
    base = f.u(1.35)
    # the splash up out of the mouth: three fat ink tongues splaying apart (a crown, not a column), blob tips
    tall = [0.5, 0.9, 1.0, 0.75, 0.4, 0.0][i]
    w = f.u([0.2, 0.24, 0.22, 0.18, 0.14, 0.1][i])
    if tall > 0.0:
        for k, (ang, ln) in enumerate(((-0.55, 0.72), (0.0, 1.0), (0.55, 0.72))):
            spread = ang * (1.0 + 0.5 * i / 5)
            pts = []
            for j in range(8):
                q = j / 7
                a2 = -math.pi * 0.5 + spread * q ** 0.8
                pts.append((c + math.cos(a2) * f.u(tall * ln) * q + (k - 1) * f.u(0.08),
                            base - f.u(0.02) + math.sin(a2) * f.u(tall * ln) * q))
            m = f.poly(tongue(pts, w * (1.0 if k == 1 else 0.8), w * 0.42), BODY if k != 1 else LIGHT, ink=4.5)
            if k == 1:
                f.fill(poly_mask([stroke(pts[:4], lambda q: w * 0.25, cap=True)], S) * m, HOT)
    # the crown: a ring of teardrop globs flung up and out, then falling
    ring = [0.25, 0.6, 0.85, 0.95, 1.0, 1.0][i]
    fall = [0.0, 0.0, 0.1, 0.35, 0.7, 1.0][i]
    for k in range(11):
        a = -math.pi + (k + 0.5) * math.pi / 11 + g.uniform(-0.06, 0.06)
        d = f.u(0.7 * ring) * (0.85 + 0.3 * ((k * 5) % 3) / 2)
        x = c + math.cos(a) * d * 1.25
        y = base + math.sin(a) * d * 0.95 + f.u(0.55) * fall * fall
        ang = a if fall < 0.3 else math.pi * 0.5
        r = f.u(0.075 - 0.01 * i) * (1.2 if k % 3 == 0 else 0.9)
        if r > 0 and 0 < y < S and 0 < x < S:
            f.poly(tear(x, y, r, ang), LIGHT if k % 2 else BODY, ink=3.5)
    # the ink thrown flat round the mouth (0-2), the puddle (3-5)
    pr = f.u([0.5, 0.62, 0.64, 0.58, 0.5, 0.4][i])
    pool = wobble_ring(c, base, pr, 5620 + i, amp=0.15, lumps=(4, 7), n=60, squash=0.3)
    f.fill(poly_mask([pool], S), DEEP, ink=4.0)
    f.fill(ellipse_mask(c, base, pr * 0.55, pr * 0.12, S), INK + 0.06)
    if i <= 2:
        for k in range(6):
            a = -math.pi * 0.5 + (k - 2.5) * 0.6
            x, y = c + math.cos(a) * pr * 1.15, base + math.sin(a) * pr * 0.42
            f.poly(tear(x, y, f.u(0.05), a), BODY, ink=3.0)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "erupt_chain": (erupt_chain, 256, 1, 4, "earth", "none", 0.9),
    "erupt_drip": (erupt_drip, 384, 4, 7, "earth", "edge", 0.5),
    "steam_shell": (steam_shell, 384, 3, 6, "water", "edge", 0.5),
    "spit_burst": (spit_burst, 384, 3, 6, "void", "edge", 0.5),
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
