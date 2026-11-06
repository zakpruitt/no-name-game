# Per-foe cycles and hit clips for foe_keys.py (round 38). Each foe maps a clip name to a function
# (ctx) -> a pose per frame. v (m/s at 1x) = enemy_types move_speed / model_scale, so the planted
# feet keep up at the game's speed with the clip at 1x.
# Pose keys: see foe_keys.py. hip (x, y, z) m; hipr / spine / chest / head / <bone> (yaw, pitch, roll)
# deg on top of Idle_Combat frame 0 (+ pitch tips a bone's far end forward: a hanging cloth or arm
# swings back); fl / fr ankle targets; tl / tr toe-up deg; root {sq, loc, rot}.
# Run spec (foe_keys.run_cycle): N frames a cycle (24 fps), P frames each foot is planted, lift m,
# lean / yaw / roll / twist deg, drop / bob / sway m, sq / stretch the squash at the bottom and the
# stretch at the top of each step, arm / pump deg, arms {side: share}, extra {bone: f(phase, bob)}.
import math


def run(**c):
    f = lambda ctx: ctx['run_cycle'](c)
    f.spec = c  # the start / stop one-shots end and begin on its frame 0
    return f


def trail(pitch, wobble=0.0, yaw=0.0):
    """A hanging part (cloth, coat, cape) blown back by the run, flapping once a step."""
    return lambda ph, bob: (yaw * math.cos(ph), pitch + wobble * bob, 0.0)


# ------------------------------------------------------------------ hit reactions, per body type
# T: amp (torso whip), fling (arms), sl / sr (each arm's share: a shield arm stays braced), kick (the
# leg thrown up), plank (heavy: stiff fall, no kick), up (legs thrown up in the death: the bomber),
# whip {bone: deg} (cloth and coats snapping on the hit).
LIGHT = dict(amp=1.0, fling=1.0, sl=1.0, sr=.5, kick=1.0)
HEAVY = dict(amp=.65, fling=.55, sl=1.0, sr=.4, kick=.4, plank=True)


def _foot(ctx, side, dx=0.0, dy=0.0, dz=0.0):
    if side not in ctx['STANCE']:
        return (0.0, 0.0, 0.0)  # no feet (the robe): _pose drops it
    st = ctx['STANCE'][side]
    return (st.x + (dx if side == 'l' else -dx), st.y + dy, st.z + dz)


def _arms(T, pitch, out):
    """Both arms thrown: pitch (- forward and up), out (spread away from the body)."""
    sl, sr = T.get('sl', 1.0), T.get('sr', 1.0)
    return {'upperarm.l': (0.0, pitch * sl, -out * sl), 'upperarm.r': (0.0, pitch * sr, out * sr),
            'lowerarm.l': (0.0, pitch * .3 * sl, 0.0), 'lowerarm.r': (0.0, pitch * .3 * sr, 0.0)}


def _pose(T, ctx, **kw):
    p = {}
    if 'arms' in kw:
        p.update(_arms(T, *kw.pop('arms')))
    if 'whip' in kw:
        k = kw.pop('whip')
        p.update({b: (0.0, d * k, 0.0) for b, d in T.get('whip', {}).items() if b in ctx['bones']})
    if not ctx['HAS_LEGS']:
        for k in ('fl', 'fr', 'tl', 'tr', 'feet'):
            kw.pop(k, None)
    p.update(kw)
    return p


def hit_b(T):
    """Knocked back hard (also the launch and the stagger): squashed on the blow, whipped back with the
    head snapped and the arms flung forward, a leg kicked up, an overshoot, a recoil, eyes shut."""
    def make(ctx):
        n = ctx['length']('Hit_B') or 14
        a, f, k = T['amp'], T['fling'], T.get('kick', 1.0)
        u = n / 14.0
        X = lambda **kw: _pose(T, ctx, **kw)
        keys = [
            (0, X(), 'out'),
            (2, X(hip=(0, .07 * a, -.03), hipr=(0, -24 * a, 0), spine=(0, -10 * a, 0), chest=(0, -12 * a, 0),
                  head=(0, -28 * a, 0), jaw=(0, 24, 0), root={'sq': .16 * a}, eye=0.0, arms=(-55 * f, 30 * f),
                  fl=_foot(ctx, 'l', 0, -.1 * k, .12 * k), tl=20 * k, whip=-1.0), 'hold'),
            (3, X(hip=(0, .08 * a, -.01), hipr=(0, -27 * a, 0), spine=(0, -10 * a, 0), chest=(0, -12 * a, 0),
                  head=(0, -30 * a, 0), jaw=(0, 24, 0), root={'sq': -.07 * a}, eye=0.0, arms=(-65 * f, 36 * f),
                  fl=_foot(ctx, 'l', 0, -.12 * k, .15 * k), tl=25 * k, whip=-1.2), 'out'),
            (round(7 * u), X(hip=(0, .1 * a, -.02), hipr=(0, -31 * a, 3), spine=(0, -12 * a, 0), chest=(0, -10 * a, 0),
                             head=(0, -18 * a, 6), jaw=(0, 14, 0), root={'sq': -.03}, eye=0.0, arms=(-78 * f, 44 * f),
                             fl=_foot(ctx, 'l', 0, -.06 * k, .06 * k), tl=10, whip=.6), 'io'),
            (round(10 * u), X(hip=(0, .02, -.05), hipr=(0, 10 * a, 0), spine=(0, 4, 0), chest=(0, 6 * a, 0),
                              head=(0, 12 * a, 0), root={'sq': .06}, eye=.15, arms=(14 * f, 12 * f), whip=1.0), 'io'),
            (n, X(), 'lin'),
        ]
        return ctx['keyed'](keys, n)
    return make


def lie_stand_up(T):
    """Flat on its back (the knockdown lies here), a twitch, sits up, rolls onto its feet in a crouch,
    pops up stretched with the arms thrown up, settles. Eyes open as it gets up."""
    def make(ctx):
        n = ctx['length']('Lie_StandUp') or 32
        u = n / 32.0
        lift = ctx['REST']['hips'].z * .32 * T.get('lift', 1.0)
        fb = T.get('fall', 1.0)  # 1 falls onto its back, -1 onto its face
        X = lambda **kw: _pose(T, ctx, **kw)
        tuck = dict(feet='body', fl=_foot(ctx, 'l', 0, -.12, .14), fr=_foot(ctx, 'r', 0, -.1, .12)) if ctx['HAS_LEGS'] else {}
        flat = dict(feet='body', fl=_foot(ctx, 'l', .04, -.06, .02), fr=_foot(ctx, 'r', .06, -.03, .04)) if ctx['HAS_LEGS'] else {}
        lying = {'rot': (0, (-90) * fb, 0), 'loc': (0, 0 * fb, lift)}
        keys = [
            (0, X(root=lying, hipr=(0, -14, 0), head=(22, -6, 0), jaw=(0, 18, 0), eye=0.0, arms=(-25, 55), whip=.5, **flat), 'hold'),
            (round(8 * u), X(root=lying, hipr=(0, -14, 0), head=(22, -6, 0), jaw=(0, 18, 0), eye=0.0, arms=(-25, 55), whip=.5, **flat), 'out'),
            (round(11 * u), X(root={'rot': (0, (-86) * fb, 0), 'loc': (0, 0 * fb, lift * 1.05)}, head=(-6, 14, 0), jaw=(0, 6, 0),
                              eye=0.0, arms=(-35, 40), **flat), 'in'),
            (round(15 * u), X(root={'rot': (0, (-55) * fb, 0), 'loc': (0, 0 * fb, lift * .7)}, hipr=(0, 30, 0), chest=(0, 15, 0),
                              head=(0, 14, 0), eye=0.0, arms=(-55, 12), **tuck), 'hold'),
            (round(18 * u), X(hip=(0, 0, -.17), hipr=(0, 32, 0), chest=(0, 10, 0), head=(0, -18, 0), root={'sq': .12},
                              eye=.3, arms=(-15, 28)), 'out'),
            (round(23 * u), X(hip=(0, 0, .02), hipr=(0, -6, 0), head=(0, -10, 0), root={'sq': -.08}, eye=1.0,
                              arms=(-80, 50), whip=-.6), 'io'),
            (round(27 * u), X(hip=(0, 0, -.03), hipr=(0, 4, 0), root={'sq': .04}, arms=(-10, 8)), 'io'),
            (n, X(), 'lin'),
        ]
        return ctx['keyed'](keys, n)
    return make


def death_a(T):
    """Snapped back by the blow (eyes shut for good), thrown onto its back with the arms flung and the
    legs kicked (a plank falls stiff), a bounce off the floor, then limp: head lolled, jaw hanging."""
    def make(ctx):
        n = ctx['length']('Death_A') or 40
        u = n / 40.0
        lift = ctx['REST']['hips'].z * .32 * T.get('lift', 1.0)
        fb = T.get('fall', 1.0)  # 1 falls onto its back, -1 onto its face
        plank = T.get('plank', False)
        up = T.get('up', 0.0)
        a, f = T['amp'], T['fling']
        X = lambda **kw: _pose(T, ctx, **kw)
        if not ctx['HAS_LEGS']:
            kick = limp = {}
        elif plank:
            kick = dict(feet='body', fl=_foot(ctx, 'l', .02, -.02, 0), fr=_foot(ctx, 'r', .02, -.02, 0))
            limp = dict(feet='body', fl=_foot(ctx, 'l', .08, -.04, .02), fr=_foot(ctx, 'r', .03, -.1, .08))
        else:
            kick = dict(feet='body', fl=_foot(ctx, 'l', .02, -.16 - up * .1, .12 + up * .25), fr=_foot(ctx, 'r', .04, -.08, .05 + up * .2))
            limp = dict(feet='body', fl=_foot(ctx, 'l', .08, -.05 - up * .1, .02 + up * .12), fr=_foot(ctx, 'r', .02, -.14, .12))
        t2, t3 = (round(9 * u), round(15 * u)) if plank else (round(6 * u), round(11 * u))
        down = {'rot': (0, (-90) * fb, 0), 'loc': (0, .13 * fb, lift)}
        keys = [
            (0, X(), 'out'),
            (2, X(hip=(0, .08 * a, -.03), hipr=(0, -28 * a, 0), chest=(0, -14 * a, 0), head=(0, -32 * a, 0), jaw=(0, 28, 0),
                  root={'sq': .18 * a}, eye=0.0, arms=(-60 * f, 35 * f), whip=-1.2), 'hold'),
            (3, X(hip=(0, .1 * a, 0), hipr=(0, -30 * a, 0), chest=(0, -14 * a, 0), head=(0, -34 * a, 0), jaw=(0, 30, 0),
                  root={'sq': -.08}, eye=0.0, arms=(-75 * f, 40 * f), whip=-1.4), 'in'),
            (t2, X(root={'rot': (0, (-30 if plank else -38) * fb, 0), 'loc': (0, .05 * fb, .06)}, hipr=(0, -20 * a, 0), head=(0, -25, 0),
                   jaw=(0, 30, 0), eye=0.0, arms=(-100 * f, 55 * f), whip=-1.0, **kick), 'in'),
            (t3, X(root={'rot': (0, (-92) * fb, 0), 'loc': (0, .1 * fb, lift * .85)}, head=(0, -10, 0), jaw=(0, 26, 0), eye=0.0,
                   arms=(-70 * f, 70 * f), whip=1.0, **kick), 'out'),
            (t3 + round(3 * u), X(root={'rot': (0, (-84) * fb, 0), 'loc': (0, .12 * fb, lift + (.1 if plank else .07))}, head=(10, -4, 0),
                                  jaw=(0, 20, 0), eye=0.0, arms=(-50, 60), whip=.5, **kick), 'in'),
            (t3 + round(6 * u), X(root=down, hipr=(0, -14, 0), head=(30, 6, 0), jaw=(0, 32, 0), eye=0.0, arms=(-30, 75), whip=-.3, **limp), 'out'),
            (n, X(root=down, hipr=(0, -14, 0), head=(36, 8, 0), jaw=(0, 34, 0), eye=0.0, arms=(-28, 78), **limp), 'lin'),
        ]
        return ctx['keyed'](keys, n)
    return make


def hits(T):
    return {'Hit_A': (lambda ctx: hit_a(T)(ctx)), 'Hit_B': hit_b(T), 'Lie_StandUp': lie_stand_up(T), 'Death_A': death_a(T)}


FOES = {
    # minion: a scurry. Quick short steps (6 a second), hunched in, the free arm pumping, head bobbing.
    'minion': {
        **hits(dict(LIGHT, sr=.4, whip={'cloth': 25})),
        'Running_A': run(v=3.6, N=8, P=3, lift=.1, lean=18, drop=.06, bob=.025, sq=.08, stretch=.03,
                         yaw=10, roll=5, sway=.02, twist=8, arm=35, pump=30, arms={'r': .1}, nod=6,
                         push=10, peak_at=.3, lift_pow=.6, paw=1.0, extra={'cloth': trail(14, 8)}),
    },
    # warrior: a stomp. Knees driven high, each foot slammed flat (big squash), shoulders rocking
    # over the planted foot, the sword carried steady.
    'warrior': {
        **hits(dict(HEAVY, whip={'cloth': 20, 'pauldron.l': 10, 'pauldron.r': 10})),
        'Running_A': run(v=2.8 / 1.15, N=12, P=4, lift=.15, lean=9, drop=.07, bob=.035, sq=.11, stretch=.03,
                         yaw=7, roll=8, sway=.035, twist=6, arm=22, pump=20, arms={'r': .15}, nod=5, heel=4,
                         push=8, peak_at=.4, lift_pow=.8, paw=.6, down_at=.12, extra={'cloth': trail(10, 6)}),
    },
    # shield: a plod. Shield held square in front and steady, heavy rocking side to side, short low steps.
    'shield': {
        **hits(dict(HEAVY, sl=.15, sr=.6, whip={'cloth': 20})),
        'Walking_D_Skeletons': run(v=3.2 / 1.05, N=10, P=3, lift=.08, lean=6, drop=.05, bob=.03, sq=.08,
                                   stretch=.02, yaw=4, roll=10, sway=.045, twist=3, arm=18, pump=10,
                                   arms={'l': 0.0, 'r': .35}, nod=3, push=8, peak_at=.35, lift_pow=.7, paw=.8,
                                   down_at=.15, extra={'cloth': trail(8, 6)}),
    },
    # rogue: a sneak-dash. Low and pitched far in, long gliding strides, both daggers swept back.
    'rogue': {
        **hits(dict(LIGHT, sr=.8, amp=1.1, whip={'cloth': 30, 'tail.l.0': 35, 'tail.r.0': 35})),
        'Running_C': run(v=5.4, N=10, P=4, lift=.11, lean=30, drop=.1, bob=.025, sq=.06, stretch=.05,
                         yaw=12, roll=4, sway=.02, twist=10, arm=10, pump=10, arm_back=80, arm_out=20,
                         nod=3, head_up=.8, push=12, peak_at=.35, lift_pow=.7, paw=1.0,
                         extra={'cloth': trail(22, 8), 'tail.l.0': trail(25, 10, 8), 'tail.r.0': trail(25, 10, -8)}),
    },
    # archer: a trot. Upright, springy, bow held out steady in the left hand, the right arm swinging.
    'archer': {
        **hits(dict(LIGHT, sl=.4, sr=1.0, whip={'loin': 25, 'cape.1': 30, 'cape.l': 25, 'cape.r': 25})),
        'Running_A': run(v=3.2, N=10, P=3, lift=.11, lean=10, drop=.05, bob=.035, sq=.07, stretch=.04,
                         yaw=8, roll=5, sway=.02, twist=6, arm=30, pump=25, arms={'l': .15, 'r': 1.0}, nod=4,
                         push=10, peak_at=.35, lift_pow=.7, paw=.9,
                         extra={'loin': trail(12, 8), 'cape.1': trail(16, 8), 'cape.l': trail(18, 8, 6), 'cape.r': trail(18, 8, -6)}),
    },
    # mage: a float. A quick low shuffle under the coat, the body gliding level, coat flaring back,
    # staff held up.
    'mage': {
        **hits(dict(LIGHT, sr=.4, kick=.3, whip={'coat.b': 35, 'coat.l': 25, 'coat.r': 25, 'loin': 30, 'hat': -25, 'mantle.b': 20})),
        'Running_A': run(v=3.0, N=8, P=3, lift=.045, lean=7, drop=.04, bob=.01, sq=.03, stretch=.015,
                         yaw=4, roll=3, sway=.01, twist=3, arm=14, pump=8, arms={'r': .2}, arm_out=8, nod=2,
                         push=5, heel=3, peak_at=.5, lift_pow=1.0, paw=.8,
                         extra={'coat.b': trail(20, 6), 'coat.l': trail(12, 5, 6), 'coat.r': trail(12, 5, -6),
                                'loin': trail(16, 6), 'mantle.b': trail(10, 4), 'hat': trail(-8, 4)}),
    },
    # bomber: a waddle. Feet wide, rolling hard from one to the other, short hops, the bomb bobbing.
    'bomber': {
        **hits(dict(LIGHT, sl=.8, sr=.8, amp=1.2, up=1.0, fall=-1.0, lift=1.3, whip={'cloth': 20})),
        'Running_C': run(v=4.2 / .9, N=8, P=2, lift=.08, lean=8, drop=.04, bob=.04, sq=.12, stretch=.06,
                         width=1.25, yaw=6, roll=16, sway=.06, twist=4, arm=20, pump=15, arm_out=18, nod=6,
                         push=6, peak_at=.4, lift_pow=.8, paw=1.0, down_at=.15,
                         extra={'cloth': trail(10, 8)}),
    },
    # necromancer: a glide. No feet under the robe: the body floats forward on a slow bob, pitched in,
    # robe streaming back, arms held out.
    'necromancer': {
        **hits(dict(LIGHT, sl=1.0, sr=.5, kick=0.0, whip={'skirt': 30})),
        'Walking_D_Skeletons': run(v=0.0, N=24, P=0, lean=12, drop=-.02, bob=.03, sq=.0, stretch=.0, yaw=4,
                                   roll=3, sway=.015, twist=3, arm=8, pump=6, arm_out=10, nod=3, down_at=.0,
                                   extra={'skirt': trail(16, 10)}),
    },
    # warden: a heavy stomp (boss.gd shakes the floor on each footfall). Slow huge steps, the body
    # dropped hard on each contact, rocking, the cleaver swinging low.
    'warden': {
        'Death_A': death_a(dict(HEAVY, amp=.5, fling=.4, whip={'tabard': 20, 'cape': 25})),
        'Walking_D_Skeletons': run(v=3.0 / 1.8, N=20, P=8, lift=.2, lean=7, drop=.08, bob=.05, sq=.08, stretch=.02,
                                   yaw=6, roll=6, sway=.05, twist=5, arm=12, pump=10, arms={'r': .4}, nod=4,
                                   heel=6, push=8, peak_at=.42, lift_pow=.9, paw=.5, down_at=.1,
                                   extra={'tabard': trail(8, 6), 'cape': trail(10, 6)}),
    },
}


# ------------------------------------------------------------------ round 2: attacks, idles, Hit_A, run start / stop
# Attacks: a tell (the anticipation pose, reached in 3-5 frames and held on twos with a tremble and a
# slow creep further back), a strike of 2-3 drawings with a smear (the weapon hand swollen, `scale`),
# the contact drawing on the clip's hit frame (enemy_types `attack_hit`: the strike lands when the
# windup ends, the clip playing at hit / 24 / attack_windup ~ 1x), held 2 frames, then a recovery that
# overshoots past the guard and settles. Ranged foes fire on the first frame of their shoot clip, so
# their windup clip is all tell and the shoot clip starts on the strike.
FOLLOW = {'archer': {'arrow': 'hand.r'}}  # the archer's arrow is on the root, keyed in world offsets


def add(p, **kw):
    """p with tuples added (bone turns, hip) and anything else replaced."""
    q = dict(p)
    for k, v in kw.items():
        if isinstance(v, tuple) and isinstance(q.get(k), tuple):
            q[k] = tuple(a + b for a, b in zip(q[k], v))
        else:
            q[k] = v
    return q


def tremble(f0, f1, a, b, amt=2.0, bones=('head', 'chest'), mix=None):
    """A held tell from f0 to f1: drawings on twos creeping from pose a to pose b, shaking +-amt deg."""
    keys = []
    fs = list(range(f0, f1, 2))
    for i, f in enumerate(fs):
        p = mix(a, b, i / max(len(fs) - 1, 1))
        s = amt if i % 2 else -amt
        for bn in bones:
            p[bn] = tuple(x + y for x, y in zip(p.get(bn, (0.0, 0.0, 0.0)), (s, 0.0, s * .5)))
        keys.append((f, p, 'hold'))
    return keys


def clip(n, build):
    def make(ctx):
        X = lambda **kw: _pose({}, ctx, **kw)
        return ctx['keyed'](build(ctx, X), n)
    return make


# ---- melee. Arms: (yaw, pitch, roll) world turns on the guard; - pitch lifts a hanging arm forward / up.
def minion_swipe(ctx, X):
    """Hit 14 of 28. Coils to its right with the cleaver cocked back by its ear, crouched; whips it flat
    across to its left, swollen; follows through past and slumps; back to guard. Arms by `aim`
    (az, el, twist): az 0 ahead, + to its left, el + up."""
    mix = ctx['mix']
    A = X(hip=(0, .04, -.07), hipr=(-28, 8, 0), spine=(-6, 4, 0), chest=(-18, 0, 0), head=(36, 6, -6), jaw=(0, 18, 0),
          root={'sq': .1}, eye=.5, aim={'upperarm.r': (-110, 25, 0), 'lowerarm.r': (-130, 55, 180), 'upperarm.l': (40, -20, 0)},
          cloth=(0, -10, 0))
    A2 = add(A, hipr=(-8, 2, 0), chest=(-6, 0, 0), head=(10, 0, 0),
             aim={'upperarm.r': (-120, 30, 0), 'lowerarm.r': (-145, 60, 180), 'upperarm.l': (45, -20, 0)})
    S = X(hip=(0, -.08, -.04), hipr=(8, 12, 0), chest=(16, 6, 0), head=(-10, 4, 0), jaw=(0, 26, 0), root={'sq': -.07},
          eye=.3, scale={'hand.r': 1.5}, aim={'upperarm.r': (-45, 10, 0), 'lowerarm.r': (-15, 5, 240), 'upperarm.l': (20, -40, 0)})
    H = X(hip=(0, -.12, -.09), hipr=(28, 16, 0), spine=(6, 6, 0), chest=(26, 6, 0), head=(-24, 8, 0), jaw=(0, 30, 0),
          root={'sq': .12}, eye=.4, scale={'hand.r': 1.2}, fl=_foot(ctx, 'l', 0, -.06, 0), cloth=(0, 18, 0),
          aim={'upperarm.r': (25, 0, 0), 'lowerarm.r': (55, -5, 290), 'upperarm.l': (-10, -60, 0)})
    O = X(hip=(0, -.13, -.11), hipr=(38, 24, 0), spine=(10, 10, 0), chest=(30, 8, 0), head=(-26, 14, 0), jaw=(0, 18, 0),
          root={'sq': .05}, fl=_foot(ctx, 'l', 0, -.06, 0), cloth=(0, -8, 0),
          aim={'upperarm.r': (60, -15, 0), 'lowerarm.r': (95, -20, 300), 'upperarm.l': (-20, -60, 0)})
    R = X(hip=(0, -.02, -.02), hipr=(-6, 2, 0), chest=(-4, -4, 0), head=(4, -4, 0), root={'sq': -.02}, **{'upperarm.r': (-6, 6, 0)})
    return ([(0, X(), 'out'), (4, A, 'hold')] + tremble(4, 11, A, A2, 2.0, mix=mix) +
            [(11, A2, 'hold'), (12, S, 'hold'), (13, mix(S, H, .55), 'hold'), (14, H, 'hold'),
             (16, H, 'out'), (20, O, 'io'), (24, R, 'io'), (28, X(), 'lin')])


def warrior_chop(ctx, X):
    """Hit 19 of 35. Coils to its right and hauls the sword out wide past its right shoulder, blade up and
    out to the side (round 39 b: held over its head it hid under the helmet from the game camera), the free
    arm thrown out ahead at the target; holds it shaking; whips it across its front in two smeared drawings
    and ends low past its left foot, turned and squashed; stays down a beat, heaves it back to guard.
    Arms and blade by `aim` (az, el, twist): az 0 ahead, + to its left, el + up."""
    mix = ctx['mix']
    wide = {'upperarm.r': (-100, 25, 0), 'lowerarm.r': (-115, 70, 0), 'upperarm.l': (35, 5, 0), 'lowerarm.l': (45, 10, 0),
            'weapon': (-100, 35, 0)}
    A = X(hip=(0, .05, .0), hipr=(-24, -4, 0), spine=(-6, -4, 0), chest=(-18, -8, 0), head=(14, 10, 0), jaw=(0, 20, 0),
          root={'sq': -.07}, eye=.5, tl=-8, tr=-8, aim=wide, cloth=(0, -6, 0), **{'pauldron.r': (0, -12, 0)})
    A2 = add(A, hipr=(-6, 0, 0), chest=(-6, -4, 0), aim=dict(wide, **{'upperarm.r': (-110, 32, 0), 'lowerarm.r': (-125, 78, 0),
                                                                     'weapon': (-112, 42, 0)}))
    S = X(hip=(0, -.04, -.02), hipr=(4, 6, 0), spine=(4, 6, 0), chest=(10, 10, 0), head=(-6, -4, 0), jaw=(0, 28, 0),
          root={'sq': -.05}, eye=.3, scale={'hand.r': 1.5},
          aim={'upperarm.r': (-35, 10, 0), 'lowerarm.r': (-15, 5, 0), 'upperarm.l': (60, -20, 0), 'lowerarm.l': (80, -25, 0),
               'weapon': (-5, 5, 0)})
    H = X(hip=(0, -.1, -.12), hipr=(30, 6, 0), spine=(6, 2, 0), chest=(18, 4, 0), head=(-14, -10, 0), jaw=(0, 34, 0),
          root={'sq': .16}, eye=.35, scale={'hand.r': 1.25}, fr=_foot(ctx, 'r', 0, -.08, 0), fl=_foot(ctx, 'l', 0, .04, 0),
          aim={'upperarm.r': (55, -25, 0), 'lowerarm.r': (80, -30, 0), 'upperarm.l': (110, -40, 0), 'lowerarm.l': (140, -40, 0),
               'weapon': (100, -30, 0)},
          cloth=(0, 20, 0), **{'pauldron.r': (0, 12, 0), 'pauldron.l': (0, 12, 0)})
    O = add(H, hip=(0, 0, -.02), hipr=(8, 4, 0), root={'sq': .09}, cloth=(0, -16, 0),
            aim=dict(H['aim'], weapon=(115, -38, 0)))
    R = X(hip=(0, .02, .01), hipr=(-4, -6, 0), chest=(0, -6, 0), head=(0, 6, 0), root={'sq': -.03}, **{'upperarm.r': (0, -10, 0)})
    return ([(0, X(), 'out'), (6, A, 'hold')] + tremble(6, 16, A, A2, 1.5, mix=mix) +
            [(16, A2, 'hold'), (17, S, 'hold'), (18, mix(S, H, .6), 'hold'), (19, H, 'hold'),
             (22, H, 'io'), (25, O, 'io'), (30, R, 'io'), (35, X(), 'lin')])


def shield_bash(ctx, X):
    """Hit 17 of 33. Turns its shield shoulder away and sinks behind the shield, sword cocked high;
    drives off the back foot and rams the shield out ahead at full reach, swollen, stepping into it;
    rocks past, steps back."""
    mix = ctx['mix']
    X0 = X
    X = lambda **kw: X0(keep=('shield',), **kw)  # the shield stays square to the front, turning with the hips
    A = X(hip=(0, .07, -.08), hipr=(32, 6, 0), spine=(4, 4, 0), chest=(10, 4, 0), head=(-36, 10, 0), jaw=(0, 14, 0),
          root={'sq': .12}, eye=.5, cloth=(0, -8, 0),
          aim={'upperarm.l': (100, -40, 0), 'lowerarm.l': (30, -5, 0), 'upperarm.r': (-80, 40, 0), 'lowerarm.r': (-120, 70, 0)})
    A2 = add(A, hipr=(8, 0, 0), hip=(0, .02, -.01), head=(-8, 0, 0),
             aim=dict(A['aim'], **{'upperarm.l': (115, -40, 0), 'lowerarm.l': (45, -5, 0)}))
    S = X(hip=(0, -.14, -.03), hipr=(-6, 14, 0), chest=(-4, 6, 0), head=(4, 4, 0), jaw=(0, 24, 0), root={'sq': -.08},
          eye=.3, scale={'hand.l': 1.35}, fl=_foot(ctx, 'l', 0, -.14, .05), tl=10,
          aim={'upperarm.l': (30, -15, 0), 'lowerarm.l': (5, 0, 0), 'upperarm.r': (-80, 20, 0), 'lowerarm.r': (-110, 50, 0)})
    H = X(hip=(0, -.22, -.07), hipr=(-14, 16, 0), chest=(-6, 8, 0), head=(8, 0, 0), jaw=(0, 30, 0), root={'sq': .12},
          eye=.35, scale={'hand.l': 1.3}, fl=_foot(ctx, 'l', 0, -.24, 0), fr=_foot(ctx, 'r', 0, .04, 0), tr=-10, cloth=(0, 16, 0),
          aim={'upperarm.l': (5, -5, 0), 'lowerarm.l': (-5, 0, 0), 'upperarm.r': (-90, 10, 0), 'lowerarm.r': (-120, 30, 0)})
    O = add(H, hip=(0, -.03, -.02), hipr=(-6, 6, 0), root={'sq': .05}, cloth=(0, -12, 0))
    R = X(hip=(0, -.06, -.02), hipr=(4, 2, 0), root={'sq': -.02}, fl=_foot(ctx, 'l', 0, -.08, .06), **{'upperarm.l': (4, 6, 0)})
    return ([(0, X(), 'out'), (4, A, 'hold')] + tremble(4, 14, A, A2, 1.5, mix=mix) +
            [(14, A2, 'hold'), (15, S, 'hold'), (16, mix(S, H, .6), 'hold'), (17, H, 'hold'),
             (19, H, 'out'), (23, O, 'io'), (27, R, 'io'), (33, X(), 'lin')])


def rogue_stab(ctx, X):
    """Hits 11 (the game's) and 14 of 23. Drops low with both daggers raised over its shoulders, points
    back, glaring; lunges and punches the right dagger out swollen, then the left, scissoring the
    shoulders; skids back up into the crouch."""
    mix = ctx['mix']
    back = {'upperarm.l': (60, 55, 0), 'lowerarm.l': (10, 100, 0), 'weapon.l': (160, 35, 0),
            'upperarm.r': (-60, 55, 0), 'lowerarm.r': (-10, 100, 0), 'weapon.r': (-160, 35, 0)}
    A = X(hip=(0, .06, -.1), hipr=(0, 10, 0), chest=(0, 6, 0), head=(0, -14, 0), jaw=(0, 16, 0), root={'sq': .12}, eye=.45,
          aim=back, cloth=(0, -10, 0), **{'tail.l.0': (0, -10, 0), 'tail.r.0': (0, -10, 0)})
    A2 = add(A, hip=(0, .02, -.02), root={'sq': .14}, aim=dict(back, **{'weapon.l': (170, 20, 0), 'weapon.r': (-170, 20, 0)}))
    stab_r = {'upperarm.r': (-8, 0, 0), 'lowerarm.r': (2, 0, 0), 'weapon.r': (0, -4, 0)}
    stab_l = {'upperarm.l': (8, 0, 0), 'lowerarm.l': (-2, 0, 0), 'weapon.l': (0, -4, 0)}
    keep_l = {k: v for k, v in back.items() if k.endswith('.l')}
    pull_r = {'upperarm.r': (-100, -30, 0), 'lowerarm.r': (-150, 10, 0), 'weapon.r': (-170, 10, 0)}
    S1 = X(hip=(0, -.12, -.06), hipr=(14, 16, 0), chest=(18, 6, 0), head=(-14, -8, 0), jaw=(0, 24, 0), root={'sq': -.08},
           eye=.3, scale={'hand.r': 1.5}, aim=dict(keep_l, **{'upperarm.r': (-40, -15, 0), 'lowerarm.r': (-20, -5, 0), 'weapon.r': (-5, 0, 0)}))
    H1 = X(hip=(0, -.18, -.08), hipr=(22, 18, 0), chest=(24, 8, 0), head=(-20, -6, 0), jaw=(0, 30, 0), root={'sq': .08},
           eye=.35, scale={'hand.r': 1.3}, fr=_foot(ctx, 'r', 0, -.12, 0), cloth=(0, 14, 0), aim=dict(keep_l, **stab_r))
    S2 = X(hip=(0, -.2, -.08), hipr=(-10, 18, 0), chest=(-16, 8, 0), head=(12, -6, 0), jaw=(0, 26, 0), root={'sq': -.06},
           eye=.3, scale={'hand.l': 1.5}, fr=_foot(ctx, 'r', 0, -.12, 0),
           aim=dict(pull_r, **{'upperarm.l': (40, -15, 0), 'lowerarm.l': (20, -5, 0), 'weapon.l': (5, 0, 0)}))
    H2 = X(hip=(0, -.22, -.09), hipr=(-22, 20, 0), chest=(-24, 8, 0), head=(20, -6, 0), jaw=(0, 30, 0), root={'sq': .1},
           eye=.35, scale={'hand.l': 1.3}, fr=_foot(ctx, 'r', 0, -.12, 0), cloth=(0, 18, 0), aim=dict(pull_r, **stab_l))
    R = X(hip=(0, -.06, -.06), hipr=(4, 8, 0), head=(-4, -6, 0), root={'sq': .03}, **{'upperarm.l': (5, 15, 0), 'upperarm.r': (-5, 15, 0)})
    return ([(0, X(), 'out'), (3, A, 'hold')] + tremble(3, 9, A, A2, 2.0, mix=mix) +
            [(9, S1, 'hold'), (10, mix(S1, H1, .6), 'hold'), (11, H1, 'hold'), (12, H1, 'hold'), (13, S2, 'hold'), (14, H2, 'hold'),
             (16, H2, 'out'), (19, R, 'io'), (23, X(), 'lin')])


# ---- idles and light hits, every foe
def idle(**c):
    """Idle_Combat as a loop from frame 0 (= the guard, so every clip that starts or ends on the guard
    blends in): two breaths a loop (chest up, body stretched a touch, eyes narrowing on the breath),
    one weight shift from foot to foot (hips sway and roll over the planted feet), the weapon arm
    bobbing ready, the head glancing, the jaw chattering. Upper body on twos.
    sway m, roll / yaw / lean / breath / glance / tilt deg, sq, weapon {bone: deg}, jaw deg, squint 0..1."""
    def make(ctx):
        n = ctx['length']('Idle_Combat') or 36
        n = c.get('n', n)
        out = []
        for f in range(n + 1):
            ph = 2 * math.pi * f / n
            b = (1 - math.cos(2 * ph)) / 2          # 0 -> 1 -> 0 twice a loop
            s = math.sin(ph)
            p = {'hip': (c.get('sway', .03) * s, 0.0, -c.get('drop', .015) * b),
                 'hipr': (c.get('yaw', 4) * s, c.get('lean', 2) * b, -c.get('roll', 4) * s),
                 'spine': (0.0, -c.get('breath', 3) * .4 * b, 0.0),
                 'chest': (-c.get('yaw', 4) * .6 * s, -c.get('breath', 3) * b, c.get('roll', 4) * .5 * s),
                 'head': (c.get('glance', 8) * math.sin(ph + .6) - c.get('glance', 8) * math.sin(.6), c.get('breath', 3) * .5 * b,
                          c.get('tilt', 4) * s),
                 'jaw': (0.0, c.get('jaw', 6) * max(0.0, math.sin(4 * ph)), 0.0),
                 'root': {'sq': -c.get('sq', .015) * b},
                 'eye': 1 - c.get('squint', .25) * b}
            for bone, deg in c.get('weapon', {}).items():
                p[bone] = (0.0, deg * math.sin(2 * ph), 0.0)
            for bone, deg in c.get('cloth', {}).items():
                p[bone] = (0.0, deg * s, 0.0)
            if not ctx['HAS_LEGS']:
                p['hip'] = (p['hip'][0], 0.0, c.get('float', .03) * math.sin(ph))
            out.append(p)
        for f in range(1, n + 1, 2):  # upper body on twos
            for k in ('spine', 'chest', 'head', 'jaw', 'eye') + tuple(c.get('weapon', {})) + tuple(c.get('cloth', {})):
                if k in out[f]:
                    out[f][k] = out[f - 1][k]
        return out
    return make


def hit_a(T):
    """The light hit (half the ground flinches, at 1.6x): the head snapped back on frame 1 with the eyes
    squeezed shut and the jaw dropped, shoulders flinched up and back, a small squash; an overshoot,
    then a recoil forward past the guard, eyes open again by 70%."""
    def make(ctx):
        n = ctx['length']('Hit_A') or 14
        u = n / 14.0
        a = T.get('amp', 1.0)
        X = lambda **kw: _pose(T, ctx, **kw)
        keys = [
            (0, X(), 'hold'),
            (1, X(hip=(0, .03 * a, -.02), hipr=(0, -8 * a, 0), chest=(0, -12 * a, 0), head=(0, -34 * a, 8), jaw=(0, 22, 0),
                  root={'sq': .1 * a}, eye=0.0, arms=(-18 * T.get('fling', 1.0), 14 * T.get('fling', 1.0)), whip=-.6), 'hold'),
            (3, X(hip=(0, .04 * a, -.01), hipr=(0, -10 * a, 0), chest=(0, -14 * a, 0), head=(0, -40 * a, 10), jaw=(0, 26, 0),
                  root={'sq': -.04 * a}, eye=0.0, arms=(-24 * T.get('fling', 1.0), 18 * T.get('fling', 1.0)), whip=-.8), 'out'),
            (round(6 * u), X(hip=(0, .01, -.02), hipr=(0, 5 * a, 0), chest=(0, 6 * a, 0), head=(0, 10 * a, -3), jaw=(0, 8, 0),
                             root={'sq': .04}, eye=.1, arms=(6, 4), whip=.5), 'io'),
            (round(10 * u), X(hipr=(0, -2, 0), head=(0, -4, 0), eye=1.0), 'io'),
            (n, X(), 'lin'),
        ]
        return ctx['keyed'](keys, n)
    return make


# ---- ranged, the bomber and the Warden
MAGE_TELL = {'upperarm.r': (-70, 50, 0), 'lowerarm.r': (-110, 70, 0), 'staff': (-160, 40, 0),
             'upperarm.l': (35, -15, 0), 'lowerarm.l': (15, 15, 0)}


def mage_cast(ctx, X):
    """Spellcasting (the windup, 0.9 s at 1.2x; never loops): the staff swung up and back over its right
    shoulder, crystal behind its head, the free hand thrust out palm first, stretched tall and leaning
    back, eyes narrowed; held to the end on twos, trembling, the staff tipping further back."""
    mix = ctx['mix']
    A = X(chest=(0, -10, 0), spine=(0, -4, 0), head=(0, 12, 0), jaw=(0, 10, 0), root={'sq': -.06}, eye=.5, aim=MAGE_TELL,
          **{'coat.b': (0, -14, 0), 'mantle.b': (0, -8, 0), 'hat': (0, -8, 0)})
    A2 = add(A, chest=(0, -6, 0), root={'sq': -.08}, aim=dict(MAGE_TELL, staff=(-165, 28, 0), **{'upperarm.r': (-75, 58, 0)}))
    return [(0, X(), 'out'), (5, A, 'hold')] + tremble(5, 36, A, A2, 1.5, mix=mix) + [(36, A2, 'lin')]


def mage_shoot(ctx, X):
    """Spellcast_Shoot (the bolt leaves on frame 0, at 1.5x): from the tell, the staff thrown forward in
    one smeared drawing, the whole body behind it and squashed, held 2 frames; a recoil back past the
    guard, settled."""
    T2 = X(chest=(0, -16, 0), spine=(0, -4, 0), head=(0, 12, 0), root={'sq': -.08}, eye=.5,
           aim=dict(MAGE_TELL, staff=(-165, 28, 0), **{'upperarm.r': (-75, 58, 0)}))
    S = X(hip=(0, -.06, -.02), chest=(0, 12, 0), head=(0, -4, 0), jaw=(0, 24, 0), root={'sq': -.04}, eye=.3, scale={'hand.r': 1.45},
          aim={'upperarm.r': (-15, 25, 0), 'lowerarm.r': (-5, 25, 0), 'staff': (0, 30, 0), 'upperarm.l': (40, -30, 0)},
          **{'coat.b': (0, 14, 0)})
    H = X(hip=(0, -.1, -.05), chest=(0, 18, 0), head=(0, -10, 0), jaw=(0, 28, 0), root={'sq': .1}, eye=.35, scale={'hand.r': 1.25},
          aim={'upperarm.r': (-10, 5, 0), 'lowerarm.r': (0, 5, 0), 'staff': (0, 8, 0), 'upperarm.l': (50, -40, 0)},
          **{'coat.b': (0, 20, 0), 'hat': (0, 12, 0)})
    O = X(hip=(0, .03, 0), chest=(0, -8, 0), head=(0, 6, 0), root={'sq': -.03}, **{'coat.b': (0, -10, 0), 'hat': (0, -8, 0)})
    return [(0, T2, 'hold'), (1, S, 'hold'), (2, H, 'hold'), (4, H, 'out'), (9, O, 'io'), (18, X(), 'lin')]


NECRO_GATHER = {'upperarm.l': (60, -35, 0), 'lowerarm.l': (35, -60, 0), 'upperarm.r': (-55, -25, 0), 'lowerarm.r': (-30, -35, 0)}


def necro_gather(ctx, X):
    """Spellcasting (both windups; 0.8x for a raise, 1.2x for a curse; never loops): hunched over the
    floor, both clawed hands spread low and pulling, head up glaring, floating lower and trembling."""
    mix = ctx['mix']
    A = X(hip=(0, .02, -.08), chest=(0, 22, 0), spine=(0, 8, 0), head=(0, -24, 0), jaw=(0, 18, 0), eye=.45, keep=('staff',),
          aim=NECRO_GATHER, **{'skirt': (0, -8, 0), 'mantle.b': (0, 10, 0)})
    A2 = add(A, hip=(0, 0, -.03), chest=(0, 6, 0), aim=dict(NECRO_GATHER, **{'upperarm.l': (70, -45, 0), 'upperarm.r': (-65, -35, 0)}))
    return [(0, X(keep=('staff',)), 'out'), (6, A, 'hold')] + tremble(6, 36, A, A2, 2.0, mix=mix) + [(36, A2, 'lin')]


def necro_summon(ctx, X):
    """Spellcast_Summon (the raise, at 1.2x, 0.6 s of recover showing): from the gather, both arms ripped
    up overhead in one smeared drawing, the body stretched tall and the head thrown back, jaw wide; held
    shaking while the dead come up, a slump, the guard."""
    mix = ctx['mix']
    G = X(hip=(0, .02, -.11), chest=(0, 28, 0), spine=(0, 8, 0), head=(0, -24, 0), jaw=(0, 18, 0), eye=.45, keep=('staff',),
          aim=dict(NECRO_GATHER, **{'upperarm.l': (70, -45, 0), 'upperarm.r': (-65, -35, 0)}))
    up = {'upperarm.l': (45, 75, 0), 'lowerarm.l': (25, 105, 0), 'upperarm.r': (-45, 75, 0), 'lowerarm.r': (-25, 105, 0)}
    S = X(hip=(0, 0, .04), chest=(0, -4, 0), head=(0, -12, 0), jaw=(0, 30, 0), root={'sq': -.14}, eye=.3, keep=('staff',),
          scale={'hand.l': 1.4}, aim={'upperarm.l': (50, 40, 0), 'lowerarm.l': (30, 60, 0), 'upperarm.r': (-50, 40, 0), 'lowerarm.r': (-30, 60, 0)})
    H = X(hip=(0, .02, .08), chest=(0, -16, 0), spine=(0, -6, 0), head=(0, -30, 0), jaw=(0, 36, 0), root={'sq': -.1}, eye=.2,
          keep=('staff',), scale={'hand.l': 1.25}, aim=up, **{'skirt': (0, 12, 0), 'mantle.b': (0, -12, 0)})
    H2 = add(H, chest=(0, -4, 0), aim=dict(up, **{'lowerarm.l': (25, 115, 0), 'lowerarm.r': (-25, 115, 0)}))
    O = X(hip=(0, 0, -.06), chest=(0, 16, 0), head=(0, 8, 0), jaw=(0, 10, 0), root={'sq': .05}, keep=('staff',))
    return ([(0, G, 'hold'), (1, S, 'hold'), (2, H, 'hold')] + tremble(2, 12, H, H2, 2.5, mix=mix) +
            [(12, H2, 'io'), (17, O, 'io'), (24, X(keep=('staff',)), 'lin')])


def necro_shoot(ctx, X):
    """Spellcast_Shoot (the curse leaves on frame 0, at 1.5x): from the gather the ember hand is flung
    out at the hero, swollen, the left shoulder driven forward; held, a recoil, the guard."""
    G = X(hip=(0, .02, -.11), chest=(0, 28, 0), spine=(0, 8, 0), head=(0, -24, 0), jaw=(0, 18, 0), eye=.45, keep=('staff',),
          aim=dict(NECRO_GATHER, **{'upperarm.l': (70, -45, 0), 'upperarm.r': (-65, -35, 0)}))
    S = X(hip=(0, -.05, -.02), hipr=(-14, 6, 0), chest=(-14, 12, 0), head=(10, -10, 0), jaw=(0, 30, 0), eye=.3, keep=('staff',),
          scale={'hand.l': 1.6}, aim={'upperarm.l': (25, 10, 0), 'lowerarm.l': (12, 10, 0), 'upperarm.r': (-70, -20, 0)})
    H = X(hip=(0, -.08, -.03), hipr=(-20, 10, 0), chest=(-20, 14, 0), head=(16, -12, 0), jaw=(0, 34, 0), root={'sq': .08}, eye=.35,
          keep=('staff',), scale={'hand.l': 1.35}, aim={'upperarm.l': (8, 2, 0), 'lowerarm.l': (2, 0, 0), 'upperarm.r': (-75, -20, 0)})
    O = X(hip=(0, .02, .02), hipr=(6, -4, 0), chest=(6, -6, 0), root={'sq': -.03}, keep=('staff',))
    return [(0, G, 'hold'), (1, S, 'hold'), (2, H, 'hold'), (4, H, 'out'), (10, O, 'io'), (22, X(keep=('staff',)), 'lin')]


def bomber_fuse(ctx, X):
    """Bomb_Windup (the fuse, 1.5 s at 1x; it blows on the last frame): sinks and hugs itself giggling,
    the bomb on its back swelling, shaking harder and harder; a deep crouch, then sprung up off the floor
    arms flung up, stretched, the bomb at its biggest as it goes."""
    mix = ctx['mix']
    hug = {'upperarm.l': (60, -30, 0), 'lowerarm.l': (-30, -10, 0), 'upperarm.r': (-60, -30, 0), 'lowerarm.r': (30, -10, 0)}
    A = X(hip=(0, .02, -.05), chest=(0, 10, 0), head=(0, -10, 0), jaw=(0, 20, 0), root={'sq': .1}, eye=.4, aim=hug, scale={'bomb': 1.05})
    B = add(A, root={'sq': .13}, jaw=(0, 8, 0), scale={'bomb': 1.25})
    C = add(B, scale={'bomb': 1.35})
    D = X(hip=(0, .03, -.12), chest=(0, 18, 0), head=(0, -18, 0), jaw=(0, 30, 0), root={'sq': .2}, eye=.2, aim=hug, scale={'bomb': 1.4})
    flung = {'upperarm.l': (30, 80, 0), 'lowerarm.l': (20, 95, 0), 'upperarm.r': (-30, 80, 0), 'lowerarm.r': (-20, 95, 0)}
    U = X(hip=(0, 0, .14), chest=(0, -14, 0), head=(0, 14, 0), jaw=(0, 36, 0), root={'sq': -.16}, eye=0.0, aim=flung,
          scale={'bomb': 1.5}, fl=_foot(ctx, 'l', .03, 0, .14), fr=_foot(ctx, 'r', .03, 0, .14), tl=-30, tr=-30)
    return ([(0, X(), 'out'), (4, A, 'hold')] + tremble(4, 16, A, B, 2.0, mix=mix) + tremble(16, 28, B, C, 4.5, mix=mix) +
            [(28, C, 'in'), (31, D, 'hold'), (32, mix(D, U, .6), 'hold'), (33, U, 'hold'), (36, U, 'lin')])


def archer_aim(ctx, X):
    """2H_Ranged_Aiming (1.1 s windup, plays once and holds): the kit's draw (enemy_archer.py) with a body
    on it: a dip and a gather as the bow comes up, then rising into the full draw leaning back, eyes
    narrowed to slits; the held draw trembles on twos."""
    mix = ctx['mix']
    src = lambda f: ('2H_Ranged_Aiming', f)
    D = X(src=src(6), hip=(0, .02, -.05), chest=(0, 8, 0), head=(0, -6, 0), root={'sq': .08}, eye=.7)
    F = X(src=src(16), chest=(0, -8, 0), spine=(0, -3, 0), head=(0, 6, 0), root={'sq': -.04}, eye=.4, **{'cape.1': (0, -8, 0)})
    F2 = X(src=src(24), chest=(0, -11, 0), spine=(0, -4, 0), head=(0, 8, 0), root={'sq': -.05}, eye=.35, **{'cape.1': (0, -10, 0)})
    keys = [(0, X(src=src(0)), 'io'), (6, D, 'io'), (12, mix(D, F, .7), 'io')]
    for i, f in enumerate(range(16, 24, 2)):
        p = mix(F, F2, i / 3)
        s = 1.5 if i % 2 else -1.5
        p['upperarm.l'] = (s, 0.0, s * .5)
        p['head'] = tuple(a + b for a, b in zip(p['head'], (-s, 0, 0)))
        keys.append((f, p, 'hold'))
    return keys + [(24, F2, 'lin')]


def archer_shoot(ctx, X):
    """2H_Ranged_Shoot (the arrow leaves on frame 0, at 1.2x): the kit's loose with a kick through the
    body: thrown back on frame 1 by the string, eyes shut, squashed; an overshoot forward; the kit's
    reach for the next arrow."""
    src = lambda f: ('2H_Ranged_Shoot', f)
    n = ctx['length']('2H_Ranged_Shoot') or 32
    return [(0, X(src=src(0), chest=(0, -11, 0), head=(0, 8, 0), root={'sq': -.05}, eye=.35), 'hold'),
            (1, X(src=src(1), hip=(0, .05, -.02), hipr=(8, -8, 0), chest=(10, -18, 0), head=(0, -16, 0), jaw=(0, 20, 0),
                  root={'sq': .1}, eye=0.0, **{'cape.1': (0, 20, 0)}), 'hold'),
            (3, X(src=src(3), hip=(0, .06, -.02), hipr=(10, -10, 0), chest=(12, -20, 0), head=(0, -18, 0), jaw=(0, 16, 0),
                  root={'sq': -.03}, eye=0.0, **{'cape.1': (0, 24, 0)}), 'out'),
            (7, X(src=src(7), hip=(0, -.02, -.02), chest=(0, 10, 0), head=(0, 6, 0), root={'sq': .04}, eye=.8, **{'cape.1': (0, -10, 0)}), 'io'),
            (12, X(src=src(12)), 'lin'), (n, X(src=src(n)), 'lin')]


def warden_slam(ctx, X):
    """Attack_Slam: the kit's leap (enemy_warden.py, frames boss.gd COMIC_ATTACKS / COMIC_SLAM_AIR) with the
    squash it lacked: a deeper sink held on twos before take-off (24), stretched tall off the floor and in
    the air, flattened on the landing (37) and held, then the heave back up. Legs stay the kit's."""
    src = lambda f: ('Attack_Slam', f)
    n = ctx['length']('Attack_Slam') or 63
    P = lambda f, **kw: X(src=src(f), legs=False, **kw)
    return [(0, P(0), 'io'), (12, P(12, root={'sq': .06}), 'io'), (18, P(18, root={'sq': .14}, eye=.5), 'hold'),
            (20, P(20, root={'sq': .17}, eye=.45, head=(0, -6, 0)), 'hold'), (22, P(22, root={'sq': .19}, eye=.45), 'hold'),
            (24, P(24, root={'sq': -.12}, eye=.6), 'out'), (30, P(30, root={'sq': -.07}), 'io'), (36, P(36, root={'sq': -.1}), 'hold'),
            (37, P(37, root={'sq': .2}, eye=.3), 'hold'), (40, P(40, root={'sq': .16}, eye=.3), 'out'), (46, P(46, root={'sq': .03}), 'io'),
            (52, P(52, root={'sq': -.03}), 'io'), (n, P(n), 'lin')]


# ---- run start / stop one-shots (the fast ones: rogue, minion), as the hero's (heretic-hero.md Locomotion)
ACCEL = 25.0  # m/s^2: enemy.gd's move_toward rate in the chase, the ramp the feet are keyed against


def _ramp(v, t):
    """Ground covered t s after setting off from rest at ACCEL, capped at v."""
    t1 = v / ACCEL
    return .5 * ACCEL * t * t if t <= t1 else .5 * ACCEL * t1 * t1 + v * (t - t1)


def run_start(spec, n=6):
    """Run_Start: a crouch pitched in (2 frames, arms drawn back), the back foot planted and pushing while
    the front one swings through to the loop's frame-0 landing, which this clip ends on, so the run loop
    carries on from 0 with nothing to blend. The planted foot gives back the floor covered on the ramp."""
    def make(ctx):
        R0 = ctx['run_cycle'](spec)[0]
        v = spec['v']
        T = n / ctx['FPS']
        X = lambda **kw: _pose({}, ctx, **kw)
        C = X(hip=(0, .04, -.08 - spec.get('drop', .05) * .5), hipr=(0, spec.get('lean', 12) + 14, 0), chest=(0, 6, 0),
              head=(0, -spec.get('lean', 12) * .8, 0), root={'sq': .12}, eye=.7,
              **{'upperarm.l': (0, 40, -10), 'upperarm.r': (0, 40, 10), 'lowerarm.l': (0, -20, 0), 'lowerarm.r': (0, -20, 0)})
        keys = [(0, X(), 'out'), (2, C, 'io'), (n, R0, 'lin')]
        out = ctx['keyed'](keys, n)
        if ctx['HAS_LEGS']:
            st = ctx['STANCE']
            for f, p in enumerate(out):
                k = _ramp(v, f / ctx['FPS']) / max(_ramp(v, T), 1e-6)
                r1 = R0['fr']
                p['fr'] = (st['r'].x + (r1[0] - st['r'].x) * k, st['r'].y + (r1[1] - st['r'].y) * k, st['r'].z + (r1[2] - st['r'].z) * k)
                p['tr'] = -spec.get('push', 12) * k
                s = min(max((f - 2) / (n - 2), 0.0), 1.0)
                l1 = R0['fl']
                p['fl'] = (st['l'].x + (l1[0] - st['l'].x) * s, st['l'].y + (l1[1] - st['l'].y) * s,
                           st['l'].z + (l1[2] - st['l'].z) * s + spec.get('lift', .1) * 1.2 * math.sin(math.pi * s))
                p['tl'] = R0.get('tl', 0.0) * s + 10 * math.sin(math.pi * s)
        return out
    return make


def run_stop(spec, n=9):
    """Run_Stop: the skid. Both feet sliding (the front braced toes up, the back dragged on its toes),
    the body squashed and thrown back, then pitched forward past upright with the arms flung through,
    a hop of the back foot into the stance, settled on the guard (Idle_Combat frame 0)."""
    def make(ctx):
        R0 = ctx['run_cycle'](spec)[0]
        X = lambda **kw: _pose({}, ctx, **kw)
        lean = spec.get('lean', 12)
        st = ctx['STANCE']
        F = lambda side, dy, dz=0.0: _foot(ctx, side, 0, dy, dz)
        S = X(hip=(0, .06, -.08), hipr=(0, -12, 0), chest=(0, -10, 0), head=(0, 6, 0), root={'sq': .12}, eye=.6,
              fl=F('l', -.22), fr=F('r', .2), tl=24, tr=-20,
              **{'upperarm.l': (0, -40, -20), 'upperarm.r': (0, -40, 20)})
        S2 = add(S, hip=(0, -.02, .02), fl=F('l', -.2), fr=F('r', .16))
        P = X(hip=(0, -.03, -.06), hipr=(0, lean * .6, 0), chest=(0, 18, 0), head=(0, 10, 0), root={'sq': .05}, eye=.8,
              fl=F('l', -.2), fr=F('r', .1, .06), tl=6,
              **{'upperarm.l': (0, -60, -10), 'upperarm.r': (0, -60, 10), 'lowerarm.l': (0, -30, 0), 'lowerarm.r': (0, -30, 0)})
        B = X(hip=(0, .01, -.01), hipr=(0, -3, 0), chest=(0, -4, 0), fl=F('l', -.06), **{'upperarm.l': (0, 8, 0), 'upperarm.r': (0, 8, 0)})
        keys = [(0, R0, 'out'), (2, S, 'lin'), (3, S2, 'io'), (5, P, 'io'), (7, B, 'io'), (n, X(), 'lin')]
        return ctx['keyed'](keys, n)
    return make


def twist_probe(bone, base_aim, others=None):
    """Debug: 8 drawings of one aimed bone twisted 0..315 (sheet=Twist)."""
    def build(ctx, X):
        keys = []
        for i in range(8):
            am = dict(others or {})
            am[bone] = (base_aim[0], base_aim[1], i * 45)
            keys.append((i * 2, X(aim=am), 'hold'))
        keys.append((16, X(aim=am), 'lin'))
        return keys
    return clip(16, build)


ROUND2 = {
    'minion': {'1H_Melee_Attack_Chop': clip(28, minion_swipe),
               'Idle_Combat': idle(sway=.03, yaw=5, lean=4, breath=4, glance=12, jaw=10, weapon={'upperarm.r': 4}, cloth={'cloth': 5})},
    'warrior': {'1H_Melee_Attack_Chop': clip(35, warrior_chop),
                'Idle_Combat': idle(sway=.04, roll=5, lean=3, breath=5, glance=6, jaw=4, sq=.02, weapon={'upperarm.r': 3},
                                    cloth={'cloth': 4})},
    'shield': {'1H_Melee_Attack_Chop': clip(33, shield_bash),
               'Idle_Combat': idle(sway=.045, roll=6, breath=4, glance=8, jaw=5, weapon={'upperarm.r': 4}, cloth={'cloth': 4})},
    'rogue': {'1H_Melee_Attack_Chop': clip(23, rogue_stab),
              'Idle_Combat': idle(n=24, sway=.02, yaw=6, lean=5, breath=5, glance=14, tilt=8, jaw=6,
                                  weapon={'upperarm.l': 5, 'upperarm.r': -5}, cloth={'cloth': 6, 'tail.l.0': 6, 'tail.r.0': -6})},
    'archer': {'2H_Ranged_Aiming': clip(24, archer_aim), '2H_Ranged_Shoot': clip(32, archer_shoot),
               'Idle_Combat': idle(sway=.025, breath=3, glance=10, jaw=4, weapon={'upperarm.r': 3}, cloth={'cape.1': 5, 'loin': 4})},
    'mage': {'Spellcasting': clip(36, mage_cast), 'Spellcast_Shoot': clip(18, mage_shoot),
             'Idle_Combat': idle(sway=.02, breath=3, glance=6, jaw=4, squint=.3, weapon={'upperarm.r': 3},
                                 cloth={'coat.b': 4, 'mantle.b': 3})},
    'bomber': {'Bomb_Windup': clip(36, bomber_fuse),
               'Idle_Combat': idle(n=16, sway=.05, roll=8, breath=6, sq=.04, jaw=12, glance=10, cloth={'cloth': 6})},
    'necromancer': {'Spellcasting': clip(36, necro_gather), 'Spellcast_Summon': clip(24, necro_summon),
                    'Spellcast_Shoot': clip(22, necro_shoot),
                    'Idle_Combat': idle(float=.04, breath=3, glance=6, jaw=6, squint=.3, weapon={'upperarm.l': 5}, cloth={'skirt': 5})},
    'warden': {'Attack_Slam': clip(63, warden_slam),
               'Idle_Combat': idle(sway=.05, roll=3, breath=4, glance=5, jaw=4, sq=.02, weapon={'upperarm.r': 2},
                                   cloth={'cape': 3, 'tabard': 3}),
               'Hit_A': hit_a(dict(HEAVY, amp=.5, fling=.4, whip={'tabard': 20, 'cape': 25}))},
}
for _k, _run in (('rogue', 'Running_C'), ('minion', 'Running_A')):
    ROUND2[_k]['Run_Start'] = run_start(FOES[_k][_run].spec)
    ROUND2[_k]['Run_Stop'] = run_stop(FOES[_k][_run].spec)
for _k, _v in ROUND2.items():
    FOES[_k].update(_v)

import os as _os
for _i, _pr in enumerate(_os.environ.get('PROBE', '').split(';') if _os.environ.get('PROBE') else []):
    # debug: PROBE="bone:az,el:{others};..." adds clips Twist0, Twist1 (sheet=Twist0,Twist1)
    _b, _a, _o = _pr.split(':', 2)
    _az, _el = (float(x) for x in _a.split(','))
    FOES[_os.environ['PROBE_FOE']]['Twist%d' % _i] = twist_probe(_b, (_az, _el), eval(_o or '{}'))
