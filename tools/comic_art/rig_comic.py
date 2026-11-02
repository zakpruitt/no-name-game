# Builds the comic shaman with twin axes, bakes the KayKit retargets and the hand-keyed abilities, and lays
# the abilities out on one timeline. Open the painted file (it holds the source rig 'Rig'), not a blank one:
#   blender -b ../style_poc/shaman_poc.blend -P rig_comic.py -- [sheet] [ABILITY ...]
# then comic_vfx/ability_vfx add the effects (render_abilities.py).
import bpy, sys, os, math
D = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc"
sys.path.insert(0, D)
import comic_lib as C
from mathutils import Vector as V, Quaternion as Q, Matrix


SRC = open(os.path.join(D, '..', 'style_poc', 'rig_poc.py')).read()
def rep(x, y, count=1):
    global SRC
    assert SRC.count(x) == count, (SRC.count(x), x)
    SRC = SRC.replace(x, y)

rep('ns = {"__name__": "build"}\nexec(compile(open(D + r"\\build_poc.py").read(), "build_poc", "exec"), ns)\n', '''
import build_comic
_cams, _J = build_comic.build_all()
ns = {'JOINTS': _J}
''')
rep("scn = bpy.context.window.scene", "scn = bpy.context.scene")
# the KayKit sources were never saved in this file; its baked P_* retargets were, and bone names match, so keep them
rep("if a.name.startswith(('P_', 'S_', 'FX_POC', 'CamShow')): bpy.data.actions.remove(a)", "if a.name in ('P_Idle', 'P_Showcase') or a.name.startswith(('P_Ab_', 'S_', 'FX_POC', 'CamShow')): bpy.data.actions.remove(a)")
import re as _re
SRC, _n = _re.subn(r"NAMES = \['Idle'.*?'Spellcast_Shoot'\]", "NAMES = ['Idle']", SRC, flags=_re.S); assert _n == 1
# abilities and secondary use the same bake; inject them before the showcase and replace its path
rep("BLEND = 5\n", '''BLEND = 3
exec(compile(open(os.path.join(COMIC, 'abilities.py')).read(), 'abilities', 'exec'), globals())
for _k, (_fr, _rm) in AB.items():
    BAKED[_k] = _fr
    write(PR, 'P_' + _k, _fr, ALL_T)
ORDER_AB = globals().get('WANTED') or list(INFO)
SEQ = [('Idle', 18, 0, 0)]
CLIPS = {}
_f = 18
for _k in ORDER_AB:
    SEQ.append(('Ab_' + _k, None, 0, 0))
    CLIPS[_k] = (_f, _f + INFO[_k]['length'] + 1)
    _f += INFO[_k]['length'] + 1
    SEQ.append(('Idle', 14, 0, 0))
    _f += 14
''')
# root motion: abilities carry their own forward travel; clips start at their own spot
rep("        pos = pos + V((math.sin(yaw), -math.cos(yaw), 0)) * speed / FPS\n", '''        pos = pos + V((math.sin(yaw), -math.cos(yaw), 0)) * speed / FPS
        if nm.startswith('Ab_'):
            _rm = AB[nm][1]
            pos = pos + FWD * -(_rm[f] - (_rm[f - 1] if f else 0))
''')
rep("pos = V((0, 0, 0)); yaw = 0.0; speed = 0.0", "YAW = math.radians(78); FWD = V((math.sin(YAW), -math.cos(YAW), 0)); pos = V((0, 0, 0)); yaw = YAW; speed = 0.0")
rep("yaw += ((-yaw + math.pi) % (2 * math.pi) - math.pi) * .14", "yaw += ((YAW - yaw + math.pi) % (2 * math.pi) - math.pi) * .14")
rep("cd = bpy.data.cameras.new('CamShow'); cd.lens = 42", "cd = bpy.data.cameras.new('CamShow'); cd.lens = 38")
rep("loc = cp + V((.2, -6.6, 4.0)); tgt = cp + V((0, 0, .95))", "loc = cp + FWD * 1.5 + V((.2, -7.4, 5.2)); tgt = cp + FWD * 1.5 + V((0, -.2, .9))")
rep("    cp = cp.lerp(root[j][0], .16)\n", "    cp = cp.lerp(root[j][0], .22)\n")

WANTED = [a for a in sys.argv[sys.argv.index('--') + 1:] if a.isupper()] if '--' in sys.argv else []
g = dict(globals()); g['COMIC'] = D; g['WANTED'] = WANTED; g['__name__'] = 'rig'
exec(compile(SRC, 'rig_poc', 'exec'), g)
PR, SR, CLIPS, INFO, root, scn, CS, FWD, YAW = g['PR'], g['SR'], g['CLIPS'], g['INFO'], g['root'], g['scn'], g['CS'], g['FWD'], g['YAW']
J = g['J']; t_rest = g['t_rest']

# ------------------------------------------------------------------ the twin axes, on the hand bones
mats = {m[2:].lower(): bpy.data.materials[m] for m in ('P_Iron', 'P_Bone', 'P_Leather', 'P_Bronze', 'P_Rock', 'P_Ice', 'P_Lava') }
def axe(name, grip, dirv, face, bit_mat, edge_mat, size, bone):
    dirv = V(dirv).normalized(); fw = V(face).normalized(); fw = (fw - dirv * fw.dot(dirv)).normalized()
    side = dirv.cross(fw).normalized()
    Bg = {k: C.Bag(k) for k in ('bone', 'leather', 'bronze', bit_mat)}
    if edge_mat not in Bg: Bg[edge_mat] = C.Bag(edge_mat)
    L = 1.05 * size
    C.tube(Bg['bone'], [grip - dirv * .24 * size, grip, grip + dirv * L], [.03, .027, .03], sides=7, sub=1)
    C.blob(Bg['bone'], grip - dirv * .27 * size, (.05, .05, .05), seg=8, rings=5)
    for t in (-.09, .02, .13):
        C.tube(Bg['leather'], [grip + dirv * (t * size - .02), grip + dirv * (t * size + .02)], [.037, .037], sides=7, sub=1)
    top = grip + dirv * (L - .2 * size)
    # the bit: a single big crescent, the read; a smaller spike on the back
    prof = [(0, -.1), (.1, -.18), (.3, -.34), (.5, -.3), (.56, 0), (.5, .3), (.3, .3), (.1, .14), (0, .08)]
    th = .03 * size
    vs = []
    n = len(prof)
    for s in (1, -1):
        for x, y in prof:
            vs.append(top + fw * x * size + dirv * y * size + side * (s * th * (1 if x < .42 else .12)))
    Bg[bit_mat].add(vs, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)])
    edge = [(.5, -.3), (.56, 0), (.5, .3), (.45, .3), (.5, 0), (.45, -.28)]
    for s in (1, -1):
        pts = [top + fw * x * size + dirv * y * size + side * (s * th * .13) for x, y in edge]
        Bg[edge_mat].add(pts, [tuple(range(6)) if s > 0 else tuple(reversed(range(6)))])
    C.tube(Bg['iron' if 'iron' in Bg else bit_mat], [top - fw * .02, top - fw * .3 * size, top - fw * .42 * size + dirv * .02 * size], [.05, .03, .002], sides=6, sub=1)
    C.tube(Bg['bronze'], [top - dirv * .1 * size, top + dirv * .1 * size], [.04, .04], sides=8, sub=1)
    out = []
    for k, bag in Bg.items():
        if not bag.v: continue
        o, _ = C.make_obj(name + '_' + k, bag, mats_all, scn.collection, outline=.007)
        grp = o.vertex_groups.new(name=bone); grp.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = PR; o.modifiers.move(o.modifiers.find('Skin'), 0)
        o.parent = PR; out.append(o)
    return out
mats_all = {m.name[2:].lower(): m for m in bpy.data.materials if m.name.startswith('P_') and m.name != 'P_Ink'}
hd = J['hd']; mf = J['mf']
axe('axe_storm', hd + V((-.03, -.05, .03)), (-.22, -.28, 1), (-1, -.3, .1), 'ice', 'bolt', .92, 'hand.r')
axe('axe_magma', mf + V((.02, -.1, -.04)), (.06, -.8, .42), (1, 0, .1), 'rock', 'lava', 1.15, 'hand.l')

C.ink_pass()
print('clips', CLIPS)
print('tris', C.tris())
ACTIVE_ROOT = root
if 'sheet' in sys.argv:
    # contact sheets without effects: hit frame +- for every clip, front-ish
    out = os.path.join(D, 'out', 'abilities'); os.makedirs(out, exist_ok=True)
    scn.camera = CS
    for k, (a, b) in CLIPS.items():
        fr = list(range(a, b, max(2, (b - a) // 7)))[:8]
        import subprocess, tempfile, shutil
        tmp = tempfile.mkdtemp(prefix='ab_')
        scn.render.resolution_x, scn.render.resolution_y = 640, 360
        for i, f in enumerate(fr):
            scn.frame_set(f); scn.render.filepath = os.path.join(tmp, '%03d.png' % i); bpy.ops.render.render(write_still=True)
        subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'), '-vf', 'tile=4x2', '-frames:v', '1', os.path.join(out, 'pose_%s.png' % k)], check=True)
        shutil.rmtree(tmp, ignore_errors=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, 'shaman_comic.blend'), copy=True)
