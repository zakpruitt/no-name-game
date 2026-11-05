extends SceneTree
## Round 33 (FX sleek, round 2) logic, headless, PASS/FAIL:
##   - a breaker landing's hits on several foes make one damage number with their total (comic_number.gd);
##     the same hits outside a breaker make one number per foe;
##   - standing effects (a comic crack, a dark pool, the frost spear's frost) born before a string are
##     cleared on its first hit, and ones born after it started stay (standing_fx.gd).
## Run: godot --headless --path . -s tests/fx_sleek_check.gd

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: CharacterBody3D = main.player
	p.set_physics_process(false)
	p.set_process(false)
	var num: GDScript = load("res://scripts/comic_number.gd")
	var foes := get_nodes_in_group("enemies").slice(0, 4)
	_ok(foes.size() >= 3, "dummies to hit (%d)" % foes.size())
	# Outside a breaker: one number per foe.
	p.state = p.State.MOVE
	var plain := {}
	for e: Node3D in foes:
		plain[num.add(main, e.global_position, 10.0, false, e)] = true
	_ok(plain.size() == foes.size(), "a number per foe outside a breaker (%d for %d)" % [plain.size(), foes.size()])
	await create_timer(1.0).timeout
	# A breaker landing: one total.
	p.state = p.State.LEAP
	var brk := {}
	var last: Node3D
	for e: Node3D in foes:
		last = num.add(main, e.global_position, 12.0, true, e)
		brk[last] = true
	p.state = p.State.MOVE
	await create_timer(0.1).timeout
	last = num.add(main, foes[0].global_position, 5.0, false, foes[0])  # a beat later (a thrown cube)
	brk[last] = true
	_ok(brk.size() == 1, "one number for a breaker's hits (%d)" % brk.size())
	_ok(is_equal_approx(last.total, 12.0 * foes.size() + 5.0), "breaker total %s" % last.total)
	await create_timer(1.2).timeout
	var after: Node3D = num.add(main, foes[0].global_position, 3.0, false, foes[0])
	_ok(after != last and is_equal_approx(after.total, 3.0), "the breaker total stops taking hits")
	# Standing effects.
	var standing: GDScript = load("res://scripts/standing_fx.gd")
	var crack: Node3D = load("res://scripts/comic_crack.gd").spawn(main, Vector3(3, 0, 3), Color.ORANGE, 1.5, 0.9)
	var pool: Node3D = load("res://scripts/dark_fx.gd").pool(main, Vector3(-3, 0, 3), 2.0, 5.0)
	var spear: Node3D = load("res://scripts/frost_spear.gd").plant(main, Vector3(0, 0, 5))
	await create_timer(0.1).timeout
	p._chain_i = 0
	p.state = p.State.MOVE
	p._hits_done = 0
	standing.watch(p)
	p.state = p.State.ATTACK
	p._chain_i = 1
	standing.watch(p)  # a string started
	await create_timer(0.05).timeout
	var own: Node3D = load("res://scripts/comic_crack.gd").spawn(main, Vector3(5, 0, 3), Color.ORANGE, 1.5, 0.9)
	standing.watch(p)
	_ok(crack.is_in_group(standing.GROUP), "nothing cleared before the first hit")
	p._hits_done = 1
	standing.watch(p)  # its first hit
	_ok(not crack.is_in_group(standing.GROUP) and not pool.is_in_group(standing.GROUP) and not spear.is_in_group(standing.GROUP),
		"crack, pool and frost cleared on the first hit")
	_ok(own.is_in_group(standing.GROUP), "an effect the string made itself stays")
	_ok(spear._cleared and spear.is_in_group(spear.GROUP), "the spear itself stays for the breaker")
	await create_timer(0.4).timeout
	_ok(not is_instance_valid(crack), "the old crack is gone")
	_ok(not is_instance_valid(pool), "the pool is gone")
	_ok(is_instance_valid(own), "the string's own crack is still up")
	print("[fx_sleek] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	quit()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
