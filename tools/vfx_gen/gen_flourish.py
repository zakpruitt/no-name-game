"""Generate the round 53 flourishes' sheets (docs/features/env-pieces.md "Flourishes"): the frozen pool's glint
(ice_rink).

    python tools/vfx_gen/gen_flourish.py [name ...] [--preview=<dir>] [--out=<dir>]

Same format as gen_counter.py / gen_designed.py (tone, erode order, boil, cover; see vfxlib.py). Registered at runtime
by scripts/env_flourish.gd (DESIGNED.extra_sheets), played in the `water` palette row.

Shape language (designed-fx.md, ice): straight lines, four-point glints, no crystals.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vfxlib import HOT, LIGHT, Frame, pack, preview, save, star  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "vfx", "designed")


def glint(f, x, y, r, tone=HOT, ink=1.5, rot=0.0, thin=0.3):
    """A four-point sparkle."""
    f.poly(star(x, y, [r, r * thin, r, r * thin], r * 0.1, rot=rot, bow=0.5), tone, ink=ink)


# --- rink_glint: a glint on the frozen pool ------------------------------------------------------------------------
# Frame 0 a pinched hot needle (the light catching), 1 the peak: a tall four-point glint with a small diagonal one
# off its shoulder, 2 shrinking, 3 a speck. Played small (0.5 m) and often while the pool is frozen.

def rink_glint(i, n, size):
    f = Frame(size)
    c = f.c
    r = [0.42, 0.92, 0.6, 0.26][i]
    thin = [0.3, 0.58, 0.5, 0.55][i]
    glint(f, c, c, f.u(r), HOT if i < 2 else LIGHT, ink=2.0 if i < 3 else 1.5, rot=-math.pi / 2, thin=thin)
    if i in (1, 2):
        k = 0.42 if i == 1 else 0.28
        glint(f, c + f.u(0.42), c - f.u(0.38), f.u(k), LIGHT, ink=1.5, rot=math.pi / 4, thin=0.34)
    return f.finish()


SHEETS = {
    # name: (fn, frame px, cols, frames, preview palette, erode mode, noise weight)
    "rink_glint": (rink_glint, 128, 2, 4, "water", "center", 0.3),
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
