# Export the comic shaman for the game: geometry, skin, the twin axes and every animation under plain names.
#   blender -b ../style_poc/shaman_poc.blend --scene POC -P export_comic_shaman.py
# P_Idle -> Idle, P_Ab_L3 -> Ab_L3. The look needs the game's comic_toon shader; a glb carries none of it.
import bpy, os, sys, json, struct
D = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc"
sys.argv = [a for a in sys.argv if a != 'sheet']
exec(compile(open(os.path.join(D, 'rig_comic.py')).read(), 'rig_comic', 'exec'))
OUT = os.path.join(D, 'out', 'shaman_comic.glb')
ad = PR.animation_data
for t in list(ad.nla_tracks): ad.nla_tracks.remove(t)
# A hand-keyed P_Hero_X takes the place of the retargeted P_X
for a in [a for a in bpy.data.actions if a.name.startswith('P_Hero_')]:
    old = bpy.data.actions.get('P_' + a.name[7:])
    if old: bpy.data.actions.remove(old)
    a.name = 'P_' + a.name[7:]
names = []
for a in bpy.data.actions:
    if not a.name.startswith('P_') or a is ad.action or '.' in a.name or a.name == 'P_Showcase': continue
    tr = ad.nla_tracks.new(); tr.name = a.name; tr.mute = True
    st = tr.strips.new(a.name, 0, a); names.append(a.name)
    if a.slots: st.action_slot = a.slots[0]
ad.action = None  # the reel has root motion and no place in the game file
# Clearing the action leaves the rig where the reel's first frame put it, turned 78 degrees for the camera.
# The game turns the model to face a direction, so the rig must sit square in it, facing front.
PR.location = (0, 0, 0)
PR.rotation_euler = (0, 0, 0)
bpy.context.view_layer.update()
for a in list(bpy.data.actions):   # the exporter takes every compatible action in the file, not only these
    if a.name not in names: bpy.data.actions.remove(a)
bpy.ops.object.select_all(action='DESELECT')
parts = []
for o in scn.objects:
    if o.type == 'MESH' and any(m.type == 'ARMATURE' and m.object is PR for m in o.modifiers):
        # the flipbook meshes are stubs for the Blender showcase; his rest state has no fire or bolts on it
        if o.name[:4] in ('fire', 'bolt'): continue
        o.hide_viewport = False; o.hide_render = False
        if o.animation_data: o.animation_data_clear()
        for m in list(o.modifiers):
            if m.name == 'Ink' or m.type == 'SOLIDIFY': o.modifiers.remove(m)   # the game draws its own hull
        o.select_set(True); parts.append(o)
PR.select_set(True)
bpy.context.view_layer.objects.active = PR
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=False, export_animations=True,
                          export_animation_mode='ACTIONS', export_skins=True, export_cameras=False, export_lights=False)
with open(OUT, 'rb') as f: raw = f.read()
n = struct.unpack('<I', raw[12:16])[0]
j = json.loads(raw[20:20 + n])
for a in j.get('animations', []):
    if a['name'].startswith('P_'): a['name'] = a['name'][2:]
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
rest = raw[20 + n:]
with open(OUT, 'wb') as f:
    f.write(raw[:8] + struct.pack('<I', 12 + 8 + len(js) + len(rest)) + struct.pack('<II', len(js), 0x4E4F534A) + js + rest)
print('EXPORT tris', sum(len(p.vertices) - 2 for o in parts for p in o.data.polygons), 'parts', len(parts))
print('EXPORT anims', sorted(a['name'] for a in j['animations']))
print('EXPORT bones', sorted(b.name for b in PR.pose.bones))
