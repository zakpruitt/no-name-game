"""The heretic hero, v3: the Meshy v3 model (docs/characters/heretic.md) fitted onto the existing hero rig.

    blender -b --factory-startup -P tools/hero_build/hero_v3.py -- <rig.glb> <meshy.glb> <out_dir> [render] [poses] [parts|fit|tips]

<rig.glb> is the committed hero GLB (assets/comic/heretic_chibi.glb): only its armature is read, at rest, which is
also the bind pose (joint world x IBM = identity), so the body is fitted in rest-pose world space round the bones
and every clip, contact frame and bone lookup in the game keeps working. <meshy.glb> is the Meshy Image-to-3D
result (one textured shell + loose chain links). Writes <out_dir>/body.npz (glTF-space arrays for glb_swap.py),
<out_dir>/texture.png (the edited Meshy texture), <out_dir>/face.txt (the face frame for heretic_rig.gd FACE),
<out_dir>/hero_v3.blend and, with `render`, workbench views of the rest pose and a few clip frames.

The steps (each a section below):
1. the rig at rest; 2. the Meshy mesh welded, mirrored (the tentacle arm onto his right, hand.r) and normalised;
3. parts by texture colour and connectivity (head, scarf, tentacle, left arm, chain links, body); 4. the body warp:
a uniform scale with a piecewise height map so belt, shoulders and the hood's hem land on the rig's hips, shoulders
and head joint, the head group scaled about the neck to HEAD_PCT of his height; 5. the arms: the tentacle's trunk
and five tips traced along the surface, each bone mapped from its traced segment onto the rig's rest bone and the
mesh deformed by those maps (linear blend, the weights the final skin uses); the left arm the same way; 6. skin
weights; 7. the face plate (the painted face flattened onto a plate tipped up to the game camera, its painted eyes
blacked out: the game's eye and grin decals lie on it); 8. texture edits (crimson horn tips, cooler hood).

Blender axes: z up, he faces -y, his right hand is -x. glTF = (x, z, -y).
"""
import bpy, bmesh, sys, math, os, colorsys, heapq
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
RIG_GLB, MESHY_GLB, OUT = argv[0], argv[1], argv[2]
RENDER = "render" in argv[3:]
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- settings for this model (v3, task 01a1ba0d)
# Normalised v3 space: welded, mirrored in x, x centred on the hood's crown, y on the torso, feet at z 0, Meshy units
# (he is 0.952 tall). Heights below are read off the colour-class renders (probe/cls_grid.png).
ZN_NECK = 0.60        # the hood's hem: the head group's pivot height, mapped onto the rig's head joint
ZN_BELT = 0.33        # middle of the belt
ZN_SHOULDER = 0.45    # where the left sleeve and the trunk leave the torso, under the scarf
ZN_BOOT = 0.17        # top of the boots
# Rig heights they land on (rest, m). The rig's hips (0.68) and shoulders (0.92) sit far higher on its body than
# v3's belt and shoulders on v3: the clips were keyed for a long-legged rig, so the lower body stretches a little and
# the scarf squashes; the head keeps its scale. Hips 4 cm over the belt keeps the tunic from becoming a dress.
Z_RIG = {"boot": 0.28, "belt": 0.62, "shoulder": 0.84, "neck": None}  # neck: the head joint's height
HEAD_PCT = float(os.environ.get("HERO_HEAD_PCT", "0.365"))  # neck joint to crown, of his crown height
X_RIG = 0.02          # the body's centre line in x
Y_RIG = [(0.0, 0.17), (0.62, 0.17), (0.84, 0.11), (1.0, 0.06)]  # rig z -> where the body's middle sits in y
TINT = os.environ.get("HERO_V3_TINT", "1") == "1"  # the two texture edits (section 8)


def log(*a):
    print("[hero_v3]", *a)


# ---------------------------------------------------------------- 1. the rig at rest
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
B = {b.name: (np.array(MW @ b.head_local), np.array(MW @ b.tail_local)) for b in ARM.data.bones}


def H(n):
    return B[n][0].copy()


def T(n):
    return B[n][1].copy()


def chain(prefix):
    out, i = [], 1
    while "%s.%02d" % (prefix, i) in B:
        out.append("%s.%02d" % (prefix, i))
        i += 1
    return out


Z_RIG["neck"] = float(H("head")[2])

# ---------------------------------------------------------------- 2. the Meshy mesh
bpy.ops.import_scene.gltf(filepath=MESHY_GLB)
src = [o for o in bpy.data.objects if o.type == "MESH"]
for o in src:
    o.select_set(True)
bpy.context.view_layer.objects.active = src[0]
if len(src) > 1:
    bpy.ops.object.join()
OB = bpy.context.view_layer.objects.active
OB.name = "heretic_v3"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ME = OB.data
bm = bmesh.new()
bm.from_mesh(ME)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)  # Meshy splits at UV seams; loops keep their UVs
for v in bm.verts:
    v.co.x = -v.co.x  # the concept's tentacle came out on his left: mirror it onto hand.r
bmesh.ops.reverse_faces(bm, faces=bm.faces)
bm.to_mesh(ME)
bm.free()
NV = len(ME.vertices)
CO = np.zeros(NV * 3)
ME.vertices.foreach_get("co", CO)
CO = CO.reshape(-1, 3)
CO[:, 2] -= CO[:, 2].min()
EDGES = np.zeros(len(ME.edges) * 2, int)
ME.edges.foreach_get("vertices", EDGES)
EDGES = EDGES.reshape(-1, 2)
ADJ = [[] for _ in range(NV)]
for a, b in EDGES:
    ADJ[a].append(b)
    ADJ[b].append(a)

# per-vertex texture colour (the mean over its loops), as HSV
IMG = next(n.image for n in OB.material_slots[0].material.node_tree.nodes if n.type == "TEX_IMAGE")
TW_, TH_ = IMG.size
PX = np.array(IMG.pixels[:], np.float32).reshape(TH_, TW_, 4)[:, :, :3].copy()
NL = len(ME.loops)
LUV = np.zeros(NL * 2)
ME.uv_layers[0].data.foreach_get("uv", LUV)
LUV = LUV.reshape(-1, 2)
LV = np.zeros(NL, int)
ME.loops.foreach_get("vertex_index", LV)
_lc = PX[np.clip((LUV[:, 1] * TH_).astype(int), 0, TH_ - 1), np.clip((LUV[:, 0] * TW_).astype(int), 0, TW_ - 1)]
_vc = np.zeros((NV, 3))
_cnt = np.zeros(NV)
np.add.at(_vc, LV, _lc)
np.add.at(_cnt, LV, 1)
_vc /= np.maximum(_cnt, 1)[:, None]
_srgb = np.where(_vc <= 0.0031308, _vc * 12.92, 1.055 * np.power(np.maximum(_vc, 0), 1 / 2.4) - 0.055)
HSV = np.array([colorsys.rgb_to_hsv(*c) for c in _srgb])
Hh, Ss, Vv = HSV.T
CLS = np.full(NV, "dark", object)
CLS[(Ss < .3) & (Vv > .72)] = "hood"
CLS[(Ss < .3) & (Vv > .3) & (Vv <= .72)] = "grey"
CLS[(Hh > .55) & (Hh < .7) & (Ss >= .12) & (Ss < .5) & (Vv > .42)] = "slate"
CLS[((Hh > .92) | (Hh < .04)) & (Ss > .45) & (Vv > .25)] = "crimson"
CLS[(Hh > .74) & (Hh < .93) & (Ss > .3) & (Vv > .3)] = "magenta"
CLS[(Hh > .42) & (Hh < .56) & (Ss > .4) & (Vv > .5)] = "cyan"
CLS[Vv < .1] = "black"

# centre: x on the hood's crown, y on the torso
_crown = (CLS == "hood") & (CO[:, 2] > 0.85)
CO[:, 0] -= np.median(CO[_crown, 0])
_torso = (CO[:, 2] > ZN_BELT) & (CO[:, 2] < ZN_SHOULDER) & (np.abs(CO[:, 0]) < 0.1) & (CLS != "magenta")
CO[:, 1] -= 0.5 * (CO[_torso, 1].min() + CO[_torso, 1].max())
log("v3 welded verts %d, height %.3f, x %.3f..%.3f" % (NV, CO[:, 2].max(), CO[:, 0].min(), CO[:, 0].max()))


# ---------------------------------------------------------------- 3. parts
def components(mask):
    seen = np.zeros(NV, bool)
    out = []
    for s in np.where(mask)[0]:
        if seen[s]:
            continue
        st, c = [s], []
        seen[s] = True
        while st:
            a = st.pop()
            c.append(a)
            for b in ADJ[a]:
                if mask[b] and not seen[b]:
                    seen[b] = True
                    st.append(b)
        out.append(c)
    return out


def flood(seeds, mask):
    out = np.zeros(NV, bool)
    st = [s for s in seeds if mask[s]]
    out[st] = True
    while st:
        a = st.pop()
        for b in ADJ[a]:
            if mask[b] and not out[b]:
                out[b] = True
                st.append(b)
    return out


def grow(mask, allowed, n=1):
    m = mask.copy()
    for _ in range(n):
        add = [b for a in np.where(m)[0] for b in ADJ[a] if allowed[b] and not m[b]]
        m[add] = True
    return m


ALL = np.ones(NV, bool)
_comps = components(ALL)
_comps.sort(key=len, reverse=True)
LINKS = np.zeros(NV, bool)
for c in _comps[1:]:
    LINKS[c] = True
SHELL = ~LINKS
log("shell %d verts, %d loose islands (%d verts)" % (SHELL.sum(), len(_comps) - 1, LINKS.sum()))
X, Y, Z = CO.T

# tentacle: the biggest magenta region on his right, colour holes closed, then the deep cuff round its root
_mag = SHELL & (CLS == "magenta") & (X < -0.06)
TENT = np.zeros(NV, bool)
TENT[max(components(_mag), key=len)] = True
TENT = grow(TENT, SHELL & (X < -0.07) & (Z > 0.12) & (Z < 0.56) & (CLS != "crimson"), 2)
TENT[max(components(TENT), key=len)] = True
# head group: everything off the shell above the hood's hem that isn't scarf, and what hangs off it (horn curls)
_above = SHELL & (Z > ZN_NECK - 0.012) & (CLS != "crimson") & ~TENT
HEAD = flood(np.where(_above)[0], SHELL & (Z > ZN_NECK - 0.08) & (CLS != "crimson") & ~TENT)
# left arm: from the glove up, over what lies out past his left side
_gl = np.where(SHELL & (X > 0.2) & (Z > 0.17) & (Z < 0.3))[0]
LARM = flood(_gl, SHELL & (X > 0.12) & (Z > 0.12) & ((Z > 0.3) | (X > 0.19)) & (Z < ZN_SHOULDER + 0.06) & ~HEAD & ~TENT & (CLS != "crimson"))
SCARF = SHELL & ~HEAD & ~TENT & ~LARM & (CLS == "crimson")
SCARF = grow(SCARF, SHELL & ~HEAD & ~TENT & ~LARM & (Z > ZN_SHOULDER - 0.02), 1)
BODY = SHELL & ~HEAD & ~TENT & ~LARM & ~SCARF
PART = np.full(NV, "body", object)
PART[SCARF] = "scarf"
PART[HEAD] = "head"
PART[LARM] = "arm_l"
PART[TENT] = "tent"
PART[LINKS] = "links"
for p in ("head", "scarf", "tent", "arm_l", "links", "body"):
    m = PART == p
    log("part %-6s %5d verts  z %.3f..%.3f  x %.3f..%.3f" % (p, m.sum(), Z[m].min(), Z[m].max(), X[m].min(), X[m].max()))




# ---------------------------------------------------------------- 4. the body warp and the head
CROWN = Z_RIG["neck"] / (1.0 - HEAD_PCT)                 # the hood's crown in rest, m
S = (CROWN - Z_RIG["neck"]) / (Z.max() - ZN_NECK)      # the head's scale, and the body's across
ZN_KEYS = [0.0, ZN_BOOT, ZN_BELT, ZN_SHOULDER, ZN_NECK]
ZR_KEYS = [0.0, Z_RIG["boot"], Z_RIG["belt"], Z_RIG["shoulder"], Z_RIG["neck"]]
log("crown %.3f m, scale %.3f (head %.0f%% of his height)" % (CROWN, S, 100 * HEAD_PCT))


def z_map(z):
    z = np.asarray(z, float)
    out = np.interp(z, ZN_KEYS, ZR_KEYS)
    return np.where(z > ZN_NECK, Z_RIG["neck"] + (z - ZN_NECK) * S, out)


def y_mid(zr):
    return np.interp(zr, [k for k, _ in Y_RIG], [v for _, v in Y_RIG])


Y_HEAD = float(y_mid(Z_RIG["neck"]))


def body_warp(p):
    """v3 point(s) -> rest pose (m): uniform across, heights through the landmark map."""
    p = np.atleast_2d(p)
    zr = z_map(p[:, 2])
    return np.stack([X_RIG + S * p[:, 0], y_mid(zr) + S * p[:, 1], zr], 1)


def head_map(p):
    """The head group: one scale about the neck (the hood's hem), so it keeps its shape."""
    p = np.atleast_2d(p)
    return np.stack([X_RIG + S * p[:, 0], Y_HEAD + S * p[:, 1], Z_RIG["neck"] + S * (p[:, 2] - ZN_NECK)], 1)


FIT = body_warp(CO)
FIT[HEAD] = head_map(CO[HEAD])


# ---------------------------------------------------------------- 5. the arms: traced in v3, mapped bone by bone
def dijkstra(srcs, mask):
    dist = np.full(NV, np.inf)
    pred = np.full(NV, -1)
    pq = []
    for i in srcs:
        dist[i] = 0.0
        pq.append((0.0, int(i)))
    heapq.heapify(pq)
    while pq:
        d, a = heapq.heappop(pq)
        if d > dist[a]:
            continue
        for b in ADJ[a]:
            if mask[b]:
                nd = d + np.linalg.norm(CO[a] - CO[b])
                if nd < dist[b]:
                    dist[b] = nd
                    pred[b] = a
                    heapq.heappush(pq, (nd, b))
    return dist, pred


def path_to(v, pred):
    out = []
    while v >= 0:
        out.append(int(v))
        v = pred[v]
    return out[::-1]


def arc(pts):
    return np.r_[0.0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]


def at_arc(pts, s):
    """Point at arc length s along a polyline, extrapolated past either end."""
    a = arc(pts)
    if s <= 0:
        d = pts[1] - pts[0]
        return pts[0] + d / np.linalg.norm(d) * s
    if s >= a[-1]:
        d = pts[-1] - pts[-2]
        return pts[-1] + d / np.linalg.norm(d) * (s - a[-1])
    return np.array([np.interp(s, a, pts[:, k]) for k in range(3)])


def smooth_line(pts, n=4):
    pts = pts.copy()
    for _ in range(n):
        pts[1:-1] = (pts[:-2] + 2 * pts[1:-1] + pts[2:]) / 4
    return pts


def centred(path, mask, r):
    q = CO[mask]
    return np.array([q[np.linalg.norm(q - CO[v], axis=1) < r].mean(0) for v in path])


# the tentacle: surface distance from the ring where it leaves the body
RING = np.array([a for a in np.where(TENT)[0] if any(SHELL[b] and not TENT[b] for b in ADJ[a])])
_rm = np.zeros(NV, bool)
_rm[RING] = True
for c in components(_rm):
    log("ring patch %d verts at %s" % (len(c), np.round(CO[c].mean(0), 3)))
DT, PRED = dijkstra(RING, TENT)
RING_C = CO[RING].mean(0)
# tips: local maxima of that distance, one per branch (a candidate whose path joins a kept one less than BR_MIN
# from its own end is a bump on that branch)
BR_MIN = 0.05
_tv = np.where(TENT & np.isfinite(DT))[0]
_cand = [v for v in _tv if all(DT[v] >= DT[b] for b in ADJ[v] if TENT[b])]
_cand.sort(key=lambda v: -DT[v])
_tips, _paths = [], []
for c in _cand:
    p = path_to(c, PRED)
    br = DT[c]
    for q in _paths:
        on = set(q)
        j = next((k for k in range(len(p) - 1, -1, -1) if p[k] in on), 0)
        br = min(br, DT[c] - DT[p[j]], np.linalg.norm(CO[q] - CO[c], axis=1).min())   # a bump lies close to a kept tip
    if br >= BR_MIN:
        _tips.append((br, c, p))
        _paths.append(p)
_tips.sort(key=lambda t: -t[0])
log("tentacle %d verts, ring %d, %d tip candidates, branches %s" % (TENT.sum(), len(RING), len(_cand), ["%.3f" % t[0] for t in _tips]))
_tips = _tips[:5]
assert len(_tips) == 5, "expected five tentacle tips"
TIP_PATHS = [t[2] for t in _tips]
for k, t in enumerate(_tips):
    log("tip %d end %s branch %.3f dist %.3f" % (k, np.round(CO[t[1]], 3), t[0], DT[t[1]]))
TIP_LINES = [smooth_line(np.vstack([RING_C, centred(p, TENT, 0.035)])) for p in TIP_PATHS]
for L, p in zip(TIP_LINES, TIP_PATHS):
    L[-1] = CO[p[-1]]
# the trunk: the surface-distance bands from the ring stay one connected loop until the tips part
BAND = 0.04
_d = 0.0
TRUNK_PTS = []
while _d < DT[np.isfinite(DT)].max():
    band = TENT & (DT >= _d) & (DT < _d + BAND)
    comps = [c for c in components(band) if len(c) >= 6]
    if len(comps) != 1:
        break
    TRUNK_PTS.append(CO[comps[0]].mean(0))
    _d += 0.005
SPLIT_S = _d
log("bands stay whole to %.3f from the ring" % SPLIT_S)
TRUNK = smooth_line(np.array([RING_C] + TRUNK_PTS), 2)
log("trunk %.3f long (v3 units), split at (%.3f %.3f %.3f)" % (arc(TRUNK)[-1], *TRUNK[-1]))
# each tip from the split on
TIP_SRC = []
for L in TIP_LINES:
    a = arc(L)
    k = int(np.argmin(np.linalg.norm(L - TRUNK[-1], axis=1)))
    TIP_SRC.append(np.vstack([TRUNK[-1], L[k + 1:]]))

RIG_TIPS = ["main", "up", "out", "mid", "low"]  # five tips, five chains (tent.back, the chibi's sixth claw, carries nothing)


def rot_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        if c > 0:
            return np.eye(3)
        p = np.cross(a, [1, 0, 0])
        if np.linalg.norm(p) < 1e-6:
            p = np.cross(a, [0, 1, 0])
        p /= np.linalg.norm(p)
        return 2 * np.outer(p, p) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


class SegMap:
    """A source segment (p0, p1) onto a target (q0, q1): turned (shortest arc), stretched along it by the length
    ratio and across it by `across` (m per v3 unit), so a tube keeps its thickness when its length changes."""

    def __init__(self, p0, p1, q0, q1, across=None):
        self.p0, self.q0 = np.array(p0, float), np.array(q0, float)
        ds, dr = np.array(p1) - p0, np.array(q1) - q0
        self.R = rot_between(ds, dr)
        along = np.linalg.norm(dr) / max(np.linalg.norm(ds), 1e-9)
        across = along if across is None else across
        u = ds / np.linalg.norm(ds)
        self.A = self.R @ (across * np.eye(3) + (along - across) * np.outer(u, u))

    def __call__(self, p):
        return (np.atleast_2d(p) - self.p0) @ self.A.T + self.q0


ARM_R = ["upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]
# trunk: its root lands where the body warp puts the ring, projected on upperarm.r; the rest of the arm's length
# carries it to hand.r's tail
_ua0, _ua1 = H("upperarm.r"), T("upperarm.r")
_rw = body_warp(RING_C)[0]
_u = (_ua1 - _ua0) / np.linalg.norm(_ua1 - _ua0)
A0 = float(np.clip(np.dot(_rw - _ua0, _u), 0.08, 0.3))
ARM_T = np.array([H("upperarm.r"), T("upperarm.r"), T("lowerarm.r"), T("wrist.r"), T("hand.r")])
ARM_A = arc(ARM_T)
_k = arc(TRUNK)[-1] / (ARM_A[-1] - A0)   # v3 units per rig metre along the trunk
TRUNK_ACROSS = S                         # the trunk keeps its girth
TIP_ACROSS = S * float(os.environ.get("HERO_V3_TIP_GIRTH", "1.4"))   # the concept's tips are chunky: 1.0 read thin at the game camera
SEGS = {}   # bone -> (SegMap, source segment p0, p1)
for i, b in enumerate(ARM_R):
    p0 = at_arc(TRUNK, (ARM_A[i] - A0) * _k)
    p1 = at_arc(TRUNK, (ARM_A[i + 1] - A0) * _k)
    SEGS[b] = (SegMap(p0, p1, ARM_T[i], ARM_T[i + 1], TRUNK_ACROSS), p0, p1)
log("trunk root lands %.2f m down upperarm.r; trunk stretched x%.2f" % (A0, 1 / _k / S))
# Which tip is which rig chain: the assignment whose directions (from the split, turned by the trunk's own map onto
# the rig arm) best match the chains' (from hand.r's tail to each chain's end).
_trunk_R = SEGS["hand.r"][0].R
_best = None
import itertools
for perm in itertools.permutations(range(5)):
    cost = 0.0
    for name, k in zip(RIG_TIPS, perm):
        ds = _trunk_R @ (TIP_SRC[k][-1] - TIP_SRC[k][0])
        bones = chain("tent." + name)
        dr = T(bones[-1]) - T("hand.r")
        cost += 1 - np.dot(ds, dr) / np.linalg.norm(ds) / np.linalg.norm(dr)
    if _best is None or cost < _best[0]:
        _best = (cost, perm)
TIP_OF = {name: k for name, k in zip(RIG_TIPS, _best[1])}
log("tips -> chains %s (cost %.2f)" % (TIP_OF, _best[0]))
# The rig's claw chains were placed for the chibi's big palm and long claws (0.6-0.9 m from hand.r's tail, up to
# 0.3 m of palm before the first joint). v3's tips are 0.2-0.4 m. No clip keys a translation on any tent.* bone
# (only rotations), so the chains' rest positions can move without touching a clip: each chain's root is pulled
# PALM_K of the way in to hand.r's tail and the chain is scaled (same directions, so the keyed curls keep their
# shape) to the tip's own length x TIP_STRETCH. glb_swap.py writes the new rest (node translations and inverse
# bind matrices) from <out>/bones.json.
PALM_K = float(os.environ.get("HERO_V3_PALM", "0.3"))
TIP_STRETCH = float(os.environ.get("HERO_V3_TIP_STRETCH", "1.15"))
NEW_REST = {}   # bone -> new head (Blender world, m); tails follow the chain
for name, k in TIP_OF.items():
    bones = chain("tent." + name)
    old = np.array([H(bones[0])] + [T(b) for b in bones])
    src = TIP_SRC[k]
    ls = arc(src)[-1]
    root = T("hand.r") + PALM_K * (old[0] - T("hand.r"))
    want = max(0.12, ls * S * TIP_STRETCH - np.linalg.norm(root - T("hand.r")))
    kc = want / arc(old)[-1]
    new = root + (old - old[0]) * kc
    for j, b in enumerate(bones):
        NEW_REST[b] = new[j]
    tgt = np.vstack([T("hand.r"), new[1:]])   # the first bone also bridges what is left of the palm
    lt = arc(tgt)
    for j, b in enumerate(bones):
        p0 = at_arc(src, lt[j] / lt[-1] * ls)
        p1 = at_arc(src, lt[j + 1] / lt[-1] * ls)
        SEGS[b] = (SegMap(p0, p1, tgt[j], tgt[j + 1], TIP_ACROSS), p0, p1)
    log("tip %-4s src %.3f (v3) = %.3f m -> chain %.3f m (was %.3f), root %.3f m off the hand (was %.3f)" % (
        name, ls, ls * S, lt[-1], arc(old)[-1] + np.linalg.norm(old[0] - T("hand.r")), np.linalg.norm(root - T("hand.r")),
        np.linalg.norm(old[0] - T("hand.r"))))
NEW_TAIL = {}
for name in RIG_TIPS:
    bones = chain("tent." + name)
    for j, b in enumerate(bones):
        NEW_TAIL[b] = NEW_REST[bones[j + 1]] if j + 1 < len(bones) else None
for name, k in TIP_OF.items():
    bones = chain("tent." + name)
    last = bones[-1]
    NEW_TAIL[last] = NEW_REST[last] + (T(last) - H(last)) * (np.linalg.norm(NEW_REST[bones[1]] - NEW_REST[bones[0]]) / np.linalg.norm(T(bones[0]) - H(bones[0])))


def NH(n):
    return NEW_REST[n].copy() if n in NEW_REST else H(n)


def NT(n):
    return NEW_TAIL[n].copy() if n in NEW_TAIL else T(n)


# the left arm: shoulder ring, the shackle (wrist), the glove
LRING = np.array([a for a in np.where(LARM)[0] if any(SHELL[b] and not LARM[b] for b in ADJ[a])])
_shackle = LARM & (CLS == "grey")
_glove = LARM & (Z < CO[_shackle, 2].min()) & ~_shackle
L_SH = CO[LRING][CO[LRING, 2] > CO[LRING, 2].max() - 0.05].mean(0)
L_WR = CO[_shackle].mean(0)
L_GL = CO[_glove].mean(0)
L_END = CO[_glove][np.argmin(CO[_glove, 2])]
L_EL = (L_SH + L_WR) / 2
_lsrc = [L_SH, L_EL, L_WR, L_WR + (L_GL - L_WR) * 0.3, L_GL + (L_END - L_GL) * 0.6]
_ltgt = [H("upperarm.l"), T("upperarm.l"), T("lowerarm.l"), T("wrist.l"), T("hand.l")]
ARM_L = ["upperarm.l", "lowerarm.l", "wrist.l", "hand.l"]
for i, b in enumerate(ARM_L):
    SEGS[b] = (SegMap(_lsrc[i], _lsrc[i + 1], _ltgt[i], _ltgt[i + 1], S), _lsrc[i], _lsrc[i + 1])
log("left arm: shoulder %s wrist %s glove %s" % (np.round(L_SH, 3), np.round(L_WR, 3), np.round(L_GL, 3)))


# Weights on the arms (v3 space): the root ring blends into the body ("body": the body warp at fit time,
# shoulder.<side> in the skin); trunk and sleeve by where they project on their centre line; tips by surface
# distance from their own path, so a tip never takes weight from a neighbour across a gap.
def seg_param(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return t, np.linalg.norm(a + np.outer(t, ab) - p, axis=1)


def chain_weights(verts, names, mask, seeds, blend):
    """Surface-distance weights: per bone, distance from its seed set; exp falloff over `blend`."""
    D = np.full((len(verts), len(names)), np.inf)
    for j, n in enumerate(names):
        if len(seeds[n]):
            d, _ = dijkstra(list(seeds[n]), mask)
            D[:, j] = d[verts]
    dmin = D.min(1, keepdims=True)
    Wt = np.exp(-(D - dmin) / blend)
    Wt[~np.isfinite(D) | (D - dmin > blend * 4)] = 0
    return Wt / np.maximum(Wt.sum(1, keepdims=True), 1e-9)


TENT_V = np.where(TENT)[0]
TENT_NAMES = ["body"] + ARM_R + [b for n in RIG_TIPS for b in chain("tent." + n)]
_seeds = {n: set() for n in TENT_NAMES}
_seeds["body"] = set(RING.tolist())
# trunk bones: trunk vertices by their projection on the trunk line
_ta = arc(TRUNK)
_proj = np.zeros(NV)
_pd = np.full(NV, np.inf)
for i in range(len(TRUNK) - 1):
    t, d = seg_param(CO, TRUNK[i], TRUNK[i + 1])
    better = d < _pd
    _pd[better] = d[better]
    _proj[better] = _ta[i] + t[better] * (_ta[i + 1] - _ta[i])
_trunk_v = TENT & (DT < SPLIT_S - 0.01) & (_pd < 0.07)
for i, b in enumerate(ARM_R):
    s0, s1 = (ARM_A[i] - A0) * _k, (ARM_A[i + 1] - A0) * _k
    _seeds[b] = set(np.where(_trunk_v & (_proj >= s0) & (_proj < s1) & (DT > 0.015))[0].tolist())
for name, k in TIP_OF.items():
    p = TIP_PATHS[k]
    bones = chain("tent." + name)
    src = TIP_SRC[k]
    tgt_a = arc(np.array([T("hand.r")] + [NT(b) for b in bones]))
    ls = arc(src)[-1]
    for v in p:
        if DT[v] < SPLIT_S:
            continue
        s_tip = (DT[v] - SPLIT_S) / max(DT[p[-1]] - SPLIT_S, 1e-6) * ls
        j = int(np.clip(np.searchsorted(tgt_a / tgt_a[-1] * ls, s_tip) - 1, 0, len(bones) - 1))
        _seeds[bones[j]].add(v)
for n in TENT_NAMES:
    if not _seeds[n] and n != "body":
        _, p0, p1 = SEGS[n]
        _seeds[n].add(int(TENT_V[np.argmin(np.linalg.norm(CO[TENT_V] - (p0 + p1) / 2, axis=1))]))
TENT_W = chain_weights(TENT_V, TENT_NAMES, TENT, _seeds, 0.018)

LARM_V = np.where(LARM | LINKS)[0]
LARM_NAMES = ["body"] + ARM_L
LARM_W = np.zeros((len(LARM_V), len(LARM_NAMES)))
_la = arc(np.array(_lsrc))
_lt, _ld = seg_param(CO[LARM_V], L_SH, _lsrc[-1])
_ls = _lt * np.linalg.norm(_lsrc[-1] - L_SH)
for j in range(1, 5):
    c = (_la[j - 1] + _la[j]) / 2
    LARM_W[:, j] = np.exp(-((_ls - c) / (0.5 * (_la[j] - _la[j - 1]) + 0.02)) ** 2)
LARM_W[:, 0] = np.exp(-(np.maximum(_ls, 0) / 0.025) ** 2)   # the root melts into the body
LARM_W[LINKS[LARM_V]] = [0, 0, 0, 0, 1]
LARM_W[_glove[LARM_V] & ~LINKS[LARM_V]] = [0, 0, 0, 0.15, 0.85]
LARM_W /= LARM_W.sum(1, keepdims=True)


def lbs(verts, names, Wt):
    out = np.zeros((len(verts), 3))
    for j, n in enumerate(names):
        w = Wt[:, j]
        on = w > 1e-6
        if not on.any():
            continue
        pts = CO[verts[on]]
        mapped = body_warp(pts) if n == "body" else SEGS[n][0](pts)
        out[on] += w[on, None] * mapped
    return out


FIT[TENT_V] = lbs(TENT_V, TENT_NAMES, TENT_W)
FIT[LARM_V] = lbs(LARM_V, LARM_NAMES, LARM_W)
log("fit: height %.3f m, x %.2f..%.2f, y %.2f..%.2f" % (FIT[:, 2].max(), FIT[:, 0].min(), FIT[:, 0].max(), FIT[:, 1].min(), FIT[:, 1].max()))
# ---------------------------------------------------------------- renders (workbench, for a quick look)
def setup_render(res=(420, 540), ortho=2.6):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_object_outline = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.12, 0.12, 0.2)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    return sc, cam


VIEWS = {"front": (0, -1, 0), "side": (-1, 0, 0), "back": (0, 1, 0),
         "game": (0, -math.cos(math.radians(53)), math.sin(math.radians(53))),
         "gameback": (0.3, math.cos(math.radians(53)), math.sin(math.radians(53)))}


def shoot(sc, cam, prefix, views=("front", "side", "game", "back"), tgt=(0, 0, 0.8)):
    for vn in views:
        d = Vector(VIEWS[vn]).normalized()
        cam.location = Vector(tgt) + d * 6
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (prefix, vn))
        bpy.ops.render.render(write_still=True)


def paint_points(colors):
    """Vertex colours on OB (debug), colors: (NV, 3) sRGB."""
    attr = ME.color_attributes.get("dbg") or ME.color_attributes.new("dbg", "BYTE_COLOR", "POINT")
    for i in range(NV):
        c = colors[i]
        attr.data[i].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1.0)
    ME.color_attributes.active_color = attr


PART_COL = {"head": (1, 1, .85), "scarf": (1, .1, .1), "tent": (1, 0, 1), "arm_l": (.2, .8, .2), "links": (1, .7, 0), "body": (.3, .4, .9)}
if "parts" in argv[3:]:
    for i in range(NV):
        ME.vertices[i].co = Vector(CO[i])
    paint_points([PART_COL[p] for p in PART])
    sc, cam = setup_render(ortho=1.1)
    sc.display.shading.color_type = "VERTEX"
    shoot(sc, cam, "parts", ("front", "side", "back"), tgt=(0, 0, 0.48))
    sys.exit(0)


# ---------------------------------------------------------------- look modes: `parts`, `fit`, `tips` (render, then stop)
if "fit" in argv[3:]:
    for i in range(NV):
        ME.vertices[i].co = Vector(FIT[i])
    sc, cam = setup_render(ortho=2.0)
    sc.display.shading.color_type = "TEXTURE"
    # bones as thin sticks
    for b in ARM.data.bones:
        h, t = NH(b.name), NT(b.name)
        if b.name.startswith(("skirt", "weapon", "handslot")):
            continue
        bm_ = bmesh.new()
        bmesh.ops.create_cone(bm_, cap_ends=True, segments=6, radius1=0.012, radius2=0.004, depth=float(np.linalg.norm(t - h)))
        me_ = bpy.data.meshes.new("b")
        bm_.to_mesh(me_)
        o = bpy.data.objects.new("bone_" + b.name, me_)
        sc.collection.objects.link(o)
        d = Vector(t - h).normalized()
        o.matrix_world = Matrix.Translation(Vector((h + t) / 2)) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        o.show_in_front = True
    shoot(sc, cam, "fit", ("front", "side", "game", "back"), tgt=(0, 0, 0.78))
    for o in list(bpy.data.objects):
        if o.name.startswith("bone_"):
            o.hide_render = True
    shoot(sc, cam, "fitnb", ("front", "side", "game", "back"), tgt=(0, 0, 0.78))
    sys.exit(0)


if "tips" in argv[3:]:
    for i in range(NV):
        ME.vertices[i].co = Vector(CO[i])
    CHAIN_COL = {"body": (.3, .3, .3), "upperarm.r": (1, 1, 1), "lowerarm.r": (.8, .8, .8), "wrist.r": (.6, .6, .6), "hand.r": (.4, .4, .4),
                 "main": (1, 0, 0), "up": (0, 1, 0), "out": (0, 0, 1), "mid": (1, 1, 0), "low": (0, 1, 1), "back": (1, 0, 1)}
    cols = np.tile([0.15, 0.15, 0.2], (NV, 1))
    dom = np.array(TENT_NAMES)[TENT_W.argmax(1)]
    for v, n in zip(TENT_V, dom):
        key = n if n in CHAIN_COL else n.split(".")[1]
        c = np.array(CHAIN_COL[key])
        if n.startswith("tent.") and int(n.split(".")[2]) % 2 == 0:
            c = c * 0.55
        cols[v] = c
    paint_points(cols)
    sc, cam = setup_render(ortho=0.6)
    sc.display.shading.color_type = "VERTEX"
    shoot(sc, cam, "tips", ("front", "side", "back"), tgt=(-0.28, 0, 0.36))
    sys.exit(0)


# ---------------------------------------------------------------- 6. skin weights (rest pose, the rig's bones)
DEFORM = [b.name for b in ARM.data.bones if b.use_deform or b.name.startswith(("tent.", "skirt.", "scarf."))]
BI = {n: i for i, n in enumerate(DEFORM)}
WT = np.zeros((NV, len(DEFORM)))


def seg_dist(p, n):
    return seg_param(p, NH(n), NT(n))[1]


def by_distance(verts, names, power, mask_fn=None):
    P = FIT[verts]
    D = np.stack([seg_dist(P, n) for n in names], 1)
    if mask_fn is not None:
        D = np.where(mask_fn(P, names), D, 1e3)
    w = 1.0 / np.maximum(D, 0.01) ** power
    top = np.argsort(-w, 1)[:, :4]
    out = np.zeros_like(w)
    np.put_along_axis(out, top, np.take_along_axis(w, top, 1), 1)
    out /= out.sum(1, keepdims=True)
    for j, n in enumerate(names):
        WT[verts, BI[n]] = out[:, j]


# body: the torso above the belt, the legs (boots, and what lies round each leg's column under the tunic), the skirt
_bv = np.where(BODY)[0]
_boot = BODY & (Z < ZN_BOOT + 0.012)
LEG_C = {s: CO[_boot & (np.sign(X) == sg)][:, :2].mean(0) for s, sg in (("l", 1), ("r", -1))}
_side = np.where(X > 0, "l", "r")
_legcol = np.array([np.linalg.norm(CO[i, :2] - LEG_C[_side[i]]) < 0.062 for i in range(NV)])
LEGS = BODY & ((Z < ZN_BOOT + 0.012) | (_legcol & (Z < ZN_BELT - 0.04)))
TORSO = BODY & ~LEGS & (Z > ZN_BELT - 0.025)
SKIRT = BODY & ~LEGS & ~TORSO
by_distance(np.where(TORSO)[0], ["hips", "spine", "chest", "neck"], 5)
SKIRT_B = [b for b in DEFORM if b.startswith("skirt.")]
by_distance(np.where(SKIRT)[0], ["hips"] + SKIRT_B, 4)
LEG_B = ["upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]
by_distance(np.where(LEGS)[0], LEG_B, 6, lambda P, names: np.array([n.endswith(".l") for n in names])[None, :] == (P[:, 0] > X_RIG)[:, None])
by_distance(np.where(SCARF)[0], ["spine", "chest", "neck"], 5)
WT[HEAD, BI["head"]] = 1.0
# the arms: their own weights; "body" is the shoulder
for verts, names, Wt, root in ((TENT_V, TENT_NAMES, TENT_W, "shoulder.r"), (LARM_V, LARM_NAMES, LARM_W, "shoulder.l")):
    WT[verts] = 0
    for j, n in enumerate(names):
        WT[verts, BI[root if n == "body" else n]] += Wt[:, j]
# blend across part seams (not inside the tentacle, whose tips must not share)
_soft = SHELL & ~TENT
_rounds = np.where(SKIRT, 5, 2)
for r in range(5):
    W2 = WT.copy()
    for i in np.where(_soft & (_rounds > r))[0]:
        nb = [b for b in ADJ[i] if SHELL[b]]
        if nb:
            W2[i] = 0.5 * WT[i] + 0.5 * WT[nb].mean(0)
    WT = W2
# four per vertex
_top = np.argsort(-WT, 1)[:, :4]
JW = np.take_along_axis(WT, _top, 1)
JW /= np.maximum(JW.sum(1, keepdims=True), 1e-9)
JN = np.array(DEFORM)[_top]
log("weights: %d bones used" % len({n for row, w in zip(JN, JW) for n, x in zip(row, w) if x > 1e-4}))

# ---------------------------------------------------------------- 7. the face plate
# v3's face is painted: a black void inside the hood with two cyan eyes. The plate is that void's vertices laid on one
# plane through its lower middle, tipped FACE_TILT up towards the game camera (54 degrees down: a vertical face is
# at cos 0.6 from it), its painted eyes blacked out (section 8); the game's eye and grin decals lie on the plate
# (heretic_rig.FACE["v3"], printed to face.txt), so blink, squint and the grin work as on the chibi.
FACE_TILT = float(os.environ.get("HERO_V3_FACE_TILT", "40"))
FACE_K = float(os.environ.get("HERO_V3_FACE_K", "0.85"))   # heretic_rig FACE "k": the decals' size
FACE_LIFT = 0.007
_eyes = HEAD & (CLS == "cyan")
_fz = CO[_eyes, 2].mean() if _eyes.any() else 0.7
FACEV = HEAD & np.isin(CLS, ["black", "cyan", "dark"]) & (Y < -0.04) & (np.abs(X) < 0.125) & (Z > ZN_NECK - 0.01) & (Z < _fz + 0.12)
FACEV = flood(np.where(_eyes)[0].tolist() + np.where(FACEV & (CLS == "black"))[0].tolist(), FACEV)
_fp = FIT[FACEV]
_fc = _fp.mean(0)
_u, _sv, _vt = np.linalg.svd(_fp - _fc)
FN = _vt[2] if _vt[2][1] < 0 else -_vt[2]        # out of the face (towards -y)
_tilt = Matrix.Rotation(math.radians(-FACE_TILT), 3, "X")
FN = np.array(_tilt @ Vector(FN))
FN /= np.linalg.norm(FN)
FUP = np.cross(FN, [1, 0, 0])
FUP = FUP if FUP[2] > 0 else -FUP
FUP /= np.linalg.norm(FUP)
FRIGHT = np.cross(FUP, FN)
# the plate passes through the void's lower middle, FACE_SINK into the opening (negative: out of it, past the brim's shadow)
FACE_SINK = float(os.environ.get("HERO_V3_FACE_SINK", "-0.03"))
_low = _fp[_fp[:, 2] < np.percentile(_fp[:, 2], 30)].mean(0)
PLATE_O = _low - FN * FACE_SINK
# move the void onto the plate; the ring next to the hood moves half way, so the rim keeps its edge
_ring = np.array([i for i in np.where(FACEV)[0] if any(SHELL[b] and not FACEV[b] for b in ADJ[i])])
_kf = np.ones(NV)
_kf[_ring] = 0.5
for i in np.where(FACEV)[0]:
    d = np.dot(FIT[i] - PLATE_O, FN)
    FIT[i] -= FN * d * _kf[i]
log("face plate: %d verts, tipped %.0f deg, normal %s" % (FACEV.sum(), FACE_TILT, np.round(FN, 3)))


def on_plate(p):
    return p - FN * np.dot(p - PLATE_O, FN) + FN * FACE_LIFT


if _eyes.any():
    _ec = [FIT[_eyes & (X < 0)].mean(0), FIT[_eyes & (X > 0)].mean(0)]   # his right eye (screen left) first
else:
    _ec = [_fc - FRIGHT * 0.1, _fc + FRIGHT * 0.1]
# the painted eyes sit high in the void, under the brim, where the game camera (54 degrees down) can't see them; the
# decals go EYE_H of the way up the plate instead, square about the void's middle, the grin GRIN_H up
EYE_H = float(os.environ.get("HERO_V3_EYE_H", "0.35"))
GRIN_H = float(os.environ.get("HERO_V3_GRIN_H", "0.08"))
EYE_GAP = float(os.environ.get("HERO_V3_EYE_GAP", "0.8"))   # of the painted eyes' spacing
_h = (FIT[FACEV] - PLATE_O) @ FUP
_w = (FIT[FACEV] - PLATE_O) @ FRIGHT
_mid = PLATE_O + FRIGHT * (_w.min() + _w.max()) / 2
_half = abs(np.dot(_ec[1] - _ec[0], FRIGHT)) / 2 * EYE_GAP   # the hood's cheek hides an eye at the painted gap
log("face void: %.3f m tall, %.3f wide; painted eyes %.2f up it" % (_h.max() - _h.min(), _w.max() - _w.min(),
    (np.mean([np.dot(e - PLATE_O, FUP) for e in _ec]) - _h.min()) / (_h.max() - _h.min())))
_up = lambda k: FUP * (_h.min() + k * (_h.max() - _h.min()))
EYE_SPOTS = [on_plate(_mid + _up(EYE_H) + FRIGHT * s * _half) for s in (-1, 1)]
GRIN_SPOT = on_plate(_mid + _up(GRIN_H))


# ---------------------------------------------------------------- 8. texture edits (texels, so edges are clean)
# Image rows run from the bottom (Blender's pixel order), like the UVs. PX holds the image's stored (sRGB) values.
ME.calc_loop_triangles()
TRI_L = np.array([lt.loops[:] for lt in ME.loop_triangles])
TRI_V = LV[TRI_L]
COVER = np.zeros((TH_, TW_), bool)


def raster(tri, fn):
    """Call fn(rows, cols, bary) for the texels inside one loop triangle (with a texel of padding)."""
    uv = LUV[TRI_L[tri]] * [TW_, TH_] - 0.5
    x0, y0 = np.floor(uv.min(0)).astype(int) - 1
    x1, y1 = np.ceil(uv.max(0)).astype(int) + 1
    xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, TW_ - 1) + 1), np.arange(max(y0, 0), min(y1, TH_ - 1) + 1))
    p = np.stack([xs.ravel(), ys.ravel()], 1).astype(float)
    a, b, c = uv
    m = np.array([b - a, c - a]).T
    if abs(np.linalg.det(m)) < 1e-9:
        return
    l12 = np.linalg.solve(m, (p - a).T).T
    bary = np.c_[1 - l12.sum(1), l12]
    eps = 1.0 / max(np.linalg.norm(b - a), np.linalg.norm(c - a), 1.0)
    inside = (bary >= -eps).all(1)
    if inside.any():
        fn(ys.ravel()[inside], xs.ravel()[inside], bary[inside])


for t in range(len(TRI_L)):
    raster(t, lambda r, c, b: COVER.__setitem__((r, c), True))

HORN = HEAD & ~FACEV & np.isin(CLS, ["dark", "slate", "grey"]) & (np.abs(X) > 0.1)
HORN_T = np.zeros(NV)
for comp in components(HORN):
    if len(comp) < 40:
        continue
    cm = np.zeros(NV, bool)
    cm[comp] = True
    root = [i for i in comp if any(SHELL[b] and not HORN[b] for b in ADJ[i])]
    d, _ = dijkstra(root, cm)
    HORN_T[comp] = d[comp] / d[comp].max()
TIP_T = 0.64                       # the last third of each horn
CRIMSON = np.array([0xA8, 0x28, 0x2E]) / 255.0
HOOD_COOL = np.array([0xE9, 0xE8, 0xF0]) / 255.0
FACE_BLACK = np.array([0x05, 0x05, 0x0A]) / 255.0
_lum = lambda c: c @ [0.299, 0.587, 0.114]
_hood_tex = []
EDIT = PX.copy()
if TINT:
    for t in np.where(HORN[TRI_V].all(1))[0]:
        tv = HORN_T[TRI_V[t]]

        def horn(r, c, b, tv=tv):
            on = b @ tv > TIP_T
            EDIT[r[on], c[on]] = CRIMSON
        raster(t, horn)
    _hood_tri = np.where((HEAD & ~HORN & ~FACEV)[TRI_V].all(1))[0]
    _samples = []
    for t in _hood_tri[::7]:
        raster(t, lambda r, c, b: _samples.append(PX[r, c]))
    _samples = np.concatenate(_samples)
    _sat = (_samples.max(1) - _samples.min(1)) / np.maximum(_samples.max(1), 1e-6)
    _ref = np.median(_lum(_samples[(_sat < 0.25) & (_samples.max(1) > 0.6)]))

    def hood(r, c, b):
        p = PX[r, c]
        sat = (p.max(1) - p.min(1)) / np.maximum(p.max(1), 1e-6)
        on = (sat < 0.3) & (p.max(1) > 0.45)
        EDIT[r[on], c[on]] = np.clip(HOOD_COOL[None, :] * (_lum(p[on]) / _ref)[:, None], 0, 1)
    for t in _hood_tri:
        raster(t, hood)
    log("texture: horn tips crimson past %.2f of each horn, hood %s (was %.3f lum)" % (TIP_T, np.round(HOOD_COOL, 3), _ref))
for t in np.where(FACEV[TRI_V].any(1))[0]:
    def face(r, c, b):
        p = PX[r, c]
        on = (p[:, 1] > p[:, 0] + 0.08) | (p.max(1) < 0.35)   # the painted eyes' cyan and the dark void
        EDIT[r[on], c[on]] = FACE_BLACK
    raster(t, face)
# fill round the islands (8 px) so mipmaps don't pull the atlas's black gaps into the colours
_fill = EDIT.copy()
_have = COVER.copy()
for _ in range(8):
    acc = np.zeros_like(_fill)
    n = np.zeros(_have.shape)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(_have, dy, 0), dx, 1)
        acc += np.roll(np.roll(_fill, dy, 0), dx, 1) * sh[..., None]
        n += sh
    grow_ = ~_have & (n > 0)
    _fill[grow_] = acc[grow_] / n[grow_, None]
    _have |= grow_
EDIT = _fill
TEX = bpy.data.images.new("hero_v3_paint", TW_, TH_, alpha=False)
TEX.pixels = np.c_[EDIT.reshape(-1, 3), np.ones(TW_ * TH_)].ravel().tolist()
TEX.filepath_raw = os.path.join(OUT, "texture.png")
TEX.file_format = "PNG"
TEX.save()

# ---------------------------------------------------------------- 9. export (glTF space)
K = ARM.scale.x
for i in range(NV):
    ME.vertices[i].co = Vector(FIT[i])
ME.update()
NRM = np.zeros(NV * 3)
ME.vertices.foreach_get("normal", NRM)
NRM = NRM.reshape(-1, 3)
keymap = {}
P_, N_, U_, J_, W_, IDX = [], [], [], [], [], []
for t in range(len(TRI_L)):
    tri = []
    for li in TRI_L[t]:
        vi = LV[li]
        u, v = LUV[li]
        key = (vi, round(float(u), 6), round(float(v), 6))
        if key not in keymap:
            keymap[key] = len(P_)
            x, y, z = FIT[vi]
            P_.append((x, z, -y))
            nx, ny, nz = NRM[vi]
            N_.append((nx, nz, -ny))
            U_.append((u, 1.0 - v))
            J_.append(list(JN[vi]))
            W_.append(list(JW[vi]))
        tri.append(keymap[key])
    IDX.append(tri)
np.savez(os.path.join(OUT, "body.npz"), pos=np.array(P_, np.float32), nrm=np.array(N_, np.float32),
         uv=np.array(U_, np.float32), joints=np.array(J_), weights=np.array(W_, np.float32), idx=np.array(IDX, np.uint32))
import json
_bones = {}
for name in RIG_TIPS:
    for b in chain("tent." + name):
        h = NEW_REST[b]
        _bones[b] = [float(h[0]), float(h[2]), float(-h[1])]   # glTF world
with open(os.path.join(OUT, "bones.json"), "w") as f:
    json.dump(_bones, f, indent=1)


def godot(v, scale=True):
    k = K if scale else 1.0
    return "Vector3(%.4f, %.4f, %.4f)" % (v[0] / k, v[2] / k, -v[1] / k)


with open(os.path.join(OUT, "face.txt"), "w") as f:
    for nm, p in (("eye_r", EYE_SPOTS[0]), ("eye_l", EYE_SPOTS[1]), ("grin", GRIN_SPOT)):
        f.write("%s %s %s\n" % (nm, godot(p), godot(FN, False)))
    f.write("normal %s\nup %s\nright %s\nk %.2f\n" % (godot(FN, False), godot(FUP, False), godot(FRIGHT, False), FACE_K))
log("tris %d, verts %d, height %.3f m (crown), feet %.3f" % (len(IDX), len(P_), FIT[:, 2].max(), FIT[:, 2].min()))
_hz = FIT[HEAD & ~HORN, 2].max()
log("head: hood crown %.3f m, neck joint %.3f m -> %.1f%% of his height" % (_hz, Z_RIG["neck"], 100 * (_hz - Z_RIG["neck"]) / _hz))


# ---------------------------------------------------------------- 10. the rig preview (blend + workbench renders)
bpy.context.view_layer.objects.active = ARM
ARM.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
_inv = MW.inverted()
for name in RIG_TIPS:
    for b in chain("tent." + name):
        eb = ARM.data.edit_bones[b]
        eb.use_connect = False
        eb.head = _inv @ Vector(NH(b))
        eb.tail = _inv @ Vector(NT(b))
bpy.ops.object.mode_set(mode="OBJECT")
for o in list(bpy.data.objects):
    if o.name.startswith("bone_"):
        bpy.data.objects.remove(o)
for i in range(NV):
    ME.vertices[i].co = Vector(FIT[i])
for n in sorted({n for row in JN for n in row}):
    OB.vertex_groups.new(name=n)
for i in range(NV):
    for n, w in zip(JN[i], JW[i]):
        if w > 1e-5:
            OB.vertex_groups[n].add([i], float(w), "ADD")
OB.parent = ARM
OB.matrix_parent_inverse = ARM.matrix_world.inverted()
_m = OB.modifiers.new("arm", "ARMATURE")
_m.object = ARM
_mat = OB.material_slots[0].material
_tn = next(n for n in _mat.node_tree.nodes if n.type == "TEX_IMAGE")
_tn.image = TEX
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "hero_v3.blend"))
if RENDER:
    sc, cam = setup_render(ortho=2.4)
    sc.display.shading.color_type = "TEXTURE"
    poses = ["rest"] + (argv[4].split(",") if len(argv) > 4 and ":" in argv[4] else
                        ["Idle:0", "Run_F:4", "Ab_L1:11", "Ab_GR:7", "Ab_L3:24", "Ab_VS:17"])
    for pose in poses:
        if pose != "rest":
            a, fr = pose.split(":")
            ARM.animation_data_create()
            ARM.animation_data.action = bpy.data.actions[a]
            sc.frame_set(int(fr))
        shoot(sc, cam, "r_" + pose.replace(":", "_"), ("front", "side", "game") if pose == "rest" else ("front", "game"), tgt=(0, -0.1, 0.85))
