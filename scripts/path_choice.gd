extends "res://scripts/menu_screen.gd"
## Between rooms: pick which door to take next (room kinds from main.gd).

signal chosen(kind: String)

## Door text per room kind.
const DOORS := {
	"fight": "Fight\nskeletons, 1 power",
	"elite": "Elite\ntougher foes, 2 powers",
	"rest": "Rest\nheal 40%, no fight",
	"shrine": "Shrine\na trade, no fight",
}


func _ready() -> void:
	super()
	title_size = 56
	button_width = 440  # doors share a width, even with an elite twist line


## The rolled elite twist (`twist_name`, `twist_desc`) is shown on the elite door.
func open(kinds: Array, next_room: int, twist_name := "", twist_desc := "") -> void:
	var items: Array = []
	for k in kinds:
		var text: String = DOORS[k]
		if k == "elite" and twist_name != "":
			text = "Elite  ·  %s\n%s, 2 powers" % [twist_name, twist_desc]
		items.append([text, _pick.bind(k)])
	show_menu("CHOOSE YOUR PATH", "room %d" % next_room, items, "", 0.6)


func pick(index: int) -> void:
	if is_open() and index >= 0 and index < _buttons.size():
		_buttons[index].pressed.emit()


func _pick(kind: String) -> void:
	close_menu()
	chosen.emit(kind)
