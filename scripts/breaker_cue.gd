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
const INK_FX := preload("res://scripts/designed_ink.gd")
## Round 44 (fx-cohesion): designed, the rings are hand-drawn brush strips (gen_cohesion.py stamp_cue) round the
## same radii in the same colours: the target a ring of inked brush dashes, the closing ring one fat brush line.
const DESIGNED_TARGET_W := 0.26  # m: the band the dashes are drawn in
const DESIGNED_CLOSING_W := 0.3  # (round 45: 0.4 read as a second thick hoop)
const INK := Color(0.012, 0.01, 0.02)
const PAPER := Color(1.0, 0.96, 0.85)
const LOCKED := Color(0.42, 0.42, 0.46)
## Crisp: flat bands on the floor with ink either side, the same width whatever the radius.
## Round 33 (sleek, at the 34% wider camera): 0.07 m bands in a 0.03 m ink line (fx_palette.LINE) still read
## as two rings closing on each other; 0.12 / 0.15 m in 0.055 m ink were the fattest shapes on a breaker's
## frames. (Before that: 0.16 / 0.24 / 0.07 was a fat green hoop over every Live Wire frame.)
const CRISP_TARGET_W := 0.06  # m (0.12)
const CRISP_CLOSING_W := 0.075  # m (0.15)
const CRISP_INK := 0.03  # m each side (0.055)
const CRISP_SEGS := 56

var color := Color(0.3, 0.95, 0.85)
var open := 0.2
var sweet := 0.38
var close := 0.54
## A breaker with two endings (hero_leap.options()): the closing ring alternates `color` (right click's ending) and
## this (left click's) in DASHES pieces until he picks; then hero_leap sets `color` to the one picked and clears it,
## so the snap-out (hit()) is in the ending that's coming. Both endings land on this spot.
var alt_color := Color.TRANSPARENT
const DASHES := 8
var crisp := false  # thin hard rings: the tentacle's breakers land right on this spot

var _t := 0.0
var _target: MeshInstance3D
var _closing: MeshInstance3D
var _over := false
var _flat: MeshInstance3D  # crisp: both rings, rebuilt each frame
var _flat_mesh := ArrayMesh.new()
var _locked := false
var _designed := false
var _closing_mi: MeshInstance3D  # designed: the closing ring (_flat is the target)
var _closing_mesh := ArrayMesh.new()
var _alpha := 1.0


func _ready() -> void:
	crisp = crisp or Game.comic_style  # hard inked rings on every comic hero
	if crisp:
		_flat = MeshInstance3D.new()
		_flat.mesh = _flat_mesh
		_flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flat.extra_cull_margin = START + 1.0
		_flat.position.y = 0.12
		add_child(_flat)
		_designed = INK_FX.DESIGNED.on()
		if _designed:
			INK_FX.cue_on(self)
			_closing_mi = MeshInstance3D.new()
			_closing_mi.mesh = _closing_mesh
			_closing_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_closing_mi.extra_cull_margin = START + 1.0
			_closing_mi.position.y = 0.12
			add_child(_closing_mi)
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
		if _designed:
			_draw_designed(r)
			return
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
	var closing_c2 := alt_color if alt_color.a > 0.0 and not _locked else closing_c
	for ring: Array in [[TARGET, CRISP_TARGET_W, target_c, target_c], [r, CRISP_CLOSING_W, closing_c, closing_c2]]:
		var rad: float = ring[0]
		var w: float = ring[1]
		_band(verts, cols, rad - w * 0.5 - CRISP_INK, rad + w * 0.5 + CRISP_INK, INK, INK)
		_band(verts, cols, rad - w * 0.5, rad + w * 0.5, ring[2], ring[3])
	_flat_mesh.clear_surfaces()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	_flat_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_flat_mesh.surface_set_material(0, FORM_FX.material())


## The designed look: the same two rings and colours, drawn as brush strips (the dashes boil on twos).
func _draw_designed(r: float) -> void:
	var in_window := _t >= open and _t <= close
	var target_c := LOCKED if _locked else (GOLD if in_window else PAPER)
	var closing_c := LOCKED if _locked else color
	var alt := alt_color.a > 0.0 and not _locked
	var boil := int(_t * 12.0) % 2
	var mat := INK_FX.stamp_material("cue")
	INK_FX.annulus(_flat_mesh, TARGET, DESIGNED_TARGET_W, 64, mat)
	_flat.set_instance_shader_parameter("tiles", INK_FX.tiles_for(TARGET, DESIGNED_TARGET_W))
	_flat.set_instance_shader_parameter("frame", float(boil))
	_flat.set_instance_shader_parameter("tint", Color(target_c, 1.0))
	_flat.set_instance_shader_parameter("alpha", _alpha)
	INK_FX.annulus(_closing_mesh, r, DESIGNED_CLOSING_W, clampi(int(r * 16.0), 32, 96), mat)
	_closing_mi.set_instance_shader_parameter("tiles", float(DASHES) if alt else INK_FX.tiles_for(r, DESIGNED_CLOSING_W))
	_closing_mi.set_instance_shader_parameter("frame", 2.0 + boil)
	_closing_mi.set_instance_shader_parameter("tint", Color(closing_c, 1.0))
	_closing_mi.set_instance_shader_parameter("tint2", Color(alt_color, 1.0) if alt else Color(0, 0, 0, 0))
	_closing_mi.set_instance_shader_parameter("alpha", _alpha)


func _set_alpha(a: float) -> void:
	_alpha = a
	for m: MeshInstance3D in [_flat, _closing_mi]:
		m.set_instance_shader_parameter("alpha", a)


static func _band(verts: PackedVector3Array, cols: PackedColorArray, r0: float, r1: float, c: Color, c2: Color) -> void:
	r0 = maxf(r0, 0.0)
	for i in CRISP_SEGS:
		var ci: Color = c2 if (i * DASHES / CRISP_SEGS) % 2 == 1 else c
		var a := Vector3(sin(TAU * i / CRISP_SEGS), 0.0, cos(TAU * i / CRISP_SEGS))
		var b := Vector3(sin(TAU * (i + 1) / CRISP_SEGS), 0.0, cos(TAU * (i + 1) / CRISP_SEGS))
		verts.append_array([a * r0, a * r1, b * r1, a * r0, b * r1, b * r0])
		for k in 6:
			cols.append(ci)


## True until he presses (or it locks): designed ground stamps hold off meanwhile, so the closing ring is the only
## ring on the floor.
func closing() -> bool:
	return not _over


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
	if _designed:  # (round 45: the closing ring goes at once, so the snap is the one ring the press leaves)
		_closing_mi.visible = false
	if crisp:  # the target ring snaps out as an inked hoop
		Fx.COMIC_POP.spawn(get_parent(), global_position, {"ring": TARGET * 1.5, "ring_color": GOLD if perfect else color, "steps": 3})
	else:
		Fx.ring(get_parent(), global_position, Color(GOLD if perfect else color, 0.95), TARGET * 1.6, 0.25)
	_fade(0.1)


func _fade(time: float) -> void:
	if _designed:
		var tw2 := create_tween()
		tw2.tween_method(_set_alpha, 1.0, 0.0, time)
		tw2.tween_callback(queue_free)
		return
	var tw := create_tween().set_parallel()
	for m in ([_flat] if crisp else [_target, _closing]):
		tw.tween_property(m, "transparency", 1.0, time)
	tw.chain().tween_callback(queue_free)
