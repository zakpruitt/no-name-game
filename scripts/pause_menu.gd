extends "res://scripts/menu_screen.gd"
## Pause menu: Esc / Start toggles it during a run (backs out of Settings
## first). Won't open over other screens that already pause the game (title,
## rewards, run summary). A panel on the left lists the run's powers; the
## footer shows the room and the run's seed (replay with --seed).

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


func _open(focus := 0) -> void:
	var main := get_parent()
	if main != null and main.get("training"):
		_open_training(focus)
		return
	show_menu("PAUSED", "", [
		["Resume", close_menu],
		["Map", _show_map],
		["Settings", open_settings.bind(_open.bind(2), 0.7)],
		["Restart run", _restart.bind(true)],
		["Quit to title", _restart.bind(false)],
		["Quit game", _quit],
	], _run_info(), 0.7, focus)
	_build_powers()
	_build_moves()


## Training's pause menu: free powers, Awakening and Ascendancy (main.train_*).
func _open_training(focus := 0) -> void:
	var main := get_parent()
	var items: Array = [
		["Resume", close_menu],
		["Pick a power", _train.bind("train_power")],
		["Fill Awakening", _train.bind("train_awaken")],
	]
	if main.player.ascendancy == "":
		items.append(["Ascend", _train.bind("train_ascend")])
	var settings := items.size()
	items.append_array([
		["Settings", open_settings.bind(_open.bind(settings), 0.7)],
		["Restart training", _restart_training],
		["Quit to title", _restart.bind(false)],
		["Quit game", _quit],
	])
	show_menu("TRAINING", "", items, "Restart training clears your powers", 0.7, focus)
	_build_powers()
	_build_moves()


func _train(method: String) -> void:
	close_menu()
	get_parent().call(method)


func _restart_training() -> void:
	close_menu()
	get_parent().restart_training()


## "Room 3 / 8   ·   daily run 2026-10-31   ·   seed 975604274"
func _run_info() -> String:
	var main := get_parent()
	if main == null or not "run_seed" in main:
		return ""
	var parts: Array[String] = ["Room %d / %d" % [main.room, main.RUN_LENGTH]]
	if main.daily_date != "":
		parts.append("daily run " + main.daily_date)
	parts.append("seed %d" % main.run_seed)
	return "   ·   ".join(parts)


## "YOUR BUILD": the owned powers grouped by path (fusions last), each with
## its icon, level and current effect, plus mastery progress and synergies.
## Scrolls once it's taller than the screen allows.
func _build_powers() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or _root == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.1, 0.88), Color(0.4, 0.35, 0.55)))
	panel.position = Vector2(40, 110)
	_root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	_label(outer, "YOUR BUILD", 30, Color(1.0, 0.7, 0.25))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size = Vector2(440, 0)
	scroll.add_child(list)
	if player.upgrades.is_empty():
		_label(list, "No powers yet", 20, Color(1, 1, 1, 0.55))
	var counts := Upgrades.path_counts(player.upgrades)
	var groups: Array = Upgrades.PATHS.keys() + ["fusion"]
	for group: String in groups:
		var ids: Array = player.upgrades.keys().filter(func(id: String) -> bool:
			var u := Upgrades.get_by_id(id)
			return u.has("fusion") if group == "fusion" else (u.path == group and not u.has("fusion")))
		if ids.is_empty():
			continue
		_path_header(list, group, counts, player.masteries)
		for id: String in ids:
			_power_row(list, id, player.upgrades[id], player.synergies)
	for tag: String in player.synergies:
		var s: Dictionary = Upgrades.SYNERGIES[tag]
		var line := _label(list, "%s synergy: %s" % [s.name, s.desc], 17, Color(0.6, 0.95, 0.85))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(420, 0)
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.custom_minimum_size = Vector2(456, minf(list.size.y, 900 - 110 - 140))


## A path's heading: key, name and mastery progress (or the mastery's effect
## once it's on). "fusion" heads the fusions.
func _path_header(list: Control, group: String, counts: Dictionary, masteries: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	list.add_child(row)
	if group == "fusion":
		_label(row, "FUSIONS", 19, Color(1, 1, 1, 0.85))
		return
	var info: Dictionary = Upgrades.PATHS[group]
	row.add_child(PowerIcon.chip(group))
	_label(row, info.name.to_upper(), 19, info.color)
	var on: bool = group in masteries
	var right := _label(row, "MASTERY" if on else PowerIcon.mastery_pips(counts[group]) + "  mastery", 15,
		info.color.lightened(0.25) if on else Color(info.color, 0.7))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if on:
		var m := _label(list, "Mastery: " + Upgrades.mastery_text(group), 15, info.color.lightened(0.25))
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(420, 0)


## One owned power: icon with level pips, name, and its effect text.
func _power_row(list: Control, id: String, level: int, synergies: Array) -> void:
	var u := Upgrades.get_by_id(id)
	var color := Upgrades.color(u)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	list.add_child(row)
	row.add_child(PowerIcon.make(id, 52, level))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var head := _label(text, "%s%s" % [u.name, Upgrades.level_tag(level)], 19, color.lightened(0.35))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# How often it has fired this run (player.power_procs), so a quiet power shows.
	var player := get_tree().get_first_node_in_group("player")
	var fired: int = player.power_procs.get(id, 0) if player != null else 0
	if fired > 0:
		head.text += "   ×%d this run" % fired
	var desc := RichTextLabel.new()
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.scroll_active = false
	desc.custom_minimum_size = Vector2(370, 0)
	for font: String in ["normal_font_size", "bold_font_size"]:
		desc.add_theme_font_size_override(font, 15)
	desc.add_theme_color_override("default_color", Color(0.85, 0.82, 0.92))
	desc.text = Upgrades.describe(u, level, synergies, color.lightened(0.3))
	text.add_child(desc)
	var combo := Upgrades.combo_of(u)
	if player != null and player.COMBOS.has(combo):
		var how := _label(text, "%s:  %s" % [player.combo_name(combo), player.COMBOS[combo].input], 13, Color(1, 1, 1, 0.5))
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


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


## One input and its name, plus the owned powers that hook it
## (Upgrades.combo_of), in their path colour.
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
	if combo == "":
		return
	for pid: String in player.upgrades:
		var u := Upgrades.get_by_id(pid)
		if Upgrades.combo_of(u) == combo:
			var hook := _label(list, "      + %s%s" % [u.name, Upgrades.level_tag(player.upgrades[pid])], 14,
				Upgrades.color(u).lightened(0.3))
			hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## The run map, read-only, over the pause menu (main.show_map()).
func _show_map() -> void:
	var main := get_parent()
	if main.has_method("show_map"):
		main.show_map()


func _restart(skip_title: bool) -> void:
	Game.skip_title = skip_title
	close_menu()
	get_tree().reload_current_scene()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
