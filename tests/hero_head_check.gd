extends SceneTree
## The hero's head rides his torso (hero fix 2026-11-07, docs/hero-audit-2026-11-07.md). Headless, about 5 s:
##   godot --headless --path . -s tests/hero_head_check.gd [-- --clips=Run_F,Idle] [--frames] [--raw]
## Plays each clip through the AnimationPlayer at 30 fps (MODEL_SCALE applied), then runs heretic_rig.steady()
## as the game does (State.MOVE for stances and runs, ATTACK for Ab_ clips; --raw skips it: the clip as keyed,
## with the old HOOD_SQUASH_K 0.45 only). Per clip, in cm:
##   hips  : the hips' height range
##   crown : the hood's crown (0.55 m over the head joint) height range
##   scr   : the crown's travel on screen against his feet, game camera (53 deg down), facing it / side-on
##   rel   : the crown's travel in the chest's frame (how far the head moves ON the torso), x y z
##   sq    : the head bone's y scale range; nod: head pitch against the chest range (deg)
##   tilt  : the head's tilt off upright (deg, min..max)
## PASS when every looping run keeps the crown's screen travel under SCREEN_MAX_CM (Idle: IDLE_SCREEN_MAX_CM) and
## every locomotion clip keeps the head's tilt within TILT_MAX_DEG of its range.

const LOCO := ["Idle", "Idle_Ready", "Run_F", "Run_B", "Strafe_L", "Strafe_R", "Run_Start", "Run_Stop"]
const ATTACKS := ["Ab_L1", "Ab_L2", "Ab_L3", "Ab_DL", "Ab_GR", "Ab_VS", "Ab_LH", "Ab_H", "Ab_LLH", "Ab_AF"]
const OTHER := ["Dodge_Forward", "Jump_Start", "Hit_A"]
const SLAM_CLIPS := {"Ab_L3": "L3", "Ab_VS": "VS", "Ab_LLH": "EF"}
const SCREEN_MAX_CM := 24.0  # Run_F keyed: 46. What is left is the deliberate sway over the planted foot
const IDLE_SCREEN_MAX_CM := 10.0
const TILT_MAX_DEG := 15.0  # the head's tilt off upright, range over the clip
const VIEW_UP := Vector3(0.0, 0.6, -0.8)  # camera_rig.VIEW_DIR (0, 0.8, 0.6) turned up a quarter: screen up

var _fails := 0


func _initialize() -> void:
	var rig: GDScript = load("res://scripts/heretic_rig.gd")
	var only := ""
	var per_frame := false
	var raw := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--clips="):
			only = a.trim_prefix("--clips=")
		if a == "--frames":
			per_frame = true
		if a == "--raw":
			raw = true
	var model: Node3D = (load("res://assets/comic/heretic_chibi.glb") as PackedScene).instantiate()
	get_root().add_child(model)
	await process_frame
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var n: Node = skel
	while n.get_parent() != model:
		n = n.get_parent()
	(n as Node3D).scale *= rig.MODEL_SCALE.get("chibi", 1.0)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bones := PackedInt32Array()
	for b: String in ["head", "neck", "root", "hips", "spine"]:
		bones.append(skel.find_bone(b))
	var head := bones[0]
	var chest := skel.find_bone("chest")
	var head_rest := skel.get_bone_global_rest(head)
	var chest_rest := skel.get_bone_global_rest(chest)
	var crown_rest := head_rest.origin + Vector3(0, 0.55, 0)
	var spine_pos := skel.get_bone_pose_position(bones[4])
	var spine_rot := skel.get_bone_pose_rotation(bones[4])  # no clip keys it: the game's skeleton restores it
	var names: Array = LOCO + ATTACKS + OTHER
	if only != "":
		names = Array(only.split(","))
	print("[head] %s  head joint y=%.3f  crown y=%.3f (skeleton rest)" % ["RAW (clip as keyed, hood x0.45)" if raw else "steadied (heretic_rig.steady)", head_rest.origin.y, crown_rest.y])
	for clip: String in names:
		if not ap.has_animation(clip):
			continue
		var a := ap.get_animation(clip)
		var spine_keyed := a.find_track(NodePath("%s:spine" % ap.get_node(ap.root_node).get_path_to(skel)), Animation.TYPE_ROTATION_3D) >= 0
		ap.play(clip)
		var moving: bool = clip in LOCO
		var attacking: bool = clip.begins_with("Ab_")
		var turn_k: float = rig.HEAD_TURN_ATTACK_K if attacking else rig.HEAD_TURN_K
		var level_k: float = rig.HEAD_LEVEL_ATTACK_K if attacking else rig.HEAD_LEVEL_K
		var squash_k: float = rig.SLAM_SQUASH_K if clip in SLAM_CLIPS else rig.HOOD_SQUASH_K
		var body_k: float = rig.RUN_SQUASH_K if moving else 1.0
		var run := 1.0 if moving else 0.0
		var frames := int(a.length * 30.0 + 0.5)
		var mean := {}
		var st := {"hips": [], "crown": [], "u1": [], "u2": [], "x2": [], "rx": [], "ry": [], "rz": [], "sq": [], "nod": [], "tilt": []}
		var loops := 2 if a.loop_mode != Animation.LOOP_NONE else 1
		for loop in loops:
			for f in frames + 1:
				ap.seek(f / 30.0, true)
				skel.set_bone_pose_position(bones[4], spine_pos)
				if not spine_keyed:
					skel.set_bone_pose_rotation(bones[4], spine_rot)
				if raw:
					skel.set_bone_pose_scale(head, Vector3.ONE.lerp(skel.get_bone_pose_scale(head), 0.45))
				else:
					rig.steady(skel, bones, turn_k, level_k, squash_k, body_k, run, mean, 1.0 / 30.0)
				skel.force_update_all_bone_transforms()
				if loop < loops - 1:
					continue
				var g := skel.global_transform
				var hp := skel.get_bone_global_pose(head)
				var cp := skel.get_bone_global_pose(chest)
				var crown_s := hp * (head_rest.affine_inverse() * crown_rest)
				var c := g * crown_s - model.global_position
				var rel := (cp * chest_rest.affine_inverse()).affine_inverse() * crown_s - crown_rest
				rel *= g.basis.get_scale().y
				var rb := (cp.basis.orthonormalized() * chest_rest.basis.orthonormalized().inverse()).inverse() \
					* hp.basis.orthonormalized() * head_rest.basis.orthonormalized().inverse()
				var vals := {"hips": (g * skel.get_bone_global_pose(bones[3]).origin).y, "crown": c.y,
					"u1": c.dot(VIEW_UP), "u2": 0.6 * c.y - 0.8 * c.x, "x2": c.z, "rx": rel.x, "ry": rel.y, "rz": rel.z,
					"sq": skel.get_bone_pose_scale(head).y, "nod": rad_to_deg(rb.get_euler().x),
					"tilt": rad_to_deg((hp.basis.orthonormalized() * head_rest.basis.orthonormalized().inverse() * Vector3.UP).angle_to(Vector3.UP))}
				for k: String in vals:
					st[k].append(vals[k])
				if per_frame:
					print("  %s f%02d hips %.1f crown %.1f scr %.1f fwd %.1f rel(%.1f,%.1f,%.1f) sq %.2f nod %.1f" % [clip, f,
						vals.hips * 100, vals.crown * 100, vals.u1 * 100, c.z * 100, rel.x * 100, rel.y * 100, rel.z * 100, vals.sq, vals.nod])
		var r := func(k: String) -> float: return (st[k].max() - st[k].min()) * (1.0 if k in ["sq", "nod", "tilt"] else 100.0)
		var side := 0.0
		for i in st.x2.size():
			for j in st.x2.size():
				side = maxf(side, Vector2(st.x2[i] - st.x2[j], st.u2[i] - st.u2[j]).length() * 100.0)
		var scr := maxf(r.call("u1"), side)
		var rel_max := maxf(r.call("rx"), maxf(r.call("ry"), r.call("rz")))
		print("[head] %-14s f=%3d hips %5.1f  crown %5.1f  scr %5.1f/%5.1f  rel x%5.1f y%5.1f z%5.1f  sq %.2f..%.2f  nod %5.1f  tilt %4.1f..%4.1f" % [
			clip, frames, r.call("hips"), r.call("crown"), r.call("u1"), side, r.call("rx"), r.call("ry"), r.call("rz"),
			st.sq.min(), st.sq.max(), r.call("nod"), st.tilt.min(), st.tilt.max()])
		if raw or clip not in LOCO:
			continue
		if clip.begins_with("Idle"):
			_check(scr <= IDLE_SCREEN_MAX_CM, "%s: the crown holds still on screen (%.1f cm)" % [clip, scr])
		elif clip not in ["Run_Start", "Run_Stop"]:  # (the skid pitches the whole of him on purpose)
			_check(scr <= SCREEN_MAX_CM, "%s: the crown's screen travel (%.1f cm)" % [clip, scr])
		_check(st.tilt.max() - st.tilt.min() <= TILT_MAX_DEG, "%s: the head stays level (tilt %.1f..%.1f deg)" % [clip, st.tilt.min(), st.tilt.max()])
	if not raw:
		print("[head] %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	model.queue_free()
	await process_frame
	quit(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		_fails += 1
