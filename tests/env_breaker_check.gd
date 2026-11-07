extends SceneTree
## Round 51 env-pieces (docs/features/env-pieces.md), headless: the heretic's environmental verbs that need the real
## comic hero playing a breaker against stand-in foes (cool_pass_check's harness): Slapshot into a Frost Wall against
## the open; Short Circuit's arcs reaching from a live grate (Live Floor) to a foe past its own reach. Prints PASS/FAIL.  Run: godot --headless --path . -s tests/env_breaker_check.gd

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
	await _frost_wall_slapshot()
	await _live_floor_short_circuit()
	print("env_breaker_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


## Round 51 (env-pieces, Frost Wall): Slapshot into the ice wall a Frost Spear raised on a grate pays the wall's damage
## (more than in the open), and the splat shatters it.
func _frost_wall_slapshot() -> void:
	var FW: GDScript = load("res://scripts/frost_wall.gd")
	hero.bot_enabled = true
	hero.bot_alt = true
	var dealt := {}
	for case: String in ["open", "ice"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		var env: Node = load("res://scripts/env_target.gd").new()  # (the room's structure list: the Frost Wall joins it)
		world.add_child(env)
		var grate := Node3D.new()
		world.add_child(grate)
		grate.global_position = Vector3(0, 0, 6.0)
		var ice: Node3D = FW.raise(world, grate, Vector3.ZERO) if case == "ice" else null
		await physics_frame
		await physics_frame
		var row := [_foe(Vector3(-1.5, 0, 3.5)), _foe(Vector3(1.5, 0, 1.0)), _foe(Vector3(0.5, 0, -2.5))]
		hero._start_attack("EF")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		if ice != null:  # (he puts the cursor on it in the window: the bracket, env_target's pick)
			hero.set_meta(&"env_pick", {"ctx": "slapshot", "id": FW.ID, "chosen": true, "ms": Time.get_ticks_msec()})
		var before: Array = row.map(func(f: Foe) -> float: return f.hp)
		await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
		await _until(func() -> bool: return row.any(func(f: Foe) -> bool: return f.has_meta("thrown_foe_flying")), 1.0)
		await _until(func() -> bool: return row.all(func(f: Foe) -> bool: return not f.has_meta("thrown_foe_flying")), 3.0)
		for i in 60:
			await physics_frame
		var sum := 0.0
		for i in row.size():
			sum += before[i] - row[i].hp
		dealt[case] = sum
		if case == "ice":
			_check(row.any(func(f: Foe) -> bool: return f.global_position.z < 7.7), "the cubes stop on the Frost Wall (%s)" % str(row.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
			_check(not is_instance_valid(ice) or ice.get("_gone"), "the splat shatters the Frost Wall")
		for f: Foe in row:
			f.free()
		if is_instance_valid(ice):
			ice.free()
		grate.free()
		env.free()
		await _settle()
	print("  frost wall: Slapshot into the ice wall %.0f, in the open %.0f (three cubes)" % [dealt.ice, dealt.open])
	_check(dealt.ice > dealt.open * 1.3, "Slapshot into the Frost Wall pays the wall's damage (%.0f vs %.0f open)" % [dealt.ice, dealt.open])
	hero.bot_alt = false
	hero.bot_enabled = false


## Live Floor: Short Circuit lands by him; a foe 20 m off is past SC_REACH from the landing but within it of a live grate
## (14 m out): the arcs reach it from the grate. With the grate cold, they don't.
func _live_floor_short_circuit() -> void:
	var EP: GDScript = load("res://scripts/env_piece.gd")
	var ve: GDScript = load("res://scripts/void_element.gd")
	var dealt := {}
	for case: String in ["cold", "live"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		var grate := Node3D.new()
		world.add_child(grate)
		grate.global_position = Vector3(0, 0, 14.0)
		grate.add_to_group("env_grate")
		grate.set_meta(EP.TAG_META, "grate")
		grate.set_meta(EP.STATE_META, case)
		var near := _foe(Vector3(0, 0, 2.5))
		var far := _foe(Vector3(0, 0, 20.0))
		far.elite = true
		hero.bot_enabled = true
		hero.bot_alt = true
		hero._start_attack("EE")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		var hp := far.hp
		await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
		await _until(func() -> bool: return far.hp < hp, 1.5)
		dealt[case] = hp - far.hp
		if case == "live":
			_check(ve.marked(far, "charged"), "the foe by the live grate is charged")
		hero.bot_enabled = false
		hero.bot_alt = false
		near.free()
		far.free()
		grate.free()
		await _settle()
	print("  live floor: Short Circuit on a foe 20 m off, by a live grate %.0f, by a cold one %.0f" % [dealt.live, dealt.cold])
	_check(dealt.live > 0.0 and dealt.cold == 0.0, "Short Circuit reaches from a live grate, not a cold one (%.0f / %.0f)" % [dealt.live, dealt.cold])


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
