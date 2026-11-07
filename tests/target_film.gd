extends SceneTree
## Films the round 51 foe picks from the game camera (windowed): hold H to charge Overwhelm with two dummies ahead,
## the bracket on the auto pick, the cursor (env_target.test_cursor, standing in for the mouse) moving onto the other
## mid-hold so the bracket switches; release: Overwhelm pins that one; Abyss's window, the cursor switching between the
## two pinned; the landing (the picked one comes up first). Frames to user://<dir>/target/NNN.png + INDEX.txt.
##   godot --path . -s tests/target_film.gd [-- --dir=name] [--fps=N]

const SIZE := Vector2i(800, 450)

var _main: Node
var _p: CharacterBody3D
var _env: Node
var _dir := "user://target_film"
var _fps := 24.0
var _frames: Array = []
var _t0 := 0
var _n := 0
var _filming := false


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game._hints_seen = game.HINTS.keys()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = "user://" + arg.substr(6)
		elif arg.begins_with("--fps="):
			_fps = float(arg.substr(6))
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	_p = _main.player
	_env = _main.env
	await create_timer(1.8).timeout
	var a: Node3D = _main._dummies[0]
	var b: Node3D = _main._dummies[1]
	for i in _main._dummies.size():
		var d: Node3D = _main._dummies[i]
		d.home = [Vector3(-1.0, 0, -1.6), Vector3(1.6, 0, -2.4), Vector3(-9, 0, 7), Vector3(9, 0, 7)][i]
		d.global_position = d.home
	_p.global_position = Vector3(0, 0, 1.8)
	_p._face(Vector3(0, 0, -1))
	await create_timer(1.0).timeout
	_filming = true
	_t0 = Time.get_ticks_msec()
	_env.test_cursor = Vector3.INF
	Input.action_press("attack_heavy")
	await create_timer(1.3).timeout  # (charged at 0.8 s: the bracket on a, the nearest ahead)
	_env.test_cursor = b.global_position
	await create_timer(0.7).timeout
	_env.test_cursor = a.global_position
	await create_timer(0.45).timeout
	_env.test_cursor = b.global_position
	await create_timer(0.5).timeout
	Input.action_release("attack_heavy")
	var waited := 0.0
	while not (_p.state == _p.State.LEAP and _p._brk_phase == 0) and waited < 3.0:
		await physics_frame
		waited += 1.0 / 60.0
	# Abyss's window: the cursor flicks between the two pinned, ends on b
	_env.test_cursor = a.global_position
	await create_timer(0.12).timeout
	_env.test_cursor = b.global_position
	waited = 0.0
	while _p.state == _p.State.LEAP and _p._brk_phase == 0 and _p._state_t < _p._brk.sweet and waited < 3.0:
		await physics_frame
		waited += 1.0 / 60.0
	Input.action_press("attack_heavy")
	await physics_frame
	await physics_frame
	Input.action_release("attack_heavy")
	await create_timer(2.2).timeout
	_env.test_cursor = Vector3.INF
	_filming = false
	_flush()
	quit(0)


func _process(_delta: float) -> bool:
	if not _filming:
		return false
	var now := Time.get_ticks_msec()
	if now - _t0 < _n * 1000.0 / _fps:
		return false
	_n = int((now - _t0) * _fps / 1000.0) + 1
	var img: Image = get_root().get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	var pick: String = str(_env.current.get("ctx", "-"))
	if _env.current.has("s"):
		pick += ":" + str(_env.current.s.id) + (" chosen" if _env.current.chosen else " auto")
	_frames.append([img, "%03d t=%5d ms state=%-6s move=%-3s brk=%d pick=%s scale=%.2f" % [_frames.size(), now - _t0,
		_p.State.keys()[_p.state], _p._move_id, _p._brk_phase if _p.state == _p.State.LEAP else -1, pick, Engine.time_scale]])
	return false


func _flush() -> void:
	var dir := "%s/target" % _dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var index := PackedStringArray(["target at %d fps, %dx%d, game camera" % [int(_fps), SIZE.x, SIZE.y]])
	for i in _frames.size():
		_frames[i][0].save_png("%s/%03d.png" % [dir, i])
		index.append(_frames[i][1])
	var f := FileAccess.open(dir + "/INDEX.txt", FileAccess.WRITE)
	f.store_string("\n".join(index) + "\n")
	f.close()
	print("[target_film] frames=%d" % _frames.size())
