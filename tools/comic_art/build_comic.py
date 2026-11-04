# The shaman restyled: same design, pushed proportions, comic materials.
#   blender -b -P build_comic.py -- stills [hero side back game face]
import bpy, sys, os, math
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import importlib, comic_lib as C
importlib.reload(C)
from mathutils import Vector as V

def bump(z, c, w): return math.exp(-((z - c) / w) ** 2)
def warp(v):
    """Comic anatomy: broad V from the chest, pinched waist, narrower hips over wide-planted legs."""
    sx = 1 + .17 * bump(v.z, 1.46, .24) - .13 * bump(v.z, .98, .13) + .05 * bump(v.z, .1, .35)
    sy = 1 + .1 * bump(v.z, 1.42, .22) - .1 * bump(v.z, 1.0, .13)
    return V((v.x * sx, v.y * sy, v.z))

def build_all():
    scn = bpy.context.scene
    for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
    C.ink_material()
    mats = C.materials()
    C.rng.seed(11)
    B = C.build()
    J = C.JOINTS
    # the signature limbs get bigger: the magma fist and the storm hand
    for k, b in B.items():
        if k in ('rock', 'lava') or k.startswith('fire'):
            C.scale_about(b.v, J['mf'], 1.3, .55)
        if k in ('skin', 'bone') or k.startswith('bolt'):
            C.scale_about(b.v, J['hd'], 1.22, .32)
    for b in B.values():
        b.v = [warp(p) for p in b.v]
    for k in list(J): J[k] = warp(J[k])
    col = scn.collection
    tot = 0
    for k, b in B.items():
        if not b.v: continue
        if k == 'skin': o, t = C.make_obj('skin', b, mats, col, voxel=.0075, smooth_iter=14, outline=.006, decim=.1)
        elif k == 'head': o, t = C.make_obj('head', b, mats, col, voxel=.0035, smooth_iter=8, outline=.005, decim=.14)
        elif b.mat in ('lava', 'bolt', 'wind', 'eye_white', 'eye_blue', 'pupil', 'socket', 'teeth', 'black'):
            o, t = C.make_obj(k, b, mats, col, outline=0)
        elif b.mat in ('fire', 'spirit'): o, t = C.make_obj(k, b, mats, col, outline=.004)
        else: o, t = C.make_obj(k, b, mats, col, outline=.006)
        tot += t
    print('TOTAL tris', tot)
    C.comic_scene()
    cams = {
        'hero': C.camera('CamHero', (1.2, -6.8, 1.6), (-.02, -.15, 1.12), lens=52),
        'side': C.camera('CamSide', (-5.2, -1.8, 1.4), (-.05, -.2, 1.1), lens=58),
        'back': C.camera('CamBack', (-1.4, 3.6, 1.6), (0, 0, 1.1), lens=58),
        'game': C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .95), ortho=3.6),
        'face': C.camera('CamFace', (.35, -2.3, 2.0), (.0, -.42, 1.72), lens=110),
    }
    bpy.context.scene.camera = cams['hero']
    return cams, J

if 'stills' in sys.argv:
    cams, J = build_all()
    C.ink_pass()
    out = os.path.join(C.DIR, 'out')
    os.makedirs(out, exist_ok=True)
    wanted = sys.argv[sys.argv.index('stills') + 1:] or list(cams)
    for n in wanted:
        C.render(os.path.join(out, 'shaman_%s.png' % n), cams[n])
    print('tris', C.tris())
