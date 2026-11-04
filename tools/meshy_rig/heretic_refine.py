# Refines a rig blend without touching the rig: swaps in a flattened texture (flatten_texture.py)
# and thickens the tentacle limb so it reads at game distance. Bones and weights are unchanged,
# so heretic_bake.py runs on the result exactly as on the original.
#   blender -b <rig.blend> -P heretic_refine.py -- dump <uvtris.npy>
#   blender -b <rig.blend> -P heretic_refine.py -- <flat.png> <out.blend> [thicken_m] [head_scale] [hand_scale] [claw_scale]
# head_scale / hand_scale push him towards the art direction (docs/features/art-direction.md):
# a bigger head and fist, grown about the neck and the wrist, blended by skin weight.
# claw_scale grows the tentacle hand (hand.r and every tent.* claw) about the right wrist, and
# moves those bones with it so the claws still bend at their own joints (the chibi's signature limb).
import bpy, sys, os
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
ob = bpy.data.objects["heretic"]
me = ob.data

if args[0] == "dump":   # the UV triangles flatten_texture.py needs to find islands
    uv = me.uv_layers[0].data
    me.calc_loop_triangles()
    np.save(args[1], np.array([[list(uv[l].uv) for l in t.loops] for t in me.loop_triangles], np.float32))
    print("DUMPED", len(me.loop_triangles), "tris")
    sys.exit(0)

FLAT, OUT = args[0], args[1]
THICKEN = float(args[2]) if len(args) > 2 else 0.015
HEAD_SCALE = float(args[3]) if len(args) > 3 else 1.0
HAND_SCALE = float(args[4]) if len(args) > 4 else 1.0
CLAW_SCALE = float(args[5]) if len(args) > 5 else 1.0
CLAW = ("hand.r", "tent.")
# (bone prefixes whose summed weight grows a vertex, bone whose head is the centre)
GROW = [(("head", "neck"), "head", HEAD_SCALE), (("hand.l", "finger."), "hand.l", HAND_SCALE),
        (CLAW, "wrist.r", CLAW_SCALE)]
# bones whose weight pushes a vertex out: the whole limb, hand.r and the tips
LIMB = ("upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "tent.")
ROOT_FADE = 0.10   # metres from the shoulder over which the push fades in, so the join stays

# ---- texture: same image datablock, new pixels, so the material and the GLB export are unchanged
img = bpy.data.images[0]
new = bpy.data.images.load(FLAT)
assert tuple(new.size) == tuple(img.size), (new.size[:], img.size[:])
img.pixels.foreach_set(np.array(new.pixels[:], np.float32))
img.update()
img.pack()
bpy.data.images.remove(new)
print("texture replaced", img.name, img.size[:])

# ---- thicken: push along the normal averaged over each position, so seams don't open
n = len(me.vertices)
# work in world space: the FBX import leaves a scale on the object
MW = np.array(ob.matrix_world); arm = bpy.data.objects["HereticRig"]
lco = np.zeros(n * 3); me.vertices.foreach_get("co", lco); lco = lco.reshape(n, 3)
co = lco @ MW[:3, :3].T + MW[:3, 3]
nr = np.zeros(n * 3); me.vertices.foreach_get("normal", nr); nr = nr.reshape(n, 3)
nr = nr @ np.linalg.inv(MW[:3, :3])  # normals take the inverse transpose
nr /= np.maximum(np.linalg.norm(nr, axis=1, keepdims=True), 1e-9)
gi = {g.index: g.name for g in ob.vertex_groups}
w = np.zeros(n)
for v in me.vertices:
    for g in v.groups:
        if gi[g.group].startswith(LIMB):
            w[v.index] += g.weight
key = {}
for i, c in enumerate(np.round(co, 4)):
    key.setdefault(tuple(c), []).append(i)
for ids in key.values():
    if len(ids) > 1:
        m = nr[ids].sum(0); m /= max(np.linalg.norm(m), 1e-6)
        nr[ids] = m
        w[ids] = w[ids].mean()
sh = arm.matrix_world @ arm.data.bones["upperarm.r"].head_local
d0 = np.linalg.norm(co - np.array(sh), axis=1)
w *= np.clip(d0 / ROOT_FADE, 0, 1)
co += nr * (w * THICKEN)[:, None]
for pre, centre, k in GROW:
    if k == 1.0:
        continue
    wg = np.zeros(n)
    for v in me.vertices:
        for g in v.groups:
            if gi[g.group].startswith(pre):
                wg[v.index] += g.weight
    if pre[0] == "head":   # the neck bone is shared with the collar: only its upper part grows
        wg = np.clip(wg, 0, 1)
    for ids in key.values():
        if len(ids) > 1:
            wg[ids] = wg[ids].mean()
    c = np.array(arm.matrix_world @ arm.data.bones[centre].head_local)
    co = c + (co - c) * (1 + (k - 1) * wg)[:, None]
    print("grew %s by %.2f round %s (%d verts)" % (pre, k, centre, int((wg > 0.01).sum())))
lco = (co - MW[:3, 3]) @ np.linalg.inv(MW[:3, :3]).T
me.vertices.foreach_set("co", lco.ravel())
me.update()
print("thickened %d verts by up to %.3f m" % (int((w > 0.01).sum()), THICKEN))
if CLAW_SCALE != 1.0:   # the claws' joints follow their mesh; hand.r keeps its head on the wrist
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    c = eb["wrist.r"].head.copy()
    moved = [b for b in eb if b.name.startswith(CLAW)]
    old = {b.name: (b.head.copy(), b.tail.copy()) for b in moved}
    for b in moved:
        h, t = old[b.name]
        if b.name != "hand.r":
            b.head = c + (h - c) * CLAW_SCALE
        b.tail = c + (t - c) * CLAW_SCALE
    bpy.ops.object.mode_set(mode="OBJECT")
    print("claw bones moved", len(moved))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SAVED", OUT)
