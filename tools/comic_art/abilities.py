# The shaman's abilities, hand-keyed. Exec'd inside the rig namespace (rig_comic.py), which supplies:
# tb, t_rest, t_q0, ALL_T, ORDER, ik, rot_to, Q, V, math, FPS, Yax.
#
# A pose is {bone: (rx, ry, rz)} degrees about world axes at rest, inherited down the chain. Front -Y, his left +X.
#   +X pitches up-pointing things forward. For an arm: -X raises it forward/up, +X lowers it. +Z turns to his left.
# Extra pose keys:
#   'hips': {'rot': .., 'loc': ..}   'L', 'R': foot/peg target offset in metres (feet stay planted by IK, so a crouch
#   is just hips loc). 'rm': forward travel so far, in metres (root motion, moves spirit and camera too).
#   'spin': whole-body yaw in degrees, not limited to the short way round.
#   A bone's value can also be a Quaternion, as arm() solves them.
# Keys: [(frame, ease, pose), ...]; ease: 'in' arrives fast (the swing), 'out' settles slowly, 'hold' snaps, 'smooth'.
# Timing rule: long enough anticipation to read, 2-4 frames to contact, a hold on contact, a slow settle.

def _ease(k, kind):
    if kind == 'in': return k * k * k
    if kind == 'out': return 1 - (1 - k) ** 3
    if kind == 'hold': return 0.0
    return k * k * (3 - 2 * k)

def _rq(rot):
    if isinstance(rot, Q): return rot   # a solved rotation (arm), not offsets
    e = [math.radians(a) for a in rot]
    return Q((1, 0, 0), e[0]) @ Q((0, 1, 0), e[1]) @ Q((0, 0, 1), e[2])

def keyed(name, length, keys, drag=0.0):
    N = length + 1
    keys = sorted(keys, key=lambda k: k[0])
    frames, track, RM = [], [], []
    a_len, b_len = {}, {}
    for side in 'lr':
        a_len[side], b_len[side] = tb['upperleg.' + side].length, tb['lowerleg.' + side].length
    rest_pos = {n: t_rest[n].to_translation() for n in ALL_T}
    for f in range(N):
        # bracket
        i0 = keys[0]; i1 = keys[-1]
        for j in range(len(keys) - 1):
            if keys[j][0] <= f <= keys[j + 1][0]:
                i0, i1 = keys[j], keys[j + 1]; break
        span = max(i1[0] - i0[0], 1)
        k = 0.0 if f <= i0[0] else (1.0 if f >= i1[0] else _ease((f - i0[0]) / span, i1[1]))
        pa, pb = i0[2], i1[2]
        def rot_of(n):
            def one(p):
                v = p.get(n)
                if v is None: return (0, 0, 0)
                return v.get('rot', (0, 0, 0)) if isinstance(v, dict) else v
            return _rq(one(pa)).slerp(_rq(one(pb)), k)
        def loc_of(n):
            def one(p):
                v = p.get(n)
                return V(v.get('loc', (0, 0, 0))) if isinstance(v, dict) else V()
            return one(pa).lerp(one(pb), k)
        def num(key):
            return pa.get(key, 0.0) + (pb.get(key, 0.0) - pa.get(key, 0.0)) * k
        def vec(key):
            return V(pa.get(key, (0, 0, 0))).lerp(V(pb.get(key, (0, 0, 0))), k)
        def dragged(n):
            # a hand with a 'drag.l' key: its axe is aimed from where the hand really is, whatever the torso did
            if n not in ('hand.l', 'hand.r') or 'drag.' + n[-1] not in pa: return None
            key = 'drag.' + n[-1]
            v = V(pa[key]).lerp(V(pb.get(key, pa[key])), k)
            return drag_rotation(n[-1], P[n], V(v[:3]), v[3])
        RM.append(num('rm'))
        spin = Q((0, 0, 1), math.radians(num('spin')))
        D, P, basis = {}, {}, {}
        D['root'] = spin; P['root'] = rest_pos['root']; basis['root'] = ((t_q0['root'].inverted() @ spin @ t_q0['root']).normalized(), V())
        for n in ALL_T:
            if n == 'root': continue
            pn = tb[n].parent.name
            off = rest_pos[n] - rest_pos[pn]
            P[n] = P[pn] + D[pn] @ off
            if n == 'hips':
                l = loc_of(n)
                P[n] = spin @ (rest_pos[n] + l)
                basis[n] = ((t_q0[n].inverted() @ rot_of(n) @ t_q0[n]).normalized(), t_q0[n].inverted() @ l)
                D[n] = spin @ rot_of(n)
            elif n.startswith('upperleg'):
                side = n[-1]
                lo = 'lowerleg.' + side
                ank0 = rest_pos[lo] + t_q0[lo] @ V((0, tb[lo].length, 0))
                tgt = spin @ (ank0 + vec('L' if side == 'l' else 'R'))
                knee0 = rest_pos[lo]; hip0 = rest_pos[n]
                pole0 = knee0 - hip0.lerp(ank0, .5)
                if pole0.length < .01: pole0 = V((0, -1, 0))
                knee, ankle = ik(P[n], tgt, a_len[side], b_len[side], D['hips'] @ pole0)
                Wup = rot_to(D[pn] @ t_q0[n], knee - P[n])
                basis[n] = ((t_q0[n].inverted() @ t_q0[pn] @ (D[pn] @ t_q0[pn]).inverted() @ Wup).normalized(), V())
                D[n] = Wup @ t_q0[n].inverted()
                D['__knee' + side] = knee; D['__ankle' + side] = ankle
            elif n.startswith('lowerleg'):
                side = n[-1]
                P[n] = D['__knee' + side]
                Wlo = rot_to(D[pn] @ t_q0[n], D['__ankle' + side] - P[n])
                basis[n] = ((t_q0[n].inverted() @ t_q0[pn] @ (D[pn] @ t_q0[pn]).inverted() @ Wlo).normalized(), V())
                D[n] = Wlo @ t_q0[n].inverted()
            elif n.startswith(('foot', 'toes')):
                if n.startswith('foot'): P[n] = D['__ankle' + n[-1]]
                W = spin @ t_q0[n]            # soles stay flat
                basis[n] = ((t_q0[n].inverted() @ t_q0[pn] @ (D[pn] @ t_q0[pn]).inverted() @ W).normalized(), V())
                D[n] = spin
            else:
                held = dragged(n)
                e = D[pn].inverted() @ held if held else rot_of(n)
                basis[n] = ((t_q0[n].inverted() @ e @ t_q0[n]).normalized(), V())
                D[n] = D[pn] @ e
        frames.append(basis)
        track.append((P['head'].copy(), P['chest'].copy(), {n: D[n] @ t_q0[n] for n in ('head', 'chest')}))
    # hair, beard and cape overshoot on their own spring
    dt = 1 / FPS
    n = len(frames)
    for bone, parent, src_i, gain, k_, c_, bias in (('mane', 'head', 0, .11, 62, 7, V((0, .35, .1))), ('beard', 'head', 0, .1, 70, 8, V((.05, .25, 0))), ('cape.1', 'chest', 1, .1, 46, 6.5, V((0, .35, .05))), ('cape.2', 'cape.1', 1, .14, 40, 5.5, V((0, .55, .15)))):
        lag, vel = V(), V()
        for i in range(n):
            a0 = track[min(i + 1, n - 1)][src_i] - track[i][src_i] * 2 + track[max(i - 1, 0)][src_i]
            vel += (-lag * k_ - vel * c_ - a0 * FPS * FPS * gain) * dt
            lag += vel * dt
            wq = track[i][2].get(parent, track[i][2]['chest']) @ t_q0[parent].inverted() @ t_q0[bone]
            local = wq.inverted() @ (lag + bias * drag)
            frames[i][bone] = (Yax.rotation_difference((Yax + local * 1.2).normalized()), V())
    return frames, RM

# ---------------------------------------------------------------- shared poses
READY = {'hips': {'rot': (6, 0, 0), 'loc': (0, 0, -.05)}, 'chest': (4, 0, 0), 'upperarm.l': (-22, 0, 8), 'lowerarm.l': (-30, 0, 0), 'upperarm.r': (10, 0, -6)}
def P(*ds, **kw):
    o = {}
    for d in ds: o.update(d)
    o.update(kw); return o

# ---------------------------------------------------------------- carrying the axes
# The rest pose is the hero pose: storm axe overhead, magma axe straight out. Offsets from it can't lose that, so
# these poses say where the hand goes and where the axe points, and solve the arm. Positions and directions are in
# his body's frame at rest (his left +X, his back +Y, up +Z). The torso carries the arms from there.
AXE_REST = {'r': (V((-.22, -.28, 1)), V((-1, -.3, .1))), 'l': (V((.06, -.8, .42)), V((1, 0, .1)))}

def _frame(along, edge):
    a = V(along).normalized(); e = V(edge); e = (e - a * e.dot(a)).normalized()
    return Matrix((a, e, a.cross(e))).transposed()

def arm(side, hand, along, edge, elbow):
    # hand: where the wrist goes. along: grip to axe head. edge: which way the blade faces. elbow: which way it bends.
    up, lo, wr = 'upperarm.' + side, 'lowerarm.' + side, 'wrist.' + side
    pos = lambda n: t_rest[n].to_translation()
    a, b = (pos(lo) - pos(up)).length, (pos(wr) - pos(lo)).length
    knee, wrist = ik(pos(up), V(hand), a, b, V(elbow))
    D_u = rot_to(t_q0[up], knee - pos(up)) @ t_q0[up].inverted()
    D_l = rot_to(D_u @ t_q0[lo], wrist - knee) @ t_q0[lo].inverted()
    D_h = (_frame(along, edge) @ _frame(*AXE_REST[side]).inverted()).to_quaternion()
    if side == 'l': return {up: D_u, lo: D_u.inverted() @ D_l}   # nothing in that hand: it hangs off the wrist
    return {up: D_u, lo: D_u.inverted() @ D_l, 'hand.' + side: D_l.inverted() @ D_h}

def _add(p, d, k=1.0):
    return tuple(V(p) + V(d) * k)

# Both axes are huge and he drags them. axe() in rig_comic.py builds the head on the handle at REACH and the blade's
# tip BLADE out from there.
AXE_SIZE = 1.75
REACH = .85 * AXE_SIZE
BLADE = .63 * AXE_SIZE
TIP_Z = .02   # rig floor is 0; the game's floor stones top out at .05, so it bites in

def drag_rotation(side, hand, head, tip_z):
    # Handle from the hand towards `head`; the blade leans out to his side and down just far enough to reach tip_z.
    along = (head - hand).normalized()
    top = hand + along * REACH
    sgn = 1 if side == 'l' else -1
    out = V((0, 0, 1)).cross(along).normalized() * -sgn
    if out.x * sgn < 0: out = -out
    down = V((0, 0, -1)); down = (down - along * down.dot(along)).normalized()
    s = max(min((top.z - tip_z) / (BLADE * max(-down.z, .2)), 1), -.3)
    edge = out * math.sqrt(1 - s * s) + down * s
    return (_frame(along, edge) @ _frame(*AXE_REST[side]).inverted()).to_quaternion()

# Hands low at his sides, arms drawn back with the weight; axe heads far behind, on the floor either side of his line.
DRAG_HAND = {'r': (-.64, .06, .88), 'l': (.64, .06, .88)}
DRAG_ELBOW = {'r': (-.7, .5, -.3), 'l': (.7, .5, -.3)}
DRAG_HEAD = {'r': (-1.05, 1.5, .68), 'l': (1.05, 1.5, .68)}   # high enough that the blade stands on its edge

def hauling(r_hand=(0, 0, 0), l_hand=(0, 0, 0), r_head=(0, 0, 0, 0), l_head=(0, 0, 0, 0)):
    # r_head, l_head: (x, y, z, tip lift) off the resting drag; the arms are solved to the hands, the hands to the heads
    o = {}
    for side, hand, head in (('r', r_hand, r_head), ('l', l_hand, l_head)):
        for bone, q in arm(side, _add(DRAG_HAND[side], hand), V((0, 1, 0)), V((1, 0, 0)), DRAG_ELBOW[side]).items():
            if not bone.startswith('hand'): o[bone] = q
        at = V(DRAG_HEAD[side]) + V(head[:3])
        if side == 'r': o['drag.r'] = (at.x, at.y, at.z, TIP_Z + head[3])
    return o

# Low guard, axes out to the sides, after a fight.
GUARD_R = dict(hand=(-.76, -.2, .94), along=(-.6, .4, .7), edge=(-.8, -.6, 0), elbow=(-.8, .35, -.45))
GUARD_L = dict(hand=(.74, -.3, .86), along=(.75, .35, .42), edge=(.1, -1, .3), elbow=(.8, .35, -.45))
# Wound up, both axes drawn back.
COILED_R = dict(hand=(-.66, .08, 1.06), along=(-.3, .8, .52), edge=(-.5, .2, .9), elbow=(-.75, .5, -.3))
COILED_L = dict(hand=(.66, .08, .98), along=(.3, .88, .36), edge=(.5, .2, .9), elbow=(.75, .5, -.3))
# Thrown back, axes streaming behind.
STREAM_R = dict(hand=(-.72, .22, 1.14), along=(-.3, .94, .1), edge=(-.5, 0, 1), elbow=(-.6, .6, -.2))
STREAM_L = dict(hand=(.72, .22, 1.04), along=(.3, .94, .06), edge=(.5, 0, 1), elbow=(.6, .6, -.2))
# Arms flung wide from a blow or in the air.
FLUNG_R = dict(hand=(-.86, -.1, 1.14), along=(-.75, .34, .5), edge=(-.8, -.6, 0), elbow=(-.6, .4, -.7))
FLUNG_L = dict(hand=(.86, -.08, 1.06), along=(.8, .25, .4), edge=(.2, -1, .2), elbow=(.6, .4, -.7))

def nudged(spec, hand=(0, 0, 0), along=(0, 0, 0)):
    return dict(spec, hand=_add(spec['hand'], hand), along=_add(spec['along'], along))

def carry(r, l):
    o = arm('r', **r); o.update(arm('l', **l)); return o

STAND_L = V((-.05, 0, 0))
STAND_R = V((.07, .26, 0))
GUARD_POSE = dict(carry(GUARD_R, GUARD_L), hips={'rot': (9, 0, 6), 'loc': (0, -.02, -.14)}, chest=(7, 0, -6), head=(-8, 0, 4), L=(-.02, .02, 0), R=(.06, .24, 0))
ARM_BONES = ('upperarm.l', 'lowerarm.l', 'wrist.l', 'hand.l', 'upperarm.r', 'lowerarm.r', 'wrist.r', 'hand.r')

def into_guard(frames, head=4, tail=.25):
    # A move's first and last frames carry the hero-pose arms; ease them from and to the guard so a move starts and
    # ends with the axes where the stances hold them. Hits are all before the tail (comic_check holds the timing).
    guard = keyed('_guard', 0, [(0, 'smooth', GUARD_POSE)])[0][0]
    n = len(frames)
    t0 = int(n * (1 - tail))
    for i, fr in enumerate(frames):
        w = max(1 - i / head, (i - t0) / max(n - 1 - t0, 1))
        if w <= 0: continue
        w = w * w * (3 - 2 * w)
        for b in ARM_BONES:
            fr[b] = (fr[b][0].slerp(guard[b][0], w), fr[b][1])

AB = {}
INFO = {}
def ability(key, name, input_, word, cast, length, keys):
    frames, rm = keyed('Ab_' + key, length, keys)
    into_guard(frames)
    AB['Ab_' + key] = (frames, rm)
    INFO[key] = dict(name=name, input=input_, word=word, cast=cast, length=length)

# L: the storm axe, right to left, with a spectral echo a beat later
ability('L1', 'Light 1', 'L', 'SHNK!', 'echo', 24, [
    (0, 'smooth', READY),
    (5, 'out', {'hips': {'rot': (4, 0, -14), 'loc': (0, .04, -.08)}, 'chest': (-4, 0, -34), 'head': (0, 0, 22), 'upperarm.r': (-34, 0, -52), 'lowerarm.r': (-12, 0, -28), 'upperarm.l': (-30, 0, 20)}),
    (8, 'in', {'rm': -.28, 'hips': {'rot': (10, 0, 16), 'loc': (0, -.06, -.14)}, 'chest': (10, 0, 36), 'head': (-4, 0, -24), 'upperarm.r': (22, 0, 76), 'lowerarm.r': (6, 0, 44), 'upperarm.l': (14, 0, -6), 'L': (0, .06, 0), 'R': (0, -.1, 0)}),
    (12, 'out', {'rm': -.32, 'hips': {'rot': (10, 0, 18), 'loc': (0, -.06, -.14)}, 'chest': (12, 0, 40), 'head': (-4, 0, -26), 'upperarm.r': (26, 0, 84), 'lowerarm.r': (8, 0, 50), 'upperarm.l': (16, 0, -6), 'L': (0, .06, 0), 'R': (0, -.1, 0)}),
    (24, 'smooth', P(READY, rm=-.32)),
])
# L L: the axe comes back the other way, a backhand across him, wider, a little hop onto it. Only the arms are solved here.
ARM_KEY = ('upperarm.', 'lowerarm.', 'wrist.', 'hand.')
LOOSE_L = dict(hand=(.6, .02, .88), along=(0, 0, -1), edge=(1, 0, 0), elbow=(.7, .3, -.4))
BACK_R = {5: dict(hand=(.03, -.6, 1.24), along=(.85, -.45, .25), edge=(-.45, -.85, .1), elbow=(-.5, -.2, -.8)),
          8: dict(hand=(-.1, -.62, 1.2), along=(.6, -.8, .1), edge=(-.8, -.6, 0), elbow=(-.6, -.1, -.8)),
          11: dict(hand=(-.42, -.66, 1.12), along=(-.3, -.95, .02), edge=(-.95, .3, 0), elbow=(-.7, .1, -.7)),
          15: dict(hand=(-.8, -.35, 1.1), along=(-.9, -.42, .05), edge=(-.42, .9, 0), elbow=(-.6, .4, -.7))}
def backhand(keys):
    out = []
    for f, ease_, pose in keys:
        if f in BACK_R:
            pose = {k: v for k, v in pose.items() if not k.startswith(ARM_KEY)}
            pose.update(carry(BACK_R[f], LOOSE_L))
        out.append((f, ease_, pose))
    return out
# L L: the arm draws out into the spear and drives it straight ahead. (The axe's backhand was here: see git history in tools/comic_art.)
THRUST_R = {5: dict(hand=(-.66, .28, 1.14), along=(.1, -.98, .12), edge=(-1, 0, 0), elbow=(-.7, .5, -.3)),
            9: dict(hand=(-.36, -.62, 1.14), along=(.04, -1, .02), edge=(-1, 0, 0), elbow=(-.7, .05, -.6)),
            14: dict(hand=(-.36, -.6, 1.12), along=(.04, -1, 0), edge=(-1, 0, 0), elbow=(-.7, .05, -.6))}
BRACE_L = dict(hand=(.62, .22, .96), along=(0, 0, -1), edge=(1, 0, 0), elbow=(.7, .4, -.3))
def thrust(keys, table):
    out = []
    for f, ease_, pose in keys:
        if f in table:
            pose = {k: v for k, v in pose.items() if not k.startswith(ARM_KEY)}
            pose.update(carry(table[f], BRACE_L))
        out.append((f, ease_, pose))
    return out
ability('L2', 'Light 2', 'L L', 'SHIING!', 'echo', 26, thrust([
    (0, 'smooth', READY),
    (5, 'out', {'hips': {'rot': (0, 0, -12), 'loc': (0, .08, -.12)}, 'chest': (-6, 0, -22), 'head': (-2, 0, 18)}),
    (9, 'in', {'rm': -.5, 'hips': {'rot': (10, 0, 4), 'loc': (0, -.14, -.2)}, 'chest': (12, 0, 6), 'head': (-8, 0, -6), 'L': (0, .14, 0), 'R': (0, -.16, 0)}),
    (14, 'out', {'rm': -.55, 'hips': {'rot': (11, 0, 5), 'loc': (0, -.14, -.2)}, 'chest': (13, 0, 7), 'head': (-8, 0, -6), 'L': (0, .14, 0), 'R': (0, -.16, 0)}),
    (26, 'smooth', P(READY, rm=-.55)),
], THRUST_R))
# L L L Triple Chop: leaps, both axes over his head, comes down hard. Two colossal axes slam into a V
CHOP_TOP = {'chest': (-24, 0, 0), 'head': (20, 0, 0), 'upperarm.r': (-62, 0, -12), 'lowerarm.r': (-26, 0, 0), 'upperarm.l': (-130, 0, 8), 'lowerarm.l': (-22, 0, 0)}
CHOP_DOWN = {'chest': (30, 0, 0), 'head': (-22, 0, 0), 'upperarm.r': (-14, 0, 14), 'lowerarm.r': (0, 0, 0), 'hand.r': (20, 0, 0), 'upperarm.l': (-100, 0, -14), 'lowerarm.l': (-10, 0, 0), 'hand.l': (6, 0, 0)}
ability('L3', 'Triple Chop', 'L L L', 'KRAK!', 'cleave', 44, [
    (0, 'smooth', READY),
    (7, 'out', P({'hips': {'rot': (22, 0, 0), 'loc': (0, .1, -.24)}, 'chest': (24, 0, 0), 'head': (-24, 0, 0), 'upperarm.r': (22, 0, -24), 'upperarm.l': (-22, 0, 24)})),
    (12, 'smooth', P(CHOP_TOP, {'rm': -.5, 'hips': {'rot': (-12, 0, 0), 'loc': (0, 0, .62)}, 'L': (0, .05, .5), 'R': (0, .1, .36)})),
    (15, 'smooth', P(CHOP_TOP, {'rm': -.9, 'hips': {'rot': (-16, 0, 0), 'loc': (0, 0, .78)}, 'L': (0, .08, .6), 'R': (0, .12, .46)})),
    (18, 'in', P(CHOP_DOWN, {'rm': -1.3, 'hips': {'rot': (24, 0, 0), 'loc': (0, -.1, -.26)}, 'L': (0, .14, 0), 'R': (0, -.16, 0)})),
    (26, 'out', P(CHOP_DOWN, {'rm': -1.3, 'hips': {'rot': (26, 0, 0), 'loc': (0, -.1, -.28)}, 'L': (0, .14, 0), 'R': (0, -.16, 0)})),
    (44, 'smooth', P(READY, rm=-1.3)),
])
# L H Launcher: drops low, the magma fist swings up through everything. Three axes burst from the floor
ability('LH', 'Launcher', 'L H', 'FWOOM!', 'crown', 40, [
    (0, 'smooth', READY),
    (8, 'out', {'hips': {'rot': (26, 0, 12), 'loc': (0, .08, -.3)}, 'chest': (26, 0, 18), 'head': (-30, 0, -8), 'upperarm.l': (42, 0, 20), 'lowerarm.l': (-8, 0, 0), 'upperarm.r': (22, 0, -30), 'L': (.04, .1, 0), 'R': (-.04, -.1, 0)}),
    (12, 'in', {'rm': -.45, 'hips': {'rot': (-14, 0, -8), 'loc': (0, -.04, .34)}, 'chest': (-28, 0, -14), 'head': (24, 0, 6), 'upperarm.l': (-126, 0, -6), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (10, 0, -28), 'L': (0, -.12, .02), 'R': (-.02, .08, .3)}),
    (18, 'out', {'rm': -.5, 'hips': {'rot': (-16, 0, -8), 'loc': (0, -.04, .4)}, 'chest': (-30, 0, -14), 'head': (28, 0, 6), 'upperarm.l': (-128, 0, -6), 'lowerarm.l': (-8, 0, 0), 'upperarm.r': (14, 0, -28), 'L': (0, -.12, .06), 'R': (-.02, .08, .32)}),
    (40, 'smooth', P(READY, rm=-.5)),
])
# L L H Ground Breaker: hops, the magma fist punches the floor, a wave of axes runs ahead
ability('LLH', 'Ground Breaker', 'L L H', 'THOOOM!', 'rift', 46, [
    (0, 'smooth', READY),
    (8, 'out', P(CHOP_TOP, {'hips': {'rot': (-12, 0, 0), 'loc': (0, .06, .48)}, 'L': (0, .05, .38), 'R': (0, .1, .3)})),
    (13, 'smooth', P(CHOP_TOP, {'rm': -.5, 'hips': {'rot': (-18, 0, 0), 'loc': (0, 0, .62)}, 'L': (0, .05, .46), 'R': (0, .1, .36)})),
    (16, 'in', {'rm': -.85, 'hips': {'rot': (30, 0, 0), 'loc': (.04, -.1, -.34)}, 'chest': (38, 0, -10), 'head': (-30, 0, 8), 'upperarm.l': (-70, 0, -8), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (-80, 0, -40), 'lowerarm.r': (-20, 0, 0), 'L': (.08, .16, 0), 'R': (-.06, -.14, 0)}),
    (26, 'out', {'rm': -.85, 'hips': {'rot': (32, 0, 0), 'loc': (.04, -.1, -.36)}, 'chest': (40, 0, -10), 'head': (-32, 0, 8), 'upperarm.l': (-68, 0, -8), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (-84, 0, -44), 'lowerarm.r': (-22, 0, 0), 'L': (.08, .16, 0), 'R': (-.06, -.14, 0)}),
    (46, 'smooth', P(READY, rm=-.85)),
])
# H Whirlwind: arms flung wide, a flat wheel of axes grinds round him
SPREAD = {'upperarm.r': (-4, 0, -34), 'lowerarm.r': (6, 0, -8), 'upperarm.l': (-92, 0, 62), 'lowerarm.l': (-4, 0, 16), 'chest': (-8, 0, 0), 'head': (10, 0, 0)}
ability('H', 'Whirlwind', 'H', 'VRRRSH!', 'wheel', 50, [
    (0, 'smooth', READY),
    (7, 'out', {'spin': 40, 'hips': {'rot': (10, 0, 0), 'loc': (0, 0, -.22)}, 'chest': (10, 0, 30), 'head': (0, 0, -22), 'upperarm.l': (-40, 0, 80), 'upperarm.r': (10, 0, 30)}),
    (12, 'in', P(SPREAD, {'spin': -160, 'hips': {'loc': (0, 0, .1)}, 'R': (0, 0, .06)})),
    (26, 'smooth', P(SPREAD, {'spin': -700, 'hips': {'loc': (0, 0, .28)}, 'L': (0, 0, .16), 'R': (0, 0, .2)})),
    (36, 'smooth', P(SPREAD, {'spin': -1080, 'hips': {'loc': (0, 0, .1)}, 'R': (0, 0, .04)})),
    (39, 'in', {'spin': -1160, 'hips': {'rot': (18, 0, 0), 'loc': (0, -.04, -.26)}, 'chest': (24, 0, 0), 'head': (-20, 0, 0), 'upperarm.r': (20, 0, -30), 'upperarm.l': (-30, 0, 36), 'L': (.05, .05, 0), 'R': (-.05, -.05, 0)}),
    (50, 'smooth', P(READY, spin=-1080)),
])
# Dash L Tomahawk: skids in, hurls the storm axe, catches it on the way back
DASH_R = {6: dict(hand=(-.66, .3, 1.1), along=(.08, -.98, .1), edge=(-1, 0, 0), elbow=(-.7, .5, -.3)),
          9: dict(hand=(-.36, -.62, 1.12), along=(.03, -1, .3), edge=(-1, 0, 0), elbow=(-.7, .05, -.6)),
          14: dict(hand=(-.36, -.6, 1.12), along=(.03, -1, .3), edge=(-1, 0, 0), elbow=(-.7, .05, -.6))}
ability('DL', 'Dash Stab', 'Dash > L', 'SHIIING!', 'tomahawk', 48, thrust([
    (0, 'smooth', P(READY, rm=0)),
    (6, 'smooth', {'rm': -1.5, 'hips': {'rot': (24, 0, 0), 'loc': (0, 0, -.2)}, 'chest': (20, 0, -18), 'head': (-24, 0, 14), 'upperarm.r': (-150, 0, -30), 'lowerarm.r': (-46, 0, 0), 'upperarm.l': (-40, 0, 44), 'L': (0, .2, 0), 'R': (0, -.2, 0)}),
    (9, 'in', {'rm': -1.75, 'hips': {'rot': (14, 0, 0), 'loc': (0, -.1, -.26)}, 'chest': (10, 0, 5), 'head': (-12, 0, -4), 'upperarm.r': (-50, 0, 30), 'lowerarm.r': (6, 0, 0), 'upperarm.l': (-30, 0, 36), 'L': (0, .2, 0), 'R': (0, -.26, 0)}),
    (14, 'out', {'rm': -1.75, 'hips': {'rot': (15, 0, 0), 'loc': (0, -.1, -.26)}, 'chest': (11, 0, 6), 'head': (-12, 0, -4), 'upperarm.r': (-44, 0, 34), 'lowerarm.r': (6, 0, 0), 'upperarm.l': (-30, 0, 36), 'L': (0, .2, 0), 'R': (0, -.26, 0)}),
    (38, 'smooth', {'rm': -1.75, 'hips': {'rot': (6, 0, 0), 'loc': (0, 0, -.08)}, 'chest': (0, 0, -10), 'upperarm.r': (-60, 0, -20), 'lowerarm.r': (-30, 0, 0)}),
    (41, 'in', {'rm': -1.75, 'hips': {'rot': (0, 0, 0), 'loc': (0, .08, -.1)}, 'chest': (-10, 0, -16), 'upperarm.r': (-80, 0, -40), 'lowerarm.r': (-46, 0, 0)}),
    (48, 'smooth', P(READY, rm=-1.75)),
], DASH_R))
# L H H Spike: flung high, points at the target, a colossal axe follows his dive down
ability('LHH', 'Spike', 'L H H', 'CHUNK!', 'guillotine', 44, [
    (0, 'smooth', READY),
    (6, 'out', {'hips': {'rot': (18, 0, 0), 'loc': (0, .05, -.26)}, 'chest': (20, 0, 0), 'head': (-16, 0, 0), 'upperarm.r': (18, 0, -20), 'upperarm.l': (-14, 0, 20)}),
    (12, 'smooth', {'rm': -.4, 'hips': {'rot': (-10, 0, 0), 'loc': (0, 0, 1.05)}, 'chest': (-14, 0, 8), 'head': (12, 0, 0), 'upperarm.r': (-78, 0, -8), 'lowerarm.r': (-8, 0, 0), 'upperarm.l': (20, 0, 26), 'L': (0, .1, .9), 'R': (0, .14, .78)}),
    (18, 'smooth', {'rm': -.7, 'hips': {'rot': (-14, 0, 0), 'loc': (0, 0, 1.25)}, 'chest': (-18, 0, 10), 'head': (16, 0, 0), 'upperarm.r': (-80, 0, -8), 'lowerarm.r': (-6, 0, 0), 'upperarm.l': (24, 0, 26), 'L': (0, .14, 1.08), 'R': (0, .18, .96)}),
    (21, 'in', P(CHOP_DOWN, {'rm': -1.1, 'hips': {'rot': (26, 0, 0), 'loc': (0, -.1, -.28)}, 'L': (0, .14, 0), 'R': (0, -.16, 0)})),
    (28, 'out', P(CHOP_DOWN, {'rm': -1.1, 'hips': {'rot': (28, 0, 0), 'loc': (0, -.1, -.3)}, 'L': (0, .14, 0), 'R': (0, -.16, 0)})),
    (44, 'smooth', P(READY, rm=-1.1)),
])
# hold H Charged Slam: coils, shaking, spirit gathers; leaps; a towering ancestor brings its axe down with him
COIL = {'hips': {'rot': (28, 0, 8), 'loc': (0, .1, -.34)}, 'chest': (30, 0, 20), 'head': (-26, 0, -10), 'upperarm.l': (46, 0, 36), 'lowerarm.l': (-20, 0, 0), 'upperarm.r': (46, 0, -40), 'lowerarm.r': (-24, 0, 0)}
def shake(p, dx):
    o = dict(p); h = dict(o['hips']); l = list(h['loc']); l[0] += dx; h['loc'] = tuple(l); o['hips'] = h; return o
ability('CH', 'Charged Slam', 'hold H', 'BOOOOM!', 'avatar', 66, [
    (0, 'smooth', READY),
    (9, 'out', COIL),
    (12, 'smooth', shake(COIL, .012)), (15, 'smooth', shake(COIL, -.014)), (18, 'smooth', shake(COIL, .018)), (21, 'smooth', shake(COIL, -.02)), (24, 'smooth', shake(COIL, .024)),
    (30, 'smooth', P(CHOP_TOP, {'rm': -.7, 'hips': {'rot': (-16, 0, 0), 'loc': (0, 0, .95)}, 'L': (0, .1, .75), 'R': (0, .14, .62)})),
    (34, 'smooth', P(CHOP_TOP, {'rm': -1.1, 'hips': {'rot': (-20, 0, 0), 'loc': (0, 0, 1.08)}, 'L': (0, .12, .86), 'R': (0, .16, .72)})),
    (37, 'in', P(CHOP_DOWN, {'rm': -1.6, 'hips': {'rot': (28, 0, 0), 'loc': (0, -.1, -.32)}, 'L': (0, .18, 0), 'R': (0, -.2, 0)})),
    (47, 'out', P(CHOP_DOWN, {'rm': -1.6, 'hips': {'rot': (30, 0, 0), 'loc': (0, -.1, -.34)}, 'L': (0, .18, 0), 'R': (0, -.2, 0)})),
    (66, 'smooth', P(READY, rm=-1.6)),
])
# Awakened L H H, Ancestor's Fall: a huge leap, a comet down, a 5x ancestor swings behind him
ability('SKY', "Ancestor's Fall", 'L H H (Awakened)', 'KA-THOOM!', 'sky', 60, [
    (0, 'smooth', READY),
    (10, 'out', {'hips': {'rot': (24, 0, 0), 'loc': (0, .1, -.32)}, 'chest': (34, 0, 0), 'head': (-36, 0, 0), 'upperarm.r': (26, 0, -30), 'upperarm.l': (-36, 0, 30)}),
    (18, 'smooth', P(CHOP_TOP, {'rm': -1.2, 'hips': {'rot': (-20, 0, 0), 'loc': (0, 0, 2.4)}, 'L': (0, .14, 2.2), 'R': (0, .2, 2.05)})),
    (28, 'smooth', P(CHOP_TOP, {'rm': -2.2, 'hips': {'rot': (-30, 0, 0), 'loc': (0, 0, 3.1)}, 'L': (0, .2, 2.85), 'R': (0, .26, 2.72)})),
    (32, 'in', P(CHOP_DOWN, {'rm': -3, 'hips': {'rot': (30, 0, 0), 'loc': (0, -.1, -.34)}, 'L': (0, .2, 0), 'R': (0, -.22, 0)})),
    (42, 'out', P(CHOP_DOWN, {'rm': -3, 'hips': {'rot': (32, 0, 0), 'loc': (0, -.1, -.36)}, 'L': (0, .2, 0), 'R': (0, -.22, 0)})),
    (60, 'smooth', P(READY, rm=-3)),
])
# Awakened Dash L H, Spirit Stampede: shoulder down, through the whole line; it erupts behind him
RAM = {'hips': {'rot': (34, 0, 0), 'loc': (0, -.1, -.24)}, 'chest': (34, 0, 14), 'head': (-44, 0, -6), 'upperarm.l': (-100, 0, 8), 'lowerarm.l': (-20, 0, 0), 'upperarm.r': (-14, 0, -44), 'lowerarm.r': (-30, 0, 0)}
ability('RUSH', 'Spirit Stampede', 'Dash L H (Awakened)', 'RRAAAH!', 'rush', 54, [
    (0, 'smooth', READY),
    (6, 'out', P(RAM, {'hips': {'rot': (40, 0, 0), 'loc': (0, .14, -.34)}, 'L': (0, .2, 0), 'R': (0, .2, 0)})),
    (9, 'in', P(RAM, {'rm': -3, 'L': (0, .3, .1), 'R': (0, -.3, .04)})),
    (12, 'smooth', P(RAM, {'rm': -6, 'L': (0, -.3, .04), 'R': (0, .3, .1)})),
    (15, 'smooth', P(RAM, {'rm': -9, 'L': (0, .3, .1), 'R': (0, -.3, .04)})),
    (20, 'out', {'rm': -9.6, 'hips': {'rot': (-8, 0, 0), 'loc': (0, .16, -.3)}, 'chest': (-16, 0, -10), 'head': (10, 0, 8), 'upperarm.l': (-30, 0, 40), 'upperarm.r': (-30, 0, -44), 'L': (.08, -.3, 0), 'R': (-.1, -.1, 0)}),
    (54, 'smooth', P(READY, rm=-9.6)),
])
# Awakened L L L H, Cataclysm: arms to the sky, the ring of axes falls round him as he punches the floor
ability('AF', 'Cataclysm', 'L L L H (Awakened)', 'KRRAKA-BOOM!', 'cataclysm', 78, [
    (0, 'smooth', READY),
    (10, 'out', {'hips': {'rot': (20, 0, 0), 'loc': (0, .06, -.28)}, 'chest': (34, 0, 0), 'head': (-30, 0, 0), 'upperarm.l': (20, 0, -34), 'lowerarm.l': (-60, 0, 0), 'upperarm.r': (50, 0, 30), 'lowerarm.r': (-60, 0, 0)}),
    (20, 'smooth', {'hips': {'rot': (-16, 0, 0), 'loc': (0, 0, .26)}, 'chest': (-30, 0, 0), 'head': (34, 0, 0), 'upperarm.l': (-125, 0, 30), 'lowerarm.l': (-6, 0, 0), 'upperarm.r': (-50, 0, -24), 'lowerarm.r': (-8, 0, 0), 'R': (0, 0, .1)}),
    (36, 'smooth', {'hips': {'rot': (-20, 0, 0), 'loc': (0, 0, .34)}, 'chest': (-34, 0, 0), 'head': (38, 0, 0), 'upperarm.l': (-126, 0, 30), 'lowerarm.l': (-4, 0, 0), 'upperarm.r': (-52, 0, -24), 'lowerarm.r': (-6, 0, 0), 'R': (0, 0, .14)}),
    (40, 'in', {'hips': {'rot': (34, 0, 0), 'loc': (0, -.06, -.4)}, 'chest': (40, 0, 0), 'head': (-34, 0, 0), 'upperarm.l': (-80, 0, -8), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (-46, 0, 30), 'lowerarm.r': (-4, 0, 0), 'L': (.08, .14, 0), 'R': (-.08, -.12, 0)}),
    (54, 'out', {'hips': {'rot': (36, 0, 0), 'loc': (0, -.06, -.42)}, 'chest': (42, 0, 0), 'head': (-36, 0, 0), 'upperarm.l': (-82, 0, -8), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (-44, 0, 30), 'lowerarm.r': (-4, 0, 0), 'L': (.08, .14, 0), 'R': (-.08, -.12, 0)}),
    (78, 'smooth', READY),
])

# ---------------------------------------------------------------- the moves that had no clip of their own
# Hit frames here match what MOVES' spacing works out to on these lengths at 24 fps (comic_look.retime keeps time after
# the first hit), so the later cuts land on the later hits. Both axes take turns; each cut is the weight of the last
# thrown the other way, not a fresh swing.
CUT_R = {'hips': {'rot': (8, 0, 14), 'loc': (0, -.04, -.12)}, 'chest': (8, 0, 32), 'head': (-4, 0, -22), 'upperarm.r': (22, 0, 72), 'lowerarm.r': (6, 0, 42), 'upperarm.l': (-30, 0, 20)}
CUT_L = {'hips': {'rot': (8, 0, -14), 'loc': (0, -.04, -.12)}, 'chest': (8, 0, -34), 'head': (-4, 0, 22), 'upperarm.l': (-74, 0, -66), 'lowerarm.l': (-4, 0, -32), 'upperarm.r': (-12, 0, 18)}
WIND_R = {'hips': {'rot': (4, 0, -12), 'loc': (0, .04, -.1)}, 'chest': (-4, 0, -30), 'head': (0, 0, 20), 'upperarm.r': (-34, 0, -48), 'lowerarm.r': (-12, 0, -26), 'upperarm.l': (-26, 0, 20)}
WIND_L = {'hips': {'rot': (0, 0, 14), 'loc': (0, .03, -.1)}, 'chest': (-6, 0, 32), 'head': (0, 0, -22), 'upperarm.l': (-106, 0, 50), 'lowerarm.l': (-14, 0, 18), 'upperarm.r': (10, 0, -24)}
STEP_A = {'L': (0, .08, 0), 'R': (0, -.08, 0)}
STEP_B = {'L': (0, -.08, 0), 'R': (0, .08, 0)}
# Off the floor: knees tucked, hips up, as Hero_Jump_Idle hangs.
AIR = {'L': (-.05, .08, .26), 'R': (.07, .12, .44)}
def aloft(p, rot=(3, 0, 0)):
    h = p.get('hips', {})
    return P(p, AIR, hips={'rot': h.get('rot', rot), 'loc': (0, 0, .04)})
AIR_READY = aloft(READY)

# L L, pause, L Flurry: five quick cuts, right, left, right, left, then both together
ability('LPL', 'Flurry', 'L L, pause, L', 'SHK-SHK-SHK!', 'tomahawk', 29, [
    (0, 'smooth', READY),
    (4, 'out', P(WIND_R, STEP_A)),
    (6, 'in', P(CUT_R, STEP_B)),
    (9, 'in', P(CUT_L, STEP_A)),
    (12, 'in', P(CUT_R, STEP_B)),
    (14, 'in', P(CUT_L, STEP_A)),
    (17, 'in', P(CHOP_DOWN, {'hips': {'rot': (20, 0, 0), 'loc': (0, -.08, -.22)}, 'L': (0, .1, 0), 'R': (0, -.12, 0)})),
    (22, 'out', P(CHOP_DOWN, {'hips': {'rot': (22, 0, 0), 'loc': (0, -.08, -.24)}, 'L': (0, .1, 0), 'R': (0, -.12, 0)})),
    (29, 'smooth', READY),
])
# Dash H Cyclone: drops low and goes round twice, arms wide, the axes dragging the body after them
ability('DH', 'Cyclone', 'Dash > H', 'VWOOM!', 'wheel', 19, [
    (0, 'smooth', READY),
    (3, 'out', {'spin': 30, 'hips': {'rot': (12, 0, 0), 'loc': (0, 0, -.24)}, 'chest': (12, 0, 26), 'head': (0, 0, -20), 'upperarm.l': (-40, 0, 76), 'upperarm.r': (10, 0, 28), 'L': (.06, 0, 0), 'R': (-.06, 0, 0)}),
    (5, 'in', P(SPREAD, {'spin': -90, 'hips': {'rot': (8, 0, 0), 'loc': (0, 0, -.2)}, 'L': (.06, 0, 0), 'R': (-.06, 0, 0)})),
    (15, 'smooth', P(SPREAD, {'spin': -700, 'hips': {'rot': (8, 0, 0), 'loc': (0, 0, -.2)}, 'L': (.06, 0, 0), 'R': (-.06, 0, 0)})),
    (19, 'smooth', P(READY, spin=-720)),
])
# L H L Air Slash: one hard cut hanging in the air
ability('AL1', 'Air Slash', 'L H L', 'SHNK!', 'echo', 23, [
    (0, 'smooth', AIR_READY),
    (5, 'out', aloft(WIND_R)),
    (8, 'in', aloft(CUT_R)),
    (12, 'out', aloft(CUT_R)),
    (23, 'smooth', AIR_READY),
])
# L H L L Sky Rend: back the other way with the magma axe, and the storm axe straight after it
ability('AL2', 'Sky Rend', 'L H L L', 'KRANG!', 'echo', 25, [
    (0, 'smooth', aloft(CUT_R)),
    (4, 'out', aloft(WIND_L)),
    (7, 'in', aloft(CUT_L)),
    (11, 'in', aloft(CUT_R)),
    (15, 'out', aloft(CUT_R)),
    (25, 'smooth', AIR_READY),
])
# L H L L H Updraft: the gale takes his feet; he opens his arms and it turns him
GALE = {'hips': {'rot': (-6, 0, 0), 'loc': (0, 0, .1)}, 'L': (-.05, .14, .1), 'R': (.07, .22, .2)}
ability('AH', 'Updraft', 'L H L L H', 'FWOOSH!', 'wheel', 43, [
    (0, 'smooth', AIR_READY),
    (5, 'out', aloft(dict(WIND_R, spin=30))),
    (8, 'in', P(SPREAD, GALE, spin=-140)),
    (18, 'smooth', P(SPREAD, GALE, spin=-620)),
    (28, 'smooth', P(SPREAD, GALE, spin=-980)),
    (34, 'smooth', aloft(dict(READY, spin=-1060))),
    (43, 'smooth', P(AIR_READY, spin=-1080)),
])
# L H L L H L Gale Waltz: three cuts on one turn
ability('AL3', 'Gale Waltz', 'L H L L H L', 'SHK-SHK!', 'echo', 27, [
    (0, 'smooth', AIR_READY),
    (3, 'out', aloft(dict(WIND_R, spin=20))),
    (6, 'in', aloft(dict(CUT_R, spin=-90))),
    (10, 'in', aloft(dict(CUT_L, spin=-220))),
    (14, 'in', aloft(dict(CUT_R, spin=-340))),
    (19, 'out', aloft(dict(CUT_R, spin=-360))),
    (27, 'smooth', P(AIR_READY, spin=-360)),
])

# ---------------------------------------------------------------- locomotion, four directions off one cycle
# The game turns him to the mouse and picks a clip from which way he travels relative to that, so a sidestep has
# to read as a sidestep. The retargeted Running_A keeps the hero pose's arms out wide and doesn't swing them.
# Rest stance is staggered and wide, the left ankle at (.262, 0) and the peg at (-.262, -.4): BASE_* brings both
# under the hips. travel is in his own axes, as a pose's: (his left, his back).
RUN_T = 16
LOPSIDED = 6   # degrees he leans away from the axe he drags, in everything he does on his feet
BASE_L = V((-.1, .0, 0))
BASE_R = V((.1, .4, 0))

def _foot(phase, reach, lift):
    # phase 0 = front of the stride; the first half is on the floor going back, the second is the swing forward
    a = phase * 2 * math.pi
    return reach * math.cos(a), (lift * math.sin((phase - .5) * 2 * math.pi) if phase > .5 else 0.0)

def run_pose(phase, travel, reach, lift, lean, width=0.0):
    tr = V((travel[0], travel[1], 0))
    sl, zl = _foot(phase, reach, lift)
    sr, zr = _foot((phase + .5) % 1, reach, lift)
    wide = V((width, 0, 0))
    swing = math.cos(phase * 2 * math.pi)   # +1: left foot leading along travel
    two = math.cos(phase * 4 * math.pi)     # low at each contact, high in the air
    forward = -travel[1]                    # +1 running forward, -1 back
    side = travel[0]
    pitch, roll = lean * forward, lean * side
    twist = swing * forward                 # shoulders counter the hips on a straight run only
    pump = swing * (1 if forward >= 0 else -1) * (abs(forward) + .35 * abs(side))
    # the hands haul on each step, the heads scrape after him: closer in going backwards, off to one side on a strafe
    behind = (-side * .5, -.25 if forward < 0 else 0)
    scrape = .03 * max(two, 0)
    r_head = (behind[0], behind[1] + .07 * pump, 0, scrape)
    l_head = (behind[0], behind[1] - .07 * pump, 0, scrape)
    return dict(hauling(r_hand=(0, -.05 * pump, .02 * two), l_hand=(0, .05 * pump, .02 * two), r_head=r_head, l_head=l_head),
        hips={'rot': (pitch * .6, roll * .6 - LOPSIDED * .4, -7 * twist), 'loc': (LOPSIDED * .004, 0, -.08 - .035 * two)},
        chest=(pitch * .5, roll * .5 + LOPSIDED, 15 * twist),
        head=(-pitch * .9, -roll * .8 - LOPSIDED * .5, -8 * twist),
        L=tuple(BASE_L + wide + tr * sl + V((0, 0, zl))),
        R=tuple(BASE_R - wide + tr * sr + V((0, 0, zr))))

def loop_clip(name, length, pose_at, drag=.1):
    # two cycles and keep the second, so the hair's and cape's springs have settled and the loop closes
    keys = [(f, 'smooth', pose_at((f % length) / length)) for f in range(2 * length + 1)]
    frames, rm = keyed(name, 2 * length, keys, drag=drag)
    AB[name] = (frames[length:], rm[length:])

def run_clip(name, travel, reach, lift, lean, width=0.0, drag=.3):
    loop_clip(name, RUN_T, lambda p: run_pose(p, travel, reach, lift, lean, width), drag)

run_clip('Run_F', (0, -1), .52, .24, 13)
run_clip('Run_B', (0, 1), .36, .16, 8, drag=.1)
run_clip('Strafe_L', (1, 0), .2, .15, 9, width=.09, drag=.1)
run_clip('Strafe_R', (-1, 0), .2, .15, 9, width=.09, drag=.1)

# ---------------------------------------------------------------- standing around
# A Hero_X clip replaces the retargeted X at export. These give him weight and let the axes hang: he breathes, his
# weight drifts between his feet on a slower beat than his breath, and his head isn't locked to his chest.
TAU = 2 * math.pi
IDLE_T = 96

def idle_pose(p, r_hand=(0, 0, 0), r_head=(0, 0, 0, 0), l_hand=(0, 0, 0), l_head=(0, 0, 0, 0), chest=(0, 0, 0), head=(0, 0, 0)):
    breath = math.sin(p * TAU * 3)
    drift = math.sin(p * TAU)
    glance = math.sin(p * TAU * 2 + 1)
    # the heads stay put on the floor; the hands ride his breath and weight
    return dict(hauling(r_hand=_add(r_hand, (.012 * drift, 0, .012 * breath)), l_hand=_add(l_hand, (.012 * drift, 0, .012 * breath)), r_head=r_head, l_head=l_head),
        hips={'rot': (4, 2.5 * drift - LOPSIDED * .4, 2 * drift), 'loc': (.035 * drift + .03, 0, -.09 + .012 * breath)},
        chest=(3 - 1.6 * breath + chest[0], -1.5 * drift + LOPSIDED + chest[1], -2.5 * drift + chest[2]),
        head=(-4 + 1.2 * breath + head[0], .8 * drift - LOPSIDED * .5 + head[1], 6 * glance + head[2]),
        L=tuple(STAND_L), R=tuple(STAND_R))

loop_clip('Hero_Idle', IDLE_T, idle_pose)

# Fired up: bounces in a low guard while a fight is on.
def ready_pose(p):
    beat = math.sin(p * TAU)
    two = math.sin(p * TAU * 2)
    o = dict(carry(nudged(GUARD_R, hand=(0, .02 * beat, .025 * beat), along=(0, .04 * two, 0)), nudged(GUARD_L, hand=(0, -.02 * beat, .025 * beat), along=(0, -.04 * two, 0))))
    o.update(hips={'rot': (9, 1.5 * beat - LOPSIDED * .4, 6), 'loc': (.018 * beat + .02, -.02, -.14 + .022 * two)}, chest=(7 + 1.5 * two, LOPSIDED, -6 + 3 * beat), head=(-8 - 1.2 * two, -LOPSIDED * .5, 4 - 3 * beat), L=GUARD_POSE['L'], R=GUARD_POSE['R'])
    return o
loop_clip('Idle_Ready', 32, ready_pose)

# Fidgets, from and back to the idle's first frame so they drop in anywhere near it.
def _bump(f, a, b):   # 0 outside a..b, up to 1 and back down inside it
    if f <= a or f >= b: return 0.0
    k = (f - a) / (b - a)
    return math.sin(k * math.pi) ** 2

# Heaves the storm axe's head off the floor and lets it thump back down, rolling the shoulder.
def heft_pose(f):
    lift = _bump(f, 4, 26)
    drop = _bump(f, 24, 38)
    return idle_pose(0, r_hand=(.02 * lift, -.04 * lift, .14 * lift - .05 * drop), r_head=(0, -.1 * lift, .55 * lift, .55 * lift), chest=(-5 * lift + 3 * drop, 3 * lift, -9 * lift + 4 * drop), head=(-5 * lift + 3 * drop, -5 * lift, 12 * lift))
keys = [(f, 'smooth', heft_pose(f)) for f in range(49)]
AB['Idle_Heft'] = keyed('Idle_Heft', 48, keys, drag=.1)

# Heaves the magma axe up and round beside him, one-handed, then lets it fall back behind him.
SWING_T = 56
def swing_pose(f):
    w = _bump(f, 0, SWING_T)
    a = math.radians(74 - 96 * w)       # the head's bearing from his hand: behind him, then round to his side
    rest = V(DRAG_HEAD['l']) - V(DRAG_HAND['l'])
    round_ = V((math.cos(a), math.sin(a), 0)) * rest.length + V((0, 0, .5))
    head = (round_ - rest) * w
    return idle_pose(0, l_hand=(.05 * w, -.28 * w, .16 * w), l_head=(head.x, head.y, head.z, .55 * w), chest=(2 * w, 0, 10 * w), head=(3 * w, 0, 20 * w))
keys = [(f, 'smooth', swing_pose(f)) for f in range(SWING_T + 1)]
AB['Idle_Swing'] = keyed('Idle_Swing', SWING_T, keys, drag=.1)

# Something speaks at the rock ear. He stops, tips his head over to it and goes still, breath and all; then two small
# nods, answering; then a beat before he comes back. The head reads at 130 px only if it moves a lot and nothing else does.
LISTEN_T = 76
def _ramp(f, a, b):
    k = max(min((f - a) / (b - a), 1), 0)
    return k * k * (3 - 2 * k)
def listen_pose(f):
    w = _ramp(f, 8, 20) * (1 - _ramp(f, 60, 74))
    nod = _bump(f, 38, 44) + .75 * _bump(f, 45, 51)
    hush = 1 - .8 * w      # the idle's breathing and glance all but stop while he listens
    o = idle_pose(0, chest=(1.5 * w, 3 * w, 5 * w), head=(4 * w + 13 * nod, 24 * w, -18 * w))
    o['hips'] = dict(o['hips'], loc=(o['hips']['loc'][0], 0, -.09 + .012 * hush * math.sin(f / LISTEN_T * TAU)))
    return o
keys = [(f, 'smooth', listen_pose(f)) for f in range(LISTEN_T + 1)]
# E: the arm lets go of its shape and shoots out; the game draws the tentacle from the hand (void_tendril.gd)
REACH_R = {4: dict(hand=(-.7, .2, 1.2), along=(.1, -.9, .3), edge=(-1, 0, 0), elbow=(-.7, .5, -.3)),
           7: dict(hand=(-.34, -.62, 1.22), along=(0, -1, .1), edge=(-1, 0, 0), elbow=(-.7, .05, -.6)),
           13: dict(hand=(-.36, -.58, 1.2), along=(0, -1, .1), edge=(-1, 0, 0), elbow=(-.7, .05, -.6))}
ability('GR', 'Tendril Grab', 'E', 'SNAP!', '', 24, thrust([
    (0, 'smooth', READY),
    (4, 'out', {'hips': {'rot': (0, 0, -14), 'loc': (0, .06, -.1)}, 'chest': (-4, 0, -24), 'head': (-4, 0, 18)}),
    (7, 'in', {'rm': -.2, 'hips': {'rot': (8, 0, 14), 'loc': (0, -.1, -.16)}, 'chest': (10, 0, 28), 'head': (-8, 0, -20), 'L': (0, .1, 0), 'R': (0, -.12, 0)}),
    (13, 'out', {'rm': -.2, 'hips': {'rot': (2, 0, 10), 'loc': (0, .02, -.14)}, 'chest': (-2, 0, 22), 'head': (-4, 0, -16), 'L': (0, .1, 0), 'R': (0, -.12, 0)}),
    (24, 'smooth', P(READY, rm=-.2)),
], REACH_R))
# E off a string: the tentacle heaves what it holds over him and brings it down in front of him
SLAM_R = {4: dict(hand=(-.7, .28, .98), along=(-.1, .6, -.7), edge=(-1, 0, 0), elbow=(-.7, .5, -.2)),
          10: dict(hand=(-.5, -.1, 1.86), along=(-.1, .1, 1), edge=(-1, 0, 0), elbow=(-.8, .2, .1)),
          14: dict(hand=(-.44, -.56, .82), along=(0, -.8, -.6), edge=(-1, 0, 0), elbow=(-.7, .1, -.6)),
          22: dict(hand=(-.44, -.54, .78), along=(0, -.8, -.6), edge=(-1, 0, 0), elbow=(-.7, .1, -.6))}
ability('VS', 'Tendril Slam', 'E', 'WHAM!', '', 36, thrust([
    (0, 'smooth', READY),
    (4, 'out', {'hips': {'rot': (14, 0, -8), 'loc': (0, .08, -.24)}, 'chest': (18, 0, -14), 'head': (-20, 0, 8)}),
    (10, 'smooth', {'hips': {'rot': (-12, 0, -6), 'loc': (0, .02, .1)}, 'chest': (-26, 0, -12), 'head': (20, 0, 6), 'L': (0, .04, .08), 'R': (0, .06, .04)}),
    (14, 'in', {'rm': -.3, 'hips': {'rot': (28, 0, 8), 'loc': (0, -.12, -.34)}, 'chest': (38, 0, 12), 'head': (-30, 0, -8), 'L': (0, .14, 0), 'R': (0, -.16, 0)}),
    (22, 'out', {'rm': -.3, 'hips': {'rot': (30, 0, 8), 'loc': (0, -.12, -.36)}, 'chest': (40, 0, 12), 'head': (-32, 0, -8), 'L': (0, .14, 0), 'R': (0, -.16, 0)}),
    (36, 'smooth', P(READY, rm=-.3)),
], SLAM_R))
# Swinging on the tentacle: the arm up to it, legs trailing. Held, not a cycle.
HANG = dict(carry(dict(hand=(-.46, -.12, 1.9), along=(-.1, -.1, 1), edge=(-1, 0, 0), elbow=(-.8, .2, .1)), dict(hand=(.66, .3, 1.0), along=(0, 0, -1), edge=(1, 0, 0), elbow=(.7, .4, -.2))),
            hips={'rot': (-16, 0, 8), 'loc': (0, 0, .1)}, chest=(-14, 0, -10), head=(12, 0, 6), L=(-.05, .24, .3), R=(.07, .36, .16))
AB['Ab_Swing'] = keyed('Ab_Swing', 8, [(0, 'smooth', HANG), (8, 'smooth', HANG)])
AB['Idle_Listen'] = keyed('Idle_Listen', LISTEN_T, keys, drag=.1)

# ---------------------------------------------------------------- the rest of what he does between moves
# Holding a charge: coiled low, shaking harder at the top of each breath. Also his hang in the air on some breakers.
def coil_pose(p):
    beat = math.sin(p * TAU * 2)
    jit = math.sin(p * TAU * 7)
    return dict(carry(nudged(COILED_R, hand=(.006 * jit, 0, .012 * beat)), nudged(COILED_L, hand=(-.006 * jit, 0, .012 * beat))),
        hips={'rot': (16, 0, 6), 'loc': (.006 * jit, .06, -.26 + .012 * beat)}, chest=(16 + 1.5 * beat, 0, 12), head=(-16, 0, -7),
        L=(-.02, .06, 0), R=(.06, .34, 0))
loop_clip('Hero_2H_Melee_Idle', 24, coil_pose)

_flung = carry(FLUNG_R, FLUNG_L)
keys = [
    (0, 'smooth', GUARD_POSE),
    (3, 'in', dict(carry(nudged(FLUNG_R, hand=(0, .1, 0)), nudged(FLUNG_L, hand=(0, .1, 0))), hips={'rot': (-9, 0, -7), 'loc': (0, .14, -.1)}, chest=(-16, 4, 10), head=(14, 0, -8), L=(-.02, .12, 0), R=(.06, .3, 0))),
    (6, 'out', dict(_flung, hips={'rot': (-5, 0, -4), 'loc': (0, .1, -.14)}, chest=(-9, 2, 6), head=(9, 0, -5), L=(-.02, .12, 0), R=(.06, .3, 0))),
    (16, 'smooth', GUARD_POSE),
]
AB['Hero_Hit_A'] = keyed('Hero_Hit_A', 16, keys, drag=.1)

# A dash: bent over, axes streaming. A short clip that lands in a stride, as it's only 10 frames.
_dash = carry(STREAM_R, STREAM_L)
keys = [
    (0, 'smooth', dict(_dash, hips={'rot': (20, 0, 0), 'loc': (0, -.02, -.2)}, chest=(18, 0, 0), head=(-18, 0, 0), L=(-.08, -.22, .02), R=(.08, .66, .06))),
    (5, 'smooth', dict(_dash, hips={'rot': (28, 0, 0), 'loc': (0, -.06, -.24)}, chest=(22, 0, 0), head=(-26, 0, 0), L=(-.08, .3, .12), R=(.08, .06, .16))),
    (10, 'smooth', dict(_dash, hips={'rot': (24, 0, 0), 'loc': (0, -.04, -.22)}, chest=(20, 0, 0), head=(-22, 0, 0), L=(-.08, .4, .02), R=(.08, -.08, .06))),
]
AB['Hero_Dodge_Forward'] = keyed('Hero_Dodge_Forward', 10, keys, drag=.2)

# Jump: crouches, then pushes off with the arms coming up and out.
keys = [
    (0, 'smooth', dict(carry(COILED_R, COILED_L), hips={'rot': (16, 0, 0), 'loc': (0, .06, -.3)}, chest=(14, 0, 0), head=(-12, 0, 0), L=(-.02, .06, 0), R=(.06, .3, 0))),
    (6, 'in', dict(_flung, hips={'rot': (-6, 0, 0), 'loc': (0, 0, .04)}, chest=(-8, 0, 0), head=(4, 0, 0), L=(-.05, .1, .1), R=(.07, .22, .26))),
    (15, 'out', dict(_flung, hips={'rot': (-2, 0, 0), 'loc': (0, 0, .04)}, chest=(-3, 0, 0), head=(0, 0, 0), L=(-.05, .1, .26), R=(.07, .12, .44))),
]
AB['Hero_Jump_Start'] = keyed('Hero_Jump_Start', 15, keys, drag=.2)

# In the air: knees tucked, arms out for balance, drifting.
def air_pose(p):
    b = math.sin(p * TAU)
    return dict(carry(nudged(FLUNG_R, hand=(0, 0, .03 * b), along=(0, .04 * b, 0)), nudged(FLUNG_L, hand=(0, 0, -.03 * b), along=(0, -.04 * b, 0))),
        hips={'rot': (3 + 2 * b, 0, 2 * b), 'loc': (0, 0, .04)}, chest=(2, 0, -3 * b), head=(-3, 0, 3 * b), L=(-.05, .08 + .02 * b, .26), R=(.07, .12 - .02 * b, .44))
loop_clip('Hero_Jump_Idle', 26, air_pose, drag=.2)
