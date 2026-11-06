extends SceneTree
## Films the dragon prince's core loop from the game camera (windowed): Javelin, the smash, the new sword,
## Dragon Breath, Royal Chain, a second Javelin and Rightful Return. Frames are held in memory (half size) and
## written at the end to user://<dir>/NNN.png (default prince_film), 30 a second of real time, with INDEX.txt
## (ms, move, sword state). Make a clip: ffmpeg -framerate 30 -i NNN.png ...
## Run: godot --path . -s tests/prince_film.gd [-- --dir=name]

const FPS := 30.0

var _frames: Array[Image] = []
var _index: Array[String] = []
var _t0 := 0
var _next_ms := 0.0
var _p: Node
var _dir := "prince_film"
var _filming := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			_dir = a.trim_prefix("--dir=")
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.hero = "prince"
	get_root().size = Vector2i(1920, 1080)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(2.0).timeout
	_p = main.player
	_p.bot_enabled = true
	_p.bot_move = Vector3.ZERO
	_face(main._dummies[0])
	_t0 = Time.get_ticks_msec()
	_filming = true
	process_frame.connect(_grab)
	await create_timer(0.4).timeout
	await _string(["light", "light", "heavy"])  # Javelin
	await _wait_planted()
	await create_timer(0.45).timeout
	_press("heavy")  # the smash
	await create_timer(1.6).timeout  # blast, kneel, the new sword
	var near: Node3D = _nearest(main)
	await _walk_to(near.global_position + Vector3(0.0, 0.0, 2.4))
	_face(near)
	_press("heavy")  # Dragon Breath
	await create_timer(0.9).timeout
	_face(_nearest(main))
	await _string(["light", "light", "light"])  # Royal Chain
	await create_timer(0.7).timeout
	_p.global_position += Vector3(0.0, 0.0, 3.0)
	_face(_nearest(main))
	await _string(["light", "light", "heavy"])  # Javelin again
	await _wait_planted()
	await create_timer(0.5).timeout
	_p.bot_move = Vector3(0.0, 0.0, 1.0)  # step back so the sword comes through the line
	await create_timer(0.35).timeout
	_p.bot_move = Vector3.ZERO
	_p.bot_hold_light = true
	_press("light")  # hold L: Rightful Return
	await create_timer(0.8).timeout
	_p.bot_hold_light = false
	await create_timer(0.6).timeout
	_filming = false
	_write()
	game.hero = "heretic"
	quit()


func _grab() -> void:
	if not _filming:
		return
	var ms := Time.get_ticks_msec() - _t0
	if ms < _next_ms:
		return
	_next_ms += 1000.0 / FPS
	var img := get_root().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	_frames.append(img)
	_index.append("%03d %5d ms  %-10s sword=%s y=%.2f ts=%.2f" % [_frames.size() - 1, ms, _p._move_id,
		_p.sword.state_word(), _p.model.position.y, Engine.time_scale])


func _write() -> void:
	DirAccess.make_dir_recursive_absolute("user://" + _dir)
	for i in _frames.size():
		_frames[i].save_png("user://%s/%03d.png" % [_dir, i])
	var f := FileAccess.open("user://%s/INDEX.txt" % _dir, FileAccess.WRITE)
	f.store_string("\n".join(_index) + "\n")
	print("[prince_film] %d frames to %s" % [_frames.size(), ProjectSettings.globalize_path("user://" + _dir)])


func _press(kind: String) -> void:
	_p._buffered = kind
	_p._buffer_t = _p.input_buffer


func _string(kinds: Array) -> void:
	for k: String in kinds:
		var n: int = _p.move_log.size()
		_press(k)
		for i in 60:
			if _p.move_log.size() > n:
				break
			await physics_frame
		await create_timer(0.2).timeout


func _wait_planted() -> void:
	for i in 90:
		if _p.sword.state == _p.sword.S.PLANTED:
			return
		await physics_frame


func _walk_to(at: Vector3) -> void:
	for i in 90:
		var to: Vector3 = at - _p.global_position
		to.y = 0.0
		if to.length() < 0.3:
			break
		_p.bot_move = to.normalized()
		await physics_frame
	_p.bot_move = Vector3.ZERO
	await create_timer(0.15).timeout


func _face(at: Node3D) -> void:
	var to: Vector3 = at.global_position - _p.global_position
	_p._face(Vector3(to.x, 0.0, to.z))


func _nearest(main: Node) -> Node3D:
	var best: Node3D = main._dummies[0]
	for d: Node3D in main._dummies:
		if d.global_position.distance_to(_p.global_position) < best.global_position.distance_to(_p.global_position):
			best = d
	return best
