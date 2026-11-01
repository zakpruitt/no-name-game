extends MeshInstance3D
## Ribbon trail that follows a weapon mesh while `emitting` is true.
## Samples the weapon's base and tip each frame, smooths the curve between
## samples (Catmull-Rom) and draws it with shaders/weapon_trail.gdshader:
## a crescent with a bright leading edge whose tail erodes with noise.

const SHADER := preload("res://shaders/weapon_trail.gdshader")
const NOISE := preload("res://assets/vfx/noise_soft.png")
const SUBDIV := 3  # interpolated steps between frame samples (fast swings stay round)
const REACH := 1.2  # trail tip past the blade tip, as a fraction of blade length

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
var _points: Array = []  # [base: Vector3, tip: Vector3, age: float]
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
	for p in _points:
		p[2] += delta
	while not _points.is_empty() and _points[0][2] > lifetime:
		_points.pop_front()
	if emitting and is_instance_valid(weapon) and weapon.is_visible_in_tree():
		var xf := weapon.global_transform
		_points.append([xf * _base_local, xf * _tip_local, 0.0])

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
				_catmull(p0[1], p1[1], p2[1], p3[1], t), age)
	var last: Array = _points[0]
	_vertex_pair(last[0], last[1], last[2])
	_imesh.surface_end()


func _vertex_pair(base: Vector3, tip: Vector3, age: float) -> void:
	var u := clampf(age / lifetime, 0.0, 1.0)
	_imesh.surface_set_color(color)
	_imesh.surface_set_uv(Vector2(u, 0.0))
	_imesh.surface_add_vertex(base)
	_imesh.surface_set_color(color)
	_imesh.surface_set_uv(Vector2(u, 1.0))
	_imesh.surface_add_vertex(tip)


static func _catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	return b.cubic_interpolate(c, a, d, t)
