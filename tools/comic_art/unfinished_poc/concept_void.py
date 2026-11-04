# Concept still, not rigged and not for export: one void arm that shapes itself into axe, hand, hammer and spear.
# The left arm is a normal arm with air rings round it. The elements live on the void arm, one per weapon, along its whole length.
#   blender -b --factory-startup -P concept_void.py   -> out/concept/void_*.png
import bpy, sys, os, math
D = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc"
OUT = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\unfinished_poc\out\concept"
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, D)
import build_tainted as T
C = T.C
from mathutils import Vector as V

def seg_dist(p, a, b):
    d = b - a
    t = max(0, min(1, (p - a).dot(d) / d.length_squared))
    return (p - (a + d * t)).length, t

_build = C.build
LARM = []
def build_body():
    B = _build()
    J = C.JOINTS
    sh, el, wr, hd, ms, H = J['sh'], J['el'], J['wr'], J['hd'], J['ms'], J['H']
    me_, mw, mf = J['me'], J['mw'], J['mf']
    def on_arm(p):
        d0, t0 = seg_dist(p, sh, el)
        if t0 > .28 and d0 < .2: return True
        if seg_dist(p, el, wr)[0] < .2: return True
        return seg_dist(p, wr, hd + (hd - wr).normalized() * .25)[0] < .24
    for k, b in B.items():
        if k == 'wind' or k.startswith(('bolt', 'fire')):
            b.v, b.f, b.t = [], [], []
        elif k in ('skin', 'bone', 'leather', 'bronze', 'iron', 'cloth'):
            b.f = [f for f in b.f if not all(on_arm(b.v[i]) for i in f)]
        if k in ('bronze', 'bone'):
            def bar(p): return .13 < abs(p.x) < .55 and 1.38 < p.z < 1.66 and p.y < -.1
            b.f = [f for f in b.f if not all(bar(b.v[i]) for i in f)]
        if k == 'rock':     # only the ear
            b.f = [f for f in b.f if all((b.v[i] - H).length < .3 for i in f)]
        elif k == 'lava':     # only the eye
            b.f = [f for f in b.f if all((b.v[i] - H).length < .3 for i in f)]
    # a normal arm in the skin bag, so it unions into the body: ordinary length, a slight bend, a loose fist
    la = ms + V((-.02, 0, -.01)); le = la + V((.13, -.01, -.37)); lw = le + V((.03, -.1, -.31)); lf = lw + V((.01, -.035, -.09))
    LARM[:] = [la, le, lw, lf]
    C.tube(B['skin'], [la, la.lerp(le, .5), le, le.lerp(lw, .35), lw, lf], [.105, .085, .066, .074, .05, .052], sides=12, sub=3)
    C.blob(B['skin'], la + V((.02, 0, 0)), (.12, .115, .11), seg=14, rings=10)
    C.blob(B['skin'], lf, (.066, .06, .075), seg=12, rings=8)
    for y in (-.042, -.014, .014, .042):
        C.tube(B['skin'], [lf + V((.045, y, -.03)), lf + V((.04, y - .012, -.075)), lf + V((-.005, y - .025, -.075))], [.02, .019, .017], sides=7, sub=2)
    C.tube(B['skin'], [lf + V((-.045, -.035, .02)), lf + V((-.035, -.07, -.025)), lf + V((.015, -.075, -.04))], [.023, .02, .017], sides=7, sub=2)
    dn = (lw - le).normalized()
    C.tube(B['leather'], [lw - dn * .07, lw - dn * .005], [.066, .06], sides=10, sub=1, tval=.5)
    return B
C.build = build_body
C.cracks = lambda nt, obj, col, *a, **k: col
_vein = T.vein
def vein(tree, pts, w, bones, **kw):
    if bones in (T.ARM_R, T.ARM_L, T.LEG_R): return     # purple belongs to the void arm and where it spreads from
    _vein(tree, pts, w, bones, **kw)
T.vein = vein
T.spark = lambda *a, **k: None
T.tongue = lambda *a, **k: None
_taint = T.taint
def taint(J):
    r = C.rock; C.rock = lambda *a, **k: None
    _taint(J)
    C.rock = r
T.taint = taint

cams, J = T.build_all()
scn = bpy.context.scene
col = scn.collection
C.toon('P_Tendril', (.1, .025, .22), (.34, .1, .6), (.62, .34, .92), rim=(.5, .2, .8), brush=.14)
mats_all = {m.name[2:].lower(): m for m in bpy.data.materials if m.name.startswith('P_') and m.name != 'P_Ink'}
mats_all['lava'] = bpy.data.materials['P_LavaDark']
mats_all['voidhard'] = C.toon('P_VoidHard', (.04, .012, .1), (.15, .05, .3), (.31, .15, .52), rim=(.5, .2, .8), brush=.14)

# ---- the left arm: three plain air rings round it, and that's all
ms, me_, mw, mf = J['ms'], J['me'], J['mw'], J['mf']
green = C.emit('P_StormGreen', (.02, .25, .16), (.86, 1, .72), mid=(.16, .85, .38))
mats_all['bolt'] = green
wind = C.Bag('wind')
la, le, lw, lf = [T.build_comic.warp(q) for q in LARM]
def ring(c, axis, r_, w, start, tilt):
    ax = V(axis).normalized()
    a0 = ax.cross(V((0, 1, 0))).normalized()
    ax2 = (ax + a0 * tilt).normalized()
    a0 = ax2.cross(V((0, 1, 0))).normalized(); a1 = ax2.cross(a0)
    n_ = 22; arc = 5.6
    pts = [c + (a0 * math.cos(start + arc * i / n_) + a1 * math.sin(start + arc * i / n_)) * r_ + ax2 * (.016 * i / n_) for i in range(n_ + 1)]
    rad = [max(w * math.sin(math.pi * min(1, (i + 1.5) / n_)) ** .6, .002) for i in range(n_ + 1)]
    C.tube(wind, pts, rad, sides=6, sub=1, tval=.5)
ring(la.lerp(le, .5), le - la, .155, .012, .4, .2)
ring(le.lerp(lw, .3), lw - le, .14, .011, 2.4, -.2)
ring(le.lerp(lw, .85), lw - le, .105, .009, 4.6, .22)
C.make_obj('left_rings', wind, mats_all, col, outline=.003)

# ---- where the arm leaves him: black roots at the shoulder, always there
sh = J['sh']
root = C.Bag('blight')
for i in range(9):
    a = i / 9 * 6.283
    q = sh + V((-.1 + .05 * math.cos(a), .155 * math.sin(a), .155 * math.cos(a)))
    C.tube(root, [q + V((.12, 0, 0)), q, q + V((-.13 - .05 * (i % 3), .03 * math.sin(a), .03 * math.cos(a)))], [.012, .03, .002], sides=5, sub=2, tval=.5)
C.make_obj('void_root', root, mats_all, col, outline=.004)

def wedge(bag, top, fw, dv, side, prof, th, size):
    n = len(prof); cx = sum(p[0] for p in prof) / n; cy = sum(p[1] for p in prof) / n
    P_ = lambda x, y, s_: top + fw * x * size + dv * y * size + side * s_
    k = .52
    inner = [(cx * .55 + (x - cx * .55) * k, cy + (y - cy) * k) for x, y in prof]
    vs = [P_(x, y, 0) for x, y in prof] + [P_(x, y, th) for x, y in inner] + [P_(x, y, -th) for x, y in inner]
    F = [tuple(range(n, 2 * n)), tuple(reversed(range(2 * n, 3 * n)))]
    for i in range(n):
        j = (i + 1) % n
        F.append((i, j, n + j, n + i)); F.append((j, i, 2 * n + i, 2 * n + j))
    bag.add(vs, F)

FORMS = {}
PATHS = {}
EXTRA = {'axe': [], 'hammer': [], 'spear': []}
def form(name, pts, rad):
    """A form's arm from the shoulder, plus bags for what it ends in."""
    arm = C.Bag('tendril')
    P = [sh + V(p) for p in pts]
    C.tube(arm, P, rad, sides=11, sub=4, tval=.5)
    path = C.catmull(P, 5)
    glow = C.Bag('fracture')
    n = len(path); rmax = rad[0]
    PATHS[name] = (path, rad)
    for i in range(6, n - 4, 4) if name == 'hand' else ():        # a few lit marks down one side, no more
        p = path[i]; d_ = (path[i + 1] - p).normalized(); out = d_.cross(V((0, 0, 1))).normalized()
        r_ = rmax * (1 - .55 * i / n)
        C.blob(glow, p + out * r_ * .8, (r_ * .2,) * 3, seg=8, rings=5, t=1.0)
    hard = C.Bag('voidhard', smooth=False)
    FORMS[name] = (arm, glow, hard)
    return P[-1], glow, hard, arm

# axe: the default. The arm runs down into its own haft and the head drags on the floor beside and behind him.
end, glow, hard, arm = form('axe', [(.02, 0, -.02), (-.2, -.05, -.1), (-.43, -.02, -.42), (-.62, .14, -.74), (-.86, .4, -1.0), (-1.1, .66, -1.16)], [.14, .118, .094, .078, .07, .082])
dv = V((-.68, .7, -.2)).normalized(); fw = V((-.72, -.56, -.3)); fw = (fw - dv * fw.dot(dv)).normalized(); side = dv.cross(fw).normalized()
S = 1.65
prof = [(0, -.055), (.12, -.06), (.27, -.12), (.44, -.62), (.57, -.32), (.63, 0), (.57, .32), (.44, .62), (.27, .12), (.12, .06), (0, .055)]
wedge(hard, end, fw, dv, side, prof, .1, S)
C.blob(arm, end, (.115, .115, .115), seg=12, rings=8)
C.tube(arm, [end, end + dv * .2, end + dv * .34 - fw * .1], [.075, .045, .003], sides=8, sub=3, tval=.5)
storm_edge, storm_core = C.Bag('bolt', smooth=False), C.Bag('bolt')
outer = [(.44, -.62), (.57, -.32), (.63, 0), (.57, .32), (.44, .62)]
inner = [(.41, -.5), (.5, -.27), (.55, 0), (.5, .27), (.41, .5)]
for s_ in (1, -1):
    vs = [end + fw * x * S + dv * y * S + side * (s_ * .012) for x, y in outer] + [end + fw * x * S + dv * y * S + side * (s_ * .058) for x, y in inner]
    F = [(i, i + 1, i + 6, i + 5) if s_ > 0 else (i + 5, i + 6, i + 1, i) for i in range(4)]
    storm_edge.add(vs, F, [.55] * len(vs))
pt = lambda x, y: end + fw * x * S + dv * y * S
C.tube(storm_core, [pt(*q) for q in outer], [.012, .018, .02, .018, .012], sides=5, sub=4, tval=1.0)
for a_, d_ in (((.44, -.62), (-.1, -.36, .14)), ((.63, 0), (.1, 0, .22)), ((.44, .62), (-.05, .36, .16))):
    q0 = pt(*a_); e_ = q0 + V(fw * d_[0] + dv * d_[1] + V((0, 0, d_[2])))
    arc = [q0.lerp(e_, i / 4) + V((C.rng.uniform(-.035, .035), C.rng.uniform(-.035, .035), C.rng.uniform(-.02, .035))) * (0 if i in (0, 4) else 1) for i in range(5)]
    C.tube(storm_edge, arc, [.012, .012, .009, .005, .002], sides=4, sub=1, tval=.55)
    C.tube(storm_core, arc, [.005, .005, .004, .002, .001], sides=4, sub=1, tval=1.0)
EXTRA['axe'] += [(storm_edge, 'storm_edge', 0), (storm_core, 'storm_edge_core', 0)]

# hand: for touching the world. Reaching out in front, big and plain.
end, glow, hard, arm = form('hand', [(.02, 0, -.02), (-.18, -.1, -.12), (-.4, -.26, -.32), (-.52, -.52, -.38), (-.56, -.82, -.3)], [.14, .118, .096, .082, .074])
C.blob(arm, end + V((0, -.08, .02)), (.135, .11, .08), seg=14, rings=9)
for i, (dx, L) in enumerate(((-.1, .27), (-.035, .31), (.035, .3), (.1, .25))):
    q = end + V((dx, -.16, .03))
    C.tube(arm, [q, q + V((dx * .4, -L * .55, .05)), q + V((dx * .7, -L, -.03))], [.056, .044, .004], sides=8, sub=3, tval=.5)
q = end + V((.135, -.06, 0))
C.tube(arm, [q, q + V((.1, -.06, .03)), q + V((.14, -.19, -.01))], [.058, .044, .004], sides=8, sub=3, tval=.5)
C.blob(glow, end + V((0, -.1, .1)), (.04, .035, .012), seg=10, rings=6, t=1.0)

# hammer: for the heavy slams. Thrown up over his head.
end, glow, hard, arm = form('hammer', [(.02, 0, -.02), (-.22, -.03, .03), (-.44, -.07, .2), (-.56, -.2, .58), (-.5, -.3, 1.02)], [.14, .118, .1, .09, .085])
x = V((-.25, -.95, .1)).normalized()
c = end + V((.0, -.02, .16))
C.tube(hard, [c - x * .5, c - x * .4, c + x * .4, c + x * .5], [.2, .27, .27, .2], sides=6, sub=1, tval=.5)
C.tube(glow, [c - x * .515, c - x * .517], [.11, .001], sides=6, sub=1, tval=1.0)
cap_rock, cap_lava = C.Bag('rock', smooth=False), C.Bag('lava')
u_ = x.cross(V((0, 0, 1))).normalized(); v_ = x.cross(u_)
C.tube(cap_lava, [c + x * .47, c + x * .535, c + x * .545], [.2, .17, .002], sides=6, sub=1, tval=.55)
C.blob(cap_lava, c + x * .548, (.07, .07, .07), seg=8, rings=6, t=.9)
for i in range(6):
    a_ = i / 6 * 6.283 + .3
    q = c + x * .47 + (u_ * math.cos(a_) + v_ * math.sin(a_)) * .235
    C.rock(cap_rock, q, (.1, .1, .1), sub=1, jit=.12)
    if i % 2 == 0:
        o_ = u_ * math.cos(a_ + .5) + v_ * math.sin(a_ + .5)
        C.tube(cap_lava, [c + x * .43 + o_ * .27, c + x * .25 + o_ * .275, c + x * .08 + o_ * .272], [.018, .012, .002], sides=4, sub=1, tval=.55)
for q0, h_ in ((c + x * .5 + v_ * .1 + V((0, 0, .18)), .24), (c + x * .46 - u_ * .16 + V((0, 0, .14)), .17)):
    C.tube(cap_lava, [q0, q0 + V((.02, -.02, h_ * .55)), q0 + V((-.015, .01, h_))], [.038, .028, .002], sides=6, sub=2, tval=.55)
EXTRA['hammer'] += [(cap_rock, 'hammer_rock', .006), (cap_lava, 'hammer_lava', 0)]

# spear: for stabs and lunges. The arm drawn out long and straight.
end, glow, hard, arm = form('spear', [(.02, 0, -.02), (-.13, -.24, -.08), (-.2, -.62, -.13), (-.24, -1.15, -.16), (-.27, -1.8, -.17)], [.14, .1, .075, .058, .05])
ax = V((-.04, -1, -.01)).normalized()
C.tube(hard, [end - ax * .05, end + ax * .14, end + ax * .34], [(.1, .04), (.125, .045), (.07, .03)], sides=4, sub=1, side=V((1, 0, .2)), tval=.5)
ice_tip = C.Bag('ice', smooth=False)
C.tube(ice_tip, [end + ax * .24, end + ax * .42, end + ax * .78, end + ax * 1.2], [(.075, .04), (.135, .06), (.08, .036), (.002, .002)], sides=4, sub=1, side=V((1, 0, .2)), tval=.5)
for sgn in (1, -1):
    b0 = end + ax * .3 + V((sgn * .06, 0, .01))
    C.tube(ice_tip, [b0, b0 + V((sgn * .1, .08, .02)), b0 + V((sgn * .2, .22, .03))], [.04, .026, .002], sides=4, sub=1, tval=.5)
C.rock(ice_tip, end + ax * .3 + V((0, 0, .055)), (.05, .07, .035), sub=1, jit=.1)
EXTRA['spear'] += [(ice_tip, 'spear_ice', .006)]

# ---- each weapon's element runs the whole length of the arm that makes it
Z = V((0, 0, 1))
def along(name, f):
    path, rad = PATHS[name]
    i = min(int(f * (len(path) - 1)), len(path) - 2)
    d_ = (path[i + 1] - path[i]).normalized()
    u_ = d_.cross(Z if abs(d_.z) < .9 else V((1, 0, 0))).normalized(); v_ = d_.cross(u_)
    x_ = f * (len(rad) - 1); k = min(int(x_), len(rad) - 2)
    return path[i], d_, u_, v_, rad[k] + (rad[k + 1] - rad[k]) * (x_ - k)
def under(d_):
    o = -Z - d_ * (-Z).dot(d_)
    return o.normalized() if o.length > .05 else V((0, -1, 0))

# axe: wind bursting off the arm, green lightning surging down it
burst, surge, surge_core = C.Bag('wind'), C.Bag('bolt'), C.Bag('bolt')
for i, f in enumerate((.16, .36, .56, .76)):    # gusts that spiral off the arm: curls, not spikes
    for sgn, a0_ in ((1, i * 2.3), (-1, i * 2.3 + 2.9)):
        pts = []
        for k in range(11):
            t_ = k / 10
            p_, d_, u_, v_, r_ = along('axe', min(f + .12 * t_, .98))
            a_ = a0_ + sgn * 3.4 * t_
            o = u_ * math.cos(a_) + v_ * math.sin(a_)
            pts.append(p_ + o * (r_ + .035 + .2 * t_ * t_))
        C.tube(burst, pts, [.006, .016, .017, .012, .002], sides=6, sub=1, tval=.5)
for a0_, w_ in ((.6, .026), (3.6, .021)):
    a_ = a0_; on, top, rs = [], [], []
    for k in range(17):
        p_, d_, u_, v_, r_ = along('axe', .05 + .93 * k / 16)
        a_ += C.rng.uniform(-.55, .55)
        o = u_ * math.cos(a_) + v_ * math.sin(a_)
        on.append(p_ + o * (r_ * 1.0 + .006)); top.append(p_ + o * (r_ * 1.0 + .006 + w_ * .7)); rs.append(w_ * (.5 + .5 * math.sin(math.pi * k / 16)))
    C.tube(surge, on, rs, sides=4, sub=1, tval=.55)
    C.tube(surge_core, top, [x * .45 for x in rs], sides=4, sub=1, tval=1.0)
EXTRA['axe'] += [(burst, 'axe_wind', .003), (surge, 'axe_surge', 0), (surge_core, 'axe_surge_core', 0)]

# hammer: lava seeping from cracks in the arm and dripping off its underside
seep = C.Bag('lava')
for a0_, f0, f1 in ((.8, .1, .5), (3.5, .28, .68), (5.2, .55, .94)):
    pts = []
    for k in range(9):
        p_, d_, u_, v_, r_ = along('hammer', f0 + (f1 - f0) * k / 8)
        a_ = a0_ + C.rng.uniform(-.28, .28)
        pts.append(p_ + (u_ * math.cos(a_) + v_ * math.sin(a_)) * (r_ * 1.0))
    C.tube(seep, pts, [.008, .022, .02, .018, .007], sides=5, sub=1, tval=.55)
for f, L in ((.16, .13), (.3, .22), (.42, .1), (.56, .18), (.7, .12), (.84, .16)):
    p_, d_, u_, v_, r_ = along('hammer', f)
    q = p_ + under(d_) * (r_ * .86)
    C.tube(seep, [q, q - Z * L * .55, q - Z * L], [.034, .015, .017], sides=6, sub=2, tval=.55)
    C.blob(seep, q - Z * (L + .012), (.025, .025, .033), seg=8, rings=6, t=.9)
    if L > .15:
        C.blob(seep, q - Z * (L + .14), (.016, .016, .024), seg=8, rings=5, t=.9)
EXTRA['hammer'] += [(seep, 'hammer_seep', 0)]

# spear: crystals of ice grown out of the arm, water dripping off it
frost, water = C.Bag('ice', smooth=False), C.Bag('ice')
for i, f in enumerate((.12, .22, .32, .43, .54, .65, .76, .87)):
    p_, d_, u_, v_, r_ = along('spear', f)
    for j, sc in ((0, 1.0), (1, .62)) if i % 2 == 0 else ((0, .85),):
        a_ = i * 2.1 + j * 1.0
        o = u_ * math.cos(a_) + v_ * math.sin(a_)
        L = (.13 + .05 * ((i * 3) % 3)) * sc
        C.tube(frost, [p_ + o * (r_ * .6), p_ + o * (r_ + L * .5) + d_ * .025, p_ + o * (r_ + L) + d_ * .05], [.04 * sc + .008, .032 * sc + .006, .002], sides=4, sub=1, tval=.5)
for f, L in ((.25, .1), (.48, .16), (.72, .12)):
    p_, d_, u_, v_, r_ = along('spear', f)
    q = p_ + under(d_) * (r_ * .85)
    C.tube(water, [q, q - Z * L], [.018, .007], sides=6, sub=2, tval=.5)
    C.blob(water, q - Z * (L + .012), (.018, .018, .026), seg=8, rings=6, t=.5)
    C.blob(water, q - Z * (L + .13), (.012, .012, .018), seg=8, rings=5, t=.5)
EXTRA['spear'] += [(frost, 'spear_frost', .005), (water, 'spear_water', .003)]

objs = {}
for name, bags in FORMS.items():
    objs[name] = []
    for k, bag, ol in zip(('arm', 'glow', 'hard'), bags, (.006, 0, .007)):
        if bag.v: objs[name].append(C.make_obj('form_%s_%s' % (name, k), bag, mats_all, col, outline=ol)[0])
    for bag, nm, ol in EXTRA.get(name, []):
        objs[name].append(C.make_obj('form_' + nm, bag, mats_all, col, outline=ol)[0])
    print('form', name, sum(len(p.vertices) - 2 for o in objs[name] for p in o.data.polygons))

for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name.startswith('spirit') and max((v.co.z for v in o.data.vertices), default=0) > 1.7:
        bpy.data.objects.remove(o)
C.ink_pass()
hull = {o.name: o for o in bpy.data.objects}
T_ = V((-.4, -.3, 1.05))
hero = C.camera('V1', (1.3, -7.6, 3.4), T_, lens=40)
game = C.camera('V2', (0, -9.5, 13), T_, lens=52)
near = C.camera('V3', (2.4, -3.7, 2.3), V((.4, -.2, 1.2)), lens=45)
for o in objs['hammer'] + objs['hand'] + objs['spear']: o.hide_render = True
C.render(os.path.join(OUT, 'void_left_arm.png'), near)
for name in FORMS:
    for other, group in objs.items():
        for o in group: o.hide_render = other != name
    C.render(os.path.join(OUT, 'void_%s_hero.png' % name), hero)
    C.render(os.path.join(OUT, 'void_%s_game.png' % name), game)
print('DONE', C.tris())
