extends Node
## A foe the tentacle has sent flying: it travels to a spot and bursts on the first foe or wall in its
## way, hurting both. launch()'s `opts` set what kind of flight it is: `el` what it bursts in, `pierce`
## runs through foes (bowling), `quiet` just stops at the end unless a wall stops it first (a shove or a
## reel), `solid` false ignores other foes, `tether` draws a tentacle to it, `wall_mult` is a wall splat's
## damage. Frozen foes fly as ice cubes (cube_on()). See docs/features/void-element.md.

const FOES := preload("res://scripts/foes.gd")
const VOID_ELEMENT := preload("res://scripts/void_element.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")  # round 46: the faceted ice block

const SPEED := 20.0  # m/s
const LAND_Y := 0.4  # m it comes down to
const HIT_GAP := 0.25  # m between bodies that counts as a hit
const SPLASH := 2.6  # m round the burst
const OTHER_MULT := 0.7  # of the damage, to whoever it hits
const SPLASH_MULT := 0.5
const SHOVE := 6.0
const STUN := 0.9  # s a foe that isn't frozen is stunned as it goes
const WIND_LAUNCH := 7.0  # what a storm burst does to whoever's near
const CUBE_NAME := "ThrownCube"
const CUBE_COLOR := Color(0.62, 0.9, 1.0)
const CUBE_HIGH := 1.5  # m
const CUBE_SPIN := 9.0  # radians/s
# The comic cube: see-through halftone ice (comic_cube) with the ink edge, clear enough to show the foe inside.
# The old 55% cyan box hid the foe and was the loudest thing in every ice frame.
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const CUBE_GLINT := Color(1.0, 1.0, 1.0, 0.85)

static var _cube_mat: StandardMaterial3D
static var _cube_meshes := {}  # (radius, height) in cm -> mesh
const WALL_MARGIN := 0.5  # m short of a wall
const FLYING := "thrown_foe_flying"  # meta on a foe in flight: nothing else may move it
const WALL_META := "last_wall_ms"  # meta: Time.get_ticks_msec() of its last wall splat (Meteor Fall goes for these)
const GROUP := "thrown_foes"  # every flight in progress (cut())
const ZAP_STEP := 0.08  # s between a `zap` flight's jolts
const ZAP_REACH := 3.2  # m it jumps to whoever it passes
const ZAP_MAX := 5  # jolts a flight gives at most

var hero: CharacterBody3D
var foe: Node3D
var damage := 0.0
var el := "water"
var pierce := false
var quiet := false
var solid := true
var tether := false
var wall_mult := 1.0
var speed := SPEED
var land_y := LAND_Y
var zap := false  # Storm Pitch: lightning jumps from it to anyone it passes (ZAP_*)
var _zaps := 0
var _next_zap := 0.0
var _from := Vector3.ZERO
var _dir := Vector3.FORWARD
var _length := 0.0
var _gone := 0.0
var _walled := false
var _struck := {}
var _rope: Node3D
var _time := 0.0


## Throws `e` at the spot `to`. Returns the node driving it, or null if it can't go.
static func launch(by: Variant, e: Variant, to: Vector3, dmg: float, opts := {}) -> Node:  # (untyped: either may be freed by a delayed call)
	if not is_instance_valid(e) or not e.is_alive() or not is_instance_valid(by) or e.has_meta(FLYING):
		return null
	var t := new()
	t.hero = by
	t.foe = e
	t.damage = dmg
	for k: String in opts:
		t.set(k, opts[k])
	by.get_parent().add_child(t)
	t.add_to_group(GROUP)
	e.set_meta(FLYING, true)
	if float(e.get("frozen_t") if e.get("frozen_t") != null else 0.0) <= 0.0 and e.has_method("stagger"):
		e.stagger(STUN)
	t._aim(to)
	if t.tether:
		t._rope = TENDRIL.new()
		t.add_child(t._rope)
	Game.sfx("swing_heavy", -2.0, 0.12)
	return t


static func flying(e: Node) -> bool:
	return e.has_meta(FLYING)


## Ends `e`'s flight where it is, so the next move can take it (Storm Pitch off Tow Line's tether, Meteor Fall's beats).
static func cut(e: Variant) -> void:
	if not is_instance_valid(e) or not e.has_meta(FLYING):
		return
	for t: Node in e.get_tree().get_nodes_in_group(GROUP):
		if t.foe == e and not t.is_queued_for_deletion():
			e.global_position.y = 0.0
			t.quiet = true
			t._finish()


## Encases a frozen foe in a cube, in place of the plain ice cylinder. enemy.gd's _thaw() takes it off.
static func cube_on(e: Node3D) -> void:
	if not is_instance_valid(e):
		return
	var ice: Variant = e.get("_ice")
	if ice != null:
		ice.visible = false  # (freezing again shows it again)
	if e.get_node_or_null(CUBE_NAME) != null:
		return
	var r: float = float(e.get("radius")) + 0.1
	var cube := MeshInstance3D.new()
	cube.name = CUBE_NAME
	if Game.comic_style:
		cube.mesh = comic_cube(r)  # (its surfaces carry their materials)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(r * 2.0, CUBE_HIGH, r * 2.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(CUBE_COLOR, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if DisplayServer.get_name() != "headless":
			mat.next_pass = Fx.ink_material()
		cube.mesh = box
		cube.material_override = mat
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(cube)
	cube.position.y = CUBE_HIGH * 0.5


## One shared material for the cube's glint: unshaded vertex colour (the block itself is spirit_echo.ghost_mat).
static func cube_material() -> StandardMaterial3D:
	if _cube_mat == null:
		_cube_mat = StandardMaterial3D.new()
		_cube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cube_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cube_mat.vertex_color_use_as_albedo = true
		_cube_mat.vertex_color_is_srgb = true
		_cube_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cube_mat


## A frozen foe's ice (enemy.freeze, comic style): the same halftone block, `r` round and `high` tall.
static func comic_ice(ice: MeshInstance3D, r: float, high: float) -> void:
	ice.mesh = comic_cube(r, high)
	ice.material_override = null  # (the mesh's surfaces carry the ghost block and the glint)
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Round 33, part 3: a block `r` round and `high` tall in the see-through halftone ice of the spikes (the water
## palette's spirit_echo.ghost_mat: dots, a thin ink line and a light edge; the round-29 flat two-tone box was
## the last opaque-looking ice), with a white glint across the top on its own surface. Corner normals point out
## of the corner, so the ink hull (pushed out along them) closes round the box instead of splitting at its edges.
static func comic_cube(r: float, high := CUBE_HIGH) -> ArrayMesh:
	if DESIGNED.on():  # round 46: a hexagonal block of drawn facets (designed_elements.ice_block)
		return DESIGNED_EL.ice_block(r, high)
	var key := Vector2i(roundi(r * 100.0), roundi(high * 100.0))
	if _cube_meshes.has(key):
		return _cube_meshes[key]
	var h := high * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		for v: Vector3 in [a, b, c, a, c, d]:
			st.set_normal(Vector3(v.x / r, v.y / h, v.z / r).normalized())
			st.add_vertex(v)
	var top := [Vector3(-r, h, -r), Vector3(r, h, -r), Vector3(r, h, r), Vector3(-r, h, r)]
	var bot := [Vector3(-r, -h, -r), Vector3(r, -h, -r), Vector3(r, -h, r), Vector3(-r, -h, r)]
	quad.call(top[0], top[1], top[2], top[3])
	quad.call(bot[3], bot[2], bot[1], bot[0])
	for i in 4:
		var j := (i + 1) % 4
		quad.call(bot[i], bot[j], top[j], top[i])
	var mesh := st.commit()
	mesh.surface_set_material(0, SPIRIT_ECHO.ghost_mat(CUBE_COLOR))
	# A glint: a fat white stroke across a corner of the top, just above it.
	var gl := SurfaceTool.new()
	gl.begin(Mesh.PRIMITIVE_TRIANGLES)
	gl.set_color(CUBE_GLINT)
	var g := h + 0.01
	for v: Vector3 in [Vector3(-r * 0.75, g, r * 0.15), Vector3(-r * 0.15, g, r * 0.75), Vector3(0.0, g, r * 0.6),
			Vector3(-r * 0.75, g, r * 0.15), Vector3(0.0, g, r * 0.6), Vector3(-r * 0.6, g, 0.0)]:
		gl.add_vertex(v)
	gl.commit(mesh)
	mesh.surface_set_material(1, cube_material())
	_cube_meshes[key] = mesh
	return mesh


static func remove_cube(e: Variant) -> void:
	if is_instance_valid(e):
		var cube: Node = e.get_node_or_null(CUBE_NAME)
		if cube != null:
			cube.queue_free()


func _aim(to: Vector3) -> void:
	_from = foe.global_position
	var flat := Vector3(to.x - _from.x, 0.0, to.z - _from.z)
	_dir = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var clear := _clear(flat.length())
	_walled = clear < flat.length()
	_length = minf(flat.length(), clear)


## How far it can fly before a wall.
func _clear(length: float) -> float:
	return clear_from(hero, foe, _from, _dir, length)


## How far `e` can fly from `from` along `dir` before a wall (`length` if none that close). Molten Palm asks it
## first, to carry them on to a wall in reach.
static func clear_from(by: Node3D, e: Node3D, from: Vector3, dir: Vector3, length: float) -> float:
	var start := Vector3(from.x, 0.9, from.z)
	var q := PhysicsRayQueryParameters3D.create(start, start + dir * (length + WALL_MARGIN), by.collision_mask)
	q.exclude = [e.get_rid(), by.get_rid()]
	for o: Node in e.get_tree().get_nodes_in_group("enemies"):
		q.exclude.append(o.get_rid())
	var hit := e.get_world_3d().direct_space_state.intersect_ray(q)
	return length if hit.is_empty() else maxf(start.distance_to(hit.position) - WALL_MARGIN, 0.0)


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return  # (cut(): another move has it now)
	if not is_instance_valid(foe) or not foe.is_alive():
		_finish()
		return
	_time += delta
	_gone = minf(_gone + speed * delta, _length)
	var k := _gone / maxf(_length, 0.01)
	var at := _from + _dir * _gone
	at.y = lerpf(_from.y, land_y, k * k)
	foe.global_position = at
	foe.velocity = Vector3.ZERO
	var cube := foe.get_node_or_null(CUBE_NAME)
	if cube != null:
		cube.rotate_y(CUBE_SPIN * delta)
	if _rope != null and hero._void != null:
		_rope.draw(hero._void._hand_pos(), at + Vector3.UP * 0.9, 1.0, 0.03, float(foe.get("radius")) + 0.05, _time)
	if zap and _zaps < ZAP_MAX and _time >= _next_zap:
		_zap(at)
	if solid:
		var other := _first_in_the_way()
		if other != null:
			if pierce:
				_struck[other] = true
				_hit_other(other)
			else:
				_burst(other)
				return
	if _gone >= _length:
		if quiet and not _walled:
			foe.global_position.y = 0.0
			_finish()
		else:
			_burst(null)


## One jolt from it to the nearest foe it's passing (Storm Pitch: the axe's storm rides the thrown foe).
func _zap(at: Vector3) -> void:
	var best: Node3D = null
	var best_d := ZAP_REACH
	for o: Node in foe.get_tree().get_nodes_in_group("enemies"):
		if o == foe or not o.is_alive():
			continue
		var d: float = (o.global_position - at).length()
		if d < best_d:
			best_d = d
			best = o
	if best == null:
		return
	_zaps += 1
	_next_zap = _time + ZAP_STEP
	VOID_ELEMENT.COMIC_ARC.jump(hero.get_parent(), at + Vector3.UP, best.global_position + Vector3.UP)
	best.take_hit(VOID_ELEMENT.WIRE_DAMAGE * float(hero.get("_dmg_mult")), Vector3.ZERO, 0.0, false)
	VOID_ELEMENT.mark(best, "charged")
	Game.register_hit("cast")


func _first_in_the_way() -> Node3D:
	for o: Node in foe.get_tree().get_nodes_in_group("enemies"):
		if o == foe or not o.is_alive() or _struck.has(o):
			continue
		var gap := Vector3(o.global_position.x - foe.global_position.x, 0.0, o.global_position.z - foe.global_position.z)
		if gap.length() <= float(o.radius) + float(foe.get("radius")) + HIT_GAP and absf(o.global_position.y - foe.global_position.y) < 2.0:
			return o
	return null


func _hit_other(o: Node3D) -> void:
	o.take_hit(damage * OTHER_MULT, _dir * SHOVE, WIND_LAUNCH if el == "wind" else 0.0, true)
	_count(o)
	if el == "water":
		VOID_ELEMENT.encase(o)
	Game.sfx("hit_big", -5.0, 0.1)
	Game.hitstop(0.03)


## It stops hard: on `other` if it hit someone, and whoever's close takes the element too.
func _burst(other: Node3D) -> void:
	var parent := hero.get_parent()
	var spot := Vector3(foe.global_position.x, 0.0, foe.global_position.z)
	foe.global_position.y = 0.0
	remove_cube(foe)
	VOID_ELEMENT.under(parent, spot, el)
	Game.sfx("hit_big", -2.0, 0.1)
	Game.hitstop(0.04)
	Game.shake(0.3)
	if _walled and other == null:
		foe.set_meta(WALL_META, Time.get_ticks_msec())
		if DESIGNED.on() and el == "earth":  # round 43: Molten Palm's splat on the wall (designed_fx.wall_splat)
			DESIGNED.wall_splat(parent, spot + _dir * (float(foe.get("radius")) + WALL_MARGIN * 0.8) + Vector3.UP * 1.05)
	if DESIGNED.on() and el == "wind":  # fx-air: Storm Pitch lands in a burst of wind (designed_fx.wind_burst)
		DESIGNED.wind_burst(parent, spot, _dir)
	if DESIGNED.on() and el == "water":  # the ice cube bursting (designed_fx.ice_shatter)
		DESIGNED.ice_shatter(parent, spot + Vector3.UP * 0.9)
	foe.take_hit(damage * (wall_mult if _walled and other == null else 1.0), _dir * 2.0, 0.0, true)
	_count(foe)
	if other != null:
		_hit_other(other)
	for e: Node3D in FOES.near(hero.get_tree(), spot, SPLASH):
		if e == foe or e == other or _struck.has(e):
			continue
		e.take_hit(damage * SPLASH_MULT, Vector3.ZERO, WIND_LAUNCH if el == "wind" else 0.0, false)
		_count(e)
		if el == "water":
			VOID_ELEMENT.encase(e)
	_finish()


func _count(_e: Node3D) -> void:
	Game.register_hit("breaker")


func _finish() -> void:
	if is_instance_valid(foe):
		foe.remove_meta(FLYING)
		if not quiet:
			remove_cube(foe)
	queue_free()
