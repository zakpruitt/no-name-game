extends "res://scripts/menu_screen.gd"
## Title screen shown when the game boots (skipped after "New run").

signal started

const CONTROLS := "WASD / left stick move    J / LMB / X light    K / RMB / Y heavy\nSpace / A dash    Q / RB awaken    Esc / Start pause"


const ALTAR_MENU := preload("res://scripts/altar_menu.gd")

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


## Spend banked bones on permanent boons (altar.gd).
func open_altar(focus := 0) -> void:
	button_width = 720
	var items := ALTAR_MENU.items(func() -> void: open_altar(focus), open.bind(2))
	show_menu("BONE ALTAR", ALTAR_MENU.subtitle(), items, "", 0.85, focus)


func _footer() -> String:
	var records: String = preload("res://scripts/records.gd").summary_line()
	return (records + "\n\n" + CONTROLS) if records != "" else CONTROLS


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
