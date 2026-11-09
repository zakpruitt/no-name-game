extends MeshInstance3D
## The line a dragged axe leaves on the floor, in its element, in world space: the drawn drag_line strip
## (shaders/designed_drag.gdshader) repeated every D_TILE m along it, each vertex carrying its age, so it cools down
## the element's ramp and erodes from its old end. comic_axe_aura feeds it the blade's tip.
## broken  chance a stretch of line is skipped, so a cut reads as slashes

const LOOKS := {
	"earth": {"life": 4.5, "width": 0.3},
	"wind": {"life": 1.8, "width": 0.13, "broken": 0.14},
	"water": {"life": 3.2, "width": 0.34},
	"spirit": {"life": 2.6, "width": 0.22},
}
const STEP_M := 0.22  # a new point every so far along
const LIFTED := 0.4  # m above the floor: the blade isn't on it
const JUMP := 1.5  # m in one frame: he teleported, or a new room
const FLOOR_LIFT := 0.06  # over the floor stones' tallest (0.05), as Fx.scorch
const MAX_POINTS := 90
const POLISH := preload("res://scripts/designed_polish.gd")
const DRAG_SHADER := preload("res://shaders/designed_drag.gdshader")
const D_TILE := 1.1  # m of line one tile of the strip covers
const D_WIDTH := 1.7  # of the look's width: the strip's banks fill ~0.6 of it
static var _d_mats := {}
var _dist := 0.0

var look: Dictionary
## {dist, pos, age, side (unit, across the line), gap, fresh}, oldest first. `fresh` starts a line.
var points: Array[Dictionary] = []
var _imesh := ImmediateMesh.new()
var _clock := 0.0
var _lifted := true
var _element := "earth"


func setup(element: String) -> void:
	look = LOOKS[element]
	_element = element
	top_level = true
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("no_ghost", true)
	material_override = _drag_material(element)


## Where the blade's tip is this frame, and the height of the floor under him.
func track(tip: Vector3, floor_y: float) -> void:
	if tip.y - floor_y > LIFTED:
		_lifted = true
		return
	var at := Vector3(tip.x, floor_y + FLOOR_LIFT, tip.z)
	if points.is_empty():
		_add(at, Vector3.RIGHT, true)
	else:
		var run := at - (points[-1].pos as Vector3)
		if _lifted or run.length() > JUMP:
			_add(at, Vector3.RIGHT, true)
		elif run.length() >= STEP_M:
			_add(at, run.normalized().cross(Vector3.UP), false)
	_lifted = false


static func _drag_material(element: String) -> ShaderMaterial:
	if _d_mats.has(element):
		return _d_mats[element]
	POLISH.register()
	var m := ShaderMaterial.new()
	m.shader = DRAG_SHADER
	m.set_shader_parameter("sheet", POLISH.DESIGNED.sheet_of("drag_line").tex)
	m.set_shader_parameter("palette", POLISH.DESIGNED.palette())
	m.set_shader_parameter("palette_rows", float(POLISH.DESIGNED.ROWS.size()))
	m.set_shader_parameter("burn_hot", 1.0 if element == "earth" else 0.0)
	m.set_shader_parameter("rows", 4.0)
	m.set_shader_parameter("cool", 0.5 if element == "earth" else 0.3)
	_d_mats[element] = m
	return m


func _add(at: Vector3, side: Vector3, fresh: bool) -> void:
	var broken: float = look.get("broken", 0.0)
	if not points.is_empty() and not fresh:
		_dist += at.distance_to(points[-1].pos)
	points.append({"dist": _dist, "pos": at, "age": 0.0, "side": side, "gap": randf() < broken, "fresh": fresh})
	if points.size() > MAX_POINTS:
		points.pop_front()
	if fresh and points.size() > 1:
		points[-1].side = points[-2].side


func tick(delta: float) -> void:
	_clock += delta
	var life: float = look.life
	while not points.is_empty() and points[0].age + delta >= life:
		points.pop_front()
	for p in points:
		p.age += delta
	_draw()


func _draw() -> void:
	_imesh.clear_surfaces()
	if points.size() < 2:
		return
	set_instance_shader_parameter("pal_row", POLISH.DESIGNED.row(_element))
	set_instance_shader_parameter("frame", float(int(_clock * 12.0) % 4))
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var drew := false
	for i in range(1, points.size()):
		var a: Dictionary = points[i - 1]
		var b: Dictionary = points[i]
		if b.fresh or b.gap:
			continue
		var pa: Vector3 = a.pos
		var pb: Vector3 = b.pos
		var sa: Vector3 = a.side * _half_width(a) * D_WIDTH
		var sb: Vector3 = b.side * _half_width(b) * D_WIDTH
		var ua: float = a.dist / D_TILE
		var ub: float = b.dist / D_TILE
		var ka: float = a.age / look.life
		var kb: float = b.age / look.life
		for v: Array in [[pa - sa, ua, 0.0, ka], [pb - sb, ub, 0.0, kb], [pa + sa, ua, 1.0, ka],
				[pa + sa, ua, 1.0, ka], [pb - sb, ub, 0.0, kb], [pb + sb, ub, 1.0, kb]]:
			_imesh.surface_set_color(Color(v[3], 0.0, 0.0, 1.0))
			_imesh.surface_set_uv(Vector2(v[1], v[2]))
			_imesh.surface_add_vertex(v[0])
		drew = true
	if not drew:  # every stretch skipped: an empty surface is an error
		var p: Vector3 = points[0].pos
		_imesh.surface_set_color(Color(1, 0, 0, 0))
		for _v in 3:
			_imesh.surface_set_uv(Vector2.ZERO)
			_imesh.surface_add_vertex(p)
	_imesh.surface_end()


func _half_width(p: Dictionary) -> float:
	return look.width * 0.5
