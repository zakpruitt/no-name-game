# The chibi heretic's hood peak as a hooked point (round 40, hero pass 3). From the game camera the hood read
# as a dome: its peak, even sheared back (chibi_shape), stayed inside the egg's outline. Vertices only, on the
# face-up blend (bones, weights, UVs, clips kept):
# - the peak, from FROM of the hood's height up, sheared back BACK m and up UP m (x t^2), then its last third
#   bent over sideways to his left SIDE m (x u, KINK) like a floppy hat tip, so from 54 degrees up the point
#   pokes out past the outline and hooks, leaving the dome at a hard corner;
# - a notch on the outside of the bend: a short band of the hood under the bend pulled in NOTCH m towards the
#   hood's middle, so the silhouette has one hard corner where the hook leaves the dome.
# Custom split normals are carried (only the bend turns them; they are rotated by the local bend angle).
#   blender -b <faceup.blend> -P chibi_hook.py -- <out.blend> [back_m] [up_m] [side_m] [notch_m] [from]
#   round 40, pass 3: 0.1 0.1 0.16 0.04 0.55
import bpy, sys, math
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
BACK = float(args[1]) if len(args) > 1 else 0.1
UP = float(args[2]) if len(args) > 2 else 0.1
SIDE = float(args[3]) if len(args) > 3 else 0.16
NOTCH = float(args[4]) if len(args) > 4 else 0.04
FROM = float(args[5]) if len(args) > 5 else 0.55
BEND = 0.62   # of the peak's t where the sideways bend starts
NOTCH_AT = (0.52, 0.7)  # of t: the band pulled in at the bend, on the side it bends to (his left, +x)
KINK = 1.0  # the bend's power: 1 leaves the dome at an angle, a hard corner in the outline (2 was a smooth curve)
LEFT = np.array([1.0, 0.0, 0.0])  # Blender: he faces -y, his left is +x

arm = bpy.data.objects["Armature"]
ob = bpy.data.objects["heretic"]
me = ob.data
n = len(me.vertices)
co = np.zeros(n * 3); me.vertices.foreach_get("co", co); co = co.reshape(n, 3)
names = [g.name for g in ob.vertex_groups]
Wt = np.zeros((n, len(names)), np.float32)
for v in me.vertices:
    for g in v.groups:
        Wt[v.index, g.group] = g.weight
key = {}
wid = np.array([key.setdefault(tuple(p), len(key)) for p in np.round(co, 4)])
nw = len(key)


def welded(w):
    s = np.zeros(nw); c = np.zeros(nw)
    np.add.at(s, wid, w); np.add.at(c, wid, 1)
    return (s / c)[wid]


w_head = welded(Wt[:, [i for i, nm in enumerate(names) if nm in ("head", "neck")]].sum(1))
neck = np.array(arm.data.bones["head"].head_local)
hood = (w_head > 0.5) & (co[:, 2] > neck[2] + 0.25)
top = co[hood, 2].max()
base = co[hood, 2].min()
z0 = base + (top - base) * FROM
t = np.clip((co[:, 2] - z0) / (top - z0), 0, 1) * hood
co0 = co.copy()
# the hood's middle per 2 cm slice, before the edit (for the notch)
bins = np.round(co[:, 2] / 0.02).astype(int)
mid = np.zeros((n, 3))
for b in np.unique(bins[hood]):
    m = hood & (bins == b)
    mid[m] = co[m].mean(0)

# the notch first, in the dome's own frame
nt = np.clip(1.0 - np.abs(t - sum(NOTCH_AT) / 2) / ((NOTCH_AT[1] - NOTCH_AT[0]) / 2), 0, 1)
side = co[:, 0] - mid[:, 0]
outside = np.clip(side / 0.06, 0, 1) * hood
pull = NOTCH * nt * outside
d = co - mid
d[:, 2] = 0
dn = d / np.maximum(np.linalg.norm(d, axis=1), 1e-6)[:, None]
co = co - dn * pull[:, None]

# shear back and up
co[:, 1] += BACK * t ** 2
co[:, 2] += UP * t ** 2
# the bend sideways over the last part
u = np.clip((t - BEND) / (1 - BEND), 0, 1)
co += LEFT[None, :] * (SIDE * u ** KINK)[:, None]
co[:, 2] -= SIDE * 0.35 * u ** 3  # the tip droops a little as it bends over

# normals: turn each corner's normal by the bend's local angle about the forward axis (y)
nl = len(me.loops)
ln = np.zeros(nl * 3); me.corner_normals.foreach_get("vector", ln); ln = ln.reshape(nl, 3)
lv = np.zeros(nl, int); me.loops.foreach_get("vertex_index", lv)
ang = -np.arctan(KINK * SIDE * u ** (KINK - 1) * (u > 0) / max(top - z0, 1e-6) / max(1 - BEND, 1e-6))[lv]  # d(x)/d(z)
c, s = np.cos(ang), np.sin(ang)
ln = np.stack([ln[:, 0] * c - ln[:, 2] * s, ln[:, 1], ln[:, 0] * s + ln[:, 2] * c], 1)

dm = np.zeros((nw, 3)); cnt = np.zeros(nw)
np.add.at(dm, wid, co - co0); np.add.at(cnt, wid, 1)
co = co0 + (dm / cnt[:, None])[wid]
me.vertices.foreach_set("co", co.ravel())
me.normals_split_custom_set([tuple(v) for v in ln])
me.update()
print("hook: %d hood verts above %.3f m, tip %s -> %s, notch %d verts" % (
    int((t > 0).sum()), z0, np.round(co0[hood][co0[hood, 2].argmax()], 3), np.round(co[hood][co0[hood, 2].argmax()], 3), int((pull > 0.005).sum())))
print("height %.3f" % ((co[:, 2].max() - co[:, 2].min()) * arm.matrix_world.to_scale().x))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("HOOK", OUT)
