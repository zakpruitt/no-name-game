extends RefCounted
## Round 46 (fx-elements, docs/features/designed-fx.md "Round 46"): the ice and magma base moves as designed effects.
## Sheets: tools/vfx_gen/gen_elements.py (registered here through DESIGNED.extra_sheets); the timeline node, palette
## and shaders are designed_fx.gd's. Every caller branches on DESIGNED.on() and keeps its old path (--fx=classic).
##   magma: Molten Palm's fist (comic_fist.gd draws `magma_fist` on its node), the fissure (`fissure`: a crack
##          decal a step and a lava spurt every other one), every earth `elements.spikes` (`spikes`: `magma_spurt`).
##   ice:   every water `elements.spikes` (`frost_mark`: Harpoon's line, the nova, Deep Freeze, Worldbreaker's ice: a
##          frost crack on the floor and a puff of cold mist; fx-ice2 took the `ice_spike` crystals out: Zak, "get rid of
##          the crystals"), the frost spear's floor (`frost_floor` / `ice_frost`), the Deep Freeze burst (`frost_burst`)
##          and the ice block round a frozen foe, fitted to its model (`fit_block`).

const DESIGNED := preload("res://scripts/designed_fx.gd")

const SHEETS := {
	"magma_fist": {"tex": preload("res://assets/vfx/designed/magma_fist.png"), "grid": Vector2(4, 2), "frames": 8, "kind": "sprite",
		"burn": 1.0},
	"magma_spurt": {"tex": preload("res://assets/vfx/designed/magma_spurt.png"), "grid": Vector2(4, 2), "frames": 7,
		"kind": "sprite_depth", "anchor": Vector2(0.0, -0.31), "burn": 1.0},
	"magma_crack": {"tex": preload("res://assets/vfx/designed/magma_crack.png"), "grid": Vector2(2, 2), "frames": 4, "kind": "ground",
		"burn": 1.0},
	"ice_frost": {"tex": preload("res://assets/vfx/designed/ice_frost.png"), "grid": Vector2(2, 2), "frames": 4, "kind": "ground"},
	"ice_mark": {"tex": preload("res://assets/vfx/designed/ice_mark.png"), "grid": Vector2(2, 2), "frames": 4, "kind": "ground"},
	# the ball is drawn right of the middle (0.18 of the quad): the pivot sits on it, so it turns round him
	"magma_meteor": {"tex": preload("res://assets/vfx/designed/magma_meteor.png"), "grid": Vector2(3, 2), "frames": 5,
		"kind": "sprite_depth", "anchor": Vector2(0.18, 0.0), "burn": 1.0},
	"magma_geyser": {"tex": preload("res://assets/vfx/designed/magma_geyser.png"), "grid": Vector2(4, 2), "frames": 8,
		"kind": "sprite_depth", "anchor": Vector2(0.0, -0.33), "burn": 1.0},
	"magma_pool": {"tex": preload("res://assets/vfx/designed/magma_pool.png"), "grid": Vector2(3, 2), "frames": 6, "kind": "ground",
		"burn": 1.0},
}

static var _registered := false


static func register() -> void:
	if _registered:
		return
	_registered = true
	for n: String in SHEETS:
		DESIGNED.extra_sheets[n] = SHEETS[n]


## Draw every material once at real size (elements.prewarm), so nothing compiles mid-fight.
static func prewarm(root: Node3D) -> void:
	if not DESIGNED.on():
		return
	register()
	for n: String in SHEETS:
		var mi := MeshInstance3D.new()
		mi.mesh = DESIGNED._mesh_for(SHEETS[n].kind)
		mi.material_override = DESIGNED.material(n)
		root.add_child(mi)
		mi.scale = Vector3.ONE * 20.0
	var block := MeshInstance3D.new()  # the facet materials (ice block, the spear's shaft and crystals)
	block.mesh = ice_block(0.6, 1.5)
	root.add_child(block)
	block.scale = Vector3.ONE * 20.0
	var sp := Node3D.new()
	root.add_child(sp)
	sp.scale = Vector3.ONE * 20.0
	spear(sp, 2.3, 0.13)


static func _spawn(parent: Node, sheet: String, at: Vector3, size: float, element: String, times: Array, erode: Vector2) -> Node3D:
	register()
	return DESIGNED.spawn(parent, sheet, at, size, element, times, erode)


# --- Molten Palm's fist ----------------------------------------------------------------------------------------
# comic_fist.gd keeps its node, flight tween and timing (the tentacle follows the node); designed, it draws this sheet
# on a camera-facing quad turned to the flight on screen instead of its polygon fist.

const FIST_SIZE := 2.5  # m: the quad (the fist itself is ~1.9 m across on screen, as the polygon one was)
const FIST_DISSOLVE := 0.22  # s after the hold: the crust cools and breaks into globs (the polygon one shrank in 0.12)


static func fist_mesh(node: Node3D) -> MeshInstance3D:
	register()
	var mi := MeshInstance3D.new()
	mi.mesh = DESIGNED._mesh_for("sprite")
	mi.material_override = DESIGNED.material("magma_fist")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = FIST_SIZE
	mi.scale = Vector3.ONE * FIST_SIZE
	node.add_child(mi)
	mi.set_instance_shader_parameter("pal_row", DESIGNED.row("earth"))
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("frame", 0.0)
	return mi


## Turn the fist sheet (drawn flying to +x) to `screen_a` (radians on screen), mirrored when it flies left so its
## lit top stays up.
static func aim_sprite(mi: MeshInstance3D, screen_a: float) -> void:
	if cos(screen_a) < 0.0:
		mi.set_instance_shader_parameter("spin", screen_a + PI)
		mi.set_instance_shader_parameter("flip", -1.0)
	else:
		mi.set_instance_shader_parameter("spin", screen_a)
		mi.set_instance_shader_parameter("flip", 1.0)


## The fist's frame and erosion at `t` s into a flight of `time` s that holds `hold` s where it lands.
static func fist_step(mi: MeshInstance3D, t: float, time: float, hold: float) -> void:
	var f := 0
	var e := 0.0
	if t < 0.033:
		f = 0
	elif t < time:
		f = 1 + (int(t * 12.0) % 2)  # the flight boils on twos
	elif t < time + hold:
		f = 3
	else:
		var k := clampf((t - time - hold) / FIST_DISSOLVE, 0.0, 1.0)
		f = 4 + mini(3, int(k * 4.0))
		e = smoothstep(0.25, 1.0, k)
	mi.set_instance_shader_parameter("frame", float(f))
	mi.set_instance_shader_parameter("erode", e * 0.98)


# --- Spikes: lava spurts (earth) and ice crystal clusters (water) --------------------------------------------------

const SPURT_SIZE := 2.2  # m: the quad at size 1 (the tongues stand ~1.2 m)
const SPIKE_TOWARD_CAM := 0.35  # m: stood a little towards the camera so the floor doesn't clip the plate
## Ice on the floor where a crystal cluster used to burst up (fx-ice2): a frost patch with fat straight cracks
## racing out (`ice_mark`) and a low puff of cold mist (`dust_puff` in water's tones).
const FROST_MARK_SIZE := 1.7  # m: the tile at size 1 (the cracks reach ~0.85 of it across)
const FROST_MIST_SIZE := 0.7  # of DESIGNED.dust's size at size 1
const FROST_MARK_TIMES := [0.04, 0.09, 0.2, 0.14]  # s: cracks half out, out (hot), settling, eroding by facets
const FROST_MIST_TIMES := [0.04, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11, 0.12]


## elements.spikes, designed: one drawn cluster (it holds three shards / tongues) in place of `count` cones; four or
## more add a smaller second one beside it.
static func spikes(parent: Node, pos: Vector3, el: String, size := 1.0, count := 3, life := 0.7) -> void:
	var foot := Vector3(pos.x, 0.0, pos.z)
	_spike(parent, foot, el, size, life)
	if count >= 4:
		var a := randf() * TAU
		_spike(parent, foot + Vector3(sin(a), 0.0, cos(a)) * 0.55 * size, el, size * 0.7, life * 0.85)


static func _spike(parent: Node, foot: Vector3, el: String, size: float, life: float) -> Node3D:
	var hold := maxf(0.05, life * 0.4)
	if el == "water":  # (fx-ice2: no crystal clusters out of the floor any more)
		return frost_mark(parent, foot, size, life)
	# bulge, the throw, two settles, the slump crusting, cooled
	var times := [0.04, 0.083, 0.083, maxf(0.06, hold * 0.6), 0.083, 0.1, 0.12]
	var fx := _spawn(parent, "magma_spurt", foot, SPURT_SIZE * size, "earth", times, Vector2(0.68, 1.0))
	fx.real_until = 1
	fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam != null:
		var to := cam.global_position - foot
		fx.global_position += Vector3(to.x, 0.0, to.z).normalized() * SPIKE_TOWARD_CAM
	return fx


## A water `elements.spikes` (fx-ice2, in place of the `ice_spike` crystals): frost cracks racing out on the floor
## at `foot` and a low puff of cold mist rolling off them. Nothing stands up out of the floor.
static func frost_mark(parent: Node, foot: Vector3, size := 1.0, life := 0.7, mist := true) -> Node3D:
	var k := clampf(life / 0.7, 0.7, 1.5)
	var times := FROST_MARK_TIMES.duplicate()
	times[2] *= k
	times[3] *= k
	var fx := _spawn(parent, "ice_mark", Vector3(foot.x, DESIGNED.GROUND_LIFT, foot.z), FROST_MARK_SIZE * size, "water",
		times, Vector2(0.55, 1.0))
	fx.real_until = 2
	fx.rotation.y = randf() * TAU
	if mist:
		var m := _spawn(parent, "dust_puff", foot, DESIGNED.DUST_SIZE * FROST_MIST_SIZE * size, "water", FROST_MIST_TIMES,
			Vector2(0.35, 1.0))
		m.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	return fx


# --- Fissure: Molten Palm's line of lava (a crack decal a step, a spurt every other step) ----------------------------

const CRACK_SIZE := 2.1  # m: the tile (the seam runs its length along the line; steps are ~0.8 m apart)
const CRACK_TIMES := [0.06, 0.12, 0.25, 0.35]


static func fissure(parent: Node, from: Vector3, dir: Vector3, length: float, steps: int, el: String, size := 1.0,
		step_time := 0.035) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	for i in steps:
		var at := from + flat * (1.0 + i * (length - 1.0) / maxf(steps - 1, 1))
		var k := lerpf(0.8, 1.2, float(i) / steps)
		var go := func() -> void:
			if not is_instance_valid(parent) or not parent.is_inside_tree():
				return
			if el == "earth":
				var c := _spawn(parent, "magma_crack", Vector3(at.x, DESIGNED.GROUND_LIFT, at.z), CRACK_SIZE * size * k, "earth",
					CRACK_TIMES, Vector2(0.6, 1.0))
				c.rotation.y = atan2(flat.x, flat.z) + PI * 0.5 + randf_range(-0.12, 0.12)  # the seam runs along the line
				if i % 2 == 0:
					_spike(parent, Vector3(at.x, 0.0, at.z), "earth", size * k * 0.85, 0.5)
			else:
				# a frost line racing along the floor (Harpoon): a crack every step, mist on every other one
				frost_mark(parent, Vector3(at.x, 0.0, at.z), size * k * (1.0 if i % 2 == 0 else 0.78), 0.7, i % 2 == 0)
		if i == 0:
			go.call()
		else:
			parent.get_tree().create_timer(i * step_time, false).timeout.connect(go)


# --- The frost spear's floor and the Deep Freeze burst -------------------------------------------------------------

const FROST_BURST_REACH := 0.4  # of Deep Freeze's ring radius the burst's cracks run out to
const FROST_BOIL := 0.33  # s a frame once the frost has spread (ice boils slowly: its glints move)
static var _unit_plane: PlaneMesh


## A floor quad 2 x 2 m (radius 1, like frost_spear's mesh) with the frost sheet: the spear scales it by its radius.
static func frost_floor() -> MeshInstance3D:
	register()
	if _unit_plane == null:
		_unit_plane = PlaneMesh.new()
		_unit_plane.size = Vector2.ONE * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = _unit_plane
	mi.material_override = DESIGNED.material("ice_frost")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.set_instance_shader_parameter("pal_row", DESIGNED.row("water"))
	mi.set_instance_shader_parameter("frame", 0.0)
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.rotation.y = randf() * TAU
	return mi


## The frost's frame at `t` s after planting, `spread` 0..1 of its radius.
static func frost_step(mi: MeshInstance3D, t: float, spread: float) -> void:
	var f := 0 if spread < 0.55 else 1 + int(t / FROST_BOIL) % 3
	mi.set_instance_shader_parameter("frame", float(f))


## Deep Freeze going off: the frost cracks out to `radius` in one beat and breaks up (frost_spear.frost_ring's ring).
static func frost_burst(parent: Node, spot: Vector3, radius: float) -> Node3D:
	# only the sheet's first frame (the cracks running out, drawn to 0.55 of the frame), sized so they reach `radius`:
	# the full frost (teeth, plates) over a 13 m breaker landing was a wall of ice under the pile
	# (0.7 of `radius`, let alone all of it, still crossed the whole screen on the film)
	var fx := _spawn(parent, "ice_frost", Vector3(spot.x, DESIGNED.GROUND_LIFT, spot.z), radius * FROST_BURST_REACH * 2.0 / 0.6,
		"water", [0.32], Vector2(0.35, 1.0))
	fx.real_until = 1
	fx.scale = Vector3.ONE * 0.55  # the cracks race out on twos
	var tw := fx.create_tween().set_ignore_time_scale()
	for k in 3:
		tw.tween_interval(1.0 / 12.0)
		tw.tween_callback(func() -> void: fx.scale = Vector3.ONE * (0.7 + 0.15 * k))
	fx.rotation.y = randf() * TAU
	return fx


# --- Faceted 3D ice: the ice block round a frozen foe, the frost spear ---------------------------------------------
# Not a flipbook: these stay 3D (they turn, the foe stands inside). A hexagonal block and faceted crystals, each face
# one flat cel tone by how it faces the camera, a light rim, a specular stripe, straight cracks, inked by the ghost
# hull (shaders/ice_facet.gdshader). No bare boxes, cylinders or spheres.

const FACET_SHADER := preload("res://shaders/ice_facet.gdshader")
const INK_SHADER := preload("res://shaders/ghost_ink.gdshader")
const FACET_INK_PX := 3.0
static var _facet_mats := {}
static var _blocks := {}


## A facet material in `element`'s tones (shared): `opaque` for the spear's shaft, see-through otherwise.
static func facet_material(element := "water", opaque := false) -> ShaderMaterial:
	var key := element + ("_o" if opaque else "")
	if _facet_mats.has(key):
		return _facet_mats[key]
	var pal: Dictionary = DESIGNED.PAL.of(element)
	var fill := ShaderMaterial.new()
	fill.shader = FACET_SHADER
	for k: String in ["ink", "deep", "body", "light", "hot"]:
		fill.set_shader_parameter("c_" + k, pal[k])
	if opaque:
		fill.set_shader_parameter("fill_alpha", 1.0)
		fill.set_shader_parameter("crack_chance", 0.0)
	fill.render_priority = 1
	var ink := ShaderMaterial.new()
	ink.shader = INK_SHADER
	ink.set_shader_parameter("ink_color", pal.ink)
	ink.set_shader_parameter("width_px", FACET_INK_PX)
	ink.render_priority = 2
	fill.next_pass = ink
	_facet_mats[key] = fill
	return fill


## Builds faces into a SurfaceTool in the facet shader's contract. Each piece has a centre for its corner normals.
class Facets:
	var st := SurfaceTool.new()
	var centre := Vector3.ZERO
	var seed_n := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _v(p: Vector3, flat: Vector3, s: float, uv: Vector2) -> void:
		st.set_color(Color(flat.x * 0.5 + 0.5, flat.y * 0.5 + 0.5, flat.z * 0.5 + 0.5, s))
		var cn := p - centre
		st.set_normal(cn.normalized() if cn.length() > 0.001 else Vector3.UP)
		st.set_uv(uv)
		st.add_vertex(p)

	func _seed() -> float:
		seed_n += 1
		return fmod(seed_n * 0.618034, 1.0)

	## A quad a b c d (counter-clockwise seen from outside) with UV 0..1.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var n := (b - a).cross(d - a).normalized()
		var s := _seed()
		_v(a, n, s, Vector2(0, 1)); _v(c, n, s, Vector2(1, 0)); _v(b, n, s, Vector2(1, 1))  # (Godot's front faces wind clockwise)
		_v(a, n, s, Vector2(0, 1)); _v(d, n, s, Vector2(0, 0)); _v(c, n, s, Vector2(1, 0))

	## A triangle whose edge a-b is a face edge (rim along it); the apex c is not.
	func tri(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a).normalized()
		var s := _seed()
		_v(a, n, s, Vector2(0, 0)); _v(c, n, s, Vector2(0.5, 1)); _v(b, n, s, Vector2(1, 0))

	## A fan cap (polygon `ring`, counter-clockwise seen from outside): one tone, a rim only round its outline.
	func cap(ring: Array) -> void:
		var mid := Vector3.ZERO
		for p: Vector3 in ring:
			mid += p
		mid /= ring.size()
		var r0: Vector3 = ring[0]
		var r1: Vector3 = ring[1]
		var n := (r1 - r0).cross(mid - r0).normalized()
		var s := _seed()
		for i in ring.size():
			_v(ring[i], n, s, Vector2(0.5, 0.0)); _v(mid, n, s, Vector2(0.5, 0.5)); _v(ring[(i + 1) % ring.size()], n, s, Vector2(0.5, 0.0))

	## A tapered prism of `sides` from y0 (radius r0) to y1 (radius r1) round `at`, turned by `turn`.
	func prism(at: Vector3, sides: int, r0: float, r1: float, y0: float, y1: float, turn := 0.0, top := true) -> void:
		centre = at + Vector3.UP * (y0 + y1) * 0.5
		var lo := []
		var hi := []
		for i in sides:
			var a := turn + TAU * i / sides
			var d := Vector3(cos(a), 0.0, -sin(a))
			lo.append(at + d * r0 + Vector3.UP * y0)
			hi.append(at + d * r1 + Vector3.UP * y1)
		for i in sides:
			var j := (i + 1) % sides
			quad(lo[i], lo[j], hi[j], hi[i])
		if top and r1 > 0.001:
			cap(hi)

	## A crystal: a `sides` prism body with a pointed `tip` on top, leaning along `lean` (a direction * amount).
	func crystal(at: Vector3, sides: int, r: float, body: float, tip: float, lean: Vector3, turn := 0.0) -> void:
		centre = at + Vector3.UP * body * 0.6 + lean * 0.5
		var lo := []
		var hi := []
		for i in sides:
			var a := turn + TAU * i / sides
			var d := Vector3(cos(a), 0.0, -sin(a))
			lo.append(at + d * r)
			hi.append(at + d * r * 0.9 + Vector3.UP * body + lean * body)
		var apex: Vector3 = at + Vector3.UP * (body + tip) + lean * (body + tip)
		for i in sides:
			var j := (i + 1) % sides
			quad(lo[i], lo[j], hi[j], hi[i])
			tri(hi[i], hi[j], apex)

	func commit(mat: Material) -> ArrayMesh:
		var mesh := st.commit()
		mesh.surface_set_material(0, mat)
		return mesh


## The ice block round a frozen foe (thrown_foe.comic_cube): a hexagonal prism `r` round (to its flats) and `high`
## tall, centred on its middle, its top a little narrower (BLOCK_TAPER). Clean faces only: fx-ice2 took the crown
## crystals off its top (Zak: "get rid of the crystals. i love the new ice block"). Cached per size, in BLOCK_STEP
## steps so fitted blocks share meshes. `fit_block` sizes one to the foe inside.
static func ice_block(r: float, high: float) -> ArrayMesh:
	var key := Vector2i(roundi(r * 100.0), roundi(high * 100.0))
	if _blocks.has(key):
		return _blocks[key]
	var f := Facets.new()
	var h := high * 0.5
	var rc := r / cos(PI / 6.0)  # corner radius, so the flats sit at r
	f.prism(Vector3.ZERO, 6, rc, rc * BLOCK_TAPER, -h, h, 0.2)
	var mesh := f.commit(facet_material("water"))
	_blocks[key] = mesh
	return mesh


# --- Fitting the block to the foe inside (fx-ice2) -----------------------------------------------------------------
# Zak: "ensure they're covering the whole character model tho. the dummies part of them clip out." The block used to
# be `radius + 0.2` round and 1.5 m tall at the foe's feet whatever the model; now it is measured from the model's
# own posed meshes: each skinned mesh's vertices are boxed per bone once (in the bone's rest space, cached per mesh),
# so a freeze only moves ~30 boxes by their bones' poses. The foe holds its pose while frozen (enemy.gd stops its
# clip; the dummy's bag spring holds its tilt), so the block made at the freeze still holds it.

const BLOCK_TAPER := 0.94  # the top's radius, of the bottom's
const BLOCK_STEP := 0.05  # m: fitted sizes round up to this (the mesh cache)
const FIT_MARGIN := 0.08  # m clear round the model's widest point
const FIT_TOP := 0.1  # m clear over its head
const FIT_CORE := 0.75  # m from the foe's middle that counts as its body: the block centres on what is in there
const FIT_R_MIN := 0.5
const FIT_R_MAX := 1.2  # m: weapons held out further than this poke out ("within reason": a sword at arm's length
	# made a 2.5 m slab that swallowed the dummy beside it)
const FIT_H_MAX := 3.4
const FIT_DIRS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1),
	Vector3(0, 0, -1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, 1, 1),
	Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1)]  # a bone's extreme vertices are kept along these
static var _bone_boxes := {}  # "mesh id:skin id" -> {bind index: PackedVector3Array, its extreme vertices in its rest space}


## The extreme vertices of `foe`'s model meshes (per bone, posed by that bone), in `foe`'s space, with the model standing upright at its
## own `model_scale` (enemy.freeze stands it up, and a hit's squash is gone in a beat). Empty if it has no meshes.
static func model_points(foe: Node3D) -> PackedVector3Array:
	var model: Node3D = foe.get("model") if foe.get("model") is Node3D else foe
	var out := PackedVector3Array()
	var ms: float = float(foe.get("model_scale")) if foe.get("model_scale") != null else 1.0
	if model == foe:
		ms = 1.0
	var pose := Transform3D.IDENTITY if model == foe else Transform3D(Basis(Vector3.UP, model.rotation.y).scaled(Vector3.ONE * ms), Vector3.ZERO)
	var model_inv := model.global_transform.affine_inverse()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.has_meta("no_ghost") or mi.name == "ThrownCube":
			continue
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		var local: Array[Transform3D] = []  # mesh-ish space -> model space, one per set
		var sets: Array[PackedVector3Array] = []
		if sk != null and mi.skin != null:
			var per := _boxes_of(mi, sk)
			var to_model := model_inv * sk.global_transform
			for b: int in per:
				var bone := mi.skin.get_bind_bone(b)
				if bone < 0:
					bone = sk.find_bone(mi.skin.get_bind_name(b))
				if bone < 0:
					continue
				local.append(to_model * sk.get_bone_global_pose(bone))
				sets.append(per[b])
		else:
			local.append(model_inv * mi.global_transform)
			var box := mi.mesh.get_aabb()
			var corners := PackedVector3Array()
			for c in 8:
				corners.append(box.get_endpoint(c))
			sets.append(corners)
		for i in sets.size():
			var xf := pose * local[i]
			for v in sets[i]:
				out.append(xf * v)
	return out


## A skinned mesh's vertices sorted to their main bone, in that bone's rest space, and only each bone's extreme ones
## along FIT_DIRS kept (a box's corners turned with the bone came out ~10% wide; these are real vertices).
static func _boxes_of(mi: MeshInstance3D, sk: Skeleton3D) -> Dictionary:
	var key := "%d:%d" % [mi.mesh.get_instance_id(), mi.skin.get_instance_id()]
	if _bone_boxes.has(key):
		return _bone_boxes[key]
	var skin: Skin = mi.skin
	var binds: Array[Transform3D] = []
	for b in skin.get_bind_count():
		binds.append(skin.get_bind_pose(b))
	var per := {}
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] == null or verts.is_empty():
			continue
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var n := bones.size() / verts.size()
		for i in verts.size():
			var b := -1  # its main bone: a vertex boxed by every bone it is weighted to swung whole limbs' boxes
			var best := 0.0  # round a hand (every box came out 1.5 m round)
			for k in n:
				if weights[i * n + k] > best:
					best = weights[i * n + k]
					b = bones[i * n + k]
			if b < 0 or b >= binds.size():
				continue
			var p := binds[b] * verts[i]
			if not per.has(b):
				var first := PackedVector3Array()
				first.resize(FIT_DIRS.size())
				first.fill(p)
				per[b] = first
				continue
			var ext: PackedVector3Array = per[b]
			for d in FIT_DIRS.size():
				if p.dot(FIT_DIRS[d]) > ext[d].dot(FIT_DIRS[d]):
					ext[d] = p
			per[b] = ext
	_bone_boxes[key] = per
	return per


## The block that encloses `points` (foe space): {centre: Vector3 (the middle of the prism), r: flat radius, high}.
## Round, so the block may turn (the ice cube spins in flight) without a corner swinging in onto the model.
static func block_fit(points: PackedVector3Array, floor_y := -INF) -> Dictionary:
	if points.is_empty():
		return {"centre": Vector3(0.0, 0.75, 0.0), "r": 0.6, "high": 1.5}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var y0 := INF
	var y1 := -INF
	for p in points:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
		if Vector2(p.x, p.z).length() <= FIT_CORE:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var c := (lo + hi) * 0.5 if lo.x <= hi.x else Vector2.ZERO
	y0 = maxf(y0, floor_y)
	y1 = minf(y1 + FIT_TOP, y0 + FIT_H_MAX)
	var high := ceilf((y1 - y0) / BLOCK_STEP) * BLOCK_STEP
	var need := 0.0
	var core := 0.0
	for p in points:
		if p.y < y0 - 0.01 or p.y > y1:
			continue
		var t := clampf((p.y - y0) / maxf(high, 0.01), 0.0, 1.0)
		var d := Vector2(p.x, p.z).distance_to(c) / lerpf(1.0, BLOCK_TAPER, t)
		need = maxf(need, d)
		if Vector2(p.x, p.z).length() <= FIT_CORE:
			core = maxf(core, d)
	var r := clampf(maxf(minf(need, FIT_R_MAX), core) + FIT_MARGIN, FIT_R_MIN, FIT_R_MAX + FIT_MARGIN)
	r = ceilf(r / BLOCK_STEP) * BLOCK_STEP
	return {"centre": Vector3(c.x, y0 + high * 0.5, c.y), "r": r, "high": high}


## Sizes the ice `ice` (a MeshInstance3D child of `foe`: enemy._ice, thrown_foe's cube) to the foe's model as it
## stands now and centres it on it, turned at random so a row of frozen foes doesn't line up into one slab.
static func fit_block(foe: Node3D, ice: MeshInstance3D) -> Dictionary:
	var floor_y := -0.08 - foe.global_position.y  # (never down through the floor: a sword tip under it pokes out)
	var fit := block_fit(model_points(foe), floor_y)
	ice.mesh = ice_block(fit.r, fit.high)
	ice.material_override = null
	ice.position = fit.centre
	ice.rotation = Vector3(0.0, randf() * TAU, 0.0)
	return fit


## The frost spear (frost_spear.gd): a faceted shaft in the tentacle's violet driven into the floor with a clean
## faceted ice point on it. Built along +Y from the floor, in its own node. fx-ice2: no ring of crystals round its
## foot and no crystal head (`crystals`, `crystal_high`, `out` kept for the callers, unused).
static func spear(node: Node3D, high: float, shaft_r: float, _crystals := 0, _crystal_high := 0.0, _out := 0.0) -> void:
	var shaft := Facets.new()
	shaft.prism(Vector3.ZERO, 6, shaft_r * 0.7, shaft_r, -0.1, high * 0.82, 0.3)
	var mi := MeshInstance3D.new()
	mi.mesh = shaft.commit(facet_material("void", true))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	node.add_child(mi)
	var ice := Facets.new()
	# one slim four-sided point on the shaft's end: a spearhead, not a cluster
	ice.crystal(Vector3.UP * high * 0.8, 4, shaft_r * 1.35, high * 0.06, high * 0.2, Vector3.ZERO, 0.4)
	var mi2 := MeshInstance3D.new()
	mi2.mesh = ice.commit(facet_material("water"))
	mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi2.set_meta("no_ghost", true)
	node.add_child(mi2)


# --- Meteor Fall's fireball in flight, the lava geysers, the lava pool under Undertow ------------------------------

const METEOR_SIZE := 4.6  # m: the quad (the ball ~1.65 m across round him, the tongues streaming ~2.2 m back)
const METEOR_BACK := 0.9  # m: stood this far behind him from the camera (depth tested: he reads in front of the ball)
const METEOR_IGNITE := 0.06  # s on the white-hot ignite frame before the boil


## What he comes down inside on Meteor Fall (void_element.meteor_shell, designed): the drawn fireball turned to the
## dive on screen. hero_leap moves the returned node with him and frees it on landing (the landing burst takes over).
static func meteor_shell(parent: Node, travel: Vector3) -> Node3D:
	register()
	var s := MeteorShell.new()
	s.travel = travel
	parent.add_child(s)
	return s


class MeteorShell extends Node3D:
	var travel := Vector3.DOWN
	var _mi: MeshInstance3D
	var _t := 0.0
	var _step := -1
	var _last_us := 0

	func _ready() -> void:
		_mi = MeshInstance3D.new()
		_mi.mesh = DESIGNED._mesh_for("sprite_depth")
		_mi.material_override = DESIGNED.material("magma_meteor")
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.set_meta("no_ghost", true)
		_mi.extra_cull_margin = METEOR_SIZE
		_mi.scale = Vector3.ONE * METEOR_SIZE
		add_child(_mi)
		_mi.set_instance_shader_parameter("pal_row", DESIGNED.row("earth"))
		_mi.set_instance_shader_parameter("erode", 0.0)
		_last_us = Time.get_ticks_usec()
		_follow()

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		_t += float(now - _last_us) / 1000000.0  # real time: the dive's slow motion mustn't freeze the boil
		_last_us = now
		_follow()

	func _follow() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_mi.position = -cam.global_basis.z * METEOR_BACK  # (the shell is never turned: hero_leap only moves it)
			var d := travel.normalized()
			var a := atan2(d.dot(cam.global_basis.y), d.dot(cam.global_basis.x))
			var left := cos(a) < 0.0  # mirrored when it flies left, so its lit top stays up
			_mi.set_instance_shader_parameter("spin", a + PI if left else a)
			_mi.set_instance_shader_parameter("flip", -1.0 if left else 1.0)
		var step := 0 if _t < METEOR_IGNITE else 1 + int((_t - METEOR_IGNITE) * 12.0) % 4  # boils on twos
		if step != _step:
			_step = step
			_mi.set_instance_shader_parameter("frame", float(step))


const GEYSER_QUAD := 1.5  # quad side per metre of column (the column stands 0.66 of the sheet at its peak)
const GEYSER_COLUMN := 0.18  # the column's width, of the quad (gen_elements: w0 0.36 of the half frame)
const GEYSER_TIMES := [0.04, 0.07, 0.07, 0.06, 0.06, 0.07, 0.08, 0.09]  # ~0.54 s: a rim geyser is a beat, not a wall


## A lava geyser `high` m tall (elements.geyser / rim_geyser, designed): the drawn column punching up, its crown
## splashing, falling back into a crusted mound. Depth tested, stood on the floor.
static func geyser(parent: Node, at: Vector3, high: float) -> Node3D:
	var foot := Vector3(at.x, 0.0, at.z)
	var fx := _spawn(parent, "magma_geyser", foot, high * GEYSER_QUAD, "earth", GEYSER_TIMES, Vector2(0.62, 1.0))
	fx.real_until = 1
	fx.set_spin(0.0, -1.0 if randf() < 0.5 else 1.0)
	fx.add_to_group("comic_geyser")  # (fx_sleek_check counts them as geysers)
	fx.set_meta("width", high * GEYSER_QUAD * GEYSER_COLUMN)
	var cam := parent.get_viewport().get_camera_3d() if parent.is_inside_tree() else null
	if cam != null:
		var to := cam.global_position - foot
		fx.global_position += Vector3(to.x, 0.0, to.z).normalized() * SPIKE_TOWARD_CAM
	return fx


const POOL_QUAD := 2.25  # quad side per metre of the well's radius (drawn 0.36 of the quad round: 2.6 merged a pile's pools)
const POOL_TIMES := [0.05, 0.12, 0.17, 0.17, 0.2, 0.2]  # ~0.9 s (elements.WELL_COMIC_SHOW): the burn outlasts the look


## The lava pool a foe is pulled down into (elements.Well's comic mark, designed): a crack splitting open, the pool
## boiling with crust rafts and popping domes, crusting over.
static func pool(parent: Node, at: Vector3, radius: float) -> Node3D:
	var fx := _spawn(parent, "magma_pool", Vector3(at.x, DESIGNED.GROUND_LIFT, at.z), radius * POOL_QUAD, "earth", POOL_TIMES,
		Vector2(0.7, 1.0))
	fx.real_until = 1
	fx.rotation.y = randf() * TAU
	return fx
