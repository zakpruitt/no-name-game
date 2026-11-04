extends Node3D
## The burst when the heretic's limb changes shape (heretic_rig.gd): a hard-edged star at the hand,
## a stroke shooting down the new haft, and chips of ink and element. Flat geometry that faces the
## camera and is redrawn on twos, like comic_axe_aura.gd, because glow and soft dots read as a
## different game next to the inked hero.

const SELF := preload("res://scripts/heretic_form_fx.gd")  # (held: a load() at fire time recompiled it once freed)
const STEPS_PER_S := 12.0  # on twos, at the clips' 24 fps
const STEPS := 5  # then it's gone
const INK := Color(0.012, 0.01, 0.02)
const GRAVITY := 7.0
const STAR_SPIKES := 9
const STAR_STRETCH := 0.4  # further along the haft than across it
## Biggest at once, then gone by about 0.25 s, when strikes start landing: it mustn't hide the swing.
const STAR_SIZE_BY_STEP := [1.0, 0.8, 0.45]  # step past the end: no star
const STAR_OFF_HAND := 1.5  # of its size, up the haft: clear of the chibi's hood
const STROKE_BY_STEP := [0.6, 1.1]  # of the haft's length, keeping up with the growth; then no stroke
const CHIP_HEAD_START := 0.04  # s of flight on the first frame, so they don't start in a pile
const STROKE_WIDTH := 0.1  # m at the hand, tapering to a point
const SPEED_LINES := 4
const INK_CHIPS := 7
const INK_CHIP_SIZE := 0.1
const INK_CHIP_SPEED := 4.5

## low, high: the two flat tones. star: m. chip: [count, size, length over width, sides, speed].
const LOOKS := {
	"axe": {"low": Color(0.16, 0.85, 0.38), "high": Color(0.86, 1.0, 0.72), "star": 0.42, "chip": [6, 0.1, 2.6, 4, 5.0]},
	"spear": {"low": Color(0.26, 0.62, 0.96), "high": Color(0.98, 1.0, 1.0), "star": 0.36, "chip": [6, 0.07, 3.6, 4, 6.0]},
	"hammer": {"low": Color(1.0, 0.28, 0.02), "high": Color(1.0, 0.86, 0.2), "star": 0.5, "chip": [7, 0.13, 1.1, 5, 4.0]},
	"hand": {"low": Color(0.44, 0.07, 0.4), "high": Color(0.68, 0.15, 0.58), "star": 0.26, "chip": [5, 0.09, 1.4, 6, 3.5]},
}

static var _mat: StandardMaterial3D

var _look: Dictionary
var _dir := Vector3.ZERO  # along the haft (zero when going back to the hand)
var _len := 0.0
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _chips := []  # {pos, vel, size, stretch, shape, ink}
var _lines := []  # [how far along the haft, offset across it, length]
var _t := 0.0
var _step := -1
var _reduced := false
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()


## The shared look, so the first change has nothing new to compile mid-swing.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # draws after the world, in triangle order
		_mat.no_depth_test = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.disable_fog = true
	return _mat


## `dir` is the haft's direction in the world; zero for a change back to the bare limb.
static func spawn(parent: Node, at: Vector3, form: String, dir: Vector3, length: float) -> Node3D:
	var fx: Node3D = SELF.new()
	parent.add_child(fx)
	fx.global_position = at
	fx.setup(form, dir, length)
	return fx


func setup(form: String, dir: Vector3, length: float) -> void:
	add_to_group("heretic_form_fx")
	_look = LOOKS[form]
	_dir = dir
	_len = length
	_reduced = Game.reduce_flashing
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
	var view := MeshInstance3D.new()
	view.mesh = _mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_meta("no_ghost", true)
	view.extra_cull_margin = 8.0
	add_child(view)
	_throw_chips()
	for c: Dictionary in _chips:
		c.pos += c.vel * CHIP_HEAD_START
	if _dir != Vector3.ZERO:
		for i in SPEED_LINES:
			var side := -1.0 if i % 2 == 0 else 1.0
			_lines.append([randf_range(0.1, 0.5), side * randf_range(0.14, 0.34), randf_range(0.3, 0.55)])
	tick(0.0)


func _throw_chips() -> void:
	for i in INK_CHIPS:
		var a := randf() * TAU
		_chips.append({"pos": Vector3.ZERO, "vel": (_right * cos(a) + _up * sin(a)) * INK_CHIP_SPEED * randf_range(0.6, 1.2),
			"size": INK_CHIP_SIZE * randf_range(0.6, 1.3), "stretch": 1.3, "shape": _shape(6), "ink": true})
	var c: Array = _look.chip
	for i in c[0]:
		var a := randf() * TAU
		var out := _right * cos(a) + _up * sin(a)
		var start := Vector3.ZERO
		if _dir != Vector3.ZERO:  # thrown off the haft, leaning the way it grew
			start = _dir * _len * randf_range(0.25, 0.9)
			out = (out + _dir * 0.7).normalized()
		_chips.append({"pos": start, "vel": out * c[4] * randf_range(0.6, 1.2),
			"size": c[1] * randf_range(0.7, 1.3), "stretch": c[2], "shape": _shape(c[3]), "ink": false})


## An uneven outline, kept for the chip's life.
func _shape(sides: int) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	for i in sides:
		radii.append(randf_range(0.75, 1.15))
	return radii


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	var step := int(_t * STEPS_PER_S)
	if step >= STEPS:
		queue_free()
		return
	if step == _step:
		return
	for k in step - maxi(_step, 0):
		for c: Dictionary in _chips:
			c.pos += c.vel / STEPS_PER_S
			c.vel += Vector3.DOWN * GRAVITY / STEPS_PER_S
	_step = step
	_draw_step(step)


func _draw_step(step: int) -> void:
	_verts.clear()
	_colors.clear()
	var shrink := 1.0 - float(step) / STEPS
	# The chips go underneath, so the star cuts cleanly across them.
	for c: Dictionary in _chips:
		_chip(c, shrink)
	if step < STROKE_BY_STEP.size() and _dir != Vector3.ZERO:
		_stroke_step(STROKE_BY_STEP[step])
	if step < STAR_SIZE_BY_STEP.size():
		_star(_look.star * STAR_SIZE_BY_STEP[step], step)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, material())


func _star(size: float, step: int) -> void:
	var breaking := step == STAR_SIZE_BY_STEP.size() - 1  # the last one: colour only, no line or core
	var spikes := PackedFloat32Array()  # the same for every layer of this step
	for i in STAR_SPIKES:
		spikes.append(randf_range(0.72, 1.25))
	var turn := randf() * TAU
	var centre: Vector3 = _dir * _look.star * STAR_OFF_HAND
	if not breaking:
		_star_layer(centre, size * 1.2, spikes, turn, INK)
	_star_layer(centre, size, spikes, turn, _look.low)
	if not breaking and not _reduced:
		_star_layer(centre, size * 0.5, spikes, turn, _look.high)


func _star_layer(centre: Vector3, size: float, spikes: PackedFloat32Array, turn: float, color: Color) -> void:
	var ring := PackedVector3Array()
	var along := (_right * _dir.dot(_right) + _up * _dir.dot(_up))
	for i in STAR_SPIKES * 2:
		var a := turn + TAU * i / (STAR_SPIKES * 2)
		var r: float = size * spikes[i / 2] if i % 2 == 0 else size * 0.42
		var p := (_right * cos(a) + _up * sin(a)) * r
		ring.append(p + along * p.dot(along) * STAR_STRETCH)
	_fan(centre, ring, color)


## The new haft arriving: ink, then colour, then a hot core, each thinner and shorter.
func _stroke_step(reach: float) -> void:
	var length := _len * reach
	var across := _across()
	_stroke(Vector3.ZERO, length * 1.03, STROKE_WIDTH * 1.5, across, INK)
	_stroke(Vector3.ZERO, length, STROKE_WIDTH, across, _look.low)
	_stroke(Vector3.ZERO, length * 0.8, STROKE_WIDTH * 0.45, across, _look.high)
	for l: Array in _lines:
		var start: Vector3 = _dir * length * l[0] + across * l[1]
		_stroke(start, length * l[2], STROKE_WIDTH * 0.32, across, _look.high)


## Sideways on screen, square to the haft.
func _across() -> Vector3:
	var a := _dir.cross(_right.cross(_up))
	return a.normalized() if a.length() > 0.01 else _right


func _stroke(start: Vector3, length: float, width: float, across: Vector3, color: Color) -> void:
	_tri(start + across * width * 0.5, start - across * width * 0.5, start + _dir * length, color)


func _chip(c: Dictionary, shrink: float) -> void:
	var size: float = c.size * shrink
	var along: Vector3 = c.vel
	var x := (_right * along.dot(_right) + _up * along.dot(_up)).normalized()
	var y := Vector3(x).cross(_right.cross(_up)).normalized()
	var ring := PackedVector3Array()
	var sides: PackedFloat32Array = c.shape
	for i in sides.size():
		var a := TAU * i / sides.size()
		ring.append(x * cos(a) * size * c.stretch * sides[i] + y * sin(a) * size * sides[i])
	if c.ink:
		_fan(c.pos, ring, INK)
		return
	var hull := PackedVector3Array()
	for v in ring:
		hull.append(v * 1.45)
	_fan(c.pos, hull, INK)
	_fan(c.pos, ring, _look.low)


func _fan(centre: Vector3, ring: PackedVector3Array, color: Color) -> void:
	for i in ring.size():
		_tri(centre, centre + ring[i], centre + ring[(i + 1) % ring.size()], color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
