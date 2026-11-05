# Chibi pass 2 on the foe models (round 39): silhouette, colour families and faces, mesh only.
# Runs on the chunky blend (after chunk_pass.py), before foe_keys.py:
#   blender -b <kit>/out/enemies_chunky/<name>.blend -P tools/comic_art/refine_pass.py -- <name>
#   blender -b <kit>/out/enemies_refined/<name>.blend -P tools/comic_art/foe_keys.py -- <name>
# Writes <kit>/out/enemies_refined/<name>.blend; foe_keys.py then writes out/enemies_keyed/ beside it.
#
# Nothing here moves a bone or touches a clip: every bone name, rest pose and IK target stays, so the
# keyed clips (foe_keys.py) play exactly as before. What changes, per foe (SPEC):
#   grow   — the vertices of one part (by their weights on the named bones) scale about a bone's head
#            or a point: the signature prop bigger (warrior's blade, minion's cleaver, the shield, bomb).
#   thick  — the vertices of a part move out from their bone's axis (k across, nothing along): the
#            archer's bow limbs, the Warden's arms. Joints stay where the bones are.
#   drop   — islands of an object that ride a bone deleted (the shield's clutter of skulls and arrows).
#   mat    — an object onto another material: each foe family's accent (FAMILY) and glow.
#   slab   — a prop's face rebuilt as one flat slab (round 39 b): its vertices on the prop bone replaced by
#            their convex outline on the best-fit plane, a dark inked rim round a raised flat face, and
#            the named clutter (the shield's iron bands) dropped. Staggered, curved planks broke into a
#            light / dark checker under the cut tones; one plane takes one tone.
# and on every skull face (FACE): eyes and sockets scaled about the eye's centre (the eye bone's head,
# so the hit squint still closes on it) and tipped back to face up the game camera, a slanted brow over each eye (on the eye bone too: a squint
# folds it into a shut-eye line) and the teeth bent down at the corners into a scowl.
import bpy, bmesh, sys, os, math
from mathutils import Vector as V
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
NAME = ARGS[0] if ARGS else 'minion'
BLEND = bpy.data.filepath
OUT = os.path.join(os.path.dirname(os.path.dirname(BLEND)), 'enemies_refined'); os.makedirs(OUT, exist_ok=True)

# One accent per family, its element in scripts/fx_palette.gd (ComicLook TONES / EMITS name them):
#   legion (earth, orange): minion, shield, warrior, archer, bomber
#   cult (void, violet): rogue, mage
#   grave (wind, green): necromancer, warden
FAMILY = {'minion': 'Earth', 'shield': 'Earth', 'warrior': 'Earth', 'archer': 'Earth', 'bomber': 'Earth',
          'rogue': 'Void', 'mage': 'Void', 'necromancer': 'Wind', 'warden': 'Wind'}
EYE_OBJ = {'archer': 'ember', 'mage': 'arcane'}   # else 'necro' (as foe_keys.add_eyes)

FACE = dict(eye=1.65, socket=1.3, tip=30, brow=True, scowl=.6, teeth_wide=1.15)
SPEC = {
    'minion': dict(ops=[('grow', ['weapon'], 1.45, 'weapon'), ('thick', ['weapon'], 1.25)],
                   mat={'cloth': 'accent', 'necro': 'glow'}, part={'rust': (['head'], 'accent')}),
    'rogue': dict(ops=[('grow', ['weapon.l'], 1.2, 'weapon.l'), ('grow', ['weapon.r'], 1.2, 'weapon.r')],
                  mat={'wrap': 'accent', 'necro': 'glow'}),
    'shield': dict(ops=[('drop', ['bone', 'socket', 'teeth', 'necro', 'cloth', 'rust'], ['shield']),
                        ('grow', ['shield'], 1.4, 'shield'),
                        ('slab', 'wood', 'shield', dict(rim=.09, depth=.07, lift=.01, drop=['iron'], front=['bronze']))],
                   mat={'bronze': 'accent', 'necro': 'glow'}),
    'warrior': dict(ops=[('grow', ['weapon'], 1.35, 'weapon')],
                    mat={'bronze': 'accent', 'necro': 'glow', 'cloth': 'P_Leather'}),
    'mage': dict(ops=[('remove', ['patch']), ('grow', ['hat', 'hat.1', 'hat.2'], 1.22, 'hat')],
                 mat={'arcane': 'glow', 'trim': 'P_Under'}),
    'archer': dict(ops=[('thick', ['bow', 'bow.u', 'bow.l'], 1.8)],
                   mat={'limbs': 'accent', 'ember': 'glow'}),
    'bomber': dict(ops=[('grow', ['bomb'], 1.18, (0.0, 0.3, 1.25))],
                   mat={'necro': 'glow'}, face=dict(scowl=.25)),
    'necromancer': dict(ops=[('grow', ['hood.1', 'hood.2'], 1.3, 'hood.1')], mat={'necro': 'glow', 'flame': 'glow'}, face=dict(eye=1.25, brow=False, scowl=0)),
    'warden': dict(ops=[('thick', ['upperarm.l', 'upperarm.r', 'lowerarm.l', 'lowerarm.r'], 1.15)],
                   mat={'necro': 'glow', 'cloth': 'accent'}, face=dict(eye=1.2, brow=True, scowl=0, teeth_wide=1.0)),
}
spec = SPEC[NAME]
face = dict(FACE); face.update(spec.get('face', {}))

rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm = rig.data
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()


def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig]


def obj(name):
    return bpy.data.objects.get(name)


def tris():
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes())


def wsum(o, v, bones):
    names = {g.index: g.name for g in o.vertex_groups}
    return min(1.0, sum(g.weight for g in v.groups if names[g.group] in bones))


def top_bone(o, v):
    gs = [(g.weight, o.vertex_groups[g.group].name) for g in v.groups if g.weight > 0 and o.vertex_groups[g.group].name != 'inkw']
    return max(gs)[1] if gs else None


def islands(me):
    adj = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        adj[a].append(b); adj[b].append(a)
    seen = [False] * len(me.vertices); out = []
    for s in range(len(me.vertices)):
        if seen[s]:
            continue
        st = [s]; seen[s] = True; isl = []
        while st:
            x = st.pop(); isl.append(x)
            for y in adj[x]:
                if not seen[y]:
                    seen[y] = True; st.append(y)
        out.append(isl)
    return out


def pivot_of(p):
    return V(p) if isinstance(p, tuple) else arm.bones[p].head_local.copy()


report = []

# ------------------------------------------------------------------ shape ops
for op in spec['ops']:
    kind = op[0]
    if kind == 'grow':
        _, bones, k, piv = op
        c = pivot_of(piv); n = 0
        for o in meshes():
            for v in o.data.vertices:
                w = wsum(o, v, bones)
                if w > 0:
                    v.co = c + (v.co - c) * (1 + (k - 1) * w); n += 1
            o.data.update()
        report.append('grow %s x%.2f (%d verts)' % ('+'.join(bones), k, n))
    elif kind == 'thick':
        _, bones, k = op
        n = 0
        segs = {b: (arm.bones[b].head_local.copy(), arm.bones[b].tail_local.copy()) for b in bones}
        for o in meshes():
            names = {g.index: g.name for g in o.vertex_groups}
            for v in o.data.vertices:
                d = V()
                for g in v.groups:
                    b = names[g.group]
                    if b in segs and g.weight > 0:
                        h, t = segs[b]; ax = t - h
                        s = max(0.0, min(1.0, (v.co - h).dot(ax) / ax.length_squared))
                        foot = h + ax * s
                        d += (v.co - foot) * (k - 1) * g.weight
                if d.length > 0:
                    v.co += d; n += 1
            o.data.update()
        report.append('thick %s x%.2f (%d verts)' % ('+'.join(bones), k, n))
    elif kind == 'remove':   # a whole part (small ornaments that speckle under the cut tones)
        for name in op[1]:
            o = obj(name)
            if o is not None:
                report.append('remove %s (%d tris)' % (name, sum(len(p.vertices) - 2 for p in o.data.polygons)))
                bpy.data.objects.remove(o)
    elif kind == 'drop':
        _, objs, bones = op
        n = 0
        for name in objs:
            o = obj(name)
            if o is None:
                continue
            me = o.data
            gone = []
            for isl in islands(me):
                if all(wsum(o, me.vertices[i], bones) > .5 for i in isl):
                    gone += isl
            if gone:
                bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
                bmesh.ops.delete(bm, geom=[bm.verts[i] for i in gone], context='VERTS')
                bm.to_mesh(me); bm.free(); me.update()
                n += len(gone)
        report.append('drop %d verts off %s' % (n, '+'.join(bones)))

    elif kind == 'slab':
        _, oname, bone, o_ = op
        o = obj(oname); me = o.data
        on = [v.index for v in me.vertices if wsum(o, v, [bone]) > .5]
        pts = [me.vertices[i].co.copy() for i in on]
        c = sum(pts, V()) / len(pts)
        import numpy as np
        A = np.array([tuple(p - c) for p in pts])
        _w, vec = np.linalg.eigh(A.T @ A)
        n = V(tuple(vec[:, 0])).normalized()   # least spread: the face's normal
        if n.y > 0:   # out of the face: ahead of the foe (-Y)
            n = -n
        bd = arm.bones[bone]
        up = bd.tail_local - bd.head_local; up = (up - n * up.dot(n)).normalized()
        rt = up.cross(n).normalized()
        uv = [((p - c).dot(rt), (p - c).dot(up)) for p in pts]
        dF = max((p - c).dot(n) for p in pts); dB = max(min((p - c).dot(n) for p in pts), dF - o_['depth'])

        def half(seq):
            h = []
            for x in seq:
                while len(h) >= 2 and ((h[-1][0] - h[-2][0]) * (x[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (x[0] - h[-2][0])) <= 0:
                    h.pop()
                h.append(x)
            return h
        q = sorted(set((round(a, 4), round(b, 4)) for a, b in uv))
        ring = half(q)[:-1] + half(q[::-1])[:-1]
        keep = [ring[0]]
        for x in ring[1:]:   # no slivers: outline points closer than 4 cm to the last kept go
            if math.hypot(x[0] - keep[-1][0], x[1] - keep[-1][1]) > .04:
                keep.append(x)
        ring = keep
        cu = sum(x[0] for x in ring) / len(ring); cv = sum(x[1] for x in ring) / len(ring)
        inner = []
        for a, b in ring:   # the face, inset by the rim width towards the outline's centre
            d = math.hypot(a - cu, b - cv)
            k = max(0.0, (d - o_['rim']) / d)
            inner.append((cu + (a - cu) * k, cv + (b - cv) * k))
        g_avg = None
        if 'g' in me.color_attributes and me.color_attributes['g'].domain == 'POINT':
            ga = me.color_attributes['g']
            g_avg = sum((V(tuple(ga.data[i].color[:3])) for i in on), V()) / len(on)
        ig = o.vertex_groups.get('inkw')
        ink_avg = None
        if ig:
            vals = [g.weight for i in on for g in me.vertices[i].groups if g.group == ig.index]
            ink_avg = sum(vals) / len(vals) if vals else None
        P3 = lambda a, b, d: c + rt * a + up * b + n * d
        m = len(ring)
        verts = ([P3(a, b, dF) for a, b in ring] + [P3(a, b, dB) for a, b in ring] +
                 [P3(a, b, dF + o_['lift']) for a, b in inner] + [P3(a, b, dF - .004) for a, b in inner])
        rim_faces = [tuple(range(m)), tuple(range(2 * m - 1, m - 1, -1))] + [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)]
        face_faces = [tuple(range(2 * m, 3 * m))] + [(2 * m + i, 3 * m + i, 3 * m + (i + 1) % m, 2 * m + (i + 1) % m) for i in range(m)]
        rname = o_.get('rim_mat', 'P_Black')
        rim_m = bpy.data.materials.get(rname) or bpy.data.materials.new(rname)
        names = [x.name if x else None for x in me.materials]
        if rname not in names:
            me.materials.append(rim_m); names.append(rname)
        rim_slot = names.index(rname)
        bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[bm.verts[i] for i in on], context='VERTS')
        dl = bm.verts.layers.deform.verify()
        gl = bm.verts.layers.float_color.get('g')
        new = [bm.verts.new(p) for p in verts]
        gb = o.vertex_groups[bone].index
        for bv in new:
            bv[dl][gb] = 1.0
            if ink_avg is not None:
                bv[dl][ig.index] = ink_avg
            if gl is not None and g_avg is not None:
                bv[gl] = (g_avg.x, g_avg.y, g_avg.z, 1.0)
        made = []
        for f in rim_faces:
            fa = bm.faces.new([new[i] for i in f]); fa.material_index = rim_slot; made.append(fa)
        for f in face_faces:
            fa = bm.faces.new([new[i] for i in f]); fa.material_index = 0; made.append(fa)
        cen = c + rt * cu + up * cv
        for j, fa in enumerate(made):   # caps face out of / into the face, sides away from the centre
            fa.normal_update()
            want = n if j in (0, len(rim_faces)) else (-n if j == 1 else fa.calc_center_median() - cen - n * (fa.calc_center_median() - cen).dot(n))
            if fa.normal.dot(want) < 0:
                fa.normal_flip()
        bm.to_mesh(me); bm.free(); me.update()
        nd = 0
        for dn in o_.get('drop', []):   # clutter on the face (iron bands, studs) dropped
            d_o = obj(dn)
            if d_o is None:
                continue
            gone = [v.index for v in d_o.data.vertices if wsum(d_o, v, [bone]) > .5]
            bm = bmesh.new(); bm.from_mesh(d_o.data); bm.verts.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.verts[i] for i in gone], context='VERTS')
            bm.to_mesh(d_o.data); bm.free(); d_o.data.update(); nd += len(gone)
        for fn in o_.get('front', []):   # the boss: centred on the new face and sat on it, not sunk inside it
            f_o = obj(fn)
            vs = [v for v in f_o.data.vertices if wsum(f_o, v, [bone]) > .5]
            bc = sum((v.co for v in vs), V()) / len(vs)
            mv = rt * (cu - (bc - c).dot(rt)) + up * (cv - (bc - c).dot(up))
            mv += n * (dF + o_['lift'] - .01 - min((v.co - c).dot(n) for v in vs))
            for v in vs:
                v.co += mv
            f_o.data.update()
        report.append('slab %s: %d-gon, %.3f m deep, rim %.3f, %d verts dropped' % (oname, m, dF - dB, o_['rim'], nd))

# ------------------------------------------------------------------ faces
eye_obj = obj(EYE_OBJ.get(NAME, 'necro'))
eyes = []   # (side, centre, radius, [(obj, island)])
if eye_obj is not None:
    me = eye_obj.data
    cand = []
    for isl in islands(me):
        tb = top_bone(eye_obj, me.vertices[isl[0]])
        if tb in ('eye.l', 'eye.r', 'head'):
            c = sum((me.vertices[i].co for i in isl), V()) / len(isl)
            cand.append((tb, c, isl))
    have_bones = 'eye.l' in arm.bones
    if have_bones:
        picked = [(tb[-1], c, isl) for tb, c, isl in cand if tb.startswith('eye.')]
    else:   # as foe_keys.add_eyes: the two front-most head islands, biggest first
        cand.sort(key=lambda e: (e[1].y, -len(e[2])))
        two = sorted(cand[:2], key=lambda e: -e[1].x)
        picked = [('l', two[0][1], two[0][2]), ('r', two[1][1], two[1][2])] if len(two) == 2 else []
    sock = obj('socket')
    sock_isl = islands(sock.data) if sock else []
    for side, c, isl in picked:
        if have_bones:
            c = arm.bones['eye.' + side].head_local.copy()
        r = max(math.hypot(me.vertices[i].co.x - c.x, me.vertices[i].co.z - c.z) for i in isl)
        parts = [(eye_obj, isl)]
        for si in sock_isl:
            sc = sum((sock.data.vertices[i].co for i in si), V()) / len(si)
            if (sc - c).length < .09 and top_bone(sock, sock.data.vertices[si[0]]) in ('head', 'eye.' + side):
                parts.append((sock, si))
                r = max(r, max(math.hypot(sock.data.vertices[i].co.x - c.x, sock.data.vertices[i].co.z - c.z) for i in si))
        eyes.append((side, c, r, parts))
    for side, c, r, parts in eyes:
        for o, isl in parts:
            k = face['eye'] if o == eye_obj else face.get('socket', face['eye'])
            a = -math.radians(face.get('tip', 0))   # the eye tipped back to face up the game camera
            ca_, sa_ = math.cos(a), math.sin(a)
            for i in isl:
                v = o.data.vertices[i]
                d = (v.co - c) * k
                v.co = c + V((d.x, d.y * ca_ - d.z * sa_, d.y * sa_ + d.z * ca_))
            o.data.update()
    report.append('eyes x%.2f, sockets x%.2f (%s)' % (face['eye'], face.get('socket', face['eye']), ', '.join('%s r=%.3f' % (s, r) for s, c, r, p in eyes)))

# a slanted brow over each eye, shaped onto the face by rays from the front
if face['brow'] and len(eyes) == 2:
    skip = {'brow', eye_obj.name, 'socket'}
    surf = [o for o in meshes() if o.name not in skip]
    bvhs = []
    for o in surf:
        bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.triangulate(bm, faces=bm.faces)
        bvhs.append(BVHTree.FromBMesh(bm)); bm.free()

    def surface_y(x, z, y0):
        best = None
        for t in bvhs:
            hit = t.ray_cast(V((x, y0 - .6, z)), V((0, 1, 0)), 1.2)
            if hit[0] is not None and (best is None or hit[0].y < best):
                best = hit[0].y
        return best if best is not None else y0

    tilt = math.tan(math.radians(24))
    SEG = 6
    vs, fs, ws = [], [], []
    for side, c, r, parts in eyes:
        rr = r * face.get('socket', face['eye'])
        hl, ht = rr * 1.05, rr * .26       # half length (x), half height (z)
        sign = 1 if c.x > 0 else -1          # +x is the foe's left; the inner end sits lower
        base = len(vs)
        for j in range(SEG + 1):
            u = -1 + 2 * j / SEG
            x = c.x + u * hl
            zc = c.z + rr * 1.0 + tilt * (x - c.x) * sign - .25 * rr * u * u   # an arch, dropped at the ends
            y = surface_y(x, zc, c.y)
            for dz in (-ht, ht):
                for dy in (.02, -.045):          # back (into the face), front (out of it)
                    vs.append((x, y + dy, zc + dz + (abs(dz) * .25 * u * sign if dz > 0 else 0)))
                    ws.append('eye.' + side)
        # quads: index (j, top/bottom, back/front) -> base + j*4 + tb*2 + bf
        def ix(j, tb, bf):
            return base + j * 4 + tb * 2 + bf
        for j in range(SEG):
            fs.append((ix(j, 0, 1), ix(j + 1, 0, 1), ix(j + 1, 1, 1), ix(j, 1, 1)))   # front
            fs.append((ix(j, 1, 0), ix(j + 1, 1, 0), ix(j + 1, 0, 0), ix(j, 0, 0)))   # back
            fs.append((ix(j, 1, 1), ix(j + 1, 1, 1), ix(j + 1, 1, 0), ix(j, 1, 0)))   # top
            fs.append((ix(j, 0, 0), ix(j + 1, 0, 0), ix(j + 1, 0, 1), ix(j, 0, 1)))   # bottom
        fs.append((ix(0, 0, 0), ix(0, 0, 1), ix(0, 1, 1), ix(0, 1, 0)))
        fs.append((ix(SEG, 0, 1), ix(SEG, 0, 0), ix(SEG, 1, 0), ix(SEG, 1, 1)))
    old = obj('brow')
    if old:
        bpy.data.objects.remove(old)
    bme = bpy.data.meshes.new('brow')
    bme.from_pydata(vs, [], fs); bme.update()
    bm = bmesh.new(); bm.from_mesh(bme); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(bme); bm.free()
    mat = bpy.data.materials.get('P_Black') or bpy.data.materials.new('P_Black')
    bme.materials.append(mat)
    ca = bme.color_attributes.new('g', 'FLOAT_COLOR', 'POINT')
    for i in range(len(vs)):
        ca.data[i].color = (1, 1, 1, 1)
    bo = bpy.data.objects.new('brow', bme)
    rig.users_collection[0].objects.link(bo)
    bo.parent = rig
    for side in 'lr':
        g = bo.vertex_groups.new(name='eye.' + side)
        g.add([i for i, w in enumerate(ws) if w == 'eye.' + side], 1.0, 'REPLACE')
    mo = bo.modifiers.new('Armature', 'ARMATURE'); mo.object = rig
    report.append('brows %d tris' % sum(len(p.vertices) - 2 for p in bme.polygons))

# teeth: wider and bent down at the corners (a scowl)
teeth = obj('teeth')
if teeth and (face['scowl'] or face['teeth_wide'] != 1.0):
    me = teeth.data
    head_teeth = [v for v in me.vertices if top_bone(teeth, v) in ('head', 'jaw')]
    if head_teeth:
        xc = sum(v.co.x for v in head_teeth) / len(head_teeth)
        hw = max(abs(v.co.x - xc) for v in head_teeth) or 1.0
        h = max(v.co.z for v in head_teeth) - min(v.co.z for v in head_teeth)
        for v in head_teeth:
            u = (v.co.x - xc) / hw
            v.co.x = xc + (v.co.x - xc) * face['teeth_wide']
            v.co.z -= face['scowl'] * h * u * u
        me.update()
        report.append('teeth x%.2f, scowl %.2f of %.3f m' % (face['teeth_wide'], face['scowl'], h))

# ------------------------------------------------------------------ colour families
fam = FAMILY[NAME]
for oname, role in spec['mat'].items():
    o = obj(oname)
    if o is None:
        print('[refine] %s no object %s' % (NAME, oname)); continue
    mname = role if role.startswith('P_') else ('P_Foe' if role == 'accent' else 'P_Glow') + fam
    m = bpy.data.materials.get(mname)
    if m is None:
        src = o.data.materials[0]
        m = src.copy() if src else bpy.data.materials.new(mname)
        m.name = mname
    o.data.materials[0] = m
    report.append('%s -> %s' % (oname, mname))

# part of an object (its faces on the named bones) onto the accent: the minion's cap, not its blade
for oname, (bones, role) in spec.get('part', {}).items():
    o = obj(oname)
    mname = role if role.startswith('P_') else ('P_Foe' if role == 'accent' else 'P_Glow') + fam
    m = bpy.data.materials.get(mname) or o.data.materials[0].copy()
    m.name = mname
    o.data.materials.append(m)
    slot = len(o.data.materials) - 1
    n = 0
    for p in o.data.polygons:
        if all(wsum(o, o.data.vertices[i], bones) > .5 for i in p.vertices):
            p.material_index = slot; n += 1
    report.append('%s on %s -> %s (%d faces)' % (oname, '+'.join(bones), mname, n))

rig.data.pose_position = 'POSE'
print('[refine] %s %s' % (NAME, '; '.join(report)))
print('[refine] %s tris %d' % (NAME, tris()))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('[refine] done', NAME)
