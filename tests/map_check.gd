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
