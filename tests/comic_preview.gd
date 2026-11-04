extends SceneTree
## Windowed look check for Game.comic_style, written before anyone could run it:
## one of each enemy type plus the Warden in the real room, camera and lighting,
## then combat text at each chain tier. Compare with
## vendor_src/shaman_redesign/comic_poc/out/enemies/lineup_game.png.
##   godot --path . -s tests/comic_preview.gd
## Saves user://comic_lineup.png and comic_words.png.
## Check: hard cut tones, fixed-size dots at any distance, hatching in shadow, stepped
## glow, thick ink, hard cast shadows up and right, enemies facing the camera.

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("[comic_preview] needs a window: nothing rendered")
		quit()
		return
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false  # don't use up the player's first-run hints
	game._comic_cli = true  # as --comic: never saved
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	main.clear_room()
	await _lineup(main)
	await _text(main, game)
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _lineup(main: Node) -> void:
	var kinds: Array = main.ENEMY_TYPES.keys()
	var spawned: Array = []
	var spots: Array = []
	for i in kinds.size():
		spots.append(main.player.global_position + Vector3((i - (kinds.size() - 1) * 0.5) * 2.4, 0.0, 3.0))
		spawned.append(main._spawn(kinds[i], false, spots[i]))
	main._spawn_boss()
	var boss: Node3D = null
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_boss") and e.is_boss():
			boss = e
	await create_timer(1.3).timeout
	for i in spawned.size():
		var e: Node3D = spawned[i]
		e.set_physics_process(false)
		e.global_position = spots[i]
		e.model.rotation.y = 0.0  # models face +Z, the camera's side
		e.anim.play("Idle_Combat")
	if boss != null:
		boss.set_physics_process(false)
		boss.global_position = main.player.global_position + Vector3(0.0, 0.0, -5.0)
		boss.model.rotation.y = 0.0
		boss.anim.play("Idle_Combat")
	await create_timer(0.4).timeout
	_shot("user://comic_lineup.png")


func _text(main: Node, game: Node) -> void:
	var fx: Node = main.get_children().filter(func(n: Node) -> bool: return n is CanvasLayer and n.has_method("_word"))[0]
	for tier in 4:
		fx._last_word_ms = -100000
		fx._word(main.player.global_position + Vector3((tier - 1.5) * 4.0, 0.0, 2.0), tier)
	await create_timer(0.2).timeout
	_shot("user://comic_words.png")


func _shot(path: String) -> void:
	get_root().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
