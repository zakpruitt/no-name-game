# Rebuilds the Meshy "elemental heretic" rig on a copy: game bone names, tentacle chains traced
# from the mesh, skirt chains, and clean weights. The source FBX is only read.
#   blender -b --factory-startup -P heretic_rig.py -- <rigged.fbx> <out.blend> [profile]
# profile: "heretic" (default, round 28's model) or "chibi" (round 29's chibi: Meshy's REST
# auto-rig, a normal right arm ending in a six-claw tentacle hand). Each profile is the
# per-character settings below; the logic is shared.
import bpy, sys, colorsys, collections, heapq, math, json, os
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
PROFILE = args[2] if len(args) > 2 else "heretic"

# ---- per-character settings (the heretic's; the chibi profile overrides them further down)
SHOULDER = np.array([-0.17, 0.01, 1.23])   # centre of the ring the tentacle is measured from
RING_R = .14         # how far round SHOULDER the ring reaches
ROOT_BLEND = .08     # surface distance over which the limb melts into ROOT_BONE
ROOT_BONE = "shoulder.r"
ARM_FROM_SKELETON = False  # True: upperarm.r / lowerarm.r are Meshy's arm; the tentacle starts at the wrist
TIP_PARENT = "upperarm.r"  # tips not in JOIN hang off this; None = the main bone nearest their start
TENT_HUE = (.68, .90, .18)  # hue range and min saturation of the limb's paint
HOLE_Z = .5          # colour holes are closed on the limb only above this height
NECK_Z = 1.42        # above this nothing but the tentacle may follow tentacle bones
ALIAS = {}           # this rig's bone name -> the Mixamo-style name used below
SKIRT_CHAIN_TOP, SKIRT_BOTTOM = .80, .2
LEG_R = (.38, .115, .095)  # below z, radius below, radius above: inside it is leg, not skirt
TIPS = {  # name: where the tip is. "main" comes first: it is the weapon limb and carries hand.r
    "main": (-.482, .038, .474), "low": (-.42, .129, .682), "mid": (-.559, .13, .892),
    "out": (-.509, .127, 1.283), "up": (-.372, .072, 1.463),
}
ARM_SPLITS = [("upperarm.r", .22), ("lowerarm.r", .42), ("wrist.r", .47), ("hand.r", .56)]  # arc length on main
JOIN = {"mid": .085, "low": .07}  # how close to the limb a tip still counts as fused to it
TRIM = {"mid": .17}  # metres of chain to skip at the base, where a tip is still fused to the limb
TIP_SEG = 0.07       # bone length on the tips; short enough to coil
TENT_XMAX = -.14     # purple past this is the shawl on his back, not a tentacle
SKIRT_N = 12         # chains round the skirt, chain 0 at the front
SKIRT_TOP, SKIRT_FADE = 0.82, 0.66
SKIRT_AXIS = (.02, -.05)
BLEND = .03          # how far along a limb one bone melts into the next
BODY_MAP = {
    "Hips": "hips", "Spine": "spine", "Spine1": "chest", "Spine2": "chest", "Neck": "neck",
    "Head": "head", "HeadTop_End": "head", "headfront": "head",
    "LeftShoulder": "shoulder.l", "LeftArm": "upperarm.l", "LeftForeArm": "lowerarm.l", "LeftHand": "hand.l",
    "RightShoulder": "shoulder.r", "RightArm": "shoulder.r",
    "LeftUpLeg": "upperleg.l", "LeftLeg": "lowerleg.l", "LeftFoot": "foot.l",
    "LeftToeBase": "toes.l", "LeftToe_End": "toes.l",
    "RightUpLeg": "upperleg.r", "RightLeg": "lowerleg.r", "RightFoot": "foot.r",
    "RightToeBase": "toes.r", "RightToe_End": "toes.r",
}
for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
    for i in (1, 2, 3, 4):
        BODY_MAP[f"LeftHand{f}{i}"] = f"finger.{f.lower()}.{min(i, 3)}.l"

if PROFILE == "chibi":
    # Meshy's REST auto-rig (24 bones, no fingers), on the decimated, mirrored, retextured chibi.
    # The tentacle is a six-claw hand on an ordinary arm, so the arm is Meshy's and the claws
    # start at the wrist. Tip positions picked by eye (vendor_src/meshy/chibi/tips.png).
    ALIAS = {"Spine02": "Spine", "Spine01": "Spine1", "Spine": "Spine2", "neck": "Neck", "head_end": "HeadTop_End"}
    SHOULDER = np.array([-0.304, -0.208, 0.857])   # RightHand's head: the wrist
    RING_R, ROOT_BLEND, ROOT_BONE = .07, .04, "lowerarm.r"
    ARM_FROM_SKELETON, TIP_PARENT = True, "hand.r"   # every claw grows out of the palm
    TIPS = {"main": (-.198, -.462, .844), "up": (-.33, -.447, 1.075), "out": (-.383, -.413, .884),
            "mid": (-.151, -.355, .896), "low": (-.215, -.397, .704), "back": (-.313, -.342, .7)}
    ARM_SPLITS = [("wrist.r", .03), ("hand.r", .10)]   # arc length from the wrist along main
    JOIN, TRIM = {}, {}
    TIP_SEG = .06
    TENT_XMAX, TENT_HUE, HOLE_Z, NECK_Z = -.15, (.82, .94, .4), .6, 1.0
    SKIRT_TOP, SKIRT_FADE, SKIRT_AXIS = .62, .52, (.02, .2)
    SKIRT_CHAIN_TOP, SKIRT_BOTTOM = .62, .18
    LEG_R = (.3, .085, .075)
    BLEND = .02
    BODY_MAP.update({"RightArm": "upperarm.r", "RightForeArm": "lowerarm.r"})

# ---- read the source
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
ob = next(o for o in bpy.data.objects if o.type == "MESH")
old = next(o for o in bpy.data.objects if o.type == "ARMATURE")
if old.animation_data:
    old.animation_data.action = None
for pb in old.pose.bones:
    pb.matrix_basis.identity()
bpy.context.view_layer.update()
me = ob.data
n = len(me.vertices)
mw = ob.matrix_world.copy()
co = np.array([list(mw @ v.co) for v in me.vertices])
canon = lambda s: ALIAS.get(s.replace("mixamorig:", ""), s.replace("mixamorig:", ""))
OB = {canon(b.name): (np.array(old.matrix_world @ b.head_local), np.array(old.matrix_world @ b.tail_local))
      for b in old.data.bones}
gname = [canon(g.name) for g in ob.vertex_groups]
G = np.zeros((n, len(gname)), np.float32)
for v in me.vertices:
    for g in v.groups:
        G[v.index, g.group] = g.weight

# weld the seam split so everything below works on the real surface
key, wid = {}, np.zeros(n, int)
for i, c in enumerate(co):
    wid[i] = key.setdefault(tuple(np.round(c, 4)), len(key))
W = len(key)
wco = np.zeros((W, 3)); wco[wid] = co
adj = [set() for _ in range(W)]
for e in me.edges:
    a, b = wid[e.vertices[0]], wid[e.vertices[1]]
    if a != b:
        adj[a].add(b); adj[b].add(a)
wG = np.zeros((W, G.shape[1]), np.float32); wG[wid] = G
wdom = np.array(gname, dtype=object)[wG.argmax(1)]

# ---- tentacle = biggest connected purple region
img = bpy.data.images[0]; Wd, Hd = img.size
px = np.array(img.pixels[:], np.float32).reshape(Hd, Wd, img.channels)
uvd = me.uv_layers[0].data
uvs = np.zeros((n, 2))
for l in me.loops:
    uvs[l.vertex_index] = uvd[l.index].uv
rgb = px[np.clip((uvs[:, 1] % 1 * Hd).astype(int), 0, Hd - 1), np.clip((uvs[:, 0] % 1 * Wd).astype(int), 0, Wd - 1), :3]
hsv = np.array([colorsys.rgb_to_hsv(*c) for c in rgb])
pur = (hsv[:, 0] > TENT_HUE[0]) & (hsv[:, 0] < TENT_HUE[1]) & (hsv[:, 1] > TENT_HUE[2])
wp = np.zeros(W, bool); wp[wid[pur]] = True

def components(idx):
    S, seen, out = set(idx), set(), []
    for s in idx:
        if s in seen:
            continue
        st, c = [s], []
        seen.add(s)
        while st:
            a = st.pop(); c.append(a)
            for b in adj[a]:
                if b in S and b not in seen:
                    seen.add(b); st.append(b)
        out.append(c)
    return out

tent = np.zeros(W, bool)
tent[max(components(list(np.where(wp)[0])), key=len)] = True
for _ in range(2):   # close colour holes on the limb only
    tent[[b for a in np.where(tent)[0] for b in adj[a] if wco[b][0] < TENT_XMAX + .02 and wco[b][2] > HOLE_Z]] = True
tent &= wco[:, 0] < TENT_XMAX
keep = max(components(list(np.where(tent)[0])), key=len)
tent[:] = False; tent[keep] = True

def dijkstra(srcs):
    dist = {i: 0. for i in srcs}; pred = {i: None for i in srcs}
    pq = [(0., i) for i in srcs]
    while pq:
        d, a = heapq.heappop(pq)
        if d > dist[a]:
            continue
        for b in adj[a]:
            if tent[b]:
                nd = d + np.linalg.norm(wco[a] - wco[b])
                if nd < dist.get(b, 9e9):
                    dist[b] = nd; pred[b] = a; heapq.heappush(pq, (nd, b))
    return dist, pred

d0 = np.linalg.norm(wco - SHOULDER, axis=1)
ringv = [i for i in np.where(tent)[0] if d0[i] < RING_R]
dist, pred = dijkstra(ringv)
tverts = np.array(sorted(dist))
print("tentacle verts", len(tverts))

def centre(p, r=.07):
    q = wco[tverts]
    return q[np.linalg.norm(q - p, axis=1) < r].mean(0)

# ---- chains: tip back along the surface to the shoulder, pulled to the tube's middle
chains, kept = {}, []
for name, tp in TIPS.items():
    t = tverts[np.argmin(np.linalg.norm(wco[tverts] - np.array(tp), axis=1))]
    path, a = [], t
    while a is not None:
        path.append(a); a = pred[a]
    path = path[::-1]
    pts = np.array([centre(wco[v]) for v in path])
    for _ in range(4):
        pts[1:-1] = (pts[:-2] + pts[1:-1] * 2 + pts[2:]) / 4
    pts[-1] = wco[t]
    s = 0
    if kept:
        K = np.vstack(kept)
        for j in range(len(pts) - 1, -1, -1):
            if np.linalg.norm(K - pts[j], axis=1).min() < JOIN.get(name, .055):
                s = j; break
    if name in TRIM:
        arc_ = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts[s:], axis=0), axis=1))]
        s += int(np.searchsorted(arc_, TRIM[name]))
    chains[name] = {"pts": pts[s:], "path": path[s:], "start": pts[s]}
    kept.append(pts[s:])

def resample(pts, cuts):
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    arc = np.r_[0, np.cumsum(seg)]
    return np.array([[np.interp(c, arc, pts[:, k]) for k in range(3)] for c in cuts]), arc

# ---- bones: (name, head, tail, parent, deform)
bones = []
def bone(nm, h, t, parent=None, deform=True):
    h, t = np.array(h, float), np.array(t, float)
    d = t - h
    if np.linalg.norm(d) < .02:
        d = d / max(np.linalg.norm(d), 1e-6) * .02 if np.linalg.norm(d) > 1e-6 else np.array([0, 0, .02])
        t = h + d
    bones.append((nm, h, t, parent, deform))

H = lambda k: OB[k][0]
T = lambda k: OB[k][1]
bone("root", (0, 0, 0), (0, 0, .2), None, False)
bone("hips", H("Hips"), H("Spine"), "root")
bone("spine", H("Spine"), H("Spine1"), "hips")
bone("chest", H("Spine1"), H("Neck"), "spine")
bone("neck", H("Neck"), H("Head"), "chest")
bone("head", H("Head"), H("HeadTop_End"), "neck")
for s, S in (("l", "Left"), ("r", "Right")):
    bone(f"shoulder.{s}", H(f"{S}Shoulder"), H(f"{S}Arm"), "chest")
    bone(f"upperleg.{s}", H(f"{S}UpLeg"), H(f"{S}Leg"), "hips")
    bone(f"lowerleg.{s}", H(f"{S}Leg"), H(f"{S}Foot"), f"upperleg.{s}")
    bone(f"foot.{s}", H(f"{S}Foot"), H(f"{S}ToeBase"), f"lowerleg.{s}")
    bone(f"toes.{s}", H(f"{S}ToeBase"), T(f"{S}ToeBase"), f"foot.{s}")
# left arm: an ordinary arm, fingers kept
bone("upperarm.l", H("LeftArm"), H("LeftForeArm"), "shoulder.l")
bone("lowerarm.l", H("LeftForeArm"), H("LeftHand"), "upperarm.l")
wv = (T("LeftHand") - H("LeftHand")); wv /= np.linalg.norm(wv)
palm = H("LeftHandMiddle1") if "LeftHandMiddle1" in OB else H("LeftHand") + (T("LeftHand") - H("LeftHand")) * .6
bone("wrist.l", H("LeftHand"), H("LeftHand") + wv * .03, "lowerarm.l", False)
bone("hand.l", H("LeftHand") + wv * .03, palm, "wrist.l")
bone("handslot.l", palm, palm + wv * .08, "hand.l", False)
for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
    for i in (1, 2, 3):
        if f"LeftHand{f}{i}" not in OB:   # the REST auto-rig has no fingers
            continue
        bone(f"finger.{f.lower()}.{i}.l", H(f"LeftHand{f}{i}"), T(f"LeftHand{f}{i}"),
             "hand.l" if i == 1 else f"finger.{f.lower()}.{i - 1}.l")

# right side: the main tentacle wears the game's arm names, so hand.r keeps working
tent_bones = []   # name, chain, arc start, arc end
main = chains["main"]
prev = "shoulder.r"
if ARM_FROM_SKELETON:   # a real arm up to the wrist; the tentacle hand starts there
    bone("upperarm.r", H("RightArm"), H("RightForeArm"), "shoulder.r")
    bone("lowerarm.r", H("RightForeArm"), H("RightHand"), "upperarm.r")
    prev = "lowerarm.r"
mpts = np.vstack(([H("RightHand") if ARM_FROM_SKELETON else H("RightArm")], main["pts"]))
marc0 = np.linalg.norm(mpts[1] - mpts[0])
total = np.linalg.norm(np.diff(mpts, axis=0), axis=1).sum()
print("main limb length %.3f" % total)
a0 = 0.
for nm, a1 in ARM_SPLITS:
    p, _ = resample(mpts, [a0, a1])
    bone(nm, p[0], p[1], prev)
    tent_bones.append((nm, "main", a0, a1)); prev, a0 = nm, a1
p, _ = resample(mpts, [a0, a0 + .08])
bone("handslot.r", p[0], p[1], "hand.r", False)
cnt = max(1, round((total - a0) / TIP_SEG))
cuts = np.linspace(a0, total, cnt + 1)
pp, _ = resample(mpts, cuts)
for i in range(cnt):
    nm = f"tent.main.{i + 1:02d}"
    bone(nm, pp[i], pp[i + 1], prev)
    tent_bones.append((nm, "main", cuts[i], cuts[i + 1])); prev = nm

def main_bone_at(p):
    best, bd = ARM_SPLITS[0][0], 9e9
    on_main = {b[0] for b in tent_bones if b[1] == "main"}
    for nm, h, t, _, _ in bones:
        if nm in on_main:
            d = np.linalg.norm((h + t) / 2 - p)
            if d < bd:
                best, bd = nm, d
    return best

for name in list(TIPS)[1:]:
    c = chains[name]
    L = np.linalg.norm(np.diff(c["pts"], axis=0), axis=1).sum()
    cnt = max(2, round(L / TIP_SEG))
    cuts = np.linspace(0, L, cnt + 1)
    pp, _ = resample(c["pts"], cuts)
    # tips that leave at the shoulder hang off upperarm.r; the fused ones split from the main limb
    prev = main_bone_at(pp[0]) if name in JOIN or TIP_PARENT is None else TIP_PARENT
    print("chain", name, "len %.3f" % L, "bones", cnt, "parent", prev)
    for i in range(cnt):
        nm = f"tent.{name}.{i + 1:02d}"
        bone(nm, pp[i], pp[i + 1], prev)
        tent_bones.append((nm, name, cuts[i], cuts[i + 1])); prev = nm

# ---- tentacle weights: surface distance, so a tip never grabs its neighbour across a gap
tb_names = [b[0] for b in tent_bones]
seeds = {b: set() for b in tb_names}
seeds[ARM_SPLITS[0][0]].update(ringv)
for name in TIPS:
    c = chains[name]
    pts = mpts if name == "main" else c["pts"]
    off = marc0 if name == "main" else 0.
    arc = np.r_[0, np.cumsum(np.linalg.norm(np.diff(c["pts"], axis=0), axis=1))] + off
    these = [b for b in tent_bones if b[1] == name]
    for v, s in zip(c["path"], arc):
        for b in these:
            if b[2] <= s <= b[3] + 1e-6:
                seeds[b[0]].add(v); break
for b in tb_names:
    if not seeds[b]:   # very short bone: take the nearest path vertex
        h, t = next((x[1], x[2]) for x in bones if x[0] == b)
        seeds[b].add(int(tverts[np.argmin(np.linalg.norm(wco[tverts] - (h + t) / 2, axis=1))]))
D = np.full((W, len(tb_names)), 1e3, np.float32)
for j, b in enumerate(tb_names):
    d, _ = dijkstra(list(seeds[b]))
    for v, x in d.items():
        D[v, j] = x
dmin = D.min(1, keepdims=True)
TW = np.exp(-(D - dmin) / BLEND)
TW[D - dmin > .12] = 0
TW /= np.maximum(TW.sum(1, keepdims=True), 1e-6)

# ---- final weight table
all_names = [b[0] for b in bones if b[4]]
# skirt chains get added below; reserve their names now
for i in range(SKIRT_N):
    for k in (1, 2, 3):
        all_names.append(f"skirt.{i:02d}.{k}")
idx = {nm: i for i, nm in enumerate(all_names)}
F = np.zeros((W, len(all_names)), np.float32)
for j, g in enumerate(gname):
    if g in BODY_MAP:
        F[:, idx[BODY_MAP[g]]] += wG[:, j]
s = F.sum(1)
print("non-mapped-only verts before fixes:", int((s < 1e-4).sum()))
# anything left only on removed bones: take the nearest vertex that still has weights
ok = s > 1e-4
okv = np.where(ok)[0]
for v in np.where(~ok)[0]:
    if not tent[v]:
        F[v] = F[okv[np.argmin(np.linalg.norm(wco[okv] - wco[v], axis=1))]]
F /= np.maximum(F.sum(1, keepdims=True), 1e-6)

# tentacle: replace, except right at the root where it melts into the shoulder
for v in tverts:
    F[v] = 0
    root = np.clip(dist[v] / ROOT_BLEND, 0, 1)
    for j, b in enumerate(tb_names):
        if TW[v, j] > 0:
            F[v, idx[b]] += TW[v, j] * root
    F[v, idx[ROOT_BONE]] += 1 - root

# ---- skirt
def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)
dleg = np.minimum.reduce([seg_dist(wco, H(f"{S}UpLeg"), H(f"{S}Leg")) for S in ("Left", "Right")]
                         + [seg_dist(wco, H(f"{S}Leg"), H(f"{S}Foot")) for S in ("Left", "Right")])
R = np.where(wco[:, 2] < LEG_R[0], LEG_R[1], LEG_R[2])
fam = np.isin(wdom, ["LeftUpLeg", "RightUpLeg", "Hips", "LeftLeg", "RightLeg", "Spine"])
skirt = fam & ~tent & (wco[:, 2] < SKIRT_TOP) & (wco[:, 2] > SKIRT_BOTTOM) & (dleg > R)
ang = np.arctan2(wco[:, 0] - SKIRT_AXIS[0], -(wco[:, 1] - SKIRT_AXIS[1]))
sect = (ang / (2 * math.pi) * SKIRT_N) % SKIRT_N
print("skirt verts", int(skirt.sum()))
zlow = np.percentile(wco[skirt, 2], 2)
top = SKIRT_CHAIN_TOP
levels = np.linspace(top, zlow, 4)
for i in range(SKIRT_N):
    m = skirt & (np.minimum(abs(sect - i), SKIRT_N - abs(sect - i)) < .75)
    a = 2 * math.pi * i / SKIRT_N
    q = []
    for z in levels:
        near = m & (abs(wco[:, 2] - z) < .05)
        if near.sum() >= 3:
            q.append(wco[near].mean(0))
        else:
            r = .2
            q.append(np.array([SKIRT_AXIS[0] + r * math.sin(a), SKIRT_AXIS[1] - r * math.cos(a), z]))
    for k in (1, 2, 3):
        bone(f"skirt.{i:02d}.{k}", q[k - 1], q[k], "hips" if k == 1 else f"skirt.{i:02d}.{k - 1}")
hips = idx["hips"]
for v in np.where(skirt)[0]:
    z = wco[v, 2]
    fade = np.clip((SKIRT_TOP - z) / (SKIRT_TOP - SKIRT_FADE), 0, 1)
    off = np.clip((dleg[v] - R[v]) / .06, 0, 1)
    wsk = fade * off
    # what isn't skirt stays on the body: on the legs near them, on the hips away from them
    rest = F[v] * (1 - off)
    rest[hips] += off
    rest *= (1 - wsk) / max(rest.sum(), 1e-6)
    F[v] = rest
    t = np.clip((top - z) / (top - zlow), 0, 1) * 3 - .5   # along the chain
    k0 = int(np.floor(t)); ft = t - k0
    s0 = int(np.floor(sect[v])) % SKIRT_N; fs = sect[v] - np.floor(sect[v])
    for si, ws in ((s0, 1 - fs), ((s0 + 1) % SKIRT_N, fs)):
        for kk, wk in ((k0, 1 - ft), (k0 + 1, ft)):
            kk = int(np.clip(kk, 0, 2)) + 1
            F[v, idx[f"skirt.{si:02d}.{kk}"]] += wsk * ws * wk

# ---- smooth where the new weights meet the old ones
zone = set(np.where(skirt)[0]) | {v for v in tverts if dist[v] < RING_R}
for _ in range(2):
    zone |= {b for a in zone for b in adj[a]}
zone = np.array(sorted(zone))
for _ in range(3):
    N = F.copy()
    for v in zone:
        nb = list(adj[v])
        if nb:
            N[v] = F[v] * .5 + F[nb].mean(0) * .5
    F = N

# keep the 4 strongest, the game's limit
order = np.argsort(-F, axis=1)
for v in range(W):
    F[v, order[v, 4:]] = 0
F /= np.maximum(F.sum(1, keepdims=True), 1e-6)

# hair and head must follow only the head and neck family: check, don't assume
above = wco[:, 2] > NECK_Z
bad = F[above][:, [idx[b] for b in tb_names]].sum(1)
print("verts above the neck on tentacle bones >.01 (excluding the tentacle):", int(((bad > .01) & ~tent[above]).sum()))

# same vertex set the audit of Meshy's rig measured, so before and after compare fairly
audit = np.isin(wdom, ["LeftUpLeg", "RightUpLeg"]) & (wco[:, 2] < SKIRT_TOP + .02) & (wco[:, 2] > SKIRT_BOTTOM) & ~tent
np.save(os.path.splitext(OUT)[0] + "_audit_skirt.npy", audit)

# ---- swap in the new rig (only in this copy)
ob.parent = None
ob.matrix_world = mw
ob.modifiers.clear()
ob.vertex_groups.clear()
bpy.data.objects.remove(old)
ad = bpy.data.armatures.new("HereticRig")
arm = bpy.data.objects.new("HereticRig", ad)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for nm, h, t, par, dfm in bones:
    eb = ad.edit_bones.new(nm)
    eb.head, eb.tail = Vector(h), Vector(t)
    eb.use_deform = dfm
    eb.roll = 0
for nm, h, t, par, dfm in bones:
    if par:
        ad.edit_bones[nm].parent = ad.edit_bones[par]
bpy.ops.object.mode_set(mode="OBJECT")
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
groups = {nm: ob.vertex_groups.new(name=nm) for nm in all_names}
for v in range(n):
    w = F[wid[v]]
    for j in np.nonzero(w)[0]:
        groups[all_names[j]].add([v], float(w[j]), "REPLACE")
mod = ob.modifiers.new("HereticRig", "ARMATURE")
mod.object = arm
ob.parent = arm
ob.matrix_parent_inverse = arm.matrix_world.inverted()
ob.name = "heretic"
# keep the texture inside the blend, and drop clips from the old rig
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
for im in bpy.data.images:
    im.pack()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("bones total", len(bones), "deform", sum(1 for b in bones if b[4]), "tentacle", len(tb_names))
print("SAVED", OUT)
