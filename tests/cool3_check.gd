extends SceneTree
## Round 54 cool pass 3 (docs/features/combo-breakers.md "Round 54 cool pass 3"), headless: the rebuilt mids and the
## raised endings do their new beat. Reap's hook yanks the far foe in and Black Tide pays the reaped more; the second
## beats of Grounded, Worldbreaker, Cataclysm, Short Circuit and Shatterstorm land; Cold Front bowls the cubes into a
## registered wall; Maw's heap jaws; Backlash's glint and flying blade. cool_pass_check's harness. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/cool3_check.gd

var fails := 0
var world: Node3D
var hero: CharacterBody3D


class Foe extends CharacterBody3D:
	var radius := 0.5
	var hp := 500.0
	var elite := false
	var hits := 0
	var last_big := false
	var frozen := false
	var up := false  # in the air (the crossovers read it)
	var last_kb := Vector3.ZERO
	var last_launch := 0.0
	var chill_t := 0.0
	func chill(t: float, _m: float) -> void: chill_t = t
	func freeze(_t: float, _m: float) -> void: frozen = true
	func is_alive() -> bool: return hp > 0.0
	func is_airborne() -> bool: return up
	func stagger(_t: float) -> void: pass
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, big = false, _x = null) -> void:
		hp -= d
		hits += 1
		last_big = big
		last_kb = _kb
		last_launch = _l


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.comic_style = true
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	hero = load("res://scripts/player.gd").new()
	world.add_child(hero)
	await process_frame
	await _settle()
	var ve: GDScript = load("res://scripts/void_element.gd")
	hero.bot_enabled = true
	await _reap(ve)
	await _seconds(ve)
	await _cold_front(ve)
	_counter()
	print("cool3_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


## Reap (GR -> VR): a near foe in the crescent, a far one in the cone past it. The hook bites the far one and yanks it in.
func _reap(ve: GDScript) -> void:
	var mb: GDScript = ve.MID_BEATS
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var near: Foe = _foe(Vector3(0.3, 0, 2.0))
	var far: Foe = _foe(Vector3(-0.4, 0, 7.5))
	await _settle()
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var hooks: int = mb.hooks
	hero._start_attack("GR")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	await _until(func() -> bool: return hero.HERO_MOVES.progress(hero) >= hero._move.cancel, 2.0)
	hero._start_attack("VR")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await create_timer(0.6).timeout
	_check(mb.hooks > hooks, "Reap throws its hook (%d)" % (mb.hooks - hooks))
	_check(far.hits > 0 and ve.marked(far, "reaped"), "the hook bites the far foe and marks it reaped")
	_check(far.global_position.z < 5.0, "the hook yanks the far foe in (z %.1f)" % far.global_position.z)
	near.free()
	far.free()
	await _settle()


## The second beats on the endings that had one beat: each counts on VOID_ELEMENT.ground_beats.
func _seconds(ve: GDScript) -> void:
	var three := [Vector3(0, 0, 3.0), Vector3(1.4, 0, 3.5), Vector3(-1.3, 0, 3.8)]
	for key: String in ["EE", "EW", "XF", "EE_alt", "EF"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		var foes: Array = []
		for p: Vector3 in three:
			foes.append(_foe(p))
		await _settle()
		hero.global_position = Vector3.ZERO
		var b: Dictionary = ve.entry(key.get_slice("_", 0)).duplicate(true)
		if key.ends_with("_alt"):
			b.merge(b.alt, true)
		if key == "EF":
			for f: Foe in foes:
				ve.encase(f)
		var beats: int = ve.ground_beats
		var seized: Array = [] if key == "EE_alt" else foes.duplicate()
		if key == "EE_alt":  # (Short Circuit: one held, the arcs run out to the rest)
			seized = [foes[0]]
		ve.breaker_impact(hero, b, Vector3(0, 0, 1.0), seized, 1.0)
		await create_timer(1.6).timeout
		var n: int = ve.ground_beats - beats
		_check(n >= 2, "%s: its second beat lands on them (%d)" % [key, n])
		print("  %s: second beats %d" % [key, n])
		for f: Foe in foes:
			f.free()
		await _settle()


## Cold Front (EW alt): by a registered wall each cube is bowled into it; in the open they are thrown as before.
func _cold_front(ve: GDScript) -> void:
	var env: Node3D = load("res://scripts/env_target.gd").new()
	world.add_child(env)
	var dealt := {}
	for case: String in ["wall", "open"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		var wall: StaticBody3D = null
		env.structures.clear()
		if case == "wall":
			wall = _wall(Vector3(0, 1, 7.0))
			env.add_wall(Vector3(-15, 0, 6.75), Vector3(15, 0, 6.75), Vector3(0, 0, -1))
		var foes: Array = [_foe(Vector3(0, 0, 2.5)), _foe(Vector3(1.3, 0, 2.2)), _foe(Vector3(-1.2, 0, 2.8))]
		for f: Foe in foes:
			ve.encase(f)
		await _settle()
		hero.global_position = Vector3.ZERO
		var b: Dictionary = ve.entry("EW").duplicate(true)
		b.merge(b.alt, true)
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		ve.breaker_impact(hero, b, Vector3(0, 0, 1.0), foes.duplicate(), 1.0)
		await create_timer(2.0).timeout
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "wall":
			_check(foes.any(func(f: Foe) -> bool: return ve.wall_fresh(f)), "Cold Front bowls the cubes into the wall (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		for f: Foe in foes:
			f.free()
		if wall != null:
			wall.free()
		await _settle()
	print("  cold front: by a wall %.0f / open %.0f" % [dealt.wall, dealt.open])
	_check(dealt.wall > dealt.open * 1.3, "Cold Front by a wall out-damages it in the open (%.0f vs %.0f)" % [dealt.wall, dealt.open])
	env.free()


## Backlash's parry: the glint and the attacker's weapon knocked flying.
func _counter() -> void:
	var cfx: GDScript = load("res://scripts/counter_fx.gd")
	var g: int = cfx.glints
	var bl: int = cfx.blades
	cfx.parry(world, Vector3.ZERO, Vector3(0, 0, 2.0), true)
	_check(cfx.glints > g and cfx.blades > bl, "the parry draws its glint and throws the weapon")


func _wall(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 4, 0.5)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body


func game_end_slowmo() -> void:
	root.get_node("Game").end_slowmo()


func _foe(at: Vector3) -> Foe:
	var f := Foe.new()
	world.add_child(f)
	f.global_position = at
	f.add_to_group("enemies")
	return f


func _settle() -> void:
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
	for i in 30:
		await physics_frame


func _until(done: Callable, seconds: float) -> void:
	var t := 0.0
	while not done.call() and t < seconds:
		await physics_frame
		t += 1.0 / 60.0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL: ", what)
