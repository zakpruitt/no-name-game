extends SceneTree
## Training mode: the game boots straight into it. Checks
## the dummy takes hits without dying or fighting back, that a dropped combo
## records the string, and that the pause menu's Fill Awakening and
## Ascend work. Prints [training] PASS/FAIL; windowed it also saves
## user://training_room.png and user://training_pause.png.
## Run: godot --headless --path . -s tests/training_check.gd

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.5).timeout
	_check(main.training and main.room_kind == "training", "boots into training")
	var dummy: Node = main._dummy
	_check(is_instance_valid(dummy) and dummy.is_alive(), "the dummy stands")
	_check(main._dummies.size() == main.DUMMY_SPOTS.size(), "a few of them (%d)" % main._dummies.size())
	for d: Node in main._dummies:
		_check(is_instance_valid(d) and d.is_alive() and d.global_position.distance_to(d.home) < 0.8, "each stands on its spot, clear of the walls")
	# Far more damage than its HP, in one go and spread over hits: it lives.
	for i in 6:
		dummy.take_hit(400.0, Vector3(0, 0, -2), 0.0, true)
		await create_timer(0.15).timeout
	_check(dummy.is_alive() and dummy.hp > 0.0, "the dummy can't die")
	_check(main._string.y == 6.0 and main._string.x >= 2400.0, "hits add to the string (%s)" % main._string)
	game.combo_changed.emit(0, "D")
	_check(main._last_string.y == 6.0 and main._best_string >= 2400.0 and main._string == Vector2.ZERO,
		"a dropped combo records the string")
	# A long juggle (a launcher every frame) never lifts it past MAX_HEIGHT.
	var top := 0.0
	for i in 60:
		dummy.take_hit(1.0, Vector3.ZERO, 9.0, true)
		await physics_frame
		top = maxf(top, dummy.global_position.y)
	_check(top <= dummy.MAX_HEIGHT + 0.2, "a juggle stays under %s m (%.2f)" % [dummy.MAX_HEIGHT, top])
	await create_timer(1.5).timeout
	# A launch, then it walks home and never winds up.
	dummy.take_hit(5.0, Vector3(0, 0, -6), 9.0, true)
	await create_timer(4.0).timeout
	_check(dummy.global_position.distance_to(dummy.home) < 0.8, "the dummy walks back home")
	_check(dummy.state != dummy.State.WINDUP and main.player.hp == main.player.max_hp, "the dummy never attacks")
	_check(dummy.hp == dummy.max_hp, "the dummy refills when left alone")
	_save("user://training_room.png")
	# Pause menu: training items.
	var pause: Node = main.get_children().filter(func(n: Node) -> bool:
		return n.has_method("_build_moves"))[0]
	pause._open()
	await create_timer(0.4).timeout
	var labels: Array = pause._buttons.map(func(b: Button) -> String: return b.text)
	_check("Fill Awakening" in labels and "Ascend" not in labels and "Restart training" in labels, "training pause menu (%s)" % ", ".join(labels))
	_save("user://training_pause.png")
	pause._buttons[labels.find("Fill Awakening")].pressed.emit()
	_check(game.awakening >= game.AWAKEN_MAX, "Fill Awakening fills the meter")
	print("[training] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		push_error("training_check: " + what)


func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
