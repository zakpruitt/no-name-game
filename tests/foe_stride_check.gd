extends SceneTree
## Feet against the floor on each comic foe's run clip (headless, PASS/FAIL):
##   godot --headless --path . -s tests/foe_stride_check.gd
## Plays each kind's run clip (enemy_types `run_anim`, after ComicLook's clip mapping) and samples
## both foot bones. While a foot is planted (moving back, in the lower half of its height range; the
## minion's shamble swings its feet low both ways, so the backward half is the one that counts) it
## slides back at the clip's ground speed; that speed (before model_scale) is `run_foot_speed`.
## enemy.gd plays the run at ground speed / (that * model_scale) (`run_clip_speed()`), clamped to RUN_CLIP_SPEED_MIN/MAX, so the feet
## keep up with move_speed. FAIL if a kind's measured foot speed is more than 8% off its
## `run_foot_speed` (a model changed: copy the new number), or if at move_speed the clamped clip
## speed leaves the feet more than 15% off the ground. In `tools/agent.sh check`.

const TYPES: Dictionary = preload("res://scripts/enemy_types.gd").TYPES
const RATE := 120.0  # samples per second of clip
const CONTACT := 0.5  # of the foot's height range, from the bottom
const STORED_TOL := 0.08
const SKATE_TOL := 0.15


func _initialize() -> void:
	await process_frame
	var enemy_script: GDScript = load("res://scripts/enemy.gd")
	var lo: float = enemy_script.RUN_CLIP_SPEED_MIN
	var hi: float = enemy_script.RUN_CLIP_SPEED_MAX
	var fails := 0
	for kind: String in TYPES:
		var spec: Dictionary = TYPES[kind]
		var scene: PackedScene = load("res://scripts/comic_look.gd").scene(kind)
		if scene == null:
			continue
		var model: Node3D = scene.instantiate()
		get_root().add_child(model)
		var anim: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var run: String = load("res://scripts/comic_look.gd").clip(anim, kind, spec.get("run_anim", "Running_A"))
		var scale: float = spec.get("model_scale", 1.0)
		var speed := _foot_speed(anim, skel, run)
		var move: float = spec.get("move_speed", 3.6)
		var stored: float = spec.get("run_foot_speed", 0.0)
		var clip_speed := clampf(move / maxf(stored * scale, 0.01), lo, hi)
		var skate := move / maxf(speed * scale * clip_speed, 0.01)
		var ok := stored > 0.0 and absf(speed / stored - 1.0) <= STORED_TOL and absf(skate - 1.0) <= SKATE_TOL
		if speed < 0.05 and stored == 0.0:
			ok = true  # no feet to plant (the necromancer's robe): the run stays at 1x
			clip_speed = 1.0
			skate = 0.0
		if not ok:
			fails += 1
		print("[stride] %-12s %-20s foot %.2f m/s at 1x (stored %.2f) x scale, move %.1f m/s -> clip x%.2f, ground/feet %.2f %s" % [
			kind, run, speed, stored, move, clip_speed, skate, "ok" if ok else "FAIL"])
		model.queue_free()
	print("[stride] %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails else 0)


## Mean backward speed (m/s in model space, clip at 1x) of both feet while planted.
func _foot_speed(anim: AnimationPlayer, skel: Skeleton3D, run: String) -> float:
	anim.play(run)
	var length := anim.get_animation(run).length
	var n := int(length * RATE)
	var total := 0.0
	var count := 0
	for foot in ["foot.l", "foot.r"]:
		var bone := skel.find_bone(foot)
		if bone < 0:
			continue
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
		if OS.get_cmdline_user_args().has("--trace"):
			var zs := []
			for p in pos.slice(0, pos.size(), 6):
				zs.append("%.2f/%.2f" % [p.z, p.y])
			print("[stride] trace %s %s %s" % [run, foot, " ".join(zs)])
		for i in n:
			var back := -(pos[i + 1].z - pos[i].z) * RATE  # forward is +Z: a planted foot slides to -Z
			if back > 0.0 and pos[i].y <= cut and pos[i + 1].y <= cut:
				total += back
				count += 1
	return total / maxf(count, 1)
