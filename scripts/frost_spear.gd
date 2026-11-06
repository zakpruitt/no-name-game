extends Node3D
## The spear he plants in the ground (L L, right click). Frost spreads out from it and slows whoever's
## on it, and that's all it does until he slams down onto it (void_element._deep_freeze). Only one at
## a time. See docs/features/void-element.md.

const STANDING := preload("res://scripts/standing_fx.gd")
const FOES := preload("res://scripts/foes.gd")
const GROUP := "frost_spear"
const RADIUS := 6.0  # m the frost reaches
const GROW := 0.6  # s to get there
const LIFE := 5.0  # s it stands, unless he sets it off
const MELT := 0.3  # s to go
const TICK := 0.15  # s between slows
const SLOW := 0.45  # what foes' speed drops to
const SLOW_TIME := 0.5  # s the slow outlasts the last tick
const PULSE_EVERY := 1.2  # s between rings of frost going out (round 33, sleek 5: 0.7 kept two up over a crowd)
const PULSE_TIME := 0.6  # s
const SHAFT_HIGH := 2.3  # m
const SHAFT_R := 0.13  # m
const TILT := 0.2  # radians
const CRYSTALS := 6
const CRYSTAL_HIGH := 1.4  # m
const CRYSTAL_OUT := 0.32  # m from the shaft
const ICE := Color(0.62, 0.9, 1.0)
const ICE_LIGHT := Color(0.88, 0.98, 1.0)
const SHAFT := Color(0.36, 0.1, 0.42)
const FROST_INK := Color(0.03, 0.05, 0.12)
const FROST_CRACKS := 11  # inked ice cracks running out from the spear
const FROST_TEETH := 26  # the frost's jagged edge
const FROST_PATCHES := 4  # ice plates scattered between the cracks (round 33, sleek: 7 cluttered it)
## Round 33, part 3: the frost's fill is the halftone ice of the spikes and cubes (shaders/halftone_floor.gdshader:
## the water palette's dots, clear in the middle, densest at the toothed edge, so it still reads as a zone),
## in place of the round-29 plates' flat two-tone ice. Cracks and teeth keep their ink.
const ZONE_SHADER := preload("res://shaders/halftone_floor.gdshader")
const PAL := preload("res://scripts/fx_palette.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")  # round 46: the drawn frost floor
const ZONE_FILL := 0.26  # (0.34 read as a carpet 12 m across)
const ZONE_INNER := 0.45  # of the radius: clear inside
const ZONE_PLATES := false  # the round-29 plates (the zone's dots replace them)

var _t := 0.0
var _next_tick := 0.0
var _next_pulse := 0.0
var _r := 0.0
var _gone := false
var _cleared := false  # the frost's look has gone (standing_fx.gd)
var _frost: MeshInstance3D
var _zone: MeshInstance3D  # the halftone fill under the cracks (a child of _frost)
var _stuck: Node3D
var _designed := false  # the frost floor is the ice_frost sheet (designed_elements.frost_floor)


## Plants one at `spot`, in place of any already standing.
static func plant(parent: Node, spot: Vector3) -> Node3D:
	var old: Node3D = current(parent.get_tree())
	if old != null:
		old.melt()
	var s: Node3D = new()
	parent.add_child(s)
	s.global_position = Vector3(spot.x, 0.0, spot.z)
	return s


## The one standing, or null.
static func current(tree: SceneTree) -> Node3D:
	for s: Node in tree.get_nodes_in_group(GROUP):
		return s
	return null


func _ready() -> void:
	add_to_group(GROUP)
	STANDING.add(self)
	_designed = DESIGNED_EL.DESIGNED.on()
	if _designed:
		_frost = DESIGNED_EL.frost_floor()
		_frost.position.y = DESIGNED_EL.DESIGNED.GROUND_LIFT
		_frost.scale = Vector3(0.01, 1.0, 0.01)
		add_child(_frost)
	else:
		_frost = MeshInstance3D.new()
		_frost.mesh = frost_mesh(RandomNumberGenerator.new())
		_frost.material_override = frost_material()
		_frost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_frost.position.y = 0.05
		_frost.scale = Vector3(0.01, 1.0, 0.01)
		add_child(_frost)
	_zone = MeshInstance3D.new()
	_zone.mesh = zone_mesh()
	_zone.material_override = zone_material()
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_zone.position.y = 0.015  # over the cracks (0..0.008): below them it hid under the tiles but for the grout
	if not _designed:
		_frost.add_child(_zone)
	else:
		_zone.free()
		_zone = null
	_stuck = Node3D.new()
	add_child(_stuck)
	var lean := randf() * TAU
	if _designed:  # round 46: a faceted shaft with an ice point (designed_elements.spear; fx-ice2: no crystal ring)
		DESIGNED_EL.spear(_stuck, SHAFT_HIGH, SHAFT_R)
		_stuck.rotation = Vector3(TILT * cos(lean), 0.0, TILT * sin(lean))
	else:
		_build_stuck(lean)
	_stuck.scale = Vector3(1.0, 0.1, 1.0)
	create_tween().tween_property(_stuck, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _designed:  # frost cracking out and cold mist where it goes in (fx-ice2: was a burst of crystal shards)
		DESIGNED_EL.frost_mark(get_parent(), global_position, 0.8, 0.6)
	else:
		Fx.shards(get_parent(), global_position + Vector3.UP * 0.3, ICE_LIGHT, 12, Vector3.UP, 7.0, 0.12, 0.5)


## The round-29 spear: a cylinder shaft, a sphere knob and four-sided prisms (--fx=classic).
func _build_stuck(lean: float) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = SHAFT_R
	shaft.bottom_radius = SHAFT_R * 0.6
	shaft.height = SHAFT_HIGH
	shaft.radial_segments = 6
	var body := _part(shaft, SHAFT)
	body.position.y = SHAFT_HIGH * 0.5
	body.rotation = Vector3(TILT * cos(lean), 0.0, TILT * sin(lean))
	body.position += Vector3(sin(TILT) * SHAFT_HIGH * 0.5 * sin(-lean), 0.0, sin(TILT) * SHAFT_HIGH * 0.5 * cos(lean))
	var knob := SphereMesh.new()
	knob.radius = SHAFT_R * 2.6
	knob.height = SHAFT_R * 5.2
	knob.radial_segments = 6
	knob.rings = 3
	var top := MeshInstance3D.new()
	top.mesh = knob
	top.material_override = _flat(ICE_LIGHT, true)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top.position.y = SHAFT_HIGH * 0.5
	body.add_child(top)
	for i in CRYSTALS:
		var a := TAU * i / CRYSTALS + randf() * 0.5
		var high := CRYSTAL_HIGH * randf_range(0.6, 1.1)
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = 0.26
		prism.height = high
		prism.radial_segments = 4
		var c := _part(prism, ICE if i % 2 == 0 else ICE_LIGHT)
		c.position = Vector3(cos(a) * CRYSTAL_OUT, high * 0.4, sin(a) * CRYSTAL_OUT)
		c.rotation = Vector3(sin(a) * 0.5, randf() * TAU, -cos(a) * 0.5)


## The frost on the floor at radius 1 (scaled to how far it has spread): inked cracks out from the spear,
## a ring of ice teeth for its edge and a few chunky plates, with bare floor between. A flat 30% disc
## here read as a grey slab 12 m across that washed out everything standing on it.
static func frost_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	rng.randomize()
	var st := SurfaceTool.new()  # (an object: a lambda captures packed arrays by value)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector2, b: Vector2, d: Vector2, col: Color, y: float) -> void:
		st.set_color(col)
		for p: Vector2 in [a, b, d]:
			st.add_vertex(Vector3(p.x, y, p.y))
	for i in FROST_CRACKS:  # a jagged crack: three kinked spans, wide at the spear, to a point
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / FROST_CRACKS
		var reach := rng.randf_range(0.7, 1.0)
		var pts := [Vector2.ZERO]
		for k in 3:
			var r := reach * (k + 1) / 3.0
			var b := a + rng.randf_range(-0.22, 0.22)
			pts.append(Vector2(cos(b), sin(b)) * r)
		for layer: Array in [[0.042, FROST_INK, 0.0], [0.03, ICE, 0.004], [0.01, ICE_LIGHT, 0.008]]:  # round 33: m per m of RADIUS (0.1 was a 0.6 m ink band)
			for k in 3:
				var p: Vector2 = pts[k]
				var q: Vector2 = pts[k + 1]
				var side := (q - p).orthogonal().normalized()
				var wp: float = layer[0] * (1.0 - k / 3.0)
				var wq: float = layer[0] * (1.0 - (k + 1) / 3.0)
				tri.call(p + side * wp, p - side * wp, q + side * wq, layer[1], layer[2])
				tri.call(q + side * wq, p - side * wp, q - side * wq, layer[1], layer[2])
	for i in FROST_TEETH:  # the edge: ice teeth pointing in, each on an ink tooth
		var a0 := TAU * i / FROST_TEETH
		var a1 := TAU * (i + 1) / FROST_TEETH
		var am := (a0 + a1) * 0.5
		var depth := rng.randf_range(0.04, 0.08)  # round 33 (sleek): 0.1-0.2 of a 6 m frost was a 1 m band of teeth
		var o0 := Vector2(cos(a0), sin(a0))
		var o1 := Vector2(cos(a1), sin(a1))
		var tip := Vector2(cos(am), sin(am)) * (1.0 - depth)
		tri.call(o0 * 1.008, o1 * 1.008, tip * 0.985, FROST_INK, 0.0)
		tri.call(o0, o1, tip, ICE if i % 2 == 0 else ICE_LIGHT, 0.004)
	for i in FROST_PATCHES if ZONE_PLATES else 0:  # chunky plates of ice between the cracks
		var a := TAU * (i + 0.5) / FROST_PATCHES + rng.randf_range(-0.2, 0.2)
		var at := Vector2(cos(a), sin(a)) * rng.randf_range(0.35, 0.75)
		var size := rng.randf_range(0.06, 0.11)
		var ring := []
		for k in 5:
			var b := TAU * k / 5.0 + rng.randf()
			ring.append(Vector2(cos(b), sin(b)) * size * rng.randf_range(0.7, 1.2))
		for k in 5:
			tri.call(at, at + ring[k] * 1.15, at + ring[(k + 1) % 5] * 1.15, FROST_INK, 0.0)
		for k in 5:
			tri.call(at, at + ring[k], at + ring[(k + 1) % 5], ICE_LIGHT if k < 2 else ICE, 0.004)
	return st.commit()


static var _frost_mat: StandardMaterial3D
static var _zone_mat: ShaderMaterial
static var _zone_mesh: ArrayMesh


## The halftone frost fill: water palette dots, shared. Drawn in elements.prewarm().
static func zone_material() -> ShaderMaterial:
	if _zone_mat == null:
		var pal := PAL.of("water")
		_zone_mat = ShaderMaterial.new()
		_zone_mat.shader = ZONE_SHADER
		_zone_mat.set_shader_parameter("body_color", pal.body)
		_zone_mat.set_shader_parameter("dot_color", pal.light)
		_zone_mat.set_shader_parameter("fill", ZONE_FILL)
		_zone_mat.set_shader_parameter("inner", ZONE_INNER)
	return _zone_mat


## A flat disc of radius 1 in XZ.
static func zone_mesh() -> ArrayMesh:
	if _zone_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 48
		for i in n:
			var a := TAU * i / n
			var b := TAU * (i + 1) / n
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(cos(a), 0.0, sin(a)))
			st.add_vertex(Vector3(cos(b), 0.0, sin(b)))
		_zone_mesh = st.commit()
	return _zone_mesh


## Flat vertex colours, depth tested so foes stand on it. Shared, and drawn in elements.prewarm().
static func frost_material() -> StandardMaterial3D:
	if _frost_mat == null:
		_frost_mat = StandardMaterial3D.new()
		_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_frost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_frost_mat.vertex_color_use_as_albedo = true
		_frost_mat.vertex_color_is_srgb = true
	return _frost_mat


func _part(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _flat(color, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stuck.add_child(m)
	return m


func _flat(color: Color, ink := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if ink and DisplayServer.get_name() != "headless":
		mat.next_pass = Fx.ink_material()
	return mat


func _physics_process(delta: float) -> void:
	if _gone:
		return
	_t += delta
	_r = RADIUS * smoothstep(0.0, GROW, _t)
	_frost.scale = Vector3(maxf(_r, 0.01), 1.0, maxf(_r, 0.01))
	if _designed:
		DESIGNED_EL.frost_step(_frost, _t, _r / RADIUS)
	if _t >= _next_tick:
		_next_tick += TICK
		for e: Node3D in FOES.near(get_tree(), global_position, _r):
			if e.has_method("chill"):
				e.chill(SLOW_TIME, SLOW)
	if _t >= _next_pulse:
		_next_pulse += PULSE_EVERY
		if not _cleared and not _designed:  # (designed: the drawn frost's glints carry it; one ring at a time)
			frost_ring(get_parent(), global_position, RADIUS, PULSE_TIME)
	if _t >= LIFE:
		melt()


## A thin hard-edged ring of frost going out to `radius`.
static func frost_ring(parent: Node, spot: Vector3, radius: float, time: float) -> void:
	if DESIGNED_EL.DESIGNED.on():  # round 46: the frost cracking out in one drawn beat
		DESIGNED_EL.frost_burst(parent, spot, radius)
		return
	var torus := TorusMesh.new()
	torus.inner_radius = 0.985  # round 33 (sleek): a thin line racing out (sleek 5: 0.97 was 0.18 m at 6 m)
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(ICE_LIGHT, 0.55)
	var m := MeshInstance3D.new()
	m.mesh = torus
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = Vector3(spot.x, 0.08, spot.z)
	m.scale = Vector3(0.2, 0.05, 0.2)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(radius, 0.05, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.5).set_delay(time * 0.5)
	tw.chain().tween_callback(m.queue_free)


## The next string's first hit landed (standing_fx.gd): the floor frost and its rings fade; the spear and
## its chill stay for the ice breaker.
func clear_standing() -> void:
	_cleared = true
	if _designed:
		create_tween().tween_method(func(e: float) -> void: _frost.set_instance_shader_parameter("erode", e), 0.0, 0.98, STANDING.CLEAR_S)
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(_frost, "transparency", 1.0, STANDING.CLEAR_S)
	tw.tween_method(func(a: float) -> void: _zone.set_instance_shader_parameter("alpha", a), 1.0, 0.0, STANDING.CLEAR_S)


## Gone quietly: time's up, or another took its place.
func melt() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	var tw := create_tween()
	if _designed and not _cleared:
		create_tween().tween_method(func(e: float) -> void: _frost.set_instance_shader_parameter("erode", e), 0.0, 0.98, MELT)
	tw.tween_property(self, "scale", Vector3(1.0, 0.01, 1.0), MELT)
	tw.tween_callback(queue_free)


## Gone in pieces: he slammed onto it.
func shatter() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	if _designed:
		DESIGNED_EL.DESIGNED.ice_shatter(get_parent(), global_position + Vector3.UP * 0.9, 1.0)
	else:
		Fx.shards(get_parent(), global_position + Vector3.UP * 0.8, ICE_LIGHT, 26, Vector3.UP, 13.0, 0.2, 0.8)
	queue_free()
