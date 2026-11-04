extends Node
## Tendrils out of the floor that have hold of foes for a while: Undertow drags them waist-deep, Overwhelm
## piles on, Black Tide has none and is only the floor. Small foes are pinned where they stand, big ones are only slowed, and everyone takes
## damage as it goes. See docs/features/void-element.md.

const TENDRIL := preload("res://scripts/void_tendril.gd")
const THROWN := preload("res://scripts/thrown_foe.gd")
const RITE := preload("res://scripts/element_rite.gd")
const VOID_GRAB_HOLD := 0.9  # s a pinned foe is staggered for, renewed
const RESTAGGER := 0.25  # s (see void_grab.RESTAGGER)
const SINK_RATE := 5.0  # m/s they go down
const ROPE_OUT := 0.12  # s for the tendrils to arrive
const ROPE_SPREAD := 1.1  # m out from the foe's edge they come up
const BIG_SLOW := 0.4  # what big foes' speed drops to

var hero: CharacterBody3D
var time := 1.5
var sink := 0.0  # m the model goes down
var tick_damage := 3.0
var step := 0.25  # s between ticks
var ropes := 2
var wells := false  # lava under each, once it's stopped moving
var color := Color(1.0, 0.4, 0.1)
var _t := 0.0
var _next_tick := 0.0
var _next_stagger := 0.0
var _depth := 0.0
var _held := []  # {foe, at, big, welled, ropes: [{tendril, from}]}


## Takes hold of `foes`. `opts` set the vars above. Abyss raises `sink` while it's running.
static func bind(by: CharacterBody3D, foes: Array, opts := {}) -> Node:
	var b := new()
	b.hero = by
	for k: String in opts:
		b.set(k, opts[k])
	by.get_parent().add_child(b)
	b._next_tick = b.step
	for e: Node3D in foes:
		b._take(e)
	return b


func _take(e: Node3D) -> void:
	var big: bool = float(e.get("radius")) >= 0.9 or e.has_method("is_boss") or e.get("elite") == true
	var rows := []
	var r := float(e.get("radius")) + ROPE_SPREAD
	var count: int = ropes + (2 if big and ropes > 0 else 0)
	for i in count:
		var a := TAU * i / float(count) + randf() * 0.5
		var t := TENDRIL.new()
		add_child(t)
		rows.append({"tendril": t, "from": Vector3(e.global_position.x + cos(a) * r, 0.0, e.global_position.z + sin(a) * r)})
	_held.append({"foe": e, "at": e.global_position, "big": big, "welled": false, "ropes": rows})
	if big:
		if e.has_method("chill"):
			e.chill(time, BIG_SLOW)
	elif e.has_method("stagger"):
		e.stagger(VOID_GRAB_HOLD)


func _physics_process(delta: float) -> void:
	_t += delta
	_depth = move_toward(_depth, sink, SINK_RATE * delta)
	var stagger_now := _t >= _next_stagger
	if stagger_now:
		_next_stagger = _t + RESTAGGER
	var tick_now := _t >= _next_tick
	if tick_now:
		_next_tick += step
	for s: Dictionary in _held:
		var e: Variant = s.foe
		if not is_instance_valid(e) or not e.is_alive():
			for rope: Dictionary in s.ropes:
				rope.tendril.visible = false
			continue
		var flying: bool = e.has_meta(THROWN.FLYING)
		if flying:  # still on its way from Molten Palm: it takes hold where it lands
			var moved: Vector3 = e.global_position - s.at
			moved.y = 0.0
			for rope: Dictionary in s.ropes:
				rope.from += moved
			s.at = e.global_position
		elif wells and not s.welled:
			s.welled = true
			RITE.well(hero.get_parent(), e.global_position)
		if not s.big and not flying:
			e.global_position = Vector3(s.at.x, e.global_position.y, s.at.z)
			e.velocity = Vector3.ZERO
			if stagger_now and e.has_method("stagger"):
				e.stagger(VOID_GRAB_HOLD)
			var body: Variant = e.get("model")
			if sink > 0.0 and body != null:
				body.position.y = -_depth
		var coil := float(e.get("radius")) + 0.05
		var first := true
		for rope: Dictionary in s.ropes:
			rope.tendril.draw(rope.from, e.global_position + Vector3.UP * (0.3 if sink > 0.0 else 0.9), smoothstep(0.0, ROPE_OUT, _t), 0.08, coil if first else 0.0, _t)
			first = false
		if tick_now:
			if e.has_method("burn_hit"):
				e.burn_hit(tick_damage)
			else:
				e.take_hit(tick_damage, Vector3.ZERO, 0.0, false)
			Game.register_hit("cast")
			hero._cast_hit(e)
			Fx.burst(hero.get_parent(), e.global_position + Vector3.UP * 0.4, color, 5, 5.0, 0.1, 0.25, Vector3.UP, 50.0)
	if _t >= time:
		_let_go()


func _let_go() -> void:
	for s: Dictionary in _held:
		var e: Variant = s.foe
		if is_instance_valid(e) and sink > 0.0:
			var body: Variant = e.get("model")
			if body != null:
				body.position.y = 0.0
	queue_free()
