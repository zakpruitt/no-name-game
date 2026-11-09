extends Node3D
## A breaker dive's comet (hero_leap, mid_beats.trail, collapse_spit): a drawn strip on a camera-facing ribbon
## along the path he came down (designed_polish.trail_sheet: a brush comet, the dark's ink smear, storm's lime
## bolt), its rows boiling on twos; when the beats stop he has landed, and the element's pop slams down at his
## feet (designed_polish.dive_land). A public tick(delta).

const SELF := preload("res://scripts/comic_comet.gd")  # (held: a load() at fire time recompiled it once freed)
const POLISH := preload("res://scripts/designed_polish.gd")
const PAL := preload("res://scripts/fx_palette.gd")
const D_WIDTH := 0.9  # m: the ribbon (the comet's head fills ~0.85 of it)
const D_BOLT_WIDTH := 1.1
const D_BOLT_TILE := 2.6  # the bolt strip's length on the ribbon, in widths
const STEPS_PER_S := 12.0  # the strip's rows step on twos; the head follows him every frame
const LANDED_AFTER := 0.06  # s without a beat: he's down
const TAIL := 3.6  # m of streak behind him at most
const MIN_TAIL := 2.8
const HEAD_BACK := 0.4  # m behind him the head starts, so the streak doesn't paint over him

var color := Color(0.3, 0.95, 0.85)
var _model: Node3D
var _pts := PackedVector3Array()
var _since := 0.0
var _t := 0.0
var _step := -1
var _right := Vector3.RIGHT
var _view := Vector3.BACK
var _mesh := ArrayMesh.new()
var _el := "spirit"
var _sheet := ""
var _dmi: MeshInstance3D


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
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_right = cam.global_basis.x
		_view = cam.global_basis.z
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	POLISH.register()
	_el = PAL.nearest(color)
	_sheet = POLISH.trail_sheet(_el)
	mi.material_override = POLISH.DESIGNED.material(_sheet)
	mi.set_instance_shader_parameter("pal_row", POLISH.DESIGNED.row(_el))
	mi.set_instance_shader_parameter("head", 1.0)
	mi.set_instance_shader_parameter("span", 1.0)
	mi.set_instance_shader_parameter("erode", 0.0)
	mi.set_instance_shader_parameter("heat", 0.15 if _sheet == "bolt_strip" else 0.0)
	_dmi = mi
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ghost", true)
	mi.extra_cull_margin = 16.0
	add_child(mi)


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
	_step = int(_t * STEPS_PER_S)
	_draw()


func _land() -> void:
	if not _pts.is_empty():
		var at := _pts[_pts.size() - 1]
		POLISH.dive_land(get_parent(), Vector3(at.x, 0.35, at.z), color, _el)
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
	var pts := _path()
	_mesh.clear_surfaces()
	if pts.size() < 2:
		return
	var bolt := _sheet == "bolt_strip"
	var w := D_BOLT_WIDTH if bolt else D_WIDTH
	POLISH.trail_mesh(_mesh, pts, w, _view, _right)
	_dmi.set_instance_shader_parameter("frame", float(_step % 4))
	if bolt:
		var run := pts[0].distance_to(pts[pts.size() - 1])
		_dmi.set_instance_shader_parameter("tiles", maxf(1.0, run / (w * D_BOLT_TILE)))
		_dmi.set_instance_shader_parameter("scroll", _step * 0.21)
	else:
		_dmi.set_instance_shader_parameter("tiles", 0.0)
