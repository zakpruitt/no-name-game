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
    return lambda ctx: ctx['run_cycle'](c)


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
    return {'Hit_B': hit_b(T), 'Lie_StandUp': lie_stand_up(T), 'Death_A': death_a(T)}


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
