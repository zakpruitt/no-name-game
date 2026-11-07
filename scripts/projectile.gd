extends Node3D
## Slow, glowing enemy bolt. Flies straight, hurts the player on contact,
## and pops on walls/pillars. Dashing through it can trigger a perfect dodge.

@export var speed := 9.0
@export var damage := 12.0
@export var lifetime := 3.0
@export var hit_radius := 0.7
@export var color := Color(0.75, 0.35, 1.0)
## Thin crossbow bolt instead of a glowing orb (the archer's fast shot).
@export var bolt := false

static var fired := 0  # running count, reported by the autotest

var direction := Vector3.FORWARD
var source: Node = null  # who fired it (stunned on a perfect dodge)
## Parried by the dash counter (counter.gd): it flies back and hits foes, not him.
var reflected := false

var _age := 0.0
var _player: Node3D


func _ready() -> void:
	fired += 1
	add_to_group("projectiles")
	_player = get_tree().get_first_node_in_group("player")
	var m := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	if bolt:
		var shaft := CapsuleMesh.new()
		shaft.radius = 0.09
		shaft.height = 1.1
		mesh = shaft
		m.rotation.x = PI * 0.5  # lie along +Z
		rotation.y = atan2(direction.x, direction.z)
	else:
		var orb := SphereMesh.new()
		orb.radius = 0.28
		orb.height = 0.56
		mesh = orb
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.7)  # white-hot core inside the coloured halo
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_add_halo(0.75 if bolt else 1.5)
	_add_trail(0.22 if bolt else 0.4)
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
	if reflected:
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if e.is_alive() and ((e as Node3D).global_position + Vector3.UP - global_position).length() < hit_radius + float(e.radius):
				e.take_hit(damage, direction * 4.0, 0.0, true)
				Game.register_hit("counter")
				_pop()
				return
		return
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
	Fx.flare(get_parent(), global_position, color, 2.4, 0.15, "flare")
	Fx.flare(get_parent(), global_position, Color(color, 0.8), 1.4, 0.2, "ring")
	queue_free()


## Soft glow sprite in the shot's colour (a danger colour that reads on the light floor).
func _add_halo(size: float) -> void:
	var mat := Fx.unshaded_mat(Color(color, 0.9), "dot")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = mat
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)


## Fading motes left behind in world space.
func _add_trail(size: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.3
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.4
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.8))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = Fx.particle_mat("dot", false)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
