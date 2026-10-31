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
		["Settings", open_settings.bind(_open.bind(1), 0.7)],
		["Restart run", _restart.bind(true)],
		["Quit to title", _restart.bind(false)],
		["Quit game", _quit],
	], _run_info(), 0.7, focus)
	_build_powers()


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


## "YOUR BUILD": each owned power with its level and current effect.
func _build_powers() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or _root == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.1, 0.85), Color(0.4, 0.35, 0.55)))
	panel.custom_minimum_size = Vector2(440, 0)
	panel.position = Vector2(48, 120)
	_root.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	panel.add_child(list)
	_label(list, "YOUR BUILD", 30, Color(1.0, 0.7, 0.25))
	if player.upgrades.is_empty():
		_label(list, "No powers yet", 20, Color(1, 1, 1, 0.55))
	for id: String in player.upgrades:
		var u := Upgrades.get_by_id(id)
		var level: int = player.upgrades[id]
		var tags := Upgrades.tags(id)
		var head := _label(list, "%s%s   [%s]%s" % [u.name, Upgrades.level_tag(level), u.slot,
			("   " + tags) if tags != "" else ""], 21, Color(1.0, 0.85, 0.55))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var desc := _label(list, Upgrades.describe(u, level, player.synergies), 17, Color(0.85, 0.8, 0.95))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(400, 0)
	for tag: String in player.synergies:
		var s: Dictionary = Upgrades.SYNERGIES[tag]
		var line := _label(list, "%s synergy: %s" % [s.name, s.desc], 18, Color(0.6, 0.95, 0.85))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(400, 0)


func _restart(skip_title: bool) -> void:
	Game.skip_title = skip_title
	close_menu()
	get_tree().reload_current_scene()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
