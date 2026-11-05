extends SceneTree
## Measures each hero clip's contact frame off its GLB tracks and prints the ComicLook.HERO_MOVES line it
## should have, for every model in ComicLook.HERETIC_MODELS. Re-run after re-keying or re-baking a clip and
## copy the printed `hit` / `frames` into HERO_MOVES; comic_check fails until they match.
## The contact frame is the last frame (at HERO_CLIP_FPS) where the weapon hand (`hand.r`) still moves at
## HERO_CONTACT_SPEED of the clip's peak hand speed: where the swing arrives.
## The tentacle clips (VOID_CLIPS) are measured too, on KEYED_MODEL, against void_element.gd's `*_HIT`
## (the void moves' `MOVES.hits`): "swing" clips by the same rule, "snap" clips (the grab) on the claw
## snap instead: the last frame the claw tips move (SNAP_STILL of their peak) before they hold still for
## SNAP_HOLD frames after the hand's fastest frame. (The 40% rule found Ab_GR's yank home, f16, not the grab.)
## Run: godot --headless --path . -s tests/contact_frames.gd

## Clip -> [rule, void_element constant holding its contact as a fraction of the clip].
const VOID_CLIPS := {"Ab_GR": ["snap", "GR_HIT"], "Ab_VS": ["swing", "VS_HIT"], "Ab_LH": ["swing", "LH_HIT"],
	"Ab_H": ["swing", "H_HIT"], "Ab_LLH": ["swing", "LLH_HIT"], "Ab_AF": ["swing", "AF_HIT"]}
## The model the void moves' hits are set from (the default hero; its clips are hand-keyed to these contacts).
## The round-28 heretic shares MOVES and only prints how far off its own clips are.
const KEYED_MODEL := "chibi"
## Void moves whose first hit isn't the clip's strike: Vault rides Ab_LH up the spear (its "hit" is the top of
## the vault), and Deep Freeze (IS) is Avalanche's ender, left as tuned.
const VOID_EXEMPT := ["IJ", "IS"]
const SNAP_STILL := 0.05
const SNAP_HOLD := 3
const TIPS := ["up", "out", "mid", "low", "back", "main"]


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
		var el: GDScript = load("res://scripts/void_element.gd")
		for clip_name: String in VOID_CLIPS:
			var clip := rig.get_animation(clip_name)
			var frames := roundi(clip.length * look.HERO_CLIP_FPS)
			var hit: int = void_contact(model, clip, frames, look.HERO_CLIP_FPS, look.HERO_CONTACT_SPEED, VOID_CLIPS[clip_name][0])
			var table: float = el.get(VOID_CLIPS[clip_name][1])
			var off: float = (table * frames - hit) / look.HERO_CLIP_FPS * 1000.0
			var same := "ok" if absf(off) < 1.0 else ("CHANGED" if model_id == KEYED_MODEL else "info") + " (%s = %.4f, %+.0f ms of clip)" % [VOID_CLIPS[clip_name][1], table, off]
			print("[contact] %s %s (%s): %d / %d frames = %.4f  (%.3f s)  %s" % [model_id, clip_name, VOID_CLIPS[clip_name][0], hit, frames,
				float(hit) / frames, hit / look.HERO_CLIP_FPS, same])
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


## A tentacle clip's contact frame by its VOID_CLIPS rule ("swing" or "snap", see above).
static func void_contact(model: Node3D, clip: Animation, frames: int, fps: float, speed_frac: float, rule: String) -> int:
	if rule == "swing":
		return contact_frame(model, clip, frames, fps, speed_frac)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var hand := skel.find_bone("hand.r")
	var tips: Array[int] = []
	for tip: String in TIPS:  # the last bone of each claw chain
		var last := -1
		for n in range(1, 13):
			var b := skel.find_bone("tent.%s.%02d" % [tip, n])
			if b >= 0:
				last = b
		if last >= 0:
			tips.append(last)
	var hand_v: Array[float] = [0.0]
	var tip_v: Array[float] = [0.0]
	var prev_h := track_pose(skel, clip, hand, 0.0).origin
	var prev_t := _tips_at(skel, clip, tips, 0.0)
	for f in range(1, frames + 1):
		var h := track_pose(skel, clip, hand, f / fps).origin
		var t := _tips_at(skel, clip, tips, f / fps)
		hand_v.append(h.distance_to(prev_h))
		tip_v.append(t.distance_to(prev_t))
		prev_h = h
		prev_t = t
	var still: float = SNAP_STILL * tip_v.max()
	var quiet := 0
	for f in range(hand_v.find(hand_v.max()) + 1, tip_v.size()):
		quiet = quiet + 1 if tip_v[f] < still else 0
		if quiet == SNAP_HOLD:
			return f - SNAP_HOLD
	return contact_frame(model, clip, frames, fps, speed_frac)


## The claw tips' mean position at `t` (skeleton space).
static func _tips_at(skel: Skeleton3D, clip: Animation, tips: Array[int], t: float) -> Vector3:
	var at := Vector3.ZERO
	for b in tips:
		at += track_pose(skel, clip, b, t).origin
	return at / maxf(tips.size(), 1)
