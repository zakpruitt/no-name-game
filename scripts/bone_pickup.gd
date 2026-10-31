extends Node3D
## A bone shard dropped by a slain skeleton: pops out, bounces, then homes in
## on the hero and is collected (Game.add_bones). Worth 1 bone.

const GRAVITY := 22.0
const HOME_DELAY := 0.55  # seconds of bouncing before it flies to the hero
const HOME_SPEED := 16.0
const COLLECT_RADIUS := 0.8
const FLOOR_Y := 0.15

var velocity := Vector3.ZERO
var _age := 0.0
var _player: Node3D
var _spin := Vector3.ZERO


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	var m := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.92, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.5)
	mat.emission_energy_multiplier = 0.6
	mesh.material = mat
	m.mesh = mesh
	m.rotation.z = PI * 0.5
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var ang := randf() * TAU
	velocity = Vector3(cos(ang) * randf_range(2.0, 4.5), randf_range(5.0, 8.0), sin(ang) * randf_range(2.0, 4.5))
	_spin = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))


func _physics_process(delta: float) -> void:
	_age += delta
	rotation += _spin * delta
	var homing: bool = _age >= HOME_DELAY and is_instance_valid(_player) and not _player.is_dead()
	if homing:
		var to := _player.global_position + Vector3.UP * 0.8 - global_position
		if to.length() < COLLECT_RADIUS:
			_collect()
			return
		velocity = velocity.lerp(to.normalized() * HOME_SPEED, minf(1.0, 8.0 * delta))
	else:
		velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	if not homing and global_position.y < FLOOR_Y:
		global_position.y = FLOOR_Y
		velocity.y = absf(velocity.y) * 0.4
		velocity.x *= 0.6
		velocity.z *= 0.6


func _collect() -> void:
	Game.add_bones(1)
	Game.sfx("pickup", -10.0, 0.15)
	Fx.burst(get_parent(), global_position, Color(1.0, 0.9, 0.6), 4, 2.5, 0.06, 0.2)
	queue_free()
