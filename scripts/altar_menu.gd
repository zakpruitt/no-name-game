extends RefCounted
## Builds the bone altar's menu items for title_screen.gd: one button per
## boon (level, next cost; greyed out when maxed or unaffordable) and Back.

const ALTAR := preload("res://scripts/altar.gd")


## `refresh` reopens the altar after a purchase; `back` returns to the title.
static func items(refresh: Callable, back: Callable) -> Array:
	var bank: int = ALTAR.load_altar().bank
	var list: Array = []
	for id: String in ALTAR.BOONS:
		var lv := ALTAR.level(id)
		var max_lv: int = ALTAR.BOONS[id].cost.size()
		var cost := ALTAR.next_cost(id)
		var text := "%s   %d/%d" % [ALTAR.describe(id), lv, max_lv]
		text += "   (max)" if cost < 0 else "   (%d bones)" % cost
		list.append([text, func() -> void:
			ALTAR.buy(id)
			refresh.call(), cost < 0 or bank < cost])
	list.append(["Back", back])
	return list


static func subtitle() -> String:
	return "%d bones banked   ·   leftover bones are banked when a run ends" % ALTAR.load_altar().bank
