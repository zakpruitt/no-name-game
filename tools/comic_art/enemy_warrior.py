# Skeleton Warrior: the heavy melee. Bull-horned helm, huge pauldrons, iron barrel chest, a greatsword he drags.
#   blender -b -P enemy_warrior.py
# Front -Y, its left +X, up +Z. Geometry, rig, animations, sheets, export, same as enemy_minion.py.
# The model is built at scale 1.0: the game applies model_scale 1.15 itself (main.ENEMY_TYPES), so it is NOT baked into
# the .glb. The proof renders do apply it (MODEL_SCALE on the armature, reset before export) so they show the game size.
# Animation: poses are stated in the world and solved for every frame (as enemy_shield.py), so feet stay planted.
# Clip timing: enemy.gd lands the chop at 45% of the clip's length, so the hit is at frame 20 of 44.
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Quaternion as Q, Euler
NAME = 'warrior'
MODEL_SCALE = 1.15
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['rust'] = C.toon('P_Rust', (.14, .04, .03), (.55, .24, .09), (.8, .45, .2), (1, .82, .55), rim=(.3, .12, .04), brush=.3)
M['iron'] = C.toon('P_IronPlain', (.05, .06, .14), (.2, .25, .38), (.46, .54, .68), (.86, .92, 1), rim=(.18, .3, .5), brush=.16, inner=.2)  # P_Iron carries the shaman's crack veins
M['steel'] = C.toon('P_Steel', (.08, .1, .2), (.3, .36, .5), (.56, .64, .76), (.8, .86, .92), rim=(.26, .36, .5), brush=.16, inner=.1)
C.rng.seed(11)

CUR = 'hips'
class TB(C.Bag):
    """A bag that remembers which bone each piece was built for."""
    def __init__(s, *a, **k):
        super().__init__(*a, **k); s.parts = []
    def add(s, vs, fs, ts=None):
        n = len(s.v); super().add(vs, fs, ts); s.parts.append((n, len(s.v), CUR))
B = {k: TB(k) for k in ('bone', 'socket', 'teeth', 'iron', 'bronze', 'leather', 'cloth', 'necro', 'rust')}
B['steel'] = TB('steel', smooth=False)
b = B['bone']

# ---- joints: upright and wide, chest out, skull sunk forward between the shoulders
hip = V((0, .02, .86)); chest = V((0, -.02, 1.26)); neck = V((0, -.1, 1.44)); H = V((0, -.2, 1.6))
shL, elL, wrL = V((.36, -.04, 1.38)), V((.55, -.02, 1.07)), V((.6, -.24, .85))
shR, elR, wrR = V((-.36, -.04, 1.38)), V((-.58, .02, 1.12)), V((-.7, -.22, .96))
hdL = wrL + V((.01, -.05, -.1)); hdR = wrR + V((-.03, -.07, -.06))
hpL, knL, anL = V((.17, .02, .82)), V((.27, -.12, .47)), V((.3, .02, .12))
hpR, knR, anR = V((-.17, .02, .82)), V((-.27, -.12, .47)), V((-.3, .02, .12))
J0 = H + V((0, -.1, -.13))

# ---- skull: same face as the minion, under an iron helm whose brim stops above the eyes
CUR = 'head'
C.blob(b, H + V((0, .02, .04)), (.2, .22, .17), seg=12, rings=8)
C.blob(b, H + V((0, -.12, -.03)), (.14, .1, .105), seg=12, rings=7)
for sx in (-1, 1):
    C.blob(b, H + V((sx * .135, -.09, -.02)), (.05, .05, .045), seg=8, rings=5)
    C.blob(B['socket'], H + V((sx * .078, -.185, .022)), (.068, .03, .056), seg=10, rings=6)
    C.blob(B['necro'], H + V((sx * .078, -.212, .022)), (.028, .012, .026), seg=8, rings=5, t=.9)
C.blob(B['socket'], H + V((0, -.215, -.045)), (.024, .012, .03), seg=7, rings=5)
for i in range(7):
    x = -.09 + i * .03
    C.blob(B['teeth'], H + V((x, -.2 + abs(x) * .4, -.1)), (.0135, .012, .022), seg=6, rings=4)
CUR = 'jaw'
C.tube(b, [H + V((-.13, -.04, -.07)), J0 + V((-.1, -.04, -.03)), J0 + V((0, -.1, -.05)), J0 + V((.1, -.04, -.03)), H + V((.13, -.04, -.07))], [.026, .036, .04, .036, .026], sides=6, sub=2)
for i in range(5):
    x = -.06 + i * .03
    C.blob(B['teeth'], J0 + V((x, -.1 + abs(x) * .4, -.012)), (.012, .011, .018), seg=6, rings=4)

# helm: a heavy dome, a brow that snarls down to a nasal, a bronze band, cheek plates, bull horns
CUR = 'head'
ir = B['iron']; br = B['bronze']
C.blob(ir, H + V((0, .03, .1)), (.245, .26, .195), seg=14, rings=8)
for sx in (-1, 1):
    C.tube(ir, [H + V((0, -.215, .135)), H + V((sx * .1, -.222, .095)), H + V((sx * .2, -.16, .085)), H + V((sx * .26, -.03, .08))], [(.045, .03), (.04, .03), (.036, .028), (.03, .026)], sides=6, sub=2)
    C.tube(ir, [H + V((sx * .225, -.08, .08)), H + V((sx * .205, -.1, -.03)), H + V((sx * .15, -.14, -.1))], [(.05, .022), (.05, .02), (.012, .012)], sides=5, sub=1, side=V((0, 1, 0)))
    # bull horn: out, then up, thick at the root, the widest thing on the head
    C.tube(br, [H + V((sx * .21, .02, .12)), H + V((sx * .34, -.0, .13)), H + V((sx * .45, -.05, .21)), H + V((sx * .49, -.11, .35)), H + V((sx * .44, -.16, .47))], [.066, .058, .044, .026, .003], sides=7, sub=2)
    C.tube(ir, [H + V((sx * .19, .02, .12)), H + V((sx * .25, .015, .12))], [.078, .082], sides=8, sub=1)
C.tube(ir, [H + V((0, -.222, .12)), H + V((0, -.245, .03)), H + V((0, -.238, -.03))], [(.034, .02), (.024, .02), (.008, .012)], sides=5, sub=1)
C.tube(br, [H + V((.245 * math.cos(i * .524), .03 + .26 * math.sin(i * .524), .075)) for i in range(13)], [(.018, .026)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
C.tube(br, [H + V((0, -.2, .17)), H + V((0, -.11, .285)), H + V((0, .06, .31)), H + V((0, .24, .2))], [(.026, .02), (.032, .022), (.032, .022), (.022, .018)], sides=6, sub=2, side=V((1, 0, 0)))
for a_ in (-2.3, -.84):
    C.blob(br, H + V((.235 * math.cos(a_), .03 + .25 * math.sin(a_), .15)), (.022, .022, .022), seg=6, rings=4)
C.blob(B['rust'], H + V((.11, -.12, .21)), (.09, .08, .05), seg=8, rings=5, rot=(.7, .2, 0))

# ---- body: vertebrae and low ribs show under the plate, the plate is a barrel, the waist is bone
CUR = 'spine'
vb = [hip.lerp(chest, i / 5) for i in range(6)]
for i, p in enumerate(vb):
    C.blob(b, p + V((0, .05, 0)), (.055, .055, .04), seg=8, rings=5)
for i in range(3):
    z = 1.14 - i * .065; w = .22 - i * .025
    for sx in (-1, 1):
        C.tube(b, [V((sx * .01, .02, z + .03)), V((sx * w, -.03, z)), V((sx * w * .85, -.15, z - .04)), V((sx * .08, -.22, z - .05))], [.02, .024, .022, .012], sides=5, sub=2)
CUR = 'chest'
C.tube(b, [chest + V((0, .05, 0)), neck, H + V((0, .03, -.1))], [.05, .046, .042], sides=6, sub=1)
C.blob(ir, chest + V((0, -.03, .04)), (.32, .25, .26), seg=16, rings=9, p=2.5)
C.tube(br, [chest + V((0, -.292, .2)), chest + V((0, -.302, .06)), chest + V((0, -.268, -.13)), chest + V((0, -.2, -.215))], [(.026, .018), (.03, .02), (.03, .02), (.012, .012)], sides=5, sub=2, side=V((1, 0, 0)))
for sx in (-1, 1):
    C.tube(br, [chest + V((sx * .13, -.25, .17)), chest + V((sx * .25, -.2, .13)), chest + V((sx * .34, -.09, .1))], [(.018, .012), (.016, .012), (.012, .01)], sides=5, sub=1)
C.blob(B['rust'], chest + V((.15, -.225, -.06)), (.11, .07, .09), seg=8, rings=5, p=2.2, rot=(.2, 0, .3))
C.blob(B['rust'], chest + V((-.18, -.2, .1)), (.07, .08, .05), seg=8, rings=5, rot=(.1, 0, -.5))
C.tube(ir, [chest + V((-.23, -.07, .25)), chest + V((0, -.21, .25)), chest + V((.23, -.07, .25))], [(.05, .05), (.08, .05), (.05, .05)], sides=7, sub=2)  # gorget
C.blob(ir, chest + V((0, .13, .1)), (.26, .14, .18), seg=10, rings=6, p=2.3)                                              # back plate hump
CUR = 'hips'
C.blob(b, hip + V((0, 0, -.04)), (.23, .15, .1), seg=12, rings=6, p=2.3)
C.tube(B['leather'], [hip + V((.25 * math.cos(i * .524), .17 * math.sin(i * .524) - .01, .05)) for i in range(13)], [(.05, .018)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
C.blob(br, hip + V((0, -.185, .05)), (.08, .03, .08), seg=8, rings=5, p=2.6)
C.blob(B['necro'], hip + V((0, -.21, .05)), (.024, .012, .024), seg=6, rings=4, t=.9)
# faulds: iron lames on the hips, teal skirt strips under them (the colour the minion wears)
for i in range(6):
    a_ = -2.75 + i * .466 + (.0 if i < 3 else .0)
    o = V((math.cos(a_), math.sin(a_) * .75, 0))
    q = hip + V((o.x * .23, o.y * .17 - .01, .02))
    C.tube(ir, [q, q + o * .05 - V((0, 0, .2))], [(.07, .012), (.062, .012)], sides=5, sub=1, side=o.cross(V((0, 0, 1))))
CUR = 'SOFT'
for i in range(9):
    a_ = -2.95 + i * .36
    o = V((math.cos(a_), math.sin(a_) * .8, 0))
    q = hip + V((o.x * .2, o.y * .15 - .02, -.08))
    L = C.rng.uniform(.3, .44)
    C.tube(B['cloth'], [q, q + o * .05 - V((0, 0, L * .5)), q + o * .08 - V((0, 0, L))], [(.056, .007), (.06, .007), (.002, .002)], sides=5, sub=2, side=o.cross(V((0, 0, 1))))

# ---- limbs: bone upper arm, iron forearm, big gauntlets. Bare femur, iron knee, greave, sabaton
def limb(tag, a, c, r=.038, k=.06, kc=None):
    global CUR; CUR = tag
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5)
    if kc: C.blob(b, c, (kc, kc, kc), seg=8, rings=5)
limb('upperarm.l', shL, elL, kc=.056); limb('upperarm.r', shR, elR, kc=.056)
limb('upperleg.l', hpL, knL, .052, .074); limb('upperleg.r', hpR, knR, .052, .074)
def vambrace(tag, el, wr, sx):
    global CUR; CUR = tag
    d = (wr - el).normalized()
    C.tube(ir, [el + d * .06, el.lerp(wr, .55), wr - d * .0], [(.06, .056), (.082, .074), (.09, .08)], sides=8, sub=1)
    C.tube(br, [wr - d * .035, wr + d * .0], [(.098, .088), (.098, .088)], sides=8, sub=1)
    C.tube(ir, [el + d * .08 + V((sx * .05, 0, 0)), el + V((sx * .15, -.0, .08))], [.03, .002], sides=5, sub=1)  # elbow spike
    C.blob(ir, el, (.075, .075, .075), seg=8, rings=5)
vambrace('lowerarm.l', elL, wrL, 1); vambrace('lowerarm.r', elR, wrR, -1)
def gauntlet(tag, w, h, side):
    global CUR; CUR = tag
    d = (h - w).normalized()
    C.blob(ir, w + d * .07, (.082, .082, .074), seg=8, rings=5, p=2.4)
    for i in range(4):
        o = side * (i - 1.5) * .038
        C.blob(ir, w + d * .15 + o, (.022, .03, .026), seg=6, rings=4)
gauntlet('hand.l', wrL, hdL, V((0, 1, 0))); gauntlet('hand.r', wrR, hdR, V((0, 0, 1)))
def greave(tag, kn, an, sx):
    global CUR; CUR = tag
    d = (an - kn).normalized()
    C.tube(ir, [kn + d * .04, kn.lerp(an, .45), an], [(.075, .07), (.094, .088), (.078, .074)], sides=8, sub=1)
    C.blob(ir, kn + V((0, -.03, .01)), (.085, .085, .08), seg=8, rings=5, p=2.2)                 # knee cop
    C.tube(br, [kn + V((-.03, -.1, .0)), kn + V((0, -.115, .0)), kn + V((.03, -.1, .0))], [.018, .022, .018], sides=5, sub=1)
    C.tube(ir, [kn + V((sx * .02, -.09, .06)), kn + V((sx * .02, -.17, .15))], [.03, .002], sides=5, sub=1)    # knee spike
greave('lowerleg.l', knL, anL, 1); greave('lowerleg.r', knR, anR, -1)
def sabaton(tag, an):
    global CUR; CUR = tag
    C.blob(ir, an + V((0, -.08, -.055)), (.108, .17, .062), seg=10, rings=6, p=2.4)
    C.tube(br, [an + V((-.09, -.02, -.05)), an + V((0, -.2, -.04)), an + V((.09, -.02, -.05))], [.012, .016, .012], sides=5, sub=2)
sabaton('foot.l', anL); sabaton('foot.r', anR)

# ---- pauldrons: stacked plates and spikes, the widest thing on the body. Own bones: they follow the arm part-way
def pauldron(tag, sh, sx):
    global CUR; CUR = tag
    r0 = Euler((0, sx * -.32, 0)).to_matrix(); c0 = sh + V((sx * .06, 0, .06))
    C.blob(ir, c0, (.215, .2, .13), seg=14, rings=7, p=2.5, rot=(0, sx * -.32, 0))
    C.blob(ir, sh + V((sx * .15, 0, -.04)), (.135, .175, .08), seg=12, rings=6, p=2.4, rot=(0, sx * -.62, 0))
    # the bronze rim follows the plate's tilt and sits on its lower edge
    C.tube(br, [c0 + r0 @ V((.212 * math.cos(i * .524), .198 * math.sin(i * .524), -.03)) for i in range(13)], [(.016, .02)] * 2, sides=5, sub=1)
    for ox, oy, ln in ((.08, -.1, .17), (.13, .02, .24), (.07, .11, .18)):
        base_ = sh + V((sx * ox, oy, .13))
        C.tube(ir, [base_, base_ + V((sx * ln * .4, oy * .15, ln))], [.042, .003], sides=6, sub=1)
        C.tube(br, [base_ - V((0, 0, .015)), base_ + V((0, 0, .012))], [.05, .046], sides=6, sub=1)
    C.blob(B['rust'], sh + V((sx * .13, -.13, .09)), (.065, .05, .04), seg=7, rings=4, rot=(.3, sx * -.3, 0))
pauldron('pauldron.l', shL, 1); pauldron('pauldron.r', shR, -1)

# ---- greatsword: heavy, chipped, blade turned flat to the game camera. Dragged low, point near the floor
sd = V((-.62, -.44, -.65)).normalized()               # hand to point
VIEW = V((0, .58, -.81)).normalized()
wd = sd.cross(VIEW).normalized()                     # the width of the blade
fc = wd.cross(sd).normalized()                       # the flat
G0 = hdR
def blade(bag, a, d, w, f, stations):
    """Rings of (along, left edge, ridge height, right edge): flat shaded, so the two bevels cut like comic tones."""
    vs, fs = [], []
    for s_, l_, h_, r_ in stations:
        p = a + d * (.16 + (s_ - .16) * .9)
        vs += [p + w * l_, p + f * h_, p - w * r_, p - f * h_]
    n = len(stations)
    for i in range(n - 1):
        for k in range(4):
            j = i * 4
            fs.append((j + k, j + (k + 1) % 4, j + 4 + (k + 1) % 4, j + 4 + k))
    fs.append(tuple(reversed(range(4)))); fs.append(tuple(range((n - 1) * 4, n * 4)))
    bag.add(vs, fs)
CUR = 'weapon'
blade(B['steel'], G0, sd, wd, fc, [(.16, .11, .03, .11), (.28, .125, .032, .125), (.42, .135, .032, .14), (.49, .08, .032, .14), (.53, .135, .032, .14), (.72, .14, .032, .13), (.78, .14, .032, .075), (.82, .14, .032, .125), (.98, .125, .028, .115), (1.09, .085, .02, .08), (1.18, .004, .004, .004)])
for sg in (1, -1):
    C.tube(B['socket'], [G0 + sd * .17 + fc * sg * .031, G0 + sd * .45 + fc * sg * .032, G0 + sd * .74 + fc * sg * .03], [(.016, .003), (.018, .003), (.002, .001)], sides=4, sub=1, side=wd)
C.tube(B['rust'], [G0 + sd * .55 + wd * .11 + fc * .02, G0 + sd * .63 + wd * .085 + fc * .026, G0 + sd * .7 + wd * .115 + fc * .02], [.034, .044, .01], sides=5, sub=1)
C.tube(B['rust'], [G0 + sd * .8 - wd * .095 + fc * .02, G0 + sd * .87 - wd * .085 + fc * .022], [.028, .014], sides=5, sub=1)
C.tube(br, [G0 + sd * .13 + wd * .26 + sd * .05, G0 + sd * .13 + wd * .12, G0 + sd * .13, G0 + sd * .13 - wd * .12, G0 + sd * .13 - wd * .26 + sd * .05], [.016, .036, .05, .036, .016], sides=6, sub=2)  # guard
C.blob(B['necro'], G0 + sd * .13 + fc * .05, (.026, .026, .026), seg=6, rings=4, t=.9)
C.tube(B['leather'], [G0 + sd * .13, G0 - sd * .21], [.034, .03], sides=6, sub=1)
for i in range(3):
    C.tube(B['leather'], [G0 - sd * (.02 + i * .08) - wd * .04, G0 - sd * (.0 + i * .08) + wd * .04], [.038, .038], sides=6, sub=1)
C.blob(br, G0 - sd * .24, (.052, .052, .052), seg=8, rings=5, p=2.6)

col = scn.collection
objs = {}
for k, bag in B.items():
    if not bag.v: continue
    outline = 0 if k in ('socket', 'necro', 'teeth') else .006
    objs[k], _t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()))

# ------------------------------------------------------------------ rig
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, -.02, .12)), 'root'),
    'spine': (hip + V((0, -.02, .12)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .02, -.15)), H + V((0, -.02, .25)), 'chest'),
    'jaw': (H + V((0, -.03, -.08)), J0 + V((0, -.12, -.03)), 'head'),
    'pauldron.l': (shL, shL + V((.25, 0, .1)), 'chest'), 'pauldron.r': (shR, shR + V((-.25, 0, .1)), 'chest'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'weapon': (G0, G0 + sd * .5, 'hand.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.18, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.18, -.08)), 'lowerleg.r'),
    'cloth': (hip + V((0, -.1, -.08)), hip + V((0, -.12, -.42)), 'hips'),
}
R = CR.Rig('WarriorRig', bones)
def skin(o, bag):
    groups = {}
    for s_, e_, bn in bag.parts:
        for i in range(s_, e_):
            if bn == 'SOFT':
                ds = sorted((max(CR.seg_dist(o.data.vertices[i].co, *R.seg[n]), .012), n) for n in ('hips', 'cloth'))
                R._put(o, groups, i, [(1 / d ** 3, n) for d, n in ds])
            else:
                R._put(o, groups, i, [(1, bn)])
    R._bind(o)
for k, bag in B.items():
    if bag.v: skin(objs[k], bag)
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ pose solver
HEAD0 = {n: bones[n][0] for n in bones}
def rel(child, parent, parent_pos, D_p): return parent_pos + D_p @ (HEAD0[child] - HEAD0[parent])
def qe(r): return Euler([math.radians(a) for a in r], 'XYZ').to_quaternion()
def deg(q): return tuple(math.degrees(a) for a in q.to_euler('XYZ'))
def two_bone(a, k, c, A, T, pole):
    L1, L2 = (k - a).length, (c - k).length
    d = T - A; D = max(min(d.length, (L1 + L2) * .998), abs(L1 - L2) * 1.02 + .01)
    u = d.normalized()
    ca = (L1 * L1 + D * D - L2 * L2) / (2 * L1 * D)
    h = L1 * math.sqrt(max(0, 1 - ca * ca))
    p = pole - u * pole.dot(u)
    if p.length < 1e-5: p = V((0, -1, 0)) - u * u.y
    p.normalize()
    return A + u * (L1 * ca) + p * h, A + u * D
def rest_pole(a, k, c):
    u = (c - a).normalized(); v = k - a
    return (v - u * v.dot(u)).normalized()
POLE = {'L': rest_pole(hpL, knL, anL), 'R': rest_pole(hpR, knR, anR)}
ARMPOLE = {'l': V((.8, .5, -.3)).normalized(), 'r': V((-.8, .5, -.3)).normalized()}
GRIP2 = G0 - sd * .15  # where the left hand joins on the two-handed swing
EMPTY = dict(hr=(0, 0, 0), hl=(0, 0, 0), sp=(0, 0, 0), ch=(0, 0, 0), hd=(0, 0, 0), Hl=(0, 0, 0), jw=(0, 0, 0), cl=(0, 0, 0),
             L=(0, 0, 0), R=(0, 0, 0), Lp=(0, 0, 0), Rp=(0, 0, 0), Wr=(0, 0, 0), Wl=(0, 0, 0), Al=(0, 0, 0), Lg=(0, 0, 0),
             Lk=tuple(POLE['L']), Rk=tuple(POLE['R']))
ROTS = ('hr', 'sp', 'ch', 'hd', 'jw', 'cl', 'Lp', 'Rp', 'Wr')
EPS = V((3e-6, 0, 0))  # forces location curves into every action, so an offset never leaks across clips
def arm(a, e, w, A, T, pole, Dc):
    ek, en = two_bone(a, e, w, A, T, pole)
    Du = (e - a).rotation_difference(ek - A); Dl = (w - e).rotation_difference(en - ek)
    return deg(Dc.inverted() @ Du), deg(Du.inverted() @ Dl), Du, Dl
def solve(p):
    out = {}
    Dh = p['hr']; Ph = HEAD0['hips'] + V(p['hl'])
    out['hips'] = {'rot': deg(Dh), 'loc': tuple(p['hl'])}
    Ds = Dh @ p['sp']; Ps = rel('spine', 'hips', Ph, Dh); out['spine'] = deg(p['sp'])
    Dc = Ds @ p['ch']; Pc = rel('chest', 'spine', Ps, Ds); out['chest'] = deg(p['ch'])
    Dhead = p['hd']; hl = Dc.inverted() @ V(p['Hl'])
    out['head'] = {'rot': deg(Dc.inverted() @ Dhead), 'loc': tuple(hl + EPS)}
    out['jaw'] = deg(p['jw']); out['cloth'] = deg(p['cl'])
    # sword arm: wrist position and blade rotation in the world
    Dw = p['Wr']; Tw = wrR + V(p['Wl'])
    Asr = rel('upperarm.r', 'chest', Pc, Dc)
    ur, lr, Du, Dl = arm(shR, elR, wrR, Asr, Tw, ARMPOLE['r'], Dc)
    out['upperarm.r'] = ur; out['lowerarm.r'] = lr; out['hand.r'] = deg(Dl.inverted() @ Dw)
    out['pauldron.r'] = deg(Q().slerp(Dc.inverted() @ Du, .4))
    # off arm: free, or blended onto the hilt
    grip = (en_ := Asr) and (Tw + Dw @ (GRIP2 - wrR))
    k = V(p['Lg']).x
    Tl = (wrL + V(p['Al'])).lerp(grip, k)
    Asl = rel('upperarm.l', 'chest', Pc, Dc)
    ul, ll, Du2, Dl2 = arm(shL, elL, wrL, Asl, Tl, ARMPOLE['l'], Dc)
    out['upperarm.l'] = ul; out['lowerarm.l'] = ll; out['hand.l'] = (0, 0, 0)
    out['pauldron.l'] = deg(Q().slerp(Dc.inverted() @ Du2, .4))
    for key, a, k_, c, nm in (('L', hpL, knL, anL, 'l'), ('R', hpR, knR, anR, 'r')):
        A = rel('upperleg.' + nm, 'hips', Ph, Dh)
        ek, en = two_bone(a, k_, c, A, c + V(p[key]), V(p[key + 'k']))
        Du_ = (k_ - a).rotation_difference(ek - A); Dl_ = (c - k_).rotation_difference(en - ek)
        out['upperleg.' + nm] = deg(Dh.inverted() @ Du_); out['lowerleg.' + nm] = deg(Du_.inverted() @ Dl_)
        out['foot.' + nm] = deg(Dl_.inverted() @ p[key + 'p'])
    return out
def spec(p):
    q = dict(EMPTY); q.update(p)
    return {k: (qe(v) if k in ROTS else V(v)) for k, v in q.items()}
def act(name, length, keys):
    items = sorted(((k if isinstance(k, tuple) else (k, 'smooth')) + (spec(v),) for k, v in keys.items()), key=lambda x: x[0])
    frames = {}
    for fr in range(length + 1):
        if fr <= items[0][0]: cur = items[0][2]
        elif fr >= items[-1][0]: cur = items[-1][2]
        else:
            for i in range(len(items) - 1):
                if items[i][0] <= fr < items[i + 1][0]:
                    t = CR._ease((fr - items[i][0]) / (items[i + 1][0] - items[i][0]), items[i + 1][1])
                    a, c = items[i][2], items[i + 1][2]
                    cur = {k: (a[k].slerp(c[k], t) if k in ROTS else a[k].lerp(c[k], t)) for k in a}
                    break
        frames[fr] = solve(cur)
    return R.action(name, length, frames)
def PP(base, **kw):
    q = dict(base); q.update(kw); return q
def aim(d):
    """Blade rotation that points the sword along d, as Euler degrees."""
    return deg(sd.rotation_difference(V(d).normalized()))

# ------------------------------------------------------------------ animation (24 fps)
# +X on the jaw drops it; hd is the skull's world rotation (-X lifts the face to the camera)
IDLE_A = dict(hr=(4, 0, 0), hl=(0, 0, -.03), ch=(2, 0, 0), hd=(-13, 0, 0), jw=(2, 0, 0), Al=(.02, 0, 0))
IDLE_B = dict(hr=(7, 0, 2), hl=(0, 0, -.075), ch=(6, 0, 3), hd=(-9, 3, 5), jw=(9, 0, 0), Al=(.03, -.02, -.05), Wl=(0, -.01, -.05), Wr=(1, 0, 3), cl=(4, 0, 0))
act('Idle_Combat', 48, {0: IDLE_A, 24: IDLE_B, 48: IDLE_A})

# the march: long heavy steps with a stomp, the shoulders roll against the hips, the sword trails behind him
DRAG = aim((-.42, .62, -.62))
def march(t):
    s = .31; sw = .36                    # stride half-length; fraction of the cycle a foot is in the air
    def fy(ph):
        ph %= 1
        if ph < sw:
            k = ph / sw; k2 = k * k * (3 - 2 * k)
            return s - 2 * s * k2, .13 * math.sin(math.pi * k) ** .8, math.sin(math.pi * k)
        return -s + 2 * s * (ph - sw) / (1 - sw), 0.0, 0.0
    ly, lz, lk = fy(t); ry, rz, rk = fy(t + .5)
    w = 2 * math.pi * t
    stomp = abs(math.sin(2 * math.pi * (t + .06))) ** 3
    return dict(hr=(8, 3.5 * math.cos(w), 9 * math.sin(w)), hl=(.05 * math.cos(w), -.05, -.075 + .032 * math.cos(2 * w) - .018 * stomp),
                ch=(8, -2 * math.cos(w), -15 * math.sin(w)), hd=(-13, 0, 3 * math.sin(w)), jw=(5 + 7 * max(0, math.sin(2 * w)), 0, 0),
                cl=(10 + 8 * math.sin(2 * w), 0, 0),
                L=(0, ly, lz), R=(0, ry, rz), Lp=(lk * -26 + (1 - lk) * 0, 0, 0), Rp=(rk * -26, 0, 0),
                Wr=(DRAG[0] + 3 * math.sin(w), DRAG[1], DRAG[2] + 4 * math.sin(2 * w)), Wl=(.02, .2 + .05 * math.sin(w), -.04 + .03 * math.cos(2 * w)),
                Al=(.02, .24 * math.sin(w), .05 + .06 * math.cos(w)))
act('Running_A', 22, {f: march(f / 22) for f in range(23)})

# chop: slow two-handed haul over the back (the telegraph), hang, then the whole body falls onto it. Hit on frame 20
WIND = dict(hr=(-9, 0, -8), hl=(0, .1, .04), ch=(-15, 0, -12), hd=(-16, 0, 4), jw=(12, 0, 0), Wl=(.46, .3, .96), Wr=aim((.1, .62, .78)), Lg=(1, 0, 0),
            L=(0, .02, .07), Lp=(-16, 0, 0), cl=(10, 0, 0))
WIND2 = PP(WIND, hl=(0, .12, .07), hr=(-12, 0, -9), ch=(-18, 0, -14), Wl=(.46, .33, 1.0), Wr=aim((.1, .76, .64)), jw=(18, 0, 0))
HIT = dict(hr=(23, 0, 9), hl=(0, -.3, -.24), ch=(20, 0, 14), hd=(-2, 0, 6), jw=(20, 0, 0), Wl=(.52, -.5, -.24), Wr=aim((.03, -.85, -.5)), Lg=(1, 0, 0),
           L=(0, -.42, 0), R=(0, -.02, 0), Rp=(10, 0, 0), cl=(-20, 0, 0))
act('1H_Melee_Attack_Chop', 44, {0: IDLE_A, (11, 'out'): WIND, (17, 'smooth'): WIND2, (20, 'in'): HIT, 29: PP(HIT, hl=(0, -.28, -.21), jw=(14, 0, 0)), 44: IDLE_A})

# hurt: he is a wall, so he rocks rather than flinches
HA = dict(hr=(-10, 0, 8), hl=(0, .06, -.03), ch=(-12, 0, 10), hd=(4, 10, -20), jw=(24, 0, 0), Al=(.08, .04, .2), Wl=(-.05, .08, .08), Wr=(-16, 0, -8), cl=(16, 0, 0), R=(0, .03, 0))
HB = dict(hr=(-8, 5, -8), hl=(.03, .08, -.05), ch=(-10, 4, -12), hd=(0, -8, 18), jw=(18, 0, 0), Al=(.1, .08, .1), Wl=(.04, .14, .12), Wr=(-14, 0, 8), cl=(14, 0, 0), L=(0, .04, 0))
act('Hit_A', 16, {0: IDLE_A, (2, 'hold'): HA, 16: IDLE_A})
act('Hit_B', 16, {0: IDLE_A, (2, 'hold'): HB, 16: IDLE_A})

# death: rocks back, sword drops, down on both knees with a clang, then pitches forward on his face
D1 = dict(hr=(-14, 0, 6), hl=(0, .12, -.05), ch=(-14, 0, 8), hd=(6, 8, -14), jw=(30, 0, 0), Al=(.1, .05, .26), Wl=(-.08, .1, .1), Wr=(-16, 0, -14), cl=(14, 0, 0), R=(0, .06, 0))
KNEEL_L, KNEEL_R = (0, .34, .0), (0, .36, .0)
D2 = dict(hr=(10, 0, -3), hl=(0, -.03, -.5), ch=(16, 0, -6), hd=(20, -6, -8), jw=(32, 0, 0), Al=(.04, -.02, -.34), Wl=(-.05, -.12, -.72), Wr=aim((-.72, -.4, -.05)),
          L=KNEEL_L, R=KNEEL_R, Lp=(-55, 0, 0), Rp=(-55, 0, 0), cl=(-6, 0, 0), Lk=(.25, -1, .0), Rk=(-.25, -1, .0))
D3 = PP(D2, hr=(58, 0, -5), hl=(0, -.24, -.56), ch=(14, 0, -6), hd=(62, -10, -12), jw=(34, 0, 0), Al=(.2, -.3, -.72), Wl=(-.18, -.2, -.82))
LIE = PP(D2, hr=(79, 0, -6), hl=(0, -.42, -.62), ch=(6, 0, -5), hd=(82, -28, -18), jw=(40, 0, 0), Al=(.3, -.75, -.72), Wl=(-.25, -.6, -.82), L=(.03, .44, -.0), R=(-.03, .46, -.0), Lp=(-85, 0, 0), Rp=(-85, 0, 0), cl=(-30, 0, 0))
act('Death_A', 50, {0: IDLE_A, (3, 'hold'): D1, (14, 'smooth'): PP(D1, hl=(0, .14, -.1)), (21, 'in'): D2, 28: PP(D2, hl=(0, -.03, -.47)), (37, 'in'): LIE, 50: LIE})

# juggled and dropped: flat on his back, hauls up onto a knee, stands. The game plays this at double speed
LB = dict(hr=(-82, 0, 4), hl=(0, .28, -.62), ch=(-4, 0, 2), hd=(-58, 0, 8), jw=(22, 0, 0), Al=(.26, .22, -.6), Wl=(-.28, .36, -.72), Wr=aim((-.8, .3, -.04)),
          L=(.06, -.42, .0), R=(-.08, -.38, .0), Lp=(-46, 0, 0), Rp=(-46, 0, 0), Lk=(.5, -.1, .9), Rk=(-.5, -.1, .9), cl=(26, 0, 0))
SIT = PP(LB, hr=(-16, 0, -5), hl=(0, .1, -.5), ch=(16, 0, 0), hd=(-16, 0, 0), L=(.0, -.34, .0), R=(.0, -.05, .0), Lp=(-12, 0, 0), Rp=(-22, 0, 0), Wl=(-.08, .02, -.56), Wr=aim((-.6, -.5, -.38)), Lk=(.25, -1, .3), Rk=(-.25, -1, .3))
act('Lie_StandUp', 30, {0: LB, (11, 'out'): SIT, 20: PP(IDLE_B, hl=(0, -.02, -.24), hr=(22, 0, 0)), 30: IDLE_A})

# spawn: the sword comes up first, point down, then the horns and pauldrons, and he hauls himself out
DN = -1.95
S0 = dict(hr=(8, 0, 0), hl=(0, 0, DN), ch=(14, 0, 0), hd=(14, 0, 0), L=(0, 0, DN), R=(0, 0, DN), Wl=(.3, -.06, DN + 1.24), Wr=aim((0, -.1, -1)), Al=(0, 0, DN))
S1 = PP(S0, hl=(0, 0, -1.05), L=(0, 0, -1.05), R=(0, 0, -1.05), Wl=(.3, -.06, .36), hd=(-6, 0, 0), Al=(.02, -.1, .45), jw=(18, 0, 0))
S2 = PP(IDLE_B, hl=(0, -.02, -.3), hr=(20, 0, 0), ch=(14, 0, 0), L=(0, .06, 0), R=(0, -.1, 0), Wl=(.28, -.1, .32), Wr=aim((-.03, -.1, -1)), hd=(-12, 0, 0), Al=(.04, -.16, .04), jw=(22, 0, 0))
S3 = PP(IDLE_A, hl=(0, 0, .04), hr=(-5, 0, 0), ch=(-6, 0, 0), hd=(-22, 0, 0), jw=(26, 0, 0))
act('Spawn_Ground_Skeletons', 36, {0: S0, (10, 'out'): S1, (22, 'smooth'): S2, (30, 'out'): S3, 36: IDLE_A})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

CLIPS = (('Idle_Combat', 48), ('Running_A', 22), ('1H_Melee_Attack_Chop', 44), ('Hit_A', 16), ('Hit_B', 16), ('Death_A', 50), ('Lie_StandUp', 30), ('Spawn_Ground_Skeletons', 36))
for nm, ln in CLIPS:
    zs = {'foot.l': [], 'foot.r': []}
    for f in range(ln + 1):
        R.play(nm, f)
        for n in zs: zs[n].append(R.obj.pose.bones[n].head.z)
    print('  feet %-24s L z %.3f..%.3f  R z %.3f..%.3f' % (nm, min(zs['foot.l']), max(zs['foot.l']), min(zs['foot.r']), max(zs['foot.r'])))

# ------------------------------------------------------------------ proof, at the size the game shows him
C.comic_scene()
R.obj.scale = (MODEL_SCALE,) * 3
hero = C.camera('CamHero', (-1.5, -7.6, 1.9), (-.25, -.2, 1.08), lens=58)
game = C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .75), ortho=3.6)
side = C.camera('CamSide', (-6.4, -1.9, 1.5), (0, -.2, 1.05), lens=48)
sheet = C.camera('CamSheet', (-2.9, -4.6, 2.9), (-.1, -.25, .75), lens=30)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
FR = [('Idle_Combat', 24), ('Running_A', 0), ('Running_A', 5), ('Running_A', 11), ('1H_Melee_Attack_Chop', 11), ('1H_Melee_Attack_Chop', 17),
      ('1H_Melee_Attack_Chop', 19), ('1H_Melee_Attack_Chop', 22), ('Hit_A', 2), ('Hit_B', 2), ('Death_A', 8), ('Death_A', 21),
      ('Death_A', 31), ('Death_A', 50), ('Lie_StandUp', 0), ('Lie_StandUp', 11), ('Spawn_Ground_Skeletons', 10), ('Spawn_Ground_Skeletons', 22)]
def sheet_png(frames, cam, out_png, cols=6, tile=320):
    # as CR.contact_sheet, but each frame is cropped round the character (halftone needs the 16:9 render)
    import subprocess, tempfile, shutil
    tmp = tempfile.mkdtemp(prefix='sheet_')
    scn.camera = cam; scn.render.image_settings.file_format = 'PNG'
    for i, (a, f) in enumerate(frames):
        R.play(a, f)
        scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
        bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                    '-vf', 'crop=720:720,scale=%d:-1,tile=%dx%d' % (tile, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
sheet_png(FR, sheet, os.path.join(OUT, NAME + '_motion.png'))
R.obj.scale = (1, 1, 1)
R.play('Idle_Combat', 0)
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME, 'tris', C.tris())
