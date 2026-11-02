# Skeleton Minion, the comic-style template for every enemy. Big skull, cage ribs, hunched, rusty cleaver.
#   blender -b -P enemy_minion.py
# Front -Y, its left +X, up +Z. One file per enemy: geometry, rig, animations, sheets, export.
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V
NAME = 'minion'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['rust'] = C.toon('P_Rust', (.14, .04, .03), (.55, .24, .09), (.8, .45, .2), (1, .82, .55), rim=(.3, .12, .04), brush=.3)
C.rng.seed(4)
B = {k: C.Bag(k) for k in ('bone', 'socket', 'teeth', 'iron', 'leather', 'cloth', 'necro', 'rust')}
b = B['bone']

# skeleton joints: hunched, chin forward, wide low stance, the cleaver arm cocked
hip = V((0, .02, .72)); chest = V((0, -.08, 1.12)); neck = V((0, -.2, 1.3)); H = V((.0, -.3, 1.5))
shL, elL, wrL, hdL = V((.3, -.1, 1.22)), V((.46, -.12, .95)), V((.5, -.3, .76)), V((.5, -.36, .68))
shR, elR, wrR, hdR = V((-.3, -.1, 1.22)), V((-.54, .02, 1.12)), V((-.62, -.2, 1.3)), V((-.64, -.26, 1.38))
hpL, knL, anL = V((.15, .02, .68)), V((.27, -.14, .4)), V((.25, .02, .1))
hpR, knR, anR = V((-.15, .02, .68)), V((-.27, -.14, .4)), V((-.25, .02, .1))

# ---- skull: too big, the read at game distance
C.blob(b, H + V((0, .02, .06)), (.2, .22, .18), seg=14, rings=9)
C.blob(b, H + V((0, -.12, -.03)), (.135, .1, .1), seg=12, rings=7)                 # face
for sx in (-1, 1):
    C.blob(b, H + V((sx * .13, -.09, -.02)), (.05, .05, .045), seg=8, rings=5)      # cheek
    C.tube(b, [H + V((sx * .03, -.19, .085)), H + V((sx * .1, -.185, .1)), H + V((sx * .17, -.12, .09))], [.03, .036, .018], sides=6, sub=2)  # brow: the snarl
    C.blob(B['socket'], H + V((sx * .075, -.185, .025)), (.062, .03, .056 if sx > 0 else .05), seg=10, rings=6)
    C.blob(B['necro'], H + V((sx * .075, -.208, .025)), (.022, .012, .022), seg=8, rings=5, t=.9)
C.blob(B['socket'], H + V((0, -.215, -.045)), (.024, .012, .03), seg=7, rings=5)     # nose hole
for i in range(7):
    x = -.09 + i * .03
    C.blob(B['teeth'], H + V((x, -.2 + abs(x) * .4, -.1)), (.0135, .012, .022), seg=6, rings=4)
# jaw: separate, hangs open and crooked
J0 = H + V((0, -.1, -.13))
C.tube(b, [H + V((-.13, -.04, -.07)), J0 + V((-.1, -.04, -.03)), J0 + V((0, -.1, -.05)), J0 + V((.1, -.04, -.03)), H + V((.13, -.04, -.07))], [.024, .032, .036, .032, .024], sides=6, sub=2)
for i in range(5):
    x = -.06 + i * .03
    C.blob(B['teeth'], J0 + V((x, -.1 + abs(x) * .4, -.015)), (.012, .011, .018), seg=6, rings=4)
# a skull crack, painted as a dark wedge
C.tube(B['socket'], [H + V((.05, -.12, .2)), H + V((.09, -.15, .15)), H + V((.07, -.18, .11)), H + V((.1, -.2, .08))], [.012, .008, .005, .001], sides=5, sub=1)
# helmet scrap on one side: asymmetry
C.blob(B['rust'], H + V((-.07, .03, .17)), (.16, .17, .085), seg=12, rings=6)
C.tube(B['rust'], [H + V((-.2, .0, .19)), H + V((-.3, .01, .3)), H + V((-.33, .02, .42))], [.035, .02, .002], sides=5, sub=2)

# ---- spine and ribs: a cage you can see through
vb = [hip.lerp(chest, i / 5) + V((0, .03 * math.sin(i), 0)) for i in range(6)]
for i, p in enumerate(vb):
    C.blob(b, p + V((0, .05, 0)), (.05, .05, .036), seg=8, rings=5)
C.tube(b, [chest + V((0, .05, 0)), neck, H + V((0, .03, -.1))], [.04, .034, .034], sides=6, sub=2)
for i in range(4):
    z = chest.z + .08 - i * .08
    w = .25 - i * .022
    for sx in (-1, 1):
        C.tube(b, [V((sx * .01, -.02, z + .03)), V((sx * w * .8, .0, z)), V((sx * w, -.14, z - .05)), V((sx * w * .45, -.235, z - .08)), V((sx * .02, -.25 + i * .012, z - .06))], [.018, .022, .02, .018, .014], sides=5, sub=2)
C.tube(b, [V((0, -.255, chest.z + .05)), V((0, -.235, chest.z - .28))], [.03, .02], sides=5, sub=1)  # sternum
# collar + shoulder bar
C.tube(b, [shL, V((0, -.16, 1.27)), shR], [.028, .022, .028], sides=6, sub=2)
# pelvis: bowl
C.blob(b, hip + V((0, 0, -.03)), (.21, .14, .1), seg=12, rings=6, p=2.3)
C.blob(B['socket'], hip + V((0, -.11, -.05)), (.075, .05, .055), seg=8, rings=5)

# ---- limbs: thin shafts, knobby joints
def limb(a, c, r=.032, k=.052):
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5); C.blob(b, c, (k * .85, k * .85, k * .85), seg=8, rings=5)
limb(shL, elL); limb(elL, wrL, .028, .042); limb(shR, elR); limb(elR, wrR, .028, .042)
limb(hpL, knL, .042, .066); limb(knL, anL, .034, .05); limb(hpR, knR, .042, .066); limb(knR, anR, .034, .05)
def hand(w, d, side):
    C.blob(b, w + d * .05, (.05, .05, .04), seg=8, rings=5)
    for i in range(3):
        o = side * (i - 1) * .032
        C.tube(b, [w + d * .06 + o, w + d * .13 + o * 1.2, w + d * .2 + o * 1.3 - V((0, 0, .02))], [.016, .013, .004], sides=5, sub=1)
hand(wrL, (hdL - wrL).normalized(), V((1, 0, 0)))
hand(wrR, (hdR - wrR).normalized(), V((1, 0, 0)))
def foot(an):
    C.blob(b, an + V((0, -.06, -.06)), (.07, .12, .035), seg=8, rings=5)
    for i in range(3):
        o = V(((i - 1) * .036, -.17, -.075))
        C.tube(b, [an + V((o.x, -.12, -.065)), an + o], [.018, .006], sides=5, sub=1)
foot(anL); foot(anR)

# ---- loincloth and strap: the bit of colour
for i in range(7):
    a = -2.6 + i * .34
    o = V((math.cos(a), math.sin(a) * .8, 0))
    q = hip + V((o.x * .2, o.y * .15 - .02, -.04))
    L = C.rng.uniform(.2, .34)
    C.tube(B['cloth'], [q, q + o * .03 - V((0, 0, L * .5)), q + o * .05 - V((0, 0, L))], [(.05, .006), (.054, .007), (.002, .002)], sides=5, sub=2, side=o.cross(V((0, 0, 1))))
C.tube(B['leather'], [hip + V((.2 * math.cos(i * .524), .15 * math.sin(i * .524) - .01, .025)) for i in range(13)], [(.012, .03)] * 2, sides=6, sub=1, side=V((0, 0, 1)))
C.tube(B['leather'], [shL + V((-.02, -.03, .04)), chest + V((0, -.26, .03)), hip + V((-.2, -.09, .03))], [(.03, .008), (.03, .008)], sides=5, sub=2, side=V((1, 0, 0)))

# ---- rusty cleaver: oversized, held up
grip = hdR + V((0, 0, .02)); up = V((-.05, -.25, 1)).normalized(); fw = V((-.1, -1, -.25)).normalized()
C.tube(B['leather'], [grip - up * .13, grip, grip + up * .18], [.024, .022, .024], sides=6, sub=1)
base = grip + up * .17
blade = [(0, 0), (.1, -.02), (.32, .02), (.34, .22), (.2, .6), (.05, .68), (-.04, .5), (-.045, .2)]
vs = []; n_ = len(blade)
for th in (1, -1):
    vs += [base + fw * x + up * y + V((.018 * th, 0, 0)) * (1 if x < .24 else .3) for x, y in blade]
fs = [tuple(range(n_)), tuple(reversed(range(n_, 2 * n_)))] + [(i, (i + 1) % n_, n_ + (i + 1) % n_, n_ + i) for i in range(n_)]
B['rust'].add(vs, fs)

col = scn.collection
objs = {}
for k, bag in B.items():
    if not bag.v: continue
    outline = 0 if k in ('socket', 'necro', 'teeth') else .006
    objs[k], t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()))

# ------------------------------------------------------------------ rig
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, -.02, .12)), 'root'),
    'spine': (hip + V((0, -.02, .12)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .02, -.15)), H + V((0, -.02, .25)), 'chest'),
    'jaw': (H + V((0, -.03, -.08)), J0 + V((0, -.12, -.03)), 'head'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'weapon': (grip, grip + up * .5, 'hand.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.18, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.18, -.08)), 'lowerleg.r'),
    'cloth': (hip + V((0, -.1, -.04)), hip + V((0, -.12, -.34)), 'hips'),
}
R = CR.Rig('MinionRig', bones)
UP = ('hips', 'spine', 'chest', 'head', 'upperarm.l', 'lowerarm.l', 'hand.l', 'upperarm.r', 'lowerarm.r', 'hand.r', 'upperleg.l', 'lowerleg.l', 'foot.l', 'upperleg.r', 'lowerleg.r', 'foot.r')
R.skin_islands(objs['bone'], UP + ('jaw',))
R.skin_fixed(objs['necro'], 'head')
R.skin_islands(objs['socket'], ('head', 'hips'))
R.skin_islands(objs['teeth'], ('head', 'jaw'))
R.skin_islands(objs['leather'], ('hips', 'chest', 'hand.r', 'weapon'))
R.skin_soft(objs['cloth'], ('hips', 'cloth'), power=3)
R.skin_islands(objs['rust'], ('head', 'weapon'))
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ animation (24 fps)
TW = {'hips': {'rot': (6, 0, 0), 'loc': (0, 0, -.03)}, 'chest': (8, 0, 0), 'head': (-8, 0, 0)}
def P(*ds):
    out = {}
    for d in ds: out.update(d)
    return out
IDLE_A = P(TW, {'upperarm.r': (0, 6, 0), 'lowerarm.r': (6, 0, 0), 'jaw': (4, 0, 0), 'upperarm.l': (0, 0, 4), 'head': (-8, 4, 3)})
IDLE_B = P({'hips': {'rot': (9, 0, 0), 'loc': (0, 0, -.07)}, 'chest': (14, 0, -3), 'head': (-12, 0, -3)}, {'upperarm.r': (0, 10, 0), 'lowerarm.r': (12, 0, 0), 'jaw': (-5, 0, 0), 'upperarm.l': (5, 0, 8), 'upperleg.l': (-5, 0, 0), 'lowerleg.l': (10, 0, 0), 'upperleg.r': (-5, 0, 0), 'lowerleg.r': (10, 0, 0)})
R.action('Idle_Combat', 36, {0: IDLE_A, 18: IDLE_B, 36: IDLE_A})
# run: a loose shamble, bones flopping behind the beat
def run(s):
    return {'hips': {'rot': (14, 0, s * 5), 'loc': (0, -.03, -.05 + .04 * abs(s))}, 'chest': (10, 0, -s * 14), 'head': (-14, 0, s * 8), 'jaw': (-8 - 8 * abs(s), 0, 0),
            'upperleg.l': (s * 44, 0, 0), 'lowerleg.l': (-max(0, s) * 8 + max(0, -s) * -60, 0, 0), 'upperleg.r': (-s * 44, 0, 0), 'lowerleg.r': (-max(0, -s) * 8 + max(0, s) * -60, 0, 0),
            'upperarm.l': (-s * 40, 0, 6), 'lowerarm.l': (-14, 0, 0), 'upperarm.r': (s * 18, 8, 0), 'lowerarm.r': (10, 0, 0), 'cloth': (s * 14 + 16, 0, 0)}
R.action('Running_A', 16, {0: run(1), 8: run(-1), 16: run(1)})
# chop: big anticipation, smear down, hold on the hit, slow recover
WIND = {'hips': {'rot': (-8, 0, 12), 'loc': (0, .06, -.02)}, 'chest': (-18, 0, 22), 'head': (10, 0, -14), 'upperarm.r': (-46, 0, -18), 'lowerarm.r': (-32, 0, 0), 'upperarm.l': (20, 0, 14), 'jaw': (-22, 0, 0)}
HIT = {'hips': {'rot': (22, 0, -14), 'loc': (0, -.22, -.14)}, 'chest': (32, 0, -30), 'head': (-22, 0, 18), 'upperarm.r': (88, 0, 28), 'lowerarm.r': (34, 0, 0), 'hand.r': (28, 0, 0), 'upperarm.l': (-30, 0, -14), 'jaw': (14, 0, 0), 'upperleg.l': (-28, 0, 0), 'lowerleg.l': (10, 0, 0), 'upperleg.r': (34, 0, 0), 'lowerleg.r': (-44, 0, 0), 'cloth': (-18, 0, 0)}
R.action('1H_Melee_Attack_Chop', 30, {0: IDLE_A, (10, 'out'): WIND, (13, 'in'): HIT, 18: HIT, 30: IDLE_A})
HURT = {'hips': {'rot': (-16, 0, 6), 'loc': (0, .1, -.02)}, 'chest': (-22, 0, 10), 'head': (24, 0, -16), 'jaw': (-30, 0, 0), 'upperarm.l': (-30, 0, 30), 'upperarm.r': (-24, 0, -22), 'cloth': (20, 0, 0)}
R.action('Hit_A', 14, {0: IDLE_A, (2, 'hold'): HURT, 14: IDLE_A})
# death: the bones lose their string and collapse into a heap
D1 = {'hips': {'rot': (-10, 0, 8), 'loc': (0, .08, -.1)}, 'chest': (-20, 0, 12), 'head': (26, 0, -20), 'jaw': (-36, 0, 0), 'upperarm.l': (-40, 0, 30), 'upperarm.r': (-60, 0, -20)}
D2 = {'hips': {'rot': (30, 0, 8), 'loc': (0, .05, -.5)}, 'chest': (46, 0, 16), 'head': (30, 20, -30), 'jaw': (-40, 0, 0), 'upperarm.l': (40, 0, 60), 'lowerarm.l': (30, 0, 0), 'upperarm.r': (10, 30, -60), 'upperleg.l': (-70, 0, 30), 'lowerleg.l': (120, 0, 0), 'upperleg.r': (-60, 0, -35), 'lowerleg.r': (110, 0, 0), 'weapon': (60, 0, 40)}
R.action('Death_A', 34, {0: IDLE_A, (4, 'hold'): D1, (20, 'in'): D2, 34: D2})
# spawn: claws up out of the floor
S0 = {'hips': {'rot': (40, 0, 0), 'loc': (0, 0, -.95)}, 'chest': (30, 0, 0), 'head': (-20, 0, 0), 'upperarm.l': (-110, 0, 30), 'upperarm.r': (-60, 0, -10)}
R.action('Spawn_Ground_Skeletons', 26, {0: S0, (20, 'out'): TW, 26: IDLE_A})

# launch recovery and the second flinch, which enemy.gd plays
R.action('Hit_B', 14, {0: IDLE_A, (2, 'hold'): {'hips': {'rot': (12, 0, -8), 'loc': (0, -.06, -.02)}, 'chest': (20, 0, -14), 'head': (-22, 0, 18)}, 14: IDLE_A})
_LIE = {'hips': {'rot': (-82, 0, 0), 'loc': (0, .15, -.6)}, 'chest': (-6, 0, 0), 'head': (10, 0, 0)}
_KNEEL = {'hips': {'rot': (-20, 0, 0), 'loc': (0, .05, -.3)}, 'chest': (30, 0, 0), 'head': (-10, 0, 0)}
R.action('Lie_StandUp', 32, {0: _LIE, (8, 'hold'): _LIE, (20, 'out'): _KNEEL, (32, 'in'): IDLE_A})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.0, -5.6, 1.4), (0, -.1, .92), lens=58)
game = C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .75), ortho=3.6)
side = C.camera('CamSide', (-5.4, -1.6, 1.3), (0, -.1, .9), lens=58)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
CR.contact_sheet(R, [('Idle_Combat', 18), ('Running_A', 0), ('Running_A', 8), ('1H_Melee_Attack_Chop', 10), ('1H_Melee_Attack_Chop', 14), ('Hit_A', 2), ('Death_A', 10), ('Death_A', 30), ('Spawn_Ground_Skeletons', 0), ('Spawn_Ground_Skeletons', 10)], side, os.path.join(OUT, NAME + '_motion.png'), cols=5, tile_w=384)
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME)
