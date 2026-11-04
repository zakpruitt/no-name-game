# Stress poses for the rebuilt rig, same tests and measures as the audit of Meshy's rig.
#   blender -b <rig.blend> -P heretic_stress.py -- <outdir>
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
scene = bpy.context.scene
ob = bpy.data.objects["heretic"]
arm = bpy.data.objects["HereticRig"]
me = ob.data
n = len(me.vertices)
def reset():
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
reset()
mw = np.array(ob.matrix_world)
def posed():
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg); m = e.to_mesh()
    a = np.zeros(n * 3); m.vertices.foreach_get("co", a); e.to_mesh_clear()
    a = a.reshape(-1, 3)
    return (mw[:3, :3] @ a.T).T + mw[:3, 3]
base = posed()
raw = np.array([list(ob.matrix_world @ v.co) for v in me.vertices])
print("REST matches the source mesh: max offset %.5f m" % np.linalg.norm(base - raw, axis=1).max())

names = [g.name for g in ob.vertex_groups]
G = np.zeros((n, len(names)), np.float32)
for v in me.vertices:
    for g in v.groups:
        G[v.index, g.group] = g.weight
print("influences: max", int((G > 0).sum(1).max()), "unweighted", int(((G > 0).sum(1) == 0).sum()))
gi = lambda pre: [i for i, x in enumerate(names) if any(x.startswith(p) for p in pre)]
tmask = G[:, gi(["tent.", "upperarm.r", "lowerarm.r", "hand.r"])].sum(1) > .5
smask = G[:, gi(["skirt."])].sum(1) > .3
hmask = (raw[:, 2] > 1.35) & ~tmask

# weld for edge stats
key, wid = {}, np.zeros(n, int)
for i, c in enumerate(raw):
    wid[i] = key.setdefault(tuple(np.round(c, 4)), len(key))
edges = np.array(sorted({(min(wid[e.vertices[0]], wid[e.vertices[1]]), max(wid[e.vertices[0]], wid[e.vertices[1]]))
                         for e in me.edges if wid[e.vertices[0]] != wid[e.vertices[1]]}))
W = len(key)
wl = np.empty(W, dtype=object); wl[:] = "other"
wl[wid[tmask]] = "tentacle"; wl[wid[hmask]] = "head"
wl[np.load(os.path.splitext(bpy.data.filepath)[0] + "_audit_skirt.npy")] = "skirt"
wb = np.zeros((W, 3)); wb[wid] = base
rest = np.linalg.norm(wb[edges[:, 0]] - wb[edges[:, 1]], axis=1)
el = wl[edges[:, 0]]
def report(tag):
    bpy.context.view_layer.update()
    a = posed()
    w = np.zeros((W, 3)); w[wid] = a
    r = np.linalg.norm(w[edges[:, 0]] - w[edges[:, 1]], axis=1) / np.maximum(rest, 1e-5)
    msg = []
    for g in ("skirt", "tentacle", "head"):
        q = r[el == g]
        msg.append("%s: >1.3x %.1f%% <.7x %.1f%% max %.1fx" % (g, 100 * (q > 1.3).mean(), 100 * (q < .7).mean(), q.max()))
    print("STRESS %-24s %s" % (tag, " | ".join(msg)))
    if tag.startswith(("stride", "high knee")):
        L = np.linalg.norm(w[edges[:, 0]] - w[edges[:, 1]], axis=1); grow = L - rest
        m = wl[edges[:, 0]] == "skirt"
        z = wb[edges[:, 0]][:, 2]
        dx = np.abs(wb[edges[:, 0]][:, 0])
        print("   gap sizes: >2cm %d  >5cm %d  >10cm %d of %d edges; biggest %.1f cm" % (
            (grow[m] > .02).sum(), (grow[m] > .05).sum(), (grow[m] > .1).sum(), m.sum(), 100 * grow[m].max()))
        for lo, hi in ((.2, .4), (.4, .55), (.55, .7), (.7, .84)):
            q = m & (z >= lo) & (z < hi)
            print("      z %.2f-%.2f: >5cm %d of %d, stretched >1.3x %.1f%%" % (lo, hi, (grow[q] > .05).sum(), q.sum(), 100 * (r[q] > 1.3).mean()))
    return a

def rot(bn, axis, deg):   # world axis through the bone's head (world = armature here)
    pb = arm.pose.bones[bn]
    cur = pb.matrix.copy()
    h = cur.translation.copy()
    pb.matrix = Matrix.Translation(h) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-h) @ cur
    bpy.context.view_layer.update()
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

def skirt_follow(thL, thR, amount=.75):
    """Stand-in for the game's spring bones: each chain leans with the thigh on its side."""
    for i in range(12):
        a = 2 * math.pi * i / 12
        wl_ = (1 + math.sin(a)) / 2
        th = (wl_ * thL + (1 - wl_) * thR) * amount
        front = math.cos(a)
        if (th > 0) != (front > 0):
            th *= .35    # the side the leg swings away from just hangs
        rot(f"skirt.{i:02d}.1", X, th * .6)
        rot(f"skirt.{i:02d}.2", X, th * .25)
        rot(f"skirt.{i:02d}.3", X, th * .15)

def chain(name):
    out_, i = [], 1
    while f"tent.{name}.{i:02d}" in arm.pose.bones:
        out_.append(f"tent.{name}.{i:02d}"); i += 1
    return out_

def coil(name, deg, axis=(1, 0, 0)):
    q = Quaternion(axis, math.radians(deg))
    for b in chain(name):
        arm.pose.bones[b].rotation_quaternion = q
    bpy.context.view_layer.update()

cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = 2.2
cob = bpy.data.objects.new("c", cam); scene.collection.objects.link(cob); scene.camera = cob
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x, scene.render.resolution_y = 500, 600
sh = scene.display.shading; sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.background_type = "VIEWPORT"; sh.background_color = (.2, .2, .22)
def shoot(tag, views=("front", "side")):
    for v in views:
        d = {"front": Vector((0, -1, 0)), "side": Vector((-1, 0, 0)), "back": Vector((0, 1, 0)), "q": Vector((-1, -1, 0)).normalized()}[v]
        cob.location = Vector((0, 0, .9)) + d * 4
        cob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, f"{tag}_{v}.png")
        bpy.ops.render.render(write_still=True)

shoot("rest", ("front", "back"))
reset(); rot("upperleg.l", X, 40); rot("upperleg.r", X, -40); report("stride, thighs only"); shoot("stride_raw")
reset(); rot("upperleg.l", X, 40); rot("upperleg.r", X, -40); skirt_follow(40, -40); report("stride + skirt"); shoot("stride")
reset(); rot("upperleg.l", X, 75); report("high knee, thigh only"); shoot("knee_raw")
reset(); rot("upperleg.l", X, 75); skirt_follow(75, 0); report("high knee + skirt"); shoot("knee")
reset(); rot("hand.l", X, 70); a = report("L wrist 70")
print("   L-WRIST: head/hair moved >1cm:", int((np.linalg.norm(a - base, axis=1)[hmask] > .01).sum()))
reset(); rot("head", Z, 50); a = report("head turn 50"); d = np.linalg.norm(a - base, axis=1)
print("   HEAD-TURN: tentacle moved >1cm:", int((d[tmask] > .01).sum()), "of", int(tmask.sum()))
shoot("headturn", ("front",))
reset(); rot("upperarm.r", Y, 60); a = report("R upperarm 60"); d = np.linalg.norm(a - base, axis=1)
print("   ARM: head/hair moved >1cm:", int((d[hmask] > .01).sum()), "of", int(hmask.sum())); shoot("armup", ("front",))
reset(); rot("lowerarm.r", Y, 60); a = report("R lowerarm 60"); d = np.linalg.norm(a - base, axis=1)
print("   FOREARM: head/hair moved >1cm:", int((d[hmask] > .01).sum())); shoot("forearm", ("front",))
for t, deg in (("main", 45), ("up", 40), ("out", 40), ("mid", 40), ("low", 40)):
    reset(); coil(t, deg); a = report(f"coil {t} {deg}/bone"); d = np.linalg.norm(a - base, axis=1)
    print("   COIL %s: head/hair moved >1cm: %d, skirt moved >1cm: %d, tip moved %.2f m" % (t, (d[hmask] > .01).sum(), (d[smask] > .01).sum(), d[tmask].max()))
    shoot(f"coil_{t}", ("front",))
# the weapon state: every other tip collapses into the limb
reset()
for t in ("up", "out", "mid", "low"):
    pb = arm.pose.bones[f"tent.{t}.01"]; pb.scale = (.03, .03, .03)
for b in chain("main"):
    arm.pose.bones[b].scale = (.5, .5, .5)
rot("upperarm.r", Y, 55)
report("tips collapsed"); shoot("weapon", ("front", "q"))
print("DONE")
