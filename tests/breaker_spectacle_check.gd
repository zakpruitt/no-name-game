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
	# (fx-queue-a: the floor spread is pooled by FX_BEAT.stamp, so it ends hidden and idle rather than freed)
	var live_n := main.get_children().filter(func(c: Node) -> bool: return not (c is Node3D) or (c as Node3D).visible).size()
	_ok(live_n <= n0, "and end: freed or back in the pool (%d left)" % (live_n - n0))
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
	await create_timer(sc.CALL_MAX_S + sc.CALL_OUT_S + 0.2, true, false, true).timeout
	await _impact_lane(main, p, sc, bk, num)

	_finish()


## Impact lane (docs/feel-audit-2026-11-07d.md items 1-3).
func _impact_lane(main: Node, p: CharacterBody3D, sc: CanvasLayer, bk: GDScript, num: GDScript) -> void:
	var game: Node = get_root().get_node("Game")
	var impact: Node = game.impact
	var cfx: GDScript = load("res://scripts/comic_fx.gd")
	var bars: GDScript = load("res://scripts/enemy_bars.gd")
	# 1. A living foe's bar never reads empty; a dead one's does.
	_ok(bars.fill_px(0.4, 75.0) >= bars.SLIVER_PX, "a foe at 0.4 / 75 hp shows a sliver of bar (%.1f px)" % bars.fill_px(0.4, 75.0))
	_ok(bars.fill_px(0.0, 75.0) == 0.0 and is_equal_approx(bars.fill_px(75.0, 75.0), bars.SIZE.x), "an empty bar only for a dead foe, a full one at full hp")
	# 1. A kill under an impact frame: the kill word on the frame, the kill star again once the frame clears.
	await create_timer(impact.IMPACT_GAP_MS / 1000.0 + 0.1, true, false, true).timeout
	var foe: Node3D = main._spawn("warrior", false, p.global_position + Vector3(0.0, 0.0, 3.0))
	await create_timer(1.6, true, false, true).timeout  # (out of SPAWN)
	var words0: int = cfx.kill_words
	var stars0: int = cfx.kill_stars
	_ok(impact.slam(true, p), "a breaker's impact frame flashes")
	foe.take_hit(foe.hp + 5.0, Vector3(0.0, 0.0, 2.0), 0.0, true)
	_ok(foe.state == foe.State.DEAD, "the foe dies under the frame")
	_ok(cfx.kill_words == words0 + 1, "the kill word goes up on the frame itself (%d)" % (cfx.kill_words - words0))
	await process_frame
	_ok(impact.current() > 0.0 and cfx.kill_stars == stars0, "the kill star waits while the frame shows")
	await create_timer(0.35, true, false, true).timeout
	_ok(impact.current() == 0.0 and cfx.kill_stars == stars0 + 1, "and pops once it clears (%d)" % (cfx.kill_stars - stars0))
	var words1: int = cfx.kill_words
	var foe2: Node3D = main._spawn("warrior", false, p.global_position + Vector3(1.5, 0.0, 3.0))
	await create_timer(1.6, true, false, true).timeout
	var reduced0: bool = game.reduce_flashing
	game.reduce_flashing = true  # (a kill flashes no frame then)
	foe2.take_hit(foe2.hp + 5.0, Vector3.ZERO, 0.0, false)
	game.reduce_flashing = reduced0
	_ok(impact.current() == 0.0 and cfx.kill_words == words1, "a kill with no frame up keeps its own star (no kill word)")
	# 2. The banner waits out the landing's impact frame, then goes up with the name.
	await create_timer(impact.IMPACT_GAP_MS / 1000.0 + 0.1, true, false, true).timeout
	var waited0: int = sc.waited
	_ok(impact.slam(false, p), "a second landing's frame flashes")
	sc.callout("Cataclysm", "earth", false)
	num.add(main, p.global_position, 120.0, true, null)
	var empty_frames := 0
	var frames := 0
	while impact.current() > 0.0 and frames < 60:
		await process_frame
		frames += 1
		if sc.banner.visible and sc._call_t < sc.CALL_IN_S * 0.5:
			empty_frames += 1
	_ok(empty_frames == 0, "no empty banner on the impact frame (%d of %d frames)" % [empty_frames, frames])
	_ok(not sc.banner.visible or impact.current() == 0.0, "the banner is not drawn while the frame shows")
	await create_timer(0.15, true, false, true).timeout
	_ok(sc.banner.visible and sc.waited == waited0 + 1 and sc.call_name == "CATACLYSM", "then it slashes in with the name (waited %d)" % (sc.waited - waited0))
	# 3. A word under the banner (said before it opened) moves off it.
	var inst: Variant = cfx.get("_inst")
	_ok(inst != null, "the comic text layer exists")
	if inst == null:
		return
	var relaid0: int = cfx.relaid
	cfx.say("KRUNCH!", p.global_position, 0.5)
	var i: int = (inst._next + inst.POOL - 1) % inst.POOL
	var br: Rect2 = num.banner_rect
	var w: Label = inst._words[i]
	w.position = br.get_center() - w.size * 0.5
	w.set_meta("y", w.position.y)
	await process_frame
	await process_frame
	_ok(num.banner_open and not inst.word_rect(i).intersects(num.banner_rect), "a word on the open banner moves off it (%s vs %s)" % [inst.word_rect(i), num.banner_rect])
	_ok(cfx.relaid == relaid0 + 1, "and is counted once (%d)" % (cfx.relaid - relaid0))
	# 3. ... and off the hero's name callout (FAULT LINE over KRUNCH!).
	await create_timer(sc.CALL_COUNT_MAX_S + sc.CALL_OUT_S + 0.2, true, false, true).timeout
	var label: Label3D = p._callout
	label.text = "FAULT LINE"
	label.modulate.a = 1.0
	label.show()
	label.global_position = p.global_position + Vector3.UP * 3.0
	await process_frame
	var cam: Camera3D = p.get_viewport().get_camera_3d()
	var name_rect: Rect2 = inst._callout_rect(cam, p)
	cfx.say("KRUNCH!", p.global_position, 0.5)
	i = (inst._next + inst.POOL - 1) % inst.POOL
	w = inst._words[i]
	w.position = name_rect.get_center() - w.size * 0.5
	w.set_meta("y", w.position.y)
	await process_frame
	await process_frame
	name_rect = inst._callout_rect(cam, p)
	_ok(name_rect.size.x > 0.0 and not inst.word_rect(i).intersects(name_rect), "a word on the name callout moves off it (%s vs %s)" % [inst.word_rect(i), name_rect])
	label.hide()


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
