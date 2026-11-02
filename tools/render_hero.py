"""Windowless hero preview, part 2: rasterize tests/hero_dump.gd's triangles.

Flat-shaded orthographic views (front, three-quarter, side, back; "top" =
the game camera's angle on request) with the
shaman texture sampled at each triangle's UV centre. Rough, but enough to check
where model edits sit without opening a Godot window.

    python tools/render_hero.py [dump.json] [out.png] [front,3/4,...]

Defaults: %APPDATA%/Godot/app_userdata/Awaken/hero_dump.json -> hero_render.png
next to it.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USER = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Awaken")
TEXTURE = os.path.join(ROOT, "assets", "hero", "shaman_texture.png")
VIEWS = [("front", 0.0, 12.0), ("3/4", 40.0, 12.0), ("side", 90.0, 12.0), ("back", 180.0, 12.0), ("top", 0.0, 55.0)]
SIZE = 420
SCALE = 125.0  # pixels per metre
LIGHT = np.array([0.4, 0.75, 0.55])
LIGHT /= np.linalg.norm(LIGHT)
BG = (46, 42, 54)


def render(tris, tex, yaw_deg, pitch_deg=12.0, scale=SCALE, center_y=0.88, fit=False):
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    # Camera orbits the model: rotate the world by -yaw about Y, then tilt.
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    rot_y = np.array([[cy, 0, -sy], [0, 1, 0], [sy, 0, cy]])
    rot_x = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    rot = rot_x @ rot_y
    off_x, off_y = SIZE / 2, SIZE * center_y
    if fit:  # scale and centre so everything fills the frame with a margin
        pts = np.array([v for t in tris for v in t["p"]], np.float32) @ rot.T
        lo, hi = pts[:, :2].min(0), pts[:, :2].max(0)
        scale = 0.9 * SIZE / max(float((hi - lo).max()), 1e-3)
        mid = (lo + hi) / 2
        off_x, off_y = SIZE / 2 - mid[0] * scale, SIZE / 2 + mid[1] * scale
    img = np.zeros((SIZE, SIZE, 3), np.float32) + np.array(BG, np.float32) / 255.0
    zbuf = np.full((SIZE, SIZE), -1e9, np.float32)
    th, tw = tex.shape[:2]
    # Opaque first, then see-through triangles back to front, blended by alpha.
    def depth(t):
        return float((np.array(t["p"], np.float32) @ rot.T)[:, 2].mean())
    opaque = [t for t in tris if len(t["c"]) < 4 or t["c"][3] >= 0.99]
    clear = sorted((t for t in tris if len(t["c"]) == 4 and t["c"][3] < 0.99), key=depth)
    for t in opaque + clear:
        p = np.array(t["p"], np.float32) @ rot.T
        n = np.cross(p[1] - p[0], p[2] - p[0])
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            continue
        n /= ln
        # Screen: x right, y up (model y ~0..2.6 centred), z toward the camera.
        sx = off_x + p[:, 0] * scale
        syy = off_y - p[:, 1] * scale
        z = p[:, 2]
        x0, x1 = int(max(0, math.floor(sx.min()))), int(min(SIZE - 1, math.ceil(sx.max())))
        y0, y1 = int(max(0, math.floor(syy.min()))), int(min(SIZE - 1, math.ceil(syy.max())))
        if x0 > x1 or y0 > y1:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (syy[1] - syy[2]) * (sx[0] - sx[2]) + (sx[2] - sx[1]) * (syy[0] - syy[2])
        if abs(d) < 1e-9:
            continue
        w0 = ((syy[1] - syy[2]) * (xs - sx[2]) + (sx[2] - sx[1]) * (ys - syy[2])) / d
        w1 = ((syy[2] - syy[0]) * (xs - sx[2]) + (sx[0] - sx[2]) * (ys - syy[2])) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        if not inside.any():
            continue
        zz = w0 * z[0] + w1 * z[1] + w2 * z[2]
        sub = zbuf[y0:y1 + 1, x0:x1 + 1]
        hit = inside & (zz > sub)
        if not hit.any():
            continue
        col = np.array(t["c"][:3], np.float32)
        alpha = t["c"][3] if len(t["c"]) == 4 else 1.0
        if t["tex"]:
            u, v = t["uv"]
            col = col * tex[min(th - 1, max(0, int(v * th))), min(tw - 1, max(0, int(u * tw)))]
        if t["glow"]:
            shade = 1.0
        else:
            facing = n if n[2] >= 0 else -n  # double-sided
            shade = 0.45 + 0.55 * max(0.0, float(facing @ LIGHT))
        region = img[y0:y1 + 1, x0:x1 + 1]
        if alpha < 0.99:
            region[hit] = region[hit] * (1 - alpha) + np.clip(col * shade, 0, 1) * alpha
        else:
            sub[hit] = zz[hit]
            region[hit] = np.clip(col * shade, 0, 1)
    return (img * 255).astype(np.uint8)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(USER, "hero_dump.json")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(src), "hero_render.png")
    data = json.load(open(src, encoding="utf-8"))
    tex = np.asarray(Image.open(TEXTURE).convert("RGB"), np.float32) / 255.0
    want = sys.argv[3].split(",") if len(sys.argv) > 3 else [v[0] for v in VIEWS if v[0] != "top"]
    views = [v for v in VIEWS if v[0] in want]
    sheet = Image.new("RGB", (SIZE * len(views), SIZE), BG)
    for i, (_, yaw, pitch) in enumerate(views):
        sheet.paste(Image.fromarray(render(data["tris"], tex, yaw, pitch, data.get("scale", SCALE), data.get("cy", 0.88), data.get("fit", False))), (i * SIZE, 0))
    sheet.save(out)
    print("saved", out, "views:", ", ".join(v[0] for v in views), "ascend:", data.get("ascend") or "-")


if __name__ == "__main__":
    main()
