extends Node3D
## Slow, glowing enemy bolt. Flies straight, hurts the player on contact,
## and pops on walls/pillars. Dashing through it can trigger a perfect dodge.

@export var speed := 9.0
@export var damage := 12.0
@export var lifetime := 3.0
@export var hit_radius := 0.7
@export var color := Color(0.75, 0.35, 1.0)

static var fired := 0  # running count, reported by the autotest

var direction := Vector3.FORWARD
var source: Node = null  # who fired it (stunned on a perfect dodge)

var _age := 0.0
var _player: Node3D


func _ready() -> void:
	fired += 1
	add_to_group("projectiles")
	_player = get_tree().get_first_node_in_group("player")
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.4)
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	if get_world_3d().direct_space_state.intersect_ray(query):
		_pop()
		return
	global_position = to
	if is_instance_valid(_player) and not _player.is_dead():
		var d := _player.global_position + Vector3.UP * 1.0 - global_position
		if d.length() < hit_radius:
			# Dashing (i-frames) lets the bolt pass through; a well-timed dash still counts as a perfect dodge.
			var dodging: bool = _player.is_invulnerable()
			_player.take_hit(damage, direction * 6.0, source if is_instance_valid(source) else null)
			if not dodging:
				_pop()


func _pop() -> void:
	Fx.burst(get_parent(), global_position, color, 12, 6.0, 0.18, 0.3, -direction, 80.0, 0.0)
	queue_free()
