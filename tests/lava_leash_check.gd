extends SceneTree
## Lava Leash (L L L H L, the dark x magma crossover, round 49) and Hellseam, headless: the routing, the pile, each of
## Lava Leash / Galvanize / Black Tide winning its own situation, the damage helpers and Hellseam's crater and seams.
## Runs the real comic hero against stand-in foes (void_arm_check's harness; split out so neither runs past
## agent.sh's 180 s a test). Round 53's brazier spill (env_flourish.gd): the seam tips a lit brazier in (the coals run
## on, the molten patch), magma lights an out one, Hellseam erupts from the spill. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/lava_leash_check.gd

var fails := 0
var world: Node3D
var hero: CharacterBody3D


class Foe extends CharacterBody3D:
	var radius := 0.5
	var hp := 500.0
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
	await _brazier_spill()
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


## Round 53, brazier spill: Lava Leash drags a foe 10 m out back past a lit brazier 1.6 m off its line: the seam tips
## it (the spilled model, facing the seam), the coals' patch leaves a foe in it molten, and Hellseam pays x
## SPILL_HELLSEAM on the pile and erupts at the coals' end too. Magma by an out brazier lights it.
func _brazier_spill() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	var EP: GDScript = load("res://scripts/env_piece.gd")
	var FL: GDScript = load("res://scripts/env_flourish.gd")
	var LEASH: GDScript = load("res://scripts/lava_leash.gd")
	Kit.set_on("brazier_spill", true)
	# an out one lights from magma by it
	var cold: Node3D = EP.place(world, "brazier", Vector3(-6, 0, -6), 0.0, "out")
	_check(EP.state(cold) == "out", "a brazier placed out is out")
	var ash: Node3D = cold.find_child("brazier_ash", true, false)
	var flame: Node3D = cold.find_child("brazier_flame", true, false)
	_check(ash == null or ash.visible, "it shows its ash")
	var warm := _foe(Vector3(-6, 0, -4.9))
	ve.mark(warm, "molten")
	_check(EP.state(cold) == "lit" and (flame == null or flame.visible), "magma by it lights it")
	warm.free()
	cold.free()
	# the seam tips a lit one
	hero.global_position = Vector3.ZERO
	hero.model.position.y = 0.0
	hero._face(Vector3(0, 0, 1))
	var env: Node = load("res://scripts/env_target.gd").new()  # (the room's structure list: the bracket's)
	world.add_child(env)
	env.hero = hero  # (no main here: its player)
	await physics_frame
	var b: Node3D = EP.place(world, "brazier", Vector3(1.6, 0, 6.0))
	_check(EP.state(b) == "lit", "a brazier is placed lit")
	var b_id := str(b.get_meta(EP.ID_META, "?"))  # (used up when it spills: out of the structure list)
	var spilled: int = int(EP.verbs.get("brazier_spill", 0))
	var foes := [_foe(Vector3(0, 0, 10)), _foe(Vector3(-1.2, 0, 3.5))]
	for f: Foe in foes:
		f.set_meta(ve.PALM_META, Time.get_ticks_msec())
	await physics_frame
	hero._start_attack("XL")
	var bracket := ""
	for i in 180:
		await physics_frame
		if hero.has_meta(&"env_pick") and str((hero.get_meta(&"env_pick") as Dictionary).get("ctx", "")) == "brazier":
			bracket = str((hero.get_meta(&"env_pick") as Dictionary).get("id", ""))
		if EP.state(b) == "spilled":
			break
	_check(bracket != "" and bracket == b_id, "the indicator brackets the brazier while the leash reaches (%s)" % bracket)
	_check(EP.state(b) == "spilled" and int(EP.verbs.get("brazier_spill", 0)) == spilled + 1, "the leash's seam tips the brazier in")
	var sp: Node3D = b.get_node_or_null(FL.SPILL_NAME)
	_check(sp != null and sp.visible, "the spilled brazier's model")
	if sp != null:
		var face := sp.global_transform.basis.z
		_check(face.x < -0.8, "its coals toward the seam (%s)" % str(face))
	var seam: Array = b.get_meta(&"spill_seam", [])
	_check(seam.size() == 2 and (seam[0] as Vector3).distance_to(b.global_position) > FL.SPILL_EXTEND, "the coals run the seam on %.0f m" % FL.SPILL_EXTEND)
	await _until(func() -> bool: return foes.all(func(f: Foe) -> bool: return f.hits >= 3), 1.5)
	var in_patch := _foe(Vector3(0.6, 0, 6.0))
	await create_timer(0.7).timeout
	_check(ve.marked(in_patch, "molten"), "a foe in the coals' patch is left molten")
	await create_timer(2.2).timeout
	await _settle()
	for f: Foe in foes + [in_patch]:
		f.free()
	game_end_slowmo()
	await _settle()
	# Hellseam with the spill fresh, then with none: the pile's hit and a foe at the coals' end
	b.set_meta(&"spill_seam", [Vector3(8, 0, -4), Vector3(6, 0, -4)])  # (off his aim: Hellseam's own seams go nowhere near)
	var with: Array = await _hellseam_by(Vector3(8, 0, -4))
	b.set_meta(&"spill_ms", -100000)  # (stale: no spill to erupt from)
	var without: Array = await _hellseam_by(Vector3(8, 0, -4))
	print("  brazier spill: Hellseam pile hit %.0f with a fresh spill, %.0f without; the coals' end %.0f / %.0f" % [with[0], without[0], with[1], without[1]])
	_check(absf(with[0] / maxf(without[0], 0.01) - FL.SPILL_HELLSEAM) < 0.05, "Hellseam pays x%.2f with a spill" % FL.SPILL_HELLSEAM)
	_check(with[1] > 0.0 and without[1] == 0.0, "and erupts at the coals' end")
	b.free()
	Kit.set_on("brazier_spill", false)


## The Hellseam landing by hand (as _lava_leash's): [the pile foe's damage, a foe at `end`'s damage after the seams go up].
func _hellseam_by(end: Vector3) -> Array:
	var ve: GDScript = load("res://scripts/void_element.gd")
	var LEASH: GDScript = load("res://scripts/lava_leash.gd")
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var pile := _foe(Vector3(0.3, 0, 1.7))
	pile.set_meta(ve.LEASH_META, 4.0)
	var at_end := _foe(Vector3(end.x, 0, end.z))
	var g: Node3D = LEASH.start(hero, [], Vector3(0, 0, 1.7))
	hero._void.dark_spot = Vector3(0, 0, 1.7)
	ve.breaker_impact(hero, ve.entry("XL"), Vector3(0, 0, 0.5), [], 1.0)
	var hit := 500.0 - pile.hp
	await create_timer(0.8).timeout
	var out := [hit, 500.0 - at_end.hp]
	pile.free()
	at_end.free()
	if is_instance_valid(g):
		g.queue_free()
	await _settle()
	return out


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
