extends SceneTree
## Camera hit feel (camera_rig.gd), headless: each hit pushes the camera in a
## hair (hit_zoom, more per chain tier, capped at HIT_ZOOM_MAX, springing back),
## heavy hits roll it alternate ways (roll, capped at ROLL_MAX), kicks chase a
## target so two opposite kicks in one frame cancel instead of jittering, and
## Game.register_hit / Game.shake drive them. Round 36: the rest distance shows the hero 125-160 px tall at
## 1080p with 25-40% more floor than round 32's camera, --cam-*= flags override it, and the fight framing eases
## out to fit a foe thrown wide, then drifts back. Prints PASS/FAIL.
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
	var kick_m: float = 0.3 * rig.dist / rig.REF_DIST  # (kicks scale with the distance)
	_check(far > 0.1 and far <= kick_m + 0.001, "a kick moves it along the hit (%.3f m, never past the %.3f m kick)" % [far, kick_m])
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
	await _distance(rig)
	await _framing(rig, world)
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


## Round 36 ("zoom the camera out more, too close to the character"): at rest the 1.85 m hero stands 125-160 px
## tall at 1080p (round 32: 167, round 28: 105) and 25-40% more floor is in frame than round 32's (0, 10, 7.5) FOV 36.
func _distance(rig: Node3D) -> void:
	await _settle(1.5)
	var feet: Vector3 = rig.target.global_position
	var now: Vector2 = _measure(rig.camera.global_transform, rig.camera.fov, feet)
	var t32 := Transform3D.IDENTITY.looking_at(-Vector3(0.0, 10.0, 7.5), Vector3.UP)
	t32.origin = feet + Vector3(0.0, 10.0, 7.5)  # (round 32 aimed at his feet)
	var r32: Vector2 = _measure(t32, 36.0, feet)
	var mid: Vector2 = _project(rig.camera.global_transform, rig.camera.fov, feet + Vector3.UP * rig.AIM_HEIGHT)
	_check(mid.distance_to(Vector2(960, 540)) < 4.0, "and aims at his chest, AIM_HEIGHT above his feet (%s)" % mid)
	print("[camera] rest dist=%.2f fov=%.1f hero=%.0f px floor=%.0f m2 (round 32: %.0f px, %.0f m2)" % [rig.camera.position.length(), rig.camera.fov, now.x, now.y, r32.x, r32.y])
	_check(now.x >= 125.0 and now.x <= 160.0, "the hero stands 125-160 px tall at 1080p (%.0f px)" % now.x)
	_check(now.y / r32.y >= 1.25 and now.y / r32.y <= 1.4, "with 25-40%% more floor in frame than round 32's camera (x%.2f)" % (now.y / r32.y))
	var flags: Dictionary = rig.cam_overrides(PackedStringArray(["--cam-dist=16.5", "--cam-fov=40", "--cam-frame=1", "--cam-fov=wide", "--spar=rogue"]))
	_check(flags == {"dist": 16.5, "fov": 40.0, "frame_max": 1.0}, "--cam-dist= / --cam-fov= / --cam-frame= override it, junk ignored (%s)" % flags)
	rig.punch(0.9, 0.2)
	_check(rig._zoom_to < 0.9, "punch() pushes in deeper than asked at the wider distance (%.3f)" % rig._zoom_to)
	await _settle(0.8)


## Fight framing: a foe hit 9 m out to the side pulls the camera out (capped) until it's on screen, a dummy in
## front of him (a normal string) doesn't, and once the foe goes quiet the camera drifts back slowly.
func _framing(rig: Node3D, world: Node3D) -> void:
	var script := GDScript.new()
	script.source_code = "extends Node3D
var last_hit_ms := -100000
"
	script.reload()
	var foe: Node3D = script.new()
	world.add_child(foe)
	foe.add_to_group("enemies")
	foe.global_position = rig.target.global_position + Vector3(0.0, 0.0, -2.6)
	foe.last_hit_ms = Time.get_ticks_msec()
	await process_frame
	await process_frame
	_check(is_equal_approx(rig._frame_to, 1.0), "a dummy hit 2.6 m in front doesn't move the camera out (%.3f)" % rig._frame_to)
	foe.global_position = rig.target.global_position + Vector3(9.0, 1.0, 0.0)
	foe.last_hit_ms = Time.get_ticks_msec()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		foe.last_hit_ms = Time.get_ticks_msec()  # (still being hit)
		await process_frame
	var out: float = rig._frame
	_check(out > 1.05 and out <= rig.FRAME_MAX + 0.001, "a foe hit 9 m out pulls the camera out, capped (x%.3f)" % out)
	_check(rig.global_position.x > 0.3, "and leans the follow point towards the fight (%.2f m)" % rig.global_position.x)
	var d: Vector3 = rig.camera.global_transform.affine_inverse() * foe.global_position
	var ndc_x := d.x / (-d.z * tan(deg_to_rad(rig.camera.fov * 0.5)) * 16.0 / 9.0)
	_check(absf(ndc_x) < 0.95, "so the thrown foe is on a 16:9 screen (x at %.2f of the half-width)" % ndc_x)
	foe.last_hit_ms = Time.get_ticks_msec() - rig.FRAME_HIT_MS - 10  # gone quiet
	await _settle(0.4)
	_check(rig._frame > 1.0 + (out - 1.0) * 0.5, "it drifts back slowly (x%.3f after 0.4 s)" % rig._frame)
	await _settle(7.0)
	_check(absf(rig._frame - 1.0) < 0.01 and Vector2(rig.global_position.x, rig.global_position.z).length() < 0.05, "and is home in a few seconds (x%.3f, %.2f m)" % [rig._frame, Vector2(rig.global_position.x, rig.global_position.z).length()])
	foe.queue_free()


## Where `p` lands on a 1920x1080 view from a camera at `xf` with `fov`.
func _project(xf: Transform3D, fov: float, p: Vector3) -> Vector2:
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	get_root().add_child(sv)
	var cam := Camera3D.new()
	sv.add_child(cam)
	cam.global_transform = xf
	cam.fov = fov
	var at := cam.unproject_position(p)
	sv.free()
	return at


## [hero px tall, floor m2 in frame] for a camera at `xf` with `fov` in a 1920x1080 view (the 1.85 m hero's
## feet at `at`, the floor at y = 0).
func _measure(xf: Transform3D, fov: float, at: Vector3) -> Vector2:
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	get_root().add_child(sv)
	var cam := Camera3D.new()
	sv.add_child(cam)
	cam.global_transform = xf
	cam.fov = fov
	var px := (cam.unproject_position(at) - cam.unproject_position(at + Vector3(0.0, 1.85, 0.0))).length()
	var pts: Array[Vector3] = []
	for c in [Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)]:
		var o := cam.project_ray_origin(c)
		var n := cam.project_ray_normal(c)
		pts.append(o + n * (-o.y / n.y))
	var area := 0.0
	for i in 4:
		area += pts[i].x * pts[(i + 1) % 4].z - pts[(i + 1) % 4].x * pts[i].z
	sv.free()
	return Vector2(px, absf(area) * 0.5)


func _settle(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() < t0 + int(sec * 1000.0):
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("[camera] ", "ok " if ok else "FAIL ", what)
	if not ok:
		fails += 1
