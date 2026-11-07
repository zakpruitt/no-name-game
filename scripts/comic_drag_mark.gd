extends MeshInstance3D
## The line a dragged axe leaves on the floor, in its element: a ribbon of an outer colour with a
## hot inner line, in world space. It cools in hard steps and thins out as it ages, like the rest of
## the comic effects, rather than a soft fade. comic_axe_aura feeds it the blade's tip.
## stages  [outer, inner] per step of its life; a colour's alpha is how solid the step is
## jag     how far the line jumps side to side; crackle re-rolls it while it's fresh (lightning)
## broken  chance a stretch of line is skipped, so a cut reads as slashes

const LOOKS := {
	"earth": {"life": 4.5, "width": 0.3, "jag": 0.02, "stages": [
		[Color(1, 0.42, 0.06), Color(1, 0.88, 0.32)],
		[Color(0.85, 0.18, 0.04), Color(1, 0.5, 0.08)],
		[Color(0.14, 0.07, 0.06), Color(0.55, 0.12, 0.03)],
		[Color(0.07, 0.05, 0.06, 0.6), Color(0.07, 0.05, 0.06, 0.0)],
	]},
	"wind": {"life": 1.8, "width": 0.13, "jag": 0.16, "crackle": 0.7, "broken": 0.14, "stages": [
		[Color(0.42, 1, 0.5), Color(0.96, 1, 0.9)],
		[Color(0.14, 0.45, 0.24), Color(0.5, 1, 0.6)],
		[Color(0.03, 0.05, 0.08, 0.75), Color(0.1, 0.2, 0.14, 0.7)],
	]},
	"water": {"life": 3.2, "width": 0.34, "jag": 0.04, "stages": [
		[Color(0.42, 0.8, 1), Color(0.95, 1, 1)],
		[Color(0.5, 0.82, 1, 0.8), Color(0.85, 0.97, 1, 0.9)],
		[Color(0.6, 0.85, 1, 0.4), Color(0.8, 0.94, 1, 0.45)],
	]},
	"spirit": {"life": 2.6, "width": 0.22, "jag": 0.05, "stages": [
		[Color(0.2, 0.92, 0.82), Color(1, 0.92, 0.6)],
		[Color(0.1, 0.62, 0.6), Color(0.45, 1, 0.88)],
		[Color(0.06, 0.36, 0.38, 0.55), Color(0.2, 0.7, 0.66, 0.5)],
	]},
}
const STEP_M := 0.22  # a new point every so far along
const LIFTED := 0.4  # m above the floor: the blade isn't on it
const JUMP := 1.5  # m in one frame: he teleported, or a new room
const FLOOR_LIFT := 0.06  # over the floor stones' tallest (0.05), as Fx.scorch
const INNER_LIFT := 0.004
const INNER_WIDTH := 0.4
const THIN_TO := 0.45  # of its width at the end of its life
const CRACKLE_PER_S := 14.0
const MAX_POINTS := 90
## fx-polygons (designed): the line is the drawn drag_line strip (shaders/designed_drag.gdshader) repeated every
## D_TILE m along it, each vertex carrying its age: it cools down the element's ramp and erodes from its old end.
const POLISH := preload("res://scripts/designed_polish.gd")
const DRAG_SHADER := preload("res://shaders/designed_drag.gdshader")
const D_TILE := 1.1  # m of line one tile of the strip covers
const D_WIDTH := 1.7  # of the look's width: the strip's banks fill ~0.6 of it
const D_ROW := {"earth": "earth", "wind": "wind", "water": "water", "spirit": "spirit"}
static var _d_mats := {}
var _designed := false
var _dist := 0.0

var look: Dictionary
## {pos, age, side (unit, across the line), jag, gap, fresh}, oldest first. `fresh` starts a line.
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
	_designed = POLISH.DESIGNED.on()
	if _designed:
		material_override = _drag_material(element)
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat


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
	points.append({"dist": _dist, "pos": at, "age": 0.0, "side": side, "jag": randf_range(-1.0, 1.0), "gap": randf() < broken, "fresh": fresh})
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
	if _designed:
		_draw_designed()
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var drew := false
	for layer in 2:  # the inner line after the outer, so it draws on top
		for i in range(1, points.size()):
			var a: Dictionary = points[i - 1]
			var b: Dictionary = points[i]
			if b.fresh or b.gap:
				continue
			_quad(a, b, layer)
			drew = true
	if not drew:  # every stretch skipped: an empty surface is an error
		var p: Vector3 = points[0].pos
		_imesh.surface_set_color(Color(0, 0, 0, 0))
		for _v in 3:
			_imesh.surface_add_vertex(p)
	_imesh.surface_end()


func _draw_designed() -> void:
	set_instance_shader_parameter("pal_row", POLISH.DESIGNED.row(D_ROW.get(_element, "earth")))
	set_instance_shader_parameter("frame", float(int(_clock * 12.0) % 4))
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var drew := false
	for i in range(1, points.size()):
		var a: Dictionary = points[i - 1]
		var b: Dictionary = points[i]
		if b.fresh or b.gap:
			continue
		var pa := _centre(a, 0)
		var pb := _centre(b, 0)
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
	if not drew:
		var p: Vector3 = points[0].pos
		_imesh.surface_set_color(Color(1, 0, 0, 0))
		for _v in 3:
			_imesh.surface_set_uv(Vector2.ZERO)
			_imesh.surface_add_vertex(p)
	_imesh.surface_end()


func _quad(a: Dictionary, b: Dictionary, layer: int) -> void:
	var c := _colour(b, layer)
	if c.a <= 0.0:
		return
	var w := INNER_WIDTH if layer == 1 else 1.0
	var pa := _centre(a, layer)
	var pb := _centre(b, layer)
	var sa: Vector3 = a.side * _half_width(a) * w
	var sb: Vector3 = b.side * _half_width(b) * w
	_imesh.surface_set_color(c)
	for v: Vector3 in [pa - sa, pb - sb, pa + sa, pa + sa, pb - sb, pb + sb]:
		_imesh.surface_add_vertex(v)


## The stage is the newer point's, so a line cools in visible blocks from its old end.
func _colour(p: Dictionary, layer: int) -> Color:
	var stages: Array = look.stages
	var k: float = p.age / look.life
	return stages[mini(int(k * stages.size()), stages.size() - 1)][layer]


func _half_width(p: Dictionary) -> float:
	return look.width * 0.5 * lerpf(1.0, THIN_TO, p.age / look.life)


func _centre(p: Dictionary, layer: int) -> Vector3:
	var jag: float = p.jag
	var crackle: float = look.get("crackle", 0.0)
	if p.age < crackle:  # re-rolled in steps while it's live, the same for both layers
		jag = sin((floorf(_clock * CRACKLE_PER_S) + 1.0) * (1.0 + absf(jag) * 7.0) + jag * 11.0)
	var at: Vector3 = p.pos + p.side * jag * look.jag
	return at + Vector3.UP * (INNER_LIFT if layer == 1 else 0.0)
