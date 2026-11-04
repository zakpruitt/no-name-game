extends SceneTree
## Enemy attack telegraphs mid-windup: one melee skeleton per windup stage
## (25 / 50 / 75 / 95 %), frozen, saved to user://telegraph_preview.png.
## The rim should sit at full reach the whole time while the fill grows to it.
## Run: godot --path . -s tests/telegraph_preview.gd

const STAGES := [0.25, 0.5, 0.75, 0.95]


func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	main.clear_room()
	main.player.set_physics_process(false)
	var kind: String = main.ENEMY_TYPES.keys()[0]
	var spawned: Array = []
	for i in STAGES.size():
		var spot: Vector3 = main.player.global_position + Vector3((i - 1.5) * 4.5, 0.0, 4.0)
		spawned.append(main._spawn(kind, false, spot))
	await create_timer(1.3).timeout
	for i in spawned.size():
		var e: Node = spawned[i]
		e._set_state(e.State.WINDUP)
		e._state_t = e.attack_windup * STAGES[i]
		e._state_windup(0.0)
		e.set_physics_process(false)
	await create_timer(0.1).timeout
	get_root().get_texture().get_image().save_png("user://telegraph_preview.png")
	print("saved ", ProjectSettings.globalize_path("user://telegraph_preview.png"), " kind=", kind)
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()
