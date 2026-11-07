extends SceneTree
## Round 55 (combo-cool4): films one foe pick from the game camera (windowed) with a drawn mouse pointer where the cursor
## stands in (env_target.test_cursor), so the choice is seen: the bracket on the auto pick, the pointer moving onto
## another foe, the bracket switching, the press, and the move landing where it was sent. One case a run:
##   godot --path . -s tests/pick_film.gd -- --case=<name> [--dir=name] [--fps=N]
## Cases (CASES below): singularity (the held one thrown onto a far foe), spear (Frost Spear's plant), reap (the hook),
## tow (Tow Line's anchor), rockslide (the boulder's landing), deep_freeze (the first block of the wave), dash_stab (no
## cursor: the lash catching the one behind).
## Frames to user://<dir>/<case>/NNN.png + INDEX.txt.

const SIZE := Vector2i(800, 450)

## Each case: the four dummies' spots, his spot and facing, then steps: ["L"] / ["H"] / ["D"] a tap, ["wait", s],
## ["cursor", dummy index] (or -1: off), ["hold", s] H held that long, ["sweet", "L" | "H"] the window's press at its
## sweet spot.
const CASES := {
	"singularity": {"spots": [Vector3(0, 0, -1.2), Vector3(-5.0, 0, -0.4), Vector3(-5.6, 0, 0.7), Vector3(9, 0, 7)],
		"me": Vector3(0, 0, 1.6), "face": Vector3(0, 0, -1),
		"steps": [["H"], ["wait", 0.3], ["cursor", 1], ["wait", 0.08], ["H"], ["wait", 2.4]]},
	"spear": {"spots": [Vector3(0.8, 0, -0.6), Vector3(1.8, 0, -1.0), Vector3(-4.4, 0, 0.6), Vector3(-5.0, 0, 1.7)],
		"me": Vector3(0, 0, 1.8), "face": Vector3(0, 0, -1),
		"steps": [["L"], ["wait", 0.26], ["L"], ["wait", 0.12], ["H"], ["wait", 0.18], ["cursor", 2], ["wait", 2.0]]},
	"reap": {"spots": [Vector3(0.4, 0, -0.8), Vector3(-5.2, 0, 0.4), Vector3(5.4, 0, -0.6), Vector3(9, 0, 7)],
		"me": Vector3(0, 0, 1.8), "face": Vector3(0, 0, -1),
		"steps": [["H"], ["wait", 0.12], ["L"], ["wait", 0.14], ["cursor", 2], ["wait", 2.0]]},
	"tow": {"spots": [Vector3(-1.4, 0, -1.2), Vector3(1.2, 0, -1.8), Vector3(4.8, 0, 0.4), Vector3(9, 0, 7)],
		"me": Vector3(0, 0, 2.4), "face": Vector3(0, 0, -1),
		"steps": [["D"], ["wait", 0.05], ["H"], ["wait", 0.06], ["cursor", 2], ["wait", 2.0]]},
	"rockslide": {"spots": [Vector3(0.4, 0, -1.2), Vector3(-1.6, 0, -1.6), Vector3(4.6, 0, -0.6), Vector3(5.4, 0, 0.5)],
		"me": Vector3(0, 0, 1.6), "face": Vector3(0, 0, -1),
		"steps": [["L"], ["wait", 0.24], ["H"], ["wait", 0.36], ["L"], ["wait", 0.3], ["L"], ["wait", 0.06], ["cursor", 2], ["wait", 2.0]]},
	"deep_freeze": {"spots": [Vector3(-1.2, 0, -1.4), Vector3(1.2, 0, -1.8), Vector3(3.6, 0, -1.6), Vector3(7.6, 0, -2.2)],
		"me": Vector3(0, 0, 1.8), "face": Vector3(0, 0, -1),
		"steps": [["L"], ["wait", 0.26], ["L"], ["wait", 0.12], ["H"], ["wait", 0.4], ["L"], ["wait", 0.3], ["H"], ["wait", 0.05],
			["cursor", 2], ["wait", 2.2]]},
	"dash_stab": {"spots": [Vector3(0, 0, -0.4), Vector3(0.4, 0, -4.4), Vector3(-9, 0, 7), Vector3(9, 0, 7)],
		"me": Vector3(0, 0, 3.0), "face": Vector3(0, 0, -1),
		"steps": [["D"], ["wait", 0.08], ["L"], ["wait", 1.8]]},
}

var _main: Node
var _p: CharacterBody3D
var _env: Node
var _dir := "user://pick_film"
var _case := "singularity"
var _fps := 24.0
var _frames: Array = []
var _t0 := 0
var _n := 0
var _filming := false
var _pointer: Polygon2D
var _cursor_on := -1


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
		elif arg.begins_with("--case="):
			_case = arg.substr(7)
	var spec: Dictionary = CASES[_case]
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	_p = _main.player
	_env = _main.env
	_pointer_layer()
	await create_timer(1.8).timeout
	for i in _main._dummies.size():
		var d: Node3D = _main._dummies[i]
		d.home = spec.spots[i]
		d.global_position = d.home
	_p.global_position = spec.me
	_p._face(spec.face)
	await create_timer(1.0).timeout
	_filming = true
	_t0 = Time.get_ticks_msec()
	_env.test_cursor = Vector3.INF
	await create_timer(0.25).timeout
	for step: Array in spec.steps:
		match step[0]:
			"L", "H", "D":
				var act: String = {"L": "attack_light", "H": "attack_heavy", "D": "dash"}[step[0]]
				Input.action_press(act)
				await physics_frame
				await physics_frame
				Input.action_release(act)
			"wait":
				await create_timer(step[1]).timeout
			"cursor":
				_cursor_on = step[1]
	_env.test_cursor = Vector3.INF
	_cursor_on = -1
	_filming = false
	_flush()
	quit(0)


func _pointer_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_root().add_child(layer)
	_pointer = Polygon2D.new()
	var arrow := PackedVector2Array([Vector2(0, 0), Vector2(0, 30), Vector2(8, 23), Vector2(14, 36), Vector2(20, 33), Vector2(14, 21), Vector2(24, 21)])
	_pointer.polygon = arrow
	_pointer.color = Color.WHITE
	var ink := Line2D.new()
	var loop := arrow.duplicate()
	loop.append(arrow[0])
	ink.points = loop
	ink.width = 3.0
	ink.default_color = Color(0.05, 0.03, 0.1)
	_pointer.add_child(ink)
	_pointer.scale = Vector2.ONE * 2.2
	_pointer.visible = false
	layer.add_child(_pointer)


func _physics_process(_delta: float) -> bool:
	if _cursor_on >= 0 and _cursor_on < _main._dummies.size():
		var d: Node3D = _main._dummies[_cursor_on]
		_env.test_cursor = Vector3(d.global_position.x, 0.0, d.global_position.z)
	return false


func _process(_delta: float) -> bool:
	if _pointer != null:
		var cam: Camera3D = get_root().get_viewport().get_camera_3d()
		_pointer.visible = _env != null and _env.test_cursor != Vector3.INF and cam != null
		if _pointer.visible:
			_pointer.position = cam.unproject_position(_env.test_cursor + Vector3.UP * 0.9)
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
	_frames.append([img, "%03d t=%5d ms state=%-6s move=%-3s brk=%d pick=%s cursor=%d scale=%.2f" % [_frames.size(), now - _t0,
		_p.State.keys()[_p.state], _p._move_id, _p._brk_phase if _p.state == _p.State.LEAP else -1, pick, _cursor_on, Engine.time_scale]])
	return false


func _flush() -> void:
	var dir := "%s/%s" % [_dir, _case]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var index := PackedStringArray(["%s at %d fps, %dx%d, game camera" % [_case, int(_fps), SIZE.x, SIZE.y]])
	for i in _frames.size():
		_frames[i][0].save_png("%s/%03d.png" % [dir, i])
		index.append(_frames[i][1])
	var f := FileAccess.open(dir + "/INDEX.txt", FileAccess.WRITE)
	f.store_string("\n".join(index) + "\n")
	f.close()
	print("[pick_film] %s frames=%d" % [_case, _frames.size()])
