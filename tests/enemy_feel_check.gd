extends SceneTree
## Enemy hit reactions, headless, on real minions in the arena: every landed
## hit squashes the model per SQUASH kind, grounded hits lean it away along
## the knockback and spring it back, the flash is in the hero's colour, and a
## kill holds the corpse KILL_FREEZE; juggles hang, tumble, bounce and skid;
## a crowd hit in one frame reacts as a wave (WAVE_STEP apart). Prints
## [enemy_feel] PASS/FAIL and the measured juggle numbers.
## Run: godot --headless --path . -s tests/enemy_feel_check.gd

var _fails: Array[String] = []
var _main: Node


func _initialize() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.save_hints = false
	_main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(_main)
	await create_timer(0.3).timeout
	_main.clear_room()
	_main.player.bot_enabled = true
	var home: Vector3 = _main.player.global_position
	var at := home + Vector3(0.0, 0.0, 4.0)
	var kb := Vector3(0.0, 0.0, 6.0)  # the hero stands at -z of it: knocked away from him

	# A tap: light squash, a small lean with the blow, back upright in LEAN_TIME.
	var e: Node = await _fresh(at)
	e.model.rotation.y = PI  # facing the hero (-z)
	e.take_hit(1.0, kb, 0.0, false)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.tap.y * e.model_scale), "tap squashes to %.2f (%.2f)" % [e.SQUASH.tap.y, e.model.scale.y])
	# Facing -z, a blow toward +z is from the front: the top tips back (local -z): rotation.x < 0.
	_check(is_equal_approx(e.model.rotation.x, -e.LEAN) and absf(e.model.rotation.z) < 0.001,
		"tap leans %.2f away from the blow (x %.2f z %.2f)" % [e.LEAN, e.model.rotation.x, e.model.rotation.z])
	_check(e._freeze_t == e.hit_freeze, "tap freezes hit_freeze (%.2f)" % e._freeze_t)
	await create_timer(e.LEAN_HOLD + e.LEAN_TIME + 0.3).timeout
	_check(absf(e.model.rotation.x) < 0.02 and is_equal_approx(e.model.scale.y, e.model_scale),
		"upright and unsquashed again (x %.3f scale %.2f)" % [e.model.rotation.x, e.model.scale.y])
	# A big hit from the side: the lean is LEAN_BIG, around the other axis.
	e.take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.big.y * e.model_scale), "big hit squashes to %.2f" % e.SQUASH.big.y)
	_check(absf(absf(e.model.rotation.z) - e.LEAN_BIG) < 0.001 and absf(e.model.rotation.x) < 0.001,
		"big hit leans %.2f sideways (x %.2f z %.2f)" % [e.LEAN_BIG, e.model.rotation.x, e.model.rotation.z])
	_check(e._freeze_t == e.hit_freeze_big, "big hit freezes hit_freeze_big")
	var tinted: MeshInstance3D = e.model.find_children("*", "MeshInstance3D", true, false)[0]
	_check(tinted.material_overlay != null and tinted.material_overlay.albedo_color.a > 0.0, "the hit flash is on")
	await create_timer(0.6).timeout
	# A launch: stretched tall; a hit while up snaps it.
	e.take_hit(1.0, kb, 9.0, true)
	_check(e.state == e.State.AIRBORNE and is_equal_approx(e.model.scale.y, e.SQUASH.launch.y * e.model_scale),
		"a launch stretches to %.2f" % e.SQUASH.launch.y)
	await physics_frame
	await physics_frame
	e.take_hit(1.0, kb, 9.0, false)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.juggle.y * e.model_scale), "a juggle hit snaps to %.2f" % e.SQUASH.juggle.y)
	# Poise held mid-windup: no squash, still a flash.
	var w: Node = await _fresh(at)
	w.poise = 100.0
	w._set_state(w.State.WINDUP)
	w.take_hit(1.0, kb, 0.0, false)
	_check(is_equal_approx(w.model.scale.y, w.model_scale) and w.model.rotation.x == 0.0, "poise held: no squash or lean")
	# A kill: the pop squash and the long hold.
	var k: Node = await _fresh(at)
	k.hp = 1.0
	k.take_hit(5.0, kb, 0.0, false)
	_check(k.state == k.State.DEAD and k._freeze_t == k.KILL_FREEZE and is_equal_approx(k.model.scale.y, k.SQUASH.kill.y * k.model_scale),
		"a kill pops to %.2f and holds %.2f s (%.2f)" % [k.SQUASH.kill.y, k.KILL_FREEZE, k._freeze_t])
	await _extra()
	print("[enemy_feel] ", "PASS" if _fails.is_empty() else "FAIL " + "; ".join(_fails))
	get_root().get_node("Game").stop_all_sfx()
	await create_timer(0.2).timeout
	quit()


## Further checks (juggle feel, crowd waves) go here as the rounds add them.
func _extra() -> void:
	await _juggle()
	await _wave()


## Four foes hit in one frame: the first reacts now, each next one WAVE_STEP later.
func _wave() -> void:
	var at: Vector3 = _main.player.global_position + Vector3(0.0, 0.0, 4.0)
	for old in _main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var crowd: Array = []
	for i in 4:
		var e: Node = _main._spawn("minion", false, at + Vector3(i * 1.5 - 2.25, 0.0, 0.0))
		e.max_hp = 2000.0
		e.hp = 2000.0
		crowd.append(e)
	await create_timer(1.1).timeout
	for e in crowd:
		e.move_speed = 0.0
		e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	var freezes: Array = crowd.map(func(e: Node) -> float: return e._freeze_t)
	var ok := true
	for i in 4:
		ok = ok and is_equal_approx(freezes[i], crowd[0].hit_freeze + i * crowd[0].WAVE_STEP)
	_check(ok, "a crowd's freezes step by WAVE_STEP (%s)" % [freezes])
	var first: Array = [-1, -1, -1, -1]  # frame each foe first squashed (0 = this frame)
	for f in 20:
		for i in 4:
			if first[i] < 0 and crowd[i].model.scale.y < crowd[i].model_scale * 0.999:
				first[i] = f
		await physics_frame
	var step: float = crowd[0].WAVE_STEP * Engine.physics_ticks_per_second
	var spaced: bool = first[0] == 0
	for i in range(1, 4):
		spaced = spaced and first[i] > first[i - 1] and absf(first[i] - first[i - 1] - step) <= 2.0  # the tween starts on the next idle frame
	_check(spaced, "the crowd reacts one after another, %.1f frames apart (%s)" % [step, first])
	print("[enemy_feel] wave: four foes hit in one frame react on frames %s (WAVE_STEP %.0f ms)" % [first, crowd[0].WAVE_STEP * 1000.0])
	# Two hits a frame apart are not a wave.
	await create_timer(0.6).timeout
	crowd[0].take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	await physics_frame
	crowd[1].take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	_check(is_equal_approx(crowd[1]._freeze_t, crowd[1].hit_freeze), "a hit the next frame starts a new wave (%.3f)" % crowd[1]._freeze_t)


## A launch hangs at its apex, tumbles, bounces once off the floor and skids.
func _juggle() -> void:
	var at: Vector3 = _main.player.global_position + Vector3(0.0, 0.0, 4.0)
	var e: Node = await _fresh(at)
	e.model.rotation.y = PI
	var launch := 9.0
	e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), launch, true)
	var top := 0.0
	var hang_frames := 0  # frames within 0.3 m of the apex
	var tumbled := 0.0
	var landed := -1  # frame of the first floor contact
	var bounce_top := 0.0
	var frames := 0
	var skid_v := -1.0  # horizontal speed one frame into the knockdown
	for i in 300:
		await physics_frame
		frames = i
		if e.state == e.State.AIRBORNE:
			top = maxf(top, e.global_position.y)
			tumbled = maxf(tumbled, absf(e.model.rotation.x))
			if landed < 0 and e.is_on_floor() and i > 10:
				landed = i
			if landed >= 0 and i > landed:
				bounce_top = maxf(bounce_top, e.global_position.y)
		else:
			if skid_v < 0.0:
				skid_v = Vector2(e.velocity.x, e.velocity.z).length()
			break
	var expect: float = e.launch_speed_for(top)
	_check(absf(expect - launch) < 0.35, "launch %.1f peaks at %.2f m (launch_speed_for -> %.2f)" % [launch, top, expect])
	_check(tumbled > 1.0, "it tumbles while up (%.2f rad)" % tumbled)
	_check(landed > 0 and bounce_top > 0.1, "it bounces once off the floor (%.2f m)" % bounce_top)
	_check(e.state == e.State.HURT and e._state_t < 0.0 and e.last_squash == e.SQUASH.land,
		"it lands flat (%.2f) and lies there" % e.last_squash.y)
	_check(skid_v > 0.3, "the knockdown keeps sliding (%.2f m/s)" % skid_v)
	_check(frames < 299, "the juggle ends (%d frames)" % frames)
	await create_timer(0.3).timeout
	_check(absf(e.model.rotation.x) < 0.01, "it rights itself on the floor (%.3f)" % e.model.rotation.x)
	# Hang time: a second launch, timing the frames spent near the apex.
	await create_timer(1.0).timeout
	e.take_hit(1.0, Vector3.ZERO, launch, false)
	var y_top := 0.0
	var ys: Array[float] = []
	for i in 300:
		await physics_frame
		if e.state != e.State.AIRBORNE:
			break
		ys.append(e.global_position.y)
		y_top = maxf(y_top, e.global_position.y)
	for y in ys:
		if y > y_top - 0.3:
			hang_frames += 1
	var plain_hang: float = 2.0 * sqrt(2.0 * 0.3 / e.AIR_GRAVITY) * 60.0
	_check(hang_frames > plain_hang * 1.25, "it hangs %d frames within 0.3 m of the apex (plain gravity %.0f)" % [hang_frames, plain_hang])
	print("[enemy_feel] juggle: launch %.1f apex %.2f m, %d frames within 0.3 m of it (plain gravity %.0f), tumble %.2f rad, bounce %.2f m, skid %.2f m/s, %d frames up" 		% [launch, top, hang_frames, plain_hang, tumbled, bounce_top, skid_v, frames])


## A sturdy minion at `at`, past its spawn animation, standing still and harmless.
func _fresh(at: Vector3) -> Node:
	for old in _main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var e: Node = _main._spawn("minion", false, Vector3(at.x, 0.0, at.z))
	e.max_hp = 2000.0
	e.hp = 2000.0
	await create_timer(1.1).timeout
	e.move_speed = 0.0
	e.attack_damage = 0.0
	e.global_position = Vector3(at.x, 0.0, at.z)
	return e


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		push_error("enemy_feel_check: " + what)
