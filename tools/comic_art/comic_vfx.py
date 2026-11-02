# Comic VFX kit. Everything is a drawn shape: flat cut tones, ink outlines, stepped timing, nothing glows or blends.
# Each piece is portable to Godot: a mesh plus an AnimationPlayer or tween, sprites for the words, a CanvasLayer for panels.
import bpy, math, random
from mathutils import Vector as V, Quaternion as Q, Matrix
import comic_lib as C

FONT = r'C:\Windows\Fonts\impact.ttf'   # POC only: Impact ships with Windows, it is not licensed for the game
ELEMENTS = {
    'spirit': dict(low=(.04, .62, .62), high=(.82, 1, .84), word=((.05, .7, .68), (.94, 1, .6))),
    'wind': dict(low=(.12, .66, .3), high=(.9, 1, .72), word=((.1, .66, .3), (.95, 1, .55))),
    'earth': dict(low=(.86, .2, .02), high=(1, .86, .22), word=((.9, .1, .02), (1, .85, .15))),
    'water': dict(low=(.1, .42, .92), high=(.88, .98, 1), word=((.08, .35, .9), (.8, .96, 1))),
}
rng = random.Random(21)

def _dissolving(name, nt_build, cull=False):
    m, nt = C.new_mat(name)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    surf = nt_build(nt)
    info = nt.nodes.new('ShaderNodeObjectInfo')
    hole = C.math_(nt, 'GREATER_THAN', C.halftone_field(nt, .9, 44), info.outputs['Alpha'])
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    mx = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(hole, mx.inputs[0]); nt.links.new(surf, mx.inputs[1]); nt.links.new(tr.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    m.use_backface_culling = cull
    m.use_backface_culling_shadow = True
    return m

def ghost_material(name, low, high):
    """Spectral body: dark core, cut bright edge along attribute g, dissolves through halftone dots via object alpha."""
    def build(nt):
        at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'g'
        r = nt.nodes.new('ShaderNodeValToRGB'); r.color_ramp.interpolation = 'CONSTANT'
        nt.links.new(at.outputs['Fac'], r.inputs[0])
        cr = r.color_ramp
        cr.elements[0].position = 0; cr.elements[0].color = C.srgb(tuple(x * .55 for x in low))
        cr.elements[1].position = .34; cr.elements[1].color = C.srgb(low)
        cr.elements.new(.74).color = C.srgb(high)
        em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(r.outputs[0], em.inputs[0])
        return em.outputs[0]
    return _dissolving(name, build, cull=True)

def ink_dissolve():
    def build(nt):
        em = nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value = C.srgb(C.INK)
        return em.outputs[0]
    return _dissolving('FX_InkD', build, cull=True)

class Kit:
    def __init__(s, scn, cam, element='spirit'):
        s.scn, s.cam, s.el = scn, cam, ELEMENTS[element]
        s.col = bpy.data.collections.new('FX'); scn.collection.children.link(s.col)
        s.objs = []
        s.q = (cam.rotation_euler.to_quaternion())
        s.back = s.q @ V((0, 0, 1))
        s.ghost = ghost_material('FX_Ghost', s.el['low'], s.el['high'])
        s.inkd = ink_dissolve()
        s.ink = C.flat('FX_Ink', C.INK)
        s.paper = C.flat('FX_Paper', C.PAPER)
        s.yellow = C.flat('FX_Yellow', (1, .84, .1))
        s.red = C.flat('FX_Red', (.92, .14, .06))
        s.accent = C.flat('FX_Accent', s.el['high'])
        s.accent2 = C.flat('FX_Accent2', s.el['low'])
        s.lens = cam.data.lens
        s.axe_me = s._axe_mesh()
        s.puff_me = s._puff_mesh()
        s.chunk_me = s._chunk_mesh()

    # ------------------------------------------------------------ plumbing
    def _link(s, me, name, hull=0.0, scale=None):
        o = bpy.data.objects.new(name, me); s.col.objects.link(o)
        if hull:
            m = o.modifiers.new('Ink', 'SOLIDIFY'); m.thickness = hull; m.offset = 1; m.use_flip_normals = True; m.material_offset = 1; m.use_rim = False
        o.rotation_mode = 'QUATERNION'
        o.visible_shadow = False   # drawn effects are ink on the page: they don't land shadows on the floor
        o.hide_render = o.hide_viewport = True
        s.objs.append(o)
        return o

    def vis(s, o, a, b):
        for f, h in ((0, True), (a, False), (b, True)):
            if f == 0 and a == 0: continue
            o.hide_render = o.hide_viewport = h
            o.keyframe_insert('hide_render', frame=f); o.keyframe_insert('hide_viewport', frame=f)

    def key(s, o, f, loc=None, rot=None, scale=None, alpha=None):
        if loc is not None:
            o.location = loc; o.keyframe_insert('location', frame=f)
        if rot is not None:
            o.rotation_quaternion = rot; o.keyframe_insert('rotation_quaternion', frame=f)
        if scale is not None:
            o.scale = (scale, scale, scale) if isinstance(scale, (int, float)) else scale; o.keyframe_insert('scale', frame=f)
        if alpha is not None:
            o.color = (1, 1, 1, alpha); o.keyframe_insert('color', frame=f)

    def finish(s):
        """Everything steps: FX are animated on twos with no in-betweens, like drawn frames."""
        for o in s.objs:
            ad = o.animation_data
            if not ad or not ad.action: continue
            cb = ad.action.layers[0].strips[0].channelbag(ad.action.slots[0])
            for fc in cb.fcurves:
                for kp in fc.keyframe_points: kp.interpolation = 'CONSTANT'
        # the hidden state at frame 0 must be applied before rendering starts
        s.scn.frame_set(0)

    # ------------------------------------------------------------ meshes
    def _bag_mesh(s, bag, name, mats):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in bag.v], [], bag.f); me.update()
        ca = me.color_attributes.new('g', 'FLOAT_COLOR', 'POINT')
        for i, t in enumerate(bag.t): ca.data[i].color = (t, t, t, 1)
        import bmesh
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        for m in mats: me.materials.append(m)
        return me

    def _axe_mesh(s):
        """A shaped axe, 1 m from butt (origin) to head, bit towards +X, flat in XZ. Edge bright through g."""
        b = C.Bag('ghost')
        C.tube(b, [V((0, 0, 0)), V((0, 0, .5)), V((0, 0, 1.0))], [.026, .022, .026], sides=6, sub=1, tval=.5)
        C.blob(b, V((0, 0, 0)), (.04, .04, .04), seg=8, rings=5, t=.5)
        top = .8
        outline = [(0, -.05, .1), (.14, -.12, .15), (.32, -.22, .55), (.42, -.2, 1), (.47, 0, 1), (.42, .2, 1), (.32, .18, .55), (.14, .08, .15), (0, .05, .1)]
        n = len(outline); vs = []; ts = []
        for sgn in (1, -1):
            for x, y, t in outline:
                vs.append(V((x, sgn * (.02 if x < .3 else .005), top + y))); ts.append(t)
        b.add(vs, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)] + [(n - 1, 0, n, 2 * n - 1)], ts)
        back = [(0, -.04, .1), (-.17, -.03, .6), (-.27, .03, 1), (-.13, .05, .4), (0, .05, .1)]
        n = len(back); vs = []; ts = []
        for sgn in (1, -1):
            for x, y, t in back:
                vs.append(V((x, sgn * .012, top + y))); ts.append(t)
        b.add(vs, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)] + [(n - 1, 0, n, 2 * n - 1)], ts)
        for sgn in (1, -1):   # a rune cut into the blade: gives the big flat shape a drawn detail
            for pts in ([(.12, -.05), (.2, -.04), (.27, -.13), (.22, -.14)], [(.13, .03), (.21, .02), (.28, .1), (.23, .12)], [(.05, -.02), (.3, -.015), (.3, .015), (.05, .02)]):
                k = len(pts); vs = [V((x, sgn * .0235 if x < .3 else sgn * .0235, top + y)) for x, y in pts]
                b.add(vs, [tuple(range(k)) if sgn > 0 else tuple(reversed(range(k)))], [0.0] * k)
        return s._bag_mesh(b, 'fx_axe', [s.ghost, s.inkd])

    def _puff_mesh(s):
        b = C.Bag('p')
        for (x, y, z, r) in ((0, 0, 0, .5), (.42, .05, -.1, .34), (-.4, -.05, -.06, .36), (.1, -.1, .36, .34), (-.16, .1, -.34, .28), (.28, 0, .26, .22)):
            C.blob(b, V((x, y, z)), (r, r, r), seg=10, rings=6)
        for i, v in enumerate(b.v):
            b.t[i] = .85 if v.z > .18 else (.5 if v.z > -.18 else .1)
        m = C.emit('FX_Puff', (.42, .4, .46), (.96, .92, .8))
        return s._bag_mesh(b, 'fx_puff', [m, s.ink_nocull()])

    def ink_nocull(s):
        m = bpy.data.materials['P_Ink']
        return m

    def _chunk_mesh(s):
        b = C.Bag('c'); C.rock(b, V(), (.5, .5, .5), sub=1, jit=.1)
        return s._bag_mesh(b, 'fx_chunk', [bpy.data.materials['P_Rock'], bpy.data.materials['P_Ink']])

    def _poly_mesh(s, name, layers):
        """layers: [(points [(x, y)], material, z)], fan-filled in order."""
        vs, fs, mi = [], [], []
        mats = []
        for pts, mat, z in layers:
            if mat not in mats: mats.append(mat)
            b = len(vs); vs.append((sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts), z)); vs += [(p[0], p[1], z) for p in pts]
            for i in range(len(pts)):
                fs.append((b, b + 1 + i, b + 1 + (i + 1) % len(pts))); mi.append(mats.index(mat))
        me = bpy.data.meshes.new(name); me.from_pydata(vs, [], fs); me.update()
        for m in mats: me.materials.append(m)
        me.polygons.foreach_set('material_index', mi); me.update()
        return me

    def _star(s, n, r0, r1, seed, jag=.3):
        r = random.Random(seed); pts = []
        for i in range(n * 2):
            a = i / (n * 2) * 6.2832 + r.uniform(-.05, .05)
            R = (r1 * r.uniform(1 - jag, 1 + jag)) if i % 2 == 0 else (r0 * r.uniform(.85, 1.15))
            pts.append((math.cos(a) * R, math.sin(a) * R))
        return pts

    def _text_mesh(s, text, low, high, extrude=.06):
        if FONT not in [f.filepath for f in bpy.data.fonts]:
            bpy.data.fonts.load(FONT)
        font = next(f for f in bpy.data.fonts if f.filepath == FONT)
        cu = bpy.data.curves.new('t', 'FONT'); cu.body = text; cu.font = font; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.extrude = extrude; cu.shear = .22
        ob = bpy.data.objects.new('t', cu); s.scn.collection.objects.link(ob)
        bpy.context.view_layer.update()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        bpy.data.objects.remove(ob); bpy.data.curves.remove(cu)
        ca = me.color_attributes.new('g', 'FLOAT_COLOR', 'POINT')
        ys = [v.co.y for v in me.vertices]; y0, y1 = min(ys), max(ys)
        for i, v in enumerate(me.vertices):
            t = (v.co.y - y0) / max(y1 - y0, 1e-3); ca.data[i].color = (t, t, t, 1)
        key = 'FX_W_%d%d' % (int(low[0] * 99), int(high[2] * 99))
        m = bpy.data.materials.get(key) or C.emit(key, low, high)
        me.materials.clear(); me.materials.append(m); me.materials.append(bpy.data.materials['P_Ink'])
        import bmesh
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        return me

    # ------------------------------------------------------------ pieces
    def axe(s, size, a, b, hull=.02):
        o = s._link(s.axe_me, 'axe', hull=hull / size * 1.0)
        s.vis(o, a, b)
        s.key(o, a, alpha=1.0)
        return o

    def fade(s, o, f, steps=(.65, .35, .12)):
        """Dissolve through growing halftone holes on twos."""
        for i, al in enumerate(steps):
            s.key(o, f + i * 2, alpha=al)

    def burst(s, f, pos, size=1.0, dur=9, seed=None, core=None):
        sd = seed if seed is not None else rng.randint(0, 9999)
        me = s._poly_mesh('burst', [(s._star(11, .55, 1.15, sd), s.ink, 0), (s._star(11, .46, .98, sd), s.paper, .01), (s._star(9, .28, .6, sd + 1), core or s.yellow, .02)])
        o = s._link(me, 'burst')
        p = V(pos) + s.back * .5
        s.vis(o, f, f + dur)
        for df, sc, a in ((0, .55, 0), (2, 1.2, .1), (4, 1.05, .18), (6, .85, .24), (8, .55, .3)):
            s.key(o, f + df, loc=p, rot=s.q @ Q((0, 0, 1), a + sd), scale=size * sc)
        return o

    def _on_page(s, f, p, me, size, top=.8):
        """Slide a billboard so its whole shape is on the page at frame f."""
        from bpy_extras.object_utils import world_to_camera_view as w2c
        s.scn.frame_set(int(f))
        v = w2c(s.scn, s.cam, p)
        hw = v.z * s.cam.data.sensor_width * .5 / s.cam.data.lens * 2  # full width of the page at that depth
        hh = hw * s.scn.render.resolution_y / s.scn.render.resolution_x
        xs = [c.co.x for c in me.vertices]; ys = [c.co.y for c in me.vertices]
        tw = (max(xs) - min(xs)) * size * 1.22 * .5 / hw; th = (max(ys) - min(ys)) * size * 1.22 * .5 / hh
        x = min(max(v.x, tw + .02), 1 - tw - .02); y = min(max(v.y, th + .14), top - th)
        M = s.cam.matrix_world.to_3x3()
        return p + M @ V((1, 0, 0)) * (x - v.x) * hw + M @ V((0, 1, 0)) * (y - v.y) * hh

    def word(s, f, pos, text, size=1.0, dur=20, tilt=.1, low=None, high=None):
        low = low or (.9, .12, .04); high = high or (1, .86, .12)   # always hot: an element-coloured word sinks into its own effect
        me = s._text_mesh(text, low, high)
        o = s._link(me, 'word_' + text, hull=.06)
        p = s._on_page(f, V(pos) + s.back * 1.0, me, size)
        s.vis(o, f, f + dur)
        r = s.q @ Q((0, 0, 1), tilt)
        for df, sc in ((0, .6), (2, 1.22), (4, 1.0), (dur - 4, 1.0), (dur - 2, 1.08)):
            s.key(o, f + df, loc=p + V((0, 0, .03 * df)), rot=r, scale=size * sc)
        return o

    def ring(s, f, pos, r0, r1, dur=8, color=None):
        pts = lambda R, sd: [(math.cos(i / 40 * 6.283) * R * (1 + .05 * math.sin(i * 2.7 + sd)), math.sin(i / 40 * 6.283) * R * (1 + .05 * math.sin(i * 2.7 + sd))) for i in range(40)]
        out_, in_ = pts(1, 1), pts(.8, 2)
        vs = [(x, y, .03) for x, y in out_] + [(x, y, .03) for x, y in in_]
        fs = [(i, (i + 1) % 40, 40 + (i + 1) % 40, 40 + i) for i in range(40)]
        me = bpy.data.meshes.new('ring'); me.from_pydata(vs, [], fs); me.update(); me.materials.append(color or s.paper)
        o = s._link(me, 'ring'); s.vis(o, f, f + dur)
        for i in range(0, dur, 2):
            k = (i / max(dur - 2, 1)) ** .6
            s.key(o, f + i, loc=pos, scale=r0 + (r1 - r0) * k)
        return o

    def cracks(s, f, pos, size=2.0, dur=40, n=9):
        vs, fs, mi = [], [], []
        r = random.Random(int(f))
        for i in range(n):
            a = i / n * 6.283 + r.uniform(-.25, .25); p = V((0, 0, 0)); w = .09 * size * .5
            for j in range(5):
                L = size * r.uniform(.14, .3) * (1 if j else .7)
                a2 = a + r.uniform(-.6, .6)
                q = p + V((math.cos(a2) * L, math.sin(a2) * L, 0))
                d = (q - p).normalized(); side = V((-d.y, d.x, 0))
                w2 = w * .68
                b = len(vs); vs += [p + side * w, p - side * w, q - side * w2, q + side * w2]; fs.append((b, b + 1, b + 2, b + 3)); mi.append(0)
                b = len(vs); vs += [p + side * w * .35 + V((0, 0, .004)), p - side * w * .35 + V((0, 0, .004)), q - side * w2 * .35 + V((0, 0, .004)), q + side * w2 * .35 + V((0, 0, .004))]; fs.append((b, b + 1, b + 2, b + 3)); mi.append(1)
                p, w = q, w2
        me = bpy.data.meshes.new('cracks'); me.from_pydata([tuple(v) for v in vs], [], fs); me.update()
        me.materials.append(s.ink); me.materials.append(s.accent); me.polygons.foreach_set('material_index', mi); me.update()
        o = s._link(me, 'cracks'); s.vis(o, f, f + dur); s.key(o, f, loc=V(pos) + V((0, 0, .02)))
        return o

    def puffs(s, f, pos, n=6, R=1.2, size=.5, dur=14):
        for i in range(n):
            a = i / n * 6.283 + rng.uniform(-.3, .3)
            d = V((math.cos(a), math.sin(a), 0)); sz = size * rng.uniform(.75, 1.25); rr = R * rng.uniform(.7, 1.15)
            o = s._link(s.puff_me, 'puff', hull=.03); s.vis(o, f, f + dur)
            for df in range(0, dur, 2):
                k = 1 - (1 - df / dur) ** 2.2
                sc = sz * (.5 + k * .9) * (1 if df < dur * .6 else max(.15, 1 - (df / dur - .6) * 2.2))
                s.key(o, f + df, loc=V(pos) + d * rr * k + V((0, 0, .2 + .55 * k)), rot=s.q, scale=sc)

    def debris(s, f, pos, n=8, speed=5.0, size=.16, dur=20):
        for i in range(n):
            a = rng.uniform(0, 6.283); u = rng.uniform(.5, 1)
            vel = V((math.cos(a) * speed * u, math.sin(a) * speed * u, rng.uniform(3, 7)))
            sz = size * rng.uniform(.6, 1.5)
            axis = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
            o = s._link(s.chunk_me, 'chunk', hull=.03); s.vis(o, f, f + dur)
            for df in range(0, dur, 2):
                t = df / 24
                q = V(pos) + vel * t + V((0, 0, -9.8 * t * t + .15))
                q.z = max(q.z, sz * .4)
                s.key(o, f + df, loc=q, rot=Q(axis, df * .55), scale=sz)

    def _plane(s, d):
        hw = d * 18 / s.lens; return hw, hw * 9 / 16

    def speedlines(s, f, dur=8, n=44, inner=.48, ink=True):
        """Radial ink wedges on the camera, three drawings cycling on twos."""
        d = 1.0; hw, hh = s._plane(d); R = math.hypot(hw, hh) * 1.15
        for var in range(3):
            r = random.Random(100 + var); vs, fs = [], []
            for i in range(n):
                a = i / n * 6.283 + r.uniform(-.06, .06)
                w = r.uniform(.006, .022) * R
                ri = R * inner * r.uniform(.85, 1.4)
                c, sn = math.cos(a), math.sin(a)
                # ellipse-fit so it frames the middle of a 16:9 picture
                tip = (c * ri * (hw / hh) ** .5, sn * ri / (hw / hh) ** .5)
                b = len(vs); vs += [(tip[0], tip[1], -d), (c * R * 1.4 - sn * w, sn * R * 1.4 + c * w, -d), (c * R * 1.4 + sn * w, sn * R * 1.4 - c * w, -d)]
                fs.append((b, b + 1, b + 2))
            me = bpy.data.meshes.new('lines'); me.from_pydata(vs, [], fs); me.update(); me.materials.append(s.ink if ink else s.paper)
            o = s._link(me, 'speedlines'); o.parent = s.cam
            for start in range(f + var * 2, f + dur, 6):
                s._vis_add(o, start, start + 2)

    def _vis_add(s, o, a, b):
        o.hide_render = o.hide_viewport = False
        o.keyframe_insert('hide_render', frame=a); o.keyframe_insert('hide_viewport', frame=a)
        o.hide_render = o.hide_viewport = True
        o.keyframe_insert('hide_render', frame=b); o.keyframe_insert('hide_viewport', frame=b)
        if a > 0 and not getattr(o, '_', False):
            o.keyframe_insert('hide_render', frame=0); o.keyframe_insert('hide_viewport', frame=0)

    def panel(s, f, dur, name, big=False):
        """The combo-ender beat: the page cuts in. Slanted ink bars, paper gutter, a caption box naming the combo."""
        d = .9; hw, hh = s._plane(d); z = -d
        def quad(a, b, c, e, m_):
            return ([a, b, c, e], m_)
        H = hh * (.2 if big else .15); sl = hw * .1
        lay = [
            ([(-hw * 1.1, hh * 1.1), (hw * 1.1, hh * 1.1), (hw * 1.1, hh - H + sl * .25), (-hw * 1.1, hh - H - sl * .25)], s.ink, z),
            ([(-hw * 1.1, hh - H - sl * .25), (hw * 1.1, hh - H + sl * .25), (hw * 1.1, hh - H + sl * .25 - hh * .022), (-hw * 1.1, hh - H - sl * .25 - hh * .022)], s.paper, z),
            ([(-hw * 1.1, -hh * 1.1), (hw * 1.1, -hh * 1.1), (hw * 1.1, -hh + H - sl * .25), (-hw * 1.1, -hh + H + sl * .25)], s.ink, z),
            ([(-hw * 1.1, -hh + H + sl * .25), (hw * 1.1, -hh + H - sl * .25), (hw * 1.1, -hh + H - sl * .25 + hh * .022), (-hw * 1.1, -hh + H + sl * .25 + hh * .022)], s.paper, z),
        ]
        me = s._poly_mesh('panel', lay); o = s._link(me, 'panel'); o.parent = s.cam; s.vis(o, f, f + dur)
        # caption, hung off the top bar
        tme = s._text_mesh(name.upper() + '!', (.92, .12, .05), (1, .84, .1), extrude=.0)
        t = s._link(tme, 'caption', hull=0); t.parent = s.cam; s.vis(t, f, f + dur)
        sc = hh * (.3 if big else .22)
        for df, k in ((0, 1.3), (2, 1.0)):
            s.key(t, f + df, loc=(-hw * .45, hh * .8, z + .002), rot=Q((0, 0, 1), .03), scale=sc * k)
        return o

    def label(s, a, b, text):
        """Which move this is, for the showcase only: bottom-left card."""
        d = .9; hw, hh = s._plane(d)
        tme = s._text_mesh(text, (.96, .92, .82), (.96, .92, .82), extrude=.0)
        t = s._link(tme, 'label'); t.parent = s.cam; s.vis(t, a, b)
        s.key(t, a, loc=(-hw * .62, -hh * .82, -d + .001), rot=Q(), scale=hh * .085)
        return t

    def swoosh(s, f, center, a0, a1, r0, r1, z=1.0, dur=6, tval=None):
        """Drawn smear arc: a thin tapered brush stroke in flat bands (ink, colour, hot edge) with a dry-brush inner edge.
        Three drawings: stroke out, full length, tail thinning away."""
        span = a1 - a0
        for st in range(3):
            tail = (0, .15, .6)[st]; head = (.5, .9, 1)[st]; thin = (1, 1, .55)[st]
            n = 44; vs = []; fs = []; mi = []
            def band(rin, rout, zz, m):
                base = len(vs)
                for i in range(n + 1):
                    u = i / n; ang = a0 + span * (tail + (head - tail) * u)
                    d = V((math.sin(ang), -math.cos(ang), 0))
                    vs.append(d * rin(u, i) + V((0, 0, z + zz))); vs.append(d * rout(u, i) + V((0, 0, z + zz)))
                for i in range(n):
                    fs.append((base + 2 * i, base + 2 * i + 1, base + 2 * i + 3, base + 2 * i + 2)); mi.append(m)
            W = (r1 - r0) * .55 * thin
            wid = lambda u: math.sin(min(1, u * 1.15) * math.pi) ** 1.3 * W
            ragged = lambda i: (.28 if i % 5 == 2 else (.14 if i % 5 == 3 else 0))
            ink = .035 * (r1 / 3) ** .5
            band(lambda u, i: r1 - wid(u) - ink, lambda u, i: r1 + ink * (.2 + wid(u) / max(W, 1e-3)), 0, 0)
            band(lambda u, i: r1 - wid(u) * (1 - ragged(i)), lambda u, i: r1, .006, 1)
            band(lambda u, i: r1 - wid(u) * .38, lambda u, i: r1, .012, 2)
            me = bpy.data.meshes.new('sw'); me.from_pydata([tuple(p) for p in vs], [], fs); me.update()
            for m_ in (s.ink, s.accent2, s.accent): me.materials.append(m_)
            me.polygons.foreach_set('material_index', mi); me.update()
            o = s._link(me, 'swoosh'); s.vis(o, f + st * 2, f + st * 2 + 2 + (2 if st == 2 else 0))
            s.key(o, f + st * 2, loc=center)

    def impact(s, f, pos, size=1.0, word=None, wsize=1.0, big=False, panel=None, tilt=.08):
        pos = V(pos)
        s.burst(f, pos + V((0, 0, .5)), size * 1.25)
        s.ring(f, pos, .4 * size, 3.1 * size, dur=10)
        s.cracks(f, pos, 2.1 * size, dur=22)
        s.puffs(f + 1, pos, n=int(5 + 3 * size), R=1.8 * size, size=.55 * size ** .5)
        s.debris(f, pos, n=int(6 + 4 * size), speed=3.5 + size * 1.5, size=.14 * size ** .5)
        if word: s.word(f + 1, pos + V((0, -.2, 1.5 + size * .4)), word, size=wsize, tilt=tilt)
        if big: s.speedlines(f, dur=10)
        if panel: s.panel(f + 1, 18, panel, big=big)

    # ---- orientations. Axes: local Z butt to head, local X bit
    @staticmethod
    def basis(x, z):
        x = V(x).normalized(); z = V(z).normalized(); x = (x - z * x.dot(z)).normalized()
        y = z.cross(x)
        return Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z))).to_quaternion()
    @staticmethod
    def flat(theta, flip=False):
        """Lying flat, pointing out along theta (from -Y towards +X), bit leading. Broad side up so the top-down camera reads it."""
        r = V((math.sin(theta), -math.cos(theta), 0))
        t = V((math.cos(theta), math.sin(theta), 0))
        return Kit.basis(-t if flip else t, r)
