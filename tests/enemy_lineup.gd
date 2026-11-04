extends SceneTree
## Spawns one of each ENEMY_TYPES entry in a row in front of the hero, freezes
## them once they've risen, and saves user://enemy_lineup.png (for checking
## how the skeleton types read apart). Run: godot --path . -s tests/enemy_lineup.gd

func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false  # don't use up the player's first-run hints
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	main.clear_room()
	var kinds: Array = main.ENEMY_TYPES.keys()
	var spawned: Array = []
	var spots: Array = []
	for i in kinds.size():
		spots.append(main.player.global_position + Vector3((i - (kinds.size() - 1) * 0.5) * 2.2, 0.0, 3.0))
		spawned.append(main._spawn(kinds[i], false, spots[i]))
	await create_timer(1.3).timeout
	for i in spawned.size():
		var e: Node3D = spawned[i]
		e.set_physics_process(false)
		e.global_position = spots[i]
		e.model.rotation.y = 0.0  # face the camera (models face +Z, the camera)
		e.anim.play("Idle_Combat")
	await create_timer(0.4).timeout
	get_root().get_texture().get_image().save_png("user://enemy_lineup.png")
	print("saved ", ProjectSettings.globalize_path("user://enemy_lineup.png"), " kinds=", kinds)
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()
