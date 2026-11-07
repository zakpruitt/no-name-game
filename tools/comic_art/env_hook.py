# The hook (env piece `hook`, gallows): a wall-mounted iron bracket, a short heavy chain and a big meat hook.
#   blender -b -P tools/comic_art/env_hook.py   -> hook_chain.glb + shots, in env_extra.OUT
# Mounted like the kit's torch_mounted: the back plate lies on the wall plane y = 0 and everything hangs out toward -Y
# (Godot +Z at yaw 0); the pivot is the bracket's mount, so place it on a wall face about 3 m up (the hook's point is
# then ~1.4 m off the floor: a hung chibi foe's feet clear the floor). Nodes: `hook_chain` (the plate and bracket) and
# `hook_swing` (chain, hook, rag), whose origin is the bracket's eye, so a script can swing it like the torch.
# Links are oversized (0.3 m, 0.09 m thick) so the chain still reads as links from the game camera at 13 m.
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import env_extra as X
from env_extra import C, E
from mathutils import Vector as V

EYE = V((0, -.42, -.02))   # where the chain hangs from (the hook_swing node's origin)
LINK = .3                  # link length
LINKS = 4


def link(b, c, vertical_plane_x, L=LINK, W=.17, th=.045, sides=6):
    """One oval chain link centred at c, long along Z, in the XZ plane (or YZ)."""
    pts = []
    for k in range(12):
        a = 2 * math.pi * k / 12
        u, v = math.cos(a) * W / 2, math.sin(a) * (L / 2)
        pts.append(c + (V((u, 0, v)) if vertical_plane_x else V((0, u, v))))
    pts.append(pts[0])
    C.tube(b, pts, [th] * len(pts), sides=sides, sub=1, cap=False)


def build():
    p = E.Piece('hook_chain'); r = p.r
    ir = p.b('iron'); ink = p.b('ink')
    # back plate: a heavy square with four rivets, tilted a hair so its face catches the key
    E.box(ir, (-.24, -.07, -.26), (.24, 0, .26))
    for sx in (-1, 1):
        for sz in (-1, 1):
            C.blob(p.b('bone'), (sx * .16, -.075, sz * .17), (.035, .02, .035), seg=6, rings=4)
    # bracket: a thick curved arm out to the eye, with a brace under it
    C.tube(ir, [V((0, -.06, .1)), V((0, -.24, .1)), V((0, -.38, .05)), EYE + V((0, 0, .05))], [.06, .055, .05, .05], sides=6, sub=2)
    C.tube(ir, [V((0, -.06, -.18)), V((0, -.22, -.08)), V((0, -.33, .04))], [.04, .035, .03], sides=5, sub=1)
    # the eye ring the chain hangs from
    link(ir, EYE + V((0, 0, -.06)), False, L=.16, W=.16, th=.035)
    E.hatch(ink, E.Ff, r, .06, -.05, .075, ang=2.3, n=4, length=.2, gap=.045, width=.014)
    # chain: alternating planes, overlapping by the wire, swinging node
    sw = p.b('iron', node='hook_swing')
    z = EYE.z - .13
    for i in range(LINKS):
        cz = z - LINK / 2 + .02
        link(sw, V((EYE.x, EYE.y, cz)), i % 2 == 0)
        z = cz - LINK / 2 + .07
    # the hook: a fat shank into a J, tapering to a point that turns back up (toward the camera)
    top = V((EYE.x, EYE.y, z + .02))
    # the J lies in the wall's plane (XZ) so the game camera, in front, sees its whole curve, and leans a little out
    J = [top, top + V((0, 0, -.14)), top + V((0, -.01, -.38)), top + V((.02, -.03, -.56)), top + V((.13, -.06, -.7)),
         top + V((.3, -.08, -.68)), top + V((.39, -.08, -.55)), top + V((.4, -.07, -.4)), top + V((.36, -.06, -.27))]
    C.tube(sw, J, [.08, .075, .075, .072, .068, .06, .048, .03, .004], sides=7, sub=3, side=(0, 1, 0))
    # a collar where the hook meets the chain
    C.blob(sw, top + V((0, 0, -.05)), (.09, .09, .07), seg=8, rings=5)
    # the one accent: a torn red rag tied round the shank (the gallows reads as a gallows, not a light fitting)
    rag = p.b('banner', node='hook_swing'); c = top + V((0, -.02, .12))
    for s in (-1, 1):
        q = [c + V((s * .02, -.075, .04)), c + V((s * .14, -.12, -.06)), c + V((s * .2, -.11, -.24)), c + V((s * .1, -.09, -.34))]
        rag.add([q[0], q[1], q[2], q[3], c + V((0, -.08, -.1))], [(0, 1, 4), (1, 2, 4), (2, 3, 4)], [.5] * 5)
    E.lathe(rag, [(.085, -.17, .5), (.09, -.12, .5), (.085, -.08, .5)], sides=8, c=(c.x, c.y + .02), top=False)
    # shift the ring of the lathe into place (lathe is about z only): move the last 24 verts to the shank height
    n = len(rag.v)
    for i in range(n - 24, n):
        rag.v[i] = rag.v[i] + V((0, 0, c.z + .1))
    return p


if __name__ == '__main__':
    X.clear_scene(); X.materials()
    root = X.finish_natural(build())
    X.export(root, 'hook_chain', origins={'hook_swing': tuple(EYE)})
    # the shot: on a kit wall, 3 m up, as the game places it
    w = E.build('wall'); w.location = (0, .5, 0)
    root.location = (0, 0, 3.0)
    X.shots(root, 'hook_chain', extent=2.6, centre_z=1.6)
