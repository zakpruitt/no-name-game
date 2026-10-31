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


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.position = offset
	camera.look_at_from_position(offset, Vector3.ZERO, Vector3.UP)
	if target:
		global_position = target.global_position
	Game.camera_rig = self


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target:
		var goal := target.global_position
		goal.y = 0.0
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var s := trauma * trauma
	camera.h_offset = randf_range(-1.0, 1.0) * max_shake_offset * s
	camera.v_offset = randf_range(-1.0, 1.0) * max_shake_offset * s
	camera.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * max_shake_roll * s)
