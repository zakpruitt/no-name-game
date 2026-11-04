extends SceneTree
## Foes next to the hero, for judging proportion and line weight by eye (windowed only):
##   godot --path . -s tests/foe_shots.gd -- --tag=after
## Saves user://foe_shots/<tag>_room.png (the training room as it opens, game camera),
## <tag>_row_game.png (hero, dummy and every foe in two rows, game camera) and
## <tag>_row_close.png (the same, closer, ortho along the game's angle) and <tag>_row_front.png
## (ortho from the front). Headless it saves nothing.

const FRONT := ["hero", "dummy", "minion", "rogue", "shield", "warrior"]
const BACK := ["mage", "archer", "bomber", "necromancer", "warden"]
const STEP := 2.0  # m between models in a row
const FRONT_Z := 3.0  # m in front of the hero's spot (towards the camera)
const BACK_Z := 0.0
const GAME_VIEW := Vector3(0.0, 13.0, 9.5)  # camera_rig.offset: the game's angle
const CLOSE_SIZE := 9.0  # m tall, ortho, along the game's angle
const FRONT_SIZE := 7.5  # m tall, ortho, from the front at chest height


func _initialize() -> void:
	await process_frame
	var tag := "shot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			tag = arg.substr(6)
	var dir := "user://foe_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.combo_guide = false
	game._hints_seen = game.HINTS.keys()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.6).timeout
	_save("%s/%s_room.png" % [dir, tag])

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
		nodes[kind] = main._spawn_boss() if kind == "warden" else main._spawn(kind, false, placed[kind])
		nodes[kind].global_position = placed[kind]
		nodes[kind].set_physics_process(false)  # no chase, no windup rings
	await create_timer(1.4).timeout
	for kind: String in nodes:
		var n: Node3D = nodes[kind]
		n.set_physics_process(false)
		n.global_position = placed[kind]
		n.model.rotation = Vector3.ZERO  # facing +Z, the camera
		var anim: AnimationPlayer = n.anim
		var idle := "Idle" if kind == "hero" else "Idle_Combat"
		if kind != "hero" and n.get("comic_kind") != "":
			idle = load("res://scripts/comic_look.gd").clip(anim, n.comic_kind, idle)
		if anim.has_animation(idle):
			anim.play(idle)
			anim.seek(0.3, true)
			anim.pause()
	await create_timer(0.3).timeout
	_save("%s/%s_row_game.png" % [dir, tag])
	var cam := Camera3D.new()
	get_root().add_child(cam)
	var centre := at + Vector3(0.0, 1.0, FRONT_Z * 0.5)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CLOSE_SIZE
	cam.global_position = centre + GAME_VIEW
	cam.look_at(centre)
	cam.make_current()
	await create_timer(0.3).timeout
	_save("%s/%s_row_close.png" % [dir, tag])
	cam.size = FRONT_SIZE
	cam.global_position = centre + Vector3(0.0, 1.2, 9.0)
	cam.look_at(centre + Vector3(0.0, 0.2, 0.0))
	await create_timer(0.2).timeout
	_save("%s/%s_row_front.png" % [dir, tag])
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
