# The shaman's abilities, hand-keyed. Exec'd inside the rig namespace (rig_comic.py), which supplies:
# tb, t_rest, t_q0, ALL_T, ORDER, ik, rot_to, Q, V, math, FPS, Yax.
#
# A pose is {bone: (rx, ry, rz)} degrees about world axes at rest, inherited down the chain. Front -Y, his left +X.
#   +X pitches up-pointing things forward. For an arm: -X raises it forward/up, +X lowers it. +Z turns to his left.
# Extra pose keys:
#   'hips': {'rot': .., 'loc': ..}   'L', 'R': foot/peg target offset in metres (feet stay planted by IK, so a crouch
#   is just hips loc). 'rm': forward travel so far, in metres (root motion, moves spirit and camera too).
#   'spin': whole-body yaw in degrees, not limited to the short way round.
# Keys: [(frame, ease, pose), ...]; ease: 'in' arrives fast (the swing), 'out' settles slowly, 'hold' snaps, 'smooth'.
# Timing rule: long enough anticipation to read, 2-4 frames to contact, a hold on contact, a slow settle.

def _ease(k, kind):
    if kind == 'in': return k * k * k
    if kind == 'out': return 1 - (1 - k) ** 3
    if kind == 'hold': return 0.0
    return k * k * (3 - 2 * k)

def _rq(rot):
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
                e = rot_of(n)
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

AB = {}
INFO = {}
def ability(key, name, input_, word, cast, length, keys):
    frames, rm = keyed('Ab_' + key, length, keys)
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
# L L: the magma axe comes back the other way, wider, a little hop onto it
ability('L2', 'Light 2', 'L L', 'KRANG!', 'echo', 26, [
    (0, 'smooth', READY),
    (5, 'out', {'hips': {'rot': (0, 0, 16), 'loc': (0, .03, -.12)}, 'chest': (-8, 0, 36), 'head': (0, 0, -26), 'upperarm.l': (-110, 0, 54), 'lowerarm.l': (-16, 0, 20), 'upperarm.r': (10, 0, -26)}),
    (8, 'in', {'rm': -.24, 'hips': {'loc': (0, -.1, .2)}, 'chest': (-2, 0, 8), 'upperarm.l': (-108, 0, 8), 'lowerarm.l': (-12, 0, 0), 'upperarm.r': (10, 0, -20), 'L': (0, -.05, .16), 'R': (0, -.1, .1)}),
    (11, 'in', {'rm': -.46, 'hips': {'rot': (12, 0, -18), 'loc': (0, -.14, -.18)}, 'chest': (12, 0, -38), 'head': (-4, 0, 26), 'upperarm.l': (-74, 0, -72), 'lowerarm.l': (-4, 0, -36), 'upperarm.r': (-12, 0, 18), 'L': (0, -.1, 0), 'R': (0, .08, 0)}),
    (15, 'out', {'rm': -.5, 'hips': {'rot': (12, 0, -20), 'loc': (0, -.14, -.18)}, 'chest': (14, 0, -42), 'head': (-4, 0, 28), 'upperarm.l': (-66, 0, -78), 'lowerarm.l': (-2, 0, -40), 'upperarm.r': (-12, 0, 18), 'L': (0, -.1, 0), 'R': (0, .08, 0)}),
    (26, 'smooth', P(READY, rm=-.5)),
])
# L L L Triple Chop: leaps, both axes over his head, comes down hard. Two colossal axes slam into a V
CHOP_TOP = {'chest': (-24, 0, 0), 'head': (20, 0, 0), 'upperarm.r': (-62, 0, -12), 'lowerarm.r': (-26, 0, 0), 'upperarm.l': (-130, 0, 8), 'lowerarm.l': (-22, 0, 0)}
CHOP_DOWN = {'chest': (30, 0, 0), 'head': (-22, 0, 0), 'upperarm.r': (-14, 0, 14), 'lowerarm.r': (0, 0, 0), 'hand.r': (20, 0, 0), 'upperarm.l': (-100, 0, -14), 'lowerarm.l': (-10, 0, 0), 'hand.l': (6, 0, 0)}
ability('L3', 'Triple Chop', 'L L L', 'KRAK!', 'cleave', 44, [
    (0, 'smooth', READY),
    (7, 'out', P({'hips': {'rot': (22, 0, 0), 'loc': (0, .1, -.24)}, 'chest': (24, 0, 0), 'head': (-24, 0, 0), 'upperarm.r': (34, 0, -24), 'upperarm.l': (40, 0, 24)})),
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
ability('DL', 'Dash Stab', 'Dash > L', 'SHIIING!', 'tomahawk', 48, [
    (0, 'smooth', P(READY, rm=0)),
    (6, 'smooth', {'rm': -1.5, 'hips': {'rot': (24, 0, 0), 'loc': (0, 0, -.2)}, 'chest': (26, 0, -30), 'head': (-30, 0, 24), 'upperarm.r': (-150, 0, -30), 'lowerarm.r': (-46, 0, 0), 'upperarm.l': (40, 0, 40), 'L': (0, .2, 0), 'R': (0, -.2, 0)}),
    (9, 'in', {'rm': -1.75, 'hips': {'rot': (28, 0, 0), 'loc': (0, -.1, -.26)}, 'chest': (30, 0, 26), 'head': (-28, 0, -18), 'upperarm.r': (-50, 0, 30), 'lowerarm.r': (6, 0, 0), 'upperarm.l': (46, 0, 30), 'L': (0, .2, 0), 'R': (0, -.26, 0)}),
    (14, 'out', {'rm': -1.75, 'hips': {'rot': (28, 0, 0), 'loc': (0, -.1, -.26)}, 'chest': (32, 0, 28), 'head': (-28, 0, -20), 'upperarm.r': (-44, 0, 34), 'lowerarm.r': (6, 0, 0), 'upperarm.l': (46, 0, 30), 'L': (0, .2, 0), 'R': (0, -.26, 0)}),
    (38, 'smooth', {'rm': -1.75, 'hips': {'rot': (6, 0, 0), 'loc': (0, 0, -.08)}, 'chest': (0, 0, -10), 'upperarm.r': (-60, 0, -20), 'lowerarm.r': (-30, 0, 0)}),
    (41, 'in', {'rm': -1.75, 'hips': {'rot': (0, 0, 0), 'loc': (0, .08, -.1)}, 'chest': (-10, 0, -16), 'upperarm.r': (-80, 0, -40), 'lowerarm.r': (-46, 0, 0)}),
    (48, 'smooth', P(READY, rm=-1.75)),
])
# L H H Spike: flung high, points at the target, a colossal axe follows his dive down
ability('LHH', 'Spike', 'L H H', 'CHUNK!', 'guillotine', 44, [
    (0, 'smooth', READY),
    (6, 'out', {'hips': {'rot': (18, 0, 0), 'loc': (0, .05, -.26)}, 'chest': (20, 0, 0), 'head': (-16, 0, 0), 'upperarm.r': (30, 0, -20), 'upperarm.l': (30, 0, 20)}),
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
    (10, 'out', {'hips': {'rot': (24, 0, 0), 'loc': (0, .1, -.32)}, 'chest': (34, 0, 0), 'head': (-36, 0, 0), 'upperarm.r': (46, 0, -30), 'upperarm.l': (46, 0, 30)}),
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
    (40, 'in', {'hips': {'rot': (34, 0, 0), 'loc': (0, -.06, -.4)}, 'chest': (40, 0, 0), 'head': (-34, 0, 0), 'upperarm.l': (-80, 0, -8), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (-20, 0, 30), 'lowerarm.r': (-4, 0, 0), 'L': (.08, .14, 0), 'R': (-.08, -.12, 0)}),
    (54, 'out', {'hips': {'rot': (36, 0, 0), 'loc': (0, -.06, -.42)}, 'chest': (42, 0, 0), 'head': (-36, 0, 0), 'upperarm.l': (-82, 0, -8), 'lowerarm.l': (-10, 0, 0), 'upperarm.r': (-18, 0, 30), 'lowerarm.r': (-4, 0, 0), 'L': (.08, .14, 0), 'R': (-.08, -.12, 0)}),
    (78, 'smooth', READY),
])
