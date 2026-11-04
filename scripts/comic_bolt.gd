extends Node3D
## A comic lightning bolt from `a` to `b`: a flat camera-facing zigzag in three bands (ink, storm green,
## pale core), with a fork or two, redrawn on twos with a new zigzag each time and gone in a quarter of a
## second. With `star` it lands in a hard yellow-orange impact star. Replaces the soft glowing tubes
## (element_rite.arc) and the green funnel (elements.storm_strike), which read as a smudge at the game
## camera. Uses heretic_form_fx's shared material, so there's nothing new to compile.

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const STEPS_PER_S := 12.0  # on twos
const WIDTH_BY_STEP := [1.0, 0.85, 0.5]  # full, a new zigzag, then colour only, then gone
const INK := Color(0.012, 0.01, 0.02)
const STORM := Color(0.16, 0.85, 0.38)
const LIGHT := Color(0.9, 1.0, 0.78)
const HOT := Color(1.0, 0.45, 0.05)
const HOT_CORE := Color(1.0, 0.88, 0.25)
const SEG := 0.75  # m per zigzag segment
const JAG := 0.32  # of a segment, sideways
const STAR_SPIKES := 8

var width := 0.24  # m of the colour band; the ink is wider, the core narrower
var star := 0.0  # m: the impact star's size at `b`, 0 for none
var forks := 1
var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _t := 0.0
var _step := -1
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _view := Vector3.BACK  # towards the camera
var _rng := RandomNumberGenerator.new()
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()


static func spawn(parent: Node, a: Vector3, b: Vector3, w := 0.24, star_size := 0.0, fork_count := 1) -> Node3D:
	var bolt: Node3D = load("res://scripts/comic_bolt.gd").new()
	bolt.width = w
	bolt.star = star_size
	bolt.forks = fork_count
	parent.add_child(bolt)
	bolt.setup(a, b)
	return bolt


func setup(a: Vector3, b: Vector3) -> void:
	add_to_group("comic_bolt")
	top_level = true
	global_transform = Transform3D.IDENTITY
	_a = a
	_b = b
	_rng.randomize()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
		_view = cam.global_basis.z
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 16.0
	add_child(mi)
	tick(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	var step := int(_t * STEPS_PER_S)
	if step >= WIDTH_BY_STEP.size():
		queue_free()
		return
	if step == _step:
		return
	_step = step
	_draw_step(step)


func _draw_step(step: int) -> void:
	_verts.clear()
	_colors.clear()
	var k: float = WIDTH_BY_STEP[step]
	var last := step == WIDTH_BY_STEP.size() - 1
	var main := _zigzag(_a, _b)
	var branches := []
	for i in forks:
		var from: Vector3 = main[_rng.randi_range(1, maxi(1, main.size() - 2))]
		var out := (_b - _a).length() * _rng.randf_range(0.18, 0.32)
		var side := _right * (1.0 if _rng.randf() < 0.5 else -1.0)
		branches.append(_zigzag(from, from + ((_b - _a).normalized() * 0.6 + side * 0.8).normalized() * out))
	# Ink under everything, then the colour, then the core, so the bands nest cleanly.
	if not last:
		_ribbon(main, width * 2.1 * k, INK)
		for f: PackedVector3Array in branches:
			_ribbon(f, width * 1.4 * k, INK)
		if star > 0.0:
			_star(_b, star * 1.25 * k, INK)
	_ribbon(main, width * k, STORM)
	for f: PackedVector3Array in branches:
		_ribbon(f, width * 0.6 * k, STORM)
	if star > 0.0:
		_star(_b, star * k, HOT)
	if not last and not Game.reduce_flashing:
		_ribbon(main, width * 0.38 * k, LIGHT)
		if star > 0.0:
			_star(_b, star * 0.5 * k, HOT_CORE)
	_mesh.clear_surfaces()
	if _verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


## Kinks sideways on screen, a new set every step.
func _zigzag(a: Vector3, b: Vector3) -> PackedVector3Array:
	var span := b - a
	var n := clampi(int(span.length() / SEG), 2, 14)
	var side := span.cross(_view)
	side = side.normalized() if side.length() > 0.01 else _right
	var pts := PackedVector3Array([a])
	var flip := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in range(1, n):
		flip = -flip
		pts.append(a + span * (float(i) / n) + side * flip * span.length() / n * JAG * _rng.randf_range(0.5, 1.4))
	pts.append(b)
	return pts


## A strip of quads across the screen, pointed at both ends.
func _ribbon(pts: PackedVector3Array, w: float, color: Color) -> void:
	var n := pts.size()
	for i in n - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var across := (q - p).cross(_view)
		across = across.normalized() if across.length() > 0.001 else _right
		var wp := w * (0.35 if i == 0 else 1.0) * 0.5
		var wq := w * (0.2 if i == n - 2 else 1.0) * 0.5
		# A little past each joint, so the kinks have no gaps.
		var ext := (q - p).normalized() * w * 0.25
		var p0 := p - ext
		var q0 := q + ext
		_tri(p0 + across * wp, p0 - across * wp, q0 + across * wq, color)
		_tri(q0 + across * wq, p0 - across * wp, q0 - across * wq, color)


func _star(at: Vector3, size: float, color: Color) -> void:
	var ring := PackedVector3Array()
	var turn := _rng.randf() * TAU
	for i in STAR_SPIKES * 2:
		var a := turn + TAU * i / (STAR_SPIKES * 2)
		var r := size * (_rng.randf_range(0.8, 1.2) if i % 2 == 0 else 0.4)
		ring.append(at + (_right * cos(a) + _up * sin(a)) * r)
	for i in ring.size():
		_tri(at, ring[i], ring[(i + 1) % ring.size()], color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
