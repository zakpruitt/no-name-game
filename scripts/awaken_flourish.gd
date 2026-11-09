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

const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")

const AFTER_BREAKER_S := 0.4  # real s after a breaker landing before the flourish shows
const WAIT_MAX_S := 1.6  # it never waits longer than this (a breaker that never lands)

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
	DESIGNED_FINISH.awaken(get_parent(), hero, global_position)  # (lines pulled in, a crown of gold flame)
	queue_free()
