extends SceneTree
## Boots to the title screen, starts a run, opens the pause menu and its
## Settings screen, and saves a frame of each. Run: godot --path . -s tests/menu_check.gd

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
	# Settings (from pause), then Esc should back out to the pause menu.
	var pause: Node = main.get_children().filter(func(n: Node) -> bool: return n.has_method("open_settings") and not n.has_signal("started"))[0]
	pause._buttons[1].pressed.emit()
	await create_timer(0.3).timeout
	_save("user://menu_settings.png")
	Input.parse_input_event(ev)
	await create_timer(0.3).timeout
	print("back in pause menu=", pause.is_open() and not pause.in_settings())
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _save(path: String) -> void:
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
