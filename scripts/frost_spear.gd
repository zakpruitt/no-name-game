extends Node3D
## The spear he plants in the ground (L L, right click). Frost spreads out from it and slows whoever's
## on it, and that's all it does until he slams down onto it (void_element._deep_freeze). Only one at
## a time. See docs/features/void-element.md.

const GROUP := "frost_spear"
const RADIUS := 6.0  # m the frost reaches
const GROW := 0.6  # s to get there
const LIFE := 5.0  # s it stands, unless he sets it off
const MELT := 0.3  # s to go
const TICK := 0.15  # s between slows
const SLOW := 0.45  # what foes' speed drops to
const SLOW_TIME := 0.5  # s the slow outlasts the last tick
const PULSE_EVERY := 0.7  # s between rings of frost going out
const PULSE_TIME := 0.6  # s
const SHAFT_HIGH := 2.3  # m
const SHAFT_R := 0.13  # m
const TILT := 0.2  # radians
const CRYSTALS := 6
const CRYSTAL_HIGH := 1.0  # m
const CRYSTAL_OUT := 0.32  # m from the shaft
const ICE := Color(0.62, 0.9, 1.0)
const ICE_LIGHT := Color(0.88, 0.98, 1.0)
const SHAFT := Color(0.36, 0.1, 0.42)
const FROST_ALPHA := 0.3

var _t := 0.0
var _next_tick := 0.0
var _next_pulse := 0.0
var _r := 0.0
var _gone := false
var _frost: MeshInstance3D
var _stuck: Node3D


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
	_frost = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 32
	_frost.mesh = disc
	_frost.material_override = _flat(Color(ICE, FROST_ALPHA))
	_frost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frost.position.y = 0.05
	_frost.scale = Vector3(0.01, 1.0, 0.01)
	add_child(_frost)
	_stuck = Node3D.new()
	add_child(_stuck)
	var lean := randf() * TAU
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
		prism.bottom_radius = 0.17
		prism.height = high
		prism.radial_segments = 4
		var c := _part(prism, ICE if i % 2 == 0 else ICE_LIGHT)
		c.position = Vector3(cos(a) * CRYSTAL_OUT, high * 0.4, sin(a) * CRYSTAL_OUT)
		c.rotation = Vector3(sin(a) * 0.5, randf() * TAU, -cos(a) * 0.5)
	_stuck.scale = Vector3(1.0, 0.1, 1.0)
	create_tween().tween_property(_stuck, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	Fx.shards(get_parent(), global_position + Vector3.UP * 0.3, ICE_LIGHT, 12, Vector3.UP, 7.0, 0.12, 0.5)


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
	if _t >= _next_tick:
		_next_tick += TICK
		for e: Node3D in Ascendancy.enemies_near(get_tree(), global_position, _r):
			if e.has_method("chill"):
				e.chill(SLOW_TIME, SLOW)
	if _t >= _next_pulse:
		_next_pulse += PULSE_EVERY
		frost_ring(get_parent(), global_position, RADIUS, PULSE_TIME)
	if _t >= LIFE:
		melt()


## A thin hard-edged ring of frost going out to `radius`.
static func frost_ring(parent: Node, spot: Vector3, radius: float, time: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(ICE_LIGHT, 0.9)
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


## Gone quietly: time's up, or another took its place.
func melt() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 0.01, 1.0), MELT)
	tw.tween_callback(queue_free)


## Gone in pieces: he slammed onto it.
func shatter() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	Fx.shards(get_parent(), global_position + Vector3.UP * 0.8, ICE_LIGHT, 26, Vector3.UP, 13.0, 0.2, 0.8)
	queue_free()
