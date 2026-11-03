# Close look at the exported hero, for skinning: blender -b --factory-startup -P closeup.py, cells in out/close/
# Tile with: python closeup_sheet.py -> out/closeup.png
import bpy, os, math
from mathutils import Vector as V
HERE = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\unfinished_poc"
src = open(os.path.join(HERE, 'compare.py')).read()
exec(compile(src[:src.index("CELLS = [")], 'compare', 'exec'))
show(M_OLD, False); show(M_NEW, True)
scn.render.use_border = False; scn.render.use_crop_to_border = False
scn.render.resolution_x, scn.render.resolution_y = 620, 620
cd.angle_y = math.radians(30)
os.makedirs(os.path.join(HERE, 'out', 'close'), exist_ok=True)
for name, clip, f, yaw, loc in (('front', 'Idle', 0, 0, (.6, -4.4, 2.6)), ('back', 'Idle', 0, 180, (.6, -4.4, 2.6)), ('left', 'Idle', 0, -90, (.6, -4.4, 2.6)),
                                ('run', 'Run_F', 6, -35, (.6, -4.4, 2.6)), ('chop', 'Ab_L3', 18, -30, (.6, -4.4, 2.6)), ('spin', 'Ab_H', 22, 30, (.6, -4.4, 2.6))):
    cam.location = loc; cam.rotation_euler = (V((0, 0, 1.0)) - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    pose(A_NEW, clip, f, yaw)
    scn.render.filepath = os.path.join(HERE, 'out', 'close', name + '.png'); bpy.ops.render.render(write_still=True)
print('DONE')
