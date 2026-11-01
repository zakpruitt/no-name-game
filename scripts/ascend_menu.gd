extends "res://scripts/menu_screen.gd"
## Level 6: choose an Ascendancy path (Ascendancy.PATHS). Emits `chosen` with
## the path key. There's no "skip": every run ascends once.

signal chosen(path: String)


func _ready() -> void:
	super()
	button_width = 760


func open() -> void:
	var items: Array = []
	for id: String in Ascendancy.PATHS:
		var p: Dictionary = Ascendancy.PATHS[id]
		items.append(["%s   ·   %s   ·   finisher: %s" % [p.name.to_upper(), p.desc, p.finisher], _pick.bind(id)])
	show_menu("ASCENDANCY", "Level %d: choose the element your Awakening becomes for the rest of the run" % Game.LEVEL_MAX,
		items, "", 0.75)


## Press button `index` (autotest).
func pick(index: int) -> void:
	if is_open() and index >= 0 and index < _buttons.size():
		_buttons[index].pressed.emit()


func _pick(id: String) -> void:
	close_menu()
	chosen.emit(id)
