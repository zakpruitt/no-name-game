# Rigs the painted shaman (bind pose = his hunched hero pose) with the KayKit deform bone names,
# retargets the game's animations onto it, simulates secondary motion and the spirit, bakes a showcase.
# Run after build_poc.py in the same session: exec with ns {"__name__": "rig"} (needs SRC rig 'Rig' in the file).
import bpy, re, math, random
from mathutils import Vector as V, Quaternion as Q, Matrix

D = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\style_poc"
ns = {"__name__": "build"}
exec(compile(open(D + r"\build_poc.py").read(), "build_poc", "exec"), ns)
scn = bpy.context.window.scene
J = ns['JOINTS']
SRC = bpy.data.objects['Rig']
FPS = 24
Yax = V((0, 1, 0))

for n in ('PRig', 'SpiritRig'):
    o = bpy.data.objects.get(n)
    if o: bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name.startswith(('P_', 'S_', 'FX_POC', 'CamShow')): bpy.data.actions.remove(a)

# ------------------------------------------------------------------ the skeleton
H = J['H']
hips0 = V((0, 0, .86)); spine0 = V((0, -.01, 1.02)); chest0 = V((0, -.06, 1.24)); neck0 = V((0, -.22, 1.57))
ft = lambda p: p + V((0, -.09, -.1))
REST = {
    'root': (V((0, 0, 0)), V((0, 0, .3))),
    'hips': (hips0, spine0), 'spine': (spine0, chest0), 'chest': (chest0, neck0),
    'head': (neck0 + V((0, -.04, .05)), H + V((0, -.03, .2))),
    'upperarm.l': (J['ms'], J['me']), 'lowerarm.l': (J['me'], J['mw']), 'wrist.l': (J['mw'], J['mf']), 'hand.l': (J['mf'], J['mf'] + V((.02, -.06, -.14))),
    'upperarm.r': (J['sh'], J['el']), 'lowerarm.r': (J['el'], J['wr']), 'wrist.r': (J['wr'], J['hd']), 'hand.r': (J['hd'], J['hd'] + V((-.03, -.1, .1))),
    'upperleg.l': (J['hl'], J['kl']), 'lowerleg.l': (J['kl'], J['al']), 'foot.l': (J['al'], ft(J['al'])), 'toes.l': (ft(J['al']), ft(J['al']) + V((0, -.13, 0))),
    'upperleg.r': (J['hr'], J['kr']), 'lowerleg.r': (J['kr'], J['tr']), 'foot.r': (J['tr'], J['tr'] + V((0, -.03, .03))), 'toes.r': (J['tr'] + V((0, -.03, .03)), J['tr'] + V((0, -.06, .03))),
}
EXTRA = {
    'mane': ('head', H + V((0, .14, .04)), H + V((0, .45, -.3))),
    'beard': ('head', H + V((0, -.13, -.18)), H + V((.05, -.1, -.62))),
    'cape.1': ('chest', V((0, .2, 1.5)), V((0, .34, 1.15))),
    'cape.2': ('cape.1', V((0, .34, 1.15)), V((0, .56, .72))),
}
SLOTS = ['handslot.l', 'handslot.r']
sb = SRC.data.bones
ORDER = [b.name for b in sb if b.name in REST or b.name in SLOTS]
s_rest = {n: sb[n].matrix_local.copy() for n in ORDER}
s_q0 = {n: s_rest[n].to_quaternion() for n in ORDER}

arm = bpy.data.armatures.new('PRig'); PR = bpy.data.objects.new('PRig', arm); scn.collection.objects.link(PR)
bpy.context.view_layer.objects.active = PR; PR.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for n in ORDER:
    eb = arm.edit_bones.new(n)
    if n in SLOTS:
        hand = n.replace('handslot', 'hand')
        h_, t_ = REST[hand]
        qa = (s_q0[hand] @ Yax).rotation_difference((t_ - h_).normalized())
        off = s_rest[n].translation - s_rest[hand].translation
        eb.head = h_ + qa @ off
        eb.tail = eb.head + qa @ (sb[n].tail_local - sb[n].head_local)
        eb.align_roll(qa @ (s_q0[n] @ V((0, 0, 1))))
    else:
        h_, t_ = REST[n]
        eb.head, eb.tail = h_, t_
        qa = (s_q0[n] @ Yax).rotation_difference((t_ - h_).normalized())
        eb.align_roll(qa @ (s_q0[n] @ V((0, 0, 1))))
for n in ORDER:
    if sb[n].parent: arm.edit_bones[n].parent = arm.edit_bones[sb[n].parent.name]
for n, (p, h_, t_) in EXTRA.items():
    eb = arm.edit_bones.new(n); eb.head, eb.tail = h_, t_; eb.parent = arm.edit_bones[p]
bpy.ops.object.mode_set(mode='OBJECT')
tb = arm.bones
t_rest = {b.name: b.matrix_local.copy() for b in tb}
t_q0 = {n: m.to_quaternion() for n, m in t_rest.items()}
ALL_T = [b.name for b in tb]
for pb in PR.pose.bones: pb.rotation_mode = 'QUATERNION'

# ------------------------------------------------------------------ reading a KayKit action without touching the scene
def curves(action):
    cb = action.layers[0].strips[0].channelbag(action.slots[0])
    out = {}
    for fc in cb.fcurves:
        m = re.match(r'pose\.bones\["(.+)"\]\.(rotation_quaternion|location)', fc.data_path)
        if m: out.setdefault(m.group(1), {}).setdefault(m.group(2), {})[fc.array_index] = fc
    return out

def src_pose(cv, f):
    M = {}
    for n in ORDER:
        b = sb[n]; c = cv.get(n, {})
        q = c.get('rotation_quaternion'); l = c.get('location')
        qq = Q([q[i].evaluate(f) for i in range(4)]).normalized() if q else Q()
        ll = V([l[i].evaluate(f) for i in range(3)]) if l else V()
        basis = Matrix.Translation(ll) @ qq.to_matrix().to_4x4()
        if b.parent:
            pn = b.parent.name
            M[n] = M[pn] @ (s_rest[pn].inverted() @ s_rest[n]) @ basis
        else:
            M[n] = s_rest[n] @ basis
    return {n: (m.to_translation(), m.to_quaternion()) for n, m in M.items()}

# ------------------------------------------------------------------ retarget
S_MOVE = 1.37
TORSO = ('hips', 'spine', 'chest', 'head')
# how far each arm follows the source (0 keeps the hero pose, 1 is the KayKit swing): storm(r), magma(l)
ARM = {'Idle': (.04, .05), 'Running_A': (.5, .68), '2H_Melee_Idle': (.35, .4), 'Dodge_Forward': (.75, .75), 'Jump_Idle': (.5, .5), 'Jump_Start': (.5, .5), 'Spellcasting': (.8, .4), 'Spellcast_Raise': (.8, .4), 'Spellcast_Shoot': (.9, .4)}
DRAG = {'Running_A': .3, 'Dodge_Forward': .4}
GROUNDED = {'Jump_Start': 0, 'Jump_Idle': 0, 'Dodge_Forward': .7, 'Death_A': 0}
TORSO_W = {'Running_A': .4, 'Dodge_Forward': .55, 'Idle': .7, '2H_Melee_Idle': .6}
NAMES = ['Idle', 'Running_A', '2H_Melee_Idle', '1H_Melee_Attack_Chop', '1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Stab', '2H_Melee_Attack_Chop', '2H_Melee_Attack_Slice', '2H_Melee_Attack_Spin', '2H_Melee_Attack_Spinning', '2H_Melee_Attack_Stab',
         'Dualwield_Melee_Attack_Chop', 'Dualwield_Melee_Attack_Slice', 'Dodge_Forward', 'Jump_Start', 'Jump_Idle', 'Hit_A', 'Death_A', 'Spellcasting', 'Spellcast_Raise', 'Spellcast_Shoot']

def ik(hip, target, a, b, pole):
    d = target - hip
    L = min(max(d.length, abs(a - b) + 1e-3), a + b - 1e-3)
    u = d.normalized()
    x = (a * a - b * b + L * L) / (2 * L)
    h = math.sqrt(max(a * a - x * x, 0))
    p = pole - u * pole.dot(u)
    if p.length < 1e-4: p = V((0, -1, 0)) - u * u.y * -1
    return hip + u * x + p.normalized() * h, hip + u * L

def rot_to(q, new_y):
    return (q @ Yax).rotation_difference(new_y.normalized()) @ q

def retarget(name):
    act = bpy.data.actions[name]
    cv = curves(act)
    last = int(math.ceil(act.frame_range[1]))
    src0 = {n: (s_rest[n].to_translation(), s_q0[n]) for n in ORDER}
    wr_, wl_ = ARM.get(name, (1, 1))
    frames, heads = [], []
    for f in range(last + 1):
        sp = src_pose(cv, f)
        W, P = {}, {}
        W['root'] = t_q0['root']; P['root'] = t_rest['root'].to_translation()
        ground = min((sp['foot.l'][0].z - src0['foot.l'][0].z), (sp['foot.r'][0].z - src0['foot.r'][0].z)) * S_MOVE * GROUNDED.get(name, .92)
        hip_t = t_rest['hips'].to_translation() + (sp['hips'][0] - src0['hips'][0]) * S_MOVE
        hip_t.z -= ground
        for n in ORDER:
            if n == 'root': continue
            pn = tb[n].parent.name
            restq = t_q0[n]
            sq = sp[n][1]
            delta = sq @ s_q0[n].inverted()
            if n == 'hips':
                P[n] = hip_t
            else:
                off = t_rest[n].to_translation() - t_rest[pn].to_translation()
                P[n] = P[pn] + (W[pn] @ t_q0[pn].inverted()) @ off
            if n in TORSO:
                W[n] = Q().slerp(delta, TORSO_W.get(name, .85)) @ restq
            elif n.startswith(('upperarm', 'lowerarm', 'wrist', 'hand.')):
                w = wl_ if n.endswith('.l') else wr_
                W[n] = restq.slerp(sq, w)
            elif n.startswith('handslot'):
                W[n] = W[pn] @ t_q0[pn].inverted() @ restq
            elif n.startswith('upperleg'):
                side = n[-1]
                up, lo = 'upperleg.' + side, 'lowerleg.' + side
                hipw = P[n]
                ank0 = t_rest[lo].to_translation() + (t_q0[lo] @ Yax) * tb[lo].length
                sa, sa0 = sp['foot.' + side][0], src0['foot.' + side][0]
                tgt = ank0 + (sa - sa0) * S_MOVE
                tgt.z = max(tgt.z - ground, ank0.z)
                a, b = tb[up].length, tb[lo].length
                knee0 = t_rest[lo].to_translation(); hip0 = t_rest[up].to_translation()
                pole0 = knee0 - hip0.lerp(ank0, .5)
                if pole0.length < .01: pole0 = V((0, -1, 0))
                pole = (sp[up][1] @ s_q0[up].inverted()) @ pole0
                knee, ankle = ik(hipw, tgt, a, b, pole)
                W[up] = rot_to(delta @ restq, knee - hipw)
                W['__knee.' + side] = knee; W['__ankle.' + side] = ankle
            elif n.startswith('lowerleg'):
                side = n[-1]
                P[n] = W['__knee.' + side]
                W[n] = rot_to(delta @ restq, W['__ankle.' + side] - P[n])
            else:  # foot, toes
                W[n] = delta @ restq
                if n.startswith('foot'): P[n] = W['__ankle.' + n[-1]]
        basis = {}
        for n in ORDER:
            if n == 'root': basis[n] = (Q(), V()); continue
            pn = tb[n].parent.name
            q = t_q0[n].inverted() @ t_q0[pn] @ W[pn].inverted() @ W[n]
            l = V()
            if n == 'hips':
                l = t_q0[n].inverted() @ (hip_t - t_rest['hips'].to_translation())
            basis[n] = (q.normalized(), l)
        frames.append(basis)
        heads.append((P['head'].copy(), P['chest'].copy(), {k: W[k] for k in ('head', 'chest')}))
    # secondary motion: spring lag driven by the bone's acceleration
    dt = 1 / FPS
    drag = DRAG.get(name, 0)
    for bone, parent, src_i, gain, k_, c_, bias in (('mane', 'head', 0, .09, 70, 8, V((0, .35, .1))), ('beard', 'head', 0, .08, 80, 9, V((.05, .25, 0))), ('cape.1', 'chest', 1, .08, 50, 7, V((0, .35, .05))), ('cape.2', 'cape.1', 1, .12, 45, 6, V((0, .55, .15)))):
        lag, vel = V(), V()
        n = len(frames)
        for pass_ in range(2):
            for i in range(n):
                acc = (heads[(i + 1) % n][src_i] - heads[i][src_i] * 2 + heads[(i - 1) % n][src_i]) * FPS * FPS
                vel += (-lag * k_ - vel * c_ - acc * gain) * dt
                lag += vel * dt
                if pass_ == 1:
                    wq = heads[i][2].get(parent, heads[i][2]['chest']) @ t_q0[parent].inverted() @ t_q0[bone]
                    bob = V((math.sin(i * .19 + src_i) * .01, 0, math.sin(i * .13) * .012))
                    local = wq.inverted() @ (lag + bias * drag + bob)
                    frames[i][bone] = (Yax.rotation_difference((Yax + local * 1.2).normalized()), V())
    return frames

def write(obj, action_name, frames, bones):
    a = bpy.data.actions.new(action_name); a.use_fake_user = True
    ad = obj.animation_data_create(); ad.action = a
    N = len(frames)
    frnums = list(range(N))
    for n in bones:
        pb = obj.pose.bones[n]
        for i in range(4):
            fc = a.fcurve_ensure_for_datablock(obj, pb.path_from_id('rotation_quaternion'), index=i)
            fc.keyframe_points.add(N)
            co = [0.0] * (2 * N)
            for j in range(N):
                co[2 * j] = j; co[2 * j + 1] = frames[j][n][0][i]
            fc.keyframe_points.foreach_set('co', co)
            fc.keyframe_points.foreach_set('interpolation', [1] * N)
            fc.update()
        if n in ('hips', 'body'):
            for i in range(3):
                fc = a.fcurve_ensure_for_datablock(obj, pb.path_from_id('location'), index=i)
                fc.keyframe_points.add(N)
                co = [0.0] * (2 * N)
                for j in range(N):
                    co[2 * j] = j; co[2 * j + 1] = frames[j][n][1][i]
                fc.keyframe_points.foreach_set('co', co)
                fc.keyframe_points.foreach_set('interpolation', [1] * N)
                fc.update()
    return a

BAKED = {}
for nm in NAMES:
    BAKED[nm] = retarget(nm)
    write(PR, 'P_' + nm, BAKED[nm], ALL_T)
print('baked', {k: len(v) for k, v in BAKED.items()})

# ------------------------------------------------------------------ skinning
CAPS = [n for n in ALL_T if n not in ('root', 'mane', 'beard', 'cape.1', 'cape.2', 'handslot.l', 'handslot.r', 'toes.l', 'toes.r', 'foot.r')]
SEG = {n: (t_rest[n].to_translation(), t_rest[n].to_translation() + t_q0[n] @ V((0, tb[n].length, 0))) for n in CAPS}
RAD = {'hips': .24, 'spine': .26, 'chest': .28, 'head': .1, 'upperarm.l': .12, 'lowerarm.l': .1, 'wrist.l': .1, 'hand.l': .1, 'upperarm.r': .11, 'lowerarm.r': .08, 'wrist.r': .06, 'hand.r': .05, 'upperleg.l': .13, 'lowerleg.l': .09, 'foot.l': .08, 'upperleg.r': .1, 'lowerleg.r': .06}
def seg_d(p, a, b):
    ab = b - a; t = max(0, min(1, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length
def nearest(p, names=CAPS, rad=False):
    return min(names, key=lambda n: seg_d(p, *SEG[n]) - (RAD[n] if rad else 0))
def soft(p, names=CAPS, power=5, top=3):
    ds = sorted(((max(seg_d(p, *SEG[n]) - RAD[n], .012), n) for n in names))[:top]
    ws = [(1 / d ** power, n) for d, n in ds]
    tot = sum(w for w, _ in ws)
    return [(w / tot, n) for w, n in ws]

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

def gattr(me):
    ca = me.color_attributes.get('g')
    if not ca: return None
    return [d.color[0] for d in ca.data]

LEGS = ('upperleg.l', 'lowerleg.l', 'foot.l', 'upperleg.r', 'lowerleg.r')
ARM_L = ('upperarm.l', 'lowerarm.l', 'wrist.l', 'hand.l'); ARM_R = ('upperarm.r', 'lowerarm.r', 'wrist.r', 'hand.r')
def skin(o):
    me = o.data; name = o.name; G = gattr(me)
    weights = [[] for _ in me.vertices]
    co = [v.co.copy() for v in me.vertices]
    if name == 'skin':
        for i, p in enumerate(co):
            names = [n for n in CAPS if n not in LEGS and n != 'foot.l' and not n.endswith('.l')] + ['chest']
            weights[i] = soft(p, tuple(set(names)), power=4)
    elif name in ('head', 'socket', 'eye_white', 'eye_blue', 'pupil', 'teeth'):
        weights = [[(1, 'head')] for _ in co]
    elif name == 'trousers':
        for i, p in enumerate(co): weights[i] = soft(p, ('hips', 'upperleg.l', 'lowerleg.l'), power=5, top=2)
    else:
        for isl in islands(me):
            pts = [co[i] for i in isl]
            c = sum(pts, V()) / len(pts)
            lo = V((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = V((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            ext = (hi - lo).length
            if name == 'hair':
                near = (c - H).length
                if ext < .36 and near < .3:
                    for i in isl: weights[i] = [(1, 'head')]
                else:
                    extra = 'beard' if (c.y < H.y + .09 and c.z < H.z - .1) else 'mane'
                    for i in isl:
                        g_ = G[i] if G else .5
                        weights[i] = [(max(g_, .001), 'head'), (max(1 - g_, .001), extra)]
                continue
            if name == 'cloth' and c.y > .2 and c.z > .7:
                for i in isl:
                    g_ = G[i]
                    a_, b_ = max(0, (g_ - .55) * 2.2), max(0, (.45 - g_) * 2.2)
                    weights[i] = [(max(a_, .001), 'chest'), (max(1 - a_ - b_, .001), 'cape.1'), (max(b_, .001), 'cape.2')]
                continue
            if name == 'cloth':
                for i in isl: weights[i] = [(1, 'hips')]
                continue
            if (c - J['SC']).length < .3 and name in ('iron', 'bronze', 'bone'):
                for i in isl: weights[i] = [(.5, 'chest'), (.5, 'upperarm.r')]
                continue
            if name in ('leather', 'iron', 'bronze') and .68 < c.z < .97 and abs(c.x) < .38 and hi.z < 1.02:
                for i in isl: weights[i] = [(1, 'hips')]
                continue
            limit = {'ice': ('upperleg.r', 'lowerleg.r')}.get(name)
            if name.startswith(('fire', 'wind')) or name == 'lava' and (c - H).length > .3:
                limit = ARM_L if c.x > 0 else ARM_R
            if name.startswith('bolt'): limit = ARM_R
            names = limit or CAPS
            if ext > .3:
                for i in isl: weights[i] = soft(co[i], names, power=5, top=2)
            else:
                b_ = nearest(c, names)
                for i in isl: weights[i] = [(1, b_)]
    vg = {}
    for i, ws in enumerate(weights):
        tot = sum(w for w, _ in ws) or 1
        for w, n in ws:
            g = vg.get(n) or o.vertex_groups.new(name=n); vg[n] = g
            g.add([i], w / tot, 'REPLACE')
    mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = PR
    while o.modifiers[0].name != 'Skin':
        bpy.ops.object.modifier_move_up({'object': o}, modifier='Skin') if False else o.modifiers.move(o.modifiers.find('Skin'), 0)
    o.parent = PR

SPIRIT = ('spirit', 'spirit_eyes')
print('skin mesh repaired:', scn.objects['skin'].data.validate(verbose=False))
SKIP = ('floor', 'floor_stones', 'ground_shadow') + SPIRIT
for o in list(scn.objects):
    if o.type == 'MESH' and o.name not in SKIP:
        skin(o)
    if o.name == 'ground_shadow': o.parent = PR
# smooth the skin weights across the mesh so shoulders and hips bend instead of creasing
o = scn.objects['skin']; me = o.data
nb = [[] for _ in me.vertices]
for e in me.edges:
    nb[e.vertices[0]].append(e.vertices[1]); nb[e.vertices[1]].append(e.vertices[0])
names = {g.index: g.name for g in o.vertex_groups}
W_ = [{names[g.group]: g.weight for g in v.groups} for v in me.vertices]
for _ in range(5):
    N_ = []
    for i, w in enumerate(W_):
        d = dict(w)
        for j in nb[i]:
            for k_, x in W_[j].items():
                d[k_] = d.get(k_, 0) + x * .6 / max(len(nb[i]), 1)
        t_ = sum(d.values())
        N_.append({k_: x / t_ for k_, x in d.items()})
    W_ = N_
for g in o.vertex_groups: g.remove(list(range(len(me.vertices))))
for i, w in enumerate(W_):
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    t_ = sum(x for _, x in top)
    for k_, x in top:
        o.vertex_groups[k_].add([i], x / t_, 'REPLACE')

# ------------------------------------------------------------------ the showcase: idle, run, attack chain, dodge, run, idle
SEQ = [('Idle', 54, 0, 0), ('Running_A', 24, 3.3, 2.0), ('Running_A', 34, 3.3, 0), ('Running_A', 30, 3.3, -2.2), ('2H_Melee_Attack_Chop', None, 0, 0), ('Dualwield_Melee_Attack_Slice', None, 0, 0), ('2H_Melee_Attack_Spin', None, 0, 0), ('2H_Melee_Idle', 18, 0, 0), ('Running_A', 24, 3.3, -2.0), ('Running_A', 30, 3.3, 0), ('Running_A', 26, 3.3, 2.2), ('Dodge_Forward', None, 5.5, 0), ('1H_Melee_Attack_Chop', None, 0, 0), ('Idle', 72, 0, 0)]
BLEND = 5
show = []; root = []
pos = V((0, 0, 0)); yaw = 0.0; speed = 0.0; turn = 0.0; last_nm = None; phase = 0
for nm, length, sp, tr in SEQ:
    n_src = len(BAKED[nm])
    length = length or n_src
    same = nm == last_nm
    if not same: phase = 0
    last_nm = nm
    for i in range(length):
        src = BAKED[nm]
        f = phase % max(n_src - 1, 1) if nm in ('Idle', 'Running_A', '2H_Melee_Idle') else min(phase, n_src - 1)
        phase += 1
        cur = {b: (q.copy(), l.copy()) for b, (q, l) in src[f].items()}
        if show and i < BLEND and not same:
            k = (i + 1) / (BLEND + 1); k = k * k * (3 - 2 * k)
            prev = show[-1]
            for b in cur:
                cur[b] = (prev[b][0].slerp(cur[b][0], k), prev[b][1].lerp(cur[b][1], k))
        show.append(cur)
        speed += (sp - speed) * .16; turn += (tr - turn) * .1
        yaw += turn / FPS
        if nm != 'Running_A':
            yaw += ((-yaw + math.pi) % (2 * math.pi) - math.pi) * .14
        pos = pos + V((math.sin(yaw), -math.cos(yaw), 0)) * speed / FPS
        root.append((pos.copy(), yaw))
LEN = len(show)
act = write(PR, 'P_Showcase', show, ALL_T)
for i in range(3):
    fc = act.fcurve_ensure_for_datablock(PR, 'location', index=i)
    fc.keyframe_points.add(LEN); co = [0.0] * (2 * LEN)
    for j in range(LEN): co[2 * j] = j; co[2 * j + 1] = root[j][0][i]
    fc.keyframe_points.foreach_set('co', co); fc.keyframe_points.foreach_set('interpolation', [1] * LEN); fc.update()
fc = act.fcurve_ensure_for_datablock(PR, 'rotation_euler', index=2)
fc.keyframe_points.add(LEN); co = [0.0] * (2 * LEN)
for j in range(LEN): co[2 * j] = j; co[2 * j + 1] = root[j][1]
fc.keyframe_points.foreach_set('co', co); fc.keyframe_points.foreach_set('interpolation', [1] * LEN); fc.update()
scn.frame_start = 0; scn.frame_end = LEN - 1; scn.render.fps = FPS

# world chest height per frame = hips motion + hero body; good enough for the spirit's anchor
def hero_anchor(i):
    p, y = root[i]
    Ry = Q((0, 0, 1), y)
    return p + V((0, 0, 1.1)), Ry

# ------------------------------------------------------------------ the spirit: spring-driven body, verlet rope tail
g = J['g']
TAIL = [g + V(d) for d in ((.02, .05, -.05), (-.06, .1, -.13), (-.17, .12, -.14), (-.24, .12, -.04), (-.2, .14, .07), (-.1, .16, .1), (-.06, .19, .03))]
sarm = bpy.data.armatures.new('SpiritRig'); SR = bpy.data.objects.new('SpiritRig', sarm); scn.collection.objects.link(SR)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = SR; SR.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = sarm.edit_bones.new('body'); eb.head = g; eb.tail = g + V((0, 0, .12))
prev = eb
for i in range(len(TAIL) - 1):
    e = sarm.edit_bones.new('tail.%d' % i); e.head = TAIL[i]; e.tail = TAIL[i + 1]; e.parent = prev; prev = e
    if i == 0: e.inherit_scale = 'NONE'
bpy.ops.object.mode_set(mode='OBJECT')
sb_ = sarm.bones
srest = {b.name: b.matrix_local.copy() for b in sb_}
sq0 = {n: m.to_quaternion() for n, m in srest.items()}
for pb in SR.pose.bones: pb.rotation_mode = 'QUATERNION'
sp_bones = [b.name for b in sb_]
for name in SPIRIT:
    o = scn.objects[name]; me = o.data
    tail_names = ['tail.%d' % i for i in range(len(TAIL) - 1)]
    segs = {n: (srest[n].to_translation(), srest[n].to_translation() + sq0[n] @ V((0, sb_[n].length, 0))) for n in tail_names}
    vg = {}
    def put(i, ws):
        tot = sum(w for w, _ in ws)
        for w, n in ws:
            gr = vg.get(n) or o.vertex_groups.new(name=n); vg[n] = gr
            gr.add([i], w / tot, 'REPLACE')
    if name == 'spirit_eyes':
        for i in range(len(me.vertices)): put(i, [(1, 'body')])
    else:
        for isl in islands(me):
            c = sum((me.vertices[i].co for i in isl), V()) / len(isl)
            if (c - g).length < .13:
                for i in isl: put(i, [(1, 'body')])
            else:
                for i in isl:
                    p = me.vertices[i].co
                    ds = sorted((max(seg_d(p, *segs[n]), .006), n) for n in tail_names)[:2]
                    put(i, [(1 / d ** 3, n) for d, n in ds])
    mod = o.modifiers.new('Skin', 'ARMATURE'); mod.object = SR
    o.modifiers.move(o.modifiers.find('Skin'), 0)
    o.parent = SR

OMEGA, ZETA = 6.5, .72
SUB = 4; dt = 1 / FPS / SUB
OFFSET = V((-.88, -.02, .58))
r = random.Random(3)
a0, R0 = hero_anchor(0)
p = a0 + R0 @ OFFSET; v = V()
body_yaw = 0.0; tilt_x = tilt_y = 0.0
rest_nodes = [t - g for t in TAIL]
nodes = [p + d for d in rest_nodes]; nv = [V() for _ in TAIL]
seglen = [(TAIL[i + 1] - TAIL[i]).length for i in range(len(TAIL) - 1)]
sp_frames = []
for i in range(-48, LEN):
    fi = max(i, 0)
    anc, Ry = hero_anchor(fi)
    t = i / FPS
    hover = V((math.sin(t * 1.3) * .05, math.sin(t * .9 + 1) * .05, math.sin(t * 2.1) * .05))
    target = anc + Ry @ (OFFSET + hover)
    moving = (root[min(fi + 1, LEN - 1)][0] - root[fi][0]).length * FPS
    still = max(0, 1 - moving / 1.5)
    omega = OMEGA * (1 + .5 * still) * (1 + .35 * min(1, (target - p).length / 1.5))
    for _ in range(SUB):
        a = (target - p) * omega * omega - v * (2 * ZETA * omega)
        v += a * dt; p += v * dt
    spd = v.length
    # face where it's going when moving, otherwise look where he's looking
    hv = V((v.x, v.y, 0))
    desired = math.atan2(hv.x, -hv.y) if hv.length > .55 else root[fi][1]
    d_ = (desired - body_yaw + math.pi) % (2 * math.pi) - math.pi
    body_yaw += d_ * .14
    Rz = Q((0, 0, 1), body_yaw)
    local_v = Rz.inverted() @ v
    tilt_x += (max(-.5, min(.5, -local_v.y * -.12)) - tilt_x) * .2
    tilt_y += (max(-.4, min(.4, local_v.x * .12)) - tilt_y) * .2
    Rb = Rz @ Q((1, 0, 0), tilt_x) @ Q((0, 1, 0), tilt_y)
    # rope: goal shape is the rest curl; tip is looser than the root, so it streams, then settles back
    nodes[0] = p + Rb @ rest_nodes[0]; nv[0] = V()
    for _ in range(SUB):
        for k in range(1, len(nodes)):
            stiff = 42 * (1 - k / len(nodes)) ** 1.2 + 5
            goal = p + Rb @ rest_nodes[k] + V((0, 0, math.sin(t * 3 + k * .9) * .012))
            nv[k] += ((goal - nodes[k]) * stiff - nv[k] * 3.4) * dt
            nodes[k] += nv[k] * dt
        for _ in range(3):
            for k in range(len(seglen)):
                d = nodes[k + 1] - nodes[k]
                if d.length < 1e-6: continue
                nodes[k + 1] = nodes[k] + d.normalized() * seglen[k]
    if i < 0: continue
    W = {'body': Rb @ sq0['body']}
    pose = {'body': ((sq0['body'].inverted() @ W['body']).normalized(), sq0['body'].inverted() @ (p - g))}
    prev_n = 'body'
    for k in range(len(TAIL) - 1):
        n = 'tail.%d' % k
        W[n] = rot_to(sq0[n], nodes[k + 1] - nodes[k])
        pose[n] = ((sq0[n].inverted() @ sq0[prev_n] @ W[prev_n].inverted() @ W[n]).normalized(), V())
        prev_n = n
    sp_frames.append(pose)
write(SR, 'S_Follow', sp_frames, sp_bones)
SR.lock_location = SR.lock_rotation = SR.lock_scale = (True, True, True)
pm = SR.pose.bones['body']
for pb in SR.pose.bones: pb.rotation_mode = 'QUATERNION'

# ------------------------------------------------------------------ flipbooks, stripe pulse, follow camera
for base, step in (('fire', 2), ('bolt', 2)):
    for k in range(3):
        o = scn.objects['%s%d' % (base, k)]
        o.animation_data_clear()
        for f in range(0, LEN + step, step):
            vis = ((f // step) % 3) == k
            for attr in ('hide_viewport', 'hide_render'):
                setattr(o, attr, not vis)
                o.keyframe_insert(attr, frame=f)
        o.animation_data.action.use_fake_user = True
        o.animation_data.action.name = 'FX_POC_' + o.name
m = bpy.data.materials['P_Skin']
node = m.node_tree.nodes['StripePulse']
drv = node.outputs[0].driver_add('default_value').driver
drv.type = 'SCRIPTED'; drv.expression = '.11+.07*sin(frame*.14)'

for name in ('CamShow',):
    o = bpy.data.objects.get(name)
    if o: bpy.data.objects.remove(o)
cd = bpy.data.cameras.new('CamShow'); cd.lens = 42
CS = bpy.data.objects.new('CamShow', cd); scn.collection.objects.link(CS)
cp = root[0][0].copy()
ad = CS.animation_data_create(); ca = bpy.data.actions.new('CamShow'); ad.action = ca
fcs = [ca.fcurve_ensure_for_datablock(CS, 'location', index=i) for i in range(3)] + [ca.fcurve_ensure_for_datablock(CS, 'rotation_euler', index=i) for i in range(3)]
for fc in fcs: fc.keyframe_points.add(LEN)
for j in range(LEN):
    cp = cp.lerp(root[j][0], .16)
    loc = cp + V((.2, -6.6, 4.0)); tgt = cp + V((0, 0, .95))
    e = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    for i in range(3):
        fcs[i].keyframe_points[j].co = (j, loc[i]); fcs[i].keyframe_points[j].interpolation = 'LINEAR'
        fcs[3 + i].keyframe_points[j].co = (j, e[i]); fcs[3 + i].keyframe_points[j].interpolation = 'LINEAR'
for fc in fcs: fc.update()
scn.camera = CS
scn.render.resolution_x, scn.render.resolution_y = 1280, 720
bpy.context.view_layer.update()
print('frames', LEN, 'path end', root[-1][0], 'tris report done')
