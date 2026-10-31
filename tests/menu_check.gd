extends SceneTree
## Boots to the title screen, starts a run, opens the pause menu, and saves
## a frame of each. Run: godot --path . -s tests/menu_check.gd

func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false  # don't use up the player's first-run hints
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.6).timeout
	_save("user://menu_title.png")
	var title: Node = main.get_children().filter(func(n: Node) -> bool: return n.has_signal("started"))[0]
	title._start()
	await create_timer(1.5).timeout
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(0.4).timeout
	print("paused=", paused)
	_save("user://menu_pause.png")
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _save(path: String) -> void:
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
