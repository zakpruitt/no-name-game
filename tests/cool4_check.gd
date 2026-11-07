extends SceneTree
## Round 55 cool pass 4 (docs/features/combo-breakers.md "Round 55 cool pass 4"), headless: the rebuilt mids do their
## beat and their picks change the outcome. Frost Spear plants at the nearest group, not along his facing; Rockslide's
## gale drags the airborne in under the boulder and buries them; Deep Freeze's wave runs from the first block and carries
## past the frost's edge from the side picked; Meltdown lights only the blocks round the one the hammer hit; Overwhelm
## slams the pinned one and drags the rest onto it; Black Tide's tentacles haul each in and knock the pile; Dash Stab's
## lash reels the straggler in; Maw's heap knocks at the top, then slams. cool3_check's harness. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/cool4_check.gd

var fails := 0
var world: Node3D
var hero: CharacterBody3D
var ve: GDScript
var env: Node3D


class Foe extends CharacterBody3D:
	var radius := 0.5
	var hp := 500.0
	var elite := false
	var hits := 0
	var frozen := false
	var frozen_t := 0.0
	var up := false
	var chill_t := 0.0
	func chill(t: float, _m: float) -> void: chill_t = t
	func freeze(t: float, _m: float) -> void:
		frozen = true
		frozen_t = t
	func is_alive() -> bool: return hp > 0.0
	func is_airborne() -> bool: return up or global_position.y > 0.3
	func stagger(_t: float) -> void: pass
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, _big = false, _x = null) -> void:
		hp -= d
		hits += 1


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
	env = load("res://scripts/env_target.gd").new()
	world.add_child(env)
	await process_frame
	await _settle()
	ve = load("res://scripts/void_element.gd")
	hero.bot_enabled = true
	await _spear()
	await _rockslide()
	await _deep_freeze()
	await _flush_wave()
	await _meltdown()
	await _overwhelm()
	await _black_tide()
	await _dash_stab()
	await _maw()
	env.free()
	print("cool4_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _home() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))


## Frost Spear: he faces +Z, the group stands off to his side (+X). The spear goes in by the group.
func _spear() -> void:
	_home()
	var foes: Array = [_foe(Vector3(5.0, 0, 0.5)), _foe(Vector3(5.8, 0, -0.6)), _foe(Vector3(4.6, 0, -1.2))]
	await _settle()
	_home()
	ve.fire(hero, "IP", Vector3(0, 0, 1))
	var s: Node3D = ve.SPEAR.current(hero.get_tree())
	_check(s != null and s.global_position.x > 3.0, "Frost Spear plants at the group off his facing (%s)" % (str(s.global_position) if s != null else "none"))
	await create_timer(0.6).timeout
	_check(foes.all(func(f: Foe) -> bool: return f.chill_t > 0.0), "its frost lines reach all three")
	if s != null:
		s.melt()
	await _clear(foes)


## Rockslide: two in the air spread out round a third; the gale drags them in and the boulder buries them.
func _rockslide() -> void:
	_home()
	var a: Foe = _foe(Vector3(0, 0, 4.0))
	var b: Foe = _foe(Vector3(3.5, 1.8, 4.5))
	var c: Foe = _foe(Vector3(-3.2, 1.6, 3.6))
	b.up = true
	c.up = true
	await physics_frame
	_home()
	var n: int = ve.rockslides
	ve.fire(hero, "XR", Vector3(0, 0, 1))
	b.up = false
	c.up = false
	await create_timer(0.5).timeout
	_check(ve.rockslides > n, "Rockslide drops its boulder")
	_check(b.global_position.distance_to(Vector3(0, 0, 4)) < 2.0 and c.global_position.distance_to(Vector3(0, 0, 4)) < 2.0,
		"the gale drags the airborne in under it (%s, %s)" % [b.global_position, c.global_position])
	_check(b in hero._void.buried and c in hero._void.buried and not a in hero._void.buried, "those the gale brought down are buried, the grounded one is not")
	_check(500.0 - b.hp > (500.0 - a.hp) * 1.5, "the airborne take the double (%.0f vs %.0f)" % [500.0 - b.hp, 500.0 - a.hp])
	await _clear([a, b, c])


## Deep Freeze: a crowd by the spear and one out past the frost's edge on the +X side. Picking the +X edge first runs the
## wave out to the straggler; picking the -X edge it runs the other way and stops at the frost's edge.
func _deep_freeze() -> void:
	var reached := {}
	for side: String in ["near", "far"]:
		_home()
		var spear: Node3D = ve.SPEAR.plant(world, Vector3(0, 0, 3.0))
		var foes: Array = [_foe(Vector3(-4.0, 0, 3.0)), _foe(Vector3(0, 0, 3.6)), _foe(Vector3(4.5, 0, 3.0)), _foe(Vector3(7.4, 0, 3.0))]
		await physics_frame
		var pick: Foe = foes[2] if side == "near" else foes[0]
		hero.set_meta(env.PICK_META, {"ctx": "deep_freeze", "id": "foe%d" % pick.get_instance_id(), "chosen": true, "ms": Time.get_ticks_msec()})
		var order: Array = ve.deep_freeze_order(hero, Vector3(0, 0, 3.0))
		_check(not order.is_empty() and order[0][0] == pick, "%s: the wave starts on the picked block" % side)
		var hp0: Array = foes.map(func(f: Foe) -> float: return f.hp)
		ve._deep_freeze(hero, Vector3.ZERO, 16.0)
		await create_timer(0.1).timeout
		var early: int = foes.filter(func(f: Foe) -> bool: return f.frozen).size()
		await create_timer(0.6).timeout
		reached[side] = foes[3].frozen
		_check(early < foes.filter(func(f: Foe) -> bool: return f.frozen).size(), "%s: the blocks pop one after another (%d then more)" % [side, early])
		_check(hp0[foes.find(pick)] - pick.hp > hp0[1] - foes[1].hp, "%s: the first block takes the most" % side)
		hero.remove_meta(env.PICK_META)
		if is_instance_valid(spear):
			spear.queue_free()
		await _clear(foes)
	_check(reached.near and not reached.far, "the wave reaches the straggler only from its side (near %s, far %s)" % [reached.near, reached.far])


## Round 56 (feel-audit6): Avalanche's hold flushes the blocks still to pop as a fast wave, not on one frame: the hold
## gets them back to take, and they freeze over the next frames, all of them within 0.25 s.
func _flush_wave() -> void:
	_home()
	var spear: Node3D = ve.SPEAR.plant(world, Vector3(0, 0, 3.0))
	var foes: Array = [_foe(Vector3(-1.5, 0, 3.0)), _foe(Vector3(0, 0, 3.6)), _foe(Vector3(1.5, 0, 3.0)), _foe(Vector3(0.4, 0, 2.2))]
	await physics_frame
	ve._deep_freeze(hero, Vector3.ZERO, 16.0)
	var first: int = foes.filter(func(f: Foe) -> bool: return f.frozen).size()
	var wave: Variant = ve.deep_freeze_flush()
	var now_frozen: int = foes.filter(func(f: Foe) -> bool: return f.frozen).size()
	_check(wave is Array and (wave as Array).size() == foes.size() - first, "the flush hands the hold the blocks still to pop (%s)" % str(wave.size() if wave is Array else wave))
	_check(now_frozen == first, "none of them pops on the flush's own frame (%d frozen of %d)" % [now_frozen, foes.size()])
	var frames := {}
	var t := 0.0
	while t < 0.3:
		await physics_frame
		t += 1.0 / 60.0
		var n: int = foes.filter(func(f: Foe) -> bool: return f.frozen).size()
		frames[n] = true
	_check(foes.all(func(f: Foe) -> bool: return f.frozen), "all of them pop within 0.3 s")
	_check(frames.size() >= 3, "on at least three different frames (counts seen %s)" % str(frames.keys()))
	if is_instance_valid(spear):
		spear.queue_free()
	await _clear(foes)


## Meltdown: a bunch of three and one off on its own. Hit in the bunch, the three are molten and the loner not.
func _meltdown() -> void:
	_home()
	var foes: Array = [_foe(Vector3(0, 2.0, 2.0)), _foe(Vector3(1.0, 2.0, 2.4)), _foe(Vector3(-0.8, 2.0, 2.6)), _foe(Vector3(0, 2.0, -4.5))]
	for f: Foe in foes:
		f.up = true
	await physics_frame
	_home()
	var n: int = ve.melts
	ve.fire(hero, "XM", Vector3(0, 0, 1))
	await create_timer(0.6).timeout
	_check(ve.melts > n, "Meltdown's hammer hits its block")
	var lit: Array = foes.map(func(f: Foe) -> bool: return ve.marked(f, "molten"))
	_check(lit[0] and lit[1] and lit[2] and not lit[3], "the globs light the bunch, not the loner (%s)" % str(lit))
	await _clear(foes)


## Overwhelm: the picked one is slammed, the others in the pool dragged onto it.
func _overwhelm() -> void:
	_home()
	var foes: Array = [_foe(Vector3(0, 0, 4.0)), _foe(Vector3(2.6, 0, 4.8)), _foe(Vector3(-2.4, 0, 3.4))]
	await physics_frame
	_home()
	hero.set_meta(env.PICK_META, {"ctx": "overwhelm", "id": "foe%d" % foes[0].get_instance_id(), "chosen": true, "ms": Time.get_ticks_msec()})
	var n: int = ve.ow_pins
	var hp0: float = foes[0].hp
	ve.fire(hero, "OW", Vector3(0, 0, 1))
	var thin := INF
	var t := 0.0
	while t < 0.6:
		await physics_frame
		t += 1.0 / 60.0
		for p: Node3D in get_nodes_in_group("dark_pool"):
			if t > 0.2:
				thin = minf(thin, p.scale.x / ve.OVERWHELM_RADIUS)
	_check(thin < 0.8, "the pool draws in under the haul (x%.2f of its size)" % thin)
	_check(ve.ow_pins > n and hp0 - foes[0].hp >= ve.OW_SLAM_DAMAGE * 0.9, "Overwhelm slams the pinned one (%.0f)" % (hp0 - foes[0].hp))
	var spread: float = foes[1].global_position.distance_to(foes[0].global_position) + foes[2].global_position.distance_to(foes[0].global_position)
	_check(spread < 3.2, "the rest are dragged onto it (%.1f m)" % spread)
	# round 56 (feel-audit6): the pool drew in and thinned under the haul, and is back by now
	await create_timer(0.45).timeout
	var pools: Array = get_nodes_in_group("dark_pool")
	_check(not pools.is_empty() and pools.all(func(p: Node3D) -> bool: return p.scale.x > ve.OVERWHELM_RADIUS * 0.95), "the pool is whole again after the slam")
	hero.remove_meta(env.PICK_META)
	await create_timer(2.0).timeout
	await _clear(foes)


## Black Tide: three marked, spread out; each is hauled in and knocks the pile.
func _black_tide() -> void:
	_home()
	var foes: Array = [_foe(Vector3(-6, 0, 6)), _foe(Vector3(7, 0, 3)), _foe(Vector3(0, 0, 11))]
	for f: Foe in foes:
		ve.DARK.mark(f)
	await physics_frame
	_home()
	var k: int = ve.tide_knocks
	ve.fire(hero, "VD", Vector3(0, 0, 1))
	await create_timer(0.7).timeout
	_check(ve.tide_knocks - k == 3, "every one dragged in knocks the pile (%d)" % (ve.tide_knocks - k))
	_check(foes.all(func(f: Foe) -> bool: return f.global_position.distance_to(Vector3(0, 0, 4)) < 1.6), "the tide's tentacles haul them all into the pool")
	await create_timer(2.0).timeout
	await _clear(foes)


## Dash Stab's lash: one foe 6 m out on the line is cut, caught and reeled in to his spear.
func _dash_stab() -> void:
	_home()
	var far: Foe = _foe(Vector3(0, 0, 6.0))
	await physics_frame
	_home()
	var lash: Node3D = load("res://scripts/claw_lash.gd").new()
	lash.dir = Vector3(0, 0, 1)
	lash.hero = hero
	lash.damage = 6.0
	hero._move_id = "DL"
	var lash_gd: GDScript = load("res://scripts/claw_lash.gd")
	var c: int = lash_gd.catches
	world.add_child(lash)
	lash.global_position = Vector3(0, 0, 0.6)
	await create_timer(0.9).timeout
	hero._move_id = ""
	_check(lash_gd.catches > c, "the lash catches the far foe")
	_check(far.global_position.z < 3.0, "and reels it in to him (z %.1f)" % far.global_position.z)
	await _clear([far])


## Maw's heap: the knock at the top lands on each, then the slam.
func _maw() -> void:
	_home()
	var foes: Array = [_foe(Vector3(0, 0, 4.0)), _foe(Vector3(1.4, 0, 4.4)), _foe(Vector3(-1.2, 0, 4.6))]
	await physics_frame
	var k: int = ve.maw_knocks
	var g: Node3D = ve.maw_knock(hero, Vector3(0, 0, 4.5), foes, 40.0)
	await create_timer(1.0).timeout
	_check(ve.maw_knocks > k, "Maw's heap knocks at the top")
	_check(g == null or not is_instance_valid(g) or g.ended == 3, "then the heap is slammed down")
	await _clear(foes)


func _foe(at: Vector3) -> Foe:
	var f := Foe.new()
	world.add_child(f)
	f.global_position = at
	f.add_to_group("enemies")
	return f


func _clear(foes: Array) -> void:
	for f: Variant in foes:
		if is_instance_valid(f):
			f.queue_free()
	await _settle()


func _settle() -> void:
	var t := 0.0
	while hero.state != hero.State.MOVE and t < 3.0:
		await physics_frame
		t += 1.0 / 60.0
	for i in 30:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL: ", what)
