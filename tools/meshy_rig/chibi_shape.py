# Sharpens the chibi heretic's two signature shapes for the game camera (round 40, chibi pass 2):
# the hood's peak is narrowed to a sharper point that flops back, so from 54 degrees up it pokes
# past the hood's outline instead of hiding inside an egg, and every claw is fattened round its own
# bones (fading in from the palm) so the six fingers read as thick hooks with ink between them.
# Only vertices move: bones, weights, UVs and the rest pose are untouched, so chibi_keys.py runs on
# the result as on the baked blend and every clip and contact stays. Height stays 1.85 m.
#   blender -b <blend> -P chibi_shape.py -- <out.blend> [hood_back_m] [hood_sharp] [claw_fat]
import bpy, sys, math
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
HOOD_BACK = float(args[1]) if len(args) > 1 else 0.18   # m the tip moves towards his back
HOOD_SHARP = float(args[2]) if len(args) > 2 else 0.3   # how much narrower the hood gets towards the tip
CLAW_FAT = float(args[3]) if len(args) > 3 else 1.35    # claw radius round its bones, past the palm
HOOD_FROM = 0.45      # of the hood's height above the brow (HOOD_BASE) where the reshaping starts
HOOD_BASE = 1.3       # m: the brow; the peak is everything well above it
TILT_POW, SHARP_POW = 2.0, 1.0
CLAW_FADE = (0.04, 0.12)   # m along a claw from its root: no growth before, full growth after
CLAW_TIPS = ("main", "up", "out", "mid", "low", "back")

ob = bpy.data.objects["heretic"]
arm = bpy.data.objects["Armature"]
me = ob.data
MW = np.array(ob.matrix_world)
n = len(me.vertices)
lco = np.zeros(n * 3); me.vertices.foreach_get("co", lco)
co = lco.reshape(n, 3) @ MW[:3, :3].T + MW[:3, 3]
names = [g.name for g in ob.vertex_groups]
Wt = np.zeros((n, len(names)), np.float32)
for v in me.vertices:
    for g in v.groups:
        Wt[v.index, g.group] = g.weight
# welded groups: the mesh is split at UV seams; every copy must move the same way
key = {}
wid = np.array([key.setdefault(tuple(p), len(key)) for p in np.round(co, 4)])
nw = len(key)


def welded(w):
    s = np.zeros(nw); c = np.zeros(nw)
    np.add.at(s, wid, w); np.add.at(c, wid, 1)
    return (s / c)[wid]


def group(pred):
    return welded(Wt[:, [i for i, nm in enumerate(names) if pred(nm)]].sum(1))


top = co[:, 2].max()
new = co.copy()

# ---- hood peak
w_head = group(lambda nm: nm in ("head", "neck"))
hood = (w_head > 0.5) & (co[:, 2] > HOOD_BASE)
z0 = HOOD_BASE + (top - HOOD_BASE) * HOOD_FROM
peak = hood & (co[:, 2] > z0)
t = np.clip((co[:, 2] - z0) / (top - z0), 0, 1)
ring = hood & (np.abs(co[:, 2] - z0) < 0.02)
pivot = co[ring].mean(0) if ring.any() else co[peak].mean(0)
pivot[2] = z0
# narrower towards the tip, about each height's own middle (the shell's centre line)
mid = {}
bins = np.round((co[:, 2] - z0) / 0.02).astype(int)
for b in np.unique(bins[peak]):
    m = peak & (bins == b)
    mid[b] = co[m, :2].mean(0)
for i in np.nonzero(peak)[0]:
    c = mid[bins[i]]
    s = 1.0 - HOOD_SHARP * t[i] ** SHARP_POW
    new[i, :2] = c + (co[i, :2] - c) * s
# flop back: a shear towards his back (+y), growing as t^TILT_POW, so the tip keeps its height
# (1.85 m stays 1.85 m) and from the game camera it pokes out past the top of the hood
new[peak, 1] += HOOD_BACK * t[peak] ** TILT_POW
print("hood: %d verts reshaped above z %.3f, tip %.2f m back, sharp %.2f" % (int(peak.sum()), z0, HOOD_BACK, HOOD_SHARP))

# ---- claws: fatter round each claw's own bone chain
bones = arm.data.bones
AW = np.array(arm.matrix_world)


def wpt(v):
    return (AW @ np.array([v[0], v[1], v[2], 1.0]))[:3]


chains = {}
for tip in CLAW_TIPS:
    ch = sorted(b.name for b in bones if b.name.startswith("tent.%s." % tip))
    if ch:
        pts = [wpt(bones[ch[0]].head_local)] + [wpt(bones[b].tail_local) for b in ch]
        chains[tip] = (ch, np.array(pts))
cw = np.stack([group(lambda nm, ch=ch: nm in ch) for ch, _ in chains.values()], 1)
own = cw.argmax(1)
claw_w = cw.sum(1)
moved = 0
for k, (tip, (ch, pts)) in enumerate(chains.items()):
    seg_len = np.linalg.norm(pts[1:] - pts[:-1], axis=1)
    cum = np.concatenate([[0], np.cumsum(seg_len)])
    sel = np.nonzero((own == k) & (claw_w > 0.3))[0]
    for i in sel:
        p = new[i]
        best = (1e9, None, 0.0)
        for j in range(len(pts) - 1):
            a, b = pts[j], pts[j + 1]
            ab = b - a
            u = np.clip(np.dot(p - a, ab) / max(np.dot(ab, ab), 1e-12), 0, 1)
            q = a + ab * u
            d = np.linalg.norm(p - q)
            if d < best[0]:
                best = (d, q, cum[j] + u * seg_len[j])
        d, q, along = best
        f = np.clip((along - CLAW_FADE[0]) / (CLAW_FADE[1] - CLAW_FADE[0]), 0, 1) * min(claw_w[i], 1.0)
        new[i] = q + (p - q) * (1 + (CLAW_FAT - 1) * f)
        moved += 1
print("claws: %d verts fattened x%.2f round %d chains" % (moved, CLAW_FAT, len(chains)))

# every copy of a welded vertex takes the mean move, so seams never open
dm = np.zeros((nw, 3)); cnt = np.zeros(nw)
np.add.at(dm, wid, new - co); np.add.at(cnt, wid, 1)
new = co + (dm / cnt[:, None])[wid]
lco = (new - MW[:3, 3]) @ np.linalg.inv(MW[:3, :3]).T
me.vertices.foreach_set("co", lco.ravel())
me.update()
print("height %.3f (was %.3f)" % (new[:, 2].max() - new[:, 2].min(), co[:, 2].max() - co[:, 2].min()))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("SHAPED", OUT)
