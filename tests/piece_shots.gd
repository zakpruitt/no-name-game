extends SceneTree
## The env-art pieces (brazier, pool, hook, ledge) beside the hero, for judging scale and whether they read as the
## comic dungeon kit (windowed only; headless saves nothing):
##   godot --path . -s tests/piece_shots.gd -- --room=pieces [--tag=x]
## Saves user://piece_shots/<tag>_room.png (the room with pieces as it opens), <tag>_<piece>.png (the hero stood by
## each placed piece, from the game camera's angle and distance) and <tag>_lineup_game.png / _lineup_close.png /
## _lineup_front.png (every new model in a row with the hero and kit pieces: the barrel, a crate, a torch on a wall).
## Every shot is also written at 800x450 (<name>_800.png), the size the art is judged at.

const SHOT := Vector2i(800, 450)
const LINE_Z := 8.5  # the lineup's row, in front of the dummies (behind the near edge's 3.5 m rubble, which fades)
const CLOSE_SIZE := 10.0  # m tall, ortho along the game's angle
const FRONT_SIZE := 6.0

var game_view := Vector3.ZERO


func _initialize() -> void:
	await process_frame
	game_view = load("res://scripts/camera_rig.gd").rest_view(OS.get_cmdline_user_args()).offset
	var tag := "shot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.substr(6)
	var dir := "user://piece_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.combo_guide = false
	game._hints_seen = game.HINTS.keys()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.6).timeout
	await _save("%s/%s_room" % [dir, tag])
	var p: Node3D = main.player
	p.set_physics_process(false)
	p.set_process(false)
	var anim: AnimationPlayer = p.anim
	if anim.has_animation("Idle"):
		anim.play("Idle")
		anim.seek(0.3, true)
		anim.pause()
	var cam := Camera3D.new()
	get_root().add_child(cam)
	var rig: Camera3D = get_root().get_viewport().get_camera_3d()
	cam.fov = rig.fov if rig != null else 37.0
	cam.make_current()
	# the hero beside each placed piece, from the game camera (its offset, its fov)
	var EP: GDScript = load("res://scripts/env_piece.gd")
	var beside := {"brazier": Vector3(1.8, 0, 1.2), "pool": Vector3(1.0, 0, 2.6), "hook": Vector3(2.2, 0, 1.0), "ledge": Vector3(-1.4, 0, 2.2)}
	for tag_p: String in beside:
		var ns: Array = get_nodes_in_group("env_" + tag_p)
		if ns.is_empty():
			print("[piece_shots] no ", tag_p, " placed (run with --room=pieces)")
			continue
		var n: Node3D = ns[0]
		var at := Vector3(n.global_position.x, 0.0, n.global_position.z)
		p.global_position = at + n.global_basis * beside[tag_p] if tag_p in ["hook", "ledge"] else at + beside[tag_p]
		p.global_position.y = 0.0
		var centre := (at + p.global_position) * 0.5 + Vector3(0, 0.8, 0)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.global_position = centre + game_view
		cam.look_at(centre)
		await create_timer(0.3).timeout
		await _save("%s/%s_%s" % [dir, tag, tag_p])
	# the lineup: every new model, the hero, and kit pieces to compare with
	var room: Node3D = main
	var row := [
		["barrel", Vector3(-6.4, 0, LINE_Z + 1.5), 0.0, "barrel_small"],
		["brazier", Vector3(-5.0, 0, LINE_Z + 1.5), 0.0, "brazier"],
		["brazier", Vector3(-2.2, 0, LINE_Z + 1.2), 0.0, "brazier_spilled"],
		["crate", Vector3(5.2, 0, LINE_Z + 1.8), 15.0, "box_large"],
		["ledge", Vector3(-1.5, 0, LINE_Z - 1.6), 0.0, "ledge"],
		["pool", Vector3(3.0, 0.012, LINE_Z + 1.6), 0.0, "pool"],
		["wall", Vector3(6.5, 0, LINE_Z - 2.0), 0.0, "wall"],
		["hook", Vector3(6.5, 3.4, LINE_Z - 1.5), 0.0, "hook_chain"],
		["torch", Vector3(4.6, 2.4, LINE_Z - 1.5), 0.0, "torch_mounted"],
	]
	for e: Array in row:
		EP.place(room, e[0], e[1], e[2], "", {"live": false, "model": e[3]})
	p.global_position = Vector3(0.4, 0, LINE_Z + 1.6)
	var line_c := Vector3(0, 0.9, LINE_Z + 0.4)
	cam.global_position = line_c + game_view * 1.25
	cam.look_at(line_c)
	await create_timer(0.3).timeout
	await _save("%s/%s_lineup_game" % [dir, tag])
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CLOSE_SIZE
	cam.global_position = line_c + game_view
	cam.look_at(line_c)
	await create_timer(0.2).timeout
	await _save("%s/%s_lineup_close" % [dir, tag])
	cam.size = FRONT_SIZE
	cam.global_position = line_c + Vector3(0, 1.0, 12.0)
	cam.look_at(line_c + Vector3(0, 0.6, 0))
	await create_timer(0.2).timeout
	await _save("%s/%s_lineup_front" % [dir, tag])
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(path + ".png")
	img.resize(SHOT.x, SHOT.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(path + "_800.png")
	print("saved ", ProjectSettings.globalize_path(path + ".png"))
