extends SceneTree
## Breaker spectacle (designed_breaker.gd; docs/features/combo-breakers.md "Round 48"), headless, PASS/FAIL:
##   - Game.slam_stop: a crunch freeze at CRUNCH_SCALE, then the slow tail, then back to 1, all inside SLAM_STOP_MAX;
##   - camera_rig.jolt: a shake along its axis that dies within a second, none with shake off;
##   - the landing's beat: the burst, speed lines and floor spread spawn (ice: no speed lines) and free themselves;
##   - the callout banner: the ending's name goes up in the element's tones, takes over a breaker total that was
##     already counting in the hang (and hides its 3D number), fits short names narrower than long ones, and goes.
## Run: godot --headless --path . -s tests/breaker_spectacle_check.gd

var _fails: Array[String] = []


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await create_timer(1.0).timeout
	var p: CharacterBody3D = main.player
	p.set_physics_process(false)
	p.set_process(false)
	var bk: GDScript = load("res://scripts/designed_breaker.gd")
	var num: GDScript = load("res://scripts/comic_number.gd")
	_ok(bk.DESIGNED.on(), "designed effects on")

	# The landing's stop shape.
	game.slam_stop(0.06, 0.1, 0.3)
	await process_frame
	var crunch := Engine.time_scale
	await create_timer(0.1, true, false, true).timeout
	var tail := Engine.time_scale
	await create_timer(0.3, true, false, true).timeout
	_ok(crunch < 0.1, "the crunch is a freeze (%.2f)" % crunch)
	_ok(tail > crunch and tail < 0.9, "then the slow tail (%.2f)" % tail)
	_ok(Engine.time_scale > 0.95, "then full speed again (%.2f)" % Engine.time_scale)

	# The jolt.
	var rig: Node = game.camera_rig
	_ok(rig != null and rig.has_method("jolt"), "the camera rig has a jolt")
	if rig != null:
		var shake0: float = game.shake_scale
		game.shake_scale = 1.0
		rig.jolt(0.5, 10.0, 6.0, Vector2(1.0, 0.0))
		var j0: Vector2 = rig.jolt_offset()
		_ok(absf(j0.x) > 0.2 and absf(j0.y) < 0.01, "a jolt shakes along its axis (%s)" % j0)
		await create_timer(1.0, true, false, true).timeout
		_ok(rig.jolt_offset().length() < 0.02, "and dies within a second (%s)" % rig.jolt_offset())
		game.shake_scale = 0.0
		rig.jolt(0.5, 10.0, 6.0, Vector2(1.0, 0.0))
		_ok(rig.jolt_offset() == Vector2.ZERO, "no jolt with the shake setting off")
		game.shake_scale = shake0

	# The beat's sheets spawn and go.
	var n0 := main.get_child_count()
	bk.burst(main, Vector3(2, 0, 2), "wind")
	bk.rays(main, Vector3(2, 0, 2), "wind")
	bk.spread(main, Vector3(2, 0, 2), "void")
	await process_frame
	_ok(main.get_child_count() >= n0 + 3, "burst, speed lines and floor spread spawn (%d)" % (main.get_child_count() - n0))
	await create_timer(bk.LIFE_S + 0.6, true, false, true).timeout
	_ok(main.get_child_count() <= n0, "and free themselves (%d left)" % (main.get_child_count() - n0))
	_ok(bk.LOOK.ice.get("rays", true) == false, "ice lands without speed lines (they read as crystals)")

	# The callout banner.
	var sc: CanvasLayer = bk.screen(p)
	_ok(sc != null, "the screen layer exists")
	await create_timer(0.2, true, false, true).timeout
	p.state = p.State.LEAP
	var foes := get_nodes_in_group("enemies").slice(0, 3)
	var live: Node3D = num.add(main, foes[0].global_position, 40.0, true, foes[0])  # the hang's chain hits
	await create_timer(0.2, true, false, true).timeout
	_ok(is_instance_valid(live) and live.visible, "the hang's running total shows in 3D until the landing")
	if not is_instance_valid(live):
		_finish()
		return
	var shown0: int = sc.shown
	sc.callout("Maw", "void", true)
	live.add_hit(60.0, true)  # the landing
	p.state = p.State.MOVE
	await create_timer(0.15, true, false, true).timeout
	_ok(sc.shown == shown0 + 1 and sc.banner.visible, "the ending's name goes up on the banner")
	_ok(is_equal_approx(sc.call_total, 100.0), "the banner takes over the hang's running total (%s)" % sc.call_total)
	_ok(not live.visible, "and hides its 3D number")
	var body: Color = sc._banner_mat.get_shader_parameter("c_body")
	var want: Color = bk.PAL.of("void").body
	_ok(body.is_equal_approx(want), "in the element's tones on a perfect too")
	var short_w: float = sc.banner.size.x
	sc.callout("Worldbreaker", "earth", false)
	await create_timer(0.15, true, false, true).timeout
	_ok(sc.banner.size.x > short_w * 1.15, "a long name gets a wider banner (%.0f > %.0f)" % [sc.banner.size.x, short_w])
	await create_timer(sc.CALL_MAX_S + sc.CALL_OUT_S + 0.2, true, false, true).timeout
	_ok(not sc.banner.visible, "the banner goes")
	# A foe splatted on a wall under the banner (Pinwheel's throw into the top wall): it moves to the bottom.
	var cam: Camera3D = p.get_viewport().get_camera_3d()
	var vp: Vector2 = p.get_viewport().get_visible_rect().size
	sc.callout("Pinwheel", "earth", true)
	await create_timer(0.1, true, false, true).timeout
	var top_y: float = sc.banner.position.y
	var foe: Node3D = foes[1]
	var spot := cam.project_position(Vector2(vp.x * 0.5, vp.y * sc.CALL_Y), cam.global_position.distance_to(foe.global_position))
	foe.global_position = Vector3(spot.x, foe.global_position.y, spot.z) - Vector3.UP * 0.0
	foe.set_meta(bk.WALL_META, Time.get_ticks_msec())
	await create_timer(0.5, true, false, true).timeout
	_ok(sc.banner.position.y > top_y + vp.y * 0.4, "a wall-splatted foe under the banner sends it to the bottom (%.0f -> %.0f)" % [top_y, sc.banner.position.y])

	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("PASS breaker_spectacle_check")
	else:
		for f in _fails:
			print("FAIL ", f)
	quit(0 if _fails.is_empty() else 1)


func _ok(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails.append(what)
