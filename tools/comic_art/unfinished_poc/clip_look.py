# One clip of the exported hero at the game's camera, every other frame:
#   blender -b --factory-startup -P clip_look.py -- CLIP [yaw] [step]
# Cells land in out/clip/<CLIP>/; clip_sheet.py tiles them and writes a GIF.
import bpy, os, sys, math
HERE = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\unfinished_poc"
args = sys.argv[sys.argv.index('--') + 1:]
CLIP = args[0]; YAW = float(args[1]) if len(args) > 1 else -20; STEP = int(args[2]) if len(args) > 2 else 2
sys.argv = sys.argv[:sys.argv.index('--')]
src = open(os.path.join(HERE, 'compare.py')).read()
exec(compile(src[:src.index("CELLS = [")], 'compare', 'exec'))
show(M_OLD, False); show(M_NEW, True)
a = action_for(A_NEW, CLIP)
d = os.path.join(HERE, 'out', 'clip', CLIP); os.makedirs(d, exist_ok=True)
for f in os.listdir(d): os.remove(os.path.join(d, f))
scn.render.use_border = True; scn.render.use_crop_to_border = True
scn.render.border_min_x, scn.render.border_max_x = .36, .64
scn.render.border_min_y, scn.render.border_max_y = .3, .82
lo, hi = int(a.frame_range[0]), int(a.frame_range[1])
for f in range(lo, hi + 1, STEP):
    pose(A_NEW, CLIP, f, YAW)
    scn.render.filepath = os.path.join(d, '%03d.png' % f); bpy.ops.render.render(write_still=True)
print('DONE', CLIP, lo, hi)
