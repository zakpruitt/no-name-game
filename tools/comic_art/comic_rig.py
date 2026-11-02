# Small hand-keyed rig kit for comic enemies. No source rig needed: bones from a table, poses as rotations.
#
#   bones = {'hips': (head, tail, None), 'spine': (head, tail, 'hips'), ...}
#   R = comic_rig.Rig('MinionRig', bones)
#   R.skin_islands(obj)                 every disconnected piece follows its nearest bone (hard parts, bones, armour)
#   R.skin_soft(obj, names, power=5)    smooth weights by distance (organic meshes, cloth)
#   R.skin_fixed(obj, 'head')           whole object on one bone
#   R.action('Idle', length=48, keys={0: POSE_A, 24: POSE_B, 48: POSE_A})
#
# A pose is {bone: (rx, ry, rz)} degrees about the WORLD axes at rest, applied in the bone's parent chain, so
# "upperarm.r (60,0,0)" swings that whole arm 60 degrees about world X and the forearm follows. A bone may also be
# {bone: {'rot': (..), 'loc': (x, y, z)}} to move it in world metres (hips: crouches, lunges, falls).
# Bones not named in a key stay at rest, EXCEPT that they interpolate from/to the neighbouring keys that name them.
# Front is -Y, the creature's left is +X, up is +Z.
# Key frames may be given as (frame, ease) tuples: ease 'in' (slow out of the last key, fast arrival: the swing),
# 'out' (fast departure, slow settle: the recoil), 'smooth' (default), 'hold' (snap to it on that frame).
import bpy, math
from mathutils import Vector as V, Quaternion as Q, Euler, Matrix

YAX = V((0, 1, 0))

def _ease(k, kind):
    if kind == 'in': return k * k * k
    if kind == 'out': return 1 - (1 - k) ** 3
    if kind == 'hold': return 0.0
    return k * k * (3 - 2 * k)

def seg_dist(p, a, b):
    ab = b - a; t = max(0, min(1, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length

def islands(me):
    parent = list(range(len(me.vertices)))
    def f(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    for e in me.edges:
        a, b = f(e.vertices[0]), f(e.vertices[1])
        if a != b: parent[a] = b
    g = {}
    for i in range(len(me.vertices)): g.setdefault(f(i), []).append(i)
    return list(g.values())

class Rig:
    def __init__(s, name, bones, scene=None):
        s.scn = scene or bpy.context.scene
        s.name = name
        arm = bpy.data.armatures.new(name)
        s.obj = bpy.data.objects.new(name, arm); s.scn.collection.objects.link(s.obj)
        bpy.context.view_layer.objects.active = s.obj; s.obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        for n, (h, t, p) in bones.items():
            e = arm.edit_bones.new(n); e.head = V(h); e.tail = V(t)
        for n, (h, t, p) in bones.items():
            if p: arm.edit_bones[n].parent = arm.edit_bones[p]
        bpy.ops.object.mode_set(mode='OBJECT')
        s.arm = arm
        s.names = list(bones)
        s.q0 = {b.name: b.matrix_local.to_quaternion() for b in arm.bones}
        s.seg = {n: (V(bones[n][0]), V(bones[n][1])) for n in bones}
        for pb in s.obj.pose.bones: pb.rotation_mode = 'QUATERNION'
        s.actions = []

    def _bind(s, o):
        mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = s.obj
        o.modifiers.move(o.modifiers.find('Skin'), 0)
        o.parent = s.obj

    def _put(s, o, groups, i, ws):
        tot = sum(w for w, _ in ws) or 1
        for w, n in ws:
            g = groups.get(n) or o.vertex_groups.new(name=n); groups[n] = g
            g.add([i], w / tot, 'REPLACE')

    def skin_islands(s, o, names=None):
        names = names or s.names
        me = o.data; groups = {}
        for isl in islands(me):
            c = sum((me.vertices[i].co for i in isl), V()) / len(isl)
            b = min(names, key=lambda n: seg_dist(c, *s.seg[n]))
            for i in isl: s._put(o, groups, i, [(1, b)])
        s._bind(o)

    def skin_soft(s, o, names=None, power=5, top=3, floor=.012):
        names = names or s.names
        me = o.data; groups = {}
        for v in me.vertices:
            ds = sorted((max(seg_dist(v.co, *s.seg[n]), floor), n) for n in names)[:top]
            s._put(o, groups, v.index, [(1 / d ** power, n) for d, n in ds])
        s._bind(o)

    def skin_fixed(s, o, bone):
        groups = {}
        for v in o.data.vertices: s._put(o, groups, v.index, [(1, bone)])
        s._bind(o)

    def _basis(s, n, spec):
        rot = spec.get('rot', (0, 0, 0)) if isinstance(spec, dict) else spec
        loc = spec.get('loc', (0, 0, 0)) if isinstance(spec, dict) else (0, 0, 0)
        e = Euler([math.radians(a) for a in rot], 'XYZ').to_quaternion()
        q0 = s.q0[n]
        return (q0.inverted() @ e @ q0).normalized(), q0.inverted() @ V(loc)

    def action(s, name, length, keys):
        """Bakes eased key poses to one key per frame. Returns the action."""
        items = []
        for k, pose in keys.items():
            f, ease = k if isinstance(k, tuple) else (k, 'smooth')
            items.append((f, ease, pose))
        items.sort(key=lambda x: x[0])
        used = [n for n in s.names if any(n in p for _, _, p in items)]
        a = bpy.data.actions.new(name); a.use_fake_user = True
        ad = s.obj.animation_data_create(); ad.action = a
        N = length + 1
        for n in used:
            seq = [(f, e, s._basis(n, p[n]) if n in p else (Q(), V())) for f, e, p in items]
            samples = []
            for fr in range(N):
                if fr <= seq[0][0]: samples.append(seq[0][2]); continue
                if fr >= seq[-1][0]: samples.append(seq[-1][2]); continue
                for i in range(len(seq) - 1):
                    if seq[i][0] <= fr < seq[i + 1][0]:
                        k = (fr - seq[i][0]) / (seq[i + 1][0] - seq[i][0])
                        k = _ease(k, seq[i + 1][1])
                        samples.append((seq[i][2][0].slerp(seq[i + 1][2][0], k), seq[i][2][1].lerp(seq[i + 1][2][1], k)))
                        break
            pb = s.obj.pose.bones[n]
            for idx in range(4):
                fc = a.fcurve_ensure_for_datablock(s.obj, pb.path_from_id('rotation_quaternion'), index=idx)
                fc.keyframe_points.add(N)
                co = [0.0] * (2 * N)
                for j in range(N): co[2 * j] = j; co[2 * j + 1] = samples[j][0][idx]
                fc.keyframe_points.foreach_set('co', co); fc.keyframe_points.foreach_set('interpolation', [1] * N); fc.update()
            if any(samples[j][1].length > 1e-6 for j in range(N)):
                for idx in range(3):
                    fc = a.fcurve_ensure_for_datablock(s.obj, pb.path_from_id('location'), index=idx)
                    fc.keyframe_points.add(N)
                    co = [0.0] * (2 * N)
                    for j in range(N): co[2 * j] = j; co[2 * j + 1] = samples[j][1][idx]
                    fc.keyframe_points.foreach_set('co', co); fc.keyframe_points.foreach_set('interpolation', [1] * N); fc.update()
        s.actions.append(a)
        return a

    def play(s, action_name, frame):
        """Show one frame of an action (for stills and sheets)."""
        s.obj.animation_data.action = bpy.data.actions[action_name]
        s.scn.frame_set(frame)

def contact_sheet(rig, frames, cam, out_png, cols=4, tile_w=480, tmp=None):
    """Renders [(action, frame), ...] through cam and tiles them into out_png with ffmpeg. Read the sheet: it catches bad poses."""
    import os, subprocess, tempfile, shutil
    tmp = tmp or tempfile.mkdtemp(prefix='sheet_')
    scn = bpy.context.scene; scn.camera = cam
    scn.render.image_settings.file_format = 'PNG'
    for i, (a, f) in enumerate(frames):
        rig.play(a, f)
        scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
        bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                    '-vf', 'scale=%d:-1,tile=%dx%d' % (tile_w, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)

def export_glb(path, rig, extra_objs=()):
    """Every action of the rig under its own name. Geometry, skin and animation only: the comic look is a Godot shader job."""
    ad = rig.obj.animation_data
    keep = ad.action
    for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
    for a in rig.actions:
        tr = ad.nla_tracks.new(); tr.name = a.name; tr.mute = True
        tr.strips.new(a.name, 0, a)
    ad.action = None
    bpy.ops.object.select_all(action='DESELECT')
    rig.obj.select_set(True)
    for o in list(rig.obj.children) + list(extra_objs):
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig.obj
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_animations=True,
                              export_animation_mode='ACTIONS', export_skins=True, export_cameras=False, export_lights=False)
    for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
    ad.action = keep
