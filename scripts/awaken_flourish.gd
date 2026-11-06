extends Node3D
## Feel audit 2, item 1: the Awakening flourish (comic style; Fx.awaken_burst). The bot, and a player, Awaken the
## frame the meter fills, which is usually on a perfect breaker landing, so the old 12 m gold beam, an 11 m flare, a
## 7 m hoop and two motes bursts were the biggest shape in every breaker frame for ~0.5 s, over the pile, the total
## and the hero (every fx_coverage frame over 0.2). Now it is one thin inked column (the ghost halftone look, gold)
## and a thin gold hoop, and it waits: while he is in a breaker (State.LEAP) and until AFTER_BREAKER_S real s after
## a landing, so the landing reads first. Only the look moves: hero_awaken.gd still turns the buff on, freezes and
## blows the foes back the frame he Awakens.
##   const AWAKEN_FLOURISH := preload("res://scripts/awaken_flourish.gd")
##   AWAKEN_FLOURISH.spawn(parent, pos)   # ComicFx calls AWAKEN_FLOURISH.note(hero) every frame

const PAL := preload("res://scripts/fx_palette.gd")
const SPIRIT_ECHO := preload("res://scripts/spirit_echo.gd")
const DESIGNED := preload("res://scripts/designed_fx.gd")
const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")

const AFTER_BREAKER_S := 0.4  # real s after a breaker landing before the flourish shows
const WAIT_MAX_S := 1.6  # it never waits longer than this (a breaker that never lands)
const HIGH := 5.0  # m: the column (the beam was 12)
const RADIUS := 0.24  # m at its foot, 1.3x at the top (the beam's sleek shell was 0.63)
const POP_S := 0.06  # real s it snaps open
const HOLD_S := 0.1
const FADE_S := 0.2  # whole life POP_S + HOLD_S + FADE_S = 0.36 s (the beam: 0.33 s at 12 m, plus 0.45 s of hoop)
const HOOP_R := 2.6  # m: one thin gold hoop at his feet (the 7 m blast hoop is gone: the foes flying out show it)
const HOOP_S := 0.3

static var _landed_seen := 0  # the hero's breakers_landed when last read
static var _landed_ms := -100000  # real ms of the last breaker landing seen
static var held := 0  # flourishes that waited for a landing (fx_sleek_check)
static var drawn := 0  # flourishes drawn

var _at := Vector3.ZERO
var _born_ms := 0
var _done := false


## Reads the hero's breaker count (ComicFx, every frame; spawn, once): a rise is a landing now.
static func note(hero: Node) -> void:
	if hero == null or not "breakers_landed" in hero:
		return
	var n: int = hero.breakers_landed
	if n < _landed_seen:  # (a new training room)
		_landed_seen = n
	elif n > _landed_seen:
		_landed_seen = n
		_landed_ms = Time.get_ticks_msec()


static func spawn(parent: Node, pos: Vector3) -> Node3D:
	var f: Node3D = load("res://scripts/awaken_flourish.gd").new()
	f._at = pos
	parent.add_child(f)
	return f


## Hold the flourish now? In a breaker, or within AFTER_BREAKER_S of a landing.
static func must_wait(hero: Node, now: int) -> bool:
	if hero != null and "state" in hero and hero.state == hero.State.LEAP:
		return true
	return now - _landed_ms < AFTER_BREAKER_S * 1000.0


func _hero() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null


func _ready() -> void:
	_born_ms = Time.get_ticks_msec()
	var hero := _hero()
	note(hero)
	if must_wait(hero, _born_ms):
		held += 1
	else:
		_show()


func _process(_delta: float) -> void:
	if _done:
		return
	var hero := _hero()
	note(hero)
	var now := Time.get_ticks_msec()
	if not must_wait(hero, now) or now - _born_ms > WAIT_MAX_S * 1000.0:
		_show()


func _show() -> void:
	_done = true
	drawn += 1
	var hero := _hero()
	if hero != null and "awakened" in hero and not hero.awakened:
		queue_free()  # (it ran out while waiting)
		return
	var at: Vector3 = hero.global_position if hero != null else _at  # where he is now, not where he pressed
	global_position = Vector3(at.x, 0.0, at.z)
	if DESIGNED.on():  # round 46: the authored event (designed_finish.awaken: lines pulled in, a crown of gold flame)
		DESIGNED_FINISH.awaken(get_parent(), hero, global_position)
		queue_free()
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS * 1.3
	cyl.bottom_radius = RADIUS
	cyl.height = HIGH
	cyl.radial_segments = 12
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var gold: Color = PAL.of("gold").body
	var col := SPIRIT_ECHO.ghost(cyl, gold)
	col.set_instance_shader_parameter("fade_height", HIGH * 0.85)
	SPIRIT_ECHO.set_alpha(1.0, col)
	col.position.y = HIGH * 0.5
	add_child(col)
	scale = Vector3(0.3, 0.6, 0.3)
	var tw := create_tween().set_ignore_time_scale(true)  # (his own Awakening freeze must not hold it)
	tw.tween_property(self, "scale", Vector3.ONE, POP_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(HOLD_S)
	tw.tween_method(SPIRIT_ECHO.set_alpha.bind(col), 1.0, 0.0, FADE_S)
	tw.tween_callback(queue_free)
	Fx.thin_hoop(get_parent(), global_position, "gold", HOOP_R, HOOP_S)
