# Chunky silhouettes on a chibi foe (round 29, after chibi_pass.py): the skeleton's many thin bone
# parts (ribs, vertebrae, finger and toe bones) become a few thick masses, one per limb group, so the
# outline sits on the silhouette like the hero's instead of on every rib.
#   blender -b out/enemies_chibi/minion.blend -P chunk_pass.py -- minion
# Writes out/enemies_chunky/<name>.glb, .blend, _game.png, _hero.png, _motion.png. Same bones, names
# and clips. Bring it into the game with  python tools/comic_glb.py <kit>/out/enemies_chunky <name>
#
# How: in each BODY object (the bone mesh) every island is rigid to one bone (Rig.skin_islands). The
# islands are sorted into limb groups by that bone (head, jaw, torso, each arm, each leg; anything under
# a weapon / shield / bow bone is a held prop and stays as it was). Each group is fattened along its
# normals (FAT, so thin ribs touch and union), voxel-remeshed into one surface, smoothed and decimated
# to its share of the triangle budget. Weights come back from the original group by nearest-face
# interpolation, then a few smoothing passes inside the group, so elbows and knees bend instead of
# shearing. Every other part (eyes, sockets, teeth, belts, helmets) near the body is pushed out along
# the body's normal by the same FAT with a falloff, so nothing is buried by the fatter mass.
import bpy, bmesh, sys, os, math
from mathutils import Vector as V
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

DIR = os.path.dirname(os.path.abspath(__file__))
NAME = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'minion'
OUT = os.path.join(DIR, 'out', 'enemies_chunky'); os.makedirs(OUT, exist_ok=True)

BODY = {'bone'}                      # material bags merged into masses
VOXEL = .011                         # remesh cell (m)
SMOOTH = (.5, 6)                     # factor, iterations after the remesh
FAT = {'head': .004, 'jaw': .008, 'torso': .02, 'arm': .03, 'hand': .008, 'leg': .036}
TRIS = {'head': 1200, 'jaw': 300, 'torso': 2200, 'arm': 450, 'hand': 500, 'leg': 650}  # per group
WEIGHT_SMOOTH = 4                    # neighbour-average passes on the transferred weights
PUSH_R = .07                         # other parts within this of the body move out with it
PROPS = ('weapon', 'shield', 'bow', 'arrow', 'nock', 'staff', 'bomb', 'fuse', 'chain', 'ring', 'keys')
# Longer strides on the run clips (round 29): the game moves foes at 3-5.4 m/s and the chibi legs
# cover a lot less than that per cycle. Each leg bone's rotation on that clip is scaled about the
# clip's mean pose (q = mean * (mean^-1 q)^k), so the swing widens and the stance bend stays.
# enemy.gd plays the run faster for the rest (run_clip_speed, tests/foe_stride_check.gd).
STRIDE_BONES = ('upperleg.', 'lowerleg.', 'foot.')
KIND = {
    'rogue': {'STRIDE': {'Running_C': 1.3}},
    'warrior': {'STRIDE': {'Running_A': 1.5}},
    'shield': {'STRIDE': {'Walking_D_Skeletons': 2.0}},
    'bomber': {'STRIDE': {'Running_C': 1.25}},
}
cfg = KIND.get(NAME, {})
BODY = cfg.get('BODY', BODY)
STRIDE = cfg.get('STRIDE', {})
for _a in sys.argv[sys.argv.index('--') + 2:] if '--' in sys.argv else []:
    if _a.startswith('stride='):   # stride=Running_C:1.5 (trying a value without editing KIND)
        _c, _k = _a[7:].split(':'); STRIDE[_c] = float(_k)

rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm = rig.data
rig.data.pose_position = 'REST'

def group_of(bone_name):
    b = arm.bones.get(bone_name)
    while b is not None:
        n = b.name
        if n.startswith(PROPS):
            return None
        if n == 'jaw': return 'jaw'
        if n == 'head': return 'head'
        if n.startswith('hand.'): return 'hand' + n[-2:]
        if n.startswith('upperarm.'): return 'arm' + n[-2:]
        if n.startswith('upperleg.'): return 'leg' + n[-2:]
        if n in ('hips', 'spine', 'chest'): return 'torso'
        b = b.parent
    return 'torso'

def kind(g):
    return g.split('.')[0]

def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig]

def islands(me):
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    seen = [False] * len(bm.verts); out = []
    for v in bm.verts:
        if seen[v.index]: continue
        st = [v]; seen[v.index] = True; isl = []
        while st:
            x = st.pop(); isl.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if not seen[y.index]: seen[y.index] = True; st.append(y)
        out.append(isl)
    bm.free()
    return out

def top_bone(o, v):
    gs = [g for g in v.groups if o.vertex_groups[g.group].name != 'inkw' and g.weight > 0]
    if not gs: return None
    return o.vertex_groups[max(gs, key=lambda g: g.weight).group].name

def weights_of(o, v):
    return {o.vertex_groups[g.group].name: g.weight for g in v.groups if o.vertex_groups[g.group].name != 'inkw' and g.weight > 0}

def remesh(verts, faces, fat, target):
    """One union surface: fatten along normals, voxel remesh, smooth, decimate to about target tris."""
    me = bpy.data.meshes.new('chunk_tmp')
    me.from_pydata(verts, [], faces); me.update()
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * fat
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('chunk_tmp', me); bpy.context.scene.collection.objects.link(o)
    r = o.modifiers.new('r', 'REMESH'); r.mode = 'VOXEL'; r.voxel_size = VOXEL; r.use_smooth_shade = True
    sm = o.modifiers.new('s', 'SMOOTH'); sm.factor, sm.iterations = SMOOTH
    dg = bpy.context.evaluated_depsgraph_get()
    m1 = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.clear(); o.data = m1
    n = len(m1.polygons) * 2 if m1.polygons and len(m1.polygons[0].vertices) == 4 else len(m1.polygons)
    if n > target:
        d = o.modifiers.new('d', 'DECIMATE'); d.ratio = target / n
    dg = bpy.context.evaluated_depsgraph_get()
    m2 = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    bm = bmesh.new(); bm.from_mesh(m2)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    vs = [v.co.copy() for v in bm.verts]
    fs = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    bpy.data.objects.remove(o); bpy.data.meshes.remove(me); bpy.data.meshes.remove(m1); bpy.data.meshes.remove(m2)
    return vs, fs

# ------------------------------------------------------------------ body objects
body_bvh = []   # (bvh over the original body faces, per-face group kind) for pushing the other parts
report = []
for o in meshes():
    key = o.data.materials[0].name[2:].lower() if o.data.materials else ''
    if o.name not in BODY and key not in BODY:
        continue
    me = o.data
    vco = [v.co.copy() for v in me.vertices]
    gattr = me.color_attributes.get('g')
    gval = [gattr.data[i].color[0] for i in range(len(me.vertices))] if gattr and gattr.domain == 'POINT' else None
    vw = [weights_of(o, v) for v in me.vertices]
    tris0 = sum(len(p.vertices) - 2 for p in me.polygons)
    # vertex -> group by the island's majority bone
    vgroup = [None] * len(vco)
    for isl in islands(me):
        votes = {}
        for i in isl:
            b = top_bone(o, me.vertices[i])
            g = group_of(b) if b else 'torso'
            votes[g] = votes.get(g, 0) + 1
        g = max(votes, key=votes.get)
        for i in isl: vgroup[i] = g
    faces_by = {}
    for p in me.polygons:
        faces_by.setdefault(vgroup[p.vertices[0]], []).append(p)
    # the whole original body, for pushing accessories out
    allf = [tuple(p.vertices) for p in me.polygons]
    body_bvh.append((BVHTree.FromPolygons(vco, allf), [kind(vgroup[p.vertices[0]]) if vgroup[p.vertices[0]] else None for p in me.polygons]))

    NV, NF, NW, NG, NS = [], [], [], [], []
    def emit(vs, fs, ws, gs, smooth):
        base = len(NV)
        NV.extend(vs); NW.extend(ws); NG.extend(gs)
        for f, s in zip(fs, smooth):
            NF.append(tuple(i + base for i in f)); NS.append(s)
    for g, polys in faces_by.items():
        if g is None:
            # held prop: kept exactly as it was
            idx = sorted({i for p in polys for i in p.vertices}); remap = {j: k for k, j in enumerate(idx)}
            emit([vco[i] for i in idx], [tuple(remap[i] for i in p.vertices) for p in polys], [vw[i] for i in idx],
                 [gval[i] if gval else 1.0 for i in idx], [p.use_smooth for p in polys])
            continue
        idx = sorted({i for p in polys for i in p.vertices}); remap = {j: k for k, j in enumerate(idx)}
        sv = [vco[i] for i in idx]; sf = [tuple(remap[i] for i in p.vertices) for p in polys]
        vs, fs = remesh(sv, sf, FAT[kind(g)], min(TRIS[kind(g)], max(300, 4 * len(polys))))
        # weights back from the original group, nearest face, interpolated
        bvh = BVHTree.FromPolygons(sv, sf)
        ws, gs = [], []
        for c in vs:
            loc, nrm, fi, d = bvh.find_nearest(c)
            f = sf[fi]
            bc = poly_3d_calc([sv[i] for i in f], loc)
            w = {}; gv = 0.0
            for b_, i in zip(bc, f):
                for n, x in vw[idx[i]].items():
                    w[n] = w.get(n, 0.0) + x * b_
                gv += (gval[idx[i]] if gval else 1.0) * b_
            ws.append(w); gs.append(gv)
        # smooth weights over the new surface's edges so joints bend
        nb = [set() for _ in vs]
        for f in fs:
            for a in range(3):
                nb[f[a]].add(f[(a + 1) % 3]); nb[f[a]].add(f[(a + 2) % 3])
        for _ in range(WEIGHT_SMOOTH):
            nw = []
            for i, w in enumerate(ws):
                acc = dict(w)
                for j in nb[i]:
                    for n, x in ws[j].items():
                        acc[n] = acc.get(n, 0.0) + x
                t = sum(acc.values()) or 1.0
                nw.append({n: x / t for n, x in acc.items()})
            ws = nw
        emit(vs, fs, ws, gs, [True] * len(fs))
        report.append('%s %d->%d' % (g, len(polys), len(fs)))

    # write the new mesh into the same object (keeps its modifiers, vertex group names, materials)
    nm = bpy.data.meshes.new(me.name + '_chunky')
    nm.from_pydata([tuple(v) for v in NV], [], NF); nm.update()
    for m in me.materials: nm.materials.append(m)
    for p, s in zip(nm.polygons, NS): p.use_smooth = s
    ca = nm.color_attributes.new('g', 'FLOAT_COLOR', 'POINT')
    for i, t in enumerate(NG): ca.data[i].color = (t, t, t, 1)
    o.data = nm
    for i, w in enumerate(NW):
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        t = sum(x for _, x in top) or 1.0
        for n, x in top:
            if x / t < .01: continue
            vg = o.vertex_groups.get(n) or o.vertex_groups.new(name=n)
            vg.add([i], x / t, 'REPLACE')
    # ink weight as comic_lib.ink_pass
    ink = o.vertex_groups.get('inkw') or o.vertex_groups.new(name='inkw')
    for v in nm.vertices:
        p = v.co
        n = math.sin(p.x * 11 + p.z * 7) * math.sin(p.y * 9 - p.z * 13) * .5 + .5
        under = max(0, -v.normal.z) * .5
        ink.add([v.index], max(.4, min(1, .25 + n * .55 + under)), 'REPLACE')
    nm.validate()
    tris1 = sum(len(p.vertices) - 2 for p in nm.polygons)
    print('[chunk] %s %s tris %d -> %d (%s)' % (NAME, o.name, tris0, tris1, ', '.join(report)))

# ------------------------------------------------------------------ push the other parts out with the fatter body
for o in meshes():
    key = o.data.materials[0].name[2:].lower() if o.data.materials else ''
    if o.name in BODY or key in BODY or not body_bvh:
        continue
    moved = 0
    for v in o.data.vertices:
        b = top_bone(o, v)
        if b and group_of(b) is None:
            continue
        best = None
        for bvh, fk in body_bvh:
            loc, nrm, fi, d = bvh.find_nearest(v.co, PUSH_R)
            if loc is not None and fk[fi] and (best is None or d < best[0]):
                best = (d, nrm, fk[fi])
        if best is None:
            continue
        d, nrm, k = best
        fall = max(0.0, 1 - d / PUSH_R)
        # outside the body: along the face normal; inside it (a socket set into the skull): straight out too
        v.co += nrm.normalized() * FAT[k] * (fall ** .5)
        moved += 1
    o.data.update()
    print('[chunk] %s pushed %s %d verts' % (NAME, o.name, moved))

rig.data.pose_position = 'POSE'

# ------------------------------------------------------------------ wider run strides
def fcurves(a):
    out = []
    for layer in getattr(a, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out += list(bag.fcurves)
    return out
from mathutils import Quaternion as Q
for clip, k in STRIDE.items():
    a = bpy.data.actions.get(clip)
    if a is None:
        print('[chunk] %s no clip %s' % (NAME, clip)); continue
    by = {}
    for fc in fcurves(a):
        if fc.data_path.endswith('rotation_quaternion'):
            b = fc.data_path.split('"')[1]
            if b.startswith(STRIDE_BONES):
                by.setdefault(b, {})[fc.array_index] = fc
    for b, chans in by.items():
        if len(chans) != 4: continue
        n = len(chans[0].keyframe_points)
        qs = [Q([chans[i].keyframe_points[j].co.y for i in range(4)]) for j in range(n)]
        acc = Q((0, 0, 0, 0))
        for q in qs:
            if q.dot(qs[0]) < 0: q = -q
            acc = Q([acc[i] + q[i] for i in range(4)])
        mean = acc.normalized(); mi = mean.inverted()
        for j, q in enumerate(qs):
            d = mi @ q
            ax, ang = d.to_axis_angle()
            if ang > math.pi: ang -= 2 * math.pi
            nq = mean @ Q(ax, ang * k)
            for i in range(4):
                kp = chans[i].keyframe_points[j]
                dy = nq[i] - kp.co.y
                kp.co.y += dy; kp.handle_left.y += dy; kp.handle_right.y += dy
        for fc in chans.values(): fc.update()
    print('[chunk] %s stride %s x%.2f on %d leg bones' % (NAME, clip, k, len(by)))

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes())
height = max((o.matrix_world @ v.co).z for o in meshes() for v in o.data.vertices)
print('[chunk] %s total tris %d, height %.2f' % (NAME, tris, height))

# ------------------------------------------------------------------ export and proof, as chibi_pass.py
ad = rig.animation_data
acts = [a for a in bpy.data.actions if a.use_fake_user]
for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
for a in acts:
    tr = ad.nla_tracks.new(); tr.name = a.name; tr.mute = True
    tr.strips.new(a.name, 0, a)
ad.action = None
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for o in rig.children: o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + '.glb'), export_format='GLB', use_selection=True, export_apply=False,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True, export_cameras=False, export_lights=False)
for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)

def show(action, frac):
    a = bpy.data.actions[action]
    ad.action = a
    if hasattr(ad, 'action_slot') and a.slots:
        ad.action_slot = a.slots[0]
    f0, f1 = a.frame_range
    bpy.context.scene.frame_set(int(round(f0 + (f1 - f0) * frac)))

scn = bpy.context.scene
show('Idle_Combat', 0.0)
for cam_name, png in (('CamGame', '_game.png'), ('CamHero', '_hero.png')):
    cam = bpy.data.objects.get(cam_name)
    if cam is None:
        continue
    scn.camera = cam
    scn.render.filepath = os.path.join(OUT, NAME + png)
    bpy.ops.render.render(write_still=True)
names = [a.name for a in acts]
run = next((n for n in ('Running_A', 'Running_C', 'Walking_D_Skeletons') if n in names), None)
attack = next((n for n in names if n.startswith(('1H_', '2H_Ranged_Shoot', 'Spellcast_Shoot', 'Bomb', 'Attack_Slam'))), None)
strip = [('Idle_Combat', .5), (run, 0), (run, .5), (attack, .45), ('Hit_A', .15), ('Lie_StandUp', .05), ('Lie_StandUp', .7), ('Death_A', 1)]
strip = [(a, f) for a, f in strip if a in names]
cam = bpy.data.objects.get('CamSide') or bpy.data.objects.get('CamHero')
scn.camera = cam
import tempfile, subprocess, shutil
tmp = tempfile.mkdtemp(prefix='chunk_')
for i, (a, f) in enumerate(strip):
    show(a, f)
    scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
    bpy.ops.render.render(write_still=True)
subprocess.run(['C:/ffmpeg/bin/ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                '-vf', 'scale=384:-1,tile=4x2', '-frames:v', '1', os.path.join(OUT, NAME + '_motion.png')], check=True)
shutil.rmtree(tmp, ignore_errors=True)
show('Idle_Combat', 0.0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('[chunk] done', NAME)
