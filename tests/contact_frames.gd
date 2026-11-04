extends SceneTree
## Measures each hero clip's contact frame off its GLB tracks and prints the ComicLook.HERO_MOVES line it
## should have, for every model in ComicLook.HERETIC_MODELS. Re-run after re-keying or re-baking a clip and
## copy the printed `hit` / `frames` into HERO_MOVES; comic_check fails until they match.
## The contact frame is the last frame (at HERO_CLIP_FPS) where the weapon hand (`hand.r`) still moves at
## HERO_CONTACT_SPEED of the clip's peak hand speed: where the swing arrives.
## Run: godot --headless --path . -s tests/contact_frames.gd


func _initialize() -> void:
	var look: GDScript = load("res://scripts/comic_look.gd")  # (at runtime: it names Game)
	for model_id: String in look.HERETIC_MODELS:
		var model: Node3D = load("res://assets/comic/%s.glb" % look.HERETIC_MODELS[model_id]).instantiate()
		var rig: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		for id: String in look.HERO_MOVES:
			var h: Dictionary = look.HERO_MOVES[id]
			var clip := rig.get_animation(h.clip)
			var frames := roundi(clip.length * look.HERO_CLIP_FPS)
			var hit := contact_frame(model, clip, frames, look.HERO_CLIP_FPS, look.HERO_CONTACT_SPEED)
			var same := "ok" if hit == h.hit and frames == h.frames else "CHANGED (table: %d/%d)" % [h.hit, h.frames]
			print("[contact] %s %s: \"hit\": %d, \"frames\": %d  (%.3f s of %.3f s)  %s" % [model_id, id, hit, frames,
				hit / look.HERO_CLIP_FPS, clip.length, same])
		model.free()
	quit()


## The contact frame of `clip` (`frames` long at `fps`), see above.
static func contact_frame(model: Node3D, clip: Animation, frames: int, fps: float, speed_frac: float) -> int:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var hand := skel.find_bone("hand.r")
	var speeds: Array[float] = [0.0]
	var prev := track_pose(skel, clip, hand, 0.0).origin
	for f in range(1, frames + 1):
		var at := track_pose(skel, clip, hand, f / fps).origin
		speeds.append(at.distance_to(prev))
		prev = at
	var peak: float = speeds.max()
	var last := 0
	for f in speeds.size():
		if speeds[f] >= speed_frac * peak:
			last = f
	return last


## A bone's skeleton-space pose at `t` in `clip`, from its rest and the clip's tracks up the chain
## (no AnimationPlayer: it doesn't pose a skeleton from _initialize).
static func track_pose(skel: Skeleton3D, clip: Animation, bone: int, t: float) -> Transform3D:
	var x := Transform3D.IDENTITY
	var b := bone
	while b >= 0:
		var rest := skel.get_bone_rest(b)
		var pos := rest.origin
		var rot := rest.basis.get_rotation_quaternion()
		var scl := rest.basis.get_scale()
		var suffix := ":" + skel.get_bone_name(b)
		for i in clip.get_track_count():
			if not str(clip.track_get_path(i)).ends_with(suffix):
				continue
			match clip.track_get_type(i):
				Animation.TYPE_POSITION_3D: pos = clip.position_track_interpolate(i, t)
				Animation.TYPE_ROTATION_3D: rot = clip.rotation_track_interpolate(i, t)
				Animation.TYPE_SCALE_3D: scl = clip.scale_track_interpolate(i, t)
		x = Transform3D(Basis(rot).scaled(scl), pos) * x
		b = skel.get_bone_parent(b)
	return x
