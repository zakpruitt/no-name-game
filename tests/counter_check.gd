extends SceneTree
## The dash counter (counter.gd, docs/features/counter.md), headless, in the training room on a swinging dummy:
## the window's timing (nothing before WINDOW s from contact, a counter inside it, a perfect only in the last PERFECT
## s), no counter when the dash is aimed away or nothing is coming (a plain dash), the i-frames through the strike,
## the mark, Backlash's slam, a perfect opening the counter breaker window and Ricochet landing; the swinging dummy's
## strike hurting him at a spar foe's third; the guide's hint; a parried bolt; round 53's gallows (env_flourish.gd) in
## the room with pieces: Ricochet hangs the attacker on the pillar's hook, bound, x GALLOWS_MULT on the wall's, the
## counter window's bracket on the hook, a hit on it a Snap, a wall the cursor chose wins. Prints [counter] PASS/FAIL.
## Run: godot --headless --path . -s tests/counter_check.gd

var _fails: Array[String] = []
var main: Node
var hero: CharacterBody3D
var dummy: Node
var counter: GDScript


var game: Node


func _initialize() -> void:
	await process_frame
	game = get_root().get_node("Game")
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
	await _gallows()
	game.room = "plain"
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
	_check(counter.hint(hero, [{"kind": "light"}]).is_empty(), "no guide rows through Backlash (it takes no input)")
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


## Round 53, gallows (env_flourish.gd): in the room with pieces (its `flourishes` rule) the counter dummy stood ~5 m
## from the hook on the east pillar. The window brackets the hook; Ricochet hurls it onto the hook, where it hangs bound
## (the hook_swing swinging) after a splat at GALLOWS_MULT x the wall's; a hit on it is a Snap and lets it go. Then the
## same counter with the flourish off (the plain room's rule) splats it on the pillar: the wall's, for the ratio. The
## cursor's wall over the hook wins.
func _gallows() -> void:
	var FL: GDScript = load("res://scripts/env_flourish.gd")
	var ENV_T: GDScript = load("res://scripts/env_target.gd")
	var EP: GDScript = load("res://scripts/env_piece.gd")
	_check(not FL.on("gallows"), "gallows is off in the plain room (no upgrade, no rule)")
	main.queue_free()
	await process_frame
	game.room = "pieces"
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	hero = main.player
	dummy = main._dummy
	hero.bot_enabled = true
	hero.bot_move = Vector3.ZERO
	_check(FL.on("gallows"), "gallows is on in the room with pieces (its flourishes rule)")
	var hook: Node3D = null
	for n: Node in get_root().get_tree().get_nodes_in_group("env_hook"):
		if Vector2((n as Node3D).global_position.x - 7.47, (n as Node3D).global_position.z + 7.47).length() < 0.5:
			hook = n
	_check(hook != null, "the pillar's hook is placed")
	if hook == null:
		return
	var point: Vector3 = FL.hook_point(hook)
	_check(point.y > 0.6 and point.y < 2.0, "its point hangs at a foe's height (%.2f m)" % point.y)
	var pillar: Node3D = null
	for n: Node in get_root().get_tree().get_nodes_in_group("env_pillar"):
		if Vector2((n as Node3D).global_position.x - 8.0, (n as Node3D).global_position.z + 8.0).length() < 0.5:
			pillar = n
	for i in main._dummies.size():  # (the others out of the way: the counter dummy alone by the hook)
		main._dummies[i].home = Vector3(4.0, dummy.home.y, -4.6) if i == 0 else Vector3(-6.0 - i * 1.5, dummy.home.y, 6.0)
	hero.global_position = Vector3(4.0, hero.global_position.y, -1.0)
	var hung: int = FL.Hang.hung
	var splat: float = await _counter_splat(true)
	_check(counter.last_ricochet == "hook", "Ricochet takes the attacker to the hook (%s)" % counter.last_ricochet)
	_check(FL.Hang.hung == hung + 1, "and it hangs on it")
	await create_timer(0.3).timeout
	_check(load("res://scripts/floor_bind.gd").holds(dummy), "bound while it hangs")
	_check(EP.state(hook) == "hung", "the hook is hung")
	var sw: Node3D = FL._swing(hook)
	_check(sw != null and absf(sw.rotation.z) > 0.02, "the hook swings with it (%.3f rad)" % (sw.rotation.z if sw != null else 0.0))
	point = FL.hook_point(hook)  # (where the point is now, swinging)
	_check(Vector2(dummy.global_position.x - point.x, dummy.global_position.z - point.z).length() < 0.8 and dummy.global_position.y > 0.05,
		"it hangs up under the hook (%.2f m up, %.2f m off, point %s at %s)" % [dummy.global_position.y, Vector2(dummy.global_position.x - point.x, dummy.global_position.z - point.z).length(), point, dummy.global_position])
	var snaps: int = FL.Hang.snaps
	var paid: int = int(hero.VOID_ELEMENT.improv_paid.get("bound", 0))
	dummy.take_hit(4.0, Vector3.ZERO, 0.0, false)
	await physics_frame
	await physics_frame
	_check(FL.Hang.snaps == snaps + 1 and int(hero.VOID_ELEMENT.improv_paid.get("bound", 0)) > paid, "a hit on the hung foe is a Snap")
	_check(not load("res://scripts/floor_bind.gd").holds(dummy), "the Snap lets it go")
	await create_timer(1.8).timeout
	_check(EP.state(hook) == "empty" and absf(sw.rotation.z) < 0.01, "the hook settles, empty again")
	game.room = "plain"  # (the rule off: the same counter splats it on the pillar behind the hook)
	var wall: float = await _counter_splat(false)
	_check(counter.last_ricochet == "wall", "with the flourish off it is a wall Ricochet (%s)" % counter.last_ricochet)
	game.room = "pieces"
	print("  gallows: hung splat %.1f vs the wall's %.1f (x%.2f, want x%.2f)" % [splat, wall, splat / maxf(wall, 0.01), FL.GALLOWS_MULT])
	_check(wall > 0.0 and absf(splat / wall - FL.GALLOWS_MULT) < 0.02, "the hang pays x%.2f the wall's" % FL.GALLOWS_MULT)
	await create_timer(1.0).timeout
	# the cursor's choice in the window (env_target CTX "gallows"): a pillar over the hook, or the hook itself
	var t: Dictionary
	if pillar != null and pillar.has_meta(EP.ID_META):
		hero.set_meta(ENV_T.PICK_META, {"ctx": "gallows", "id": pillar.get_meta(EP.ID_META), "chosen": true, "ms": Time.get_ticks_msec()})
		t = counter.ricochet_target(hero, dummy)
		_check(t.kind == "wall", "a pillar the cursor chose wins over the hook (%s)" % t.kind)
	hero.set_meta(ENV_T.PICK_META, {"ctx": "gallows", "id": hook.get_meta(EP.ID_META, ""), "chosen": true, "ms": Time.get_ticks_msec()})
	t = counter.ricochet_target(hero, dummy)
	_check(t.kind == "hook", "the hook the cursor chose (%s)" % t.kind)
	hero.remove_meta(ENV_T.PICK_META)


## A perfect counter on the dummy from where he stands, Ricochet landing: its splat's damage (the first hit after the
## throw). `bracket`: the window's pick is on the hook (env_target CTX "gallows").
func _counter_splat(bracket: bool) -> float:
	await create_timer(1.2).timeout
	await _stand()
	_windup(0.06)
	var landed: int = hero.breakers_landed
	hero.bot_move = _to_dummy()
	hero._start_dash()
	hero.bot_move = Vector3.ZERO
	var ENV_T: GDScript = load("res://scripts/env_target.gd")
	var picked := ""
	for i in 120:
		await physics_frame
		if hero.state == hero.State.LEAP and hero.has_meta(ENV_T.PICK_META):
			var pk: Dictionary = hero.get_meta(ENV_T.PICK_META)
			if pk.get("ctx", "") == "gallows":
				picked = str(pk.get("id", ""))
		if hero.breakers_landed > landed:
			break
	if bracket:
		_check(picked.begins_with("hook"), "the counter window brackets the hook (%s)" % picked)
	var before: float = dummy.string_damage
	var hits: int = dummy.hits_taken
	for i in 90:
		await physics_frame
		if dummy.hits_taken > hits:
			break
	return dummy.string_damage - before
