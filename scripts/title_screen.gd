extends "res://scripts/menu_screen.gd"
## Title screen shown when the game boots (skipped after "New run").

signal started

const CONTROLS := "WASD / left stick move    J / LMB / X light    K / RMB / Y heavy\nSpace / A dash    Q / RB awaken    Esc / Start pause"


const ALTAR_MENU := preload("res://scripts/altar_menu.gd")
const RECORDS := preload("res://scripts/records.gd")

var daily := false  # "Daily run" picked: main seeds the run from today's date


func open(focus := 0) -> void:
	button_width = 340
	show_menu("AWAKEN", "a combo roguelike", [
		["Start run", _start],
		["Daily run", _start_daily],
		["Bone altar", open_altar],
		["Settings", open_settings.bind(open.bind(3), 0.85)],
		["Quit", _quit],
	], _footer(), 0.85, focus)
	build_recent(RECORDS.recent_runs())


## Spend banked bones on permanent boons (altar.gd).
func open_altar(focus := 0) -> void:
	button_width = 720
	var items := ALTAR_MENU.items(func() -> void: open_altar(focus), open.bind(2))
	show_menu("BONE ALTAR", ALTAR_MENU.subtitle(), items, "", 0.85, focus)


func _footer() -> String:
	var records: String = RECORDS.summary_line()
	return (records + "\n\n" + CONTROLS) if records != "" else CONTROLS


## "RECENT RUNS" panel on the right (records.gd keeps the last few).
func build_recent(runs: Array) -> void:
	if runs.is_empty() or _root == null:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.1, 0.85), Color(0.4, 0.35, 0.55)))
	panel.custom_minimum_size = Vector2(400, 0)
	panel.position = Vector2(get_viewport().get_visible_rect().size.x - 448, 120)
	_root.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	panel.add_child(list)
	_label(list, "RECENT RUNS", 26, Color(1.0, 0.7, 0.25))
	for run: Dictionary in runs:
		var line := _label(list, RECORDS.recent_line(run), 18,
			Color(1.0, 0.85, 0.45) if run.victory else Color(0.85, 0.8, 0.95))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _start() -> void:
	close_menu()
	started.emit()


## Same doors, twists and rewards for everyone today (main.daily_seed()).
func _start_daily() -> void:
	daily = true
	_start()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
