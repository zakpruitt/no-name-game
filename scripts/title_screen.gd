extends "res://scripts/menu_screen.gd"
## Title screen shown when the game boots (skipped after "New run").

signal started

const CONTROLS := "WASD / left stick move    J / LMB / X light    K / RMB / Y heavy\nSpace / A dash    Q / RB awaken    Esc / Start pause"


func open() -> void:
	show_menu("AWAKEN", "a combo roguelike", [
		["Start run", _start],
		["Quit", _quit],
	], CONTROLS, 0.85)


func _start() -> void:
	close_menu()
	started.emit()


func _quit() -> void:
	Game.stop_all_sfx()
	get_tree().quit()
