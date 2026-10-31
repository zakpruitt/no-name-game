extends SceneTree
## Boots to the title screen, starts a run, opens the pause menu and its
## Settings screen, then the door choice with an elite twist, and saves a
## frame of each. Run: godot --path . -s tests/menu_check.gd

func _initialize() -> void:
	await process_frame
	get_root().get_node("Game").save_hints = false  # don't use up the player's first-run hints
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.6).timeout
	_save("user://menu_title.png")
	# The bone altar (read-only here: nothing is bought).
	var title_menu: Node = main.get_children().filter(func(n: Node) -> bool: return n.has_signal("started"))[0]
	title_menu.open_altar()
	await create_timer(0.3).timeout
	_save("user://menu_altar.png")
	title_menu.open()
	await create_timer(0.2).timeout
	var title: Node = main.get_children().filter(func(n: Node) -> bool: return n.has_signal("started"))[0]
	title._start()
	await create_timer(1.5).timeout
	# A few powers so the pause menu's build panel has something to list,
	# including an active synergy (Skybreaker + Quake = Tremor).
	main.player.add_upgrade("ember_cleave")
	main.player.add_upgrade("skybreaker")
	main.player.add_upgrade("skybreaker")
	main.player.add_upgrade("quake")
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
	# Door choice with a late elite's two twists (the longest door text).
	pause.close_menu()
	var twists := ["volatile", "hasted"]
	main.path_menu.open(["fight", "elite"], 6, main._twist_text(twists, "name", " + "), main._twist_text(twists, "desc", ", "))
	await create_timer(0.3).timeout
	_save("user://menu_path.png")
	main.path_menu.close_menu()
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _save(path: String) -> void:
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
