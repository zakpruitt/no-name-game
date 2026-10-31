extends Node3D
## One spike of the Bone Warden's spike line: a red warning disc, then a
## cluster of bone spikes stabs up, hurts the hero if they're standing on it,
## and sinks away. The boss lays these out one after another (boss.gd).

const BONE_COLOR := Color(0.92, 0.88, 0.78)
const SPIKES := 5

var warn_time := 0.4
var radius := 1.0
var damage := 18.0
var source: Node  # the boss (a perfect dodge through a spike stuns it)

var _warn_mat: StandardMaterial3D
var _cluster: Node3D


func _ready() -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warn_mat.albedo_color = Color(1.0, 0.15, 0.1, 0.0)
	mesh.material = _warn_mat
	disc.mesh = mesh
	disc.position.y = 0.09
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	_cluster = Node3D.new()
	_cluster.scale = Vector3(1.0, 0.01, 1.0)
	_cluster.visible = false
	add_child(_cluster)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BONE_COLOR
	for i in SPIKES:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = randf_range(0.14, 0.22)
		cone.height = randf_range(1.0, 1.6)
		cone.radial_segments = 6
		cone.material = mat
		spike.mesh = cone
		var ang := TAU * i / SPIKES + randf() * 0.6
		var off := 0.0 if i == 0 else randf_range(0.35, radius * 0.75)
		spike.position = Vector3(cos(ang) * off, cone.height * 0.5, sin(ang) * off)
		spike.rotation = Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
		_cluster.add_child(spike)

	var tw := create_tween()
	tw.tween_property(_warn_mat, "albedo_color:a", 0.55, warn_time)
	tw.tween_callback(_stab)
	tw.tween_property(_cluster, "scale:y", 1.0, 0.06)
	tw.tween_interval(0.35)
	tw.tween_property(_warn_mat, "albedo_color:a", 0.0, 0.2)
	tw.parallel().tween_property(_cluster, "position:y", -1.7, 0.4)
	tw.tween_callback(queue_free)


func _stab() -> void:
	_cluster.visible = true
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.3, BONE_COLOR, 8, 5.0, 0.1, 0.25, Vector3.UP, 50.0)
	Fx.dust(get_parent(), global_position, 6, 0.5)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or player.is_dead():
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() <= radius + 0.3:
		player.take_hit(damage, to.normalized() * 6.0 + Vector3.UP * 4.0, source if is_instance_valid(source) else null,
			"the Bone Warden's bone spikes")
