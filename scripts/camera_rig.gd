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
var _cued := false  # a foe in the framing is cued (FRAME_CUE), not hit yet: ease out fast
var _lean := Vector3.ZERO  # metres the follow point leans towards the fight's middle, chases _lean_to
var _lean_to := Vector3.ZERO
var _last_us := 0  # Time.get_ticks_usec() at the last _process (the real delta)
## Breaker spectacle: a landing's jolt (jolt()): a damped shake along one screen axis on real time, on top of the
## random trauma shake, so each element's landing has its own feel (storm buzzes sideways, magma thuds down and
## rumbles, ice cracks short, dark sinks slow; designed_breaker.FEEL). Starts at its peak (cos), so the blow lands
## on the landing's first frame.
const JOLT_MAX := 0.9  # metres at REF_DIST
var _jolt_amp := 0.0
var _jolt_t := 0.0
var _jolt_hz := 0.0
var _jolt_decay := 0.0
var _jolt_axis := Vector2.DOWN

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
const PUNCH_MIN := 0.8  # the deepest any punch goes (a perfect landing's 0.75 x the gain was a 31% dive)
# Breaker hangs (feel audit item 3 / 10): while the hero is in State.LEAP the camera pushes in a little
# and its follow point rises with him, so the hang doesn't climb under the HUD.
# CALM PASS (Zak, 2026-11-05: "the camera is all messed up, especially during the special moves; weird how it
# frames the player"). A breaker stacked the hang push-in, the focus punch x PUNCH_GAIN, the per-hit push-in, a
# lean of up to 2.5 m off him, then Meteor Fall's x2.0 pull-out in 0.19 s: the view went from 0.64x to 2.0x and
# slid sideways in one move. Now: he stays centred in a hang (no lean outside Meteor Fall's beats), the push-ins
# don't multiply (the deeper of hang and punch wins, per-hit push-in fades out in a hang), and the pull-out is
# shorter and slower.
const HANG_ZOOM := 0.06  # fraction of the offset the hang pushes in (was 0.16)
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
# string nothing moves. In a breaker hang it doesn't run: he stays centred (HANG_SETTLE below).
const FRAME_MAX := 1.25  # most it zooms out (16.25 m: the hero ~112 px)
const FRAME_HIT_MS := 2200  # a foe hit this recently is part of the fight
const FRAME_RANGE := 11.0  # metres from the hero; further foes are left to the threat arrows
const FRAME_SAFE := Vector2(0.8, 0.72)  # of the half-screen (x, y; y less for the HUD at the top)
const FRAME_HEAD := 1.6  # metres above a foe's feet that must fit too (a thrown foe's body)
const FRAME_OUT := 2.5  # per real second, easing out to fit
## Feel audit 3 item 5: a move that is about to strike foes outside the view cues them (meta FRAME_CUE on the foe:
## the real ms until which it counts as the fight, Short Circuit's targets at its landing). A cued foe counts before
## it is hit, and the view eases out at FRAME_CUE_OUT: at FRAME_OUT the far arcs landed off screen (worst foe at
## ndc 1.47 on its arc) and it came in ~0.3 s later.
const FRAME_CUE := &"frame_cue_ms"
const FRAME_CUE_OUT := 7.0  # per real second
const FRAME_BACK := 0.6  # per real second, the slow return
const FRAME_LEAN := 0.6  # of the way from him to the middle of the fight's box (heads included)
const FRAME_LEAN_MAX := 1.5  # metres (was 2.5: he sat visibly off-centre)
const FRAME_CUE_LEAN_MAX := 3.5  # metres while a cued foe is in the fight (round 47: Slapshot's cubes sliding 8-10 m
# up-screen into a wall hit on the top edge at 1.5; a cue is a short, deliberate look away from him)
const FRAME_LEAN_RAMP := 0.25  # the lean fades in over this much needed zoom-out; a fight that fits at rest has none
# The camera aims AIM_HEIGHT m above his feet, not at them: from 53 deg his body and anything in front of him
# (the dummies, a pile in the air) sits up-screen under the HUD, and the round-36 film put their heads on the top
# edge. 0.8 m centres his chest.
const AIM_HEIGHT := 0.8
# In a breaker hang the fight framing and the lean settle back to none at HANG_SETTLE, so he stays centred in the
# hang's push-in through the rise, the window and the dive. (Round 36's HANG_FRAME_* pull-out for Meteor Fall's wall
# throw and gather went with those beats in round 42: the meteor now dives straight onto a group.)
const HANG_SETTLE := 3.0  # per real second
## Feel audit 3 item 6: a cued foe still counts in a hang (only cued ones: a foe merely hit keeps him centred), so
## Meteor Fall's hang frames the wall splat Molten Palm cued (void_element.PALM_CUE_MS) and the dive onto it; it
## sat in the top-left corner, half off frame, for the whole hang. Cued foes count this far out (the palm's carry).
const FRAME_CUE_RANGE := 17.0


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


## The rest view a shot test copies (tests/comic_shots, foe_shots, heretic_shots), so its sheets match the game:
## {"offset": the camera from the point it aims at, "aim": m above his feet that point is, "fov": degrees}, after
## any --cam-dist= / --cam-fov= in `args`. A -s test can't preload this script (it names Game): `load()` it.
static func rest_view(args: PackedStringArray) -> Dictionary:
	var knobs := cam_overrides(args)
	var d := clampf(float(knobs.get("dist", DIST)), 4.0, 60.0)
	return {"offset": VIEW_DIR * d, "aim": AIM_HEIGHT, "fov": clampf(float(knobs.get("fov", FOV)), 10.0, 100.0)}


## Push the camera in (zoom < 1) or out for `hold` seconds of real time (breakers).
func punch(zoom: float, hold: float) -> void:
	var gain := 1.0 if target != null and _hanging(target) else PUNCH_GAIN  # (a hang is already pushed in)
	_zoom_to = maxf(1.0 - (1.0 - zoom) * gain, PUNCH_MIN) if zoom < 1.0 else zoom
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


## A damped jolt of `amount` m (at REF_DIST) along `axis` (screen x right, y up), ringing at `hz`, dying at `decay`
## per real second; a new one adds to what is left of the last. Scaled by the shake setting, none with it off.
func jolt(amount: float, hz: float, decay: float, axis: Vector2) -> void:
	if Game.shake_scale <= 0.0:
		return
	var left := _jolt_amp * exp(-_jolt_decay * _jolt_t)
	_jolt_amp = minf(left + amount * minf(Game.shake_scale, 1.5), JOLT_MAX)
	_jolt_t = 0.0
	_jolt_hz = hz
	_jolt_decay = decay
	_jolt_axis = axis.normalized() if axis.length() > 0.01 else Vector2.DOWN


## The jolt's offset now (screen x, y), metres at the current distance.
func jolt_offset() -> Vector2:
	if _jolt_amp <= 0.0:
		return Vector2.ZERO
	return _jolt_axis * _jolt_amp * exp(-_jolt_decay * _jolt_t) * cos(TAU * _jolt_hz * _jolt_t) * dist / REF_DIST


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
		var lean_rate := (FRAME_CUE_OUT if _cued else FRAME_OUT) if _lean_to.length() > _lean.length() else FRAME_BACK
		if hanging and not _cued:
			lean_rate = HANG_SETTLE
		_lean = _lean.lerp(_lean_to, 1.0 - exp(-lean_rate * real_delta))
		goal += _lean
		var speed := follow_speed * (3.0 if _zoom_to != 1.0 else 1.0)  # keep up while zoomed
		global_position = global_position.lerp(goal, 1.0 - exp(-speed * delta))
	var frame_rate := (FRAME_CUE_OUT if _cued else FRAME_OUT) if _frame_to > _frame else FRAME_BACK
	if hanging and not _cued:
		frame_rate = HANG_SETTLE
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
	camera.position = offset * _frame * _squeeze() * (1.0 - _hit_zoom * (1.0 - _hang)) + _kick
	var s := trauma * trauma
	var shake := max_shake_offset * dist / REF_DIST * s
	_jolt_t += real_delta
	if _jolt_amp > 0.0 and exp(-_jolt_decay * _jolt_t) < 0.02:
		_jolt_amp = 0.0
	var j := jolt_offset()
	camera.h_offset = randf_range(-1.0, 1.0) * shake + j.x
	camera.v_offset = randf_range(-1.0, 1.0) * shake + j.y
	camera.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * max_shake_roll * s + _roll)


## The push-in from the hang and any punch(): the deeper of the two, not their product (a punch out multiplies).
func _squeeze() -> float:
	var hang := 1.0 - HANG_ZOOM * _hang
	return minf(_zoom, hang) if _zoom <= 1.0 else _zoom * hang


## Sets _frame_to / _lean_to so the hero (at `goal`) and the foes he's fighting fit FRAME_SAFE of the screen
## (in a breaker hang: none, he stays centred).
func _frame_fight(goal: Vector3, hanging: bool) -> void:
	_frame_to = 1.0
	_lean_to = Vector3.ZERO
	_cued = false
	if frame_max <= 1.0:
		return  # (a hang: the rise, the window and the dive keep him centred in its push-in, cued foes aside)
	var now := Time.get_ticks_msec()
	var hero := target.global_position
	var pts: Array[Vector3] = []
	var lo := Vector2(hero.x, hero.z)
	var hi := lo
	for foe in get_tree().get_nodes_in_group("enemies"):
		if not foe is Node3D or not is_instance_valid(foe) or foe == target:
			continue
		var hit_ms: Variant = foe.get("last_hit_ms")
		var cued: bool = int(foe.get_meta(FRAME_CUE, 0)) > now
		if not cued and (hanging or not hit_ms is int or now - int(hit_ms) > FRAME_HIT_MS):
			continue
		var at: Vector3 = foe.global_position
		if at.distance_to(hero) > (FRAME_CUE_RANGE if cued else FRAME_RANGE):
			continue
		pts.append(at)
		_cued = _cued or cued
		lo = lo.min(Vector2(at.x, at.z - (at.y + FRAME_HEAD) * VIEW_DIR.z / VIEW_DIR.y))  # (a head reads as
		hi = hi.max(Vector2(at.x, at.z))  # floor that far up-screen)
	if pts.is_empty():
		return
	var mid := (lo + hi) * 0.5
	pts.append(hero)
	var lean := (Vector3(mid.x - hero.x, 0.0, mid.y - hero.z) * FRAME_LEAN).limit_length(
		FRAME_CUE_LEAN_MAX if _cued else FRAME_LEAN_MAX)
	# Lean only as far as the fight needs room: none while everyone fits around him at rest.
	_lean_to = lean * clampf((_need(pts, goal) - 1.0) / FRAME_LEAN_RAMP, 0.0, 1.0)
	_frame_to = minf(_need(pts, goal + _lean_to), frame_max)


## How far out (x the rest distance) the camera must be for `pts` and their heads to fit FRAME_SAFE around `centre`.
func _need(pts: Array[Vector3], centre: Vector3) -> float:
	# Camera space at the rest distance: depth of a point = dist * f + d.fwd, so it fits |ndc| <= FRAME_SAFE
	# from f = (|d.side| / (FRAME_SAFE * tan(half fov)) - d.fwd) / dist.
	var fwd := -VIEW_DIR
	var up := VIEW_DIR.cross(Vector3.RIGHT)  # screen up (only its size is read, so the sign doesn't matter)
	var ty := tan(deg_to_rad(fov * 0.5))
	var size := get_viewport().get_visible_rect().size if get_viewport() else Vector2(16.0, 9.0)
	var tx := ty * (size.x / maxf(size.y, 1.0))
	var need := 1.0
	for p in pts:
		for h in [0.0, FRAME_HEAD]:
			var d: Vector3 = p + Vector3.UP * h - centre
			var fx := (absf(d.dot(Vector3.RIGHT)) / (FRAME_SAFE.x * tx) - d.dot(fwd)) / dist
			var fy := (absf(d.dot(up)) / (FRAME_SAFE.y * ty) - d.dot(fwd)) / dist
			need = maxf(need, maxf(fx, fy))
	return need


## True while `t` (the hero) is in his combo-breaker leap (player.State.LEAP).
func _hanging(t: Node3D) -> bool:
	if _leap_state == -2:
		var states: Variant = t.get_script().get_script_constant_map().get("State") if t.get_script() else null
		_leap_state = int(states.get("LEAP", -1)) if states is Dictionary else -1
	return _leap_state >= 0 and t.get("state") == _leap_state
