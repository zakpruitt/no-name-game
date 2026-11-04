extends Node3D
## Angled top-down follow camera with trauma-based screen shake.

@export var target: Node3D
@export var offset := Vector3(0.0, 13.0, 9.5)
@export var follow_speed := 8.0
@export var max_shake_offset := 0.6
@export var max_shake_roll := 2.5
@export var trauma_decay := 1.8

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

# Per-hit feel (hero-agnostic; Game calls these): hits push the camera in a
# hair, more as the chain climbs, clamped so a crowd hit doesn't dive; heavy
# hits roll it a touch. Every nudge chases a target that springs back in real
# time, so stacked hits in one frame blend instead of jittering.
const HIT_ZOOM := 0.012  # push-in per hit, as a fraction of the camera offset
const HIT_ZOOM_TIER := 0.5  # extra per Fx.CHAIN_TIERS tier passed (x1 at tier 0, x2.5 at tier 3)
const HIT_ZOOM_MAX := 0.06  # cap on the stacked push-in (at most 6% closer)
const HIT_ZOOM_RETURN := 7.0  # how fast the push-in springs back (per real second)
const ROLL_DEG := 2.2  # degrees of roll per unit of shake on a heavy hit (Game.shake >= ROLL_SHAKE)
const ROLL_SHAKE := 0.3  # Game.shake amounts from here roll the camera
const ROLL_MAX := 2.5  # cap on the stacked roll, degrees
const ROLL_RETURN := 9.0  # how fast the roll springs back (per real second)
const NUDGE_FOLLOW := 40.0  # how fast kick / zoom / roll reach their targets (per real second)
const KICK_RETURN := 12.0  # how fast a kick springs back (per real second)
const FOV := 42.0
# FOV punch: enders (punch()) and big stops (Game.hitstop's impact frame) and kills narrow the view a few
# degrees on top of the push-in, springing back in real time.
const FOV_ENDER := 2.5  # degrees at a full ender / a full-strength impact frame
const FOV_KILL := 1.5
const FOV_MAX := 5.0
const FOV_RETURN := 6.0  # per real second


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOV
	add_child(camera)
	camera.position = offset
	camera.look_at_from_position(offset, Vector3.ZERO, Vector3.UP)
	if target:
		global_position = target.global_position
	Game.camera_rig = self


## Push the camera in (zoom < 1) or out for `hold` seconds of real time (breakers).
func punch(zoom: float, hold: float) -> void:
	_zoom_to = zoom
	_zoom_until_ms = Time.get_ticks_msec() + int(hold * 1000.0)
	if zoom < 1.0:  # (an ender's ENDER_ZOOM is 0.05-0.1 a tier)
		fov_punch(FOV_ENDER * clampf((1.0 - zoom) / 0.1, 0.4, 1.0))


## Narrow the view by `deg` degrees, stacking up to FOV_MAX, springing back.
func fov_punch(deg: float) -> void:
	if Game.shake_scale <= 0.0:
		return
	_fov_to = minf(_fov_to + deg * minf(Game.shake_scale, 1.0), FOV_MAX)


## Nudge the camera along `dir` (world, flattened) by `amount` m; it springs back
## in real time. Heavy hits and combo enders (player._camera_hit).
func kick(dir: Vector3, amount: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	Game.last_hit_dir = dir.normalized()  # (the impact frame leans this way, even with shake off)
	Game.last_hit_ms = Time.get_ticks_msec()
	if Game.shake_scale <= 0.0:
		return
	_kick_to = (_kick_to + dir.normalized() * amount * Game.shake_scale).limit_length(0.8)


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
	if target:
		var goal := target.global_position
		goal.y = 0.0
		var speed := follow_speed * (3.0 if _zoom_to != 1.0 else 1.0)  # keep up while zoomed
		global_position = global_position.lerp(goal, 1.0 - exp(-speed * delta))
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	if Time.get_ticks_msec() >= _zoom_until_ms:
		_zoom_to = 1.0
	var real_delta := delta / maxf(Engine.time_scale, 0.01)  # slow-mo shouldn't slow the push-in
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
	camera.fov = FOV - _fov
	camera.position = offset * _zoom * (1.0 - _hit_zoom) + _kick
	var s := trauma * trauma
	camera.h_offset = randf_range(-1.0, 1.0) * max_shake_offset * s
	camera.v_offset = randf_range(-1.0, 1.0) * max_shake_offset * s
	camera.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * max_shake_roll * s + _roll)
