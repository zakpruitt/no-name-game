extends SceneTree
## The hero's weapon trail mid-swing, from the game's camera angle (zoomed in):
## one shot per move in SWINGS, tiled into user://trail_preview.png.
## Run: godot --path . -s tests/trail_preview.gd [-- --awakened]

const SWINGS := [
	["1H_Melee_Attack_Slice_Diagonal", 0.45],
	["2H_Melee_Attack_Spin", 0.55],
	["Dualwield_Melee_Attack_Chop", 0.5],
	["2H_Melee_Attack_Chop", 0.6],
]


func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	var awakened := "--awakened" in OS.get_cmdline_user_args()
	var shots: Array[Image] = []
	for swing: Array in SWINGS:
		var root3d := _stage()
		var player: Node3D = load("res://scripts/player.gd").new()
		root3d.add_child(player)
		player.set_physics_process(false)
		if awakened:
			player._set_awakened(true)
		await process_frame
		player.anim.play(swing[0])
		for trail in player._trails:
			trail.emitting = true
		# Step the swing in real frames so the trail samples the motion.
		var t := 0.0
		while t < swing[1]:
			await process_frame
			t += 1.0 / 60.0
		player.anim.speed_scale = 0.0
		for trail in player._trails:
			trail.set_process(false)  # freeze the ribbon as it was
		await process_frame
		await process_frame
		shots.append(get_root().get_texture().get_image())
		root3d.queue_free()
		await process_frame
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var sheet := Image.create(w * 2, h * 2, false, shots[0].get_format())
	for i in shots.size():
		shots[i].resize(w, h)
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i % 2 * w, i / 2 * h))
	sheet.save_png("user://trail_preview.png")
	print("saved ", ProjectSettings.globalize_path("user://trail_preview.png"))
	quit()


func _stage() -> Node3D:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
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
	cam.look_at_from_position(Vector3(0, 6.5, 4.8), Vector3(0, 0.8, 0), Vector3.UP)
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
