extends SceneTree
## The Meshy hero, checked and photographed in the real game:
##   godot --headless --path . -s tests/heretic_shots.gd     PASS/FAIL, no pictures
##   godot --path . -s tests/heretic_shots.gd                also user://heretic_shots/*.png
## Sets the flags for this process only. Windowed, it opens a window for about 30 s.
## Checks the default model (the chibi, pictures in user://heretic_shots_chibi/); -- --hero=heretic
## checks the round-28 heretic instead, its pictures in user://heretic_shots/.

var DIR := "user://heretic_shots"
const CLOSE := Vector3(0.0, 1.5, 4.2)
const TURN := -0.55  # rad: towards the camera, his right side (the tentacle) showing
const STRIP_STEP := 0.02  # s of the change between frames
const STRIP_FRAMES := 24
const STRIP_FORMS := [["axe", "Ab_L1", 0.3], ["spear", "Ab_L2", 0.34], ["hammer", "Ab_L3", 0.4], ["hand", "Ab_GR", 0.4]]
## name, clip, fraction of the clip, shape.
const POSES := [
	["idle", "Idle", 0.3, "hand"], ["ready", "Idle_Ready", 0.3, "hand"], ["run", "Run_F", 0.25, "hand"],
	["axe_L1", "Ab_L1", 0.32, "axe"], ["spear_L2", "Ab_L2", 0.34, "spear"], ["hammer_L3", "Ab_L3", 0.4, "hammer"],
	["reach_GR", "Ab_GR", 0.18, "hand"], ["grab_GR", "Ab_GR", 0.4, "hand"],
	["lift_VS", "Ab_VS", 0.3, "hand"], ["slam_VS", "Ab_VS", 0.5, "hand"],
]
## Clip -> the move whose claw grip (heretic_rig.GRIP_MOVES) the pose shows.
const POSE_MOVES := {"Ab_GR": "GR", "Ab_VS": "VS"}
## Pass 3 (round 40): the face must read from the game camera. Headless, the facing (rig.face_dot); windowed,
## the Idle game shot's pixels: at least FACE_PX of the dark face colour round FaceShade and EYE_PX of
## cyan glow round each eye.
const FACE_DOT_MIN := 0.7
const FACE_PX := 250
const EYE_PX := 25

var _game: Node
var _main: Node
var _cam: Camera3D
var _fails := 0
var _headless := false
var game_view := Vector3.ZERO  # camera_rig.rest_view(): the game camera's offset now (round 28's was (0, 13, 9.5))
var game_fov := 0.0


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
			var off := Vector3(-0.3, 0.9, 3.0) if view == "close" else game_view
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


## -- --clips [--clips-tag=before]: every clip the game plays on him, filmed as the game shows
## it (12 drawings a second at its play speed) from the game camera, cropped round him, to
## user://heretic_shots_<model>/clips_<tag>/<clip>_<i>.png, with INDEX.txt (clip time, hit).
## He faces screen right, so the claw (his right hand) is towards the camera.
func _clips(p: Node3D, arm: Node, anim: AnimationPlayer) -> void:
	var tag := "now"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--clips-tag="):
			tag = a.get_slice("=", 1)
	var only := ""
	var near := 1.0  # --clips-near=0.4: the game camera's angle from closer, to check a pose
	var clip_step := 0.0
	var max_shots := 16
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--clips-max="):  # shots per clip (16: a whole attack at 12 a second)
			max_shots = int(a.get_slice("=", 1))
		if a.begins_with("--clips-only="):
			only = a.get_slice("=", 1)
		if a.begins_with("--clips-near="):
			near = float(a.get_slice("=", 1))
		if a.begins_with("--clips-step="):  # s of clip time between shots (1/30: every frame of a run)
			clip_step = float(a.get_slice("=", 1))
	var out := "%s/clips_%s" % [DIR, tag]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var index := FileAccess.open(out + "/INDEX.txt", FileAccess.WRITE)
	p.model.rotation.y = PI * 0.5
	var real_step := 1.0 / 12.0
	for c: Array in CLIP_SET:
		var clip: String = c[0]
		if only != "" and clip not in only.split(","):
			continue
		var id: String = c[1]
		var speed: float = p.anim_speed if id != "" else 1.1
		var length := anim.get_animation(clip).length
		var end := length
		var hit := -1.0
		if id != "":
			var m: Dictionary = p.HERO_MOVES.effective_move(p.anim, id)
			end = minf(length, m.end * length + 0.15)
			hit = m.hits[0] * length
		arm.shape(c[2], false)
		p.state = p.State.ATTACK if id != "" else p.State.MOVE
		p._move_id = id
		anim.play(clip)
		anim.seek(0.0, true)
		anim.pause()
		await create_timer(0.35).timeout
		var times: Array[float] = []
		var t := 0.0
		while t <= end + 0.001 and times.size() < max_shots:
			times.append(t)
			t += clip_step if clip_step > 0.0 else real_step * speed
		if hit >= 0.0 and not times.has(hit):
			times.append(hit)
			times.sort()
		for i in times.size():
			anim.seek(times[i], true)
			await create_timer(0.12).timeout
			var at := p.global_position + Vector3(0.0, 0.5, 0.0)
			_cam.look_at_from_position(at + game_view * near, at, Vector3.UP)
			await process_frame
			await RenderingServer.frame_post_draw
			var img := get_root().get_texture().get_image()
			var s := int(img.get_height() * (0.36 if near >= 1.0 else minf(0.15 / near, 0.95)))
			var mid := _cam.unproject_position(p.global_position + Vector3(0.0, 0.8, 0.0))
			var box := Rect2i(int(mid.x) - s / 2, int(mid.y) - s / 2, s, s)
			img.get_region(box).save_png("%s/%s_%02d.png" % [out, clip, i])
			index.store_line("%s %02d t=%.3f hit=%s" % [clip, i, times[i], "1" if absf(times[i] - hit) < 0.001 else "0"])
	index.close()
	p._move_id = ""
	p.state = p.State.MOVE


## How far the claw tips sit from their middle, in the hand's own space (so a swollen hand doesn't
## count): wider when splayed, closer when clenched. `clip` null measures the rest pose.
func _claw_spread(skel: Skeleton3D, clip: Animation, t: float) -> float:
	var frames: GDScript = load("res://tests/contact_frames.gd")
	var pose := func(b: int) -> Transform3D:
		return skel.get_bone_global_rest(b) if clip == null else frames.track_pose(skel, clip, b, t)
	var inv: Transform3D = pose.call(skel.find_bone("hand.r")).affine_inverse()
	var tips: Array[Vector3] = []
	for tip: String in ["main", "up", "out", "mid", "low", "back"]:
		var last := -1
		for i in 12:
			var b := skel.find_bone("tent.%s.%02d" % [tip, i + 1])
			if b < 0:
				break
			last = b
		if last >= 0:
			tips.append(inv * (pose.call(last) as Transform3D).origin)
	var mid := Vector3.ZERO
	for v in tips:
		mid += v / tips.size()
	var sum := 0.0
	for v in tips:
		sum += v.distance_to(mid) / tips.size()
	return sum


## clip, the move it plays for ("" = a stance, played at 1.1), the shape out.
const CLIP_SET := [
	["Ab_L1", "L1", "axe"], ["Ab_L2", "L2", "spear"], ["Ab_L3", "L3", "hammer"], ["Ab_DL", "DL", "spear"],
	["Ab_AL1", "AL1", "axe"], ["Ab_GR", "GR", "hand"], ["Ab_VS", "VS", "hand"], ["Ab_LH", "EC", "hand"],
	["Ab_H", "VR", "hand"], ["Ab_LLH", "EF", "spear"], ["Ab_AF", "EM", "hand"],
	["Idle", "", "hand"], ["Idle_Ready", "", "hand"], ["Run_F", "", "hand"], ["Strafe_L", "", "hand"],
	["Hit_A", "", "hand"], ["Dodge_Forward", "", "hand"], ["Run_B", "", "hand"], ["Strafe_R", "", "hand"],
	["Jump_Start", "", "hand"], ["Jump_Idle", "", "hand"], ["Run_Start", "", "hand"], ["Run_Stop", "", "hand"],
	["Run_Start_B", "", "hand"], ["Run_Start_L", "", "hand"], ["Run_Start_R", "", "hand"], ["Run_Stop_B", "", "hand"],
	["Run_Stop_L", "", "hand"], ["Run_Stop_R", "", "hand"], ["Run_Stop_Ready", "", "hand"], ["Run_Stop_L_Ready", "", "hand"],
	["Death_A", "", "hand"], ["Ab_Swing", "", "hand"],  # (round 35 c keys; --clips-only=Death_A,Ab_Swing found nothing before)
]


## The Idle game shot: count the face shade's colour within its oval's reach of FaceShade and the eyes'
## glow within an eye's reach of each eye, on screen.
func _face_pixels(img: Image, rig: Node) -> void:
	var shade: Node3D = rig.grin.get_child(1)
	var px_per_m := img.get_height() / (2.0 * _cam.global_position.distance_to(shade.global_position) * tan(deg_to_rad(_cam.fov) * 0.5))
	var want: Color = rig.FACE_SHADE_COLOR
	var face := _count(img, _cam.unproject_position(shade.global_position), rig.FACE_SHADE_SIZE.x * rig._face_k * px_per_m,
		func(c: Color) -> bool: return absi(c.r8 - roundi(want.r * 255)) <= 2 and absi(c.g8 - roundi(want.g * 255)) <= 2 and absi(c.b8 - roundi(want.b * 255)) <= 2)
	_check(face >= FACE_PX, "the dark face reads from the game camera in Idle (%d px)" % face)
	for i in 2:
		var eye: Node3D = rig.eyes.get_child(i)
		var n := _count(img, _cam.unproject_position(eye.global_position), rig.EYE_SIZE.x * rig._face_k * px_per_m,
			func(c: Color) -> bool: return c.g > 0.7 and c.b > 0.7 and c.g - c.r > 0.12)
		_check(n >= EYE_PX, "eye %d glows from the game camera in Idle (%d px)" % [i, n])


static func _count(img: Image, at: Vector2, r: float, hit: Callable) -> int:
	var n := 0
	for y in range(maxi(int(at.y - r), 0), mini(int(at.y + r) + 1, img.get_height())):
		for x in range(maxi(int(at.x - r), 0), mini(int(at.x + r) + 1, img.get_width())):
			if Vector2(x, y).distance_to(at) <= r and hit.call(img.get_pixel(x, y)):
				n += 1
	return n


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	_headless = DisplayServer.get_name() == "headless"
	await process_frame
	var cam_rest: Dictionary = load("res://scripts/camera_rig.gd").rest_view(OS.get_cmdline_user_args())
	game_view = cam_rest.offset
	game_fov = cam_rest.fov
	_game = get_root().get_node("Game")
	if _game.hero_model != "heretic":
		DIR += "_" + _game.hero_model
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
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
	var file: String = look.HERETIC_MODELS[_game.hero_model]
	_check(look.scene(look.HERETIC).resource_path.ends_with("/%s.glb" % file), "the %s model loaded (%s)" % [_game.hero_model, file])
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
	var rig: Node = skel.find_children("*", "", false, false).filter(func(n: Node) -> bool: return n.has_method("form_weight"))[0]
	# keyed claws (the chibi) stay out round the haft, clenched by the clip; the others pull right in
	var pulled: float = rig.KEYED_COLLAPSED + 0.01 if rig.keyed else 0.15
	_check(skel.get_bone_pose_scale(tip).x < pulled, "tips pull in for a weapon (%.2f)" % skel.get_bone_pose_scale(tip).x)
	_check(p.model.find_child("spear_void_ice", true, false).visible, "the spear shows")
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

	# the claw grips on the grab and lets go on the slam (visual only): procedural on the heretic
	# (heretic_rig.GRIP_MOVES), keyed in the chibi's clips (claws spread wider or closer than at rest)
	p.state = p.State.ATTACK
	if rig.keyed:  # read off the clip's own tracks (tests/contact_frames.gd's track_pose), as the game plays them
		var rest_spread := _claw_spread(skel, null, 0.0)
		for g: Array in [["Ab_GR", 0.15, 1, "splays reaching out on GR"], ["Ab_GR", 0.4, -1, "clenches on GR's catch"],
				["Ab_VS", 0.3, -1, "holds clenched lifting on VS"], ["Ab_VS", 0.5, 1, "flings open on VS's slam"]]:
			var clip := anim.get_animation(g[0])
			var sp := _claw_spread(skel, clip, clip.length * g[1])
			var ok: bool = sp > rest_spread * 1.04 if g[2] > 0 else sp < rest_spread * 0.85
			_check(ok, "claw %s (spread %.3f m, rest %.3f m)" % [g[3], sp, rest_spread])
	for g: Array in [] if rig.keyed else [["GR", "Ab_GR", 0.15, -0.3, "splays reaching out on GR"], ["GR", "Ab_GR", 0.4, 0.5, "clenches on GR's catch"],
			["VS", "Ab_VS", 0.3, 0.5, "holds clenched lifting on VS"], ["VS", "Ab_VS", 0.5, -0.5, "flings open on VS's slam"]]:
		p._move_id = g[0]
		anim.play(g[1])
		anim.seek(anim.get_animation(g[1]).length * g[2], true)
		anim.pause()
		await create_timer(0.25).timeout
		await skel.skeleton_updated
		var gr: Vector2 = rig.grip()
		var ok: bool = gr.x < g[3] if g[3] < 0.0 else gr.x > g[3]
		_check(ok and gr.y > 0.9, "claw %s (%.2f, on %.2f)" % [g[4], gr.x, gr.y])
	p._move_id = ""
	p.state = p.State.MOVE
	await create_timer(0.3).timeout
	await skel.skeleton_updated
	_check(rig.grip().y < 0.05, "and lets the claw go after (%.2f)" % rig.grip().y)
	_check(not rig.keyed or anim.get_animation("Idle").find_track(NodePath("%s:tent.up.01" % p.model.get_path_to(skel)), Animation.TYPE_ROTATION_3D) >= 0,
		"the keyed model's Idle keys the claws")
	if _game.hero_model == "chibi":
		_check(rig.eyes != null and rig.eyes.get_child_count() == 2, "the chibi has glowing eyes")
		var cam := game_view
		var eye := Vector3(0.0, 1.25, 0.13)
		_check(rig._covered(cam, eye, PackedVector3Array([eye.lerp(cam, 0.05)]), 0.07), "an eye goes behind the claw in front of it")
		_check(not rig._covered(cam, eye, PackedVector3Array([eye.lerp(cam, 0.05) + Vector3(0.4, 0.0, 0.0)]), 0.07)
			and not rig._covered(cam, eye, PackedVector3Array([eye + Vector3(0.0, -0.3, -0.3)]), 0.07),
			"but not behind a claw beside it or behind him")
		_check(rig.grin != null and rig.grin.get_child_count() == 2 and rig.grin.get_child(1).name == "FaceShade", "the chibi grins under them, on a dark face oval")
		# pass 3: the face is tipped up to the game camera, so in Idle facing it the face points within
		# FACE_DOT_MIN of the camera (cos 0.7 = 46 degrees; untipped it was 0.47, 62 degrees)
		var yaw: float = p.model.rotation.y
		p.model.rotation.y = 0.0  # facing the camera
		anim.play("Idle")
		anim.seek(0.3, true)
		anim.pause()
		await create_timer(0.1).timeout
		await skel.skeleton_updated
		var fd: float = rig.face_dot(skel, p.global_position + game_view)
		_check(fd > FACE_DOT_MIN, "his face points up at the game camera in Idle (cos %.2f)" % fd)
		p.model.rotation.y = yaw
		p.state = p.State.HURT
		await create_timer(0.25).timeout
		await skel.skeleton_updated
		var hurt_squint: float = rig.squint
		p.state = p.State.MOVE
		rig._blink_t = 0.0
		await create_timer(0.3).timeout
		await skel.skeleton_updated
		_check(hurt_squint > 0.8 and rig.squint < 0.2, "eyes squeeze shut when hit, open after (%.2f, %.2f)" % [hurt_squint, rig.squint])
		# the scarf tail (round 40, hero pass 2): its own chain on its own spring, waving while he stands
		var tail := skel.find_bone("scarf.04")
		_check(rig._scarf.size() == 4 and skel.get_node_or_null("ScarfSprings") != null, "the chibi has a scarf tail on its own spring")
		if tail >= 0:
			await skel.skeleton_updated
			var t0 := skel.get_bone_global_pose(tail).origin
			await create_timer(0.3).timeout
			await skel.skeleton_updated
			var t1 := skel.get_bone_global_pose(tail).origin
			_check(t0.distance_to(t1) > 0.005 and t1.z < -0.2, "and it flutters behind him (moved %.3f m, z %.2f)" % [t0.distance_to(t1), t1.z])

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

	if not _headless and "--clips" in OS.get_cmdline_user_args():
		_cam = Camera3D.new()
		_cam.fov = game_fov
		_main.add_child(_cam)
		_cam.current = true
		await _clips(p, arm, anim)
	elif not _headless:
		_cam = Camera3D.new()
		_cam.fov = game_fov
		_main.add_child(_cam)
		_cam.current = true
		p.model.rotation.y = TURN
		await _strip(p, arm, anim)
		for pose: Array in POSES:
			arm.shape(pose[3], false)
			p.state = p.State.ATTACK if pose[1].begins_with("Ab_") else p.State.MOVE
			p._move_id = POSE_MOVES.get(pose[1], "")
			anim.play(pose[1])
			anim.seek(anim.get_animation(pose[1]).length * pose[2], true)
			anim.pause()
			rig._blink_t = -100.0  # no blink in the shot
			await create_timer(0.3).timeout
			for view: String in ["close", "game"]:
				var off: Vector3 = CLOSE if view == "close" else game_view
				var aim := p.global_position + Vector3(0.0, 1.05 if view == "close" else 0.5, 0.0)
				_cam.look_at_from_position(p.global_position + off, aim, Vector3.UP)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var shot := get_root().get_texture().get_image()
				shot.save_png("%s/%s_%s.png" % [DIR, pose[0], view])
				if pose[0] == "idle" and view == "game" and rig.eyes != null:
					_face_pixels(shot, rig)
	_game.stop_all_sfx()
	print("[heretic] %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	await create_timer(0.1).timeout
	quit(0 if _fails == 0 else 1)
