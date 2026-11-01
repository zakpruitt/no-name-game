extends SceneTree
## Close-up of the hero for look changes: front and back, then Awakened in
## each Ascendancy (base, wind, earth, water). Saves user://hero_preview.png.
## Run: godot --path . -s tests/hero_preview.gd

func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.14, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root3d.add_child(env)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 32.0
	cam.look_at_from_position(Vector3(0, 3.4, 12.5), Vector3(0, 1.0, 0), Vector3.UP)
	var light := DirectionalLight3D.new()
	root3d.add_child(light)
	light.rotation_degrees = Vector3(-40, 25, 0)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mesh.mesh = pm
	root3d.add_child(floor_mesh)
	var player_s: GDScript = load("res://scripts/player.gd")
	var looks := [["", false, 0.0], ["", false, PI], ["", true, 0.0], ["wind", true, 0.0], ["earth", true, 0.0], ["water", true, 0.0]]
	for i in looks.size():
		var p: Node3D = player_s.new()
		root3d.add_child(p)
		p.position = Vector3((i - (looks.size() - 1) * 0.5) * 1.75, 0, 0)
		p.set_physics_process(false)
		p.model.rotation.y = looks[i][2]
		if looks[i][0] != "":
			p.ascend(looks[i][0])
		if looks[i][1]:
			p._set_awakened(true)
		p.anim.play("2H_Melee_Idle")
	await create_timer(0.8).timeout
	get_root().get_texture().get_image().save_png("user://hero_preview.png")
	print("saved ", ProjectSettings.globalize_path("user://hero_preview.png"))
	quit()
