# The brazier (env piece `brazier`): a standing iron bowl on three legs, coals and a flame cap, about 1.3 m.
#   blender -b -P tools/comic_art/env_brazier.py   -> brazier.glb (lit) + brazier_spilled.glb, shots, in env_extra.OUT
# brazier.glb nodes: `brazier` (bowl, legs, rim teeth, the skull), `brazier_coals` (glowing, comic_ember),
# `brazier_ash` (the same coals dark, a hair smaller, under the glowing ones: hide `brazier_coals` and the bowl reads
# "out"), `brazier_flame` (the flame cap, comic_fire; a designed effect can replace it later).
# brazier_spilled.glb: the bowl on its side, legs up, the coals thrown in a 2 m patch toward -Y (Godot +Z at yaw 0),
# small flames on them. Same pivot: the brazier's foot centre.
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import env_extra as X
from env_extra import C, E
from mathutils import Vector as V, Matrix

RIM = .9      # bowl rim height
R_RIM = .6    # bowl rim radius (chibi: wide and shallow)
LEGS = 3


def bowl(p):
    """Bowl, legs, teeth, skull into p's `brazier` node bags. Returns the bags used."""
    r = p.r; ir = p.b('iron'); bo = p.b('bone', smooth=True); ink = p.b('ink'); vo = p.b('void')
    # outside of the bowl, over the lip, down the inside to the coal bed (the top face is the bed)
    E.lathe(ir, [(.12, .58, .4), (.3, .62, .42), (.48, .72, .46), (.58, .84, .5), (R_RIM + .04, RIM, .55),
                 (R_RIM + .04, RIM + .06, .55), (R_RIM - .04, RIM + .07, .5), (R_RIM - .08, RIM - .04, .45)],
            sides=10, r=r, rj=.015, top=True, bottom=True)
    # a heavy band under the lip, raised so its hull ink reads as a second line
    E.lathe(ir, [(R_RIM - .02, .76, .4), (R_RIM + .02, .79, .42), (R_RIM + .02, .84, .42), (R_RIM - .02, .87, .4)], sides=10, top=False)
    # rim teeth: five short blunt spikes, leaning out (the badass silhouette from above)
    for k in range(5):
        a = math.pi / 2 + (k + .5) * 2 * math.pi / 5
        ca, sa = math.cos(a), math.sin(a)
        base = V((ca * (R_RIM + .01), sa * (R_RIM + .01), RIM + .04))
        tip = base + V((ca * .1, sa * .1, .2))
        C.tube(ir, [base, base * .5 + tip * .5, tip], [.055, .04, .006], sides=4, sub=1)
    # three legs: out from under the bowl, splayed, a claw foot each
    for k in range(LEGS):
        a = -math.pi / 2 + math.pi / LEGS + k * 2 * math.pi / LEGS
        ca, sa = math.cos(a), math.sin(a)
        pts = [V((ca * .24, sa * .24, .68)), V((ca * .44, sa * .44, .42)), V((ca * .56, sa * .56, .12)), V((ca * .6, sa * .6, .02))]
        C.tube(ir, pts, [.06, .055, .045, .05], sides=6, sub=2)
        C.blob(ir, (ca * .62, sa * .62, .05), (.1, .1, .06), seg=7, rings=4)
        for s in (-1, 1):   # claw toes
            ta = a + s * .5
            C.tube(ir, [V((ca * .62, sa * .62, .04)), V((ca * .62 + math.cos(ta) * .15, sa * .62 + math.sin(ta) * .15, .01))], [.03, .008], sides=4, sub=1)
    # a ring tying the legs halfway down
    E.lathe(ir, [(.43, .38, .4), (.45, .41, .4), (.43, .44, .4)], sides=9, top=False)
    # the one accent: a bone skull on the front of the bowl (front = -Y, toward the game camera)
    S = V((0, -.6, .74))
    C.blob(bo, S, (.13, .1, .12), seg=10, rings=7)
    C.blob(bo, S + V((0, -.03, -.09)), (.08, .06, .055), seg=8, rings=5)
    for sx in (-1, 1):
        C.blob(vo, S + V((sx * .05, -.09, .02)), (.035, .02, .035), seg=7, rings=4)
    # ink on the bowl: hatch on the side away from the key, a dent crack at the front
    Fbowl = lambda u, v, w: V((u, -w, v))
    E.hatch(ink, lambda u, v, w: V((w, u, v)), r, .1, .7, .52, ang=2.35, n=5, length=.16, gap=.04, width=.014)
    E.crack(ink, Fbowl, r, .28, .86, .59, -1.9, .22, .016, 1)
    return [ir, bo, vo, ink]


def coals(p, node, mat, tone_fn, scale=1.0, z=RIM - .02):
    r = random.Random(77)
    b = p.b(mat, node=node)
    C.rng.seed(99)
    for i in range(9):
        a = i * 2.4; d = (.08 + .32 * ((i * .37) % 1)) * scale
        n0 = len(b.v)
        C.rock(b, (math.cos(a) * d, math.sin(a) * d, z + .03), (.13 * scale, .12 * scale, .08 * scale), sub=1, jit=.25)
        X.tones(b, n0, tone_fn(i))
    n0 = len(b.v)
    C.rock(b, (0, 0, z + .06), (.22 * scale, .2 * scale, .1 * scale), sub=1, jit=.2)
    X.tones(b, n0, tone_fn(-1))
    return b


def flame_cap(p, base=RIM + .04, node='brazier_flame'):
    fi = p.b('fire', node=node); r = random.Random(5)
    E.flame(fi, 0, 0, base, .4, .26, r)
    E.flame(fi, .17, -.08, base, .27, .14, r)
    E.flame(fi, -.18, .05, base, .24, .13, r)
    E.flame(fi, .02, .18, base, .2, .11, r)
    return fi


def lit():
    p = E.Piece('brazier')
    bowl(p)
    coals(p, 'brazier_coals', 'ember', lambda i: .85 if i in (-1, 2, 5) else (.55 if i % 2 else .3))
    coals(p, 'brazier_ash', 'grout', lambda i: .5, scale=.95, z=RIM - .035)
    flame_cap(p)
    return p


def spilled():
    p = E.Piece('brazier_spilled')
    used = bowl(p)
    # tip it over on its side, the mouth to -Y where the coals went, legs to +Y
    m = Matrix.Translation((.1, .55, 0)) @ Matrix.Rotation(math.radians(15), 4, 'Z') @ Matrix.Rotation(math.radians(96), 4, "X")
    X.xform(used, m)
    # keep it on the floor
    lo = min(v.z for b in used for v in b.v)
    X.xform(used, Matrix.Translation((0, 0, -lo)))
    # the coals in a 2 m patch ahead of its mouth, flat on the floor, a few still burning
    r = random.Random(11); b = p.b('ember', node='brazier_coals'); C.rng.seed(12)
    for i in range(22):
        a = r.uniform(-1.3, 1.3) - math.pi / 2; d = r.uniform(.2, 1.15)
        x, y = math.cos(a) * d * 1.05, math.sin(a) * d - .35
        s = r.uniform(.07, .14)
        n0 = len(b.v)
        C.rock(b, (x, y, s * .4), (s, s * .9, s * .55), sub=1, jit=.25)
        X.tones(b, n0, r.choice((.3, .55, .55, .85)))
    fi = p.b('fire', node='brazier_flame')
    for x, y, h in ((-.15, -.6, .3), (.32, -.85, .24), (.02, -1.15, .2), (-.48, -1.0, .18)):
        E.flame(fi, x, y, .02, h, h * .55, r)
    # scorch strokes on the floor under the patch
    w = p.b('wash')
    for k in range(6):
        a = -math.pi / 2 + (k - 2.5) * .45
        E.stroke(w, [(math.cos(a) * .2, math.sin(a) * .2 - .2, .006), (math.cos(a) * .7, math.sin(a) * .7 - .2, .006), (math.cos(a) * 1.15, math.sin(a) * 1.1 - .2, .006)], .09, (0, 0, 1), r)
    return p


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    X.clear_scene(); X.materials()
    for name, fn in (('brazier', lit), ('brazier_spilled', spilled)):
        if argv and name not in argv:
            continue
        X.clear_scene()
        root = X.finish_natural(fn())
        X.export(root, name)
        X.shots(root, name, extent=2.2)
