# Hides the chibi's face in the hood's shadow: skin texels (chin, nose, cheeks) under the hood
# go to a dark indigo so only the black mask and the eyes are left, and the eye texels go to a
# bright cyan. Only texels under head triangles inside the hood opening change (a box measured on
# chibi_rig_v1.blend, metres, Blender axes, front = -y). Writes a PNG for heretic_refine.py.
# From the game camera the face is under the hood anyway: the glow that reads from there is
# heretic_rig.gd's eye decal (EYES); this is for close cameras and the front.
#   blender -b <rig.blend> -P chibi_face.py -- <in.png> <out.png>
import bpy, sys, colorsys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
BOX = ((-0.2, 0.28), (-0.05, 0.3), (0.92, 1.3))   # x, y, z: the face inside the hood opening
SHADOW = (0.045, 0.035, 0.085)
EYE = (0.35, 1.0, 0.95)

ob = bpy.data.objects["heretic"]
me = ob.data
MW = np.array(ob.matrix_world)
n = len(me.vertices)
lco = np.zeros(n * 3); me.vertices.foreach_get("co", lco)
co = lco.reshape(n, 3) @ MW[:3, :3].T + MW[:3, 3]
gi = {g.index: g.name for g in ob.vertex_groups}
hw = np.zeros(n)
for v in me.vertices:
    hw[v.index] = sum(g.weight for g in v.groups if gi[g.group] in ("head", "neck"))

src = bpy.data.images.load(SRC)
W, H = src.size
px = np.array(src.pixels[:], np.float32).reshape(H, W, src.channels)
uv = me.uv_layers[0].data
me.calc_loop_triangles()
mask = np.zeros((H, W), bool)
tris = 0
for t in me.loop_triangles:
    vs = list(t.vertices)
    c = co[vs].mean(0)
    if hw[vs].mean() < 0.5 or not all(lo <= c[k] <= hi for k, (lo, hi) in enumerate(BOX)):
        continue
    tris += 1
    p = np.array([[uv[l].uv[0] * W, uv[l].uv[1] * H] for l in t.loops])
    x0, y0 = np.maximum(np.floor(p.min(0)).astype(int) - 2, 0)
    x1, y1 = np.minimum(np.ceil(p.max(0)).astype(int) + 2, [W - 1, H - 1])
    if x1 < x0 or y1 < y0:
        continue
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
    (ax, ay), (bx, by), (cx, cy) = p
    d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(d) < 1e-9:
        continue
    l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / d
    l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / d
    pad = 2.0 / max(abs(d) ** .5, 1)
    mask[y0:y1 + 1, x0:x1 + 1] |= (l1 > -pad) & (l2 > -pad) & (1 - l1 - l2 > -pad)
ys, xs = np.nonzero(mask)
rgb = px[ys, xs, :3]
hsv = np.array([colorsys.rgb_to_hsv(*q) for q in rgb])
# skin is peach (hue .04-.06, saturation .25-.3); the hood's bone white is hue .1, saturation under .2
skin = (hsv[:, 0] > 0.02) & (hsv[:, 0] < 0.075) & (hsv[:, 1] > 0.21) & (hsv[:, 1] < 0.45) & (hsv[:, 2] > 0.7)
eye = (hsv[:, 0] > 0.4) & (hsv[:, 0] < 0.56) & (hsv[:, 1] > 0.3) & (hsv[:, 2] > 0.2)
if "--hist" in sys.argv:
    cand = (hsv[:, 2] > 0.45) & (hsv[:, 1] > 0.05) & ((hsv[:, 0] < 0.15) | (hsv[:, 0] > 0.9))
    hb = np.round(hsv[cand, 0] * 50) / 50; sb = np.round(hsv[cand, 1] * 20) / 20; vb = np.round(hsv[cand, 2] * 10) / 10
    from collections import Counter
    for k, m in Counter(zip(hb, sb, vb)).most_common(30): print("hsv", k, m)
print("face triangles", tris, "texels", len(ys), "skin", int(skin.sum()), "eye", int(eye.sum()))
rgb[skin] = SHADOW
# keep the eye's own light-to-dark so the iris still has a shape, just much brighter
rgb[eye] = np.array(EYE) * (0.55 + 0.45 * np.clip(hsv[eye, 2:3] / max(hsv[eye, 2].max(), 1e-6), 0, 1))
px[ys, xs, :3] = rgb
out = bpy.data.images.new("face_out", W, H)
out.pixels.foreach_set(px.ravel() if src.channels == 4 else np.dstack([px, np.ones((H, W, 1), np.float32)]).ravel())
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
print("SAVED", OUT)
