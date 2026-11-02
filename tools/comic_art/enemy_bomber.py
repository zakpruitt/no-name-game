# Bomber, comic style. A tiny delighted skeleton sprinting under a round black bomb bigger than he is.
#   blender -b -P enemy_bomber.py
# Front -Y, its left +X, up +Z. Stance poses go through plant(): a small leg IK that keeps the ankles where they belong.
import bpy, sys, os, math, random
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Euler, Matrix, Quaternion as Q
NAME = 'bomber'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['bomb'] = C.toon('P_Bomb', (.02, .02, .05), (.065, .065, .115), (.14, .145, .23), (.34, .37, .52), rim=(.75, .24, .05), brush=.12, inner=.12)
M['hot'] = C.emit('P_Hot', (1, .72, .12), (1, 1, .78))
C.rng.seed(7)
B = {k: C.Bag(m) for k, m in (('bone', 'bone'), ('socket', 'socket'), ('teeth', 'teeth'), ('necro', 'necro'), ('leather', 'leather'), ('strap', 'leather'),
                              ('cloth', 'cloth'), ('bomb', 'bomb'), ('iron', 'iron'), ('bronze', 'bronze'), ('ink', 'black'), ('shine', 'eye_white'),
                              ('lava', 'lava'), ('hot', 'hot'), ('fuse', 'leather'), ('fire', 'fire'))}
b = B['bone']

# rigid parts are tagged per bone as they are built, so one mesh per material can still follow many bones
TAGS = {k: [] for k in B}; _done = {k: 0 for k in B}
def tag(bone):
    for k, bag in B.items():
        n = len(bag.v)
        if n > _done[k]:
            TAGS[k].append((_done[k], n, bone)); _done[k] = n

# ---- skeleton joints: tiny, pitched forward, head thrust out and tipped up so the grin faces the game camera
hip = V((0, -.2, .44)); chest = V((0, -.2, .68)); neck = V((0, -.32, .86)); H = V((0, -.5, 1.05))
shL, elL, wrL, hdL = V((.2, -.22, .76)), V((.44, -.1, .84)), V((.66, .04, 1.04)), V((.72, .08, 1.14))   # left arm flung high
shR, elR, wrR, hdR = V((-.2, -.22, .76)), V((-.43, -.08, .62)), V((-.64, .08, .5)), V((-.73, .13, .44))  # right arm flung low
hpL, knL, anL = V((.1, -.2, .42)), V((.21, -.45, .28)), V((.2, -.38, .1))                               # left foot forward
hpR, knR, anR = V((-.1, -.2, .42)), V((-.21, -.2, .28)), V((-.2, -.03, .1))
HP, KN, AN = {'l': hpL, 'r': hpR}, {'l': knL, 'r': knR}, {'l': anL, 'r': anR}

# ---- the bomb: the one oversized shape
BC = V((0, .5, .86)); BR = .62
def S(d, lift=0.0): return BC + V(d).normalized() * (BR + lift)
def frame(d):
    n = V(d).normalized(); u = n.cross(V((0, 0, 1)))
    if u.length < .01: u = V((1, 0, 0))
    u.normalize(); return n, u, u.cross(n)
def onball(d, u_, v_, lift=0.0):
    n, a, c = frame(d)
    return BC + (n * BR + a * u_ + c * v_).normalized() * (BR + lift)
def patch(bag, d, poly, lift=.008, t=.9):
    """A flat painted shape lying on the ball. poly is in metres on the surface, star-shaped around (0,0)."""
    vs = [onball(d, 0, 0, lift)] + [onball(d, u_, v_, lift) for u_, v_ in poly]
    m = len(poly)
    bag.add(vs, [(0, 1 + i, 1 + (i + 1) % m) for i in range(m)], [t] * len(vs))
def strip(bag, d, path, lift=.008, wide=1.0, grow=0.0, t=.9):
    """A jagged crack line on the ball: path is (u, v, half width) in metres."""
    vs, fs = [], []
    for i, (u_, v_, w) in enumerate(path):
        p0 = path[max(i - 1, 0)]; p1 = path[min(i + 1, len(path) - 1)]
        du, dv = p1[0] - p0[0], p1[1] - p0[1]; L = math.hypot(du, dv) or 1
        nx, ny = -dv / L, du / L; w = w * wide + grow
        vs += [onball(d, u_ + nx * w, v_ + ny * w, lift), onball(d, u_ - nx * w, v_ - ny * w, lift)]
        if i: fs.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
    bag.add(vs, fs, [t] * len(vs))

C.blob(B['bomb'], BC, (BR, BR, BR), seg=26, rings=16)
SHINE = V((-.62, -.38, .68)); CRACK = V((.42, -.52, .74))
strip(B['shine'], SHINE, [(.21, -.17, .008), (.18, -.05, .036), (.11, .07, .056), (-.01, .15, .042), (-.15, .19, .008)])
patch(B['shine'], SHINE, [(-.235 + .036 * math.cos(i * .9), .205 + .03 * math.sin(i * .9)) for i in range(7)])
# the crack: ink wedge, ember line, and the hot core waiting under the surface (see the 'flash' bone)
CR_MAIN = [(u_ * 1.25, v_ * 1.25, w * 1.25) for u_, v_, w in [(-.27, .26, .004), (-.17, .2, .018), (-.13, .1, .03), (-.03, .07, .05), (.0, -.03, .056), (.11, -.06, .04), (.09, -.16, .026), (.19, -.22, .012), (.21, -.33, .002)]]
CR_A = [(u_ * 1.25, v_ * 1.25, w * 1.25) for u_, v_, w in [(-.03, .07, .024), (.07, .15, .018), (.15, .13, .01), (.22, .22, .001)]]
CR_B = [(u_ * 1.25, v_ * 1.25, w * 1.25) for u_, v_, w in [(.0, -.03, .024), (-.1, -.09, .018), (-.11, -.19, .009), (-.2, -.25, .001)]]
for path in (CR_MAIN, CR_A, CR_B):
    strip(B['ink'], CRACK, path, lift=.006, grow=.013)
    strip(B['lava'], CRACK, path, lift=.01, wide=.8, t=.55)
tag('bomb')
for path in (CR_MAIN, CR_A, CR_B):
    strip(B['hot'], CRACK, path, lift=-.03, wide=1.5, grow=.012, t=.9)
for i in range(9):   # rays burst out of the crack when it flashes
    a = i * .698 + .2; L = .2 + .12 * (i % 3)
    u0, v0 = .12 * math.cos(a), .12 * math.sin(a); u1, v1 = (.12 + L) * math.cos(a), (.12 + L) * math.sin(a)
    strip(B['hot'], CRACK, [(u0, v0, .002), ((u0 + u1) / 2, (v0 + v1) / 2, .018), (u1, v1, .001)], lift=-.03, t=.5)
tag('flash')
# hardware: bronze collar on top, leather belt with rivets
CAP = V((.34, .14, .93)).normalized()
capR = CAP.to_track_quat('Z', 'Y').to_euler()
C.blob(B['bronze'], BC + CAP * (BR + .015), (.17, .17, .05), seg=14, rings=6, rot=capR, p=2.6)
C.blob(B['iron'], BC + CAP * (BR + .06), (.09, .09, .05), seg=10, rings=5, rot=capR, p=2.6)
C.tube(B['leather'], [S((math.cos(i * .524), math.sin(i * .524), -.3), .012) for i in range(13)], [(.018, .06), (.018, .06)], sides=6, sub=1)
for i in range(12):
    if i in (4, 5): continue
    C.blob(B['iron'], S((math.cos(i * .524 + .26), math.sin(i * .524 + .26), -.3), .022), (.02, .02, .016), seg=6, rings=4)
tag('bomb')
C.blob(B['bronze'], S((-.13, -.12, .98), .03), (.085, .1, .03), seg=8, rings=4, rot=V((-.12, -.13, 1)).normalized().to_track_quat('Z', 'Y').to_euler(), p=3.5)   # buckle
tag('bomb')
# a yoke off both shoulders into one wide strap over the top: says "strapped on" and leaves the ball's face clean
for sx in (-1, 1):
    sh = shL if sx > 0 else shR
    C.tube(B['strap'], [sh + V((-sx * .02, .03, .045)), sh + V((-sx * .04, .1, .1)), S((sx * .1 - .03, -.86, .5), .014)], [(.04, .012), (.04, .012)], sides=6, sub=3, side=V((1, 0, 0)))
C.tube(B['strap'], [S((-.03, -.86, .5), .012), S((-.09, -.45, .9), .014), S((-.14, .15, .98), .014), S((-.12, .7, .7), .014), S((-.08, .97, .05), .012)], [(.06, .012), (.066, .012)], sides=6, sub=3, side=V((1, 0, 0)))

# ---- fuse: S-curl off to its left, tip above everything so the spark reads from the top
F0 = BC + CAP * (BR + .1)
FM = F0 + V((.02, -.02, .2)); FT = F0 + V((.25, -.1, .47))
C.tube(B['fuse'], [F0, F0 + V((-.02, 0, .1)), FM, F0 + V((.13, -.05, .28)), F0 + V((.24, -.08, .34)), FT], [.036, .032, .026], sides=6, sub=2)
C.tube(B['ink'], [F0 + V((.24, -.08, .34)), FT], [.03, .03], sides=6, sub=1)
tag('fuse.2')

# ---- spark: cut-tone star plus flung chips, all on one bone that spins for flicker
rs = random.Random(11)
for i in range(11):
    a = i * 2 * math.pi / 11; e = (i * 2.39) % 3.14 - 1.57
    d = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e) + .25)).normalized()
    L = .16 + .15 * (i % 3) / 2
    C.tube(B['fire'], [FT, FT + d * L * .35, FT + d * L], [.058, .036, .002], sides=4, sub=1)
C.blob(B['shine'], FT, (.05, .05, .05), seg=6, rings=4)
for i in range(11):
    a = rs.uniform(0, 6.28); up = rs.uniform(-.2, 1); r_ = rs.uniform(.28, .5)
    p = FT + V((math.cos(a) * r_, math.sin(a) * r_, up * r_)); s_ = rs.uniform(.014, .03)
    C.blob(B['fire'], p, (s_, s_, s_ * 1.4), seg=4, rings=2, t=rs.choice((.1, .55, .9)))
tag('spark')

# ---- skull: huge, built upright around H then tipped back so the face looks up at the camera
TILT = Euler((math.radians(-24), 0, 0)).to_matrix(); HSC = .92
_mark = {k: len(bag.v) for k, bag in B.items()}
tag('chest')
def hp(x, y, z): return H + V((x, y, z))
C.blob(b, hp(0, .03, .07), (.3, .31, .26), seg=16, rings=10)                      # dome
C.blob(b, hp(0, -.15, -.06), (.215, .15, .14), seg=14, rings=8)                   # face plate
for sx in (-1, 1):
    C.blob(b, hp(sx * .2, -.15, -.05), (.085, .075, .065), seg=8, rings=5)        # cheek apples: pushed up by the grin
    # brows arched high: delight, the opposite of the minion's snarl
    rise = .025 if sx > 0 else 0
    C.tube(b, [hp(sx * .055, -.285, .185 + rise), hp(sx * .135, -.275, .225 + rise), hp(sx * .235, -.2, .155 + rise)], [.014, .034, .012], sides=6, sub=2)
# sockets: mismatched, wide open, pinprick eyes pointing slightly different ways
C.blob(B['socket'], hp(.125, -.272, .045), (.098, .05, .112), seg=10, rings=7)
C.blob(B['socket'], hp(-.122, -.272, .03), (.082, .05, .088), seg=10, rings=7)
C.blob(B['necro'], hp(.112, -.325, .03), (.04, .012, .042), seg=8, rings=5, t=.9)
C.blob(B['necro'], hp(-.105, -.316, .045), (.03, .012, .032), seg=8, rings=5, t=.9)
C.blob(B['socket'], hp(0, -.302, -.042), (.036, .018, .036), seg=7, rings=5)      # nose hole
# grin: a black smile running cheek to cheek with a fence of square teeth in it
def smile(k, drop=0.0):
    """k in -1..1 across the mouth: the corners ride high."""
    return hp(k * .235, -.3 + .13 * k * k, -.17 + .1 * k * k + drop)
C.tube(B['socket'], [smile(i / 4, -.025) for i in range(-4, 5)], [(.03, .04), (.05, .05), (.03, .04)], sides=6, sub=1, side=V((0, -1, 0)))
for i in range(-4, 5):
    k = i / 4.4
    C.blob(B['teeth'], smile(k) + V((0, -.012, .012)), (.024, .018, .031), seg=6, rings=4, p=3.2)
# the crack: a wedge out of the dome, with a chip gone from its top
C.tube(B['socket'], [hp(.02, -.16, .29), hp(.07, -.19, .265), hp(.02, -.25, .235), hp(.03, -.285, .16)], [.03, .018, .012, .002], sides=5, sub=1, side=V((1, 0, 0)))
C.tube(B['socket'], [hp(.07, -.19, .265), hp(.17, -.13, .27), hp(.235, -.09, .22)], [.012, .008, .001], sides=5, sub=1)
C.tube(B['socket'], [hp(.02, -.16, .29), hp(-.05, -.12, .315), hp(-.09, -.1, .315)], [.016, .008, .001], sides=5, sub=1)
tag('head')
# jaw: a separate grinning horseshoe that chatters
J0 = hp(0, -.2, -.19)
C.tube(b, [hp(-.23, -.1, -.1), hp(-.17, -.2, -.22), hp(0, -.27, -.27), hp(.17, -.2, -.22), hp(.23, -.1, -.1)], [.034, .046, .056, .046, .034], sides=6, sub=2)
for i in range(-3, 4):
    k = i / 3.8
    C.blob(B['teeth'], smile(k * .86, -.062 + .012 * abs(k)) + V((0, .004, 0)), (.024, .017, .024), seg=6, rings=4, p=3.2)
tag('jaw')
for k, bag in B.items():
    for i in range(_mark[k], len(bag.v)):
        bag.v[i] = H + TILT @ (bag.v[i] - H) * HSC
J_PIV = H + TILT @ V((0, -.02, -.08)) * HSC; J_TIP = H + TILT @ V((0, -.3, -.27)) * HSC

# ---- spine and cage: small
vb = [hip.lerp(chest, i / 4) + V((0, .055, 0)) for i in range(5)]
for p in vb[:3]:
    C.blob(b, p, (.046, .046, .032), seg=8, rings=5)
tag('spine')
for p in vb[3:]:
    C.blob(b, p, (.046, .046, .032), seg=8, rings=5)
C.tube(b, [chest + V((0, .05, 0)), neck, H + V((0, .1, -.16))], [.042, .036, .036], sides=6, sub=2)
for i in range(3):
    z = chest.z + .07 - i * .075; w = .165 - i * .014; y0 = chest.y + .05
    for sx in (-1, 1):
        C.tube(b, [V((sx * .01, y0, z + .02)), V((sx * w * .85, y0 + .015, z)), V((sx * w, y0 - .11, z - .03)), V((sx * w * .5, y0 - .2, z - .05)), V((sx * .02, y0 - .22, z - .04))], [.019, .023, .022, .02, .015], sides=5, sub=2)
C.tube(b, [V((0, chest.y - .175, chest.z + .08)), V((0, chest.y - .17, chest.z - .12))], [.028, .018], sides=5, sub=1)
C.tube(b, [shL, V((0, -.28, .8)), shR], [.026, .02, .026], sides=6, sub=2)
tag('chest')
C.blob(b, hip + V((0, 0, -.02)), (.15, .11, .075), seg=10, rings=6, p=2.3)
tag('hips')

# ---- limbs: thin shafts, knobby joints, hands and feet too big
def limb(a, c, bone, r=.03, k=.05, knob_a=True):
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    if knob_a: C.blob(b, a, (k, k, k), seg=8, rings=5)
    tag(bone)
def hand(w, d, side, bone):
    C.blob(b, w + d * .05, (.058, .05, .05), seg=8, rings=5)
    C.blob(b, w, (.042, .042, .042), seg=8, rings=5)
    up = d.cross(side).normalized()
    for i, sp in enumerate((-1.25, -.4, .45, 1.3)):
        o = side * sp * .05 + up * (.02 - abs(sp) * .012)
        C.tube(b, [w + d * .07 + o * .6, w + d * .16 + o * 1.1, w + d * .25 + o * 1.8 - up * .02], [.022, .017, .004], sides=5, sub=1)
    tag(bone)
limb(shL, elL, 'upperarm.l'); limb(elL, wrL, 'lowerarm.l', .026, .044)
limb(shR, elR, 'upperarm.r'); limb(elR, wrR, 'lowerarm.r', .026, .044)
hand(wrL, (hdL - wrL).normalized(), V((.6, -.7, -.2)).normalized(), 'hand.l')
hand(wrR, (hdR - wrR).normalized(), V((.35, -.8, -.45)).normalized(), 'hand.r')
limb(hpL, knL, 'upperleg.l', .036, .058); limb(knL, anL, 'lowerleg.l', .03, .056)
limb(hpR, knR, 'upperleg.r', .036, .058); limb(knR, anR, 'lowerleg.r', .03, .056)
def foot(an, bone):
    C.blob(b, an, (.045, .045, .045), seg=8, rings=5)
    C.blob(b, an + V((0, -.08, -.058)), (.09, .15, .042), seg=9, rings=5)
    for i in range(3):
        o = V(((i - 1) * .05, -.235, -.08))
        C.tube(b, [an + V((o.x * .7, -.15, -.06)), an + o], [.024, .01], sides=5, sub=1)
    tag(bone)
foot(anL, 'foot.l'); foot(anR, 'foot.r')

# ---- loincloth and harness: the one bit of family colour
for i in range(5):
    a = -2.5 + i * .46
    o = V((math.cos(a), math.sin(a) * .8, 0))
    q = hip + V((o.x * .13, o.y * .1 - .02, -.02))
    L = .15 + .05 * (i % 2)
    C.tube(B['cloth'], [q, q + o * .03 - V((0, 0, L * .5)), q + o * .05 - V((0, 0, L))], [(.042, .006), (.046, .007), (.002, .002)], sides=5, sub=2, side=o.cross(V((0, 0, 1))))
C.tube(B['strap'], [shL + V((-.02, -.03, .03)), chest + V((0, -.2, -.02)), chest + V((-.1, -.12, -.17))], [(.034, .009), (.034, .009)], sides=5, sub=2, side=V((1, 0, 0)))
C.tube(B['strap'], [shR + V((.02, -.03, .03)), chest + V((0, -.21, .0)), chest + V((.1, -.12, -.17))], [(.034, .009), (.034, .009)], sides=5, sub=2, side=V((1, 0, 0)))

col = scn.collection
objs = {}
for k, bag in B.items():
    if not bag.v: continue
    outline = 0 if k in ('socket', 'necro', 'teeth', 'ink', 'shine', 'lava', 'hot') else (.012 if k == 'bomb' else .006)
    objs[k], t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()))

# ------------------------------------------------------------------ rig
FLASH_DIR = CRACK.normalized()
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, 0, .1)), 'root'),
    'spine': (hip + V((0, 0, .1)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .1, -.22)), H + V((0, -.02, .25)), 'chest'),
    'jaw': (J_PIV, J_TIP, 'head'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.2, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.2, -.08)), 'lowerleg.r'),
    'cloth': (hip + V((0, -.08, -.02)), hip + V((0, -.1, -.2)), 'hips'),
    'bomb': (V((0, -.06, .72)), BC, 'chest'),
    'flash': (BC + FLASH_DIR * .3, BC + FLASH_DIR * .5, 'bomb'),
    'fuse.1': (F0, FM, 'bomb'), 'fuse.2': (FM, FT, 'fuse.1'),
    'spark': (FT, FT + V((0, 0, .15)), 'fuse.2'),
}
R = CR.Rig('BomberRig', bones)
def rigid(key):
    o = objs[key]; groups = {}
    for a, c, bone in TAGS[key]:
        for i in range(a, c): R._put(o, groups, i, [(1, bone)])
    R._bind(o)
for k in ('bone', 'socket', 'teeth', 'necro', 'leather', 'bomb', 'iron', 'bronze', 'ink', 'shine', 'lava', 'hot', 'fire'):
    rigid(k)
R.skin_soft(objs['strap'], ('chest', 'bomb'), power=4)
R.skin_soft(objs['cloth'], ('hips', 'cloth'), power=3)
R.skin_soft(objs['fuse'], ('fuse.1', 'fuse.2'), power=4)
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ pose tools
def Qd(r): return Euler([math.radians(a) for a in r], 'XYZ').to_quaternion()
def Jt(h, r, loc=(0, 0, 0)): return Matrix.Translation(h + V(loc)) @ Qd(r).to_matrix().to_4x4() @ Matrix.Translation(-h)
def _solve(Dh, s, target):
    x = [0.0, 0.0, 0.0]
    def f(x_): return Dh @ Jt(HP[s], (x_[0], x_[1], 0)) @ Jt(KN[s], (x_[2], 0, 0)) @ AN[s]
    for _ in range(24):
        e = target - f(x)
        if e.length < 2e-4: break
        p0 = f(x); cols = []
        for i in range(3):
            y = list(x); y[i] += 1.0; cols.append(f(y) - p0)
        JJ = Matrix([[cols[i].dot(cols[j]) + (1e-6 if i == j else 0) for j in range(3)] for i in range(3)])
        g = V((cols[0].dot(e), cols[1].dot(e), cols[2].dot(e)))
        d = JJ.inverted() @ g
        x = [x[0] + max(-20, min(20, d[0])), x[1] + max(-20, min(20, d[1])), x[2] + max(-20, min(20, d[2]))]
        x[2] = max(-40, min(125, x[2]))
    return x
def plant(pose, l=(0, 0, 0), r=(0, 0, 0), pl=0.0, pr=0.0):
    """Returns pose + leg rotations that hold each ankle at rest + offset and each sole flat (or pitched: + is toe down)."""
    out = dict(pose)
    sp = pose.get('hips', (0, 0, 0))
    rot = sp['rot'] if isinstance(sp, dict) else sp; loc = sp.get('loc', (0, 0, 0)) if isinstance(sp, dict) else (0, 0, 0)
    Dh = Jt(hip, rot, loc); Qh = Qd(rot)
    for s, off, pitch in (('l', l, pl), ('r', r, pr)):
        x = _solve(Dh, s, AN[s] + V(off))
        u = (x[0], x[1], 0); w = (x[2], 0, 0)
        out['upperleg.' + s] = u; out['lowerleg.' + s] = w
        q = (Qh @ Qd(u) @ Qd(w)).inverted() @ Qd((pitch, 0, 0))
        out['foot.' + s] = tuple(math.degrees(a) for a in q.to_euler('XYZ'))
    return out
LOCS = ('hips', 'flash', 'spark')
def act(name, length, keys):
    """Kit workaround: an unkeyed channel keeps the previous action's value when actions switch, so every action
    names every bone and carries a location track on the bones that ever translate."""
    first = min(keys, key=lambda k: k[0] if isinstance(k, tuple) else k)
    p = keys[first]
    for n in R.names: p.setdefault(n, (0, 0, 0))
    for n in LOCS:
        s = p[n]
        if not isinstance(s, dict): s = {'rot': s}
        if V(s.get('loc', (0, 0, 0))).length < 1e-5: s = dict(s, loc=(0, 0, 2e-5))
        p[n] = s
    return R.action(name, length, keys)
def s_(x): return math.sin(x)
FLASH_ON = {'flash': {'rot': (0, 0, 0), 'loc': tuple(FLASH_DIR * .05)}}
def spin(i, step=45): return {'spark': {'rot': (0, 0, i * step), 'loc': (0, 0, 0)}}

# ------------------------------------------------------------------ animation (24 fps)
# idle: can't stand still, bouncing on his toes with the giggles; the bomb and fuse trail the beat
def idle(t, i):
    w = 2 * math.pi * t
    return plant({'hips': {'rot': (3 + 2 * s_(2 * w), 0, 2.5 * s_(w)), 'loc': (.018 * s_(w), 0, -.035 - .025 * s_(2 * w))},
                  'chest': (4 + 3 * s_(2 * w - .6), 0, -3 * s_(w)), 'spine': (2 + 2 * s_(2 * w - .3), 0, 0),
                  'head': (-2 - 5 * s_(2 * w - 1.2), 3 * s_(w - .4), 6 * s_(w - .8)), 'jaw': (11 + 9 * s_(4 * w), 0, 0),
                  'upperarm.l': (5 * s_(2 * w - .5), 7 * s_(2 * w - .9), 3), 'lowerarm.l': (0, 9 * s_(2 * w - 1.4), 0), 'hand.l': (0, 12 * s_(2 * w - 1.9), 0),
                  'upperarm.r': (5 * s_(2 * w - 1.1), -7 * s_(2 * w - 1.5), -3), 'lowerarm.r': (0, -9 * s_(2 * w - 2), 0), 'hand.r': (0, -12 * s_(2 * w - 2.5), 0),
                  'bomb': (-1 + 2.5 * s_(2 * w - 1.6), 2.5 * s_(w - 1.1), 0), 'fuse.1': (7 * s_(2 * w - 2.2), 9 * s_(w - 1.7), 0), 'fuse.2': (11 * s_(2 * w - 2.8), 14 * s_(w - 2.4), 0),
                  'cloth': (8 * s_(2 * w - 1), 0, 0), **spin(i)})
IDLE0 = idle(0, 0)
act('Idle_Combat', 32, {i * 2: idle(i / 16, i) for i in range(17)})

# run: a frantic scamper, legs a blur, arms streaming back, the bomb slamming up and down a beat late
def foot_path(p):
    """Ankle target relative to rest centre line. p in 0..1: on the ground to .42, then a high whipping recovery."""
    fr, bk = -.5, .08
    if p < .42:
        k = p / .42
        return fr + (bk - fr) * k, 0.0, 12 * k - 8
    k = (p - .42) / .58
    return bk + (fr - bk) * (k * k * (3 - 2 * k)), .3 * s_(math.pi * k) ** 1.2, 55 * (1 - k) ** 1.4 - 8
def run(t, i):
    w = 2 * math.pi * t
    pose = {'hips': {'rot': (17, 3 * s_(w), 7 * s_(w)), 'loc': (.02 * s_(w), -.03, -.05 + .055 * s_(2 * w - .9))},
            'spine': (3, 0, -5 * s_(w - .3)), 'chest': (5 + 3 * s_(2 * w - 1.3), 0, -11 * s_(w - .5)),
            'head': (-16 + 6 * s_(2 * w - 2), 6 * s_(w - 1), 12 * s_(w - 1.2)), 'jaw': (16 + 9 * s_(2 * w - 2.8), 0, 0),
            'upperarm.l': (-6 + 9 * s_(2 * w - 1.4), 10 * s_(2 * w - 1.1), 14), 'lowerarm.l': (0, 13 * s_(2 * w - 1.8), 8), 'hand.l': (0, 18 * s_(2 * w - 2.3), 0),
            'upperarm.r': (-6 + 9 * s_(2 * w - 1.9), -10 * s_(2 * w - 1.6), -14), 'lowerarm.r': (0, -13 * s_(2 * w - 2.3), -8), 'hand.r': (0, -18 * s_(2 * w - 2.8), 0),
            'bomb': (-13 + 6 * s_(2 * w - 2.4), 3.5 * s_(w - 1.5), 4 * s_(w - 1.8)), 'fuse.1': (-16 + 9 * s_(2 * w - 3), 10 * s_(w - 2), 0), 'fuse.2': (-26 + 14 * s_(2 * w - 3.6), 16 * s_(w - 2.6), 0),
            'cloth': (30 + 12 * s_(2 * w - 1.5), 0, 0), **spin(i, 60)}
    yl, zl, pl = foot_path(t % 1); yr, zr, pr = foot_path((t + .5) % 1)
    return plant(pose, l=(-.06, yl - AN['l'].y - .2 + .0, zl), r=(.06, yr - AN['r'].y - .2, zr), pl=pl, pr=pr)
act('Running_C', 12, {i: run(i / 12, i) for i in range(13)})

# windup: sinks, hugs himself, then rises trembling harder and harder into a huge arms-up ta-da; the crack pulses faster
rw = random.Random(3)
FLASHES = {10, 18, 24, 28, 30, 32, 33, 34, 35, 36}
def windup(f):
    k = f / 36; a = k ** 1.4
    j = lambda m: rw.uniform(-m, m) * a
    c = min(1, f / 8); c = c * c * (3 - 2 * c)                   # into the crouch
    u = max(0, (f - 8) / 28); u = u * u * (3 - 2 * u)            # out of it
    hz = -.03 - .13 * c + .19 * u
    pose = {'hips': {'rot': (3 + 8 * c - 16 * u + j(3), j(3), j(4)), 'loc': (j(.018), .03 * c - .05 * u + j(.01), hz + j(.012))},
            'spine': (2 * c - 6 * u, 0, j(3)), 'chest': (6 + 8 * c - 26 * u + j(4), j(3), j(6)),
            'head': (-2 + 10 * c - 30 * u + j(5), j(7), j(8)), 'jaw': (4 + 34 * u + j(8), 0, 0),
            'upperarm.l': (8 * c - 10 * u, 24 * c - 80 * u + j(10), 22 * c - 62 * u), 'lowerarm.l': (14 * c, 22 * c - 30 * u + j(10), 0), 'hand.l': (0, j(25), 0),
            'upperarm.r': (8 * c - 10 * u, -24 * c + 88 * u + j(10), -22 * c + 62 * u), 'lowerarm.r': (14 * c, -22 * c + 58 * u + j(10), 0), 'hand.r': (0, j(25), 0),
            'bomb': (2 - 10 * c + 22 * u + j(5), j(5), j(5)), 'fuse.1': (j(16), j(16), 0), 'fuse.2': (j(26), j(26), 0), 'cloth': (j(20), 0, 0), **spin(f // 2 * 3, 45)}
    if f in FLASHES: pose.update(FLASH_ON)
    return plant(pose, l=(j(.0), 0, 0), r=(0, 0, 0))
act('Bomb_Windup', 36, {f: windup(f) for f in range(0, 37, 1)})

# hit: snaps back, skull lags, bomb jolts and the crack spits; held, then a slow wobble home
HURT = plant({'hips': {'rot': (-17, 0, 9), 'loc': (0, .07, -.03)}, 'spine': (-6, 0, 3), 'chest': (-16, 0, 10), 'head': (30, 8, -16), 'jaw': (40, 0, 0),
              'upperarm.l': (-14, -30, 20), 'lowerarm.l': (0, -24, 0), 'upperarm.r': (-14, 34, -20), 'lowerarm.r': (0, 24, 0),
              'bomb': (10, 4, -5), 'fuse.1': (26, -14, 0), 'fuse.2': (38, -24, 0), 'cloth': (-22, 0, 0), **FLASH_ON, **spin(2)})
HURT2 = plant({'hips': {'rot': (-13, 0, 7), 'loc': (0, .05, -.05)}, 'spine': (-5, 0, 2), 'chest': (-12, 0, 8), 'head': (18, 5, -12), 'jaw': (34, 0, 0),
               'upperarm.l': (-10, -22, 16), 'upperarm.r': (-10, 26, -16), 'bomb': (-6, -3, 3), 'fuse.1': (-14, 10, 0), 'fuse.2': (-22, 18, 0), 'cloth': (-10, 0, 0), **FLASH_ON, **spin(4)})
OVER = plant({'hips': {'rot': (7, 0, -2), 'loc': (0, -.01, -.05)}, 'chest': (8, 0, -2), 'head': (-8, -2, 3), 'jaw': (14, 0, 0), 'bomb': (3, 1, 0), 'fuse.1': (8, -4, 0), 'fuse.2': (12, -6, 0), **spin(6)})
act('Hit_A', 18, {0: IDLE0, (2, 'hold'): HURT, (5, 'out'): HURT2, (11, 'smooth'): OVER, 18: idle(0, 8)})

# death: flung up and back with limbs everywhere, tumbles over, the bomb lands on him. A bounce, then he flops flat.
SPLAT = {'hips': {'rot': (60, 0, -10), 'loc': (0, .1, -.24)}, 'spine': (4, 0, 0), 'chest': (6, 0, 5), 'head': (-50, 26, -20), 'jaw': (26, 0, 0),
         'upperarm.l': (46, 30, 60), 'lowerarm.l': (10, 40, 0), 'hand.l': (0, 30, 0), 'upperarm.r': (38, -44, -40), 'lowerarm.r': (-20, -30, 0), 'hand.r': (0, -40, 0),
         'upperleg.l': (-40, 26, 0), 'lowerleg.l': (40, 0, 0), 'foot.l': (40, 0, 0), 'upperleg.r': (-30, -34, 0), 'lowerleg.r': (70, 0, 0), 'foot.r': (40, 0, 0),
         'bomb': (4, 0, 0), 'fuse.1': (30, 20, 0), 'fuse.2': (60, 40, 0), 'cloth': (-40, 0, 0), **spin(0)}
FLUNG1 = {'hips': {'rot': (-38, 0, 16), 'loc': (0, .15, .3)}, 'spine': (-10, 0, 6), 'chest': (-22, 0, 12), 'head': (36, 12, -20), 'jaw': (44, 0, 0),
          'upperarm.l': (30, -50, 50), 'lowerarm.l': (0, -30, 0), 'upperarm.r': (30, 54, -50), 'lowerarm.r': (0, 30, 0),
          'upperleg.l': (-55, 18, 0), 'lowerleg.l': (20, 0, 0), 'upperleg.r': (-30, -22, 0), 'lowerleg.r': (50, 0, 0), 'bomb': (12, 6, -6), 'fuse.1': (30, -14, 0), 'fuse.2': (50, -24, 0), **FLASH_ON, **spin(1)}
FLUNG2 = {'hips': {'rot': (-52, 20, 28), 'loc': (0, .15, .6)}, 'spine': (-6, 0, 6), 'chest': (-14, 0, 14), 'head': (18, 20, -26), 'jaw': (50, 0, 0),
          'upperarm.l': (-30, -70, 30), 'lowerarm.l': (0, -40, 0), 'upperarm.r': (-30, 70, -30), 'lowerarm.r': (0, 40, 0), 'hand.l': (0, -30, 0), 'hand.r': (0, 30, 0),
          'upperleg.l': (-70, 30, 0), 'lowerleg.l': (30, 0, 0), 'upperleg.r': (-20, -36, 0), 'lowerleg.r': (80, 0, 0), 'bomb': (-8, 8, -6), 'fuse.1': (-24, 20, 0), 'fuse.2': (-40, 30, 0), **spin(3)}
FALL = {'hips': {'rot': (30, 16, 10), 'loc': (0, -.05, .55)}, 'chest': (10, 0, 8), 'head': (-20, 14, -14), 'jaw': (46, 0, 0),
        'upperarm.l': (-60, -50, 20), 'upperarm.r': (-60, 50, -20), 'upperleg.l': (30, 20, 0), 'lowerleg.l': (40, 0, 0), 'upperleg.r': (50, -30, 0), 'lowerleg.r': (60, 0, 0), 'bomb': (-14, 0, 0), 'fuse.1': (-40, 10, 0), 'fuse.2': (-50, 10, 0), **spin(5)}
def mod(base, **kw):
    out = dict(base)
    for k, v in kw.items(): out[k.replace('__', '.')] = v
    return out
BOUNCE = mod(SPLAT, hips={'rot': (50, 0, -8), 'loc': (0, .08, -.08)}, chest=(4, 0, 4), bomb=(-4, 0, 0), head=(-20, 6, -8), jaw=(40, 0, 0), fuse__1=(-24, 10, 0), fuse__2=(-30, 20, 0), **spin(2))
LIMP = mod(SPLAT, jaw=(18, 0, 0), head=(-54, 30, -24), fuse__1=(40, 26, 0), fuse__2=(78, 48, 0), spark={'rot': (0, 0, 0), 'loc': (0, 0, 0)})
OUT_ = mod(LIMP, spark={'rot': (0, 0, 0), 'loc': (-.2, .0, -.5)})
act('Death_A', 48, {0: IDLE0, (3, 'hold'): FLUNG1, (11, 'out'): FLUNG2, (17, 'in'): FALL, (22, 'in'): SPLAT, (24, 'hold'): SPLAT, (28, 'out'): BOUNCE, (32, 'in'): LIMP, 40: LIMP, (41, 'hold'): OUT_, 48: OUT_})

# spawn: the lit fuse pops out of the floor first and looks around, then the whole lot bursts up and lands grinning
def hid(z, i): return {'hips': {'rot': (14, 0, 0), 'loc': (0, 0, z)}, 'upperleg.l': (-40, 0, 0), 'lowerleg.l': (70, 0, 0), 'upperleg.r': (-40, 0, 0), 'lowerleg.r': (70, 0, 0), 'fuse.1': (14 * ((-1) ** i), 12, 0), 'fuse.2': (20 * ((-1) ** i), -16, 0), **spin(i)}
POP = {'hips': {'rot': (-6, 0, 0), 'loc': (0, 0, .38)}, 'chest': (-10, 0, 0), 'head': (-14, 0, 0), 'jaw': (36, 0, 0), 'upperarm.l': (0, -60, 0), 'upperarm.r': (0, 60, 0), 'lowerarm.l': (0, -20, 0), 'lowerarm.r': (0, 20, 0),
       'upperleg.l': (20, 8, 0), 'lowerleg.l': (30, 0, 0), 'foot.l': (30, 0, 0), 'upperleg.r': (36, -8, 0), 'lowerleg.r': (36, 0, 0), 'foot.r': (30, 0, 0), 'bomb': (12, 0, 0), 'fuse.1': (24, -10, 0), 'fuse.2': (36, -16, 0), 'cloth': (40, 0, 0), **spin(4)}
LAND = plant({'hips': {'rot': (12, 0, 0), 'loc': (0, -.02, -.17)}, 'spine': (3, 0, 0), 'chest': (12, 0, 0), 'head': (-12, 0, 0), 'jaw': (6, 0, 0), 'upperarm.l': (0, 30, 18), 'upperarm.r': (0, -30, -18), 'bomb': (-16, 0, 0), 'fuse.1': (-28, 0, 0), 'fuse.2': (-38, 0, 0), **FLASH_ON, **spin(5)})
SETTLE = plant({'hips': {'rot': (0, 0, 0), 'loc': (0, 0, -.02)}, 'chest': (-3, 0, 0), 'head': (-4, 0, 0), 'jaw': (22, 0, 0), 'bomb': (5, 0, 0), 'fuse.1': (12, 0, 0), 'fuse.2': (16, 0, 0), **spin(6)})
act('Spawn_Ground_Skeletons', 36, {0: hid(-2.3, 0), (8, 'out'): hid(-1.72, 1), 11: hid(-1.78, 2), 14: hid(-1.7, 3), 17: hid(-1.76, 4), (22, 'out'): POP, (25, 'in'): mod(POP, hips={'rot': (10, 0, 0), 'loc': (0, 0, .02)}), (27, 'in'): LAND, (29, 'hold'): LAND, (33, 'out'): SETTLE, 36: IDLE0})

# launch recovery and the second flinch, which enemy.gd plays
R.action('Hit_B', 14, {0: IDLE0, (2, 'hold'): {'hips': {'rot': (12, 0, -8), 'loc': (0, -.06, -.02)}, 'chest': (20, 0, -14), 'head': (-22, 0, 18)}, 14: IDLE0})
_LIE = {'hips': {'rot': (-82, 0, 0), 'loc': (0, .15, -.6)}, 'chest': (-6, 0, 0), 'head': (10, 0, 0)}
_KNEEL = {'hips': {'rot': (-20, 0, 0), 'loc': (0, .05, -.3)}, 'chest': (30, 0, 0), 'head': (-10, 0, 0)}
R.action('Lie_StandUp', 32, {0: _LIE, (8, 'hold'): _LIE, (20, 'out'): _KNEEL, (32, 'in'): IDLE0})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ measure: do the feet really stay planted?
def foot_drift(action, length):
    R.obj.animation_data.action = bpy.data.actions[action]
    worst = {'l': 0.0, 'r': 0.0}; lo = 9.0
    for f in range(length + 1):
        scn.frame_set(f)
        for s in 'lr':
            pb = R.obj.pose.bones['foot.' + s]
            worst[s] = max(worst[s], (pb.head - AN[s]).length); lo = min(lo, pb.tail.z)
    print('  feet %-14s drift l %.3f r %.3f  lowest toe z %.3f' % (action, worst['l'], worst['r'], lo))
for a, n in (('Idle_Combat', 32), ('Bomb_Windup', 36), ('Hit_A', 18)):
    foot_drift(a, n)
R.play('Running_C', 0)
lowz = 9
for f in range(13):
    scn.frame_set(f)
    for s in 'lr':
        lowz = min(lowz, R.obj.pose.bones['foot.' + s].head.z)
print('  run lowest ankle z %.3f (rest .100)' % lowz)

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.5, -6.2, 1.6), (0, .15, 1.0), lens=58)
game = C.camera('CamGame', (0, -3.6, 5.5), (0, .1, .85), ortho=4.4)
side = C.camera('CamSide', (-5.8, -.1, 1.3), (0, .25, 1.0), lens=58)
sheet = C.camera('CamSheet', (-3.0, -4.3, 2.0), (0, .05, .95), lens=44)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
frames = [('Idle_Combat', 8), ('Running_C', 0), ('Running_C', 3), ('Running_C', 6), ('Running_C', 9),
          ('Bomb_Windup', 8), ('Bomb_Windup', 22), ('Bomb_Windup', 30), ('Bomb_Windup', 36), ('Hit_A', 3),
          ('Hit_A', 11), ('Death_A', 5), ('Death_A', 11), ('Death_A', 22), ('Death_A', 47),
          ('Spawn_Ground_Skeletons', 11), ('Spawn_Ground_Skeletons', 22), ('Spawn_Ground_Skeletons', 27), ('Spawn_Ground_Skeletons', 33), ('Idle_Combat', 24)]
# crop the sheet renders to the middle of the frame: the 16:9 sides are empty and the window-space halftone stays correct
r_ = scn.render; r_.use_border, r_.use_crop_to_border = True, True
r_.border_min_x, r_.border_max_x, r_.border_min_y, r_.border_max_y = .2, .8, 0, 1
CR.contact_sheet(R, frames, sheet, os.path.join(OUT, NAME + '_motion.png'), cols=5, tile_w=380)
if os.environ.get('BOMBER_DEBUG'):   # the same poses through the game camera, for checking the top-down read
    CR.contact_sheet(R, frames[:10] + frames[14:15], game, os.environ['BOMBER_DEBUG'], cols=6, tile_w=320)
r_.use_border = r_.use_crop_to_border = False
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME)
