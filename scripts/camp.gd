extends "res://scripts/menu_screen.gd"
## Rest-room camp: spend bones on run boosts (main.CAMP holds costs/amounts),
## or move on. Emits `chosen` with a CAMP key or "leave".

signal chosen(id: String)


## `can_hone`: whether any owned power can still level up.
func open(camp: Dictionary, bones: int, can_hone: bool) -> void:
	var items: Array = []
	for id in camp:
		var c: Dictionary = camp[id]
		var blocked: bool = bones < c.cost or (id == "hone" and not can_hone)
		items.append(["%s   (%d bones)" % [c.text, c.cost], _pick.bind(id), blocked])
	items.append(["Move on", _pick.bind("leave")])
	show_menu("CAMP", "rested and healed   ·   %d bones" % bones, items, "", 0.6)


## Press button `index` (autotest).
func pick(index: int) -> void:
	if is_open() and index >= 0 and index < _buttons.size() and not _buttons[index].disabled:
		_buttons[index].pressed.emit()


func first_affordable() -> int:
	for i in _buttons.size():
		if not _buttons[i].disabled:
			return i
	return _buttons.size() - 1


func _pick(id: String) -> void:
	close_menu()
	chosen.emit(id)
