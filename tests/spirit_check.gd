extends SceneTree
## The spirit gate (docs/features/spirits.md): what void_route() starts with no spirit, with each one, and with
## everything open. Prints `[spirit] PASS/FAIL`.
## godot --headless --path . -s tests/spirit_check.gd

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var M: GDScript = load("res://scripts/hero_moves.gd")
	# everything open (the tests' and the autotest's default): the storm launcher off the axe
	Spirits.set_all(true)
	_is(M.void_route("heavy", "L1", true, 1, false), "EC", "all: L H is Updraft")
	# no spirit: the base kit. Element enders fall back to the grab, the dark moves stay.
	Spirits.set_all(false)
	Spirits.claim("")
	_is(M.void_route("heavy", "L1", true, 1, false), "GR", "none: L H falls back to the grab")
	_is(M.void_route("heavy", "L2", true, 2, false), "GR", "none: L L H falls back to the grab")
	_is(M.void_route("heavy", "L3", true, 0, false), "GR", "none: L L L H falls back to the grab")
	_is(M.void_route("heavy", "GR", true, 0, false), "VS", "none: H H is still Singularity")
	_is(M.void_route("light", "GR", true, 0, false), "VR", "none: H L is still Reap")
	_is(M.void_route("heavy", "", false, 0, true), "TW", "none: Dash H is still Tow Line")
	_is(M.void_route("heavy", "TW", true, 0, false), "GR", "none: Impale (ice) is closed")
	_is(M.void_route("light", "", false, 0, false), "L1", "none: the light string plays")
	# one spirit opens its element and its crossover with dark, and nothing else
	for row: Array in [["wind", "L1", "EC", "L2", "VR", "XC"], ["water", "L2", "IP", "L3", "", ""], ["earth", "L3", "EM", "L1", "EM", "XL"]]:
		Spirits.claim(row[0])
		_is(M.void_route("heavy", row[1], true, 0, false), row[2], "%s: its ender opens" % row[0])
		_is(M.void_route("heavy", row[3], true, 0, false), "GR", "%s: another element's ender stays closed" % row[0])
		if row[4] != "":
			_is(M.void_route("light", row[4], true, 0, false), row[5], "%s: its crossover with dark opens" % row[0])
	Spirits.claim("wind")
	_check(not Spirits.allows("XF"), "storm alone doesn't open Fault Line (storm x magma)")
	_check(not Spirits.allows("XR"), "storm alone doesn't open the step into Fault Line")
	_check(Spirits.allows("EE") and Spirits.allows("EW"), "storm opens its big moves")
	Spirits.claim("water")
	_check(Spirits.allows("XK") and Spirits.allows("XW") and Spirits.allows("IJ"), "ice opens Impale, Backdraft and the vault")
	_check(not Spirits.allows("XG"), "ice alone doesn't open Hailstorm (ice x storm)")
	# the bond prompt's list: what each spirit opens, its breakers' endings, nothing from another element
	var storm := Spirits.offers("wind")
	_is(_ids(storm.combos), "EC EE EW XC", "storm offers its ender, big moves and Dark x storm")
	_is(_names(storm.breakers), "Grounded, Short Circuit, Worldbreaker, Cold Front", "storm offers its windows' endings")
	_is(_ids(Spirits.offers("water").combos), "IP IS EF XK XW IJ EA", "ice offers its moves, then its route steps")
	_is(_ids(Spirits.offers("earth").combos), "EM EV XL", "magma offers its moves and Lava Leash")
	var harpoon: Dictionary = Spirits.offers("water").breakers[1]
	_is(harpoon.input, "Dash L H, pause, H", "a paused window's input says so")
	_is(harpoon.element, "wind", "an ending wears the element it lands in")
	# the prompt itself: it pauses, Bond runs the claim, Esc's close doesn't
	Spirits.claim("")
	var prompt: Node = (load("res://scripts/bond_prompt.gd") as GDScript).new()
	root.add_child(prompt)
	prompt.call("ask", "water", Spirits.claim.bind("water"))
	_check(prompt.call("is_open") and paused, "the prompt opens and pauses")
	prompt.call("close_menu")
	_check(Spirits.held == "" and not paused, "closing it claims nothing and unpauses")
	prompt.call("ask", "water", Spirits.claim.bind("water"))
	var buttons: Array = prompt.get("_buttons")
	(buttons[0] as Button).pressed.emit()
	_check(Spirits.held == "water" and not paused and not prompt.call("is_open"), "Bond claims it and closes")
	Spirits.claim("wind")
	prompt.call("ask", "earth", Spirits.claim.bind("earth"))  # (the swap line's path)
	prompt.call("close_menu")
	prompt.queue_free()
	Spirits.claim("")
	Spirits.set_all(true)
	for f in _fails:
		print("[spirit] FAIL ", f)
	print("[spirit] %s" % ("PASS" if _fails.is_empty() else "FAIL %d" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)


func _ids(rows: Array) -> String:
	return " ".join(rows.map(func(r: Dictionary) -> String: return r.id))


func _names(rows: Array) -> String:
	return ", ".join(rows.map(func(r: Dictionary) -> String: return r.name))


func _is(got: String, want: String, what: String) -> void:
	_check(got == want, "%s (got %s, want %s)" % [what, got, want])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
