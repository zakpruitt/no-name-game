# Resizes the chibi heretic's three void weapons for the sleek fx look (round 40, chibi pass 2): fatter
# hafts that read as the claw grown long, a bigger spear head and a hammer grown to about his chest,
# each with one element accent (axe edge, spear ice, hammer lava). Vertices only: the weapon.* bones,
# their weights and the hand they sit in are untouched. Scaling is about the hand (whole weapon, so its
# haft still points along its bone: heretic_shots' haft_alignment) or about a part's own middle (so
# chibi_keys.py's facing from the hammer head's centroid is unchanged). Tones live in
# ComicLook.KIND_TONES["heretic"]; heretic_rig.gd keeps the paper rim off them (thin ink only).
#   blender -b <blend> -P chibi_weapons.py -- <out.blend>
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
arm = bpy.data.objects["Armature"]
HAND = arm.matrix_world @ arm.data.bones["hand.r"].head_local
# object -> (whole weapon about the hand, across its haft about the haft's line, the part about its own middle)
WHOLE = {"hammer": 1.18}
HAFT_FAT = {"axe_void_haft": 1.3, "spear_void_haft": 1.55, "hammer_void_haft": 1.4}
PART = {"spear_void_ice": (1.6, 1.15), "hammer_void_head": (1.15, 1.15), "hammer_void_lava": (1.15, 1.15),
        "hammer_void_rock": (1.15, 1.15), "spear_void_collar": (1.3, 1.0)}   # (across, along) the bone


def bone_axis(form):
    b = arm.data.bones["weapon." + form]
    h, t = arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local
    return h, (t - h).normalized()


for o in bpy.data.objects:
    if o.type != "MESH" or o.name == "heretic" or "_void_" not in o.name:
        continue
    form = o.name.split("_")[0]
    h, ax = bone_axis(form)
    me = o.data
    MW, MI = o.matrix_world, o.matrix_world.inverted()
    pts = [MW @ v.co for v in me.vertices]
    mid = sum(pts, Vector()) / len(pts)
    k = WHOLE.get(form, 1.0)
    out = []
    for p in pts:
        q = p
        if o.name in HAFT_FAT:   # radial about the bone's line
            along = h + ax * (q - h).dot(ax)
            q = along + (q - along) * HAFT_FAT[o.name]
        if o.name in PART:
            across, alongk = PART[o.name]
            d = q - mid
            da = ax * d.dot(ax)
            q = mid + da * alongk + (d - da) * across
        q = HAND + (q - HAND) * k
        out.append(MI @ q)
    for v, c in zip(me.vertices, out):
        v.co = c
    me.update()
    bb = [MW @ v.co for v in me.vertices]
    print("weapon %-20s reach %.2f m from the hand" % (o.name, max((p - HAND).length for p in bb)))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("WEAPONS", OUT)
