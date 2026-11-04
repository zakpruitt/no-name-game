extends Node3D
## Molten Palm's fist with the comic style (void_element._fist hands off here): a flat inked fist
## facing the camera, the limb's magenta with molten orange knuckles, fat speed strokes behind it,
## stretched as it flies and squashed wide with an impact star when it arrives. Replaces the lumpy
## shaded balls. Drawn on twos with heretic_form_fx's shared material; moves like the old one, so
## the tentacle (void_grab._tick_palm) still follows it out.

const SELF := preload("res://scripts/comic_fist.gd")  # (held: a load() at fire time recompiled it once freed)
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const INK := Color(0.012, 0.01, 0.02)
const LOW := Color(0.5, 0.08, 0.45)  # the limb's magenta (heretic_form_fx "hand", a touch brighter)
const HIGH := Color(0.78, 0.24, 0.66)
const MOLTEN := Color(1.0, 0.42, 0.04)
const MOLTEN_CORE := Color(1.0, 0.86, 0.22)
const STEPS_PER_S := 12.0
const R := 0.85  # m, the fist's half height on screen
const HOLD_AFTER := 0.08  # s it holds where it lands, then shrinks away
const SHRINK := 0.12

var _time := 0.2  # s out
var _t := 0.0
var _step := -1
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _d := Vector3.RIGHT  # its flight on the screen plane
var _s := Vector3.UP  # across it
var _rng := RandomNumberGenerator.new()
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()


## The same flight as void_element._fist: from 1 m ahead of `at` out `length` m along `fwd` in `time` s.
static func spawn(parent: Node, at: Vector3, fwd: Vector3, length: float, time: float) -> Node3D:
	var fist: Node3D = SELF.new()
	parent.add_child(fist)
	fist.setup(at, fwd, length, time)
	return fist


func setup(at: Vector3, fwd: Vector3, length: float, time: float) -> void:
	add_to_group("comic_fist")
	_time = time
	_rng.randomize()
	global_position = at + fwd * 1.0 + Vector3.UP * 1.0
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
	var d := _right * fwd.dot(_right) + _up * fwd.dot(_up)
	_d = d.normalized() if d.length() > 0.05 else _right
	_s = _d.cross(_right.cross(_up)).normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 4.0
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(self, "global_position", at + fwd * length + Vector3.UP * 1.0, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tick(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	if _t >= _time + HOLD_AFTER + SHRINK:
		queue_free()
		return
	var step := int(_t * STEPS_PER_S)
	if step == _step:
		return
	_step = step
	_draw_step()


func _draw_step() -> void:
	_verts.clear()
	_colors.clear()
	var landed := _t >= _time
	var size := R
	var along := 1.0
	var across := 1.0
	if _t < _time * 0.3:
		size *= 0.75
		along = 1.35  # stretched as it shoots out
		across = 0.8
	elif landed:
		along = 0.8  # squashed against what it hit
		across = 1.2
		if _t >= _time + HOLD_AFTER:
			size *= 0.5
	if not landed:
		for i in 3:
			var off := (float(i) - 1.0) * size * 0.55
			_wedge(-_d * size * 0.7 + _s * off, -_d, size * _rng.randf_range(1.3, 1.9), size * 0.32, INK)
			_wedge(-_d * size * 0.75 + _s * off, -_d, size * _rng.randf_range(1.0, 1.4), size * 0.16, MOLTEN)
	elif _t < _time + HOLD_AFTER:
		_star(_d * size * 0.9, size * 1.15, INK)
		_star(_d * size * 0.9, size * 0.95, MOLTEN)
		_star(_d * size * 0.9, size * 0.45, MOLTEN_CORE)
	# The fist from above: wider than it is long, four fat knuckles making its front edge, a thumb
	# tucked along one side, ink grooves between the fingers and the knuckles glowing molten.
	var la := size * along * 0.8  # half length, along the flight
	var lb := size * across * 1.1  # half width
	var knuckles := []
	for i in 4:
		var k := (float(i) - 1.5) / 1.5
		knuckles.append(_d * la * (0.72 - 0.12 * k * k) + _s * lb * k * 0.72)
	var thumb := -_s * lb * 0.95 - _d * la * 0.05
	var kr := lb * 0.32
	_blob(Vector3.ZERO, la + 0.08, lb + 0.08, INK)
	_blob(thumb, la * 0.55 + 0.07, kr * 0.9 + 0.07, INK)
	for at: Vector3 in knuckles:
		_blob(at, kr + 0.07, kr + 0.07, INK)
	_blob(Vector3.ZERO, la, lb, LOW)
	_blob(thumb, la * 0.55, kr * 0.9, LOW)
	for at: Vector3 in knuckles:
		_blob(at, kr, kr, LOW)
	_blob(-_d * la * 0.15 + _s * lb * 0.15, la * 0.45, lb * 0.55, HIGH)
	for i in 3:
		var mid: Vector3 = (knuckles[i] + knuckles[i + 1]) * 0.5
		_tri(mid + _d * kr * 0.6 + _s * 0.035, mid + _d * kr * 0.6 - _s * 0.035, mid - _d * la * 0.55, INK)
	for at: Vector3 in knuckles:
		_blob(at + _d * kr * 0.25, kr * 0.62, kr * 0.62, MOLTEN)
		_blob(at + _d * kr * 0.35, kr * 0.28, kr * 0.28, MOLTEN_CORE)
	_mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


## A squarish ellipse, `a` along the flight and `b` across.
func _blob(c: Vector3, a: float, b: float, color: Color) -> void:
	var n := 14
	var ring := PackedVector3Array()
	for i in n:
		var t := TAU * i / n
		var x := signf(cos(t)) * pow(absf(cos(t)), 0.6)
		var y := signf(sin(t)) * pow(absf(sin(t)), 0.6)
		ring.append(c + _d * x * a + _s * y * b)
	for i in n:
		_tri(c, ring[i], ring[(i + 1) % n], color)


func _star(c: Vector3, size: float, color: Color) -> void:
	var ring := PackedVector3Array()
	var turn := _rng.randf() * TAU
	for i in 18:
		var a := turn + TAU * i / 18.0
		var r := size * (_rng.randf_range(0.8, 1.2) if i % 2 == 0 else 0.42)
		ring.append(c + (_right * cos(a) + _up * sin(a)) * r)
	for i in ring.size():
		_tri(c, ring[i], ring[(i + 1) % ring.size()], color)


func _wedge(p: Vector3, d: Vector3, length: float, w: float, color: Color) -> void:
	_tri(p + _s * w * 0.5, p - _s * w * 0.5, p + d * length, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color, color, color])
