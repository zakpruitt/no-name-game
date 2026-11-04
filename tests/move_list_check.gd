extends SceneTree
## Checks the move list (scripts/move_list.gd, the pause menu's MOVES panel)
## against the real routing: every row's input starts its move, every COMBOS
## input does too, every move and combo is listed, and nothing void_route() can
## reach is missing. Then opens the pause menu and checks the panel fits the
## screen and clears the buttons. Prints `[moves] PASS/FAIL`.
## godot --headless --path . -s tests/move_list_check.gd

var LIST: GDScript  # (loaded after the autoloads: player.gd needs Game)
var PLAYER: GDScript
var VOID: GDScript
const VIEW := Rect2(0, 0, 1600, 900)

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	LIST = load("res://scripts/move_list.gd")
	PLAYER = load("res://scripts/player.gd")
	VOID = load("res://scripts/void_element.gd")
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
				var got := _press(row.input)
				_check(got == row.id, "%s starts %s, listed as %s" % [row.input, got, row.id])


func _check_combo_inputs() -> void:
	for id: String in PLAYER.COMBOS:
		var input: String = PLAYER.COMBOS[id].input
		var got := _press(input)
		_check(got == id, "COMBOS %s input '%s' starts %s" % [id, input, got])


## Every move and combo has a row (the grab, GR, is the "H" text row).
func _check_all_listed() -> void:
	for id: String in PLAYER.MOVES.keys() + PLAYER.COMBOS.keys():
		if id == VOID.NEUTRAL:
			continue
		_check(_listed(id), "%s isn't on the move list" % id)


## Every move void_route() can reach by any presses from neutral.
func _check_reachable() -> void:
	var seen := {}
	var reached := {}
	var todo: Array = [{"from": "", "attacking": false, "chain": 0, "post_dash": false}]
	while not todo.is_empty():
		var s: Dictionary = todo.pop_back()
		var key := str(s)
		if seen.has(key):
			continue
		seen[key] = true
		if s.attacking:  # let the move finish (the chain's still live), or dash out of it
			var waited: Dictionary = s.duplicate()
			waited.attacking = false
			todo.append(waited)
			var dashed: Dictionary = waited.duplicate()
			dashed.post_dash = true
			todo.append(dashed)
		for kind: String in ["light", "heavy"]:
			var id: String = PLAYER.void_route(kind, s.from, s.attacking, s.chain, s.post_dash)
			reached[id] = true
			todo.append({"from": id, "attacking": true, "chain": PLAYER.chain_after(id), "post_dash": false})
	for id: String in reached:
		_check(id == VOID.NEUTRAL or _listed(id), "void_route() reaches %s, not on the move list" % id)


func _listed(id: String) -> bool:
	for section: Dictionary in LIST.SECTIONS:
		for row: Dictionary in section.rows:
			if row.kind == "move" and row.id == id:
				return true
	return false


## Walks an input through the same void_route() the game uses ("hold H" = Overwhelm; the
## vault, IJ, is listed off the spear, which is how void_route() reaches it too).
func _press(input: String) -> String:
	var from := ""
	var attacking := false
	var chain := 0
	var post_dash := false
	var last := ""
	var tokens := input.replace(",", " ").replace(">", " ").split(" ", false)
	var i := 0
	while i < tokens.size():
		var t: String = tokens[i]
		i += 1
		match t:
			"Dash":
				post_dash = true
				attacking = false
			"hold":
				i += 1  # "hold H": the held right click
				last = VOID.CHARGED
			"L", "H":
				last = PLAYER.void_route("light" if t == "L" else "heavy", from, attacking, chain, post_dash)
				from = last
				attacking = true
				chain = PLAYER.chain_after(last)
				post_dash = false
			_:
				_check(false, "unknown token %s in '%s'" % [t, input])
	return last


func _check_panel() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main.clear_room()
	var p: Node3D = main.player
	# Every row names itself.
	for section: Dictionary in LIST.SECTIONS:
		for row: Dictionary in section.rows:
			_check(LIST.row_name(row, p) != "", "%s has no name" % row.input)
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
