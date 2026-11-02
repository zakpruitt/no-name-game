# Comic look on top of the painted-shaman toolkit. Import from any build script running in Blender:
#   import sys; sys.path.insert(0, COMIC_DIR); import comic_lib as C
# It re-uses every primitive of ../style_poc/build_poc.py (Bag, blob, tube, rock, make_obj ...)
# and replaces the materials. Everything here must stay portable to a Godot spatial shader:
# flat tones, window-space halftone, fresnel inner ink, inverted-hull outline.
import bpy, math, os, random, bmesh
from mathutils import Vector as V, Euler, Matrix, Quaternion as Q

DIR = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(DIR, '..', 'style_poc', 'build_poc.py')).read().rsplit('\nrun()', 1)[0]
_src = _src.replace("bpy.context.window.scene = scn", "pass").replace("SCN = 'POC'", "SCN = bpy.context.scene.name")
exec(compile(_src, 'build_poc', 'exec'), globals())

ASPECT = 16 / 9
DOTS = 62     # halftone cells per screen height
HATCH = 95    # hatch lines per screen height
PAPER = (.965, .93, .82)   # the "white" of the page: nothing in the world is pure white
INK = (.012, .01, .02)

def _node(nt, kind, **kw):
    n = nt.nodes.new(kind)
    for k, v in kw.items(): setattr(n, k, v)
    return n

def screen_uv(nt, angle=.5, freq=DOTS):
    tc = _node(nt, 'ShaderNodeTexCoord')
    sp = _node(nt, 'ShaderNodeSeparateXYZ'); nt.links.new(tc.outputs['Window'], sp.inputs[0])
    x = math_(nt, 'MULTIPLY', sp.outputs['X'], ASPECT); y = sp.outputs['Y']
    c, s = math.cos(angle), math.sin(angle)
    u = math_(nt, 'ADD', math_(nt, 'MULTIPLY', x, c), math_(nt, 'MULTIPLY', y, -s))
    v = math_(nt, 'ADD', math_(nt, 'MULTIPLY', x, s), math_(nt, 'MULTIPLY', y, c))
    k = freq * 2 * math.pi
    return math_(nt, 'MULTIPLY', u, k), math_(nt, 'MULTIPLY', v, k)

def halftone_field(nt, angle=.5, freq=DOTS):
    """0..1 field: low at dot centres. `field < coverage` gives dots whose size follows coverage."""
    u, v = screen_uv(nt, angle, freq)
    f = math_(nt, 'MULTIPLY', math_(nt, 'SINE', u), math_(nt, 'SINE', v))
    return math_(nt, 'ADD', math_(nt, 'MULTIPLY', f, .5), .5)

def hatch_field(nt, angle=1.0, freq=HATCH):
    u, _ = screen_uv(nt, angle, freq)
    return math_(nt, 'ADD', math_(nt, 'MULTIPLY', math_(nt, 'SINE', u), .5), .5)

def toon(name, shadow, mid, light, hi=None, rim=(0, 0, 0), brush=.3, extra=None, spot=.075, inner=.17, dots=None):
    """Comic tones: spot black / shadow / halftoned mid / light / optional hot highlight, inked at grazing angles."""
    m, nt = new_mat(name)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    d = nt.nodes.new('ShaderNodeBsdfDiffuse'); d.inputs['Color'].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new('ShaderNodeShaderToRGB'); nt.links.new(d.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new('ShaderNodeRGBToBW'); nt.links.new(s2r.outputs[0], bw.inputs[0])
    tc = nt.nodes.new('ShaderNodeTexCoord'); obj = tc.outputs['Object']
    # brushed edge: streaky, low frequency, so tone shapes look cut with a brush rather than computed
    mp = nt.nodes.new('ShaderNodeMapping'); nt.links.new(obj, mp.inputs[0]); mp.inputs['Scale'].default_value = (1, 1, .4)
    nz = nt.nodes.new('ShaderNodeTexNoise'); nt.links.new(mp.outputs[0], nz.inputs['Vector'])
    nz.inputs['Scale'].default_value = 13; nz.inputs['Detail'].default_value = 1.5; nz.inputs['Roughness'].default_value = .45
    lum = math_(nt, 'ADD', bw.outputs[0], math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', nz.outputs['Fac'], .5), brush * 1.1))
    ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation = 'CONSTANT'
    nt.links.new(lum, ramp.inputs[0])
    cr = ramp.color_ramp
    cr.elements[0].position = 0; cr.elements[0].color = srgb(INK)
    cr.elements[1].position = spot; cr.elements[1].color = srgb(shadow)
    cr.elements.new(.3).color = srgb(mid)
    cr.elements.new(.72).color = srgb(light)
    if hi: cr.elements.new(1.12).color = srgb(hi)
    col = ramp.outputs[0]
    # halftone: shadow-colour dots in the mid band, biggest at the shadow edge, gone by mid-tone
    cov = maprange(nt, lum, .3, .56, .62, 0.0)
    band = math_(nt, 'MULTIPLY', math_(nt, 'GREATER_THAN', lum, .3), math_(nt, 'LESS_THAN', lum, .72))
    dot = math_(nt, 'LESS_THAN', halftone_field(nt), cov)
    col = mix(nt, 'MIX', math_(nt, 'MULTIPLY', dot, band), col, srgb(dots or shadow))
    # hatching: ink lines running into the black shapes on the shadow side
    hcov = maprange(nt, lum, spot, .2, .55, 0.0)
    hband = math_(nt, 'MULTIPLY', math_(nt, 'GREATER_THAN', lum, spot), math_(nt, 'LESS_THAN', lum, .3))
    hl = math_(nt, 'LESS_THAN', hatch_field(nt), hcov)
    col = mix(nt, 'MIX', math_(nt, 'MULTIPLY', hl, hband), col, srgb(INK))
    # a touch of colour from the element lights, kept small: tones must stay flat
    col = mix(nt, 'MIX', .08, col, mix(nt, 'MULTIPLY', 1.0, col, s2r.outputs[0]))
    lw = nt.nodes.new('ShaderNodeLayerWeight'); lw.inputs[0].default_value = .22
    # hard rim, like a coloured kicker in a comic
    rimf = maprange(nt, lw.outputs['Facing'], .83, .86)
    col = mix(nt, 'ADD', rimf, col, srgb(rim))
    if extra: col = extra(nt, obj, col)
    # inner ink: contour darkening that swells and thins with the noise, a brush line not a hull
    lw2 = nt.nodes.new('ShaderNodeLayerWeight'); lw2.inputs[0].default_value = .5
    thin = math_(nt, 'ADD', inner, math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', nz.outputs['Fac'], .5), inner * 1.4))
    edge = math_(nt, 'GREATER_THAN', lw2.outputs['Facing'], math_(nt, 'SUBTRACT', 1.0, thin))
    col = mix(nt, 'MIX', edge, col, srgb(INK))
    em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(col, em.inputs[0]); em.inputs[1].default_value = 1
    nt.links.new(em.outputs[0], out.inputs[0])
    return m

def emit(name, low, high, strength=1.0, core=None):
    """Flat FX colour: three cut tones along attribute g, no glow. Glow is drawn, not lit."""
    m, nt = new_mat(name)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'g'
    r = nt.nodes.new('ShaderNodeValToRGB'); r.color_ramp.interpolation = 'CONSTANT'
    nt.links.new(at.outputs['Fac'], r.inputs[0])
    midc = tuple(low[i] + (high[i] - low[i]) * .55 for i in range(3))
    cr = r.color_ramp
    cr.elements[0].position = 0; cr.elements[0].color = srgb(low)
    cr.elements[1].position = .42; cr.elements[1].color = srgb(midc)
    cr.elements.new(.72).color = srgb(high)
    em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(r.outputs[0], em.inputs[0]); em.inputs[1].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    return m

def flat(name, c):
    m, nt = new_mat(name)
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    em.inputs[0].default_value = srgb(c); nt.links.new(em.outputs[0], out.inputs[0])
    return m

def ink_material():
    ink, nt = new_mat('P_Ink')
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    em.inputs[0].default_value = srgb(INK); nt.links.new(em.outputs[0], out.inputs[0])
    ink.use_backface_culling = True
    # the hull wraps the whole body: if it casts, the body sits in its own shadow (dark, view-dependent blotches)
    ink.use_backface_culling_shadow = True
    return ink

def shared_materials():
    """The palette every comic asset draws from. Enemies add accents, they don't invent new base tones."""
    return {
        'skin': toon('P_Skin', (.36, .1, .14), (.86, .46, .28), (1, .75, .5), (1, .92, .74), rim=(.55, .26, .2), brush=.1, extra=skin_extra),
        'socket': toon('P_Socket', INK, (.1, .03, .05), (.18, .06, .07), brush=.05, inner=.0),
        'hair': toon('P_Hair', (.2, .24, .5), (.62, .68, .86), (.95, .95, .92), (1, 1, .98), rim=(.25, .35, .6), brush=.2, extra=hair_extra, inner=.2),
        'iron': toon('P_Iron', (.05, .06, .14), (.2, .25, .38), (.46, .54, .68), (.86, .92, 1), rim=(.18, .3, .5), brush=.16, extra=iron_extra, inner=.2),
        'bronze': toon('P_Bronze', (.2, .06, .02), (.68, .34, .08), (.98, .68, .18), (1, .95, .56), rim=(.3, .16, .05), brush=.14),
        'leather': toon('P_Leather', (.1, .03, .03), (.34, .14, .08), (.6, .32, .15), rim=(.15, .07, .04), brush=.2),
        'cloth': toon('P_Cloth', (.02, .08, .16), (.03, .32, .36), (.08, .6, .56), (.34, .86, .72), rim=(.05, .24, .24), brush=.28),
        'trousers': toon('P_Trousers', (.06, .05, .13), (.2, .17, .32), (.42, .36, .5), rim=(.1, .1, .2), brush=.24),
        'rock': toon('P_Rock', (.05, .02, .05), (.2, .12, .16), (.42, .28, .28), (.72, .55, .44), rim=(.8, .28, .03), brush=.14, inner=.22),
        'bone': toon('P_Bone', (.36, .17, .1), (.8, .6, .36), (.98, .92, .72), rim=(.2, .15, .1), brush=.14),
        'ice': toon('P_Ice', (.08, .3, .72), (.26, .62, .96), (.6, .9, 1), (.98, 1, 1), rim=(.4, .7, 1), brush=.08, inner=.14),
        'teeth': toon('P_Teeth', (.4, .28, .16), (.8, .7, .44), (.96, .9, .68), brush=.08, inner=.0),
        'black': toon('P_Black', INK, (.03, .02, .03), (.06, .05, .06), brush=.05, inner=.0),
        'floor': toon('P_Floor', (.03, .03, .07), (.09, .09, .16), (.17, .165, .26), brush=.1, inner=.0, spot=.02),
        'fire': emit('P_Fire', (.95, .1, .02), (1, .9, .2)),
        'lava': emit('P_Lava', (1, .28, .02), (1, .86, .2)),
        'bolt': emit('P_Bolt', (.2, .55, 1), (.98, 1, .92)),
        'wind': emit('P_Wind', (.2, .85, .5), (.9, 1, .8)),
        'spirit': emit('P_Spirit', (.05, .75, .72), (.86, 1, .86)),
        'eye_white': emit('P_EyeWhite', PAPER, PAPER),
        'eye_blue': emit('P_EyeBlue', (.1, .45, 1), (.7, .95, 1)),
        'pupil': emit('P_Pupil', INK, INK),
    }
materials = shared_materials

def ink_pass(scale=2.0, min_w=.4, objs=None):
    """Variable line weight: the hull thins and fattens over the form (heavier underneath), like a brush."""
    for o in (objs or [x for x in bpy.context.scene.objects if x.type == 'MESH']):
        s = o.modifiers.get('Ink')
        if not s: continue
        s.thickness = s.thickness * scale
        g = o.vertex_groups.get('inkw') or o.vertex_groups.new(name='inkw')
        for v in o.data.vertices:
            p = v.co
            n = math.sin(p.x * 11 + p.z * 7) * math.sin(p.y * 9 - p.z * 13) * .5 + .5
            under = max(0, -v.normal.z) * .5
            g.add([v.index], max(min_w, min(1, .25 + n * .55 + under)), 'REPLACE')
        s.vertex_group = 'inkw'; s.thickness_vertex_group = min_w

def scale_about(verts, c, s, radius=None):
    for i, v in enumerate(verts):
        if radius is None or (v - c).length < radius:
            verts[i] = c + (v - c) * s

def comic_scene(floor=True, key=(40, 10, -38)):
    """Hard key with real cast shadows (black shapes do half the comic look), blue fill, flat page-dark world."""
    scn = bpy.context.scene
    col = scn.collection
    if 'P_Ink' not in bpy.data.materials: ink_material()
    def light(name, kind, energy, rot=None, loc=None, c=(1, 1, 1), shadow=False):
        d = bpy.data.lights.new(name, kind); d.energy = energy; d.color = c; d.use_shadow = shadow
        if kind == 'SUN': d.angle = math.radians(.6)
        o = bpy.data.objects.new(name, d); col.objects.link(o)
        if rot: o.rotation_euler = [math.radians(a) for a in rot]
        if loc: o.location = loc
        return o
    light('Key', 'SUN', 3.6, rot=key, c=(1, .97, .9), shadow=True)
    light('Fill', 'SUN', .42, rot=(72, 0, 150), c=(.55, .62, 1))
    w = bpy.data.worlds.get('COMIC') or bpy.data.worlds.new('COMIC'); w.use_nodes = True; scn.world = w
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = srgb((.05, .05, .1)); bg.inputs[1].default_value = 1
    scn.view_settings.view_transform = 'Standard'; scn.view_settings.look = 'None'
    try: scn.render.engine = 'BLENDER_EEVEE'
    except TypeError as e: print(e)
    scn.render.resolution_x, scn.render.resolution_y, scn.render.resolution_percentage = 1280, 720, 100
    scn.render.film_transparent = False
    if floor:
        m = bpy.data.materials.get('P_Floor') or shared_materials()['floor']
        me = bpy.data.meshes.new('floor')
        vs = [(0, 0, 0)] + [(40 * math.cos(i / 48 * 6.283), 40 * math.sin(i / 48 * 6.283), 0) for i in range(48)]
        me.from_pydata(vs, [], [(0, 1 + i, 1 + (i + 1) % 48) for i in range(48)]); me.update()
        me.materials.append(m)
        col.objects.link(bpy.data.objects.new('floor', me))
    return scn

def camera(name, loc, target, lens=50, ortho=None):
    d = bpy.data.cameras.new(name)
    if ortho: d.type = 'ORTHO'; d.ortho_scale = ortho
    else: d.lens = lens
    o = bpy.data.objects.new(name, d); bpy.context.scene.collection.objects.link(o)
    o.location = loc; o.rotation_euler = (V(target) - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    return o

def render(path, cam=None):
    scn = bpy.context.scene
    if cam: scn.camera = cam
    scn.render.image_settings.file_format = 'PNG'
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)

def tris(objs=None):
    t = 0
    for o in (objs or bpy.context.scene.objects):
        if o.type == 'MESH' and o.name not in ('floor',):
            t += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return t
