extends Node3D
## The shared drawer for the crossover effects (round 37: comic_boulder, comic_fault, comic_steam, comic_freeze_over,
## comic_arc). Two surfaces rebuilt on twos: `screen` (camera-facing, heretic_form_fx's shared material:
## no depth test, alpha, so it sits over the pile) and `floor` (flat on the floor, comic_crack's shared depth-tested
## material, so foes stand on it). Nothing new to compile. Sleek rules from fx_palette: thin LINE ink round a shape,
## gradient fills, one hot core, peak on the first frame, gone in well under a second.
## A subclass sets `life`, fills `_build()` (once) and `_draw(step)` (each step), and uses the helpers below.
## Anything it follows (a foe, a flight) is kept untyped and checked with is_instance_valid each step: a foe can be
## freed mid-effect (tests/fx_free_check.gd).

const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const CRACK := preload("res://scripts/comic_crack.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const STANDING := preload("res://scripts/standing_fx.gd")
const STEPS_PER_S := 12.0  # on twos, at 24 fps
const INK := Color(0.012, 0.01, 0.02)
const HOT := Color(1.0, 0.45, 0.05)  # impact stars, whatever the element (comic_pop)
const HOT_CORE := Color(1.0, 0.88, 0.25)
const FLOOR_Y := 0.07  # m over the floor (the stones' tallest is 0.05; comic_crack sits at 0.06)

var life := 0.5  # s
## Real time instead of game time: for effects in a breaker's slow-motion hang, which would stretch them.
var real_time := false
var lift := 0.0  # m: the floor layer's extra lift (over another floor effect, e.g. a dark pool)
var _t := 0.0
var _step := -1
var _last_us := 0
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _view := Vector3.BACK
var _rng := RandomNumberGenerator.new()
var _screen_mesh := ArrayMesh.new()
var _floor_mesh := ArrayMesh.new()
var _sv := PackedVector3Array()
var _sc := PackedColorArray()
var _fv := PackedVector3Array()
var _fc := PackedColorArray()
var _fy := 0.0  # floor layer lift: each layer a hair over the last


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
	for m: ArrayMesh in [_screen_mesh, _floor_mesh]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
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
	_fv.clear()
	_fc.clear()
	_fy = 0.0
	_draw(step)
	_commit(_screen_mesh, _sv, _sc, FORM_FX.material())
	_commit(_floor_mesh, _fv, _fc, CRACK.material())


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


## A world direction as an angle on the screen plane.
func _angle(v: Vector3) -> float:
	return atan2(v.dot(_up), v.dot(_right))


## A ring of `radii` round the screen plane, starting at angle `turn`, each stretched by `squash` along `axis`.
func _ring(radii: PackedFloat32Array, size: float, turn := 0.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in radii.size():
		out.append(_screen(turn + TAU * i / radii.size()) * size * radii[i])
	return out


## A star's ring: spikes at `radii`, valleys at `inner` of the size.
func _star_ring(radii: PackedFloat32Array, size: float, inner: float, turn := 0.0) -> PackedVector3Array:
	var n := radii.size()
	var out := PackedVector3Array()
	for i in n * 2:
		var r: float = size * radii[i / 2] if i % 2 == 0 else size * inner
		out.append(_screen(turn + TAU * i / (n * 2)) * r)
	return out


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


# --- Floor layer (local x / z, on the floor whatever the node's height) ----------------------------------------

## Next floor layer: lifted a hair over the last so they don't z-fight.
func _layer() -> void:
	_fy += 0.006


func _f(p: Vector2) -> Vector3:
	return Vector3(p.x, FLOOR_Y + lift + _fy - global_position.y, p.y)


## A tapered floor strip along `pts` (local x / z): `w0` m wide at the start to `w1` at the end, `color` to `tail`.
func _floor_strip(pts: PackedVector2Array, w0: float, w1: float, color: Color, tail := Color(0, 0, 0, -1)) -> void:
	var n := pts.size()
	var t := color if tail.a < 0.0 else tail
	for i in n - 1:
		var d := (pts[i + 1] - pts[i]).normalized()
		var sa := Vector2(-d.y, d.x)
		var sb := sa
		if i + 2 < n:  # mitre into the next segment, so a bend has no gap
			var d2 := (pts[i + 2] - pts[i + 1]).normalized()
			sb = (Vector2(-d.y, d.x) + Vector2(-d2.y, d2.x)).normalized()
		if i > 0:
			var d0 := (pts[i] - pts[i - 1]).normalized()
			sa = (Vector2(-d0.y, d0.x) + Vector2(-d.y, d.x)).normalized()
		var ka := float(i) / (n - 1)
		var kb := float(i + 1) / (n - 1)
		var wa := lerpf(w0, w1, ka) * 0.5
		var wb := lerpf(w0, w1, kb) * 0.5
		var ca := color.lerp(t, ka)
		var cb := color.lerp(t, kb)
		_ftri3(_f(pts[i] + sa * wa), _f(pts[i] - sa * wa), _f(pts[i + 1] + sb * wb), ca, ca, cb)
		_ftri3(_f(pts[i + 1] + sb * wb), _f(pts[i] - sa * wa), _f(pts[i + 1] - sb * wb), cb, ca, cb)


## A filled floor polygon round `centre` (local x / z): `color` in the middle to `edge` at the ring.
func _floor_fan(centre: Vector2, ring: PackedVector2Array, color: Color, edge := Color(0, 0, 0, -1)) -> void:
	var e := color if edge.a < 0.0 else edge
	for i in ring.size():
		_ftri3(_f(centre), _f(centre + ring[i]), _f(centre + ring[(i + 1) % ring.size()]), color, e, e)


## (comic_crack's material reads vertex colours as linear: convert, or the palette washes out pale on the floor)
func _ftri3(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_fv.append_array([a, b, c])
	_fc.append_array([ca.srgb_to_linear(), cb.srgb_to_linear(), cc.srgb_to_linear()])


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
