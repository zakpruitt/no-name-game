extends "res://scripts/menu_screen.gd"
## Title screen shown when the game boots (skipped after "New run").

signal started

const CONTROLS := "WASD / left stick move    J / LMB / X light    K / RMB / Y heavy\nSpace / A dash    Q / RB awaken    Esc / Start pause"


const ALTAR_MENU := preload("res://scripts/altar_menu.gd")
const RECORDS := preload("res://scripts/records.gd")

var daily := false  # "Daily run" picked: main seeds the run from today's date
var replay := {}  # a RECENT RUNS entry picked: main replays its seed


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


## "RECENT RUNS" panel on the right (records.gd keeps the last few). Each
## line is a button that starts a new run on that run's seed.
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
		var b := Button.new()
		b.text = RECORDS.recent_line(run)
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = "Replay this seed"
		b.add_theme_font_size_override("font_size", 18)
		var color := Color(1.0, 0.85, 0.45) if run.victory else Color(0.85, 0.8, 0.95)
		b.add_theme_color_override("font_color", color)
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.3))
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.7, 0.3))
		b.add_theme_stylebox_override("focus", _style(Color(0.2, 0.15, 0.28), Color(1.0, 0.7, 0.3)))
		b.disabled = run.seed < 0
		b.pressed.connect(_replay.bind(run))
		list.add_child(b)
	var hint := _label(list, "Pick a run to replay its seed", 14, Color(1, 1, 1, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _start() -> void:
	close_menu()
	started.emit()


## Same doors, twists and rewards for everyone today (main.daily_seed()).
func _start_daily() -> void:
	daily = true
	_start()


func _replay(run: Dictionary) -> void:
	replay = run
	_start()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
