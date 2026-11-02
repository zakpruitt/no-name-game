# Necromancer: a stooped stage villain. Huge hooked cowl, burning eyes and a grin in the dark, one enormous skeletal
# hand thrown up, a staff of fused spines with a caged soul-flame, robe pooling into a long swept point.
#   blender -b -P enemy_necromancer.py
# Front -Y, its left +X, up +Z. The robe hem hangs off the root (not the hips), so the torso can act while it stays planted.
import bpy, sys, os, math, subprocess, tempfile, shutil
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Euler, Matrix, Quaternion as Q
NAME = 'necromancer'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['shroud'] = C.toon('P_Shroud', (.08, .015, .06), (.32, .05, .11), (.58, .12, .16), (.84, .3, .24), rim=(.3, .05, .1), brush=.16)
C.rng.seed(7)

class TB(C.Bag):
    """A bag that remembers which bone each vertex was added for (kit's skin_islands guesses by nearest bone)."""
    cur = None
    def __init__(s, mat, **kw):
        super().__init__(mat, **kw); s.owner = []
    def add(s, vs, fs, ts=None):
        super().add(vs, fs, ts); s.owner += [TB.cur] * len(vs)
def on(bone): TB.cur = bone

B = {k: TB(m) for k, m in (('bone', 'bone'), ('black', 'black'), ('teeth', 'teeth'), ('necro', 'necro'), ('flame', 'necro'), ('leather', 'leather'), ('rim', 'shroud'), ('socket', 'socket'))}
S = {k: C.Bag(m) for k, m in (('robe', 'shroud'), ('under', 'cloth'), ('mantle', 'shroud'), ('hood', 'shroud'), ('sleeve', 'shroud'), ('tatter', 'shroud'))}
b = B['bone']

def loft(bag, rings, ts=None, cap_start=False, cap_end=False):
    n = len(rings[0]); vs = [p for r in rings for p in r]; F = []
    for j in range(len(rings) - 1):
        for i in range(n):
            a = j * n + i; c = j * n + (i + 1) % n
            F.append((a, c, c + n, a + n))
    if cap_start: F.append(tuple(reversed(range(n))))
    if cap_end: F.append(tuple(range((len(rings) - 1) * n, len(rings) * n)))
    bag.add(vs, F, ts)

# ---- skeleton joints: stooped far over, chin thrown up, left arm flung high, right planted on the staff
hip = V((0, .1, .82)); chest = V((0, .02, 1.22)); neck = V((0, -.2, 1.42)); H = V((0, -.42, 1.56))
foot_s, top_s = V((-.62, -.56, .0)), V((-.86, -.36, 1.8))
shL, elL, wrL, hdL = V((.26, -.14, 1.32)), V((.58, -.26, 1.14)), V((.74, -.52, 1.4)), V((.78, -.58, 1.56))
shR, elR = V((-.26, -.14, 1.3)), V((-.56, -.12, 1.1))
hdR = foot_s.lerp(top_s, .62); wrR = hdR + V((.06, .06, -.02))
TAIL_DIR = V((math.cos(math.radians(128)), math.sin(math.radians(128)), 0))

# ---- robe: one loft, folds growing downward, hem torn, the back sweeping out into a long point
def hem_notches(n, deep, big):
    # irregular teeth: each 2-4 verts wide, some deep tears, tips touching z=0
    out = []
    while len(out) < n:
        w = C.rng.choice((2, 2, 3, 3, 4)); d = C.rng.uniform(deep * .4, deep) * (big if C.rng.random() < .25 else 1)
        out += [d * abs(2 * j / w - 1) ** .8 if j else d for j in range(w)]
    out = out[:n]
    lo = min(out)
    return [x - lo for x in out]
RS = 44
SEC = [(1.33, -.12, .12, .12, 0, 0), (1.3, -.08, .25, .19, 0, 0), (1.2, .0, .27, .22, .01, 0), (1.06, .07, .22, .2, .015, 0), (.92, .1, .2, .19, .02, 0),
       (.76, .1, .22, .2, .03, .02), (.56, .08, .26, .25, .05, .05), (.36, .06, .33, .31, .09, .2), (.18, .05, .46, .44, .13, .5), (.08, .05, .62, .58, .15, .8), (.0, .05, .7, .65, .16, 1.0)]
def skirt_rings(sec, sides, notch=None, k=1.0, trail=.72, folds=7):
    rings = []
    for j, (z, cy, rx, ry, amp, tr) in enumerate(sec):
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            f = 1 + amp * math.sin(a * folds + 1.1) + amp * .5 * math.sin(a * 3 + .4)
            pull = max(0, math.cos(a - math.radians(128))) ** 7 * tr * trail
            zz = z; nn = 0
            if notch:
                if j == len(sec) - 1: nn = notch[i]; zz = nn
                elif j == len(sec) - 2: zz = max(z, notch[i] + .05)
            r = f * k * (1 - nn * .9)
            ring.append(V((rx * r * math.cos(a), cy + ry * r * math.sin(a), zz)) + TAIL_DIR * pull * (1 - nn * 1.5))
        rings.append(ring)
    return rings
notch = hem_notches(RS, .26, 1.5)
loft(S['robe'], skirt_rings(SEC, RS, notch))
# under-robe: teal, the minion's cloth, showing in the tears
UND = [(z, cy, rx, ry, amp * .5, tr) for z, cy, rx, ry, amp, tr in SEC[5:]]
loft(S['under'], skirt_rings(UND, 28, hem_notches(28, .05, 1.0), k=.82, trail=.5))

# ---- mantle: ragged shoulder cape, open at the front over the ribs
MS = 36
mn = hem_notches(MS, .2, 1.6)
msec = [(1.42, -.18, .12, .12), (1.36, -.12, .27, .22), (1.28, -.06, .38, .3), (1.16, -.02, .44, .35), (1.0, .0, .47, .38)]
rings = []
for j, (z, cy, rx, ry) in enumerate(msec):
    ring = []
    for i in range(MS):
        a = 2 * math.pi * i / MS
        front = max(0, -math.sin(a)) ** 3
        zz = z + front * (j / 4) ** 1.3 * .36
        if j == 4: zz += mn[i]
        f = 1 + .05 * math.sin(a * 5 + .7) * (j / 4)
        ring.append(V((rx * f * math.cos(a), cy + ry * f * math.sin(a), zz)))
    rings.append(ring)
loft(S['mantle'], rings)

# ---- the hood: a swept tube from the face opening back to a hooked point. Oversized, the read from above.
n = V((0, -.78, .62)).normalized(); ex = V((1, 0, 0)); eu = n.cross(ex).normalized()
if eu.z < 0: eu = -eu
O = H + n * .17
hoodpts = [O, H + V((0, .0, .02)), H + V((0, .16, .05)), H + V((.01, .31, .2)), H + V((.05, .36, .4)), H + V((.17, .29, .56)), H + V((.3, .2, .55))]
C.tube(S['hood'], hoodpts, [(.25, .27), (.32, .32), (.3, .29), (.2, .19), (.11, .105), (.05, .05), (.002, .002)], sides=14, sub=3, side=ex)
# brow-cut rim: the opening dips to a V in the middle, so the cowl itself scowls
on('head')
TILT = -math.atan2(n.z, -n.y)
def rim_pt(th):
    x = math.cos(th) * .25; u = math.sin(th) * .27
    if math.sin(th) > 0: u -= .11 * math.exp(-(abs(math.cos(th)) / .32) ** 2)
    return O + ex * x + eu * u + n * (.015 + .014 * math.sin(th * 5 + .6) + max(0, math.sin(th)) * .05)
RN = 20
ths = [-math.pi / 2 + 2 * math.pi * i / RN for i in range(RN + 1)]
C.tube(B['rim'], [rim_pt(t) for t in ths], [(.034 + .036 * max(0, math.sin(t)), .018 + .03 * max(0, math.sin(t))) for t in ths], sides=6, sub=2, side=n)
# a torn flap of cowl hanging off one side of the face
C.tube(B['rim'], [O + ex * -.24 + eu * .06, O + ex * -.31 + eu * -.1 + n * .02, O + ex * -.28 + eu * -.32], [(.055, .02), (.05, .018), (.002, .002)], sides=5, sub=2, side=ex)

# the shadow, the eyes, the grin
C.blob(B['black'], O, (.24, .075, .265), seg=14, rings=7, rot=(TILT, 0, 0))
E = O + n * .07
def eye(sx, scale, lift):
    inner = E + ex * sx * .03 + eu * (.0 + lift)
    C.tube(B['necro'], [inner, inner + ex * sx * .07 * scale + eu * .012 * scale, inner + ex * sx * .135 * scale + eu * .05 * scale, inner + ex * sx * .185 * scale + eu * .115 * scale],
           [(.03 * scale, .004), (.048 * scale, .004), (.03 * scale, .004), (.002, .002)], sides=6, sub=2, side=eu)
    C.blob(B['necro'], inner + ex * sx * .065 * scale + eu * .012 * scale + n * .008, (.024 * scale, .01, .022 * scale), seg=8, rings=5, t=1.0, rot=(TILT, 0, 0))
eye(1, 1.2, .03); eye(-1, .95, .0)
for i in range(9):
    x = -.12 + i * .03
    C.blob(B['teeth'], E + ex * x - eu * (.085 - x * x * 2.4) + n * (-.008 - abs(x) * .1), (.0145, .012, .027), seg=6, rings=4, rot=(TILT, 0, 0))
on('jaw')
for i in range(7):
    x = -.09 + i * .03
    C.blob(B['teeth'], E + ex * x - eu * (.145 - x * x * 3.2) + n * (-.018 - abs(x) * .1), (.0135, .012, .024), seg=6, rings=4, rot=(TILT, 0, 0))

# ---- ribs in the torn chest: black behind, bone in front
on('chest')
C.blob(B['black'], V((0, -.15, 1.1)), (.16, .085, .27), seg=12, rings=7)
for i in range(4):
    z = 1.24 - i * .082; w = .15 - i * .012
    for sx in (-1, 1):
        C.tube(b, [V((sx * w, -.13, z + .02)), V((sx * w * .8, -.22, z - .01)), V((sx * .02, -.25, z - .03))], [.02, .02, .014], sides=5, sub=2)
C.tube(b, [V((0, -.26, 1.28)), V((0, -.25, .96))], [.024, .016], sides=5, sub=1)
on('spine')
C.tube(B['black'], [V((0, -.08, .96)), V((0, -.1, .84))], [(.12, .05), (.04, .03)], sides=6, sub=1)
# lapels: the edge of the torn opening, thick shapes either side
on('chest')
for sx in (-1, 1):
    C.tube(B['rim'], [V((sx * .1, -.27, 1.38)), V((sx * .19, -.25, 1.2)), V((sx * .13, -.2, .98)), V((sx * .03, -.13, .84))], [(.04, .03), (.055, .03), (.05, .03), (.015, .012)], sides=6, sub=2)
# villain's collar: ribs fan up behind the hood, three and a broken one
for sx, tips in ((1, (.0, .13, .26)), (-1, (.03, .2))):
    for t in tips:
        a = V((sx * (.16 + t * .3), -.04 + t * .1, 1.32 - t * .12))
        tip = V((sx * (.5 + t * .5), .04 + t * .12, 1.68 - t * .75))
        C.tube(b, [a, a.lerp(tip, .45) + V((sx * .11, 0, -.03)), tip], [.03, .026, .002], sides=5, sub=2)

# ---- rope belt with trophies
on('hips')
C.tube(B['leather'], [V((.215 * math.cos(i * .524), .1 + .205 * math.sin(i * .524), .93)) for i in range(13)], [(.022, .022)] * 2, sides=5, sub=1)
on('hips')
sk = V((.2, -.12, .78))
C.tube(B['leather'], [V((.2, -.07, .93)), sk + V((0, 0, .06))], [.008, .008], sides=4, sub=1)
C.blob(b, sk, (.055, .055, .055), seg=8, rings=6); C.blob(B['socket'], sk + V((.02, -.048, .005)), (.014, .008, .014), seg=6, rings=4); C.blob(B['socket'], sk + V((-.02, -.048, .005)), (.014, .008, .014), seg=6, rings=4)
C.tube(B['leather'], [V((.12, -.11, .93)), V((.09, -.17, .74))], [.008, .008], sides=4, sub=1)
C.tube(b, [V((.09, -.17, .74)), V((.085, -.175, .58))], [.018, .014], sides=5, sub=1)
C.blob(b, V((.09, -.17, .74)), (.024, .024, .024), seg=6, rings=4); C.blob(b, V((.085, -.175, .58)), (.024, .024, .024), seg=6, rings=4)

# ---- arms: thin twin-boned, knobby
def limb(bone, a, c, r=.026, k=.046, twin=False):
    on(bone)
    if twin:
        o = (c - a).cross(V((0, 0, 1))).normalized() * .018
        C.tube(b, [a + o, c + o], [r * .7, r * .7], sides=5, sub=1); C.tube(b, [a - o, c - o], [r * .7, r * .7], sides=5, sub=1)
    else:
        C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=5, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5); C.blob(b, c, (k * .85, k * .85, k * .85), seg=8, rings=5)
limb('upperarm.l', shL, elL); limb('lowerarm.l', elL, wrL, .03, .048, True)
limb('upperarm.r', shR, elR); limb('lowerarm.r', elR, wrR, .03, .048, True)

# ---- sleeves: wide, torn, sagging off the bone
def sleeve(a, e, w, sx, drape, end=.6):
    pts = [a, a.lerp(e, .5), e, e.lerp(w, end * .5), e.lerp(w, end)]
    rad = [.1, .11, .12, .16, .21]
    NS = 20
    no = hem_notches(NS, .26, 1.3)
    rings = []
    for j, (p, r) in enumerate(zip(pts, rad)):
        tg = (pts[min(j + 1, 4)] - pts[max(j - 1, 0)]).normalized()
        s1 = tg.cross(V((0, 0, 1))).normalized(); s2 = s1.cross(tg).normalized()
        ring = []
        for i in range(NS):
            an = 2 * math.pi * i / NS
            q = p + s1 * r * math.cos(an) + s2 * r * math.sin(an)
            if math.sin(an) * s2.z < 0: q += V((0, 0, -drape * (j / 4) ** 2 * abs(math.sin(an))))
            if j == 4: q -= tg * no[i]
            ring.append(q)
        rings.append(ring)
    loft(S['sleeve'], rings)
    on('lowerarm.l' if sx > 0 else 'lowerarm.r')
    C.blob(B['black'], pts[4] - (pts[4] - pts[3]).normalized() * .1, (.09, .09, .09), seg=8, rings=5)
sleeve(shL, elL, wrL, 1, .34)
sleeve(shR, elR, wrR, -1, .3)

# ---- the enormous left hand: the second big shape. Palm to the enemy, index accusing, the rest hooked.
hU = (hdL - wrL).normalized(); hX = (V((1, 0, -.05)) - hU * V((1, 0, -.05)).dot(hU)).normalized(); hN = hX.cross(hU).normalized()
Pc = hdL - hU * .02
on('hand.l')
C.blob(b, wrL + hU * .02, (.075, .06, .06), seg=8, rings=5)
C.blob(b, Pc + hU * .03, (.14, .06, .12), seg=10, rings=6)    # solid palm: it has to read as a hand from the game camera
FING = [(-.135, -.34, 1.24, .1), (-.045, -.1, 1.45, .28), (.05, .12, 1.36, .62), (.135, .4, 1.1, .85)]
FSEG = []
for i, (x, a, L, cu) in enumerate(FING):
    base = Pc + hX * x + hU * .12
    d1 = (hU * math.cos(a) + hX * math.sin(a)).normalized()
    d2 = (d1 + hN * cu * .75).normalized(); d3 = (d1 + hN * cu * 1.9).normalized()
    p1 = base + d1 * .19 * L; p2 = p1 + d2 * .15 * L; p3 = p2 + d3 * .14 * L
    on('hand.l')
    C.blob(b, base, (.054, .05, .054), seg=8, rings=5)
    on('f%d.a' % i)
    C.tube(b, [base, p1], [.045, .036], sides=5, sub=1)
    C.blob(b, p1, (.046, .044, .046), seg=7, rings=4)
    on('f%d.b' % i)
    C.tube(b, [p1, p2], [.036, .03], sides=5, sub=1)
    C.blob(b, p2, (.038, .036, .038), seg=7, rings=4)
    C.tube(b, [p2, p2.lerp(p3, .5), p3], [.032, .022, .002], sides=5, sub=1)
    FSEG.append((base, p1, p3))
# thumb, on the inner side
tb0 = wrL + hU * .05 - hX * .08; tb1 = tb0 + (hU * .35 - hX * .9 + hN * .25).normalized() * .22; tb2 = tb1 + (hU * .8 - hX * .5 + hN * .5).normalized() * .22
on('hand.l'); C.blob(b, tb0, (.05, .05, .05), seg=7, rings=4)
on('thumb.a'); C.tube(b, [tb0, tb1], [.042, .034], sides=5, sub=1); C.blob(b, tb1, (.04, .04, .04), seg=7, rings=4)
on('thumb.b'); C.tube(b, [tb1, tb1.lerp(tb2, .5), tb2], [.03, .021, .002], sides=5, sub=1)
# a soul-ember sitting in the palm, the spell at rest
on('ember')
Em = Pc + hN * .13 + hU * .04
def flame(bag, base, h, w, lean=V((0, 0, 0)), tongues=3, flat=.95):
    up = V((0, 0, 1))
    C.tube(bag, [base - up * h * .08, base + up * h * .22 + lean * .2, base + up * h * .6 + lean * .6 + V((w * .4, 0, 0)), base + up * h + lean], [(w * .6, w * .6 * flat), (w, w * flat), (w * .5, w * .5 * flat), (.001, .001)], sides=8, sub=3, side=V((1, 0, 0)))
    for i in range(tongues):
        an = i * 2.4 + .6
        d = V((math.cos(an), math.sin(an) * .7, 0)); ht = (.72, .62, .5, .42)[i % 4]
        q = base + d * w * .5 + up * h * .04
        C.tube(bag, [q, q + d * w * .55 + up * h * ht * .4 + lean * .2, q + d * w * .2 + up * h * ht * .75 + lean * .5, q + d * w * .55 + up * h * ht + lean * .7], [(w * .42, w * .38), (w * .42, w * .38), (w * .2, w * .18), (.001, .001)], sides=5, sub=2, side=V((1, 0, 0)))
flame(B['flame'], Em, .22, .06, lean=V((.02, 0, 0)), tongues=2)

# ---- right hand wrapped round the staff
on('hand.r')
sdir = (top_s - foot_s).normalized()
grip = hdR
C.blob(b, wrR, (.052, .05, .05), seg=8, rings=5)
for i in range(4):
    o = sdir * (i - 1.5) * .045
    C.tube(b, [wrR + o * .5, grip + o + V((-.0, -.06, .0)) + V((.05, 0, 0)), grip + o + V((-.08, -.04, 0)), grip + o + V((-.07, .05, 0))], [.022, .024, .02, .005], sides=5, sub=2)
C.tube(b, [wrR + sdir * .05, grip + sdir * .11 + V((.05, .04, 0)), grip + sdir * .13 + V((-.04, .06, 0))], [.022, .02, .005], sides=5, sub=1)

# ---- staff of fused spines, finial skull, caged soul-flame
on('staff')
VN = 25
C.tube(b, [foot_s, foot_s.lerp(top_s, .5) + V((.015, .01, 0)), top_s], [.022, .025, .03], sides=5, sub=2)
bx = sdir.cross(V((0, 1, 0))).normalized()
by = sdir.cross(bx).normalized()
for i in range(VN):
    k = i / (VN - 1)
    p = foot_s.lerp(top_s, k) + bx * .012 * math.sin(k * 9)
    w = .03 + .026 * k + .012 * (i % 2)
    C.blob(b, p, (w, w, .03), seg=6, rings=4, rot=(.25 * math.sin(i * 1.7), .25 * math.cos(i * 1.3), 0))
    if i % 2 == 0 and k > .08:
        sd = bx if (i // 2) % 2 else -bx
        C.tube(b, [p + sd * w * .7, p + sd * (w + .045 + .03 * k) - sdir * .05], [.015, .002], sides=4, sub=1)
        C.tube(b, [p + by * w * .7, p + by * (w + .03) - sdir * .04], [.012, .002], sides=4, sub=1)
fs = top_s + sdir * .07
C.blob(b, fs, (.095, .1, .085), seg=10, rings=6)
C.blob(b, fs + V((0, -.06, -.04)), (.058, .05, .05), seg=8, rings=5)
for sx in (-1, 1): C.blob(B['socket'], fs + V((sx * .036, -.088, .0)), (.026, .012, .024), seg=7, rings=4)
for i in range(4): C.blob(B['teeth'], fs + V((-.027 + i * .018, -.102, -.06)), (.008, .008, .014), seg=5, rings=3)
Cg = fs + V((0, 0, .1))
for i in range(6):
    a = i * math.pi / 3 + .3
    d = V((math.cos(a), math.sin(a), 0))
    C.tube(b, [Cg + d * .06, Cg + d * .165 + V((0, 0, .12)), Cg + d * .165 + V((0, 0, .28)), Cg + d * .03 + V((.01, 0, .42))], [.016, .015, .013, .012], sides=4, sub=2)
C.tube(b, [Cg + V((0, 0, .41)), Cg + V((.01, 0, .47)), Cg + V((.06, 0, .55))], [.024, .016, .001], sides=5, sub=2)
on('flame')
flame(B['flame'], Cg + V((0, 0, .01)), .38, .1, lean=V((.02, 0, 0)), tongues=4)
B['flame'].t = [max(0, min(1, t + C.rng.uniform(-.1, .1))) for t in B['flame'].t]   # jagged cut bands

# ---- tatters: flat strips trailing behind, the bits that animate
def strip(bag, q, d, L, w, side):
    C.tube(bag, [q, q + d * L * .4 + V((0, 0, -.02)), q + d * L * .75 + V((C.rng.uniform(-.03, .03), 0, 0)), q + d * L], [(w, .012), (w * 1.1, .012), (w * .6, .01), (.002, .002)], sides=5, sub=2, side=side)
for i in range(7):
    a = math.radians(30 + i * 34)
    q = V((.5 * math.cos(a), .03 + .36 * math.sin(a), 1.12))
    strip(S['tatter'], q, V((math.cos(a) * .25, .1 + math.sin(a) * .25, -1)).normalized(), C.rng.uniform(.3, .55), .055, V((-math.sin(a), math.cos(a), 0)))

col = scn.collection
objs = {}
for k, bag in list(B.items()) + list(S.items()):
    if not bag.v: continue
    outline = 0 if k in ('socket', 'necro', 'teeth', 'black') else .006
    objs[k], t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()))

# ------------------------------------------------------------------ rig
def td(k): return V((.05, .05, 0)) + TAIL_DIR * k
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, -.02, .14)), 'root'),
    'spine': (hip + V((0, -.02, .14)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .04, -.2)), H + V((0, -.02, .2)), 'chest'),
    'jaw': (H + V((0, -.02, -.1)), E - eu * .17, 'head'),
    'hood.1': (H + V((0, .16, .05)), H + V((.03, .34, .32)), 'head'),
    'hood.2': (H + V((.03, .34, .32)), H + V((.17, .29, .56)), 'hood.1'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'ember': (Em, Em + V((0, 0, .25)), 'hand.l'),
    'thumb.a': (tb0, tb1, 'hand.l'), 'thumb.b': (tb1, tb2, 'thumb.a'),
    'staff': (grip, grip + sdir * .6, 'hand.r'),
    'flame': (Cg, Cg + V((0, 0, .36)), 'staff'),
    'sleeve.l': (elL.lerp(wrL, .4), elL.lerp(wrL, .4) + V((0, 0, -.4)), 'lowerarm.l'),
    'sleeve.r': (elR.lerp(wrR, .4), elR.lerp(wrR, .4) + V((0, 0, -.4)), 'lowerarm.r'),
    'mantle.l': (V((.3, -.03, 1.36)), V((.5, -.02, 1.08)), 'chest'),
    'mantle.r': (V((-.3, -.03, 1.36)), V((-.5, -.02, 1.08)), 'chest'),
    'mantle.b': (V((0, .15, 1.4)), V((0, .34, 1.08)), 'chest'),
    'skirt': (V((0, .06, .78)), V((0, .05, .3)), 'root'),
    'hem.f': (V((0, -.2, .48)), V((0, -.56, .04)), 'skirt'),
    'hem.l': (V((.24, .05, .48)), V((.62, .05, .04)), 'skirt'),
    'hem.r': (V((-.24, .05, .48)), V((-.62, .05, .04)), 'skirt'),
    'tail.1': (V((0, .3, .48)) + TAIL_DIR * .05, td(.58) + V((0, 0, .1)), 'skirt'),
    'tail.2': (td(.58) + V((0, 0, .1)), td(.95) + V((0, 0, .02)), 'tail.1'),
    'tail.3': (td(.95) + V((0, 0, .02)), td(1.28), 'tail.2'),
}
for i, (base, p1, p3) in enumerate(FSEG):
    bones['f%d.a' % i] = (base, p1, 'hand.l')
    bones['f%d.b' % i] = (p1, p3, 'f%d.a' % i)
R = CR.Rig('NecromancerRig', bones)
def skin_tagged(o, bag):
    g = {}
    for i, nm in enumerate(bag.owner): R._put(o, g, i, [(1, nm)])
    R._bind(o)
for k in B:
    if k in objs: skin_tagged(objs[k], B[k])
ROBE = ('hips', 'spine', 'chest', 'skirt', 'hem.f', 'hem.l', 'hem.r', 'tail.1', 'tail.2', 'tail.3')
R.skin_soft(objs['robe'], ROBE, power=3.5)
R.skin_soft(objs['under'], ROBE, power=3.5)
R.skin_soft(objs['mantle'], ('chest', 'mantle.l', 'mantle.r', 'mantle.b', 'head'), power=4)
R.skin_soft(objs['hood'], ('head', 'hood.1', 'hood.2'), power=4)
R.skin_soft(objs['sleeve'], ('upperarm.l', 'lowerarm.l', 'sleeve.l', 'upperarm.r', 'lowerarm.r', 'sleeve.r'), power=4)
R.skin_soft(objs['tatter'], ('mantle.l', 'mantle.r', 'mantle.b'), power=3)
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ animation (24 fps)
def P(*ds):
    out = {}
    for d in ds: out.update(d)
    return out
def claw(k, thumb=None, spread=0):
    """k degrees of extra curl over the rest pose; negative opens the hand wide."""
    d = {}
    for i in range(4):
        d['f%d.a' % i] = (k * .55, 0, 0) if not spread else (k * .55, (i - 1.5) * spread, 0)
        d['f%d.b' % i] = (k, 0, 0)
    tk = k if thumb is None else thumb
    d['thumb.a'] = (0, 0, tk * .6); d['thumb.b'] = (0, 0, tk * .8)
    return d

CHAIN_R = ('root', 'hips', 'spine', 'chest', 'upperarm.r', 'lowerarm.r', 'hand.r')
def _rl(spec):
    rot = spec.get('rot', (0, 0, 0)) if isinstance(spec, dict) else spec
    loc = spec.get('loc', (0, 0, 0)) if isinstance(spec, dict) else (0, 0, 0)
    return Euler([math.radians(a) for a in rot], 'XYZ').to_quaternion(), V(loc)
def staff_fix(pose, want=(0, 0, 0), plant=False):
    """Staff rotations add up down the arm chain: solve its world tilt here, and with plant=True slide it through the fist so the foot stays on the floor."""
    M = Matrix.Identity(4); q = Q()
    for n_ in CHAIN_R:
        e, l = _rl(pose.get(n_, (0, 0, 0)))
        h = bones[n_][0]
        M = M @ Matrix.Translation(l) @ Matrix.Translation(h) @ e.to_matrix().to_4x4() @ Matrix.Translation(-h)
        q = q @ e
    w = Euler([math.radians(a) for a in want], 'XYZ').to_quaternion()
    es = q.inverted() @ w
    pose = dict(pose); deg = [math.degrees(a) for a in es.to_euler('XYZ')]
    loc = V()
    if plant:
        h = bones['staff'][0]
        f = M @ Matrix.Translation(h) @ es.to_matrix().to_4x4() @ Matrix.Translation(-h) @ foot_s
        loc = q.inverted() @ V((0, 0, -f.z))
    pose['staff'] = {'rot': tuple(deg), 'loc': tuple(loc)}
    return pose

IDLE_A = P(claw(-4), {'hips': {'rot': (0, 0, 0), 'loc': (0, 0, 0)}, 'chest': (0, 0, 2), 'head': (0, 0, 2), 'upperarm.l': (0, 0, 0), 'hood.1': (-3, 0, 2), 'hood.2': (-5, 0, 4), 'tail.2': (1, 0, 0), 'flame': (0, -4, 0), 'ember': (0, 5, 0), 'jaw': (-3, 0, 0), 'sleeve.l': (0, -4, 0)})
IDLE_B = P(claw(12), {'hips': {'rot': (0, 0, 0), 'loc': (0, .0, -.035)}, 'chest': (3, 0, -2), 'head': (-5, 3, -3), 'upperarm.l': (0, -3, 0), 'lowerarm.l': (-3, 0, 0), 'hood.1': (3, 0, -3), 'hood.2': (6, 0, -6), 'tail.2': (3, 0, 0), 'tail.3': (4, 0, 0), 'flame': (0, 5, 0), 'ember': (0, -6, 0), 'jaw': (10, 0, 0), 'sleeve.l': (0, 5, 0), 'mantle.b': (4, 0, 0)})
IDLE_A = staff_fix(IDLE_A, plant=True); IDLE_B = staff_fix(IDLE_B, (1, 0, 0), plant=True)
R.action('Idle_Combat', 44, {0: IDLE_A, 22: IDLE_B, 44: IDLE_A})

# glide: no steps, the torso sails and the cloth drags behind the beat
def glide(s, c):
    return staff_fix(P(claw(4 + 12 * c), {'root': {'rot': (0, 0, 0), 'loc': (0, 0, .015 + .012 * s)},
        'hips': {'rot': (8, s * 5, c * 10), 'loc': (c * .03, -.02, .045 * s)}, 'chest': (8, s * 4, -c * 16), 'head': (-10, -s * 6, c * 14),
        'upperarm.l': (-c * 8, -6 + 5 * s, -c * 10), 'lowerarm.l': (c * 12, 0, 0), 'hand.l': (s * 8, 0, 0), 'upperarm.r': (-c * 12, 0, 0), 'lowerarm.r': (c * 6, 0, 0),
        'skirt': (5, s * 3, c * 7), 'hem.f': (-14 - 12 * s, 0, 0), 'hem.l': (0, -9 - 10 * c, 0), 'hem.r': (0, 9 - 10 * c, 0),
        'tail.1': (14 + 7 * s, 0, 14 * c), 'tail.2': (8 - 8 * c, 0, -20 * s), 'tail.3': (8 + 10 * s, 0, 26 * c),
        'hood.1': (-8 + 6 * c, 0, 10 * s), 'hood.2': (-14 + 8 * s, 0, 18 * c), 'sleeve.l': (-16, 12 * c, 0), 'sleeve.r': (-20, -9 * c, 0), 'mantle.b': (-20 + 8 * s, 0, 6 * c), 'mantle.l': (-12, 6 * s, 0), 'mantle.r': (-12, -6 * s, 0), 'flame': (-14, 8 * c, 0), 'ember': (-16, 0, 0), 'jaw': (6 + 6 * s, 0, 0)}), (16 * c - 6, 3, 0))
R.action('Walking_D_Skeletons', 24, {f: glide(math.sin(f / 24 * 6.2832), math.cos(f / 24 * 6.2832)) for f in (0, 4, 8, 12, 16, 20, 24)})

# channel: the big hand conducts a slow figure, the staff hums, the head nods with it
def weave(s, c):
    return P(claw(10 + 16 * s, spread=6 * c), {'hips': {'rot': (2, 0, c * 3), 'loc': (0, 0, -.03 + .02 * s)}, 'chest': (5 - 3 * s, 3 * c, c * 6), 'head': (-8 + 4 * s, c * 6, -c * 5),
        'upperarm.l': (-4 * s, -12 - 8 * c, -6 * s), 'lowerarm.l': (-8 + 8 * s, 8 * c, 8 * c), 'hand.l': (-12 + 14 * c, 0, 10 * s),
        'upperarm.r': (2, 3 * s, 0), 'staff': (0, 2 * c, 0), 'flame': (6 * s, 10 * c, 0), 'ember': (10 * c, 12 * s, 0), 'jaw': (10 + 6 * s, 0, 0), 'hood.1': (-3 * c, 0, 4 * s), 'hood.2': (-6 * c, 0, 8 * s),
        'sleeve.l': (6 * c, 10 * s, 0), 'tail.2': (2 + 2 * s, 0, 3 * c), 'tail.3': (3 + 3 * c, 0, 6 * s), 'mantle.l': (0, -6 * c, 0), 'hem.f': (-3 * s, 0, 0)})
R.action('Spellcasting', 32, {f: staff_fix(weave(math.sin(f / 32 * 6.2832), math.cos(f / 32 * 6.2832)), plant=True) for f in (0, 4, 8, 12, 16, 20, 24, 28, 32)})

# shoot: rear back, hand cocked at the ear, then the whole body throws the curse down the arm. Hold it. Enjoy it.
WIND = P(claw(46), {'hips': {'rot': (-6, 0, 16), 'loc': (0, .1, -.05)}, 'chest': (-12, 0, 26), 'head': (6, 0, -22), 'upperarm.l': (-10, -12, 42), 'lowerarm.l': (0, -8, 34), 'hand.l': (-24, 0, 0),
    'upperarm.r': (6, 0, 12), 'staff': (8, 0, 0), 'hood.1': (10, 0, 0), 'hood.2': (14, 0, 0), 'jaw': (-3, 0, 0), 'sleeve.l': (10, 0, 8), 'tail.1': (0, 0, 8), 'tail.2': (4, 0, 8), 'flame': (10, 0, 0)})
FIRE = P(claw(-14, spread=9), {'hips': {'rot': (8, 0, -14), 'loc': (0, -.16, -.1)}, 'chest': (8, 0, -28), 'head': (-20, 0, 24), 'upperarm.l': (0, -34, -62), 'lowerarm.l': (0, 58, 0), 'hand.l': (0, 0, 0),
    'upperarm.r': (-22, -6, 18), 'lowerarm.r': (-8, 0, 0), 'staff': (-12, 0, 0), 'hood.1': (-24, 0, 12), 'hood.2': (-30, 0, 20), 'jaw': (24, 0, 0), 'sleeve.l': (-28, 16, 0), 'sleeve.r': (-20, 0, 0),
    'skirt': (9, 0, -6), 'hem.f': (-16, 0, 0), 'tail.1': (20, 0, -6), 'tail.2': (14, 0, -14), 'tail.3': (18, 0, -20), 'mantle.b': (-26, 0, 0), 'mantle.l': (-16, -10, 0), 'flame': (-22, 0, 0), 'ember': (-30, 0, 0)})
FIRE2 = P(FIRE, {'hips': {'rot': (6, 0, -12), 'loc': (0, -.14, -.08)}, 'head': (-17, 0, 20), 'jaw': (18, 0, 0), 'hood.1': (-14, 0, 8), 'hood.2': (-16, 0, 12), 'mantle.b': (-14, 0, 0), 'tail.3': (8, 0, -8), 'flame': (-10, 0, 0)})
WIND = staff_fix(WIND, (6, 0, 6)); FIRE = staff_fix(FIRE, (-4, -6, 0), plant=True); FIRE2 = staff_fix(FIRE2, (-2, -4, 0), plant=True)
R.action('Spellcast_Shoot', 34, {0: IDLE_A, (9, 'out'): WIND, (12, 'in'): FIRE, (20, 'out'): FIRE2, 34: IDLE_A})

# summon: gather down low, arms crossing, then rip the dead up out of the floor with both arms. Curtain call pose.
SWIND = P(claw(50), {'hips': {'rot': (14, 0, 0), 'loc': (0, -.02, -.2)}, 'chest': (30, 0, 0), 'head': (-22, 0, 0), 'upperarm.l': (20, 40, 26), 'lowerarm.l': (46, 14, 40), 'hand.l': (30, 0, 0),
    'upperarm.r': (22, -36, -18), 'lowerarm.r': (10, -14, 0), 'staff': (-6, 0, 0), 'hood.1': (10, 0, 0), 'hood.2': (16, 0, 0), 'hem.f': (6, 0, 0), 'mantle.b': (10, 0, 0), 'sleeve.l': (8, 0, 0), 'jaw': (-3, 0, 0), 'flame': (0, 0, 0)})
SUP = P(claw(-22, spread=12), {'hips': {'rot': (-8, 0, 0), 'loc': (0, .03, .1)}, 'chest': (-12, 0, 0), 'head': (4, 0, 0), 'upperarm.l': (-4, -52, 6), 'lowerarm.l': (-22, -22, 0), 'hand.l': (-10, 0, 0),
    'upperarm.r': (-4, 64, -4), 'lowerarm.r': (-16, 30, 0), 'hand.r': (0, 8, 0), 'staff': (0, -44, 0), 'hood.1': (-26, 0, 0), 'hood.2': (-32, 0, 0), 'jaw': (30, 0, 0),
    'skirt': (0, 0, 0), 'hem.f': (-26, 0, 0), 'hem.l': (0, -26, 0), 'hem.r': (0, 26, 0), 'tail.1': (20, 0, 0), 'tail.2': (24, 0, 0), 'tail.3': (28, 0, 0),
    'mantle.b': (-34, 0, 0), 'mantle.l': (0, -34, 0), 'mantle.r': (0, 34, 0), 'sleeve.l': (0, -30, 0), 'sleeve.r': (0, 30, 0), 'flame': (-10, 0, 0), 'ember': (10, 0, 0)})
SUP2 = P(SUP, {'hips': {'rot': (-11, 0, 0), 'loc': (0, .04, .13)}, 'chest': (-15, 0, 3), 'head': (2, 0, -3), 'upperarm.l': (-4, -58, 6), 'upperarm.r': (-4, 70, -4), 'hood.1': (-12, 0, 0), 'hood.2': (-18, 0, 0), 'hem.f': (-12, 0, 0), 'hem.l': (0, -12, 0), 'hem.r': (0, 12, 0), 'tail.1': (8, 0, 0), 'tail.2': (8, 0, 0), 'tail.3': (10, 0, 0), 'mantle.b': (-16, 0, 0), 'mantle.l': (0, -16, 0), 'mantle.r': (0, 16, 0), 'sleeve.l': (0, -14, 0), 'sleeve.r': (0, 14, 0)})
SWIND = staff_fix(SWIND, (8, 8, 0)); SUP = staff_fix(SUP, (0, -16, 0)); SUP2 = staff_fix(SUP2, (0, -14, 0))
R.action('Spellcast_Summon', 50, {0: IDLE_A, (11, 'out'): SWIND, 15: SWIND, (18, 'in'): SUP, (34, 'smooth'): SUP2, 50: IDLE_A})

# hit: the villain is offended. Snaps back, hand splayed at the chest, hood whips over.
HURT = P(claw(-20, spread=8), {'hips': {'rot': (-14, 0, -6), 'loc': (0, .14, -.02)}, 'chest': (-20, 0, -12), 'head': (22, -10, 16), 'jaw': (32, 0, 0), 'upperarm.l': (20, 22, 20), 'lowerarm.l': (24, 0, 16),
    'upperarm.r': (-12, -10, 0), 'staff': (-8, 10, 0), 'hood.1': (32, 0, 8), 'hood.2': (36, 0, 12), 'mantle.b': (22, 0, 0), 'sleeve.l': (18, 0, 0), 'tail.1': (-2, 0, 0), 'hem.f': (-10, 0, 0), 'flame': (20, 0, 0)})
HURT = staff_fix(HURT, (-14, -8, 0))
R.action('Hit_A', 16, {0: IDLE_A, (2, 'hold'): HURT, 5: HURT, 16: IDLE_A})

# death: a last dramatic swoon with the hand clawing the air; then the robe is empty, it collapses, and the hand flops last.
D1 = P(claw(-24, spread=10), {'hips': {'rot': (-16, 0, 0), 'loc': (0, .1, .03)}, 'chest': (-22, 0, 8), 'head': (10, 10, 10), 'jaw': (34, 0, 0), 'upperarm.l': (-8, -58, 0), 'lowerarm.l': (-16, -26, 0),
    'upperarm.r': (-8, 18, -10), 'staff': (0, -30, 0), 'hood.1': (24, 0, 0), 'hood.2': (28, 0, 0), 'mantle.b': (16, 0, 0), 'flame': (14, 0, 0)})
D2 = P(claw(-8, spread=4), D1, {'chest': (-26, 0, 14), 'head': (6, 14, 14), 'jaw': (40, 0, 0), 'upperarm.l': (-8, -64, 0)})
D3 = P(claw(30), {'hips': {'rot': (24, 0, 10), 'loc': (0, .0, -.72)}, 'chest': (36, 0, 8), 'head': (-30, 22, -10), 'jaw': (30, 0, 0), 'upperarm.l': (-56, -66, 0), 'lowerarm.l': (-30, -24, 0), 'hand.l': (-10, 0, 0), 'upperarm.r': (30, 40, -30), 'lowerarm.r': (0, 20, 0), 'staff': (0, 72, 0),
    'skirt': {'rot': (0, 0, 0), 'loc': (0, 0, -.08)}, 'hem.f': (-40, 0, 0), 'hem.l': (0, -38, 0), 'hem.r': (0, 38, 0), 'tail.1': (-6, 0, 0), 'hood.1': (20, 0, 20), 'hood.2': (30, 0, 30), 'mantle.b': (20, 0, 0), 'mantle.l': (0, -20, 0), 'mantle.r': (0, 20, 0), 'flame': (0, -30, 0)})
D4 = P(claw(70), D3, {'upperarm.l': (20, 44, 0), 'lowerarm.l': (10, 30, 0), 'hand.l': (30, 0, 0), 'hips': {'rot': (28, 0, 10), 'loc': (0, .0, -.75)}, 'head': (-26, 26, -14)})
D1 = staff_fix(D1, (0, -26, 0)); D2 = staff_fix(D2, (0, -30, 0)); D3 = staff_fix(D3, (0, 86, 0)); D4 = dict(D4); D4['staff'] = D3['staff']
R.action('Death_A', 56, {0: IDLE_A, (3, 'hold'): HURT, (12, 'out'): D1, 22: D2, (30, 'in'): D3, 42: D3, (47, 'in'): D4, 56: D4})

# dodge: yanked backwards on a wire, the robe lagging forward of him, then a slow haughty resettle
DPREP = P(claw(24), {'hips': {'rot': (12, 0, 0), 'loc': (0, -.05, -.12)}, 'chest': (14, 0, 0), 'head': (-10, 0, 0), 'hood.1': (6, 0, 0)})
DFLY = P(claw(-16, spread=8), {'root': {'rot': (-10, 0, 0), 'loc': (0, .85, .14)}, 'hips': {'rot': (-16, 0, 0), 'loc': (0, -.04, .04)}, 'chest': (28, 0, 0), 'head': (-2, 0, 0), 'upperarm.l': (34, -18, -6), 'lowerarm.l': (30, 0, 0), 'upperarm.r': (30, 18, 6), 'staff': (-14, 0, 0),
    'skirt': (-22, 0, 0), 'hem.f': (-34, 0, 0), 'hem.l': (0, -18, 0), 'hem.r': (0, 18, 0), 'tail.1': (-8, 0, 0), 'tail.2': (-4, 0, 0), 'hood.1': (-34, 0, 0), 'hood.2': (-30, 0, 0), 'mantle.b': (-20, 0, 0), 'mantle.l': (-22, 0, 0), 'mantle.r': (-22, 0, 0), 'sleeve.l': (-30, 0, 0), 'sleeve.r': (-30, 0, 0), 'flame': (-30, 0, 0), 'ember': (-30, 0, 0)})
DLAND = P(claw(8), {'root': {'rot': (0, 0, 0), 'loc': (0, 1.05, 0)}, 'hips': {'rot': (10, 0, 0), 'loc': (0, -.02, -.1)}, 'chest': (10, 0, 0), 'head': (-16, 0, 0), 'upperarm.l': (-4, -8, 0), 'hood.1': (18, 0, 0), 'hood.2': (24, 0, 0), 'mantle.b': (14, 0, 0), 'tail.1': (-2, 0, 0), 'tail.2': (6, 0, 0), 'hem.f': (6, 0, 0), 'sleeve.l': (14, 0, 0), 'flame': (14, 0, 0)})
HOME = P(IDLE_A, {'root': {'rot': (0, 0, 0), 'loc': (0, 1.05, 0)}})
DFLY = staff_fix(DFLY, (-14, -4, 0)); DLAND = staff_fix(DLAND, (6, 0, 0)); HOME = staff_fix(HOME, plant=True)
R.action('Dodge_Backward', 26, {0: P(IDLE_A, {'root': {'rot': (0, 0, 0), 'loc': (0, 0, 0)}}), (4, 'out'): staff_fix(P(DPREP, {'root': {'rot': (0, 0, 0), 'loc': (0, 0, 0)}}), plant=True), (8, 'in'): DFLY, (11, 'out'): DLAND, 26: HOME})

# launch recovery and the second flinch, which enemy.gd plays
R.action('Hit_B', 14, {0: IDLE_A, (2, 'hold'): {'hips': {'rot': (12, 0, -8), 'loc': (0, -.06, -.02)}, 'chest': (20, 0, -14), 'head': (-22, 0, 18)}, 14: IDLE_A})
_LIE = {'hips': {'rot': (-82, 0, 0), 'loc': (0, .15, -.6)}, 'chest': (-6, 0, 0), 'head': (10, 0, 0)}
_KNEEL = {'hips': {'rot': (-20, 0, 0), 'loc': (0, .05, -.3)}, 'chest': (30, 0, 0), 'head': (-10, 0, 0)}
R.action('Lie_StandUp', 32, {0: _LIE, (8, 'hold'): _LIE, (20, 'out'): _KNEEL, (32, 'in'): IDLE_A})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.5, -5.5, 1.35), (0, -.1, 1.14), lens=42)
game = C.camera('CamGame', (0, -3.8, 5.55), (0, 0, 1.0), ortho=3.6)
side = C.camera('CamSide', (-5.6, -1.2, 1.35), (0, .1, 1.1), lens=42)
sheet = C.camera('CamSheet', (3.4, -4.6, 2.3), (-.02, -.05, 1.06), lens=44)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)

# feet-on-the-floor check: lowest hem vertex and the staff foot, per frame of the stance clips
def measure(act, frames):
    for f in frames:
        R.play(act, f)
        dg = bpy.context.evaluated_depsgraph_get()
        me = objs['robe'].evaluated_get(dg).to_mesh()
        zs = [v.co.z for v in me.vertices]
        lo = min(zs); objs['robe'].evaluated_get(dg).to_mesh_clear()
        sp = R.obj.pose.bones['staff']; foot = (R.obj.matrix_world @ sp.matrix @ sp.bone.matrix_local.inverted() @ foot_s)
        print('  ground %-20s f%-3d hem_min_z %+.3f staff_foot (%+.2f %+.2f %+.3f)' % (act, f, lo, foot.x, foot.y, foot.z))
measure('Idle_Combat', (0, 22)); measure('Walking_D_Skeletons', (0, 12)); measure('Spellcasting', (0, 8, 16, 24)); measure('Spellcast_Shoot', (9, 12)); measure('Spellcast_Summon', (15, 18)); measure('Hit_A', (2,))

def sheet_render(frames, cam, out_png, cols=5, tile=384):
    """Like comic_rig.contact_sheet but crops each 16:9 render to a centred square, so the character fills the tile."""
    tmp = tempfile.mkdtemp(prefix='sheet_necro_')
    scn.camera = cam; scn.render.image_settings.file_format = 'PNG'
    for i, (a, f) in enumerate(frames):
        R.play(a, f)
        scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
        bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                    '-vf', 'crop=ih:ih,scale=%d:-1,tile=%dx%d' % (tile, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
sheet_render([('Idle_Combat', 22), ('Walking_D_Skeletons', 0), ('Walking_D_Skeletons', 12), ('Spellcasting', 8), ('Spellcasting', 24),
              ('Spellcast_Shoot', 9), ('Spellcast_Shoot', 13), ('Spellcast_Summon', 15), ('Spellcast_Summon', 19), ('Spellcast_Summon', 34),
              ('Hit_A', 3), ('Death_A', 20), ('Death_A', 36), ('Death_A', 56), ('Dodge_Backward', 8)], sheet, os.path.join(OUT, NAME + '_motion.png'))
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME)
