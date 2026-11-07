# Shared helpers for the four env pieces the kit lacked (env-art lane, round 51 b): brazier, hook, pool, ledge.
# Each piece has its own script (env_brazier.py, env_hook.py, env_pool.py, env_ledge.py); this file only adds what
# env_kit.py does not have, without editing the kit:
#   - three materials (water, water_hi, ember) on top of env_kit.env_materials(), and their export stand-ins
#     (comic_water / comic_water_hi / comic_ember, which ComicLook.TONES / EMITS key on);
#   - finish_natural(): env_kit.finish() for a piece with no KayKit twin (its own bounds are the reference);
#   - export(), game_shot() (one piece at the game's camera, beside a 1.85 m stand-in for the hero and a kit barrel)
#     and lineup() (the new pieces beside kit pieces: does it read as one kit?).
# Run each piece script with Blender 5.2 headless:  blender -b -P tools/comic_art/env_<name>.py
# Outputs go to <worktree>/vendor_src/env_art/out/ (gitignored): <piece>.glb, <piece>_game.png, <piece>_side.png.
# The kit itself (comic_lib, env_kit) is read from the integration checkout's vendor_src, as every kit script does.
import bpy, sys, os, math
from mathutils import Vector as V, Matrix

KIT = r"C:\Users\pruit\Desktop\dev\awaken\vendor_src\shaman_redesign\comic_poc"
sys.path.insert(0, KIT)
import comic_lib as C
import env_kit as E

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.environ.get('ENV_ART_OUT') or os.path.join(REPO, 'vendor_src', 'env_art', 'out')

# light tone of each new material = the export stand-in's base colour (as env_kit._export_mat does)
NEW = {
    'water': (.13, .4, .62),
    'water_hi': (.56, .84, .96),
    'ember': (1, .5, .1),
}


def materials():
    M = E.env_materials()
    if 'water' not in M:
        t = lambda name, *a, **k: C.toon(name, *a, extra=E.tone_extra, **k)
        # deep teal-blue, darker than the ice palette so a frozen swap pops; the light tone stays under the floor's
        # mid-light so the pool sits in the floor, not on it
        M['water'] = t('E_Water', (.02, .05, .13), (.045, .15, .3), (.09, .29, .48), (.14, .4, .62), rim=(.04, .12, .24), brush=.03, inner=.0, spot=.02)
        M['water_hi'] = C.flat('E_WaterHi', NEW['water_hi'])
        M['ember'] = C.emit('E_Ember', (.42, .04, .03), (1, .62, .12), mid=(.92, .22, .04))
    return M


_orig_export_mat = E._export_mat


def _export_mat(mat):
    if mat not in NEW:
        return _orig_export_mat(mat)
    if mat in E._EXP:
        return E._EXP[mat]
    m = bpy.data.materials.new('comic_' + mat); m.use_nodes = True
    pr = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    pr.inputs['Base Color'].default_value = C.srgb(NEW[mat]); pr.inputs['Roughness'].default_value = 1
    if mat in ('water_hi', 'ember'):
        pr.inputs['Emission Color'].default_value = C.srgb(NEW[mat]); pr.inputs['Emission Strength'].default_value = 1
    E._EXP[mat] = m
    return m


E._export_mat = _export_mat


def clear_scene():
    for o in list(bpy.context.scene.collection.all_objects):
        bpy.data.objects.remove(o)


def finish_natural(p, col=None):
    """env_kit.finish for a piece with no KayKit file: its own bounds are its reference, so fit() changes nothing."""
    materials()
    vs = [v for b in p.bags.values() for v in b.v]
    lo = tuple(min(v[i] for v in vs) for i in range(3)); hi = tuple(max(v[i] for v in vs) for i in range(3))
    E.REF[p.name] = (lo, hi)
    return E.finish(p, col)


def xform(bags, m):
    """Move every vertex of these bags by matrix m (a tipped brazier)."""
    for b in bags:
        for i, v in enumerate(b.v):
            b.v[i] = m @ V(v)


def tones(b, n0, t):
    """Set the tone of the vertices added to bag b since index n0."""
    for i in range(n0, len(b.v)):
        b.t[i] = t


def export(root, name, origins=None):
    """One GLB per piece into OUT. origins: node -> hinge (Blender coords), as env_kit.NODE_ORIGIN."""
    os.makedirs(OUT, exist_ok=True)
    if origins:
        E.NODE_ORIGIN.update(origins)
    sv = root.location.copy(); root.location = (0, 0, 0); bpy.context.view_layer.update()
    E.export_piece(root, os.path.join(OUT, name + '.glb'))
    root.location = sv; bpy.context.view_layer.update()
    t = E.piece_tris(root)
    lo, hi = E.bounds(root.children)
    print('PIECE', name, 'tris', t, 'size %.2f x %.2f x %.2f' % tuple(hi[i] - lo[i] for i in range(3)))
    return t


def stand_in(at=(0, 0, 0)):
    """A 1.85 m chibi-proportioned dummy for scale (the hero's height, big head): not his look, only his size."""
    M = materials(); col = bpy.context.scene.collection
    b = C.Bag('bone', smooth=True)
    x, y, z = at
    C.blob(b, (x, y, z + .38), (.2, .17, .38), seg=10, rings=7)            # legs + hips
    C.blob(b, (x, y, z + .86), (.3, .24, .34), seg=12, rings=8)            # body
    C.blob(b, (x, y, z + 1.45), (.42, .38, .4), seg=14, rings=9)           # big head, top at 1.85
    o, _ = C.make_obj('scale_stand_in', b, M, col, outline=.02)
    return o


def frame_cam(name, centre, dist=13.0, pitch=55.0, yaw=-35.0, ortho=None, lens=None):
    """A camera looking at centre from the game's angle: pitch degrees down, turned yaw degrees round Z."""
    p, a = math.radians(pitch), math.radians(yaw)
    c = V(centre)
    off = V((math.sin(a) * math.cos(p), -math.cos(a) * math.cos(p), math.sin(p))) * dist
    if ortho:
        return C.camera(name, c + off, c, ortho=ortho)
    return C.camera(name, c + off, c, lens=lens or 50)


def shots(root, name, extent=2.5, centre_z=.6, kit=('barrel_small',)):
    """<name>_game.png (the game camera: 55 deg down, 37 deg fov, from 13 m, cropped to the piece) and <name>_side.png
    (a low three-quarter view), with the scale stand-in and a kit piece beside it, on kit floor tiles."""
    scn = bpy.context.scene
    bpy.context.view_layer.update()
    lo, hi = E.bounds(root.children)
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    wx = hi[0] - lo[0]
    stand_in((cx + wx / 2 + .9, cy - .2, 0))
    for i, k in enumerate(kit):
        kr = E.build(k)
        kr.location = (cx - wx / 2 - 1.0 - i * 1.4, cy + .3, 0)
    # floor around it, unless it is a floor tile itself
    for fx in (-1, 0, 1):
        for fy in (-1, 0, 1):
            if name.startswith('pool') and fx == 0 and fy == 0:
                continue
            f = E.build('floor_tile_large'); f.location = (cx + fx * 4, cy + fy * 4, 0)
    C.comic_scene(floor=False)
    scn.render.resolution_x, scn.render.resolution_y = 800, 450
    w = max(wx + 4.5, extent * 2)
    cam = frame_cam('CamGame', (cx + .5, cy, centre_z), dist=30, pitch=55, yaw=-20, ortho=w)
    C.render(os.path.join(OUT, name + '_game.png'), cam)
    cam2 = frame_cam('CamSide', (cx + .5, cy, centre_z + .2), dist=30, pitch=18, yaw=-35, ortho=w)
    C.render(os.path.join(OUT, name + '_side.png'), cam2)
