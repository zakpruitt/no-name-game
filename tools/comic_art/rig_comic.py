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
import build_unfinished
_cams, _J = build_unfinished.build_all()
ns = {'JOINTS': _J}
''')
# ---- The Unfinished: both arms are flesh now, the right leg is a leg with a foot.
rep("'foot.r': (J['tr'], J['tr'] + V((0, -.03, .03))), 'toes.r': (J['tr'] + V((0, -.03, .03)), J['tr'] + V((0, -.06, .03))),", "'foot.r': (J['tr'], ft(J['tr'])), 'toes.r': (ft(J['tr']), ft(J['tr']) + V((0, -.13, 0))),")
rep("'toes.l', 'toes.r', 'foot.r')]", "'toes.l', 'toes.r')]")
rep("'upperleg.r': .1, 'lowerleg.r': .06}", "'upperleg.r': .13, 'lowerleg.r': .09, 'foot.r': .08}")
rep("names = [n for n in CAPS if n not in LEGS and n != 'foot.l' and not n.endswith('.l')] + ['chest']", "names = [n for n in CAPS if n not in LEGS and n not in ('foot.l', 'foot.r')]")
rep("for i, p in enumerate(co): weights[i] = soft(p, ('hips', 'upperleg.l', 'lowerleg.l'), power=5, top=2)", "for i, p in enumerate(co): weights[i] = soft(p, ('hips', 'upperleg.l', 'lowerleg.l') if p.x > 0 else ('hips', 'upperleg.r', 'lowerleg.r'), power=5, top=2)")
rep("# smooth the skin weights across the mesh", '''# parts the body script tagged with a bone are pinned to it; the breastplate bends with the torso
import build_unfinished as _BU
for _o in list(scn.objects):
    _h = _BU.hint_of(_o.name) if _o.type == 'MESH' else None
    if not _h: continue
    for _i, _b in enumerate(_h):
        if _b is None: continue
        for _g in _o.vertex_groups: _g.remove([_i])
        _ws = [(1, _b)] if _b != 'SOFT_TORSO' else soft(_o.data.vertices[_i].co, ('hips', 'spine', 'chest'), power=3, top=2)
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

# ------------------------------------------------------------------ the twin axes, on the hand bones
# Same grip, directions and reach as before, so the solved carries still land. A real wedge of iron on a thick haft.
mats_all = {m.name[2:].lower(): m for m in bpy.data.materials if m.name.startswith('P_') and m.name != 'P_Ink'}
hd = J['hd']; mf = J['mf']
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
def axe(name, grip, dirv, face, size, bone, chip):
    dv = V(dirv).normalized(); fw = V(face).normalized(); fw = (fw - dv * fw.dot(dv)).normalized(); side = dv.cross(fw).normalized()
    Bg = {'haft': C.Bag('haft'), 'leather': C.Bag('leather'), 'steel': C.Bag('iron', sharp=40), 'blade': C.Bag('iron', smooth=False), 'edge': C.Bag('fracture', smooth=False), 'crack': C.Bag('fracture', smooth=False)}
    top = grip + dv * (.85 * size)
    C.tube(Bg['haft'], [grip - dv * .24 * size, grip, top + dv * .08 * size], [.05, .047, .058], sides=9, sub=1)
    C.blob(Bg['steel'], grip - dv * .28 * size, (.07, .07, .085), seg=10, rings=6)
    for t in (-.09, .03, .15):
        C.tube(Bg['leather'], [grip + dv * (t * size - .035), grip + dv * (t * size + .035)], [.06, .06], sides=9, sub=1)
    C.tube(Bg['steel'], [top - dv * .17 * size, top + dv * .13 * size], [.1, .1], sides=9, sub=1)
    for t in (-.15, .11):
        C.tube(Bg['steel'], [top + dv * (t * size - .015), top + dv * (t * size + .015)], [.112, .112], sides=9, sub=1)
    C.tube(Bg['steel'], [top - fw * .04, top - fw * .28 * size, top - fw * .44 * size], [.09, .055, .003], sides=7, sub=1)
    notch = [(.53, .1), (.45, .15), (.51, .21)] if chip else []
    prof = [(0, -.07), (.14, -.08), (.3, -.26), (.47, -.5), (.53, -.3), (.56, 0)] + notch + [(.53, .24), (.47, .46), (.3, .22), (.14, .07), (0, .06)]
    wedge(Bg['blade'], top, fw, dv, side, prof, .1, size)
    if not chip:    # the other wear: a cracked cheek, lit from inside
        for s_ in (1, -1):
            C.tube(Bg['crack'], [top + fw * x * size + dv * y * size + side * (s_ * .104) for x, y in ((.13, .0), (.2, .07), (.24, .0), (.31, .09))], [.016, .014, .011, .003], sides=5, sub=1, tval=1.0)
    e = [(.47, -.5), (.53, -.3), (.56, 0)] + notch + [(.53, .24), (.47, .46), (.45, .3), (.5, 0), (.45, -.32)]
    for s_ in (1, -1):
        pts = [top + fw * x * size + dv * y * size + side * (s_ * .012) for x, y in e]
        Bg['edge'].add(pts, [tuple(range(len(e))) if s_ > 0 else tuple(reversed(range(len(e))))])
    for k, bag in Bg.items():
        if not bag.v: continue
        o, _ = C.make_obj(name + '_' + k, bag, mats_all, scn.collection, outline=0 if k in ('edge', 'crack') else .007)
        grp = o.vertex_groups.new(name=bone); grp.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = PR; o.modifiers.move(o.modifiers.find('Skin'), 0)
        o.parent = PR
axe('axe_storm', hd + V((-.03, -.05, .03)), (-.22, -.28, 1), (-1, -.3, .1), AXE_SIZE, 'hand.r', True)
axe('axe_magma', mf + V((.02, -.1, -.04)), (.06, -.8, .42), (1, 0, .1), AXE_SIZE, 'hand.l', False)

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
