"""Effect coverage per HIT frame of a string_film run (round 33, sleek 5 / 6).

    python tests/fx_coverage.py <film_dir> [--all] [--per-string] [--max=0.40]

<film_dir> is the folder string_film.gd wrote (user://string_film, or user://<name> with -- --dir=<name>;
on Windows %APPDATA%/Godot/app_userdata/Awaken/<name>), one sub-folder per string with NNN.png + INDEX.txt.

Coverage = the share of the middle 60% of a frame (x and y 20-80%) that is effect-coloured: saturated and bright
(HSV S > 0.5 and V > 0.5) and not the dummies' red (hue 340-12 deg). The indigo floor, the cream dummies and ink are
not counted. Impact frames (the cream negative: mean V > 0.62 and mean S < 0.25) are skipped. Each HIT line of an
INDEX is scored as the max over that frame and the next two (effects peak just after contact).

Run to run a number moves by about 0.05 (bot timing, when he Awakens): compare one string at a time and back
every number with a crop. With --max=X it exits 1 if any HIT frame is over X (the sleek budget: 0.40) and names
them, so a lane can gate a film on it. Needs numpy and Pillow; not part of agent.sh check (it needs a windowed film).
"""
import os
import sys

import numpy as np
from PIL import Image

MIDDLE = (0.2, 0.8)


def cover(path):
    im = np.asarray(Image.open(path).convert("HSV"), dtype=np.float32) / 255.0
    h, w = im.shape[:2]
    m = im[int(h * MIDDLE[0]):int(h * MIDDLE[1]), int(w * MIDDLE[0]):int(w * MIDDLE[1])]
    hue, s, v = m[..., 0] * 360.0, m[..., 1], m[..., 2]
    if v.mean() > 0.62 and s.mean() < 0.25:
        return None
    eff = (s > 0.5) & (v > 0.5) & ~((hue > 340) | (hue < 12))
    return float(eff.mean())


def hits(root):
    rows = []
    for film in sorted(os.listdir(root)):
        d = os.path.join(root, film)
        idx = os.path.join(d, "INDEX.txt")
        if not os.path.isfile(idx):
            continue
        lines = open(idx).read().splitlines()[1:]
        n = len(lines)
        for i, ln in enumerate(lines):
            if " HIT " not in ln:
                continue
            move = ln.split("move=")[1].split()[0] if "move=" in ln else "?"
            best, at = -1.0, i
            for j in range(i, min(i + 3, n)):
                p = os.path.join(d, "%03d.png" % j)
                if not os.path.isfile(p):
                    continue
                c = cover(p)
                if c is not None and c > best:
                    best, at = c, j
            rows.append((best, film, i, at, move))
    return rows


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    root = argv[1]
    limit = None
    for a in argv[2:]:
        if a.startswith("--max="):
            limit = float(a.split("=", 1)[1])
    rows = hits(root)
    rows.sort(reverse=True)
    for r in (rows if "--all" in argv else rows[:12]):
        print("%.3f  %-22s HIT %03d (peak %03d) move=%s" % r)
    vals = [r[0] for r in rows if r[0] >= 0]
    if not vals:
        print("no HIT frames under %s" % root)
        return 2
    if "--per-string" in argv:
        by = {}
        for r in rows:
            if r[0] >= 0:
                by.setdefault(r[1], []).append(r[0])
        for film in sorted(by):
            print("  %-22s max %.3f mean %.3f (%d HIT)" % (film, max(by[film]), np.mean(by[film]), len(by[film])))
    print("HIT frames %d, mean %.3f, median %.3f, max %.3f" % (len(vals), np.mean(vals), np.median(vals), max(vals)))
    if limit is not None:
        over = [r for r in rows if r[0] > limit]
        for r in over:
            print("FAIL: %.3f > %.2f  %s HIT %03d (peak %03d) move=%s" % (r[0], limit, r[1], r[2], r[3], r[4]))
        print("FAIL" if over else "PASS", "(budget %.2f per HIT frame)" % limit)
        return 1 if over else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
