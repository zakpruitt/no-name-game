extends SceneTree
## Checks the move list (scripts/move_list.gd, the pause menu's MOVES panel and
## the wiki) against the real routing: every row's input starts its move, every
## COMBOS input does too, every move, combo, ultimate and breaker is listed, and
## nothing route() can reach is missing. Then opens the pause menu and checks the
## panel fits the screen and clears the buttons. Prints `[moves] PASS/FAIL`.
## godot --headless --path . -s tests/move_list_check.gd

var LIST: GDScript  # (loaded after the autoloads: player.gd needs Game)
var PLAYER: GDScript
const VIEW := Rect2(0, 0, 1600, 900)
## COMBOS that aren't moves: what they play as.
const PLAYS_AS := {"SKYFALL": "L3", "STORMFALL": "L3"}

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	LIST = load("res://scripts/move_list.gd")
	PLAYER = load("res://scripts/player.gd")
	_check_rows()
	_check_combo_inputs()
	_check_all_listed()
	_check_reachable()
	await _check_panel()
	print("[moves] PASS" if _fails.is_empty() else "[moves] FAIL " + "; ".join(_fails))
	quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


func _check_rows() -> void:
	for section: Dictionary in LIST.SECTIONS:
		for row: Dictionary in section.rows:
			if row.kind == "move":
				var got := _press(row.input, section.get("awake", false))
				_check(got == PLAYS_AS.get(row.id, row.id), "%s starts %s, listed as %s" % [row.input, got, row.id])
			elif row.kind == "breaker":
				_check(PLAYER.BREAKERS.has(row.id), "%s is no breaker" % row.id)
				_check(row.input == PLAYER.COMBOS[row.id].input + " > H", "breaker %s input %s" % [row.id, row.input])


func _check_combo_inputs() -> void:
	for id: String in PLAYER.COMBOS:
		if id in LIST.VOID_ONLY:
			continue
		var input: String = PLAYER.COMBOS[id].input
		var got := _press(input.replace(" (Awakened)", ""), "(Awakened)" in input)
		_check(got == PLAYS_AS.get(id, id), "COMBOS %s input '%s' starts %s" % [id, input, got])


func _check_all_listed() -> void:
	for id: String in PLAYER.MOVES.keys() + PLAYER.COMBOS.keys() + PLAYER.ULTIMATES.keys():
		if id in LIST.VOID_ONLY:
			continue
		_check(_listed(id, "move"), "%s isn't on the move list" % id)
	for id: String in PLAYER.BREAKERS:
		_check(_listed(id, "breaker"), "breaker %s isn't on the move list" % id)


## Every move route() can reach by any presses from neutral, resting or Awakened.
func _check_reachable() -> void:
	for awake: bool in [false, true]:
		var seen := {}
		var reached := {}
		var todo: Array = [{"from": "", "attacking": false, "chain": 0, "post_dash": false, "gusted": false}]
		while not todo.is_empty():
			var s: Dictionary = todo.pop_back()
			var key := str(s)
			if seen.has(key):
				continue
			seen[key] = true
			# Let the move finish (the chain's still live), or dash out of it.
			if s.attacking:
				var waited: Dictionary = s.duplicate()
				waited.attacking = false
				todo.append(waited)
				var dashed: Dictionary = waited.duplicate()
				dashed.post_dash = true
				if s.from in PLAYER.AIR_DASH_FROM:
					dashed.from = "AD"
				todo.append(dashed)
			for kind: String in ["light", "heavy"]:
				var id: String = PLAYER.route(kind, s.from, s.attacking, s.chain, s.post_dash, awake, s.gusted)
				reached[id] = true
				if PLAYER.ULTIMATES.has(id):
					continue  # (an ultimate ends the string)
				todo.append({"from": id, "attacking": true, "chain": PLAYER.chain_after(id), "post_dash": false,
					"gusted": s.gusted or id == "AH"})
		for id: String in reached:
			_check(_listed(id, "move"), "route() reaches %s, not on the move list" % id)


func _listed(id: String, kind: String) -> bool:
	for section: Dictionary in LIST.SECTIONS:
		for row: Dictionary in section.rows:
			if row.kind == kind and row.id == id:
				return true
	return false


## Walks an input through the same route() the game uses.
func _press(input: String, awake: bool) -> String:
	var from := ""
	var attacking := false
	var chain := 0
	var post_dash := false
	var gusted := false
	var last := ""
	var tokens := input.replace(",", " ").replace(">", " ").replace(":", " ").split(" ", false)
	var i := 0
	while i < tokens.size():
		var t: String = tokens[i]
		i += 1
		match t:
			"Air":  # mid air string
				from = "AL1"
				attacking = true
			"pause":
				attacking = false
			"Dash":
				post_dash = true
				attacking = false
				if from in PLAYER.AIR_DASH_FROM:
					from = "AD"
			"hold":
				i += 1  # "hold H": the charged heavy (not a route() press)
				last = "CH"
			"L", "H":
				last = PLAYER.route("light" if t == "L" else "heavy", from, attacking, chain, post_dash, awake, gusted)
				from = last
				attacking = true
				chain = PLAYER.chain_after(last)
				post_dash = false
				gusted = gusted or last == "AH"
			_:
				_check(false, "unknown token %s in '%s'" % [t, input])
	return last


func _check_panel() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main.clear_room()
	var p: Node3D = main.player
	# Every row names itself in every element.
	for el: String in ["", "wind", "earth", "water"]:
		p.ascendancy = el
		for section: Dictionary in LIST.SECTIONS:
			for row: Dictionary in section.rows:
				_check(LIST.row_name(row, p) != "", "%s has no name (%s)" % [row.input, el])
	p.ascendancy = ""
	var menu: Node = main.get_children().filter(func(n: Node) -> bool: return n.has_method("_build_moves"))[0]
	menu._open()
	for i in 4:
		await process_frame
	var panel: Control = menu.moves_panel
	var rect := panel.get_global_rect()
	_check(VIEW.encloses(rect), "moves panel %s off screen" % rect)
	for b: Button in menu._buttons:
		_check(not rect.intersects(b.get_global_rect()), "moves panel %s covers %s" % [rect, b.text])
	var scroll: ScrollContainer = menu.moves_scroll
	print("[moves] panel=%s content=%.0f view=%.0f" % [rect, scroll.get_child(0).size.y, scroll.size.y])
	menu.close_menu()
