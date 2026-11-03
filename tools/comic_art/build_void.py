# The shaman with one void arm: his right arm is gone to a purple tendril that shapes itself into his weapon, an axe for now
# (rig_comic adds the axe). His left is an ordinary arm with air rings round it. build_tainted supplies the rest of the body.
#   Exported through rig_comic.py; there is no stills mode here. unfinished_poc/closeup_tight.py shows the result.
import bpy, sys, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import build_tainted as T
C = T.C
from mathutils import Vector as V

def _seg(p, a, b):
    d = b - a
    t = max(0, min(1, (p - a).dot(d) / d.length_squared))
    return (p - (a + d * t)).length, t

_build = C.build
def _body():
    """His old body, less everything the two new arms replace. Joints here are before build_tainted's warp."""
    B = _build()
    J = C.JOINTS
    sh, el, wr, hd, ms, H = J['sh'], J['el'], J['wr'], J['hd'], J['ms'], J['H']
    def on_arm(p):
        d0, t0 = _seg(p, sh, el)
        if t0 > .28 and d0 < .2: return True
        if _seg(p, el, wr)[0] < .2: return True
        return _seg(p, wr, hd + (hd - wr).normalized() * .25)[0] < .24
    def bar(p): return .13 < abs(p.x) < .55 and 1.38 < p.z < 1.66 and p.y < -.1   # the old arms' straps, cut off by their removal
    for k, b in B.items():
        if k == 'wind' or k.startswith(('bolt', 'fire')):
            b.v, b.f, b.t = [], [], []
        elif k in ('skin', 'bone', 'leather', 'bronze', 'iron', 'cloth'):
            b.f = [f for f in b.f if not all(on_arm(b.v[i]) for i in f)]
        if k in ('bronze', 'bone'):
            b.f = [f for f in b.f if not all(bar(b.v[i]) for i in f)]
        if k in ('rock', 'lava'):      # the ear and the eye are all that stay
            b.f = [f for f in b.f if all((b.v[i] - H).length < .3 for i in f)]
    # an ordinary left arm: its own joints, shorter than the old fist-at-the-knee, unioned into the skin
    la = ms + V((-.02, 0, -.01)); le = la + V((.13, -.01, -.37)); lw = le + V((.03, -.1, -.31)); lf = lw + V((.01, -.035, -.09))
    J['me'], J['mw'], J['mf'] = le.copy(), lw.copy(), lf.copy()
    C.tube(B['skin'], [la, la.lerp(le, .5), le, le.lerp(lw, .35), lw, lf], [.105, .085, .066, .074, .05, .052], sides=12, sub=3)
    C.blob(B['skin'], la + V((.02, 0, 0)), (.12, .115, .11), seg=14, rings=10)
    C.blob(B['skin'], lf, (.066, .06, .075), seg=12, rings=8)
    for y in (-.042, -.014, .014, .042):
        C.tube(B['skin'], [lf + V((.045, y, -.03)), lf + V((.04, y - .012, -.075)), lf + V((-.005, y - .025, -.075))], [.02, .019, .017], sides=7, sub=2)
    C.tube(B['skin'], [lf + V((-.045, -.035, .02)), lf + V((-.035, -.07, -.025)), lf + V((.015, -.075, -.04))], [.023, .02, .017], sides=7, sub=2)
    dn = (lw - le).normalized()
    C.tube(B['leather'], [lw - dn * .07, lw - dn * .005], [.066, .06], sides=10, sub=1, tval=.5)
    return B

def _ring(bag, c, axis, r_, w, start, tilt):
    ax = V(axis).normalized()
    a0 = ax.cross(V((0, 1, 0))).normalized()
    ax2 = (ax + a0 * tilt).normalized()
    a0 = ax2.cross(V((0, 1, 0))).normalized(); a1 = ax2.cross(a0)
    n_ = 22; arc = 5.6
    pts = [c + (a0 * math.cos(start + arc * i / n_) + a1 * math.sin(start + arc * i / n_)) * r_ + ax2 * (.016 * i / n_) for i in range(n_ + 1)]
    rad = [max(w * math.sin(math.pi * min(1, (i + 1.5) / n_)) ** .6, .002) for i in range(n_ + 1)]
    C.tube(bag, pts, rad, sides=6, sub=1, tval=.5)

def build_all():
    C.build = _body
    _vein = T.vein
    def vein(tree, pts, w, bones, **kw):
        if bones in (T.ARM_R, T.ARM_L, T.LEG_R): return     # the purple belongs to the void arm and where it spreads from
        _vein(tree, pts, w, bones, **kw)
    T.vein = vein
    T.spark = lambda *a, **k: None
    T.tongue = lambda *a, **k: None
    _taint = T.taint
    def taint(J_):
        r = C.rock; C.rock = lambda *a, **k: None
        _taint(J_)
        C.rock = r
    T.taint = taint
    cams, J = T.build_all()
    scn = bpy.context.scene; col = scn.collection
    C.toon('P_Tendril', (.1, .025, .22), (.34, .1, .6), (.62, .34, .92), rim=(.5, .2, .8), brush=.14)
    C.toon('P_VoidHard', (.04, .012, .1), (.15, .05, .3), (.31, .15, .52), rim=(.5, .2, .8), brush=.14)
    C.emit('P_StormGreen', (.02, .25, .16), (.86, 1, .72), mid=(.16, .85, .38))
    mats = {m.name[2:].lower(): m for m in bpy.data.materials if m.name.startswith('P_') and m.name != 'P_Ink'}
    bags = T.bags
    for k, mat, smooth in (('void_arm', 'tendril', True), ('void_root', 'blight', True), ('void_surge', 'stormgreen', True), ('void_surge_core', 'stormgreen', True), ('left_rings', 'wind', True)):
        bags[k] = C.Bag(mat, smooth=smooth)
    # ---- the void arm, on the right arm's bones: thick at the shoulder, soft bends in it, thinning to the hand where the haft goes on
    sh, el, wr, hd = J['sh'], J['el'], J['wr'], J['hd']
    P = [sh + V((.02, 0, -.02)), sh.lerp(el, .5) + V((.0, .02, .035)), el, el.lerp(wr, .5) + V((-.045, .025, -.03)), wr, hd]
    R = [.145, .126, .102, .09, .08, .076]
    C.tube(T.K('void_arm', T.ARM_R), P, R, sides=11, sub=4, tval=.5)
    C.blob(bags['void_arm'], hd, (.086, .086, .086), seg=10, rings=7)
    q0 = P[1]; C.tube(bags['void_arm'], [q0, q0 + V((-.14, .12, .06)), q0 + V((-.2, .24, .18))], [.04, .025, .002], sides=7, sub=3, tval=.5)
    for i in range(9):       # black roots where it leaves him
        a = i / 9 * 6.283
        q = sh + V((-.1 + .05 * math.cos(a), .155 * math.sin(a), .155 * math.cos(a)))
        C.tube(T.K('void_root', ('chest', 'upperarm.r')), [q + V((.12, 0, 0)), q, q + V((-.13 - .05 * (i % 3), .03 * math.sin(a), .03 * math.cos(a)))], [.012, .03, .002], sides=5, sub=2, tval=.5)
    # green lightning surging down it, for the axe (and for now always: the other forms come later)
    path = C.catmull(P, 5); N = len(path)
    for a0, w in ((.6, .024), (3.6, .019)):
        a = a0; on, top, rs = [], [], []
        for k in range(2, N - 1):
            f = k / (N - 1); p = path[k]; d = (path[k + 1] - path[k - 1]).normalized()
            u = d.cross(V((0, 0, 1))).normalized(); v = d.cross(u)
            x = f * (len(R) - 1); i = min(int(x), len(R) - 2); r = R[i] + (R[i + 1] - R[i]) * (x - i)
            a += C.rng.uniform(-.6, .6)
            o = u * math.cos(a) + v * math.sin(a)
            on.append(p + o * (r + .004)); top.append(p + o * (r + .004 + w * .7)); rs.append(w * (.5 + .5 * math.sin(math.pi * f)))
        C.tube(T.K('void_surge', T.ARM_R), on, rs, sides=4, sub=1, tval=.55)
        C.tube(T.K('void_surge_core', T.ARM_R), top, [x * .45 for x in rs], sides=4, sub=1, tval=1.0)
    # ---- the left arm's air rings
    ms, me_, mw = J['ms'], J['me'], J['mw']
    la = ms + V((-.02, 0, -.01))
    _ring(T.K('left_rings', 'upperarm.l'), la.lerp(me_, .5), me_ - la, .155, .012, .4, .2)
    _ring(T.K('left_rings', 'lowerarm.l'), me_.lerp(mw, .3), mw - me_, .14, .011, 2.4, -.2)
    _ring(T.K('left_rings', 'lowerarm.l'), me_.lerp(mw, .85), mw - me_, .105, .009, 4.6, .22)
    for k, ol in (('void_arm', .006), ('void_root', .004), ('void_surge', 0), ('void_surge_core', 0), ('left_rings', .003)):
        C.make_obj(k, bags[k], mats, col, outline=ol)
    # rig_poc's flipbook code wants these to exist; export_comic_shaman leaves them out
    for i in range(3):
        for base, bone, at, mat in (('fire', 'hand.l', J['mf'], 'fire'), ('bolt', 'hand.r', hd, 'bolt')):
            k = '%s%d' % (base, i)
            bags[k] = C.Bag(mat)
            C.blob(T.K(k, bone), at, (.01, .01, .01), seg=4, rings=3)
            C.make_obj(k, bags[k], mats, col, outline=0)
    return cams, J
