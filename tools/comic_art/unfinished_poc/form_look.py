# The void arm's forms, each in the clip that uses it, close and from the game's angle. One sheet: out/forms/sheet.png
#   blender -b --factory-startup -P form_look.py
import bpy, os, math
from mathutils import Vector as V
HERE = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\unfinished_poc"
src = open(os.path.join(HERE, 'compare.py')).read()
exec(compile(src[:src.index("CELLS = [")], 'compare', 'exec'))
show(M_OLD, False); show(M_NEW, True)
scn.render.use_border = False; scn.render.use_crop_to_border = False
scn.render.resolution_x, scn.render.resolution_y = 520, 520
cd.angle_y = math.radians(30)
OUT_T = os.path.join(HERE, 'out', 'forms'); os.makedirs(OUT_T, exist_ok=True)
FORM = {'axe': ('axe_void', 'void_surge'), 'hammer': ('hammer_void', 'void_seep'), 'spear': ('spear_void', 'void_frost'), 'none': ()}
ALL = tuple(x for v in FORM.values() for x in v)
def form(name):
    for o in M_NEW:
        if o.name.startswith(ALL): o.hide_render = not o.name.startswith(FORM[name]) if FORM[name] else True
LOC, AT = (.3, -5.6, 4.2), (0, -.5, 1.0)
CUTS = [('axe', 'axe', 'Idle', 0), ('L1', 'axe', 'Ab_L1', 8), ('L2_wind', 'spear', 'Ab_L2', 5), ('L2_hit', 'spear', 'Ab_L2', 9),
        ('L3_top', 'hammer', 'Ab_L3', 15), ('L3_hit', 'hammer', 'Ab_L3', 18), ('CH', 'hammer', 'Ab_CH', 37), ('DL', 'spear', 'Ab_DL', 9),
        ('GR', 'none', 'Ab_GR', 7), ('VS_top', 'none', 'Ab_VS', 10), ('VS_hit', 'none', 'Ab_VS', 14), ('Swing', 'none', 'Ab_Swing', 4)]
names = []
for name, fm_, clip, f in CUTS:
    form(fm_)
    cam.location = LOC; cam.rotation_euler = (V(AT) - V(LOC)).to_track_quat('-Z', 'Y').to_euler()
    pose(A_NEW, clip, f, 0)
    p = os.path.join(OUT_T, name + '.png'); scn.render.filepath = p; bpy.ops.render.render(write_still=True); names.append(p)
print('DONE')
