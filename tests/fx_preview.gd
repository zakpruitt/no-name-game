extends SceneTree
## Renders each Fx effect in isolation and saves a screenshot.
## Run: godot --path . -s tests/fx_preview.gd

func _initialize() -> void:
	await process_frame
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 6, 5), Vector3(0, 1, 0), Vector3.UP)
	var light := DirectionalLight3D.new()
	root3d.add_child(light)
	light.rotation_degrees = Vector3(-50, -30, 0)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mesh.mesh = pm
	root3d.add_child(floor_mesh)
	Fx.impact(root3d, Vector3(-1.5, 0, 0), Vector3(1, 0.3, 0), true)
	Fx.impact(root3d, Vector3(1.5, 0, 0), Vector3(-1, 0.3, 0), false)
	Fx.dust(root3d, Vector3(0, 0, 1.5), 14, 0.6)
	await create_timer(0.12).timeout
	await process_frame
	get_root().get_texture().get_image().save_png("user://fx_preview.png")
	print("saved ", ProjectSettings.globalize_path("user://fx_preview.png"))
	quit()
