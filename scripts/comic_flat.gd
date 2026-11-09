extends Node3D
## The shared base of the crossover effect nodes (comic_backdraft draws with it; comic_fault,
## comic_melt, comic_freeze_over, comic_impale, comic_state_tell use its timing and following to drive designed
## pieces). One camera-facing surface rebuilt on twos (heretic_form_fx's shared material: no depth test, alpha, so
## it sits over the pile). Sleek rules from fx_palette: thin LINE ink round a shape, gradient fills, one hot core,
## peak on the first frame, gone in well under a second.
## A subclass sets `life`, fills `_build()` (once) and `_draw(step)` (each step), and uses the helpers below.
## Anything it follows (a foe, a flight) is kept untyped and checked with is_instance_valid each step: a foe can be
## freed mid-effect (tests/fx_free_check.gd).

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const STANDING := preload("res://scripts/standing_fx.gd")
const STEPS_PER_S := 12.0  # on twos, at 24 fps
const INK := Color(0.012, 0.01, 0.02)

var life := 0.5  # s
## Real time instead of game time: for effects in a breaker's slow-motion hang, which would stretch them.
var real_time := false
var _t := 0.0
var _step := -1
var _last_us := 0
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _view := Vector3.BACK
var _rng := RandomNumberGenerator.new()
var _screen_mesh := ArrayMesh.new()
var _sv := PackedVector3Array()
var _sc := PackedColorArray()


## Adds it to `parent` at `at` (world), reads the camera and builds it. Call from a subclass's spawn().
func begin(parent: Node, at: Vector3) -> void:
	parent.add_child(self)
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, at)
	_rng.randomize()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_right = cam.global_basis.x
		_up = cam.global_basis.y
		_view = cam.global_basis.z
	var mi := MeshInstance3D.new()
	mi.mesh = _screen_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 12.0
	mi.set_meta("no_ghost", true)
	add_child(mi)
	_last_us = Time.get_ticks_usec()
	STANDING.add(self)
	_build()
	tick(0.0)


## The next string's first hit landed (standing_fx.gd): gone now, so nothing of the last string sits under it.
func clear_standing() -> void:
	life = minf(life, _t + STANDING.CLEAR_S)


func _build() -> void:
	pass


func _draw(_s: int) -> void:
	pass


func _process(delta: float) -> void:
	if real_time:
		var now := Time.get_ticks_usec()
		delta = minf((now - _last_us) / 1000000.0, 0.1)
		_last_us = now
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	_follow(delta)
	var step := int(_t * STEPS_PER_S)
	if step == _step:
		return
	_step = step
	_sv.clear()
	_sc.clear()
	_draw(step)
	_commit(_screen_mesh, _sv, _sc, FORM_FX.material())


## Every frame (not on twos): an effect that rides something moves with it here.
func _follow(_delta: float) -> void:
	pass


func _commit(mesh: ArrayMesh, v: PackedVector3Array, c: PackedColorArray, mat: Material) -> void:
	mesh.clear_surfaces()
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)


# --- Screen layer (local to the node, camera-facing) ---------------------------------------------------------

func _screen(a: float) -> Vector3:
	return _right * cos(a) + _up * sin(a)


## Filled polygon: `color` at the centre to `edge` at the ring (flat if `edge` is unset).
func _fan(centre: Vector3, ring: PackedVector3Array, color: Color, edge := Color(0, 0, 0, -1)) -> void:
	var e := color if edge.a < 0.0 else edge
	for i in ring.size():
		_tri3(centre, centre + ring[i], centre + ring[(i + 1) % ring.size()], color, e, e)


## A `w` m line just outside the ring.
func _outline(centre: Vector3, ring: PackedVector3Array, w: float, color: Color) -> void:
	var n := ring.size()
	for i in n:
		var p := ring[i]
		var q := ring[(i + 1) % n]
		var po := p + (p.normalized() if p.length() > 0.001 else _up) * w
		var qo := q + (q.normalized() if q.length() > 0.001 else _up) * w
		_tri(centre + p, centre + po, centre + qo, color)
		_tri(centre + p, centre + qo, centre + q, color)


## A camera-facing strip along `pts` (local), `w0` wide at the start to `w1` at the end.
func _strip(pts: PackedVector3Array, w0: float, w1: float, color: Color, tail := Color(0, 0, 0, -1)) -> void:
	var n := pts.size()
	var t := color if tail.a < 0.0 else tail
	for i in n - 1:
		var d := pts[i + 1] - pts[i]
		var side := d.cross(_view).normalized()
		var ka := float(i) / (n - 1)
		var kb := float(i + 1) / (n - 1)
		var wa := lerpf(w0, w1, ka) * 0.5
		var wb := lerpf(w0, w1, kb) * 0.5
		var ca := color.lerp(t, ka)
		var cb := color.lerp(t, kb)
		_tri3(pts[i] + side * wa, pts[i] - side * wa, pts[i + 1] + side * wb, ca, ca, cb)
		_tri3(pts[i + 1] + side * wb, pts[i] - side * wa, pts[i + 1] - side * wb, cb, ca, cb)


## A speed line: clear at the back, `color` at its widest, a point ahead.
func _wedge(p: Vector3, d: Vector3, length: float, w: float, color: Color) -> void:
	var side := d.cross(_view).normalized()
	var back := PAL.fade(color, 0.0)
	var mid := p + d * length * 0.6
	_tri3(p + side * w * 0.1, p - side * w * 0.1, mid + side * w * 0.5, back, back, color)
	_tri3(mid + side * w * 0.5, p - side * w * 0.1, mid - side * w * 0.5, color, back, color)
	_tri(mid + side * w * 0.5, mid - side * w * 0.5, p + d * length, color)


func _tri3(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_sv.append_array([a, b, c])
	_sc.append_array([ca, cb, cc])


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_tri3(a, b, c, color, color, color)



## A jagged path from `a` to `b` (local x / z), about `seg` m a segment, kinked `jag` of a segment sideways.
func _jagged(a: Vector2, b: Vector2, seg: float, jag: float) -> PackedVector2Array:
	var d := b - a
	var n := maxi(2, int(d.length() / seg))
	var side := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array([a])
	for i in range(1, n):
		var k := float(i) / n
		pts.append(a + d * k + side * _rng.randf_range(-jag, jag) * d.length() / n)
	pts.append(b)
	return pts
