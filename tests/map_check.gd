extends SceneTree
## Checks the run map (RunMap.generate) over many seeds: room 1 a lone fight,
## the boss alone at the end, every room reachable and leading to the boss,
## no two fightless rooms linked, a rest before the boss, every kind showing
## up, valid vault paths / trials / twists, and the same seed giving the same
## map. Prints `[map] PASS` or `[map] FAIL ...`. Windowed it also renders the
## map mid-run to `user://map_check.png`.
## godot --path . -s tests/map_check.gd   (checks only: add --headless)

const SEEDS := 500

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var RM: GDScript = load("res://scripts/run_map.gd")
	var main_script: GDScript = load("res://scripts/main.gd")
	var length: int = main_script.RUN_LENGTH
	var twists: Array = main_script.ELITE_TWISTS.keys()
	var seen := {}
	var rng := RandomNumberGenerator.new()
	for i in SEEDS:
		rng.seed = i
		var map: Array = RM.generate(rng, length, twists, main_script.DOUBLE_TWIST_ROOM)
		_check_map(RM, map, length, twists, i, seen)
	for kind: String in RM.KINDS:
		_check(seen.has(kind), "kind %s appears in %d seeds" % [kind, SEEDS])
	print("[map] kinds over %d seeds: %s" % [SEEDS, seen])
	rng.seed = 42
	var a: Array = RM.generate(rng, length, twists, main_script.DOUBLE_TWIST_ROOM)
	rng.seed = 42
	var b: Array = RM.generate(rng, length, twists, main_script.DOUBLE_TWIST_ROOM)
	_check(str(a) == str(b), "same seed, same map")
	await _check_screen(RM, a)

	if DisplayServer.get_name() != "headless":
		await _shot(RM)
	print("[map] PASS" if _fails.is_empty() else "[map] FAIL " + "; ".join(_fails))
	quit()


func _check_map(RM: GDScript, map: Array, length: int, twists: Array, i: int, seen: Dictionary) -> void:
	var tag := "seed %d" % i
	_check(map.size() == length, "%s: %d columns" % [tag, length])
	_check(map[0].size() == 1 and map[0][0].kind == "fight", "%s: room 1 is a lone fight" % tag)
	_check(map[-1].size() == 1 and map[-1][0].kind == "boss", "%s: the boss is alone at the end" % tag)
	var pre_boss_rest := false
	for c in length:
		for n: Dictionary in map[c]:
			seen[n.kind] = seen.get(n.kind, 0) + 1
			if c + 1 < RM.UNLOCK_ROOM:
				_check(n.kind == "fight", "%s: room %d is a fight" % [tag, c + 1])
			if c > 0:
				_check(not RM.preds(map, c, n.lane).is_empty(), "%s: room %d lane %d has a way in" % [tag, c + 1, n.lane])
			if c < length - 1:
				_check(not n.next.is_empty(), "%s: room %d lane %d has a way out" % [tag, c + 1, n.lane])
				for lane: int in n.next:
					var to: Dictionary = RM.node_at(map, Vector2i(c + 1, lane))
					_check(not to.is_empty(), "%s: link to a real room" % tag)
					_check(not (RM.is_fightless(n.kind) and RM.is_fightless(to.kind)),
						"%s: room %d %s links to fightless %s" % [tag, c + 1, n.kind, to.kind])
			if c == length - 2 and n.kind == "rest":
				pre_boss_rest = true
			match n.kind:
				"elite":
					_check(not n.twists.is_empty() and n.twists.all(func(t: String) -> bool: return t in twists),
						"%s: elite twists %s" % [tag, n.twists])
				"vault":
					_check(Upgrades.PATHS.has(n.path), "%s: vault path %s" % [tag, n.path])
				"trial":
					_check(RM.TRIALS.has(n.trial), "%s: trial %s" % [tag, n.trial])
				"mystery":
					# Reveal a copy: a real, dressed room (the map itself stays unknown).
					var r: Dictionary = n.duplicate(true)
					var rr := RandomNumberGenerator.new()
					rr.seed = i * 31 + c
					RM.reveal(r, c + 1, twists, 5, rr)
					_check(RM.MYSTERY.has(r.kind), "%s: unknown room revealed as %s" % [tag, r.kind])
					_check((r.kind != "vault" or Upgrades.PATHS.has(r.path)) and (r.kind != "trial" or RM.TRIALS.has(r.trial))
						and (r.kind != "elite" or not r.twists.is_empty()), "%s: revealed %s is dressed" % [tag, r.kind])
	_check(pre_boss_rest or not RM.PRE_BOSS_REST, "%s: a rest before the boss" % tag)
	# Every room reachable from the start (links only go forward, so this
	# plus "a way out" everywhere means every room also reaches the boss).
	var reach := {Vector2i(0, map[0][0].lane): true}
	for c in length - 1:
		for n: Dictionary in map[c]:
			if reach.has(Vector2i(c, n.lane)):
				for lane: int in n.next:
					reach[Vector2i(c + 1, lane)] = true
	for c in length:
		for n: Dictionary in map[c]:
			_check(reach.has(Vector2i(c, n.lane)), "%s: room %d lane %d reachable" % [tag, c + 1, n.lane])


## The screen on its own (works headless): hovering any room shows it,
## the focused choice's onward routes are what the "Leads on to" line counts,
## and a pick walks the marker over, then emits `chosen`.
func _check_screen(RM: GDScript, map: Array) -> void:
	var screen_script: GDScript = load("res://scripts/map_screen.gd")
	_check(screen_script != null and screen_script.can_instantiate(), "map_screen.gd compiles")
	if screen_script == null or not screen_script.can_instantiate():
		return
	var screen: CanvasLayer = screen_script.new()
	var cover := CanvasLayer.new()
	get_root().add_child(cover)
	get_root().add_child(screen)
	screen.cover = cover
	var route: Array = [Vector2i(0, map[0][0].lane)]
	route.append(Vector2i(1, RM.next_nodes(map, route[-1])[0].lane))
	var choices: Array = RM.next_nodes(map, route[-1])
	screen.open(map, route, choices, false, {})
	_check(not cover.visible, "the map hides the HUD")
	screen.set_status(30.0, 100.0, 12, 2)
	_check(screen._status.text.begins_with("HP 30 / 100") and screen._status.get_theme_color("font_color").r > 0.9
		and screen._status.get_theme_color("font_color").g < 0.6, "low HP shows red on the map")
	# The focused choice reaches only rooms its links lead to.
	for at: Vector2i in screen._reach:
		_check(at.x >= 2, "reach starts at the choice (%s)" % at)
	var far := Vector2i(map.size() - 2, map[-2][0].lane)
	screen._set_hover(far)
	_check(screen._detail_title.text == RM.title(map[-2][0]), "hovering room %d shows it" % (far.x + 1))
	_check(screen._detail_hint.text.begins_with("Room %d" % (far.x + 1)), "hover hint names the room")
	screen._set_hover(Vector2i(2, choices[-1].lane))
	_check(screen._focus == choices.size() - 1, "hovering a choice focuses it")
	var picked := [-1]
	screen.chosen.connect(func(i: int) -> void: picked[0] = i)
	screen.pick(0)
	_check(screen.visible and picked[0] == -1, "a pick walks the marker before closing")
	await create_timer(screen.MOVE_TIME + 0.2).timeout
	_check(picked[0] == 0 and not screen.visible, "the pick lands after the walk")
	_check(cover.visible, "closing brings the HUD back")
	screen.open(map, route, [], true, {})
	screen.move_cursor(1, 0)
	_check(screen._hover.x == route[-1].x + 1 and screen._detail_hint.text.begins_with("Room %d" % (route[-1].x + 2)),
		"arrows walk the read-only map")
	screen.move_cursor(0, 1)
	screen.move_cursor(99, 0)
	_check(screen._hover == Vector2i(map.size() - 1, map[-1][0].lane), "the cursor stops at the boss")
	screen._hover = Vector2i(-1, -1)
	screen._update_detail()
	_check(screen._detail_text.text.begins_with("Ahead: ") or screen._detail_text.text.begins_with("Only"),
		"read-only map sums up what's ahead")
	screen._close()
	paused = false
	screen.queue_free()
	cover.queue_free()
	await process_frame


## The map four rooms in, a vault chosen as the focus if one is on offer.
func _shot(RM: GDScript) -> void:
	get_root().get_node("Game").skip_title = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.4).timeout
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	main._queue.clear()
	var route: Array = [main.map_route[0]]
	for i in 3:
		route.append(Vector2i(route[-1].x + 1, RM.next_nodes(main.run_map, route[-1])[0].lane))
	var choices: Array = RM.next_nodes(main.run_map, route[-1])
	main.map_menu.open(main.run_map, route, choices, false, {"light": 2, "heavy": 1, "dash": 0, "awaken": 0, "soul": 1})
	for i in choices.size():
		if choices[i].kind == "vault":
			main.map_menu._set_focus(i)
	await create_timer(0.5).timeout
	main.get_viewport().get_texture().get_image().save_png("user://map_check.png")
	main.map_menu.pick(0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		if _fails.size() < 20:
			_fails.append(what)
		print("[map] fail: ", what)
