extends SceneTree
## The void arm's H moves in the real game, at the game's camera, with real foes in front of him:
##   godot --path . -s tests/element_shots.gd     user://element_shots/<combo>_<0..2>.png
## Windowed only (headless draws nothing), about a minute. Sets its flags for this process only.

const DIR := "user://element_shots"
const COMBOS := [
	["shot", ["EB"]],
	["worldbreaker", ["L1", "EC", "EE"]],
	["shatterstorm", ["L2", "EF", "EA"]],
	["absolutezero", ["L3", "EM", "EV"]],
	["thunderclap", ["DL", "EG"]],
	["landslide", ["CH"]],
	["convergence", ["L1", "EC", "L2", "EF", "L3", "EM"]],
]

var _p: CharacterBody3D


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.skip_title = true
	game._comic_cli = true
	game.heretic = true
	game._hints_seen = game.HINTS.keys()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_p = main.player
	var waited := 0.0
	while get_nodes_in_group("enemies").is_empty() and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(1.5).timeout
	if "_queue" in main:
		main._queue.clear()
	for combo: Array in COMBOS:
		await _film(combo[0], combo[1])
	print("[element_shots] done, %d foes left" % get_nodes_in_group("enemies").size())
	quit(0)


func _film(combo_name: String, moves: Array) -> void:
	await _ready_up()
	_p.bot_enabled = true  # presses each breaker at its sweet spot
	for i in moves.size():
		_gather()
		_p._start_attack(moves[i])
		await _until_hit()
		await create_timer(0.03).timeout
	await _shot("%s_0" % combo_name)  # the last move's hit
	await create_timer(0.14).timeout
	await _shot("%s_1" % combo_name)  # its shots on the way
	var t := 0.0
	while _p.state != _p.State.LEAP and t < 1.0:
		await process_frame
		t += _p.get_process_delta_time()
	if _p.state == _p.State.LEAP:
		while _p.state == _p.State.LEAP and _state_t() < 0.3:
			await process_frame
		await _shot("%s_2" % combo_name)  # held up in the hang
		while _p.state == _p.State.LEAP:
			await process_frame
		await create_timer(0.04).timeout
		await _shot("%s_3" % combo_name)  # the slam
		await create_timer(0.2).timeout
		await _shot("%s_4" % combo_name)  # what comes up through the floor
	print("[element_shots] %s breakers=%d last=%s" % [combo_name, _p.breakers_landed, _p.breaker_name()])
	_p.bot_enabled = false
	await create_timer(1.6).timeout


func _state_t() -> float:
	return _p._state_t


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [DIR, file])


## Back to the middle, unhurt, with nothing left of the last shot's foes' injuries.
func _ready_up() -> void:
	var t := 0.0
	while _p.state != _p.State.MOVE and t < 3.0:
		await create_timer(0.05).timeout
		t += 0.05
	_p._invuln_t = 999.0
	_p.global_position = Vector3(0.0, _p.global_position.y, 0.0)
	_p._face(Vector3(0.0, 0.0, -1.0))
	for e in get_nodes_in_group("enemies"):
		if "hp" in e:
			e.hp = 9999.0
	await create_timer(0.25).timeout


## The foes in a loose fan in front of him.
func _gather() -> void:
	var fwd: Vector3 = _p._facing()
	var foes := get_nodes_in_group("enemies")
	for i in foes.size():
		var side := (i - (foes.size() - 1) * 0.5) * 1.4
		foes[i].global_position = _p.global_position + fwd * (2.6 + i % 2 * 1.2) + fwd.cross(Vector3.UP) * side


func _until_hit() -> void:
	var t := 0.0
	while _p._hits_done == 0 and t < 3.0:
		await process_frame
		t += _p.get_process_delta_time()
