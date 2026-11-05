# Gives the chibi heretic the presence of the warrior-class foes (round 40, hero pass 2): he is the
# player's avatar and must be the boldest silhouette in a crowd. Four edits on the weapons blend:
# - the head: hood, brim and face grow about the neck joint (the head bone's head) by head weight;
#   heretic_rig.gd moves its EYES / GRIN decals through the same map (HEAD_GROW);
# - the hood: from the brow up it widens about its own axis (each 2 cm slice about its own middle
#   near the tip, so chibi_shape's lean-back stays) and the peak stretches up;
# - the claw: every vertex on hand.r / tent.* grows about the wrist (hand.r's head) by its weight, and
#   the tent.* bones (heads and tails, plus hand.r's tail) move through the same map so the claws still
#   bend about their own joints. hand.r's head, the weapon.* bones and the weapons are untouched, so a
#   weapon still sits in the hand and chibi_keys.py's facings hold;
# - the body: the armature object is scaled to HEIGHT (the glTF Armature node carries it), so every
#   clip keeps its shape and contact frames exactly; chibi_keys.py reads the scale (WORLD_K) and
#   shortens its run strides by it, so his feet still match player.move_speed on the floor.
# Bone names, weights, UVs and IK targets are kept.
#   blender -b <weapons.blend> -P chibi_presence.py -- <out.blend> [hood_wide] [hood_tall_m] [claw] [height_m] [head] [brow_m]
#   round 40: 1.25 0.06 1.5 2.05 1.2 1.1
import bpy, sys
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
HOOD_WIDE = float(args[1]) if len(args) > 1 else 1.15   # across, at the top of the hood
HOOD_TALL = float(args[2]) if len(args) > 2 else 0.12   # m the tip rises (before the body scale)
CLAW = float(args[3]) if len(args) > 3 else 1.5         # claw size about the wrist
HEIGHT = float(args[4]) if len(args) > 4 else 0.0       # m: the body's height (hood tip) after the scale; 0 = no scale
BROW = float(args[6]) if len(args) > 6 else 1.3        # m (before the head growth): the widening fades in from here
HEAD = float(args[5]) if len(args) > 5 else 1.0         # head and hood about the neck joint (head bone's head), by weight
WIDE_FULL = 1.55      # m: full widening from here up (it fades in from the brow)
TALL_FROM = 1.5       # m: the stretch upwards starts here (the shear-back pivot is 1.548)

arm = bpy.data.objects["Armature"]
ob = bpy.data.objects["heretic"]
me = ob.data
MW = np.array(ob.matrix_world)
n = len(me.vertices)
lco = np.zeros(n * 3); me.vertices.foreach_get("co", lco)
co = lco.reshape(n, 3) @ MW[:3, :3].T + MW[:3, 3]
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


def group(pred):
    return welded(Wt[:, [i for i, nm in enumerate(names) if pred(nm)]].sum(1))


new = co.copy()
h0 = co[:, 2].max()
co0 = co.copy()

# ---- head: the whole hood, face and brim about the neck joint, by head weight (heretic_rig.gd's EYES and
# GRIN are this map of the round-40 spots: HEAD_GROW there)
w_head = group(lambda nm: nm in ("head", "neck"))
w_h = np.clip(group(lambda nm: nm == "head"), 0, 1)
neck = np.array(arm.matrix_world @ arm.data.bones["head"].head_local)
new = neck + (co - neck) * (1 + (HEAD - 1) * w_h)[:, None]
co = new.copy()
BROW = neck[2] + (BROW - neck[2]) * HEAD
WIDE_FULL = neck[2] + (WIDE_FULL - neck[2]) * HEAD
TALL_FROM = neck[2] + (TALL_FROM - neck[2]) * HEAD
print("head: x%.2f about the neck joint %s" % (HEAD, np.round(neck, 3)))

# ---- hood
hood = (w_head > 0.5) & (co[:, 2] > BROW)
axis = co[hood & (co[:, 2] < BROW + 0.1), :2].mean(0)   # the hood's middle just above the brow
top = co[hood, 2].max()
f = np.clip((co[:, 2] - BROW) / (WIDE_FULL - BROW), 0, 1) ** 1.5
k = 1 + (HOOD_WIDE - 1) * f
# the sheared tip leans back: widen each height about its own middle above the full height, so the lean stays
mid_xy = np.tile(axis, (n, 1))
bins = np.round(co[:, 2] / 0.02).astype(int)
for b in np.unique(bins[hood & (co[:, 2] > WIDE_FULL)]):
    m = hood & (bins == b)
    mid_xy[m] = co[m, :2].mean(0)
blend = np.clip((co[:, 2] - WIDE_FULL) / 0.1, 0, 1)[:, None]
centre = axis * (1 - blend) + mid_xy * blend
new[hood, :2] = centre[hood] + (co[hood, :2] - centre[hood]) * k[hood, None]
t = np.clip((co[:, 2] - TALL_FROM) / (top - TALL_FROM), 0, 1)
new[hood, 2] += HOOD_TALL * t[hood] ** 1.3
print("hood: %d verts, x%.2f wide at the top, tip +%.2f m (%.3f -> %.3f)" % (int(hood.sum()), HOOD_WIDE, HOOD_TALL, top, new[hood, 2].max()))

# ---- claw about the wrist
B = arm.data.bones
AW = arm.matrix_world
pivot = np.array(AW @ B["hand.r"].head_local)
w_claw = np.clip(group(lambda nm: nm == "hand.r" or nm.startswith("tent.")), 0, 1)
sel = w_claw > 0.01
s = 1 + (CLAW - 1) * w_claw
new[sel] = pivot + (new[sel] - pivot) * s[sel, None]
print("claw: %d verts x%.2f about the wrist" % (int(sel.sum()), CLAW))

dm = np.zeros((nw, 3)); cnt = np.zeros(nw)
np.add.at(dm, wid, new - co0); np.add.at(cnt, wid, 1)
new = co0 + (dm / cnt[:, None])[wid]
lco = (new - MW[:3, 3]) @ np.linalg.inv(MW[:3, :3]).T
me.vertices.foreach_set("co", lco.ravel())
me.update()

# the claw bones through the same map (edit mode, armature space = world: the object is unscaled here)
bpy.context.view_layer.objects.active = arm
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
P = Vector(B["hand.r"].head_local)
eb = arm.data.edit_bones
moved = 0
for e in eb:
    if e.name.startswith("tent."):
        e.head = P + (e.head - P) * CLAW
        e.tail = P + (e.tail - P) * CLAW
        moved += 1
eb["hand.r"].tail = P + (eb["hand.r"].tail - P) * CLAW
bpy.ops.object.mode_set(mode="OBJECT")
print("claw bones: %d moved x%.2f" % (moved, CLAW))

# ---- the body
h1 = new[:, 2].max() - new[:, 2].min()
if HEIGHT > 0:
    sc = HEIGHT / h1
    arm.scale = (sc, sc, sc)
    print("body: x%.4f (%.3f -> %.3f m)" % (sc, h1, HEIGHT))
print("height %.3f (was %.3f)" % (h1 * arm.scale[0], h0))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("PRESENCE", OUT)
