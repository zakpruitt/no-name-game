# One function per spirit cast, redesigned as drawn comic shapes. Names and shapes follow the game's casts
# (scripts/elements.gd CASTS). Each takes the clip's start frame F, the kit K and root(frame) -> hero's ground position.
# Forward is -Y in these clips.
import math
from mathutils import Vector as V, Quaternion as Q
import comic_lib as C
FWD = V((0, -1, 0)); UP = V((0, 0, 1)); YAW = 0.0
BEATS = {'RUSH': (0, 8, 16, 24), 'CH': (-22, -8, 0, 6), 'SKY': (-14, -6, 0, 6)}
HIT = {'L1': 8, 'L2': 11, 'L3': 18, 'LH': 12, 'LLH': 16, 'H': 12, 'DL': 9, 'LHH': 21, 'CH': 37, 'SKY': 32, 'RUSH': 9, 'AF': 40}

def echo(K, F, root, sweep, r, word, wsize=.9):
    """A giant spectral axe follows the real swing a beat later, on the same arc, trailing a drawn smear."""
    f = F; c = root(f) + UP * 1.05
    a0, a1 = sweep[0] + YAW, sweep[1] + YAW
    n = 3
    size = r * .5
    o = K.axe(size, f + 1, f + n * 2 + 5)
    for i in range(n + 1):
        u = i / n; th = a0 + (a1 - a0) * u
        K.key(o, f + 1 + i * 2, loc=c + V((math.sin(th), -math.cos(th), 0)) * .55, rot=K.flat(th, flip=a1 < a0), scale=size)
    K.fade(o, f + n * 2 + 1)
    K.swoosh(f + 1, c, a0, a1, r * .45, r * 1.02, z=0)
    tip = (a0 + a1) * .5
    p = c + V((math.sin(tip), -math.cos(tip), 0)) * r * .72
    K.burst(f + 4, p, .55)
    K.word(f + 4, p + UP * .9, word, size=wsize, tilt=-.12 if a1 > a0 else .12, dur=14)

def cleave(K, F, root, size=2.6, ahead=2.9, gap=1.55):
    """Two colossal axes rise either side and slam inward into a V on the target, side-on to the camera so they read."""
    f = F; t = root(f) + FWD * ahead
    for sx in (-1, 1):
        o = K.axe(size, f - 9, f + 20, hull=.03)
        inward = V((-sx, 0, 0))
        butt = t + V((sx * gap, 0, .1))
        rise_up = K.basis(inward, V((sx * .25, 0, 1)))
        K.key(o, f - 9, loc=butt - UP * size * .95, rot=rise_up, scale=size)
        K.key(o, f - 7, loc=butt - UP * size * .55, rot=rise_up, scale=size)
        K.key(o, f - 5, loc=butt - UP * size * .15, rot=rise_up, scale=size)
        K.key(o, f - 3, loc=butt, rot=K.basis(inward, V((sx * .42, 0, 1))), scale=size)  # the lean back: anticipation
        K.key(o, f - 1, loc=butt, rot=K.basis(inward, V((sx * .3, 0, 1))), scale=size)
        slam = K.basis(inward + V((0, 0, -1)), V((-sx * 1.05, 0, 1)))
        K.key(o, f, loc=butt, rot=slam, scale=size)
        K.key(o, f + 2, loc=butt + V((sx * .04, 0, 0)), scale=size)
        K.key(o, f + 4, loc=butt, scale=size)
        K.fade(o, f + 12)
    K.impact(f, t, .85, 'KRAK!', .85, big=True, panel='Triple Chop')

def crown(K, F, root, size=2.5, ahead=2.2):
    """Three axes burst blade-up from the floor round the target, faces to the camera. The launch."""
    f = F; t = root(f) + FWD * ahead
    for i, a in enumerate((-2.0, 0, 2.0)):
        sx = math.sin(a); cy = math.cos(a)
        base = t + V((sx * .85, cy * .35, 0))
        o = K.axe(size * (1.1 if i == 1 else .9), f - 1, f + 20, hull=.03)
        rot = K.basis(V((-sx if sx else 1, 0, 0)), V((sx * .32, 0, 1)))
        sz = size * (1.1 if i == 1 else .9)
        for df, k in ((-1, -.85), (1, -.25), (3, .08), (5, .02), (9, 0)):
            K.key(o, f + df + i, loc=base + UP * sz * k, rot=rot, scale=sz)
        K.fade(o, f + 12)
    K.impact(f, t, .7, 'FWOOM!', .8, panel='Launcher')
    for i in range(14):   # the column of streaks: drawn upward speed
        K.debris(f + 1, t, n=1, speed=1.2, size=.1)
        break

def rift(K, F, root, n=6, gap=1.05):
    """A wave of colossal axes bursting up one after another along the thrust, growing, leaning into it."""
    f = F; p0 = root(f) + FWD * 1.5
    for i in range(n):
        sz = 1.2 + i * .26; df = i * 2
        pos = p0 + FWD * (gap * i) + V(((-1) ** i * .4, 0, 0))
        o = K.axe(sz, f + df, f + df + 22, hull=.026)
        rot = K.basis(V(((-1) ** (i + 1), 0, 0)), FWD * .5 + UP)
        for d, k in ((0, -.8), (2, -.1), (4, .04), (6, 0)):
            K.key(o, f + df + d, loc=pos + UP * sz * k, rot=rot, scale=sz)
        K.fade(o, f + df + 14)
        K.ring(f + df, pos, .25, 1.0 + i * .14, dur=8)
        K.burst(f + df, pos + UP * .3, .4 + i * .08, dur=5)
        K.puffs(f + df, pos, n=3, R=.85, size=.36)
        K.cracks(f + df, pos, 1.0 + i * .1, dur=20, n=6)
    K.impact(f, root(f) + FWD * 1.9, .75, None, big=True, panel='Ground Breaker')
    K.word(f + 5, p0 + FWD * gap * 2.2 + UP * 1.4, 'THOOOM!', size=.95, tilt=.06, dur=22)
    K.debris(f + 6, p0 + FWD * gap * 3, n=10, speed=3, size=.18)

def wheel(K, F, root, a, b, count=4, r=2.3, turns=2.5):
    """Axes laid flat like a sawblade, grinding round him. Broad side up so the camera reads the whole wheel."""
    c = root(a) + UP * .95
    for i in range(count):
        o = K.axe(r, a, b + 5, hull=.026)
        off = i / count * 6.2832
        for f in range(a, b + 1, 2):
            u = (f - a) / max(b - a, 1)
            sc = r * min(1, (f - a + 2) / 6) * (1 if f < b - 4 else max(.5, (b - f) / 4 * .5 + .5))
            K.key(o, f, loc=c, rot=K.flat(off - turns * 6.2832 * u), scale=sc)
        K.fade(o, b)
    K_y = (0, 2.1, 4.2)
    for f in range(a, b, 6):
        a0 = (f - a) * -.6
        K.swoosh(f, c, a0, a0 - 5.2, r * .55, r * 1.04, z=0)
    K.word(a + 4, c + UP * 1.3 + V((-1.9, 0, 0)), 'VRRRSH!', size=1.0, tilt=.14, dur=20)
    for f in range(a + 4, b, 8):
        K.burst(f, c + V((math.sin(f) * r * .8, math.cos(f) * r * .8, 0)), .36, dur=5)
    K.panel(b - 2, 14, 'Whirlwind')

def tomahawk(K, F, root, reach=5.2, size=1.6):
    """Flung spinning flat, pierces out, boomerangs back to his hand. The speed is drawn as ink streaks behind it."""
    f = F; st = root(f) + UP * 1.05; out = 12; back = 16
    o = K.axe(size, f, f + out + back + 2, hull=.026)
    turns = 5
    for i in range(0, out + back + 1, 2):
        if i <= out:
            u = 1 - (1 - i / out) ** 2.4; d = reach * u
        else:
            u = ((i - out) / back) ** 2.2; d = reach * (1 - u)
        th = i * 6.2832 * turns / (out + back)
        r_ = V((math.sin(-th), -math.cos(-th), 0)) * size * .55
        K.key(o, f + i, loc=st + FWD * d - r_, rot=K.flat(-th), scale=size)
        if i % 4 == 0 and i not in (0, out):
            K.burst(f + i, st + FWD * d + V((0, 0, .1)), .26, dur=3)
    K.swoosh(f, st + FWD * 2.4, YAW - .45, YAW + .45, 1.8, 3.1, z=0)
    K.swoosh(f + 4, st + FWD * 3.8, YAW - .5, YAW + .5, 1.3, 2.2, z=0)
    K.word(f + 3, st + FWD * 2.8 + UP * 1.2, 'SHIIING!', size=.95, tilt=-.1, dur=16)
    K.burst(f + out, st + FWD * reach, .85)
    K.panel(f + 2, 14, 'Dash Stab')

def guillotine(K, F, root, size=3.4, ahead=2.2, offset=None):
    """A colossal axe drops blade-first out of the sky and buries itself."""
    f = F; t = (root(f) + FWD * ahead) if offset is None else offset
    down = K.basis(V((1, 0, 0)), V((0, 0, -1)))
    o = K.axe(size, f - 6, f + 34, hull=.03)
    bury = size - .55
    for df, z in ((-6, 16), (-4, 11), (-2, 5.6), (0, bury), (2, bury - .12), (4, bury)):
        K.key(o, f + df, loc=t + UP * z, rot=down, scale=size)
    K.fade(o, f + 24)
    return t

def spike(K, F, root):
    t = guillotine(K, F, root)
    K.impact(F, t, .9, 'CHUNK!', .9, big=True, panel='Spike')

def _ancestor_mesh(K):
    """A towering ghost of him, drawn like the axes: bull shoulders, crest, beard, no legs (it trails off into the floor)."""
    b = C.Bag('ghost')
    C.tube(b, [V((0, .06, -.5)), V((0, .08, 0)), V((0, .1, .32)), V((0, .08, .7)), V((0, 0, .98))], [(.1, .08), (.2, .15), (.27, .2), (.46, .28), (.2, .17)], sides=10, sub=2, tval=.3)
    for sx in (-1, 1):
        C.blob(b, V((sx * .44, .02, .86)), (.19, .17, .16), seg=10, rings=6, t=.75)     # shoulders
    C.tube(b, [V((-.46, .02, .82)), V((-.54, -.04, .5)), V((-.5, -.12, .24))], [.11, .085, .1], sides=8, sub=1, tval=.42)   # the off arm hangs
    C.blob(b, V((-.5, -.13, .2)), (.11, .1, .11), seg=8, rings=5, t=.75)
    C.blob(b, V((0, -.16, 1.14)), (.19, .21, .19), seg=12, rings=7, t=.72)
    for sx in (-1, 1):
        C.tube(b, [V((sx * .16, -.12, 1.2)), V((sx * .32, -.1, 1.32)), V((sx * .36, -.06, 1.52))], [.05, .035, .002], sides=6, sub=1, tval=1.0)   # horns
    for x, h, L in ((-.1, 1.26, .36), (-.035, 1.32, .5), (.035, 1.32, .54), (.1, 1.26, .38)):
        C.tube(b, [V((x, -.12, h)), V((x * 1.2, .08, h + L * .6)), V((x * 1.1, .36, h + L))], [.075, .05, .002], sides=6, sub=1, tval=1.0)
    C.tube(b, [V((0, -.3, 1.08)), V((.02, -.35, .82)), V((.05, -.27, .56))], [(.15, .05), (.11, .05), (.003, .003)], sides=7, tval=.9)
    # spirit flames off the shoulders and round the waist, war paint across the chest: jagged drawn shapes, not a mannequin
    for sx in (-1, 1):
        for dx, dz, L in ((.0, .14, .42), (.16, .1, .34), (.28, -.02, .3), (-.14, .12, .3)):
            C.tube(b, [V((sx * .44 + sx * dx * .5, .02, .9 + dz * .5)), V((sx * (.44 + dx), .06, .9 + dz + L * .5)), V((sx * (.48 + dx * 1.5), .14, .9 + dz + L))], [.08, .05, .002], sides=5, sub=1, tval=1.0)
    for i in range(11):
        a_ = i / 11 * 6.2832
        cx, cy = math.sin(a_), math.cos(a_)
        C.tube(b, [V((cx * .2, cy * .15, .22)), V((cx * .38, cy * .28, .02 + .06 * (i % 2))), V((cx * .5, cy * .36, -.28 - .1 * (i % 3)))], [.09, .06, .002], sides=5, sub=1, tval=.95 if i % 2 else .6)
    for z, w in ((.74, .34), (.62, .3), (.5, .24)):
        C.tube(b, [V((-w, -.235, z + .05)), V((0, -.3, z - .04)), V((w, -.235, z + .05))], [.012, .03, .012], sides=5, sub=1, tval=0.0)
    C.tube(b, [V((-.1, -.36, 1.27)), V((.1, -.36, 1.27))], [.016, .016], sides=5, sub=1, tval=1.0)
    # glowing eye slits: the brightest thing on him
    for sx in (-1, 1):
        C.blob(b, V((sx * .08, -.35, 1.16)), (.05, .012, .018), seg=6, rings=4, t=1.0)
    me = K._bag_mesh(b, 'fx_ancestor', [K.ghost, K.inkd])
    ca = me.color_attributes['g']; L = V((-.45, -.5, .74)).normalized()
    for i, v in enumerate(me.vertices):
        if .05 < b.t[i] < .95: ca.data[i].color = (lambda t: (t, t, t, 1))(min(.9, b.t[i] * .35 + .62 * max(0, v.normal.dot(L))))
    return me

def _arm_mesh(K):
    b = C.Bag('ghost')
    C.tube(b, [V((0, 0, 0)), V((0, 0, .5)), V((0, 0, 1.0))], [.16, .12, .13], sides=8, sub=1, tval=.42)
    C.blob(b, V((0, 0, 1.0)), (.14, .13, .14), seg=8, rings=5, t=.75)
    return K._bag_mesh(b, 'fx_ancestor_arm', [K.ghost, K.inkd])

def avatar(K, F, root, scale=1.7, word='BOOOOM!', wsize=1.05, name='Charged Slam', hit_ahead=2.6, rise_from=26):
    """He leaps; behind him the ancestor rises and brings the great axe down with him. The figure leans back towards
    the camera, the way the game's casts turn their faces to it: from above a true upright is all foreshortened top."""
    f = F
    me = getattr(K, '_anc', None) or _ancestor_mesh(K); K._anc = me
    arm_me = getattr(K, '_arm', None) or _arm_mesh(K); K._arm = arm_me
    CR, CU = K.q @ V((1, 0, 0)), K.q @ V((0, 1, 0))
    tilt = Q().slerp(K.q @ Q((1, 0, 0), -math.pi / 2), .85)
    rot = tilt @ Q((0, 0, 1), math.radians(50))
    up = tilt @ UP
    t = root(f) + FWD * hit_ahead
    back = root(f) - FWD * (1.5 + .6 * scale) + UP * .1
    b = K._link(me, 'ancestor', hull=.02); K.vis(b, f - rise_from, f + 24)
    K.key(b, f - rise_from, alpha=1.0)
    sink = {-rise_from: 1.3, -rise_from + 6: .85, -rise_from + 12: .42, -10: .12, -4: -.04, -2: 0, 0: .1, 4: .13}
    for df, k in sink.items():
        K.key(b, f + df, loc=back - up * k * scale, rot=rot, scale=scale)
    K.fade(b, f + 14)
    # the arm and axe swing in the picture plane, onto the impact
    sh = back + rot @ V((.44, .02, .86)) * scale
    v = t - sh
    end = math.atan2(v.dot(CR), v.dot(CU)); reach = math.hypot(v.dot(CR), v.dot(CU))
    arm_len = .85 * scale
    size = max(scale * 1.1, reach - arm_len)
    ar = K._link(arm_me, 'ancestor_arm', hull=.02); K.vis(ar, f - 14, f + 24); K.key(ar, f - 14, alpha=1.0)
    a = K.axe(size, f - 14, f + 24, hull=.026)
    keys = {-14: (-.2, .42), -12: (-.5, .3), -10: (-.75, .2), -8: (-.95, .1), -6: (-1.1, .03), -4: (-1.22, 0), -2: (end - 1.1, 0), 0: (end, .1), 2: (end - .06, .12), 4: (end, .13)}
    for df, (th, k) in keys.items():
        d = CR * math.sin(th) + CU * math.cos(th)
        s0 = sh - up * k * scale
        rt = K.basis(CR * math.cos(th) - CU * math.sin(th), d)
        K.key(ar, f + df, loc=s0, rot=rt, scale=arm_len)
        K.key(a, f + df, loc=s0 + d * arm_len, rot=rt, scale=size)
    K.fade(ar, f + 14); K.fade(a, f + 14)
    K.impact(f, t, 1.05, word, wsize, big=True, panel=name)

def charge_up(K, a, b, root):
    """Coiling: lines rush in towards him, the page goes tense."""
    K.speedlines(a, dur=b - a, n=30, inner=.56)

def sky(K, F, root):
    f = F
    avatar(K, f, root, scale=2.1, word='KA-THOOM!', wsize=1.25, name="Ancestor's Fall", hit_ahead=2.4, rise_from=22)
    for i in range(5):
        K.axe  # the ring is left to Cataclysm: this one is about the single huge figure
    t = root(f)
    K.ring(f, t, 1, 5.5, dur=14, color=K.accent)
    K.puffs(f, t, n=10, R=3.6, size=.6, dur=18)

def rush(K, F, root, length=9.0):
    """The charge is the shape: a run of drawn smears along his path, then the whole line erupts behind him."""
    f = F - 2
    for i in range(4):
        fr = f + i * 2
        K.swoosh(fr, root(fr) + UP * .9, YAW - .5, YAW + .5, 1.0, 1.9, z=0)
    K.speedlines(f, dur=12)
    start = root(F - 6)
    for i in range(7):
        pos = start + FWD * (1 + i * 1.3) + V(((-1) ** i * .5, 0, 0))
        sz = 1.9 + i * .2; d = 12 + i
        o = K.axe(sz, F + d, F + d + 20, hull=.026)
        rot = K.basis(V(((-1) ** (i + 1), 0, 0)), V(((-1) ** i * .25, 0, 1)))
        for df, k in ((0, -.8), (2, -.08), (4, .04), (6, 0)):
            K.key(o, F + d + df, loc=pos + UP * sz * k, rot=rot, scale=sz)
        K.fade(o, F + d + 12)
        K.burst(F + d, pos + UP * .3, .55, dur=5)
        K.ring(F + d, pos, .25, 1.2, dur=8)
        K.cracks(F + d, pos, 1.1, dur=20, n=6)
        K.puffs(F + d, pos, n=3, R=.9, size=.38)
    K.word(F + 14, root(F + 14) + FWD * 2.6 + UP * 1.4, 'RRAAAH!', size=1.15, tilt=-.08, dur=22)
    K.panel(F + 15, 18, 'Spirit Stampede', big=True)

def cataclysm(K, F, root):
    f = F; c = root(f)
    K.speedlines(f - 22, dur=20, n=30, inner=.56)
    for i in range(6):
        a = i / 6 * 6.2832 + .3
        pos = c + FWD * 1.4 + V((math.sin(a) * 3.1, -math.cos(a) * 1.9, 0))
        guillotine(K, f - 4 + i * 2, root, size=3.0, offset=pos)
        K.burst(f - 4 + i * 2, pos + UP * .3, .75, dur=6)
        K.ring(f - 4 + i * 2, pos, .2, 1.4, dur=8)
        K.cracks(f - 4 + i * 2, pos, 1.4, dur=22, n=7)
        K.puffs(f - 4 + i * 2, pos, n=2, R=.8, size=.34)
    K.impact(f, c + FWD * 2.0, 1.05, 'KRRAKA-BOOM!', .95, big=True, panel='Cataclysm')
    K.ring(f + 2, c, 1, 6.5, dur=14, color=K.accent)

def run(K, clips, info, root_at):
    for key, (a, b) in clips.items():
        h = a + HIT[key]
        K.label(a - 6 if a > 6 else 0, b + 6, '%s  /  %s' % (info[key]['input'], info[key]['name']))
        if key == 'L1': echo(K, h, root_at, (-1.5, 1.5), 3.4, 'SHNK!')
        elif key == 'L2': echo(K, h, root_at, (1.75, -1.75), 3.8, 'KRANG!', 1.05)
        elif key == 'L3': cleave(K, h, root_at)
        elif key == 'LH': crown(K, h, root_at)
        elif key == 'LLH': rift(K, h, root_at)
        elif key == 'H': wheel(K, h, root_at, h - 5, h + 28)
        elif key == 'DL': tomahawk(K, h, root_at)
        elif key == 'LHH': spike(K, h, root_at)
        elif key == 'CH':
            charge_up(K, a + 9, a + 28, root_at)
            avatar(K, h, root_at)
        elif key == 'SKY': sky(K, h, root_at)
        elif key == 'RUSH': rush(K, h, root_at)
        elif key == 'AF': cataclysm(K, h, root_at)
