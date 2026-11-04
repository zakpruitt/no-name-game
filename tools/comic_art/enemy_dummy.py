# Training dummy, comic chibi style (round 29): a cartoon punching bag that waddles, takes a beating and
# looks dazed doing it. Pale canvas sack tied off at the top, red straps and a bullseye, big googly eyes,
# a cheeky buck-toothed grin, a plaster cross on its head, stubby legs and red boxing gloves.
#   blender -b -P enemy_dummy.py
# Front -Y, its left +X, up +Z. Feet on z = 0. Same clip names as the skeletons (enemy.gd plays them),
# plus Dazed (pupils spin, head wobbles) for training_dummy._shake_off. Eyes shut on a hit: the eye
# bones' scale is keyed on every clip (1 = open), so a hit never leaves them shut in the engine.
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V
NAME = 'dummy'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['canvas'] = C.toon('P_Canvas', (.44, .24, .2), (.86, .7, .48), (1, .92, .72), (1, .98, .86), rim=(.5, .3, .2), brush=.22)
M['red'] = C.toon('P_BagRed', (.26, .02, .07), (.7, .08, .09), (.96, .22, .13), (1, .5, .32), rim=(.32, .04, .06), brush=.16)
M['rope'] = C.toon('P_Rope', (.3, .14, .05), (.72, .5, .2), (.96, .8, .4), rim=(.3, .16, .05), brush=.24)
M['boot'] = C.toon('P_Boot', (.12, .07, .1), (.38, .27, .3), (.62, .5, .48), rim=(.2, .12, .14), brush=.2)
C.rng.seed(11)
B = {k: C.Bag(m) for k, m in (('bag', 'canvas'), ('limb', 'canvas'), ('red', 'red'), ('strap', 'red'), ('rope', 'rope'), ('boot', 'boot'),
                              ('white', 'eye_white'), ('pupil', 'pupil'), ('mouth', 'socket'), ('teeth', 'teeth'), ('brow', 'black'), ('tape', 'teeth'))}

# ---- the sack: one fat pear, remeshed into a single surface so it bends like a bag
BAG_Z, BAG_R = 1.08, (.52, .48, .7)
C.blob(B['bag'], (0, 0, BAG_Z), BAG_R, seg=28, rings=18, p=2.2)
C.blob(B['bag'], (0, .02, .78), (.58, .54, .4), seg=28, rings=14, p=2.2)    # the heavy bottom
C.tube(B['bag'], [V((0, 0, 1.72)), V((0, 0, 1.86)), V((0, 0, 1.92))], [.2, .09, .1], sides=14, sub=3)  # neck of the sack
for i in range(5):  # the tied-off tuft: five fat lumps splaying up
    a = i / 5 * 6.283 + .4
    d = V((math.cos(a), math.sin(a), 0))
    C.tube(B['bag'], [V((0, 0, 1.9)), V((0, 0, 1.96)) + d * .08, V((0, 0, 2.06)) + d * .2], [.07, .06, .015], sides=8, sub=3)
C.tube(B['rope'], [V((.105 * math.cos(i * .524), .105 * math.sin(i * .524), 1.88)) for i in range(13)], [(.028, .028)] * 2, sides=6, sub=1)

def surf(z, ang, lift=0.0):
    """A point on the front of the sack at height z, ang radians round from the front (-Y), lifted off it."""
    k = max(0.0, 1 - ((z - BAG_Z) / BAG_R[2]) ** 2) ** .5
    rx, ry = BAG_R[0] * k ** .9, BAG_R[1] * k ** .9
    n = V((math.sin(ang) * rx, -math.cos(ang) * ry, 0))
    return V((0, 0, z)) + n + n.normalized() * lift

# red straps round the middle and the waist
for z in (1.0, .66):
    rx, ry = (.585, .545) if z < .8 else (.535, .495)
    if z < .8: rx, ry = .6, .56
    C.tube(B['strap'], [V((rx * math.cos(i * .3927), ry * math.sin(i * .3927) + .01, z)) for i in range(17)], [(.035, .075)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
# bullseye on the belly: closed lens shapes, not flat patches (the game culls what Blender shows)
BE = V((0, -.53, .83))
C.blob(B['red'], BE, (.2, .045, .2), seg=18, rings=8)
C.blob(B['limb'], BE + V((0, -.012, 0)), (.13, .045, .13), seg=16, rings=8)
C.blob(B['red'], BE + V((0, -.024, 0)), (.06, .045, .06), seg=12, rings=6)

# ---- the face, high and tipped up so the game camera sees it
EZ = 1.5
eyes = {}
for sx, side in ((1, 'l'), (-1, 'r')):
    c = surf(EZ, sx * .32, .02)
    eyes[side] = c
    C.blob(B['white'], c, (.14, .07, .16), seg=16, rings=10)                     # googly eye
    C.blob(B['pupil'], c + V((sx * -.02, -.07, -.01)), (.055, .03, .06), seg=10, rings=6)
    C.tube(B['brow'], [c + V((sx * .13, -.02, .19)), c + V((sx * .02, -.07, .22)), c + V((sx * -.1, -.06, .17))], [.022, .03, .018], sides=6, sub=2)  # cocky brow
MZ = 1.25
mouth = surf(MZ, 0, .0)
C.blob(B['mouth'], mouth + V((0, -.02, 0)), (.18, .05, .11), seg=16, rings=8, p=2.4)   # open grin, a bit cocky
C.blob(B['red'], mouth + V((.03, -.05, -.055)), (.09, .03, .045), seg=10, rings=6)       # tongue
for sx in (-1, 1):
    C.blob(B['teeth'], mouth + V((sx * .045, -.065, .07)), (.042, .02, .045), seg=8, rings=5, p=2.6)  # buck teeth off the top lip
# plaster cross on its head: it has been hit before
pc = surf(1.66, -.55, .01)
for r in (.7, -.7):
    C.blob(B['tape'], pc, (.16, .02, .04), seg=10, rings=5, p=3, rot=(0, r, -.5))

# ---- stubby limbs, big gloves and boots
shL, elL, wrL = V((.5, -.02, 1.16)), V((.66, -.1, .98)), V((.64, -.26, .9))
shR, elR, wrR = V((-.5, -.02, 1.16)), V((-.66, -.1, .98)), V((-.64, -.26, .9))
hpL, knL, anL = V((.22, 0, .5)), V((.26, -.04, .28)), V((.26, 0, .12))
hpR, knR, anR = V((-.22, 0, .5)), V((-.26, -.04, .28)), V((-.26, 0, .12))
for a, b_, c in ((shL, elL, wrL), (shR, elR, wrR)):
    C.tube(B['limb'], [a + (a - b_).normalized() * .05, b_, c], [.085, .075, .07], sides=10, sub=3)
for sx, w in ((1, wrL), (-1, wrR)):
    g = w + V((0, -.1, .02))
    C.blob(B['red'], g, (.15, .17, .15), seg=16, rings=10, p=2.2)              # boxing glove
    C.blob(B['red'], g + V((sx * -.12, -.05, .05)), (.06, .07, .06), seg=10, rings=6)  # thumb
    C.tube(B['rope'], [w + V((0, .02, 0)) + V((.085 * math.cos(i * .785), 0, .085 * math.sin(i * .785))) for i in range(9)], [(.022, .03)] * 2, sides=6, sub=1)  # cuff
for a, b_, c in ((hpL, knL, anL), (hpR, knR, anR)):
    C.tube(B['limb'], [a, b_, c], [.1, .09, .085], sides=10, sub=3)
for an in (anL, anR):
    C.blob(B['boot'], an + V((0, -.07, -.04)), (.14, .21, .09), seg=14, rings=8, p=2.3)

col = scn.collection
objs = {}
for k, bag in B.items():
    if not bag.v: continue
    outline = 0 if k in ('pupil', 'mouth', 'teeth', 'tape', 'white') else .006
    if k == 'bag':
        objs[k], t = C.make_obj(k, bag, M, col, voxel=.025, smooth_iter=2, decim=.22, outline=outline)
    else:
        objs[k], t = C.make_obj(k, bag, M, col, outline=outline)
    objs[k].data.validate()
print('tris', C.tris())

# ------------------------------------------------------------------ rig
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (V((0, 0, .45)), V((0, 0, .76)), 'root'),
    'spine': (V((0, 0, .76)), V((0, 0, 1.1)), 'hips'),
    'chest': (V((0, 0, 1.1)), V((0, 0, 1.42)), 'spine'),
    'head': (V((0, 0, 1.42)), V((0, 0, 1.95)), 'chest'),
    'knot': (V((0, 0, 1.86)), V((0, 0, 2.08)), 'head'),
    'jaw': (mouth + V((0, .05, .03)), mouth + V((0, -.12, -.03)), 'head'),
    'eye.l': (eyes['l'], eyes['l'] + V((0, -.12, 0)), 'head'),
    'eye.r': (eyes['r'], eyes['r'] + V((0, -.12, 0)), 'head'),
    'pupil.l': (eyes['l'] + V((-.02, -.07, -.01)), eyes['l'] + V((-.02, -.15, -.01)), 'eye.l'),
    'pupil.r': (eyes['r'] + V((.02, -.07, -.01)), eyes['r'] + V((.02, -.15, -.01)), 'eye.r'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, wrL + V((0, -.2, .02)), 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, wrR + V((0, -.2, .02)), 'lowerarm.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.2, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.2, -.08)), 'lowerleg.r'),
}
R = CR.Rig('DummyRig', bones)
SACK = ('hips', 'spine', 'chest', 'head', 'knot')
R.skin_soft(objs['bag'], SACK, power=4)
R.skin_soft(objs['strap'], ('hips', 'spine', 'chest'), power=4)
# rope: the knot's tie and the two cuffs
R.skin_islands(objs['rope'], ('knot', 'hand.l', 'hand.r'))
R.skin_islands(objs['red'], ('spine', 'hand.l', 'hand.r', 'jaw'))
R.skin_islands(objs['limb'], ('spine', 'upperarm.l', 'lowerarm.l', 'upperarm.r', 'lowerarm.r', 'upperleg.l', 'lowerleg.l', 'upperleg.r', 'lowerleg.r'))
R.skin_islands(objs['boot'], ('foot.l', 'foot.r'))
R.skin_islands(objs['white'], ('eye.l', 'eye.r'))
R.skin_islands(objs['pupil'], ('pupil.l', 'pupil.r'))
for k in ('mouth', 'teeth'):
    R.skin_fixed(objs[k], 'jaw')

for k in ('brow', 'tape'):
    R.skin_fixed(objs[k], 'head')
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ animation (24 fps)
# Every clip keys every bone (rotation), the hips and pupils' position, and the eyes' scale: a track
# a clip leaves out keeps the last clip's value in the engine.
BASE = {n: (0, 0, 0) for n in bones}
BASE['hips'] = {'rot': (0, 0, 0), 'loc': (0, 0, 2e-5)}
for n in ('pupil.l', 'pupil.r'):
    BASE[n] = {'rot': (0, 0, 0), 'loc': (0, 0, 2e-5)}
def P(*ds):
    out = dict(BASE)
    for d in ds: out.update(d)
    return out
def eyes_open(a, keys=None):
    """Scale keys on the eyes: keys = [(frame, open 0..1)], default open throughout."""
    keys = keys or [(0, 1.0)]
    for side in ('l', 'r'):
        pb = R.obj.pose.bones['eye.' + side]
        for idx in range(3):
            fc = a.fcurve_ensure_for_datablock(R.obj, pb.path_from_id('scale'), index=idx)
            for f, o in keys:
                # bone axes: y runs out of the face, z is up the eye; shutting squashes z, widens x a touch
                v = (1 + .25 * (1 - o)) if idx == 0 else (1.0 if idx == 1 else max(.08, o))
                kp = fc.keyframe_points.insert(f, v); kp.interpolation = 'LINEAR'
            fc.update()
    return a
def clip(name, length, keys, eyes=None):
    full = {k: P(p) for k, p in keys.items()}
    return eyes_open(R.action(name, length, full), eyes)

GUARD = {'upperarm.l': (-40, 0, 14), 'lowerarm.l': (-50, 0, 0), 'upperarm.r': (-40, 0, -14), 'lowerarm.r': (-50, 0, 0)}
IDLE_A = P(GUARD, {'spine': (0, 0, 3), 'chest': (2, 0, 3), 'head': (-4, 0, 2), 'knot': (0, 6, 0)})
IDLE_B = P(GUARD, {'hips': {'rot': (0, 0, 0), 'loc': (0, 0, -.03)}, 'spine': (4, 0, -3), 'chest': (4, 0, -4), 'head': (-2, 0, -4), 'knot': (0, -8, 0),
                   'upperarm.l': (-46, 0, 18), 'upperarm.r': (-34, 0, -10), 'lowerarm.r': (-58, 0, 0)})
clip('Idle_Combat', 36, {0: IDLE_A, 18: IDLE_B, 36: IDLE_A}, eyes=[(0, 1), (27, 1), (29, .1), (31, 1), (36, 1)])  # a blink
# waddle home: hops from foot to foot, the sack rolling over each one
def run(s):
    return P(GUARD, {'hips': {'rot': (6, 0, s * 9), 'loc': (0, 0, .05 * abs(s))}, 'spine': (4, 0, -s * 8), 'chest': (4, 0, -s * 6), 'head': (-6, 0, s * 6), 'knot': (-10, s * 14, 0),
                     'upperleg.l': (s * 38, 0, 0), 'lowerleg.l': (max(0, -s) * -40, 0, 0), 'upperleg.r': (-s * 38, 0, 0), 'lowerleg.r': (max(0, s) * -40, 0, 0),
                     'upperarm.l': (-40 - s * 22, 0, 14), 'upperarm.r': (-40 + s * 22, 0, -14)})
clip('Running_A', 16, {0: run(1), 4: P(run(0), {'hips': {'rot': (6, 0, 0), 'loc': (0, 0, -.02)}}), 8: run(-1), 12: P(run(0), {'hips': {'rot': (6, 0, 0), 'loc': (0, 0, -.02)}}), 16: run(1)})
# hit: the sack folds back round the blow, arms fly, eyes squeezed shut
HURT_A = P({'hips': {'rot': (-6, 0, 0), 'loc': (0, .06, -.02)}, 'spine': (-16, 0, 4), 'chest': (-18, 0, 4), 'head': (-14, 0, -6), 'knot': (-30, 0, 10), 'jaw': (12, 0, 0),
            'upperarm.l': (-70, 0, 50), 'lowerarm.l': (-20, 0, 0), 'upperarm.r': (-60, 0, -44), 'lowerarm.r': (-24, 0, 0), 'upperleg.l': (10, 0, 0), 'upperleg.r': (10, 0, 0)})
clip('Hit_A', 14, {0: IDLE_A, (2, 'hold'): HURT_A, (6, 'out'): P(HURT_A, {'spine': (-8, 0, 2), 'chest': (-8, 0, 2)}), 14: IDLE_A}, eyes=[(0, 1), (1, 1), (2, .08), (8, .08), (11, 1)])
HURT_B = P({'hips': {'rot': (0, 0, -8), 'loc': (0, .03, -.02)}, 'spine': (-6, 0, -16), 'chest': (-8, 6, -18), 'head': (0, -12, -14), 'knot': (0, 30, -20), 'jaw': (16, 0, 0),
            'upperarm.l': (-30, 0, 60), 'upperarm.r': (-80, 0, -30), 'lowerarm.r': (-10, 0, 0)})
clip('Hit_B', 14, {0: IDLE_A, (2, 'hold'): HURT_B, 14: IDLE_A}, eyes=[(0, 1), (1, 1), (2, .08), (8, .08), (11, 1)])
# flat on its back, legs in the air, then boings upright past vertical and settles
LIE = P({'hips': {'rot': (-84, 0, 0), 'loc': (0, .3, -.2)}, 'spine': (-4, 0, 0), 'chest': (-2, 0, 0), 'head': (8, 0, 0), 'knot': (20, 0, 0), 'jaw': (10, 0, 0),
         'upperarm.l': (-10, 0, 70), 'upperarm.r': (-10, 0, -70), 'upperleg.l': (-60, 0, 10), 'lowerleg.l': (30, 0, 0), 'upperleg.r': (-50, 0, -10), 'lowerleg.r': (20, 0, 0)})
UP = P(GUARD, {'hips': {'rot': (14, 0, 0), 'loc': (0, -.05, .08)}, 'spine': (10, 0, 0), 'chest': (8, 0, 0), 'head': (-10, 0, 0), 'knot': (-30, 0, 0)})
clip('Lie_StandUp', 32, {0: LIE, (8, 'hold'): LIE, (16, 'in'): UP, (24, 'out'): P(IDLE_A, {'hips': {'rot': (-6, 0, 0), 'loc': (0, 0, -.04)}}), 32: IDLE_A},
     eyes=[(0, .08), (10, .08), (12, 1)])
D2 = P(LIE, {'head': (20, 0, 18), 'jaw': (24, 0, 0), 'upperarm.l': (20, 0, 80), 'upperarm.r': (20, 0, -80)})
clip('Death_A', 30, {0: IDLE_A, (4, 'hold'): HURT_A, (18, 'in'): D2, 30: D2}, eyes=[(0, 1), (3, .08), (30, .08)])
# pops up out of a squashed heap
SQ = P({'hips': {'rot': (0, 0, 0), 'loc': (0, 0, -.34)}, 'spine': (20, 0, 0), 'chest': (16, 0, 0), 'head': (-14, 0, 0), 'upperleg.l': (-70, 0, 20), 'lowerleg.l': (110, 0, 0), 'upperleg.r': (-70, 0, -20), 'lowerleg.r': (110, 0, 0)})
clip('Spawn_Ground_Skeletons', 24, {0: SQ, (10, 'out'): UP, 24: IDLE_A}, eyes=[(0, .08), (9, .08), (11, 1)])
# dazed: pupils spin round the eyes, the head lolls, the sack wobbles, arms dangle
def daze(t):
    a = t * 6.283
    pl = (.035 * math.cos(a), 0, .035 * math.sin(a))
    pr = (.035 * math.cos(a + 3.1), 0, .035 * math.sin(-a))
    return P({'hips': {'rot': (0, 0, 4 * math.sin(a)), 'loc': (0, 0, -.03)}, 'spine': (4, 0, -6 * math.sin(a)), 'chest': (4 * math.cos(a), 0, -8 * math.sin(a)),
              'head': (-6 + 6 * math.cos(a), 0, 14 * math.sin(a)), 'knot': (0, 24 * math.sin(a), 0), 'jaw': (14, 0, 0),
              'pupil.l': {'rot': (0, 0, 0), 'loc': pl}, 'pupil.r': {'rot': (0, 0, 0), 'loc': pr},
              'upperarm.l': (-10, 0, 20 + 8 * math.sin(a)), 'lowerarm.l': (-14, 0, 0), 'upperarm.r': (-10, 0, -20 + 8 * math.sin(a)), 'lowerarm.r': (-14, 0, 0)})
clip('Dazed', 24, {f: daze(f / 24) for f in range(0, 25, 3)})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.0, -5.6, 1.4), (0, -.1, 1.0), lens=50)
game = C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .85), ortho=3.6)
side = C.camera('CamSide', (-5.4, -1.6, 1.3), (0, -.1, 1.0), lens=50)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
CR.contact_sheet(R, [('Idle_Combat', 18), ('Idle_Combat', 29), ('Running_A', 0), ('Running_A', 8), ('Hit_A', 3), ('Hit_B', 3), ('Lie_StandUp', 4), ('Lie_StandUp', 16),
                     ('Dazed', 6), ('Dazed', 18)], hero, os.path.join(OUT, NAME + '_motion.png'), cols=5, tile_w=384)
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME, 'tris', C.tris())
