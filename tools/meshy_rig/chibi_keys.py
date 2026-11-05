# Hand-keyed signature clips for the chibi heretic, written over the clips heretic_bake.py copied
# from the shaman, then the GLB exported again (same bones, weapons and clip names).
#   blender -b <heretic_chibi_baked.blend> -P chibi_keys.py -- <out.glb> [sheet_dir]
# The baked blend is the one heretic_bake.py saves beside its GLB (<out>_baked.blend).
#
# How a clip is written: KEYS lists its extremes (frame, pose, ease to the next). Drawings fall every
# STEP frames plus on every extreme, each drawing is the eased mix of the extremes round it, and it is
# held until the next drawing: animation on twos at the game's play speed (anim_speed 1.7 for
# attacks, 1.1 for stances). A pose gives where things go, not bone angles:
#   hip (right, fwd, up) m and hipr (yaw, pitch, roll) deg; spine/chest/neck/head (yaw, pitch, roll)
#   deg, each on top of its parent; hsq head squash (+ wide and short, - tall and thin)
#   rh (az, el, r): right hand from its shoulder, az 0 = ahead, +90 = his right, el + up, r m
#   w (az, el): where the weapon (or, bare, the claw) points; f (az, el): the axe's edge facing
#   lh (az, el, r): left fist from its shoulder; fl/fr (right, fwd, up) m: feet from their rest
#   claw -1 (splayed) .. 1 (clenched); clawph: a wave across the six claws (deg)
# Contact: the game finds a clip's contact as the last frame its hand.r moves at 40% of its peak
# speed (tests/contact_frames.gd). Every clip here is checked against CONTACT before export.
import bpy, sys, os, json, struct, math
from mathutils import Vector, Matrix, Quaternion

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else ""
STEP_ATTACK = 4  # frames per drawing at 30 fps for clips played at 1.7: 12.75 drawings a second
STEP_STANCE = 3  # at 1.1: 11 a second
# From the game camera (54 degrees down) up-and-down barely reads, so a squash also widens the hood
# past volume (x this per unit of squash) and the runs sway sideways over the planted foot.
HSQ_WIDE = 0.6
COPIED_STEP = 6  # frames per claw drawing on the clips still copied from the shaman (claws only)
RUN_SWAY = -0.05  # m the hips shift sideways per footfall, over the planted foot (- his left on the left foot)
RUN_ROLL = -10.0  # degrees of roll per footfall, leaning over the planted foot

arm = bpy.data.objects["Armature"]
# chibi_presence.py scales the armature object (the glTF node carries it): every pose here is in armature
# space, so a distance that must hold on the floor (the run's ground speed) is divided by it.
WORLD_K = arm.matrix_world.to_scale().x
AW_INV = arm.matrix_world.inverted()
# m each foot sits further out from its rest in every keyed pose (armature space): a wider, planted stance
STANCE_W = 0.05
BONES = arm.data.bones
R = {b.name: b.matrix_local.copy() for b in BONES}
RQ = {k: v.to_quaternion() for k, v in R.items()}
PAR = {b.name: (b.parent.name if b.parent else None) for b in BONES}
LOC = {b: (R[PAR[b]].inverted() @ R[b]) if PAR[b] else R[b].copy() for b in R}  # rest, parent space
FWD, RIGHT, UP = Vector((0, -1, 0)), Vector((-1, 0, 0)), Vector((0, 0, 1))
TIPS = ["main", "up", "out", "mid", "low", "back"]
CHAINS = {t: sorted([b.name for b in BONES if b.name.startswith("tent.%s." % t)]) for t in TIPS}


def dirv(az, el):
    a, e = math.radians(az), math.radians(el)
    return ((FWD * math.cos(a) + RIGHT * math.sin(a)) * math.cos(e) + UP * math.sin(e)).normalized()


def wrot(ypr):
    """World-delta rotation: yaw + turns his front to his right, pitch + leans forward, roll + to his right."""
    y, p, r = (math.radians(x) for x in ypr)
    return Quaternion(UP, -y) @ Quaternion(Vector((1, 0, 0)), p) @ Quaternion(Vector((0, 1, 0)), -r)


def head_of(b):
    return R[b].translation.copy()


# ---- weapon and claw rest vectors (rest, armature space)
HAND_HEAD = head_of("hand.r")


def ydir(b):
    return (R[b].to_3x3() @ Vector((0, 1, 0))).normalized()


def mesh_centroid(name):
    o = bpy.data.objects.get(name)
    vs = [AW_INV @ o.matrix_world @ v.co for v in o.data.vertices]
    return sum(vs, Vector()) / len(vs)


def perp(v, axis):
    return (v - axis * v.dot(axis)).normalized()


CLAW_DIR = sum((head_of(CHAINS[t][1]) - HAND_HEAD for t in TIPS if len(CHAINS[t]) > 1), Vector()).normalized()
W0 = {"axe": ydir("weapon.axe"), "spear": ydir("weapon.spear"), "hammer": ydir("weapon.hammer"), "hand": CLAW_DIR}
F0 = {"axe": perp(mesh_centroid("axe_void_blade") - HAND_HEAD, ydir("weapon.axe")),
      "hammer": perp(mesh_centroid("hammer_void_head") - HAND_HEAD, ydir("weapon.hammer")),
      "spear": perp(UP, ydir("weapon.spear")), "hand": perp(ydir("hand.r").cross(CLAW_DIR) if False else UP, CLAW_DIR)}


def basis(w, f):
    w = w.normalized(); f = perp(f, w)
    return Matrix((w, f, w.cross(f))).transposed().to_quaternion()


# curl axis per claw bone: rotating about it by + bends the bone in towards the claw's middle line
CURL = {}
for t in TIPS:
    for b in CHAINS[t]:
        d = ydir(b)
        h = head_of(b)
        p0 = HAND_HEAD + CLAW_DIR * (h - HAND_HEAD).dot(CLAW_DIR)
        n = perp(p0 - h, d) if (p0 - h).length > 1e-4 else perp(UP, d)
        if t == "main":  # the main claw runs along the middle: curl it down, under the palm
            n = perp(-UP, d)
        k = d.cross(n).normalized()
        CURL[b] = RQ[b].inverted() @ k
CLENCH_DEG, SPLAY_DEG = 34.0, 24.0

# ---- the solver: a pose -> each bone's global matrix (rest frames carried), then the bone's basis
GUARD = {}  # set below
ARM_R = ["shoulder.r", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r"]


def carried(G, b, local=Quaternion()):
    p = PAR[b]
    return G[p] @ LOC[b] @ local.to_matrix().to_4x4()


def with_rot(M, q):
    out = q.to_matrix().to_4x4()
    out.translation = M.translation
    return out


def ik2(S, T, a, c, pole):
    d = min(max((T - S).length, abs(a - c) + 1e-3), a + c - 1e-3)
    n = (T - S).normalized()
    x = (a * a - c * c + d * d) / (2 * d)
    h = math.sqrt(max(a * a - x * x, 0.0))
    m = perp(pole, n)
    return S + n * x + m * h, S + n * d


def aim_bone(G, b, child_head_rest, target):
    """b's global rotation so the vector from its head to child_head_rest (rest) points at target."""
    M = carried(G, b)
    v0 = child_head_rest - head_of(b)
    cur = M.to_quaternion() @ RQ[b].inverted() @ v0
    q = cur.rotation_difference(target - M.translation) @ M.to_quaternion()
    G[b] = with_rot(M, q)


LEG_MISS = [0.0]  # m: the worst foot target the legs couldn't reach, per clip


def solve(P, form):
    G = {}
    G["root"] = R["root"].copy()
    hip = P["hip"]
    Wh = wrot(P["hipr"])
    G["hips"] = with_rot(Matrix.Translation(head_of("hips") + RIGHT * hip[0] + FWD * hip[1] + UP * hip[2]), Wh @ RQ["hips"])
    W = {"hips": Wh}
    for b, src in (("spine", "spine"), ("chest", "chest"), ("neck", "neck"), ("head", "head")):
        W[b] = W[PAR[b]] @ wrot(P[src])
        G[b] = with_rot(carried(G, b), W[b] @ RQ[b])
    for s in "lr":
        G["shoulder." + s] = with_rot(carried(G, "shoulder." + s), W["chest"] @ RQ["shoulder." + s])
    # right arm: two bones to the hand, the hand turned to the weapon
    S = carried(G, "upperarm.r").translation
    az, el, r = P["rh"]
    T = S + dirv(az, el) * r
    a = (head_of("lowerarm.r") - head_of("upperarm.r")).length
    c = (HAND_HEAD - head_of("lowerarm.r")).length
    E, T = ik2(S, T, a, c, dirv(*P["rpole"]))
    aim_bone(G, "upperarm.r", head_of("lowerarm.r"), E)
    aim_bone(G, "lowerarm.r", HAND_HEAD, T)
    G["wrist.r"] = carried(G, "wrist.r")
    w = dirv(*P["w"])
    if P.get("f") is not None:
        q = basis(w, dirv(*P["f"])) @ basis(W0[form], F0[form]).inverted() @ RQ["hand.r"]
    else:
        base = W["chest"] @ RQ["hand.r"]
        w_now = W["chest"] @ W0[form]
        q = w_now.rotation_difference(w) @ base
    G["hand.r"] = with_rot(carried(G, "hand.r"), q)
    G["handslot.r"] = carried(G, "handslot.r")
    # left arm
    S = carried(G, "upperarm.l").translation
    az, el, r = P["lh"]
    T = S + dirv(az, el) * r
    a = (head_of("lowerarm.l") - head_of("upperarm.l")).length
    c = (head_of("hand.l") - head_of("lowerarm.l")).length
    E, T = ik2(S, T, a, c, dirv(*P["lpole"]))
    aim_bone(G, "upperarm.l", head_of("lowerarm.l"), E)
    aim_bone(G, "lowerarm.l", head_of("hand.l"), T)
    for b in ("wrist.l", "hand.l", "handslot.l"):
        G[b] = carried(G, b)
    # legs: feet where the pose puts them, flat, knees forward and out
    for s, key, out in (("l", "fl", -1.0), ("r", "fr", 1.0)):
        off = P[key]
        T = head_of("foot." + s) + RIGHT * (off[0] + out * STANCE_W) + FWD * off[1] + UP * off[2]
        S = carried(G, "upperleg." + s).translation
        a = (head_of("lowerleg." + s) - head_of("upperleg." + s)).length
        c = (head_of("foot." + s) - head_of("lowerleg." + s)).length
        pole = (FWD + RIGHT * 0.25 * out + UP * 0.1)
        T0 = T
        E, T = ik2(S, T, a, c, pole)
        LEG_MISS[0] = max(LEG_MISS[0], (T0 - T).length)
        aim_bone(G, "upperleg." + s, head_of("lowerleg." + s), E)
        aim_bone(G, "lowerleg." + s, head_of("foot." + s), T)
        yaw = P.get(key + "r") or (0, 0, 0)
        G["foot." + s] = with_rot(carried(G, "foot." + s), wrot(yaw) @ RQ["foot." + s])
        G["toes." + s] = carried(G, "toes." + s)
    return G


ORDER = ["root", "hips", "spine", "chest", "neck", "head", "shoulder.l", "upperarm.l", "lowerarm.l", "wrist.l",
         "hand.l", "handslot.l", "shoulder.r", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r",
         "upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]


def bases(G):
    out = {}
    for b in ORDER:
        par = G[PAR[b]] if PAR[b] else Matrix.Identity(4)
        B = LOC[b].inverted() @ par.inverted() @ G[b]
        out[b] = (B.to_quaternion(), B.translation.copy())
    return out


def claw_rots(P):
    c = P["claw"]
    ph = P.get("clawph", 0.0)
    out = {}
    for i, t in enumerate(TIPS):
        wave = math.sin(math.radians(ph) + i * 1.3) * 0.25 if ph else 0.0
        v = max(-1.0, min(1.0, c + wave))
        for j, b in enumerate(CHAINS[t]):
            deg = v * CLENCH_DEG if v > 0 else v * SPLAY_DEG * (1.6 if j == 0 else 1.0)
            if t == "main":
                deg *= 0.6
            out[b] = Quaternion(CURL[b], math.radians(deg))
    return out


# ---- poses
def pose(base, **kw):
    p = dict(base)
    p.update(kw)
    return p


NEUTRAL = {"hip": (0, 0, -0.04), "hipr": (0, 0, 0), "spine": (0, 0, 0), "chest": (0, 6, 0), "neck": (0, 0, 0),
           "head": (0, 4, 0), "hsq": 0.0, "rh": (30, -12, 0.5), "rpole": (80, -60), "w": (25, 15), "f": None,
           "lh": (-45, -55, 0.36), "lpole": (-120, -20), "fl": (-0.03, 0.02, 0), "fr": (0.03, -0.04, 0),
           "claw": 0.3, "clawph": 0.0, "hs": 1.0}
# guard with the claw up and forward, half open: Idle_Ready, and where the claw moves start and end
GUARD = pose(NEUTRAL, hip=(0, 0.0, -0.07), chest=(8, 10, 0), head=(-6, 6, 0), rh=(25, -5, 0.52), w=(15, 25),
             lh=(-35, -35, 0.36), fl=(-0.05, 0.06, 0), fr=(0.05, -0.07, 0), claw=0.0)


def mixv(a, b, t):
    if a is None or b is None:
        return b if t >= 0.5 else a
    if isinstance(a, (int, float)):
        return a + (b - a) * t
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mixp(a, b, t):
    return {k: mixv(a.get(k), b.get(k), t) for k in set(a) | set(b)}


EASES = {"lin": lambda t: t, "in": lambda t: t * t, "out": lambda t: 1 - (1 - t) ** 2,
         "io": lambda t: t * t * (3 - 2 * t), "hold": lambda t: 0.0, "snap": lambda t: 1.0 if t > 0 else 0.0}


def drawings(keys, n, step):
    """[(frame, pose)] for every frame 1..n: drawings every `step` frames and on each key, held between."""
    marks = sorted(set(list(range(1, n + 1, step)) + [k[0] for k in keys if k[0] <= n]))
    out = []
    for f in range(1, n + 1):
        d = max(m for m in marks if m <= f)
        i = max(j for j in range(len(keys)) if keys[j][0] <= d)
        if i + 1 < len(keys):
            f0, p0, ease = keys[i]
            f1, p1 = keys[i + 1][0], keys[i + 1][1]
            t = EASES[ease]((d - f0) / float(f1 - f0))
            out.append(mixp(p0, p1, t))
        else:
            out.append(keys[i][1])
    return out


# ---------------------------------------------------------------- the clips
# Each: frames, form, step, contact frame (None: not checked), keys [(frame, pose, ease to next)].
CLIPS = {}

# L1: axe slice, a flat arc from behind his right shoulder across the front to his left. hs swells
# the claw and the axe in it on the smear.
AX = pose(GUARD, w=(55, 45), f=(-35, 0), rh=(45, -10, 0.5), claw=0.6)
L1_WIND = pose(AX, hip=(0.04, 0.05, -0.12), hipr=(30, 0, -4), chest=(28, -4, 0), head=(-30, 8, 0), hsq=0.14,
               rh=(115, 5, 0.47), w=(160, 12), f=(70, 0), lh=(-60, 0, 0.38), fl=(-0.07, 0.1, 0), fr=(0.06, -0.12, 0),
               claw=-0.6)
L1_DEEP = pose(L1_WIND, hipr=(36, 0, -5), chest=(32, -6, 0), rh=(125, 8, 0.46), w=(172, 15), f=(82, 0), hsq=0.18)
L1_SMEAR = pose(L1_WIND, hip=(0, -0.02, -0.08), hipr=(0, 8, 0), chest=(0, 8, 0), head=(-10, 6, 0), hsq=-0.1,
                rh=(45, -5, 0.58), w=(65, -2), f=(-25, 0), lh=(-90, -10, 0.38), claw=0.4, hs=1.2)
L1_HIT = pose(L1_SMEAR, hip=(-0.03, -0.05, -0.1), hipr=(-35, 14, 4), chest=(-25, 10, 3), head=(15, 8, 0), hsq=0.08,
              rh=(-25, -8, 0.58), w=(-45, -6), f=(-135, 0), lh=(-150, 10, 0.38), fl=(-0.08, 0.14, 0), fr=(0.08, -0.14, 0),
              claw=1.0, hs=1.1)
L1_OVER = pose(L1_HIT, hipr=(-42, 15, 4), chest=(-30, 10, 3), rh=(-38, -6, 0.57), w=(-60, -2), f=(-150, 0), hsq=0.04)
L1_SET = pose(L1_HIT, hipr=(-25, 8, 2), chest=(-18, 8, 0), rh=(-20, -5, 0.55), w=(-35, 15), f=(-120, 10), hsq=0.0,
              claw=0.8, hs=1.0)
L1_BACK = mixp(L1_SET, AX, 0.5)
CLIPS["Ab_L1"] = (31, "axe", STEP_ATTACK, 11, [
    (1, AX, "out"), (4, L1_WIND, "lin"), (8, L1_DEEP, "snap"), (9, L1_SMEAR, "snap"), (11, L1_HIT, "hold"),
    (16, L1_OVER, "io"), (19, L1_SET, "lin"), (23, L1_BACK, "lin"), (27, AX, "hold"), (31, AX, "hold")])
# AL1: the same cut in the air (Updraft Lash's follow-up), one frame shorter; legs tucked.
AIR = dict(fl=(-0.02, 0.1, 0.12), fr=(0.02, -0.06, 0.2))
CLIPS["Ab_AL1"] = (30, "axe", STEP_ATTACK, 11, [
    (1, pose(AX, **AIR), "out"), (4, pose(L1_WIND, **AIR), "lin"), (8, pose(L1_DEEP, **AIR), "snap"),
    (9, pose(L1_SMEAR, **AIR), "snap"), (11, pose(L1_HIT, **AIR), "hold"), (16, pose(L1_OVER, **AIR), "io"),
    (19, pose(L1_SET, **AIR), "lin"), (23, pose(L1_BACK, **AIR), "lin"), (27, pose(AX, **AIR), "hold"),
    (30, pose(AX, **AIR), "hold")])

# L2: spear thrust: coil right back with the spear cocked up and out, then punch it straight out,
# body lunging behind it.
SP = pose(GUARD, w=(10, 5), f=None, rh=(55, -15, 0.45), claw=0.7)
L2_COIL = pose(SP, hip=(0.03, 0.1, -0.13), hipr=(40, -6, 0), chest=(30, -8, 0), head=(-35, 4, 0), hsq=0.16,
               rh=(120, -15, 0.4), w=(35, 18), lh=(-20, 10, 0.39), fl=(-0.06, 0.16, 0), fr=(0.05, -0.1, 0), claw=-0.7)
L2_DEEP = pose(L2_COIL, hipr=(50, -8, 0), rh=(135, -12, 0.42), w=(40, 22), hsq=0.2)
L2_SMEAR = pose(L2_COIL, hip=(0, -0.05, -0.06), hipr=(10, 10, 0), chest=(5, 10, 0), head=(-8, 4, 0), hsq=-0.14,
                rh=(30, -5, 0.55), w=(8, 2), lh=(-60, -10, 0.38), claw=0.5, hs=1.15)
L2_HIT = pose(L2_SMEAR, hip=(-0.02, -0.12, -0.1), hipr=(-30, 22, 0), chest=(-20, 14, 0), head=(20, 4, 0), hsq=0.06,
              rh=(-5, -6, 0.6), w=(-5, -4), lh=(-150, 20, 0.38), fl=(-0.06, 0.22, 0), fr=(0.06, -0.26, 0), claw=1.0,
              hs=1.1)
L2_OVER = pose(L2_HIT, hip=(-0.02, -0.14, -0.11), hipr=(-34, 24, 0), rh=(-8, -8, 0.6), w=(-8, -7))
L2_SET = pose(L2_HIT, hip=(-0.01, -0.06, -0.08), hipr=(-18, 12, 0), chest=(-10, 10, 0), rh=(5, -8, 0.53), w=(0, 2),
              hsq=0.0, claw=0.8, hs=1.0)
CLIPS["Ab_L2"] = (33, "spear", STEP_ATTACK, 12, [
    (1, SP, "out"), (4, L2_COIL, "lin"), (9, L2_DEEP, "snap"), (10, L2_SMEAR, "snap"), (12, L2_HIT, "hold"),
    (17, L2_OVER, "io"), (21, L2_SET, "io"), (29, SP, "hold"), (33, SP, "hold")])

# L3: hammer overhead: rise up tall with it behind the head, then crash it down on the floor
# ahead, squashed flat.
HM = pose(GUARD, w=(40, 50), f=(0, 20), rh=(45, -5, 0.5), claw=0.7)
L3_LIFT = pose(HM, hip=(0, 0.05, -0.02), hipr=(25, -14, 0), chest=(15, -14, 0), head=(-15, -6, 0), hsq=-0.12,
               rh=(60, 60, 0.5), w=(150, 50), f=(170, -20), lh=(-60, 40, 0.39), fl=(-0.05, 0.08, 0), fr=(0.05, -0.1, 0),
               claw=-0.5)
L3_TOP = pose(L3_LIFT, hipr=(30, -18, 0), chest=(18, -16, 0), hsq=-0.16, rh=(80, 70, 0.48), w=(170, 35), f=(175, -40),
              lh=(-70, 50, 0.39), claw=-0.8)
L3_SMEAR = pose(L3_TOP, hip=(0, -0.05, -0.1), hipr=(5, 20, 0), chest=(0, 15, 0), head=(-5, 10, 0), hsq=0.0,
                rh=(10, 25, 0.58), w=(15, 30), f=(10, -60), lh=(-60, -10, 0.38), claw=0.4, hs=1.2)
L3_HIT = pose(L3_SMEAR, hip=(0, -0.1, -0.2), hipr=(-15, 34, 0), chest=(-8, 18, 0), head=(5, 10, 0), hsq=0.24,
              rh=(-5, -30, 0.58), w=(-8, -16), f=(-5, -106), lh=(-80, -50, 0.37), fl=(-0.1, 0.18, 0), fr=(0.1, -0.2, 0),
              claw=1.0, hs=1.1)
L3_OVER = pose(L3_HIT, hip=(0, -0.11, -0.22), hipr=(-18, 37, 0), hsq=0.28, rh=(-8, -32, 0.58), w=(-10, -17))
L3_SET = pose(L3_HIT, hip=(0, -0.06, -0.14), hipr=(-8, 22, 0), chest=(-4, 14, 0), hsq=0.06, rh=(10, -22, 0.55),
              w=(5, -5), claw=0.8, hs=1.0)
CLIPS["Ab_L3"] = (56, "hammer", STEP_ATTACK, 24, [
    (1, HM, "out"), (6, L3_LIFT, "out"), (14, L3_TOP, "hold"), (20, L3_TOP, "snap"), (21, L3_SMEAR, "snap"),
    (24, L3_HIT, "hold"), (30, L3_OVER, "io"), (36, L3_SET, "io"), (50, HM, "hold"), (56, HM, "hold")])

# DL: dash stab: a short crouch with the spear cocked up, a pounce, then stabbed down ahead with the
# whole body stretched after it.
DL_COIL = pose(SP, hip=(0, 0.06, -0.16), hipr=(15, 18, 0), chest=(10, 10, 0), head=(-10, -4, 0), hsq=0.18,
               rh=(90, -20, 0.4), w=(30, 25), lh=(-60, -30, 0.38), fl=(-0.05, 0.05, 0), fr=(0.05, 0.02, 0), claw=-0.6)
DL_LEAP = pose(DL_COIL, hip=(0, -0.06, 0.0), hipr=(5, 25, 0), chest=(5, 10, 0), head=(0, 0, 0), hsq=-0.16,
               rh=(100, 10, 0.4), w=(25, 40), lh=(-140, 30, 0.39), fl=(-0.03, 0.25, 0.1), fr=(0.03, -0.25, 0.05),
               claw=0.3, hs=1.15)
DL_HIT = pose(DL_LEAP, hip=(0, -0.12, -0.12), hipr=(-20, 35, 0), chest=(-10, 12, 0), head=(12, 0, 0), hsq=0.1,
              rh=(-5, -22, 0.6), w=(-4, -16), lh=(-160, 30, 0.39), fl=(-0.06, 0.28, 0), fr=(0.06, -0.3, 0), claw=1.0,
              hs=1.1)
DL_OVER = pose(DL_HIT, hip=(0, -0.13, -0.14), hipr=(-22, 38, 0), rh=(-6, -25, 0.6), w=(-6, -20), hsq=0.14)
DL_SET = pose(DL_HIT, hip=(0, -0.06, -0.1), hipr=(-10, 18, 0), chest=(-5, 10, 0), rh=(10, -15, 0.54), w=(0, -5),
              hsq=0.0, claw=0.8, hs=1.0)
CLIPS["Ab_DL"] = (61, "spear", STEP_ATTACK, 12, [
    (1, SP, "out"), (4, DL_COIL, "hold"), (8, DL_LEAP, "hold"), (12, DL_HIT, "hold"), (18, DL_OVER, "io"),
    (24, DL_SET, "lin"), (44, SP, "hold"), (61, SP, "hold")])

# GR: the grab: claw pulled back splayed wide, shot out at full reach and swollen, snapped shut on
# the hit (frame 7, 0.233 s: the game's hit is at 0.248 s), yanked home.
GR_BACK = pose(GUARD, hip=(0.02, 0.06, -0.1), hipr=(30, -4, 0), chest=(24, -6, 0), head=(-20, 2, 0), hsq=0.12,
               rh=(100, 5, 0.36), w=(70, 25), lh=(-40, -20, 0.38), claw=-1.0, clawph=60.0)
GR_SHOT = pose(GR_BACK, hip=(-0.02, -0.08, -0.08), hipr=(-20, 16, 0), chest=(-15, 12, 0), head=(10, 4, 0), hsq=-0.12,
               rh=(-5, 0, 0.6), w=(-5, 0), lh=(-140, 10, 0.39), fl=(-0.06, 0.18, 0), fr=(0.06, -0.2, 0), claw=-1.0,
               clawph=0.0, hs=1.45)
GR_SNAP = pose(GR_SHOT, hsq=0.06, rh=(-6, -2, 0.6), w=(-6, -4), claw=1.0, hs=1.3)
GR_YANK = pose(GR_SNAP, hip=(0.03, 0.06, -0.09), hipr=(35, -8, 0), chest=(25, -8, 0), head=(-20, 0, 0), hsq=0.1,
               rh=(80, 0, 0.4), w=(40, 10), lh=(-60, -10, 0.38), claw=1.0, hs=1.1)
GR_SET = pose(GUARD, claw=0.6, hipr=(15, 0, 0))
CLIPS["Ab_GR"] = (31, "hand", STEP_ATTACK, None, [
    (1, GUARD, "out"), (3, GR_BACK, "snap"), (5, GR_SHOT, "snap"), (7, GR_SNAP, "hold"), (12, GR_SNAP, "out"),
    (16, GR_YANK, "io"), (24, GR_SET, "io"), (31, GUARD, "hold")])

# VS: the slam: the caught foe heaved up over his head, the claw clenched and shaking, then
# smashed down ahead with the claws flung open (frame 17, 0.567 s: the game's hit is at 0.598 s).
VS_LIFT = pose(GUARD, hip=(0, 0.04, -0.0), hipr=(15, -12, 0), chest=(10, -14, 0), head=(-10, -10, 0), hsq=-0.14,
               rh=(40, 65, 0.55), w=(60, 80), lh=(-70, 30, 0.39), fl=(-0.06, 0.08, 0), fr=(0.06, -0.08, 0), claw=1.0,
               hs=1.2)
VS_TOP = pose(VS_LIFT, hipr=(22, -16, 0), chest=(14, -18, 0), rh=(70, 72, 0.52), w=(150, 70), hsq=-0.18)
VS_SHAKE = pose(VS_TOP, rh=(62, 70, 0.53), hipr=(18, -15, 2), head=(-6, -8, 3))
VS_SMEAR = pose(VS_TOP, hip=(0, -0.04, -0.1), hipr=(0, 18, 0), chest=(0, 14, 0), head=(0, 8, 0), hsq=0.0,
                rh=(10, 10, 0.6), w=(5, 0), claw=1.0)
VS_HIT = pose(VS_SMEAR, hip=(0, -0.1, -0.22), hipr=(-10, 36, 0), chest=(-5, 18, 0), head=(5, 12, 0), hsq=0.26,
              rh=(-5, -45, 0.6), w=(-5, -60), lh=(-90, -40, 0.38), fl=(-0.1, 0.16, 0), fr=(0.1, -0.18, 0), claw=-1.0,
              clawph=40.0, hs=1.4)
VS_OVER = pose(VS_HIT, hip=(0, -0.11, -0.24), hipr=(-12, 39, 0), hsq=0.3, rh=(-6, -48, 0.6))
VS_SET = pose(VS_HIT, hip=(0, -0.05, -0.14), hipr=(-5, 20, 0), chest=(0, 12, 0), hsq=0.06, rh=(15, -25, 0.55),
              w=(10, -20), claw=-0.4, clawph=0.0, hs=1.05)
CLIPS["Ab_VS"] = (46, "hand", STEP_ATTACK, None, [
    (1, GUARD, "out"), (5, VS_LIFT, "out"), (9, VS_TOP, "snap"), (11, VS_SHAKE, "snap"), (13, VS_TOP, "snap"),
    (15, VS_SMEAR, "snap"), (17, VS_HIT, "hold"), (23, VS_OVER, "io"), (29, VS_SET, "io"), (42, GUARD, "hold"), (46, GUARD, "hold")])




# Idle_Ready: re-keyed in the Locomotion block (ready_frames).




# ---- round 2: the void moves' clips and the rest of what the game plays on him.
# Contacts for clips outside HERO_MOVES: the move's own hit (MOVES `hits` x the clip's length) lands on
# the contact frame or just after it, so the hitstop freezes on the arrival (like GR and VS).

# Ab_LH, Updraft Lash (EC, hit 0.29 = frame 14.8; also IJ's vault): the claw dragged back low and
# splayed, raked along the floor under them, then heaved up overhead clenched as he hops after them.
LH_COIL = pose(GUARD, hip=(0.03, 0.06, -0.16), hipr=(35, 10, -4), chest=(25, 4, 0), head=(-25, 6, 0), hsq=0.2,
               rh=(135, -40, 0.5), w=(160, -35), lh=(-50, 10, 0.38), fl=(-0.08, 0.12, 0), fr=(0.07, -0.12, 0),
               claw=-0.8, clawph=50.0, hs=1.15)
LH_DEEP = pose(LH_COIL, hipr=(42, 12, -5), chest=(30, 5, 0), rh=(145, -42, 0.5), w=(170, -30), hsq=0.24)
LH_SMEAR = pose(LH_COIL, hip=(0, -0.04, -0.14), hipr=(5, 18, 0), chest=(0, 10, 0), head=(-5, 8, 0), hsq=-0.08,
                rh=(70, -45, 0.6), w=(75, -35), claw=-1.0, clawph=0.0, hs=1.45)
LH_HIT = pose(LH_SMEAR, hip=(-0.03, -0.07, -0.16), hipr=(-32, 20, 4), chest=(-24, 10, 2), head=(15, 8, 0), hsq=0.14,
              rh=(-5, -40, 0.6), w=(-15, -28), lh=(-150, 0, 0.38), fl=(-0.09, 0.15, 0), fr=(0.08, -0.15, 0), hs=1.45)
LH_SCOOP = pose(LH_HIT, hipr=(-26, 14, 2), hsq=0.06, rh=(-5, -28, 0.6), w=(-12, -12), claw=0.6)
LH_RISE = pose(LH_HIT, hip=(0, -0.02, 0.03), hipr=(-10, -8, 0), chest=(-5, -12, 0), head=(0, -10, 0), hsq=-0.22,
               rh=(-5, 55, 0.58), w=(-5, 80), lh=(-60, -50, 0.37), fl=(-0.03, 0.05, 0.1), fr=(0.03, -0.05, 0.16),
               claw=1.0, hs=1.3)
LH_TOP = pose(LH_RISE, hsq=-0.18, rh=(0, 60, 0.57), w=(0, 85), claw=-0.5, clawph=40.0, hs=1.2)
CLIPS["Ab_LH"] = (51, "hand", STEP_ATTACK, 14, [
    (1, GUARD, "out"), (4, LH_COIL, "lin"), (9, LH_DEEP, "hold"), (11, LH_SMEAR, "hold"), (14, LH_HIT, "hold"),
    (18, LH_SCOOP, "lin"), (33, LH_RISE, "hold"), (36, LH_TOP, "io"), (47, GUARD, "hold"), (51, GUARD, "hold")])

# Ab_H, Reap (VR, hit 0.24 = frame 15.1): the claw as a scythe: cocked high behind his right shoulder,
# splayed, raked in a flat crescent across the front to his left, swollen, then shut on the follow-through.
VR_WIND = pose(GUARD, hip=(0.04, 0.05, -0.1), hipr=(38, -4, -5), chest=(30, -6, 0), head=(-30, 6, 0), hsq=0.16,
               rh=(120, 25, 0.52), w=(150, 30), lh=(-60, 0, 0.38), fl=(-0.07, 0.1, 0), fr=(0.06, -0.12, 0),
               claw=-0.9, clawph=60.0, hs=1.15)
VR_DEEP = pose(VR_WIND, hipr=(45, -6, -6), chest=(34, -8, 0), rh=(130, 30, 0.5), w=(165, 30), hsq=0.2)
VR_SMEAR = pose(VR_WIND, hip=(0, -0.02, -0.08), hipr=(0, 10, 0), chest=(0, 8, 0), head=(-8, 6, 0), hsq=-0.12,
                rh=(40, 0, 0.6), w=(50, -5), claw=-1.0, clawph=0.0, hs=1.5)
VR_HIT = pose(VR_SMEAR, hip=(-0.03, -0.05, -0.1), hipr=(-40, 15, 4), chest=(-28, 10, 3), head=(18, 8, 0), hsq=0.12,
              rh=(-40, -10, 0.6), w=(-70, -10), lh=(-150, 10, 0.38), fl=(-0.08, 0.14, 0), fr=(0.08, -0.14, 0), hs=1.4)
VR_OVER = pose(VR_HIT, hipr=(-46, 16, 4), chest=(-32, 10, 3), rh=(-48, -8, 0.59), w=(-82, -8), hsq=0.08)
VR_SET = pose(VR_HIT, hipr=(-25, 8, 2), chest=(-18, 8, 0), rh=(-30, -5, 0.55), w=(-50, 10), hsq=0.0, claw=0.9, hs=1.1)
CLIPS["Ab_H"] = (63, "hand", STEP_ATTACK, 15, [
    (1, GUARD, "out"), (4, VR_WIND, "lin"), (11, VR_DEEP, "hold"), (13, VR_SMEAR, "hold"), (15, VR_HIT, "hold"),
    (21, VR_OVER, "io"), (27, VR_SET, "lin"), (35, mixp(VR_SET, GUARD, 0.5), "lin"), (44, GUARD, "hold"),
    (63, GUARD, "hold")])

# Ab_LLH, Harpoon (EF) and the Frost Spear plant (IP), hit 0.34 = frame 20.1: up on his toes with the
# spear raised high and turned tip-down, then lunged and driven into the floor ahead, held, leaning on it.
# Round 35 c: raised higher before the drive: the arm straight up over the hood (el 84, was 72), the
# spear swollen and turned less tip-down (-32, was -55: a steeper spear foreshortens to a stub from the game
# camera), up on his toes further.
LLH_RISE = pose(SP, hip=(0, 0.04, 0.04), hipr=(10, -10, 0), chest=(5, -12, 0), head=(-5, -8, 0), hsq=-0.14,
                rh=(35, 72, 0.55), w=(8, -40), lh=(-60, 40, 0.39), claw=0.9)
LLH_TOP = pose(LLH_RISE, hip=(0, 0.04, 0.06), hipr=(15, -14, 0), chest=(8, -15, 0), hsq=-0.18, rh=(30, 84, 0.6),
               w=(4, -32), fl=(-0.05, 0.04, 0.08), fr=(0.05, -0.05, 0.09), claw=1.0, hs=1.1)
LLH_SHAKE = pose(LLH_TOP, rh=(28, 81, 0.59), hipr=(13, -13, 2), head=(-3, -7, 3))
LLH_SMEAR = pose(LLH_TOP, hip=(0, -0.06, -0.08), hipr=(0, 18, 0), chest=(0, 12, 0), head=(0, 6, 0), hsq=0.0,
                 rh=(10, 20, 0.6), w=(5, -35), fl=(-0.06, 0.08, 0), fr=(0.06, -0.1, 0), hs=1.2)
LLH_HIT = pose(LLH_SMEAR, hip=(0, -0.14, -0.22), hipr=(-10, 34, 0), chest=(-5, 16, 0), head=(5, 12, 0), hsq=0.26,
               rh=(0, -25, 0.6), w=(0, -22), lh=(-90, -40, 0.38), fl=(-0.1, 0.24, 0), fr=(0.1, -0.26, 0), hs=1.1)
LLH_OVER = pose(LLH_HIT, hip=(0, -0.15, -0.24), hipr=(-12, 37, 0), hsq=0.3, rh=(-2, -27, 0.6))
LLH_SET = pose(LLH_HIT, hip=(0, -0.06, -0.12), hipr=(-5, 18, 0), chest=(0, 10, 0), hsq=0.05, rh=(10, -20, 0.55),
               w=(5, -20), claw=0.8, hs=1.0)
CLIPS["Ab_LLH"] = (59, "spear", STEP_ATTACK, 20, [
    (1, SP, "out"), (5, LLH_RISE, "out"), (12, LLH_TOP, "hold"), (14, LLH_SHAKE, "hold"), (16, LLH_TOP, "hold"),
    (18, LLH_SMEAR, "hold"), (20, LLH_HIT, "hold"), (26, LLH_OVER, "io"), (32, LLH_SET, "io"), (48, SP, "hold"),
    (59, SP, "hold")])

# Ab_AF, Molten Palm (EM, hit 0.51 = frame 50.5, played at 1.7 x 1.6 so drawings every 6 frames): the claw
# pulled back to his hip and clenched into a swelling fist, shaking with the build-up, then shoved out
# flat ahead, the palm splayed and huge, body lunging behind it.
STEP_FAST = 6
AF_DRAW = pose(GUARD, hip=(0.03, 0.08, -0.12), hipr=(35, -6, 0), chest=(28, -8, 0), head=(-25, 4, 0), hsq=0.14,
               rh=(150, -20, 0.38), w=(170, -10), lh=(-10, 20, 0.38), fl=(-0.07, 0.14, 0), fr=(0.06, -0.12, 0),
               claw=1.0, hs=1.2)
AF_CHARGE = pose(AF_DRAW, hip=(0.03, 0.1, -0.14), hipr=(45, -8, 0), chest=(34, -10, 0), rh=(160, -15, 0.36),
                 hsq=0.22, hs=1.45)
AF_SHAKE = pose(AF_CHARGE, rh=(154, -11, 0.37), hipr=(42, -7, 2), head=(-22, 4, 3), hs=1.5)
AF_SMEAR = pose(AF_CHARGE, hip=(0, -0.06, -0.08), hipr=(5, 14, 0), chest=(0, 10, 0), head=(-5, 4, 0), hsq=-0.14,
                rh=(40, -5, 0.6), w=(25, 0), claw=0.2, hs=1.5)
AF_HIT = pose(AF_SMEAR, hip=(-0.02, -0.18, -0.12), hipr=(-32, 24, 0), chest=(-22, 14, 0), head=(20, 6, 0), hsq=0.2,
              rh=(-10, 0, 0.6), w=(-10, 5), lh=(-160, 20, 0.39), fl=(-0.06, 0.24, 0), fr=(0.06, -0.3, 0), claw=-1.0,
              hs=1.65)
AF_OVER = pose(AF_HIT, hip=(-0.02, -0.19, -0.13), hipr=(-35, 26, 0), hsq=0.24, rh=(-12, -1, 0.6), hs=1.6)
AF_SET = pose(AF_HIT, hip=(-0.01, -0.08, -0.09), hipr=(-15, 12, 0), chest=(-10, 10, 0), hsq=0.04, rh=(10, -5, 0.55),
              w=(5, 5), claw=0.0, hs=1.2)
CLIPS["Ab_AF"] = (99, "hand", STEP_FAST, 50, [
    (1, GUARD, "out"), (7, AF_DRAW, "lin"), (25, AF_CHARGE, "hold"), (31, AF_SHAKE, "hold"), (35, AF_CHARGE, "hold"),
    (39, AF_SHAKE, "hold"), (43, AF_CHARGE, "hold"), (47, AF_SMEAR, "hold"), (50, AF_HIT, "hold"), (60, AF_OVER, "io"),
    (70, AF_SET, "io"), (84, GUARD, "hold"), (99, GUARD, "hold")])

# Hit_A: a big cartoon flinch: knocked back with the hood squashed flat and wide, claw flung open, held,
# a stretched rebound, back to the guard.
HIT_FLINCH = pose(GUARD, hip=(0, 0.1, -0.06), hipr=(8, -22, -6), chest=(5, -16, -4), head=(10, -14, -8), hsq=0.3,
                  rh=(110, 20, 0.5), w=(140, 40), lh=(-110, 30, 0.38), fl=(-0.06, 0.04, 0), fr=(0.06, 0.08, 0),
                  claw=-1.0, clawph=40.0, hs=1.2)
HIT_BACK = pose(HIT_FLINCH, hip=(0, 0.06, -0.02), hipr=(4, -12, -3), chest=(2, -8, 0), head=(5, -6, -3), hsq=-0.12,
                rh=(70, 5, 0.5), w=(80, 25), claw=-0.3, clawph=0.0, hs=1.05)
CLIPS["Hit_A"] = (21, "hand", STEP_ATTACK, None, [
    (1, GUARD, "snap"), (2, HIT_FLINCH, "hold"), (7, HIT_BACK, "io"), (13, pose(GUARD, hsq=0.05), "io"),
    (21, GUARD, "hold")])

# Death_A (46 frames, 0.9 s at 1.7; the game restarts the room 1.8 s after he falls): a chibi collapse.
# Hit (flinch, hood squashed), a woozy stagger with the head lolling, the knees buckle and he drops onto
# them, the hood flopping forward, then he topples onto his face, the hood squashed flat on the floor with
# a small bounce. The claw lies out ahead splayed, twitches twice, and dissolves last (shrinks away).
DE_HIT = pose(HIT_FLINCH, hsq=0.3, bsq=0.06)
DE_WOOZY = pose(GUARD, hip=(0.02, 0.06, -0.08), hipr=(-6, -10, 8), chest=(-4, -6, 10), head=(8, -16, 18), hsq=-0.12,
                bsq=-0.04, rh=(70, -40, 0.5), w=(70, -50), lh=(-60, -70, 0.36), fl=(-0.06, 0.04, 0), fr=(0.08, -0.02, 0),
                claw=0.2, hs=1.1)
DE_BUCKLE = pose(DE_WOOZY, hip=(0.0, 0.08, -0.3), hipr=(0, 14, 4), chest=(0, 14, 0), head=(0, 26, 6), hsq=0.2, bsq=0.08,
                 rh=(40, -70, 0.42), w=(30, -70), lh=(-40, -75, 0.34), fl=(-0.06, -0.14, 0.0), fr=(0.06, -0.18, 0.0),
                 flr=(0, -50, 0), frr=(0, -50, 0), claw=-0.3, hs=1.1)
DE_KNEEL = pose(DE_BUCKLE, hip=(0.0, 0.06, -0.33), head=(-4, 34, -8), hsq=0.12, bsq=0.03)
DE_TOPPLE = pose(DE_KNEEL, hip=(0.0, -0.06, -0.38), hipr=(0, 52, 0), chest=(0, 24, 0), head=(0, 12, 0), hsq=-0.16,
                 bsq=-0.03, rh=(10, -20, 0.55), w=(5, -25), lh=(-30, -30, 0.36), fl=(-0.06, -0.24, 0.04),
                 fr=(0.06, -0.28, 0.06), flr=(0, -60, 0), frr=(0, -60, 0), claw=-0.8, clawph=40.0, hs=1.2)
DE_FLAT = pose(DE_TOPPLE, hip=(0.0, -0.12, -0.5), hipr=(0, 80, 0), chest=(0, 8, 0), head=(0, -6, 0), hsq=0.34,
               bsq=0.08, rh=(15, -5, 0.6), w=(10, -8), lh=(-60, -5, 0.36), fl=(-0.08, -0.38, 0.06),
               fr=(0.08, -0.42, 0.08), claw=-1.0, clawph=60.0, hs=1.25)
DE_BOUNCE = pose(DE_FLAT, hip=(0.0, -0.12, -0.46), hipr=(0, 76, 0), hsq=-0.06, bsq=-0.02, claw=-0.6, hs=1.25)
DE_LIE = pose(DE_FLAT, hsq=0.26, bsq=0.04, claw=-0.9, hs=1.25)
CLIPS["Death_A"] = (46, "hand", STEP_ATTACK, None, [
    (1, GUARD, "snap"), (2, DE_HIT, "hold"), (5, DE_WOOZY, "io"), (11, DE_BUCKLE, "snap"), (13, DE_KNEEL, "hold"),
    (17, DE_TOPPLE, "snap"), (21, DE_FLAT, "hold"), (23, DE_BOUNCE, "hold"), (25, DE_LIE, "hold"),
    (29, pose(DE_LIE, claw=0.6), "hold"), (31, pose(DE_LIE, claw=-0.9), "hold"), (33, pose(DE_LIE, claw=0.3, hs=1.15), "hold"),
    (35, pose(DE_LIE, claw=-0.4, hs=0.9), "lin"), (43, pose(DE_LIE, claw=-0.2, hs=0.12), "hold"),
    (46, pose(DE_LIE, claw=-0.2, hs=0.12), "hold")])

# Ab_Swing (R onto a pillar; void_grab plays it once and the swing runs 0.5-1.6 s on): a crouch with the
# claw cocked down behind him (anticipation), the claw flung up and out (the tentacle shoots, 0.07 s),
# the yank as it catches: the body pulled up after it, stretched past the hang (overshoot), legs swinging
# through; then the hang: tucked, leaning in, the claw up holding, slowly flexing until he lets go.
SW_COCK = pose(GUARD, hip=(0.02, 0.05, -0.14), hipr=(20, 16, -4), chest=(14, 8, 0), head=(-10, -8, 0), hsq=0.22,
               bsq=0.08, rh=(120, -40, 0.45), w=(150, -30), lh=(-60, -30, 0.36), fl=(-0.06, 0.08, 0), fr=(0.06, -0.08, 0),
               claw=0.8, hs=1.1)
SW_FLING = pose(SW_COCK, hip=(0.0, -0.02, 0.0), hipr=(-6, -6, 6), chest=(-10, -10, 4), head=(6, -16, 0), hsq=-0.2,
                bsq=-0.1, rh=(40, 70, 0.6), w=(40, 78), lh=(-80, -20, 0.38), fl=(-0.03, 0.06, 0.08), fr=(0.03, -0.1, 0.14),
                claw=-1.0, clawph=60.0, hs=1.45)
SW_YANK = pose(SW_FLING, hip=(0.0, -0.06, 0.06), hipr=(-10, -18, 10), chest=(-14, -14, 6), head=(10, -20, 4), hsq=-0.26,
               bsq=-0.12, rh=(45, 76, 0.6), w=(45, 82), lh=(-120, -40, 0.38), fl=(-0.02, 0.2, 0.2), fr=(0.02, 0.12, 0.26),
               flr=(0, 40, 0), frr=(0, 50, 0), claw=1.0, hs=1.3)
SW_HANG = pose(SW_YANK, hip=(0.0, 0.0, 0.03), hipr=(-6, 10, 8), chest=(-8, 4, 4), head=(6, -6, 0), hsq=0.06, bsq=0.03,
               rh=(42, 72, 0.58), w=(42, 80), lh=(-60, -40, 0.36), fl=(-0.02, 0.12, 0.16), fr=(0.02, -0.02, 0.24),
               flr=(0, 20, 0), frr=(0, 30, 0), claw=0.9, hs=1.2)
SW_DRIFT = pose(SW_HANG, hipr=(-4, 14, 12), head=(2, -2, 4), rh=(44, 70, 0.58), claw=0.7, clawph=60.0, hs=1.25)
CLIPS["Ab_Swing"] = (41, "hand", STEP_ATTACK, None, [
    (1, GUARD, "out"), (3, SW_COCK, "hold"), (5, SW_FLING, "hold"), (7, SW_YANK, "hold"), (11, SW_HANG, "io"),
    (25, SW_DRIFT, "io"), (41, SW_HANG, "hold")])

# ---------------------------------------------------------------- locomotion (round 35)
# The runs, the idle and the dash. Runs are written a frame at a time (step 0: `keys` is the list of
# per-frame poses): legs, hips and the body squash on ones, so a planted foot stays locked to the
# floor, and the arms, head and hood on twos (held 2 frames) for the comic snap. Loops are written
# from frame 0 (LOOP0), so frame N is frame 0 again and Godot's loop has no held seam.
LOOP0 = set()
LOOP_SPEED = 1.1  # player._play: loops play at 1.1
MOVE_SPEED = 7.5  # player.move_speed, m/s
RUN_N = 14  # frames per cycle (two steps): 0.424 s of play at LOOP_SPEED, 4.7 steps a second
RUN_GROUND = MOVE_SPEED / WORLD_K / LOOP_SPEED / 30.0  # m the floor passes under him per clip frame (0.227)
RUN_PLANT = 3.0  # frames a foot is down (a whole number: Godot samples between keys); the rest he is in the air
RUN_REACH = 0.30  # m ahead of the hip joint a foot lands (behind it on Run_B)
RUN_FOLLOW = 0.0  # of the floor speed the foot keeps going back as it leaves the floor (0: it kicks straight up and through)
RUN_TOE = 0.09  # m the ankle rises at push-off, onto the toes (the leg can't reach further back flat)
RUN_PAW = 0.0  # of a frame's floor travel the foot reaches past the landing spot and paws back (0: it drops straight down the last frame, a stomp)
RUN_LIFT = 0.22  # m the swinging foot rises (heel kicked up behind)
RUN_LEAN = 26.0  # degrees the hips pitch into the run
STRAFE_PLANT = 2.0  # sideways the legs can't reach as far: a shorter plant
# Ankle to hip joint at rest, along his front (the chibi's ankles sit 17 cm behind his hips).
ANK = {s: (head_of("foot." + s) - head_of("upperleg." + s)).dot(FWD) for s in "lr"}


def pump(x, k=0.6):
    """A snappier sine: holds near the ends, so arm pumps read as poses, not a wobble."""
    return math.copysign(abs(x) ** k, x)


def foot_run(s, reach, plant, way):
    """(along, up, pitch) of one foot at cycle phase s (0 = its contact) for a run along `way` (+1
    ahead, -1 back). Planted (`plant` frames) it slides against the travel at exactly RUN_GROUND a
    frame, the ankle rising onto the toes at the end; in the air it carries on back a moment, kicks up,
    swings through past the landing spot and, the last frame, paws back onto it at the floor's speed
    (so it lands without skidding)."""
    f = s * RUN_N  # frames since contact
    sweep = plant * RUN_GROUND
    land = reach * way
    if f <= plant:
        t = f / plant
        return land - way * RUN_GROUND * f, RUN_TOE * t * t, -10.0 + 35.0 * t
    swing = RUN_N - plant  # frames in the air
    p0, p1 = land - way * sweep, land + way * RUN_GROUND * RUN_PAW
    T = swing - 1.0
    w = (f - plant) / swing
    if f - plant <= T:  # Hermite from the push-off (still moving back at the floor's speed) to the reach
        t = (f - plant) / T
        h00, h10, h01 = 2 * t ** 3 - 3 * t * t + 1, t ** 3 - 2 * t * t + t, -2 * t ** 3 + 3 * t * t
        along = h00 * p0 + h10 * T * (-way * RUN_GROUND * RUN_FOLLOW) + h01 * p1
    else:
        along = p1 - way * RUN_GROUND * RUN_PAW * (f - plant - T)
    up = RUN_TOE + (RUN_LIFT - RUN_TOE) * math.sin(math.pi * min(w * 1.6, 1.0) ** 0.7) if w < 0.3 else         RUN_LIFT * math.sin(math.pi * (0.5 + 0.5 * (w - 0.3) / 0.7))
    pitch = 25.0 + 35.0 * math.sin(math.pi * min(w / 0.4, 1.0)) if w < 0.4 else 25.0 - 35.0 * (w - 0.4) / 0.6
    return along, up, pitch


# Hip height (m from his stance) through one step, at step phase 0 (contact), the down pose, the
# push-off, the top of the leap: tallest in the air, lowest just after the foot lands.
RUN_HIPS = [(0.0, -0.075), (0.2, -0.125), (0.43, -0.08), (0.7, -0.02), (1.0, -0.075)]
RUN_SQUASH = 0.06  # body squash at the down pose (and stretch at the top)


def run_hips(q):
    """(hip height, body squash) at step phase q: a smooth periodic curve through RUN_HIPS."""
    pts = RUN_HIPS
    for j in range(len(pts) - 1):
        if pts[j][0] <= q <= pts[j + 1][0]:
            t = (q - pts[j][0]) / (pts[j + 1][0] - pts[j][0])
            a, b = pts[j][1], pts[j + 1][1]
            z = a + (b - a) * t * t * (3 - 2 * t)
            break
    lo, hi = min(v for _, v in pts), max(v for _, v in pts)
    return z, RUN_SQUASH * (1 - 2 * (z - lo) / (hi - lo))


def unsquash(s, off, bsq):
    """A foot offset (right, fwd, up) from its rest that lands where `off` would with no body squash."""
    h = head_of("foot." + s)
    rest = (h.dot(RIGHT), h.dot(FWD), h.dot(UP))
    sc = (1 + 0.5 * bsq, 1 + 0.5 * bsq, 1 - bsq)
    return tuple((r + o) / k - r for r, o, k in zip(rest, off, sc))


def run_feet(way, u):
    """Both feet (offsets from rest before the squash, and their turns) at cycle phase u of a run."""
    side = {"L": -1.0, "R": 1.0}.get(way, 0.0)
    plant = STRAFE_PLANT if side else RUN_PLANT
    feet = {}
    for s, ph in (("l", u), ("r", (u + 0.5) % 1.0)):
        if side:
            a, up, pitch = foot_run(ph, plant * RUN_GROUND / 2, plant, side)
            sx = 1.0 if s == "r" else -1.0
            # sideways from its own rest; the swinging foot passes a little ahead (left) or behind (right)
            feet[s] = ((a - 0.03 * sx), (-0.06 * sx) * (up / RUN_LIFT) + 0.0, up)
            feet[s + "r"] = (0, 8.0 * up / RUN_LIFT, -side * 10.0)
        else:
            w = 1.0 if way == "F" else -1.0
            a, up, pitch = foot_run(ph, RUN_REACH, plant, w)
            feet[s] = (0.03 if s == "l" else -0.03, a - ANK[s], up)  # a little narrower than his stance
            feet[s + "r"] = (0, pitch if w > 0 else -0.5 * pitch, 0)
    return feet


def run_frames(way):
    """Run_F ("F"), Run_B ("B"), Strafe_L / Strafe_R ("L", "R"): left foot down on frame 0, right on
    RUN_N / 2, the same phase on all four so a change of direction carries on from the same step."""
    out = []
    side = {"L": -1.0, "R": 1.0}.get(way, 0.0)  # his right +
    plant = STRAFE_PLANT if side else RUN_PLANT
    for i in range(RUN_N + 1):
        u = i / RUN_N
        uq = (i // 2) * 2 / RUN_N  # on twos
        q = (2 * u) % 1.0  # step phase: 0 at each contact
        qq = (2 * uq) % 1.0
        k = math.cos(2 * math.pi * (q - 0.18))  # 1 at the down pose (mid-stance), -1 at the top of the leap
        lf = math.cos(2 * math.pi * uq)  # 1 with the left foot ahead
        feet = run_feet(way, u)
        hz, bsq = run_hips(q)  # the whole body squashes on the down pose and stretches at the top
        hip = (RUN_SWAY * math.cos(2 * math.pi * (u - 0.09)) + 0.03 * side, 0.0, hz)
        base = dict(GUARD if way != "F" else NEUTRAL)
        if way == "F":
            body = dict(hipr=(10 * lf, RUN_LEAN + 4 * k, RUN_ROLL * math.cos(2 * math.pi * (u - 0.09))),
                        chest=(-22 * lf, 8, 0), head=(6 * lf, -8 + 7 * math.cos(2 * math.pi * (qq - 0.3)), 0),
                        # the claw trails out behind his right, pumping against the right leg, splayed
                        rh=(140 + 18 * pump(lf), -18 - 8 * pump(lf), 0.55), w=(165 + 12 * pump(lf), 5 + 10 * pump(-lf)),
                        # the fist pumps hard against the left leg
                        lh=(-85 - 65 * pump(lf), -22 - 18 * pump(lf), 0.31), lpole=(-150, -30),
                        claw=-0.45 + 0.15 * math.cos(2 * math.pi * (qq - 0.3)), clawph=360 * uq, hs=1.18)
        elif way == "B":
            body = dict(hipr=(-8 * lf, -6 + 3 * k, RUN_ROLL * math.cos(2 * math.pi * (u - 0.09))),
                        chest=(14 * lf, 2, 0), head=(-4 * lf, 4 + 6 * math.cos(2 * math.pi * (qq - 0.3)), 0),
                        # backing off: the claw up in guard, open, the fist pumping small
                        rh=(30, -5 + 6 * pump(lf), 0.52), w=(20, 18 + 8 * pump(lf)),
                        lh=(-45 - 35 * pump(-lf), -30, 0.33), claw=-0.35, clawph=360 * uq, hs=1.15)
        else:
            body = dict(hipr=(side * 14, 8 + 3 * k, side * 10 + RUN_ROLL * 0.5 * math.cos(2 * math.pi * (u - 0.09))),
                        chest=(-side * 10, 6, 0), head=(-side * 6, 4 + 6 * math.cos(2 * math.pi * (qq - 0.3)), -side * 6),
                        # facing ahead, claw up and open towards where he looks
                        rh=(30 + side * 10, -5 + 5 * pump(lf), 0.52), w=(20 + side * 15, 15 + 6 * pump(lf)),
                        lh=(-40 - side * 15, -32 + 8 * pump(lf), 0.34), claw=-0.3, clawph=360 * uq, hs=1.15)
        hsq = 0.04 + 0.16 * math.cos(2 * math.pi * (qq - 0.24))  # the hood lags the body a little
        for f in "lr":  # the body squash scales about the floor: undo it on the feet so they stay locked
            feet[f] = unsquash(f, feet[f], bsq)
        p = pose(base, hip=hip, hsq=hsq, bsq=bsq, fl=feet["l"], fr=feet["r"], flr=feet["lr"], frr=feet["rr"], **body)
        out.append(p)
    return out


for _way, _clip in (("F", "Run_F"), ("B", "Run_B"), ("L", "Strafe_L"), ("R", "Strafe_R")):
    CLIPS[_clip] = (RUN_N + 1, "hand", 0, None, run_frames(_way))
    LOOP0.add(_clip)


# Idle: 4 s, hunched and menacing. The weight rolls onto one leg and over to the other once a loop
# (the free knee bends, its heel lifts), two slow breaths heave the chest and hood, the head tilts
# and glances, the claw held out at his side, swollen, opening and closing and drifting out and back
# (from the game camera a claw hanging low read small and dead), one claw flex half way.
IDLE_N = 120


def idle_frames():
    out = []
    for i in range(IDLE_N + 1):
        iq = (i // STEP_STANCE) * STEP_STANCE if i < IDLE_N else IDLE_N
        ph = iq / IDLE_N * 2 * math.pi
        wt = pump(math.sin(ph), 0.5)  # weight: + on his left leg, held there, then rolled over
        br = math.sin(ph * 2)  # two breaths a loop
        lag = math.sin(ph * 2 - 0.7)
        flex = max(0.0, math.sin(ph - 1.2)) ** 3
        drift = math.sin(ph + 0.6)
        free_l = max(0.0, -wt)  # the left heel lifts with his weight on the right
        free_r = max(0.0, wt)
        out.append(pose(NEUTRAL, hip=(-0.035 * wt, 0.0, -0.06 + 0.012 * br - 0.012 * abs(wt)),
                        hipr=(5 * wt, 4, 5 * wt), spine=(0, 3, 0),
                        chest=(-3 * wt, 9 - 3 * br, -8 * wt), head=(-4 + 9 * math.sin(ph - 0.5), 2 + 4 * lag, 10 * wt),
                        hsq=0.045 * lag, bsq=0.015 * br,
                        rh=(45 + 8 * drift, -20 + 4 * br, 0.54), w=(50 + 16 * drift, 2 + 8 * lag),
                        lh=(-45, -60 + 4 * br, 0.36), fl=(-0.04, 0.03, 0.025 * free_l), fr=(0.04, -0.05, 0.025 * free_r),
                        flr=(0, 18 * free_l, 0), frr=(0, 18 * free_r, 0),
                        claw=0.1 + 0.55 * math.sin(ph) + 0.15 * lag - 0.6 * flex, clawph=180 * ph / math.pi, hs=1.2))
    return out


CLIPS["Idle"] = (IDLE_N + 1, "hand", 0, None, idle_frames())
LOOP0.add("Idle")


# Dodge_Forward (13 frames at 1.7: 0.25 s, drawings every 2): a one-drawing crouch, then the streak
# (pitched 48 degrees, body stretched long and thin, hood stretched along the dash, the leading knee
# tucked up and the other leg straight out behind, claw and fist trailing), a skid landing squashed
# low with the feet wide fore and aft, and back up to the guard.
DG_SQUASH = pose(GUARD, hip=(0, 0.02, -0.14), hipr=(0, 24, 0), chest=(0, 10, 0), head=(0, -8, 0), hsq=0.24, bsq=0.1,
                 rh=(110, -20, 0.45), w=(150, -10), lh=(-120, -30, 0.33), fl=(-0.04, 0.12, 0), fr=(0.04, -0.06, 0),
                 claw=0.6)
DG_STREAK = pose(GUARD, hip=(0, -0.06, -0.03), hipr=(0, 48, 0), chest=(0, 12, 0), head=(0, -16, 0), hsq=-0.3,
                 bsq=-0.1, rh=(175, 5, 0.6), w=(180, 12), lh=(-170, 5, 0.37), fl=(-0.02, 0.18, 0.2),
                 fr=(0.02, -0.4, 0.16), flr=(0, 30, 0), frr=(0, 60, 0), claw=-0.5, clawph=60.0, hs=1.1)
DG_SKID = pose(GUARD, hip=(0, 0.04, -0.15), hipr=(0, -10, 0), chest=(0, 4, 0), head=(0, 8, 0), hsq=0.22, bsq=0.09,
               rh=(60, -25, 0.5), w=(60, -5), lh=(-60, -45, 0.33), fl=(-0.06, 0.24, 0), fr=(0.06, -0.14, 0),
               flr=(0, -15, 0), claw=0.3)
CLIPS["Dodge_Forward"] = (13, "hand", 2, None, [
    (1, DG_SQUASH, "hold"), (2, DG_STREAK, "hold"), (8, DG_SKID, "hold"), (10, pose(GUARD, hsq=-0.06, bsq=-0.03, hipr=(0, 4, 0)), "lin"),
    (13, GUARD, "hold")])

# Jump_Start (20) and Jump_Idle (33): the breaker leap. A deep squash, sprung up stretched with the claw
# thrown overhead, then tucked and hanging with the claw cocked high and splayed, a slow menacing flex.
JS_CROUCH = pose(GUARD, hip=(0, 0.03, -0.18), hipr=(0, 20, 0), chest=(0, 8, 0), head=(0, 6, 0), hsq=0.28,
                 rh=(120, -30, 0.45), w=(150, -20), lh=(-60, -50, 0.36), fl=(-0.08, 0.06, 0), fr=(0.08, -0.06, 0),
                 claw=-0.6)
JS_SPRING = pose(GUARD, hip=(0, -0.02, 0.06), hipr=(0, -8, 0), chest=(0, -10, 0), head=(0, -12, 0), hsq=-0.25,
                 rh=(50, 70, 0.6), w=(55, 75), lh=(-40, -60, 0.37), fl=(-0.03, 0.05, 0.1), fr=(0.03, -0.08, 0.18),
                 claw=1.0, hs=1.3)
JUMP_AIR = pose(GUARD, hip=(0, 0, 0.02), hipr=(0, 8, 0), chest=(0, 4, 0), head=(0, -4, 0), hsq=-0.05,
                rh=(60, 45, 0.55), w=(75, 50), lh=(-50, -30, 0.37), fl=(-0.02, 0.1, 0.18), fr=(0.02, -0.04, 0.25),
                claw=-0.6, clawph=60.0, hs=1.2)
CLIPS["Jump_Start"] = (20, "hand", STEP_ATTACK, None, [
    (1, GUARD, "out"), (3, JS_CROUCH, "hold"), (8, JS_SPRING, "hold"), (12, JS_SPRING, "io"), (20, JUMP_AIR, "hold")])
CLIPS["Jump_Idle"] = (33, "hand", STEP_STANCE, None, [
    (1, JUMP_AIR, "io"), (17, pose(JUMP_AIR, hip=(0, 0, 0.0), hsq=0.04, rh=(62, 50, 0.55), claw=0.3, clawph=120.0), "io"),
    (33, JUMP_AIR, "hold")])


# Run_Start (6 frames) and Run_Stop (8): one-shots player._play_locomotion plays at the loop speed when
# he sets off from standing and when he lets go of the stick at full run. Written a frame at a time like
# the runs. player.accel takes him from 0 to MOVE_SPEED in 0.107 s, so his planted feet are keyed against
# that ramp (`floor_d`) and stay put on the floor while he speeds up or brakes.
ACCEL = 70.0  # player.accel, m/s^2


def floor_d(i, v0, a):
    """m the floor has passed under him `i` clip frames (at LOOP_SPEED) into a ramp from v0 at a m/s^2,
    capped between 0 and MOVE_SPEED."""
    t = i / 30.0 / LOOP_SPEED
    v0, a = v0 / WORLD_K, a / WORLD_K  # armature space
    t_end = ((MOVE_SPEED / WORLD_K if a > 0 else 0.0) - v0) / a
    if t <= t_end:
        return v0 * t + 0.5 * a * t * t
    return v0 * t_end + 0.5 * a * t_end * t_end + (v0 + a * t_end) * (t - t_end)


def run_feet0():
    """Run_F frame 0's feet before the squash: the left foot landing (contact), the right in mid-swing."""
    out = {}
    for s, ph, x in (("l", 0.0, 0.03), ("r", 0.5, -0.03)):
        a, up, pitch = foot_run(ph, RUN_REACH, RUN_PLANT, 1.0)
        out[s] = (x, a - ANK[s], up)
        out[s + "r"] = (0, pitch, 0)
    return out


def herm(p0, p1, t):
    t = t * t * (3 - 2 * t)
    return tuple(a + (b - a) * t for a, b in zip(p0, p1))


def oneshot(body, feet):
    """Per-frame poses from per-frame body poses and raw foot offsets (squash undone on each)."""
    out = []
    for P, F in zip(body, feet):
        bsq = P.get("bsq") or 0.0
        out.append(pose(P, fl=unsquash("l", F["l"], bsq), fr=unsquash("r", F["r"], bsq), flr=F["lr"], frr=F["rr"]))
    return out


RUN0 = run_frames("F")[0]
RF0 = run_feet0()
# The lunge: crouched and pitched in with the hips left behind (he sets off before his body does), claw
# drawn back low; then launched long, stretched tall, the fist thrown ahead, the claw trailing splayed,
# the left knee driven up; the left foot lands on Run_F's first contact and Run_F carries on from frame 0.
RS_LOAD = pose(GUARD, hip=(0, -0.07, -0.15), hipr=(0, 30, 0), chest=(-8, 8, 0), head=(4, -12, 0), hsq=0.24, bsq=0.08,
               rh=(135, -28, 0.47), w=(165, -12), lh=(-70, -35, 0.31), lpole=(-150, -30), claw=0.6, hs=1.1)
RS_LAUNCH = pose(GUARD, hip=(0, 0.02, -0.04), hipr=(8, 40, -4), chest=(-18, 8, 0), head=(6, -14, 0), hsq=-0.22, bsq=-0.08,
                 rh=(158, -12, 0.58), w=(178, 4), lh=(-15, -5, 0.37), lpole=(-150, -30), claw=-0.7, clawph=60.0, hs=1.22)
# Round 35 c: the same lunge backing off and sideways (mouse aim: he often strafes or backs), landing on
# frame 0 of Run_B / Strafe_L / Strafe_R. Backing: hunched over the push with the hips left ahead, then
# sprung back leaning away, the claw kept up in guard. Sideways: dropped low and tipped into the travel
# with the hips left behind, then thrown along it stretched and banked, facing ahead, claw up.
RS_POSES = {"F": (RS_LOAD, RS_LAUNCH)}
RS_POSES["B"] = (
    pose(GUARD, hip=(0, 0.07, -0.15), hipr=(0, 16, 0), chest=(6, 10, 0), head=(-4, -6, 0), hsq=0.24, bsq=0.08,
         rh=(35, -12, 0.48), w=(25, 10), lh=(-55, -40, 0.31), claw=0.5, hs=1.1),
    pose(GUARD, hip=(0, -0.03, -0.04), hipr=(-6, -14, 0), chest=(10, -6, 0), head=(-6, 8, 0), hsq=-0.22, bsq=-0.08,
         rh=(28, 8, 0.56), w=(18, 32), lh=(-35, -15, 0.35), claw=-0.6, clawph=60.0, hs=1.22))
for _w, _s in (("L", -1.0), ("R", 1.0)):
    RS_POSES[_w] = (
        pose(GUARD, hip=(-0.06 * _s, 0.0, -0.15), hipr=(_s * 8, 10, _s * 8), chest=(-_s * 6, 8, 0), head=(-_s * 4, -6, -_s * 6),
             hsq=0.24, bsq=0.08, rh=(35 + _s * 10, -12, 0.48), w=(25 + _s * 10, 10), lh=(-50 - _s * 10, -40, 0.31), claw=0.5, hs=1.1),
        pose(GUARD, hip=(0.03 * _s, 0.0, -0.04), hipr=(_s * 16, 8, _s * 18), chest=(-_s * 12, 6, _s * 4), head=(-_s * 6, 2, -_s * 10),
             hsq=-0.22, bsq=-0.08, rh=(30 + _s * 14, 10, 0.56), w=(20 + _s * 18, 30), lh=(-40 - _s * 20, -20, 0.35), claw=-0.6,
             clawph=60.0, hs=1.22))
WAY_SUFFIX = {"F": "", "B": "_B", "L": "_L", "R": "_R"}  # player.RUN_SUFFIX
TRAVEL = {"F": (0.0, 1.0), "B": (0.0, -1.0), "L": (-1.0, 0.0), "R": (1.0, 0.0)}  # (his right, his front)
RS_N = 7  # frames 0..6


def run_start_body(way):
    load, launch = RS_POSES[way]
    r0 = run_frames(way)[0]
    body = [load, load, mixp(load, launch, 0.6), launch, mixp(launch, r0, 0.35), mixp(launch, r0, 0.7), r0]
    for i in (1, 3, 5):  # arms, head and hood on twos, like the runs
        body[i] = pose(body[i], **{k: body[i - 1][k] for k in ("rh", "w", "lh", "head", "claw", "hs")})
    return body


def run_start_feet(way="F"):
    l0, r0 = GUARD["fl"], GUARD["fr"]
    tx, ty = TRAVEL[way]
    side = way in "LR"
    end = run_feet(way, 0.0)  # the run's frame 0: left landing, right in mid-swing
    out = []
    for i in range(RS_N):
        d = floor_d(i, 0.0, ACCEL)
        F = {}
        # right: the push-off foot, planted frames 0-2 (rising onto the toes) and sliding against the
        # travel with the floor, kicked up and through to the run's frame-0 mid-swing by frame 6
        if i <= 2:
            F["r"] = (r0[0] - tx * d, r0[1] - ty * d, RUN_TOE * (i / 2.0) ** 2)
            F["rr"] = (0, 30.0 * i / 2.0, 0) if not side else (0, 12.0 * i / 2.0, -tx * 12.0 * i / 2.0)
        else:
            t = (i - 2) / 4.0
            d2 = floor_d(2, 0.0, ACCEL)
            p = herm((r0[0] - tx * d2, r0[1] - ty * d2, RUN_TOE), end["r"], t)
            F["r"] = (p[0], p[1], p[2] + 0.12 * math.sin(math.pi * t))
            F["rr"] = (0, (20.0 if side else 40.0) * (1 - t) + end["rr"][1] * t, end["rr"][2] * t)
        # left: leaves the floor at once, knee driven up, reaching for the first contact on frame 6
        if i == 0:
            F["l"], F["lr"] = l0, (0, 0, 0)
        else:
            t = i / 6.0
            p = herm((l0[0] - 0.03 * tx, l0[1] - 0.03 * ty, 0.0), end["l"], t)
            F["l"] = (p[0], p[1], p[2] + 0.2 * math.sin(math.pi * min(t * 1.2, 1.0)))
            F["lr"] = (0, -15.0 * math.sin(math.pi * t) + end["lr"][1] * t, end["lr"][2] * t)
        out.append(F)
    return out


for _w in "FBLR":
    CLIPS["Run_Start" + WAY_SUFFIX[_w]] = (RS_N, "hand", 0, None, oneshot(run_start_body(_w), run_start_feet(_w)))
    LOOP0.add("Run_Start" + WAY_SUFFIX[_w])  # written from frame 0: frame 0 is the first pose, not a held key

# The skid: the left foot slammed down far ahead and braced, toes up, body squashed low and leaning
# back against the stop, claw flung out behind for balance, fist out wide; momentum then carries
# the top of him over: chest, head and hood pitch forward past upright, the hood stretched ahead and
# the claw swinging through in front of him, and he settles back into the idle's first pose.
IDLE0 = idle_frames()[0]
SK_BRACE = pose(NEUTRAL, hip=(0.02, -0.08, -0.15), hipr=(-6, -5, 6), chest=(-6, 0, 0), head=(0, 8, 0), hsq=0.26,
                bsq=0.1, rh=(125, 15, 0.56), w=(140, 25), lh=(-105, 5, 0.37), lpole=(-150, -30), claw=-0.7,
                clawph=40.0, hs=1.2)
SK_OVER = pose(NEUTRAL, hip=(0.0, 0.03, -0.11), hipr=(4, 22, 0), chest=(4, 18, 0), head=(4, 20, 0), hsq=-0.2,
               bsq=-0.04, rh=(35, -14, 0.58), w=(30, -8), lh=(-40, -55, 0.34), claw=0.7, hs=1.15)
SK_BACK = pose(NEUTRAL, hip=(0.0, -0.01, -0.08), hipr=(0, 0, 0), chest=(0, 4, 0), head=(-2, -2, 0), hsq=0.1, bsq=0.03,
               rh=(45, -18, 0.54), w=(48, 2), claw=0.2, hs=1.2)
# Backing: braced on a foot behind him, hunched forward against it, the claw kept up in guard; then the top
# of him rocks back past upright. Sideways: braced on the leading foot out wide, banked away from the
# travel; then the top of him tips over towards it, the claw swinging through that way.
SK_POSES = {"F": (SK_BRACE, SK_OVER)}
SK_POSES["B"] = (
    pose(GUARD, hip=(0.02, 0.08, -0.15), hipr=(6, 16, -6), chest=(6, 10, 0), head=(0, -6, 0), hsq=0.26, bsq=0.1,
         rh=(60, 18, 0.56), w=(55, 40), lh=(-75, 10, 0.37), claw=-0.7, clawph=40.0, hs=1.2),
    pose(GUARD, hip=(0.0, -0.03, -0.11), hipr=(-4, -12, 0), chest=(-4, -14, 0), head=(-4, -16, 0), hsq=-0.2, bsq=-0.04,
         rh=(20, 5, 0.58), w=(15, 25), lh=(-35, -45, 0.34), claw=0.7, hs=1.15))
for _w, _s in (("L", -1.0), ("R", 1.0)):
    SK_POSES[_w] = (
        pose(GUARD, hip=(0.05 * _s, 0.0, -0.15), hipr=(-_s * 6, 6, -_s * 14), chest=(_s * 6, 4, -_s * 6), head=(0, 6, -_s * 8),
             hsq=0.26, bsq=0.1, rh=(95 if _s < 0 else 40, 15, 0.56), w=(120 if _s < 0 else 50, 25),
             lh=(-110 if _s > 0 else -60, 5, 0.37), lpole=(-150, -30), claw=-0.7, clawph=40.0, hs=1.2),
        pose(GUARD, hip=(0.02 * _s, 0.0, -0.11), hipr=(_s * 6, 8, _s * 14), chest=(_s * 6, 8, _s * 10), head=(_s * 4, 6, _s * 14),
             hsq=-0.2, bsq=-0.04, rh=(-30 if _s < 0 else 85, -10, 0.58), w=(-35 if _s < 0 else 95, -5),
             lh=(-60 + _s * 20, -50, 0.34), claw=0.7, hs=1.15))
SS_N = 9  # frames 0..8
SKID_FRONT = 0.32  # m ahead of the hip joint the braced foot lands
SKID_BACK = 0.28  # m behind it the back foot drags
SKID_GIVE = 0.1  # m the feet come back towards him while they skid (the rest of his 0.4 m they slide)
SKID_WIDE = 0.2  # m out past its rest a sideways skid braces the leading foot


def run_stop_body(way, end):
    brace, over = SK_POSES[way]
    back = SK_BACK if end is IDLE0 else mixp(SK_BACK, end, 0.5)
    body = [brace, brace, mixp(brace, over, 0.25), mixp(brace, over, 0.7), over,
            mixp(over, back, 0.5), back, mixp(back, end, 0.6), end]
    for i in (1, 3, 5, 7):
        body[i] = pose(body[i], **{k: body[i - 1][k] for k in ("rh", "w", "lh", "claw", "hs")})
    return body


def run_stop_feet(way="F", end=None):
    """A skid, not a step: both feet slide on the floor as he brakes (they only give back a little of his
    travel in his frame), the front one a long reach ahead, the back one on its toes behind. Backing, the
    braced foot is the one behind him; sideways, the leading foot braces out wide and the other drags in."""
    end = end or IDLE0
    l_end, r_end = end["fl"], end["fr"]
    stop = floor_d(SS_N, MOVE_SPEED, -ACCEL)
    out = []
    for i in range(SS_N):
        g = floor_d(min(i, 5), MOVE_SPEED, -ACCEL) / stop  # 0..1 of the braking travel
        toe = RUN_TOE * (1.0 if i >= 2 else 1.0 + (2 - i))
        lr0, rr0 = (0, -22.0 * (1 - i / 6.0), 0), (0, 32, 0)
        if way == "F":
            l_skid = (-0.02, SKID_FRONT - SKID_GIVE * g - ANK["l"], 0.0)
            r_skid = (0.06, -SKID_BACK - 0.5 * SKID_GIVE * g - ANK["r"], toe)
        elif way == "B":  # the braced foot behind, on the ball of the foot; the front one flat
            l_skid = (-0.02, -0.85 * SKID_FRONT + SKID_GIVE * g - ANK["l"], 0.5 * toe)
            r_skid = (0.06, 0.8 * SKID_BACK + 0.5 * SKID_GIVE * g - ANK["r"], 0.0)
            lr0, rr0 = (0, 20.0 * (1 - i / 6.0), 0), (0, -10, 0)
        else:
            sd = TRAVEL[way][0]  # +1 to his right
            lead = (sd * (SKID_WIDE - SKID_GIVE * g), 0.02, 0.0)  # out wide, on its edge
            trail = (sd * (-0.08 + 0.5 * SKID_GIVE * g), -0.04, 0.6 * toe)
            l_skid, r_skid = (trail, lead) if sd > 0 else (lead, trail)
            edge = (0, 0, -sd * 14.0 * (1 - i / 6.0))
            lr0, rr0 = (edge, (0, 0, 0)) if sd < 0 else ((0, 0, 0), edge)
        F = {}
        if i <= 5:
            F["l"], F["lr"] = l_skid, lr0
            F["r"], F["rr"] = r_skid, rr0
        else:  # stepped back in under him, a small lift each
            t = (i - 5) / 3.0
            p = herm(l_skid, l_end, t)
            F["l"], F["lr"] = (p[0], p[1], p[2] + 0.05 * math.sin(math.pi * t)), (0, 0, 0) if way == "F" else herm(lr0, (0, 0, 0), t)
            p = herm(r_skid, r_end, t)
            F["r"], F["rr"] = (p[0], p[1], p[2] + 0.08 * math.sin(math.pi * t)), (0, 32.0 * (1 - t), 0) if way == "F" else herm(rr0, (0, 0, 0), t)
        out.append(F)
    return out


# Round 35 c: a stop per run (Run_Stop, Run_Stop_B, _L, _R) and each again ending on the guard's first
# pose (..._Ready) for when he has just fought (player._play_locomotion: the stand after is Idle_Ready).
READY0 = None  # set below, once ready_frames exists
STOP_WAYS = []
for _w in "FBLR":
    CLIPS["Run_Stop" + WAY_SUFFIX[_w]] = (SS_N, "hand", 0, None, oneshot(run_stop_body(_w, IDLE0), run_stop_feet(_w, IDLE0)))
    LOOP0.add("Run_Stop" + WAY_SUFFIX[_w])
    STOP_WAYS.append(_w)


# Idle_Ready (60 frames, 1.8 s at 1.1, a loop): the fight stance on Idle's breathing and weight shift,
# quicker and lower: feet wide, hunched over, weight rolled from leg to leg once a loop, two breaths, the
# claw held up in front of his face, open and flexing, the fist raised, a drawing every 3 frames.
READY_N = 60


def ready_frames():
    out = []
    for i in range(READY_N + 1):
        iq = (i // STEP_STANCE) * STEP_STANCE if i < READY_N else READY_N
        ph = iq / READY_N * 2 * math.pi
        wt = pump(math.sin(ph), 0.5)
        br = math.sin(ph * 2)
        lag = math.sin(ph * 2 - 0.8)
        free_l, free_r = max(0.0, -wt), max(0.0, wt)
        out.append(pose(GUARD, hip=(-0.04 * wt, 0.0, -0.11 + 0.016 * br - 0.01 * abs(wt)),
                        hipr=(8 + 5 * wt, 10, 6 * wt), spine=(0, 4, 0),
                        chest=(10 - 3 * wt, 12 - 3 * br, -7 * wt), head=(-8 + 6 * math.sin(ph - 0.5), -2 + 4 * lag, 8 * wt),
                        hsq=0.06 * lag, bsq=0.02 * br,
                        rh=(30 + 4 * math.sin(ph + 0.6), 12 + 4 * br, 0.55), w=(22 + 6 * math.sin(ph + 0.6), 38 + 6 * lag),
                        lh=(-35, -18 + 4 * br, 0.33), fl=(-0.09, 0.12, 0.025 * free_l), fr=(0.09, -0.12, 0.025 * free_r),
                        flr=(0, 15 * free_l, 0), frr=(0, 15 * free_r, 0),
                        claw=-0.5 + 0.3 * lag + 0.25 * math.sin(ph), clawph=180 * ph / math.pi, hs=1.2))
    return out


CLIPS["Idle_Ready"] = (READY_N + 1, "hand", 0, None, ready_frames())
LOOP0.add("Idle_Ready")
READY0 = ready_frames()[0]
for _w in STOP_WAYS:
    CLIPS["Run_Stop" + WAY_SUFFIX[_w] + "_Ready"] = (SS_N, "hand", 0, None,
                                                    oneshot(run_stop_body(_w, READY0), run_stop_feet(_w, READY0)))
    LOOP0.add("Run_Stop" + WAY_SUFFIX[_w] + "_Ready")


# ---------------------------------------------------------------- readability (round 35 c)
# From the game camera (13 m, 54 degrees down, the hero 140 px tall) the strikes read by width and size,
# not by height: so each attack gets a whole-body squash (`bsq`, the root bone scaled about the floor,
# short and wide) on the anticipation drawing 2-4 frames before contact, a stretched smear (tall and thin,
# the claw or weapon swollen `hs`, the hood stretched) on the strike, an impact squash on the contact, and
# on the recovery the body sinking on into the follow-through, then springing up past rest (stretched,
# the weapon a touch small) before it settles. Contact frames don't move: the script's own check counts
# the squash on the hand (`squashed`) as tests/contact_frames.gd does.
# Per clip: {key frame: role}; roles: A anticipation, S smear, H hit, O follow-through, T the overshoot
# past rest. (L3, VS and the plant rise tall first; their A is a quick gather just before the drive.)
PUNCH = {
    "Ab_L1": {4: "a", 8: "A", 9: "S", 11: "H", 16: "O", 19: "T"},
    "Ab_AL1": {4: "a", 8: "A", 9: "S", 11: "H", 16: "O", 19: "T"},
    "Ab_L2": {4: "a", 9: "A", 10: "S", 12: "H", 17: "O", 21: "T"},
    "Ab_L3": {14: "U", 20: "A", 21: "S", 24: "H", 30: "O", 36: "T"},
    "Ab_DL": {4: "A", 8: "S", 12: "H", 18: "O", 24: "T"},
    "Ab_GR": {3: "A", 5: "S", 7: "H", 12: "H", 16: "O", 24: "T"},
    "Ab_VS": {9: "U", 11: "U", 13: "A", 15: "S", 17: "H", 23: "O", 29: "T"},
    "Ab_LH": {4: "a", 9: "A", 11: "S", 14: "H", 18: "O"},
    "Ab_H": {4: "a", 11: "A", 13: "S", 15: "H", 21: "O", 27: "T"},
    "Ab_LLH": {12: "U", 14: "U", 16: "A", 18: "S", 20: "H", 26: "O", 32: "T"},
    "Ab_AF": {25: "a", 31: "a", 35: "a", 39: "a", 43: "A", 47: "S", 50: "H", 60: "O", 70: "T"},
    "Jump_Start": {3: "A", 8: "S", 12: "S", 20: "T"},
}
PUNCH_BSQ = {"a": 0.06, "A": 0.16, "U": -0.08, "S": -0.16, "H": 0.13, "O": 0.08, "T": -0.05}
PUNCH_HS_SMEAR = 1.3  # x the smear's own swell, up to PUNCH_HS_MAX (a bigger claw over the hood hides him)
PUNCH_HS_MAX = 1.6
PUNCH_HS_OVER = 0.93  # x the hit's swell on the spring past rest


def punch(keys, roles):
    out = []
    hit_hs = 1.0
    for f, P, ease in keys:
        r = roles.get(f)
        P = pose(P, bsq=P.get("bsq") or 0.0)
        if r:
            P["bsq"] = PUNCH_BSQ[r]
            if r == "A":
                P["hsq"] = max(P["hsq"], 0.24)
            elif r == "S":
                P["hsq"] = min(P["hsq"], -0.2)
                P["hs"] = max(P.get("hs", 1.0), min(P.get("hs", 1.0) * PUNCH_HS_SMEAR, PUNCH_HS_MAX))
            elif r == "H":
                P["hsq"] = max(P["hsq"], 0.18)
                hit_hs = P.get("hs", 1.0)
            elif r == "T":
                P["hsq"] = min(P["hsq"], -0.06)
                P["hs"] = min(P.get("hs", 1.0), hit_hs * PUNCH_HS_OVER)
        out.append((f, P, ease))
    return out


for _c, _roles in PUNCH.items():
    _n, _form, _step, _want, _keys = CLIPS[_c]
    CLIPS[_c] = (_n, _form, _step, _want, punch(_keys, _roles))
CLIP_CONTACT = {"Ab_VS": 17}  # checked here too (contact_frames.gd checks it; Ab_GR's snap rule only there)


ROOT_HEAD = head_of("root")


def squashed(v, b):
    """Where the root bone's squash `b` (scale about its head: bone y up) puts a point v."""
    if not b:
        return v
    loc = RQ["root"].inverted() @ (v - ROOT_HEAD)
    loc = Vector((loc.x * (1 + 0.5 * b), loc.y * (1 - b), loc.z * (1 + 0.5 * b)))
    return ROOT_HEAD + RQ["root"] @ loc


# ---------------------------------------------------------------- writing
def contact(hand_pos):
    sp = [0.0] + [(hand_pos[i] - hand_pos[i - 1]).length for i in range(1, len(hand_pos))]
    peak = max(sp)
    return max(i for i, s in enumerate(sp) if s >= 0.4 * peak) + 1  # 1-based frames


def write(name, n, frames_pose, changes, start=1):
    """changes: the 0-based frames where a new drawing starts (0 included). Claws key only those, held
    (CONSTANT -> glTF STEP); everything else keys the frame before each change and the change itself,
    LINEAR, which is the same curve as a key on every frame (the change still takes one frame) at a
    fraction of the keys."""
    old = bpy.data.actions.get(name)
    if old:
        old.name = name + "__old"
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data_create()
    ad.action = act
    slot = act.slots.new("OBJECT", arm.name)
    ad.action_slot = slot
    data = {}
    claw_bones = set()
    for i, (B, C, hsq, hs, bsq) in enumerate(frames_pose):
        for b, (q, t) in B.items():
            data.setdefault(b, {"q": [], "t": []})
            data[b]["q"].append(q); data[b]["t"].append(t)
        for b, q in C.items():
            data.setdefault(b, {"q": [], "t": []})
            data[b]["q"].append(q)
            claw_bones.add(b)
        data.setdefault("head", {}).setdefault("s", []).append(hsq)
        data.setdefault("hand.r", {}).setdefault("u", []).append(hs)
        data.setdefault("root", {}).setdefault("b", []).append(bsq)
    held = sorted(set(changes + [n - 1]))
    lin = sorted(set([0, n - 1] + [i - 1 for i in changes if i > 0] + changes))
    for b, d in data.items():
        qs = d["q"]
        for i in range(1, len(qs)):
            if qs[i].dot(qs[i - 1]) < 0:
                qs[i] = -qs[i]
        at = held if b in claw_bones else lin
        for k in range(4):
            fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].rotation_quaternion' % b, index=k)
            fc.keyframe_points.add(len(at))
            fc.keyframe_points.foreach_set("co", [v for i in at for v in (i + start, qs[i][k])])
            fc.keyframe_points.foreach_set("interpolation", [0 if b in claw_bones else 1] * len(at))
            fc.update()
        if b in ("root", "hips"):
            for k in range(3):
                fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["%s"].location' % b, index=k)
                fc.keyframe_points.add(len(lin))
                fc.keyframe_points.foreach_set("co", [v for i in lin for v in (i + start, d["t"][i][k])])
                fc.keyframe_points.foreach_set("interpolation", [1] * len(lin))
                fc.update()
        if "s" in d:  # head squash: wide and short, keeping the volume about
            for k in range(3):
                fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["head"].scale', index=k)
                fc.keyframe_points.add(len(lin))
                vals = []
                for i in range(n):
                    s = d["s"][i]
                    wide = 1.0 / math.sqrt(max(1.0 - s, 0.3)) * (1.0 + HSQ_WIDE * max(s, 0.0))
                    vals.append(1.0 - s if k == 1 else wide)
                fc.keyframe_points.foreach_set("co", [v for i in lin for v in (i + start, vals[i])])
                fc.keyframe_points.foreach_set("interpolation", [1] * len(lin))
                fc.update()
    if any(abs(b) > 1e-4 for b in data["root"]["b"]):
        for k in range(3):  # the whole body squashes (short and wide) and stretches, about the floor
            fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["root"].scale', index=k)
            fc.keyframe_points.add(len(lin))
            vals = [(1.0 - b) if k == 1 else 1.0 + 0.5 * b for b in data["root"]["b"]]  # bone y is up
            fc.keyframe_points.foreach_set("co", [v for i in lin for v in (i + start, vals[i])])
            fc.keyframe_points.foreach_set("interpolation", [1] * len(lin))
            fc.update()
    if any(abs(u - 1.0) > 1e-4 for u in data["hand.r"]["u"]):
        for k in range(3):  # the claw (and a weapon in it) swells on a reach or a smear
            fc = act.fcurve_ensure_for_datablock(arm, 'pose.bones["hand.r"].scale', index=k)
            fc.keyframe_points.add(len(lin))
            fc.keyframe_points.foreach_set("co", [v for i in lin for v in (i + start, data["hand.r"]["u"][i])])
            fc.keyframe_points.foreach_set("interpolation", [1] * len(lin))
            fc.update()
    ad.action = None
    if old:
        bpy.data.actions.remove(old)


for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
report = []
for name, (n, form, step, want, keys) in CLIPS.items():
    frames = keys if step == 0 else drawings(keys, n, step)
    if step:  # the body squash scales about the floor: keep the feet where the pose puts them
        frames = [pose(P, fl=unsquash("l", P["fl"], P["bsq"]), fr=unsquash("r", P["fr"], P["bsq"])) if P.get("bsq") else P
                  for P in frames]
    want = want or CLIP_CONTACT.get(name)
    out, hand = [], []
    LEG_MISS[0] = 0.0
    for P in frames:
        G = solve(P, form)
        out.append((bases(G), claw_rots(P), P["hsq"], P.get("hs", 1.0), P.get("bsq") or 0.0))
        hand.append(squashed(G["hand.r"].translation.copy(), P.get("bsq") or 0.0))
    got = contact(hand) if want else None
    report.append((name, n, want, got))
    sp = [0.0] + [(hand[i] - hand[i - 1]).length for i in range(1, len(hand))]
    # the biggest step after the contact against the 40% line (under 1.0 or the contact moves later)
    after = max(sp[got:] or [0.0]) / (0.4 * max(sp)) if got else 0.0
    if after > 0.85:
        print("   near the line: frame", sp.index(max(sp[got:])) + 1, "steps", " ".join("%.3f" % x for x in sp))
    print("[keys] %-12s %3d frames  contact want %s got %s  recovery %.2f of the line  legs miss %.3f m"
          % (name, n, want, got, after, LEG_MISS[0]))
    if want and got != want:
        print("   speeds", " ".join("%d:%.2f" % (i + 1, (hand[i] - hand[i - 1]).length) for i in range(1, n)))
    write(name, n, out, [0] + [i for i in range(1, n) if frames[i] != frames[i - 1]], 0 if name in LOOP0 else 1)


# ---- claws on the clips still copied from the shaman: half curled at rest, splayed into each swing's
# contact (its fastest hand frame, measured the game's way), clenched on it, easing back.
def copied_claws(a):
    ad = arm.animation_data
    ad.action = a
    ad.action_slot = a.slots[0]
    f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
    pos = []
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        pos.append((arm.matrix_world @ arm.pose.bones["hand.r"].head).copy())
    ad.action = None
    n = len(pos)
    loop = a.name in ("Run_B", "Strafe_L", "Strafe_R", "Running_A", "2H_Melee_Idle", "Jump_Idle", "Spellcasting")
    hit = contact(pos) if not loop else None
    # drawings (0-based frame, value), each held to the next (CONSTANT keys, glTF STEP): one every
    # COPIED_STEP frames on the ramps, the clench on the contact held 4 frames
    def at(i):
        f = i + 1
        if loop:
            return 0.2 + 0.25 * math.sin(2 * math.pi * i / max(n - 1, 1))
        if f < hit:
            return -0.8 * min(1.0, f / max(hit - 1.0, 1.0))
        return 1.0 - 0.7 * min(1.0, (f - hit) / max(0.5 * (n - hit), 1.0))
    if loop:
        marks = list(range(0, n, COPIED_STEP))
    else:
        marks = sorted(set(list(range(0, hit - 1, COPIED_STEP)) + [hit - 1] + list(range(hit + 3, n, COPIED_STEP))))
    keys = [(i, 1.0 if hit and hit - 1 <= i < hit + 3 else at(i)) for i in marks]
    if keys[-1][0] != n - 1:
        keys.append((n - 1, keys[-1][1]))
    cb = a.layers[0].strips[0].channelbag(a.slots[0])
    for i_t, t in enumerate(TIPS):
        for j, b in enumerate(CHAINS[t]):
            qs = []
            for _i, v in keys:
                deg = v * CLENCH_DEG if v > 0 else v * SPLAY_DEG * (1.6 if j == 0 else 1.0)
                if t == "main":
                    deg *= 0.6
                qs.append(Quaternion(CURL[b], math.radians(deg)))
            for k in range(4):
                fc = cb.fcurves.new('pose.bones["%s"].rotation_quaternion' % b, index=k)
                fc.keyframe_points.add(len(keys))
                fc.keyframe_points.foreach_set("co", [x for (i, _v), q in zip(keys, qs) for x in (f0 + i, q[k])])
                fc.keyframe_points.foreach_set("interpolation", [0] * len(keys))
                fc.update()
    return hit


# The clips the game plays on him (scripts/*.gd, after ComicLook's Ab_ mapping). The rest are still in
# the GLB but get no claw tracks: every track is a sampler, accessors and buffer views in the GLB's
# JSON, and claw tracks on all 40 copied clips grew the file by 1.1 MB.
PLAYED = {"Ab_L1", "Ab_AL1", "Ab_L2", "Ab_L3", "Ab_DL", "Ab_GR", "Ab_VS", "Ab_LH", "Ab_H", "Ab_LLH", "Ab_AF",
          "Ab_Swing", "Idle", "Idle_Ready", "Idle_Heft", "Idle_Listen", "Idle_Swing", "Run_F", "Run_B",
          "Strafe_L", "Strafe_R", "Run_Start", "Run_Stop", "Run_Start_B", "Run_Start_L", "Run_Start_R", "Run_Stop_B",
          "Run_Stop_L", "Run_Stop_R", "Run_Stop_Ready", "Run_Stop_B_Ready", "Run_Stop_L_Ready", "Run_Stop_R_Ready", "Hit_A", "Dodge_Forward", "Jump_Start", "Jump_Idle", "Death_A",
          "2H_Melee_Idle"}
for a in list(bpy.data.actions):
    if a.name in CLIPS or a.name.endswith("__old") or a.name not in PLAYED:
        continue
    if not a.slots or not a.layers:
        continue
    h = copied_claws(a)
    print("[claws] %-30s contact %s" % (a.name, h))

bad = [r for r in report if r[2] and r[2] != r[3]]
if bad:
    print("[keys] CONTACT MISMATCH", bad)


def share_anim_accessors(path):
    """Lossless: animation samplers whose key times (or values) are byte-identical share one accessor,
    then unused accessors and buffer views are dropped and the BIN chunk is packed again. The exporter
    writes a time accessor per track, and every track in a clip keys the same frames."""
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    bl = struct.unpack("<I", d[20 + jl:24 + jl])[0]
    bin_ = d[28 + jl:28 + jl + bl]
    acc, views = j["accessors"], j["bufferViews"]

    def blob(a):
        v = views[acc[a]["bufferView"]]
        o = v.get("byteOffset", 0) + acc[a].get("byteOffset", 0)
        meta = json.dumps({k: acc[a][k] for k in ("componentType", "count", "type", "normalized") if k in acc[a]})
        return meta, bin_[o:o + v["byteLength"] - acc[a].get("byteOffset", 0)]
    canon = {}
    for an in j["animations"]:
        for sm in an["samplers"]:
            for k in ("input", "output"):
                key = blob(sm[k])
                sm[k] = canon.setdefault(key, sm[k])
    # every accessor still referenced, in first-use order
    used = []

    def use(a):
        if a not in used:
            used.append(a)
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            for a in pr["attributes"].values():
                use(a)
            if "indices" in pr:
                use(pr["indices"])
            for t in pr.get("targets", []):
                for a in t.values():
                    use(a)
    for sk in j.get("skins", []):
        if "inverseBindMatrices" in sk:
            use(sk["inverseBindMatrices"])
    for an in j["animations"]:
        for sm in an["samplers"]:
            use(sm["input"]); use(sm["output"])
    amap = {a: i for i, a in enumerate(used)}
    for m in j.get("meshes", []):
        for pr in m["primitives"]:
            pr["attributes"] = {k: amap[a] for k, a in pr["attributes"].items()}
            if "indices" in pr:
                pr["indices"] = amap[pr["indices"]]
            pr["targets"] = [{k: amap[a] for k, a in t.items()} for t in pr.get("targets", [])] or None
            if pr["targets"] is None:
                del pr["targets"]
    for sk in j.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = amap[sk["inverseBindMatrices"]]
    for an in j["animations"]:
        for sm in an["samplers"]:
            sm["input"] = amap[sm["input"]]; sm["output"] = amap[sm["output"]]
    j["accessors"] = [acc[a] for a in used]
    # buffer views still referenced (accessors, images), repacked 4-byte aligned
    vused = []
    for a in j["accessors"]:
        if acc_view(a) is not None and acc_view(a) not in vused:
            vused.append(acc_view(a))
    for im in j.get("images", []):
        if "bufferView" in im and im["bufferView"] not in vused:
            vused.append(im["bufferView"])
    vmap = {v: i for i, v in enumerate(vused)}
    out = bytearray()
    new_views = []
    for v in vused:
        bv = dict(views[v])
        o = bv.get("byteOffset", 0)
        chunk = bin_[o:o + bv["byteLength"]]
        while len(out) % 4:
            out.append(0)
        bv["byteOffset"] = len(out)
        out += chunk
        new_views.append(bv)
    for a in j["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = vmap[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = vmap[im["bufferView"]]
    j["bufferViews"] = new_views
    while len(out) % 4:
        out.append(0)
    j["buffers"][0]["byteLength"] = len(out)
    js = json.dumps(j, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(out)
    glb = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<I", len(js)) + b"JSON" + js
    glb += struct.pack("<I", len(out)) + b"BIN" + bytes(1) + bytes(out)
    open(path, "wb").write(glb)


def acc_view(a):
    return a.get("bufferView")


# ---- optional contact sheet renders are left to the game (tests/heretic_shots.gd --clips)
if OUT:
    ob = bpy.data.objects["heretic"]
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    arm.animation_data.action = None
    for o in bpy.context.selected_objects:
        o.select_set(False)
    keep = [arm, ob] + [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm and o is not ob]
    for o in keep:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.splitext(OUT)[0] + "_keyed.blend", copy=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_skins=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=False,
                              export_apply=False, export_yup=True)
    before = os.path.getsize(OUT)
    share_anim_accessors(OUT)
    d = open(OUT, "rb").read()
    l = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + l])
    print("GLB", len(d) // 1024, "KB (%d KB before sharing); anims" % (before // 1024), len(j["animations"]),
          "joints", len(j["skins"][0]["joints"]))
    print("KEYED", OUT, "bad contacts" if bad else "contacts ok")
