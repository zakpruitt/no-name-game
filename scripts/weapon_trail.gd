extends MeshInstance3D
## Ribbon trail that follows a weapon mesh while `emitting` is true.
## Samples the weapon's base and tip each frame, smooths the curve between
## samples (Catmull-Rom) and draws it with shaders/weapon_trail.gdshader:
## a crescent with a bright leading edge whose tail erodes with noise.

const SHADER := preload("res://shaders/weapon_trail.gdshader")
const NOISE := preload("res://assets/vfx/noise_soft.png")
const SUBDIV := 3  # interpolated steps between frame samples (fast swings stay round)
const REACH := 1.2  # trail tip past the blade tip, as a fraction of blade length
# The ribbon swells with the hit: each Fx.CHAIN_TIERS tier the chain passes and
# the latest hit's weight (Game.hit_weight, from its hitstop) stretch each new
# sample's tip (a wider crescent), lengthen its life and fill the shader's body
# (UV2.x = the swell, 0..1). Samples keep the swell they were drawn with.
const CHAIN_GROW := 0.1  # extra reach per chain tier (x1.3 at tier 3)
const HIT_GROW := 0.25  # extra reach at full hit weight
const LIFE_GROW := 0.6  # extra lifetime per unit of swell (x1.33 at the most)

@export var lifetime := 0.2
## Body colour (alpha = opacity); the leading edge is this lightened toward white.
@export var color := Color(1.0, 0.95, 0.8, 0.8):
	set(c):
		color = c
		_mat.set_shader_parameter("edge_color", c.lerp(Color.WHITE, 0.7))

var weapon: MeshInstance3D
var emitting := false

var _base_local := Vector3.ZERO
var _tip_local := Vector3.UP
var _points: Array[Array] = []  # [base: Vector3, tip: Vector3, age: float, life: float, swell: float]
var _imesh := ImmediateMesh.new()
var _mat := ShaderMaterial.new()


func setup(weapon_mesh: MeshInstance3D) -> void:
	weapon = weapon_mesh
	# Use the mesh's longest axis as the blade line; the far end is the tip.
	var box := weapon.get_aabb()
	var axis := 0
	for i in 3:
		if box.size[i] > box.size[axis]:
			axis = i
	var center := box.get_center()
	_base_local = center
	_base_local[axis] = box.position[axis] + box.size[axis] * 0.35
	_tip_local = center
	_tip_local[axis] = lerpf(_base_local[axis], box.end[axis], REACH)


func _init() -> void:
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise", NOISE)
	color = color


func _ready() -> void:
	top_level = true
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _mat


func _process(delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	for p: Array in _points:
		p[2] += delta
	while not _points.is_empty() and _points[0][2] > _points[0][3]:
		_points.pop_front()
	if emitting and is_instance_valid(weapon) and weapon.is_visible_in_tree():
		var xf := weapon.global_transform
		var grow := swell()
		var base: Vector3 = xf * _base_local
		var tip: Vector3 = xf * _tip_local
		_points.append([base, base + (tip - base) * (1.0 + grow), 0.0, lifetime * (1.0 + LIFE_GROW * grow), grow])

	_imesh.clear_surfaces()
	var n := _points.size()
	if n < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	# Newest sample first, so UV.x runs 0 (at the blade) -> 1 (oldest).
	for i in range(n - 1, 0, -1):
		var p0: Array = _points[mini(i + 1, n - 1)]
		var p1: Array = _points[i]
		var p2: Array = _points[i - 1]
		var p3: Array = _points[maxi(i - 2, 0)]
		for s in SUBDIV:
			var t := float(s) / SUBDIV
			var age: float = lerpf(p1[2], p2[2], t)
			_vertex_pair(
				_catmull(p0[0], p1[0], p2[0], p3[0], t),
				_catmull(p0[1], p1[1], p2[1], p3[1], t), age,
				lerpf(p1[3], p2[3], t), lerpf(p1[4], p2[4], t))
	var last: Array = _points[0]
	_vertex_pair(last[0], last[1], last[2], last[3], last[4])
	_imesh.surface_end()


## 0 = the plain ribbon; grows CHAIN_GROW per chain tier and HIT_GROW per hit weight.
func swell() -> float:
	return CHAIN_GROW * Fx.chain_tier(Game.combo_count) + HIT_GROW * Game.hit_weight


func _vertex_pair(base: Vector3, tip: Vector3, age: float, life: float, grow: float) -> void:
	var u := clampf(age / life, 0.0, 1.0)
	var uv2 := Vector2(clampf(grow, 0.0, 1.0), 0.0)
	_imesh.surface_set_color(color)
	_imesh.surface_set_uv(Vector2(u, 0.0))
	_imesh.surface_set_uv2(uv2)
	_imesh.surface_add_vertex(base)
	_imesh.surface_set_color(color)
	_imesh.surface_set_uv(Vector2(u, 1.0))
	_imesh.surface_set_uv2(uv2)
	_imesh.surface_add_vertex(tip)


static func _catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	return b.cubic_interpolate(c, a, d, t)
