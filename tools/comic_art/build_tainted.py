# The shaman with the darkness getting in: build_comic's body, and his elements turning at the root. Magma, fire and
# lightning each fall to violet-black in their lowest tone, the arm's magma from the shoulder down, and a few black veins lit
# violet run where you can see them. Corruption stays a minor note: the design is still the elements.
#   blender -b -P build_tainted.py -- stills [hero side back game face]
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import importlib, comic_lib as C
importlib.reload(C)
import build_comic
from mathutils import Vector as V
from mathutils.bvhtree import BVHTree

ARM_L = ('upperarm.l', 'lowerarm.l', 'wrist.l', 'hand.l')
ARM_R = ('upperarm.r', 'lowerarm.r', 'wrist.r', 'hand.r')
TORSO = ('hips', 'spine', 'chest')
LEG_R = ('upperleg.r', 'lowerleg.r')
HINTS = {}    # object name -> [(first vertex, bone or tuple of bones)]; rig_comic skins those vertices to them
bags = {}

def K(name, bones):
    b = bags[name]
    HINTS.setdefault(name, []).append((len(b.v), bones))
    return b

def surface(names):
    verts, polys = [], []
    for n in names:
        me = bpy.data.objects[n].data; off = len(verts)
        verts += [v.co.copy() for v in me.vertices]
        polys += [[i + off for i in p.vertices] for p in me.polygons]
    return BVHTree.FromPolygons(verts, polys)

def vein(tree, pts, w, bones, ray=None, n=5, jag=.012, lift=.002):
    """A black vein with a violet core, lying on the surface, tapering from its first point to nothing."""
    path = C.catmull([V(p) for p in pts], n)
    on, nrm = [], []
    for p in path:
        p = p + V((C.rng.uniform(-jag, jag), C.rng.uniform(-jag, jag), C.rng.uniform(-jag, jag)))
        q, no = None, None
        if ray:
            q, no, _, _ = tree.ray_cast(p - V(ray) * 1.2, V(ray))
        if q is None:
            q, no, _, _ = tree.find_nearest(p)
        on.append(q); nrm.append(no)
    k = len(on)
    r = [max(w * (1 - (i / (k - 1)) ** 1.6), .0015) for i in range(k)]
    C.tube(K('blight', bones), [q + no * lift for q, no in zip(on, nrm)], r, sides=5, sub=1, tval=.5)
    C.tube(K('fracture', bones), [q + no * (lift + r_ * .72) for q, no, r_ in zip(on, nrm, r)], [max(r_ * .42, .001) for r_ in r], sides=4, sub=1, tval=1.0)

def tongue(base, tip, w, bones):
    """A lick of dark flame: black, violet at the heart."""
    base, tip = V(base), V(tip)
    mid = base.lerp(tip, .55) + V((C.rng.uniform(-.05, .05), C.rng.uniform(-.05, .05), 0))
    C.tube(K('blight', bones), [base, mid, tip], [w, w * .72, .002], sides=6, sub=3, tval=.5)
    C.tube(K('fracture', bones), [base, base.lerp(mid, .8)], [w * .5, .002], sides=5, sub=2, tval=1.0)

def spark(a, e, w, bones, steps=7, amp=.05):
    """A violet arc among the storm's blue: one thin jagged line."""
    a, e = V(a), V(e)
    pts = [a.lerp(e, i / (steps - 1)) + V((C.rng.uniform(-amp, amp), C.rng.uniform(-amp, amp), C.rng.uniform(-amp, amp))) * (0 if i in (0, steps - 1) else 1) for i in range(steps)]
    C.tube(K('fracture', bones), pts, [w * .4, w, w, w * .4], sides=4, sub=1, tval=1.0)

def taint(J):
    B_ = C.rng
    worn = surface(('skin', 'iron', 'leather', 'bronze'))
    skin = surface(('skin',))
    rock = surface(('rock',))
    ice = surface(('ice',))
    head = surface(('head',))
    ms, me_, mw, mf = J['ms'], J['me'], J['mw'], J['mf']
    sh, el, wr, hd = J['sh'], J['el'], J['wr'], J['hd']
    H = J['H']
    # 1. It has crossed his chest and come out from under the beard, on the side the beard doesn't hide.
    front = (0, 1, 0)
    vein(worn, [(-.04, 0, 1.4), (-.12, 0, 1.36), (-.17, 0, 1.28), (-.24, 0, 1.22)], .024, TORSO, ray=front)
    vein(worn, [(-.12, 0, 1.36), (-.2, 0, 1.42), (-.27, 0, 1.4)], .017, TORSO, ray=front)
    vein(worn, [(-.1, 0, 1.2), (-.17, 0, 1.13), (-.16, 0, 1.06)], .016, TORSO, ray=front)
    # 2. The magma arm is where it started: obsidian among the rock, veins through what's left.
    for P0, P1, f, off, s in ((ms, me_, .25, (.13, -.08, .02), .075), (ms, me_, .72, (.15, -.06, 0), .07), (me_, mw, .3, (.14, -.07, 0), .07),
                              (me_, mw, .75, (.13, -.1, -.01), .062), (mw, mf, .4, (.12, -.09, .02), .06), (ms, me_, .5, (.02, -.15, .02), .06)):
        c = P0.lerp(P1, f) + V(off)
        C.rock(K('blight', ARM_L), c, (s, s * .85, s * 1.1), sub=2)
    # the big shoulder rock is the arm's one clean face, and it's where this began
    vein(rock, [ms + V((.03, -.28, .22)), ms + V((.1, -.3, .1)), ms + V((.14, -.28, -.04)), ms + V((.2, -.24, -.16))], .027, ARM_L, n=4, lift=.012, jag=.006)
    vein(rock, [ms + V((.1, -.3, .1)), ms + V((.2, -.25, .14)), ms + V((.29, -.17, .1))], .019, ARM_L, n=4, lift=.012, jag=.006)
    vein(rock, [ms + V((.14, -.28, -.04)), ms + V((.04, -.3, -.11))], .015, ARM_L, n=4, lift=.012, jag=.006)
    # ...and in his fire, two tongues burn black.
    tongue(mf + V((.09, -.09, .1)), mf + V((.15, -.08, .5)), .05, 'hand.l')
    tongue(mf + V((-.08, -.02, .08)), mf + V((-.13, .0, .4)), .04, 'hand.l')
    # 3. The storm hand: it's reached the fingers and is climbing the forearm. One bolt in the blue has turned.
    vein(skin, [wr.lerp(el, .45) + V((-.07, -.07, 0)), el + V((-.09, -.07, 0)), el.lerp(sh, .45) + V((-.1, -.07, 0)), el.lerp(sh, .8) + V((-.08, -.07, 0))], .023, ARM_R, n=4)
    vein(skin, [el + V((-.09, -.07, 0)), el.lerp(sh, .3) + V((-.02, -.1, 0)), el.lerp(sh, .55) + V((.02, -.09, 0))], .015, ARM_R, n=4)
    spark(el + V((-.1, -.08, .02)), hd + V((-.12, -.1, .14)), .013, ARM_R)
    # 4. The ice leg: black cracks inside the blue, from the hip down.
    hr, kr, tr = J['hr'], J['kr'], J['tr']
    vein(ice, [hr + V((-.06, -.12, -.04)), hr.lerp(kr, .5) + V((-.07, -.09, 0)), kr + V((-.05, -.08, 0)), kr.lerp(tr, .4) + V((-.03, -.06, 0))], .02, LEG_R, n=4)
    vein(ice, [hr.lerp(kr, .35) + V((.07, -.1, 0)), hr.lerp(kr, .8) + V((.07, -.07, 0))], .014, LEG_R, n=4)
    # 5. The voice: from the rock ear through the temple to the lava eye.
    vein(head, [H + V((.125, -.01, .01)), H + V((.12, -.07, .035)), H + V((.09, -.115, .015)), H + V((.075, -.125, -.01))], .009, 'head', n=4, jag=.003)

def build_all():
    scn = bpy.context.scene
    for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
    C.ink_material()
    mats = C.materials()
    mats['fracture'] = C.emit('P_Fracture', (.34, .1, .62), (.82, .55, 1))
    mats['blight'] = C.toon('P_Blight', (.015, .01, .03), (.07, .035, .12), (.2, .12, .34), rim=(.3, .1, .5), brush=.12)
    # his own elements, not the ones the enemies use: the same hot tones, with violet-black where the cool one was
    mats['lava'] = C.emit('P_LavaDark', (.2, .04, .28), (1, .86, .2), mid=(1, .28, .02))
    mats['fire'] = C.emit('P_FireDark', (.14, .03, .2), (1, .9, .2), mid=(.95, .1, .02))
    mats['bolt'] = C.emit('P_BoltDark', (.42, .16, .78), (.98, 1, .92), mid=(.3, .6, 1))
    mats['haft'] = C.toon('P_Haft', (.08, .04, .04), (.27, .14, .09), (.46, .28, .16), rim=(.08, .04, .03), brush=.2)
    C.rng.seed(11)
    B = C.build()
    J = C.JOINTS
    for k, b in B.items():
        if k in ('rock', 'lava') or k.startswith('fire'):
            C.scale_about(b.v, J['mf'], 1.3, .55)
        if k in ('skin', 'bone') or k.startswith('bolt'):
            C.scale_about(b.v, J['hd'], 1.22, .32)
    for b in B.values():
        b.v = [build_comic.warp(p) for p in b.v]
    for k in list(J): J[k] = build_comic.warp(J[k])
    # the arm's magma has gone dark from the shoulder and is still hot at the fist; the wobble keeps the line from looking ruled
    lava = B['lava']; ms_z = J['ms'].z; mf_z = J['mf'].z
    for i, p in enumerate(lava.v):
        if p.x < .2: continue
        f = (ms_z - p.z) / (ms_z - mf_z) + .09 * math.sin(p.x * 31) + .07 * math.sin(p.y * 43 + p.z * 17)
        lava.t[i] = .2 if f < .34 else (.55 if f < .8 else .9)
    col = scn.collection
    tot = 0; rep = {}
    for k, b in B.items():
        if not b.v: continue
        if k == 'skin': o, t = C.make_obj('skin', b, mats, col, voxel=.0085, smooth_iter=14, outline=.006, decim=.09)
        elif k == 'head': o, t = C.make_obj('head', b, mats, col, voxel=.0055, smooth_iter=8, outline=.005, decim=.12)
        elif b.mat in ('lava', 'bolt', 'wind', 'eye_white', 'eye_blue', 'pupil', 'socket', 'teeth', 'black'):
            o, t = C.make_obj(k, b, mats, col, outline=0)
        elif b.mat in ('fire', 'spirit'): o, t = C.make_obj(k, b, mats, col, outline=.004)
        else: o, t = C.make_obj(k, b, mats, col, outline=.006)
        tot += t; rep[k] = t
    bags.clear(); HINTS.clear()
    bags['blight'] = C.Bag('blight'); bags['fracture'] = C.Bag('fracture')
    taint(J)
    for k, b in bags.items():
        o, t = C.make_obj(k, b, mats, col, outline=0)
        tot += t; rep[k] = t
    print('TAINTED tris', tot, dict(sorted(rep.items(), key=lambda kv: -kv[1])))
    C.comic_scene()
    cams = {'hero': C.camera('CamHero', (1.2, -6.8, 1.6), (-.02, -.15, 1.12), lens=52),
            'side': C.camera('CamSide', (-5.2, -1.8, 1.4), (-.05, -.2, 1.1), lens=58),
            'back': C.camera('CamBack', (-1.4, 3.6, 1.6), (0, 0, 1.1), lens=58),
            'game': C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .95), ortho=3.6),
            'face': C.camera('CamFace', (.35, -2.3, 2.0), (.0, -.42, 1.72), lens=110)}
    bpy.context.scene.camera = cams['hero']
    return cams, J

def hint_of(name):
    """Per-vertex bone or bones from the K() calls, or None where the rig's own rules apply."""
    marks = HINTS.get(name)
    if not marks: return None
    n = len(bags[name].v)
    out = [None] * n
    for i, (start, bones) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else n
        for v in range(start, end): out[v] = bones
    return out
