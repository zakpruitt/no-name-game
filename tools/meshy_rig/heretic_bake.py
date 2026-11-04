# Bakes the current hero's clips onto the rebuilt rig, moves his weapons over, exports a GLB.
#   blender -b <rig.blend> -P heretic_bake.py -- <shaman_comic.glb> <out.glb> [height_m]
# height_m: his height in the GLB (default: the old hero's head height decides it, ~1.95 m).
# Each mapped bone takes the source bone's direction and world rotation, so the weapon in hand.r
# swings as it does on the old hero, whatever the rest poses and proportions are.
import bpy, sys, os, json, struct
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
SRC_GLB, OUT = args[0], args[1]
HEIGHT = float(args[2]) if len(args) > 2 else 0.0
# void_surge, void_seep and void_frost are left out: they are shaped to wrap the old hero's arm
FORMS = ["axe_void_haft", "axe_void_blade", "axe_void_edge", "axe_void_core",
         "hammer_void_haft", "hammer_void_head", "hammer_void_rock", "hammer_void_lava",
         "spear_void_haft", "spear_void_collar", "spear_void_ice"]
ONE_TO_ONE = ["root", "hips", "spine", "chest", "head",
              "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
              "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r",
              "upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
# bones the source doesn't have: which source bone(s) they follow
FOLLOW = {"neck": ("chest", "head"), "shoulder.l": ("chest",), "shoulder.r": ("chest",)}

scene = bpy.context.scene
ob = bpy.data.objects["heretic"]
arm = bpy.data.objects["HereticRig"]
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
known = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=SRC_GLB)
new = [o for o in bpy.data.objects if o not in known]
src = next(o for o in new if o.type == "ARMATURE")
fps = scene.render.fps / scene.render.fps_base
print("fps", fps, "src arm matrix", [round(x, 3) for x in src.matrix_world.to_euler()], "source bones", len(src.data.bones))
if src.animation_data:
    for tr in list(src.animation_data.nla_tracks):
        src.animation_data.nla_tracks.remove(tr)
    src.animation_data.action = None
for pb in src.pose.bones:
    pb.matrix_basis.identity()
bpy.context.view_layer.update()
SR = {b.name: src.matrix_world @ b.matrix_local for b in src.data.bones}

# ---- bake the rig into world space, then scale it to the old hero's height
ob_m = ob.matrix_world.copy()
ob.parent = None
ob.matrix_parent_inverse.identity()
ob.data.transform(ob_m)
ob.matrix_world = Matrix.Identity(4)
scale = (SR["head"].translation.z) / arm.data.bones["head"].head_local.z
if HEIGHT > 0:  # an asked-for height instead: weapons keep their size, so he grows into them
    scale = HEIGHT / max(v.co.z for v in ob.data.vertices)
print("scale to old hero: %.3f (head %.3f -> %.3f)" % (scale, arm.data.bones["head"].head_local.z, SR["head"].translation.z))
ob.data.transform(Matrix.Scale(scale, 4))
bpy.context.view_layer.objects.active = arm
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for eb in arm.data.edit_bones:
    eb.head *= scale; eb.tail *= scale
bpy.ops.object.mode_set(mode="OBJECT")
ob.parent = arm
bpy.context.view_layer.update()
NR = {b.name: b.matrix_local.copy() for b in arm.data.bones}
print("heretic top %.3f; source head %.3f" % (max(v.co.z for v in ob.data.vertices), SR["head"].translation.z))

def bone_dir(M):
    return (M.to_3x3() @ Vector((0, 1, 0))).normalized()
ALIGN = {}
for nm in ONE_TO_ONE:
    # new bone's rest direction -> source bone's
    ALIGN[nm] = bone_dir(NR[nm]).rotation_difference(bone_dir(SR[nm]))
    # feet stay flat by copying rotation only: the two rigs' foot bones point different ways
    if nm == "root" or nm.startswith(("foot.", "toes.")):
        ALIGN[nm] = Quaternion()

# ---- weapons: same place in the hand as on the old hero
old_hand, new_hand = SR["hand.r"], NR["hand.r"]
Ainv = ALIGN["hand.r"].inverted().to_matrix().to_4x4()
wm = Matrix.Translation(new_hand.translation) @ Ainv @ Matrix.Translation(-old_hand.translation)
weapons = []
for nm in FORMS:
    o = bpy.data.objects.get(nm)
    if o is None or o.type != "MESH":
        print("  no weapon mesh", nm); continue
    m = o.data.copy()
    colors = [c.name for c in m.color_attributes]
    # the shipped GLB has g in COLOR_0; keep only that so the export has one colour attribute
    for c in colors[1:]:
        m.color_attributes.remove(m.color_attributes[c])
    m.transform(wm @ o.matrix_world)
    n = bpy.data.objects.new(nm + "__new", m)
    scene.collection.objects.link(n)
    n.parent = arm
    g = n.vertex_groups.new(name="weapon." + nm.split("_")[0])
    g.add(list(range(len(m.vertices))), 1.0, "REPLACE")
    n.modifiers.new("rig", "ARMATURE").object = arm
    weapons.append((n, nm))
print("weapons", len(weapons))
# one bone per weapon, from the hand along its haft, so each can stretch out of the limb on its own
hand_head = new_hand.translation.copy()
far = {}
for n, nm in weapons:
    form = nm.split("_")[0]
    for v in n.data.vertices:
        d = (v.co - hand_head).length
        if d > far.get(form, (0.0, None))[0]:
            far[form] = (d, v.co.copy())
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for form, (d, tip) in far.items():
    eb = arm.data.edit_bones.new("weapon." + form)
    eb.head, eb.tail = hand_head, tip
    eb.parent = arm.data.edit_bones["hand.r"]
    print("  weapon bone", form, "length %.2f" % d)
bpy.ops.object.mode_set(mode="OBJECT")

# ---- read every source clip
clips = [a for a in bpy.data.actions if a.users or a.use_fake_user or True]
clips = [a for a in clips if a.slots and any(s.identifier.startswith("OB") for s in a.slots)]
for o in new:
    if o is not src:
        bpy.data.objects.remove(o)
ad = src.animation_data or src.animation_data_create()
wanted = set(ONE_TO_ONE) | {x for v in FOLLOW.values() for x in v}
poses = {}
for a in clips:
    ad.action = a
    ad.action_slot = next(s for s in a.slots if s.identifier.startswith("OB"))
    f0, f1 = int(round(a.frame_range[0])), int(round(a.frame_range[1]))
    frames = []
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        frames.append({nm: src.matrix_world @ src.pose.bones[nm].matrix for nm in wanted if nm in src.pose.bones})
    poses[a.name] = frames
print("clips read", len(poses))
for nm in ("foot.l", "foot.r"):
    pass
src_z0 = {s: SR[f"foot.{s}"].translation.z for s in "lr"}
new_z0 = {s: NR[f"foot.{s}"].translation.z for s in "lr"}
hip_ratio = NR["hips"].translation.z / SR["hips"].translation.z
print("hip height ratio %.3f" % hip_ratio, "foot rest z", src_z0, new_z0)

for a in list(poses):
    bpy.data.actions[a].name = "SRC_" + a
ad.action = None
bpy.data.objects.remove(src)
for a in [x for x in bpy.data.actions if x.name.startswith("SRC_")]:
    bpy.data.actions.remove(a)

# ---- bake
order = ["root", "hips", "spine", "chest", "neck", "head", "shoulder.l", "shoulder.r",
         "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
         "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r",
         "upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
srq = {k: v.to_quaternion() for k, v in SR.items()}
nrq = {k: v.to_quaternion() for k, v in NR.items()}
LOCAL = {b: (NR[parent[b]].inverted() @ NR[b]) if parent[b] else NR[b] for b in order}

def solve(fr, drop=0.):
    P = {}
    for b in order:
        if b in ALIGN:
            q = fr[b].to_quaternion() @ srq[b].inverted() @ ALIGN[b] @ nrq[b]
        else:
            fs = FOLLOW[b]
            d = [fr[x].to_quaternion() @ srq[x].inverted() for x in fs]
            dq = d[0] if len(d) == 1 else d[0].slerp(d[1], .5)
            q = dq @ nrq[b]
        M = q.to_matrix().to_4x4()
        if b == "root":
            M.translation = fr["root"].translation - SR["root"].translation + NR["root"].translation
        elif b == "hips":
            dp = (fr["hips"].translation - fr["root"].translation) - (SR["hips"].translation - SR["root"].translation)
            M.translation = P["root"].translation + NR["hips"].translation - NR["root"].translation + dp * hip_ratio + Vector((0, 0, drop))
        else:
            M.translation = (P[parent[b]] @ LOCAL[b]).translation
        P[b] = M
    return P

for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
aa = arm.animation_data_create()
stats = []
for name, frames in poses.items():
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    aa.action = act
    slot = act.slots.new("OBJECT", arm.name)
    aa.action_slot = slot
    data = {b: {"q": [], "t": []} for b in order}
    low = 9.
    for fr in frames:
        P = solve(fr)
        # keep his feet at the height the source's were: legs are not the same length
        # (measured from each foot's own rest height: the ankle bones don't sit at the same place)
        sz = min(fr[f"foot.{x}"].translation.z - src_z0[x] for x in "lr")
        nz = min(P[f"foot.{x}"].translation.z - new_z0[x] for x in "lr")
        P = solve(fr, sz - nz)
        for b in order:
            par = P[parent[b]] if parent[b] else Matrix.Identity(4)
            B = LOCAL[b].inverted() @ par.inverted() @ P[b]
            q, t = B.to_quaternion(), B.translation
            data[b]["q"].append(q); data[b]["t"].append(t)
        low = min(low, nz + (sz - nz))
    stats.append((name, len(frames), round(low, 3)))
    N = len(frames)
    for b, d in data.items():
        # keep quaternions on one hemisphere so linear keys don't spin the long way
        for i in range(1, N):
            if d["q"][i].dot(d["q"][i - 1]) < 0:
                d["q"][i] = -d["q"][i]
        for k in range(4):
            fc = act.fcurve_ensure_for_datablock(arm, f'pose.bones["{b}"].rotation_quaternion', index=k)
            fc.keyframe_points.add(N)
            fc.keyframe_points.foreach_set("co", [v for i in range(N) for v in (i + 1, d["q"][i][k])])
            fc.keyframe_points.foreach_set("interpolation", [1] * N)
            fc.update()
        if b in ("root", "hips"):
            for k in range(3):
                fc = act.fcurve_ensure_for_datablock(arm, f'pose.bones["{b}"].location', index=k)
                fc.keyframe_points.add(N)
                fc.keyframe_points.foreach_set("co", [v for i in range(N) for v in (i + 1, d["t"][i][k])])
                fc.keyframe_points.foreach_set("interpolation", [1] * N)
                fc.update()
print("clips baked", len(stats), "sample", stats[:4])

# ---- names, material, export
aa.action = None
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
for n, nm in weapons:
    n.name = nm
ob.data.materials[0].name = "P_HereticPaint"
arm.name = "Armature"
for o in bpy.context.selected_objects:
    o.select_set(False)
arm.select_set(True); ob.select_set(True)
for n, _ in weapons:
    n.select_set(True)
bpy.context.view_layer.objects.active = arm
os.makedirs(os.path.dirname(OUT), exist_ok=True)
# keep a blend beside the GLB so the bake can be inspected
bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + "_baked.blend", copy=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=False,
                          export_apply=False, export_yup=True)
d = open(OUT, "rb").read()
l = struct.unpack("<I", d[12:16])[0]
j = json.loads(d[20:20 + l])
print("GLB", len(d) // 1024, "KB; meshes", [m["name"] for m in j["meshes"]][:20])
print("anims", len(j["animations"]), [a["name"] for a in j["animations"]][:8])
print("joints", len(j["skins"][0]["joints"]), "materials", [m["name"] for m in j["materials"]], "images", len(j.get("images", [])))
print("colour attrs", sorted({k for m in j["meshes"] for p in m["primitives"] for k in p["attributes"] if k.startswith("COLOR")}))
print("BAKED", OUT)
