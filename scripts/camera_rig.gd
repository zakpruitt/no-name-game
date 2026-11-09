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

# (The rig is built in code, main.gd's `CAMERA.new()`: these are set by it and the checks, never from a scene.)
var target: Node3D
var follow_speed := 8.0
var max_shake_offset := 0.6  # metres at REF_DIST; scaled with the distance so shake reads the same
var max_shake_roll := 2.5
var trauma_decay := 1.8
## The hero's fields the rig reads (player.gd): as StringNames, so a `get()` a frame costs no String conversion. They
## go through `get()` because camera_feel_check drives the rig with bare Node3D stand-ins that lack most of them.
const P_MODEL := &"model"
const P_STATE := &"state"
const P_LANDED := &"breakers_landed"
const P_VOID := &"_void"
const P_ZONE := &"_brk_zone"
const P_LAST_HIT := &"last_hit_ms"

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
const ENV_TARGET_Y := 1.0  # m: the structure indicator's point the hang frames (its bracket top is FRAME_HEAD above)
## HANG FRAMING (round 54, camera-hang lane; feel audit 6 item 10: Meteor Fall's splat, Black Ice's skid, Maw's heap,
## Cold Front's hoisted blocks sat at the frame's edge or under the banner). One rule for the whole breaker scene, the
## leap through the payoff: the framing takes every foe the ending will act on (held by the tentacles, by the landing
## zone, cued) and its cued structure (the indicator's pick, a cued room piece), ZOOMS OUT first, up to HANG_CAP, and
## leans only what the zoom cannot cover (the least lean that fits, found by halving). The actors must fit HANG_SAFE,
## whose top edge sits under the banner, so the banner rarely needs its dodge. No push-in (the hang's, a punch) goes
## deeper than the actors allow. The scene lasts past the landing HANG_AFTER_MS, longer while an actor is still cued
## (up to HANG_AFTER_MAX_MS), so the payoff beat (a skid, a haul, a spit) is framed too.
const HANG_CAP := 1.4  # most the scene zooms out (x DIST: 18.2 m)
const HANG_CAP_WIDE := 1.55  # the last tier: a scene the whole screen can't hold at HANG_CAP (Cold Front's dive off the cube)
const HANG_SAFE := Vector3(0.82, 0.5, 0.8)  # of the half-screen: sides, up (under the banner), down
const HANG_SAFE_FULL := Vector3(0.82, 0.8, 0.8)  # when even leaning can't keep the top band clear: the whole screen
# (the banner's dodge takes over then)
const HANG_LAND_HIT_MS := Vector2i(60, 200)  # a foe hit this long before to after the landing is the ending's too
const HANG_ZONE_R := 5.0  # m round the landing zone (and the landing): foes there are the ending's
const HANG_AFTER_MS := 1300  # real ms the scene frames on past the landing
const HANG_AFTER_MAX_MS := 2600  # at most, however long an actor stays cued
const HANG_LEAN_STEPS := 7  # halvings of the least lean that fits
const HANG_LEAN_MAX := 6.0  # m: the most it leans (only what the zoom can't cover: Cold Front's blocks 8 m behind him)
var _scene_ms := -1  # real ms the breaker scene frames until (-1: none)
var _scene_until := 0  # real ms a cue can keep it on until (the landing + HANG_AFTER_MAX_MS)
var _scene_land := -1  # the hero's breakers_landed when the scene last looked
var _scene_hang := false  # he was in the leap last frame
var _actors := {}  # instance id -> Node3D: the scene's foes
var _safe := HANG_SAFE  # the scene's safe box this frame (HANG_SAFE, or HANG_SAFE_FULL when that can't fit)
var _scene_cap := HANG_CAP  # this frame's cap (HANG_CAP_WIDE in the last tier)
var _scene_env := Vector3.INF  # the indicator's pick as of the leap (INF: none)
var _land_ms := -100000  # the scene's landing (ticks ms)
## Round 56 (feel-audit6, item f): the landing punches in. After the landing the scene used to take its wide tier at
## once, so half the endings went OUT on the slam (Cold Front x1.54 -> 1.68 at +60 ms, Slapshot, Meteor Shower, Uproot,
## Maw, Black Ice 1.45 -> 1.55-1.62). Now the view goes to LAND_PUNCH of where it was at the landing (no wider than the
## actors allow in the looser LAND_SAFE box), holds LAND_HOLD_MS and eases out to the scene's own need by LAND_EASE_MS.
const LAND_PUNCH := 0.85
const LAND_SAFE := Vector3(0.86, 0.62, 0.86)  # of the half-screen: sides, up, down (camera_feel_check's bar is 0.9)
const LAND_HOLD_MS := 50
const LAND_EASE_MS := 330
var _land_from := 0.0  # the view's distance (x the rest offset) on the landing's frame
var _scene_need := 0.0  # how far out the actors need the view (x DIST, uncapped, no floor; 0: no scene), _squeeze()
## Per-frame scratch, kept so the framing allocates nothing a frame: the lens (_need's tangents, from the FOV and the
## viewport once a frame in _lens()), the point lists, and the indicator node.
const FWD := Vector3(0.0, -0.8, -0.6)  # -VIEW_DIR: camera forward
const SCREEN_UP := Vector3(0.0, 0.6, -0.8)  # VIEW_DIR x RIGHT: screen up
const HEAD := Vector3(0.0, FRAME_HEAD, 0.0)
var _tx := 0.0  # tan(half fov) x the aspect
var _ty := 0.0  # tan(half fov)
var _fight_pts: Array[Vector3] = []
var _scene_pts: Array[Vector3] = []
var _scene_structs: Array[Vector3] = []
var _scene_all: Array[Vector3] = []
var _env: Node  # the structure indicator (group env_target), found once


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
		_lens()
		var goal := target.global_position
		var body: Variant = target.get(P_MODEL)  # (the leap lifts his model, not the body)
		var high: float = body.global_position.y if body is Node3D and is_instance_valid(body) else goal.y
		var lift := clampf(high * LIFT_FOLLOW, 0.0, LIFT_MAX) if hanging else 0.0
		_lift = lerpf(_lift, lift, 1.0 - exp(-(HANG_IN if lift > _lift else HANG_OUT) * real_delta))
		goal.y = _lift + AIM_HEIGHT
		if _scene_tick(hanging):
			_frame_scene(goal, hanging)
		else:
			_scene_need = 0.0
			_frame_fight(goal, hanging)
		var lean_rate := (FRAME_CUE_OUT if _cued else FRAME_OUT) if _lean_to.length() > _lean.length() else FRAME_BACK
		if (hanging and not _cued) or (_scene_need > 0.0 and lean_rate == FRAME_BACK):
			lean_rate = HANG_SETTLE  # (a scene's lean comes home at the hang's rate)
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
	var push := _squeeze() * (1.0 - _hit_zoom * (1.0 - _hang))
	if _scene_need > 0.0:  # (a scene's actors stay inside its box through the hits' push-ins and FOV kicks)
		var narrow := tan(deg_to_rad(camera.fov * 0.5)) / tan(deg_to_rad(fov * 0.5))
		push = maxf(push, minf(minf(_scene_need, _scene_cap) / maxf(_frame * narrow, 0.01), 1.0 / maxf(narrow, 0.01)))
	camera.position = offset * _frame * push + _kick
	var s := trauma * trauma
	var shake := max_shake_offset * dist / REF_DIST * s
	_jolt_t += real_delta
	if _jolt_amp > 0.0 and exp(-_jolt_decay * _jolt_t) < 0.02:
		_jolt_amp = 0.0
	var j := jolt_offset()
	camera.h_offset = randf_range(-1.0, 1.0) * shake + j.x
	camera.v_offset = randf_range(-1.0, 1.0) * shake + j.y
	camera.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * max_shake_roll * s + _roll)


## The push-in from the hang and any punch(): the deeper of the two, not their product (a punch out multiplies). In a
## breaker scene no deeper than its actors allow (round 54: the landing's punch put the pile on the edge).
func _squeeze() -> float:
	var hang := 1.0 - HANG_ZOOM * _hang
	var sq := minf(_zoom, hang) if _zoom <= 1.0 else _zoom * hang
	if _scene_need > 0.0 and sq < 1.0:
		sq = clampf(minf(_scene_need, _scene_cap) / maxf(_frame, 0.01), sq, 1.0)
	return sq


## The breaker scene (HANG FRAMING above): is one on, and who its actors are. A leap starts it (the foes the tentacles
## hold and those by the landing zone join each frame); the landing (the hero's breakers_landed going up) adds the
## foes round him and frames HANG_AFTER_MS more, a cued actor longer; a leap that ends with no landing ends it.
func _scene_tick(hanging: bool) -> bool:
	var now := Time.get_ticks_msec()
	var landed_v: Variant = target.get(P_LANDED)
	var landed: int = int(landed_v) if landed_v != null else 0
	var hero := target.global_position
	if hanging and not _scene_hang:
		_actors.clear()  # (a new leap: a new cast)
		_scene_env = Vector3.INF
	if hanging:
		_scene_ms = now + HANG_AFTER_MS
		_scene_until = now + HANG_AFTER_MAX_MS
		var grab: Variant = target.get(P_VOID)
		if grab is Object and is_instance_valid(grab) and (grab as Object).has_method("held_foes"):
			for e: Variant in grab.held_foes():
				if e is Node3D:
					_actors[(e as Node3D).get_instance_id()] = e
		var zone: Variant = target.get(P_ZONE)
		if zone is Vector3:
			_add_near(zone, HANG_ZONE_R)
	if _scene_land >= 0 and landed > _scene_land:  # the landing
		_add_near(Vector3(hero.x, 0.0, hero.z), HANG_ZONE_R)
		_land_ms = now
		_land_from = camera.position.length() / maxf(offset.length(), 0.01)
		_scene_ms = now + HANG_AFTER_MS
		_scene_until = now + HANG_AFTER_MAX_MS
	elif _scene_hang and not hanging:
		_scene_ms = -1  # (out of the leap with no landing: a miss, a dash out)
	_scene_land = landed
	_scene_hang = hanging
	if _scene_ms < 0:
		_actors.clear()
		_scene_env = Vector3.INF
		return false
	for e: Node in get_tree().get_nodes_in_group("enemies"):  # a cued foe joins, and keeps the scene on while cued
		if not hanging and now - _land_ms <= HANG_LAND_HIT_MS.y and e is Node3D:  # (and one the landing hit, however
			var hit: Variant = e.get(P_LAST_HIT)  # far: Short Circuit's arc, Ricochet's bounce, Cold Front's cube)
			if hit is int and int(hit) >= _land_ms - HANG_LAND_HIT_MS.x:
				_actors[e.get_instance_id()] = e
		var cue: int = int(e.get_meta(FRAME_CUE, 0))
		if cue > now and e is Node3D:
			_actors[e.get_instance_id()] = e
			if not hanging:
				_scene_ms = maxi(_scene_ms, mini(cue, _scene_until))
	if not hanging and now >= _scene_ms:
		_scene_ms = -1
		_actors.clear()
		_scene_env = Vector3.INF
		return false
	return true


func _add_near(at: Vector3, r: float) -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var p: Vector3 = (e as Node3D).global_position
		if e != target and Vector2(p.x - at.x, p.z - at.z).length() < r:
			_actors[e.get_instance_id()] = e


## The scene's framing: the actors, the cued structure and him inside HANG_SAFE, zooming out up to HANG_CAP first and
## leaning the least that makes the rest fit.
func _frame_scene(goal: Vector3, hanging: bool) -> void:
	_frame_to = 1.0
	_lean_to = Vector3.ZERO
	_cued = true  # (eases out at FRAME_CUE_OUT)
	_scene_need = 0.0
	var hero := target.global_position
	var pts := _scene_pts
	pts.clear()
	for id: int in _actors.keys():
		var e: Variant = _actors[id]
		if not is_instance_valid(e) or not (e as Node).is_inside_tree():
			_actors.erase(id)
			continue
		var at: Vector3 = (e as Node3D).global_position
		if at.distance_to(hero) <= FRAME_CUE_RANGE:
			pts.append(at)
	var now := Time.get_ticks_msec()
	var structs := _scene_structs
	structs.clear()
	var env: Node = _indicator() if hanging else null
	if env != null and not env.current.is_empty() and env.current.get("state", "") == "target":
		_scene_env = env.current.at + Vector3.UP * ENV_TARGET_Y
	if _scene_env != Vector3.INF and _scene_env.distance_to(hero) <= FRAME_CUE_RANGE:
		structs.append(_scene_env)  # (the pick the leap had stays the scene's: Collapse spits into it after the landing)
	for n: Node in get_tree().get_nodes_in_group("env"):
		if n is Node3D and int(n.get_meta(FRAME_CUE, 0)) > now:
			var at: Vector3 = (n as Node3D).global_position + Vector3.UP * ENV_TARGET_Y
			if at.distance_to(hero) <= FRAME_CUE_RANGE:
				structs.append(at)
	if (pts.is_empty() and structs.is_empty()) or frame_max <= 1.0:
		return
	pts.append(hero)
	var zone: Variant = target.get(P_ZONE) if hanging else null
	if zone is Vector3 and (zone as Vector3).distance_to(hero) <= FRAME_CUE_RANGE:
		pts.append(zone)  # (where the dive lands: the zoom is out for it before he gets there, Cold Front's 8 m dive)
	var body: Variant = target.get(P_MODEL)
	if body is Node3D and is_instance_valid(body):
		pts.append((body as Node3D).global_position)  # (his hang height)
	var all := _scene_all
	all.assign(pts)
	all.append_array(structs)
	_safe = HANG_SAFE
	var need := _need(all, goal, _safe, 0.0)
	if need > HANG_CAP:  # the zoom can't cover it all: lean, the least that fits
		var best := _best_lean(all, goal)
		if _need(all, goal + best, _safe, 0.0) > HANG_CAP:  # (not even leaning: the whole screen, the banner dodges)
			_safe = HANG_SAFE_FULL
			best = _best_lean(all, goal)
		if _need(all, goal + best, _safe, 0.0) > HANG_CAP and not structs.is_empty():
			all = pts  # (still not: the foes first, the structure as near as it comes)
			best = _best_lean(all, goal)
		var s := 1.0
		if _need(all, goal + best, _safe, 0.0) <= HANG_CAP:
			var a := 0.0
			for i in HANG_LEAN_STEPS:
				var m := (a + s) * 0.5
				if _need(all, goal + best * m, _safe, 0.0) > HANG_CAP:
					a = m
				else:
					s = m
		_lean_to = best * s
		need = _need(all, goal + _lean_to, _safe, 0.0)
	# (the lean eases: frame what the view centres on now as well, or a lean still on its way home from the hang put
	# the landing's pile off the bottom while the zoom came in)
	need = maxf(need, _need(all, goal + _lean, _safe, 0.0))
	if not hanging:  # (after the landing, where the follow is too: a dive outruns it; and only then the wide tier)
		need = maxf(need, _need(all, global_position, _safe, 0.0))
		need = _land_punch(all, goal, need, now)
	_scene_need = need
	_scene_cap = HANG_CAP_WIDE if _safe == HANG_SAFE_FULL or (not hanging and need > HANG_CAP) else HANG_CAP
	_frame_to = clampf(need, 1.0, _scene_cap)


## The landing's punch (LAND_PUNCH above): the need eased from the punch to the scene's own over LAND_EASE_MS.
func _land_punch(all: Array[Vector3], goal: Vector3, need: float, now: int) -> float:
	var since := now - _land_ms
	if since < 0 or since >= LAND_EASE_MS or _land_from <= 0.0:
		return need
	var loose := maxf(_need(all, goal + _lean_to, LAND_SAFE, 0.0), maxf(_need(all, goal + _lean, LAND_SAFE, 0.0),
		_need(all, global_position, LAND_SAFE, 0.0)))
	var punch := maxf(_land_from * LAND_PUNCH, loose)
	if punch >= need:
		return need
	var k := smoothstep(0.0, 1.0, float(since - LAND_HOLD_MS) / float(LAND_EASE_MS - LAND_HOLD_MS))
	return lerpf(punch, need, k)


## The lean (within HANG_LEAN_MAX) that lets `pts` fit the nearest: two rounds along x, then z, each a coarse then a
## fine sweep, a tie going to the smaller lean. (A ternary search drifted to the cap on a tie: the pile 6 m sideways
## because nothing sideways mattered.)
func _best_lean(pts: Array[Vector3], goal: Vector3) -> Vector3:
	var lean := Vector3.ZERO
	for round_i in 2:
		for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var base := lean - axis * lean.dot(axis)
			var best_m := 0.0
			var best_n := _need(pts, goal + base, _safe, 0.0)
			for sweep: Vector2 in [Vector2(HANG_LEAN_MAX, 0.5), Vector2(0.5, 0.1)]:  # (half-width, step)
				var from := best_m
				var m := maxf(from - sweep.x, -HANG_LEAN_MAX)
				while m <= minf(from + sweep.x, HANG_LEAN_MAX) + 0.001:
					var n := _need(pts, goal + base + axis * m, _safe, 0.0)
					if n < best_n - 0.002 or (absf(n - best_n) <= 0.002 and absf(m) < absf(best_m)):
						best_n = n
						best_m = m
					m += sweep.y
			lean = base + axis * best_m
	return lean.limit_length(HANG_LEAN_MAX)


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
	var pts := _fight_pts
	pts.clear()
	var lo := Vector2(hero.x, hero.z)
	var hi := lo
	for foe in get_tree().get_nodes_in_group("enemies"):
		if not foe is Node3D or not is_instance_valid(foe) or foe == target:
			continue
		var hit_ms: Variant = foe.get(P_LAST_HIT)
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
	# In a hang, the wall or pillar the ending will use (env_target's structure indicator) counts as a cued foe, so its
	# bracket is in view (Pinwheel's back wall sat on the top edge, the bracket half off it).
	var env: Node = _indicator() if hanging else null
	if env != null and not env.current.is_empty() and env.current.get("state", "") == "target":
		var at: Vector3 = env.current.at + Vector3.UP * ENV_TARGET_Y
		if at.distance_to(hero) <= FRAME_CUE_RANGE:
			pts.append(at)
			_cued = true
			lo = lo.min(Vector2(at.x, at.z - (at.y + FRAME_HEAD) * VIEW_DIR.z / VIEW_DIR.y))
			hi = hi.max(Vector2(at.x, at.z))
	if pts.is_empty():
		return
	var mid := (lo + hi) * 0.5
	pts.append(hero)
	var lean := (Vector3(mid.x - hero.x, 0.0, mid.y - hero.z) * FRAME_LEAN).limit_length(
		FRAME_CUE_LEAN_MAX if _cued else FRAME_LEAN_MAX)
	# Lean only as far as the fight needs room: none while everyone fits around him at rest.
	_lean_to = lean * clampf((_need(pts, goal) - 1.0) / FRAME_LEAN_RAMP, 0.0, 1.0)
	_frame_to = minf(_need(pts, goal + _lean_to), frame_max)


## The lens this frame: the tangents _need() divides by, from the FOV and the viewport's aspect. Once a frame
## (_process); _need() runs hundreds of times a frame in a breaker scene (_best_lean's sweeps).
func _lens() -> void:
	_ty = tan(deg_to_rad(fov * 0.5))
	var size := get_viewport().get_visible_rect().size if get_viewport() else Vector2(16.0, 9.0)
	_tx = _ty * (size.x / maxf(size.y, 1.0))


## The structure indicator (env_target.gd), or null; looked up once and kept while it lives.
func _indicator() -> Node:
	if _env == null or not is_instance_valid(_env) or not _env.is_inside_tree():
		_env = get_tree().get_first_node_in_group(&"env_target")
	return _env


## How far out (x the rest distance) the camera must be for `pts` and their heads to fit FRAME_SAFE around `centre`
## (`safe`: x the sides, y up, z down, of the half-screen; `least`: the least it returns).
func _need(pts: Array[Vector3], centre: Vector3, safe := Vector3(FRAME_SAFE.x, FRAME_SAFE.y, FRAME_SAFE.y), least := 1.0) -> float:
	# Camera space at the rest distance: depth of a point = dist * f + d.fwd, so it fits |ndc| <= FRAME_SAFE
	# from f = (|d.side| / (FRAME_SAFE * tan(half fov)) - d.fwd) / dist. Each point counts at its feet and FRAME_HEAD up.
	if _ty == 0.0:
		_lens()
	var need := least
	for p in pts:
		var d: Vector3 = p - centre
		need = maxf(need, _fit(d, safe))
		need = maxf(need, _fit(d + HEAD, safe))
	return need


## _need() for one camera-space offset `d` from the centre.
func _fit(d: Vector3, safe: Vector3) -> float:
	var fx := (absf(d.x) / (safe.x * _tx) - d.dot(FWD)) / dist
	var sy := d.dot(SCREEN_UP)
	var fy := (absf(sy) / ((safe.y if sy > 0.0 else safe.z) * _ty) - d.dot(FWD)) / dist
	return maxf(fx, fy)


## True while `t` (the hero) is in his combo-breaker leap (player.State.LEAP).
func _hanging(t: Node3D) -> bool:
	if _leap_state == -2:
		var states: Variant = t.get_script().get_script_constant_map().get("State") if t.get_script() else null
		_leap_state = int(states.get("LEAP", -1)) if states is Dictionary else -1
	return _leap_state >= 0 and t.get(P_STATE) == _leap_state
