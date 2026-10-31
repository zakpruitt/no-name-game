class_name Fx
## Small throwaway visual effects: damage numbers, hit sparks, flashes.

static var _flash_mat: StandardMaterial3D
static var _rim_mat: ShaderMaterial


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


static func rim_material() -> ShaderMaterial:
	if _rim_mat == null:
		_rim_mat = ShaderMaterial.new()
		_rim_mat.shader = load("res://shaders/rim_glow.gdshader")
	return _rim_mat
