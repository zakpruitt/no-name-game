extends SceneTree
## Camera hit feel (camera_rig.gd), headless: each hit pushes the camera in a
## hair (hit_zoom, more per chain tier, capped at HIT_ZOOM_MAX, springing back),
## heavy hits roll it alternate ways (roll, capped at ROLL_MAX), kicks chase a
## target so two opposite kicks in one frame cancel instead of jittering, and
## Game.register_hit / Game.shake drive them. Prints PASS/FAIL.
## Run: godot --headless --path . -s tests/camera_feel_check.gd

var fails := 0
var game: Node


func _initialize() -> void:
	await process_frame
	game = get_root().get_node("Game")
	game.save_hints = false
	game.shake_scale = 1.0
	var world := Node3D.new()
	get_root().add_child(world)
	var hero := Node3D.new()
	world.add_child(hero)
	var rig: Node3D = load("res://scripts/camera_rig.gd").new()
	rig.target = hero
	rig.max_shake_roll = 0.0  # trauma roll is random; keep the hit roll readable
	world.add_child(rig)
	await process_frame
	await process_frame
	_check(game.camera_rig == rig, "the rig registers itself with Game")
	var rest: float = rig.offset.length()
	_check(absf(rig.camera.position.length() - rest) < 0.001, "rests at its offset (%.2f)" % rig.camera.position.length())
	# Micro-zoom: one hit nudges in; a crowd of hits stacks only to the cap.
	rig.hit_zoom(1.0)
	await process_frame
	await process_frame
	var one: float = rig.camera.position.length()
	_check(one < rest - 0.01 and one > rest * (1.0 - rig.HIT_ZOOM_MAX), "a hit pushes the camera in a little (%.3f of %.3f)" % [one, rest])
	for i in 30:
		rig.hit_zoom(2.5)
	_check(rig._hit_zoom_to <= rig.HIT_ZOOM_MAX + 0.0001, "30 stacked hits cap at HIT_ZOOM_MAX (%.3f)" % rig._hit_zoom_to)
	await process_frame
	await process_frame
	_check(rig.camera.position.length() >= rest * (1.0 - rig.HIT_ZOOM_MAX) - 0.01, "so the camera dives at most %d%% (%.3f)" % [roundi(rig.HIT_ZOOM_MAX * 100.0), rig.camera.position.length()])
	await _settle(1.2)
	_check(absf(rig.camera.position.length() - rest) < 0.02, "and springs back within 1.2 s (%.3f)" % rig.camera.position.length())
	# Roll: heavy hits rock it alternate ways, capped.
	rig.roll(2.0)
	await process_frame
	await process_frame
	var r1: float = rig.camera.rotation.z
	_check(absf(r1) > deg_to_rad(0.5), "a heavy hit rolls the camera (%.2f deg)" % rad_to_deg(r1))
	await _settle(1.0)
	rig.roll(2.0)
	await process_frame
	await process_frame
	var r2: float = rig.camera.rotation.z
	_check(signf(r2) == -signf(r1), "the next heavy hit rolls the other way (%.2f then %.2f deg)" % [rad_to_deg(r1), rad_to_deg(r2)])
	for i in 10:
		rig.roll(2.0)
	_check(absf(rig._roll_to) <= rig.ROLL_MAX + 0.0001, "stacked rolls cap at ROLL_MAX (%.2f deg)" % rig._roll_to)
	await _settle(1.2)
	_check(absf(rig.camera.rotation.z) < deg_to_rad(0.05), "and settle level (%.3f deg)" % rad_to_deg(rig.camera.rotation.z))
	# Kicks: opposite kicks in one frame cancel; a lone kick moves it and springs back.
	rig.kick(Vector3.RIGHT, 0.3)
	rig.kick(Vector3.LEFT, 0.3)
	await process_frame
	await process_frame
	var base: Vector3 = rig.offset * rig._zoom
	_check((rig.camera.position - base).length() < 0.01, "two opposite kicks in a frame cancel (%.3f m)" % (rig.camera.position - base).length())
	rig.kick(Vector3.RIGHT, 0.3)
	var far := 0.0
	for i in 6:
		await process_frame
		far = maxf(far, (rig.camera.position - base).length())
	_check(far > 0.1 and far <= 0.3 + 0.001, "a kick moves it along the hit (%.3f m, never past the kick)" % far)
	await _settle(1.0)
	_check((rig.camera.position - base).length() < 0.01, "and springs back (%.3f m)" % (rig.camera.position - base).length())
	# Game drives them: a hit zooms, a heavy shake rolls, a light one doesn't.
	game.combo_count = 0
	game.register_hit("L1")
	_check(rig._hit_zoom_to > 0.0, "Game.register_hit pushes in (%.4f)" % rig._hit_zoom_to)
	var light: float = rig._hit_zoom_to
	rig._hit_zoom_to = 0.0
	game.combo_count = 40  # past every chain tier
	game.register_hit("L1")
	_check(rig._hit_zoom_to > light * 2.0, "deep in the chain each hit pushes harder (%.4f vs %.4f)" % [rig._hit_zoom_to, light])
	game.combo_count = 0
	rig._roll_to = 0.0
	game.shake(0.1)
	_check(is_zero_approx(rig._roll_to), "a light shake doesn't roll (%.2f)" % rig._roll_to)
	game.shake(0.5)
	_check(absf(rig._roll_to) > 0.5, "a heavy shake rolls (%.2f deg)" % rig._roll_to)
	game.shake_scale = 0.0
	rig._roll_to = 0.0
	rig._hit_zoom_to = 0.0
	game.shake(1.0)
	rig.hit_zoom(1.0)
	rig.roll(2.0)
	_check(is_zero_approx(rig._roll_to) and is_zero_approx(rig._hit_zoom_to), "screen shake off switches roll and push-in off too")
	game.shake_scale = 1.0
	await _fov_and_blow(rig)
	print("[camera] ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


## Round 29 fx 4: enders, big stops and kills narrow the FOV a few degrees (stacking, capped, springing
## back); a kick records the blow's direction for the impact frame, which leans that way on screen.
func _fov_and_blow(rig: Node3D) -> void:
	await _settle(1.0)
	_check(is_equal_approx(rig.camera.fov, rig.FOV), "rests at FOV %.0f (%.2f)" % [rig.FOV, rig.camera.fov])
	rig.punch(0.9, 0.1)
	await process_frame
	await process_frame
	_check(rig.camera.fov < rig.FOV - 0.5, "an ender's punch narrows the FOV too (%.2f)" % rig.camera.fov)
	for i in 6:
		rig.fov_punch(rig.FOV_ENDER)
	_check(rig._fov_to <= rig.FOV_MAX + 0.0001, "stacked FOV punches cap at FOV_MAX (%.2f)" % rig._fov_to)
	await _settle(1.2)
	_check(absf(rig.camera.fov - rig.FOV) < 0.05, "and spring back (%.2f)" % rig.camera.fov)
	var corpse := Node.new()
	game.enemy_killed.emit(corpse)
	corpse.free()
	_check(rig._fov_to > rig.FOV_KILL * 0.5, "a kill punches the FOV (%.2f)" % rig._fov_to)
	rig.kick(Vector3.RIGHT, 0.2)
	_check(game.last_hit_dir.is_equal_approx(Vector3.RIGHT) and Time.get_ticks_msec() - game.last_hit_ms < 50, "a kick records the blow's direction")
	var blow: Vector2 = game.hit_dir_screen()
	_check(blow.x > 0.9, "which points right on the screen for a blow along +x (%s)" % blow)
	game.last_hit_ms -= game.HIT_DIR_FRESH_MS + 10
	_check(game.hit_dir_screen() == Vector2.ZERO, "a stale blow centres the frame")
	game.reduce_flashing = false
	game.impact._last_ms = -100000
	rig.kick(Vector3.LEFT, 0.2)
	game.impact.flash(0.8, false, Vector2.ZERO, Color(0.62, 0.3, 1.0))
	await process_frame
	_check(game.impact.dir.x < -0.05, "the impact frame leans with a kick just after it fired (%s)" % game.impact.dir)
	await _settle(0.5)
	game.shake_scale = 0.0
	rig._fov_to = 0.0
	rig.fov_punch(2.0)
	_check(is_zero_approx(rig._fov_to), "screen shake off switches the FOV punch off")
	game.shake_scale = 1.0


func _settle(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() < t0 + int(sec * 1000.0):
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("[camera] ", "ok " if ok else "FAIL ", what)
	if not ok:
		fails += 1
