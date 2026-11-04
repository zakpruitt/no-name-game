# Prints the numbers that matter for a hero GLB: tris per mesh, materials, textures, bones,
# height, and the chains the rig contract needs (tent.*, skirt.*, weapon.*, hand.r).
#   blender -b --factory-startup -P heretic_audit.py -- <hero.glb>
import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args[0])
dg = bpy.context.evaluated_depsgraph_get()
tot = 0
for o in bpy.data.objects:
    if o.type == "MESH":
        m = o.data
        t = sum(len(p.vertices) - 2 for p in m.polygons)
        tot += t
        bb = [o.matrix_world @ v.co for v in m.vertices]
        print("mesh %-22s tris %6d verts %6d mats %s z %.2f..%.2f" % (o.name, t, len(m.vertices), [s.name for s in m.materials],
              min(v.z for v in bb), max(v.z for v in bb)))
print("TOTAL tris", tot)
for im in bpy.data.images:
    print("image", im.name, tuple(im.size))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
names = [b.name for b in arm.data.bones]
print("bones", len(names), "deform", sum(b.use_deform for b in arm.data.bones))
for pre in ("tent.", "skirt.", "weapon.", "finger."):
    print(" ", pre, sum(n.startswith(pre) for n in names))
for k in ("hand.r", "hips", "head", "foot.l"):
    b = arm.data.bones.get(k)
    print("  %-8s" % k, tuple(round(x, 3) for x in (arm.matrix_world @ b.head_local)) if b else "MISSING")
body = bpy.data.objects.get("heretic") or max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
zs = [(body.matrix_world @ v.co) for v in body.data.vertices]
print("body", body.name, "height %.3f width x %.3f depth y %.3f" % (max(v.z for v in zs) - min(v.z for v in zs),
      max(v.x for v in zs) - min(v.x for v in zs), max(v.y for v in zs) - min(v.y for v in zs)))
print("actions", len(bpy.data.actions))
