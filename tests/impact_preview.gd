extends SceneTree
## Renders the impact frame (impact_frame.gd) over a hero and a big hit on the
## fx_preview stage, as a windowed sheet: plain view, the frame at full
## strength, mid-fade, and the reduce-flashing pulse. Saves
## user://impact_preview.png. Run: godot --path . -s tests/impact_preview.gd

var F: GDScript  # loaded at runtime: it uses the Game autoload


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	game.reduce_flashing = false
	F = load("res://scripts/fx.gd")
	var stage: GDScript = load("res://tests/fx_preview.gd")
	var root3d: Node3D = stage._stage.call() if false else _stage()
	var hero: Node3D = load("res://assets/kaykit/characters/Barbarian.glb").instantiate()
	root3d.add_child(hero)
	var ap: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
	ap.play("2H_Melee_Attack_Chop")
	ap.seek(0.4, true)
	hero.position = Vector3(-1.5, 0, 0)
	hero.rotation.y = PI * 0.5
	F.impact(root3d, Vector3(1.2, 0.8, 0), Vector3(1, 0.3, 0), true)
	F.ring(root3d, Vector3(1.2, 0, 0), Color(1.0, 0.7, 0.3, 0.8), 2.2, 0.35)
	await create_timer(0.05).timeout
	await process_frame
	var fr: CanvasLayer = game.impact
	var shots: Array[Image] = []
	shots.append(get_root().get_texture().get_image())
	fr.flash(1.0)
	await process_frame
	await process_frame
	shots.append(get_root().get_texture().get_image())
	fr._start_ms = Time.get_ticks_msec() - int((fr.IMPACT_HOLD + fr.IMPACT_FADE * 0.5) * 1000.0)
	await process_frame
	await process_frame
	shots.append(get_root().get_texture().get_image())
	fr._strength = 0.0
	fr._last_ms = -100000
	game.reduce_flashing = true
	fr.flash(1.0)
	await process_frame
	await process_frame
	shots.append(get_root().get_texture().get_image())
	game.reduce_flashing = false
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var sheet := Image.create(w * 2, h * 2, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	sheet.save_png("user://impact_preview.png")
	print("saved ", ProjectSettings.globalize_path("user://impact_preview.png"))
	quit()


## Same look as the arena (fx_preview._stage).
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
