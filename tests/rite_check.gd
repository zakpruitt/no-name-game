extends SceneTree
## Checks the Ascended heavies (scripts/element_rite.gd) on real enemies for
## each element: a heavy primes (earth wells up lava, wind charges and water
## soaks the foes it hits), the next heavy sets them off (wells erupt and
## launch, charged foes are zapped, soaked foes freeze and the heavy's own
## blows shatter them), and a heavy before
## an Ascendancy does nothing. Prints `[rite] PASS` or `[rite] FAIL ...`.
## Works headless: godot --headless --path . -s tests/rite_check.gd

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.skip_title = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main._queue.clear()
	var p: Node3D = main.player
	p.bot_enabled = true  # no real input
	var home: Vector3 = p.global_position

	# Spirit (no Ascendancy): heavies lay nothing down.
	var foes: Array = await _foes(main, p, home)
	await _heavy(p, "H")
	_check(main.get_tree().get_nodes_in_group("lava_wells").is_empty(), "spirit H wells no lava")
	_check(foes.all(func(e: Node) -> bool: return e.get_node_or_null("RiteMark") == null), "spirit H marks no foe")

	for el: String in ["earth", "wind", "water"]:
		p.ascend(el)
		foes = await _foes(main, p, home)
		var rites: int = p.rites
		await _heavy(p, "H")
		if el == "earth":
			var wells: Array = main.get_tree().get_nodes_in_group("lava_wells")
			_check(wells.size() == 3, "earth H wells 3 lava (%d)" % wells.size())
		else:
			_check(foes.all(func(e: Node) -> bool: return e.get_node_or_null("RiteMark") != null), "%s H marks every foe it hits" % el)
		_check(p.rites == rites, "%s first heavy sets nothing off" % el)
		var hp: Array = foes.map(func(e: Node) -> float: return e.hp)
		await _heavy(p, "H")
		await create_timer(0.5).timeout
		_check(p.rites == rites + 1, "%s second heavy sets it off" % el)
		var hurt := 0
		for i in foes.size():
			if foes[i].hp < hp[i] - p.MOVES.H.damage * p.MOVES.H.hits.size():
				hurt += 1
		_check(hurt == foes.size(), "%s set-off hits every foe beyond the spin (%d/%d)" % [el, hurt, foes.size()])
		if el == "water":
			_check(foes.all(func(e: Node) -> bool: return e._ice != null), "water set-off freezes the soaked")
		if el == "earth":
			_check(main.get_tree().get_nodes_in_group("lava_wells").size() >= 1, "earth: the second spin's own wells wait (%d)" % main.get_tree().get_nodes_in_group("lava_wells").size())
		for w in main.get_tree().get_nodes_in_group("lava_wells"):
			w.drain()

	print("[rite] PASS" if _fails.is_empty() else "[rite] FAIL " + "; ".join(_fails))
	quit()


## Plays heavy `id` to the end.
func _heavy(p: Node3D, id: String) -> void:
	p._set_state(p.State.MOVE)
	p._start_attack(id)
	await create_timer(1.3).timeout


## Three sturdy, harmless minions round the hero inside the spin's reach.
func _foes(main: Node, p: Node3D, home: Vector3) -> Array:
	for old in main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	p.global_position = home
	var out := []
	for i in 3:
		var ang := TAU * i / 3.0
		var e: Node = main._spawn("minion", false, home + Vector3(sin(ang), 0.0, cos(ang)) * 2.0)
		e.max_hp = 2000.0
		e.hp = 2000.0
		out.append(e)
	await create_timer(1.1).timeout
	for e in out:
		e.move_speed = 0.0
		e.attack_damage = 0.0
	return out


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[rite] fail: ", what)
