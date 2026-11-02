# Stages the ability reel in the comic dungeon, with minions taking the hits. Called from render_abilities.py with room=1.
# The room runs along his line of travel, so the back wall stays in the top of the frame the whole way down the reel.
import bpy, os, math, random
import comic_lib as C, env_kit as EK
from mathutils import Vector as V, Quaternion as Q

TILE = 4.0
WALL_Y = 2.6              # local: how far behind his path the back wall stands
# how far ahead of him each hit lands, and what it does to the target: (ahead, spread, knockback, launch height)
TARGETS = {'L1': (1.9, 0, .7, 0), 'L2': (1.9, 0, .8, 0), 'L3': (2.9, .95, 1.2, 0), 'LH': (2.2, 0, .2, 2.3), 'LLH': (2.7, 1.0, 1.3, .5), 'H': (1.9, 1.2, 1.5, .4),
           'DL': (3.2, 0, 1.4, 0), 'LHH': (2.2, 0, .3, 0), 'CH': (2.6, 1.1, 1.6, 1.2), 'SKY': (2.4, 1.2, 1.8, 1.4), 'RUSH': (3.5, 1.0, 1.6, .9), 'AF': (2.4, 1.6, 2.2, 1.2)}

# who takes each hit: every enemy type turns up
CAST = {'L1': ['minion'], 'L2': ['rogue'], 'L3': ['minion', 'rogue'], 'LH': ['warrior'], 'LLH': ['shield', 'minion'], 'H': ['rogue', 'minion'], 'DL': ['mage'],
        'LHH': ['warrior'], 'CH': ['warrior', 'shield'], 'SKY': ['necromancer', 'warrior'], 'RUSH': ['minion', 'archer'], 'AF': ['warrior', 'necromancer']}

def dress(scn, YAW, FWD, root_at, CLIPS, HIT, K):
    EK.env_materials()
    for n in ('floor', 'floor_stones', 'ground_shadow'):
        o = bpy.data.objects.get(n)
        if o: bpy.data.objects.remove(o)
    room = bpy.data.objects.new('Room', None); scn.collection.objects.link(room)
    # local +X along his path, local +Y behind it
    room.rotation_euler = (0, 0, YAW - math.pi / 2)
    src = {}
    def place(name, x, y, yaw=0.0, z=0.0):
        if name not in src:
            r = EK.build(name)
            src[name] = list(r.children)
            for o in src[name]: scn.collection.objects.unlink(o)
            scn.collection.objects.unlink(r)
        e = bpy.data.objects.new(name, None); scn.collection.objects.link(e)
        e.parent = room; e.location = (x, y, z); e.rotation_euler = (0, 0, math.radians(yaw))
        for o in src[name]:
            c = o.copy(); c.parent = e; scn.collection.objects.link(c)
        return e
    far = (root_at(10 ** 6) - root_at(0)).length + 12
    xs = [(-10 + i * TILE + TILE / 2) for i in range(int((far + 10) / TILE) + 1)]
    rnd = random.Random(11)
    for x in xs:
        for j in range(4):
            y = WALL_Y - TILE / 2 - j * TILE
            piece = 'floor_tile_large'
            if rnd.random() < .05: piece = 'floor_tile_big_grate'
            elif rnd.random() < .08: piece = 'floor_tile_large_rocks'
            place(piece, x, y)
    for i, x in enumerate(xs):
        place({3: 'wall_arched', 6: 'wall_broken', 9: 'wall_arched'}.get(i % 11, 'wall'), x, WALL_Y)
        if i % 3 == 1: place('banner_patternA_red' if i % 2 else 'banner_red', x + 1.9, WALL_Y - .35)
        if i % 3 == 2: place('torch_mounted', x, WALL_Y - .48, z=2.4)
        if i % 4 == 0: place(rnd.choice(('barrel_large', 'crates_stacked', 'box_large', 'candle_triple')), x + .9, WALL_Y - 1.0, rnd.uniform(-30, 30))

    # the targets: one source minion, copied per hit; each plays idle until the blow, then flinches and falls
    POOL = {}
    def load(name):
        if name in POOL: return POOL[name]
        path = os.path.join(C.DIR, 'out', 'enemies', name + '.blend')
        with bpy.data.libraries.load(path, link=False) as (s_, d):
            d.objects = [n for n in s_.objects if n != 'floor']; d.actions = list(s_.actions)
        objs = [o for o in d.objects if o]
        rig0 = next(o for o in objs if o.type == 'ARMATURE')
        # only meshes this rig drives; anything else in the file (props on the floor) stays out
        meshes0 = [o for o in objs if o.type == 'MESH' and (o.parent is rig0 or any(m.type == 'ARMATURE' and m.object is rig0 for m in o.modifiers))]
        # names may have gained .001 on append; map them back
        acts = {}
        for ac in d.actions:
            acts[ac.name.split('.')[0]] = ac
        POOL[name] = (rig0, meshes0, acts)
        return POOL[name]
    def minion(kind, a, b, h, pos, kb, up, away):
        rig0, meshes0, acts = load(kind)
        rig = rig0.copy(); scn.collection.objects.link(rig)
        if rig.animation_data: rig.animation_data_clear()
        rig.animation_data_create()
        # one action per target: idle looped up to the blow, flinch, fall. NLA strips on copied rigs did not evaluate headless.
        act = bpy.data.actions.new('target_%d_%d' % (a, h))
        slot = act.slots.new('OBJECT', 'target'); cb = act.layers.new('l').strips.new(type='KEYFRAME').channelbag(slot, ensure=True)
        dest = {}
        def put(name, start, end, loop=False):
            src_a = acts[name]; src_cb = src_a.layers[0].strips[0].channelbag(src_a.slots[0])
            L = max((kp.co.x for fc in src_cb.fcurves for kp in fc.keyframe_points), default=1) or 1
            off = start
            while off < end:
                for fc in src_cb.fcurves:
                    k = (fc.data_path, fc.array_index)
                    d_ = dest.get(k) or dest.setdefault(k, cb.fcurves.new(fc.data_path, index=fc.array_index))
                    for kp in fc.keyframe_points:
                        t = off + kp.co.x
                        if t < end: d_.keyframe_points.insert(t, kp.co.y, options={'FAST'})
                if not loop: break
                off += L
        put('Idle_Combat', a, h, loop=True); put('Hit_A', h, h + 10); put('Death_A', h + 10, b + 40)
        for d_ in dest.values(): d_.update()
        rig.animation_data.action = act; rig.animation_data.action_slot = slot
        e = bpy.data.objects.new('target', None); scn.collection.objects.link(e); rig.parent = e
        e.rotation_euler = (0, 0, YAW + math.pi)
        # flung on the hit frame in held steps: drawn, not simulated
        steps = {0: (0, 0), 1: (.35, .5), 3: (.65, 1), 5: (.82, .85), 7: (.93, .5), 9: (1, .12), 11: (1, 0)}
        K.objs.append(e)
        e.location = pos; e.keyframe_insert('location', frame=h - 1)
        for df, (u, w) in steps.items():
            e.location = pos + away * kb * u + V((0, 0, up * w)); e.keyframe_insert('location', frame=h + df)
        for m0 in meshes0:
            m = m0.copy(); scn.collection.objects.link(m); m.parent = rig
            for mod in m.modifiers:
                if mod.type == 'ARMATURE': mod.object = rig
            for f, hide in ((0, True), (a, False), (b, True)):
                m.hide_render = hide; m.keyframe_insert('hide_render', frame=f)
    side = V((FWD.y, -FWD.x, 0))
    for k, (a, b) in CLIPS.items():
        h = a + HIT[k]; ahead, spread, kb, up = TARGETS[k]
        if k == 'RUSH': h += 10
        p = root_at(a + HIT[k]) + FWD * ahead
        spots = [p] if not spread else [p + side * spread, p - side * spread * .8 + FWD * .4]
        for i_, q in enumerate(spots):
            away = (q - root_at(h)); away.z = 0; away = away.normalized() if away.length else FWD
            minion(CAST[k][i_ % len(CAST[k])], a - 10, b + 10, h, q, kb, up, away)
    bpy.context.view_layer.update()
