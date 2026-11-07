# The pool (env piece `pool`): a floor tile (4 x 4 m, the kit's flagstones round it, so it joins any floor tile) with
# a low stone kerb round a sunk water surface.
#   blender -b -P tools/comic_art/env_pool.py   -> pool.glb + shots, in env_extra.OUT
# Nodes: `pool` (floor stones, kerb, the dark inner lip) and `pool_water` (the water surface and its ripple lines: one
# flat disc at z 0.075 plus strokes 2 mm over it). The game swaps `pool_water` for a frozen surface by giving its mesh
# designed_elements.facet_material() (ice_rink), or hides it; nothing else in the tile has to change.
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import env_extra as X
from env_extra import C, E
from mathutils import Vector as V

RX, RY = 1.56, 1.5   # the water's half extents (a squarish superellipse, the tile is 2 m half)
KERB = .3            # kerb width
WZ = .075            # water surface height (the floor stones' top is .05)
N = 40               # outline points


def outline(rx, ry, e=3.2, n=N, wob=0.0, r=None):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        k = 1 + (r.uniform(-wob, wob) if r else 0)
        pts.append((math.copysign(abs(c) ** (2 / e), c) * rx * k, math.copysign(abs(s) ** (2 / e), s) * ry * k))
    return pts


def build():
    p = E.Piece('pool'); r = p.r
    E.floor_base(p, ink=.35)
    # kerb: chamfered stone blocks round the rim, one tone each, a hair irregular
    inner = outline(RX + .04, RY + .04)
    outer = outline(RX + KERB, RY + KERB)
    cut = sorted(set([0] + [i for i in range(N) if r.random() < .22] + [N]))
    st = p.b('cap')
    for a, b_ in zip(cut, cut[1:]):
        if b_ - a < 2:
            continue
        idx = list(range(a, b_ + 1))
        ring_o = [outer[i % N] for i in idx]; ring_i = [inner[i % N] for i in idx]
        t = r.uniform(.4, .62); z0, z1 = .02, r.uniform(.15, .18)
        # shrink each block a bit along the ring so the seams are real gaps over the dark lip
        def pull(q, frac):
            return q
        top_o = [(x * .985, y * .985) for x, y in ring_o]; top_i = [(x * 1.012, y * 1.012) for x, y in ring_i]
        m = len(idx)
        vs = [(x, y, z0) for x, y in ring_o] + [(x, y, z0) for x, y in ring_i] + [(x, y, z1) for x, y in top_o] + [(x, y, z1) for x, y in top_i]
        fs = []
        for k in range(m - 1):
            fs.append((2 * m + k, 2 * m + k + 1, 3 * m + k + 1, 3 * m + k))   # top
            fs.append((k, k + 1, 2 * m + k + 1, 2 * m + k))                  # outer side
            fs.append((m + k + 1, m + k, 3 * m + k, 3 * m + k + 1))          # inner side
        fs.append((0, 2 * m, 3 * m, m))                                      # ends
        fs.append((m - 1, 2 * m - 1, 4 * m - 1, 3 * m - 1))
        # seam gap: pull the block's two end rows in along the ring
        for e0, e1 in ((0, 1), (m - 1, m - 2)):
            for base in (0, m, 2 * m, 3 * m):
                q0, q1 = vs[base + e0], vs[base + e1]
                vs[base + e0] = (q0[0] + (q1[0] - q0[0]) * .18, q0[1] + (q1[1] - q0[1]) * .18, q0[2])
        st.add(vs, fs, [t] * len(vs))
        # a crack or a hatch on some kerb stones' tops
        if r.random() < .45:
            k = m // 2
            mx = (top_o[k][0] + top_i[k][0]) / 2; my = (top_o[k][1] + top_i[k][1]) / 2
            ang = math.atan2(my, mx) + r.uniform(-.5, .5)
            E.crack(p.b('ink'), E.Fz, r, mx * .99, my * .99, z1 + .006, ang + math.pi, .14, .016, 0)
    # the dark band inside the kerb, between it and the water (reads as depth)
    lip = p.b('void'); o = outline(RX + .06, RY + .06); i_ = outline(RX - .06, RY - .06)
    lip.add([(x, y, WZ - .004) for x, y in o] + [(x, y, WZ - .004) for x, y in i_],
            [(k, (k + 1) % N, N + (k + 1) % N, N + k) for k in range(N)], [.5] * (2 * N))
    # --- the water: its own node, a disc in rings (darker at the edge: depth) and ripple strokes
    wt = p.b('water', node='pool_water'); hi = p.b('water_hi', node='pool_water')
    rings = [(1.0, .38), (.8, .44), (.55, .52), (.25, .58)]
    vs, ts = [], []
    for k_, (sc, t) in enumerate(rings):
        for x, y in outline(RX * sc, RY * sc):
            vs.append((x, y, WZ)); ts.append(t)
    fs = []
    for k_ in range(len(rings) - 1):
        for i in range(N):
            a0, a1 = k_ * N + i, k_ * N + (i + 1) % N
            fs.append((a0, a1, a1 + N, a0 + N))
    c = len(vs); vs.append((0, 0, WZ)); ts.append(.6)
    base = (len(rings) - 1) * N
    for i in range(N):
        fs.append((base + i, base + (i + 1) % N, c))
    wt.add(vs, fs, ts)
    # ripples: broken concentric arcs round two drip points, and glints along the near (camera) side
    Z = WZ + .003
    for cx, cy, rad, n in ((-.45, .3, (.22, .42, .62), 3), (.6, -.45, (.18, .34), 2)):
        for rr in rad:
            a0 = r.uniform(0, 6.28); span = r.uniform(2.2, 3.6)
            pts = [(cx + math.cos(a0 + span * q / 8) * rr, cy + math.sin(a0 + span * q / 8) * rr * .85, Z) for q in range(9)]
            E.stroke(hi, pts, .035, (0, 0, 1), r)
    for k in range(7):
        x = r.uniform(-1.2, 1.2); y = r.uniform(-1.2, 1.1)
        if abs(x) ** 3 / RX ** 3 + abs(y) ** 3 / RY ** 3 > .6:
            continue
        L = r.uniform(.18, .38)
        E.stroke(hi, [(x, y, Z), (x + L * .5, y + .015, Z), (x + L, y, Z)], .03, (0, 0, 1), r)
    # dark wash strokes under the near kerb (the kerb's reflection, a comic shorthand)
    dk = p.b('wash', node='pool_water')
    for k in range(5):
        x0 = -1.1 + k * .5 + r.uniform(-.08, .08)
        E.stroke(dk, [(x0, -RY + .14, Z - .001), (x0 + .2, -RY + .16, Z - .001), (x0 + .4, -RY + .13, Z - .001)], .05, (0, 0, 1), r)
    return p


if __name__ == '__main__':
    X.clear_scene(); X.materials()
    root = X.finish_natural(build())
    X.export(root, 'pool')
    X.shots(root, 'pool', extent=3.4, centre_z=0)
