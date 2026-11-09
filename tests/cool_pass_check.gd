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
			b.radius = 1.0  # (heavy: void_grab.is_heavy, radius 0.9+)
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
	await _cool2(ve)
	await _maw_pair(ve)
	hero.bot_enabled = false


## Round 52 cool pass (combo-cool2): Eruption (XM, off Hailstorm -> Meltdown) against Flash Freeze (XS, off Steam
## Burst), the two endings Dash L H H leads to. Three burning foes by a wall: Eruption hurls them into it (best), and
## beats Flash Freeze there; a crowd of four in the open: Flash Freeze's chain of shells (best) beats Eruption, which
## only drops them back into the floor (its worst).
func _cool2(ve: GDScript) -> void:
	var dealt := {}
	var three := [Vector3(0, 0, 2.5), Vector3(1.3, 0, 2.2), Vector3(-1.2, 0, 2.8)]
	var four := [Vector3(0, 0, 2.5), Vector3(1.4, 0, 2.2), Vector3(-1.3, 0, 2.8), Vector3(0.4, 0, 4.0)]
	for case: String in ["erupt_wall", "ff_wall", "erupt_open", "ff_open", "erupt_open3"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		var wall: StaticBody3D = _wall(Vector3(0, 1, 8.0)) if case.ends_with("wall") else null
		var foes: Array = []
		for p: Vector3 in (four if case.ends_with("open") else three):
			foes.append(_foe(p))
		for f: Foe in foes:
			ve.encase(f)
		await _settle()
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		var landed: int = hero.breakers_landed
		if case.begins_with("erupt"):
			hero._start_attack("XG")
			await _until(func() -> bool: return hero._hits_done > 0, 3.0)
			await _until(func() -> bool: return hero.HERO_MOVES.progress(hero) >= hero._move.cancel, 2.0)
			for f: Foe in foes:
				f.up = true
			hero._start_attack("XM")
		else:
			hero._start_attack("XS")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 4.0)
		for f: Foe in foes:
			f.up = false
		var name: String = hero.HERO_LEAP.breaker_name(hero)
		_check(name == ("Eruption" if case.begins_with("erupt") else "Flash Freeze"), "%s: the window opens on its ending (%s)" % [case, name])
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed, "%s: lands" % case)
		await create_timer(1.6).timeout
		for i in 20:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "erupt_wall":
			_check(foes.all(func(f: Foe) -> bool: return ve.wall_fresh(f) and absf(f.global_position.y) < 0.05 and ve.marked(f, "molten")),
				"Eruption hurls every one into the wall, and they slide down it burning (%s)" % str(foes.map(func(f: Foe) -> String: return "%.1f/%.1f" % [f.global_position.z, f.global_position.y])))
		if case == "ff_open":
			_check(foes.all(func(f: Foe) -> bool: return f.hits >= 2 and not ve.in_cube(f)), "Flash Freeze sets a shell on all four and breaks every one (%s)" % str(foes.map(func(f: Foe) -> int: return f.hits)))
		_check(foes.all(func(f: Foe) -> bool: return absf(f.global_position.y) < 0.05 and not f.has_meta("thrown_foe_flying")), "%s: all back on the floor" % case)
		for f: Foe in foes:
			f.free()
		if wall != null:
			wall.free()
		await _settle()
	print("  eruption vs flash freeze: three by a wall %.0f / %.0f, four in the open %.0f / %.0f, eruption three in the open %.0f" % [dealt.erupt_wall, dealt.ff_wall, dealt.erupt_open, dealt.ff_open, dealt.erupt_open3])
	_check(dealt.erupt_wall > dealt.ff_wall * 1.3, "by a wall: Eruption beats Flash Freeze (%.0f vs %.0f)" % [dealt.erupt_wall, dealt.ff_wall])
	_check(dealt.ff_open > dealt.erupt_open * 1.2, "a crowd in the open: Flash Freeze beats Eruption (%.0f vs %.0f)" % [dealt.ff_open, dealt.erupt_open])
	_check(dealt.erupt_wall > dealt.erupt_open3 * 1.6, "Eruption by a wall out-damages it in the open (%.0f vs %.0f)" % [dealt.erupt_wall, dealt.erupt_open3])


## Maw / Black Ice (VD, round 52): three in the pool, by a wall or in the open. Maw's tentacles knock the bitten
## together and slam the heap (a crowd, anywhere); Black Ice's blocks skid out across the ice into the wall.
func _maw_pair(ve: GDScript) -> void:
	var dealt := {}
	var pool := Vector3(0, 0, 4.5)
	var three := [Vector3(0, 0, 4.5), Vector3(1.3, 0, 4.9), Vector3(-1.2, 0, 5.1)]
	for case: String in ["maw_wall", "ice_wall", "maw_open", "ice_open"]:
		hero.global_position = Vector3(0, 0, 2.0)
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		var wall: StaticBody3D = _wall(Vector3(0, 1, 8.5)) if case.ends_with("wall") else null
		var foes: Array = []
		for p: Vector3 in three:
			foes.append(_foe(p))
		await _settle()
		hero.global_position = Vector3(0, 0, 2.0)
		hero._void.dark_spot = pool
		var b: Dictionary = ve.entry("VD").duplicate(true)
		if case.begins_with("ice"):
			ve.freeze_pool(hero)
			b.merge(b.alt, true)
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		ve.breaker_impact(hero, b, Vector3(0, 0, 2.0), [], 1.0)
		await create_timer(1.4).timeout
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "ice_wall":
			_check(foes.any(func(f: Foe) -> bool: return ve.wall_fresh(f)), "Black Ice skids the blocks into the wall (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		_check(foes.all(func(f: Foe) -> bool: return absf(f.global_position.y) < 0.3 and not f.has_meta("thrown_foe_flying")), "%s: all back on the floor" % case)
		for f: Foe in foes:
			f.free()
		if wall != null:
			wall.free()
		for n: Node in get_nodes_in_group("dark_maw"):
			n.queue_free()
		await _settle()
	print("  maw vs black ice: by a wall %.0f / %.0f, in the open %.0f / %.0f" % [dealt.maw_wall, dealt.ice_wall, dealt.maw_open, dealt.ice_open])
	_check(dealt.ice_wall > dealt.maw_wall, "by a wall: Black Ice beats Maw (%.0f vs %.0f)" % [dealt.ice_wall, dealt.maw_wall])
	_check(dealt.maw_open > dealt.ice_open, "in the open: Maw beats Black Ice (%.0f vs %.0f)" % [dealt.maw_open, dealt.ice_open])


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
