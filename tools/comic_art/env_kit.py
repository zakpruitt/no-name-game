# Comic dungeon kit: drop-in replacements for assets/kaykit/dungeon, same names, sizes and pivots.
#   blender -b -P env_kit.py                 every piece: out/env/<piece>.glb + out/env/kit_sheet.png
#   blender -b -P env_kit.py -- check        re-imports the exports and compares bounds and nodes with the KayKit files
# Import it from env_room.py for the materials and meshes (the toon look does not travel in a .glb).
#
# Ink is geometry: seams are real gaps over a black core, cracks and hatching are thin tapered strips, so the
# line work survives any export and needs no texture. Vertex attribute 'g' is a per-stone tone (0.5 = neutral).
import bpy, sys, os, math, random
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C
from mathutils import Vector as V

OUT = os.path.join(C.DIR, 'out', 'env')
KAYKIT = r"C:\Users\pruit\Desktop\dev\awaken\assets\kaykit\dungeon"

# Blender coords of the KayKit pieces, measured from the .glb files: (lo, hi)
REF = {
    'banner_patternA_red': ((-.75, -.69, .53), (.75, -.38, 3.73)), 'banner_red': ((-.75, -.69, .53), (.75, -.38, 3.73)),
    'barrel_large': ((-.9, -.9, 0), (.9, .9, 2)), 'barrel_small': ((-.5, -.5, 0), (.5, .5, 1.02)),
    'box_large': ((-.75, -.75, 0), (.75, .75, 1.5)), 'candle_lit': ((-.17, -.16, 0), (.17, .17, 1.05)),
    'candle_triple': ((-.17, -.23, 0), (.33, .16, .87)), 'chest_gold': ((-.85, -.75, 0), (.85, .7, 1.3)),
    'column': ((-.35, -.35, 0), (.35, .35, 1.4)), 'crates_stacked': ((-1.09, -1.09, 0), (1, 1.16, 2.14)),
    'floor_tile_big_grate': ((-2, -2, -1), (2, 2, .05)), 'floor_tile_big_spikes': ((-2, -2, -.1), (2, 2, 2)),
    'floor_tile_large': ((-2, -2, -.1), (2, 2, .05)), 'floor_tile_large_rocks': ((-2, -2, -.1), (2, 2, .54)),
    'pillar': ((-.75, -.75, 0), (.75, .75, 4)), 'pillar_decorated': ((-1.12, -.96, 0), (1.12, .75, 4)),
    'rubble_half': ((0, -1.48, 0), (4, 1.52, 3.5)), 'rubble_large': ((-4.07, -1.6, 0), (4.06, 1.59, 3.5)),
    'sword_shield_gold': ((-1.12, -.25, -.82), (1.12, .08, .85)), 'table_medium_tablecloth': ((-1, -1, 0), (1, 1, 1)),
    'torch_mounted': ((-.28, -.62, -.38), (.28, 0, .68)), 'wall': ((-2, -.5, 0), (2, .5, 4)),
    'wall_arched': ((-2, -.5, 0), (2, .5, 4)), 'wall_broken': ((-2, -.5, 0), (2, .5, 4)), 'wall_corner': ((-2, -2, 0), (.5, .5, 4)),
}

# ------------------------------------------------------------------ materials
_M = {}
def tone_extra(nt, obj, col):
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'g'
    return C.mix(nt, 'MULTIPLY', 1.0, col, C.maprange(nt, at.outputs['Fac'], 0, 1, .6, 1.4))

def env_materials():
    """Limited palette: indigo stone, bone, one red-orange accent. Everything else is a dimmed cousin of those."""
    if _M: return _M
    if 'P_Ink' not in bpy.data.materials: C.ink_material()
    t = lambda name, *a, **k: C.toon(name, *a, extra=tone_extra, **k)
    _M.update({
        # the floor sits two steps below everything: its light tone is darker than the wall's mid-light
        'floor': t('E_Floor', (.042, .042, .085), (.085, .085, .15), (.128, .125, .205), brush=.06, inner=.0, spot=.015),
        'floor_hi': t('E_FloorHi', (.05, .05, .1), (.1, .1, .17), (.168, .163, .26), brush=.05, inner=.0, spot=.015),
        'grout': t('E_Grout', (.016, .016, .036), (.036, .036, .07), (.066, .064, .118), brush=.02, inner=.0, spot=.01),
        'stone': t('E_Stone', (.045, .045, .105), (.125, .125, .235), (.225, .225, .365), (.3, .3, .45), rim=(.06, .07, .16), brush=.025, inner=.12, spot=.05),
        'cap': t('E_Cap', (.04, .04, .095), (.11, .11, .21), (.195, .195, .32), (.26, .26, .39), rim=(.05, .06, .14), brush=.025, inner=.1, spot=.05),
        'iron': t('E_Iron', (.025, .025, .06), (.09, .1, .18), (.2, .215, .33), (.38, .41, .55), rim=(.08, .1, .2), brush=.1, inner=.16),
        'wood': t('E_Wood', (.04, .03, .07), (.12, .09, .15), (.235, .165, .21), (.31, .22, .25), rim=(.06, .04, .08), brush=.2, inner=.14),
        'bone': t('E_Bone', (.17, .11, .15), (.42, .34, .33), (.68, .6, .5), (.8, .72, .58), rim=(.12, .08, .08), brush=.12, inner=.12),
        'banner': t('E_Banner', (.22, .025, .06), (.56, .07, .05), (.86, .2, .05), (.96, .32, .07), rim=(.2, .03, .02), brush=.22, inner=.14),
        'gold': t('E_Gold', (.2, .07, .05), (.55, .26, .06), (.82, .5, .12), (.95, .7, .3), rim=(.2, .1, .02), brush=.12, inner=.12),
        'void': t('E_Void', (.008, .008, .02), (.016, .016, .036), (.028, .028, .06), brush=.02, inner=.0),
        'ink': C.flat('E_Inkline', C.INK),
        'wash': C.flat('E_InkWash', (.028, .027, .06)),
        'fire': C.emit('E_Fire', (.95, .16, .03), (1, .88, .28)),
    })
    return _M

# ------------------------------------------------------------------ piece container
HULL = {'stone': .022, 'cap': .022, 'iron': .014, 'wood': .018, 'bone': .014, 'banner': .018, 'gold': .016, 'fire': .012}
FLAT = ('stone', 'cap', 'void', 'grout', 'floor', 'floor_hi', 'ink', 'wash')

class Piece:
    """Bags grouped by (node, material, smooth). node = the glTF node name; extra nodes keep the KayKit split (spikes, lid)."""
    def __init__(s, name, seed=None):
        s.name = name; s.bags = {}; s.node = name
        s.r = random.Random(seed if seed is not None else sum(ord(c) * (i + 3) for i, c in enumerate(name)))
        C.rng.seed(s.r.randint(0, 9999))
    def b(s, mat, smooth=False, node=None):
        k = (node or s.node, mat, smooth)
        if k not in s.bags: s.bags[k] = C.Bag(mat, smooth=smooth)
        return s.bags[k]

def fit(p):
    """Remap every vertex onto the KayKit bounds: hand-noisy geometry, exact size and pivot."""
    lo0, hi0 = REF[p.name]
    vs = [v for b in p.bags.values() for v in b.v]
    lo = [min(v[i] for v in vs) for i in range(3)]; hi = [max(v[i] for v in vs) for i in range(3)]
    for b in p.bags.values():
        for v in b.v:
            for i in range(3):
                d = hi[i] - lo[i]
                v[i] = lo0[i] + (v[i] - lo[i]) * (hi0[i] - lo0[i]) / d if d > 1e-6 else lo0[i]

def finish(p, col=None):
    """Bags to objects under an empty named after the piece. Returns the empty."""
    M = env_materials(); col = col or bpy.context.scene.collection
    fit(p)
    root = bpy.data.objects.new(p.name, None); col.objects.link(root)
    for (node, mat, smooth), b in p.bags.items():
        if not b.v: continue
        o, _ = C.make_obj('%s~%s~%s' % (p.name, node, mat), b, M, col, outline=HULL.get(mat, 0))
        o.parent = root; o['env_node'] = node; o['env_mat'] = mat
        if HULL.get(mat): C.ink_pass(scale=1.0, min_w=.5, objs=[o])
    return root

# ------------------------------------------------------------------ primitives
def Fz(u, v, w): return V((u, v, w))                   # up-facing plane
def Ff(u, v, w): return V((u, -w, v))                  # wall front, faces -Y
def Fb(u, v, w): return V((-u, w, v))                  # wall back
def Fxp(u, v, w): return V((w, -u, v))                 # faces +X, u runs toward -Y... mirrored below as needed
def Fxn(u, v, w): return V((-w, u, v))                 # faces -X
def normal(F): return (F(0, 0, 1) - F(0, 0, 0)).normalized()

def box(b, lo, hi, t=.5):
    x0, y0, z0 = lo; x1, y1, z1 = hi
    b.add([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
          [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], [t] * 8)

def stroke(b, pts, w, n, r=None, t=.5, nib=None):
    """One brush line: a strip that swells in the middle and tapers to points."""
    m = len(pts)
    if m < 2: return
    n = V(n); vs = []; fs = []
    for i, p in enumerate(pts):
        p = V(p); tg = (V(pts[min(i + 1, m - 1)]) - V(pts[max(i - 1, 0)]))
        s = tg.cross(n)
        s = s.normalized() if s.length > 1e-6 else V((1, 0, 0))
        k = math.sin(math.pi * i / (m - 1)) ** .6 if nib is None else nib(i / (m - 1))
        k *= (r.uniform(.7, 1.25) if r else 1)
        vs += [p + s * w * k * .5, p - s * w * k * .5]
        if i: fs.append((2 * i - 2, 2 * i - 1, 2 * i + 1, 2 * i))
    b.add(vs, fs, [t] * len(vs))

def crack(b, F, r, u, v, w, ang, length, width, forks=2, bound=None):
    """Jagged tapered line with forks, in face coords."""
    steps = max(3, int(length / .16)); pts = []; a = ang
    for i in range(steps + 1):
        if bound and not bound(u, v): break
        pts.append((u, v))
        a += r.uniform(-.75, .75); a += (ang - a) * .45
        d = length / steps * r.uniform(.7, 1.3)
        u += math.cos(a) * d; v += math.sin(a) * d
        if forks and i and i < steps - 1 and r.random() < .3:
            crack(b, F, r, u, v, w, a + r.choice((-1, 1)) * r.uniform(.5, 1.1), length * r.uniform(.25, .45), width * .65, forks - 1, bound)
    stroke(b, [F(x, y, w) for x, y in pts], width, normal(F), r)

def hatch(b, F, r, u, v, w, ang=.85, n=6, length=.34, gap=.075, width=.016, fan=.06):
    """Parallel hand strokes, each a thin diamond."""
    du, dv = math.cos(ang + math.pi / 2), math.sin(ang + math.pi / 2)
    nrm = normal(F)
    for i in range(n):
        a = ang + r.uniform(-fan, fan)
        l = length * r.uniform(.6, 1.1) * (1 - abs(i - n / 2) / n * .7)
        x, y = u + du * gap * (i - n / 2) + r.uniform(-.008, .008), v + dv * gap * (i - n / 2) + r.uniform(-.008, .008)
        ca, sa = math.cos(a) * l, math.sin(a) * l
        stroke(b, [F(x, y, w), F(x + ca * .5, y + sa * .5, w), F(x + ca, y + sa, w)], width, nrm, None, nib=lambda q: 1 - q * .9)

def prism(b, F, poly, w0, w1, ch=.04, r=None, t=.5, jit=0):
    """Extruded polygon in face coords: chamfered front, open back."""
    cx = sum(p[0] for p in poly) / len(poly); cy = sum(p[1] for p in poly) / len(poly)
    n = len(poly); vs = []
    for x, y in poly: vs.append(F(x, y, w0))
    for x, y in poly:
        d = math.hypot(x - cx, y - cy) or 1
        k = max(0, 1 - ch / d)
        j = (r.uniform(-jit, jit) if r and jit else 0)
        vs.append(F(cx + (x - cx) * k, cy + (y - cy) * k, w1 + j))
    fs = [tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b.add(vs, fs, [t] * len(vs))

def block(b, F, u0, u1, v0, v1, w0, w1, r, ch=.035, t=.5, open0=False, open1=False, tilt=.012, wob=.012):
    """Chamfered stone: corners wobble so no line is ruler-straight. open0/1 leave an end uncut where a tile boundary splits it."""
    def j(): return r.uniform(-wob, wob)
    a0 = 0 if open0 else ch; a1 = 0 if open1 else ch
    jl = 0 if open0 else 1; jr = 0 if open1 else 1
    back = [(u0 + jl * j(), v0 + j()), (u1 + jr * j(), v0 + j()), (u1 + jr * j(), v1 + j()), (u0 + jl * j(), v1 + j())]
    front = [(back[0][0] + a0, back[0][1] + ch), (back[1][0] - a1, back[1][1] + ch), (back[2][0] - a1, back[2][1] - ch), (back[3][0] + a0, back[3][1] - ch)]
    vs = [F(x, y, w0) for x, y in back] + [F(x, y, w1 + r.uniform(-tilt, tilt)) for x, y in front]
    fs = [(4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6)]
    if not open1: fs.append((1, 2, 6, 5))
    if not open0: fs.append((3, 0, 4, 7))
    b.add(vs, fs, [t] * 8)

def lathe(b, prof, sides=8, c=(0, 0), phase=None, t=.5, sq=(1, 1), top=True, bottom=False, rj=0, r=None):
    """Rings of (radius, z[, tone]). rj jitters the ring radii so stone looks hand cut."""
    phase = math.pi / sides if phase is None else phase
    vs, ts, fs = [], [], []
    jit = [1 + (r.uniform(-rj, rj) if r else 0) for _ in range(sides)]
    for ring in prof:
        rad, z = ring[0], ring[1]; tone = ring[2] if len(ring) > 2 else t
        for k in range(sides):
            a = phase + 2 * math.pi * k / sides
            vs.append((c[0] + math.cos(a) * rad * sq[0] * jit[k], c[1] + math.sin(a) * rad * sq[1] * jit[k], z)); ts.append(tone)
    for i in range(len(prof) - 1):
        for k in range(sides):
            fs.append((i * sides + k, i * sides + (k + 1) % sides, (i + 1) * sides + (k + 1) % sides, (i + 1) * sides + k))
    if top: fs.append(tuple((len(prof) - 1) * sides + k for k in range(sides)))
    if bottom: fs.append(tuple(reversed(range(sides))))
    b.add(vs, fs, ts)

def flame(b, x, y, z, h, rad, r):
    C.tube(b, [V((x, y, z)), V((x + r.uniform(-.2, .2) * rad, y, z + h * .35)), V((x + r.uniform(-.5, .5) * rad, y, z + h * .7)), V((x + r.uniform(-.3, .3) * rad, y, z + h))],
           [rad * .7, rad, rad * .5, rad * .03], sides=6, sub=2)

# ------------------------------------------------------------------ floor: periodic flagstones, no visible 4 m grid
T = 4.0; KW = 2 * math.pi / T
def _warp(x, y):
    s = math.sin
    return (x + .065 * s(KW * 2 * y + 1.1) + .035 * s(KW * (3 * x + 2 * y) + .4) + .018 * s(KW * (5 * x - 3 * y) + 2),
            y + .065 * s(KW * 2 * x + 2.3) + .035 * s(KW * (2 * x - 3 * y) + 1.7) + .018 * s(KW * (3 * x + 5 * y) + .3))
def _gap(x, y):
    return .009 + .017 * (.5 + .5 * math.sin(KW * (3 * x + 4 * y) + .9)) * (.6 + .4 * math.sin(KW * (5 * x - 2 * y)))

def _clip_half(poly, inside, cross):
    out = []
    for i, a in enumerate(poly):
        b = poly[(i + 1) % len(poly)]
        ia, ib = inside(a), inside(b)
        if ia: out.append(a)
        if ia != ib: out.append(cross(a, b))
    return out

def flagstones():
    """Voronoi of jittered seeds with the tile as its period. Same seeds for every floor piece, so all floor tiles join."""
    r = random.Random(2024); N = 3
    seeds = [((i + .5 + r.uniform(-.3, .3)) * T / N - 2, (j + .5 + r.uniform(-.3, .3)) * T / N - 2) for i in range(N) for j in range(N)]
    tones = [r.uniform(.36, .64) for _ in seeds]
    allp = [(x + a * T, y + c * T) for x, y in seeds for a in (-1, 0, 1) for c in (-1, 0, 1)]
    cells = []
    for si, (sx, sy) in enumerate(seeds):
        poly = [(sx - 9, sy - 9), (sx + 9, sy - 9), (sx + 9, sy + 9), (sx - 9, sy + 9)]
        for qx, qy in allp:
            if (qx, qy) == (sx, sy): continue
            mx, my = (sx + qx) / 2, (sy + qy) / 2; nx, ny = qx - sx, qy - sy
            def side(p): return (p[0] - mx) * nx + (p[1] - my) * ny
            def cross(a, b):
                sa, sb = side(a), side(b); k = sa / (sa - sb)
                return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
            poly = _clip_half(poly, lambda p: side(p) <= 0, cross)
        # subdivide, warp, inset by a brush-varying gap
        fine = []
        for i, a in enumerate(poly):
            b = poly[(i + 1) % len(poly)]
            n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / .4))
            fine += [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n)]
        fine = [_warp(*p) for p in fine]
        cx = sum(p[0] for p in fine) / len(fine); cy = sum(p[1] for p in fine) / len(fine)
        ins = []
        for x, y in fine:
            d = math.hypot(x - cx, y - cy) or 1; g = _gap(x, y)
            ins.append((x + (cx - x) * g / d, y + (cy - y) * g / d))
        cells.append((ins, (cx, cy), tones[si]))
    return cells

def clip_tile(poly, h=2.0):
    for axis, sign in ((0, 1), (0, -1), (1, 1), (1, -1)):
        if len(poly) < 3: return []
        def cross(a, b):
            k = (sign * h - a[axis]) / (b[axis] - a[axis])
            return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
        poly = _clip_half(poly, lambda p: sign * p[axis] <= h, cross)
    return poly

def poly_area(p): return abs(sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p)))) / 2

def floor_base(p, ink=1.0, skip=None):
    """Grout slab, stones, a soft top-left lip on each stone, cracks and hatch in the low-contrast wash colour."""
    r = p.r; ZS = .05
    box(p.b('grout'), (-2, -2, -.1), (2, 2, .018), .5)
    fb, hb, wb = p.b('floor'), p.b('floor_hi'), p.b('wash')
    inside = lambda u, v: abs(u) < 1.95 and abs(v) < 1.95
    for ins, (cx, cy), tone in flagstones():
        for ax in (-T, 0, T):
            for ay in (-T, 0, T):
                moved = [(x + ax, y + ay) for x, y in ins]
                clipped = clip_tile(moved)
                if len(clipped) < 3 or poly_area(clipped) < .004: continue
                i0 = len(fb.v)
                fb.add([(x, y, ZS) for x, y in clipped], [tuple(range(len(clipped)))], [tone] * len(clipped))
                # lip: an offset band on the edge that faces up-left, reads as a worn top edge
                m = len(moved); ux, uy = cx + ax, cy + ay
                ok = [(q[0] - ux) * -.6 + (q[1] - uy) * .8 > .3 and inside(*q) for q in moved]
                # the longest unbroken run of edge points: never a chord across the stone
                seg, run = [], []
                for q, f in zip(moved + moved, ok + ok):
                    run = run + [q] if f else []
                    if len(seg) < len(run) <= len(moved): seg = run
                if len(seg) >= 3:
                    seg = [(ux + (x - ux) * .955, uy + (y - uy) * .955) for x, y in seg]
                    stroke(hb, [(x, y, ZS + .002) for x, y in seg], .026, (0, 0, 1), r, tone)
        cx0, cy0 = cx, cy
        if abs(cx0) > 1.9 or abs(cy0) > 1.9: continue
        if r.random() < .78 * ink:
            q = r.choice(ins); ang = math.atan2(cy0 - q[1], cx0 - q[0]) + r.uniform(-.35, .35)
            crack(wb, Fz, r, q[0], q[1], ZS + .004, ang, r.uniform(.7, 1.35), .022, 2, inside)
        if r.random() < .5 * ink:
            q = r.choice(ins); hx, hy = q[0] + (cx0 - q[0]) * .2, q[1] + (cy0 - q[1]) * .2
            if inside(hx, hy) and abs(hx) < 1.6 and abs(hy) < 1.6:
                hatch(wb, Fz, r, hx, hy, ZS + .004, ang=.8, n=r.randint(4, 7), length=r.uniform(.22, .38), gap=.07, width=.016)

def floor_tile_large():
    p = Piece('floor_tile_large'); floor_base(p); return p

def floor_tile_large_rocks():
    p = Piece('floor_tile_large_rocks'); floor_base(p, ink=.5)
    for i in range(5):
        a = i * 1.26 + .4; d = .25 + .4 * (i % 3)
        C.rock(p.b('cap'), (math.cos(a) * d, math.sin(a) * d, .1), (.42 - i * .04, .36 - i * .03, .3 - i * .02), sub=1, jit=.2)
    C.rock(p.b('cap'), (-.1, 0, .22), (.48, .4, .32), sub=2, jit=.16)
    hatch(p.b('wash'), Fz, p.r, .8, -.7, .056, n=7, length=.4, gap=.08, width=.018)
    # keep the top exact: fit() scales to 0.54
    return p

def _octagon(rad, cx=0, cy=0):
    return [(cx + math.cos(math.pi / 8 + i * math.pi / 4) * rad, cy + math.sin(math.pi / 8 + i * math.pi / 4) * rad) for i in range(8)]

def floor_tile_big_grate():
    p = Piece('floor_tile_big_grate'); floor_base(p, ink=.5); r = p.r
    v = p.b('void'); o = _octagon(1.62)
    v.add([(x, y, .054) for x, y in o], [tuple(range(8))])
    box(v, (-1.2, -1.2, -1), (1.2, 1.2, -.15))
    # stone kerb: eight chamfered lintels, not an iron hoop, so it stays quiet
    outer = _octagon(1.86); inner = _octagon(1.6)
    for i in range(8):
        a, b_, c, d = outer[i], outer[(i + 1) % 8], inner[(i + 1) % 8], inner[i]
        p.b('floor_hi').add([(*a, .03), (*b_, .03), (*c, .03), (*d, .03), (*a, .1), (*b_, .1), (*c, .1), (*d, .1)],
                       [(4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)], [r.uniform(.35, .55)] * 8)
    # bars: heavy diagonal lattice, kept dark
    iron = p.b('floor'); h = 1.62; ca = math.cos(math.pi / 4); n = 5
    def chord(c):  # half length of a line at offset c inside the octagon
        return max(0, math.sqrt(max(0, h * h - c * c)) * .94)
    for sgn in (1, -1):
        for i in range(n):
            c = (i - (n - 1) / 2) * .56
            l = chord(c)
            dx, dy = ca * sgn, ca; nx, ny = -dy, dx
            w = .045
            pts = [(c * nx - l * dx - w * nx, c * ny - l * dy - w * ny), (c * nx + l * dx - w * nx, c * ny + l * dy - w * ny),
                   (c * nx + l * dx + w * nx, c * ny + l * dy + w * ny), (c * nx - l * dx + w * nx, c * ny - l * dy + w * ny)]
            z0, z1 = (.02, .07) if sgn > 0 else (.07, .105)
            iron.add([(*q, z0) for q in pts] + [(*q, z1) for q in pts], [(4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], [.42] * 8)
    return p

def floor_tile_big_spikes():
    p = Piece('floor_tile_big_spikes'); floor_base(p, ink=.5); r = p.r
    for x in (-1.2, 0, 1.2):
        for y in (-1.2, 0, 1.2):
            v = p.b('void'); hw = .17
            v.add([(x - hw, y - .06, .054), (x + hw, y - .06, .054), (x + hw * .8, y + .06, .054), (x - hw * .8, y + .06, .054)], [(0, 1, 2, 3)])
            # blade: a diamond section, bone tip
            sp = p.b('iron', node='spikes'); tip = p.b('bone', node='spikes')
            h = r.uniform(1.75, 2.0); j = (r.uniform(-.03, .03), r.uniform(-.03, .03))
            ring = lambda rad, z, dx=0: [(x + rad + dx, y, z), (x + dx, y + rad * .55, z), (x - rad + dx, y, z), (x + dx, y - rad * .55, z)]
            sp.add(ring(.15, -.1) + ring(.13, h * .62, j[0]), [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], [.45] * 8)
            base = ring(.13, h * .62, j[0])
            tip.add(base + [(x + j[0] * 2, y + j[1], h)], [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)], [.5] * 5)
    return p

# ------------------------------------------------------------------ walls
COURSES = [(.0, .62), (.62, 1.52), (1.52, 2.46), (2.46, 3.42)]  # the cap sits on top
def _breaks(i, u0, u1):
    """Vertical joints for course i, repeating every 4 m so wall pieces join without a visible seam."""
    r = random.Random(40 + i)
    n = 3 if i else 2
    base = [(-2 + (k + r.uniform(.1, .9)) * 4 / n + (i % 2) * .55 + 4) % 4 - 2 for k in range(n)]
    base = sorted(base)
    return [b for b in base if u0 < b < u1]

def course_segments(i, u0, u1, periodic):
    cuts = _breaks(i, u0 + .28, u1 - .28)
    edges = [u0] + cuts + [u1]
    return [(edges[k], edges[k + 1]) for k in range(len(edges) - 1)]

def stone_face(p, F, u0, u1, r, skip=None, periodic=True, cracks=.4, w_core=.42):
    """Courses of big blocks over a black core, hand-inked on top."""
    st, ink = p.b('stone'), p.b('ink')
    nrm = normal(F)
    for i, (v0, v1) in enumerate(COURSES):
        segs = course_segments(i, u0, u1, periodic)
        for k, (a, b_) in enumerate(segs):
            if skip and skip((a + b_) / 2, (v0 + v1) / 2): continue
            w1 = .5 if i == 0 else r.uniform(.462, .488)
            tone = r.uniform(.36, .66) if i else r.uniform(.3, .45)
            block(st, F, a, b_, v0 + .012, v1 - .012, w_core, w1, r, ch=.04, t=tone, open0=periodic and k == 0, open1=periodic and k == len(segs) - 1)
            W = w1 + .018
            inb = lambda x, y, a=a, b_=b_, v0=v0, v1=v1: a + .05 < x < b_ - .05 and v0 + .05 < y < v1 - .05
            if r.random() < cracks:
                x = r.uniform(a + .1, max(a + .11, b_ - .1)); up = r.random() < .5
                crack(ink, F, r, x, (v1 - .07) if up else (v0 + .07), W, (-1.57 if up else 1.57) + r.uniform(-.5, .5), r.uniform(.4, .75), .024, 1, inb)
            if r.random() < .68:   # hatch into the lower-right corner, the side away from the key
                hatch(ink, F, r, b_ - .17, v0 + .15, W, ang=2.25, n=r.randint(5, 8), length=r.uniform(.24, .38), gap=.062, width=.018)
            if i and r.random() < .22:  # chipped edge
                x = r.uniform(a + .1, max(a + .11, b_ - .1))
                stroke(ink, [F(x, v1 - .05, W), F(x + r.uniform(.06, .14), v1 - .11, W), F(x + r.uniform(.14, .26), v1 - .05, W)], .05, nrm, r)

def cap_row(p, u0, u1, y0, y1, r, xf=lambda x, y, z: V((x, y, z)), periodic=True, z0=3.42, z1=4.0):
    """Big top stones. Seen from above these carry the skyline of the frame."""
    c = p.b('cap'); ink = p.b('ink')
    n = max(1, round((u1 - u0) / 1.34))
    edges = [u0 + (u1 - u0) * k / n for k in range(n + 1)]
    F = lambda a, b_, w: xf(a, b_, w)
    for k in range(n):
        a, b_ = edges[k], edges[k + 1]
        if 0 < k < n: pass
        block(c, F, a, b_, y0, y1, z0, z1, r, ch=.055, t=r.uniform(.38, .6), open0=periodic and k == 0, open1=periodic and k == n - 1, wob=.0, tilt=.008)
        if r.random() < .75:
            crack(ink, lambda u, v, w: xf(u, v, w), r, r.uniform(a + .2, b_ - .2), y0 + .1, z1 + .012, 1.3 + r.uniform(-.5, .5), .55, .022, 1, lambda x, y, a=a, b_=b_: a + .05 < x < b_ - .05 and y0 + .05 < y < y1 - .05)
        hatch(ink, lambda u, v, w: xf(u, v, w), r, b_ - .2, y0 + .18, z1 + .012, ang=2.3, n=4, length=.22, gap=.07, width=.018)

def wall_core(p):
    box(p.b('void'), (-2, -.42, 0), (2, .42, 3.5))

def wall(skip=None, name='wall'):
    p = Piece(name, seed=21)
    wall_core(p)
    stone_face(p, Ff, -2, 2, p.r, skip)
    cap_row(p, -2, 2, -.5, .5, p.r)
    return p

def wall_arched():
    """The courses run unbroken behind it; the opening and its ring are laid over them, so nothing leaves a gap."""
    cz, ri, ro = 1.72, .95, 1.32
    p = wall(name='wall_arched'); r = p.r
    st = p.b('stone'); v = p.b('void'); ink = p.b('ink')
    pts = [(-ri, .0)] + [(math.cos(math.pi - i * math.pi / 10) * ri, cz + math.sin(math.pi - i * math.pi / 10) * ri) for i in range(11)] + [(ri, .0)]
    v.add([Ff(x, y, .508) for x, y in pts], [tuple(range(len(pts)))])
    n = 7
    for i in range(n):
        a0, a1 = math.pi - i * math.pi / n, math.pi - (i + 1) * math.pi / n
        poly = [(math.cos(a0) * ri, cz + math.sin(a0) * ri), (math.cos(a1) * ri, cz + math.sin(a1) * ri), (math.cos(a1) * ro, cz + math.sin(a1) * ro), (math.cos(a0) * ro, cz + math.sin(a0) * ro)]
        key = i == n // 2
        prism(p.b('bone') if key else st, Ff, poly, .42, .54 if key else .525, ch=.035, t=r.uniform(.45, .68))
    for s in (-1, 1):
        for z0, z1 in ((.0, .62), (.62, 1.18), (1.18, cz)):
            box2 = [(s * ri, z0 + .012), (s * ro, z0 + .012), (s * ro, z1 - .012), (s * ri, z1 - .012)]
            prism(st, Ff, box2, .42, .525, ch=.035, t=r.uniform(.45, .68))
    # the far wall, only hinted: three quiet courses in the dark
    wb = p.b('wash')
    for k_ in range(3):
        y = .45 + k_ * .55
        stroke(wb, [Ff(-.72, y, .512), Ff(0, y + .02, .512), Ff(.72, y - .01, .512)], .03, (0, -1, 0), r)
    return p

def wall_broken():
    """Same idea: a torn black hole laid over the courses, with broken stones biting into it."""
    hx, hz, hw, hh = .15, 2.02, 1.08, .98
    p = wall(name='wall_broken'); r = p.r
    ink = p.b('ink'); st = p.b('stone')
    n = 18; pts = []
    for i in range(n):
        a = i / n * 2 * math.pi; k_ = r.uniform(.78, .98) if i % 2 else r.uniform(1.04, 1.26)
        pts.append((hx + math.cos(a) * hw * k_, hz + math.sin(a) * hh * k_))
    p.b('void').add([Ff(x, min(y, 3.38), .508) for x, y in pts], [tuple(range(n))])
    for i in range(0, n, 3):
        a = i / n * 2 * math.pi
        x, y = hx + math.cos(a) * hw * .92, min(3.2, hz + math.sin(a) * hh * .92)
        s = r.uniform(.12, .2)
        tri = [(x - s, y - s * .6), (x + s, y - s * .4), (x + s * .5, y + s), (x - s * .4, y + s * .8)]
        prism(st, Ff, tri, .42, .525, ch=.02, t=r.uniform(.5, .72))
    for i in range(6):
        a = i * 1.07 + .3
        crack(ink, Ff, r, hx + math.cos(a) * hw * 1.22, hz + math.sin(a) * hh * 1.22, .515, a, r.uniform(.4, .8), .026, 1,
              lambda u, v: abs(u) < 1.93 and .05 < v < 3.4)
    for i in range(5):
        C.rock(p.b('cap'), (-.6 + i * .32 + r.uniform(-.05, .05), -.42, .12 + (i % 2) * .05), (.16, .08, .13), sub=1, jit=.2)
    return p

def wall_corner():
    p = Piece('wall_corner', seed=33); r = p.r
    v = p.b('void')
    box(v, (-2, -.42, 0), (.42, .42, 3.5)); box(v, (-.42, -2, 0), (.42, .42, 3.5))
    # faces of the two arms; arm A runs to -X, arm B to -Y
    FA_front = Ff                                    # u = x, faces -Y
    FA_back = lambda u, v_, w: V((u, w, v_))         # u = x, faces +Y
    FB_px = lambda u, v_, w: V((w, u, v_))           # u = y, faces +X
    FB_nx = lambda u, v_, w: V((-w, u, v_))          # u = y, faces -X
    stone_face(p, FA_front, -2, -.5, r, periodic=False)
    stone_face(p, FA_back, -2, .5, r, periodic=False)
    stone_face(p, FB_px, -2, .5, r, periodic=False)
    stone_face(p, FB_nx, -2, -.5, r, periodic=False)
    # caps: two runs and a heavy chamfered corner block (the KayKit corner is clipped too)
    cap_row(p, -2, -.5, -.5, .5, r, periodic=False)
    cap_row(p, -2, -.5, -.5, .5, r, xf=lambda a, b_, z: V((b_, a, z)), periodic=False)
    poly = [(-.5, -.5), (.5, -.5), (.5, 0), (0, .5), (-.5, .5)]
    prism(p.b('cap'), Fz, poly, 3.42, 4.0, ch=.05, t=.5)
    hatch(p.b('ink'), Fz, r, .05, -.1, 4.01, ang=2.3, n=5, length=.3, gap=.08, width=.02)
    return p

# ------------------------------------------------------------------ pillars
def _pillar_body(p, R0=.75, R=.6, H=4.0, hatch_it=True):
    r = p.r; c, st = p.b('cap'), p.b('stone'); ink = p.b('ink'); wb = ink
    lathe(c, [(R0, 0, .4), (R0, .28, .4), (R0 - .06, .36, .46), (R0 - .16, .4, .5)], t=.45, top=True, r=r, rj=.012)
    n = 4; z0, z1 = .4, H - .72
    for i in range(n):
        a, b_ = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
        rad = R * r.uniform(.96, 1.03); tone = r.uniform(.42, .62)
        lathe(st, [(rad - .05, a + .012, tone), (rad, a + .05, tone), (rad, b_ - .05, tone), (rad - .05, b_ - .012, tone)], r=r, rj=.018, t=tone)
    lathe(c, [(R - .02, z1, .5), (R0 - .04, z1 + .2, .5), (R0, z1 + .28, .5), (R0, H - .08, .5), (R0 - .08, H, .5)], t=.5, r=r, rj=.012)
    # hand-inked: the three camera faces get cracks, the two away from the key get dense hatching
    for f, ang in enumerate((-90, -45, -135, 0)):
        a = math.radians(ang)
        ca, sa = math.cos(a), math.sin(a)
        F = lambda u, v_, w, ca=ca, sa=sa: V((ca * w - sa * u, sa * w + ca * u, v_))
        w = R * math.cos(math.pi / 8) + .018
        if f < 3:
            crack(ink, F, r, r.uniform(-.1, .1), r.uniform(2.6, 3.0), w, -1.57, r.uniform(.6, 1.0), .026, 2, lambda u, v_: abs(u) < .19 and .45 < v_ < 3.2)
        if hatch_it and ang in (0, -45):
            for z in (.75, 1.45, 2.2, 2.9):
                hatch(ink, F, r, 0, z, w, ang=2.35, n=6, length=.32, gap=.058, width=.02)
    # top face: seams and hatch, the top is what the camera really sees
    Ztop = H + .005
    stroke(ink, [(-.55, -.2, Ztop), (-.1, -.05, Ztop), (.15, .3, Ztop), (.55, .35, Ztop)], .03, (0, 0, 1), r)
    crack(ink, Fz, r, .1, -.55, Ztop, 1.4, .6, .024, 1, lambda u, v_: math.hypot(u, v_) < .62)
    hatch(ink, Fz, r, .3, -.25, Ztop, ang=2.3, n=6, length=.34, gap=.07, width=.022)

def pillar():
    p = Piece('pillar'); _pillar_body(p); return p

def pillar_decorated():
    p = Piece('pillar_decorated'); _pillar_body(p); r = p.r
    # red-orange sash round the waist, bone skull, crossed irons: one accent per pillar
    ban = p.b('banner', smooth=False); Zb = 1.9
    lathe(ban, [(.625, Zb - .13, .55), (.645, Zb - .05, .5), (.645, Zb + .05, .5), (.625, Zb + .13, .55)], top=False, t=.5)
    # sash tail hanging at the front
    tail = [(-.13, 1.78), (.13, 1.78), (.17, 1.12), (.0, 1.26), (-.17, 1.06)]
    ban.add([(x, -.68, z) for x, z in tail], [tuple(range(5))], [.5] * 5)
    bo = p.b('bone', smooth=True)
    S = V((0, -.73, 2.12))
    C.blob(bo, S + V((0, 0, .06)), (.2, .17, .19), seg=10, rings=7)
    C.blob(bo, S + V((0, -.06, -.1)), (.115, .09, .09), seg=8, rings=5)
    so = p.b('void')
    for sx in (-1, 1):
        C.blob(so, S + V((sx * .08, -.15, .05)), (.055, .025, .055), seg=8, rings=5)
    C.blob(so, S + V((0, -.155, -.04)), (.022, .012, .03), seg=6, rings=4)
    ir = p.b('iron')
    for s in (-1, 1):
        # crossed blades behind the skull, tips reach the KayKit span
        C.tube(ir, [V((s * .15, -.72, 1.6)), V((-s * .45, -.78, 2.1)), V((-s * 1.12, -.9, 2.85))], [(.07, .018), (.06, .018), (.008, .006)], sides=4, sub=1, side=(1, 1, 0))
        C.blob(p.b('gold'), V((s * .16, -.74, 1.56)), (.08, .05, .06), seg=6, rings=4)
    C.blob(ir, (0, -.96, 2.2), (.02, .01, .02), seg=4, rings=3)
    return p

def column():
    p = Piece('column'); r = p.r; st = p.b('stone'); c = p.b('cap'); ink = p.b('ink')
    lathe(c, [(.35, 0), (.35, .16), (.27, .22)], t=.45, r=r, rj=.02)
    for i, (a, b_) in enumerate(((.22, .78), (.78, 1.22))):
        lathe(st, [(.25, a), (.27, a + .03), (.27, b_ - .03), (.25, b_)], t=r.uniform(.45, .6), r=r, rj=.03)
    # broken top
    lathe(c, [(.27, 1.22), (.31, 1.3), (.3, 1.4)], t=.5, r=r, rj=.05)
    crack(ink, Ff, r, 0, 1.15, .262, -1.57, .6, .022, 1, lambda u, v_: abs(u) < .1 and .25 < v_ < 1.2)
    hatch(ink, Fz, r, .05, 0, 1.408, ang=2.3, n=4, length=.2, gap=.05, width=.016)
    return p

# ------------------------------------------------------------------ banners
def _banner(name, pattern):
    p = Piece(name); r = p.r
    cloth = p.b('banner', smooth=True); bone = p.b('bone', smooth=False)
    nx, nz = 8, 10
    def pos(a, b_):
        """a -1..1 across, b 0 top..1 bottom. Folds deepen downward; the hem is torn into three tongues."""
        x = a * .72 * (1 - .06 * b_) + .03 * math.sin(b_ * 5)
        z = 3.62 - b_ * (2.72 + .34 * (1 - abs(math.sin(a * 4.7 + .4))) )
        y = -.53 + (.1 + .05 * b_) * math.sin(a * 5.3 + b_ * 1.6 + .3) * (.3 + .8 * b_)
        return V((x, y, z))
    vs, fs = [], []
    for j in range(nz + 1):
        for i in range(nx + 1):
            vs.append(pos(i / nx * 2 - 1, j / nz))
    for j in range(nz):
        for i in range(nx):
            q = j * (nx + 1) + i
            fs.append((q, q + 1, q + nx + 2, q + nx + 1))
    cloth.add(vs, fs, [.5] * len(vs))
    # iron pole with bone finials, wall hooks
    ir = p.b('iron')
    C.tube(ir, [V((-.75, -.5, 3.68)), V((0, -.5, 3.7)), V((.75, -.5, 3.68))], [.035, .035, .035], sides=6, sub=1)
    for s in (-1, 1):
        C.blob(p.b('bone'), (s * .72, -.5, 3.68), (.05, .05, .05), seg=6, rings=4)
    def on_cloth(a, b_, lift=.022):
        q = pos(a, b_); return q - V((0, lift, 0))
    # bone trim down the sides
    for s in (-1, 1):
        stroke(bone, [on_cloth(s * .84, b_ / 8) for b_ in range(9)], .07, (0, -1, 0), None, nib=lambda q: 1)
    stroke(bone, [on_cloth(a / 4 - 1, .025) for a in range(9)], .1, (0, -1, 0), None, nib=lambda q: 1)
    ink = p.b('ink')
    if pattern:
        # KayKit's pattern A is blocks; here, stacked bone chevrons, printed cloth
        for k in range(3):
            b0 = .16 + k * .22
            for sgn in (-1, 1):
                pts = [on_cloth(sgn * q / 5 * .72, b0 + (q / 5) * -.1 + .1) for q in range(6)]
                stroke(bone, pts, .17, (0, -1, 0), None, nib=lambda q: 1)
    else:
        # the emblem: a blunt bone skull, big enough to read at game distance
        c0 = pos(0, .3) - V((0, .035, 0))
        sk = [(-.3, .14), (-.17, .3), (.17, .3), (.3, .14), (.26, -.08), (.13, -.16), (.11, -.32), (-.11, -.32), (-.13, -.16), (-.26, -.08)]
        bone.add([c0 + V((x, 0, z)) for x, z in sk], [tuple(range(len(sk)))], [.72] * len(sk))
        for sx in (-1, 1):
            e = [(sx * .05, .06), (sx * .2, .1), (sx * .19, -.04), (sx * .07, -.06)]
            ink.add([c0 + V((x, -.006, z)) for x, z in e], [(0, 1, 2, 3)])
        ink.add([c0 + V((x, -.006, z)) for x, z in ((0, -.09), (.04, -.17), (-.04, -.17))], [(0, 1, 2)])
    # ink fold lines
    for a in (-.62, -.25, .18, .55):
        stroke(ink, [on_cloth(a + .02 * math.sin(b_), b_ / 6 * .85 + .1, .03) for b_ in range(7)], .022, (0, -1, 0), r)
    return p

def banner_red(): return _banner('banner_red', False)
def banner_patternA_red(): return _banner('banner_patternA_red', True)

# ------------------------------------------------------------------ torches and candles
def torch_mounted():
    p = Piece('torch_mounted'); r = p.r
    ir = p.b('iron'); w = p.b('wood', smooth=False); fi = p.b('fire')
    box(ir, (-.16, -.05, -.34), (.16, 0, .06))
    C.tube(ir, [V((0, -.04, -.14)), V((0, -.3, -.18)), V((0, -.42, -.05))], [.035, .03, .028], sides=5, sub=1)
    # shaft leans out from the wall into a wide iron cup
    C.tube(w, [V((0, -.42, -.38)), V((0, -.42, -.05)), V((0, -.43, .14))], [.042, .05, .058], sides=6, sub=1)
    lathe(ir, [(.08, .05), (.14, .14), (.17, .24)], sides=6, c=(0, -.43), t=.4, top=False)
    flame(fi, 0, -.44, .12, .56, .19, r)
    flame(fi, .07, -.44, .14, .33, .1, r)
    flame(fi, -.1, -.44, .16, .28, .09, r)
    return p

def _candle(p, x, y, h, rad):
    r = p.r; bo = p.b('bone', smooth=False); fi = p.b('fire')
    lathe(bo, [(rad * 1.0, 0), (rad * .96, h * .15), (rad * .78, h * .24), (rad * .74, h * .8), (rad * .62, h * .86)], sides=7, c=(x, y), r=r, rj=.05, t=.55)
    box(p.b('ink'), (x - .006, y - .006, h * .85), (x + .006, y + .006, h * .92))
    flame(fi, x, y, h * .84, h * .28, rad * .42, r)

def candle_lit():
    p = Piece('candle_lit'); _candle(p, 0, 0, .86, .17); return p

def candle_triple():
    p = Piece('candle_triple')
    _candle(p, 0, 0, .72, .17); _candle(p, .19, .02, .52, .14); _candle(p, .06, -.13, .38, .1)
    return p

# ------------------------------------------------------------------ containers and furniture
def _barrel(p, R, H):
    r = p.r; w = p.b('wood', smooth=False); ir = p.b('iron'); ink = p.b('ink')
    prof = [(R * .78, 0), (R * .9, H * .14), (R, H * .36), (R, H * .64), (R * .9, H * .86), (R * .78, H)]
    lathe(w, prof, sides=12, t=.5, r=r, rj=.008, top=False, bottom=True)
    lathe(p.b('wood'), [(R * .74, H - .008), (R * .68, H - .03)], sides=12, t=.42)
    for z, rr in ((H * .17, .94), (H * .36, 1.01), (H * .64, 1.01), (H * .83, .94)):
        lathe(ir, [(R * rr, z - H * .035), (R * rr + .012, z), (R * rr, z + H * .035)], sides=12, top=False, t=.45)
    # staves
    for k in range(12):
        a = -math.pi / 2 + (k - 6) * 2 * math.pi / 12 + math.pi / 12
        ca, sa = math.cos(a), math.sin(a)
        pts = [(ca * (rad + .012), sa * (rad + .012), z) for rad, z in prof[1:5]]
        stroke(ink, pts, .018 * max(1, R), (ca, sa, 0), r)
    # lid planks
    for k in (-1, 0, 1):
        stroke(ink, [(k * R * .24, -R * .62, H - .012), (k * R * .24 + .01, 0, H - .012), (k * R * .24, R * .62, H - .012)], .02, (0, 0, 1), r)
    hatch(ink, Fz, r, R * .25, -R * .1, H - .012, ang=2.3, n=4, length=R * .3, gap=.05, width=.016)

def barrel_large():
    p = Piece('barrel_large'); _barrel(p, .9, 2.0); return p
def barrel_small():
    p = Piece('barrel_small'); _barrel(p, .5, 1.02); return p

def _crate(p, lo, hi, yaw=0):
    r = p.r; w = p.b('wood', smooth=False); ir = p.b('iron'); ink = p.b('ink')
    c = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)
    ca, sa = math.cos(yaw), math.sin(yaw)
    def R(v): x, y, z = v; x -= c[0]; y -= c[1]; return V((c[0] + x * ca - y * sa, c[1] + x * sa + y * ca, z))
    b0 = len(w.v); box(w, lo, hi, r.uniform(.42, .58)); w.v[b0:] = [R(v) for v in w.v[b0:]]
    fw, fh = hi[0] - lo[0], hi[2] - lo[2]
    # frame boards on the camera face and the top, strapped with iron corners
    i0 = len(ir.v)
    for z0, z1 in ((lo[2], lo[2] + .14), (hi[2] - .14, hi[2])):
        box(ir, (lo[0] - .012, lo[1] - .012, z0), (hi[0] + .012, lo[1] + .05, z1), .42)
    for x0, x1 in ((lo[0], lo[0] + .14), (hi[0] - .14, hi[0])):
        box(ir, (x0 - .012, lo[1] - .014, lo[2]), (x1 + .012, lo[1] + .05, hi[2]), .42)
    ir.v[i0:] = [R(v) for v in ir.v[i0:]]
    n = 3
    for k in range(1, n):
        x = lo[0] + fw * k / n
        stroke(ink, [R((x, lo[1] - .006, lo[2] + .14)), R((x + .01, lo[1] - .006, (lo[2] + hi[2]) / 2)), R((x, lo[1] - .006, hi[2] - .14))], .022, R((0, -1, 0)) - R((0, 0, 0)), r)
        stroke(ink, [R((x, lo[1] + .05, hi[2] + .006)), R((x + .01, (lo[1] + hi[1]) / 2, hi[2] + .006)), R((x, hi[1] - .05, hi[2] + .006))], .022, (0, 0, 1), r)
    h0 = len(ink.v)
    hatch(ink, lambda u, v_, wv: V((u, lo[1] - wv, v_)), r, hi[0] - .34, lo[2] + .34, .008, ang=2.3, n=6, length=.34, gap=.06, width=.018)
    ink.v[h0:] = [R(v) for v in ink.v[h0:]]

def box_large():
    p = Piece('box_large'); _crate(p, (-.75, -.75, 0), (.75, .75, 1.5)); return p

def crates_stacked():
    p = Piece('crates_stacked')
    _crate(p, (-.98, -.6, 0), (.3, .68, 1.2), .08)
    _crate(p, (.1, -1.06, 0), (.98, -.18, .86), -.28)
    _crate(p, (-.72, -.42, 1.2), (.2, .5, 2.14), .3)
    _crate(p, (-.72, .55, 0), (.1, 1.14, .6), .1)
    return p

def table_medium_tablecloth():
    p = Piece('table_medium_tablecloth'); r = p.r; w = p.b('wood', smooth=False); ink = p.b('ink')
    box(w, (-1, -1, .9), (1, 1, 1), .5)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(w, (sx * .82 - .09, sy * .82 - .09, 0), (sx * .82 + .09, sy * .82 + .09, .9), .42)
    # bone runner with a red-orange hem, hanging both ends
    bo = p.b('bone'); ba = p.b('banner')
    box(bo, (-.38, -1.03, .99), (.38, 1.03, 1.0), .5)
    for sy in (-1, 1):
        box(bo, (-.38, sy * 1.0 - .012, .32), (.38, sy * 1.0 + .012, 1.0), .5)
        box(ba, (-.385, sy * 1.0 - .016, .2), (.385, sy * 1.0 + .016, .34), .5)
    for k in (-.6, .6):
        stroke(ink, [(k, -.95, 1.004), (k + .02, 0, 1.004), (k, .95, 1.004)], .024, (0, 0, 1), r)
    hatch(ink, Fz, r, .66, -.6, 1.004, ang=2.3, n=5, length=.3, gap=.06, width=.018)
    return p

def chest_gold():
    p = Piece('chest_gold'); r = p.r; ink = p.b('ink')
    w = p.b('wood', smooth=False); g = p.b('gold', smooth=False)
    W, D_, Hb = .85, .68, .72
    box(w, (-W + .05, -D_ + .03, 0), (W - .05, D_ - .03, Hb), .5)
    for x in (-W + .15, 0, W - .15):
        box(g, (x - .1, -D_ - .012, -0.0), (x + .1, D_ + .02, Hb + .01), .5)
    box(g, (-W, -D_ - .012, 0), (W, D_ + .02, .14), .5)
    # lid: half barrel as its own node (KayKit keeps it separate), hinged at the back
    LN = 'chest_gold_lid'; lw = p.b('wood', node=LN); lg = p.b('gold', node=LN)
    n = 8; ring = lambda x, rr: [(x, math.cos(math.pi * k / n) * rr, Hb + math.sin(math.pi * k / n) * rr * .8) for k in range(n + 1)]
    a, b_ = ring(-W + .03, D_ - .02), ring(W - .03, D_ - .02)
    lw.add(a + b_, [(k, k + 1, n + 2 + k, n + 1 + k) for k in range(n)] + [tuple(range(n + 1)), tuple(range(n + 1, 2 * n + 2))], [.5] * (2 * n + 2))
    for x, w_ in ((-W + .15, .1), (0, .1), (W - .15, .1)):
        a, b_ = ring(x - w_, D_ + .02), ring(x + w_, D_ + .02)
        lg.add(a + b_, [(k, k + 1, n + 2 + k, n + 1 + k) for k in range(n)] + [tuple(range(n + 1)), tuple(range(n + 1, 2 * n + 2))], [.5] * (2 * n + 2))
    # lock: a big bone-gold plate facing the camera
    box(lg, (-.22, -D_ - .07, Hb - .22), (.22, -D_ - .012, Hb + .16), .6)
    C.blob(p.b('void'), (0, -D_ - .078, Hb - .04), (.05, .012, .075), seg=6, rings=4)
    # shadow ink
    hatch(ink, Ff, r, .55, .34, D_ + .004, ang=2.3, n=5, length=.26, gap=.055, width=.018)
    for x in (-.45, .45):
        stroke(ink, [(x, -D_ + .02 - .012, .16), (x + .01, -D_ + .02 - .012, .4), (x, -D_ + .02 - .012, Hb)], .022, (0, -1, 0), r)
    return p

def sword_shield_gold():
    p = Piece('sword_shield_gold'); r = p.r; ir = p.b('iron', smooth=False); g = p.b('gold', smooth=False); ba = p.b('banner', smooth=False)
    for s in (-1, 1):
        C.tube(ir, [V((s * .52, -.04, -.72)), V((-s * .3, -.03, .24)), V((-s * 1.12, -.02, .84))], [(.09, .02), (.075, .02), (.008, .006)], sides=4, sub=1, side=(1, 1, 0))
        C.tube(g, [V((s * .38, -.04, -.62)), V((s * .66, -.04, -.48))], [.04, .04], sides=5, sub=1)
        C.blob(g, (s * .58, -.04, -.82 + .06), (.07, .05, .06), seg=6, rings=4)
    # kite shield in front: red-orange field, gold rim, bone boss
    n = 14; rim = []
    for i in range(n):
        a = i / n * 2 * math.pi
        k = 1 if math.sin(a) > 0 else 1 - .3 * abs(math.sin(a))
        rim.append((math.cos(a) * .52 * (1 - .25 * max(0, -math.sin(a))), .05 + math.sin(a) * .56 * (1 + .15 * max(0, -math.sin(a)))))
    prism(g, Ff, rim, .06, .2, ch=.02, t=.5)
    prism(ba, Ff, [(x * .84, .05 + (y - .05) * .84) for x, y in rim], .19, .22, ch=.015, t=.5)
    C.blob(p.b('bone'), (0, -.25, .05), (.15, .03, .17), seg=8, rings=5)
    hatch(p.b('ink'), Ff, r, .22, -.2, .226, ang=2.3, n=5, length=.26, gap=.06, width=.018)
    return p

# ------------------------------------------------------------------ rubble
def _rubble(p, x0, x1, y0, y1, H, n):
    """A heap: big chiselled boulders at the middle, small ones at the skirt. fit() brings it to the exact bounds."""
    r = p.r; cx, cy = (x0 + x1) / 2, (y0 + y1) / 2; Lx, Ly = (x1 - x0) / 2, (y1 - y0) / 2
    for i in range(n):
        a = r.uniform(0, 6.283); d = r.uniform(.05, 1) ** .7
        x, y = cx + math.cos(a) * d * Lx * .9, cy + math.sin(a) * d * Ly * .9
        peak = (1 - d) ** .8
        s = r.uniform(.5, .95) * (.45 + .55 * peak)
        z = H * .72 * peak * r.uniform(.6, 1) + .15
        C.rock(p.b('cap' if i % 3 else 'stone'), (x, y, z), (s * r.uniform(.8, 1.2), s * r.uniform(.7, 1), s * r.uniform(.5, .85)), sub=1 if i % 4 else 2, jit=.18)
    C.rock(p.b('stone'), (cx, cy, H * .62), (min(Lx * .5, 1.1), min(Ly * .5, .9), H * .36), sub=2, jit=.16)
    # ink ticks on the ground-level skirt: dark triangles at the rock feet, plus hatching on the away side
    for i in range(n // 2):
        a = r.uniform(-1.2, .4); x, y = cx + math.cos(a) * Lx * .92, cy + math.sin(a) * Ly * .92
        hatch(p.b('wash'), Fz, r, x, y, .012, ang=2.3, n=4, length=.3, gap=.07, width=.02)

def rubble_half():
    p = Piece('rubble_half'); _rubble(p, 0, 4, -1.48, 1.52, 3.5, 14); return p
def rubble_large():
    p = Piece('rubble_large'); _rubble(p, -4.07, 4.06, -1.6, 1.59, 3.5, 22); return p

BUILDERS = {
    'floor_tile_large': floor_tile_large, 'floor_tile_large_rocks': floor_tile_large_rocks, 'floor_tile_big_grate': floor_tile_big_grate,
    'floor_tile_big_spikes': floor_tile_big_spikes, 'wall': wall, 'wall_arched': wall_arched, 'wall_broken': wall_broken, 'wall_corner': wall_corner,
    'pillar': pillar, 'pillar_decorated': pillar_decorated, 'column': column, 'banner_red': banner_red, 'banner_patternA_red': banner_patternA_red,
    'torch_mounted': torch_mounted, 'candle_lit': candle_lit, 'candle_triple': candle_triple, 'barrel_large': barrel_large, 'barrel_small': barrel_small,
    'box_large': box_large, 'crates_stacked': crates_stacked, 'chest_gold': chest_gold, 'table_medium_tablecloth': table_medium_tablecloth,
    'sword_shield_gold': sword_shield_gold, 'rubble_half': rubble_half, 'rubble_large': rubble_large,
}

def build(name, col=None):
    return finish(BUILDERS[name](), col)

def piece_tris(root):
    return sum(sum(len(q.vertices) - 2 for q in o.data.polygons) for o in root.children)

# ------------------------------------------------------------------ export
_EXP = {}
NODE_ORIGIN = {'chest_gold_lid': (0, .565, .5)}   # measured from the KayKit node
def _export_mat(mat):
    """Flat stand-in named after the toon material: base colour = the light tone, so a Godot shader can key on the name."""
    if mat in _EXP: return _EXP[mat]
    src = {'floor': (.128, .125, .205), 'floor_hi': (.168, .163, .26), 'grout': (.05, .05, .095), 'stone': (.29, .29, .45), 'cap': (.25, .25, .4), 'iron': (.27, .29, .42),
           'wood': (.4, .26, .27), 'bone': (.9, .82, .64), 'banner': (.97, .29, .06), 'gold': (.98, .66, .16), 'void': (.028, .028, .06), 'ink': C.INK, 'wash': (.033, .032, .07), 'fire': (1, .6, .15)}[mat]
    m = bpy.data.materials.new('comic_' + mat); m.use_nodes = True
    pr = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    pr.inputs['Base Color'].default_value = C.srgb(src); pr.inputs['Roughness'].default_value = 1
    if mat in ('fire', 'ink', 'wash'):
        pr.inputs['Emission Color'].default_value = C.srgb(src); pr.inputs['Emission Strength'].default_value = 1
    _EXP[mat] = m
    return m

def export_piece(root, path):
    """One node per KayKit node: merged mesh, no hull, flat named materials, per-stone tone as COLOR_0."""
    groups = {}
    for o in root.children: groups.setdefault(o['env_node'], []).append(o)
    temps = []
    bpy.ops.object.select_all(action='DESELECT')
    for node, objs in groups.items():
        made = []
        for o in objs:
            c = o.copy(); c.data = o.data.copy(); c.parent = None; c.modifiers.clear(); c.matrix_world = o.matrix_world
            bpy.context.scene.collection.objects.link(c)
            c.data.materials.clear(); c.data.materials.append(_export_mat(o['env_mat']))
            for q in c.data.polygons: q.material_index = 0
            made.append(c)
        bpy.ops.object.select_all(action='DESELECT')
        for c in made: c.select_set(True)
        bpy.context.view_layer.objects.active = made[0]
        if len(made) > 1: bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active; j.name = node; j.data.name = node
        org = NODE_ORIGIN.get(node)
        if org:   # same hinge as the KayKit node, so a script that swings it keeps working
            for v in j.data.vertices: v.co -= V(org)
            j.location = org
        temps.append(j)
    bpy.ops.object.select_all(action='DESELECT')
    for j in temps: j.select_set(True)
    kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_animations=False, export_cameras=False, export_lights=False, export_yup=True)
    try: bpy.ops.export_scene.gltf(export_vertex_color='NAME', export_vertex_color_name='g', **kw)
    except TypeError: bpy.ops.export_scene.gltf(**kw)
    for j in temps: bpy.data.objects.remove(j)

def sheet(path):
    scn = bpy.context.scene
    names = sorted(BUILDERS)
    roots = {}
    cols = 7
    for i, n in enumerate(names):
        rt = build(n); roots[n] = rt
        rt.location = ((i % cols) * 10.5, -(i // cols) * 10.5, 0)
    C.comic_scene(floor=False, key=(40, 10, -38))
    w = cols * 10.5
    cam = C.camera('CamSheet', ((cols - 1) * 5.25, -7.2 * 10.5 / 2 * 1.3 - 24, 56), ((cols - 1) * 5.25, -1.5 * 10.5, 0), ortho=w)
    scn.render.resolution_x, scn.render.resolution_y = 1920, 1200
    C.render(path, cam)
    return roots

def bounds(objs):
    lo = [1e9] * 3; hi = [-1e9] * 3
    for o in objs:
        if o.type != 'MESH': continue
        for c in o.bound_box:
            w = o.matrix_world @ V(c)
            for i in range(3): lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    return lo, hi

def check():
    """Import both .glb files, compare bounds and node names."""
    bad = 0
    for n in sorted(BUILDERS):
        res = {}
        for tag, f in (('ours', os.path.join(OUT, n + '.glb')), ('kk', os.path.join(KAYKIT, n + '.glb'))):
            for o in list(bpy.data.objects): bpy.data.objects.remove(o)
            bpy.ops.import_scene.gltf(filepath=f); bpy.context.view_layer.update()
            res[tag] = (bounds(bpy.data.objects), sorted(o.name.split('.')[0] for o in bpy.data.objects if o.type == 'MESH'),
                        {o.name.split('.')[0]: tuple(round(x, 3) for x in o.location) for o in bpy.data.objects if o.type == 'MESH'},
                        sum(sum(len(q.vertices) - 2 for q in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'))
        d = max(abs(a - b) for t in (0, 1) for a, b in zip(res['ours'][0][t], res['kk'][0][t]))
        pivots = all(max(abs(a - b) for a, b in zip(res['ours'][2][m], res['kk'][2][m])) < .01 for m in res['kk'][2] if m in res['ours'][2])
        note = 'OK ' if d < .02 and res['ours'][1] == res['kk'][1] and pivots else 'BAD'
        bad += note == 'BAD'
        print('CHECK', note, n, 'max_dev %.3f' % d, 'tris', res['ours'][3], 'kk', res['kk'][3], res['ours'][1], res['ours'][2] if len(res['ours'][1]) > 1 else '', res['kk'][2] if len(res['kk'][1]) > 1 else '')
    print('CHECK done, bad =', bad)

if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    if 'check' in argv:
        check()
    else:
        scn = bpy.context.scene
        for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
        os.makedirs(OUT, exist_ok=True)
        env_materials()
        wanted = [a for a in argv if a in BUILDERS]
        total = 0
        roots = sheet(os.path.join(OUT, 'kit_sheet.png'))
        for n, rt in roots.items():
            if wanted and n not in wanted: continue
            sv = rt.location.copy(); rt.location = (0, 0, 0); bpy.context.view_layer.update()
            export_piece(rt, os.path.join(OUT, n + '.glb'))
            rt.location = sv; bpy.context.view_layer.update()
            t = piece_tris(rt); total += t
            print('PIECE', n, 'tris', t)
        print('done', len(roots), 'pieces')
