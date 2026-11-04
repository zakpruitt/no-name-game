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
import build_void
_cams, _J = build_void.build_all()
ns = {'JOINTS': _J}
''')
# ---- his left arm is skin now
rep("names = [n for n in CAPS if n not in LEGS and n != 'foot.l' and not n.endswith('.l')] + ['chest']", "names = [n for n in CAPS if n not in LEGS and n != 'foot.l']")
rep("# smooth the skin weights across the mesh", '''# parts the body script tagged follow those bones: one is a pin, several bend as the skin does
import build_tainted as _BT   # build_void adds its own parts to these tags
for _o in list(scn.objects):
    _h = _BT.hint_of(_o.name) if _o.type == 'MESH' else None
    if not _h: continue
    for _i, _b in enumerate(_h):
        if _b is None: continue
        for _g in _o.vertex_groups: _g.remove([_i])
        _ws = [(1, _b)] if isinstance(_b, str) else soft(_o.data.vertices[_i].co, _b, power=2 if _o.name.startswith('void_') else 4, top=3 if _o.name.startswith('void_') else 2)
        for _w, _n in _ws:
            _g = _o.vertex_groups.get(_n) or _o.vertex_groups.new(name=_n)
            _g.add([_i], _w, 'REPLACE')
# smooth the skin weights across the mesh''')
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

# ------------------------------------------------------------------ the axe his void arm makes, on the right hand bone
# Same grip, direction and reach as before, so the solved carries still land. The arm runs on into its own haft.
mats_all = {m.name[2:].lower(): m for m in bpy.data.materials if m.name.startswith('P_') and m.name != 'P_Ink'}
hd = J['hd']
AXE_SIZE = g['AXE_SIZE']  # abilities.py poses the blade tip on the floor from this
def wedge(bag, top, fw, dv, side, prof, th, size):
    n = len(prof); cx = sum(p[0] for p in prof) / n; cy = sum(p[1] for p in prof) / n
    P_ = lambda x, y, s_: top + fw * x * size + dv * y * size + side * s_
    k = .52
    inner = [(cx * .55 + (x - cx * .55) * k, cy + (y - cy) * k) for x, y in prof]
    vs = [P_(x, y, 0) for x, y in prof] + [P_(x, y, th) for x, y in inner] + [P_(x, y, -th) for x, y in inner]
    F = [tuple(range(n, 2 * n)), tuple(reversed(range(2 * n, 3 * n)))]
    for i in range(n):
        j = (i + 1) % n
        F.append((i, j, n + j, n + i)); F.append((j, i, 2 * n + i, 2 * n + j))
    bag.add(vs, F)
def axe(name, grip, dirv, face, size, bone):
    dv = V(dirv).normalized(); fw = V(face).normalized(); fw = (fw - dv * fw.dot(dv)).normalized(); side = dv.cross(fw).normalized()
    Bg = {'haft': C.Bag('tendril'), 'blade': C.Bag('voidhard', smooth=False), 'edge': C.Bag('stormgreen', smooth=False), 'core': C.Bag('stormgreen')}
    top = grip + dv * (.85 * size)
    C.tube(Bg['haft'], [grip - dv * .05, grip + dv * (.4 * size), top + dv * (.06 * size)], [.076, .058, .07], sides=9, sub=2, tval=.5)
    C.blob(Bg['haft'], top, (.105, .105, .105), seg=10, rings=7)
    C.tube(Bg['haft'], [top, top - fw * (.2 * size), top - fw * (.36 * size) + dv * (.03 * size)], [.078, .048, .003], sides=8, sub=3, tval=.5)
    prof = [(0, -.055), (.12, -.06), (.27, -.12), (.44, -.62), (.57, -.32), (.63, 0), (.57, .32), (.44, .62), (.27, .12), (.12, .06), (0, .055)]
    wedge(Bg['blade'], top, fw, dv, side, prof, .1, size)
    outer = [(.44, -.62), (.57, -.32), (.63, 0), (.57, .32), (.44, .62)]
    inner = [(.41, -.5), (.5, -.27), (.55, 0), (.5, .27), (.41, .5)]
    pt = lambda x, y, s_: top + fw * x * size + dv * y * size + side * s_
    for s_ in (1, -1):
        vs = [pt(x, y, s_ * .012) for x, y in outer] + [pt(x, y, s_ * .058) for x, y in inner]
        Bg['edge'].add(vs, [(i, i + 1, i + 6, i + 5) if s_ > 0 else (i + 5, i + 6, i + 1, i) for i in range(4)], [.55] * len(vs))
    C.tube(Bg['core'], [pt(x, y, 0) for x, y in outer], [.012, .018, .02, .018, .012], sides=5, sub=4, tval=1.0)
    for k, bag in Bg.items():
        o, _ = C.make_obj(name + '_' + k, bag, mats_all, scn.collection, outline=0 if k in ('edge', 'core') else .007)
        grp = o.vertex_groups.new(name=bone); grp.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = PR; o.modifiers.move(o.modifiers.find('Skin'), 0)
        o.parent = PR
def _skin_form(name, Bg, outlines, bone):
    for k, bag in Bg.items():
        o, _ = C.make_obj(name + '_' + k, bag, mats_all, scn.collection, outline=outlines.get(k, .007))
        grp = o.vertex_groups.new(name=bone); grp.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = PR; o.modifiers.move(o.modifiers.find('Skin'), 0)
        o.parent = PR

def hammer(name, grip, dirv, face, size, bone):
    # the arm thickens to a six-sided block, one face a rock ring round a pool of lava: `face` is the end that lands
    dv = V(dirv).normalized(); fw = V(face).normalized(); fw = (fw - dv * fw.dot(dv)).normalized(); side = dv.cross(fw).normalized()
    Bg = {'haft': C.Bag('tendril'), 'head': C.Bag('voidhard', smooth=False), 'rock': C.Bag('rock', smooth=False), 'lava': C.Bag('lava')}
    top = grip + dv * (.78 * size)
    C.tube(Bg['haft'], [grip - dv * .05, grip + dv * (.4 * size), top], [.076, .062, .08], sides=9, sub=2, tval=.5)
    c = top + dv * .12
    C.tube(Bg['head'], [c - fw * .46, c - fw * .36, c + fw * .36, c + fw * .46], [.2, .27, .27, .2], sides=6, sub=1, tval=.5)
    C.tube(Bg['lava'], [c + fw * .43, c + fw * .495, c + fw * .505], [.2, .17, .002], sides=6, sub=1, tval=.55)
    C.blob(Bg['lava'], c + fw * .508, (.07, .07, .07), seg=8, rings=6, t=.9)
    for i in range(6):
        a = i / 6 * 6.283 + .3
        o_ = side * math.cos(a) + dv * math.sin(a)
        C.rock(Bg['rock'], c + fw * .43 + o_ * .235, (.1, .1, .1), sub=1, jit=.12)
        if i % 2 == 0:   # lava runs back down the block from the face
            o2 = side * math.cos(a + .5) + dv * math.sin(a + .5)
            C.tube(Bg['lava'], [c + fw * .39 + o2 * .27, c + fw * .21 + o2 * .275, c + fw * .04 + o2 * .272], [.018, .012, .002], sides=4, sub=1, tval=.55)
    _skin_form(name, Bg, {'lava': 0}, bone)

def spear(name, grip, dirv, face, size, bone):
    # the arm drawn out straight, a hard collar, then a long ice point past the collar with two barbs
    dv = V(dirv).normalized(); fw = V(face).normalized(); fw = (fw - dv * fw.dot(dv)).normalized(); side = dv.cross(fw).normalized()
    Bg = {'haft': C.Bag('tendril'), 'collar': C.Bag('voidhard', smooth=False), 'ice': C.Bag('ice', smooth=False)}
    end = grip + dv * (.82 * size)
    C.tube(Bg['haft'], [grip - dv * .05, grip + dv * (.4 * size), end], [.076, .056, .05], sides=8, sub=2, tval=.5)
    C.tube(Bg['collar'], [end - dv * .05, end + dv * .14, end + dv * .34], [(.1, .04), (.125, .045), (.07, .03)], sides=4, sub=1, side=fw, tval=.5)
    C.tube(Bg['ice'], [end + dv * .24, end + dv * .42, end + dv * .78, end + dv * 1.2], [(.075, .04), (.135, .06), (.08, .036), (.002, .002)], sides=4, sub=1, side=fw, tval=.6)
    for sgn in (1, -1):
        b0 = end + dv * .3 + fw * (sgn * .06)
        C.tube(Bg['ice'], [b0, b0 + fw * (sgn * .1) - dv * .08, b0 + fw * (sgn * .2) - dv * .22], [.04, .026, .002], sides=4, sub=1, tval=.5)
    _skin_form(name, Bg, {}, bone)

axe('axe_void', hd + V((-.03, -.05, .03)), (-.22, -.28, 1), (-1, -.3, .1), AXE_SIZE, 'hand.r')
hammer('hammer_void', hd + V((-.03, -.05, .03)), (-.22, -.28, 1), (-1, -.3, .1), AXE_SIZE, 'hand.r')
spear('spear_void', hd + V((-.03, -.05, .03)), (-.22, -.28, 1), (-1, -.3, .1), AXE_SIZE, 'hand.r')

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
