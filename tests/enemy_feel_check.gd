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
	_check(e.last_ink == e.INK.big, "a big hit swells the ink %.1fx" % e.last_ink)
	var tinted: MeshInstance3D = e.model.find_children("*", "MeshInstance3D", true, false)[0]
	_check(tinted.material_overlay != null and tinted.material_overlay.albedo_color.a > 0.0, "the hit flash is on")
	await create_timer(0.6).timeout
	# A launch: stretched tall; a hit while up snaps it.
	e.take_hit(1.0, kb, 9.0, true)
	_check(e.state == e.State.AIRBORNE and is_equal_approx(e.model.scale.y, e.SQUASH.launch.y * e.model_scale),
		"a launch stretches to %.2f" % e.SQUASH.launch.y)
	await physics_frame
	await physics_frame
	e.take_hit(1.0, kb, 5.0, false)
	_check(is_equal_approx(e.model.scale.y, e.SQUASH.juggle.y * e.model_scale), "a juggle hit snaps to %.2f" % e.SQUASH.juggle.y)
	await physics_frame
	e.take_hit(1.0, kb, e.RELAUNCH_MIN + 2.0, false)
	_check(e.last_squash == e.SQUASH.launch, "a hit from below re-launches with the launch stretch (%.2f)" % e.last_squash.y)
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
	await _direction()
	await _bag()
	await _air_kill()
	await _slams()
	await _boss()
	await _spar()


## Killed while up: the corpse spins faster all the way down, then settles on a full turn.
func _air_kill() -> void:
	var e: Node = await _fresh(_main.player.global_position + Vector3(0.0, 0.0, 4.0))
	e.model.rotation.y = PI
	e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 9.0, true)
	await create_timer(0.3).timeout
	e.hp = 1.0
	e.take_hit(5.0, Vector3(0.0, 0.0, 6.0), 0.0, true)
	_check(e.state == e.State.DEAD and e.last_squash == e.SQUASH.air_kill and absf(e._tumble_v) > e.TUMBLE_BIG * 1.5,
		"an air kill spins on (%.1f rad/s)" % e._tumble_v)
	var spun := 0.0
	var start: float = e.model.rotation.x
	for i in 120:
		await physics_frame
		spun = maxf(spun, absf(e.model.rotation.x - start))
		if e._tumble_v == 0.0:
			break
	await create_timer(0.25).timeout
	var off: float = absf(e.model.rotation.x - roundf(e.model.rotation.x / TAU) * TAU)
	_check(spun > 2.0 and off < 0.01, "the corpse spins %.1f rad down and lands flat (%.3f off)" % [spun, off])
	print("[enemy_feel] air kill: spins %.1f rad/s, %.1f rad before it lands" % [e._tumble_v if e._tumble_v != 0.0 else e.TUMBLE_BIG * e.AIR_KILL_SPIN, spun])


## The training dummy as a punching bag: a tap snaps it over BAG_LEAN_MULT as
## far, the spring rocks it back past upright and settles it; squashes are
## exaggerated; it boings back up after a knockdown; refilling, it shakes off a daze.
func _bag() -> void:
	for old in _main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var d: Node = load("res://scripts/training_dummy.gd").new()
	d.model_scene = _main._model("Skeleton_Warrior")
	_main.add_child(d)
	d.home = _main.player.global_position + Vector3(0.0, 0.0, 4.0)
	d.global_position = d.home
	await create_timer(1.1).timeout
	d.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	var tip: Vector2 = d._bag_tilt
	_check(absf(tip.length() - d.LEAN * d.BAG_LEAN_MULT) < 0.001, "the dummy tips %.2f rad on a tap (%.2f)" % [d.LEAN * d.BAG_LEAN_MULT, tip.length()])
	var want: float = 1.0 - (1.0 - d.SQUASH.tap.y) * d.BAG_SQUASH_MULT
	_check(is_equal_approx(d.last_squash.y, want), "its squash is exaggerated (%.2f, a skeleton %.2f)" % [d.last_squash.y, d.SQUASH.tap.y])
	var along := tip.normalized()
	var back := 0.0  # furthest past upright, against the blow
	var settled := -1
	for i in 240:
		await physics_frame
		var t: Vector2 = Vector2(d.model.rotation.x, d.model.rotation.z)
		back = minf(back, t.dot(along))
		if settled < 0 and t == Vector2.ZERO and i > 5:
			settled = i
	_check(back < -0.25 * tip.length(), "the spring overshoots past upright (%.2f rad back from %.2f)" % [back, tip.length()])
	_check(settled > 0 and settled < 180, "and settles dead upright (%d frames)" % settled)
	# A knockdown: once it's up, the spring kicks it past upright.
	d.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 9.0, true)
	var boing := 0.0
	for i in 400:
		await physics_frame
		if d.state == d.State.CHASE:
			boing = maxf(boing, d._bag_tilt.length())
			if i > 30 and d._bag_tilt == Vector2.ZERO and boing > 0.0:
				break
	_check(boing > 0.2, "it boings back upright after a knockdown (%.2f rad)" % boing)
	# Left alone, it refills and shakes off the daze.
	var before: int = d.shakeoffs
	d.hp = d.max_hp - 10.0
	d.last_hit_ms = -100000
	await physics_frame
	await physics_frame
	_check(d.shakeoffs == before + 1 and d.hp == d.max_hp and d.find_child("DazeStars", false, false) != null,
		"refilling, it shakes off a daze under stars (%d)" % d.shakeoffs)
	var wobble := 0.0
	for i in 30:
		await physics_frame
		wobble = maxf(wobble, absf(d.model.rotation.z))
	_check(wobble > 0.15, "the shake-off rocks it side to side (%.2f rad)" % wobble)
	print("[enemy_feel] bag: tap tips %.2f rad, swings %.2f back, still after %d frames; knockdown boing %.2f rad; shake-off %.2f rad" \
		% [tip.length(), back, settled, boing, wobble])
	await _bag_round3(d, settled)
	await create_timer(1.0).timeout  # freeing it mid hit-flash floods "Parameter material is null" (agents.md)
	d.queue_free()


## Round 3: the knobs and their flags, a hit cutting a shake-off short, the last-string tag.
func _bag_round3(d: Node, settled_default: int) -> void:
	var knobs: Dictionary = d.bag_overrides(PackedStringArray(["--bag-damping=7", "--bag-stiffness=abc", "--bag-lean=2.5", "--autotest"]))
	_check(knobs == {"bag_damping": 7.0, "bag_lean_mult": 2.5}, "--bag-*= flags parse (%s)" % [knobs])
	await create_timer(1.0).timeout
	d.bag_damping = 7.0
	d.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	var settled := -1
	for i in 240:
		await physics_frame
		if i > 5 and d._bag_tilt == Vector2.ZERO:
			settled = i
			break
	_check(settled > 0 and settled < settled_default, "more damping settles sooner (%d frames vs %d)" % [settled, settled_default])
	d.bag_damping = d.BAG_DAMPING
	# A shake-off cut short by a hit: the kicks and the stars stop.
	await create_timer(0.5).timeout
	var cut: int = d.shakeoffs_cut
	d.hp = d.max_hp - 10.0
	d.last_hit_ms = -100000
	await physics_frame
	await physics_frame
	d.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	await physics_frame
	_check(d.shakeoffs_cut == cut + 1 and d.find_child("DazeStars", false, false) == null, "a hit cuts the shake-off short (%d)" % d.shakeoffs_cut)
	var stretched := false
	for i in 40:  # past the whole shake-off: no boing stretch at its end
		await physics_frame
		stretched = stretched or d.last_squash == d.DAZE_STRETCH
	_check(not d._daze_tween.is_running() and not stretched, "no head-shake or boing after the cut")
	# The tag: the string's damage on this dummy pops when the combo drops, dims when the next starts.
	var game: Node = get_root().get_node("Game")
	game.combo_changed.emit(0, "D")  # close whatever the hits above started
	var tag: Label3D = d.get_node("StringTag")
	d.take_hit(12.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	await physics_frame
	d.take_hit(30.0, Vector3(0.0, 0.0, 6.0), 0.0, true)
	var dealt: float = d.string_damage
	game.combo_changed.emit(0, "D")
	_check(tag.visible and tag.text == "%d" % roundi(dealt) and d.last_string_damage == dealt and d.string_damage == 0.0,
		"the tag reads the last string's damage (%s for %.0f)" % [tag.text, dealt])
	d.take_hit(5.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	_check(is_equal_approx(tag.modulate.a, d.TAG_DIM) and tag.text == "%d" % roundi(dealt), "a new string dims it (%.2f)" % tag.modulate.a)
	print("[enemy_feel] bag round 3: damping 7 still after %d frames (5: %d); shake-off cut %d; tag %s" % [settled, settled_default, d.shakeoffs_cut, tag.text])


## Hit direction: a side launch rolls, a downward hit craters (from the air,
## Spike's fast fall, and on the floor) and skids further than a plain landing.
func _direction() -> void:
	var at: Vector3 = _main.player.global_position + Vector3(0.0, 0.0, 4.0)
	# Side launch: the turn is a roll around rotation.z, the flip axis stays put.
	var e: Node = await _fresh(at)
	e.model.rotation.y = PI
	e.take_hit(1.0, Vector3(6.0, 0.0, 0.0), 9.0, true)
	var roll := 0.0
	var flip := 0.0
	for i in 300:
		await physics_frame
		if e.state != e.State.AIRBORNE:
			break
		roll = maxf(roll, absf(e.model.rotation.z))
		flip = maxf(flip, absf(e.model.rotation.x))
	_check(roll > 1.0 and flip < 0.01, "a side launch rolls (z %.2f rad, x %.2f)" % [roll, flip])
	await create_timer(0.3).timeout
	_check(absf(e.model.rotation.z) < 0.01 and absf(e.model.rotation.x) < 0.01, "the roll rights itself (z %.3f)" % e.model.rotation.z)
	# Downward hit while up (knockback.y < 0): driven down stretched, craters, no bounce.
	e = await _fresh(at)
	e.model.rotation.y = PI
	e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 9.0, true)
	await create_timer(0.35).timeout
	e.take_hit(1.0, Vector3(0.0, -6.0, 6.0), 0.0, true)
	_check(e.last_squash == e.SQUASH.spike and e.velocity.y <= -e.SPIKE_SPEED + 0.01,
		"a downward hit drives it down stretched (%.1f m/s, %.2f)" % [e.velocity.y, e.last_squash.y])
	var crater := await _until_down(e)
	_check(crater.x == 1.0 and e.last_squash == e.SQUASH.crater, "it craters instead of bouncing (%.2f)" % e.last_squash.y)
	_check(e._state_t < -e.SPIKE_LIE + 0.05, "it lies in the crater %.2f s (%.2f)" % [e.SPIKE_LIE, e._state_t])
	var spike_skid := await _skid_length(e)
	# Spike (player.gd): a plain hit, then the hero sets the fall speed itself.
	e = await _fresh(at)
	e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 9.0, true)
	await create_timer(0.35).timeout
	e.take_hit(1.0, Vector3(0.0, 0.0, 3.0), 0.0, true)
	e.velocity.y = -24.0
	crater = await _until_down(e)
	_check(crater.x == 1.0 and e.last_squash == e.SQUASH.crater, "Spike's fast fall craters (%.2f)" % e.last_squash.y)
	# A plain landing for comparison.
	e = await _fresh(at)
	e.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 9.0, true)
	await _until_down(e)
	var plain_skid := await _skid_length(e)
	_check(spike_skid > plain_skid * 1.5, "a spiked skid goes further (%.2f m vs %.2f m)" % [spike_skid, plain_skid])
	# A downward hit on the floor: cratered where it stands, lying there.
	e = await _fresh(at)
	e.take_hit(1.0, Vector3(0.0, -6.0, 0.0), 0.0, true)
	_check(e.last_squash == e.SQUASH.crater and e.state == e.State.HURT and e._state_t < 0.0,
		"a grounded spike craters on the spot (%.2f, state %d)" % [e.last_squash.y, e.state])
	print("[enemy_feel] direction: side roll %.2f rad, spiked skid %.2f m (plain %.2f m), spike %.0f m/s, crater squash %.2f" \
		% [roll, spike_skid, plain_skid, e.SPIKE_SPEED, e.SQUASH.crater.y])


## Waits for `e` to touch down for good; x = 1 if it never rose again after its first floor contact.
func _until_down(e: Node) -> Vector2:
	var touched := false
	var rose := false
	for i in 300:
		await physics_frame
		if e.state != e.State.AIRBORNE:
			break
		if e.is_on_floor():
			touched = true
		elif touched and e.velocity.y > 0.5:
			rose = true
	return Vector2(0.0 if rose else 1.0, 0.0)


## Metres it slides from now until it's back on its feet.
func _skid_length(e: Node) -> float:
	var from: Vector3 = e.global_position
	for i in 200:
		await physics_frame
		if e.state != e.State.HURT:
			break
	var d: Vector3 = e.global_position - from
	return Vector2(d.x, d.z).length()


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
	# Killed by one blow: the death pops wait out the same wave.
	await create_timer(0.6).timeout
	for e in crowd:
		e.hp = 1.0
		e.take_hit(5.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	var waits: Array = crowd.map(func(e: Node) -> float: return e._wave_delay)
	var killed := true
	for i in 4:
		killed = killed and crowd[i].state == crowd[i].State.DEAD and is_equal_approx(waits[i], i * crowd[0].WAVE_STEP)
	_check(killed, "a multi-kill's death pops step by WAVE_STEP (%s)" % [waits])


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


## The element slams that hit downward (void_element DEEP_FREEZE_DOWN, METEOR_DOWN, MAW_DOWN): each, run for
## real by the hero on a standing minion, craters it (SQUASH.crater, knocked down) instead of a plain flinch.
func _slams() -> void:
	var ve: GDScript = load("res://scripts/void_element.gd")
	var hero: Node = _main.player
	var at: Vector3 = hero.global_position + Vector3(0.0, 0.0, 4.0)
	var seen := []
	for move in ["deep_freeze", "meteor", "maw"]:
		var e: Node = await _fresh(at)
		await physics_frame
		match move:
			"deep_freeze":
				ve._deep_freeze(hero, at, 1.0)
			"meteor":
				ve._tear(hero, {"damage": 1.0}, [e], 1.0)
			"maw":
				hero._void.dark_spot = at
				ve._maw(hero, {"damage": 1.0}, 1.0)
		_check(e.last_squash == e.SQUASH.crater and e.state == e.State.HURT,
			"%s craters the foe (squash %.2f, state %d)" % [move, e.last_squash.y, e.state])
		seen.append("%s %.2f" % [move, e.last_squash.y])
		await create_timer(0.3).timeout
	print("[enemy_feel] slams: %s" % ", ".join(seen))


## The Warden's reduced set: a tap only flashes; a big launching hit flashes, swells its ink and squashes a
## little, but never leans, tumbles or leaves the floor (super armour).
func _boss() -> void:
	for old in _main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var b: Node = _main._spawn_boss()
	b.global_position = _main.player.global_position + Vector3(0.0, 0.0, 5.0)
	b.max_hp = 5000.0
	b.hp = 5000.0
	b.break_damage = 100000.0
	await create_timer(1.2).timeout
	b.attack_damage = 0.0
	b.move_speed = 0.0
	b.take_hit(1.0, Vector3(0.0, 0.0, 6.0), 0.0, false)
	var tinted: MeshInstance3D = b.model.find_children("*", "MeshInstance3D", true, false)[0]
	_check(tinted.material_overlay != null and b.last_squash == Vector3.ONE and b.last_ink == 1.0,
		"a tap only flashes the Warden (squash %.2f ink %.1f)" % [b.last_squash.y, b.last_ink])
	await create_timer(0.2).timeout
	b.take_hit(1.0, Vector3(6.0, 0.0, 0.0), 9.0, true)
	var tilt := 0.0
	for i in 20:
		await physics_frame
		tilt = maxf(tilt, absf(b.model.rotation.x) + absf(b.model.rotation.z))
	_check(b.last_squash == b.BOSS_SQUASH and b.last_ink == b.BOSS_INK, "a big hit squashes the Warden %.2f and swells its ink %.1fx" % [b.last_squash.y, b.last_ink])
	_check(tilt < 0.001 and b.state != b.State.AIRBORNE and b.global_position.y < 0.05,
		"and it never leans, tumbles or lifts (tilt %.3f, y %.2f)" % [tilt, b.global_position.y])
	print("[enemy_feel] boss: big hit squash %.2f ink %.1fx, tilt %.3f" % [b.last_squash.y, b.last_ink, tilt])
	b.queue_free()


## --spar=<kind>: off without the flag, one live foe of that kind at 1/3 damage with it, its hits counted.
func _spar() -> void:
	for old in _main.get_tree().get_nodes_in_group("enemies"):
		old.queue_free()
	var spar: GDScript = load("res://scripts/spar.gd")
	_check(spar.kind_from(PackedStringArray(["--autotest"])) == "" and spar.kind_from(PackedStringArray(["--spar=dragon"])) == ""
		and spar.start(_main, PackedStringArray()) == null, "no --spar flag (or a wrong kind): no spar foe")
	var s: Node = spar.start(_main, PackedStringArray(["--spar=shield"]))
	var spec: Dictionary = _main.ENEMY_TYPES.shield
	_check(s != null and is_instance_valid(s.foe) and s.foe.shield and is_equal_approx(s.foe.attack_damage, spec.attack_damage / 3.0),
		"--spar=shield puts up a shield skeleton at 1/3 damage (%.1f)" % (s.foe.attack_damage if s != null else -1.0))
	await create_timer(1.1).timeout
	s.foe.take_hit(1.0, Vector3(6.0, 0.0, 0.0), 0.0, true)
	await physics_frame
	s.foe.take_hit(1.0, Vector3(0.0, 0.0, 0.0), 0.0, false)
	_check(s.total_hits() == 2, "its hits are counted (%d)" % s.total_hits())
	print("[enemy_feel] spar: shield foe attack %.1f, hits_taken %d" % [s.foe.attack_damage, s.total_hits()])
	await create_timer(0.5).timeout
	s.queue_free()
	s.foe.queue_free()


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
