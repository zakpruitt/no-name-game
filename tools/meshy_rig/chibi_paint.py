# Repaints the chibi's tentacle hand in the heretic's magenta, so it matches the weapons that grow
# out of it (ComicLook.KIND_TONES["heretic"] P_Tendril) and reads on the indigo floor. Meshy's
# retexture painted it a dark wine (hue ~.90, value ~.43). Only texels under the hand's own UV
# triangles change: a triangle is the hand's when its vertices are mostly weighted to tent.*,
# hand.r or wrist.r. Writes a PNG for heretic_refine.py; the blend is not changed.
#   blender -b <rig.blend> -P chibi_paint.py -- <out.png> [hue] [value_gain]
import bpy, sys, colorsys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
HUE = float(args[1]) if len(args) > 1 else 0.85     # the old limb's magenta
GAIN = float(args[2]) if len(args) > 2 else 1.45
HAND = ("tent.", "hand.r", "wrist.r")

ob = bpy.data.objects["heretic"]
me = ob.data
img = bpy.data.images[0]
W, H = img.size
px = np.array(img.pixels[:], np.float32).reshape(H, W, img.channels)

gi = {g.index: g.name for g in ob.vertex_groups}
hw = np.zeros(len(me.vertices))
for v in me.vertices:
    hw[v.index] = sum(g.weight for g in v.groups if gi[g.group].startswith(HAND))
uv = me.uv_layers[0].data
me.calc_loop_triangles()
mask = np.zeros((H, W), bool)
n = 0
for t in me.loop_triangles:
    if hw[list(t.vertices)].mean() < 0.5:
        continue
    n += 1
    p = np.array([[uv[l].uv[0] * W, uv[l].uv[1] * H] for l in t.loops])
    x0, y0 = np.floor(p.min(0)).astype(int) - 2
    x1, y1 = np.ceil(p.max(0)).astype(int) + 2
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, W - 1), min(y1, H - 1)
    if x1 < x0 or y1 < y0:
        continue
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
    (ax, ay), (bx, by), (cx, cy) = p
    d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(d) < 1e-9:
        continue
    l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / d
    l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / d
    l3 = 1 - l1 - l2
    pad = 2.0 / max(abs(d) ** .5, 1)   # a texel or two past the edge, against seams
    inside = (l1 > -pad) & (l2 > -pad) & (l3 > -pad)
    mask[y0:y1 + 1, x0:x1 + 1] |= inside
print("hand triangles", n, "texels", int(mask.sum()))

rgb = px[..., :3]
ys, xs = np.nonzero(mask)
c = rgb[ys, xs]
hsv = np.array([colorsys.rgb_to_hsv(*q) for q in c])
# the wine paint only: leave the dark claw tips and any stray pale texels alone
wine = ((hsv[:, 0] > .78) | (hsv[:, 0] < .02)) & (hsv[:, 1] > .3)
print("wine texels", int(wine.sum()), "median hsv", np.median(hsv[wine], 0).round(3))
out = c.copy()
for i in np.nonzero(wine)[0]:
    h, s, v = hsv[i]
    out[i] = colorsys.hsv_to_rgb(HUE, min(s, .85), min(v * GAIN, 1.0))
rgb[ys, xs] = out
px[..., :3] = rgb
img.pixels.foreach_set(px.ravel())
img.filepath_raw = OUT
img.file_format = "PNG"
img.save()
print("SAVED", OUT)
