"""The heretic hero, v2: a hand-scripted chibi body skinned to the existing rig.

    blender -b --factory-startup -P tools/hero_build/hero_v2.py -- <rig.glb> <out_dir> [variant] [render]

<rig.glb> is any hero GLB with the round-40 rig (assets/comic/heretic_chibi.glb): only its armature
is used, at its true rest pose, which is also the bind pose (jointWorld * IBM = identity), so the
body is built in rest-pose world space around the bones and every clip, contact frame and bone
lookup in the game keeps working. Writes <out_dir>/body.npz (glTF-space arrays for glb_swap.py),
<out_dir>/palette.png, <out_dir>/face.txt (the face frame for heretic_rig.gd), <out_dir>/hero_v2.blend
and, with `render`, workbench views (rest + a few clip frames) for a quick look.

Blender axes here: z up, he faces -y, his right hand is -x. glTF = (x, z, -y).

Every part is closed: primitives are unioned per part by a voxel remesh, smoothed and decimated, so
the game's inverted-hull ink has no holes or thin shells to break on. Colour is flat per face from a
swatch texture (PALETTE), so the comic toon shader's cut tones do all the shading.
"""
import bpy, bmesh, sys, math, os
import numpy as np
from mathutils import Vector, Matrix, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
RIG_GLB, OUT = argv[0], argv[1]
VARIANT = argv[2] if len(argv) > 2 else "hook"
RENDER = "render" in argv[3:]
TIP = os.environ.get("HERO_TIP", "crimson")  # horn tips: crimson (picked by film: violet merged into the claw) or violet
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- palette (sRGB 0..1, flat swatches)
PALETTE = {
    "hood": (0.95, 0.91, 0.8), "hood_shade": (0.74, 0.68, 0.62), "lining": (0.55, 0.07, 0.14),
    "face": (0.03, 0.025, 0.06),
    "tunic": (0.1, 0.11, 0.16), "belt": (0.6, 0.08, 0.15), "trousers": (0.06, 0.06, 0.1),
    "skirt": (0.12, 0.1, 0.17), "skirt_hem": (0.6, 0.08, 0.15),
    "scarf": (0.84, 0.17, 0.2), "scarf_end": (0.64, 0.09, 0.15),
    "boot": (0.16, 0.14, 0.19), "boot_cuff": (0.6, 0.08, 0.15), "sole": (0.04, 0.03, 0.06),
    "sleeve": (0.07, 0.08, 0.12), "glove": (0.16, 0.14, 0.19), "wrap": (0.6, 0.08, 0.15),
    "claw": (0.62, 0.3, 1.0), "claw_deep": (0.3, 0.1, 0.56), "claw_tip": (1.0, 0.52, 0.95),
    "horn": (0.1, 0.06, 0.17), "horn_tip": (0.62, 0.3, 1.0) if TIP == "violet" else (0.84, 0.17, 0.2),
    "stripe": (0.72, 0.1, 0.17),
}
REGIONS = list(PALETTE)
SW = 16  # px per swatch
GRID = 8  # swatches per row: 128 px texture


def region_uv(r):
    k = REGIONS.index(r)
    return ((k % GRID + 0.5) / GRID, (k // GRID + 0.5) / GRID)  # glTF: v runs down the image


# ---------------------------------------------------------------- the rig at rest
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=RIG_GLB)
ARM = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o)
if ARM.animation_data:
    ARM.animation_data.action = None
for pb in ARM.pose.bones:
    pb.matrix_basis = Matrix()
MW = ARM.matrix_world.copy()
B = {b.name: (MW @ b.head_local, MW @ b.tail_local) for b in ARM.data.bones}


def H(n):
    return B[n][0].copy()


def T(n):
    return B[n][1].copy()


def chain(prefix):
    out = []
    i = 1
    while "%s.%02d" % (prefix, i) in B:
        out.append("%s.%02d" % (prefix, i))
        i += 1
    return out


# ---------------------------------------------------------------- primitives -> bmesh
def blob(bm, c, r, rot=Matrix(), seg=24, ring=16, exp=1.0):
    """Ellipsoid (exp < 1 squarer, a superellipsoid) at c with radii r, turned by rot."""
    verts = []
    for i in range(ring + 1):
        th = math.pi * i / ring
        st, ct = math.sin(th), math.cos(th)
        row = []
        for j in range(seg if 0 < i < ring else 1):
            ph = 2 * math.pi * j / seg
            sp, cp = math.sin(ph), math.cos(ph)
            def sgn(v):
                return math.copysign(abs(v) ** exp, v)
            p = Vector((r[0] * sgn(st) * sgn(cp), r[1] * sgn(st) * sgn(sp), r[2] * sgn(ct)))
            row.append(bm.verts.new(c + rot @ p))
        verts.append(row)
    for i in range(ring):
        a, b = verts[i], verts[i + 1]
        for j in range(seg):
            if len(a) == 1:
                bm.faces.new((a[0], b[(j + 1) % seg], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[j], a[(j + 1) % seg], b[0]))
            else:
                bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))


def catmull(pts, n):
    """n samples along a Catmull-Rom curve through pts (ends clamped)."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    segs = len(pts) - 1
    for k in range(n):
        t = k / (n - 1) * segs
        i = min(int(t), segs - 1)
        u = t - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    return out


def tube(bm, pts, radii, n=24, seg=14, flat=1.0, up=Vector((0, 0, 1)), cap=True):
    """Closed tube along a curve through pts, radius interpolated along radii (list or fn of t).
    flat < 1 squashes the section along `up` x tangent's normal."""
    P = catmull([Vector(p) for p in pts], n)
    rings = []
    for k, p in enumerate(P):
        t = k / (n - 1)
        tan = (P[min(k + 1, n - 1)] - P[max(k - 1, 0)]).normalized()
        side = tan.cross(up)
        if side.length < 1e-4:
            side = tan.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(tan).normalized()
        r = radii(t) if callable(radii) else np.interp(t, np.linspace(0, 1, len(radii)), radii)
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ring.append(bm.verts.new(p + side * math.cos(a) * r + nrm * math.sin(a) * r * flat))
        rings.append(ring)
    for k in range(n - 1):
        a, b = rings[k], rings[k + 1]
        for j in range(seg):
            bm.faces.new((a[j], a[(j + 1) % seg], b[(j + 1) % seg], b[j]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return P


def ring(bm, c, u, v, a, b, r, n=40, seg=12, flat=1.0):
    """A closed torus: centre c, in the plane of unit vectors u, v, radii a (along u), b (along v),
    tube radius r (flat < 1 squashes the section across the plane)."""
    w = u.cross(v).normalized()
    rings = []
    for k in range(n):
        t = 2 * math.pi * k / n
        p = c + u * math.cos(t) * a + v * math.sin(t) * b
        out = (u * math.cos(t) * b + v * math.sin(t) * a).normalized()
        rr = []
        for j in range(seg):
            q = 2 * math.pi * j / seg
            rr.append(bm.verts.new(p + out * math.cos(q) * r + w * math.sin(q) * r * flat))
        rings.append(rr)
    for k in range(n):
        A, Bn = rings[k], rings[(k + 1) % n]
        for j in range(seg):
            bm.faces.new((A[j], A[(j + 1) % seg], Bn[(j + 1) % seg], Bn[j]))


def part_object(name, build, voxel=0.012, smooth=4, target=None, subtract=None):
    """A closed part: primitives from build(bm), unioned by voxel remesh, smoothed, decimated."""
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.adaptivity = 0.0
    if smooth:
        m = ob.modifiers.new("smooth", "SMOOTH")
        m.factor = 0.5
        m.iterations = smooth
    _apply(ob)
    if subtract is not None:
        # after the union: EXACT needs a clean closed mesh, not overlapping primitives
        m = ob.modifiers.new("cut", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = subtract
        m.solver = "EXACT"
        _apply(ob)
        m = ob.modifiers.new("remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = voxel
        m = ob.modifiers.new("smooth", "SMOOTH")
        m.factor = 0.5
        m.iterations = 2
        _apply(ob)
    if target:
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        if tris > target:
            m = ob.modifiers.new("dec", "DECIMATE")
            m.ratio = target / tris
            _apply(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def _apply(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def cutter(name, build):
    bm = bmesh.new()
    build(bm)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.hide_render = True
    return ob


def rot_x(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def rot_y(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Y")


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


# ---------------------------------------------------------------- design numbers (rest pose, m)
NECK = H("head")                      # the head's pivot
HEAD_C = Vector((0.045, -0.02, 1.31))  # the hood's mass
HEAD_R = (0.37, 0.35, 0.33)
FACE_TILT = 35.0                       # degrees the face opening turns up towards the game camera
FACE_PHI = 12.0                        # degrees up the head's front where the opening sits
FACE_ROT = rot_x(-FACE_TILT)
FACE_N = (FACE_ROT @ Vector((0, -1, 0))).normalized()  # out of the face
FACE_UP = (FACE_ROT @ Vector((0, 0, 1))).normalized()
FACE_SURF = HEAD_C + Vector((0, -HEAD_R[1] * math.cos(math.radians(FACE_PHI)), HEAD_R[2] * math.sin(math.radians(FACE_PHI))))
FACE_R = (0.23, 0.07, 0.18)            # face plate half width, depth, half height
FACE_C = FACE_SURF - FACE_N * 0.095    # its front sits 2.5 cm inside the opening
CAVITY_C = FACE_SURF + FACE_N * 0.03
CAVITY_R = (0.25, 0.16, 0.2)
TORSO_C = Vector((0.03, 0.12, 0.78))
SKIRT_C = Vector((0.025, 0.2, 0.0))  # the skirt ring's axis (x, y)


def build_head(bm):
    blob(bm, HEAD_C, HEAD_R, seg=32, ring=24, exp=0.92)
    # cheeks / jowls of the hood, flaring a little at the bottom: a menacing wide base
    blob(bm, HEAD_C + Vector((0, 0.02, -0.17)), (0.36, 0.3, 0.14), seg=28, ring=14)
    if VARIANT == "hook":
        # one big point up and back, kinked over to his left: reads above the hood from 54 degrees up
        tube(bm, [HEAD_C + Vector((0.0, 0.1, 0.16)), HEAD_C + Vector((0.0, 0.2, 0.36)),
                  HEAD_C + Vector((0.03, 0.33, 0.52)), HEAD_C + Vector((0.2, 0.42, 0.6))],
             lambda t: 0.25 * (1 - t) ** 1.25 + 0.012, n=28, seg=16)
    elif VARIANT == "horns":
        # the hood's own point, swept back and drooping: a cowl, not a crown (horns: build_horns)
        tube(bm, BACK_POINT, lambda t: 0.22 * (1 - t) ** 1.2 + 0.016, n=30, seg=16)
    elif VARIANT == "twin":
        # two long points swept back, the left one longer: an imp's hood
        for s, ln in ((-1, 0.75), (1, 1.0)):
            tube(bm, [HEAD_C + Vector((0.14 * s, 0.08, 0.18)), HEAD_C + Vector((0.22 * s, 0.22, 0.38)),
                      HEAD_C + Vector((0.3 * s, 0.4 * ln, 0.5 * ln)), HEAD_C + Vector((0.38 * s, 0.62 * ln, 0.5 * ln))],
                 lambda t: 0.17 * (1 - t) ** 1.2 + 0.012, n=26, seg=14)


BACK_POINT = [HEAD_C + Vector((0, 0.12, 0.17)), HEAD_C + Vector((0, 0.34, 0.28)),
              HEAD_C + Vector((-0.03, 0.58, 0.22)), HEAD_C + Vector((-0.09, 0.8, 0.04))]


def horn_points(s):
    # out from the temples, splayed wide, up, the tips hooking forward: breaks the outline from above
    return [HEAD_C + Vector((0.18 * s, 0.04, 0.13)), HEAD_C + Vector((0.44 * s, 0.05, 0.27)),
            HEAD_C + Vector((0.62 * s, -0.02, 0.5)), HEAD_C + Vector((0.58 * s, -0.17, 0.7))]


def build_horns(bm):
    for s in (-1, 1):
        tube(bm, horn_points(s), lambda t: 0.155 * (1 - t) ** 1.1 + 0.016, n=30, seg=16)


def stripe_points():
    # down the hood's crown and back on its midline, then along the back point to its tip
    pts = []
    for k in range(7):
        a = math.radians(-30 + 85 * k / 6)  # from a little ahead of the top to half way down the back
        pts.append(HEAD_C + Vector((0.0, math.sin(a) * HEAD_R[1], math.cos(a) * HEAD_R[2])) * 1.07)
    return pts


def build_stripe(bm):
    # a bold crimson ridge, half sunk into the hood, from the brow over the crown and down the back point
    tube(bm, stripe_points(), lambda t: 0.09 - 0.02 * t, n=30, seg=12)
    # on top of the back point: each centre lifted by most of the point's radius there
    tube(bm, [p + Vector((0, 0, 0.8 * (0.22 * (1 - k / 3) ** 1.2 + 0.016))) for k, p in enumerate(BACK_POINT)][1:],
         lambda t: 0.065 * (1 - t) + 0.012, n=20, seg=12)


def build_cavity(bm):
    blob(bm, CAVITY_C, CAVITY_R, rot=FACE_ROT, seg=28, ring=18)


def build_rim(bm):
    u = (FACE_ROT @ Vector((1, 0, 0))).normalized()
    ring(bm, FACE_SURF - FACE_N * 0.01, u, FACE_UP, CAVITY_R[0] * 0.93, CAVITY_R[2] * 0.93, 0.04, n=48, flat=1.0)


def build_face(bm):
    blob(bm, FACE_C, FACE_R, rot=FACE_ROT, seg=28, ring=18)


def build_torso(bm):
    # a stubby pear: chest under the hood, a round belly
    blob(bm, TORSO_C, (0.2, 0.17, 0.2), seg=24, ring=16)
    blob(bm, TORSO_C + Vector((0, -0.01, 0.12)), (0.26, 0.18, 0.12), seg=24, ring=12)
    tube(bm, [H("neck") - Vector((0, 0, 0.04)), T("neck") + Vector((0, 0, 0.04))], [0.09, 0.09], n=4, seg=12)
    # thighs to the knee, under the skirt
    for s in "lr":
        tube(bm, [H("upperleg." + s), T("upperleg." + s)], [0.1, 0.075], n=8, seg=14)


def build_belt(bm):
    ring(bm, TORSO_C + Vector((0, -0.01, -0.09)), Vector((1, 0, 0)), Vector((0, 1, 0)), 0.215, 0.18, 0.04, flat=1.0)


def build_scarf_wrap(bm):
    c = H("neck") + Vector((0, 0.0, 0.0))
    ring(bm, c, Vector((1, 0, 0)), Vector((0, 1, 0)).lerp(Vector((0, 0, 1)), 0.15).normalized(), 0.15, 0.13, 0.07)
    blob(bm, c + Vector((0.06, -0.12, -0.05)), (0.08, 0.05, 0.07))  # the knot


SCARF_MORE = 0.16  # m the ribbon runs on past the last scarf bone (weighted to it)


def build_scarf_tail(bm):
    names = chain("scarf")
    pts = [H(names[0]) + Vector((0, -0.02, 0.0))] + [T(n) for n in names]
    d = (pts[-1] - pts[-2]).normalized()
    pts.append(pts[-1] + d * SCARF_MORE)
    # a flat ribbon, box section: wide side faces up/back so it reads from above
    tube(bm, pts, [0.11, 0.15, 0.15, 0.14, 0.13, 0.12][:len(pts)], n=34, seg=12, flat=0.3, up=Vector((0, 0, 1)))
    # swallowtail end: two short points
    end = pts[-1]
    side = d.cross(Vector((0, 0, 1))).normalized()
    for s in (-1, 1):
        tube(bm, [end - d * 0.05, end + d * 0.13 + side * 0.09 * s], [0.07, 0.018], n=8, seg=10, flat=0.45)


def build_skirt(bm):
    # a short flared tunic skirt from the belt to above the knee, chunky hem points
    top_z, bot_z = 0.7, 0.36
    n = 36
    for k in range(6):  # six panels, each a thick wedge, overlapping: a jagged hem in silhouette
        a0 = k / 6 * 2 * math.pi
        pts = []
        for i in range(4):
            z = np.interp(i, [0, 3], [top_z, bot_z + (0.0 if k % 2 else 0.05)])
            r = np.interp(i, [0, 3], [0.22, 0.36])
            pts.append(Vector((SKIRT_C.x + math.cos(a0) * r * 1.05, SKIRT_C.y + math.sin(a0) * r * 0.9 - 0.06, z)))
        tube(bm, pts, [0.16, 0.19, 0.2, 0.1], n=10, seg=12, flat=0.35, up=Vector((math.cos(a0), math.sin(a0), 0)))


def build_legs(bm):
    for s in "lr":
        tube(bm, [H("lowerleg." + s), T("lowerleg." + s)], [0.075, 0.07], n=8, seg=14)


def build_boots(bm):
    for s in "lr":
        ank, toe0, toe1 = H("foot." + s), H("toes." + s), T("toes." + s)
        fwd = (toe1 - ank)
        fwd.z = 0
        fwd.normalize()
        side = fwd.cross(Vector((0, 0, 1)))
        # a big rounded boot: heel under the ankle to past the toes, flat on the floor
        c = (ank + toe1) * 0.5
        c.z = 0.085
        L = (toe1 - ank).length * 0.5 + 0.09
        rot = Matrix((side, fwd, Vector((0, 0, 1)))).transposed()
        blob(bm, c + fwd * 0.02, (0.115, L, 0.095), rot=rot, seg=24, ring=16, exp=0.8)
        tube(bm, [ank + Vector((0, 0, -0.02)), ank + Vector((0, 0, 0.1))], [0.095, 0.1], n=4, seg=16)


def build_cuffs(bm):
    for s in "lr":
        ank = H("foot." + s)
        ring(bm, ank + Vector((0, 0, 0.1)), Vector((1, 0, 0)), Vector((0, 1, 0)), 0.1, 0.1, 0.035)


def build_left_arm(bm):
    tube(bm, [H("upperarm.l"), T("upperarm.l"), T("lowerarm.l")], [0.075, 0.065, 0.065], n=14, seg=14)


def build_glove(bm):
    c = (H("hand.l") + T("hand.l")) * 0.5
    d = (T("hand.l") - H("wrist.l")).normalized()
    rot = d.to_track_quat("Z", "Y").to_matrix()
    blob(bm, c + d * 0.02, (0.12, 0.1, 0.13), rot=rot, seg=24, ring=16)
    # a thumb
    side = d.cross(Vector((0, 0, 1))).normalized()
    tube(bm, [c - side * 0.06, c - side * 0.13 + d * 0.06], [0.05, 0.04], n=6, seg=10)


def build_wrap(bm):
    d = (T("hand.l") - H("wrist.l")).normalized()
    u = d.cross(Vector((0, 0, 1))).normalized()
    v = d.cross(u).normalized()
    ring(bm, H("wrist.l") - d * 0.01, u, v, 0.075, 0.075, 0.035)


# The tentacle arm: the arm bones, then a palm, then three big claws (and a thumb hook) along the claw
# chains the clips key. Chains without geometry still animate, nothing hangs on them.
CLAWS = {"up": 0.085, "main": 0.095, "low": 0.08}
THUMB = {"mid": 0.06}


def arm_r_points():
    return [H("upperarm.r"), T("upperarm.r"), T("lowerarm.r"), H("hand.r")]


def build_tentacle_arm(bm):
    # chunky segments: a core tube with fat overlapping beads along it, growing to the wrist
    P = tube(bm, arm_r_points(), lambda t: 0.06 + 0.03 * t, n=24, seg=16)
    Q = catmull([Vector(p) for p in arm_r_points()], 60)
    L = [0.0]
    for i in range(len(Q) - 1):
        L.append(L[-1] + (Q[i + 1] - Q[i]).length)
    for k in range(ARM_BEADS):
        t = (k + 0.6) / (ARM_BEADS + 0.2)
        i = int(np.searchsorted(L, t * L[-1]))
        i = min(max(i, 1), len(Q) - 2)
        d = (Q[i + 1] - Q[i - 1]).normalized()
        r = 0.08 + 0.035 * t
        blob(bm, Q[i], (r, r, r * 0.62), rot=d.to_track_quat("Z", "Y").to_matrix(), seg=20, ring=12)
    return P


ARM_BEADS = 5


def palm_frame():
    roots = [H("tent.%s.01" % c) for c in list(CLAWS) + list(THUMB)]
    wrist = H("hand.r")
    c = sum(roots, Vector()) / len(roots)
    c = c.lerp(wrist, 0.35)
    return c, wrist, roots


def build_palm(bm):
    c, wrist, roots = palm_frame()
    d = (c - wrist).normalized()
    rot = d.to_track_quat("Z", "Y").to_matrix()
    blob(bm, c, (0.15, 0.11, 0.17), rot=rot, seg=24, ring=16)
    tube(bm, [wrist - d * 0.03, c], [0.1, 0.13], n=6, seg=16)


def claw_points(name):
    bones = chain("tent." + name)
    c, wrist, roots = palm_frame()
    pts = [c.lerp(H(bones[0]), 0.4)] + [H(b) for b in bones] + [T(bones[-1])]
    return pts


def build_claws(bm, which):
    for name, r in which.items():
        pts = claw_points(name)
        tube(bm, pts, lambda t, r=r: r * (1 - t) ** 0.85 + 0.012, n=30, seg=14)


# ---------------------------------------------------------------- build
cav = cutter("cavity", build_cavity)
parts = {}
parts["hood"] = part_object("hood", build_head, voxel=0.012, target=3000, subtract=cav)
if VARIANT == "horns":
    parts["horns"] = part_object("horns", build_horns, voxel=0.01, target=1400)
    parts["stripe"] = part_object("stripe", build_stripe, voxel=0.01, target=700)
parts["face"] = part_object("face", build_face, voxel=0.012, target=900)
parts["rim"] = part_object("rim", build_rim, voxel=0.01, target=900)
parts["torso"] = part_object("torso", build_torso, voxel=0.012, target=1800)
parts["belt"] = part_object("belt", build_belt, voxel=0.01, target=500)
parts["scarf_wrap"] = part_object("scarf_wrap", build_scarf_wrap, voxel=0.01, target=900)
parts["scarf_tail"] = part_object("scarf_tail", build_scarf_tail, voxel=0.01, target=700)
parts["skirt"] = part_object("skirt", build_skirt, voxel=0.012, target=1600)
parts["legs"] = part_object("legs", build_legs, voxel=0.012, target=600)
parts["boots"] = part_object("boots", build_boots, voxel=0.012, target=1400)
parts["cuffs"] = part_object("cuffs", build_cuffs, voxel=0.01, target=600)
parts["arm_l"] = part_object("arm_l", build_left_arm, voxel=0.012, target=700)
parts["glove"] = part_object("glove", build_glove, voxel=0.012, target=900)
parts["wrap"] = part_object("wrap", build_wrap, voxel=0.01, target=400)
parts["arm_r"] = part_object("arm_r", build_tentacle_arm, voxel=0.012, target=1600)
parts["palm"] = part_object("palm", build_palm, voxel=0.012, target=1000)
parts["claws"] = part_object("claws", lambda bm: build_claws(bm, CLAWS), voxel=0.01, target=1800)
parts["thumb"] = part_object("thumb", lambda bm: build_claws(bm, THUMB), voxel=0.01, target=500)


# ---------------------------------------------------------------- colour regions per face
def seg_t(p, pts):
    """Arc-length fraction of the closest point on polyline pts to p, and its distance."""
    best, bt, acc = 1e9, 0.0, 0.0
    L = [0.0]
    for i in range(len(pts) - 1):
        L.append(L[-1] + (pts[i + 1] - pts[i]).length)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        u = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
        d = (a + ab * u - p).length
        if d < best:
            best, bt = d, (L[i] + u * ab.length) / L[-1]
    return bt, best


def region_of(part, p):
    if part == "hood":
        return "hood"
    if part == "rim":
        return "lining"
    if part == "stripe":
        return "stripe"
    if part == "horns":
        t, _ = seg_t(p, horn_points(1 if p.x > 0 else -1))
        return "horn_tip" if t > 0.6 else "horn"
    if part == "cuffs":
        return "boot_cuff"
    if part == "wrap":
        return "wrap"
    if part == "face":
        return "face"
    if part == "torso":
        return "trousers" if p.z < 0.6 else "tunic"
    if part == "belt":
        return "belt"
    if part == "scarf_wrap":
        return "scarf"
    if part == "scarf_tail":
        names = chain("scarf")
        t, _ = seg_t(p, [H(names[0])] + [T(n) for n in names])
        return "scarf_end" if t > 0.72 else "scarf"
    if part == "skirt":
        return "skirt_hem" if p.z < 0.45 else "skirt"
    if part == "legs":
        return "trousers"
    if part == "boots":
        return "boot"
    if part == "arm_l":
        return "sleeve"
    if part == "glove":
        return "glove"
    if part == "arm_r":
        return "claw"
    if part == "palm":
        return "claw"
    if part in ("claws", "thumb"):
        which = CLAWS if part == "claws" else THUMB
        best = None
        for name in which:
            t, d = seg_t(p, claw_points(name))
            if best is None or d < best[1]:
                best = (t, d)
        return "claw_tip" if best[0] > 0.72 else "claw"
    return "hood"


# ---------------------------------------------------------------- skin weights
def bone_seg(n):
    return H(n), T(n)


def dist_seg(p, a, b):
    ab = b - a
    u = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (a + ab * u - p).length


ALLOWED = {
    "hood": ["head"], "horns": ["head"], "stripe": ["head"], "face": ["head"], "rim": ["head"], "cuffs": ["lowerleg.l", "lowerleg.r"], "wrap": ["wrist.l"],
    "torso": ["hips", "spine", "chest", "neck", "upperleg.l", "upperleg.r"],
    "belt": ["hips", "spine"],
    "scarf_wrap": ["chest", "neck"],
    "scarf_tail": ["chest"] + chain("scarf"),  # past the last bone: weighted to it
    "skirt": ["hips"] + [b for b in B if b.startswith("skirt.")],
    "legs": ["upperleg.l", "lowerleg.l", "upperleg.r", "lowerleg.r"],
    "boots": ["lowerleg.l", "foot.l", "toes.l", "lowerleg.r", "foot.r", "toes.r"],
    "arm_l": ["shoulder.l", "upperarm.l", "lowerarm.l", "wrist.l"],
    "glove": ["wrist.l", "hand.l"],
    "arm_r": ["shoulder.r", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r"],
    "palm": ["hand.r"],
    "claws": ["hand.r"] + [b for c in CLAWS for b in chain("tent." + c)],
    "thumb": ["hand.r"] + [b for c in THUMB for b in chain("tent." + c)],
}
POWER = {"torso": 5, "skirt": 4, "arm_r": 6, "claws": 6, "thumb": 6, "scarf_tail": 6, "legs": 6, "boots": 8, "arm_l": 6}


def weights_for(part, ob):
    me = ob.data
    names = ALLOWED[part]
    nv = len(me.vertices)
    W = np.zeros((nv, len(names)))
    if len(names) == 1:
        W[:, 0] = 1.0
        return names, W
    segs = [bone_seg(n) for n in names]
    pw = POWER.get(part, 5)
    for i, v in enumerate(me.vertices):
        p = v.co
        d = np.array([dist_seg(p, a, b) for a, b in segs])
        if part in ("claws", "thumb"):
            # a claw takes only its own chain (and the hand near the palm)
            own = None
            for c in (CLAWS if part == "claws" else THUMB):
                t, dd = seg_t(p, claw_points(c))
                if own is None or dd < own[1]:
                    own = (c, dd)
            mask = np.array([n == "hand.r" or n.startswith("tent.%s." % own[0]) for n in names])
            d = np.where(mask, d, 1e3)
        if part in ("boots", "cuffs"):
            side = "l" if p.x > 0 else "r"
            d = np.where(np.array([n.endswith("." + side) for n in names]), d, 1e3)
        if part == "legs":
            side = "l" if p.x > 0.01 else "r"
            d = np.where(np.array([n.endswith("." + side) for n in names]), d, 1e3)
        if part == "torso":
            # thighs only below the hips' own height, by side
            side = "l" if p.x > 0.0 else "r"
            for k, n in enumerate(names):
                if n.startswith("upperleg.") and (not n.endswith("." + side) or p.z > 0.6):
                    d[k] = 1e3
        w = 1.0 / np.maximum(d, 0.01) ** pw
        top = np.argsort(-w)[:4]
        ww = np.zeros_like(w)
        ww[top] = w[top]
        W[i] = ww / ww.sum()
    # smooth over edges
    adj = [[] for _ in range(nv)]
    for e in me.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    rounds = {"skirt": 6, "torso": 5, "arm_r": 4, "claws": 2, "thumb": 2, "scarf_tail": 4}.get(part, 3)
    for _ in range(rounds):
        W2 = W.copy()
        for i in range(nv):
            if adj[i]:
                W2[i] = 0.5 * W[i] + 0.5 * W[adj[i]].mean(axis=0)
        W = W2
    return names, W


# ---------------------------------------------------------------- weapons (formed by the claw)
# Each in its weapon bone's own frame (head on the hand, y along the haft, as the game's _read_form expects:
# the farthest vertex from the hand must lie up the haft). Blades lie flat in the bone's x-y plane with the
# edge towards -x, where the old ones had theirs, so chibi_keys.py's blade facing still holds. Oversized and
# chunky, closed parts only (the ink hull needs volume). One mesh per GLB node, same names and materials.
def bone_frame(n):
    m = MW @ ARM.data.bones[n].matrix_local
    o = m.to_translation()
    r = m.to_3x3().normalized()
    return o, r.col[0].normalized(), r.col[1].normalized(), r.col[2].normalized()


def in_frame(f, x, y, z):
    o, X, Y, Z = f
    return o + X * x + Y * y + Z * z


def crescent(bm, f, y0, y1, reach, thick, inner=0.0, n=14):
    """A flat axe blade on the -x side: from the haft at y0..y1 out to `reach`, a curved edge."""
    o, X, Y, Z = f
    rot = Matrix((X, Y, Z)).transposed()
    for k in range(n):
        t = k / (n - 1)
        y = y0 + (y1 - y0) * t
        bulge = math.sin(math.pi * t) ** 0.6
        x = -(inner + (reach - inner) * (0.55 + 0.45 * bulge))
        # an overlapping row of flattened blobs from the haft out to the edge makes one solid blade
        mid = (inner + abs(x)) * 0.5
        blob(bm, in_frame(f, -mid, y, 0.0), ((abs(x) - inner) * 0.5 + 0.03, (y1 - y0) / n * 1.6, thick), rot=rot, seg=16, ring=10)


def build_axe_haft(bm):
    f = bone_frame("weapon.axe")
    tube(bm, [in_frame(f, 0, -0.1, 0), in_frame(f, 0, 0.6, 0), in_frame(f, 0.0, 1.45, 0)], [0.06, 0.05, 0.05], n=16, seg=12)
    blob(bm, in_frame(f, 0, -0.12, 0), (0.08, 0.08, 0.08))  # pommel
    # the top spike: the farthest point, so the game reads the haft's direction from it
    tube(bm, [in_frame(f, 0, 1.4, 0), in_frame(f, 0, 1.92, 0)], [0.07, 0.012], n=8, seg=12)


AXE_C = (0.02, 1.24)    # the blade's arc centre on the bone's x-y plane (m)
AXE_R = 0.6             # its radius: the edge
AXE_ARC = (118.0, 242.0)  # degrees from +x, through -x: the crescent on the -x side


def axe_arc(k, n, r=AXE_R):
    a = math.radians(AXE_ARC[0] + (AXE_ARC[1] - AXE_ARC[0]) * k / (n - 1))
    return AXE_C[0] + math.cos(a) * r, AXE_C[1] + math.sin(a) * r


def build_axe_blade(bm):
    """A crescent: radial wedges from the haft out to the arc, thick at the haft, its two horns flaring."""
    f = bone_frame("weapon.axe")
    n = 15
    for k in range(n):
        ex, ey = axe_arc(k, n, AXE_R - 0.02)
        hx, hy = 0.0, AXE_C[1] + (ey - AXE_C[1]) * 0.45
        tube(bm, [in_frame(f, hx, hy, 0), in_frame(f, ex, ey, 0)], [0.07, 0.05], n=6, seg=10, flat=0.55, up=f[2])
    # a back hook on the +x side
    tube(bm, [in_frame(f, 0.0, 1.26, 0), in_frame(f, 0.18, 1.24, 0), in_frame(f, 0.3, 1.1, 0)], [0.07, 0.05, 0.012],
         n=10, seg=10, flat=0.6, up=f[2])


def build_axe_edge(bm):
    f = bone_frame("weapon.axe")
    pts = [in_frame(f, *axe_arc(k, 15, AXE_R + 0.01), 0) for k in range(15)]
    tube(bm, pts, lambda t: 0.06 * (math.sin(math.pi * t) ** 0.35) + 0.014, n=40, seg=10, flat=0.6, up=f[2])


def build_axe_core(bm):
    f = bone_frame("weapon.axe")
    o, X, Y, Z = f
    blob(bm, in_frame(f, -0.24, AXE_C[1], 0.0), (0.085, 0.085, 0.075), rot=Matrix((X, Y, Z)).transposed())


def build_spear_haft(bm):
    f = bone_frame("weapon.spear")
    tube(bm, [in_frame(f, 0, -0.12, 0), in_frame(f, 0, 0.7, 0), in_frame(f, 0, 1.3, 0)], [0.055, 0.048, 0.045], n=16, seg=12)
    blob(bm, in_frame(f, 0, -0.14, 0), (0.075, 0.075, 0.075))


def build_spear_collar(bm):
    f = bone_frame("weapon.spear")
    o, X, Y, Z = f
    ring(bm, in_frame(f, 0, 1.2, 0), X, Z, 0.07, 0.07, 0.04)
    ring(bm, in_frame(f, 0, 1.3, 0), X, Z, 0.08, 0.08, 0.045)


def build_spear_ice(bm):
    f = bone_frame("weapon.spear")
    o, X, Y, Z = f
    # a broad leaf head with two barbs: flat in x-y, so it reads from above as a big blade
    pts = [in_frame(f, 0, 1.28, 0), in_frame(f, 0, 1.5, 0), in_frame(f, 0, 1.75, 0), in_frame(f, 0, 2.02, 0)]
    tube(bm, pts, lambda t: 0.2 * math.sin(math.pi * min(1.0, t * 1.25 + 0.08)) ** 0.8 + 0.012, n=24, seg=14, flat=0.3, up=Z)
    for sx in (-1, 1):
        tube(bm, [in_frame(f, 0.08 * sx, 1.36, 0), in_frame(f, 0.22 * sx, 1.32, 0), in_frame(f, 0.27 * sx, 1.22, 0)],
             [0.05, 0.035, 0.012], n=8, seg=10, flat=0.5, up=Z)


def build_hammer_haft(bm):
    f = bone_frame("weapon.hammer")
    tube(bm, [in_frame(f, 0, -0.12, 0), in_frame(f, 0, 0.6, 0), in_frame(f, 0, 1.2, 0)], [0.065, 0.058, 0.058], n=16, seg=12)
    blob(bm, in_frame(f, 0, -0.14, 0), (0.09, 0.09, 0.09))


def build_hammer_head(bm):
    f = bone_frame("weapon.hammer")
    o, X, Y, Z = f
    blob(bm, in_frame(f, 0, 1.3, 0), (0.42, 0.21, 0.22), rot=Matrix((X, Y, Z)).transposed(), seg=28, ring=18, exp=0.45)


def build_hammer_lava(bm):
    f = bone_frame("weapon.hammer")
    o, X, Y, Z = f
    for sx in (-1, 1):  # glowing bands round both ends of the head
        ring(bm, in_frame(f, 0.3 * sx, 1.3, 0), Y, Z, 0.215, 0.225, 0.035, n=32)


def build_hammer_rock(bm):
    f = bone_frame("weapon.hammer")
    o, X, Y, Z = f
    # a spike on top (the farthest point) and studs on the faces
    tube(bm, [in_frame(f, 0, 1.45, 0), in_frame(f, 0, 1.72, 0)], [0.09, 0.012], n=8, seg=12)
    for sx in (-1, 1):
        tube(bm, [in_frame(f, 0.4 * sx, 1.3, 0), in_frame(f, 0.56 * sx, 1.3, 0)], [0.09, 0.015], n=8, seg=12)


WEAPON_PARTS = {
    "axe_void_haft": (build_axe_haft, "weapon.axe"), "axe_void_blade": (build_axe_blade, "weapon.axe"),
    "axe_void_edge": (build_axe_edge, "weapon.axe"), "axe_void_core": (build_axe_core, "weapon.axe"),
    "spear_void_haft": (build_spear_haft, "weapon.spear"), "spear_void_collar": (build_spear_collar, "weapon.spear"),
    "spear_void_ice": (build_spear_ice, "weapon.spear"),
    "hammer_void_haft": (build_hammer_haft, "weapon.hammer"), "hammer_void_head": (build_hammer_head, "weapon.hammer"),
    "hammer_void_lava": (build_hammer_lava, "weapon.hammer"), "hammer_void_rock": (build_hammer_rock, "weapon.hammer"),
}
WEAPON_COLOR = {"haft": (0.62, 0.3, 1.0), "blade": (0.15, 0.06, 0.3), "edge": (0.72, 1.0, 0.14), "core": (0.72, 1.0, 0.14),
                "collar": (0.15, 0.06, 0.3), "ice": (0.6, 0.9, 1.0), "head": (0.15, 0.06, 0.3), "lava": (1.0, 0.5, 0.1),
                "rock": (0.5, 0.25, 0.8)}
wpn = {}
wpn_tris = {}
for wname, (fn, bone) in WEAPON_PARTS.items():
    budget = {"haft": 320, "blade": 600, "edge": 260, "core": 120, "collar": 200, "ice": 460, "head": 520, "lava": 300, "rock": 260}
    ob = part_object("w_" + wname, fn, voxel=0.01, smooth=2, target=budget[wname.split("_")[-1]])
    me = ob.data
    me.calc_loop_triangles()
    P = np.array([(v.co.x, v.co.z, -v.co.y) for v in me.vertices], np.float32)
    N = np.array([(v.normal.x, v.normal.z, -v.normal.y) for v in me.vertices], np.float32)
    idx = np.array([lt.vertices[:] for lt in me.loop_triangles], np.uint32)
    nv = len(P)
    wpn[wname + "|pos"] = P
    wpn[wname + "|nrm"] = N
    wpn[wname + "|uv"] = np.zeros((nv, 2), np.float32)
    wpn[wname + "|joints"] = np.array([[bone] * 4] * nv)
    wpn[wname + "|weights"] = np.tile(np.array([1, 0, 0, 0], np.float32), (nv, 1))
    wpn[wname + "|idx"] = idx
    wpn_tris[wname] = len(idx)
    ob.parent = ARM
    ob.matrix_parent_inverse = ARM.matrix_world.inverted()
    g = ob.vertex_groups.new(name=bone)
    g.add(list(range(nv)), 1.0, "REPLACE")
    m = ob.modifiers.new("arm", "ARMATURE")
    m.object = ARM
    col = me.color_attributes.new("col", "BYTE_COLOR", "CORNER")
    c = WEAPON_COLOR[wname.split("_")[-1]]
    for li in range(len(me.loops)):
        col.data[li].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1.0)
    ob.hide_render = True
np.savez(os.path.join(OUT, "weapons.npz"), **wpn)
print("[hero_v2] weapons %d tris %s" % (sum(wpn_tris.values()), wpn_tris))


# ---------------------------------------------------------------- export arrays (glTF space)
JOINTS = None  # joint order of the GLB's skin, read by glb_swap.py from the GLB itself; here names
pos_all, nrm_all, uv_all, jn_all, jw_all, idx_all = [], [], [], [], [], []
tri_counts = {}
base = 0
for part, ob in parts.items():
    me = ob.data
    me.calc_loop_triangles()
    names, W = weights_for(part, ob)
    # keep four, by name
    vreg = {}
    keymap = {}
    P, N, U, J, WW = [], [], [], [], []
    corner_n = [Vector(cn.vector) for cn in me.corner_normals] if hasattr(me, "corner_normals") else None
    tri_list = []
    for lt in me.loop_triangles:
        poly = me.polygons[lt.polygon_index]
        reg = region_of(part, sum((me.vertices[v].co for v in lt.vertices), Vector()) / 3)
        tri = []
        for li, vi in zip(lt.loops, lt.vertices):
            key = (vi, reg)
            if key not in keymap:
                keymap[key] = len(P)
                co = me.vertices[vi].co
                n = me.vertices[vi].normal
                P.append((co.x, co.z, -co.y))
                N.append((n.x, n.z, -n.y))
                U.append(region_uv(reg))
                order = list(np.argsort(-W[vi])[:4])
                w = list(W[vi][order] / W[vi][order].sum())
                while len(order) < 4:
                    order.append(order[0])
                    w.append(0.0)
                J.append([names[k] if w[i] > 0 else names[order[0]] for i, k in enumerate(order)])
                WW.append(w)
            tri.append(keymap[key] + base)
        tri_list.append(tri)
    pos_all += P; nrm_all += N; uv_all += U; jn_all += J; jw_all += WW
    idx_all += tri_list
    tri_counts[part] = len(tri_list)
    base += len(P)
    # vertex groups too, for Blender looks
    for k, n in enumerate(names):
        g = ob.vertex_groups.new(name=n)
        for i in range(len(me.vertices)):
            if W[i][k] > 1e-4:
                g.add([i], float(W[i][k]), "REPLACE")
    ob.parent = ARM
    ob.matrix_parent_inverse = ARM.matrix_world.inverted()
    m = ob.modifiers.new("arm", "ARMATURE")
    m.object = ARM
    # paint for renders
    mat = bpy.data.materials.new(part)
    ob.data.materials.append(mat)
    col = me.color_attributes.new("col", "BYTE_COLOR", "CORNER")
    for lt in me.loop_triangles:
        reg = region_of(part, sum((me.vertices[v].co for v in lt.vertices), Vector()) / 3)
        c = PALETTE[reg]
        for li in lt.loops:
            col.data[li].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1.0)

all_names = sorted({n for J in jn_all for n in J})
np.savez(os.path.join(OUT, "body.npz"), pos=np.array(pos_all, np.float32), nrm=np.array(nrm_all, np.float32),
         uv=np.array(uv_all, np.float32), joints=np.array(jn_all), weights=np.array(jw_all, np.float32),
         idx=np.array(idx_all, np.uint32))
# palette texture
img = np.zeros((GRID * SW, GRID * SW, 3), np.uint8)
for k, r in enumerate(REGIONS):
    x, y = (k % GRID) * SW, (k // GRID) * SW
    img[y:y + SW, x:x + SW] = (np.array(PALETTE[r]) * 255 + 0.5).astype(np.uint8)
np.save(os.path.join(OUT, "palette.npy"), img)
# The face anchors for heretic_rig.gd: points on the face plate's surface (plus a lift) with the surface
# normal there, in Godot skeleton space (glTF axes over the Armature node's scale).
K = ARM.scale.x
FACE_U = (FACE_ROT @ Vector((1, 0, 0))).normalized()
EYE_AT = [(-0.1, 0.035), (0.1, 0.035)]   # (across, up) on the plate, m: his right eye first (screen left)
GRIN_AT = (0.0, -0.085)
FACE_LIFT = 0.007


def face_point(x, z):
    a, b, c = FACE_R
    yy = b * math.sqrt(max(1e-6, 1 - (x / a) ** 2 - (z / c) ** 2))
    local = Vector((x, -yy, z))               # face-local: -y out of the face
    n = Vector((x / a ** 2, -yy / b ** 2, z / c ** 2)).normalized()
    p = FACE_C + FACE_ROT @ local
    nn = (FACE_ROT @ n).normalized()
    return p + nn * FACE_LIFT, nn


def godot(v, scale=True):
    k = K if scale else 1.0
    return "Vector3(%.4f, %.4f, %.4f)" % (v.x / k, v.z / k, -v.y / k)


with open(os.path.join(OUT, "face.txt"), "w") as f:
    for nm, (x, z) in (("eye_r", EYE_AT[0]), ("eye_l", EYE_AT[1]), ("grin", GRIN_AT)):
        p, n = face_point(x, z)
        f.write("%s %s %s\n" % (nm, godot(p), godot(n, False)))
    f.write("up %s\nright %s\n" % (godot(FACE_UP, False), godot(-FACE_U, False)))
print("[hero_v2] variant %s tris %d %s" % (VARIANT, len(idx_all), tri_counts))
print("[hero_v2] verts %d bones %d" % (len(pos_all), len(all_names)))
top = max(p[1] for p in pos_all)
print("[hero_v2] height %.3f m" % top)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "hero_v2.blend"))

if RENDER:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "VERTEX"
    sc.display.shading.show_object_outline = True
    sc.render.resolution_x, sc.render.resolution_y = 400, 520
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.12, 0.12, 0.2)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.7
    views = {"front": (0, -1, 0), "side": (1, 0, 0), "game": (0, -math.cos(math.radians(54)), math.sin(math.radians(54))), "back": (0, 1, 0),
             "gameback": (0.3, math.cos(math.radians(54)), math.sin(math.radians(54)))}
    poses = ["rest"] + [p for p in (argv[4].split(",") if len(argv) > 4 else ["Idle:0", "Ab_L1:11", "Ab_GR:7", "Run_F:4", "Ab_L2:12", "Ab_L3:24"])]
    for pose in poses:
        if pose != "rest":
            a, fr = pose.split(":")
            ARM.animation_data_create()
            ARM.animation_data.action = bpy.data.actions[a]
            sc.frame_set(int(fr))
        form = {"Ab_L1": "axe", "Ab_L2": "spear", "Ab_L3": "hammer"}.get(pose.split(":")[0], "")
        for o in bpy.data.objects:
            if o.name.startswith("w_"):
                o.hide_render = not (form and o.name.startswith("w_" + form))
        for vn, d in views.items():
            if pose != "rest" and vn in ("back",):
                continue
            d = Vector(d).normalized()
            tgt = Vector((0, 0, 0.95))
            cam.location = tgt + d * 6
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = os.path.join(OUT, "r_%s_%s.png" % (pose.replace(":", "_"), vn))
            bpy.ops.render.render(write_still=True)
