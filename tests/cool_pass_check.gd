extends SceneTree
## Round 51 cool pass (docs/features/combo-breakers.md "Round 51 cool pass"), headless: each rebuilt ending wins its
## best situation and loses its worst. Avalanche by a wall against the open, Collapse by a wall against the open, and
## Abyss against Collapse (one big foe: Abyss's; a crowd of four: Collapse's). Runs the real comic hero against
## stand-in foes (void_arm_check's harness; split out so neither runs past agent.sh's 180 s a test). Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/cool_pass_check.gd

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
	await _cool_pass()
	print("cool_pass_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _cool_pass() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	hero.bot_enabled = true
	var dealt := {}
	# Avalanche (IS): the tower by a wall falls into it; in the open it falls away from him and the cubes slide to a stop.
	for case: String in ["aval_open", "aval_wall"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		var wall: StaticBody3D = _wall(Vector3(0, 1, 11.5)) if case.ends_with("wall") else null
		var foes: Array = [_foe(Vector3(1.5, 0, 5)), _foe(Vector3(-1.2, 0, 5.4)), _foe(Vector3(0.4, 0, 6.3))]
		await physics_frame
		hero._start_attack("IP")
		await _until(func() -> bool: return hero._hits_done > 0, 3.0)
		hero._start_attack("IJ")
		await _until(func() -> bool: return hero._hits_done > 0, 3.0)
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		var landed: int = hero.breakers_landed
		hero._start_attack("IS")
		await _until(func() -> bool: return hero.breakers_landed > landed, 5.0)
		_check(hero.breakers_landed > landed and hero.HERO_LEAP.breaker_name(hero) == "Avalanche", "%s: Avalanche lands" % case)
		await create_timer(1.6).timeout
		for i in 20:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "aval_wall":
			_check(foes.all(func(f: Foe) -> bool: return f.global_position.z > 8.5 and ve.wall_fresh(f)),
				"the tower falls into the wall, every cube on it (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		for f: Foe in foes:
			f.free()
		if wall != null:
			wall.free()
		await _settle()
	print("  avalanche: open %.0f / by a wall %.0f" % [dealt.aval_open, dealt.aval_wall])
	_check(dealt.aval_wall > dealt.aval_open * 1.5, "Avalanche by a wall out-damages it in the open (%.0f vs %.0f)" % [dealt.aval_wall, dealt.aval_open])
	# Collapse (VS): the hole spits them into a wall, or up out of the floor.
	for case: String in ["coll_wall", "coll_open"]:  # (each settles first: the hero still moving off the last case turned the slam round)
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		var wall: StaticBody3D = _wall(Vector3(0, 1, 9.0)) if case.ends_with("wall") else null
		var foes: Array = [_foe(Vector3(0, 0, 3)), _foe(Vector3(1.4, 0, 3.6)), _foe(Vector3(-1.3, 0, 3.4))]
		await _settle()
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero._start_attack("GR")
		await _until(func() -> bool: return hero._hits_done > 0, 2.0)
		var landed: int = hero.breakers_landed
		hero._start_attack("VS")
		await _until(func() -> bool: return hero._hits_done > 0, 3.0)
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed, "%s: Collapse lands" % case)
		await create_timer(1.6).timeout
		for i in 20:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "coll_wall":
			_check(foes.all(func(f: Foe) -> bool: return ve.wall_fresh(f)), "the hole spits every one into the wall (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		for f: Foe in foes:
			f.free()
		if wall != null:
			wall.free()
		await _settle()
	print("  collapse: open %.0f / by a wall %.0f" % [dealt.coll_open, dealt.coll_wall])
	_check(dealt.coll_wall > dealt.coll_open * 1.2, "Collapse by a wall out-damages it in the open (%.0f vs %.0f)" % [dealt.coll_wall, dealt.coll_open])
	# Abyss (OW) against Collapse (VS), the two dark endings off a hold: one big foe is Abyss's, a crowd Collapse's.
	for case: String in ["abyss_big", "coll_big", "abyss_crowd", "coll_crowd"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		var foes: Array = []
		if case.ends_with("big"):
			var b: Foe = _foe(Vector3(0, 0, 4))
			b.elite = true
			foes.append(b)
		else:
			for p: Vector3 in [Vector3(0, 0, 4), Vector3(1.3, 0, 4.4), Vector3(-1.2, 0, 4.6), Vector3(0.3, 0, 5.6)]:
				foes.append(_foe(p))
		await physics_frame
		var landed: int = hero.breakers_landed
		var before: Array = []
		if case.begins_with("abyss"):
			before = foes.map(func(f: Foe) -> float: return f.hp)
			hero._start_attack("OW")
			await _until(func() -> bool: return hero.breakers_landed > landed, 5.0)
		else:
			hero._start_attack("GR")
			await _until(func() -> bool: return hero._hits_done > 0, 2.0)
			hero._start_attack("VS")
			await _until(func() -> bool: return hero._hits_done > 0, 3.0)
			before = foes.map(func(f: Foe) -> float: return f.hp)
			await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed, "%s lands" % case)
		await create_timer(1.6).timeout
		for i in 20:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case.begins_with("abyss"):
			_check(foes.all(func(f: Foe) -> bool: return absf(f.global_position.y) < 0.05), "%s: all back on the floor" % case)
		for f: Foe in foes:
			f.free()
		await _settle()
	print("  abyss vs collapse: one big %.0f / %.0f, a crowd of 4 %.0f / %.0f" % [dealt.abyss_big, dealt.coll_big, dealt.abyss_crowd, dealt.coll_crowd])
	_check(dealt.abyss_big > dealt.coll_big * 1.2, "one big foe: Abyss beats Collapse (%.0f vs %.0f)" % [dealt.abyss_big, dealt.coll_big])
	_check(dealt.coll_crowd > dealt.abyss_crowd * 1.2, "a crowd: Collapse beats Abyss (%.0f vs %.0f)" % [dealt.coll_crowd, dealt.abyss_crowd])
	# (Abyss against Uproot, its LMB, the env-pieces lane's pair: here since void_arm_check is at the 180 s cap)
	await _uproot_pair(ve)
	hero.bot_enabled = false


## Abyss / Uproot (OW, round 51 env-pieces): a big foe 4 m from a pillar with one more on the line the pillar falls
## along, or the same two in the open. Uproot wins by the pillar, Abyss in the open; the pillar is out of the swing
## anchors after, laid down along the line.
func _uproot_pair(ve: GDScript) -> void:
	var EP: GDScript = load("res://scripts/env_piece.gd")
	var dealt := {}
	for case: String in ["abyss_pillar", "uproot_pillar", "abyss_open", "uproot_open"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		hero.bot_alt = case.begins_with("uproot")
		var pillar: Node3D = null
		if case.ends_with("pillar"):
			pillar = Node3D.new()
			world.add_child(pillar)
			pillar.global_position = Vector3(0, 0, 8)
			pillar.set_meta(EP.TAG_META, "pillar")
			pillar.set_meta(EP.STATE_META, "whole")
			pillar.add_to_group("env_pillar")
			pillar.add_to_group("grab_anchors")
		var big := _foe(Vector3(0, 0, 4))
		big.radius = 1.0
		var other := _foe(Vector3(0.8, 0, 6))
		var foes: Array = [big, other]
		await physics_frame
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		var landed: int = hero.breakers_landed
		hero._start_attack("OW")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		var opts: Array = hero.breaker_window().get("options", [])
		_check(opts.size() == 2 and opts[0].button == "light" and opts[0].name == "Uproot" and opts[1].name == "Abyss",
			"%s: the window offers LMB Uproot, RMB Abyss (%s)" % [case, str(opts)])
		await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed, "%s: lands" % case)
		await create_timer(0.6, true, false, true).timeout  # (the club comes down on real time)
		for i in 20:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "uproot_pillar":
			_check(not pillar.is_in_group("grab_anchors") and EP.state(pillar) == "toppled", "Uproot leaves the pillar toppled, out of the swing anchors (%s)" % EP.state(pillar))
			_check(pillar.global_transform.basis.y.dot(Vector3(0, 0, -1)) > 0.9, "laid down along the line to the foe (%s)" % str(pillar.global_transform.basis.y))
			_check(ve.marked(big, "buried") and ve.marked(other, "buried"), "the foe and the one on the line are buried")
		if pillar != null:
			for l: Variant in pillar.get_meta(&"env_leftovers", []):
				if is_instance_valid(l):
					l.free()
			pillar.free()
		for f: Foe in foes:
			f.free()
		await _settle()
	print("  abyss pair: by a pillar abyss %.0f / uproot %.0f, open abyss %.0f / uproot %.0f" % [dealt.abyss_pillar, dealt.uproot_pillar, dealt.abyss_open, dealt.uproot_open])
	_check(dealt.uproot_pillar > dealt.abyss_pillar * 1.3, "a big foe by a pillar: Uproot out-damages Abyss (%.0f vs %.0f)" % [dealt.uproot_pillar, dealt.abyss_pillar])
	_check(dealt.abyss_open > dealt.uproot_open * 1.5, "in the open: Abyss out-damages Uproot (%.0f vs %.0f)" % [dealt.abyss_open, dealt.uproot_open])
	hero.bot_alt = false


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
