extends Node3D
## A breaker dive with the comic style (air_gust.comet): a fat inked comet streak along the path he
## came down, element colour round a hot core, pointed at the tail; when the beats stop he has landed,
## and a held-frame impact star slams down at his feet. Replaces the soft spark puffs and the pale
## afterimages, which piled into a big soft disc under the foes at the game camera.
## Flat, camera-facing, heretic_form_fx's shared material, a public tick(delta).

const SELF := preload("res://scripts/comic_comet.gd")  # (held: a load() at fire time recompiled it once freed)
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const COMIC_POP := preload("res://scripts/comic_pop.gd")
const DESIGNED_EL := preload("res://scripts/designed_elements.gd")
const ELEMENTS := preload("res://scripts/elements.gd")
const ICE_TRAIL_W := 1.1  # m: the designed ice comet's strip height (its head crystal ~1 m across)
const INK := Color(0.012, 0.01, 0.02)
const HOT_CORE := Color(1.0, 0.88, 0.25)
const STEPS_PER_S := 12.0  # the wobble changes on twos; the head follows him every frame
const LANDED_AFTER := 0.06  # s without a beat: he's down
const TAIL := 3.6  # m of streak behind him at most
const MIN_TAIL := 2.8
const WIDTH := 0.6  # m of the colour band at the head (round 33, sleek: was 0.85 in an ink hull 1.6x); core scales from it, the ink is a thin line
const HEAD_BACK := 0.4  # m behind him the head starts, so the streak doesn't paint over him
const STAR := 1.05  # m, the landing star
const STAR_HOLD := 3  # steps the landing frame holds

var color := Color(0.3, 0.95, 0.85)
var _model: Node3D
var _pts := PackedVector3Array()
var _since := 0.0
var _t := 0.0
var _step := -1
var _wob := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _view := Vector3.BACK
var _mesh := ArrayMesh.new()
var _verts := PackedVector3Array()
var _colors := PackedColorArray()
var _ice: MeshInstance3D  # designed (round 46): an ice dive drawn as the authored crystal trail, not the polygon streak


## The comet on `model`, made on the first beat and fed by the rest.
static func beat(parent: Node, model: Node3D, c: Color) -> void:
	var comet: Node3D = model.get_meta("comic_comet") if model.has_meta("comic_comet") else null
	if not is_instance_valid(comet):
		comet = SELF.new()
		comet.color = c
		parent.add_child(comet)
		comet.setup(model)
		model.set_meta("comic_comet", comet)
	comet.feed()


func setup(model: Node3D) -> void:
	add_to_group("comic_comet")
	top_level = true
	global_transform = Transform3D.IDENTITY
	_model = model
	_rng.randomize()
	var cam := get_viewport().get_camera_3d()
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
	if DESIGNED_EL.DESIGNED.on() and color.is_equal_approx(ELEMENTS.LOOK.water.color):
		DESIGNED_EL.register()
		_ice = mi
		mi.material_override = DESIGNED_EL.DESIGNED.material("ice_trail")
		mi.set_instance_shader_parameter("pal_row", DESIGNED_EL.DESIGNED.row("water"))
		mi.set_instance_shader_parameter("erode", 0.0)


func feed() -> void:
	_since = 0.0
	if is_instance_valid(_model):
		var p := _model.global_position + Vector3.UP * 0.9
		if _pts.is_empty() or _pts[_pts.size() - 1].distance_to(p) > 0.05:
			_pts.append(p)


func _process(delta: float) -> void:
	tick(delta)


## Public so a test can step it exactly.
func tick(delta: float) -> void:
	_t += delta
	_since += delta
	if _since > LANDED_AFTER or not is_instance_valid(_model):
		_land()
		return
	var step := int(_t * STEPS_PER_S)
	if step != _step:
		_step = step
		_wob.clear()
		for i in 16:
			_wob.append(_rng.randf_range(0.8, 1.2))
	_draw()


func _land() -> void:
	if not _pts.is_empty():
		var at := _pts[_pts.size() - 1]
		var down := Vector3(at.x, 0.35, at.z)
		var dir := Vector3.DOWN
		if _pts.size() > 1:
			dir = (at - _pts[0]).normalized()
		COMIC_POP.spawn(get_parent(), down, {"star": STAR, "spikes": 8, "hold": STAR_HOLD, "steps": 3,
			"strokes": 7, "radial": true, "gap": STAR * 0.85, "stroke_len": 0.7, "stroke_w": 0.22,
			"stroke_color": color.lightened(0.3), "chips": 6, "chip": color, "chip_size": 0.15,
			"chip_speed": 6.0, "chip_ink": 4, "dir": -dir})
	if is_instance_valid(_model) and _model.get_meta("comic_comet", null) == self:
		_model.remove_meta("comic_comet")
	queue_free()


## A straight streak back along the way he came, never shorter than MIN_TAIL (a tentacle breaker's
## hero barely moves), starting HEAD_BACK short of him.
func _path() -> PackedVector3Array:
	var head := _model.global_position + Vector3.UP * 0.9
	var from := _pts[0] if not _pts.is_empty() else head + Vector3.UP
	var back := from - head
	var run := back.length()
	back = back / run if run > 0.05 else Vector3.UP
	var length := clampf(run + 0.8, MIN_TAIL, TAIL)
	var out := PackedVector3Array()
	var n := maxi(int(length / 0.4), 3)
	for i in n + 1:
		out.append(head + back * (HEAD_BACK + length * float(i) / n))
	return out


func _draw() -> void:
	_verts.clear()
	_colors.clear()
	var pts := _path()
	_mesh.clear_surfaces()
	if pts.size() < 2:
		return
	if _ice != null:
		_draw_ice(pts)
		return
	_ribbon(pts, WIDTH + 0.07, INK)
	_ribbon(pts, WIDTH, Color(color, 0.88))
	if not Game.reduce_flashing:
		_ribbon(pts, WIDTH * 0.3, HOT_CORE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.surface_set_material(0, FORM_FX.material())


## Fat and round at the head, tapering to a point at the tail, wobbling on twos.
func _ribbon(pts: PackedVector3Array, w: float, c: Color) -> void:
	var n := pts.size()
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		var across := (b - a).cross(_view)
		across = across.normalized() if across.length() > 0.001 else _right
		var k := 1.0 - float(i) / (n - 1)
		var half := w * 0.5 * pow(k, 0.7) * (_wob[i % _wob.size()] if i > 0 else 1.0)
		left.append(pts[i] + across * half)
		right.append(pts[i] - across * half)
	for i in n - 1:
		_tri(left[i], right[i], left[i + 1], c)
		_tri(left[i + 1], right[i], right[i + 1], c)
	# A round head, so the streak reads as a comet and not a stick.
	var dir := (pts[0] - pts[1]).normalized()
	var across := dir.cross(_view).normalized()
	var r := w * 0.5
	for i in 8:
		var a0 := PI * i / 8.0 - PI * 0.5
		var a1 := PI * (i + 1) / 8.0 - PI * 0.5
		_tri(pts[0], pts[0] + (dir * cos(a0) + across * sin(a0)) * r, pts[0] + (dir * cos(a1) + across * sin(a1)) * r, c)


## The designed ice comet: the crystal trail strip laid along the path (head crystal at him, chips off the tail),
## its frames boiling on twos.
func _draw_ice(pts: PackedVector3Array) -> void:
	var n := pts.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		var across := (b - a).cross(_view)
		across = across.normalized() if across.length() > 0.001 else _right
		var u := 1.0 - float(i) / (n - 1)  # (the strip's head is u = 1, at pts[0])
		verts.append_array([pts[i] + across * ICE_TRAIL_W * 0.5, pts[i] - across * ICE_TRAIL_W * 0.5])
		uvs.append_array([Vector2(u, 1.0), Vector2(u, 0.0)])
	var idx := PackedInt32Array()
	for i in n - 1:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ice.set_instance_shader_parameter("frame", float(_step % 4))


func _tri(a: Vector3, b: Vector3, c: Vector3, color_: Color) -> void:
	_verts.append_array([a, b, c])
	_colors.append_array([color_, color_, color_])
