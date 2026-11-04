extends "res://scripts/menu_screen.gd"
## Pause menu: Esc / Start toggles it in the training room (backs out of
## Settings first). Won't open over other screens that already pause the game
## (none do for now). A panel on the right lists every move.

const MOVE_LIST := preload("res://scripts/move_list.gd")
const MOVES_WIDTH := 500.0
const MOVES_HEIGHT := 620.0  # the list scrolls past this
const MOVES_INPUT_WIDTH := 190.0
const MOVES_PAGE := 300  # px per Page Up / Down
const MOVES_STICK := 700.0  # px/s at full right stick

var moves_panel: Control
var moves_scroll: ScrollContainer


func _process(delta: float) -> void:
	if not is_open() or not is_instance_valid(moves_scroll):
		return
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(stick) > 0.25:
		moves_scroll.scroll_vertical += int(round(stick * MOVES_STICK * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and is_open() and is_instance_valid(moves_scroll):
		if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
			moves_scroll.scroll_vertical += MOVES_PAGE if event.keycode == KEY_PAGEDOWN else -MOVES_PAGE
			get_viewport().set_input_as_handled()
			return
	if not event.is_action_pressed("pause"):
		return
	if in_settings():
		settings_back()
	elif is_open():
		close_menu()
	elif not get_tree().paused:
		_open()
	else:
		return
	get_viewport().set_input_as_handled()


## Training's pause menu: Fill Awakening (main.train_awaken), Settings, a fresh room.
func _open(focus := 0) -> void:
	var main := get_parent()
	var items: Array = [
		["Resume", close_menu],
		["Fill Awakening", _train.bind("train_awaken")],
	]
	var settings := items.size()
	items.append_array([
		["Settings", open_settings.bind(_open.bind(settings), 0.7)],
		["Restart training", _restart_training],
		["Quit game", _quit],
	])
	show_menu("TRAINING", "", items, "", 0.7, focus)
	_build_moves()


func _train(method: String) -> void:
	close_menu()
	get_parent().call(method)


func _restart_training() -> void:
	close_menu()
	get_parent().restart_training()


## "MOVES": everything he can press (MOVE_LIST.SECTIONS). Combos landed this run
## show how often; the rest are dimmed, still to find. Scrolls with the mouse
## wheel, Page Up / Down or the right stick.
func _build_moves() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or _root == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.1, 0.85), Color(0.4, 0.35, 0.55)))
	panel.position = Vector2(1600 - 40 - MOVES_WIDTH, 110)
	_root.add_child(panel)
	moves_panel = panel
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	_label(outer, "MOVES", 30, Color(1.0, 0.7, 0.25))
	_label(outer, "%d / %d combos landed this run" % [player.combos_landed.size(), player.COMBOS.size()], 15,
		Color(1, 1, 1, 0.5))
	_label(outer, "Scroll: wheel, Page Up / Down or right stick", 13, Color(1, 1, 1, 0.4))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(MOVES_WIDTH - 16, MOVES_HEIGHT)
	outer.add_child(scroll)
	moves_scroll = scroll
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for section: Dictionary in MOVE_LIST.SECTIONS:
		_move_header(list, section)
		for row: Dictionary in section.rows:
			_move_row(list, row, player)


## A section heading in the move list, with its hint in a dim line under it.
func _move_header(list: Control, section: Dictionary) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	list.add_child(gap)
	var head := _label(list, section.title, 15, Color(1.0, 0.7, 0.25, 0.85))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if section.has("hint"):
		var hint := _label(list, section.hint, 13, Color(1, 1, 1, 0.5))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## One input and its name, and how often it was landed.
func _move_row(list: Control, row: Dictionary, player: Node) -> void:
	var tier: int = MOVE_LIST.row_tier(row, player)
	var color: Color = player.COMBO_TIER_COLORS[tier - 1] if tier > 0 else Color(0.85, 0.8, 0.95)
	var combo: String = MOVE_LIST.row_combo(row, player)
	var times: int = player.combos_landed.get(combo, 0)
	if combo != "" and times == 0:
		color.a = 0.5
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	list.add_child(line)
	var input := _label(line, row.input, 16, color)
	input.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	input.custom_minimum_size = Vector2(MOVES_INPUT_WIDTH, 0)
	var title := _label(line, MOVE_LIST.row_name(row, player) + ("   ×%d" % times if times > 0 else ""), 16, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
