class_name Fx
## Small throwaway visual effects: damage numbers, hit sparks, flashes.

static var _flash_mat: StandardMaterial3D
static var _rim_mat: ShaderMaterial
## Tick time of the last big impact (read by the autotest to snap a frame).
static var last_big_hit_ms := 0
static var last_afterimage_ms := 0


static func damage_number(parent: Node, pos: Vector3, amount: float, big := false) -> void:
	var l := Label3D.new()
	l.text = str(roundi(amount))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 96 if big else 64
	l.outline_size = 18
	l.pixel_size = 0.006
	l.modulate = Color(1.0, 0.85, 0.3) if big else Color.WHITE
	l.outline_modulate = Color(0.1, 0.05, 0.1)
	parent.add_child(l)
	var jitter := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.2, 0.2))
	l.global_position = pos + Vector3.UP * 2.2 + jitter
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


static func hit_spark(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.6), size := 0.9) -> void:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * 1.1
	m.scale = Vector3.ONE * 0.2
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3.ONE * size, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14).set_delay(0.04)
	tw.chain().tween_callback(m.queue_free)


## One-shot particle burst. `dir` biases the spray (e.g. knockback direction).
static func burst(parent: Node, pos: Vector3, color: Color, amount := 14, speed := 7.0,
		size := 0.12, lifetime := 0.3, dir := Vector3.UP, spread := 70.0, gravity := -12.0,
		radius := 0.0) -> void:
	# CPU particles: no shader compile hitch on first spawn, cheap at these counts.
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = true  # emitter never moves; world-space emission misplaces the first burst
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, gravity, 0.0)
	p.damping_min = speed * 0.6
	p.damping_max = speed * 1.2
	if radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = parent.to_local(pos) if parent is Node3D else pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func impact(parent: Node, pos: Vector3, dir: Vector3, big := false) -> void:
	var at := pos + Vector3.UP * 1.1
	burst(parent, at, Color(1.0, 0.6, 0.15), 24 if big else 14, 14.0 if big else 10.0, 0.22, 0.35, dir, 50.0)
	burst(parent, at, Color(1.0, 0.97, 0.85), 8 if big else 4, 18.0, 0.18, 0.2, dir, 30.0, 0.0)
	if big:
		last_big_hit_ms = Time.get_ticks_msec()


static func dust(parent: Node, pos: Vector3, amount := 10, size := 0.45) -> void:
	burst(parent, pos + Vector3.UP * 0.2, Color(0.62, 0.57, 0.5, 0.6), amount, 4.0, size, 0.55, Vector3.UP, 80.0, 1.0, 0.45)


## Expanding flat ring on the ground (shockwaves, Awakening burst).
static func ring(parent: Node, pos: Vector3, color: Color, radius: float, time := 0.35) -> void:
	var m := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.material = mat
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * 0.15
	m.scale = Vector3(0.3, 0.05, 0.3)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(radius, 0.05, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time * 0.6).set_delay(time * 0.4)
	tw.chain().tween_callback(m.queue_free)


## Frozen translucent copy of a (skinned) model in its current pose.
static func afterimage(parent: Node, model: Node3D, color: Color, time := 0.25) -> void:
	if DisplayServer.get_name() == "headless":
		return  # the dummy renderer has no skeletons to bake from
	last_afterimage_ms = Time.get_ticks_msec()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var ghost := Node3D.new()
	parent.add_child(ghost)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var flashing := _flash_mat != null and mi.material_overlay == _flash_mat
		if not mi.is_visible_in_tree() or mi.mesh == null or flashing:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mi.bake_mesh_from_current_skeleton_pose() if mi.skin else mi.mesh
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
	var tw := ghost.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, time)
	tw.tween_callback(ghost.queue_free)


## Briefly paint every mesh under `root` white.
static func flash(root: Node, duration := 0.08) -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_color = Color(1, 1, 1, 0.85)
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = _flash_mat
	await root.get_tree().create_timer(duration, true, false, true).timeout
	for mi in meshes:
		if is_instance_valid(mi) and mi.material_overlay == _flash_mat:
			mi.material_overlay = null


## Drop cached materials so nothing is left alive at exit.
static func release() -> void:
	_flash_mat = null
	_rim_mat = null


static func rim_material() -> ShaderMaterial:
	if _rim_mat == null:
		_rim_mat = ShaderMaterial.new()
		_rim_mat.shader = load("res://shaders/rim_glow.gdshader")
	return _rim_mat
