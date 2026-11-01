extends "res://scripts/menu_screen.gd"
## Pause menu: Esc / Start toggles it during a run (backs out of Settings
## first). Won't open over other screens that already pause the game (title,
## rewards, run summary). A panel on the left lists the run's powers; the
## footer shows the room and the run's seed (replay with --seed).


func _unhandled_input(event: InputEvent) -> void:
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


## "MOVES": the fixed move list, basics plus the named combos (player.COMBOS).
## Combos landed this run show how often; the rest are dimmed, still to find.
func _build_moves() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or _root == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.1, 0.85), Color(0.4, 0.35, 0.55)))
	panel.custom_minimum_size = Vector2(380, 0)
	panel.position = Vector2(1600 - 48 - 380, 120)
	_root.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)
	_label(list, "MOVES", 30, Color(1.0, 0.7, 0.25))
	_label(list, "%d / %d combos landed this run" % [player.combos_landed.size(), player.COMBOS.size()], 15,
		Color(1, 1, 1, 0.5))
	var rows: Array = [["L", "Slice"], ["H", "Spin"], ["Dash", "Dodge"], ["Q", "Awaken"]]
	for id: String in player.COMBOS:
		rows.append([player.COMBOS[id].input, player.combo_name(id), player.COMBOS[id].tier, player.combos_landed.get(id, 0)])
	for r: Array in rows:
		var tier: int = r[2] if r.size() > 2 else 0
		var color: Color = player.COMBO_TIER_COLORS[tier - 1] if tier > 0 else Color(0.85, 0.8, 0.95)
		var times: int = r[3] if r.size() > 3 else -1
		if times == 0:
			color.a = 0.5
		var line := _label(list, "%s   %s%s" % [r[0], r[1], "   ×%d" % times if times > 0 else ""], 19, color)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


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
