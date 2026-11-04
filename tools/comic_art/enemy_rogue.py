# Skeleton Rogue: the fast flanker. Lean, low, wrapped head with long streaming tails, twin poisoned daggers held wide.
#   blender -b -P enemy_rogue.py
# Front -Y, its left +X, up +Z. Geometry, rig, animations, sheets, export, same as enemy_minion.py.
# Animation: poses are stated in the world and solved for every frame (as enemy_shield.py), so feet stay planted.
# Clip names come from scripts/enemy.gd: run_anim is Running_C, the dodge is Dodge_Backward (played at speed 1.8 for a
# 0.35 s state, so its 15 frames last 0.35 s), and the chop lands at 45% of its length (frame 11 of 24).
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Quaternion as Q, Euler
NAME = 'rogue'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['wrap'] = C.toon('P_Wrap', (.1, .02, .14), (.32, .07, .28), (.58, .16, .4), (.8, .34, .52), rim=(.26, .08, .24), brush=.26, inner=.14)  # the rogue's accent
M['steel'] = C.toon('P_Steel', (.08, .1, .2), (.32, .38, .52), (.62, .7, .82), (.88, .93, 1), rim=(.26, .36, .5), brush=.12, inner=.08)
M['iron'] = C.toon('P_IronPlain', (.05, .06, .14), (.2, .25, .38), (.46, .54, .68), (.86, .92, 1), rim=(.18, .3, .5), brush=.16, inner=.2)
C.rng.seed(23)

CUR = 'hips'
class TB(C.Bag):
    """A bag that remembers which bone each piece was built for."""
    def __init__(s, *a, **k):
        super().__init__(*a, **k); s.parts = []
    def add(s, vs, fs, ts=None):
        n = len(s.v); super().add(vs, fs, ts); s.parts.append((n, len(s.v), CUR))
B = {k: TB(k) for k in ('bone', 'socket', 'teeth', 'leather', 'wrap', 'necro', 'iron')}
B['steel'] = TB('steel', smooth=False)
b = B['bone']

# ---- joints: a deep predator crouch. Hips low and back, spine long and level-ish, skull thrust out, knees wide
hip = V((0, .3, .58)); chest = V((0, 0, .86)); neck = V((0, -.14, .92)); H = V((0, -.34, .98))
shL, elL, wrL = V((.22, -.02, .92)), V((.47, -.08, .72)), V((.62, -.34, .68))
shR, elR, wrR = V((-.22, -.02, .92)), V((-.47, -.08, .72)), V((-.62, -.34, .68))
hdL = wrL + V((.03, -.08, -.01)); hdR = wrR + V((-.03, -.08, -.01))
hpL, knL, anL = V((.12, .3, .55)), V((.37, .0, .42)), V((.28, .26, .08))
hpR, knR, anR = V((-.12, .3, .55)), V((-.33, .08, .39)), V((-.26, .42, .08))
K = .93
def HP(x, y, z): return H + V((x, y, z)) * K
J0 = HP(0, -.1, -.13)

# ---- skull: the family face, narrowed. The wrap covers the crown; a low brow leaves only the eyes and the grin
CUR = 'head'
C.blob(b, HP(0, .02, .04), (.185 * K, .21 * K, .165 * K), seg=12, rings=8)
C.blob(b, HP(0, -.12, -.03), (.118 * K, .1 * K, .1 * K), seg=12, rings=7)
for sx in (-1, 1):
    C.blob(b, HP(sx * .118, -.09, -.02), (.04, .05, .04), seg=8, rings=5)
    # narrow slanted eyes: the sneer
    C.blob(B['socket'], HP(sx * .07, -.185, .022), (.06, .03, .042), seg=10, rings=6, rot=(0, sx * .3, 0))
    C.blob(B['necro'], HP(sx * .072, -.21, .02), (.028, .012, .018), seg=8, rings=5, t=.9, rot=(0, sx * .3, 0))
C.blob(B['socket'], HP(0, -.215, -.045), (.02, .012, .026), seg=7, rings=5)
for i in range(7):
    x = -.08 + i * .0267
    C.blob(B['teeth'], HP(x, -.2 + abs(x) * .4, -.1), (.012, .012, .022), seg=6, rings=4)
CUR = 'jaw'
C.tube(b, [HP(-.115, -.04, -.07), J0 + V((-.08, -.04, -.03)), J0 + V((0, -.09, -.05)), J0 + V((.08, -.04, -.03)), HP(.115, -.04, -.07)], [.022, .028, .032, .028, .022], sides=6, sub=2)
for i in range(5):
    x = -.052 + i * .026
    C.blob(B['teeth'], J0 + V((x, -.09 + abs(x) * .4, -.016)), (.011, .011, .017), seg=6, rings=4)

# the wrap: a tight cowl over the crown, a brow fold down to the eyes, a knot at the back, two long tails
CUR = 'head'
wr = B['wrap']
C.blob(wr, HP(0, .035, .085), (.215, .245, .17), seg=14, rings=8)
for sx in (-1, 1):
    C.tube(wr, [HP(0, -.222, .058), HP(sx * .08, -.222, .082), HP(sx * .165, -.165, .112), HP(sx * .225, -.03, .1)], [(.03, .02), (.03, .022), (.034, .024), (.032, .022)], sides=6, sub=2)
    C.tube(wr, [HP(sx * .2, -.04, .03), HP(sx * .185, -.08, -.04), HP(sx * .12, -.12, -.1)], [(.05, .02), (.04, .02), (.008, .01)], sides=5, sub=1, side=V((0, 1, 0)))
for sx in (-1, 1):
    C.tube(wr, [HP(sx * .17, -.1, .17), HP(sx * .05, .02, .255), HP(-sx * .07, .19, .19)], [.01, .022, .008], sides=5, sub=2)
C.tube(B['leather'], [HP(.215 * math.cos(i * .524), .035 + .245 * math.sin(i * .524), .1) for i in range(13)], [(.016, .02)] * 2, sides=5, sub=1, side=V((0, 0, 1)))
C.blob(wr, HP(0, .29, .1), (.082, .07, .07), seg=8, rings=5)
# ragged neck scarf, under the jaw
CUR = 'chest'
C.tube(wr, [neck + V((-.11, .05, -.0)), neck + V((-.1, -.09, -.03)), neck + V((0, -.15, -.05)), neck + V((.1, -.09, -.03)), neck + V((.11, .05, -.0))], [(.06, .05), (.07, .06), (.075, .065), (.07, .06), (.06, .05)], sides=7, sub=2)

for sx in (-1, 1):
    for i in range(2):
        q = chest + V((sx * (.12 + i * .09), .03, .08 - i * .025))
        C.tube(wr, [q, q + V((sx * .03, .1, -.05)), q + V((sx * .05, .2 - i * .04, -.15))], [(.05, .007), (.055, .007), (.002, .002)], sides=5, sub=2, side=V((1, 0, 0)))
# the tails: built as chains so they trail and whip. Long enough to change the silhouette from above
TAILS = {}
def tail(tag, sx, n, L, wid, out=.2, bend=.13):
    global CUR
    root = HP(sx * .04, .3, .1)
    d = V((sx * out, .86, .34)).normalized()
    pts = [root]
    for i in range(n):
        d = (d + V((sx * bend, .0, -.1))).normalized()
        pts.append(pts[-1] + d * (L / n))
    for i in range(n):
        CUR = '%s.%d' % (tag, i)
        a_, c_ = pts[i], pts[i + 1]
        w0 = wid * (.72 + .28 * math.sin(math.pi * (i + .3) / n)); w1 = wid * (.72 + .28 * math.sin(math.pi * (i + 1.3) / n))
        if i == n - 1: w1 = .003
        sd_ = V((0, 0, 1)).cross(c_ - a_).normalized()
        C.tube(wr, [a_, c_], [(w0, .012), (w1, .012)], sides=4, sub=1, side=sd_, cap=False)  # no caps: they shade as dark bands
    TAILS[tag] = pts
tail('tail.l', 1, 3, .86, .09, out=.3, bend=.2)
tail('tail.r', -1, 3, .44, .08, out=.62, bend=.06)  # uneven on purpose: an even pair reads as rabbit ears

# ---- body: a thin bare cage, spine showing, crossed bandolier, one rag at the hip
CUR = 'spine'
vb = [hip.lerp(chest, i / 5) for i in range(6)]
for i, p in enumerate(vb):
    C.blob(b, p + V((0, .03, .04)), (.04, .042, .03), seg=8, rings=5)
CUR = 'chest'
C.tube(b, [chest + V((0, .03, .04)), neck, HP(0, .03, -.1)], [.032, .028, .03], sides=6, sub=1)
ax = (neck - hip).normalized()                       # along the spine
for i in range(4):
    p = chest - ax * (i * .07 - .02); w = .165 - i * .016
    for sx in (-1, 1):
        C.tube(b, [p + V((sx * .01, .03, .03)), p + V((sx * w * .85, .0, .0)), p + V((sx * w, -.1, -.08)), p + V((sx * w * .45, -.17, -.14)), p + V((sx * .02, -.18, -.16))], [.015, .018, .017, .015, .012], sides=5, sub=2)
C.tube(b, [shL, neck + V((0, .02, -.03)), shR], [.024, .018, .024], sides=6, sub=2)
C.tube(B['leather'], [shL + V((-.02, -.05, .04)), chest + V((.02, -.19, -.08)), chest + V((-.15, -.12, -.3))], [(.028, .008), (.028, .008)], sides=5, sub=2, side=V((1, 0, 0)))
C.tube(B['leather'], [shR + V((.02, -.05, .04)), chest + V((-.02, -.19, -.08)), chest + V((.15, -.12, -.3))], [(.028, .008), (.028, .008)], sides=5, sub=2, side=V((1, 0, 0)))
for i in range(3):
    C.tube(B['iron'], [chest + V((-.1 + i * .05 + .02, -.2 + i * .012, -.1 - i * .045 + .03)), chest + V((-.1 + i * .05 + .02, -.21 + i * .012, -.1 - i * .045 - .03))], [.014, .012], sides=5, sub=1)
CUR = 'hips'
C.blob(b, hip + V((0, 0, -.02)), (.155, .11, .08), seg=10, rings=6, p=2.3)
C.tube(B['leather'], [hip + V((.175 * math.cos(i * .524), .125 * math.sin(i * .524), .02)) for i in range(13)], [(.04, .014)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
C.blob(B['leather'], hip + V((.17, -.07, -.03)), (.05, .036, .06), seg=7, rings=4, p=2.5)     # pouch
C.blob(B['leather'], hip + V((-.17, -.03, -.03)), (.04, .03, .05), seg=7, rings=4, p=2.5)
CUR = 'SOFT'
for i in range(5):
    a_ = .35 + i * .6
    o = V((math.cos(a_), math.sin(a_) * .8, 0))
    q = hip + V((o.x * .15, o.y * .11, -.02))
    L = C.rng.uniform(.22, .32)
    C.tube(wr, [q, q + o * .02 - V((0, -.04, L * .5)), q + o * .04 + V((0, .08, -L))], [(.04, .006), (.046, .006), (.002, .002)], sides=5, sub=2, side=o.cross(V((0, 0, 1))))

# ---- limbs: long thin shafts, wrapped forearms and shins
def limb(tag, a, c, r=.026, k=.042, kc=None):
    global CUR; CUR = tag
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5)
    if kc: C.blob(b, c, (kc, kc, kc), seg=8, rings=5)
limb('upperarm.l', shL, elL, kc=.038); limb('upperarm.r', shR, elR, kc=.038)
limb('lowerarm.l', elL, wrL, .021); limb('lowerarm.r', elR, wrR, .021)
limb('upperleg.l', hpL, knL, .032, .05, kc=.05); limb('upperleg.r', hpR, knR, .032, .05, kc=.05)
limb('lowerleg.l', knL, anL, .026); limb('lowerleg.r', knR, anR, .026)
def wraps(tag, a, c, n, r0, r1):
    global CUR; CUR = tag
    d = (c - a).normalized()
    for i in range(n):
        k = i / max(n - 1, 1); p = a.lerp(c, k)
        rr = r0 + (r1 - r0) * k
        C.tube(B['leather'], [p - d * .021, p + d * .021], [(rr, rr), (rr, rr)], sides=6, sub=1)
wraps('lowerarm.l', elL.lerp(wrL, .35), wrL, 4, .034, .04); wraps('lowerarm.r', elR.lerp(wrR, .35), wrR, 4, .034, .04)
wraps('lowerleg.l', knL.lerp(anL, .4), anL, 4, .038, .042); wraps('lowerleg.r', knR.lerp(anR, .4), anR, 4, .038, .042)
def hand(tag, w, h):
    global CUR; CUR = tag
    d = (h - w).normalized()
    C.blob(b, w + d * .05, (.046, .05, .04), seg=8, rings=5)
    for i in range(3):
        o = V((0, 0, 1)) * (i - 1) * .026
        C.tube(b, [w + d * .06 + o, w + d * .11 + o * 1.1 + V((0, 0, -.02))], [.014, .011], sides=5, sub=1)
hand('hand.l', wrL, hdL); hand('hand.r', wrR, hdR)
def foot(tag, an):
    global CUR; CUR = tag
    C.blob(B['leather'], an + V((0, -.06, -.05)), (.056, .115, .03), seg=8, rings=5)
    for i in range(3):
        o = V(((i - 1) * .028, -.16, -.062))
        C.tube(b, [an + V((o.x, -.12, -.056)), an + o], [.015, .005], sides=5, sub=1)
foot('foot.l', anL); foot('foot.r', anR)

# ---- daggers: long, curved, forward grip, splayed outward, blade flat to the game camera. Green poisoned edge
VIEW = V((0, .58, -.81)).normalized()
def dagger(tag, hd_, sx):
    global CUR; CUR = tag
    d = V((sx * .62, -.72, .22)).normalized()     # hand to point: out and forward, a mantis read
    w = d.cross(VIEW).normalized()
    if w.dot(V((sx, .1, 0))) < 0: w = -w
    f = w.cross(d).normalized()
    a = hd_ + d * .03
    # handle, guard, pommel
    C.tube(B['leather'], [a - d * .09, a + d * .1], [.022, .02], sides=6, sub=1)
    C.blob(B['iron'], a - d * .1, (.03, .03, .03), seg=6, rings=4)
    C.tube(B['iron'], [a + d * .1 - w * .1, a + d * .1, a + d * .1 + w * .1 + d * .03], [.012, .024, .01], sides=5, sub=1)
    # blade: a long curve bending to the inside edge
    STN = [(.1, .05), (.25, .062), (.42, .06), (.57, .045), (.68, .004)]
    bend = lambda k: -w * (.14 * k * k)
    vs, fs = [], []
    for s_, wd_ in STN:
        p = a + d * s_ + bend(s_ / .68)
        vs += [p + w * wd_, p + f * .014, p - w * wd_ * .9, p - f * .014]
    n = len(STN)
    for i in range(n - 1):
        for k in range(4):
            j = i * 4
            fs.append((j + k, j + (k + 1) % 4, j + 4 + (k + 1) % 4, j + 4 + k))
    fs.append((3, 2, 1, 0)); fs.append(tuple(range((n - 1) * 4, n * 4)))
    B['steel'].add(vs, fs)
    # poison along the outside edge, as a strip with its own mesh: reads green from any angle
    edge = [a + d * s_ + bend(s_ / .68) + w * (wd_ - .004) for s_, wd_ in STN]
    C.tube(B['necro'], edge, [(.012, .018), (.013, .018), (.012, .017), (.009, .012), (.001, .001)], sides=4, sub=1, side=f)
    return a, d
DL = dagger('weapon.l', hdL, 1)
DR = dagger('weapon.r', hdR, -1)

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
    'hips': (hip, hip + V((0, -.02, .1)), 'root'),
    'spine': (hip + V((0, -.02, .1)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .03, -.13)), H + V((0, -.03, .23)), 'chest'),
    'jaw': (HP(0, -.03, -.08), J0 + V((0, -.12, -.03)), 'head'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'weapon.l': (DL[0], DL[0] + DL[1] * .4, 'hand.l'), 'weapon.r': (DR[0], DR[0] + DR[1] * .4, 'hand.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.16, -.06)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.16, -.06)), 'lowerleg.r'),
    'cloth': (hip + V((0, .1, -.04)), hip + V((0, .16, -.3)), 'hips'),
}
for tag, pts in TAILS.items():
    for i in range(len(pts) - 1):
        bones['%s.%d' % (tag, i)] = (pts[i], pts[i + 1], 'head' if i == 0 else '%s.%d' % (tag, i - 1))
R = CR.Rig('RogueRig', bones)
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
ARMPOLE = {'l': V((.75, .55, -.35)).normalized(), 'r': V((-.75, .55, -.35)).normalized()}
Z3 = (0, 0, 0)
EMPTY = dict(hr=Z3, hl=Z3, sp=Z3, ch=Z3, hd=Z3, jw=Z3, cl=Z3, L=Z3, R=Z3, Lp=Z3, Rp=Z3, Lk=tuple(POLE['L']), Rk=tuple(POLE['R']),
             Ar=Z3, Al=Z3, Br=Z3, Bl=Z3, tl=Z3, tr=Z3)   # A = left wrist/dagger, B = right; t = tail curl, per link
ROTS = ('hr', 'sp', 'ch', 'hd', 'jw', 'cl', 'Lp', 'Rp', 'Ar', 'Br', 'tl', 'tr')
EPS = V((3e-6, 0, 0))
def arm(a, e, w, A, T, pole, Dc):
    ek, en = two_bone(a, e, w, A, T, pole)
    Du = (e - a).rotation_difference(ek - A); Dl = (w - e).rotation_difference(en - ek)
    return deg(Dc.inverted() @ Du), deg(Du.inverted() @ Dl), Dl
def solve(p):
    out = {}
    Dh = p['hr']; Ph = HEAD0['hips'] + V(p['hl'])
    out['hips'] = {'rot': deg(Dh), 'loc': tuple(p['hl'])}
    Ds = Dh @ p['sp']; Ps = rel('spine', 'hips', Ph, Dh); out['spine'] = deg(p['sp'])
    Dc = Ds @ p['ch']; Pc = rel('chest', 'spine', Ps, Ds); out['chest'] = deg(p['ch'])
    Dhead = p['hd']
    out['head'] = {'rot': deg(Dc.inverted() @ Dhead), 'loc': tuple(EPS)}
    out['jaw'] = deg(p['jw']); out['cloth'] = deg(p['cl'])
    for nm, s_, e_, w_, wrot, wl, pole in (('l', shL, elL, wrL, p['Ar'], p['Al'], ARMPOLE['l']), ('r', shR, elR, wrR, p['Br'], p['Bl'], ARMPOLE['r'])):
        A = rel('upperarm.' + nm, 'chest', Pc, Dc)
        u_, l_, Dl = arm(s_, e_, w_, A, w_ + V(wl), pole, Dc)
        out['upperarm.' + nm] = u_; out['lowerarm.' + nm] = l_; out['hand.' + nm] = deg(Dl.inverted() @ wrot)
    for key, a, k_, c, nm in (('L', hpL, knL, anL, 'l'), ('R', hpR, knR, anR, 'r')):
        A = rel('upperleg.' + nm, 'hips', Ph, Dh)
        ek, en = two_bone(a, k_, c, A, c + V(p[key]), V(p[key + 'k']))
        Du_ = (k_ - a).rotation_difference(ek - A); Dl_ = (c - k_).rotation_difference(en - ek)
        out['upperleg.' + nm] = deg(Dh.inverted() @ Du_); out['lowerleg.' + nm] = deg(Du_.inverted() @ Dl_)
        out['foot.' + nm] = deg(Dl_.inverted() @ p[key + 'p'])
    for tag, q in (('tail.l', p['tl']), ('tail.r', p['tr'])):
        for i in range(3): out['%s.%d' % (tag, i)] = deg(q)
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
DA = {'l': DL[1], 'r': DR[1]}
def aimL(d): return deg(DA['l'].rotation_difference(V(d).normalized()))
def aimR(d): return deg(DA['r'].rotation_difference(V(d).normalized()))
def PP(base, **kw):
    q = dict(base); q.update(kw); return q

# ------------------------------------------------------------------ animation (24 fps)
# hd is the skull's world rotation (-X lifts the face to the camera); +X on the jaw drops it; tail pose rotates each link
IDLE_A = dict(hr=(0, 0, 0), hl=(.012, 0, -.01), ch=(0, 0, 0), hd=(-18, 0, 0), jw=(3, 0, 0), Al=(.01, 0, 0), Bl=(-.01, 0, 0), tl=(-2, 0, 3), tr=(-2, 0, -3))
IDLE_B = dict(hr=(3, 0, -5), hl=(-.05, .01, -.05), ch=(4, 0, 6), hd=(-14, 0, -9), jw=(7, 0, 0), Al=(.03, -.03, .05), Bl=(-.04, .02, -.03), Ar=(0, 0, -6), Br=(0, 0, -8), tl=(-7, 0, -3), tr=(-5, 0, 3), cl=(6, 0, 0))
IDLE_C = dict(hr=(3, 0, 6), hl=(.07, .01, -.05), ch=(4, 0, -7), hd=(-14, 0, 10), jw=(5, 0, 0), Al=(.04, .02, -.03), Bl=(-.03, -.03, .05), Ar=(0, 0, 8), Br=(0, 0, 6), tl=(-5, 0, 5), tr=(-7, 0, -5), cl=(6, 0, 0))
act('Idle_Combat', 32, {0: IDLE_A, 8: IDLE_B, 24: IDLE_C, 32: IDLE_A})

# the sprint: pitched far forward, arms swept back, daggers trailing like fins, tails flat out behind
def sprint(t):
    s = .34; sw = .46
    def fy(ph):
        ph %= 1
        if ph < sw:
            k = ph / sw; k2 = k * k * (3 - 2 * k)
            return s - 2 * s * k2, .17 * math.sin(math.pi * k), math.sin(math.pi * k)
        return -s + 2 * s * (ph - sw) / (1 - sw), 0.0, 0.0
    ly, lz, lk = fy(t); ry, rz, rk = fy(t + .5)
    w = 2 * math.pi * t
    flap = math.sin(2 * w)
    return dict(hr=(16, 2.5 * math.cos(w), 7 * math.sin(w)), hl=(.035 * math.cos(w), -.06, -.03 + .03 * math.cos(2 * w)),
                ch=(12, 0, -11 * math.sin(w)), hd=(-22, 0, 3 * math.sin(w)), jw=(4 + 5 * max(0, flap), 0, 0), cl=(30 + 12 * flap, 0, 0),
                L=(.05 * 0, ly, lz), R=(-.05 * 0, ry - .16, rz), Lp=(lk * -34, 0, 0), Rp=(rk * -34, 0, 0),
                Al=(-.12, .62 + .04 * math.sin(w), .02 + .03 * math.cos(w)), Bl=(.12, .62 - .04 * math.sin(w), .02 - .03 * math.cos(w)),
                Ar=aimL((.42, .88, .16)), Br=aimR((-.42, .88, .16)),
                tl=(5 + 7 * math.sin(w * 2 + 1), 0, -9 + 7 * math.sin(w)), tr=(5 + 7 * math.sin(w * 2 + 2), 0, 9 + 7 * math.sin(w + 1)))
act('Running_C', 12, {f: sprint(f / 12) for f in range(13)})

# dodge: a springy hop back with a twist, knees tucked, daggers flung wide, lands in the crouch. The game moves him; the
# clip adds the arc. In place (no root travel) so it does not fight velocity. 15 frames at speed 1.8 fills the 0.35 s state
UP = dict(hr=(-32, 8, -18), hl=(0, .16, .34), ch=(-16, 0, 14), hd=(0, 0, -8), jw=(14, 0, 0), L=(.03, .1, .36), R=(-.03, -.08, .42), Lp=(-44, 0, 0), Rp=(-34, 0, 0),
          Al=(.34, .34, .32), Bl=(-.34, .28, .28), Ar=(0, 0, -30), Br=(0, 0, 30), tl=(-20, 0, 7), tr=(-24, 0, -7), cl=(-30, 0, 0))
LOAD = dict(hr=(16, 0, 4), hl=(0, -.03, -.13), ch=(12, 0, -5), hd=(-24, 0, 4), jw=(3, 0, 0), Al=(-.06, -.02, -.08), Bl=(.06, -.02, -.08), tl=(10, 0, 0), tr=(10, 0, 0))
LAND = dict(hr=(16, -3, 6), hl=(0, .06, -.17), ch=(12, 0, -4), hd=(-22, 0, 3), jw=(8, 0, 0), L=(0, .02, 0), R=(0, .02, 0), Al=(.13, -.04, -.14), Bl=(-.13, -.04, -.14), tl=(14, 0, 2), tr=(14, 0, -2), cl=(24, 0, 0))
act('Dodge_Backward', 15, {0: IDLE_A, (2, 'out'): LOAD, (6, 'out'): UP, (11, 'in'): LAND, 15: IDLE_A})

# chop: quick scissor. Both blades cross high over the skull, then snap down and through. Hit on frame 11 of 24
WIND = dict(hr=(-8, 0, 4), hl=(0, .13, -.02), ch=(-14, 0, 0), hd=(-24, 0, 0), jw=(16, 0, 0), L=(0, .02, 0), Lp=(-8, 0, 0),
            Al=(-.34, .1, .66), Bl=(.34, .14, .58), Ar=aimL((-.38, .12, 1)), Br=aimR((.38, .12, 1)), tl=(-6, 0, 2), tr=(-6, 0, -2), cl=(-6, 0, 0))
STAB = dict(hr=(28, 0, -6), hl=(0, -.42, -.15), ch=(14, 0, 8), hd=(-16, 0, -5), jw=(24, 0, 0), L=(0, -.52, 0), R=(0, -.08, 0), Rp=(18, 0, 0),
            Al=(-.07, -.46, -.26), Bl=(.09, -.42, -.2), Ar=aimL((-.22, -.92, -.32)), Br=aimR((.22, -.92, -.32)), tl=(12, 0, 5), tr=(12, 0, -5), cl=(34, 0, 0))
act('1H_Melee_Attack_Chop', 24, {0: IDLE_A, (8, 'out'): WIND, (11, 'in'): STAB, 15: PP(STAB, hl=(0, -.4, -.13), jw=(18, 0, 0)), 24: IDLE_A})

# hurt: light frame, big snap
HA = dict(hr=(-20, 0, 12), hl=(0, .14, .02), ch=(-18, 0, 12), hd=(4, 10, -24), jw=(28, 0, 0), Al=(.14, .1, .2), Bl=(-.05, .18, .1), Ar=(-22, 0, 0), Br=(-20, 0, 0), tl=(10, 0, 7), tr=(10, 0, 7), cl=(18, 0, 0), R=(0, .1, 0))
HB = dict(hr=(-14, -8, -14), hl=(.05, .12, 0), ch=(-14, -5, -12), hd=(-2, -14, 26), jw=(22, 0, 0), Al=(.05, .18, .08), Bl=(-.14, .1, .22), Ar=(-18, 0, 0), Br=(-24, 0, 0), tl=(10, 0, -7), tr=(10, 0, -7), cl=(16, 0, 0), L=(0, .1, 0))
act('Hit_A', 14, {0: IDLE_A, (2, 'hold'): HA, 14: IDLE_A})
act('Hit_B', 14, {0: IDLE_A, (2, 'hold'): HB, 14: IDLE_A})

# death: head snaps back, knees go, folds forward over his own legs. Daggers skitter out, tails settle last
D1 = dict(hr=(-14, 0, 8), hl=(0, .1, 0), ch=(-14, 0, 9), hd=(4, 10, -22), jw=(30, 0, 0), Al=(.14, .1, .2), Bl=(-.14, .14, .18), Ar=(-26, 0, 0), Br=(-30, 0, 0), tl=(-10, 0, 5), tr=(-10, 0, 5))
D2 = dict(hr=(22, 0, 8), hl=(0, -.02, -.28), ch=(12, 0, 8), hd=(30, 14, -14), jw=(38, 0, 0), Al=(.14, -.1, -.5), Bl=(-.14, -.1, -.5), Ar=(30, 30, 0), Br=(30, -30, 0), tl=(8, 0, 3), tr=(8, 0, -3),
          L=(0, .22, 0), R=(0, .0, 0), Lp=(-30, 0, 0), Rp=(-30, 0, 0))
D3 = PP(D2, hr=(30, 0, 12), hl=(.02, -.08, -.33), ch=(6, 0, 8), hd=(34, 24, -18), jw=(44, 0, 0), Al=(.22, -.38, -.52), Bl=(-.22, -.34, -.52), Ar=(0, 90, 40), Br=(0, -90, -40), tl=(30, 0, 8), tr=(32, 0, -6),
        L=(.02, .3, 0), R=(-.02, .12, 0), Lp=(-58, 0, 0), Rp=(-60, 0, 0), cl=(-40, 0, 0))
act('Death_A', 30, {0: IDLE_A, (3, 'hold'): D1, (10, 'smooth'): PP(D1, hl=(0, .12, -.04)), (18, 'in'): D2, (25, 'in'): D3, 30: D3})

# juggled and dropped: flat on his back, kips straight up into the crouch. The game plays this at double speed
LB = dict(hr=(-112, 0, 4), hl=(0, .08, -.42), ch=(-8, 0, 2), hd=(-96, 0, 6), jw=(18, 0, 0), Al=(.2, .36, -.56), Bl=(-.2, .4, -.52), Ar=(0, 80, 0), Br=(0, -80, 0),
          L=(.06, -.32, 0), R=(-.04, -.4, 0), Lp=(-40, 0, 0), Rp=(-40, 0, 0), Lk=(.6, -.1, .8), Rk=(-.6, -.1, .8), tl=(10, 0, 3), tr=(10, 0, -3), cl=(30, 0, 0))
KIP = dict(hr=(-30, 0, 0), hl=(0, .05, .1), ch=(-10, 0, 0), hd=(-20, 0, 0), jw=(10, 0, 0), Al=(.1, .1, .05), Bl=(-.1, .1, .05), L=(0, -.1, .22), R=(0, -.14, .22), Lp=(-20, 0, 0), Rp=(-20, 0, 0), tl=(-20, 0, 3), tr=(-20, 0, -3))
act('Lie_StandUp', 22, {0: LB, (7, 'in'): KIP, (13, 'out'): PP(LAND, hl=(0, .03, -.12)), 22: IDLE_A})

# spawn: a dagger stabs up out of the floor, then the other, and he pulls himself out low and fast
DN = -1.2
S0 = dict(hr=(10, 0, 0), hl=(0, 0, DN), ch=(8, 0, 0), hd=(0, 0, 0), L=(0, 0, DN), R=(0, 0, DN), Al=(-.05, -.02, DN + .3), Bl=(.05, 0, DN - .1), Ar=(-48, 0, 0), Br=(-48, 0, 0), jw=(5, 0, 0))
S1 = PP(S0, Al=(-.14, .04, -.08), Ar=(-62, 0, 0), Bl=(.05, 0, DN + .34))
S2 = PP(S0, hl=(0, 0, -.5), L=(0, 0, -.5), R=(0, 0, -.5), Al=(-.1, .14, .02), Bl=(.12, .14, -.06), Ar=(-50, 0, 0), Br=(-52, 0, 0), hd=(-14, 0, 0), jw=(22, 0, 0))
S3 = PP(UP, hl=(0, 0, .22), L=(0, 0, .2), R=(0, 0, .22), hr=(-14, 0, 0), ch=(-8, 0, 0), hd=(-20, 0, 0), Al=(.3, .1, .28), Bl=(-.3, .1, .28), Ar=(0, 0, -14), Br=(0, 0, 14), tl=(14, 0, 3), tr=(14, 0, -3))
S4 = PP(LAND, hd=(-22, 0, 0), hr=(10, 0, 0))
act('Spawn_Ground_Skeletons', 30, {0: S0, (7, 'out'): S1, (15, 'smooth'): S2, (20, 'out'): S3, (24, 'in'): S4, 30: IDLE_A})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

CLIPS = (('Idle_Combat', 32), ('Running_C', 12), ('Dodge_Backward', 15), ('1H_Melee_Attack_Chop', 24), ('Hit_A', 14), ('Hit_B', 14), ('Death_A', 30), ('Lie_StandUp', 22), ('Spawn_Ground_Skeletons', 30))
for nm, ln in CLIPS:
    zs = {'foot.l': [], 'foot.r': []}
    for f in range(ln + 1):
        R.play(nm, f)
        for n in zs: zs[n].append(R.obj.pose.bones[n].head.z)
    print('  feet %-24s L z %.3f..%.3f  R z %.3f..%.3f' % (nm, min(zs['foot.l']), max(zs['foot.l']), min(zs['foot.r']), max(zs['foot.r'])))

R.play('Death_A', 30); print('  death: head bone z %.3f chest z %.3f hips z %.3f' % tuple(R.obj.pose.bones[n].head.z for n in ('head', 'chest', 'hips')))
# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.2, -6.2, 1.2), (0, -.3, .7), lens=58)
game = C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .75), ortho=3.6)
side = C.camera('CamSide', (-5.4, -1.6, 1.2), (0, -.15, .7), lens=58)
sheet = C.camera('CamSheet', (-2.7, -4.3, 2.7), (-.05, -.1, .62), lens=36)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
FR = [('Idle_Combat', 8), ('Running_C', 0), ('Running_C', 3), ('Running_C', 6), ('Dodge_Backward', 2), ('Dodge_Backward', 6),
      ('Dodge_Backward', 11), ('1H_Melee_Attack_Chop', 8), ('1H_Melee_Attack_Chop', 11), ('1H_Melee_Attack_Chop', 15), ('Hit_A', 2), ('Hit_B', 2),
      ('Death_A', 8), ('Death_A', 18), ('Death_A', 30), ('Lie_StandUp', 0), ('Spawn_Ground_Skeletons', 7), ('Spawn_Ground_Skeletons', 20)]
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
R.play('Idle_Combat', 0)
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME, 'tris', C.tris())
