extends Node3D
## Combo breaker timing cue (void_element.gd BREAKERS): a fixed target ring on the
## floor where the dive will land and a closing ring shrinking onto it. The
## rings meet at `sweet` s after spawning, the press window is `open`..`close`
## (the target ring lights up gold through it). lock() = pressed too early
## (greys out), hit(perfect) = the dive is coming (flash), else it fades at close.
## Both rings are hand-drawn brush strips (gen_cohesion.py stamp_cue, designed_ink's stamp material): the target a
## thin solid brush line (paper, gold in the window), the closing ring long broken cream dashes with a third of
## them in the ending's colour (two endings alternate). The cue is quieter than the action.

const TARGET := 1.6  # m radius of the target ring
const START := 4.6  # m radius the closing ring starts at
const GOLD := Color(1.0, 0.82, 0.3)
const INK_FX := preload("res://scripts/designed_ink.gd")
const DESIGNED_TARGET_W := 0.17
const DESIGNED_CLOSING_W := 0.2
const DESIGNED_CLOSING_TILES := 6.0  # three long dashes a tile, whatever the radius
const DESIGNED_ACCENT := 3.0  # every third tile in the ending's colour
const CREAM := Color(0.93, 0.88, 0.76)
const PAPER := Color(1.0, 0.96, 0.85)
const LOCKED := Color(0.42, 0.42, 0.46)

var color := Color(0.3, 0.95, 0.85)
var open := 0.2
var sweet := 0.38
var close := 0.54
## A breaker with two endings (hero_leap.options()): the closing ring alternates `color` (right click's ending) and
## this (left click's) tile by tile until he picks; then hero_leap sets `color` to the one picked and clears it,
## so the snap-out (hit()) is in the ending that's coming. Both endings land on this spot.
var alt_color := Color.TRANSPARENT

var _t := 0.0
var _over := false
var _flat: MeshInstance3D  # the target ring
var _flat_mesh := ArrayMesh.new()
var _locked := false
var _closing_mi: MeshInstance3D  # the closing ring
var _closing_mesh := ArrayMesh.new()
var _alpha := 1.0


func _ready() -> void:
	_flat = MeshInstance3D.new()
	_flat.mesh = _flat_mesh
	_flat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flat.extra_cull_margin = START + 1.0
	_flat.position.y = 0.12
	add_child(_flat)
	INK_FX.cue_on(self)
	_closing_mi = MeshInstance3D.new()
	_closing_mi.mesh = _closing_mesh
	_closing_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_closing_mi.extra_cull_margin = START + 1.0
	_closing_mi.position.y = 0.12
	add_child(_closing_mi)
	_update()


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
	_draw_designed(r)


## The two rings and their colours as brush strips (the dashes boil on twos).
func _draw_designed(r: float) -> void:
	var in_window := _t >= open and _t <= close
	var target_c := LOCKED if _locked else (GOLD if in_window else PAPER)
	var closing_c := LOCKED if _locked else color
	var alt := alt_color.a > 0.0 and not _locked
	var boil := int(_t * 12.0) % 2
	var mat := INK_FX.stamp_material("cue")
	INK_FX.annulus(_flat_mesh, TARGET, DESIGNED_TARGET_W, 64, mat)
	_flat.set_instance_shader_parameter("tiles", INK_FX.tiles_for(TARGET, DESIGNED_TARGET_W))
	_flat.set_instance_shader_parameter("frame", 2.0 + boil)
	_flat.set_instance_shader_parameter("tint", Color(target_c, 1.0))
	_flat.set_instance_shader_parameter("alpha", _alpha)
	INK_FX.annulus(_closing_mesh, r, DESIGNED_CLOSING_W, clampi(int(r * 16.0), 32, 96), mat)
	_closing_mi.set_instance_shader_parameter("tiles", DESIGNED_CLOSING_TILES)
	_closing_mi.set_instance_shader_parameter("frame", float(boil))
	if _locked:
		_closing_mi.set_instance_shader_parameter("tint", Color(LOCKED, 1.0))
		_closing_mi.set_instance_shader_parameter("tint2", Color(0, 0, 0, 0))
	elif alt:  # two endings: their colours alternate tile by tile
		_closing_mi.set_instance_shader_parameter("tint", Color(closing_c, 1.0))
		_closing_mi.set_instance_shader_parameter("tint2", Color(alt_color, 1.0))
		_closing_mi.set_instance_shader_parameter("accent_every", 0.0)
	else:
		_closing_mi.set_instance_shader_parameter("tint", Color(CREAM, 1.0))
		_closing_mi.set_instance_shader_parameter("tint2", Color(closing_c, 1.0))
		_closing_mi.set_instance_shader_parameter("accent_every", DESIGNED_ACCENT)
	_closing_mi.set_instance_shader_parameter("alpha", _alpha)


func _set_alpha(a: float) -> void:
	_alpha = a
	for m: MeshInstance3D in [_flat, _closing_mi]:
		m.set_instance_shader_parameter("alpha", a)


## True until he presses (or it locks): designed ground stamps hold off meanwhile, so the closing ring is the only
## ring on the floor.
func closing() -> bool:
	return not _over


## Pressed too early: no breaker this time.
func lock() -> void:
	if _over:
		return
	_over = true
	_locked = true
	_update()
	_fade(0.25)


## Pressed in the window: the closing ring goes at once and the target ring snaps out as an inked hoop, the one
## ring the press leaves.
func hit(perfect: bool) -> void:
	if _over:
		return
	_over = true
	_closing_mi.visible = false
	Fx.COMIC_POP.spawn(get_parent(), global_position, {"ring": TARGET * 1.5, "ring_color": GOLD if perfect else color, "steps": 3})
	_fade(0.1)


func _fade(time: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_alpha, 1.0, 0.0, time)
	tw.tween_callback(queue_free)
