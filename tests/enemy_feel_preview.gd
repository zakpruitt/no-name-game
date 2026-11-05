extends SceneTree
## Enemy hit reactions, one skeleton each in a row in front of the hero, caught
## mid-reaction: a tap's lean, a big hit's lean + squash, a launch mid-tumble
## near its apex, a knockdown lying flat after its bounce, a side launch
## rolling, and a downward hit pancaked into its crater. Windowed:
## saves user://enemy_feel.png. Run: godot --path . -s tests/enemy_feel_preview.gd
## `-- --bag`: three training dummies instead (just tapped, swinging back past
## upright, shaking off a daze under stars) -> user://enemy_feel_bag.png; a fourth shows its last-string tag.
## `-- --slams`: Deep Freeze, Meteor Fall and Maw run for real on a minion each (each craters), then the
## Warden taking a big hit (flash, ink, small squash), one at a time -> user://enemy_feel_slams_<move>.png.


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
	if "--slams" in OS.get_cmdline_user_args():
		await _slams(main)
		game.stop_all_sfx()
		await create_timer(0.2).timeout
		quit()
		return
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
	print("[enemy_feel_preview] tap lean x=%.2f  big lean z=%.2f scale=%.2f  air y=%.2f tumble=%.2f  down state=%d squash=%.2f  roll y=%.2f z=%.2f  crater scale=%.2f  ink tap %.2f big %.2f px" % [
		foes[0].model.rotation.x, foes[1].model.rotation.z, foes[1].model.scale.y,
		foes[2].global_position.y, foes[2].model.rotation.x, foes[3].state, foes[3].last_squash.y,
		foes[4].global_position.y, foes[4].model.rotation.z, foes[5].model.scale.y,
		_ink(foes[0]), _ink(foes[1])])
	game.stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


func _bag(main: Node) -> void:
	var row: Vector3 = main.player.global_position + Vector3(0.0, 0.0, 3.5)
	var bags: Array = []
	for i in 4:
		var d: Node = load("res://scripts/training_dummy.gd").new()
		main._set_model(d, "dummy", "Skeleton_Warrior")  # the comic bag, as main._start_training
		main.add_child(d)
		d.home = row + Vector3(i * 2.4 - 3.6, 0.0, 0.0)
		d.global_position = d.home
		bags.append(d)
	await create_timer(2.2).timeout  # past the TRAINING banner
	bags[3].take_hit(40.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	bags[3].take_hit(87.0, Vector3(0.0, 0.0, 6.0), 0.0, true)
	await create_timer(0.5).timeout
	game_of(main).combo_changed.emit(0, "D")  # the string ends: its tag pops
	await create_timer(0.3).timeout
	bags[2].hp = bags[2].max_hp - 10.0
	bags[2].last_hit_ms = -100000  # refills next frame: the shake-off
	bags[1].take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	await create_timer(0.2).timeout  # about half a swing: past upright the other way
	bags[0].take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	await create_timer(0.03).timeout
	if DisplayServer.get_name() != "headless":
		get_root().get_texture().get_image().save_png("user://enemy_feel_bag.png")
		print("saved ", ProjectSettings.globalize_path("user://enemy_feel_bag.png"))
	print("[enemy_feel_preview] bag tip z=%.2f scale=%.2f  swing z=%.2f  shake z=%.2f stars=%s  tag=%s" % [
		bags[0].model.rotation.z, bags[0].model.scale.y, bags[1].model.rotation.z, bags[2].model.rotation.z,
		bags[2].find_child("DazeStars", false, false) != null, bags[3].get_node("StringTag").text])


func game_of(main: Node) -> Node:
	return main.get_node("/root/Game")


func _slams(main: Node) -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	var hero: Node = main.player
	var at: Vector3 = hero.global_position + Vector3(0.0, 0.0, 3.5)
	await create_timer(2.0).timeout  # past the TRAINING banner
	var out := []
	for move in ["deep_freeze", "meteor", "maw", "warden"]:
		var e: Node = main._spawn_boss() if move == "warden" else main._spawn("minion", false, at)
		e.global_position = at + (Vector3(0.0, 0.0, 2.0) if move == "warden" else Vector3.ZERO)
		e.max_hp = 50000.0
		e.hp = 50000.0
		if move == "warden":
			e.break_damage = 1e6
		await create_timer(1.2).timeout
		e.move_speed = 0.0
		e.attack_damage = 0.0
		e.model.rotation.y = PI
		match move:
			"deep_freeze":
				ve._deep_freeze(hero, at, 1.0)
			"meteor":
				ve._meteor_landing(hero, {"damage": 1.0}, at, 1.0)
			"maw":
				hero._void.dark_spot = at
				ve._maw(hero, {"damage": 1.0}, 1.0)
			"warden":
				e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 9.0, true)
		await create_timer(0.1).timeout
		var shot := "user://enemy_feel_slams_%s.png" % move
		if DisplayServer.get_name() != "headless":
			get_root().get_texture().get_image().save_png(shot)
			print("saved ", ProjectSettings.globalize_path(shot))
		out.append("%s squash=%.2f ink=%.1f tilt=%.2f" % [move, e.last_squash.y, e.last_ink, absf(e.model.rotation.x) + absf(e.model.rotation.z)])
		await create_timer(1.0).timeout
		e.queue_free()
		await create_timer(1.5).timeout  # the effects clear before the next
	print("[enemy_feel_preview] slams (crater squash 0.32): ", ", ".join(out))


## A foe's outline width right now (0 headless: no outline there).
func _ink(e: Node) -> float:
	return e._ink_mat.get_shader_parameter("width_px") if e._ink_mat != null else 0.0
