extends SceneTree
## Parks the hero just behind a near pillar and saves a frame, to check the
## pillar fades. Run: godot --path . -s tests/occlusion_check.gd

func _initialize() -> void:
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	main.player.global_position = Vector3(-8, 0, 5)
	await create_timer(0.8).timeout
	get_root().get_texture().get_image().save_png("user://occlusion_check.png")
	print("saved ", ProjectSettings.globalize_path("user://occlusion_check.png"))
	quit()
