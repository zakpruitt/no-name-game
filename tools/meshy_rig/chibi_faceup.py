# Turns the chibi heretic's face up to the game camera (round 40, hero pass 3). From 54 degrees down the
# camera saw only the top of his hood: the face opening pointed at the horizon, under the brim. Two edits
# on the scarf blend, vertices only (bones, weights, UVs, clips kept, so contact frames print the same):
# - the tip: every vertex rotates about the neck joint (the head bone's head) by TIP degrees x its head
#   weight, chin up and the peak back, in the bind pose, so every clip shows the face tipped towards the
#   camera; heretic_rig.gd moves its EYES / GRIN / FACE_SHADE decals through the same map (FACE_TIP);
# - the cut: the hood's front rim round the face opening is pushed out from the face's middle and back,
#   CUT m at the rim fading to nothing CUT_FADE m out, so the opening is wider and the dark face shows.
# Armature space = mesh space here (the mesh is parented to the Armature with no offset).
#   blender -b <chibi_scarf.blend> -P chibi_faceup.py -- <out.blend> [tip_deg] [cut_m] [cut_fade_m]
#   round 40, pass 3: 28 0.05 0.12
import bpy, sys, math
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
TIP = float(args[1]) if len(args) > 1 else 28.0
CUT = float(args[2]) if len(args) > 2 else 0.05
CUT_FADE = float(args[3]) if len(args) > 3 else 0.12
PIVOT_UP = float(args[4]) if len(args) > 4 else 0.0  # m above the neck joint the head turns about
# the face's middle before the tip, armature space (Blender axes: -y is his front): heretic_rig.gd's
# FACE_SHADE spot moved through chibi_presence's head growth
FACE = np.array([0.062, -0.09, 1.2])
HEAD_GROW = 1.2
CUT_R = (0.14, 0.12)  # m: the opening's half width and half height at the rim, after the growth

arm = bpy.data.objects["Armature"]
ob = bpy.data.objects["heretic"]
assert ob.parent == arm and np.allclose(np.array(ob.matrix_parent_inverse), np.eye(4)), "mesh not on the armature"
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


w_h = np.clip(welded(Wt[:, names.index("head")]), 0, 1)
neck = np.array(arm.data.bones["head"].head_local)
face0 = neck + (FACE - neck) * HEAD_GROW
grow0 = neck.copy()
co0 = co.copy()
# the body carries custom split normals: read them now, turn them with the tip, set them after
nl = len(me.loops)
ln = np.zeros(nl * 3); me.corner_normals.foreach_get("vector", ln) if hasattr(me, "corner_normals") else None
ln = ln.reshape(nl, 3)
lv = np.zeros(nl, int); me.loops.foreach_get("vertex_index", lv)

# ---- the cut, before the tip (the opening's frame is the rest face): rim vertices in front of the face
# and round its middle move out radially in the face plane and back into the hood
w_hood = welded(Wt[:, [i for i, nm in enumerate(names) if nm in ("head", "neck")]].sum(1))
d = co - face0
ex = d[:, 0] / CUT_R[0]
ez = d[:, 2] / CUT_R[1]
r = np.sqrt(ex ** 2 + ez ** 2)
front = (d[:, 1] < 0.06) & (w_hood > 0.5)
fade = np.clip(1.0 - np.abs(r - 1.0) * CUT_R[0] / CUT_FADE, 0, 1) * front
radial = np.stack([ex, np.zeros(n), ez], 1) / np.maximum(r, 1e-6)[:, None]
radial[:, 0] *= CUT_R[0]; radial[:, 2] *= CUT_R[1]
radial /= np.maximum(np.linalg.norm(radial, axis=1), 1e-6)[:, None]
co = co + (radial * CUT + np.array([0, CUT * 0.6, 0])) * fade[:, None]
print("cut: %d verts round the face opening, %.3f m out" % (int((fade > 0.05).sum()), CUT))

# ---- the tip about a point PIVOT_UP over the neck joint, by head weight
neck = neck + np.array([0, 0, PIVOT_UP])
a = -math.radians(TIP) * w_h
c, s = np.cos(a), np.sin(a)
d = co - neck
co = neck + np.stack([d[:, 0], d[:, 1] * c - d[:, 2] * s, d[:, 1] * s + d[:, 2] * c], 1)
eye = grow0 + (np.array([0.06, -0.13, 1.25]) - grow0) * HEAD_GROW
ae = -math.radians(TIP)
de = eye - neck
eye1 = neck + np.array([de[0], de[1] * math.cos(ae) - de[2] * math.sin(ae), de[1] * math.sin(ae) + de[2] * math.cos(ae)])
print("tip: %.0f deg about the neck %s, eyes %s -> %s" % (TIP, np.round(neck, 3), np.round(eye, 3), np.round(eye1, 3)))

al = a[lv]
ln = np.stack([ln[:, 0], ln[:, 1] * np.cos(al) - ln[:, 2] * np.sin(al), ln[:, 1] * np.sin(al) + ln[:, 2] * np.cos(al)], 1)

dm = np.zeros((nw, 3)); cnt = np.zeros(nw)
np.add.at(dm, wid, co - co0); np.add.at(cnt, wid, 1)
co = co0 + (dm / cnt[:, None])[wid]
me.vertices.foreach_set("co", co.ravel())
me.normals_split_custom_set([tuple(v) for v in ln])
me.update()
print("height %.3f" % ((co[:, 2].max() - co[:, 2].min()) * arm.matrix_world.to_scale().x))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("FACEUP", OUT)
