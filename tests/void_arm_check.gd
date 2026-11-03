extends SceneTree
## The void arm, headless: E's routing and targeting, the grab pulling a foe in, the big foe pulling him,
## the pillar swing and fling, a dash out of it, the slam with its finisher, and the arm's shapes per move.
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
	func is_alive() -> bool: return hp > 0.0
	func is_airborne() -> bool: return false
	func stagger(_t: float) -> void: pass
	func take_hit(d: float, _kb = Vector3.ZERO, _l = 0.0, big = false, _x = null) -> void:
		hp -= d
		hits += 1
		last_big = big


func _initialize() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.comic_style = true
	game.comic_moves = true
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
	await _dash_out()
	await _slam_finisher()
	await _whiff()
	print("void_arm_check: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(1 if fails > 0 else 0)


func _routing() -> void:
	var r: Callable = load("res://scripts/player.gd").void_route
	_check(r.call("light", "", false, 0, false) == "L1", "L: axe")
	_check(r.call("light", "L1", true, 1, false) == "L2", "L L: spear")
	_check(r.call("light", "L2", true, 2, false) == "L3", "L L L: hammer")
	_check(r.call("special", "L3", true, 0, false) == "VS", "L L L E: the slam")
	_check(r.call("special", "GR", true, 0, false) == "VS", "E E: grab into slam")
	_check(r.call("special", "", false, 0, false) == "GR", "E from neutral: the grab")
	_check(r.call("special", "VS", true, 0, false) == "GR", "E off the slam grabs again")
	_check(r.call("light", "GR", true, 0, false) == "L1", "a grab flows into the string")
	_check(r.call("light", "", false, 0, true) == "DL", "dash L: the spear lunge")
	_check(r.call("heavy", "", false, 0, true) == "DH", "dash H")
	_check(r.call("heavy", "L1", true, 1, false) == "H", "no launcher for now: heavy is the spin")
	# The pause menu lists every move he can reach, and only real ones.
	var list: GDScript = load("res://scripts/move_list.gd")
	var listed := {}
	for section: Dictionary in list.VOID_SECTIONS:
		for row: Dictionary in section.rows:
			if row.kind == "move":
				listed[row.id] = true
				_check(hero.MOVES.has(row.id) or hero.COMBOS.has(row.id), "listed move %s exists" % row.id)
	for id: String in ["L1", "L2", "L3", "H", "CH", "DL", "DH", "VS", "SHAPEBREAKER"]:
		_check(listed.has(id), "%s is on his move list" % id)
	_check(list.sections_for(hero) == list.VOID_SECTIONS, "the menu shows him his own list")
	_check(hero.COMBOS.has("SHAPEBREAKER") and hero.COMBOS.SHAPEBREAKER.tier == 3, "the finisher is top tier")


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
	_check(arm.form == "axe", "he rests with the axe")
	var look: GDScript = load("res://scripts/comic_look.gd")
	for form: String in look.HERO_FORMS:
		for part: String in look.HERO_FORMS[form]:
			var mi: MeshInstance3D = hero.model.find_child(part, true, false)
			_check(mi != null, "%s: mesh %s" % [form, part])
			if mi != null:
				_check(mi.visible == (form == "axe"), "%s shown only with its form" % part)
	for id: String in ["L1", "L2", "L3"]:
		hero._start_attack(id)
		var want: String = look.HERO_MOVE_FORMS.get(id, "axe")
		_check(arm.form == want, "%s: the arm is %s (%s)" % [id, want, arm.form])
		_check(hero.anim.current_animation != "", "%s plays" % id)
		var head: MeshInstance3D = hero.model.find_child(look.HERO_FORMS[want][0], true, false)
		_check(head.visible, "%s: its form is showing" % id)
	hero._set_state(hero.State.MOVE)
	_check(arm.form == "axe", "back to moving: the axe")


func _grab() -> void:
	var f := _foe(hero.global_position + Vector3(0, 0, 6))
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("GR")
	_check(hero.state == hero.State.ATTACK and hero._move_id == "GR", "E at a foe plays the grab")
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
	_check(hero.state == hero.State.SWING, "E at something big sends him travelling")
	await _until(func() -> bool: return hero.state != hero.State.SWING, 1.5)
	var d: float = f.global_position.distance_to(hero.global_position)
	_check(d < 3.0, "he got to it (%.2f m)" % d)
	_check(f.global_position.distance_to(hero.global_position + Vector3(0, 0, d)) < 1.5, "it didn't move")
	_check(hero._move_id == "L1" and hero.state == hero.State.ATTACK, "he arrives swinging")
	f.free()
	await _settle()


func _swing() -> void:
	hero.global_position = Vector3.ZERO
	var p := Node3D.new()
	world.add_child(p)
	p.add_to_group("grab_anchors")
	p.global_position = Vector3(0, 0, 4)
	hero._face(Vector3(0, 0, 1))
	var f := _foe(Vector3(3.2, 0, 7))
	hero._start_attack("GR")
	_check(hero.state == hero.State.SWING, "E at a pillar swings")
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


func _dash_out() -> void:
	hero.global_position = Vector3.ZERO
	var p := Node3D.new()
	world.add_child(p)
	p.add_to_group("grab_anchors")
	p.global_position = Vector3(0, 0, 4)
	hero._face(Vector3(0, 0, 1))
	hero._dash_cd = 0.0
	hero._start_attack("GR")
	await physics_frame
	await physics_frame
	hero._dash_buffer_t = 0.2
	await physics_frame
	await physics_frame
	_check(hero.state == hero.State.DASH, "a dash cuts the swing")
	_check(not hero._void.tendril.visible, "and lets go")
	p.free()
	await _settle()


func _slam_finisher() -> void:
	hero.global_position = Vector3.ZERO
	var f := _foe(Vector3(0, 0, 2))
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("L1")
	hero._start_attack("L2")
	hero._start_attack("L3")
	hero._start_attack("VS")
	_check(hero._void.after_string, "off the hammer it's the finisher")
	_check(hero.named_id() == "SHAPEBREAKER", "it has the name")
	_check(hero._move.damage > hero.MOVES.VS.damage, "and the power")
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
	await _settle()
	hero._start_attack("VS")
	_check(not hero._void.after_string, "off nothing it's the plain slam")
	_check(hero.named_id() == "VS", "with the plain name")
	await _settle()


func _whiff() -> void:
	hero.global_position = Vector3.ZERO
	hero._face(Vector3(0, 0, 1))
	hero._start_attack("GR")
	_check(hero.state == hero.State.ATTACK, "E at nothing whips")
	await _until(func() -> bool: return hero.state == hero.State.MOVE, 2.0)
	_check(hero.state == hero.State.MOVE and not hero._connected, "and plays out")


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
