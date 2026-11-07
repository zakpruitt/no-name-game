extends SceneTree
## Camera hit feel (camera_rig.gd), headless: each hit pushes the camera in a
## hair (hit_zoom, more per chain tier, capped at HIT_ZOOM_MAX, springing back),
## heavy hits roll it alternate ways (roll, capped at ROLL_MAX), kicks chase a
## target so two opposite kicks in one frame cancel instead of jittering, and
## Game.register_hit / Game.shake drive them. Round 36: the rest distance shows the hero 125-160 px tall at
## 1080p with 25-40% more floor than round 32's camera, --cam-*= flags override it, and the fight framing eases
## out to fit a foe thrown wide, then drifts back; a breaker hang stays centred, and the camera follows a long
## dive (Meteor Fall) without a snap. Prints PASS/FAIL.
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
	await _hang_dive(world)
	world.queue_free()
	await process_frame
	await _endings()
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


## Breaker hang and dive (round 42, meteor dive): a foe hit 12 m out doesn't pull the hang out or lean it (he stays
## centred in the push-in through the window), and when he dives 12 m onto a group (Meteor Fall) the camera
## follows him there without a snap: no frame moves it further than he moved, it never runs ahead of him, and it
## has caught up soon after he lands.
func _hang_dive(world: Node3D) -> void:
	var hero_script := GDScript.new()
	hero_script.source_code = "extends Node3D
enum State { MOVE, LEAP }
var state := 0
var _brk_phase := -1
"
	hero_script.reload()
	var hero: Node3D = hero_script.new()
	world.add_child(hero)
	hero.global_position = Vector3(100.0, 0.0, 0.0)  # (clear of the other checks' rig and foes)
	var rig: Node3D = load("res://scripts/camera_rig.gd").new()
	rig.target = hero
	rig.max_shake_roll = 0.0
	world.add_child(rig)
	var foe_script := GDScript.new()
	foe_script.source_code = "extends Node3D
var last_hit_ms := -100000
"
	foe_script.reload()
	var foe: Node3D = foe_script.new()
	world.add_child(foe)
	foe.add_to_group("enemies")
	foe.global_position = hero.global_position + Vector3(12.0, 0.0, 2.0)  # the group the palm punched away
	var rest: float = rig.offset.length()
	await _settle(0.5)
	hero.state = 1
	hero._brk_phase = 0  # the rise and the timing window
	await _hang_hold(foe, 0.6)
	_check(rig._frame < 1.02 and rig.camera.position.length() < rest * 0.97, "in the window the hang keeps its push-in (x%.3f, %.2f of %.2f m)" % [rig._frame, rig.camera.position.length(), rest])
	_check(absf(rig.global_position.x - hero.global_position.x) < 0.2, "and no lean towards the foe 12 m out (%.2f m)" % (rig.global_position.x - hero.global_position.x))
	_check(not rig.get_script().get_script_constant_map().has("HANG_FRAME_GAIN"), "no hang pull-out left (Meteor Fall's beats are gone)")
	hero._brk_phase = 1  # the dive: 12 m in 0.4 s
	var from: Vector3 = hero.global_position
	var worst := 0.0
	var ahead := -INF
	var frame_max := 0.0
	var last_rig: Vector3 = rig.global_position
	var last_hero: Vector3 = hero.global_position
	# Stepped by hand at 60 fps: he moves 1/24 of the dive and the rig follows one 1/60 s step. (This drove him by the
	# wall clock while the rig follows with the engine's frame delta; headless the two disagree, two frames could land
	# in one ms and the rig still stepped, so it read 0.21 m "over" every run with no snap in the rig.)
	rig.set_process(false)
	const STEPS := 24  # 0.4 s
	for i in STEPS:
		hero.global_position = from + Vector3(12.0, 0.0, 0.0) * (float(i + 1) / STEPS)
		foe.last_hit_ms = Time.get_ticks_msec()
		rig._process(1.0 / 60.0)
		var step: float = (rig.global_position - last_rig).length()
		worst = maxf(worst, step - (hero.global_position - last_hero).length())
		ahead = maxf(ahead, rig.global_position.x - hero.global_position.x)
		frame_max = maxf(frame_max, rig._frame)
		last_rig = rig.global_position
		last_hero = hero.global_position
	_check(worst < 0.05, "the dive's follow never snaps: no frame moves the camera further than he moved (%.3f m over)" % worst)
	_check(ahead < 0.05, "and it never runs ahead of him (%.2f m)" % ahead)
	_check(frame_max < 1.02, "nor pulls out on the way down (x%.3f)" % frame_max)
	rig.set_process(true)
	hero.global_position = from + Vector3(12.0, 0.0, 0.0)
	hero.state = 0
	hero._brk_phase = -1
	await _settle(0.8)
	var gap := Vector2(rig.global_position.x - hero.global_position.x, rig.global_position.z - hero.global_position.z).length()
	_check(gap < 0.3, "it has caught up with him 0.8 s after he lands (%.2f m)" % gap)
	foe.queue_free()
	rig.queue_free()
	hero.queue_free()


## Round 54 (camera-hang lane): the hang framing in the real game. The bot plays one string per breaker ending (its
## best situation where it has one) in the training room at 1920x1080, and for each the worst actor's NDC (feet and
## FRAME_HEAD up of every foe held in the hang, by the landing zone, by the landing or cued, and the cued structure)
## must be inside ENDING_NDC at the landing (its first LAND_MS) and over the payoff (to PAYOFF_MS after it).
const ENDING_STRINGS := {
	"Grounded": "L H H", "Collapse": "H H", "Maw": "H L H", "Worldbreaker": "L H L H", "Shatterstorm": "D L H",
	"Avalanche": "L L H L H", "Abyss": "hold", "Meteor Fall": "L L L H H", "Cataclysm": "L H L L H",
	"Flash Freeze": "D L H H L", "Black Ice": "alt H L H", "Anvil": "L L H D H H L", "Short Circuit": "spread far alt L H H",
	"Slapshot": "wall alt D L H", "Meteor Shower": "spread alt L L L H H", "Pinwheel": "wall alt L L H D H H L",
	"Hellseam": "wall spread L L L H L", "Cold Front": "alt L H L H", "Tempest": "alt L H L L H", "Ricochet": "counter D",
	"Uproot": "pillar alt hold", "Eruption": "wall D L H H H L"}
const ENDING_NDC := 0.9
## Cold Front: the hoisted cube sits ~8 m down-screen of where his dive lands and 2.8 m up; the scene wants x1.7, past
## camera_rig.HANG_CAP_WIDE (1.55), so its cube lands at 0.89-0.96 for the landing's first frames. On screen is the bar.
const ENDING_NDC_OVER := {"Cold Front": 1.0}
const LAND_MS := 150
const PAYOFF_MS := 1400
const NEAR_R := 5.0  # m round the landing: the pile
var _hp: CharacterBody3D
var _rows := {}  # ending -> [landing, payoff, worst]


func _endings() -> void:
	get_root().size = Vector2i(1920, 1080)
	game._hints_seen = game.HINTS.keys()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_hp = main.player
	var waited := 0.0
	while get_nodes_in_group("enemies").is_empty() and waited < 6.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(1.0).timeout
	var bot: Node = load("res://scripts/training_bot.gd").new()
	bot.main = main
	main.add_child(bot)
	for flag in ["_hit_shot_taken", "_dash_shot_taken", "_guide_shot_taken", "_cast_shot_taken"]:
		bot.set(flag, true)
	bot._shots_taken = 99
	var plan: Array = []  # [index, ending]
	for ending: String in ENDING_STRINGS:
		var at := -1
		for i in bot.strings.size():
			if " ".join(bot.strings[i]) == ENDING_STRINGS[ending]:
				at = i
				break
		_check(at >= 0, "the bot has %s's string (%s)" % [ending, ENDING_STRINGS[ending]])
		if at >= 0:
			plan.append([at, ending])
	plan.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for step: Array in plan:
		bot._bot_string = step[0]
		bot._bot_step = 0
		bot._reset_done = false
		bot._bot_wait = 0.3
		await _one_ending(bot, step[1])
	main.queue_free()
	for ending: String in ENDING_STRINGS:
		if not _rows.has(ending):
			continue
		var r: Array = _rows[ending]
		var bar: float = ENDING_NDC_OVER.get(ending, ENDING_NDC)
		_check(r[0] <= bar and r[1] <= bar, "%s: the worst actor is inside %.1f at the landing (%.2f) and the payoff (%.2f)%s" % [
			ending, bar, r[0], r[1], "" if r[0] <= bar and r[1] <= bar else " (worst: %s; %s)" % [r[2], r[3]]])


## Plays the bot's current string until its breaker has landed and PAYOFF_MS gone by (or it gives up), measuring.
func _one_ending(bot: Node, ending: String) -> void:
	var t0 := Time.get_ticks_msec()
	var landed: int = _hp.breakers_landed
	var actors := {}
	var land_ms := -1
	var worst := [0.0, 0.0, "", ""]
	var was_leap := false
	var frames := []  # [ms, camera transform, fov, {id: pos}, structs]
	while Time.get_ticks_msec() - t0 < 25000:
		bot._autotest_t = 0.0
		game.awakening = 0.0
		await process_frame
		var now := Time.get_ticks_msec()
		var leap: bool = _hp.state == _hp.State.LEAP
		if leap and not was_leap:
			actors.clear()
			frames.clear()
		was_leap = leap
		if leap:
			for e in _hp._void.held_foes():
				actors[e.get_instance_id()] = true
		if land_ms < 0 and _hp.breakers_landed > landed:
			land_ms = now
			for e: Node3D in get_nodes_in_group("enemies"):
				var d := e.global_position - _hp.global_position
				if Vector2(d.x, d.z).length() < NEAR_R or absi(int(e.get("last_hit_ms")) - now) <= 60:
					actors[e.get_instance_id()] = true
		if land_ms < 0 and not leap:
			continue
		var cam: Camera3D = get_root().get_camera_3d()
		var rig: Node = game.camera_rig
		var f := [now, cam.global_transform, cam.fov, {}, [], rig._actors.keys(), "frame %.2f need %.2f lean %s hero %s" % [rig._frame, rig._scene_need, rig._lean.snapped(Vector3.ONE * 0.1), _hp.global_position.snapped(Vector3.ONE * 0.1)]]
		for e: Node3D in get_nodes_in_group("enemies"):
			f[3][e.get_instance_id()] = e.global_position
			if int(e.get_meta(&"frame_cue_ms", 0)) > now:
				actors[e.get_instance_id()] = true
		for n: Node in get_nodes_in_group("env"):
			if n is Node3D and int(n.get_meta(&"frame_cue_ms", 0)) > now:
				f[4].append((n as Node3D).global_position + Vector3.UP)
		frames.append(f)
		if land_ms > 0 and (now - land_ms > PAYOFF_MS or bot._bot_step == 0 and not bot._reset_done):
			break
	if land_ms < 0:
		_check(false, "%s lands (%s)" % [ending, ENDING_STRINGS[ending]])
		return
	var first := true
	for f: Array in frames:
		if f[0] <= land_ms:  # (from the frame after: the landing's own frame has the camera from before it)
			continue
		var k := 0 if f[0] - land_ms < LAND_MS or first else 1  # (a long first frame still counts as the landing)
		first = false
		var pts := []
		for id: int in actors:
			if f[3].has(id):
				pts.append(f[3][id])
		pts.append_array(f[4])
		var ids := actors.keys().filter(func(id: int) -> bool: return f[3].has(id))
		for j in pts.size():
			var p: Vector3 = pts[j]
			var framed: bool = j >= ids.size() or f[5].has(ids[j])
			for h: float in [0.0, 1.6]:
				var d: Vector3 = (f[1] as Transform3D).affine_inverse() * (p + Vector3.UP * h)
				var ty := tan(deg_to_rad(float(f[2]) * 0.5))
				var z := maxf(-d.z, 0.01)
				var m := maxf(absf(d.x / (z * ty * 16.0 / 9.0)), absf(d.y / (z * ty)))
				if m > worst[k]:
					worst[k] = m
					worst[2 + k] = "%s at %s, %d ms, %s, %s" % ["landing" if k == 0 else "payoff", p.snapped(Vector3.ONE * 0.1), f[0] - land_ms, "framed" if framed else "NOT an actor", f[6]]
	_rows[ending] = worst
	print("[camera] %-14s landing %.2f payoff %.2f" % [ending, worst[0], worst[1]])


## `sec` of real time with `foe` still being hit.
func _hang_hold(foe: Node3D, sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		foe.last_hit_ms = Time.get_ticks_msec()
		await process_frame


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
