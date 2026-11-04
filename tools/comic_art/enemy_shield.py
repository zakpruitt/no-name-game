# Shield Skeleton: a stubborn little skeleton hunched behind a door it has been dragging through a war.
#   blender -b -P enemy_shield.py
# Front -Y, its left +X, up +Z. Geometry, rig, animations, sheets, export, same as enemy_minion.py.
# One bag per material (one mesh per material), every piece tagged with its bone as it is built (CUR).
# Animation: poses are stated in the world (foot targets, shield transform, sword wrist + rotation, head aim) and
# solved to the kit's pose format for EVERY frame, so planted feet stay planted and the left hand stays on the grip.
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # the kit beside this script
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Quaternion as Q, Euler
NAME = 'shield'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['rust'] = C.toon('P_Rust', (.14, .04, .03), (.55, .24, .09), (.8, .45, .2), (1, .82, .55), rim=(.3, .12, .04), brush=.3)
M['wood'] = C.toon('P_Wood', (.15, .06, .06), (.42, .23, .13), (.72, .47, .25), (.95, .74, .44), rim=(.22, .1, .05), brush=.32, inner=.1)
C.rng.seed(7)

CUR = 'hips'
class TB(C.Bag):
    """A bag that remembers which bone each piece was built for."""
    def __init__(s, *a, **k):
        super().__init__(*a, **k); s.parts = []
    def add(s, vs, fs, ts=None):
        n = len(s.v); super().add(vs, fs, ts); s.parts.append((n, len(s.v), CUR))
B = {k: TB(k) for k in ('bone', 'socket', 'teeth', 'iron', 'leather', 'cloth', 'necro', 'rust', 'bronze')}
B['wood'] = TB('wood', smooth=False)
b = B['bone']

# ---- skeleton joints: deep hunch, skull thrust at the rim, front foot planted, back foot braced
hip = V((0, .08, .66)); chest = V((-.02, -.02, 1.06)); neck = V((-.07, -.14, 1.24)); H = V((-.12, -.2, 1.47))
K = 1.15  # skull scale
def HP(x, y, z): return H + V((x, y, z)) * K
shL, elL = V((.28, -.06, 1.2)), V((.46, -.2, 1.02))
shR, elR, wrR = V((-.3, -.06, 1.2)), V((-.6, .1, .98)), V((-.68, -.2, 1.16))
hpL, knL, anL = V((.15, .08, .62)), V((.28, -.12, .38)), V((.25, -.2, .1))
hpR, knR, anR = V((-.15, .08, .62)), V((-.27, .02, .36)), V((-.25, .24, .1))

# ---- the door: everything on it is placed in shield coordinates (u across, v up, d out of the face)
SC = V((.03, -.56, .76)); TILT = math.radians(8); YAW = math.radians(4)
_y = Euler((0, 0, YAW)).to_matrix()
SU = _y @ V((1, 0, 0)); SV = _y @ V((0, math.sin(TILT), math.cos(TILT))); SN = _y @ V((0, -math.cos(TILT), math.sin(TILT)))
def S(u, v, d=0.0): return SC + SU * u + SV * v + SN * (d - .42 * u * u)   # curved: the edges wrap back round him
TH = .05
# each plank: its outline, a stagger forward/back, and a lean, so every plank catches a different tone
PLANKS = [
    ([(-.5, -.5), (-.4, -.54), (-.3, -.6), (-.3, .36), (-.36, .29), (-.41, .36), (-.5, .22), (-.48, .03), (-.43, -.05), (-.5, -.13)], .0, .03),
    ([(-.29, -.6), (-.09, -.66), (-.08, .57), (-.15, .49), (-.2, .56), (-.29, .47)], .018, -.04),
    ([(-.07, -.63), (.15, -.59), (.15, .68), (.09, .6), (.03, .66), (-.07, .55)], -.012, .03),
    ([(.16, -.62), (.35, -.58), (.35, .83), (.3, .91), (.25, .8), (.2, .9), (.16, .84)], .02, -.03),
    ([(.36, -.55), (.5, -.52), (.535, -.27), (.45, -.2), (.43, -.1), (.52, -.03), (.53, .5), (.47, .77), (.42, .7), (.36, .79)], -.006, .02),
]
def plank_of(u):
    for p, a, l in PLANKS:
        if u <= max(q[0] for q in p) + .005: return a, l
    return PLANKS[-1][1:]
def surf(u, v):
    a, l = plank_of(u)
    return TH + a + l * v
def plank(poly, a, l):
    n = len(poly); cu = sum(p[0] for p in poly) / n; cv = sum(p[1] for p in poly) / n
    w = max(abs(p[0] - cu) for p in poly); h = max(abs(p[1] - cv) for p in poly)
    def ring(ins, d):
        return [S(cu + (u - cu) * (1 - ins / w), cv + (v - cv) * (1 - ins / h), d + a + l * v) for u, v in poly]
    vs = ring(.022, TH) + ring(0, TH * .35) + ring(0, -TH)
    fs = [tuple(range(n)), tuple(range(2 * n, 3 * n))]
    for r in (0, n):
        fs += [(r + i, r + (i + 1) % n, r + n + (i + 1) % n, r + n + i) for i in range(n)]
    B['wood'].add(vs, fs)
def strip(bag, pts, ws, eps=.007):
    """A tapered flat brush stroke painted on the face: grain, cracks, tally marks."""
    vs = []; m = len(pts)
    for i, (u, v) in enumerate(pts):
        a, c = pts[max(i - 1, 0)], pts[min(i + 1, m - 1)]
        tu, tv = c[0] - a[0], c[1] - a[1]; L = max(math.hypot(tu, tv), 1e-6)
        nu, nv = -tv / L, tu / L
        w = ws[0] + (ws[1] - ws[0]) * i / (m - 1)
        for sg in (-1, 1):
            q = (u + nu * w * sg, v + nv * w * sg)
            vs.append(S(q[0], q[1], surf(u, v) + eps))
    bag.add(vs, [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(m - 1)])
def nail(u, v, d0, L=.05, r=.016, head=.03):
    d = surf(u, v) + d0
    C.tube(B['iron'], [S(u, v, d - .02), S(u, v, d + L)], [r, r * .9], sides=5, sub=1, side=SU)
    C.blob(B['iron'], S(u, v, d + L), (head, head * .6 + .004, head), seg=6, rings=3)

# ---- skull: too big, peering over the low side of the rim, glaring
CUR = 'head'
C.blob(b, HP(0, .02, .06), (.2 * K, .22 * K, .18 * K), seg=14, rings=9)
C.blob(b, HP(0, -.12, -.03), (.135 * K, .1 * K, .1 * K), seg=12, rings=7)
for sx in (-1, 1):
    C.blob(b, HP(sx * .13, -.09, -.02), (.05 * K, .05 * K, .045 * K), seg=8, rings=5)
    low = -.02 if sx > 0 else .018   # one brow crushed down: the stubborn glare
    C.tube(b, [HP(sx * .02, -.195, .075 + low), HP(sx * .1, -.19, .105 + low), HP(sx * .18, -.11, .115 + low)], [.034 * K, .042 * K, .02 * K], sides=6, sub=2)
    ey = .05 if sx < 0 else .035
    C.blob(B['socket'], HP(sx * .075, -.185, .02), (.064 * K, .03 * K, ey * K * 1.1), seg=10, rings=6)
    C.blob(B['necro'], HP(sx * .075, -.208, .02), ((.026 if sx < 0 else .02) * K, .012 * K, (.026 if sx < 0 else .017) * K), seg=8, rings=5, t=.9)
C.blob(B['socket'], HP(0, -.215, -.045), (.024 * K, .012 * K, .03 * K), seg=7, rings=5)
for i in range(7):
    x = -.09 + i * .03
    C.blob(B['teeth'], HP(x, -.2 + abs(x) * .4, -.1), (.0135 * K, .012 * K, .022 * K), seg=6, rings=4)
C.tube(B['socket'], [HP(-.03, -.1, .23), HP(-.07, -.15, .17), HP(-.05, -.18, .135), HP(-.09, -.2, .1)], [.012, .008, .005, .001], sides=5, sub=1)
# dented rust cap, shoved down over the crown on the far side, with an arrow he never noticed
C.blob(B['rust'], HP(.06, .04, .165), (.18 * K, .19 * K, .09 * K), seg=12, rings=6)
C.tube(B['rust'], [HP(-.1, -.09, .17), HP(.08, -.16, .16), HP(.21, -.05, .13)], [(.02, .022), (.028, .03), (.012, .014)], sides=6, sub=2)
ar0 = HP(-.05, .04, .2); ard = V((-.42, .34, .84)).normalized()
C.tube(b, [ar0, ar0 + ard * .36], [.014, .012], sides=5, sub=1)
for a in (0, 1.57):
    sd = V((math.cos(a), math.sin(a), 0))
    C.tube(B['cloth'], [ar0 + ard * .26, ar0 + ard * .42], [(.045, .004), (.03, .004)], sides=4, sub=1, side=sd)
# jaw: separate, an underbite clamped shut
CUR = 'jaw'
J0 = HP(0, -.1, -.13)
C.tube(b, [HP(-.13, -.04, -.07), J0 + V((-.11, -.05, -.03)), J0 + V((0, -.125, -.06)), J0 + V((.11, -.05, -.03)), HP(.13, -.04, -.07)], [.028, .036, .042, .036, .028], sides=6, sub=2)
for i, x in enumerate((-.075, -.04, .0, .04, .075)):
    C.blob(B['teeth'], J0 + V((x, -.128 + abs(x) * .4, .0 + (.012 if i in (0, 3) else 0))), (.015, .012, .024 if i in (0, 3) else .017), seg=6, rings=4)

# ---- spine and ribs
for i in range(6):
    p = hip.lerp(chest, i / 5) + V((0, .03 * math.sin(i) + .05, 0))
    CUR = ('hips', 'hips', 'spine', 'spine', 'chest', 'chest')[i]
    C.blob(b, p, (.05, .05, .036), seg=8, rings=5)
CUR = 'chest'
C.tube(b, [chest + V((0, .05, 0)), neck, H + V((0, .03, -.1))], [.042, .036, .036], sides=6, sub=2)
for i in range(4):
    z = chest.z + .08 - i * .08; w = .25 - i * .022
    dy = chest.y + .02 + i * .02; cx = chest.x
    for sx in (-1, 1):
        C.tube(b, [V((cx + sx * .01, dy - .02, z + .03)), V((cx + sx * w * .8, dy, z)), V((cx + sx * w, dy - .14, z - .05)), V((cx + sx * w * .45, dy - .235, z - .08)), V((cx + sx * .02, dy - .25 + i * .012, z - .06))], [.018, .022, .02, .018, .014], sides=5, sub=2)
C.tube(b, [V((chest.x, chest.y - .235, chest.z + .05)), V((chest.x, chest.y - .2, chest.z - .28))], [.03, .02], sides=5, sub=1)
C.tube(b, [shL, V((chest.x, chest.y - .14, 1.2)), shR], [.028, .022, .028], sides=6, sub=2)
CUR = 'hips'
C.blob(b, hip + V((0, 0, -.03)), (.21, .14, .1), seg=12, rings=6, p=2.3)
C.blob(B['socket'], hip + V((0, -.11, -.05)), (.075, .05, .055), seg=8, rings=5)

# ---- limbs
def limb(a, c, bone, r=.032, k=.052):
    global CUR
    CUR = bone
    C.tube(b, [a, a.lerp(c, .5), c], [r, r * .72, r], sides=6, sub=1)
    C.blob(b, a, (k, k, k), seg=8, rings=5); C.blob(b, c, (k * .85, k * .85, k * .85), seg=8, rings=5)

# grip sits just behind the face; the left hand holds it
grip = S(.1, .08, -.12); wrL = grip + V((.06, .07, .03)); hdL = grip
limb(shL, elL, 'upperarm.l', .034, .056); limb(elL, wrL, 'lowerarm.l', .03, .046)
limb(shR, elR, 'upperarm.r', .034, .056); limb(elR, wrR, 'lowerarm.r', .03, .046)
limb(hpL, knL, 'upperleg.l', .044, .068); limb(knL, anL, 'lowerleg.l', .036, .052)
limb(hpR, knR, 'upperleg.r', .044, .068); limb(knR, anR, 'lowerleg.r', .036, .052)
def foot(an, bone):
    global CUR
    CUR = bone
    C.blob(b, an + V((0, -.07, -.06)), (.08, .14, .036), seg=8, rings=5)
    for i in range(3):
        o = V(((i - 1) * .046, -.2, -.075))
        C.tube(b, [an + V((o.x, -.13, -.065)), an + o], [.024, .009], sides=5, sub=1)
foot(anL, 'foot.l'); foot(anR, 'foot.r')
# rusty pauldron on the sword shoulder, the one bit of armour he kept
CUR = 'upperarm.r'
C.blob(B['rust'], shR + V((-.06, .0, .05)), (.13, .13, .085), seg=10, rings=5)
C.tube(B['iron'], [shR + V((-.1, .0, .12)), shR + V((-.15, .02, .24))], [.024, .003], sides=5, sub=1)
# the left hand round the strap
CUR = 'hand.l'
C.blob(b, wrL.lerp(grip, .55), (.055, .05, .045), seg=8, rings=5)
for i in range(3):
    o = SU * ((i - 1) * .034)
    C.tube(b, [wrL.lerp(grip, .7) + o, grip + o + V((0, -.02, .0)), grip + o + V((0, .0, -.04))], [.018, .016, .007], sides=5, sub=1)

# ---- sword: notched falchion, cocked out and up on the open side, flat turned to the camera
sd = V((-.5, .35, .79)).normalized()            # blade axis
wd = V((-1, -.25, 0)); wd = (wd - sd * wd.dot(sd)).normalized()   # edge direction: outward
sn = sd.cross(wd).normalized()
hdR = wrR + sd * .08
CUR = 'hand.r'
C.blob(b, wrR + sd * .05, (.058, .058, .048), seg=8, rings=5)
for i in range(3):
    o = sd * ((i - 1) * .034)
    C.tube(b, [wrR + sd * .05 + o + sn * .03, hdR + o + sn * .052 - wd * .012, hdR + o - sn * .01 - wd * .055], [.017, .015, .006], sides=5, sub=1)
CUR = 'weapon'
C.tube(B['leather'], [hdR - sd * .13, hdR, hdR + sd * .15], [.026, .024, .027], sides=6, sub=1)
C.blob(b, hdR - sd * .16, (.042, .042, .042), seg=8, rings=4)
gb = hdR + sd * .16
C.tube(B['iron'], [gb - wd * .13 - sd * .03, gb, gb + wd * .15 + sd * .04], [.022, .026, .012], sides=6, sub=2)
blade = [(-.06, 0), (.085, 0), (.115, .13), (.09, .21), (.055, .235), (.105, .275), (.15, .44), (.2, .6), (.17, .72), (.07, .82), (-.03, .72), (-.06, .46), (-.045, .34), (-.015, .31), (-.06, .27)]
vs = []; n_ = len(blade)
for th in (1, -1):
    vs += [gb + wd * x + sd * y * .8 + sn * th * (.026 if x < .05 else .009) for x, y in blade]
fs = [tuple(range(n_)), tuple(reversed(range(n_, 2 * n_)))] + [(i, (i + 1) % n_, n_ + (i + 1) % n_, n_ + i) for i in range(n_)]
B['rust'].add(vs, fs)
C.tube(B['socket'], [gb + sd * .05 - wd * .015 + sn * .03, gb + sd * .42 - wd * .012 + sn * .03], [(.012, .002), (.003, .002)], sides=4, sub=1, side=wd)

# ---- loincloth, belt, strap
CUR = 'SOFT'
for i in range(7):
    a = -2.6 + i * .34
    o = V((math.cos(a), math.sin(a) * .8, 0))
    q = hip + V((o.x * .2, o.y * .15 - .02, -.04))
    L = C.rng.uniform(.18, .3)
    C.tube(B['cloth'], [q, q + o * .03 - V((0, 0, L * .5)), q + o * .05 - V((0, 0, L))], [(.05, .006), (.054, .007), (.002, .002)], sides=5, sub=2, side=o.cross(V((0, 0, 1))))
CUR = 'hips'
C.tube(B['leather'], [hip + V((.2 * math.cos(i * .524), .15 * math.sin(i * .524) - .01, .025)) for i in range(13)], [(.012, .03)] * 2, sides=6, sub=1, side=V((0, 0, 1)))

# ================================================================= the door
CUR = 'shield'
for p, a, l in PLANKS: plank(p, a, l)
# back: two beams and the strap, seen from behind and in the side view
for v in (.34, -.34):
    C.tube(B['wood'], [S(-.46, v, -.085), S(0, v, -.085), S(.48, v, -.085)], [(.05, .03), (.055, .03)], sides=6, sub=1, side=SV)
C.tube(B['wood'], [S(-.42, -.38, -.1), S(.44, .4, -.1)], [(.04, .022), (.04, .022)], sides=6, sub=1, side=SV)
C.tube(B['leather'], [S(.1, .3, -.09), S(.1, .2, -.15), grip, S(.1, -.04, -.15), S(.1, -.14, -.09)], [(.04, .012), (.044, .012)], sides=6, sub=2, side=SU)

def band(v, u0, u1, w=.04, curl=None, n=9):
    pts = []
    for i in range(n):
        u = u0 + (u1 - u0) * i / (n - 1)
        pts.append(S(u, v + .005 * math.sin(i * 1.9), surf(u, v) + .009))
    if curl: pts[-1] = pts[-1] + SN * curl
    C.tube(B['iron'], pts, [(w, .008), (w * 1.1, .01)], sides=6, sub=1, side=SV)
    for i in range(1, n - 1, 2):
        C.blob(B['iron'], pts[i] + SN * .012, (.02, .014, .02), seg=6, rings=3)
band(-.5, -.5, .51, .045)
band(.62, .53, .1, .038, curl=.07, n=7)
band(.02, .52, .22, .034, n=5)
band(.13, -.5, -.24, .032, curl=.05, n=5)
# corner cap on the tall side
C.tube(B['iron'], [S(.53, -.14, surf(.5, 0) - .05), S(.535, .22, surf(.5, 0) - .045), S(.53, .5, surf(.5, 0) - .05)], [(.024, .05), (.026, .056)], sides=6, sub=1, side=SU)

# the crack: one long jagged split from the low rim down across the face, green leaking out of it
CK = [(-.2, .56), (-.13, .42), (-.18, .31), (-.05, .17), (-.09, .05), (.08, -.1), (.04, -.2), (.2, -.34), (.17, -.44), (.27, -.56)]
strip(B['socket'], CK, (.05, .012), eps=.008)
strip(B['necro'], CK[2:6], (.011, .003), eps=.012)
strip(B['socket'], [(-.05, .17), (.04, .2), (.08, .16)], (.016, .002), eps=.008)
strip(B['socket'], [(.08, -.1), (-.02, -.2), (-.06, -.3)], (.016, .002), eps=.008)
strip(B['socket'], [(-.18, .31), (-.27, .27), (-.3, .2)], (.014, .002), eps=.008)
# wood grain: quick ink strokes, not texture
for i in range(26):
    u = C.rng.uniform(-.46, .49); v = C.rng.uniform(-.55, .5); L = C.rng.uniform(.07, .2)
    strip(B['socket'], [(u, v), (u + C.rng.uniform(-.008, .008), v + L * .5), (u + C.rng.uniform(-.012, .012), v + L)], (.005, .0012), eps=.006)

# trophy: skull and crossbones, the emblem you read from the game camera
EU, EV = .2, .33
ed = surf(EU, EV)
def bone_x(s):
    a = S(EU - s * .2, EV - .19, ed + .04); c = S(EU + s * .2, EV + .19, ed + .04)
    C.tube(b, [a, c], [.024, .024], sides=6, sub=1, side=SU)
    for e, q in ((-1, a), (1, c)):
        for t_ in (-1, 1):
            o = SU * (.024 * t_) + SV * (-.024 * t_ * s)
            C.blob(b, q + o, (.032, .025, .032), seg=6, rings=4)
bone_x(1); bone_x(-1)
C.blob(b, S(EU, EV + .015, ed + .1), (.125, .095, .112), seg=10, rings=6)
C.blob(b, S(EU, EV - .07, ed + .12), (.08, .07, .06), seg=8, rings=5)
for sx in (-1, 1):
    C.blob(B['socket'], S(EU + sx * .052, EV - .005, ed + .185), (.04, .018, .042), seg=8, rings=5)
C.blob(B['socket'], S(EU, EV - .06, ed + .19), (.015, .01, .022), seg=6, rings=4)
for i in range(4):
    C.blob(B['teeth'], S(EU - .045 + i * .03, EV - .11, ed + .17), (.013, .012, .018), seg=6, rings=3)
C.tube(B['iron'], [S(EU + .01, EV + .08, ed + .08), S(EU + .01, EV + .08, ed + .24)], [.02, .017], sides=5, sub=1, side=SU)
C.blob(B['iron'], S(EU + .01, EV + .08, ed + .24), (.04, .024, .04), seg=7, rings=3)

# trophy: a dead man's bronze buckler, nailed on crooked, with the arrow still in it
BU, BV = -.27, -.27
bd = surf(BU, BV)
C.tube(B['bronze'], [S(BU, BV, bd - .01), S(BU, BV, bd + .03), S(BU, BV, bd + .075), S(BU, BV, bd + .1)], [.165, .17, .08, .05], sides=10, sub=1, side=SU)
C.blob(B['bronze'], S(BU, BV, bd + .105), (.045, .03, .045), seg=7, rings=4)
for i in range(6):
    a = i * 1.047 + .3
    C.blob(B['iron'], S(BU + .135 * math.cos(a), BV + .135 * math.sin(a), bd + .04), (.016, .012, .016), seg=6, rings=3)

def arrow(u, v, du, dv, L=.34, fletch=True):
    d = surf(u, v)
    a = S(u, v, d - .02); c = S(u + du * L, v + dv * L, d + L * .85)
    C.tube(b, [a, c], [.014, .012], sides=5, sub=1, side=SU)
    if fletch:
        t = (c - a).normalized()
        for sx in (SU, SV):
            C.tube(B['cloth'], [a.lerp(c, .72), c + t * .045], [(.048, .005), (.03, .004)], sides=4, sub=1, side=sx)
arrow(-.2, -.2, -.4, .5)
arrow(-.02, .03, .3, -.25)
arrow(.42, .22, .35, .35, L=.26)
arrow(.3, -.2, -.1, .55, L=.17, fletch=False)   # a snapped one

# trophy: the hand of someone who tried to climb over, nailed through the palm
HU, HV = .35, -.33
hd_ = surf(HU, HV) + .03
C.blob(b, S(HU, HV, hd_), (.05, .022, .056), seg=7, rings=4)
for i in range(4):
    o = (i - 1.5) * .027
    C.tube(b, [S(HU + o, HV - .03, hd_), S(HU + o * 1.3, HV - .1, hd_ + .004), S(HU + o * 1.4, HV - .165 + abs(o) * .3, hd_ - .012)], [.013, .012, .004], sides=5, sub=1, side=SU)
C.tube(b, [S(HU + .05, HV, hd_), S(HU + .1, HV - .05, hd_)], [.014, .004], sides=5, sub=1, side=SU)
nail(HU, HV + .01, .03, L=.05, head=.026)

# trophy: rusty horned helmet, low on the sword side
GU, GV = -.36, .1
gd = surf(GU, GV)
C.blob(B['rust'], S(GU, GV, gd + .05), (.1, .065, .09), seg=9, rings=5)
C.tube(B['rust'], [S(GU - .08, GV + .02, gd + .05), S(GU - .16, GV + .1, gd + .06), S(GU - .16, GV + .19, gd + .08)], [.026, .017, .002], sides=5, sub=1, side=SU)
nail(GU + .01, GV + .01, .1, L=.04, head=.024)

# teal rag nailed at the tall corner: the only colour on the door
RU, RV = .44, .58
rd = surf(RU, RV)
C.tube(B['cloth'], [S(RU, RV, rd + .012), S(RU + .01, RV - .15, rd + .03), S(RU - .025, RV - .3, rd + .02), S(RU + .005, RV - .44, rd + .03)], [(.05, .006), (.066, .007), (.056, .006), (.004, .003)], sides=5, sub=2, side=SU)
nail(RU, RV, .012, L=.04, head=.024)

# tally marks, scratched in chalk: he is keeping score
TU, TV = .03, -.37
for g in range(2):
    for i in range(4):
        u = TU + g * .155 + i * .024
        strip(B['teeth'], [(u, TV - .05), (u + .004, TV + .05)], (.0065, .005), eps=.009)
    strip(B['teeth'], [(TU + g * .155 - .018, TV - .035), (TU + g * .155 + .09, TV + .04)], (.006, .005), eps=.011)

# the hatchet that nearly got him, still stuck in the tall rim: a silhouette break up top
AU, AV = .25, .8
a0 = S(AU, AV + .015, surf(AU, AV) - TH * .5)
hdir = (SU * .42 + SV * .86 + SN * .28).normalized()
C.tube(B['leather'], [a0 - hdir * .02, a0 + hdir * .2, a0 + hdir * .38], [.021, .019, .023], sides=6, sub=1, side=SU)
hb = (SU * .88 - SV * .42).normalized()
hh = [(-.1, .0), (.14, -.08), (.17, .03), (.1, .1), (.0, .09), (-.08, .1), (-.12, .05)]
vs = []
for th in (1, -1):
    vs += [a0 + hb * x + hdir * (y - .02) + SN * th * .018 * (1 if y > .03 else .35) for x, y in hh]
n_ = len(hh)
fs = [tuple(range(n_)), tuple(reversed(range(n_, 2 * n_)))] + [(i, (i + 1) % n_, n_ + (i + 1) % n_, n_ + i) for i in range(n_)]
B['rust'].add(vs, fs)

# ------------------------------------------------------------------ meshes
col = scn.collection
objs = {}
for k, bag in B.items():
    if not bag.v: continue
    outline = 0 if k in ('socket', 'necro', 'teeth') else .006
    objs[k], _t = C.make_obj(k, bag, M, col, outline=outline)
print('tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()))

# ------------------------------------------------------------------ rig
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .2)), None),
    'hips': (hip, hip + V((0, -.02, .12)), 'root'),
    'spine': (hip + V((0, -.02, .12)), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (H + V((0, .02, -.15)), H + V((0, -.02, .25)), 'chest'),
    'jaw': (HP(0, -.03, -.08), J0 + V((0, -.12, -.03)), 'head'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'shield': (grip, grip + SV * .4, 'hand.l'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'weapon': (hdR, hdR + sd * .5, 'hand.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + V((0, -.18, -.08)), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + V((0, -.18, -.08)), 'lowerleg.r'),
    'cloth': (hip + V((0, -.1, -.04)), hip + V((0, -.12, -.34)), 'hips'),
}
R = CR.Rig('ShieldRig', bones)
def skin(o, bag):
    groups = {}
    for s_, e_, bn in bag.parts:
        for i in range(s_, e_):
            if bn == 'SOFT':
                ds = sorted((max(CR.seg_dist(o.data.vertices[i].co, *R.seg[n]), .012), n) for n in ('hips', 'cloth'))
                R._put(o, groups, i, [(1 / d ** 3, n) for d, n in ds])
            else:
                R._put(o, groups, i, [(1, bn)])
    R._bind(o)
for k, bag in B.items():
    if bag.v: skin(objs[k], bag)
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ pose solver
HEAD0 = {n: bones[n][0] for n in bones}
def rel(child, parent, parent_pos, D_p): return parent_pos + D_p @ (HEAD0[child] - HEAD0[parent])
def qe(r): return Euler([math.radians(a) for a in r], 'XYZ').to_quaternion()
def deg(q): return tuple(math.degrees(a) for a in q.to_euler('XYZ'))
def two_bone(a, k, c, A, T, pole):
    """Rest joints a-k-c, new root A, target T. Returns knee, end."""
    L1, L2 = (k - a).length, (c - k).length
    d = T - A; D = max(min(d.length, (L1 + L2) * .998), abs(L1 - L2) * 1.02 + .01)
    u = d.normalized()
    ca = (L1 * L1 + D * D - L2 * L2) / (2 * L1 * D)
    h = L1 * math.sqrt(max(0, 1 - ca * ca))
    p = pole - u * pole.dot(u)
    if p.length < 1e-5: p = V((0, -1, 0)) - u * u.y
    p.normalize()
    return A + u * (L1 * ca) + p * h, A + u * D
def rest_pole(a, k, c):
    u = (c - a).normalized(); v = k - a
    return (v - u * v.dot(u)).normalized()
POLE = {'L': rest_pole(hpL, knL, anL), 'R': rest_pole(hpR, knR, anR), 'AL': rest_pole(shL, elL, wrL), 'AR': rest_pole(shR, elR, wrR)}
EMPTY = dict(hr=(0, 0, 0), hl=(0, 0, 0), sp=(0, 0, 0), ch=(0, 0, 0), hd=(0, 0, 0), Hl=(0, 0, 0), jw=(0, 0, 0), cl=(0, 0, 0),
             L=(0, 0, 0), R=(0, 0, 0), Lp=(0, 0, 0), Rp=(0, 0, 0), Sr=(0, 0, 0), Sl=(0, 0, 0), Wr=(0, 0, 0), Wl=(0, 0, 0),
             Lk=tuple(POLE['L']), Rk=tuple(POLE['R']))
ROTS = ('hr', 'sp', 'ch', 'hd', 'jw', 'cl', 'Lp', 'Rp', 'Sr', 'Wr')
# kit gotcha: Rig.action writes no location curves when a bone never moves in that action, so an offset from another
# action (the rolled skull in Death_A) stays on the bone. A negligible offset forces the curves into every action.
EPS = V((3e-6, 0, 0))
def solve(p):
    """World-stated pose -> the kit's {bone: rot / {rot, loc}} (see comic_rig docstring: rotations about world axes, in the chain)."""
    out = {}
    I = Q()
    Dh = p['hr']; Ph = HEAD0['hips'] + V(p['hl'])
    out['hips'] = {'rot': deg(Dh), 'loc': tuple(p['hl'])}
    Ds = Dh @ p['sp']; Ps = rel('spine', 'hips', Ph, Dh); out['spine'] = deg(p['sp'])
    Dc = Ds @ p['ch']; Pc = rel('chest', 'spine', Ps, Ds); out['chest'] = deg(p['ch'])
    # head: aimed in the world, optionally knocked off its neck
    Dhead = p['hd']; hl = Dc.inverted() @ V(p['Hl'])
    out['head'] = {'rot': deg(Dc.inverted() @ Dhead), 'loc': tuple(hl + EPS)}
    out['jaw'] = deg(p['jw']); out['cloth'] = deg(p['cl'])
    # shield: placed in the world, the left arm reaches for it
    DS = p['Sr']; G = HEAD0['shield'] + V(p['Sl'])
    Ash = rel('upperarm.l', 'chest', Pc, Dc)
    wtarget = G + DS @ (wrL - HEAD0['shield'])
    ek, en = two_bone(shL, elL, wrL, Ash, wtarget, POLE['AL'])
    Du = (elL - shL).rotation_difference(ek - Ash); Dl = (wrL - elL).rotation_difference(en - ek)
    out['upperarm.l'] = deg(Dc.inverted() @ Du); out['lowerarm.l'] = deg(Du.inverted() @ Dl)
    out['hand.l'] = deg(Dl.inverted() @ DS)
    out['shield'] = {'rot': (0, 0, 0), 'loc': tuple(DS.inverted() @ (G - (en + DS @ (HEAD0['shield'] - wrL))) + EPS)}
    # sword: wrist position and blade rotation in the world
    Dw = p['Wr']
    Asr = rel('upperarm.r', 'chest', Pc, Dc)
    ek, en = two_bone(shR, elR, wrR, Asr, wrR + V(p['Wl']), POLE['AR'])
    Du = (elR - shR).rotation_difference(ek - Asr); Dl = (wrR - elR).rotation_difference(en - ek)
    out['upperarm.r'] = deg(Dc.inverted() @ Du); out['lowerarm.r'] = deg(Du.inverted() @ Dl)
    out['hand.r'] = deg(Dl.inverted() @ Dw)
    # legs: ankle targets on the floor
    for key, a, k, c, nm in (('L', hpL, knL, anL, 'l'), ('R', hpR, knR, anR, 'r')):
        A = rel('upperleg.' + nm, 'hips', Ph, Dh)
        ek, en = two_bone(a, k, c, A, c + V(p[key]), V(p[key + 'k']))
        Du = (k - a).rotation_difference(ek - A); Dl = (c - k).rotation_difference(en - ek)
        out['upperleg.' + nm] = deg(Dh.inverted() @ Du); out['lowerleg.' + nm] = deg(Du.inverted() @ Dl)
        out['foot.' + nm] = deg(Dl.inverted() @ p[key + 'p'])
    return out
def spec(p):
    q = dict(EMPTY); q.update(p)
    return {k: (qe(v) if k in ROTS else V(v)) for k, v in q.items()}
def act(name, length, keys):
    """Interpolates the world-stated poses and solves every frame, so the IK holds between keys too."""
    items = sorted(((k if isinstance(k, tuple) else (k, 'smooth')) + (spec(v),) for k, v in keys.items()), key=lambda x: x[0])
    frames = {}
    for fr in range(length + 1):
        if fr <= items[0][0]: cur = items[0][2]
        elif fr >= items[-1][0]: cur = items[-1][2]
        else:
            for i in range(len(items) - 1):
                if items[i][0] <= fr < items[i + 1][0]:
                    t = CR._ease((fr - items[i][0]) / (items[i + 1][0] - items[i][0]), items[i + 1][1])
                    a, c = items[i][2], items[i + 1][2]
                    cur = {k: (a[k].slerp(c[k], t) if k in ROTS else a[k].lerp(c[k], t)) for k in a}
                    break
        frames[fr] = solve(cur)
    return R.action(name, length, frames)
def P(base, **kw):
    q = dict(base); q.update(kw); return q

# ------------------------------------------------------------------ animation (24 fps)
IDLE_A = dict(hr=(3, 0, 0), hl=(0, 0, -.015), ch=(3, 0, 0), jw=(1, 0, 0), Wr=(0, 2, 0))
IDLE_B = dict(hr=(5, 0, -1), hl=(0, 0, -.05), ch=(7, 0, -3), hd=(4, 0, -5), jw=(3, 0, 0), Sr=(2, 0, 1), Sl=(0, 0, -.025), Wr=(6, 4, 0), Wl=(0, 0, -.04))
R_PEEK = dict(hr=(3, 0, 1), hl=(0, 0, -.01), ch=(0, 0, 2), hd=(-6, 0, 8), jw=(-3, 0, 0), Sr=(1, 0, -1), Sl=(0, 0, -.005), Wr=(-4, 2, 0), Wl=(0, 0, .03))
act('Idle_Combat', 48, {0: IDLE_A, 16: IDLE_B, 30: R_PEEK, 48: IDLE_A})

# the shuffle: dragged steps, the door lurching on each one. Round 29: s .13 -> .3 and the cycle 48 -> 24
# frames, since the game walks him at 3.2 m/s and the tiny steps skated (tests/foe_stride_check.gd)
def walk(t):
    s = .3; sw = .36
    def fy(ph):
        ph %= 1
        if ph < sw:
            k = ph / sw; k2 = k * k * (3 - 2 * k)
            return s - 2 * s * k2, .03 * math.sin(math.pi * k), math.sin(math.pi * k)
        return -s + 2 * s * (ph - sw) / (1 - sw), 0.0, 0.0
    ly, lz, lk = fy(t); ry, rz, rk = fy(t + .5)
    w = 2 * math.pi * t
    return dict(
        hr=(6, 0, 4 * math.sin(w)), hl=(.022 * math.cos(w), -.02, -.05 + .018 * math.cos(2 * w)),
        ch=(6, 0, -5 * math.sin(w)), hd=(1, 0, 3 * math.sin(w)), jw=(1 + 3 * max(0, math.sin(2 * w)), 0, 0), cl=(8 * math.sin(2 * w) + 6, 0, 0),
        L=(0, ly, lz), R=(0, ry, rz), Lp=(lk * 22, 0, 0), Rp=(rk * 22, 0, 0),
        Sr=(2 + 2.5 * math.cos(2 * w), 0, 4 * math.sin(w)), Sl=(.02 * math.sin(w), -.015 * math.cos(2 * w), -.04 + .03 * math.cos(2 * w)),
        Wr=(6 * math.sin(w), 3, 0), Wl=(0, -.03 * math.sin(w), -.05 + .025 * math.cos(2 * w)))
act('Walking_D_Skeletons', 24, {f: walk(f / 24) for f in range(25)})

# chop: the door swings open like a door, the sword comes over, hold, the slow stubborn shut
WIND = dict(hr=(-7, 0, 12), hl=(0, .09, .005), ch=(-14, 0, 16), hd=(4, 0, -16), jw=(-16, 0, 0),
            Sr=(-4, 0, 14), Sl=(-.02, .1, 0), Wr=(-52, 18, -10), Wl=(.2, .24, .42), L=(0, .04, .05), Lp=(-14, 0, 0), cl=(10, 0, 0))
LUNGE = dict(hr=(20, 0, -14), hl=(0, -.2, -.17), ch=(24, 0, -18), hd=(2, 0, 12), jw=(14, 0, 0),
             Sr=(4, 0, -38), Sl=(.26, -.08, -.05), Wr=(118, 26, 6), Wl=(.28, -.58, -.34), L=(0, -.2, 0), R=(0, -.04, 0), cl=(-16, 0, 0))
act('1H_Melee_Attack_Chop', 42, {0: IDLE_A, (13, 'out'): WIND, (16, 'in'): LUNGE, 24: P(LUNGE, hl=(0, -.19, -.15), jw=(10, 0, 0)), 42: IDLE_A})

# block: the whole door slams back into him, feet skid, skull ducks, then he leans straight back into it
BLK = dict(hr=(-9, 0, 2), hl=(0, .17, -.075), ch=(-10, 0, -3), hd=(22, 0, 5), jw=(5, 0, 0), cl=(14, 0, 0),
           Sr=(-15, 0, 5), Sl=(0, .19, .035), Wr=(-16, 6, -8), Wl=(.03, .16, .1), L=(0, .15, 0), R=(0, .1, 0))
BLK2 = P(BLK, hd=(12, 0, 3), hl=(0, .15, -.09), Sr=(-10, 0, 3), Sl=(0, .15, .0), L=(0, .16, 0), R=(0, .12, 0))
SHOVE = dict(hr=(11, 0, 0), hl=(0, .02, -.07), ch=(10, 0, 0), hd=(-7, 0, -4), jw=(-1, 0, 0), Sr=(5, 0, -2), Sl=(0, -.03, -.03), Wr=(5, 2, 0), L=(0, .06, 0), R=(0, .07, 0))
act('Block_Hit', 28, {0: IDLE_A, (2, 'hold'): BLK, (8, 'out'): BLK2, 13: BLK2, (20, 'smooth'): SHOVE, 28: IDLE_A})

# hurt: he got round the door. Skull snaps, jaw drops, door sags open
HURT = dict(hr=(-14, 0, 10), hl=(.02, .1, -.03), ch=(-16, 0, 12), hd=(18, 14, -22), jw=(-28, 0, 0), cl=(16, 0, 0),
            Sr=(-8, -6, 18), Sl=(.05, .08, -.05), Wr=(-30, 0, -22), Wl=(-.08, .1, .08), R=(0, .05, 0))
act('Hit_A', 16, {0: IDLE_A, (2, 'hold'): HURT, 16: IDLE_A})

# death: staggers, buckles, and the door falls on him. Skull rolls out, feet stick out from under it
D1 = dict(hr=(-16, 0, 8), hl=(0, .13, -.05), ch=(-16, 0, 10), hd=(24, 12, -16), jw=(-30, 0, 0), cl=(14, 0, 0),
          Sr=(-16, 0, 12), Sl=(.03, .18, -.03), Wr=(-32, 0, -24), Wl=(-.1, .14, .08), L=(0, .1, 0), R=(.02, .02, 0))
D2 = dict(hr=(-34, 0, 10), hl=(0, .22, -.3), ch=(-16, 0, 8), hd=(-6, 20, -22), jw=(-34, 0, 0), cl=(20, 0, 0),
          Sr=(-34, 0, 14), Sl=(.03, .24, -.2), Wr=(-55, 0, -50), Wl=(-.16, .26, -.42), L=(0, .06, 0), R=(.03, -.1, 0), Lp=(-10, 0, 0), Rp=(-10, 0, 0))
LIE = dict(hr=(-82, 0, 8), hl=(0, .12, -.53), ch=(-8, 0, 6), hd=(-70, 30, -60), Hl=(-.56, -.25, -.08), jw=(-40, 0, 0), cl=(-30, 0, 0),
           Sr=(-84, 0, 8), Sl=(.0, .76, -.5), Wr=(-72, 0, -62), Wl=(-.25, .35, -1.0), L=(.1, -.3, -.04), R=(-.02, -.72, -.04), Lp=(-72, 0, 10), Rp=(-78, 0, -10),
           Lk=(.5, -.2, .9), Rk=(-.5, -.2, .9))
BOUNCE = P(LIE, Sr=(-77, 0, 6), Sl=(.0, .74, -.42), hl=(0, .12, -.5), Lp=(-60, 0, 10), Rp=(-90, 0, -10))
act('Death_A', 56, {0: IDLE_A, (3, 'hold'): D1, (16, 'out'): P(D1, hl=(0, .17, -.1), Sr=(-22, 0, 14)), (25, 'smooth'): D2, (31, 'in'): LIE, (35, 'out'): BOUNCE, (39, 'in'): LIE, 56: LIE})

# spawn: the door punches up out of the floor first, then the skull rises behind it and glares over the rim
DN = -1.85
S0 = dict(hr=(10, 0, 0), hl=(0, 0, DN), ch=(16, 0, 0), hd=(14, 0, 0), L=(0, 0, DN), R=(0, 0, DN), Sl=(0, 0, DN + .1), Sr=(6, 0, 4), Wl=(0, 0, DN), Wr=(30, 0, 0), jw=(-10, 0, 0))
S1 = P(S0, Sl=(0, 0, -.42), Sr=(-2, 0, -3))
S2 = P(S0, hl=(0, 0, -.42), L=(0, 0, -.42), R=(0, 0, -.42), Sl=(0, 0, -.02), Sr=(-4, 0, -2), Wl=(0, 0, -.6), hd=(10, 0, 0), jw=(-8, 0, 0))
S3 = dict(hr=(-4, 0, 0), hl=(0, 0, .03), ch=(-6, 0, 0), hd=(-8, 0, 7), jw=(-22, 0, 0), Sl=(0, 0, .03), Sr=(-2, 0, -1), Wl=(.05, .05, .22), Wr=(-18, 6, 0))
act('Spawn_Ground_Skeletons', 40, {0: S0, (8, 'out'): S1, 14: S1, (22, 'out'): S2, (30, 'out'): S3, 40: IDLE_A})

# launch recovery and the second flinch, which enemy.gd plays
R.action('Hit_B', 14, {0: IDLE_A, (2, 'hold'): {'hips': {'rot': (12, 0, -8), 'loc': (0, -.06, -.02)}, 'chest': (20, 0, -14), 'head': (-22, 0, 18)}, 14: IDLE_A})
_LIE = {'hips': {'rot': (-82, 0, 0), 'loc': (0, .15, -.6)}, 'chest': (-6, 0, 0), 'head': (10, 0, 0)}
_KNEEL = {'hips': {'rot': (-20, 0, 0), 'loc': (0, .05, -.3)}, 'chest': (30, 0, 0), 'head': (-10, 0, 0)}
R.action('Lie_StandUp', 32, {0: _LIE, (8, 'hold'): _LIE, (20, 'out'): _KNEEL, (32, 'in'): IDLE_A})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# foot check: measured through the armature, as printed to confirm the solve (ankle rest z is .1)
for nm, ln, stance in (('Idle_Combat', 48, True), ('Walking_D_Skeletons', 24, True), ('1H_Melee_Attack_Chop', 42, True), ('Block_Hit', 28, True), ('Hit_A', 16, True), ('Death_A', 56, False), ('Spawn_Ground_Skeletons', 40, False)):
    zs = {'foot.l': [], 'foot.r': []}
    for f in range(ln + 1):
        R.play(nm, f)
        for n in zs: zs[n].append(R.obj.pose.bones[n].head.z)
    print('  feet %-24s L z %.3f..%.3f  R z %.3f..%.3f' % (nm, min(zs['foot.l']), max(zs['foot.l']), min(zs['foot.r']), max(zs['foot.r'])))
R.play('Idle_Combat', 0)
print('  top z', max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in objs.values()))

# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (-1.7, -6.0, 1.5), (-.04, -.2, .95), lens=58)
game = C.camera('CamGame', (0, -3.8, 5.3), (0, 0, .75), ortho=3.6)
side = C.camera('CamSide', (-5.4, -1.6, 1.3), (0, -.1, .9), lens=58)
sheet = C.camera('CamSheet', (-2.9, -4.1, 2.1), (-.05, -.05, .9), lens=48)
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)
FR = [('Idle_Combat', 16), ('Walking_D_Skeletons', 0), ('Walking_D_Skeletons', 6), ('Walking_D_Skeletons', 12),
      ('1H_Melee_Attack_Chop', 13), ('1H_Melee_Attack_Chop', 15), ('1H_Melee_Attack_Chop', 18), ('Block_Hit', 2),
      ('Block_Hit', 10), ('Block_Hit', 20), ('Hit_A', 2), ('Death_A', 12),
      ('Death_A', 25), ('Death_A', 33), ('Death_A', 54), ('Spawn_Ground_Skeletons', 8),
      ('Spawn_Ground_Skeletons', 22), ('Spawn_Ground_Skeletons', 30)]
def sheet_png(frames, cam, out_png, cols=6, tile=320):
    # as CR.contact_sheet, but each frame is cropped to a square round the character (halftone needs the 16:9 render)
    import subprocess, tempfile, shutil
    tmp = tempfile.mkdtemp(prefix='sheet_')
    scn.camera = cam; scn.render.image_settings.file_format = 'PNG'
    for i, (a, f) in enumerate(frames):
        R.play(a, f)
        scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
        bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                    '-vf', 'crop=720:720,scale=%d:-1,tile=%dx%d' % (tile, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
sheet_png(FR, sheet, os.path.join(OUT, NAME + '_motion.png'))
R.play('Idle_Combat', 0)
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME)
