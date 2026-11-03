# The Unfinished: a shaman being overtaken from his left shoulder down. His right side is still a man.
# Replaces build_comic for rig_comic.py. Same joints as before except the right ankle, which is a real ankle now.
# Rest coordinates: his left +X, front -Y, up +Z. Design notes: unfinished_poc/blockout.py was the silhouette study.
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import importlib, comic_lib as C
importlib.reload(C)
from mathutils import Vector as V

def bump(z, c, w): return math.exp(-((z - c) / w) ** 2)
def warp(v):
    v = V(v)
    sx = 1 + .17 * bump(v.z, 1.46, .24) - .13 * bump(v.z, .98, .13) + .05 * bump(v.z, .1, .35)
    sy = 1 + .1 * bump(v.z, 1.42, .22) - .1 * bump(v.z, 1.0, .13)
    return V((v.x * sx, v.y * sy, v.z))

# The rig is built from these. Only tr moved: it was a peg's tip on the floor, now an ankle matching the left one.
JOINTS = {k: warp(v) for k, v in dict(H=(.02, -.4, 1.72), sh=(-.37, -.14, 1.53), el=(-.62, -.3, 1.4), wr=(-.75, -.62, 1.58), hd=(-.8, -.72, 1.65),
    ms=(.36, -.12, 1.52), me=(.56, -.13, 1.14), mw=(.62, -.26, .78), mf=(.65, -.3, .6), hl=(.16, -.01, .9), kl=(.27, -.15, .5), al=(.25, 0, .13),
    hr=(-.17, -.01, .9), kr=(-.28, -.25, .53), tr=(-.25, -.36, .13), g=(-.74, .02, 1.98), Pv=(0, 0, .9)).items()}
JOINTS['SC'] = JOINTS['sh'] + V((-.05, 0, .1))

bags = {}
HINTS = {}    # object name -> [(first vertex, bone)]; rig_comic pins those vertices rigidly to the bone
def K(name, bone=None):
    b = bags[name]
    HINTS.setdefault(name, []).append((len(b.v), bone))
    return b

def shard(bag, c, n, up, w, h, t=.04):
    # a flat chiselled plate: wide back ring, narrow raised face, irregular outline
    n = V(n).normalized(); up = V(up); up = (up - n * up.dot(n)).normalized(); sd = n.cross(up)
    out = [(-.55, -.8), (.3, -1), (.85, -.45), (1, .3), (.25, 1), (-.8, .55)]
    out = [(x + C.rng.uniform(-.12, .12), y + C.rng.uniform(-.12, .12)) for x, y in out]
    c = V(c)
    ring = lambda k, off: [c + sd * x * w * k + up * y * h * k + n * off for x, y in out]
    vs = ring(1, 0) + ring(.66, t) + ring(.9, -t); N = len(out)
    F = [tuple(range(N, 2 * N)), tuple(reversed(range(2 * N, 3 * N)))]
    for i in range(N):
        j = (i + 1) % N
        F.append((i, j, N + j, N + i)); F.append((j, i, 2 * N + i, 2 * N + j))
    bag.add(vs, F)

def plate(b, rows, th=.016):
    m_, c_ = len(rows), len(rows[0])
    vs = [p for r_ in rows for p, o in r_] + [p - o * th for r_ in rows for p, o in r_]
    F = []; n_ = m_ * c_; ix = lambda i, j: i * c_ + j
    for i in range(m_ - 1):
        for j in range(c_ - 1):
            q = (ix(i, j), ix(i, j + 1), ix(i + 1, j + 1), ix(i + 1, j))
            F.append(q); F.append(tuple(n_ + v for v in reversed(q)))
    for j in range(c_ - 1):
        F.append((ix(0, j), n_ + ix(0, j), n_ + ix(0, j + 1), ix(0, j + 1)))
        F.append((ix(m_ - 1, j), ix(m_ - 1, j + 1), n_ + ix(m_ - 1, j + 1), n_ + ix(m_ - 1, j)))
    for i in range(m_ - 1):
        F.append((ix(i, 0), ix(i + 1, 0), n_ + ix(i + 1, 0), n_ + ix(i, 0)))
        F.append((ix(i, c_ - 1), n_ + ix(i, c_ - 1), n_ + ix(i + 1, c_ - 1), ix(i + 1, c_ - 1)))
    b.add(vs, F)

def build():
    J = JOINTS
    for k, s, sh in (('skin', True, None), ('head', True, None), ('socket', True, None), ('hair', True, None), ('iron', True, 40), ('bronze', True, 40), ('leather', True, None),
                     ('cloth', True, None), ('trousers', True, None), ('rock', False, None), ('bone', True, None), ('ice', False, None), ('teeth', True, None), ('black', True, None),
                     ('lava', True, None), ('spirit', True, None), ('eye_white', True, None), ('eye_blue', True, None), ('pupil', True, None),
                     ('fracture', True, None), ('scar', False, None), ('fur', True, None)):
        bags[k] = C.Bag(k, smooth=s, sharp=sh)
    for i in range(3):
        bags['fire%d' % i] = C.Bag('fire'); bags['bolt%d' % i] = C.Bag('bolt', smooth=False)
    bags['spirit_eyes'] = C.Bag('pupil')
    S_, Hd = bags['skin'], bags['head']
    H = J['H']

    # ---- body: one remeshed skin, so the shoulders bend
    C.tube(S_, [(0, 0, .86), (0, -.01, 1.02), (0, -.06, 1.24), (.02, -.14, 1.46), (.01, -.28, 1.62), H + V((0, .05, -.08))], [(.27, .19), (.27, .19), (.33, .24), (.38, .26), (.16, .13), (.095, .095)], sides=18)
    C.blob(S_, (.2, -.28, 1.4), (.2, .11, .14))      # the bare pec, on the side the plate tore from
    for z, y in ((1.04, -.19), (1.12, -.21), (1.21, -.24)):
        C.blob(S_, (.22, y, z), (.11, .035, .025), rot=(0, -.35, 0))
    sh, el, wr, hd = J['sh'], J['el'], J['wr'], J['hd']
    C.tube(S_, [sh, sh.lerp(el, .5) + V((0, 0, .02)), el], [.1, .085, .062], sides=12)
    C.blob(S_, sh + V((-.03, 0, .02)), (.11, .11, .1))
    C.tube(S_, [el, el.lerp(wr, .35) + V((0, .02, .02)), wr], [.06, .07, .045], sides=12)
    C.blob(S_, hd, (.07, .076, .066), rot=(.5, 0, .2))
    grip = hd + V((-.03, -.05, .03)); dv = V((-.22, -.28, 1)).normalized()
    u = (hd - grip); u = (u - dv * u.dot(dv)).normalized(); w_ = dv.cross(u)
    ring = lambda t, a, rr: grip + dv * t + (u * math.cos(a) + w_ * math.sin(a)) * rr
    for t, sgn, r0 in ((-.07, 1, .024), (-.025, 1, .026), (.02, 1, .026), (.065, 1, .024), (.1, -1, .027)):
        C.tube(S_, [hd + dv * t * .6] + [ring(t, sgn * math.radians(a_), .078) for a_ in (20, 110, 200, 270)], [r0, r0, r0 * .95, r0 * .85, r0 * .6], sides=8, sub=2)
    ms, me, mw, mf = J['ms'], J['me'], J['mw'], J['mf']
    C.tube(S_, [ms, ms.lerp(me, .5), me], [.14, .14, .115], sides=12)
    C.tube(S_, [me, me.lerp(mw, .5), mw, mf], [.115, .14, .16, .17], sides=12)
    C.blob(S_, mf + V((0, -.03, -.05)), (.185, .185, .16))
    for dy, L in ((-.13, .15), (-.045, .17), (.045, .16), (.13, .14)):    # thick fingers round the grip
        C.tube(S_, [mf + V((.1, dy - .03, -.08)), mf + V((.14, dy - .05, -.17)), mf + V((.1, dy - .07, -.08 - L))], [.052, .048, .03], sides=8, sub=2)

    # ---- head: the old sculpt, smaller count. Heavy brow, one blue eye, one burning.
    C.blob(Hd, H + V((0, .03, .04)), (.122, .14, .125))
    C.blob(Hd, H + V((0, -.03, -.075)), (.1, .09, .085))
    C.blob(Hd, H + V((0, -.055, -.115)), (.07, .06, .04))
    C.tube(Hd, [H + V((-.112, -.09, .034)), H + V((-.05, -.13, .046)), H + V((0, -.13, .016)), H + V((.05, -.13, .022)), H + V((.112, -.085, .022))], [.024, .033, .03, .036, .024], sides=10)
    for sx in (-1, 1):
        C.blob(Hd, H + V((sx * .088, -.085, -.035)), (.042, .036, .034))
        C.tube(Hd, [H + V((sx * .05, -.128, -.06)), H + V((sx * .1, -.09, -.1))], [.02, .014], sides=8, sub=1)
    C.tube(Hd, [H + V((-.002, -.13, .025)), H + V((.002, -.165, -.015)), H + V((.012, -.19, -.05)), H + V((.01, -.165, -.07))], [.019, .023, .032, .017], sides=10)
    C.blob(Hd, H + V((-.128, .015, -.005)), (.018, .036, .05), rot=(0, 0, .3))
    eL = H + V((-.052, -.118, -.003)); eR = H + V((.053, -.13, -.022))
    C.blob(K('socket', 'head'), eL + V((0, .006, 0)), (.041, .012, .034), seg=12, rings=7)
    C.blob(K('socket', 'head'), eR + V((0, .006, 0)), (.043, .012, .023), seg=12, rings=7, rot=(0, -.25, 0))
    C.blob(K('eye_white', 'head'), eL + V((0, -.002, 0)), (.027, .0095, .024), seg=10, rings=6)
    C.blob(K('eye_blue', 'head'), eL + V((.003, -.0095, .004)), (.011, .0035, .011), seg=8, rings=5, t=.3)
    C.blob(K('pupil', 'head'), eL + V((.003, -.0125, .004)), (.0045, .0015, .0045), seg=6, rings=4)
    C.blob(K('lava', 'head'), eR + V((0, -.001, 0)), (.034, .01, .017), seg=10, rings=5, rot=(0, -.25, 0), t=.95)
    C.blob(K('pupil', 'head'), eR + V((-.003, -.0085, 0)), (.0035, .002, .011), seg=6, rings=4)
    mouth = H + V((.005, -.128, -.095))
    C.blob(K('socket', 'head'), mouth, (.06, .016, .026), seg=12, rings=7, rot=(0, -.18, 0))
    for x, z, w, h_ in ((-.035, .009, .01, .012), (-.008, .012, .012, .014), (.022, .014, .013, .017), (.045, .018, .009, .012)):
        C.blob(K('teeth', 'head'), mouth + V((x, -.012, z)), (w, .006, h_), seg=6, rings=4)
    def lock3(ctrl, w, sides=7, sub=4, thick=.5):
        C.tube(bags['hair'], ctrl, [(w * .55, w * thick * .55), (w, w * thick), (w * .72, w * thick * .75), (.001, .001)], sides=sides, sub=sub)
    lock3([H + V((-.015, -.145, .062)), H + V((-.06, -.15, .08)), H + V((-.115, -.11, .095)), H + V((-.16, -.075, .1))], .03, thick=.7)
    lock3([H + V((.012, -.15, .042)), H + V((.06, -.155, .046)), H + V((.115, -.105, .058)), H + V((.16, -.07, .082))], .031, thick=.7)
    # moustache and a short beard, so it stops merging with the hair
    for sx, n_ in ((-1, 3), (1, 2)):
        for i in range(n_):
            q = H + V((sx * (.012 + i * .022), -.15 + i * .012, -.075 + i * .002)); L = .1 + i * .03
            lock3([q, q + V((sx * L * .4, -.012, -.012)), q + V((sx * L * .85, .004, -.05)), q + V((sx * L * 1.2, .03, -.1))], .024, sides=5, sub=3)
    C.tube(bags['hair'], [H + V((0, -.1, -.1)), H + V((.0, -.14, -.22)), H + V((-.03, -.12, -.34)), H + V((-.07, -.08, -.44))], [(.11, .05), (.1, .055), (.06, .04), (.004, .004)], sides=9, tval=.9)
    for x, L in ((-.09, .22), (-.045, .32), (0, .38), (.045, .3), (.09, .2)):
        q = H + V((x, -.112 + abs(x) * .42, -.12 + abs(x) * .55)); dz = -L
        lock3([q, q + V((x * .4, -.05, dz * .3)), q + V((x * .2 - .02, -.04, dz * .65)), q + V((-.06, .01, dz))], .055, sides=7, sub=3, thick=.6)
    # the sculpted parts take the 1.2 head stylisation, before the locks are laid over them
    for k in ('head', 'socket', 'eye_white', 'eye_blue', 'pupil', 'teeth', 'hair'):
        b = bags[k]
        b.v = [H + (v - H) * 1.2 for v in b.v]
    C.rock(K('rock', 'head'), H + V((.15, .02, -.01)), (.048, .058, .072), sub=2, jit=.05)    # the ear the voice uses
    C.tube(K('black', 'head'), [H + V((.14, -.04, .03)), H + V((.126, -.1, .09)), H + V((.1, -.15, .055)), H + V((.075, -.17, .0))], [.009, .011, .008, .002], sides=5, sub=1)

    # ---- hair: a few heavy locks, old and weighty, blown off him and hooking at the ends
    C.blob(bags['hair'], H + V((0, .06, .08)), (.155, .155, .13), seg=16, rings=10, t=.95)
    def lock4(root, a_, b_, tip, w):
        C.tube(bags['hair'], [H + V(root), H + V(a_), H + V(b_), H + V(tip)], [(w * .75, w * .55), (w, w * .72), (w * .78, w * .55), (.003, .003)], sides=8, sub=4)
    lock4((-.02, 0, .15), (-.16, .14, .4), (-.38, .34, .5), (-.62, .44, .36), .1)
    lock4((-.1, .05, .13), (-.3, .1, .22), (-.56, .2, .18), (-.78, .24, -.02), .09)
    lock4((.06, .02, .16), (-.02, .24, .38), (-.2, .52, .4), (-.44, .66, .22), .1)
    lock4((-.14, 0, .05), (-.28, .02, -.02), (-.44, .06, -.16), (-.54, .14, -.34), .075)
    lock4((.12, .05, .08), (.1, .3, .14), (-.02, .56, .04), (-.22, .72, -.2), .09)
    lock4((-.02, .12, 0), (-.1, .34, -.1), (-.26, .52, -.26), (-.42, .62, -.5), .09)
    lock4((.04, .06, .14), (-.06, .28, .28), (-.26, .46, .3), (-.52, .56, .14), .07)
    lock4((.13, .02, .1), (.2, .12, .12), (.2, .3, .04), (.12, .42, -.1), .06)

    # ---- breastplate on the side still his, torn at the sternum; the left half is gone
    chest_c = lambda z: V((-.01, -.01 - max(0, z - 1.02) * .24, z))
    chest_r = lambda z: (.27 + .1 * math.sin(min(1, max(0, (z - .94) / .62)) * 2.3), .205 + .065 * math.sin(min(1, max(0, (z - .94) / .62)) * 2.2))
    edge = [(.92, -96), (.99, -118), (1.07, -94), (1.15, -112), (1.23, -90), (1.31, -106), (1.39, -86), (1.47, -96), (1.55, -80), (1.6, -86)]
    rows = []
    for z, end in edge:
        c = chest_c(z); rx, ry = chest_r(z); row = []
        for j in range(22):
            az = 128 + (end - 128) * j / 21
            d = V((-math.cos(math.radians(az)), math.sin(math.radians(az)), 0))    # mirrored: covers -X
            ridge = .012 * math.exp(-((az + 90) / 14) ** 2)
            row.append((warp(c + V((d.x * (rx + .018), d.y * (ry + .018 + ridge), 0))), d))
        rows.append(row)
    n0 = len(bags['iron'].v)
    plate(K('iron', 'chest'), rows)
    b_i = bags['iron']
    for i in range(n0, len(b_i.v)):
        if b_i.v[i].z < 1.14: pass
    HINTS['iron'] = [(n0, 'SOFT_TORSO')]   # the plate spans the waist, so it bends with it
    C.tube(K('bronze', 'chest'), [r_[-1][0] + r_[-1][1] * .002 for r_ in rows], [.012, .012], sides=6, sub=1)
    C.tube(K('bronze', 'hips'), [p + o * .004 for p, o in rows[0]], [.016, .016], sides=6, sub=1)
    C.tube(K('bronze', 'chest'), [p + o * .004 for p, o in rows[-1]], [.015, .015], sides=6, sub=1)
    # fur over the human shoulder: he was a shaman, and it still shows on this side
    FC = sh + V((-.02, .03, .1))
    C.blob(K('fur', 'chest'), FC, (.17, .17, .09), seg=12, rings=7)
    for x, y, L in ((.15, .1, .17), (.02, .17, .2), (-.13, .14, .16), (-.2, .05, .21), (-.21, -.07, .15), (-.13, -.15, .2), (.03, -.18, .15), (.15, -.1, .18)):
        q = FC + V((x, y, .02))
        C.tube(K('fur', 'chest'), [q, q + V((x * .35, y * .35, -L * .55)), q + V((x * .7, y * .7, -L))], [.05, .03, .002], sides=5, sub=1)
    # beads and a fang on a cord at the neck
    for i in range(7):
        a = -2.7 + i * .42
        q = V((.0 + math.cos(a) * .15 - .02, -.3 + math.sin(a) * .1, 1.55 - .06 * math.sin(a + 1.6) ** 2))
        C.blob(K('bone', 'chest'), q, (.018, .018, .018), seg=6, rings=4)
    # wraps on the wiry forearm
    a0 = el.lerp(wr, .3); a1 = el.lerp(wr, .95)
    for f in (.0, .22, .44, .66, .88):
        C.tube(K('bone', 'lowerarm.r'), [a0.lerp(a1, f - .1 if f else 0), a0.lerp(a1, f + .09)], [.071 - f * .017, .071 - f * .017], sides=8, sub=1)

    # ---- left shoulder: scar tissue breaking out under drifting plates. Hump rides the chest, so it holds still.
    S = V((.47, -.12, 1.64)); SR = V((.34, .31, .29))
    def sph(az, el_, k=1.0):
        a, e = math.radians(az), math.radians(el_)
        d = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        return S + V((d.x * SR.x, d.y * SR.y, d.z * SR.z)) * k, d
    C.blob(K('scar', 'chest'), S, tuple(SR), seg=14, rings=9)
    # az -90 is his front, 0 his outside, 90 his back. Rows overlap enough to hide most of the scar, with cracks of gap.
    for az, el_, w, h, lift in ((-75, 18, .14, .12, 1.07), (-30, 18, .14, .12, 1.08), (15, 18, .14, .13, 1.08), (60, 20, .14, .13, 1.08), (108, 20, .13, .13, 1.07), (160, 22, .11, .12, 1.05),
                                (-105, 44, .11, .12, 1.1), (-55, 48, .14, .13, 1.12), (-5, 48, .15, .13, 1.13), (50, 50, .15, .13, 1.13), (108, 50, .14, .12, 1.1), (160, 52, .1, .11, 1.08),
                                (-60, 76, .13, .12, 1.16), (45, 78, .14, .13, 1.17), (150, 76, .1, .1, 1.12), (-25, -12, .13, .11, 1.05), (35, -12, .12, .11, 1.05), (-85, -10, .12, .1, 1.04)):
        p, d = sph(az, el_, lift)
        shard(K('rock', 'chest'), p, d, (0, 0, 1) if el_ < 60 else (0, -1, 0), w, h)
    for az, el_, k, w, h in ((12, 62, 1.62, .08, .17), (70, 52, 1.5, .07, .13), (-48, 58, 1.48, .06, .1)):
        p, d = sph(az, el_, k)    # torn loose and hanging in the air: the jagged crest on his outline
        shard(K('rock', 'chest'), p, d.lerp(V((0, -.5, .2)), .5), (d.x * .5, d.y * .5, 1), w, h, .035)
    C.tube(K('scar', 'upperarm.l'), [ms, ms.lerp(me, .5), me], [.185, .19, .165], sides=9, sub=1)
    C.tube(K('scar', 'lowerarm.l'), [me, me.lerp(mw, .5), mw], [.165, .19, .205], sides=9, sub=1)
    def arm_plates(bone, a_, b_, r, rows_):
        d = (b_ - a_).normalized()
        for f, ang, w, h in rows_:
            o = V((math.cos(math.radians(ang)), math.sin(math.radians(ang)), 0)); o = (o - d * o.dot(d)).normalized()
            shard(K('rock', bone), a_.lerp(b_, f) + o * r, o, d, w, h, .035)
    arm_plates('upperarm.l', ms, me, .19, ((.3, 0, .1, .11), (.72, 25, .1, .1), (.45, -72, .1, .1), (.55, 90, .11, .12), (.8, 150, .1, .09), (.2, -145, .09, .1), (.65, -130, .09, .09), (.15, 70, .1, .1), (.85, -45, .09, .09)))
    arm_plates('lowerarm.l', me, mw, .205, ((.22, 10, .11, .12), (.7, -15, .12, .13), (.42, -82, .11, .11), (.55, 80, .12, .13), (.9, 150, .1, .1), (.25, 150, .1, .11), (.6, -140, .1, .11), (.15, 95, .1, .1), (.88, 60, .1, .1), (.9, -70, .1, .1)))
    for y in (-.14, -.05, .05, .14):
        shard(K('rock', 'hand.l'), mf + V((.16, y - .04, -.1)), (1, 0, .2), (0, 0, 1), .05, .06, .03)

    # ---- fractures: one connected line, hump to sternum and on down the arm. Their ends are where he leaks.
    def crack(bone, pts, w=.024):
        C.tube(K('fracture', bone), [V(p) for p in pts], [w, w * .8, w * .55, .004], sides=5, sub=1, tval=1.0)
    def hump(*ae):
        out = []
        for (a0, e0), (a1, e1) in zip(ae, ae[1:]):
            for i in range(3):
                f = i / 3
                out.append(sph(a0 + (a1 - a0) * f + (4 if i % 2 else -4), e0 + (e1 - e0) * f + (-3 if i % 2 else 3), 1.31)[0])
        out.append(sph(*ae[-1], 1.31)[0])
        return out
    crack('chest', hump((100, 50), (60, 72), (5, 58), (-30, 48), (-75, 62), (-110, 30)) + [(.25, -.44, 1.53), (.17, -.47, 1.42), (.21, -.47, 1.3), (.09, -.44, 1.17)], .024)
    crack('chest', hump((5, 58), (15, 30), (-20, 12), (20, -20)), .02)
    crack('chest', hump((60, 72), (90, 25), (75, -10)), .018)
    crack('chest', [(.25, -.44, 1.53), (.13, -.42, 1.58), (.1, -.38, 1.68)], .02)
    crack('chest', [(.17, -.47, 1.42), (.05, -.46, 1.4), (0, -.46, 1.33)], .017)
    along = lambda a_, b_, f, o: a_.lerp(b_, f) + V(o)
    crack('upperarm.l', [along(ms, me, .08, (.11, -.21, .04)), along(ms, me, .36, (-.02, -.25, 0)), along(ms, me, .62, (.09, -.23, 0)), along(ms, me, .95, (0, -.22, 0))], .019)
    crack('lowerarm.l', [along(me, mw, .02, (0, -.22, 0)), along(me, mw, .34, (.11, -.24, 0)), along(me, mw, .66, (-.03, -.27, 0)), along(me, mw, 1.0, (.1, -.26, 0))], .019)
    for az, el_, top in ((-110, 30, .17), (20, -20, .13), (75, -10, .15)):
        p, d = sph(az, el_, 1.31); q = p + V((d.x * .05, d.y * .05, top))
        C.tube(K('fracture', 'chest'), [p, p.lerp(q, .5) + V((.02, 0, 0)), q], [.018, .014, .002], sides=5, sub=2, tval=1.0)

    # ---- back: a hide vest, and one torn sheet of cloak off the human shoulder. The hump burst through the rest.
    C.blob(K('leather', 'chest'), (-.05, .08, 1.36), (.32, .2, .26), seg=14, rings=9)
    C.blob(K('leather', 'spine'), (-.02, .05, 1.08), (.27, .18, .19), seg=14, rings=9)
    Pv = J['Pv']
    n = 21
    xs = [-.46 + .61 * i / (n - 1) for i in range(n)]
    tear = [.92, .66, .8, .96, .56, .74, .9, .72, 1.0, 1.1]
    def hem_z(i):
        f = i / (n - 1) * (len(tear) - 1); a = int(f); b_ = min(a + 1, len(tear) - 1)
        return tear[a] + (tear[b_] - tear[a]) * (f - a) + (.05 if i % 3 == 1 else -.03)
    fold = [.035 * math.sin(x * 44 + .6) + .018 * math.sin(x * 97) for x in xs]
    def row(y_of, z_of, k, sx):
        return [V((x * sx, y_of(x, i) + fold[i] * k, z_of(x, i))) for i, x in enumerate(xs)]
    top = row(lambda x, i: .25 + abs(x) * .05, lambda x, i: 1.6 - abs(x + .15) * .28, .15, 1)
    mid = row(lambda x, i: .39, lambda x, i: 1.15, .8, 1.1)
    hem = row(lambda x, i: .46 + (1.15 - hem_z(i)) * .4, lambda x, i: hem_z(i), 1.3, 1.22)
    hem = [V((v.x + (i % 2) * .012, v.y, v.z)) for i, v in enumerate(hem)]
    rows_ = [top, [a.lerp(b, .5) for a, b in zip(top, mid)], mid, [a.lerp(b, .5) for a, b in zip(mid, hem)], hem]
    gs = [1, .75, .5, .25, 0]
    bags['cloth'].add([v for r in rows_ for v in r], [(r * n + c, r * n + c + 1, (r + 1) * n + c + 1, (r + 1) * n + c) for r in range(4) for c in range(n - 1)], [g for g in gs for _ in xs])
    HINTS['cloth'] = [(0, None)]

    # ---- belt, faulds, tatters, charms
    C.tube(K('leather', 'hips'), [Pv + V((.285 * math.cos(a * .3142), .225 * math.sin(a * .3142), .02)) for a in range(21)], [(.018, .05)] * 2, sides=8, sub=1, side=(0, 0, 1))
    bk = Pv + V((0, -.232, .02))
    C.blob(K('bronze', 'hips'), bk, (.075, .02, .07), seg=10, rings=7, p=2.8)
    for i in range(9):
        a = i / 9 * 6.283 + .3; o = V((math.cos(a), math.sin(a), 0)); q = Pv + V((o.x * .29, o.y * .23, -.035))
        L = C.rng.uniform(.17, .23) * (1 if o.x < 0 else .6)    # the plates fell off the changing side too
        C.tube(K('iron', 'hips'), [q, q + o * .03 - V((0, 0, L * .5)), q + o * .055 - V((0, 0, L))], [(.07, .009), (.074, .01), (.058, .008)], sides=6, sub=2, side=o.cross(V((0, 0, 1))))
    for i in range(11):
        a = i / 11 * 6.283 + .2; o = V((math.cos(a), math.sin(a), 0)); q = Pv + V((o.x * .27, o.y * .21, -.05))
        L = C.rng.uniform(.3, .46); sd = o.cross(V((0, 0, 1))).normalized()
        C.tube(K('cloth', 'hips'), [q, q + o * .04 - V((0, 0, L * .5)), q + o * .07 + sd * C.rng.uniform(-.03, .03) - V((0, 0, L))], [(.055, .005), (.058, .005), (.002, .002)], sides=5, sub=3, side=sd)
    gc = Pv + V((-.31, -.1, -.14))
    C.blob(K('bronze', 'hips'), gc, (.062, .058, .074), seg=12, rings=8)
    C.blob(K('bronze', 'hips'), gc + V((0, 0, .09)), (.036, .034, .042), seg=10, rings=7)
    C.blob(K('bone', 'hips'), gc + V((-.03, .08, -.08)), (.04, .04, .06), seg=8, rings=5)

    # ---- legs: both real. The right is still flesh under a crust of ice.
    hl, kl, al = J['hl'], J['kl'], J['al']
    C.tube(bags['trousers'], [hl, hl.lerp(kl, .5), kl, kl.lerp(al, .5), al + V((0, 0, .05))], [.155, .14, .1, .095, .072], sides=12)
    C.tube(K('leather', 'lowerleg.l'), [al + V((0, 0, .17)), al + V((0, 0, .03))], [.09, .085], sides=10, sub=1)
    C.blob(K('leather', 'foot.l'), al + V((.01, -.09, -.065)), (.09, .165, .068), seg=12, rings=7, p=2.4)
    C.blob(K('iron', 'lowerleg.l'), kl + V((0, -.065, 0)), (.09, .055, .09), seg=12, rings=7, p=2.3)
    hr, kr, tr = J['hr'], J['kr'], J['tr']
    n1 = len(bags['trousers'].v)
    C.tube(bags['trousers'], [hr, hr.lerp(kr, .5), kr, kr.lerp(tr, .5), tr + V((0, 0, .05))], [.15, .135, .095, .09, .07], sides=12)
    C.tube(K('leather', 'lowerleg.r'), [tr + V((0, 0, .17)), tr + V((0, 0, .03))], [.09, .085], sides=10, sub=1)
    C.blob(K('leather', 'foot.r'), tr + V((.01, -.09, -.065)), (.09, .165, .068), seg=12, rings=7, p=2.4)
    C.blob(K('iron', 'lowerleg.r'), kr + V((0, -.06, 0)), (.08, .05, .08), seg=10, rings=6, p=2.3)
    for bone, a_, b_, f, o, s in (('upperleg.r', hr, kr, .7, (-.1, -.03, .06), .08), ('lowerleg.r', kr, tr, .02, (-.11, -.04, .1), .1), ('lowerleg.r', kr, tr, .3, (-.13, 0, .12), .13),
                                  ('lowerleg.r', kr, tr, .32, (0, -.12, .14), .11), ('lowerleg.r', kr, tr, .55, (-.1, -.05, .16), .12), ('lowerleg.r', kr, tr, .7, (.07, -.08, .1), .09), ('lowerleg.r', kr, tr, .8, (-.08, .05, .08), .08)):
        p = a_.lerp(b_, f) + V(o)
        C.tube(K('ice', bone), [p - V(o) * .4, p, p + V(o) * .7 + V((0, 0, s))], [.05, .035, .002], sides=5, sub=1)

    # ---- not shipped: the Blender showcase's familiar and the flipbooks the rig script expects
    g = J['g']
    C.blob(bags['spirit'], g, (.05, .05, .05), seg=8, rings=5)
    C.tube(bags['spirit'], [g + V((.02, .05, -.05)), g + V((-.06, .1, -.13))], [.02, .002], sides=5, sub=1)
    C.blob(bags['spirit_eyes'], g + V((0, -.05, 0)), (.01, .004, .01), seg=6, rings=4)
    for i in range(3):
        C.blob(K('fire%d' % i, 'hand.l'), mf, (.01, .01, .01), seg=4, rings=3)
        C.blob(K('bolt%d' % i, 'hand.r'), hd, (.01, .01, .01), seg=4, rings=3)
    return bags

def build_all():
    scn = bpy.context.scene
    for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
    C.ink_material()
    mats = C.materials()
    mats['fracture'] = C.emit('P_Fracture', (.08, .72, .68), (.86, 1, .92))
    mats['scar'] = C.toon('P_Scar', (.1, .05, .12), (.26, .14, .22), (.42, .24, .3), rim=(.1, .05, .1), brush=.2)
    mats['fur'] = C.toon('P_Fur', (.07, .05, .07), (.2, .14, .13), (.36, .27, .22), rim=(.1, .1, .1), brush=.25)
    mats['haft'] = C.toon('P_Haft', (.08, .04, .04), (.27, .14, .09), (.46, .28, .16), rim=(.08, .04, .03), brush=.2)
    C.rng.seed(11)
    bags.clear(); HINTS.clear()
    B = build()
    J = JOINTS
    col = scn.collection
    tot = 0; rep = {}
    for k, b in B.items():
        if not b.v: continue
        if k == 'skin': o, t = C.make_obj('skin', b, mats, col, voxel=.0095, smooth_iter=12, outline=.006, decim=.09)
        elif k == 'head': o, t = C.make_obj('head', b, mats, col, voxel=.0055, smooth_iter=7, outline=.005, decim=.12)
        elif b.mat in ('lava', 'bolt', 'eye_white', 'eye_blue', 'pupil', 'socket', 'teeth', 'black', 'fracture'): o, t = C.make_obj(k, b, mats, col, outline=0)
        elif b.mat in ('fire', 'spirit'): o, t = C.make_obj(k, b, mats, col, outline=.004)
        else: o, t = C.make_obj(k, b, mats, col, outline=.006)
        tot += t; rep[k] = t
    print('UNFINISHED tris', tot, dict(sorted(rep.items(), key=lambda kv: -kv[1])))
    C.comic_scene()
    cams = {'hero': C.camera('CamHero', (1.2, -6.8, 1.6), (-.02, -.15, 1.12), lens=52),
            'side': C.camera('CamSide', (-5.2, -1.8, 1.4), (-.05, -.2, 1.1), lens=58),
            'back': C.camera('CamBack', (-1.4, 3.6, 1.6), (0, 0, 1.1), lens=58),
            'game': C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .95), ortho=3.6),
            'face': C.camera('CamFace', (.35, -2.3, 2.0), (.0, -.42, 1.72), lens=110)}
    bpy.context.scene.camera = cams['hero']
    return cams, J

def hint_of(name):
    """Per-vertex bone from the K() calls, or None where the rig's own rules apply."""
    marks = HINTS.get(name)
    if not marks: return None
    n = len(bags[name].v)
    out = [None] * n
    for i, (start, bone) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else n
        for v in range(start, end): out[v] = bone
    return out
