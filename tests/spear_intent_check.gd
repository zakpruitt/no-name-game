extends SceneTree
## Frost Spear on purpose only (ice-staff lane, 2026-11-07). Zak: "the ice staff can be a little buggy at times:
## accidentally triggering, and then when it's down you're stuck into bouncing on it to break it."
##   godot --headless --path . -s tests/spear_intent_check.gd [-- --probe]
## Rhythms: the hero is stepped by hand at 60 Hz (his physics off) and fed presses at human gaps, through
## hero_input.press() (what read_input does with a click); each hit connects. For each string and gap it prints the moves
## the presses started. `--probe` only prints the table (no PASS/FAIL), for a before / after.
##   - L L L H at any gap from 80 to 300 ms is Molten Palm (60 ms, a mash, can still be L L H), never Frost Spear (one buffer slot let the H overwrite the
##     third L still waiting, so the H came off L2: the spear).
##   - L L H at any gap is Frost Spear (the ender stays on its slot); L L L H H never plants (below ~150 ms its last H
##     outruns the two slots and is dropped: Molten Palm without Undertow).
## The spear standing (an option, not a trap; void_element.vaults):
##   - a fresh L facing away from it, or far from it, is a Slice; facing it near is the vault;
##   - L or H off the plant itself still vaults (L L H L / L L H H, the documented route), and Tow Line's presses go
##     on to Impale and Backdraft;
##   - off a vault that ended without Deep Freeze, the next press is the string, not another vault;
##   - walking off (> SPEAR_LEASH m for SPEAR_LEASH_S s) shatters it; a spear that ends shatters at once (no melt).

const DT := 1.0 / 60.0
const GAPS := [80, 90, 120, 150, 180, 210, 240, 270, 300]

var fails := 0
var probe := false
var world: Node3D
var hero: CharacterBody3D
var game: Node
var SPEAR: GDScript
var EL: GDScript


func _initialize() -> void:
	await process_frame
	probe = "--probe" in OS.get_cmdline_user_args()
	game = root.get_node("Game")
	SPEAR = load("res://scripts/frost_spear.gd")
	EL = load("res://scripts/void_element.gd")
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	hero = load("res://scripts/player.gd").new()
	world.add_child(hero)
	await process_frame
	hero.set_physics_process(false)
	hero.bot_enabled = true  # (no mouse: he faces bot_move / where he is told)
	_rhythms()
	if not probe:
		await _standing()
	print("spear_intent_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if probe:
		return
	if not ok:
		fails += 1
	print("[spear_intent] %s  %s" % ["ok  " if ok else "FAIL", what])


func _clear_spears() -> void:
	for s: Node in get_nodes_in_group(SPEAR.GROUP):
		s.remove_from_group(SPEAR.GROUP)
		s.queue_free()


func _reset() -> void:
	game.end_slowmo()
	hero._set_state(hero.State.MOVE)
	hero._move_id = ""
	hero._chain_i = 0
	hero._buffered = ""
	hero._buffer_t = 0.0
	if "_queued" in hero:
		hero._queued = ""
	hero._dash_buffer_t = 0.0
	hero._post_dash_t = 0.0
	hero._connected = false
	hero.velocity = Vector3.ZERO
	hero.bot_move = Vector3.ZERO
	hero.global_position = Vector3.ZERO
	hero.model.position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	_clear_spears()


func _press(kind: String) -> void:
	if hero.HERO_INPUT.has_method("press"):
		hero.HERO_INPUT.press(hero, kind)
	else:  # (the old read_input: one slot, the last press wins)
		hero._buffered = kind
		hero._buffer_t = hero.input_buffer


## Plays `presses` ("L"/"H"/"D") `gap` ms apart from standing; returns the moves they started, in order.
func _play(presses: Array, gap: int) -> Array:
	_reset()
	var started: Array = []
	var on_start := func(id: String) -> void: started.append(id)
	hero.attack_started.connect(on_start)
	var ms := 0.0
	var next_i := 0
	var since := 0.0
	while ms < 4000.0:
		if next_i < presses.size() and ms >= next_i * gap:
			var p: String = presses[next_i]
			if p == "D":
				hero._dash_buffer_t = hero.input_buffer
			else:
				_press("light" if p == "L" else "heavy")
			next_i += 1
		hero._physics_process(DT)
		if hero.state == hero.State.ATTACK and hero._hits_done > 0:
			hero._connected = true
		ms += DT * 1000.0
		if next_i >= presses.size() and hero.state == hero.State.MOVE and hero._buffered == "":
			since += DT
			if since > 0.2:
				break
	hero.attack_started.disconnect(on_start)
	_clear_spears()
	return started


func _rhythms() -> void:
	var table := {"L L L H": [["L", "L", "L", "H"], "EM"], "L L H": [["L", "L", "H"], "IP"], "L H": [["L", "H"], "EC"],
		"L L L L L H": [["L", "L", "L", "L", "L", "H"], ""], "D L L H": [["D", "L", "L", "H"], ""], "L L L H H": [["L", "L", "L", "H", "H"], ""]}
	for name: String in table:
		var row := "%-12s" % name
		var bad := []
		for gap: int in GAPS:
			var got := _play(table[name][0], gap)
			row += " %d:%s" % [gap, "-".join(got)]
			var want: String = table[name][1]
			if want != "" and (got.is_empty() or got[-1] != want):
				bad.append("%d ms -> %s" % [gap, "-".join(got)])
		print("[rhythm] " + row)
		if table[name][1] != "":
			_check(bad.is_empty(), "%s at every gap ends on %s %s" % [name, table[name][1], bad])
		if name in ["L L L H", "L L L H H"]:
			_check(not row.contains("IP"), "a fast %s never plants the spear" % name)


## A press from standing with the spear at `spot`, him facing `face`. Returns the move it started.
func _fresh(kind: String, spot: Vector3, face: Vector3, from := "") -> String:
	_reset()
	hero._move_id = from
	SPEAR.plant(world, spot)
	hero._face(face)
	hero.model.rotation.y = hero._facing_yaw
	_press(kind)
	for i in 3:
		hero._physics_process(DT)
	return hero._move_id


func _standing() -> void:
	var at := Vector3(0, 0, 2.5)
	_check(_fresh("light", at, Vector3(0, 0, 1)) == "IJ", "spear 2.5 m ahead, L facing it: the vault")
	_check(_fresh("heavy", at, Vector3(0, 0, 1)) == "IJ", "and H facing it: the vault")
	_check(_fresh("light", at, Vector3(0, 0, -1)) == "L1", "L facing away: Slice")
	_check(_fresh("light", at, Vector3(1, 0, 0)) == "L1", "L across it: Slice")
	_check(_fresh("light", Vector3(0, 0, 6.0), Vector3(0, 0, 1)) == "L1", "L facing one 6 m off: Slice")
	_check(_fresh("light", Vector3(0, 0, 6.0), Vector3(0, 0, 1), "IP") == "IJ", "but off his own plant, facing it 6 m off: the vault")
	_check(_fresh("light", Vector3(0, 0, 6.0), Vector3(0, 0, -1), "IP") == "L1", "off his plant facing away: Slice")
	_check(_fresh("light", at, Vector3(0, 0, 1), "IJ") == "L1", "off a vault that came down without Deep Freeze: Slice, not another vault")
	_check(_fresh("heavy", at, Vector3(0, 0, 1), "IJ") == "GR", "and H there is the grab")
	_reset()
	SPEAR.plant(world, at)
	var r: Callable = hero.HERO_MOVES.routed
	_check(r.call(hero, "light", "IP", true, 0, false) == "IJ", "L off the plant: the vault (L L H L)")
	_check(r.call(hero, "heavy", "IP", true, 0, false) == "IJ", "H off the plant: the vault (L L H H)")
	_check(r.call(hero, "heavy", "IJ", true, 0, false) == "IS", "H off the vault: Deep Freeze")
	_check(r.call(hero, "light", "L1", true, 1, false) == "L2", "mid-string L near it: the string goes on")
	_check(r.call(hero, "heavy", "L2", true, 2, false) == "IP", "mid-string L L H: plants again")
	_check(r.call(hero, "heavy", "TW", true, 0, false) == "XK", "Tow Line's H: Impale")
	_check(r.call(hero, "light", "XK", true, 0, false) == "XW", "Impale's L: Backdraft")
	_check(r.call(hero, "heavy", "", false, 0, true) == "TW", "a dash's H: Tow Line")
	# Walking off leaves it behind: past SPEAR_LEASH for SPEAR_LEASH_S it shatters.
	_reset()
	var s: Node3D = SPEAR.plant(world, at)
	hero.global_position = Vector3(0, 0, -SPEAR.LEASH - 1.0)
	await create_timer(SPEAR.LEASH_S * 0.5).timeout
	_check(SPEAR.current(self) == s, "still up half a leash later")
	await create_timer(SPEAR.LEASH_S * 0.5 + 0.2).timeout
	_check(SPEAR.current(self) == null, "he walked off: it shatters")
	await process_frame
	_check(not is_instance_valid(s) or s.is_queued_for_deletion(), "and is gone at once, not lying there")
	# Its life over: gone at once.
	_reset()
	s = SPEAR.plant(world, at)
	hero.global_position = at + Vector3(1, 0, 0)
	await create_timer(SPEAR.LIFE + 0.1).timeout
	await process_frame
	_check(not is_instance_valid(s), "after LIFE it is gone the same frame (no melt lying about)")
	_reset()
