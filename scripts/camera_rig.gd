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
var _kick := Vector3.ZERO  # directional hit nudge (kick), springs back


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.position = offset
	camera.look_at_from_position(offset, Vector3.ZERO, Vector3.UP)
	if target:
		global_position = target.global_position
	Game.camera_rig = self


## Push the camera in (zoom < 1) or out for `hold` seconds of real time (ultimates).
func punch(zoom: float, hold: float) -> void:
	_zoom_to = zoom
	_zoom_until_ms = Time.get_ticks_msec() + int(hold * 1000.0)


## Nudge the camera along `dir` (world, flattened) by `amount` m; it springs back
## in real time. Heavy hits and combo enders (player._camera_hit).
func kick(dir: Vector3, amount: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001 or Game.shake_scale <= 0.0:
		return
	_kick = (_kick + dir.normalized() * amount * Game.shake_scale).limit_length(0.8)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target:
		var goal := target.global_position
		goal.y = 0.0
		var speed := follow_speed * (3.0 if _zoom_to != 1.0 else 1.0)  # keep up with ultimates
		global_position = global_position.lerp(goal, 1.0 - exp(-speed * delta))
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	if Time.get_ticks_msec() >= _zoom_until_ms:
		_zoom_to = 1.0
	var real_delta := delta / maxf(Engine.time_scale, 0.01)  # slow-mo shouldn't slow the push-in
	_zoom = lerpf(_zoom, _zoom_to, 1.0 - exp(-9.0 * real_delta))
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-12.0 * real_delta))
	camera.position = offset * _zoom + _kick
	var s := trauma * trauma
	camera.h_offset = randf_range(-1.0, 1.0) * max_shake_offset * s
	camera.v_offset = randf_range(-1.0, 1.0) * max_shake_offset * s
	camera.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * max_shake_roll * s)
