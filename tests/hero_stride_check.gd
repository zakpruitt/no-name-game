extends SceneTree
## The hero's feet against the floor on his four run clips (headless, PASS/FAIL):
##   godot --headless --path . -s tests/hero_stride_check.gd [-- --trace]
## The same measure as foe_stride_check: sample both foot bones over each clip at 1x; while a foot
## is planted (in the lower half of its height range and moving against the way he travels, faster
## than MOVING) take its mean speed along that way. player.gd plays every loop at LOOP_SPEED, so at move_speed the
## ground passes under him at move_speed and the feet at foot * LOOP_SPEED. FAIL if the two are
## more than SKATE_TOL apart, or if a clip's length differs from Run_F's (the four share one cycle:
## a change of direction seeks the new clip to the same time). Awakened he moves SPEED_MULT faster and
## player.gd plays the runs AWAKENED_RUN_CLIP faster: FAIL if those two disagree past SKATE_TOL too.
## Also prints how long a foot stays planted.

const RATE := 120.0  # samples per second of clip
const CONTACT := 0.5  # of the foot's height range, from the bottom
const SKATE_TOL := 0.15
## m/s: slower than this a foot isn't sliding back at all (the run's last swing frame drops the foot
## straight down onto its mark: low, but not planted yet).
const MOVING := 0.1
## Clip -> the way he travels in model space (he faces +Z; Strafe_L goes to his left, +X).
const WAYS := {"Run_F": Vector3(0, 0, 1), "Run_B": Vector3(0, 0, -1), "Strafe_L": Vector3(1, 0, 0),
	"Strafe_R": Vector3(-1, 0, 0)}


func _initialize() -> void:
	await process_frame
	var player_script: GDScript = load("res://scripts/player.gd")
	var move: float = player_script.get_property_default_value("move_speed")
	var mult: float = load("res://scripts/hero_awaken.gd").SPEED_MULT
	var consts := player_script.get_script_constant_map()
	var loop_speed: float = consts.get("LOOP_SPEED", 1.1)
	var awake_clip: float = consts.get("AWAKENED_RUN_CLIP", 1.0)  # before round 35 b: none, the feet skated 1.2x
	var model: Node3D = load("res://assets/comic/heretic_chibi.glb").instantiate()
	get_root().add_child(model)
	var anim: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var fails := 0
	var cycle := anim.get_animation("Run_F").length
	for clip: String in WAYS:
		var r := _foot_speed(anim, skel, clip, WAYS[clip])
		var speed: float = r[0]
		var skate := move / maxf(speed * loop_speed, 0.01)
		var awake := skate * mult / awake_clip
		var same := absf(anim.get_animation(clip).length - cycle) < 0.001
		var ok := absf(skate - 1.0) <= SKATE_TOL and absf(awake - 1.0) <= SKATE_TOL and same
		if not ok:
			fails += 1
		print("[hero_stride] %-9s %.3f s  foot %.2f m/s at 1x -> %.2f at x%.1f, move %.1f m/s: ground/feet %.2f (Awakened x%.1f, clip x%.1f: %.2f), planted %.0f%% of the cycle %s" % [
			clip, anim.get_animation(clip).length, speed, speed * loop_speed, loop_speed, move, skate, mult, awake_clip, awake,
			r[1] * 100.0, "ok" if ok else "FAIL"])
	print("[hero_stride] %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	model.queue_free()
	quit(1 if fails else 0)


## [mean speed (m/s, clip at 1x) of both feet against `way` while planted, planted share of the samples].
func _foot_speed(anim: AnimationPlayer, skel: Skeleton3D, clip: String, way: Vector3) -> Array:
	anim.play(clip)
	var length := anim.get_animation(clip).length
	var n := int(length * RATE)
	var total := 0.0
	var count := 0
	var trace := OS.get_cmdline_user_args().has("--trace")
	for foot in ["foot.l", "foot.r"]:
		var bone := skel.find_bone(foot)
		var pos: Array[Vector3] = []
		for i in n + 1:
			anim.seek(length * i / n, true)
			skel.force_update_all_bone_transforms()
			pos.append(skel.global_transform * skel.get_bone_global_pose(bone).origin)
		var ymin := INF
		var ymax := -INF
		for p in pos:
			ymin = minf(ymin, p.y)
			ymax = maxf(ymax, p.y)
		var cut := ymin + (ymax - ymin) * CONTACT
		if trace:
			var zs := []
			for p in pos.slice(0, pos.size(), 4):
				zs.append("%.2f/%.2f" % [p.dot(way), p.y])
			print("[hero_stride] trace %s %s %s" % [clip, foot, " ".join(zs)])
		for i in n:
			var back := -(pos[i + 1] - pos[i]).dot(way) * RATE
			if back > MOVING and pos[i].y <= cut and pos[i + 1].y <= cut:
				total += back
				count += 1
	return [total / maxf(count, 1), count / (2.0 * n)]
