# Skeleton Archer: a lean, crouched hunter with one eye squinted shut. Huge bone bow laid over on its side, because a bow held
# upright is a line from the game camera and one held flat is a big C. Green bandana, scarf and ragged cape, quiver of orange
# fletched arrows fanning out behind the head.
#   blender -b -P enemy_archer.py
# Front -Y, its left +X, up +Z.
# enemy.gd timing the clips are built around: 2H_Ranged_Aiming plays once (no loop) over a 1.1 s windup and must end by holding
# at full draw, because the game turns the whole body along the aim line. The bolt spawns on the FIRST frame of 2H_Ranged_Shoot
# (height 1.0, 0.8 ahead, orange), so Shoot starts at full draw and releases at once. The arrow is drawn along -Y through x = 0.
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Euler, Matrix, Quaternion as Q
NAME = 'archer'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['ember'] = C.emit('P_Ember', (1, .42, .05), (1, .93, .55))     # the same orange as the game's crossbow bolt (LINE_COLOR)
M['forest'] = C.toon('P_Forest', (.03, .16, .1), (.07, .36, .16), (.17, .6, .22), (.48, .86, .38), rim=(.1, .3, .12), brush=.2, spot=.02)
M['string'] = C.flat('P_String', (.96, .92, .74))
C.rng.seed(23)

class TB(C.Bag):
    """Remembers which bone each vertex was added for, so rigid parts never get guessed by distance."""
    cur = None
    def __init__(s, mat, **kw):
        super().__init__(mat, **kw); s.owner = []
    def add(s, vs, fs, ts=None):
        super().add(vs, fs, ts); s.owner += [TB.cur] * len(vs)
def on(bone): TB.cur = bone

B = {k: TB(m) for k, m in (('bone', 'bone'), ('socket', 'socket'), ('teeth', 'teeth'), ('ember', 'ember'), ('leather', 'leather'), ('gold', 'bronze'), ('rag', 'forest'), ('iron', 'iron'))}
S = {k: C.Bag(m) for k, m in (('cape', 'forest'), ('scarf', 'forest'), ('hood', 'forest'), ('loin', 'forest'), ('limbs', 'bone'))}
b = B['bone']

def loft(bag, rings, closed=True):
    n = len(rings[0]); vs = [p for r in rings for p in r]; F = []
    for j in range(len(rings) - 1):
        for i in range(n if closed else n - 1):
            a = j * n + i; c = j * n + (i + 1) % n
            F.append((a, c, c + n, a + n))
    bag.add(vs, F)
def notches(n, deep):
    out = []
    while len(out) < n:
        w = C.rng.choice((2, 3, 3, 4)); d = C.rng.uniform(deep * .45, deep)
        out += [d * abs(2 * j / w - 1) if j else d for j in range(w)]
    return out[:n]

# ---- joints: low and coiled, chin forward. The arms are bound in a neutral hang; the clips place them with IK.
hip = V((0, .04, .68)); chest = V((0, -.04, 1.06)); neck = V((0, -.14, 1.25)); H = V((0, -.26, 1.44))
shL, elL, wrL = V((.26, -.08, 1.17)), V((.44, -.16, .95)), V((.5, -.4, .92))
shR, elR, wrR = V((-.26, -.08, 1.17)), V((-.46, -.02, .96)), V((-.5, -.24, .9))
hdL = wrL + V((0, -.075, 0)); hdR = wrR + V((0, -.08, 0))
hpL, knL, anL = V((.14, .04, .63)), V((.23, -.11, .38)), V((.21, .05, .1))
hpR, knR, anR = V((-.14, .04, .63)), V((-.23, -.11, .38)), V((-.21, .05, .1))

# ---- skull: the family's, one eye wide, the other squinted down the shaft
on('head')
C.blob(b, H + V((0, .02, .06)), (.2, .22, .18), seg=14, rings=9)
C.blob(b, H + V((0, -.12, -.03)), (.13, .1, .1), seg=12, rings=7)
for sx in (-1, 1):
    C.blob(b, H + V((sx * .13, -.09, -.02)), (.05, .05, .045), seg=8, rings=5)
# wide left eye, brow up
C.tube(b, [H + V((.03, -.19, .095)), H + V((.1, -.185, .125)), H + V((.17, -.12, .11))], [.028, .034, .018], sides=6, sub=2)
C.blob(B['socket'], H + V((.078, -.185, .03)), (.066, .03, .066), seg=10, rings=6)
C.blob(B['ember'], H + V((.078, -.208, .03)), (.03, .012, .03), seg=8, rings=5, t=.2)
C.blob(B['ember'], H + V((.074, -.222, .028)), (.014, .007, .014), seg=6, rings=4, t=.95)
# squinted right eye: brow and cheek crush it to a slit
C.tube(b, [H + V((-.02, -.195, .04)), H + V((-.1, -.195, .05)), H + V((-.17, -.13, .1))], [.03, .04, .02], sides=6, sub=2)
C.blob(B['socket'], H + V((-.08, -.185, .005)), (.062, .03, .026), seg=10, rings=6)
C.blob(B['ember'], H + V((-.08, -.208, .004)), (.036, .01, .01), seg=8, rings=4, t=.95)
C.tube(b, [H + V((-.03, -.19, -.035)), H + V((-.1, -.185, -.03)), H + V((-.16, -.13, -.01))], [.018, .024, .012], sides=5, sub=2)
C.blob(B['socket'], H + V((0, -.215, -.045)), (.024, .012, .03), seg=7, rings=5)
for i in range(7):
    x = -.09 + i * .03
    C.blob(B['teeth'], H + V((x, -.2 + abs(x) * .4, -.1)), (.0135, .012, .022), seg=6, rings=4)
on('jaw')
J0 = H + V((0, -.1, -.13))
C.tube(b, [H + V((-.13, -.04, -.07)), J0 + V((-.1, -.04, -.03)), J0 + V((0, -.1, -.05)), J0 + V((.1, -.04, -.03)), H + V((.13, -.04, -.07))], [.024, .032, .036, .032, .024], sides=6, sub=2)
for i in range(5):
    x = -.06 + i * .03
    C.blob(B['teeth'], J0 + V((x, -.1 + abs(x) * .4, -.015)), (.012, .011, .018), seg=6, rings=4)
# hood: open at the face, peaked over the brow, a long point drooping down the back. Colours the top of the head from above.
on('head')
hn_ = V((0, -.88, .47)).normalized(); hx = V((1, 0, 0)); hu = hn_.cross(hx).normalized()
if hu.z < 0: hu = -hu
HO = H + V((0, -.03, .03)) + hn_ * .13
HOODP = [HO, H + V((0, .02, .1)), H + V((0, .16, .11)), H + V((0, .3, .03)), H + V((.02, .4, -.14)), H + V((.05, .46, -.34))]
C.tube(S['hood'], HOODP, [(.225, .25), (.255, .265), (.235, .235), (.14, .14), (.065, .065), (.002, .002)], sides=14, sub=3, side=hx, cap=False)
def hood_rim(th):
    x = math.cos(th) * .225; u = math.sin(th) * .25
    if math.sin(th) > 0: u -= .075 * math.exp(-(abs(math.cos(th)) / .3) ** 2)    # dips at the brow, so the hood scowls too
    return HO + hx * x + hu * u + hn_ * (.012 + .012 * math.sin(th * 7 + .6))
ths = [-math.pi / 2 + 2 * math.pi * i / 22 for i in range(23)]
C.tube(B['rag'], [hood_rim(t) for t in ths], [(.03, .02)] * 2, sides=6, sub=1, side=hn_)
Kn = HOODP[3]

# ---- cage ribs and spine, as the minion
on('spine')
for i in range(6):
    C.blob(b, hip.lerp(chest, i / 5) + V((0, .05 + .03 * math.sin(i), 0)), (.05, .05, .036), seg=8, rings=5)
on('chest')
C.tube(b, [chest + V((0, .05, 0)), neck, H + V((0, .03, -.1))], [.04, .034, .034], sides=6, sub=2)
for i in range(4):
    z = chest.z + .07 - i * .075
    w = .23 - i * .02
    for sx in (-1, 1):
        C.tube(b, [V((sx * .01, -.02, z + .03)), V((sx * w * .8, -.02, z)), V((sx * w, -.14, z - .04)), V((sx * w * .45, -.235, z - .07)), V((sx * .02, -.25 + i * .012, z - .05))], [.017, .021, .019, .017, .013], sides=5, sub=2)
C.tube(b, [V((0, -.255, chest.z + .04)), V((0, -.235, chest.z - .25))], [.028, .019], sides=5, sub=1)
C.tube(b, [shL, V((0, -.14, 1.2)), shR], [.026, .02, .026], sides=6, sub=2)
on('hips')
C.blob(b, hip + V((0, 0, -.03)), (.2, .14, .095), seg=12, rings=6, p=2.3)
C.tube(B['leather'], [hip + V((.205 * math.cos(i * .524), .15 * math.sin(i * .524) - .005, .03)) for i in range(13)], [(.014, .032)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
C.blob(B['gold'], hip + V((0, -.16, .03)), (.05, .018, .045), seg=8, rings=4, p=3)
# bandolier: quiver strap over the ribs
on('chest')
C.tube(B['leather'], [V((-.24, -.09, 1.2)), V((-.1, -.27, 1.14)), V((.08, -.26, .98)), V((.2, -.1, .86))], [(.034, .01), (.036, .01), (.036, .01), (.03, .01)], sides=5, sub=2, side=V((1, 0, 0)))

# ---- limbs
def limb(bone, a, c, r=.031, k=.05):
    on(bone)
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5); C.blob(b, c, (k * .85, k * .85, k * .85), seg=8, rings=5)
limb('upperarm.l', shL, elL); limb('lowerarm.l', elL, wrL, .027, .041); limb('upperarm.r', shR, elR); limb('lowerarm.r', elR, wrR, .027, .041)
limb('upperleg.l', hpL, knL, .041, .064); limb('lowerleg.l', knL, anL, .033, .05); limb('upperleg.r', hpR, knR, .041, .064); limb('lowerleg.r', knR, anR, .033, .05)
# bracer on the bow arm
on('lowerarm.l')
C.tube(B['leather'], [elL.lerp(wrL, .35), elL.lerp(wrL, .92)], [.052, .05], sides=7, sub=1)
C.tube(B['gold'], [elL.lerp(wrL, .9), elL.lerp(wrL, .96)], [.056, .056], sides=7, sub=1)
for bn, an in (('foot.l', anL), ('foot.r', anR)):
    on(bn)
    C.blob(b, an + V((0, -.06, -.06)), (.07, .12, .035), seg=8, rings=5)
    for i in range(3):
        o = V(((i - 1) * .036, -.17, -.075))
        C.tube(b, [an + V((o.x, -.12, -.065)), an + o], [.018, .006], sides=5, sub=1)
    lb = 'lowerleg.l' if bn == 'foot.l' else 'lowerleg.r'
    kn = knL if bn == 'foot.l' else knR
    on(lb)
    C.tube(B['rag'], [kn.lerp(an, .55), kn.lerp(an, .95)], [.05, .05], sides=7, sub=1)   # shin wraps: green on the legs from above
# bow hand: closed on the grip. Draw hand: two fingers and a thumb on the string.
on('hand.l')
C.blob(b, wrL + V((0, -.035, 0)), (.048, .05, .046), seg=8, rings=5)
on('hand.r')
C.blob(b, wrR + V((0, -.04, 0)), (.044, .05, .042), seg=8, rings=5)
for i in range(3):
    o = V(((i - 1) * .03, 0, .0))
    q = wrR + V((0, -.07, 0)) + o
    C.tube(b, [q, q + V((0, -.05, -.015)), q + V((0, -.085, -.05))], [.015, .013, .003], sides=5, sub=1)
C.tube(b, [wrR + V((.03, -.05, .02)), wrR + V((.035, -.1, .02)), wrR + V((.02, -.13, 0))], [.015, .013, .003], sides=5, sub=1)

# ---- the bow: bound upright in the left hand (axis Z, arrow along -Y); the clips lay it over on its side.
G = hdL + V((0, -.01, 0)); BL = .9
def bow_pt(t):
    a = abs(t)
    back = .36 * a * a - .15 * max(0, (a - .76) / .24) ** 2
    return G + V((0, back, BL * t))
n0 = G + V((0, bow_pt(1).y - G.y, 0))     # string at rest
TS = [-1, -.8, -.55, -.3, -.12, 0, .12, .3, .55, .8, 1]
wid = lambda t: (.058 - .03 * abs(t), .042 - .018 * abs(t))
pts = [bow_pt(t) for t in TS]
C.tube(S['limbs'], pts, [wid(t) for t in TS], sides=7, sub=2, side=V((1, 0, 0)))
on('bow')
C.tube(B['leather'], [bow_pt(-.14), bow_pt(0), bow_pt(.14)], [(.07, .055), (.074, .058), (.07, .055)], sides=8, sub=2, side=V((1, 0, 0)))
for t in (-.2, .2):
    C.tube(B['gold'], [bow_pt(t - .025), bow_pt(t + .025)], [(.065, .05)] * 2, sides=7, sub=1, side=V((1, 0, 0)))
on('hand.l')
for i in range(4):
    z = G.z + (i - 1.5) * .042
    C.tube(b, [V((G.x + .055, G.y + .03, z)), V((G.x + .06, G.y - .05, z)), V((G.x - .01, G.y - .075, z)), V((G.x - .065, G.y - .01, z))], [.021, .021, .019, .006], sides=5, sub=2)
# rib-spurs and barbed tips: the big bow's silhouette from above
for sgn, bn in ((1, 'bow.u'), (-1, 'bow.l')):
    on(bn)
    tip = bow_pt(sgn); pre = bow_pt(sgn * .9); dr = (tip - pre).normalized()
    C.tube(b, [pre, tip + dr * .02, tip + dr * .13 + V((0, -.09, 0))], [(.03, .026), (.036, .03), (.002, .002)], sides=6, sub=2)
    for t in (.42, .6, .76):
        q = bow_pt(sgn * t)
        C.tube(B['bone'], [q + V((0, -.01, 0)), q + V((0, -.08, sgn * -.02)), q + V((0, -.135, sgn * -.08))], [.018, .014, .002], sides=5, sub=1)
    C.blob(B['iron'], bow_pt(sgn * .28), (.04, .03, .03), seg=6, rings=4)
# string, on its own: weights blend from the tips to the nock
SB = TB('string')
on('nock')
for sgn in (1, -1):
    C.tube(SB, [bow_pt(sgn), n0], [.009, .009], sides=4, sub=1, cap=False)
B['string'] = SB

# ---- the nocked arrow, bound lying along -Y from the string
AL = 1.02
on('arrow')
Ar0 = n0; Atip = n0 + V((0, -AL, 0))
C.tube(B['leather'], [Ar0, Atip + V((0, .1, 0))], [.012, .012], sides=5, sub=1)
C.tube(B['ember'], [Atip + V((0, .1, 0)), Atip + V((0, .06, 0)), Atip], [(.05, .012), (.04, .012), (.001, .001)], sides=4, sub=1, side=V((1, 0, 0)))
C.tube(B['ember'], [Atip + V((0, .1, 0)), Atip + V((0, .06, 0)), Atip], [(.012, .04), (.012, .03), (.001, .001)], sides=4, sub=1, side=V((1, 0, 0)))
for sd in ((1, 0, 0), (0, 0, 1)):
    d = V(sd)
    C.tube(B['ember'], [Ar0 + V((0, -.02, 0)), Ar0 + V((0, -.09, 0)), Ar0 + V((0, -.15, 0))], [(.012, .002), (.05, .004), (.002, .002)], sides=4, sub=1, side=d, tval=.2)

# ---- quiver on the back, slanted so the arrows fan up behind the head
on('quiver')
Qb, Qt = V((.13, .22, .72)), V((-.17, .24, 1.32))
qd = (Qt - Qb).normalized()
C.tube(B['leather'], [Qb, Qb.lerp(Qt, .5), Qt], [(.1, .085), (.115, .095), (.13, .105)], sides=9, sub=2, side=V((1, 0, 0)))
C.tube(B['gold'], [Qt - qd * .03, Qt + qd * .012], [(.14, .112), (.14, .112)], sides=9, sub=1, side=V((1, 0, 0)))
C.tube(B['gold'], [Qb + qd * .1, Qb + qd * .145], [(.112, .092), (.112, .092)], sides=9, sub=1, side=V((1, 0, 0)))
C.blob(B['black' if 'black' in B else 'socket'], Qt + qd * .015, (.11, .09, .018), seg=9, rings=4, rot=(0, math.atan2(qd.x, qd.z), 0))
FAN = [(-.18, .02, .36), (-.06, -.04, .44), (.05, .03, .4), (.16, -.02, .34), (-.1, .07, .28), (.09, .08, .3)]
for fx, fy, L in FAN:
    d = (qd + V((fx * 1.1, fy, 0))).normalized()
    q0 = Qt + V((fx * .22, fy * .6, 0)) - qd * .05; q1 = q0 + d * L; q2 = q1 + d * .13
    C.tube(B['leather'], [q0, q1], [.011, .011], sides=4, sub=1)
    s1 = d.cross(V((0, 1, 0))).normalized()
    C.tube(B['ember'], [q1 - d * .02, q1 + d * .05, q2], [(.052, .004), (.06, .004), (.005, .002)], sides=4, sub=1, side=s1, tval=.2)
    C.tube(B['ember'], [q1 - d * .02, q1 + d * .05, q2], [(.004, .052), (.004, .06), (.002, .005)], sides=4, sub=1, side=s1, tval=.85)

# ---- cloth: scarf round the neck, cape off the shoulders, ragged panels at the belt
on('chest')
NCK = V((0, -.1, 1.235))
C.tube(S['scarf'], [NCK + V((.21 * math.cos(i * .524), .17 * math.sin(i * .524) + .0, .015 * math.sin(i * 1.05))) for i in range(13)], [(.075, .058)] * 2, sides=8, sub=1, side=V((0, 0, 1)))
q = NCK + V((.13, -.16, -.03))
C.tube(S['scarf'], [q, q + V((.05, -.05, -.14)), q + V((.03, -.03, -.3)), q + V((.09, -.03, -.42))], [(.06, .016), (.07, .016), (.05, .014), (.002, .002)], sides=5, sub=2, side=V((1, 0, 0)))
NC = 26
capes = [(1.26, .03, .24, .12), (1.14, .07, .34, .19), (.96, .12, .41, .24), (.76, .18, .45, .28), (.56, .24, .47, .31)]
cn = notches(NC, .2)
rings = []
for j, (z, cy, rx, ry) in enumerate(capes):
    ring = []
    for i in range(NC):
        a = math.radians(-22 + 224 * i / (NC - 1))
        f = 1 + .045 * (j / 4) * math.sin(a * 7 + .4)
        ring.append(V((rx * f * math.cos(a), cy + ry * f * math.sin(a), z + (cn[i] if j == 4 else 0))))
    rings.append(ring)
loft(S['cape'], rings, closed=False)
for i in range(8):
    a = -2.75 + i * .4
    o = V((math.cos(a), math.sin(a) * .8, 0))
    q = hip + V((o.x * .2, o.y * .15 - .01, .01))
    L = C.rng.uniform(.26, .4)
    C.tube(S['loin'], [q, q + o * .035 - V((0, 0, L * .5)), q + o * .06 - V((0, 0, L))], [(.056, .006), (.06, .007), (.002, .002)], sides=5, sub=2, side=o.cross(V((0, 0, 1))))

col = scn.collection
objs = {}
for k, bag in list(B.items()) + list(S.items()):
    if not bag.v: continue
    outline = 0 if k in ('socket', 'ember', 'teeth', 'string') else .006
    objs[k], t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', C.tris(objs.values()))

# ------------------------------------------------------------------ rig
tipU, tipL = bow_pt(1), bow_pt(-1)
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, -.02, .12)), 'root'),
    'spine': (hip + V((0, -.02, .12)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .03, -.15)), H + V((0, -.02, .25)), 'chest'),
    'jaw': (H + V((0, -.03, -.08)), J0 + V((0, -.12, -.03)), 'head'),
    'tail': (Kn, HOODP[5], 'head'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'bow': (G, G + V((0, 0, .3)), 'hand.l'),
    'bow.u': (bow_pt(.35), tipU, 'bow'), 'bow.l': (bow_pt(-.35), tipL, 'bow'),
    'nock': (n0, n0 + V((0, -.12, 0)), 'bow'),
    'arrow': (Ar0, Ar0 + V((0, -.5, 0)), 'root'),
    'quiver': (Qb, Qt, 'chest'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.18, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.18, -.08)), 'lowerleg.r'),
    'cape.1': (V((0, .14, 1.2)), V((0, .3, .86)), 'chest'),
    'cape.2': (V((0, .3, .86)), V((0, .42, .42)), 'cape.1'),
    'cape.l': (V((.33, .08, 1.14)), V((.46, .18, .5)), 'chest'),
    'cape.r': (V((-.33, .08, 1.14)), V((-.46, .18, .5)), 'chest'),
    'loin': (hip + V((0, -.08, -.04)), hip + V((0, -.1, -.36)), 'hips'),
}
R = CR.Rig('ArcherRig', bones)
def skin_tagged(o, bag):
    g = {}
    for i, nm in enumerate(bag.owner): R._put(o, g, i, [(1, nm)])
    R._bind(o)
for k in B:
    if k in objs and k != 'string': skin_tagged(objs[k], B[k])
# the string runs tip to nock: fully on the limb at the tip, fully on the nock at the middle
g = {}
for v in objs['string'].data.vertices:
    z = v.co.z - G.z; w = min(1, abs(z) / BL)
    R._put(objs['string'], g, v.index, [(w, 'bow.u' if z > 0 else 'bow.l'), (1 - w + 1e-4, 'nock')])
R._bind(objs['string'])
R.skin_soft(objs['limbs'], ('bow', 'bow.u', 'bow.l'), power=4)
R.skin_soft(objs['cape'], ('chest', 'cape.1', 'cape.2', 'cape.l', 'cape.r'), power=3.5)
R.skin_soft(objs['scarf'], ('chest', 'head'), power=6)
R.skin_soft(objs['hood'], ('head', 'tail'), power=4)
R.skin_soft(objs['loin'], ('hips', 'loin'), power=3)
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ pose tools
# Delta of a bone at rest-space: D(bone) = D(parent) @ T(loc) @ T(head) @ R(e) @ T(-head), exactly what Rig._basis keys.
def _rl(spec):
    rot = spec.get('rot', (0, 0, 0)) if isinstance(spec, dict) else spec
    loc = spec.get('loc', (0, 0, 0)) if isinstance(spec, dict) else (0, 0, 0)
    return Euler([math.radians(a) for a in rot], 'XYZ').to_quaternion(), V(loc)
def delta(pose, bone):
    chain = []
    while bone: chain.insert(0, bone); bone = bones[bone][2]
    Mx = Matrix.Identity(4)
    for n in chain:
        e, l = _rl(pose.get(n, (0, 0, 0)))
        h = bones[n][0]
        Mx = Mx @ Matrix.Translation(l) @ Matrix.Translation(h) @ e.to_matrix().to_4x4() @ Matrix.Translation(-h)
    return Mx
def deg(q): return tuple(math.degrees(a) for a in q.to_euler('XYZ'))
def E(want): return Euler([math.radians(a) for a in want], 'XYZ').to_quaternion()
def _ik(pose, parent, b1, b2, sh, el, wr, target, pole):
    D = delta(pose, parent); Di = D.inverted(); qi = D.to_quaternion().inverted()
    t = Di @ V(target)
    pl = qi @ V(pole)
    L1, L2 = (el - sh).length, (wr - el).length
    d = t - sh; dist = min(d.length, (L1 + L2) * .995); dn = d.normalized()
    a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist); hh = math.sqrt(max(L1 * L1 - a * a, 0))
    perp = (pl - dn * pl.dot(dn)).normalized()
    elb = sh + dn * a + perp * hh; tt = sh + dn * dist
    q1 = (el - sh).rotation_difference(elb - sh)
    q2 = (wr - el).rotation_difference(q1.inverted() @ (tt - elb))
    pose[b1] = deg(q1); pose[b2] = deg(q2)
    return pose
def arm(pose, side, target, pole=(0, 0, -1)):
    sh, el, wr = (shL, elL, wrL) if side == 'l' else (shR, elR, wrR)
    return _ik(pose, 'chest', 'upperarm.' + side, 'lowerarm.' + side, sh, el, wr, target, pole)
def aim(pose, bone, want):
    """World rotation for a bone regardless of its parents: want is XYZ degrees from rest."""
    q = delta(pose, bones[bone][2]).to_quaternion()
    pose[bone] = deg(q.inverted() @ E(want))
    return pose
def plant(pose, l=(0, 0, 0), r=(0, 0, 0), ld=(0, 0, 0), rd=(0, 0, 0)):
    """Feet on the floor whatever the hips do: ankle on a world point (rest + offset), knee forward and out, foot flat (or ld/rd)."""
    _ik(pose, 'hips', 'upperleg.l', 'lowerleg.l', hpL, knL, anL, anL + V(l), (.3, -1, 0)); aim(pose, 'foot.l', ld)
    _ik(pose, 'hips', 'upperleg.r', 'lowerleg.r', hpR, knR, anR, anR + V(r), (-.3, -1, 0)); aim(pose, 'foot.r', rd)
    return pose
def hold_bow(pose, gw, cant, pole=(.7, .3, -.7), flex=0):
    """Bow grip on a world point, the whole bow at a world tilt. The fist stays square so the grip lands exactly."""
    arm(pose, 'l', V(gw) - (G - wrL), pole); aim(pose, 'hand.l', (0, 0, 0)); aim(pose, 'bow', cant)
    pose['bow.u'] = (-flex, 0, 0); pose['bow.l'] = (flex, 0, 0)
    return pose
def string_at(pose, nw=None):
    """String pulled to a world point (None: at rest)."""
    if nw is None: pose['nock'] = {'rot': (0, 0, 0), 'loc': (0, 0, 2e-5)}
    else: pose['nock'] = {'rot': (0, 0, 0), 'loc': tuple(delta(pose, 'bow').inverted() @ V(nw) - n0)}
    return pose
def nock_world(pose): return delta(pose, 'bow') @ n0
def pinch(pose, nw, pole):
    """Draw hand on the string."""
    arm(pose, 'r', V(nw) - (hdR - wrR) + V((0, 0, .012)), pole); aim(pose, 'hand.r', (0, 0, 0))
    return pose
def arrow_at(pose, tail, direction):
    D = delta(pose, 'root')
    e = V((0, -1, 0)).rotation_difference(D.to_quaternion().inverted() @ V(direction))
    pose['arrow'] = {'rot': deg(e), 'loc': tuple(D.inverted() @ V(tail) - Ar0)}
    return pose
def P(*ds):
    out = {}
    for d in ds: out.update(d)
    return out
def clip(name, length, keys, arrow=((0, 0),)):
    """Every clip tracks every bone, plus position on the moving ones, and the arrow's scale: it vanishes on release and when not held.
    A bone with no track keeps a stale pose in the engine. arrow: (frame, 1 or 0) stepped."""
    first = min(keys, key=lambda k: k[0] if isinstance(k, tuple) else k)
    p0 = dict(keys[first])
    for n in bones: p0.setdefault(n, (0, 0, 0))
    for n in ('root', 'hips', 'arrow', 'nock', 'bow'):
        s = p0[n]
        rot = s.get('rot', (0, 0, 0)) if isinstance(s, dict) else s
        loc = s.get('loc', (0, 0, 0)) if isinstance(s, dict) else (0, 0, 0)
        if V(loc).length < 1e-5: p0[n] = {'rot': rot, 'loc': (0, 0, 2e-5)}
    keys[first] = p0
    a = R.action(name, length, keys)
    pb = R.obj.pose.bones['arrow']
    for idx in range(3):
        fc = a.fcurve_ensure_for_datablock(R.obj, pb.path_from_id('scale'), index=idx)
        for f, v in arrow:
            kp = fc.keyframe_points.insert(f, max(v, .001)); kp.interpolation = 'CONSTANT'
        fc.update()
    return a

# ------------------------------------------------------------------ animation (24 fps)
# idle: bow low and out to the left, laid over; arrow on the string, draw hand across the belt. Bow still shows from above.
def idle(k):
    p = {'hips': {'rot': (6, 0, -8), 'loc': (0, 0, -.04 - .025 * k)}, 'chest': (10 + 4 * k, 0, -6 - 2 * k), 'jaw': (3 - 7 * k, 0, 0), 'tail': (0, 0, 5 * k), 'cape.1': (3 * k, 0, 0), 'cape.l': (0, -2 * k, 0), 'loin': (2 * k, 0, 0)}
    aim(p, 'head', (-6 - 3 * k, 0, 4 + 4 * k))
    hold_bow(p, (.42, -.58 - .01 * k, .84 - .02 * k), (0, -60, 24), flex=2)
    nw = nock_world(p) + V((-.05, .05, .02))
    string_at(p, nw); pinch(p, nw, (-.5, .6, -1)); gw = delta(p, 'bow') @ G
    arrow_at(p, nw, (gw - nw).normalized())
    plant(p, l=(.02, -.06, 0), r=(-.02, .05, 0), ld=(0, 0, 8), rd=(0, 0, -8))
    return p
IDLE_A, IDLE_B = idle(0), idle(1)
clip('Idle_Combat', 40, {0: IDLE_A, 20: IDLE_B, 40: IDLE_A}, arrow=((0, 1),))

# run: low and fast, bow pumped out to the side, the other arm swinging. No arrow in hand on the move.
def run(s, c):
    p = {'hips': {'rot': (18, 0, s * 6), 'loc': (0, -.04, -.08 + .05 * abs(c))}, 'chest': (10, 0, -s * 14), 'jaw': (-5, 0, 0), 'tail': (28 + 8 * c, 0, -8 * s),
         'upperleg.l': (s * 44 - 10, 0, -2), 'lowerleg.l': (16 + 66 * max(0, -c), 0, 0), 'upperleg.r': (-s * 44 - 10, 0, 2), 'lowerleg.r': (16 + 66 * max(0, c), 0, 0),
         'cape.1': (14 + 8 * c, 0, 6 * s), 'cape.2': (10 + 8 * s, 0, -8 * s), 'cape.l': (8 + 5 * c, -6, 0), 'cape.r': (8 - 5 * c, 6, 0), 'loin': (s * 20 + 12, 0, 0), 'quiver': (0, s * 4, 0)}
    aim(p, 'head', (-12, 0, s * 6))
    hold_bow(p, (.56, -.3 - .1 * s, 1.0 + .03 * s), (6, -66, 14), pole=(.8, .5, -.5))
    string_at(p)
    arm(p, 'r', V((-.42, -.08 + .3 * s, .92 + .1 * s)), (-.8, .6, -.4))
    return p
clip('Running_A', 16, {f: run(math.sin(f / 16 * 6.2832), math.cos(f / 16 * 6.2832)) for f in range(0, 17, 2)})

# aim: bow up, left shoulder into the line, arrow on x = 0. Holds on the last frame; the game keeps turning the whole body.
AIM_Z = 1.1; GRIP_Y = -.74
def aiming(draw, breath=0):
    p = {'hips': {'rot': (8, 0, -30), 'loc': (.12, -.02, -.1 - .006 * breath)}, 'chest': (8, 0, -24 - breath), 'jaw': (5, 0, 0), 'tail': (10, 0, 0), 'cape.1': (6, 0, 6), 'cape.2': (4, 0, 0), 'cape.l': (6, 0, 0), 'loin': (0, 0, -8)}
    aim(p, 'head', (-14, 0, 3))
    gw = V((0, GRIP_Y, AIM_Z))
    hold_bow(p, gw, (0, -68, 0), pole=(.6, .1, -.8), flex=8 + 12 * draw)
    nw = V((0, GRIP_Y + .28 + .36 * draw, AIM_Z))
    string_at(p, nw); pinch(p, nw, (-.75, .7, .15)); arrow_at(p, nw, (0, -1, 0))
    plant(p, l=(.0, -.18, 0), r=(.02, .22, 0), ld=(0, 0, -6), rd=(0, 0, -40))
    return p
HALF, AIM, AIM2 = aiming(.35), aiming(1), aiming(1, 1)
RAISE = dict(HALF);
clip('2H_Ranged_Aiming', 24, {0: IDLE_A, (8, 'out'): HALF, (16, 'smooth'): AIM, 24: AIM2}, arrow=((0, 1),))

# shoot: the bolt is already in the air on frame 0. String snaps, hand flies open, shoulders kick. Reach back for the next arrow, nock it.
REL = {'hips': {'rot': (2, 0, -34), 'loc': (0, .05, -.08)}, 'chest': (-2, 0, -26), 'jaw': (18, 0, 0), 'tail': (-16, 0, 0), 'cape.1': (-14, 0, 0), 'cape.2': (-10, 0, 0), 'cape.l': (-10, 0, 0), 'loin': (-10, 0, 0)}
aim(REL, 'head', (-22, 0, 3)); hold_bow(REL, (.01, GRIP_Y + .08, AIM_Z + .05), (-10, -68, 0), pole=(.6, .1, -.8), flex=-7); string_at(REL)
arm(REL, 'r', V((-.34, .3, 1.28)), (-.8, .5, -.3)); aim(REL, 'hand.r', (-40, 0, 0)); plant(REL, l=(.0, -.18, 0), r=(.02, .22, 0), ld=(0, 0, -6), rd=(0, 0, -40))
SETTLE = {'hips': {'rot': (6, 0, -26), 'loc': (0, .01, -.07)}, 'chest': (5, 0, -20), 'jaw': (6, 0, 0), 'cape.1': (3, 0, 0)}
aim(SETTLE, 'head', (-10, 0, 3)); hold_bow(SETTLE, (.1, GRIP_Y + .12, 1.0), (0, -66, 10), pole=(.6, .1, -.8)); string_at(SETTLE)
arm(SETTLE, 'r', V((-.36, .2, 1.1)), (-.8, .5, -.4)); plant(SETTLE, l=(.0, -.14, 0), r=(.02, .18, 0), ld=(0, 0, -4), rd=(0, 0, -30))
REACH = {'hips': {'rot': (4, 0, -12), 'loc': (0, .01, -.06)}, 'chest': (4, 0, -18), 'jaw': (0, 0, 0)}
aim(REACH, 'head', (-8, 0, -8)); hold_bow(REACH, (.3, -.6, .9), (0, -62, 20)); string_at(REACH)
Qw = delta(REACH, 'quiver') @ (Qt + qd * .1)
arm(REACH, 'r', Qw + V((0, -.02, 0)), (-1, -.2, .1)); arrow_at(REACH, Qw + V((0, -.08, .1)), (delta(REACH, 'quiver').to_quaternion() @ -qd));  plant(REACH, l=(.02, -.08, 0), r=(-.02, .08, 0))
clip('2H_Ranged_Shoot', 32, {0: AIM2, (2, 'hold'): REL, (5, 'out'): REL, (11, 'smooth'): SETTLE, (19, 'smooth'): REACH, 21: REACH, 32: IDLE_A}, arrow=((0, 1), (1, 0), (19, 1)))

# hits: A takes it in the chest, B spins off. The bow is flung wide so it stays on screen.
HURT = {'hips': {'rot': (-16, 0, 8), 'loc': (0, .12, -.05)}, 'chest': (-18, 0, 12), 'jaw': (30, 0, 0), 'tail': (-30, 0, 0), 'cape.1': (-20, 0, 0), 'cape.2': (-12, 0, 0), 'cape.l': (-12, 0, 0), 'cape.r': (-12, 0, 0), 'loin': (-16, 0, 0)}
aim(HURT, 'head', (14, 10, -14)); hold_bow(HURT, (.6, -.42, .86), (0, -70, 30), pole=(.9, .2, -.5), flex=-3); string_at(HURT)
arm(HURT, 'r', V((-.54, -.02, 1.22)), (-1, .2, -.4)); plant(HURT, r=(0, .14, 0))
clip('Hit_A', 14, {0: IDLE_A, (2, 'hold'): HURT, 4: HURT, 14: IDLE_A}, arrow=((0, 1), (1, 0), (13, 1)))
HURTB = {'hips': {'rot': (8, 8, -14), 'loc': (.05, .08, -.1)}, 'chest': (22, 6, -20), 'jaw': (34, 0, 0), 'tail': (0, 0, 24), 'cape.1': (-8, 0, -14), 'cape.l': (0, 12, 0), 'cape.r': (0, 12, 0), 'loin': (-8, 0, 0)}
aim(HURTB, 'head', (2, -12, 22)); hold_bow(HURTB, (.52, -.26, .68), (20, -40, 30), pole=(.9, .4, 0), flex=-3); string_at(HURTB)
arm(HURTB, 'r', V((-.34, .18, 1.2)), (-1, .5, -.3)); plant(HURTB, l=(.06, .1, 0))
clip('Hit_B', 16, {0: IDLE_A, (2, 'hold'): HURTB, 5: HURTB, 16: IDLE_A}, arrow=((0, 1), (1, 0), (15, 1)))

# death: head thrown back, the bow drops from the hand first and lands flat, then the bones fold on top of the quiver.
def bow_on_floor(p, world, want):
    par = delta(p, 'hand.l'); e = par.to_quaternion().inverted() @ E(want)
    p['bow'] = {'rot': deg(e), 'loc': tuple(par.inverted() @ V(world) - G)}
    return p
D1 = {'hips': {'rot': (-14, 0, 8), 'loc': (0, .08, -.06)}, 'chest': (-22, 0, 10), 'jaw': (38, 0, 0), 'tail': (-30, 0, 0), 'cape.1': (-16, 0, 0)}
aim(D1, 'head', (28, 10, -14)); hold_bow(D1, (.6, -.36, .84), (0, -70, 28), pole=(.9, .2, -.5)); string_at(D1)
arm(D1, 'r', V((-.5, .04, 1.34)), (-1, .3, -.3)); plant(D1)
D2 = {'hips': {'rot': (22, 0, 8), 'loc': (0, .05, -.46)}, 'chest': (26, 0, 14), 'head': (-26, 16, -20), 'jaw': (40, 0, 0), 'upperarm.l': (40, 0, 60), 'lowerarm.l': (30, 0, 0), 'upperarm.r': (10, 30, -60), 'lowerarm.r': (14, 0, 0), 'upperleg.l': (-70, 0, 30), 'lowerleg.l': (116, 0, 0), 'upperleg.r': (-62, 0, -34), 'lowerleg.r': (108, 0, 0), 'cape.1': (6, 0, 0), 'cape.2': (40, 0, 0), 'cape.l': (0, -26, 0), 'cape.r': (0, 26, 0), 'tail': (16, 0, 20), 'loin': (-18, 0, 0)}
Da = bow_on_floor(dict(D2), (.56, -.42, .5), (40, -40, 20)); Da = string_at(Da)
Db = bow_on_floor(dict(D2), (.46, -.62, .07), (90, 0, 22)); Db = string_at(Db)
clip('Death_A', 44, {0: IDLE_A, (4, 'hold'): D1, 10: D1, (22, 'in'): Da, (32, 'in'): Db, 44: Db}, arrow=((0, 1), (3, 0)))

# spawn: claws up out of the floor, bow arm first
S0 = {'hips': {'rot': (40, 0, 0), 'loc': (0, 0, -.9)}, 'chest': (30, 0, 0), 'head': (-20, 0, 0), 'upperarm.l': (-110, 0, 34), 'upperarm.r': (-60, 0, -10), 'bow': (0, -40, 0), 'cape.1': (24, 0, 0)}
string_at(S0)
S1 = {'hips': {'rot': (16, 0, 0), 'loc': (0, 0, -.3)}, 'chest': (14, 0, 0), 'head': (-14, 0, 0), 'cape.1': (10, 0, 0)}
hold_bow(S1, (.5, -.42, .86), (0, -56, 20)); string_at(S1); arm(S1, 'r', V((-.46, -.2, .92)), (-1, .3, -.5)); plant(S1)
clip('Spawn_Ground_Skeletons', 26, {0: S0, (14, 'out'): S1, 26: IDLE_A}, arrow=((0, 0), (22, 1)))

# knocked down and up: flat on its back, then a push up off the free hand.
LIE = {'root': {'rot': (-84, 0, 0), 'loc': (0, -.32, .16)}, 'chest': (4, 0, 0), 'head': (22, 12, 0), 'jaw': (24, 0, 0), 'upperarm.l': (20, 0, 54), 'upperarm.r': (22, 0, -50), 'upperleg.l': (-14, 0, -10), 'lowerleg.l': (22, 0, 0), 'upperleg.r': (6, 0, 10), 'lowerleg.r': (10, 0, 0), 'cape.1': (50, 0, 0), 'cape.2': (20, 0, 0), 'bow': (0, -60, 0)}
string_at(LIE)
SIT = {'root': {'rot': (-30, 0, 0), 'loc': (0, -.1, .02)}, 'hips': {'rot': (0, 0, 0), 'loc': (0, 0, -.38)}, 'chest': (38, 0, 0), 'head': (-10, 0, 0), 'upperleg.l': (-30, 0, -8), 'lowerleg.l': (84, 0, 0), 'upperleg.r': (-44, 0, 8), 'lowerleg.r': (96, 0, 0), 'cape.1': (18, 0, 0)}
hold_bow(SIT, (.56, -.34, .58), (0, -60, 20)); string_at(SIT); arm(SIT, 'r', V((-.44, -.2, .42)), (-1, .4, 0))
clip('Lie_StandUp', 34, {0: LIE, 8: LIE, (20, 'out'): SIT, 34: IDLE_A}, arrow=((0, 0), (31, 1)))

# dodge: the game moves the body, so no root travel. A flat backward spring, bow pulled in, cape lagging forward.
DP = {'hips': {'rot': (12, 0, 0), 'loc': (0, -.03, -.16)}, 'chest': (12, 0, 0), 'head': (-12, 0, 0)}
hold_bow(DP, (.44, -.56, .78), (0, -60, 24)); string_at(DP); arm(DP, 'r', V((-.44, -.2, .86)), (-1, .3, -.5)); plant(DP)
DF = {'hips': {'rot': (-20, 0, 0), 'loc': (0, .05, .2)}, 'chest': (14, 0, 0), 'upperleg.l': (34, 0, 0), 'lowerleg.l': (20, 0, 0), 'upperleg.r': (20, 0, 0), 'lowerleg.r': (40, 0, 0), 'cape.1': (-28, 0, 0), 'cape.2': (-16, 0, 0), 'cape.l': (-18, 0, 0), 'cape.r': (-18, 0, 0), 'loin': (-26, 0, 0), 'tail': (-26, 0, 0)}
aim(DF, 'head', (-8, 0, 0)); hold_bow(DF, (.54, -.38, .9), (0, -70, 26), pole=(.9, .3, -.3)); string_at(DF); arm(DF, 'r', V((-.56, -.18, 1.2)), (-1, .3, -.3))
DL = {'hips': {'rot': (14, 0, 0), 'loc': (0, -.02, -.17)}, 'chest': (12, 0, 0), 'head': (-14, 0, 0), 'cape.1': (10, 0, 0)}
hold_bow(DL, (.46, -.5, .8), (0, -60, 24)); string_at(DL); arm(DL, 'r', V((-.46, -.26, .86)), (-1, .4, -.5)); plant(DL)
clip('Dodge_Backward', 20, {0: IDLE_A, (3, 'out'): DP, (7, 'in'): DF, (11, 'out'): DL, 20: IDLE_A}, arrow=((0, 1), (1, 0), (19, 1)))
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.3, -5.6, 1.4), (0, -.2, 1.0), lens=44)
game = C.camera('CamGame', (0, -3.8, 5.4), (0, -.1, .85), ortho=3.6)
side = C.camera('CamSide', (-5.6, -1.2, 1.3), (0, -.1, 1.0), lens=44)
sheet = C.camera('CamSheet', (3.0, -4.8, 3.2), (0, -.2, .8), lens=44)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
R.play('2H_Ranged_Aiming', 24)
C.render(os.path.join(OUT, NAME + '_aim_game.png'), game)
def pt(bone, offs=None):
    pb = R.obj.pose.bones[bone]
    return tuple(round(x, 2) for x in pb.head)
def report():
    for act, f in (('Idle_Combat', 0), ('2H_Ranged_Aiming', 24), ('2H_Ranged_Shoot', 0), ('2H_Ranged_Shoot', 19)):
        R.play(act, f); bpy.context.view_layer.update()
        print('  %-18s f%-3d nock %s hand.r %s arrow %s' % (act, f, pt('nock'), pt('hand.r'), pt('arrow')))
    for act, f in (('Idle_Combat', 0), ('Idle_Combat', 20), ('Running_A', 0), ('Running_A', 4), ('2H_Ranged_Aiming', 24), ('2H_Ranged_Shoot', 3)):
        R.play(act, f); dg = bpy.context.evaluated_depsgraph_get(); e = objs['bone'].evaluated_get(dg); me = e.to_mesh()
        print('  feet %-18s f%-3d min_z %+.3f' % (act, f, min(v.co.z for v in me.vertices))); e.to_mesh_clear()
report()
def sheet_render(frames, cam, out_png, cols=5, tile=384):
    import tempfile, subprocess, shutil
    tmp = tempfile.mkdtemp(prefix='sheet_archer_')
    scn.camera = cam; scn.render.image_settings.file_format = 'PNG'
    for i, (a, f) in enumerate(frames):
        R.play(a, f); scn.render.filepath = os.path.join(tmp, '%03d.png' % i); bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'), '-vf', 'crop=ih:ih,scale=%d:-1,tile=%dx%d' % (tile, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
sheet_render([('Idle_Combat', 20), ('Running_A', 4), ('Running_A', 12), ('2H_Ranged_Aiming', 8), ('2H_Ranged_Aiming', 24),
              ('2H_Ranged_Shoot', 3), ('2H_Ranged_Shoot', 19), ('Hit_A', 3), ('Hit_B', 3), ('Death_A', 8),
              ('Death_A', 24), ('Death_A', 44), ('Spawn_Ground_Skeletons', 0), ('Lie_StandUp', 0), ('Dodge_Backward', 7)], sheet, os.path.join(OUT, NAME + '_motion.png'))
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME, 'tris', C.tris(objs.values()))
