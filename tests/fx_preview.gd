extends SceneTree
## Renders the shared Fx effects in isolation, from the game's camera angle,
## and saves a screenshot: big and small impact, hit spark, ground rings,
## dust and afterimages.
## Run: godot --path . -s tests/fx_preview.gd [-- --at=0.06]
## (--at = seconds after spawning to take the shot; flares peak ~0.06s.)

var F: GDScript  # loaded at runtime: it uses the Game autoload


func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	F = load("res://scripts/fx.gd")
	var at := 0.06
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			at = a.get_slice("=", 1).to_float()
	var root3d := _stage()
	if "--swoosh" in OS.get_cmdline_user_args():
		# Melee arcs as the moves use them: L1 (2.4 m, 140°), CH (3.4 m, 160°, big),
		# H spin (3.2 m, 360°), DL (2.8 m, 90°); spirit teal and earth orange.
		var c := Color(0.3, 0.95, 0.85, 0.85)
		F.swoosh(root3d, Vector3(-4.5, 0, 0), Vector3.BACK, 2.4 * 0.9, 140.0, c, false, 0.24)
		F.swoosh(root3d, Vector3(0.0, 0, 0), Vector3.BACK, 3.4 * 0.9, 160.0, Color(1.0, 0.38, 0.08, 0.9), true, 0.32)
		F.swoosh(root3d, Vector3(4.8, 0, 0), Vector3.BACK, 3.2 * 0.9, 360.0, c, false, 0.24)
		F.swoosh(root3d, Vector3(0.0, 0, 3.6), Vector3.LEFT, 2.8 * 0.9, 90.0, c, false, 0.24)
		await create_timer(at).timeout
		await process_frame
		get_root().get_texture().get_image().save_png("user://fx_preview.png")
		print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
		quit()
		return
	if "--shots" in OS.get_cmdline_user_args():
		# Enemy shots in flight: caster orb (purple) and archer bolt, plus a pop.
		var P: GDScript = load("res://scripts/projectile.gd")
		for i in 2:
			var shot: Node3D = P.new()
			shot.bolt = i == 1
			shot.direction = Vector3.RIGHT
			if i == 1:
				shot.color = Color(1.0, 0.35, 0.2)
			root3d.add_child(shot)
			shot.global_position = Vector3(-4.0 + i * 5.0, 1.0, 0)
			shot.set_physics_process(false)
			var tw := shot.create_tween()  # slide it along so the trail shows
			tw.tween_property(shot, "global_position:x", shot.global_position.x + 2.0, 0.25)
		await create_timer(0.24).timeout
		var pop: Node3D = P.new()
		root3d.add_child(pop)
		pop.global_position = Vector3(5.0, 1.0, 2.5)
		pop.set_physics_process(false)
		pop._pop()
		await create_timer(maxf(at, 0.05)).timeout
		await process_frame
		get_root().get_texture().get_image().save_png("user://fx_preview.png")
		print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
		quit()
		return
	if "--awaken" in OS.get_cmdline_user_args():
		# Awakening activation: base (spirit) colour, and earth's for comparison.
		F.awaken_burst(root3d, Vector3(-3.5, 0, 0), Color(1.0, 0.55, 0.15), 5.0)
		F.awaken_burst(root3d, Vector3(3.5, 0, 0), Color(0.5, 1.0, 0.55), 5.0)
		await create_timer(at).timeout
		await process_frame
		get_root().get_texture().get_image().save_png("user://fx_preview.png")
		print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
		quit()
		return
	if "--dash" in OS.get_cmdline_user_args():
		# A dash left to right (spirit teal) and a perfect dodge's burst on the right.
		var c := Color(0.3, 0.95, 0.85)
		var hero: Node3D = load("res://assets/kaykit/characters/Barbarian.glb").instantiate()
		root3d.add_child(hero)
		var ap: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
		ap.play("Dodge_Forward")
		ap.seek(0.2, true)
		hero.rotation.y = PI * 0.5
		for i in 4:
			hero.position = Vector3(-6.0 + i * 0.9, 0, 0)
			await process_frame
			F.afterimage(root3d, hero, Color(c, 0.45), 5.0)
		hero.position = Vector3(-2.2, 0, 0)
		# After the ghosts: their first bakes are slow and the streak only lives 0.3 s.
		F.dash_streak(root3d, Vector3(-6.0, 0, 0), Vector3.RIGHT, 24.0 * 0.16 + 0.8, Color(c, 0.8))
		var spot := Vector3(3.5, 0, 0)
		F.ring(root3d, spot, Color(0.5, 0.85, 1.0, 0.9), 4.0, 0.4)
		F.ring(root3d, spot, Color(0.25, 0.6, 1.0, 0.9), 2.2, 0.3)
		F.flare(root3d, spot + Vector3.UP * 1.0, Color(0.35, 0.75, 1.0), 9.0, 0.35, "flare")
		F.burst(root3d, spot + Vector3.UP * 0.8, Color(0.6, 0.9, 1.0), 20, 9.0, 0.14, 0.4, Vector3.UP, 180.0, 0.0, 0.0, "dot", true)
		await create_timer(at).timeout
		await process_frame
		get_root().get_texture().get_image().save_png("user://fx_preview.png")
		print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
		quit()
		return
	if "--death" in OS.get_cmdline_user_args():
		# Enemy kills: normal and elite, then the corpse's soul wisp.
		F.death(root3d, Vector3(-3.5, 0, 0), Vector3(1, 0, 0.3) * 6.0, false)
		F.death(root3d, Vector3(1.0, 0, 0), Vector3(-1, 0, 0.3) * 6.0, true, Color(1.0, 0.85, 0.45))
		F.soul(root3d, Vector3(4.5, 0, 0))
		await create_timer(at).timeout
		await process_frame
		get_root().get_texture().get_image().save_png("user://fx_preview.png")
		print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
		quit()
		return
	# Afterimages: pose a hero mid-dodge and leave ghosts along a line.
	var hero: Node3D = load("res://assets/kaykit/characters/Barbarian.glb").instantiate()
	root3d.add_child(hero)
	var ap: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
	ap.play("Dodge_Forward")
	ap.seek(0.2, true)
	hero.rotation.y = PI * 0.5
	for i in 3:
		hero.position = Vector3(-6.5 + i * 0.6, 0, -2.5)
		await process_frame
		F.afterimage(root3d, hero, Color(0.55, 0.8, 1.0, 0.4), 5.0)
	hero.position = Vector3(-4.5, 0, -2.5)
	F.impact(root3d, Vector3(-3.0, 0, 0), Vector3(1, 0.3, 0), true)
	F.impact(root3d, Vector3(0.0, 0, 0), Vector3(-1, 0.3, 0), false)
	F.hit_spark(root3d, Vector3(3.0, 0, 0), Color(0.6, 0.85, 1.0), 1.0)
	F.ring(root3d, Vector3(-3.0, 0, 3.2), Color(1.0, 0.7, 0.3, 0.8), 2.2, 0.35)
	F.ring(root3d, Vector3(2.5, 0, 3.2), Color(0.5, 0.85, 1.0, 0.8), 2.2, 0.35)
	F.dust(root3d, Vector3(4.5, 0, -2.5), 14, 0.6)
	await create_timer(at).timeout
	await process_frame
	get_root().get_texture().get_image().save_png("user://fx_preview.png")
	print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
	quit()


## Same look as the arena: dark background, filmic tonemap, glow, light floor.
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
