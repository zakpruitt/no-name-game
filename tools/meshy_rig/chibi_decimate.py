# Decimates a Meshy GLB (about 1.2 M tris) to a game budget before it is retextured and rigged,
# keeping the silhouette: welds the seam split first so the collapse sees one surface, then
# collapses in two passes, and renders front / side / top so the hood and tentacle can be checked.
#   blender -b --factory-startup -P chibi_decimate.py -- <in.glb> <out.glb> [target_tris] [render_dir] [mirror]
# mirror=1 flips left and right: the game's tentacle is the RIGHT arm (hand.r), and the chibi
# came out with it on the left.
# The output keeps Meshy's orientation (face towards +Z in glTF), which the rigging API needs.
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
TARGET = int(args[2]) if len(args) > 2 else 22000
RENDER = args[3] if len(args) > 3 else ""
MIRROR = len(args) > 4 and args[4] == "1"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = next(o for o in bpy.data.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
me = ob.data
t0 = sum(len(p.vertices) - 2 for p in me.polygons)
bb = [ob.matrix_world @ v.co for v in me.vertices]
print("source tris %d verts %d  z %.3f..%.3f  x %.3f..%.3f  y %.3f..%.3f" % (
    t0, len(me.vertices), min(v.z for v in bb), max(v.z for v in bb),
    min(v.x for v in bb), max(v.x for v in bb), min(v.y for v in bb), max(v.y for v in bb)))

# weld: Meshy splits the surface at UV seams; per-loop UVs survive a merge
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.0001)
bpy.ops.object.mode_set(mode="OBJECT")
print("after weld verts", len(me.vertices))

# two passes: a gentle first collapse keeps thin parts (tentacle fingers) better than one big one
for frac in ((0.25, None) if TARGET else ()):  # target 0: no decimate (just look, recentre)
    cur = sum(len(p.vertices) - 2 for p in me.polygons)
    goal = cur * frac if frac else TARGET
    mod = ob.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(goal / cur, 1e-4)
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print("pass ->", sum(len(p.vertices) - 2 for p in me.polygons))
# centre on the origin, feet on the floor (the saved candidate sat 6 m off in x)
ob.data.transform(ob.matrix_world)
ob.matrix_world = __import__("mathutils").Matrix.Identity(4)
vs = [v.co for v in me.vertices]
off = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2, min(v.z for v in vs)))
ob.data.transform(__import__("mathutils").Matrix.Translation(-off))
print("recentred by", tuple(round(x, 3) for x in off))
if MIRROR:
    ob.data.transform(__import__("mathutils").Matrix.Diagonal((-1, 1, 1, 1)))
    me.flip_normals()
    print("mirrored left/right")
for p in me.polygons:
    p.use_smooth = True
t1 = sum(len(p.vertices) - 2 for p in me.polygons)
print("final tris", t1)

os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=True, export_animations=False)
print("EXPORTED", OUT, os.path.getsize(OUT) // 1024, "KB")

if RENDER:
    os.makedirs(RENDER, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = sc.render.resolution_y = 640
    w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0.12, 0.1, 0.2)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"
    bb = [ob.matrix_world @ v.co for v in me.vertices]
    c = sum(bb, Vector()) / len(bb)
    h = max(v.z for v in bb) - min(v.z for v in bb)
    cam.data.ortho_scale = h * 1.15
    for name, d in (("front", (0, -1, 0.05)), ("side", (1, 0, 0.05)), ("back", (0, 1, 0.05)), ("top", (0.0, -0.6, 1))):
        d = Vector(d).normalized()
        cam.location = c + d * 6
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(RENDER, name + ".png")
        bpy.ops.render.render(write_still=True)
    print("RENDERED", RENDER)
