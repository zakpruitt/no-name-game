extends Node3D
## The tentacles' after-beat (round 52 cool pass, combo-cool2; docs/features/combo-breakers.md "Round 52 cool pass"):
## after a breaker lands, a tentacle out of `root` takes each foe, hauls it up and drives it to where it ends, in three
## parts per foe: up (UP s to `top`), hold (HOLD s, a small bob), down (DOWN s to `end`, eased in: a slam), then
## on_end(foe, i). Maw knocks the bitten together over the pool and slams the heap into it, Anvil yanks the buried kebab
## back up and drives it in again, Cold Front's tethers hold each cube up before it is thrown.
## Game time (hit stops hold it). Headless it draws nothing but moves them.
##   var g := TENTACLE_HAUL.start(hero, [{"foe": e, "root": spot, "top": up_there, "end": floor, "t0": 0.0}, ...])
##   g.on_up = func(e, i): ...;  g.on_end = func(e, i): ...
## Each entry may set its own "up" / "hold" / "down" (s) and "keep" (true: left where it ends, still flying, for a
## throw to take it; on_end runs first).

const SELF := preload("res://scripts/tentacle_haul.gd")
const TENDRIL := preload("res://scripts/void_tendril.gd")

const UP := 0.12
const HOLD := 0.06
const DOWN := 0.07
const CHEST := Vector3(0.0, 0.85, 0.0)
const WAVE := 0.03
const FLYING := "thrown_foe_flying"

var hero: CharacterBody3D
var hauls := []  # {foe, i, root, top, end, t0, up, hold, down, from, done, tendril, keep}
var on_up := Callable()  # (foe, i) it leaves the floor
var on_end := Callable()  # (foe, i) it gets where it ends
var on_top := Callable()  # (foe, i) round 55: it gets to the top (the hold starts)
var ended := 0  # (checks)
var top_y := 0.0  # (checks) the highest any got
var _t := 0.0


static func start(by: CharacterBody3D, items: Array) -> Node3D:
	var g: Node3D = SELF.new()
	g.hero = by
	var i := 0
	for it: Dictionary in items:
		var e: Variant = it.get("foe")
		if not is_instance_valid(e) or not e.is_alive():
			continue
		g.hauls.append({"foe": e, "i": i, "root": it.get("root", (e as Node3D).global_position), "top": it.top, "end": it.end,
			"t0": float(it.get("t0", 0.0)), "up": float(it.get("up", UP)), "hold": float(it.get("hold", HOLD)),
			"down": float(it.get("down", DOWN)), "keep": bool(it.get("keep", false)), "done": false, "lifted": false})
		i += 1
	by.get_parent().add_child(g)
	return g


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for one: Dictionary in hauls:
		one.tendril = TENDRIL.new()
		add_child(one.tendril)
		(one.tendril as Node3D).visible = false


func _physics_process(delta: float) -> void:
	_t += delta
	var left := false
	for one: Dictionary in hauls:
		var e: Variant = one.foe
		var tendril: Node3D = one.tendril
		if one.done:
			continue
		if not is_instance_valid(e) or not e.is_alive():
			_finish(one, false)
			continue
		left = true
		var foe := e as Node3D
		var k: float = _t - float(one.t0)
		if k < 0.0:
			continue
		if not one.lifted:
			if foe.has_meta(FLYING):  # (someone else is throwing it: wait for that to end)
				continue
			one.lifted = true
			one.from = foe.global_position
			foe.set_meta(FLYING, true)
			if on_up.is_valid():
				on_up.call(foe, int(one.i))
			k = 0.0
		var up: float = one.up
		var hold: float = one.hold
		var down: float = one.down
		var p: Vector3
		if k < up:  # 1. up (eased out)
			var j := k / up
			p = (one.from as Vector3).lerp(one.top, 1.0 - (1.0 - j) * (1.0 - j))
		elif k < up + hold:  # 2. hold (a bob)
			p = (one.top as Vector3) + Vector3.UP * sin((k - up) / hold * PI) * 0.12
			if not one.get("topped", false):
				one.topped = true
				if on_top.is_valid():
					on_top.call(foe, int(one.i))
		else:  # 3. down (eased in: the slam)
			var j := clampf((k - up - hold) / down, 0.0, 1.0)
			p = (one.top as Vector3).lerp(one.end, j * j)
			if j >= 1.0:
				foe.global_position = one.end
				_finish(one, true)
				continue
		top_y = maxf(top_y, p.y)
		foe.global_position = p
		if foe is CharacterBody3D:
			(foe as CharacterBody3D).velocity = Vector3.ZERO
		var coil: float = float(foe.get("radius") if foe.get("radius") != null else 0.5) + 0.05
		tendril.draw(one.root, foe.global_position + CHEST, 1.0, WAVE, coil, _t)
	if not left:
		queue_free()


func _finish(one: Dictionary, arrived: bool) -> void:
	one.done = true
	(one.tendril as Node3D).visible = false
	var e: Variant = one.foe
	if not is_instance_valid(e):
		return
	if arrived:
		ended += 1
	if not one.keep or not arrived:
		if (e as Node).has_meta(FLYING) and one.lifted:
			(e as Node).remove_meta(FLYING)
		if not one.keep:
			(e as Node3D).global_position.y = maxf(0.0, (one.end as Vector3).y) if arrived else 0.0
	if arrived and on_end.is_valid():
		if one.keep and (e as Node).has_meta(FLYING):
			(e as Node).remove_meta(FLYING)  # (the throw on_end starts sets it again)
		on_end.call(e, int(one.i))


func _exit_tree() -> void:
	for one: Dictionary in hauls:  # (freed mid-haul: nobody stays in the air)
		if not one.done and one.lifted and is_instance_valid(one.foe):
			(one.foe as Node).remove_meta(FLYING)
			(one.foe as Node3D).global_position.y = 0.0
