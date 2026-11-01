extends SceneTree
## Checks the element casts and the Awakened ultimates for every element
## (spirit, wind, earth, water) on a real enemy: L H H / Dash L H / L L L H
## route to SKY / RUSH / AF, each ultimate damages, the chain count grows, and
## landing all three calls the Trinity. Prints `[ult] PASS` or `[ult] FAIL ...`.
## Works headless: godot --headless --path . -s tests/ult_check.gd

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

	# Routing: Awakened heavy after LH / DL / L3.
	p._set_awakened(true)
	p.state = p.State.ATTACK
	for pair: Array in [["LH", "SKY"], ["DL", "RUSH"], ["L3", "AF"]]:
		p._move_id = pair[0]
		_check(p._next_move("heavy") == pair[1], "%s + H -> %s" % pair)
	p._set_awakened(false)
	p.state = p.State.MOVE
	p._move_id = "LH"
	p.state = p.State.ATTACK
	_check(p._next_move("heavy") == "LHH", "LH + H is Spike when not Awakened")
	p.state = p.State.MOVE

	for el: String in ["spirit", "wind", "earth", "water"]:
		if el != "spirit":
			p.ascend(el)
		_check(p.element() == el, "element is " + el)
		# Cast: a light's bolt flies ahead and hits.
		p.global_position = home
		var e: Node = await _fresh(main, p.global_position + Vector3(0.0, 0.0, 4.5))
		var hp: float = e.hp
		var casts: int = p.ELEMENTS.casts
		p._start_attack("L1")
		await create_timer(0.8).timeout
		_check(p.ELEMENTS.casts > casts, "%s L1 casts" % el)
		_check(e.hp < hp, "%s bolt hits at 4.5m (%s -> %s)" % [el, hp, e.hp])
		# The three ultimates in one Awakening.
		p._set_awakened(true)
		var impacts: int = p.ult_impacts
		var trin: int = p.trinities
		for id: String in ["SKY", "RUSH", "AF"]:
			p.global_position = home  # room to charge, away from walls
			e = await _fresh(main, p.global_position + p.facing_dir() * 3.0)
			hp = e.hp
			p._set_state(p.State.MOVE)
			p._start_attack(id)
			_check(p.state == (p.State.ULT if id != "AF" else p.State.ATTACK), "%s %s starts" % [el, id])
			await create_timer(1.3).timeout
			_check(not is_instance_valid(e) or e.hp < hp, "%s %s damages (%s -> %s)" % [el, id, hp, e.hp if is_instance_valid(e) else 0.0])
			_check(p.state == p.State.MOVE, "%s %s returns control" % [el, id])
			_check(is_zero_approx(p.model.position.y), "%s %s lands" % [el, id])
		_check(p._ult_chain == 3, "%s chain reaches 3 (%d)" % [el, p._ult_chain])
		_check(p.ult_impacts == impacts + 2, "%s SKY and RUSH impact" % el)
		await create_timer(0.6).timeout
		_check(p.trinities == trin + 1, "%s Trinity after all three" % el)
		p._set_awakened(false)

	print("[ult] PASS" if _fails.is_empty() else "[ult] FAIL " + "; ".join(_fails))
	quit()


## A sturdy minion at `at`, past its spawn animation, standing still and harmless.
func _fresh(main: Node, at: Vector3) -> Node:
	for old in main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var e: Node = main._spawn("minion", false, Vector3(at.x, 0.0, at.z))
	e.max_hp = 2000.0
	e.hp = 2000.0
	await create_timer(1.1).timeout
	e.move_speed = 0.0
	e.attack_damage = 0.0
	return e


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[ult] fail: ", what)
