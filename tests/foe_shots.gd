extends SceneTree
## Foes next to the hero, for judging proportion and line weight by eye (windowed only):
##   godot --path . -s tests/foe_shots.gd -- --tag=after
## Saves user://foe_shots/<tag>_room.png (the training room as it opens, game camera),
## <tag>_row_game.png (hero, dummy and every foe in two rows, game camera) and
## <tag>_row_close.png (the same, closer, ortho along the game's angle) and <tag>_row_front.png
## (ortho from the front). Headless it saves nothing. `-- --bars` shows every foe's health bar
## (enemy_bars.gd at each kind's bar_height) in the row shots.
## `-- --clip=run|Hit_A|Hit_B|Lie_StandUp|Death_A [--frames=N] [--turn=-70]`: N close shots through that clip
## (<tag>_<clip>_NN.png); `run` plays each kind's run at its game clip speed and moves it along its
## facing at move_speed, so planted feet that skate slide on the floor between shots.

const FRONT := ["hero", "dummy", "minion", "rogue", "shield", "warrior"]
const BACK := ["mage", "archer"]
const STEP := 2.0  # m between models in a row
const FRONT_Z := 3.0  # m in front of the hero's spot (towards the camera)
const BACK_Z := 0.0
const CLOSE_SIZE := 9.0  # m tall, ortho, along the game's angle
const FRONT_SIZE := 7.5  # m tall, ortho, from the front at chest height

## `--side`: the front shot from 90 degrees off the sun (main.gd's -35 degree yaw), models turned to it,
## so each body shows its lit and shadow halves side by side (judging FOE_SHADE_MATCH against the hero).
const SIDE_DIR := Vector3(0.82, 0.0, 0.57)

var _bars := false
var _side := false
var _turn := 0.0  # `--turn=deg`: every model turned this far from facing the camera (side light on the faces)
var _clip := ""
var _frames := 8
var _only: PackedStringArray = []  # `--only=minion,rogue`: film just these, spread in a row
var game_view := Vector3.ZERO  # camera_rig.rest_view(): the game camera's offset, the game's angle


func _initialize() -> void:
	await process_frame
	game_view = load("res://scripts/camera_rig.gd").rest_view(OS.get_cmdline_user_args()).offset
	var tag := "shot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.substr(6)
		elif arg == "--bars":
			_bars = true
		elif arg == "--side":
			_side = true
			_turn = SIDE_DIR.signed_angle_to(Vector3.BACK, Vector3.DOWN)
		elif arg.begins_with("--turn="):
			_turn = deg_to_rad(float(arg.substr(7)))
		elif arg.begins_with("--clip="):
			_clip = arg.substr(7)
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
	var dir := "user://foe_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.combo_guide = false
	game._hints_seen = game.HINTS.keys()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.6).timeout
	await _save("%s/%s_room.png" % [dir, tag])

	var p: Node3D = main.player
	p.set_physics_process(false)
	p.set_process(false)
	var at: Vector3 = p.global_position
	var dummy: Node3D = main._dummies[0]
	for d: Node3D in main._dummies.slice(1):
		d.queue_free()
	for e in get_nodes_in_group("enemies"):
		if e != dummy and not e in main._dummies:
			e.queue_free()
	var placed := {}
	for i in FRONT.size():
		placed[FRONT[i]] = at + Vector3((i - (FRONT.size() - 1) * 0.5) * STEP, 0.0, FRONT_Z)
	for i in BACK.size():
		placed[BACK[i]] = at + Vector3((i - (BACK.size() - 1) * 0.5) * STEP * 1.2, 0.0, BACK_Z)
	var nodes := {"hero": p, "dummy": dummy}
	for kind: String in placed:
		if nodes.has(kind):
			continue
		nodes[kind] = main._spawn(kind, false, placed[kind])
		nodes[kind].global_position = placed[kind]
		nodes[kind].set_physics_process(false)  # no chase, no windup rings
	await create_timer(1.4).timeout
	for kind: String in nodes:
		var n: Node3D = nodes[kind]
		n.set_physics_process(false)
		n.global_position = placed[kind]
		n.model.rotation = Vector3(0.0, _turn, 0.0)  # facing +Z, the camera, unless --turn
		var anim: AnimationPlayer = n.anim
		var idle := "Idle" if kind == "hero" else "Idle_Combat"
		if kind != "hero" and n.get("comic_kind") != "":
			idle = load("res://scripts/comic_look.gd").clip(anim, n.comic_kind, idle)
		if anim.has_animation(idle):
			anim.play(idle)
			anim.seek(0.3, true)
			anim.pause()
	await create_timer(0.3).timeout
	await _save("%s/%s_row_game.png" % [dir, tag])
	var cam := Camera3D.new()
	get_root().add_child(cam)
	var centre := at + Vector3(0.0, 1.0, FRONT_Z * 0.5)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CLOSE_SIZE
	cam.global_position = centre + game_view
	cam.look_at(centre)
	cam.make_current()
	await create_timer(0.3).timeout
	if _clip != "":
		await _film(nodes, placed, cam, dir, tag)
		quit()
		return
	await _save("%s/%s_row_close.png" % [dir, tag])
	cam.size = FRONT_SIZE
	cam.global_position = centre + (Vector3(0.0, 1.2, 0.0) + SIDE_DIR * 9.0 if _side else Vector3(0.0, 1.2, 9.0))
	cam.look_at(centre + Vector3(0.0, 0.2, 0.0))
	await create_timer(0.2).timeout
	await _save("%s/%s_row_front.png" % [dir, tag])
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


## Every foe through one clip, `_frames` shots, from the close game-angle camera.
func _film(nodes: Dictionary, placed: Dictionary, cam: Camera3D, dir: String, tag: String) -> void:
	var look: GDScript = load("res://scripts/comic_look.gd")
	var facing := Vector3(sin(_turn), 0.0, cos(_turn))
	nodes["hero"].visible = false
	nodes["dummy"].visible = false
	if not _only.is_empty():
		var at := cam.global_position - game_view - Vector3(0.0, 1.0, 0.0)  # the close camera's floor centre
		cam.size = 1.2 * _only.size() + 2.0
		for kind: String in nodes:
			if kind in ["hero", "dummy"]:
				continue
			var k := _only.find(kind)
			nodes[kind].visible = k >= 0
			if k >= 0:
				placed[kind] = at + Vector3((k - (_only.size() - 1) * 0.5) * 3.2, 0.0, 0.0)
	for i in _frames:
		for kind: String in nodes:
			if kind in ["hero", "dummy"] or not nodes[kind].visible:
				continue
			var n: Node3D = nodes[kind]
			n.global_position = placed[kind]
			var anim: AnimationPlayer = n.anim
			var want: String = n.run_anim if _clip == "run" else _clip
			var clip: String = look.clip(anim, n.comic_kind, want) if n.get("comic_kind") != "" else want
			if not anim.has_animation(clip):
				continue
			var length := anim.get_animation(clip).length
			var t := length * i / _frames
			if _clip == "run":
				var speed: float = n.run_clip_speed(n.move_speed) if n.has_method("run_clip_speed") else 1.0
				n.global_position = placed[kind] + facing * n.move_speed * t / speed - facing * 0.6
			anim.play(clip)
			anim.seek(t, true)
			anim.pause()
		await create_timer(0.12).timeout
		await _save("%s/%s_%s_%02d.png" % [dir, tag, _clip, i])


func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _bars:
		for e in get_nodes_in_group("enemies"):
			if "last_hit_ms" in e:
				e.last_hit_ms = Time.get_ticks_msec()
				if e.state == e.State.SPAWN:  # bars skip spawning foes; physics is off, so nothing else reads it
					e.state = e.State.CHASE
		await process_frame
		await process_frame
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
