extends "res://scripts/menu_screen.gd"
## Title screen shown when the game boots (skipped after "New run").

signal started

const CONTROLS := "WASD / left stick move    J / LMB / X light    K / RMB / Y heavy\nSpace / A dash    Q / RB awaken    Esc / Start pause"


func open(focus := 0) -> void:
	show_menu("AWAKEN", "a combo roguelike", [
		["Start run", _start],
		["Settings", open_settings.bind(open.bind(1), 0.85)],
		["Quit", _quit],
	], _footer(), 0.85, focus)


func _footer() -> String:
	var records: String = preload("res://scripts/records.gd").summary_line()
	return (records + "\n\n" + CONTROLS) if records != "" else CONTROLS


func _start() -> void:
	close_menu()
	started.emit()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
