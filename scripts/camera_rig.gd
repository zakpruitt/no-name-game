extends Node3D
## Angled top-down follow camera with trauma-based screen shake, framing the fight.

# DISTANCE AND LENS (round 36, "zoom the camera out more, too close to the character"). The camera sits DIST m
# from its follow point along VIEW_DIR (53 deg down, from +Z) with a vertical FOV of FOV deg. Measured at 1080p
# (16:9, tests/camera_feel_check.gd), the 1.85 m chibi stands / the floor in frame covers:
#   round 28  (0, 13, 9.5)   16.1 m, FOV 42: 105 px, 396 m2   (the hero a 40 px hood in the half-size film)
#   round 32  (0, 10, 7.5)   12.5 m, FOV 36: 167 px, 166 m2   (Zak: too close)
#   round 36  (0, 10.4, 7.8) 13.0 m, FOV 37, aimed AIM_HEIGHT 0.8 m up: 140 px, 222 m2   (+34% floor)
# and the fight framing below takes it out to FRAME_MAX x DIST (16.25 m, ~112 px) when a throw spreads the foes.
# Try live: `godot --path . -- --cam-dist=15 --cam-fov=38 --cam-frame=1.3` (cam_overrides(); --cam-frame=1 turns
# the fight framing off). Each +1 m of DIST is about -10 px of hero and +13% floor.
const VIEW_DIR := Vector3(0.0, 0.8, 0.6)  # unit; the pitch every round has kept (atan(0.8 / 0.6) = 53 deg)
const DIST := 13.0  # metres, camera to follow point
const FOV := 37.0  # degrees, vertical
const REF_DIST := 12.5  # the distance the metre-sized nudges (kicks, shake offset) were tuned at (round 32)
const CAM_FLAGS := {"--cam-dist=": "dist", "--cam-fov=": "fov", "--cam-frame=": "frame_max"}

@export var target: Node3D
@export var follow_speed := 8.0
@export var max_shake_offset := 0.6  # metres at REF_DIST; scaled with the distance so shake reads the same
@export var max_shake_roll := 2.5
@export var trauma_decay := 1.8

var dist := DIST  # after any --cam-dist= flag
var fov := FOV  # after any --cam-fov= flag
var frame_max := 0.0  # FRAME_MAX after any --cam-frame= flag (set in _ready)
var offset := VIEW_DIR * DIST  # camera position from the follow point, at rest
var trauma := 0.0
var camera: Camera3D
var _zoom := 1.0
var _zoom_to := 1.0
var _zoom_until_ms := 0
var _kick := Vector3.ZERO  # directional hit nudge (kick), chases _kick_to
var _kick_to := Vector3.ZERO  # where the kicks add up; springs back
var _hit_zoom := 0.0  # per-hit micro push-in (fraction of offset), chases _hit_zoom_to
var _hit_zoom_to := 0.0
var _roll := 0.0  # degrees of hit roll, chases _roll_to
var _roll_to := 0.0
var _roll_sign := 1.0  # heavy hits roll alternate ways so a string rocks
var _fov := 0.0  # degrees narrower than FOV, chases _fov_to
var _fov_to := 0.0
var _hang := 0.0  # 0..1: how far into the breaker-hang push-in (the hero is in State.LEAP)
var _lift := 0.0  # metres the follow point has risen with his leap
var _leap_state := -2  # the target's State.LEAP (-1: it has none; -2: not read yet)
var _frame := 1.0  # fight framing: offset multiplier (>= 1) that fits the hero and the foes he's hitting
var _frame_to := 1.0
var _lean := Vector3.ZERO  # metres the follow point leans towards the fight's middle, chases _lean_to
var _lean_to := Vector3.ZERO
var _last_us := 0  # Time.get_ticks_usec() at the last _process (the real delta)

# Per-hit feel (hero-agnostic; Game calls these): hits push the camera in a
# hair, more as the chain climbs, clamped so a crowd hit doesn't dive; heavy
# hits roll it a touch. Every nudge chases a target that springs back in real
# time, so stacked hits in one frame blend instead of jittering.
const HIT_ZOOM := 0.014  # push-in per hit, as a fraction of the camera offset (0.012 at 12.5 m)
const HIT_ZOOM_TIER := 0.5  # extra per Fx.CHAIN_TIERS tier passed (x1 at tier 0, x2.5 at tier 3)
const HIT_ZOOM_MAX := 0.07  # cap on the stacked push-in (at most 7% closer; 6% at 12.5 m)
const HIT_ZOOM_RETURN := 7.0  # how fast the push-in springs back (per real second)
const ROLL_DEG := 2.2  # degrees of roll per unit of shake on a heavy hit (Game.shake >= ROLL_SHAKE)
const ROLL_SHAKE := 0.3  # Game.shake amounts from here roll the camera
const ROLL_MAX := 2.5  # cap on the stacked roll, degrees
const ROLL_RETURN := 9.0  # how fast the roll springs back (per real second)
const NUDGE_FOLLOW := 40.0  # how fast kick / zoom / roll reach their targets (per real second)
const KICK_RETURN := 12.0  # how fast a kick springs back (per real second)
const KICK_MAX := 0.8  # metres at REF_DIST (kicks scale with dist / REF_DIST, so the same blow moves the frame as far)
# punch() (enders, breaker focus, Awakening, last kill): the callers' zooms were tuned at 12.5 m; from further out
# the same fraction shows the push-in on a wider shot, so PUNCH_GAIN deepens it (ender tier 3: 0.895 -> 0.869).
const PUNCH_GAIN := 1.25
# Breaker hangs (feel audit item 3 / 10): while the hero is in State.LEAP the camera pushes in a little
# and its follow point rises with him, so the hang doesn't climb under the HUD.
const HANG_ZOOM := 0.16  # fraction of the offset the hang pushes in (0.12 at 12.5 m: 13 m x 0.84 ~ the old 12.5 x 0.88 hang)
const HANG_IN := 6.0  # per real second, towards the push-in
const HANG_OUT := 3.0  # per real second, back out after the slam
const LIFT_FOLLOW := 0.75  # fraction of his height off the floor the follow point rises
const LIFT_MAX := 4.0  # metres
# FOV punch: enders (punch()) and big stops (Game.hitstop's impact frame) and kills narrow the view a few
# degrees on top of the push-in, springing back in real time.
const FOV_ENDER := 2.5  # degrees at a full ender / a full-strength impact frame
const FOV_KILL := 1.5
const FOV_MAX := 5.0
const FOV_RETURN := 6.0  # per real second
# FIGHT FRAMING (round 36): the hero and every foe hit in the last FRAME_HIT_MS (within FRAME_RANGE m) stay
# inside FRAME_SAFE of the screen. When a throw or a breaker spreads them past it the camera eases out (up to
# FRAME_MAX x DIST) and the follow point leans FRAME_LEAN of the way to their middle (at most FRAME_LEAN_MAX m);
# once they go quiet it drifts back slowly. A fan of dummies in front of him fits at rest, so in a normal
# string nothing moves. In a breaker hang it reaches further (HANG_FRAME_* below).
const FRAME_MAX := 1.25  # most it zooms out (16.25 m: the hero ~112 px)
const FRAME_HIT_MS := 2200  # a foe hit this recently is part of the fight
const FRAME_RANGE := 11.0  # metres from the hero; further foes are left to the threat arrows
const FRAME_SAFE := Vector2(0.8, 0.72)  # of the half-screen (x, y; y less for the HUD at the top)
const FRAME_HEAD := 1.6  # metres above a foe's feet that must fit too (a thrown foe's body)
const FRAME_OUT := 2.5  # per real second, easing out to fit
const FRAME_BACK := 0.6  # per real second, the slow return
const FRAME_LEAN := 0.6  # of the way from him to the middle of the fight's box (heads included); also in a hang
const FRAME_LEAN_MAX := 2.5  # metres
# The camera aims AIM_HEIGHT m above his feet, not at them: from 53 deg his body and anything in front of him
# (the dummies, a pile in the air) sits up-screen under the HUD, and the round-36 film put their heads on the top
# edge. 0.8 m centres his chest.
const AIM_HEIGHT := 0.8
# BREAKER HANG PULL-OUT (round 36, camera round 2): a hang used to be push-in only, so Meteor Fall's beat 1 (the
# tentacles hurl everyone METEOR_WALL_LENGTH 10 m out at 36 m/s, a 2x splat on a wall) and beat 2 (the drag into
# one pile) happened off screen at 13 m. In State.LEAP the framing now runs too, on everyone hit within
# HANG_FRAME_RANGE, may see HANG_FRAME_GAIN past frame_max, and cancels the hang push-in / focus punch while it is
# out (they come back as the foes come in). Only in the beats (BEATS_PHASE): the rise and the timing window keep
# the push-in. It eases out fast (the throw is ~0.28 s to the wall) and comes back in slower on the dive, which
# keeps its own punch(); once he lands the normal FRAME_BACK drift takes the rest. Uncapped, the round-36 room's
# throw wanted ~3.5x (foes splat on both side walls, 26 m apart): x2.0 keeps the hero ~70 px and every splat but
# the nearest wall's corner on screen.
const HANG_FRAME_GAIN := 1.6  # cap in a hang: frame_max x this (1.25 x 1.6 = 2.0, 26 m; the round-28 view was 16 m)
const HANG_FRAME_RANGE := 22.0  # m: METEOR_REACH 12 + METEOR_WALL_LENGTH 10, who beat 1 can throw and beat 2 gathers
const HANG_FRAME_HIT_MS := 4000  # a hang's foes were hit by the ender before the window's slow motion
const HANG_FRAME_OUT := 12.0  # per real second: 90% out in 0.19 s, before the throw reaches the wall (~0.28 s)
const HANG_FRAME_BACK := 4.0  # per real second on the dive (0.3 s): ~70% back in as he lands
const HANG_LEAN_MAX := 5.0  # m: a throw to one side wall puts the fight's middle ~6.5 m off him; 2.5 cut the splats
const BEATS_PHASE := 3  # hero_leap's _brk_phase between the press and the dive (Meteor Fall's beats 1 and 2)


func _ready() -> void:
	frame_max = FRAME_MAX
	var knobs := cam_overrides(OS.get_cmdline_user_args())
	for key: String in knobs:
		set(key, knobs[key])
	dist = clampf(dist, 4.0, 60.0)
	fov = clampf(fov, 10.0, 100.0)
	frame_max = maxf(frame_max, 1.0)
	if not knobs.is_empty():
		print("[camera] dist=%.2f fov=%.1f frame_max=%.2f" % [dist, fov, frame_max])
	offset = VIEW_DIR * dist
	camera = Camera3D.new()
	camera.fov = fov
	add_child(camera)
	camera.position = offset
	camera.look_at_from_position(offset, Vector3.ZERO, Vector3.UP)
	if target:
		global_position = target.global_position
	Game.camera_rig = self


## The --cam-*=N flags in `args`, as {property: value} (--cam-dist= metres, --cam-fov= degrees,
## --cam-frame= the most the fight framing zooms out, 1 = off).
static func cam_overrides(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		for flag: String in CAM_FLAGS:
			if arg.begins_with(flag) and arg.substr(flag.length()).is_valid_float():
				out[CAM_FLAGS[flag]] = arg.substr(flag.length()).to_float()
	return out


## Push the camera in (zoom < 1) or out for `hold` seconds of real time (breakers).
func punch(zoom: float, hold: float) -> void:
	_zoom_to = 1.0 - (1.0 - zoom) * PUNCH_GAIN if zoom < 1.0 else zoom
	_zoom_until_ms = Time.get_ticks_msec() + int(hold * 1000.0)
	if zoom < 1.0:  # (an ender's ENDER_ZOOM is 0.05-0.1 a tier)
		fov_punch(FOV_ENDER * clampf((1.0 - zoom) / 0.1, 0.4, 1.0))


## Narrow the view by `deg` degrees, stacking up to FOV_MAX, springing back.
func fov_punch(deg: float) -> void:
	if Game.shake_scale <= 0.0:
		return
	_fov_to = minf(_fov_to + deg * minf(Game.shake_scale, 1.0), FOV_MAX)


## Nudge the camera along `dir` (world, flattened) by `amount` m (at REF_DIST; scaled with the distance);
## it springs back in real time. Heavy hits and combo enders (player._camera_hit).
func kick(dir: Vector3, amount: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	Game.last_hit_dir = dir.normalized()  # (the impact frame leans this way, even with shake off)
	Game.last_hit_ms = Time.get_ticks_msec()
	if Game.shake_scale <= 0.0:
		return
	var k := dist / REF_DIST
	_kick_to = (_kick_to + dir.normalized() * amount * k * Game.shake_scale).limit_length(KICK_MAX * k)


## A hit landed: push the camera in by HIT_ZOOM (x `mult`), stacking up to
## HIT_ZOOM_MAX. Game.register_hit calls it with the chain tier's multiplier.
func hit_zoom(mult := 1.0) -> void:
	if Game.shake_scale <= 0.0:
		return
	_hit_zoom_to = minf(_hit_zoom_to + HIT_ZOOM * mult, HIT_ZOOM_MAX)


## Roll the camera `deg` degrees (sign alternates each call), springing back.
## Heavy hits (Game.shake past ROLL_SHAKE).
func roll(deg: float) -> void:
	if Game.shake_scale <= 0.0:
		return
	_roll_sign = -_roll_sign
	_roll_to = clampf(_roll_to + _roll_sign * deg * Game.shake_scale, -ROLL_MAX, ROLL_MAX)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	# Real time, so slow-mo doesn't slow the push-in. Measured, not delta / time_scale: a hitstop that starts this
	# frame divides a delta taken at scale 1 by its 0.03, a 33x step that snapped the hang pull-out home in a frame.
	var now_us := Time.get_ticks_usec()
	var real_delta := clampf((now_us - _last_us) / 1000000.0, 0.0, 0.1) if _last_us > 0 else delta
	_last_us = now_us
	var hanging := target != null and _hanging(target)
	_hang = lerpf(_hang, 1.0 if hanging else 0.0, 1.0 - exp(-(HANG_IN if hanging else HANG_OUT) * real_delta))
	if target:
		var goal := target.global_position
		var body: Variant = target.get("model")  # (the leap lifts his model, not the body)
		var high: float = body.global_position.y if body is Node3D and is_instance_valid(body) else goal.y
		var lift := clampf(high * LIFT_FOLLOW, 0.0, LIFT_MAX) if hanging else 0.0
		_lift = lerpf(_lift, lift, 1.0 - exp(-(HANG_IN if lift > _lift else HANG_OUT) * real_delta))
		goal.y = _lift + AIM_HEIGHT
		_frame_fight(goal, hanging)
		var lean_rate := FRAME_OUT if _lean_to.length() > _lean.length() else FRAME_BACK
		if hanging:  # (the lean keeps pace with the pull-out)
			lean_rate = HANG_FRAME_OUT if _lean_to.length() > _lean.length() else HANG_FRAME_BACK
		_lean = _lean.lerp(_lean_to, 1.0 - exp(-lean_rate * real_delta))
		goal += _lean
		var speed := follow_speed * (3.0 if _zoom_to != 1.0 else 1.0)  # keep up while zoomed
		global_position = global_position.lerp(goal, 1.0 - exp(-speed * delta))
	var frame_rate := FRAME_OUT if _frame_to > _frame else FRAME_BACK
	if hanging:
		frame_rate = HANG_FRAME_OUT if _frame_to > _frame else HANG_FRAME_BACK
	_frame = lerpf(_frame, _frame_to, 1.0 - exp(-frame_rate * real_delta))
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	if Time.get_ticks_msec() >= _zoom_until_ms:
		_zoom_to = 1.0
	_zoom = lerpf(_zoom, _zoom_to, 1.0 - exp(-9.0 * real_delta))
	var follow := 1.0 - exp(-NUDGE_FOLLOW * real_delta)
	_kick_to = _kick_to.lerp(Vector3.ZERO, 1.0 - exp(-KICK_RETURN * real_delta))
	_kick = _kick.lerp(_kick_to, follow)
	_hit_zoom_to = lerpf(_hit_zoom_to, 0.0, 1.0 - exp(-HIT_ZOOM_RETURN * real_delta))
	_hit_zoom = lerpf(_hit_zoom, _hit_zoom_to, follow)
	_roll_to = lerpf(_roll_to, 0.0, 1.0 - exp(-ROLL_RETURN * real_delta))
	_roll = lerpf(_roll, _roll_to, follow)
	_fov_to = lerpf(_fov_to, 0.0, 1.0 - exp(-FOV_RETURN * real_delta))
	_fov = lerpf(_fov, _fov_to, follow)
	camera.fov = fov - _fov
	camera.position = offset * _frame * _zoom * (1.0 - _hit_zoom) * (1.0 - HANG_ZOOM * _hang) + _kick
	var s := trauma * trauma
	var shake := max_shake_offset * dist / REF_DIST * s
	camera.h_offset = randf_range(-1.0, 1.0) * shake
	camera.v_offset = randf_range(-1.0, 1.0) * shake
	camera.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * max_shake_roll * s + _roll)


## Sets _frame_to / _lean_to so the hero (at `goal`) and the foes he's fighting fit FRAME_SAFE of the screen
## (in a breaker hang: further out and wider, until he dives).
func _frame_fight(goal: Vector3, hanging: bool) -> void:
	_frame_to = 1.0
	_lean_to = Vector3.ZERO
	if frame_max <= 1.0:
		return
	var now := Time.get_ticks_msec()
	var hero := target.global_position
	var beats: bool = hanging and target.get("_brk_phase") == BEATS_PHASE  # (Meteor Fall's throw and gather)
	var pts: Array[Vector3] = []
	var lo := Vector2(hero.x, hero.z)
	var hi := lo
	for foe in get_tree().get_nodes_in_group("enemies"):
		if not foe is Node3D or not is_instance_valid(foe) or foe == target:
			continue
		var hit_ms: Variant = foe.get("last_hit_ms")
		if not hit_ms is int or now - int(hit_ms) > (HANG_FRAME_HIT_MS if beats else FRAME_HIT_MS):
			continue
		var at: Vector3 = foe.global_position
		if at.distance_to(hero) > (HANG_FRAME_RANGE if beats else FRAME_RANGE):
			continue
		pts.append(at)
		lo = lo.min(Vector2(at.x, at.z - (at.y + FRAME_HEAD) * VIEW_DIR.z / VIEW_DIR.y))  # (a head reads as
		hi = hi.max(Vector2(at.x, at.z))  # floor that far up-screen)
	if pts.is_empty():
		return
	var mid := (lo + hi) * 0.5
	_lean_to = (Vector3(mid.x - hero.x, 0.0, mid.y - hero.z) * FRAME_LEAN).limit_length(HANG_LEAN_MAX if beats else FRAME_LEAN_MAX)
	if hanging and not beats:
		return  # (the rise, the window and the dive keep the hang's push-in; the dive comes back at HANG_FRAME_BACK)
	pts.append(hero)
	# Camera space at the rest distance: depth of a point = dist * f + d.fwd, so it fits |ndc| <= FRAME_SAFE
	# from f = (|d.side| / (FRAME_SAFE * tan(half fov)) - d.fwd) / dist.
	var fwd := -VIEW_DIR
	var up := VIEW_DIR.cross(Vector3.RIGHT)  # screen up (only its size is read, so the sign doesn't matter)
	var ty := tan(deg_to_rad(fov * 0.5))
	var size := get_viewport().get_visible_rect().size if get_viewport() else Vector2(16.0, 9.0)
	var tx := ty * (size.x / maxf(size.y, 1.0))
	var need := 1.0
	var centre := goal + _lean_to
	for p in pts:
		for h in [0.0, FRAME_HEAD]:
			var d: Vector3 = p + Vector3.UP * h - centre
			var fx := (absf(d.dot(Vector3.RIGHT)) / (FRAME_SAFE.x * tx) - d.dot(fwd)) / dist
			var fy := (absf(d.dot(up)) / (FRAME_SAFE.y * ty) - d.dot(fwd)) / dist
			need = maxf(need, maxf(fx, fy))
	if not beats:
		_frame_to = minf(need, frame_max)
		return
	# In a hang the push-in (HANG_ZOOM, the breaker focus punch) holds until the foes need more room than it leaves,
	# then _frame undoes it and pulls out past it: the distance is max(push-in, need), continuous either way.
	var squeeze := (1.0 - HANG_ZOOM * _hang) * minf(_zoom, 1.0)
	squeeze = maxf(squeeze, 0.1)
	_frame_to = maxf(1.0, minf(need, frame_max * HANG_FRAME_GAIN) / squeeze)  # (the cap is on the distance seen)


## True while `t` (the hero) is in his combo-breaker leap (player.State.LEAP).
func _hanging(t: Node3D) -> bool:
	if _leap_state == -2:
		var states: Variant = t.get_script().get_script_constant_map().get("State") if t.get_script() else null
		_leap_state = int(states.get("LEAP", -1)) if states is Dictionary else -1
	return _leap_state >= 0 and t.get("state") == _leap_state
