extends SceneTree
## Lava Leash (L L L H L, the dark x magma crossover, round 49) and Hellseam, headless: the routing, the pile, each of
## Lava Leash / Galvanize / Black Tide winning its own situation, the damage helpers and Hellseam's crater and seams.
## Runs the real comic hero against stand-in foes (void_arm_check's harness; split out so neither runs past
## agent.sh's 180 s a test). Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/lava_leash_check.gd

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
	var up := false
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
	await _lava_leash()
	print("lava_leash_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


## Lava Leash (L L L H L, dark-magma lane): the tentacles drag everyone Molten Palm hit back into a pile at his feet,
## each paying by the metre (torn off a wall more), and the seam erupts under the pile (molten, bound). Its best
## situation is the palm's foes at mixed ranges with one on a wall; Galvanize's is a spread crowd round him; Black
## Tide's is marked foes anywhere. Each of the three, played in each situation, must win its own. Then Hellseam.
func _lava_leash() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	var DARK: GDScript = load("res://scripts/dark_fx.gd")
	var LEASH: GDScript = load("res://scripts/lava_leash.gd")
	var r: Callable = load("res://scripts/hero_moves.gd").void_route
	_check(r.call("light", "EM", true, 0, false) == "XL", "L L L H L: Lava Leash")
	_check(r.call("light", "EM", false, 0, false) == "L1", "after the palm has finished, L is the string again")
	_check(ve.BREAKERS.has("XL") and ve.BREAKERS.XL.names.spirit == "Hellseam", "its window ends in Hellseam")
	_check(not ve.BREAKERS.XL.has("alt"), "one ending (Zak: two only when truly compelling)")
	_check(float(ve.BREAKERS.XL.leap) < float(hero.MOVES.XL.cancel), "the leap comes before the cancel (no press steals it)")
	await _settle()
	hero.bot_enabled = false
	# The situations, hero at the origin facing +z. palm: Molten Palm hit it (PALM_META); wall: splatted on a wall just
	# now. Every foe is Reap-marked (so Galvanize and Black Tide get the state they want too) but the spread crowd:
	# Galvanize's own situation is a crowd spread round him nobody has marked yet (Black Tide takes the unmarked only
	# within TIDE_NEAR).
	var cases := {
		"wall_mixed": [[Vector3(0, 0, 10), true, true], [Vector3(1.5, 0, 6), true, false], [Vector3(-1.2, 0, 3.5), true, false]],
		"spread_round": [],
		"marked_far": [[Vector3(-9, 0, 1), false, false], [Vector3(8, 0, -4), false, false], [Vector3(0, 0, -10), false, false],
			[Vector3(7, 0, 6), false, false]],
	}
	for k in 6:  # a crowd spread all round him 7 m out: past Black Tide's TIDE_NEAR, in Galvanize's GALV_REACH; the palm
		# went ahead, so it hit the one in front
		var a := TAU * k / 6.0
		var p := Vector3(sin(a), 0, cos(a)) * 7.0
		cases.spread_round.append([p, p.z > 0.0 and absf(p.x) < ve.PALM_HALF_WIDTH, false])
	var dealt := {}
	for case: String in cases:
		for id: String in ["XL", "XC", "VD"]:
			hero.global_position = Vector3.ZERO
			hero.model.position.y = 0.0
			hero._face(Vector3(0, 0, 1))
			var foes: Array = []
			for spec: Array in cases[case]:
				var f := _foe(spec[0])
				if case != "spread_round":
					DARK.mark(f)
				if spec[1]:
					f.set_meta(ve.PALM_META, Time.get_ticks_msec())
				if spec[2]:
					f.set_meta("last_wall_ms", Time.get_ticks_msec())
				foes.append(f)
			await physics_frame
			hero._start_attack(id)
			await _until(func() -> bool: return hero._hits_done > 0, 3.0)
			if id == "XL" and case == "wall_mixed":
				await _until(func() -> bool: return foes.all(func(f: Foe) -> bool: return f.hits >= 3), 1.5)
				var pile: Vector3 = hero._void.dark_spot
				_check(foes.all(func(f: Foe) -> bool: return Vector2(f.global_position.x - pile.x, f.global_position.z - pile.z).length() < 1.2),
					"the leash drags all three into a pile at his feet (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
				_check(pile.z < 2.5, "the pile is at his feet (%.1f m)" % pile.z)
				_check(foes.all(func(f: Foe) -> bool: return ve.marked(f, "molten")), "the seam leaves them molten")
				_check(foes.all(func(f: Foe) -> bool: return f.has_meta("x_bound")), "and bound")
				_check(LEASH.seams(hero).size() == 3, "three seams to run (%d)" % LEASH.seams(hero).size())
			await create_timer(2.2).timeout  # (the binds burn out: Black Tide's 1.8 s, the leash's 1.6 s)
			await _settle()
			var sum := 0.0
			for f: Foe in foes:
				sum += 500.0 - f.hp
			dealt[case + "_" + id] = sum
			for f: Foe in foes:
				f.free()
			game_end_slowmo()
			await _settle()
	for case: String in cases:
		print("  %s: Lava Leash %.0f / Galvanize %.0f / Black Tide %.0f" % [case, dealt[case + "_XL"], dealt[case + "_XC"], dealt[case + "_VD"]])
	_check(dealt.wall_mixed_XL > dealt.wall_mixed_XC * 1.3 and dealt.wall_mixed_XL > dealt.wall_mixed_VD * 1.3,
		"mixed ranges by a wall: Lava Leash wins (%.0f vs %.0f / %.0f)" % [dealt.wall_mixed_XL, dealt.wall_mixed_XC, dealt.wall_mixed_VD])
	_check(dealt.spread_round_XC > dealt.spread_round_XL * 1.15 and dealt.spread_round_XC > dealt.spread_round_VD,
		"a spread crowd round him: Galvanize wins (%.0f vs %.0f / %.0f)" % [dealt.spread_round_XC, dealt.spread_round_XL, dealt.spread_round_VD])
	_check(dealt.marked_far_VD > dealt.marked_far_XL * 1.5 and dealt.marked_far_VD > dealt.marked_far_XC,
		"marked foes far off all round: Black Tide wins (%.0f vs %.0f / %.0f)" % [dealt.marked_far_VD, dealt.marked_far_XL, dealt.marked_far_XC])
	# The drag pays by the metre, and more off a wall; the eruption more the bigger the pile.
	_check(ve.leash_drag_damage(10.0, false) > ve.leash_drag_damage(3.0, false) * 3.0, "a far drag hits harder than a near one")
	_check(ve.leash_drag_damage(8.0, true) > ve.leash_drag_damage(8.0, false) * 1.5, "torn off a wall harder still")
	_check(ve.leash_erupt_damage(4) > ve.leash_erupt_damage(1) * 1.5, "a bigger pile erupts harder")
	# Hellseam: the pile into the floor, harder the further each was dragged; then the seams go up and catch whoever
	# stands on one.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var near := _foe(Vector3(0.3, 0, 1.7))
	var far := _foe(Vector3(-0.3, 0, 1.7))
	near.set_meta(ve.LEASH_META, 1.0)
	far.set_meta(ve.LEASH_META, 10.0)
	var on_seam := _foe(Vector3(0, 0, 7.0))
	var off := _foe(Vector3(6, 0, 4))
	var g: Node3D = LEASH.start(hero, [], Vector3(0, 0, 1.7))
	g.grabs = [{"foe": far, "latched": true, "metres": 10.0, "from": Vector3(0, 0, 11.7), "to": Vector3(0, 0, 1.7), "arrived": true,
		"heavy": false, "seam": [], "t0": 0.0, "reach": 0.0, "tendril": load("res://scripts/void_tendril.gd").new()}]
	g.add_child(g.grabs[0].tendril)
	hero._void.dark_spot = Vector3(0, 0, 1.7)
	ve.breaker_impact(hero, ve.entry("XL"), Vector3(0, 0, 0.5), [], 1.0)
	_check(near.last_kb.y < 0.0 and far.last_kb.y < 0.0, "Hellseam drives the pile into the floor")
	_check(500.0 - far.hp > (500.0 - near.hp) * 1.25, "the one dragged furthest hardest (%.0f vs %.0f)" % [500.0 - far.hp, 500.0 - near.hp])
	_check(on_seam.hits == 0, "the seam hasn't gone up on the landing frame")
	await create_timer(0.6).timeout
	_check(on_seam.hits == 1 and on_seam.hp < 500.0, "then it runs out along the seam and catches the one on it (%.0f)" % (500.0 - on_seam.hp))
	_check(off.hits == 0, "and nobody off it")
	for f: Foe in [near, far, on_seam, off]:
		f.free()
	g.queue_free()
	await _settle()


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
