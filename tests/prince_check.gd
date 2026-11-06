extends SceneTree
## The dragon prince's first slice (docs/characters/dragon-prince.md, scripts/prince/): without the flag the
## training room still spawns the heretic; with Game.hero = "prince" it spawns him, and on the dummies L L H
## throws Sunbrand (in hand -> flight -> planted, the bite lands), H smashes it (planted -> shattered, the blast
## lands), the new sword forms REFORM_TIME later (shattered -> in hand), H alone breathes fire on a dummy, and
## hold L calls a thrown sword back. Also checks the routing table. Prints [prince] PASS/FAIL.
## Run: godot --headless --path . -s tests/prince_check.gd

var _fails: Array[String] = []
var _damage := 0.0
var _game: Node


func _initialize() -> void:
	await process_frame
	_game = get_root().get_node("Game")
	_game.save_hints = false
	_check(_game.hero == "heretic", "the heretic plays without the flag (Game.hero %s)" % _game.hero)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.5).timeout
	_check(not main.player.has_method("is_prince") and main.player.get_script().resource_path.ends_with("/player.gd"),
		"main spawns player.gd by default")
	main.queue_free()
	await create_timer(0.3).timeout

	_routing()

	_game.hero = "prince"
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	var p: Node = main.player
	_check(p.has_method("is_prince") and p.sword != null, "--hero=prince spawns the prince, with his sword")
	if not p.has_method("is_prince") or p.sword == null:
		_finish()
		return
	for d: Node in main._dummies:
		d.hit_taken.connect(func(dmg: float) -> void: _damage += dmg)
	p.bot_enabled = true
	p.bot_move = Vector3.ZERO
	var sw: Node = p.sword
	var S: Dictionary = sw.S
	_check(sw.state == S.HELD and sw.state_word() == "hand", "starts with the sword in hand")

	# L L H: Javelin, at the front left dummy.
	var before := _damage
	_face(p, main._dummies[0])
	await _string(p, ["light", "light", "heavy"])
	_check(p.move_log.slice(-3) == ["P_SLASH", "P_RIPOSTE", "P_JAVELIN"], "L L H is Slash, Riposte, Javelin (%s)" % [p.move_log])
	var saw_flight := false
	for i in 120:
		if sw.state == S.FLIGHT:
			saw_flight = true
		if sw.state == S.PLANTED:
			break
		await physics_frame
	_check(saw_flight and sw.state == S.PLANTED, "the thrown sword flies, then plants (state %d)" % sw.state)
	_check(sw.bites >= 1 and sw.host != null, "the Javelin bit a dummy and stuck in it (bites %d)" % sw.bites)
	_check(_damage > before, "the throw's damage landed (%.1f)" % (_damage - before))
	_check(sw.state_word() == "out" and not p.hand_sword.visible and sw._mesh.visible, "out: the hand is empty, the sword shows in the world")
	await _idle(p)

	# H with the sword out: the smash.
	before = _damage
	_check(p.next_move("heavy") == "P_SMASH", "H with the sword out is the smash (%s)" % p.next_move("heavy"))
	_press(p, "heavy")
	var rose := 0.0
	var blast_ms := 0
	for i in 120:
		rose = maxf(rose, p.model.position.y)
		if sw.state == S.SHATTERED:
			blast_ms = Time.get_ticks_msec()
			break
		await physics_frame
	_check(p.smashes == 1 and rose >= p.SMASH_HEIGHT * 0.9, "he flies up for the smash (%.2f m)" % rose)
	_check(sw.state == S.SHATTERED and sw.blasts == 1, "the smash shatters the sword (state %d)" % sw.state)
	_check(sw.last_blast_hits >= 1 and _damage > before, "the blast hit %d dummies for %.1f" % [sw.last_blast_hits, _damage - before])
	_check(sw.state_word() == "shattered", "shattered between the blast and the new sword")
	for i in 120:
		if sw.state == S.HELD:
			break
		await physics_frame
	var formed_ms := Time.get_ticks_msec() - blast_ms
	_check(sw.state == S.HELD and p.reforms == 1, "a new sword forms in his hand (state %d)" % sw.state)
	# (the blast's hitstop stretches the wall clock a little past REFORM_TIME)
	_check(formed_ms >= sw.REFORM_TIME * 1000.0 - 40 and formed_ms <= sw.REFORM_TIME * 1000.0 + 450,
		"it forms %d ms after the blast (REFORM_TIME %.0f)" % [formed_ms, sw.REFORM_TIME * 1000.0])
	await _idle(p)

	# H alone: Dragon Breath, on the nearest dummy.
	var near: Node3D = _nearest(main, p)
	p.global_position = near.global_position + Vector3(0, 0, 2.2)
	await create_timer(0.1).timeout
	_face(p, near)
	before = _damage
	var breath_hits: int = p.breath_hits
	_press(p, "heavy")
	await create_timer(0.7).timeout
	_check(p.move_log[-1] == "P_BREATH" and p.breaths >= 1, "H with nothing set up breathes fire (%s)" % p.move_log[-1])
	_check(p.breath_hits > breath_hits and _damage > before, "the breath hit (%d foes, %.1f)" % [p.breath_hits - breath_hits, _damage - before])
	await _idle(p)

	# L L H again, then hold L: Rightful Return.
	_face(p, _nearest(main, p))
	await _string(p, ["light", "light", "heavy"])
	for i in 120:
		if sw.state == S.PLANTED:
			break
		await physics_frame
	_check(sw.state == S.PLANTED, "thrown again")
	await _idle(p)
	p.bot_hold_light = true
	_press(p, "light")
	var saw_return := false
	for i in 90:
		if sw.state == S.RETURN:
			saw_return = true
		if sw.state == S.HELD:
			break
		await physics_frame
	p.bot_hold_light = false
	_check(saw_return and sw.state == S.HELD and p.recalls == 1, "hold L calls the sword back to his hand (state %d)" % sw.state)
	# The pause menu's MOVES panel lists his moves, not the heretic's.
	var pause: Node = main.get_children().filter(func(n: Node) -> bool: return n.has_method("_build_moves"))[0]
	pause._open()
	await create_timer(0.3).timeout
	var texts: Array = pause.moves_panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text) if pause.moves_panel != null else []
	_check(texts.any(func(t: String) -> bool: return t.begins_with("Skyfall")) and not texts.any(func(t: String) -> bool: return t.begins_with("Grounded")),
		"the MOVES panel lists his moves (%d labels)" % texts.size())
	_finish()


func _routing() -> void:
	var r = load("res://scripts/prince/prince_moves.gd")
	_check(r.route("light", "", false, 0, "hand", false) == "P_SLASH", "L in hand: Slash")
	_check(r.route("heavy", "", false, 0, "hand", false) == "P_BREATH", "H in hand, no string: breath")
	_check(r.route("heavy", "P_SLASH", true, 1, "hand", false) == "P_FLICK", "L H: Ember Flick")
	_check(r.route("heavy", "P_RIPOSTE", true, 2, "hand", false) == "P_JAVELIN", "L L H: Javelin")
	_check(r.route("heavy", "", false, 0, "out", true) == "P_SMASH", "H out, in reach: smash")
	_check(r.route("heavy", "", false, 0, "out", false) == "P_BREATH", "H out, too far: breath")
	_check(r.route("heavy", "", false, 0, "shattered", false) == "P_BREATH", "H shattered: breath")
	_check(r.route("light", "", false, 0, "out", true) == "P_TALON1", "L out: Talon")


func _press(p: Node, kind: String) -> void:
	p._buffered = kind
	p._buffer_t = p.input_buffer


## Presses each, waiting for the last to start before the next.
func _string(p: Node, kinds: Array) -> void:
	for k: String in kinds:
		var n: int = p.move_log.size()
		_press(p, k)
		for i in 60:
			if p.move_log.size() > n:
				break
			await physics_frame
		await create_timer(0.18).timeout


func _idle(p: Node) -> void:
	for i in 180:
		if p.state == p.State.MOVE and p._chain_i == 0:
			break
		await physics_frame
	await create_timer(0.1).timeout


func _face(p: Node, at: Node3D) -> void:
	var to: Vector3 = at.global_position - p.global_position
	p._face(Vector3(to.x, 0.0, to.z))
	p.model.rotation.y = p._facing_yaw


func _nearest(main: Node, p: Node3D) -> Node3D:
	var best: Node3D = main._dummies[0]
	for d: Node3D in main._dummies:
		if d.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
			best = d
	return best


func _finish() -> void:
	print("[prince] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	_game.hero = "heretic"
	_game.stop_all_sfx()
	quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[prince] ", "ok   " if ok else "FAIL ", what)
