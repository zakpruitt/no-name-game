extends SceneTree
## The dash counter (counter.gd, docs/features/counter.md), headless, in the training room on a swinging dummy:
## the window's timing (nothing before WINDOW s from contact, a counter inside it, a perfect only in the last PERFECT
## s), no counter when the dash is aimed away or nothing is coming (a plain dash), the i-frames through the strike,
## the mark, Backlash's slam, a perfect opening the counter breaker window and Ricochet landing; the swinging dummy's
## strike hurting him at a spar foe's third; the guide's hint; a parried bolt. Prints [counter] PASS/FAIL.
## Run: godot --headless --path . -s tests/counter_check.gd

var _fails: Array[String] = []
var main: Node
var hero: CharacterBody3D
var dummy: Node
var counter: GDScript


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	hero = main.player
	dummy = main._dummy
	counter = load("res://scripts/counter.gd")
	hero.bot_enabled = true  # (input_dir reads bot_move; the window's press comes at the sweet spot)
	hero.bot_move = Vector3.ZERO
	_check(not game.dummies_swing, "dummies don't swing by default (Settings off)")
	_check(is_equal_approx(counter.WINDOW, 0.25) and is_equal_approx(counter.PERFECT, 0.1), "window %.2f s, perfect %.2f s" % [counter.WINDOW, counter.PERFECT])
	await _swing_hurts()
	await _timing()
	await _plain_dash()
	await _backlash()
	await _perfect()
	await _bolt()
	if _fails.is_empty():
		print("[counter] PASS")
	else:
		for f in _fails:
			print("[counter] FAIL: ", f)
		print("[counter] FAIL (%d)" % _fails.size())
	quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


## Hero 2 m in front of the dummy, facing it; the dummy home, still, its swing timer clear.
func _stand() -> void:
	await create_timer(0.6).timeout
	for d: Node in main._dummies:
		d.swings = false
		d.global_position = d.home
		d.velocity = Vector3.ZERO
		d._set_state(d.State.CHASE)
		d._swing_cd = 0.0
		d._front_t = 0.0
	var fwd: Vector3 = (hero.global_position - dummy.home)
	fwd.y = 0.0
	hero.global_position = dummy.home + fwd.normalized() * 2.0
	hero.velocity = Vector3.ZERO
	hero._set_state(hero.State.MOVE)
	hero._dash_cd = 0.0
	hero._invuln_t = 0.0
	hero.hp = hero.max_hp
	hero._face(_to_dummy())
	hero.model.rotation.y = hero._facing_yaw
	dummy.model.rotation.y = atan2(fwd.x, fwd.z)
	await physics_frame


func _to_dummy() -> Vector3:
	var to: Vector3 = dummy.global_position - hero.global_position
	to.y = 0.0
	return to.normalized()


## The dummy mid-windup with its strike `left` s away.
func _windup(left: float) -> void:
	dummy._set_state(dummy.State.WINDUP)
	dummy._aim_dir = -_to_dummy()
	dummy._state_t = dummy.attack_windup - left


## A swinging dummy winds up after he stands there a beat, and its strike lands for a spar foe's third.
func _swing_hurts() -> void:
	await _stand()
	dummy.swings = true
	var swung: int = dummy.swings_done
	var wound := false
	for i in 180:
		await physics_frame
		wound = wound or dummy.state == dummy.State.WINDUP
		if dummy.swings_done > swung:
			break
	_check(wound, "the swinging dummy winds up with him in front of it")
	_check(dummy.swings_done > swung, "and strikes")
	_check(is_equal_approx(hero.max_hp - hero.hp, dummy.SWING_DAMAGE), "its strike hurts %.1f (got %.1f)" % [dummy.SWING_DAMAGE, hero.max_hp - hero.hp])
	dummy.swings = false


func _timing() -> void:
	await _stand()
	_windup(0.5)
	_check(counter.find(hero, _to_dummy()).is_empty(), "no counter 0.5 s before contact")
	_windup(0.2)
	var c: Dictionary = counter.find(hero, _to_dummy())
	_check(not c.is_empty() and not c.perfect, "a counter 0.2 s before contact, not perfect")
	_check(counter.find(hero, -_to_dummy()).is_empty(), "no counter aimed away from the attacker")
	_check(counter.find(hero, _to_dummy().rotated(Vector3.UP, deg_to_rad(80.0))).is_empty(), "no counter aimed 80 deg off")
	_check(not counter.find(hero, _to_dummy().rotated(Vector3.UP, deg_to_rad(45.0))).is_empty(), "a counter aimed 45 deg off")
	var rows: Array = counter.hint(hero, [])
	_check(rows.size() == 1 and rows[0].name == "Backlash" and rows[0].next.is_empty(), "the guide hints SPACE Backlash")
	_windup(0.06)
	c = counter.find(hero, _to_dummy())
	_check(not c.is_empty() and c.perfect, "a perfect 0.06 s before contact")
	rows = counter.hint(hero, [])
	_check(not rows.is_empty() and rows[0].next.get("name", "") == "Ricochet", "the guide hints Ricochet on a perfect")
	dummy._set_state(dummy.State.CHASE)


## No strike coming: the dash is the dash.
func _plain_dash() -> void:
	await _stand()
	var n: int = hero.counters
	hero.bot_move = _to_dummy()
	hero._start_dash()
	hero.bot_move = Vector3.ZERO
	_check(hero.state == hero.State.DASH and hero._counter.is_empty() and hero.counters == n, "a dash with nothing coming is a plain dash")
	await create_timer(0.4).timeout


func _backlash() -> void:
	await _stand()
	_windup(0.2)
	var hits: int = dummy.hits_taken
	hero.bot_move = _to_dummy()
	hero._start_dash()
	hero.bot_move = Vector3.ZERO
	_check(not hero._counter.is_empty() and hero.state == hero.State.DASH, "the dash into the strike is the counter")
	_check(hero.counters >= 1 and hero.counter_perfects == 0, "counted, not perfect")
	_check(hero.is_invulnerable(), "i-frames on the counter")
	_check(dummy.state == dummy.State.HURT, "the attacker is staggered (its strike is off)")
	_check(load("res://scripts/dark_fx.gd").marked(dummy), "the attacker is marked")
	var hp: float = hero.hp
	hero.take_hit(10.0, Vector3.ZERO, dummy)
	_check(hero.hp == hp, "a hit in the counter does nothing")
	var lifted := 0.0
	for i in 60:
		await physics_frame
		lifted = maxf(lifted, dummy.global_position.y)
		if hero._counter.is_empty():
			break
	_check(lifted > 1.0, "Backlash swings it up over him (%.2f m)" % lifted)
	_check(dummy.hits_taken > hits, "and slams it (a hit)")
	_check(hero.state == hero.State.MOVE, "a plain counter ends on his feet, no window (state %d)" % hero.state)
	_check(hero.hp == hero.max_hp, "the strike never landed")


func _perfect() -> void:
	await create_timer(1.0).timeout
	await _stand()
	_windup(0.06)
	var landed: int = hero.breakers_landed
	hero.bot_move = _to_dummy()
	hero._start_dash()
	hero.bot_move = Vector3.ZERO
	_check(hero.counter_perfects == 1, "a perfect counter")
	var leapt := false
	for i in 90:
		await physics_frame
		if hero.state == hero.State.LEAP:
			leapt = true
			break
	_check(leapt and hero._brk_id == counter.BREAKER, "a perfect opens the counter breaker window")
	if leapt:
		await physics_frame
		var held: Array = hero._void.held_foes()
		_check(held.size() == 1 and held[0] == dummy, "the tentacle holds the attacker alone (%d)" % held.size())
		var w: Dictionary = hero.breaker_window()
		_check(w.get("name", "") == "Ricochet" and w.get("options", []).size() == 1, "one ending: Ricochet")
	for i in 120:
		await physics_frame
		if hero.breakers_landed > landed:
			break
	_check(hero.breakers_landed > landed and hero.endings_seen.has("Ricochet"), "Ricochet lands")
	_check(counter.last_ricochet in ["foe", "wall", "open"], "it went somewhere (%s)" % counter.last_ricochet)
	await create_timer(0.6).timeout
	_check(load("res://scripts/floor_bind.gd").holds(dummy) or counter.last_ricochet == "open", "bound where it hit")
	_check(hero.hp == hero.max_hp, "untouched through it all")


## An enemy bolt in the window is batted back at whoever shot it.
func _bolt() -> void:
	await create_timer(1.6).timeout
	await _stand()
	var p: Node3D = load("res://scripts/projectile.gd").new()
	p.direction = -_to_dummy()
	p.speed = 9.0
	p.source = dummy
	main.add_child(p)
	p.global_position = hero.global_position + Vector3.UP + _to_dummy() * 1.6
	await physics_frame
	var c: Dictionary = counter.find(hero, _to_dummy())
	_check(c.get("bolt") == p, "a bolt about to hit counts")
	hero.bot_move = _to_dummy()
	hero._start_dash()
	hero.bot_move = Vector3.ZERO
	_check(p.reflected and p.direction.dot(_to_dummy()) > 0.9, "the bolt goes back at its shooter")
	await create_timer(0.3).timeout
	_check(hero.hp == hero.max_hp, "the bolt never hit him")
