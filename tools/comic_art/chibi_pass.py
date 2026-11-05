# Chibi proportion pass on a finished comic enemy (round 29): bigger head, hands and weapons,
# short stocky legs, a squat torso. Same bones, same names, same weights, same clips.
#   blender -b out/enemies/minion.blend -P chibi_pass.py -- minion
# Writes out/enemies_chibi/<name>.glb, .blend, _game.png, _hero.png. Bring it into the game with
#   python tools/comic_glb.py <kit>/out/enemies_chibi <name>
#
# How: every bone gets an affine map M_b of rest space. A bone in SCALE scales its own part about its
# head: uniformly, or (len, perp) along its own axis and across it, so its direction (and every
# clip's rotations about it) is kept. Its head follows wherever its parent's map puts it. A bone not
# in SCALE moves rigidly with its parent's map (a jaw with the head, a weapon with the hand). A bone
# hanging to the floor (hem, tail, rest tail under GROUND_Z) keeps its width and squashes only in Z,
# so it still ends at the floor. Each vertex moves by its weights' blend of the maps, the edit bones
# move with theirs, then everything above the root drops until the feet are back on z = 0, and the
# root and hips location keys shrink by the hip height ratio (crouches, lunges, rising out of the floor).
import bpy, sys, os, math
from mathutils import Vector as V, Matrix

DIR = os.path.dirname(os.path.abspath(__file__))
NAME = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'minion'
OUT = os.path.join(DIR, 'out', 'enemies_chibi'); os.makedirs(OUT, exist_ok=True)

HEAD = 1.5        # the skull, hood or hat grows this much about the neck
HAND = 1.35       # fists and whatever they hold
FOOT = 1.3
LEG = (.62, 1.28)  # (along, across): short, thick legs
ARM = (.9, 1.18)
TORSO = (.84, 1.1)
HIPS = 1.08
GROUND_Z = .2     # rest tails lower than this hang to the floor
SCALE = {
    'head': HEAD, 'hand.l': HAND, 'hand.r': HAND, 'foot.l': FOOT, 'foot.r': FOOT, 'hips': HIPS,
    'upperleg.l': LEG, 'lowerleg.l': LEG, 'upperleg.r': LEG, 'lowerleg.r': LEG,
    'upperarm.l': ARM, 'lowerarm.l': ARM, 'upperarm.r': ARM, 'lowerarm.r': ARM,
    'spine': TORSO, 'chest': TORSO,
}
# Per kind, on top of SCALE. A bone named here scales about its own head (not with its parent).
KIND = {
    'archer': {'bow': 1 / HAND * 1.05},             # the bow already reaches the floor
    'mage': {'hat': 1 / HEAD * 1.3},                 # a hat 1.5x on a 1.5x head is a tower
    'shield': {'shield': 1 / HAND * 1.12},           # already the biggest prop in the game
    'warden': {'weapon': 1 / HAND * 1.1,             # the cleaver is 2 m already
               'chain.1': .78},                      # the key ring still just reaches the floor from the lower fist
    'rogue': {'upperleg.l': (.75, 1.25), 'upperleg.r': (.75, 1.25), 'lowerleg.l': (.75, 1.25), 'lowerleg.r': (.75, 1.25)},  # crouched low already
    'bomber': {'head': 1.3, 'upperleg.l': (.8, 1.25), 'upperleg.r': (.8, 1.25), 'lowerleg.l': (.8, 1.25), 'lowerleg.r': (.8, 1.25)},
}
NO_GROUND = {'archer': {'bow.l', 'bow.u'}, 'warden': {'chain.2', 'ring', 'keys'}}
FOLLOW_ROOT = 'hips'  # other children of the root (a robe's skirt, the archer's arrow) move with it
LOC_BONES = ('root', 'hips')

rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm = rig.data
spec = dict(SCALE); spec.update(KIND.get(NAME, {}))
no_ground = NO_GROUND.get(NAME, set())

def scale_about(p, s, axis=None):
    """Matrix scaling about point p: uniform s, or s = (along, across) the unit axis."""
    if isinstance(s, tuple):
        a, c = s
        d = axis.normalized()
        L = Matrix.Identity(3) * c
        for i in range(3):
            for j in range(3):
                L[i][j] += (a - c) * d[i] * d[j]
    else:
        L = Matrix.Identity(3) * s
    m = L.to_4x4()
    return Matrix.Translation(p) @ m @ Matrix.Translation(-p)

def squash_z(p, across, sz):
    m = Matrix.Diagonal((across, across, sz, 1.0))
    return Matrix.Translation(p) @ m @ Matrix.Translation(-p)

def ordered(bones):
    out = []
    def visit(b):
        out.append(b)
        for c in b.children: visit(c)
    for b in bones:
        if b.parent is None: visit(b)
    return out

def maps(drop):
    M = {}
    for b in ordered(arm.bones):
        h, t = b.head_local.copy(), b.tail_local.copy()
        par = b.parent
        if par is None:
            M[b.name] = Matrix.Identity(4); continue
        pm = M[FOLLOW_ROOT] if (par.parent is None and b.name != FOLLOW_ROOT and FOLLOW_ROOT in M) else M[par.name]
        if b.name == FOLLOW_ROOT:
            pm = Matrix.Translation((0, 0, -drop)) @ pm
        s = spec.get(b.name)
        ground = t.z < GROUND_Z and not b.name.startswith(('foot', 'lowerleg', 'upperleg')) and b.name not in no_ground and b.name != 'root'
        moved = pm @ h
        follow = Matrix.Translation(moved - h)
        if ground and s is None:
            # keep its spread, end at the floor where it ended before
            nh = moved
            sz = (t.z - nh.z) / (t.z - h.z) if abs(t.z - h.z) > 1e-4 else 1.0
            sz = max(.2, min(1.0, sz))
            across = 1.12
            M[b.name] = follow @ squash_z(h, across, sz)
        elif s is None:
            M[b.name] = pm
        else:
            M[b.name] = follow @ scale_about(h, s, t - h)
    return M

def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig]

def mapped_verts(M):
    out = {}
    names = set(M)
    rw = rig.matrix_world
    for o in meshes():
        groups = {g.index: g.name for g in o.vertex_groups if g.name in names}
        mw = o.matrix_world; mi = mw.inverted()
        res = []
        for v in o.data.vertices:
            p = rw.inverted() @ (mw @ v.co)
            acc = V((0, 0, 0)); tot = 0.0
            for g in v.groups:
                if g.group in groups and g.weight > 0:
                    acc += (M[groups[g.group]] @ p) * g.weight; tot += g.weight
            q = acc / tot if tot > 0 else p
            res.append(mi @ (rw @ q))
        out[o.name] = res
    return out

def foot_min(M, vs=None):
    vs = vs or mapped_verts(M)
    zs = []
    for o in meshes():
        feet = {g.index for g in o.vertex_groups if g.name.startswith(('foot', 'lowerleg'))}
        for v, q in zip(o.data.vertices, vs[o.name]):
            if any(g.group in feet and g.weight > .5 for g in v.groups):
                zs.append((o.matrix_world @ q).z)
    return min(zs) if zs else 0.0

def head_share(tag):
    # the head's part of the body's height: skull, hood or hat over the top of the head (weapons left out)
    heads = []
    body_top = 0.0
    kids = {b.name for b in arm.bones['head'].children_recursive} | {'head'} if 'head' in arm.bones else set()
    for o in meshes():
        hg = {g.index for g in o.vertex_groups if g.name in kids}
        for v in o.data.vertices:
            z = (o.matrix_world @ v.co).z
            if any(g.group in hg and g.weight > .5 for g in v.groups):
                heads.append(z)
    if heads:
        print('[chibi] %s %s head %.2f of %.2f m (%.0f%%)' % (NAME, tag, max(heads) - min(heads), max(heads), 100 * (max(heads) - min(heads)) / max(heads)))
head_share('before')

# old feet, then the drop that puts the new ones back on the floor
before = foot_min({b.name: Matrix.Identity(4) for b in arm.bones})
height0 = max((o.matrix_world @ v.co).z for o in meshes() for v in o.data.vertices)
hip0 = arm.bones[FOLLOW_ROOT].head_local.z
drop = foot_min(maps(0.0)) - before
M = maps(drop)
new = mapped_verts(M)
for o in meshes():
    for v, q in zip(o.data.vertices, new[o.name]):
        v.co = q
    o.data.update()

# bones: each head and tail through its own map (connected children agree with their parents)
bpy.context.view_layer.objects.active = rig
for o in bpy.context.selected_objects: o.select_set(False)
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for e in arm.edit_bones:
    m = M[e.name]
    roll = e.roll
    e.head, e.tail = m @ e.head, m @ e.tail
    e.roll = roll
bpy.ops.object.mode_set(mode='OBJECT')
hip1 = arm.bones[FOLLOW_ROOT].head_local.z
k = hip1 / hip0

# location keys: crouches and lunges in proportion to the shorter legs
def fcurves(a):
    if hasattr(a, 'fcurves') and len(a.fcurves):
        return list(a.fcurves)
    out = []
    for layer in getattr(a, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out += list(bag.fcurves)
    return out
roots = {b.name for b in arm.bones if b.parent is None or b.parent.parent is None}
for a in bpy.data.actions:
    for fc in fcurves(a):
        if not fc.data_path.endswith('.location'):
            continue
        bone = fc.data_path.split('"')[1]
        if bone not in roots:
            continue
        for kp in fc.keyframe_points:
            kp.co.y *= k; kp.handle_left.y *= k; kp.handle_right.y *= k
        fc.update()

# the archer's arrow rides the string: re-aim it every frame at the new bow
if 'arrow' in arm.bones and 'nock' in arm.bones and 'bow' in arm.bones:
    pa, pn, pb = rig.pose.bones['arrow'], rig.pose.bones['nock'], rig.pose.bones['bow']
    G = arm.bones['bow'].head_local
    ad = rig.animation_data
    for a in bpy.data.actions:
        if not any(fc.data_path.startswith('pose.bones["arrow"]') for fc in fcurves(a)):
            continue
        ad.action = a
        if hasattr(ad, 'action_slot') and a.slots:
            ad.action_slot = a.slots[0]
        f0, f1 = (int(x) for x in a.frame_range)
        frames = []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            nock = pn.matrix.translation.copy()
            grip = (pb.matrix @ arm.bones['bow'].matrix_local.inverted() @ G.to_4d()).to_3d()
            frames.append((f, nock, (grip - nock).normalized()))
        for f, nock, d in frames:
            bpy.context.scene.frame_set(f)
            rest = arm.bones['arrow'].matrix_local
            rot = V((0, -1, 0)).rotation_difference(d)
            want = Matrix.Translation(nock) @ rot.to_matrix().to_4x4() @ Matrix.Translation(-rest.translation) @ rest
            # pose matrix in armature space -> basis (arrow is a root child: parent is the root at rest pose)
            pa.matrix = want
            bpy.context.view_layer.update()
            pa.keyframe_insert('rotation_quaternion', frame=f)
            pa.keyframe_insert('location', frame=f)
    ad.action = bpy.data.actions.get('Idle_Combat')

head_share('after')
height1 = max((o.matrix_world @ v.co).z for o in meshes() for v in o.data.vertices)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes())
print('[chibi] %s height %.2f -> %.2f, hips %.2f -> %.2f (loc keys x%.2f), drop %.2f, tris %d' % (NAME, height0, height1, hip0, hip1, k, drop, tris))

# ------------------------------------------------------------------ export, as comic_rig.export_glb
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

# ------------------------------------------------------------------ proof: the script's own cameras, then a motion strip from the side
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
tmp = tempfile.mkdtemp(prefix='chibi_')
for i, (a, f) in enumerate(strip):
    show(a, f)
    scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
    bpy.ops.render.render(write_still=True)
subprocess.run(['C:/ffmpeg/bin/ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                '-vf', 'scale=384:-1,tile=4x2', '-frames:v', '1', os.path.join(OUT, NAME + '_motion.png')], check=True)
shutil.rmtree(tmp, ignore_errors=True)
show('Idle_Combat', 0.0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('[chibi] done', NAME)
