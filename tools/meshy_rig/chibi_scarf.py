# A trailing scarf tail for the chibi heretic (round 40, hero pass 2): a crimson ribbon that leaves the
# back of his scarf under the hood's hem and hangs down behind him, ending in a swallowtail notch, on its
# own chain of new bones (scarf.01 .. scarf.NN, parented to chest). heretic_rig.gd hangs the chain on a
# spring (SpringBoneSimulator3D, like the skirt) with a procedural flutter that grows with his speed, so
# it streams behind a run and snaps after a dash. The clips never key these bones. Every existing bone,
# weight, UV and the rest pose are kept; the ribbon is joined into the body mesh (same material,
# painted by pointing its UVs at flat scarf texels of the repainted texture).
#   blender -b <presence.blend> -P chibi_scarf.py -- <out.blend>
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
# The tail's centre line in armature space (Blender axes: -y is his front), from the back of the scarf
# (under the hood's hem, which reaches z 1.0 behind him) out over his left hip, down and back to his knees,
# so from above it trails past his outline instead of lying on the sash.
PATH = [Vector(p) for p in ((0.05, 0.14, 0.93), (0.1, 0.34, 0.86), (0.16, 0.54, 0.76),
                            (0.22, 0.72, 0.63), (0.28, 0.88, 0.5))]
BONES = 4             # scarf.01 .. scarf.04, one per PATH segment
WIDTH = (0.24, 0.17)  # m across, at the root and at the tip
THICK = 0.035         # m: thick enough that its ink hull reads as one ribbon
NOTCH = 0.11          # m: the swallowtail cut into the end
RINGS = 6             # cross-sections per bone
TONE = (0.84, 0.17, 0.2)       # chibi_repaint.TONES["scarf"]
TONE_END = (0.64, 0.09, 0.15)  # ["scarf_end"]: the last third

arm = bpy.data.objects["Armature"]
body = bpy.data.objects["heretic"]
if "scarf.01" in arm.data.bones:
    raise SystemExit("scarf already built")


# ---- flat texels of the two tones: the middle of a 9x9 block of exactly that colour
img = next(n.image for n in body.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
W, H = img.size
px = np.array(img.pixels[:], np.float32).reshape(H, W, img.channels)[..., :3]


def texel(tone):
    d = np.abs(px - np.array(tone, np.float32)).sum(-1) < 0.03
    k = 4
    ok = d.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            ok &= np.roll(d, (dy, dx), (0, 1))
    ys, xs = np.nonzero(ok)
    if len(ys) == 0:
        raise SystemExit("no flat texel for %s" % (tone,))
    i = len(ys) // 2
    return ((xs[i] + 0.5) / W, (ys[i] + 0.5) / H)


UV_BODY, UV_END = texel(TONE), texel(TONE_END)

# ---- bones
bpy.context.view_layer.objects.active = arm
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
parent = eb["chest"]
names = []
for i in range(BONES):
    b = eb.new("scarf.%02d" % (i + 1))
    b.head, b.tail = PATH[i], PATH[i + 1]
    b.roll = 0.0
    b.parent = parent
    b.use_connect = i > 0
    b.use_deform = True
    parent = b
    names.append(b.name)
bpy.ops.object.mode_set(mode="OBJECT")

# ---- the ribbon along PATH: a flat box section, wide across his back (x), its flat face to the camera
seg = [(PATH[i + 1] - PATH[i]).length for i in range(BONES)]
cum = np.concatenate([[0], np.cumsum(seg)])
L = cum[-1]
bm = bmesh.new()
uv = bm.loops.layers.uv.new(body.data.uv_layers[0].name)
dv = bm.verts.layers.deform.verify()
rings = []
n_r = BONES * RINGS
for r in range(n_r + 1):
    s = L * r / n_r
    j = min(int(np.searchsorted(cum, s, side="right") - 1), BONES - 1)
    t = (s - cum[j]) / seg[j]
    c = PATH[j].lerp(PATH[j + 1], t)
    tan = (PATH[j + 1] - PATH[j]).normalized()
    side = Vector((1, 0, 0))
    side = (side - tan * side.dot(tan)).normalized()
    nrm = tan.cross(side).normalized()
    w = WIDTH[0] + (WIDTH[1] - WIDTH[0]) * (s / L)
    # a slight twist and sideways drift so it hangs like cloth, not a plank
    side = (side * math.cos(0.35 * s / L) + nrm * math.sin(0.35 * s / L)).normalized()
    nrm = tan.cross(side).normalized()
    ring = []
    for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        ring.append(c + side * (a * w * 0.5) + nrm * (b * THICK * 0.5))
    # weights: half and half at each joint, all on the bone at its middle; the root blends into chest
    u = t
    wts = {}
    if u < 0.5:
        wts[names[j]] = 0.5 + u
        wts["chest" if j == 0 else names[j - 1]] = 0.5 - u
    else:
        wts[names[j]] = 1.5 - u if j + 1 < BONES else 1.0
        if j + 1 < BONES:
            wts[names[j + 1]] = u - 0.5
    rings.append((ring, wts, s / L, w))
# the swallowtail: the last ring's middle pulled back up the ribbon by NOTCH
verts = []
for k, (ring, wts, f, w) in enumerate(rings):
    vs = []
    for p in ring:
        vs.append(bm.verts.new(p))
    verts.append(vs)
groups = {}
for nm in names + ["chest"]:
    g = body.vertex_groups.get(nm) or body.vertex_groups.new(name=nm)
    groups[nm] = g.index
for vs, (ring, wts, f, w) in zip(verts, rings):
    for v in vs:
        for nm, x in wts.items():
            if x > 0:
                v[dv][groups[nm]] = x
faces = []
for k in range(len(verts) - 1):
    a, b = verts[k], verts[k + 1]
    for i in range(4):
        faces.append(bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i])))
# root cap
faces.append(bm.faces.new(list(reversed(verts[0]))))
# the end: two points of the swallowtail and a notch between them
last = verts[-1]
tan = (PATH[-1] - PATH[-2]).normalized()
mid_lo = bm.verts.new((last[0].co + last[1].co) * 0.5 - tan * NOTCH)
mid_hi = bm.verts.new((last[3].co + last[2].co) * 0.5 - tan * NOTCH)
for v in (mid_lo, mid_hi):
    for nm, x in rings[-1][1].items():
        v[dv][groups[nm]] = x
faces.append(bm.faces.new((last[0], mid_lo, mid_hi, last[3])))
faces.append(bm.faces.new((mid_lo, last[1], last[2], mid_hi)))
for fc in faces:
    zc = sum((v.co.z for v in fc.verts), 0.0) / len(fc.verts)
    end = zc < PATH[0].z - (PATH[0].z - PATH[-1].z) * 0.66
    for l in fc.loops:
        l[uv].uv = UV_END if end else UV_BODY
bmesh.ops.recalc_face_normals(bm, faces=faces)

# into the body mesh: its local space is the armature's (the body sits at identity under it)
M = body.matrix_world.inverted() @ arm.matrix_world
for v in bm.verts:
    v.co = M @ v.co
tmp = bpy.data.meshes.new("scarf_tail")
bm.to_mesh(tmp)
bm.free()
ob = bpy.data.objects.new("scarf_tail", tmp)
bpy.context.scene.collection.objects.link(ob)
ob.matrix_world = body.matrix_world
for g in body.vertex_groups:
    ob.vertex_groups.new(name=g.name)
tmp.materials.append(body.data.materials[0])
# bmesh wrote the body's group indices; the new object has the same groups in the same order
for o in bpy.context.selected_objects:
    o.select_set(False)
ob.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
n0 = len(body.data.vertices)
# the body carries custom split normals; joined faces would get none (black in the toon light, no ink
# hull), so keep the body's and give the ribbon its own smooth ones
keep = [tuple(c.vector) for c in body.data.corner_normals]
for p in tmp.polygons:
    p.use_smooth = True
tmp.update()
mine = [tuple(c.vector) for c in tmp.corner_normals]
bpy.ops.object.join()
body.data.normals_split_custom_set(keep + mine)
n1 = len(body.data.vertices)
body.data.calc_loop_triangles()
print("[scarf] %d bones, %d verts, %.2f m long, uv %s / %s" % (BONES, n1 - n0, L, UV_BODY, UV_END))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("DONE", OUT)
