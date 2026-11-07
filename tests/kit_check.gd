extends SceneTree
## The kit check (round 49, docs/features/kit-slots.md): the heretic's card (scripts/kit_slots.gd) against the kit
## grammar (docs/characters/kit-grammar.md section 2) and the real routing (hero_moves.void_route):
##   every slot filled with a move whose input starts it (pending slots named), inputs in the slot's shape,
##   every breaker window on a slot with at most two endings (at most 15 windows), at most six crossovers with
##   distinct colour pairs, every MOVES id on the card, every slot and upgrade with a bot string, and the demoted
##   moves unreachable with their upgrade off and reachable with it on.
## Prints `[kit] PASS/FAIL`.
## godot --headless --path . -s tests/kit_check.gd

## Slots allowed empty for now: their lanes (counter, dark-magma) fill them.
const PENDING_OK := ["counter", "cross_dark_magma"]
const MAX_WINDOWS := 15
const MAX_ENDINGS := 2
const MAX_CROSS := 6

var MOVES_GD: GDScript
var VOID: GDScript
var BOT: GDScript
var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	MOVES_GD = load("res://scripts/hero_moves.gd")
	VOID = load("res://scripts/void_element.gd")
	BOT = load("res://scripts/training_bot.gd")
	var card: Dictionary = KitSlots.HERETIC
	for u: String in Kit.UPGRADES:
		Kit.set_on(u, false)
	_check_slots(card)
	_check_shapes(card)
	_check_windows(card)
	_check_crossovers(card)
	_check_complete(card)
	_check_bot(card)
	_check_gates(card)
	_check_prince()
	var filled := KitSlots.SLOTS.filter(func(s: Dictionary) -> bool: return not card.fill[s.id].is_empty())
	print("[kit] slots filled=%d/%d pending=%s" % [filled.size(), KitSlots.SLOTS.size(),
		",".join(KitSlots.SLOTS.filter(func(s: Dictionary) -> bool: return KitSlots.pending(card, s.id)).map(func(s: Dictionary) -> String: return s.id))])
	print("[kit] PASS" if _fails.is_empty() else "[kit] FAIL " + "; ".join(_fails))
	quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)


## Every slot is on the card, filled (or allowed pending), and each fill's input starts its move.
func _check_slots(card: Dictionary) -> void:
	var ids := {}
	for s: Dictionary in KitSlots.SLOTS:
		_check(not ids.has(s.id), "slot %s twice" % s.id)
		ids[s.id] = true
		_check(s.group >= 1 and s.group <= KitSlots.GROUPS.size() and s.tag != "" and s.role != "", "slot %s has a group, tag and role" % s.id)
		_check(card.fill.has(s.id), "the heretic's card has slot %s" % s.id)
		var fill: Dictionary = card.fill.get(s.id, {})
		if fill.is_empty():
			_check(s.get("meter", false) or s.id in PENDING_OK, "slot %s is empty" % s.id)
			continue
		for id: String in fill:
			_check(MOVES_GD.MOVES.has(id), "%s's %s is a move" % [s.id, id])
			var got := _press(fill[id])
			_check(got == id, "%s: '%s' starts %s, not %s" % [s.id, fill[id], got, id])
	for s: String in card.fill:
		_check(ids.has(s), "the card fills %s, not a slot" % s)
	for id: String in card.route:
		_check(_press(card.route[id]) == id, "route step %s: '%s' starts %s" % [id, card.route[id], _press(card.route[id])])


## Inputs match the slot's shape (KitSlots.SLOTS `shape`): exact, "*" = one route step's press between the ender and
## the last H, "+" = one press off another move or route step on the card (a crossover's extension).
func _check_shapes(card: Dictionary) -> void:
	for s: Dictionary in KitSlots.SLOTS:
		for id: String in card.fill.get(s.id, {}):
			var input: String = card.fill[s.id][id]
			var ok := false
			for shape: String in s.shape:
				if shape == input:
					ok = true
				elif shape == "+":
					var cut := input.rfind(" ")
					ok = ok or (cut > 0 and _on_card(card, input.substr(0, cut)) and input.substr(cut + 1) in ["L", "H"])
				elif shape.contains("*"):
					var head: String = shape.get_slice("*", 0).strip_edges()
					var tail: String = shape.get_slice("*", 1).strip_edges()
					if input.begins_with(head + " ") and input.ends_with(" " + tail):
						ok = ok or card.route.values().has(input.substr(0, input.length() - tail.length() - 1))
			_check(ok, "%s's %s input '%s' isn't in the slot's shape %s" % [s.id, id, input, s.shape])


## An input that some move or route step on the card is started by.
func _on_card(card: Dictionary, input: String) -> bool:
	if card.route.values().has(input):
		return true
	for s: String in card.fill:
		if card.fill[s].values().has(input):
			return true
	return false


## Every breaker window is on a slot's move (never a route step or an upgrade), with one or two endings.
func _check_windows(card: Dictionary) -> void:
	var n := 0
	for key: String in VOID.BREAKERS:
		var s := KitSlots.slot_of(key, card)
		_check(s != "", "breaker %s isn't on a slot's move" % key)
		var b: Dictionary = VOID.BREAKERS[key]
		var endings := 1 + (1 if b.has("alt") else 0)
		_check(endings <= MAX_ENDINGS, "%s has %d endings" % [key, endings])
		if s != "":
			_check(str(KitSlots.slot(s).window) != "false", "%s has a window but slot %s has none in the grammar" % [key, s])
		n += 1
	_check(n <= MAX_WINDOWS, "%d windows (the grammar allows %d)" % [n, MAX_WINDOWS])
	# (the grammar gives these a window; the heretic hasn't one yet: noted, not failed)
	var open := []
	for s: Dictionary in KitSlots.SLOTS:
		if str(s.window) == "true" and not card.fill[s.id].is_empty() and not card.fill[s.id].keys().any(func(id: String) -> bool: return VOID.BREAKERS.has(id)):
			open.append(s.id)
	print("[kit] windows=%d/%d; window slots with no breaker yet: %s" % [n, MAX_WINDOWS, ", ".join(open) if not open.is_empty() else "none"])


## At most six crossovers, one per colour pair, and the pair's two elements on the move's route.
func _check_crossovers(card: Dictionary) -> void:
	var pairs := {}
	var n := 0
	for s: Dictionary in KitSlots.SLOTS:
		if s.group != 8:
			continue
		n += 1
		var pair: Array = s.pair.duplicate()
		pair.sort()
		var key := "-".join(pair)
		_check(not pairs.has(key), "two crossover slots for %s" % key)
		pairs[key] = true
		var colours := [card.signature] + Array(card.elements)
		_check(colours.has(s.pair[0]) and colours.has(s.pair[1]) and s.pair[0] != s.pair[1], "%s's pair is two of the card's colours" % s.id)
		for id: String in card.fill[s.id]:
			var els := _route_elements(card.fill[s.id][id])
			_check(els.has(s.pair[0]) and els.has(s.pair[1]), "%s's %s route has %s and %s (%s)" % [s.id, id, s.pair[0], s.pair[1], els])
	_check(n <= MAX_CROSS, "%d crossover slots" % n)


## Every move in MOVES is on the card: a slot, a route step or an upgrade.
func _check_complete(card: Dictionary) -> void:
	for id: String in MOVES_GD.MOVES:
		var on: bool = KitSlots.slot_of(id, card) != "" or card.route.has(id) or KitSlots.upgrade_of(id, card) != ""
		_check(on, "%s isn't on the heretic's card" % id)
	for u: String in card.upgrades:
		_check(Kit.UPGRADES.has(u), "upgrade %s isn't in Kit.UPGRADES" % u)
		_check(card.upgrades[u].gates in ["route", "payoff"], "upgrade %s gates route or payoff" % u)


## Every BOT_STRINGS entry names a slot (or "step") or an upgrade; every filled slot and every upgrade has one.
func _check_bot(card: Dictionary) -> void:
	var labelled := {}
	for b: Dictionary in BOT.BOT_STRINGS:
		_check(b.has("tokens") and (b.has("slot") or b.has("upgrade")), "bot string %s has a slot label" % b)
		if b.has("slot"):
			for l: String in BOT.labels_of(b):
				_check(l == "step" or not KitSlots.slot(l).is_empty(), "bot string slot %s is a slot" % l)
				labelled[l] = true
		if b.has("upgrade"):
			_check(card.upgrades.has(b.upgrade), "bot string upgrade %s is the card's" % b.upgrade)
			labelled[b.upgrade] = true
	for s: Dictionary in KitSlots.SLOTS:
		if not card.fill[s.id].is_empty():
			_check(labelled.has(s.id), "slot %s has no bot string" % s.id)
	for u: String in card.upgrades:
		_check(labelled.has(u), "upgrade %s has no bot string" % u)


## Demoted moves: a "route" gate's move is unreachable with its upgrade off (by its input and by any presses from
## neutral) and starts from its input with it on; a "payoff" gate's move routes either way (the step stays).
func _check_gates(card: Dictionary) -> void:
	for u: String in card.upgrades:
		var up: Dictionary = card.upgrades[u]
		for on: bool in [false, true]:
			Kit.set_on(u, on)
			var reached := _reachable()
			for id: String in up.moves:
				var got := _press(up.moves[id])
				if up.gates == "route" and not on:
					_check(got != id and not reached.has(id), "%s reachable with %s off" % [id, u])
				else:
					_check(got == id and reached.has(id), "%s ('%s') not reachable with %s %s (got %s)" % [id, up.moves[id], u, "on" if on else "off", got])
		Kit.set_on(u, false)


## The prince's card is a TODO (paused): shaped like the heretic's, its filled moves his own.
func _check_prince() -> void:
	var card: Dictionary = KitSlots.of("prince")
	_check(card.get("todo", false), "the prince's card is marked todo until his lane fills it")
	for s: Dictionary in KitSlots.SLOTS:
		_check(card.fill.has(s.id), "the prince's card has slot %s" % s.id)
	var pm: GDScript = load("res://scripts/prince/prince_moves.gd")
	for s: String in card.fill:
		for id: String in card.fill[s]:
			_check(pm.MOVES.has(id), "the prince's %s %s is one of his moves" % [s, id])


## The elements along an input's moves (ELEMENT_OF, the weapons' WEAPON_ELEMENT).
func _route_elements(input: String) -> Array:
	var out := []
	for id: String in _walk(input):
		var el: String = VOID.ELEMENT_OF.get(id, MOVES_GD.WEAPON_ELEMENT.get(id, ""))
		if el != "" and not out.has(el):
			out.append(el)
	return out


## Every move void_route() reaches by any presses from neutral (move_list_check's search).
func _reachable() -> Dictionary:
	var seen := {}
	var reached := {}
	var todo: Array = [{"from": "", "attacking": false, "chain": 0, "post_dash": false}]
	while not todo.is_empty():
		var s: Dictionary = todo.pop_back()
		var key := str(s)
		if seen.has(key):
			continue
		seen[key] = true
		if s.attacking:
			var waited: Dictionary = s.duplicate()
			waited.attacking = false
			todo.append(waited)
			var dashed: Dictionary = waited.duplicate()
			dashed.post_dash = true
			todo.append(dashed)
		for kind: String in ["light", "heavy"]:
			var id: String = MOVES_GD.void_route(kind, s.from, s.attacking, s.chain, s.post_dash)
			reached[id] = true
			todo.append({"from": id, "attacking": true, "chain": MOVES_GD.chain_after(id), "post_dash": false})
	return reached


func _press(input: String) -> String:
	var walked := _walk(input)
	return walked[-1] if not walked.is_empty() else ""


## The moves an input starts, in order, through the same void_route() the game uses ("hold H" = Overwhelm).
func _walk(input: String) -> Array:
	var out := []
	var from := ""
	var attacking := false
	var chain := 0
	var post_dash := false
	var tokens := input.replace(",", " ").split(" ", false)
	var i := 0
	while i < tokens.size():
		var t: String = tokens[i]
		i += 1
		match t:
			"Dash":
				post_dash = true
				attacking = false
			"hold":
				i += 1
				out.append(VOID.CHARGED)
			"L", "H":
				var id: String = MOVES_GD.void_route("light" if t == "L" else "heavy", from, attacking, chain, post_dash)
				out.append(id)
				from = id
				attacking = true
				chain = MOVES_GD.chain_after(id)
				post_dash = false
			_:
				_check(false, "unknown token %s in '%s'" % [t, input])
	return out
