extends SceneTree
## The shaman's elements side by side, from the game's camera angle: one
## screenshot per element of the casts (bolt, pillar, nova, fissure, vortex,
## orbit) and one of the ultimate impacts (SKY, RUSH wake, Trinity strike).
## Saves user://element_<el>.png and user://element_<el>_ult.png, and the
## 2x2 sheets user://element_sheet.png and user://element_ult_sheet.png.
## Run: godot --path . -s tests/element_preview.gd [-- --only=earth]

var E: GDScript  # loaded at runtime: it uses the Game autoload


func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	E = load("res://scripts/elements.gd")
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	for el: String in E.LOOK:
		if only != "" and el != only:
			continue
		await _shot(el, false)
		await _shot(el, true)
	if only == "":
		for suffix: String in ["", "_ult"]:
			_sheet(suffix)
	quit()


## Tile the four elements' shots 2x2 at half size.
func _sheet(suffix: String) -> void:
	var sheet: Image = null
	var i := 0
	for el: String in E.LOOK:
		var img := Image.load_from_file(ProjectSettings.globalize_path("user://element_%s%s.png" % [el, suffix]))
		img.resize(img.get_width() / 2, img.get_height() / 2)
		if sheet == null:
			sheet = Image.create(img.get_width() * 2, img.get_height() * 2, false, img.get_format())
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i % 2 * img.get_width(), i / 2 * img.get_height()))
		i += 1
	var path := "user://element%s_sheet.png" % suffix
	sheet.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _stage() -> Node3D:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	# Same as main._build_environment().
	env.environment.background_color = Color(0.05, 0.05, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.8)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.6
	env.environment.glow_bloom = 0.05
	root3d.add_child(env)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 42.0
	cam.look_at_from_position(Vector3(0, 13, 9.5), Vector3.ZERO, Vector3.UP)
	var light := DirectionalLight3D.new()
	root3d.add_child(light)
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.shadow_enabled = true
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.78, 0.7, 0.64)
	floor_mesh.material_override = fm
	root3d.add_child(floor_mesh)
	return root3d


func _shot(el: String, ult: bool) -> void:
	var root3d := _stage()
	var player: Node3D = load("res://scripts/player.gd").new()
	root3d.add_child(player)
	player.set_physics_process(false)
	if el != "spirit":
		player.ascend(el)
	player._set_awakened(true)
	player.anim.play("2H_Melee_Idle")
	await process_frame
	if not ult:
		player.position = Vector3(0, 0, 1.0)
		for i in 3:
			var b: Node3D = E.Bolt.new()
			b.el = el
			b.dir = Vector3(-1, 0, 0).rotated(Vector3.UP, (i - 1) * 0.38)
			b.speed = 0.0001
			b.size = 1.3
			root3d.add_child(b)
			b.global_position = Vector3(-2.5, 0.25 if el == "earth" else 1.0, 1.0) + b.dir * 0.8
		E.pillar(root3d, Vector3(4.5, 0, 1.5), el, 4.0, 1.5, 3.0)
		E.nova(root3d, Vector3(0, 0, -3.5), el, 3.0, 8)
		E.fissure(root3d, Vector3(-4.5, 0, 2.5), Vector3(0.6, 0, 0.8).normalized(), 5.0, 5, el)
		E.vortex(player, el, 3.0, 3.0)
		await create_timer(0.22).timeout
	else:
		E.sky_impact(root3d, Vector3(-3.5, 0, 0), el, 4.8)
		E.rush_wake(root3d, Vector3(2.0, 0, 3.5), Vector3(0.3, 0, -1).normalized(), 7.0, el)
		E.storm_strike(root3d, Vector3(5.5, 0, 2.5), el)
		if el == "earth":
			E.meteor(root3d, Vector3(5.5, 0, -2.5), 0.6)
		player.position = Vector3(1.0, 0, -4)
		await create_timer(0.3).timeout
	var path := "user://element_%s%s.png" % [el, "_ult" if ult else ""]
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
	root3d.queue_free()
	await process_frame
