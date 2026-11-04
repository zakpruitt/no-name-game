extends SceneTree
## Enemy hit reactions, one skeleton each in a row in front of the hero, caught
## mid-reaction: a tap's lean, a big hit's lean + squash, a launch mid-tumble
## near its apex, a knockdown lying flat after its bounce, a side launch
## rolling, and a downward hit pancaked into its crater. Windowed:
## saves user://enemy_feel.png. Run: godot --path . -s tests/enemy_feel_preview.gd
## `-- --bag`: three training dummies instead (just tapped, swinging back past
## upright, shaking off a daze under stars) -> user://enemy_feel_bag.png.


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(0.3).timeout
	main.clear_room()
	main.player.bot_enabled = true
	for old in main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	if "--bag" in OS.get_cmdline_user_args():
		await _bag(main)
		game.stop_all_sfx()
		await create_timer(0.2).timeout
		quit()
		return
	var row: Vector3 = main.player.global_position + Vector3(0.0, 0.0, 3.5)
	var foes: Array = []
	for i in 6:
		var e: Node = main._spawn("minion", false, row + Vector3(i * 1.8 - 4.5, 0.0, 0.0))
		e.max_hp = 2000.0
		e.hp = 2000.0
		foes.append(e)
	await create_timer(1.1).timeout
	for e in foes:
		e.move_speed = 0.0
		e.attack_damage = 0.0
		e.model.rotation.y = PI
	var kb := Vector3(0.0, 0.0, 6.0)
	foes[3].take_hit(1.0, Vector3(0.0, 0.0, -6.0), 9.0, true)  # lands and lies flat by the shot, in frame
	await create_timer(1.9).timeout
	foes[2].take_hit(1.0, kb, 9.0, true)  # near its apex, tumbling
	foes[4].take_hit(1.0, Vector3(6.0, 0.0, 0.0), 9.0, true)  # rolling sideways near its apex
	await create_timer(0.4).timeout
	foes[5].take_hit(1.0, Vector3(0.0, -6.0, 0.0), 0.0, true)  # spiked on the floor: crater (its own wave)
	await create_timer(0.15).timeout
	foes[0].take_hit(1.0, kb, 0.0, false)
	foes[1].take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	await create_timer(0.06).timeout
	if DisplayServer.get_name() != "headless":
		get_root().get_texture().get_image().save_png("user://enemy_feel.png")
		print("saved ", ProjectSettings.globalize_path("user://enemy_feel.png"))
	print("[enemy_feel_preview] tap lean x=%.2f  big lean z=%.2f scale=%.2f  air y=%.2f tumble=%.2f  down state=%d squash=%.2f  roll y=%.2f z=%.2f  crater scale=%.2f" % [
		foes[0].model.rotation.x, foes[1].model.rotation.z, foes[1].model.scale.y,
		foes[2].global_position.y, foes[2].model.rotation.x, foes[3].state, foes[3].last_squash.y,
		foes[4].global_position.y, foes[4].model.rotation.z, foes[5].model.scale.y])
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _bag(main: Node) -> void:
	var row: Vector3 = main.player.global_position + Vector3(0.0, 0.0, 3.5)
	var bags: Array = []
	for i in 3:
		var d: Node = load("res://scripts/training_dummy.gd").new()
		d.model_scene = main._model("Skeleton_Warrior")
		main.add_child(d)
		d.home = row + Vector3(i * 2.4 - 2.4, 0.0, 0.0)
		d.global_position = d.home
		bags.append(d)
	await create_timer(2.2).timeout  # past the TRAINING banner
	bags[2].hp = bags[2].max_hp - 10.0
	bags[2].last_hit_ms = -100000  # refills next frame: the shake-off
	bags[1].take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	await create_timer(0.2).timeout  # about half a swing: past upright the other way
	bags[0].take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	await create_timer(0.03).timeout
	if DisplayServer.get_name() != "headless":
		get_root().get_texture().get_image().save_png("user://enemy_feel_bag.png")
		print("saved ", ProjectSettings.globalize_path("user://enemy_feel_bag.png"))
	print("[enemy_feel_preview] bag tip z=%.2f scale=%.2f  swing z=%.2f  shake z=%.2f stars=%s" % [
		bags[0].model.rotation.z, bags[0].model.scale.y, bags[1].model.rotation.z, bags[2].model.rotation.z,
		bags[2].find_child("DazeStars", false, false) != null])
