# Hand-keyed locomotion and hit clips for the chibi foes (round 38), written over the kit's generic
# KayKit-era clips on the chunky blends (after chunk_pass.py). Same bones, names and clips otherwise.
#   blender -b <kit>/out/enemies_chunky/<name>.blend -P tools/comic_art/foe_keys.py -- <name> [only=Running_A,Hit_B]
# Writes <kit>/out/enemies_keyed/<name>.glb, .blend and <name>_keys.png (a side sheet of every keyed
# clip, a frame per tile). Bring it into the game with
#   python tools/comic_glb.py <kit>/out/enemies_keyed <name>
# then `godot --headless --import --path .` and `tests/foe_stride_check.gd` (copy the printed foot
# speed into enemy_types `run_foot_speed`).
#
# How a pose is written: not bone angles but where things go. The upper body takes the clip's base
# (Idle_Combat frame 0, so weapons stay in the guard grip) and turns on top of it, as world-space
# (yaw, pitch, roll) degrees per bone: + yaw turns to the foe's left, + pitch tips the bone's far end
# forward (a hanging arm swings back), + roll leans to its left. The legs are two-bone IK onto ankle
# targets (fl / fr, m, the foe's frame: +X its left, -Y ahead, z up) with the knees pointing ahead;
# the whole body squashes about the floor through the root bone (sq), and `root` can lay it down
# (loc, rot) for the falls, with the feet then given in the body's frame (feet='body').
#
# Runs: a planted ankle slides back exactly v / FPS a frame, v = move_speed / model_scale, so at the
# game's move speed the clip plays at 1x with its feet on the floor (enemy.run_clip_speed ~ 1). Legs,
# hips and the squash are written every frame (a held planted foot rides forward with the body and
# snaps back); arms, head and torso turns are held on twos for the comic snap. Loops are keyed from
# frame 0 to N with N == 0, so the wrap has no held seam.
import bpy, sys, os, math
from mathutils import Vector as V, Quaternion as Q, Matrix as M

FPS = 24
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
NAME = ARGS[0] if ARGS else 'minion'
ONLY = next((a[5:].split(',') for a in ARGS if a.startswith('only=')), None)
NOSHEET = 'nosheet' in ARGS
BLEND = bpy.data.filepath
OUT = os.path.join(os.path.dirname(os.path.dirname(BLEND)), 'enemies_keyed'); os.makedirs(OUT, exist_ok=True)

rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm = rig.data


def fcurves(a):
    out = []
    for layer in getattr(a, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out += list(bag.fcurves)
    return out


# ------------------------------------------------------------------ eyes (chunk_pass's, for the foes still without)
EYE_MAT, SOCKET_MAT = 'necro', 'socket'


def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig]


def islands(me):
    adj = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        adj[a].append(b); adj[b].append(a)
    seen = [False] * len(me.vertices); out = []
    for s in range(len(me.vertices)):
        if seen[s]:
            continue
        stack = [s]; seen[s] = True; isl = []
        while stack:
            v = stack.pop(); isl.append(v)
            for w in adj[v]:
                if not seen[w]:
                    seen[w] = True; stack.append(w)
        out.append(isl)
    return out


def top_bone(o, v):
    gs = [(g.weight, o.vertex_groups[g.group].name) for g in v.groups if g.weight > 0]
    return max(gs)[1] if gs else None


def add_eyes():
    """Glowing eye islands on the head (and the sockets round them) onto new bones eye.l / eye.r."""
    if 'eye.l' in arm.bones:
        return True
    mat = {'archer': 'ember', 'mage': 'arcane'}.get(NAME, EYE_MAT)   # what each foe's eyes glow in
    glow = next((o for o in meshes() if o.name == mat), None) or         next((o for o in meshes() if o.data.materials and o.data.materials[0] and o.data.materials[0].name[2:].lower() == mat), None)
    eyes = []
    if glow:
        for isl in islands(glow.data):
            if top_bone(glow, glow.data.vertices[isl[0]]) == 'head':
                c = sum((glow.data.vertices[i].co for i in isl), V()) / len(isl)
                eyes.append((c, isl))
    if len(eyes) < 2:
        print('[keys] %s eyes: %d head islands in %s, none added' % (NAME, len(eyes), EYE_MAT))
        return False
    # the two biggest islands nearest the front are the eyes (a mage's gem or a warden's crown glow too)
    eyes.sort(key=lambda e: (e[0].y, -len(e[1])))
    eyes = sorted(eyes[:2], key=lambda e: -e[0].x)   # +X is the foe's left
    parts = {'l': [(glow, eyes[0][1])], 'r': [(glow, eyes[1][1])]}
    sock = next((o for o in meshes() if o.data.materials and o.data.materials[0] and o.data.materials[0].name[2:].lower() == SOCKET_MAT), None)
    if sock:
        for isl in islands(sock.data):
            c = sum((sock.data.vertices[i].co for i in isl), V()) / len(isl)
            for side, (ec, _i) in zip('lr', eyes):
                if (c - ec).length < .09 and top_bone(sock, sock.data.vertices[isl[0]]) == 'head':
                    parts[side].append((sock, isl))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side, (ec, _i) in zip('lr', eyes):
        eb = arm.edit_bones.new('eye.' + side)
        eb.head = ec; eb.tail = ec + V((0, -.12, 0)); eb.roll = 0
        eb.parent = arm.edit_bones['head']; eb.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    for side in 'lr':
        rig.pose.bones['eye.' + side].rotation_mode = 'QUATERNION'
        for o, isl in parts[side]:
            vg = o.vertex_groups.get('eye.' + side) or o.vertex_groups.new(name='eye.' + side)
            hg = o.vertex_groups.get('head')
            if hg:
                hg.remove(isl)
            vg.add(isl, 1.0, 'REPLACE')
    print('[keys] %s eyes added: eye.l %d parts, eye.r %d parts' % (NAME, len(parts['l']), len(parts['r'])))
    return True


def eye_keys(name, length):
    if name in ('Hit_A', 'Hit_B'):
        return [(0, 1.0), (1, 0.0), (round(length * .55), 0.0), (round(length * .8), 1.0)]
    if name == 'Death_A':
        return [(0, 1.0), (3, 0.0)]
    if name == 'Lie_StandUp':
        return [(0, 0.0), (round(length * .5), 0.0), (round(length * .65), 1.0)]
    return [(0, 1.0)]


def eye_scale(o, idx):
    # bone y runs out of the face, z up the eye: shutting squashes z, widens x a touch
    return (1 + .25 * (1 - o)) if idx == 0 else (1.0 if idx == 1 else max(.08, o))


def key_eyes_on(a):
    """Eye scale keys on a clip this script doesn't re-key (the kit's), so no clip leaves them shut."""
    f0, f1 = (int(x) for x in a.frame_range)
    for fc in list(fcurves(a)):
        if '"eye.' in fc.data_path:
            return
    ad = rig.animation_data
    ad.action = a
    if a.slots:
        ad.action_slot = a.slots[0]
    for side in 'lr':
        pb = rig.pose.bones['eye.' + side]
        for idx in range(3):
            fc = a.fcurve_ensure_for_datablock(rig, pb.path_from_id('scale'), index=idx)
            for f, o in eye_keys(a.name, f1 - f0):
                kp = fc.keyframe_points.insert(f0 + f, eye_scale(o, idx)); kp.interpolation = 'LINEAR'
            fc.update()


HAS_EYES = add_eyes()
print('[keys] %s legs: %s' % (NAME, ', '.join('%s %.3f' % (b.name, b.length) for b in arm.bones if b.name.startswith(('upperleg', 'lowerleg')))))

# ------------------------------------------------------------------ the rig, in Python
BONES = list(arm.bones)
REST = {b.name: b.matrix_local.copy() for b in BONES}
PAR = {b.name: (b.parent.name if b.parent else None) for b in BONES}
LOCM = {n: (REST[PAR[n]].inverted() @ REST[n]) if PAR[n] else REST[n].copy() for n in REST}
LEN = {b.name: b.length for b in BONES}
def depth(n):
    d = 0
    while PAR[n]:
        n = PAR[n]; d += 1
    return d
ORDER = sorted(REST, key=depth)
for pb in rig.pose.bones:
    pb.rotation_mode = 'QUATERNION'


def basis_at(action, frame):
    """Each bone's matrix_basis in `action` at `frame` (unkeyed channels at rest)."""
    ch = {}
    for fc in fcurves(action):
        if '"' not in fc.data_path:
            continue
        b = fc.data_path.split('"')[1]
        prop = fc.data_path.rsplit('.', 1)[1]
        ch.setdefault(b, {}).setdefault(prop, {})[fc.array_index] = fc.evaluate(frame)
    out = {}
    for n in REST:
        c = ch.get(n, {})
        loc = V([c.get('location', {}).get(i, 0.0) for i in range(3)])
        qd = c.get('rotation_quaternion', {})
        q = Q([qd.get(0, 1.0), qd.get(1, 0.0), qd.get(2, 0.0), qd.get(3, 0.0)]).normalized()
        sc = V([c.get('scale', {}).get(i, 1.0) for i in range(3)])
        out[n] = M.Translation(loc) @ q.to_matrix().to_4x4() @ M.Diagonal(sc.to_4d())
    return out


def rot(ypr):
    """World turn from (yaw, pitch, roll) degrees: yaw about Z (+ its left), pitch about X (+ far end
    forward, to -Y), roll about -Y... (+ leans to its left, +X)."""
    y, p, r = (math.radians(x) for x in ypr)
    return Q((0, 0, 1), y) @ Q((0, 1, 0), r) @ Q((1, 0, 0), p)


def compose(pos, q, s=None):
    m = q.to_matrix().to_4x4()
    if s is not None:
        m = m @ M.Diagonal(V(s).to_4d())
    m.translation = pos
    return m


ARM_BONES = [n for n in REST if n.startswith(('upperarm.', 'lowerarm.', 'hand.'))]
HAS_LEGS = all(n in REST for n in ('upperleg.l', 'lowerleg.l', 'foot.l', 'upperleg.r', 'lowerleg.r', 'foot.r'))
STANCE = {}
if HAS_LEGS:  # the rest feet, made symmetric (some kit rests stand one foot ahead)
    _l, _r = REST['foot.l'].translation, REST['foot.r'].translation
    _x, _y, _z = (abs(_l.x) + abs(_r.x)) / 2, (_l.y + _r.y) / 2, (_l.z + _r.z) / 2
    STANCE = {'l': V((_x, _y, _z)), 'r': V((-_x, _y, _z))}
MISS = [0.0]
FOOT_REACH = (LEN['foot.l'] * .8) if HAS_LEGS else 0.0  # ankle to the ball of the foot, about


def solve(P, base):
    """A pose dict -> each bone's matrix_basis."""
    root = P.get('root', {})
    sq = root.get('sq', 0.0)
    wide = 1 + sq * .55
    mroot = compose(V(root.get('loc', (0, 0, 0))), rot(root.get('rot', (0, 0, 0))), (wide, wide, 1 - sq))
    mroot_inv = mroot.inverted()
    G = {}
    over = {}
    yaw_q = rot((P.get('hipr', (0, 0, 0))[0], 0, 0))
    for n in ORDER:
        if n in over:
            G[n] = over[n]
            continue
        pm = G[PAR[n]] if PAR[n] else M.Identity(4)
        if n == 'root':
            G[n] = REST[n].copy()
            continue
        gc = pm @ LOCM[n] @ base[n]
        pos, q, sc = gc.decompose()
        if n == 'hips':
            pos = pos + V(P.get('hip', (0, 0, 0)))
            q = rot(P.get('hipr', (0, 0, 0))) @ q
        elif n in P and isinstance(P[n], tuple) and len(P[n]) == 3:
            q = rot(P[n]) @ q
        s = P.get('scale', {}).get(n)
        G[n] = compose(pos, q, (s, s, s) if s else sc)
        if n.startswith('upperleg.') and HAS_LEGS and P.get('legs', True):
            side = n[-1]
            up, lo, ft = n, 'lowerleg.' + side, 'foot.' + side
            tgt = V(P.get('f' + side, STANCE[side]))
            if P.get('feet', 'world') == 'world':
                tgt = mroot_inv @ tgt
            p0 = pos
            a, c = LEN[up], LEN[lo]
            d0 = (tgt - p0).length
            MISS[0] = max(MISS[0], d0 - (a + c) * .995)
            d = min(max(d0, abs(a - c) + 1e-3), (a + c) * .995)
            u = (tgt - p0).normalized()
            hq = G['hips'].to_quaternion() if P.get('feet', 'world') == 'body' else yaw_q
            pole = hq @ V((.18 if side == 'l' else -.18, -1, 0))
            nn = (pole - u * pole.dot(u)).normalized()
            ca = (a * a + d * d - c * c) / (2 * a * d)
            sa = math.sqrt(max(0.0, 1 - ca * ca))
            knee = p0 + (u * ca + nn * sa) * a
            ankle = p0 + u * d
            ref = hq @ REST[up].to_quaternion()
            q_up = (ref @ V((0, 1, 0))).rotation_difference(knee - p0) @ ref
            ref = q_up @ (REST[up].to_quaternion().inverted() @ REST[lo].to_quaternion())
            q_lo = (ref @ V((0, 1, 0))).rotation_difference(ankle - knee) @ ref
            toe = math.radians(P.get('t' + side, 0.0))
            side_ax = hq @ V((1, 0, 0))
            q_ft = Q(side_ax, -toe) @ hq @ REST[ft].to_quaternion()
            G[up] = compose(p0, q_up)
            over[lo] = compose(knee, q_lo)
            over[ft] = compose(ankle, q_ft)
    out = {}
    for n in ORDER:
        if n == 'root':
            out[n] = REST[n].inverted() @ mroot @ REST[n]
            continue
        pm = G[PAR[n]] if PAR[n] else M.Identity(4)
        out[n] = (pm @ LOCM[n]).inverted() @ G[n]
    if 'eye.l' in out:
        o = P.get('eye', 1.0)
        for s in 'lr':
            l, q, _ = out['eye.' + s].decompose()
            out['eye.' + s] = compose(l, q, [eye_scale(o, i) for i in range(3)])
    return out


def write(name, frames, base_name='Idle_Combat'):
    """frames: list of pose dicts, frame 0..N. Replaces the action `name` (or adds it)."""
    base = basis_at(bpy.data.actions[base_name], bpy.data.actions[base_name].frame_range[0])
    old = bpy.data.actions.get(name)
    if old:
        old.name = name + '__old'
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    ad = rig.animation_data or rig.animation_data_create()
    ad.action = a
    if a.slots:
        ad.action_slot = a.slots[0]
    MISS[0] = 0.0
    mats = [solve(P, base) for P in frames]
    for n in ORDER:
        pb = rig.pose.bones[n]
        prev = None
        cols = {'location': [], 'rotation_quaternion': [], 'scale': []}
        for m in mats:
            l, q, s = m[n].decompose()
            if prev is not None and q.dot(prev) < 0:
                q = -q
            prev = q
            cols['location'].append(l); cols['rotation_quaternion'].append(q); cols['scale'].append(s)
        for prop, vals in cols.items():
            for i in range(len(vals[0])):
                fc = a.fcurve_ensure_for_datablock(rig, pb.path_from_id(prop), index=i)
                fc.keyframe_points.add(len(vals))
                co = []
                for f, v in enumerate(vals):
                    co += [f, v[i]]
                fc.keyframe_points.foreach_set('co', co)
                fc.keyframe_points.foreach_set('interpolation', [1] * len(vals))
                fc.update()
    if old:
        bpy.data.actions.remove(old)
    print('[keys] %s %s %d frames, worst leg reach miss %.3f m' % (NAME, name, len(frames) - 1, MISS[0]))
    KEYED.append(name)


KEYED = []


# ------------------------------------------------------------------ helpers for clips
def lerp(a, b, t):
    if isinstance(a, (tuple, list)):
        return tuple(x + (y - x) * t for x, y in zip(a, b))
    return a + (b - a) * t


def mix(p, q, t):
    out = {}
    for k in set(p) | set(q):
        if k in ('feet', 'legs'):
            out[k] = (p if t < .5 else q).get(k, p.get(k, q.get(k)))
            continue
        a, b = p.get(k), q.get(k)
        if isinstance(a, dict) or isinstance(b, dict):
            a = a or {}; b = b or {}
            out[k] = {kk: lerp(a.get(kk, NEUTRAL_SUB.get(k, {}).get(kk, b.get(kk))), b.get(kk, NEUTRAL_SUB.get(k, {}).get(kk, a.get(kk))), t) for kk in set(a) | set(b)}
            continue
        if a is None:
            a = default_of(k, b)
        if b is None:
            b = default_of(k, a)
        out[k] = lerp(a, b, t)
    return out


NEUTRAL_SUB = {'root': {'loc': (0, 0, 0), 'rot': (0, 0, 0), 'sq': 0.0}, 'scale': {}}


def default_of(k, other):
    if k in ('fl', 'fr'):
        return tuple(STANCE[k[1]])
    if k == 'eye' or k == 'scale_':
        return 1.0
    if isinstance(other, tuple):
        return (0.0,) * len(other)
    if k == 'scale':
        return {}
    return 0.0


EASE = {'lin': lambda t: t, 'in': lambda t: t * t, 'out': lambda t: 1 - (1 - t) ** 2,
        'io': lambda t: t * t * (3 - 2 * t), 'hold': lambda t: 0.0}


def keyed(keys, n, step=2, held=('spine', 'chest', 'head', 'jaw', 'eye') + tuple(ARM_BONES)):
    """keys [(frame, pose, ease)] -> a pose per frame 0..n. Upper body held on twos (drawing every
    `step` frames and on every key); legs, hips and root every frame."""
    def at(f):
        for (f0, p0, e), (f1, p1, _e) in zip(keys, keys[1:]):
            if f0 <= f <= f1:
                return mix(p0, p1, EASE[e]((f - f0) / max(f1 - f0, 1e-6)))
        return dict(keys[-1][1])
    marks = sorted(set(list(range(0, n + 1, step)) + [k[0] for k in keys]))
    out = []
    for f in range(n + 1):
        p = at(f)
        dm = max(m for m in marks if m <= f)
        if dm != f:
            ph = at(dm)
            for k in list(p.keys()):
                if k in held or k.startswith(('upperarm', 'lowerarm', 'hand', 'weapon', 'shield', 'bow')):
                    p[k] = ph[k] if k in ph else p[k]
        out.append(p)
    return out


def hermite(p0, p1, v0, v1, t):
    t2, t3 = t * t, t * t * t
    return (2 * t3 - 3 * t2 + 1) * p0 + (t3 - 2 * t2 + t) * v0 + (-2 * t3 + 3 * t2) * p1 + (t3 - t2) * v1


# ------------------------------------------------------------------ run cycles
def run_cycle(c):
    """A loop from a gait spec. Left foot lands on frame 0, the right on N/2."""
    N, P, v = c['N'], c['P'], c['v']
    dv = v / FPS                     # m a frame a planted foot slides back (+Y: behind)
    span = dv * P
    out = []
    lift, fwd0 = c.get('lift', .1), c.get('ahead', 0.0)
    width = c.get('width', 1.0)
    arms = c.get('arms', {})
    for f in range(N + 1):
        pose = {'legs': True}
        for side, off in (('l', 0), ('r', N // 2)) if STANCE else ():
            t = (f - off) % N        # frames since this foot landed
            st = STANCE[side]
            x = st.x * width
            land_y = st.y + fwd0 - span / 2
            if t <= P:               # planted, sliding back with the floor
                y = land_y + dv * t
                k = (t / max(P, 1)) ** 3
                toe = c.get('heel', 8) * (1 - t / max(P, 1)) - c.get('push', 14) * k
                z = st.z
            else:                    # in the air: up, through, down onto the landing mark
                s = (t - P) / (N - P)
                sw = N - P
                y = hermite(land_y + span, land_y, dv * sw, dv * sw * c.get('paw', .6), s)
                pk = c.get('peak_at', .45)  # when in the swing the foot is highest
                w = .5 * s / pk if s < pk else .5 + .5 * (s - pk) / (1 - pk)
                z = st.z + lift * math.sin(math.pi * w) ** c.get('lift_pow', 1.0)
                toe = -c.get('push', 14) * (1 - s) ** 2 + c.get('heel', 8) * s ** 2 + c.get('kick', 0) * math.sin(math.pi * s)
            pose['f' + side] = (x, y, z)
            pose['t' + side] = toe
        ph = 2 * math.pi * f / N          # one turn a cycle; 0 = left foot down
        ph2 = 2 * ph                      # one turn a step
        down = c.get('down_at', .2)
        # body: lowest just after each contact, highest in the air
        bob = -math.cos(ph2 - 2 * math.pi * down)
        pose['hip'] = (c.get('sway', .03) * math.cos(ph), c.get('hip_y', 0.0), -c.get('drop', .05) + c.get('bob', .03) * -bob)
        pose['hipr'] = (c.get('yaw', 8) * math.cos(ph), c.get('lean', 12) + c.get('lean_bob', 2) * bob,
                        c.get('roll', 6) * math.cos(ph))
        sq = c.get('sq', .06) * max(0.0, bob) - c.get('stretch', .03) * max(0.0, -bob)
        pose['root'] = {'sq': sq}
        pose['spine'] = (-c.get('yaw', 8) * .6 * math.cos(ph), c.get('spine', 0), -c.get('roll', 6) * .4 * math.cos(ph))
        pose['chest'] = (-(c.get('yaw', 8) * .4 + c.get('twist', 10)) * math.cos(ph), c.get('chest', 0), 0)  # shoulders net -twist against the hips
        pose['head'] = (c.get('yaw', 8) * .5 * math.cos(ph), -c.get('lean', 12) * c.get('head_up', .6) + c.get('nod', 4) * bob, -c.get('roll', 6) * .5 * math.cos(ph))
        sw = c.get('arm', 30)
        for side, sgn in (('l', 1), ('r', -1)):
            a = arms.get(side, 1.0)
            # an arm swings against its own leg: back while that leg is ahead
            pose['upperarm.' + side] = (0, sw * a * sgn * math.cos(ph) + c.get('arm_back', 0) * a, c.get('arm_out', 0) * sgn)
            pose['lowerarm.' + side] = (0, -c.get('pump', 15) * a * max(0.0, -sgn * math.cos(ph)), 0)
        for k, fn in c.get('extra', {}).items():
            pose[k] = fn(ph, bob)
        out.append(pose)
    # upper body on twos
    for f in range(1, N + 1, 2):
        for k in list(out[f].keys()):
            if k in ('spine', 'chest', 'head') or k.startswith(('upperarm', 'lowerarm', 'hand', 'cloth', 'coat', 'loin', 'skirt', 'tabard', 'weapon', 'shield', 'bow', 'bomb')):
                out[f][k] = out[f - 1][k]
    return out


# ------------------------------------------------------------------ per foe
import importlib.util
spec = importlib.util.spec_from_file_location('foe_cycles', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'foe_cycles.py'))
CY = importlib.util.module_from_spec(spec); spec.loader.exec_module(CY)
CFG = CY.FOES[NAME]
ctx = {'STANCE': STANCE, 'REST': {n: REST[n].translation.copy() for n in REST}, 'keyed': keyed, 'run_cycle': run_cycle,
       'HAS_LEGS': HAS_LEGS, 'bones': set(REST), 'FPS': FPS,
       'length': lambda n: int(round(bpy.data.actions[n].frame_range[1] - bpy.data.actions[n].frame_range[0])) if n in bpy.data.actions else 0}
for clip, make in CFG.items():
    if ONLY and clip not in ONLY:
        continue
    frames = make(ctx)
    write(clip, frames)

if HAS_EYES:
    for a in [a for a in bpy.data.actions if a.use_fake_user and a.name not in KEYED]:
        key_eyes_on(a)

# ------------------------------------------------------------------ export, as chunk_pass.py
ad = rig.animation_data
acts = [a for a in bpy.data.actions if a.use_fake_user]
for t in list(ad.nla_tracks):
    ad.nla_tracks.remove(t)
for a in acts:
    tr = ad.nla_tracks.new(); tr.name = a.name; tr.mute = True
    tr.strips.new(a.name, 0, a)
ad.action = None
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for o in rig.children:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, NAME + '.glb'), export_format='GLB', use_selection=True, export_apply=False,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True, export_cameras=False, export_lights=False)
for t in list(ad.nla_tracks):
    ad.nla_tracks.remove(t)


def show(action, frame):
    a = bpy.data.actions[action]
    ad.action = a
    if a.slots:
        ad.action_slot = a.slots[0]
    bpy.context.scene.frame_set(int(frame))


# ------------------------------------------------------------------ side sheet: every keyed clip, a frame a tile
if not NOSHEET and KEYED:
    import tempfile, subprocess, shutil
    scn = bpy.context.scene
    try:
        scn.render.engine = 'BLENDER_WORKBENCH'
    except TypeError:
        pass
    scn.display.shading.light = 'STUDIO'
    scn.display.shading.color_type = 'MATERIAL'
    scn.render.resolution_x, scn.render.resolution_y = 300, 300
    scn.render.film_transparent = False
    h = max(REST['head'].translation.z + LEN['head'], 1.0)
    cam_d = bpy.data.cameras.new('KeysCam'); cam_d.type = 'ORTHO'; cam_d.ortho_scale = h * 2.7
    cam = bpy.data.objects.new('KeysCam', cam_d); scn.collection.objects.link(cam)
    cam.location = (6, 0, h * .85); cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)   # from its left, looking -X
    scn.camera = cam
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.startswith(('floor', 'Floor')):
            o.hide_render = False
    tmp = tempfile.mkdtemp(prefix='keys_')
    sheet = []
    for clip in KEYED:
        a = bpy.data.actions[clip]
        f0, f1 = (int(x) for x in a.frame_range)
        step = 1 if f1 - f0 <= 16 else 2
        tiles = list(range(f0, f1 + 1, step))[:24]
        while len(tiles) % 8:
            tiles.append(-1)
        for i, f in enumerate(tiles):
            p = os.path.join(tmp, '%s_%03d.png' % (clip, i))
            if f < 0:
                shutil.copy(os.path.join(tmp, '%s_%03d.png' % (clip, i - 1)), p)
                continue
            show(clip, f)
            scn.render.filepath = p
            bpy.ops.render.render(write_still=True)
        row = os.path.join(tmp, 'row_%s.png' % clip)
        subprocess.run(['C:/ffmpeg/bin/ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, clip + '_%03d.png'),
                        '-vf', 'tile=8x%d' % (len(tiles) // 8), '-frames:v', '1', row], check=True)
        sheet.append(row)
    args = ['C:/ffmpeg/bin/ffmpeg.exe', '-y', '-loglevel', 'error']
    for r in sheet:
        args += ['-i', r]
    args += ['-filter_complex', ''.join('[%d:v]' % i for i in range(len(sheet))) + 'vstack=inputs=%d' % len(sheet) if len(sheet) > 1 else 'null',
             os.path.join(OUT, NAME + '_keys.png')]
    subprocess.run(args, check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    bpy.data.objects.remove(cam)
    print('[keys] sheet', os.path.join(OUT, NAME + '_keys.png'), 'rows:', ', '.join(KEYED))

show('Idle_Combat', 0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('[keys] done', NAME, 'keyed:', ', '.join(KEYED))
