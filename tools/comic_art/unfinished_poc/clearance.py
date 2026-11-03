# Does an axe go through him? Every frame of every Ab_ clip of the exported GLB: blade corners against his torso, head and
# hump, and how far under the floor they go. Prints a table; no renders.
#   blender -b --factory-startup -P clearance.py
import bpy, sys
from mathutils import Vector as V
GLB = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc\out\shaman_comic.glb"
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for t in arm.animation_data.nla_tracks: t.mute = True
scn = bpy.context.scene
AX = {'hand.r': 'axe_storm', 'hand.l': 'axe_magma'}
pts = {}
for bone, name in AX.items():
    o = next(x for x in bpy.data.objects if x.type == 'MESH' and x.name.startswith(name + '_blade'))
    wm = o.matrix_world
    inv = (arm.matrix_world @ arm.data.bones[bone].matrix_local).inverted()
    pts[bone] = [inv @ (wm @ v.co) for v in o.data.vertices]
    h = next(x for x in bpy.data.objects if x.type == 'MESH' and x.name.startswith(name + '_haft'))
    # the top half of the haft is what passes him; the grip is meant to be near him
    hp = [inv @ (h.matrix_world @ v.co) for v in h.data.vertices]
    pts[bone] += [p for p in hp if p.length > .55]
def seg(p, a, b):
    d = b - a; t = max(min((p - a).dot(d) / max(d.length_squared, 1e-6), 1), 0)
    return (p - (a + d * t)).length
rows = []
for act in bpy.data.actions:
    n = act.name
    if not (n.startswith('Ab_') or n in ('Idle', 'Idle_Ready', 'Idle_Listen', 'Idle_Heft', 'Idle_Swing', 'Run_F', 'Run_B', 'Strafe_L', 'Strafe_R')): continue
    ad = arm.animation_data; ad.action = act
    if act.slots: ad.action_slot = act.slots[0]
    lo, hi = int(act.frame_range[0]), int(act.frame_range[1])
    hits = []; worst = -9; wf = None; floor = 9; ff = None; sunk = 0
    for f in range(lo, hi + 1):
        scn.frame_set(f); bpy.context.view_layer.update()
        B = {b.name: arm.matrix_world @ b.matrix for b in arm.pose.bones}
        at = lambda b: B[b].to_translation()
        tail = lambda b: arm.matrix_world @ arm.pose.bones[b].tail
        hump = B['chest'] @ (arm.data.bones['chest'].matrix_local.inverted() @ V((.47, -.12, 1.64)))
        vols = [('torso', at('hips'), at('chest'), .24), ('chest', at('chest'), tail('chest'), .27), ('head', at('head'), tail('head'), .19), ('shoulder', hump, hump, .3)]
        deep = -9; who = None
        for bone in AX:
            m = B[bone] @ arm.data.bones[bone].matrix_local.inverted() @ arm.data.bones[bone].matrix_local
            for p in pts[bone]:
                w = m @ p
                
                if w.z < floor: floor, ff = w.z, (f, bone)
                for vn, a, b, r in vols:
                    d = r - seg(w, a, b)
                    if d > deep: deep, who = d, (bone, vn)
        if deep > .02: hits.append(f)
        sunk += min((m_z for m_z in [min((B[b] @ p).z for b in AX for p in pts[b])]), default=0) < -.05
        if deep > worst: worst, wf = deep, (f, who)
    rows.append((n, hi - lo + 1, len(hits), round(worst, 3), wf, round(floor, 3), ff, sunk))
print('CLEAR clip frames bad worst_depth (frame,(hand,part)) lowest_z (frame,hand) frames_under_5cm')
for r in sorted(rows, key=lambda r: -r[3]): print('CLEAR', *r)
print('DONE')
