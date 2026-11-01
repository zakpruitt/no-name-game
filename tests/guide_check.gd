extends SceneTree
## Checks the combo guide against the real routing: from every move (resting
## and Awakened), each row's move is what that press starts, and each row's
## "next" combo is what one more press starts after it. Prints `[guide] PASS`
## or `[guide] FAIL ...`. Windowed it also renders the guide in six states to
## `user://guide_sheet.png`. godot --path . -s tests/guide_check.gd
## (headless works for the checks: godot --headless --path . -s tests/guide_check.gd)

const FROM := ["L1", "L2", "L3", "LPL", "H", "LH", "LHH", "LLH", "CH", "DL", "DH"]
const CROP := Vector2i(760, 300)

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.skip_title = true
	game.combo_guide = true  # (not saved)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main._queue.clear()
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p: Node3D = main.player
	p.bot_enabled = true
	var guide: Control = main.hud.combo_guide

	for awake: bool in [false, true]:
		p._set_awakened(awake)
		for from: String in FROM:
			_begin(p, from)
			var rows: Array = p.combo_options()
			_check(not rows.is_empty(), "%s%s shows rows" % [from, _tag(awake)])
			for row: Dictionary in rows:
				_begin(p, from)
				var want: String = "DL" if row.kind == "dash" else p._next_move(row.kind)
				_check(row.id == want, "%s%s %s -> %s (guide says %s)" % [from, _tag(awake), row.kind, want, row.id])
				if row.next.is_empty():
					continue
				_begin(p, from)
				if row.kind == "dash":
					p._set_state(p.State.MOVE)
					p._post_dash_t = 0.3
				p._start_attack(row.id)
				var after: String = p._next_move(row.next.kind)
				_check(after == row.next.id, "%s%s %s then %s -> %s (guide says %s)" % [from, _tag(awake), row.id, row.next.kind, after, row.next.id])
		# Out of a dash: light is the Dash Stab.
		p._set_state(p.State.MOVE)
		p._post_dash_t = 0.3
		var rows: Array = p.combo_options()
		_check(not rows.is_empty() and rows[0].id == "DL", "post-dash light -> DL" + _tag(awake))
		if awake:
			_check(rows[0].next.get("id", "") == "RUSH", "post-dash DL then heavy -> RUSH (Awakened)")
		# ...and heavy is Whirlwind.
		_check(rows.size() > 1 and rows[1].id == "DH" and p._next_move("heavy") == "DH", "post-dash heavy -> DH" + _tag(awake))
		# L2 finished, chain still live: the pause makes the third light Flurry.
		_begin(p, "L1")
		p._start_attack("L2")
		p._set_state(p.State.MOVE)
		p._chain_reset_t = 0.3
		rows = p.combo_options()
		_check(not rows.is_empty() and rows[0].id == "LPL" and p._next_move("light") == "LPL",
			"L L, pause, L -> Flurry" + _tag(awake))
		_begin(p, "L1")
		p._start_attack("L2")
		_check(p._next_move("light") == "L3", "L L L without the pause stays Triple Chop" + _tag(awake))
		rows = p.combo_options()
		_check(rows[0].get("pause", {}).get("id", "") == "LPL", "mid-L2 the light row hints the pause (Flurry)" + _tag(awake))
		_check(rows.slice(1).all(func(r: Dictionary) -> bool: return not r.has("pause")), "only the light row has a pause hint" + _tag(awake))
	p._set_awakened(false)
	# A combo landed GUIDE_LEARNED times is no longer hinted as the follow-up.
	_begin(p, "L1")
	_check(p.combo_options()[1].next.get("id", "") == "LHH", "L1's heavy row hints Spike")
	p.combos_landed["LHH"] = p.GUIDE_LEARNED
	_begin(p, "L1")
	_check(p.combo_options()[1].next.get("id", "") != "LHH", "a learned Spike is no longer hinted")
	p.combos_landed.clear()
	p._set_state(p.State.MOVE)
	p._post_dash_t = 0.0
	p._chain_i = 0
	_check(p.combo_options().is_empty(), "no rows in neutral")
	p._set_state(p.State.CHARGE)
	_check(p.combo_options().size() == 1 and p.combo_options()[0].hold, "charging shows the hold row")
	p._set_state(p.State.MOVE)

	if DisplayServer.get_name() != "headless":
		await _sheet(main, p, guide)
	print("[guide] PASS" if _fails.is_empty() else "[guide] FAIL " + "; ".join(_fails))
	quit()


func _begin(p: Node3D, from: String) -> void:
	p._set_state(p.State.MOVE)
	p._post_dash_t = 0.0
	p._chain_i = 0
	p._start_attack(from)


func _tag(awake: bool) -> String:
	return " (Awakened)" if awake else ""


## Six states, cropped round the hero, in a 2x3 sheet.
func _sheet(main: Node, p: Node3D, guide: Control) -> void:
	var shots: Array[Image] = []
	var setups := [
		["", false, "L1", false], ["", false, "L2", false], ["earth", true, "L3", true],
		["earth", true, "LH", false], ["water", true, "dash", false], ["wind", false, "charge", false]]
	for s: Array in setups:
		if s[0] != "" and p.ascendancy != s[0]:
			p.ascend(s[0])
		p._set_awakened(s[1])
		p.global_position = Vector3.ZERO
		p._set_state(p.State.MOVE)
		p._post_dash_t = 0.0
		p._chain_i = 0
		await create_timer(0.3).timeout  # the guide fades out between states
		match s[2]:
			"dash":
				p._set_state(p.State.MOVE)
				p._post_dash_t = 5.0
			"charge":
				p._start_charge()
			_:
				p._start_attack(s[2])
		# Early (s[3]): the ring still filling. Otherwise once a press is taken.
		for i in 120:
			await process_frame
			if s[2] == "dash":
				p._post_dash_t = 5.0
			if s[2] == "charge":
				Input.action_press("attack_heavy")
			var w: Dictionary = p.combo_window()
			if guide._vis >= 1.0 and guide._swap_t > 0.15 and (w.progress > 0.35 if s[3] else w.ready):
				break
		var img := main.get_viewport().get_texture().get_image()
		var at := main.get_viewport().get_camera_3d().unproject_position(p.global_position + Vector3.UP * 1.1)
		var scale := Vector2(img.get_size()) / main.get_viewport().get_visible_rect().size
		var c := Vector2i((at * scale).round()) - Vector2i(260, CROP.y / 2)
		c = c.clamp(Vector2i.ZERO, img.get_size() - CROP)
		shots.append(img.get_region(Rect2i(c, CROP)))
		Input.action_release("attack_heavy")
	var sheet := Image.create(CROP.x * 2, CROP.y * 3, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CROP), Vector2i((i % 2) * CROP.x, (i / 2) * CROP.y))
	sheet.save_png("user://guide_sheet.png")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[guide] fail: ", what)
