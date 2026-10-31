extends "res://scripts/menu_screen.gd"
## Between rooms: pick which door to take next (room kinds from main.gd).

signal chosen(kind: String)

## Door text per room kind.
const DOORS := {
	"fight": "Fight\nskeletons, 1 power",
	"elite": "Elite\ntougher foes, 2 powers",
	"rest": "Rest\nheal 40%, no fight",
}


func open(kinds: Array, next_room: int) -> void:
	var items: Array = []
	for k in kinds:
		items.append([DOORS[k], _pick.bind(k)])
	show_menu("CHOOSE YOUR PATH", "room %d" % next_room, items, "", 0.6)


func pick(index: int) -> void:
	if is_open() and index >= 0 and index < _buttons.size():
		_buttons[index].pressed.emit()


func _pick(kind: String) -> void:
	close_menu()
	chosen.emit(kind)
