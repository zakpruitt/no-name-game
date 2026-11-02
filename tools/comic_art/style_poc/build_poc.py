# Style POC: same shaman, inked/painterly comic look, real proportions, static hero pose (no rig).
# Front = -Y, his left (magma) = +X. Skin is unioned by voxel remesh so it reads as one sculpted form.
import bpy, bmesh, math, random
from mathutils import Vector as V, Euler

rng = random.Random(11)
Z, X, Y = V((0, 0, 1)), V((1, 0, 0)), V((0, 1, 0))
SCN = 'POC'

# ---------------------------------------------------------------- nodes
def mix(nt, blend, fac, a, b):
    n = nt.nodes.new('ShaderNodeMix'); n.data_type = 'RGBA'; n.blend_type = blend; n.clamp_result = True
    for sock, val in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(val, (int, float)): sock.default_value = val
        elif isinstance(val, tuple): sock.default_value = val if len(val) == 4 else (*val, 1)
        else: nt.links.new(val, sock)
    return n.outputs[2]

def math_(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new('ShaderNodeMath'); n.operation = op; n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None: continue
        if isinstance(v, (int, float)): n.inputs[i].default_value = v
        else: nt.links.new(v, n.inputs[i])
    return n.outputs[0]

def maprange(nt, val, f0, f1, t0=0.0, t1=1.0):
    n = nt.nodes.new('ShaderNodeMapRange'); n.interpolation_type = 'SMOOTHSTEP' if False else 'LINEAR'; n.clamp = True
    nt.links.new(val, n.inputs[0])
    n.inputs[1].default_value, n.inputs[2].default_value, n.inputs[3].default_value, n.inputs[4].default_value = f0, f1, t0, t1
    return n.outputs[0]

def srgb(c):
    f = lambda x: x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1)

def new_mat(name):
    m = bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name); m.use_nodes = True
    m.node_tree.nodes.clear()
    return m, m.node_tree

def toon(name, shadow, mid, light, hi=None, rim=(0, 0, 0), brush=.3, extra=None):
    """Hard-edged painted light: three or four flat tones, a rough brushed edge between them."""
    m, nt = new_mat(name)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    d = nt.nodes.new('ShaderNodeBsdfDiffuse')
    d.inputs['Color'].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new('ShaderNodeShaderToRGB'); nt.links.new(d.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new('ShaderNodeRGBToBW'); nt.links.new(s2r.outputs[0], bw.inputs[0])
    tc = nt.nodes.new('ShaderNodeTexCoord'); obj = tc.outputs['Object']
    # brush: streaky noise bites into the shadow edge
    mp = nt.nodes.new('ShaderNodeMapping'); nt.links.new(obj, mp.inputs[0]); mp.inputs['Scale'].default_value = (1, 1, .45)
    nz = nt.nodes.new('ShaderNodeTexNoise'); nt.links.new(mp.outputs[0], nz.inputs['Vector'])
    nz.inputs['Scale'].default_value = 16; nz.inputs['Detail'].default_value = 2; nz.inputs['Roughness'].default_value = .5
    fac = math_(nt, 'ADD', bw.outputs[0], math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', nz.outputs['Fac'], .5), brush * 1.2))
    ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation = 'CONSTANT'
    nt.links.new(fac, ramp.inputs[0])
    cr = ramp.color_ramp
    cr.elements[0].position = 0; cr.elements[0].color = srgb(shadow)
    cr.elements[1].position = .3; cr.elements[1].color = srgb(mid)
    e = cr.elements.new(.62); e.color = srgb(light)
    if hi:
        e = cr.elements.new(1.08); e.color = srgb(hi)
    col = ramp.outputs[0]
    # large soft colour drift so nothing is one flat swatch
    nz2 = nt.nodes.new('ShaderNodeTexNoise'); nt.links.new(obj, nz2.inputs['Vector'])
    nz2.inputs['Scale'].default_value = 5; nz2.inputs['Detail'].default_value = 3
    col = mix(nt, 'SOFT_LIGHT', .45, col, nz2.outputs['Color'])
    col = mix(nt, 'MIX', .1, col, mix(nt, 'MULTIPLY', 1.0, col, s2r.outputs[0]))  # coloured lights tint it a little
    # thin rim of light on the shadow side
    lw = nt.nodes.new('ShaderNodeLayerWeight'); lw.inputs[0].default_value = .22
    rimf = maprange(nt, lw.outputs['Facing'], .86, .94)
    col = mix(nt, 'ADD', rimf, col, srgb(rim))
    if extra: col = extra(nt, obj, col)
    em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(col, em.inputs[0]); em.inputs[1].default_value = 1
    nt.links.new(em.outputs[0], out.inputs[0])
    return m

def emit(name, low, high, strength=1.0):
    """Unlit glow, colour along the attribute 'g' (1 = hot base, 0 = tip)."""
    m, nt = new_mat(name)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'g'
    r = nt.nodes.new('ShaderNodeValToRGB'); nt.links.new(at.outputs['Fac'], r.inputs[0])
    r.color_ramp.elements[0].color = srgb(low); r.color_ramp.elements[1].color = srgb(high)
    em = nt.nodes.new('ShaderNodeEmission'); nt.links.new(r.outputs[0], em.inputs[0]); em.inputs[1].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    return m

LAVA = (1, .55, .08)
def cracks(nt, obj, col, scale, width, x0, x1, zmin=None):
    """Glowing crack network on the volcanic side, painted in object space, hot at the seam."""
    sp = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(obj, sp.inputs[0])
    side = maprange(nt, sp.outputs['X'], x0, x1)
    if zmin is not None: side = math_(nt, 'MULTIPLY', side, maprange(nt, sp.outputs['Z'], zmin, zmin + .03))
    warp = nt.nodes.new('ShaderNodeTexNoise'); nt.links.new(obj, warp.inputs['Vector']); warp.inputs['Scale'].default_value = 11; warp.inputs['Detail'].default_value = 4
    vec = mix(nt, 'MIX', .18, obj, warp.outputs['Color'])
    vo = nt.nodes.new('ShaderNodeTexVoronoi'); vo.feature = 'DISTANCE_TO_EDGE'; vo.inputs['Scale'].default_value = scale
    nt.links.new(vec, vo.inputs['Vector'])
    line = maprange(nt, vo.outputs['Distance'], width * side_gate(), 0.0, 0.0, 1.0)
    glow = math_(nt, 'MULTIPLY', line, math_(nt, 'GREATER_THAN', side, .25))
    hot = maprange(nt, vo.outputs['Distance'], width * .45, 0.0)
    c = mix(nt, 'MIX', hot, srgb(LAVA), srgb((1, .92, .55)))
    # char the skin just around the cracks
    char = maprange(nt, vo.outputs['Distance'], width * 2.6, width)
    col = mix(nt, 'MULTIPLY', math_(nt, 'MULTIPLY', char, math_(nt, 'MULTIPLY', side, .55)), col, srgb((.16, .1, .1)))
    return mix(nt, 'MIX', glow, col, c)

def side_gate(): return 1.0

def pulse_socket(nt):
    v = nt.nodes.new('ShaderNodeValue'); v.name = 'StripePulse'; v.outputs[0].default_value = .16
    return v.outputs[0]

def skin_extra(nt, obj, col):
    col = cracks(nt, obj, col, 20, .022, .05, .14)
    # air side: faint swept stripes, a slow-moving band pattern across the -X half
    sp = nt.nodes.new('ShaderNodeSeparateXYZ'); nt.links.new(obj, sp.inputs[0])
    side = maprange(nt, sp.outputs['X'], -.02, -.1)
    nz = nt.nodes.new('ShaderNodeTexNoise'); nt.links.new(obj, nz.inputs['Vector']); nz.inputs['Scale'].default_value = 7
    wave = math_(nt, 'ADD', math_(nt, 'ADD', math_(nt, 'MULTIPLY', sp.outputs['Z'], 34), math_(nt, 'MULTIPLY', sp.outputs['X'], 18)), math_(nt, 'MULTIPLY', nz.outputs['Fac'], 5))
    band = math_(nt, 'GREATER_THAN', math_(nt, 'SINE', wave), .86)
    return mix(nt, 'MIX', math_(nt, 'MULTIPLY', math_(nt, 'MULTIPLY', band, side), pulse_socket(nt)), col, srgb((.62, 1, .8)))

def iron_extra(nt, obj, col):
    return cracks(nt, obj, col, 8.5, .022, .02, .1, zmin=.9)

def hair_extra(nt, obj, col):
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'g'
    nz = nt.nodes.new('ShaderNodeTexNoise'); nt.links.new(obj, nz.inputs['Vector']); nz.inputs['Scale'].default_value = 9; nz.inputs['Detail'].default_value = 1
    k = math_(nt, 'ADD', at.outputs['Fac'], math_(nt, 'MULTIPLY', math_(nt, 'SUBTRACT', nz.outputs['Fac'], .5), .25))
    k = math_(nt, 'GREATER_THAN', k, .84)
    return mix(nt, 'MULTIPLY', math_(nt, 'MULTIPLY', k, .9), col, srgb((.6, .64, .8)))

def materials():
    return {
        'skin': toon('P_Skin', (.26, .12, .12), (.72, .44, .31), (.93, .68, .5), (1, .84, .66), rim=(.5, .3, .25), brush=.12, extra=skin_extra),
        'socket': toon('P_Socket', (.04, .02, .03), (.12, .05, .05), (.2, .09, .08), brush=.1),
        'hair': toon('P_Hair', (.38, .4, .55), (.68, .71, .8), (.87, .89, .94), (1, 1, 1), rim=(.3, .35, .5), brush=.22, extra=hair_extra),
        'iron': toon('P_Iron', (.07, .07, .12), (.22, .24, .31), (.42, .45, .53), (.72, .76, .86), rim=(.25, .28, .4), brush=.2, extra=iron_extra),
        'bronze': toon('P_Bronze', (.14, .06, .03), (.42, .24, .1), (.76, .5, .2), (1, .84, .46), rim=(.3, .18, .08), brush=.2),
        'leather': toon('P_Leather', (.08, .04, .04), (.25, .14, .1), (.45, .28, .17), rim=(.14, .08, .05), brush=.25),
        'cloth': toon('P_Cloth', (.03, .08, .12), (.05, .25, .29), (.13, .47, .47), (.3, .66, .62), rim=(.08, .2, .22), brush=.34),
        'trousers': toon('P_Trousers', (.07, .06, .1), (.2, .19, .26), (.36, .34, .4), rim=(.1, .1, .15), brush=.3),
        'rock': toon('P_Rock', (.04, .025, .04), (.16, .12, .14), (.34, .27, .28), (.55, .47, .45), rim=(.5, .22, .05), brush=.16),
        'bone': toon('P_Bone', (.26, .17, .12), (.64, .52, .37), (.93, .86, .68), rim=(.2, .15, .1), brush=.16),
        'ice': toon('P_Ice', (.2, .4, .68), (.42, .68, .92), (.62, .86, 1), (.88, .97, 1), rim=(.5, .7, .9), brush=.1),
        'teeth': toon('P_Teeth', (.3, .24, .16), (.7, .62, .44), (.9, .85, .66), brush=.1),
        'black': toon('P_Black', (.01, .01, .02), (.03, .02, .03), (.06, .05, .06), brush=.05),
        'floor': toon('P_Floor', (.03, .03, .05), (.09, .085, .12), (.17, .155, .2), rim=(0, 0, 0), brush=.12),
        'fire': emit('P_Fire', (.92, .13, .02), (1, .9, .42), 1.0),
        'lava': emit('P_Lava', (1, .35, .03), (1, .85, .35), 1.0),
        'bolt': emit('P_Bolt', (.3, .62, 1), (.94, 1, 1), 1.0),
        'wind': emit('P_Wind', (.34, .9, .62), (.86, 1, .92), .8),
        'spirit': emit('P_Spirit', (.16, .82, .78), (.78, 1, .96), 1.0),
        'eye_white': emit('P_EyeWhite', (.92, .94, .9), (1, 1, 1), 1.0),
        'eye_blue': emit('P_EyeBlue', (.15, .5, 1), (.75, .95, 1), 1.0),
        'pupil': emit('P_Pupil', (.01, .01, .02), (.01, .01, .02), 1.0),
    }

# ---------------------------------------------------------------- geometry
class Bag:
    def __init__(s, mat, smooth=True, sharp=None):
        s.mat, s.smooth, s.sharp, s.v, s.f, s.t = mat, smooth, sharp, [], [], []
    def add(s, vs, fs, ts=None):
        b = len(s.v); s.v += [V(p) for p in vs]; s.t += ts if ts else [.5] * len(vs)
        s.f += [tuple(i + b for i in f) for f in fs]

def spow(w, e): return math.copysign(abs(w) ** e, w)

def blob(b, c, r, seg=20, rings=14, p=2.0, rot=None, t=.5):
    c = V(c); e = 2 / p
    R = Euler(rot).to_matrix() if rot else None
    vs = [V((0, 0, -r[2]))]
    for j in range(1, rings):
        th = -math.pi / 2 + math.pi * j / rings
        for i in range(seg):
            ph = 2 * math.pi * i / seg
            ct = spow(math.cos(th), e)
            vs.append(V((r[0] * ct * spow(math.cos(ph), e), r[1] * ct * spow(math.sin(ph), e), r[2] * spow(math.sin(th), e))))
    vs.append(V((0, 0, r[2])))
    vs = [c + (R @ q if R else q) for q in vs]
    F = [(0, 1 + (i + 1) % seg, 1 + i) for i in range(seg)]
    for j in range(rings - 2):
        for i in range(seg):
            a_ = 1 + j * seg + i; b_ = 1 + j * seg + (i + 1) % seg
            F.append((a_, b_, b_ + seg, a_ + seg))
    top = len(vs) - 1; base = 1 + (rings - 2) * seg
    F += [(base + i, base + (i + 1) % seg, top) for i in range(seg)]
    b.add(vs, F, [t] * len(vs))

def catmull(pts, n):
    P = [V(p) for p in pts]
    if n <= 1 or len(P) < 3: return P
    o = []
    for i in range(len(P) - 1):
        a = P[max(i - 1, 0)]; b = P[i]; c = P[i + 1]; d = P[min(i + 2, len(P) - 1)]
        for k in range(n):
            u = k / n
            o.append(.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (3 * b - a - 3 * c + d) * u ** 3))
    o.append(P[-1]); return o

def lerp_list(vals, n):
    out = []; m = len(vals) - 1
    for i in range(n):
        f = i / (n - 1) * m; j = min(int(f), m - 1); k = f - j
        A = vals[j]; B = vals[j + 1]
        A = (A, A) if not isinstance(A, (tuple, list)) else A
        B = (B, B) if not isinstance(B, (tuple, list)) else B
        # ease so limbs swell rather than taper linearly
        k = k * k * (3 - 2 * k)
        out.append((A[0] + (B[0] - A[0]) * k, A[1] + (B[1] - A[1]) * k))
    return out

def tube(b, ctrl, radii, sides=12, sub=4, side=None, tval=None, cap=True):
    P = catmull(ctrl, sub)
    m = len(P); W = lerp_list(radii, m)
    s = None; vs, ts, F = [], [], []; idx = []
    for i, p in enumerate(P):
        tg = (P[min(i + 1, m - 1)] - P[max(i - 1, 0)]).normalized()
        ref = V(side) if side is not None else (s if s is not None else (X if abs(tg.x) < .9 else Y))
        s = ref - tg * ref.dot(tg)
        if s.length < 1e-5: s = (Y if abs(tg.y) < .9 else X) - tg * (Y if abs(tg.y) < .9 else X).dot(tg)
        s.normalize(); u = tg.cross(s)
        a, c = W[i]
        tt = (1 - i / (m - 1)) if tval is None else tval
        ring = []
        for k in range(sides):
            an = 2 * math.pi * k / sides
            ring.append(len(vs)); vs.append(p + s * max(a, 1e-4) * math.cos(an) + u * max(c, 1e-4) * math.sin(an)); ts.append(tt)
        idx.append(ring)
    for i in range(m - 1):
        for k in range(sides):
            F.append((idx[i][k], idx[i][(k + 1) % sides], idx[i + 1][(k + 1) % sides], idx[i + 1][k]))
    if cap:
        F.append(tuple(reversed(idx[0]))); F.append(tuple(idx[-1]))
    b.add(vs, F, ts)

def rock(b, c, size, sub=3, jit=.14):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1)
    q = V((rng.uniform(-9, 9), rng.uniform(-9, 9), rng.uniform(-9, 9)))
    fq = rng.uniform(1.4, 2.2)
    vs = []
    for v in bm.verts:
        p = v.co
        d = math.sin(p.x * fq * 2 + q.x) * math.sin(p.y * fq * 2 + q.y) * math.sin(p.z * fq * 2 + q.z) + .5 * math.sin(p.x * fq * 5 + q.y) * math.sin(p.z * fq * 5 + q.x)
        r_ = 1 + jit * d * 1.8
        # cut planes for chiselled faces
        for a_ in (q.x, q.y, q.z):
            n = V((math.cos(a_), math.sin(a_ * 1.3), math.cos(a_ * .7))).normalized()
            r_ = min(r_, .86 / max(p.normalized().dot(n), .25))
        vs.append(V(c) + V((p.x * r_ * size[0], p.y * r_ * size[1], p.z * r_ * size[2])))
    F = [tuple(q_.index for q_ in f.verts) for f in bm.faces]; bm.free()
    b.add(vs, F)

def bolt_path(a, b_, steps, amp):
    a, b_ = V(a), V(b_); d = b_ - a
    s1 = d.cross(Z if abs(d.normalized().z) < .9 else X).normalized(); s2 = d.cross(s1).normalized()
    P = [a]
    for i in range(1, steps):
        k = i / steps
        P.append(a + d * k + s1 * rng.uniform(-amp, amp) + s2 * rng.uniform(-amp, amp))
    P.append(b_); return P

def bolt(b, a, e, steps, amp, w):
    P = bolt_path(a, e, steps, amp)
    tube(b, P, [(w, w), (w * .7, w * .7), (w * .15, w * .15)], sides=5, sub=1)
    return P

# ---------------------------------------------------------------- the character
def build():
    B = {k: Bag(k, smooth=s, sharp=sh) for k, s, sh in (
        ('skin', True, None), ('head', True, None), ('socket', True, None), ('hair', True, None), ('iron', True, 40), ('bronze', True, 40), ('leather', True, None),
        ('cloth', True, None), ('trousers', True, None), ('rock', False, None), ('bone', True, None), ('ice', False, None), ('teeth', True, None), ('black', True, None),
        ('lava', True, None), ('wind', True, None), ('spirit', True, None), ('eye_white', True, None), ('eye_blue', True, None), ('pupil', True, None))}
    for k_ in range(3):
        B['fire%d' % k_] = Bag('fire')
        B['bolt%d' % k_] = Bag('bolt', smooth=False)
    B['spirit_eyes'] = Bag('pupil')
    S, Hd = B['skin'], B['head']

    # skeleton: hunched, head thrust forward, wide low stance
    H = V((.02, -.4, 1.72))
    # ---- torso and neck (skin under the plate; only the torn side shows)
    tube(S, [(0, .0, .86), (0, -.01, 1.02), (0, -.06, 1.24), (0, -.13, 1.46), (.0, -.27, 1.62), H + V((0, .05, -.08))], [(.25, .19), (.26, .19), (.31, .24), (.35, .25), (.14, .13), (.095, .095)], sides=18)
    blob(S, (-.17, -.26, 1.38), (.17, .1, .13))  # pec
    blob(S, (-.27, -.1, 1.2), (.055, .09, .17))  # lat
    for z, y in ((1.04, -.18), (1.12, -.2), (1.21, -.23)):
        blob(S, (-.2, y, z), (.1, .035, .025), rot=(0, .35, 0))  # ribs showing through the torn plate
    # ---- storm arm (-X): raised and reaching, all tendon
    sh = V((-.37, -.14, 1.53)); el = V((-.62, -.3, 1.4)); wr = V((-.75, -.62, 1.58)); hd = V((-.8, -.72, 1.65))
    tube(S, [sh, sh.lerp(el, .5) + V((0, 0, .03)), el], [.115, .1, .075], sides=14)
    blob(S, sh + V((-.05, .0, .03)), (.13, .13, .12))  # deltoid
    tube(S, [el, el.lerp(wr, .35) + V((0, .02, .03)), wr], [.074, .088, .052], sides=14)
    blob(S, hd, (.062, .068, .06), rot=(.5, 0, .2))
    fingers = []
    for i, (dx, dy, dz) in enumerate(((-.11, -.06, .1), (-.09, -.12, .1), (-.04, -.14, .12), (.02, -.13, .1), (.08, -.08, .02))):
        k = hd + V((dx * .55, dy * .55, dz * .55))
        tip = k + V((dx * .5, dy * .9, dz * .8 - .02))
        ctrl = [hd, k, k + (tip - k) * .55 + V((0, 0, .025)), tip]
        tube(S, ctrl, [.024, .021, .017, .012], sides=8, sub=2)
        fingers.append(tip)
        tube(B['bone'], [tip, tip + (tip - k).normalized() * .035], [.011, .001], sides=6, sub=1)
    # ---- head, sculpted forms
    blob(Hd, H + V((0, .03, .04)), (.122, .14, .125))
    blob(Hd, H + V((0, -.03, -.075)), (.1, .09, .085))
    blob(Hd, H + V((0, -.055, -.115)), (.07, .06, .04))
    tube(Hd, [H + V((-.112, -.09, .034)), H + V((-.05, -.13, .046)), H + V((.0, -.13, .016)), H + V((.05, -.13, .022)), H + V((.112, -.085, .022))], [.024, .033, .03, .036, .024], sides=10)
    for sx in (-1, 1):
        blob(Hd, H + V((sx * .088, -.085, -.035)), (.042, .036, .034))
        tube(Hd, [H + V((sx * .05, -.128, -.06)), H + V((sx * .1, -.09, -.1))], [.02, .014], sides=8, sub=1)
    tube(Hd, [H + V((-.002, -.13, .025)), H + V((.002, -.165, -.015)), H + V((.012, -.19, -.05)), H + V((.01, -.165, -.07))], [.019, .023, .032, .017], sides=10)
    for sx in (-1, 1):
        blob(Hd, H + V((sx * .03 + .012, -.163, -.066)), (.02, .017, .016))
    blob(Hd, H + V((-.128, .015, -.005)), (.018, .036, .05), rot=(0, 0, .3))
    rock(B['rock'], H + V((.122, .02, -.01)), (.035, .045, .055), sub=2)
    # eye sockets, painted dark, eyes set deep
    eL = H + V((-.052, -.118, -.003)); eR = H + V((.053, -.13, -.022))
    blob(B['socket'], eL + V((0, .006, 0)), (.041, .012, .034), seg=14, rings=8)
    blob(B['socket'], eR + V((0, .006, 0)), (.043, .012, .023), seg=14, rings=8, rot=(0, -.25, 0))
    blob(B['eye_white'], eL + V((0, -.002, .0)), (.027, .0095, .024), seg=12, rings=8)
    blob(B['eye_blue'], eL + V((.003, -.0095, .004)), (.011, .0035, .011), seg=10, rings=6, t=.3)
    blob(B['pupil'], eL + V((.003, -.0125, .004)), (.0045, .0015, .0045), seg=8, rings=5)
    blob(B['lava'], eR + V((0, -.001, 0)), (.034, .01, .017), seg=12, rings=6, rot=(0, -.25, 0), t=.95)
    blob(B['pupil'], eR + V((-.003, -.0085, 0)), (.0035, .002, .011), seg=8, rings=5)
    # mouth: open, snarling up one side, bad teeth, half lost in the beard
    mouth = H + V((.005, -.128, -.095))
    blob(B['socket'], mouth, (.06, .016, .026), seg=16, rings=10, rot=(0, -.18, 0))
    for x, z, w, h_ in ((-.035, .009, .01, .012), (-.008, .012, .012, .014), (.022, .014, .013, .017), (.045, .018, .009, .012), (-.012, -.018, .009, .01), (.025, -.015, .011, .013)):
        blob(B['teeth'], mouth + V((x, -.012, z)), (w, .006, h_), seg=8, rings=5)
    # ---- brows: heavy white hanks
    def lock(ctrl, w, sides=7, sub=4, thick=.5, flat=None):
        tube(B['hair'], ctrl, [(w * .55, w * thick * .55), (w, w * thick), (w * .72, w * thick * .75), (0.001, .001)], sides=sides, sub=sub, side=flat)
    def clump(ctrl, w, n=3, thick=.5, spread=.05):
        for j in range(n):
            off = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * spread
            pts = [V(p) + off * (i / (len(ctrl) - 1)) ** 1.4 for i, p in enumerate(ctrl)]
            lock(pts, w * rng.uniform(.5, .75), sides=5, sub=3, thick=thick)
    lock([H + V((-.015, -.145, .062)), H + V((-.06, -.15, .08)), H + V((-.115, -.11, .095)), H + V((-.16, -.075, .1))], .026, thick=.7)
    lock([H + V((.012, -.15, .042)), H + V((.06, -.155, .046)), H + V((.115, -.105, .058)), H + V((.16, -.07, .082))], .027, thick=.7)
    # ---- moustache + beard: long, tangled, blown sideways by whatever's coming off him
    wind = V((.11, .1, 0))
    for sx, n_ in ((-1, 4), (1, 3)):
        for i in range(n_):
            q = H + V((sx * (.012 + i * .022), -.15 + i * .012, -.075 + i * .002))
            L = rng.uniform(.1, .16)
            lock([q, q + V((sx * L * .4, -.012, -.012)), q + V((sx * L * .85, .004, -.05)), q + V((sx * L * 1.25, .03, -.11))], rng.uniform(.018, .026))
    tube(B['hair'], [H + V((.0, -.1, -.1)), H + V((.01, -.13, -.26)), H + V((.04, -.1, -.42)), H + V((.08, -.05, -.56))], [(.11, .05), (.1, .055), (.065, .04), (.004, .004)], sides=10, tval=.9)
    for x, L in ((-.105, .3), (-.075, .4), (-.045, .47), (-.015, .54), (.015, .56), (.045, .5), (.075, .42), (.105, .32), (-.03, .32), (.03, .34), (.0, .44)):
        w_ = rng.uniform(-.02, .02)
        q = H + V((x, -.112 + abs(x) * .42, -.12 + abs(x) * .55))
        ctrl = [q, q + V((x * .45 + w_, -.05, -L * .28)), q + V((x * .25 + wind.x * .4 - w_, -.042, -L * .58)), q + V((wind.x * .8 + w_, .015, -L * .85)), q + V((wind.x * 1.2, .05, -L * 1.05))]
        lock(ctrl, rng.uniform(.042, .06), sides=8, thick=.6)
    # ---- hair: a scalp mass, a crown of big swept locks, a heavy mane down his back, a few strays
    blob(B['hair'], H + V((0, .055, .06)), (.125, .125, .112), seg=18, rings=12, t=.95)
    def hair_lock(az, el_, L, w, lift, sides=8):
        a, e = math.radians(az), math.radians(el_)
        o = V((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        q = H + V((0, .05, .05)) + V((o.x * .115, o.y * .118, o.z * .105))
        fall = V((o.x * .14 + .17 + rng.uniform(-.06, .06), .3, lift))
        ctrl = [q - o * .015, q + o * L * .24 + V((0, .03, .03)), q + o * L * .42 + fall * L * .32, q + o * L * .42 + fall * L * .72, q + o * L * .32 + fall * L * 1.1]
        lock(ctrl, w, sides=sides, thick=.62)
    for az, el_, L, w in ((22, 64, .46, .056), (58, 80, .36, .05), (90, 86, .58, .062), (128, 70, .32, .046), (160, 58, .42, .05), (2, 42, .26, .04), (178, 40, .3, .04)):
        hair_lock(az, el_, L, w, rng.uniform(.3, .46))
    for az, el_, L, w in ((12, 24, .6, .06), (42, 30, .7, .066), (72, 35, .78, .07), (104, 35, .8, .07), (136, 30, .7, .066), (167, 24, .6, .06), (-8, 8, .46, .048), (188, 8, .46, .048)):
        hair_lock(az, el_, L, w, rng.uniform(-.8, -.6))
    for i in range(5):
        hair_lock(rng.uniform(-10, 190), rng.uniform(35, 80), rng.uniform(.22, .34), .017, rng.uniform(.1, .5), sides=5)
    # ---- breastplate: rows round the chest, ripped along the -X front edge
    def plate(b, rows, th=.016):
        m_, c_ = len(rows), len(rows[0])
        vs = [p + o * .0 for r_ in rows for p, o in r_] + [p - o * th for r_ in rows for p, o in r_]
        F = []; n_ = m_ * c_; ix = lambda i, j: i * c_ + j
        for i in range(m_ - 1):
            for j in range(c_ - 1):
                q = (ix(i, j), ix(i, j + 1), ix(i + 1, j + 1), ix(i + 1, j))
                F.append(q); F.append(tuple(n_ + v for v in reversed(q)))
        for j in range(c_ - 1):
            F.append((ix(0, j), n_ + ix(0, j), n_ + ix(0, j + 1), ix(0, j + 1)))
            F.append((ix(m_ - 1, j), ix(m_ - 1, j + 1), n_ + ix(m_ - 1, j + 1), n_ + ix(m_ - 1, j)))
        for i in range(m_ - 1):
            F.append((ix(i, 0), ix(i + 1, 0), n_ + ix(i + 1, 0), n_ + ix(i, 0)))
            F.append((ix(i, c_ - 1), n_ + ix(i, c_ - 1), n_ + ix(i + 1, c_ - 1), ix(i + 1, c_ - 1)))
        b.add(vs, F)
    chest_c = lambda z: V((.01, -.01 - max(0, z - 1.02) * .24, z))
    chest_r = lambda z: (.27 + .1 * math.sin(min(1, max(0, (z - .94) / .62)) * 2.3) , .205 + .065 * math.sin(min(1, max(0, (z - .94) / .62)) * 2.2))
    edge = [(.92, -96), (.99, -118), (1.07, -94), (1.15, -112), (1.23, -90), (1.31, -106), (1.39, -86), (1.47, -96), (1.55, -80), (1.6, -86)]
    rows = []
    for z, end in edge:
        c = chest_c(z); rx, ry = chest_r(z)
        row = []
        for j in range(30):
            az = 128 + (end - 128) * j / 29
            d = V((math.cos(math.radians(az)), math.sin(math.radians(az)), 0))
            # sternum ridge and a touch of pectoral swell
            ridge = .012 * math.exp(-((az + 90) / 14) ** 2)
            row.append((c + V((d.x * (rx + .018), d.y * (ry + .018 + ridge), 0)), d))
        rows.append(row)
    plate(B['iron'], rows)
    # bronze rim along the torn edge and the hem
    tube(B['bronze'], [r_[-1][0] + r_[-1][1] * .002 for r_ in rows], [.012, .012], sides=6, sub=1)
    tube(B['bronze'], [p + o * .004 for p, o in rows[0]], [.016, .016], sides=6, sub=1)
    tube(B['bronze'], [p + o * .004 for p, o in rows[-1]], [.015, .015], sides=6, sub=1)
    for j in range(2, 28, 4):
        p, o = rows[1][j]
        blob(B['bronze'], p + o * .005, (.012, .012, .012), seg=8, rings=5)
    # ---- pauldron on the storm side
    SC = sh + V((-.05, .0, .1))
    blob(B['iron'], SC, (.2, .2, .13), seg=26, rings=14, p=2.25, rot=(.08, .22, 0))
    blob(B['iron'], SC + V((-.075, 0, -.085)), (.16, .175, .085), seg=22, rings=10, p=2.2, rot=(.08, .42, 0))
    blob(B['iron'], SC + V((-.125, 0, -.15)), (.115, .14, .06), seg=20, rings=8, p=2.2, rot=(.08, .6, 0))
    tube(B['bronze'], [SC + V((.205 * math.cos(a * .35) * .98, .205 * math.sin(a * .35), -.043 + .046 * math.cos(a * .35))) for a in range(19)], [.014, .014], sides=7, sub=1)
    for a in (1.4, 2.1, 2.9, 3.7, 4.5, 5.2):
        blob(B['bronze'], SC + V((.17 * math.cos(a), .17 * math.sin(a), .05)), (.011, .011, .009), seg=8, rings=5)
    q = SC + V((-.05, -.02, .11))
    tube(B['bone'], [q, q + V((-.05, -.01, .08)), q + V((-.13, -.02, .15)), q + V((-.24, -.03, .17))], [.05, .037, .02, .002], sides=10)
    # ---- vambrace
    a0 = el.lerp(wr, .34); a1 = el.lerp(wr, .92)
    tube(B['iron'], [a0, a0.lerp(a1, .5), a1], [.097, .094, .081], sides=14, sub=2)
    tube(B['bronze'], [a0 + (a0 - a1).normalized() * .005, a0 - (a0 - a1).normalized() * .018], [.101, .101], sides=14, sub=1)
    tube(B['bronze'], [a1 - (a1 - a0).normalized() * .018, a1 + (a1 - a0).normalized() * .005], [.086, .086], sides=14, sub=1)
    # ---- magma arm (+X): hanging, massive, the fist nearly at his knee. Lava core, plates of rock adrift.
    ms = V((.36, -.12, 1.52)); me_ = V((.56, -.13, 1.14)); mw = V((.62, -.26, .78)); mf = V((.65, -.3, .6))
    tube(B['lava'], [ms, me_, mw, mf], [.1, .08, .07, .13], sides=12, tval=.55)
    rock(B['rock'], ms + V((.04, 0, .06)), (.25, .23, .19), sub=4, jit=.09)
    for dx, dy, dz, r_, ang in ((-.1, -.08, .16, .05, .2), (.08, .05, .18, .056, -.1), (.17, -.03, .1, .046, -.4)):
        q = ms + V((dx, dy, dz))
        tube(B['rock'], [q, q + V((math.sin(ang) * .14, -.01, .13)), q + V((math.sin(ang) * .24, -.01, .24))], [r_, r_ * .62, .002], sides=6, sub=1)
    for k, (P0, P1, n_, s_) in enumerate(((ms, me_, 10, .1), (me_, mw, 12, .118), (mw, mf, 7, .13))):
        d = (P1 - P0).normalized(); u_ = d.cross(Y if abs(d.y) < .8 else X).normalized(); v_ = d.cross(u_)
        for i in range(n_):
            f = (i + .5) / n_ + rng.uniform(-.03, .03); a = i * 2.3 + rng.uniform(-.3, .3)
            rr = s_ * rng.uniform(.82, 1.06)
            o = u_ * math.cos(a) + v_ * math.sin(a)
            rock(B['rock'], P0.lerp(P1, f) + o * rr, (s_ * rng.uniform(.46, .62), s_ * rng.uniform(.46, .62), s_ * rng.uniform(.55, .75)), sub=2)
    # the fist: too big
    rock(B['rock'], mf + V((0, .03, .02)), (.16, .13, .15), sub=4, jit=.09)
    for i, y in enumerate((-.1, -.033, .035, .1)):
        rock(B['rock'], mf + V((.1 + (.018 if 0 < i < 3 else 0), y - .05, -.07)), (.058, .05, .062), sub=2)
        rock(B['rock'], mf + V((.04, y - .09, -.12)), (.047, .043, .04), sub=2)
    rock(B['rock'], mf + V((-.04, -.15, -.02)), (.06, .05, .07), sub=2)
    for i in range(10):
        a = i * 1.1; o = V((math.cos(a), math.sin(a), 0))
        blob(B['lava'], mf + o * rng.uniform(.14, .17) + V((0, -.03, rng.uniform(-.1, .1))), (.024, .024, .024), seg=8, rings=5, t=.9)
    def flame(base, d, L, w):
        base = V(base); d = V(d).normalized()
        s_ = d.cross(Y if abs(d.y) < .9 else X).normalized(); o = s_ * rng.choice((-1, 1)) * L * rng.uniform(.12, .24)
        tube(B[fire_key], [base, base + d * L * .3 + o * .5, base + d * L * .66 - o * .4, base + d * L + o], [(w, w * .7), (w * 1.05, w * .72), (w * .55, w * .45), (.002, .002)], sides=9, sub=3)
    for fire_key in ('fire0', 'fire1', 'fire2'):
        for dx, dy, L, w in ((0, 0, .46, .085), (.1, -.05, .32, .062), (-.09, .04, .36, .066), (.05, .08, .28, .052), (-.05, -.09, .26, .05), (.13, .05, .22, .045), (-.14, -.03, .23, .045)):
            flame(mf + V((dx, dy - .02, .08)), (dx * .9, dy * .5, 1), L * .7 * rng.uniform(.8, 1.2), w * .85)
        flame(ms.lerp(me_, .35) + V((.04, 0, .05)), (.1, 0, 1), .12 * rng.uniform(.8, 1.2), .03)
        flame(me_.lerp(mw, .5) + V((.06, 0, .04)), (.15, 0, 1), .12 * rng.uniform(.8, 1.2), .03)
    for i in range(16):
        spot = mf + V((rng.uniform(-.26, .26), rng.uniform(-.2, .2), rng.uniform(.2, .85)))
        rock(B['lava'], spot, tuple([rng.uniform(.004, .011)] * 3), sub=0, jit=.0)
    # ---- belt, fauld, cloth
    Pv = V((0, 0, .9))
    tube(B['leather'], [Pv + V((.285 * math.cos(a * .3142), .225 * math.sin(a * .3142), .02)) for a in range(21)], [(.018, .05)] * 2, sides=8, sub=1, side=Z)
    bk = Pv + V((.0, -.232, .02))
    blob(B['bronze'], bk, (.075, .02, .07), seg=10, rings=7, p=2.8)
    rock(B['spirit'], bk - Y * .017, (.03, .012, .03), sub=1, jit=.02)
    for i in range(11):
        a = i / 11 * 6.283
        o = V((math.cos(a), math.sin(a), 0))
        q = Pv + V((o.x * .29, o.y * .23, -.035))
        L = rng.uniform(.17, .23) * (.5 if o.x < -.5 and o.y < .5 else 1)
        sd = o.cross(Z).normalized()
        tube(B['iron'], [q, q + o * .03 - Z * L * .5, q + o * .055 - Z * L], [(.07, .009), (.074, .01), (.058, .008)], sides=6, sub=2, side=sd)
        blob(B['bronze'], q + o * .012 - Z * .025, (.011, .011, .011), seg=8, rings=5)
    for i in range(14):
        a = i / 14 * 6.283 + .2
        o = V((math.cos(a), math.sin(a), 0))
        q = Pv + V((o.x * .27, o.y * .21, -.05))
        L = rng.uniform(.3, .46) * (.45 if o.x < -.3 and o.y < .4 else 1)
        sd = o.cross(Z).normalized()
        tube(B['cloth'], [q, q + o * .04 - Z * L * .5, q + o * .07 + sd * rng.uniform(-.03, .03) - Z * L], [(.055, .005), (.058, .005), (.002, .002)], sides=5, sub=3, side=sd)
    # cloak: long tatters off the shoulders, streaming back
    for i in range(7):
        x = -.3 + i * .1
        q = V((x, .16, 1.54 - abs(x) * .22))
        L = rng.uniform(.55, .85)
        ctrl = [q, q + V((x * .1, .1, -L * .28)), q + V((x * .2 + rng.uniform(-.03, .03), .17, -L * .6)), q + V((x * .26 + rng.uniform(-.05, .05), .24, -L * .86)), q + V((x * .3 + rng.uniform(-.07, .07), .32, -L * 1.02))]
        tube(B['cloth'], ctrl, [(.07, .008), (.08, .009), (.066, .008), (.003, .002)], sides=5, sub=4, side=X)
    # ---- flesh leg (+X)
    hl = V((.16, -.01, .9)); kl = V((.27, -.15, .5)); al = V((.25, .0, .13))
    tube(B['trousers'], [hl, hl.lerp(kl, .5), kl, kl.lerp(al, .5), al + V((0, 0, .05))], [.15, .135, .095, .09, .07], sides=14)
    tube(B['leather'], [al + V((0, 0, .17)), al + V((0, 0, .03))], [.09, .085], sides=12, sub=1)
    blob(B['leather'], al + V((.01, -.09, -.065)), (.085, .155, .065), p=2.4)
    blob(B['iron'], al + V((.01, -.165, -.075)), (.098, .1, .056), p=2.6, seg=16, rings=9)
    blob(B['iron'], kl + V((0, -.065, 0)), (.085, .05, .085), seg=18, rings=10, p=2.3)
    blob(B['bronze'], kl + V((0, -.107, 0)), (.022, .01, .022), seg=8, rings=5)
    tube(B['iron'], [kl + V((0, -.05, -.06)), kl.lerp(al, .5) + V((0, -.078, 0)), al + V((0, -.078, .02))], [(.075, .012), (.075, .013), (.055, .01)], sides=8, sub=2, side=X)
    # ---- ice peg (-X): crystal from the hip to a point, strapped on
    hr = V((-.17, -.01, .9)); kr = V((-.28, -.25, .53)); tr = V((-.25, -.4, .0))
    tube(B['ice'], [hr, hr.lerp(kr, .5), kr, kr.lerp(tr, .45), tr], [.115, .1, .08, .052, .003], sides=7, sub=2)
    for i in range(14):
        f = rng.uniform(.04, .62)
        p = hr.lerp(kr, f / .62) if f < .62 else kr
        a = rng.uniform(0, 6.28); o = V((math.cos(a), math.sin(a) * .9, 0))
        L = rng.uniform(.08, .2)
        q = p + o * .1
        tube(B['ice'], [q - o * .02, q + o * L * .5 + Z * L * .35, q + o * L + Z * L * .7], [.042, .028, .001], sides=5, sub=1)
    mid_ = hr.lerp(kr, .72)
    d_ = (kr - hr).normalized()
    tube(B['iron'], [mid_ - d_ * .025, mid_ + d_ * .025], [.13, .125], sides=12, sub=1)
    tube(B['bronze'], [mid_ - d_ * .008, mid_ + d_ * .008], [.14, .14], sides=12, sub=1)
    for sx in (-.08, .08):
        tube(B['leather'], [mid_ + V((sx, -.11, .02)), mid_.lerp(Pv + V((-.17, -.2, .0)), .55) + V((sx, -.06, 0)), Pv + V((-.17 + sx, -.22, .0))], [(.022, .007), (.022, .007)], sides=6, sub=3, side=X)
    # gourd and bone charm at his hip
    gc = Pv + V((.31, -.1, -.14))
    blob(B['bronze'], gc, (.062, .058, .074), seg=14, rings=9)
    blob(B['bronze'], gc + Z * .09, (.036, .034, .042), seg=12, rings=8)
    tube(B['leather'], [gc + Z * .125, gc + Z * .165], [.012, .016], sides=7, sub=1)
    # ---- lightning: three flipbook frames, played one at a time
    for bolt_key in ('bolt0', 'bolt1', 'bolt2'):
        for a0_, n_ in ((1.0, 8), (3.4, 8), (5.2, 7)):
            pts = []
            for i in range(n_ + 1):
                k = i / n_
                q = sh.lerp(el, min(1, k * 2)) if k < .5 else el.lerp(wr, (k - .5) * 2)
                a = a0_ + rng.uniform(-.9, .9) + k * 3
                pts.append(q + V((math.cos(a) * .09, math.sin(a) * .09, math.sin(a * 1.3) * .09)) + V((0, 0, .01)))
            pts.append(hd)
            tube(B[bolt_key], pts, [.005, .011, .012, .007], sides=5, sub=1, tval=.75)
        for tip in fingers:
            bolt(B[bolt_key], tip + V((0, 0, .008)), tip + V((rng.uniform(-.15, .05), rng.uniform(-.25, -.07), rng.uniform(.0, .17))), 5, .03, .014)
        for i in range(10):
            s_ = hd + V((rng.uniform(-.1, .1), rng.uniform(-.1, .1), rng.uniform(-.05, .15)))
            bolt(B[bolt_key], s_, s_ + V((rng.uniform(-.16, .16), rng.uniform(-.2, .05), rng.uniform(-.1, .2))), 4, .022, .008)
        for i in range(10):
            spot = hd + V((rng.uniform(-.28, .22), rng.uniform(-.34, .12), rng.uniform(-.1, .38)))
            rock(B[bolt_key], spot, tuple([rng.uniform(.004, .009)] * 3), sub=0, jit=0)
    # ---- air rings round the arm: thin, broken, tilted
    for P0, P1, f, R_, a0_, tilt in ((sh, el, .75, .18, .4, .15), (el, wr, .12, .19, 2.4, -.2), (el, wr, .6, .165, 4.4, .18)):
        c = P0.lerp(P1, f); n = (P1 - P0).normalized()
        n = (n + V((tilt, -tilt, tilt * .5))).normalized()
        e1 = n.cross(Z).normalized(); e2 = n.cross(e1).normalized()
        for st, span, w in ((a0_, 3.9, .012), (a0_ + 4.3, 1.5, .009)):
            pts = [c + (e1 * math.cos(st + span * i / 14) + e2 * math.sin(st + span * i / 14)) * R_ for i in range(15)]
            W_ = [(.0005 + w * math.sin(i / 14 * math.pi) * .55, .0005 + w * math.sin(i / 14 * math.pi)) for i in range(15)]
            tube(B['wind'], pts, W_, sides=7, sub=1, side=n, tval=.5)
    # ---- spirit familiar, drifting by his shoulder with a long curl of tail
    g = V((-.74, .02, 1.98))
    blob(B['spirit'], g, (.082, .074, .086), seg=18, rings=12, t=.75)
    tube(B['spirit'], [g + V((.02, .05, -.05)), g + V((-.06, .1, -.13)), g + V((-.17, .12, -.14)), g + V((-.24, .12, -.04)), g + V((-.2, .14, .07)), g + V((-.1, .16, .1)), g + V((-.06, .19, .03))], [.05, .04, .032, .024, .016, .002], sides=9)
    for sx in (-1, 1):
        tube(B['spirit'], [g + V((sx * .04, 0, .07)), g + V((sx * .05, .01, .125)), g + V((sx * .09, .02, .165))], [.021, .015, .001], sides=7, sub=2, tval=.8)
        blob(B['spirit_eyes'], g + V((sx * .03, -.07, .015)), (.012, .004, .018), seg=8, rings=5)
        tube(B['spirit_eyes'], [g + V((sx * .012, -.071, .036)), g + V((sx * .048, -.066, .054))], [.005, .005], sides=5, sub=1)
    global JOINTS
    JOINTS = dict(H=H.copy(), sh=sh, el=el, wr=wr, hd=hd, ms=ms, me=me_, mw=mw, mf=mf, hl=hl, kl=kl, al=al, hr=hr, kr=kr, tr=tr, g=g.copy(), SC=SC, Pv=Pv)
    HS = 1.2
    for k, b in B.items():
        for i, v in enumerate(b.v):
            near = (v - H).length
            if k == 'hair' or (k in ('head', 'socket', 'eye_white', 'eye_blue', 'pupil', 'teeth') and near < .4) or (k in ('rock', 'lava') and near < .2):
                b.v[i] = H + (v - H) * HS
    return B


def make_obj(name, b, mats, col, voxel=None, smooth_iter=0, outline=.006, decim=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in b.v], [], b.f); me.update()
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); col.objects.link(o)
    if voxel is None:
        ca = me.color_attributes.new('g', 'FLOAT_COLOR', 'POINT')
        for i, t in enumerate(b.t):
            ca.data[i].color = (t, t, t, 1)
    if voxel:
        r = o.modifiers.new('r', 'REMESH'); r.mode = 'VOXEL'; r.voxel_size = voxel; r.use_smooth_shade = True
        if smooth_iter:
            sm = o.modifiers.new('s', 'SMOOTH'); sm.factor = .6; sm.iterations = smooth_iter
        if decim:
            dc = o.modifiers.new('d', 'DECIMATE'); dc.ratio = decim
        dg = bpy.context.evaluated_depsgraph_get()
        nm = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        o.modifiers.clear(); o.data = nm; bpy.data.meshes.remove(me); me = nm
    me.materials.clear()
    mat_key = {'head': 'skin'}.get(b.mat, b.mat)
    me.materials.append(mats[mat_key]); me.materials.append(bpy.data.materials['P_Ink'])
    bm = bmesh.new(); bm.from_mesh(me)
    if b.sharp:
        lim = math.radians(b.sharp)
        for e in bm.edges:
            if e.is_manifold and e.calc_face_angle(0) > lim: e.smooth = False
    for f in bm.faces: f.smooth = b.smooth
    bm.to_mesh(me); bm.free()
    if outline:
        s = o.modifiers.new('Ink', 'SOLIDIFY'); s.thickness = outline; s.offset = 1; s.use_flip_normals = True; s.material_offset = 1; s.use_rim = False
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    return o, tris


def run():
    # a fresh scene in this file; the original model file is untouched
    scn = bpy.data.scenes.get(SCN)
    if scn:
        for o in list(scn.collection.all_objects):
            bpy.data.objects.remove(o)
    else:
        scn = bpy.data.scenes.new(SCN)
    bpy.context.window.scene = scn
    col = scn.collection
    mats = materials()
    ink, nt = new_mat('P_Ink')
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission'); em.inputs[0].default_value = (.008, .006, .012, 1)
    nt.links.new(em.outputs[0], out.inputs[0]); ink.use_backface_culling = True

    rng.seed(11)
    B = build()
    total = 0
    for k, b in B.items():
        if not b.v:
            print('EMPTY', k); continue
        if k == 'skin': o, t = make_obj('skin', b, mats, col, voxel=.0075, smooth_iter=14, outline=.006, decim=.1)
        elif k == 'head': o, t = make_obj('head', b, mats, col, voxel=.0035, smooth_iter=8, outline=.005, decim=.14)
        elif b.mat in ('fire', 'lava', 'bolt', 'wind', 'spirit', 'eye_white', 'eye_blue', 'pupil', 'socket', 'teeth', 'black'):
            o, t = make_obj(k, b, mats, col, outline=.0 if b.mat not in ('fire', 'spirit') else .004)
        elif k == 'hair':
            o, t = make_obj(k, b, mats, col, outline=.0045)
            o.visible_shadow = False
        else: o, t = make_obj(k, b, mats, col, outline=.006)
        total += t
        print(f'{k:10s} tris={t}')
    print('TOTAL tris', total)
    # floor
    f = Bag('floor')
    verts = [V((0, 0, 0))] + [V((40 * math.cos(i / 64 * 6.283), 40 * math.sin(i / 64 * 6.283), 0)) for i in range(64)]
    f.add(verts, [(0, 1 + i, 1 + (i + 1) % 64) for i in range(64)])
    make_obj('floor', f, mats, col, outline=0)
    st = Bag('rock', smooth=False)
    r2 = random.Random(5)
    for i in range(170):
        a = r2.uniform(0, 6.283); d_ = r2.uniform(1.2, 13)
        z_ = r2.uniform(.012, .05)
        rock(st, (d_ * math.cos(a), d_ * math.sin(a), z_ * .5), (r2.uniform(.03, .1), r2.uniform(.03, .1), z_), sub=1, jit=.1)
    make_obj('floor_stones', st, mats, col, outline=.004)
    sh_ = Bag('black')
    verts = [V((.02, -.1, .004))] + [V((.02 + .72 * math.cos(i / 32 * 6.283), -.1 + .42 * math.sin(i / 32 * 6.283), .004)) for i in range(32)]
    sh_.add(verts, [(0, 1 + i, 1 + (i + 1) % 32) for i in range(32)])
    make_obj('ground_shadow', sh_, mats, col, outline=0)
    # lights: one hard key, element light from the fist and the hand
    def light(name, kind, energy, loc=None, rot=None, c=(1, 1, 1), size=None, shadow=True):
        d = bpy.data.lights.new(name, kind); d.energy = energy; d.color = c; d.use_shadow = shadow
        if kind == 'SUN': d.angle = math.radians(1.5)
        else: d.shadow_soft_size = size or .05
        o = bpy.data.objects.new(name, d); col.objects.link(o)
        if loc: o.location = loc
        if rot: o.rotation_euler = [math.radians(a) for a in rot]
    light('Key', 'SUN', 4.2, rot=(58, 8, -30), c=(1, .96, .88), shadow=False)
    light('Fill', 'SUN', .5, rot=(70, 0, 145), c=(.55, .62, 1), shadow=False)
    light('Fist', 'POINT', 34, loc=(.92, -.55, .62), c=(1, .42, .1), shadow=False)
    light('MagmaSh', 'POINT', 16, loc=(.9, -.75, 1.25), c=(1, .45, .12), shadow=False)
    light('Hand', 'POINT', 12, loc=(-.95, -1.0, 1.75), c=(.35, .6, 1), shadow=False)
    w = bpy.data.worlds.get('POC') or bpy.data.worlds.new('POC'); w.use_nodes = True; scn.world = w
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = srgb((.045, .04, .065)); bg.inputs[1].default_value = 1
    scn.view_settings.view_transform = 'Standard'; scn.view_settings.look = 'None'
    try: scn.render.engine = 'BLENDER_EEVEE'
    except TypeError as e: print(e)
    scn.render.film_transparent = False
    # cameras: beauty and game angle
    def cam(name, loc, target, lens=None, ortho=None):
        d = bpy.data.cameras.new(name)
        if ortho: d.type = 'ORTHO'; d.ortho_scale = ortho
        else: d.lens = lens
        o = bpy.data.objects.new(name, d); col.objects.link(o)
        o.location = loc; o.rotation_euler = (V(target) - V(loc)).to_track_quat('-Z', 'Y').to_euler()
        return o
    scn.render.resolution_x, scn.render.resolution_y, scn.render.resolution_percentage = 900, 1200, 100
    scn.camera = cam('CamHero', (.55, -5.2, 1.15), (-.02, -.15, 1.12), lens=58)
    cam('CamBack', (-1.4, 3.3, 1.5), (0, 0, 1.1), lens=58)
    cam('CamSide', (-5.2, -1.6, 1.25), (-.05, -.2, 1.12), lens=58)
    cam('CamGame', (0, -3.4, 5.1), (0, 0, .95), ortho=3.2)
    return scn

run()
