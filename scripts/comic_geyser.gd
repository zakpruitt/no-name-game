extends Node3D
## A comic lava geyser: a flat camera-facing column punching up out of the floor in three bands (ink,
## lava orange, hot yellow core), a hard splash star at its foot and fat inked blobs of lava thrown off
## the top. Redrawn on twos: it peaks tall on the first frame with an overshoot, settles, breaks into
## blobs and is gone in about a third of a second. Replaces the soft glowing swirl cone and its rain of
## dots, which piled into a fire soup over the foes (elements.geyser, was element_rite.geyser). Uses heretic_form_fx's
## shared material, so there's nothing new to compile.

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const STEPS_PER_S := 12.0  # on twos
const HEIGHT_BY_STEP := [1.15, 1.0, 0.7, 0.3]  # overshoot, settle, sink, a stub; then gone
const INK := Color(0.012, 0.01, 0.02)
const LAVA := Color(1.0, 0.3, 0.03)
const HOT := Color(1.0, 0.82, 0.22)
const GRAVITY := 16.0
const BLOBS := 6
const WOBBLE := 0.12  # of the width, side to side down the column on each step
const ROWS := 6

var height := 3.2  # m
var width := 1.1  # m across at the top
var _t := 0.0
var _step := -1
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _rng := RandomNumberGenerator.new()
var _blobs := []  # {pos, vel, size}
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()


static func spawn(parent: Node, spot: Vector3, h: float, w: float) -> Node3D:
	var g: Node3D = load("res://scripts/comic_geyser.gd").new()
	g.height = h
	g.width = w
	parent.add_child(g)
	g.global_position = Vector3(spot.x, 0.0, spot.z)
	g.setup()
	return g


func setup() -> void:
	add_to_group("comic_geyser")
	_rng.randomize()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 8.0
	add_child(mi)
	for i in BLOBS:
		var side := _rng.randf_range(-1.0, 1.0)
		_blobs.append({"pos": Vector3.UP * height * 0.9 + _right * side * width * 0.3,
			"vel": _right * side * _rng.randf_range(2.0, 4.0) + Vector3.UP * _rng.randf_range(3.0, 6.0),
			"size": width * _rng.randf_range(0.16, 0.26)})
	tick(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	var step := int(_t * STEPS_PER_S)
	if step >= HEIGHT_BY_STEP.size():
		queue_free()
		return
	if step == _step:
		return
	for k in step - maxi(_step, 0):
		for b: Dictionary in _blobs:
			b.pos += b.vel / STEPS_PER_S
			b.vel += Vector3.DOWN * GRAVITY / STEPS_PER_S
	_step = step
	_draw_step(step)


func _draw_step(step: int) -> void:
	_verts.clear()
	_colors.clear()
	var h: float = height * HEIGHT_BY_STEP[step]
	var last := step == HEIGHT_BY_STEP.size() - 1
	var wob := PackedFloat32Array()
	for i in ROWS + 1:
		wob.append(_rng.randf_range(-1.0, 1.0) * WOBBLE * width)
	var splash := width * (0.9 if step == 0 else 0.65)
	if not last:
		_star(Vector3.UP * 0.1, splash * 1.2, INK, 9)
		_column(h * 1.04, width * 1.3, wob, INK)
	_star(Vector3.UP * 0.1, splash, LAVA, 9)
	_column(h, width, wob, LAVA)
	if not last:
		_column(h * 0.85, width * 0.45, wob, HOT)
	if step >= 1:  # blobs once it starts to break
		for b: Dictionary in _blobs:
			if b.pos.y > 0.0:
				_blob(b.pos, b.size * 1.35, INK)
				_blob(b.pos, b.size, LAVA if last else HOT)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


## Narrow at the floor, widest near the top, a ragged crown of three licks.
func _column(h: float, w: float, wob: PackedFloat32Array, color: Color) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in ROWS + 1:
		var k := float(i) / ROWS
		var half := w * 0.5 * lerpf(0.45, 1.0, sqrt(k))
		var mid := Vector3.UP * h * k + _right * wob[i] * k
		var l := mid - _right * half
		var r := mid + _right * half
		if i > 0:
			_tri(prev_l, prev_r, r, color)
			_tri(prev_l, r, l, color)
		prev_l = l
		prev_r = r
	var top := Vector3.UP * h + _right * wob[ROWS]
	for j in 3:  # licks off the crown
		var x := lerpf(-0.5, 0.5, j / 2.0) * w
		var tall := h * (0.22 if j == 1 else 0.13)
		_tri(top + _right * (x - w * 0.2), top + _right * (x + w * 0.2), top + _right * x * 1.2 + Vector3.UP * tall, color)


func _star(at: Vector3, size: float, color: Color, spikes: int) -> void:
	var ring := PackedVector3Array()
	for i in spikes * 2:
		var a := TAU * i / (spikes * 2)
		var r := size * (_rng.randf_range(0.8, 1.2) if i % 2 == 0 else 0.45)
		ring.append(at + (_right * cos(a) + _up * sin(a) * 0.55) * r)  # squashed: it lies on the floor
	for i in ring.size():
		_tri(at, ring[i], ring[(i + 1) % ring.size()], color)


func _blob(at: Vector3, r: float, color: Color) -> void:
	var ring := PackedVector3Array()
	for i in 10:
		var a := TAU * i / 10.0
		ring.append(at + (_right * cos(a) + _up * sin(a)) * r)
	for i in ring.size():
		_tri(at, ring[i], ring[(i + 1) % ring.size()], color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
