# The Bone Warden, jailer of the dead: the comic-style boss. Hulking armoured skeleton, barred crown, a chest that is a
# cell door with a soul-fire heart behind it, a ring of keys on a chain, a bone-and-iron cleaver dragged along the floor.
#   blender -b -P enemy_warden.py
# Front -Y, its left +X, up +Z. Same layout as enemy_minion.py: geometry, rig, animations, sheets, export.
#
# Poses go through A() below rather than straight into Rig.action: it adds leg IK (feet stay planted, `F.l`/`F.r` move
# them), a verlet chain on the key ring, and heart scale, then hands the kit one key per frame.
import bpy, sys, os, math, shutil, subprocess, tempfile
sys.path.insert(0, r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc")
import comic_lib as C, comic_rig as CR
from mathutils import Vector as V, Euler, Quaternion as Q, Matrix
NAME = 'warden'
OUT = os.path.join(C.DIR, 'out', 'enemies'); os.makedirs(OUT, exist_ok=True)

scn = bpy.context.scene
for o in list(scn.collection.all_objects): bpy.data.objects.remove(o)
C.ink_material(); M = C.materials()
M['necro'] = C.emit('P_Necro', (.2, .85, .3), (.9, 1, .55))
M['rust'] = C.toon('P_Rust', (.14, .04, .03), (.55, .24, .09), (.8, .45, .2), (1, .82, .55), rim=(.3, .12, .04), brush=.3)
M['iron'] = C.toon('P_WardenIron', (.04, .05, .11), (.16, .19, .3), (.36, .42, .56), (.72, .8, .92), rim=(.14, .24, .4), brush=.16, inner=.2)  # shared P_Iron paints the shaman's lightning cracks
M['edge'] = C.toon('P_Edge', (.2, .24, .34), (.55, .62, .72), (.9, .95, 1), (1, 1, 1), rim=(.3, .4, .5), brush=.1, inner=.1)
C.rng.seed(11)

# Every vertex is tagged with the bone current when it was added, so skinning is explicit (no nearest-bone guessing).
CUR = ['chest']
def on(n): CUR[0] = n
class PB(C.Bag):
    def __init__(s, mat, smooth=True, sharp=None):
        super().__init__(mat, smooth, sharp); s.bn = []
    def add(s, vs, fs, ts=None):
        vs = list(vs); s.bn += [CUR[0]] * len(vs)
        super().add(vs, fs, ts)
B = {'bone': PB('bone'), 'socket': PB('socket'), 'teeth': PB('teeth'), 'iron': PB('iron', sharp=38), 'slab': PB('trousers', smooth=False), 'edge': PB('edge', smooth=False),
     'leather': PB('leather'), 'cloth': PB('cloth'), 'cape': PB('trousers'), 'necro': PB('necro'), 'rust': PB('rust', sharp=38), 'bronze': PB('bronze', sharp=40), 'black': PB('black')}
b, ir, nc, br, rs, bk = B['bone'], B['iron'], B['necro'], B['bronze'], B['rust'], B['black']

XX, YY, ZZ = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
def v(x, y, z): return V((x, y, z))

# skeleton joints: gorilla build. Barrel chest pushed forward so the heart clears the helm from the game camera.
hip = v(0, .1, 1.2); Cg = v(0, -.42, 1.72); chest = v(0, -.12, 1.98); neck = v(0, -.22, 2.3); H = v(0, -.42, 2.5)
shL, elL, wrL, hdL = v(1.04, -.12, 2.36), v(1.42, -.2, 1.88), v(1.46, -.5, 1.56), v(1.47, -.54, 1.36)
shR, elR, wrR, hdR = v(-1.04, -.12, 2.36), v(-1.4, .02, 1.82), v(-1.48, -.22, 1.38), v(-1.5, -.24, 1.18)
hpL, knL, anL = v(.3, .1, 1.1), v(.48, -.2, .62), v(.44, .1, .2)
hpR, knR, anR = v(-.3, .1, 1.1), v(-.5, -.2, .62), v(-.46, .14, .2)

def spike(bag, a, e, r, sides=5, bend=None):
    pts = [a, a.lerp(e, .5) + bend, e] if bend else [a, e]
    C.tube(bag, pts, [r, r * .55, .003] if bend else [r, .003], sides=sides, sub=2 if bend else 1)
def ring(bag, c, u, w, rt, n=14, sides=6):
    pts = [c + u * math.cos(i / n * 6.2832) + w * math.sin(i / n * 6.2832) for i in range(n + 1)]
    C.tube(bag, pts, [rt, rt], sides=sides, sub=1, cap=False)
def rivet(bag, c, r=.026): C.blob(bag, c, (r, r, r), seg=6, rings=4)
def link(bag, c, d, w, L=.085, W=.05, r=.017):
    pts = [c + d * (L * math.cos(i / 8 * 6.2832)) + w * (W * math.sin(i / 8 * 6.2832)) for i in range(9)]
    C.tube(bag, pts, [r, r], sides=4, sub=1, cap=False)
def chain_links(bag, a, e, n, L=.085, W=.05, r=.017):
    d = (e - a).normalized(); w1 = d.cross(XX if abs(d.x) < .8 else YY).normalized(); w2 = d.cross(w1)
    for i in range(n):
        link(bag, a.lerp(e, (i + .5) / n), d, w1 if i % 2 else w2, L, W, r)
def mini_skull(c, s=1.0, face=V((0, -1, 0)), glow=False):
    r = face.cross(ZZ).normalized()
    C.blob(b, c, (.1 * s, .1 * s, .09 * s), seg=9, rings=6)
    C.blob(b, c + face * .05 * s - ZZ * .05 * s, (.065 * s, .06 * s, .05 * s), seg=7, rings=4)
    for sx in (-1, 1):
        C.blob(B['socket'], c + face * .085 * s + r * sx * .04 * s, (.03 * s, .03 * s, .03 * s), seg=6, rings=4)
        if glow: C.blob(nc, c + face * .105 * s + r * sx * .04 * s, (.012 * s, .012 * s, .012 * s), seg=6, rings=4, t=.9)

# ---- the helm: skull face in an iron frame, heavy angry brow, underslung iron jaw. The read at game distance.
on('head')
C.blob(ir, H + v(0, .06, .1), (.5, .46, .36), seg=16, rings=9, p=2.4)
C.blob(b, H + v(0, -.25, -.04), (.38, .31, .31), seg=14, rings=9, p=2.3)
C.blob(bk, H + v(0, .1, -.16), (.42, .38, .26), seg=10, rings=6)                  # under the helm: black
for sx in (-1, 1):
    C.tube(ir, [H + v(sx * .4, .04, .12), H + v(sx * .47, -.2, -.1), H + v(sx * .36, -.3, -.3)], [.08, .07, .02], sides=6, sub=2)     # cheek guards
    C.tube(ir, [H + v(sx * .03, -.52, .03), H + v(sx * .2, -.5, .12), H + v(sx * .44, -.26, .22)], [.045, .06, .025], sides=6, sub=2)  # brow: the snarl
    rsz = .115 if sx > 0 else .1                                                     # one socket wider
    C.blob(B['socket'], H + v(sx * .175, -.5, -.04), (rsz, .05, rsz * .84), seg=10, rings=6)
    C.blob(nc, H + v(sx * .175, -.545, -.04), (rsz * .42, .016, rsz * .42), seg=8, rings=5, t=.9)
    rivet(B['edge'], H + v(sx * .38, -.14, .06)); rivet(B['edge'], H + v(sx * .34, -.3, -.2))
C.tube(ir, [H + v(0, -.16, .42), H + v(0, -.38, .28), H + v(0, -.52, .12), H + v(0, -.56, .02)], [.05, .07, .05, .012], sides=6, sub=2)   # nasal bar
C.blob(B['socket'], H + v(0, -.55, -.15), (.05, .022, .06), seg=7, rings=5)         # nose hole
for i in range(7):
    x = -.21 + i * .07
    C.blob(B['teeth'], H + v(x, -.5 + abs(x) * .32, -.28), (.032, .03, .05), seg=6, rings=4)
C.tube(B['socket'], [H + v(-.12, -.44, .17), H + v(-.32, -.46, .1), H + v(-.33, -.46, -.02), H + v(-.36, -.42, -.14)], [.016, .012, .008, .002], sides=5, sub=1)   # crack
# crown of bars: a jail door round the skull, spiked, with the soul fire breathing out of the top
c0 = H + v(0, .04, .3); c1 = H + v(0, .04, .42)
ring(ir, c0, XX * .5, YY * .47, .036, n=18)
ring(ir, c1, XX * .5, YY * .47, .024, n=18)
for i in range(11):
    a = i / 11 * 6.2832 + .29
    p = V((math.cos(a) * .5, math.sin(a) * .47, 0))
    tall = .03 + .1 * max(0, math.sin(a)) + .02 * (i % 2)
    C.tube(ir, [c0 + p, c1 + p * 1.02, c1 + p * 1.1 + ZZ * tall], [.034, .03, .003], sides=5, sub=1)
C.blob(B['socket'], H + v(0, .06, .44), (.36, .33, .05), seg=12, rings=4)
on('crownfire')
C.blob(nc, H + v(0, .06, .47), (.29, .26, .035), seg=12, rings=4, t=.25)
C.blob(nc, H + v(0, .02, .49), (.17, .15, .03), seg=10, rings=4, t=.6)
for i, (x, y, t) in enumerate(((0, -.02, .11), (.17, .05, .08), (-.17, .07, .09), (.05, .2, .08), (-.09, -.15, .07))):
    q = H + v(x, y + .04, .46)
    C.tube(nc, [q, q + v(x * .3, -.03, t * .55), q + v(x * .15 + .03, -.07, t + .02)], [.065, .045, .003], sides=6, sub=2)
on('head')
# jaw: iron, underslung, tusked
on('jaw')
J0 = H + v(0, -.2, -.38)
C.tube(ir, [H + v(-.39, -.1, -.22), J0 + v(-.3, -.02, .0), J0 + v(0, -.27, -.04), J0 + v(.3, -.02, 0), H + v(.39, -.1, -.22)], [.07, .1, .12, .1, .07], sides=7, sub=2)
C.blob(B['socket'], H + v(0, -.26, -.3), (.27, .17, .1), seg=9, rings=5)
for i in range(7):
    x = -.21 + i * .07
    C.blob(B['teeth'], J0 + v(x, -.24 + abs(x) * .55, .09), (.03, .026, .045), seg=6, rings=4)
for sx in (-1, 1):
    spike(b, J0 + v(sx * .23, -.2, .08), J0 + v(sx * .3, -.26, .36), .055, sides=6, bend=v(sx * .03, -.03, 0))

# ---- torso: an iron yoke over a barrel of ribs, the cell door in front, a black cavity behind the heart
on('chest')
C.blob(ir, v(0, .12, 2.2), (.98, .56, .4), seg=14, rings=8, p=2.6)
C.blob(B['rust'], v(0, .22, 2.42), (.5, .36, .14), seg=10, rings=5, p=2.4)
C.blob(bk, Cg + v(0, .32, 0), (.66, .42, .6), seg=12, rings=8)
for sx in (-1, 1):
    spike(ir, v(sx * .42, .26, 2.5), v(sx * .62, .42, 2.86), .085)                      # back spines: a broken gate
for i, (dz, w) in enumerate(((.44, .72), (.21, .8), (-.03, .78), (-.26, .68), (-.46, .54))):
    z = Cg.z + dz
    for sx in (-1, 1):
        C.tube(b, [v(sx * .05, .14, z + .06), v(sx * w * .86, .04, z), v(sx * w, -.4, z - .04), v(sx * w * .72, -.84, z - .08)], [.06, .068, .062, .05], sides=6, sub=2)
# the door frame: two hoops the doors shut against
for dz, rt in ((.55, .055), (-.56, .05)):
    z = Cg.z + dz; w = .62 if dz > 0 else .5
    C.tube(ir, [v(-w, -.62, z), v(-w * .6, -1.0, z), v(0, -1.12, z), v(w * .6, -1.0, z), v(w, -.62, z)], [rt, rt], sides=6, sub=2)
# the soul-fire heart: three flat tones stacked toward the viewer, tongues licking up
on('heart')
Hc = Cg + v(0, -.43, -.2)
C.blob(nc, Hc + v(-.13, .03, .08), (.25, .17, .23), seg=10, rings=7, t=.2)
C.blob(nc, Hc + v(.13, .03, .08), (.25, .17, .23), seg=10, rings=7, t=.2)
C.blob(nc, Hc + v(0, .03, -.13), (.22, .15, .3), seg=10, rings=7, t=.2)
C.blob(nc, Hc + v(-.01, -.09, .02), (.24, .14, .24), seg=9, rings=6, t=.55)
C.blob(nc, Hc + v(.0, -.18, .02), (.13, .07, .14), seg=8, rings=5, t=.95)
for x, y, h in ((-.2, .0, .34), (-.07, -.04, .46), (.08, -.02, .38), (.2, .02, .3), (0, .1, .3)):
    q = Hc + v(x, y, .16)
    C.tube(nc, [q, q + v(x * .3, 0, h * .55), q + v(-x * .2, 0, h)], [.07, .05, .003], sides=6, sub=2)
# the cell door: two leaves of bars, hinged at the outer edge. +Z opens door.l, -Z opens door.r
HINGE = {1: v(.56, -.8, Cg.z - .5), -1: v(-.56, -.8, Cg.z - .5)}
def door_y(x): return -1.14 + .95 * x * x
for sx in (-1, 1):
    on('door.l' if sx > 0 else 'door.r')
    for x, rt in ((.03, .04), (.27, .036), (.53, .05)):
        X_ = sx * x; y_ = door_y(x)
        C.tube(ir, [v(X_, y_, Cg.z + .5), v(X_ * 1.14, y_ - .13, Cg.z + .02), v(X_ * .82, y_ + .04, Cg.z - .5)], [rt, rt * 1.1, rt], sides=6, sub=2)
    for dz in (.36, -.33):
        pts = [v(sx * x, door_y(x) - .11, Cg.z + dz) for x in (.03, .16, .3, .44, .56)]
        C.tube(B['rust'], pts, [(.03, .024), (.03, .024)], sides=5, sub=1, side=YY)
    C.tube(ir, [HINGE[sx] + v(sx * .05, .02, 0), HINGE[sx] + v(sx * .05, .02, 1.0)], [.05, .05], sides=6, sub=1)
on('door.l')
Lk = v(0, -1.31, Cg.z - .34)
C.blob(br, Lk, (.13, .055, .145), seg=10, rings=6, p=3)
C.blob(B['socket'], Lk + v(0, -.05, .03), (.03, .012, .03), seg=6, rings=4)
C.tube(B['socket'], [Lk + v(0, -.05, .02), Lk + v(0, -.05, -.07)], [.016, .01], sides=4, sub=1)
ring(ir, Lk + v(0, .02, .17), XX * .085, ZZ * .11, .022, n=10)
for sx in (-1, 1):
    rivet(B['edge'], Lk + v(sx * .1, -.055, .11), .018); rivet(B['edge'], Lk + v(sx * .1, -.055, -.11), .018)

# gorget: iron collar, chain slung round it, a trophy skull on a link
on('chest')
ring(ir, neck + v(0, -.06, .02), XX * .46, YY * .42, .075, n=14, sides=7)
for i in range(16):
    a = -.3 + i / 15 * (math.pi + .6)
    p = V((math.cos(a) * .72, -.46 - math.sin(a) * .26 - .18, 2.34 - math.sin(a) * .15))
    d = V((-math.sin(a), -math.cos(a) * .3, 0)).normalized()
    link(ir, p, d, ZZ if i % 2 else V((0, -1, 0)), .07, .045, .016)

# ---- waist and pelvis: the spine shows, thin for how much it carries
on('spine')
C.tube(bk, [hip + v(0, -.04, .05), v(0, -.1, 1.72)], [.26, .3], sides=8, sub=1)
for i in range(5):
    C.blob(b, hip.lerp(v(0, -.14, 1.68), i / 4) + v(0, -.13, .06), (.145 - i * .004, .1, .06), seg=8, rings=5)
on('hips')
C.blob(ir, hip + v(0, 0, -.04), (.46, .33, .2), seg=12, rings=6, p=2.4)
ring(B['leather'], hip + v(0, -.01, .1), XX * .48, YY * .35, .05, n=14, sides=6)
mini_skull(hip + v(0, -.42, .08), 1.5, glow=True)
for sx in (-1, 1):
    C.blob(ir, hip + v(sx * .46, -.02, -.1), (.2, .24, .28), seg=9, rings=6, p=2.5, rot=(0, sx * .3, 0))
    rivet(B['edge'], hip + v(sx * .63, -.12, -.03))
mini_skull(hip + v(.5, -.28, -.1), 1.0)

# ---- tabard: the shared teal rag, ragged panels between the legs. Cape: soul-grey rags off the back
for i in range(7):
    x = -.33 + i * .11
    y = -.33 + abs(x) * .3
    L = C.rng.uniform(.5, .78) * (1.1 - abs(x))
    C.tube(B['cloth'], [v(x, y, 1.26), v(x * 1.02, y - .04, 1.26 - L * .55), v(x * 1.05, y - .02, 1.26 - L)], [(.075, .012), (.082, .012), (.006, .004)], sides=5, sub=2, side=XX)
for i in range(11):
    x = -.92 + i * .184
    L = C.rng.uniform(1.0, 1.42)
    y0 = .42 + .12 * (1 - abs(x))
    C.tube(B['cape'], [v(x * .8, y0, 2.42), v(x * .9, y0 + .22, 2.42 - L * .45), v(x, y0 + .3, 2.42 - L)], [(.12, .018), (.13, .018), (.006, .004)], sides=5, sub=2, side=XX)

# ---- shoulders: oversized on purpose. Key side wears a little prison with a burning skull in it; cleaver side is all spikes.
def pauldron(sh, sx):
    c = sh + v(sx * .1, 0, .14)
    C.blob(ir, c + v(0, 0, .05), (.49, .47, .35), seg=14, rings=8, p=2.5)
    C.blob(ir, c + v(sx * .1, 0, -.2), (.5, .49, .1), seg=14, rings=4, p=2.6)
    C.blob(ir, c + v(sx * .16, 0, -.33), (.44, .44, .09), seg=12, rings=4, p=2.6)
    C.blob(bk, c + v(sx * .02, 0, -.42), (.42, .4, .1), seg=10, rings=4)
    ring(B['rust'], c + v(0, 0, .1), XX * .485, YY * .465, .028, n=16, sides=5)
    for k in (-1, 1):   # two raised ribs fore and aft over the dome, spot-black grooves beside them
        off = k * .17
        C.tube(ir, [c + v(-.46 * sx, off, .04), c + v(-.24 * sx, off, .34), c + v(.06 * sx, off, .41), c + v(.34 * sx, off, .28), c + v(.48 * sx, off, .04)], [.04, .05, .055, .05, .035], sides=5, sub=2)
        C.tube(bk, [c + v(-.44 * sx, off * 1.32, .05), c + v(-.2 * sx, off * 1.32, .335), c + v(.06 * sx, off * 1.32, .385), c + v(.32 * sx, off * 1.32, .27), c + v(.46 * sx, off * 1.32, .05)], [.012, .018, .018, .018, .012], sides=4, sub=2)
    for i in range(7):
        a = i / 7 * 6.2832
        rivet(B['edge'], c + v(math.cos(a) * .475, math.sin(a) * .455, .13), .022)
on('upperarm.l')
pauldron(shL, 1)
PC = shL + v(.1, 0, .56)
ring(ir, PC + v(0, 0, -.11), XX * .25, YY * .25, .03, n=10, sides=5); ring(ir, PC + v(0, 0, .16), XX * .2, YY * .2, .026, n=10, sides=5)
for i in range(6):
    a = i / 6 * 6.2832
    d = V((math.cos(a), math.sin(a), 0))
    C.tube(ir, [PC + d * .25 + v(0, 0, -.11), PC + d * .22 + v(0, 0, .16), PC + d * .08 + v(0, 0, .26)], [.024, .022, .018], sides=5, sub=1)
mini_skull(PC + v(0, 0, .0), 1.25, glow=True)
on('upperarm.r')
pauldron(shR, -1)
for off, tip in ((v(-.2, 0, .3), v(-.5, .02, .8)), (v(-.52, -.2, .18), v(-.98, -.3, .52)), (v(-.46, .26, .22), v(-.88, .46, .62))):
    spike(b, shR + off, shR + tip, .13, sides=6, bend=v(-.02, 0, -.05))

# ---- arms: bone upper arm, armoured Popeye forearm, huge fists
def arm_mesh(sh, el, wr, hd, up, lo, hn, sx):
    on(up)
    C.tube(b, [sh, sh.lerp(el, .5), el], [.14, .1, .13], sides=7, sub=1)
    ring(ir, sh.lerp(el, .62), XX * .155, YY * .155, .03, n=10, sides=5)
    on(lo)
    C.blob(ir, el, (.18, .18, .18), seg=9, rings=6, p=2.4)
    spike(ir, el + v(sx * .08, .1, 0), el + v(sx * .34, .34, -.04), .09, sides=5)
    d = (wr - el).normalized(); o = el + d * .06
    C.tube(ir, [o, el.lerp(wr, .55), wr], [.19, .27, .25], sides=9, sub=2)
    C.tube(B['rust'], [wr - d * .02, wr + d * .03], [.27, .26], sides=9, sub=1)
    on(hn)
    C.blob(ir, hd, (.235, .22, .22), seg=10, rings=6, p=2.5)
    for i in range(4):
        q = hd + v((i - 1.5) * .105, -.2, -.05)
        C.blob(b, q, (.056, .056, .056), seg=6, rings=4)
        spike(ir, q + v(0, -.02, .0), q + v((i - 1.5) * .02, -.13, -.02), .036, sides=4)
arm_mesh(shL, elL, wrL, hdL, 'upperarm.l', 'lowerarm.l', 'hand.l', 1)
arm_mesh(shR, elR, wrR, hdR, 'upperarm.r', 'lowerarm.r', 'hand.r', -1)
# chain wound round the key forearm
on('lowerarm.l')
for i in range(12):
    a = i * .85
    k = i / 11
    p = elL.lerp(wrL, .15 + k * .7)
    q = p + V((math.cos(a) * .3, math.sin(a) * .3, 0))
    link(ir, q, V((-math.sin(a), math.cos(a), .2)).normalized(), ZZ, .065, .04, .016)

# ---- the keys: chain from the fist to a colossal ring. Tilted to the top-down camera (a cheat that reads).
c0_ = hdL + v(0, -.02, -.2)
c1_ = c0_ + v(0, 0, -.11); c2_ = c1_ + v(0, 0, -.11)
RD = v(0, -.6, -.8).normalized(); RU = XX
RR = .34
Rc = c2_ + RD * RR; Rb = c2_ + RD * RR * 2
on('chain.1'); chain_links(ir, c0_, c1_, 2, .05, .036, .017)
on('chain.2'); chain_links(ir, c1_, c2_, 2, .05, .036, .017)
on('ring')
ring(ir, Rc, RU * RR, RD * RR, .05, n=18, sides=7)
ring(B['rust'], Rc, RU * (RR + .02), RD * (RR + .02), .022, n=18, sides=5)
C.blob(ir, c2_ + RD * .02, (.08, .07, .09), seg=8, rings=5, p=2.4)
on('keys')
def key(a, L):
    # a: angle round the ring from straight down, the key hangs out radially and gravity pulls it down a bit
    o = Rc + RD * (RR * math.cos(a)) + RU * (RR * math.sin(a))
    d = (RD * math.cos(a) + RU * math.sin(a) * .9 + V((0, 0, -.45))).normalized()
    wd = d.cross(RD.cross(RU)).normalized()
    bw = o + d * .1
    ring(br, bw, wd * .085, d * .1, .024, n=10, sides=5)
    C.tube(br, [bw + d * .09, bw + d * L], [.032, .028], sides=6, sub=1)
    e_ = bw + d * L
    C.blob(br, bw + d * .11, (.04, .04, .04), seg=6, rings=4)
    # bit: two chunky teeth
    for k, wid in ((-.02, .12), (-.1, .085)):
        q = e_ + d * k
        C.tube(br, [q, q + wd * wid], [(.026, .022), (.026, .022)], sides=4, sub=1, side=d)
    C.tube(br, [e_ + d * -.14 + wd * .1, e_ + wd * .1], [.012, .012], sides=4, sub=1)
for a, L in ((-1.25, .34), (-.72, .36), (-.24, .32), (.26, .3), (.74, .38), (1.25, .32)):
    key(a, L)
mini_skull(Rb + V((0, -.04, -.1)) + RU * .08, 1.05, glow=True)

# ---- the cleaver: a slab of black iron with a bone spine, chewed edge, dragged by its tip
on('hand.r')
grip = hdR.copy()
CL = 2.3
A0 = v(-.86, .4, -.27).normalized()
_seed = v(-.05, -.62, .78)
E0 = A0.cross(_seed).normalized()
if E0.z > 0: E0 = -E0
N0 = A0.cross(E0)
on('weapon')
def bp(u, w, t=0): return grip + A0 * u + E0 * w + N0 * t
C.tube(B['leather'], [bp(-.2, 0), bp(.38, 0)], [.06, .056], sides=6, sub=1)
for u in (-.12, -.02, .1, .22):
    ring(ir, bp(u, 0) , E0 * .07, N0 * .07, .012, n=8, sides=4) if u in (-.12, .22) else None
mini_skull(bp(-.31, 0), 1.25, face=A0 * -1 if False else v(0, -.8, .6).normalized())
C.blob(ir, bp(.42, .1), (.13, .13, .13), seg=8, rings=5, p=2.6)
ST = [(.36, .24), (.46, .36), (.64, .46), (.82, .5), (.86, .4), (.92, .53), (1.2, .6), (1.27, .49), (1.34, .63), (1.7, .71), (1.77, .58), (1.84, .73), (2.12, .8), (2.3, .68)]
def wsp(u): return 0 if u < 1.92 else (u - 1.92) / .38 * .24
vs_body, fs_body, vs_edge, fs_edge = [], [], [], []
T = .06
for i, (u, we) in enumerate(ST):
    s_ = wsp(u); m = s_ + (we - s_) * .7
    vs_body += [bp(u, s_, T), bp(u, m, T * .85), bp(u, m, -T * .85), bp(u, s_, -T)]
    vs_edge += [bp(u, m, T * .85), bp(u, we, 0), bp(u, m, -T * .85)]
for i in range(len(ST) - 1):
    for k in range(4):
        a_, b_ = i * 4 + k, i * 4 + (k + 1) % 4
        fs_body.append((a_, b_, b_ + 4, a_ + 4))
    for k in range(2):
        a_, b_ = i * 3 + k, i * 3 + k + 1
        fs_edge.append((a_, b_, b_ + 3, a_ + 3))
    a_, b_ = i * 3 + 2, i * 3
    fs_edge.append((a_, b_, b_ + 3, a_ + 3))
n_ = len(ST) - 1
fs_body += [(0, 1, 2, 3), (n_ * 4 + 3, n_ * 4 + 2, n_ * 4 + 1, n_ * 4)]
fs_edge += [(0, 1, 2), (n_ * 3 + 2, n_ * 3 + 1, n_ * 3)]
B['slab'].add(vs_body, fs_body); B['edge'].add(vs_edge, fs_edge)
# bone spine with hooked vertebrae, a glowing crack in the slab, rivets
C.tube(b, [bp(.36, -.02), bp(1.2, -.03), bp(2.12, .03)], [.1, .085, .05], sides=7, sub=2)
for i, u in enumerate((.55, .85, 1.15, 1.45, 1.75, 2.02)):
    C.blob(b, bp(u, -.05), (.1, .1, .1), seg=7, rings=4)
    if i % 2 == 0:
        spike(b, bp(u, -.06), bp(u - .08, -.34 + i * .02), .07, sides=5)
for th in (1, -1):
    C.tube(nc, [bp(1.02, .2, th * .062), bp(1.22, .3, th * .062), bp(1.3, .22, th * .062), bp(1.5, .36, th * .062), bp(1.58, .3, th * .062)], [.03, .018, .026, .014, .003], sides=4, sub=1, tval=.75)
    for u in (.5, .95, 1.4, 1.85):
        rivet(B['edge'], bp(u, .13, th * .065), .026)

# ---- legs: bone thigh, iron knee, greave, an anvil of a boot
def leg_mesh(hp, kn, an, up, lo, ft, sx):
    on(up)
    C.tube(b, [hp, hp.lerp(kn, .5), kn], [.13, .095, .12], sides=7, sub=1)
    C.blob(b, hp, (.16, .16, .16), seg=8, rings=5)
    on(lo)
    C.blob(ir, kn, (.17, .17, .17), seg=9, rings=6, p=2.4)
    spike(ir, kn + v(0, -.12, .02), kn + v(sx * .03, -.38, .16), .08, sides=5)
    C.tube(ir, [kn.lerp(an, .1), kn.lerp(an, .55), an + v(0, 0, .03)], [.135, .19, .2], sides=8, sub=1)
    C.tube(B['rust'], [kn.lerp(an, .7), kn.lerp(an, .78)], [.2, .205], sides=8, sub=1)
    on(ft)
    C.blob(ir, v(an.x, an.y - .14, .15), (.27, .4, .15), seg=10, rings=6, p=2.8)
    C.blob(bk, v(an.x, an.y - .12, .025), (.25, .37, .025), seg=8, rings=3, p=2.5)
    C.blob(ir, v(an.x, an.y + .02, .26), (.2, .23, .1), seg=8, rings=4, p=2.4)
    for i in range(3):
        q = v(an.x + (i - 1) * .14, an.y - .42, .09)
        spike(b, q, q + v((i - 1) * .03, -.22, -.07), .062, sides=5)
leg_mesh(hpL, knL, anL, 'upperleg.l', 'lowerleg.l', 'foot.l', 1)
leg_mesh(hpR, knR, anR, 'upperleg.r', 'lowerleg.r', 'foot.r', -1)

HEAD_S = 1.18; HEAD_R = Euler((math.radians(-20), 0, 0), 'XYZ').to_matrix()
def hx(p): return H + HEAD_R @ ((V(p) - H) * HEAD_S)
for bag in B.values():
    for i, n in enumerate(bag.bn):
        if n in ('head', 'jaw', 'crownfire'): bag.v[i] = hx(bag.v[i])

col = scn.collection
objs = {}
NO_INK = ('socket', 'necro', 'teeth', 'black')
for k, bag in B.items():
    if not bag.v: continue
    objs[k], t = C.make_obj(k, bag, M, col, outline=0 if k in NO_INK else .012)
print('tris', sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs.values()))
_all = [p for bag in B.values() for p in bag.v]
print('  lowest:', ', '.join('%s %.2f' % (k, min(p.z for p in bag.v)) for k, bag in B.items() if bag.v and min(p.z for p in bag.v) < .02))
print('  bounds z %.2f..%.2f  x %.2f..%.2f  y %.2f..%.2f' % (min(p.z for p in _all), max(p.z for p in _all), min(p.x for p in _all), max(p.x for p in _all), min(p.y for p in _all), max(p.y for p in _all)))

# ------------------------------------------------------------------ rig
r_top = c2_
bones = {
    'root': (V((0, 0, 0)), V((0, 0, .3)), None),
    'hips': (hip, hip + v(0, -.04, .22), 'root'),
    'spine': (hip + v(0, -.04, .22), chest, 'hips'),
    'chest': (chest, neck, 'spine'),
    'head': (neck + v(0, -.06, .02), hx(H + v(0, 0, .5)), 'chest'),
    'jaw': (hx(H + v(0, -.04, -.2)), hx(J0 + v(0, -.3, -.02)), 'head'),
    'crownfire': (hx(H + v(0, .06, .46)), hx(H + v(0, .06, .7)), 'head'),
    'heart': (Hc, Hc + v(0, 0, .3), 'chest'),
    'door.l': (HINGE[1], HINGE[1] + v(0, 0, 1), 'chest'),
    'door.r': (HINGE[-1], HINGE[-1] + v(0, 0, 1), 'chest'),
    'upperarm.l': (shL, elL, 'chest'), 'lowerarm.l': (elL, wrL, 'upperarm.l'), 'hand.l': (wrL, hdL, 'lowerarm.l'),
    'chain.1': (c0_, c1_, 'hand.l'), 'chain.2': (c1_, c2_, 'chain.1'), 'ring': (c2_, Rb, 'chain.2'), 'keys': (Rb, Rb + v(0, 0, -.4), 'ring'),
    'upperarm.r': (shR, elR, 'chest'), 'lowerarm.r': (elR, wrR, 'upperarm.r'), 'hand.r': (wrR, hdR, 'lowerarm.r'),
    'weapon': (grip, grip + A0 * CL, 'hand.r'),
    'upperleg.l': (hpL, knL, 'hips'), 'lowerleg.l': (knL, anL, 'upperleg.l'), 'foot.l': (anL, anL + v(0, -.4, -.12), 'lowerleg.l'),
    'upperleg.r': (hpR, knR, 'hips'), 'lowerleg.r': (knR, anR, 'upperleg.r'), 'foot.r': (anR, anR + v(0, -.4, -.12), 'lowerleg.r'),
    'tabard': (hip + v(0, -.3, .02), hip + v(0, -.36, -.62), 'hips'),
    'cape': (v(0, .55, 2.0), v(0, .78, 1.1), 'chest'),
}
R = CR.Rig('WardenRig', bones)
for k, o in objs.items():
    if k == 'cloth': R.skin_soft(o, ('hips', 'tabard'), power=3)
    elif k == 'cape': R.skin_soft(o, ('chest', 'cape'), power=3)
    else:
        idx = {}
        for i, n in enumerate(B[k].bn): idx.setdefault(n, []).append(i)
        for n, ids in idx.items():
            o.vertex_groups.new(name=n).add(ids, 1, 'REPLACE')
        R._bind(o)
C.ink_pass(scale=2.0)

# ------------------------------------------------------------------ pose helpers
# World-axis pose maths: with e = a bone's pose rotation, its deformation is D = D_parent @ e and its head lands at
# P = P_parent + D_parent @ (head0 + loc - parent_head0). Everything below (IK, chain, arm targets) builds on that.
NAMES = list(bones)
PAR = {n: bones[n][2] for n in NAMES}
HEAD = {n: V(bones[n][0]) for n in NAMES}
TAIL = {n: V(bones[n][1]) for n in NAMES}
LEN = {n: (TAIL[n] - HEAD[n]).length for n in NAMES}
def parse(spec):
    rot = spec.get('rot', (0, 0, 0)) if isinstance(spec, dict) else spec
    loc = spec.get('loc', (0, 0, 0)) if isinstance(spec, dict) else (0, 0, 0)
    return Euler([math.radians(a) for a in rot], 'XYZ').to_quaternion(), V(loc)
def deg(q):
    e = q.to_euler('XYZ')
    return tuple(math.degrees(a) for a in e)
def fk(state):
    D, P = {}, {}
    for n in NAMES:
        e, loc = state.get(n, (Q(), V()))
        p = PAR[n]
        if p is None:
            D[n] = e; P[n] = HEAD[n] + loc
        else:
            D[n] = D[p] @ e; P[n] = P[p] + D[p] @ (HEAD[n] + loc - HEAD[p])
    return D, P
def two_bone(a, t, l1, l2, pole):
    d = t - a; dist = max(abs(l1 - l2) + .02, min(d.length, l1 + l2 - .002))
    dn = d.normalized(); t2 = a + dn * dist
    k = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist); h = math.sqrt(max(0, l1 * l1 - k * k))
    pv = pole - dn * pole.dot(dn)
    if pv.length < 1e-4: pv = V((1, 0, 0)) - dn * dn.x
    return a + dn * k + pv.normalized() * h, t2
def frame(a, e):
    a = a.normalized(); e = (e - a * e.dot(a)).normalized(); n = a.cross(e)
    return Matrix((a, e, n)).transposed().to_quaternion()
F0 = frame(A0, E0)
A0H, E0H = (hdR - wrR).normalized(), E0
def arm(pose, side, wrist, pole=None, long=None, edge=None):
    """Sets the arm so the wrist lands on a root-space target; `long`/`edge` aim the blade (or `long` the fist on the key arm)."""
    S = {n: parse(pose[n]) for n in pose if n in bones}
    D, P = fk(S)
    u, l, h = 'upperarm.' + side, 'lowerarm.' + side, 'hand.' + side
    sx = 1 if side == 'l' else -1
    pole = pole or v(sx, .35, -.5)
    mid, t2 = two_bone(P[u], V(wrist), LEN[u], LEN[l], V(pole))
    Du = (TAIL[u] - HEAD[u]).rotation_difference(mid - P[u])
    Dl = (TAIL[l] - HEAD[l]).rotation_difference(t2 - mid)
    out = dict(pose)
    out[u] = deg(D['chest'].inverted() @ Du); out[l] = deg(Du.inverted() @ Dl)
    if long is not None:
        if side == 'r':
            Dh = frame(V(long), V(edge)) @ F0.inverted()
        else:
            Dh = (TAIL[h] - HEAD[h]).rotation_difference(V(long))
        out[h] = deg(Dl.inverted() @ Dh)
    return out
def P_(*ds):
    out = {}
    for d in ds: out.update(d)
    return out

def _ease(k, kind): return CR._ease(k, kind)
ALL_ACTS = {}
def A(name, length, keys, loop=False, over=None, whirl=None, heart=None):
    """Key poses -> dense per-frame poses with leg IK and the chain sim -> Rig.action.
    A key may carry 'F.l'/'F.r' = (dx, dy, dz, pitch): foot offset from rest (root space). Absent = planted.
    over: {bone: f(frame) -> rot}. whirl: (on0, on1, off0, off1, revs): the chain spins flat round the hand.
    heart: {frame: scale}; default a slow pulse."""
    items = sorted(((k if isinstance(k, tuple) else (k, 'smooth')) + (p,)) for k, p in keys.items()) if False else None
    items = []
    for k, p in keys.items():
        f, e = k if isinstance(k, tuple) else (k, 'smooth')
        items.append((f, e, p))
    items.sort(key=lambda x: x[0])
    cached = [{n: parse(p[n]) if n in p else (Q(), V()) for n in NAMES} for _, _, p in items]
    feet = [{s: V(p.get('F.' + s, (0, 0, 0, 0))) if False else tuple(p.get('F.' + s, (0, 0, 0, 0))) for s in 'lr'} for _, _, p in items]
    def seg_at(fr):
        if fr <= items[0][0]: return 0, 0, 0.0
        if fr >= items[-1][0]: return len(items) - 1, len(items) - 1, 0.0
        for i in range(len(items) - 1):
            if items[i][0] <= fr < items[i + 1][0]:
                k = (fr - items[i][0]) / (items[i + 1][0] - items[i][0])
                return i, i + 1, _ease(k, items[i + 1][1])
    def state_at(fr):
        i, j, k = seg_at(fr)
        st = {n: (cached[i][n][0].slerp(cached[j][n][0], k), cached[i][n][1].lerp(cached[j][n][1], k)) for n in NAMES}
        ft = {s: tuple(feet[i][s][c] + (feet[j][s][c] - feet[i][s][c]) * k for c in range(4)) for s in 'lr'}
        if over:
            for n, fn in over.items(): st[n] = (parse(fn(fr))[0], st[n][1])
        return st, ft
    def legs(st, ft):
        # solved in root space: root sits above everything and carries the feet with it
        eh, lh = st['hips']
        Dh = eh; Ph = HEAD['hips'] + lh
        for s in 'lr':
            u, l, f = 'upperleg.' + s, 'lowerleg.' + s, 'foot.' + s
            hj = Ph + Dh @ (HEAD[u] - HEAD['hips'])
            dx, dy, dz, pitch = ft[s]
            t = HEAD[f] + V((dx, dy, dz))
            rest_pole = (HEAD[l] - HEAD[u]) - (HEAD[f] - HEAD[u]).normalized() * (HEAD[l] - HEAD[u]).dot((HEAD[f] - HEAD[u]).normalized())
            mid, t2 = two_bone(hj, t, LEN[u], LEN[l], rest_pole + V((0, -.2, 0)))
            Du = (TAIL[u] - HEAD[u]).rotation_difference(mid - hj)
            Dl = (TAIL[l] - HEAD[l]).rotation_difference(t2 - mid)
            Df = Euler((math.radians(pitch), 0, 0), 'XYZ').to_quaternion()
            st[u] = (Dh.inverted() @ Du, V()); st[l] = (Du.inverted() @ Dl, V()); st[f] = (Dl.inverted() @ Df, V())
    segs = ['chain.1', 'chain.2', 'ring', 'keys']
    lens = [LEN['chain.1'], LEN['chain.2'], LEN['ring'], .28]
    floors = [.2, .2, .12, -.06]
    dn = V((0, 0, -1))
    def attach(st):
        D, P = fk(st)
        return P['chain.1'], D['hand.l']
    st0, ft0 = state_at(0); legs(st0, ft0)
    x0, _ = attach(st0)
    nodes = [x0.copy()]
    for L in lens: nodes.append(nodes[-1] + dn * L)
    prev = [n.copy() for n in nodes]
    theta = [0.0]
    def step(fr):
        st, ft = state_at(fr); legs(st, ft)
        x, Dh = attach(st)
        G = V((0, 0, -.024))
        for i in range(1, len(nodes)):
            vel = (nodes[i] - prev[i]) * .9
            prev[i] = nodes[i].copy()
            nodes[i] = nodes[i] + vel + G
        nodes[0] = x.copy()
        for _ in range(5):
            for i in range(len(lens)):
                d = nodes[i + 1] - nodes[i]
                d = d.normalized() * lens[i] if d.length > 1e-6 else dn * lens[i]
                nodes[i + 1] = nodes[i] + d
                nodes[i + 1].z = max(nodes[i + 1].z, floors[i])
        if whirl:
            on0, on1, off0, off1, revs = whirl
            if fr <= on1: w = max(0, min(1, (fr - on0) / max(1, on1 - on0)))
            else: w = max(0, min(1, 1 - (fr - off0) / max(1, off1 - off0)))
            theta[0] += revs * 6.2832 * (.25 + .75 * w)
            if w > 0:
                q = nodes[0].copy()
                for i, L in enumerate(lens):
                    a = theta[0] - i * .42
                    d = V((math.cos(a) * .9, math.sin(a) * .9, .36)).normalized()
                    q = q + d * L
                    nodes[i + 1] = nodes[i + 1].lerp(q, w)
        Dp = Dh
        for i, s in enumerate(segs):
            Dw = dn.rotation_difference((nodes[i + 1] - nodes[i]).normalized())
            st[s] = (Dp.inverted() @ Dw, V())
            Dp = Dw
        return st
    if loop:
        for fr in range(length): step(fr)
    poses = {}
    for fr in range(length + 1):
        st = step(fr)
        pose = {}
        for n in NAMES:
            e, loc = st[n]
            if loc.length > 1e-6 or n == 'hips':
                pose[n] = {'rot': deg(e), 'loc': tuple(loc + V((0, 0, 1e-5)) if n == 'hips' else loc)}
            else:
                pose[n] = deg(e)
        poses[fr] = pose
    a = R.action(name, length, poses)
    # heart scale: not in the kit's pose format, keyed straight onto the action so the flare exports too
    pb = R.obj.pose.bones['heart']
    hk = sorted((heart or {0: 1.0, length // 2: 1.07, length: 1.0}).items())
    N = length + 1
    def hs(fr):
        if fr <= hk[0][0]: return hk[0][1]
        if fr >= hk[-1][0]: return hk[-1][1]
        for i in range(len(hk) - 1):
            if hk[i][0] <= fr < hk[i + 1][0]:
                k = (fr - hk[i][0]) / (hk[i + 1][0] - hk[i][0]); k = k * k * (3 - 2 * k)
                return hk[i][1] + (hk[i + 1][1] - hk[i][1]) * k
    def cf(x): return x if x < .4 else 1 + (x - 1) * .35   # the crown follows the heart at a third of the swell, and dies with it
    for bn, fn in (('heart', lambda x: x), ('crownfire', cf)):
        pb = R.obj.pose.bones[bn]
        for idx in range(3):
            fc = a.fcurve_ensure_for_datablock(R.obj, pb.path_from_id('scale'), index=idx)
            fc.keyframe_points.add(N)
            co = [0.0] * (2 * N)
            for j in range(N): co[2 * j] = j; co[2 * j + 1] = max(.001, fn(hs(j)))
            fc.keyframe_points.foreach_set('co', co); fc.keyframe_points.foreach_set('interpolation', [1] * N); fc.update()
    ALL_ACTS[name] = length
    return a

# ------------------------------------------------------------------ animation (24 fps). Windups from boss.gd ATTACKS:
# cleave 20f, slam 24f + 13f air, nova 26f, spikes 22f, cage 24f. Recoveries 22, 26, 19, 24, 29.
HR = (A0, E0)
def body(hz=-.04, hy=0, hx=0, pitch=4, yaw=0, roll=0, ch=(5, 0, 0), hd=(-5, 0, 0), jaw=(4, 0, 0), **extra):
    d = {'hips': {'rot': (pitch, roll, yaw), 'loc': (hx, hy, hz)}, 'chest': ch, 'head': hd, 'jaw': jaw}
    d.update(extra)
    return d
def idle(hz, ch, hd, jaw, wl=(0, 0, 0), wr=(0, 0, 0), **extra):
    p = body(hz=hz, pitch=4, ch=ch, hd=hd, jaw=jaw, **extra)
    p = arm(p, 'l', wrL + V(wl))
    return arm(p, 'r', wrR + V(wr), long=A0, edge=E0)

I_A = idle(-.05, (5, 0, 0), (-6, 0, 2), (4, 0, 0))
I_B = idle(-.12, (10, 0, -2), (-10, 0, -3), (12, 0, 0), wl=(.02, 0, -.05), wr=(-.02, 0, 0), cape=(4, 0, 0))
A('Idle_Combat', 56, {0: I_A, 28: I_B, 56: I_A}, loop=True, heart={0: 1.0, 14: 1.14, 28: .96, 42: 1.1, 56: 1.0})

# heavy stomp: lift slow, drop fast, the whole frame shudders on contact. The cleaver tip scrapes behind.
S = .4
def walk(s, t):
    """s=+1: left foot is the stance foot moving back and right foot swinging through. t 0..1 across the half cycle."""
    back = -S + 2 * S * t
    lift = math.sin(min(1, t * 1.05) * math.pi) ** .8 * .42
    swing_pitch = (20 * math.sin(t * 6.28))
    stance, swing = ('F.l', 'F.r') if s > 0 else ('F.r', 'F.l')
    sink = max(0, .1 - t) * 1.6
    hz = -.22 + .2 * math.sin(t * math.pi) - sink
    p = body(hz=hz, hy=-.08, pitch=9, roll=s * (6 - 3 * t), yaw=s * (5 - 10 * t),
             ch=(9, s * 3, -s * (9 - 18 * t)), hd=(-8, 0, s * (5 - 10 * t)), jaw=(4 + 10 * sink / .16, 0, 0),
             tabard=(-14 + 10 * math.sin(t * 3.14), 0, 0), cape=(8 + 8 * math.sin(t * 3.14), 0, 0), **{'door.l': (0, 0, 3 * sink / .16), 'door.r': (0, 0, -3 * sink / .16)})
    p[stance] = (0, back, 0, 0)
    p[swing] = (0, -back, lift, swing_pitch)
    sw = -s * (.22 - .44 * t)
    p = arm(p, 'l', wrL + V((0, sw, .06 * math.sin(t * 3.14) - .02)))
    return arm(p, 'r', wrR + V((0, -sw * .5, -.03 * (1 - t))), long=A0, edge=E0)
_wk = {}
for f, s, t in ((0, 1, 0), (3, 1, .1), (9, 1, .55), (13, 1, .8), (16, -1, 0), (19, -1, .1), (25, -1, .55), (29, -1, .8), (32, 1, 0)):
    key = (f, 'in') if f in (16, 32) else f
    _wk[key] = walk(s, t)
A('Walking_D_Skeletons', 32, _wk, loop=True, heart={0: 1.0, 2: 1.12, 8: 1.0, 16: 1.0, 18: 1.12, 24: 1.0, 32: 1.0})

# cleave: a full spin. Wound the wrong way for 17 frames, unwinds into a flat sweep, cleaver level at full reach.
def _spin(f):
    if f < 17: return (0, 0, -34 * CR._ease(min(1, f / 15), 'smooth'))
    if f >= 26: return (0, 0, 0)
    k = (f - 17) / 9
    return (0, 0, -34 + 394 * (k * k * (3 - 2 * k)))
CL_0 = I_A
CL_W = arm(arm(body(hz=-.32, hy=.12, pitch=-2, yaw=-14, ch=(-6, 0, -26), hd=(6, 0, 34), jaw=(16, 0, 0), tabard=(-14, 0, 0), cape=(-8, 0, 0)),
           'l', v(1.1, -1.0, 2.0)), 'r', v(-1.65, .95, 2.05), long=v(-.45, .88, .1), edge=v(.1, .1, -1))
CL_H = arm(arm(body(hz=-.36, hy=-.12, pitch=10, yaw=8, ch=(14, 0, 16), hd=(-10, 0, -10), jaw=(30, 0, 0), tabard=(-20, 0, 0), cape=(26, 0, 0), **{'F.l': (.12, 0, 0, 0), 'F.r': (-.12, 0, 0, 0)}),
           'l', v(1.6, .55, 1.95)), 'r', v(-2.05, -.6, 1.75), long=v(-.95, -.3, .04), edge=v(-.26, .97, -.1))
CL_F = arm(arm(body(hz=-.3, hy=-.08, pitch=12, yaw=10, ch=(18, 0, 22), hd=(-12, 0, -16), jaw=(22, 0, 0), tabard=(-16, 0, 0), cape=(8, 0, 0), **{'F.l': (.12, 0, 0, 0), 'F.r': (-.12, 0, 0, 0)}),
           'l', v(1.55, .3, 1.8)), 'r', v(-1.95, -.75, 1.45), long=v(-.85, -.42, -.28), edge=v(-.32, .9, -.3))
A('Attack_Cleave', 42, {0: CL_0, (17, 'out'): CL_W, (20, 'in'): CL_H, 26: CL_H, 32: CL_F, 42: I_A}, over={'root': _spin}, heart={0: 1, 17: 1.2, 21: 1.5, 30: 1, 42: 1})

# slam: deep crouch, launch, hang with the cleaver over the head, comes down in 3 frames and stays down
SL_C = arm(arm(body(hz=-.52, hy=.18, pitch=16, ch=(22, 0, 0), hd=(-28, 0, 0), jaw=(10, 0, 0), tabard=(-30, 0, 0), cape=(20, 0, 0)),
           'l', v(1.55, .85, .95)), 'r', v(-1.65, 1.0, 1.05), long=v(-.3, .9, -.2), edge=v(0, .2, -1))
SL_L = arm(arm(body(hz=.28, hy=-.15, pitch=-6, ch=(-10, 0, 0), hd=(0, 0, 0), jaw=(26, 0, 0), tabard=(10, 0, 0), cape=(30, 0, 0), **{'F.l': (0, 0, .02, 30), 'F.r': (0, 0, .02, 30)}),
           'l', v(1.1, -.5, 3.2)), 'r', v(-1.05, -.65, 3.3), long=v(-.25, .25, .94), edge=v(0, -.95, .25))
SL_A = arm(arm(body(hz=1.5, hy=-.25, pitch=-14, ch=(-16, 0, 0), hd=(6, 0, 0), jaw=(34, 0, 0), tabard=(24, 0, 0), cape=(44, 0, 0), **{'F.l': (0, .06, 1.0, 34), 'F.r': (0, .1, .82, 26)}),
           'l', v(1.15, -.3, 4.85)), 'r', v(-.95, -.25, 5.0), long=v(-.05, .72, .7), edge=v(0, .7, -.72))
SL_B = arm(arm(body(hz=1.56, hy=-.32, pitch=-8, ch=(-12, 0, 0), hd=(4, 0, 0), jaw=(30, 0, 0), tabard=(28, 0, 0), cape=(50, 0, 0), **{'F.l': (0, .02, 1.06, 30), 'F.r': (0, .06, .9, 22)}),
           'l', v(1.2, -.3, 4.85)), 'r', v(-1.0, -.2, 5.05), long=v(-.05, .85, .52), edge=v(0, .52, -.85))
SL_H = arm(arm(body(hz=-.55, hy=-.3, pitch=22, ch=(22, 0, 0), hd=(-40, 0, 0), jaw=(42, 0, 0), tabard=(-34, 0, 0), cape=(-20, 0, 0), **{'F.l': (.1, 0, 0, 0), 'F.r': (-.1, 0, 0, 0)}),
           'l', v(1.4, -1.25, .42)), 'r', v(-.95, -1.5, .95), long=v(-.3, -.9, -.32), edge=v(-.75, -.05, -.65))
SL_S = arm(arm(body(hz=-.48, hy=-.24, pitch=18, ch=(18, 0, 0), hd=(-32, 0, 0), jaw=(20, 0, 0), tabard=(-28, 0, 0), **{'F.l': (.1, 0, 0, 0), 'F.r': (-.1, 0, 0, 0)}),
           'l', v(1.45, -1.1, .55)), 'r', v(-1.0, -1.4, 1.05), long=v(-.32, -.88, -.34), edge=v(-.75, -.05, -.65))
SL_R = arm(arm(body(hz=-.28, hy=-.1, pitch=10, ch=(10, 0, 0), hd=(-14, 0, 0), jaw=(10, 0, 0), tabard=(-14, 0, 0)),
           'l', v(1.45, -.75, 1.05)), 'r', v(-1.4, -.8, 1.4), long=v(-.84, -.1, -.3), edge=E0)
A('Attack_Slam', 63, {0: I_A, (20, 'out'): SL_C, 24: SL_L, (28, 'out'): SL_A, 34: SL_B, (37, 'in'): SL_H, 43: SL_H, 50: SL_S, 56: SL_R, 63: I_A},
  heart={0: 1, 20: 1.2, 28: 1.4, 37: 1.8, 45: 1.1, 63: 1})

# nova: curls round the heart as it dims, then throws everything open. Doors swing wide, heart goes huge.
NV_W = arm(arm(body(hz=-.36, hy=.05, pitch=16, ch=(26, 0, 0), hd=(-16, 0, 0), jaw=(0, 0, 0), tabard=(-20, 0, 0), cape=(10, 0, 0), **{'door.l': (0, 0, -2), 'door.r': (0, 0, 2)}),
           'l', v(.5, -1.3, 1.5), pole=v(1, .2, -.6)), 'r', v(-.5, -1.25, 1.65), pole=v(-1, .2, -.6), long=v(-.92, .1, .35), edge=v(.1, -.9, -.4))
NV_X = arm(arm(body(hz=-.4, hy=.05, pitch=19, ch=(30, 0, 0), hd=(-20, 0, 0), jaw=(0, 0, 0), tabard=(-22, 0, 0), cape=(12, 0, 0), **{'door.l': (0, 0, 1), 'door.r': (0, 0, -1)}),
           'l', v(.45, -1.3, 1.42), pole=v(1, .2, -.6)), 'r', v(-.45, -1.25, 1.55), pole=v(-1, .2, -.6), long=v(-.92, .1, .35), edge=v(.1, -.9, -.4))
NV_F = arm(arm(body(hz=.02, hy=.16, pitch=-14, ch=(-24, 0, 0), hd=(12, 0, 0), jaw=(36, 0, 0), tabard=(12, 0, 0), cape=(26, 0, 0), **{'door.l': (0, 0, 112), 'door.r': (0, 0, -112), 'F.l': (.08, 0, 0, 0), 'F.r': (-.08, 0, 0, 0)}),
           'l', v(2.5, .1, 2.75)), 'r', v(-2.5, .1, 2.8), long=v(-.9, .1, .42), edge=v(.25, -.75, .6))
NV_G = arm(arm(body(hz=-.06, hy=.12, pitch=-9, ch=(-16, 0, 0), hd=(8, 0, 0), jaw=(24, 0, 0), tabard=(4, 0, 0), cape=(12, 0, 0), **{'door.l': (0, 0, 92), 'door.r': (0, 0, -96), 'F.l': (.08, 0, 0, 0), 'F.r': (-.08, 0, 0, 0)}),
           'l', v(2.3, .05, 2.3)), 'r', v(-2.3, .1, 2.35), long=v(-.9, .1, .1), edge=v(.1, -.75, -.6))
A('Attack_Nova', 45, {0: I_A, (22, 'out'): NV_W, 25: NV_X, (28, 'in'): NV_F, 33: NV_F, 38: NV_G, 45: I_A},
  heart={0: 1, 22: .55, 25: .45, 28: 2.3, 33: 2.2, 38: 1.3, 45: 1})

# spikes: rears back with the key fist up, then punches it through the floor
SP_W = arm(arm(body(hz=-.08, hy=.2, pitch=-16, yaw=10, ch=(-22, 0, 20), hd=(14, 0, -14), jaw=(12, 0, 0), tabard=(6, 0, 0), cape=(-6, 0, 0), **{'F.l': (.05, .02, 0, 0)}),
           'l', v(1.4, .2, 3.35)), 'r', wrR + v(-.2, .3, .1), long=A0, edge=E0)
SP_H = arm(arm(body(hz=-.5, hy=-.34, hx=.2, pitch=20, roll=10, yaw=-10, ch=(16, 14, -12), hd=(-34, 0, 8), jaw=(30, 0, 0), tabard=(-30, 0, 0), cape=(-16, 0, 0), **{'F.l': (.16, -.5, 0, 0), 'F.r': (-.1, .22, 0, 0)}),
           'l', v(1.32, -1.38, .28), pole=v(1, .4, .2)), 'r', v(-1.6, -.1, 1.25), long=A0, edge=E0)
SP_S = arm(arm(body(hz=-.44, hy=-.3, hx=.18, pitch=17, roll=8, yaw=-8, ch=(13, 11, -10), hd=(-28, 0, 6), jaw=(16, 0, 0), tabard=(-26, 0, 0), **{'F.l': (.16, -.5, 0, 0), 'F.r': (-.1, .22, 0, 0)}),
           'l', v(1.32, -1.36, .4), pole=v(1, .4, .2)), 'r', v(-1.6, -.1, 1.28), long=A0, edge=E0)
A('Attack_Spikes', 46, {0: I_A, (19, 'out'): SP_W, (22, 'in'): SP_H, 29: SP_H, 36: SP_S, 46: I_A}, heart={0: 1, 19: 1.15, 22: 1.6, 30: 1.1, 46: 1})

# cage: both arms go up, the chain whirls overhead faster and faster, a stamp sets it off
CG_W = arm(arm(body(hz=-.26, pitch=2, ch=(-6, 0, 0), hd=(-8, 0, 0), jaw=(14, 0, 0), tabard=(-8, 0, 0)),
           'l', v(1.25, -.2, 3.55)), 'r', v(-1.6, .15, 2.6), long=v(-.5, .5, .7), edge=v(-.75, -.4, -.55))
CG_H = arm(arm(body(hz=.02, hy=.05, pitch=-8, ch=(-16, 0, 0), hd=(-14, 0, 0), jaw=(44, 0, 0), tabard=(8, 0, 0), cape=(16, 0, 0), **{'door.l': (0, 0, 14), 'door.r': (0, 0, -14)}),
           'l', v(1.05, -.2, 4.55)), 'r', v(-1.5, -.1, 4.1), long=v(-.32, .1, .94), edge=v(-.9, -.25, -.34))
CG_G = arm(arm(body(hz=-.03, hy=.05, pitch=-5, ch=(-11, 0, 0), hd=(-10, 0, 0), jaw=(30, 0, 0), cape=(8, 0, 0)),
           'l', v(1.1, -.2, 4.3)), 'r', v(-1.55, -.1, 3.9), long=v(-.38, .1, .92), edge=v(-.9, -.25, -.34))
A('Attack_Cage', 53, {0: I_A, (20, 'out'): CG_W, (24, 'in'): CG_H, 31: CG_H, 38: CG_G, 53: I_A}, whirl=(3, 22, 34, 44, .085), heart={0: 1, 20: 1.1, 24: 1.7, 34: 1.2, 53: 1})

# enrage: fists in, then the roar. Everything open, head to the sky, heart blazing.
EN_W = arm(arm(body(hz=-.42, hy=.08, pitch=14, ch=(22, 0, 0), hd=(-22, 0, 0), jaw=(0, 0, 0), tabard=(-24, 0, 0)),
           'l', v(1.05, -.95, 1.2)), 'r', v(-1.1, -.65, 1.15), long=v(-.8, .5, -.34), edge=E0)
EN_R = arm(arm(body(hz=.04, hy=.14, pitch=-16, ch=(-24, 0, 0), hd=(-16, 0, 0), jaw=(58, 0, 0), tabard=(14, 0, 0), cape=(34, 0, 0), **{'door.l': (0, 0, 46), 'door.r': (0, 0, -46), 'F.l': (.1, 0, 0, 0), 'F.r': (-.1, 0, 0, 0)}),
           'l', v(2.15, -.45, 2.05)), 'r', v(-2.15, -.3, 2.05), long=v(-.84, .38, -.3), edge=E0)
EN_T = arm(arm(body(hz=.0, hy=.1, pitch=-12, ch=(-20, 0, 3), hd=(-12, 0, -4), jaw=(50, 0, 0), tabard=(8, 0, 0), cape=(24, 0, 0), **{'door.l': (0, 0, 40), 'door.r': (0, 0, -36), 'F.l': (.1, 0, 0, 0), 'F.r': (-.1, 0, 0, 0)}),
           'l', v(2.05, -.5, 1.9)), 'r', v(-2.15, -.28, 2.0), long=v(-.84, .38, -.3), edge=E0)
A('Enrage', 62, {0: I_A, (16, 'out'): EN_W, (20, 'in'): EN_R, 28: EN_T, 34: EN_R, 40: EN_T, 46: EN_R, 62: I_A}, heart={0: 1, 16: .7, 20: 2.0, 46: 1.9, 62: 1.15})

# hit: it barely flinches. Head snaps, door rattles.
HT = arm(arm(body(hz=-.09, hy=.09, pitch=-3, ch=(-9, 0, 5), hd=(14, 0, -10), jaw=(22, 0, 0), cape=(10, 0, 0), **{'door.l': (0, 0, 16), 'door.r': (0, 0, -10)}),
         'l', wrL + v(.14, .1, .12)), 'r', wrR + v(-.08, .08, .02), long=A0, edge=E0)
A('Hit_A', 16, {0: I_A, (2, 'hold'): HT, 16: I_A}, heart={0: 1, 2: 1.5, 16: 1})

# death: the doors fly open, the heart burns out, it goes down on its knees and dies propped over its cleaver
_kneel = {'F.l': (.02, .52, .08, 40), 'F.r': (-.02, .48, .06, 44)}
DE_1 = arm(arm(body(hz=-.02, hy=.14, pitch=-14, ch=(-22, 0, 8), hd=(-18, 0, -12), jaw=(46, 0, 0), cape=(20, 0, 0), **{'door.l': (0, 0, 96), 'door.r': (0, 0, -84)}),
           'l', wrL + v(.45, .2, .6)), 'r', wrR + v(-.4, .1, .3), long=A0, edge=E0)
DE_2 = arm(arm(body(hz=-.68, hy=.2, pitch=8, ch=(6, 0, 8), hd=(-4, 0, -16), jaw=(40, 0, 0), tabard=(-22, 0, 0), **{'door.l': (0, 0, 70), 'door.r': (0, 0, -60), **_kneel}),
           'l', v(1.35, -.7, .75)), 'r', v(-1.3, -.8, 1.0), long=v(-.9, -.3, -.32), edge=v(-.2, -.8, -.55))
DE_3 = arm(arm(body(hz=-.68, hy=.16, pitch=12, ch=(20, 0, 6), hd=(30, 6, -16), jaw=(34, 0, 0), tabard=(-20, 0, 0), cape=(-6, 0, 0), **{'door.l': (0, 0, 54), 'door.r': (0, 0, -34), **_kneel}),
           'l', v(1.15, -1.1, .32)), 'r', v(-1.2, -1.05, .8), long=v(-.92, -.3, -.24), edge=v(-.15, -.85, -.5))
A('Death_A', 74, {0: I_A, (4, 'hold'): DE_1, 12: DE_1, (28, 'in'): DE_2, 34: DE_2, (52, 'out'): DE_3, 74: DE_3}, heart={0: 1, 4: 2.2, 14: 1.4, 34: .8, 58: .01, 74: .01})
R.obj.animation_data.action = bpy.data.actions['Idle_Combat']

# ------------------------------------------------------------------ checks (read the numbers, not just the pictures)
PB_ = R.obj.pose.bones
print('  rest-sim check: ankle rest z %.3f' % anL.z)
for act, L in ALL_ACTS.items():
    R.play(act, 0)
    lo, hi = 9, -9; tip = (9, 0); fist = (9, 0); top = -9; cg = (9, 0)
    _cinv = R.arm.bones['chest'].matrix_local.inverted(); _pt = v(0, -1.12, Cg.z - .56)
    for f in range(L + 1):
        scn.frame_set(f)
        az = min(PB_['foot.l'].head.z, PB_['foot.r'].head.z)
        lo = min(lo, az); hi = max(hi, az)
        t = PB_['weapon'].tail.z
        if t < tip[0]: tip = (t, f)
        w = PB_['hand.l'].tail.z
        if w < fist[0]: fist = (w, f)
        top = max(top, PB_['hips'].head.z)
        cz = (PB_['chest'].matrix @ _cinv @ _pt).z
        if cz < cg[0]: cg = (cz, f)
    print('  %-22s ankle z %.3f..%.3f  blade-axis tip min %.2f @%d  key fist min %.2f @%d  hips top %.2f  cage-low %.2f @%d' % (act, lo, hi, tip[0], tip[1], fist[0], fist[1], top, cg[0], cg[1]))

R.play('Attack_Cage', 0)
for f in (10, 16, 20, 24, 28, 32):
    scn.frame_set(f)
    h_, t_ = PB_['chain.1'].head, PB_['ring'].tail
    print('  whirl f%d ring end rel. hand: az %.0f deg, radius %.2f, dz %.2f' % (f, math.degrees(math.atan2(t_.y - h_.y, t_.x - h_.x)), math.hypot(t_.x - h_.x, t_.y - h_.y), t_.z - h_.z))
# ------------------------------------------------------------------ proof
C.comic_scene()
hero = C.camera('CamHero', (1.8, -10.6, 2.3), (0, -.2, 1.55), lens=58)
game = C.camera('CamGame', (0, -7.6, 10.6), (-.2, -.1, 1.25), ortho=7.0)
side = C.camera('CamSide', (-12.6, -4.2, 2.4), (-.5, 0, 1.45), lens=58)
sheet_cam = C.camera('CamSheet', (-6, -9, 4.4), (0, 0, 1.5), ortho=6)
SD = (V((0, 0, 1.5)) - V((-6, -9, 4.4))).normalized()
R.play('Idle_Combat', 0)
C.render(os.path.join(OUT, NAME + '_hero.png'), hero)
C.render(os.path.join(OUT, NAME + '_game.png'), game)
C.render(os.path.join(OUT, NAME + '_side.png'), side)

def sheet(frames, out_png, cols=5, tile=384):
    """Own contact sheet: square tiles, the ortho camera refits each frame to the character's extent so poses fill the tile."""
    tmp = tempfile.mkdtemp(prefix='wsheet_')
    res = scn.render.resolution_x, scn.render.resolution_y
    scn.render.resolution_x = scn.render.resolution_y = 640
    C.ASPECT = 1.0
    scn.camera = sheet_cam; scn.render.image_settings.file_format = 'PNG'
    right = SD.cross(ZZ).normalized(); up = right.cross(SD).normalized()
    for i, (a, f) in enumerate(frames):
        R.play(a, f)
        pts = []
        for n in NAMES:
            pb = PB_[n]; pts += [pb.head.copy(), pb.tail.copy()]
        wx = PB_['weapon']; pts.append(wx.head + (wx.tail - wx.head).normalized() * CL)
        xs = [p.dot(right) for p in pts]; ys = [p.dot(up) for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        span = max(max(xs) - min(xs), max(ys) - min(ys)) + 1.3
        sheet_cam.data.ortho_scale = max(4.6, span)
        sheet_cam.location = right * cx + up * cy - SD * 25
        scn.render.filepath = os.path.join(tmp, '%03d.png' % i)
        bpy.ops.render.render(write_still=True)
    rows = math.ceil(len(frames) / cols)
    subprocess.run([r'C:\ffmpeg\bin\ffmpeg.exe', '-y', '-loglevel', 'error', '-framerate', '1', '-i', os.path.join(tmp, '%03d.png'),
                    '-vf', 'scale=%d:-1,tile=%dx%d' % (tile, cols, rows), '-frames:v', '1', out_png], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    scn.render.resolution_x, scn.render.resolution_y = res
FR = [('Idle_Combat', 28), ('Walking_D_Skeletons', 0), ('Walking_D_Skeletons', 9), ('Attack_Cleave', 17), ('Attack_Cleave', 20), ('Attack_Cleave', 30),
      ('Attack_Slam', 20), ('Attack_Slam', 31), ('Attack_Slam', 38), ('Attack_Nova', 25), ('Attack_Nova', 30),
      ('Attack_Spikes', 19), ('Attack_Spikes', 23), ('Attack_Cage', 20), ('Attack_Cage', 28), ('Attack_Cage', 31), ('Attack_Slam', 24), ('Walking_D_Skeletons', 25), ('Attack_Nova', 38), ('Death_A', 30), ('Enrage', 16), ('Enrage', 22), ('Hit_A', 2), ('Death_A', 6), ('Death_A', 70)]
sheet(FR, os.path.join(OUT, NAME + '_motion.png'), cols=5, tile=384)  # order: see FR
R.play('Idle_Combat', 0)
CR.export_glb(os.path.join(OUT, NAME + '.glb'), R)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, NAME + '.blend'))
print('done', NAME)
