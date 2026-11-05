# Repaints the chibi heretic's texture into flat bold regions (round 40, chibi pass 2). Meshy's
# retexture left blotches (wine patches on the claw, dark scribbles on the boots, crimson bits in the
# skirt hem, fold lines on the hood and scarf). Every triangle gets a region from its old colour and
# its bones, small islands of one region inside another are merged away, then each region is painted
# in 2-3 flat tones: one body tone plus design bands (the hood's crimson lining, the scarf's ends, boot soles and cuffs,
# the claw's void tips), never shading. Writes a PNG and the blend with the new pixels packed in,
# ready for chibi_keys.py. Same mesh, bones, UVs and clips.
#   blender -b <heretic_chibi_baked.blend> -P chibi_repaint.py -- <out.png> <out.blend> [--debug]
import bpy, sys, colorsys
import numpy as np
from collections import Counter, defaultdict

args = sys.argv[sys.argv.index("--") + 1:]
OUT_PNG, OUT_BLEND = args[0], args[1]
DEBUG = "--debug" in args

# The palette (linear-ish sRGB 0..1, as written into the texture). comic_toon multiplies these by the
# cut tones (ComicLook.PAINTED: lilac shadow, 0.8 mid, white light), so keep values up against the
# indigo floor (about 0.16, 0.14, 0.3). Claw tones are scripts/fx_palette.gd's void.
VOID_DEEP, VOID_BODY, VOID_LIGHT = (0.3, 0.1, 0.56), (0.62, 0.3, 1.0), (1.0, 0.52, 0.95)
TONES = {
    "hood": (0.95, 0.91, 0.8), "lining": (0.55, 0.07, 0.14),
    "face": (0.045, 0.035, 0.085), "eye": (0.4, 1.0, 0.95),
    "scarf": (0.84, 0.17, 0.2), "scarf_end": (0.64, 0.09, 0.15),
    "sash": (0.6, 0.08, 0.15), "sash_end": (0.48, 0.06, 0.13),
    "tunic": (0.12, 0.6, 0.62), "tunic_hem": (0.06, 0.42, 0.48), "sleeve": (0.06, 0.42, 0.48),
    "boot": (0.78, 0.7, 0.58), "boot_cuff": (0.58, 0.5, 0.45), "boot_sole": (0.28, 0.22, 0.3),
    "glove": (0.78, 0.7, 0.58), "wrap": (0.78, 0.7, 0.58),
    "trousers": (0.26, 0.17, 0.34), "skirt": (0.38, 0.2, 0.44), "skirt_hem": (0.25, 0.12, 0.32),
    "claw": VOID_BODY, "claw_tip": VOID_LIGHT, "claw_root": VOID_DEEP,
}
DEBUG_TONES = {"hood": (1, 1, 1), "lining": (1, .5, 0), "face": (0, 0, 0), "eye": (0, 1, 1),
               "claw": (1, 0, 1), "claw_tip": (1, .7, 1), "claw_root": (.5, 0, .5), "scarf": (1, 1, 0), "scarf_end": (.7, .7, 0),
               "sash": (1, 0, 0), "sash_end": (.6, 0, 0), "tunic": (0, .6, .6), "tunic_hem": (0, .3, .3), "sleeve": (0, .8, 0),
               "boot": (.6, .4, .2), "boot_cuff": (.4, .25, .1), "boot_sole": (.2, .1, 0), "glove": (.9, .6, .3),
               "wrap": (.4, .4, 1), "skirt": (.4, 0, .5), "skirt_hem": (.25, 0, .3), "trousers": (.1, .1, .4)}
MIN_ISLAND = 25        # triangles: a same-region patch smaller than this takes its neighbours' region
SOLE_Z = 0.045         # m: boot below this is the sole
CUFF = 0.05            # m below the top of the boot: the cuff band
SCARF_END_Z = 0.9      # m: the scarf's hanging ends below this
SASH_END_Z = 0.6
TUNIC_HEM_Z = 0.66
SKIRT_HEM = 0.3        # of the skirt's height from its lowest point
TIP_W = 0.5            # weight on a claw's last bone past which it is the tip
CLAW_X = -0.34         # m: everything past the right wrist (rest pose) is claw, whatever the old paint
CLAW_Y = -0.2          # m: and everything this far ahead of him (the claw is held out in front at rest)
ROOT_R = 0.075         # m round the wrist joint: the claw's root band, a cuff where it leaves the sleeve

ob = bpy.data.objects["heretic"]
me = ob.data
img = bpy.data.images[0]
W, H = img.size
px = np.array(img.pixels[:], np.float32).reshape(H, W, img.channels)
MW = np.array(ob.matrix_world)
nv = len(me.vertices)
co = np.zeros(nv * 3); me.vertices.foreach_get("co", co); co = co.reshape(nv, 3) @ MW[:3, :3].T + MW[:3, 3]
names = [g.name for g in ob.vertex_groups]
Wt = np.zeros((nv, len(names)), np.float32)
for v in me.vertices:
    for g in v.groups:
        Wt[v.index, g.group] = g.weight
me.calc_loop_triangles()
tv = np.array([list(t.vertices) for t in me.loop_triangles], np.int32)
uvd = me.uv_layers[0].data
tuv = np.array([[list(uvd[l].uv) for l in t.loops] for t in me.loop_triangles], np.float32)
T = len(tv)


def vw(pred):
    idx = [i for i, n in enumerate(names) if pred(n)]
    return Wt[:, idx].sum(1)


def tw(w):
    return w[tv].mean(1)


last_claw = set()
for tip in ("main", "up", "out", "mid", "low", "back"):
    chain = sorted(n for n in names if n.startswith("tent.%s." % tip))
    last_claw.update(chain[-2:] if len(chain) > 3 else chain[-1:])
w_head = vw(lambda n: n in ("head", "neck"))
w_claw = vw(lambda n: n.startswith(("hand.r", "tent.", "wrist.r")))
w_tip = vw(lambda n: n in last_claw)
arm_ob = bpy.data.objects["Armature"]
wrist = np.array(arm_ob.matrix_world @ arm_ob.data.bones["wrist.r"].head_local)
w_root = np.linalg.norm(co - wrist, axis=1)   # distance, not a weight
w_feet = vw(lambda n: n.startswith(("foot", "toes")))
w_legs = vw(lambda n: n.startswith(("upperleg", "lowerleg")))
w_skirt = vw(lambda n: n.startswith("skirt."))
w_handl = vw(lambda n: n in ("hand.l", "wrist.l", "lowerarm.l", "handslot.l"))
w_forearm = vw(lambda n: n in ("lowerarm.r",))
c = co[tv].mean(1)


# ---- each triangle's old colour: the median of the texels inside it
def tri_texels(q, grow=0.0):
    x0, y0 = np.maximum(np.floor(q.min(0)).astype(int) - 1, 0)
    x1, y1 = np.minimum(np.ceil(q.max(0)).astype(int) + 1, [W - 1, H - 1])
    (ax, ay), (bx, by), (cx, cy) = q
    dd = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(dd) < 1e-9 or x1 < x0 or y1 < y0:
        return None
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
    l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / dd
    l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / dd
    l3 = 1 - l1 - l2
    m = (l1 >= -grow) & (l2 >= -grow) & (l3 >= -grow)
    return x0, y0, x1, y1, m, np.clip(np.stack([l1, l2, l3], -1), 0, 1)


med = np.zeros((T, 3), np.float32)
for i, p in enumerate(tuv):
    r = tri_texels(p * [W, H])
    if r is None or r[4].sum() == 0:
        q = (p.mean(0) * [W, H]).astype(int)
        med[i] = px[min(q[1], H - 1), min(q[0], W - 1), :3]
    else:
        x0, y0, x1, y1, m, _ = r
        med[i] = np.median(px[y0:y1 + 1, x0:x1 + 1, :3][m], 0)
hsv = np.array([colorsys.rgb_to_hsv(*q) for q in med])
h, s, v = hsv.T
cls = np.full(T, "dark", object)
cls[(h > .36) & (h < .45) & (s > .4) & (v > .08)] = "green"
cls[(h > .45) & (h < .56) & (s > .5) & (v > .15)] = "teal"
cls[((h > .88) | (h < .03)) & (s > .45) & (v > .2)] = "crimson"
cls[(h > .78) & (h < .88) & (s > .45) & (v > .35)] = "magenta"
cls[(h > .04) & (h < .14) & (s > .17) & (s < .55) & (v > .3)] = "beige"
cls[(s < .2) & (v > .75)] = "white"
cls[(h > .4) & (h < .56) & (s > .3) & (v > .55)] = "cyan"
cls[v < .07] = "black"

# ---- regions
head, claw, feet, legs, skirt = tw(w_head), tw(w_claw), tw(w_feet), tw(w_legs), tw(w_skirt)
handl, forearm = tw(w_handl), tw(w_forearm)
lab = np.full(T, "?", object)
for i in range(T):
    k = cls[i]
    if claw[i] > .5 or (claw[i] > .25 and k in ("magenta", "crimson", "dark", "black")) or ((c[i, 0] < CLAW_X or c[i, 1] < CLAW_Y) and head[i] < .5):
        lab[i] = "claw"
    elif head[i] > .5:
        lab[i] = {"white": "hood", "beige": "hood", "crimson": "lining", "black": "face", "dark": "face", "cyan": "eye"}.get(k, "?")
    elif k == "white":
        lab[i] = "scarf"
    elif k == "crimson":
        # the red slivers in the skirt's hem are Meshy's layering, not the sash's front panel
        lab[i] = "skirt" if c[i, 2] < 0.5 and abs(c[i, 0] - 0.01) > 0.09 and skirt[i] > .3 else "sash"
    elif k == "teal":
        lab[i] = "tunic"
    elif k == "green":
        lab[i] = "sleeve"
    elif k == "beige":
        lab[i] = ("boot" if (c[i, 2] < 0.32 or feet[i] > .3) else "glove" if handl[i] > .4
                  else "wrap" if forearm[i] > .4 else "?")
    elif k in ("dark", "black"):
        lab[i] = "skirt" if skirt[i] > .4 else "trousers" if (legs[i] + feet[i]) > .5 and c[i, 2] < 0.62 else "?"

# adjacency through welded positions (the mesh is split at UV seams)
key = {}
wid = np.array([key.setdefault(tuple(p), len(key)) for p in np.round(co, 4)])
vt = defaultdict(list)
for t, vs in enumerate(wid[tv]):
    for x in vs:
        vt[x].append(t)
adj = [set() for _ in range(T)]
for ts in vt.values():
    for t in ts:
        adj[t].update(ts)
adj = [list(a - {t}) for t, a in enumerate(adj)]
for it in range(30):
    unk = np.nonzero(lab == "?")[0]
    if len(unk) == 0:
        break
    new = lab.copy()
    for t in unk:
        cnt = Counter(lab[a] for a in adj[t] if lab[a] != "?")
        if cnt:
            new[t] = cnt.most_common(1)[0][0]
    lab[:] = new
lab[lab == "?"] = "trousers"
for rnd in range(6):
    seen = np.zeros(T, bool)
    changed = 0
    for t0 in range(T):
        if seen[t0]:
            continue
        comp = [t0]
        seen[t0] = True
        i = 0
        while i < len(comp):
            for a in adj[comp[i]]:
                if not seen[a] and lab[a] == lab[t0]:
                    seen[a] = True
                    comp.append(a)
            i += 1
        if len(comp) < MIN_ISLAND and lab[t0] != "eye":
            cs = set(comp)
            cnt = Counter(lab[a] for t in comp for a in adj[t] if a not in cs)
            if cnt:
                lab[comp] = cnt.most_common(1)[0][0]
                changed += 1
    if not changed:
        break
print("regions", Counter(lab).most_common())

# ---- per-vertex fields for the bands, interpolated per texel
boot_top = np.percentile(c[lab == "boot", 2], 99)
sk = c[lab == "skirt", 2]
skirt_hem_z = sk.min() + (np.percentile(sk, 98) - sk.min()) * SKIRT_HEM
FIELDS = np.stack([co[:, 2], w_tip, w_root], 1)   # z, tip weight, distance from the wrist


def tone(label, f):
    """Per-texel tone name from the triangle's region and the interpolated fields (z, tip, root)."""
    z, tip, root = f[..., 0], f[..., 1], f[..., 2]
    out = np.full(z.shape, label, object)
    if label == "claw":
        out[root < ROOT_R] = "claw_root"
        out[tip > TIP_W] = "claw_tip"
    elif label == "boot":
        out[z > boot_top - CUFF] = "boot_cuff"
        out[z < SOLE_Z] = "boot_sole"
    elif label == "scarf":
        out[z < SCARF_END_Z] = "scarf_end"
    elif label == "sash":
        out[z < SASH_END_Z] = "sash_end"
    elif label == "tunic":
        out[z < TUNIC_HEM_Z] = "tunic_hem"
    elif label == "skirt":
        out[z < skirt_hem_z] = "skirt_hem"
    return out


pal = DEBUG_TONES if DEBUG else TONES
tex = np.zeros((H, W, 3), np.float32)
have = np.zeros((H, W), bool)
for i, p in enumerate(tuv):
    r = tri_texels(p * [W, H], 0.02)
    if r is None:
        continue
    x0, y0, x1, y1, m, bary = r
    if not m.any():
        continue
    f = bary[m] @ FIELDS[tv[i]]
    names_ = tone(lab[i], f)
    cols = np.array([pal[n] for n in names_], np.float32)
    tex[y0:y1 + 1, x0:x1 + 1][m] = cols
    have[y0:y1 + 1, x0:x1 + 1] |= m
# pad outward so mips and bilinear never pull in an unpainted texel
for it in range(24):
    if have.all():
        break
    grown = tex.copy()
    hv = have.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(have, (dy, dx), (0, 1))
        st = np.roll(tex, (dy, dx), (0, 1))
        take = sh & ~hv
        grown[take] = st[take]
        hv |= take
    tex, have = grown, hv
tex[~have] = TONES["trousers"]
px[..., :3] = tex
img.pixels.foreach_set(px.ravel())
img.update()
out = bpy.data.images.new("repaint_out", W, H)
out.pixels.foreach_set(px.ravel() if img.channels == 4 else np.dstack([px, np.ones((H, W, 1), np.float32)]).ravel())
out.filepath_raw = OUT_PNG
out.file_format = "PNG"
out.save()
bpy.data.images.remove(out)
img.pack()
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("REPAINTED", OUT_PNG, OUT_BLEND, "boot top %.2f skirt hem %.2f" % (boot_top, skirt_hem_z))
