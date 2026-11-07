# The ledge (env piece `ledge`, the prince's High Ground): a raised stone block a character can spring from, 1.2 m high,
# two floor tiles wide (8 m) and 2 m deep, with a chibi-scale step along its front (a big 0.55 m stair, 0.6 m deep).
#   blender -b -P tools/comic_art/env_ledge.py   -> ledge.glb + shots, in env_extra.OUT
# Pivot: the middle of its footprint on the floor, front (the step side) toward -Y (Godot +Z at yaw 0), so
# env_piece's box collider (centred on the node, size.y / 2 up) wraps it. It is meant to stand against a wall with its
# back (+Y) on the wall's face. One node, `ledge`.
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import env_extra as X
from env_extra import C, E
from mathutils import Vector as V

HW = 4.0      # half width
HD = 1.0      # half depth
H = 1.2       # top
SH = .55      # step height
SD = .6       # step depth (the step's front is at -HD, the main face at -HD + SD)
FACE = -HD + SD


def blocks_on(p, F, u0, u1, v0, v1, w0, w1, r, rows, mat='stone', min_len=.9, max_len=1.7, inkf=None):
    """Courses of chamfered blocks over a face (F maps (u, v, w) as env_kit's faces), with ink."""
    b = p.b(mat); ink = p.b('ink'); nrm = E.normal(F)
    for i, (a, c) in enumerate(rows):
        u = u0 + (r.uniform(.2, .7) if i % 2 else 0)
        edges = [u0]
        while True:
            u += r.uniform(min_len, max_len)
            if u >= u1 - .5:
                break
            edges.append(u)
        edges.append(u1)
        for k, (x0, x1) in enumerate(zip(edges, edges[1:])):
            t = r.uniform(.38, .66)
            E.block(b, F, x0 + .012, x1 - .012, a + .012, c - .012, w0, w1 + r.uniform(-.008, .008), r, ch=.045, t=t)
            W = w1 + .016
            inb = lambda x, y, x0=x0, x1=x1: x0 + .06 < x < x1 - .06 and a + .05 < y < c - .05
            if r.random() < .45:
                E.crack(ink, F, r, r.uniform(x0 + .15, x1 - .15), c - .07, W, -1.57 + r.uniform(-.5, .5), r.uniform(.25, .45), .022, 1, inb)
            if c - a > .35 and x1 - x0 > .5 and r.random() < .55:
                E.hatch(ink, F, r, x1 - .2, a + .2, W, ang=2.25, n=4, length=min(.28, (c - a) * .5), gap=.05, width=.018)


def build():
    p = E.Piece('ledge'); r = p.r
    v = p.b('void')
    # black core: the main block and the step, inside the stones (the seams show it)
    E.box(v, (-HW + .06, FACE + .06, 0), (HW - .06, HD, H - .06))
    E.box(v, (-HW + .06, -HD + .06, 0), (HW - .06, FACE + .1, SH - .05))
    Ff = E.Ff                                     # faces -Y, w = -y
    # the step's front (one course) and the main face above it (one course): big chibi stones
    blocks_on(p, Ff, -HW, HW, 0, SH, -(-HD + .08), HD, r, [(0, SH)], min_len=1.0, max_len=1.6)
    blocks_on(p, Ff, -HW + .02, HW - .02, SH, H - .14, -(FACE + .08), -FACE, r, [(SH, H - .14)], min_len=.9, max_len=1.5)
    # the step's tread and the top: cap slabs seen from above (the camera's view), lighter, with cracks
    Fz = E.Fz
    tread = lambda u, v_, w: V((u, v_, w))
    blocks_on(p, Fz, -HW, HW, -HD, FACE, SH - .07, SH, r, [(-HD, FACE)], mat='cap', min_len=1.1, max_len=1.8)
    # the top: a front row of coping stones that overhang the face, then two rows behind
    blocks_on(p, Fz, -HW - .04, HW + .04, FACE - .06, FACE + .62, H - .16, H, r, [(FACE - .06, FACE + .62)], mat='cap', min_len=1.0, max_len=1.5)
    blocks_on(p, Fz, -HW, HW, FACE + .62, HD, H - .12, H - .03, r, [(FACE + .62, HD)], mat='cap', min_len=1.2, max_len=2.0)
    # the coping's front edge (a thin face under the overhang)
    blocks_on(p, Ff, -HW - .04, HW + .04, H - .16, H, -(FACE - .02), -(FACE - .06), r, [(H - .16, H)], mat='cap', min_len=1.0, max_len=1.5)
    # ends: the two sides, courses facing +X and -X (u runs along -Y for Fxp)
    Fxp = lambda u, v_, w: V((w, -u, v_))
    Fxn = lambda u, v_, w: V((-w, u, v_))
    blocks_on(p, Fxp, -HD, -FACE, 0, H - .14, HW - .08, HW, r, [(0, SH), (SH, H - .14)], min_len=.5, max_len=.9)
    blocks_on(p, Fxp, -FACE, HD, 0, SH - .07, HW - .08, HW, r, [(0, SH - .07)], min_len=.3, max_len=.6)
    blocks_on(p, Fxn, FACE, HD, 0, H - .14, HW - .08, HW, r, [(0, SH), (SH, H - .14)], min_len=.5, max_len=.9)
    blocks_on(p, Fxn, -HD, FACE, 0, SH - .07, HW - .08, HW, r, [(0, SH - .07)], min_len=.3, max_len=.6)
    # accents: two iron mooring rings on the main face, and a bone skull keystone in the middle of it
    ir = p.b('iron'); bo = p.b('bone', smooth=True); vo = p.b('void')
    for x in (-2.4, 2.4):
        C.tube(ir, [V((x + math.cos(a) * .13, FACE - .05, .78 + math.sin(a) * .15)) for a in [k * math.pi / 5 - math.pi for k in range(11)]], [.03] * 11, sides=5, sub=1, cap=False)
        C.blob(ir, (x, FACE - .03, .9), (.07, .04, .06), seg=6, rings=4)
    # the one accent (the prince's room reads it as royal): a red runner draped over the coping, down the main face
    # and the step, with a bone skull clasp at the top edge
    ban = p.b('banner'); RW = .55
    prof = [(H + .012, FACE + .5), (H + .012, FACE - .07), (H - .1, FACE - .085), (SH + .05, FACE - .03), (SH + .012, FACE - .05),
            (SH + .012, -HD - .02), (.25, -HD - .03), (.08, -HD - .02)]
    vs = []
    for z, y in prof:
        vs += [(-RW, y, z), (RW, y, z)]
    # a torn notch at the bottom hem
    vs[-2] = (-RW, -HD - .02, .02); vs[-1] = (RW, -HD - .02, .14)
    ban.add(vs, [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(prof) - 1)], [.5] * len(vs))
    for x in (-RW + .07, RW - .07):   # bone trim down both edges
        E.stroke(bo, [(x, y - .012, z + .006) for z, y in prof[1:5]], .07, (0, -1, 0), None, nib=lambda q: 1)
    S = V((0, FACE - .1, H - .05))
    C.blob(bo, S, (.24, .13, .21), seg=10, rings=7)
    C.blob(bo, S + V((0, -.04, -.15)), (.14, .08, .08), seg=8, rings=5)
    for sx in (-1, 1):
        C.blob(vo, S + V((sx * .09, -.115, .03)), (.06, .025, .06), seg=7, rings=4)
    # hatching where the overhang shades the main face
    for x in (-3.2, -1.1, 1.3, 3.1):
        E.hatch(p.b('ink'), Ff, r, x, H - .26, -FACE + .018, ang=0.0, n=6, length=.42, gap=.05, width=.016, fan=.02)
    return p


if __name__ == '__main__':
    X.clear_scene(); X.materials()
    root = X.finish_natural(build())
    X.export(root, 'ledge')
    w = E.build('wall'); w.location = (-2, HD + .5, 0)
    w2 = E.build('wall'); w2.location = (2, HD + .5, 0)
    X.shots(root, 'ledge', extent=5.5, centre_z=.6)
