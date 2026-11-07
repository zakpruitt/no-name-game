extends SceneTree
## The void arm, headless: right click's routing and targeting, the grab pulling a foe in, the big foe
## pulling him, R's swings and fling, a dash out of one, the slam, the strings and their breakers, thrown
## ice cubes, and the arm's shapes per move.
## Runs the real comic hero against stand-in foes. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/void_arm_check.gd

var fails := 0
var world: Node3D
var hero: CharacterBody3D
var GRAB: GDScript


class Foe extends CharacterBody3D:
	var radius := 0.5
	var hp := 500.0
	var elite := false
	var hits := 0
	var last_big := false
	var frozen := false
	var up := false  # in the air (the crossovers read it)
	var last_kb := Vector3.ZERO
	var last_launch := 0.0
	var chill_t := 0.0
	func chill(t: float, _m: float) -> void: chill_t = t
	func freeze(_t: float, _m: float) -> void: frozen = true
	func is_alive() -> bool: return hp > 0.0
	func is_airborne() -> bool: return up
	func stagger(_t: float) -> void: pass
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, big = false, _x = null) -> void:
		hp -= d
		hits += 1
		last_big = big
		last_kb = _kb
		last_launch = _l


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.comic_style = true
	GRAB = load("res://scripts/void_grab.gd")
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
	_check(hero._void != null, "the comic hero has a void arm")
	_routing()
	_picking()
	_shapes_at_rest()
	await _grab()
	await _pull()
	await _swing()
	await _sky_swing()
	await _swing_into_wall()
	await _dash_out()
	await _slam()
	await _whiff()
	await _elements()
	await _breakers()
	await _cold_front()
	await _short_circuit()
	await _breaker_choice()
	await _thrown_at_wall()
	await _ice()
	await _magma()
	await _meteor_target()
	await _dark()
	await _crossovers()
	await _three_elements()
	await _breaker_pairs()
	await _element_matrix()
	await _tentacle_alone()
	await _snatch()
	print("void_arm_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _routing() -> void:
	var r: Callable = load("res://scripts/hero_moves.gd").void_route
	_check(not InputMap.has_action("special"), "E is gone")
	_check(InputMap.has_action("traverse"), "R is bound")
	_check(r.call("light", "", false, 0, false) == "L1", "L: axe")
	_check(r.call("light", "L1", true, 1, false) == "L2", "L L: spear")
	_check(r.call("light", "L2", true, 2, false) == "L3", "L L L: hammer")
	_check(r.call("heavy", "", false, 0, false) == "GR", "right click alone: the grab")
	_check(r.call("heavy", "GR", true, 0, false) == "VS", "H H: Singularity")
	_check(r.call("light", "GR", true, 0, false) == "VR", "H L: Reap")
	_check(r.call("heavy", "VR", true, 0, false) == "VD", "H L H: Black Tide")
	_check(r.call("heavy", "VS", true, 0, false) == "GR", "right click off the slam grabs again")
	_check(r.call("heavy", "EF", true, 2, false) == "EA", "Dash L H H: Ice Cube")
	_check(r.call("heavy", "EM", true, 0, false) == "EV", "L L L H H: Undertow")
	_check(r.call("heavy", "L1", false, 1, false) == "GR", "right click after the string has lapsed: the grab")
	_check(r.call("heavy", "", false, 0, true) == "TW", "dash right click: Tow Line")
	_check(r.call("light", "GR", false, 0, false) == "L1", "after a grab has finished, L is the string")
	_check(r.call("light", "", false, 0, true) == "DL", "dash L: the spear lunge")
	_check(r.call("heavy", "L1", true, 1, false) == "EC", "L H: Updraft Lash")
	_check(r.call("heavy", "EC", true, 0, false) == "EE", "L H H: Live Wire")
	_check(r.call("light", "EC", true, 0, false) == "AL1", "L H L: up into the air")
	_check(r.call("light", "EC", false, 0, false) == "L1", "the air's only there while the lash is going")
	_check(r.call("heavy", "AL1", true, 0, false) == "EW", "L H L H: Live Wire from the air")
	_check(r.call("heavy", "L2", true, 2, false) == "IP", "L L H: the spear goes in")
	_check(r.call("heavy", "IP", true, 0, false) == "IJ", "L L H H: he vaults too, not the bowl")
	_check(r.call("light", "IP", true, 0, false) == "IJ", "L L H L: he vaults")
	_check(r.call("heavy", "IJ", true, 0, false) == "IS", "L L H L H: onto the spear")
	_check(r.call("heavy", "L3", true, 0, false) == "EM", "L L L H: magma")
	_check(r.call("heavy", "DL", true, 1, false) == "EF", "dash L H: Harpoon")
	for id: String in ["GR", "VS", "EC", "EE", "EW", "EF", "IP", "IJ", "IS", "EA", "EM", "EV", "VR", "VD", "OW", "TW"]:
		_check(hero.anim.has_animation(hero._clip_name(hero.MOVES[id].anim)), "%s has its clip" % id)
	# The pause menu lists every move he can reach, and only real ones.
	var list: GDScript = load("res://scripts/move_list.gd")
	var listed := {}
	for section: Dictionary in list.SECTIONS:
		for row: Dictionary in section.rows:
			_check(not row.input.contains("E"), "no E on the menu: %s" % row.input)
			if row.kind == "move":
				listed[row.id] = true
				_check(hero.MOVES.has(row.id) or hero.COMBOS.has(row.id), "listed move %s exists" % row.id)
	for id: String in ["L1", "L2", "L3", "DL", "VS", "EC", "EE", "AL1", "EW", "EF", "IP", "IS", "EA", "EM", "EV", "VR", "VD", "OW", "TW"]:
		_check(listed.has(id), "%s is on his move list" % id)
	_check(hero.COMBOS.EW.tier == 3, "the showcase is top tier")


func _picking() -> void:
	var near := _foe(Vector3(0, 0, 4))
	var off := _foe(Vector3(6, 0, 0))
	var far := _foe(Vector3(0, 0, 20))
	var pillar := Node3D.new()
	world.add_child(pillar)
	pillar.global_position = Vector3(0, 0, 5)
	var at := Vector3.ZERO
	var ahead := Vector3(0, 0, 1)
	_check(GRAB.pick(at, ahead, [near, off, far], [pillar]).node == near, "a foe beats a pillar a little past it")
	hero.global_position = Vector3.ZERO
	hero._face(ahead)
	pillar.add_to_group("grab_anchors")
	_check(hero._void._pick_now().node == near, "right click goes for the foe")
	near.remove_from_group("enemies")
	_check(hero._void._pick_now().node != pillar, "right click never goes for a pillar")
	near.add_to_group("enemies")
	_check(GRAB.pick(at, ahead, [off, far], [pillar]).node == pillar, "foes out of the cone or range: the pillar")
	_check(GRAB.pick(at, ahead, [off, far], []).kind == "none", "nothing there: a whip")
	near.elite = true
	_check(GRAB.pick(at, ahead, [near], []).kind == "heavy", "an elite is too big to throw")
	near.free()
	off.free()
	far.free()
	pillar.free()


func _shapes_at_rest() -> void:
	var arm: Node = hero._void.arm
	_check(arm.form == "hand", "he rests with a free tentacle")
	var look: GDScript = load("res://scripts/comic_look.gd")
	for form: String in look.HERO_FORMS:
		for part: String in look.HERO_FORMS[form]:
			var mi: MeshInstance3D = hero.model.find_child(part, true, false)
			_check(mi != null, "%s: mesh %s" % [form, part])
			if mi != null:
				_check(not mi.visible, "%s hidden at rest" % part)
	for id: String in ["L1", "L2", "L3"]:
		hero._start_attack(id)
		var want: String = look.HERO_MOVE_FORMS.get(id, "axe")
		_check(arm.form == want, "%s: the arm is %s (%s)" % [id, want, arm.form])
		_check(hero.anim.current_animation != "", "%s plays" % id)
		var head: MeshInstance3D = hero.model.find_child(look.HERO_FORMS[want][0], true, false)
		_check(head.visible, "%s: its form is showing" % id)
	hero._set_state(hero.State.MOVE)
	_check(arm.form == "hand", "back to moving: the tentacle")


func _grab() -> void:
	var f := _foe(hero.global_position + Vector3(0, 0, 6))
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("GR")
	_check(hero.state == hero.State.ATTACK and hero._move_id == "GR", "right click at a foe plays the grab")
	_check(hero._void.arm.form == "hand", "the axe lets go for the grab")
	var start := f.global_position
	await _until(func() -> bool: return f.hits > 0, 1.0)
	_check(f.hits == 1, "the tentacle lands one hit")
	_check(hero._void.tendril.visible, "the tentacle is drawn")
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 2.0)
	var d: float = f.global_position.distance_to(hero.global_position)
	_check(d < 2.2 and d < start.distance_to(hero.global_position), "the foe was yanked to him (%.2f m)" % d)
	_check(not hero._void.tendril.visible, "the tentacle's away after")
	f.free()


func _pull() -> void:
	var f := _foe(hero.global_position + Vector3(0, 0, 7))
	f.elite = true
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("GR")
	_check(hero.state == hero.State.SWING, "right click at something big sends him travelling")
	await _until(func() -> bool: return hero.state != hero.State.SWING, 1.5)
	var d: float = f.global_position.distance_to(hero.global_position)
	_check(d < 3.0, "he got to it (%.2f m)" % d)
	_check(f.global_position.distance_to(hero.global_position + Vector3(0, 0, d)) < 1.5, "it didn't move")
	_check(hero._move_id == "L1" and hero.state == hero.State.ATTACK, "he arrives swinging")
	f.free()
	await _settle()


func _press_r() -> void:
	hero._swing_cd = 0.0
	hero._swing_buffer_t = 0.2
	await physics_frame
	await physics_frame


func _swing() -> void:
	hero.global_position = Vector3.ZERO
	var p := Node3D.new()
	world.add_child(p)
	p.add_to_group("grab_anchors")
	p.global_position = Vector3(0, 0, 4)
	hero._face(Vector3(0, 0, 1))
	var f := _foe(Vector3(3.2, 0, 7))
	await _press_r()
	_check(hero.state == hero.State.SWING and hero._void._kind == "swing", "R at a pillar swings round it")
	_check(hero._invuln_t <= 0.0, "with no invulnerability")
	var peak := 0.0
	var moved := 0.0
	var last := hero.global_position
	var frames := 0
	while hero.state == hero.State.SWING and frames < 200:
		await physics_frame
		frames += 1
		peak = maxf(peak, hero.model.position.y)
		moved += hero.global_position.distance_to(last)
		last = hero.global_position
	_check(frames < 200, "the swing ends by itself")
	_check(peak > 0.8, "he lifts off the floor (%.2f m)" % peak)
	_check(moved > 6.0, "he travels round it (%.2f m)" % moved)
	var fly := Vector2(hero.velocity.x, hero.velocity.z).length()
	_check(hero.state == hero.State.MOVE and fly > 12.0, "he's flung off at speed (%.1f m/s)" % fly)
	_check(hero._next_move("light") == "DL", "a press off the fling is the lunge")
	f.free()
	p.free()
	await _settle()


## With nothing to latch onto it still goes, and a hold goes further than a tap.
func _sky_swing() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	await _press_r()
	_check(hero.state == hero.State.SWING and hero._void._kind == "sky", "R with nothing there still swings")
	_check(hero._void.tendril.visible, "the tentacle goes up")
	_check(hero._void._pivot.y > 8.0, "off the top of the screen (%.1f m)" % hero._void._pivot.y)
	await _until(func() -> bool: return hero.state != hero.State.SWING, 2.0)
	var tap := Vector3(hero.global_position.x, 0, hero.global_position.z).length()
	_check(tap > 2.5, "a tap carries him (%.1f m)" % tap)
	var fly := Vector2(hero.velocity.x, hero.velocity.z).length()
	_check(fly > 12.0, "and flings him (%.1f m/s)" % fly)
	_check(hero._next_move("light") == "DL", "L off it is the lunge")
	await _settle()
	var before: Vector3 = hero.global_position
	hero._swing_cd = 0.5
	hero._swing_buffer_t = 0.2
	await physics_frame
	await physics_frame
	_check(hero.state == hero.State.MOVE, "R waits out its cooldown")
	hero._swing_buffer_t = 0.0
	hero.global_position = before
	hero._face(Vector3(0, 0, 1))
	Input.action_press("traverse")
	await _press_r()
	await _until(func() -> bool: return hero.state != hero.State.SWING, 2.0)
	Input.action_release("traverse")
	var held: float = (hero.global_position - before).length()
	_check(held > tap + 2.0, "holding R goes further (%.1f m, a tap %.1f m)" % [held, tap])
	await _settle()
	hero.global_position = Vector3.ZERO
	var f := _foe(Vector3(0, 0, 3))
	await _press_r()
	await _until(func() -> bool: return hero.state != hero.State.SWING, 2.0)
	_check(f.hits == 1, "what he swings through takes one hit (%d)" % f.hits)
	f.free()
	await _settle()
	hero._start_attack("L1")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	await _press_r()
	_check(hero.state == hero.State.SWING, "R cuts an attack once it has hit")
	await _settle()


func _swing_into_wall() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var wall := _wall(Vector3(0, 1, 2.5))
	await _press_r()
	await _until(func() -> bool: return hero.state != hero.State.SWING, 2.0)
	_check(hero.state == hero.State.MOVE, "a wall ends the swing")
	_check(hero.global_position.z < 2.5, "he doesn't go through it (%.1f m)" % hero.global_position.z)
	wall.free()
	await _settle()


func _dash_out() -> void:
	hero.global_position = Vector3.ZERO
	var p := Node3D.new()
	world.add_child(p)
	p.add_to_group("grab_anchors")
	p.global_position = Vector3(0, 0, 4)
	hero._face(Vector3(0, 0, 1))
	hero._dash_cd = 0.0
	await _press_r()
	hero._dash_buffer_t = 0.2
	await physics_frame
	await physics_frame
	_check(hero.state == hero.State.DASH, "a dash cuts the swing")
	_check(not hero._void.tendril.visible, "and lets go")
	p.free()
	await _settle()


func _slam() -> void:
	hero.global_position = Vector3.ZERO
	var f := _foe(Vector3(0, 0, 2))
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("VS")
	_check(hero._move_id == "VS", "the slam has its name")
	var top := 0.0
	var frames := 0
	while f.hits == 0 and frames < 120:
		await physics_frame
		frames += 1
		top = maxf(top, f.global_position.y)
	_check(top > 2.0, "the foe goes up overhead (%.2f m)" % top)
	_check(f.hits > 0 and f.last_big, "and comes down hard")
	_check(absf(f.global_position.y) < 0.5, "onto the floor (%.2f m)" % f.global_position.y)
	_check(hero._void.arm.form == "hand", "the arm is bare through the slam")
	f.free()
	for h: Node in get_nodes_in_group("dark_hole"):
		h.free()
	await _settle()


func _whiff() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("GR")
	_check(hero.state == hero.State.ATTACK, "right click at nothing whips")
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 2.0)
	_check(hero.state == hero.State.MOVE and not hero._connected, "and plays out")


## Each right-click move hurts what's in front of him, and only the storm's breakers open windows.
func _elements() -> void:
	hero.global_position = Vector3.ZERO
	var foe := _foe(hero._facing() * 2.5)
	for id: String in ["EC", "EF", "EM"]:
		await _settle()
		foe.hp = 500.0
		foe.global_position = hero.global_position + hero._facing() * 2.5
		var hp := foe.hp
		hero._start_attack(id)
		await _until(func() -> bool: return hero._hits_done > 0, 3.0)
		await create_timer(0.2).timeout
		_check(foe.hp < hp, "%s hurts the foe in front (%.0f)" % [id, hp - foe.hp])
		_check(hero.HERO_LEAP.entry_for(id).is_empty() == (id != "EF"), "%s opens no window (Harpoon's opens after a pause, round 47)" % id)
	await _settle()
	hero._start_attack("L1")
	hero._start_attack("EC")
	var peak := 0.0
	var t := 0.0
	while hero.state == hero.State.ATTACK and t < 2.0:
		await physics_frame
		t += 1.0 / 60.0
		peak = maxf(peak, hero.model.position.y)
	_check(peak > 1.0, "the lash takes him up after them (%.1f m)" % peak)
	await _settle()
	foe.queue_free()
	await physics_frame
	hero.global_position = Vector3.ZERO
	hero._start_attack("EE")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await create_timer(0.25).timeout
	_check(hero.state != hero.State.LEAP, "Live Wire at nobody opens no window")
	await _settle()


## Each window holds them up, runs its lightning and lands, and a missed one lets go.
func _breakers() -> void:
	hero.global_position = Vector3.ZERO
	var foe := _foe(hero._facing() * 2.5)
	var breakers: Dictionary = load("res://scripts/void_element.gd").BREAKERS
	hero.bot_enabled = true  # presses each breaker at its sweet spot
	for id: String in ["EE", "EW"]:
		await _settle()
		foe.hp = 500.0
		foe.global_position = hero.global_position + hero._facing() * 2.5
		var landed: int = hero.breakers_landed
		hero._start_attack(id)
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		_check(hero.state == hero.State.LEAP, "%s opens its window" % id)
		await create_timer(0.28).timeout
		_check(foe.global_position.y > 0.5, "%s: the tentacle holds the foe up (%.1f m)" % [id, foe.global_position.y])
		var hp := foe.hp
		if breakers[id].has("wire"):
			_check(foe.hp < 500.0, "%s: lightning runs through it (%.0f)" % [id, 500.0 - foe.hp])
		await _until(func() -> bool: return hero.state == hero.State.MOVE, 4.0)
		_check(hero.breakers_landed == landed + 1, "%s: the press lands %s" % [id, breakers[id].names.spirit])
		_check(foe.hp <= hp - breakers[id].damage, "%s: it takes the slam (%.0f)" % [id, hp - foe.hp])
		_check(absf(foe.global_position.y) < 0.5, "%s: on the floor" % id)
		_check(hero._void._seized.is_empty(), "%s: the tentacles let go" % id)
		foe.global_position.y = 0.0
	hero.bot_enabled = false
	# From the height he's at: no pop down to the floor as the window begins.
	await _settle()
	foe.hp = 500.0
	foe.global_position = hero.global_position + hero._facing() * 2.5
	hero.model.position.y = 1.5
	hero._start_attack("EW")
	var low := 9.0
	var frames := 0
	while hero.state == hero.State.ATTACK and frames < 120:
		await physics_frame
		frames += 1
	for i in 6:
		await physics_frame
		low = minf(low, hero.model.position.y)
	_check(low > 1.2, "Live Wire from the air stays up (%.2f m)" % low)
	# With no press the foe is let go and nothing lands.
	var before: int = hero.breakers_landed
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 4.0)
	_check(hero.breakers_landed == before, "no press, no breaker")
	_check(hero._void._seized.is_empty(), "a miss lets go")
	await _settle()
	# The window's buttons.
	var w_name := ""
	var w_alt := ""
	foe.global_position = Vector3(hero.global_position.x, 0, hero.global_position.z) + hero._facing() * 2.5
	hero._start_attack("EW")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
	w_name = hero.breaker_window().name
	w_alt = hero.breaker_window().alt_name
	_check(w_name == "Worldbreaker" and w_alt == "Cold Front", "the window offers both endings (%s, %s)" % [w_name, w_alt])
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 4.0)
	await _settle()
	foe.global_position = Vector3(hero.global_position.x, 0, hero.global_position.z) + hero._facing() * 2.5
	hero._start_attack("EE")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
	_check(hero.breaker_window().alt_name == "Short Circuit", "Grounded's window offers Short Circuit too (%s)" % hero.breaker_window().alt_name)
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 4.0)
	await _settle()
	foe.queue_free()
	await physics_frame


## L in the window: everyone held freezes and is hurled at the one it isn't holding.
func _cold_front() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var near := _foe(Vector3(0, 0, 2.5))
	var big := _foe(Vector3(0, 0, 7))
	big.elite = true
	var seized_hp := 0.0
	hero.bot_enabled = true
	hero.bot_alt = true
	hero._start_attack("EW")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
	_check(hero.state == hero.State.LEAP, "the showcase opens its window")
	await _until(func() -> bool: return hero._brk_phase == 1, 2.0)
	_check(hero.HERO_LEAP.breaker_name(hero) == "Cold Front", "L is Cold Front (%s)" % hero.HERO_LEAP.breaker_name(hero))
	_check(near.frozen, "it freezes what it holds")
	_check(near.get_node_or_null("ThrownCube") != null, "in a cube")
	_check(near.global_position.y > 1.5, "held up (%.1f m)" % near.global_position.y)
	seized_hp = near.hp
	var big_hp := big.hp
	var landed: int = hero.breakers_landed
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
	_check(hero.breakers_landed == landed + 1, "and it lands")
	var moved := 0.0
	var start := near.global_position
	await _until(func() -> bool: return big.hp < big_hp, 2.0)
	moved = (near.global_position - start).length()
	_check(moved > 1.0, "the cube flies (%.1f m)" % moved)
	_check(big.hp < big_hp, "and hits the other foe (%.0f)" % (big_hp - big.hp))
	_check(big.frozen, "which freezes too")
	_check(near.hp < seized_hp, "and breaks (%.0f)" % (seized_hp - near.hp))
	_check(near.get_node_or_null("ThrownCube") == null or near.get_node("ThrownCube").is_queued_for_deletion(), "the cube's gone")
	_check(absf(near.global_position.y) < 0.5, "it lands on the floor (%.2f m)" % near.global_position.y)
	var look: GDScript = load("res://scripts/void_element.gd")
	var far_foe := _foe(Vector3(0, 0, 30))
	var alone := look.cube_target(near, [near], Vector3.ZERO, [near, far_foe], Vector3(0, 0, 1)) as Vector3
	_check(alone.distance_to(far_foe.global_position) > 1.0, "a cube won't chase someone miles away")
	_check(look.cube_target(near, [near, big], Vector3.ZERO, [near, big], Vector3(0, 0, 1)).distance_to(look._flat(big.global_position)) < 0.1, "with nobody else it goes for another it held")
	far_foe.free()
	hero.bot_enabled = false
	hero.bot_alt = false
	near.free()
	big.free()
	await _settle()


## Round 43: the window offers every ending, one per button (hero_leap.options(), what breaker_prompt.gd draws), and
## a real press picks it: L in Live Wire's window is Cold Front, H is Worldbreaker; Grounded has one ending, and L
## there does nothing.
func _breaker_choice() -> void:
	hero.bot_enabled = false
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var foe := _foe(Vector3(0, 0, 2.5))
	for press: String in ["attack_light", "attack_heavy"]:
		# (Cold Front's cube may still be in flight under load: nothing seizes a flying foe, so no leap)
		await _until(func() -> bool: return not foe.has_meta("thrown_foe_flying"), 3.0)
		foe.global_position = Vector3(hero.global_position.x, 0, hero.global_position.z) + hero._facing() * 2.5
		hero._start_attack("EW")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		var opts: Array = hero.breaker_window().get("options", [])
		_check(opts.size() == 2, "Live Wire's window offers two endings (%d)" % opts.size())
		if opts.size() == 2:
			_check(opts[0].button == "light" and opts[0].name == "Cold Front" and opts[0].element == "water",
				"left button first: LMB Cold Front in ice (%s)" % str(opts[0]))
			_check(opts[1].button == "heavy" and opts[1].name == "Worldbreaker" and opts[1].element == "earth",
				"then RMB Worldbreaker in magma (%s)" % str(opts[1]))
			_check(opts[0].color != opts[1].color, "each ending in its own colour")
		await _until(func() -> bool: return hero._state_t >= hero._brk.open + 0.02, 2.0)
		Input.action_press(press)
		await physics_frame
		Input.action_release(press)
		await _until(func() -> bool: return hero._brk_phase == 1, 0.5)
		var want := "Cold Front" if press == "attack_light" else "Worldbreaker"
		_check(hero._brk_phase == 1, "%s in the window dives" % press)
		_check(hero.HERO_LEAP.breaker_name(hero) == want, "%s picks %s (%s)" % [press, want, hero.HERO_LEAP.breaker_name(hero)])
		_check(hero.breaker_window().get("chose", "") == ("light" if press == "attack_light" else "heavy"), "the window says which button chose it")
		if is_instance_valid(hero._brk_cue):
			_check(hero._brk_cue.alt_color.a == 0.0, "the floor cue drops the other ending's colour once he picks")
		await _settle()
	# Round 44 b: Grounded's window has two endings too: LMB Short Circuit, RMB Grounded, both in the storm.
	foe.global_position = Vector3(hero.global_position.x, 0, hero.global_position.z) + hero._facing() * 2.5
	hero._start_attack("EE")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
	var two: Array = hero.breaker_window().get("options", [])
	_check(two.size() == 2 and two[0].button == "light" and two[0].name == "Short Circuit" and two[1].button == "heavy" and two[1].name == "Grounded",
		"Grounded's window: LMB Short Circuit, RMB Grounded (%s)" % str(two))
	await _until(func() -> bool: return hero._state_t >= hero._brk.open + 0.02, 2.0)
	Input.action_press("attack_light")
	await physics_frame
	Input.action_release("attack_light")
	await _until(func() -> bool: return hero._brk_phase == 1, 0.5)
	_check(hero._brk_phase == 1 and hero.HERO_LEAP.breaker_name(hero) == "Short Circuit", "L takes Short Circuit (%s)" % hero.HERO_LEAP.breaker_name(hero))
	await _settle()
	foe.queue_free()
	await physics_frame

## Short Circuit (round 44 b): the held take a little and stay down; the charge arcs out to the one the tentacles
## didn't hold (a heavy here), harder than Grounded's spill would, and charges it.
func _short_circuit() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var near := _foe(Vector3(0, 0, 2.5))
	var out := _foe(Vector3(-6.0, 0, 6.0))  # (far past the landing's spill)
	out.elite = true  # (can't be held)
	hero.bot_enabled = true
	hero.bot_alt = true
	hero._start_attack("EE")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
	await _until(func() -> bool: return hero._brk_phase == 1, 3.0)
	_check(hero.HERO_LEAP.breaker_name(hero) == "Short Circuit", "L is Short Circuit (%s)" % hero.HERO_LEAP.breaker_name(hero))
	var near_hp := near.hp
	var out_hp := out.hp
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
	await _until(func() -> bool: return out.hp < out_hp, 1.5)
	_check(near.hp < near_hp, "the held take some (%.0f)" % (near_hp - near.hp))
	_check(out_hp - out.hp >= el.BREAKERS.EE.alt.damage * el.SC_ARC_MULT * 0.99, "the charge arcs out to the one it didn't hold (%.0f)" % (out_hp - out.hp))
	_check(el.marked(out, "charged") and not el.marked(near, "charged"), "and the charge moves into it")
	hero.bot_enabled = false
	hero.bot_alt = false
	near.free()
	out.free()
	await _settle()


## A throw stops at a wall instead of going through it, and still breaks.
func _thrown_at_wall() -> void:
	hero.global_position = Vector3.ZERO
	var f := _foe(Vector3(0, 0, 2))
	var wall := _wall(Vector3(0, 1, 5))
	await physics_frame  # (a new body only reaches the physics space next frame)
	await physics_frame
	var hp := f.hp
	var thrown: Node = load("res://scripts/thrown_foe.gd").launch(hero, f, Vector3(0, 0, 12), 20.0)
	_check(thrown != null, "it throws")
	await _until(func() -> bool: return f.hp < hp, 2.0)
	_check(f.hp < hp, "it breaks at the wall")
	_check(f.global_position.z < 5.0, "short of it (%.1f m)" % f.global_position.z)
	f.free()
	wall.free()
	await physics_frame
	var g := _foe(Vector3(0, 0, 2))
	load("res://scripts/thrown_foe.gd").launch(hero, g, Vector3(0, 0, 8), 20.0)
	await physics_frame
	g.free()  # it dying in flight mustn't break anything
	await physics_frame
	await physics_frame
	await _settle()


func _ice() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	hero.bot_enabled = false
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	# Round 47: the tentacles take everyone near him, not a line: one on his aim, one well off to the side, one behind.
	var a := _foe(Vector3(0, 0, 4))
	var b := _foe(Vector3(5.0, 0, 0.5))
	var c := _foe(Vector3(-1.5, 0, -3.5))
	var big := _foe(Vector3(-3.0, 0, 5))
	big.elite = true
	var off := _foe(Vector3(12.5, 0, -2.0))  # (past HARPOON_REACH even grown by a top-tier chain: x1.45, _cast_grow)
	var start_ms := 0
	hero._start_attack("EF")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	start_ms = Time.get_ticks_msec()
	var light := [a, b, c]
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 2.0)
	var set_at_leap: bool = light.all(func(f: Foe) -> bool: return f.frozen and not f.has_meta("thrown_foe_flying"))
	await _until(func() -> bool: return light.all(func(f: Foe) -> bool: return f.frozen and not f.has_meta("thrown_foe_flying")), 2.0)
	var took := Time.get_ticks_msec() - start_ms
	_check(a.frozen and b.frozen and c.frozen and big.frozen, "Harpoon freezes everyone near, off his aim line and behind him too")
	_check(b.hits > 0 and c.hits > 0, "and the tentacles hit the ones off his line (%d, %d)" % [b.hits, c.hits])
	_check(not off.frozen and off.hits == 0, "but no one past its reach (frozen %s, hits %d)" % [off.frozen, off.hits])
	for f: Foe in light:
		_check(f.global_position.z > 1.4 and f.global_position.z < 3.0 and absf(f.global_position.x) < 3.0,
			"set down in front of him (%.1f, %.1f)" % [f.global_position.x, f.global_position.z])
		_check(el.in_cube(f), "in a cube")
	for i in light.size():
		for j in range(i + 1, light.size()):
			var gap: float = (light[i].global_position - light[j].global_position).length()
			_check(gap >= 1.2, "cubes don't overlap (%.2f m apart)" % gap)
	_check(absf(light[0].global_position.z - light[1].global_position.z) < 0.3 and absf(light[1].global_position.z - light[2].global_position.z) < 0.3,
		"in one rank across his aim")
	_check(absf(big.global_position.z - 5.0) < 0.3, "a big one freezes where it stands")
	_check(set_at_leap, "all set down by the time he leaps (%d ms real after the hit)" % took)
	await _settle()
	# A wall 3 m ahead: the rank stands short of it.
	for f: Foe in light:
		f.free()
	big.free()
	off.free()
	var wall := _wall(Vector3(0, 1, 3.2))
	await physics_frame
	await physics_frame
	var w1 := _foe(Vector3(-1.0, 0, 1.2))
	var w2 := _foe(Vector3(2.5, 0, -1.0))
	hero._start_attack("EF")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await _until(func() -> bool: return w1.frozen and w2.frozen and not w1.has_meta("thrown_foe_flying") and not w2.has_meta("thrown_foe_flying"), 2.0)
	_check(w1.global_position.z + w1.radius < 3.0 - 0.2 and w2.global_position.z + w2.radius < 3.0 - 0.2,
		"set down short of a wall (%.2f, %.2f; wall face 2.95)" % [w1.global_position.z, w2.global_position.z])
	await _settle()
	w1.free()
	w2.free()
	wall.free()
	await physics_frame
	# A press before the cancel is still Ice Cube (Dash L H H), not the leap.
	var p := _foe(Vector3(0.5, 0, 3.0))
	hero._start_attack("EF")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	Input.action_press("attack_heavy")
	await physics_frame
	Input.action_release("attack_heavy")
	await _until(func() -> bool: return hero._move_id == "EA" or hero.state == hero.State.LEAP, 2.0)
	_check(hero._move_id == "EA" and hero.state != hero.State.LEAP, "H during Harpoon is Ice Cube, not the window (%s)" % hero._move_id)
	await _settle()
	p.free()
	await physics_frame
	await _harpoon_endings()
	var a2 := _foe(Vector3(0, 0, 4))
	var b2 := _foe(Vector3(0.5, 0, 7))
	var big2 := _foe(Vector3(-0.5, 0, 9))
	big2.elite = true
	var off2 := _foe(Vector3(6, 0, 4))
	a = a2
	b = b2
	big = big2
	off = off2
	hero.global_position = Vector3.ZERO
	await physics_frame
	# Ice Cube bowls the frozen one through the next.
	a.global_position = Vector3(0, 0, 2)
	b.global_position = Vector3(0, 0, 6)
	b.frozen = false
	big.global_position = Vector3(20, 0, 20)
	off.global_position = Vector3(-20, 0, 20)
	var hp := b.hp
	hero._face(Vector3(0, 0, 1))
	hero.bot_enabled = true
	var landed: int = hero.breakers_landed
	hero._start_attack("EA")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(a.has_meta("thrown_foe_flying"), "Ice Cube throws it")
	await _until(func() -> bool: return b.hp < hp, 2.0)
	_check(b.hp < hp and b.frozen, "and what it passes takes it and freezes")
	_check(hero.state != hero.State.LEAP, "Ice Cube opens no window")
	hero.bot_enabled = false
	_check(hero.breakers_landed == landed, "and no breaker")
	for f: Node3D in [a, b, big, off]:
		f.free()
	await _settle()
	await _spear_string()
	await _spear_by_hand("attack_light")
	await _spear_by_hand("attack_heavy")
	await _one_cube()


## Round 47: Harpoon's two endings. A pause after it leaps over the row; the window offers LMB Slapshot (magma) and
## RMB Shatterstorm (storm). Slapshot into a wall out-damages Shatterstorm, which out-damages Slapshot in the open.
func _harpoon_endings() -> void:
	hero.bot_enabled = true
	var dealt := {}
	for case: String in ["thunder", "fist_open", "fist_wall"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.bot_alt = case != "thunder"
		var wall: StaticBody3D = _wall(Vector3(0, 1, 8.0)) if case == "fist_wall" else null
		await physics_frame
		await physics_frame
		var row := [_foe(Vector3(-1.5, 0, 3.5)), _foe(Vector3(3.5, 0, 1.0)), _foe(Vector3(0.5, 0, -2.5))]
		hero._start_attack("EF")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		_check(hero.state == hero.State.LEAP, "%s: the pause after Harpoon leaps into the window" % case)
		var opts: Array = hero.breaker_window().get("options", [])
		_check(opts.size() == 2 and opts[0].button == "light" and opts[0].name == "Slapshot" and opts[0].element == "earth"
			and opts[1].button == "heavy" and opts[1].name == "Shatterstorm" and opts[1].element == "wind",
			"%s: the window offers LMB Slapshot (magma), RMB Shatterstorm (storm) (%s)" % [case, str(opts)])
		await _until(func() -> bool: return hero._void.held_foes().size() == 3, 0.5)
		_check(hero._void.held_foes().size() == 3, "%s: a tentacle holds each cube through the hang (%d)" % [case, hero._void.held_foes().size()])
		var before: Array = row.map(func(f: Foe) -> float: return f.hp)
		await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
		_check(hero.HERO_LEAP.breaker_name(hero) == ("Shatterstorm" if case == "thunder" else "Slapshot"), "%s: picks %s" % [case, hero.HERO_LEAP.breaker_name(hero)])
		if case != "thunder":  # (the fist lands, then they slide)
			await _until(func() -> bool: return row.any(func(f: Foe) -> bool: return f.has_meta("thrown_foe_flying")), 1.0)
		await _until(func() -> bool: return row.all(func(f: Foe) -> bool: return not f.has_meta("thrown_foe_flying")), 3.0)
		for i in 60:
			await physics_frame
		var sum := 0.0
		for i in row.size():
			sum += before[i] - row[i].hp
		dealt[case] = sum
		if case == "fist_wall":
			_check(row.all(func(f: Foe) -> bool: return f.global_position.z < 8.0 - 0.25 and f.global_position.z > 5.5),
				"the cubes slid to the wall (%s)" % str(row.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		elif case == "fist_open":
			_check(row.all(func(f: Foe) -> bool: return f.global_position.z > 6.0), "the cubes slid on along his aim (%s)" % str(row.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		for f: Foe in row:
			f.free()
		if wall != null:
			wall.free()
		await _settle()
	print("  harpoon endings: thunder %.0f, fist into a wall %.0f, fist in the open %.0f (three cubes)" % [dealt.thunder, dealt.fist_wall, dealt.fist_open])
	_check(dealt.fist_wall > dealt.thunder, "Slapshot into a wall out-damages Shatterstorm (%.0f vs %.0f)" % [dealt.fist_wall, dealt.thunder])
	_check(dealt.thunder > dealt.fist_open, "Shatterstorm out-damages Slapshot with no wall (%.0f vs %.0f)" % [dealt.thunder, dealt.fist_open])
	hero.bot_alt = false
	hero.bot_enabled = false


## L L H, L, H, H in the window: frost slows, the slam makes cubes, the tentacles send them flying.
func _spear_string() -> void:
	var SPEAR: GDScript = load("res://scripts/frost_spear.gd")
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var near := _foe(Vector3(1.5, 0, 5))
	var far := _foe(Vector3(-2, 0, 6))
	var out := _foe(Vector3(0, 0, 25))
	var big := _foe(Vector3(3, 0, 1))
	big.elite = true
	var hp := near.hp
	hero._start_attack("IP")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	var spear: Node3D = SPEAR.current(self)
	_check(spear != null, "the spear goes in")
	_check(spear != null and absf(spear.global_position.z - hero.global_position.z - 2.6) < 1.0, "ahead of him")
	await create_timer(SPEAR.GROW + 0.2).timeout
	_check(near.chill_t > 0.0 and far.chill_t > 0.0, "the frost slows them")
	_check(not near.frozen and not far.frozen, "but only slows them")
	_check(out.chill_t <= 0.0, "and only those on it")
	_check(near.hp >= hp - 5.0, "and doesn't hurt (%.0f)" % (hp - near.hp))
	var there: Vector3 = spear.global_position
	hero._start_attack("IJ")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await create_timer(0.12).timeout
	_check(hero.model.position.y > 1.0, "he vaults up (%.1f m)" % hero.model.position.y)
	var landed: int = hero.breakers_landed
	hp = near.hp
	hero.bot_enabled = true
	hero._start_attack("IS")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	var gap := Vector2(hero.global_position.x - there.x, hero.global_position.z - there.z).length()
	_check(gap < 1.2, "and comes down on the spear (%.1f m off)" % gap)
	_check(SPEAR.current(self) == null, "it goes off")
	_check(near.frozen and far.frozen and big.frozen, "everyone on the frost freezes")
	_check(near.get_node_or_null("ThrownCube") != null and big.get_node_or_null("ThrownCube") != null, "into cubes")
	_check(near.hp < hp, "and it hurts (%.0f)" % (hp - near.hp))
	_check(not out.frozen, "not those off it")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 2.0)
	_check(hero.state == hero.State.LEAP, "the slam opens a window (%d)" % hero.state)
	_check(hero.HERO_LEAP.breaker_name(hero) == "Avalanche", "Avalanche (%s)" % hero.HERO_LEAP.breaker_name(hero))
	_check(hero._void.held_foes().size() == 3, "a tentacle on each cube (%d)" % hero._void.held_foes().size())
	var apart := near.global_position.distance_to(far.global_position)
	var top := 0.0
	hp = far.hp
	while hero.breakers_landed == landed and top < 100.0:
		await physics_frame
		top = maxf(top, far.global_position.y)
		if hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK:
			break
	_check(hero.breakers_landed == landed + 1, "Avalanche lands")
	_check(top > 2.0, "the cubes go up first (%.1f m)" % top)
	_check(absf(far.global_position.y) < 0.05, "and land on the floor (%.2f)" % far.global_position.y)
	_check(near.global_position.distance_to(far.global_position) < 2.2 and near.global_position.distance_to(far.global_position) < apart, "slammed together (%.1f m, from %.1f)" % [near.global_position.distance_to(far.global_position), apart])
	_check(big.global_position.distance_to(far.global_position) < 2.2, "all of them (%.1f m)" % big.global_position.distance_to(far.global_position))
	_check(not far.has_meta("thrown_foe_flying"), "not thrown away")
	_check(far.hp < hp, "and it hurts (%.0f)" % (hp - far.hp))
	_check(hero.global_position.distance_to(hero._void.dark_spot) > 2.5, "he lands beside the pile, not under it (%.1f m)" % hero.global_position.distance_to(hero._void.dark_spot))
	hero.bot_enabled = false
	for f: Node3D in [near, far, out, big]:
		if is_instance_valid(f):
			f.free()
	await _settle()
	# The slam with nobody there and no spear: it plays out, with no window.
	hero._start_attack("IS")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await create_timer(0.3).timeout
	_check(hero.state != hero.State.LEAP, "the slam at nobody opens no window")
	await _settle()
	# A second spear takes the first one's place, and an untouched one melts.
	hero._start_attack("IP")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	var first: Node3D = SPEAR.current(self)
	await _settle()
	hero._start_attack("IP")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	var second: Node3D = SPEAR.current(self)
	_check(second != null and second != first, "one spear at a time")
	await create_timer(SPEAR.LIFE + SPEAR.MELT + 0.2).timeout
	_check(SPEAR.current(self) == null, "and it melts in the end")
	await _settle()


func _magma() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var a := _foe(Vector3(0, 0, 3))
	var big := _foe(Vector3(1.0, 0, 4))
	big.elite = true
	var hp := a.hp
	var big_hp := big.hp
	hero._start_attack("EM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(a.hp < hp and big.hp < big_hp, "Molten Palm hits them")
	await _until(func() -> bool: return not a.has_meta("thrown_foe_flying"), 2.0)
	_check(a.global_position.z > 7.0, "and shoves them (%.1f m)" % a.global_position.z)
	_check(absf(big.global_position.z - 4.0) < 1.0, "not a big one (%.1f m)" % big.global_position.z)
	await _settle()
	# A wall takes it harder.
	a.global_position = hero.global_position + hero._facing() * 2.0
	var at: Vector3 = a.global_position
	big.global_position = Vector3(30, 0, 30)
	var wall := _wall(at + hero._facing() * 3.0 + Vector3.UP)
	await physics_frame
	await physics_frame
	hp = a.hp
	hero._start_attack("EM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	var after_blow := a.hp
	await _until(func() -> bool: return a.hp < after_blow, 2.0)
	_check(after_blow - a.hp >= 20.0, "a wall splats it (%.0f)" % (after_blow - a.hp))
	wall.free()
	await _settle()
	# Undertow and Meteor Fall.
	a.hp = 500.0
	big.hp = 500.0
	a.global_position = hero.global_position + Vector3(2, 0, 0)
	big.global_position = hero.global_position + Vector3(-3, 0, 0)
	var pin: Vector3 = a.global_position
	hero.bot_enabled = true
	var landed: int = hero.breakers_landed
	hero._start_attack("EV")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(world.get_children().any(func(n: Node) -> bool: return n.get_script() == load("res://scripts/floor_bind.gd")), "Undertow binds them")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 2.0)
	_check(hero.state == hero.State.LEAP, "Undertow opens a window")
	_check(hero.HERO_LEAP.breaker_name(hero) == "Meteor Fall", "Meteor Fall (%s)" % hero.HERO_LEAP.breaker_name(hero))
	_check(hero._void.held_foes().is_empty(), "no tentacle hold: the meteor needs none")
	await create_timer(0.1).timeout
	_check(a.global_position.distance_to(pin) < 0.3, "the small one's stuck")
	var a_before := a.hp
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(a_before - a.hp >= 60.0, "two lone foes: he dives on the nearer and it takes the meteor (%.0f)" % (a_before - a.hp))
	var off := Vector2(hero.global_position.x - a.global_position.x, hero.global_position.z - a.global_position.z).length()
	_check(off < 1.0, "he lands on it (%.1f m off)" % off)
	hero.bot_enabled = false
	a.hp = 500.0
	await _until(func() -> bool: return not world.get_children().any(func(n: Node) -> bool: return n.get_script() == load("res://scripts/floor_bind.gd")), 3.0)
	for w: Node in get_nodes_in_group("lava_wells"):  # (the pool outlasts the hold, and burns on its own)
		w.free()
	var drained := a.hp
	await create_timer(0.4).timeout
	_check(a.hp == drained, "the burning stops when it lets go")
	_check(a.get("model") == null or a.get("model").position.y == 0.0, "and it comes back up out of the floor")
	a.free()
	big.free()
	await _settle()
	# Palm into a wall, Undertow, meteor: he dives on the one the palm splatted on the wall, not the nearer one.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var shoved := _foe(Vector3(0, 0, 4))
	var near := _foe(Vector3(5, 0, -3))
	var near2 := _foe(Vector3(6, 0, -3.5))  # (a bigger group the palm never touched: it doesn't draw the dive)
	var near3 := _foe(Vector3(5.5, 0, -2))
	var back_wall := _wall(Vector3(0, 1, 9.5))
	await physics_frame
	await physics_frame
	hero._start_attack("EM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await _until(func() -> bool: return not shoved.has_meta("thrown_foe_flying"), 2.0)
	_check(ve.wall_fresh(shoved) and not ve.wall_fresh(near), "Molten Palm's wall splat marks it (last_wall_ms)")
	_check(ve.palm_fresh(shoved) and not ve.palm_fresh(near), "and the palm marks who it hit (last_palm_ms)")
	await _until(func() -> bool: return hero._state_t * hero.anim_speed * hero._anim_mult / hero._move_len >= hero._move.cancel, 2.0)
	hero.bot_enabled = true
	landed = hero.breakers_landed
	hero._start_attack("EV")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(hero._void.bound.has(shoved), "Undertow follows who the palm shoved")
	var where := shoved.global_position
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 2.0)
	_check(hero.HERO_LEAP.breaker_name(hero) == "Meteor Fall", "the breaker's the meteor")
	_check(shoved.global_position.distance_to(where) < 0.3, "and pins it where it splatted")
	var hp_before := shoved.hp
	var near_before := near.hp
	await _until(func() -> bool: return hero._brk_phase == 1, 3.0)
	_check(is_instance_valid(hero._brk_meteor), "he comes down in fire")
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(not is_instance_valid(hero._brk_meteor) or hero._brk_meteor.is_queued_for_deletion(), "which goes when he lands")
	off = Vector2(hero.global_position.x - shoved.global_position.x, hero.global_position.z - shoved.global_position.z).length()
	_check(off < 1.0, "the meteor dives on the one the palm hit, not the three it never touched (%.1f m off)" % off)
	_check(hp_before - shoved.hp >= 60.0 * ve.METEOR_SPLAT_MULT - 0.5, "it takes the splat bonus x%.1f (%.0f)" % [ve.METEOR_SPLAT_MULT, hp_before - shoved.hp])
	_check(near_before - near.hp < 40.0, "and the stray out of the blast only burns in the lava (%.0f)" % (near_before - near.hp))
	hero.bot_enabled = false
	shoved.free()
	near.free()
	near2.free()
	near3.free()
	back_wall.free()
	await _settle()
	# Round 42 e: a wall past the 6 m shove but inside PALM_WALL_REACH: the palm carries them on to it and splats them.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var far := _foe(Vector3(0, 0, 4))
	var far_wall := _wall(Vector3(0, 1, 4.0 + ve.PALM_SHOVE + 3.0))
	await physics_frame
	await physics_frame
	hero._start_attack("EM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await _until(func() -> bool: return not far.has_meta("thrown_foe_flying"), 2.0)
	_check(ve.wall_fresh(far) and far.global_position.z > 4.0 + ve.PALM_SHOVE + 1.0, "a wall 9 m behind: the palm carries it there and splats it (z %.1f)" % far.global_position.z)
	far_wall.free()
	await _settle()
	far.global_position = Vector3(0, 0, 4)
	await physics_frame
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("EM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	await _until(func() -> bool: return not far.has_meta("thrown_foe_flying"), 2.0)
	_check(absf(far.global_position.z - (4.0 + ve.PALM_SHOVE)) < 1.0, "no wall in reach: the plain %.0f m shove (z %.1f)" % [ve.PALM_SHOVE, far.global_position.z])
	far.free()
	await _settle()


## Meteor Fall's target (void_element.meteor_target, pure): the biggest group in reach, the wall-splatted group on
## a tie, a clearly bigger group over a splatted stray, and nothing to dive on with nobody in reach.
func _meteor_target() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	var at := Vector3.ZERO
	var group := [Vector3(0, 0, 8), Vector3(1, 0, 8.5), Vector3(-1, 0, 7.6)]
	var r: Dictionary = ve.meteor_target(at, [Vector3(4, 0, 0)] + group, [false, false, false, false])
	_check(r.found and r.at.distance_to(Vector3(0, 0, 8.03)) < 0.2 and r.count == 3, "a group of three beats a nearer stray (%s)" % r)
	r = ve.meteor_target(at, [Vector3(-6, 0, 2), Vector3(-6.5, 0, 3)] + [Vector3(6, 0, 2), Vector3(6.5, 0, 3)], [false, false, true, true])
	_check(r.found and r.at.x > 5.0, "two equal groups: the one the palm splatted on a wall wins (%s)" % r)
	r = ve.meteor_target(at, [Vector3(-3, 0, 2), Vector3(-6.5, 0, 3)] + group + [Vector3(1, 0, 7)], [true, false, false, false, false, false])
	_check(r.found and r.count == 4 and r.at.z > 7.0, "a clearly bigger group beats a splatted stray (%s)" % r)
	r = ve.meteor_target(at, [Vector3(7, 0, 0), Vector3(7.5, 0, 0.5), Vector3(0, 0, 5)], [true, true, false])
	_check(r.found and r.at.x > 6.0, "and the splatted pair beats a lone foe nearer (%s)" % r)
	r = ve.meteor_target(at, [], [])
	_check(not r.found, "nobody: no target (he lands ahead of him)")
	r = ve.meteor_target(at, [Vector3(0, 0, ve.METEOR_REACH + 2.0)], [false])
	_check(not r.found, "nobody in reach: no target either")
	r = ve.meteor_target(at, [Vector3(0, 0, ve.METEOR_REACH + 2.0), Vector3(3, 0, 4)], [true, false])
	_check(r.found and r.at.z > ve.METEOR_REACH, "a splatted one past the reach still counts: he follows the palm to the wall (%s)" % r)
	r = ve.meteor_target(at, [Vector3(0, 0, ve.METEOR_SPLAT_REACH + 1.0)], [true])
	_check(not r.found, "but not past METEOR_SPLAT_REACH")


## Round 34's crossovers: each cashes in what the element before it set up.
func _crossovers() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	var r: Callable = load("res://scripts/hero_moves.gd").void_route
	_check(r.call("light", "AL1", true, 0, false) == "XR", "L H L L: Rockslide")
	_check(r.call("heavy", "XR", true, 0, false) == "XF", "L H L L H: Fault Line")
	_check(r.call("light", "EA", true, 0, false) == "XS", "Dash L H H L: Steam Burst")
	_check(r.call("light", "TW", true, 0, false) == "XT", "Dash H L: Storm Pitch")
	# Rockslide: down into the floor, the one the gale had up twice as hard.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero.model.position.y = 0.0
	var up := _foe(Vector3(1, 0, 2))
	up.up = true
	var down := _foe(Vector3(-1, 0, 2))
	hero._start_attack("XR")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(up.last_kb.y < 0.0 and down.last_kb.y < 0.0, "Rockslide drives them both down (craters)")
	_check(500.0 - up.hp > (500.0 - down.hp) * 1.9, "the one in the air takes double (%.0f vs %.0f)" % [500.0 - up.hp, 500.0 - down.hp])
	_check(hero._void.buried == [up], "and Fault Line knows who it buried")
	await _settle()
	# Fault Line: the buried one goes up hardest.
	up.hp = 500.0
	down.hp = 500.0
	hero.bot_enabled = false
	hero._void.buried = [up]
	hero._start_attack("XF")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(up.last_launch > 0.0 and down.last_launch > 0.0, "Fault Line throws them up")
	_check(500.0 - up.hp > (500.0 - down.hp) * 1.9, "the buried hardest (%.0f vs %.0f)" % [500.0 - up.hp, 500.0 - down.hp])
	await _until(func() -> bool: return hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK, 3.0)
	game_end_slowmo()
	up.free()
	down.free()
	await _settle()
	# Steam Burst: only the frozen go off; the one beside it is scalded.
	var ice := _foe(Vector3(0, 0, 3))
	var warm := _foe(Vector3(1.5, 0, 3))
	el.encase(ice)
	_check(el.in_cube(ice), "a cube to start from")
	hero._start_attack("XS")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(not el.in_cube(ice) and ice.last_launch > 0.0, "Steam Burst blows the cube apart, and it up")
	_check(warm.hp < 500.0 and warm.hp > ice.hp, "the steam scalds the one beside it, less (%.0f / %.0f)" % [500.0 - warm.hp, 500.0 - ice.hp])
	await _until(func() -> bool: return hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK, 3.0)
	game_end_slowmo()
	ice.free()
	warm.free()
	await _settle()
	# Storm Pitch: whoever's bunched in front flies on, crackling.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var pitched := _foe(Vector3(0, 0, 1.8))
	var passed := _foe(Vector3(0.8, 0, 6.0))
	passed.remove_from_group("enemies")
	hero._start_attack("XT")
	passed.add_to_group("enemies")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(pitched.has_meta("thrown_foe_flying"), "Storm Pitch hurls it")
	await _until(func() -> bool: return not pitched.has_meta("thrown_foe_flying"), 2.0)
	_check(pitched.global_position.z > 5.0, "along his aim (%.1f m)" % pitched.global_position.z)
	_check(passed.hp < 500.0, "and lightning or the landing finds the one it passes (%.0f)" % (500.0 - passed.hp))
	pitched.free()
	passed.free()
	await _settle()
	# Galvanize (H L L, round 44 b): a tentacle to everyone within GALV_REACH, and to the Reap marked further out; one
	# pulse lands on all of them on the same frame, harder the more are linked, the marked harder still.
	_check(r.call("light", "VR", true, 0, false) == "XC", "H L L: Galvanize")
	var DARK: GDScript = load("res://scripts/dark_fx.gd")
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var spread := [_foe(Vector3(-4.0, 0, 3.0)), _foe(Vector3(0, 0, 5.0)), _foe(Vector3(4.5, 0, 2.0))]
	var beside := _foe(Vector3(6.5, 0, 3.0))  # (not marked, inside GALV_REACH)
	var far_marked := _foe(Vector3(0, 0, -10.0))  # (behind him, past GALV_REACH, marked)
	var far := _foe(Vector3(-10.0, 0, -2.0))  # (past GALV_REACH, not marked, out of the arcs' reach)
	for e: Foe in spread:
		DARK.mark(e)
	DARK.mark(far_marked)
	var all := spread + [beside, far_marked]
	hero._start_attack("XC")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(all.all(func(e: Foe) -> bool: return e.hits == 0), "the current hasn't arrived on the hit frame")
	await _until(func() -> bool: return all.any(func(e: Foe) -> bool: return e.hits > 0), 1.5)
	_check(all.all(func(e: Foe) -> bool: return e.hits == 1), "one pulse lands on all five on the same frame (%s)" % str(all.map(func(e: Foe) -> int: return e.hits)))
	var five: float = el.GALV_DAMAGE * (1.0 + el.GALV_LINK_BONUS * 4.0)
	_check(absf(500.0 - beside.hp - five) < 0.1, "five linked: %.1f each (%.1f)" % [five, 500.0 - beside.hp])
	_check(spread.all(func(e: Foe) -> bool: return absf(500.0 - e.hp - five * el.GALV_MARK_MULT) < 0.1), "the marked x%.2f" % el.GALV_MARK_MULT)
	_check(far.hits == 0, "nobody unmarked past GALV_REACH")
	_check(el.marked(beside, "charged"), "Galvanize leaves them charged")
	await _settle()
	for e: Foe in all + [far]:
		e.free()
	await _settle()
	# Black Ice: the pool freezes them, the landing shatters them down into the floor.
	var pooled := _foe(Vector3(0, 0, 4))
	hero._void.dark_spot = Vector3(0, 0, 4)
	el.freeze_pool(hero)
	_check(el.in_cube(pooled), "Black Ice freezes the pool with it in")
	var b: Dictionary = el.entry("VD")
	b.merge(b.alt, true)
	el.breaker_impact(hero, b, Vector3(0, 0, 2), [], 1.0)
	_check(pooled.hp < 500.0 and pooled.last_kb.y < 0.0, "and the landing shatters it into the floor")
	pooled.free()
	await _settle()


## Round 34, second pass: the three-element strings (each hand-over pays for what the last element left) and the
## improvised payoffs a dash route reaches (states outlive the string by ELEMENT_HOLD).
## The element matrix (round 49, kit grammar section 3): each of the six states' one rule pays for every element on a
## stand-in foe (the state's own element and the moves that pay it themselves left alone), then every upgrade cell
## plays in the rule's place with its Kit id on and the rule plays with it off; a whole move cashes one in, and a move
## with no reach doesn't touch a foe on top of him.
func _element_matrix() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	var BIND: GDScript = load("res://scripts/floor_bind.gd")
	var KIT: GDScript = load("res://scripts/kit.gd")
	var base := {"wind": "EC", "water": "EF", "earth": "EM", "void": "VR"}
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	for id: String in KIT.UPGRADES:
		KIT.set_on(id, false)
	_check(el.RULES.size() == 6 and el.RULES.keys().all(func(s: String) -> bool: return s in el.IMPROV_ORDER),
		"six states, one rule each (%s)" % str(el.RULES.keys()))
	# The rules, on every element (Undertow too: Molten Palm's own steam keeps the frozen, Undertow shatters it).
	var rules := 0
	var cases := []
	for state: String in el.RULES:
		for element: String in ["wind", "water", "earth", "void"]:
			cases.append([state, element, base[element]])
	cases.append(["frozen", "earth", "EV"])
	for c: Array in cases:
		var state: String = c[0]
		var element: String = c[1]
		var id: String = c[2]
		var e := _foe(Vector3(0, 0, 2.0))
		var o := _foe(Vector3(1.2, 0, 2.2))
		var bind := _matrix_state(el, BIND, e, state)
		if state == "charged":
			el.mark(o, "charged")
		var before: int = int(el.improv_paid.get(state, 0))
		var paid: int = el.improvise(hero, id, Vector3.ZERO, 1.0)
		var cell := "%s x %s (%s)" % [state, element, id]
		if el.RULE_OWN.get(state, "") == element or el._pays_itself(state, element, id):
			_check(paid == 0 and e.hits == 0, "%s is the move's own: no rule (%d)" % [cell, paid])
		else:
			rules += 1
			var dealt := 500.0 - e.hp
			var shows := false
			match state:
				"frozen":
					shows = not el.in_cube(e) and dealt >= el.IMPROV_DAMAGE * el.RULE_SHATTER_MULT - 0.01
				"charged":
					shows = o.hits > 0 and not el.marked(e, "charged") and not el.marked(o, "charged")
				"molten":
					shows = o.hits > 0 and not el.marked(e, "molten") and dealt >= el.IMPROV_DAMAGE * el.IMPROV_MULT - 0.01
				"bound":
					shows = not BIND.holds(e) and e.last_kb == Vector3.ZERO and e.last_big
				"airborne":
					shows = e.last_launch > 0.0
				"buried":
					shows = e.last_kb.y < 0.0 and not el.marked(e, "buried")
			_check((paid == 1 or (state == "charged" and paid >= 1)) and e.hits >= 1 and shows
				and int(el.improv_paid.get(state, 0)) > before,
				"%s: the %s rule (paid %d, hits %d, dealt %.1f, kb %s, launch %.1f)" % [cell, el.RULE_NAMES[state], paid, e.hits, dealt, e.last_kb, e.last_launch])
		if is_instance_valid(bind):
			bind.free()
		e.free()
		o.free()
	_check(rules == 18, "the six rules pay on 18 state x element pairs (%d)" % rules)
	# The upgrade cells: on, the cell plays in the rule's place; off, it doesn't.
	var cells := 0
	for key: String in el.IMPROV_UPGRADE:
		var state: String = key.get_slice("_x_", 0)
		var element: String = key.get_slice("_x_", 1)
		var up: String = el.IMPROV_UPGRADE[key]
		_check(KIT.UPGRADES.has(up), "%s's upgrade %s is in Kit.UPGRADES" % [key, up])
		for on: bool in [false, true]:
			KIT.set_on(up, on)
			var e := _foe(Vector3(0, 0, 2.0))
			var o := _foe(Vector3(1.2, 0, 2.2))
			var bind := _matrix_state(el, BIND, e, state)
			var want: String = el.improv_cell(e, element, base[element])
			if not on:
				_check(want != key, "%s off (%s): the cell doesn't play (%s)" % [key, up, want if want != "" else "nothing"])
			else:
				cells += 1
				var before: int = int(el.improv_paid.get(key, 0))
				var paid: int = el.improvise(hero, base[element], Vector3.ZERO, 1.0)
				var kind: String = el.IMPROV[state][element]
				var shows := false
				match kind:
					"lift", "fan", "quench", "erupt", "loose":
						shows = e.last_launch > 0.0
					"crater", "swallow", "smother", "spike":
						shows = e.last_kb.y < 0.0
					"encase", "freeze":
						shows = el.in_cube(e)
					"shards":
						shows = o.hits > 0
					"spread":
						shows = el.in_cube(o) and el.marked(o, "skewered")
					"tear":
						shows = e.last_kb.z < 0.0
					"conduct":
						shows = o.hits > 0 and el.marked(o, "charged") and el.marked(e, "charged")
					"superconduct":
						shows = el.in_cube(e)
					"flash":
						shows = o.hits > 0 and o.has_meta("thrown_foe_flying")
					"overload":
						shows = e.hits >= 1
				_check(want == key and paid == 1 and e.hits >= 1 and shows and int(el.improv_paid.get(key, 0)) > before,
					"%s on (%s): %s (paid %d, hits %d, kb %s, launch %.1f)" % [key, up, kind, paid, e.hits, e.last_kb, e.last_launch])
				if kind == "fan":
					_check(el.marked(o, "molten") and o.hits > 0, "fan: the flames catch the one beside it")
				if kind == "loose":
					_check(not BIND.holds(e), "loose: out of the bind")
				if state in ["buried", "molten", "skewered"] or (state == "charged" and kind != "conduct"):
					_check(not el.marked(e, state), "%s: spent once" % key)
			if is_instance_valid(bind):
				bind.free()
			e.free()
			o.free()
		KIT.set_on(up, false)
	_check(cells == 18, "every old cell is an upgrade (%d)" % cells)
	print("  element matrix: %d rule pairs, %d upgrade cells on and off" % [rules, cells])
	# The guide's tag reads the rule's name, or the upgrade's with it on.
	var tagged := _foe(Vector3(0, 0, 2.0))
	el.encase(tagged)
	_check(el.improv_name(el.improv_cell(tagged, "wind", "EC")) == "Shatter", "the tag off: + Shatter (%s)" % el.improv_name(el.improv_cell(tagged, "wind", "EC")))
	KIT.set_on("gale_lift", true)
	_check(el.improv_name(el.improv_cell(tagged, "wind", "EC")) == "Gale Lift", "gale_lift on: + Gale Lift")
	KIT.set_on("gale_lift", false)
	tagged.free()
	# Round 44: a jolt leaves them charged. The rule: the arc goes on through every charged foe near the payer, out of
	# the move's reach too, and discharges them all.
	var one := _foe(Vector3(0, 0, 2.0))
	el.jolt(hero, one)
	_check(el.marked(one, "charged"), "a jolt leaves it charged")
	var chain := [one, _foe(Vector3(4.0, 0, 5.0)), _foe(Vector3(-3.0, 0, 6.5))]
	el.mark(chain[1], "charged")
	el.mark(chain[2], "charged")
	el.improvise(hero, "VR", Vector3.ZERO, 1.0)
	_check(chain.all(func(e: Foe) -> bool: return e.hits > 0 and not el.marked(e, "charged")),
		"the arc rule: Reap's hit arcs on through both charged foes past its crescent, all discharged (%s)" % str(chain.map(func(e: Foe) -> int: return e.hits)))
	for e: Foe in chain:
		e.free()
	# Storm on charged is Live Wire's own: off, Updraft Lash leaves the charge; Overload on, harder the more are
	# charged, and discharges them all.
	var mine := _foe(Vector3(0, 0, 2.0))
	el.mark(mine, "charged")
	_check(el.improvise(hero, "EC", Vector3.ZERO, 1.0) == 0 and el.marked(mine, "charged"), "storm on charged, Overload off: the move's own, still charged")
	mine.free()
	KIT.set_on("overload", true)
	var lone := _foe(Vector3(0, 0, 2.0))
	el.mark(lone, "charged")
	var before_one := lone.hp
	el.improvise(hero, "EC", Vector3.ZERO, 1.0)
	var alone: float = before_one - lone.hp
	lone.free()
	var trio := [_foe(Vector3(0, 0, 2.0)), _foe(Vector3(4.0, 0, 3.0)), _foe(Vector3(-4.0, 0, 3.0))]
	for e: Foe in trio:
		el.mark(e, "charged")
	el.improvise(hero, "EC", Vector3.ZERO, 1.0)
	_check(500.0 - trio[0].hp > alone * 1.5 and trio[1].hits > 0 and trio[2].hits > 0
		and not trio.any(func(e: Foe) -> bool: return el.marked(e, "charged")),
		"Overload: harder with three charged (%.1f vs %.1f alone), all three discharged" % [500.0 - trio[0].hp, alone])
	for e: Foe in trio:
		e.free()
	KIT.set_on("overload", false)
	# Superconduct: the charge runs on through a cube standing 5 m off.
	KIT.set_on("superconduct", true)
	var payer := _foe(Vector3(0, 0, 2.0))
	var cube := _foe(Vector3(5.0, 0, 3.0))
	el.mark(payer, "charged")
	el.encase(cube)
	el.improvise(hero, "EF", Vector3.ZERO, 1.0)
	_check(el.in_cube(payer) and cube.hits > 0 and el.marked(cube, "charged"), "Superconduct runs through the ice to the cube 5 m off")
	payer.free()
	cube.free()
	KIT.set_on("superconduct", false)
	await _settle()
	# Round 4: the payoff follows the move's own hit shape. A foe behind him, well inside the old 5 m reach round
	# him, is outside every one of these moves (the gale's circle ahead, the harpoon's line, the palm's line, the
	# crescent) and doesn't pay; nor does one off to the side of the harpoon's line.
	root.get_node("Game").combo_count = 0  # (a long chain grows the shapes: Updraft Lash's gale then reaches behind him)
	var paying := {"wind": "frozen", "water": "buried", "earth": "buried", "void": "frozen"}
	for element: String in base:
		# (round 47: Harpoon takes everyone in 8 m round him, so its miss is past that, behind and to the side)
		for spot: Vector3 in [Vector3(0, 0, -9.0), Vector3(9.0, 0, 1.0)] if element == "water" else [Vector3(0, 0, -2.5)]:
			var e := _foe(spot)
			if paying[element] == "frozen":
				el.encase(e)
			else:
				el.mark(e, paying[element])
			var paid: int = el.improvise(hero, base[element], Vector3.ZERO, 1.0)
			_check(paid == 0 and e.hits == 0, "%s (%s) misses a %s foe at %s, %.1f m off: outside its shape (paid %d)" % [base[element], element,
				paying[element], spot, spot.length(), paid])
			e.free()
	var ahead := _foe(Vector3(-3.0, 0, -3.5))  # (round 47: and the tentacles find one behind him, off his aim)
	el.mark(ahead, "buried")
	_check(el.improvise(hero, "EF", Vector3.ZERO, 1.0) == 1, "Harpoon's reach pays the buried behind him")
	ahead.free()
	# A whole move cashes one in: Harpoon on someone Rockslide buried craters them (the rule).
	var buried := _foe(Vector3(0, 0, 3.0))
	el.mark(buried, "buried")
	var craters: int = int(el.improv_paid.get("buried", 0))
	hero._start_attack("EF")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(not el.marked(buried, "buried") and int(el.improv_paid.get("buried", 0)) == craters + 1, "Harpoon on the buried: the crater rule")
	await _until(func() -> bool: return hero.state != hero.State.ATTACK, 3.0)
	buried.free()
	await _settle()
	# Round 2's bug: a move with `range` 0 touched a foe standing on him (a 0-damage hit that broke its ice early).
	hero.global_position = Vector3.ZERO
	var on_him := _foe(Vector3(0, 0, 0.1))
	hero._start_attack("EE")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(on_him.hits == 0, "a move with no reach doesn't touch a foe on top of him (%d hits)" % on_him.hits)
	await _until(func() -> bool: return hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK, 3.0)
	game_end_slowmo()
	on_him.free()
	await _settle()


## Puts `e` in `state` for the matrix checks (returns the bind holding it, for "bound").
func _matrix_state(el: GDScript, BIND: GDScript, e: Foe, state: String) -> Node:
	match state:
		"frozen":
			el.encase(e)
		"airborne":
			e.up = true
		"bound":
			return BIND.bind(hero, [e], {"time": 3.0})
		_:
			el.mark(e, state)
	return null


func _three_elements() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	var SPEAR: GDScript = load("res://scripts/frost_spear.gd")
	var r: Callable = load("res://scripts/hero_moves.gd").void_route
	_check(r.call("heavy", "EA", true, 0, false) == "XG", "Dash L H H H: Hailstorm")
	_check(r.call("light", "XG", true, 0, false) == "XM", "Dash L H H H L: Meltdown")
	_check(r.call("heavy", "TW", true, 0, false) == "XK", "Dash H H: Impale")
	_check(r.call("light", "XK", true, 0, false) == "XW", "Dash H H L: Backdraft")
	_check(el.BREAKERS.has("XM") and el.BREAKERS.has("XW"), "Meltdown and Backdraft open a window")
	_check(el.FREEZE_TIME >= 2.0 and el.FREEZE_TIME == el.ELEMENT_HOLD, "the ice holds %.1f s: long enough to dash and come back" % el.FREEZE_TIME)
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero.model.position.y = 0.0
	# With the spear standing, Tow Line's presses go on down its string instead of up the spear.
	SPEAR.plant(world, Vector3(0, 0, 4))
	_check(hero.HERO_MOVES.routed(hero, "heavy", "TW", true, 0, false) == "XK", "with the spear up, H off Tow Line is still Impale")
	_check(hero.HERO_MOVES.routed(hero, "light", "XK", true, 0, false) == "XW", "and L off Impale is Backdraft")
	_check(hero.HERO_MOVES.routed(hero, "light", "IP", true, 0, false) == "IJ", "the vault still comes off the plant")
	# Impale: Tow Line's bunch onto the spear, frozen round it.
	var a := _foe(Vector3(0.5, 0, 2.0))
	var b := _foe(Vector3(-0.8, 0, 1.6))
	hero._start_attack("XK")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(a.has_meta("thrown_foe_flying") and el.in_cube(a), "Impale throws them, frozen")
	_check(el.marked(a, "skewered") and el.marked(b, "skewered"), "and they're skewered")
	var hit_a := 500.0 - a.hp
	_check(hit_a >= el.IMPALE_DAMAGE * el.IMPALE_SPEAR_MULT * 0.99, "onto a standing spear it pays more (%.0f)" % hit_a)
	await _until(func() -> bool: return not a.has_meta("thrown_foe_flying"), 2.0)
	var spear: Node3D = SPEAR.current(self)
	_check(spear != null and Vector2(a.global_position.x - spear.global_position.x, a.global_position.z - spear.global_position.z).length() < 1.3,
		"stuck round the spear")
	await _settle()
	# Backdraft: the spear goes, the kebab comes back to him and up.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var hp := a.hp
	hero._start_attack("XW")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(SPEAR.current(self) == null, "Backdraft blows the spear apart")
	_check(a.last_launch > 0.0 and a.last_kb.z < 0.0, "Backdraft hauls them back to him and up (kb %.1f, launch %.1f)" % [a.last_kb.z, a.last_launch])
	_check(hp - a.hp >= el.BACKDRAFT_DAMAGE * 0.99 and not el.marked(a, "skewered"), "the skewered take it all (%.0f)" % (hp - a.hp))
	await _until(func() -> bool: return hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK, 3.0)
	game_end_slowmo()
	# Anvil: what's held goes into the floor.
	var bw: Dictionary = el.entry("XW")
	hp = a.hp
	el.breaker_impact(hero, bw, Vector3(0, 0, 1), [a], 1.0)
	_check(a.last_kb.y < 0.0 and hp - a.hp >= bw.damage * el.ANVIL_AIR_MULT * 0.99, "Anvil drives them into the floor (%.0f)" % (hp - a.hp))
	a.free()
	b.free()
	await _settle()
	# Round 4: Anvil's reel fans the kebab out across his aim (ANVIL_SPREAD), held and landed, a crater each:
	# hauled to one point, three foes stuck round the spear landed in one pile.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var kebab := [_foe(Vector3(0.3, 0, 3.0)), _foe(Vector3(-0.3, 0, 3.2)), _foe(Vector3(0.0, 0, 2.7))]
	hero._brk_zone = Vector3(0, 0, 1.5)
	hero._void.seize(bw)
	var lands := []
	for s: Dictionary in hero._void._seized:
		lands.append(hero._brk_zone.lerp(Vector3(s.from.x, 0.0, s.from.z), 1.0 - hero._void.SEIZE_IN) + s.get("fan", Vector3.ZERO) * hero._void.SEIZE_IN)
	var closest := INF
	for i in lands.size():
		for j in range(i + 1, lands.size()):
			closest = minf(closest, (lands[i] - lands[j]).length())
	_check(lands.size() == 3 and closest >= el.ANVIL_SPREAD * 0.95, "Anvil's reel lands them %.2f m apart at least (ANVIL_SPREAD %.1f)" % [closest, el.ANVIL_SPREAD])
	hero._void.release_seized()
	for k: Node in kebab:
		k.free()
	await _settle()
	# Hailstorm: only the frozen go up, in their ice; he climbs.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero.model.position.y = 0.0
	var ice := _foe(Vector3(0, 0, 2.5))
	var warm := _foe(Vector3(1.5, 0, 2.0))
	el.encase(ice)
	hero._start_attack("XG")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(ice.last_launch >= el.HAIL_LAUNCH and el.in_cube(ice), "Hailstorm carries the frozen up, still in their ice")
	_check(warm.last_launch > 0.0 and warm.last_launch < ice.last_launch, "the warm only stagger up (%.1f)" % warm.last_launch)
	_check(hero.model.position.y > 1.5, "and he climbs after them (%.1f m)" % hero.model.position.y)
	# Meltdown off it: the ones up there with him come down burning, the ones the gale had up hardest.
	ice.up = true
	var floor_ice := _foe(Vector3(-1.5, 0, 2.0))
	el.encase(floor_ice)
	warm.up = false
	var hp_ice := ice.hp
	var hp_floor := floor_ice.hp
	var hp_warm := warm.hp
	await _until(func() -> bool: return hero.HERO_MOVES.progress(hero) >= hero._move.cancel, 2.0)
	hero._start_attack("XM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(hero.model.position.y > 1.5, "Meltdown is up there with them (%.1f m)" % hero.model.position.y)
	_check(ice.last_kb.y < 0.0 and not el.in_cube(ice), "it bursts the ice and brings them down (craters)")
	_check(hp_ice - ice.hp > (hp_floor - floor_ice.hp) * 1.4, "those in the air take it worst (%.0f vs %.0f)" % [hp_ice - ice.hp, hp_floor - floor_ice.hp])
	_check(warm.hp == hp_warm, "a foe on the floor out of the ice is left alone")
	_check(el.marked(ice, "molten"), "and they're alight")
	await _until(func() -> bool: return hero.state != hero.State.ATTACK, 3.0)
	_check(hero.state == hero.State.LEAP and hero.HERO_LEAP.breaker_name(hero) == "Eruption", "the window opens: Eruption (%s)" % hero.HERO_LEAP.breaker_name(hero))
	_check(hero._brk_y0 > 1.0, "from up there (%.1f m)" % hero._brk_y0)
	await _until(func() -> bool: return hero.state != hero.State.LEAP, 3.0)
	game_end_slowmo()
	# Eruption: the molten hardest.
	var be: Dictionary = el.entry("XM")
	el.mark(ice, "molten")
	ice.global_position = Vector3(0, 0, 1)
	warm.global_position = Vector3(1, 0, 1)
	hp_ice = ice.hp
	hp_warm = warm.hp
	el.breaker_impact(hero, be, Vector3(0, 0, 1), [], 1.0)
	_check(hp_ice - ice.hp > (hp_warm - warm.hp) * 1.9 and ice.last_launch > 0.0, "Eruption throws them up, the molten hardest (%.0f vs %.0f)" % [hp_ice - ice.hp, hp_warm - warm.hp])
	ice.free()
	warm.free()
	floor_ice.free()
	await _settle()
	hero.model.position.y = 0.0
	# Improvising: frozen into magma by another route. Molten Palm on a cube goes off as a Steam Burst.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var cube := _foe(Vector3(0, 0, 2.5))
	el.encase(cube)
	hero._start_attack("EM")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(not el.in_cube(cube) and cube.last_launch > 0.0 and not cube.has_meta("thrown_foe_flying"), "Molten Palm on the frozen: Steam Burst (up, not shoved)")
	await _until(func() -> bool: return hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK, 3.0)
	game_end_slowmo()
	cube.free()
	await _settle()
	# Steam Burst on a cube Ice Cube is still bowling (the bot's Dash L H H L): it's cut out of its roll and goes off.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var rolling := _foe(Vector3(0, 0, 2.0))
	el.encase(rolling)
	el.THROWN.launch(hero, rolling, Vector3(0, 0, 14.0), 0.0, {"pierce": true})
	_check(rolling.has_meta("thrown_foe_flying"), "a cube on its way")
	hero._start_attack("XS")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(not rolling.has_meta("thrown_foe_flying") and not el.in_cube(rolling) and rolling.last_launch > 0.0, "Steam Burst takes the rolling cube too")
	await _until(func() -> bool: return hero.state != hero.State.LEAP and hero.state != hero.State.ATTACK, 3.0)
	game_end_slowmo()
	rolling.free()
	await _settle()
	# Buried into storm: Updraft Lash on someone Rockslide buried takes it twice, and the state's spent.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var buried := _foe(Vector3(0, 0, 3.5))
	var plain := _foe(Vector3(1.0, 0, 3.5))
	el.mark(buried, "buried")
	hero._start_attack("EC")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(buried.hits == plain.hits + 1 and plain.hp - buried.hp >= el.CUTTER_DAMAGE * 0.99, "Updraft Lash on the buried: the gale's hit twice (%.0f vs %.0f)" % [500.0 - buried.hp, 500.0 - plain.hp])
	_check(not el.marked(buried, "buried"), "once")
	await _settle()
	# Airborne into dark: Tow Line rips someone in the air out of it, harder.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero._dash_from = Vector3(0, 0, -3)
	buried.global_position = Vector3(0.5, 0, 2.0)
	plain.global_position = Vector3(-0.5, 0, 2.0)
	buried.up = true
	var hits_up := buried.hits
	var hits_down := plain.hits
	hero._start_attack("TW")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(buried.hits == hits_up + 1 and plain.hits == hits_down, "Tow Line on one in the air hits it on the way in too")
	buried.free()
	plain.free()
	await _settle()
	# A buried mark runs out.
	var old := _foe(Vector3(0, 0, 3))
	old.set_meta("x_buried", Time.get_ticks_msec() - 1)
	_check(not el.marked(old, "buried"), "a state ELEMENT_HOLD s old is gone")
	old.free()


func game_end_slowmo() -> void:
	root.get_node("Game").end_slowmo()


## The dark string: each one gathers them, and its breaker lands on where it gathered them.
func _dark() -> void:
	# Singularity into Collapse.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var held := _foe(Vector3(0, 0, 3))
	var other := _foe(Vector3(5, 0, 3))
	var big := _foe(Vector3(-4, 0, 3))
	big.elite = true
	var far := _foe(Vector3(40, 0, 40))
	hero._start_attack("GR")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	hero.bot_enabled = true
	var landed: int = hero.breakers_landed
	hero._start_attack("VS")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(is_instance_valid(hero._void.hole), "Singularity opens a black hole")
	var spot: Vector3 = hero._void.dark_spot
	var gap := Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length()
	var big_at := big.global_position
	var hp := other.hp
	await create_timer(0.2).timeout
	_check(Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length() < gap - 0.5, "it drags them in")
	_check(other.hp < hp, "and burns them")
	_check(big.global_position.distance_to(big_at) < 0.5 and big.chill_t > 0.0, "a big one only slows")
	_check(hero.HERO_LEAP.breaker_name(hero) == "Collapse", "the breaker's Collapse (%s)" % hero.HERO_LEAP.breaker_name(hero))
	hp = other.hp
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(hero.breakers_landed == landed + 1, "Collapse lands")
	_check(get_nodes_in_group("dark_hole").is_empty(), "the hole's gone")
	_check(hp - other.hp >= 40.0, "and it hits hard (%.0f)" % (hp - other.hp))
	_check(Vector2(hero.global_position.x - spot.x, hero.global_position.z - spot.z).length() < 2.5, "he came down at it")
	hero.bot_enabled = false
	await _settle()
	# Reap marks what it cuts, in front of him.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	held.global_position = Vector3(1, 0, 4)
	other.global_position = Vector3(-3, 0, 4)
	big.global_position = Vector3(0, 0, -3)
	big.elite = false
	hp = held.hp
	hero._start_attack("VR")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	_check(held.hp < hp, "Reap cuts (%.0f)" % (hp - held.hp))
	_check(held.get_node_or_null("VoidMark") != null and other.get_node_or_null("VoidMark") != null, "and marks them")
	_check(big.get_node_or_null("VoidMark") == null, "not behind him")
	# Black Tide takes the marked, however far, into a pool, and Maw shuts on them.
	other.global_position = Vector3(-12, 0, 12)
	big.global_position = Vector3(3, 0, -3)
	var big_stays := big.global_position
	hero.bot_enabled = true
	landed = hero.breakers_landed
	await _until(func() -> bool: return hero._state_t * hero.anim_speed * hero._anim_mult / hero._move_len >= hero._move.cancel, 2.0)
	hero._start_attack("VD")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	_check(other.has_meta("thrown_foe_flying"), "Black Tide comes for the far one")
	var el: Variant = hero.VOID_ELEMENT
	var earliest: float = (el.BREAKERS.VD.leap - hero._move.hits[0]) * hero._move_len / (hero.anim_speed * hero._anim_mult) + el._WINDOW.open
	_check(el.TIDE_ARRIVE < earliest, "and it gets there before the earliest bite (%.2f s)" % earliest)
	hp = other.hp
	_check(not big.has_meta("thrown_foe_flying"), "and leaves the unmarked")
	_check(other.get_node_or_null("VoidMark") == null, "the mark's spent")
	spot = hero._void.dark_spot
	await _until(func() -> bool: return not other.has_meta("thrown_foe_flying"), 2.0)
	_check(Vector2(other.global_position.x - spot.x, other.global_position.z - spot.z).length() < 1.5, "it fetches up in the pool")
	_check(big.global_position.distance_to(big_stays) < 0.5, "and nobody else moved")
	_check(hero.HERO_LEAP.breaker_name(hero) == "Maw", "the breaker's Maw (%s)" % hero.HERO_LEAP.breaker_name(hero))
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(hero.breakers_landed == landed + 1, "Maw lands")
	_check(get_nodes_in_group("dark_maw").size() == 1, "its jaws are up")
	_check(hp - other.hp >= 50.0, "and bites (%.0f)" % (hp - other.hp))
	_check(hero.global_position.distance_to(spot) > 1.5, "he lands short of it, not under the teeth")
	await _until(func() -> bool: return get_nodes_in_group("dark_maw").is_empty(), 2.0)
	_check(get_nodes_in_group("dark_maw").is_empty(), "and the jaws go")
	hero.bot_enabled = false
	await _settle()
	# Overwhelm into Abyss.
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	held.global_position = Vector3(0, 0, 5)
	other.global_position = Vector3(1, 0, 5.5)
	big.global_position = Vector3(40, 0, -40)
	hero.bot_enabled = true
	landed = hero.breakers_landed
	hero._start_attack("OW")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	_check(is_instance_valid(hero._void.dark_bind), "Overwhelm has them")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 2.0)
	_check(hero.HERO_LEAP.breaker_name(hero) == "Abyss", "the breaker's Abyss (%s)" % hero.HERO_LEAP.breaker_name(hero))
	hp = held.hp
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(hero.breakers_landed == landed + 1, "Abyss lands")
	_check(hp - held.hp >= 40.0, "and it hurts (%.0f)" % (hp - held.hp))
	await create_timer(0.05).timeout
	_check(not is_instance_valid(hero._void.dark_bind) or hero._void.dark_bind.is_queued_for_deletion(), "and lets go of them")
	hero.bot_enabled = false
	for f: Node3D in [held, other, big, far]:
		f.free()
	await _settle()
	# Nobody there: no window on any of them.
	for id: String in ["VR", "VD", "OW"]:
		hero._start_attack(id)
		await _until(func() -> bool: return hero._hits_done > 0, 2.0)
		await create_timer(0.3).timeout
		_check(hero.state != hero.State.LEAP, "%s at nobody opens no window" % id)
		await _settle()


func _tentacle_alone() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var a := _foe(Vector3(0, 0, 3))
	var b := _foe(Vector3(0, 0, 8))
	var hp := 0.0
	# Overwhelm: pins a small one, holds on to a big one.
	var big := _foe(hero.global_position + hero._facing() * 5.0)
	big.elite = true
	a.global_position = big.global_position + Vector3(1.5, 0, 0)
	b.global_position = Vector3(40, 0, 40)
	var big_hp := big.hp
	var pin: Vector3 = a.global_position
	hero._start_attack("OW")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	await create_timer(0.7).timeout
	_check(big.hp < big_hp, "Overwhelm works on big foes (%.0f)" % (big_hp - big.hp))
	_check(a.global_position.distance_to(pin) < 0.3, "and pins small ones")
	big.free()
	await _settle()
	# Tow Line: who he passed, yanked together.
	await create_timer(1.8).timeout
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	a.global_position = Vector3(2, 0, 3)
	b.global_position = Vector3(-2, 0, 5)
	hero._dash_from = Vector3(0, 0, -1)
	hero.global_position = Vector3(0, 0, 7)
	await physics_frame
	hp = a.hp
	hero._start_attack("TW")
	await _until(func() -> bool: return hero._hits_done > 0, 2.0)
	_check(a.has_meta("thrown_foe_flying") and b.has_meta("thrown_foe_flying"), "Tow Line takes who he passed")
	await _until(func() -> bool: return a.hp < hp, 2.0)
	_check(a.hp < hp, "and they hit each other")
	a.free()
	b.free()
	await _settle()


## Right click on a swing carries a foe along, and it flies on at the end.
func _snatch() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var a := _foe(Vector3(0, 0, 3))
	await _press_r()
	hero._buffered = "heavy"
	hero._buffer_t = 0.5
	await physics_frame
	await physics_frame
	_check(hero._void._carry == a, "right click on a swing snatches a foe")
	_check(hero._buffered == "", "and doesn't also end the swing")
	await create_timer(0.1).timeout
	_check((a.global_position - hero.global_position).length() < 2.5, "it comes along (%.1f m)" % (a.global_position - hero.global_position).length())
	var hp := a.hp
	await _until(func() -> bool: return hero.state != hero.State.SWING, 2.0)
	_check(hero._void._carry == null, "he lets it go")
	await _until(func() -> bool: return a.hp < hp, 2.0)
	_check(a.hp < hp, "and it flies on and breaks")
	a.free()
	await _settle()


## Breaker pairs: each new LMB ending against its RMB sibling, in the LMB's best situation and its worst (the damage the
## held / targeted foes take from the leap to a beat after the landing, the window pressed by the bot at the sweet spot).
func _breaker_pairs() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	hero.bot_enabled = true
	# Meteor Fall / Meteor Shower (EV): four the palm scattered, or three it piled on a wall.
	var dealt := {}
	for case: String in ["fall_spread", "shower_spread", "fall_pile", "shower_pile"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.bot_alt = case.begins_with("shower")
		var spots: Array = [Vector3(2, 0, 1), Vector3(-5.5, 0, 5), Vector3(5.5, 0, 6), Vector3(0, 0, 10)] if case.ends_with("spread") \
			else [Vector3(1.5, 0, 2), Vector3(0.8, 0, 2.8), Vector3(2.4, 0, 2.6)]
		var foes: Array = spots.map(func(p: Vector3) -> Foe: return _foe(p))
		for f: Foe in foes:
			f.set_meta(ve.PALM_META, Time.get_ticks_msec())
			if case.ends_with("pile"):
				f.set_meta("last_wall_ms", Time.get_ticks_msec())
		await physics_frame
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		var landed: int = hero.breakers_landed
		hero._start_attack("EV")
		await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed, "%s: the breaker lands" % case)
		var want := "Meteor Shower" if hero.bot_alt else "Meteor Fall"
		_check(hero.HERO_LEAP.breaker_name(hero) == want, "%s: picks %s (%s)" % [case, want, hero.HERO_LEAP.breaker_name(hero)])
		await create_timer(1.0, true, false, true).timeout  # (the fireballs fall on real time)
		for i in 20:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "shower_spread":
			_check(foes.all(func(f: Foe) -> bool: return before[foes.find(f)] - f.hp >= ve.SHOWER_DAMAGE * 0.99), "Meteor Shower drops a fireball on every foe the palm hit (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(before[foes.find(f)] - f.hp, 1.0))))
			_check(foes.all(func(f: Foe) -> bool: return ve.marked(f, "molten")), "and leaves them molten")
		for f: Foe in foes:
			f.free()
		for w: Node in get_nodes_in_group("lava_wells"):
			w.free()
		await _settle()
	print("  meteor pair: spread fall %.0f / shower %.0f, wall pile fall %.0f / shower %.0f" % [dealt.fall_spread, dealt.shower_spread, dealt.fall_pile, dealt.shower_pile])
	_check(dealt.shower_spread > dealt.fall_spread * 1.5, "scattered: Meteor Shower out-damages Meteor Fall (%.0f vs %.0f)" % [dealt.shower_spread, dealt.fall_spread])
	_check(dealt.fall_pile > dealt.shower_pile * 1.5, "piled on a wall: Meteor Fall out-damages Meteor Shower (%.0f vs %.0f)" % [dealt.fall_pile, dealt.shower_pile])
	# Anvil / Pinwheel (XW): the kebab by a wall, or in the open.
	dealt = {}
	for case: String in ["anvil_open", "pin_open", "anvil_wall", "pin_wall"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.bot_alt = case.begins_with("pin")
		var wall: StaticBody3D = _wall(Vector3(0, 1, 7.5)) if case.ends_with("wall") else null
		await physics_frame
		await physics_frame
		var foes: Array = [_foe(Vector3(0.5, 0, 3.0)), _foe(Vector3(-0.5, 0, 3.4)), _foe(Vector3(0.0, 0, 2.6))]
		await physics_frame
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		var landed: int = hero.breakers_landed
		hero._start_attack("XW")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		var opts: Array = hero.breaker_window().get("options", [])
		_check(opts.size() == 2 and opts[0].button == "light" and opts[0].name == "Pinwheel" and opts[0].element == "wind"
			and opts[1].name == "Anvil", "%s: the window offers LMB Pinwheel (storm), RMB Anvil (%s)" % [case, str(opts)])
		var held: int = hero._void.held_foes().size()
		await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed and held == 3, "%s: lands, holding the three (%d)" % [case, held])
		if case.begins_with("pin"):
			await _until(func() -> bool: return foes.any(func(f: Foe) -> bool: return f.has_meta("thrown_foe_flying")), 0.5)
			await _until(func() -> bool: return foes.all(func(f: Foe) -> bool: return not f.has_meta("thrown_foe_flying")), 3.0)
		for i in 30:
			await physics_frame
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		if case == "pin_wall":
			_check(foes.all(func(f: Foe) -> bool: return f.global_position.z > 5.0 and ve.wall_fresh(f)),
				"Pinwheel hurls them into the wall (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.z, 0.1))))
		for f: Foe in foes:
			f.free()
		if wall != null:
			wall.free()
		await _settle()
	print("  anvil pair: open anvil %.0f / pinwheel %.0f, by a wall anvil %.0f / pinwheel %.0f" % [dealt.anvil_open, dealt.pin_open, dealt.anvil_wall, dealt.pin_wall])
	_check(dealt.pin_wall > dealt.anvil_wall, "by a wall: Pinwheel out-damages Anvil (%.0f vs %.0f)" % [dealt.pin_wall, dealt.anvil_wall])
	_check(dealt.anvil_open > dealt.pin_open, "in the open: Anvil out-damages Pinwheel (%.0f vs %.0f)" % [dealt.anvil_open, dealt.pin_open])
	# Cataclysm / Tempest (XF): a crowd of five round the gale, or a pair.
	dealt = {}
	for case: String in ["cata_crowd", "temp_crowd", "cata_pair", "temp_pair"]:
		hero.global_position = Vector3.ZERO
		hero._face(Vector3(0, 0, 1))
		hero.model.position.y = 0.0
		hero.bot_alt = case.begins_with("temp")
		var spots: Array = [Vector3(0.6, 0, 3.0), Vector3(-0.8, 0, 3.4)]
		if case.ends_with("crowd"):
			spots += [Vector3(1.8, 0, 2.2), Vector3(-1.9, 0, 2.0), Vector3(0.2, 0, 4.6)]
		var foes: Array = spots.map(func(p: Vector3) -> Foe: return _foe(p))
		await physics_frame
		var before: Array = foes.map(func(f: Foe) -> float: return f.hp)
		var landed: int = hero.breakers_landed
		hero._start_attack("XF")
		await _until(func() -> bool: return hero.state == hero.State.LEAP, 3.0)
		var opts: Array = hero.breaker_window().get("options", [])
		_check(opts.size() == 2 and opts[0].button == "light" and opts[0].name == "Tempest" and opts[0].element == "wind"
			and opts[1].name == "Cataclysm", "%s: the window offers LMB Tempest (storm), RMB Cataclysm (%s)" % [case, str(opts)])
		await _until(func() -> bool: return hero.breakers_landed > landed, 4.0)
		_check(hero.breakers_landed > landed, "%s: lands" % case)
		if case == "temp_crowd":
			await create_timer(0.4, true, false, true).timeout
			_check(foes.all(func(f: Foe) -> bool: return f.global_position.y > 1.5 and f.has_meta("thrown_foe_flying")),
				"Tempest takes the whole crowd up its column (%s)" % str(foes.map(func(f: Foe) -> float: return snappedf(f.global_position.y, 0.1))))
		await create_timer(1.2, true, false, true).timeout  # (the column runs on real time)
		for i in 20:
			await physics_frame
		_check(foes.all(func(f: Foe) -> bool: return not f.has_meta("thrown_foe_flying")), "%s: everyone let go (%s)" % [case, str(foes.map(func(f: Foe) -> String: return "%.0f/%s" % [f.hp, f.has_meta("thrown_foe_flying")]))])
		var sum := 0.0
		for i in foes.size():
			sum += before[i] - foes[i].hp
		dealt[case] = sum
		for f: Foe in foes:
			f.free()
		await _settle()
	print("  cataclysm pair: crowd of five cataclysm %.0f / tempest %.0f, a pair cataclysm %.0f / tempest %.0f" % [dealt.cata_crowd, dealt.temp_crowd, dealt.cata_pair, dealt.temp_pair])
	_check(dealt.temp_crowd > dealt.cata_crowd, "a crowd: Tempest out-damages Cataclysm (%.0f vs %.0f)" % [dealt.temp_crowd, dealt.cata_crowd])
	_check(dealt.cata_pair > dealt.temp_pair, "a pair: Cataclysm out-damages Tempest (%.0f vs %.0f)" % [dealt.cata_pair, dealt.temp_pair])
	hero.bot_alt = false
	hero.bot_enabled = false


func _wall(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 4, 0.5)
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body


## The ice string with the buttons, as he plays it, stopping to watch the frost spread before he vaults.
func _spear_by_hand(vault_button: String) -> void:
	var SPEAR: GDScript = load("res://scripts/frost_spear.gd")
	await _settle()
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var near := _foe(Vector3(1.5, 0, 5))
	var far := _foe(Vector3(-2, 0, 6))
	await _tap("attack_light")
	await _until(func() -> bool: return hero._move_id == "L1", 1.0)
	await _tap("attack_light")
	await _until(func() -> bool: return hero._move_id == "L2", 2.0)
	await _tap("attack_heavy")
	await _until(func() -> bool: return hero._move_id == "IP", 2.0)
	_check(hero._move_id == "IP", "by hand, L L H plants the spear (%s)" % hero._move_id)
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
	await create_timer(1.2).timeout
	_check(SPEAR.current(self) != null, "and it's still up after he's stopped to watch")
	await _tap(vault_button)
	await _until(func() -> bool: return hero._move_id == "IJ", 1.0)
	_check(hero._move_id == "IJ", "%s vaults (%s)" % [vault_button, hero._move_id])
	await _until(func() -> bool: return hero.model.position.y > 1.0, 1.5)
	_check(hero.model.position.y > 1.0, "up over it (%.1f m)" % hero.model.position.y)
	var landed: int = hero.breakers_landed
	await _tap("attack_heavy")
	await _until(func() -> bool: return hero._move_id == "IS", 2.0)
	_check(hero._move_id == "IS", "right click comes down on it (%s)" % hero._move_id)
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	_check(near.frozen and far.frozen, "and they freeze")
	_check(SPEAR.current(self) == null, "and the spear's gone")
	await _until(func() -> bool: return hero.state == hero.State.LEAP, 2.0)
	_check(hero.state == hero.State.LEAP, "the window opens")
	await _until(func() -> bool: return hero._state_t >= hero._brk.sweet, 3.0)
	await _tap("attack_heavy")
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(hero.breakers_landed == landed + 1, "right click in it lands Avalanche")
	_check(near.global_position.distance_to(far.global_position) < 2.2, "and slams the cubes together (%.1f m)" % near.global_position.distance_to(far.global_position))
	for f: Node3D in [near, far]:
		if is_instance_valid(f):
			f.free()
	await _settle()


## One cube on its own comes back down where it was.
func _one_cube() -> void:
	await _settle()
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	var lone := _foe(Vector3(1.0, 0, 4))
	var landed: int = hero.breakers_landed
	hero.bot_enabled = true
	hero._start_attack("IP")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	hero._start_attack("IJ")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	hero._start_attack("IS")
	await _until(func() -> bool: return hero._hits_done > 0, 3.0)
	var was := lone.global_position
	await _until(func() -> bool: return hero.breakers_landed > landed, 3.0)
	_check(hero.breakers_landed == landed + 1, "one cube's still an Avalanche")
	_check(Vector2(lone.global_position.x - was.x, lone.global_position.z - was.z).length() < 0.2, "and it comes down where it was")
	hero.bot_enabled = false
	lone.free()
	await _settle()


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _foe(at: Vector3) -> Foe:
	var f := Foe.new()
	world.add_child(f)
	f.global_position = at
	f.add_to_group("enemies")
	return f


func _settle() -> void:
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 3.0)
	for i in 30:
		await physics_frame


func _until(done: Callable, seconds: float) -> void:
	var t := 0.0
	while not done.call() and t < seconds:
		await physics_frame
		t += 1.0 / 60.0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("  FAIL: ", what)
