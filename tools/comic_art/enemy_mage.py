# Skeleton Mage: an upright, smug old wizard. Huge tipped-back pointed hat with a hooked tip, forked beard, open ultramarine
# coat over bare legs, short staff with a crescent-held crystal. The opposite of the necromancer: he stoops under a red hood
# and glides on a robe; this one stands straight, walks on bones, and the hat is the silhouette.
#   blender -b -P enemy_mage.py
# Front -Y, its left +X, up +Z.
# enemy.gd timing the clips are built around: the bolt spawns on the FIRST frame of Spellcast_Shoot (height 1.0, 0.8 ahead),
# so Spellcasting is the anticipation and Shoot goes off at once. Spellcasting loops; the others do not.
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Euler, Matrix, Quaternion as Q
NAME = 'mage'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
# the bolt in the game is violet (projectile.gd), so the magic is too; the coat stays bluer so the glow separates from it
M['arcane'] = C.emit('P_Arcane', (.55, .16, 1), (.96, .86, 1))
M['coat'] = C.toon('P_Coat', (.05, .06, .36), (.1, .15, .62), (.22, .32, .92), (.52, .64, 1), rim=(.2, .16, .6), brush=.16, spot=.02)
M['hat'] = C.toon('P_Hat', (.1, .05, .4), (.2, .11, .68), (.36, .24, .95), (.66, .52, 1), rim=(.32, .14, .62), brush=.18, spot=.02)
M['under'] = C.flat('P_Under', (.13, .05, .3))   # linings: flat, so brim and coat insides keep their shape instead of going to black
M['lining'] = C.toon('P_Lining', (.08, .01, .14), (.28, .05, .34), (.5, .12, .5), rim=(.2, .05, .2), brush=.2)
C.rng.seed(11)

class TB(C.Bag):
    """Remembers which bone each vertex was added for, so rigid parts never get guessed by distance."""
    cur = None
    def __init__(s, mat, **kw):
        super().__init__(mat, **kw); s.owner = []
    def add(s, vs, fs, ts=None):
        super().add(vs, fs, ts); s.owner += [TB.cur] * len(vs)
def on(bone): TB.cur = bone

B = {k: TB(m) for k, m in (('bone', 'bone'), ('socket', 'socket'), ('teeth', 'teeth'), ('arcane', 'arcane'), ('gold', 'bronze'), ('black', 'black'), ('wood', 'leather'), ('beard', 'hair'), ('patch', 'bronze'))}
S = {k: C.Bag(m) for k, m in (('coat', 'coat'), ('trim', 'bronze'), ('mantle', 'coat'), ('sleeve', 'coat'), ('hat', 'hat'), ('brim', 'hat'), ('brim_u', 'under'), ('coat_u', 'under'), ('loin', 'lining'))}
b = B['bone']

def loft(bag, rings, closed=True, ts=None):
    n = len(rings[0]); vs = [p for r in rings for p in r]; F = []
    for j in range(len(rings) - 1):
        for i in range(n if closed else n - 1):
            a = j * n + i; c = j * n + (i + 1) % n
            F.append((a, c, c + n, a + n))
    bag.add(vs, F, ts)

def notches(n, deep):
    out = []
    while len(out) < n:
        w = C.rng.choice((2, 3, 3, 4)); d = C.rng.uniform(deep * .45, deep)
        out += [d * abs(2 * j / w - 1) if j else d for j in range(w)]
    return out[:n]

# ---- joints: straight-backed, chin out, staff hand forward and to the side so it clears the body from above
hip = V((0, .03, .76)); chest = V((0, -.02, 1.14)); neck = V((0, -.1, 1.34)); H = V((0, -.2, 1.55))
shL, elL, wrL = V((.27, -.06, 1.27)), V((.47, -.14, 1.03)), V((.54, -.4, 1.08))
shR, elR, wrR = V((-.27, -.06, 1.27)), V((-.5, -.12, 1.02)), V((-.56, -.38, 1.12))
hdL = wrL + V((.02, -.07, .03)); hdR = wrR + V((-.01, -.06, .02))
hpL, knL, anL = V((.13, .03, .7)), V((.19, -.07, .41)), V((.17, .04, .1))
hpR, knR, anR = V((-.13, .03, .7)), V((-.19, -.07, .41)), V((-.17, .04, .1))

# ---- skull: the family's, longer in the face, one brow cocked in disdain
on('head')
C.blob(b, H + V((0, .02, .05)), (.19, .21, .18), seg=14, rings=9)
C.blob(b, H + V((0, -.12, -.04)), (.125, .1, .105), seg=12, rings=7)
for sx in (-1, 1):
    C.blob(b, H + V((sx * .12, -.09, -.03)), (.046, .05, .045), seg=8, rings=5)
    lift = .03 if sx > 0 else 0
    C.tube(b, [H + V((sx * .03, -.19, .08 + lift * .3)), H + V((sx * .1, -.185, .1 + lift)), H + V((sx * .17, -.12, .08 + lift))], [.03, .036, .018], sides=6, sub=2)
    C.blob(B['socket'], H + V((sx * .075, -.185, .02 + lift * .3)), (.064, .03, .062 + lift * .5), seg=10, rings=6)
    C.blob(B['arcane'], H + V((sx * .075, -.205, .015 + lift * .3)), (.04, .012, .04 + lift * .3), seg=8, rings=5, t=.1)
    C.blob(B['arcane'], H + V((sx * .07, -.22, .012 + lift * .3)), (.017, .008, .02), seg=6, rings=4, t=.95)
C.blob(B['socket'], H + V((0, -.215, -.055)), (.024, .012, .03), seg=7, rings=5)
for i in range(7):
    x = -.09 + i * .03
    C.blob(B['teeth'], H + V((x, -.2 + abs(x) * .4, -.115)), (.0135, .012, .022), seg=6, rings=4)
on('jaw')
J0 = H + V((0, -.1, -.15))
C.tube(b, [H + V((-.12, -.04, -.08)), J0 + V((-.09, -.04, -.03)), J0 + V((0, -.1, -.05)), J0 + V((.09, -.04, -.03)), H + V((.12, -.04, -.08))], [.024, .032, .036, .032, .024], sides=6, sub=2)
for i in range(5):
    x = -.06 + i * .03
    C.blob(B['teeth'], J0 + V((x, -.1 + abs(x) * .4, -.012)), (.012, .011, .018), seg=6, rings=4)
# forked beard: the wizard read, even on a skull
for sx, L in ((1, .36), (-1, .3)):
    q = J0 + V((sx * .035, -.13, -.05))
    C.tube(B['beard'], [J0 + V((sx * .06, -.08, -.03)), q, q + V((sx * .025, -.03, -L * .5)), q + V((sx * .075, -.02, -L))], [(.075, .04), (.075, .045), (.05, .03), (.002, .002)], sides=6, sub=2)
C.tube(B['beard'], [J0 + V((0, -.1, -.03)), J0 + V((0, -.145, -.12)), J0 + V((0, -.14, -.24))], [(.05, .03), (.04, .025), (.002, .002)], sides=5, sub=2)

# ---- the hat: tipped back so the brim clears the face from the game camera, tip hooked over to one side
Hc = H + V((0, .09, .155))
hn = V((0, .36, .93)).normalized(); ex = V((1, 0, 0)); ef = ex.cross(hn).normalized()   # ef points forward and up
BR = 40
rings = []
for j, r in enumerate((.2, .42, .62, .82, 1.0)):
    ring = []
    for i in range(BR):
        a = 2 * math.pi * i / BR
        sa = math.sin(a)
        reach = .39 if sa > 0 else .6                     # front short, back long
        wave = .055 * math.sin(a * 5 + .8) + .03 * math.sin(a * 3 + 2.1)
        ring.append(Hc + ex * (math.cos(a) * .6 * r) + ef * (sa * reach * r) + hn * (-.09 * r * r + wave * r * r - (.05 * r ** 3 if sa < 0 else 0)))
    rings.append(ring)
loft(S['brim'], rings)
loft(S['brim_u'], [[p - hn * .012 for p in ring] for ring in rings[1:]])
HATP = [Hc + hn * -.02, Hc + hn * .18, Hc + hn * .38 + V((0, .03, 0)), Hc + hn * .56 + V((.03, .07, -.01)), Hc + hn * .68 + V((.14, .12, -.05)), Hc + hn * .7 + V((.34, .14, -.16))]
C.tube(S['hat'], HATP, [(.27, .27), (.2, .2), (.14, .14), (.09, .09), (.05, .05), (.002, .002)], sides=14, sub=3, side=ex)
# dent on the cone: a second soft fold, so the silhouette is not a perfect cone
on('hat')
band = [Hc + hn * .065 + ex * (.262 * math.cos(i * .524)) + ef * (.262 * math.sin(i * .524)) for i in range(13)]
C.tube(B['gold'], band, [(.034, .018)] * 2, sides=6, sub=1, side=hn)
buckle = Hc + hn * .065 + ef * .27
C.blob(B['gold'], buckle, (.075, .022, .06), seg=8, rings=4, p=4, rot=(math.atan2(ef.z, -ef.y), 0, 0))
C.blob(B['black'], buckle + ef * .018, (.036, .012, .026), seg=6, rings=4, p=4, rot=(math.atan2(ef.z, -ef.y), 0, 0))
def star(bag, c, n, s, r=.075, pts=5, spin=0):
    """Flat star on a surface: a thin bipyramid so it survives any view."""
    n = V(n).normalized(); u = n.cross(V((0, 0, 1)))
    if u.length < .01: u = V((1, 0, 0))
    u.normalize(); w = n.cross(u)
    rim = []
    for i in range(pts * 2):
        a = spin + math.pi * i / pts
        rr = r if i % 2 == 0 else r * .42
        rim.append(c + u * rr * math.cos(a) * s + w * rr * math.sin(a) * s)
    vs = rim + [c + n * .012, c - n * .012]; m = len(rim)
    F = [(i, (i + 1) % m, m) for i in range(m)] + [((i + 1) % m, i, m + 1) for i in range(m)]
    bag.add(vs, F)
on('hat')
for ang, h_, s in ((.75, .2, 1.5), (2.35, .28, 1.2), (1.5, .38, 1.0)):
    r_ = .254 - h_ * .3
    d = (ex * math.cos(ang) + ef * math.sin(ang)).normalized()
    star(B['patch'], Hc + hn * h_ + d * (r_ + .016), d + hn * .3, s, spin=.3)
for ang, r_, s in ((3.6, .46, 1.7), (5.4, .5, 1.3), (.1, .47, 1.5)):
    a2 = math.sin(ang)
    reach = .39 if a2 > 0 else .6
    star(B['patch'], Hc + ex * (math.cos(ang) * .9 * r_ * .8) + ef * (a2 * reach * .72) + hn * .02, hn, s)

# ---- torso: ribs in the coat opening, gold belt
on('chest')
C.blob(B['black'], V((0, -.03, 1.1)), (.15, .09, .2), seg=10, rings=6)
for i in range(4):
    z = 1.24 - i * .075; w = .17 - i * .012
    for sx in (-1, 1):
        C.tube(b, [V((sx * .02, .03, z + .03)), V((sx * w, -.02, z)), V((sx * w * .9, -.13, z - .03)), V((sx * .02, -.17 + i * .01, z - .05))], [.016, .02, .018, .013], sides=5, sub=2)
C.tube(b, [V((0, -.175, 1.27)), V((0, -.155, 1.0))], [.026, .016], sides=5, sub=1)
C.tube(b, [V((0, .02, 1.18)), neck, H + V((0, .03, -.1))], [.038, .032, .032], sides=6, sub=2)
C.tube(b, [shL, V((0, -.09, 1.3)), shR], [.026, .02, .026], sides=6, sub=2)
on('spine')
for i in range(4):
    C.blob(b, hip.lerp(chest, (i + 1) / 5) + V((0, .03, 0)), (.045, .045, .034), seg=8, rings=5)
on('hips')
C.blob(b, hip + V((0, 0, -.03)), (.19, .13, .09), seg=12, rings=6, p=2.3)
C.tube(B['gold'], [hip + V((.205 * math.cos(i * .524), .15 * math.sin(i * .524), .06)) for i in range(13)], [(.018, .03)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
C.blob(B['gold'], hip + V((0, -.16, .06)), (.07, .025, .06), seg=8, rings=5)
C.blob(B['arcane'], hip + V((0, -.185, .06)), (.03, .012, .03), seg=8, rings=4, t=.9)
# front panel: the second colour, hanging from the belt between the coat edges
n_ = 8; np = notches(n_, .12)
rings = []
for j, z in enumerate((.82, .62, .44, .3)):
    ring = []
    for i in range(n_):
        x = (i / (n_ - 1) - .5) * (.23 + j * .014)
        ring.append(V((x, -.145 - j * .015 + .03 * x * x, z + (np[i] if j == 3 else 0))))
    rings.append(ring)
loft(S['loin'], rings, closed=False)

# ---- limbs: thin shafts, knobby joints
def limb(bone, a, c, r=.03, k=.05):
    on(bone)
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5); C.blob(b, c, (k * .85, k * .85, k * .85), seg=8, rings=5)
limb('upperarm.l', shL, elL); limb('lowerarm.l', elL, wrL, .026, .04); limb('upperarm.r', shR, elR); limb('lowerarm.r', elR, wrR, .026, .04)
limb('upperleg.l', hpL, knL, .04, .062); limb('lowerleg.l', knL, anL, .032, .048); limb('upperleg.r', hpR, knR, .04, .062); limb('lowerleg.r', knR, anR, .032, .048)
for bn, an in (('foot.l', anL), ('foot.r', anR)):
    on(bn)
    # pointed slippers: gold-toed curl, a cheap wizard joke that also marks the feet from above
    C.blob(b, an + V((0, -.05, -.06)), (.066, .11, .036), seg=8, rings=5)
    C.tube(B['gold'], [an + V((0, -.12, -.07)), an + V((0, -.2, -.07)), an + V((0, -.27, -.03)), an + V((0, -.27, .03))], [.042, .034, .018, .002], sides=6, sub=2)
# left hand: open, fingers fanned, the spell sits above the palm
on('hand.l')
hU = (hdL - wrL).normalized()
C.blob(b, wrL + hU * .05, (.055, .05, .035), seg=8, rings=5)
for i in range(4):
    o = V(((i - 1.5) * .034, 0, 0))
    q = wrL + hU * .08 + o
    C.tube(b, [q, q + hU * .08 + o * .5 + V((0, 0, .02)), q + hU * .15 + o * .8 + V((0, 0, .055))], [.016, .013, .003], sides=5, sub=1)
C.tube(b, [wrL + hU * .05 + V((-.04, 0, 0)), wrL + hU * .07 + V((-.1, 0, .02)), wrL + hU * .1 + V((-.13, 0, .05))], [.016, .013, .003], sides=5, sub=1)
on('mote')
Mo = wrL + hU * .1 + V((0, 0, .17))
C.blob(B['arcane'], Mo, (.06, .06, .06), seg=8, rings=5, t=.9)
for i in range(3):
    a = i * 2.094 + .4
    C.tube(B['arcane'], [Mo + V((.09 * math.cos(a), .09 * math.sin(a), -.03)), Mo + V((.13 * math.cos(a + .5), .13 * math.sin(a + .5), .02)), Mo + V((.1 * math.cos(a + 1), .1 * math.sin(a + 1), .07))], [(.016, .016), (.012, .012), (.001, .001)], sides=4, sub=2)

# ---- right hand and the short staff
sdir = V((-.09, -.1, 1)).normalized()
grip = hdR + V((0, -.01, 0))
s_foot = grip - sdir * .44; s_top = grip + sdir * .72
on('hand.r')
C.blob(b, wrR + V((0, -.03, 0)), (.05, .05, .045), seg=8, rings=5)
for i in range(4):
    o = sdir * (i - 1.5) * .04
    C.tube(b, [wrR + o * .5, grip + o + V((.045, -.05, 0)), grip + o + V((-.03, -.06, 0)), grip + o + V((-.05, .02, 0))], [.02, .021, .018, .005], sides=5, sub=2)
on('staff')
C.tube(B['wood'], [s_foot, s_foot.lerp(s_top, .35) + V((.012, 0, 0)), s_foot.lerp(s_top, .7) + V((-.012, .01, 0)), s_top], [.024, .027, .025, .033], sides=7, sub=2)
for k in (.0, .62, .97):
    C.tube(B['gold'], [s_foot.lerp(s_top, k - .025), s_foot.lerp(s_top, k + .025)], [.043, .043], sides=7, sub=1)
C.tube(B['gold'], [s_foot - sdir * .07, s_foot], [.003, .03], sides=6, sub=1)
# crescent cradling the crystal: wide, flat to the side, so from above it reads as a C rather than a dot
sx_ = V((1, 0, 0)); Cc = s_top + sdir * .2
cres = [Cc + sx_ * (.2 * math.cos(a)) + sdir * (.2 * math.sin(a)) for a in [math.radians(d) for d in (-205, -180, -150, -120, -90, -60, -30, 0, 25)]]
C.tube(B['gold'], cres, [(.004, .012), (.03, .02), (.042, .026), (.05, .03), (.054, .032), (.05, .03), (.042, .026), (.03, .02), (.004, .012)], sides=6, sub=2, side=V((0, 1, 0)))
C.tube(B['gold'], [s_top, Cc - sdir * .2], [.035, .045], sides=6, sub=1)
on('crystal')
C.tube(B['arcane'], [Cc - sdir * .15, Cc - sdir * .02, Cc + sdir * .24], [(.001, .001), (.095, .058), (.001, .001)], sides=6, sub=1, tval=.1)
C.tube(B['arcane'], [Cc - sdir * .08, Cc + sdir * .0, Cc + sdir * .13], [(.001, .001), (.05, .075), (.001, .001)], sides=6, sub=1, tval=1.0)

# ---- coat: open at the front, stiff at the shoulder, ragged at the shin
NC = 34
SEC = [(1.36, -.05, .17, .14, .25), (1.27, -.03, .33, .21, .35), (1.13, .0, .29, .2, .8), (.96, .04, .265, .205, .9), (.8, .06, .31, .25, 1.0), (.6, .08, .42, .34, 1.0), (.4, .11, .53, .44, 1.0)]
cn = notches(NC, .17)
RINGS = []; EDGE = ([], [])
for j, (z, cy, rx, ry, gap) in enumerate(SEC):
    ring = []
    half = math.radians(26 + 22 * gap)
    a0 = -math.pi / 2 + half; a1 = 3 * math.pi / 2 - half
    for i in range(NC):
        a = a0 + (a1 - a0) * i / (NC - 1)
        f = 1 + (.016 + .05 * j / 6) * math.sin(a * 6 + .7)
        zz = z + (cn[i] if j == len(SEC) - 1 else 0)
        ring.append(V((rx * f * math.cos(a), cy + ry * f * math.sin(a), zz)))
    RINGS.append(ring); EDGE[0].append(ring[0]); EDGE[1].append(ring[-1])
loft(S['coat'], RINGS, closed=False)
loft(S['coat_u'], [[V((p.x * .965, cy_ + (p.y - cy_) * .965, p.z + .012)) for p in ring] for ring, cy_ in zip(RINGS[1:], [q[1] for q in SEC[1:]])], closed=False)
for e in EDGE:
    C.tube(S['trim'], e, [(.026, .017)] * 2, sides=5, sub=2)
# shoulder cape: wide stiff shape with scalloped points, gold-edged. It sets the body's width under the brim.
MS = 30
ms = [(1.44, -.09, .015, .015), (1.42, -.08, .13, .12), (1.36, -.05, .27, .2), (1.27, -.03, .42, .28), (1.14, -.01, .5, .34)]
rings = []; edge = []
for j, (z, cy, rx, ry) in enumerate(ms):
    ring = []
    for i in range(MS):
        a = 2 * math.pi * i / MS
        front = max(0, -math.sin(a)) ** 4
        zz = z + front * (j / 4) * .2
        if j == 4: zz -= .075 * abs(math.sin(a * 4.0)) ** .7
        ring.append(V((rx * math.cos(a), cy + ry * math.sin(a) * (1 - front * .22 * j / 4), zz)))
    rings.append(ring)
    if j == 4: edge = ring + ring[:1]
loft(S['mantle'], rings)
C.tube(S['trim'], edge, [(.02, .016)] * 2, sides=5, sub=1)
# clasp at the throat
on('chest')
C.blob(B['gold'], V((0, -.215, 1.31)), (.07, .03, .07), seg=8, rings=5)
C.blob(B['arcane'], V((0, -.245, 1.31)), (.036, .012, .036), seg=8, rings=4, t=.9)
# bell sleeves
def sleeve(a, e, w):
    pts = [a.lerp(e, .3), e, e.lerp(w, .4), e.lerp(w, .78)]
    rad = [.085, .1, .135, .19]
    NS = 16; no = notches(NS, .1); rs = []
    for j, (p, r) in enumerate(zip(pts, rad)):
        tg = (pts[min(j + 1, 3)] - pts[max(j - 1, 0)]).normalized()
        s1 = tg.cross(V((0, 0, 1))).normalized(); s2 = s1.cross(tg).normalized()
        ring = []
        for i in range(NS):
            an = 2 * math.pi * i / NS
            q = p + s1 * r * math.cos(an) + s2 * r * math.sin(an)
            q += V((0, 0, -.13 * (j / 3) ** 2 * max(0, -math.sin(an) * (1 if s2.z > 0 else -1))))
            if j == 3: q -= tg * no[i]
            ring.append(q)
        rs.append(ring)
    loft(S['sleeve'], rs)
sleeve(shL, elL, wrL); sleeve(shR, elR, wrR)

col = scn.collection
objs = {}
for k, bag in list(B.items()) + list(S.items()):
    if not bag.v: continue
    outline = 0 if k in ('socket', 'arcane', 'teeth', 'black', 'patch', 'brim_u', 'coat_u') else .006
    objs[k], t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', C.tris(objs.values()))

# ------------------------------------------------------------------ rig
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, -.02, .12)), 'root'),
    'spine': (hip + V((0, -.02, .12)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .03, -.15)), H + V((0, -.02, .25)), 'chest'),
    'jaw': (H + V((0, -.03, -.09)), J0 + V((0, -.12, -.03)), 'head'),
    'hat': (Hc, Hc + hn * .3, 'head'),
    'hat.1': (HATP[1], HATP[3], 'hat'),
    'hat.2': (HATP[3], HATP[5], 'hat.1'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'mote': (Mo, Mo + V((0, 0, .15)), 'hand.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'staff': (grip, grip + sdir * .5, 'hand.r'),
    'crystal': (Cc, Cc + sdir * .2, 'staff'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.18, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.18, -.08)), 'lowerleg.r'),
    'coat.b': (V((0, .22, .92)), V((0, .38, .38)), 'hips'),
    'coat.l': (V((.27, .05, .92)), V((.44, .1, .38)), 'hips'),
    'coat.r': (V((-.27, .05, .92)), V((-.44, .1, .38)), 'hips'),
    'loin': (V((0, -.15, .82)), V((0, -.17, .32)), 'hips'),
    'mantle.l': (V((.25, -.04, 1.36)), V((.5, -.02, 1.12)), 'chest'),
    'mantle.r': (V((-.25, -.04, 1.36)), V((-.5, -.02, 1.12)), 'chest'),
    'mantle.b': (V((0, .1, 1.38)), V((0, .33, 1.12)), 'chest'),
    'sleeve.l': (elL.lerp(wrL, .3), elL.lerp(wrL, .3) + V((0, 0, -.3)), 'lowerarm.l'),
    'sleeve.r': (elR.lerp(wrR, .3), elR.lerp(wrR, .3) + V((0, 0, -.3)), 'lowerarm.r'),
}
R = CR.Rig('MageRig', bones)
def skin_tagged(o, bag):
    g = {}
    for i, nm in enumerate(bag.owner): R._put(o, g, i, [(1, nm)])
    R._bind(o)
for k in B:
    if k in objs: skin_tagged(objs[k], B[k])
CO = ('hips', 'spine', 'chest', 'coat.b', 'coat.l', 'coat.r')
R.skin_soft(objs['coat'], CO, power=3.5)
R.skin_soft(objs['coat_u'], CO, power=3.5)
R.skin_soft(objs['trim'], CO + ('mantle.l', 'mantle.r', 'mantle.b'), power=3.5)
R.skin_soft(objs['mantle'], ('chest', 'mantle.l', 'mantle.r', 'mantle.b'), power=4)
R.skin_soft(objs['sleeve'], ('upperarm.l', 'lowerarm.l', 'sleeve.l', 'upperarm.r', 'lowerarm.r', 'sleeve.r'), power=4)
R.skin_soft(objs['hat'], ('hat', 'hat.1', 'hat.2'), power=4)
R.skin_fixed(objs['brim'], 'hat'); R.skin_fixed(objs['brim_u'], 'hat')
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
    """Two-bone IK: put the wrist on a world point, elbow towards pole (a world direction). Writes both arm bones."""
    sh, el, wr = (shL, elL, wrL) if side == 'l' else (shR, elR, wrR)
    return _ik(pose, 'chest', 'upperarm.' + side, 'lowerarm.' + side, sh, el, wr, target, pole)
def aim(pose, bone, want):
    """World rotation for a bone regardless of its parents: want is XYZ degrees from rest."""
    par = bones[bone][2]
    q = delta(pose, par).to_quaternion()
    pose[bone] = deg(q.inverted() @ Euler([math.radians(a) for a in want], 'XYZ').to_quaternion())
    return pose
def plant(pose, l=(0, 0, 0), r=(0, 0, 0), ld=(0, 0, 0), rd=(0, 0, 0)):
    """Feet on the floor whatever the hips do: ankle on a world point (rest + offset), knee forward and out, foot flat (or ld/rd)."""
    _ik(pose, 'hips', 'upperleg.l', 'lowerleg.l', hpL, knL, anL, anL + V(l), (.25, -1, 0)); aim(pose, 'foot.l', ld)
    _ik(pose, 'hips', 'upperleg.r', 'lowerleg.r', hpR, knR, anR, anR + V(r), (-.25, -1, 0)); aim(pose, 'foot.r', rd)
    return pose
def P(*ds):
    out = {}
    for d in ds: out.update(d)
    return out
ALL = list(bones)
def clip(name, length, keys):
    """Every clip tracks every bone, plus root and hips position: a bone with no track keeps a stale pose in the engine."""
    first = min(keys, key=lambda k: k[0] if isinstance(k, tuple) else k)
    p0 = dict(keys[first])
    for n in ALL: p0.setdefault(n, (0, 0, 0))
    for n in ('root', 'hips', 'hat', 'mote'):
        s = p0[n]
        rot = s.get('rot', (0, 0, 0)) if isinstance(s, dict) else s
        loc = s.get('loc', (0, 0, 0)) if isinstance(s, dict) else (0, 0, 0)
        if V(loc).length < 1e-5: p0[n] = {'rot': rot, 'loc': (0, 0, 2e-5)}
    keys[first] = p0
    return R.action(name, length, keys)

# ------------------------------------------------------------------ animation (24 fps). Every body pose, then IK the staff hand.
def stance(**kw):
    p = {'hips': {'rot': (2, 0, 0), 'loc': (0, 0, -.02)}, 'chest': (2, 0, 0), 'head': (-4, 0, 0),
         'upperleg.l': (-4, 0, -2), 'lowerleg.l': (8, 0, 0), 'upperleg.r': (-4, 0, 2), 'lowerleg.r': (8, 0, 0)}
    p.update(kw)
    return p
IDLE_A = P(stance(), {'jaw': (2, 0, 0), 'hat.1': (-2, 0, 2), 'hat.2': (-4, 0, 5), 'mote': (0, 0, 0), 'crystal': (0, 0, 0)})
arm(IDLE_A, 'r', wrR + V((0, 0, -.01)), pole=(-.6, .4, -1)); aim(IDLE_A, 'staff', (0, 2, 0)); arm(IDLE_A, 'l', wrL, pole=(.8, .4, -1)); plant(IDLE_A)
IDLE_B = P(stance(hips={'rot': (3, 0, 0), 'loc': (0, 0, -.045)}, chest=(4, 0, -3), head=(-7, 3, 4)), {'jaw': (-3, 0, 0), 'hat.1': (3, 0, -3), 'hat.2': (6, 0, -8), 'mote': {'rot': (0, 0, 80), 'loc': (0, 0, .04)}, 'crystal': (0, 0, 40),
    'mantle.b': (3, 0, 0), 'coat.b': (2, 0, 0), 'sleeve.l': (0, 4, 0)})
arm(IDLE_B, 'r', wrR + V((0, 0, -.045)), pole=(-.6, .4, -1)); aim(IDLE_B, 'staff', (0, -2, 0)); arm(IDLE_B, 'l', wrL + V((.01, -.01, .02)), pole=(.8, .4, -1)); plant(IDLE_B)
clip('Idle_Combat', 44, {0: IDLE_A, 22: IDLE_B, 44: IDLE_A})

# run: a stiff-backed scurry, hat dragging behind, coat tails flying
def run(s, c):
    p = {'root': {'rot': (0, 0, 0), 'loc': (0, 0, 0)}, 'hips': {'rot': (12, 0, s * 5), 'loc': (0, -.03, -.045 + .05 * abs(c))}, 'chest': (5, 0, -s * 12), 'head': (-14, 0, s * 8), 'jaw': (-3, 0, 0),
         'upperleg.l': (s * 40 - 8, 0, -2), 'lowerleg.l': (14 + 62 * max(0, -c), 0, 0), 'upperleg.r': (-s * 40 - 8, 0, 2), 'lowerleg.r': (14 + 62 * max(0, c), 0, 0),
         'hat': (-10, 0, 0), 'hat.1': (-16 + 6 * c, 0, 8 * s), 'hat.2': (-22 + 8 * c, 0, -14 * s),
         'coat.b': (34 + 9 * c, 0, s * 8), 'coat.l': (20 + 6 * c, -6, 0), 'coat.r': (20 - 6 * c, 6, 0), 'loin': (s * 18 + 10, 0, 0), 'mantle.b': (14, 0, 0), 'sleeve.l': (20, 0, 0), 'sleeve.r': (20, 0, 0), 'mote': (0, 0, s * 60), 'crystal': (0, 0, s * 40)}
    arm(p, 'l', V((.42 - .03 * s, -.28 + .2 * s, .98 + .06 * s)), pole=(.8, .5, -.6))
    arm(p, 'r', V((-.44 + .03 * s, -.42 - .1 * s, 1.14)), pole=(-.8, .5, -.6))
    aim(p, 'staff', (22 - 4 * s, 4, s * 4))
    return p
cyc = 16
clip('Running_A', cyc, {f: run(math.sin(f / cyc * 6.2832), math.cos(f / cyc * 6.2832)) for f in (0, 2, 4, 6, 8, 10, 12, 14, 16)})

# windup: staff lifted overhead, the free hand winding the spell, the mote climbing. Loops under the telegraph.
def weave(s, c):
    p = {'hips': {'rot': (-3, 0, 6 + c * 3), 'loc': (0, .03, -.02 + .012 * s)}, 'chest': (-6, 0, 10 + c * 4), 'head': (-2, 0, -14 - c * 3), 'jaw': (10 + 6 * s, 0, 0), 'upperleg.l': (-6, 0, -3), 'lowerleg.l': (10, 0, 0), 'upperleg.r': (-3, 0, 3), 'lowerleg.r': (6, 0, 0),
         'hat.1': (8 * s, 0, 6 * c), 'hat.2': (14 * s, 0, 12 * c), 'mote': {'rot': (0, 0, 180 * c + 180), 'loc': (0, -.03 * c, .12 + .03 * s)}, 'crystal': (0, 0, 90 * s), 'sleeve.r': (-6, 12, 0), 'sleeve.l': (6 * c, 10 * s, 0), 'mantle.b': (4 * s, 0, 0), 'coat.b': (3 * s, 0, 0), 'coat.l': (0, -3 * c, 0), 'loin': (3 * c, 0, 0)}
    arm(p, 'r', V((-.5, -.2 - .02 * c, 1.54 + .02 * s)), pole=(-1, .2, -.3))
    arm(p, 'l', V((.42 + .07 * c, -.48 + .07 * s, 1.12 + .05 * s)), pole=(.8, .4, -1))
    aim(p, 'staff', (-14, -8 + 3 * c, 0)); plant(p, l=(.03, -.04, 0), r=(-.02, .08, 0), rd=(0, 0, -6))
    return p
clip('Spellcasting', 32, {f: weave(math.sin(f / 32 * 6.2832), math.cos(f / 32 * 6.2832)) for f in range(0, 33, 4)})
CAST0 = weave(0, 1)

# shoot: the bolt leaves on frame 0, so the staff is already on its way. Whole body behind the thrust, tip near the muzzle point.
FIRE = {'hips': {'rot': (10, 0, 8), 'loc': (-.04, -.15, -.09)}, 'chest': (14, 0, 14), 'head': (-20, 0, -8), 'jaw': (22, 0, 0), 'upperleg.l': (-30, 0, -3), 'lowerleg.l': (14, 0, 0), 'upperleg.r': (26, 0, 3), 'lowerleg.r': (-34, 0, 0),
        'hat': (-14, 0, 0), 'hat.1': (-26, 0, 0), 'hat.2': (-34, 0, 8), 'coat.b': (26, 0, 0), 'coat.l': (14, 0, 0), 'coat.r': (14, 0, 0), 'loin': (12, 0, 0), 'mantle.b': (20, 0, 0), 'sleeve.r': (24, 0, 0), 'sleeve.l': (12, 0, 0), 'crystal': (0, 0, 60), 'mote': {'rot': (0, 0, 40), 'loc': (0, .03, -.05)}}
arm(FIRE, 'r', V((-.2, -.58, 1.2)), pole=(-1, .3, -.4)); aim(FIRE, 'staff', (82, 0, 14)); arm(FIRE, 'l', V((.36, .05, 1.06)), pole=(.7, .7, -.4)); plant(FIRE, l=(.04, -.34, 0), r=(-.04, .22, 0))
FIRE2 = P(FIRE, {'hips': {'rot': (8, 0, 6), 'loc': (-.03, -.13, -.075)}, 'head': (-16, 0, -6), 'jaw': (12, 0, 0), 'hat.1': (-14, 0, 0), 'hat.2': (-16, 0, 4), 'coat.b': (10, 0, 0), 'mantle.b': (8, 0, 0), 'sleeve.r': (10, 0, 0)})
arm(FIRE2, 'r', V((-.21, -.55, 1.21)), pole=(-1, .3, -.4)); aim(FIRE2, 'staff', (76, 0, 12)); arm(FIRE2, 'l', V((.36, .04, 1.06)), pole=(.7, .7, -.4)); plant(FIRE2, l=(.04, -.34, 0), r=(-.04, .22, 0))
clip('Spellcast_Shoot', 26, {0: CAST0, (3, 'in'): FIRE, (10, 'out'): FIRE2, 26: IDLE_A})

# hits: A snaps back, B spins off the other way (the game alternates them, B also opens launches)
HURT = {'hips': {'rot': (-14, 0, 6), 'loc': (0, .12, -.02)}, 'chest': (-16, 0, 12), 'head': (22, 8, -16), 'jaw': (28, 0, 0), 'hat': (-20, 0, 8), 'hat.1': (20, 0, -10), 'hat.2': (26, 0, -16), 'mantle.b': (-12, 0, 0), 'coat.b': (-12, 0, 0), 'loin': (-14, 0, 0), 'crystal': (0, 0, 30), 'mote': {'rot': (0, 0, 0), 'loc': (0, .05, .08)}}
arm(HURT, 'r', V((-.56, -.1, 1.28)), pole=(-1, .2, -.5)); aim(HURT, 'staff', (-26, -18, 0)); arm(HURT, 'l', V((.52, -.05, 1.3)), pole=(1, .2, -.5)); plant(HURT, r=(0, .12, 0))
clip('Hit_A', 14, {0: IDLE_A, (2, 'hold'): HURT, 4: HURT, 14: IDLE_A})
HURTB = {'hips': {'rot': (6, 8, -10), 'loc': (.05, .08, -.05)}, 'chest': (14, 6, -18), 'head': (-16, -14, 22), 'jaw': (34, 0, 0), 'hat': (-14, 14, 0), 'hat.1': (24, 0, 12), 'hat.2': (30, 0, 20), 'mantle.l': (0, -14, 0), 'coat.r': (-10, 8, 0), 'loin': (-8, 0, 0)}
arm(HURTB, 'r', V((-.52, -.34, .86)), pole=(-1, .5, 0)); aim(HURTB, 'staff', (24, 34, 0)); arm(HURTB, 'l', V((.4, .12, 1.28)), pole=(1, .6, -.3)); plant(HURTB, l=(.06, .1, 0))
clip('Hit_B', 16, {0: IDLE_A, (2, 'hold'): HURTB, 5: HURTB, 16: IDLE_A})

# death: arms up in outrage, the crystal goes first, the bones fold. The hat stays in the air a beat and lands on the heap.
D1 = {'hips': {'rot': (-12, 0, 6), 'loc': (0, .08, -.06)}, 'chest': (-22, 0, 8), 'head': (24, 0, -14), 'jaw': (36, 0, 0), 'hat': {'rot': (-18, 0, 0), 'loc': (0, .05, .1)}, 'hat.1': (20, 0, 0), 'hat.2': (24, 0, 0), 'mantle.b': (12, 0, 0)}
arm(D1, 'r', V((-.55, -.1, 1.45)), pole=(-1, .3, -.4)); aim(D1, 'staff', (-40, -30, 0)); arm(D1, 'l', V((.55, -.08, 1.42)), pole=(1, .3, -.4)); plant(D1)
D2 = {'hips': {'rot': (26, 0, 8), 'loc': (0, .05, -.5)}, 'chest': (40, 0, 14), 'head': (24, 18, -24), 'jaw': (40, 0, 0), 'upperarm.l': (40, 0, 56), 'lowerarm.l': (30, 0, 0), 'upperarm.r': (10, 30, -60), 'lowerarm.r': (14, 0, 0), 'upperleg.l': (-70, 0, 28), 'lowerleg.l': (118, 0, 0), 'upperleg.r': (-62, 0, -32), 'lowerleg.r': (108, 0, 0),
      'staff': (70, 0, 50), 'coat.b': (40, 0, 0), 'coat.l': (0, -30, 0), 'coat.r': (0, 30, 0), 'loin': (-20, 0, 0)}
def hat_at(pose, world, want):
    """Hat free of the head: its world place and tilt, solved back through the chain."""
    par = delta(pose, 'head'); e = par.to_quaternion().inverted() @ Euler([math.radians(a) for a in want], 'XYZ').to_quaternion()
    h = bones['hat'][0]
    l = par.inverted() @ V(world) - h
    pose['hat'] = {'rot': deg(e), 'loc': tuple(l)}
    return pose
D2a = hat_at(dict(D2), Hc + V((.04, .1, -.5)), (10, 8, 0))
D2b = hat_at(dict(D2), V((.1, .02, .78)), (-22, 16, 0)); D2b['hat.1'] = (0, 0, 20); D2b['hat.2'] = (0, 0, 40)
clip('Death_A', 44, {0: IDLE_A, (4, 'hold'): D1, 10: D1, (22, 'in'): D2a, (34, 'in'): D2b, 44: D2b})

# spawn: claw up out of the floor. The hat comes up first, which is the joke.
S0 = {'hips': {'rot': (36, 0, 0), 'loc': (0, 0, -.95)}, 'chest': (26, 0, 0), 'head': (-22, 0, 0), 'upperarm.l': (-110, 0, 30), 'upperarm.r': (-70, 0, -14), 'staff': (-10, 0, 0), 'coat.b': (30, 0, 0)}
S1 = {'hips': {'rot': (14, 0, 0), 'loc': (0, 0, -.32)}, 'chest': (12, 0, 0), 'head': (-14, 0, 0), 'hat.1': (14, 0, 0), 'hat.2': (20, 0, 0)}
arm(S1, 'r', V((-.5, -.3, 1.2)), pole=(-1, .3, -.5)); aim(S1, 'staff', (10, 0, 0)); arm(S1, 'l', V((.5, -.3, 1.0)), pole=(1, .3, -.5)); plant(S1)
clip('Spawn_Ground_Skeletons', 26, {0: S0, (14, 'out'): S1, 26: IDLE_A})

# knocked down and up again: lies on its back, sits up, plants the staff. Played at double speed.
LIE = {'root': {'rot': (-84, 0, 0), 'loc': (0, -.3, .2)}, 'chest': (4, 0, 0), 'head': (22, 12, 0), 'jaw': (24, 0, 0), 'upperarm.l': (20, 0, 50), 'upperarm.r': (22, 0, -50), 'upperleg.l': (-14, 0, -10), 'lowerleg.l': (22, 0, 0), 'upperleg.r': (6, 0, 10), 'lowerleg.r': (10, 0, 0), 'coat.b': (40, 0, 0), 'hat': (34, 0, 0), 'hat.2': (0, 0, 20), 'staff': (20, 0, 20)}
SIT = {'root': {'rot': (-30, 0, 0), 'loc': (0, -.1, .02)}, 'hips': {'rot': (0, 0, 0), 'loc': (0, 0, -.42)}, 'chest': (38, 0, 0), 'head': (-10, 0, 0), 'upperleg.l': (-30, 0, -8), 'lowerleg.l': (84, 0, 0), 'upperleg.r': (-44, 0, 8), 'lowerleg.r': (96, 0, 0), 'coat.b': (16, 0, 0), 'hat.1': (10, 0, 0)}
arm(SIT, 'r', V((-.52, -.45, .62)), pole=(-1, .4, 0)); aim(SIT, 'staff', (-6, 0, 0)); arm(SIT, 'l', V((.45, -.3, .6)), pole=(1, .4, 0))
clip('Lie_StandUp', 34, {0: LIE, 8: LIE, (20, 'out'): SIT, 34: IDLE_A})

# dodge: the game moves the body, so no root travel here. Sharp hop, staff flung out for balance, coat lagging ahead.
DP = plant({'hips': {'rot': (10, 0, 0), 'loc': (0, -.03, -.13)}, 'chest': (10, 0, 0), 'head': (-10, 0, 0)})
DF = {'hips': {'rot': (-20, 0, 0), 'loc': (0, .05, .22)}, 'chest': (14, 0, 0), 'head': (-6, 0, 0), 'upperleg.l': (34, 0, 0), 'lowerleg.l': (-20, 0, 0), 'upperleg.r': (20, 0, 0), 'lowerleg.r': (-44, 0, 0), 'hat': (-22, 0, 0), 'hat.1': (-26, 0, 0), 'hat.2': (-20, 0, 0), 'coat.b': (-26, 0, 0), 'coat.l': (-18, 0, 0), 'coat.r': (-18, 0, 0), 'loin': (-30, 0, 0), 'mantle.b': (-18, 0, 0)}
arm(DF, 'r', V((-.62, -.28, 1.42)), pole=(-1, .3, -.3)); aim(DF, 'staff', (-30, -20, 0)); arm(DF, 'l', V((.6, -.3, 1.34)), pole=(1, .3, -.3))
DL = {'hips': {'rot': (12, 0, 0), 'loc': (0, -.02, -.14)}, 'chest': (10, 0, 0), 'head': (-14, 0, 0), 'hat': (12, 0, 0), 'hat.1': (14, 0, 0)}
arm(DL, 'r', V((-.52, -.34, 1.02)), pole=(-1, .4, -.6)); aim(DL, 'staff', (8, 0, 0)); arm(DL, 'l', V((.5, -.3, 1.0)), pole=(1, .4, -.6)); plant(DL)
clip('Dodge_Backward', 20, {0: IDLE_A, (3, 'out'): DP, (7, 'in'): DF, (11, 'out'): DL, 20: IDLE_A})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.3, -5.6, 1.5), (0, -.1, 1.14), lens=44)
game = C.camera('CamGame', (0, -3.8, 5.75), (0, 0, 1.2), ortho=3.6)
side = C.camera('CamSide', (-5.6, -1.2, 1.4), (0, .05, 1.14), lens=44)
sheet = C.camera('CamSheet', (3.2, -4.8, 3.0), (0, -.12, .98), lens=44)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
# where the crystal is when the game spawns the bolt (0, -.8, 1.0), and the lowest point of the feet per stance clip
def report():
    for act, f in (('Spellcasting', 0), ('Spellcast_Shoot', 3), ('Idle_Combat', 0), ('Idle_Combat', 22)):
        R.play(act, f); bpy.context.view_layer.update()
        pb = R.obj.pose.bones['crystal']; print('  crystal %-18s f%-3d %s' % (act, f, tuple(round(x, 2) for x in pb.head)))
    for act, f in (('Idle_Combat', 0), ('Idle_Combat', 22), ('Running_A', 0), ('Running_A', 4), ('Spellcasting', 8), ('Spellcast_Shoot', 3)):
        R.play(act, f); dg = bpy.context.evaluated_depsgraph_get(); e = objs['bone'].evaluated_get(dg); me = e.to_mesh()
        print('  feet %-18s f%-3d min_z %+.3f' % (act, f, min(v.co.z for v in me.vertices))); e.to_mesh_clear()
report()
def sheet_render(frames, cam, out_png, cols=5, tile=384):
    import tempfile, subprocess, shutil
    tmp = tempfile.mkdtemp(prefix='sheet_mage_')
    scn.camera = cam; scn.render.image_settings.file_format = 'PNG'
    for i, (a, f) in enumerate(frames):
        R.play(a, f); scn.render.filepath = os.path.join(tmp, '%03d.png' % i); bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'), '-vf', 'crop=ih:ih,scale=%d:-1,tile=%dx%d' % (tile, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
sheet_render([('Idle_Combat', 22), ('Running_A', 4), ('Running_A', 12), ('Spellcasting', 0), ('Spellcasting', 16),
              ('Spellcast_Shoot', 3), ('Spellcast_Shoot', 12), ('Hit_A', 3), ('Hit_B', 3), ('Death_A', 8),
              ('Death_A', 24), ('Death_A', 44), ('Spawn_Ground_Skeletons', 0), ('Lie_StandUp', 0), ('Dodge_Backward', 7)], sheet, os.path.join(OUT, NAME + '_motion.png'))
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME, 'tris', C.tris(objs.values()))
