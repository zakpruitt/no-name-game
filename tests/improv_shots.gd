extends SceneTree
## The element matrix's tells (comic_improv.gd), each from the game camera, played for real: the dummies stand in a
## fan in front of him, the first one is put in the cell's state (frozen / buried / molten / skewered / airborne /
## bound) and he plays the element's base move on it, so the payoff, its word and the move's own hit all show.
## Round 49: first the six states' rules (void_element.RULES, cell = the state, paid by RULE_HITTER's element), then
## every upgrade cell with its Kit id turned on for the shot.
## Six frames 83 ms apart from the move's first hit:
##   godot --path . -s tests/improv_shots.gd [-- --only=frozen,charged,frozen_x_void,bound_x_wind] [--alone]
##     user://improv_shots/<cell>/N.png (a 640x480 crop round the foe that pays; `--dir=<name>`: user://<name> instead)
## `--alone`: no move, only void_element.improvise() (the tell and its word on their own).
## Windowed only (headless draws nothing). `user://` is shared: copy it out at once.

const DIR := "user://improv_shots"
const BASE := {"wind": "EC", "water": "EF", "earth": "EM", "void": "VR"}  # each element's base move
## The element each rule is filmed with (any element but the state's own pays it).
const RULE_HITTER := {"frozen": "wind", "charged": "void", "molten": "wind", "bound": "wind", "airborne": "water", "buried": "water"}
const FRAMES := 6
const GAP_S := 0.083

var _main: Node
var _p: CharacterBody3D


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game._hints_seen = game.HINTS.keys()
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	_p = _main.player
	var waited := 0.0
	while get_nodes_in_group("enemies").is_empty() and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(1.5).timeout
	var el: GDScript = load("res://scripts/void_element.gd")
	var only := []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",")
	for state: String in el.RULES:
		if only.is_empty() or state in only:
			await _film(el, state, RULE_HITTER[state], state)
	for state: String in el.IMPROV_ORDER:
		for element: String in el.IMPROV.get(state, {}):
			var cell := "%s_x_%s" % [state, element]
			if only.is_empty() or cell in only:
				Kit.set_on(el.IMPROV_UPGRADE[cell], true)
				await _film(el, state, element, cell)
				Kit.set_on(el.IMPROV_UPGRADE[cell], false)
	print("[improv_shots] done ", ProjectSettings.globalize_path(_dir()))
	quit()


func _film(el: GDScript, state: String, element: String, cell: String) -> void:
	_gather()
	await create_timer(0.9).timeout
	_gather()
	await physics_frame
	var foes := get_nodes_in_group("enemies")
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(_p.global_position) < b.global_position.distance_to(_p.global_position))
	var e: Node3D = foes[0]
	match state:
		"frozen":
			el.encase(e)
		"airborne":
			e.take_hit(0.0, Vector3.ZERO, 9.0, false)
			await create_timer(0.3).timeout
		"bound":
			load("res://scripts/floor_bind.gd").bind(_p, [e], {"time": 3.0})
			await create_timer(0.2).timeout
		"skewered":
			el.encase(e)
			el.mark(e, state)
		"charged":  # (and two more, so the arc rule has somewhere to go)
			for o: Node3D in foes.slice(0, 3):
				el.mark(o, state)
		_:
			el.mark(e, state)
	await create_timer(0.15).timeout
	_p._face(e.global_position - _p.global_position)
	var t := 0.0
	var focus: Vector3 = e.global_position
	if "--alone" in OS.get_cmdline_user_args():
		el.improvise(_p, BASE[element], Vector3(_p.global_position.x, 0.0, _p.global_position.z), 1.0)
	else:
		_p._start_attack(BASE[element])
		while _p._hits_done == 0 and t < 2.0:
			await process_frame
			t += get_root().get_process_delta_time()
	var dir := "%s/%s" % [_dir(), cell]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in FRAMES:
		await process_frame
		var img := get_root().get_texture().get_image()
		var cam := get_root().get_camera_3d()
		var c := cam.unproject_position(focus + Vector3.UP * 0.9) * (Vector2(img.get_size()) / get_root().get_visible_rect().size)
		var r := Rect2i(Vector2i(c) - Vector2i(320, 260), Vector2i(640, 480)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(r).save_png("%s/%d.png" % [dir, i])
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int(GAP_S * 1000.0):
			await process_frame
	while _p.state != _p.State.MOVE and t < 5.0:
		await process_frame
		t += get_root().get_process_delta_time()
	get_root().get_node("Game").end_slowmo()


func _dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			return "user://" + arg.get_slice("=", 1)
	return DIR


func _gather() -> void:
	var el: GDScript = load("res://scripts/void_element.gd")
	for e: Node in get_nodes_in_group("enemies"):  # (nothing of the last cell carries into this one)
		load("res://scripts/floor_bind.gd").let_go_of(self, e)
		el.THROWN.remove_cube(e)
		for s: String in ["buried", "molten", "skewered", "charged"]:
			el.unmark(e, s)
		if e.get("frozen_t") != null:
			e.frozen_t = 0.0
	_p.global_position = Vector3(0.0, _p.global_position.y, 0.0)
	_p.velocity = Vector3.ZERO
	_p._face(Vector3(0.0, 0.0, -1.0))
	var fwd: Vector3 = _p._facing()
	var foes := get_nodes_in_group("enemies")
	for i in foes.size():
		var side := (i - (foes.size() - 1) * 0.5) * 1.4
		foes[i].global_position = _p.global_position + fwd * (2.2 + i % 2 * 1.0) + fwd.cross(Vector3.UP) * side
		foes[i].velocity = Vector3.ZERO
		if "home" in foes[i]:
			foes[i].home = foes[i].global_position
