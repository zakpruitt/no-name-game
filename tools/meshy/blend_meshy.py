"""Blender side of tools/meshy/meshy.py. Run by it, headless; not by hand.

    blender -b --python blend_meshy.py -- library <out_dir> <clips.glb> [...]
    blender -b --python blend_meshy.py -- build <job.json>

`library` reads Meshy animation GLBs (any Meshy-rigged character) and writes one JSON per clip:
each bone's rotation away from its rest pose, in armature space, and the hips' travel in hip
heights. That form fits every Meshy biped rig (the 24 bones always carry the same names), so a
clip is bought once and reused on every character.

`build` puts those clips on one rigged character, scales it, renames its material and exports
the game's GLB, a sheet of stills per clip and the numbers the foe table wants.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 30  # clips are sampled and exported at this rate
# bones whose rest direction is turned onto the clip's own before the motion goes on, so a
# character modelled with lower arms or a wider stance still swings where the clip swings
ALIGN = ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"]
HANDS = ["LeftHand", "RightHand"]
FEET = ["LeftFoot", "RightFoot"]
# Meshy's bone -> the game's name for it (the KayKit foes' names, which the checks and attachments look up)
GAME_BONES = {
    "Hips": "hips", "Spine02": "spine", "Spine01": "spine.1", "Spine": "chest", "neck": "neck", "Head": "head",
    "LeftShoulder": "shoulder.l", "LeftArm": "upperarm.l", "LeftForeArm": "lowerarm.l", "LeftHand": "hand.l",
    "RightShoulder": "shoulder.r", "RightArm": "upperarm.r", "RightForeArm": "lowerarm.r", "RightHand": "hand.r",
    "LeftUpLeg": "upperleg.l", "LeftLeg": "lowerleg.l", "LeftFoot": "foot.l", "LeftToeBase": "toes.l",
    "RightUpLeg": "upperleg.r", "RightLeg": "lowerleg.r", "RightFoot": "foot.r", "RightToeBase": "toes.r",
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def load_glb(path):
    """Import a Meshy GLB. Returns (armature, body mesh or None); drops everything else."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    meshes = [o for o in new if o.type == "MESH" and o.parent == arm and o.vertex_groups and o.data.materials]
    body = max(meshes, key=lambda o: len(o.data.vertices)) if meshes else None
    for o in new:
        if o not in (arm, body):
            bpy.data.objects.remove(o)
    return arm, body


def child_dir(arm, name):
    """Unit vector from a bone's joint to its first child's joint, in world space."""
    b = arm.data.bones[name]
    kids = [c for c in b.children]
    if not kids:
        return None
    d = (arm.matrix_world @ kids[0].head_local) - (arm.matrix_world @ b.head_local)
    return d.normalized() if d.length > 1e-6 else None


def order_of(arm):
    out = []

    def walk(b):
        out.append(b.name)
        for c in b.children:
            walk(c)
    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return out


# ------------------------------------------------------------------ library

def library(out_dir, files):
    os.makedirs(out_dir, exist_ok=True)
    for path in files:
        reset()
        arm, _ = load_glb(path)
        scene = bpy.context.scene
        src_fps = 24.0  # the glTF importer lays keys out at 24 frames per second of clip time
        world = arm.matrix_world
        rest_q = {b.name: (world @ b.matrix_local).to_quaternion() for b in arm.data.bones}
        hips_rest = world @ arm.data.bones["Hips"].head_local
        dirs = {n: list(child_dir(arm, n)) for n in ALIGN}
        ad = arm.animation_data or arm.animation_data_create()
        for act in list(bpy.data.actions):
            if not act.slots:
                continue
            f0, f1 = act.frame_range
            seconds = (f1 - f0) / src_fps
            if seconds < 0.05:
                continue  # the rig file's one-frame rest clip
            ad.action = act
            ad.action_slot = act.slots[0]
            n = int(round(seconds * FPS)) + 1
            bones = {b: [] for b in rest_q}
            hips = []
            for i in range(n):
                f = f0 + (i / FPS) * src_fps
                scene.frame_set(int(math.floor(f)), subframe=f - math.floor(f))
                for pb in arm.pose.bones:
                    q = (world @ pb.matrix).to_quaternion() @ rest_q[pb.name].inverted()
                    bones[pb.name].append([round(v, 5) for v in q])
                p = (world @ arm.pose.bones["Hips"].matrix).translation - hips_rest
                hips.append([round(v / hips_rest.z, 5) for v in p])
            name = act.name.split("|")[1] if "|" in act.name else act.name
            name = name.strip().replace(" ", "_")
            doc = {"name": name, "fps": FPS, "frames": n, "source": os.path.basename(path),
                   "rest_dirs": dirs, "hips": hips, "bones": bones}
            with open(os.path.join(out_dir, name + ".json"), "w") as f:
                json.dump(doc, f, separators=(",", ":"))
            drift = Vector(hips[-1]) - Vector(hips[0])
            reach = max(Vector((h[0], h[1], 0)).length for h in hips)
            print("CLIP %-32s %5.2f s  %3d frames  hips end-start (%.2f %.2f) max floor travel %.2f (hip heights)" % (
                name, seconds, n, drift.x, drift.y, reach))


# -------------------------------------------------------------------- build

def build(job):
    reset()
    scene = bpy.context.scene
    arm, body = load_glb(job["rig"])
    if body is None:
        raise SystemExit("no skinned, textured mesh under the armature in " + job["rig"])
    names = {b.name for b in arm.data.bones}
    need = set(ALIGN) | set(HANDS) | set(FEET) | {"Hips", "Head"}
    if need - names:
        raise SystemExit("not a Meshy biped rig, missing bones: %s" % sorted(need - names))
    if arm.animation_data:
        arm.animation_data_clear()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)

    # scale to the game height, feet on the floor, transforms applied
    def bounds():
        ws = [body.matrix_world @ v.co for v in body.data.vertices]
        return min(w.z for w in ws), max(w.z for w in ws)
    lo, hi = bounds()
    k = job["height"] / (hi - lo)
    arm.scale = arm.scale * k
    bpy.context.view_layer.update()
    lo, hi = bounds()
    arm.location.z -= lo
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()

    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    body.name = job["kind"] + "_body"
    body.data.materials[0].name = job["material"]
    for im in bpy.data.images:
        if im.size[0] > 0:
            im.name = "paint"
    arm.name = "Armature"

    order = order_of(arm)
    parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
    rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
    rest_q = {n: m.to_quaternion() for n, m in rest.items()}
    hips_rest = rest["Hips"].translation.copy()
    my_dirs = {n: child_dir(arm, n) for n in ALIGN}
    out_name = {b: GAME_BONES.get(b, b) for b in order}
    for b in arm.data.bones:
        b.name = out_name[b.name]
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    ad = arm.animation_data_create()

    report = {"kind": job["kind"], "height": round(job["height"], 3), "tris": tris, "clips": {}}
    poses = {}  # game clip -> [ {bone: armature-space Matrix} per frame ]
    for clip, spec in job["clips"].items():
        with open(spec["file"]) as f:
            lib = json.load(f)
        i0 = int(round(spec.get("start", 0.0) * FPS))
        i1 = lib["frames"] - 1 if "end" not in spec else min(lib["frames"] - 1, int(round(spec["end"] * FPS)))
        count = i1 - i0 + 1 if "seconds" not in spec else int(round(spec["seconds"] * FPS)) + 1
        idx = [i0 + (i1 - i0) * j / max(1, count - 1) for j in range(count)]  # fractional: `seconds` retimes
        align = {}
        for n in ALIGN:
            align[n] = my_dirs[n].rotation_difference(Vector(lib["rest_dirs"][n]))
        root = spec.get("root", "lock")
        h0 = Vector(lib["hips"][i0])
        h1 = Vector(lib["hips"][i1])
        frames = []
        for j, i in enumerate(idx):
            P = {}
            for b in order:
                a, f = int(math.floor(i)), i - math.floor(i)
                c = min(a + 1, lib["frames"] - 1)
                q = Quaternion(lib["bones"][b][a]).slerp(Quaternion(lib["bones"][b][c]), f)
                if b in align:
                    q = q @ align[b]
                q = q @ rest_q[b]
                if b == "Hips":
                    h = Vector(lib["hips"][a]).lerp(Vector(lib["hips"][c]), f)
                    if root == "lock":  # the game moves the body: take the floor travel out, keep the bob
                        t = j / max(1, len(idx) - 1)
                        trend = h0.lerp(h1, t)
                        h = Vector((h.x - trend.x, h.y - trend.y, h.z))
                    pos = hips_rest + h * hips_rest.z
                elif parent[b] is None:
                    pos = rest[b].translation
                else:
                    pos = P[parent[b]] @ (rest[parent[b]].inverted() @ rest[b].translation)
                P[b] = Matrix.Translation(pos) @ q.to_matrix().to_4x4()
            frames.append(P)
        # hold the lowest foot where the rest pose has it, so short and long legs both stand on the floor
        if spec.get("ground", True):
            rest_low = min(rest[f].translation.z for f in FEET)
            for P in frames:
                low = min(P[f].translation.z for f in FEET)
                lift = rest_low - low
                if spec.get("ground") == "min" or lift > 0.0:
                    for b in order:
                        P[b] = Matrix.Translation((0, 0, lift)) @ P[b]
        poses[clip] = frames

        act = bpy.data.actions.new(clip)
        act.use_fake_user = True
        ad.action = act
        ad.action_slot = act.slots.new("OBJECT", arm.name)
        n = len(frames)
        for b in order:
            qs, ts = [], []
            for P in frames:
                par = P[parent[b]] if parent[b] else Matrix.Identity(4)
                local = rest[b] if parent[b] is None else rest[parent[b]].inverted() @ rest[b]
                B = local.inverted() @ par.inverted() @ P[b]
                qs.append(B.to_quaternion())
                ts.append(B.translation.copy())
            for i in range(1, n):
                if qs[i].dot(qs[i - 1]) < 0:
                    qs[i] = -qs[i]
            for c in range(4):
                fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].rotation_quaternion' % out_name[b], index=c)
                fc.keyframe_points.add(n)
                fc.keyframe_points.foreach_set("co", [v for i in range(n) for v in (i, qs[i][c])])
                fc.keyframe_points.foreach_set("interpolation", [1] * n)
                fc.update()
            if b == "Hips":
                for c in range(3):
                    fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].location' % out_name[b], index=c)
                    fc.keyframe_points.add(n)
                    fc.keyframe_points.foreach_set("co", [v for i in range(n) for v in (i, ts[i][c])])
                    fc.keyframe_points.foreach_set("interpolation", [1] * n)
                    fc.update()
        info = {"from": os.path.splitext(os.path.basename(spec["file"]))[0], "seconds": round((n - 1) / FPS, 3)}
        if spec.get("hit_scan"):
            # the blow: the frame a hand is furthest ahead of the hips (the model faces -Y here)
            reach = [max(P["Hips"].translation.y - P[h].translation.y for h in HANDS) for P in frames]
            info["hit_seconds"] = round(reach.index(max(reach)) / FPS, 3)
        if "hit" in spec:  # seconds into the built clip
            info["hit_seconds"] = spec["hit"]
        report["clips"][clip] = info

    # head top in the idle, for the health bar
    idle = poses.get(job.get("idle", "Idle_Combat"))
    if idle:
        head_top = max((P["Head"] @ (rest["Head"].inverted() @ Vector((v.co.x, v.co.y, v.co.z)))).z
                       for P in idle[:1] for v in _head_verts(body, arm))
        report["head_top"] = round(head_top, 3)

    # stills first (they need the actions), then the export
    if job.get("sheet_dir"):
        stills(job, arm, body, poses)
    ad.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(job["out"]), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=job["out"], export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=False,
                              export_apply=False, export_yup=True)
    report["bytes"] = os.path.getsize(job["out"])
    with open(job["report"], "w") as f:
        json.dump(report, f, indent=1)
    print("BUILT", job["out"])


def _head_verts(body, arm):
    g = body.vertex_groups.get(GAME_BONES["Head"])
    if g is None:
        return list(body.data.vertices)
    out = [v for v in body.data.vertices if any(e.group == g.index and e.weight > 0.5 for e in v.groups)]
    return out or list(body.data.vertices)


def stills(job, arm, body, poses):
    """Five stills per clip from the game's side of the camera, flat-lit, for a look at the motion."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_object_outline = True
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.16, 0.14, 0.26)
    scene.display.shading.background_type = "WORLD"
    scene.render.resolution_x = 360
    scene.render.resolution_y = 360
    scene.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = job["height"] * 1.45
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # the model faces -Y: stand in front and to one side, looking down a little
    pitch, yaw = math.radians(62), math.radians(-28)
    cam.rotation_euler = (pitch, 0.0, yaw)
    back = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X") @ Vector((0, 0, 12))
    cam.location = Vector((0, 0, job["height"] * 0.5)) + back
    ad = arm.animation_data
    os.makedirs(job["sheet_dir"], exist_ok=True)
    for clip, frames in poses.items():
        act = bpy.data.actions[clip]
        ad.action = act
        ad.action_slot = act.slots[0]
        n = len(frames)
        for s in range(job.get("stills", 5)):
            scene.frame_set(int(round(s * (n - 1) / max(1, job.get("stills", 5) - 1))))
            scene.render.filepath = os.path.join(job["sheet_dir"], "%s_%d.png" % (clip, s))
            bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    if args[0] == "library":
        library(args[1], args[2:])
    elif args[0] == "build":
        with open(args[1]) as f:
            build(json.load(f))
    else:
        raise SystemExit("unknown mode " + args[0])


main()
