# Whole ability reel: rig + keyed moves + comic effects, rendered on twos.
#   blender -b ../style_poc/shaman_poc.blend --scene POC -P render_abilities.py -- [element=earth] [out=name] [stills=f1,f2] [L3 CH ...]
import bpy, sys, os, math, subprocess, shutil
D = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc"
sys.path.insert(0, D)
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
opt = dict(a.split('=', 1) for a in args if '=' in a)
exec(compile(open(os.path.join(D, 'rig_comic.py')).read(), 'rig_comic', 'exec'))
import comic_lib as C, comic_vfx, ability_vfx
from mathutils import Vector as V

# closer than the game's camera, far enough to hold a colossal axe
CS = bpy.data.objects['CamShow']
CS.data.lens = 40
K = comic_vfx.Kit(scn, CS, opt.get('element', 'spirit'))
K.q = (V((0, -.2, .9)) - V((.2, -7.4, 5.2))).to_track_quat('-Z', 'Y'); K.back = K.q @ V((0, 0, 1))
K.lens = 40
ability_vfx.FWD = FWD.copy(); ability_vfx.YAW = YAW
def root_at(f):
    return root[max(0, min(int(f), len(root) - 1))][0].copy()
if 'room' in opt:
    import reel_room
    reel_room.dress(scn, YAW, FWD, root_at, CLIPS, ability_vfx.HIT, K)
# the camera rises with his leaps, so the top of the page never beheads him
_hb = PR.pose.bones['head']
_samples = []
_last = max(b for a, b in CLIPS.values()) + 14
for _f in range(0, _last + 1, 3):
    scn.frame_set(_f); _samples.append(max(0.0, (PR.matrix_world @ _hb.head).z - 1.9))
_cb = CS.animation_data.action.layers[0].strips[0].channelbag(CS.animation_data.action.slots[0])
_fc = next(c for c in _cb.fcurves if c.data_path == 'location' and c.array_index == 2)
def _lift(f):
    # anticipates by a beat and eases back down
    return max(_samples[min(max(0, int(g) // 3), len(_samples) - 1)] * (1 - abs(g - f) / 12) for g in range(int(f) - 9, int(f) + 10, 3)) * .8
for kp in _fc.keyframe_points:
    d = _lift(kp.co.x); kp.co.y += d; kp.handle_left.y += d; kp.handle_right.y += d
_fc.update()
ability_vfx.run(K, CLIPS, INFO, root_at)
K.finish()
print('fx objects', len(K.objs))
scn.render.resolution_x, scn.render.resolution_y = 1280, 720
scn.render.image_settings.file_format = 'PNG'
name = opt.get('out', 'abilities')
out = os.path.join(D, 'out', 'abilities'); os.makedirs(out, exist_ok=True)
assert SR.location.length < .001

if 'hitsheet' in opt:
    # four beats of every clip, tiled: the fastest full review
    tmp = os.path.join(out, 'hs_' + name); shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp)
    scn.render.resolution_x, scn.render.resolution_y = 640, 360
    i = 0
    for k, (a, b) in CLIPS.items():
        h = a + ability_vfx.HIT[k]
        for f in (h + d for d in ability_vfx.BEATS.get(k, (-8, -2, 2, 8))):
            scn.frame_set(max(f, 0)); scn.render.filepath = os.path.join(tmp, '%03d.png' % i); bpy.ops.render.render(write_still=True); i += 1
    rows = i // 4
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'), '-vf', 'tile=4x%d' % rows, '-frames:v', '1', os.path.join(out, name + '_sheet.png')], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
elif 'stills' in opt:
    for f in opt['stills'].split(','):
        scn.frame_set(int(f)); scn.render.filepath = os.path.join(out, '%s_%s.png' % (name, f)); bpy.ops.render.render(write_still=True)
else:
    fr = os.path.join(out, 'frames_' + name); shutil.rmtree(fr, ignore_errors=True); os.makedirs(fr)
    last = max(b for a, b in CLIPS.values()) + 14
    for i, f in enumerate(range(0, last, 2)):   # animated on twos
        scn.frame_set(f); scn.render.filepath = os.path.join(fr, '%05d.png' % i); bpy.ops.render.render(write_still=True)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '12', '-i', os.path.join(fr, '%05d.png'), '-r', '24', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17', os.path.join(D, 'out', 'shaman_%s.mp4' % name)], check=True)
    # keep a sheet of each clip's hit
    HIT = ability_vfx.HIT
    for k, (a, b) in CLIPS.items():
        print('hitframe', k, a + HIT[k])
print('rendered', name)
