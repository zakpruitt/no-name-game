# A full comic room laid out like main.gd _build_arena, with the shaman and minions, at the real game camera.
#   blender -b -P env_room.py                 out/env/room_game.png (1920x1080) + out/env/room.blend
#   blender -b -P env_room.py -- preview      half size, faster look
# Coordinates in PLACE and CAST are Godot's (x, y, z), so they read straight against main.gd.
import bpy, sys, os, math, random
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, build_comic, env_kit as K
from mathutils import Vector as V

OUT = K.OUT; os.makedirs(OUT, exist_ok=True)
ARGV = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
TILE, HALF, ARENA = 4.0, 4, 16.0
CAM_OFFSET = (0.0, 13.0, 9.5); CAM_FOV = 42.0      # camera_rig.gd
CAM_ZOOM = .85                                     # camera_rig.punch(0.85): the zoom autotest_cast.jpg was caught at
FOCUS = (.6, 0.0, -12.5)                           # what the rig follows: the shaman
MINION_SCALE = 1.2
CHAR_SCALE = 1.4                                   # the comic models read small next to the chunky KayKit ones at this camera

def g2b(p): return V((p[0], -p[2], p[1]))          # Godot Y-up to Blender Z-up

# ---- the shaman first: build_all clears the scene and recreates the P_ materials
build_comic.build_all()
scn = bpy.context.scene
shaman = [o for o in scn.collection.all_objects if o.type == 'MESH' and o.name != 'floor']
for o in list(scn.collection.all_objects):
    if o.type in ('LIGHT', 'CAMERA') or o.name == 'floor': bpy.data.objects.remove(o)
C.ink_pass(objs=shaman)
for n in ('fire1', 'fire2', 'bolt1', 'bolt2'):        # flicker frames of the same flame
    o = bpy.data.objects.get(n)
    if o: bpy.data.objects.remove(o)
shaman = [o for o in scn.collection.all_objects if o.type == 'MESH']
K.env_materials()

# ---- instancing
_src = {}; tri_count = {'env': 0, 'chars': 0}; counts = {}
def place(name, pos, yaw=0.0):
    if name not in _src:
        root = K.build(name)
        _src[name] = list(root.children)
        for o in _src[name]: scn.collection.objects.unlink(o)
        scn.collection.objects.unlink(root)
    e = bpy.data.objects.new(name, None); scn.collection.objects.link(e)
    e.location = g2b(pos); e.rotation_euler = (0, 0, math.radians(yaw))
    for o in _src[name]:
        c = o.copy(); c.parent = e; scn.collection.objects.link(c)
        tri_count['env'] += sum(len(q.vertices) - 2 for q in c.data.polygons)
    counts[name] = counts.get(name, 0) + 1
    return e

# ---- arena, same layout logic as main.gd _build_arena
rnd = random.Random(8)
for x in range(-HALF, HALF):
    for z in range(-HALF, HALF):
        piece = 'floor_tile_big_grate' if (x, z) in ((2, -2), (-3, 1), (0, 2), (-2, -4)) else 'floor_tile_large'
        place(piece, ((x + .5) * TILE, 0, (z + .5) * TILE))
for i in range(-HALF, HALF):
    c = (i + .5) * TILE
    back = {-1: 'wall_arched', 1: 'wall_broken', -4: 'wall_arched'}.get(i, 'wall')
    place(back, (c, 0, -ARENA))
    place('wall', (-ARENA, 0, c), 90)
    place('wall', (ARENA, 0, c), -90)
place('wall_corner', (-ARENA, 0, -ARENA), 0)
place('wall_corner', (ARENA, 0, -ARENA), -90)
for i in range(-HALF, HALF):
    place('rubble_half', ((i + .5) * TILE, 0, ARENA - .4), rnd.uniform(0, 360))
TORCHES = (-10, -4, 0, 8)                          # main.gd has -10, -2, 6; moved off the arch and the hole
for x in TORCHES:
    place('torch_mounted', (x, 2.4, -ARENA + .5))
for x in (-6, 2, 10):
    place('banner_patternA_red' if x == 2 else 'banner_red', (x, 0, -ARENA + .4))
for p in ((-8, 0, -8), (8, 0, -8), (-8, 0, 7), (8, 0, 7)):       # LAYOUTS "hall"
    place('pillar_decorated', p)
place('barrel_large', (-14.5, 0, -14)); place('barrel_small', (-12.8, 0, -14.6))
place('crates_stacked', (14, 0, -13.8), 20); place('chest_gold', (13.6, 0, 12), -30); place('box_large', (-14.2, 0, 12.5), 15)
# set dressing inside the frame
place('column', (-11.5, 0, -14.2)); place('candle_triple', (-4.7, 0, -14.9)); place('candle_lit', (-3.5, 0, -14.9), 0)
place('table_medium_tablecloth', (11.3, 0, -14.0), 8); place('candle_lit', (11.2, 1.0, -14.0))
place('floor_tile_large_rocks', (-10, .01, -6)); place('box_large', (12.4, 0, -11.2), -18)

# ---- drawn light: glow is drawn, not lit. Cut warm shapes added over the wall so the seams stay visible.
def glow_mat(name, c, fac):
    """Flat warm wash laid over the stone at a fixed strength, so seams and hatching still read through it."""
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission'); tr = nt.nodes.new('ShaderNodeBsdfTransparent'); mx = nt.nodes.new('ShaderNodeMixShader')
    em.inputs[0].default_value = C.srgb(c); mx.inputs[0].default_value = fac
    nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], out.inputs[0])
    try: m.surface_render_method = 'BLENDED'
    except Exception: m.blend_method = 'BLEND'
    return m
GLOW_A = glow_mat('E_GlowA', (.62, .24, .05), .11); GLOW_B = glow_mat('E_GlowB', (.9, .46, .08), .17)
def decal(name, mat, poly):
    me = bpy.data.meshes.new(name); me.from_pydata(poly, [], [tuple(range(len(poly)))]); me.update(); me.materials.append(mat)
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o); o.visible_shadow = False
    tri_count['env'] += len(poly) - 2
    return o
def spiky(cx, cz, rx, rz, n, r, y):
    return [(cx + math.cos(i / n * 6.283) * rx * (r.uniform(.72, 1.0) if i % 2 else r.uniform(1.0, 1.16)), y, cz + math.sin(i / n * 6.283) * rz * (r.uniform(.72, 1.0) if i % 2 else r.uniform(1.0, 1.16))) for i in range(n)]
gr = random.Random(5)
for x in TORCHES:
    Y = ARENA - .515
    decal('glow', GLOW_A, spiky(x, 2.72, 1.0, .92, 18, gr, Y))
    decal('glow', GLOW_B, spiky(x, 2.78, .62, .58, 12, gr, Y - .002))

# ---- minions: appended from the enemy blend, one rig per body, frozen on a chosen frame
MINION = os.path.join(C.DIR, 'out', 'enemies', 'minion.blend')
def add_minion(pos, face_yaw, action, frame, scale=1.0):
    with bpy.data.libraries.load(MINION, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n != 'floor']
        if action not in bpy.data.actions: dst.actions = list(src.actions)
    objs = [o for o in dst.objects if o]
    rig = next(o for o in objs if o.type == 'ARMATURE')
    for o in objs: scn.collection.objects.link(o)
    rig.location = g2b(pos); rig.rotation_euler = (0, 0, math.radians(face_yaw)); rig.scale = (scale,) * 3
    if not rig.animation_data: rig.animation_data_create()
    act = bpy.data.actions[action]
    rig.animation_data.action = act
    if act.slots: rig.animation_data.action_slot = act.slots[0]
    scn.frame_set(frame)
    # freeze: pose values stay on the bones once the action is off
    for pb in rig.pose.bones: pb.matrix_basis = pb.matrix_basis.copy()
    rig.animation_data.action = None
    for o in objs:
        if o.type == 'MESH':
            tri_count['chars'] += sum(len(q.vertices) - 2 for q in o.data.polygons)
            ink = o.modifiers.get('Ink')
            if ink: ink.thickness *= 1.5
    return rig
# (yaw: 0 faces the camera. Positive turns toward +X)
add_minion((-3.4, 0, -12.2), 58, '1H_Melee_Attack_Chop', 10, MINION_SCALE)
add_minion((4.3, 0, -13.4), -50, 'Running_A', 4, MINION_SCALE)
add_minion((4.0, 0, -10.2), -40, '1H_Melee_Attack_Chop', 10, MINION_SCALE)
add_minion((-2.4, 0, -9.4), 34, '1H_Melee_Attack_Chop', 7, MINION_SCALE)
add_minion((-6.8, 0, -11.6), 40, 'Idle_Combat', 18, MINION_SCALE)

# ---- the shaman stands where the rig looks
e = bpy.data.objects.new('Shaman', None); scn.collection.objects.link(e); e.location = g2b(FOCUS); e.scale = (CHAR_SCALE,) * 3
for o in shaman:
    o.parent = e
    tri_count['chars'] += sum(len(q.vertices) - 2 for q in o.data.polygons)
    ink = o.modifiers.get('Ink')
    if ink: ink.thickness *= 1.5

# ---- light and camera
C.comic_scene(floor=False, key=(46, 6, -32))
for l in bpy.data.objects:
    if l.type == 'LIGHT' and l.name.startswith('Fill'): l.data.energy = .34
w = scn.world; next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND').inputs[0].default_value = C.srgb(C.INK)

# a shadow-only roof with a broken hole: its soft edge steps through the toon bands, so the pool of light over the
# fight falls off through halftone and hatching into spot black. The hole is projected along the sun to land on the floor.
ROOF_Z = 26.0; POOL = (.6, -11.7, 10.2, 5.7)        # floor centre x, z and radii (Godot)
KEY = next(o for o in scn.objects if o.name == 'Key')
KEY.data.angle = math.radians(1.7)
def roof():
    r = random.Random(3); n = 44
    d = KEY.rotation_euler.to_matrix() @ V((0, 0, -1))
    sx, sy = d.x / -d.z * ROOF_Z, d.y / -d.z * ROOF_Z
    cx, cy = POOL[0] - sx, -POOL[1] - sy
    vs, fs = [], []
    for i in range(n):
        a = i / n * 2 * math.pi
        k = r.uniform(.9, 1.02) if i % 2 else r.uniform(1.02, 1.14)
        vs.append((cx + math.cos(a) * POOL[2] * k, cy + math.sin(a) * POOL[3] * k, ROOF_Z))
    for i in range(n):
        a = i / n * 2 * math.pi
        vs.append((cx + math.cos(a) * 400, cy + math.sin(a) * 400, ROOF_Z))
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    me = bpy.data.meshes.new('roof'); me.from_pydata(vs, [], fs); me.update()
    o = bpy.data.objects.new('roof', me); scn.collection.objects.link(o)
    o.visible_camera = False
    return o
if 'noroof' not in ARGV: roof()

off = V(g2b(CAM_OFFSET)) * CAM_ZOOM; target = g2b(FOCUS)
cam = C.camera('CamGame', target + off, target)
cam.data.sensor_fit = 'VERTICAL'; cam.data.angle_y = math.radians(CAM_FOV)
cam.data.clip_end = 200
scn.render.resolution_x, scn.render.resolution_y = (960, 540) if 'preview' in ARGV else (1920, 1080)
scn.frame_set(0)
print('ROOM tris env', tri_count['env'], 'chars', tri_count['chars'], 'pieces', sum(counts.values()), counts)
C.render(os.path.join(OUT, 'room_preview.png' if 'preview' in ARGV else 'room_game.png'), cam)
if 'preview' not in ARGV:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'room.blend'))
print('done room')
