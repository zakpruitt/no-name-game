extends Node3D
## The Bone Warden's cage: a ring of bone walls bursts up around the hero,
## then closes in, slowly turning. One gap in the ring is the way out (or dash
## through a wall on i-frames). Walls that reach the hero hurt once; whatever
## is still inside when the ring is fully shut gets stabbed. boss.gd tunes it
## through ATTACKS.cage.

const BONE_COLOR := Color(0.92, 0.88, 0.78)
const WARN_COLOR := Color(1.0, 0.15, 0.1)

var radius := 7.0  # starting ring radius (m)
var end_radius := 1.0  # where the ring stops and stabs
var rise_time := 0.5  # walls grow out of the floor (harmless)
var close_time := 2.6  # seconds from radius to end_radius
var gap := 50.0  # degrees of open ring
var gap_angle := 0.0  # radians, world yaw of the gap's middle
var spin := 25.0  # degrees per second the ring turns while closing
var walls := 22  # wall pieces around a full ring (some are left out for the gap)
var damage := 20.0
var source: Node  # the boss (a perfect dodge through a wall stuns it)

var _t := 0.0
var _r := 0.0
var _hit_done := false
var _pieces: Array[Node3D] = []
var _angles: Array[float] = []
var _floor_ring: MeshInstance3D
var _floor_mat: StandardMaterial3D
var _done := false


func _ready() -> void:
	_r = radius
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BONE_COLOR
	var half_gap := deg_to_rad(gap) * 0.5
	for i in walls:
		var ang := TAU * i / walls
		if absf(angle_difference(ang, 0.0)) < half_gap:
			continue  # the way out
		var piece := Node3D.new()
		for k in 3:
			var spike := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = randf_range(0.18, 0.26)
			cone.height = randf_range(1.2, 1.9)
			cone.radial_segments = 6
			cone.material = mat
			spike.mesh = cone
			spike.position = Vector3(randf_range(-0.25, 0.25), cone.height * 0.5, (k - 1) * 0.42)
			spike.rotation = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
			piece.add_child(spike)
		piece.scale = Vector3(1.0, 0.01, 1.0)
		add_child(piece)
		_pieces.append(piece)
		_angles.append(ang)

	# A faint red floor band under the ring shows where the walls are heading.
	_floor_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 48
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor_mat.albedo_color = Color(WARN_COLOR, 0.0)
	torus.material = _floor_mat
	_floor_ring.mesh = torus
	_floor_ring.position.y = 0.08
	_floor_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor_ring)

	_place()
	var tw := create_tween().set_parallel()
	for piece in _pieces:
		tw.tween_property(piece, "scale:y", 1.0, rise_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_floor_mat, "albedo_color:a", 0.45, rise_time)
	Fx.dust(get_parent(), global_position, 24, radius * 0.3)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t < rise_time:
		return
	var k := clampf((_t - rise_time) / close_time, 0.0, 1.0)
	_r = lerpf(radius, end_radius, k)
	gap_angle += deg_to_rad(spin) * delta
	_place()
	_check_walls()
	if k >= 1.0:
		_shut()


## Spread the pieces round the current radius, turned so the gap sits at gap_angle.
func _place() -> void:
	for i in _pieces.size():
		var ang := _angles[i] + gap_angle
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		_pieces[i].position = dir * _r
		_pieces[i].rotation.y = atan2(dir.x, dir.z)
	_floor_ring.scale = Vector3(_r, 0.02, _r)


func _player() -> Node3D:
	var p: Node3D = get_tree().get_first_node_in_group("player")
	return p if is_instance_valid(p) and not p.is_dead() else null


## A wall touching the hero (and not the gap) hurts them, once per cage.
func _check_walls() -> void:
	var p := _player()
	if p == null or _hit_done:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	if absf(to.length() - _r) > 0.55:
		return
	var ang := atan2(to.z, to.x)
	if absf(angle_difference(ang, gap_angle)) < deg_to_rad(gap) * 0.5:
		return  # slipping out through the gap
	_hurt(p, to)


func _hurt(p: Node3D, to: Vector3) -> void:
	var before: float = p.hp
	p.take_hit(damage, -to.normalized() * 8.0, source if is_instance_valid(source) else null)
	# A dash through the wall (i-frames) doesn't count as getting hit.
	_hit_done = p.hp < before


func _shut() -> void:
	_done = true
	Game.shake(0.4)
	Game.sfx("hit_big", -3.0, 0.05)
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, BONE_COLOR, 16, 6.0, 0.1, 0.3, Vector3.UP, 60.0)
	var p := _player()
	if p != null and not _hit_done:
		var to := p.global_position - global_position
		to.y = 0.0
		if to.length() <= end_radius + 0.4:
			p.take_hit(damage, to.normalized() * 6.0 + Vector3.UP * 4.0, source if is_instance_valid(source) else null)
	var tw := create_tween().set_parallel()
	for piece in _pieces:
		tw.tween_property(piece, "position:y", -2.0, 0.45).set_delay(0.25)
	tw.tween_property(_floor_mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
