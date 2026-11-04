# The exported hero up close, the way someone opening him in Blender sees him: whole body and each limb, at rest and mid-move.
#   blender -b --factory-startup -P closeup_tight.py   -> out/tight.png
# Judge limbs here as well as at the game's camera: a broken arm doesn't show at 130 px.
import bpy, os, math
from mathutils import Vector as V
HERE = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\unfinished_poc"
src = open(os.path.join(HERE, 'compare.py')).read()
exec(compile(src[:src.index("CELLS = [")], 'compare', 'exec'))
show(M_OLD, False); show(M_NEW, True)
scn.render.use_border = False; scn.render.use_crop_to_border = False
scn.render.resolution_x, scn.render.resolution_y = 640, 640
cd.angle_y = math.radians(30)
OUT_T = os.path.join(HERE, 'out', 'tight'); os.makedirs(OUT_T, exist_ok=True)
CUTS = [('whole', 'Idle', 0, 0, (.5, -5.2, 2.2), (0, 0, 1.05)), ('whole_back', 'Idle', 0, 180, (.5, -5.2, 2.2), (0, 0, 1.05)),
        ('magma_arm', 'Idle', 0, 0, (1.9, -2.6, 1.6), (.5, -.2, 1.05)), ('storm_arm', 'Idle', 0, 0, (-1.9, -2.6, 1.6), (-.5, -.2, 1.1)),
        ('chest_face', 'Idle', 0, 0, (.3, -2.7, 2.1), (.05, -.2, 1.5)), ('ice_leg', 'Idle', 0, 0, (-1.1, -2.4, 1.0), (-.25, -.1, .4)),
        ('run', 'Run_F', 6, -35, (.5, -5.2, 2.2), (0, 0, 1.05)), ('chop', 'Ab_L3', 18, -30, (.5, -5.2, 2.2), (0, 0, 1.05)), ('spin', 'Ab_H', 22, 30, (.5, -5.2, 2.2), (0, 0, 1.05))]
for name, clip, f, yaw, loc, at in CUTS:
    cam.location = loc; cam.rotation_euler = (V(at) - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    pose(A_NEW, clip, f, yaw)
    scn.render.filepath = os.path.join(OUT_T, name + '.png'); bpy.ops.render.render(write_still=True)
print('DONE')
