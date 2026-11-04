extends Node3D
## Combo breaker timing cue (void_element.gd BREAKERS): a fixed target ring on the
## floor where the dive will land and a closing ring shrinking onto it. The
## rings meet at `sweet` s after spawning, the press window is `open`..`close`
## (the target ring lights up gold through it). lock() = pressed too early
## (greys out), hit(perfect) = the dive is coming (flash), else it fades at close.

const TARGET := 1.6  # m radius of the target ring
const START := 4.6  # m radius the closing ring starts at
const GOLD := Color(1.0, 0.82, 0.3)
const FORM_FX := preload("res://scripts/heretic_form_fx.gd")
const INK := Color(0.012, 0.01, 0.02)
const PAPER := Color(1.0, 0.96, 0.85)
const LOCKED := Color(0.42, 0.42, 0.46)
## Crisp: flat bands on the floor with ink either side, the same width whatever the radius.
const CRISP_TARGET_W := 0.16  # m
const CRISP_CLOSING_W := 0.24
const CRISP_INK := 0.07
const CRISP_SEGS := 56

var color := Color(0.3, 0.95, 0.85)
var open := 0.2
var sweet := 0.38
var close := 0.54
var crisp := false  # thin hard rings: the tentacle's breakers land right on this spot

var _t := 0.0
var _target: MeshInstance3D
var _closing: MeshInstance3D
var _over := false
var _flat: MeshInstance3D  # crisp: both rings, rebuilt each frame
var _flat_mesh := ArrayMesh.new()
var _locked := false


func _ready() -> void:
	crisp = crisp or Game.comic_style  # hard inked rings on every comic hero
	if crisp:
		_flat = MeshInstance3D.new()
		_flat.mesh = _flat_mesh
		_flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flat.extra_cull_margin = START + 1.0
		_flat.position.y = 0.12
		add_child(_flat)
		_update()
		return
	_target = _ring(Color(1, 1, 1, 0.55))
	_target.scale = Vector3(TARGET, 1.0, TARGET)
	_closing = _ring(Color(color, 0.95))
	_update()


func _ring(c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if crisp:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.92
		hoop.outer_radius = 1.0
		hoop.rings = 48
		hoop.ring_segments = 4
		mesh = hoop
	else:
		var quad := PlaneMesh.new()
		quad.size = Vector2.ONE * 2.2  # Fx.ring: the texture's ring sits ~1 m out
		mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true  # reads over the spikes and enemies
	if not crisp:
		mat.albedo_texture = Fx.TEX.ring
	mat.albedo_color = c
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = 0.12
	add_child(m)
	return m


func _process(delta: float) -> void:
	if _over:
		return
	_t += delta
	_update()
	if _t >= close:
		_over = true
		_fade(0.15)


func _update() -> void:
	# Linear from START to TARGET at `sweet`, on past it toward the centre.
	var r := lerpf(START, TARGET, _t / sweet) if _t < sweet else lerpf(TARGET, TARGET * 0.4, (_t - sweet) / maxf(close - sweet, 0.01))
	if crisp:
		_draw_flat(r)
		return
	_closing.scale = Vector3(r, 1.0, r)
	var in_window := _t >= open and _t <= close
	var tm: StandardMaterial3D = _target.mesh.material
	tm.albedo_color = Color(GOLD, 0.75 + 0.25 * sin(_t * 40.0)) if in_window else Color(1, 1, 1, 0.55)


## The crisp look: a paper target ring that turns gold through the window and a fat closing ring in
## the breaker's colour, each between two ink bands, flat on the floor.
func _draw_flat(r: float) -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var in_window := _t >= open and _t <= close
	var target_c := LOCKED if _locked else (GOLD if in_window else PAPER)
	var closing_c := LOCKED if _locked else color
	for ring: Array in [[TARGET, CRISP_TARGET_W, target_c], [r, CRISP_CLOSING_W, closing_c]]:
		var rad: float = ring[0]
		var w: float = ring[1]
		_band(verts, cols, rad - w * 0.5 - CRISP_INK, rad + w * 0.5 + CRISP_INK, INK)
		_band(verts, cols, rad - w * 0.5, rad + w * 0.5, ring[2])
	_flat_mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	_flat_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_flat_mesh.surface_set_material(0, FORM_FX.material())


static func _band(verts: PackedVector3Array, cols: PackedColorArray, r0: float, r1: float, c: Color) -> void:
	r0 = maxf(r0, 0.0)
	for i in CRISP_SEGS:
		var a := Vector3(sin(TAU * i / CRISP_SEGS), 0.0, cos(TAU * i / CRISP_SEGS))
		var b := Vector3(sin(TAU * (i + 1) / CRISP_SEGS), 0.0, cos(TAU * (i + 1) / CRISP_SEGS))
		verts.append_array([a * r0, a * r1, b * r1, a * r0, b * r1, b * r0])
		for k in 6:
			cols.append(c)


## Pressed too early: no breaker this time.
func lock() -> void:
	if _over:
		return
	_over = true
	if crisp:
		_locked = true
		_update()
		_fade(0.25)
		return
	for m in [_target, _closing]:
		(m.mesh.material as StandardMaterial3D).albedo_color = Color(0.35, 0.35, 0.38, 0.7)
	_fade(0.25)


## Pressed in the window: flash and go.
func hit(perfect: bool) -> void:
	if _over:
		return
	_over = true
	if crisp:  # the target ring snaps out as an inked hoop
		Fx.COMIC_POP.spawn(get_parent(), global_position, {"ring": TARGET * 1.5, "ring_color": GOLD if perfect else color, "steps": 3})
	else:
		Fx.ring(get_parent(), global_position, Color(GOLD if perfect else color, 0.95), TARGET * 1.6, 0.25)
	_fade(0.1)


func _fade(time: float) -> void:
	var tw := create_tween().set_parallel()
	for m in ([_flat] if crisp else [_target, _closing]):
		tw.tween_property(m, "transparency", 1.0, time)
	tw.chain().tween_callback(queue_free)
