extends SceneTree
## The Meshy hero, checked and photographed in the real game:
##   godot --headless --path . -s tests/heretic_shots.gd     PASS/FAIL, no pictures
##   godot --path . -s tests/heretic_shots.gd                also user://heretic_shots/*.png
## Sets the flags for this process only. Windowed, it opens a window for about 30 s.

const DIR := "user://heretic_shots"
const GAME_VIEW := Vector3(0.0, 13.0, 9.5)  # camera_rig.offset
const CLOSE := Vector3(0.0, 1.5, 4.2)
const TURN := -0.55  # rad: towards the camera, his right side (the tentacle) showing
const STRIP_STEP := 0.02  # s of the change between frames
const STRIP_FRAMES := 24
const STRIP_FORMS := [["axe", "Ab_L1", 0.3], ["spear", "Ab_L2", 0.34], ["hammer", "Ab_L3", 0.4], ["hand", "Ab_GR", 0.4]]
## name, clip, fraction of the clip, shape.
const POSES := [
	["idle", "Idle", 0.3, "hand"], ["ready", "Idle_Ready", 0.3, "hand"], ["run", "Run_F", 0.25, "hand"],
	["axe_L1", "Ab_L1", 0.32, "axe"], ["spear_L2", "Ab_L2", 0.34, "spear"], ["hammer_L3", "Ab_L3", 0.4, "hammer"],
	["grab_GR", "Ab_GR", 0.4, "hand"], ["slam_VS", "Ab_VS", 0.5, "hand"],
]

var _game: Node
var _main: Node
var _cam: Camera3D
var _fails := 0
var _headless := false


## The change itself, one exact STRIP_STEP at a time (a timer can't sample it: one slow frame
## swallows the whole change), to user://heretic_shots/strip_*.png.
func _strip(p: Node3D, arm: Node, anim: AnimationPlayer) -> void:
	p.state = p.State.ATTACK
	var skel: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	var hand := skel.find_bone("hand.r")
	for view: String in ["close", "game"]:
		for step: Array in STRIP_FORMS:
			anim.play(step[1])
			anim.seek(anim.get_animation(step[1]).length * step[2], true)
			anim.pause()
			await create_timer(0.1).timeout
			var at := skel.global_transform * skel.get_bone_global_pose(hand).origin
			var off := Vector3(-0.3, 0.9, 3.0) if view == "close" else GAME_VIEW
			_cam.look_at_from_position(at + off, at, Vector3.UP)
			Engine.time_scale = 0.02
			skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
			arm.shape(step[0], false)
			for i in STRIP_FRAMES:
				skel.advance(STRIP_STEP)  # only queues it: the modifiers run on the skeleton's next update
				await skel.skeleton_updated
				for fx: Node in get_nodes_in_group("heretic_form_fx"):
					fx.set_process(false)
					fx.tick(STRIP_STEP)
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png("%s/strip_%s_%s_%d.png" % [DIR, view, step[0], i])
			skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
			Engine.time_scale = 1.0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_game = get_root().get_node("Game")
	_game.save_hints = false
	_game.combo_guide = false  # the shots set his state with no move behind it
	_game._hints_seen = _game.HINTS.keys()
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(0.3).timeout
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	_main.clear_room()
	var p: Node3D = _main.player
	var look: GDScript = load("res://scripts/comic_look.gd")

	_check(look.hero_kind() == "heretic", "the game picked the heretic hero")
	var skel: Skeleton3D = p.model.find_children("*", "Skeleton3D", true, false)[0]
	for b in ["hand.r", "handslot.r", "head", "chest", "tent.main.01", "tent.up.01", "skirt.00.1"]:
		_check(skel.find_bone(b) >= 0, "bone " + b)
	var anim: AnimationPlayer = p.anim
	var missing := []
	for id: String in look.HERO_MOVES:
		if not anim.has_animation(look.HERO_MOVES[id].clip):
			missing.append(id)
	for c in ["Idle", "Idle_Ready", "Run_F", "Run_B", "Strafe_L", "Strafe_R", "Ab_GR", "Ab_VS", "Ab_Swing", "Hit_A", "Death_A"]:
		if not anim.has_animation(c):
			missing.append(c)
	_check(missing.is_empty(), "every clip he needs is there %s" % [missing])
	for f: String in look.HERO_FORMS:
		for part: String in look.HERO_FORMS[f]:
			if part.begins_with("void_"):  # arm effects shaped for the old hero; not on this one
				continue
			_check(p.model.find_child(part, true, false) != null, "form %s has %s" % [f, part])

	# stand him still; this script drives his pose from here
	p.set_physics_process(false)
	p.set_process(false)
	var arm: Node = p._void.arm
	_check(arm.form == "hand", "tentacle is free at rest")
	var tip := skel.find_bone("tent.up.01")
	# modifiers' results only exist between their run and the skeleton's restore: read them in skeleton_updated
	await create_timer(0.35).timeout
	await skel.skeleton_updated
	_check(skel.get_bone_pose_scale(tip).x > 0.9, "tips open at rest (%.2f)" % skel.get_bone_pose_scale(tip).x)
	var r0 := skel.get_bone_pose_rotation(tip)
	await create_timer(0.3).timeout
	await skel.skeleton_updated
	_check(not skel.get_bone_pose_rotation(tip).is_equal_approx(r0), "tips sway when idle")
	arm.shape("spear", false)
	await create_timer(0.2).timeout
	await skel.skeleton_updated
	_check(skel.get_bone_pose_scale(tip).x < 0.15, "tips pull in for a weapon (%.2f)" % skel.get_bone_pose_scale(tip).x)
	_check(p.model.find_child("spear_void_ice", true, false).visible, "the spear shows")
	var rig: Node = skel.find_children("*", "", false, false).filter(func(n: Node) -> bool: return n.has_method("form_weight"))[0]
	_check(rig.form_weight("spear") > 0.99, "the spear finished growing")
	for f: String in rig.FORM_BONES:
		_check(rig.haft_alignment(f) > 0.98, "%s bone runs along its haft (%.3f)" % [f, rig.haft_alignment(f)])
	var main1 := skel.find_bone("tent.main.01")
	_check(skel.get_bone_pose_scale(main1).x > 0.9, "the main tentacle stays to grip the weapon")
	for old: Node in get_nodes_in_group("heretic_form_fx"):  # the spear's, if it's still going
		old.tick(1.0)
	await process_frame
	skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	arm.shape("hammer", false)
	skel.advance(0.01)
	await skel.skeleton_updated
	_check(p.model.find_child("spear_void_ice", true, false).visible, "the old weapon stays while it pulls back")
	_check(rig.form_weight("hammer") == 0.0, "the new one waits for it")
	await process_frame
	var bursts := get_nodes_in_group("heretic_form_fx")
	_check(bursts.size() == 1, "one burst for one change (%d)" % bursts.size())
	if bursts.size() == 1:
		bursts[0].tick(1.0)
		await process_frame
		_check(get_nodes_in_group("heretic_form_fx").is_empty(), "the burst cleans itself up")
	for i in 12:
		skel.advance(0.02)
		await skel.skeleton_updated
	skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	_check(not p.model.find_child("spear_void_ice", true, false).visible, "then it has gone")
	_check(rig.form_weight("hammer") > 0.99, "and the new one has grown")
	arm.shape("hand", false)
	await create_timer(0.35).timeout
	await skel.skeleton_updated
	_check(skel.get_bone_pose_scale(tip).x > 0.9, "tips open again (%.2f)" % skel.get_bone_pose_scale(tip).x)

	# skirt: at rest it holds; yank him sideways and it should lag behind
	var sb := skel.find_bone("skirt.03.3")
	await skel.skeleton_updated
	var a0 := skel.get_bone_global_pose(sb).origin
	var at := p.global_position
	for i in 6:
		p.global_position += Vector3(0.35, 0.0, 0.0)
		await process_frame
	await skel.skeleton_updated
	var a1 := skel.get_bone_global_pose(sb).origin
	_check(a0.distance_to(a1) > 0.01, "skirt springs move (%.3f m)" % a0.distance_to(a1))
	p.global_position = at

	# feet: on the ground, for standing clips
	anim.play("Idle")
	anim.seek(0.3, true)
	await process_frame
	var foot := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("foot.r")).origin
	var rest := skel.get_bone_global_rest(skel.find_bone("foot.r")).origin.y
	_check(absf(foot.y - p.global_position.y - rest) < 0.12, "right foot at its rest height in Idle (off by %.3f m)" % (foot.y - p.global_position.y - rest))

	if not _headless:
		_cam = Camera3D.new()
		_cam.fov = 42.0
		_main.add_child(_cam)
		_cam.current = true
		p.model.rotation.y = TURN
		await _strip(p, arm, anim)
		for pose: Array in POSES:
			arm.shape(pose[3], false)
			p.state = p.State.ATTACK if pose[1].begins_with("Ab_") else p.State.MOVE
			anim.play(pose[1])
			anim.seek(anim.get_animation(pose[1]).length * pose[2], true)
			anim.pause()
			await create_timer(0.3).timeout
			for view: String in ["close", "game"]:
				var off: Vector3 = CLOSE if view == "close" else GAME_VIEW
				var aim := p.global_position + Vector3(0.0, 1.05 if view == "close" else 0.5, 0.0)
				_cam.look_at_from_position(p.global_position + off, aim, Vector3.UP)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png("%s/%s_%s.png" % [DIR, pose[0], view])
	_game.stop_all_sfx()
	print("[heretic] %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	await create_timer(0.1).timeout
	quit(0 if _fails == 0 else 1)
