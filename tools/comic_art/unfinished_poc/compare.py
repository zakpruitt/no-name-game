# Two real GLBs at the game's camera, 1:1 at 1080p, with flat comic stand-in materials: the old hero and the export.
#   blender -b --factory-startup -P compare.py -- [new.glb]
# Then sheet.py tiles the cells. No Godot here: the real look is comic_toon and only a windowed run can confirm it.
import bpy, sys, os, math
from mathutils import Vector as V, Euler
ROOT = r"C:\Users\pruit\Desktop\dev\awaken"
OUT = os.path.join(ROOT, r"vendor_src\shaman_redesign\unfinished_poc\out")
NEW_GLB = os.path.join(ROOT, r"vendor_src\shaman_redesign\comic_poc\out\shaman_comic.glb")
OLD_GLB = os.path.join(ROOT, r"vendor_src\shaman_redesign\comic_poc\out\archive_shaman_comic_v1.glb")
if '--' in sys.argv and len(sys.argv) > sys.argv.index('--') + 1: NEW_GLB = sys.argv[sys.argv.index('--') + 1]
os.makedirs(os.path.join(OUT, 'cells'), exist_ok=True)
scn = bpy.context.scene
for o in list(bpy.data.objects): bpy.data.objects.remove(o)

def lin(c): return tuple(x ** 2.2 for x in c) + (1,)
def set_toon(m, sh, mi, li, hi=None):
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    d = nt.nodes.new('ShaderNodeBsdfDiffuse'); s = nt.nodes.new('ShaderNodeShaderToRGB')
    r = nt.nodes.new('ShaderNodeValToRGB'); e = nt.nodes.new('ShaderNodeEmission'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    d.inputs[0].default_value = (1, 1, 1, 1); r.color_ramp.interpolation = 'CONSTANT'
    r.color_ramp.elements[0].color = lin(sh); r.color_ramp.elements[1].position = .22; r.color_ramp.elements[1].color = lin(mi)
    r.color_ramp.elements.new(.62).color = lin(li)
    nt.links.new(d.outputs[0], s.inputs[0]); nt.links.new(s.outputs[0], r.inputs[0]); nt.links.new(r.outputs[0], e.inputs[0]); nt.links.new(e.outputs[0], o.inputs[0])
def set_emit3(m, low, mid, high, attr):
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    a = nt.nodes.new('ShaderNodeVertexColor'); a.layer_name = attr
    r = nt.nodes.new('ShaderNodeValToRGB'); e = nt.nodes.new('ShaderNodeEmission'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    cr = r.color_ramp; cr.interpolation = 'CONSTANT'
    cr.elements[0].position = 0; cr.elements[0].color = lin(low); cr.elements[1].position = .42; cr.elements[1].color = lin(mid); cr.elements.new(.72).color = lin(high)
    nt.links.new(a.outputs[0], r.inputs[0]); nt.links.new(r.outputs[0], e.inputs[0]); nt.links.new(e.outputs[0], o.inputs[0])
# the materials whose stepped tones matter here, as comic_emit draws them along g
EMIT3 = {'lavadark': ((.2, .04, .28), (1, .28, .02), (1, .86, .2)), 'firedark': ((.14, .03, .2), (.95, .1, .02), (1, .9, .2)), 'boltdark': ((.42, .16, .78), (.3, .6, 1), (.98, 1, .92))}
def set_emit(m, c):
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new('ShaderNodeEmission'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    e.inputs[0].default_value = lin(c); nt.links.new(e.outputs[0], o.inputs[0])
# comic_lib's own tones, so this is near what comic_toon will be given
TONES = {'blight': ((.015, .01, .03), (.05, .025, .09), (.12, .07, .2)), 'skin': ((.36, .1, .14), (.86, .46, .28), (1, .75, .5)), 'hair': ((.2, .24, .5), (.62, .68, .86), (.95, .95, .92)), 'iron': ((.05, .06, .14), (.2, .25, .38), (.46, .54, .68)),
         'bronze': ((.2, .06, .02), (.68, .34, .08), (.98, .68, .18)), 'leather': ((.1, .03, .03), (.34, .14, .08), (.6, .32, .15)), 'cloth': ((.02, .08, .16), (.03, .32, .36), (.08, .6, .56)),
         'trousers': ((.06, .05, .13), (.2, .17, .32), (.42, .36, .5)), 'rock': ((.05, .02, .05), (.2, .12, .16), (.42, .28, .28)), 'bone': ((.36, .17, .1), (.8, .6, .36), (.98, .92, .72)),
         'ice': ((.08, .3, .72), (.26, .62, .96), (.6, .9, 1)), 'scar': ((.1, .05, .12), (.26, .14, .22), (.42, .24, .3)), 'fur': ((.07, .05, .07), (.2, .14, .13), (.36, .27, .22)),
         'haft': ((.08, .04, .04), (.27, .14, .09), (.46, .28, .16)), 'teeth': ((.4, .28, .16), (.8, .7, .44), (.96, .9, .68)), 'socket': ((.012, .01, .02), (.1, .03, .05), (.18, .06, .07)), 'black': ((.012, .01, .02), (.03, .02, .03), (.06, .05, .06))}
EMITS = {'lava': (1, .55, .1), 'fire': (1, .6, .1), 'bolt': (.6, .8, 1), 'wind': (.6, 1, .7), 'fracture': (.62, .36, .98), 'spirit': (.5, 1, .86), 'eyewhite': (.965, .93, .82), 'eyeblue': (.3, .65, 1), 'pupil': (.012, .01, .02)}
INK = bpy.data.materials.new('Ink'); set_emit(INK, (.035, .032, .07)); INK.use_backface_culling = True; INK.use_backface_culling_shadow = True
AXE_TEAL = bpy.data.materials.new('AxeTeal'); set_toon(AXE_TEAL, (.03, .22, .28), (.1, .55, .55), (.4, .9, .82))
CRK = bpy.data.materials.new('Crk'); set_emit(CRK, EMITS['fracture'])

def load(path):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[n] for n in set(bpy.data.objects.keys()) - before]
    arm = next(o for o in new if o.type == 'ARMATURE')
    for t in arm.animation_data.nla_tracks: t.mute = True
    meshes = [o for o in new if o.type == 'MESH']
    for m in {m for o in meshes for m in o.data.materials if m}:
        k = m.name.split('.')[0][2:].lower()
        if k in TONES: set_toon(m, *TONES[k])
        elif k in EMITS: set_emit(m, EMITS[k])
    for o in meshes:
        for m in o.data.materials:
            k = m.name.split('.')[0][2:].lower() if m else ''
            if k in EMIT3 and len(o.data.color_attributes): set_emit3(m, *EMIT3[k], o.data.color_attributes[-1].name)
        if o.name.startswith('axe_storm_ice') or o.name.startswith('axe_magma_rock'): o.data.materials[0] = AXE_TEAL
        if o.name.startswith('axe_storm_bolt') or o.name.startswith('axe_magma_lava'): o.data.materials[0] = CRK
        o.data.materials.append(INK)
        s = o.modifiers.new('InkHull', 'SOLIDIFY'); s.thickness = .016; s.offset = 1; s.use_flip_normals = True; s.material_offset = len(o.data.materials) - 1; s.use_rim = False
    return arm, meshes, new
A_OLD, M_OLD, _ = load(OLD_GLB)
acts_old = set(bpy.data.actions.keys())
A_NEW, M_NEW, _ = load(NEW_GLB)
acts_new = set(bpy.data.actions.keys()) - acts_old
def action_for(arm, clip):
    names = acts_new if arm is A_NEW else acts_old
    for n in names:
        if n == clip or n.split('.')[0] == clip: return bpy.data.actions[n]
    raise KeyError(clip)
print('NEW tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in M_NEW), 'clips', len(acts_new))

scn.render.engine = 'BLENDER_EEVEE'
scn.view_settings.view_transform = 'Standard'; scn.view_settings.look = 'None'
scn.render.resolution_x, scn.render.resolution_y = 1920, 1080
world = bpy.data.worlds.new('W'); scn.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND'); bg.inputs[0].default_value = (0, 0, 0, 1)
bpy.ops.mesh.primitive_plane_add(size=120); FLOOR = bpy.context.object
fm = bpy.data.materials.new('Floor'); set_toon(fm, (.125, .11, .2), (.243, .212, .345), (.275, .243, .384)); FLOOR.data.materials.append(fm)
sd = bpy.data.lights.new('Key', 'SUN'); sd.energy = 3.0; sd.angle = math.radians(1)
sun = bpy.data.objects.new('Key', sd); scn.collection.objects.link(sun); sun.rotation_euler = Euler((math.radians(40), math.radians(10), math.radians(-38)))
cd = bpy.data.cameras.new('Game'); cd.sensor_fit = 'VERTICAL'; cd.angle_y = math.radians(42)
cam = bpy.data.objects.new('Game', cd); scn.collection.objects.link(cam); scn.camera = cam
cam.location = (0, -9.5, 13); cam.rotation_euler = (-cam.location).to_track_quat('-Z', 'Y').to_euler()
BLACK = bpy.data.materials.new('Black'); set_emit(BLACK, (.035, .032, .07))

def show(ms, on):
    for o in ms: o.hide_render = not on
def pose(arm, clip, f, yaw):
    a = action_for(arm, clip); ad = arm.animation_data; ad.action = a
    if a.slots: ad.action_slot = a.slots[0]
    arm.rotation_mode = 'XYZ'; arm.rotation_euler = (0, 0, math.radians(yaw))
    scn.frame_set(f); bpy.context.view_layer.update()
CELLS = [('idle_front', 'Idle', 0, 0), ('idle_34', 'Idle', 0, -50), ('idle_back', 'Idle', 0, 180), ('run_side', 'Run_F', 6, 90), ('run_away', 'Run_F', 2, 180),
         ('ready', 'Idle_Ready', 8, 0), ('chop', 'Ab_L3', 18, 0), ('spin', 'Ab_H', 22, 0)]
scn.render.use_border = True; scn.render.use_crop_to_border = True
scn.render.border_min_x, scn.render.border_max_x = .33, .67
scn.render.border_min_y, scn.render.border_max_y = .34, .82
def shoot(n):
    scn.render.filepath = os.path.join(OUT, 'cells', n); bpy.ops.render.render(write_still=True)
for name, arm, group, other in (('cur', A_OLD, M_OLD, M_NEW), ('new', A_NEW, M_NEW, M_OLD)):
    show(group, True); show(other, False)
    for cell, clip, f, yaw in CELLS:
        pose(arm, clip, f, yaw); shoot('%s_%s.png' % (name, cell))
    FLOOR.hide_render = True; bg.inputs[0].default_value = (1, 1, 1, 1); scn.view_layers[0].material_override = BLACK
    for cell, clip, f, yaw in CELLS:
        pose(arm, clip, f, yaw); shoot('%s_%s_black.png' % (name, cell))
    scn.view_layers[0].material_override = None; FLOOR.hide_render = False; bg.inputs[0].default_value = (0, 0, 0, 1)
print('DONE')
