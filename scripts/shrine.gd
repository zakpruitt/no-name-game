extends "res://scripts/menu_screen.gd"
## Shrine room: one trade from main.SHRINE (HP for a power, or bones for a
## full heal), or walk past. Emits `chosen` with a SHRINE key or "leave".

signal chosen(id: String)


func _ready() -> void:
	super()
	button_width = 620


## A trade is greyed out if it can't be paid: not enough bones, or the HP
## price would kill (or the heal would do nothing).
func open(shrine: Dictionary, hp: float, max_hp: float, bones: int) -> void:
	var items: Array = []
	for id in shrine:
		var s: Dictionary = shrine[id]
		var text: String = s.text
		var blocked := false
		if s.has("hp_frac"):
			var price := ceili(max_hp * s.hp_frac)
			text = text.format({"hp": price})
			blocked = hp <= price
		if s.has("cost"):
			text += "   (%d bones)" % s.cost
			blocked = blocked or bones < s.cost or (id == "mend" and hp >= max_hp)
		blocked = blocked or s.get("blocked", false)
		items.append([text, _pick.bind(id), blocked])
	items.append(["Walk on", _pick.bind("leave")])
	show_menu("SHRINE", "it asks for a price   ·   %d / %d HP   ·   %d bones" % [ceili(hp), ceili(max_hp), bones],
		items, "", 0.6)


## Press button `index` (autotest).
func pick(index: int) -> void:
	if is_open() and index >= 0 and index < _buttons.size() and not _buttons[index].disabled:
		_buttons[index].pressed.emit()


func is_disabled(index: int) -> bool:
	return index < 0 or index >= _buttons.size() or _buttons[index].disabled


func first_affordable() -> int:
	for i in _buttons.size():
		if not _buttons[i].disabled:
			return i
	return _buttons.size() - 1


func _pick(id: String) -> void:
	close_menu()
	chosen.emit(id)
