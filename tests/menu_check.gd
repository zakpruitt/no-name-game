extends SceneTree
## Boots to the title screen, starts a run, opens the pause menu and its
## Settings screen, then the run map mid-run (choosing room 5), and saves a
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
	# RECENT RUNS (sample lines, nothing saved): right arrow moves focus into it.
	title_menu.build_recent([{"victory": false, "room": 4, "rank": "B", "seed": 7, "daily": ""}])
	await create_timer(0.2).timeout
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	Input.parse_input_event(right)
	await create_timer(0.1).timeout
	var focused := get_root().gui_get_focus_owner()
	print("recent focus=", focused is Button and focused.flat)
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
	pause._buttons[2].pressed.emit()  # Settings (Map is [1])
	await create_timer(0.3).timeout
	_save("user://menu_settings.png")
	Input.parse_input_event(ev)
	await create_timer(0.3).timeout
	print("back in pause menu=", pause.is_open() and not pause.in_settings())
	# The map, four rooms in, choosing the fifth.
	pause.close_menu()
	var run_map_script: GDScript = load("res://scripts/run_map.gd")
	var route: Array = [main.map_route[0]]
	for i in 3:
		route.append(Vector2i(route[-1].x + 1, run_map_script.next_nodes(main.run_map, route[-1])[-1].lane))
	main.map_menu.open(main.run_map, route, run_map_script.next_nodes(main.run_map, route[-1]), false,
		{"light": 2, "heavy": 1, "dash": 0, "awaken": 0, "soul": 0})
	await create_timer(0.4).timeout
	_save("user://menu_map.png")
	main.map_menu.pick(0)
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _save(path: String) -> void:
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
