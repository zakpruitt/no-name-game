extends MeshInstance3D
## Ribbon trail that follows a weapon mesh while `emitting` is true.
## Samples the weapon's base and tip each frame and fades old samples out.

@export var lifetime := 0.13
@export var color := Color(1.0, 0.95, 0.8, 0.8)

var weapon: MeshInstance3D
var emitting := false

var _base_local := Vector3.ZERO
var _tip_local := Vector3.UP
var _points: Array = []  # [base: Vector3, tip: Vector3, age: float]
var _imesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()


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
	_tip_local[axis] = box.end[axis]


func _ready() -> void:
	top_level = true
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
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
	if _points.size() < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in _points:
		var k: float = 1.0 - p[2] / lifetime
		var c := Color(color.r, color.g, color.b, color.a * k * k)
		_imesh.surface_set_color(Color(c.r, c.g, c.b, 0.0))
		_imesh.surface_add_vertex(p[0])
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(p[1])
	_imesh.surface_end()
